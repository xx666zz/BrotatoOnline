extends Node

# Public-lobby discovery and UI are kept separate from the gameplay replication
# path. The SteamLobbyManager remains the single owner of lobby join/leave state.

const MOD_ID = "six666-BrotatoOnline"
const MOD_PROTOCOL_VERSION = "1.1.0"
const GAME_VERSION = "1.1.15.4"
const META_PUBLIC_LOBBY_ENABLED = "brotato_online_public_lobby_enabled"
const SETTINGS_FILE_PATH = "user://brotato_online_settings.cfg"
const SETTINGS_SECTION = "network"
const SETTINGS_KEY_PUBLIC_LOBBY = "public_lobby"
const DEFAULT_PUBLIC_LOBBY_ENABLED = false

const MAIN_MENU_BUTTON_NAME = "BrotatoOnlinePublicLobbyBrowserButton"
const PUBLIC_TOGGLE_NAME = "BrotatoOnlinePublicLobbyToggle"
const OVERLAY_NAME = "BrotatoOnlinePublicLobbyBrowserOverlay"

const LOBBY_COMPARISON_EQUAL = 0
const LOBBY_DISTANCE_WORLDWIDE = 3
const LOBBY_LIST_RESULT_LIMIT = 50
const LOBBY_LIST_AUTO_REFRESH_MSEC = 10000
const LOBBY_LIST_REQUEST_TIMEOUT_MSEC = 8000
const PUBLIC_JOIN_VERIFY_TIMEOUT_MSEC = 6000
const HOST_METADATA_REFRESH_MSEC = 1000
const UI_SCAN_INTERVAL_MSEC = 300

# A dedicated SteamNetworkingMessages channel is used for a tiny request/response
# probe. It measures the route that the mod will actually use without joining the
# lobby first. The host only answers while it owns a public lobby.
const P2P_CHANNEL_LOBBY_BROWSER = 2
const STEAM_NETWORKING_SEND_UNRELIABLE = 0
const PING_ATTEMPT_LIMIT = 3
const PING_RETRY_INTERVAL_MSEC = 850
const PING_PENDING_TTL_MSEC = 4000

var _steam = null
var _public_lobby_enabled = DEFAULT_PUBLIC_LOBBY_ENABLED
var _last_ui_scan_msec = 0
var _last_host_metadata_refresh_msec = 0

var _main_menu_button = null
var _main_menu_button_parent = null
var _public_toggle = null
var _public_toggle_parent = null
var _public_toggle_signal_guard = false

var _overlay = null
var _overlay_parent = null
var _title_label = null
var _status_label = null
var _rows_container = null
var _refresh_button = null
var _back_button = null
var _last_focus_owner = null
var _overlay_open = false

var _list_request_pending = false
var _last_list_request_msec = 0
var _lobby_entries = []
var _ping_label_by_lobby_id = {}
var _ping_state_by_lobby_id = {}
var _pending_ping_by_nonce = {}
var _ping_sequence = 0
var _pending_public_join_lobby_id = 0
var _pending_public_join_started_msec = 0

# Lobby metadata writes are cached. Rewriting the same Steam lobby data every
# second emits lobby_data_update callbacks; those callbacks used to rebuild the
# host slot layout and flood clients with selection_state packets.
var _published_lobby_id = 0
var _published_lobby_metadata = {}
var _published_lobby_joinable = null


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_load_public_lobby_preference()
	_publish_public_lobby_preference()
	_setup_steam()
	_connect_steam_signals()
	_connect_ui_language_signal()
	set_process(true)
	set_process_input(true)
	call_deferred("_apply_public_preference_to_lobby_manager")


func _process(_delta: float) -> void:
	var now = OS.get_ticks_msec()
	if now - _last_ui_scan_msec >= UI_SCAN_INTERVAL_MSEC:
		_last_ui_scan_msec = now
		_poll_main_menu_browser_button()
		_poll_character_public_toggle()
		_refresh_localized_texts()
		_update_public_toggle_state()

	_poll_host_lobby_metadata(now)

	if _overlay_open:
		_poll_browser_ping_packets()
		_poll_pending_ping_requests(now)
		_poll_pending_public_join_verification(now)
		if _list_request_pending and now - _last_list_request_msec >= LOBBY_LIST_REQUEST_TIMEOUT_MSEC:
			_list_request_pending = false
			_set_status(_text("request_failed"))
		if not _list_request_pending and now - _last_list_request_msec >= LOBBY_LIST_AUTO_REFRESH_MSEC:
			request_public_lobby_list()


func _input(event: InputEvent) -> void:
	if not _overlay_open:
		return
	if event.is_action_released("ui_cancel"):
		_close_browser_overlay()
		get_tree().set_input_as_handled()


func _setup_steam() -> void:
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")


func _connect_steam_signals() -> void:
	if _steam == null:
		return
	_connect_signal_if_exists("lobby_match_list", "_on_lobby_match_list")
	_connect_signal_if_exists("lobby_data_update", "_on_lobby_data_update")


func _connect_signal_if_exists(signal_name: String, method_name: String) -> void:
	if _steam == null or not _steam.has_signal(signal_name):
		return
	if _steam.is_connected(signal_name, self, method_name):
		return
	var _err = _steam.connect(signal_name, self, method_name)


func _connect_ui_language_signal() -> void:
	if ProgressData == null or not ProgressData.has_signal("language_changed"):
		return
	if not ProgressData.is_connected("language_changed", self, "_on_ui_language_changed"):
		ProgressData.connect("language_changed", self, "_on_ui_language_changed")


func _on_ui_language_changed() -> void:
	_refresh_localized_texts()
	if _overlay_open:
		_rebuild_lobby_rows()


func _get_ui_language_code() -> String:
	var language = ""
	if ProgressData != null and typeof(ProgressData.settings) == TYPE_DICTIONARY:
		language = str(ProgressData.settings.get("language", ""))
	if language == "":
		language = str(TranslationServer.get_locale())
	language = language.to_lower()
	return "zh" if language.begins_with("zh") else "en"


