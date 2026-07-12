extends Node


const MAX_REMOTE_PLAYERS = 3
const RESTORE_CHECK_INTERVAL_MSEC = 500
# Remote placeholders must use vanilla-mapped device ids.
# InputService creates ui_* / button_* actions for remapped devices 0..7.
# 7 is the local keyboard. Vanilla local gamepads are remapped from the high end
# (normally 6, then 5, 4, ...), so remote placeholders use the low free ids.
# Always check CoopService.is_device_assigned() before using one, because Host may
# have several local controllers in the same online run.
const REMOTE_PLACEHOLDER_DEVICE_IDS = [1, 2, 3]
const REMOTE_PLACEHOLDER_PLAYER_TYPE = CoopService.PlayerType.GAMEPAD_XBOX
const META_AUTO_JOIN_HOST_PLAYER = "brotato_online_auto_join_host_player"

const BO_SLOT_DIAG_ENABLED = true
# Slot logs are for finding stalls only.  Low-frequency, low-cost restore checks
# and normal emits are silent; expensive calls or repeated medium-cost calls are kept.
const BO_SLOT_DIAG_SINGLE_COST_USEC = 8000
const BO_SLOT_DIAG_BURST_COST_USEC = 2500
const BO_SLOT_DIAG_BURST_TOTAL_USEC = 16000
const BO_SLOT_DIAG_BURST_COUNT = 5
const BO_SLOT_DIAG_BURST_WINDOW_MSEC = 2000

var _bo_slot_diag_emit_count = 0
var _bo_slot_diag_cost_stats_by_scope = {}
var _bo_slot_diag_last_state_key_by_tag = {}
var _bo_slot_diag_last_state_msec_by_tag = {}


var _last_restore_check_time = 0
var _remote_steam_id_by_device = {}
var _device_by_remote_steam_id = {}
var _remote_devices = []
var _host_player_joined_by_manager = false
var _local_mirrored_steam_id = ""
var _local_mirrored_player_index = -1
var _online_run_slots_locked = false
var _mirrored_connected_players = []
var _pending_offline_reset_reason = ""
var _last_mirror_restore_log_msec = 0
var _bo_resume_emit_scene_id = 0
var _bo_resume_last_emitted_count = -1



func _bo_slot_diag_log(tag: String, msg: String) -> void:
	if not BO_SLOT_DIAG_ENABLED:
		return
	print("[BO_LAG][SLOT][" + tag + "] " + msg)


func _bo_slot_diag_players() -> String:
	var parts = []
	for i in range(CoopService.connected_players.size()):
		var p = CoopService.connected_players[i]
		if typeof(p) == TYPE_ARRAY and p.size() >= 2:
			parts.append("P" + str(i) + "{dev=" + str(p[0]) + ",type=" + str(p[1]) + "}")
		else:
			parts.append("P" + str(i) + "{" + str(p) + "}")
	return "[" + ";".join(parts) + "]"


func _bo_slot_diag_maps() -> String:
	return "remote_by_dev=" + str(_remote_steam_id_by_device) + " device_by_steam=" + str(_device_by_remote_steam_id) + " remote_devices=" + str(_remote_devices) + " mirror_idx=" + str(_local_mirrored_player_index) + " mirror=" + str(_mirrored_connected_players)


func _bo_slot_diag_context(extra: String = "") -> String:
	var parts = []
	parts.append("locked=" + str(_is_slot_mutation_locked()))
	parts.append("online_locked=" + str(_online_run_slots_locked))
	parts.append("run_players=" + str(RunData.get_player_count() if RunData.has_method("get_player_count") else -1))
	parts.append("players=" + _bo_slot_diag_players())
	if extra != "":
		parts.append(extra)
	return " ".join(parts)


func _bo_slot_diag_cost(scope: String, start_usec: int, extra: String = "") -> void:
	if not BO_SLOT_DIAG_ENABLED:
		return
	var cost = OS.get_ticks_usec() - start_usec
	var now = OS.get_ticks_msec()
	if cost >= BO_SLOT_DIAG_SINGLE_COST_USEC:
		_bo_slot_diag_log("SLOW", "scope=" + scope + " us=" + str(cost) + " " + _bo_slot_diag_context(extra))
		return
	if cost < BO_SLOT_DIAG_BURST_COST_USEC:
		return
	var stats = _bo_slot_diag_cost_stats_by_scope.get(scope, {})
	if typeof(stats) != TYPE_DICTIONARY or stats.empty() or now - int(stats.get("start_msec", now)) > BO_SLOT_DIAG_BURST_WINDOW_MSEC:
		stats = {"start_msec": now, "count": 0, "total_usec": 0, "max_usec": 0, "last_log_msec": 0}
	stats["count"] = int(stats.get("count", 0)) + 1
	stats["total_usec"] = int(stats.get("total_usec", 0)) + cost
	stats["max_usec"] = max(int(stats.get("max_usec", 0)), cost)
	_bo_slot_diag_cost_stats_by_scope[scope] = stats
	var should_log = int(stats.get("count", 0)) >= BO_SLOT_DIAG_BURST_COUNT or int(stats.get("total_usec", 0)) >= BO_SLOT_DIAG_BURST_TOTAL_USEC
	if not should_log:
		return
	if now - int(stats.get("last_log_msec", 0)) < BO_SLOT_DIAG_BURST_WINDOW_MSEC:
		return
	stats["last_log_msec"] = now
	_bo_slot_diag_cost_stats_by_scope[scope] = stats
	_bo_slot_diag_log("BURST", "scope=" + scope + " count=" + str(stats.get("count", 0)) + " total_us=" + str(stats.get("total_usec", 0)) + " max_us=" + str(stats.get("max_usec", 0)) + " window_ms=" + str(now - int(stats.get("start_msec", now))) + " " + _bo_slot_diag_context(extra))


