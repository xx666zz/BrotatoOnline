extends SceneTree

var _failures = []
var _source_root = ""


func _init() -> void:
	_source_root = OS.get_environment("BO_SOURCE_ROOT")
	if _source_root == "":
		_source_root = "/workspace"

	_test_protocol_attempt_identity_and_handshake()
	_test_protocol_envelope_and_stream_invariants()
	_test_network_send_scheduler_behavior()
	_test_steam_callback_driver_switching()
	_test_protocol_config()
	_test_focus_control_guard_rejects_off_tree_controls()
	_test_shop_focus_target_fallback_policy()
	_test_focus_application_policy()
	_test_online_slot_reset_preserves_local_layout()
	_test_host_proxy_death_cleanup_policy()
	_finish()


func _test_protocol_attempt_identity_and_handshake() -> void:
	var state_script = _load_source_script(_source_root + "/scripts/network_session_state.gd")
	_assert(state_script != null, "production protocol core loads")
	if state_script == null:
		return

	var host_peer = state_script.new("peer-a")
	var nonce_a = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	var nonce_b = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
	_assert(not bool(host_peer.host_accept_hello("short-nonce", 41).get("accepted", true)), "host rejects a nonce that is not 128-bit hexadecimal")
	var first = host_peer.host_accept_hello(nonce_a, 41)
	_assert(bool(first.get("accepted", false)), "host accepts a new v2 hello attempt")
	_assert(bool(first.get("new_attempt", false)), "first nonce creates a new attempt")
	_assert(int(first.get("generation", 0)) == 1, "host assigns generation one")
	var duplicate = host_peer.host_accept_hello(nonce_a, 99)
	_assert(bool(duplicate.get("accepted", false)), "duplicate hello is idempotent")
	_assert(not bool(duplicate.get("new_attempt", true)), "duplicate nonce does not advance generation")
	_assert(int(duplicate.get("generation", 0)) == 1, "duplicate nonce keeps generation")
	_assert(int(duplicate.get("state_revision", 0)) == 41, "duplicate hello keeps the original challenge revision")
	_assert(str(duplicate.get("resend_phase", "")) == "challenge", "duplicate Hello in NEGOTIATING resends Challenge")
	var restarted = host_peer.host_accept_hello(nonce_b, 42)
	_assert(bool(restarted.get("new_attempt", false)), "new process nonce creates a fresh attempt")
	_assert(int(restarted.get("generation", 0)) == 2, "host advances generation for a new process nonce")
	var delayed_old_hello = host_peer.host_accept_hello(nonce_a, 42)
	_assert(not bool(delayed_old_hello.get("accepted", true)), "retired nonce cannot become a third attempt when its Hello arrives late")
	_assert(int(host_peer.connection_generation) == 2, "retired nonce does not advance generation")

	_assert(not host_peer.host_accept_confirm(nonce_b, 2, 41), "confirm with the wrong challenge revision is rejected")
	_assert(host_peer.host_accept_confirm(nonce_b, 2, 42), "matching confirm enters syncing")
	var syncing_duplicate = host_peer.host_accept_hello(nonce_b, 99)
	_assert(str(syncing_duplicate.get("resend_phase", "")) == "full_state", "duplicate Hello in SYNCING resends FullState without returning to Challenge")
	_assert(not host_peer.begin_full_state(nonce_b, 2, 41, ["selection", "battle_snapshot"]), "full-state manifest cannot change the bound challenge revision")
	_assert(host_peer.begin_full_state(nonce_b, 2, 42, ["selection", "battle_snapshot"]), "matching full-state manifest is accepted")
	_assert(host_peer.has_method("mark_full_state_component_revision"), "production core binds full-state components to revision")
	if not host_peer.has_method("mark_full_state_component_revision"):
		return
	_assert(not host_peer.mark_full_state_component_revision(nonce_b, 2, 41, "selection"), "component from the wrong revision is rejected")
	_assert(host_peer.mark_full_state_component_revision(nonce_b, 2, 42, "selection"), "first required component is recorded")
	_assert(not host_peer.can_ack_full_state(nonce_b, 2, 42), "full state cannot ACK before every component")
	_assert(host_peer.mark_full_state_component_revision(nonce_b, 2, 42, "battle_snapshot"), "second required component is recorded")
	_assert(host_peer.can_ack_full_state(nonce_b, 2, 42), "full state can ACK after every component")
	_assert(not host_peer.host_accept_ack(nonce_a, 1, 42), "stale attempt ACK is rejected")
	_assert(not host_peer.host_accept_ack(nonce_b, 2, 41), "wrong revision ACK is rejected")
	_assert(host_peer.host_accept_ack(nonce_b, 2, 42), "matching ACK is accepted")
	_assert(host_peer.host_accept_ack(nonce_b, 2, 42), "duplicate matching ACK remains idempotent after READY")
	_assert(str(host_peer.host_accept_hello(nonce_b, 99).get("resend_phase", "")) == "complete", "duplicate Hello in READY resends Complete")
	_assert(host_peer.can_send_input, "matching ACK makes host peer ready")
	_assert(host_peer.apply_periodic_revision(42), "periodic state revision is accepted after ready")
	_assert(host_peer.can_send_input and host_peer.state == state_script.STATE_READY, "periodic state never revokes ready")
	host_peer.state = state_script.STATE_FAILED
	host_peer.can_send_input = false
	_assert(not bool(host_peer.host_accept_hello(nonce_b, 43).get("accepted", true)), "failed Steam session requires a fresh nonce")

	var replay_guard = state_script.new("peer-replay")
	var oldest_nonce = "%032x" % 1
	for nonce_index in range(1, 19):
		_assert(bool(replay_guard.host_accept_hello("%032x" % nonce_index, nonce_index).get("accepted", false)), "fresh nonce is retained for lobby-lifetime replay protection")
	_assert(not bool(replay_guard.host_accept_hello(oldest_nonce, 99).get("accepted", true)), "a nonce remains retired after more than sixteen attempts")

	var client_peer = state_script.new("host-a")
	_assert(client_peer.begin_client_attempt(nonce_a), "client starts a revision-bound attempt")
	_assert(client_peer.client_accept_challenge(nonce_a, 1, 51, 1, 1, 1), "client accepts a matching challenge revision")
	_assert(client_peer.begin_full_state(nonce_a, 1, 51, []), "client accepts the challenge-bound full-state revision")
	_assert(not client_peer.client_receive_complete(nonce_a, 1, 52), "client rejects Complete with a revision newer than the acknowledged manifest")
	_assert(client_peer.client_receive_complete(nonce_a, 1, 51), "client accepts Complete only at the exact manifest revision")
	_assert(client_peer.client_accept_challenge(nonce_a, 1, 51, 1, 1, 1), "duplicate challenge after READY is idempotently accepted")
	_assert(client_peer.state == state_script.STATE_READY and client_peer.can_send_input, "duplicate challenge after READY does not revoke readiness")
	client_peer.clear_transport()
	_assert(client_peer.state == state_script.STATE_DISCONNECTED and not client_peer.can_send_input and client_peer.mapping.empty(), "transport cleanup clears readiness and slot mapping")
	print("[BO_TEST_CASE_COMPLETE] protocol_attempt_identity_and_handshake")


