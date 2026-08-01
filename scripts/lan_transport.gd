extends Node

signal peer_connected(transport, peer)
signal peer_disconnected(transport, peer)
signal packet_received(transport, peer, data, channel)
signal connection_failed(transport, reason)

const DEFAULT_PORT = 27462
const MAX_CLIENTS = 3

var _peer: NetworkedMultiplayerENet = null
var _is_host = false
var _active = false


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
	_bind_peer_signals()
	return OK


func start_client(address: String, port: int = DEFAULT_PORT) -> int:
	stop()
	_peer = NetworkedMultiplayerENet.new()
	_peer.set_channel_count(4)
	var err = _peer.create_client(address, port)
	if err != OK:
		_peer = null
		return err
	_is_host = false
	_active = true
	_bind_peer_signals()
	return OK


func stop() -> void:
	_unbind_peer_signals()
	if _peer != null:
		_peer.close_connection()
	_peer = null
	_active = false
	_is_host = false


func is_active() -> bool:
	return _active and _peer != null


func is_hosting() -> bool:
	return is_active() and _is_host


func get_peer_key(peer) -> String:
	return "lan:" + str(peer)


func send_packet(peer, data: PoolByteArray, channel: int, reliable: bool) -> bool:
	if not is_active() or data.empty():
		return false
	_peer.set_target_peer(int(peer))
	if _peer.has_method("set_transfer_channel"):
		# ENet channel 0 is reserved by Godot's multiplayer protocol.
		_peer.set_transfer_channel(int(clamp(channel + 1, 1, 3)))
	_peer.set_transfer_mode(NetworkedMultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else NetworkedMultiplayerPeer.TRANSFER_MODE_UNRELIABLE)
	return _peer.put_packet(data) == OK


func close_peer(peer) -> void:
	if _peer != null and _is_host and _peer.has_method("disconnect_peer"):
		_peer.disconnect_peer(int(peer), true)


func _process(_delta: float) -> void:
	if not is_active():
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
		emit_signal("packet_received", self, sender, data, channel)


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
		emit_signal("peer_connected", self, peer_id)


func _on_network_peer_disconnected(peer_id: int) -> void:
	emit_signal("peer_disconnected", self, peer_id)


func _on_connected_to_server() -> void:
	emit_signal("peer_connected", self, 1)


func _on_connection_failed() -> void:
	emit_signal("connection_failed", self, "connection_failed")
	stop()


func _on_server_disconnected() -> void:
	emit_signal("peer_disconnected", self, 1)
	stop()
