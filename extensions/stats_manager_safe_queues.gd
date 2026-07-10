extends "res://global/stats_manager.gd"

# BrotatoOnline safety extension.
# Vanilla StatsManager keeps delayed recalculation queues whose object keys can become
# invalid after host-authoritative replica cleanup. Remove only unusable keys first,
# then use the vanilla implementation whenever the remaining entries have the normal
# StatsManager interfaces. The local fallback is reserved for malformed-but-live keys.


func _physics_process(_delta: float) -> void:
	_brotato_online_sanitize_all_stat_queues("physics_pre")
	if _brotato_online_can_use_vanilla_stat_queues():
		._physics_process(_delta)
		return
	_brotato_online_process_stat_queues_safely()


func _brotato_online_can_use_vanilla_stat_queues() -> bool:
	for player in _player_queue.keys():
		if player.get("dead") == null or not player.has_method("update_player_stats"):
			return false

	for weapon in _weapon_queue.keys():
		if not weapon.has_method("init_stats"):
			return false

	for player_structure_queue in _structure_queues:
		if typeof(player_structure_queue) != TYPE_DICTIONARY:
			return false
		for structure in player_structure_queue.keys():
			var structure_filename = structure.get("filename")
			if structure.get("dead") == null or structure.get("is_cursed") == null or structure_filename == null:
				return false
			if str(structure_filename) == "" or structure.get("stats") == null:
				return false
			if not structure.has_method("reload_data") or not structure.has_method("set_current_stats"):
				return false

	for player_pet_queue in _pet_queues:
		if typeof(player_pet_queue) != TYPE_DICTIONARY:
			return false
		for pet in player_pet_queue.keys():
			var pet_filename = pet.get("filename")
			if pet.get("dead") == null or pet.get("is_cursed") == null or pet_filename == null:
				return false
			if str(pet_filename) == "":
				return false
			if not pet.has_method("reload_data") or not pet.has_method("set_current_stats") or not pet.has_method("get_stats"):
				return false

	return true


func _brotato_online_process_stat_queues_safely() -> void:
	for player in _player_queue.keys():
		if _brotato_online_should_drop_queue_key(player):
			_player_queue.erase(player)
			continue
		if not bool(player.get("dead")) and player.has_method("update_player_stats"):
			player.update_player_stats()
	_player_queue.clear()

	_current_frame = Engine.get_physics_frames()
	_brotato_online_dequeue_weapons_safely()
	_brotato_online_dequeue_structures_safely()
	_brotato_online_dequeue_pets_safely()


func _brotato_online_dequeue_weapons_safely() -> void:
	var count: int = 0
	for weapon in _weapon_queue.keys():
		if _brotato_online_should_drop_queue_key(weapon):
			_weapon_queue.erase(weapon)
			count += 1
			continue
		if _should_recalc_item(int(_weapon_queue.get(weapon, _current_frame)), count):
			count += 1
			if is_instance_valid(weapon) and weapon.has_method("init_stats"):
				weapon.init_stats(false)
			_weapon_queue.erase(weapon)
		else:
			break


func _brotato_online_dequeue_structures_safely() -> void:
	for player_structure_queue in _structure_queues:
		if typeof(player_structure_queue) != TYPE_DICTIONARY:
			continue
		var structure_cache = {}
		var count: int = 0

		for structure in player_structure_queue.keys():
			if _brotato_online_should_drop_queue_key(structure):
				player_structure_queue.erase(structure)
				count += 1
				continue

			var is_dead = bool(structure.get("dead"))
			if not is_dead:
				var is_cursed = bool(structure.get("is_cursed"))
				var filename = str(structure.get("filename"))
				if not is_cursed:
					if filename != "" and structure_cache.has(filename):
						if structure.has_method("set_current_stats"):
							structure.set_current_stats(structure_cache[filename])
						count += 1
						player_structure_queue.erase(structure)
					elif _should_recalc_item(int(player_structure_queue.get(structure, _current_frame)), count):
						if structure.has_method("reload_data"):
							structure.reload_data()
						if filename != "":
							structure_cache[filename] = structure.get("stats")
						count += 1
						player_structure_queue.erase(structure)
				elif _should_recalc_item(int(player_structure_queue.get(structure, _current_frame)), count):
					if structure.has_method("reload_data"):
						structure.reload_data()
					count += 1
					player_structure_queue.erase(structure)
			else:
				count += 1
				player_structure_queue.erase(structure)


func _brotato_online_dequeue_pets_safely() -> void:
	for player_pet_queue in _pet_queues:
		if typeof(player_pet_queue) != TYPE_DICTIONARY:
			continue
		var recalced_pets = []
		var pet_cache = {}

		for pet in player_pet_queue.keys():
			if _brotato_online_should_drop_queue_key(pet):
				recalced_pets.append(pet)
				continue

			var is_dead = bool(pet.get("dead"))
			if not is_dead:
				var is_cursed = bool(pet.get("is_cursed"))
				var filename = str(pet.get("filename"))
				if not is_cursed:
					if filename != "" and pet_cache.has(filename):
						if pet.has_method("set_current_stats"):
							pet.set_current_stats(pet_cache[filename])
						recalced_pets.append(pet)
					elif _should_recalc_item(int(player_pet_queue.get(pet, _current_frame)), recalced_pets.size()):
						if pet.has_method("reload_data"):
							pet.reload_data()
						if filename != "" and pet.has_method("get_stats"):
							pet_cache[filename] = pet.get_stats()
						recalced_pets.append(pet)
				elif _should_recalc_item(int(player_pet_queue.get(pet, _current_frame)), recalced_pets.size()):
					if pet.has_method("reload_data"):
						pet.reload_data()
					recalced_pets.append(pet)
			else:
				recalced_pets.append(pet)

		for pet in recalced_pets:
			player_pet_queue.erase(pet)


func _brotato_online_sanitize_all_stat_queues(_reason: String) -> void:
	_brotato_online_sanitize_queue_dict(_player_queue)
	_brotato_online_sanitize_queue_dict(_weapon_queue)
	_brotato_online_sanitize_queue_array(_structure_queues)
	_brotato_online_sanitize_queue_array(_pet_queues)


func _brotato_online_sanitize_queue_array(queues) -> int:
	if typeof(queues) != TYPE_ARRAY:
		return 0
	var removed = 0
	for queue in queues:
		removed += _brotato_online_sanitize_queue_dict(queue)
	return removed


func _brotato_online_sanitize_queue_dict(queue) -> int:
	if typeof(queue) != TYPE_DICTIONARY:
		return 0
	var removed = 0
	for key in queue.keys():
		if _brotato_online_should_drop_queue_key(key):
			queue.erase(key)
			removed += 1
	return removed


func _brotato_online_should_drop_queue_key(key) -> bool:
	if key == null or typeof(key) != TYPE_OBJECT:
		return true
	if not is_instance_valid(key):
		return true
	if key is Node and key.is_queued_for_deletion():
		return true
	return false
