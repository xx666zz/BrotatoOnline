extends Node
onready var root = get_tree().root
const Registry = preload("res://scripts/player_identity_registry.gd")
var failures = 0
var checks = 0
var mod = null
var session = null
var slots = null
var identity = null
var transport = null

func _ready():
	get_tree().create_timer(15).connect("timeout", get_tree(), "quit", [1])
	call_deferred("_run")

func check(value: bool, message: String):
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: ", message)

func _run():
	for filename in ["session_manager.gd", "online_player_slot_manager.gd", "player_removal_manager.gd"]:
		var script = load("res://scripts/" + filename)
		check(script != null and script.can_instance(), "whole production script compiles: " + filename)
	for path in ["res://mod_main.gd", "res://progress_extension.gd"]:
		var script = load(path)
		check(script != null and script.can_instance(), "production bootstrap/save extension compiles: " + path)
	_test_registry()
	var loader = Node.new()
	loader.name = "ModLoader"
	root.add_child(loader)
	mod = Node.new()
	mod.name = "six666-BrotatoOnline"
	loader.add_child(mod)
	session = load("res://session.gd").new()
	session.name = "BrotatoOnlineSessionManager"
	mod.add_child(session)
	slots = load("res://slots.gd").new()
	slots.name = "BrotatoOnlineOnlinePlayerSlotManager"
	mod.add_child(slots)
	identity = load("res://scripts/player_identity_manager.gd").new()
	identity.name = "BrotatoOnlinePlayerIdentityManager"
	mod.add_child(identity)
	identity.set_process(false)
	transport = load("res://transport.gd").new()
	mod.add_child(transport)
	session._lan_transport = transport
	var args = OS.get_cmdline_args()
	if "--preview" in args:
		_preview(args[args.find("--preview") + 1])
		return
	_test_reconnections()
	_test_resume_orders()
	_test_local_coop()
	_test_legacy()
	_test_lan()
	_test_transaction()
	_test_checkpoint_filter()
	_test_handshake_readiness()
	_test_new_run_credentials()
	_test_resume_recovery()
	_test_resume_feedback()
	_test_lan_failure_and_refresh()
	_test_delayed_rotation_checkpoint()
	_test_review_regressions()
	yield(_test_loopback_transport(), "completed")
	yield(_test_loopback_refusal(), "completed")
	if failures == 0:
		print("IDENTITY TESTS PASSED: ", checks, " checks")
	else:
		printerr("IDENTITY TESTS FAILED: ", failures, "/", checks)
	get_tree().quit(0 if failures == 0 else 1)

func _preview(output: String):
	var i18n = load("res://i18n.gd").new()
	i18n.name = "BrotatoOnlineI18n"
	mod.add_child(i18n)
	_reset()
	var scene = _resume({})
	if File.new().file_exists("res://preview_font.ttc"):
		var font = DynamicFont.new()
		var data = DynamicFontData.new()
		data.font_path = "res://preview_font.ttc"
		font.font_data = data
		font.size = 22
		var theme = Theme.new()
		theme.default_font = font
		identity._panel.theme = theme
	for index in range(2, 5):
		session._register_remote_connection(str(index), transport, index + 20)
	identity._update_panel()
	yield(get_tree().create_timer(0.3), "timeout")
	var screenshot = get_viewport().get_texture().get_data()
	screenshot.flip_y()
	var error = screenshot.save_png(output)
	check(error == OK, "UI screenshot exported")
	print("IDENTITY UI PREVIEW SAVED")
	get_tree().quit(0 if failures == 0 else 1)

func _owners(keys: Array) -> Array:
	var result = []
	for key in keys:
		result.append({"owner_id": str(key), "local_slot": 0})
	return result

func _test_registry():
	var registry = Registry.new()
	registry.assign(_owners(["1", "2", "3", "4"]))
	var state = registry.metadata()
	var restored = Registry.new()
	check(restored.load_metadata(parse_json(to_json(state)), 4), "JSON save round-trip")
	check(restored.index_for_owner("3") == 2, "ownership survives JSON numeric coercion")
	var slot_id = str(restored.slots[2].slot_id)
	restored.compact([0, 2, 3])
	check(restored.index_for_owner("3") == 1 and str(restored.slots[1].slot_id) == slot_id, "compaction keeps permanent slot ID")
	var invalid = state.duplicate(true)
	invalid.slots[1].owner_id = "1"
	check(not Registry.new().load_metadata(invalid, 4), "duplicate owners rejected")
	invalid = state.duplicate(true)
	invalid.slots[1].slot_id = invalid.slots[0].slot_id
	check(not Registry.new().load_metadata(invalid, 4), "duplicate slot IDs rejected")
	check(not Registry.new().load_metadata(state, 3), "count mismatch rejected")
	check(not Registry.new().load_metadata({}, 4), "old saves need explicit assignment")
	var lan = "lan:" + Registry.random_id()
	var token = Registry.random_id()
	registry.assign(_owners(["1", lan]), {lan: token.sha256_text()})
	check(registry.lan_proof_valid(lan, token), "LAN saved proof accepted")
	check(not registry.lan_proof_valid(lan, Registry.random_id()), "wrong LAN proof rejected")
	check(not token in to_json(registry.metadata()), "saved table has hashes, no private token")

