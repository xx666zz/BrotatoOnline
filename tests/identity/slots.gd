extends Node
const REMOTE_PLACEHOLDER_DEVICE_IDS = [1, 2, 3, 4, 5]
const REMOTE_PLACEHOLDER_PLAYER_TYPE = 1
var _remote_steam_id_by_device = {}
var _device_by_remote_steam_id = {}
var _remote_devices = []
var _local_mirrored_player_index = -1
var _local_mirrored_steam_id = ""
var _mirrored_connected_players = []
var _last_observed_local_layout_key = ""
var _host_player_joined_by_manager = true
var _online_run_slots_locked = false
var _online_run_connected_players_snapshot = []
func _is_in_official_coop_resume_scene():
	var scene = get_tree().current_scene
	return scene != null and str(scene.filename).ends_with("/coop_resume.tscn")
func _is_in_active_online_run_scene():
	return false
func _remove_remote_steam_id(key):
	var device = _device_by_remote_steam_id.get(key, -1)
	for index in range(CoopService.connected_players.size() - 1, -1, -1):
		if int(CoopService.connected_players[index][0]) == device:
			CoopService.connected_players.remove(index)
func _sync_run_data_player_count():
	pass
func _bo_emit_connected_players_updated(_reason):
	CoopService.emit_signal("connected_players_updated", CoopService.connected_players)
func _restore_current_character_selection_to_solo():
	return false
func _refresh_current_character_selection_layout():
	pass
func dump_slots():
	pass
func _is_slot_mutation_locked():
	return false
func _get_connected_local_gamepad_remapped_devices():
	return []
func _build_local_layout_key():
	return ""
func _get_player_index_for_device(device):
	for index in range(CoopService.connected_players.size()):
		if int(CoopService.connected_players[index][0]) == device:
			return index
	return -1
func _ensure_host_player_joined():
	if CoopService.connected_players.empty():
		CoopService.connected_players.append([7, 0])
		CoopService.emit_signal("connected_players_updated", CoopService.connected_players)
