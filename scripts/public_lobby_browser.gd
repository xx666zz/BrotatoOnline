extends Node

# Steam and LAN discovery share one list; SessionManager remains the only owner
# of join/leave and gameplay state.

const MOD_ID = "six666-BrotatoOnline"
# Steam/LAN compatibility is negotiated independently from the package version.
const NETWORK_PROTOCOL_VERSION = "4.0.0"
const DEFAULT_LAN_PORT = 27462
const GAME_VERSION = "1.1.15.4"
const META_PUBLIC_LOBBY_ENABLED = "brotato_online_public_lobby_enabled"
const SETTINGS_FILE_PATH = "user://brotato_online_settings.cfg"
const SETTINGS_SECTION = "network"
const SETTINGS_KEY_PUBLIC_LOBBY = "public_lobby"
const DEFAULT_PUBLIC_LOBBY_ENABLED = false
const ROOM_NAME_MAX_LENGTH = 32
const ROOM_NAME_COLUMN_WIDTH = 420.0
const ROOM_NAME_ROW_HEIGHT = 60.0
const ROOM_NAME_SCROLL_MIN_SPEED = 90.0
const ROOM_NAME_SCROLL_EDGE_PAUSE = 0.35
# LAN discovery can rebuild the rows repeatedly during the first 2.5 s of each
# 10 s browser refresh. Finish a full start -> end -> start marquee cycle in at
# most 6 s so even the last LAN-triggered rebuild still completes in time.
const ROOM_NAME_SCROLL_CYCLE_TARGET_SEC = 6.0
const ROOM_NAME_SCROLL_OVERFLOW_EPSILON = 1.0

const MAIN_MENU_BUTTON_NAME = "BrotatoOnlinePublicLobbyBrowserButton"
const PUBLIC_TOGGLE_NAME = "BrotatoOnlinePublicLobbyToggle"
const OVERLAY_NAME = "BrotatoOnlinePublicLobbyBrowserOverlay"

const LOBBY_COMPARISON_EQUAL = 0
const LOBBY_DISTANCE_WORLDWIDE = 3
const LOBBY_LIST_RESULT_LIMIT = 50
const LOBBY_LIST_AUTO_REFRESH_MSEC = 10000
const LOBBY_LIST_REQUEST_TIMEOUT_MSEC = 8000
const PUBLIC_JOIN_VERIFY_TIMEOUT_MSEC = 6000
const UI_SCAN_INTERVAL_MSEC = 300
const HOST_MODS_FORMAT_VERSION = "1"
const HOST_MODS_LOBBY_MAX_PARTS = 24

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
var _entry_by_key = {}
var _lan_discovery = null
var _ping_label_by_lobby_id = {}
var _ping_state_by_lobby_id = {}
var _pending_ping_by_nonce = {}
var _ping_sequence = 0
var _pending_public_join_lobby_id = 0
var _pending_public_join_started_msec = 0
var _direct_connect_button = null
var _direct_panel = null
var _direct_address_edit = null
var _direct_port_edit = null
var _mods_panel = null
var _mods_title_label = null
var _mods_body_edit = null
var _mods_close_button = null
var _mods_return_focus = null
var _room_name_marquee_by_clip = {}
# Stable marquee state keyed by lobby entry. Row rebuilds (Steam/LAN results,
# localization, etc.) may replace the Control nodes, but should not rewind text.
var _room_name_marquee_state_by_entry_key = {}

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
	call_deferred("_bind_lan_discovery")


func _bind_lan_discovery() -> void:
	var parent = get_parent()
	if parent == null:
		return
	_lan_discovery = parent.get_node_or_null("BrotatoOnlineLanDiscovery")
	if _lan_discovery != null and _lan_discovery.has_signal("lobby_found") and not _lan_discovery.is_connected("lobby_found", self, "_on_lan_lobby_found"):
		_lan_discovery.connect("lobby_found", self, "_on_lan_lobby_found")


func _process(delta: float) -> void:
	var now = OS.get_ticks_msec()
	if now - _last_ui_scan_msec >= UI_SCAN_INTERVAL_MSEC:
		_last_ui_scan_msec = now
		_poll_main_menu_browser_button()
		_poll_character_public_toggle()
		_refresh_localized_texts()
		_update_public_toggle_state()

	if _overlay_open:
		_update_room_name_marquees(delta)
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
		if _mods_panel != null and is_instance_valid(_mods_panel) and _mods_panel.visible:
			_hide_host_mods()
		elif _direct_panel != null and is_instance_valid(_direct_panel) and _direct_panel.visible:
			_hide_direct_connect()
		else:
			_close_browser_overlay()
		get_tree().set_input_as_handled()


func _get_version_adapter():
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineVersionAdapter")


func _steam_has_method(method_name: String) -> bool:
	if _steam == null:
		return false
	var adapter = _get_version_adapter()
	if adapter != null and adapter.has_method("has_method_cached"):
		return bool(adapter.has_method_cached(_steam, method_name))
	return _steam.has_method(method_name)


func _steam_has_signal(signal_name: String) -> bool:
	if _steam == null:
		return false
	var adapter = _get_version_adapter()
	if adapter != null and adapter.has_method("has_signal_cached"):
		return bool(adapter.has_signal_cached(_steam, signal_name))
	return _steam.has_signal(signal_name)


func _setup_steam() -> void:
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")


func _connect_steam_signals() -> void:
	if _steam == null:
		return
	_connect_signal_if_exists("lobby_match_list", "_on_lobby_match_list")
	_connect_signal_if_exists("lobby_data_update", "_on_lobby_data_update")