func _reset():
	if get_tree().current_scene != null and get_tree().current_scene != self:
		get_tree().current_scene.free()
	get_tree().current_scene = null
	identity.reset_online_session_state()
	session._session_active = true
	session._online_role = "host"
	session._self_steam_id = "1"
	session._steam = null
	session._steam_transport = null
	session._lobby_id = 0
	session._pending_lan_join = false
	session._pending_join_lobby_id = 0
	session._client_join_requested_lobby_id = 0
	session._rejected_peer_keys.clear()
	session._pending_p2p_chunk_sends.clear()
	session._official_continue_auto_lobby_done_for_scene_id = 0
	session._official_continue_auto_lobby_armed = false
	session.failures.clear()
	session.frozen = false
	session._connection_by_peer_key.clear()
	session._peer_key_by_connection.clear()
	session._connections.clear()
	session._session_remote_peer_keys.clear()
	session._host_known_remote_ids.clear()
	session._lan_identity_challenges.clear()
	session._seen_client_hello_by_steam_id.clear()
	slots._remote_steam_id_by_device.clear()
	slots._device_by_remote_steam_id.clear()
	slots._remote_devices.clear()
	CoopService.connected_players = [[7, 0]]
	slots._host_player_joined_by_manager = true
	RunData.players_data = ["gear1", "gear2", "gear3", "gear4"]
	RunData.start_wave_state = {}
	ProgressData.saved_run_state = {"has_run_state": true, "players_data": RunData.players_data.duplicate(), "shop_items": ["shop1", "shop2", "shop3", "shop4"]}
	ProgressData.last_saved_run_state = ProgressData.saved_run_state.duplicate(true)
	transport.closed.clear()
	transport.packets.clear()
	transport.host_result = OK
	transport.available = false
	transport.hosting = false
	session.welcomes.clear()

func _resume(metadata: Dictionary):
	var file = File.new()
	file.open("res://run_v3_0.json", File.WRITE)
	file.store_string(to_json(ProgressData.saved_run_state))
	file.close()
	var store = ConfigFile.new()
	if not metadata.empty():
		store.set_value("checkpoints", identity._checkpoint_key(), metadata)
	store.save(identity.RUN_FILE)
	var scene = load("res://resume_base.gd").new()
	scene.filename = "res://ui/menus/shop/coop_resume.tscn"
	root.add_child(scene)
	get_tree().current_scene = scene
	identity.bind_resume_scene(scene)
	identity.prepare_resume_if_needed()
	return scene

func _test_reconnections():
	_reset()
	check(session._register_remote_connection("2", transport, 21), "first owner admitted")
	check(session._register_remote_connection("3", transport, 31), "second owner admitted")
	session._on_transport_peer_disconnected(transport, 21)
	session._on_transport_peer_disconnected(transport, 31)
	session.frozen = true
	check(session._register_remote_connection("3", transport, 32), "second owner reconnects first during battle")
	check(session._session_remote_peer_keys == ["2", "3"], "reconnect cannot overwrite first absent owner")
	check(session._register_remote_connection("3", transport, 32), "repeated connection registration is idempotent")
	check(not session._register_remote_connection("3", transport, 33), "duplicate live owner rejected")
	check(not session._register_remote_connection("4", transport, 41), "stranger cannot take disconnected battle slot")
	check(session._register_remote_connection("2", transport, 22), "first owner returns to its own slot")
	# An old transport callback cannot remove a newer connection.
	session._peer_key_by_connection[session._connection_lookup_key(transport, 21)] = "2"
	session._on_transport_peer_disconnected(transport, 21)
	check(session._connection_by_peer_key["2"].peer == 22, "stale disconnect preserves new connection")
	session.received_sender = ""
	session._on_transport_packet_received(transport, 41, to_json({"sender_steam_id": "2"}).to_utf8(), 0)
	check(session.received_sender == "", "unregistered connection cannot spoof another owner's sender")
	session._on_transport_packet_received(transport, 32, to_json({"sender_steam_id": "2"}).to_utf8(), 0)
	check(session.received_sender == "3", "registered connection uses actual sender instead of claimed owner")

func _test_resume_orders():
	for order in [["2", "3", "4"], ["2", "4", "3"], ["3", "2", "4"], ["3", "4", "2"], ["4", "2", "3"], ["4", "3", "2"]]:
		_reset()
		var registry = Registry.new()
		registry.assign(_owners(["1", "2", "3", "4"]))
		var scene = _resume(registry.metadata())
		for position in range(order.size()):
			check(session._register_remote_connection(order[position], transport, position + 20), "resume admission " + str(order))
			session._seen_client_hello_by_steam_id[order[position]] = true
			CoopService.emit_signal("connected_players_updated", CoopService.connected_players)
			identity._try_commit(false)
			if position < 2:
				check(not scene.finished and identity.is_resume_pending(), "wait for absent owners " + str(order))
				check(not session._official_continue_players_ready(), "offline owner never counted ready")
		check(scene.finished and not identity.is_resume_pending(), "complete resume " + str(order))
		check(scene.advance_count == 2, "vanilla progression runs once after full commit")
		for index in range(1, 4):
			check(slots.get_player_index_for_steam_id(str(index + 1)) == index, "saved index preserved " + str(order))
		check(RunData.players_data == ["gear1", "gear2", "gear3", "gear4"], "gear stays in saved slots")
		check(ProgressData.saved_run_state.shop_items == ["shop1", "shop2", "shop3", "shop4"], "shop data stays in saved slots")
		check(session._session_remote_peer_keys == ["2", "3", "4"], "transport bindings follow committed order")

