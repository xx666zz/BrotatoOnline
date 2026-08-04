extends Reference

# Production per-peer protocol state. This deliberately has no Steam or scene
# dependencies; SteamLobbyManager uses it for every real handshake and envelope.

const STATE_DISCONNECTED = "DISCONNECTED"
const STATE_RESYNCING = "RESYNCING"
const STATE_NEGOTIATING = "NEGOTIATING"
const STATE_SYNCING = "SYNCING"
const STATE_READY = "READY"
const STATE_FAILED = "FAILED"

var peer_id = ""
var connection_generation = 0
var connection_nonce = ""
var state = STATE_DISCONNECTED
var can_send_input = false
var last_revision = 0
var expected_revision = 0
var required_components = {}
var applied_components = {}
var last_sequence_by_stream = {}
var retired_nonces = {}
var mapping = {}
var _staged_full_state_messages = []


func _init(p_peer_id: String = "") -> void:
	peer_id = p_peer_id
	_reset_windows()


func begin_client_attempt(nonce: String) -> bool:
	if nonce == "":
		return false
	connection_nonce = nonce
	connection_generation = 0
	state = STATE_NEGOTIATING
	can_send_input = false
	_reset_windows()
	return true


func host_accept_hello(nonce: String, challenge_revision: int) -> Dictionary:
	if not _is_valid_connection_nonce(nonce):
		return {"accepted": false, "new_attempt": false, "generation": connection_generation, "reason": "INVALID_NONCE"}
	if challenge_revision <= 0:
		return {"accepted": false, "new_attempt": false, "generation": connection_generation, "reason": "INVALID_REVISION"}
	if retired_nonces.has(nonce):
		return {"accepted": false, "new_attempt": false, "generation": connection_generation, "reason": "RETIRED_NONCE"}
	if nonce == connection_nonce and connection_generation > 0:
		if state == STATE_FAILED:
			return {"accepted": false, "new_attempt": false, "generation": connection_generation, "reason": "NEW_NONCE_REQUIRED"}
		return {
			"accepted": true,
			"new_attempt": false,
			"already_ready": state == STATE_READY and can_send_input,
			"generation": connection_generation,
			"nonce": connection_nonce,
			"state_revision": expected_revision,
			"resend_phase": _idempotent_resend_phase()
		}
	if connection_nonce != "":
		retired_nonces[connection_nonce] = true
	connection_generation += 1
	connection_nonce = nonce
	state = STATE_NEGOTIATING
	can_send_input = false
	_reset_windows()
	expected_revision = challenge_revision
	return {
		"accepted": true,
		"new_attempt": true,
		"already_ready": false,
		"generation": connection_generation,
		"nonce": connection_nonce,
		"state_revision": expected_revision,
		"resend_phase": "challenge"
	}


func client_accept_challenge(nonce: String, generation: int, revision: int, player_index: int, slot_index: int, device_id: int) -> bool:
	if nonce == "" or nonce != connection_nonce or generation <= 0 or revision <= 0:
		return false
	if connection_generation > 0 and generation != connection_generation:
		return false
	if connection_generation > 0 and state != STATE_NEGOTIATING:
		if revision != expected_revision or (state != STATE_SYNCING and state != STATE_RESYNCING and state != STATE_READY):
			return false
		mapping = {
			"player_index": player_index,
			"slot_index": slot_index,
			"device_id": device_id
		}
		return true
	connection_generation = generation
	expected_revision = revision
	mapping = {
		"player_index": player_index,
		"slot_index": slot_index,
		"device_id": device_id
	}
	state = STATE_NEGOTIATING
	can_send_input = false
	return true


func host_accept_confirm(nonce: String, generation: int, revision: int) -> bool:
	if nonce == "" or nonce != connection_nonce or generation != connection_generation or revision != expected_revision:
		return false
	if state != STATE_NEGOTIATING and state != STATE_SYNCING:
		return false
	state = STATE_SYNCING
	can_send_input = false
	return true


func begin_full_state(nonce: String, generation: int, revision: int, components: Array) -> bool:
	if nonce == "" or nonce != connection_nonce or generation != connection_generation or revision <= 0:
		return false
	if expected_revision <= 0 or revision != expected_revision:
		return false
	if state != STATE_NEGOTIATING and state != STATE_SYNCING and state != STATE_RESYNCING:
		return false
	required_components.clear()
	applied_components.clear()
	for component in components:
		var component_name = str(component)
		if component_name != "":
			required_components[component_name] = true
	state = STATE_SYNCING
	can_send_input = false
	return true


func mark_full_state_component(nonce: String, generation: int, component: String) -> bool:
	return mark_full_state_component_revision(nonce, generation, expected_revision, component)


func mark_full_state_component_revision(nonce: String, generation: int, revision: int, component: String) -> bool:
	if nonce != connection_nonce or generation != connection_generation or state != STATE_SYNCING:
		return false
	if revision <= 0 or revision != expected_revision:
		return false
	if component == "" or not required_components.has(component):
		return false
	applied_components[component] = true
	return true


func can_ack_full_state(nonce: String, generation: int, revision: int) -> bool:
	if nonce != connection_nonce or generation != connection_generation or revision != expected_revision or state != STATE_SYNCING:
		return false
	for component in required_components.keys():
		if not applied_components.has(component):
			return false
	return true


