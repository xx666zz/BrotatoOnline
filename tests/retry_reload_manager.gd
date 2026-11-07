extends "res://mods-unpacked/six666-BrotatoOnline/scripts/menu_sync_manager.gd"

# Use the production scene dispatcher unchanged. Isolate network roster and
# inventory deserialization; the driver supplies an actual playable RunData.
var config_apply_count = 0

func _is_game_host() -> bool:
	return false

func _get_slot_manager() -> Node:
	return null

func _apply_run_config_before_client_scene_change(_config: Dictionary, _screen: String) -> void:
	config_apply_count += 1
