extends "res://entities/units/enemies/crash_zone/basic/evil_mob/evil_mob.gd"

# A negative stage leaves the vanilla host/offline pickup and reward paths active.
var _bo_confirmed_stage = -1
var _bo_follow_host_target = false
var _bo_has_target = false
var _bo_target = Vector2.ZERO
var _bo_sample_sequence = 0
var _bo_network_life = false
var bo_base_stats: Resource


func bo_get_gobbler_state() -> Dictionary:
	_bo_network_life = true
	_bo_sample_sequence += 1
	var state = {"gold": gold_count, "stage": evolution, "seq": _bo_sample_sequence}
	if _movement_behavior is TargetRandGoldPosBehavior and _movement_behavior.init:
		var target = _movement_behavior.get_target_position()
		state["target"] = {"x": target.x, "y": target.y}
	return state


func bo_apply_gobbler_state(state: Dictionary, released: bool = false) -> void:
	if not state.has("gold") or not state.has("stage"):
		return
	var sequence = int(state.get("seq", 0))
	if not released and _bo_confirmed_stage >= 0 and sequence <= _bo_sample_sequence:
		return
	_bo_sample_sequence = sequence
	var initial = _bo_confirmed_stage < 0
	_bo_network_life = true
	gold_count = max(0, int(state.gold))
	_bo_confirmed_stage = int(clamp(int(state.stage), 0, textures_evolution.size() - 1))
	_bo_follow_host_target = not released
	var target = state.get("target", null)
	_bo_has_target = typeof(target) == TYPE_DICTIONARY and target.has("x") and target.has("y")
	if _bo_has_target:
		_bo_target = Vector2(target.x, target.y)
		_movement_behavior._current_target = _bo_target
	if released:
		# Force the next native move to select a fresh local destination.
		_movement_behavior._current_target = Vector2.ZERO
	if initial:
		_bo_show_confirmed_stage()


func get_movement() -> Vector2:
	if not _bo_follow_host_target or _move_locked or _current_movement_behavior != _movement_behavior:
		return .get_movement()
	if not _bo_has_target or Utils.vectors_approx_equal(global_position, _bo_target, MovementBehavior.EQUALITY_PRECISION):
		return Vector2.ZERO
	return _bo_target - global_position


func has_random_target_movement() -> bool:
	# Vanilla stuck recovery also selects a random pile, independently of get_movement().
	return false if _bo_follow_host_target and _current_movement_behavior == _movement_behavior else .has_random_target_movement()


func _on_ItemPickUpArea_area_entered(area: Area2D) -> void:
	if _bo_confirmed_stage < 0:
		._on_ItemPickUpArea_area_entered(area)
		return
	if not dead and area is Gold and not area.already_picked_up:
		area.pickup(-1)
		_bo_show_confirmed_stage()


func _bo_show_confirmed_stage() -> void:
	if evolution >= _bo_confirmed_stage:
		return
	for stage in range(evolution + 1, _bo_confirmed_stage + 1):
		evolve(stage)
	on_health_updated(self, current_stats.health, max_stats.health)


func evolve(stage: int) -> void:
	# Vanilla evolve writes knockback resistance to a shared map resource.
	if _bo_network_life and bo_base_stats == null:
		bo_base_stats = stats
		stats = stats.duplicate()
	.evolve(stage)


func get_stats_value() -> int:
	return .get_stats_value() if _bo_confirmed_stage < 0 else gold_count * (_bo_confirmed_stage + 1)


func respawn() -> void:
	if _bo_network_life:
		_bo_confirmed_stage = -1
		_bo_sample_sequence = 0
		_bo_follow_host_target = false
		_bo_has_target = false
		gold_count = 0
		if evolution > 0:
			evolve(0)
			life_bar.hide()
		if bo_base_stats != null:
			stats = bo_base_stats
			bo_base_stats = null
		_movement_behavior._current_target = Vector2.ZERO
		_movement_behavior.init = false
		_bo_network_life = false
	.respawn()
