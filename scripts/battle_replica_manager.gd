extends Node

# Host owns spawn order, boss/elite movement, pet movement, economy/XP/upgrade/box queues and wave timer; pickups are local-only visuals/interactions.
# Client locally simulates regular enemy movement/combat after Host-authoritative birth positions.
# Client mirrors Host birth warnings with real EntityBirth visual timing, but does not let the legacy GhostLayer hide entities.


const PHASE = "B12_delayed_death_sync"
const BULL_CHARACTER_ID = "character_bull"
const LOCAL_SUPPRESS_INTERVAL_MSEC = 700
const PLAYER_STATE_SEND_INTERVAL_MSEC = 80
const BOSS_DAMAGE_SEND_INTERVAL_MSEC = 120
const HOST_ENTITY_LERP_SPEED = 20.0
const HOST_PLAYER_LERP_SPEED = 18.0
const MAX_EXTRAPOLATION_MSEC = 120
const ENTITY_INTERPOLATION_DELAY_MSEC = 140
const PLAYER_INTERPOLATION_DELAY_MSEC = 100
const INTERPOLATION_BUFFER_KEEP_MSEC = 900
const CLOCK_OFFSET_SMOOTHING = 0.10
const SYNC_MODE_BIRTH_ONLY = "birth_only"
const SYNC_MODE_HOST_MOTION = "host_motion"
const LOCAL_KILL_IGNORE_MSEC = 1600
const ENABLE_BIRTH_MARKERS = true
const WAVE_TIMER_SYNC_INTERVAL_MSEC = 160
const WAVE_TIMER_DRIFT_CORRECTION_SEC = 0.35
const DEATH_VISUAL_DELAY_MSEC = 500
const DEATH_EVENT_SEEN_KEEP = 192
# Diagnostic switch: keep vanilla/local enemy deaths disabled, but allow player death reporting/display.
# Entity kill/death sync was disabled to avoid the earlier battle freeze path; player death is separate
# and is required for Host-authoritative failed-wave / end-run flow.
const ENABLE_DEATH_REPORTS = false
# Keep broad enemy death sync disabled, but allow the narrow boss/elite death path.
# In Brotato, elites and bosses are both replicated through category == "boss" / get_bosses().
# Without this, a client can locally kill a Host-motion boss/elite, clear its net_id mapping,
# then recreate it from the next Host snapshot as the generic boss fallback.
const ENABLE_CLIENT_BOSS_ONE_SHOT_REPORTS = true
const ENABLE_CLIENT_BOSS_ELITE_DEATH_REPORTS = true
const ENABLE_DEATH_SYNC = false
const ENABLE_PLAYER_DEATH_REPORTS = true
const ENABLE_PLAYER_DEATH_SYNC = true
# Diagnostic switch: ignore Host removed ids and active-id prune on clients.
const ENABLE_HOST_REMOVED_SYNC = false
const REMOTE_PLAYER_HURTBOX_GUARD_INTERVAL_MSEC = 250
const CLIENT_NEW_BATTLE_TERMINAL_SNAPSHOT_GUARD_MSEC = 6000
# The first accepted Host combat snapshot after entering a battle must be a clearly
# running timer.  Stale/pre-start packets often report 0 seconds on wave 1 and must
# never be allowed to drive the client into the vanilla wave-timeout path.
const CLIENT_FIRST_HOST_ACTIVE_SNAPSHOT_MIN_TIME_LEFT_SEC = 1.0
const BULLET_HELL_PHASE_SYNC_INTERVAL_MSEC = 250
const BULLET_HELL_PHASE_DRIFT_CORRECTION_SEC = 0.20
const BULLET_HELL_CLEAR_LOCAL_PROJECTILES_ON_FIRST_SYNC = true
const UNKNOWN_ENTITY_RESYNC_REQUEST_INTERVAL_MSEC = 2000

var _latest_snapshot = {}
var _latest_snapshot_tick = -1
var _last_applied_tick = -1
var _last_scene_was_game = false
var _last_game_scene_instance_id = 0
var _client_battle_terminal_cleanup_suspended = false
var _client_world_prepared = false
var _client_initial_entity_cleanup_done = false
var _last_local_suppress_msec = 0
var _last_player_state_send_msec = 0
var _last_sent_player_dead_state = false
var _sent_owned_player_terminal_state = false
var _last_terminal_player_state_reason = ""
var _last_boss_damage_send_msec = 0
var _last_log_msec = 0
var _apply_count = 0
var _cached_owned_player_index = -1
var _last_owned_index_log_msec = 0

var _host_entities = {}                # net_id -> Node
var _host_entity_category = {}          # net_id -> String
var _host_entity_scene_path = {}        # net_id -> String
var _host_entity_targets = {}           # net_id -> Vector2
var _host_entity_velocities = {}        # net_id -> Vector2
var _host_entity_rx_msec = {}           # net_id -> int
var _host_entity_samples = {}           # net_id -> [{t:int host_msec, pos:Vector2, vel:Vector2}]
var _host_clock_offset_msec = 0.0       # local_ticks - host_ticks, smoothed
var _host_clock_offset_initialized = false
var _locally_killed_until = {}          # net_id -> local msec; prevents immediate resurrection while Host processes claim
var _connected_died_ids = {}
var _connected_damage_ids = {}
var _pending_boss_damage = {}           # net_id -> damage sum
var _pending_boss_one_shots = {}        # net_id -> true when the damage was a Vorpal/one-shot kill

var _remote_player_targets = {}         # player_index -> Vector2
var _remote_player_velocities = {}
var _remote_player_rx_msec = {}
var _remote_player_samples = {}         # player_index -> [{t:int host_msec, pos:Vector2, vel:Vector2}]

var _birth_markers = {}
var _birth_marker_states = {}
var _latest_wave_timer_state = {}
var _pickup_markers = {}                # pickup_net_id -> Node2D marker
var _pickup_targets = {}
var _pickup_claimed = {}
var _last_wave_timer_apply_msec = 0
var _last_economy_apply_msec = 0
var _seen_battle_event_ids = {}       # event_key -> true
var _pending_remote_deaths = {}       # net_id -> {remove_at:int, category:String, pos:Vector2, source:String}
var _sent_kill_claim_ids = {}         # net_id -> true, prevents duplicate local death reports
var _spawned_from_birth_marker_entity_ids = {} # entity_net_id -> true, prevents marker-timeout duplicate spawns
var _last_progression_apply_key_by_player = {} # player_index -> stable visible reward option key
var _last_progression_queue_key_by_player = {} # player_index -> stable pending reward queue key
var _last_remote_player_hurtbox_guard_msec = 0
var _last_bullet_hell_phase_sync_msec = 0
var _bullet_hell_phase_cleared_key = ""
var _last_host_battle_inactive_cleanup_msec = 0
var _snapshot_gate_scene_instance_id = 0
var _snapshot_gate_enter_msec = 0
var _snapshot_gate_seen_running_wave = false
var _last_entity_resync_request_msec_by_net_id = {}

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	set_process(true)


func receive_battle_terminal_state_from_host(message: Dictionary) -> void:
	if not _is_online_session_active() or _is_game_host():
		return
	if typeof(message) != TYPE_DICTIONARY or message.empty():
		return
	if not _is_in_game_scene():
		return
	if _client_battle_terminal_cleanup_suspended:
		return
	if _is_client_main_terminal_cleanup_active():
		return

	var now = OS.get_ticks_msec()
	var snapshot = message.duplicate(true)
	snapshot["msg_type"] = "battle_snapshot"
	snapshot["phase"] = str(message.get("phase", "B14_host_terminal_state"))
	if not snapshot.has("progression_state"):
		snapshot["progression_state"] = {}
	snapshot["prune_missing"] = false
	var tick = int(snapshot.get("tick", snapshot.get("t", 0)))
	if tick <= 0:
		tick = max(1, _latest_snapshot_tick + 1)
	snapshot["tick"] = tick
	# A stale/pre-start win terminal must not be allowed to end a fresh client battle
	# before this scene has accepted one active Host wave snapshot. Real final-wave
	# wins will be re-sent and accepted after the short entry guard if needed.
	if bool(message.get("run_won", false)) and _should_drop_client_entry_terminal_snapshot(snapshot, now):
		return
	_update_host_clock_offset(_get_snapshot_server_time_msec(snapshot, now), now)

	# Apply immediately. A terminal failure packet is rare and must not wait behind the
	# normal per-frame snapshot cache, because the local client may otherwise advance
	# through a stale wave-end path before seeing Host death.
	_latest_snapshot = snapshot.duplicate(false)
	_latest_snapshot_tick = max(tick, _latest_snapshot_tick + 1)
	_apply_latest_snapshot_if_needed()
	_apply_owned_terminal_player_state_from_host(snapshot)

	if bool(message.get("wave_failed", false)) or bool(message.get("run_lost", false)) or bool(message.get("retry_visible", false)):
		_neutralize_client_combat_threats("host_terminal_state")
		_queue_client_failed_cleanup_from_host("host_terminal_state", bool(message.get("run_lost", false)), _terminal_packet_all_players_dead(snapshot))
	elif bool(message.get("run_won", false)):
		_neutralize_client_combat_threats("host_run_won_terminal")
		_queue_client_wave_end_from_host("host_run_won_terminal", true)


func _apply_owned_terminal_player_state_from_host(snapshot: Dictionary) -> void:
	var owned_index = _get_owned_player_index()
	if owned_index < 0:
		return
	var players = snapshot.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return
	for state in players:
		if typeof(state) != TYPE_DICTIONARY:
			continue
		if int(state.get("player_index", -1)) != owned_index:
			continue
		var hp = int(state.get("health", state.get("hp", -1)))
		var should_dead = bool(state.get("dead", false)) or (hp >= 0 and hp <= 0)
		if should_dead:
			_force_owned_player_dead_from_host_terminal(hp)
		return


func _force_owned_player_dead_from_host_terminal(hp: int) -> void:
	var player = _get_owned_player_node()
	if not _is_valid_node(player):
		return
	var current_stats = player.get("current_stats")
	var max_stats = player.get("max_stats")
	if current_stats != null:
		current_stats.health = 0
	if player.has_signal("health_updated"):
		var mhp = int(max_stats.health) if max_stats != null else 0
		player.emit_signal("health_updated", player, 0, mhp)
	var already_dead = false
	if player.get("dead") != null:
		already_dead = bool(player.get("dead"))
	if already_dead:
		return
	player.set_meta("brotato_online_host_terminal_dead", true)
	player.set_meta("brotato_online_remote_death_applying", true)
	player.set_meta("brotato_online_allow_remote_die", true)
	if player.has_method("die"):
		player.die()
	elif player.get("dead") != null:
		player.set("dead", true)
	player.set_meta("brotato_online_allow_remote_die", false)
	player.set_meta("brotato_online_remote_death_applying", false)
	if player.get("dead") != null and not bool(player.get("dead")):
		player.set("dead", true)
		_force_remote_player_death_pose(player)


func _terminal_packet_all_players_dead(snapshot: Dictionary) -> bool:
	var players = snapshot.get("players", [])
	if typeof(players) != TYPE_ARRAY or players.empty():
		return false
	var expected_count = max(1, int(snapshot.get("player_count", RunData.get_player_count())))
	if players.size() < expected_count:
		return false
	for state in players:
		if typeof(state) != TYPE_DICTIONARY:
			continue
		var hp = int(state.get("health", state.get("hp", -1)))
		if not bool(state.get("dead", false)) and not (hp >= 0 and hp <= 0):
			return false
	return true


func _queue_client_failed_cleanup_from_host(reason: String, run_lost: bool, force_from_packet: bool) -> void:
	call_deferred("_deferred_force_client_failed_cleanup_from_host", reason, run_lost, force_from_packet)


func _deferred_force_client_failed_cleanup_from_host(reason: String, run_lost: bool, force_from_packet: bool) -> void:
	if _is_game_host() or not _is_online_session_active() or not _is_in_game_scene():
		return
	var main = _get_current_main_node()
	if main == null:
		return
	if _safe_node_bool(main, "_cleaning_up", false) or _safe_node_bool(main, "_is_wave_failed", false) or _safe_node_bool(main, "_is_run_lost", false):
		return
	var retry_wave = _safe_node_get(main, "_retry_wave", null)
	if _is_valid_node(retry_wave) and retry_wave is CanvasItem and retry_wave.visible:
		return
	if not force_from_packet and not _local_all_players_dead_for_terminal():
		return
	if main.get("_is_wave_failed") != null:
		main.set("_is_wave_failed", true)
	if run_lost and main.get("_is_run_lost") != null:
		main.set("_is_run_lost", true)
	if main.has_method("clean_up_room"):
		main.clean_up_room()


func _local_all_players_dead_for_terminal() -> bool:
	var locator = _get_runtime_locator()
	if locator == null or not locator.has_method("get_players"):
		return false
	var players = locator.get_players()
	if typeof(players) != TYPE_ARRAY or players.empty():
		return false
	for player in players:
		if not _is_valid_node(player):
			continue
		var current_stats = player.get("current_stats")
		var hp = int(current_stats.health) if current_stats != null else -1
		var dead = bool(player.get("dead")) if player.get("dead") != null else false
		if not dead and not (hp >= 0 and hp <= 0):
			return false
	return true


func _queue_client_wave_end_from_host(reason: String, run_won: bool) -> void:
	call_deferred("_deferred_force_client_wave_end_from_host", reason, run_won)


func _deferred_force_client_wave_end_from_host(reason: String, run_won: bool) -> void:
	if _is_game_host() or not _is_online_session_active() or not _is_in_game_scene():
		return
	var main = _get_current_main_node()
	if main == null:
		return
	if _safe_node_bool(main, "_cleaning_up", false) or _safe_node_bool(main, "_is_wave_failed", false) or _safe_node_bool(main, "_is_run_lost", false) or _safe_node_bool(main, "_is_run_won", false):
		return
	var already_forced = main.has_meta("brotato_online_host_wave_timeout_forced") and bool(main.get_meta("brotato_online_host_wave_timeout_forced"))
	if run_won and main.get("_is_run_won") != null:
		# Final-wave boss kill can finish the Host before WaveTimer reaches 0. Mark the
		# client terminal state first, then drive the normal vanilla wave timeout path.
		main.set("_is_run_won", true)
	if already_forced:
		# _apply_host_wave_timer_state() may already have started the local Timer at
		# 0.05 / queued _on_WaveTimer_timeout from the same terminal packet. Do not
		# schedule a duplicate; setting _is_run_won above is enough for that path.
		return
	main.set_meta("brotato_online_host_wave_timeout_forced", true)
	if main.has_method("_on_WaveTimer_timeout"):
		main.call_deferred("_on_WaveTimer_timeout")
	elif main.has_method("clean_up_room"):
		main.call_deferred("clean_up_room")


func receive_battle_snapshot_from_host(snapshot: Dictionary) -> void:
	if not _is_online_session_active() or _is_game_host():
		return
	if _client_battle_terminal_cleanup_suspended:
		return
	# Do not cache battle snapshots while the Client is in shop/upgrade/scene transition.
	# Late wave-1 packets can otherwise become _latest_snapshot and get applied to the
	# next main.tscn, which is exactly the risky second-wave entry path.
	if not _is_in_game_scene():
		return
	if _is_client_main_terminal_cleanup_active():
		send_owned_player_terminal_state(null, "client_terminal_cleanup_snapshot")
		_suspend_client_battle_layer("client_terminal_cleanup_snapshot")
		return
	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.empty():
		return
	var now = OS.get_ticks_msec()
	if _should_drop_client_entry_terminal_snapshot(snapshot, now):
		return
	var tick = int(snapshot.get("tick", 0))
	if tick <= 0:
		return
	var snapshot_wave = _get_snapshot_wave(snapshot)
	var local_wave = _get_local_run_wave()
	if snapshot_wave >= 0 and local_wave >= 0 and snapshot_wave < local_wave:
		# Drop late packets from the previous battle after shop->battle transition.
		return
	if _latest_snapshot_tick > 0 and tick < _latest_snapshot_tick:
		return
	_update_host_clock_offset(_get_snapshot_server_time_msec(snapshot, now), now)
	# Keep packet handling light. Applying snapshots inside the Steam P2P polling
	# loop can stack several snapshot applications in one rendered frame and cause
	# visible battle hitching. Cache the newest packet here; _process() applies at
	# most one snapshot per frame. A shallow copy is enough because apply code
	# treats snapshot payload as read-only.
	_latest_snapshot = snapshot.duplicate(false)
	_latest_snapshot_tick = tick


func receive_battle_reliable_events_from_host(message: Dictionary) -> void:
	if not _is_online_session_active() or _is_game_host():
		return
	if _client_battle_terminal_cleanup_suspended:
		return
	if typeof(message) != TYPE_DICTIONARY or message.empty():
		return
	var now = OS.get_ticks_msec()
	var server_time_msec = _get_snapshot_server_time_msec(message, now)
	_update_host_clock_offset(server_time_msec, now)
	if not _is_in_game_scene():
		return
	if _is_client_main_terminal_cleanup_active():
		send_owned_player_terminal_state(null, "client_terminal_cleanup_reliable")
		_suspend_client_battle_layer("client_terminal_cleanup_reliable")
		return

	var births = message.get("births", [])
	if typeof(births) == TYPE_ARRAY:
		for birth in births:
			if typeof(birth) == TYPE_DICTIONARY:
				_apply_reliable_birth_marker_state(birth, server_time_msec)

	var entities = message.get("entities", [])
	if typeof(entities) == TYPE_ARRAY:
		for state in entities:
			if typeof(state) == TYPE_DICTIONARY:
				_apply_reliable_entity_birth_state(state, server_time_msec, now)

	_process_battle_events(message, server_time_msec, now)

	var removed = message.get("removed", [])
	if ENABLE_HOST_REMOVED_SYNC and typeof(removed) == TYPE_ARRAY:
		for rid in removed:
			var id = str(rid)
			_handle_host_removed_entity(id, now, "reliable_removed")
			_remove_birth_marker(id)
			_remove_pickup_marker(id)


func _apply_reliable_entity_birth_state(state: Dictionary, server_time_msec: int, now: int) -> void:
	var net_id = str(state.get("net_id", ""))
	if net_id == "" or _locally_killed_until.has(net_id):
		return
	if bool(state.get("dead", false)):
		if ENABLE_DEATH_SYNC:
			_schedule_remote_death(net_id, str(state.get("category", _host_entity_category.get(net_id, ""))), _dict_to_vec2(state.get("pos", {})), now + DEATH_VISUAL_DELAY_MSEC, "reliable_state_dead")
		else:
			_remove_host_entity(net_id, true)
		return
	var category = str(state.get("category", ""))
	var sync_mode = _get_entity_sync_mode(category, state)
	var pos = _dict_to_vec2(state.get("pos", {}))
	var vel = _dict_to_vec2(state.get("vel", {}))
	var was_known = _host_entities.has(net_id) and _is_valid_node(_host_entities[net_id])
	var node = _get_or_create_host_entity(net_id, state)
	if not _is_valid_node(node):
		_request_unknown_entity_resync(net_id, category, "reliable_spawn_failed")
		return
	_apply_host_entity_state(node, state)
	if not was_known or not _node_has_valid_position(node):
		_set_node_global_pos(node, pos)
	if sync_mode == SYNC_MODE_HOST_MOTION:
		_host_entity_targets[net_id] = pos
		_host_entity_velocities[net_id] = vel
		_host_entity_rx_msec[net_id] = now
		_append_entity_sample(net_id, server_time_msec, pos, vel)


