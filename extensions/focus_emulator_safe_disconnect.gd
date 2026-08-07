extends "res://ui/menus/global/focus_emulator.gd"

# Minimal safety guards around vanilla focus bookkeeping. Valid controls continue
# through the original implementation; only stale/freed controls use the fallback.
# The extra signal gives online menu code an event-driven focus-change hook so it
# does not need to rediscover the focused inventory element by polling whole lists.

signal bo_focused_control_changed(control)

var _bo_last_focus_event_control_id = -1


func _bo_is_live_control(value) -> bool:
	if value == null or typeof(value) != TYPE_OBJECT:
		return false
	if not is_instance_valid(value) or not (value is Control):
		return false
	return not value.is_queued_for_deletion()


func _bo_emit_focused_control_changed(control) -> void:
	var control_id = 0
	if _bo_is_live_control(control):
		control_id = int(control.get_instance_id())
	if control_id == _bo_last_focus_event_control_id:
		return
	_bo_last_focus_event_control_id = control_id
	emit_signal("bo_focused_control_changed", control if control_id != 0 else null)


func _connect_focused_control(control: Control) -> void:
	if not _bo_is_live_control(control):
		return
	if not control.is_connected("item_rect_changed", self, "update"):
		._connect_focused_control(control)
	_bo_emit_focused_control_changed(control)


func _disconnect_focused_control(control: Control) -> void:
	if not _bo_is_live_control(control):
		return
	._disconnect_focused_control(control)


func _clear_focused_control() -> void:
	if focused_control == null:
		_bo_emit_focused_control_changed(null)
		return
	if _bo_is_live_control(focused_control):
		._clear_focused_control()
		_bo_emit_focused_control_changed(null)
		return

	focused_control = null
	_focused_control_index = -1
	_focused_parent = null
	update()
	_bo_emit_focused_control_changed(null)