func _test_protocol_envelope_and_stream_invariants() -> void:
	var state_script = _load_source_script(_source_root + "/scripts/network_session_state.gd")
	if state_script == null:
		return
	var peer = state_script.new("peer-a")
	var nonce_a = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	peer.host_accept_hello(nonce_a, 1)
	var expected = {
		"protocol_version": 2,
		"lobby_id": "lobby-a",
		"host_steam_id": "host-a",
		"sender_steam_id": "peer-a"
	}
	var valid = {
		"msg_type": "selection_state",
		"protocol_version": 2,
		"session_lobby_id": "lobby-a",
		"game_host_steam_id": "host-a",
		"sender_steam_id": "peer-a",
		"connection_generation": 1,
		"session_epoch": 1,
		"connection_nonce": nonce_a
	}
	_assert(bool(peer.validate_envelope(valid, expected).get("accepted", false)), "matching v2 envelope is accepted")
	for field_case in [
		{"protocol_version": 1},
		{"session_lobby_id": "other-lobby"},
		{"game_host_steam_id": "other-host"},
		{"sender_steam_id": "other-peer"},
		{"connection_generation": 2, "session_epoch": 2},
		{"connection_nonce": "old-nonce"}
	]:
		var invalid = valid.duplicate(true)
		for key in field_case.keys():
			invalid[key] = field_case[key]
		_assert(not bool(peer.validate_envelope(invalid, expected).get("accepted", true)), "mismatched v2 envelope is rejected: " + to_json(field_case))

	for seq in range(1, 65):
		_assert(peer.accept_stream_sequence("peer-a", "shop", seq), "monotonic shop sequence is accepted: " + str(seq))
		_assert(peer.accept_stream_sequence("peer-a", "upgrade", seq), "independent upgrade sequence is accepted: " + str(seq))
		_assert(not peer.accept_stream_sequence("peer-a", "shop", seq), "duplicate shop sequence is rejected: " + str(seq))
	_assert(not peer.accept_stream_sequence("", "shop", 1), "empty action origin is rejected")
	_assert(not peer.accept_stream_sequence("peer-a", "", 1), "empty action stream is rejected")
	_assert(not peer.accept_stream_sequence("peer-a", "shop", 0), "non-positive action sequence is rejected")
	_assert(peer.has_method("next_outbound_stream_sequence"), "production core exposes Host relay sequencing")
	if not peer.has_method("next_outbound_stream_sequence"):
		return
	_assert(peer.next_outbound_stream_sequence("peer-a", "shop") == 65, "Host relay sequence continues independently of a reconnecting origin's local counter")
	_assert(peer.next_outbound_stream_sequence("peer-a", "upgrade") == 65, "Host relay keeps streams independent while preserving continuity")
	_assert(peer.has_method("validate_chunk_metadata"), "production protocol core exposes chunk admission")
	if not peer.has_method("validate_chunk_metadata"):
		return
	_assert(bool(peer.validate_chunk_metadata(48, 2 * 1024 * 1024, 3, 11).get("accepted", false)), "chunk metadata at every production limit is accepted")
	_assert(not bool(peer.validate_chunk_metadata(49, 1024, 0, 0).get("accepted", true)), "chunk count above 48 is rejected")
	_assert(not bool(peer.validate_chunk_metadata(2, 2 * 1024 * 1024 + 1, 0, 0).get("accepted", true)), "reassembled payload above 2 MiB is rejected")
	_assert(not bool(peer.validate_chunk_metadata(2, 1024, 4, 0).get("accepted", true)), "fifth concurrent assembly for one peer is rejected")
	_assert(not bool(peer.validate_chunk_metadata(2, 1024, 0, 12).get("accepted", true)), "thirteenth global assembly is rejected")
	print("[BO_TEST_CASE_COMPLETE] protocol_envelope_and_stream_invariants")