func _text(key: String) -> String:
	var zh = _get_ui_language_code() == "zh"
	match key:
		"browser_button":
			return "公共大厅" if zh else "Public Lobbies"
		"public_toggle":
			return "公开" if zh else "Public"
		"title":
			return "公共大厅" if zh else "Public Lobbies"
		"searching":
			return "正在搜索公共大厅…" if zh else "Searching for public lobbies..."
		"none":
			return "没有找到可加入的公共大厅" if zh else "No joinable public lobbies found"
		"steam_unavailable":
			return "Steam 大厅接口不可用" if zh else "Steam lobby service is unavailable"
		"request_failed":
			return "无法请求大厅列表" if zh else "Could not request the lobby list"
		"refresh":
			return "刷新" if zh else "Refresh"
		"back":
			return "返回" if zh else "Back"
		"host":
			return "房主" if zh else "Host"
		"players":
			return "人数" if zh else "Players"
		"ping":
			return "延迟" if zh else "Latency"
		"state":
			return "状态" if zh else "State"
		"join":
			return "加入" if zh else "Join"
		"joining":
			return "加入中…" if zh else "Joining..."
		"checking_lobby":
			return "正在确认大厅状态…" if zh else "Checking lobby status..."
		"lobby_no_longer_public":
			return "该大厅已关闭公开，请刷新列表。" if zh else "This lobby is no longer public. Refresh the list."
		"lobby_no_longer_joinable":
			return "该大厅当前不可加入。" if zh else "This lobby is no longer joinable."
		"join_verify_failed":
			return "无法确认大厅状态，请刷新后重试。" if zh else "Could not verify the lobby status. Refresh and try again."
		"version_mismatch":
			return "版本不兼容" if zh else "Version mismatch"
		"full":
			return "已满" if zh else "Full"
		"character_selection":
			return "角色选择" if zh else "Character select"
		"coop_resume":
			return "等待重连" if zh else "Waiting for reconnect"
		"weapon_selection":
			return "武器选择中" if zh else "Choosing weapons"
		"difficulty_selection":
			return "难度选择中" if zh else "Choosing difficulty"
		"game":
			return "游戏中" if zh else "In game"
		"shop":
			return "商店中" if zh else "In shop"
		"busy":
			return "不可加入" if zh else "Not joinable"
		"unknown":
			return "未知" if zh else "Unknown"
	return key


func _load_public_lobby_preference() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE_PATH)
	if err == OK:
		_public_lobby_enabled = bool(config.get_value(
			SETTINGS_SECTION,
			SETTINGS_KEY_PUBLIC_LOBBY,
			DEFAULT_PUBLIC_LOBBY_ENABLED
		))
	else:
		_public_lobby_enabled = DEFAULT_PUBLIC_LOBBY_ENABLED


func _save_public_lobby_preference() -> void:
	var config = ConfigFile.new()
	var _load_err = config.load(SETTINGS_FILE_PATH)
	config.set_value(SETTINGS_SECTION, SETTINGS_KEY_PUBLIC_LOBBY, _public_lobby_enabled)
	var _save_err = config.save(SETTINGS_FILE_PATH)


func _publish_public_lobby_preference() -> void:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return
	tree.root.set_meta(META_PUBLIC_LOBBY_ENABLED, _public_lobby_enabled)


func _apply_public_preference_to_lobby_manager() -> void:
	var manager = _get_steam_lobby_manager()
	if manager != null and manager.has_method("set_public_lobby_enabled"):
		manager.call("set_public_lobby_enabled", _public_lobby_enabled)


func _get_steam_lobby_manager() -> Node:
	var parent = get_parent()
	if parent != null:
		var direct = parent.get_node_or_null("BrotatoOnlineSteamLobbyManager")
		if direct != null and is_instance_valid(direct):
			return direct
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	return _find_node_named(tree.root, "BrotatoOnlineSteamLobbyManager", 0)


func _find_node_named(node: Node, target_name: String, depth: int) -> Node:
	if node == null or not is_instance_valid(node) or depth > 7:
		return null
	if str(node.name) == target_name:
		return node
	for child in node.get_children():
		if child is Node:
			var found = _find_node_named(child, target_name, depth + 1)
			if found != null:
				return found
	return null


func _poll_main_menu_browser_button() -> void:
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		_clear_main_menu_button_ref()
		return

	var main_menu = tree.current_scene.get_node_or_null("Menus/MainMenu")
	if main_menu == null or not is_instance_valid(main_menu):
		_clear_main_menu_button_ref()
		return

	var left_buttons = main_menu.get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/ButtonsLeft")
	if left_buttons == null or not is_instance_valid(left_buttons):
		_clear_main_menu_button_ref()
		return

	# SteamLobbyManager creates this button first. The browser button belongs directly
	# below it so the two lobby entry points remain together on the left side.
	var create_lobby_button = left_buttons.get_node_or_null("BrotatoOnlineMainMenuOnlineButton")
	if create_lobby_button == null or not is_instance_valid(create_lobby_button):
		_clear_main_menu_button_ref()
		return

	if _main_menu_button_parent != left_buttons or _main_menu_button == null or not is_instance_valid(_main_menu_button):
		_main_menu_button_parent = left_buttons
		_ensure_main_menu_browser_button(left_buttons, create_lobby_button)

	_reposition_main_menu_browser_button(left_buttons, create_lobby_button)
	_refresh_main_menu_button_focus(left_buttons, create_lobby_button)


func _clear_main_menu_button_ref() -> void:
	_main_menu_button = null
	_main_menu_button_parent = null
	if _overlay_open:
		_close_browser_overlay()


