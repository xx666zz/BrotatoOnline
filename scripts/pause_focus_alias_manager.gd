extends Node

# Purpose:
#   In battle pause/options, vanilla MenuOptions calls Utils.get_focus_emulator(0).
#   The battle pause scene owns "FocusEmulator" under PauseMenu, not a scene-level
#   "FocusEmulator1". This manager creates a lightweight scene-level alias and
#   keeps its focused_control valid, so vanilla MenuOptions can return focus safely
#   without script-extending res://ui/menus/pages/menu_options.gd.

const LOG_NAME = "six666-BrotatoOnline"
const FOCUS_EMULATOR_SCRIPT_PATH = "res://ui/menus/global/focus_emulator.gd"
const FOCUS_BASE_DATA_SCRIPT_PATH = "res://ui/menus/global/focus_emulator_base_data.gd"

var _focus_emulator_script = null
var _focus_base_data_script = null
var _active_scene = null
var _alias = null
var _pause_menu = null
var _scan_cooldown = 0.0
var _printed_alias_created = false
var _printed_focus_repaired = false


func _brotato_online_is_online_session_active() -> bool:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return false
	return bool(tree.root.get_meta("brotato_online_session_active", false))


func _clear_alias_if_inactive() -> void:
	if _alias != null and is_instance_valid(_alias) and _alias.has_meta("brotato_online_pause_alias"):
		_alias.queue_free()
	_alias = null
	_pause_menu = null
	_printed_alias_created = false
	_printed_focus_repaired = false


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_focus_emulator_script = load(FOCUS_EMULATOR_SCRIPT_PATH)
	_focus_base_data_script = load(FOCUS_BASE_DATA_SCRIPT_PATH)
	if _focus_emulator_script == null:
		ModLoaderLog.error("Failed to load FocusEmulator script: " + FOCUS_EMULATOR_SCRIPT_PATH, LOG_NAME)
	if _focus_base_data_script == null:
		ModLoaderLog.error("Failed to load FocusEmulatorBaseData script: " + FOCUS_BASE_DATA_SCRIPT_PATH, LOG_NAME)
	set_process(true)


func _process(delta: float) -> void:
	if not _brotato_online_is_online_session_active():
		_clear_alias_if_inactive()
		return

	var scene = get_tree().current_scene
	if scene == null:
		return

	if scene != _active_scene:
		_active_scene = scene
		_alias = null
		_pause_menu = null
		_scan_cooldown = 0.0
		_printed_alias_created = false
		_printed_focus_repaired = false

	# Never touch scenes that already own a real FocusEmulator1, such as CoopShop.
	# This manager is only a compatibility shim for battle pause/options lookup.
	if _scene_has_real_focus_emulator1(scene):
		_alias = null
		return

	_scan_cooldown -= delta
	if _scan_cooldown <= 0.0 or _pause_menu == null or not is_instance_valid(_pause_menu):
		_pause_menu = _find_pause_menu(scene)
		_scan_cooldown = 0.15

	if _pause_menu == null:
		return

	_ensure_alias(scene, _pause_menu)
	_sync_alias(_pause_menu)
	_repair_pause_menu_options_focus(_pause_menu)


func _scene_has_real_focus_emulator1(scene) -> bool:
	if scene == null:
		return false
	var existing = scene.get_node_or_null("FocusEmulator1")
	if existing == null:
		return false
	if existing.has_meta("brotato_online_pause_alias") and bool(existing.get_meta("brotato_online_pause_alias")):
		return false
	# A real menu/shop FocusEmulator has configured focus bases. The alias we create
	# has an empty focus_base_data array and is disabled for input/process.
	if _has_property(existing, "focus_base_data"):
		var bases = existing.get("focus_base_data")
		if typeof(bases) == TYPE_ARRAY and bases.size() > 0:
			return true
	return false


func _ensure_alias(scene, pause_menu) -> void:
	var existing = scene.get_node_or_null("FocusEmulator1")
	if existing != null:
		_alias = existing
		return

	if _focus_emulator_script == null:
		return

	var pause_focus = pause_menu.get_node_or_null("FocusEmulator")
	if pause_focus == null:
		return

	var alias = Node2D.new()
	alias.name = "FocusEmulator1"
	alias.set_script(_focus_emulator_script)
	alias.set_meta("brotato_online_pause_alias", true)

	# Set focus bases before add_child(), because FocusEmulator._ready() resolves
	# focus_base_data immediately.  An empty alias focus base is what produced:
	#   Focus base not found for control: OptionsButton
	if _has_property(alias, "focus_base_data"):
		alias.set("focus_base_data", _build_alias_focus_base_data(scene, pause_menu))
	if _has_property(alias, "player_index") and _has_property(pause_focus, "player_index"):
		alias.set("player_index", int(pause_focus.get("player_index")))

	scene.add_child(alias)

	# This node is only for Utils.get_focus_emulator(0) lookup compatibility.
	# The real PauseMenu FocusEmulator still handles pause-menu input.
	alias.set_process(false)
	alias.set_process_input(false)
	alias.set_physics_process(false)
	alias.visible = false

	_alias = alias
	_sync_alias(pause_menu)

	if not _printed_alias_created:
		_printed_alias_created = true


