extends Node

const WHEEL_RADIUS = 166.0
const WHEEL_ITEM_SIZE = Vector2(188, 48)
const WHEEL_DEADZONE = 24.0
const GAMEPAD_STICK_DEADZONE = 0.42
const GAMEPAD_TRIGGER_THRESHOLD = 0.45
const GAMEPAD_RIGHT_STICK_AXES = [[2, 3], [3, 4]]
const GAMEPAD_LT_AXIS_CANDIDATES = [6]
const GAMEPAD_LT_BUTTON_CANDIDATES = [6]
const FULL_CIRCLE = PI * 2.0
const BUBBLE_SECONDS = 3.0
const BUBBLE_JITTER = Vector2(18, 10)
const TEXT_LIMIT = 32
const SHARED_FONT_PATHS = [
	"res://resources/fonts/actual/base/font_26_outline.tres",
	"res://resources/fonts/actual/base/font_26.tres"
]

const OPTION_IDS = [
	"come",
	"help",
	"wait",
	"ready",
	"buy",
	"no_reroll",
	"thanks",
	"nice"
]

var _overlay_layer = null
var _overlay_root = null
var _wheel_root = null
var _wheel_panels = []
var _wheel_labels = []
var _wheel_active = false
var _wheel_center = Vector2.ZERO
var _selected_index = -1
var _local_seq = 0
var _rng = RandomNumberGenerator.new()
var _seen_chat_keys = {}
var _last_seen_prune_msec = 0
var _shared_font = null
var _gamepad_active = false
var _gamepad_device = -1
var _gamepad_lt_down = {}
var _ctrl_mouse_visible_active = false
var _ctrl_mouse_previous_mode = Input.MOUSE_MODE_VISIBLE
var _mouse_left_was_down = false


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	set_process(true)
	set_process_input(true)
	_rng.randomize()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			_mouse_left_was_down = true
			if _is_ctrl_down() and _can_use_quick_chat():
				_open_wheel(event.position)
				_gamepad_active = false
				_gamepad_device = -1
				get_tree().set_input_as_handled()
				return
		elif _wheel_active and not _gamepad_active:
			_mouse_left_was_down = false
			if _is_ctrl_down() and _selected_index >= 0:
				_submit_selected()
			_close_wheel()
			get_tree().set_input_as_handled()
			return
		else:
			_mouse_left_was_down = false

	if event is InputEventJoypadButton:
		if _is_lt_button_index(event.button_index):
			_set_gamepad_lt_down(event.device, event.pressed)
			if event.pressed:
				_try_open_gamepad_wheel(event.device)
			else:
				_finish_gamepad_wheel(event.device)
			get_tree().set_input_as_handled()
			return

	if event is InputEventJoypadMotion:
		if _is_lt_axis_index(event.axis):
			var lt_down = _axis_value_is_pressed(event.axis_value)
			var was_down = bool(_gamepad_lt_down.get(event.device, false))
			_set_gamepad_lt_down(event.device, lt_down)
			if lt_down and not was_down:
				_try_open_gamepad_wheel(event.device)
			elif not lt_down and was_down:
				_finish_gamepad_wheel(event.device)
			if _wheel_active and _gamepad_active and event.device == _gamepad_device:
				get_tree().set_input_as_handled()
			return
		if _wheel_active and _gamepad_active and event.device == _gamepad_device and _is_right_stick_axis(event.axis):
			_update_selected_from_gamepad()
			get_tree().set_input_as_handled()
			return

	if _wheel_active and not _gamepad_active:
		if event is InputEventMouseMotion:
			_update_selected(event.position)
			get_tree().set_input_as_handled()
			return
		if event is InputEventKey and not _is_ctrl_down():
			_close_wheel()
			get_tree().set_input_as_handled()
			return