func _ensure_main_menu_browser_button(left_buttons: Node, create_lobby_button: Node) -> void:
	var existing = left_buttons.get_node_or_null(MAIN_MENU_BUTTON_NAME)
	if existing != null and is_instance_valid(existing):
		_main_menu_button = existing
		if not existing.is_connected("pressed", self, "_on_main_menu_browser_button_pressed"):
			existing.connect("pressed", self, "_on_main_menu_browser_button_pressed")
		_configure_runtime_button(existing)
		return

	var button = Button.new()
	button.name = MAIN_MENU_BUTTON_NAME
	button.text = _text("browser_button")
	button.rect_min_size = Vector2(create_lobby_button.rect_min_size.x, 65)
	button.size_flags_horizontal = create_lobby_button.size_flags_horizontal
	button.size_flags_vertical = create_lobby_button.size_flags_vertical
	button.align = create_lobby_button.align
	button.expand_icon = create_lobby_button.expand_icon
	button.clip_text = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.hint_tooltip = ""
	if create_lobby_button.has_font("font"):
		button.add_font_override("font", create_lobby_button.get_font("font"))
	for style_name in ["hover_pressed", "pressed", "hover", "normal", "focus", "disabled"]:
		if create_lobby_button.has_stylebox(style_name):
			button.add_stylebox_override(style_name, create_lobby_button.get_stylebox(style_name))
	for color_name in ["font_color", "font_color_pressed", "font_color_hover", "font_color_disabled"]:
		if create_lobby_button.has_color(color_name):
			button.add_color_override(color_name, create_lobby_button.get_color(color_name))
	left_buttons.add_child(button)
	button.connect("pressed", self, "_on_main_menu_browser_button_pressed")
	_configure_runtime_button(button)
	_main_menu_button = button
	_reposition_main_menu_browser_button(left_buttons, create_lobby_button)
	_refresh_main_menu_button_focus(left_buttons, create_lobby_button)


func _reposition_main_menu_browser_button(left_buttons: Node, create_lobby_button: Node) -> void:
	if _main_menu_button == null or not is_instance_valid(_main_menu_button):
		return
	var target_index = min(left_buttons.get_child_count() - 1, create_lobby_button.get_index() + 1)
	if _main_menu_button.get_index() != target_index:
		left_buttons.move_child(_main_menu_button, target_index)


func _refresh_main_menu_button_focus(left_buttons: Node, create_lobby_button: Node) -> void:
	if _main_menu_button == null or not is_instance_valid(_main_menu_button):
		return
	var profile_button = left_buttons.get_node_or_null("ProfileButton")
	if create_lobby_button is Control:
		create_lobby_button.focus_neighbour_bottom = create_lobby_button.get_path_to(_main_menu_button)
		_main_menu_button.focus_neighbour_top = _main_menu_button.get_path_to(create_lobby_button)
		_main_menu_button.focus_neighbour_left = create_lobby_button.focus_neighbour_left
		_main_menu_button.focus_neighbour_right = create_lobby_button.focus_neighbour_right
	if profile_button != null and profile_button is Control:
		_main_menu_button.focus_neighbour_bottom = _main_menu_button.get_path_to(profile_button)
		profile_button.focus_neighbour_top = profile_button.get_path_to(_main_menu_button)


func _configure_runtime_button(button: Control) -> void:
	if button == null or not is_instance_valid(button):
		return
	if button.has_method("set_message_translation"):
		button.set_message_translation(false)
	if button.has_signal("mouse_entered") and not button.is_connected("mouse_entered", self, "_on_runtime_focusable_mouse_entered"):
		button.connect("mouse_entered", self, "_on_runtime_focusable_mouse_entered", [button])