func _test_local_coop():
	_reset()
	var registry = Registry.new()
	registry.assign([{"owner_id": "1", "local_slot": 0}, {"owner_id": "2", "local_slot": 0}, {"owner_id": "1", "local_slot": 1}, {"owner_id": "3", "local_slot": 0}])
	var scene = _resume(registry.metadata())
	session._register_remote_connection("3", transport, 30)
	session._register_remote_connection("2", transport, 20)
	session._seen_client_hello_by_steam_id = {"2": true, "3": true}
	identity._try_commit(false)
	check(not scene.finished, "missing second host-local input blocks resume")
	CoopService.connected_players.append([6, 1])
	CoopService.emit_signal("connected_players_updated", CoopService.connected_players)
	identity._try_commit(false)
	check(scene.finished and CoopService.connected_players[2] == [6, 1], "host local ordinal maps to saved nonadjacent slot")
	check(slots.get_player_index_for_steam_id("2") == 1 and slots.get_player_index_for_steam_id("3") == 3, "mixed local/online ownership restored")

func _test_legacy():
	_reset()
	var scene = _resume({})
	for index in range(2, 5):
		session._register_remote_connection(str(index), transport, index + 20)
		session._seen_client_hello_by_steam_id[str(index)] = true
	identity._update_panel()
	identity._try_commit(false)
	check(not scene.finished and identity._manual, "legacy save never guesses join-order ownership")
	for index in range(identity._choices.size()):
		identity._choices[index].select(index + 1)
	identity._confirm_assignment()
	check(scene.finished and not identity.load_saved_identity().empty() and not ProgressData.saved_run_state.has(Registry.SAVE_KEY), "host confirmation migrates old save")
	var migrated = Registry.new()
	check(migrated.load_metadata(identity.load_saved_identity(), 4), "migrated table valid on next resume")

func _test_lan():
	_reset()
	var install = Registry.random_id()
	var token = Registry.random_id()
	var owner = "lan:" + install
	var registry = Registry.new()
	registry.assign(_owners(["1", owner, "3", "4"]), {owner: token.sha256_text()})
	_resume(registry.metadata())
	check(identity.accept_lan_identity(install, token), "saved LAN identity accepts its token")
	check(not identity.accept_lan_identity(install, Registry.random_id()), "same installation with wrong proof denied")
	check(identity.client_identity_for_run(registry.run_id).resume_token == identity.client_identity_for_run(registry.run_id).resume_token, "client proof survives retry")
	session._on_transport_peer_connected(transport, 100)
	var request = transport.packets.back().message
	check(request.msg_type == "transport_identity_request" and request.run_id == registry.run_id, "LAN connection challenged for saved run")
	var reply = {"msg_type": "transport_identity", "installation_id": install, "resume_token": token, "run_id": registry.run_id, "protocol_version": 3}
	session._handle_transport_identity(transport, 100, reply)
	check(session._connection_by_peer_key.has(owner), "verified LAN owner uses stable key")
	session._on_transport_peer_disconnected(transport, 100)
	session._on_transport_peer_connected(transport, 200)
	session._handle_transport_identity(transport, 200, reply)
	check(session._connection_by_peer_key[owner].peer == 200 and session._session_remote_peer_keys == [owner], "changed ENet ID reconnects to same owner")
	session._online_role = "client"
	session._pending_lan_join = false
	transport.packets.clear()
	session._handle_transport_identity(transport, 1, {"msg_type": "transport_identity_request", "run_id": registry.run_id, "protocol_version": 3, "mod_version": "5.0.0"})
	check(not transport.packets.empty() and transport.packets.back().message.msg_type == "transport_identity", "automatic LAN reconnect answers challenge while already active")
	session._online_role = "host"

func _test_transaction():
	_reset()
	var before = CoopService.connected_players.duplicate(true)
	check(not slots.apply_resume_identity_layout([{"peer_key": "", "local_slot": 0}, {"peer_key": "2"}, {"peer_key": "2"}, {"peer_key": "3"}]), "duplicate layout rejected")
	check(CoopService.connected_players == before and slots._device_by_remote_steam_id.empty(), "failed commit has no partial topology")
	identity.registry.assign(_owners(["1", "2", "3", "4"]))
	RunData.start_wave_state = ProgressData.saved_run_state.duplicate(true)
	var old_slot_id = identity.registry.slots[2].slot_id
	RunData.players_data = ["gear1", "gear3", "gear4"]
	ProgressData.saved_run_state.players_data = RunData.players_data.duplicate()
	RunData.start_wave_state.players_data = RunData.players_data.duplicate()
	identity.compact_slots([0, 2, 3])
	check(identity.registry.slots[1].slot_id == old_slot_id, "removal keeps durable slot identity")
	check(identity.registry.slots.size() == 3 and not RunData.start_wave_state.has(Registry.SAVE_KEY), "retry cannot resurrect removed owner")