func _connect_signal_if_exists(signal_name: String, method_name: String) -> void:
	if _steam == null or not _steam_has_signal(signal_name):
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


func _text(key: String) -> String:
	var translation_key = "BROTATO_ONLINE_PUBLIC_LOBBY_" + key.to_upper()
	var parent = get_parent()
	if parent != null:
		var i18n = parent.get_node_or_null("BrotatoOnlineI18n")
		if i18n != null and i18n.has_method("get_text"):
			return str(i18n.call("get_text", translation_key))
	return translation_key


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
	var manager = _get_session_manager()
	if manager != null and manager.has_method("set_public_lobby_enabled"):
		manager.call("set_public_lobby_enabled", _public_lobby_enabled)


func _get_session_manager() -> Node:
	var parent = get_parent()
	if parent != null:
		var direct = parent.get_node_or_null("BrotatoOnlineSessionManager")
		if direct != null and is_instance_valid(direct):
			return direct
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	return _find_node_named(tree.root, "BrotatoOnlineSessionManager", 0)


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
	# The browser UI is parented to the title scene. When that scene is replaced,
	# Godot 3 leaves member variables pointing at already-freed Objects. A null check
	# is not enough for those references, so drop the complete UI cache once its
	# owning scene has gone away.
	if _overlay_parent != null and not is_instance_valid(_overlay_parent):
		_clear_browser_overlay_refs()


