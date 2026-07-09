extends Node

# Locates runtime nodes in main.tscn. It does not change Brotato gameplay logic.

const ENABLE_RUNTIME_DIAGNOSTIC_LOG = false

var _last_runtime_log_key = ""


func _ready() -> void:
	set_process(true)


func _process(_delta: float) -> void:
	if not ENABLE_RUNTIME_DIAGNOSTIC_LOG:
		return
	if not is_in_game_scene():
		return
	_log_runtime_once()


func is_in_game_scene() -> bool:
	var scene = get_tree().current_scene
	if scene == null:
		return false

	var filename = str(scene.filename)
	if filename == "res://main.tscn":
		return true

	return scene.name == "Main"


func get_main() -> Node:
	var scene = get_tree().current_scene
	if scene != null:
		var filename = str(scene.filename)
		if filename == "res://main.tscn" or scene.name == "Main":
			return scene

	return get_node_or_null("/root/Main")


func get_entities_container() -> Node:
	var main = get_main()
	if main == null:
		return null

	var stored = main.get("_entities_container")
	if _is_valid_runtime_node(stored):
		return stored

	var node = main.get_node_or_null("Entities")
	if node != null:
		return node

	return main.get_node_or_null("%Entities")


func get_births_container() -> Node:
	var main = get_main()
	if main == null:
		return null

	var stored = main.get("_births_container")
	if _is_valid_runtime_node(stored):
		return stored

	var node = main.get_node_or_null("Births")
	if node != null:
		return node

	return main.get_node_or_null("%Births")


func get_entity_spawner() -> Node:
	var main = get_main()
	if main == null:
		return null

	var node = main.get_node_or_null("EntitySpawner")
	if node != null:
		return node

	var stored = main.get("_entity_spawner")
	if stored != null and is_instance_valid(stored) and stored is Node:
		return stored

	return null


func get_wave_manager() -> Node:
	var main = get_main()
	if main == null:
		return null

	var node = main.get_node_or_null("WaveManager")
	if node != null:
		return node

	var stored = main.get("_wave_manager")
	if stored != null and is_instance_valid(stored) and stored is Node:
		return stored

	return null

func get_players() -> Array:
	var players = []
	var spawner = get_entity_spawner()
	if spawner != null:
		var spawner_players = spawner.get("_players")
		if typeof(spawner_players) == TYPE_ARRAY:
			for player in spawner_players:
				if _is_valid_runtime_node(player):
					players.append(player)

	if players.size() > 0:
		return players

	var main = get_main()
	if main != null:
		var main_players = main.get("_players")
		if typeof(main_players) == TYPE_ARRAY:
			for player_from_main in main_players:
				if _is_valid_runtime_node(player_from_main):
					players.append(player_from_main)

	return players

func get_enemy_nodes() -> Array:
	var result = []
	_append_valid_nodes(result, _get_spawner_array("enemies"))
	return result


func get_bosses() -> Array:
	var result = []
	_append_valid_nodes(result, _get_spawner_array("bosses"))
	return result


func get_neutrals() -> Array:
	var result = []
	_append_valid_nodes(result, _get_spawner_array("neutrals"))
	return result


func get_structures() -> Array:
	var result = []
	_append_valid_nodes(result, _get_spawner_array("structures"))
	return result


func get_pets() -> Array:
	var result = []
	_append_valid_nodes(result, _get_spawner_array("pets"))
	return result


func get_births() -> Array:
	var result = []
	var births_container = get_births_container()
	if births_container == null:
		return result

	for child in births_container.get_children():
		if _is_valid_runtime_node(child) and not _has_meta_true(child, "brotato_online_replica_birth"):
			result.append(child)
	return result


func get_entity_counts() -> Dictionary:
	var spawner = get_entity_spawner()
	if spawner == null:
		return {
			"players": get_players().size(),
			"enemies": 0,
			"bosses": 0,
			"neutrals": 0,
			"trees": 0,
			"births": 0,
			"structures": 0,
			"pets": 0
		}

	var neutral_count = _array_size(spawner.get("neutrals"))
	return {
		"players": get_players().size(),
		"enemies": _array_size(spawner.get("enemies")),
		"bosses": _array_size(spawner.get("bosses")),
		"neutrals": neutral_count,
		"trees": neutral_count,
		"births": int(spawner.get("active_births")),
		"structures": _array_size(spawner.get("structures")),
		"pets": _array_size(spawner.get("pets"))
	}


func _get_spawner_array(property_name: String):
	var spawner = get_entity_spawner()
	if spawner == null:
		return []
	return spawner.get(property_name)


func _append_valid_nodes(target: Array, value) -> void:
	if typeof(value) != TYPE_ARRAY:
		return

	for node in value:
		if _is_valid_runtime_node(node):
			target.append(node)


func _array_size(value) -> int:
	if typeof(value) == TYPE_ARRAY:
		return value.size()
	return 0


func _is_valid_runtime_node(node) -> bool:
	return node != null and is_instance_valid(node) and node is Node and not node.is_queued_for_deletion() and node.is_inside_tree()


func _has_meta_true(node: Node, key: String) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.has_meta(key):
		return false
	return bool(node.get_meta(key))


func _log_runtime_once() -> void:
	var main = get_main()
	var spawner = get_entity_spawner()
	var entities = get_entities_container()
	var counts = get_entity_counts()
	var key = str(main != null) + "|" + str(spawner != null) + "|" + str(entities != null) + "|" + str(counts.get("players", 0)) + "|" + str(counts.get("enemies", 0)) + "|" + str(counts.get("neutrals", 0)) + "|" + str(counts.get("pets", 0))
	if key == _last_runtime_log_key:
		return

	_last_runtime_log_key = key