func _test_checkpoint_filter():
	_reset()
	var removal = load("res://scripts/player_removal_manager.gd").new()
	mod.add_child(removal)
	removal.set_process(false)
	removal._affects_saved_run = true
	removal._removed = {1: "2"}
	identity.registry.assign(_owners(["1", "2", "3", "4"]))
	var state = ProgressData.saved_run_state.duplicate(true)
	var metadata = identity._metadata_for_state(state)
	var filtered = removal.filter_saved_state(state)
	check(filtered.players_data == ["gear1", "gear3", "gear4"], "checkpoint removal filters character data")
	check(identity._metadata_for_state(filtered).slots[1].owner_id == "3", "checkpoint removal filters ownership in same positions")
	check(identity._metadata_for_state(filtered).slots[1].slot_id == metadata.slots[2].slot_id, "checkpoint removal retains slot ID")
	var again = removal.filter_saved_state(filtered)
	check(again.players_data == filtered.players_data and identity._metadata_for_state(again).slots.size() == 3 and not again.has(Registry.SAVE_KEY), "repeated checkpoint filtering is idempotent")
	var freshly_filtered = ProgressData.saved_run_state.duplicate(true)
	freshly_filtered.players_data = ["gear1", "gear3", "gear4"]
	freshly_filtered.bo_roster_slots = [0, 2, 3]
	var fresh_metadata = identity._metadata_for_state(freshly_filtered)
	check(fresh_metadata.slots[1].owner_id == "3", "fresh save metadata honors filtered indices")
	removal.free()

func _test_handshake_readiness():
	_reset()
	RunData.players_data = ["gear1", "gear2"]
	ProgressData.saved_run_state.players_data = RunData.players_data.duplicate()
	var registry = Registry.new()
	registry.assign(_owners(["1", "2"]))
	var scene = _resume(registry.metadata())
	check(not session._register_remote_connection("3", transport, 30), "stranger cannot consume saved owner's waiting seat")
	session._register_remote_connection("2", transport, 20)
	identity._try_commit(false)
	check(not scene.finished, "Steam membership before hello does not advance resume")
	session._seen_client_hello_by_steam_id["2"] = true
	identity._try_commit(false)
	check(scene.finished, "actual client hello permits commit")
	check(session.frozen, "committed topology locked before deferred shop transition")

func _test_new_run_credentials():
	_reset()
	var install = Registry.random_id()
	var owner = "lan:" + install
	var old_token = Registry.random_id()
	identity.registry.run_id = Registry.random_id()
	var old_run = identity.registry.run_id
	identity._lan_hashes[owner] = old_token.sha256_text()
	session._register_remote_connection(owner, transport, 50)
	var selection = Control.new()
	selection.filename = "res://ui/menus/character_selection.tscn"
	root.add_child(selection)
	get_tree().current_scene = selection
	identity._reset_for_new_selection()
	var next_run = identity.registry.run_id
	check(next_run != old_run, "same-room new run gets fresh run ID")
	check(transport.packets.back().message.run_id == next_run, "existing LAN connection challenged for new run")
	var new_token = Registry.random_id()
	var reply = {"msg_type": "transport_identity", "installation_id": install, "resume_token": new_token, "run_id": next_run, "protocol_version": 3}
	session._handle_transport_identity(transport, 50, reply)
	check(identity._lan_hashes.get(owner, "") == new_token.sha256_text(), "existing authenticated connection rotates per-run proof")
	check(session._session_remote_peer_keys == [owner], "credential rotation does not add or move a player")
	var packet_count = transport.packets.size()
	reply.run_id = old_run
	session._handle_transport_identity(transport, 50, reply)
	check(transport.packets.size() == packet_count and transport.closed.empty(), "delayed old-run response ignored without disconnecting")
	var credential = identity.client_identity_for_run(next_run)
	var reloaded = load("res://scripts/player_identity_manager.gd").new()
	mod.add_child(reloaded)
	reloaded.set_process(false)
	var restored = reloaded.client_identity_for_run(next_run)
	check(credential.resume_token == restored.resume_token and credential.installation_id == restored.installation_id, "client identity and proof persist across manager restart")
	reloaded.free()

