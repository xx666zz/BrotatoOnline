extends Node

signal peer_connected(transport, peer)
signal peer_disconnected(transport, peer)
signal packet_received(transport, peer, data, channel)
signal connection_failed(transport, reason)

const DEFAULT_PORT = 27462
const MAX_CLIENTS = 3
const RECONNECT_GRACE_MSEC = 5000
const RECONNECT_RETRY_INTERVAL_MSEC = 750
const POLL_STALL_WARN_MSEC = 1000
const POLL_STALL_LOG_INTERVAL_MSEC = 3000

var _peer: NetworkedMultiplayerENet = null
var _is_host = false
var _active = false

var _client_address = ""
var _client_port = DEFAULT_PORT
var _reconnect_active = false
var _reconnect_started_msec = 0
var _reconnect_deadline_msec = 0
var _reconnect_next_attempt_msec = 0
var _reconnect_attempts = 0

var _last_poll_msec = 0
var _max_poll_gap_msec = 0
var _last_poll_stall_log_msec = 0
var _last_tx_msec = 0
var _last_rx_msec = 0


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	set_process(true)


func start_host(port: int = DEFAULT_PORT) -> int:
	stop()
	_peer = NetworkedMultiplayerENet.new()
	_peer.set_channel_count(4)
	var err = _peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		_peer = null
		return err
	_is_host = true
	_active = true
	_reset_runtime_diagnostics()
	_bind_peer_signals()
	_diag_log("host_started", "port=" + str(port))
	return OK


func start_client(address: String, port: int = DEFAULT_PORT) -> int:
	stop()
	_client_address = address
	_client_port = port
	var err = _create_client_peer(address, port)
	if err != OK:
		_client_address = ""
		return err
	_reset_runtime_diagnostics()
	_diag_log("client_connecting", "address=" + address + " port=" + str(port))
	return OK


func _create_client_peer(address: String, port: int) -> int:
	var next_peer = NetworkedMultiplayerENet.new()
	next_peer.set_channel_count(4)
	var err = next_peer.create_client(address, port)
	if err != OK:
		next_peer.close_connection()
		return err
	_peer = next_peer
	_is_host = false
	_active = true
	_bind_peer_signals()
	return OK


func stop() -> void:
	_discard_current_peer()
	_active = false
	_is_host = false
	_client_address = ""
	_client_port = DEFAULT_PORT
	_reconnect_active = false
	_reconnect_started_msec = 0
	_reconnect_deadline_msec = 0
	_reconnect_next_attempt_msec = 0
	_reconnect_attempts = 0
	_last_poll_msec = 0
	_max_poll_gap_msec = 0
	_last_poll_stall_log_msec = 0
	_last_tx_msec = 0
	_last_rx_msec = 0


func _discard_current_peer() -> void:
	_unbind_peer_signals()
	if _peer != null:
		_peer.close_connection()
	_peer = null


func is_active() -> bool:
	return _active and (_peer != null or _reconnect_active)


func is_hosting() -> bool:
	return is_active() and _is_host and _peer != null


func is_reconnecting() -> bool:
	return _reconnect_active


func get_peer_key(peer) -> String:
	return "lan:" + str(peer)


