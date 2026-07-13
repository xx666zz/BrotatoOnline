extends Node

const REMOTE_DEAD_DISPLAY_HP = -999
const BULL_CHARACTER_ID = "character_bull"

# Host-side snapshot collector for battle sync.
# Birth-only entities are announced once through reliable battle events; host-motion
# entities are carried by lightweight unreliable snapshots. Host still owns economy/XP/box queues and boss HP; pickup visuals are local-only.


const SNAPSHOT_INTERVAL_MSEC = 120
const SYNC_MODE_BIRTH_ONLY = "birth_only"
const SYNC_MODE_HOST_MOTION = "host_motion"
const SUMMARY_PRINT_INTERVAL_MSEC = 5000
const MAX_SUMMARY_ENTITY_SAMPLES = 3
const MAX_EVENTS_PER_SNAPSHOT = 64
const MAX_RELIABLE_BIRTH_ENTITIES_PER_SEND = 96
const MAX_RELIABLE_BIRTH_MARKERS_PER_SEND = 96
const MAX_RELIABLE_REMOVED_PER_SEND = 160
# Diagnostic switch: disable Host removed-id propagation. Host still purges its local registry
# bookkeeping, but clients no longer receive removed ids or prune missing host entities.
const ENABLE_REMOVED_SYNC = false
const RESERVED_BIRTH_MATCH_RADIUS = 96.0
const RESERVED_BIRTH_TTL_MSEC = 12000
const ENABLE_PROJECTILE_VISUAL_EVENTS_IN_B5_5 = false
const ENABLE_DAMAGE_HIT_EVENTS = false
const REMOTE_PLAYER_HURTBOX_GUARD_INTERVAL_MSEC = 250
# Diagnostic switch: disable broad BrotatoOnline death-report application and Host death-event broadcast.
const ENABLE_DEATH_REPORT_APPLY = false
# Narrow exceptions for boss/elite client kills and Vorpal/one-shot boss damage reports.
# In Brotato, elites and bosses both arrive as category == "boss".
const ENABLE_BOSS_ELITE_DEATH_REPORT_APPLY = true
const ENABLE_BOSS_ONE_SHOT_REPORT_APPLY = true
const ENABLE_DEATH_EVENT_BROADCAST = false
const ENABLE_REMOTE_PLAYER_DEATH_SYNC = true

var _tick = 0
var _last_snapshot_msec = 0
var _last_summary_print_msec = 0
var _last_snapshot = {}
var _last_economy_snapshot_msec = 0
var _last_progression_snapshot_msec = 0
var _cached_economy_state = {}
var _cached_progression_state = {}
var _last_forced_stopped_progression_key = ""
var _last_scene_was_game = false
var _last_game_scene_instance_id = 0
var _game_scene_enter_msec = 0
var _next_battle_event_id = 1
var _pending_battle_events = []
var _pending_reliable_birth_entities_by_net_id = {}
var _pending_reliable_birth_entity_order = []
var _pending_reliable_birth_markers_by_net_id = {}
var _pending_reliable_birth_marker_order = []
var _pending_reliable_removed_id_set = {}
var _pending_reliable_removed_ids = []
var _damage_signal_connected_ids = {}
var _known_projectile_instance_ids = {}
var _last_entity_pos_by_net_id = {}
var _last_entity_category_by_net_id = {}
var _last_entity_cursed_by_net_id = {}
var _structure_curse_data_signature_by_net_id = {}
var _host_entity_by_net_id = {}
var _host_entity_by_short_id = {}
var _host_pickup_by_net_id = {}
var _host_pickup_kind_by_net_id = {}
var _last_damage_claim_log_msec = 0
var _damage_claim_batches_applied = 0
var _damage_claim_damage_applied = 0
var _birth_only_announced_net_ids = {}
var _birth_only_first_seen_msec = {}
var _announced_death_net_ids = {}
var _birth_marker_announced_net_ids = {}
var _reserved_spawn_by_birth_id = {}
var _reserved_birth_id_by_spawn_net_id = {}
var _pending_signal_spawn_nodes = []
var _pending_signal_spawn_instance_ids = {}
var _connected_spawner_instance_id = ""
var _last_remote_player_hurtbox_guard_msec = 0


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	set_process(true)
	var parent_name = "null"
	if get_parent() != null:
		parent_name = str(get_parent().name)


func _process(_delta: float) -> void:
	var locator = _get_runtime_locator()
	var steam = _get_steam_lobby_manager()
	var in_game = locator != null and locator.has_method("is_in_game_scene") and bool(locator.is_in_game_scene())
	var online_active = _is_online_session_active()
	var is_host = _is_game_host()


	if not online_active:
		if _last_scene_was_game:
			_on_left_game_scene()
		_last_scene_was_game = false
		return

	if not in_game:
		if _last_scene_was_game:
			_on_left_game_scene()
		_last_scene_was_game = false
		return

	_ensure_current_game_scene_registered("process", locator, is_host, steam)

	if not is_host:
		return

	_prepare_host_remote_player_damage_proxies(false)

	var now = OS.get_ticks_msec()
	if now - _last_snapshot_msec < SNAPSHOT_INTERVAL_MSEC:
		return
	_last_snapshot_msec = now

	var snapshot = build_snapshot()
	_last_snapshot = snapshot

	if now - _last_summary_print_msec >= SUMMARY_PRINT_INTERVAL_MSEC:
		_last_summary_print_msec = now
		_print_snapshot_summary(snapshot)


func build_snapshot() -> Dictionary:
	_tick += 1

	var locator = _get_runtime_locator()
	var registry = _get_net_id_registry()
	var players = []
	# Continuous snapshot payload contains only entities whose current state must be
	# host-driven every sample. Regular enemies/neutrals/structures are born through
	# the reliable event queue and then simulate locally.
	var entities = []
	var removed = []
	var counts = {}
	var active_dynamic_net_ids = {}
	var emitted_dynamic_net_ids = {}
	var events = []
	var now_msec = OS.get_ticks_msec()
	var wave_timer_state = _build_wave_timer_state(locator, now_msec)
	var battle_allows_births = _wave_timer_state_allows_births(wave_timer_state)
	if locator != null:
		_ensure_spawner_signal_connections(locator)
	if locator != null and locator.has_method("get_entity_counts"):
		counts = locator.get_entity_counts()

	if locator != null and locator.has_method("get_players"):
		var player_nodes = locator.get_players()
		for i in range(player_nodes.size()):
			var player = player_nodes[i]
			if not _is_valid_node(player):
				continue
			players.append(_build_player_state(player, i, registry))

	_process_pending_signal_spawn_nodes(locator, registry, now_msec, entities, active_dynamic_net_ids, emitted_dynamic_net_ids)
	_append_dynamic_entity_states(locator, registry, "get_enemy_nodes", "enemy", _entity_type_enemy(), "enemy", SYNC_MODE_BIRTH_ONLY, now_msec, entities, active_dynamic_net_ids, emitted_dynamic_net_ids)
	_append_dynamic_entity_states(locator, registry, "get_bosses", "boss", _entity_type_boss(), "boss", SYNC_MODE_HOST_MOTION, now_msec, entities, active_dynamic_net_ids, emitted_dynamic_net_ids)
	_append_dynamic_entity_states(locator, registry, "get_neutrals", "neutral", _entity_type_neutral(), "neutral", SYNC_MODE_BIRTH_ONLY, now_msec, entities, active_dynamic_net_ids, emitted_dynamic_net_ids)
	_append_dynamic_entity_states(locator, registry, "get_structures", "structure", _entity_type_structure(), "structure", SYNC_MODE_BIRTH_ONLY, now_msec, entities, active_dynamic_net_ids, emitted_dynamic_net_ids)
	_append_dynamic_entity_states(locator, registry, "get_pets", "pet", _entity_type_pet(), "pet", SYNC_MODE_HOST_MOTION, now_msec, entities, active_dynamic_net_ids, emitted_dynamic_net_ids)

	if battle_allows_births and locator != null and locator.has_method("get_births"):
		var birth_nodes = locator.get_births()
		for birth in birth_nodes:
			if not _is_valid_node(birth):
				continue
			var birth_state = _build_birth_state(birth, registry, now_msec)
			if not birth_state.empty():
				var birth_id = str(birth_state.get("net_id", ""))
				active_dynamic_net_ids[birth_id] = true
				if birth_id != "" and not _birth_marker_announced_net_ids.has(birth_id):
					_birth_marker_announced_net_ids[birth_id] = true
					_queue_pending_reliable_birth_marker(birth_state)


	_collect_projectile_spawn_visual_events(locator)
	# Pickups are deliberately not part of the battle snapshot anymore.
	# Each peer runs local pickup visuals/interactions; Host snapshots correct economy/XP
	# and the Host-authoritative upgrade/item-box queues at a low rate.

	if registry != null and registry.has_method("purge_missing"):
		var purged_removed = registry.purge_missing(active_dynamic_net_ids)
		for removed_id_value in purged_removed:
			var removed_id = str(removed_id_value)
			_birth_only_announced_net_ids.erase(removed_id)
			_birth_only_first_seen_msec.erase(removed_id)
			_birth_marker_announced_net_ids.erase(removed_id)
			_last_entity_pos_by_net_id.erase(removed_id)
			_last_entity_category_by_net_id.erase(removed_id)
			_structure_curse_data_signature_by_net_id.erase(removed_id)
			_host_entity_by_net_id.erase(removed_id)
			_host_entity_by_short_id.erase(str(_net_short_id(removed_id)))
			if ENABLE_REMOVED_SYNC:
				removed.append(removed_id)
				_queue_pending_reliable_removed(removed_id)
		if ENABLE_REMOVED_SYNC:
			_append_death_events_for_removed(removed)

	events = _peek_pending_battle_events(MAX_EVENTS_PER_SNAPSHOT)
	var economy_state = _build_economy_state_throttled(locator, wave_timer_state, now_msec)
	var progression_state = _build_progression_state_throttled(locator, wave_timer_state, now_msec)

	var result = {
		"msg_type": "battle_snapshot",
		"phase": "B12_delayed_death_sync",
		"tick": _tick,
		"scene_instance_id": _current_game_scene_instance_id(),
		"scene_enter_msec": _game_scene_enter_msec,
		"scene_desc": _current_scene_desc(),
		"time_msec": now_msec,
		"server_time_msec": now_msec,
		"wave": _safe_int_from_object(RunData, "current_wave", 0),
		"player_count": RunData.get_player_count(),
		"players": players,
		"entities": entities,
		"active_entity_ids": active_dynamic_net_ids.keys(),
		"wave_timer_state": wave_timer_state,
		"economy_state": economy_state,
		"progression_state": progression_state,
		"events": events,
		"removed": removed,
		"prune_missing": ENABLE_REMOVED_SYNC,
		"counts": counts
	}
	return result

func _wave_timer_state_allows_births(wave_timer_state: Dictionary) -> bool:
	if typeof(wave_timer_state) != TYPE_DICTIONARY or wave_timer_state.empty():
		return true
	if bool(wave_timer_state.get("running", false)):
		return true
	return float(wave_timer_state.get("time_left", 0.0)) > 0.05

func get_last_snapshot_message() -> Dictionary:
	return _last_snapshot


func force_fresh_snapshot_message() -> Dictionary:
	var locator = _get_runtime_locator()
	var steam = _get_steam_lobby_manager()
	if locator != null and locator.has_method("is_in_game_scene") and bool(locator.is_in_game_scene()):
		_ensure_current_game_scene_registered("force_fresh", locator, _is_game_host(), steam)
	var snapshot = build_snapshot()
	_last_snapshot = snapshot
	_last_snapshot_msec = OS.get_ticks_msec()
	return snapshot


func _build_wave_timer_state(locator: Node, now_msec: int) -> Dictionary:
	var main = locator.get_main() if locator != null and locator.has_method("get_main") else null
	if main == null:
		return {}
	var timer = main.get("_wave_timer")
	if not _is_valid_timer(timer):
		timer = main.get_node_or_null("WaveTimer")
	if not _is_valid_timer(timer):
		return {}
	var stopped = bool(timer.is_stopped())
	var paused = bool(timer.paused)
	return {
		"wave": _safe_int_from_object(RunData, "current_wave", 0),
		"wait_time": float(timer.wait_time),
		"time_left": float(timer.time_left),
		"paused": paused,
		"stopped": stopped,
		"running": not stopped and not paused and float(timer.time_left) > 0.0,
		"server_time_msec": now_msec
	}


func _is_valid_timer(value) -> bool:
	return value != null and is_instance_valid(value) and value is Timer