func _test_loopback_transport():
	_reset()
	RunData.players_data = ["gear1", "gear2"]
	ProgressData.saved_run_state.players_data = RunData.players_data.duplicate()
	var registry = Registry.new()
	registry.run_id = Registry.random_id()
	var credential = identity.client_identity_for_run(registry.run_id)
	var owner = "lan:" + str(credential.installation_id)
	registry.assign(_owners(["1", owner]), {owner: str(credential.resume_token).sha256_text()})
	var scene = _resume(registry.metadata())
	var host_transport = load("res://scripts/lan_transport.gd").new()
	mod.add_child(host_transport)
	session._lan_transport = host_transport
	_bind_transport(host_transport, session)
	var client_group = Node.new()
	root.add_child(client_group)
	var client_session = load("res://session.gd").new()
	client_session.name = "BrotatoOnlineSessionManager"
	client_session._online_role = "client"
	client_session._pending_lan_join = true
	client_group.add_child(client_session)
	var client_identity = load("res://scripts/player_identity_manager.gd").new()
	client_identity.name = "BrotatoOnlinePlayerIdentityManager"
	client_group.add_child(client_identity)
	client_identity.set_process(false)
	var client_transport = load("res://scripts/lan_transport.gd").new()
	client_group.add_child(client_transport)
	client_session._lan_transport = client_transport
	_bind_transport(client_transport, client_session)
	var port = 29000 + int(OS.get_ticks_usec() % 1000)
	check(host_transport.start_host(port) == OK, "loopback ENet host starts")
	check(client_transport.start_client("127.0.0.1", port) == OK, "loopback ENet client starts")
	var deadline = OS.get_ticks_msec() + 3500
	while client_session.welcomes.empty() and OS.get_ticks_msec() < deadline:
		yield(get_tree().create_timer(0.02), "timeout")
	check(not client_session.welcomes.empty() and bool(client_session.welcomes.back().accepted), "real ENet identity challenge/welcome completes")
	check(session._connection_by_peer_key.has(owner), "real packet sender registered under persistent owner")
	if not session._connection_by_peer_key.has(owner):
		client_transport.stop()
		host_transport.stop()
		client_group.free()
		host_transport.free()
		session._lan_transport = transport
		return
	var old_peer = session._connection_by_peer_key[owner].peer
	client_transport.send_packet(1, to_json({"msg_type": "hello", "sender_steam_id": owner}).to_utf8(), 0, true)
	deadline = OS.get_ticks_msec() + 1500
	while not session._seen_client_hello_by_steam_id.has(owner) and OS.get_ticks_msec() < deadline:
		yield(get_tree().create_timer(0.02), "timeout")
	identity._try_commit(false)
	check(scene.finished and slots.get_player_index_for_steam_id(owner) == 1, "real ENet resume commits correct saved character")
	client_transport.stop()
	yield(get_tree().create_timer(0.15), "timeout")
	client_session.welcomes.clear()
	client_transport.start_client("127.0.0.1", port)
	deadline = OS.get_ticks_msec() + 3500
	while client_session.welcomes.empty() and OS.get_ticks_msec() < deadline:
		yield(get_tree().create_timer(0.02), "timeout")
	check(not client_session.welcomes.empty() and bool(client_session.welcomes.back().accepted), "real ENet reconnect validates persisted proof")
	check(session._connection_by_peer_key.has(owner) and session._connection_by_peer_key[owner].peer != old_peer, "real reconnect receives a different ENet peer ID")
	check(session._session_remote_peer_keys == [owner] and slots.get_player_index_for_steam_id(owner) == 1, "real reconnect keeps one owner and the same saved slot")
	client_transport.stop()
	host_transport.stop()
	client_group.free()
	host_transport.free()
	session._lan_transport = transport

func _bind_transport(endpoint: Node, target: Node):
	endpoint.connect("peer_connected", target, "_on_transport_peer_connected")
	endpoint.connect("peer_disconnected", target, "_on_transport_peer_disconnected")
	endpoint.connect("packet_received", target, "_on_transport_packet_received")


class TestSteam:
	extends Node
	var left_lobbies = []
	var version = "5.0.0"
	func getLobbyData(_lobby, _key):
		return version
	func leaveLobby(lobby):
		left_lobbies.append(lobby)
	func getNumLobbyMembers(_lobby):
		return 2
	func getLobbyMemberByIndex(_lobby, index):
		return "1" if index == 0 else "9"


func _two_player_resume(owner="2"):
	_reset()
	RunData.players_data = ["gear1", "gear2"]
	ProgressData.saved_run_state.players_data = RunData.players_data.duplicate()
	var reg = Registry.new()
	reg.assign(_owners(["1", owner]))
	return _resume(reg.metadata())


