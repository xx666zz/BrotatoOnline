extends Node

# Upgrade runtime-effect synchronization helper shared by menu progression state
# and battle/progression snapshots. All wire fields are optional so peers that do
# not know about the runtime metadata simply ignore it.

const PROPERTY_USAGE_STORAGE_BIT = 1

var _effect_property_cache = {}


func serialize_upgrade_effect_state(upgrade_data) -> Array:
	if upgrade_data == null or not (upgrade_data is UpgradeData):
		return []
	var effects = upgrade_data.get("effects")
	if typeof(effects) != TYPE_ARRAY:
		return []
	var result = []
	for i in range(effects.size()):
		var effect = effects[i]
		if effect == null or typeof(effect) != TYPE_OBJECT:
			result.append({"index": i, "properties": {}})
			continue
		var properties = {}
		for property_info in _get_syncable_effect_properties(effect):
			var property_name = str(property_info.get("name", ""))
			if property_name == "":
				continue
			var encoded = _encode_wire_value(effect.get(property_name), 0)
			if bool(encoded.get("ok", false)):
				properties[property_name] = encoded.get("value", null)

		# Exported Resource fields (WeaponStats, BurningData, explosion stats, etc.)
		# cannot be represented by the generic property overlay. Effect subclasses
		# already expose serialize()/deserialize_and_merge() specifically for these
		# nested runtime resources, so include that native wire-safe state when possible.
		var serialized_effect = null
		if effect.has_method("serialize"):
			var raw_serialized = effect.call("serialize")
			if typeof(raw_serialized) == TYPE_DICTIONARY:
				var encoded_serialized = _encode_wire_value(raw_serialized, 0)
				if bool(encoded_serialized.get("ok", false)):
					serialized_effect = encoded_serialized.get("value", null)

		var entry = {
			"index": i,
			"resource_path": _get_resource_path(effect),
			"script_path": _get_script_path(effect),
			"properties": properties
		}
		if serialized_effect != null:
			entry["serialized_effect"] = serialized_effect
		result.append(entry)
	return result


func apply_upgrade_effect_state(upgrade_data, effect_state) -> void:
	if upgrade_data == null or not (upgrade_data is UpgradeData):
		return
	if typeof(effect_state) != TYPE_ARRAY:
		return
	var base_effects = upgrade_data.get("effects")
	if typeof(base_effects) != TYPE_ARRAY:
		return
	# Runtime upgrades from another peer can have a different Effect subclass and even
	# a different effect count than the locally rolled option in the same slot. Rebuild
	# each entry from its resource/script identity when available, then overlay the
	# wire-safe properties. This prevents a plain Effect from receiving a specialized
	# key such as effect_reduce_stat_gains without its required stat_displayed field.
	var effects = base_effects.duplicate()
	for entry in effect_state:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var index = int(entry.get("index", -1))
		if index < 0:
			continue
		while effects.size() <= index:
			effects.append(null)
		var base_effect = effects[index]
		var properties = entry.get("properties", {})
		if typeof(properties) != TYPE_DICTIONARY:
			properties = {}
		var effect_copy = _make_effect_copy_for_entry(base_effect, entry, properties)
		if effect_copy == null:
			continue

		# Restore the Effect subclass's own serialized state first. This is what
		# rebuilds nested Resource members that a script.new() instance does not have,
		# e.g. CapybaraProjectileOnHit.weapon_stats / burning_stats. Without it the
		# description renderer immediately calls WeaponService with a null WeaponStats.
		var serialized_effect = entry.get("serialized_effect", null)
		if typeof(serialized_effect) == TYPE_DICTIONARY and effect_copy.has_method("deserialize_and_merge"):
			effect_copy.call("deserialize_and_merge", serialized_effect)

		# Keep the generic exported-property overlay as the final authority. It covers
		# Effects that do not extend serialize(), and preserves compatibility with
		# older senders that only provide properties/script metadata.
		var property_types = _get_effect_property_types(effect_copy)
		for property_name in properties.keys():
			var name = str(property_name)
			if not property_types.has(name):
				continue
			var value = _coerce_wire_value(properties[property_name], int(property_types[name]))
			effect_copy.set(name, value)

		# Effect subclasses keep runtime-only derived fields (key_hash, custom_key_hash,
		# tracking_key, etc.) outside the exported/storage property list. A script.new()
		# schedules _generate_hashes() deferred, which is too late because UpgradeUI renders
		# the effect immediately in the same call stack. Recompute them synchronously after
		# the Host properties have been overlaid. This also fixes stale hashes when a local
		# same-class slot is reused but the Host changed `key` at runtime.
		_refresh_effect_runtime_fields(effect_copy)
		effects[index] = effect_copy
	# Never hand a literal null to vanilla EffectLine._display_effect(), which calls
	# get_text()/get_icon() immediately. Selection authority remains position-based.
	var sanitized_effects = []
	for effect in effects:
		if effect != null and typeof(effect) == TYPE_OBJECT:
			sanitized_effects.append(effect)
	upgrade_data.set("effects", sanitized_effects)


func _refresh_effect_runtime_fields(effect) -> void:
	if effect == null or typeof(effect) != TYPE_OBJECT:
		return
	# Effect._generate_hashes() regenerates key_hash/custom_key_hash, and subclasses
	# extend it for their own derived runtime keys (for example
	# ChanceStatDamageEffect.tracking_key). It is safe here because effect is always a
	# private duplicate/new instance created for the synchronized UpgradeData.
	if effect.has_method("_generate_hashes"):
		effect.call("_generate_hashes")