func _test_network_send_scheduler_behavior() -> void:
	var scheduler_script = _load_source_script(_source_root + "/scripts/network_send_scheduler.gd")
	_assert(scheduler_script != null, "production send scheduler loads")
	if scheduler_script == null:
		return
	var scheduler = scheduler_script.new(48, 192, 15000, 100)
	for index in range(5):
		_assert(scheduler.enqueue({
			"target_steam_id": "peer-a",
			"channel": 0,
			"payload": PoolByteArray([index]),
			"queued_msec": 0,
			"next_send_msec": 0,
			"connection_generation": 1,
			"connection_nonce": "nonce-a",
			"priority": scheduler_script.PRIORITY_EVENT
		}), "single-peer packet is queued")
	var first_frame = []
	for _index in range(4):
		var entry = scheduler.take_next_ready(0, {})
		first_frame.append(int(entry.get("payload", PoolByteArray())[0]))
		scheduler.report_success(entry)
	_assert(first_frame == [0, 1, 2, 3], "single peer consumes the full four-packet frame budget in FIFO order")

	var fair = scheduler_script.new(48, 192, 15000, 100)
	for peer_id in ["peer-a", "peer-b", "peer-c"]:
		for index in range(2):
			fair.enqueue({
				"target_steam_id": peer_id,
				"channel": 0,
				"payload": PoolByteArray([index]),
				"queued_msec": 0,
				"next_send_msec": 0,
				"connection_generation": 1,
				"connection_nonce": "nonce-" + peer_id,
				"priority": scheduler_script.PRIORITY_EVENT
			})
	var served = []
	for _index in range(4):
		var entry = fair.take_next_ready(0, {})
		served.append(str(entry.get("target_steam_id", "")))
		fair.report_success(entry)
	_assert(served.slice(0, 2) == ["peer-a", "peer-b", "peer-c"], "scheduler serves every peer before a second pass")

	var failure = scheduler_script.new(48, 192, 15000, 100)
	for peer_id in ["blocked", "healthy"]:
		failure.enqueue({
			"target_steam_id": peer_id,
			"channel": 0,
			"payload": PoolByteArray([1]),
			"queued_msec": 0,
			"next_send_msec": 0,
			"connection_generation": 1,
			"connection_nonce": "nonce-" + peer_id,
			"priority": scheduler_script.PRIORITY_CONTROL
		})
	var blocked_entry = failure.take_next_ready(0, {})
	failure.report_failure(blocked_entry, 0)
	var healthy_entry = failure.take_next_ready(0, {"blocked|0": true})
	_assert(str(healthy_entry.get("target_steam_id", "")) == "healthy", "failed peer does not block a healthy peer")
	_assert(failure.drop_stale_for_connection("blocked", 2, "nonce-new") == 1, "old-generation retry is removed on reconnect")

	var bounded = scheduler_script.new(3, 4, 50, 100)
	_assert(bounded.enqueue(_scheduler_test_packet(scheduler_script, "peer-a", 0, 1, scheduler_script.PRIORITY_TRANSIENT, "")), "transient packet enters bounded queue")
	_assert(bounded.enqueue(_scheduler_test_packet(scheduler_script, "peer-a", 0, 2, scheduler_script.PRIORITY_REPLACEABLE, "state")), "replaceable packet enters bounded queue")
	_assert(bounded.enqueue(_scheduler_test_packet(scheduler_script, "peer-a", 0, 3, scheduler_script.PRIORITY_REPLACEABLE, "state")), "new replaceable packet supersedes the old state")
	_assert(bounded.count_for_peer("peer-a") == 2, "coalescing does not grow the peer queue")
	_assert(bounded.has_pending("peer-a", 0), "pending query is scoped by peer and channel")
	_assert(bounded.enqueue(_scheduler_test_packet(scheduler_script, "peer-a", 0, 4, scheduler_script.PRIORITY_CONTROL, "")), "control packet evicts lower priority work at the peer limit")
	_assert(bounded.count_for_peer("peer-a") == 3, "control insertion preserves the peer limit")
	_assert(bounded.prune_expired(100) == 3, "expired entries are removed deterministically")
	_assert(not bounded.has_pending("peer-a", 0), "expired peer queue is empty")

	var failed_replace = scheduler_script.new(2, 2, 1000, 100)
	_assert(failed_replace.enqueue(_scheduler_test_packet(scheduler_script, "peer-replace", 0, 1, scheduler_script.PRIORITY_REPLACEABLE, "state")), "replaceable state enters before saturation")
	_assert(failed_replace.enqueue(_scheduler_test_packet(scheduler_script, "peer-replace", 0, 2, scheduler_script.PRIORITY_CONTROL, "")), "control packet saturates the peer queue")
	_assert(not failed_replace.enqueue(_scheduler_test_packet(scheduler_script, "peer-replace", 0, 3, scheduler_script.PRIORITY_REPLACEABLE, "state")), "replaceable replacement is rejected when saturated")
	var preserved = failed_replace.take_next_ready(0, {})
	_assert(int(preserved.get("payload", PoolByteArray())[0]) == 1, "failed replacement preserves the previous coalesced state")

	var chunk_batch = scheduler_script.new(8, 16, 1000, 100)
	var first_chunk = _scheduler_test_packet(scheduler_script, "peer-chunk", 0, 10, scheduler_script.PRIORITY_REPLACEABLE, "snapshot")
	first_chunk["preserve_coalesce_group"] = true
	var second_chunk = _scheduler_test_packet(scheduler_script, "peer-chunk", 0, 11, scheduler_script.PRIORITY_REPLACEABLE, "snapshot")
	second_chunk["preserve_coalesce_group"] = true
	_assert(chunk_batch.enqueue(first_chunk), "first replaceable chunk enters as part of an atomic group")
	_assert(chunk_batch.enqueue(second_chunk), "second replaceable chunk does not evict its own group")
	_assert(chunk_batch.count_for_peer("peer-chunk") == 2, "all chunks in one coalesced message remain queued")
	_assert(chunk_batch.drop_coalesced("peer-chunk", 0, "snapshot") == 2, "a newer state removes the entire older chunk group")

	var control_batch = scheduler_script.new(3, 4, 1000, 100)
	for value in [1, 2, 3]:
		control_batch.enqueue(_scheduler_test_packet(scheduler_script, "peer-control", 0, value, scheduler_script.PRIORITY_TRANSIENT, ""))
	_assert(control_batch.has_method("reserve_capacity"), "production scheduler exposes atomic batch reservation")
	if not control_batch.has_method("reserve_capacity"):
		return
	_assert(control_batch.reserve_capacity("peer-control", 3, scheduler_script.PRIORITY_CONTROL), "handshake chunk batch evicts lower-priority work instead of being dropped")
	_assert(control_batch.count_for_peer("peer-control") == 0, "batch reservation frees the full peer capacity before enqueue")

	var atomic_failure = scheduler_script.new(2, 4, 1000, 100)
	for value in [1, 2]:
		_assert(atomic_failure.enqueue(_scheduler_test_packet(scheduler_script, "peer-full", 0, value, scheduler_script.PRIORITY_CONTROL, "")), "preferred peer control packet fills its own limit")
	_assert(atomic_failure.enqueue(_scheduler_test_packet(scheduler_script, "peer-other", 0, 3, scheduler_script.PRIORITY_TRANSIENT, "")), "unrelated lower-priority packet is queued")
	_assert(not atomic_failure.reserve_capacity("peer-full", 1, scheduler_script.PRIORITY_CONTROL), "reservation fails when only preferred-peer control work blocks capacity")
	_assert(atomic_failure.count_for_peer("peer-other") == 1 and atomic_failure.size() == 3, "failed reservation leaves unrelated peer work untouched")

	var ordered_handshake = state_script_for_scheduler_test()
	_assert(ordered_handshake != null, "protocol core loads for staged full-state ordering")
	if ordered_handshake != null:
		var staged_peer = ordered_handshake.new("peer-stage")
		var staged_nonce = "cccccccccccccccccccccccccccccccc"
		staged_peer.host_accept_hello(staged_nonce, 7)
		staged_peer.host_accept_confirm(staged_nonce, 1, 7)
		_assert(staged_peer.has_method("stage_full_state_messages"), "protocol core exposes production full-state staging")
		if staged_peer.has_method("stage_full_state_messages"):
			var staged_messages = [{"msg_type": "reconnect_full_state_begin"}]
			for chunk_index in range(48):
				staged_messages.append({"msg_type": "p2p_json_chunk", "chunk_index": chunk_index})
			staged_messages.append({"msg_type": "reconnect_full_state"})
			_assert(staged_peer.stage_full_state_messages(staged_nonce, 1, 7, staged_messages), "maximum-size component and final marker are staged as one ordered handshake plan")
			for expected_index in range(staged_messages.size()):
				var actual_message = staged_peer.peek_full_state_message()
				var expected_message = staged_messages[expected_index]
				var same_message = str(actual_message.get("msg_type", "")) == str(expected_message.get("msg_type", ""))
				if expected_message.has("chunk_index"):
					same_message = same_message and int(actual_message.get("chunk_index", -1)) == int(expected_message.get("chunk_index", -2))
				_assert(same_message, "staged handshake never lets the final marker overtake a component chunk")
				_assert(staged_peer.mark_full_state_message_sent(), "staged handshake advances only after transport accepts the current message")
			_assert(not staged_peer.has_staged_full_state_messages(), "staged handshake is empty only after the marker is accepted")
	print("[BO_TEST_CASE_COMPLETE] network_send_scheduler_behavior")


