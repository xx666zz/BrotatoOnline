extends Node

# Draw after all input/process callbacks, so vanilla cursor hiding cannot flicker
# the pointer. Sprite has no GUI hit testing and cannot consume clicks or wheels.
var _pointer: Sprite
var _window_focused = true
var _normal = preload("res://ui/custom_cursor.png")

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	var layer = CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_pointer = Sprite.new()
	_pointer.centered = false
	_pointer.hide()
	layer.add_child(_pointer)
	VisualServer.connect("frame_pre_draw", self, "_update_pointer")

func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_FOCUS_OUT:
		_window_focused = false
	elif what == MainLoop.NOTIFICATION_WM_FOCUS_IN:
		_window_focused = true

func _update_pointer() -> void:
	if not is_instance_valid(_pointer):
		return
	var tree = get_tree()
	var mouse = get_viewport().get_mouse_position()
	_pointer.visible = (_window_focused
		and tree.root.get_meta("brotato_online_session_active", false)
		and RunData.is_coop_run
		and not _is_active_battle()
		and not DebugService.screenshot_freeze
		and Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN
		and get_viewport().get_visible_rect().has_point(mouse))
	if not _pointer.visible:
		return
	_pointer.texture = _normal
	_pointer.position = mouse - Vector2(3, 3)

func _is_active_battle() -> bool:
	var tree = get_tree()
	var scene = tree.current_scene
	return not tree.paused and is_instance_valid(scene) and scene.has_method("_handle_manual_aim_visuals")
