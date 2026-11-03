extends Reference

var _base_states = {}
var _fingerprints = {}

func fingerprint(data) -> String:
	if data == null or not data.has_method("serialize"):
		return ""
	var id = data.get_instance_id()
	var signature = str(data.is_cursed) + ":" + str(data.is_meca) + ":" + str(data.is_mutant) + ":" + str(hash(data.effects)) + ":" + str(data.value) + ":" + str(data.tier)
	if data is WeaponData:
		signature += ":" + str(data.meca_rank) + ":" + str(data.meca_power)
	var cached = _fingerprints.get(id, {})
	if not cached.empty() and cached.owner.get_ref() == data and str(cached.signature) == signature:
		return str(cached.value)
	var state = data.serialize()
	for key in ["is_locked", "dmg_dealt_last_wave", "tracked_value", "tracked_value_added_this_wave"]:
		state.erase(key)
	var scripts = []
	for effect in data.effects:
		scripts.append(str(effect.get_script().resource_path) if effect != null and effect.get_script() != null else "")
	state["effect_scripts"] = scripts
	var value = JSON.print(state, "", true).sha256_text()
	_fingerprints[id] = {"owner": weakref(data), "signature": signature, "value": value}
	return value

func invalidate_player(player_index: int) -> void:
	if player_index < 0 or player_index >= RunData.get_player_count():
		return
	for data in RunData.get_player_items(player_index) + RunData.get_player_weapons(player_index):
		if data != null:
			_fingerprints.erase(data.get_instance_id())

func can_compact(state: Dictionary) -> bool:
	if bool(state.get("is_cursed", false)) or bool(state.get("is_meca", false)) or bool(state.get("is_mutant", false)) or state.has("serialized_data"):
		return false
	var id = str(state.get("my_id", ""))
	if not _base_states.has(id):
		var base = ItemService.get_element_safe(ItemService.items, id)
		if base == null or base is CharacterData:
			return false
		_base_states[id] = _compact_signature(base.serialize())
	return _compact_signature(state) == _base_states[id]

func _compact_signature(state: Dictionary) -> String:
	var relevant = {}
	for key in ["effects", "mutation_removed_effects", "replaced_by", "tags", "item_appearances"]:
		relevant[key] = state.get(key, null)
	return JSON.print(relevant, "", true)

func clear() -> void:
	_base_states.clear()
	_fingerprints.clear()
