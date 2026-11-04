extends "res://singletons/run_data.gd"

var _bo_host_settles_mutations = false

func on_wave_end() -> void:
	var main = get_tree().current_scene
	_bo_host_settles_mutations = is_instance_valid(main) and main.has_method("_brotato_online_is_online_client") and main._brotato_online_is_online_client()
	var before = []
	if is_instance_valid(main) and main.has_method("_brotato_online_is_online_session_active") and main._brotato_online_is_online_session_active() and main._brotato_online_is_game_host():
		for player in players_data:
			before.append(player.items.duplicate())
	.on_wave_end()
	_bo_host_settles_mutations = false
	for index in range(min(before.size(), players_data.size())):
		var player = players_data[index]
		if before[index] != player.items:
			player.set_meta("bo_wave_inventory_changed", current_wave)
		elif player.has_meta("bo_wave_inventory_changed"):
			player.remove_meta("bo_wave_inventory_changed")


func mutate_random_item(player_index: int):
	if _bo_host_settles_mutations:
		return null
	return .mutate_random_item(player_index)

func advance_dino_eggs() -> void:
	if not _bo_host_settles_mutations:
		.advance_dino_eggs()
