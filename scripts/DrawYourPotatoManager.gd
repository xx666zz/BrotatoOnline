extends Node

const LOG_NAME = "six666-DrawYourPotato"
const USER_ROOT = "user://custom_potatoes"
const SETTINGS_PATH = "user://custom_potatoes/settings.cfg"
const DEFAULT_PRESET = "default"
const SETTINGS_VERSION = 3
const ONLINE_MOD_ID = "six666_draw_your_potato"
const ONLINE_ROUTE_SKIN_UPDATE = "skin_update"
const ONLINE_ROUTE_SKIN_REQUEST = "skin_request"
const ONLINE_SYNC_OPTIONS = {"scope": "menu", "reliable": true}
const ONLINE_PROBE_INTERVAL_MS = 1000
const ONLINE_SYNC_DELAY_MS = 250
const BODY_SIZE = Vector2(150, 150)
const LEGS_SIZE = Vector2(100, 50)
const BODY_RESOLUTIONS = [Vector2(32, 32), Vector2(48, 48), Vector2(64, 64), Vector2(96, 96), Vector2(150, 150)]
const LEGS_RESOLUTIONS = [Vector2(32, 16), Vector2(48, 24), Vector2(64, 32), Vector2(100, 50)]

var mod_dir_path = ""
var enabled = true
var active_preset = DEFAULT_PRESET
var skip_character_appearances = true
var skip_item_appearances = false
var restrict_to_mask = true
var body_edit_size = Vector2(150, 150)
var legs_edit_size = Vector2(100, 50)
var palette = []

var _body_texture: ImageTexture = null
var _legs_texture: ImageTexture = null
var _textures_dirty = true
var _ui = null
var _translations = {}

var bo_api = null
var _bo_api_connected = false
var _remote_player_skins = {}
var _online_last_sent_signatures = {}
var _online_pending_sync = false
var _online_force_sync = false
var _online_last_probe_msec = 0
var _online_last_sync_msec = 0
var _online_was_active = false
var _online_last_request_msec = 0


func _ready() -> void:
	mod_dir_path = ModLoaderMod.get_unpacked_dir().plus_file("six666-DrawYourPotato")
	add_to_group("DrawYourPotatoManager")
	palette = _get_default_palette()
	_load_translations()
	_ensure_user_root()
	_load_settings()
	_ensure_preset(active_preset)
	set_process(true)
	call_deferred("_online_try_setup")
	call_deferred("_online_queue_sync", true)


func open_painter() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.queue_free()
		_ui = null

	var script_path = mod_dir_path.plus_file("Scripts/PainterUI.gd")
	var script_res = load(script_path)
	if script_res == null:
		ModLoaderLog.error("Failed to load painter ui: " + script_path, LOG_NAME)
		return

	_ui = script_res.new()
	_ui.setup(self, mod_dir_path)
	get_tree().root.add_child(_ui)


func close_painter(ui_ref) -> void:
	if _ui == ui_ref:
		_ui = null


func get_text(key: String) -> String:
	if _translations.has(key):
		var entry = _translations[key]
		if _is_chinese_locale():
			return str(entry.get("zh", key))
		return str(entry.get("en", key))
	return key


func get_presets() -> Array:
	_ensure_user_root()
	var result = []
	var dir = Directory.new()
	if dir.open(USER_ROOT) != OK:
		return [DEFAULT_PRESET]
	dir.list_dir_begin(true, true)
	var name = dir.get_next()
	while name != "":
		if dir.current_is_dir():
			result.push_back(name)
		name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	if not result.has(DEFAULT_PRESET):
		result.push_front(DEFAULT_PRESET)
	return result


func get_safe_preset_name(name: String) -> String:
	var cleaned = ""
	for i in range(name.length()):
		var c = name.substr(i, 1)
		var code = name.ord_at(i)
		var ok = false
		if code >= 48 and code <= 57:
			ok = true
		elif code >= 65 and code <= 90:
			ok = true
		elif code >= 97 and code <= 122:
			ok = true
		elif c == "_" or c == "-":
			ok = true
		elif code > 127 and c != "/" and c != "\\" and c != ":":
			ok = true
		if ok:
			cleaned += c
	if cleaned.empty():
		cleaned = DEFAULT_PRESET
	return cleaned