func _process(delta: float) -> void:
	var scene = get_tree().current_scene
	var in_game = _is_in_game_scene()
	if not in_game:
		if _last_scene_was_game:
			_clear_all("left_game_scene")
		_last_scene_was_game = false
		_last_game_scene_instance_id = 0
		_client_battle_terminal_cleanup_suspended = false
		_client_world_prepared = false
		_client_initial_entity_cleanup_done = false
		_snapshot_gate_scene_instance_id = 0
		_snapshot_gate_enter_msec = 0
		_snapshot_gate_seen_running_wave = false
		return

	var scene_instance_id = scene.get_instance_id() if scene != null and is_instance_valid(scene) else 0
	if _last_scene_was_game and _last_game_scene_instance_id != 0 and scene_instance_id != 0 and scene_instance_id != _last_game_scene_instance_id:
		_clear_all("game_scene_replaced")
		_last_scene_was_game = false
		_client_battle_terminal_cleanup_suspended = false
		_client_world_prepared = false
		_client_initial_entity_cleanup_done = false
		_reset_snapshot_gate_for_scene(scene_instance_id, "game_scene_replaced")

	if not _is_online_session_active():
		# If the lobby/session is closed while current_scene is still main.tscn
		# (for example quitting an online run back to the main menu), the old battle
		# cache will not pass through the normal not-in-game cleanup path.  Clear it
		# here too; otherwise a later Continue/rejoin can apply a stale stopped-timer
		# snapshot before the first fresh Host-active snapshot and instantly finish
		# the client wave.
		if _last_scene_was_game or _latest_snapshot_tick > 0 or not _latest_wave_timer_state.empty() or _snapshot_gate_seen_running_wave:
			_clear_all("online_session_inactive")
		_last_scene_was_game = false
		_last_game_scene_instance_id = 0
		_client_battle_terminal_cleanup_suspended = false
		_client_world_prepared = false
		_client_initial_entity_cleanup_done = false
		_snapshot_gate_scene_instance_id = 0
		_snapshot_gate_enter_msec = 0
		_snapshot_gate_seen_running_wave = false
		return

	if _is_game_host():
		return

	if _client_battle_terminal_cleanup_suspended:
		return
	if _is_client_main_terminal_cleanup_active():
		# The local death / fail path can start Main.clean_up_room() before the normal
		# 80ms player_state poll sends HP=0. Push a reliable terminal packet first,
		# otherwise the Host keeps the client-owned player proxy alive and invulnerable.
		send_owned_player_terminal_state(null, "client_terminal_cleanup_process")
		_suspend_client_battle_layer("client_terminal_cleanup_process")
		return


	if not _last_scene_was_game:
		# A Client can press ESC while ready and carry SceneTree.paused into main.tscn.
		# This manager processes while paused, so clear the stale menu pause exactly when
		# the Client enters/re-enters a battle scene. Do not intercept ESC itself.
		if get_tree().paused:
			get_tree().paused = false
		_last_scene_was_game = true
		_last_game_scene_instance_id = scene_instance_id
		_reset_snapshot_gate_for_scene(scene_instance_id, "client_enter_game_scene")
		_prepare_client_host_controlled_world(true)

	_prepare_client_host_controlled_world(false)
	_prepare_remote_player_damage_proxies(false)
	_apply_latest_snapshot_if_needed()
	_update_host_wave_timer_from_cached_state(false)
	_update_host_entity_positions(delta)
	_update_remote_player_positions(delta)
	_poll_and_send_player_state(false)
	_flush_boss_damage_reports(false)
	# Pickup claim polling disabled: pickups are local-only; Host corrects economy/XP/box queues.
	_update_birth_markers()
	_update_pending_remote_deaths()


func _reset_snapshot_gate_for_scene(scene_instance_id: int, reason: String) -> void:
	_snapshot_gate_scene_instance_id = scene_instance_id
	_snapshot_gate_enter_msec = OS.get_ticks_msec()
	_snapshot_gate_seen_running_wave = false
	_last_host_battle_inactive_cleanup_msec = 0


func _ensure_snapshot_gate_for_current_scene(now: int) -> void:
	var scene = get_tree().current_scene
	var scene_instance_id = scene.get_instance_id() if scene != null and is_instance_valid(scene) else 0
	if scene_instance_id == 0:
		return
	if _snapshot_gate_scene_instance_id != scene_instance_id:
		_snapshot_gate_scene_instance_id = scene_instance_id
		_snapshot_gate_enter_msec = now
		_snapshot_gate_seen_running_wave = false


func should_block_local_wave_timeout_until_host_active() -> bool:
	if _is_game_host() or not _is_online_session_active() or not _is_in_game_scene():
		return false
	if _client_battle_terminal_cleanup_suspended:
		return false
	if _is_client_main_terminal_cleanup_active():
		return false
	_ensure_snapshot_gate_for_current_scene(OS.get_ticks_msec())
	return not _snapshot_gate_seen_running_wave


func has_seen_active_host_wave_for_current_scene() -> bool:
	if _is_game_host() or not _is_online_session_active() or not _is_in_game_scene():
		return true
	_ensure_snapshot_gate_for_current_scene(OS.get_ticks_msec())
	return _snapshot_gate_seen_running_wave


func _should_drop_client_entry_terminal_snapshot(snapshot: Dictionary, now: int) -> bool:
	_ensure_snapshot_gate_for_current_scene(now)
	if _snapshot_gate_seen_running_wave:
		return false

	# Accept the first combat snapshot only after Host has a clearly running wave timer.
	# Wave-1 scene entry can briefly produce running=false/time_left=0 snapshots before
	# the real timer starts; applying those can immediately call the vanilla timeout path
	# on the client and show an instant victory.
	if _snapshot_wave_timer_passes_first_active_gate(snapshot):
		_snapshot_gate_seen_running_wave = true
		return false

	var elapsed = now - _snapshot_gate_enter_msec
	var in_entry_guard = _snapshot_gate_enter_msec <= 0 or elapsed <= CLIENT_NEW_BATTLE_TERMINAL_SNAPSHOT_GUARD_MSEC
	if in_entry_guard and _snapshot_wave_timer_is_inactive_or_terminal(snapshot):
		return true
	if in_entry_guard and _snapshot_has_terminal_progression(snapshot):
		return true
	return false


func _snapshot_wave_matches_local(snapshot: Dictionary, wave_state: Dictionary) -> bool:
	var snapshot_wave = int(snapshot.get("wave", wave_state.get("wave", -9999)))
	var local_wave = _get_local_run_wave()
	return snapshot_wave < 0 or local_wave < 0 or snapshot_wave == local_wave


func _snapshot_wave_timer_passes_first_active_gate(snapshot: Dictionary) -> bool:
	var wave_state = snapshot.get("wave_timer_state", {})
	if typeof(wave_state) != TYPE_DICTIONARY:
		return false
	if not _snapshot_wave_matches_local(snapshot, wave_state):
		return false
	var time_left = float(wave_state.get("time_left", -1.0))
	return bool(wave_state.get("running", false)) and time_left > CLIENT_FIRST_HOST_ACTIVE_SNAPSHOT_MIN_TIME_LEFT_SEC


func _snapshot_wave_timer_is_inactive_or_terminal(snapshot: Dictionary) -> bool:
	var wave_state = snapshot.get("wave_timer_state", {})
	if typeof(wave_state) != TYPE_DICTIONARY or wave_state.empty():
		return false
	if not _snapshot_wave_matches_local(snapshot, wave_state):
		return false
	var time_left = float(wave_state.get("time_left", -1.0))
	return not bool(wave_state.get("running", false)) and time_left <= 0.05


func _snapshot_wave_timer_is_running(snapshot: Dictionary) -> bool:
	var wave_state = snapshot.get("wave_timer_state", {})
	if typeof(wave_state) != TYPE_DICTIONARY:
		return false
	var time_left = float(wave_state.get("time_left", 0.0))
	# Right after a retry scene reload, Host can report running=false for a few frames
	# while the Timer still has positive time_left. That is a pre-start/transition
	# battle state, not a terminal wave-end snapshot. Treat it as active.
	return time_left > 0.05 or bool(wave_state.get("running", false))


func _snapshot_has_terminal_progression(snapshot: Dictionary) -> bool:
	var wave_state = snapshot.get("wave_timer_state", {})
	var wave_running = false
	var time_left = -1.0
	if typeof(wave_state) == TYPE_DICTIONARY:
		wave_running = bool(wave_state.get("running", false))
		time_left = float(wave_state.get("time_left", -1.0))
	if wave_running or time_left > 0.05:
		return false
	var state = snapshot.get("progression_state", {})
	if typeof(state) != TYPE_DICTIONARY or state.empty():
		return false
	var players = state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return false
	for player_state in players:
		if typeof(player_state) != TYPE_DICTIONARY:
			continue
		var pending_upgrades = player_state.get("pending_upgrades", [])
		var pending_consumables = player_state.get("pending_consumables", [])
		if typeof(pending_upgrades) == TYPE_ARRAY and pending_upgrades.size() > 0:
			return true
		if typeof(pending_consumables) == TYPE_ARRAY and pending_consumables.size() > 0:
			return true
		var visible = player_state.get("visible_option", {})
		if typeof(visible) == TYPE_DICTIONARY:
			var mode = str(visible.get("mode", "none"))
			if mode == "upgrade" or mode == "item_box":
				return true
	return false


func _suspend_client_battle_layer(reason: String) -> void:
	if not _client_battle_terminal_cleanup_suspended:
		pass
	_client_battle_terminal_cleanup_suspended = true
	_clear_all(reason)
	_client_world_prepared = false
	_client_initial_entity_cleanup_done = false
	_latest_snapshot = {}
	_latest_snapshot_tick = -1
	_last_applied_tick = -1


func _is_client_main_terminal_cleanup_active() -> bool:
	if _is_game_host() or not _is_in_game_scene():
		return false
	var main = _get_current_main_node()
	if main == null:
		return false
	# During Main.clean_up_room() the vanilla scene starts freeing spawner/projectile/UI
	# nodes while it is still the current scene. The client replica layer must stop
	# touching battle containers at that point, otherwise late Host snapshots can race
	# against the local failure/RetryWave cleanup.
	if _safe_node_bool(main, "_cleaning_up", false):
		return true
	if _safe_node_bool(main, "_is_wave_failed", false) or _safe_node_bool(main, "_is_run_lost", false) or _safe_node_bool(main, "_is_run_won", false):
		return true
	var retry_wave = _safe_node_get(main, "_retry_wave", null)
	if _is_valid_node(retry_wave) and retry_wave is CanvasItem and retry_wave.visible:
		return true
	return false


func _get_current_main_node() -> Node:
	var locator = _get_runtime_locator()
	var main = locator.get_main() if locator != null and locator.has_method("get_main") else null
	if _is_valid_node(main):
		return main
	var scene = get_tree().current_scene
	if scene != null and is_instance_valid(scene) and scene is Node:
		return scene
	return null


func _safe_node_get(node: Node, prop: String, default_value = null):
	if node == null or not is_instance_valid(node):
		return default_value
	var value = node.get(prop)
	return default_value if value == null else value


func _safe_node_bool(node: Node, prop: String, default_value: bool = false) -> bool:
	var value = _safe_node_get(node, prop, default_value)
	if value == null:
		return default_value
	return bool(value)


func _prepare_client_host_controlled_world(force: bool) -> void:
	if not _is_online_session_active() or _is_game_host() or not _is_in_game_scene():
		return
	var now = OS.get_ticks_msec()
	if not force and _client_world_prepared and now - _last_local_suppress_msec < LOCAL_SUPPRESS_INTERVAL_MSEC:
		return
	_last_local_suppress_msec = now

	var locator = _get_runtime_locator()
	if locator == null:
		return
	var spawner = locator.get_entity_spawner() if locator.has_method("get_entity_spawner") else null
	if spawner == null:
		return

	var wave_manager = locator.get_wave_manager() if locator.has_method("get_wave_manager") else null
	if wave_manager != null and wave_manager.is_connected("group_spawn_timing_reached", spawner, "on_group_spawn_timing_reached"):
		wave_manager.disconnect("group_spawn_timing_reached", spawner, "on_group_spawn_timing_reached")

	var structure_timer = spawner.get_node_or_null("StructureTimer")
	if structure_timer != null and structure_timer is Timer:
		structure_timer.stop()

	_clear_spawner_queues(spawner)
	_sanitize_stats_manager_queues("prepare_client_world_before_cleanup")
	var removed_counts = {}
	# Do destructive cleanup only once when the battle scene is first prepared.
	# locally simulated enemies / spawner arrays and produce visible flicker.
	if force or not _client_initial_entity_cleanup_done:
		removed_counts = _remove_non_host_controlled_entities(spawner, locator)
		spawner.set("active_births", 0)
		spawner.set("_all_enemy_dirty", true)
		_client_initial_entity_cleanup_done = true
	_client_world_prepared = true


func _prepare_remote_player_damage_proxies(force: bool) -> void:
	if not _is_online_session_active() or _is_game_host() or not _is_in_game_scene():
		return
	var now = OS.get_ticks_msec()
	if not force and now - _last_remote_player_hurtbox_guard_msec < REMOTE_PLAYER_HURTBOX_GUARD_INTERVAL_MSEC:
		return
	_last_remote_player_hurtbox_guard_msec = now
	var locator = _get_runtime_locator()
	if locator == null or not locator.has_method("get_players"):
		return
	var players = locator.get_players()
	if typeof(players) != TYPE_ARRAY:
		return
	var owned_index = _get_owned_player_index()
	for i in range(players.size()):
		var player = players[i]
		if not _is_valid_node(player):
			continue
		var player_index = _get_player_index_from_node(player, i)
		if player_index == owned_index:
			continue
		_disable_player_hurtbox_for_net_proxy(player, player_index, "client_remote_guard")


func _disable_player_hurtbox_for_net_proxy(player: Node, player_index: int, reason: String) -> void:
	if not _is_valid_node(player):
		return
	player.set_meta("brotato_online_remote_damage_proxy", true)
	player.set_meta("brotato_online_hurtbox_disabled_player_index", player_index)

	# Remote non-owned players normally have their Hurtbox disabled on clients so local
	# enemy overlap cannot damage/kill the display proxy. Bull is the exception: its
	# character mechanic is the on-hit explosion, so every peer that can see the Bull
	# must keep a real Hurtbox locally. PlayerSafeRoomCleanup filters HP/death and only
	# lets the explosion/flash side effect run.
	if _is_bull_player_index(player_index):
		player.set_meta("brotato_online_remote_bull_hurtbox_proxy", true)
		player.set_meta("brotato_online_hurtbox_enabled_reason", reason)
		_restore_remote_proxy_collision_tree(player)
		_enable_bull_remote_player_hurtbox(player)
		return

	player.set_meta("brotato_online_remote_bull_hurtbox_proxy", false)
	player.set_meta("brotato_online_hurtbox_disabled_reason", reason)
	if player.has_method("disable_hurtbox"):
		player.disable_hurtbox()
	else:
		var hurtbox = player.get_node_or_null("Hurtbox")
		if hurtbox != null and hurtbox.has_method("disable"):
			hurtbox.disable()
	_disable_remote_proxy_collision_tree(player)


func _disable_remote_proxy_collision_tree(root: Node) -> void:
	if not _is_valid_node(root):
		return
	var hurtbox = root.get_node_or_null("Hurtbox")
	if hurtbox != null:
		_disable_collision_tree_under_hurtbox(hurtbox)
	# Some modded characters may rename or wrap the Hurtbox. Only disable nodes that
	# look like hurtboxes; do not zero the whole Player collision tree, because weapon
	# hitboxes under the remote proxy are still useful for local visual simulation.
	var stack = [root]
	while stack.size() > 0:
		var cur = stack.pop_back()
		if not _is_valid_node(cur):
			continue
		for child in cur.get_children():
			if child is Node:
				stack.append(child)
		if cur != root and str(cur.name).to_lower().find("hurtbox") != -1:
			_disable_collision_tree_under_hurtbox(cur)


func _disable_collision_tree_under_hurtbox(root: Node) -> void:
	if not _is_valid_node(root):
		return
	var stack = [root]
	while stack.size() > 0:
		var cur = stack.pop_back()
		if not _is_valid_node(cur):
			continue
		for child in cur.get_children():
			if child is Node:
				stack.append(child)
		if cur is CollisionObject2D:
			if not cur.has_meta("brotato_online_saved_collision_layer"):
				cur.set_meta("brotato_online_saved_collision_layer", int(cur.collision_layer))
			if not cur.has_meta("brotato_online_saved_collision_mask"):
				cur.set_meta("brotato_online_saved_collision_mask", int(cur.collision_mask))
			cur.set_deferred("collision_layer", 0)
			cur.set_deferred("collision_mask", 0)
		if cur is Area2D:
			if not cur.has_meta("brotato_online_saved_monitoring"):
				cur.set_meta("brotato_online_saved_monitoring", bool(cur.monitoring))
			if not cur.has_meta("brotato_online_saved_monitorable"):
				cur.set_meta("brotato_online_saved_monitorable", bool(cur.monitorable))
			cur.set_deferred("monitoring", false)
			cur.set_deferred("monitorable", false)
		if cur is CollisionShape2D or cur is CollisionPolygon2D:
			if not cur.has_meta("brotato_online_saved_disabled"):
				cur.set_meta("brotato_online_saved_disabled", bool(cur.disabled))
			cur.set_deferred("disabled", true)


func _restore_remote_proxy_collision_tree(root: Node) -> void:
	if not _is_valid_node(root):
		return
	var hurtbox = root.get_node_or_null("Hurtbox")
	if hurtbox != null:
		_restore_collision_tree_under_hurtbox(hurtbox)
	var stack = [root]
	while stack.size() > 0:
		var cur = stack.pop_back()
		if not _is_valid_node(cur):
			continue
		for child in cur.get_children():
			if child is Node:
				stack.append(child)
		if cur != root and str(cur.name).to_lower().find("hurtbox") != -1:
			_restore_collision_tree_under_hurtbox(cur)


func _restore_collision_tree_under_hurtbox(root: Node) -> void:
	if not _is_valid_node(root):
		return
	var stack = [root]
	while stack.size() > 0:
		var cur = stack.pop_back()
		if not _is_valid_node(cur):
			continue
		for child in cur.get_children():
			if child is Node:
				stack.append(child)
		if cur is CollisionObject2D:
			var layer = int(cur.get_meta("brotato_online_saved_collision_layer", 1))
			var mask = int(cur.get_meta("brotato_online_saved_collision_mask", 20))
			cur.set_deferred("collision_layer", layer)
			cur.set_deferred("collision_mask", mask)
		if cur is Area2D:
			cur.set_deferred("monitoring", bool(cur.get_meta("brotato_online_saved_monitoring", true)))
			cur.set_deferred("monitorable", bool(cur.get_meta("brotato_online_saved_monitorable", true)))
		if cur is CollisionShape2D or cur is CollisionPolygon2D:
			cur.set_deferred("disabled", bool(cur.get_meta("brotato_online_saved_disabled", false)))


func _is_bull_player_index(player_index: int) -> bool:
	if player_index < 0:
		return false
	if RunData != null and RunData.has_method("get_player_count") and player_index >= int(RunData.get_player_count()):
		return false
	if RunData == null:
		return false
	var character = null
	if RunData.has_method("get_player_character"):
		character = RunData.get_player_character(player_index)
	elif RunData.get("players_data") != null:
		var players_data = RunData.get("players_data")
		if typeof(players_data) == TYPE_ARRAY and player_index < players_data.size():
			var player_data = players_data[player_index]
			if player_data != null:
				character = player_data.get("current_character")
	if character == null:
		return false
	return str(character.get("my_id")) == BULL_CHARACTER_ID


func _enable_bull_remote_player_hurtbox(player: Node) -> void:
	if not _is_valid_node(player):
		return
	var invincibility_timer = player.get("_invincibility_timer")
	if invincibility_timer != null and is_instance_valid(invincibility_timer) and invincibility_timer.has_method("is_stopped") and not invincibility_timer.is_stopped():
		return
	if player.has_method("enable_hurtbox"):
		player.enable_hurtbox()
		return
	var hurtbox = player.get_node_or_null("Hurtbox")
	if hurtbox != null and hurtbox.has_method("enable"):
		hurtbox.enable()


func _apply_latest_snapshot_if_needed() -> void:
	if _latest_snapshot_tick <= 0:
		return
	if _latest_snapshot_tick == _last_applied_tick:
		return
	if not _is_in_game_scene() or _is_game_host():
		return

	var snapshot = _latest_snapshot
	var active_ids = _get_snapshot_active_entity_ids(snapshot)
	var entities = _get_snapshot_entities(snapshot)
	var now = OS.get_ticks_msec()
	var server_time_msec = _get_snapshot_server_time_msec(snapshot, now)
	_prune_local_kill_ignores(now, active_ids)

	for state in entities:
		if typeof(state) != TYPE_DICTIONARY:
			continue
		var net_id = str(state.get("net_id", ""))
		if net_id == "":
			continue
		if bool(state.get("dead", false)):
			if ENABLE_DEATH_SYNC:
				_schedule_remote_death(net_id, str(state.get("category", _host_entity_category.get(net_id, ""))), _dict_to_vec2(state.get("pos", {})), now + DEATH_VISUAL_DELAY_MSEC, "state_dead")
			else:
				_remove_host_entity(net_id, true)
			continue
		if _locally_killed_until.has(net_id):
			continue
		active_ids[net_id] = true

		var category = str(state.get("category", ""))
		var sync_mode = _get_entity_sync_mode(category, state)
		var pos = _dict_to_vec2(state.get("pos", {}))
		var vel = _dict_to_vec2(state.get("vel", {}))
		var was_known = _host_entities.has(net_id) and _is_valid_node(_host_entities[net_id])
		if not was_known and _unknown_entity_state_needs_reliable_resync(state):
			_request_unknown_entity_resync(net_id, category, "snapshot_unknown_missing_birth")
			continue
		var node = _get_or_create_host_entity(net_id, state)
		if not _is_valid_node(node):
			_request_unknown_entity_resync(net_id, category, "snapshot_spawn_failed")
			continue

		_apply_host_entity_state(node, state)
		if not was_known or not _node_has_valid_position(node):
			_set_node_global_pos(node, pos)

		# Regular enemies/trees are birth-only on clients: after creation, their local
		# movement/knockback/physics are not corrected by Host snapshots.
		if sync_mode == SYNC_MODE_HOST_MOTION:
			_host_entity_targets[net_id] = pos
			_host_entity_velocities[net_id] = vel
			_host_entity_rx_msec[net_id] = now
			_append_entity_sample(net_id, server_time_msec, pos, vel)

	_apply_remote_player_states(snapshot, server_time_msec)
	_apply_host_wave_timer_state(snapshot)
	_apply_pickups(snapshot)
	_apply_host_economy_state(snapshot)
	_apply_host_progression_state(snapshot)

	var removed = snapshot.get("removed", [])
	if ENABLE_HOST_REMOVED_SYNC and typeof(removed) == TYPE_ARRAY:
		for rid in removed:
			var id = str(rid)
			_handle_host_removed_entity(id, now, "removed")
			_remove_birth_marker(id)
			_remove_pickup_marker(id)

	if ENABLE_HOST_REMOVED_SYNC and bool(snapshot.get("prune_missing", true)):
		_prune_missing_host_entities(active_ids)

	_last_applied_tick = _latest_snapshot_tick
	_apply_count += 1