func _append_dynamic_entity_states(locator: Node, registry: Node, method_name: String, category: String, entity_type: int, prefix: String, sync_mode: String, now_msec: int, entities_out: Array, active_dynamic_net_ids: Dictionary, emitted_dynamic_net_ids: Dictionary) -> void:
	if locator == null or not locator.has_method(method_name):
		return

	var nodes = locator.call(method_name)
	if typeof(nodes) != TYPE_ARRAY:
		return

	for node in nodes:
		_append_dynamic_node_state(node, registry, category, entity_type, prefix, sync_mode, now_msec, entities_out, active_dynamic_net_ids, emitted_dynamic_net_ids)


func _append_dynamic_node_state(node, registry: Node, category: String, entity_type: int, prefix: String, sync_mode: String, now_msec: int, entities_out: Array, active_dynamic_net_ids: Dictionary, emitted_dynamic_net_ids: Dictionary) -> void:
	if not _is_valid_node(node):
		return

	var net_id = _get_or_assign_entity_net_id(node, registry, category, entity_type, prefix)
	if net_id == "":
		return

	active_dynamic_net_ids[net_id] = true
	_touch_dynamic_entity_tracking(node, net_id, category, true)

	var first_seen = not _birth_only_first_seen_msec.has(net_id)
	if first_seen:
		_birth_only_first_seen_msec[net_id] = now_msec
		if _should_sync_entity_curse_status(category):
			_last_entity_cursed_by_net_id[net_id] = _is_entity_cursed_authoritative(node, category)
		var full_state = _build_dynamic_entity_state_from_net_id(node, net_id, category, entity_type)
		if not full_state.empty():
			full_state["sync_mode"] = sync_mode
			_queue_pending_reliable_birth_entity(full_state)
			_store_structure_curse_data_signature_if_present(net_id, full_state)
			_birth_only_announced_net_ids[net_id] = true
			if sync_mode == SYNC_MODE_HOST_MOTION and not emitted_dynamic_net_ids.has(net_id):
				entities_out.append(full_state)
				emitted_dynamic_net_ids[net_id] = true
		return

	if _should_sync_entity_curse_status(category):
		var current_cursed = _is_entity_cursed_authoritative(node, category)
		var last_cursed_value = _last_entity_cursed_by_net_id.get(net_id, null)
		if last_cursed_value == null or bool(last_cursed_value) != current_cursed:
			_last_entity_cursed_by_net_id[net_id] = current_cursed
			var status_state = _build_dynamic_entity_state_from_net_id(node, net_id, category, entity_type)
			if not status_state.empty():
				status_state["sync_mode"] = sync_mode
				_queue_pending_reliable_birth_entity(status_state)

	if category == "structure":
		_maybe_append_structure_curse_data_update(node, net_id, category, entity_type, sync_mode)

	if sync_mode != SYNC_MODE_HOST_MOTION:
		# Known regular enemies/trees/structures are now only touched for liveness and
		# Host-side kill-claim lookup. Avoid rebuilding scene_path/stats/resource state
		# every snapshot; that work is only needed for the first reliable birth packet.
		# Status changes such as DLC curse are still sent above as reliable updates.
		return

	if emitted_dynamic_net_ids.has(net_id):
		return
	var motion_state = _build_dynamic_entity_motion_state(node, net_id, category, entity_type)
	if motion_state.empty():
		return
	motion_state["sync_mode"] = sync_mode
	entities_out.append(motion_state)
	emitted_dynamic_net_ids[net_id] = true


func _get_or_assign_entity_net_id(entity: Node, registry: Node, category: String, entity_type: int, prefix: String) -> String:
	if not _is_valid_node(entity) or registry == null:
		return ""
	if registry.has_method("get_existing_net_id"):
		var existing = str(registry.get_existing_net_id(entity))
		if existing != "":
			registry.mark_seen(existing)
			return existing

	var reserved_id = _match_reserved_spawn_for_entity(entity, category, entity_type)
	if reserved_id != "" and registry.has_method("bind_net_id"):
		var bound = str(registry.bind_net_id(entity, reserved_id, prefix))
		if bound != "":
			_consume_reserved_spawn(bound)
			registry.mark_seen(bound)
			return bound

	if registry.has_method("get_or_assign_net_id"):
		var net_id = str(registry.get_or_assign_net_id(entity, prefix))
		registry.mark_seen(net_id)
		return net_id
	return ""


func _touch_dynamic_entity_tracking(entity: Node, net_id: String, category: String, update_pos: bool) -> void:
	if net_id == "" or not _is_valid_node(entity):
		return
	if update_pos:
		_last_entity_pos_by_net_id[net_id] = _vec_to_dict(_get_global_pos(entity))
	_last_entity_category_by_net_id[net_id] = category
	_host_entity_by_net_id[net_id] = entity
	_host_entity_by_short_id[str(_net_short_id(net_id))] = entity
	_ensure_host_damage_event_connection(entity, net_id, category)

func _build_dynamic_entity_state_from_net_id(entity: Node, net_id: String, category: String, entity_type: int) -> Dictionary:
	if net_id == "" or not _is_valid_node(entity):
		return {}

	var online_drop_result = _ensure_online_drop_preroll_for_entity(entity, net_id, category)
	var current_stats = entity.get("current_stats")
	var max_stats = entity.get("max_stats")
	var type_path = _get_script_path(entity)
	var scene_path = _get_scene_path(entity)
	var stats_path = _get_resource_path(entity.get("stats"))
	var player_index = _safe_int_from_object(entity, "player_index", -1)
	var spawn_data = _find_runtime_spawn_data_for_entity(entity, category, scene_path, player_index)
	var data_path = _get_valid_spawn_data_path(spawn_data, scene_path, category + ":entity:" + str(entity.name))
	var spawn_data_state = _build_spawn_data_sync_state(spawn_data)
	var pos = _vec_to_dict(_get_global_pos(entity))
	_touch_dynamic_entity_tracking(entity, net_id, category, false)
	_last_entity_pos_by_net_id[net_id] = pos

	var result = {
		"net_id": net_id,
		"category": category,
		"entity_type": entity_type,
		"path": _safe_node_path(entity),
		"name": str(entity.name),
		"scene_path": scene_path,
		"type_path": type_path,
		"stats_path": stats_path,
		"data_path": data_path,
		"player_index": player_index,
		"pos": pos,
		"vel": _vec_to_dict(_get_velocity(entity)),
		"dead": ENABLE_DEATH_EVENT_BROADCAST and _safe_bool_from_object(entity, "dead", false),
		"health": _safe_int_from_object(current_stats, "health", -1),
		"max_health": _safe_int_from_object(max_stats, "health", -1),
		"speed": _safe_int_from_object(current_stats, "speed", -1),
		"damage": _safe_int_from_object(current_stats, "damage", -1),
		"armor": _safe_int_from_object(current_stats, "armor", -1),
		"status_flags": _build_status_flags_for_entity(entity, category)
	}
	if typeof(spawn_data_state) == TYPE_DICTIONARY and not spawn_data_state.empty():
		result["spawn_data"] = spawn_data_state
	if typeof(online_drop_result) == TYPE_DICTIONARY and not online_drop_result.empty():
		result["online_drop_result"] = online_drop_result.duplicate(true)
	return result

func _maybe_append_structure_curse_data_update(node: Node, net_id: String, category: String, entity_type: int, sync_mode: String) -> void:
	if net_id == "" or category != "structure" or not _is_valid_node(node):
		return
	var scene_path = _get_scene_path(node)
	# Known birth-only structures are checked for a late runtime curse only from
	# their actual node data. Do not scan RunData every tick for normal structures.
	var spawn_data = node.get("data")
	if not _is_runtime_spawn_data_scene_safe(spawn_data, scene_path) or not _is_spawn_data_cursed(spawn_data):
		return
	var spawn_data_state = _build_spawn_data_sync_state(spawn_data)
	if typeof(spawn_data_state) != TYPE_DICTIONARY or spawn_data_state.empty():
		return
	var signature = _make_structure_curse_data_signature(scene_path, spawn_data_state)
	if str(_structure_curse_data_signature_by_net_id.get(net_id, "")) == signature:
		return
	var state = _build_dynamic_entity_state_from_net_id(node, net_id, category, entity_type)
	if state.empty():
		return
	state["sync_mode"] = sync_mode
	_queue_pending_reliable_birth_entity(state)
	_structure_curse_data_signature_by_net_id[net_id] = signature
func _store_structure_curse_data_signature_if_present(net_id: String, state: Dictionary) -> void:
	if net_id == "" or typeof(state) != TYPE_DICTIONARY or str(state.get("category", "")) != "structure":
		return
	var spawn_data_state = state.get("spawn_data", {})
	if typeof(spawn_data_state) != TYPE_DICTIONARY or not bool(spawn_data_state.get("is_cursed", false)):
		return
	_structure_curse_data_signature_by_net_id[net_id] = _make_structure_curse_data_signature(str(state.get("scene_path", "")), spawn_data_state)


func _make_structure_curse_data_signature(scene_path: String, spawn_data_state: Dictionary) -> String:
	return scene_path + ":" + to_json(spawn_data_state)


func _find_runtime_spawn_data_path_for_entity(entity: Node, category: String, scene_path: String, player_index: int) -> String:
	if not _is_valid_node(entity):
		return ""
	var data = _find_runtime_spawn_data_for_entity(entity, category, scene_path, player_index)
	return _get_valid_spawn_data_path(data, scene_path, category + ":entity:" + str(entity.name))


func _find_runtime_spawn_data_for_entity(entity: Node, category: String, scene_path: String, player_index: int):
	# EntitySpawner.spawn_entity() needs the original StructureData/PetEffect for
	# structures and pets. Cursed variants are runtime duplicated resources, so the
	# network state must keep both the path and the cursed serialized payload.
	if not _is_valid_node(entity):
		return null
	if category != "structure" and category != "pet":
		return null

	var direct_data = entity.get("data")
	if _is_runtime_spawn_data_scene_safe(direct_data, scene_path):
		var direct_path = _get_valid_spawn_data_path(direct_data, scene_path, category + ":entity:" + str(entity.name))
		if direct_path != "" or _is_spawn_data_cursed(direct_data):
			return direct_data

	if player_index < 0:
		return null

	if category == "structure":
		return _find_spawn_data_in_player_effects(player_index, Keys.structures_hash, scene_path)

	if category == "pet":
		var player_effects = RunData.get_player_effects(player_index) if RunData.has_method("get_player_effects") else {}
		if typeof(player_effects) == TYPE_DICTIONARY and player_effects.has(Keys.stat_pets_hash):
			return _find_spawn_data_in_player_effects(player_index, Keys.stat_pets_hash, scene_path)

	return null


func _find_spawn_data_path_in_player_effects(player_index: int, effect_hash: int, scene_path: String) -> String:
	var data = _find_spawn_data_in_player_effects(player_index, effect_hash, scene_path)
	return _get_valid_spawn_data_path(data, scene_path, "player_effect:" + str(player_index) + ":" + str(effect_hash))


func _find_spawn_data_in_player_effects(player_index: int, effect_hash: int, scene_path: String):
	if not RunData.has_method("get_player_effect"):
		return null
	var values = RunData.get_player_effect(effect_hash, player_index)
	return _find_spawn_data_in_array(values, scene_path)


func _find_spawn_data_path_in_array(values, scene_path: String) -> String:
	var data = _find_spawn_data_in_array(values, scene_path)
	return _get_valid_spawn_data_path(data, scene_path, "array")


func _find_spawn_data_in_array(values, scene_path: String):
	if typeof(values) != TYPE_ARRAY:
		return null
	for data in values:
		if data == null:
			continue
		var data_path = _get_resource_path(data)
		if data_path == "":
			continue
		var data_scene_path = _get_spawn_data_scene_path(data)
		if scene_path != "" and data_scene_path == scene_path:
			return data
	# Do not fall back to an arbitrary StructureEffect/PetEffect from the player
	# array. A stale pooled node can expose a scene from one structure and data from
	# another; sending that mismatched pair lets clients instantiate e.g.
	# landmine.tscn with rocket_turret_effect_1.tres, which crashes vanilla scripts.
	return null


func _is_runtime_spawn_data_scene_safe(data, scene_path: String) -> bool:
	if data == null or not (data is Resource):
		return false
	var data_scene_path = _get_spawn_data_scene_path(data)
	return scene_path == "" or data_scene_path == "" or data_scene_path == scene_path


