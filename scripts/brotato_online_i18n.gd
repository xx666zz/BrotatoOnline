extends Node

const TRANSLATION_FILES = {
	"en": "translations/brotato_online_en.txt",
	"zh": "translations/brotato_online_zh.txt"
}

var _translations = {}
var _load_attempted = false


func reload_translations() -> void:
	_load_attempted = true
	_translations.clear()
	var mod_root = _get_mod_root_path()
	for language_code in TRANSLATION_FILES.keys():
		var file_path = mod_root.plus_file(str(TRANSLATION_FILES[language_code]))
		var table = _parse_translation_file(file_path)
		if not table.empty():
			_translations[language_code] = table


func get_text(key: String) -> String:
	if not _load_attempted:
		reload_translations()

	var language_code = get_language_code()
	if _translations.has(language_code) and _translations[language_code].has(key):
		return str(_translations[language_code][key])
	if _translations.has("en") and _translations["en"].has(key):
		return str(_translations["en"][key])
	return key


func get_language_code() -> String:
	var language = str(TranslationServer.get_locale())
	language = language.replace("-", "_").strip_edges().to_lower()
	return "zh" if language.begins_with("zh") else "en"


func _get_mod_root_path() -> String:
	var script_res = get_script()
	if script_res != null:
		var resource_path = str(script_res.resource_path)
		if resource_path != "":
			return resource_path.get_base_dir().get_base_dir()
	return "res://mods-unpacked/six666-BrotatoOnline"


func _parse_translation_file(file_path: String) -> Dictionary:
	var out = {}
	var file = File.new()
	if not file.file_exists(file_path):
		return out
	if file.open(file_path, File.READ) != OK:
		return out

	# Read one physical line at a time instead of File.get_csv_line(). A malformed
	# quoted CSV row must never make mod startup wait for additional lines/EOF.
	var line_index = 0
	while not file.eof_reached():
		var line = file.get_line()
		line_index += 1
		if line == null:
			continue
		line = str(line)
		if line.ends_with("\r"):
			line = line.substr(0, line.length() - 1)
		if line == "":
			continue

		var separator = line.find(",")
		if separator < 0:
			continue
		var key = line.substr(0, separator).strip_edges()
		if key == "" or (line_index == 1 and key.to_lower() == "key"):
			continue

		var text = line.substr(separator + 1, line.length() - separator - 1)
		if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
			text = text.substr(1, text.length() - 2).replace("\"\"", "\"")
		out[key] = text.replace("\\n", "\n")

	file.close()
	return out