func host_accept_ack(nonce: String, generation: int, revision: int) -> bool:
	if state == STATE_READY and can_send_input and nonce == connection_nonce and generation == connection_generation and revision == expected_revision and revision == last_revision:
		return true
	if not can_ack_full_state(nonce, generation, revision):
		return false
	last_revision = revision
	state = STATE_READY
	can_send_input = true
	return true


func client_receive_complete(nonce: String, generation: int, revision: int) -> bool:
	if nonce != connection_nonce or generation != connection_generation or revision != expected_revision:
		return false
	if not can_ack_full_state(nonce, generation, revision):
		return false
	last_revision = revision
	state = STATE_READY
	can_send_input = true
	return true


func apply_periodic_revision(revision: int) -> bool:
	if revision <= 0 or revision < last_revision:
		return false
	last_revision = revision
	return true


func validate_envelope(message: Dictionary, expected: Dictionary) -> Dictionary:
	if int(message.get("protocol_version", 0)) != int(expected.get("protocol_version", 0)):
		return {"accepted": false, "reason": "PROTOCOL_MISMATCH"}
	var message_lobby = str(message.get("session_lobby_id", message.get("lobby_id", "")))
	if message_lobby == "" or message_lobby != str(expected.get("lobby_id", "")):
		return {"accepted": false, "reason": "LOBBY_MISMATCH"}
	if str(message.get("game_host_steam_id", "")) != str(expected.get("host_steam_id", "")):
		return {"accepted": false, "reason": "HOST_MISMATCH"}
	if str(message.get("sender_steam_id", "")) != str(expected.get("sender_steam_id", "")):
		return {"accepted": false, "reason": "SENDER_MISMATCH"}
	var generation = int(message.get("connection_generation", 0))
	if generation <= 0 or generation != connection_generation:
		return {"accepted": false, "reason": "GENERATION_MISMATCH"}
	if message.has("session_epoch") and int(message.get("session_epoch", 0)) != generation:
		return {"accepted": false, "reason": "EPOCH_MISMATCH"}
	if str(message.get("connection_nonce", "")) == "" or str(message.get("connection_nonce", "")) != connection_nonce:
		return {"accepted": false, "reason": "NONCE_MISMATCH"}
	return {"accepted": true, "reason": ""}


func accept_stream_sequence(origin: String, stream: String, sequence: int) -> bool:
	if origin == "" or stream == "" or sequence <= 0:
		return false
	var key = origin + "|" + stream
	var previous = int(last_sequence_by_stream.get(key, 0))
	if sequence <= previous:
		return false
	last_sequence_by_stream[key] = sequence
	return true


func next_outbound_stream_sequence(origin: String, stream: String) -> int:
	if origin == "" or stream == "":
		return 0
	var key = origin + "|" + stream
	var sequence = int(last_sequence_by_stream.get(key, 0)) + 1
	last_sequence_by_stream[key] = sequence
	return sequence


func validate_chunk_metadata(chunk_count: int, original_bytes: int, active_peer_assemblies: int, active_total_assemblies: int) -> Dictionary:
	if chunk_count <= 1 or chunk_count > 48:
		return {"accepted": false, "reason": "CHUNK_COUNT_LIMIT"}
	if original_bytes <= 0 or original_bytes > 2 * 1024 * 1024:
		return {"accepted": false, "reason": "MESSAGE_SIZE_LIMIT"}
	if active_peer_assemblies >= 4:
		return {"accepted": false, "reason": "PEER_ASSEMBLY_LIMIT"}
	if active_total_assemblies >= 12:
		return {"accepted": false, "reason": "GLOBAL_ASSEMBLY_LIMIT"}
	return {"accepted": true, "reason": "OK"}


func stage_full_state_messages(nonce: String, generation: int, revision: int, messages: Array) -> bool:
	if nonce != connection_nonce or generation != connection_generation or revision != expected_revision or state != STATE_SYNCING:
		return false
	if messages.empty():
		return false
	_staged_full_state_messages = messages.duplicate(true)
	return true


func has_staged_full_state_messages() -> bool:
	return not _staged_full_state_messages.empty()


func peek_full_state_message() -> Dictionary:
	if _staged_full_state_messages.empty():
		return {}
	return _staged_full_state_messages[0].duplicate(true)


func mark_full_state_message_sent() -> bool:
	if _staged_full_state_messages.empty():
		return false
	_staged_full_state_messages.pop_front()
	return true


func cancel_staged_full_state_messages() -> void:
	_staged_full_state_messages.clear()


func _idempotent_resend_phase() -> String:
	if state == STATE_READY and can_send_input:
		return "complete"
	if state == STATE_SYNCING or state == STATE_RESYNCING:
		return "full_state"
	return "challenge"


func _is_valid_connection_nonce(nonce: String) -> bool:
	if nonce.length() != 32:
		return false
	for index in range(nonce.length()):
		var code = nonce.ord_at(index)
		var decimal = code >= 48 and code <= 57
		var lower_hex = code >= 97 and code <= 102
		var upper_hex = code >= 65 and code <= 70
		if not decimal and not lower_hex and not upper_hex:
			return false
	return true


func clear_transport() -> void:
	_reset_windows()
	state = STATE_DISCONNECTED
	can_send_input = false
	mapping.clear()


func _reset_windows() -> void:
	last_revision = 0
	expected_revision = 0
	required_components.clear()
	applied_components.clear()
	last_sequence_by_stream.clear()
	_staged_full_state_messages.clear()
