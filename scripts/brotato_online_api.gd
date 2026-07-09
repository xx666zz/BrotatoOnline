extends Node

signal phase_changed(old_phase, new_phase, context)
signal slot_layout_changed(context)
signal mod_message_received(mod_id, route, payload, meta)

const API_VERSION = 1
const API_GROUP = "brotato_online_api"
const MSG_TYPE_MOD_MESSAGE = "bo_mod_message"
const SCOPE_MENU = "menu"
const SCOPE_BATTLE = "battle"

var _last_phase = ""
var _last_slot_key = ""
var _last_context = {}


func _ready() -> void:
	add_to_group(API_GROUP)
	_last_phase = get_phase()
	_last_slot_key = _make_slot_key(get_local_player_indices())
	_last_context = get_context()
	set_process(true)


func _process(_delta: float) -> void:
	_poll_phase_and_slots()


func get_api_version() -> int:
	return API_VERSION


func is_online() -> bool:
	var steam_manager = _get_steam_lobby_manager()
	if steam_manager != null and steam_manager.has_method("bo_api_is_online"):
		return bool(steam_manager.bo_api_is_online())
	var tree = get_tree()
	if tree != null and tree.root != null:
		return bool(tree.root.get_meta("brotato_online_session_active", false))
	return false


func is_host() -> bool:
	if not is_online():
		return false
	var steam_manager = _get_steam_lobby_manager()
	if steam_manager != null and steam_manager.has_method("bo_api_is_host"):
		return bool(steam_manager.bo_api_is_host())
	return false


func is_client() -> bool:
	if not is_online():
		return false
	var steam_manager = _get_steam_lobby_manager()
	if steam_manager != null and steam_manager.has_method("bo_api_is_client"):
		return bool(steam_manager.bo_api_is_client())
	return not is_host()


func is_offline_or_host() -> bool:
	return not is_online() or is_host()


func get_phase() -> String:
	if not is_online():
		return "offline"

	var menu_sync = _get_menu_sync_manager()
	var screen = ""
	if menu_sync != null and menu_sync.has_method("get_current_menu_screen"):
		screen = str(menu_sync.get_current_menu_screen())

	if screen == "character_selection" or screen == "weapon_selection" or screen == "difficulty_selection":
		return "selection"
	if screen == "shop" or screen.find("shop") != -1:
		return "shop"
	if screen == "game":
		if _is_run_end_visible():
			return "run_end"
		if _is_progression_visible(menu_sync):
			return "progression"
		return "battle"

	var scene = get_tree().current_scene if get_tree() != null else null
	if scene != null:
		var scene_path = str(scene.filename).to_lower()
		var scene_name = str(scene.name).to_lower()
		if scene_path == "res://main.tscn" or scene_name == "main":
			if _is_run_end_visible():
				return "run_end"
			if _is_progression_visible(menu_sync):
				return "progression"
			return "battle"
		if scene_path.find("shop") != -1 or scene_name.find("shop") != -1:
			return "shop"
		if scene_path.find("character") != -1 or scene_path.find("weapon") != -1 or scene_path.find("difficulty") != -1:
			return "selection"
		if scene_path.find("end") != -1 or scene_name.find("end") != -1:
			return "run_end"

	return "lobby"


func get_context() -> Dictionary:
	return {
		"api_version": API_VERSION,
		"online": is_online(),
		"role": _get_role(),
		"phase": get_phase(),
		"wave": _get_current_wave(),
		"local_player_indices": get_local_player_indices(),
		"battle_id": _get_battle_id()
	}


func get_local_player_indices() -> Array:
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("get_local_player_indices"):
		var indices = slot_manager.get_local_player_indices()
		if typeof(indices) == TYPE_ARRAY:
			return indices.duplicate(true)

	var result = []
	if typeof(CoopService) != TYPE_NIL:
		for i in range(CoopService.connected_players.size()):
			result.append(i)
	return result


func owns_player(player_index: int) -> bool:
	return get_local_player_indices().has(player_index)


func should_run_authoritative_logic() -> bool:
	return not is_online() or is_host()


func should_run_local_visual_only() -> bool:
	return is_online() and is_client()