func _is_spawn_data_cursed(data) -> bool:
	if data == null or not (data is Object):
		return false
	return data.get("is_cursed") != null and bool(data.get("is_cursed"))


func _build_spawn_data_sync_state(data) -> Dictionary:
	if data == null or not (data is Resource):
		return {}
	var result = {
		"resource_path": _get_resource_path(data)
	}
	if data.get("value") != null:
		result["value"] = int(data.get("value"))
	if data.get("is_cursed") != null:
		result["is_cursed"] = bool(data.get("is_cursed"))
	if data.get("curse_factor") != null:
		result["curse_factor"] = float(data.get("curse_factor"))
	if (bool(result.get("is_cursed", false)) or (data is WeaponData)) and data.has_method("serialize"):
		var serialized = data.serialize()
		if typeof(serialized) == TYPE_DICTIONARY and not serialized.empty():
			result["serialized_data"] = serialized
	return result

func _get_spawn_data_scene_path(data) -> String:
	if data == null or not (data is Object):
		return ""
	var scene = data.get("scene")
	if scene == null:
		return ""
	return str(scene.resource_path)


func _get_valid_spawn_data_path(data, scene_path: String, context: String) -> String:
	var data_path = _get_resource_path(data)
	if data_path == "":
		return ""
	var data_scene_path = _get_spawn_data_scene_path(data)
	if scene_path != "" and data_scene_path != "" and data_scene_path != scene_path:
		return ""
	return data_path


func _build_dynamic_entity_motion_state(entity: Node, net_id: String, category: String, entity_type: int) -> Dictionary:
	if net_id == "" or not _is_valid_node(entity):
		return {}
	var current_stats = entity.get("current_stats")
	var max_stats = entity.get("max_stats")
	var pos = _vec_to_dict(_get_global_pos(entity))
	_touch_dynamic_entity_tracking(entity, net_id, category, false)
	_last_entity_pos_by_net_id[net_id] = pos
	return {
		"net_id": net_id,
		"category": category,
		"entity_type": entity_type,
		"player_index": _safe_int_from_object(entity, "player_index", -1),
		"pos": pos,
		"vel": _vec_to_dict(_get_velocity(entity)),
		"dead": ENABLE_DEATH_EVENT_BROADCAST and _safe_bool_from_object(entity, "dead", false),
		"health": _safe_int_from_object(current_stats, "health", -1),
		"max_health": _safe_int_from_object(max_stats, "health", -1),
		"status_flags": _build_status_flags_for_entity(entity, category)
	}


func _ensure_spawner_signal_connections(locator: Node) -> void:
	if locator == null or not locator.has_method("get_entity_spawner"):
		return
	var spawner = locator.get_entity_spawner()
	if not _is_valid_node(spawner):
		return
	var instance_key = str(spawner.get_instance_id())
	if _connected_spawner_instance_id == instance_key:
		return
	_connected_spawner_instance_id = instance_key
	_connect_spawner_signal_if_exists(spawner, "enemy_spawned", "_on_spawner_enemy_spawned")
	_connect_spawner_signal_if_exists(spawner, "enemy_respawned", "_on_spawner_enemy_respawned")
	_connect_spawner_signal_if_exists(spawner, "neutral_spawned", "_on_spawner_neutral_spawned")
	_connect_spawner_signal_if_exists(spawner, "neutral_respawned", "_on_spawner_neutral_respawned")
	_connect_spawner_signal_if_exists(spawner, "structure_spawned", "_on_spawner_structure_spawned")
	_connect_spawner_signal_if_exists(spawner, "structure_respawned", "_on_spawner_structure_respawned")
	_connect_spawner_signal_if_exists(spawner, "pet_spawned", "_on_spawner_pet_spawned")


func _connect_spawner_signal_if_exists(spawner: Node, signal_name: String, method_name: String) -> void:
	if not spawner.has_signal(signal_name):
		return
	if spawner.is_connected(signal_name, self, method_name):
		return
	var err = spawner.connect(signal_name, self, method_name)
	if err != OK:
		pass


func _on_spawner_enemy_spawned(entity) -> void:
	_queue_signal_spawn_node(entity, "")


func _on_spawner_enemy_respawned(entity) -> void:
	_queue_signal_spawn_node(entity, "enemy")


func _on_spawner_neutral_spawned(entity) -> void:
	_queue_signal_spawn_node(entity, "neutral")


func _on_spawner_neutral_respawned(entity) -> void:
	_queue_signal_spawn_node(entity, "neutral")


func _on_spawner_structure_spawned(entity) -> void:
	_queue_signal_spawn_node(entity, "structure")


func _on_spawner_structure_respawned(entity) -> void:
	_queue_signal_spawn_node(entity, "structure")


func _on_spawner_pet_spawned(entity) -> void:
	_queue_signal_spawn_node(entity, "pet")


func _queue_signal_spawn_node(entity, hint_category: String) -> void:
	if not _is_valid_node(entity):
		return
	var key = str(entity.get_instance_id())
	if _pending_signal_spawn_instance_ids.has(key):
		return
	_pending_signal_spawn_instance_ids[key] = true
	_pending_signal_spawn_nodes.append({"node": entity, "hint_category": hint_category})


func _process_pending_signal_spawn_nodes(locator: Node, registry: Node, now_msec: int, entities_out: Array, active_dynamic_net_ids: Dictionary, emitted_dynamic_net_ids: Dictionary) -> void:
	if _pending_signal_spawn_nodes.empty():
		return
	var pending = _pending_signal_spawn_nodes
	_pending_signal_spawn_nodes = []
	_pending_signal_spawn_instance_ids.clear()
	for info in pending:
		if typeof(info) != TYPE_DICTIONARY:
			continue
		var node = info.get("node")
		if not _is_valid_node(node):
			continue
		var hint = str(info.get("hint_category", ""))
		var category = _infer_dynamic_category(locator, node, hint)
		if category == "":
			continue
		var entity_type = _entity_type_from_category(category)
		var prefix = _prefix_from_category(category)
		var sync_mode = _sync_mode_from_category(category)
		_append_dynamic_node_state(node, registry, category, entity_type, prefix, sync_mode, now_msec, entities_out, active_dynamic_net_ids, emitted_dynamic_net_ids)


func _infer_dynamic_category(locator: Node, node: Node, hint_category: String) -> String:
	if hint_category == "neutral" or hint_category == "structure" or hint_category == "pet":
		return hint_category
	if locator != null:
		if locator.has_method("get_bosses") and _array_has_node(locator.get_bosses(), node):
			return "boss"
		if locator.has_method("get_enemy_nodes") and _array_has_node(locator.get_enemy_nodes(), node):
			return "enemy"
		if locator.has_method("get_neutrals") and _array_has_node(locator.get_neutrals(), node):
			return "neutral"
		if locator.has_method("get_structures") and _array_has_node(locator.get_structures(), node):
			return "structure"
		if locator.has_method("get_pets") and _array_has_node(locator.get_pets(), node):
			return "pet"
	return hint_category


func _array_has_node(value, node: Node) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	for candidate in value:
		if candidate == node:
			return true
	return false


func _build_player_state(player: Node, fallback_index: int, registry: Node) -> Dictionary:
	var player_index = fallback_index
	var raw_player_index = player.get("player_index")
	if raw_player_index != null:
		player_index = int(raw_player_index)

	var net_id = "player_%s" % str(player_index)
	if registry != null and registry.has_method("get_player_net_id"):
		net_id = str(registry.get_player_net_id(player_index))
		registry.mark_seen(net_id)

	var current_stats = player.get("current_stats")
	var max_stats = player.get("max_stats")
	var hp = _safe_int_from_object(current_stats, "health", -1)
	var dead_state = _safe_bool_from_object(player, "dead", false)
	if hp >= 0 and hp <= 0:
		# A Player can be sampled after HP reached zero but before its vanilla dead flag is
		# visible to this autoload. For network state, HP<=0 is already a death state.
		dead_state = true

	return {
		"net_id": net_id,
		"player_index": player_index,
		"path": _safe_node_path(player),
		"scene_path": _get_scene_path(player),
		"pos": _vec_to_dict(_get_global_pos(player)),
		"vel": _vec_to_dict(_get_velocity(player)),
		"dead": ENABLE_REMOTE_PLAYER_DEATH_SYNC and dead_state,
		"health": hp,
		"max_health": _safe_int_from_object(max_stats, "health", -1),
		# Tardigrade / hit-protection is runtime-only on Player, not in current_stats.
		# Sync the remaining charges so remote HP bars and UI icons stop staying purple
		# after another player's protection has already been consumed.
		"hit_protection": _safe_int_from_object(player, "_hit_protection", 0),
		"speed": _safe_int_from_object(current_stats, "speed", -1),
		"armor": _safe_int_from_object(current_stats, "armor", -1),
		"dodge": _safe_int_from_object(current_stats, "dodge", -1)
	}


func _build_birth_state(birth: Node, registry: Node, now_msec: int) -> Dictionary:
	var net_id = ""
	if registry != null and registry.has_method("get_or_assign_net_id"):
		net_id = str(registry.get_or_assign_net_id(birth, "birth"))
		registry.mark_seen(net_id)

	if net_id == "":
		return {}

	var scene_path = ""
	var scene = birth.get("scene")
	if scene != null:
		scene_path = str(scene.resource_path)

	var entity_type = _safe_int_from_object(birth, "type", -1)
	var spawn_category = _category_from_entity_type(entity_type)
	var spawn_net_id = _get_or_create_reserved_spawn_net_id(net_id, registry, spawn_category, entity_type, scene_path, _get_global_pos(birth), now_msec)
	var spawn_data = birth.get("data")
	var data_path = _get_valid_spawn_data_path(spawn_data, scene_path, "birth:" + spawn_category + ":" + net_id)
	var spawn_data_state = _build_spawn_data_sync_state(spawn_data)

	var result = {
		"net_id": net_id,
		"category": "birth",
		"entity_type": entity_type,
		"path": _safe_node_path(birth),
		"scene_path": scene_path,
		"data_path": data_path,
		"pos": _vec_to_dict(_get_global_pos(birth)),
		"dead": false,
		"player_index": _safe_int_from_object(birth, "player_index", -1),
		"time_before_spawn": _safe_float_from_object(birth, "time_before_spawn", 60.0),
		"current_time_before_spawn": _safe_float_from_object(birth, "_current_time_before_spawn", 60.0),
		"server_time_msec": now_msec,
		"spawn_net_id": spawn_net_id,
		"entity_net_id": spawn_net_id,
		"spawn_category": spawn_category,
		"spawn_sync_mode": _sync_mode_from_category(spawn_category),
		"spawn_scene_path": scene_path
	}
	if typeof(spawn_data_state) == TYPE_DICTIONARY and not spawn_data_state.empty():
		result["spawn_data"] = spawn_data_state
	return result

func _get_or_create_reserved_spawn_net_id(birth_net_id: String, registry: Node, category: String, entity_type: int, scene_path: String, pos: Vector2, now_msec: int) -> String:
	if birth_net_id == "" or category == "":
		return ""
	if _reserved_spawn_by_birth_id.has(birth_net_id):
		var existing = _reserved_spawn_by_birth_id[birth_net_id]
		if typeof(existing) == TYPE_DICTIONARY:
			existing["category"] = category
			existing["entity_type"] = entity_type
			existing["scene_path"] = scene_path
			existing["pos"] = pos
			existing["updated_msec"] = now_msec
			_reserved_spawn_by_birth_id[birth_net_id] = existing
			return str(existing.get("spawn_net_id", ""))

	var prefix = _prefix_from_category(category)
	var spawn_net_id = ""
	if registry != null and registry.has_method("reserve_net_id"):
		spawn_net_id = str(registry.reserve_net_id(prefix))
	else:
		spawn_net_id = "%s_%s" % [prefix, birth_net_id]
	var info = {
		"birth_net_id": birth_net_id,
		"spawn_net_id": spawn_net_id,
		"category": category,
		"entity_type": entity_type,
		"scene_path": scene_path,
		"pos": pos,
		"created_msec": now_msec,
		"updated_msec": now_msec
	}
	_reserved_spawn_by_birth_id[birth_net_id] = info
	_reserved_birth_id_by_spawn_net_id[spawn_net_id] = birth_net_id
	return spawn_net_id