func _clear_browser_overlay_refs() -> void:
	_overlay = null
	_overlay_parent = null
	_title_label = null
	_status_label = null
	_rows_container = null
	_refresh_button = null
	_direct_connect_button = null
	_back_button = null
	_direct_panel = null
	_direct_address_edit = null
	_direct_port_edit = null
	_mods_panel = null
	_mods_title_label = null
	_mods_body_edit = null
	_mods_close_button = null
	_mods_return_focus = null
	_last_focus_owner = null


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
	var manager = _get_session_manager()
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
		_direct_connect_button = existing.get_node_or_null("Center/Panel/Margin/VBox/Bottom/DirectConnect")
		_back_button = existing.get_node_or_null("Center/Panel/Margin/VBox/Bottom/Back")
		_direct_panel = existing.get_node_or_null("DirectConnectPanel")
		if _direct_panel != null:
			_direct_address_edit = _direct_panel.get_node_or_null("Margin/VBox/Address")
			_direct_port_edit = _direct_panel.get_node_or_null("Margin/VBox/Port")
		_mods_panel = existing.get_node_or_null("HostModsPanel")
		if _mods_panel != null:
			_mods_title_label = _mods_panel.get_node_or_null("Center/Panel/Margin/VBox/Title")
			_mods_body_edit = _mods_panel.get_node_or_null("Center/Panel/Margin/VBox/Body")
			_mods_close_button = _mods_panel.get_node_or_null("Center/Panel/Margin/VBox/Close")
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
	panel.rect_min_size = Vector2(1400, 760)
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
	_add_header_label(header, _text("room_name"), int(ROOM_NAME_COLUMN_WIDTH))
	_add_header_label(header, _text("players"), 115)
	_add_header_label(header, _text("ping"), 130)
	_add_header_label(header, _text("state"), 220)
	var header_mods_spacer = Control.new()
	header_mods_spacer.rect_min_size = Vector2(120, 0)
	header.add_child(header_mods_spacer)
	var header_join_spacer = Control.new()
	header_join_spacer.rect_min_size = Vector2(140, 0)
	header.add_child(header_join_spacer)

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

	var refresh_separator = ColorRect.new()
	refresh_separator.color = Color(1, 1, 1, 0.18)
	refresh_separator.rect_min_size = Vector2(2, 52)
	refresh_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(refresh_separator)

	var direct_connect = Button.new()
	direct_connect.name = "DirectConnect"
	direct_connect.text = _text("direct_connect")
	direct_connect.rect_min_size = Vector2(250, 65)
	direct_connect.focus_mode = Control.FOCUS_ALL
	direct_connect.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom.add_child(direct_connect)
	direct_connect.connect("pressed", self, "_show_direct_connect")
	_configure_runtime_button(direct_connect)
	_direct_connect_button = direct_connect

	var bottom_spacer = Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(bottom_spacer)

	var back_separator = ColorRect.new()
	back_separator.color = Color(1, 1, 1, 0.18)
	back_separator.rect_min_size = Vector2(2, 52)
	back_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(back_separator)

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

	var direct_panel = PanelContainer.new()
	direct_panel.name = "DirectConnectPanel"
	direct_panel.anchor_left = 0.5
	direct_panel.anchor_top = 0.5
	direct_panel.anchor_right = 0.5
	direct_panel.anchor_bottom = 0.5
	direct_panel.margin_left = -350
	direct_panel.margin_top = -220
	direct_panel.margin_right = 350
	direct_panel.margin_bottom = 220
	direct_panel.visible = false
	overlay.add_child(direct_panel)
	var direct_margin = MarginContainer.new()
	direct_margin.name = "Margin"
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		direct_margin.add_constant_override(side, 26)
	direct_panel.add_child(direct_margin)
	var direct_vbox = VBoxContainer.new()
	direct_vbox.name = "VBox"
	direct_vbox.add_constant_override("separation", 14)
	direct_margin.add_child(direct_vbox)
	var direct_title = Label.new()
	direct_title.name = "Title"
	direct_title.text = _text("direct_title")
	direct_title.align = Label.ALIGN_CENTER
	direct_vbox.add_child(direct_title)
	var direct_desc = Label.new()
	direct_desc.name = "Description"
	direct_desc.text = _text("direct_description")
	direct_desc.align = Label.ALIGN_CENTER
	direct_desc.autowrap = true
	direct_desc.rect_min_size = Vector2(0, 44)
	direct_vbox.add_child(direct_desc)
	var direct_separator = ColorRect.new()
	direct_separator.name = "Separator"
	direct_separator.color = Color(1, 1, 1, 0.18)
	direct_separator.rect_min_size = Vector2(0, 2)
	direct_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	direct_vbox.add_child(direct_separator)
	var address_label = Label.new()
	address_label.name = "AddressLabel"
	address_label.text = _text("address_label")
	direct_vbox.add_child(address_label)
	var address_edit = LineEdit.new()
	address_edit.name = "Address"
	address_edit.placeholder_text = _text("address_hint")
	address_edit.rect_min_size = Vector2(0, 48)
	direct_vbox.add_child(address_edit)
	var port_label = Label.new()
	port_label.name = "PortLabel"
	port_label.text = _text("port_label")
	direct_vbox.add_child(port_label)
	var port_edit = LineEdit.new()
	port_edit.name = "Port"
	port_edit.placeholder_text = _text("port_hint")
	port_edit.text = str(DEFAULT_LAN_PORT)
	port_edit.rect_min_size = Vector2(0, 48)
	direct_vbox.add_child(port_edit)
	var direct_buttons = HBoxContainer.new()
	direct_buttons.name = "Buttons"
	direct_buttons.add_constant_override("separation", 14)
	direct_vbox.add_child(direct_buttons)
	var join_direct = Button.new()
	join_direct.name = "Join"
	join_direct.text = _text("join")
	join_direct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_direct.rect_min_size = Vector2(0, 56)
	direct_buttons.add_child(join_direct)
	join_direct.connect("pressed", self, "_confirm_direct_connect")
	_configure_runtime_button(join_direct)
	var cancel_direct = Button.new()
	cancel_direct.name = "Cancel"
	cancel_direct.text = _text("cancel")
	cancel_direct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_direct.rect_min_size = Vector2(0, 56)
	direct_buttons.add_child(cancel_direct)
	cancel_direct.connect("pressed", self, "_hide_direct_connect")
	_configure_runtime_button(cancel_direct)
	_direct_panel = direct_panel
	_direct_address_edit = address_edit
	_direct_port_edit = port_edit

	# Modal host-mod viewer. The lobby list itself stays compact; details are only
	# rendered after the user presses the per-row button.
	var mods_layer = Control.new()
	mods_layer.name = "HostModsPanel"
	mods_layer.anchor_right = 1.0
	mods_layer.anchor_bottom = 1.0
	mods_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	mods_layer.visible = false
	overlay.add_child(mods_layer)

	var mods_dim = ColorRect.new()
	mods_dim.name = "Dim"
	mods_dim.anchor_right = 1.0
	mods_dim.anchor_bottom = 1.0
	mods_dim.color = Color(0, 0, 0, 0.45)
	mods_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	mods_layer.add_child(mods_dim)

	var mods_center = CenterContainer.new()
	mods_center.name = "Center"
	mods_center.anchor_right = 1.0
	mods_center.anchor_bottom = 1.0
	mods_layer.add_child(mods_center)

	var mods_popup = PanelContainer.new()
	mods_popup.name = "Panel"
	mods_popup.rect_min_size = Vector2(760, 570)
	mods_center.add_child(mods_popup)

	var mods_margin = MarginContainer.new()
	mods_margin.name = "Margin"
	mods_margin.add_constant_override("margin_left", 28)
	mods_margin.add_constant_override("margin_right", 28)
	mods_margin.add_constant_override("margin_top", 24)
	mods_margin.add_constant_override("margin_bottom", 24)
	mods_popup.add_child(mods_margin)

	var mods_vbox = VBoxContainer.new()
	mods_vbox.name = "VBox"
	mods_vbox.add_constant_override("separation", 14)
	mods_margin.add_child(mods_vbox)

	var mods_title = Label.new()
	mods_title.name = "Title"
	mods_title.text = _text("mods_title")
	mods_title.align = Label.ALIGN_CENTER
	mods_vbox.add_child(mods_title)

	var mods_body = TextEdit.new()
	mods_body.name = "Body"
	mods_body.readonly = true
	mods_body.rect_min_size = Vector2(690, 410)
	mods_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mods_vbox.add_child(mods_body)

	var mods_close = Button.new()
	mods_close.name = "Close"
	mods_close.text = _text("close")
	mods_close.rect_min_size = Vector2(220, 58)
	mods_close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mods_close.connect("pressed", self, "_hide_host_mods")
	_configure_runtime_button(mods_close)
	mods_vbox.add_child(mods_close)

	_mods_panel = mods_layer
	_mods_title_label = mods_title
	_mods_body_edit = mods_body
	_mods_close_button = mods_close

	_refresh_button.focus_neighbour_right = _refresh_button.get_path_to(_direct_connect_button)
	_direct_connect_button.focus_neighbour_left = _direct_connect_button.get_path_to(_refresh_button)
	_direct_connect_button.focus_neighbour_right = _direct_connect_button.get_path_to(_back_button)
	_back_button.focus_neighbour_left = _back_button.get_path_to(_direct_connect_button)

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


func _show_direct_connect() -> void:
	if _direct_panel == null or not is_instance_valid(_direct_panel):
		return
	_direct_panel.show()
	if _direct_address_edit != null and is_instance_valid(_direct_address_edit):
		_direct_address_edit.grab_focus()


