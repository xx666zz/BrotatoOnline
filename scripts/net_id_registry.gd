extends Node

# Host-side stable net_id assignment for active runtime entities.
# Important: get_instance_id() is only used locally to remember a currently active node.
# Network messages must use the assigned net_id, not get_instance_id().


var _next_dynamic_id = 1
var _net_id_by_instance = {}
var _instance_by_net_id = {}
var _prefix_by_net_id = {}
var _last_seen_msec_by_net_id = {}


func _ready() -> void:
	pass


func get_player_net_id(player_index: int) -> String:
	return "player_%s" % str(player_index)


func get_or_assign_net_id(node: Node, prefix: String) -> String:
	if node == null or not is_instance_valid(node):
		return ""

	var instance_key = str(node.get_instance_id())
	if _net_id_by_instance.has(instance_key):
		var existing_id = str(_net_id_by_instance[instance_key])
		_last_seen_msec_by_net_id[existing_id] = OS.get_ticks_msec()
		return existing_id

	var net_id = "%s_%06d" % [prefix, _next_dynamic_id]
	_next_dynamic_id += 1

	_net_id_by_instance[instance_key] = net_id
	_instance_by_net_id[net_id] = instance_key
	_prefix_by_net_id[net_id] = prefix
	_last_seen_msec_by_net_id[net_id] = OS.get_ticks_msec()

	return net_id


func reserve_net_id(prefix: String) -> String:
	if prefix == "":
		prefix = "entity"
	var net_id = "%s_%06d" % [prefix, _next_dynamic_id]
	_next_dynamic_id += 1
	_prefix_by_net_id[net_id] = prefix
	_last_seen_msec_by_net_id[net_id] = OS.get_ticks_msec()
	return net_id


func get_existing_net_id(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	var instance_key = str(node.get_instance_id())
	if _net_id_by_instance.has(instance_key):
		var existing_id = str(_net_id_by_instance[instance_key])
		_last_seen_msec_by_net_id[existing_id] = OS.get_ticks_msec()
		return existing_id
	return ""


func bind_net_id(node: Node, net_id: String, prefix: String) -> String:
	if node == null or not is_instance_valid(node) or net_id == "":
		return ""
	if prefix == "":
		prefix = "entity"
	var instance_key = str(node.get_instance_id())
	if _net_id_by_instance.has(instance_key):
		var old_id = str(_net_id_by_instance[instance_key])
		if old_id != net_id:
			_instance_by_net_id.erase(old_id)
			_prefix_by_net_id.erase(old_id)
			_last_seen_msec_by_net_id.erase(old_id)
	if _instance_by_net_id.has(net_id):
		var old_instance_key = str(_instance_by_net_id[net_id])
		if old_instance_key != instance_key:
			_net_id_by_instance.erase(old_instance_key)
	_net_id_by_instance[instance_key] = net_id
	_instance_by_net_id[net_id] = instance_key
	_prefix_by_net_id[net_id] = prefix
	_last_seen_msec_by_net_id[net_id] = OS.get_ticks_msec()
	return net_id


func mark_seen(net_id: String) -> void:
	if net_id == "":
		return
	_last_seen_msec_by_net_id[net_id] = OS.get_ticks_msec()


func purge_missing(active_net_ids: Dictionary) -> Array:
	var removed = []
	var ids = _instance_by_net_id.keys()
	for net_id_value in ids:
		var net_id = str(net_id_value)
		if active_net_ids.has(net_id):
			continue

		removed.append(net_id)
		var instance_key = str(_instance_by_net_id[net_id])
		_instance_by_net_id.erase(net_id)
		_prefix_by_net_id.erase(net_id)
		_last_seen_msec_by_net_id.erase(net_id)
		_net_id_by_instance.erase(instance_key)

	return removed


func reset() -> void:
	_next_dynamic_id = 1
	_net_id_by_instance.clear()
	_instance_by_net_id.clear()
	_prefix_by_net_id.clear()
	_last_seen_msec_by_net_id.clear()

