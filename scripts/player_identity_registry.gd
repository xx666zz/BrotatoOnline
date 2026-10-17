extends Reference

# Persistence only. Transport connections and input devices never enter this table.
const SAVE_KEY = "bo_player_identity"
const SCHEMA_VERSION = 1
var run_id = ""
var slots = []


static func random_id() -> String:
	return Crypto.new().generate_random_bytes(32).hex_encode()


static func is_random_id(value) -> bool:
	if typeof(value) != TYPE_STRING or value.length() != 64:
		return false
	for character in value:
		if not character in "0123456789abcdef":
			return false
	return true


func load_metadata(metadata, player_count: int) -> bool:
	if typeof(metadata) != TYPE_DICTIONARY or metadata.get("version", 0) != SCHEMA_VERSION:
		return false
	var incoming = metadata.get("slots", [])
	if not is_random_id(metadata.get("run_id", "")) or typeof(incoming) != TYPE_ARRAY:
		return false
	if incoming.size() != player_count or player_count < 1 or player_count > 4:
		return false
	var seen_slots = []
	var seen_owners = []
	var next_slots = []
	for entry in incoming:
		if typeof(entry) != TYPE_DICTIONARY:
			return false
		var slot_id = entry.get("slot_id", "")
		var owner = str(entry.get("owner_id", ""))
		var local_slot = int(entry.get("local_slot", -1))
		if typeof(entry.get("owner_id", null)) != TYPE_STRING or entry.get("local_slot", -1) != local_slot:
			return false
		if not is_random_id(slot_id) or seen_slots.has(slot_id) or owner == "" or owner == "0" or local_slot < 0 or local_slot > 3:
			return false
		if owner.begins_with("lan:"):
			if not is_random_id(owner.substr(4)):
				return false
		elif not owner.is_valid_integer() or int(owner) <= 0:
			return false
		var owner_slot = owner + ":" + str(local_slot)
		if seen_owners.has(owner_slot):
			return false
		var proof_hash = str(entry.get("resume_hash", ""))
		if proof_hash != "" and not is_random_id(proof_hash):
			return false
		seen_slots.append(slot_id)
		seen_owners.append(owner_slot)
		next_slots.append({"slot_id": slot_id, "owner_id": owner, "local_slot": local_slot, "resume_hash": proof_hash})
	run_id = metadata.run_id
	slots = next_slots
	return true


func assign(owners: Array, hashes: Dictionary = {}) -> void:
	if run_id == "":
		run_id = random_id()
	var next_slots = []
	for index in range(owners.size()):
		var owner = str(owners[index].owner_id)
		# Reassignment changes ownership, never the saved character's slot identity.
		var slot_id = slots[index].slot_id if index < slots.size() else random_id()
		next_slots.append({"slot_id": slot_id, "owner_id": owner, "local_slot": int(owners[index].local_slot), "resume_hash": str(hashes.get(owner, ""))})
	slots = next_slots


func metadata(indices: Array = []) -> Dictionary:
	var selected = slots.duplicate(true)
	if not indices.empty():
		selected = []
		for index in indices:
			if int(index) < 0 or int(index) >= slots.size():
				return {}
			selected.append(slots[int(index)].duplicate(true))
	return {"version": SCHEMA_VERSION, "run_id": run_id, "slots": selected}


func compact(kept: Array) -> void:
	slots = metadata(kept).get("slots", [])


func index_for_owner(owner: String, local_slot: int = 0) -> int:
	for index in range(slots.size()):
		if str(slots[index].owner_id) == owner and int(slots[index].local_slot) == local_slot:
			return index
	return -1


func lan_proof_valid(owner: String, token: String) -> bool:
	if not is_random_id(token):
		return false
	var index = index_for_owner(owner)
	return index >= 0 and str(slots[index].resume_hash) != "" and str(slots[index].resume_hash) == token.sha256_text()