func state_script_for_scheduler_test():
	return _load_source_script(_source_root + "/scripts/network_session_state.gd")


func _scheduler_test_packet(scheduler_script, peer_id: String, channel: int, byte_value: int, priority: int, coalesce_key: String) -> Dictionary:
	return {
		"target_steam_id": peer_id,
		"channel": channel,
		"payload": PoolByteArray([byte_value]),
		"queued_msec": 0,
		"next_send_msec": 0,
		"connection_generation": 1,
		"connection_nonce": "nonce-" + peer_id,
		"priority": priority,
		"coalesce_key": coalesce_key
	}


func _test_steam_callback_driver_switching() -> void:
	var driver_script = _load_source_script(_source_root + "/scripts/steam_callback_driver.gd")
	_assert(driver_script != null, "production Steam callback driver loads")
	if driver_script == null:
		return
	var driver = driver_script.new()
	_assert(driver.should_run_manual(self, self), "callback driver is manual when SceneTree has no owner")
	connect("idle_frame", self, "run_callbacks")
	_assert(not driver.should_run_manual(self, self), "callback driver detects an automatic SceneTree owner")
	disconnect("idle_frame", self, "run_callbacks")
	_assert(driver.should_run_manual(self, self), "callback driver returns to manual after owner removal")
	print("[BO_TEST_CASE_COMPLETE] steam_callback_driver_switching")


