extends Node

const Registry = preload("player_identity_registry.gd")
const STORAGE_DIR = "user://mod_data/six666-BrotatoOnline"
const CLIENT_FILE = STORAGE_DIR + "/client_identity.cfg"
const RUN_FILE = STORAGE_DIR + "/saved_identities.cfg"
const ResumeBridge = preload("../extensions/coop_resume_player_identity.gd")
var registry = Registry.new()
var _credentials = ConfigFile.new()
var _installation_id = ""
var _lan_hashes = {}
var _resume_scene = null
var _pending = false
var _prepared_scene_id = 0
var _manual = false
var _panel = null
var _status = null
var _choices = []
var _candidates_key = ""
var _poll_elapsed = 0.0
var _last_selection_scene_id = 0
var _last_status_mode = ""
var _offline_resume = false
var _legacy_save = false
var _resume_bridge = null


func _ready() -> void:
	Directory.new().make_dir_recursive(STORAGE_DIR)
	if _credentials.load(CLIENT_FILE) != OK:
		_credentials.load("user://brotato_online_identity.cfg")
	_installation_id = str(_credentials.get_value("identity", "installation_id", ""))
	if not Registry.is_random_id(_installation_id):
		_installation_id = Registry.random_id()
		_credentials.set_value("identity", "installation_id", _installation_id)
		_credentials.save(CLIENT_FILE)
	get_tree().connect("node_added", self, "_on_node_added")


func _on_node_added(node: Node) -> void:
	if str(node.filename).ends_with("/coop_resume.tscn"):
		call_deferred("bind_resume_scene", node)


func bind_resume_scene(scene: Node) -> void:
	if not is_instance_valid(scene) or scene.has_node("BrotatoOnlineIdentityResume"):
		return
	_resume_bridge = ResumeBridge.new()
	_resume_bridge.name = "BrotatoOnlineIdentityResume"
	scene.add_child(_resume_bridge)
	_resume_bridge.bind(scene, self)


func installation_peer_key() -> String:
	return "lan:" + _installation_id


func client_identity_for_run(run_id: String) -> Dictionary:
	if not Registry.is_random_id(run_id):
		return {}
	var token = str(_credentials.get_value("runs", run_id, ""))
	if not Registry.is_random_id(token):
		token = Registry.random_id()
		_credentials.set_value("runs", run_id, token)
		if _credentials.save(CLIENT_FILE) != OK:
			return {}
	return {"installation_id": _installation_id, "resume_token": token}


func _session():
	return get_parent().get_node_or_null("BrotatoOnlineSessionManager")


func _slots():
	return get_parent().get_node_or_null("BrotatoOnlineOnlinePlayerSlotManager")


func _is_host() -> bool:
	var session = _session()
	return session != null and session.is_online_session_active() and session.is_game_host()


func attach_resume_scene(scene: Node) -> void:
	_resume_scene = scene
	_offline_resume = false
	_prepared_scene_id = 0
	_pending = true
	_manual = false
	_choices.clear()
	_candidates_key = ""
	_panel = null
	_status = null
	_last_status_mode = ""


func guards_resume(scene: Node) -> bool:
	var session = _session()
	return scene == _resume_scene and not _offline_resume and session != null and (session.AUTO_CREATE_LOBBY_ON_OFFICIAL_COOP_CONTINUE or _is_host())


func wants_offline_resume(scene: Node) -> bool:
	return scene == _resume_scene and _offline_resume


func prepare_resume_if_needed() -> bool:
	if _offline_resume or not _is_host() or not is_instance_valid(_resume_scene) or get_tree().current_scene != _resume_scene:
		return false
	if _prepared_scene_id != _resume_scene.get_instance_id():
		_prepared_scene_id = _resume_scene.get_instance_id()
		_session()._unlock_online_run_slots()
		registry = Registry.new()
		_lan_hashes.clear()
		_manual = not registry.load_metadata(load_saved_identity(), RunData.get_player_count())
		_legacy_save = _manual
		if registry.run_id == "":
			registry.run_id = Registry.random_id()
		for slot in registry.slots:
			if str(slot.resume_hash) != "":
				_lan_hashes[str(slot.owner_id)] = str(slot.resume_hash)
		_pending = true
		_clear_panel()
		_build_panel()
	return _pending


