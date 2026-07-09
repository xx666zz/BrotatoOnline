extends Node

# Design goal:
# - Do not patch Brotato Player / Unit / PlayerMovementBehavior.
# - Client sends local input only.
# - Host maps sender steam_id -> official COOP player_index, then injects actions into
#   that player's official placeholder device, so Brotato's original movement code still runs.


const SEND_INTERVAL_MSEC = 33
const HEARTBEAT_INTERVAL_MSEC = 150
const REMOTE_INPUT_TIMEOUT_MSEC = 300
const ACTION_DEADZONE = 0.15


var _last_send_msec = 0
var _last_heartbeat_msec = 0
var _last_sent_key = ""
var _local_tick = 0

# player_index -> {"move": Vector2, "aim": Vector2, "tick": int, "last_seen_msec": int}
var _remote_input_by_player = {}

# player_index -> {action_name: true}
var _held_actions_by_player = {}


func _ready() -> void:
	set_process(true)
	set_physics_process(true)


func _process(_delta: float) -> void:
	# 不在这里自动发包，因为实际 P2P 发送函数在 steam_lobby_manager.gd 里。
	# steam_lobby_manager 每帧/定时调用 consume_local_battle_input_messages() 即可。
	pass


func _physics_process(_delta: float) -> void:
	if not _is_in_authoritative_game_context():
		_release_all_remote_actions()
		return

	if not _is_host():
		return

	_apply_remote_inputs_to_official_actions()

func receive_battle_input(from_steam_id: String, message: Dictionary) -> void:
	# Host side. Called by SteamLobbyManager when a P2P message arrives.
	if not _is_host():
		return
	if typeof(message) != TYPE_DICTIONARY:
		return
	if str(message.get("msg_type", "")) != "battle_input":
		return

	var slot_manager = _get_slot_manager()
	if slot_manager == null or not slot_manager.has_method("get_player_index_for_steam_id"):
		return

	var player_index = int(slot_manager.get_player_index_for_steam_id(from_steam_id))
	if player_index < 0 or player_index >= RunData.get_player_count():
		return

	# 防止把 Host 本地玩家输入也当作远程输入覆盖。
	if slot_manager.has_method("is_remote_player_index") and not bool(slot_manager.is_remote_player_index(player_index)):
		return

	var move = _sanitize_vector(_dict_to_vec(message.get("move", {})))
	var aim = _sanitize_vector(_dict_to_vec(message.get("aim", {})))
	var tick = int(message.get("tick", 0))

	_remote_input_by_player[player_index] = {
		"move": move,
		"aim": aim,
		"tick": tick,
		"last_seen_msec": OS.get_ticks_msec()
	}


func clear_remote_inputs() -> void:
	_remote_input_by_player.clear()
	_release_all_remote_actions()


func _apply_remote_inputs_to_official_actions() -> void:
	var now = OS.get_ticks_msec()
	var active_players = {}

	for player_index in _remote_input_by_player.keys():
		var input_state = _remote_input_by_player[player_index]
		if typeof(input_state) != TYPE_DICTIONARY:
			continue

		var age = now - int(input_state.get("last_seen_msec", 0))
		var move = input_state.get("move", Vector2.ZERO)
		var aim = input_state.get("aim", Vector2.ZERO)
		if age > REMOTE_INPUT_TIMEOUT_MSEC:
			move = Vector2.ZERO
			aim = Vector2.ZERO

		var device = CoopService.get_remapped_player_device(int(player_index))
		if device < 0:
			_release_player_actions(int(player_index))
			continue

		_apply_vector_to_device_actions(int(player_index), device, "button_move_", move)
		_apply_vector_to_device_actions(int(player_index), device, "analog_move_", move)
		_apply_vector_to_device_actions(int(player_index), device, "rjoy_", aim)
		active_players[int(player_index)] = true

	# 远程槽位消失或离开游戏后，释放旧 action，避免卡住一直移动。
	for held_player_index in _held_actions_by_player.keys():
		if not active_players.has(int(held_player_index)):
			_release_player_actions(int(held_player_index))


func _apply_vector_to_device_actions(player_index: int, device: int, prefix: String, vec: Vector2) -> void:
	var left_action = prefix + "left_" + str(device)
	var right_action = prefix + "right_" + str(device)
	var up_action = prefix + "up_" + str(device)
	var down_action = prefix + "down_" + str(device)

	_set_action(player_index, left_action, vec.x < -ACTION_DEADZONE, abs(vec.x))
	_set_action(player_index, right_action, vec.x > ACTION_DEADZONE, abs(vec.x))
	_set_action(player_index, up_action, vec.y < -ACTION_DEADZONE, abs(vec.y))
	_set_action(player_index, down_action, vec.y > ACTION_DEADZONE, abs(vec.y))


func _set_action(player_index: int, action_name: String, pressed: bool, strength: float = 1.0) -> void:
	var held = _held_actions_by_player.get(player_index, {})
	if typeof(held) != TYPE_DICTIONARY:
		held = {}

	if pressed:
		Input.action_press(action_name, clamp(strength, 0.0, 1.0))
		held[action_name] = true
	else:
		if bool(held.get(action_name, false)):
			Input.action_release(action_name)
			held.erase(action_name)

	if held.empty():
		_held_actions_by_player.erase(player_index)
	else:
		_held_actions_by_player[player_index] = held