func _unknown_entity_state_needs_reliable_resync(state: Dictionary) -> bool:
	if typeof(state) != TYPE_DICTIONARY or state.empty():
		return false
	var category = str(state.get("category", ""))
	# Compact host-motion snapshots intentionally omit scene_path/data_path. If the
	# client missed the one-shot reliable birth packet, spawning from this state would
	# create a marker/white square instead of the real boss/pet/elite. Ask the Host
	# for the full reliable entity payload and do not create a placeholder yet.
	if str(state.get("scene_path", "")) == "":
		return category == "boss" or category == "pet" or category == "enemy" or category == "neutral" or category == "structure"
	if (category == "pet" or category == "structure") and str(state.get("data_path", "")) == "" and typeof(state.get("spawn_data", {})) != TYPE_DICTIONARY:
		return true
	return false


func _request_unknown_entity_resync(net_id: String, category: String, reason: String) -> void:
	if net_id == "" or _is_game_host() or not _is_online_session_active():
		return
	var now = OS.get_ticks_msec()
	var last = int(_last_entity_resync_request_msec_by_net_id.get(net_id, -UNKNOWN_ENTITY_RESYNC_REQUEST_INTERVAL_MSEC))
	if now - last < UNKNOWN_ENTITY_RESYNC_REQUEST_INTERVAL_MSEC:
		return
	_last_entity_resync_request_msec_by_net_id[net_id] = now
	var steam = _get_steam_lobby_manager()
	if steam == null or not steam.has_method("send_battle_message_to_host"):
		return
	steam.send_battle_message_to_host({
		"msg_type": "battle_entity_resync_request",
		"phase": PHASE,
		"player_index": _get_owned_player_index(),
		"net_id": net_id,
		"category": category,
		"reason": reason,
		"client_time_msec": now
	}, true)


func _get_snapshot_entities(snapshot: Dictionary) -> Array:
	var entities = snapshot.get("entities", [])
	if typeof(entities) == TYPE_ARRAY:
		return entities
	return []


func _get_snapshot_active_entity_ids(snapshot: Dictionary) -> Dictionary:
	var active = {}
	var ids = snapshot.get("active_entity_ids", [])
	if typeof(ids) == TYPE_ARRAY:
		for value in ids:
			var id = str(value)
			if id != "":
				active[id] = true
	return active


func _get_or_create_host_entity(net_id: String, state: Dictionary) -> Node:
	if _host_entities.has(net_id):
		var existing = _host_entities[net_id]
		if _is_valid_node(existing):
			return existing
		_remove_host_entity(net_id, false)

	var category = str(state.get("category", ""))
	var scene_path = str(state.get("scene_path", ""))
	var entity_type = int(state.get("entity_type", -1))
	var pos = _dict_to_vec2(state.get("pos", {}))
	var node = null
	if _is_local_combat_category(category):
		var spawn_scene_path = scene_path
		var data_path = str(state.get("data_path", ""))
		var spawn_data_state = state.get("spawn_data", {})
		if typeof(spawn_data_state) != TYPE_DICTIONARY:
			spawn_data_state = {}
		if data_path == "" and spawn_data_state.has("resource_path"):
			data_path = str(spawn_data_state.get("resource_path", ""))
		if category == "structure" and data_path == "":
			data_path = _infer_structure_data_path(scene_path, str(state.get("stats_path", "")))
		elif category == "pet" and data_path == "":
			data_path = _infer_pet_data_path(scene_path)
		var data_res = _load_resource_from_path(data_path)
		if (category == "structure" or category == "pet") and _is_spawn_data_scene_mismatch(data_res, scene_path):
			var old_data_path = data_path
			var old_data_scene_path = _get_spawn_data_scene_path(data_res)
			var repaired_path = ""
			if category == "structure":
				repaired_path = _infer_structure_data_path(scene_path, str(state.get("stats_path", "")))
			elif category == "pet":
				repaired_path = _infer_pet_data_path(scene_path)
			var repaired_res = _load_resource_from_path(repaired_path)
			if repaired_res != null and not _is_spawn_data_scene_mismatch(repaired_res, scene_path):
				data_path = repaired_path
				data_res = repaired_res
			elif category == "structure":
				return null
			else:
				data_path = ""
				data_res = null
		if data_res != null and typeof(spawn_data_state) == TYPE_DICTIONARY and not spawn_data_state.empty():
			data_res = _duplicate_with_host_value_if_needed(data_res, spawn_data_state)
		# Structures and pets must receive their original effect resource; otherwise
		# vanilla set_data()/update_data() can crash or leave the entity inert.
		# Continue/resume can expose already-existing nodes with no birth.data, so infer
		# common vanilla mappings from scene_path when Host could not recover data_path.
		if category == "structure" and data_res == null:
			return null
		if category == "pet" and data_res == null:
			node = _spawn_display_only_entity(scene_path, pos, category)
			if _is_valid_node(node):
				node.set_meta("brotato_online_display_only_fallback", true)
		else:
			spawn_scene_path = _get_spawnable_combat_scene_path(scene_path, category)
			node = _spawn_local_combat_entity(spawn_scene_path, entity_type, pos, int(state.get("player_index", -1)), data_res)
		if _is_valid_node(node) and spawn_scene_path != scene_path:
			node.set_meta("brotato_online_scene_fallback", true)
			node.set_meta("brotato_online_original_scene_path", scene_path)
	else:
		node = _spawn_display_only_entity(scene_path, pos, category)

	if not _is_valid_node(node):
		return null

	node.name = _safe_node_name("BrotatoOnlineHostEntity_" + net_id)
	node.set_meta("brotato_online_host_entity", true)
	node.set_meta("brotato_online_net_id", net_id)
	node.set_meta("brotato_online_category", category)
	if node.has_meta("brotato_online_remote_death_applying"):
		node.remove_meta("brotato_online_remote_death_applying")
	node.pause_mode = Node.PAUSE_MODE_PROCESS
	_host_entities[net_id] = node
	_host_entity_category[net_id] = category
	_host_entity_scene_path[net_id] = scene_path

	if _is_local_combat_category(category) and not _has_meta_true(node, "brotato_online_display_only_fallback"):
		_configure_local_combat_entity(node, net_id, category)
		_repair_zero_projectile_speed_for_node(node, category, "spawn:" + net_id)
	else:
		_configure_display_only_entity(node)

	return node


func _get_spawnable_combat_scene_path(scene_path: String, category: String) -> String:
	if _packed_scene_exists(scene_path):
		return scene_path
	var fallback = _get_missing_combat_scene_fallback(category)
	if _packed_scene_exists(fallback):
		return fallback
	return scene_path


func _packed_scene_exists(scene_path: String) -> bool:
	if scene_path == "":
		return false
	if not ResourceLoader.exists(scene_path):
		return false
	var packed = load(scene_path)
	return packed != null and packed is PackedScene


func _get_missing_combat_scene_fallback(category: String) -> String:
	# Clients may not have the Host's optional DLC. Never instantiate DLC-only
	# scenes by class name or script reference; degrade to vanilla combat scenes
	# and apply Host-sent stats/status after spawn. This keeps the run playable
	# instead of dropping the entity or crashing on missing resources.
	match category:
		"enemy":
			return "res://entities/units/enemies/enemy.tscn"
		"boss":
			return "res://entities/units/enemies/boss/boss.tscn"
		"neutral":
			return "res://entities/units/neutral/tree.tscn"
		"pet":
			return "res://entities/units/pet/pet.tscn"
	return ""


func _infer_structure_data_path(scene_path: String, stats_path: String = "") -> String:
	# Vanilla structure scenes need the corresponding TurretEffect/Structure effect
	# resource, not the raw stats resource. This fallback is intentionally narrow:
	# it only covers common vanilla structures that appear in continue/resume before
	# the Host can recover an exact birth data_path.
	match scene_path:
		"res://entities/structures/turret/turret.tscn":
			return "res://items/all/turret/turret_effect_1.tres"
		"res://entities/structures/turret/flame/flame_turret.tscn":
			return "res://items/all/turret_flame/turret_flame_effect_1.tres"
		"res://entities/structures/turret/laser/laser_turret.tscn":
			return "res://items/all/turret_laser/turret_laser_effect_1.tres"
		"res://entities/structures/turret/rocket/rocket_turret.tscn":
			return "res://items/all/turret_rocket/turret_rocket_effect_1.tres"
		"res://entities/structures/turret/healing/healing_turret.tscn":
			return "res://items/all/turret_healing/turret_healing_effect_1.tres"
		"res://entities/structures/turret/tyler/tyler.tscn":
			return "res://items/all/tyler/tyler_effect_1.tres"
		"res://entities/structures/turret/wandering_bot/wandering_bot.tscn":
			return "res://items/all/wandering_bot/wandering_bot_effect_1.tres"
		"res://entities/structures/turret/garden/garden.tscn":
			return "res://items/all/garden/garden_effect_1.tres"
		"res://entities/structures/landmine/landmine.tscn":
			return "res://items/all/landmines/landmines_effect_1.tres"
	return ""


func _infer_pet_data_path(scene_path: String) -> String:
	match scene_path:
		"res://entities/units/pet/blazemander/blazemander.tscn":
			return "res://items/all/blazemander/blazemander_effect_0.tres"
		"res://entities/units/pet/bonk_dog/bonk_dog.tscn":
			return "res://items/all/bonk_dog/bonk_dog_effect_0.tres"
		"res://entities/units/pet/bot_o_mine/bot_o_mine.tscn":
			return "res://items/all/bot_o_mine/bot_o_mine_effect_0.tres"
		"res://entities/units/pet/catling_gun/catling_gun.tscn":
			return "res://items/all/catling_gun/catling_gun_effect_0.tres"
		"res://entities/units/pet/doc_moth/doc_moth.tscn":
			return "res://items/all/doc_moth/doc_moth_effect_0.tres"
		"res://entities/units/pet/jellyshield/jellyshield.tscn":
			return "res://items/all/jellyshield/jellyshield_effect_1.tres"
		"res://entities/units/pet/lootworm/lootworm.tscn":
			return "res://items/all/lootworm/lootworm_effect_0.tres"
		"res://entities/units/pet/ratzilla/ratzilla.tscn":
			return "res://items/all/ratzilla/ratzilla_effect_0.tres"
		"res://entities/units/pet/scapegoat/scapegoat.tscn":
			return "res://items/all/scapegoat/scapegoat_effect_0.tres"
	return ""


func _spawn_local_combat_entity(scene_path: String, entity_type: int, pos: Vector2, player_index: int, data_res: Resource = null) -> Node:
	if scene_path == "":
		return null
	var packed = load(scene_path)
	if packed == null or not (packed is PackedScene):
		return null
	var locator = _get_runtime_locator()
	var spawner = locator.get_entity_spawner() if locator != null and locator.has_method("get_entity_spawner") else null
	if spawner != null and spawner.has_method("spawn_entity"):
		var args = spawner.get("_spawn_entity_args")
		if args != null:
			args.position = pos
			args.type = entity_type
			args.player_index = player_index

			var spawned = spawner.spawn_entity(packed, args, data_res, null, -1)
			if _is_valid_node(spawned):
				return spawned

	var node = packed.instance()
	if node == null:
		return null
	var parent = _get_entities_parent()
	if parent == null:
		node.queue_free()
		return null
	parent.add_child(node)
	_init_fallback_local_combat_entity(node, spawner, entity_type, pos, player_index, data_res)
	_set_node_global_pos(node, pos)
	return node


func _spawn_display_only_entity(scene_path: String, pos: Vector2, category: String) -> Node:
	var node = null
	if scene_path != "":
		var packed = load(scene_path)
		if packed != null and packed is PackedScene:
			node = packed.instance()
	if node == null:
		node = _make_marker_for_category(category)
	if node == null:
		return null
	var parent = _get_entities_parent()
	if parent == null:
		node.queue_free()
		return null
	parent.add_child(node)
	_set_node_global_pos(node, pos)
	return node


func _init_fallback_local_combat_entity(node: Node, spawner: Node, entity_type: int, pos: Vector2, player_index: int, data_res: Resource = null) -> void:
	# If EntitySpawner.spawn_entity() could not be used, a raw PackedScene instance must still
	# receive the vanilla Unit/Enemy init call. Otherwise MovementBehavior._parent stays null
	# and follow_target_movement_behavior.gd crashes in get_target_position().
	if not _is_valid_node(node):
		return
	if node.get("player_index") != null:
		node.set("player_index", player_index)
	if node.has_method("init") and spawner != null:
		var zone_min = spawner.get("_zone_min_pos")
		var zone_max = spawner.get("_zone_max_pos")
		var players = spawner.get("_players")
		if typeof(zone_min) != TYPE_VECTOR2:
			zone_min = Vector2.ZERO
		if typeof(zone_max) != TYPE_VECTOR2:
			zone_max = Vector2.ZERO
		if typeof(players) != TYPE_ARRAY:
			players = []
		node.call("init", zone_min, zone_max, players, spawner)
	if data_res != null:
		if node.has_method("set_data"):
			node.call("set_data", data_res)
		elif node.has_method("update_data"):
			node.call("update_data", data_res)
	_ensure_combat_behavior_parent_links(node)


func _ensure_combat_behavior_parent_links(node: Node) -> void:
	if not _is_valid_node(node):
		return
	var stack = [node]
	while stack.size() > 0:
		var cur = stack.pop_back()
		if not _is_valid_node(cur):
			continue
		for child in cur.get_children():
			if _is_valid_node(child):
				stack.append(child)
		if cur == node:
			continue
		if not cur.has_method("init"):
			continue
		var script = cur.get_script()
		var script_path = ""
		if script != null and script is Resource:
			script_path = str(script.resource_path)
		var name_lower = str(cur.name).to_lower()
		var looks_like_behavior = script_path.find("/behaviors/") != -1 or script_path.find("_behavior.gd") != -1 or name_lower.find("behavior") != -1
		if not looks_like_behavior:
			continue
		# Re-init behavior children defensively. Behavior.init(parent) is idempotent for vanilla
		# MovementBehavior/AttackBehavior/TargetBehavior subclasses and fixes pooled/fallback nodes.
		cur.call("init", node)


func _repair_zero_projectile_speed_for_node(node: Node, category: String, reason: String = "") -> void:
	# Client-side replicated turrets/structure-like pets must never reach vanilla
	# PlayerProjectile._set_time_until_max_range() with projectile_speed == 0.
	# That crashes with Division by Zero in player_projectile.gd. Prefer the node's
	# base_stats speed when available; otherwise use Brotato's common default.
	if not _is_valid_node(node):
		return
	if category != "structure" and category != "pet":
		return
	var stats = node.get("stats")
	if stats == null or stats.get("projectile_speed") == null:
		return
	var speed = int(stats.get("projectile_speed"))
	if speed > 0:
		return
	var fallback_speed = 3000
	var base_stats = node.get("base_stats")
	if base_stats != null and base_stats.get("projectile_speed") != null:
		var base_speed = int(base_stats.get("projectile_speed"))
		if base_speed > 0:
			fallback_speed = base_speed
	stats.set("projectile_speed", fallback_speed)
	if not node.has_meta("brotato_online_repaired_zero_projectile_speed"):
		node.set_meta("brotato_online_repaired_zero_projectile_speed", true)


func _configure_local_combat_entity(node: Node, net_id: String, category: String) -> void:
	if not _is_valid_node(node):
		return
	_ensure_combat_behavior_parent_links(node)
	var host_motion = _get_entity_sync_mode(category, {}) == SYNC_MODE_HOST_MOTION
	# Enemy/tree/boss drops are local-only visuals on clients. Structures/pets must not spawn
	# loot just because they now run local logic. Boss covers elites and bosses in Brotato.
	node.set("can_drop_loot", category == "enemy" or category == "neutral" or category == "boss")
	node.set("is_loot", false)

	if host_motion:
		_configure_host_motion_combat_entity(node, category)
	else:
		# Regular enemies/neutral entities must keep their local movement, attack,
		# knockback and physics. The Host only provided the birth position.
		if node.get("_can_move") != null:
			node.set("_can_move", true)
		if node.get("_move_locked") != null:
			node.set("_move_locked", false)

	_enable_area_named(node, "Hurtbox", true)
	_enable_area_named(node, "Hitbox", true)

	# Vanilla pools reuse the same enemy node for a new Host net_id. Godot signal
	# connections keep their old bind arguments across pooling, so a reused enemy can
	# otherwise emit died(old_net_id) while its meta already says enemy_new_id. Always
	# refresh these online-layer signal binds when configuring a replicated combat node.
	if node.has_signal("died"):
		if node.is_connected("died", self, "_on_host_local_entity_died"):
			node.disconnect("died", self, "_on_host_local_entity_died")
		var err = node.connect("died", self, "_on_host_local_entity_died", [net_id, category])
		if err == OK:
			_connected_died_ids[net_id] = true

	if node.has_signal("took_damage") and node.is_connected("took_damage", self, "_on_host_local_boss_took_damage"):
		node.disconnect("took_damage", self, "_on_host_local_boss_took_damage")
	if category == "boss" and node.has_signal("took_damage"):
		var err2 = node.connect("took_damage", self, "_on_host_local_boss_took_damage", [net_id])
		if err2 == OK:
			_connected_damage_ids[net_id] = true

	if node.has_meta("brotato_online_remote_death_applying"):
		node.remove_meta("brotato_online_remote_death_applying")


func _configure_host_motion_combat_entity(node: Node, category: String) -> void:
	if not _is_valid_node(node):
		return
	if category == "pet":
		_configure_host_motion_pet(node)
		return
	# Bosses are still Host-motion controlled, but do not clear knockback/velocity.
	# Lock only their autonomous movement/AI so Host interpolation does not fight it.
	if node.get("_can_move") != null:
		node.set("_can_move", false)
	if node.get("_move_locked") != null:
		node.set("_move_locked", true)
	_disable_behavior_children(node)


func _configure_host_motion_pet(node: Node) -> void:
	# Pets such as CatlingGun implement their weapon logic directly in _physics_process().
	# Treating pets as display-only, or disabling target/attack children, prevents
	# client-side projectile visuals and local enemy damage.  Keep pet logic alive,
	# but lock autonomous movement so Host position interpolation remains authoritative.
	if not _is_valid_node(node):
		return
	if node.get("_move_locked") != null:
		node.set("_move_locked", true)
	if node.get("_can_move") != null:
		node.set("_can_move", true)
	node.set_process(true)
	node.set_physics_process(true)
	_enable_pet_runtime_areas(node)


func _enable_pet_runtime_areas(node: Node) -> void:
	if not _is_valid_node(node):
		return
	if node is Area2D:
		node.set_deferred("monitoring", true)
		node.set_deferred("monitorable", true)
		if node.get("active") != null:
			node.set("active", true)
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.set_deferred("disabled", false)
	for child in node.get_children():
		if child is Node:
			_enable_pet_runtime_areas(child)


func _configure_display_only_entity(node: Node) -> void:
	if not _is_valid_node(node):
		return
	node.set("can_drop_loot", false)
	node.set("is_loot", false)
	_disable_logic_tree(node)
	_disable_collision_tree(node)


func _apply_host_entity_state(node: Node, state: Dictionary) -> void:
	if not _is_valid_node(node):
		return
	var current_stats = node.get("current_stats")
	var max_stats = node.get("max_stats")
	var max_health = int(state.get("max_health", -1))
	var health = int(state.get("health", -1))
	var damage = int(state.get("damage", -1))
	var speed = int(state.get("speed", -1))
	var armor = int(state.get("armor", -1))

	# Apply max first, then current. Cursed enemies are born with boosted max/current
	# health on the Host; regular birth-only enemies must receive that initial
	# health too, not just bosses.
	if max_stats != null and max_health >= 0:
		max_stats.health = max_health
	if current_stats != null:
		if health >= 0:
			current_stats.health = health
		if damage >= 0:
			current_stats.damage = damage
			_apply_entity_runtime_damage(node, damage)
		if speed >= 0:
			current_stats.speed = speed
		if armor >= 0:
			current_stats.armor = armor
	_apply_host_spawn_data_state_to_existing_entity(node, state)
	_apply_online_drop_result_to_entity(node, state)
	_apply_status_flags_to_entity(node, state)


