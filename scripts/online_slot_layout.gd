extends Reference


static func preserve_local_slots(players: Array, remote_devices: Array, remote_device_map: Dictionary = {}) -> Array:
	var known_remote_devices = remote_devices.duplicate()
	for device_key in remote_device_map.keys():
		var mapped_device = int(device_key)
		if not known_remote_devices.has(mapped_device):
			known_remote_devices.append(mapped_device)
	var result = []
	for player in players:
		if typeof(player) != TYPE_ARRAY or player.size() < 2:
			continue
		var device = int(player[0])
		if known_remote_devices.has(device):
			continue
		result.append([device, int(player[1])])
	return result


static func clear_for_offline_continue(_players: Array) -> Array:
	# CoopResume owns the next join. Keeping the former client's local device here
	# makes the saved P2 slot look already occupied, so no fresh input can join.
	return []
