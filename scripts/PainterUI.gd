extends CanvasLayer

var manager = null
var mod_dir_path = ""
var current_target = "body"
var current_preset = "default"
var current_edit_size = Vector2(150, 150)

var root: Control
var canvas = null
var title_label: Label
var status_label: Label
var preset_name_edit: LineEdit
var preset_option: OptionButton
var target_option: OptionButton
var resolution_option: OptionButton
var enabled_check: CheckBox
var restrict_check: CheckBox
var skip_item_check: CheckBox
var brush_size_option: OptionButton
var brush_button: Button
var eraser_button: Button
var exit_button: Button
var palette_grid: GridContainer
var custom_color_picker = null

var _game_theme = null
var _title_font = null
var _label_font = null
var _selected_palette_index = 0
var _current_color = Color(1, 1, 1, 1)
var _current_tool = "brush"
var _is_closing = false
var _allow_preset_focus_release = false
var _suspended_focus_emulator_states = []
var _suspended_text_input_action_events = []



func _ready() -> void:
	_suspend_text_input_conflicting_actions()
	call_deferred("_suspend_game_focus_emulators")


func _exit_tree() -> void:
	_restore_text_input_conflicting_actions()
	_restore_game_focus_emulators()


func setup(p_manager, p_mod_dir_path: String) -> void:
	manager = p_manager
	mod_dir_path = p_mod_dir_path
	current_preset = manager.active_preset
	current_target = "body"
	current_edit_size = manager.body_edit_size
	_load_style_resources()
	_build_ui()
	_reload_preset_list()
	_reload_palette_grid()
	_load_canvas_image()



func _suspend_text_input_conflicting_actions() -> void:
	_restore_text_input_conflicting_actions()
	var text_keys = _text_input_conflicting_scancodes()
	for action_name in InputMap.get_actions():
		var action_string = String(action_name)
		if not _is_text_input_conflicting_action(action_string):
			continue
		var action_events = InputMap.get_action_list(action_name)
		for input_event in action_events:
			if not input_event is InputEventKey:
				continue
			if text_keys.has(input_event.scancode) or text_keys.has(input_event.physical_scancode):
				_suspended_text_input_action_events.push_back([action_name, input_event])
				InputMap.action_erase_event(action_name, input_event)


func _restore_text_input_conflicting_actions() -> void:
	for entry in _suspended_text_input_action_events:
		if entry.size() < 2:
			continue
		var action_name = entry[0]
		var input_event = entry[1]
		if InputMap.has_action(action_name):
			InputMap.action_add_event(action_name, input_event)
	_suspended_text_input_action_events.clear()


func _is_text_input_conflicting_action(action_name: String) -> bool:
	var base_action = action_name
	var last_underscore = action_name.rfind("_")
	if last_underscore >= 0:
		var suffix = action_name.substr(last_underscore + 1, action_name.length() - last_underscore - 1)
		if suffix.is_valid_integer():
			base_action = action_name.substr(0, last_underscore)
	return base_action in [
		"ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_pause", "ui_cancel", "ui_info", "ui_select", "ui_ban",
		"move_up", "move_down", "move_left", "move_right", "move_accept", "move_pause", "move_cancel", "move_info", "move_select", "move_ban"
	]


func _text_input_conflicting_scancodes() -> Array:
	# 原版/调试多人键盘会把这些字母映射成合作 UI/移动动作；中文输入 preset 名称时必须临时摘掉。
	return [
		KEY_W, KEY_A, KEY_S, KEY_D, KEY_E, KEY_Q, KEY_Z, KEY_X, KEY_C,
		KEY_T, KEY_F, KEY_G, KEY_H, KEY_Y, KEY_R, KEY_V, KEY_B, KEY_N,
		KEY_I, KEY_J, KEY_K, KEY_L, KEY_O, KEY_U, KEY_M, KEY_COMMA, KEY_PERIOD
	]


func _suspend_game_focus_emulators() -> void:
	_restore_game_focus_emulators()
	var tree = get_tree()
	if tree == null:
		return
	_collect_focus_emulators(tree.get_root())


