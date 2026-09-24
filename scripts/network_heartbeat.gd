extends Node

const HEARTBEAT_INTERVAL_MSEC = 2000
const HEARTBEAT_TIMEOUT_MSEC = 8000
const STATUS_POLL_INTERVAL_MSEC = 250
const DISPLAY_NAME_LIMIT = 48

var _session_manager = null
var _session_was_active = false
var _next_heartbeat_msec = 0
var _heartbeat_seq = 0
var _send_failure_active = false
var _next_status_poll_msec = 0
var _last_heartbeat_by_peer = {}
var _peer_names = {}
var _disconnected_peers = {}
var _host_reported_disconnected = {}
var _notice_layer = null
var _notice_panel = null
var _notice_label = null


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	set_process(true)


func _process(_delta: float) -> void:
	var session_manager = _get_session_manager()
	if session_manager == null:
		return
	var active = session_manager.has_method("is_online_session_active") and bool(session_manager.is_online_session_active())
	if not active:
		if _session_was_active:
			_diag_log("stopped", "")
			reset_online_session_state()
		return

	var now = OS.get_ticks_msec()
	_begin_session(session_manager, now)
	if now >= _next_status_poll_msec:
		_next_status_poll_msec = now + STATUS_POLL_INTERVAL_MSEC
		_sync_monitored_peers(session_manager, now)
		_poll_heartbeat_timeouts(now)
		_refresh_notice()
	if now < _next_heartbeat_msec:
		return
	_send_heartbeat(session_manager, now)


func _begin_session(session_manager, now: int) -> void:
	if not _session_was_active:
		_session_was_active = true
		# Send immediately on entry, then every two seconds.
		_next_heartbeat_msec = now
		_diag_log("started", "interval_ms=" + str(HEARTBEAT_INTERVAL_MSEC) + " role=" + _role(session_manager) + " phase=" + _phase(session_manager))


func _send_heartbeat(session_manager, now: int) -> void:
	_next_heartbeat_msec = now + HEARTBEAT_INTERVAL_MSEC
	_heartbeat_seq += 1

	var heartbeat = {
		"msg_type": "heartbeat",
		"heartbeat_seq": _heartbeat_seq,
		"heartbeat_msec": now,
		"display_name": _sanitize_name(session_manager.get_peer_display_name(session_manager.get_self_steam_id()))
	}
	var ok = false
	var is_host = session_manager.has_method("is_game_host") and bool(session_manager.is_game_host())
	if is_host:
		# Repeat the full current state, including an empty list after recovery.
		# One dropped status packet must not leave the other clients with stale UI.
		var disconnected = []
		for peer_key in _disconnected_peers.keys():
			disconnected.append({"peer_key": str(peer_key), "name": str(_disconnected_peers[peer_key])})
		heartbeat["disconnected_peers"] = disconnected
		var remote_count = _remote_count(session_manager)
		if remote_count <= 0:
			ok = true
		else:
			ok = bool(session_manager.broadcast_message(heartbeat, "", false))
	else:
		ok = bool(session_manager.send_message_to_host(heartbeat, false))

	if not ok:
		if not _send_failure_active:
			_send_failure_active = true
			_diag_log("send_failed", "seq=" + str(_heartbeat_seq) + " role=" + _role(session_manager) + " phase=" + _phase(session_manager))
	elif _send_failure_active:
		_send_failure_active = false
		_diag_log("send_recovered", "seq=" + str(_heartbeat_seq) + " role=" + _role(session_manager) + " phase=" + _phase(session_manager))


func receive_heartbeat(from_peer_key: String, message: Dictionary) -> void:
	var session_manager = _get_session_manager()
	if session_manager == null:
		return
	# Host monitors its clients; clients monitor only Host. A different client
	# cannot refresh Host's timer or publish a room-wide disconnect notice.
	var peers = session_manager.get_heartbeat_peer_keys()
	if not peers.has(from_peer_key):
		return
	var now = OS.get_ticks_msec()
	_begin_session(session_manager, now)
	_last_heartbeat_by_peer[from_peer_key] = now
	var display_name = _sanitize_name(session_manager.get_peer_display_name(from_peer_key))
	if display_name == "":
		display_name = _sanitize_name(str(message.get("display_name", "")))
	if display_name != "":
		_peer_names[from_peer_key] = display_name
	if _disconnected_peers.has(from_peer_key):
		_disconnected_peers.erase(from_peer_key)
		_next_heartbeat_msec = 0
		_diag_log("peer_recovered", "peer=" + from_peer_key)
	if not bool(session_manager.is_game_host()):
		_receive_host_disconnect_status(message)
	_next_status_poll_msec = 0


func _sync_monitored_peers(session_manager, now: int) -> void:
	var peers = session_manager.get_heartbeat_peer_keys()
	for peer_key_value in peers:
		var peer_key = str(peer_key_value)
		if not _last_heartbeat_by_peer.has(peer_key):
			# Each new peer gets its own eight-second first-heartbeat grace period.
			_last_heartbeat_by_peer[peer_key] = now
			var display_name = _sanitize_name(session_manager.get_peer_display_name(peer_key))
			if display_name != "":
				_peer_names[peer_key] = display_name
	for peer_key in _last_heartbeat_by_peer.keys():
		if not peers.has(peer_key):
			_last_heartbeat_by_peer.erase(peer_key)
			_peer_names.erase(peer_key)
			if _disconnected_peers.has(peer_key):
				_disconnected_peers.erase(peer_key)
				_next_heartbeat_msec = 0