func _apply_online_drop_result_to_entity(node: Node, state: Dictionary) -> void:
	if not _is_valid_node(node):
		return
	var drop_result = state.get("online_drop_result", {})
	if typeof(drop_result) != TYPE_DICTIONARY or drop_result.empty():
		return
	node.set_meta("brotato_online_drop_result", drop_result.duplicate(true))


func _apply_host_spawn_data_state_to_existing_entity(node: Node, state: Dictionary) -> void:
	if not _is_valid_node(node):
		return
	var category = str(state.get("category", ""))
	if category != "structure" and category != "pet":
		return
	var spawn_data_state = state.get("spawn_data", {})
	if typeof(spawn_data_state) != TYPE_DICTIONARY or spawn_data_state.empty():
		return
	var scene_path = str(state.get("scene_path", ""))
	var data_path = str(state.get("data_path", ""))
	if data_path == "" and spawn_data_state.has("resource_path"):
		data_path = str(spawn_data_state.get("resource_path", ""))
	if data_path == "":
		if category == "structure":
			data_path = _infer_structure_data_path(scene_path, str(state.get("stats_path", "")))
		elif category == "pet":
			data_path = _infer_pet_data_path(scene_path)
	if data_path == "":
		return
	var data_res = _load_resource_from_path(data_path)
	if data_res == null:
		return
	if (category == "structure" or category == "pet") and _is_spawn_data_scene_mismatch(data_res, scene_path):
		return
	var signature = data_path + ":" + to_json(spawn_data_state)
	if node.has_meta("brotato_online_spawn_data_signature") and str(node.get_meta("brotato_online_spawn_data_signature")) == signature:
		return
	data_res = _duplicate_with_host_value_if_needed(data_res, spawn_data_state)
	if data_res == null:
		return
	if node.has_method("set_data"):
		node.call("set_data", data_res)
	elif node.has_method("update_data"):
		node.call("update_data", data_res)
	else:
		return
	node.set_meta("brotato_online_spawn_data_signature", signature)
func _apply_status_flags_to_entity(node: Node, state: Dictionary) -> void:
	if not _is_valid_node(node):
		return
	var flags = state.get("status_flags", {})
	if typeof(flags) != TYPE_DICTIONARY:
		return
	# Absence of the key means: this entity category does not use the curse status
	# channel. Structure/pet data resources are still handled by spawn_data.
	if not flags.has("cursed"):
		return
	var category = str(state.get("category", ""))
	var cursed = _safe_bool(flags.get("cursed", false))
	if category == "structure":
		_apply_structure_cursed_visual(node, cursed)
		return
	_set_entity_cursed_authoritative(node, cursed, category)


func _apply_structure_cursed_visual(node: Node, cursed: bool) -> void:
	if not _is_valid_node(node):
		return
	if not cursed:
		# Do not aggressively remove visuals from structures: Host often first sees a
		# structure before vanilla set_data() has finished applying its cursed data.
		# A later true packet is authoritative for the visual fix.
		return
	if node.get("is_cursed") != null:
		node.set("is_cursed", true)
	if not node.has_meta("brotato_online_structure_curse_particles") and node.has_method("add_curse_particles"):
		node.call("add_curse_particles")
		node.set_meta("brotato_online_structure_curse_particles", true)
	if not node.has_meta("brotato_online_structure_curse_outline") and node.has_method("add_outline"):
		node.call("add_outline", Color("ca61ff"))
		node.set_meta("brotato_online_structure_curse_outline", true)
	node.set_meta("brotato_online_structure_cursed", true)
func _set_entity_cursed_authoritative(node: Node, cursed: bool, category: String = "") -> void:
	if not _is_valid_node(node):
		return
	if not _can_apply_enemy_curse_status(node, category):
		# Old hosts or malformed packets may still send status_flags.cursed for
		# pets/structures/fallback display nodes. Ignore it: CurseEnemyEffectBehavior
		# requires a real Enemy parent.
		return
	if cursed:
		node.set_meta("brotato_online_cursed", true)
		if node.get("is_cursed") != null:
			node.set("is_cursed", true)
		if node.get("can_be_boosted") != null:
			node.set("can_be_boosted", false)
		if not _has_curse_effect_behavior(node):
			var fx = _make_curse_enemy_effect_behavior(node)
			var container = _get_effect_behaviors_container(node)
			if fx != null and container != null:
				container.add_child(fx)
			elif node.has_method("add_outline"):
				node.call("add_outline", Color("ca61ff"))
		elif node.has_method("add_outline"):
			node.call("add_outline", Color("ca61ff"))
		node.set_meta("brotato_online_curse_outline_applied", true)
		return

	_clear_entity_curse_effect(node)
	if node.has_meta("brotato_online_cursed"):
		node.remove_meta("brotato_online_cursed")
	if node.has_meta("brotato_online_curse_outline_applied"):
		node.remove_meta("brotato_online_curse_outline_applied")
	if node.get("is_cursed") != null:
		node.set("is_cursed", false)


func _can_apply_enemy_curse_status(node: Node, category: String) -> bool:
	if not _is_real_enemy_node(node):
		return false
	if category == "" or category == "enemy" or category == "boss":
		return true
	return false


func _is_real_enemy_node(node: Node) -> bool:
	return _is_valid_node(node) and node is Enemy


func _get_effect_behaviors_container(node: Node) -> Node:
	if not _is_valid_node(node):
		return null
	var direct = node.get("effect_behaviors")
	if _is_valid_node(direct):
		return direct
	var by_name = node.get_node_or_null("EffectBehaviors")
	if _is_valid_node(by_name):
		return by_name
	return null


func _make_curse_enemy_effect_behavior(parent: Node) -> Node:
	if not _is_real_enemy_node(parent):
		return null
	var scene_path = "res://dlcs/dlc_1/effect_behaviors/enemy/curse_enemy_effect_behavior.tscn"
	if not ResourceLoader.exists(scene_path):
		return null
	var packed = load(scene_path)
	if packed == null or not (packed is PackedScene):
		return null
	var fx = packed.instance()
	if fx == null or not is_instance_valid(fx) or not (fx is Node):
		return null
	if fx.has_method("init"):
		var initialized = fx.call("init", parent)
		if initialized != null and initialized is Node:
			fx = initialized
	return fx


func _clear_entity_curse_effect(node: Node) -> void:
	var container = _get_effect_behaviors_container(node)
	if container != null:
		for child in container.get_children():
			if _is_curse_effect_behavior_node(child):
				container.remove_child(child)
				child.queue_free()
	if node.has_method("remove_outline"):
		node.call("remove_outline", Color("ca61ff"))
		node.call("remove_outline", Color("8d55ff"))


func _has_curse_effect_behavior(node: Node) -> bool:
	var container = _get_effect_behaviors_container(node)
	if container == null:
		return false
	for child in container.get_children():
		if _is_curse_effect_behavior_node(child):
			return true
	return false


func _is_curse_effect_behavior_node(node: Node) -> bool:
	if not _is_valid_node(node):
		return false
	var script = node.get_script()
	var script_path = ""
	if script != null and script is Resource:
		script_path = str(script.resource_path).to_lower()
	return script_path.find("curse_enemy_effect_behavior.gd") != -1


func _apply_entity_runtime_damage(node: Node, damage: int) -> void:
	if not _is_valid_node(node) or damage < 0:
		return
	var hitbox = node.get_node_or_null("Hitbox")
	if hitbox != null and hitbox.get("damage") != null:
		hitbox.set("damage", damage)
	_apply_damage_to_attack_behavior_children(node, damage)


func _apply_damage_to_attack_behavior_children(node: Node, damage: int) -> void:
	if not _is_valid_node(node):
		return
	var stack = [node]
	while stack.size() > 0:
		var cur = stack.pop_back()
		if not _is_valid_node(cur):
			continue
		for child in cur.get_children():
			if _is_valid_node(child):
				stack.append(child)
		if cur == node:
			continue
		var script = cur.get_script()
		var script_path = ""
		if script != null and script is Resource:
			script_path = str(script.resource_path).to_lower()
		var name_lower = str(cur.name).to_lower()
		var looks_like_attack = script_path.find("attack") != -1 or name_lower.find("attack") != -1
		if not looks_like_attack:
			continue
		# Do not write enemy snapshot damage into ShootingAttackBehavior fields.
		# - damage is the vanilla/base projectile input used by Enemy.reset_damage_stat().
		# - projectile_damage can also be recalculated by vanilla right before some
		#   attacks/death attacks (for example Pufferfish). The entity snapshot's
		#   `damage` is body/contact damage, not a per-projectile authoritative value.
		# Leave projectile damage to the vanilla attack behavior on this client; the
		# Player extension below clamps obviously corrupted enemy-projectile hits for
		# the owned online client.
		pass


func _update_host_entity_positions(delta: float) -> void:
	if _host_entities.empty():
		return
	var now = OS.get_ticks_msec()
	var target_time = _get_estimated_host_time_msec(now) - ENTITY_INTERPOLATION_DELAY_MSEC
	var alpha = clamp(delta * HOST_ENTITY_LERP_SPEED, 0.0, 1.0)
	for id_value in _host_entities.keys():
		var id = str(id_value)
		var category = str(_host_entity_category.get(id, ""))
		if _get_entity_sync_mode(category, {}) != SYNC_MODE_HOST_MOTION:
			continue
		var node = _host_entities[id]
		if not _is_valid_node(node):
			continue
		var sample = _sample_position(_host_entity_samples.get(id, []), target_time, _host_entity_targets.get(id, _get_node_global_pos(node)), _host_entity_velocities.get(id, Vector2.ZERO))
		var display_target = sample[0]
		var current = _get_node_global_pos(node)
		_set_node_global_pos(node, current.linear_interpolate(display_target, alpha))

func _apply_remote_player_states(snapshot: Dictionary, server_time_msec: int) -> void:
	var players = snapshot.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return
	var owned_index = _get_owned_player_index()
	var now = OS.get_ticks_msec()
	for p in players:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var idx = int(p.get("player_index", -1))
		if idx < 0 or idx == owned_index:
			continue
		var pos = _dict_to_vec2(p.get("pos", {}))
		var vel = _dict_to_vec2(p.get("vel", {}))
		_remote_player_targets[idx] = pos
		_remote_player_velocities[idx] = vel
		_remote_player_rx_msec[idx] = now
		_append_remote_player_sample(idx, server_time_msec, pos, vel)
		_apply_remote_player_runtime_state(idx, p)


func _update_remote_player_positions(delta: float) -> void:
	if _remote_player_targets.empty():
		return
	var locator = _get_runtime_locator()
	if locator == null or not locator.has_method("get_players"):
		return
	var players = locator.get_players()
	if typeof(players) != TYPE_ARRAY:
		return
	var alpha = clamp(delta * HOST_PLAYER_LERP_SPEED, 0.0, 1.0)
	var now = OS.get_ticks_msec()
	var target_time = _get_estimated_host_time_msec(now) - PLAYER_INTERPOLATION_DELAY_MSEC
	for i in range(players.size()):
		var player = players[i]
		if not _is_valid_node(player):
			continue
		var idx = _get_player_index_from_node(player, i)
		if not _remote_player_targets.has(idx):
			continue
		var sample = _sample_position(_remote_player_samples.get(idx, []), target_time, _remote_player_targets.get(idx, _get_node_global_pos(player)), _remote_player_velocities.get(idx, Vector2.ZERO))
		_set_node_global_pos(player, _get_node_global_pos(player).linear_interpolate(sample[0], alpha))


func _apply_remote_player_runtime_state(player_index: int, state: Dictionary) -> void:
	if _is_client_owned_player_index(player_index):
		return
	var locator = _get_runtime_locator()
	if locator == null or not locator.has_method("get_players"):
		return
	var players = locator.get_players()
	if typeof(players) != TYPE_ARRAY:
		return
	var player = null
	for i in range(players.size()):
		var candidate = players[i]
		if _is_valid_node(candidate) and _get_player_index_from_node(candidate, i) == player_index:
			player = candidate
			break
	if not _is_valid_node(player):
		return
	_disable_player_hurtbox_for_net_proxy(player, player_index, "client_remote_snapshot")
	var current_stats = player.get("current_stats")
	var max_stats = player.get("max_stats")
	var host_hp = int(state.get("health", state.get("hp", -1)))
	if host_hp >= 0:
		player.set_meta("brotato_online_last_host_hp", host_hp)
	var remote_dead = false
	if state.has("dead") and bool(state.get("dead", false)):
		remote_dead = true
	if host_hp >= 0 and host_hp <= 0:
		# Host can be sampled with HP already zero before the vanilla dead flag is visible
		# in the snapshot. Treat HP<=0 as remote death authority too.
		remote_dead = true
	if not ENABLE_PLAYER_DEATH_SYNC:
		remote_dead = false
	if current_stats != null:
		if host_hp >= 0:
			current_stats.health = host_hp
		if int(state.get("speed", -1)) >= 0:
			current_stats.speed = int(state.get("speed", current_stats.speed))
		if int(state.get("armor", -1)) >= 0:
			current_stats.armor = int(state.get("armor", current_stats.armor))
		if float(state.get("dodge", -1.0)) >= 0.0:
			current_stats.dodge = float(state.get("dodge", current_stats.dodge))
	var host_max_hp = int(state.get("max_health", state.get("max_hp", -1)))
	if max_stats != null and host_max_hp >= 0:
		max_stats.health = host_max_hp
	var remote_hit_protection = int(state.get("hit_protection", -1))
	if remote_dead:
		remote_hit_protection = 0
	if remote_hit_protection >= 0 and player.get("_hit_protection") != null:
		player.set("_hit_protection", remote_hit_protection)
	if ENABLE_PLAYER_DEATH_SYNC and (state.has("dead") or (host_hp >= 0 and host_hp <= 0)):
		_apply_remote_dead_display_to_player(player, remote_dead)

	if current_stats != null and player.has_signal("health_updated"):
		var mhp = int(max_stats.health) if max_stats != null else int(current_stats.health)
		player.emit_signal("health_updated", player, int(current_stats.health), mhp)

func _apply_remote_dead_display_to_player(player, dead_state: bool) -> void:
	# Remote players are display/proxy nodes. Once their owner reports death, mirror the
	# vanilla death lifecycle locally so they do not remain as a standing 0-HP player.
	# Do not resurrect a proxy whose vanilla death lifecycle already ran; the next wave
	# creates fresh player nodes.
	if not _is_valid_node(player):
		return
	var current_stats = player.get("current_stats")
	var max_stats = player.get("max_stats")
	var vanilla_dead = false
	if player.get("dead") != null:
		vanilla_dead = bool(player.get("dead"))

	if dead_state:
		if current_stats != null:
			current_stats.health = 0
		if player.get("_hit_protection") != null:
			player.set("_hit_protection", 0)
		player.set_meta("brotato_online_remote_dead", true)
		player.set_meta("brotato_online_last_host_dead", true)
		if not vanilla_dead:
			player.set_meta("brotato_online_remote_death_applying", true)
			player.set_meta("brotato_online_allow_remote_die", true)
			if player.has_method("die"):
				player.die()
			elif player.get("dead") != null:
				player.set("dead", true)
			player.set_meta("brotato_online_allow_remote_die", false)
			player.set_meta("brotato_online_remote_death_applying", false)
			vanilla_dead = bool(player.get("dead")) if player.get("dead") != null else false
			if not vanilla_dead:
				# Defensive fallback: if an extension or scene timing prevented Player.die()
				# from marking the proxy dead, force the dead flag/pose so 0-HP remote
				# players do not stay alive during the wave.
				if player.get("dead") != null:
					player.set("dead", true)
				_force_remote_player_death_pose(player)
				vanilla_dead = true
	else:
		player.set_meta("brotato_online_last_host_dead", false)
		if vanilla_dead:
			return
		player.set_meta("brotato_online_remote_dead", false)

	if vanilla_dead:
		# Avoid Player.update_animation()/temp-stat assertions after Player.die() freed
		# visual children such as RunningSmoke, Legs and Shadow.
		player.set_physics_process(false)
		player.set_process(false)

	if current_stats != null and player.has_signal("health_updated"):
		var mhp = int(max_stats.health) if max_stats != null else int(current_stats.health)
		player.emit_signal("health_updated", player, int(current_stats.health), mhp)


func _allows_client_boss_elite_death_report(category: String) -> bool:
	# Brotato stores elites in the same boss entity list/type used for bosses.
	return ENABLE_CLIENT_BOSS_ELITE_DEATH_REPORTS and (category == "boss" or category == "elite")


func _on_host_local_entity_died(entity, _die_args, net_id: String, category: String) -> void:
	if _is_game_host():
		return
	if net_id == "":
		return
	if not ENABLE_DEATH_REPORTS:
		if _allows_client_boss_elite_death_report(category):
			# Bosses/elites are Host-motion controlled. If a client-side kill removes the
			# local proxy first, do not let the next compact Host snapshot recreate this
			# net_id as the generic baby/boss fallback while the reliable claim is in flight.
			_locally_killed_until[net_id] = OS.get_ticks_msec() + LOCAL_KILL_IGNORE_MSEC
			_cleanup_host_entity_tracking(net_id)
			_send_entity_kill_claim(net_id, category, entity)
			_flush_boss_damage_reports(true)
			return
		_cleanup_host_entity_tracking(net_id)
		return

	# Defensive fallback for any stale pooled signal connection that survived from an
	# older build/session: trust the node's current replicated meta id if it points
	# back to this same node. This prevents cleanup/kill-claim from targeting an old id.
	if _is_valid_node(entity) and entity.has_meta("brotato_online_net_id"):
		var meta_net_id = str(entity.get_meta("brotato_online_net_id"))
		if meta_net_id != "" and meta_net_id != net_id:
			if _host_entities.has(meta_net_id) and _host_entities[meta_net_id] == entity:
				net_id = meta_net_id
				category = str(_host_entity_category.get(net_id, category))
			else:
				return

	if _pending_remote_deaths.has(net_id):
		_cleanup_host_entity_tracking(net_id)
		return
	if _is_valid_node(entity) and entity.has_meta("brotato_online_remote_death_applying") and bool(entity.get_meta("brotato_online_remote_death_applying")):
		_cleanup_host_entity_tracking(net_id)
		return

	_locally_killed_until[net_id] = OS.get_ticks_msec() + LOCAL_KILL_IGNORE_MSEC
	_cleanup_host_entity_tracking(net_id)
	_send_entity_kill_claim(net_id, category, entity)


func _send_entity_kill_claim(net_id: String, category: String, entity: Node = null) -> void:
	if not ENABLE_DEATH_REPORTS and not _allows_client_boss_elite_death_report(category):
		return
	if net_id == "" or _sent_kill_claim_ids.has(net_id):
		return
	_sent_kill_claim_ids[net_id] = true
	var steam = _get_steam_lobby_manager()
	if steam == null or not steam.has_method("send_battle_message_to_host"):
		return
	var death_pos = Vector2.ZERO
	if _is_valid_node(entity):
		death_pos = _get_node_global_pos(entity)
	elif _host_entity_targets.has(net_id):
		death_pos = _host_entity_targets[net_id]
	var msg = {
		"msg_type": "entity_kill_claim",
		"phase": PHASE,
		"player_index": _get_owned_player_index(),
		"net_id": net_id,
		"category": category,
		"pos": _vec_to_dict(death_pos),
		"client_time_msec": OS.get_ticks_msec()
	}
	steam.send_battle_message_to_host(msg, true)


func _on_host_local_boss_took_damage(_unit, value: int, _knockback_direction: Vector2, _is_crit: bool, is_dodge: bool, is_protected: bool, _armor_did_something: bool, _args, _hit_type: int, _is_one_shot: bool, net_id: String) -> void:
	if _is_game_host() or is_dodge or is_protected or int(value) <= 0 or net_id == "":
		return
	# Do not revive broad client damage reports here. Entity death claims already cover
	# boss/elite local deaths; this damage path remains a fast Vorpal one-shot fallback.
	if not (ENABLE_CLIENT_BOSS_ONE_SHOT_REPORTS and bool(_is_one_shot)):
		return
	_pending_boss_damage[net_id] = max(int(_pending_boss_damage.get(net_id, 0)), int(value))
	_pending_boss_one_shots[net_id] = true
	_locally_killed_until[net_id] = OS.get_ticks_msec() + LOCAL_KILL_IGNORE_MSEC
	_flush_boss_damage_reports(true)


func _flush_boss_damage_reports(force: bool) -> void:
	if not ENABLE_CLIENT_BOSS_ONE_SHOT_REPORTS:
		_pending_boss_damage.clear()
		_pending_boss_one_shots.clear()
		return
	if _pending_boss_damage.empty():
		return
	var now = OS.get_ticks_msec()
	if not force and now - _last_boss_damage_send_msec < BOSS_DAMAGE_SEND_INTERVAL_MSEC:
		return
	_last_boss_damage_send_msec = now
	var reports = []
	for id_value in _pending_boss_damage.keys():
		var id = str(id_value)
		reports.append({"net_id": id, "damage": int(_pending_boss_damage[id]), "one_shot": bool(_pending_boss_one_shots.get(id, false))})
	_pending_boss_damage.clear()
	_pending_boss_one_shots.clear()
	var steam = _get_steam_lobby_manager()
	if steam != null and steam.has_method("send_battle_message_to_host"):
		steam.send_battle_message_to_host({
			"msg_type": "boss_damage_report",
			"phase": PHASE,
			"player_index": _get_owned_player_index(),
			"reports": reports,
			"client_time_msec": now
		}, true)