func _match_reserved_spawn_for_entity(entity: Node, category: String, entity_type: int) -> String:
	if _reserved_spawn_by_birth_id.empty() or not _is_valid_node(entity):
		return ""
	var now_msec = OS.get_ticks_msec()
	var scene_path = _get_scene_path(entity)
	var pos = _get_global_pos(entity)
	var best_id = ""
	var best_dist = RESERVED_BIRTH_MATCH_RADIUS * RESERVED_BIRTH_MATCH_RADIUS
	for birth_id_value in _reserved_spawn_by_birth_id.keys():
		var birth_id = str(birth_id_value)
		var info = _reserved_spawn_by_birth_id[birth_id]
		if typeof(info) != TYPE_DICTIONARY:
			continue
		if now_msec - int(info.get("created_msec", now_msec)) > RESERVED_BIRTH_TTL_MSEC:
			continue
		if str(info.get("category", "")) != category:
			continue
		if int(info.get("entity_type", -1)) != entity_type:
			continue
		var reserved_scene_path = str(info.get("scene_path", ""))
		if reserved_scene_path != "" and scene_path != "" and reserved_scene_path != scene_path:
			continue
		var reserved_pos = info.get("pos", Vector2.ZERO)
		if typeof(reserved_pos) != TYPE_VECTOR2:
			reserved_pos = _dict_to_vec2(reserved_pos)
		var dist = pos.distance_squared_to(reserved_pos)
		if dist <= best_dist:
			best_dist = dist
			best_id = str(info.get("spawn_net_id", ""))
	return best_id


func _consume_reserved_spawn(spawn_net_id: String) -> void:
	if spawn_net_id == "":
		return
	var birth_id = str(_reserved_birth_id_by_spawn_net_id.get(spawn_net_id, ""))
	if birth_id != "":
		_reserved_spawn_by_birth_id.erase(birth_id)
	_reserved_birth_id_by_spawn_net_id.erase(spawn_net_id)


func _ensure_online_drop_preroll_for_entity(entity: Node, net_id: String, category: String) -> Dictionary:
	if not _is_game_host() or not _is_online_session_active():
		return {}
	if entity == null or not is_instance_valid(entity):
		return {}
	if category != "enemy" and category != "boss" and category != "neutral":
		return {}
	var main = _get_current_main_scene()
	if main == null or not main.has_method("brotato_online_preroll_drop_for_unit"):
		return {}
	var result = main.call("brotato_online_preroll_drop_for_unit", entity, net_id, category)
	if typeof(result) == TYPE_DICTIONARY:
		return result
	return {}


func _get_current_main_scene() -> Node:
	var locator = _get_runtime_locator()
	if locator != null and locator.has_method("get_main"):
		var main = locator.get_main()
		if main != null and is_instance_valid(main):
			return main
	var tree = get_tree()
	if tree != null and tree.current_scene != null and is_instance_valid(tree.current_scene):
		return tree.current_scene
	return null


func _category_from_entity_type(entity_type: int) -> String:
	if entity_type == _entity_type_enemy():
		return "enemy"
	if entity_type == _entity_type_boss():
		return "boss"
	if entity_type == _entity_type_neutral():
		return "neutral"
	if entity_type == _entity_type_structure():
		return "structure"
	if entity_type == _entity_type_pet():
		return "pet"
	return ""


func _entity_type_from_category(category: String) -> int:
	match category:
		"enemy":
			return _entity_type_enemy()
		"boss":
			return _entity_type_boss()
		"neutral":
			return _entity_type_neutral()
		"structure":
			return _entity_type_structure()
		"pet":
			return _entity_type_pet()
		_:
			return -1


func _prefix_from_category(category: String) -> String:
	if category == "":
		return "entity"
	return category


func _sync_mode_from_category(category: String) -> String:
	if category == "boss" or category == "pet":
		return SYNC_MODE_HOST_MOTION
	return SYNC_MODE_BIRTH_ONLY


func _ensure_host_damage_event_connection(entity: Node, net_id: String, category: String) -> void:
	if not ENABLE_DAMAGE_HIT_EVENTS:
		return
	if not _is_valid_node(entity):
		return
	if not entity.has_signal("took_damage"):
		return
	if category != "enemy" and category != "boss" and category != "neutral":
		return
	var key = str(entity.get_instance_id())
	if _damage_signal_connected_ids.has(key):
		return
	if entity.is_connected("took_damage", self, "_on_host_unit_took_damage"):
		_damage_signal_connected_ids[key] = net_id
		return
	var err = entity.connect("took_damage", self, "_on_host_unit_took_damage", [net_id, category])
	if err == OK:
		_damage_signal_connected_ids[key] = net_id
	else:
		pass


func _on_host_unit_took_damage(unit, value: int, _knockback_direction: Vector2, is_crit: bool, is_dodge: bool, is_protected: bool, armor_did_something: bool, args, hit_type: int, is_one_shot: bool, net_id: String, category: String) -> void:
	if not ENABLE_DAMAGE_HIT_EVENTS:
		return
	if not _is_game_host():
		return
	if unit == null or not is_instance_valid(unit):
		return
	if value <= 0 and not is_dodge and not is_protected:
		return

	var from_player_index = -1
	if args != null:
		var raw_player_index = args.get("from_player_index")
		if raw_player_index != null:
			from_player_index = int(raw_player_index)

	var now_msec = OS.get_ticks_msec()
	var pos = _vec_to_dict(_get_global_pos(unit))
	var damage_event = {
		"event_type": "damage_number",
		"event_id": _next_battle_event_id,
		"tick": _tick,
		"time_msec": now_msec,
		"server_time_msec": now_msec,
		"target_net_id": net_id,
		"category": category,
		"pos": pos,
		"value": int(value),
		"from_player_index": from_player_index,
		"crit": bool(is_crit),
		"dodge": bool(is_dodge),
		"protected": bool(is_protected),
		"armor": bool(armor_did_something),
		"one_shot": bool(is_one_shot),
		"hit_type": int(hit_type)
	}
	_next_battle_event_id += 1
	_queue_battle_event(damage_event)

	var fx_type = "normal"
	if bool(is_crit):
		fx_type = "crit"
	var hit_event = {
		"event_type": "hit_fx",
		"event_id": _next_battle_event_id,
		"tick": _tick,
		"time_msec": now_msec,
		"server_time_msec": now_msec,
		"target_net_id": net_id,
		"category": category,
		"pos": pos,
		"fx_type": fx_type,
		"hit_type": int(hit_type)
	}
	_next_battle_event_id += 1
	_queue_battle_event(hit_event)

func _build_economy_state_throttled(locator: Node, wave_timer_state: Dictionary, now_msec: int) -> Dictionary:
	var running = typeof(wave_timer_state) == TYPE_DICTIONARY and bool(wave_timer_state.get("running", false))
	var interval = 200 if running else 80
	if not _cached_economy_state.empty() and now_msec - _last_economy_snapshot_msec < interval:
		return {}
	_last_economy_snapshot_msec = now_msec
	_cached_economy_state = _build_economy_state(locator)
	return _cached_economy_state


func _build_progression_state_throttled(locator: Node, wave_timer_state: Dictionary, now_msec: int) -> Dictionary:
	var running = typeof(wave_timer_state) == TYPE_DICTIONARY and bool(wave_timer_state.get("running", false))
	if _is_host_retry_or_failed_terminal_state(locator):
		# While the RetryWave failure screen is active, progression state must not be
		# serialized into battle snapshots. A stale progression snapshot from the failed
		# wave can otherwise be consumed by the client immediately after retry reload and
		# make the retry wave jump to the upgrade/shop flow.
		_cached_progression_state = {}
		_last_forced_stopped_progression_key = ""
		return {}

	# The first stopped-wave packet is the handoff from battle into upgrade/box UI.
	# Force a full queue snapshot there instead of letting the previous 700/160 ms
	# throttled combat packet hide the Host's final item-box/upgrade queues.
	if not running:
		var wave_key = str(_current_game_scene_instance_id()) + ":" + str(_safe_int_from_object(RunData, "current_wave", 0))
		if _last_forced_stopped_progression_key != wave_key:
			_last_forced_stopped_progression_key = wave_key
			_last_progression_snapshot_msec = now_msec
			_cached_progression_state = _build_progression_state(locator, true)
			return _cached_progression_state

	# During combat only the Host-authoritative pending queues are sent. Visible
	# upgrade/card UI is still reserved for stopped-wave snapshots.
	var interval = 700 if running else 160
	if not _cached_progression_state.empty() and now_msec - _last_progression_snapshot_msec < interval:
		return {}
	_last_progression_snapshot_msec = now_msec
	_cached_progression_state = _build_progression_state(locator, not running)
	return _cached_progression_state


func _is_host_retry_or_failed_terminal_state(locator: Node) -> bool:
	var main = locator.get_main() if locator != null and locator.has_method("get_main") else _get_main_scene()
	if main == null:
		return false
	var retry_wave = _safe_get_from_object(main, "_retry_wave", null)
	if retry_wave != null and is_instance_valid(retry_wave) and retry_wave is CanvasItem and bool(retry_wave.visible):
		return true
	# Failure retry uses _is_wave_failed/_is_run_lost internally, but it must not be
	# treated like a successful wave-end progression page.
	if bool(_safe_get_from_object(main, "_is_wave_failed", false)):
		return true
	return false


func _build_progression_state(locator: Node, include_visible_options: bool = true) -> Dictionary:
	var main = locator.get_main() if locator != null and locator.has_method("get_main") else _get_main_scene()
	if main == null:
		return {}
	var player_count = 0
	if RunData != null and RunData.has_method("get_player_count"):
		player_count = int(RunData.get_player_count())
	var players = []
	for player_index in range(player_count):
		var box_counts = _count_pending_consumables_for_player(main, player_index)
		var player_state = {
			"player_index": player_index,
			"pending_upgrade_count": _count_pending_upgrades_for_player(main, player_index),
			"pending_item_box_count": int(box_counts.get("item_box", 0)),
			"pending_legendary_item_box_count": int(box_counts.get("legendary_item_box", 0)),
			"pending_other_consumable_count": int(box_counts.get("other", 0)),
			"visible_option": {"mode": "none"}
		}
		if include_visible_options:
			# Wave-end/upgrade-page packets still carry the real queue entries and visible
			# option data. Combat packets only carry counters so clients can repair the HUD
			# without rebuilding Host queues or serializing every pending item resource.
			player_state["pending_upgrades"] = _serialize_pending_upgrades_for_player(main, player_index)
			player_state["pending_consumables"] = _serialize_pending_consumables_for_player(main, player_index)
			player_state["visible_option"] = _build_visible_progression_option(main, player_index)
		players.append(player_state)
	return {
		"server_time_msec": OS.get_ticks_msec(),
		"wave": _safe_int_from_object(RunData, "current_wave", 0),
		"players": players
	}


func _count_pending_upgrades_for_player(main: Node, player_index: int) -> int:
	var all = main.get("_upgrades_to_process")
	if typeof(all) != TYPE_ARRAY or player_index < 0 or player_index >= all.size():
		return 0
	var queue = all[player_index]
	if typeof(queue) != TYPE_ARRAY:
		return 0
	return queue.size()


func _count_pending_consumables_for_player(main: Node, player_index: int) -> Dictionary:
	var counts = {"item_box": 0, "legendary_item_box": 0, "other": 0}
	var all = main.get("_consumables_to_process")
	if typeof(all) != TYPE_ARRAY or player_index < 0 or player_index >= all.size():
		return counts
	var queue = all[player_index]
	if typeof(queue) != TYPE_ARRAY:
		return counts
	for consumable_to_process in queue:
		var data = _safe_get_from_object(consumable_to_process, "consumable_data", null)
		var kind = _get_consumable_kind(data)
		if kind == "legendary_item_box":
			counts["legendary_item_box"] = int(counts["legendary_item_box"]) + 1
		elif kind == "item_box":
			counts["item_box"] = int(counts["item_box"]) + 1
		else:
			counts["other"] = int(counts["other"]) + 1
	return counts


func _serialize_pending_upgrades_for_player(main: Node, player_index: int) -> Array:
	var result = []
	var all = main.get("_upgrades_to_process")
	if typeof(all) != TYPE_ARRAY or player_index < 0 or player_index >= all.size():
		return result
	var queue = all[player_index]
	if typeof(queue) != TYPE_ARRAY:
		return result
	for upgrade_to_process in queue:
		result.append({
			"level": int(_safe_get_from_object(upgrade_to_process, "level", 0)),
			"player_index": int(_safe_get_from_object(upgrade_to_process, "player_index", player_index))
		})
	return result


