extends Node

# Player indices stay stable while Main still owns actors, projectiles and rewards.
# Compact only after disposing that scene, then publish one authoritative roster.
const SAVE_ARRAYS = ["players_data", "locked_shop_items", "tracked_item_effects", "shop_items", "reroll_count", "paid_reroll_count", "initial_free_rerolls", "free_rerolls", "item_steals"]
const RUN_ARRAYS = ["locked_shop_items", "tracked_item_effects", "_players_die_args", "remove_speed_effect_cache", "items_nb_cache", "different_items_nb_cache", "duplicate_items_cache", "max_consumable_stats_gained_this_wave", "_are_player_stats_dirty", "current_charmed_enemies", "steps_taken_this_wave"]
const CONTROL_MESSAGES = ["player_kicked", "player_removed", "player_roster_commit"]

var revision = 0
var transitioning = false
var _removed = {} # old player_index -> peer key
var _affects_saved_run = false
var _last_poll_msec = 0
var _progression_finished_key = ""
var _kick_notice_pending = false
var _pending_client_roster = {}
var _exiting_after_kick = false


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	set_process(true)


func _session() -> Node:
	return get_parent().get_node_or_null("BrotatoOnlineSessionManager")


func _slots() -> Node:
	return get_parent().get_node_or_null("BrotatoOnlineOnlinePlayerSlotManager")


func _menu() -> Node:
	return get_parent().get_node_or_null("BrotatoOnlineMenuSyncManager")


func _is_host() -> bool:
	return _session() != null and _session().is_online_session_active() and _session().is_game_host()


func is_player_removed(player_index: int) -> bool:
	return _removed.has(player_index)


func can_kick_peer(peer_key: String) -> bool:
	if not _is_host() or transitioning or peer_key == "" or peer_key == _session().get_self_steam_id():
		return false
	var slots = _slots()
	if slots == null or not _session()._session_remote_peer_keys.has(peer_key):
		return false
	var index = int(slots.get_player_index_for_steam_id(peer_key))
	if index < 0 or index >= RunData.get_player_count() or not slots.is_remote_player_index(index) or _removed.has(index):
		return false
	# A committed scene-start handshake must finish before changing its participants.
	return _session()._pending_host_game_start.empty() and get_tree().current_scene != null


func kick_peer(peer_key: String) -> void:
	if not can_kick_peer(peer_key):
		return
	# Leave the button's signal stack before killing a player or disposing a menu.
	call_deferred("_kick_peer_deferred", peer_key)


func _kick_peer_deferred(peer_key: String) -> void:
	if not can_kick_peer(peer_key):
		return
	var index = int(_slots().get_player_index_for_steam_id(peer_key))
	_affects_saved_run = _affects_saved_run or _session()._online_flow_started or _session()._is_in_active_online_run_scene()
	_removed[index] = peer_key
	_trace("kick", "player_index=" + str(index))
	_session().detach_kicked_peer(peer_key)
	_session().broadcast_message({"msg_type": "player_removed", "removed_indices": _removed.keys()}, "", true)
	var input_manager = get_parent().get_node_or_null("BrotatoOnlineOnlineInputManager")
	if input_manager != null:
		input_manager.clear_remote_inputs()
	_persist_checkpoint_removals()
	_trace("checkpoint_saved")
	_refresh_player_list()
	_poll_pending_removals()


func _process(_delta: float) -> void:
	if _kick_notice_pending:
		_show_kicked_notice()
	var now = OS.get_ticks_msec()
	if transitioning or _removed.empty() or now - _last_poll_msec < 100:
		return
	_last_poll_msec = now
	_poll_pending_removals()


func _poll_pending_removals() -> void:
	var scene = get_tree().current_scene
	if scene == null or not is_instance_valid(scene) or transitioning:
		return
	if str(scene.filename) == "res://main.tscn":
		_disable_removed_actors_and_rewards(scene)
	elif _is_host():
		transitioning = true
		call_deferred("_commit_host_removal", scene.get_instance_id())