func _collect_focus_emulators(node: Node) -> void:
	if node == null:
		return
	if node != self and _is_focus_emulator_node(node):
		_suspended_focus_emulator_states.push_back([node, node.is_processing_input(), node.is_processing_unhandled_input()])
		node.set_process_input(false)
		node.set_process_unhandled_input(false)
	for child in node.get_children():
		_collect_focus_emulators(child)



func _is_focus_emulator_node(node: Node) -> bool:
	if node == null:
		return false
	if node.has_method("get_class") and node.get_class() == "FocusEmulator":
		return true
	var script = node.get_script()
	if script != null and script is Resource:
		var path = script.resource_path
		if path.ends_with("/focus_emulator.gd"):
			return true
	return node.name.begins_with("FocusEmulator")


func _restore_game_focus_emulators() -> void:
	for entry in _suspended_focus_emulator_states:
		if entry.size() < 3:
			continue
		var node = entry[0]
		if is_instance_valid(node):
			node.set_process_input(entry[1])
			node.set_process_unhandled_input(entry[2])
	_suspended_focus_emulator_states.clear()


func _input(event) -> void:
	if event is InputEventMouseButton and event.pressed:
		if preset_name_edit != null and preset_name_edit.has_focus():
			var clicked_inside_name = preset_name_edit.get_global_rect().has_point(event.position)
			if not clicked_inside_name:
				_allow_preset_focus_release = true
				call_deferred("_clear_preset_focus_release")
	if event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
		if preset_name_edit != null and preset_name_edit.has_focus():
			_allow_preset_focus_release = true
			preset_name_edit.release_focus()
			get_tree().set_input_as_handled()
			return
		_close()


func _t(key: String) -> String:
	if manager != null and manager.has_method("get_text"):
		return manager.get_text(key)
	return key


func _load_style_resources() -> void:
	_game_theme = load("res://resources/themes/base_theme.tres")
	_title_font = load("res://resources/fonts/actual/base/font_40_outline.tres")
	_label_font = load("res://resources/fonts/actual/base/font_22.tres")