func _serialize_pending_consumables_for_player(main: Node, player_index: int) -> Array:
	var result = []
	var all = main.get("_consumables_to_process")
	if typeof(all) != TYPE_ARRAY or player_index < 0 or player_index >= all.size():
		return result
	var queue = all[player_index]
	if typeof(queue) != TYPE_ARRAY:
		return result
	for consumable_to_process in queue:
		var data = _safe_get_from_object(consumable_to_process, "consumable_data", null)
		var data_state = _serialize_item_parent_data(data)
		result.append({
			"player_index": int(_safe_get_from_object(consumable_to_process, "player_index", player_index)),
			"consumable_kind": str(data_state.get("consumable_kind", "consumable")),
			"consumable_data": data_state
		})
	return result


func _build_visible_progression_option(main: Node, player_index: int) -> Dictionary:
	var ui = main.get("_coop_upgrades_ui") if RunData != null and bool(RunData.get("is_coop_run")) else main.get("_upgrades_ui")
	if not _is_valid_node(ui):
		return {"mode": "none"}
	if ui is CanvasItem and not ui.visible:
		return {"mode": "hidden"}
	var choosing = ui.get("_player_is_choosing")
	if typeof(choosing) == TYPE_ARRAY and player_index < choosing.size() and not bool(choosing[player_index]):
		return {"mode": "idle"}
	var container = null
	if ui.has_method("_get_player_container"):
		container = ui._get_player_container(player_index)
	if not _is_valid_node(container):
		return {"mode": "none"}
	var item_container = container.get("_items_container")
	var upgrades_container = container.get("_upgrades_container")
	if _is_canvas_visible(item_container):
		return {
			"mode": "item_box",
			"player_index": player_index,
			"item_data": _serialize_item_parent_data(container.get("_item_data")),
			"consumable_data": _serialize_item_parent_data(container.get("_consumable_data"))
		}
	if _is_canvas_visible(upgrades_container):
		var upgrades = []
		var upgrade_uis = []
		if container.has_method("_get_upgrade_uis"):
			upgrade_uis = container._get_upgrade_uis()
		for upgrade_ui in upgrade_uis:
			if not _is_valid_node(upgrade_ui):
				continue
			if upgrade_ui is CanvasItem and not upgrade_ui.visible:
				continue
			upgrades.append(_serialize_item_parent_data(upgrade_ui.get("upgrade_data")))
		return {
			"mode": "upgrade",
			"player_index": player_index,
			"level": int(_safe_get_from_object(container, "_level", 0)),
			"reroll_price": int(_safe_get_from_object(container, "_reroll_price", 0)),
			"reroll_count": int(_safe_get_from_object(container, "_reroll_count", 0)),
			"reroll_discount": int(_safe_get_from_object(container, "_reroll_discount", 0)),
			"upgrades": upgrades
		}
	return {"mode": "none"}


func _serialize_item_parent_data(data) -> Dictionary:
	if data == null:
		return {}
	var data_type = "item"
	if data is WeaponData:
		data_type = "weapon"
	elif data is UpgradeData:
		data_type = "upgrade"
	elif data is ConsumableData:
		data_type = "consumable"
	var result = {
		"type": data_type,
		"my_id": str(_safe_get_from_object(data, "my_id", "")),
		"my_id_hash": int(_safe_get_from_object(data, "my_id_hash", Keys.empty_hash)),
		"resource_path": _get_resource_path(data),
		"value": int(_safe_get_from_object(data, "value", 0)),
		"tier": int(_safe_get_from_object(data, "tier", -1)),
		"is_cursed": bool(_safe_get_from_object(data, "is_cursed", false)),
		"curse_factor": float(_safe_get_from_object(data, "curse_factor", 0.0))
	}
	# Cursed entries are runtime duplicates with boosted effects; weapons can also
	# carry runtime-mutated stats/effects after shop choices. Keep the full payload so
	# clients do not reload the base resource and lose those mutations.
	if bool(result["is_cursed"]) and data.has_method("serialize"):
		result["serialized_data"] = data.serialize()
	if data is WeaponData:
		result["weapon_id"] = str(_safe_get_from_object(data, "weapon_id", ""))
		result["weapon_id_hash"] = int(_safe_get_from_object(data, "weapon_id_hash", Keys.empty_hash))
		if data.has_method("serialize"):
			result["serialized_data"] = data.serialize()
	if data is UpgradeData:
		result["upgrade_id"] = str(_safe_get_from_object(data, "upgrade_id", ""))
		result["upgrade_id_hash"] = int(_safe_get_from_object(data, "upgrade_id_hash", Keys.empty_hash))
	if data is ConsumableData:
		result["consumable_kind"] = _get_consumable_kind(data)
	return result


func _get_consumable_kind(data) -> String:
	if data == null:
		return ""
	var id_hash = int(_safe_get_from_object(data, "my_id_hash", Keys.empty_hash))
	var my_id = str(_safe_get_from_object(data, "my_id", ""))
	if id_hash == int(Keys.consumable_legendary_item_box_hash) or my_id == "consumable_legendary_item_box":
		return "legendary_item_box"
	if id_hash == int(Keys.consumable_item_box_hash) or my_id == "consumable_item_box":
		return "item_box"
	return "consumable"


func _safe_get_from_object(obj, property_name: String, fallback):
	if obj == null:
		return fallback
	var value = obj.get(property_name)
	if value == null:
		return fallback
	return value


func _is_canvas_visible(node) -> bool:
	return node != null and is_instance_valid(node) and node is CanvasItem and bool(node.visible)

func _build_economy_state(locator: Node) -> Dictionary:
	var player_states = []
	var player_count = 0
	if RunData != null and RunData.has_method("get_player_count"):
		player_count = int(RunData.get_player_count())
	var player_nodes = []
	if locator != null and locator.has_method("get_players"):
		player_nodes = locator.get_players()
	for i in range(player_count):
		var hp = -1
		var max_hp = -1
		if typeof(player_nodes) == TYPE_ARRAY and i < player_nodes.size():
			var player = player_nodes[i]
			if _is_valid_node(player):
				var current_stats = player.get("current_stats")
				var max_stats = player.get("max_stats")
				if current_stats != null:
					hp = _safe_int_from_object(current_stats, "health", hp)
				if max_stats != null:
					max_hp = _safe_int_from_object(max_stats, "health", max_hp)
		var level = 0
		var xp = 0.0
		var next_xp = 0.0
		var gold = 0
		if RunData.has_method("get_player_level"):
			level = int(RunData.get_player_level(i))
		if RunData.has_method("get_player_xp"):
			xp = float(RunData.get_player_xp(i))
		if RunData.has_method("get_next_level_xp_needed"):
			next_xp = float(RunData.get_next_level_xp_needed(i))
		if RunData.has_method("get_player_gold"):
			gold = int(RunData.get_player_gold(i))
		var dead_state = false
		if hp >= 0 and hp <= 0:
			dead_state = true
		elif typeof(player_nodes) == TYPE_ARRAY and i < player_nodes.size() and _is_valid_node(player_nodes[i]):
			dead_state = _safe_bool_from_object(player_nodes[i], "dead", false)
		player_states.append({
			"player_index": i,
			"materials": gold,
			"gold": gold,
			"xp": xp,
			"level": level,
			"next_level_xp": next_xp,
			"hp": hp,
			"max_hp": max_hp,
			"dead": ENABLE_REMOTE_PLAYER_DEATH_SYNC and dead_state
		})
	return {
		"server_time_msec": OS.get_ticks_msec(),
		"players": player_states
	}


func apply_entity_kill_claim(from_steam_id: String, message: Dictionary) -> void:
	if not _is_game_host():
		return
	var net_id = str(message.get("net_id", ""))
	if net_id == "":
		return
	var target = _host_entity_by_net_id.get(net_id, null)
	if not _is_valid_node(target):
		return
	if bool(target.get("dead")):
		return
	var category = str(_last_entity_category_by_net_id.get(net_id, message.get("category", "")))
	if not ENABLE_DEATH_REPORT_APPLY and not (ENABLE_BOSS_ELITE_DEATH_REPORT_APPLY and (category == "boss" or category == "elite")):
		return
	var player_index = int(message.get("player_index", -1))
	if player_index < 0:
		player_index = _get_player_index_for_steam_id(from_steam_id)
	var pos = _dict_to_vec2(message.get("pos", _last_entity_pos_by_net_id.get(net_id, _vec_to_dict(_get_global_pos(target)))))
	var damage = 1
	var current_stats = target.get("current_stats")
	if current_stats != null:
		damage = max(1, int(current_stats.health))
		current_stats.health = 0
		if target.has_signal("health_updated"):
			var max_stats = target.get("max_stats")
			var max_hp = int(max_stats.health) if max_stats != null else int(current_stats.health)
			target.emit_signal("health_updated", target, int(current_stats.health), max_hp)
	_queue_death_event_once(net_id, category, pos, "client_boss_elite_kill_claim", player_index)
	if target.has_method("die"):
		target.die(_make_remote_kill_die_args(player_index, damage))
	else:
		target.queue_free()


func apply_boss_damage_report(from_steam_id: String, message: Dictionary) -> void:
	if not (ENABLE_DEATH_REPORT_APPLY or ENABLE_BOSS_ONE_SHOT_REPORT_APPLY):
		return
	if not _is_game_host():
		return
	var reports = message.get("reports", [])
	if typeof(reports) != TYPE_ARRAY:
		return
	var player_index = int(message.get("player_index", -1))
	if player_index < 0:
		player_index = _get_player_index_for_steam_id(from_steam_id)
	var applied = 0
	var total_damage = 0
	for report in reports:
		if typeof(report) != TYPE_DICTIONARY:
			continue
		var net_id = str(report.get("net_id", ""))
		var damage = int(report.get("damage", 0))
		var is_one_shot = bool(report.get("one_shot", false))
		# While broad death-report application is disabled, only accept the explicit
		# one-shot boss path. This prevents normal client damage from being applied twice.
		if not ENABLE_DEATH_REPORT_APPLY and not is_one_shot:
			continue
		if net_id == "" or damage <= 0:
			continue
		var target = _host_entity_by_net_id.get(net_id, null)
		if not _is_valid_node(target) or bool(target.get("dead")):
			continue
		var current_stats = target.get("current_stats")
		if current_stats != null:
			if is_one_shot:
				damage = max(damage, int(current_stats.health))
			current_stats.health = max(0, int(current_stats.health) - damage)
			if target.has_signal("health_updated"):
				var max_stats = target.get("max_stats")
				var max_hp = int(max_stats.health) if max_stats != null else int(current_stats.health)
				target.emit_signal("health_updated", target, int(current_stats.health), max_hp)
			if int(current_stats.health) <= 0:
				_queue_death_event_once(net_id, str(_last_entity_category_by_net_id.get(net_id, "boss")), _get_global_pos(target), "boss_one_shot_report" if is_one_shot else "boss_damage_report", player_index)
				if target.has_method("die"):
					target.die(_make_remote_kill_die_args(player_index, damage))
			applied += 1
			total_damage += damage
	if applied > 0:
		pass


func _make_remote_kill_die_args(player_index: int, damage: int):
	var die_args = Entity.DieArgs.new()
	die_args.enemy_killed_by_player = true
	die_args.killed_by_player_index = player_index
	die_args.killing_blow_dmg_value = max(1, damage)
	die_args.cleaning_up = false
	die_args.is_burning = false
	var locator = _get_runtime_locator()
	if locator != null and locator.has_method("get_players"):
		var players = locator.get_players()
		if typeof(players) == TYPE_ARRAY and player_index >= 0 and player_index < players.size():
			var player = players[player_index]
			if _is_valid_node(player):
				die_args.from = player
	return die_args


func apply_pickup_claim(from_steam_id: String, message: Dictionary) -> void:
	# Pickup entities are local-only now. Do not apply client pickup claims on Host;
	# gold/xp/box state remains corrected by Host economy/progression snapshots.
	return


