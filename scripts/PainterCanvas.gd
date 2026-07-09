extends Control

signal image_changed

var edit_image: Image = null
var mask_image: Image = null
var preview_texture: ImageTexture = null
var restrict_to_mask = true
var brush_color = Color(1, 1, 1, 1)
var brush_size = 1
var tool = "brush"

var _drawing = false
var _drawing_button = 0
var _active_tool = "brush"
var _last_pixel = Vector2(-1, -1)
var _undo_stack = []
var _max_undo = 24

var _zoom = 1.0
var _min_zoom = 0.35
var _max_zoom = 12.0
var _pan = Vector2.ZERO
var _panning = false
var _last_pan_pos = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	rect_clip_content = true
	rect_min_size = Vector2(620, 620)


func set_images(p_edit_image: Image, p_mask_image: Image) -> void:
	edit_image = p_edit_image
	mask_image = p_mask_image
	_reset_view()
	_update_texture()
	_undo_stack.clear()


func get_image():
	if edit_image == null:
		return null
	return edit_image.duplicate()


func set_restrict_to_mask(value: bool) -> void:
	restrict_to_mask = value


func set_brush_color(value: Color) -> void:
	brush_color = value
	tool = "brush"


func set_brush_size(value: int) -> void:
	brush_size = max(1, value)


func set_tool(value: String) -> void:
	tool = value


func clear_to_image(image: Image) -> void:
	_push_undo()
	edit_image = image
	_update_texture()
	emit_signal("image_changed")


func undo() -> void:
	if _undo_stack.empty():
		return
	edit_image = _undo_stack.pop_back()
	_update_texture()
	emit_signal("image_changed")


func _gui_input(event) -> void:
	if edit_image == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_WHEEL_UP or event.button_index == BUTTON_WHEEL_DOWN:
			if event.control:
				var zoom_factor = 1.15 if event.button_index == BUTTON_WHEEL_UP else 1.0 / 1.15
				_zoom_at(event.position, zoom_factor)
				accept_event()
			return
		if event.button_index == BUTTON_MIDDLE:
			_panning = event.pressed
			_last_pan_pos = event.position
			accept_event()
			return
		if event.button_index == BUTTON_LEFT or event.button_index == BUTTON_RIGHT:
			if event.pressed:
				_drawing = true
				_drawing_button = event.button_index
				_active_tool = "eraser" if event.button_index == BUTTON_RIGHT else tool
				_last_pixel = Vector2(-1, -1)
				_push_undo()
				_draw_at_event_pos(event.position, _active_tool)
			else:
				if event.button_index == _drawing_button:
					_drawing = false
					_drawing_button = 0
					_last_pixel = Vector2(-1, -1)
	elif event is InputEventMouseMotion:
		if _panning:
			_pan += event.position - _last_pan_pos
			_last_pan_pos = event.position
			_clamp_pan()
			update()
			accept_event()
		elif _drawing:
			_draw_at_event_pos(event.position, _active_tool)


func _draw() -> void:
	var bg_a = Color(0.07, 0.07, 0.07, 1)
	var bg_b = Color(0.12, 0.12, 0.12, 1)
	var block = 16
	var cols = int(ceil(rect_size.x / block))
	var rows = int(ceil(rect_size.y / block))
	for y in range(rows):
		for x in range(cols):
			var c = bg_a if (x + y) % 2 == 0 else bg_b
			draw_rect(Rect2(Vector2(x * block, y * block), Vector2(block, block)), c)
	if preview_texture != null:
		draw_texture_rect(preview_texture, _get_view_rect(), false)
	_draw_grid()


func _draw_grid() -> void:
	if edit_image == null:
		return
	var w = edit_image.get_width()
	var h = edit_image.get_height()
	if w <= 0 or h <= 0:
		return
	if w > 96 or h > 96:
		return
	var view_rect = _get_view_rect()
	var step_x = view_rect.size.x / float(w)
	var step_y = view_rect.size.y / float(h)
	var grid_color = Color(1, 1, 1, 0.08)
	for x in range(w + 1):
		var px = view_rect.position.x + x * step_x
		draw_line(Vector2(px, view_rect.position.y), Vector2(px, view_rect.position.y + view_rect.size.y), grid_color, 1)
	for y in range(h + 1):
		var py = view_rect.position.y + y * step_y
		draw_line(Vector2(view_rect.position.x, py), Vector2(view_rect.position.x + view_rect.size.x, py), grid_color, 1)