func is_resume_pending() -> bool:
	return _pending and is_instance_valid(_resume_scene) and get_tree().current_scene == _resume_scene and _is_host()


func run_id_for_handshake() -> String:
	_reset_for_new_selection()
	prepare_resume_if_needed()
	if registry.run_id == "":
		registry.run_id = Registry.random_id()
	return registry.run_id


func accept_lan_identity(installation_id: String, token: String, authenticated_existing_connection: bool = false) -> bool:
	if not Registry.is_random_id(installation_id) or not Registry.is_random_id(token):
		return false
	prepare_resume_if_needed()
	var owner = "lan:" + installation_id
	if _lan_hashes.has(owner):
		return str(_lan_hashes[owner]) == token.sha256_text()
	if authenticated_existing_connection:
		# A new run in the same room rotates credentials on the already verified
		# connection. This cannot be used by a new transport peer to claim a save.
		_lan_hashes[owner] = token.sha256_text()
		for slot in registry.slots:
			if str(slot.owner_id) == owner:
				slot.resume_hash = str(_lan_hashes[owner])
		# A late reply may repair an already-written checkpoint from this run,
		# never overwrite the sidecar of the previous run still on disk.
		if str(load_saved_identity().get("run_id", "")) == registry.run_id:
			persist_saved_identity()
		return true
	if is_resume_pending() and not _manual and registry.index_for_owner(owner) >= 0:
		# A saved LAN owner without a proof is never silently trusted.
		return registry.lan_proof_valid(owner, token)
	if _session()._should_freeze_online_run_slots():
		return false
	_lan_hashes[owner] = token.sha256_text()
	return true


func can_admit_peer(peer_key: String) -> bool:
	prepare_resume_if_needed()
	# The host must open reassignment before a stranger can occupy a waiting seat.
	if is_resume_pending() and not _manual and registry.index_for_owner(peer_key) < 0:
		return false
	return peer_key != "" and peer_key != _session().get_self_steam_id()


func reset_online_session_state() -> void:
	registry = Registry.new()
	_lan_hashes.clear()
	_prepared_scene_id = 0
	_pending = false
	_clear_panel()


func _clear_panel() -> void:
	if is_instance_valid(_panel):
		_panel.get_parent().queue_free()
	_panel = null
	_status = null
	_choices.clear()
	_candidates_key = ""
	_last_status_mode = ""


func show_resume_session_failure() -> void:
	if not is_instance_valid(_resume_scene) or get_tree().current_scene != _resume_scene or _offline_resume:
		return
	_clear_panel()
	var box = _create_panel_box()
	_status.text = _text("BROTATO_ONLINE_IDENTITY_SESSION_FAILED")
	var retry = Button.new()
	retry.text = _text("BROTATO_ONLINE_IDENTITY_RETRY")
	retry.connect("pressed", self, "_retry_session")
	box.add_child(retry)
	_add_offline_button(box)


func _retry_session() -> void:
	_clear_panel()
	_session().create_lobby_and_invite(false)


func _continue_offline() -> void:
	# Capture the mapping before teardown removes remote placeholders and clears
	# the registry. A host's second input can belong to P2 rather than P1.
	var inputs = {}
	var local_indices = _slots().get_local_player_indices()
	var host = _session().get_self_steam_id()
	for local_slot in range(local_indices.size()):
		var saved_index = registry.index_for_owner(host, local_slot)
		if saved_index < 0 and local_slot == 0:
			saved_index = 0
		if saved_index >= 0:
			inputs[saved_index] = CoopService.connected_players[int(local_indices[local_slot])].duplicate()
	_session().leave_lobby()
	_offline_resume = true
	_resume_bridge.identity_resume_offline(inputs)