func _hide_direct_connect() -> void:
	if _direct_panel != null and is_instance_valid(_direct_panel):
		_direct_panel.hide()
	if _direct_connect_button != null and is_instance_valid(_direct_connect_button):
		_direct_connect_button.grab_focus()


func _confirm_direct_connect() -> void:
	var address = ""
	if _direct_address_edit != null and is_instance_valid(_direct_address_edit):
		address = str(_direct_address_edit.text).strip_edges()
	var port = DEFAULT_LAN_PORT
	if _direct_port_edit != null and is_instance_valid(_direct_port_edit):
		port = int(str(_direct_port_edit.text))
	if address.find(":") != -1:
		var parts = address.split(":", false, 1)
		address = str(parts[0]).strip_edges()
		if parts.size() > 1 and str(parts[1]).strip_edges() != "":
			port = int(parts[1])
	if port <= 0 or port > 65535:
		port = DEFAULT_LAN_PORT
	var manager = _get_session_manager()
	if address == "" or manager == null or not manager.has_method("join_lan"):
		_set_status(_text("join_verify_failed"))
		return
	_hide_direct_connect()
	_close_browser_overlay()
	manager.join_lan(address, port)


func _close_browser_overlay() -> void:
	_overlay_open = false
	_list_request_pending = false
	_pending_public_join_lobby_id = 0
	_pending_public_join_started_msec = 0
	_clear_ping_state()
	_room_name_marquee_by_clip.clear()
	_room_name_marquee_state_by_entry_key.clear()
	_hide_direct_connect()
	_hide_host_mods(false)
	if _lan_discovery != null and is_instance_valid(_lan_discovery) and _lan_discovery.has_method("stop_search"):
		_lan_discovery.stop_search()
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.hide()
	if _last_focus_owner != null and is_instance_valid(_last_focus_owner):
		_last_focus_owner.grab_focus()
	elif _main_menu_button != null and is_instance_valid(_main_menu_button):
		_main_menu_button.grab_focus()


func request_public_lobby_list() -> void:
	if not _overlay_open or _list_request_pending:
		return

	_clear_lobby_results()
	_set_status(_text("searching"))
	_last_list_request_msec = OS.get_ticks_msec()
	if _lan_discovery != null and _lan_discovery.has_method("start_search"):
		_lan_discovery.start_search()
	if _steam == null or not _steam_has_method("requestLobbyList"):
		_list_request_pending = false
		return
	_list_request_pending = true

	if _steam_has_method("addRequestLobbyListStringFilter"):
		_steam.addRequestLobbyListStringFilter("mod", MOD_ID, LOBBY_COMPARISON_EQUAL)
		_steam.addRequestLobbyListStringFilter("visibility", "public", LOBBY_COMPARISON_EQUAL)
	if _steam_has_method("addRequestLobbyListFilterSlotsAvailable"):
		_steam.addRequestLobbyListFilterSlotsAvailable(1)
	if _steam_has_method("addRequestLobbyListDistanceFilter"):
		_steam.addRequestLobbyListDistanceFilter(LOBBY_DISTANCE_WORLDWIDE)
	if _steam_has_method("addRequestLobbyListResultCountFilter"):
		_steam.addRequestLobbyListResultCountFilter(LOBBY_LIST_RESULT_LIMIT)
	var result = _steam.requestLobbyList()
	if typeof(result) == TYPE_BOOL and not bool(result):
		_list_request_pending = false
		_set_status(_text("request_failed"))


func request_lobby_list() -> void:
	request_public_lobby_list()


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
	if typeof(payload) == TYPE_INT and _steam != null and _steam_has_method("getLobbyByIndex"):
		var result = []
		for i in range(max(0, int(payload))):
			result.append(_steam.getLobbyByIndex(i))
		return result
	return []


func _build_lobby_entries(lobby_ids: Array) -> void:
	for value in lobby_ids:
		var lobby_id = int(str(value))
		if lobby_id == 0:
			continue
		var entry = _read_lobby_entry(lobby_id)
		if entry.empty():
			continue
		_upsert_lobby_entry(entry)


func _sanitize_room_name(text: String) -> String:
	var normalized = text.replace("\r", " ").replace("\n", " ").strip_edges()
	if normalized.length() > ROOM_NAME_MAX_LENGTH:
		normalized = normalized.substr(0, ROOM_NAME_MAX_LENGTH)
	return normalized


func _read_lobby_entry(lobby_id: int) -> Dictionary:
	if _steam == null or not _steam_has_method("getLobbyData"):
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
	if host_name == "" and host_id != "" and host_id != "0" and _steam_has_method("getFriendPersonaName"):
		host_name = str(_steam.getFriendPersonaName(int(host_id)))
	if host_name == "":
		host_name = host_id if host_id != "" else str(lobby_id)
	var room_name = _sanitize_room_name(str(_steam.getLobbyData(lobby_id, "room_name")))
	if room_name == "":
		# Optional metadata for protocol compatibility: old hosts only publish
		# host_name, so they remain visible with exactly the previous label.
		room_name = host_name

	# SessionManager publishes total Steam + LAN membership. Steam's native lobby
	# count intentionally must not override this value in a mixed room.
	var member_count = int(str(_steam.getLobbyData(lobby_id, "member_count")))
	var member_limit = int(str(_steam.getLobbyData(lobby_id, "member_limit")))
	if _steam_has_method("getLobbyMemberLimit"):
		var live_limit = int(_steam.getLobbyMemberLimit(lobby_id))
		if live_limit > 0:
			member_limit = live_limit
	if member_limit <= 0:
		member_limit = 4
	if member_count <= 0:
		member_count = 1

	var compatible = mod_version == NETWORK_PROTOCOL_VERSION and game_version == GAME_VERSION
	var joinable_state = state == "character_selection" or state == "coop_resume"
	var full = member_count >= member_limit
	var host_mods = _read_steam_host_mod_metadata(lobby_id)
	return {
		"source": "steam",
		"entry_id": str(lobby_id),
		"entry_key": "steam:" + str(lobby_id),
		"lobby_id": lobby_id,
		"endpoint": {"lobby_id": lobby_id},
		"host_id": host_id,
		"host_name": host_name,
		"room_name": room_name,
		"member_count": member_count,
		"member_limit": member_limit,
		"state": state,
		"compatible": compatible,
		"joinable": compatible and joinable_state and not full and host_id != "" and host_id != "0",
		"full": full,
		"ping_ms": -1,
		"host_mods_format": str(host_mods.get("format", "")),
		"host_mods_payload": str(host_mods.get("payload", "")),
		"host_mods_too_large": bool(host_mods.get("too_large", false))
	}