func set_active_preset(name: String) -> void:
	active_preset = get_safe_preset_name(name)
	_ensure_preset(active_preset)
	_mark_textures_dirty()
	_save_settings()
	_online_queue_sync(true)


func set_enabled(value: bool) -> void:
	enabled = value
	_mark_textures_dirty()
	_save_settings()
	_online_queue_sync(true)


func set_skip_item_appearances(value: bool) -> void:
	skip_item_appearances = value
	_save_settings()
	_online_queue_sync(true)


func set_restrict_to_mask(value: bool) -> void:
	restrict_to_mask = value
	_save_settings()


func set_body_edit_size(size: Vector2) -> void:
	body_edit_size = _sanitize_resolution(size, BODY_RESOLUTIONS, Vector2(150, 150))
	_save_settings()


func set_legs_edit_size(size: Vector2) -> void:
	legs_edit_size = _sanitize_resolution(size, LEGS_RESOLUTIONS, Vector2(100, 50))
	_save_settings()


func should_skip_appearance(appearance) -> bool:
	if not enabled:
		return false
	if appearance == null:
		return true
	if skip_character_appearances and appearance.is_character_appearance:
		return true
	if skip_item_appearances and not appearance.is_character_appearance:
		return true
	return false


func get_body_texture() -> Texture:
	_reload_textures_if_needed()
	return _body_texture


func get_legs_texture() -> Texture:
	_reload_textures_if_needed()
	return _legs_texture


func get_palette() -> Array:
	if palette.empty():
		palette = _get_default_palette()
	return palette


func add_palette_color(color: Color) -> void:
	get_palette()
	palette.push_back(color)
	_save_settings()


func remove_palette_color(index: int) -> bool:
	get_palette()
	if palette.size() <= 1:
		return false
	if index < 0 or index >= palette.size():
		return false
	palette.remove(index)
	_save_settings()
	return true


func load_edit_image(target: String, preset_name: String, edit_size: Vector2) -> Image:
	var out_size = _get_output_size(target)
	var path = _get_target_path(preset_name, target)
	var image = Image.new()
	var err = image.load(path)
	if err != OK:
		image = _get_base_image(target)
	if _image_is_empty(image):
		image = Image.new()
		image.create(int(out_size.x), int(out_size.y), false, Image.FORMAT_RGBA8)
	image.convert(Image.FORMAT_RGBA8)
	image.resize(int(edit_size.x), int(edit_size.y), Image.INTERPOLATE_NEAREST)
	return image


func get_mask_image(target: String, edit_size: Vector2) -> Image:
	var mask = _get_base_image(target)
	if _image_is_empty(mask):
		mask = Image.new()
		var out_size = _get_output_size(target)
		mask.create(int(out_size.x), int(out_size.y), false, Image.FORMAT_RGBA8)
	mask.convert(Image.FORMAT_RGBA8)
	mask.resize(int(edit_size.x), int(edit_size.y), Image.INTERPOLATE_NEAREST)
	return mask


func get_base_edit_image(target: String, edit_size: Vector2) -> Image:
	var image = _get_base_image(target)
	if _image_is_empty(image):
		var out_size = _get_output_size(target)
		image = Image.new()
		image.create(int(out_size.x), int(out_size.y), false, Image.FORMAT_RGBA8)
	image.convert(Image.FORMAT_RGBA8)
	image.resize(int(edit_size.x), int(edit_size.y), Image.INTERPOLATE_NEAREST)
	return image


func save_edit_image(target: String, preset_name: String, edit_image: Image) -> bool:
	if _image_is_empty(edit_image):
		return false
	var safe_name = get_safe_preset_name(preset_name)
	_ensure_preset(safe_name)
	var output_size = _get_output_size(target)
	var output = edit_image.duplicate()
	output.convert(Image.FORMAT_RGBA8)
	output.resize(int(output_size.x), int(output_size.y), Image.INTERPOLATE_NEAREST)
	var path = _get_target_path(safe_name, target)
	var err = output.save_png(path)
	if err != OK:
		ModLoaderLog.error("Failed to save custom potato image: " + path + " err=" + str(err), LOG_NAME)
		return false
	active_preset = safe_name
	_mark_textures_dirty()
	_save_settings()
	_online_queue_sync(true)
	return true