func _build_ui() -> void:
	root = Control.new()
	root.name = "DrawYourPotatoRoot"
	root.anchor_right = 1
	root.anchor_bottom = 1
	if _game_theme != null:
		root.theme = _game_theme
	add_child(root)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.78)
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	root.add_child(bg)

	var outer = HBoxContainer.new()
	outer.anchor_left = 0.01
	outer.anchor_top = 0.06
	outer.anchor_right = 0.99
	outer.anchor_bottom = 0.94
	outer.add_constant_override("separation", 18)
	root.add_child(outer)

	exit_button = _make_button(_t("EXIT_TO_MAIN_MENU"))
	exit_button.rect_min_size = Vector2(220, 54)
	exit_button.anchor_left = 0.02
	exit_button.anchor_top = 0.875
	exit_button.anchor_right = 0.16
	exit_button.anchor_bottom = 0.94
	exit_button.connect("pressed", self, "_close")
	root.add_child(exit_button)

	var palette_panel = _make_panel(Vector2(580, 720))
	outer.add_child(palette_panel)
	var palette_vbox = _make_scrolled_vbox(palette_panel, 24)

	_add_section_label(palette_vbox, _t("SECTION_PALETTE"))
	palette_grid = GridContainer.new()
	palette_grid.columns = 5
	palette_grid.add_constant_override("hseparation", 8)
	palette_grid.add_constant_override("vseparation", 8)
	palette_vbox.add_child(palette_grid)

	_add_section_label(palette_vbox, _t("CUSTOM_COLOR"))
	custom_color_picker = ColorPickerButton.new()
	custom_color_picker.rect_min_size = Vector2(0, 50)
	custom_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_color_picker.color = _current_color
	custom_color_picker.connect("color_changed", self, "_on_custom_color_changed")
	palette_vbox.add_child(custom_color_picker)
	call_deferred("_configure_color_picker_popup")

	var palette_actions = HBoxContainer.new()
	palette_actions.add_constant_override("separation", 8)
	palette_vbox.add_child(palette_actions)
	var add_color_btn = _make_button(_t("ADD_COLOR"))
	add_color_btn.connect("pressed", self, "_on_add_color_pressed")
	palette_actions.add_child(add_color_btn)
	var delete_color_btn = _make_button(_t("DELETE_COLOR"))
	delete_color_btn.connect("pressed", self, "_on_delete_color_pressed")
	palette_actions.add_child(delete_color_btn)

	var canvas_panel = _make_panel(Vector2(720, 720))
	outer.add_child(canvas_panel)

	var canvas_outer_margin = _make_margin(26)
	canvas_panel.add_child(canvas_outer_margin)

	var canvas_vbox = VBoxContainer.new()
	canvas_vbox.add_constant_override("separation", 16)
	canvas_outer_margin.add_child(canvas_vbox)

	title_label = Label.new()
	title_label.text = _t("TITLE")
	title_label.align = Label.ALIGN_CENTER
	if _title_font != null:
		title_label.add_font_override("font", _title_font)
	title_label.add_color_override("font_color", Color(1, 1, 1, 1))
	canvas_vbox.add_child(title_label)

	var canvas_frame = PanelContainer.new()
	canvas_frame.rect_min_size = Vector2(640, 640)
	canvas_vbox.add_child(canvas_frame)
	var canvas_margin = _make_margin(10)
	canvas_frame.add_child(canvas_margin)

	var canvas_script = load(mod_dir_path.plus_file("Scripts/PainterCanvas.gd"))
	canvas = canvas_script.new()
	canvas.rect_min_size = Vector2(620, 620)
	canvas.connect("image_changed", self, "_on_canvas_changed")
	canvas_margin.add_child(canvas)

	status_label = Label.new()
	status_label.text = ""
	status_label.align = Label.ALIGN_CENTER
	status_label.autowrap = true
	if _label_font != null:
		status_label.add_font_override("font", _label_font)
	status_label.add_color_override("font_color", Color(1, 1, 1, 1))
	canvas_vbox.add_child(status_label)

	var controls_panel = _make_panel(Vector2(500, 720))
	outer.add_child(controls_panel)
	var vbox = _make_scrolled_vbox(controls_panel, 22)

	_add_section_label(vbox, _t("SECTION_FILE"))
	preset_option = _make_option_button()
	preset_option.connect("item_selected", self, "_on_preset_selected")
	vbox.add_child(preset_option)

	preset_name_edit = LineEdit.new()
	preset_name_edit.placeholder_text = "default"
	preset_name_edit.text = current_preset
	preset_name_edit.rect_min_size = Vector2(0, 44)
	preset_name_edit.focus_mode = Control.FOCUS_CLICK
	preset_name_edit.connect("focus_entered", self, "_on_preset_name_focus_entered")
	preset_name_edit.connect("focus_exited", self, "_on_preset_name_focus_exited")
	preset_name_edit.connect("text_entered", self, "_on_preset_name_text_entered")
	vbox.add_child(preset_name_edit)

	var preset_buttons = HBoxContainer.new()
	preset_buttons.add_constant_override("separation", 8)
	vbox.add_child(preset_buttons)
	var save_btn = _make_button(_t("SAVE_CURRENT"))
	save_btn.connect("pressed", self, "_on_save_pressed")
	preset_buttons.add_child(save_btn)
	var load_btn = _make_button(_t("LOAD"))
	load_btn.connect("pressed", self, "_on_load_pressed")
	preset_buttons.add_child(load_btn)
	var delete_btn = _make_button(_t("DELETE_PRESET"))
	delete_btn.connect("pressed", self, "_on_delete_preset_pressed")
	preset_buttons.add_child(delete_btn)

	_add_section_label(vbox, _t("SECTION_TARGET"))
	target_option = _make_option_button()
	target_option.add_item(_t("TARGET_BODY"))
	target_option.add_item(_t("TARGET_LEGS"))
	target_option.select(0)
	target_option.connect("item_selected", self, "_on_target_selected")
	vbox.add_child(target_option)

	_add_section_label(vbox, _t("SECTION_RESOLUTION"))
	resolution_option = _make_option_button()
	resolution_option.connect("item_selected", self, "_on_resolution_selected")
	vbox.add_child(resolution_option)
	_reload_resolution_options()

	_add_section_label(vbox, _t("SECTION_TOOLS"))
	var tool_buttons = HBoxContainer.new()
	tool_buttons.add_constant_override("separation", 8)
	vbox.add_child(tool_buttons)
	brush_button = _make_tool_button(_t("TOOL_BRUSH"))
	brush_button.connect("pressed", self, "_on_brush_pressed")
	tool_buttons.add_child(brush_button)
	eraser_button = _make_tool_button(_t("TOOL_ERASER"))
	eraser_button.connect("pressed", self, "_on_eraser_pressed")
	tool_buttons.add_child(eraser_button)
	_refresh_tool_buttons()
	var undo_btn = _make_button(_t("UNDO"))
	undo_btn.connect("pressed", self, "_on_undo_pressed")
	tool_buttons.add_child(undo_btn)

	var brush_row = HBoxContainer.new()
	brush_row.add_constant_override("separation", 10)
	vbox.add_child(brush_row)
	_add_section_label(brush_row, _t("BRUSH_SIZE"))
	brush_size_option = _make_option_button()
	for s in [1, 2, 3, 4, 6, 8]:
		brush_size_option.add_item(str(s))
	brush_size_option.select(0)
	brush_size_option.rect_min_size = Vector2(120, 44)
	brush_size_option.connect("item_selected", self, "_on_brush_size_selected")
	brush_row.add_child(brush_size_option)

	_add_section_label(vbox, _t("SECTION_OPTIONS"))
	enabled_check = _make_check_box(_t("ENABLE_CUSTOM"))
	enabled_check.pressed = manager.enabled
	enabled_check.connect("toggled", self, "_on_enabled_toggled")
	vbox.add_child(enabled_check)

	restrict_check = _make_check_box(_t("RESTRICT_MASK"))
	restrict_check.pressed = manager.restrict_to_mask
	restrict_check.connect("toggled", self, "_on_restrict_toggled")
	vbox.add_child(restrict_check)

	skip_item_check = _make_check_box(_t("SKIP_ITEM_APPEARANCE"))
	skip_item_check.pressed = manager.skip_item_appearances
	skip_item_check.connect("toggled", self, "_on_skip_item_toggled")
	vbox.add_child(skip_item_check)

	var reset_btn = _make_button(_t("RESET_BASE"))
	reset_btn.connect("pressed", self, "_on_reset_pressed")
	vbox.add_child(reset_btn)

	_set_status(_t("STATUS_INIT"))