func _bo_slot_diag_state_change(tag: String, key: String, msg: String) -> void:
	if not BO_SLOT_DIAG_ENABLED:
		return
	var now = OS.get_ticks_msec()
	var last_key = str(_bo_slot_diag_last_state_key_by_tag.get(tag, ""))
	var last_msec = int(_bo_slot_diag_last_state_msec_by_tag.get(tag, 0))
	if key == last_key and now - last_msec < BO_SLOT_DIAG_BURST_WINDOW_MSEC:
		return
	_bo_slot_diag_last_state_key_by_tag[tag] = key
	_bo_slot_diag_last_state_msec_by_tag[tag] = now
	_bo_slot_diag_log(tag, msg)


func _bo_slot_diag_emit(reason: String) -> void:
	if not BO_SLOT_DIAG_ENABLED:
		return
	_bo_slot_diag_emit_count += 1
	# Normal connected_players emits are low-frequency and cheap.  Only log emits
	# that happen while the slot topology is locked, because those can explain input
	# ownership stalls or phantom player changes.
	if not _is_slot_mutation_locked() and not _online_run_slots_locked:
		return
	var key = reason + ":" + str(_bo_slot_diag_emit_count) + ":" + str(CoopService.connected_players.size()) + ":" + str(_online_run_slots_locked)
	_bo_slot_diag_state_change("EMIT_WHILE_LOCKED", key, "count=" + str(_bo_slot_diag_emit_count) + " reason=" + reason + " " + _bo_slot_diag_context("maps=" + _bo_slot_diag_maps()))


func _bo_emit_connected_players_updated(reason: String) -> void:
	if _is_online_session_active() and _is_in_official_coop_resume_scene():
		var scene_id = 0
		var tree = get_tree()
		if tree != null and tree.current_scene != null:
			scene_id = tree.current_scene.get_instance_id()
		if scene_id != _bo_resume_emit_scene_id:
			_bo_resume_emit_scene_id = scene_id
			_bo_resume_last_emitted_count = -1
		var count = int(CoopService.connected_players.size())
		# CoopResume advances one saved player for each connected_players_updated signal.
		# While in that scene, only forward real count increases; layout repairs with
		# the same count would otherwise auto-accept multiple saved players.
		if count <= _bo_resume_last_emitted_count:
			_bo_slot_diag_state_change("RESUME_EMIT_SKIP", reason + ":" + str(count), "reason=" + reason + " count=" + str(count) + " last=" + str(_bo_resume_last_emitted_count) + " " + _bo_slot_diag_context("maps=" + _bo_slot_diag_maps()))
			return
		_bo_resume_last_emitted_count = count
	else:
		_bo_resume_emit_scene_id = 0
		_bo_resume_last_emitted_count = -1
	_bo_slot_diag_emit(reason)
	CoopService.emit_signal("connected_players_updated", CoopService.connected_players)


func _bo_slot_diag_periodic(reason: String) -> void:
	# Disabled by policy: periodic restore checks are only useful when they are slow,
	# and _bo_slot_diag_cost() records those.
	return


func _ready() -> void:
	set_process(true)


func _is_in_official_coop_resume_scene() -> bool:
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var filename = str(tree.current_scene.filename).to_lower()
	var node_name = str(tree.current_scene.name).to_lower()
	return filename == "res://ui/menus/shop/coop_resume.tscn" or filename.find("coop_resume") != -1 or node_name.find("coopresume") != -1 or node_name.find("coop_resume") != -1


func _is_in_active_online_run_scene() -> bool:
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var filename = str(tree.current_scene.filename).to_lower()
	var node_name = str(tree.current_scene.name).to_lower()
	if filename == "res://main.tscn":
		return true
	if _is_in_official_coop_resume_scene():
		return false
	if filename.find("/shop") != -1 or filename.find("shop/") != -1:
		return true
	if node_name.find("shop") != -1:
		return true
	return false


func _is_slot_mutation_locked() -> bool:
	# CoopResume is the official Continue reconnect screen. Keep battle/shop slot
	# protection everywhere else, but allow SteamLobbyManager to reinsert remote
	# placeholders here so Host can jump back to P2/P3/P4 and the client can enter.
	if _is_in_official_coop_resume_scene():
		return false
	return _online_run_slots_locked or _is_in_active_online_run_scene()


func _is_online_session_active() -> bool:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return false
	return bool(tree.root.get_meta("brotato_online_session_active", false))


func _get_auto_join_host_player_enabled() -> bool:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return true
	return bool(tree.root.get_meta(META_AUTO_JOIN_HOST_PLAYER, true))


