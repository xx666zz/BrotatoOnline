extends Node

# Steam-specific adapter. SessionManager owns game/session state; this node owns
# Steam initialization, callbacks and SteamNetworkingMessages byte transport.

signal lobby_created(connect_result, lobby_id)
signal lobby_joined(lobby_id, permissions, locked, response)
signal lobby_chat_update(lobby_id, changed_id, making_change_id, chat_state)
signal lobby_data_update(success, lobby_id, member_id)
signal lobby_join_requested(lobby_id, friend_id)
signal rich_presence_join_requested(friend_id, connect_string)
signal join_game_requested(arg0, arg1)
signal network_messages_session_request(remote_peer)
signal network_messages_session_failed(remote_peer, session_error, end_reason, debug_message)

const BROTATO_APP_ID = 1942280
const STEAM_NETWORKING_SEND_RELIABLE = 8

var _steam = null
var _ready = false


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_setup_steam()
	_connect_callbacks()


func is_available() -> bool:
	if _steam != null and _steam.has_method("getSteamID"):
		var self_id = str(_steam.getSteamID())
		_ready = self_id != "" and self_id != "0"
	return _ready and _steam != null


func get_steam():
	return _steam


func get_peer_key(peer) -> String:
	return str(peer)


func poll_callbacks() -> void:
	if _steam != null and _steam.has_method("run_callbacks"):
		_steam.run_callbacks()


func start_host(lobby_type: int, member_limit: int) -> int:
	if not is_available() or not _steam.has_method("createLobby"):
		return ERR_UNAVAILABLE
	_steam.createLobby(lobby_type, member_limit)
	return OK


func join_lobby(lobby_id) -> int:
	if not is_available() or not _steam.has_method("joinLobby"):
		return ERR_UNAVAILABLE
	var result = _steam.joinLobby(lobby_id)
	if typeof(result) == TYPE_BOOL and not bool(result):
		return FAILED
	return OK


func leave_lobby(lobby_id) -> void:
	if _steam != null and int(lobby_id) != 0 and _steam.has_method("leaveLobby"):
		_steam.leaveLobby(lobby_id)


func open_invite_overlay(lobby_id) -> void:
	if _steam != null and int(lobby_id) != 0 and _steam.has_method("activateGameOverlayInviteDialog"):
		_steam.activateGameOverlayInviteDialog(lobby_id)


func prepare_peer(peer) -> bool:
	if not is_available() or not _steam.has_method("acceptSessionWithUser"):
		return false
	return bool(_steam.acceptSessionWithUser(int(peer)))


func close_peer(peer) -> void:
	if _steam != null and _steam.has_method("closeSessionWithUser"):
		_steam.closeSessionWithUser(int(peer))


func send_packet(peer, data: PoolByteArray, channel: int, reliable: bool) -> bool:
	if not is_available() or not _steam.has_method("sendMessageToUser"):
		return false
	var flags = STEAM_NETWORKING_SEND_RELIABLE if reliable else 0
	var result = _steam.sendMessageToUser(int(peer), data, flags, channel)
	if typeof(result) == TYPE_BOOL:
		return bool(result)
	if typeof(result) == TYPE_INT or typeof(result) == TYPE_REAL:
		return int(result) == 1
	if typeof(result) == TYPE_DICTIONARY:
		for key in ["result", "status", "code", "response"]:
			if result.has(key):
				return int(result[key]) == 1
	return false


func receive_packets(channel: int, limit: int) -> Array:
	if not is_available() or not _steam.has_method("receiveMessagesOnChannel"):
		return []
	var result = _steam.receiveMessagesOnChannel(channel, limit)
	if typeof(result) == TYPE_ARRAY:
		return result
	if typeof(result) == TYPE_DICTIONARY:
		if result.has("messages") and typeof(result["messages"]) == TYPE_ARRAY:
			return result["messages"]
		if result.has("data") and typeof(result["data"]) == TYPE_ARRAY:
			return result["data"]
		if result.has("message") or result.has("payload") or result.has("bytes"):
			return [result]
	return []


func _setup_steam() -> void:
	if not Engine.has_singleton("Steam"):
		return
	_steam = Engine.get_singleton("Steam")
	if _steam.has_method("steamInitEx"):
		_steam.steamInitEx(BROTATO_APP_ID, true)
	elif _steam.has_method("steamInit"):
		_steam.steamInit()
	var self_id = ""
	if _steam.has_method("getSteamID"):
		self_id = str(_steam.getSteamID())
	_ready = self_id != "" and self_id != "0"


func _connect_callbacks() -> void:
	_connect_steam_signal("lobby_created", "_on_lobby_created")
	_connect_steam_signal("lobby_joined", "_on_lobby_joined")
	_connect_steam_signal("lobby_chat_update", "_on_lobby_chat_update")
	_connect_steam_signal("lobby_data_update", "_on_lobby_data_update")
	for signal_name in ["join_requested", "game_lobby_join_requested"]:
		_connect_steam_signal(signal_name, "_on_lobby_join_requested")
	for signal_name in ["rich_presence_join_requested", "game_rich_presence_join_requested"]:
		_connect_steam_signal(signal_name, "_on_rich_presence_join_requested")
	for signal_name in ["join_game_requested", "game_join_requested"]:
		_connect_steam_signal(signal_name, "_on_join_game_requested")
	for signal_name in ["network_messages_session_request", "networking_messages_session_request"]:
		_connect_steam_signal(signal_name, "_on_network_messages_session_request")
	for signal_name in ["network_messages_session_failed", "networking_messages_session_failed"]:
		_connect_steam_signal(signal_name, "_on_network_messages_session_failed")


func _connect_steam_signal(signal_name: String, method_name: String) -> void:
	if _steam == null or not _steam.has_signal(signal_name):
		return
	if not _steam.is_connected(signal_name, self, method_name):
		_steam.connect(signal_name, self, method_name)


func _on_lobby_created(connect_result = 0, lobby_id = 0) -> void:
	emit_signal("lobby_created", connect_result, lobby_id)


func _on_lobby_joined(lobby_id = 0, permissions = 0, locked = false, response = 0) -> void:
	emit_signal("lobby_joined", lobby_id, permissions, locked, response)


func _on_lobby_chat_update(lobby_id = 0, changed_id = 0, making_change_id = 0, chat_state = 0) -> void:
	emit_signal("lobby_chat_update", lobby_id, changed_id, making_change_id, chat_state)


func _on_lobby_data_update(success = false, lobby_id = 0, member_id = 0) -> void:
	emit_signal("lobby_data_update", success, lobby_id, member_id)


func _on_lobby_join_requested(lobby_id = 0, friend_id = 0) -> void:
	emit_signal("lobby_join_requested", lobby_id, friend_id)


func _on_rich_presence_join_requested(friend_id = 0, connect_string = "") -> void:
	emit_signal("rich_presence_join_requested", friend_id, connect_string)


func _on_join_game_requested(arg0 = null, arg1 = null) -> void:
	emit_signal("join_game_requested", arg0, arg1)


func _on_network_messages_session_request(remote_peer = 0) -> void:
	emit_signal("network_messages_session_request", remote_peer)


func _on_network_messages_session_failed(remote_peer = 0, session_error = 0, end_reason = 0, debug_message = "") -> void:
	emit_signal("network_messages_session_failed", remote_peer, session_error, end_reason, debug_message)