func run_callbacks() -> void:
	pass


func _test_protocol_config() -> void:
	var config_script = _load_source_script(_source_root + "/scripts/network_protocol_config.gd")
	_assert(config_script != null, "production protocol config loads")
	if config_script == null:
		return
	_assert(str(config_script.MOD_VERSION) == "4.1.1", "production Mod version is 4.1.1")
	_assert(int(config_script.PROTOCOL_VERSION) == 2, "production protocol version is v2 only")
	print("[BO_TEST_CASE_COMPLETE] protocol_config")


func _test_focus_control_guard_rejects_off_tree_controls() -> void:
	var guard_script = _load_source_script(_source_root + "/scripts/focus_control_guard.gd")
	_assert(guard_script != null, "focus control guard loads")
	if guard_script == null:
		return

	var scene_root = Node.new()
	get_root().add_child(scene_root)
	var control = Button.new()
	_assert(not guard_script.is_focusable_control(control), "off-tree controls are rejected as focus targets")
	scene_root.add_child(control)
	_assert(guard_script.is_focusable_control(control), "in-tree visible controls are accepted as focus targets")
	control.queue_free()
	_assert(not guard_script.is_focusable_control(control), "queued controls are rejected as focus targets")
	scene_root.queue_free()
	print("[BO_TEST_CASE_COMPLETE] focus_control_guard")