func _make_effect_copy_for_entry(base_effect, entry: Dictionary, properties: Dictionary):
	var wanted_resource_path = str(entry.get("resource_path", ""))
	if wanted_resource_path != "" and ResourceLoader.exists(wanted_resource_path):
		var loaded_effect = load(wanted_resource_path)
		if loaded_effect != null:
			return loaded_effect.duplicate() if loaded_effect.has_method("duplicate") else loaded_effect

	var wanted_script_path = str(entry.get("script_path", ""))
	if wanted_script_path != "":
		if base_effect != null and _get_script_path(base_effect) == wanted_script_path:
			return base_effect.duplicate() if base_effect.has_method("duplicate") else base_effect
		var created = _new_effect_from_script_path(wanted_script_path)
		if created != null:
			return created

	# Mixed-version fallback: older senders do not include script_path. Infer the two
	# vanilla effect subclasses whose base Effect.get_icon() requires subclass-only
	# display fields. This keeps old/new peers from crashing on these common cases.
	var legacy_script_path = _infer_legacy_effect_script_path(properties)
	if legacy_script_path != "" and (base_effect == null or _get_script_path(base_effect) != legacy_script_path):
		var legacy_created = _new_effect_from_script_path(legacy_script_path)
		if legacy_created != null:
			return legacy_created

	if base_effect != null and typeof(base_effect) == TYPE_OBJECT:
		return base_effect.duplicate() if base_effect.has_method("duplicate") else base_effect
	return null


func _new_effect_from_script_path(script_path: String):
	if script_path == "" or not ResourceLoader.exists(script_path):
		return null
	var effect_script = load(script_path)
	if effect_script == null or not (effect_script is Script):
		return null
	var created = effect_script.new()
	if created == null or typeof(created) != TYPE_OBJECT:
		return null
	return created


func _infer_legacy_effect_script_path(properties: Dictionary) -> String:
	var key = str(properties.get("key", ""))
	if key == "effect_increase_stat_gains" or key == "effect_reduce_stat_gains":
		return "res://effects/items/stat_gains_modification_effect.gd"
	if key == "effect_weapon_class_bonus":
		return "res://effects/items/class_bonus_effect.gd"
	return ""


func _get_resource_path(resource) -> String:
	if resource == null or not (resource is Resource):
		return ""
	return str(resource.resource_path)


func _get_script_path(effect) -> String:
	if effect == null or typeof(effect) != TYPE_OBJECT or not effect.has_method("get_script"):
		return ""
	var script_res = effect.get_script()
	if script_res == null or not is_instance_valid(script_res):
		return ""
	return str(script_res.resource_path)


func _get_syncable_effect_properties(effect) -> Array:
	var cache_key = _get_effect_cache_key(effect)
	var cached = _effect_property_cache.get(cache_key, null)
	if cached != null and typeof(cached) == TYPE_ARRAY:
		return cached
	var result = []
	if effect == null or not effect.has_method("get_property_list"):
		_effect_property_cache[cache_key] = result
		return result
	for property_info in effect.get_property_list():
		if typeof(property_info) != TYPE_DICTIONARY:
			continue
		var property_name = str(property_info.get("name", ""))
		if _should_skip_property_name(property_name):
			continue
		var usage = int(property_info.get("usage", 0))
		if (usage & PROPERTY_USAGE_STORAGE_BIT) == 0:
			continue
		result.append({
			"name": property_name,
			"type": int(property_info.get("type", TYPE_NIL))
		})
	_effect_property_cache[cache_key] = result
	return result


func _get_effect_property_types(effect) -> Dictionary:
	var result = {}
	for property_info in _get_syncable_effect_properties(effect):
		result[str(property_info.get("name", ""))] = int(property_info.get("type", TYPE_NIL))
	return result


func _get_effect_cache_key(effect) -> String:
	if effect == null:
		return "null"
	var script_res = effect.get_script() if effect.has_method("get_script") else null
	if script_res != null and is_instance_valid(script_res):
		return "script:" + str(script_res.get_instance_id())
	return "class:" + str(effect.get_class() if effect.has_method("get_class") else typeof(effect))


func _should_skip_property_name(property_name: String) -> bool:
	return property_name == "" \
		or property_name == "resource_name" \
		or property_name == "resource_path" \
		or property_name == "resource_local_to_scene" \
		or property_name == "script"


func _encode_wire_value(value, depth: int) -> Dictionary:
	if depth > 4:
		return {"ok": false}
	var value_type = typeof(value)
	if value_type == TYPE_NIL or value_type == TYPE_BOOL or value_type == TYPE_INT or value_type == TYPE_REAL or value_type == TYPE_STRING:
		return {"ok": true, "value": value}
	if value_type == TYPE_ARRAY:
		var array_value = []
		for child in value:
			var encoded_child = _encode_wire_value(child, depth + 1)
			if not bool(encoded_child.get("ok", false)):
				return {"ok": false}
			array_value.append(encoded_child.get("value", null))
		return {"ok": true, "value": array_value}
	if value_type == TYPE_DICTIONARY:
		var dict_value = {}
		for child_key in value.keys():
			if typeof(child_key) != TYPE_STRING:
				return {"ok": false}
			var encoded_value = _encode_wire_value(value[child_key], depth + 1)
			if not bool(encoded_value.get("ok", false)):
				return {"ok": false}
			dict_value[str(child_key)] = encoded_value.get("value", null)
		return {"ok": true, "value": dict_value}
	return {"ok": false}


func _coerce_wire_value(value, target_type: int):
	if target_type == TYPE_BOOL:
		return bool(value)
	if target_type == TYPE_INT:
		return int(value)
	if target_type == TYPE_REAL:
		return float(value)
	if target_type == TYPE_STRING:
		return str(value)
	return value
