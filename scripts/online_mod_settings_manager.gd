extends Node

const SETTINGS_FILE_PATH = "user://brotato_online_settings.cfg"
const SETTINGS_SECTION = "display"
const KEY_LOCAL_CHARACTER_OUTLINE = "local_character_outline"
const DEFAULT_LOCAL_CHARACTER_OUTLINE = false
const KEY_AUTO_JOIN_HOST_PLAYER = "auto_join_host_player"
const DEFAULT_AUTO_JOIN_HOST_PLAYER = true
const META_AUTO_JOIN_HOST_PLAYER = "brotato_online_auto_join_host_player"

const SETTINGS_BUTTON_NAME = "BrotatoOnlineSettingsButton"
const SETTINGS_OVERLAY_NAME = "BrotatoOnlineSettingsOverlay"
const META_LOCAL_OUTLINE_COLOR = "brotato_online_local_outline_color"
const META_LOCAL_OUTLINE_OWNED = "brotato_online_local_outline_owned"

var _local_character_outline_enabled = DEFAULT_LOCAL_CHARACTER_OUTLINE
var _auto_join_host_player_enabled = DEFAULT_AUTO_JOIN_HOST_PLAYER
var _last_scan_msec = 0
var _settings_button = null
var _settings_overlay = null
var _local_outline_button = null
var _local_outline_description_label = null
var _auto_join_host_button = null
var _auto_join_host_description_label = null
var _title_label = null
var _description_label = null
var _back_button = null
var _last_focus_owner = null
var _i18n = null


func _ready() -> void:
	_load_settings()
	_publish_settings_meta()
	set_process(true)
	set_process_input(false)


func _process(_delta: float) -> void:
	var now = OS.get_ticks_msec()
	if now - _last_scan_msec < 500:
		return
	_last_scan_msec = now
	_try_inject_title_screen_settings_button()
	_refresh_settings_button_text_only()
	if _settings_overlay != null and is_instance_valid(_settings_overlay) and _settings_overlay.visible:
		_refresh_localized_texts()
	if _local_character_outline_enabled or _has_any_local_outline_meta():
		_apply_outline_to_live_players()


func _input(event) -> void:
	if _settings_overlay == null or not is_instance_valid(_settings_overlay):
		return
	if not _settings_overlay.visible:
		return
	if event.is_action_released("ui_cancel"):
		_close_settings_overlay()
		get_tree().set_input_as_handled()


func get_local_character_outline_enabled() -> bool:
	return _local_character_outline_enabled


func set_local_character_outline_enabled(enabled: bool) -> void:
	if _local_character_outline_enabled == enabled:
		return
	_local_character_outline_enabled = enabled
	_save_settings()
	_publish_settings_meta()
	_apply_outline_to_live_players()


func get_auto_join_host_player_enabled() -> bool:
	return _auto_join_host_player_enabled


func set_auto_join_host_player_enabled(enabled: bool) -> void:
	if _auto_join_host_player_enabled == enabled:
		return
	_auto_join_host_player_enabled = enabled
	_save_settings()
	_publish_settings_meta()
	_notify_slot_manager_settings_changed()


func is_online_session_active() -> bool:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return false
	return bool(tree.root.get_meta("brotato_online_session_active", false))


func get_local_player_index() -> int:
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("get_local_mirrored_player_index"):
		var mirrored_index = int(slot_manager.call("get_local_mirrored_player_index"))
		if mirrored_index >= 0:
			return mirrored_index

	if is_online_session_active() and CoopService != null and CoopService.connected_players.size() > 0:
		return 0

	return -1


func _get_i18n_manager():
	if _i18n != null and is_instance_valid(_i18n):
		return _i18n
	var parent = get_parent()
	if parent != null:
		_i18n = parent.get_node_or_null("BrotatoOnlineI18n")
	return _i18n


func _txt(key: String) -> String:
	var i18n = _get_i18n_manager()
	if i18n != null and i18n.has_method("get_text"):
		return str(i18n.call("get_text", key))
	return key