func _poll_heartbeat_timeouts(now: int) -> void:
	for peer_key in _last_heartbeat_by_peer.keys():
		if now - int(_last_heartbeat_by_peer[peer_key]) < HEARTBEAT_TIMEOUT_MSEC:
			continue
		if _disconnected_peers.has(peer_key):
			continue
		_disconnected_peers[peer_key] = _get_peer_name(str(peer_key))
		# Host forwards a changed status on this tick, without waiting another 2s.
		_next_heartbeat_msec = 0
		_diag_log("peer_timeout", "peer=" + str(peer_key) + " age_ms=" + str(now - int(_last_heartbeat_by_peer[peer_key])))


func _receive_host_disconnect_status(message: Dictionary) -> void:
	var rows = message.get("disconnected_peers", [])
	if typeof(rows) != TYPE_ARRAY:
		return
	var reported = {}
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var peer_key = str(row.get("peer_key", ""))
		var display_name = _sanitize_name(str(row.get("name", "")))
		if peer_key != "" and display_name != "":
			reported[peer_key] = display_name
		if reported.size() >= 3:
			break
	_host_reported_disconnected = reported


func _get_peer_name(peer_key: String) -> String:
	var cached_name = str(_peer_names.get(peer_key, ""))
	if cached_name != "":
		return cached_name
	var session_manager = _get_session_manager()
	var player_index = session_manager.get_player_index_for_peer(peer_key) if session_manager != null else -1
	return _txt("BROTATO_ONLINE_PLAYER_LIST_PLAYER") % [max(0, player_index) + 1]


func _sanitize_name(value: String) -> String:
	return value.replace("\r", " ").replace("\n", " ").replace("\t", " ").strip_edges().substr(0, DISPLAY_NAME_LIMIT)


func reset_online_session_state() -> void:
	_session_was_active = false
	_next_heartbeat_msec = 0
	_heartbeat_seq = 0
	_send_failure_active = false
	_next_status_poll_msec = 0
	_last_heartbeat_by_peer.clear()
	_peer_names.clear()
	_disconnected_peers.clear()
	_host_reported_disconnected.clear()
	if _notice_panel != null and is_instance_valid(_notice_panel):
		_notice_panel.hide()


func _refresh_notice() -> void:
	var disconnected = _host_reported_disconnected.duplicate()
	for peer_key in _disconnected_peers.keys():
		disconnected[peer_key] = _disconnected_peers[peer_key]
	if disconnected.empty():
		if _notice_panel != null and is_instance_valid(_notice_panel):
			_notice_panel.hide()
		return
	_ensure_notice()
	var lines = PoolStringArray()
	var keys = disconnected.keys()
	keys.sort()
	for peer_key in keys:
		lines.append(_txt("BROTATO_ONLINE_HEARTBEAT_DISCONNECTED") % [str(disconnected[peer_key])])
	lines.append(_txt("BROTATO_ONLINE_HEARTBEAT_RECOVERY"))
	_notice_label.text = lines.join("\n")
	var viewport_size = get_viewport().get_visible_rect().size
	var width = min(620.0, max(240.0, viewport_size.x - 32.0))
	_notice_label.rect_min_size.x = width - 28.0
	_notice_panel.rect_min_size.x = width
	_notice_panel.rect_size = Vector2(width, 0)
	_notice_panel.rect_position = Vector2(max(16.0, viewport_size.x - width - 16.0), 16.0)
	_notice_panel.show()


func _ensure_notice() -> void:
	if _notice_panel != null and is_instance_valid(_notice_panel):
		return
	# A persistent CanvasLayer survives battle/shop scene switches and still
	# updates while paused. The notice never captures clicks or keyboard focus.
	_notice_layer = CanvasLayer.new()
	_notice_layer.name = "HeartbeatDisconnectNotice"
	_notice_layer.layer = 128
	_notice_layer.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(_notice_layer)
	_notice_panel = PanelContainer.new()
	_notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.04, 0.04, 0.94)
	style.border_color = Color(0.9, 0.3, 0.2, 1.0)
	style.set_border_width_all(2)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_notice_panel.add_stylebox_override("panel", style)
	_notice_layer.add_child(_notice_panel)
	_notice_label = Label.new()
	_notice_label.autowrap = true
	_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_label.add_color_override("font_color", Color(1.0, 0.9, 0.8, 1.0))
	var font = load("res://resources/fonts/actual/base/font_22.tres")
	if font != null:
		_notice_label.add_font_override("font", font)
	_notice_panel.add_child(_notice_label)


func _txt(key: String) -> String:
	var i18n = get_parent().get_node_or_null("BrotatoOnlineI18n")
	return str(i18n.get_text(key)) if i18n != null else key


func _get_session_manager():
	if _session_manager != null and is_instance_valid(_session_manager):
		return _session_manager
	var parent = get_parent()
	if parent == null:
		return null
	_session_manager = parent.get_node_or_null("BrotatoOnlineSessionManager")
	return _session_manager


func _remote_count(session_manager) -> int:
	if session_manager != null and session_manager.has_method("bo_api_get_remote_member_steam_ids"):
		var remotes = session_manager.bo_api_get_remote_member_steam_ids()
		if typeof(remotes) == TYPE_ARRAY:
			return remotes.size()
	return 0


func _role(session_manager) -> String:
	if session_manager != null and session_manager.has_method("is_game_host") and bool(session_manager.is_game_host()):
		return "host"
	return "client"


func _phase(session_manager) -> String:
	if session_manager != null and session_manager.has_method("get_lobby_state"):
		return str(session_manager.get_lobby_state())
	return "unknown"


func _diag_log(event: String, details: String) -> void:
	var line = "[BO_NET][HEARTBEAT][" + event + "]"
	if details != "":
		line += " " + details
	print(line)
