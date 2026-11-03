extends "res://effect_behaviors/scenes/evolution_scene_effect_behavior.gd"

func _on_EntitySpawner_enemy_respawned(enemy: Enemy) -> void:
	var main = get_tree().current_scene
	if not is_instance_valid(main) or not main.has_method("_brotato_online_is_online_client") or not main._brotato_online_is_online_client():
		._on_EntitySpawner_enemy_respawned(enemy)
		return
	# The authoritative birth has already selected the form, including plain bosses.
	if enemy._is_meca or enemy._is_mutant:
		var team = TeamEvolution.new()
		_evolution_enemy(enemy, enemy._is_meca, team.magnitude_for(enemy._is_meca))