func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE_PATH)
	if err == OK:
		_local_character_outline_enabled = bool(config.get_value(
			SETTINGS_SECTION,
			KEY_LOCAL_CHARACTER_OUTLINE,
			DEFAULT_LOCAL_CHARACTER_OUTLINE
		))
		_auto_join_host_player_enabled = bool(config.get_value(
			SETTINGS_SECTION,
			KEY_AUTO_JOIN_HOST_PLAYER,
			DEFAULT_AUTO_JOIN_HOST_PLAYER
		))
	else:
		_local_character_outline_enabled = DEFAULT_LOCAL_CHARACTER_OUTLINE
		_auto_join_host_player_enabled = DEFAULT_AUTO_JOIN_HOST_PLAYER


func _save_settings() -> void:
	var config = ConfigFile.new()
	var _load_err = config.load(SETTINGS_FILE_PATH)
	config.set_value(SETTINGS_SECTION, KEY_LOCAL_CHARACTER_OUTLINE, _local_character_outline_enabled)
	config.set_value(SETTINGS_SECTION, KEY_AUTO_JOIN_HOST_PLAYER, _auto_join_host_player_enabled)
	var _save_err = config.save(SETTINGS_FILE_PATH)


func _publish_settings_meta() -> void:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return
	tree.root.set_meta("brotato_online_local_character_outline", _local_character_outline_enabled)
	tree.root.set_meta(META_AUTO_JOIN_HOST_PLAYER, _auto_join_host_player_enabled)


func _notify_slot_manager_settings_changed() -> void:
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("on_online_settings_changed"):
		slot_manager.call("on_online_settings_changed")


func _refresh_settings_button_text_only() -> void:
	if _settings_button != null and is_instance_valid(_settings_button):
		_settings_button.text = _txt("BROTATO_ONLINE_MENU_SETTINGS")


func _try_inject_title_screen_settings_button() -> void:
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return

	var main_menu = tree.current_scene.get_node_or_null("Menus/MainMenu")
	if main_menu == null or not is_instance_valid(main_menu):
		_settings_button = null
		_settings_overlay = null
		_local_outline_button = null
		_local_outline_description_label = null
		_auto_join_host_button = null
		_auto_join_host_description_label = null
		_title_label = null
		_description_label = null
		_back_button = null
		return

	var right_buttons = main_menu.get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/ButtonsRight")
	if right_buttons == null or not is_instance_valid(right_buttons):
		return

	var existing_button = right_buttons.get_node_or_null(SETTINGS_BUTTON_NAME)
	if existing_button != null and is_instance_valid(existing_button):
		_settings_button = existing_button
		if not _settings_button.is_connected("pressed", self, "_on_settings_button_pressed"):
			var _existing_press_err = _settings_button.connect("pressed", self, "_on_settings_button_pressed")
		_refresh_settings_button_text_only()
		return

	var button = Button.new()
	button.name = SETTINGS_BUTTON_NAME
	button.text = _txt("BROTATO_ONLINE_MENU_SETTINGS")
	button.rect_min_size = Vector2(0, 65)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.align = 0
	button.expand_icon = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	# Keep the startup injection lightweight: create a plain Button only.
	# The settings overlay and input handling are created lazily when pressed.
	right_buttons.add_child(button)

	var mods_button = right_buttons.get_node_or_null("ModsButton")
	if mods_button != null and is_instance_valid(mods_button):
		right_buttons.move_child(button, max(0, mods_button.get_index() + 1))

	var _connect_err = button.connect("pressed", self, "_on_settings_button_pressed")
	_settings_button = button
	_refresh_settings_button_text_only()


func _refresh_settings_button_focus(main_menu: Node, right_buttons: Node) -> void:
	if _settings_button == null or not is_instance_valid(_settings_button):
		return

	var options_button = main_menu.get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/ButtonsLeft/OptionsButton")
	if options_button != null and is_instance_valid(options_button):
		_settings_button.focus_neighbour_left = _settings_button.get_path_to(options_button)
		_settings_button.focus_neighbour_right = _settings_button.get_path_to(options_button)

	var previous_button = _find_visible_button_before(right_buttons, _settings_button)
	var next_button = _find_visible_button_after(right_buttons, _settings_button)

	if previous_button != null:
		_settings_button.focus_neighbour_top = _settings_button.get_path_to(previous_button)
		previous_button.focus_neighbour_bottom = previous_button.get_path_to(_settings_button)

	if next_button != null:
		_settings_button.focus_neighbour_bottom = _settings_button.get_path_to(next_button)
		next_button.focus_neighbour_top = next_button.get_path_to(_settings_button)


