extends Reference

# Pure production queue scheduler. SteamLobbyManager owns the actual Steam call;
# this class owns ordering, fairness, limits, retries and reconnect cleanup.

const PRIORITY_CONTROL = 0
const PRIORITY_EVENT = 1
const PRIORITY_REPLACEABLE = 2
const PRIORITY_TRANSIENT = 3

var max_pending_per_peer = 48
var max_pending_total = 192
var max_pending_age_msec = 15000
var retry_delay_msec = 100

var _queues = {}
var _peer_order = []
var _cursor = 0
var _total_count = 0


func _init(per_peer_limit: int = 48, total_limit: int = 192, age_limit_msec: int = 15000, retry_msec: int = 100) -> void:
	max_pending_per_peer = max(1, per_peer_limit)
	max_pending_total = max(max_pending_per_peer, total_limit)
	max_pending_age_msec = max(1, age_limit_msec)
	retry_delay_msec = max(1, retry_msec)


func enqueue(packet: Dictionary) -> bool:
	if typeof(packet) != TYPE_DICTIONARY:
		return false
	var peer_id = str(packet.get("target_steam_id", ""))
	if peer_id == "" or peer_id == "0":
		return false
	var channel = int(packet.get("channel", 0))
	var priority = int(packet.get("priority", PRIORITY_EVENT))
	var coalesce_key = str(packet.get("coalesce_key", ""))
	if _count_for_peer(peer_id) >= max_pending_per_peer or _total_count >= max_pending_total:
		if not reserve_capacity(peer_id, 1, priority):
			return false
	# Replace only after capacity has been secured. A rejected replacement must
	# leave the previous coalesced state available for delivery.
	# Chunk batches set preserve_coalesce_group and remove their old group in the
	# manager only after the batch reservation succeeds.
	if coalesce_key != "" and not bool(packet.get("preserve_coalesce_group", false)):
		_drop_coalesced(peer_id, channel, coalesce_key)
	var stored = packet.duplicate(true)
	stored["target_steam_id"] = peer_id
	stored["channel"] = channel
	stored["priority"] = priority
	stored["queued_msec"] = int(stored.get("queued_msec", 0))
	stored["next_send_msec"] = int(stored.get("next_send_msec", stored["queued_msec"]))
	stored["retry_count"] = int(stored.get("retry_count", 0))
	var key = _queue_key(peer_id, channel)
	if not _queues.has(key):
		_queues[key] = []
	_queues[key].append(stored)
	_total_count += 1
	if not _peer_order.has(peer_id):
		_peer_order.append(peer_id)
	return true


func take_next_ready(now_msec: int, blocked_peer_channels: Dictionary = {}) -> Dictionary:
	_prune_expired(now_msec)
	_compact_peer_order()
	if _peer_order.empty():
		return {}
	if _cursor >= _peer_order.size():
		_cursor = 0
	var peer_count = _peer_order.size()
	for offset in range(peer_count):
		var peer_index = (_cursor + offset) % peer_count
		var peer_id = str(_peer_order[peer_index])
		var selected_key = _select_ready_queue_for_peer(peer_id, now_msec, blocked_peer_channels)
		if selected_key == "":
			continue
		var queue = _queues[selected_key]
		var entry = queue.pop_front()
		_total_count -= 1
		entry["_scheduler_queue_key"] = selected_key
		_cursor = (peer_index + 1) % max(1, peer_count)
		return entry
	return {}


func report_success(_entry: Dictionary) -> void:
	pass


func report_failure(entry: Dictionary, now_msec: int) -> void:
	if typeof(entry) != TYPE_DICTIONARY or entry.empty():
		return
	var peer_id = str(entry.get("target_steam_id", ""))
	var channel = int(entry.get("channel", 0))
	if peer_id == "" or peer_id == "0":
		return
	entry.erase("_scheduler_queue_key")
	entry["retry_count"] = int(entry.get("retry_count", 0)) + 1
	entry["next_send_msec"] = now_msec + retry_delay_msec
	var key = _queue_key(peer_id, channel)
	if not _queues.has(key):
		_queues[key] = []
	_queues[key].push_front(entry)
	_total_count += 1
	if not _peer_order.has(peer_id):
		_peer_order.append(peer_id)


func drop_stale_for_connection(peer_id: String, generation: int, nonce: String) -> int:
	var removed = 0
	for key in _queues.keys():
		if not str(key).begins_with(peer_id + "|"):
			continue
		var queue = _queues[key]
		for index in range(queue.size() - 1, -1, -1):
			var entry = queue[index]
			if int(entry.get("connection_generation", 0)) != generation or str(entry.get("connection_nonce", "")) != nonce:
				queue.remove(index)
				_total_count -= 1
				removed += 1
	_compact_peer_order()
	return removed


func clear_peer(peer_id: String) -> int:
	var removed = 0
	for key in _queues.keys():
		if str(key).begins_with(peer_id + "|"):
			removed += _queues[key].size()
			_queues.erase(key)
	_total_count = max(0, _total_count - removed)
	_compact_peer_order()
	return removed


func clear() -> void:
	_queues.clear()
	_peer_order.clear()
	_cursor = 0
	_total_count = 0


func size() -> int:
	return _total_count