func _read_steam_host_mod_metadata(lobby_id: int) -> Dictionary:
	if _steam == null or not _steam_has_method("getLobbyData"):
		return {}
	var format_version = str(_steam.getLobbyData(lobby_id, "host_mods_format"))
	if format_version == "":
		return {}
	var too_large = str(_steam.getLobbyData(lobby_id, "host_mods_too_large")) == "1"
	var part_count = int(str(_steam.getLobbyData(lobby_id, "host_mods_parts")))
	if part_count < 0 or part_count > HOST_MODS_LOBBY_MAX_PARTS:
		return {"format": format_version, "payload": "", "too_large": true}
	var payload = ""
	for i in range(part_count):
		payload += str(_steam.getLobbyData(lobby_id, "host_mods_" + str(i)))
	return {"format": format_version, "payload": payload, "too_large": too_large}


func _on_lan_lobby_found(entry: Dictionary) -> void:
	if not _overlay_open or typeof(entry) != TYPE_DICTIONARY:
		return
	var normalized = entry.duplicate(true)
	normalized["source"] = "lan"
	# These fields are optional. Old LAN hosts simply do not provide them.
	normalized["host_mods_format"] = str(normalized.get("host_mods_format", ""))
	normalized["host_mods_payload"] = str(normalized.get("host_mods_payload", ""))
	normalized["host_mods_too_large"] = bool(normalized.get("host_mods_too_large", false))
	var room_name = _sanitize_room_name(str(normalized.get("room_name", "")))
	if room_name == "":
		room_name = str(normalized.get("host_name", ""))
	normalized["room_name"] = room_name
	normalized["compatible"] = str(normalized.get("mod_version", "")) == NETWORK_PROTOCOL_VERSION
	var member_count = int(normalized.get("member_count", 1))
	var member_limit = int(normalized.get("member_limit", 4))
	normalized["full"] = member_count >= member_limit
	normalized["joinable"] = bool(normalized.get("joinable", true)) and bool(normalized["compatible"]) and not bool(normalized["full"])

	var entry_key = str(normalized.get("entry_key", ""))
	var previous = _find_entry(entry_key) if entry_key != "" else {}
	var row_changed = previous.empty() or _lobby_row_data_changed(previous, normalized)
	# LAN discovery sends several probes during one search. Its reported ping is
	# measured from search start, so later duplicate replies naturally contain a
	# larger number. Keep the best reply and update only the ping Label instead of
	# rebuilding the entire row for every duplicate response.
	if not previous.empty():
		var previous_ping = int(previous.get("ping_ms", -1))
		var incoming_ping = int(normalized.get("ping_ms", -1))
		if previous_ping >= 0 and incoming_ping >= 0:
			normalized["ping_ms"] = min(previous_ping, incoming_ping)
	_upsert_lobby_entry(normalized)
	if row_changed:
		_rebuild_lobby_rows()
	else:
		_update_ping_label_for_entry_key(entry_key, int(normalized.get("ping_ms", -1)))


func _upsert_lobby_entry(entry: Dictionary) -> void:
	var entry_key = str(entry.get("entry_key", ""))
	if entry_key == "":
		return
	if _entry_by_key.has(entry_key):
		var index = int(_entry_by_key[entry_key])
		if index >= 0 and index < _lobby_entries.size():
			_lobby_entries[index] = entry
			return
	_entry_by_key[entry_key] = _lobby_entries.size()
	_lobby_entries.append(entry)


func _lobby_row_data_changed(previous: Dictionary, incoming: Dictionary) -> bool:
	# ping_ms is intentionally excluded: ping has its own in-place Label update.
	# endpoint/entry ids do not affect the visible row either.
	for key in [
		"source", "host_id", "host_name", "room_name",
		"member_count", "member_limit", "state", "compatible",
		"joinable", "full", "host_mods_format", "host_mods_payload",
		"host_mods_too_large"
	]:
		if previous.get(key, null) != incoming.get(key, null):
			return true
	return false


func _update_ping_label_for_entry_key(entry_key: String, ping_ms: int) -> void:
	if not _ping_label_by_lobby_id.has(entry_key):
		return
	var label = _ping_label_by_lobby_id[entry_key]
	if label != null and is_instance_valid(label):
		label.text = _format_ping(ping_ms)


