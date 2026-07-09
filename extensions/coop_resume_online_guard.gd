extends "res://ui/menus/shop/coop_resume.gd"

# BrotatoOnline guard for the official Continue / CoopResume screen.
# Vanilla CoopResume advances once for every connected_players_updated signal.
# Online slot sync may emit several layout-only updates for one Steam member join
# (host slot repair, stale placeholder removal, remote placeholder insertion, etc.).
# In online sessions, advance the official resume UI only when the actual
# connected online COOP slot count increases. Offline/local coop keeps the vanilla path.

const BO_STEAM_LOBBY_MANAGER_PATH = "ModLoader/six666-BrotatoOnline/BrotatoOnlineSteamLobbyManager"
const BO_SLOT_MANAGER_PATH = "ModLoader/six666-BrotatoOnline/BrotatoOnlinePlayerSlotManager"

var _bo_last_resume_target_connected: = -1


func _bo_is_online_session_active() -> bool:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return false
	return bool(tree.root.get_meta("brotato_online_session_active", false))


func _bo_get_steam_lobby_manager() -> Node:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(BO_STEAM_LOBBY_MANAGER_PATH)


func _bo_get_slot_manager() -> Node:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(BO_SLOT_MANAGER_PATH)


func _bo_get_saved_player_count(fallback_connected_count: int) -> int:
	if RunData != null and RunData.has_method("get_player_count"):
		return int(RunData.get_player_count())
	return fallback_connected_count


func _bo_get_online_present_player_count(fallback_connected_count: int, total_players: int) -> int:
	# Continue must progress according to the COOP slots that are actually present,
	# not only Steam lobby members.  Steam member data can lag behind the slot repair
	# by a few frames: the Host log then shows device 1 being added, but CoopResume
	# still thinks only one player is present and never enters CoopShop.
	# Count only real local slots and tracked online remote placeholders; this keeps
	# duplicate/layout-only emits from auto-accepting a 4P save.
	var slot_manager = _bo_get_slot_manager()
	if slot_manager != null and is_instance_valid(slot_manager):
		var counted_devices = []
		var present_count = 0
		for i in range(CoopService.connected_players.size()):
			var player = CoopService.connected_players[i]
			if typeof(player) != TYPE_ARRAY or player.size() < 2:
				continue
			var device = int(player[0])
			if counted_devices.has(device):
				continue
			var is_tracked_remote = false
			if slot_manager.has_method("is_remote_player_index"):
				is_tracked_remote = bool(slot_manager.is_remote_player_index(i))
			var is_real_local = device == CoopService.KEYBOARD_REMAPPED_DEVICE_ID or device == CoopService.GAMEPAD_REMAPPED_DEVICE_ID
			if not is_tracked_remote and not is_real_local:
				continue
			counted_devices.append(device)
			present_count += 1
		if present_count > 0:
			return int(clamp(present_count, 0, max(1, total_players)))

	return int(clamp(fallback_connected_count, 0, max(1, total_players)))


func _bo_get_resume_accepted_player_count(total_players: int) -> int:
	# Vanilla _ready() calls _setup_next_player() once immediately, which displays
	# the first pending saved player. That displayed player is not accepted yet.
	var remaining = _players_to_join.size() if typeof(_players_to_join) == TYPE_ARRAY else 0
	return int(clamp(total_players - 1 - remaining, 0, total_players))


func _on_connected_players_updated(_connected_players: Array) -> void:
	if not _bo_is_online_session_active():
		._on_connected_players_updated(_connected_players)
		return

	var total_players = _bo_get_saved_player_count(_connected_players.size())
	if total_players <= 1:
		._on_connected_players_updated(_connected_players)
		return

	var target_connected = _bo_get_online_present_player_count(_connected_players.size(), total_players)
	var accepted = _bo_get_resume_accepted_player_count(total_players)

	# Ignore duplicate/layout-only emissions. This is the important part: Steam slot
	# repair must not pop multiple saved players from vanilla CoopResume.
	if target_connected <= accepted:
		return

	# If Steam member data is temporarily unavailable and CoopService falls back to a
	# smaller count, never move backwards. This avoids a later duplicate signal from
	# being interpreted as a new player after the member list catches up.
	if _bo_last_resume_target_connected >= 0 and target_connected < _bo_last_resume_target_connected:
		target_connected = _bo_last_resume_target_connected
	_bo_last_resume_target_connected = target_connected

	while accepted < target_connected:
		_setup_next_player()
		accepted += 1
		# _setup_next_player() changes scene when the last saved player is accepted.
		# Stop immediately so duplicate signals cannot run resume work on a stale node.
		if not is_inside_tree() or get_tree() == null or get_tree().current_scene != self:
			break