func count_for_peer(peer_id: String) -> int:
	return _count_for_peer(peer_id)


func has_pending(peer_id: String, channel: int = -1) -> bool:
	if channel >= 0:
		var key = _queue_key(peer_id, channel)
		return _queues.has(key) and not _queues[key].empty()
	return _count_for_peer(peer_id) > 0


func drop_coalesced(peer_id: String, channel: int, coalesce_key: String) -> int:
	return _drop_coalesced(peer_id, channel, coalesce_key)


func reserve_capacity(peer_id: String, count: int, priority: int) -> bool:
	if peer_id == "" or peer_id == "0" or count <= 0 or count > max_pending_per_peer or count > max_pending_total:
		return false
	var peer_shortage = max(0, _count_for_peer(peer_id) + count - max_pending_per_peer)
	var global_shortage = max(0, _total_count + count - max_pending_total)
	if peer_shortage <= 0 and global_shortage <= 0:
		return true
	if priority != PRIORITY_CONTROL:
		return false
	var planned = {}
	if peer_shortage > 0:
		if _plan_lower_priority_evictions(peer_id, peer_shortage, planned) < peer_shortage:
			return false
	# Preferred-peer removals also create global room. Recompute the remaining
	# global shortage before considering unrelated peers.
	global_shortage = max(0, _total_count - _planned_eviction_count(planned) + count - max_pending_total)
	if global_shortage > 0:
		if _plan_lower_priority_evictions("", global_shortage, planned) < global_shortage:
			return false
	_apply_planned_evictions(planned)
	_compact_peer_order()
	return true


func prune_expired(now_msec: int) -> int:
	var before = _total_count
	_prune_expired(now_msec)
	_compact_peer_order()
	return before - _total_count


func _queue_key(peer_id: String, channel: int) -> String:
	return peer_id + "|" + str(channel)


func _count_for_peer(peer_id: String) -> int:
	var count = 0
	for key in _queues.keys():
		if str(key).begins_with(peer_id + "|"):
			count += _queues[key].size()
	return count


func _drop_coalesced(peer_id: String, channel: int, coalesce_key: String) -> int:
	var key = _queue_key(peer_id, channel)
	if not _queues.has(key):
		return 0
	var queue = _queues[key]
	var removed = 0
	for index in range(queue.size() - 1, -1, -1):
		if str(queue[index].get("coalesce_key", "")) == coalesce_key:
			queue.remove(index)
			_total_count -= 1
			removed += 1
	return removed


func _plan_lower_priority_evictions(peer_id: String, needed: int, planned: Dictionary) -> int:
	var added = 0
	for priority in [PRIORITY_TRANSIENT, PRIORITY_REPLACEABLE, PRIORITY_EVENT]:
		for key_value in _queues.keys():
			var key = str(key_value)
			if peer_id != "" and not key.begins_with(peer_id + "|"):
				continue
			var queue = _queues[key_value]
			for index in range(queue.size() - 1, -1, -1):
				if _is_planned_eviction(planned, key, index):
					continue
				if int(queue[index].get("priority", PRIORITY_EVENT)) != priority:
					continue
				if not planned.has(key):
					planned[key] = []
				planned[key].append(index)
				added += 1
				if added >= needed:
					return added
	return added


func _is_planned_eviction(planned: Dictionary, key: String, index: int) -> bool:
	return planned.has(key) and planned[key].has(index)


func _planned_eviction_count(planned: Dictionary) -> int:
	var count = 0
	for key in planned.keys():
		count += planned[key].size()
	return count


func _apply_planned_evictions(planned: Dictionary) -> void:
	for key in planned.keys():
		if not _queues.has(key):
			continue
		var indices = planned[key]
		indices.sort()
		indices.invert()
		for index in indices:
			if int(index) >= 0 and int(index) < _queues[key].size():
				_queues[key].remove(int(index))
				_total_count -= 1


func _select_ready_queue_for_peer(peer_id: String, now_msec: int, blocked_peer_channels: Dictionary) -> String:
	var selected_key = ""
	var selected_priority = 999
	for key in _queues.keys():
		var key_string = str(key)
		if not key_string.begins_with(peer_id + "|") or blocked_peer_channels.has(key_string):
			continue
		var queue = _queues[key]
		if queue.empty():
			continue
		var head = queue[0]
		if int(head.get("next_send_msec", 0)) > now_msec:
			continue
		var priority = int(head.get("priority", PRIORITY_EVENT))
		if selected_key == "" or priority < selected_priority or (priority == selected_priority and key_string < selected_key):
			selected_key = key_string
			selected_priority = priority
	return selected_key


func _prune_expired(now_msec: int) -> void:
	for key in _queues.keys():
		var queue = _queues[key]
		for index in range(queue.size() - 1, -1, -1):
			var queued_msec = int(queue[index].get("queued_msec", now_msec))
			if now_msec - queued_msec > max_pending_age_msec:
				queue.remove(index)
				_total_count -= 1


func _compact_peer_order() -> void:
	for index in range(_peer_order.size() - 1, -1, -1):
		if _count_for_peer(str(_peer_order[index])) <= 0:
			_peer_order.remove(index)
	if _peer_order.empty():
		_cursor = 0
	elif _cursor >= _peer_order.size():
		_cursor = 0