func _rebuild_lobby_rows() -> void:
	if _rows_container == null or not is_instance_valid(_rows_container):
		return
	for child in _rows_container.get_children():
		_rows_container.remove_child(child)
		child.queue_free()
	_ping_label_by_lobby_id.clear()
	_room_name_marquee_by_clip.clear()

	if _lobby_entries.empty():
		_set_status(_text("none"))
		var empty_label = Label.new()
		empty_label.text = _text("none")
		empty_label.align = Label.ALIGN_CENTER
		empty_label.rect_min_size = Vector2(0, 90)
		_rows_container.add_child(empty_label)
		return

	_set_status(_text("count") % _lobby_entries.size())
	for entry in _lobby_entries:
		_add_lobby_row(entry)


func _add_lobby_row(entry: Dictionary) -> void:
	var panel = PanelContainer.new()
	panel.rect_min_size = Vector2(0, 66)
	_rows_container.add_child(panel)

	var row = HBoxContainer.new()
	row.add_constant_override("separation", 12)
	panel.add_child(row)

	# Keep the room-name column at a fixed width. A Label's own minimum width can
	# still grow with long text even when clip_text is enabled, which used to push
	# the player/ping/state columns to the right. The parent Control owns the fixed
	# column width and clips the wider child Label instead.
	var host_clip = Control.new()
	host_clip.rect_min_size = Vector2(ROOM_NAME_COLUMN_WIDTH, ROOM_NAME_ROW_HEIGHT)
	host_clip.rect_clip_content = true
	host_clip.mouse_filter = Control.MOUSE_FILTER_PASS
	host_clip.hint_tooltip = str(entry.get("host_name", ""))
	row.add_child(host_clip)

	var host = Label.new()
	var source_prefix = "[LAN] " if str(entry.get("source", "steam")) == "lan" else ""
	host.text = source_prefix + str(entry.get("room_name", entry.get("host_name", "")))
	host.hint_tooltip = str(entry.get("host_name", ""))
	# Do not give the Label a 420 px minimum before measuring its text. Doing so
	# makes get_combined_minimum_size() report at least 420 px even for short
	# names, which previously created a fake ~6 px overflow on every row.
	host.rect_min_size = Vector2(0, ROOM_NAME_ROW_HEIGHT)
	host.rect_size = Vector2(ROOM_NAME_COLUMN_WIDTH, ROOM_NAME_ROW_HEIGHT)
	host.valign = Label.VALIGN_CENTER
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host_clip.add_child(host)
	_register_room_name_marquee(str(entry.get("entry_key", "")), host_clip, host)

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
	_ping_label_by_lobby_id[str(entry.get("entry_key", ""))] = ping

	var state = Label.new()
	state.text = _format_lobby_state(entry)
	state.rect_min_size = Vector2(220, 60)
	state.valign = Label.VALIGN_CENTER
	state.clip_text = true
	row.add_child(state)

	var view_mods = Button.new()
	view_mods.text = _text("view_mods")
	view_mods.rect_min_size = Vector2(120, 60)
	view_mods.focus_mode = Control.FOCUS_ALL
	view_mods.mouse_filter = Control.MOUSE_FILTER_STOP
	view_mods.connect("pressed", self, "_on_view_mods_pressed", [str(entry.get("entry_key", ""))])
	_configure_runtime_button(view_mods)
	row.add_child(view_mods)

	var join = Button.new()
	join.text = _text("join")
	join.rect_min_size = Vector2(140, 60)
	join.focus_mode = Control.FOCUS_ALL
	join.mouse_filter = Control.MOUSE_FILTER_STOP
	join.disabled = not bool(entry.get("joinable", false))
	join.connect("pressed", self, "_on_join_lobby_pressed", [str(entry.get("entry_key", ""))])
	_configure_runtime_button(join)
	row.add_child(join)
	view_mods.focus_neighbour_right = view_mods.get_path_to(join)
	join.focus_neighbour_left = join.get_path_to(view_mods)



func _register_room_name_marquee(entry_key: String, clip: Control, label: Label) -> void:
	if clip == null or label == null or not is_instance_valid(clip) or not is_instance_valid(label):
		return

	# Measure the text itself, not a previously forced column minimum. The parent
	# owns the fixed-width clipping area; the Label only becomes wider when the
	# actual rendered text really exceeds it.
	label.rect_min_size = Vector2(0, ROOM_NAME_ROW_HEIGHT)
	var natural_width = label.get_combined_minimum_size().x
	var clip_width = ROOM_NAME_COLUMN_WIDTH
	if clip.rect_size.x > 1.0:
		clip_width = clip.rect_size.x
	var overflows = natural_width > clip_width + ROOM_NAME_SCROLL_OVERFLOW_EPSILON
	var label_width = clip_width
	if overflows:
		# A few pixels of trailing room prevent the final glyph from touching the
		# clipping boundary, but are added only after real overflow is confirmed.
		label_width = natural_width + 6.0
	label.rect_size = Vector2(label_width, ROOM_NAME_ROW_HEIGHT)

	var saved = _room_name_marquee_state_by_entry_key.get(entry_key, {})
	if typeof(saved) != TYPE_DICTIONARY or str(saved.get("text", "")) != label.text:
		saved = {}
	var max_offset = max(0.0, label_width - clip_width) if overflows else 0.0
	var offset = clamp(float(saved.get("offset", 0.0)), 0.0, max_offset)
	var direction = float(saved.get("direction", 1.0))
	if direction == 0.0:
		direction = 1.0
	var pause = max(0.0, float(saved.get("pause", ROOM_NAME_SCROLL_EDGE_PAUSE)))
	if max_offset <= ROOM_NAME_SCROLL_OVERFLOW_EPSILON:
		offset = 0.0
		direction = 1.0
		pause = 0.0

	label.rect_position = Vector2(-offset, label.rect_position.y)
	var item = {
		"entry_key": entry_key,
		"clip": clip,
		"label": label,
		"text": label.text,
		"scrollable": overflows,
		"offset": offset,
		"direction": direction,
		"pause": pause
	}
	_room_name_marquee_by_clip[clip.get_instance_id()] = item
	_store_room_name_marquee_state(item)


