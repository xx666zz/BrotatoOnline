extends "res://ui/menus/ingame/pause_menu.gd"

# Godot 3.x has no OS.get_controller_count(). More importantly, an online
# RunData player count includes remote slots, so it must never be compared with
# this machine's physical controller count when deciding pause-menu ownership.


func on_game_lost_focus() -> void:
	var tree = get_tree()
	if tree == null:
		return

	if not tree.paused and ProgressData.settings.pause_on_focus_lost:
		var pause_owner = 0
		if _brotato_online_is_online_session_active():
			pause_owner = _brotato_online_get_local_player_index(_player_index)
		_player_index = pause_owner
		pause(pause_owner)

	if not tree.paused or not RunData.is_coop_run or _player_index <= 0:
		return

	# Remote players are represented in RunData/CoopService as player slots, but
	# they are not local joypads. Keep the current local online owner unchanged.
	if _brotato_online_is_online_session_active():
		return

	# Offline/local COOP fallback: transfer ownership only when a local gamepad is
	# actually missing. Input.get_connected_joypads() is the Godot 3.x API.
	var expected_gamepads = _brotato_online_get_expected_local_gamepad_count()
	var connected_gamepads = Input.get_connected_joypads().size()
	if connected_gamepads < expected_gamepads:
		_brotato_online_set_pause_owner(0)


func _brotato_online_is_online_session_active() -> bool:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return false
	return bool(tree.root.get_meta("brotato_online_session_active", false))


func _brotato_online_get_local_player_index(fallback_index: int) -> int:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return fallback_index if fallback_index >= 0 else 0

	var manager = tree.root.get_node_or_null(
		"ModLoader/six666-BrotatoOnline/BrotatoOnlineOnlinePlayerSlotManager"
	)
	if manager == null:
		return fallback_index if fallback_index >= 0 else 0

	if manager.has_method("get_local_mirrored_player_index"):
		var mirrored_index = int(manager.get_local_mirrored_player_index())
		if mirrored_index >= 0:
			return mirrored_index

	if manager.has_method("get_local_player_indices"):
		var local_indices = manager.get_local_player_indices()
		if typeof(local_indices) == TYPE_ARRAY and not local_indices.empty():
			return int(local_indices[0])

	return fallback_index if fallback_index >= 0 else 0


func _brotato_online_get_expected_local_gamepad_count() -> int:
	var count = 0
	for player in CoopService.connected_players:
		if typeof(player) != TYPE_ARRAY or player.size() < 2:
			continue
		if int(player[1]) != CoopService.PlayerType.KEYBOARD_AND_MOUSE:
			count += 1
	return count


func _brotato_online_set_pause_owner(player_index: int) -> void:
	_player_index = player_index
	if _focus_emulator != null and is_instance_valid(_focus_emulator):
		_focus_emulator.player_index = player_index
	if _menus != null and is_instance_valid(_menus):
		_menus.reset()
	if _main_menu != null and is_instance_valid(_main_menu):
		_main_menu.init(player_index)