func _configure_color_picker_popup() -> void:
	if custom_color_picker == null:
		return
	var picker = custom_color_picker.get_picker()
	if picker != null:
		picker.rect_min_size = Vector2(620, 520)
		_widen_color_picker_line_edits(picker)
	var popup = custom_color_picker.get_popup()
	if popup != null:
		popup.rect_min_size = Vector2(660, 0)


func _widen_color_picker_line_edits(node: Node) -> void:
	if node is LineEdit:
		var edit = node
		var min_size = edit.rect_min_size
		min_size.x = max(min_size.x, 110)
		edit.rect_min_size = min_size
	for child in node.get_children():
		_widen_color_picker_line_edits(child)


func _make_panel(min_size: Vector2) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.rect_min_size = min_size
	return panel


func _make_margin(amount: int) -> MarginContainer:
	var margin = MarginContainer.new()
	margin.add_constant_override("margin_left", amount)
	margin.add_constant_override("margin_top", amount)
	margin.add_constant_override("margin_right", amount)
	margin.add_constant_override("margin_bottom", amount)
	return margin


func _make_scrolled_vbox(parent: Node, margin_amount: int) -> VBoxContainer:
	var margin = _make_margin(margin_amount)
	parent.add_child(margin)
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.scroll_horizontal_enabled = false
	scroll.scroll_vertical_enabled = true
	margin.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.add_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	var top_spacer = Control.new()
	top_spacer.rect_min_size = Vector2(0, 12)
	vbox.add_child(top_spacer)
	return vbox


func _add_section_label(parent: Node, text: String) -> void:
	var label = Label.new()
	label.text = text
	label.align = Label.ALIGN_LEFT
	if _label_font != null:
		label.add_font_override("font", _label_font)
	label.add_color_override("font_color", Color(1, 1, 1, 1))
	parent.add_child(label)


