extends "res://ui/menus/global/focus_emulator.gd"


# Minimal safety guard only.
# It does not remap input, does not choose neighbours, and does not route focus.
# Vanilla FocusEmulator can keep a stale/freed Control after shop popups rebuild;
# then _disconnect_focused_control() calls is_connected() on Nil and crashes.

func _bo_is_live_control(value) -> bool:
	if value == null or typeof(value) != TYPE_OBJECT:
		return false
	if not is_instance_valid(value):
		return false
	if not (value is Control):
		return false
	if value.is_queued_for_deletion():
		return false
	return true


func _connect_focused_control(control: Control) -> void:
	if not _bo_is_live_control(control):
		return
	if not control.is_connected("item_rect_changed", self, "update"):
		var _error = control.connect("item_rect_changed", self, "update")


func _disconnect_focused_control(control: Control) -> void:
	if not _bo_is_live_control(control):
		return
	if control.is_connected("item_rect_changed", self, "update"):
		control.disconnect("item_rect_changed", self, "update")


func _clear_focused_control() -> void:
	var control = focused_control
	if not _bo_is_live_control(control):
		focused_control = null
		_focused_control_index = -1
		_focused_parent = null
		update()
		return

	_disconnect_focused_control(control)
	if _bo_is_live_control(control):
		_clear_focus_style(control)
	focused_control = null
	_focused_control_index = -1
	_focused_parent = null
