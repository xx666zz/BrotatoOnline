extends "res://singletons/run_data.gd"

var _bo_host_settles_mutations = false

func on_wave_end() -> void:
	var main = get_tree().current_scene
	_bo_host_settles_mutations = is_instance_valid(main) and main.has_method("_brotato_online_is_online_client") and main._brotato_online_is_online_client()
	.on_wave_end()
	_bo_host_settles_mutations = false

func mutate_random_item(player_index: int):
	if _bo_host_settles_mutations:
		return null
	return .mutate_random_item(player_index)