func on_online_settings_changed() -> void:
	if not _is_online_session_active():
		return
	if not _get_auto_join_host_player_enabled():
		return
	if _is_slot_mutation_locked():
		return
	_ensure_host_player_joined()
	_sync_run_data_player_count()
	_refresh_current_character_selection_layout()
	dump_slots()


func _process(_delta: float) -> void:
	var now = OS.get_ticks_msec()
	if now - _last_restore_check_time >= RESTORE_CHECK_INTERVAL_MSEC:
		_last_restore_check_time = now
		if _pending_offline_reset_reason != "" and not _is_in_active_online_run_scene():
			var pending_reason = _pending_offline_reset_reason
			_pending_offline_reset_reason = ""
			online_reset_to_offline(pending_reason)
			return
		_bo_slot_diag_periodic("restore_check")
		var t_restore = OS.get_ticks_usec()
		_restore_tracked_coop_players_if_needed()
		_bo_slot_diag_cost("restore_check", t_restore)


func set_online_run_slots_locked(locked: bool) -> void:
	if _online_run_slots_locked == locked:
		return
	_online_run_slots_locked = locked


func are_online_run_slots_locked() -> bool:
	return _online_run_slots_locked


func online_sync_remote_steam_ids(remote_steam_ids: Array) -> void:
	if _is_slot_mutation_locked():
		return
	_pending_offline_reset_reason = ""
	# Host 侧由 SteamLobbyManager 调用。
	# 目标：Steam lobby 成员变化后，保持 CoopService.connected_players 与远程 Steam 成员一致。
	# 先清掉没有 Steam 映射的旧远程占位槽，避免空房间里 device=1/2/3
	# 被误当成本地 P0，导致键盘/手柄只能新增角色不能控制第一个角色。
	_remove_untracked_remote_placeholder_slots()
	var normalized_ids = []
	for steam_id_value in remote_steam_ids:
		var steam_id = str(steam_id_value)
		if steam_id == "" or normalized_ids.has(steam_id):
			continue
		normalized_ids.append(steam_id)

	_ensure_coop_mode_if_possible()

	# 先移除已经离开 lobby 的远程玩家。
	var existing_ids = _device_by_remote_steam_id.keys()
	for existing_id in existing_ids:
		if not normalized_ids.has(str(existing_id)):
			_remove_remote_steam_id(str(existing_id))

	# Default path: keep Host P0 present before any remote placeholder is inserted.
	# If the user disables this compatibility switch, do not auto-create P0; in that
	# mode the host must manually join/confirm Player 1 with the intended input
	# device before remote players enter. This keeps the old manual fallback without
	# making it the default.
	var auto_join_host_player = _get_auto_join_host_player_enabled()
	if auto_join_host_player:
		_ensure_host_player_joined()

	if normalized_ids.empty():
		_sync_run_data_player_count()
		_refresh_current_character_selection_layout()
		dump_slots()
		return

	if not auto_join_host_player and _get_existing_local_player_index() < 0:
		# Manual mode safety: remote placeholders before Host P0 can reproduce the
		# stale-character/focus bug. Keep the Steam lobby open, but wait for Host P1
		# to be inserted by vanilla input before accepting remote slots.
		_sync_run_data_player_count()
		_refresh_current_character_selection_layout()
		dump_slots()
		return

	# 再添加新加入 lobby 的远程玩家。
	for steam_id in normalized_ids:
		_add_remote_steam_id(steam_id)

	_sync_run_data_player_count()
	_refresh_current_character_selection_layout()
	dump_slots()


func online_clear_remote_players() -> void:
	_mirrored_connected_players.clear()
	_local_mirrored_player_index = -1
	_local_mirrored_steam_id = ""
	var existing_ids = _device_by_remote_steam_id.keys()
	for steam_id in existing_ids:
		_remove_remote_steam_id(str(steam_id))

	_sync_run_data_player_count()
	_refresh_current_character_selection_layout()
	dump_slots()


func online_reset_to_offline(reason: String = "") -> void:
	# Leaving a Steam lobby must also release the local COOP topology that this
	# manager created for online staging. Otherwise the next CharacterSelection
	# scene can reopen in COOP with an empty/stale slot list, producing focus jumps
	# or dead input until the periodic guard repairs it.
	if _is_in_active_online_run_scene():
		_pending_offline_reset_reason = "deferred:" + reason
		dump_slots()
		return

	_pending_offline_reset_reason = ""
	var was_tracking_online_slots = _host_player_joined_by_manager or not _remote_devices.empty() or _local_mirrored_player_index >= 0 or not _mirrored_connected_players.empty()
	_online_run_slots_locked = false
	_mirrored_connected_players.clear()
	_local_mirrored_player_index = -1
	_local_mirrored_steam_id = ""
	_host_player_joined_by_manager = false

	var existing_ids = _device_by_remote_steam_id.keys()
	for steam_id in existing_ids:
		_remove_remote_steam_id(str(steam_id))
	_device_by_remote_steam_id.clear()
	_remote_steam_id_by_device.clear()
	_remote_devices.clear()

	var restored_selection_to_solo = false
	if was_tracking_online_slots:
		CoopService.connected_players.clear()
		CoopService.listening_for_inputs = false
		if RunData.has_method("set_player_count"):
			RunData.set_player_count(1)
		RunData.play_mode = RunData.PlayMode.SOLO
		RunData.set_coop_run(false)
		_bo_emit_connected_players_updated("generic_emit")
		restored_selection_to_solo = _restore_current_character_selection_to_solo()
	else:
		_sync_run_data_player_count()

	if not restored_selection_to_solo:
		_refresh_current_character_selection_layout()
	dump_slots()