func send_owned_player_terminal_state(player: Node = null, reason: String = "terminal") -> void:
	if _is_game_host() or not _is_online_session_active():
		return
	if _sent_owned_player_terminal_state and _last_terminal_player_state_reason == reason:
		return
	var owned_index = _get_owned_player_index()
	if owned_index < 0:
		return
	if _is_valid_node(player):
		var passed_index = _get_player_index_from_node(player, -999999)
		if passed_index != owned_index:
			# Main._on_player_died can also fire for Host-owned mirrored players on a client.
			# A client may only ever report death for its own slot; otherwise it can falsely
			# kill P1 on Host when a remote proxy enters the local fail path.
			return
	else:
		player = _get_owned_player_node()
	if not _is_valid_node(player):
		return
	var current_stats = player.get("current_stats")
	var local_hp = int(current_stats.health) if current_stats != null else -1
	var local_dead = bool(player.get("dead"))
	if current_stats != null and local_hp <= 0:
		local_dead = true
	if not local_dead:
		# Terminal cleanup can be triggered by scene/fail flow for reasons unrelated to
		# this client's owned player. Never convert an alive owned player into hp=0 here.
		return
	if not ENABLE_PLAYER_DEATH_REPORTS:
		return
	_sent_owned_player_terminal_state = _send_owned_player_state_packet(player, true, reason, 3)
	if _sent_owned_player_terminal_state:
		_last_terminal_player_state_reason = reason


func _poll_and_send_player_state(force: bool) -> void:
	var player = _get_owned_player_node()
	if not _is_valid_node(player):
		return
	var current_stats = player.get("current_stats")
	var local_hp = int(current_stats.health) if current_stats != null else -1
	var local_dead = bool(player.get("dead"))
	if current_stats != null and local_hp <= 0:
		# Some death packets can be sampled while HP already reached zero but before / instead of
		# the vanilla dead flag being visible to the autoload. Treat HP<=0 as death authority.
		local_dead = true
	if local_dead and not ENABLE_PLAYER_DEATH_REPORTS:
		return

	var now = OS.get_ticks_msec()
	# Do not let the normal interval hide a death edge. The terminal packet must be
	# sent before the client-side fail cleanup suspends this replica layer.
	if not force and not local_dead and now - _last_player_state_send_msec < PLAYER_STATE_SEND_INTERVAL_MSEC:
		return
	if not force and local_dead and _last_sent_player_dead_state and now - _last_player_state_send_msec < PLAYER_STATE_SEND_INTERVAL_MSEC:
		return
	_send_owned_player_state_packet(player, false, "poll", 1)


func _send_owned_player_state_packet(player: Node, force_dead: bool, reason: String, repeat_count: int = 1) -> bool:
	if _is_game_host() or not _is_online_session_active():
		return false
	if force_dead and not ENABLE_PLAYER_DEATH_REPORTS:
		return false
	if not _is_valid_node(player):
		return false
	var owned_index = _get_owned_player_index()
	if owned_index < 0:
		return false
	var node_index = _get_player_index_from_node(player, owned_index)
	if node_index != owned_index:
		return false
	var now = OS.get_ticks_msec()
	_last_player_state_send_msec = now
	var current_stats = player.get("current_stats")
	var max_stats = player.get("max_stats")
	var local_hp = int(current_stats.health) if current_stats != null else -1
	var local_dead = bool(player.get("dead"))
	var local_hit_protection = int(_safe_node_get(player, "_hit_protection", 0))
	if current_stats != null and local_hp <= 0:
		local_dead = true
	if force_dead:
		local_dead = true
		if local_hp > 0:
			local_hp = 0
	if local_dead and not ENABLE_PLAYER_DEATH_REPORTS:
		return false
	if local_dead:
		local_hit_protection = 0
	var msg = {
		"msg_type": "player_state",
		"phase": PHASE,
		"player_index": owned_index,
		"pos": _vec_to_dict(_get_node_global_pos(player)),
		"vel": _vec_to_dict(_get_velocity(player)),
		"hp": local_hp,
		"max_hp": int(max_stats.health) if max_stats != null else -1,
		"hit_protection": local_hit_protection,
		"dead": local_dead,
		"terminal": force_dead,
		"reason": reason,
		"client_time_msec": now
	}
	var steam = _get_steam_lobby_manager()
	if steam == null or not steam.has_method("send_battle_message_to_host"):
		return false
	var sent = false
	var count = max(1, repeat_count)
	for _i in range(count):
		if steam.send_battle_message_to_host(msg, true):
			sent = true
	if sent and local_dead and not _last_sent_player_dead_state:
		pass
	_last_sent_player_dead_state = local_dead
	return sent


func _snapshot_allows_birth_markers(snapshot: Dictionary) -> bool:
	var wave_state = snapshot.get("wave_timer_state", {})
	if typeof(wave_state) != TYPE_DICTIONARY or wave_state.empty():
		# Older packets did not include wave_timer_state. Keep accepting births for
		# backward compatibility instead of hiding all warnings.
		return true
	if bool(wave_state.get("running", false)):
		return true
	return float(wave_state.get("time_left", 0.0)) > 0.05


func _clear_birth_markers(reason: String) -> void:
	if _birth_markers.empty() and _birth_marker_states.empty():
		return
	for id_value in _birth_markers.keys():
		var marker = _birth_markers[id_value]
		if _is_valid_node(marker):
			marker.queue_free()
	_birth_markers.clear()
	_birth_marker_states.clear()


func _apply_reliable_birth_marker_state(birth_state: Dictionary, server_time_msec: int) -> void:
	if not ENABLE_BIRTH_MARKERS:
		return
	if typeof(birth_state) != TYPE_DICTIONARY or birth_state.empty():
		return
	var id = str(birth_state.get("net_id", ""))	
	if id == "":
		return
	var state_copy = birth_state.duplicate(true)
	state_copy["snapshot_server_time_msec"] = server_time_msec
	if str(state_copy.get("spawn_category", "")) == "":
		state_copy["spawn_category"] = _category_from_entity_type(int(state_copy.get("entity_type", -1)))
	if str(state_copy.get("spawn_sync_mode", "")) == "":
		state_copy["spawn_sync_mode"] = _get_entity_sync_mode(str(state_copy.get("spawn_category", "")), {})
	if str(state_copy.get("spawn_scene_path", "")) == "":
		state_copy["spawn_scene_path"] = str(state_copy.get("scene_path", ""))
	_birth_marker_states[id] = state_copy
	var marker = _get_or_create_birth_marker(id, state_copy)
	if _is_valid_node(marker):
		_sync_birth_marker_runtime(marker, state_copy)
		marker.set_meta("brotato_online_birth_state", state_copy)


func _spawn_entity_from_birth_marker_state(birth_id: String, birth_state: Dictionary) -> bool:
	if birth_id == "" or typeof(birth_state) != TYPE_DICTIONARY or birth_state.empty():
		return false
	var entity_net_id = str(birth_state.get("spawn_net_id", birth_state.get("entity_net_id", "")))
	if entity_net_id == "" or _spawned_from_birth_marker_entity_ids.has(entity_net_id):
		return false
	if _host_entities.has(entity_net_id) and _is_valid_node(_host_entities[entity_net_id]):
		_spawned_from_birth_marker_entity_ids[entity_net_id] = true
		return false
	var category = str(birth_state.get("spawn_category", ""))
	if category == "":
		category = _category_from_entity_type(int(birth_state.get("entity_type", -1)))
	if category == "":
		return false
	var scene_path = str(birth_state.get("spawn_scene_path", birth_state.get("scene_path", "")))
	if scene_path == "":
		return false
	var pos = birth_state.get("pos", {})
	var entity_state = {
		"net_id": entity_net_id,
		"category": category,
		"sync_mode": str(birth_state.get("spawn_sync_mode", _get_entity_sync_mode(category, {}))),
		"entity_type": int(birth_state.get("entity_type", -1)),
		"scene_path": scene_path,
		"data_path": str(birth_state.get("data_path", "")),
		"spawn_data": birth_state.get("spawn_data", {}),
		"player_index": int(birth_state.get("player_index", -1)),
		"pos": pos,
		"vel": {"x": 0.0, "y": 0.0},
		"dead": false,
		"health": -1,
		"max_health": -1,
		"speed": -1,
		"damage": -1,
		"armor": -1,
		"status_flags": {}
	}
	_spawned_from_birth_marker_entity_ids[entity_net_id] = true
	_apply_reliable_entity_birth_state(entity_state, int(birth_state.get("server_time_msec", OS.get_ticks_msec())), OS.get_ticks_msec())
	var spawned = _host_entities.has(entity_net_id)
	return spawned


func _get_or_create_birth_marker(id: String, birth_state: Dictionary) -> Node:
	if _birth_markers.has(id) and _is_valid_node(_birth_markers[id]):
		return _birth_markers[id]
	var marker = _spawn_birth_display_node(birth_state)
	if marker == null:
		marker = _make_birth_fallback_marker(birth_state)
	if marker == null:
		return null
	marker.name = _safe_node_name("BrotatoOnlineBirth_" + id)
	marker.set_meta("brotato_online_birth_marker", true)
	marker.set_meta("brotato_online_replica_birth", true)
	var parent = _get_births_parent()
	if parent == null:
		marker.queue_free()
		return null
	parent.add_child(marker)
	_configure_birth_display_node(marker, birth_state)
	_birth_markers[id] = marker
	return marker


func _spawn_birth_display_node(birth_state: Dictionary) -> Node:
	var packed = load("res://entities/birth/entity_birth.tscn")
	if packed == null or not (packed is PackedScene):
		return null
	var node = packed.instance()
	return node


func _load_packed_scene(scene_path: String) -> PackedScene:
	if scene_path == "":
		return null
	var packed = load(scene_path)
	if packed != null and packed is PackedScene:
		return packed
	return null

func _load_resource_from_path(path: String) -> Resource:
	if path == "":
		return null
	if not ResourceLoader.exists(path):
		return null
	var res = load(path)
	if res != null and res is Resource:
		return res
	return null


func _get_spawn_data_scene_path(data_res) -> String:
	if data_res == null or not (data_res is Object):
		return ""
	var scene = data_res.get("scene")
	if scene == null:
		return ""
	return str(scene.resource_path)


func _is_spawn_data_scene_mismatch(data_res, scene_path: String) -> bool:
	if data_res == null or scene_path == "":
		return false
	var data_scene_path = _get_spawn_data_scene_path(data_res)
	return data_scene_path != "" and data_scene_path != scene_path


func _make_birth_fallback_marker(birth_state: Dictionary) -> Node:
	var root = Node2D.new()
	var sprite = Sprite.new()
	var entity_type = int(birth_state.get("entity_type", -1))
	var texture_path = "res://entities/birth/entity_birth.png"
	# EntityType.STRUCTURE = 3, EntityType.PET = 5 in Brotato.
	if entity_type == 3 or entity_type == 5:
		texture_path = "res://entities/birth/structure_birth.png"
	var tex = load(texture_path)
	if tex != null:
		sprite.texture = tex
		sprite.scale = Vector2(0.33, 0.33)
	root.add_child(sprite)
	return root


func _configure_birth_display_node(node: Node, birth_state: Dictionary) -> void:
	if node == null:
		return
	var id = str(birth_state.get("net_id", ""))
	var entity_type = int(birth_state.get("entity_type", -1))
	var player_index = int(birth_state.get("player_index", -1))
	var pos = _dict_to_vec2(birth_state.get("pos", {}))
	var packed_scene = _load_packed_scene(str(birth_state.get("scene_path", "")))

	# Use Brotato's real EntityBirth visual timing/flicker instead of a GhostLayer
	# overlay. The Host also sends a reserved entity_net_id in the warning packet,
	# so the client can create the matching entity as soon as the marker expires.
	if node.has_signal("birth_timeout") and not node.is_connected("birth_timeout", self, "_on_replica_birth_marker_timeout"):
		node.connect("birth_timeout", self, "_on_replica_birth_marker_timeout", [id])
	if node.has_method("start") and packed_scene != null:
		node.call("start", entity_type, packed_scene, pos, null, player_index, null, -1)
	else:
		_set_node_global_pos(node, pos)
		if node.get("type") != null:
			node.set("type", entity_type)
		if node.get("player_index") != null:
			node.set("player_index", player_index)
		if node.get("scene") != null and packed_scene != null:
			node.set("scene", packed_scene)
		if node.has_method("set_color"):
			node.call("set_color")

	_disable_collision_tree(node)
	_sync_birth_marker_runtime(node, birth_state)
	node.set_process(true)
	node.set_physics_process(true)
	if node is CanvasItem:
		node.show()
	for child in node.get_children():
		if child is CanvasItem:
			child.show()


func _sync_birth_marker_runtime(marker: Node, birth_state: Dictionary) -> void:
	if not _is_valid_node(marker):
		return
	var pos = _dict_to_vec2(birth_state.get("pos", {}))
	_set_node_global_pos(marker, pos)
	var remaining_units = _predict_birth_remaining_units(birth_state)
	if marker.get("_current_time_before_spawn") != null:
		var current = float(marker.get("_current_time_before_spawn"))
		# EntityBirth also decrements locally. Only correct visible drift so it keeps
		# using the vanilla flicker rhythm instead of being hard-reset every frame.
		if abs(current - remaining_units) > 6.0:
			marker.set("_current_time_before_spawn", remaining_units)
	if marker is CanvasItem:
		marker.show()


func _predict_birth_remaining_units(birth_state: Dictionary) -> float:
	var host_now = _get_estimated_host_time_msec(OS.get_ticks_msec())
	var snapshot_time = int(birth_state.get("snapshot_server_time_msec", birth_state.get("server_time_msec", host_now)))
	var current_before_spawn = float(birth_state.get("current_time_before_spawn", birth_state.get("time_before_spawn", 60.0)))
	var elapsed_units = max(0.0, float(host_now - snapshot_time) * 0.06)
	return max(0.0, current_before_spawn - elapsed_units)


func _update_birth_markers() -> void:
	if not ENABLE_BIRTH_MARKERS or _birth_markers.empty():
		return
	var to_remove = []
	for id_value in _birth_markers.keys():
		var id = str(id_value)
		var marker = _birth_markers[id]
		if not _is_valid_node(marker):
			to_remove.append(id)
			continue
		var state = _birth_marker_states.get(id, {})
		if typeof(state) != TYPE_DICTIONARY:
			to_remove.append(id)
			continue
		if _predict_birth_remaining_units(state) <= 0.05:
			_spawn_entity_from_birth_marker_state(id, state)
			to_remove.append(id)
			continue
		_sync_birth_marker_runtime(marker, state)
	for id in to_remove:
		_remove_birth_marker(id)


func _on_replica_birth_marker_timeout(birth: Node, id: String) -> void:
	var state = _birth_marker_states.get(id, {})
	if typeof(state) == TYPE_DICTIONARY:
		_spawn_entity_from_birth_marker_state(id, state)
	_remove_birth_marker(id)

func _set_canvas_tree_alpha(node: Node, alpha: float) -> void:
	if node is CanvasItem:
		var c = node.self_modulate
		c.a = alpha
		node.self_modulate = c
	for child in node.get_children():
		if child is Node:
			_set_canvas_tree_alpha(child, alpha)


func _apply_host_wave_timer_state(snapshot: Dictionary) -> void:
	var state = snapshot.get("wave_timer_state", {})
	if typeof(state) != TYPE_DICTIONARY or state.empty():
		return
	_latest_wave_timer_state = state.duplicate(true)
	if not _latest_wave_timer_state.has("snapshot_server_time_msec"):
		_latest_wave_timer_state["snapshot_server_time_msec"] = _get_snapshot_server_time_msec(snapshot, OS.get_ticks_msec())
	# Do not force timer/HUD correction for every network snapshot. During combat
	# snapshots arrive ~10-12 times/sec; forcing timer.start()/label work on the
	# packet path was a frequent source of small frame spikes. _process() already
	# applies the cached timer state at WAVE_TIMER_SYNC_INTERVAL_MSEC. Force only
	# for the first packet or stopped/transition states.
	var running = bool(_latest_wave_timer_state.get("running", false))
	var force = _last_wave_timer_apply_msec <= 0 or not running
	_update_host_wave_timer_from_cached_state(force)
	_handle_host_battle_inactive_state(_latest_wave_timer_state)


func _handle_host_battle_inactive_state(state: Dictionary) -> void:
	if typeof(state) != TYPE_DICTIONARY or state.empty() or _is_game_host() or not _is_in_game_scene():
		return
	var wave = int(state.get("wave", -1))
	var local_wave = _get_local_run_wave()
	if wave >= 0 and local_wave >= 0 and wave != local_wave:
		return
	var time_left = float(state.get("time_left", -1.0))
	# Do not treat running=false + positive time_left as wave end. This happens during
	# retry reload / timer startup and previously nudged the local timer to timeout,
	# making the client enter CoopShop as if the retried wave was won.
	if bool(state.get("running", false)) or time_left > 0.05:
		return
	# A stopped/0s Host timer is only allowed to end the local wave after this client has
	# already accepted a clearly active snapshot for the current battle.  This blocks the
	# wave-1 stale/pre-start 0s snapshot that caused instant victory.
	if not _snapshot_gate_seen_running_wave:
		return
	var now = OS.get_ticks_msec()
	if now - _last_host_battle_inactive_cleanup_msec < 250:
		return
	_last_host_battle_inactive_cleanup_msec = now
	_neutralize_client_combat_threats("host_battle_inactive")
	_nudge_local_wave_timeout_from_host()


func _nudge_local_wave_timeout_from_host() -> void:
	var main = get_tree().current_scene
	if main == null:
		return
	if bool(main.get("_cleaning_up")):
		return
	if main.has_meta("brotato_online_host_wave_timeout_forced") and bool(main.get_meta("brotato_online_host_wave_timeout_forced")):
		return
	var timer = _get_wave_timer()
	# The Host has already ended the wave. Trigger the vanilla client cleanup path
	# almost immediately instead of waiting for local timer drift to catch up.
	# Some late-wave clients already have a stopped local Timer, so starting it is not
	# enough; fall back to the vanilla timeout handler directly.
	if timer != null and not timer.is_stopped():
		main.set_meta("brotato_online_host_wave_timeout_forced", true)
		timer.start(0.05)
		return
	if main.has_method("_on_WaveTimer_timeout"):
		main.set_meta("brotato_online_host_wave_timeout_forced", true)
		main.call_deferred("_on_WaveTimer_timeout")


func _update_host_wave_timer_from_cached_state(force: bool) -> void:
	if _latest_wave_timer_state.empty() or not _is_in_game_scene() or _is_game_host():
		return
	var now = OS.get_ticks_msec()
	if not force and now - _last_wave_timer_apply_msec < WAVE_TIMER_SYNC_INTERVAL_MSEC:
		return
	_last_wave_timer_apply_msec = now
	var predicted_left = _predict_host_wave_time_left(_latest_wave_timer_state)
	if predicted_left < 0.0:
		return
	_set_host_wave_timer_label(predicted_left, _latest_wave_timer_state)
	_correct_local_wave_timer(predicted_left, _latest_wave_timer_state)
	_sync_client_bullet_hell_phase(predicted_left, _latest_wave_timer_state)


func _predict_host_wave_time_left(state: Dictionary) -> float:
	var time_left = float(state.get("time_left", -1.0))
	if time_left < 0.0:
		return -1.0
	var running = bool(state.get("running", false))
	var snapshot_time = int(state.get("snapshot_server_time_msec", state.get("server_time_msec", 0)))
	if running and snapshot_time > 0:
		var host_now = _get_estimated_host_time_msec(OS.get_ticks_msec())
		time_left -= max(0.0, float(host_now - snapshot_time) / 1000.0)
	return max(0.0, time_left)


func _set_host_wave_timer_label(time_left: float, state: Dictionary) -> void:
	var label = _get_wave_timer_label()
	if label == null:
		return
	# Detach the vanilla label process from the local Timer on Client; otherwise it
	# overwrites the Host-synced value every frame.
	if label.get("wave_timer") != null:
		label.set("wave_timer", null)
	label.text = str(int(ceil(max(0.0, time_left))))


func _correct_local_wave_timer(time_left: float, state: Dictionary) -> void:
	var timer = _get_wave_timer()
	if timer == null:
		return
	var running = bool(state.get("running", false))
	if not running:
		return
	var local_left = float(timer.time_left)
	var drift = abs(local_left - time_left)
	if timer.is_stopped() or drift >= WAVE_TIMER_DRIFT_CORRECTION_SEC:
		# Keep the original Main._on_WaveTimer_timeout path alive, but correct major
		# drift to Host time. The HUD label above is fully Host-driven.
		var corrected = max(0.05, time_left)
		timer.start(corrected)