func apply_player_state(from_steam_id: String, message: Dictionary) -> void:
	if not _is_game_host():
		return
	var expected_player_index = _get_player_index_for_steam_id(from_steam_id)
	var player_index = int(message.get("player_index", -1))
	if expected_player_index >= 0:
		if player_index < 0:
			player_index = expected_player_index
		elif player_index != expected_player_index:
			# Never trust the client-provided player_index over the Steam member -> COOP slot map.
			# This prevents a client from accidentally killing Host/P1 when its local mirrored
			# proxy fires Main._on_player_died.
			return
	if player_index < 0:
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
	_prepare_remote_player_proxy_for_client_authority(player, player_index, "player_state")
	var pos = _dict_to_vec2(message.get("pos", {}))
	if pos != Vector2.ZERO and player is Node2D:
		player.global_position = pos
	var current_stats = player.get("current_stats")
	var max_stats = player.get("max_stats")
	var incoming_hp = int(message.get("hp", -999999))
	var incoming_dead = bool(message.get("dead", false))
	if incoming_hp != -999999 and incoming_hp <= 0:
		# The client owns its current HP. If it reports HP<=0, treat that as an authoritative
		# death even if the sampled vanilla dead flag has not flipped yet.
		incoming_dead = true
	if incoming_dead and not ENABLE_REMOTE_PLAYER_DEATH_SYNC:
		return
	var incoming_max_hp = int(message.get("max_hp", -1))
	if max_stats != null and incoming_max_hp >= 0:
		max_stats.health = incoming_max_hp

	var incoming_hit_protection = int(message.get("hit_protection", -1))
	if incoming_dead:
		incoming_hit_protection = 0
	if incoming_hit_protection >= 0 and player.get("_hit_protection") != null:
		player.set("_hit_protection", incoming_hit_protection)

	_apply_client_authoritative_remote_player_life_state(player, player_index, incoming_hp, incoming_dead)


func _apply_client_authoritative_remote_player_life_state(player: Node, player_index: int, incoming_hp: int, incoming_dead: bool) -> void:
	if not _is_valid_node(player):
		return
	var current_stats = player.get("current_stats")
	var max_stats = player.get("max_stats")
	if incoming_dead:
		if current_stats != null:
			current_stats.health = 0
		if player.get("_hit_protection") != null:
			player.set("_hit_protection", 0)
		player.set_meta("brotato_online_remote_dead", true)

		# Host-side remote players are only local proxies for the client-owned player.
		# Their hurtbox is disabled, so vanilla local damage will not kill them. When the
		# owning client reports death, mirror the vanilla death lifecycle here so Host does
		# not show a living 0-HP proxy. If another path already set Player.dead=true before
		# the vanilla death animation ran, force a death pose instead of leaving the proxy standing.
		var already_dead = false
		if player.get("dead") != null:
			already_dead = bool(player.get("dead"))
		var first_dead_report = not _has_meta_true(player, "brotato_online_remote_dead_log_printed")
		_ensure_remote_player_death_visual(player, already_dead)
		if first_dead_report:
			player.set_meta("brotato_online_remote_dead_log_printed", true)
	else:
		# Do not resurrect a remote proxy whose vanilla death lifecycle already ran. The
		# next wave/scene will create a fresh Player node.
		if player.get("dead") != null and bool(player.get("dead")):
			return
		if _has_meta_true(player, "brotato_online_remote_dead_visual_applied"):
			return
		if current_stats != null and incoming_hp != -999999:
			current_stats.health = incoming_hp
		player.set_meta("brotato_online_remote_dead", false)

	if current_stats != null and player.has_signal("health_updated"):
		var mhp = int(max_stats.health) if max_stats != null else int(current_stats.health)
		player.emit_signal("health_updated", player, int(current_stats.health), mhp)


func _ensure_remote_player_death_visual(player: Node, vanilla_dead: bool) -> void:
	if not _is_valid_node(player):
		return
	if _has_meta_true(player, "brotato_online_remote_dead_visual_applied"):
		return
	player.set_meta("brotato_online_remote_dead_visual_applied", true)
	player.set_meta("brotato_online_remote_death_applying", true)

	if player.has_method("die") and not vanilla_dead:
		var args = Entity.DieArgs.new()
		args.from = null
		args.knockback_vector = Vector2.ZERO
		args.cleaning_up = false
		args.enemy_killed_by_player = false
		args.killed_by_player_index = -1
		args.killing_blow_dmg_value = 0
		args.is_burning = false
		player.set_meta("brotato_online_remote_death_applying", true)
		player.set_meta("brotato_online_allow_remote_die", true)
		player.die(args)
		player.set_meta("brotato_online_allow_remote_die", false)
		vanilla_dead = bool(player.get("dead")) if player.get("dead") != null else false
		if not vanilla_dead:
			if player.get("dead") != null:
				player.set("dead", true)
			_force_remote_player_death_pose(player)
			vanilla_dead = true
	elif player.get("dead") != null:
		player.set("dead", true)
		_force_remote_player_death_pose(player)
	else:
		_force_remote_player_death_pose(player)

	player.set_meta("brotato_online_remote_death_applying", false)
	if _is_valid_node(player):
		player.set_physics_process(false)
		player.set_process(false)


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

func build_battle_entity_resync_payload(net_ids: Array) -> Dictionary:
	var entities = []
	var seen = {}
	if typeof(net_ids) != TYPE_ARRAY:
		net_ids = []
	for id_value in net_ids:
		var net_id = str(id_value)
		if net_id == "" or seen.has(net_id):
			continue
		seen[net_id] = true
		var entity = _host_entity_by_net_id.get(net_id, null)
		if not _is_valid_node(entity):
			continue
		var category = str(_last_entity_category_by_net_id.get(net_id, ""))
		if category == "":
			category = _infer_category_from_net_id(net_id)
		if category == "":
			continue
		var entity_type = _entity_type_from_category(category)
		var state = _build_dynamic_entity_state_from_net_id(entity, net_id, category, entity_type)
		if state.empty():
			continue
		state["sync_mode"] = _sync_mode_from_category(category)
		entities.append(state.duplicate(true))
	return {
		"entities": entities,
		"births": [],
		"removed": [],
		"events": []
	}


func _infer_category_from_net_id(net_id: String) -> String:
	if net_id.begins_with("enemy_"):
		return "enemy"
	if net_id.begins_with("boss_"):
		return "boss"
	if net_id.begins_with("neutral_"):
		return "neutral"
	if net_id.begins_with("structure_"):
		return "structure"
	if net_id.begins_with("pet_"):
		return "pet"
	return ""


func apply_damage_claim_batch(from_steam_id: String, message: Dictionary) -> void:
	if not _is_game_host():
		return
	var claims = message.get("claims", [])
	if typeof(claims) != TYPE_ARRAY or claims.empty():
		return
	var player_index = int(message.get("player_index", -1))
	if player_index < 0:
		player_index = _get_player_index_for_steam_id(from_steam_id)
	if player_index < 0:
		return

	var applied_count = 0
	var applied_damage = 0
	for claim in claims:
		var short_id = -1
		var damage_sum = 0
		var hit_count = 1
		var flags = 0
		if typeof(claim) == TYPE_ARRAY:
			if claim.size() >= 2:
				short_id = int(claim[0])
				damage_sum = int(claim[1])
			if claim.size() >= 3:
				hit_count = int(claim[2])
			if claim.size() >= 4:
				flags = int(claim[3])
		elif typeof(claim) == TYPE_DICTIONARY:
			short_id = int(claim.get("short_id", claim.get("target_id", -1)))
			damage_sum = int(claim.get("damage", claim.get("damage_sum", 0)))
			hit_count = int(claim.get("hit_count", 1))
			flags = int(claim.get("flags", 0))
		if short_id <= 0 or damage_sum <= 0:
			continue
		var target = _host_entity_by_short_id.get(str(short_id), null)
		if not _is_valid_node(target):
			continue
		if bool(target.get("dead")):
			continue
		_apply_trusted_damage_to_host_entity(target, damage_sum, player_index, flags, hit_count)
		applied_count += 1
		applied_damage += damage_sum
	_damage_claim_batches_applied += 1
	_damage_claim_damage_applied += applied_damage
	_maybe_log_damage_claim_batch(from_steam_id, int(message.get("seq", 0)), claims.size(), applied_count, applied_damage, player_index)


func apply_player_hp_state(from_steam_id: String, message: Dictionary) -> void:
	if not _is_game_host():
		return
	apply_player_state(from_steam_id, message)
	return
	var player_index = int(message.get("player_index", -1))
	if player_index < 0:
		player_index = _get_player_index_for_steam_id(from_steam_id)
	if player_index < 0:
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
	var current_stats = player.get("current_stats")
	var max_stats = player.get("max_stats")
	if current_stats == null:
		return
	var incoming_dead = bool(message.get("dead", false))
	var hp = int(message.get("hp", current_stats.health))
	if hp <= 0:
		incoming_dead = true
	if incoming_dead:
		hp = REMOTE_DEAD_DISPLAY_HP
	current_stats.health = hp
	if max_stats != null and int(message.get("max_hp", -1)) >= 0:
		max_stats.health = int(message.get("max_hp", max_stats.health))
	if player.get("dead") != null and bool(player.get("dead")):
		player.set("dead", false)
	player.set_meta("brotato_online_remote_dead", incoming_dead)
	if player.has_signal("health_updated"):
		var max_hp = int(max_stats.health) if max_stats != null else hp
		player.emit_signal("health_updated", player, hp, max_hp)


func _apply_trusted_damage_to_host_entity(target: Node, damage_sum: int, player_index: int, flags: int, _hit_count: int) -> void:
	if target == null or not is_instance_valid(target):
		return
	var args = TakeDamageArgs.new(player_index, null)
	args.armor_applied = false
	args.dodgeable = false
	args.bypass_invincibility = true
	var players = []
	var locator = _get_runtime_locator()
	if locator != null and locator.has_method("get_players"):
		players = locator.get_players()
	if typeof(players) == TYPE_ARRAY and player_index >= 0 and player_index < players.size():
		args.from = players[player_index]
	if target.has_method("take_damage"):
		target.take_damage(max(1, damage_sum), args)
		var net_id = ""
		for key in _host_entity_by_net_id.keys():
			if _host_entity_by_net_id[key] == target:
				net_id = str(key)
				break
		if net_id != "":
			var current_stats = target.get("current_stats")
			if bool(target.get("dead")) or (current_stats != null and int(current_stats.health) <= 0):
				_queue_death_event_once(net_id, str(_last_entity_category_by_net_id.get(net_id, "enemy")), _get_global_pos(target), "damage_claim_batch", player_index)


func _maybe_log_damage_claim_batch(from_steam_id: String, seq: int, claim_count: int, applied_count: int, applied_damage: int, player_index: int) -> void:
	var now = OS.get_ticks_msec()
	if now - _last_damage_claim_log_msec < 1000 and applied_count > 0:
		return
	_last_damage_claim_log_msec = now


func _get_main_scene() -> Node:
	var scene = get_tree().current_scene
	if scene != null and (str(scene.filename) == "res://main.tscn" or scene.name == "Main"):
		return scene
	return get_node_or_null("/root/Main")


func _dict_to_vec2(value) -> Vector2:
	if typeof(value) == TYPE_VECTOR2:
		return value
	if typeof(value) != TYPE_DICTIONARY:
		return Vector2.ZERO
	return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))


func _prepare_host_remote_player_damage_proxies(force: bool) -> void:
	if not _is_game_host():
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
	for i in range(players.size()):
		var player = players[i]
		if not _is_valid_node(player):
			continue
		var player_index = _get_player_index_from_node(player, i)
		if _is_host_remote_player_index(player_index):
			_prepare_remote_player_proxy_for_client_authority(player, player_index, "host_remote_guard")


func _prepare_remote_player_proxy_for_client_authority(player: Node, player_index: int, reason: String) -> void:
	if not _is_valid_node(player):
		return
	player.set_meta("brotato_online_client_authority_hp", true)
	player.set_meta("brotato_online_hurtbox_disabled_player_index", player_index)

	# Bull must keep a real Hurtbox on the Host, because its character mechanic
	# is triggered by being hit. Damage/death is still client-authoritative and
	# filtered by player_safe_room_cleanup.gd through this meta flag.
	if _is_bull_player_index(player_index):
		player.set_meta("brotato_online_remote_bull_hurtbox_proxy", true)
		player.set_meta("brotato_online_hurtbox_enabled_reason", reason)
		_enable_bull_remote_player_hurtbox(player)
		return

	player.set_meta("brotato_online_remote_bull_hurtbox_proxy", false)
	if player.has_method("disable_hurtbox"):
		player.disable_hurtbox()
	else:
		var hurtbox = player.get_node_or_null("Hurtbox")
		if hurtbox != null and hurtbox.has_method("disable"):
			hurtbox.disable()
	player.set_meta("brotato_online_hurtbox_disabled_reason", reason)


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


func _is_host_remote_player_index(player_index: int) -> bool:
	var slot_manager = _get_player_slot_manager()
	if slot_manager != null and slot_manager.has_method("is_remote_player_index"):
		return bool(slot_manager.is_remote_player_index(player_index))
	# Fallback for the normal online layout where Host is P0 and Steam clients occupy P1..Pn.
	return player_index > 0