func send_to_host(mod_id: String, route: String, payload: Dictionary, options: Dictionary = {}) -> bool:
	if not _is_valid_outgoing(mod_id, route, payload):
		return false
	var message = _make_wire_message(mod_id, route, payload, options)
	if not is_online():
		return _deliver_local_message(_get_self_steam_id(), message)
	if is_host():
		return _deliver_local_message(_get_self_steam_id(), message)
	var host_steam_id = _get_host_steam_id()
	if host_steam_id == "":
		return false
	return _send_wire_to_steam_id(host_steam_id, message, _get_reliable_option(options))


func send_to_player(player_index: int, mod_id: String, route: String, payload: Dictionary, options: Dictionary = {}) -> bool:
	if not _is_valid_outgoing(mod_id, route, payload):
		return false
	var message = _make_wire_message(mod_id, route, payload, options)
	if not is_online():
		if owns_player(player_index):
			return _deliver_local_message(_get_self_steam_id(), message)
		return false
	if owns_player(player_index):
		return _deliver_local_message(_get_self_steam_id(), message)
	if is_host():
		var target_steam_id = _get_remote_steam_id_for_player(player_index)
		if target_steam_id == "":
			return false
		return _send_wire_to_steam_id(target_steam_id, message, _get_reliable_option(options))

	# Client-to-client targeting is relayed by Host. This keeps third-party mods from
	# depending on direct client P2P sessions that may not be open yet.
	var host_steam_id = _get_host_steam_id()
	if host_steam_id == "":
		return false
	var relay = message.duplicate(true)
	relay["bo_api_target_player_index"] = player_index
	return _send_wire_to_steam_id(host_steam_id, relay, _get_reliable_option(options))


func broadcast(mod_id: String, route: String, payload: Dictionary, options: Dictionary = {}) -> bool:
	if not _is_valid_outgoing(mod_id, route, payload):
		return false
	var message = _make_wire_message(mod_id, route, payload, options)
	var delivered_or_sent = false

	# Broadcast includes local listeners, which is useful for Host-local players and
	# also lets a Client show its own visual-only effect immediately.
	if _deliver_local_message(_get_self_steam_id(), message):
		delivered_or_sent = true

	if not is_online():
		return delivered_or_sent

	if is_host():
		for steam_id_value in _get_remote_member_steam_ids():
			var steam_id = str(steam_id_value)
			if steam_id == "" or steam_id == _get_self_steam_id():
				continue
			if _send_wire_to_steam_id(steam_id, message, _get_reliable_option(options)):
				delivered_or_sent = true
		return delivered_or_sent

	var host_steam_id = _get_host_steam_id()
	if host_steam_id == "":
		return delivered_or_sent
	var relay = message.duplicate(true)
	relay["bo_api_broadcast_request"] = true
	if _send_wire_to_steam_id(host_steam_id, relay, _get_reliable_option(options)):
		delivered_or_sent = true
	return delivered_or_sent


func receive_mod_message(from_steam_id: String, message: Dictionary) -> void:
	if typeof(message) != TYPE_DICTIONARY:
		return
	if str(message.get("msg_type", "")) != MSG_TYPE_MOD_MESSAGE:
		return
	if int(message.get("api_version", API_VERSION)) > API_VERSION:
		return
	if not _message_battle_id_is_current(message):
		return

	if is_host() and bool(message.get("bo_api_broadcast_request", false)) and not bool(message.get("bo_api_relayed", false)):
		_handle_broadcast_relay(from_steam_id, message)
		return

	if is_host() and message.has("bo_api_target_player_index") and not bool(message.get("bo_api_relayed", false)):
		_handle_target_relay(from_steam_id, message)
		return

	_deliver_local_message(from_steam_id, message)


func _handle_broadcast_relay(from_steam_id: String, message: Dictionary) -> void:
	_deliver_local_message(from_steam_id, message)
	var reliable = bool(message.get("reliable", true))
	for steam_id_value in _get_remote_member_steam_ids():
		var target_steam_id = str(steam_id_value)
		if target_steam_id == "" or target_steam_id == _get_self_steam_id() or target_steam_id == from_steam_id:
			continue
		var relayed = message.duplicate(true)
		relayed.erase("bo_api_broadcast_request")
		relayed.erase("bo_api_target_player_index")
		relayed["bo_api_relayed"] = true
		relayed["relay_from_steam_id"] = from_steam_id
		_send_wire_to_steam_id(target_steam_id, relayed, reliable)