func _on_runtime_focusable_mouse_entered(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	if control is Button and control.disabled:
		return
	if control.focus_mode == Control.FOCUS_NONE:
		control.focus_mode = Control.FOCUS_ALL
	control.grab_focus()


func _on_main_menu_browser_button_pressed() -> void:
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return
	_ensure_browser_overlay(tree.current_scene)
	_open_browser_overlay()


func _poll_character_public_toggle() -> void:
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		_clear_public_toggle_ref()
		return
	var current = tree.current_scene
	var filename = str(current.filename).to_lower()
	var node_name = str(current.name).to_lower()
	if filename.find("character_selection") == -1 and node_name.find("characterselection") == -1:
		_clear_public_toggle_ref()
		return

	var panel = current.get_node_or_null("MarginContainer/VBoxContainer/DescriptionContainer/RunOptionsPanel")
	if panel == null or not is_instance_valid(panel):
		_clear_public_toggle_ref()
		return

	var lobby_toggle = _find_node_named(panel, "BrotatoOnlineSteamLobbyButton", 0)
	if lobby_toggle == null or not is_instance_valid(lobby_toggle):
		_clear_public_toggle_ref()
		return
	var parent = lobby_toggle.get_parent()
	if parent == null:
		_clear_public_toggle_ref()
		return
	_compact_custom_lobby_option_rows(parent, lobby_toggle)

	if _public_toggle_parent != parent or _public_toggle == null or not is_instance_valid(_public_toggle):
		_public_toggle_parent = parent
		_ensure_character_public_toggle(parent, lobby_toggle)
	_reposition_character_public_toggle(parent, lobby_toggle)


func _clear_public_toggle_ref() -> void:
	_public_toggle = null
	_public_toggle_parent = null


func _compact_custom_lobby_option_rows(parent: Node, lobby_toggle: Control) -> void:
	# The two mod rows share the space left below the three vanilla toggles.
	# Keeping only these rows compact avoids moving the character grid downward.
	if parent.has_method("add_constant_override"):
		parent.add_constant_override("separation", 6)
	var min_size = lobby_toggle.rect_min_size
	min_size.y = 48
	lobby_toggle.rect_min_size = min_size
	var compact_font = load("res://resources/fonts/actual/base/font_22.tres")
	if compact_font != null:
		lobby_toggle.add_font_override("font", compact_font)


func _ensure_character_public_toggle(parent: Node, lobby_toggle: Node) -> void:
	var existing = parent.get_node_or_null(PUBLIC_TOGGLE_NAME)
	if existing != null and is_instance_valid(existing):
		_public_toggle = existing
		if not existing.is_connected("toggled", self, "_on_public_toggle_toggled"):
			existing.connect("toggled", self, "_on_public_toggle_toggled")
		_configure_runtime_button(existing)
		return

	var toggle = CheckButton.new()
	toggle.name = PUBLIC_TOGGLE_NAME
	toggle.text = _text("public_toggle")
	toggle.clip_text = true
	toggle.focus_mode = Control.FOCUS_ALL
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle.hint_tooltip = ""
	# This compact fifth row fits the vanilla 500px run-options panel without
	# pushing the character grid down or overlapping the panel border.
	toggle.rect_min_size = Vector2(260, 48)
	if lobby_toggle is Control:
		toggle.size_flags_horizontal = lobby_toggle.size_flags_horizontal
		toggle.size_flags_vertical = lobby_toggle.size_flags_vertical
		_copy_check_button_visuals(lobby_toggle, toggle)
	var compact_font = load("res://resources/fonts/actual/base/font_22.tres")
	if compact_font != null:
		toggle.add_font_override("font", compact_font)
	parent.add_child(toggle)
	parent.move_child(toggle, min(parent.get_child_count() - 1, lobby_toggle.get_index() + 1))
	toggle.connect("toggled", self, "_on_public_toggle_toggled")
	_configure_runtime_button(toggle)
	_public_toggle = toggle
	_update_public_toggle_state()


func _copy_check_button_visuals(source: Control, target: Control) -> void:
	if source.has_font("font"):
		target.add_font_override("font", source.get_font("font"))
	for style_name in ["hover_pressed", "pressed", "hover", "normal", "focus", "disabled"]:
		if source.has_stylebox(style_name):
			target.add_stylebox_override(style_name, source.get_stylebox(style_name))
	for color_name in ["font_color", "font_color_pressed", "font_color_hover", "font_color_disabled"]:
		if source.has_color(color_name):
			target.add_color_override(color_name, source.get_color(color_name))


func _reposition_character_public_toggle(parent: Node, lobby_toggle: Node) -> void:
	if _public_toggle == null or not is_instance_valid(_public_toggle):
		return
	var target_index = min(parent.get_child_count() - 1, lobby_toggle.get_index() + 1)
	if _public_toggle.get_index() != target_index:
		parent.move_child(_public_toggle, target_index)
	if lobby_toggle is Control and _public_toggle is Control:
		lobby_toggle.focus_neighbour_bottom = lobby_toggle.get_path_to(_public_toggle)
		_public_toggle.focus_neighbour_top = _public_toggle.get_path_to(lobby_toggle)


func _update_public_toggle_state() -> void:
	if _public_toggle == null or not is_instance_valid(_public_toggle):
		return
	var manager = _get_steam_lobby_manager()
	var active = false
	var host = true
	if manager != null:
		if manager.has_method("has_active_online_session"):
			active = bool(manager.call("has_active_online_session"))
		if active and manager.has_method("is_host"):
			host = bool(manager.call("is_host"))
	_public_toggle_signal_guard = true
	_public_toggle.set_pressed_no_signal(_public_lobby_enabled)
	_public_toggle.disabled = active and not host
	_public_toggle.text = _text("public_toggle")
	_public_toggle_signal_guard = false


func _on_public_toggle_toggled(button_pressed: bool) -> void:
	if _public_toggle_signal_guard:
		return
	_public_lobby_enabled = button_pressed
	_reset_host_metadata_cache()
	_save_public_lobby_preference()
	_publish_public_lobby_preference()
	_apply_public_preference_to_lobby_manager()
	_update_public_toggle_state()


func _ensure_browser_overlay(title_screen: Node) -> void:
	if title_screen == null or not is_instance_valid(title_screen):
		return
	var existing = title_screen.get_node_or_null(OVERLAY_NAME)
	if existing != null and is_instance_valid(existing):
		_overlay = existing
		_overlay_parent = title_screen
		_title_label = existing.get_node_or_null("Center/Panel/Margin/VBox/Title")
		_status_label = existing.get_node_or_null("Center/Panel/Margin/VBox/Status")
		_rows_container = existing.get_node_or_null("Center/Panel/Margin/VBox/Scroll/Rows")
		_refresh_button = existing.get_node_or_null("Center/Panel/Margin/VBox/Bottom/Refresh")
		_back_button = existing.get_node_or_null("Center/Panel/Margin/VBox/Bottom/Back")
		return

	var overlay = Control.new()
	overlay.name = OVERLAY_NAME
	overlay.pause_mode = Node.PAUSE_MODE_PROCESS
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	var base_theme = load("res://resources/themes/base_theme.tres")
	if base_theme != null:
		overlay.theme = base_theme
	title_screen.add_child(overlay)

	var dim = ColorRect.new()
	dim.name = "Dim"
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0, 0, 0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var center = CenterContainer.new()
	center.name = "Center"
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.rect_min_size = Vector2(1220, 760)
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.name = "Margin"
	margin.add_constant_override("margin_left", 34)
	margin.add_constant_override("margin_right", 34)
	margin.add_constant_override("margin_top", 28)
	margin.add_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_constant_override("separation", 14)
	margin.add_child(vbox)

	var title = Label.new()
	title.name = "Title"
	title.text = _text("title")
	title.align = Label.ALIGN_CENTER
	var title_font = load("res://resources/fonts/actual/base/font_40_outline.tres")
	if title_font != null:
		title.add_font_override("font", title_font)
	vbox.add_child(title)
	_title_label = title

	var status = Label.new()
	status.name = "Status"
	status.text = _text("searching")
	status.align = Label.ALIGN_CENTER
	status.rect_min_size = Vector2(0, 34)
	vbox.add_child(status)
	_status_label = status

	var header = HBoxContainer.new()
	header.name = "Header"
	header.add_constant_override("separation", 12)
	vbox.add_child(header)
	_add_header_label(header, _text("host"), 410)
	_add_header_label(header, _text("players"), 115)
	_add_header_label(header, _text("ping"), 130)
	_add_header_label(header, _text("state"), 260)
	var header_spacer = Control.new()
	header_spacer.rect_min_size = Vector2(150, 0)
	header.add_child(header_spacer)

	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.rect_min_size = Vector2(0, 470)
	vbox.add_child(scroll)

	var rows = VBoxContainer.new()
	rows.name = "Rows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_constant_override("separation", 8)
	scroll.add_child(rows)
	_rows_container = rows

	var bottom = HBoxContainer.new()
	bottom.name = "Bottom"
	bottom.add_constant_override("separation", 14)
	vbox.add_child(bottom)

	var refresh = Button.new()
	refresh.name = "Refresh"
	refresh.text = _text("refresh")
	refresh.rect_min_size = Vector2(250, 65)
	refresh.focus_mode = Control.FOCUS_ALL
	refresh.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom.add_child(refresh)
	refresh.connect("pressed", self, "request_public_lobby_list")
	_configure_runtime_button(refresh)
	_refresh_button = refresh

	var bottom_spacer = Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(bottom_spacer)

	var back = Button.new()
	back.name = "Back"
	back.text = _text("back")
	back.rect_min_size = Vector2(250, 65)
	back.focus_mode = Control.FOCUS_ALL
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom.add_child(back)
	back.connect("pressed", self, "_close_browser_overlay")
	_configure_runtime_button(back)
	_back_button = back

	_refresh_button.focus_neighbour_left = _refresh_button.get_path_to(_back_button)
	_refresh_button.focus_neighbour_right = _refresh_button.get_path_to(_back_button)
	_back_button.focus_neighbour_left = _back_button.get_path_to(_refresh_button)
	_back_button.focus_neighbour_right = _back_button.get_path_to(_refresh_button)

	_overlay = overlay
	_overlay_parent = title_screen


func _add_header_label(parent: HBoxContainer, text: String, width: float) -> void:
	var label = Label.new()
	label.text = text
	label.rect_min_size = Vector2(width, 36)
	label.align = Label.ALIGN_LEFT
	var font = load("res://resources/fonts/actual/base/font_22.tres")
	if font != null:
		label.add_font_override("font", font)
	parent.add_child(label)


func _open_browser_overlay() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	var viewport = get_viewport()
	if viewport != null and viewport.has_method("gui_get_focus_owner"):
		var owner = viewport.call("gui_get_focus_owner")
		if owner != null and owner is Control:
			_last_focus_owner = owner
		else:
			_last_focus_owner = _main_menu_button
	_overlay.show()
	_overlay_open = true
	if _overlay.get_parent() != null:
		_overlay.get_parent().move_child(_overlay, _overlay.get_parent().get_child_count() - 1)
	_clear_lobby_results()
	_set_status(_text("searching"))
	call_deferred("_focus_browser_refresh")
	request_public_lobby_list()


func _focus_browser_refresh() -> void:
	if _overlay_open and _refresh_button != null and is_instance_valid(_refresh_button):
		_refresh_button.grab_focus()


func _close_browser_overlay() -> void:
	_overlay_open = false
	_list_request_pending = false
	_pending_public_join_lobby_id = 0
	_pending_public_join_started_msec = 0
	_clear_ping_state()
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.hide()
	if _last_focus_owner != null and is_instance_valid(_last_focus_owner):
		_last_focus_owner.grab_focus()
	elif _main_menu_button != null and is_instance_valid(_main_menu_button):
		_main_menu_button.grab_focus()


func request_public_lobby_list() -> void:
	if not _overlay_open or _list_request_pending:
		return
	if _steam == null or not _steam.has_method("requestLobbyList"):
		_list_request_pending = false
		_set_status(_text("steam_unavailable"))
		return

	_clear_lobby_results()
	_set_status(_text("searching"))
	_list_request_pending = true
	_last_list_request_msec = OS.get_ticks_msec()

	if _steam.has_method("addRequestLobbyListStringFilter"):
		_steam.addRequestLobbyListStringFilter("mod", MOD_ID, LOBBY_COMPARISON_EQUAL)
		_steam.addRequestLobbyListStringFilter("visibility", "public", LOBBY_COMPARISON_EQUAL)
	if _steam.has_method("addRequestLobbyListFilterSlotsAvailable"):
		_steam.addRequestLobbyListFilterSlotsAvailable(1)
	if _steam.has_method("addRequestLobbyListDistanceFilter"):
		_steam.addRequestLobbyListDistanceFilter(LOBBY_DISTANCE_WORLDWIDE)
	if _steam.has_method("addRequestLobbyListResultCountFilter"):
		_steam.addRequestLobbyListResultCountFilter(LOBBY_LIST_RESULT_LIMIT)
	var result = _steam.requestLobbyList()
	if typeof(result) == TYPE_BOOL and not bool(result):
		_list_request_pending = false
		_set_status(_text("request_failed"))


func _on_lobby_match_list(payload = null) -> void:
	if not _overlay_open:
		return
	_list_request_pending = false
	var lobby_ids = _normalize_lobby_match_list_payload(payload)
	_build_lobby_entries(lobby_ids)
	_rebuild_lobby_rows()
	_start_ping_measurements()


func _normalize_lobby_match_list_payload(payload) -> Array:
	if typeof(payload) == TYPE_ARRAY:
		return payload
	if typeof(payload) == TYPE_DICTIONARY:
		for key in ["lobbies", "lobby_ids", "results", "data"]:
			if payload.has(key) and typeof(payload[key]) == TYPE_ARRAY:
				return payload[key]
	if typeof(payload) == TYPE_INT and _steam != null and _steam.has_method("getLobbyByIndex"):
		var result = []
		for i in range(max(0, int(payload))):
			result.append(_steam.getLobbyByIndex(i))
		return result
	return []


func _build_lobby_entries(lobby_ids: Array) -> void:
	_lobby_entries.clear()
	var seen = {}
	for value in lobby_ids:
		var lobby_id = int(str(value))
		if lobby_id == 0 or seen.has(str(lobby_id)):
			continue
		seen[str(lobby_id)] = true
		var entry = _read_lobby_entry(lobby_id)
		if entry.empty():
			continue
		_lobby_entries.append(entry)


func _read_lobby_entry(lobby_id: int) -> Dictionary:
	if _steam == null or not _steam.has_method("getLobbyData"):
		return {}
	var mod_id = str(_steam.getLobbyData(lobby_id, "mod"))
	var visibility = str(_steam.getLobbyData(lobby_id, "visibility"))
	if mod_id != MOD_ID or visibility != "public":
		return {}
	var mod_version = str(_steam.getLobbyData(lobby_id, "mod_version"))
	var game_version = str(_steam.getLobbyData(lobby_id, "game_version"))
	var state = str(_steam.getLobbyData(lobby_id, "state"))
	if state == "":
		state = "unknown"
	var host_id = str(_steam.getLobbyData(lobby_id, "host"))
	var host_name = str(_steam.getLobbyData(lobby_id, "host_name"))
	if host_name == "" and host_id != "" and host_id != "0" and _steam.has_method("getFriendPersonaName"):
		host_name = str(_steam.getFriendPersonaName(int(host_id)))
	if host_name == "":
		host_name = host_id if host_id != "" else str(lobby_id)

	var member_count = int(str(_steam.getLobbyData(lobby_id, "member_count")))
	if _steam.has_method("getNumLobbyMembers"):
		var live_count = int(_steam.getNumLobbyMembers(lobby_id))
		if live_count > 0:
			member_count = live_count
	var member_limit = int(str(_steam.getLobbyData(lobby_id, "member_limit")))
	if _steam.has_method("getLobbyMemberLimit"):
		var live_limit = int(_steam.getLobbyMemberLimit(lobby_id))
		if live_limit > 0:
			member_limit = live_limit
	if member_limit <= 0:
		member_limit = 4
	if member_count <= 0:
		member_count = 1

	var compatible = mod_version == MOD_PROTOCOL_VERSION and game_version == GAME_VERSION
	var joinable_state = state == "character_selection" or state == "coop_resume"
	var full = member_count >= member_limit
	return {
		"lobby_id": lobby_id,
		"host_id": host_id,
		"host_name": host_name,
		"member_count": member_count,
		"member_limit": member_limit,
		"state": state,
		"compatible": compatible,
		"joinable": compatible and joinable_state and not full and host_id != "" and host_id != "0",
		"full": full,
		"ping_ms": -1
	}


func _rebuild_lobby_rows() -> void:
	if _rows_container == null or not is_instance_valid(_rows_container):
		return
	for child in _rows_container.get_children():
		_rows_container.remove_child(child)
		child.queue_free()
	_ping_label_by_lobby_id.clear()

	if _lobby_entries.empty():
		_set_status(_text("none"))
		var empty_label = Label.new()
		empty_label.text = _text("none")
		empty_label.align = Label.ALIGN_CENTER
		empty_label.rect_min_size = Vector2(0, 90)
		_rows_container.add_child(empty_label)
		return

	_set_status(str(_lobby_entries.size()) + (" 个大厅" if _get_ui_language_code() == "zh" else " lobbies"))
	for entry in _lobby_entries:
		_add_lobby_row(entry)


func _add_lobby_row(entry: Dictionary) -> void:
	var panel = PanelContainer.new()
	panel.rect_min_size = Vector2(0, 66)
	_rows_container.add_child(panel)

	var row = HBoxContainer.new()
	row.add_constant_override("separation", 12)
	panel.add_child(row)

	var host = Label.new()
	host.text = str(entry.get("host_name", ""))
	host.rect_min_size = Vector2(410, 60)
	host.valign = Label.VALIGN_CENTER
	host.clip_text = true
	row.add_child(host)

	var players = Label.new()
	players.text = str(entry.get("member_count", 0)) + "/" + str(entry.get("member_limit", 4))
	players.rect_min_size = Vector2(115, 60)
	players.valign = Label.VALIGN_CENTER
	row.add_child(players)

	var ping = Label.new()
	ping.text = _format_ping(int(entry.get("ping_ms", -1)))
	ping.rect_min_size = Vector2(130, 60)
	ping.valign = Label.VALIGN_CENTER
	row.add_child(ping)
	_ping_label_by_lobby_id[str(entry.get("lobby_id", 0))] = ping

	var state = Label.new()
	state.text = _format_lobby_state(entry)
	state.rect_min_size = Vector2(260, 60)
	state.valign = Label.VALIGN_CENTER
	state.clip_text = true
	row.add_child(state)

	var join = Button.new()
	join.text = _text("join")
	join.rect_min_size = Vector2(150, 60)
	join.focus_mode = Control.FOCUS_ALL
	join.mouse_filter = Control.MOUSE_FILTER_STOP
	join.disabled = not bool(entry.get("joinable", false))
	join.connect("pressed", self, "_on_join_lobby_pressed", [int(entry.get("lobby_id", 0))])
	_configure_runtime_button(join)
	row.add_child(join)


func _format_lobby_state(entry: Dictionary) -> String:
	if not bool(entry.get("compatible", false)):
		return _text("version_mismatch")
	if bool(entry.get("full", false)):
		return _text("full")
	var state = str(entry.get("state", "unknown"))
	if state == "character_selection" or state == "coop_resume" or state == "weapon_selection" or state == "difficulty_selection" or state == "game" or state == "shop" or state == "busy":
		return _text(state)
	return _text("unknown")


func _format_ping(ping_ms: int) -> String:
	if ping_ms < 0:
		return "--"
	return str(ping_ms) + " ms"


func _set_status(text: String) -> void:
	if _status_label != null and is_instance_valid(_status_label):
		_status_label.text = text


func _clear_lobby_results() -> void:
	_lobby_entries.clear()
	_clear_ping_state()
	if _rows_container != null and is_instance_valid(_rows_container):
		for child in _rows_container.get_children():
			_rows_container.remove_child(child)
			child.queue_free()


func _on_join_lobby_pressed(lobby_id: int) -> void:
	if lobby_id == 0 or _pending_public_join_lobby_id != 0:
		return
	if _steam == null or not _steam.has_method("requestLobbyData"):
		_set_status(_text("steam_unavailable"))
		return

	# Lobby-list data is cached. Re-request the selected lobby immediately before
	# joining so a row that was public a few seconds ago cannot bypass a host that
	# has just disabled Public.
	_pending_public_join_lobby_id = lobby_id
	_pending_public_join_started_msec = OS.get_ticks_msec()
	_set_status(_text("checking_lobby"))
	var request_result = _steam.requestLobbyData(lobby_id)
	if typeof(request_result) == TYPE_BOOL and not bool(request_result):
		_pending_public_join_lobby_id = 0
		_pending_public_join_started_msec = 0
		_set_status(_text("join_verify_failed"))


func _on_lobby_data_update(success = false, lobby_id = 0, member_id = 0) -> void:
	if _pending_public_join_lobby_id == 0 or str(lobby_id) != str(_pending_public_join_lobby_id):
		return
	var target_lobby_id = _pending_public_join_lobby_id
	_pending_public_join_lobby_id = 0
	_pending_public_join_started_msec = 0
	if not bool(success):
		_set_status(_text("join_verify_failed"))
		return

	var visibility = ""
	if _steam != null and _steam.has_method("getLobbyData"):
		visibility = str(_steam.getLobbyData(target_lobby_id, "visibility"))
	if visibility != "public":
		_remove_lobby_entry(target_lobby_id)
		_rebuild_lobby_rows()
		_set_status(_text("lobby_no_longer_public"))
		return

	var entry = _read_lobby_entry(target_lobby_id)
	if entry.empty() or not bool(entry.get("joinable", false)):
		_remove_lobby_entry(target_lobby_id)
		_rebuild_lobby_rows()
		_set_status(_text("lobby_no_longer_joinable"))
		return

	var manager = _get_steam_lobby_manager()
	if manager == null or not manager.has_method("join_lobby"):
		_set_status(_text("steam_unavailable"))
		return
	_set_status(_text("joining"))
	_close_browser_overlay()
	manager.call("join_lobby", target_lobby_id)


func _poll_pending_public_join_verification(now: int) -> void:
	if _pending_public_join_lobby_id == 0:
		return
	if now - _pending_public_join_started_msec < PUBLIC_JOIN_VERIFY_TIMEOUT_MSEC:
		return
	_pending_public_join_lobby_id = 0
	_pending_public_join_started_msec = 0
	_set_status(_text("join_verify_failed"))


func _remove_lobby_entry(lobby_id: int) -> void:
	for i in range(_lobby_entries.size() - 1, -1, -1):
		if str(_lobby_entries[i].get("lobby_id", 0)) == str(lobby_id):
			_lobby_entries.remove(i)


func _start_ping_measurements() -> void:
	# Keep the row-label map built by _rebuild_lobby_rows(). Only reset the
	# request state for a fresh measurement round.
	_ping_state_by_lobby_id.clear()
	_pending_ping_by_nonce.clear()
	var now = OS.get_ticks_msec()
	for entry in _lobby_entries:
		var lobby_id = str(entry.get("lobby_id", 0))
		var host_id = str(entry.get("host_id", ""))
		if lobby_id == "0" or host_id == "" or host_id == "0":
			continue
		_ping_state_by_lobby_id[lobby_id] = {
			"host_id": host_id,
			"attempts": 0,
			"next_send_msec": now,
			"best_ping_ms": -1
		}


func _poll_pending_ping_requests(now: int) -> void:
	if _steam == null or not _steam.has_method("sendMessageToUser"):
		return
	var expired_nonces = []
	for nonce in _pending_ping_by_nonce.keys():
		var pending = _pending_ping_by_nonce[nonce]
		if now - int(pending.get("sent_msec", now)) > PING_PENDING_TTL_MSEC:
			expired_nonces.append(nonce)
	for nonce in expired_nonces:
		_pending_ping_by_nonce.erase(nonce)

	for lobby_key in _ping_state_by_lobby_id.keys():
		var state = _ping_state_by_lobby_id[lobby_key]
		if int(state.get("attempts", 0)) >= PING_ATTEMPT_LIMIT:
			continue
		if now < int(state.get("next_send_msec", now)):
			continue
		_send_lobby_ping(int(lobby_key), state)


func _send_lobby_ping(lobby_id: int, state: Dictionary) -> void:
	var host_id = str(state.get("host_id", ""))
	if host_id == "" or host_id == "0":
		state["attempts"] = PING_ATTEMPT_LIMIT
		return
	_ping_sequence += 1
	var now = OS.get_ticks_msec()
	var nonce = str(lobby_id) + ":" + str(_ping_sequence) + ":" + str(OS.get_ticks_usec())
	var message = {
		"msg_type": "lobby_ping_request",
		"lobby_id": str(lobby_id),
		"nonce": nonce
	}
	var payload = to_json(message).to_utf8()
	if _steam.has_method("acceptSessionWithUser"):
		_steam.acceptSessionWithUser(int(host_id))
	var _result = _steam.sendMessageToUser(int(host_id), payload, STEAM_NETWORKING_SEND_UNRELIABLE, P2P_CHANNEL_LOBBY_BROWSER)
	_pending_ping_by_nonce[nonce] = {
		"lobby_id": str(lobby_id),
		"host_id": host_id,
		"sent_msec": now
	}
	state["attempts"] = int(state.get("attempts", 0)) + 1
	state["next_send_msec"] = now + PING_RETRY_INTERVAL_MSEC
	_ping_state_by_lobby_id[str(lobby_id)] = state


func _poll_browser_ping_packets() -> void:
	if _steam == null or not _steam.has_method("receiveMessagesOnChannel"):
		return
	var packets = _normalize_received_messages(_steam.receiveMessagesOnChannel(P2P_CHANNEL_LOBBY_BROWSER, 64))
	for packet in packets:
		_handle_browser_ping_packet(packet)


func _normalize_received_messages(result) -> Array:
	if typeof(result) == TYPE_ARRAY:
		return result
	if typeof(result) == TYPE_DICTIONARY:
		if result.has("messages") and typeof(result["messages"]) == TYPE_ARRAY:
			return result["messages"]
		if result.has("data") and typeof(result["data"]) == TYPE_ARRAY:
			return result["data"]
		if result.has("message") or result.has("payload") or result.has("bytes"):
			return [result]
	return []


func _handle_browser_ping_packet(packet) -> void:
	if typeof(packet) != TYPE_DICTIONARY:
		return
	var sender = _extract_packet_sender(packet)
	var bytes = _extract_packet_bytes(packet)
	if sender == "" or bytes.size() == 0:
		return
	var parsed = parse_json(bytes.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or str(parsed.get("msg_type", "")) != "lobby_ping_response":
		return
	var nonce = str(parsed.get("nonce", ""))
	if nonce == "" or not _pending_ping_by_nonce.has(nonce):
		return
	var pending = _pending_ping_by_nonce[nonce]
	if sender != str(pending.get("host_id", "")):
		return
	var lobby_key = str(pending.get("lobby_id", "0"))
	if lobby_key != str(parsed.get("lobby_id", "0")):
		return
	var ping_ms = max(0, OS.get_ticks_msec() - int(pending.get("sent_msec", OS.get_ticks_msec())))
	_pending_ping_by_nonce.erase(nonce)
	if not _ping_state_by_lobby_id.has(lobby_key):
		return
	var state = _ping_state_by_lobby_id[lobby_key]
	var best = int(state.get("best_ping_ms", -1))
	if best < 0 or ping_ms < best:
		best = ping_ms
	state["best_ping_ms"] = best
	_ping_state_by_lobby_id[lobby_key] = state
	_update_entry_ping(lobby_key, best)


func _extract_packet_sender(packet: Dictionary) -> String:
	for key in ["remote_steam_id", "steam_id_remote", "steamIDRemote", "steam_id", "sender", "remote_id", "remote"]:
		if packet.has(key):
			return _extract_steam_id_value(packet[key])
	for key in ["identity", "identity_remote", "remote_identity", "networking_identity"]:
		if packet.has(key):
			var steam_id = _extract_steam_id_value(packet[key])
			if steam_id != "":
				return steam_id
	return ""


func _extract_steam_id_value(value) -> String:
	if typeof(value) == TYPE_NIL:
		return ""
	if typeof(value) == TYPE_DICTIONARY:
		for key in ["steam_id", "steamID", "steamID64", "id", "remote_steam_id"]:
			if value.has(key):
				return str(value[key])
		return ""
	return str(value)


func _extract_packet_bytes(packet: Dictionary) -> PoolByteArray:
	for key in ["payload", "data", "message", "bytes", "body"]:
		if not packet.has(key):
			continue
		var value = packet[key]
		if typeof(value) == TYPE_RAW_ARRAY:
			return value
		if typeof(value) == TYPE_STRING:
			return str(value).to_utf8()
	return PoolByteArray()


func _update_entry_ping(lobby_key: String, ping_ms: int) -> void:
	for entry in _lobby_entries:
		if str(entry.get("lobby_id", 0)) == lobby_key:
			entry["ping_ms"] = ping_ms
			break
	if _ping_label_by_lobby_id.has(lobby_key):
		var label = _ping_label_by_lobby_id[lobby_key]
		if label != null and is_instance_valid(label):
			label.text = _format_ping(ping_ms)


func _clear_ping_state() -> void:
	_ping_label_by_lobby_id.clear()
	_ping_state_by_lobby_id.clear()
	_pending_ping_by_nonce.clear()


func _reset_host_metadata_cache() -> void:
	_published_lobby_id = 0
	_published_lobby_metadata.clear()
	_published_lobby_joinable = null


func _set_lobby_data_if_changed(lobby_id: int, key: String, value: String) -> void:
	if _published_lobby_metadata.has(key) and str(_published_lobby_metadata.get(key, "")) == value:
		return
	# _setup_lobby_data() already publishes the initial values. Seed the cache from
	# Steam instead of writing the same value again on the browser's first poll.
	if not _published_lobby_metadata.has(key) and _steam.has_method("getLobbyData"):
		if str(_steam.getLobbyData(lobby_id, key)) == value:
			_published_lobby_metadata[key] = value
			return
	_steam.setLobbyData(lobby_id, key, value)
	_published_lobby_metadata[key] = value


func _poll_host_lobby_metadata(now: int) -> void:
	if now - _last_host_metadata_refresh_msec < HOST_METADATA_REFRESH_MSEC:
		return
	_last_host_metadata_refresh_msec = now
	if _steam == null:
		return

	# Private/friends-only sessions keep the original code path. Public discovery
	# must be dormant outside an explicitly public host lobby.
	if not _public_lobby_enabled:
		_reset_host_metadata_cache()
		return

	var manager = _get_steam_lobby_manager()
	if manager == null or not manager.has_method("get_lobby_id") or not manager.has_method("is_host"):
		_reset_host_metadata_cache()
		return
	var lobby_id = int(manager.call("get_lobby_id"))
	if lobby_id == 0 or not bool(manager.call("is_host")):
		_reset_host_metadata_cache()
		return
	if not _steam.has_method("setLobbyData"):
		return

	if _published_lobby_id != lobby_id:
		_reset_host_metadata_cache()
		_published_lobby_id = lobby_id

	var state = _detect_host_lobby_state()
	var member_count = 1
	if _steam.has_method("getNumLobbyMembers"):
		member_count = max(1, int(_steam.getNumLobbyMembers(lobby_id)))

	_set_lobby_data_if_changed(lobby_id, "state", state)
	_set_lobby_data_if_changed(lobby_id, "member_count", str(member_count))
	_set_lobby_data_if_changed(lobby_id, "member_limit", "4")
	_set_lobby_data_if_changed(lobby_id, "visibility", "public")
	if _steam.has_method("getPersonaName"):
		var persona_name = str(_steam.getPersonaName()).strip_edges()
		if persona_name.length() > 64:
			persona_name = persona_name.substr(0, 64)
		_set_lobby_data_if_changed(lobby_id, "host_name", persona_name)

	if _steam.has_method("setLobbyJoinable"):
		var joinable = state == "character_selection" or state == "coop_resume"
		if _published_lobby_joinable == null or bool(_published_lobby_joinable) != joinable:
			_steam.setLobbyJoinable(lobby_id, joinable)
			_published_lobby_joinable = joinable


func _detect_host_lobby_state() -> String:
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return "busy"
	var current = tree.current_scene
	var filename = str(current.filename).to_lower()
	var node_name = str(current.name).to_lower()
	if filename.find("character_selection") != -1 or node_name.find("characterselection") != -1:
		return "character_selection"
	if filename.find("coop_resume") != -1 or node_name.find("coopresume") != -1 or node_name.find("coop_resume") != -1:
		return "coop_resume"
	if filename.find("weapon_selection") != -1 or node_name.find("weaponselection") != -1:
		return "weapon_selection"
	if filename.find("difficulty_selection") != -1 or node_name.find("difficultyselection") != -1:
		return "difficulty_selection"
	if filename.find("/shop") != -1 or filename.find("shop/") != -1 or node_name.find("shop") != -1:
		return "shop"
	if filename.find("main.tscn") != -1 or node_name == "main" or node_name.find("battle") != -1:
		return "game"
	return "busy"


func _refresh_localized_texts() -> void:
	if _main_menu_button != null and is_instance_valid(_main_menu_button):
		_main_menu_button.text = _text("browser_button")
	if _public_toggle != null and is_instance_valid(_public_toggle):
		_public_toggle.text = _text("public_toggle")
	if _title_label != null and is_instance_valid(_title_label):
		_title_label.text = _text("title")
	if _refresh_button != null and is_instance_valid(_refresh_button):
		_refresh_button.text = _text("refresh")
	if _back_button != null and is_instance_valid(_back_button):
		_back_button.text = _text("back")