func _disable_removed_actors_and_rewards(scene: Node) -> void:
	var players = scene.get("_players")
	for value in _removed.keys():
		var index = int(value)
		if typeof(players) == TYPE_ARRAY and index < players.size():
			var player = players[index]
			if player != null and is_instance_valid(player):
				if not bool(scene.get("_cleaning_up")) and not bool(player.get("dead")) and player.has_method("die"):
					player.die()
				player.hide()
		for property in ["_upgrades_to_process", "_consumables_to_process"]:
			_clear_player_queue(scene, property, index)
	var ui = _menu()._find_progression_ui(false)
	if ui == null or not is_instance_valid(ui) or not ui.visible:
		return
	var changed = false
	for value in _removed.keys():
		var index = int(value)
		for property in ["_upgrades_to_process", "_consumables_to_process", "_extra_items_to_process"]:
			_clear_player_queue(ui, property, index)
		var choosing = ui.get("_player_is_choosing")
		if typeof(choosing) == TYPE_ARRAY and index < choosing.size():
			changed = changed or bool(choosing[index])
			choosing[index] = false
		var showing = ui.get("_showing_option")
		if typeof(showing) == TYPE_ARRAY and index < showing.size():
			showing[index] = null
		var container = ui._get_player_container(index)
		if container != null and is_instance_valid(container):
			container.finish()
			container.hide()
	# Only the Host advances progression; clear the removed player's current option
	# as well as future rewards so no dead slot can keep options_processed waiting.
	if _is_host() and changed and not ui._show_next_player_options():
		var key = str(ui.get_instance_id()) + ":" + str(RunData.current_wave)
		if key != _progression_finished_key:
			_progression_finished_key = key
			_menu().call_deferred("_emit_progression_options_processed_safely", ui.get_instance_id(), int(RunData.current_wave))


func _clear_player_queue(node: Node, property: String, index: int) -> void:
	var queues = node.get(property)
	if typeof(queues) == TYPE_ARRAY and index >= 0 and index < queues.size() and typeof(queues[index]) == TYPE_ARRAY:
		queues[index].clear()


func _kept_indices(count: int) -> Array:
	var kept = []
	for index in range(count):
		if not _removed.has(index):
			kept.append(index)
	return kept


func _select_array(source: Array, kept: Array, pad: bool = false) -> Array:
	var result = []
	for index in kept:
		if int(index) < source.size():
			result.append(source[int(index)])
	if pad and not source.empty():
		while result.size() < source.size():
			var sample = source[0]
			if typeof(sample) == TYPE_ARRAY:
				result.append([])
			elif typeof(sample) == TYPE_DICTIONARY:
				result.append({})
			elif typeof(sample) == TYPE_BOOL:
				result.append(false)
			elif typeof(sample) == TYPE_INT or typeof(sample) == TYPE_REAL:
				result.append(0)
			else:
				result.append(null)
	return result


func filter_saved_state(state: Dictionary) -> Dictionary:
	if not _is_host() or not _affects_saved_run or _removed.empty() or not bool(state.get("has_run_state", false)):
		return state
	var players = state.get("players_data", [])
	if typeof(players) != TYPE_ARRAY or players.empty():
		return state
	var original_indices = range(players.size())
	if int(state.get("bo_roster_revision", -1)) == revision:
		original_indices = state.get("bo_roster_slots", original_indices)
	var kept_positions = []
	var kept_slots = []
	for position in range(players.size()):
		if position < original_indices.size() and not _removed.has(int(original_indices[position])):
			kept_positions.append(position)
			kept_slots.append(int(original_indices[position]))
	if kept_positions.empty():
		return state
	var result = state.duplicate()
	for key in SAVE_ARRAYS:
		var value = state.get(key, null)
		if typeof(value) == TYPE_ARRAY:
			result[key] = _select_array(value, kept_positions, key != "players_data")
	result["bo_roster_revision"] = revision
	result["bo_roster_slots"] = kept_slots
	return result


func _persist_checkpoint_removals() -> void:
	if not _is_host() or not _affects_saved_run:
		return
	ProgressData.saved_run_state = filter_saved_state(ProgressData.saved_run_state)
	ProgressData.last_saved_run_state = filter_saved_state(ProgressData.last_saved_run_state)
	ProgressData.save()


func _capture_shop_save(scene: Node) -> Dictionary:
	if not scene.has_method("get_player_shop_items"):
		return {}
	return ProgressData.get_run_state(scene.get("_shop_items"), scene.get("_reroll_count"), scene.get("_paid_reroll_count"), scene.get("_initial_free_rerolls"), scene.get("_free_rerolls"), scene.get("_item_steals"))