func _add_offline_button(box: Node) -> void:
	var button = Button.new()
	button.text = _text("BROTATO_ONLINE_IDENTITY_OFFLINE")
	button.connect("pressed", self, "_continue_offline")
	box.add_child(button)


func _process(delta: float) -> void:
	_poll_elapsed += delta
	if _poll_elapsed < 0.2:
		return
	_poll_elapsed = 0.0
	if not _is_host():
		return
	if _reset_for_new_selection():
		return
	if not prepare_resume_if_needed():
		return
	if _slots().get_local_player_indices().empty():
		_slots()._ensure_host_player_joined()
	_update_panel()
	if not _manual:
		_try_commit(false)


func _reset_for_new_selection() -> bool:
	var scene = get_tree().current_scene
	if scene == null or not str(scene.filename).ends_with("/character_selection.tscn"):
		return false
	if _last_selection_scene_id != scene.get_instance_id():
		_last_selection_scene_id = scene.get_instance_id()
		registry = Registry.new()
		registry.run_id = Registry.random_id()
		_lan_hashes.clear()
		_session().refresh_lan_identities_for_run(registry.run_id)
	return true


func _capture_current_owners() -> Array:
	var owners = []
	var local_slot = 0
	for index in range(CoopService.connected_players.size()):
		var owner = _slots().get_remote_steam_id(index)
		if owner == "":
			owner = _session().get_self_steam_id()
			owners.append({"owner_id": owner, "local_slot": local_slot})
			local_slot += 1
		else:
			owners.append({"owner_id": owner, "local_slot": 0})
	return owners


func _metadata_for_state(state: Dictionary) -> Dictionary:
	if not _is_host() or not bool(state.get("has_run_state", false)) or is_resume_pending():
		return {}
	var player_count = RunData.get_player_count()
	if registry.slots.empty():
		var owners = _capture_current_owners()
		if owners.size() != player_count:
			return {}
		registry.assign(owners, _lan_hashes)
	if registry.slots.size() != player_count:
		return {}
	var indices = state.get("bo_roster_slots", [])
	if state.get("players_data", []).size() == player_count:
		indices = []
	return registry.metadata(indices)


func _checkpoint_key() -> String:
	# Bind metadata to the bytes actually written by the vanilla save loader,
	# including the profile path. Copied/replaced runs cannot inherit stale owners.
	var path = str(ProgressData.SAVE_PATH).replace("save_v3_", "run_v3_")
	if not File.new().file_exists(path):
		return ""
	return path.sha256_text() + ":" + File.new().get_sha256(path)


func load_saved_identity() -> Dictionary:
	var store = ConfigFile.new()
	if store.load(RUN_FILE) != OK:
		return {}
	var metadata = store.get_value("checkpoints", _checkpoint_key(), {})
	return metadata if typeof(metadata) == TYPE_DICTIONARY else {}


func persist_saved_identity() -> void:
	var key = _checkpoint_key()
	var metadata = _metadata_for_state(ProgressData.saved_run_state)
	if key == "" or metadata.empty():
		return
	var store = ConfigFile.new()
	store.load(RUN_FILE)
	store.set_value("checkpoints", key, metadata)
	# Retain recent checkpoint backups without growing the file indefinitely.
	var keys = store.get_section_keys("checkpoints")
	while keys.size() > 64:
		store.erase_section_key("checkpoints", keys[0])
		keys.remove(0)
	if store.save(RUN_FILE) != OK:
		push_error("BrotatoOnline: could not save player identities to " + RUN_FILE)


func compact_slots(kept: Array) -> void:
	if registry.slots.empty():
		return
	registry.compact(kept)


func _create_panel_box():
	var canvas = CanvasLayer.new()
	canvas.layer = 90
	_resume_scene.add_child(canvas)
	_panel = PanelContainer.new()
	_panel.theme = _resume_scene.theme
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.margin_left = -450
	_panel.margin_right = 450
	_panel.margin_top = -180
	_panel.margin_bottom = 180
	canvas.add_child(_panel)
	var margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_constant_override("margin_" + side, 16)
	_panel.add_child(margin)
	var box = VBoxContainer.new()
	box.add_constant_override("separation", 12)
	margin.add_child(box)
	var title = Label.new()
	title.text = _text("BROTATO_ONLINE_IDENTITY_TITLE")
	box.add_child(title)
	_status = Label.new()
	_status.autowrap = true
	_status.rect_min_size = Vector2(550, 65)
	box.add_child(_status)
	return box


