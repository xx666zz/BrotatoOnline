extends "res://global/stats_manager.gd"

# BrotatoOnline safety extension.
# Vanilla StatsManager delays player/weapon/structure/pet stat recalculation in dictionaries.
# On an online client the host-authoritative replica layer can remove local structures/pets
# before those delayed queues are dequeued. Vanilla then reads `dead` on a previously freed
# instance and crashes. Sanitize the queue keys before any property access.




func _dict_size(value) -> int:
	if typeof(value) == TYPE_DICTIONARY:
		return value.size()
	return 0


func _queue_array_size(value) -> int:
	if typeof(value) != TYPE_ARRAY:
		return 0
	var total = 0
	for queue in value:
		if typeof(queue) == TYPE_DICTIONARY:
			total += queue.size()
	return total

func _dequeue_weapons() -> void:
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


func _dequeue_structures() -> void:
	for player_structure_queue in _structure_queues:
		if typeof(player_structure_queue) != TYPE_DICTIONARY:
			continue
		var structure_cache = {}
		var count: int = 0

		for struct in player_structure_queue.keys():
			if _brotato_online_should_drop_queue_key(struct):
				player_structure_queue.erase(struct)
				count += 1
				continue

			var is_dead = bool(struct.get("dead"))
			if not is_dead:
				var is_cursed = bool(struct.get("is_cursed"))
				var filename = str(struct.get("filename"))
				if not is_cursed:
					if filename != "" and structure_cache.has(filename):
						if struct.has_method("set_current_stats"):
							struct.set_current_stats(structure_cache[filename])
						count += 1
						player_structure_queue.erase(struct)
					elif _should_recalc_item(int(player_structure_queue.get(struct, _current_frame)), count):
						if struct.has_method("reload_data"):
							struct.reload_data()
						if filename != "":
							structure_cache[filename] = struct.get("stats")
						count += 1
						player_structure_queue.erase(struct)
				elif _should_recalc_item(int(player_structure_queue.get(struct, _current_frame)), count):
					if struct.has_method("reload_data"):
						struct.reload_data()
					count += 1
					player_structure_queue.erase(struct)
			else:
				count += 1
				player_structure_queue.erase(struct)


func _dequeue_pets() -> void:
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


func _brotato_online_sanitize_all_stat_queues(reason: String) -> void:
	var removed = 0
	removed += _brotato_online_sanitize_queue_dict(_player_queue)
	removed += _brotato_online_sanitize_queue_dict(_weapon_queue)
	removed += _brotato_online_sanitize_queue_array(_structure_queues)
	removed += _brotato_online_sanitize_queue_array(_pet_queues)
	if removed > 0 and _brotato_online_is_online_session_active():
		pass


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
	if key == null:
		return true
	if typeof(key) != TYPE_OBJECT:
		return true
	if not is_instance_valid(key):
		return true
	if key is Node and key.is_queued_for_deletion():
		return true
	return false


func _brotato_online_is_online_session_active() -> bool:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return false
	return bool(tree.root.get_meta("brotato_online_session_active", false))

func _physics_process(_delta: float) -> void:
	_brotato_online_sanitize_all_stat_queues("physics_pre")

	for player in _player_queue.keys():
		if _brotato_online_should_drop_queue_key(player):
			_player_queue.erase(player)
			continue
		if not bool(player.get("dead")) and player.has_method("update_player_stats"):
			player.update_player_stats()
	_player_queue.clear()

	_current_frame = Engine.get_physics_frames()
	_dequeue_weapons()
	_dequeue_structures()
	_dequeue_pets()