func _dispose_current_scene() -> void:
	var scene = get_tree().current_scene
	if scene == null:
		return
	var overlay = get_parent().get_node_or_null("BrotatoOnlinePlayerListOverlay")
	if overlay != null:
		overlay._close_overlay()
	_menu()._clear_focus_emulators_before_client_scene_change("roster", "roster")
	_session()._freeze_scene_branch_for_host_disconnect(scene)
	# Reconstructing the same shop must not trigger Fish Hook's on-leaving-shop roll.
	if scene.is_connected("tree_exited", scene, "_on_tree_exited"):
		scene.disconnect("tree_exited", scene, "_on_tree_exited")
	# Match SceneTree's teardown: free while attached so exit callbacks still have
	# the old scene/tree. Node destruction detaches it and clears current_scene.
	scene.free()
	get_tree().current_scene = null


func _reset_indexed_caches() -> void:
	_menu().reset_after_player_roster_change()
	_session().reset_after_player_roster_change()
	var input_manager = get_parent().get_node_or_null("BrotatoOnlineOnlineInputManager")
	if input_manager != null:
		input_manager.clear_remote_inputs()
	RunData.reset_run_caches()
	TempStats.reset()
	LinkedStats.reset()
	_refresh_player_list()


func _commit_host_removal(scene_id: int) -> void:
	var scene = get_tree().current_scene
	if not _is_host() or _removed.empty() or scene == null or scene.get_instance_id() != scene_id or str(scene.filename) == "res://main.tscn":
		transitioning = false
		return
	var path = str(scene.filename)
	var packed = load(path)
	if packed == null or not (packed is PackedScene):
		transitioning = false
		return
	_trace("host_begin", path)
	var shop_save = _capture_shop_save(scene)
	var shop_states = _menu()._build_all_shop_player_states_for_menu_scene() if not shop_save.empty() else []
	_trace("shop_captured", path)
	var kept = _kept_indices(RunData.get_player_count())
	if kept.empty():
		transitioning = false
		return
	var removed_indices = _removed.keys()
	var lock_run = _slots().are_online_run_slots_locked()
	var was_paused = get_tree().paused
	_dispose_current_scene()
	_trace("old_scene_freed")
	RunData.players_data = _select_array(RunData.players_data, kept)
	for property in RUN_ARRAYS:
		var value = RunData.get(property)
		if typeof(value) == TYPE_ARRAY:
			RunData.set(property, _select_array(value, kept, true))
	# The old wave snapshot is only used for retry. It must never resurrect a deleted
	# player after the topology has been compacted.
	for key in SAVE_ARRAYS:
		var value = RunData.start_wave_state.get(key, null)
		if typeof(value) == TYPE_ARRAY:
			RunData.start_wave_state[key] = _select_array(value, kept, key != "players_data")
	_slots().remove_online_player_slots(removed_indices)
	revision += 1
	_removed.clear()
	_affects_saved_run = false
	_reset_indexed_caches()
	_trace("roster_compacted")
	if not shop_save.empty():
		shop_save["bo_roster_revision"] = revision
		shop_save["bo_roster_slots"] = range(RunData.get_player_count())
		ProgressData.saved_run_state = shop_save
		ProgressData.last_saved_run_state = shop_save
		RunData.resumed_from_state_in_shop = true
	get_tree().paused = false
	if path.ends_with("/character_selection.tscn"):
		RunData.menu_selection_back = true
	# SceneTree sets current_scene BEFORE entering the new scene. Adding a node
	# manually and setting current_scene afterwards leaves vanilla BaseShop._ready
	# calling Utils.focus_player_control() against a null scene.
	var error = get_tree().change_scene_to(packed)
	if error != OK:
		_trace("host_scene_error", str(error))
		transitioning = false
		return
	call_deferred("_finish_host_removal", path, kept, shop_states, lock_run, was_paused, _session()._online_session_generation)