func _sync_client_bullet_hell_phase(time_left: float, state: Dictionary) -> void:
	if _is_game_host() or not _is_in_game_scene():
		return
	if typeof(state) != TYPE_DICTIONARY or state.empty():
		return
	var running = bool(state.get("running", false))
	if not running:
		return
	var wait_time = float(state.get("wait_time", 0.0))
	if wait_time <= 0.0:
		var timer = _get_wave_timer()
		if timer != null:
			wait_time = float(timer.wait_time)
	if wait_time <= 0.0 or time_left < 0.0:
		return
	var now = OS.get_ticks_msec()
	if now - _last_bullet_hell_phase_sync_msec < BULLET_HELL_PHASE_SYNC_INTERVAL_MSEC:
		return
	_last_bullet_hell_phase_sync_msec = now

	var main = _get_current_main_node()
	if not _is_valid_node(main):
		return
	var enemy_projectiles = _safe_node_get(main, "_enemy_projectiles", null)
	if not _is_valid_node(enemy_projectiles):
		enemy_projectiles = main.get_node_or_null("EnemyProjectiles")
	if not _is_valid_node(enemy_projectiles):
		return

	var bullet_hell_nodes = _get_local_bullet_hell_nodes(enemy_projectiles)
	if bullet_hell_nodes.empty():
		return

	var wave = int(state.get("wave", RunData.current_wave))
	var scene_id = int(_last_game_scene_instance_id)
	var key = str(scene_id) + ":" + str(wave)
	var should_clear = BULLET_HELL_CLEAR_LOCAL_PROJECTILES_ON_FIRST_SYNC and _bullet_hell_phase_cleared_key != key
	var elapsed = clamp(wait_time - time_left, 0.0, wait_time)
	for bullet_hell in bullet_hell_nodes:
		if should_clear:
			_remove_local_bullet_hell_projectiles(enemy_projectiles, bullet_hell)
		_sync_bullet_hell_node_phase(bullet_hell, elapsed)
	if should_clear:
		_bullet_hell_phase_cleared_key = key


func _get_local_bullet_hell_nodes(enemy_projectiles: Node) -> Array:
	var result = []
	if not _is_valid_node(enemy_projectiles):
		return result
	for child in enemy_projectiles.get_children():
		if not _is_valid_node(child):
			continue
		if child.has_method("_update_bullet_hell_parameters"):
			result.append(child)
			continue
		var scene_path = str(child.filename)
		if scene_path.find("projectiles/bullet_hells/") != -1 or scene_path.find("BulletHell") != -1:
			result.append(child)
	return result


func _sync_bullet_hell_node_phase(node: Node, elapsed: float) -> void:
	if not _is_valid_node(node):
		return
	for child in node.get_children():
		if not _is_valid_node(child):
			continue
		_sync_bullet_hell_node_phase(child, elapsed)
		var tick_value = child.get("tick_progression")
		if tick_value == null:
			continue
		var bullet_hell = child.get("bullet_hell")
		var generator = child.get("generator")
		if bullet_hell == null or generator == null:
			continue
		if not is_instance_valid(bullet_hell) or not is_instance_valid(generator):
			continue
		var spawn_rate = float(_safe_node_get(bullet_hell, "spawn_rate", 0.0))
		var spawn_rate_factor = float(_safe_node_get(generator, "spawn_rate_factor", 1.0))
		var period = spawn_rate * spawn_rate_factor
		if period <= 0.01:
			continue
		var base = period * float(_safe_node_get(child, "start_cool_down", 0.0))
		var desired = base + elapsed
		desired = desired - floor(desired / period) * period
		if desired < 0.0:
			desired += period
		var current = float(tick_value)
		var drift = abs(current - desired)
		drift = min(drift, abs(period - drift))
		if drift >= BULLET_HELL_PHASE_DRIFT_CORRECTION_SEC:
			child.set("tick_progression", desired)


func _remove_local_bullet_hell_projectiles(enemy_projectiles: Node, bullet_hell: Node) -> void:
	if not _is_valid_node(enemy_projectiles) or not _is_valid_node(bullet_hell):
		return
	for child in enemy_projectiles.get_children():
		if not _is_valid_node(child) or child == bullet_hell:
			continue
		var hitbox = child.get("_hitbox")
		if hitbox != null and is_instance_valid(hitbox):
			var from_node = hitbox.get("from")
			if from_node == bullet_hell:
				child.queue_free()


func _apply_pickups(snapshot: Dictionary) -> void:
	# Host no longer synchronizes pickup entities. Remove any markers left from older packets
	# and let the local game scene spawn/pick up fruit/material visuals normally.
	if not _pickup_markers.empty():
		for id_value in _pickup_markers.keys():
			var marker = _pickup_markers[id_value]
			if _is_valid_node(marker):
				marker.queue_free()
		_pickup_markers.clear()
		_pickup_targets.clear()
		_pickup_claimed.clear()
	return

func _apply_host_economy_state(snapshot: Dictionary) -> void:
	var economy = snapshot.get("economy_state", {})
	if typeof(economy) != TYPE_DICTIONARY:
		return
	if economy.empty():
		return
	var wave_state = snapshot.get("wave_timer_state", {})
	if typeof(wave_state) == TYPE_DICTIONARY and bool(wave_state.get("running", false)):
		var now = OS.get_ticks_msec()
		if now - _last_economy_apply_msec < 180:
			return
		_last_economy_apply_msec = now
	var players = economy.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return
	for state in players:
		if typeof(state) == TYPE_DICTIONARY:
			_apply_host_economy_player_state(state)


func _apply_host_economy_player_state(state: Dictionary) -> void:
	var player_index = int(state.get("player_index", -1))
	if player_index < 0:
		return
	var players_data = RunData.get("players_data")
	if typeof(players_data) != TYPE_ARRAY or player_index >= players_data.size():
		return
	var player_data = players_data[player_index]
	if player_data == null:
		return
	var gold = int(state.get("gold", state.get("materials", player_data.gold)))
	var xp = float(state.get("xp", player_data.current_xp))
	var level = int(state.get("level", player_data.current_level))
	var old_gold = int(player_data.gold)
	var old_xp = float(player_data.current_xp)
	var old_level = int(player_data.current_level)
	var changed_gold = old_gold != gold
	var changed_xp = old_xp != xp
	var changed_level = old_level != level
	player_data.gold = gold
	_apply_host_level_state(player_index, player_data, old_level, level)
	player_data.current_xp = xp
	var hp = int(state.get("hp", -1))
	var max_hp = int(state.get("max_hp", -1))
	# Economy snapshots may arrive after battle end or around death timing. HP<=0 is
	# sufficient to mark a remote player as dead even if the separate dead flag lags.
	_apply_host_hp_state_to_player(player_index, hp, max_hp)
	_update_hud_from_host_economy(player_index, state)
	if changed_gold:
		RunData.emit_signal("gold_changed", gold, player_index)
	if changed_xp or changed_level:
		var next_xp = float(state.get("next_level_xp", 0.0))
		if next_xp <= 0.0 and RunData.has_method("get_next_level_xp_needed"):
			next_xp = float(RunData.get_next_level_xp_needed(player_index))
		RunData.emit_signal("xp_added", xp, next_xp, player_index)


func _apply_host_level_state(player_index: int, player_data, old_level: int, host_level: int) -> void:
	if host_level == old_level:
		return
	if player_index == _get_owned_player_index():
		# The local client owns its character runtime stats. Sync the numeric level only;
		# do not emit levelled_up here or max-health/stat side effects run again.
		player_data.current_level = host_level
		return
	if host_level < old_level:
		# Host is authoritative. This can happen if the client produced a local-only
		# economy/XP side effect before the next snapshot corrected it.
		player_data.current_level = host_level
		return

	# Brotato's level-up flow is signal-driven. Main.on_levelled_up creates the
	# pending upgrade entry, refreshes level UI, and applies level-up stat effects.
	for next_level in range(old_level + 1, host_level + 1):
		player_data.current_level = next_level
		if RunData.has_signal("levelled_up"):
			RunData.emit_signal("levelled_up", player_index)


func _apply_host_progression_state(snapshot: Dictionary) -> void:
	var state = snapshot.get("progression_state", {})
	if typeof(state) != TYPE_DICTIONARY or state.empty():
		return
	var wave_state = snapshot.get("wave_timer_state", {})
	var wave_running = typeof(wave_state) == TYPE_DICTIONARY and bool(wave_state.get("running", false))
	var players = state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return
	var main = null
	var locator = _get_runtime_locator()
	if locator != null and locator.has_method("get_main"):
		main = locator.get_main()
	if main == null:
		main = get_tree().current_scene
	if main == null:
		return
	# Upgrade and item-box queues are Host-authoritative even while combat is running.
	# Do not apply visible upgrade/card UI during the wave; only mirror the pending
	# queue counters/data so local client drops cannot permanently diverge.
	_sync_host_pending_progression_queues(main, players)
	if wave_running:
		return
	var ui = main.get("_coop_upgrades_ui") if RunData != null and bool(RunData.get("is_coop_run")) else main.get("_upgrades_ui")
	if not _is_valid_node(ui):
		return
	for player_state in players:
		if typeof(player_state) != TYPE_DICTIONARY:
			continue
		_apply_host_progression_player_state(ui, player_state)


func _sync_host_pending_progression_queues(main: Node, players: Array) -> void:
	var upgrades_all = main.get("_upgrades_to_process")
	var consumables_all = main.get("_consumables_to_process")
	for player_state in players:
		if typeof(player_state) != TYPE_DICTIONARY:
			continue
		var player_index = int(player_state.get("player_index", -1))
		if player_index < 0:
			continue

		# Combat snapshots are intentionally count-only. Keep local process queues intact
		# and repair only the small HUD lists when their displayed counters diverge.
		if player_state.has("pending_upgrade_count") and not player_state.has("pending_upgrades"):
			_sync_things_to_process_hud_counts(
				main,
				player_index,
				int(player_state.get("pending_upgrade_count", 0)),
				int(player_state.get("pending_item_box_count", 0)),
				int(player_state.get("pending_legendary_item_box_count", 0)),
				int(player_state.get("pending_other_consumable_count", 0))
			)
			continue

		if typeof(upgrades_all) != TYPE_ARRAY or typeof(consumables_all) != TYPE_ARRAY:
			continue
		if player_index >= upgrades_all.size() or player_index >= consumables_all.size():
			continue
		var pending_upgrades = player_state.get("pending_upgrades", [])
		var pending_consumables = player_state.get("pending_consumables", [])
		if typeof(pending_upgrades) != TYPE_ARRAY or typeof(pending_consumables) != TYPE_ARRAY:
			continue
		var queue_key = str(player_index) + ":" + to_json(pending_upgrades) + ":" + to_json(pending_consumables)
		if str(_last_progression_queue_key_by_player.get(player_index, "")) == queue_key:
			continue
		var new_upgrades = []
		for upgrade_state in pending_upgrades:
			if typeof(upgrade_state) != TYPE_DICTIONARY:
				continue
			var upgrade_to_process = UpgradesUI.UpgradeToProcess.new()
			upgrade_to_process.level = int(upgrade_state.get("level", 0))
			upgrade_to_process.player_index = int(upgrade_state.get("player_index", player_index))
			new_upgrades.append(upgrade_to_process)
		var new_consumables = []
		for consumable_state in pending_consumables:
			if typeof(consumable_state) != TYPE_DICTIONARY:
				continue
			var data_state = consumable_state.get("consumable_data", {})
			if typeof(data_state) != TYPE_DICTIONARY:
				data_state = {}
			var consumable_kind = str(consumable_state.get("consumable_kind", data_state.get("consumable_kind", "")))
			var consumable_data = _resolve_item_parent_data(data_state)
			if consumable_data == null:
				consumable_data = _resolve_consumable_data_by_kind(consumable_kind)
			if consumable_data == null:
				continue
			var consumable_to_process = UpgradesUI.ConsumableToProcess.new()
			consumable_to_process.consumable_data = consumable_data
			consumable_to_process.player_index = int(consumable_state.get("player_index", player_index))
			new_consumables.append(consumable_to_process)
		upgrades_all[player_index] = new_upgrades
		consumables_all[player_index] = new_consumables
		_last_progression_queue_key_by_player[player_index] = queue_key
		_sync_things_to_process_hud(main, player_index, new_upgrades, new_consumables)
	if typeof(upgrades_all) == TYPE_ARRAY:
		main.set("_upgrades_to_process", upgrades_all)
	if typeof(consumables_all) == TYPE_ARRAY:
		main.set("_consumables_to_process", consumables_all)


func _sync_things_to_process_hud_counts(main: Node, player_index: int, upgrade_count: int, item_box_count: int, legendary_item_box_count: int, other_consumable_count: int = 0) -> void:
	var containers = main.get("_things_to_process_player_containers")
	if typeof(containers) != TYPE_ARRAY or player_index < 0 or player_index >= containers.size():
		return
	var holder = containers[player_index]
	if not _is_valid_node(holder):
		return
	var upgrade_list = holder.get("upgrades")
	if _is_valid_node(upgrade_list):
		var current_upgrade_count = _get_ui_item_list_count(upgrade_list)
		if current_upgrade_count != max(0, upgrade_count):
			_rebuild_upgrade_marker_count(upgrade_list, max(0, upgrade_count))
	var consumable_list = holder.get("consumables")
	if _is_valid_node(consumable_list):
		var desired = {
			"item_box": max(0, item_box_count + other_consumable_count),
			"legendary_item_box": max(0, legendary_item_box_count)
		}
		var current = _get_consumable_marker_counts(consumable_list)
		if int(current.get("item_box", 0)) != int(desired.get("item_box", 0)) or int(current.get("legendary_item_box", 0)) != int(desired.get("legendary_item_box", 0)):
			_rebuild_consumable_marker_counts(consumable_list, int(desired.get("item_box", 0)), int(desired.get("legendary_item_box", 0)))


func _rebuild_upgrade_marker_count(upgrade_list: Node, desired_count: int) -> void:
	_clear_ui_item_list(upgrade_list)
	if not _is_valid_node(upgrade_list) or desired_count <= 0:
		return
	var icon = ItemService.get_icon(Keys.icon_upgrade_to_process_hash)
	for _i in range(desired_count):
		if upgrade_list.has_method("add_element"):
			# Combat count sync deliberately does not serialize per-upgrade levels.
			# The icon/count is what matters; wave-end full state restores exact levels.
			upgrade_list.add_element(icon, 0)


func _rebuild_consumable_marker_counts(consumable_list: Node, item_box_count: int, legendary_item_box_count: int) -> void:
	_clear_ui_item_list(consumable_list)
	if not _is_valid_node(consumable_list):
		return
	var item_box_data = _resolve_consumable_data_by_kind("item_box")
	var legendary_data = _resolve_consumable_data_by_kind("legendary_item_box")
	if item_box_data != null:
		for _i in range(max(0, item_box_count)):
			if consumable_list.has_method("add_element"):
				consumable_list.add_element(item_box_data)
	if legendary_data != null:
		for _i in range(max(0, legendary_item_box_count)):
			if consumable_list.has_method("add_element"):
				consumable_list.add_element(legendary_data)


func _get_ui_item_list_count(list_node: Node) -> int:
	if not _is_valid_node(list_node):
		return 0
	var elements = list_node.get("_elements")
	if typeof(elements) == TYPE_ARRAY:
		return elements.size()
	return list_node.get_child_count()


func _get_consumable_marker_counts(list_node: Node) -> Dictionary:
	var counts = {"item_box": 0, "legendary_item_box": 0}
	if not _is_valid_node(list_node):
		return counts
	var elements = list_node.get("_elements")
	if typeof(elements) == TYPE_ARRAY:
		for item_data in elements:
			var kind = _get_consumable_marker_kind(item_data)
			if kind == "legendary_item_box":
				counts["legendary_item_box"] = int(counts["legendary_item_box"]) + 1
			else:
				counts["item_box"] = int(counts["item_box"]) + 1
		return counts
	for child in list_node.get_children():
		var item_data = child.get("item_data") if child != null else null
		var kind = _get_consumable_marker_kind(item_data)
		if kind == "legendary_item_box":
			counts["legendary_item_box"] = int(counts["legendary_item_box"]) + 1
		else:
			counts["item_box"] = int(counts["item_box"]) + 1
	return counts


func _get_consumable_marker_kind(item_data) -> String:
	if item_data == null:
		return "item_box"
	var id_hash = int(item_data.get("my_id_hash")) if item_data.get("my_id_hash") != null else 0
	var my_id = str(item_data.get("my_id")) if item_data.get("my_id") != null else ""
	if id_hash == int(Keys.consumable_legendary_item_box_hash) or my_id == "consumable_legendary_item_box":
		return "legendary_item_box"
	return "item_box"


func _sync_things_to_process_hud(main: Node, player_index: int, upgrades: Array, consumables: Array) -> void:
	var containers = main.get("_things_to_process_player_containers")
	if typeof(containers) != TYPE_ARRAY or player_index < 0 or player_index >= containers.size():
		return
	var holder = containers[player_index]
	if not _is_valid_node(holder):
		return
	var upgrade_list = holder.get("upgrades")
	if _is_valid_node(upgrade_list):
		_clear_ui_item_list(upgrade_list)
		for upgrade_to_process in upgrades:
			if upgrade_list.has_method("add_element"):
				upgrade_list.add_element(ItemService.get_icon(Keys.icon_upgrade_to_process_hash), int(upgrade_to_process.level))
	var consumable_list = holder.get("consumables")
	if _is_valid_node(consumable_list):
		_clear_ui_item_list(consumable_list)
		for consumable_to_process in consumables:
			if consumable_list.has_method("add_element") and consumable_to_process.consumable_data != null:
				consumable_list.add_element(consumable_to_process.consumable_data)


func _clear_ui_item_list(list_node: Node) -> void:
	if list_node.get("_elements") != null:
		list_node.set("_elements", [])
	for child in list_node.get_children():
		if child is Node:
			list_node.remove_child(child)
			child.queue_free()


func _apply_host_progression_player_state(ui: Node, player_state: Dictionary) -> void:
	var player_index = int(player_state.get("player_index", -1))
	if player_index < 0:
		return
	var visible = player_state.get("visible_option", {})
	if typeof(visible) != TYPE_DICTIONARY:
		return
	var mode = str(visible.get("mode", "none"))
	if mode != "upgrade" and mode != "item_box":
		return
	var key = str(player_index) + ":" + to_json(visible)
	if str(_last_progression_apply_key_by_player.get(player_index, "")) == key:
		return
	var container = null
	if ui.has_method("_get_player_container"):
		container = ui._get_player_container(player_index)
	if not _is_valid_node(container):
		return
	_prepare_host_progression_ui(ui, container, player_index, visible)
	if mode == "upgrade":
		if _apply_host_upgrade_options_to_container(container, player_index, visible):
			_last_progression_apply_key_by_player[player_index] = key
	elif mode == "item_box":
		if _apply_host_item_box_option_to_container(container, player_index, visible):
			_last_progression_apply_key_by_player[player_index] = key


func _prepare_host_progression_ui(ui: Node, container: Node, player_index: int, visible: Dictionary) -> void:
	if ui is CanvasItem:
		ui.show()
	var choosing = ui.get("_player_is_choosing")
	if typeof(choosing) == TYPE_ARRAY and player_index >= 0 and player_index < choosing.size():
		choosing[player_index] = true
		ui.set("_player_is_choosing", choosing)
	var showing = ui.get("_showing_option")
	if typeof(showing) == TYPE_ARRAY and player_index >= 0 and player_index < showing.size():
		var mode = str(visible.get("mode", "none"))
		if mode == "upgrade":
			var upgrade_to_process = UpgradesUI.UpgradeToProcess.new()
			upgrade_to_process.level = int(visible.get("level", 0))
			upgrade_to_process.player_index = player_index
			showing[player_index] = upgrade_to_process
		elif mode == "item_box":
			var consumable_to_process = UpgradesUI.ConsumableToProcess.new()
			consumable_to_process.player_index = player_index
			var consumable_state = visible.get("consumable_data", {})
			if typeof(consumable_state) == TYPE_DICTIONARY:
				var consumable_data = _resolve_item_parent_data(consumable_state)
				if consumable_data != null:
					consumable_to_process.consumable_data = consumable_data
			showing[player_index] = consumable_to_process
		ui.set("_showing_option", showing)
	if container.has_method("focus"):
		container.call_deferred("focus")


