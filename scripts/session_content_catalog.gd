extends Reference

# Resource presence is independent of DLC ownership and local unlock progress.
# Keep the complete loadable catalog read-only; register only a Host run's data.
const META_KEY = "brotato_online_session_content"
const KINDS = ["characters", "items", "weapons"]
const EXTRA_ITEM_FIELDS = ["meca_items", "mutant_items", "evolution_items"]
const DLC_RESOURCE_LISTS = {"backgrounds": "backgrounds", "title_screen_backgrounds": "title_screen_backgrounds", "entities_items": "entities", "effect_scripts": "effects"}

var _configuration_key = ""
var _added_resources = {}


func get_loadable_catalog() -> Dictionary:
	var result = {"characters": [], "items": [], "weapons": []}
	for kind in KINDS:
		_append_unique_data(result[kind], ItemService.get(kind))
	_collect_item_set(ItemService.base_game_item_set, result)
	for update in ItemService.update_data_list:
		if _is_loadable_update(update):
			_collect_item_set(update.item_set, result)
	return result


func get_locally_owned_characters(loadable_characters: Array) -> Array:
	var blocked_ids = {}
	for update in ItemService.update_data_list:
		if not _is_loadable_update(update) or update.update_type != UpdateData.UpdateType.DLC:
			continue
		if ProgressData.available_dlc_ids.has(update.id):
			continue
		for character in update.item_set.characters:
			if character != null:
				blocked_ids[str(character.my_id)] = true
	var result = []
	for character in loadable_characters:
		if not blocked_ids.has(str(character.my_id)):
			result.append(character)
	return result


func apply(enabled: Array, active_updates: Array) -> Dictionary:
	var result = {"characters": [], "items": [], "weapons": [], "enabled_dlcs": [], "active_update_data_ids": []}
	var selected = []
	for update in ItemService.update_data_list:
		if not _is_loadable_update(update):
			continue
		var dlc_enabled = update.update_type == UpdateData.UpdateType.DLC and enabled.has(update.id)
		if active_updates.has(update.id):
			# A Host cannot activate DLC contents absent from its enabled DLC list.
			if update.update_type != UpdateData.UpdateType.DLC or dlc_enabled:
				result.active_update_data_ids.append(update.id)
		if dlc_enabled:
			result.enabled_dlcs.append(update.id)
		if dlc_enabled or result.active_update_data_ids.has(update.id):
			selected.append(update)
			_collect_item_set(update.item_set, result)
	var key = to_json([result.enabled_dlcs, result.active_update_data_ids])
	if key == _configuration_key and ItemService.has_meta(META_KEY):
		result["changed"] = false
		return result
	_remove_added_resources()
	for update in selected:
		if update.update_type == UpdateData.UpdateType.DLC:
			_register_dlc_resources(update.dlc_data)
	_configuration_key = key
	ItemService.set_meta(META_KEY, result.duplicate())
	_invalidate_catalogs()
	result["changed"] = true
	return result


func restore() -> void:
	_configuration_key = ""
	_remove_added_resources()
	if ItemService.has_meta(META_KEY):
		ItemService.remove_meta(META_KEY)
		_invalidate_catalogs()


func _is_loadable_update(update) -> bool:
	return update != null and update.item_set != null and (update.update_type != UpdateData.UpdateType.DLC or update.dlc_data != null)


func _collect_item_set(item_set, result: Dictionary) -> void:
	if item_set == null:
		return
	for kind in KINDS:
		_append_unique_data(result[kind], item_set.get(kind))
	if item_set is PrimalDreadItemSetData:
		for field in EXTRA_ITEM_FIELDS:
			_append_unique_data(result.items, item_set.get(field))


func _append_unique_data(destination: Array, pool) -> void:
	if typeof(pool) != TYPE_ARRAY:
		return
	for data in pool:
		if data is ItemParentData and str(data.my_id) != "" and not destination.has(data):
			destination.append(data)


func _register_dlc_resources(dlc) -> void:
	# Match DLCData.add_resources without duplicating owned resources or changing
	# availability, unlocks, challenges, or saved progression.
	for source in DLC_RESOURCE_LISTS:
		var target = DLC_RESOURCE_LISTS[source]
		var pool = ItemService.get(target)
		for data in dlc.get(source):
			if data != null and not pool.has(data):
				pool.append(data)
				if not _added_resources.has(target):
					_added_resources[target] = []
				_added_resources[target].append(data)
	if _added_resources.has("backgrounds"):
		ItemService.emit_signal("backgrounds_updated")


func _remove_added_resources() -> void:
	var backgrounds_changed = _added_resources.has("backgrounds")
	for target in _added_resources:
		var pool = ItemService.get(target)
		for data in _added_resources[target]:
			pool.erase(data)
	_added_resources.clear()
	if backgrounds_changed:
		ItemService.emit_signal("backgrounds_updated")


func _invalidate_catalogs() -> void:
	ItemService.invalidate_items_cache()
	ItemService.invalidate_weapons_cache()
	ItemService.invalidate_characters_cache()
	# These id caches must not retain a previous Host's DLC resources or append
	# duplicate weapon tiers after a content switch.
	ItemService.set("_item_id_lookup", {})
	ItemService.set("_weapon_id_lookup", {})
	ItemService.set("_base_weapon_lookup", {})