func _build_panel() -> void:
	var box = _create_panel_box()
	for index in range(RunData.get_player_count()):
		var row = HBoxContainer.new()
		box.add_child(row)
		var label = Label.new()
		label.text = "P" + str(index + 1)
		var character = RunData.get_player_character(index)
		if character != null:
			label.text += "  " + tr(str(character.name))
		label.rect_min_size.x = 200
		label.clip_text = true
		label.hint_tooltip = label.text
		row.add_child(label)
		var choice = OptionButton.new()
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.clip_text = true
		row.add_child(choice)
		_choices.append(choice)
	var assign = Button.new()
	assign.text = _text("BROTATO_ONLINE_IDENTITY_ASSIGN")
	assign.name = "ReassignIdentity"
	assign.connect("pressed", self, "_open_assignment")
	box.add_child(assign)
	var confirm = Button.new()
	confirm.text = _text("BROTATO_ONLINE_IDENTITY_CONFIRM")
	confirm.connect("pressed", self, "_confirm_assignment")
	box.add_child(confirm)
	confirm.name = "ConfirmIdentity"
	_add_offline_button(box)


func _text(key: String) -> String:
	var i18n = get_parent().get_node_or_null("BrotatoOnlineI18n")
	return i18n.get_text(key) if i18n != null else tr(key)


func _owner_label(owner: String, local_slot: int = 0) -> String:
	if owner == _session().get_self_steam_id():
		return _text("BROTATO_ONLINE_IDENTITY_LOCAL") + " " + str(local_slot + 1)
	var label = _session().get_peer_display_name(owner)
	if label != "":
		return label
	return "LAN " + owner.substr(4, 8) if owner.begins_with("lan:") else owner


func _candidates() -> Array:
	var result = []
	var host = _session().get_self_steam_id()
	var locals = _slots().get_local_player_indices()
	for index in range(locals.size()):
		result.append({"owner_id": host, "local_slot": index, "label": _text("BROTATO_ONLINE_IDENTITY_LOCAL") + " " + str(index + 1)})
	for peer in _session()._connection_by_peer_key.keys():
		if str(peer) == host:
			continue
		var label = _owner_label(str(peer))
		result.append({"owner_id": str(peer), "local_slot": 0, "label": label})
	return result


func _update_panel() -> void:
	if not is_instance_valid(_panel):
		return
	var candidates = _candidates()
	var key = str(_manual) + to_json(candidates)
	if key != _candidates_key:
		_candidates_key = key
		for index in range(_choices.size()):
			var choice = _choices[index]
			var previous = choice.get_item_metadata(choice.selected) if choice.selected > 0 else {}
			choice.clear()
			choice.add_item(_text("BROTATO_ONLINE_IDENTITY_UNASSIGNED"))
			for candidate in candidates:
				if index == 0 and _manual and (str(candidate.owner_id) != _session().get_self_steam_id() or int(candidate.local_slot) != 0):
					continue
				choice.add_item(candidate.label)
				choice.set_item_metadata(choice.get_item_count() - 1, candidate)
				var saved = registry.slots[index] if index < registry.slots.size() else {}
				var desired = previous if not previous.empty() else saved
				if str(desired.get("owner_id", "")) == str(candidate.owner_id) and int(desired.get("local_slot", -1)) == int(candidate.local_slot):
					choice.select(choice.get_item_count() - 1)
			if index == 0 and _manual and choice.get_item_count() == 2:
				choice.select(1)
			if not _manual and choice.selected <= 0 and index < registry.slots.size():
				var expected = registry.slots[index]
				var name = _owner_label(str(expected.owner_id), int(expected.local_slot))
				choice.add_item(name + " — " + _text("BROTATO_ONLINE_IDENTITY_ABSENT"))
				choice.select(choice.get_item_count() - 1)
				choice.set_item_metadata(choice.selected, expected)
	for choice in _choices:
		choice.disabled = not _manual
	var confirm = _panel.find_node("ConfirmIdentity", true, false)
	confirm.visible = _manual
	_panel.find_node("ReassignIdentity", true, false).visible = not _manual
	var mode = "manual" if _manual else "waiting"
	if mode != _last_status_mode:
		_last_status_mode = mode
		_status.text = _text("BROTATO_ONLINE_IDENTITY_LEGACY" if _legacy_save else "BROTATO_ONLINE_IDENTITY_ASSIGN_HINT") if _manual else _text("BROTATO_ONLINE_IDENTITY_WAITING")