func dump_slots() -> void:

	for i in range(CoopService.connected_players.size()):
		var player = CoopService.connected_players[i]
		var device = player[0]
		var player_type = player[1]
		var remote_flag = _remote_steam_id_by_device.has(device)
		var steam_id = str(_remote_steam_id_by_device.get(device, ""))



func is_remote_player_index(player_index: int) -> bool:
	if player_index < 0 or player_index >= CoopService.connected_players.size():
		return false

	var device = CoopService.connected_players[player_index][0]
	return _remote_steam_id_by_device.has(device)


func get_remote_steam_id(player_index: int) -> String:
	if player_index < 0 or player_index >= CoopService.connected_players.size():
		return ""

	var device = CoopService.connected_players[player_index][0]
	return str(_remote_steam_id_by_device.get(device, ""))


func get_player_index_for_steam_id(steam_id: String) -> int:
	if not _device_by_remote_steam_id.has(steam_id):
		return -1

	var device = int(_device_by_remote_steam_id[steam_id])
	return _get_player_index_for_device(device)


func apply_host_selection_layout(selection_state: Dictionary, self_steam_id: String, host_steam_id: String = "") -> void:
	var t_apply_layout = OS.get_ticks_usec()
	if _is_slot_mutation_locked() and _local_mirrored_player_index >= 0 and not _mirrored_connected_players.empty():
		_bo_slot_diag_log("APPLY_HOST_LAYOUT_SKIP", "reason=locked_existing_mirror self=" + self_steam_id + " host=" + host_steam_id + " players=" + _bo_slot_diag_players() + " maps=" + _bo_slot_diag_maps())
		return
	# Client 侧使用：根据 Host 广播的 selection_state 重建本地 COOP 槽位布局。
	# 目标是让客户端 UI 的 player_index 与 Host 一致：Host P0 仍显示为 P0，自己如果是 P1 就显示为 P1。
	var players = selection_state.get("players", [])
	if typeof(players) != TYPE_ARRAY or players.empty():
		return

	_ensure_coop_mode_if_possible()

	var new_connected_players = []
	var new_remote_steam_id_by_device = {}
	var new_device_by_remote_steam_id = {}
	var new_remote_devices = []

	var new_local_mirrored_player_index = -1
	var target_client_player_index = int(selection_state.get("target_client_player_index", selection_state.get("client_player_index", -1)))
	var target_client_steam_id = str(selection_state.get("target_client_steam_id", self_steam_id))
	if target_client_steam_id == "":
		target_client_steam_id = self_steam_id

	for player_data in players:
		if typeof(player_data) != TYPE_DICTIONARY:
			continue

		var player_index = int(player_data.get("player_index", new_connected_players.size()))
		while new_connected_players.size() < player_index:
			# 补洞，理论上不应该发生；保持数组下标不乱。
			var hole_device = _get_next_remote_placeholder_device_from_lists(new_remote_devices, new_connected_players)
			if hole_device < 0:
				return
			new_connected_players.append([hole_device, REMOTE_PLACEHOLDER_PLAYER_TYPE])
			new_remote_devices.append(hole_device)

		var steam_id = str(player_data.get("steam_id", ""))
		var is_self = self_steam_id != "" and steam_id == self_steam_id
		# Targeted host packets carry the authoritative player_index for this client.
		# Use it as a fallback when an early selection_state/host_*_setup arrives before
		# every players[] entry has a Steam id. This prevents P2/P3 clients from both
		# mirroring the same local slot during three-player joins.
		if not is_self and target_client_player_index >= 0 and player_index == target_client_player_index:
			if target_client_steam_id == "" or target_client_steam_id == self_steam_id:
				is_self = true
		var device = CoopService.KEYBOARD_REMAPPED_DEVICE_ID
		var player_type = CoopService.PlayerType.KEYBOARD_AND_MOUSE

		if is_self:
			# 本机真实输入必须保留真实设备。旧逻辑强制写 keyboard device=7，
			# 会让插着手柄的客户端/主机进入联机后只能用键盘槽位。
			var local_entry = _get_preferred_local_player_entry(true)
			if not local_entry.empty():
				device = int(local_entry[0])
				player_type = int(local_entry[1])
			new_local_mirrored_player_index = player_index
		else:
			# 其他玩家只是显示/槽位占位，不接本机输入；使用官方已映射的 gamepad placeholder。
			device = _get_next_remote_placeholder_device_from_lists(new_remote_devices, new_connected_players)
			if device < 0:
				continue
			player_type = REMOTE_PLACEHOLDER_PLAYER_TYPE
			new_remote_devices.append(device)
			var remote_key = steam_id
			if remote_key == "":
				# Only P0 is the host when Host omits its steam_id from selection_state.
				# Empty non-host slots must stay unique local placeholders; mapping all of
				# them to host_steam_id makes client mirrors overwrite each other.
				if player_index == 0 and host_steam_id != "":
					remote_key = host_steam_id
				else:
					remote_key = "unknown_remote_player_" + str(player_index)
			new_remote_steam_id_by_device[device] = remote_key
			new_device_by_remote_steam_id[remote_key] = device

		new_connected_players.append([device, player_type])

	if new_connected_players.empty():
		_bo_slot_diag_log("APPLY_HOST_LAYOUT_SKIP", "reason=new_empty self=" + self_steam_id + " host=" + host_steam_id + " players=" + _bo_slot_diag_players())
		return

	var connected_players_unchanged = _connected_players_match(new_connected_players)
	_bo_slot_diag_log("APPLY_HOST_LAYOUT", "unchanged=" + str(connected_players_unchanged) + " self=" + self_steam_id + " host=" + host_steam_id + " new=" + str(new_connected_players) + " old=" + _bo_slot_diag_players())

	_pending_offline_reset_reason = ""
	_local_mirrored_steam_id = self_steam_id
	_local_mirrored_player_index = new_local_mirrored_player_index
	_mirrored_connected_players = _duplicate_connected_players(new_connected_players)
	_remote_steam_id_by_device = new_remote_steam_id_by_device
	_device_by_remote_steam_id = new_device_by_remote_steam_id
	_remote_devices = new_remote_devices
	_host_player_joined_by_manager = false

	# Host selection_state is sent for focus/ready/selected changes too. The COOP slot
	# layout should only be rebuilt when the actual player/device layout changed;
	# otherwise clients repeatedly emit connected_players_updated and vanilla selection UI
	# rebuilds on every focus packet, causing stutter without visible focus jumps.
	if connected_players_unchanged:
		_sync_run_data_player_count()
		_bo_slot_diag_cost("apply_host_selection_layout_unchanged", t_apply_layout)
		return

	CoopService.connected_players.clear()
	for player in new_connected_players:
		CoopService.connected_players.append(player)

	_sync_run_data_player_count()
	_bo_emit_connected_players_updated("generic_emit")
	_refresh_current_character_selection_layout()