func _store_room_name_marquee_state(item: Dictionary) -> void:
	var entry_key = str(item.get("entry_key", ""))
	if entry_key == "":
		return
	_room_name_marquee_state_by_entry_key[entry_key] = {
		"text": str(item.get("text", "")),
		"offset": float(item.get("offset", 0.0)),
		"direction": float(item.get("direction", 1.0)),
		"pause": float(item.get("pause", 0.0))
	}


func _update_room_name_marquees(delta: float) -> void:
	if _room_name_marquee_by_clip.empty():
		return
	var stale_keys = []
	for key in _room_name_marquee_by_clip.keys():
		var item = _room_name_marquee_by_clip[key]
		var clip = item.get("clip", null)
		var label = item.get("label", null)
		if clip == null or label == null or not is_instance_valid(clip) or not is_instance_valid(label):
			stale_keys.append(key)
			continue

		var max_offset = max(0.0, label.rect_size.x - clip.rect_size.x)
		if not bool(item.get("scrollable", false)) or max_offset <= ROOM_NAME_SCROLL_OVERFLOW_EPSILON:
			item["offset"] = 0.0
			item["direction"] = 1.0
			item["pause"] = 0.0
			label.rect_position = Vector2(0.0, label.rect_position.y)
			_room_name_marquee_by_clip[key] = item
			_store_room_name_marquee_state(item)
			continue

		var pause_left = float(item.get("pause", 0.0))
		if pause_left > 0.0:
			item["pause"] = max(0.0, pause_left - delta)
			_room_name_marquee_by_clip[key] = item
			_store_room_name_marquee_state(item)
			continue

		var offset = float(item.get("offset", 0.0))
		var direction = float(item.get("direction", 1.0))
		# Dynamically raise the speed for very long names. The target includes
		# the initial/end-edge pauses and deliberately stays below the 10 s refresh.
		var pause_budget = ROOM_NAME_SCROLL_EDGE_PAUSE * 2.0
		var travel_budget = max(1.0, ROOM_NAME_SCROLL_CYCLE_TARGET_SEC - pause_budget)
		var scroll_speed = max(ROOM_NAME_SCROLL_MIN_SPEED, (max_offset * 2.0) / travel_budget)
		offset += direction * scroll_speed * delta
		if offset >= max_offset:
			offset = max_offset
			direction = -1.0
			item["pause"] = ROOM_NAME_SCROLL_EDGE_PAUSE
		elif offset <= 0.0:
			offset = 0.0
			direction = 1.0
			item["pause"] = ROOM_NAME_SCROLL_EDGE_PAUSE
		item["offset"] = offset
		item["direction"] = direction
		label.rect_position = Vector2(-offset, label.rect_position.y)
		_room_name_marquee_by_clip[key] = item
		_store_room_name_marquee_state(item)

	for key in stale_keys:
		_room_name_marquee_by_clip.erase(key)


func _format_lobby_state(entry: Dictionary) -> String:
	if not bool(entry.get("compatible", false)):
		return _text("version_mismatch")
	if bool(entry.get("full", false)):
		return _text("full")
	var state = str(entry.get("state", "unknown"))
	if state == "battle":
		state = "game"
	elif state == "menu":
		state = "busy"
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
	_entry_by_key.clear()
	_clear_ping_state()
	if _rows_container != null and is_instance_valid(_rows_container):
		for child in _rows_container.get_children():
			_rows_container.remove_child(child)
			child.queue_free()


func _on_view_mods_pressed(entry_key: String) -> void:
	if entry_key == "":
		return
	var entry = _find_entry(entry_key)
	if entry.empty():
		return
	_show_host_mods(_format_host_mods_text(entry))


func _format_host_mods_text(entry: Dictionary) -> String:
	var format_version = str(entry.get("host_mods_format", ""))
	if format_version == "":
		return _text("mods_unsupported")
	if format_version != HOST_MODS_FORMAT_VERSION:
		return _text("mods_unknown_format")
	if bool(entry.get("host_mods_too_large", false)):
		return _text("mods_too_large")

	var payload = str(entry.get("host_mods_payload", ""))
	if payload == "":
		return _text("mods_unreadable")
	var parsed = parse_json(payload)
	if typeof(parsed) != TYPE_ARRAY:
		return _text("mods_unreadable")
	if parsed.empty():
		return _text("mods_empty")

	var lines = []
	lines.append(_text("mods_count") % parsed.size())
	lines.append("")
	var index = 1
	for value in parsed:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var mod_id = str(value.get("id", "")).strip_edges()
		var mod_name = str(value.get("name", mod_id)).strip_edges()
		var mod_version = str(value.get("version", "")).strip_edges()
		if mod_name == "":
			mod_name = mod_id if mod_id != "" else _text("mods_unknown_name")
		var line = str(index) + ". " + mod_name
		if mod_version != "":
			line += "  " + mod_version
		if mod_id != "" and mod_id != mod_name:
			line += "  [" + mod_id + "]"
		lines.append(line)
		index += 1
	return "\n".join(lines)