func _test_shop_focus_target_fallback_policy() -> void:
	var guard_script = _load_source_script(_source_root + "/scripts/focus_control_guard.gd")
	_assert(guard_script != null, "focus target policy loads")
	if guard_script == null:
		return
	_assert(str(guard_script.resolve_shop_focus_target(true, "", "item_0")) == "", "live focus emulator does not fall back to stale shop item")
	_assert(str(guard_script.resolve_shop_focus_target(true, "go", "item_0")) == "go", "live focus emulator keeps the actual target")
	_assert(str(guard_script.resolve_shop_focus_target(false, "", "item_0")) == "item_0", "missing focus emulator keeps legacy fallback")
	print("[BO_TEST_CASE_COMPLETE] shop_focus_target_fallback_policy")


func _test_focus_application_policy() -> void:
	var guard_script = _load_source_script(_source_root + "/scripts/focus_control_guard.gd")
	_assert(guard_script != null, "focus application policy loads")
	if guard_script == null:
		return
	var scene_root = Node.new()
	get_root().add_child(scene_root)
	var control = Button.new()
	_assert(not guard_script.can_apply_focus_control(control), "detached controls are rejected before focus application")
	scene_root.add_child(control)
	_assert(guard_script.can_apply_focus_control(control), "attached visible controls can receive focus application")
	_assert(not guard_script.should_expect_focus_signal_after_direct_assignment(true), "direct focus assignment does not wait for a focus signal")
	_assert(guard_script.should_expect_focus_signal_after_direct_assignment(false), "engine focus calls still wait for a focus signal")
	control.queue_free()
	scene_root.queue_free()
	print("[BO_TEST_CASE_COMPLETE] focus_application_policy")