func get_local_mirrored_player_index() -> int:
	return _local_mirrored_player_index


func repair_mirrored_layout_now(reason: String = "") -> void:
	if _local_mirrored_player_index < 0 or _mirrored_connected_players.empty():
		return
	if _restore_mirrored_connected_players_if_needed(reason):
		# Keep the log compact; this function is called before scene transitions and by the periodic guard.
		var now = OS.get_ticks_msec()
		if now - _last_mirror_restore_log_msec >= 1000:
			_last_mirror_restore_log_msec = now
			dump_slots()


func _duplicate_connected_players(source: Array) -> Array:
	var result = []
	for player in source:
		if typeof(player) == TYPE_ARRAY and player.size() >= 2:
			result.append([int(player[0]), int(player[1])])
	return result


func _connected_players_match(expected: Array) -> bool:
	if CoopService.connected_players.size() != expected.size():
		return false
	for i in range(expected.size()):
		var expected_player = expected[i]
		if typeof(expected_player) != TYPE_ARRAY or expected_player.size() < 2:
			return false
		if i >= CoopService.connected_players.size():
			return false
		var actual_player = CoopService.connected_players[i]
		if typeof(actual_player) != TYPE_ARRAY or actual_player.size() < 2:
			return false
		if int(actual_player[0]) != int(expected_player[0]) or int(actual_player[1]) != int(expected_player[1]):
			return false
	return true


func _restore_mirrored_connected_players_if_needed(reason: String = "") -> bool:
	if _mirrored_connected_players.empty():
		return false
	if _connected_players_match(_mirrored_connected_players):
		return false

	_bo_slot_diag_log("RESTORE_MIRRORED", "reason=" + reason + " before=" + _bo_slot_diag_players() + " mirror=" + str(_mirrored_connected_players))
	CoopService.connected_players.clear()
	for player in _mirrored_connected_players:
		if typeof(player) == TYPE_ARRAY and player.size() >= 2:
			CoopService.connected_players.append([int(player[0]), int(player[1])])

	_sync_run_data_player_count()
	_bo_emit_connected_players_updated("generic_emit")
	_refresh_current_character_selection_layout()
	return true


func _add_remote_steam_id(steam_id: String) -> int:
	if steam_id == "":
		return -1

	if _device_by_remote_steam_id.has(steam_id):
		return get_player_index_for_steam_id(steam_id)

	if _remote_devices.size() >= MAX_REMOTE_PLAYERS:
		return -1

	if CoopService.connected_players.size() >= CoopService.get_max_players():
		return -1

	var device = _get_next_free_remote_device()
	if device < 0:
		return -1

	_remote_devices.append(device)
	_remote_steam_id_by_device[device] = steam_id
	_device_by_remote_steam_id[steam_id] = device
	CoopService._add_player(device, REMOTE_PLACEHOLDER_PLAYER_TYPE)
	_sync_run_data_player_count()

	var player_index = _get_player_index_for_device(device)
	return player_index