func save_meta(preset_name: String) -> void:
	var safe_name = get_safe_preset_name(preset_name)
	_ensure_user_root()
	var dir = Directory.new()
	var dir_path = _get_preset_dir(safe_name)
	if not dir.dir_exists(dir_path):
		dir.make_dir_recursive(dir_path)
	var cfg = ConfigFile.new()
	cfg.set_value("preset", "name", safe_name)
	cfg.set_value("preset", "body_edit_width", int(body_edit_size.x))
	cfg.set_value("preset", "body_edit_height", int(body_edit_size.y))
	cfg.set_value("preset", "legs_edit_width", int(legs_edit_size.x))
	cfg.set_value("preset", "legs_edit_height", int(legs_edit_size.y))
	cfg.set_value("preset", "restrict_to_mask", restrict_to_mask)
	cfg.set_value("preset", "skip_character_appearances", skip_character_appearances)
	cfg.set_value("preset", "skip_item_appearances", skip_item_appearances)
	cfg.save(_get_preset_dir(safe_name).plus_file("meta.cfg"))


func delete_preset(preset_name: String) -> bool:
	var safe_name = get_safe_preset_name(preset_name)
	if safe_name == DEFAULT_PRESET:
		return false
	var dir_path = _get_preset_dir(safe_name)
	var dir = Directory.new()
	if not dir.dir_exists(dir_path):
		return false
	var ok = _delete_dir_recursive(dir_path)
	if active_preset == safe_name:
		active_preset = DEFAULT_PRESET
		_ensure_preset(active_preset)
		_mark_textures_dirty()
		_save_settings()
	return ok


func get_target_edit_size(target: String) -> Vector2:
	if target == "legs":
		return legs_edit_size
	return body_edit_size


func set_target_edit_size(target: String, size: Vector2) -> void:
	if target == "legs":
		set_legs_edit_size(size)
	else:
		set_body_edit_size(size)


func get_target_resolutions(target: String) -> Array:
	if target == "legs":
		return LEGS_RESOLUTIONS
	return BODY_RESOLUTIONS


func _process(_delta: float) -> void:
	_online_process()


func has_custom_skin_for_player(player_index: int) -> bool:
	if _online_is_active():
		if _online_owns_player(player_index):
			return _local_has_custom_skin()
		if not _remote_player_skins.has(player_index):
			return false
		var skin = _remote_player_skins[player_index]
		if not bool(skin.get("enabled", false)):
			return false
		return skin.get("body_texture", null) != null or skin.get("legs_texture", null) != null
	return _local_has_custom_skin()


func get_body_texture_for_player(player_index: int) -> Texture:
	if _online_is_active() and not _online_owns_player(player_index):
		var skin = _remote_player_skins.get(player_index, null)
		if skin != null and bool(skin.get("enabled", false)):
			return skin.get("body_texture", null)
		return null
	return get_body_texture()


func get_legs_texture_for_player(player_index: int) -> Texture:
	if _online_is_active() and not _online_owns_player(player_index):
		var skin = _remote_player_skins.get(player_index, null)
		if skin != null and bool(skin.get("enabled", false)):
			return skin.get("legs_texture", null)
		return null
	return get_legs_texture()


func should_skip_appearance_for_player(player_index: int, appearance) -> bool:
	if _online_is_active() and not _online_owns_player(player_index):
		var skin = _remote_player_skins.get(player_index, null)
		if skin == null or not bool(skin.get("enabled", false)):
			return false
		if appearance == null:
			return true
		if bool(skin.get("skip_character_appearances", true)) and appearance.is_character_appearance:
			return true
		if bool(skin.get("skip_item_appearances", false)) and not appearance.is_character_appearance:
			return true
		return false
	return should_skip_appearance(appearance)


func _local_has_custom_skin() -> bool:
	return enabled


func _online_process() -> void:
	var now = OS.get_ticks_msec()
	if bo_api == null or not is_instance_valid(bo_api):
		if now - _online_last_probe_msec >= ONLINE_PROBE_INTERVAL_MS:
			_online_last_probe_msec = now
			_online_try_setup()
	elif not _bo_api_connected:
		_online_connect_api_signals()

	var active = _online_is_active()
	if active and not _online_was_active:
		_remote_player_skins.clear()
		_online_last_sent_signatures.clear()
		_online_queue_sync(true)
		_online_request_skins()
	_online_was_active = active

	if active and _online_pending_sync and now - _online_last_sync_msec >= ONLINE_SYNC_DELAY_MS:
		var force = _online_force_sync
		_online_pending_sync = false
		_online_force_sync = false
		_online_send_all_local_skins(force)