func _find_visible_button_before(container: Node, target: Node):
	var children = container.get_children()
	var index = children.find(target)
	for i in range(index - 1, -1, -1):
		var child = children[i]
		if child is Button and child.visible and not child.disabled:
			return child
	return null


func _find_visible_button_after(container: Node, target: Node):
	var children = container.get_children()
	var index = children.find(target)
	for i in range(index + 1, children.size()):
		var child = children[i]
		if child is Button and child.visible and not child.disabled:
			return child
	return null


func _ensure_settings_overlay(title_screen: Node) -> void:
	if title_screen == null or not is_instance_valid(title_screen):
		return

	var existing_overlay = title_screen.get_node_or_null(SETTINGS_OVERLAY_NAME)
	if existing_overlay != null and is_instance_valid(existing_overlay):
		_settings_overlay = existing_overlay
		_title_label = existing_overlay.get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel")
		_local_outline_button = existing_overlay.get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LocalCharacterOutlineButton")
		_local_outline_description_label = existing_overlay.get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/LocalCharacterOutlineDescriptionLabel")
		_auto_join_host_button = existing_overlay.get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/AutoJoinHostPlayerButton")
		_auto_join_host_description_label = existing_overlay.get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/AutoJoinHostPlayerDescriptionLabel")
		_description_label = existing_overlay.get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DescriptionLabel")
		_back_button = existing_overlay.get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BackButton")
		_connect_runtime_mouse_focus(_local_outline_button)
		_connect_runtime_mouse_focus(_auto_join_host_button)
		_connect_runtime_mouse_focus(_back_button)
		return

	var overlay = Control.new()
	overlay.name = SETTINGS_OVERLAY_NAME
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	var base_theme = load("res://resources/themes/base_theme.tres")
	if base_theme != null:
		overlay.theme = base_theme
	title_screen.add_child(overlay)

	var dim = ColorRect.new()
	dim.name = "DimBackground"
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0, 0, 0, 0.66)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.name = "PanelContainer"
	panel.rect_min_size = Vector2(900, 540)
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.name = "MarginContainer"
	margin.add_constant_override("margin_left", 40)
	margin.add_constant_override("margin_right", 40)
	margin.add_constant_override("margin_top", 35)
	margin.add_constant_override("margin_bottom", 35)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_constant_override("separation", 16)
	margin.add_child(vbox)

	var title = Label.new()
	title.name = "TitleLabel"
	title.text = _txt("BROTATO_ONLINE_SETTINGS_TITLE")
	title.align = Label.ALIGN_CENTER
	var title_font = load("res://resources/fonts/actual/base/font_40_outline.tres")
	if title_font != null:
		title.add_font_override("font", title_font)
	vbox.add_child(title)
	_title_label = title

	var check = CheckButton.new()
	check.name = "LocalCharacterOutlineButton"
	check.text = _txt("BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE")
	check.pressed = _local_character_outline_enabled
	check.rect_min_size = Vector2(0, 62)
	check.focus_mode = Control.FOCUS_ALL
	check.mouse_filter = Control.MOUSE_FILTER_STOP
	check.align = 0
	_configure_option_check_button(check)
	vbox.add_child(check)
	var _check_err = check.connect("toggled", self, "_on_local_character_outline_toggled")
	_local_outline_button = check
	_connect_runtime_mouse_focus(_local_outline_button)

	var local_outline_description = _create_settings_description_label("LocalCharacterOutlineDescriptionLabel", "BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE_DESC")
	vbox.add_child(local_outline_description)
	_local_outline_description_label = local_outline_description
	_description_label = local_outline_description

	var auto_join_check = CheckButton.new()
	auto_join_check.name = "AutoJoinHostPlayerButton"
	auto_join_check.text = _txt("BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER")
	auto_join_check.pressed = _auto_join_host_player_enabled
	auto_join_check.rect_min_size = Vector2(0, 62)
	auto_join_check.focus_mode = Control.FOCUS_ALL
	auto_join_check.mouse_filter = Control.MOUSE_FILTER_STOP
	auto_join_check.align = 0
	_configure_option_check_button(auto_join_check)
	vbox.add_child(auto_join_check)
	var _auto_join_check_err = auto_join_check.connect("toggled", self, "_on_auto_join_host_player_toggled")
	_auto_join_host_button = auto_join_check
	_connect_runtime_mouse_focus(_auto_join_host_button)

	var auto_join_description = _create_settings_description_label("AutoJoinHostPlayerDescriptionLabel", "BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER_DESC")
	vbox.add_child(auto_join_description)
	_auto_join_host_description_label = auto_join_description

	var spacer = Control.new()
	spacer.name = "Spacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = _txt("MENU_BACK")
	back_button.rect_min_size = Vector2(0, 65)
	back_button.align = 0
	back_button.focus_mode = Control.FOCUS_ALL
	back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(back_button)
	var _back_err = back_button.connect("pressed", self, "_close_settings_overlay")
	_back_button = back_button
	_connect_runtime_mouse_focus(_back_button)

	check.focus_neighbour_top = check.get_path_to(back_button)
	if _auto_join_host_button != null and is_instance_valid(_auto_join_host_button):
		check.focus_neighbour_bottom = check.get_path_to(_auto_join_host_button)
		_auto_join_host_button.focus_neighbour_top = _auto_join_host_button.get_path_to(check)
		_auto_join_host_button.focus_neighbour_bottom = _auto_join_host_button.get_path_to(back_button)
		back_button.focus_neighbour_top = back_button.get_path_to(_auto_join_host_button)
	else:
		check.focus_neighbour_bottom = check.get_path_to(back_button)
		back_button.focus_neighbour_top = back_button.get_path_to(check)
	back_button.focus_neighbour_bottom = back_button.get_path_to(check)

	_settings_overlay = overlay