func _process(_delta: float) -> void:
	_update_ctrl_mouse_visibility()

	var mouse_left_down = Input.is_mouse_button_pressed(BUTTON_LEFT)
	if not _gamepad_active:
		if mouse_left_down and not _mouse_left_was_down:
			if not _wheel_active and _is_ctrl_down() and _can_use_quick_chat():
				_open_wheel(get_viewport().get_mouse_position())
				_gamepad_active = false
				_gamepad_device = -1
		elif not mouse_left_down and _mouse_left_was_down:
			if _wheel_active:
				if _is_ctrl_down() and _selected_index >= 0:
					_submit_selected()
				_close_wheel()
				_mouse_left_was_down = mouse_left_down
				_prune_seen_chat_keys()
				return
	_mouse_left_was_down = mouse_left_down

	if _wheel_active:
		if _gamepad_active:
			if not bool(_gamepad_lt_down.get(_gamepad_device, false)):
				_finish_gamepad_wheel(_gamepad_device)
			else:
				_update_selected_from_gamepad()
		else:
			if not _is_ctrl_down() or not mouse_left_down:
				_close_wheel()
				return
			_update_selected(get_viewport().get_mouse_position())
	_prune_seen_chat_keys()


func receive_remote_quick_chat(message: Dictionary) -> void:
	if typeof(message) != TYPE_DICTIONARY or message.empty():
		return
	var key = _quick_chat_key(message)
	if key != "" and _seen_chat_keys.has(key):
		return
	if key != "":
		_seen_chat_keys[key] = OS.get_ticks_msec()
	_show_chat_bubble(message)


func _can_use_quick_chat() -> bool:
	var steam = _get_steam_lobby_manager()
	if steam == null or not steam.has_method("has_active_online_session"):
		return false
	return bool(steam.has_active_online_session())


func _is_ctrl_down() -> bool:
	return Input.is_key_pressed(KEY_CONTROL)


func _update_ctrl_mouse_visibility() -> void:
	var should_show = _is_ctrl_down() and _can_use_quick_chat()
	if should_show:
		if not _ctrl_mouse_visible_active:
			_ctrl_mouse_previous_mode = Input.get_mouse_mode()
			_ctrl_mouse_visible_active = true
		if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	_restore_ctrl_mouse_mode()


func _restore_ctrl_mouse_mode() -> void:
	if not _ctrl_mouse_visible_active:
		return
	_ctrl_mouse_visible_active = false
	if Input.get_mouse_mode() != _ctrl_mouse_previous_mode:
		Input.set_mouse_mode(_ctrl_mouse_previous_mode)


func _exit_tree() -> void:
	_restore_ctrl_mouse_mode()


func _open_wheel(pos: Vector2) -> void:
	_ensure_overlay()
	if _overlay_root == null:
		return
	_close_wheel()
	_wheel_active = true
	_wheel_center = _clamp_to_viewport(pos, Vector2(270, 230))
	_selected_index = -1
	_wheel_root = Control.new()
	_wheel_root.name = "QuickChatWheel"
	_wheel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wheel_root.rect_position = Vector2.ZERO
	_wheel_root.rect_size = _get_viewport_size()
	_overlay_root.add_child(_wheel_root)
	_build_wheel_ui()
	_update_selected(pos)


func _close_wheel() -> void:
	_wheel_active = false
	_gamepad_active = false
	_gamepad_device = -1
	_selected_index = -1
	_wheel_panels.clear()
	_wheel_labels.clear()
	if _wheel_root != null and is_instance_valid(_wheel_root):
		_wheel_root.queue_free()
	_wheel_root = null


