extends Node

const TRANSLATION_FILES = {
	"en": "translations/brotato_online_en.txt",
	"zh": "translations/brotato_online_zh.txt"
}

const I18N_BUILD_MARKER = "i18n-table-retry-v2"
const RETRY_INTERVAL_MSEC = 1000

var _translations = {}
var _translation_paths = {}
var _last_retry_msec = -RETRY_INTERVAL_MSEC
var _last_status_key = ""


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	set_process(true)
	_connect_language_signal()
	_reload_missing_translations(true)
	_log_status("ready")


func _process(_delta: float) -> void:
	if _has_all_translation_tables():
		return
	_reload_missing_translations(false)


func reload_translations() -> void:
	# Explicit reload keeps already-valid tables until a replacement was parsed.
	# A transient File.open/file_exists failure must not erase the working language.
	_reload_missing_translations(true, true)


func get_text(key: String) -> String:
	var language_code = get_language_code()
	if not _has_translation_table(language_code):
		_reload_missing_translations(false)

	if _has_translation_table(language_code) and _translations[language_code].has(key):
		return str(_translations[language_code][key])
	if _has_translation_table("en") and _translations["en"].has(key):
		return str(_translations["en"][key])
	return key


func get_language_code() -> String:
	# Brotato calls TranslationServer.set_locale() both during startup settings
	# application and before emitting ProgressData.language_changed().
	var language = str(TranslationServer.get_locale())
	language = language.replace("-", "_").strip_edges().to_lower()
	return "zh" if language.begins_with("zh") else "en"


func get_debug_status() -> Dictionary:
	return {
		"marker": I18N_BUILD_MARKER,
		"locale": str(TranslationServer.get_locale()),
		"language_code": get_language_code(),
		"loaded_languages": _translations.keys(),
		"translation_paths": _translation_paths.duplicate(true),
		"entry_counts": _get_entry_counts()
	}


func _connect_language_signal() -> void:
	if ProgressData == null or not ProgressData.has_signal("language_changed"):
		return
	if not ProgressData.is_connected("language_changed", self, "_on_language_changed"):
		var _err = ProgressData.connect("language_changed", self, "_on_language_changed")


func _on_language_changed() -> void:
	# Normally the tables are already loaded. If the selected table was missing at
	# startup, changing language also triggers an immediate retry instead of leaving
	# every custom control permanently on the English fallback.
	_reload_missing_translations(true)
	_log_status("language_changed")


func _reload_missing_translations(force: bool, replace_existing: bool = false) -> void:
	var now = OS.get_ticks_msec()
	if not force and now - _last_retry_msec < RETRY_INTERVAL_MSEC:
		return
	_last_retry_msec = now

	for language_code in TRANSLATION_FILES.keys():
		if not replace_existing and _has_translation_table(str(language_code)):
			continue
		var result = _load_translation_table(str(language_code))
		var table = result.get("table", {})
		if typeof(table) == TYPE_DICTIONARY and not table.empty():
			_translations[language_code] = table
			_translation_paths[language_code] = str(result.get("path", ""))

	_log_status("reload")


func _load_translation_table(language_code: String) -> Dictionary:
	var relative_path = str(TRANSLATION_FILES.get(language_code, ""))
	for mod_root in _get_mod_root_paths():
		var file_path = str(mod_root).plus_file(relative_path)
		var table = _parse_translation_file(file_path)
		if not table.empty():
			return {"table": table, "path": file_path}
	return {"table": {}, "path": ""}


func _get_mod_root_paths() -> Array:
	var paths = []

	var parent = get_parent()
	if parent != null:
		var parent_mod_path = str(parent.get("mod_dir_path"))
		_add_unique_path(paths, parent_mod_path)

	var script_res = get_script()
	if script_res != null:
		var resource_path = str(script_res.resource_path)
		if resource_path != "":
			_add_unique_path(paths, resource_path.get_base_dir().get_base_dir())

	_add_unique_path(paths, ModLoaderMod.get_unpacked_dir().plus_file("six666-BrotatoOnline"))
	_add_unique_path(paths, "res://mods-unpacked/six666-BrotatoOnline")
	return paths


func _add_unique_path(paths: Array, path: String) -> void:
	path = path.strip_edges()
	if path == "" or paths.has(path):
		return
	paths.append(path)


func _has_translation_table(language_code: String) -> bool:
	if not _translations.has(language_code):
		return false
	if typeof(_translations[language_code]) != TYPE_DICTIONARY:
		return false
	return not _translations[language_code].empty()


func _has_all_translation_tables() -> bool:
	for language_code in TRANSLATION_FILES.keys():
		if not _has_translation_table(str(language_code)):
			return false
	return true


func _get_entry_counts() -> Dictionary:
	var counts = {}
	for language_code in TRANSLATION_FILES.keys():
		var table = _translations.get(language_code, {})
		counts[language_code] = table.size() if typeof(table) == TYPE_DICTIONARY else 0
	return counts


func _log_status(reason: String) -> void:
	var counts = _get_entry_counts()
	var status_key = str(counts) + "|" + str(_translation_paths) + "|" + str(TranslationServer.get_locale())
	if reason == "reload" and status_key == _last_status_key:
		return
	_last_status_key = status_key
	print(
		"[BrotatoOnlineI18n] marker=", I18N_BUILD_MARKER,
		" reason=", reason,
		" locale=", TranslationServer.get_locale(),
		" language=", get_language_code(),
		" entries=", counts,
		" paths=", _translation_paths
	)


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
		# Also tolerate a UTF-8 BOM at the beginning of the first header/key.
		if line_index == 1 and key.begins_with("﻿"):
			key = key.substr(1, key.length() - 1)
		if key == "" or (line_index == 1 and key.to_lower() == "key"):
			continue

		var text = line.substr(separator + 1, line.length() - separator - 1)
		if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
			text = text.substr(1, text.length() - 2).replace("\"\"", "\"")
		out[key] = text.replace("\\n", "\n")

	file.close()
	return out