func _remove_remote_steam_id(steam_id: String) -> void:
	if not _device_by_remote_steam_id.has(steam_id):
		return

	var device = int(_device_by_remote_steam_id[steam_id])
	_device_by_remote_steam_id.erase(steam_id)
	_remote_steam_id_by_device.erase(device)
	_remote_devices.erase(device)

	if CoopService.is_device_assigned(device):
		CoopService._remove_player(device)

	_sync_run_data_player_count()


func _ensure_coop_mode_if_possible() -> void:
	if RunData.is_coop_run:
		return

	var character_selection = _find_character_selection_node()
	if character_selection != null and character_selection.has_method("_play_mode_init"):
		character_selection._play_mode_init(RunData.PlayMode.COOP, false)
		return

	RunData.play_mode = RunData.PlayMode.COOP
	RunData.set_coop_run(true)
	CoopService.listening_for_inputs = true


func _ensure_host_player_joined() -> void:
	if _is_slot_mutation_locked():
		return

	# Host/local player should be the real local input device. Do not hard-code
	# keyboard device 7: that creates a phantom keyboard character and prevents
	# a controller user from owning P0/P-local.
	_remove_untracked_remote_placeholder_slots()

	var entry = _get_preferred_local_player_entry(true)
	if entry.empty():
		return

	var host_device = int(entry[0])
	var host_type = int(entry[1])
	# Do not remove other Host-local input slots here. Opening/refreshing a Steam
	# lobby must not collapse a vanilla local-COOP setup like P1/P2/P3 controllers
	# into a single online Host player. Only replace the manager-created fallback
	# keyboard slot when it is safe.
	_maybe_replace_manager_keyboard_slot_with_gamepad()

	var local_index = _get_existing_local_player_index()
	if local_index == 0:
		return

	if local_index > 0:
		var host_player = CoopService.connected_players[local_index]
		CoopService.connected_players.remove(local_index)
		CoopService.connected_players.insert(0, host_player)
		_host_player_joined_by_manager = true
		_sync_run_data_player_count()
		_bo_emit_connected_players_updated("generic_emit")
		return

	if CoopService.is_device_assigned(host_device):
		return

	CoopService.connected_players.insert(0, [host_device, host_type])
	_host_player_joined_by_manager = true
	_sync_run_data_player_count()
	_bo_emit_connected_players_updated("generic_emit")


func _get_existing_local_player_index() -> int:
	# Online used to assume that the Host had exactly one local input (keyboard 7 or
	# first gamepad 6). In a mixed local+online room the Host may legitimately have
	# several vanilla local COOP slots, for example devices 6/5/4 plus one Steam
	# remote placeholder. Treat every non-online-placeholder slot as Host-local,
	# while still preferring the auto P1 device when we need to move a local slot to
	# index 0.
	var preferred_entry = _get_preferred_local_player_entry(true)
	if not preferred_entry.empty():
		var preferred_index = _get_player_index_for_device(int(preferred_entry[0]))
		if preferred_index >= 0 and not is_remote_player_index(preferred_index):
			return preferred_index

	var local_indices = get_local_player_indices()
	if not local_indices.empty():
		return int(local_indices[0])

	return -1


func get_local_player_indices() -> Array:
	var result = []
	for i in range(CoopService.connected_players.size()):
		if not is_remote_player_index(i):
			result.append(i)
	return result


func _prefers_local_gamepad_input() -> bool:
	var ui_device_value = null
	if UIService != null:
		ui_device_value = UIService.get("current_device")
	return ui_device_value != null and int(ui_device_value) != CoopService.PlayerType.KEYBOARD_AND_MOUSE


func _get_preferred_local_player_entry(allow_create: bool = true) -> Array:
	if not allow_create:
		return []

	# For the auto-inserted Host P1 fallback, prefer a real controller whenever one
	# is connected. This matches vanilla local-COOP expectations better than using
	# the last UI device, which often stays keyboard/mouse after opening the lobby
	# and creates a phantom keyboard P1 while the controllers become P2/P3.
	var gamepad_entry = _get_preferred_local_gamepad_entry()
	if not gamepad_entry.empty():
		return gamepad_entry

	return [CoopService.KEYBOARD_REMAPPED_DEVICE_ID, CoopService.PlayerType.KEYBOARD_AND_MOUSE]


func _get_preferred_local_gamepad_entry() -> Array:
	var joypads = Input.get_connected_joypads()
	if typeof(joypads) != TYPE_ARRAY or joypads.empty():
		return []

	# Brotato remaps the first physical gamepad (event.device == 0) to device 6.
	# Keep using the vanilla remapped local gamepad slot, not the remote placeholders 1..3.
	var device = CoopService.GAMEPAD_REMAPPED_DEVICE_ID
	var player_type = _get_player_type_for_joypad(int(joypads[0]))
	return [device, player_type]