func _finish_host_removal(path: String, kept: Array, shop_states: Array, lock_run: bool, was_paused: bool, generation: int) -> void:
	if generation != _session()._online_session_generation or not _is_host():
		return
	var next_scene = get_tree().current_scene
	if next_scene == null or str(next_scene.filename) != path:
		_trace("host_scene_not_ready", path)
		transitioning = false
		return
	_trace("host_scene_ready", path)
	if not shop_states.empty():
		var remaining_shop_states = []
		for new_index in range(kept.size()):
			var old_index = int(kept[new_index])
			if old_index < shop_states.size():
				var player_state = shop_states[old_index].duplicate(true)
				player_state["player_index"] = new_index
				player_state["pressed_go"] = false
				remaining_shop_states.append(player_state)
		_menu()._apply_all_shop_states_to_ui(remaining_shop_states)
		_save_current_shop(next_scene)
	# Rebuilding the official Continue page retains players who already rejoined.
	if path.ends_with("/coop_resume.tscn"):
		for _index in range(CoopService.connected_players.size()):
			next_scene._on_connected_players_updated(CoopService.connected_players)
	var state = _menu().build_menu_scene_state(true, true, true)
	state["scene_path"] = path
	state["run_config"]["run_config_source"] = "player_removed"
	state["run_config"]["full_player_run_data_authoritative"] = true
	state["run_config"]["shop_effects_checked"] = RunData.shop_effects_checked
	var packet = {"msg_type": "player_roster_commit", "revision": revision, "state": state, "lock_run": lock_run}
	_session().broadcast_message(packet, "", true)
	transitioning = false
	if was_paused and next_scene.has_method("on_paused"):
		var pause_menu = next_scene.get("_pause_menu")
		if pause_menu != null:
			pause_menu.pause(0)
	print("[BrotatoOnline] Removed players; roster_revision=" + str(revision) + " remaining=" + str(RunData.get_player_count()))


func handle_network_message(sender: String, message: Dictionary) -> bool:
	var type = str(message.get("msg_type", ""))
	if not CONTROL_MESSAGES.has(type):
		return false
	var session = _session()
	if session == null or session.is_game_host() or session._should_drop_p2p_message_for_session(sender, message):
		return true
	if sender != session.get_game_host_steam_id():
		return true
	if _exiting_after_kick:
		return true
	if type == "player_kicked":
		_exiting_after_kick = true
		_pending_client_roster.clear()
		transitioning = true
		call_deferred("_exit_kicked_client")
	elif type == "player_removed":
		if int(message.get("roster_revision", 0)) != revision:
			return true
		for index_value in message.get("removed_indices", []):
			var index = int(index_value)
			if index >= 0 and index < RunData.get_player_count() and index != _slots().get_local_mirrored_player_index():
				_removed[index] = ""
		_refresh_player_list()
	elif type == "player_roster_commit":
		var incoming_revision = int(message.get("revision", 0))
		if incoming_revision > revision and incoming_revision > int(_pending_client_roster.get("revision", 0)):
			# Several complete commits can arrive in one poll when the host removes
			# multiple players. Apply the newest one instead of dropping it mid-transition.
			_pending_client_roster = message.duplicate(true)
			if not transitioning:
				transitioning = true
				call_deferred("_apply_pending_client_roster", session._online_session_generation)
	return true


func _apply_pending_client_roster(generation: int) -> void:
	if _session()._online_session_generation != generation or _exiting_after_kick or _pending_client_roster.empty():
		return
	var message = _pending_client_roster
	_pending_client_roster = {}
	_apply_client_roster(message, generation)


func _apply_client_roster(message: Dictionary, generation: int) -> void:
	if _session()._online_session_generation != generation or not _session().is_online_session_active() or _session().is_game_host():
		return
	var state = message.get("state", {})
	var config = state.get("run_config", {})
	var players = state.get("slot_layout", {}).get("players", [])
	var path = str(state.get("scene_path", ""))
	var self_key = _session().get_self_steam_id()
	var self_count = 0
	for player in players:
		if str(player.get("steam_id", "")) == self_key:
			self_count += 1
	if self_count != 1 or players.empty() or players.size() != int(config.get("player_count", 0)):
		transitioning = false
		return
	var packed = load(path)
	if packed == null or not (packed is PackedScene):
		transitioning = false
		return
	_trace("client_begin", path)
	_dispose_current_scene()
	_removed.clear()
	revision = int(message.get("revision", 0))
	_reset_indexed_caches()
	_slots().apply_authoritative_roster(players, self_key, _session().get_game_host_steam_id(), bool(message.get("lock_run", true)))
	# All entries carry full data; do not preserve runtime state from a different
	# player's old index when the middle slot was deleted.
	RunData.players_data.clear()
	RunData.set_player_count(players.size())
	_menu()._apply_run_config_before_client_scene_change(config, str(state.get("screen", "shop")))
	RunData.shop_effects_checked = bool(config.get("shop_effects_checked", true))
	RunData.resumed_from_state_in_shop = false
	RunData.locked_shop_items = [[], [], [], []]
	get_tree().paused = false
	if path.ends_with("/character_selection.tscn"):
		RunData.menu_selection_back = true
	var error = get_tree().change_scene_to(packed)
	if error != OK:
		_trace("client_scene_error", str(error))
		transitioning = false
		return
	call_deferred("_finish_client_roster", message, generation)