func _online_try_setup() -> void:
	var tree = get_tree()
	if tree == null:
		return
	var apis = tree.get_nodes_in_group("brotato_online_api")
	if apis.empty():
		return
	bo_api = apis[0]
	_online_connect_api_signals()
	_online_queue_sync(true)
	_online_request_skins()


func _online_connect_api_signals() -> void:
	if bo_api == null or not is_instance_valid(bo_api):
		return
	if bo_api.has_signal("mod_message_received") and not bo_api.is_connected("mod_message_received", self, "_on_bo_mod_message_received"):
		bo_api.connect("mod_message_received", self, "_on_bo_mod_message_received")
	if bo_api.has_signal("phase_changed") and not bo_api.is_connected("phase_changed", self, "_on_bo_phase_changed"):
		bo_api.connect("phase_changed", self, "_on_bo_phase_changed")
	if bo_api.has_signal("slot_layout_changed") and not bo_api.is_connected("slot_layout_changed", self, "_on_bo_slot_layout_changed"):
		bo_api.connect("slot_layout_changed", self, "_on_bo_slot_layout_changed")
	_bo_api_connected = true


func _online_is_active() -> bool:
	if bo_api == null or not is_instance_valid(bo_api):
		return false
	if not bo_api.has_method("is_online"):
		return false
	return bool(bo_api.is_online())


func _online_is_host() -> bool:
	if bo_api == null or not is_instance_valid(bo_api):
		return false
	if not bo_api.has_method("is_host"):
		return false
	return bool(bo_api.is_host())


func _online_owns_player(player_index: int) -> bool:
	if bo_api != null and is_instance_valid(bo_api) and bo_api.has_method("owns_player"):
		return bool(bo_api.owns_player(player_index))
	var local_players = _online_get_local_player_indices()
	return local_players.has(player_index)


func _online_get_local_player_indices() -> Array:
	if bo_api == null or not is_instance_valid(bo_api):
		return []
	if bo_api.has_method("get_local_player_indices"):
		var indices = bo_api.get_local_player_indices()
		if indices is Array:
			return indices
	if bo_api.has_method("get_context"):
		var context = bo_api.get_context()
		if context is Dictionary:
			var from_context = context.get("local_player_indices", [])
			if from_context is Array:
				return from_context
	return []


func _online_queue_sync(force: bool = false) -> void:
	_online_pending_sync = true
	if force:
		_online_force_sync = true


func _online_request_skins() -> void:
	if not _online_is_active():
		return
	var now = OS.get_ticks_msec()
	if now - _online_last_request_msec < 1000:
		return
	_online_last_request_msec = now
	if _online_is_host():
		bo_api.broadcast(ONLINE_MOD_ID, ONLINE_ROUTE_SKIN_REQUEST, {}, ONLINE_SYNC_OPTIONS)
	elif bo_api.has_method("send_to_host"):
		bo_api.send_to_host(ONLINE_MOD_ID, ONLINE_ROUTE_SKIN_REQUEST, {}, ONLINE_SYNC_OPTIONS)


func _online_send_all_local_skins(force: bool = false) -> void:
	if not _online_is_active():
		return
	var local_players = _online_get_local_player_indices()
	if local_players.empty():
		return
	for raw_index in local_players:
		var player_idx = int(raw_index)
		var payload = _online_build_skin_payload(player_idx)
		var signature = str(payload.get("signature", ""))
		if not force and _online_last_sent_signatures.get(player_idx, "") == signature:
			continue
		_online_last_sent_signatures[player_idx] = signature
		if _online_is_host():
			bo_api.broadcast(ONLINE_MOD_ID, ONLINE_ROUTE_SKIN_UPDATE, payload, ONLINE_SYNC_OPTIONS)
		elif bo_api.has_method("send_to_host"):
			bo_api.send_to_host(ONLINE_MOD_ID, ONLINE_ROUTE_SKIN_UPDATE, payload, ONLINE_SYNC_OPTIONS)
	_online_last_sync_msec = OS.get_ticks_msec()