func _build_wheel_ui() -> void:
	if _wheel_root == null:
		return

	var center_shadow = Panel.new()
	center_shadow.rect_position = _wheel_center - Vector2(17, 17) + Vector2(3, 4)
	center_shadow.rect_size = Vector2(34, 34)
	center_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_shadow.add_stylebox_override("panel", _make_panel_style(Color(0, 0, 0, 0.28), Color(0, 0, 0, 0), 17))
	_wheel_root.add_child(center_shadow)

	var center_panel = Panel.new()
	center_panel.rect_position = _wheel_center - Vector2(16, 16)
	center_panel.rect_size = Vector2(32, 32)
	center_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_panel.add_stylebox_override("panel", _make_panel_style(Color(0.13, 0.11, 0.09, 0.95), Color(0.92, 0.84, 0.60, 0.65), 16))
	_wheel_root.add_child(center_panel)

	for i in range(OPTION_IDS.size()):
		var angle = -PI / 2.0 + FULL_CIRCLE * float(i) / float(OPTION_IDS.size())
		var dir = Vector2(cos(angle), sin(angle))

		var shadow = Panel.new()
		shadow.rect_size = WHEEL_ITEM_SIZE
		shadow.rect_position = _wheel_center + dir * WHEEL_RADIUS - WHEEL_ITEM_SIZE * 0.5 + Vector2(3, 4)
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shadow.add_stylebox_override("panel", _make_panel_style(Color(0, 0, 0, 0.26), Color(0, 0, 0, 0), 10))
		_wheel_root.add_child(shadow)

		var panel = Panel.new()
		panel.rect_size = WHEEL_ITEM_SIZE
		panel.rect_position = _wheel_center + dir * WHEEL_RADIUS - WHEEL_ITEM_SIZE * 0.5
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_stylebox_override("panel", _make_panel_style(Color(0.08, 0.08, 0.08, 0.84), Color(1, 1, 1, 0.20), 10))
		_wheel_root.add_child(panel)

		var label = Label.new()
		label.text = _option_text_by_index(i)
		label.align = Label.ALIGN_CENTER
		label.valign = Label.VALIGN_CENTER
		label.autowrap = false
		label.clip_text = true
		label.rect_position = Vector2(12, 2)
		label.rect_size = WHEEL_ITEM_SIZE - Vector2(24, 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_label_style(label, Color(1, 1, 1, 0.96))
		panel.add_child(label)

		_wheel_panels.append(panel)
		_wheel_labels.append(label)


func _update_selected(mouse_pos: Vector2) -> void:
	if not _wheel_active:
		return
	var delta = mouse_pos - _wheel_center
	var next_index = -1
	if delta.length() >= WHEEL_DEADZONE:
		var angle = atan2(delta.y, delta.x) + PI / 2.0
		while angle < 0.0:
			angle += FULL_CIRCLE
		while angle >= FULL_CIRCLE:
			angle -= FULL_CIRCLE
		next_index = int(floor((angle + FULL_CIRCLE / float(OPTION_IDS.size()) * 0.5) / FULL_CIRCLE * float(OPTION_IDS.size()))) % OPTION_IDS.size()
	if next_index == _selected_index:
		return
	_selected_index = next_index
	_refresh_wheel_styles()


func _refresh_wheel_styles() -> void:
	for i in range(_wheel_panels.size()):
		var selected = i == _selected_index
		var bg = Color(0.29, 0.20, 0.07, 0.96) if selected else Color(0.08, 0.08, 0.08, 0.84)
		var border = Color(1.0, 0.84, 0.34, 0.94) if selected else Color(1, 1, 1, 0.20)
		_wheel_panels[i].add_stylebox_override("panel", _make_panel_style(bg, border, 10))
		if i < _wheel_labels.size():
			_apply_label_style(_wheel_labels[i], Color(1, 0.96, 0.62, 1) if selected else Color(1, 1, 1, 0.96))


func _submit_selected() -> void:
	if _selected_index < 0 or _selected_index >= OPTION_IDS.size():
		return
	var steam = _get_steam_lobby_manager()
	if steam == null or not steam.has_method("send_or_broadcast_quick_chat"):
		return
	_local_seq += 1
	var vp = _get_viewport_size()
	var nx = 0.5
	var ny = 0.5
	if vp.x > 1.0 and vp.y > 1.0:
		nx = clamp(_wheel_center.x / vp.x, 0.0, 1.0)
		ny = clamp(_wheel_center.y / vp.y, 0.0, 1.0)
	var self_id = ""
	if steam.has_method("get_self_steam_id"):
		self_id = str(steam.get_self_steam_id())
	var option_id = OPTION_IDS[_selected_index]
	var message = {
		"msg_type": "quick_chat",
		"quick_chat_id": option_id,
		"text": _option_text_by_id(option_id),
		"screen_pos": {"x": int(round(_wheel_center.x)), "y": int(round(_wheel_center.y))},
		"screen_pos_norm": {"x": nx, "y": ny},
		"origin_steam_id": self_id,
		"player_index": _get_local_player_index(),
		"seq": _local_seq,
		"time_msec": OS.get_ticks_msec()
	}
	var key = _quick_chat_key(message)
	if key != "":
		_seen_chat_keys[key] = OS.get_ticks_msec()
	_show_chat_bubble(message)
	steam.send_or_broadcast_quick_chat(message)


func _show_chat_bubble(message: Dictionary) -> void:
	_ensure_overlay()
	if _overlay_root == null:
		return
	var text = _resolve_message_text(message)
	if text == "":
		return

	var pos = _resolve_message_screen_pos(message)
	pos += Vector2(_rng.randf_range(-BUBBLE_JITTER.x, BUBBLE_JITTER.x), _rng.randf_range(-BUBBLE_JITTER.y, BUBBLE_JITTER.y))
	var player_index = int(message.get("player_index", -1))
	var bubble_w = clamp(116 + max(4, text.length()) * 18, 200, 390)
	var bubble_h = 74
	var holder_size = Vector2(94 + bubble_w, 98)
	var top_left = pos - Vector2(40, 44)
	top_left = _clamp_top_left_to_viewport(top_left, holder_size)

	var holder = Control.new()
	holder.name = "QuickChatBubble"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.rect_position = top_left
	holder.rect_size = holder_size
	_overlay_root.add_child(holder)

	_build_avatar(holder, player_index)
	_build_bubble(holder, bubble_w, bubble_h, text)

	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = BUBBLE_SECONDS
	holder.add_child(timer)
	timer.connect("timeout", holder, "queue_free")
	timer.start()


func _build_avatar(holder: Control, player_index: int) -> void:
	var avatar_root = Control.new()
	avatar_root.rect_position = Vector2(6, 10)
	avatar_root.rect_size = Vector2(76, 76)
	avatar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(avatar_root)

	var character_icon = _get_character_icon_texture(player_index)
	if character_icon != null:
		var icon = TextureRect.new()
		icon.texture = character_icon
		icon.expand = true
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.rect_position = Vector2(2, 10)
		icon.rect_size = Vector2(56, 56)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_root.add_child(icon)
	else:
		var fallback_root = Control.new()
		fallback_root.rect_position = Vector2(6, 16)
		fallback_root.rect_size = Vector2(52, 46)
		fallback_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar_root.add_child(fallback_root)
		_build_fallback_potato_face(fallback_root)

	var badge = Panel.new()
	badge.rect_position = Vector2(36, 2)
	badge.rect_size = Vector2(18, 18)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_stylebox_override("panel", _make_panel_style(Color(0.95, 0.66, 0.20, 1.0), Color(0.25, 0.17, 0.08, 0.92), 9))
	avatar_root.add_child(badge)

	var badge_label = Label.new()
	badge_label.text = str(player_index + 1) if player_index >= 0 else "?"
	badge_label.align = Label.ALIGN_CENTER
	badge_label.valign = Label.VALIGN_CENTER
	badge_label.rect_position = Vector2(0, -1)
	badge_label.rect_size = badge.rect_size
	badge_label.rect_scale = Vector2(0.62, 0.62)
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_label_style(badge_label, Color(0.14, 0.08, 0.03, 1))
	badge.add_child(badge_label)


func _build_fallback_potato_face(parent: Control) -> void:
	var eye_left = Panel.new()
	eye_left.rect_position = Vector2(16, 16)
	eye_left.rect_size = Vector2(5, 8)
	eye_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eye_left.add_stylebox_override("panel", _make_panel_style(Color(0.11, 0.08, 0.06, 1), Color(0.11, 0.08, 0.06, 1), 2))
	parent.add_child(eye_left)

	var eye_right = Panel.new()
	eye_right.rect_position = Vector2(31, 16)
	eye_right.rect_size = Vector2(5, 8)
	eye_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eye_right.add_stylebox_override("panel", _make_panel_style(Color(0.11, 0.08, 0.06, 1), Color(0.11, 0.08, 0.06, 1), 2))
	parent.add_child(eye_right)

	var mouth = Panel.new()
	mouth.rect_position = Vector2(19, 30)
	mouth.rect_size = Vector2(16, 3)
	mouth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouth.add_stylebox_override("panel", _make_panel_style(Color(0.11, 0.08, 0.06, 1), Color(0.11, 0.08, 0.06, 1), 2))
	parent.add_child(mouth)


func _get_character_icon_texture(player_index: int):
	if player_index < 0:
		return null
	var character = null
	if RunData != null and RunData.has_method("get_player_character"):
		if player_index < RunData.get_player_count():
			character = RunData.get_player_character(player_index)
	if character == null:
		character = _get_character_selection_player_character(player_index)
	if character == null:
		return null
	if character is Object and character.has_method("get_icon"):
		var icon_from_method = character.get_icon()
		if icon_from_method != null:
			return icon_from_method
	var icon_value = _safe_get(character, "icon", null)
	if icon_value != null:
		return icon_value
	return null


func _get_character_selection_player_character(player_index: int):
	var selection = _find_current_character_selection_node()
	if selection == null:
		return null
	var player_characters = selection.get("_player_characters")
	if typeof(player_characters) == TYPE_ARRAY and player_index >= 0 and player_index < player_characters.size():
		return player_characters[player_index]
	return null


func _find_current_character_selection_node() -> Node:
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return _find_character_selection_node_recursive(tree.current_scene)


func _find_character_selection_node_recursive(node: Node) -> Node:
	if node == null:
		return null
	if _is_character_selection_node(node):
		return node
	for child in node.get_children():
		var found = _find_character_selection_node_recursive(child)
		if found != null:
			return found
	return null


func _is_character_selection_node(node: Node) -> bool:
	if node == null:
		return false
	var script_res = node.get_script()
	var script_path = str(script_res.resource_path) if script_res != null else ""
	if script_path.find("ui/menus/run/character_selection.gd") != -1:
		return true
	return node.has_method("_play_mode_init") and node.has_method("_on_connected_players_updated")


func _build_bubble(holder: Control, bubble_w: int, bubble_h: int, text: String) -> void:
	var bubble_x = 84
	var bubble_y = 8

	var tail = Panel.new()
	tail.rect_position = Vector2(77, 37)
	tail.rect_size = Vector2(14, 14)
	tail.rect_rotation = 45
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.add_stylebox_override("panel", _make_panel_style(Color(1.0, 0.97, 0.87, 1.0), Color(0.20, 0.15, 0.08, 0.90), 4))
	holder.add_child(tail)

	var bubble = Panel.new()
	bubble.rect_position = Vector2(bubble_x, bubble_y)
	bubble.rect_size = Vector2(bubble_w, bubble_h)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_stylebox_override("panel", _make_panel_style(Color(1.0, 0.97, 0.87, 1.0), Color(0.20, 0.15, 0.08, 0.90), 16))
	holder.add_child(bubble)

	var label = Label.new()
	label.text = text
	label.align = Label.ALIGN_CENTER
	label.valign = Label.VALIGN_CENTER
	label.autowrap = true
	label.rect_position = Vector2(16, 10)
	label.rect_size = Vector2(bubble_w - 32, bubble_h - 20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_label_style(label, Color(0.13, 0.10, 0.06, 1))
	bubble.add_child(label)


func _resolve_message_text(message: Dictionary) -> String:
	var id = str(message.get("quick_chat_id", ""))
	if id != "":
		var text_by_id = _option_text_by_id(id)
		if text_by_id != "":
			return text_by_id
	var text = str(message.get("text", "")).strip_edges()
	if text.length() > TEXT_LIMIT:
		text = text.substr(0, TEXT_LIMIT)
	return text


func _resolve_message_screen_pos(message: Dictionary) -> Vector2:
	var vp = _get_viewport_size()
	var norm = message.get("screen_pos_norm", {})
	if typeof(norm) == TYPE_DICTIONARY and norm.has("x") and norm.has("y"):
		return Vector2(clamp(float(norm.get("x", 0.5)), 0.0, 1.0) * vp.x, clamp(float(norm.get("y", 0.5)), 0.0, 1.0) * vp.y)
	var raw = message.get("screen_pos", {})
	if typeof(raw) == TYPE_DICTIONARY:
		return Vector2(float(raw.get("x", vp.x * 0.5)), float(raw.get("y", vp.y * 0.5)))
	return vp * 0.5


func _ensure_overlay() -> void:
	if _overlay_layer != null and is_instance_valid(_overlay_layer) and _overlay_root != null and is_instance_valid(_overlay_root):
		_overlay_root.rect_size = _get_viewport_size()
		return
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "BrotatoOnlineQuickChatOverlay"
	_overlay_layer.layer = 127
	_overlay_layer.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(_overlay_layer)
	_overlay_root = Control.new()
	_overlay_root.name = "Root"
	_overlay_root.anchor_left = 0
	_overlay_root.anchor_top = 0
	_overlay_root.anchor_right = 1
	_overlay_root.anchor_bottom = 1
	_overlay_root.margin_left = 0
	_overlay_root.margin_top = 0
	_overlay_root.margin_right = 0
	_overlay_root.margin_bottom = 0
	_overlay_root.rect_size = _get_viewport_size()
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_layer.add_child(_overlay_root)


func _make_panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _apply_label_style(label: Label, color: Color) -> void:
	if label == null:
		return
	_ensure_shared_font()
	if _shared_font != null:
		label.add_font_override("font", _shared_font)
	label.add_color_override("font_color", color)


func _ensure_shared_font() -> void:
	if _shared_font != null:
		return
	for font_path in SHARED_FONT_PATHS:
		if not ResourceLoader.exists(font_path):
			continue
		var font = load(font_path)
		if font != null:
			_shared_font = font
			return


func _try_open_gamepad_wheel(device: int) -> void:
	if _wheel_active or not _can_use_quick_chat():
		return
	var center = _get_viewport_size() * 0.5
	_open_wheel(center)
	_gamepad_active = true
	_gamepad_device = device
	_update_selected_from_gamepad()


func _finish_gamepad_wheel(device: int) -> void:
	if not _wheel_active or not _gamepad_active or device != _gamepad_device:
		return
	if _selected_index >= 0:
		_submit_selected()
	_close_wheel()


func _set_gamepad_lt_down(device: int, down: bool) -> void:
	_gamepad_lt_down[device] = down


func _is_lt_button_index(button_index: int) -> bool:
	return GAMEPAD_LT_BUTTON_CANDIDATES.has(button_index)


func _is_lt_axis_index(axis_index: int) -> bool:
	return GAMEPAD_LT_AXIS_CANDIDATES.has(axis_index)


func _axis_value_is_pressed(value: float) -> bool:
	return value >= GAMEPAD_TRIGGER_THRESHOLD


func _is_right_stick_axis(axis_index: int) -> bool:
	for pair in GAMEPAD_RIGHT_STICK_AXES:
		if pair.has(axis_index):
			return true
	return false


func _get_right_stick_vector(device: int) -> Vector2:
	var best = Vector2.ZERO
	for pair in GAMEPAD_RIGHT_STICK_AXES:
		var v = Vector2(Input.get_joy_axis(device, int(pair[0])), Input.get_joy_axis(device, int(pair[1])))
		if v.length() > best.length():
			best = v
	return best


func _update_selected_from_gamepad() -> void:
	if not _wheel_active or not _gamepad_active:
		return
	var stick = _get_right_stick_vector(_gamepad_device)
	if stick.length() < GAMEPAD_STICK_DEADZONE:
		return
	_update_selected(_wheel_center + stick.normalized() * (WHEEL_RADIUS + 40.0))


func _safe_get(obj, prop: String, default_value = null):
	if obj == null:
		return default_value
	var value = default_value
	# Godot objects expose most Resource fields through get(); dictionaries need explicit lookup.
	if typeof(obj) == TYPE_DICTIONARY:
		return obj.get(prop, default_value)
	if obj is Object:
		value = obj.get(prop)
		return value if value != null else default_value
	return default_value


func _clamp_to_viewport(pos: Vector2, margin: Vector2) -> Vector2:
	var vp = _get_viewport_size()
	return Vector2(clamp(pos.x, margin.x, max(margin.x, vp.x - margin.x)), clamp(pos.y, margin.y, max(margin.y, vp.y - margin.y)))


func _clamp_top_left_to_viewport(pos: Vector2, size: Vector2) -> Vector2:
	var vp = _get_viewport_size()
	return Vector2(clamp(pos.x, 4.0, max(4.0, vp.x - size.x - 4.0)), clamp(pos.y, 4.0, max(4.0, vp.y - size.y - 4.0)))


func _get_viewport_size() -> Vector2:
	var viewport = get_viewport()
	if viewport == null:
		return Vector2(1280, 720)
	return viewport.get_visible_rect().size


func _get_local_player_index() -> int:
	var slot_manager = _get_slot_manager()
	if slot_manager != null:
		if slot_manager.has_method("get_local_mirrored_player_index"):
			var mirrored = int(slot_manager.get_local_mirrored_player_index())
			if mirrored >= 0:
				return mirrored
		if slot_manager.has_method("get_local_player_indices"):
			var indices = slot_manager.get_local_player_indices()
			if typeof(indices) == TYPE_ARRAY and not indices.empty():
				return int(indices[0])
	return 0


func _quick_chat_key(message: Dictionary) -> String:
	var origin = str(message.get("origin_steam_id", message.get("sender_steam_id", "")))
	var seq = int(message.get("seq", 0))
	if origin == "" or seq <= 0:
		return ""
	return origin + ":" + str(seq)


func _prune_seen_chat_keys() -> void:
	var now = OS.get_ticks_msec()
	if now - _last_seen_prune_msec < 5000:
		return
	_last_seen_prune_msec = now
	for key in _seen_chat_keys.keys():
		if now - int(_seen_chat_keys.get(key, now)) > 15000:
			_seen_chat_keys.erase(key)


func _option_text_by_index(index: int) -> String:
	if index < 0 or index >= OPTION_IDS.size():
		return ""
	return _option_text_by_id(OPTION_IDS[index])


func _option_text_by_id(id: String) -> String:
	match id:
		"come":
			return _t("BROTATO_ONLINE_QUICK_CHAT_STAY_ALIVE")
		"help":
			return _t("BROTATO_ONLINE_QUICK_CHAT_HURRY")
		"wait":
			return _t("BROTATO_ONLINE_QUICK_CHAT_ELLIPSIS")
		"ready":
			return _t("BROTATO_ONLINE_QUICK_CHAT_THIS_ONE")
		"buy":
			return _t("BROTATO_ONLINE_QUICK_CHAT_STRONG_STRONG")
		"no_reroll":
			return _t("BROTATO_ONLINE_QUICK_CHAT_QUESTION")
		"thanks":
			return _t("BROTATO_ONLINE_QUICK_CHAT_NO")
		"nice":
			return _t("BROTATO_ONLINE_QUICK_CHAT_WAIT_A_SEC")
	return ""


func _t(key: String) -> String:
	var parent = get_parent()
	if parent != null:
		var i18n = parent.get_node_or_null("BrotatoOnlineI18n")
		if i18n != null and i18n.has_method("get_text"):
			return str(i18n.call("get_text", key))
	return key


func _get_steam_lobby_manager() -> Node:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineSteamLobbyManager")


func _get_slot_manager() -> Node:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineOnlinePlayerSlotManager")
