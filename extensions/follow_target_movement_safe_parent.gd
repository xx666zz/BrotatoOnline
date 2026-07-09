extends "res://entities/units/movement_behaviors/follow_target_movement_behavior.gd"

# Defensive guard for online-spawned / pooled enemies whose Behavior.init(parent)
# has not completed yet, or whose current_target is briefly null during scene / death
# transitions. Vanilla code assumes both are valid and can crash in get_target_position().


func _brotato_online_is_online_session_active() -> bool:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return false
	return bool(tree.root.get_meta("brotato_online_session_active", false))

func get_movement() -> Vector2:
	if not _brotato_online_is_online_session_active():
		return .get_movement()

	if _parent == null or not is_instance_valid(_parent):
		return Vector2.ZERO
	var target = _parent.get("current_target")
	if stop_close_to_target and _target_player and is_instance_valid(target):
		if _parent.global_position.distance_squared_to(target.global_position) < distance_to_target * distance_to_target:
			return Vector2.ZERO
	return get_target_position() - _parent.global_position


func get_target_position():
	if not _brotato_online_is_online_session_active():
		return .get_target_position()

	if _parent == null or not is_instance_valid(_parent):
		return global_position
	var target = _parent.get("current_target")
	if not is_instance_valid(target):
		return global_position
	return target.global_position