func _release_player_actions(player_index: int) -> void:
	var held = _held_actions_by_player.get(player_index, {})
	if typeof(held) != TYPE_DICTIONARY:
		_held_actions_by_player.erase(player_index)
		return

	for action_name in held.keys():
		Input.action_release(str(action_name))
	_held_actions_by_player.erase(player_index)


func _release_all_remote_actions() -> void:
	for player_index in _held_actions_by_player.keys():
		_release_player_actions(int(player_index))

func _get_local_player_index() -> int:
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("get_local_mirrored_player_index"):
		var idx = int(slot_manager.get_local_mirrored_player_index())
		if idx >= 0:
			return idx
	return -1


func _is_in_authoritative_game_context() -> bool:
	return _is_online_session_active() and RunData.is_coop_run and _is_in_game_scene()


func _is_in_game_scene() -> bool:
	var main_node = get_node_or_null("/root/Main")
	if main_node != null:
		return true

	var current = get_tree().current_scene
	if current == null:
		return false
	if str(current.name) == "Main":
		return true
	if current.has_node("Entities"):
		return true
	return false


func _is_online_session_active() -> bool:
	var lobby_manager = _get_lobby_manager()
	if lobby_manager == null:
		return false
	if lobby_manager.has_method("is_online_session_active"):
		return bool(lobby_manager.is_online_session_active())
	if lobby_manager.has_method("has_active_online_session"):
		return bool(lobby_manager.has_active_online_session())
	return false


func _is_host() -> bool:
	var lobby_manager = _get_lobby_manager()
	if lobby_manager == null:
		return false

	var method_names = ["is_game_host", "is_host", "is_lobby_host", "am_i_host", "get_is_host"]
	for method_name in method_names:
		if lobby_manager.has_method(method_name):
			return bool(lobby_manager.call(method_name))

	if _has_property(lobby_manager, "is_host"):
		return bool(lobby_manager.get("is_host"))
	if _has_property(lobby_manager, "_is_host"):
		return bool(lobby_manager.get("_is_host"))
	if _has_property(lobby_manager, "lobby_is_host"):
		return bool(lobby_manager.get("lobby_is_host"))

	return false


func _get_slot_manager() -> Node:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineOnlinePlayerSlotManager")


func _get_lobby_manager() -> Node:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineSteamLobbyManager")


func _has_property(obj, property_name: String) -> bool:
	if obj == null:
		return false
	var property_list = obj.get_property_list()
	for property_info in property_list:
		if typeof(property_info) == TYPE_DICTIONARY and str(property_info.get("name", "")) == property_name:
			return true
	return false


func _dict_to_vec(value) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value
	if typeof(value) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))


func _vec_to_dict(vec: Vector2) -> Dictionary:
	return {"x": float(vec.x), "y": float(vec.y)}


func _sanitize_vector(vec: Vector2) -> Vector2:
	# Godot 3.x 不用 is_finite()
	# NaN 唯一特点：不等于自身
	if vec.x != vec.x or vec.y != vec.y:
		return Vector2.ZERO

	# 防止极端异常值 / INF-like 值进入 length()
	if abs(vec.x) > 1000000.0 or abs(vec.y) > 1000000.0:
		return Vector2.ZERO

	if vec.length() > 1.0:
		return vec.normalized()

	return vec


func _vector_key(vec: Vector2) -> String:
	return str(int(round(vec.x * 100.0))) + "," + str(int(round(vec.y * 100.0)))

func consume_local_battle_input_messages() -> Array:
	var messages = []

	if _is_host():
		return messages
	if not _is_in_game_scene():
		return messages
	if not bool(RunData.is_coop_run):
		return messages

	var now = OS.get_ticks_msec()
	if now - _last_send_msec < SEND_INTERVAL_MSEC:
		return messages
	_last_send_msec = now

	var player_index = _get_local_player_index()
	var player_count = RunData.get_player_count()
	if player_index < 0 or player_index >= player_count:
		return messages

	var device = CoopService.get_remapped_player_device(player_index)
	if device < 0:
		return messages

	var move = _read_move_vector_for_device(device)
	var aim = _read_aim_vector_for_device(device)
	var key = _vector_key(move) + "|" + _vector_key(aim)
	var should_send = key != _last_sent_key or now - _last_heartbeat_msec >= HEARTBEAT_INTERVAL_MSEC
	if not should_send:
		return messages

	_last_sent_key = key
	_last_heartbeat_msec = now
	_local_tick += 1

	messages.append({
		"msg_type": "battle_input",
		"tick": _local_tick,
		"player_index": player_index,
		"move": _vec_to_dict(move),
		"aim": _vec_to_dict(aim),
		"actions": {}
	})
	return messages

func _read_move_vector_for_device(device: int) -> Vector2:
	var button_vec = Input.get_vector(
		"button_move_left_" + str(device),
		"button_move_right_" + str(device),
		"button_move_up_" + str(device),
		"button_move_down_" + str(device)
	)
	var analog_vec = Input.get_vector(
		"analog_move_left_" + str(device),
		"analog_move_right_" + str(device),
		"analog_move_up_" + str(device),
		"analog_move_down_" + str(device)
	)
	var result = button_vec
	if analog_vec.length() > button_vec.length():
		result = analog_vec
	return _sanitize_vector(result)

func _read_aim_vector_for_device(device: int) -> Vector2:
	var aim = Input.get_vector(
		"rjoy_left_" + str(device),
		"rjoy_right_" + str(device),
		"rjoy_up_" + str(device),
		"rjoy_down_" + str(device)
	)
	return _sanitize_vector(aim)