func _apply_host_upgrade_options_to_container(container: Node, player_index: int, visible: Dictionary) -> bool:
	var upgrade_states = visible.get("upgrades", [])
	if typeof(upgrade_states) != TYPE_ARRAY:
		return false
	var upgrades = []
	for upgrade_state in upgrade_states:
		if typeof(upgrade_state) != TYPE_DICTIONARY:
			continue
		var upgrade_data = _resolve_item_parent_data(upgrade_state)
		if upgrade_data != null:
			upgrades.append(upgrade_data)
	if upgrades.empty():
		return false
	if container.get("_level") != null:
		container.set("_level", int(visible.get("level", container.get("_level"))))
	if container.get("_reroll_price") != null:
		container.set("_reroll_price", int(visible.get("reroll_price", container.get("_reroll_price"))))
	if container.get("_reroll_count") != null:
		container.set("_reroll_count", int(visible.get("reroll_count", container.get("_reroll_count"))))
	if container.get("_reroll_discount") != null:
		container.set("_reroll_discount", int(visible.get("reroll_discount", container.get("_reroll_discount"))))
	if container.get("_old_upgrades") != null:
		container.set("_old_upgrades", upgrades.duplicate())
	var upgrade_uis = []
	if container.has_method("_get_upgrade_uis"):
		upgrade_uis = container._get_upgrade_uis()
	for i in range(upgrade_uis.size()):
		var upgrade_ui = upgrade_uis[i]
		if not _is_valid_node(upgrade_ui):
			continue
		if upgrade_ui is CanvasItem:
			upgrade_ui.visible = i < upgrades.size()
		if i < upgrades.size() and upgrade_ui.has_method("set_upgrade"):
			upgrade_ui.set_upgrade(upgrades[i], player_index)
	var reroll_button = container.get("_reroll_button")
	if _is_valid_node(reroll_button) and reroll_button.has_method("init"):
		reroll_button.init(int(visible.get("reroll_price", 0)), player_index)
		if reroll_button is CanvasItem:
			reroll_button.visible = upgrades.size() > 1
	var items_container = container.get("_items_container")
	if items_container is CanvasItem:
		items_container.hide()
	var upgrades_container = container.get("_upgrades_container")
	if upgrades_container is CanvasItem:
		upgrades_container.show()
	if container.has_method("_update_gold_label"):
		container._update_gold_label()
	return true


func _apply_host_item_box_option_to_container(container: Node, player_index: int, visible: Dictionary) -> bool:
	var item_state = visible.get("item_data", {})
	if typeof(item_state) != TYPE_DICTIONARY:
		return false
	var item_data = _resolve_item_parent_data(item_state)
	if item_data == null:
		return false
	var consumable_state = visible.get("consumable_data", {})
	if typeof(consumable_state) == TYPE_DICTIONARY:
		var consumable_data = _resolve_item_parent_data(consumable_state)
		if consumable_data != null and container.get("_consumable_data") != null:
			container.set("_consumable_data", consumable_data)
	if container.has_method("show_item"):
		container.show_item(item_data)
	else:
		if container.get("_item_data") != null:
			container.set("_item_data", item_data)
	return true


func _resolve_consumable_data_by_kind(consumable_kind: String):
	match consumable_kind:
		"legendary_item_box":
			return ItemService.get_element(ItemService.consumables, int(Keys.consumable_legendary_item_box_hash))
		"item_box":
			return ItemService.get_element(ItemService.consumables, int(Keys.consumable_item_box_hash))
		_:
			return null


func _resolve_item_parent_data(state: Dictionary):
	if typeof(state) != TYPE_DICTIONARY or state.empty():
		return null
	var resource_path = str(state.get("resource_path", state.get("data_path", "")))
	if resource_path != "":
		var loaded = load(resource_path)
		if loaded != null:
			return _duplicate_with_host_value_if_needed(loaded, state)
	var data_type = str(state.get("type", ""))
	var id_hash = int(state.get("my_id_hash", state.get("data_id_hash", 0)))
	if data_type == "upgrade":
		var upgrade_hash = int(state.get("upgrade_id_hash", id_hash))
		var upgrade_data = ItemService.get_element(ItemService.upgrades, upgrade_hash)
		if upgrade_data == null and id_hash != 0:
			upgrade_data = ItemService.get_element(ItemService.upgrades, id_hash)
		return _duplicate_with_host_value_if_needed(upgrade_data, state)
	if data_type == "weapon":
		var weapon_data = ItemService.get_element(ItemService.weapons, id_hash)
		if weapon_data == null:
			var weapon_id_hash = int(state.get("weapon_id_hash", 0))
			if weapon_id_hash != 0 and ItemService.has_method("get_weapon_from_weapon_id"):
				weapon_data = ItemService.get_weapon_from_weapon_id(weapon_id_hash)
		return _duplicate_with_host_value_if_needed(weapon_data, state)
	if data_type == "consumable":
		var consumable_data = ItemService.get_element(ItemService.consumables, id_hash)
		return _duplicate_with_host_value_if_needed(consumable_data, state)
	var item_data = null
	if id_hash != 0:
		item_data = ItemService.get_element(ItemService.items, id_hash)
	return _duplicate_with_host_value_if_needed(item_data, state)


func _duplicate_with_host_value_if_needed(data, state: Dictionary):
	if data == null:
		return null
	var serialized_data = state.get("serialized_data", {})
	var has_serialized_data = typeof(serialized_data) == TYPE_DICTIONARY and not serialized_data.empty()
	var needs_copy = has_serialized_data or state.has("value") or state.has("is_cursed") or state.has("curse_factor")
	if not needs_copy:
		return data
	var copy = data.duplicate()
	if has_serialized_data and copy.has_method("deserialize_and_merge"):
		copy.deserialize_and_merge(serialized_data)
	else:
		if state.has("value"):
			copy.set("value", int(state.get("value", data.get("value"))))
	# Some vanilla deserialize_and_merge() implementations do not restore DLC curse
	# fields, so apply Host's explicit runtime fields after deserialization too.
	if state.has("value") and copy.get("value") != null:
		copy.set("value", int(state.get("value", copy.get("value"))))
	if state.has("is_cursed") and copy.get("is_cursed") != null:
		copy.set("is_cursed", bool(state.get("is_cursed", copy.get("is_cursed"))))
	if state.has("curse_factor") and copy.get("curse_factor") != null:
		copy.set("curse_factor", float(state.get("curse_factor", copy.get("curse_factor"))))
	return copy


func _apply_host_hp_state_to_player(player_index: int, hp: int, max_hp: int) -> void:
	if hp < 0 and max_hp < 0:
		return
	var locator = _get_runtime_locator()
	if locator == null or not locator.has_method("get_players"):
		return
	var players = locator.get_players()
	if typeof(players) != TYPE_ARRAY or player_index >= players.size():
		return
	var player = players[player_index]
	if not _is_valid_node(player):
		return
	var is_owned = player_index == _get_owned_player_index()
	if is_owned:
		_apply_owned_player_authoritative_max_hp(player, max_hp)
		return
	var current_stats = player.get("current_stats")
	var max_stats = player.get("max_stats")
	if max_stats != null and max_hp >= 0:
		max_stats.health = max_hp
	if current_stats != null and hp != -1:
		current_stats.health = hp
	if ENABLE_PLAYER_DEATH_SYNC:
		if hp != -1 and hp <= 0:
			_apply_remote_dead_display_to_player(player, true)
		elif hp > 0:
			_apply_remote_dead_display_to_player(player, false)


func _apply_owned_player_authoritative_max_hp(player: Node, max_hp: int) -> void:
	if not _is_valid_node(player) or max_hp < 0:
		return
	var max_stats = player.get("max_stats")
	if max_stats == null:
		return
	var current_stats = player.get("current_stats")
	var old_max_hp = int(max_stats.health)
	if old_max_hp == max_hp:
		return
	max_stats.health = max_hp
	if current_stats != null:
		if max_hp > old_max_hp and old_max_hp >= 0:
			# Match Brotato's update_player_stats(false): max-HP gains also raise current HP by the delta.
			current_stats.health = int(current_stats.health) + (max_hp - old_max_hp)
		elif max_hp > 0 and int(current_stats.health) > max_hp:
			current_stats.health = max_hp
	if player.has_signal("health_updated"):
		var hp_value = int(current_stats.health) if current_stats != null else max_hp
		player.emit_signal("health_updated", player, hp_value, max_hp)


func _update_hud_from_host_economy(player_index: int, state: Dictionary) -> void:
	var main = get_tree().current_scene
	if main == null:
		return
	var players_ui = main.get("_players_ui")
	if typeof(players_ui) != TYPE_ARRAY or player_index >= players_ui.size():
		return
	var ui = players_ui[player_index]
	if ui == null:
		return
	var gold = int(state.get("gold", state.get("materials", 0)))
	var xp = int(float(state.get("xp", 0.0)))
	var next_xp = int(ceil(float(state.get("next_level_xp", 0.0))))
	if next_xp <= 0 and RunData.has_method("get_next_level_xp_needed"):
		next_xp = int(ceil(float(RunData.get_next_level_xp_needed(player_index))))
	if ui.gold != null:
		ui.gold.update_value(gold)
	if ui.xp_bar != null and next_xp > 0:
		ui.xp_bar.update_value(xp % next_xp, next_xp)
	if ui.level_label != null:
		ui.update_level_label()
	if player_index == _get_owned_player_index():
		return
	var hp = int(state.get("hp", -1))
	var max_hp = int(state.get("max_hp", -1))
	if hp >= 0 and max_hp > 0:
		if ui.life_bar != null:
			ui.life_bar.update_value(hp, max_hp)
		if ui.life_label != null:
			ui.life_label.text = str(max(hp, 0)) + " / " + str(max_hp)

func _process_battle_events(snapshot: Dictionary, server_time_msec: int, now: int) -> void:
	var events = snapshot.get("events", [])
	if typeof(events) != TYPE_ARRAY or events.empty():
		return
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var event_type = str(event.get("event_type", ""))
		var event_id = int(event.get("event_id", 0))
		var event_key = event_type + ":" + str(event_id)
		if event_id > 0:
			if _seen_battle_event_ids.has(event_key):
				continue
			_seen_battle_event_ids[event_key] = true
		if event_type == "death_event":
			if not ENABLE_DEATH_SYNC:
				continue
			var net_id = str(event.get("target_net_id", event.get("net_id", "")))
			if net_id == "":
				continue
			var category = str(event.get("category", _host_entity_category.get(net_id, "")))
			var pos = _dict_to_vec2(event.get("pos", {}))
			var event_server_time = int(event.get("server_time_msec", server_time_msec))
			var elapsed = max(0, server_time_msec - event_server_time)
			var delay = max(0, DEATH_VISUAL_DELAY_MSEC - elapsed)
			_schedule_remote_death(net_id, category, pos, now + delay, "death_event")
	_prune_seen_battle_events()


func _prune_seen_battle_events() -> void:
	if _seen_battle_event_ids.size() <= DEATH_EVENT_SEEN_KEEP:
		return
	# Dictionary order is insertion order in Godot 3.x, so this keeps recent events.
	var keys = _seen_battle_event_ids.keys()
	var remove_count = max(0, keys.size() - DEATH_EVENT_SEEN_KEEP)
	for i in range(remove_count):
		_seen_battle_event_ids.erase(keys[i])


func _handle_host_removed_entity(id: String, now: int, source: String) -> void:
	if id == "":
		return
	if not ENABLE_DEATH_SYNC:
		_remove_host_entity(id, true)
		_locally_killed_until.erase(id)
		_sent_kill_claim_ids.erase(id)
		return
	if _locally_killed_until.has(id):
		_remove_host_entity(id, true)
		_locally_killed_until.erase(id)
		_sent_kill_claim_ids.erase(id)
		return
	_schedule_or_remove_remote_death(id, source, now)


func _schedule_or_remove_remote_death(id: String, source: String, now: int) -> void:
	var category = str(_host_entity_category.get(id, ""))
	if _is_combat_death_category(category) and _host_entities.has(id):
		var pos = _get_node_global_pos(_host_entities[id]) if _is_valid_node(_host_entities[id]) else _host_entity_targets.get(id, Vector2.ZERO)
		_schedule_remote_death(id, category, pos, now + DEATH_VISUAL_DELAY_MSEC, source)
	else:
		_remove_host_entity(id, true)


func _schedule_remote_death(id: String, category: String, pos: Vector2, remove_at_msec: int, source: String) -> void:
	if id == "":
		return
	if not ENABLE_DEATH_SYNC:
		_remove_host_entity(id, true)
		_locally_killed_until.erase(id)
		_sent_kill_claim_ids.erase(id)
		return
	if _locally_killed_until.has(id):
		_remove_host_entity(id, true)
		_locally_killed_until.erase(id)
		_sent_kill_claim_ids.erase(id)
		return
	if not _host_entities.has(id):
		return
	if category == "":
		category = str(_host_entity_category.get(id, ""))
	if not _is_combat_death_category(category):
		_remove_host_entity(id, true)
		return
	if _is_host_battle_inactive_cached():
		remove_at_msec = OS.get_ticks_msec()
	if _pending_remote_deaths.has(id):
		var existing = _pending_remote_deaths[id]
		if typeof(existing) == TYPE_DICTIONARY:
			existing["remove_at"] = min(int(existing.get("remove_at", remove_at_msec)), remove_at_msec)
			_pending_remote_deaths[id] = existing
		return
	_pending_remote_deaths[id] = {
		"remove_at": remove_at_msec,
		"category": category,
		"pos": pos,
		"source": source
	}


func _update_pending_remote_deaths() -> void:
	if not ENABLE_DEATH_SYNC:
		_pending_remote_deaths.clear()
		return
	if _pending_remote_deaths.empty():
		return
	var now = OS.get_ticks_msec()
	var ready = []
	for id_value in _pending_remote_deaths.keys():
		var id = str(id_value)
		var data = _pending_remote_deaths[id]
		if typeof(data) != TYPE_DICTIONARY:
			ready.append(id)
		elif now >= int(data.get("remove_at", now)):
			ready.append(id)
	for id in ready:
		_apply_pending_remote_death(id)


func _apply_pending_remote_death(id: String) -> void:
	var node = _host_entities.get(id, null)
	if _is_valid_node(node):
		node.set_meta("brotato_online_remote_death_applying", true)
		_unregister_from_spawner_arrays(node)
		if node.has_method("die") and not bool(node.get("dead")):
			node.call("die")
		else:
			node.queue_free()
	_cleanup_host_entity_tracking(id)
	_pending_remote_deaths.erase(id)
	_locally_killed_until.erase(id)
	_sent_kill_claim_ids.erase(id)


func _is_combat_death_category(category: String) -> bool:
	return category == "enemy" or category == "boss" or category == "neutral" or category == "structure" or category == "pet"


func _is_host_battle_inactive_cached() -> bool:
	if typeof(_latest_wave_timer_state) != TYPE_DICTIONARY or _latest_wave_timer_state.empty():
		return false
	if bool(_latest_wave_timer_state.get("running", false)):
		return float(_latest_wave_timer_state.get("time_left", 0.0)) <= 0.05
	return true


func _neutralize_client_combat_threats(reason: String) -> void:
	if _is_game_host() or not _is_in_game_scene():
		return
	_clear_birth_markers(reason)
	var locator = _get_runtime_locator()
	var spawner = locator.get_entity_spawner() if locator != null and locator.has_method("get_entity_spawner") else null
	if spawner != null:
		spawner.set("_cleaning_up", true)
		spawner.set("active_births", 0)
		spawner.set("_all_enemy_dirty", true)
		_clear_spawner_queues(spawner)
		for prop in ["enemies", "bosses", "charmed_enemies"]:
			var arr = spawner.get(prop)
			if typeof(arr) == TYPE_ARRAY:
				for node in arr:
					_neutralize_combat_threat_node(node)
	for id_value in _host_entities.keys():
		var id = str(id_value)
		var category = str(_host_entity_category.get(id, ""))
		if category == "enemy" or category == "boss":
			_neutralize_combat_threat_node(_host_entities[id])
	_clear_enemy_projectiles()


func _neutralize_combat_threat_node(node: Node) -> void:
	if not _is_valid_node(node):
		return
	if node.get("_can_move") != null:
		node.set("_can_move", false)
	if node.get("_move_locked") != null:
		node.set("_move_locked", true)
	node.set_physics_process(false)
	node.set_process(false)
	_disable_behavior_children(node)
	_disable_collision_tree(node)


func _clear_enemy_projectiles() -> void:
	var main = get_tree().current_scene
	if main == null:
		return
	var enemy_projectiles = main.get("_enemy_projectiles")
	if not _is_valid_node(enemy_projectiles):
		enemy_projectiles = main.get_node_or_null("EnemyProjectiles")
	if not _is_valid_node(enemy_projectiles):
		return
	for child in enemy_projectiles.get_children():
		if _is_valid_node(child):
			child.queue_free()


func _remove_host_entity(id: String, free_node: bool) -> void:
	if _host_entities.has(id):
		var node = _host_entities[id]
		_unregister_from_spawner_arrays(node)
		if free_node and _is_valid_node(node):
			node.queue_free()
	_cleanup_host_entity_tracking(id)
	_pending_remote_deaths.erase(id)


func _cleanup_host_entity_tracking(id: String) -> void:
	_host_entities.erase(id)
	_host_entity_category.erase(id)
	_host_entity_scene_path.erase(id)
	_host_entity_targets.erase(id)
	_host_entity_velocities.erase(id)
	_host_entity_rx_msec.erase(id)
	_host_entity_samples.erase(id)
	_connected_died_ids.erase(id)
	_connected_damage_ids.erase(id)


func _remove_birth_marker(id: String) -> void:
	if _birth_markers.has(id):
		var marker = _birth_markers[id]
		if _is_valid_node(marker):
			marker.queue_free()
	_birth_markers.erase(id)
	_birth_marker_states.erase(id)


func _remove_pickup_marker(id: String) -> void:
	if _pickup_markers.has(id):
		var marker = _pickup_markers[id]
		if _is_valid_node(marker):
			marker.queue_free()
	_pickup_markers.erase(id)
	_pickup_targets.erase(id)
	_pickup_claimed.erase(id)


func _prune_missing_host_entities(active_ids: Dictionary) -> void:
	var to_remove = []
	for id_value in _host_entities.keys():
		var id = str(id_value)
		if active_ids.has(id):
			continue

		var category = str(_host_entity_category.get(id, ""))
		var sync_mode = _get_entity_sync_mode(category, {})
		if sync_mode == SYNC_MODE_BIRTH_ONLY:
			# Birth-only enemies are intentionally independent after creation.
			# Do not delete them just because a snapshot temporarily misses active_entity_ids.
			# They are removed only by an explicit Host `removed` id or by local death.
			continue

		to_remove.append(id)
	var now = OS.get_ticks_msec()
	for id in to_remove:
		_schedule_or_remove_remote_death(id, "prune_missing", now)


func _prune_local_kill_ignores(now: int, active_ids: Dictionary) -> void:
	var to_remove = []
	for id_value in _locally_killed_until.keys():
		var id = str(id_value)
		# For birth-only entities, a local death means the client has already
		# removed its visual/gameplay copy. Do not resurrect it just because the
		# Host still reports the same net_id as active or periodically resends the
		# birth payload. Only clear the guard after the Host confirms removal by
		# omitting the id from active_entity_ids / sending it in removed.
		if not active_ids.has(id):
			to_remove.append(id)
		elif now >= int(_locally_killed_until[id]) and _host_entities.has(id):
			# Defensive cleanup for stale guards on entities that still exist locally.
			to_remove.append(id)
	for id in to_remove:
		_locally_killed_until.erase(id)


func _clear_all(reason: String) -> void:
	_sanitize_stats_manager_queues("clear_all_before:" + reason)
	_latest_snapshot = {}
	_latest_snapshot_tick = -1
	_last_applied_tick = -1
	for id_value in _host_entities.keys():
		_remove_host_entity(str(id_value), true)
	_clear_birth_markers(reason)
	_latest_wave_timer_state.clear()
	_last_wave_timer_apply_msec = 0
	for p in _pickup_markers.keys():
		var pm = _pickup_markers[p]
		if _is_valid_node(pm):
			pm.queue_free()
	_pickup_markers.clear()
	_pickup_targets.clear()
	_pickup_claimed.clear()
	_remote_player_targets.clear()
	_remote_player_velocities.clear()
	_remote_player_rx_msec.clear()
	_remote_player_samples.clear()
	_locally_killed_until.clear()
	_pending_boss_damage.clear()
	_pending_boss_one_shots.clear()
	_pending_remote_deaths.clear()
	_seen_battle_event_ids.clear()
	_sent_kill_claim_ids.clear()
	_spawned_from_birth_marker_entity_ids.clear()
	_last_entity_resync_request_msec_by_net_id.clear()
	_last_progression_apply_key_by_player.clear()
	_last_progression_queue_key_by_player.clear()
	_host_entity_samples.clear()
	_host_clock_offset_initialized = false
	_host_clock_offset_msec = 0.0
	_snapshot_gate_scene_instance_id = 0
	_snapshot_gate_enter_msec = 0
	_snapshot_gate_seen_running_wave = false
	_last_host_battle_inactive_cleanup_msec = 0
	_last_sent_player_dead_state = false
	_sent_owned_player_terminal_state = false
	_last_terminal_player_state_reason = ""
	_last_applied_tick = -1
	_sanitize_stats_manager_queues("clear_all_after:" + reason)


func _clear_spawner_queues(spawner: Node) -> void:
	_clear_array_property(spawner, "queue_to_spawn")
	_clear_array_property(spawner, "queue_to_spawn_trees")
	_clear_array_property(spawner, "queue_to_spawn_summons")
	_clear_array_property(spawner, "queue_to_spawn_bosses")
	_clear_nested_array_property(spawner, "queues_to_spawn_structures")
	_clear_nested_array_property(spawner, "queues_to_spawn_pets")