func _finish_client_roster(message: Dictionary, generation: int) -> void:
	if _session()._online_session_generation != generation or not _session().is_online_session_active() or _session().is_game_host() or _exiting_after_kick:
		return
	var state = message.get("state", {})
	var next_scene = get_tree().current_scene
	if next_scene == null or str(next_scene.filename) != str(state.get("scene_path", "")):
		_trace("client_scene_not_ready", str(state.get("scene_path", "")))
		transitioning = false
		return
	_trace("client_scene_ready", str(next_scene.filename))
	var self_key = _session().get_self_steam_id()
	_menu().receive_menu_scene_state_from_host(state, self_key, _session().get_game_host_steam_id())
	_save_current_shop(next_scene)
	if not _pending_client_roster.empty():
		call_deferred("_apply_pending_client_roster", generation)
	else:
		transitioning = false


func should_drop_message(sender: String, message: Dictionary) -> bool:
	var type = str(message.get("msg_type", ""))
	if type in ["heartbeat", "hello", "hello_ack"]:
		return _session()._kicked_departing_peer_keys.has(sender)
	if transitioning:
		return true
	if _session().is_game_host() and _session()._kicked_departing_peer_keys.has(sender):
		return true
	var packet_revision = int(message.get("roster_revision", 0))
	# A new/reconnected client learns the revision with its normal full Host setup.
	if not _session().is_game_host() and sender == _session().get_game_host_steam_id() and not _session()._online_flow_started and packet_revision > revision:
		revision = packet_revision
	return packet_revision != revision


func _exit_kicked_client() -> void:
	_session()._freeze_current_run_for_host_disconnect()
	_session().leave_lobby()
	get_tree().paused = false
	get_tree().change_scene(MenuData.title_screen_scene)
	_kick_notice_pending = true


func _show_kicked_notice() -> void:
	var scene = get_tree().current_scene
	if scene == null or str(scene.filename) != str(MenuData.title_screen_scene):
		return
	_kick_notice_pending = false
	var dialog = AcceptDialog.new()
	dialog.window_title = _txt("BROTATO_ONLINE_PLAYER_LIST_KICK")
	dialog.dialog_text = _txt("BROTATO_ONLINE_PLAYER_KICKED_NOTICE")
	dialog.pause_mode = Node.PAUSE_MODE_PROCESS
	scene.add_child(dialog)
	dialog.connect("popup_hide", dialog, "queue_free")
	dialog.popup_centered(Vector2(600, 160))


func _refresh_player_list() -> void:
	var overlay = get_parent().get_node_or_null("BrotatoOnlinePlayerListOverlay")
	if overlay != null:
		overlay.reset_roster_cache()


func reset_online_session_state() -> void:
	revision = 0
	transitioning = false
	_pending_client_roster.clear()
	_exiting_after_kick = false
	_removed.clear()
	_affects_saved_run = false
	_progression_finished_key = ""


func _save_current_shop(scene: Node) -> void:
	if scene.has_method("get_player_shop_items"):
		ProgressData.save_run_state(scene.get("_shop_items"), scene.get("_reroll_count"), scene.get("_paid_reroll_count"), scene.get("_initial_free_rerolls"), scene.get("_free_rerolls"), scene.get("_item_steals"))


func _txt(key: String) -> String:
	var i18n = get_parent().get_node_or_null("BrotatoOnlineI18n")
	return str(i18n.get_text(key)) if i18n != null else key


func _trace(stage: String, detail: String = "") -> void:
	print("[BO_NET][ROSTER][" + stage + "] revision=" + str(revision) + " players=" + str(RunData.get_player_count()) + " " + detail)