func _create_settings_description_label(node_name: String, text_key: String) -> Label:
	var description = Label.new()
	description.name = node_name
	description.text = _txt(text_key)
	description.autowrap = true
	description.align = Label.ALIGN_LEFT
	var desc_font = load("res://resources/fonts/actual/base/font_22.tres")
	if desc_font != null:
		description.add_font_override("font", desc_font)
	return description


func _configure_option_check_button(check: CheckButton) -> void:
	var option_font = load("res://resources/fonts/actual/base/font_40_outline.tres")
	if option_font != null:
		check.add_font_override("font", option_font)

	var hover_style = load("res://resources/themes/button_styles/button_hover.tres")
	if hover_style != null:
		check.add_stylebox_override("hover", hover_style)
		check.add_stylebox_override("hover_pressed", hover_style)
		check.add_stylebox_override("focus", hover_style)


func _connect_runtime_mouse_focus(control) -> void:
	if control == null or not is_instance_valid(control):
		return
	if control.has_signal("mouse_entered") and not control.is_connected("mouse_entered", self, "_on_runtime_focusable_mouse_entered"):
		var _mouse_err = control.connect("mouse_entered", self, "_on_runtime_focusable_mouse_entered", [control])


func _on_runtime_focusable_mouse_entered(control) -> void:
	if control == null or not is_instance_valid(control):
		return
	if control is Button and control.disabled:
		return
	if control is Control:
		if control.focus_mode == Control.FOCUS_NONE:
			control.focus_mode = Control.FOCUS_ALL
		control.grab_focus()