func _get_player_type_for_joypad(unmapped_device: int) -> int:
	var joy_name = Input.get_joy_name(unmapped_device)
	var joy_name_components = joy_name.to_lower().split(" ")
	if Utils.on_nintendo_nx_or_ounce:
		return CoopService.PlayerType.GAMEPAD_SWITCH
	if Utils.on_playstation:
		return CoopService.PlayerType.GAMEPAD_PLAYSTATION
	if "ps4" in joy_name_components or "ps5" in joy_name_components or "playstation" in joy_name_components or "dualsense" in joy_name_components:
		return CoopService.PlayerType.GAMEPAD_PLAYSTATION
	if "nintendo" in joy_name_components or "switch" in joy_name_components:
		return CoopService.PlayerType.GAMEPAD_SWITCH
	return CoopService.PlayerType.GAMEPAD_XBOX


func _maybe_replace_manager_keyboard_slot_with_gamepad() -> bool:
	if not _host_player_joined_by_manager:
		return false
	if not _prefers_local_gamepad_input():
		return false
	var gamepad_entry = _get_preferred_local_gamepad_entry()
	if gamepad_entry.empty():
		return false
	var gamepad_device = int(gamepad_entry[0])
	if CoopService.is_device_assigned(gamepad_device):
		return false
	var keyboard_index = _get_player_index_for_device(CoopService.KEYBOARD_REMAPPED_DEVICE_ID)
	if keyboard_index < 0:
		return false
	var keyboard_player = CoopService.connected_players[keyboard_index]
	if typeof(keyboard_player) != TYPE_ARRAY or keyboard_player.size() < 2:
		return false
	if _remote_steam_id_by_device.has(int(keyboard_player[0])):
		return false
	CoopService.connected_players[keyboard_index] = [gamepad_device, int(gamepad_entry[1])]
	_sync_run_data_player_count()
	_bo_emit_connected_players_updated("generic_emit")
	return true


func _maybe_replace_local_mirrored_keyboard_slot_with_gamepad() -> bool:
	if _local_mirrored_player_index < 0:
		return false
	if not _prefers_local_gamepad_input():
		return false
	var gamepad_entry = _get_preferred_local_gamepad_entry()
	if gamepad_entry.empty():
		return false
	var gamepad_device = int(gamepad_entry[0])
	if CoopService.is_device_assigned(gamepad_device):
		return false
	var idx = int(_local_mirrored_player_index)
	if idx < 0 or idx >= CoopService.connected_players.size():
		return false
	var current = CoopService.connected_players[idx]
	if typeof(current) != TYPE_ARRAY or current.size() < 2:
		return false
	if int(current[0]) != CoopService.KEYBOARD_REMAPPED_DEVICE_ID:
		return false
	if _remote_steam_id_by_device.has(int(current[0])):
		return false

	var replacement = [gamepad_device, int(gamepad_entry[1])]
	CoopService.connected_players[idx] = replacement
	if idx >= 0 and idx < _mirrored_connected_players.size():
		_mirrored_connected_players[idx] = [replacement[0], replacement[1]]
	_sync_run_data_player_count()
	_bo_emit_connected_players_updated("generic_emit")
	_refresh_current_character_selection_layout()
	return true


func _restore_tracked_coop_players_if_needed() -> void:
	if not _is_online_session_active():
		return
	# Client mirror layouts must survive vanilla scene transitions.  Some Brotato menus
	# rebuild CoopService.connected_players while changing scenes; if we only restore
	# remote placeholders, the local client slot can disappear before main.tscn spawns
	# players, producing one-player scenes and stale/dead player nodes.
	if _local_mirrored_player_index >= 0 and not _mirrored_connected_players.empty():
		_maybe_replace_local_mirrored_keyboard_slot_with_gamepad()
		repair_mirrored_layout_now("periodic_guard")
		return

	if _is_slot_mutation_locked():
		return
	if not RunData.is_coop_run:
		return

	if _remote_devices.empty() and not _host_player_joined_by_manager:
		return

	var restored = false

	if _host_player_joined_by_manager:
		if _maybe_replace_manager_keyboard_slot_with_gamepad():
			restored = true
		var local_index = _get_existing_local_player_index()
		if local_index != 0:
			_ensure_host_player_joined()
			restored = true

	for device in _remote_devices:
		if not CoopService.is_device_assigned(device):
			CoopService._add_player(device, REMOTE_PLACEHOLDER_PLAYER_TYPE)
			restored = true

	if restored:
		_sync_run_data_player_count()
		dump_slots()


func _remove_unpreferred_local_input_slots(preferred_device: int) -> bool:
	var removed = false
	for i in range(CoopService.connected_players.size() - 1, -1, -1):
		var player = CoopService.connected_players[i]
		if typeof(player) != TYPE_ARRAY or player.size() < 2:
			continue
		var device = int(player[0])
		if device != CoopService.GAMEPAD_REMAPPED_DEVICE_ID and device != CoopService.KEYBOARD_REMAPPED_DEVICE_ID:
			continue
		if device == preferred_device:
			continue
		if _remote_steam_id_by_device.has(device):
			continue
		_bo_slot_diag_log("REMOVE_UNPREFERRED_LOCAL_SLOT", "idx=" + str(i) + " device=" + str(device) + " preferred=" + str(preferred_device) + " before=" + _bo_slot_diag_players())
		CoopService.connected_players.remove(i)
		removed = true

	if removed:
		_sync_run_data_player_count()
		_bo_emit_connected_players_updated("generic_emit")
	return removed


