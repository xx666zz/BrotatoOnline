extends Reference


static func resolve_shop_focus_target(focus_emulator_available: bool, actual_target: String, legacy_target: String) -> String:
	if focus_emulator_available:
		return actual_target
	return legacy_target


static func can_apply_focus_control(control) -> bool:
	return is_focusable_control(control)


static func should_expect_focus_signal_after_direct_assignment(direct_assignment: bool) -> bool:
	return not direct_assignment


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