func _refresh_localized_texts() -> void:
	if _settings_button != null and is_instance_valid(_settings_button):
		_settings_button.text = _txt("BROTATO_ONLINE_MENU_SETTINGS")
	if _title_label != null and is_instance_valid(_title_label):
		_title_label.text = _txt("BROTATO_ONLINE_SETTINGS_TITLE")
	if _local_outline_button != null and is_instance_valid(_local_outline_button):
		_local_outline_button.text = _txt("BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE")
	if _local_outline_description_label != null and is_instance_valid(_local_outline_description_label):
		_local_outline_description_label.text = _txt("BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE_DESC")
	elif _description_label != null and is_instance_valid(_description_label):
		_description_label.text = _txt("BROTATO_ONLINE_LOCAL_CHARACTER_OUTLINE_DESC")
	if _auto_join_host_button != null and is_instance_valid(_auto_join_host_button):
		_auto_join_host_button.text = _txt("BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER")
	if _auto_join_host_description_label != null and is_instance_valid(_auto_join_host_description_label):
		_auto_join_host_description_label.text = _txt("BROTATO_ONLINE_AUTO_JOIN_HOST_PLAYER_DESC")
	if _back_button != null and is_instance_valid(_back_button):
		_back_button.text = _txt("MENU_BACK")


func _on_settings_button_pressed() -> void:
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	_ensure_settings_overlay(tree.current_scene)
	_open_settings_overlay()


func _open_settings_overlay() -> void:
	if _settings_overlay == null or not is_instance_valid(_settings_overlay):
		return

	var focus_owner = null
	var viewport = get_viewport()
	if viewport != null and viewport.has_method("gui_get_focus_owner"):
		focus_owner = viewport.call("gui_get_focus_owner")
	if focus_owner != null and focus_owner is Control:
		_last_focus_owner = focus_owner
	else:
		_last_focus_owner = _settings_button

	if _local_outline_button != null and is_instance_valid(_local_outline_button):
		_local_outline_button.set_pressed_no_signal(_local_character_outline_enabled)
	if _auto_join_host_button != null and is_instance_valid(_auto_join_host_button):
		_auto_join_host_button.set_pressed_no_signal(_auto_join_host_player_enabled)

	_refresh_localized_texts()
	_settings_overlay.show()
	set_process_input(true)
	call_deferred("_focus_first_settings_control")


func _focus_first_settings_control() -> void:
	if _settings_overlay == null or not is_instance_valid(_settings_overlay):
		return
	if not _settings_overlay.visible:
		return
	if _local_outline_button != null and is_instance_valid(_local_outline_button):
		_local_outline_button.grab_focus()


func _close_settings_overlay() -> void:
	if _settings_overlay == null or not is_instance_valid(_settings_overlay):
		return
	_settings_overlay.hide()
	set_process_input(false)
	if _last_focus_owner != null and is_instance_valid(_last_focus_owner):
		_last_focus_owner.grab_focus()
	elif _settings_button != null and is_instance_valid(_settings_button):
		_settings_button.grab_focus()


func _on_local_character_outline_toggled(button_pressed: bool) -> void:
	set_local_character_outline_enabled(button_pressed)


func _on_auto_join_host_player_toggled(button_pressed: bool) -> void:
	set_auto_join_host_player_enabled(button_pressed)


func _has_any_local_outline_meta() -> bool:
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return false
	var players_value = tree.current_scene.get("_players")
	if typeof(players_value) == TYPE_ARRAY:
		for player in players_value:
			if player != null and typeof(player) == TYPE_OBJECT and is_instance_valid(player) and player.has_meta(META_LOCAL_OUTLINE_COLOR):
				return true
	return false


func _apply_outline_to_live_players() -> void:
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return

	var players_value = tree.current_scene.get("_players")
	if typeof(players_value) == TYPE_ARRAY:
		for player in players_value:
			_apply_outline_to_player(player)
		return

	_apply_outline_to_player_nodes_recursive(tree.current_scene, 0)


func _apply_outline_to_player_nodes_recursive(node: Node, depth: int) -> void:
	if node == null or not is_instance_valid(node) or depth > 8:
		return
	_apply_outline_to_player(node)
	for child in node.get_children():
		_apply_outline_to_player_nodes_recursive(child, depth + 1)