func _get_player_slot_manager() -> Node:
	var slot_manager = _get_sibling_or_root_node("BrotatoOnlineOnlinePlayerSlotManager")
	if slot_manager != null:
		return slot_manager
	return _get_sibling_or_root_node("BrotatoOnlinePlayerSlotManager")


func _get_player_index_from_node(player: Node, fallback_index: int) -> int:
	if not _is_valid_node(player):
		return fallback_index
	var raw_player_index = player.get("player_index")
	if raw_player_index != null:
		return int(raw_player_index)
	return fallback_index


func _get_player_index_for_steam_id(steam_id: String) -> int:
	var slot_manager = _get_player_slot_manager()
	if slot_manager != null and slot_manager.has_method("get_player_index_for_steam_id"):
		return int(slot_manager.get_player_index_for_steam_id(steam_id))
	return -1


func _net_short_id(net_id: String) -> int:
	var parts = net_id.split("_")
	if parts.size() <= 0:
		return -1
	return int(parts[parts.size() - 1])


func _queue_battle_event(event: Dictionary) -> void:
	_pending_battle_events.append(event)
	while _pending_battle_events.size() > MAX_EVENTS_PER_SNAPSHOT * 3:
		_pending_battle_events.pop_front()


func _queue_death_event_once(net_id: String, category: String, pos: Vector2, cause: String, player_index: int) -> void:
	if not ENABLE_DEATH_EVENT_BROADCAST:
		return
	if net_id == "" or _announced_death_net_ids.has(net_id):
		return
	if category != "enemy" and category != "boss" and category != "neutral":
		return
	_announced_death_net_ids[net_id] = true
	var now_msec = OS.get_ticks_msec()
	var event = {
		"event_type": "death_event",
		"event_id": _next_battle_event_id,
		"tick": _tick,
		"time_msec": now_msec,
		"server_time_msec": now_msec,
		"target_net_id": net_id,
		"category": category,
		"pos": _vec_to_dict(pos),
		"cause": cause,
		"player_index": player_index
	}
	_next_battle_event_id += 1
	_queue_battle_event(event)

func _has_meta_true(node: Node, key: String) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not node.has_meta(key):
		return false
	return bool(node.get_meta(key))
func _collect_projectile_spawn_visual_events(locator: Node) -> void:
	# Host projectile visual events caused duplicate nodes/network pressure and made the
	# battle stutter. Re-enable later only for remote-player presentation.
	if not ENABLE_PROJECTILE_VISUAL_EVENTS_IN_B5_5:
		return
	if locator == null:
		return
	var containers = _get_projectile_containers(locator)
	var active_ids = {}
	for info in containers:
		if typeof(info) != TYPE_DICTIONARY:
			continue
		var container = info.get("node")
		if not _is_valid_node(container):
			continue
		var projectile_kind = str(info.get("kind", "projectile"))
		for child in container.get_children():
			if not _is_valid_node(child):
				continue
			if _has_meta_true(child, "brotato_online_projectile_visual"):
				continue
			if not (child is Node2D):
				continue
			var instance_key = str(child.get_instance_id())
			active_ids[instance_key] = true
			if _known_projectile_instance_ids.has(instance_key):
				continue
			_known_projectile_instance_ids[instance_key] = true
			_queue_battle_event(_build_projectile_spawn_visual_event(child, projectile_kind))

	var to_remove = []
	for known_id in _known_projectile_instance_ids.keys():
		if not active_ids.has(str(known_id)):
			to_remove.append(str(known_id))
	for known_id in to_remove:
		_known_projectile_instance_ids.erase(known_id)


func _get_projectile_containers(locator: Node) -> Array:
	var result = []
	var main = null
	if locator.has_method("get_main"):
		main = locator.get_main()
	if main == null:
		return result
	_append_projectile_container(result, main.get("_player_projectiles"), "player")
	_append_projectile_container(result, main.get("_enemy_projectiles"), "enemy")
	_append_projectile_container(result, main.get_node_or_null("PlayerProjectiles"), "player")
	_append_projectile_container(result, main.get_node_or_null("EnemyProjectiles"), "enemy")
	return result


func _append_projectile_container(result: Array, node, kind: String) -> void:
	if not _is_valid_node(node):
		return
	for info in result:
		if typeof(info) == TYPE_DICTIONARY and info.get("node") == node:
			return
	result.append({"node": node, "kind": kind})


func _build_projectile_spawn_visual_event(projectile: Node, projectile_kind: String) -> Dictionary:
	var now_msec = OS.get_ticks_msec()
	var velocity = _safe_vector_from_object(projectile, "velocity", Vector2.ZERO)
	var pos = _get_global_pos(projectile)
	var rotation = 0.0
	var scale_value = 1.0
	if projectile is Node2D:
		rotation = projectile.rotation
		scale_value = projectile.scale.x
	var direction = Vector2.RIGHT.rotated(rotation)
	var speed = velocity.length()
	if speed > 0.01:
		direction = velocity.normalized()

	var muzzle_pos = pos
	var estimated_spawn_elapsed_msec = 0
	var spawn_position = projectile.get("spawn_position")
	if typeof(spawn_position) == TYPE_VECTOR2 and speed > 0.01:
		muzzle_pos = spawn_position
		var travelled = max(0.0, (pos - muzzle_pos).dot(direction))
		estimated_spawn_elapsed_msec = int(clamp(travelled / speed * 1000.0, 0.0, 1200.0))
	var event_server_time_msec = now_msec - estimated_spawn_elapsed_msec

	var lifetime_msec = 900
	var time_until_max_range = projectile.get("_time_until_max_range")
	if time_until_max_range != null:
		lifetime_msec = int(clamp(float(time_until_max_range) * 1000.0 + float(estimated_spawn_elapsed_msec), 80.0, 2500.0))
	var scene_path = _get_scene_path(projectile)
	var event = {
		"event_type": "projectile_spawn_visual",
		"event_id": _next_battle_event_id,
		"tick": _tick,
		"time_msec": now_msec,
		"server_time_msec": event_server_time_msec,
		"projectile_kind": projectile_kind,
		"projectile_scene_path": scene_path,
		"muzzle_pos": _vec_to_dict(muzzle_pos),
		"pos": _vec_to_dict(pos),
		"velocity": _vec_to_dict(velocity),
		"direction": _vec_to_dict(direction),
		"speed": _round2(speed),
		"rotation": rotation,
		"scale": scale_value,
		"lifetime_msec": lifetime_msec
	}
	_next_battle_event_id += 1
	return event


func _append_death_events_for_removed(removed: Array) -> void:
	if typeof(removed) != TYPE_ARRAY or removed.empty():
		return
	if not ENABLE_DEATH_EVENT_BROADCAST:
		for rid_value in removed:
			var rid_disabled = str(rid_value)
			_last_entity_pos_by_net_id.erase(rid_disabled)
			_last_entity_category_by_net_id.erase(rid_disabled)
			_host_entity_by_net_id.erase(rid_disabled)
			_host_entity_by_short_id.erase(str(_net_short_id(rid_disabled)))
		return
	for rid_value in removed:
		var rid = str(rid_value)
		var category = str(_last_entity_category_by_net_id.get(rid, ""))
		if category == "enemy" or category == "boss" or category == "neutral":
			var pos = _dict_to_vec2(_last_entity_pos_by_net_id.get(rid, {"x": 0.0, "y": 0.0}))
			_queue_death_event_once(rid, category, pos, "registry_removed", -1)
		_last_entity_pos_by_net_id.erase(rid)
		_last_entity_category_by_net_id.erase(rid)
		_host_entity_by_net_id.erase(rid)
		_host_entity_by_short_id.erase(str(_net_short_id(rid)))


func peek_pending_battle_reliable_events_for_send() -> Dictionary:
	return {
		"entities": _pending_ordered_dictionary_values(_pending_reliable_birth_entity_order, _pending_reliable_birth_entities_by_net_id, MAX_RELIABLE_BIRTH_ENTITIES_PER_SEND),
		"births": _pending_ordered_dictionary_values(_pending_reliable_birth_marker_order, _pending_reliable_birth_markers_by_net_id, MAX_RELIABLE_BIRTH_MARKERS_PER_SEND),
		"removed": _peek_pending_reliable_removed_ids(MAX_RELIABLE_REMOVED_PER_SEND) if ENABLE_REMOVED_SYNC else [],
		"events": _peek_pending_battle_events(MAX_EVENTS_PER_SNAPSHOT)
	}


func mark_battle_reliable_events_sent(message: Dictionary) -> void:
	if typeof(message) != TYPE_DICTIONARY or message.empty():
		return

	var entities = message.get("entities", [])
	if typeof(entities) == TYPE_ARRAY:
		for entity in entities:
			if typeof(entity) != TYPE_DICTIONARY:
				continue
			var net_id = str(entity.get("net_id", ""))
			if net_id == "":
				continue
			_pending_reliable_birth_entities_by_net_id.erase(net_id)
			_pending_reliable_birth_entity_order.erase(net_id)

	var births = message.get("births", [])
	if typeof(births) == TYPE_ARRAY:
		for birth in births:
			if typeof(birth) != TYPE_DICTIONARY:
				continue
			var birth_id = str(birth.get("net_id", ""))
			if birth_id == "":
				continue
			_pending_reliable_birth_markers_by_net_id.erase(birth_id)
			_pending_reliable_birth_marker_order.erase(birth_id)

	var removed = message.get("removed", [])
	if typeof(removed) == TYPE_ARRAY:
		for rid_value in removed:
			var rid = str(rid_value)
			_pending_reliable_removed_id_set.erase(rid)
			_pending_reliable_removed_ids.erase(rid)

	var events = message.get("events", [])
	if typeof(events) == TYPE_ARRAY and not events.empty():
		var sent_event_ids = {}
		for event in events:
			if typeof(event) != TYPE_DICTIONARY:
				continue
			var event_id = int(event.get("event_id", 0))
			if event_id > 0:
				sent_event_ids[event_id] = true
		if not sent_event_ids.empty():
			var kept = []
			for pending_event in _pending_battle_events:
				if typeof(pending_event) != TYPE_DICTIONARY:
					continue
				var pending_event_id = int(pending_event.get("event_id", 0))
				if pending_event_id <= 0 or not sent_event_ids.has(pending_event_id):
					kept.append(pending_event)
			_pending_battle_events = kept


func _queue_pending_reliable_birth_entity(state: Dictionary) -> void:
	if typeof(state) != TYPE_DICTIONARY or state.empty():
		return
	var net_id = str(state.get("net_id", ""))
	if net_id == "":
		return
	if not _pending_reliable_birth_entities_by_net_id.has(net_id):
		_pending_reliable_birth_entity_order.append(net_id)
	_pending_reliable_birth_entities_by_net_id[net_id] = state.duplicate(true)
	while _pending_reliable_birth_entity_order.size() > MAX_RELIABLE_BIRTH_ENTITIES_PER_SEND * 4:
		var dropped = str(_pending_reliable_birth_entity_order.pop_front())
		_pending_reliable_birth_entities_by_net_id.erase(dropped)


func _queue_pending_reliable_birth_marker(state: Dictionary) -> void:
	if typeof(state) != TYPE_DICTIONARY or state.empty():
		return
	var birth_id = str(state.get("net_id", ""))
	if birth_id == "":
		return
	if not _pending_reliable_birth_markers_by_net_id.has(birth_id):
		_pending_reliable_birth_marker_order.append(birth_id)
	_pending_reliable_birth_markers_by_net_id[birth_id] = state.duplicate(true)
	while _pending_reliable_birth_marker_order.size() > MAX_RELIABLE_BIRTH_MARKERS_PER_SEND * 4:
		var dropped = str(_pending_reliable_birth_marker_order.pop_front())
		_pending_reliable_birth_markers_by_net_id.erase(dropped)


func _queue_pending_reliable_removed(net_id: String) -> void:
	if not ENABLE_REMOVED_SYNC:
		return
	if net_id == "":
		return
	if _pending_reliable_removed_id_set.has(net_id):
		return
	_pending_reliable_removed_id_set[net_id] = true
	_pending_reliable_removed_ids.append(net_id)
	while _pending_reliable_removed_ids.size() > MAX_RELIABLE_REMOVED_PER_SEND * 4:
		var dropped = str(_pending_reliable_removed_ids.pop_front())
		_pending_reliable_removed_id_set.erase(dropped)


func _pending_ordered_dictionary_values(order: Array, values_by_id: Dictionary, max_count: int) -> Array:
	var result = []
	if max_count <= 0:
		return result
	for id_value in order:
		if result.size() >= max_count:
			break
		var id = str(id_value)
		if not values_by_id.has(id):
			continue
		var value = values_by_id[id]
		if typeof(value) == TYPE_DICTIONARY:
			result.append(value.duplicate(true))
		else:
			result.append(value)
	return result