func _online_build_skin_payload(player_idx: int) -> Dictionary:
	var body_png = ""
	var legs_png = ""
	if enabled:
		body_png = _online_read_png_base64("body")
		legs_png = _online_read_png_base64("legs")
	var signature = str(enabled) + "|" + str(skip_character_appearances) + "|" + str(skip_item_appearances) + "|" + str(body_png.hash()) + "|" + str(legs_png.hash())
	return {
		"player_index": player_idx,
		"enabled": enabled,
		"skip_character_appearances": skip_character_appearances,
		"skip_item_appearances": skip_item_appearances,
		"body_png": body_png,
		"legs_png": legs_png,
		"signature": signature
	}


func _online_read_png_base64(target: String) -> String:
	var path = _get_target_path(active_preset, target)
	var file = File.new()
	if not file.file_exists(path):
		return ""
	if file.open(path, File.READ) != OK:
		return ""
	var data = file.get_buffer(file.get_len())
	file.close()
	if data.size() <= 0:
		return ""
	return Marshalls.raw_to_base64(data)


func _on_bo_phase_changed(_old_phase, _new_phase, _context) -> void:
	_online_queue_sync(true)
	_online_request_skins()


func _on_bo_slot_layout_changed(_context) -> void:
	_online_queue_sync(true)
	_online_request_skins()


func _on_bo_mod_message_received(mod_id, route, payload, meta) -> void:
	if str(mod_id) != ONLINE_MOD_ID:
		return
	if route == ONLINE_ROUTE_SKIN_UPDATE:
		_online_receive_skin_update(payload, meta)
	elif route == ONLINE_ROUTE_SKIN_REQUEST:
		_online_send_all_local_skins(true)
		if _online_is_host():
			_online_broadcast_cached_remote_skins()


func _online_receive_skin_update(payload, meta) -> void:
	if not (payload is Dictionary):
		return
	var player_idx = int(payload.get("player_index", -1))
	if player_idx < 0:
		return
	if _online_owns_player(player_idx):
		return
	var signature = str(payload.get("signature", ""))
	var old_skin = _remote_player_skins.get(player_idx, null)
	if old_skin != null and str(old_skin.get("signature", "")) == signature:
		return

	var is_enabled = bool(payload.get("enabled", true))
	var body_tex = null
	var legs_tex = null
	if is_enabled:
		body_tex = _online_texture_from_base64(str(payload.get("body_png", "")))
		legs_tex = _online_texture_from_base64(str(payload.get("legs_png", "")))
	_remote_player_skins[player_idx] = {
		"enabled": is_enabled,
		"skip_character_appearances": bool(payload.get("skip_character_appearances", true)),
		"skip_item_appearances": bool(payload.get("skip_item_appearances", false)),
		"body_texture": body_tex,
		"legs_texture": legs_tex,
		"signature": signature,
		"raw_payload": payload.duplicate(true)
	}
	_apply_skin_to_existing_player(player_idx)

	if _online_is_host():
		bo_api.broadcast(ONLINE_MOD_ID, ONLINE_ROUTE_SKIN_UPDATE, payload, ONLINE_SYNC_OPTIONS)


func _online_broadcast_cached_remote_skins() -> void:
	if not _online_is_active() or not _online_is_host():
		return
	for player_idx in _remote_player_skins.keys():
		var skin = _remote_player_skins[player_idx]
		var payload = skin.get("raw_payload", null)
		if payload is Dictionary:
			bo_api.broadcast(ONLINE_MOD_ID, ONLINE_ROUTE_SKIN_UPDATE, payload, ONLINE_SYNC_OPTIONS)


func _online_texture_from_base64(value: String) -> ImageTexture:
	if value.empty():
		return null
	var data = Marshalls.base64_to_raw(value)
	if data.size() <= 0:
		return null
	var img = Image.new()
	if img.load_png_from_buffer(data) != OK:
		return null
	if _image_is_empty(img):
		return null
	img.convert(Image.FORMAT_RGBA8)
	var tex = ImageTexture.new()
	tex.create_from_image(img, 0)
	return tex


func _apply_skin_to_existing_player(player_idx: int) -> void:
	var tree = get_tree()
	if tree == null:
		return
	_apply_skin_to_existing_player_recursive(tree.root, player_idx)