func _make_option_button() -> OptionButton:
	var option = OptionButton.new()
	option.rect_min_size = Vector2(0, 44)
	option.focus_mode = Control.FOCUS_NONE
	_apply_stable_option_style(option)
	return option


func _make_check_box(text: String) -> CheckBox:
	var check = CheckBox.new()
	check.text = text
	check.rect_min_size = Vector2(0, 42)
	check.focus_mode = Control.FOCUS_NONE
	check.add_color_override("font_color", Color(0, 0, 0, 1))
	check.add_color_override("font_color_hover", Color(0, 0, 0, 1))
	check.add_color_override("font_color_focus", Color(0, 0, 0, 1))
	check.add_color_override("font_color_pressed", Color(0, 0, 0, 1))
	if _label_font != null:
		check.add_font_override("font", _label_font)
	var style = _make_flat_style(Color(0.82, 0.82, 0.82, 1), Color(0.82, 0.82, 0.82, 1), 2, 8)
	for key in ["normal", "hover", "pressed", "focus"]:
		check.add_stylebox_override(key, style)
	return check


func _make_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.rect_min_size = Vector2(0, 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_color_override("font_color_focus", Color(0, 0, 0, 1))
	btn.add_color_override("font_color_hover", Color(0, 0, 0, 1))
	btn.add_color_override("font_color_pressed", Color(0, 0, 0, 1))
	var script = load("res://ui/menus/global/my_menu_button.gd")
	if script != null:
		btn.set_script(script)
	return btn


func _make_tool_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.rect_min_size = Vector2(0, 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return btn


func _refresh_tool_buttons() -> void:
	_apply_tool_button_style(brush_button, _current_tool == "brush")
	_apply_tool_button_style(eraser_button, _current_tool == "eraser")


func _apply_tool_button_style(btn: Button, selected: bool) -> void:
	if btn == null:
		return
	var bg = Color(0.82, 0.82, 0.82, 1) if selected else Color(0.02, 0.02, 0.02, 0.55)
	var border = Color(0.9, 0.9, 0.9, 1) if selected else Color(0.18, 0.18, 0.18, 1)
	var font = Color(0, 0, 0, 1) if selected else Color(1, 1, 1, 1)
	var style = _make_flat_style(bg, border, 3, 8)
	for key in ["normal", "hover", "focus", "pressed"]:
		btn.add_stylebox_override(key, style)
	for key in ["font_color", "font_color_hover", "font_color_focus", "font_color_pressed"]:
		btn.add_color_override(key, font)


func _apply_stable_option_style(control: Control) -> void:
	var style = _make_flat_style(Color(0.02, 0.02, 0.02, 0.55), Color(0.18, 0.18, 0.18, 1), 2, 8)
	for key in ["normal", "hover", "focus", "pressed"]:
		control.add_stylebox_override(key, style)
	for key in ["font_color", "font_color_hover", "font_color_focus", "font_color_pressed"]:
		control.add_color_override(key, Color(1, 1, 1, 1))


func _make_flat_style(bg: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _add_palette_button(parent: Node, color: Color, index: int) -> void:
	var btn = Button.new()
	btn.text = ""
	btn.rect_min_size = Vector2(72, 46)
	btn.focus_mode = Control.FOCUS_NONE
	btn.hint_tooltip = _t("COLOR") + " " + str(index + 1)
	btn.add_stylebox_override("normal", _make_color_style(color, 0.85, index == _selected_palette_index))
	btn.add_stylebox_override("hover", _make_color_style(color.lightened(0.06), 0.95, index == _selected_palette_index))
	btn.add_stylebox_override("focus", _make_color_style(color, 0.85, index == _selected_palette_index))
	btn.add_stylebox_override("pressed", _make_color_style(color.darkened(0.12), 1.0, true))
	btn.connect("pressed", self, "_on_palette_color_pressed", [index, color])
	parent.add_child(btn)


func _make_color_style(color: Color, alpha: float, selected: bool = false) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, alpha)
	style.border_color = Color(1, 1, 1, 1) if selected else Color(0, 0, 0, 1)
	var border = 4
	style.border_width_left = border
	style.border_width_top = border
	style.border_width_right = border
	style.border_width_bottom = border
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _reload_preset_list() -> void:
	preset_option.clear()
	var presets = manager.get_presets()
	var selected = 0
	for i in range(presets.size()):
		preset_option.add_item(presets[i])
		if presets[i] == current_preset:
			selected = i
	preset_option.select(selected)
	preset_name_edit.text = current_preset


func _reload_resolution_options() -> void:
	resolution_option.clear()
	var resolutions = manager.get_target_resolutions(current_target)
	current_edit_size = manager.get_target_edit_size(current_target)
	var selected = 0
	for i in range(resolutions.size()):
		var r: Vector2 = resolutions[i]
		resolution_option.add_item(str(int(r.x)) + "×" + str(int(r.y)))
		if int(r.x) == int(current_edit_size.x) and int(r.y) == int(current_edit_size.y):
			selected = i
	resolution_option.select(selected)


func _reload_palette_grid() -> void:
	if palette_grid == null:
		return
	for child in palette_grid.get_children():
		palette_grid.remove_child(child)
		child.queue_free()
	var colors = manager.get_palette()
	if colors.empty():
		return
	_selected_palette_index = clamp(_selected_palette_index, 0, colors.size() - 1)
	_current_color = colors[_selected_palette_index]
	if custom_color_picker != null:
		custom_color_picker.color = _current_color
	for i in range(colors.size()):
		_add_palette_button(palette_grid, colors[i], i)
	if canvas != null:
		canvas.set_brush_color(_current_color)


func _load_canvas_image() -> void:
	current_edit_size = manager.get_target_edit_size(current_target)
	var edit_image: Image = manager.load_edit_image(current_target, current_preset, current_edit_size)
	var mask_image: Image = manager.get_mask_image(current_target, current_edit_size)
	canvas.set_images(edit_image, mask_image)
	canvas.set_restrict_to_mask(manager.restrict_to_mask)
	canvas.set_brush_color(_current_color)
	canvas.set_tool(_current_tool)
	_refresh_tool_buttons()
	_set_status(_t("STATUS_LOADED") + " " + current_preset + " / " + current_target + " / " + str(int(current_edit_size.x)) + "×" + str(int(current_edit_size.y)))


func _on_preset_selected(index: int) -> void:
	current_preset = preset_option.get_item_text(index)
	preset_name_edit.text = current_preset
	manager.set_active_preset(current_preset)
	_load_canvas_image()


func _on_target_selected(index: int) -> void:
	current_target = "body" if index == 0 else "legs"
	_reload_resolution_options()
	_load_canvas_image()


func _on_resolution_selected(index: int) -> void:
	var resolutions = manager.get_target_resolutions(current_target)
	if index < 0 or index >= resolutions.size():
		return
	current_edit_size = resolutions[index]
	manager.set_target_edit_size(current_target, current_edit_size)
	_save_current_meta_only()
	_load_canvas_image()


func _save_current_image() -> bool:
	if manager == null or canvas == null:
		return false
	current_preset = manager.get_safe_preset_name(preset_name_edit.text)
	if current_preset.empty():
		current_preset = "default"
	var ok = manager.save_edit_image(current_target, current_preset, canvas.get_image())
	manager.save_meta(current_preset)
	manager.set_active_preset(current_preset)
	return ok


func _on_save_pressed() -> void:
	var ok = _save_current_image()
	_reload_preset_list()
	_set_status((_t("STATUS_SAVE_OK") if ok else _t("STATUS_SAVE_FAIL")) + ": " + current_preset + " / " + current_target)


func _on_load_pressed() -> void:
	current_preset = manager.get_safe_preset_name(preset_name_edit.text)
	manager.set_active_preset(current_preset)
	_reload_preset_list()
	_load_canvas_image()


func _on_delete_preset_pressed() -> void:
	var to_delete = manager.get_safe_preset_name(preset_name_edit.text)
	if to_delete.empty():
		to_delete = "default"
	var ok = manager.delete_preset(to_delete)
	if ok:
		current_preset = manager.active_preset
		preset_name_edit.text = current_preset
		_reload_preset_list()
		_load_canvas_image()
		_set_status(_t("STATUS_DELETE_OK") + ": " + to_delete)
	else:
		_set_status(_t("STATUS_DELETE_FAIL") + ": " + to_delete)


func _on_brush_pressed() -> void:
	_current_tool = "brush"
	canvas.set_tool("brush")
	_refresh_tool_buttons()
	_set_status(_t("STATUS_TOOL_BRUSH"))


func _on_eraser_pressed() -> void:
	_current_tool = "eraser"
	canvas.set_tool("eraser")
	_refresh_tool_buttons()
	_set_status(_t("STATUS_TOOL_ERASER"))


func _on_undo_pressed() -> void:
	canvas.undo()


func _on_brush_size_selected(index: int) -> void:
	var size = int(brush_size_option.get_item_text(index))
	canvas.set_brush_size(size)
	_set_status(_t("STATUS_BRUSH_SIZE") + ": " + str(size))


func _on_palette_color_pressed(index: int, color: Color) -> void:
	_selected_palette_index = index
	_current_color = color
	_current_tool = "brush"
	canvas.set_brush_color(color)
	if custom_color_picker != null:
		custom_color_picker.color = color
	_reload_palette_grid()
	_refresh_tool_buttons()
	_set_status(_t("STATUS_TOOL_BRUSH"))


func _on_custom_color_changed(color: Color) -> void:
	_current_color = color
	_current_tool = "brush"
	if canvas != null:
		canvas.set_brush_color(color)
	_refresh_tool_buttons()


func _on_add_color_pressed() -> void:
	manager.add_palette_color(_current_color)
	_selected_palette_index = manager.get_palette().size() - 1
	_reload_palette_grid()
	_set_status(_t("STATUS_COLOR_ADDED"))


func _on_delete_color_pressed() -> void:
	if manager.remove_palette_color(_selected_palette_index):
		_selected_palette_index = max(0, _selected_palette_index - 1)
		_reload_palette_grid()
		_set_status(_t("STATUS_COLOR_DELETED"))
	else:
		_set_status(_t("STATUS_COLOR_DELETE_FAILED"))


func _on_enabled_toggled(value: bool) -> void:
	manager.set_enabled(value)
	_save_current_meta_only()
	_set_status(_t("STATUS_APPLIED"))


func _on_restrict_toggled(value: bool) -> void:
	manager.set_restrict_to_mask(value)
	canvas.set_restrict_to_mask(value)
	if skip_item_check != null:
		skip_item_check.set_block_signals(true)
		skip_item_check.pressed = not value
		skip_item_check.set_block_signals(false)
	manager.set_skip_item_appearances(not value)
	_save_current_meta_only()
	_set_status(_t("STATUS_APPLIED"))


func _on_skip_item_toggled(value: bool) -> void:
	manager.set_skip_item_appearances(value)
	_save_current_meta_only()
	_set_status(_t("STATUS_APPLIED"))


func _on_reset_pressed() -> void:
	var base: Image = manager.get_base_edit_image(current_target, current_edit_size)
	canvas.clear_to_image(base)
	_set_status(_t("STATUS_RESET_BASE"))


func _save_current_meta_only() -> void:
	if manager == null:
		return
	var meta_preset = current_preset
	if preset_name_edit != null:
		meta_preset = manager.get_safe_preset_name(preset_name_edit.text)
	if meta_preset.empty():
		meta_preset = "default"
	manager.save_meta(meta_preset)


func _on_preset_name_focus_entered() -> void:
	_allow_preset_focus_release = false


func _on_preset_name_focus_exited() -> void:
	# 中文输入法在组词/候选窗口弹出时可能会触发临时失焦。
	# 这里不能再立刻 grab_focus()，否则会打断 IME 组合状态，表现为拼音输到 a 等字母时候选窗口弹出又消失。
	call_deferred("_clear_preset_focus_release")


func _on_preset_name_text_entered(_text: String) -> void:
	_allow_preset_focus_release = true
	if preset_name_edit != null:
		preset_name_edit.release_focus()
	call_deferred("_clear_preset_focus_release")


func _clear_preset_focus_release() -> void:
	_allow_preset_focus_release = false


func _on_canvas_changed() -> void:
	pass


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _close() -> void:
	if _is_closing:
		return
	_is_closing = true
	_save_current_image()
	_restore_text_input_conflicting_actions()
	_restore_game_focus_emulators()
	if manager != null:
		manager.close_painter(self)
	queue_free()
