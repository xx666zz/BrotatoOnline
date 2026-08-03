extends Reference


static func is_focusable_control(control) -> bool:
	if control == null or typeof(control) != TYPE_OBJECT:
		return false
	if not is_instance_valid(control) or not (control is Control):
		return false
	if control.is_queued_for_deletion() or not control.is_inside_tree():
		return false
	if not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
		return false
	return true