func _peek_pending_reliable_removed_ids(max_count: int) -> Array:
	var result = []
	if not ENABLE_REMOVED_SYNC:
		return result
	if max_count <= 0:
		return result
	for id_value in _pending_reliable_removed_ids:
		if result.size() >= max_count:
			break
		result.append(str(id_value))
	return result


func _peek_pending_battle_events(max_count: int) -> Array:
	if _pending_battle_events.empty() or max_count <= 0:
		return []
	var events = []
	var count = int(min(_pending_battle_events.size(), max_count))
	for i in range(count):
		var event = _pending_battle_events[i]
		if typeof(event) == TYPE_DICTIONARY:
			events.append(event.duplicate(true))
	return events


func _clear_pending_reliable_events() -> void:
	_pending_battle_events.clear()
	_pending_reliable_birth_entities_by_net_id.clear()
	_pending_reliable_birth_entity_order.clear()
	_pending_reliable_birth_markers_by_net_id.clear()
	_pending_reliable_birth_marker_order.clear()
	_pending_reliable_removed_id_set.clear()
	_pending_reliable_removed_ids.clear()


func _print_snapshot_summary(snapshot: Dictionary) -> void:
	var players = snapshot.get("players", [])
	var entities = snapshot.get("entities", [])
	var removed = snapshot.get("removed", [])
	var events = snapshot.get("events", [])
	var counts = snapshot.get("counts", {})
	var samples = []

	if typeof(entities) == TYPE_ARRAY:
		var sample_count = int(min(entities.size(), MAX_SUMMARY_ENTITY_SAMPLES))
		for i in range(sample_count):
			var entity = entities[i]
			if typeof(entity) == TYPE_DICTIONARY:
				var pos = entity.get("pos", {})
				samples.append(str(entity.get("net_id", "")) + ":" + str(entity.get("category", "")) + "@" + str(pos.get("x", 0)) + "," + str(pos.get("y", 0)) + ":hp" + str(entity.get("health", -1)) + ":scene=" + str(entity.get("scene_path", "")))



func _ensure_current_game_scene_registered(reason: String, locator: Node, is_host: bool, steam: Node) -> void:
	var current_scene_id = _current_game_scene_instance_id()
	if _last_scene_was_game:
		var scene_cache_invalid = _last_game_scene_instance_id <= 0 or _game_scene_enter_msec <= 0
		var scene_changed = _last_game_scene_instance_id > 0 and current_scene_id > 0 and current_scene_id != _last_game_scene_instance_id
		if scene_cache_invalid or scene_changed:
			var old_scene_id = _last_game_scene_instance_id
			var old_scene_enter = _game_scene_enter_msec
			_on_left_game_scene()

	if not _last_scene_was_game:
		_tick = 0
		_last_snapshot = {}
		_last_snapshot_msec = 0
		_cached_economy_state = {}
		_cached_progression_state = {}
		_last_economy_snapshot_msec = 0
		_last_progression_snapshot_msec = 0
		_last_forced_stopped_progression_key = ""
		_clear_pending_reliable_events()
		_damage_signal_connected_ids.clear()
		_known_projectile_instance_ids.clear()
		_last_entity_pos_by_net_id.clear()
		_last_entity_category_by_net_id.clear()
		_last_entity_cursed_by_net_id.clear()
		_structure_curse_data_signature_by_net_id.clear()
		_host_entity_by_net_id.clear()
		_host_entity_by_short_id.clear()
		_host_pickup_by_net_id.clear()
		_host_pickup_kind_by_net_id.clear()
		_birth_only_announced_net_ids.clear()
		_birth_only_first_seen_msec.clear()
		_announced_death_net_ids.clear()
		_birth_marker_announced_net_ids.clear()
		_reserved_spawn_by_birth_id.clear()
		_reserved_birth_id_by_spawn_net_id.clear()
		_pending_signal_spawn_nodes.clear()
		_pending_signal_spawn_instance_ids.clear()
		_connected_spawner_instance_id = ""
		_last_game_scene_instance_id = current_scene_id
		_game_scene_enter_msec = OS.get_ticks_msec()
		var registry = _get_net_id_registry()
		if registry != null and registry.has_method("reset"):
			registry.reset()
	_last_scene_was_game = true


func _on_left_game_scene() -> void:
	_tick = 0
	_last_snapshot_msec = 0
	_last_snapshot = {}
	_cached_progression_state = {}
	_last_progression_snapshot_msec = 0
	_last_forced_stopped_progression_key = ""
	_clear_pending_reliable_events()
	_damage_signal_connected_ids.clear()
	_known_projectile_instance_ids.clear()
	_last_entity_pos_by_net_id.clear()
	_last_entity_category_by_net_id.clear()
	_last_entity_cursed_by_net_id.clear()
	_structure_curse_data_signature_by_net_id.clear()
	_host_entity_by_net_id.clear()
	_host_entity_by_short_id.clear()
	_host_pickup_by_net_id.clear()
	_host_pickup_kind_by_net_id.clear()
	_birth_only_announced_net_ids.clear()
	_birth_only_first_seen_msec.clear()
	_announced_death_net_ids.clear()
	_birth_marker_announced_net_ids.clear()
	_reserved_spawn_by_birth_id.clear()
	_reserved_birth_id_by_spawn_net_id.clear()
	_pending_signal_spawn_nodes.clear()
	_pending_signal_spawn_instance_ids.clear()
	_connected_spawner_instance_id = ""
	_last_game_scene_instance_id = 0
	_game_scene_enter_msec = 0
	_last_scene_was_game = false
	var registry = _get_net_id_registry()
	if registry != null and registry.has_method("reset"):
		registry.reset()


func _get_runtime_locator() -> Node:
	return _get_sibling_or_root_node("BrotatoOnlineRuntimeLocator")


func _get_net_id_registry() -> Node:
	return _get_sibling_or_root_node("BrotatoOnlineNetIdRegistry")


func _get_steam_lobby_manager() -> Node:
	return _get_sibling_or_root_node("BrotatoOnlineSteamLobbyManager")


func _get_sibling_or_root_node(node_name: String) -> Node:
	var parent = get_parent()
	if parent != null:
		var sibling = parent.get_node_or_null(node_name)
		if sibling != null:
			return sibling

	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	return _find_node_by_name(tree.root, node_name)


func _find_node_by_name(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if str(root.name) == node_name:
		return root
	for child in root.get_children():
		if child is Node:
			var found = _find_node_by_name(child, node_name)
			if found != null:
				return found
	return null


func _is_online_session_active() -> bool:
	var steam_manager = _get_steam_lobby_manager()
	if steam_manager == null:
		return false
	if steam_manager.has_method("is_online_session_active"):
		return bool(steam_manager.is_online_session_active())
	if steam_manager.has_method("has_active_online_session"):
		return bool(steam_manager.has_active_online_session())
	return false


func _is_game_host() -> bool:
	var steam_manager = _get_steam_lobby_manager()
	if steam_manager == null:
		return false
	if steam_manager.has_method("is_game_host"):
		return bool(steam_manager.is_game_host())
	if steam_manager.has_method("is_host"):
		return bool(steam_manager.is_host())
	return false

func _current_game_scene_instance_id() -> int:
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return 0
	return tree.current_scene.get_instance_id()


func _current_scene_desc() -> String:
	var tree = get_tree()
	if tree == null or tree.current_scene == null:
		return "none"
	return str(tree.current_scene.name) + "|" + str(tree.current_scene.filename)


func _is_valid_node(node) -> bool:
	return node != null and is_instance_valid(node) and node is Node and not node.is_queued_for_deletion() and node.is_inside_tree()


func _safe_node_path(node: Node) -> String:
	if not _is_valid_node(node):
		return ""
	return str(node.get_path())


func _get_global_pos(node: Node) -> Vector2:
	if node is Node2D:
		return node.global_position
	return Vector2.ZERO


func _get_velocity(node: Node) -> Vector2:
	var linear_velocity = node.get("linear_velocity")
	if typeof(linear_velocity) == TYPE_VECTOR2:
		return _sanitize_vector(linear_velocity)

	var integrate_velocity = node.get("_integrate_forces_velocity")
	if typeof(integrate_velocity) == TYPE_VECTOR2:
		return _sanitize_vector(integrate_velocity)

	var current_movement = node.get("_current_movement")
	if typeof(current_movement) == TYPE_VECTOR2:
		return _sanitize_vector(current_movement)

	return Vector2.ZERO


func _get_script_path(node: Node) -> String:
	if not _is_valid_node(node):
		return ""
	var script_res = node.get_script()
	if script_res == null:
		return ""
	return str(script_res.resource_path)


func _get_scene_path(node: Node) -> String:
	if not _is_valid_node(node):
		return ""

	var filename_value = node.get("filename")
	if filename_value != null and str(filename_value) != "":
		return str(filename_value)

	var script_path = _get_script_path(node)
	if script_path.begins_with("res://") and script_path.ends_with(".gd"):
		return script_path.substr(0, script_path.length() - 3) + ".tscn"

	return ""


func _get_resource_path(res) -> String:
	if res == null or not (res is Resource):
		return ""
	return str(res.resource_path)


func _build_status_flags_for_entity(entity: Node, category: String) -> Dictionary:
	var flags = {}
	if _should_sync_entity_curse_status(category):
		flags["cursed"] = _is_entity_cursed_authoritative(entity, category)
	return flags


func _should_sync_enemy_curse_status(category: String) -> bool:
	return category == "enemy" or category == "boss"


func _should_sync_structure_curse_status(category: String) -> bool:
	return category == "structure"


func _should_sync_entity_curse_status(category: String) -> bool:
	return _should_sync_enemy_curse_status(category) or _should_sync_structure_curse_status(category)


func _is_entity_cursed_authoritative(entity: Node, category: String = "") -> bool:
	if _should_sync_enemy_curse_status(category):
		return _has_curse_effect_behavior(entity) or _safe_bool_from_object(entity, "is_cursed", false)
	if _should_sync_structure_curse_status(category):
		return _safe_bool_from_object(entity, "is_cursed", false)
	return false


func _has_curse_effect_behavior(entity: Node) -> bool:
	if not _is_valid_node(entity):
		return false
	var effect_behaviors = entity.get_node_or_null("EffectBehaviors")
	if effect_behaviors == null:
		return false

	for child in effect_behaviors.get_children():
		if not _is_valid_node(child):
			continue
		var script_path = _get_script_path(child)
		if script_path.find("curse_enemy_effect_behavior.gd") != -1:
			return true

	return false


func _safe_vector_from_object(obj, property_name: String, fallback: Vector2) -> Vector2:
	if obj == null:
		return fallback
	var value = obj.get(property_name)
	if typeof(value) == TYPE_VECTOR2:
		return _sanitize_vector(value)
	return fallback


func _safe_float_from_object(obj, property_name: String, fallback: float) -> float:
	if obj == null:
		return fallback
	var value = obj.get(property_name)
	if value == null:
		return fallback
	return float(value)


func _safe_int_from_object(obj, property_name: String, fallback: int) -> int:
	if obj == null:
		return fallback
	var value = obj.get(property_name)
	if value == null:
		return fallback
	return int(value)


func _safe_bool_from_object(obj, property_name: String, fallback: bool) -> bool:
	if obj == null:
		return fallback
	var value = obj.get(property_name)
	if value == null:
		return fallback
	return bool(value)


func _vec_to_dict(value: Vector2) -> Dictionary:
	var vec = _sanitize_vector(value)
	return {
		"x": _round2(vec.x),
		"y": _round2(vec.y)
	}


func _sanitize_vector(value: Vector2) -> Vector2:
	var x = value.x
	var y = value.y
	if x != x:
		x = 0.0
	if y != y:
		y = 0.0
	x = clamp(x, -1000000.0, 1000000.0)
	y = clamp(y, -1000000.0, 1000000.0)
	return Vector2(x, y)


func _round2(value: float) -> float:
	return round(value * 100.0) / 100.0


func _array_size(value) -> int:
	if typeof(value) == TYPE_ARRAY:
		return value.size()
	return 0


func _entity_type_enemy() -> int:
	return EntityType.ENEMY


func _entity_type_neutral() -> int:
	return EntityType.NEUTRAL


func _entity_type_structure() -> int:
	return EntityType.STRUCTURE


func _entity_type_boss() -> int:
	return EntityType.BOSS


func _entity_type_pet() -> int:
	return EntityType.PET