func _apply_outline_to_player(player) -> void:
	if player == null or typeof(player) != TYPE_OBJECT or not is_instance_valid(player):
		return
	if not player.has_method("add_outline") or not player.has_method("remove_outline"):
		return
	if player.get("player_index") == null:
		return

	# Stale player references can remain in Main._players for a short time while
	# the death/cleanup path is freeing child nodes. In that window remove_outline
	# can re-enter Player._set_outlines() and touch already-freed legs/sprites.
	# Drop only our metadata when the player is no longer safe to mutate; the
	# node is being cleaned anyway, and this prevents the both-players-dead crash.
	if not _is_player_outline_mutation_safe(player):
		_clear_local_outline_meta_only(player)
		return

	var should_outline = false
	if _local_character_outline_enabled and _is_online_coop_battle_player(player):
		var local_index = get_local_player_index()
		if local_index >= 0 and int(player.get("player_index")) == local_index:
			should_outline = true

	if should_outline:
		_add_or_update_local_outline(player)
	else:
		_remove_local_outline(player)


func _is_player_outline_mutation_safe(player) -> bool:
	if player == null or typeof(player) != TYPE_OBJECT or not is_instance_valid(player):
		return false
	if player.has_method("is_queued_for_deletion") and bool(player.call("is_queued_for_deletion")):
		return false
	var player_sprite = player.get("sprite")
	if player_sprite == null or typeof(player_sprite) != TYPE_OBJECT or not is_instance_valid(player_sprite):
		return false
	return true


func _clear_local_outline_meta_only(player) -> void:
	if player == null or typeof(player) != TYPE_OBJECT or not is_instance_valid(player):
		return
	if player.has_meta(META_LOCAL_OUTLINE_COLOR):
		player.remove_meta(META_LOCAL_OUTLINE_COLOR)
	if player.has_meta(META_LOCAL_OUTLINE_OWNED):
		player.remove_meta(META_LOCAL_OUTLINE_OWNED)


func _is_online_coop_battle_player(player) -> bool:
	if RunData == null or not bool(RunData.is_coop_run):
		return false
	if not is_online_session_active():
		return false
	var dead_value = player.get("dead")
	if dead_value != null and bool(dead_value):
		return false
	return true


func _add_or_update_local_outline(player) -> void:
	var outline_color = Utils.HIGHLIGHT_COLOR
	if CoopService != null and CoopService.has_method("get_player_color"):
		outline_color = CoopService.get_player_color(int(player.get("player_index")))
	outline_color.a = 1.0

	if player.has_meta(META_LOCAL_OUTLINE_COLOR):
		var old_color = player.get_meta(META_LOCAL_OUTLINE_COLOR)
		if old_color == outline_color and player.has_method("has_outline") and player.call("has_outline", outline_color):
			return
		_remove_local_outline(player)

	var already_had_same_outline = false
	if player.has_method("has_outline"):
		already_had_same_outline = bool(player.call("has_outline", outline_color))

	if not already_had_same_outline:
		var outline_colors = player.get("_outline_colors")
		if typeof(outline_colors) == TYPE_ARRAY and outline_colors.size() >= 4:
			return
		player.call("add_outline", outline_color)

	player.set_meta(META_LOCAL_OUTLINE_COLOR, outline_color)
	player.set_meta(META_LOCAL_OUTLINE_OWNED, not already_had_same_outline)


func _remove_local_outline(player) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not player.has_meta(META_LOCAL_OUTLINE_COLOR):
		return

	if not _is_player_outline_mutation_safe(player):
		_clear_local_outline_meta_only(player)
		return

	var outline_color = player.get_meta(META_LOCAL_OUTLINE_COLOR)
	var owned_outline = false
	if player.has_meta(META_LOCAL_OUTLINE_OWNED):
		owned_outline = bool(player.get_meta(META_LOCAL_OUTLINE_OWNED))

	if owned_outline and player.has_method("has_outline") and player.call("has_outline", outline_color):
		player.call("remove_outline", outline_color)

	_clear_local_outline_meta_only(player)


func _get_slot_manager() -> Node:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	var direct = tree.root.get_node_or_null("ModLoader/six666-BrotatoOnline/BrotatoOnlineOnlinePlayerSlotManager")
	if direct != null and is_instance_valid(direct):
		return direct
	return _find_node_named(tree.root, "BrotatoOnlineOnlinePlayerSlotManager", 0)


func _find_node_named(node: Node, target_name: String, depth: int) -> Node:
	if node == null or not is_instance_valid(node) or depth > 6:
		return null
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _find_node_named(child, target_name, depth + 1)
		if found != null:
			return found
	return null