func send_packet(peer, data: PoolByteArray, channel: int, reliable: bool) -> bool:
	if not _active or _peer == null or data.empty():
		return false
	_peer.set_target_peer(int(peer))
	if _peer.has_method("set_transfer_channel"):
		# ENet channel 0 is reserved by Godot's multiplayer protocol.
		_peer.set_transfer_channel(int(clamp(channel + 1, 1, 3)))
	_peer.set_transfer_mode(NetworkedMultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else NetworkedMultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
	var err = _peer.put_packet(data)
	if err == OK:
		_last_tx_msec = OS.get_ticks_msec()
		return true
	_diag_log("send_failed", "peer=" + str(peer) + " channel=" + str(channel) + " reliable=" + str(reliable) + " bytes=" + str(data.size()) + " error=" + str(err) + " " + _diag_timing_snapshot())
	return false


func close_peer(peer) -> void:
	if _peer != null and _is_host and _peer.has_method("disconnect_peer"):
		_peer.disconnect_peer(int(peer), true)


func _process(_delta: float) -> void:
	if not _active:
		return
	var now = OS.get_ticks_msec()
	_track_poll_gap(now)

	if _reconnect_active:
		if now >= _reconnect_deadline_msec:
			_finish_client_reconnect_failure("grace_timeout")
			return
		if _peer == null and now >= _reconnect_next_attempt_msec:
			_try_client_reconnect(now)

	if _peer == null:
		return
	var active_peer = _peer
	active_peer.poll()
	while _peer == active_peer and active_peer.get_available_packet_count() > 0:
		# NetworkedMultiplayerENet reads the sender from the packet currently at
		# the head of its receive queue. Read it before get_packet(); unlike the
		# sender, get_last_packet_channel() describes the packet just fetched and
		# must therefore be read afterward.
		var sender = active_peer.get_packet_peer()
		var data = active_peer.get_packet()
		var channel = active_peer.get_last_packet_channel() if active_peer.has_method("get_last_packet_channel") else 0
		_last_rx_msec = OS.get_ticks_msec()
		emit_signal("packet_received", self, sender, data, channel)


func _track_poll_gap(now: int) -> void:
	if _last_poll_msec > 0:
		var gap = now - _last_poll_msec
		if gap > _max_poll_gap_msec:
			_max_poll_gap_msec = gap
		if gap >= POLL_STALL_WARN_MSEC and now - _last_poll_stall_log_msec >= POLL_STALL_LOG_INTERVAL_MSEC:
			_last_poll_stall_log_msec = now
			_diag_log("poll_stall", "gap_ms=" + str(gap) + " " + _diag_timing_snapshot(now))
	_last_poll_msec = now


func _begin_client_reconnect(reason: String) -> void:
	if _is_host or not _active:
		return
	if _reconnect_active:
		return
	if _client_address == "":
		_diag_log("disconnect_no_target", "reason=" + reason + " " + _diag_timing_snapshot())
		emit_signal("peer_disconnected", self, 1)
		stop()
		return

	var now = OS.get_ticks_msec()
	_reconnect_active = true
	_reconnect_started_msec = now
	_reconnect_deadline_msec = now + RECONNECT_GRACE_MSEC
	_reconnect_next_attempt_msec = now
	_reconnect_attempts = 0
	_diag_log("disconnect_grace_started", "reason=" + reason + " grace_ms=" + str(RECONNECT_GRACE_MSEC) + " address=" + _client_address + " port=" + str(_client_port) + " " + _diag_timing_snapshot(now))
	_discard_current_peer()


func _try_client_reconnect(now: int) -> void:
	if not _reconnect_active or _client_address == "":
		return
	_reconnect_attempts += 1
	_diag_log("reconnect_attempt", "attempt=" + str(_reconnect_attempts) + " elapsed_ms=" + str(now - _reconnect_started_msec) + " address=" + _client_address + " port=" + str(_client_port))
	var err = _create_client_peer(_client_address, _client_port)
	if err != OK:
		_diag_log("reconnect_create_failed", "attempt=" + str(_reconnect_attempts) + " error=" + str(err))
		_reconnect_next_attempt_msec = now + RECONNECT_RETRY_INTERVAL_MSEC


func _finish_client_reconnect_failure(reason: String) -> void:
	if not _reconnect_active:
		return
	var now = OS.get_ticks_msec()
	var elapsed = now - _reconnect_started_msec
	_reconnect_active = false
	_diag_log("reconnect_failed", "reason=" + reason + " attempts=" + str(_reconnect_attempts) + " elapsed_ms=" + str(elapsed) + " " + _diag_timing_snapshot(now))
	# Preserve the existing SessionManager behavior only after the grace period is
	# exhausted. That code owns the actual session teardown/title return.
	emit_signal("peer_disconnected", self, 1)
	stop()


func _bind_peer_signals() -> void:
	if _peer == null:
		return
	_bind_peer_signal("peer_connected", "_on_network_peer_connected")
	_bind_peer_signal("peer_disconnected", "_on_network_peer_disconnected")
	_bind_peer_signal("connection_succeeded", "_on_connected_to_server")
	_bind_peer_signal("connection_failed", "_on_connection_failed")
	_bind_peer_signal("server_disconnected", "_on_server_disconnected")


func _bind_peer_signal(signal_name: String, method_name: String) -> void:
	if _peer.has_signal(signal_name) and not _peer.is_connected(signal_name, self, method_name):
		_peer.connect(signal_name, self, method_name)


func _unbind_peer_signals() -> void:
	if _peer == null:
		return
	for pair in [["peer_connected", "_on_network_peer_connected"], ["peer_disconnected", "_on_network_peer_disconnected"], ["connection_succeeded", "_on_connected_to_server"], ["connection_failed", "_on_connection_failed"], ["server_disconnected", "_on_server_disconnected"]]:
		if _peer.has_signal(pair[0]) and _peer.is_connected(pair[0], self, pair[1]):
			_peer.disconnect(pair[0], self, pair[1])


func _on_network_peer_connected(peer_id: int) -> void:
	if _is_host:
		_diag_log("peer_connected", "peer=" + str(peer_id) + " " + _diag_timing_snapshot())
		emit_signal("peer_connected", self, peer_id)


func _on_network_peer_disconnected(peer_id: int) -> void:
	if _is_host:
		_diag_log("peer_disconnected", "peer=" + str(peer_id) + " " + _diag_timing_snapshot())
		emit_signal("peer_disconnected", self, peer_id)
		return
	_begin_client_reconnect("peer_disconnected:" + str(peer_id))


func _on_connected_to_server() -> void:
	var was_reconnecting = _reconnect_active
	var elapsed = OS.get_ticks_msec() - _reconnect_started_msec if was_reconnecting else 0
	_reconnect_active = false
	_reconnect_deadline_msec = 0
	_reconnect_next_attempt_msec = 0
	if was_reconnecting:
		_diag_log("reconnect_succeeded", "attempts=" + str(_reconnect_attempts) + " elapsed_ms=" + str(elapsed) + " " + _diag_timing_snapshot())
	else:
		_diag_log("client_connected", "address=" + _client_address + " port=" + str(_client_port))
	emit_signal("peer_connected", self, 1)


func _on_connection_failed() -> void:
	if _reconnect_active:
		var now = OS.get_ticks_msec()
		_diag_log("reconnect_attempt_failed", "attempt=" + str(_reconnect_attempts) + " elapsed_ms=" + str(now - _reconnect_started_msec))
		_discard_current_peer()
		_reconnect_next_attempt_msec = now + RECONNECT_RETRY_INTERVAL_MSEC
		return
	emit_signal("connection_failed", self, "connection_failed")
	stop()


func _on_server_disconnected() -> void:
	_begin_client_reconnect("server_disconnected")


func _reset_runtime_diagnostics() -> void:
	_last_poll_msec = 0
	_max_poll_gap_msec = 0
	_last_poll_stall_log_msec = 0
	_last_tx_msec = 0
	_last_rx_msec = 0


func _diag_timing_snapshot(now: int = -1) -> String:
	if now < 0:
		now = OS.get_ticks_msec()
	var tx_age = -1 if _last_tx_msec <= 0 else now - _last_tx_msec
	var rx_age = -1 if _last_rx_msec <= 0 else now - _last_rx_msec
	return "phase=" + _diag_phase() + " last_tx_age_ms=" + str(tx_age) + " last_rx_age_ms=" + str(rx_age) + " max_poll_gap_ms=" + str(_max_poll_gap_msec)


func _diag_phase() -> String:
	var parent = get_parent()
	if parent == null:
		return "unknown"
	var session_manager = parent.get_node_or_null("BrotatoOnlineSessionManager")
	if session_manager != null and session_manager.has_method("get_lobby_state"):
		return str(session_manager.get_lobby_state())
	return "unknown"


func _diag_log(event: String, details: String = "") -> void:
	var line = "[BO_NET][LAN][" + event + "]"
	if details != "":
		line += " " + details
	print(line)