func _test_resume_recovery():
	var scene = _two_player_resume()
	session._steam = TestSteam.new()
	session._steam_transport = transport
	session._lobby_id = 42
	session._refresh_lobby_members()
	check(session._rejected_peer_keys.has("9"), "waiting mode rejects an early Steam newcomer")
	var before = CoopService.connected_players.duplicate(true)
	identity._open_assignment()
	check(session._connection_by_peer_key.has("9"), "opening reassignment immediately registers existing Steam members")
	check(CoopService.connected_players == before, "admitting a waiting member does not assign a saved character")
	session._seen_client_hello_by_steam_id["9"] = true
	identity._choices[1].select(2)
	identity._confirm_assignment()
	check(scene.finished and identity.registry.slots[1].owner_id == "9", "host can explicitly assign the replacement")
	session._steam.free()
	session._steam = null
	session._steam_transport = null
	session._lobby_id = 0

	scene = _two_player_resume()
	session._official_continue_auto_lobby_done_for_scene_id = scene.get_instance_id()
	session.leave_lobby()
	check(RunData.get_player_count() == 2 and RunData.players_data == ["gear1", "gear2"], "leaving Continue preserves every loaded character instead of resetting to SOLO")
	check(session._official_continue_auto_lobby_done_for_scene_id == 0, "leaving clears the automatic creation scene marker")
	session._poll_official_continue_auto_lobby()
	session._official_continue_auto_lobby_first_seen_msec = OS.get_ticks_msec() - 301
	session._poll_official_continue_auto_lobby()
	check(session._session_active and transport.hosting, "leaving on Continue permits a new automatic LAN room")
	identity.prepare_resume_if_needed()
	check(is_instance_valid(identity._panel), "recreated session rebuilds ownership UI")

	scene = _two_player_resume()
	session._session_active = false
	transport.host_result = ERR_CANT_CREATE
	session.create_session()
	check(not session._session_active and session._online_role == "none", "synchronous transport failures leave no phantom host session")
	check(is_instance_valid(identity._panel) and identity._status.text == "BROTATO_ONLINE_IDENTITY_SESSION_FAILED", "creation failure offers an explicit recovery panel")
	transport.host_result = OK
	identity._retry_session()
	identity.prepare_resume_if_needed()
	check(session._session_active and identity.is_resume_pending(), "retry can rebuild the identity transaction")
	identity._continue_offline()
	check(not identity.guards_resume(scene) and not session._session_active, "local continuation releases the vanilla guard after teardown")
	session._poll_official_continue_auto_lobby()
	check(not session._session_active, "local continuation suppresses automatic rehosting")
	var late_steam = TestSteam.new()
	session._steam = late_steam
	session._on_lobby_created(1, 99)
	check(not session._session_active and late_steam.left_lobbies == [99], "late Steam creation result cannot reopen a room after local continuation")
	session._steam = null
	late_steam.free()
	check(scene._players_to_join.empty() and not scene.finished, "offline queue accounts for already joined local P0")
	CoopService.connected_players.append([6, 1])
	CoopService.emit_signal("connected_players_updated", CoopService.connected_players)
	check(scene.finished, "vanilla local join can complete after online failure")

	scene = _two_player_resume()
	session._session_active = false
	transport.host_result = ERR_CANT_CREATE
	var steam_transport = load("res://transport.gd").new()
	steam_transport.available = true
	mod.add_child(steam_transport)
	session._steam_transport = steam_transport
	session.create_session()
	check(session._session_active and session._lobby_toggle_pending_create, "Steam creation may still be pending when LAN bind fails")
	session._on_lobby_created(15, 0)
	check(not session._session_active and is_instance_valid(identity._panel), "asynchronous Steam failure also offers local recovery when LAN is unavailable")
	steam_transport.free()
	session._steam_transport = null

	scene = _two_player_resume()
	transport.hosting = true
	session._lobby_toggle_pending_create = true
	session._on_lobby_created(2, 0)
	check(session._session_active and transport.hosting, "Steam failure preserves a healthy LAN room")


func _test_resume_feedback():
	var scene = _two_player_resume()
	session._register_remote_connection("2", transport, 20)
	identity._update_panel()
	identity._try_commit(false)
	check(identity._status.text.begins_with("BROTATO_ONLINE_IDENTITY_HANDSHAKE"), "automatic wait identifies the unfinished handshake")
	identity._open_assignment()
	identity._confirm_assignment()
	check(identity._status.text.begins_with("BROTATO_ONLINE_IDENTITY_HANDSHAKE") and not scene.finished, "manual confirm explains missing hello")
	session._seen_client_hello_by_steam_id["2"] = true
	CoopService.connected_players.append([6, 1])
	identity._confirm_assignment()
	check(identity._status.text.begins_with("BROTATO_ONLINE_IDENTITY_LOCAL_COUNT"), "extra joined local input reports required and actual counts")
	CoopService.connected_players.pop_back()
	session._on_transport_peer_disconnected(transport, 20)
	identity._confirm_assignment()
	check(identity._status.text.begins_with("BROTATO_ONLINE_IDENTITY_NOT_CONNECTED"), "manual confirm explains a player who disconnected after selection")

	scene = _two_player_resume()
	session._self_steam_id = identity.installation_peer_key()
	identity._try_commit(false)
	check(identity._status.text == "BROTATO_ONLINE_IDENTITY_HOST_CHANGED", "host identity change points to explicit recovery")

	var owner = "lan:" + Registry.random_id()
	scene = _two_player_resume(owner)
	identity._try_commit(false)
	check(identity._status.text == "BROTATO_ONLINE_IDENTITY_PROOF_MISSING", "missing saved proof points to reassignment")

	scene = _two_player_resume()
	session._register_remote_connection("2", transport, 20)
	session._register_remote_connection("9", transport, 90)
	identity._open_assignment()
	session._register_remote_connection("9", transport, 90)
	session._pending_p2p_chunk_sends = [{"target_steam_id": "9"}, {"target_steam_id": "2"}]
	session.commit_resume_peer_order([{"peer_key": "", "local_slot": 0}, {"peer_key": "2", "local_slot": 0}])
	check(session._pending_p2p_chunk_sends.size() == 1 and session._pending_p2p_chunk_sends[0].target_steam_id == "2", "unassigned peers lose their queued messages before disconnect")