func _remove_non_host_controlled_entities(spawner: Node, locator: Node) -> Dictionary:
	var counts = {
		"enemies": _free_spawner_array_except_host(spawner, "enemies"),
		"bosses": _free_spawner_array_except_host(spawner, "bosses"),
		"neutrals": _free_spawner_array_except_host(spawner, "neutrals"),
		"structures": _free_spawner_array_except_host(spawner, "structures"),
		"pets": _free_spawner_array_except_host(spawner, "pets"),
		"births": _free_non_host_births(locator)
	}
	_clear_array_property(spawner, "targetable_pets")
	_clear_array_property(spawner, "structures_to_remove_in_priority")
	_clear_array_property(spawner, "enemies_to_remove_in_priority")
	_clear_array_property(spawner, "charmed_enemies")
	return counts


func _free_spawner_array_except_host(spawner: Node, property_name: String) -> int:
	var arr = spawner.get(property_name)
	if typeof(arr) != TYPE_ARRAY:
		return 0
	var removed = 0
	var keep = []
	for node in arr:
		if _is_valid_node(node) and _has_meta_true(node, "brotato_online_host_entity"):
			keep.append(node)
		elif _is_valid_node(node):
			_remove_node_from_stats_manager_queues(node, "free_spawner_array:" + property_name)
			node.queue_free()
			removed += 1
	arr.clear()
	for node2 in keep:
		if _is_valid_node(node2):
			arr.append(node2)
	return removed


func _free_non_host_births(locator: Node) -> int:
	if locator == null or not locator.has_method("get_births_container"):
		return 0
	var container = locator.get_births_container()
	if container == null:
		return 0
	var removed = 0
	for child in container.get_children():
		if _is_valid_node(child) and not _has_meta_true(child, "brotato_online_birth_marker"):
			child.queue_free()
			removed += 1
	return removed


func _unregister_from_spawner_arrays(node: Node) -> void:
	if node == null:
		return
	_remove_node_from_stats_manager_queues(node, "unregister_from_spawner")
	var locator = _get_runtime_locator()
	var spawner = locator.get_entity_spawner() if locator != null and locator.has_method("get_entity_spawner") else null
	if spawner == null:
		return
	for prop in ["enemies", "bosses", "neutrals", "structures", "pets", "targetable_pets", "enemies_to_remove_in_priority", "structures_to_remove_in_priority", "charmed_enemies"]:
		var arr = spawner.get(prop)
		if typeof(arr) == TYPE_ARRAY:
			arr.erase(node)
	spawner.set("_all_enemy_dirty", true)


func _get_stats_manager_node() -> Node:
	var main = _get_current_main_node()
	if main != null and is_instance_valid(main):
		var stored = main.get("_stats_manager")
		if stored != null and is_instance_valid(stored) and stored is Node:
			return stored
		var by_name = main.get_node_or_null("StatsManager")
		if by_name != null and is_instance_valid(by_name):
			return by_name
	return null


func _sanitize_stats_manager_queues(reason: String) -> void:
	var stats_manager = _get_stats_manager_node()
	if stats_manager == null:
		return
	var removed = _sanitize_stats_manager_queue_dict(stats_manager.get("_player_queue"), null)
	removed += _sanitize_stats_manager_queue_dict(stats_manager.get("_weapon_queue"), null)
	removed += _sanitize_stats_manager_queue_array(stats_manager.get("_structure_queues"), null)
	removed += _sanitize_stats_manager_queue_array(stats_manager.get("_pet_queues"), null)
	if removed > 0:
		pass


func _remove_node_from_stats_manager_queues(node, reason: String) -> void:
	var target = node if node != null and typeof(node) == TYPE_OBJECT and is_instance_valid(node) else null
	var stats_manager = _get_stats_manager_node()
	if stats_manager == null:
		return
	var removed = _sanitize_stats_manager_queue_dict(stats_manager.get("_player_queue"), target)
	removed += _sanitize_stats_manager_queue_dict(stats_manager.get("_weapon_queue"), target)
	removed += _sanitize_stats_manager_queue_array(stats_manager.get("_structure_queues"), target)
	removed += _sanitize_stats_manager_queue_array(stats_manager.get("_pet_queues"), target)
	if removed > 0:
		pass


func _sanitize_stats_manager_queue_array(queues, target) -> int:
	if typeof(queues) != TYPE_ARRAY:
		return 0
	var removed = 0
	for queue in queues:
		removed += _sanitize_stats_manager_queue_dict(queue, target)
	return removed


func _sanitize_stats_manager_queue_dict(queue, target) -> int:
	if typeof(queue) != TYPE_DICTIONARY:
		return 0
	var removed = 0
	for key in queue.keys():
		var should_remove = _should_remove_stats_queue_key(key, target)
		if should_remove:
			queue.erase(key)
			removed += 1
	return removed


func _should_remove_stats_queue_key(key, target) -> bool:
	if key == null:
		return true
	if typeof(key) != TYPE_OBJECT:
		return true
	if not is_instance_valid(key):
		return true
	if key is Node and key.is_queued_for_deletion():
		return true
	if target != null and typeof(target) == TYPE_OBJECT and is_instance_valid(target) and key == target:
		return true
	return false


func _disable_behavior_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		if not (child is Node):
			continue
		var n = str(child.name).to_lower()
		if n.find("movement") >= 0 or n.find("attack") >= 0 or n.find("target") >= 0:
			child.set_process(false)
			child.set_physics_process(false)
			if child is Timer:
				child.stop()
		_disable_behavior_children(child)


func _disable_logic_tree(node: Node) -> void:
	if node == null:
		return
	if not (node is Sprite) and not (node is Polygon2D):
		node.set_process(false)
		node.set_physics_process(false)
	if node is Timer:
		node.stop()
	if node is AnimationPlayer:
		node.stop(false)
	for child in node.get_children():
		if child is Node:
			_disable_logic_tree(child)


func _disable_collision_tree(node: Node) -> void:
	if node == null:
		return
	if node is CollisionObject2D:
		node.set_deferred("collision_layer", 0)
		node.set_deferred("collision_mask", 0)
	if node is Area2D:
		node.set_deferred("monitoring", false)
		node.set_deferred("monitorable", false)
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.set_deferred("disabled", true)
	for child in node.get_children():
		if child is Node:
			_disable_collision_tree(child)


func _enable_area_named(node: Node, target_name: String, enabled: bool) -> void:
	if node == null:
		return
	if str(node.name) == target_name:
		if node is Area2D:
			node.set_deferred("monitoring", enabled)
			node.set_deferred("monitorable", enabled)
			if node.get("active") != null:
				node.set("active", enabled)
		for child in node.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred("disabled", not enabled)
	for child2 in node.get_children():
		if child2 is Node:
			_enable_area_named(child2, target_name, enabled)


func _category_from_entity_type(entity_type: int) -> String:
	if entity_type == EntityType.ENEMY:
		return "enemy"
	if entity_type == EntityType.BOSS:
		return "boss"
	if entity_type == EntityType.NEUTRAL:
		return "neutral"
	if entity_type == EntityType.STRUCTURE:
		return "structure"
	if entity_type == EntityType.PET:
		return "pet"
	return ""


func _get_entity_sync_mode(category: String, state: Dictionary) -> String:
	var explicit_mode = str(state.get("sync_mode", "")) if typeof(state) == TYPE_DICTIONARY else ""
	if explicit_mode == SYNC_MODE_BIRTH_ONLY or explicit_mode == SYNC_MODE_HOST_MOTION:
		return explicit_mode
	# Regular enemies, neutral trees and structures are birth-only. Boss covers
	# elites/bosses in Brotato; pets still use Host motion.
	if category == "boss" or category == "pet":
		return SYNC_MODE_HOST_MOTION
	return SYNC_MODE_BIRTH_ONLY


func _get_snapshot_server_time_msec(snapshot: Dictionary, fallback: int) -> int:
	if snapshot.has("server_time_msec"):
		return int(snapshot.get("server_time_msec"))
	if snapshot.has("time_msec"):
		return int(snapshot.get("time_msec"))
	return fallback


func _get_snapshot_wave(snapshot: Dictionary) -> int:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return -1
	if snapshot.has("wave"):
		return int(snapshot.get("wave", -1))
	var timer_state = snapshot.get("wave_timer_state", {})
	if typeof(timer_state) == TYPE_DICTIONARY and timer_state.has("wave"):
		return int(timer_state.get("wave", -1))
	var progression_state = snapshot.get("progression_state", {})
	if typeof(progression_state) == TYPE_DICTIONARY and progression_state.has("wave"):
		return int(progression_state.get("wave", -1))
	return -1


func _get_local_run_wave() -> int:
	if RunData == null:
		return -1
	var value = RunData.get("current_wave")
	if value == null:
		return -1
	return int(value)


func _update_host_clock_offset(host_time_msec: int, local_time_msec: int) -> void:
	var measured = float(local_time_msec - host_time_msec)
	if not _host_clock_offset_initialized:
		_host_clock_offset_msec = measured
		_host_clock_offset_initialized = true
	else:
		_host_clock_offset_msec = lerp(_host_clock_offset_msec, measured, CLOCK_OFFSET_SMOOTHING)


func _get_estimated_host_time_msec(local_time_msec: int) -> int:
	if not _host_clock_offset_initialized:
		return local_time_msec
	return int(float(local_time_msec) - _host_clock_offset_msec)


func _append_entity_sample(net_id: String, host_time_msec: int, pos: Vector2, vel: Vector2) -> void:
	if not _host_entity_samples.has(net_id):
		_host_entity_samples[net_id] = []
	_append_sample_to_buffer(_host_entity_samples[net_id], host_time_msec, pos, vel)


func _append_remote_player_sample(player_index: int, host_time_msec: int, pos: Vector2, vel: Vector2) -> void:
	if not _remote_player_samples.has(player_index):
		_remote_player_samples[player_index] = []
	_append_sample_to_buffer(_remote_player_samples[player_index], host_time_msec, pos, vel)


func _append_sample_to_buffer(buffer: Array, host_time_msec: int, pos: Vector2, vel: Vector2) -> void:
	if buffer.size() > 0 and int(buffer[buffer.size() - 1].get("t", 0)) == host_time_msec:
		buffer[buffer.size() - 1] = {"t": host_time_msec, "pos": pos, "vel": vel}
	else:
		buffer.append({"t": host_time_msec, "pos": pos, "vel": vel})
	var keep_after = host_time_msec - INTERPOLATION_BUFFER_KEEP_MSEC
	while buffer.size() > 2 and int(buffer[0].get("t", 0)) < keep_after:
		buffer.pop_front()


func _sample_position(buffer: Array, target_time_msec: int, fallback_pos: Vector2, fallback_vel: Vector2) -> Array:
	if buffer.size() == 0:
		return [fallback_pos, fallback_vel]
	if buffer.size() == 1:
		var only = buffer[0]
		var dt_only = float(clamp(target_time_msec - int(only.get("t", target_time_msec)), 0, MAX_EXTRAPOLATION_MSEC)) / 1000.0
		var only_pos = only.get("pos", fallback_pos)
		var only_vel = only.get("vel", fallback_vel)
		return [only_pos + only_vel * dt_only, only_vel]

	var first = buffer[0]
	if target_time_msec <= int(first.get("t", 0)):
		return [first.get("pos", fallback_pos), first.get("vel", fallback_vel)]

	for i in range(buffer.size() - 1):
		var a = buffer[i]
		var b = buffer[i + 1]
		var ta = int(a.get("t", 0))
		var tb = int(b.get("t", 0))
		if target_time_msec >= ta and target_time_msec <= tb:
			var denom = max(1.0, float(tb - ta))
			var ratio = clamp(float(target_time_msec - ta) / denom, 0.0, 1.0)
			var pa = a.get("pos", fallback_pos)
			var pb = b.get("pos", fallback_pos)
			var va = a.get("vel", fallback_vel)
			var vb = b.get("vel", fallback_vel)
			return [pa.linear_interpolate(pb, ratio), va.linear_interpolate(vb, ratio)]

	var last = buffer[buffer.size() - 1]
	var last_pos = last.get("pos", fallback_pos)
	var last_vel = last.get("vel", fallback_vel)
	var dt = float(clamp(target_time_msec - int(last.get("t", target_time_msec)), 0, MAX_EXTRAPOLATION_MSEC)) / 1000.0
	return [last_pos + last_vel * dt, last_vel]


func _make_marker_for_category(category: String) -> Node:
	var marker = Polygon2D.new()
	var r = 8.0
	if category == "boss":
		r = 16.0
	elif category == "structure" or category == "pet":
		r = 10.0
	# Last-resort fallback only. Use an opaque square, not a transparent diamond.
	marker.polygon = PoolVector2Array([Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])
	marker.color = Color(0.85, 0.85, 0.85, 1.0)
	return marker


func _is_local_combat_category(category: String) -> bool:
	return category == "enemy" or category == "boss" or category == "neutral" or category == "structure" or category == "pet"

func _is_client_owned_player_index(player_index: int) -> bool:
	if _is_game_host():
		return false
	return player_index >= 0 and player_index == _get_owned_player_index()


func _get_owned_player_node() -> Node:
	var locator = _get_runtime_locator()
	if locator == null or not locator.has_method("get_players"):
		return null
	var players = locator.get_players()
	if typeof(players) != TYPE_ARRAY:
		return null
	var owned_index = _get_owned_player_index()
	for i in range(players.size()):
		var player = players[i]
		if _is_valid_node(player) and _get_player_index_from_node(player, i) == owned_index:
			return player
	return null


func _get_owned_player_index() -> int:
	if _is_game_host():
		return 0
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("get_local_mirrored_player_index"):
		var idx = int(slot_manager.get_local_mirrored_player_index())
		if idx >= 0:
			_cache_owned_player_index(idx, "slot_manager")
			return idx
	var inferred = _infer_owned_player_index_from_coop_layout()
	if inferred >= 0:
		_cache_owned_player_index(inferred, "coop_layout")
		return inferred
	return _cached_owned_player_index


func _cache_owned_player_index(idx: int, source: String) -> void:
	if idx < 0:
		return
	var changed = _cached_owned_player_index != idx
	_cached_owned_player_index = idx
	var now = OS.get_ticks_msec()
	if changed or now - _last_owned_index_log_msec > 5000:
		_last_owned_index_log_msec = now


func _infer_owned_player_index_from_coop_layout() -> int:
	if CoopService == null:
		return -1
	var keyboard_device = 7
	if typeof(CoopService.connected_players) == TYPE_ARRAY:
		for i in range(CoopService.connected_players.size()):
			var data = CoopService.connected_players[i]
			if typeof(data) == TYPE_ARRAY and data.size() >= 1 and int(data[0]) == keyboard_device:
				return i
	var run_count = int(RunData.get_player_count()) if RunData != null else 0
	if run_count >= 2:
		return run_count - 1
	return -1


func _get_player_index_from_node(player: Node, fallback: int) -> int:
	if not _is_valid_node(player):
		return fallback
	var raw = player.get("player_index")
	if raw != null:
		return int(raw)
	return fallback


func _get_runtime_locator() -> Node:
	return _get_sibling_or_root_node("BrotatoOnlineRuntimeLocator")


func _get_steam_lobby_manager() -> Node:
	return _get_sibling_or_root_node("BrotatoOnlineSteamLobbyManager")


func _get_slot_manager() -> Node:
	var node = _get_sibling_or_root_node("BrotatoOnlineOnlinePlayerSlotManager")
	if node != null:
		return node
	return _get_sibling_or_root_node("BrotatoOnlinePlayerSlotManager")


func _get_sibling_or_root_node(node_name: String) -> Node:
	if get_parent() != null:
		var sibling = get_parent().get_node_or_null(node_name)
		if sibling != null:
			return sibling
	return get_node_or_null("/root/" + node_name)

func _get_entities_parent() -> Node:
	var locator = _get_runtime_locator()
	if locator != null and locator.has_method("get_entities_container"):
		var c = locator.get_entities_container()
		if c != null:
			return c
	return get_tree().current_scene


func _get_births_parent() -> Node:
	var locator = _get_runtime_locator()
	if locator != null and locator.has_method("get_births_container"):
		var c = locator.get_births_container()
		if c != null:
			return c
	return _get_entities_parent()


func _get_wave_timer() -> Timer:
	var locator = _get_runtime_locator()
	var main = locator.get_main() if locator != null and locator.has_method("get_main") else get_tree().current_scene
	if main == null:
		return null
	var stored = main.get("_wave_timer")
	if stored != null and is_instance_valid(stored) and stored is Timer:
		return stored
	var node = main.get_node_or_null("WaveTimer")
	if node != null and is_instance_valid(node) and node is Timer:
		return node
	return null


func _get_wave_timer_label() -> Label:
	var locator = _get_runtime_locator()
	var main = locator.get_main() if locator != null and locator.has_method("get_main") else get_tree().current_scene
	if main == null:
		return null
	var stored = main.get("_wave_timer_label")
	if stored != null and is_instance_valid(stored) and stored is Label:
		return stored
	var node = main.get_node_or_null("UI/HUD/WaveContainer/WaveTimerLabel")
	if node != null and is_instance_valid(node) and node is Label:
		return node
	return null


func _is_online_session_active() -> bool:
	var steam = _get_steam_lobby_manager()
	if steam != null:
		if steam.has_method("is_online_session_active"):
			return bool(steam.is_online_session_active())
		if steam.has_method("has_active_online_session"):
			return bool(steam.has_active_online_session())
	return false


func _is_game_host() -> bool:
	var steam = _get_steam_lobby_manager()
	if steam != null and steam.has_method("is_game_host"):
		return bool(steam.is_game_host())
	return false


func _is_in_game_scene() -> bool:
	var scene = get_tree().current_scene
	if scene == null:
		return false
	return str(scene.filename) == "res://main.tscn" or scene.name == "Main"


func _is_valid_node(node) -> bool:
	return node != null and is_instance_valid(node) and node is Node and not node.is_queued_for_deletion() and node.is_inside_tree()


func _node_has_valid_position(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node is Node2D:
		var p = node.global_position
		return not is_nan(p.x) and not is_nan(p.y) and not is_inf(p.x) and not is_inf(p.y)
	return false


func _get_node_global_pos(node: Node) -> Vector2:
	if node != null and is_instance_valid(node) and node is Node2D:
		return node.global_position
	return Vector2.ZERO


func _set_node_global_pos(node: Node, pos: Vector2) -> void:
	if node != null and is_instance_valid(node) and node is Node2D:
		node.global_position = pos


func _get_velocity(node: Node) -> Vector2:
	if node == null or not is_instance_valid(node):
		return Vector2.ZERO
	var velocity = node.get("velocity")
	if typeof(velocity) == TYPE_VECTOR2:
		return velocity
	var current_movement = node.get("_current_movement")
	if typeof(current_movement) == TYPE_VECTOR2:
		return current_movement
	if node is RigidBody2D:
		return node.linear_velocity
	return Vector2.ZERO


func _dict_to_vec2(value) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value
	if typeof(value) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))


func _vec_to_dict(v: Vector2) -> Dictionary:
	return {"x": float(v.x), "y": float(v.y)}


func _safe_node_name(value: String) -> String:
	var s = value
	for ch in ["/", ":", "@", " ", "."]:
		s = s.replace(ch, "_")
	return s


func _safe_bool(value) -> bool:
	var t = typeof(value)
	if t == TYPE_BOOL:
		return value
	if t == TYPE_INT or t == TYPE_REAL:
		return value != 0
	if t == TYPE_STRING:
		var v = str(value).strip_edges().to_lower()
		return v == "true" or v == "1" or v == "yes" or v == "on"
	return bool(value)


func _has_meta_true(node: Node, key: String) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.has_meta(key):
		return false
	return bool(node.get_meta(key))


func _clear_array_property(obj: Object, property_name: String) -> void:
	if obj == null:
		return
	var value = obj.get(property_name)
	if typeof(value) == TYPE_ARRAY:
		value.clear()


func _clear_nested_array_property(obj: Object, property_name: String) -> void:
	if obj == null:
		return
	var value = obj.get(property_name)
	if typeof(value) != TYPE_ARRAY:
		return
	for sub in value:
		if typeof(sub) == TYPE_ARRAY:
			sub.clear()


func _force_remote_player_death_pose(player: Node) -> void:
	if not _is_valid_node(player):
		return

	var played_death = false

	var anim = player.get("_animation_player")
	if anim != null and is_instance_valid(anim) and anim.has_method("has_animation") and anim.has_animation("death"):
		anim.playback_speed = 1
		anim.play("death")
		if anim.has_method("advance"):
			anim.advance(0.12)
		played_death = true

	var smoke = player.get("_running_smoke")
	if smoke != null and is_instance_valid(smoke) and smoke.has_method("stop"):
		smoke.stop()

	if not played_death and player is CanvasItem:
		player.hide()


func _array_size(value) -> int:
	if typeof(value) == TYPE_ARRAY:
		return value.size()
	if typeof(value) == TYPE_DICTIONARY:
		return value.size()
	return 0