func _handle_target_relay(from_steam_id: String, message: Dictionary) -> void:
	var player_index = int(message.get("bo_api_target_player_index", -1))
	if player_index < 0:
		return
	if owns_player(player_index):
		_deliver_local_message(from_steam_id, message)
		return
	var target_steam_id = _get_remote_steam_id_for_player(player_index)
	if target_steam_id == "" or target_steam_id == from_steam_id:
		return
	var relayed = message.duplicate(true)
	relayed.erase("bo_api_broadcast_request")
	relayed.erase("bo_api_target_player_index")
	relayed["bo_api_relayed"] = true
	relayed["relay_from_steam_id"] = from_steam_id
	_send_wire_to_steam_id(target_steam_id, relayed, bool(message.get("reliable", true)))


func _deliver_local_message(from_steam_id: String, message: Dictionary) -> bool:
	if typeof(message) != TYPE_DICTIONARY:
		return false
	if str(message.get("msg_type", "")) != MSG_TYPE_MOD_MESSAGE:
		return false
	if not _message_battle_id_is_current(message):
		return false
	var payload = message.get("payload", {})
	if typeof(payload) != TYPE_DICTIONARY:
		payload = {}
	var source_steam_id = str(message.get("relay_from_steam_id", from_steam_id))
	var meta = {
		"from_player_index": _get_player_index_for_steam_id(source_steam_id),
		"from_role": _get_role_for_steam_id(source_steam_id),
		"scope": str(message.get("scope", SCOPE_MENU))
	}
	emit_signal("mod_message_received", str(message.get("mod_id", "")), str(message.get("route", "")), payload, meta)
	return true


func _make_wire_message(mod_id: String, route: String, payload: Dictionary, options: Dictionary) -> Dictionary:
	var scope = str(options.get("scope", SCOPE_MENU))
	if scope != SCOPE_BATTLE:
		scope = SCOPE_MENU
	var wire = {
		"msg_type": MSG_TYPE_MOD_MESSAGE,
		"api_version": API_VERSION,
		"mod_id": mod_id,
		"route": route,
		"scope": scope,
		"payload": payload.duplicate(true),
		"reliable": _get_reliable_option(options)
	}
	if scope == SCOPE_BATTLE:
		wire["battle_id"] = _get_battle_id()
	return wire


func _is_valid_outgoing(mod_id: String, route: String, payload: Dictionary) -> bool:
	if mod_id == "" or route == "":
		return false
	return typeof(payload) == TYPE_DICTIONARY


func _get_reliable_option(options: Dictionary) -> bool:
	return bool(options.get("reliable", true))


func _message_battle_id_is_current(message: Dictionary) -> bool:
	if str(message.get("scope", SCOPE_MENU)) != SCOPE_BATTLE:
		return true
	if not message.has("battle_id"):
		return true
	var packet_battle_id = int(message.get("battle_id", 0))
	var current_battle_id = _get_battle_id()
	if packet_battle_id <= 0 or current_battle_id <= 0:
		return true
	return packet_battle_id == current_battle_id


func _poll_phase_and_slots() -> void:
	var phase = get_phase()
	var context = get_context()
	if phase != _last_phase:
		var old_phase = _last_phase
		_last_phase = phase
		_last_context = context
		emit_signal("phase_changed", old_phase, phase, context)

	var slot_key = _make_slot_key(context.get("local_player_indices", []))
	if slot_key != _last_slot_key:
		_last_slot_key = slot_key
		_last_context = context
		emit_signal("slot_layout_changed", context)


func _make_slot_key(indices: Array) -> String:
	var parts = []
	for value in indices:
		parts.append(str(int(value)))
	return ",".join(parts)


func _get_role() -> String:
	if not is_online():
		return "offline"
	if is_host():
		return "host"
	if is_client():
		return "client"
	return "offline"


