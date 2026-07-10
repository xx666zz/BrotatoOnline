extends "res://ui/menus/global/focus_emulator.gd"

# Minimal safety guards around vanilla focus bookkeeping. Valid controls continue
# through the original implementation; only stale/freed controls use the fallback.


func _bo_is_live_control(value) -> bool:
	if value == null or typeof(value) != TYPE_OBJECT:
		return false
	if not is_instance_valid(value) or not (value is Control):
		return false
	return not value.is_queued_for_deletion()


func _connect_focused_control(control: Control) -> void:
	if not _bo_is_live_control(control):
		return
	if not control.is_connected("item_rect_changed", self, "update"):
		._connect_focused_control(control)


func _disconnect_focused_control(control: Control) -> void:
	if not _bo_is_live_control(control):
		return
	._disconnect_focused_control(control)


func _clear_focused_control() -> void:
	if focused_control == null:
		return
	if _bo_is_live_control(focused_control):
		._clear_focused_control()
		return

	focused_control = null
	_focused_control_index = -1
	_focused_parent = null
	update()