func _test_lan_failure_and_refresh():
	_two_player_resume()
	var install = Registry.random_id()
	var owner = "lan:" + install
	var token = Registry.random_id()
	session._on_transport_peer_connected(transport, 90)
	var probe = transport.packets[0].message
	check(probe.msg_type == "transport_welcome" and probe.accepted and probe.protocol_version != 1 and probe.protocol_version != 2, "legacy-readable welcome reaches old clients' version check")
	check(probe.identity_required, "negotiation welcome cannot complete a current client join")
	session._handle_transport_identity(transport, 90, {"msg_type": "transport_identity", "run_id": identity.registry.run_id, "installation_id": install, "resume_token": token, "protocol_version": 3})
	check(transport.packets.back().message.reason == "resume_reassignment_required", "early LAN newcomer receives actionable refusal instead of room full")
	identity._open_assignment()
	session._on_transport_peer_connected(transport, 91)
	session._handle_transport_identity(transport, 91, {"msg_type": "transport_identity", "run_id": identity.registry.run_id, "installation_id": install, "resume_token": token, "protocol_version": 3})
	check(session._connection_by_peer_key.has(owner), "LAN newcomer can reconnect after reassignment opens")
	session._on_transport_peer_connected(transport, 92)
	session._handle_transport_identity(transport, 92, {"msg_type": "transport_identity", "run_id": identity.registry.run_id, "installation_id": install, "resume_token": token, "protocol_version": 3})
	check(transport.packets.back().message.reason == "duplicate_identity" and session._connection_by_peer_key[owner].peer == 91, "duplicate LAN identity gets a distinct error and preserves its live connection")

	_reset()
	session._session_active = false
	session._online_role = "client"
	session._pending_lan_join = true
	session._client_join_request_started_msec = OS.get_ticks_msec() - 12001
	session._poll_join_request_timeout()
	check(not session._pending_lan_join and session._online_role == "none" and session.failures.back() == "join_failed_timeout", "LAN handshake has a bounded timeout and clears joining state")
	session._online_role = "client"
	session._pending_lan_join = true
	session._handle_transport_identity(transport, 1, {"msg_type": "transport_identity_request", "run_id": "invalid", "protocol_version": 3, "mod_version": "5.0.0"})
	check(not session._pending_lan_join and session._online_role == "none" and session.failures.back() == "identity_failed", "unusable identity credentials clear pending state")
	session._online_role = "client"
	session._pending_lan_join = true
	session._handle_transport_welcome(transport, 1, {"accepted": false, "protocol_version": 1, "mod_version": "5.0.0"})
	check(session.failures.back() == "join_failed_protocol_mismatch", "version mismatch takes precedence over generic rejection")
	session._online_role = "client"
	session._pending_lan_join = true
	session._handle_transport_welcome(transport, 1, probe)
	check(session._pending_lan_join and not session._session_active, "current client waits for authentication after negotiation")
	var welcome = {"accepted": true, "protocol_version": 3, "mod_version": "5.0.0", "session_id": "test-session", "assigned_peer_key": owner, "host_peer_key": "1"}
	session._handle_transport_welcome(transport, 1, welcome)
	check(session._session_active and not session._pending_lan_join, "authenticated welcome completes initial join")
	session._online_flow_started = true
	session._online_flow_left_since_msec = 123
	session._client_join_request_started_msec = 456
	var hello_starts = session.hello_starts
	welcome.identity_refresh = true
	session._handle_transport_welcome(transport, 1, welcome)
	check(session._online_flow_started and session._online_flow_left_since_msec == 123 and session._client_join_request_started_msec == 456 and session.hello_starts == hello_starts, "credential rotation preserves established flow and hello retry state")


func _test_delayed_rotation_checkpoint():
	_reset()
	RunData.players_data = ["gear1", "gear2"]
	ProgressData.saved_run_state.players_data = RunData.players_data.duplicate()
	var install = Registry.random_id()
	var owner = "lan:" + install
	session._register_remote_connection(owner, transport, 50)
	var selection = Control.new()
	selection.filename = "res://ui/menus/character_selection.tscn"
	root.add_child(selection)
	get_tree().current_scene = selection
	identity._reset_for_new_selection()
	selection.filename = "res://ui/menus/shop/coop_shop.tscn"
	CoopService.connected_players = [[7, 0], [8, 0]]
	slots._remote_steam_id_by_device[8] = owner
	slots._device_by_remote_steam_id[owner] = 8
	slots._remote_devices.append(8)
	identity.persist_saved_identity()
	ProgressData.last_saved_run_state = ProgressData.saved_run_state.duplicate(true)
	var token = Registry.random_id()
	var before = ProgressData.saves
	session._handle_transport_identity(transport, 50, {"msg_type": "transport_identity", "run_id": identity.registry.run_id, "installation_id": install, "resume_token": token, "protocol_version": 3})
	check(ProgressData.saves == before and identity.load_saved_identity().slots[1].resume_hash == token.sha256_text() and not ProgressData.saved_run_state.has(Registry.SAVE_KEY), "delayed credential rotation repairs a checkpoint saved before the reply")