func _get_role_for_steam_id(steam_id: String) -> String:
	if not is_online():
		return "offline"
	var host_id = _get_host_steam_id()
	if steam_id != "" and host_id != "" and steam_id == host_id:
		return "host"
	if steam_id != "" and steam_id == _get_self_steam_id():
		return _get_role()
	return "client"


func _get_current_wave() -> int:
	if typeof(RunData) == TYPE_NIL:
		return 0
	return int(RunData.get("current_wave"))


func _get_battle_id() -> int:
	var steam_manager = _get_steam_lobby_manager()
	if steam_manager != null and steam_manager.has_method("bo_api_get_battle_id"):
		var id = int(steam_manager.bo_api_get_battle_id())
		if id > 0:
			return id
	# Do not fall back to current_scene instance id while online: Host and Client have
	# different local instance ids, which would make valid battle-scope mod packets
	# look stale. A zero battle_id is accepted by the stale-packet guard.
	return 0


func _get_player_index_for_steam_id(steam_id: String) -> int:
	if steam_id == "":
		return -1
	if steam_id == _get_self_steam_id():
		var local_indices = get_local_player_indices()
		if not local_indices.empty():
			return int(local_indices[0])
	var steam_manager = _get_steam_lobby_manager()
	if steam_manager != null and steam_manager.has_method("bo_api_get_player_index_for_steam_id"):
		var idx = int(steam_manager.bo_api_get_player_index_for_steam_id(steam_id))
		if idx >= 0:
			return idx
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("get_player_index_for_steam_id"):
		return int(slot_manager.get_player_index_for_steam_id(steam_id))
	return -1


func _get_remote_steam_id_for_player(player_index: int) -> String:
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("get_remote_steam_id"):
		return str(slot_manager.get_remote_steam_id(player_index))
	return ""


func _get_self_steam_id() -> String:
	var steam_manager = _get_steam_lobby_manager()
	if steam_manager != null and steam_manager.has_method("bo_api_get_self_steam_id"):
		return str(steam_manager.bo_api_get_self_steam_id())
	return ""


func _get_host_steam_id() -> String:
	var steam_manager = _get_steam_lobby_manager()
	if steam_manager != null and steam_manager.has_method("bo_api_get_host_steam_id"):
		return str(steam_manager.bo_api_get_host_steam_id())
	return ""


func _get_remote_member_steam_ids() -> Array:
	var steam_manager = _get_steam_lobby_manager()
	if steam_manager != null and steam_manager.has_method("bo_api_get_remote_member_steam_ids"):
		var ids = steam_manager.bo_api_get_remote_member_steam_ids()
		if typeof(ids) == TYPE_ARRAY:
			return ids
	return []


func _send_wire_to_steam_id(target_steam_id: String, message: Dictionary, reliable: bool) -> bool:
	var steam_manager = _get_steam_lobby_manager()
	if steam_manager == null:
		return false
	if steam_manager.has_method("bo_api_send_to_steam_id"):
		return bool(steam_manager.bo_api_send_to_steam_id(target_steam_id, message, reliable))
	return false


func _is_progression_visible(menu_sync: Node) -> bool:
	# Keep this cheap: get_phase() is polled by the public API, so do not recursively
	# scan the battle tree here. MenuSync already caches the direct progression UI.
	if menu_sync != null and menu_sync.has_method("_find_progression_ui"):
		var ui = menu_sync._find_progression_ui(false)
		return ui != null and is_instance_valid(ui) and ui is CanvasItem and bool(ui.visible)
	return false


func _is_run_end_visible() -> bool:
	var scene = get_tree().current_scene if get_tree() != null else null
	if scene == null:
		return false
	var scene_path = str(scene.filename).to_lower()
	var scene_name = str(scene.name).to_lower()
	return scene_path.find("end") != -1 or scene_name.find("end") != -1 or scene_name.find("victory") != -1 or scene_name.find("defeat") != -1


func _get_steam_lobby_manager() -> Node:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineSteamLobbyManager")


func _get_menu_sync_manager() -> Node:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineMenuSyncManager")


func _get_slot_manager() -> Node:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineOnlinePlayerSlotManager")
