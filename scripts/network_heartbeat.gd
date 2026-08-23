extends Node

const HEARTBEAT_INTERVAL_MSEC = 2000

var _session_manager = null
var _session_was_active = false
var _next_heartbeat_msec = 0
var _heartbeat_seq = 0
var _send_failure_active = false


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
		_session_was_active = false
		_next_heartbeat_msec = 0
		_heartbeat_seq = 0
		_send_failure_active = false
		return

	var now = OS.get_ticks_msec()
	if not _session_was_active:
		_session_was_active = true
		_next_heartbeat_msec = now + HEARTBEAT_INTERVAL_MSEC
		_diag_log("started", "interval_ms=" + str(HEARTBEAT_INTERVAL_MSEC) + " role=" + _role(session_manager) + " phase=" + _phase(session_manager))
		return
	if now < _next_heartbeat_msec:
		return
	_next_heartbeat_msec = now + HEARTBEAT_INTERVAL_MSEC
	_heartbeat_seq += 1

	var heartbeat = {
		"msg_type": "heartbeat",
		"heartbeat_seq": _heartbeat_seq,
		"heartbeat_msec": now
	}
	var ok = false
	var is_host = session_manager.has_method("is_game_host") and bool(session_manager.is_game_host())
	if is_host:
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