func _test_online_slot_reset_preserves_local_layout() -> void:
	var layout_script = _load_source_script(_source_root + "/scripts/online_slot_layout.gd")
	_assert(layout_script != null, "online slot layout helper loads")
	if layout_script == null:
		return

	var local_and_remote = [[7, 0], [1, 1], [6, 0], [5, 0]]
	var local_layout = layout_script.preserve_local_slots(local_and_remote, [1])
	_assert(local_layout == [[7, 0], [6, 0], [5, 0]], "leaving a lobby keeps all local character slots")
	var mapped_remote_layout = layout_script.preserve_local_slots(local_and_remote, [], {"1": "remote-peer"})
	_assert(mapped_remote_layout == local_layout, "remote device mapping also excludes stale remote placeholders")
	var continue_layout = layout_script.clear_for_offline_continue([[1, 1], [7, 0]])
	_assert(continue_layout.empty(), "client leave clears pre-joined slots so Continue can accept a fresh input")

	var first_reopen = local_layout.duplicate(true)
	first_reopen.append([1, 1])
	var second_offline = layout_script.preserve_local_slots(first_reopen, [1])
	_assert(second_offline == local_layout, "reopening a lobby does not lose a local slot")
	var second_reopen = second_offline.duplicate(true)
	second_reopen.append([1, 1])
	_assert(second_reopen.size() == 4, "repeated create/leave/create keeps the four-slot lobby layout")
	print("[BO_TEST_CASE_COMPLETE] online_slot_reset_preserves_local_layout")


func _test_host_proxy_death_cleanup_policy() -> void:
	var replica_script = _load_source_script(_source_root + "/scripts/battle_replica_manager.gd")
	_assert(replica_script != null, "battle replica manager loads for proxy death policy")
	if replica_script == null:
		return
	var replica = replica_script.new()
	_assert(replica != null, "battle replica manager can instantiate for proxy death policy")
	if replica == null:
		return
	_assert(replica.should_remove_dead_host_proxy("pet", false, false), "client removes a dead pet Host proxy when death sync is disabled")
	_assert(not replica.should_remove_dead_host_proxy("enemy", false, false), "client keeps enemy spawner bookkeeping on a local enemy death")
	_assert(not replica.should_remove_dead_host_proxy("pet", true, false), "Host does not remove its own entity through the client proxy policy")
	_assert(not replica.should_remove_dead_host_proxy("pet", false, true), "delayed death sync keeps the pet proxy for the death animation path")
	replica.queue_free()
	print("[BO_TEST_CASE_COMPLETE] host_proxy_death_cleanup_policy")


func _load_source_script(script_path: String):
	var relative_path = script_path.substr(_source_root.length()).trim_prefix("/")
	var resource_path = "res://" + relative_path
	var script = load(resource_path)
	if script != null and script.has_method("can_instance") and not script.can_instance():
		return null
	return script


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		printerr("[FAIL] " + message)
	else:
		print("[PASS] " + message)


func _finish() -> void:
	if _failures.empty():
		print("[BO_TEST_SUITE_COMPLETE]")
		print("Godot headless tests passed")
		quit(0)
		return
	printerr("Godot headless tests failed: " + str(_failures.size()))
	quit(1)