func _test_review_regressions():
	_reset()
	RunData.players_data = ["keyboard gear", "remote gear", "controller gear"]
	ProgressData.saved_run_state.players_data = RunData.players_data.duplicate()
	var registry = Registry.new()
	registry.assign([{"owner_id": "1", "local_slot": 0}, {"owner_id": "2", "local_slot": 0}, {"owner_id": "1", "local_slot": 1}])
	var scene = _resume(registry.metadata())
	CoopService.connected_players.append([6, 1])
	var bridge = identity._resume_bridge
	identity.bind_resume_scene(scene)
	check(identity._resume_bridge == bridge and scene.advance_count == 1, "deferred/removal binding is idempotent and cannot advance the vanilla queue")
	var saved_bytes = File.new().get_sha256("res://run_v3_0.json")
	identity._continue_offline()
	check(identity._resume_bridge._waiting_slot == 1 and not scene.finished, "offline asks for missing P1, retaining local P2")
	CoopService.connected_players.append([3, 1])
	CoopService.emit_signal("connected_players_updated", CoopService.connected_players)
	check(scene.finished and CoopService.connected_players == [[7, 0], [3, 1], [6, 1]], "offline restores nonadjacent local inputs to their saved characters")
	check(RunData.players_data == ["keyboard gear", "remote gear", "controller gear"], "offline join does not reorder or resize saved character data")
	check(File.new().get_sha256("res://run_v3_0.json") == saved_bytes, "offline fallback never rewrites the vanilla run file")

	scene = _two_player_resume()
	identity._pending = false
	identity.persist_saved_identity()
	var metadata = identity.load_saved_identity()
	check(not metadata.empty() and not ProgressData.saved_run_state.has(Registry.SAVE_KEY), "ownership lives only in the mod sidecar")
	ProgressData.SAVE_PATH = "res://save_v3_1.json"
	check(identity.load_saved_identity().empty(), "a different profile cannot inherit the previous profile's owners")
	ProgressData.SAVE_PATH = "res://save_v3_0.json"
	var file = File.new()
	file.open("res://run_v3_0.json", File.WRITE)
	file.store_string("a different run with the same character count")
	file.close()
	check(identity.load_saved_identity().empty(), "replaced save bytes cannot reuse stale ownership")
	var installed = Registry.random_id()
	identity.registry.run_id = Registry.random_id()
	identity.accept_lan_identity(installed, Registry.random_id(), true)
	check(identity.load_saved_identity().empty(), "new-run credential reply cannot attach metadata to an older on-disk checkpoint")

	for continuing in [false, true]:
		if continuing:
			_two_player_resume()
		else:
			_reset()
		var steam = TestSteam.new()
		session._steam = steam
		steam.version = "4.0.0"
		check(not session._is_lobby_protocol_compatible(42), "new client rejects old host, Continue=" + str(continuing))
		steam.version = "5.0.0"
		check(session._is_lobby_protocol_compatible(42), "current Steam host version accepted")
		check(not session._accept_client_protocol("2", {"mod_version": "4.0.0"}) and session.kicked.has("2"), "new host rejects old client, Continue=" + str(continuing))
		check(not session._seen_client_hello_by_steam_id.has("2"), "incompatible hello never counts as ready")
		check(session._accept_client_protocol("3", {"mod_version": "5.0.0"}), "current client protocol accepted")
		session._steam = null
		steam.free()


func _test_loopback_refusal():
	_two_player_resume()
	var host_transport = load("res://scripts/lan_transport.gd").new()
	mod.add_child(host_transport)
	session._lan_transport = host_transport
	_bind_transport(host_transport, session)
	var group = Node.new()
	root.add_child(group)
	var client = load("res://session.gd").new()
	client.name = "BrotatoOnlineSessionManager"
	client._session_active = false
	client._online_role = "client"
	client._pending_lan_join = true
	group.add_child(client)
	var client_identity = load("res://scripts/player_identity_manager.gd").new()
	client_identity.name = "BrotatoOnlinePlayerIdentityManager"
	group.add_child(client_identity)
	client_identity.set_process(false)
	var client_transport = load("res://scripts/lan_transport.gd").new()
	group.add_child(client_transport)
	client._lan_transport = client_transport
	_bind_transport(client_transport, client)
	var port = 30000 + int(OS.get_ticks_usec() % 1000)
	check(host_transport.start_host(port) == OK and client_transport.start_client("127.0.0.1", port) == OK, "refusal loopback starts")
	var deadline = OS.get_ticks_msec() + 1500
	while client.failures.empty() and OS.get_ticks_msec() < deadline:
		yield(get_tree().create_timer(0.02), "timeout")
	check(not client.failures.empty() and client.failures.back() == "resume_reassignment_required", "real ENet newcomer receives actionable refusal before disconnection")
	check(not client._pending_lan_join and client._online_role == "none", "real refusal clears LAN joining state")
	client_transport.stop()
	host_transport.stop()
	group.free()
	host_transport.free()
	session._lan_transport = transport