func _remove_untracked_remote_placeholder_slots() -> bool:
	var removed = false
	for i in range(CoopService.connected_players.size() - 1, -1, -1):
		var player = CoopService.connected_players[i]
		if typeof(player) != TYPE_ARRAY or player.size() < 2:
			continue
		var device = int(player[0])
		if not REMOTE_PLACEHOLDER_DEVICE_IDS.has(device):
			continue
		if _remote_steam_id_by_device.has(device):
			continue
		# Only remove placeholders that this online manager previously owned. A device
		# in the low placeholder range can be a valid vanilla local controller on some
		# setups/builds, so blindly deleting 1/2/3 breaks Host local-multiplayer.
		if not _remote_devices.has(device):
			continue
		_bo_slot_diag_log("REMOVE_UNTRACKED_REMOTE_PLACEHOLDER", "idx=" + str(i) + " device=" + str(device) + " before=" + _bo_slot_diag_players() + " maps=" + _bo_slot_diag_maps())
		CoopService.connected_players.remove(i)
		_remote_devices.erase(device)
		removed = true

	if removed:
		_sync_run_data_player_count()
		_bo_emit_connected_players_updated("generic_emit")
	return removed


func _sync_run_data_player_count() -> void:
	if not RunData.has_method("set_player_count"):
		return

	var target_count = CoopService.connected_players.size()
	var current_count = RunData.get_player_count()

	if target_count > 1:
		RunData.play_mode = RunData.PlayMode.COOP
		RunData.set_coop_run(true)

	# Official continue/resume restores RunData.players_data from the saved run.
	# Do not shrink saved player data while the official resume UI is still wiring
	# Steam placeholders. Expanding 1 -> 2 is required after a client rejoins;
	# otherwise RunData stays single-player while CoopService has two players.
	if current_count > 0 and target_count < current_count and _should_preserve_loaded_run_player_data():
		return

	RunData.set_player_count(target_count)
	if target_count > 1:
		RunData.play_mode = RunData.PlayMode.COOP
		RunData.set_coop_run(true)


func _should_preserve_loaded_run_player_data() -> bool:
	if _is_in_official_coop_resume_scene():
		return true

	# resume_from_state() sets this when the official Continue flow restores into shop.
	# Object.get() is used so this remains safe if the property changes in another build.
	var resumed_value = RunData.get("resumed_from_state_in_shop")
	if resumed_value != null and bool(resumed_value):
		return true

	# Once an online run is locked/active, saved player slots must not be reduced by
	# lobby membership churn or late Steam callbacks.
	return _online_run_slots_locked or _is_in_active_online_run_scene()


func _restore_current_character_selection_to_solo() -> bool:
	var selection = _find_character_selection_node()
	if selection == null or not selection.has_method("_play_mode_init"):
		return false
	selection.call("_play_mode_init", RunData.PlayMode.SOLO, false)
	return true


func _refresh_current_character_selection_layout() -> void:
	var selection = _find_character_selection_node()
	if selection == null:
		return
	if selection.has_method("_on_connected_players_updated"):
		selection.call_deferred("_on_connected_players_updated", CoopService.connected_players, false)
	elif selection.has_method("_set_base_ui_player_count"):
		selection.call_deferred("_set_base_ui_player_count", RunData.get_player_count(), RunData.is_coop_run, false)


func _get_player_index_for_device(device: int) -> int:
	for i in range(CoopService.connected_players.size()):
		if int(CoopService.connected_players[i][0]) == device:
			return i
	return -1


func _get_next_free_remote_device() -> int:
	for device in REMOTE_PLACEHOLDER_DEVICE_IDS:
		if not CoopService.is_device_assigned(device) and not _remote_devices.has(device):
			return device

	return -1


func _get_next_remote_placeholder_device_from_lists(remote_devices: Array, connected_players: Array) -> int:
	for device in REMOTE_PLACEHOLDER_DEVICE_IDS:
		if remote_devices.has(device):
			continue

		var used = false
		for player in connected_players:
			if typeof(player) == TYPE_ARRAY and player.size() > 0 and int(player[0]) == int(device):
				used = true
				break

		if not used:
			return device

	return -1

func _find_character_selection_node() -> Node:
	var current = get_tree().current_scene
	if current == null:
		return null

	if _is_character_selection_node(current):
		return current

	return _find_character_selection_node_recursive(current)


func _find_character_selection_node_recursive(node: Node) -> Node:
	for child in node.get_children():
		if _is_character_selection_node(child):
			return child

		var found = _find_character_selection_node_recursive(child)
		if found != null:
			return found

	return null


func _is_character_selection_node(node: Node) -> bool:
	if node == null:
		return false

	var script_path = _get_script_path(node)
	if script_path.find("ui/menus/run/character_selection.gd") != -1:
		return true

	return node.has_method("_on_connected_players_updated") and node.has_method("_play_mode_init")


func _get_script_path(node: Node) -> String:
	if node == null:
		return ""

	var script_res = node.get_script()
	if script_res == null:
		return ""

	return str(script_res.resource_path)