func _sync_alias(pause_menu) -> void:
	if _alias == null or not is_instance_valid(_alias):
		_alias = null
		return

	var pause_focus = pause_menu.get_node_or_null("FocusEmulator")
	if pause_focus == null:
		return

	if _has_property(pause_focus, "player_index") and _has_property(_alias, "player_index"):
		var player_index = int(pause_focus.get("player_index"))
		if int(_alias.get("player_index")) != player_index:
			_alias.set("player_index", player_index)

	# Critical fix: vanilla MenuOptions.init() reads
	# Utils.get_focus_emulator(0).focused_control into focus_before_created.
	# If the alias has no focused_control, Back later crashes on Nil.grab_focus().
	var return_focus = _get_return_focus_control(pause_menu, pause_focus)
	if return_focus != null and _has_property(_alias, "focused_control"):
		var current = _alias.get("focused_control")
		if current == null or not is_instance_valid(current):
			_alias.set("focused_control", return_focus)


func _repair_pause_menu_options_focus(pause_menu) -> void:
	var menu_options = pause_menu.get_node_or_null("Menus/MenuOptions")
	if menu_options == null:
		menu_options = _find_descendant_named(pause_menu, "MenuOptions")
	if menu_options == null:
		return
	if not _has_property(menu_options, "focus_before_created"):
		return

	var existing = menu_options.get("focus_before_created")
	if existing != null and is_instance_valid(existing):
		return

	var pause_focus = pause_menu.get_node_or_null("FocusEmulator")
	var return_focus = _get_return_focus_control(pause_menu, pause_focus)
	if return_focus == null:
		return

	menu_options.set("focus_before_created", return_focus)

	if not _printed_focus_repaired:
		_printed_focus_repaired = true


func _build_alias_focus_base_data(scene, pause_menu) -> Array:
	var result = []
	if _focus_base_data_script == null or scene == null or pause_menu == null:
		return result

	var pause_rel = str(scene.get_path_to(pause_menu))
	var menu_base_path = "../Menus"
	if pause_rel != "" and pause_rel != ".":
		menu_base_path = "../" + pause_rel + "/Menus"

	var base_all = _new_focus_base_data(menu_base_path, false)
	if base_all != null:
		result.append(base_all)

	var base_main_list = _new_focus_base_data(menu_base_path + "/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/HBoxContainer/VBoxContainer", true)
	if base_main_list != null:
		result.append(base_main_list)

	return result


func _new_focus_base_data(path: String, contain_vertical: bool):
	if _focus_base_data_script == null:
		return null
	var data = _focus_base_data_script.new()
	data.set("path", NodePath(path))
	data.set("apply_player_color", true)
	data.set("contain_horizontal_focus", false)
	data.set("contain_horizontal_focus_exception_paths", [])
	data.set("contain_vertical_focus", contain_vertical)
	data.set("require_entry_from_control_paths", [])
	data.set("focus_neighbour_top_paths", [])
	data.set("focus_neighbour_bottom_paths", [])
	data.set("focus_neighbour_left_paths", [])
	data.set("focus_neighbour_right_paths", [])
	return data


func _get_return_focus_control(pause_menu, pause_focus):
	# Prefer the real pause FocusEmulator's focused control. When entering options,
	# this is normally OptionsButton.
	var focused = _get_valid_focused_control(pause_focus)
	if focused != null:
		return focused

	# Stable fallback paths from res://ui/menus/ingame/ingame_main_menu.tscn.
	var option_button = pause_menu.get_node_or_null("Menus/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/Buttons/OptionsButton")
	if option_button != null and option_button is Control and is_instance_valid(option_button):
		return option_button

	option_button = _find_descendant_named(pause_menu, "OptionsButton")
	if option_button != null and option_button is Control and is_instance_valid(option_button):
		return option_button

	var resume_button = pause_menu.get_node_or_null("Menus/MainMenu/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer2/Buttons/ResumeButton")
	if resume_button != null and resume_button is Control and is_instance_valid(resume_button):
		return resume_button

	resume_button = _find_descendant_named(pause_menu, "ResumeButton")
	if resume_button != null and resume_button is Control and is_instance_valid(resume_button):
		return resume_button

	return null


func _get_valid_focused_control(focus_emulator):
	if focus_emulator == null or not is_instance_valid(focus_emulator):
		return null
	if not _has_property(focus_emulator, "focused_control"):
		return null
	var focused = focus_emulator.get("focused_control")
	if focused != null and focused is Control and is_instance_valid(focused):
		return focused
	return null


func _find_pause_menu(scene):
	var pause_menu = scene.get_node_or_null("UI/PauseMenu")
	if pause_menu != null and pause_menu.get_node_or_null("FocusEmulator") != null:
		return pause_menu

	pause_menu = scene.get_node_or_null("PauseMenu")
	if pause_menu != null and pause_menu.get_node_or_null("FocusEmulator") != null:
		return pause_menu

	return _find_pause_menu_recursive(scene)


func _find_pause_menu_recursive(node):
	if node == null:
		return null

	if str(node.name) == "PauseMenu" and node.get_node_or_null("FocusEmulator") != null:
		return node

	for child in node.get_children():
		var found = _find_pause_menu_recursive(child)
		if found != null:
			return found

	return null


func _find_descendant_named(node, target_name: String):
	if node == null:
		return null
	if str(node.name) == target_name:
		return node
	for child in node.get_children():
		var found = _find_descendant_named(child, target_name)
		if found != null:
			return found
	return null


func _has_property(obj, property_name: String) -> bool:
	if obj == null:
		return false

	var property_list = obj.get_property_list()
	for property_info in property_list:
		if typeof(property_info) == TYPE_DICTIONARY and str(property_info.get("name", "")) == property_name:
			return true

	return false
