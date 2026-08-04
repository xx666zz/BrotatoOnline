extends "res://ui/menus/global/focus_emulator.gd"

# Minimal safety guards around vanilla focus bookkeeping. Valid controls continue
# through the original implementation; only stale/freed controls use the fallback.

const FOCUS_CONTROL_GUARD = preload("res://mods-unpacked/six666-BrotatoOnline/scripts/focus_control_guard.gd")


func _bo_is_live_control(value) -> bool:
	return FOCUS_CONTROL_GUARD.is_focusable_control(value)


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