func _apply_skin_to_existing_player_recursive(node: Node, player_idx: int) -> void:
	if node == null:
		return
	if node.has_method("_custom_potato_apply_textures"):
		var idx_value = node.get("player_index")
		if idx_value != null and int(idx_value) == player_idx:
			node.call("_custom_potato_apply_textures", self)
	for child in node.get_children():
		_apply_skin_to_existing_player_recursive(child, player_idx)


func _reload_textures_if_needed() -> void:
	if not _textures_dirty:
		return
	_textures_dirty = false
	_body_texture = _load_texture_from_png(_get_target_path(active_preset, "body"))
	_legs_texture = _load_texture_from_png(_get_target_path(active_preset, "legs"))


func _mark_textures_dirty() -> void:
	_textures_dirty = true
	_body_texture = null
	_legs_texture = null


func _load_texture_from_png(path: String) -> ImageTexture:
	if not enabled:
		return null
	var img = Image.new()
	if img.load(path) != OK:
		return null
	if _image_is_empty(img):
		return null
	img.convert(Image.FORMAT_RGBA8)
	var tex = ImageTexture.new()
	tex.create_from_image(img, 0)
	return tex


func _get_output_size(target: String) -> Vector2:
	if target == "legs":
		return LEGS_SIZE
	return BODY_SIZE


func _get_base_image(target: String) -> Image:
	var res_path = "res://entities/units/player/potato.png"
	if target == "legs":
		res_path = "res://entities/units/player/legs.png"
	var tex = load(res_path)
	if tex == null:
		return null
	var img = tex.get_data()
	if img == null:
		return null
	img = img.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _ensure_user_root() -> void:
	var dir = Directory.new()
	if not dir.dir_exists(USER_ROOT):
		dir.make_dir_recursive(USER_ROOT)


func _ensure_preset(preset_name: String) -> void:
	_ensure_user_root()
	var safe_name = get_safe_preset_name(preset_name)
	var dir_path = _get_preset_dir(safe_name)
	var dir = Directory.new()
	if not dir.dir_exists(dir_path):
		dir.make_dir_recursive(dir_path)
	_ensure_target_image(safe_name, "body")
	_ensure_target_image(safe_name, "legs")
	save_meta(safe_name)


func _ensure_target_image(preset_name: String, target: String) -> void:
	var path = _get_target_path(preset_name, target)
	var file = File.new()
	if file.file_exists(path):
		return
	var img = _get_base_image(target)
	if _image_is_empty(img):
		var size = _get_output_size(target)
		img = Image.new()
		img.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
	img.save_png(path)


func _get_preset_dir(preset_name: String) -> String:
	return USER_ROOT.plus_file(get_safe_preset_name(preset_name))


func _get_target_path(preset_name: String, target: String) -> String:
	if target == "legs":
		return _get_preset_dir(preset_name).plus_file("legs.png")
	return _get_preset_dir(preset_name).plus_file("body.png")


func _load_settings() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(SETTINGS_PATH)
	if err != OK:
		_save_settings()
		return
	var loaded_version = int(cfg.get_value("main", "settings_version", 0))
	enabled = bool(cfg.get_value("main", "enabled", enabled))
	active_preset = get_safe_preset_name(str(cfg.get_value("main", "active_preset", active_preset)))
	skip_character_appearances = bool(cfg.get_value("main", "skip_character_appearances", skip_character_appearances))
	skip_item_appearances = bool(cfg.get_value("main", "skip_item_appearances", skip_item_appearances))
	if loaded_version < 3:
		skip_item_appearances = false
	restrict_to_mask = bool(cfg.get_value("main", "restrict_to_mask", restrict_to_mask))
	body_edit_size = Vector2(int(cfg.get_value("main", "body_edit_width", int(body_edit_size.x))), int(cfg.get_value("main", "body_edit_height", int(body_edit_size.y))))
	legs_edit_size = Vector2(int(cfg.get_value("main", "legs_edit_width", int(legs_edit_size.x))), int(cfg.get_value("main", "legs_edit_height", int(legs_edit_size.y))))
	body_edit_size = _sanitize_resolution(body_edit_size, BODY_RESOLUTIONS, Vector2(150, 150))
	legs_edit_size = _sanitize_resolution(legs_edit_size, LEGS_RESOLUTIONS, Vector2(100, 50))
	palette = _parse_palette_string(str(cfg.get_value("palette", "colors", "")))
	if palette.empty():
		palette = _get_default_palette()
	if loaded_version < SETTINGS_VERSION:
		body_edit_size = Vector2(150, 150)
		legs_edit_size = Vector2(100, 50)
		_save_settings()


