extends "res://entities/units/movement_behaviors/follow_target_movement_behavior.gd"

# Defensive guards for online-spawned / pooled enemies. The vanilla movement
# implementation is used whenever its parent/target assumptions are satisfied.


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
	if stop_close_to_target and _target_player and not is_instance_valid(target):
		return get_target_position() - _parent.global_position
	return .get_movement()


func get_target_position():
	if not _brotato_online_is_online_session_active():
		return .get_target_position()
	if _parent == null or not is_instance_valid(_parent):
		return global_position
	return .get_target_position()