func _draw_at_event_pos(pos: Vector2, draw_tool: String) -> void:
	var pixel = _event_pos_to_pixel(pos)
	if pixel.x < 0 or pixel.y < 0:
		return
	if _last_pixel.x < 0:
		_draw_brush(int(pixel.x), int(pixel.y), draw_tool)
	else:
		_draw_line_pixels(_last_pixel, pixel, draw_tool)
	_last_pixel = pixel
	_update_texture()
	emit_signal("image_changed")


func _event_pos_to_pixel(pos: Vector2) -> Vector2:
	if edit_image == null or rect_size.x <= 0 or rect_size.y <= 0:
		return Vector2(-1, -1)
	var view_rect = _get_view_rect()
	if pos.x < view_rect.position.x or pos.y < view_rect.position.y:
		return Vector2(-1, -1)
	if pos.x >= view_rect.position.x + view_rect.size.x or pos.y >= view_rect.position.y + view_rect.size.y:
		return Vector2(-1, -1)
	var local_pos = pos - view_rect.position
	var x = int(floor(local_pos.x / view_rect.size.x * edit_image.get_width()))
	var y = int(floor(local_pos.y / view_rect.size.y * edit_image.get_height()))
	x = clamp(x, 0, edit_image.get_width() - 1)
	y = clamp(y, 0, edit_image.get_height() - 1)
	return Vector2(x, y)


func _draw_line_pixels(from_px: Vector2, to_px: Vector2, draw_tool: String) -> void:
	var dist = int(max(abs(to_px.x - from_px.x), abs(to_px.y - from_px.y)))
	if dist <= 0:
		_draw_brush(int(to_px.x), int(to_px.y), draw_tool)
		return
	for i in range(dist + 1):
		var t = float(i) / float(dist)
		var p = from_px.linear_interpolate(to_px, t)
		_draw_brush(int(round(p.x)), int(round(p.y)), draw_tool)


func _draw_brush(cx: int, cy: int, draw_tool: String) -> void:
	if edit_image == null:
		return
	var w = edit_image.get_width()
	var h = edit_image.get_height()
	var radius = int(max(0, brush_size - 1))
	edit_image.lock()
	if mask_image != null:
		mask_image.lock()
	for y in range(cy - radius, cy + radius + 1):
		if y < 0 or y >= h:
			continue
		for x in range(cx - radius, cx + radius + 1):
			if x < 0 or x >= w:
				continue
			if radius > 0 and Vector2(x - cx, y - cy).length() > float(radius) + 0.25:
				continue
			var mask_pixel = Color(0, 0, 0, 0)
			var inside_mask = true
			if mask_image != null:
				mask_pixel = mask_image.get_pixel(x, y)
				inside_mask = mask_pixel.a > 0.05
			if draw_tool == "eraser":
				if restrict_to_mask and mask_image != null:
					if inside_mask:
						edit_image.set_pixel(x, y, mask_pixel)
				else:
					edit_image.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				if restrict_to_mask and not inside_mask:
					continue
				edit_image.set_pixel(x, y, brush_color)
	if mask_image != null:
		mask_image.unlock()
	edit_image.unlock()


func _push_undo() -> void:
	if edit_image == null:
		return
	_undo_stack.push_back(edit_image.duplicate())
	while _undo_stack.size() > _max_undo:
		_undo_stack.pop_front()


func _reset_view() -> void:
	_zoom = 1.0
	_pan = Vector2.ZERO
	_panning = false


func _get_view_rect() -> Rect2:
	return Rect2(_pan, rect_size * _zoom)


func _zoom_at(pos: Vector2, factor: float) -> void:
	if rect_size.x <= 0 or rect_size.y <= 0:
		return
	var old_zoom = _zoom
	var old_size = rect_size * old_zoom
	if old_size.x <= 0 or old_size.y <= 0:
		return
	var uv = Vector2((pos.x - _pan.x) / old_size.x, (pos.y - _pan.y) / old_size.y)
	_zoom = clamp(_zoom * factor, _min_zoom, _max_zoom)
	var new_size = rect_size * _zoom
	_pan = pos - Vector2(uv.x * new_size.x, uv.y * new_size.y)
	_clamp_pan()
	update()


func _clamp_pan() -> void:
	var view_size = rect_size * _zoom
	if view_size.x <= rect_size.x:
		_pan.x = (rect_size.x - view_size.x) * 0.5
	else:
		_pan.x = clamp(_pan.x, rect_size.x - view_size.x, 0)
	if view_size.y <= rect_size.y:
		_pan.y = (rect_size.y - view_size.y) * 0.5
	else:
		_pan.y = clamp(_pan.y, rect_size.y - view_size.y, 0)


func _update_texture() -> void:
	if edit_image == null:
		preview_texture = null
		update()
		return
	if preview_texture == null:
		preview_texture = ImageTexture.new()
	preview_texture.create_from_image(edit_image, 0)
	update()