func _save_settings() -> void:
	_ensure_user_root()
	if palette.empty():
		palette = _get_default_palette()
	var cfg = ConfigFile.new()
	cfg.set_value("main", "settings_version", SETTINGS_VERSION)
	cfg.set_value("main", "enabled", enabled)
	cfg.set_value("main", "active_preset", active_preset)
	cfg.set_value("main", "skip_character_appearances", skip_character_appearances)
	cfg.set_value("main", "skip_item_appearances", skip_item_appearances)
	cfg.set_value("main", "restrict_to_mask", restrict_to_mask)
	cfg.set_value("main", "body_edit_width", int(body_edit_size.x))
	cfg.set_value("main", "body_edit_height", int(body_edit_size.y))
	cfg.set_value("main", "legs_edit_width", int(legs_edit_size.x))
	cfg.set_value("main", "legs_edit_height", int(legs_edit_size.y))
	cfg.set_value("palette", "colors", _palette_to_string(palette))
	cfg.save(SETTINGS_PATH)


func _image_is_empty(img) -> bool:
	if img == null:
		return true
	return img.get_width() <= 0 or img.get_height() <= 0


func _sanitize_resolution(size: Vector2, allowed: Array, fallback: Vector2) -> Vector2:
	for candidate in allowed:
		if int(candidate.x) == int(size.x) and int(candidate.y) == int(size.y):
			return candidate
	return fallback


func _delete_dir_recursive(path: String) -> bool:
	var success = true
	var dir = Directory.new()
	if dir.open(path) != OK:
		return false
	dir.list_dir_begin(true, true)
	var name = dir.get_next()
	while name != "":
		var child_path = path.plus_file(name)
		if dir.current_is_dir():
			if not _delete_dir_recursive(child_path):
				success = false
		else:
			if dir.remove(child_path) != OK:
				success = false
		name = dir.get_next()
	dir.list_dir_end()
	var parent = Directory.new()
	if parent.remove(path) != OK:
		success = false
	return success


func _get_default_palette() -> Array:
	return [
		Color(1, 1, 1, 1),
		Color(0, 0, 0, 1),
		Color(0.55, 0.55, 0.55, 1),
		Color(0.95, 0.78, 0.45, 1),
		Color(0.45, 0.25, 0.12, 1),
		Color(0.95, 0.22, 0.18, 1),
		Color(0.95, 0.45, 0.65, 1),
		Color(0.25, 0.8, 0.25, 1),
		Color(0.25, 0.55, 1, 1),
		Color(0.65, 0.35, 1, 1)
	]


func _palette_to_string(colors: Array) -> String:
	var out = ""
	for i in range(colors.size()):
		var c: Color = colors[i]
		if i > 0:
			out += "|"
		out += str(c.r) + "," + str(c.g) + "," + str(c.b) + "," + str(c.a)
	return out


func _parse_palette_string(value: String) -> Array:
	var result = []
	if value.strip_edges().empty():
		return result
	var entries = value.split("|", false)
	for entry in entries:
		var parts = str(entry).split(",", false)
		if parts.size() < 3:
			continue
		var r = clamp(float(parts[0]), 0.0, 1.0)
		var g = clamp(float(parts[1]), 0.0, 1.0)
		var b = clamp(float(parts[2]), 0.0, 1.0)
		var a = 1.0
		if parts.size() >= 4:
			a = clamp(float(parts[3]), 0.0, 1.0)
		result.push_back(Color(r, g, b, a))
	return result


func _load_translations() -> void:
	_translations.clear()
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
		var key = str(cols[0]).strip_edges()
		_translations[key] = {"zh": str(cols[1]), "en": str(cols[2])}
	file.close()


func _is_chinese_locale() -> bool:
	var locale = TranslationServer.get_locale().to_lower()
	return locale.begins_with("zh")
