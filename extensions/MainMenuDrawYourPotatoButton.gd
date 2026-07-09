extends "res://ui/menus/pages/main_menu.gd"

var _custom_potato_button: Button = null
var _custom_potato_translations = {}
var _custom_potato_translation_loaded = false


func _ready() -> void:
	_custom_potato_add_button()


func _custom_potato_add_button() -> void:
	if left_container == null:
		return
	if left_container.get_node_or_null("DrawYourPotatoButton") != null:
		return

	_custom_potato_button = Button.new()
	_custom_potato_button.name = "DrawYourPotatoButton"
	_custom_potato_button.text = _custom_potato_tr("BUTTON_MAIN_MENU")
	_custom_potato_button.align = Button.ALIGN_LEFT
	_custom_potato_button.expand_icon = true
	_custom_potato_button.rect_min_size = Vector2(0, 65)
	_custom_potato_button.focus_mode = Control.FOCUS_ALL

	var script = load("res://ui/menus/global/my_menu_button.gd")
	if script != null:
		_custom_potato_button.set_script(script)

	left_container.add_child(_custom_potato_button)
	if quit_button != null and quit_button.get_parent() == left_container:
		left_container.move_child(_custom_potato_button, quit_button.get_index())

	_custom_potato_button.connect("pressed", self, "_on_DrawYourPotatoButton_pressed")


func _on_DrawYourPotatoButton_pressed() -> void:
	var manager = _custom_potato_get_manager()
	if manager != null:
		manager.open_painter()


func _custom_potato_get_manager():
	var tree = get_tree()
	if tree == null:
		return null
	var managers = tree.get_nodes_in_group("DrawYourPotatoManager")
	if managers.empty():
		return null
	return managers[0]


func _custom_potato_tr(key: String) -> String:
	var manager = _custom_potato_get_manager()
	if manager != null and manager.has_method("get_text"):
		return manager.get_text(key)
	_custom_potato_load_translations()
	if _custom_potato_translations.has(key):
		var entry = _custom_potato_translations[key]
		if TranslationServer.get_locale().to_lower().begins_with("zh"):
			return str(entry.get("zh", key))
		return str(entry.get("en", key))
	return "自定义土豆" if TranslationServer.get_locale().to_lower().begins_with("zh") else "CUSTOM POTATO"


func _custom_potato_load_translations() -> void:
	if _custom_potato_translation_loaded:
		return
	_custom_potato_translation_loaded = true
	_custom_potato_translations.clear()
	var mod_dir_path = ModLoaderMod.get_unpacked_dir().plus_file("six666-DrawYourPotato")
	var path = mod_dir_path.plus_file("Translations/DrawYourPotato.csv")
	var file = File.new()
	if not file.file_exists(path):
		return
	if file.open(path, File.READ) != OK:
		return
	var is_header = true
	while not file.eof_reached():
		var line = file.get_line()
		if line.strip_edges().empty():
			continue
		if is_header:
			is_header = false
			continue
		var cols = line.split(",", true)
		if cols.size() < 3:
			continue
		_custom_potato_translations[str(cols[0]).strip_edges()] = {"zh": str(cols[1]), "en": str(cols[2])}
	file.close()