func _show_host_mods(text: String) -> void:
	if _mods_panel == null or not is_instance_valid(_mods_panel):
		return
	var viewport = get_viewport()
	if viewport != null and viewport.has_method("gui_get_focus_owner"):
		var focus_owner = viewport.call("gui_get_focus_owner")
		if focus_owner != null and focus_owner is Control:
			_mods_return_focus = focus_owner
	if _direct_panel != null and is_instance_valid(_direct_panel):
		_direct_panel.hide()
	if _mods_body_edit != null and is_instance_valid(_mods_body_edit):
		_mods_body_edit.text = text
		_mods_body_edit.scroll_vertical = 0
	_mods_panel.show()
	if _mods_panel.get_parent() != null:
		_mods_panel.get_parent().move_child(_mods_panel, _mods_panel.get_parent().get_child_count() - 1)
	if _mods_close_button != null and is_instance_valid(_mods_close_button):
		_mods_close_button.grab_focus()


func _hide_host_mods(restore_focus: bool = true) -> void:
	if _mods_panel != null and is_instance_valid(_mods_panel):
		_mods_panel.hide()
	if restore_focus and _mods_return_focus != null and is_instance_valid(_mods_return_focus):
		_mods_return_focus.grab_focus()
	elif restore_focus and _refresh_button != null and is_instance_valid(_refresh_button):
		_refresh_button.grab_focus()
	_mods_return_focus = null


func _on_join_lobby_pressed(entry_key: String) -> void:
	if entry_key == "" or _pending_public_join_lobby_id != 0:
		return
	var entry = _find_entry(entry_key)
	if entry.empty():
		return
	if str(entry.get("source", "steam")) == "lan":
		var endpoint = entry.get("endpoint", {})
		var manager = _get_session_manager()
		if manager != null and manager.has_method("join_lan"):
			_close_browser_overlay()
			manager.join_lan(str(endpoint.get("address", "")), int(endpoint.get("port", DEFAULT_LAN_PORT)))
		return
	var lobby_id = int(entry.get("lobby_id", 0))
	if lobby_id == 0:
		return
	if _steam == null or not _steam_has_method("requestLobbyData"):
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


func _find_entry(entry_key: String) -> Dictionary:
	if not _entry_by_key.has(entry_key):
		return {}
	var index = int(_entry_by_key[entry_key])
	if index < 0 or index >= _lobby_entries.size():
		return {}
	return _lobby_entries[index]


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
	if _steam != null and _steam_has_method("getLobbyData"):
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

	var manager = _get_session_manager()
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
	_entry_by_key.clear()
	for i in range(_lobby_entries.size()):
		_entry_by_key[str(_lobby_entries[i].get("entry_key", ""))] = i


func _start_ping_measurements() -> void:
	# Keep the row-label map built by _rebuild_lobby_rows(). Only reset the
	# request state for a fresh measurement round.
	_ping_state_by_lobby_id.clear()
	_pending_ping_by_nonce.clear()
	var now = OS.get_ticks_msec()
	for entry in _lobby_entries:
		if str(entry.get("source", "steam")) != "steam":
			continue
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
	if _steam == null or not _steam_has_method("sendMessageToUser"):
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
	if _steam_has_method("acceptSessionWithUser"):
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
	if _steam == null or not _steam_has_method("receiveMessagesOnChannel"):
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
	_update_ping_label_for_entry_key("steam:" + lobby_key, ping_ms)


func _clear_ping_state() -> void:
	_ping_label_by_lobby_id.clear()
	_ping_state_by_lobby_id.clear()
	_pending_ping_by_nonce.clear()


func _refresh_localized_texts() -> void:
	if _main_menu_button != null and is_instance_valid(_main_menu_button):
		_main_menu_button.text = _text("browser_button")
	if _public_toggle != null and is_instance_valid(_public_toggle):
		_public_toggle.text = _text("public_toggle")
	if _title_label != null and is_instance_valid(_title_label):
		_title_label.text = _text("title")
	if _refresh_button != null and is_instance_valid(_refresh_button):
		_refresh_button.text = _text("refresh")
	if _direct_connect_button != null and is_instance_valid(_direct_connect_button):
		_direct_connect_button.text = _text("direct_connect")
	if _back_button != null and is_instance_valid(_back_button):
		_back_button.text = _text("back")
	if _mods_title_label != null and is_instance_valid(_mods_title_label):
		_mods_title_label.text = _text("mods_title")
	if _mods_close_button != null and is_instance_valid(_mods_close_button):
		_mods_close_button.text = _text("close")
	if _direct_panel != null and is_instance_valid(_direct_panel):
		var title = _direct_panel.get_node_or_null("Margin/VBox/Title")
		var description = _direct_panel.get_node_or_null("Margin/VBox/Description")
		var address_label = _direct_panel.get_node_or_null("Margin/VBox/AddressLabel")
		var address_edit = _direct_panel.get_node_or_null("Margin/VBox/Address")
		var port_label = _direct_panel.get_node_or_null("Margin/VBox/PortLabel")
		var port_edit = _direct_panel.get_node_or_null("Margin/VBox/Port")
		var join_button = _direct_panel.get_node_or_null("Margin/VBox/Buttons/Join")
		var cancel_button = _direct_panel.get_node_or_null("Margin/VBox/Buttons/Cancel")
		if title != null:
			title.text = _text("direct_title")
		if description != null:
			description.text = _text("direct_description")
		if address_label != null:
			address_label.text = _text("address_label")
		if address_edit != null:
			address_edit.placeholder_text = _text("address_hint")
		if port_label != null:
			port_label.text = _text("port_label")
		if port_edit != null:
			port_edit.placeholder_text = _text("port_hint")
		if join_button != null:
			join_button.text = _text("join")
		if cancel_button != null:
			cancel_button.text = _text("cancel")