func _open_assignment() -> void:
	_manual = true
	_session().refresh_resume_candidates()
	_update_panel()


func _confirm_assignment() -> void:
	_try_commit(true)


func _resume_problem(key: String, values: Array = []) -> void:
	if is_instance_valid(_status):
		var text = _text(key)
		_status.text = text % values if not values.empty() and text.find("%s") >= 0 else text


func _try_commit(manual: bool) -> void:
	var owners = []
	if manual:
		for choice in _choices:
			if choice.selected <= 0:
				_status.text = _text("BROTATO_ONLINE_IDENTITY_INVALID")
				return
			owners.append(choice.get_item_metadata(choice.selected).duplicate())
	else:
		owners = registry.slots.duplicate(true)
	if owners.size() != RunData.get_player_count():
		_resume_problem("BROTATO_ONLINE_IDENTITY_INVALID")
		return
	var seen = []
	var layout = []
	var host = _session().get_self_steam_id()
	if not owners.empty() and str(owners[0].owner_id) != host:
		_resume_problem("BROTATO_ONLINE_IDENTITY_HOST_CHANGED")
		return
	var required_locals = 0
	for owner in owners:
		var key = str(owner.owner_id)
		var local_slot = int(owner.local_slot)
		var unique_key = key + ":" + str(local_slot)
		if seen.has(unique_key):
			_status.text = _text("BROTATO_ONLINE_IDENTITY_INVALID")
			return
		seen.append(unique_key)
		if key == host:
			required_locals += 1
		elif not manual and key.begins_with("lan:") and str(owner.get("resume_hash", "")) == "":
			_resume_problem("BROTATO_ONLINE_IDENTITY_PROOF_MISSING")
			return
		if key != host and (local_slot != 0 or not _session()._connection_by_peer_key.has(key)):
			_resume_problem("BROTATO_ONLINE_IDENTITY_NOT_CONNECTED", [_owner_label(key)])
			return
		if key != host and not _session()._seen_client_hello_by_steam_id.has(key):
			# Steam lobby membership alone does not mean the mod client is ready.
			_resume_problem("BROTATO_ONLINE_IDENTITY_HANDSHAKE", [_owner_label(key)])
			return
		layout.append({"peer_key": "" if key == host else key, "local_slot": local_slot})
	# Host P0 is a vanilla invariant throughout this mod (camera, shops, menus).
	if layout.empty() or str(layout[0].peer_key) != "" or int(layout[0].local_slot) != 0:
		_status.text = _text("BROTATO_ONLINE_IDENTITY_HOST_FIRST")
		return
	var local_count = _slots().get_local_player_indices().size()
	if required_locals != local_count:
		_resume_problem("BROTATO_ONLINE_IDENTITY_LOCAL_COUNT", [required_locals, local_count])
		return
	if not _slots().apply_resume_identity_layout(layout):
		_resume_problem("BROTATO_ONLINE_IDENTITY_INVALID")
		return
	registry.assign(owners, _lan_hashes)
	_pending = false
	_session()._lock_online_run_slots("resume_identity_commit")
	_session().commit_resume_peer_order(layout)
	persist_saved_identity()
	_resume_bridge.identity_resume_committed()
