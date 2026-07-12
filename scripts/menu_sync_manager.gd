extends Node


const STATE_POLL_INTERVAL_MSEC = 250
const MENU_SCENE_APPLY_DEBOUNCE_MSEC = 500
const MUTATING_RUN_PAGE_ACTION_DEDUP_MSEC = 900
const ENABLE_HOST_SHOP_DIAGNOSTICS = false
const RUN_PAGE_CONSUME_SCAN_INTERVAL_MSEC = 120
const PROGRESSION_UI_RECURSIVE_SCAN_INTERVAL_MSEC = 1000
const RUN_PAGE_GAME_START_GUARD_MSEC = 10000
const MENU_SCENE_CHANGE_IN_FLIGHT_MSEC = 12000
const CLIENT_SHOP_PREDICTION_HOLD_MSEC = 3000
const SHOP_DELTA_STATE_INTERVAL_MSEC = 1000
const SHOP_RUN_DATA_ITEMS_COMPACT_VERSION = 1
const SHOP_RUN_DATA_ID_ONLY_VERSION = 1
const SHOP_HELD_ITEMS_SYNC_COMPACT = "compact"
const SHOP_HELD_ITEMS_SYNC_HASH_ONLY = "hash_only"
const SHOP_HELD_ITEMS_SYNC_INCREMENTAL_ONLY = "incremental_only"
const ENDLESS_INCREMENTAL_ITEMS_ONLY_START_WAVE = 21
const SHOP_ITEMS_RESYNC_REQUEST_COOLDOWN_MSEC = 1500
const SHOP_CUSTOM_POPUP_BUTTON_ACTION = "shop_custom_popup_button"

const BO_UI_DIAG_ENABLED = true
# Lag log policy: routine polls / focus / screen changes are silent.  Only a single
# expensive call, repeated medium-cost calls, input storms, or backlog states are logged.
const BO_UI_DIAG_SINGLE_COST_USEC = 10000
const BO_UI_DIAG_BURST_COST_USEC = 3000
const BO_UI_DIAG_BURST_TOTAL_USEC = 20000
const BO_UI_DIAG_BURST_COUNT = 5
const BO_UI_DIAG_BURST_WINDOW_MSEC = 2000
const BO_UI_DIAG_INPUT_BURST_WINDOW_MSEC = 1000
const BO_UI_DIAG_INPUT_BURST_COUNT = 18
const BO_UI_DIAG_QUEUE_WARN_COUNT = 4

var _bo_ui_diag_last_screen = ""
var _bo_ui_diag_last_focus_key = ""
var _bo_ui_diag_input_count = 0
var _bo_ui_diag_input_window_start_msec = 0
var _bo_ui_diag_input_window_count = 0
var _bo_ui_diag_last_input_summary = ""
var _bo_ui_diag_last_input_burst_log_msec = 0
var _bo_ui_diag_cost_stats_by_scope = {}
var _bo_ui_diag_last_queue_key = ""
var _bo_ui_diag_last_queue_log_msec = 0




const SCREEN_NONE = "none"
const SCREEN_CHARACTER_SELECTION = "character_selection"
const SCREEN_WEAPON_SELECTION = "weapon_selection"
const SCREEN_DIFFICULTY_SELECTION = "difficulty_selection"
const SCREEN_GAME = "game"
const SCREEN_SHOP = "shop"

var _last_state_key = ""
var _last_state_poll_msec = 0
var _last_state_from_host = {}
var _pending_state_from_host = {}
var _last_menu_scene_state_from_host = {}
var _pending_menu_scene_state_from_host = {}
var _last_client_scene_apply_key = ""
var _last_client_scene_apply_msec = 0
var _last_sent_local_focus_key = ""
var _last_sent_local_select_key = ""
var _last_local_selection_instance_id = 0
var _last_applied_run_config_key = ""
var _last_applied_difficulty_start_key = ""
var _local_client_steam_id = ""
var _last_availability_from_host = {}
var _pending_availability_from_host = {}
var _last_applied_availability_key = ""
var _last_applied_progress_mirror_key = ""
var _progress_mirror_active = false
var _host_catalog_by_screen = {}
var _host_catalog_key_by_screen = {}
var _host_catalog_player_key_by_screen = {}
var _last_applied_catalog_key_by_screen = {}
var _last_applied_catalog_player_key_by_inventory = {}
# Host-side catalog build cache. Character DLC locks are event-driven; do not rebuild
# the full selection inventory catalog on every focus/selection_state refresh.
var _host_built_catalog_by_screen = {}
var _host_built_catalog_build_key_by_screen = {}
var _host_dlc_gate_logged_missing_keys = {}
var _dlc_safe_fallback_warning_keys = {}
var _host_client_character_lookup_by_steam_id = {}
var _host_client_item_lookup_by_steam_id = {}
var _host_client_weapon_lookup_by_steam_id = {}
var _host_client_character_catalog_key_by_steam_id = {}
var _host_client_shop_content_catalog_key_by_steam_id = {}
var _host_common_shop_fallback_cache = {}
var _host_dlc_gate_catalog_dirty = false
var _last_host_dlc_gate_apply_key = ""
var _last_host_dlc_gate_log_key = ""
var _client_intercept_selection_instance_id = 0
var _queued_local_client_menu_messages = []
var _queued_local_run_page_action_messages = []
var _last_client_prime_key = ""
var _pending_client_prime_screen = ""
var _pending_client_prime_until_msec = 0
var _last_local_run_page_focus_key = {}
var _last_local_run_page_state_key_by_player = {}
var _client_progression_intercept_container_id = 0
var _processed_run_page_action_ids = {}
var _last_run_page_action_seq_by_origin = {}
var _applying_remote_run_page_action = false
var _last_progression_options_processed_key = ""
var _last_shop_state_key = ""
var _last_shop_full_state_msec = 0
var _host_shop_initial_full_sent_instance_id = 0
var _host_shop_state_key_by_player = {}
var _last_local_shop_focus_key = {}
var _last_shop_focus_target_by_player = {}
var _last_host_shop_focus_repair_msec = 0
var _shop_input_guard_instance_id = 0
var _shop_input_guard_until_msec = 0
var _shop_input_guard_wait_release = false
var _client_shop_intercept_key = ""
var _pending_shop_states_from_host = []
var _local_shop_go_pending_until_by_player = {}
var _host_shop_go_intercept_key = {}
var _host_shop_item_observer_key = {}
var _next_local_run_page_action_seq = 1
var _recent_mutating_run_page_action_keys = {}
var _pending_synced_shop_start_id = 0
var _client_shop_direct_lock_probe_seq = 0
var _client_shop_lock_state_by_slot_key = {}
var _last_client_shop_lock_poll_key = ""
var _last_applied_shop_gear_key_by_player = {}
var _last_applied_shop_state_key_by_player = {}
var _client_shop_prediction_seq = 0
var _client_shop_prediction_until_by_player = {}
var _client_shop_prediction_token_by_player = {}
var _client_shop_prediction_key_by_player = {}
var _client_shop_prediction_action_by_player = {}
var _shop_state_cache_instance_id = 0
var _host_shop_run_data_key_by_player = {}
var _host_shop_run_data_cache_by_player = {}
var _host_shop_run_data_cache_mode_by_player = {}
var _host_shop_run_data_sent_key_by_player = {}
var _host_shop_run_data_stamp_by_player = {}
var _host_shop_run_data_dirty_by_player = {}
var _last_applied_shop_slots_key_by_player = {}
var _last_applied_shop_run_data_key_by_player = {}
var _pending_shop_items_resync_key_by_player = {}
var _pending_shop_items_resync_until_by_player = {}
var _missing_host_item_placeholder_cache = {}
var _last_consume_run_page_scan_msec = 0
var _cached_progression_ui = null
var _cached_progression_ui_scene_id = 0
var _last_progression_ui_recursive_scan_msec = 0
var _run_page_game_start_guard_until_msec = 0
var _run_page_game_start_guard_start_id = 0
var _run_page_game_start_guard_reason = ""
var _run_page_game_start_guard_logged_key = ""
var _client_scene_change_in_flight_screen = ""
var _client_scene_change_in_flight_path = ""
var _client_scene_change_in_flight_until_msec = 0
var _client_scene_change_in_flight_logged_key = ""
var _shop_inventory_custom_button_popup_key_by_player = {}
var _shop_inventory_custom_button_connected_keys = {}
var _shop_inventory_custom_button_apply_guard = false
var _shop_inventory_custom_button_recent_press_keys = {}
var _shop_inventory_custom_button_deferred_apply_keys = {}
var _shop_inventory_custom_button_descriptor_cache = {}

func _bo_ui_diag_log(tag: String, msg: String) -> void:
	if not BO_UI_DIAG_ENABLED:
		return
	print("[BO_LAG][UI][" + tag + "] " + msg)


func _bo_ui_diag_node_desc(node) -> String:
	if not _is_live_ref(node):
		return "null"
	var node_name = ""
	if node is Node:
		node_name = str(node.name)
	var cls = node.get_class() if node.has_method("get_class") else "Object"
	return cls + "#" + str(node.get_instance_id()) + "(" + node_name + ")"


func _bo_ui_diag_players_desc() -> String:
	var parts = []
	if CoopService == null:
		return "no_coop"
	for i in range(CoopService.connected_players.size()):
		var p = CoopService.connected_players[i]
		if typeof(p) == TYPE_ARRAY and p.size() >= 2:
			parts.append("P" + str(i) + "{dev=" + str(p[0]) + ",type=" + str(p[1]) + "}")
		else:
			parts.append("P" + str(i) + "{" + str(p) + "}")
	return "[" + ";".join(parts) + "]"


func _bo_ui_diag_focus_key() -> String:
	var parts = []
	var count = int(max(4, int(RunData.get_player_count()))) if RunData != null and RunData.has_method("get_player_count") else 4
	for player_index in range(count):
		var fe = Utils.get_focus_emulator(player_index) if Utils != null else null
		if not _is_live_ref(fe):
			parts.append("P" + str(player_index) + "=null")
			continue
		var focused = _safe_get(fe, "focused_control", null)
		var device = int(_safe_get(fe, "_device", -999))
		var process_input = fe.is_processing_input() if fe.has_method("is_processing_input") else false
		var visible = fe.visible if fe is CanvasItem else false
		parts.append("P" + str(player_index) + "{dev=" + str(device) + ",in=" + str(process_input) + ",vis=" + str(visible) + ",focus=" + _bo_ui_diag_node_desc(focused) + "}")
	return " | ".join(parts)


func _bo_ui_diag_log_focus(reason: String, force: bool = false) -> void:
	# Focus owner snapshots are expensive and noisy.  Keep this callable for existing
	# call sites, but only emit when the focus layer is changing while a queue/backlog
	# is already suspicious.
	if not BO_UI_DIAG_ENABLED:
		return
	var queued = _queued_local_client_menu_messages.size() + _queued_local_run_page_action_messages.size() + _pending_shop_states_from_host.size()
	if queued < BO_UI_DIAG_QUEUE_WARN_COUNT:
		return
	var key = _bo_ui_diag_focus_key()
	if not force and key == _bo_ui_diag_last_focus_key:
		return
	_bo_ui_diag_last_focus_key = key
	_bo_ui_diag_log("FOCUS_BACKLOG", "reason=" + reason + " queued=" + str(queued) + " screen=" + _get_current_menu_screen_fast() + " host=" + str(_is_game_host()) + " local_idx=" + str(_get_local_client_player_index()) + " run_players=" + str(_get_run_player_count()) + " coop=" + _bo_ui_diag_players_desc() + " fe=" + key)


func _bo_ui_diag_extra_context(extra: String = "") -> String:
	var parts = []
	parts.append("screen=" + _get_current_menu_screen_fast())
	parts.append("host=" + str(_is_game_host()))
	parts.append("queued_menu=" + str(_queued_local_client_menu_messages.size()))
	parts.append("queued_run=" + str(_queued_local_run_page_action_messages.size()))
	parts.append("pending_shop=" + str(_pending_shop_states_from_host.size()))
	if _bo_ui_diag_last_input_summary != "":
		parts.append("last_input=" + _bo_ui_diag_last_input_summary)
	if extra != "":
		parts.append(extra)
	return " ".join(parts)


func _bo_ui_diag_log_cost(scope: String, start_usec: int, extra: String = "") -> void:
	if not BO_UI_DIAG_ENABLED:
		return
	var cost = OS.get_ticks_usec() - start_usec
	var now = OS.get_ticks_msec()
	if cost >= BO_UI_DIAG_SINGLE_COST_USEC:
		_bo_ui_diag_log("SLOW", "scope=" + scope + " us=" + str(cost) + " " + _bo_ui_diag_extra_context(extra))
		return
	if cost < BO_UI_DIAG_BURST_COST_USEC:
		return
	var stats = _bo_ui_diag_cost_stats_by_scope.get(scope, {})
	if typeof(stats) != TYPE_DICTIONARY or stats.empty() or now - int(stats.get("start_msec", now)) > BO_UI_DIAG_BURST_WINDOW_MSEC:
		stats = {"start_msec": now, "count": 0, "total_usec": 0, "max_usec": 0, "last_log_msec": 0}
	stats["count"] = int(stats.get("count", 0)) + 1
	stats["total_usec"] = int(stats.get("total_usec", 0)) + cost
	stats["max_usec"] = max(int(stats.get("max_usec", 0)), cost)
	_bo_ui_diag_cost_stats_by_scope[scope] = stats
	var should_log = int(stats.get("count", 0)) >= BO_UI_DIAG_BURST_COUNT or int(stats.get("total_usec", 0)) >= BO_UI_DIAG_BURST_TOTAL_USEC
	if not should_log:
		return
	if now - int(stats.get("last_log_msec", 0)) < BO_UI_DIAG_BURST_WINDOW_MSEC:
		return
	stats["last_log_msec"] = now
	_bo_ui_diag_cost_stats_by_scope[scope] = stats
	_bo_ui_diag_log("BURST", "scope=" + scope + " count=" + str(stats.get("count", 0)) + " total_us=" + str(stats.get("total_usec", 0)) + " max_us=" + str(stats.get("max_usec", 0)) + " window_ms=" + str(now - int(stats.get("start_msec", now))) + " " + _bo_ui_diag_extra_context(extra))


func _bo_ui_diag_log_input_event(event: InputEvent, source: String = "input") -> void:
	if not BO_UI_DIAG_ENABLED:
		return
	if event == null:
		return
	var is_key = event is InputEventKey
	var is_joy_button = event is InputEventJoypadButton
	var is_joy_motion = event is InputEventJoypadMotion
	if not is_key and not is_joy_button and not is_joy_motion:
		return
	if is_key and (not event.pressed or event.echo):
		return
	if is_joy_button and not event.pressed:
		return
	var actions = ["ui_up", "ui_down", "ui_left", "ui_right", "ui_accept", "ui_cancel", "ui_pause"]
	for i in range(8):
		actions.append("ui_up_" + str(i))
		actions.append("ui_down_" + str(i))
		actions.append("ui_left_" + str(i))
		actions.append("ui_right_" + str(i))
		actions.append("ui_accept_" + str(i))
		actions.append("ui_cancel_" + str(i))
		actions.append("ui_pause_" + str(i))
	var hits = []
	for action in actions:
		if InputMap.has_action(action) and event.is_action(action):
			hits.append(action)
	if hits.empty() and is_joy_motion:
		return
	_bo_ui_diag_input_count += 1
	var now = OS.get_ticks_msec()
	if _bo_ui_diag_input_window_start_msec <= 0 or now - _bo_ui_diag_input_window_start_msec > BO_UI_DIAG_INPUT_BURST_WINDOW_MSEC:
		_bo_ui_diag_input_window_start_msec = now
		_bo_ui_diag_input_window_count = 0
	_bo_ui_diag_input_window_count += 1
	_bo_ui_diag_last_input_summary = source + ":" + str(hits) + ":" + event.get_class()
	if _bo_ui_diag_input_window_count >= BO_UI_DIAG_INPUT_BURST_COUNT and now - _bo_ui_diag_last_input_burst_log_msec >= BO_UI_DIAG_INPUT_BURST_WINDOW_MSEC:
		_bo_ui_diag_last_input_burst_log_msec = now
		_bo_ui_diag_log("INPUT_BURST", "source=" + source + " count=" + str(_bo_ui_diag_input_window_count) + " window_ms=" + str(now - _bo_ui_diag_input_window_start_msec) + " hits=" + str(hits) + " screen=" + _get_current_menu_screen_fast() + " host=" + str(_is_game_host()) + " local_idx=" + str(_get_local_client_player_index()))


func _bo_ui_diag_process_tick(screen: String) -> void:
	if not BO_UI_DIAG_ENABLED:
		return
	if screen != _bo_ui_diag_last_screen:
		_bo_ui_diag_last_screen = screen
		_bo_ui_diag_last_focus_key = ""
		return
	var now = OS.get_ticks_msec()
	var queued = _queued_local_client_menu_messages.size() + _queued_local_run_page_action_messages.size() + _pending_shop_states_from_host.size()
	if queued < BO_UI_DIAG_QUEUE_WARN_COUNT:
		return
	var key = screen + ":" + str(_queued_local_client_menu_messages.size()) + ":" + str(_queued_local_run_page_action_messages.size()) + ":" + str(_pending_shop_states_from_host.size())
	if key == _bo_ui_diag_last_queue_key and now - _bo_ui_diag_last_queue_log_msec < BO_UI_DIAG_BURST_WINDOW_MSEC:
		return
	_bo_ui_diag_last_queue_key = key
	_bo_ui_diag_last_queue_log_msec = now
	_bo_ui_diag_log("QUEUE", "screen=" + screen + " queued_menu=" + str(_queued_local_client_menu_messages.size()) + " queued_run=" + str(_queued_local_run_page_action_messages.size()) + " pending_shop=" + str(_pending_shop_states_from_host.size()) + " host=" + str(_is_game_host()))


func _is_client_interactive_selection_screen(screen: String) -> bool:
	# Client can only drive vanilla focus/select on character and weapon pages.
	# Difficulty is Host-only, and unknown/transition pages must not call FocusEmulator.
	return screen == SCREEN_CHARACTER_SELECTION or screen == SCREEN_WEAPON_SELECTION

func _get_current_menu_screen_fast() -> String:
	var scene_path = _get_current_scene_resource_path()
	if scene_path == MenuData.game_scene:
		return SCREEN_GAME
	if _is_shop_scene_path(scene_path):
		return SCREEN_SHOP
	if scene_path == MenuData.character_selection_scene:
		return SCREEN_CHARACTER_SELECTION
	if scene_path == MenuData.weapon_selection_scene:
		return SCREEN_WEAPON_SELECTION
	if scene_path == MenuData.difficulty_selection_scene:
		return SCREEN_DIFFICULTY_SELECTION
	var current = get_tree().current_scene
	if _is_live_ref(current):
		var node_name = str(current.name).to_lower()
		if node_name.find("shop") != -1:
			return SCREEN_SHOP
		if node_name.find("character") != -1:
			return SCREEN_CHARACTER_SELECTION
		if node_name.find("weapon") != -1:
			return SCREEN_WEAPON_SELECTION
		if node_name.find("difficulty") != -1:
			return SCREEN_DIFFICULTY_SELECTION
	return SCREEN_NONE


func _is_selection_like_screen_fast(screen: String) -> bool:
	return screen == SCREEN_CHARACTER_SELECTION or screen == SCREEN_WEAPON_SELECTION or screen == SCREEN_DIFFICULTY_SELECTION



func begin_game_start_guard(start_id: int = 0, reason: String = "", preserve_queued_actions: bool = false) -> void:
	# Called as soon as a difficulty/shop game start handshake begins. From this point
	# old shop/upgrade UI nodes are transitional: do not scan them, do not queue focus
	# packets, and do not apply late reliable page-state packets from the previous scene.
	var now = OS.get_ticks_msec()
	var was_active = _is_game_start_guard_active()
	var same_start = was_active and start_id != 0 and start_id == _run_page_game_start_guard_start_id
	_run_page_game_start_guard_until_msec = max(_run_page_game_start_guard_until_msec, now + RUN_PAGE_GAME_START_GUARD_MSEC)
	_run_page_game_start_guard_start_id = start_id
	_run_page_game_start_guard_reason = reason

	# The same synced start is reported through prepare -> commit -> deferred scene apply.
	# Resetting runtime state and clearing FocusEmulators on every one of those phases
	# made the client do repeated shop->game transition work. Do it only for a new start.
	if not same_start:
		_reset_run_page_runtime_state_for_game_start(not preserve_queued_actions)
		if not _is_game_host():
			var current_screen = _get_current_menu_screen_fast()
			if current_screen != SCREEN_GAME:
				_clear_focus_emulators_before_client_scene_change(current_screen, SCREEN_GAME)
	var key = str(start_id) + ":" + reason
	if key != _run_page_game_start_guard_logged_key:
		_run_page_game_start_guard_logged_key = key

func _is_game_start_guard_active() -> bool:
	return OS.get_ticks_msec() < _run_page_game_start_guard_until_msec


func _end_game_start_guard(reason: String = "") -> void:
	if _run_page_game_start_guard_until_msec <= 0 and _run_page_game_start_guard_start_id == 0:
		return
	_run_page_game_start_guard_until_msec = 0
	_run_page_game_start_guard_start_id = 0
	_run_page_game_start_guard_reason = ""
	_run_page_game_start_guard_logged_key = ""


func _is_guarded_run_page_action(action_type: String) -> bool:
	return action_type.begins_with("shop") or action_type.begins_with("upgrade") or action_type.begins_with("item_box")


func _is_progression_run_page_action(action_type: String) -> bool:
	return action_type.begins_with("upgrade") or action_type.begins_with("item_box")


func should_accept_page_state_during_game_start_guard(kind: String, value: String = "") -> bool:
	# SteamLobbyManager has an earlier stale-packet guard. Give it the same wave-end
	# exception as receive_run_page_action_sync(): upgrade/item-box overlays live in
	# main.tscn, so they may legitimately arrive while the old shop->battle guard is
	# still counting down. Shop scene-state is accepted only once a progression overlay
	# is visible, which prevents old shop packets from bouncing the client back during
	# the actual battle load.
	if _get_current_menu_screen_fast() != SCREEN_GAME:
		return false
	if kind == "run_page_action":
		return _is_progression_run_page_action(value)
	if kind == "menu_scene" and value == SCREEN_SHOP:
		var progression_ui = _find_progression_ui(false)
		return _is_valid_progression_ui_visible(progression_ui)
	return false


func _reset_run_page_runtime_state_for_game_start(clear_queued_actions: bool = true) -> void:
	if clear_queued_actions:
		_queued_local_run_page_action_messages.clear()
	_pending_shop_states_from_host.clear()
	_local_shop_go_pending_until_by_player.clear()
	_last_local_shop_focus_key.clear()
	_last_shop_state_key = ""
	_last_shop_full_state_msec = 0
	_last_shop_focus_target_by_player.clear()
	_client_shop_intercept_key = ""
	_host_shop_go_intercept_key.clear()
	_host_shop_item_observer_key.clear()
	_shop_input_guard_instance_id = 0
	_shop_input_guard_until_msec = 0
	_shop_input_guard_wait_release = false
	_client_shop_direct_lock_probe_seq = 0
	_client_shop_lock_state_by_slot_key.clear()
	_last_client_shop_lock_poll_key = ""
	_last_applied_shop_gear_key_by_player.clear()
	_last_applied_shop_state_key_by_player.clear()
	_last_applied_shop_slots_key_by_player.clear()
	_last_applied_shop_run_data_key_by_player.clear()
	_host_shop_run_data_key_by_player.clear()
	_host_shop_run_data_cache_by_player.clear()
	_host_shop_run_data_cache_mode_by_player.clear()
	_host_shop_run_data_sent_key_by_player.clear()
	_host_shop_run_data_stamp_by_player.clear()
	_host_shop_run_data_dirty_by_player.clear()
	_shop_state_cache_instance_id = 0
	_missing_host_item_placeholder_cache.clear()
	_reset_shop_inventory_custom_button_runtime_state()
	_clear_all_client_shop_predictions()
	_client_progression_intercept_container_id = 0
	_last_local_run_page_focus_key.clear()
	_last_local_run_page_state_key_by_player.clear()
	_last_progression_options_processed_key = ""


func reset_online_session_state(reason: String = "") -> void:
	# Full per-room cleanup. This intentionally does not modify the player's real save data;
	# it only clears transient online mirrors, Host catalogs, pending authoritative states,
	# and local client identity cached from the previous lobby.
	_last_state_key = ""
	_last_state_from_host = {}
	_pending_state_from_host = {}
	_last_menu_scene_state_from_host = {}
	_pending_menu_scene_state_from_host = {}
	_last_client_scene_apply_key = ""
	_last_client_scene_apply_msec = 0
	_last_sent_local_focus_key = ""
	_last_sent_local_select_key = ""
	_last_local_selection_instance_id = 0
	_last_applied_run_config_key = ""
	_last_applied_difficulty_start_key = ""
	_local_client_steam_id = ""
	_last_availability_from_host = {}
	_pending_availability_from_host = {}
	_last_applied_availability_key = ""
	_host_catalog_by_screen.clear()
	_host_catalog_key_by_screen.clear()
	_host_catalog_player_key_by_screen.clear()
	_last_applied_catalog_key_by_screen.clear()
	_last_applied_catalog_player_key_by_inventory.clear()
	_host_built_catalog_by_screen.clear()
	_host_built_catalog_build_key_by_screen.clear()
	_host_dlc_gate_logged_missing_keys.clear()
	_dlc_safe_fallback_warning_keys.clear()
	_host_client_character_lookup_by_steam_id.clear()
	_host_client_item_lookup_by_steam_id.clear()
	_host_client_weapon_lookup_by_steam_id.clear()
	_host_client_character_catalog_key_by_steam_id.clear()
	_host_client_shop_content_catalog_key_by_steam_id.clear()
	_host_common_shop_fallback_cache.clear()
	_host_dlc_gate_catalog_dirty = false
	_last_host_dlc_gate_apply_key = ""
	_last_host_dlc_gate_log_key = ""
	_shop_state_cache_instance_id = 0
	_host_shop_run_data_key_by_player.clear()
	_host_shop_run_data_cache_by_player.clear()
	_host_shop_run_data_cache_mode_by_player.clear()
	_host_shop_run_data_sent_key_by_player.clear()
	_host_shop_run_data_stamp_by_player.clear()
	_host_shop_run_data_dirty_by_player.clear()
	_host_shop_initial_full_sent_instance_id = 0
	_host_shop_state_key_by_player.clear()
	_last_applied_shop_slots_key_by_player.clear()
	_last_applied_shop_run_data_key_by_player.clear()
	_missing_host_item_placeholder_cache.clear()
	_client_intercept_selection_instance_id = 0
	_queued_local_client_menu_messages.clear()
	_queued_local_run_page_action_messages.clear()
	_last_client_prime_key = ""
	_pending_client_prime_screen = ""
	_pending_client_prime_until_msec = 0
	_processed_run_page_action_ids.clear()
	_last_run_page_action_seq_by_origin.clear()
	_applying_remote_run_page_action = false
	_client_scene_change_in_flight_screen = ""
	_client_scene_change_in_flight_path = ""
	_client_scene_change_in_flight_until_msec = 0
	_client_scene_change_in_flight_logged_key = ""
	_run_page_game_start_guard_until_msec = 0
	_run_page_game_start_guard_start_id = 0
	_run_page_game_start_guard_reason = ""
	_run_page_game_start_guard_logged_key = ""
	_reset_run_page_runtime_state_for_game_start(true)
	restore_progress_mirror()


func has_host_catalog_for_screen(screen: String) -> bool:
	return _host_catalog_by_screen.has(screen)


func _ready() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	# Offline/single-player must remain completely vanilla.
	if not _is_online_session_active():
		return

	var now = OS.get_ticks_msec()
	if now - _last_state_poll_msec < STATE_POLL_INTERVAL_MSEC:
		return

	_last_state_poll_msec = now
	var process_start_usec = OS.get_ticks_usec()
	var fast_screen = _get_current_menu_screen_fast()
	_bo_ui_diag_process_tick(fast_screen)
	var t_scene = OS.get_ticks_usec()
	_try_apply_pending_menu_scene_state()
	_bo_ui_diag_log_cost("try_apply_pending_menu_scene", t_scene)

	if _is_game_start_guard_active():
		# During the handshake into main.tscn, the current shop/upgrade scene is stale.
		# Only authoritative scene changes may run; all page polling is suspended.
		_bo_ui_diag_log_cost("process_guarded", process_start_usec, "reason=game_start_guard")
		return

	if _is_selection_like_screen_fast(fast_screen):
		var t_selection = OS.get_ticks_usec()
		_enforce_focus_change_cancels_ready_on_current_selection()
		_poll_selection_state_change()
		_try_apply_online_catalog_to_current_selection()
		_try_apply_host_dlc_gate_to_current_selection(fast_screen)
		_try_apply_pending_client_prime_focus()
		_try_apply_pending_host_state()
		_bo_ui_diag_log_cost("selection_process_total", t_selection)
	elif fast_screen == SCREEN_SHOP:
		var t_shop = OS.get_ticks_usec()
		_poll_shop_page_state_and_intercepts()
		_bo_ui_diag_log_cost("shop_process_total", t_shop)
	elif fast_screen == SCREEN_GAME:
		# main.tscn can show the level-up / item-box overlay after a wave, but it must not
		# scan selection/catalog/shop trees during battle. Those recursive scans were the
		# measured 100ms+ client stalls.
		var t_progression = OS.get_ticks_usec()
		_poll_progression_page_focus_and_state()
		_bo_ui_diag_log_cost("progression_process_total", t_progression)
	else:
		# Transition / unknown scene: only apply pending authoritative scene changes.
		pass
	_bo_ui_diag_log_cost("process_total", process_start_usec, "branch=" + fast_screen)


func receive_menu_message(from_steam_id: String, message: Dictionary) -> void:
	# 未来 Steam P2P 收到菜单消息后直接调用这里。
	# 现在本地 mock 也复用同一套 apply 逻辑。
	var slot_manager = _get_slot_manager()
	if slot_manager == null:
		return

	var player_index = -1
	if slot_manager.has_method("get_player_index_for_steam_id"):
		player_index = int(slot_manager.get_player_index_for_steam_id(from_steam_id))

	if player_index < 0:
		return

	var msg_type = str(message.get("msg_type", ""))
	var item_id = message.get("item_id", message.get("item_id_hash", ""))

	if msg_type == "menu_focus":
		apply_remote_focus_by_item_id(player_index, item_id)
	elif msg_type == "select_character":
		apply_remote_select_by_item_id(player_index, item_id, "character_selection")
	elif msg_type == "select_weapon":
		apply_remote_select_by_item_id(player_index, item_id, "weapon_selection")
	elif msg_type == "select_difficulty":
		pass
	else:
		pass

func consume_local_client_menu_messages() -> Array:
	# Client 侧正常输入入口：让玩家用官方菜单焦点/确认操作，当前节点只把变化转成 P2P 菜单消息。
	# 注意：这里只用于 character_selection / weapon_selection。difficulty 仍然是 Host-only。
	var messages = []
	var fast_screen = _get_current_menu_screen_fast()
	if not _is_client_interactive_selection_screen(fast_screen):
		while not _queued_local_client_menu_messages.empty():
			messages.append(_queued_local_client_menu_messages.pop_front())
		return messages
	var selection = _find_current_selection_node()
	if selection == null:
		return messages

	var selection_instance_id = selection.get_instance_id()
	if selection_instance_id != _last_local_selection_instance_id:
		_last_local_selection_instance_id = selection_instance_id
		_last_sent_local_focus_key = ""
		_last_sent_local_select_key = ""

	var screen = _get_selection_screen(selection)
	if not _is_client_interactive_selection_screen(screen):
		# This includes difficulty_selection and transient/unknown selection nodes during scene changes.
		# Do not call _ensure_local_client_focus_exists() here; it drives FocusEmulator and can
		# clear a stale weapon-selection focused_control after the node has already been freed.
		_disable_selection_buttons(selection, true)
		return messages

	_disable_selection_buttons(selection, false)
	_try_apply_online_catalog_to_current_selection()

	var player_index = _get_local_client_player_index()
	if player_index < 0 or player_index >= RunData.get_player_count():
		return messages
	_enable_only_local_inventory_mouse_focus(selection, player_index)
	_configure_online_focus_emulator_input_owner(player_index, "selection_client")
	_install_client_press_intercept(selection, screen, player_index)
	_ensure_local_client_focus_exists(selection)

	while not _queued_local_client_menu_messages.empty():
		messages.append(_queued_local_client_menu_messages.pop_front())

	var focus_msg = _build_local_focus_current_message(selection, screen, player_index)
	if typeof(focus_msg) == TYPE_DICTIONARY and not focus_msg.empty():
		messages.append(focus_msg)

	# Selection is sent by _on_client_inventory_element_pressed before the vanilla selection
	# code can mark this client ready, avoiding a local green-check flash.
	return messages


func _build_local_focus_current_message(selection: Node, screen: String, player_index: int) -> Dictionary:
	var element = _get_latest_focused_element(selection, player_index)
	if not _is_live_ref(element):
		return {}

	var item_state = _element_to_state(element)
	if not _is_host_catalog_item_known(screen, player_index, item_state):
		return {}
	var item_id = _get_item_id_from_state(item_state)
	if item_id == "":
		return {}

	var key = screen + ":" + str(player_index) + ":" + item_id
	if key == _last_sent_local_focus_key:
		return {}

	_last_sent_local_focus_key = key
	return {
		"msg_type": "menu_focus",
		"screen": screen,
		"item_id": item_id,
		"item_id_hash": item_state.get("id_hash", ""),
		"item_log": item_state.get("log", "")
	}

func _get_item_id_from_state(item_state) -> String:
	if typeof(item_state) != TYPE_DICTIONARY:
		return ""
	var item_id = str(item_state.get("id", ""))
	if item_id != "":
		return item_id
	item_id = str(item_state.get("id_hash", ""))
	if item_id != "":
		return item_id
	return str(item_state.get("weapon_id_hash", ""))


func consume_local_run_page_action_messages() -> Array:
	# Called by SteamLobbyManager on both Host and Client. Keep this cheap because
	# SteamLobbyManager polls it every frame. Scene scanning is throttled and gated by
	# the current scene; queued button-signal actions are still returned immediately.
	var now = OS.get_ticks_msec()
	if _is_game_start_guard_active():
		var allowed_messages = []
		while not _queued_local_run_page_action_messages.empty():
			var queued = _queued_local_run_page_action_messages.pop_front()
			if typeof(queued) == TYPE_DICTIONARY and str(queued.get("action_type", "")) == "shop_go":
				allowed_messages.append(queued)
		return allowed_messages
	if now - _last_consume_run_page_scan_msec >= RUN_PAGE_CONSUME_SCAN_INTERVAL_MSEC:
		_last_consume_run_page_scan_msec = now
		var fast_screen = _get_current_menu_screen_fast()
		if fast_screen == SCREEN_SHOP:
			_poll_shop_page_state_and_intercepts()
		elif fast_screen == SCREEN_GAME:
			_poll_progression_page_focus_and_state()

	var messages = []
	while not _queued_local_run_page_action_messages.empty():
		messages.append(_queued_local_run_page_action_messages.pop_front())
	return messages


func receive_run_page_action_sync(from_steam_id: String, message: Dictionary, self_steam_id: String) -> Dictionary:
	var action_id = str(message.get("action_id", ""))
	if action_id != "":
		if _processed_run_page_action_ids.has(action_id):
			return {}
		if _is_stale_run_page_action(action_id):
			return {}
		_processed_run_page_action_ids[action_id] = OS.get_ticks_msec()
		_trim_processed_run_page_actions()

	var action_type = str(message.get("action_type", ""))
	if _is_game_start_guard_active() and _is_guarded_run_page_action(action_type):
		# Upgrade/item-box overlays live inside main.tscn and can legitimately appear
		# shortly after a synced shop->battle start (especially on short/final waves).
		# Do not let a late/duplicate screen=game scene-state re-arm the guard and drop
		# the authoritative wave-end progression packets.
		if _is_progression_run_page_action(action_type) and _get_current_menu_screen_fast() == SCREEN_GAME:
			_end_game_start_guard("accept_progression_action:" + action_type)
		else:
			return {}
	var origin_steam_id = str(message.get("origin_steam_id", ""))
	if origin_steam_id == "":
		origin_steam_id = from_steam_id
	if action_id == "" and _is_duplicate_mutating_run_page_action(message, origin_steam_id):
		return {}

	var player_index = _resolve_run_page_action_player_index(origin_steam_id, from_steam_id, self_steam_id, message)
	if player_index < 0:
		return {}
	if action_type == "shop_items_resync_request" and _is_game_host():
		player_index = int(message.get("requested_player_index", message.get("player_index", player_index)))

	# Focus packets are cosmetic. Clients ignore their own echoes; remote shop focus
	# is applied as visual-only FocusEmulator style without emitting vanilla focus signals.
	if (action_type == "shop_focus" or action_type == "upgrade_focus") and not _is_game_host() and origin_steam_id == self_steam_id:
		return {}

	_applying_remote_run_page_action = true
	var applied = false
	if action_type == "upgrade_focus":
		applied = _apply_progression_focus_action(player_index, message)
	elif action_type == "upgrade_select":
		if _is_game_host():
			applied = _apply_progression_select_action(player_index, message)
		else:
			applied = true
	elif action_type == "upgrade_reroll":
		if _is_game_host():
			applied = _apply_progression_reroll_action(player_index, message)
		else:
			applied = true
	elif action_type == "upgrade_state":
		applied = true
	elif action_type == "shop_state":
		applied = true
	elif action_type == "shop_items_resync_request":
		applied = true
	elif action_type == "item_box_take":
		if _is_game_host():
			applied = _apply_progression_item_box_action(player_index, message, "take")
		else:
			applied = true
	elif action_type == "item_box_discard":
		if _is_game_host():
			applied = _apply_progression_item_box_action(player_index, message, "discard")
		else:
			applied = true
	elif action_type == "item_box_ban":
		if _is_game_host():
			applied = _apply_progression_item_box_action(player_index, message, "ban")
		else:
			applied = true
	elif action_type == "shop_focus":
		applied = _apply_shop_focus_visual_action(player_index, message)
	elif action_type == "shop_buy":
		if _is_game_host():
			applied = _apply_shop_buy_action(player_index, message)
		else:
			applied = true
	elif action_type == "shop_combine_weapon":
		if _is_game_host():
			applied = _apply_shop_combine_weapon_action(player_index, message)
		else:
			applied = true
	elif action_type == "shop_discard_weapon":
		if _is_game_host():
			applied = _apply_shop_discard_weapon_action(player_index, message)
		else:
			applied = true
	elif action_type == "shop_reroll":
		if _is_game_host():
			applied = _apply_shop_reroll_action(player_index, message)
		else:
			applied = true
	elif action_type == "shop_go":
		if _is_game_host():
			applied = _apply_shop_go_action(player_index, message)
		else:
			applied = true
	elif action_type == "shop_lock":
		if _is_game_host():
			applied = _apply_shop_lock_action(player_index, message)
		else:
			applied = true
	elif action_type == SHOP_CUSTOM_POPUP_BUTTON_ACTION:
		if not _is_game_host() and origin_steam_id == self_steam_id:
			applied = true
		else:
			applied = _apply_shop_inventory_custom_popup_button_action(player_index, message)
	else:
		pass
	_applying_remote_run_page_action = false

	if _is_game_host():
		if action_type == SHOP_CUSTOM_POPUP_BUTTON_ACTION:
			# Third-party inventory popup buttons are replayed as local UI presses only.
			# Do not attach a shop_state payload to this generic compatibility packet.
			return {}
		if action_type == "shop_focus":
			# Focus is visual-only and high-frequency; relay the packet without attaching
			# a full shop_state payload.
			return {}
		if action_type == "shop_items_resync_request":
			if _should_use_endless_incremental_items_only_shop_sync():
				return {}
			var resync_state = _build_shop_items_resync_state(player_index)
			return resync_state
		if action_type.begins_with("shop_"):
			var is_remote_origin = origin_steam_id != "" and origin_steam_id != self_steam_id
			if is_remote_origin and action_type == "shop_go":
				# Do not restore Host-local focus after remote shop actions. That focus repair
				# can trigger Host GoButton.focus_exited and cancel an already-ready Host.
				# Reassert the authoritative post-toggle state; a second Go press is a cancel.
				var shop_after_go = _find_shop_node()
				var pressed_after_go = false
				if _is_valid_shop_node(shop_after_go):
					pressed_after_go = bool(_get_node_array_value(shop_after_go, "_player_pressed_go_button", player_index, false))
				call_deferred("_force_shop_go_visual_state_for_player", player_index, pressed_after_go)
			var shop_delta = _build_shop_action_delta_state(player_index, action_type, message, applied)
			return shop_delta

		# Focus is high-frequency and must not carry authoritative option state back.
		# Otherwise old focus packets can arrive after a select/reroll and reopen a stale upgrade page on Client.
		if action_type == "upgrade_focus":
			return {}

		var ui = _find_progression_ui(true)
		var host_state = _build_progression_visible_option(player_index, ui)
		var all_states = _build_all_progression_visible_options(ui)
		if not host_state.empty():
			_last_local_run_page_state_key_by_player[player_index] = str(player_index) + ":" + to_json(host_state)
			if not all_states.empty():
				host_state["all_player_states"] = all_states
		return host_state

	if action_type.begins_with("shop_"):
		if action_type == SHOP_CUSTOM_POPUP_BUTTON_ACTION:
			return {}
		if action_type == "shop_focus":
			# Already applied above. Do not apply a second time on clients; double refreshes
			# can race popup hide/show and make navigation appear to skip.
			return {}
		var shop_states_after = message.get("host_shop_states_after", message.get("host_states_after", []))
		if typeof(shop_states_after) == TYPE_ARRAY and not shop_states_after.empty():
			_apply_or_queue_shop_states(shop_states_after, message)
		else:
			var shop_state_after = message.get("host_shop_state_after", message.get("host_state_after", message.get("state_after", {})))
			if typeof(shop_state_after) == TYPE_DICTIONARY and not shop_state_after.empty():
				_apply_or_queue_shop_states([shop_state_after], message)
		if action_type == "shop_combine_weapon" or action_type == "shop_discard_weapon":
			_close_shop_popup_for_player(_find_shop_node(), player_index, message)
		return {}

	var applied_any_state = false
	var all_states_after = message.get("host_states_after", [])
	if typeof(all_states_after) == TYPE_ARRAY and not all_states_after.empty():
		for state in all_states_after:
			if typeof(state) != TYPE_DICTIONARY:
				continue
			var state_player_index = int(state.get("player_index", player_index))
			if _apply_progression_visible_option_to_ui(state_player_index, state):
				applied_any_state = true
	else:
		var state_after = message.get("host_state_after", message.get("state_after", {}))
		if typeof(state_after) == TYPE_DICTIONARY and not state_after.empty():
			applied_any_state = _apply_progression_visible_option_to_ui(player_index, state_after)
	if action_type == "upgrade_focus":
		_apply_progression_focus_action(player_index, message)
	return {}


func _poll_shop_page_state_and_intercepts() -> void:
	if _is_game_start_guard_active():
		return
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		_reset_shop_state_diff_cache()
		_last_shop_state_key = ""
		_last_shop_full_state_msec = 0
		_last_local_shop_focus_key.clear()
		_client_shop_intercept_key = ""
		_host_shop_go_intercept_key.clear()
		_host_shop_item_observer_key.clear()
		_shop_input_guard_instance_id = 0
		_shop_input_guard_until_msec = 0
		_shop_input_guard_wait_release = false
		_client_shop_lock_state_by_slot_key.clear()
		_last_client_shop_lock_poll_key = ""
		_last_applied_shop_gear_key_by_player.clear()
		_last_applied_shop_state_key_by_player.clear()
		_reset_shop_inventory_custom_button_runtime_state()
		_clear_all_client_shop_predictions()
		return

	_ensure_shop_state_diff_cache_for_instance(shop)

	if _is_game_host():
		# Host shop navigation remains vanilla except GoButton final-start, which must
		# be delayed through the same scene-ready handshake as difficulty start.
		# In mixed local+online rooms the Host can own multiple local players; all of
		# those local FocusEmulators must keep processing input, while Steam placeholders
		# stay visual-only.
		_pending_shop_states_from_host = []
		var host_player_indices = _get_host_local_player_indices()
		_configure_online_focus_emulator_input_owners(host_player_indices, "shop_host")
		for host_player_index in host_player_indices:
			_ensure_shop_inventory_popup_wiring_for_player(shop, int(host_player_index), false)
			_queue_shop_focus_if_changed(int(host_player_index))
		_install_host_shop_go_sync_intercept(shop)
		_install_host_shop_local_mutation_observer(shop)
		_queue_shop_state_if_changed()
		_debug_host_shop_focus_snapshot(shop)
		return

	_try_apply_pending_shop_state()

	var local_player_index = _get_local_client_player_index()
	if local_player_index < 0:
		return
	_configure_online_focus_emulator_input_owner(local_player_index, "shop_client")
	# Client shop movement stays vanilla; this manager only intercepts mutating actions.
	_install_client_shop_intercepts(shop, local_player_index)
	_ensure_shop_inventory_popup_wiring_for_player(shop, local_player_index, true)
	_queue_shop_focus_if_changed(local_player_index)
	_poll_client_shop_lock_state_changes(shop, local_player_index)


func _debug_host_shop_focus_snapshot(shop: Node) -> void:
	if not ENABLE_HOST_SHOP_DIAGNOSTICS:
		return
	if not _is_game_host() or not _is_valid_shop_node(shop):
		return
	var now = OS.get_ticks_msec()
	# Print rarely; this is a diagnostic guard for the current Host-shop issue.
	if now - int(_last_host_shop_focus_repair_msec) < 1500:
		return
	_last_host_shop_focus_repair_msec = now
	var player_index = _get_host_local_player_index()
	var focus_emulator = Utils.get_focus_emulator(player_index) if player_index >= 0 else null
	var focused = _safe_get(focus_emulator, "focused_control", null) if _is_live_ref(focus_emulator) else null
	var device = int(_safe_get(focus_emulator, "_device", -999)) if _is_live_ref(focus_emulator) else -999
	var process_input = focus_emulator.is_processing_input() if _is_live_ref(focus_emulator) else false
	var visible = focus_emulator.visible if (_is_live_ref(focus_emulator) and focus_emulator is CanvasItem) else false
	var raw_count = 0
	var raw_all_items = _safe_get(shop, "_shop_items", [])
	if typeof(raw_all_items) == TYPE_ARRAY and player_index >= 0 and player_index < raw_all_items.size() and typeof(raw_all_items[player_index]) == TYPE_ARRAY:
		raw_count = raw_all_items[player_index].size()
	var node_count = 0
	var active_count = 0
	var container = shop._get_shop_items_container(player_index) if player_index >= 0 and shop.has_method("_get_shop_items_container") else null
	if _is_live_ref(container):
		var nodes = _safe_get(container, "_shop_items", [])
		if typeof(nodes) == TYPE_ARRAY:
			node_count = nodes.size()
			for item_node in nodes:
				if _is_live_ref(item_node) and bool(_safe_get(item_node, "active", false)):
					active_count += 1


func _reset_shop_state_diff_cache() -> void:
	# Client can receive the Host's first shop_state before CoopShop has finished
	# entering the tree. Do not drop that pending payload during the transient
	# no-shop-node frames, or the client keeps its locally generated random shop.
	var preserve_pending_shop_state = _should_preserve_pending_shop_state_for_scene_transition()
	_shop_state_cache_instance_id = 0
	_host_shop_run_data_key_by_player.clear()
	_host_shop_run_data_cache_by_player.clear()
	_host_shop_run_data_cache_mode_by_player.clear()
	_host_shop_run_data_sent_key_by_player.clear()
	_host_shop_run_data_stamp_by_player.clear()
	_host_shop_run_data_dirty_by_player.clear()
	_host_shop_initial_full_sent_instance_id = 0
	_host_shop_state_key_by_player.clear()
	_last_applied_shop_slots_key_by_player.clear()
	_last_applied_shop_run_data_key_by_player.clear()
	_last_applied_shop_gear_key_by_player.clear()
	_last_applied_shop_state_key_by_player.clear()
	_reset_shop_inventory_custom_button_runtime_state(false)
	if not preserve_pending_shop_state:
		_pending_shop_states_from_host = []
	_last_shop_state_key = ""
	_last_shop_full_state_msec = 0


func _should_preserve_pending_shop_state_for_scene_transition() -> bool:
	if _is_game_host():
		return false
	if typeof(_pending_shop_states_from_host) != TYPE_ARRAY or _pending_shop_states_from_host.empty():
		return false
	if _get_current_menu_screen_fast() == SCREEN_SHOP:
		return true
	if _client_scene_change_in_flight_screen == SCREEN_SHOP:
		return true
	if typeof(_pending_menu_scene_state_from_host) == TYPE_DICTIONARY and str(_pending_menu_scene_state_from_host.get("screen", "")) == SCREEN_SHOP:
		return true
	if typeof(_last_menu_scene_state_from_host) == TYPE_DICTIONARY and str(_last_menu_scene_state_from_host.get("screen", "")) == SCREEN_SHOP:
		return true
	return false


func _ensure_shop_state_diff_cache_for_instance(shop: Node) -> void:
	if not _is_valid_shop_node(shop):
		return
	var instance_id = int(shop.get_instance_id())
	if _shop_state_cache_instance_id == instance_id:
		return
	# A new CoopShop instance must reset applied/diff caches, but a Client may already
	# have the Host's first full shop_state queued from menu_scene_state/run_page_action_sync.
	# Keep that queue so it can overwrite the local vanilla RNG shop as soon as this
	# instance is ready. Host never consumes this queue and may clear it.
	var preserve_pending_shop_state = not _is_game_host() and typeof(_pending_shop_states_from_host) == TYPE_ARRAY and not _pending_shop_states_from_host.empty()
	_shop_state_cache_instance_id = instance_id
	_host_shop_run_data_key_by_player.clear()
	_host_shop_run_data_cache_by_player.clear()
	_host_shop_run_data_cache_mode_by_player.clear()
	_host_shop_run_data_sent_key_by_player.clear()
	_host_shop_run_data_stamp_by_player.clear()
	_host_shop_run_data_dirty_by_player.clear()
	_host_shop_initial_full_sent_instance_id = 0
	_host_shop_state_key_by_player.clear()
	_last_applied_shop_slots_key_by_player.clear()
	_last_applied_shop_run_data_key_by_player.clear()
	_last_applied_shop_gear_key_by_player.clear()
	_last_applied_shop_state_key_by_player.clear()
	_reset_shop_inventory_custom_button_runtime_state(false)
	if not preserve_pending_shop_state:
		_pending_shop_states_from_host = []
	_last_shop_state_key = ""
	_last_shop_full_state_msec = 0


func _record_host_shop_state_baselines_from_states(states: Array) -> void:
	if not _is_game_host() or typeof(states) != TYPE_ARRAY:
		return
	for state in states:
		if typeof(state) == TYPE_DICTIONARY:
			_record_host_shop_state_baseline_from_state(state)


func _record_host_shop_state_baseline_from_state(state: Dictionary) -> void:
	if not _is_game_host() or typeof(state) != TYPE_DICTIONARY or state.empty():
		return
	var player_index = int(state.get("player_index", -1))
	if player_index < 0:
		return
	var key = _build_shop_state_prediction_key_from_state(state)
	if key != "":
		_host_shop_state_key_by_player[player_index] = key


func _record_host_shop_player_state_baseline(player_index: int, shop: Node = null) -> void:
	if not _is_game_host() or player_index < 0:
		return
	if shop == null:
		shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return
	var state = _build_shop_player_state(player_index, shop, false)
	if typeof(state) == TYPE_DICTIONARY and not state.empty():
		_record_host_shop_state_baseline_from_state(state)


func mark_menu_scene_shop_state_sent(scene_state: Dictionary = {}) -> void:
	# menu_scene_state already carried the initial full shop UI state for this CoopShop
	# instance. Mark it as the initial snapshot so the later polling path only sends
	# compact deltas, avoiding a second large run_page_action_sync right after scene entry.
	if not _is_game_host():
		return
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return
	var shop_instance_id = int(shop.get_instance_id())
	_host_shop_initial_full_sent_instance_id = shop_instance_id
	_last_shop_full_state_msec = OS.get_ticks_msec()
	var shop_state = scene_state.get("shop_state", {}) if typeof(scene_state) == TYPE_DICTIONARY else {}
	var states = []
	if typeof(shop_state) == TYPE_DICTIONARY:
		var players = shop_state.get("players", [])
		if typeof(players) == TYPE_ARRAY:
			states = players
	if states.empty():
		states = _build_all_shop_player_states(false)
	_last_shop_state_key = to_json(states)
	_record_host_shop_state_baselines_from_states(states)


func _strip_run_data_from_shop_states_for_menu_scene(states: Array) -> Array:
	# In menu_scene_state, run_config.players[].run_data is applied before change_scene().
	# shop_state still needs the shop slots/scalars for UI, but carrying run_data again
	# doubles the large inventory/effects payload on high-wave runs.
	var result = []
	if typeof(states) != TYPE_ARRAY:
		return result
	for state in states:
		if typeof(state) != TYPE_DICTIONARY:
			continue
		var slim = state.duplicate(true)
		slim.erase("run_data")
		slim["run_data_full"] = false
		slim["run_data_source"] = "run_config"
		result.append(slim)
	return result


func _queue_shop_state_if_changed() -> void:
	# Full shop snapshots are sent only as the initial shop payload (menu_scene_state).
	# After that, this polling path emits compact per-player delta snapshots only when
	# the Host-visible shop state actually changes. This prevents the old 600KB+ reliable
	# full shop_state from being queued every few seconds on high-wave runs.
	if not _is_game_host():
		return
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return

	var now = OS.get_ticks_msec()
	var shop_instance_id = int(shop.get_instance_id())
	if _host_shop_initial_full_sent_instance_id != shop_instance_id:
		if _should_use_endless_incremental_items_only_shop_sync():
			# The scene transition already carried shop slots plus incremental/runtime run data.
			# From endless wave 21 onward do not build a separate initial full shop_state.
			_host_shop_initial_full_sent_instance_id = shop_instance_id
			_last_shop_full_state_msec = now
			_last_shop_state_key = "late_endless_incremental_only:" + str(shop_instance_id)
			return
		var initial_states = _build_all_shop_player_states(true)
		if initial_states.empty():
			return
		for state in initial_states:
			if typeof(state) == TYPE_DICTIONARY:
				state["full_snapshot"] = true
				state["delta_snapshot"] = false
				state["shop_delta"] = false
		_host_shop_initial_full_sent_instance_id = shop_instance_id
		_last_shop_full_state_msec = now
		_last_shop_state_key = to_json(initial_states)
		_record_host_shop_state_baselines_from_states(initial_states)
		# Do not also broadcast a separate initial full shop_state here.
		# The scene transition packet already carries shop_state slots/scalars, and
		# run_config carries the authoritative run data. Sending both was a 400KB+
		# duplicate reliable packet before every shop.
		return

	if _should_use_endless_incremental_items_only_shop_sync():
		# Late endless uses explicit action deltas only. This avoids rebuilding per-player
		# shop state and comparing held-item/run-data keys every second inside the shop.
		return

	if _last_shop_full_state_msec > 0 and now - int(_last_shop_full_state_msec) < SHOP_DELTA_STATE_INTERVAL_MSEC:
		return
	_last_shop_full_state_msec = now

	var changed_states = []
	var changed_players = []
	for player_index in range(_get_run_player_count()):
		var state = _build_shop_player_state(player_index, shop, false)
		if typeof(state) != TYPE_DICTIONARY or state.empty():
			continue
		var key = _build_shop_state_prediction_key_from_state(state)
		if key == "":
			continue
		var prev_key = str(_host_shop_state_key_by_player.get(player_index, ""))
		if prev_key == "":
			_host_shop_state_key_by_player[player_index] = key
			continue
		if key == prev_key:
			continue
		_host_shop_state_key_by_player[player_index] = key
		state["full_snapshot"] = false
		state["delta_snapshot"] = true
		changed_states.append(state)
		changed_players.append(player_index)

	if changed_states.empty():
		return

	_last_shop_state_key = to_json(changed_states)
	_queue_local_run_page_action({
		"msg_type": "run_page_action_sync",
		"action_type": "shop_state",
		"screen": "shop",
		"player_index": 0,
		"host_states_after": changed_states,
		"state_after": {"mode": "shop", "players": changed_states, "delta_snapshot": true},
		"delta_snapshot": true,
		"full_snapshot": false
	})


func _queue_shop_focus_if_changed(player_index: int) -> void:
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return
	var target = _get_current_shop_focus_target(shop, player_index)
	if target == "":
		return
	var key = str(player_index) + ":" + target
	if key == str(_last_local_shop_focus_key.get(player_index, "")):
		return
	_last_local_shop_focus_key[player_index] = key
	_queue_local_run_page_action({
		"msg_type": "run_page_action_sync",
		"action_type": "shop_focus",
		"screen": "shop",
		"player_index": player_index,
		"target": target,
		"shop_index": _shop_target_to_index(target)
	})


func _install_host_shop_go_sync_intercept(shop: Node) -> void:
	if not _is_game_host() or not _is_valid_shop_node(shop):
		return
	for raw_player_index in _get_host_local_player_indices():
		var player_index = int(raw_player_index)
		if player_index < 0:
			continue
		var go_button = shop._get_go_button(player_index) if shop.has_method("_get_go_button") else null
		if not _is_live_ref(go_button):
			continue
		var key = str(shop.get_instance_id()) + ":" + str(player_index)
		if key == str(_host_shop_go_intercept_key.get(player_index, "")):
			continue
		_host_shop_go_intercept_key[player_index] = key
		if go_button.is_connected("pressed", shop, "_on_GoButton_pressed"):
			go_button.disconnect("pressed", shop, "_on_GoButton_pressed")
		if not go_button.is_connected("pressed", self, "_on_host_shop_go_pressed"):
			go_button.connect("pressed", self, "_on_host_shop_go_pressed", [player_index])


func _on_host_shop_go_pressed(player_index: int) -> void:
	if not _is_game_host() or _applying_remote_run_page_action:
		return
	var msg = {
		"msg_type": "run_page_action_sync",
		"action_type": "shop_go",
		"screen": "shop",
		"player_index": player_index,
		"target": "go",
		"shop_index": -1
	}
	_apply_host_local_shop_action(msg, "go")


func _install_host_shop_local_mutation_observer(shop: Node) -> void:
	if not _is_game_host() or not _is_valid_shop_node(shop):
		return
	for raw_player_index in _get_host_local_player_indices():
		var player_index = int(raw_player_index)
		if player_index < 0:
			continue
		var key = str(shop.get_instance_id()) + ":" + str(player_index)
		if key == str(_host_shop_item_observer_key.get(player_index, "")):
			continue
		_host_shop_item_observer_key[player_index] = key

		var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
		if _is_live_ref(container):
			if not container.is_connected("shop_item_bought", self, "_on_host_shop_item_bought_observed"):
				container.connect("shop_item_bought", self, "_on_host_shop_item_bought_observed", [player_index])
			if not container.is_connected("shop_item_stolen", self, "_on_host_shop_item_stolen_observed"):
				container.connect("shop_item_stolen", self, "_on_host_shop_item_stolen_observed", [player_index])

		# Combine/discard also mutate Host-local RunData. Observing them is cheap and keeps
		# the remote gear panel current without taking over vanilla Host shop behavior.
		var item_popup = shop._get_item_popup(player_index) if shop.has_method("_get_item_popup") else null
		if _is_live_ref(item_popup):
			if not item_popup.is_connected("item_combine_button_pressed", self, "_on_host_shop_inventory_mutation_observed"):
				item_popup.connect("item_combine_button_pressed", self, "_on_host_shop_inventory_mutation_observed", [player_index, "shop_combine_weapon"])
			if not item_popup.is_connected("item_discard_button_pressed", self, "_on_host_shop_inventory_mutation_observed"):
				item_popup.connect("item_discard_button_pressed", self, "_on_host_shop_inventory_mutation_observed", [player_index, "shop_discard_weapon"])


func _on_host_shop_item_bought_observed(shop_item, player_index: int) -> void:
	if not _is_game_host() or _applying_remote_run_page_action:
		return
	var item_data = _safe_get(shop_item, "item_data", null) if _is_live_ref(shop_item) else null
	var slot_index = _get_shop_item_index(shop_item, player_index) if _is_live_ref(shop_item) else -1
	_schedule_host_local_shop_state_sync(player_index, "shop_buy", "host_buy", _get_item_id_for_log(item_data), _serialize_item_parent_data(item_data), slot_index)


func _on_host_shop_item_stolen_observed(shop_item, player_index: int) -> void:
	if not _is_game_host() or _applying_remote_run_page_action:
		return
	var item_data = _safe_get(shop_item, "item_data", null) if _is_live_ref(shop_item) else null
	var slot_index = _get_shop_item_index(shop_item, player_index) if _is_live_ref(shop_item) else -1
	_schedule_host_local_shop_state_sync(player_index, "shop_buy", "host_steal", _get_item_id_for_log(item_data), _serialize_item_parent_data(item_data), slot_index)


func _on_host_shop_inventory_mutation_observed(_item_data, player_index: int, action_type: String) -> void:
	if not _is_game_host() or _applying_remote_run_page_action:
		return
	_schedule_host_local_shop_state_sync(player_index, action_type, "host_inventory_mutation", _get_item_id_for_log(_item_data), _serialize_item_parent_data(_item_data), -1)


func _schedule_host_local_shop_state_sync(player_index: int, source_action_type: String, reason: String, item_log: String = "", item_state: Dictionary = {}, slot_index: int = -1) -> void:
	if player_index < 0:
		return
	call_deferred("_deferred_broadcast_host_local_shop_state", player_index, source_action_type, reason, item_log, item_state, slot_index)


func _deferred_broadcast_host_local_shop_state(player_index: int, source_action_type: String, reason: String, item_log: String = "", item_state: Dictionary = {}, slot_index: int = -1) -> void:
	if not _is_game_host():
		return
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop) or player_index < 0:
		return

	# Host-local vanilla mutations are already applied locally; broadcast only the
	# authoritative compact delta now. The 2s periodic shop_state is the full RunData
	# repair path, so this no longer serializes every player's inventory per action.
	if source_action_type == "shop_buy" or source_action_type == "shop_combine_weapon" or source_action_type == "shop_discard_weapon":
		_mark_host_shop_run_data_dirty(player_index)
	_last_shop_state_key = ""
	var synthetic = {
		"action_type": source_action_type,
		"player_index": player_index,
		"shop_index": slot_index,
		"resolved_shop_index": slot_index,
		"resolved_item": item_state,
		"item": item_state,
		"item_log": item_log,
		"steal": reason == "host_steal"
	}
	var state_after = _build_shop_action_delta_state(player_index, source_action_type, synthetic, true)
	if state_after.empty():
		return
	_queue_local_run_page_action({
		"msg_type": "run_page_action_sync",
		"action_type": source_action_type,
		"screen": "shop",
		"player_index": player_index,
		"host_state_after": state_after,
		"state_after": state_after,
		"source_action_type": source_action_type,
		"item_log": item_log
	})


func _apply_shop_focus_visual_action(player_index: int, message: Dictionary) -> bool:
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop) or player_index < 0:
		return false
	var target = str(message.get("target", ""))
	if target == "" and message.has("shop_index"):
		var idx = int(message.get("shop_index", -1))
		if idx >= 0:
			target = "item_" + str(idx)
	if target == "":
		return false
	var control = _get_control_for_shop_target(shop, player_index, target)
	if not _is_live_ref(control):
		return false
	var focus_emulator = Utils.get_focus_emulator(player_index)
	if not _is_live_ref(focus_emulator):
		return false
	var previous_target = str(_last_shop_focus_target_by_player.get(player_index, ""))
	if previous_target == "":
		previous_target = _get_current_shop_focus_target(shop, player_index)
	# Use vanilla style placement without signal emission, then update the coop shop
	# popups manually. Calling the FocusEmulator property setter here can emit a
	# focus_exited signal with a null/stale previous control after buy/reroll.
	if not _set_focus_emulator_control_safely(focus_emulator, control):
		return false
	# Refresh tooltip even if the target string did not change. After a buy/reroll/
	# combine the target key can remain item_0/weapon_0 while the underlying data
	# and popup content changed.
	_apply_shop_focus_popup_side_effects(shop, player_index, previous_target, target, true)
	_last_shop_focus_target_by_player[player_index] = target
	return true


func _install_client_shop_intercepts(shop: Node, player_index: int) -> void:
	if not _is_valid_shop_node(shop):
		return
	var key = str(shop.get_instance_id()) + ":" + str(player_index)
	if key == _client_shop_intercept_key:
		return
	_client_shop_intercept_key = key

	var reroll_button = shop._get_reroll_button(player_index) if shop.has_method("_get_reroll_button") else null
	if _is_live_ref(reroll_button):
		if reroll_button.is_connected("pressed", shop, "_on_RerollButton_pressed"):
			reroll_button.disconnect("pressed", shop, "_on_RerollButton_pressed")
		if not reroll_button.is_connected("pressed", self, "_on_client_shop_reroll_pressed"):
			reroll_button.connect("pressed", self, "_on_client_shop_reroll_pressed", [player_index])

	var go_button = shop._get_go_button(player_index) if shop.has_method("_get_go_button") else null
	if _is_live_ref(go_button):
		if go_button.is_connected("pressed", shop, "_on_GoButton_pressed"):
			go_button.disconnect("pressed", shop, "_on_GoButton_pressed")
		# Online shop readiness is authoritative through shop_go/shop_state. The vanilla
		# focus_exited handler clears the ready checkmark whenever our focus repair/router
		# moves away from GoButton, which makes readiness flash and immediately disappear.
		if go_button.is_connected("focus_exited", shop, "_on_GoButton_focus_exited"):
			go_button.disconnect("focus_exited", shop, "_on_GoButton_focus_exited")
		if not go_button.is_connected("pressed", self, "_on_client_shop_go_pressed"):
			go_button.connect("pressed", self, "_on_client_shop_go_pressed", [player_index])

	var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
	if _is_live_ref(container):
		# Disconnect container -> shop mutations, then also intercept ShopItem -> container
		# button signals so the Client does not locally deactivate/repack shop items
		# before the Host confirms the operation. This avoids post-buy index drift.
		if container.is_connected("shop_item_bought", shop, "on_shop_item_bought"):
			container.disconnect("shop_item_bought", shop, "on_shop_item_bought")
		if not container.is_connected("shop_item_bought", self, "_on_client_shop_item_bought"):
			container.connect("shop_item_bought", self, "_on_client_shop_item_bought", [player_index])
		if container.is_connected("shop_item_stolen", shop, "on_shop_item_stolen"):
			container.disconnect("shop_item_stolen", shop, "on_shop_item_stolen")
		if not container.is_connected("shop_item_stolen", self, "_on_client_shop_item_stolen"):
			container.connect("shop_item_stolen", self, "_on_client_shop_item_stolen", [player_index])
		if container.is_connected("shop_item_banned", shop, "on_shop_item_banned"):
			container.disconnect("shop_item_banned", shop, "on_shop_item_banned")
		if not container.is_connected("shop_item_banned", self, "_on_client_shop_item_banned"):
			container.connect("shop_item_banned", self, "_on_client_shop_item_banned", [player_index])

		_intercept_client_shop_item_buttons(container, player_index)

	var item_popup = shop._get_item_popup(player_index) if shop.has_method("_get_item_popup") else null
	if _is_live_ref(item_popup):
		if item_popup.is_connected("item_combine_button_pressed", shop, "_on_item_combine_button_pressed"):
			item_popup.disconnect("item_combine_button_pressed", shop, "_on_item_combine_button_pressed")
		if not item_popup.is_connected("item_combine_button_pressed", self, "_on_client_shop_combine_weapon_pressed"):
			item_popup.connect("item_combine_button_pressed", self, "_on_client_shop_combine_weapon_pressed", [player_index])
		if item_popup.is_connected("item_discard_button_pressed", shop, "_on_item_discard_button_pressed"):
			item_popup.disconnect("item_discard_button_pressed", shop, "_on_item_discard_button_pressed")
		if not item_popup.is_connected("item_discard_button_pressed", self, "_on_client_shop_discard_weapon_pressed"):
			item_popup.connect("item_discard_button_pressed", self, "_on_client_shop_discard_weapon_pressed", [player_index])

	_seed_client_shop_lock_state_baseline(shop, player_index)


func _seed_client_shop_lock_state_baseline(shop: Node, player_index: int) -> void:
	if _is_game_host() or not _is_valid_shop_node(shop):
		return
	var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
	if not _is_live_ref(container):
		return
	var shop_item_nodes = _safe_get(container, "_shop_items", [])
	if typeof(shop_item_nodes) != TYPE_ARRAY:
		return
	for slot_index in range(shop_item_nodes.size()):
		var shop_item = shop_item_nodes[slot_index]
		if not _is_live_ref(shop_item):
			continue
		var item_data = _safe_get(shop_item, "item_data", null)
		if item_data == null:
			continue
		var slot_key = _build_client_shop_lock_slot_key(shop, player_index, slot_index, item_data)
		if slot_key == "":
			continue
		_client_shop_lock_state_by_slot_key[slot_key] = bool(_safe_get(shop_item, "locked", false))


func _poll_client_shop_lock_state_changes(shop: Node, player_index: int) -> void:
	if _is_game_host() or _applying_remote_run_page_action:
		return
	if not _is_valid_shop_node(shop) or player_index < 0:
		return
	if RunData.get_player_effect_bool(Keys.disable_item_locking_hash, player_index):
		return
	var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
	if not _is_live_ref(container):
		return
	var shop_item_nodes = _safe_get(container, "_shop_items", [])
	if typeof(shop_item_nodes) != TYPE_ARRAY:
		return
	var live_keys = {}
	for slot_index in range(shop_item_nodes.size()):
		var shop_item = shop_item_nodes[slot_index]
		if not _is_live_ref(shop_item):
			continue
		if not bool(_safe_get(shop_item, "active", false)):
			continue
		var item_data = _safe_get(shop_item, "item_data", null)
		if item_data == null:
			continue
		if not bool(_safe_get(item_data, "is_lockable", true)):
			continue
		var slot_key = _build_client_shop_lock_slot_key(shop, player_index, slot_index, item_data)
		if slot_key == "":
			continue
		live_keys[slot_key] = true
		var locked = bool(_safe_get(shop_item, "locked", false))
		if not _client_shop_lock_state_by_slot_key.has(slot_key):
			_client_shop_lock_state_by_slot_key[slot_key] = locked
			continue
		var prev_locked = bool(_client_shop_lock_state_by_slot_key[slot_key])
		if prev_locked == locked:
			continue
		_client_shop_lock_state_by_slot_key[slot_key] = locked
		var msg = _build_client_shop_item_action("shop_lock", shop_item, player_index)
		msg["ban"] = false
		msg["desired_locked"] = locked
		_submit_local_shop_action(msg, player_index, "lock_poll")
	var cleanup = []
	for key in _client_shop_lock_state_by_slot_key.keys():
		if not live_keys.has(key) and str(key).begins_with(str(shop.get_instance_id()) + ":" + str(player_index) + ":"):
			cleanup.append(key)
	for key in cleanup:
		_client_shop_lock_state_by_slot_key.erase(key)


func _build_client_shop_lock_slot_key(shop: Node, player_index: int, slot_index: int, item_data) -> String:
	if not _is_valid_shop_node(shop) or item_data == null:
		return ""
	var item_key = _get_shop_item_identity_key(item_data)
	if item_key == "":
		item_key = str(_safe_get(item_data, "my_id_hash", 0))
	return str(shop.get_instance_id()) + ":" + str(player_index) + ":" + str(slot_index) + ":" + item_key


func _intercept_client_shop_item_buttons(container: Node, player_index: int) -> void:
	if not _is_live_ref(container):
		return
	var shop_item_nodes = _safe_get(container, "_shop_items", [])
	if typeof(shop_item_nodes) != TYPE_ARRAY:
		return
	for shop_item_node in shop_item_nodes:
		if not _is_live_ref(shop_item_node):
			continue
		if shop_item_node.is_connected("buy_button_pressed", container, "on_shop_item_buy_button_pressed"):
			shop_item_node.disconnect("buy_button_pressed", container, "on_shop_item_buy_button_pressed")
		if not shop_item_node.is_connected("buy_button_pressed", self, "_on_client_shop_item_buy_button_pressed"):
			shop_item_node.connect("buy_button_pressed", self, "_on_client_shop_item_buy_button_pressed", [player_index])
		if shop_item_node.is_connected("steal_button_pressed", container, "on_shop_item_steal_button_pressed"):
			shop_item_node.disconnect("steal_button_pressed", container, "on_shop_item_steal_button_pressed")
		if not shop_item_node.is_connected("steal_button_pressed", self, "_on_client_shop_item_steal_button_pressed"):
			shop_item_node.connect("steal_button_pressed", self, "_on_client_shop_item_steal_button_pressed", [player_index])
		if shop_item_node.is_connected("ban_item_pressed", container, "on_shop_item_ban_button_pressed"):
			shop_item_node.disconnect("ban_item_pressed", container, "on_shop_item_ban_button_pressed")
		if not shop_item_node.is_connected("ban_item_pressed", self, "_on_client_shop_item_ban_button_pressed"):
			shop_item_node.connect("ban_item_pressed", self, "_on_client_shop_item_ban_button_pressed", [player_index])

		var lock_button = _safe_get(shop_item_node, "_lock_button", null)
		if _is_live_ref(lock_button):
			if lock_button.is_connected("toggled", shop_item_node, "_on_LockButton_toggled"):
				lock_button.disconnect("toggled", shop_item_node, "_on_LockButton_toggled")
			if not lock_button.is_connected("toggled", self, "_on_client_shop_item_lock_toggled"):
				lock_button.connect("toggled", self, "_on_client_shop_item_lock_toggled", [shop_item_node, player_index])


func _maybe_schedule_client_shop_direct_lock_probe(event: InputEvent) -> void:
	# This probe is only for shop lock/select. In battle, analog stick motion can
	# generate many InputEventJoypadMotion events per second; do not scan for a
	# shop node from main.tscn on every motion event.
	if event is InputEventJoypadMotion:
		return
	if _get_current_menu_screen_fast() != SCREEN_SHOP:
		return
	if _is_game_start_guard_active():
		return
	if _is_game_host() or _applying_remote_run_page_action:
		return
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return
	var player_index = _get_local_client_player_index()
	if player_index < 0:
		return
	if not Utils.is_player_select_pressed(event, player_index):
		return
	var shop_item = _get_focused_shop_item_node(shop, player_index)
	if not _is_live_ref(shop_item):
		return
	var item_data = _safe_get(shop_item, "item_data", null)
	if item_data == null:
		return
	if not bool(_safe_get(item_data, "is_lockable", true)):
		return
	if RunData.get_player_effect_bool(Keys.disable_item_locking_hash, player_index):
		return

	_client_shop_direct_lock_probe_seq += 1
	var probe_seq = _client_shop_direct_lock_probe_seq
	var before_locked = bool(_safe_get(shop_item, "locked", false))
	var item_key = _get_shop_item_identity_key(item_data)
	call_deferred("_finish_client_shop_direct_lock_probe", probe_seq, int(shop.get_instance_id()), int(shop_item.get_instance_id()), player_index, before_locked, item_key)


func _finish_client_shop_direct_lock_probe(probe_seq: int, shop_instance_id: int, shop_item_instance_id: int, player_index: int, before_locked: bool, item_key: String) -> void:
	if probe_seq <= 0:
		return
	if _is_game_host() or _applying_remote_run_page_action:
		return
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop) or int(shop.get_instance_id()) != shop_instance_id:
		return
	var shop_item = _get_shop_item_by_instance_id(shop, player_index, shop_item_instance_id)
	if not _is_live_ref(shop_item):
		return
	var item_data = _safe_get(shop_item, "item_data", null)
	if item_data == null:
		return
	if item_key != "" and _get_shop_item_identity_key(item_data) != item_key:
		return
	var after_locked = bool(_safe_get(shop_item, "locked", false))
	# Send even if after_locked == before_locked. Depending on scene-tree input order,
	# this manager can receive _input after BaseShop already toggled the item, so the
	# captured "before" value may already be the final value. Host-side application is
	# idempotent because desired_locked is explicit and the item identity is included.
	var msg = _build_client_shop_item_action("shop_lock", shop_item, player_index)
	msg["ban"] = false
	msg["desired_locked"] = after_locked
	_submit_local_shop_action(msg, player_index, "lock_probe")


func _get_focused_shop_item_node(shop: Node, player_index: int):
	if not _is_valid_shop_node(shop):
		return null
	var focused_items = _safe_get(shop, "_focused_shop_item", [])
	if typeof(focused_items) == TYPE_ARRAY and player_index >= 0 and player_index < focused_items.size():
		var focused_shop_item = focused_items[player_index]
		if _is_live_ref(focused_shop_item):
			return focused_shop_item
	var target = _get_current_shop_focus_target(shop, player_index)
	if target != "":
		return _get_shop_item_for_target(shop, player_index, target)
	return null


func _get_shop_item_by_instance_id(shop: Node, player_index: int, instance_id: int):
	if not _is_valid_shop_node(shop):
		return null
	var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
	if not _is_live_ref(container):
		return null
	var shop_item_nodes = _safe_get(container, "_shop_items", [])
	if typeof(shop_item_nodes) != TYPE_ARRAY:
		return null
	for shop_item in shop_item_nodes:
		if _is_live_ref(shop_item) and int(shop_item.get_instance_id()) == instance_id:
			return shop_item
	return null


func _on_client_shop_reroll_pressed(player_index: int) -> void:
	if _applying_remote_run_page_action:
		return
	var msg = {
		"msg_type": "run_page_action_sync",
		"action_type": "shop_reroll",
		"screen": "shop",
		"player_index": player_index
	}
	_submit_local_shop_action(msg, player_index, "reroll")


func _on_client_shop_go_pressed(player_index: int) -> void:
	if _applying_remote_run_page_action:
		return
	var shop = _find_shop_node()
	var was_pressed = false
	if _is_valid_shop_node(shop):
		was_pressed = bool(_get_node_array_value(shop, "_player_pressed_go_button", player_index, false))
	var desired_pressed = not was_pressed

	# Client does not execute the vanilla Go action locally, but the player should
	# immediately see their own ready/cancel state while waiting for Host confirmation.
	if not _is_game_host():
		_force_shop_go_visual_state_for_player(player_index, desired_pressed)
		if desired_pressed:
			# Keep the optimistic ready mark through one delayed stale shop_state.
			_local_shop_go_pending_until_by_player[player_index] = OS.get_ticks_msec() + 1500
		else:
			# Cancel must not be masked by the optimistic-ready grace window.
			_local_shop_go_pending_until_by_player.erase(player_index)
	var msg = {
		"msg_type": "run_page_action_sync",
		"action_type": "shop_go",
		"screen": "shop",
		"player_index": player_index,
		"desired_pressed": desired_pressed
	}
	_submit_local_shop_action(msg, player_index, "go")
	# Do not enter the transition guard from a speculative local ready press.
	# Host may still receive a cancel/focus-exit before it commits the start. The
	# authoritative game_start_prepare packet is the only point that may arm the
	# client transition guard.


func _would_shop_go_press_start_game(shop: Node, player_index: int, desired_pressed: bool) -> bool:
	if not desired_pressed:
		return false
	if not _is_valid_shop_node(shop):
		return false
	var player_count = _get_run_player_count()
	if player_count <= 1:
		return true
	for other_player_index in range(player_count):
		if other_player_index == player_index:
			continue
		if not bool(_get_node_array_value(shop, "_player_pressed_go_button", other_player_index, false)):
			return false
	return true


func _on_client_shop_item_buy_button_pressed(shop_item, player_index: int) -> void:
	_on_client_shop_item_bought(shop_item, player_index)


func _on_client_shop_item_steal_button_pressed(shop_item, player_index: int) -> void:
	_on_client_shop_item_stolen(shop_item, player_index)


func _on_client_shop_item_ban_button_pressed(shop_item, player_index: int) -> void:
	_on_client_shop_item_banned(shop_item, player_index)


func _on_client_shop_combine_weapon_pressed(weapon_data, player_index: int) -> void:
	if _applying_remote_run_page_action:
		return
	var msg = {
		"msg_type": "run_page_action_sync",
		"action_type": "shop_combine_weapon",
		"screen": "shop",
		"player_index": player_index,
		"weapon": _serialize_item_parent_data(weapon_data),
		# Backward-compatible field name: legacy packets used weapon_id_hash for my_id_hash.
		"weapon_id_hash": int(_safe_get(weapon_data, "my_id_hash", 0)),
		"weapon_id": str(_safe_get(weapon_data, "my_id", "")),
		"weapon_my_id_hash": int(_safe_get(weapon_data, "my_id_hash", 0)),
		"weapon_my_id": str(_safe_get(weapon_data, "my_id", "")),
		"weapon_weapon_id_hash": int(_safe_get(weapon_data, "weapon_id_hash", 0)),
		"weapon_weapon_id": str(_safe_get(weapon_data, "weapon_id", "")),
		"weapon_slot_index": _get_player_weapon_index_for_action_payload(player_index, weapon_data),
		"item_log": _get_item_id_for_log(weapon_data)
	}
	_submit_local_shop_action(msg, player_index, "combine weapon")
	_close_shop_popup_for_player(_find_shop_node(), player_index, msg)


func _on_client_shop_discard_weapon_pressed(weapon_data, player_index: int) -> void:
	if _applying_remote_run_page_action:
		return
	var msg = {
		"msg_type": "run_page_action_sync",
		"action_type": "shop_discard_weapon",
		"screen": "shop",
		"player_index": player_index,
		"weapon": _serialize_item_parent_data(weapon_data),
		# Backward-compatible field name: legacy packets used weapon_id_hash for my_id_hash.
		"weapon_id_hash": int(_safe_get(weapon_data, "my_id_hash", 0)),
		"weapon_id": str(_safe_get(weapon_data, "my_id", "")),
		"weapon_my_id_hash": int(_safe_get(weapon_data, "my_id_hash", 0)),
		"weapon_my_id": str(_safe_get(weapon_data, "my_id", "")),
		"weapon_weapon_id_hash": int(_safe_get(weapon_data, "weapon_id_hash", 0)),
		"weapon_weapon_id": str(_safe_get(weapon_data, "weapon_id", "")),
		"weapon_slot_index": _get_player_weapon_index_for_action_payload(player_index, weapon_data),
		"item_log": _get_item_id_for_log(weapon_data)
	}
	_submit_local_shop_action(msg, player_index, "discard weapon")
	_close_shop_popup_for_player(_find_shop_node(), player_index, msg)


func _on_client_shop_item_bought(shop_item, player_index: int) -> void:
	if _applying_remote_run_page_action:
		return
	var msg = _build_client_shop_item_action("shop_buy", shop_item, player_index)
	_submit_local_shop_action(msg, player_index, "buy")


func _on_client_shop_item_stolen(shop_item, player_index: int) -> void:
	if _applying_remote_run_page_action:
		return
	var msg = _build_client_shop_item_action("shop_buy", shop_item, player_index)
	msg["steal"] = true
	_submit_local_shop_action(msg, player_index, "steal")


func _on_client_shop_item_banned(shop_item, player_index: int) -> void:
	if _applying_remote_run_page_action:
		return
	var msg = _build_client_shop_item_action("shop_lock", shop_item, player_index)
	msg["ban"] = true
	_submit_local_shop_action(msg, player_index, "ban")


func _on_client_shop_item_lock_toggled(button_pressed: bool, shop_item, player_index: int) -> void:
	if _applying_remote_run_page_action:
		return
	var msg = _build_client_shop_item_action("shop_lock", shop_item, player_index)
	msg["ban"] = false
	msg["desired_locked"] = bool(button_pressed)
	if not _is_game_host() and _is_live_ref(shop_item):
		_apply_shop_item_lock_visual_only(shop_item, bool(button_pressed))
		_update_client_shop_lock_baseline_for_item(shop_item, player_index, bool(button_pressed))
	_submit_local_shop_action(msg, player_index, "lock")


func _update_client_shop_lock_baseline_for_item(shop_item, player_index: int, locked: bool) -> void:
	if _is_game_host() or not _is_live_ref(shop_item):
		return
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return
	var slot_index = _get_shop_item_index(shop_item, player_index)
	if slot_index < 0:
		return
	var item_data = _safe_get(shop_item, "item_data", null)
	if item_data == null:
		return
	var slot_key = _build_client_shop_lock_slot_key(shop, player_index, slot_index, item_data)
	if slot_key != "":
		_client_shop_lock_state_by_slot_key[slot_key] = locked


func _build_client_shop_item_action(action_type: String, shop_item, player_index: int) -> Dictionary:
	var idx = _get_shop_item_index(shop_item, player_index)
	var item_data = _safe_get(shop_item, "item_data", null)
	return {
		"msg_type": "run_page_action_sync",
		"action_type": action_type,
		"screen": "shop",
		"player_index": player_index,
		"target": "item_" + str(idx),
		"shop_index": idx,
		# Host already has the authoritative item in this shop slot. Sending the full
		# serialized resource here can turn a buy into a 60KB+ chunked packet, which lets
		# later reroll/focus packets overtake it. Keep only identity fields for matching.
		"item": _serialize_item_parent_identity_for_action(item_data),
		"item_id_hash": int(_safe_get(item_data, "my_id_hash", 0)),
		"item_key": _get_shop_item_identity_key(item_data),
		"item_log": _get_item_id_for_log(item_data)
	}


func _submit_local_shop_action(message: Dictionary, player_index: int, label: String) -> void:
	if typeof(message) != TYPE_DICTIONARY or message.empty():
		return
	if _is_game_host():
		_apply_host_local_shop_action(message, label)
	else:
		var predicted = _apply_client_local_shop_prediction(message, player_index, label)
		var outbound = _build_client_shop_action_outbound_message(message)
		_queue_local_run_page_action(outbound)


func _build_client_shop_action_outbound_message(message: Dictionary) -> Dictionary:
	var outbound = message.duplicate(true)
	# _apply_shop_buy_action() adds resolved_item for local prediction / Host-side delta
	# building. It is the full serialized resource and can make a tiny buy request huge.
	# The Host already owns the authoritative shop slot, so keep only identity fields
	# such as shop_index, item_id_hash, item_key and item_log for cross-DLC validation.
	outbound.erase("resolved_item")
	outbound.erase("resolved_shop_index")
	return outbound


func _is_client_shop_predictable_action(action_type: String) -> bool:
	# Reroll creates a new random shop pool and must remain Host-authoritative.
	# Predict only deterministic local display mutations.
	return [
		"shop_buy",
		"shop_combine_weapon",
		"shop_discard_weapon",
		"shop_lock"
	].has(action_type)


func _apply_client_local_shop_prediction(message: Dictionary, player_index: int, label: String = "") -> bool:
	if _is_game_host() or _applying_remote_run_page_action:
		return false
	var action_type = str(message.get("action_type", ""))
	if not _is_client_shop_predictable_action(action_type):
		return false
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop) or player_index < 0:
		return false

	_prepare_client_shop_prediction_message(message, player_index)
	_applying_remote_run_page_action = true
	var applied = false
	if action_type == "shop_buy":
		applied = _apply_shop_buy_action(player_index, message)
	elif action_type == "shop_combine_weapon":
		applied = _apply_shop_combine_weapon_action(player_index, message)
	elif action_type == "shop_discard_weapon":
		applied = _apply_shop_discard_weapon_action(player_index, message)
	elif action_type == "shop_lock":
		# Client-side lock prediction must be visual-only. Calling the vanilla
		# ShopItem.change_lock_status() on a Client writes RunData.locked_shop_items,
		# so stale local locks can survive until the next shop and be added on top of
		# the Host authoritative shop state. That can make BaseShop._shop_items have
		# more entries than the 4 visual slots and crash at index 4.
		applied = _apply_client_shop_lock_prediction_visual_only(shop, player_index, message)
	_applying_remote_run_page_action = false

	if applied:
		_record_client_shop_prediction(player_index, message)
		_refresh_client_local_shop_after_prediction(shop, player_index, action_type)
	else:
		message.erase("client_prediction_token")
		message.erase("client_predicted_key")
	return applied


func _apply_client_shop_lock_prediction_visual_only(shop: Node, player_index: int, message: Dictionary) -> bool:
	if _is_game_host() or not _is_valid_shop_node(shop) or player_index < 0:
		return false
	var shop_item = _get_shop_item_for_action(shop, player_index, message)
	if not _is_live_ref(shop_item):
		return false
	message["resolved_shop_index"] = _get_shop_item_index(shop_item, player_index)

	# A Client is never authoritative for RunData.locked_shop_items. Clear any
	# local residue that may have been produced by vanilla direct-select locking
	# or by an older prediction path; Host shop_state will replace it below.
	_clear_client_locked_shop_items_for_player(player_index)

	var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
	if bool(message.get("ban", false)):
		_deactivate_shop_item_visual_if_needed(shop_item)
		if _is_live_ref(container) and container.has_method("update_buttons_color"):
			container.update_buttons_color()
		return true

	var desired_locked = not bool(_safe_get(shop_item, "locked", false))
	if message.has("desired_locked"):
		desired_locked = bool(message.get("desired_locked", desired_locked))
	_apply_shop_item_lock_visual_only(shop_item, desired_locked)
	_update_client_shop_lock_baseline_for_item(shop_item, player_index, desired_locked)
	if _is_live_ref(container) and container.has_method("update_buttons_color"):
		container.update_buttons_color()
	return true


func _prepare_client_shop_prediction_message(message: Dictionary, player_index: int) -> void:
	if str(message.get("client_prediction_token", "")) == "":
		_client_shop_prediction_seq += 1
		message["client_prediction_token"] = _get_self_steam_id() + ":shop_pred:" + str(_client_shop_prediction_seq)
	message["client_predicted_player_index"] = player_index
	message["client_predicted_at_msec"] = OS.get_ticks_msec()


func _record_client_shop_prediction(player_index: int, message: Dictionary) -> void:
	var state = _build_shop_player_state(player_index)
	var key = _build_shop_state_prediction_key_from_state(state)
	var token = str(message.get("client_prediction_token", ""))
	_client_shop_prediction_until_by_player[player_index] = OS.get_ticks_msec() + CLIENT_SHOP_PREDICTION_HOLD_MSEC
	_client_shop_prediction_token_by_player[player_index] = token
	_client_shop_prediction_key_by_player[player_index] = key
	_client_shop_prediction_action_by_player[player_index] = str(message.get("action_type", ""))
	_last_applied_shop_state_key_by_player[player_index] = key
	message["client_predicted_key"] = key


func _refresh_client_local_shop_after_prediction(shop: Node, player_index: int, action_type: String = "") -> void:
	if not _is_valid_shop_node(shop):
		return
	var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
	if _is_live_ref(container):
		container.update_buttons_color()
		_intercept_client_shop_item_buttons(container, player_index)
	if shop.has_method("set_reroll_button_price"):
		shop.set_reroll_button_price(player_index)
	var gold_label = shop._get_gold_label(player_index) if shop.has_method("_get_gold_label") else null
	if _is_live_ref(gold_label) and gold_label.has_method("update_value"):
		gold_label.update_value(RunData.get_player_gold(player_index))
	if action_type == "shop_buy" or action_type == "shop_combine_weapon" or action_type == "shop_discard_weapon":
		var gear_container = shop._get_gear_container(player_index) if shop.has_method("_get_gear_container") else null
		if _is_live_ref(gear_container):
			_force_rebuild_shop_gear_container(shop, player_index)


func _should_skip_client_predicted_own_shop_state(state: Dictionary, context: Dictionary = {}) -> bool:
	if _is_game_host():
		return false
	var local_player_index = _get_local_client_player_index()
	var player_index = int(state.get("player_index", -1))
	if local_player_index < 0 or player_index != local_player_index:
		return false
	if bool(state.get("force_run_data_repair", false)):
		return false
	var until_msec = int(_client_shop_prediction_until_by_player.get(player_index, 0))
	if until_msec <= 0:
		return false
	var now = OS.get_ticks_msec()
	if now > until_msec:
		_clear_client_shop_prediction(player_index)
		return false

	var incoming_token = str(context.get("client_prediction_token", ""))
	var expected_token = str(_client_shop_prediction_token_by_player.get(player_index, ""))
	if incoming_token != "":
		if incoming_token == expected_token:
			var predicted_key = str(_client_shop_prediction_key_by_player.get(player_index, ""))
			# Compact action deltas are echoes for a locally predicted mutation. The local
			# client already ran vanilla logic, so applying an inventory add delta would
			# duplicate the item/weapon. Trust the echo only when the Host applied it and
			# the packet still carries the predicted key generated before send. Periodic
			# full snapshots remain the correction path if the prediction was wrong.
			if bool(state.get("shop_delta", false)) and bool(state.get("host_applied", true)) and str(context.get("client_predicted_key", "")) == predicted_key:
				_clear_client_shop_prediction(player_index)
				return true
			var incoming_key = _build_shop_state_prediction_key_from_state(state)
			if incoming_key == predicted_key:
				_clear_client_shop_prediction(player_index)
				return true
			_clear_client_shop_prediction(player_index)
			return false
		# An older echo can arrive after a newer local prediction. Do not roll the local
		# player's panel backward; the newest prediction will either match or be corrected.
		return true

	# Generic Host shop_state can be older than the local command because reliable P2P
	# still preserves per-sender order, not cross-sender action/order with the Client UI.
	# Hold only this Client's own panel; states for other players are still applied.
	return true


func _clear_client_shop_prediction(player_index: int) -> void:
	_client_shop_prediction_until_by_player.erase(player_index)
	_client_shop_prediction_token_by_player.erase(player_index)
	_client_shop_prediction_key_by_player.erase(player_index)
	_client_shop_prediction_action_by_player.erase(player_index)


func _clear_all_client_shop_predictions() -> void:
	_client_shop_prediction_until_by_player.clear()
	_client_shop_prediction_token_by_player.clear()
	_client_shop_prediction_key_by_player.clear()
	_client_shop_prediction_action_by_player.clear()


func _get_next_shop_wave_number_for_item_sync() -> int:
	# In shop, RunData.current_wave is the last completed wave; the next battle is +1.
	var next_wave = int(RunData.current_wave) + 1
	if next_wave < 1:
		return 1
	return next_wave


func _should_use_endless_incremental_items_only_shop_sync() -> bool:
	var endless_enabled = bool(RunData.is_endless_run) or bool(ProgressData.settings.endless_mode_toggled)
	return endless_enabled and _get_next_shop_wave_number_for_item_sync() >= ENDLESS_INCREMENTAL_ITEMS_ONLY_START_WAVE


func _resolve_shop_held_items_sync_mode(default_mode: String, force_full_held_items: bool = false) -> String:
	# Fresh clients entering through official Continue/rejoin do not have the late-endless
	# local held-item baseline. In that bootstrap path, force one compact full item list
	# even after wave 20; normal late shops still use incremental-only.
	if force_full_held_items:
		return SHOP_HELD_ITEMS_SYNC_COMPACT
	if _should_use_endless_incremental_items_only_shop_sync():
		return SHOP_HELD_ITEMS_SYNC_INCREMENTAL_ONLY
	return default_mode


func _build_shop_state_prediction_key_from_state(state: Dictionary) -> String:
	if typeof(state) != TYPE_DICTIONARY or state.empty():
		return ""
	var item_keys = []
	var item_entries = state.get("shop_items", [])
	if typeof(item_entries) == TYPE_ARRAY:
		for entry in item_entries:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var slot_index = int(entry.get("slot_index", entry.get("index", -1)))
			if bool(entry.get("slot_empty", false)) or not bool(entry.get("active", true)):
				item_keys.append(str(slot_index) + ":empty")
				continue
			var lock_bit = "1" if bool(entry.get("locked", false)) else "0"
			item_keys.append(str(slot_index) + ":" + _build_shop_entry_identity_key(entry) + ":L" + lock_bit)

	var shop_slots_key = _build_shop_slots_state_key_from_entries(item_entries)
	var run_data_key = str(state.get("run_data_key", ""))
	var run_data_state = state.get("run_data", {})
	var weapon_keys = []
	var inventory_item_keys = []
	if run_data_key == "" and typeof(run_data_state) == TYPE_DICTIONARY and not run_data_state.empty():
		weapon_keys = _build_serialized_inventory_list_key(run_data_state.get("weapons", []))
		inventory_item_keys = _build_serialized_inventory_list_key(run_data_state.get("items", []))
	elif run_data_key == "":
		var player_index = int(state.get("player_index", -1))
		if player_index >= 0:
			weapon_keys = _build_inventory_data_key(RunData.get_player_weapons(player_index))
			inventory_item_keys = _build_inventory_data_key(RunData.get_player_items(player_index))

	return to_json({
		"player": int(state.get("player_index", -1)),
		"gold": int(state.get("gold", 0)),
		"current_health": int(state.get("current_health", 0)),
		"current_wave": int(state.get("current_wave", 0)),
		"items": item_keys,
		"shop_slots_key": shop_slots_key,
		"run_data_key": run_data_key,
		"weapons": weapon_keys,
		"inventory_items": inventory_item_keys,
		"reroll_price": int(state.get("reroll_price", 0)),
		"reroll_count": int(state.get("reroll_count", 0)),
		"paid_reroll_count": int(state.get("paid_reroll_count", 0)),
		"free_rerolls": int(state.get("free_rerolls", 0)),
		"has_bonus_free_reroll": bool(state.get("has_bonus_free_reroll", false)),
		"item_steals": int(state.get("item_steals", 0)),
		"pressed_go": bool(state.get("pressed_go", false))
	})


func _build_shop_entry_identity_key(entry: Dictionary) -> String:
	var explicit_key = str(entry.get("item_key", ""))
	if explicit_key != "":
		return explicit_key
	var item_state = entry.get("item", {})
	if typeof(item_state) != TYPE_DICTIONARY:
		return ""
	var parts = []
	parts.append(str(item_state.get("type", "")))
	parts.append(str(item_state.get("my_id_hash", 0)))
	parts.append(str(item_state.get("weapon_id_hash", 0)))
	parts.append(str(item_state.get("my_id", "")))
	parts.append(str(item_state.get("weapon_id", "")))
	parts.append(str(item_state.get("resource_path", "")))
	parts.append(str(item_state.get("tier", -1)))
	parts.append(str(item_state.get("is_cursed", false)))
	parts.append(str(item_state.get("curse_factor", 0.0)))
	return "|".join(parts)


func _build_serialized_inventory_list_key(items) -> Array:
	var result = []
	if typeof(items) != TYPE_ARRAY:
		return result
	for item in items:
		if typeof(item) == TYPE_DICTIONARY:
			result.append(_build_serialized_inventory_entry_key(item))
		else:
			result.append(str(item))
	return result


func _build_serialized_inventory_entry_key(item: Dictionary) -> String:
	var parts = []
	parts.append(str(item.get("my_id_hash", 0)))
	parts.append(str(item.get("weapon_id_hash", 0)))
	parts.append(str(item.get("my_id", "")))
	parts.append(str(item.get("weapon_id", "")))
	parts.append(str(item.get("tier", -1)))
	parts.append(str(item.get("value", 0)))
	parts.append(str(item.get("is_cursed", false)))
	return "|".join(parts)


func _apply_host_local_shop_action(message: Dictionary, label: String = "") -> void:
	if not _is_game_host():
		return
	var action_type = str(message.get("action_type", ""))
	var player_index = int(message.get("player_index", _get_host_local_player_index()))
	if player_index < 0:
		return
	_applying_remote_run_page_action = true
	var applied = false
	if action_type == "shop_buy":
		applied = _apply_shop_buy_action(player_index, message)
	elif action_type == "shop_combine_weapon":
		applied = _apply_shop_combine_weapon_action(player_index, message)
	elif action_type == "shop_discard_weapon":
		applied = _apply_shop_discard_weapon_action(player_index, message)
	elif action_type == "shop_reroll":
		applied = _apply_shop_reroll_action(player_index, message)
	elif action_type == "shop_go":
		applied = _apply_shop_go_action(player_index, message)
	elif action_type == "shop_lock":
		applied = _apply_shop_lock_action(player_index, message)
	_applying_remote_run_page_action = false
	if applied and (action_type == "shop_buy" or action_type == "shop_combine_weapon" or action_type == "shop_discard_weapon"):
		_mark_host_shop_run_data_dirty(player_index)

	var state_after = _build_shop_action_delta_state(player_index, action_type, message, applied)
	var broadcast = message.duplicate(true)
	broadcast["msg_type"] = "run_page_action_sync"
	broadcast["screen"] = "shop"
	broadcast["origin_steam_id"] = _get_self_steam_id()
	broadcast["host_state_after"] = state_after
	broadcast["state_after"] = state_after
	_queue_local_run_page_action(broadcast)
	_last_shop_state_key = ""


func _can_shop_buy_action_pass_local_rules(player_index: int, shop_item, container: Node, steal: bool) -> bool:
	if player_index < 0 or not _is_live_ref(shop_item):
		return false
	if not bool(_safe_get(shop_item, "active", true)):
		return false
	var item_data = _safe_get(shop_item, "item_data", null)
	if item_data == null:
		return false

	if steal:
		if _is_live_ref(container) and int(_safe_get(container, "item_steals", 0)) <= 0:
			return false
	else:
		var value = int(_safe_get(shop_item, "value", 0))
		if RunData.has_method("get_player_currency"):
			if RunData.get_player_currency(player_index) < value:
				return false
		elif RunData.get_player_gold(player_index) < value:
			return false

	var category = item_data.get_category() if typeof(item_data) == TYPE_OBJECT and item_data.has_method("get_category") else null
	if category == Category.WEAPON:
		# Client-side button interception bypasses ShopItemsContainer's vanilla
		# on_shop_item_buy_button_pressed()/on_shop_item_steal_button_pressed() checks.
		# Re-run the same weapon-slot / duplicate / lock-current-weapons validation before
		# doing any optimistic local mutation, otherwise a full weapon inventory can make
		# the client hide the shop weapon until the next authoritative snapshot.
		if _is_live_ref(container) and container.has_method("_can_weapon_be_bought"):
			return bool(container._can_weapon_be_bought(shop_item))
		return _can_weapon_data_be_bought_for_player(player_index, item_data)
	return true


func _can_weapon_data_be_bought_for_player(player_index: int, weapon_data) -> bool:
	if player_index < 0 or weapon_data == null:
		return false
	var min_weapon_tier = int(RunData.get_player_effect(Keys.min_weapon_tier_hash, player_index))
	var max_weapon_tier = int(RunData.get_player_effect(Keys.max_weapon_tier_hash, player_index))
	var no_melee_weapons = RunData.get_player_effect_bool(Keys.no_melee_weapons_hash, player_index)
	var no_ranged_weapons = RunData.get_player_effect_bool(Keys.no_ranged_weapons_hash, player_index)
	var no_duplicate_weapons = RunData.get_player_effect_bool(Keys.no_duplicate_weapons_hash, player_index)
	var lock_current_weapons = RunData.get_player_effect_bool(Keys.lock_current_weapons_hash, player_index)

	var weapon_type = _safe_get(weapon_data, "type", null)
	var weapon_slot_available = bool(RunData.has_weapon_slot_available(weapon_data, player_index))
	var weapon_tier = int(_safe_get(weapon_data, "tier", 0))
	if weapon_tier > max_weapon_tier or weapon_tier < min_weapon_tier:
		return false
	if no_melee_weapons and weapon_type == WeaponType.MELEE:
		return false
	if no_ranged_weapons and weapon_type == WeaponType.RANGED:
		return false
	if lock_current_weapons and not weapon_slot_available:
		return false

	var player_has_weapon = false
	var weapons = RunData.get_player_weapons_ref(player_index) if RunData.has_method("get_player_weapons_ref") else RunData.get_player_weapons(player_index)
	if typeof(weapons) == TYPE_ARRAY:
		var weapon_my_id = _safe_get(weapon_data, "my_id", null)
		for weapon in weapons:
			if _safe_get(weapon, "my_id", null) == weapon_my_id:
				player_has_weapon = true
				break

	var upgrades_into = _safe_get(weapon_data, "upgrades_into", null)
	if player_has_weapon and not weapon_slot_available and upgrades_into != null and int(_safe_get(upgrades_into, "tier", 999)) <= max_weapon_tier:
		return true

	var player_has_weapon_family = false
	var unique_weapon_ids = RunData.get_unique_weapon_ids(player_index) if RunData.has_method("get_unique_weapon_ids") else []
	if typeof(unique_weapon_ids) == TYPE_ARRAY and _safe_get(weapon_data, "weapon_id", null) in unique_weapon_ids:
		player_has_weapon_family = true
	if no_duplicate_weapons and player_has_weapon_family:
		return false

	return weapon_slot_available


func _apply_shop_buy_action(player_index: int, message: Dictionary) -> bool:
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return false
	var shop_item = _get_shop_item_for_action(shop, player_index, message)
	if not _is_live_ref(shop_item):
		return false
	var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
	var resolved_item_data = _safe_get(shop_item, "item_data", null)
	message["resolved_shop_index"] = _get_shop_item_index(shop_item, player_index)
	if typeof(message.get("resolved_item", {})) != TYPE_DICTIONARY or message.get("resolved_item", {}).empty():
		message["resolved_item"] = _serialize_item_parent_data(resolved_item_data)
	var steal = bool(message.get("steal", false))
	if not _can_shop_buy_action_pass_local_rules(player_index, shop_item, container, steal):
		if _is_live_ref(container) and container.has_method("update_buttons_color"):
			container.update_buttons_color()
		return false

	# If the vanilla container->shop signal is still connected, let vanilla perform its
	# normal checks and mutation. If we installed the local network-style intercept, the
	# signal is disconnected, so call the authoritative shop mutation directly.
	var container_can_mutate_shop = false
	if _is_live_ref(container):
		if steal:
			container_can_mutate_shop = container.is_connected("shop_item_stolen", shop, "on_shop_item_stolen")
		else:
			container_can_mutate_shop = container.is_connected("shop_item_bought", shop, "on_shop_item_bought")
	if steal and container_can_mutate_shop and container.has_method("on_shop_item_steal_button_pressed"):
		container.on_shop_item_steal_button_pressed(shop_item)
		return true
	if not steal and container_can_mutate_shop and container.has_method("on_shop_item_buy_button_pressed"):
		container.on_shop_item_buy_button_pressed(shop_item)
		return true

	if steal and shop.has_method("on_shop_item_stolen"):
		shop.on_shop_item_stolen(shop_item, player_index)
	elif not steal and shop.has_method("on_shop_item_bought"):
		var value = int(_safe_get(shop_item, "value", 0))
		if RunData.has_method("get_player_currency") and RunData.get_player_currency(player_index) < value:
			return false
		shop.on_shop_item_bought(shop_item, player_index)
	else:
		return false
	if shop_item.has_method("deactivate"):
		shop_item.deactivate()
	if _is_live_ref(container) and container.has_method("update_buttons_color"):
		container.update_buttons_color()
	return true


func _apply_shop_combine_weapon_action(player_index: int, message: Dictionary) -> bool:
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return false
	var weapon_data = _find_player_weapon_for_shop_action(player_index, message)
	if weapon_data == null:
		return false
	# The network intercept calls the shop method directly, bypassing the vanilla
	# Combine button visibility gate. Re-check the same rule here so a stale Client
	# packet cannot upgrade a single weapon without consuming a matching pair.
	if not _can_apply_shop_combine_weapon_action(player_index, weapon_data):
		_close_shop_popup_for_player(shop, player_index, message)
		return false
	if shop.has_method("_on_item_combine_button_pressed"):
		shop._on_item_combine_button_pressed(weapon_data, player_index)
		_close_shop_popup_for_player(shop, player_index, message)
		_force_rebuild_shop_gear_container(shop, player_index)
		return true
	return false


func _can_apply_shop_combine_weapon_action(player_index: int, weapon_data) -> bool:
	if player_index < 0 or weapon_data == null:
		return false
	if RunData.get_player_effect_bool(Keys.lock_current_weapons_hash, player_index):
		return false
	if _safe_get(weapon_data, "upgrades_into", null) == null:
		return false
	if RunData.has_method("can_combine"):
		return bool(RunData.can_combine(weapon_data, player_index))
	return false


func _apply_shop_discard_weapon_action(player_index: int, message: Dictionary) -> bool:
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return false
	var weapon_data = _find_player_weapon_for_shop_action(player_index, message)
	if weapon_data == null:
		return false
	var before_count = RunData.get_player_weapons(player_index).size()
	var before_gold = RunData.get_player_gold(player_index)
	var applied = _discard_player_weapon_authoritative(shop, player_index, weapon_data)
	_close_shop_popup_for_player(shop, player_index, message)
	var after_count = RunData.get_player_weapons(player_index).size()
	var after_gold = RunData.get_player_gold(player_index)
	return applied


func _discard_player_weapon_authoritative(shop: Node, player_index: int, weapon_data) -> bool:
	if not _is_valid_shop_node(shop) or weapon_data == null:
		return false
	if RunData.get_player_effect_bool(Keys.lock_current_weapons_hash, player_index):
		return false

	var before_count = RunData.get_player_weapons(player_index).size()
	if before_count <= 0:
		return false

	RunData.add_recycled(player_index)

	var gear_container = shop._get_gear_container(player_index) if shop.has_method("_get_gear_container") else null
	var weapons_container = _safe_get(gear_container, "weapons_container", null) if _is_live_ref(gear_container) else null
	if _is_live_ref(weapons_container):
		var elements = _safe_get(weapons_container, "_elements", null)
		if _is_live_ref(elements) and elements.has_method("remove_element"):
			elements.remove_element(weapon_data, 1, true)

	var removed_weapon_tracked_value = RunData.remove_weapon(weapon_data, player_index)
	if RunData.get_player_weapons(player_index).size() >= before_count:
		var fallback_index = _get_player_weapon_index_for_action_payload(player_index, weapon_data)
		if fallback_index >= 0 and fallback_index < RunData.get_player_weapons(player_index).size():
			removed_weapon_tracked_value = RunData.remove_weapon_by_index(fallback_index, player_index)

	if RunData.get_player_weapons(player_index).size() >= before_count:
		return false

	var base_recycling_value = _safe_get(weapon_data, "value", 0)
	var specific_recycling_price_factor = 1.0
	for specific_item_price in RunData.get_player_effect(Keys.specific_items_price_hash, player_index):
		if typeof(specific_item_price) != TYPE_ARRAY or specific_item_price.size() < 2:
			continue
		var specific_hash = int(specific_item_price[0])
		if Keys.hash_to_string.has(specific_hash) and str(Keys.hash_to_string[specific_hash]) in str(_safe_get(weapon_data, "my_id", "")):
			specific_recycling_price_factor = float(specific_item_price[1])
			break
	base_recycling_value *= specific_recycling_price_factor

	var recycling_value = ItemService.get_recycling_value(RunData.current_wave, base_recycling_value, player_index, true)
	RunData.add_gold(recycling_value, player_index)
	RunData.update_recycling_tracking_value(weapon_data, player_index)

	var nb_coupons = RunData.get_nb_item(Keys.item_coupon_hash, player_index)
	if nb_coupons > 0:
		var base_value = ItemService.get_recycling_value(RunData.current_wave, _safe_get(weapon_data, "value", 0), player_index, true, false)
		var actual_value = ItemService.get_recycling_value(RunData.current_wave, _safe_get(weapon_data, "value", 0), player_index, true)
		var val_lost = int(base_value - actual_value)
		RunData.add_tracked_value(player_index, Keys.item_coupon_hash, -val_lost)

	if shop.has_method("_update_stats"):
		shop._update_stats(player_index)
	var shop_items_container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
	if _is_live_ref(shop_items_container) and shop_items_container.has_method("reload_shop_items"):
		shop_items_container.reload_shop_items()
	var reroll_button = shop._get_reroll_button(player_index) if shop.has_method("_get_reroll_button") else null
	if _is_live_ref(reroll_button) and reroll_button.has_method("set_color_from_currency"):
		reroll_button.set_color_from_currency(RunData.get_player_gold(player_index))

	_force_rebuild_shop_gear_container(shop, player_index)
	return true


func _force_rebuild_shop_gear_container(shop: Node, player_index: int) -> void:
	if not _is_valid_shop_node(shop):
		return
	var gear_container = shop._get_gear_container(player_index) if shop.has_method("_get_gear_container") else null
	if not _is_live_ref(gear_container):
		return
	var shop_key = str(shop.get_instance_id()) + ":" + str(player_index)
	_last_applied_shop_gear_key_by_player.erase(shop_key)
	if gear_container.has_method("set_weapons_data"):
		gear_container.set_weapons_data(RunData.get_player_weapons(player_index))
	if gear_container.has_method("set_items_data"):
		gear_container.set_items_data(RunData.get_player_items(player_index))
	_ensure_shop_inventory_popup_wiring_for_player(shop, player_index, not _is_game_host() and player_index == _get_local_client_player_index())


func _apply_shop_reroll_action(player_index: int, _message: Dictionary) -> bool:
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return false
	if shop.has_method("_on_RerollButton_pressed"):
		shop._on_RerollButton_pressed(player_index)
		return true
	return false


func _apply_shop_go_action(player_index: int, _message: Dictionary) -> bool:
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return false
	if not shop.has_method("_on_GoButton_pressed"):
		return false

	# Once the synchronized shop start handshake has begun, its ready snapshot is
	# authoritative. Host-local Go presses used to bypass SteamLobbyManager's
	# guarded network-action path and could cancel readiness after Clients had
	# already accepted game_start_commit, splitting Host and Client scenes.
	if _is_game_host():
		var steam_lobby_pending = _get_steam_lobby_manager()
		if steam_lobby_pending != null and steam_lobby_pending.has_method("has_pending_synced_shop_game_start"):
			if bool(steam_lobby_pending.has_pending_synced_shop_game_start()):
				return true

	# Online final-ready is special: vanilla _on_GoButton_pressed() immediately
	# changes to MenuData.game_scene when all players are ready. In an online run
	# that makes Host enter battle before Clients receive/apply the last shop state.
	# For the final ready press, mark the visual/state as ready now, do the same
	# clock-sync handshake used by difficulty start, then execute the vanilla method
	# on the scheduled Host enter tick.
	if _should_sync_shop_game_start(shop, player_index):
		return _request_synced_shop_game_start(shop, player_index)

	shop._on_GoButton_pressed(player_index)
	# Restoring the Host local focus after a remote Go can trigger the remote
	# GoButton focus_exited callback, which clears vanilla ready state. Reassert it
	# only when this press actually left the player ready; a second Go press should
	# still be able to cancel readiness.
	if bool(_get_node_array_value(shop, "_player_pressed_go_button", player_index, false)):
		_force_shop_go_visual_state(shop, player_index, true)
	return true


func _should_sync_shop_game_start(shop: Node, player_index: int) -> bool:
	if not _is_game_host() or not _is_valid_shop_node(shop):
		return false
	var steam_lobby = _get_steam_lobby_manager()
	if steam_lobby == null or not steam_lobby.has_method("request_synced_shop_game_start"):
		return false
	if bool(_get_node_array_value(shop, "_player_pressed_go_button", player_index, false)):
		# Preserve vanilla behaviour: pressing Go again cancels ready.
		return false
	for other_player_index in range(_get_run_player_count()):
		if other_player_index == player_index:
			continue
		if not bool(_get_node_array_value(shop, "_player_pressed_go_button", other_player_index, false)):
			return false
	return true


func _request_synced_shop_game_start(shop: Node, player_index: int) -> bool:
	if not _is_valid_shop_node(shop):
		return false
	_force_shop_go_visual_state(shop, player_index, true)

	var steam_lobby = _get_steam_lobby_manager()
	if steam_lobby != null and steam_lobby.has_method("request_synced_shop_game_start"):
		var force_full_held_items = false
		if steam_lobby.has_method("should_force_full_item_list_for_next_scene_sync"):
			force_full_held_items = bool(steam_lobby.should_force_full_item_list_for_next_scene_sync())
		var run_config = _build_shop_start_run_config_for_scene_sync(force_full_held_items)
		var accepted = bool(steam_lobby.request_synced_shop_game_start(shop, player_index, run_config))
		if accepted:
			_pending_synced_shop_start_id = int(shop.get_instance_id())
			return true

	# Fallback: if the sync manager is unavailable, execute vanilla rather than
	# leaving every player stuck ready in the shop. Reset this player's flag first
	# because _on_GoButton_pressed() toggles true -> false.
	_set_node_array_value(shop, "_player_pressed_go_button", player_index, false)
	shop._on_GoButton_pressed(player_index)
	return true


func _build_shop_start_run_config_for_scene_sync(force_full_held_items: bool = false) -> Dictionary:
	_force_run_player_count_to_online_coop_layout("shop_start_run_config")
	var config = _build_run_config_for_scene_sync(true, SHOP_HELD_ITEMS_SYNC_COMPACT, force_full_held_items)
	# Shop -> battle must carry the authoritative full PlayerRunData. Otherwise
	# clients keep the old battle-side data and P2 purchases/upgrades only appear
	# in the shop UI.
	config["full_player_run_data_authoritative"] = true
	config["run_config_source"] = "shop_start"
	var wave_reset_count = 0
	for idx in range(_get_run_player_count()):
		var effects = RunData.get_player_effects(idx)
		if typeof(effects) == TYPE_DICTIONARY and effects.has(Keys.item_hourglass_hash):
			wave_reset_count += int(effects[Keys.item_hourglass_hash])
	config["current_wave"] = int(RunData.current_wave) + 1 - wave_reset_count
	return config


func execute_synced_shop_game_start(shop, player_index: int) -> bool:
	if not _is_valid_shop_node(shop):
		shop = _find_shop_node()
	if not _is_valid_shop_node(shop) or not shop.has_method("_on_GoButton_pressed"):
		return false

	# BaseShop clears a player's ready flag whenever that player's Go button loses
	# focus. Focus restoration and a Host cancel press can therefore alter the
	# flags while the network start handshake is in flight. Rebuild the committed
	# all-ready snapshot immediately before the one vanilla call that changes the
	# scene. Leave only the triggering player false so vanilla turns it true rather
	# than interpreting this call as a cancellation.
	_force_run_player_count_to_online_coop_layout("execute_synced_shop_game_start")
	for ready_player_index in range(_get_run_player_count()):
		_force_shop_go_visual_state(shop, ready_player_index, ready_player_index != player_index)
	shop._on_GoButton_pressed(player_index)
	_pending_synced_shop_start_id = 0
	return true


func _apply_shop_lock_action(player_index: int, message: Dictionary) -> bool:
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return false
	var shop_item = _get_shop_item_for_action(shop, player_index, message)
	if not _is_live_ref(shop_item):
		return false
	message["resolved_shop_index"] = _get_shop_item_index(shop_item, player_index)
	if bool(message.get("ban", false)):
		var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
		if _is_live_ref(container) and container.has_method("on_shop_item_ban_button_pressed") and container.is_connected("shop_item_banned", shop, "on_shop_item_banned"):
			container.on_shop_item_ban_button_pressed(shop_item)
			return true
		# When the network intercept bypasses ShopItemsContainer, directly calling
		# BaseShop.on_shop_item_banned() is not enough: the visual ShopItem remains
		# active and later state snapshots can make Clients display a banned item.
		# Emulate the container path: ShopItem.ban_item() consumes the ban token and
		# deactivates the visual slot, then BaseShop removes it from _shop_items.
		if shop_item.has_method("ban_item"):
			shop_item.ban_item()
		if shop.has_method("on_shop_item_banned"):
			shop.on_shop_item_banned(shop_item, player_index)
			return true
		return false
	var desired_locked = not bool(_safe_get(shop_item, "locked", false))
	if message.has("desired_locked"):
		desired_locked = bool(message.get("desired_locked", desired_locked))
	if shop_item.has_method("change_lock_status"):
		if bool(_safe_get(shop_item, "locked", false)) != desired_locked:
			shop_item.change_lock_status(desired_locked)
		else:
			_apply_shop_item_lock_visual_only(shop_item, desired_locked)
		var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
		if _is_live_ref(container) and container.has_method("update_buttons_color"):
			container.update_buttons_color()
		return true
	return false


func _queue_shop_state_from_menu_scene_state(state: Dictionary) -> void:
	if typeof(state) != TYPE_DICTIONARY:
		return
	if str(state.get("screen", "")) != SCREEN_SHOP:
		return
	var shop_state = state.get("shop_state", {})
	if typeof(shop_state) == TYPE_DICTIONARY:
		var players = shop_state.get("players", [])
		if typeof(players) == TYPE_ARRAY and not players.empty():
			_pending_shop_states_from_host = players.duplicate(true)


func _apply_or_queue_shop_states(states: Array, context: Dictionary = {}) -> void:
	if not _apply_all_shop_states_to_ui(states, context):
		_pending_shop_states_from_host = states.duplicate(true)


func _try_apply_pending_shop_state() -> void:
	if typeof(_pending_shop_states_from_host) != TYPE_ARRAY or _pending_shop_states_from_host.empty():
		return
	if _apply_all_shop_states_to_ui(_pending_shop_states_from_host, {}):
		_pending_shop_states_from_host = []


func _apply_all_shop_states_to_ui(states: Array, context: Dictionary = {}) -> bool:
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return false
	var applied = false
	var consumed = false
	_applying_remote_run_page_action = true
	for state in states:
		if typeof(state) != TYPE_DICTIONARY:
			continue
		if _should_skip_client_predicted_own_shop_state(state, context):
			consumed = true
			continue
		if _apply_shop_player_state_to_ui(shop, state):
			applied = true
	_applying_remote_run_page_action = false
	if (applied or consumed) and shop.has_method("update_go_next_button_text"):
		shop.update_go_next_button_text()
	return applied or consumed


func _set_player_gold_from_shop_state(player_index: int, gold_value: int) -> void:
	if player_index < 0:
		return
	if RunData.get_player_count() <= player_index:
		RunData.set_player_count(player_index + 1, false)
	if player_index >= RunData.players_data.size() or RunData.players_data[player_index] == null:
		return
	var player_data = RunData.players_data[player_index]
	var old_gold = int(_safe_get(player_data, "gold", gold_value))
	if old_gold == gold_value:
		return
	player_data.gold = gold_value
	if RunData.has_signal("gold_changed"):
		RunData.emit_signal("gold_changed", gold_value, player_index)


func _build_shop_slots_state_key_from_entries(item_entries: Array) -> String:
	if typeof(item_entries) != TYPE_ARRAY:
		return ""
	var parts = []
	for entry in item_entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var slot_index = int(entry.get("slot_index", entry.get("index", -1)))
		if bool(entry.get("slot_empty", false)) or not bool(entry.get("active", true)):
			parts.append(str(slot_index) + ":empty")
			continue
		parts.append(str(slot_index) + ":" + _build_shop_entry_identity_key(entry) + ":W" + str(int(entry.get("wave_value", RunData.current_wave))) + ":L" + ("1" if bool(entry.get("locked", false)) else "0") + ":B" + ("1" if bool(entry.get("buy_disabled", entry.get("disabled", false))) else "0") + ":S" + ("1" if bool(entry.get("steal_disabled", false)) else "0") + ":K" + ("1" if bool(entry.get("lock_disabled", false)) else "0") + ":N" + ("1" if bool(entry.get("ban_disabled", false)) else "0"))
	return "|".join(parts)


func _build_shop_action_delta_state(player_index: int, action_type: String, message: Dictionary = {}, applied: bool = true) -> Dictionary:
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop) or player_index < 0:
		return {}
	if not applied:
		var correction = _build_shop_player_state(player_index, shop, true)
		correction["full_snapshot"] = true
		correction["delta_action"] = action_type
		correction["host_applied"] = false
		_record_host_shop_state_baseline_from_state(correction)
		return correction

	var state = {
		"mode": "shop",
		"shop_delta": true,
		"delta_action": action_type,
		"host_applied": true,
		"player_index": player_index
	}
	_append_shop_scalar_state(state, shop, player_index)

	if action_type == "shop_reroll":
		state["shop_items"] = _build_shop_slot_entries_for_player(shop, player_index, -1)
		state["shop_items_full"] = true
	elif action_type == "shop_buy":
		var slot_index = int(message.get("resolved_shop_index", message.get("shop_index", -1)))
		state["shop_items"] = _build_shop_slot_entries_for_player(shop, player_index, slot_index)
		state["shop_items_full"] = false
		var inventory_delta = _build_shop_buy_inventory_delta_from_message(player_index, message)
		state["inventory_delta"] = inventory_delta
		if bool(inventory_delta.get("mirror_buy_requires_full_run_data", false)):
			_append_forced_shop_run_data_repair_to_delta_state(state, player_index, "mirror_buy")
		elif bool(inventory_delta.get("replace_weapons", false)) and _should_use_endless_incremental_items_only_shop_sync():
			_append_incremental_shop_runtime_state_to_delta_state(state, player_index, "weapon_buy")
	elif action_type == "shop_lock":
		var lock_slot_index = int(message.get("resolved_shop_index", message.get("shop_index", -1)))
		state["shop_items"] = _build_shop_slot_entries_for_player(shop, player_index, lock_slot_index)
		state["shop_items_full"] = false
	elif action_type == "shop_combine_weapon" or action_type == "shop_discard_weapon":
		state["inventory_delta"] = {
			"replace_weapons": true,
			"weapons": _serialize_inventory_data_list(RunData.get_player_weapons(player_index))
		}
		if _should_use_endless_incremental_items_only_shop_sync():
			_append_incremental_shop_runtime_state_to_delta_state(state, player_index, action_type)
		else:
			state["gear_key"] = _build_shop_gear_state_key(player_index)
	elif action_type == "shop_go":
		state["pressed_go"] = bool(_get_node_array_value(shop, "_player_pressed_go_button", player_index, false))

	if _should_use_endless_incremental_items_only_shop_sync():
		_record_host_shop_state_baseline_from_state(state)
	else:
		_record_host_shop_player_state_baseline(player_index, shop)
	return state


func _build_shop_items_resync_state(player_index: int) -> Dictionary:
	if _should_use_endless_incremental_items_only_shop_sync():
		return {}
	var run_data_sync = _build_shop_run_data_sync_state(player_index, true, SHOP_HELD_ITEMS_SYNC_COMPACT)
	var run_data_state = run_data_sync.get("run_data", {})
	return {
		"mode": "shop",
		"player_index": player_index,
		"run_data_only": true,
		"held_items_resync": true,
		"held_items_hash": str(run_data_state.get("held_items_hash", "0")) if typeof(run_data_state) == TYPE_DICTIONARY else "0",
		"run_data_key": str(run_data_sync.get("run_data_key", "")) + ":items_resync",
		"run_data_full": bool(run_data_sync.get("run_data_full", false)),
		"run_data": run_data_state,
		"gear_key": _build_shop_gear_state_key(player_index)
	}


func _append_shop_scalar_state(state: Dictionary, shop: Node, player_index: int) -> void:
	state["current_wave"] = int(RunData.current_wave)
	state["gold"] = int(RunData.get_player_gold(player_index))
	state["current_health"] = _get_player_current_health_value(player_index)
	state["reroll_price"] = int(_get_node_array_value(shop, "_reroll_price", player_index, 0))
	state["reroll_count"] = int(_get_node_array_value(shop, "_reroll_count", player_index, 0))
	state["paid_reroll_count"] = int(_get_node_array_value(shop, "_paid_reroll_count", player_index, 0))
	state["initial_free_rerolls"] = int(_get_node_array_value(shop, "_initial_free_rerolls", player_index, 0))
	state["free_rerolls"] = int(_get_node_array_value(shop, "_free_rerolls", player_index, 0))
	state["has_bonus_free_reroll"] = bool(_get_node_array_value(shop, "_has_bonus_free_reroll", player_index, false))
	state["item_steals"] = int(_get_node_array_value(shop, "_item_steals", player_index, 0))
	state["pressed_go"] = bool(_get_node_array_value(shop, "_player_pressed_go_button", player_index, false))


func _get_player_current_health_value(player_index: int) -> int:
	if player_index < 0 or player_index >= RunData.players_data.size() or RunData.players_data[player_index] == null:
		return 0
	return int(_safe_get(RunData.players_data[player_index], "current_health", 0))


func _set_player_current_health_from_shop_state(player_index: int, health_value: int) -> void:
	if player_index < 0:
		return
	if RunData.get_player_count() <= player_index:
		RunData.set_player_count(player_index + 1, false)
	if player_index >= RunData.players_data.size() or RunData.players_data[player_index] == null:
		return
	RunData.players_data[player_index].current_health = health_value


func _build_shop_slot_entries_for_player(shop: Node, player_index: int, slot_index: int = -1) -> Array:
	var entries = []
	if not _is_valid_shop_node(shop):
		return entries
	var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
	var visual_items = _safe_get(container, "_shop_items", []) if _is_live_ref(container) else []
	if typeof(visual_items) == TYPE_ARRAY and not visual_items.empty():
		var start_idx = 0 if slot_index < 0 else slot_index
		var end_idx = visual_items.size() - 1 if slot_index < 0 else slot_index
		for idx in range(start_idx, end_idx + 1):
			if idx < 0 or idx >= visual_items.size():
				continue
			var shop_item_node = visual_items[idx]
			if not _is_live_ref(shop_item_node) or not bool(_safe_get(shop_item_node, "active", false)) or _safe_get(shop_item_node, "item_data", null) == null:
				entries.append(_build_empty_shop_slot_entry(idx))
			else:
				entries.append(_build_visual_shop_item_entry(container, shop_item_node, idx))
		return entries
	if slot_index >= 0:
		entries.append(_build_empty_shop_slot_entry(slot_index))
	return entries


func _build_shop_buy_inventory_delta_from_message(player_index: int, message: Dictionary) -> Dictionary:
	var item_state = message.get("resolved_item", {})
	if typeof(item_state) != TYPE_DICTIONARY or item_state.empty():
		item_state = message.get("item", {})
	if typeof(item_state) != TYPE_DICTIONARY or item_state.empty():
		return {}
	if str(item_state.get("type", "")) == "weapon":
		return {
			"replace_weapons": true,
			"weapons": _serialize_inventory_data_list(RunData.get_player_weapons(player_index))
		}
	if _is_mirror_item_state(item_state):
		# Mirror consumes an existing duplicate_item source and may add multiple copies of
		# the bought item. A simple items_added delta can desync PlayerRunData.items from
		# PlayerRunData.effects[duplicate_item], so ship a full RunData repair with it.
		return {
			"mirror_buy_requires_full_run_data": true,
			"replace_items": true,
			"items": _serialize_inventory_data_list(RunData.get_player_items(player_index))
		}
	return {"items_added": [item_state]}


func _is_mirror_item_state(item_state: Dictionary) -> bool:
	if typeof(item_state) != TYPE_DICTIONARY or item_state.empty():
		return false
	if str(item_state.get("my_id", "")) == "item_mirror":
		return true
	var mirror_hash = int(_safe_get(Keys, "item_mirror_hash", 0))
	if mirror_hash != 0 and int(item_state.get("my_id_hash", 0)) == mirror_hash:
		return true
	var resource_path = str(item_state.get("resource_path", ""))
	return resource_path.find("/items/mirror/") != -1 or resource_path.find("/items/mirror_data.tres") != -1


func _append_forced_shop_run_data_repair_to_delta_state(state: Dictionary, player_index: int, reason: String) -> void:
	var run_data_sync = _build_forced_full_shop_run_data_repair_state(player_index, reason)
	var run_data_state = run_data_sync.get("run_data", {})
	if typeof(run_data_state) != TYPE_DICTIONARY or run_data_state.empty():
		return
	state["run_data_key"] = str(run_data_sync.get("run_data_key", ""))
	state["run_data_full"] = true
	state["run_data"] = run_data_state
	state["force_run_data_repair"] = true
	state["run_data_repair_reason"] = reason
	state["gear_key"] = _build_shop_gear_state_key(player_index)


func _append_incremental_shop_runtime_state_to_delta_state(state: Dictionary, player_index: int, reason: String) -> void:
	var run_data_sync = _build_shop_run_data_sync_state(player_index, true, SHOP_HELD_ITEMS_SYNC_INCREMENTAL_ONLY)
	var run_data_state = run_data_sync.get("run_data", {})
	if typeof(run_data_state) != TYPE_DICTIONARY or run_data_state.empty():
		return
	state["run_data_key"] = str(run_data_sync.get("run_data_key", "")) + ":runtime_delta:" + reason + ":" + str(OS.get_ticks_msec())
	state["run_data_full"] = true
	state["run_data"] = run_data_state
	state["run_data_incremental_items_only"] = true
	state["run_data_repair_reason"] = reason
	state["gear_key"] = _build_shop_gear_state_key(player_index)


func _build_forced_full_shop_run_data_repair_state(player_index: int, reason: String) -> Dictionary:
	if player_index < 0 or player_index >= RunData.players_data.size() or RunData.players_data[player_index] == null:
		return {}
	var player_data = RunData.players_data[player_index]
	if not player_data.has_method("serialize"):
		return {}
	var run_data_state = player_data.serialize()
	if typeof(run_data_state) != TYPE_DICTIONARY or run_data_state.empty():
		return {}
	run_data_state["player_index"] = player_index
	var run_data_key = _build_shop_run_data_sync_key(player_index)
	if run_data_key == "":
		run_data_key = str(player_index) + ":" + str(OS.get_ticks_msec())
	run_data_key += ":forced_repair:" + reason + ":" + str(OS.get_ticks_msec())
	return {
		"run_data_key": run_data_key,
		"run_data_full": true,
		"run_data": run_data_state
	}


func _serialize_inventory_data_list(items: Array) -> Array:
	var result = []
	if typeof(items) != TYPE_ARRAY:
		return result
	for item in items:
		result.append(_serialize_item_parent_data(item))
	return result


func _apply_shop_delta_state_to_ui(shop: Node, state: Dictionary) -> bool:
	var player_index = int(state.get("player_index", -1))
	if not _is_valid_shop_node(shop) or player_index < 0:
		return false
	var shop_player_key = str(shop.get_instance_id()) + ":" + str(player_index)
	if state.has("current_wave"):
		RunData.current_wave = int(state.get("current_wave", RunData.current_wave))
	if state.has("gold"):
		_set_player_gold_from_shop_state(player_index, int(state.get("gold", RunData.get_player_gold(player_index))))
	if state.has("current_health"):
		_set_player_current_health_from_shop_state(player_index, int(state.get("current_health", _get_player_current_health_value(player_index))))

	var inventory_changed = false
	var run_data_key = str(state.get("run_data_key", ""))
	var run_data_state = state.get("run_data", {})
	if typeof(run_data_state) == TYPE_DICTIONARY and not run_data_state.empty():
		var last_run_data_key = str(_last_applied_shop_run_data_key_by_player.get(player_index, ""))
		if bool(state.get("force_run_data_repair", false)) or run_data_key == "" or run_data_key != last_run_data_key:
			if _apply_one_serialized_player_run_data(player_index, run_data_state):
				_apply_missing_host_inventory_placeholders_from_serialized_state(player_index, _expand_compact_player_run_data_from_shop_sync(player_index, run_data_state))
				_last_applied_shop_gear_key_by_player.erase(shop_player_key)
				inventory_changed = true
				if bool(state.get("force_run_data_repair", false)) and not _is_game_host() and player_index == _get_local_client_player_index():
					_clear_client_shop_prediction(player_index)
				if run_data_key != "":
					_last_applied_shop_run_data_key_by_player[player_index] = run_data_key

	if _apply_shop_inventory_delta_to_run_data(player_index, state.get("inventory_delta", {})):
		inventory_changed = true
	var item_entries = state.get("shop_items", [])
	if typeof(item_entries) == TYPE_ARRAY and not item_entries.empty():
		var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
		if bool(state.get("shop_items_full", false)):
			_replace_client_locked_shop_items_from_host_entries(player_index, item_entries)
			var player_shop_items = _resolve_shop_state_active_items(item_entries, player_index)
			_set_shop_player_items_array(shop, player_index, player_shop_items)
			_last_applied_shop_slots_key_by_player[shop_player_key] = _build_shop_slots_state_key_from_entries(item_entries)
			if _is_live_ref(container):
				_apply_shop_state_entries_to_container(container, item_entries, player_index)
		else:
			if _is_live_ref(container):
				_apply_shop_delta_entries_to_container(container, item_entries, player_index)
			_last_applied_shop_slots_key_by_player.erase(shop_player_key)

	_apply_shop_scalar_fields_to_node(shop, player_index, state)

	var container_after = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
	if _is_live_ref(container_after):
		container_after.item_steals = int(state.get("item_steals", _safe_get(container_after, "item_steals", 0)))
		container_after.update_buttons_color()
		if not _is_game_host() and player_index == _get_local_client_player_index():
			_intercept_client_shop_item_buttons(container_after, player_index)
	if shop.has_method("set_reroll_button_price") and state.has("reroll_price"):
		shop.set_reroll_button_price(player_index)
	_force_shop_reroll_price_from_host(shop, player_index, state)

	var gold_label = shop._get_gold_label(player_index) if shop.has_method("_get_gold_label") else null
	if _is_live_ref(gold_label) and gold_label.has_method("update_value"):
		gold_label.update_value(RunData.get_player_gold(player_index))

	var gear_container = shop._get_gear_container(player_index) if shop.has_method("_get_gear_container") else null
	if _is_live_ref(gear_container):
		if inventory_changed:
			_last_applied_shop_gear_key_by_player.erase(shop_player_key)
			_force_rebuild_shop_gear_container(shop, player_index)
		else:
			_ensure_shop_inventory_popup_wiring_for_player(shop, player_index, not _is_game_host() and player_index == _get_local_client_player_index())

	var checkmark = shop._get_checkmark(player_index) if shop.has_method("_get_checkmark") else null
	if _is_live_ref(checkmark) and state.has("pressed_go"):
		if bool(state.get("pressed_go", false)):
			checkmark.show()
		else:
			checkmark.hide()
	return true


func _apply_shop_scalar_fields_to_node(shop: Node, player_index: int, state: Dictionary) -> void:
	if state.has("reroll_price"):
		_set_node_array_value(shop, "_reroll_price", player_index, int(state.get("reroll_price", 0)))
	if state.has("reroll_count"):
		_set_node_array_value(shop, "_reroll_count", player_index, int(state.get("reroll_count", 0)))
	if state.has("paid_reroll_count"):
		_set_node_array_value(shop, "_paid_reroll_count", player_index, int(state.get("paid_reroll_count", 0)))
	if state.has("initial_free_rerolls"):
		_set_node_array_value(shop, "_initial_free_rerolls", player_index, int(state.get("initial_free_rerolls", 0)))
	if state.has("free_rerolls"):
		_set_node_array_value(shop, "_free_rerolls", player_index, int(state.get("free_rerolls", 0)))
	if state.has("has_bonus_free_reroll"):
		_set_node_array_value(shop, "_has_bonus_free_reroll", player_index, bool(state.get("has_bonus_free_reroll", false)))
	if state.has("item_steals"):
		_set_node_array_value(shop, "_item_steals", player_index, int(state.get("item_steals", 0)))
	if state.has("pressed_go"):
		_set_node_array_value(shop, "_player_pressed_go_button", player_index, bool(state.get("pressed_go", false)))


func _force_shop_reroll_price_from_host(shop: Node, player_index: int, state: Dictionary) -> void:
	if not _is_valid_shop_node(shop) or player_index < 0 or not state.has("reroll_price"):
		return
	var host_price = int(state.get("reroll_price", 0))
	# BaseShop.set_reroll_button_price() rewrites _reroll_price to 0 whenever local
	# _free_rerolls / _has_bonus_free_reroll is stale. Host price is authoritative.
	if host_price > 0:
		_set_node_array_value(shop, "_free_rerolls", player_index, 0)
		_set_node_array_value(shop, "_has_bonus_free_reroll", player_index, false)
	_set_node_array_value(shop, "_reroll_price", player_index, host_price)
	var reroll_button = shop._get_reroll_button(player_index) if shop.has_method("_get_reroll_button") else null
	if _is_live_ref(reroll_button):
		if reroll_button.has_method("init"):
			reroll_button.init(host_price, player_index)
		if reroll_button.has_method("set_color_from_currency"):
			reroll_button.set_color_from_currency(RunData.get_player_gold(player_index))


func _apply_shop_inventory_delta_to_run_data(player_index: int, inventory_delta) -> bool:
	if typeof(inventory_delta) != TYPE_DICTIONARY or inventory_delta.empty():
		return false
	if player_index < 0:
		return false
	if RunData.get_player_count() <= player_index:
		RunData.set_player_count(player_index + 1, false)
	if player_index >= RunData.players_data.size() or RunData.players_data[player_index] == null:
		return false
	var player_data = RunData.players_data[player_index]
	var changed = false
	if bool(inventory_delta.get("replace_weapons", false)):
		player_data.weapons = _resolve_serialized_inventory_data_list(inventory_delta.get("weapons", []))
		changed = true
	if bool(inventory_delta.get("replace_items", false)):
		player_data.items = _resolve_serialized_inventory_data_list(inventory_delta.get("items", []))
		changed = true
	var weapons_added = inventory_delta.get("weapons_added", [])
	if typeof(weapons_added) == TYPE_ARRAY:
		for weapon_state in weapons_added:
			if typeof(weapon_state) != TYPE_DICTIONARY:
				continue
			var weapon_data = _resolve_item_parent_data(weapon_state)
			if weapon_data != null:
				player_data.weapons.append(weapon_data)
				changed = true
	var items_added = inventory_delta.get("items_added", [])
	if typeof(items_added) == TYPE_ARRAY:
		for item_state in items_added:
			if typeof(item_state) != TYPE_DICTIONARY:
				continue
			var item_data = _resolve_item_parent_data(item_state)
			if item_data != null:
				_add_shop_item_delta_to_player_run_data(player_index, item_data)
				changed = true
	return changed


func _add_shop_item_delta_to_player_run_data(player_index: int, item_data) -> void:
	if item_data == null:
		return
	# Use RunData.add_item so remote clients apply the same stat/effect mutation as the Host.
	# The old append-only path kept the visual list updated but left attributes stale until a
	# later full RunData repair, which wave 21+ intentionally no longer sends for held items.
	var item_to_add = item_data.duplicate() if item_data.has_method("duplicate") else item_data
	if RunData.has_method("add_item"):
		RunData.add_item(item_to_add, player_index, false)
		return
	if player_index >= 0 and player_index < RunData.players_data.size() and RunData.players_data[player_index] != null:
		RunData.players_data[player_index].items.append(item_to_add)


func _resolve_serialized_inventory_data_list(serialized_items) -> Array:
	var result = []
	if typeof(serialized_items) != TYPE_ARRAY:
		return result
	for serialized in serialized_items:
		if typeof(serialized) != TYPE_DICTIONARY:
			continue
		var item_data = _resolve_item_parent_data(serialized)
		if item_data != null:
			result.append(item_data)
	return result


func _apply_shop_delta_entries_to_container(container, item_entries: Array, player_index: int) -> void:
	if not _is_live_ref(container) or typeof(item_entries) != TYPE_ARRAY:
		return
	var shop_item_nodes = _safe_get(container, "_shop_items", [])
	if typeof(shop_item_nodes) != TYPE_ARRAY:
		return
	for entry in item_entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var slot_index = int(entry.get("slot_index", entry.get("index", -1)))
		if slot_index < 0 or slot_index >= shop_item_nodes.size():
			continue
		var shop_item_node = shop_item_nodes[slot_index]
		if not _is_live_ref(shop_item_node):
			continue
		if bool(entry.get("slot_empty", false)) or not bool(entry.get("active", true)):
			_deactivate_shop_item_visual_if_needed(shop_item_node)
			_apply_shop_item_entry_button_state(container, entry)
			continue
		var item_data = _resolve_item_parent_data(entry.get("item", {}))
		if item_data == null:
			_deactivate_shop_item_visual_if_needed(shop_item_node)
			continue
		shop_item_node.item_steals = int(_safe_get(container, "item_steals", 0))
		if shop_item_node.has_method("set_shop_item"):
			shop_item_node.set_shop_item(item_data, int(entry.get("wave_value", RunData.current_wave)))
		_apply_shop_item_lock_visual_only(shop_item_node, bool(entry.get("locked", false)))
		_apply_shop_item_entry_button_state(container, entry)


func _apply_shop_player_state_to_ui(shop: Node, state: Dictionary) -> bool:
	var player_index = int(state.get("player_index", -1))
	if player_index < 0:
		return false
	if bool(state.get("shop_delta", false)):
		return _apply_shop_delta_state_to_ui(shop, state)

	var incoming_state_key = _build_shop_state_prediction_key_from_state(state)
	var applied_key = str(_last_applied_shop_state_key_by_player.get(player_index, ""))
	if incoming_state_key != "" and incoming_state_key == applied_key:
		# Accept duplicate authoritative states without rebuilding ShopItem/gear UI.
		# Still re-assert reroll price because vanilla can rewrite it to 0 from stale
		# local free-reroll flags after the authoritative state was applied.
		_force_shop_reroll_price_from_host(shop, player_index, state)
		return true

	if state.has("current_wave"):
		RunData.current_wave = int(state.get("current_wave", RunData.current_wave))

	var run_data_key = str(state.get("run_data_key", ""))
	var run_data_state = state.get("run_data", {})
	if typeof(run_data_state) == TYPE_DICTIONARY and not run_data_state.empty():
		var last_run_data_key = str(_last_applied_shop_run_data_key_by_player.get(player_index, ""))
		if run_data_key == "" or run_data_key != last_run_data_key:
			if _apply_one_serialized_player_run_data(player_index, run_data_state):
				_apply_missing_host_inventory_placeholders_from_serialized_state(player_index, _expand_compact_player_run_data_from_shop_sync(player_index, run_data_state))
				_last_applied_shop_gear_key_by_player.erase(str(shop.get_instance_id()) + ":" + str(player_index))
				if run_data_key != "":
					_last_applied_shop_run_data_key_by_player[player_index] = run_data_key
	elif run_data_key != "" and not _last_applied_shop_run_data_key_by_player.has(player_index):
		# A delta-only shop_state arrived before the first full inventory snapshot. Keep the
		# raw UI changes, but do not mark the inventory as applied; the next full snapshot
		# will still rebuild the gear panel once.
		pass

	if bool(state.get("run_data_only", false)):
		var gear_container_only = shop._get_gear_container(player_index) if shop.has_method("_get_gear_container") else null
		if _is_live_ref(gear_container_only):
			_last_applied_shop_gear_key_by_player.erase(str(shop.get_instance_id()) + ":" + str(player_index))
			_apply_shop_gear_state_if_changed(shop, gear_container_only, player_index, str(state.get("gear_key", "")))
		_pending_shop_items_resync_key_by_player.erase(player_index)
		_pending_shop_items_resync_until_by_player.erase(player_index)
		return true

	_set_player_gold_from_shop_state(player_index, int(state.get("gold", RunData.get_player_gold(player_index))))
	if state.has("current_health"):
		_set_player_current_health_from_shop_state(player_index, int(state.get("current_health", _get_player_current_health_value(player_index))))

	var item_entries = state.get("shop_items", [])
	if typeof(item_entries) != TYPE_ARRAY:
		item_entries = []
	var shop_slots_key = _build_shop_slots_state_key_from_entries(item_entries)
	var shop_player_key = str(shop.get_instance_id()) + ":" + str(player_index)
	var shop_slots_changed = shop_slots_key == "" or str(_last_applied_shop_slots_key_by_player.get(shop_player_key, "")) != shop_slots_key
	if shop_slots_changed:
		_replace_client_locked_shop_items_from_host_entries(player_index, item_entries)
		var player_shop_items = _resolve_shop_state_active_items(item_entries, player_index)
		_set_shop_player_items_array(shop, player_index, player_shop_items)
		if shop_slots_key != "":
			_last_applied_shop_slots_key_by_player[shop_player_key] = shop_slots_key

	_set_node_array_value(shop, "_reroll_price", player_index, int(state.get("reroll_price", 0)))
	_set_node_array_value(shop, "_reroll_count", player_index, int(state.get("reroll_count", 0)))
	_set_node_array_value(shop, "_paid_reroll_count", player_index, int(state.get("paid_reroll_count", 0)))
	_set_node_array_value(shop, "_initial_free_rerolls", player_index, int(state.get("initial_free_rerolls", 0)))
	_set_node_array_value(shop, "_free_rerolls", player_index, int(state.get("free_rerolls", 0)))
	_set_node_array_value(shop, "_has_bonus_free_reroll", player_index, bool(state.get("has_bonus_free_reroll", false)))
	_set_node_array_value(shop, "_item_steals", player_index, int(state.get("item_steals", 0)))
	var pressed_go = bool(state.get("pressed_go", false))
	# If this Client just pressed Go, a delayed generic shop_state from before the
	# Host-confirmed shop_go can otherwise hide the local ready checkmark. Keep the
	# optimistic ready visual briefly until the authoritative shop_go/shop_state lands.
	if not pressed_go and int(_local_shop_go_pending_until_by_player.get(player_index, 0)) > OS.get_ticks_msec():
		pressed_go = true
	_set_node_array_value(shop, "_player_pressed_go_button", player_index, pressed_go)

	var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
	if _is_live_ref(container):
		container.item_steals = int(state.get("item_steals", 0))
		if shop_slots_changed:
			_apply_shop_state_entries_to_container(container, item_entries, player_index)
		container.update_buttons_color()
		if not _is_game_host() and player_index == _get_local_client_player_index():
			_intercept_client_shop_item_buttons(container, player_index)
	if shop.has_method("set_reroll_button_price"):
		shop.set_reroll_button_price(player_index)
	_force_shop_reroll_price_from_host(shop, player_index, state)

	var gold_label = shop._get_gold_label(player_index) if shop.has_method("_get_gold_label") else null
	if _is_live_ref(gold_label) and gold_label.has_method("update_value"):
		gold_label.update_value(RunData.get_player_gold(player_index))

	var gear_container = shop._get_gear_container(player_index) if shop.has_method("_get_gear_container") else null
	if _is_live_ref(gear_container):
		_apply_shop_gear_state_if_changed(shop, gear_container, player_index, run_data_key)

	var checkmark = shop._get_checkmark(player_index) if shop.has_method("_get_checkmark") else null
	if _is_live_ref(checkmark):
		if pressed_go:
			checkmark.show()
		else:
			checkmark.hide()

	if incoming_state_key != "":
		_last_applied_shop_state_key_by_player[player_index] = incoming_state_key
	return true


func _apply_shop_gear_state_if_changed(shop: Node, gear_container, player_index: int, expected_key: String = "") -> void:
	if not _is_valid_shop_node(shop) or not _is_live_ref(gear_container):
		return
	var key = expected_key
	if key == "":
		key = _build_shop_gear_state_key(player_index)
	var shop_key = str(shop.get_instance_id()) + ":" + str(player_index)
	if str(_last_applied_shop_gear_key_by_player.get(shop_key, "")) == key:
		_ensure_shop_inventory_popup_wiring_for_player(shop, player_index, not _is_game_host() and player_index == _get_local_client_player_index())
		return

	# set_weapons_data()/set_items_data() rebuild InventoryElement nodes. Rebuilding them
	# on every Host shop_state destroys the weapon popup focus chain. Only rebuild when
	# the authoritative inventory really changed, then reconnect the popup signal chain.
	_last_applied_shop_gear_key_by_player[shop_key] = key
	if _is_live_ref(_safe_get(gear_container, "weapons_container", null)):
		gear_container.set_weapons_data(RunData.get_player_weapons(player_index))
	if _is_live_ref(_safe_get(gear_container, "items_container", null)):
		gear_container.set_items_data(RunData.get_player_items(player_index))

	_ensure_shop_inventory_popup_wiring_for_player(shop, player_index, not _is_game_host() and player_index == _get_local_client_player_index())


func _build_shop_gear_state_key(player_index: int) -> String:
	return to_json({
		"id_only": true,
		"weapons": _build_id_only_live_inventory_key(RunData.get_player_weapons(player_index), false),
		"items": _build_id_only_live_inventory_key(RunData.get_player_items(player_index), true)
	})


func _build_inventory_data_key(items: Array) -> Array:
	var result = []
	if typeof(items) != TYPE_ARRAY:
		return result
	for item in items:
		if item == null:
			result.append("null")
			continue
		result.append(_build_inventory_item_key(item))
	return result


func _build_inventory_item_key(item) -> String:
	if item == null:
		return "null"
	var parts = []
	parts.append(str(_safe_get(item, "my_id_hash", 0)))
	parts.append(str(_safe_get(item, "weapon_id_hash", 0)))
	parts.append(str(_safe_get(item, "my_id", "")))
	parts.append(str(_safe_get(item, "weapon_id", "")))
	parts.append(str(_safe_get(item, "tier", -1)))
	parts.append(str(_safe_get(item, "value", 0)))
	parts.append(str(_safe_get(item, "is_cursed", false)))
	parts.append(str(_safe_get(item, "dmg_dealt_last_wave", 0)))
	return "|".join(parts)


func _ensure_shop_inventory_popup_wiring_for_player(shop: Node, player_index: int, client_action_intercept: bool) -> void:
	if not _is_valid_shop_node(shop) or player_index < 0:
		return
	var gear_container = shop._get_gear_container(player_index) if shop.has_method("_get_gear_container") else null
	if _is_live_ref(gear_container):
		_reconnect_shop_inventory_popup_sources(shop, gear_container, player_index)
	_ensure_shop_item_popup_action_connections(shop, player_index, client_action_intercept)


func _reconnect_shop_inventory_popup_sources(shop: Node, gear_container, player_index: int) -> void:
	if not _is_valid_shop_node(shop) or not _is_live_ref(gear_container):
		return
	var popup_manager = _safe_get(shop, "_popup_manager", null)
	if not _is_live_ref(popup_manager):
		return
	var weapons_container = _safe_get(gear_container, "weapons_container", null)
	if _is_live_ref(weapons_container):
		_ensure_popup_manager_inventory_connection(popup_manager, weapons_container)
	var items_container = _safe_get(gear_container, "items_container", null)
	if _is_live_ref(items_container):
		_ensure_popup_manager_inventory_connection(popup_manager, items_container)

	# BaseShop._ready connects PopupManager.element_pressed to CoopShop._on_element_pressed.
	# Some online scene rewiring paths leave the inventory side alive but this shop-side
	# connection missing, which makes a weapon click only flash the panel without opening
	# Combine/Recycle/Cancel.
	if not popup_manager.is_connected("element_pressed", shop, "_on_element_pressed"):
		popup_manager.connect("element_pressed", shop, "_on_element_pressed")
	if not popup_manager.is_connected("element_focused", shop, "_on_element_focused"):
		popup_manager.connect("element_focused", shop, "_on_element_focused")
	if not popup_manager.is_connected("element_unfocused", shop, "_on_element_unfocused"):
		popup_manager.connect("element_unfocused", shop, "_on_element_unfocused")


func _ensure_popup_manager_inventory_connection(popup_manager, inventory_container) -> void:
	if not _is_live_ref(popup_manager) or not _is_live_ref(inventory_container):
		return
	var inventory = _safe_get(inventory_container, "_elements", null)
	if not _is_live_ref(inventory):
		return
	var specs = [
		["element_hovered", "_on_element_hovered"],
		["element_unhovered", "_on_element_unhovered"],
		["element_focused", "_on_element_focused"],
		["element_unfocused", "_on_element_unfocused"],
		["element_pressed", "_on_element_pressed"]
	]
	for spec in specs:
		var signal_name = str(spec[0])
		var method_name = str(spec[1])
		if not inventory.is_connected(signal_name, popup_manager, method_name):
			inventory.connect(signal_name, popup_manager, method_name)


func _find_shop_inventory_element_by_instance_id(shop: Node, player_index: int, element_instance_id: int):
	var weapons = _get_shop_inventory_elements(shop, player_index, true)
	for element in weapons:
		if _is_live_ref(element) and int(element.get_instance_id()) == element_instance_id:
			return element
	var items = _get_shop_inventory_elements(shop, player_index, false)
	for element in items:
		if _is_live_ref(element) and int(element.get_instance_id()) == element_instance_id:
			return element
	return null


func _ensure_shop_item_popup_action_connections(shop: Node, player_index: int, client_action_intercept: bool) -> void:
	if not _is_valid_shop_node(shop):
		return
	var item_popup = shop._get_item_popup(player_index) if shop.has_method("_get_item_popup") else null
	if not _is_live_ref(item_popup):
		return
	if client_action_intercept:
		if item_popup.is_connected("item_combine_button_pressed", shop, "_on_item_combine_button_pressed"):
			item_popup.disconnect("item_combine_button_pressed", shop, "_on_item_combine_button_pressed")
		if not item_popup.is_connected("item_combine_button_pressed", self, "_on_client_shop_combine_weapon_pressed"):
			item_popup.connect("item_combine_button_pressed", self, "_on_client_shop_combine_weapon_pressed", [player_index])
		if item_popup.is_connected("item_discard_button_pressed", shop, "_on_item_discard_button_pressed"):
			item_popup.disconnect("item_discard_button_pressed", shop, "_on_item_discard_button_pressed")
		if not item_popup.is_connected("item_discard_button_pressed", self, "_on_client_shop_discard_weapon_pressed"):
			item_popup.connect("item_discard_button_pressed", self, "_on_client_shop_discard_weapon_pressed", [player_index])
	else:
		if item_popup.is_connected("item_combine_button_pressed", self, "_on_client_shop_combine_weapon_pressed"):
			item_popup.disconnect("item_combine_button_pressed", self, "_on_client_shop_combine_weapon_pressed")
		if item_popup.is_connected("item_discard_button_pressed", self, "_on_client_shop_discard_weapon_pressed"):
			item_popup.disconnect("item_discard_button_pressed", self, "_on_client_shop_discard_weapon_pressed")
		if not item_popup.is_connected("item_combine_button_pressed", shop, "_on_item_combine_button_pressed"):
			item_popup.connect("item_combine_button_pressed", shop, "_on_item_combine_button_pressed", [player_index])
		if not item_popup.is_connected("item_discard_button_pressed", shop, "_on_item_discard_button_pressed"):
			item_popup.connect("item_discard_button_pressed", shop, "_on_item_discard_button_pressed", [player_index])
	if not item_popup.is_connected("item_cancel_button_pressed", shop, "_on_item_cancel_button_pressed"):
		item_popup.connect("item_cancel_button_pressed", shop, "_on_item_cancel_button_pressed", [player_index])
	_ensure_shop_inventory_custom_popup_button_wiring(item_popup, player_index)


func _reset_shop_inventory_custom_button_runtime_state(clear_recent: bool = true) -> void:
	_shop_inventory_custom_button_popup_key_by_player.clear()
	_shop_inventory_custom_button_connected_keys.clear()
	_shop_inventory_custom_button_deferred_apply_keys.clear()
	_shop_inventory_custom_button_descriptor_cache.clear()
	if clear_recent:
		_shop_inventory_custom_button_recent_press_keys.clear()


func _ensure_shop_inventory_custom_popup_button_wiring(item_popup: Node, player_index: int) -> void:
	if not _is_online_session_active():
		return
	if not _is_live_ref(item_popup) or player_index < 0:
		return
	# Inventory popup compatibility is shop-only. Do not let main.tscn battle popups or
	# stale shop nodes trigger recursive Button scans during combat input.
	if _get_current_menu_screen_fast() != SCREEN_SHOP:
		return
	if not item_popup.is_connected("visibility_changed", self, "_on_shop_inventory_popup_visibility_changed"):
		item_popup.connect("visibility_changed", self, "_on_shop_inventory_popup_visibility_changed", [player_index, int(item_popup.get_instance_id())])
	if item_popup.visible and item_popup.is_inside_tree():
		call_deferred("_scan_shop_inventory_custom_popup_buttons_deferred", player_index, int(item_popup.get_instance_id()), false)


func _on_shop_inventory_popup_visibility_changed(player_index: int, popup_instance_id: int) -> void:
	if _get_current_menu_screen_fast() != SCREEN_SHOP:
		return
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return
	var item_popup = shop._get_item_popup(player_index) if shop.has_method("_get_item_popup") else null
	if not _is_live_ref(item_popup) or int(item_popup.get_instance_id()) != popup_instance_id:
		return
	if not item_popup.visible or not item_popup.is_inside_tree():
		_shop_inventory_custom_button_popup_key_by_player.erase(player_index)
		return
	call_deferred("_scan_shop_inventory_custom_popup_buttons_deferred", player_index, popup_instance_id, false)
	call_deferred("_scan_shop_inventory_custom_popup_buttons_deferred", player_index, popup_instance_id, true)


func _scan_shop_inventory_custom_popup_buttons_deferred(player_index: int, popup_instance_id: int, force_rescan: bool = false) -> void:
	if _get_current_menu_screen_fast() != SCREEN_SHOP:
		return
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return
	var item_popup = shop._get_item_popup(player_index) if shop.has_method("_get_item_popup") else null
	if not _is_live_ref(item_popup) or int(item_popup.get_instance_id()) != popup_instance_id:
		return
	if not item_popup.visible or not item_popup.is_inside_tree():
		return
	var popup_key = str(popup_instance_id) + ":" + _get_shop_inventory_popup_item_key(item_popup)
	if not force_rescan and str(_shop_inventory_custom_button_popup_key_by_player.get(player_index, "")) == popup_key:
		return
	_shop_inventory_custom_button_popup_key_by_player[player_index] = popup_key
	var buttons = []
	_collect_shop_inventory_custom_popup_buttons(item_popup, item_popup, buttons)
	for button in buttons:
		if not _is_live_ref(button):
			continue
		var connected_key = str(popup_instance_id) + ":" + str(button.get_instance_id())
		_shop_inventory_custom_button_connected_keys[connected_key] = OS.get_ticks_msec()
		var descriptor = _build_shop_inventory_custom_button_descriptor(item_popup, button, player_index)
		if not descriptor.empty():
			_shop_inventory_custom_button_descriptor_cache[_get_shop_inventory_custom_button_cache_key(popup_instance_id, button)] = descriptor
		# Send on button_down too. Many third-party buttons mutate/close the popup in
		# their pressed handler before our later pressed callback can read _item_data.
		# button_down captures the item/button identity before the mod consumes it;
		# pressed stays as a fallback for keyboard/programmatic activation.
		if not button.is_connected("button_down", self, "_on_shop_inventory_custom_button_down"):
			button.connect("button_down", self, "_on_shop_inventory_custom_button_down", [player_index, popup_instance_id, button])
		if not button.is_connected("pressed", self, "_on_shop_inventory_custom_button_pressed"):
			button.connect("pressed", self, "_on_shop_inventory_custom_button_pressed", [player_index, popup_instance_id, button])


func _collect_shop_inventory_custom_popup_buttons(root_popup: Node, node: Node, out: Array) -> void:
	if not _is_live_ref(node):
		return
	if node is BaseButton and _is_shop_inventory_custom_popup_button(root_popup, node):
		out.append(node)
	for child in node.get_children():
		if child is Node:
			_collect_shop_inventory_custom_popup_buttons(root_popup, child, out)


func _is_shop_inventory_custom_popup_button(item_popup: Node, button: Node) -> bool:
	if not _is_live_ref(item_popup) or not _is_live_ref(button):
		return false
	if not (button is BaseButton):
		return false
	if not _safe_node_is_parent_of(item_popup, button):
		return false
	# Exclude vanilla ItemPopup buttons. These already have explicit online paths
	# (combine/recycle/cancel), and taking them generically would double-execute them.
	var vanilla_refs = [
		_safe_get(item_popup, "_combine_button", null),
		_safe_get(item_popup, "_discard_button", null),
		_safe_get(item_popup, "_cancel_button", null)
	]
	for vanilla_button in vanilla_refs:
		if _is_live_ref(vanilla_button) and vanilla_button == button:
			return false
	var name_l = str(button.name).to_lower()
	if name_l == "combinebutton" or name_l == "discardbutton" or name_l == "cancelbutton":
		return false
	var path_l = ""
	if item_popup != button:
		path_l = str(item_popup.get_path_to(button)).to_lower()
	if path_l.ends_with("combinebutton") or path_l.ends_with("discardbutton") or path_l.ends_with("cancelbutton"):
		return false
	return true


func _on_shop_inventory_custom_button_down(player_index: int, popup_instance_id: int, button: Node) -> void:
	_queue_shop_inventory_custom_button_signal(player_index, popup_instance_id, button, "button_down")


func _on_shop_inventory_custom_button_pressed(player_index: int, popup_instance_id: int, button: Node) -> void:
	_queue_shop_inventory_custom_button_signal(player_index, popup_instance_id, button, "pressed")


func _queue_shop_inventory_custom_button_signal(player_index: int, popup_instance_id: int, button: Node, signal_name: String) -> void:
	if not _is_online_session_active():
		return
	if _shop_inventory_custom_button_apply_guard:
		return
	if _applying_remote_run_page_action:
		return
	if _get_current_menu_screen_fast() != SCREEN_SHOP:
		return
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return
	var item_popup = shop._get_item_popup(player_index) if shop.has_method("_get_item_popup") else null
	if not _is_live_ref(item_popup) or int(item_popup.get_instance_id()) != popup_instance_id:
		return
	if not item_popup.is_inside_tree():
		return
	if not _is_shop_inventory_custom_popup_button(item_popup, button):
		return
	var descriptor = _build_shop_inventory_custom_button_descriptor(item_popup, button, player_index)
	if descriptor.empty():
		descriptor = _get_cached_shop_inventory_custom_button_descriptor(popup_instance_id, button)
	if descriptor.empty():
		return
	_shop_inventory_custom_button_descriptor_cache[_get_shop_inventory_custom_button_cache_key(popup_instance_id, button)] = descriptor
	var dedup_key = str(player_index) + ":" + str(descriptor.get("button_path", "")) + ":" + str(descriptor.get("button_name", "")) + ":" + str(descriptor.get("item_kind", "")) + ":" + str(descriptor.get("item_index", -1)) + ":" + str(descriptor.get("item_key", ""))
	var now = OS.get_ticks_msec()
	# button_down and pressed both fire for normal mouse/controller activation.
	# Keep one outgoing packet per real click, but allow a later separate click.
	if now - int(_shop_inventory_custom_button_recent_press_keys.get(dedup_key, 0)) < 900:
		return
	_shop_inventory_custom_button_recent_press_keys[dedup_key] = now
	_trim_shop_inventory_custom_button_recent_press_keys(now)
	_queue_local_run_page_action({
		"msg_type": "run_page_action_sync",
		"action_type": SHOP_CUSTOM_POPUP_BUTTON_ACTION,
		"screen": "shop",
		"player_index": player_index,
		"button_path": str(descriptor.get("button_path", "")),
		"button_name": str(descriptor.get("button_name", "")),
		"button_text": str(descriptor.get("button_text", "")),
		"button_script_path": str(descriptor.get("button_script_path", "")),
		"item_key": str(descriptor.get("item_key", "")),
		"item_kind": str(descriptor.get("item_kind", "")),
		"item_index": int(descriptor.get("item_index", -1)),
		"item_log": str(descriptor.get("item_log", "")),
		"signal": signal_name
	})


func _get_shop_inventory_custom_button_cache_key(popup_instance_id: int, button: Node) -> String:
	if not _is_live_ref(button):
		return str(popup_instance_id) + ":0"
	return str(popup_instance_id) + ":" + str(button.get_instance_id())


func _get_cached_shop_inventory_custom_button_descriptor(popup_instance_id: int, button: Node) -> Dictionary:
	var key = _get_shop_inventory_custom_button_cache_key(popup_instance_id, button)
	var descriptor = _shop_inventory_custom_button_descriptor_cache.get(key, {})
	if typeof(descriptor) == TYPE_DICTIONARY:
		return descriptor.duplicate(true)
	return {}


func _build_shop_inventory_custom_button_descriptor(item_popup: Node, button: Node, player_index: int) -> Dictionary:
	if not _is_shop_inventory_custom_popup_button(item_popup, button):
		return {}
	var locator = _get_shop_inventory_popup_item_locator(item_popup, player_index)
	return {
		"button_path": str(item_popup.get_path_to(button)),
		"button_name": str(button.name),
		"button_text": str(_safe_get(button, "text", "")),
		"button_script_path": _get_script_path(button),
		"item_key": _get_shop_inventory_popup_item_key(item_popup),
		"item_kind": str(locator.get("kind", "")),
		"item_index": int(locator.get("index", -1)),
		"item_log": _get_item_id_for_log(_safe_get(item_popup, "_item_data", null))
	}


func _get_shop_inventory_popup_item_key(item_popup: Node) -> String:
	if not _is_live_ref(item_popup):
		return ""
	var item_data = _safe_get(item_popup, "_item_data", null)
	if item_data == null:
		return ""
	return _get_shop_item_identity_key(item_data)


func _apply_shop_inventory_custom_popup_button_action(player_index: int, message: Dictionary) -> bool:
	if not _is_online_session_active():
		return false
	if _get_current_menu_screen_fast() != SCREEN_SHOP:
		return false
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop) or player_index < 0:
		return false
	var item_popup = shop._get_item_popup(player_index) if shop.has_method("_get_item_popup") else null
	if not _is_live_ref(item_popup) or not item_popup.is_inside_tree():
		return false

	# Receiver may not have the inventory popup open. Open/rebind it to the same local
	# inventory element first, then press the matching third-party Button. This is the
	# key difference from vanilla combine/recycle packets: generic mod buttons usually
	# read item_popup._item_data instead of accepting an item payload.
	if not _prepare_shop_inventory_custom_popup_for_message(shop, player_index, item_popup, message):
		return false

	var expected_item_key = str(message.get("item_key", ""))
	if expected_item_key != "" and _get_shop_inventory_popup_item_key(item_popup) != expected_item_key:
		return false

	# Some mods add their Button in response to the popup being shown, sometimes deferred.
	# Scan now and, if still missing, retry a few deferred frames instead of silently losing
	# the packet.
	_scan_shop_inventory_custom_popup_buttons_deferred(player_index, int(item_popup.get_instance_id()), true)
	var button = _find_shop_inventory_custom_popup_button_for_message(item_popup, message)
	if not _is_shop_inventory_custom_popup_button(item_popup, button):
		_schedule_shop_inventory_custom_popup_button_deferred_apply(player_index, message)
		return true

	_shop_inventory_custom_button_apply_guard = true
	_applying_remote_run_page_action = true
	# Direct signal replay is intentional. Remote UI can be disabled/hidden because it is
	# not the local player's focused popup; the sender already validated the click.
	# emit_signal("pressed") calls the third-party button's own local handler without
	# going through focus routing or adding new data sync.
	button.emit_signal("pressed")
	_applying_remote_run_page_action = false
	_shop_inventory_custom_button_apply_guard = false
	return true


func _prepare_shop_inventory_custom_popup_for_message(shop: Node, player_index: int, item_popup: Node, message: Dictionary) -> bool:
	if not _is_valid_shop_node(shop) or not _is_live_ref(item_popup):
		return false
	var expected_item_key = str(message.get("item_key", ""))
	if item_popup.visible and (expected_item_key == "" or _get_shop_inventory_popup_item_key(item_popup) == expected_item_key):
		return true
	var element = _find_shop_inventory_element_for_custom_popup_action(shop, player_index, message)
	if not _is_live_ref(element):
		return false
	if item_popup.has_method("display_element"):
		item_popup.display_element(element)
	else:
		var item_data = _safe_get(element, "item", null)
		if item_data == null:
			return false
		if item_popup.has_method("display_item_data"):
			item_popup.display_item_data(item_data, element, true)
	if item_popup.has_method("focus"):
		item_popup.focus()
	var player_container = shop._get_coop_player_container(player_index) if shop.has_method("_get_coop_player_container") else null
	if _is_live_ref(player_container) and player_container.has_method("on_show_focused_inventory_popup"):
		player_container.on_show_focused_inventory_popup()
	return expected_item_key == "" or _get_shop_inventory_popup_item_key(item_popup) == expected_item_key


func _find_shop_inventory_element_for_custom_popup_action(shop: Node, player_index: int, message: Dictionary):
	if not _is_valid_shop_node(shop) or player_index < 0:
		return null
	var expected_item_key = str(message.get("item_key", ""))
	var kind = str(message.get("item_kind", ""))
	var index = int(message.get("item_index", -1))
	if index >= 0 and (kind == "weapon" or kind == "item"):
		var by_index = _get_shop_inventory_elements_for_custom_popup(shop, player_index, kind == "weapon")
		if index < by_index.size():
			var element = by_index[index]
			var item_data = _safe_get(element, "item", null)
			if expected_item_key == "" or _get_shop_item_identity_key(item_data) == expected_item_key:
				return element
	for is_weapon in [true, false]:
		var elements = _get_shop_inventory_elements_for_custom_popup(shop, player_index, is_weapon)
		for element in elements:
			if not _is_live_ref(element):
				continue
			var item_data = _safe_get(element, "item", null)
			if expected_item_key != "" and _get_shop_item_identity_key(item_data) == expected_item_key:
				return element
	return null


func _get_shop_inventory_elements_for_custom_popup(shop: Node, player_index: int, is_weapon: bool) -> Array:
	var result = []
	if not _is_valid_shop_node(shop) or not shop.has_method("_get_gear_container"):
		return result
	var gear = shop._get_gear_container(player_index)
	if not _is_live_ref(gear):
		return result
	var inv_container = _safe_get(gear, "weapons_container", null) if is_weapon else _safe_get(gear, "items_container", null)
	if not _is_live_ref(inv_container):
		return result
	var elements_node = _safe_get(inv_container, "_elements", null)
	if not _is_live_ref(elements_node):
		return result
	for child in elements_node.get_children():
		if _is_live_ref(child) and child is Control:
			result.append(child)
	return result


func _get_shop_inventory_popup_item_locator(item_popup: Node, player_index: int) -> Dictionary:
	var result = {"kind":"", "index":-1}
	if not _is_live_ref(item_popup):
		return result
	var item_data = _safe_get(item_popup, "_item_data", null)
	if item_data == null:
		return result
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return result
	for is_weapon in [true, false]:
		var elements = _get_shop_inventory_elements_for_custom_popup(shop, player_index, is_weapon)
		for i in range(elements.size()):
			var element = elements[i]
			if not _is_live_ref(element):
				continue
			var element_item = _safe_get(element, "item", null)
			if _is_live_ref(element_item) and element_item == item_data:
				result["kind"] = "weapon" if is_weapon else "item"
				result["index"] = i
				return result
			if _get_shop_item_identity_key(element_item) == _get_shop_item_identity_key(item_data):
				result["kind"] = "weapon" if is_weapon else "item"
				result["index"] = i
				return result
	return result


func _schedule_shop_inventory_custom_popup_button_deferred_apply(player_index: int, message: Dictionary) -> void:
	var attempt = int(message.get("_custom_popup_button_attempt", 0))
	if attempt >= 12:
		return
	var key = str(player_index) + ":" + str(message.get("action_id", "")) + ":" + str(message.get("button_path", "")) + ":" + str(message.get("button_name", "")) + ":" + str(message.get("item_key", "")) + ":" + str(attempt)
	if _shop_inventory_custom_button_deferred_apply_keys.has(key):
		return
	_shop_inventory_custom_button_deferred_apply_keys[key] = OS.get_ticks_msec()
	var deferred_message = message.duplicate(true)
	deferred_message["_custom_popup_button_attempt"] = attempt + 1
	call_deferred("_apply_shop_inventory_custom_popup_button_action_deferred", player_index, deferred_message)


func _apply_shop_inventory_custom_popup_button_action_deferred(player_index: int, message: Dictionary) -> void:
	if _shop_inventory_custom_button_apply_guard:
		return
	_apply_shop_inventory_custom_popup_button_action(player_index, message)


func _find_shop_inventory_custom_popup_button_for_message(item_popup: Node, message: Dictionary):
	if not _is_live_ref(item_popup):
		return null
	var button_path = str(message.get("button_path", ""))
	if button_path != "":
		var by_path = item_popup.get_node_or_null(button_path)
		if _is_shop_inventory_custom_popup_button(item_popup, by_path):
			return by_path
	var expected_name = str(message.get("button_name", ""))
	var expected_text = str(message.get("button_text", ""))
	var expected_script = str(message.get("button_script_path", ""))
	var candidates = []
	_collect_shop_inventory_custom_popup_buttons(item_popup, item_popup, candidates)
	var loose_match = null
	for candidate in candidates:
		if not _is_live_ref(candidate):
			continue
		var name_ok = expected_name == "" or str(candidate.name) == expected_name
		var text_ok = expected_text == "" or str(_safe_get(candidate, "text", "")) == expected_text
		var script_ok = expected_script == "" or _get_script_path(candidate) == expected_script
		if name_ok and text_ok and script_ok:
			return candidate
		if loose_match == null and name_ok and text_ok:
			loose_match = candidate
	if _is_live_ref(loose_match):
		return loose_match
	return null


func _find_node_by_instance_id(node: Node, instance_id: int):
	if not _is_live_ref(node) or instance_id <= 0:
		return null
	if int(node.get_instance_id()) == instance_id:
		return node
	for child in node.get_children():
		if child is Node:
			var found = _find_node_by_instance_id(child, instance_id)
			if _is_live_ref(found):
				return found
	return null


func _trim_shop_inventory_custom_button_recent_press_keys(now: int) -> void:
	if _shop_inventory_custom_button_recent_press_keys.size() <= 64:
		return
	var stale = []
	for key in _shop_inventory_custom_button_recent_press_keys.keys():
		if now - int(_shop_inventory_custom_button_recent_press_keys[key]) > 1000:
			stale.append(key)
	for key in stale:
		_shop_inventory_custom_button_recent_press_keys.erase(key)


func _get_shop_item_slot_cap() -> int:
	return int(ItemService.NB_SHOP_ITEMS)


func _clear_client_locked_shop_items_for_player(player_index: int) -> void:
	if _is_game_host() or player_index < 0:
		return
	var locked_items = _safe_get(RunData, "locked_shop_items", [])
	if typeof(locked_items) != TYPE_ARRAY:
		locked_items = []
	var min_size = max(max(4, _get_run_player_count()), player_index + 1)
	while locked_items.size() < min_size:
		locked_items.append([])
	locked_items[player_index] = []
	RunData.set("locked_shop_items", locked_items)


func _replace_client_locked_shop_items_from_host_entries(player_index: int, item_entries: Array) -> void:
	if _is_game_host() or player_index < 0:
		return
	if typeof(item_entries) != TYPE_ARRAY:
		return

	var rebuilt_locked = []
	var seen = {}
	var cap = _get_shop_item_slot_cap()
	for entry in item_entries:
		if rebuilt_locked.size() >= cap:
			break
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if bool(entry.get("slot_empty", false)) or not bool(entry.get("active", true)):
			continue
		if not bool(entry.get("locked", false)):
			continue
		var item_data = _resolve_item_parent_data(entry.get("item", {}))
		if item_data == null:
			continue
		var item_key = _get_shop_item_identity_key(item_data)
		if item_key == "":
			item_key = _build_shop_entry_identity_key(entry)
		if item_key != "":
			if seen.has(item_key):
				continue
			seen[item_key] = true
		rebuilt_locked.append([item_data, int(entry.get("wave_value", RunData.current_wave))])

	var locked_items = _safe_get(RunData, "locked_shop_items", [])
	if typeof(locked_items) != TYPE_ARRAY:
		locked_items = []
	var min_size = max(max(4, _get_run_player_count()), player_index + 1)
	while locked_items.size() < min_size:
		locked_items.append([])
	locked_items[player_index] = rebuilt_locked
	RunData.set("locked_shop_items", locked_items)

func _resolve_shop_state_active_items(item_entries: Array, player_index: int) -> Array:
	var player_shop_items = []
	var resolved_count = 0
	for entry in item_entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if bool(entry.get("slot_empty", false)) or not bool(entry.get("active", true)):
			continue
		var serialized_item = entry.get("item", {})
		var item_data = _resolve_item_parent_data(serialized_item)
		if item_data == null:
			continue
		player_shop_items.append([item_data, int(entry.get("wave_value", RunData.current_wave))])
		resolved_count += 1
	if item_entries.size() > 0 and resolved_count != _count_active_shop_state_entries(item_entries):
		pass
	return player_shop_items


func _count_active_shop_state_entries(item_entries: Array) -> int:
	var count = 0
	for entry in item_entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if bool(entry.get("slot_empty", false)) or not bool(entry.get("active", true)):
			continue
		count += 1
	return count


func _apply_shop_state_entries_to_container(container, item_entries: Array, player_index: int) -> void:
	if not _is_live_ref(container):
		return
	var shop_item_nodes = _safe_get(container, "_shop_items", [])
	if typeof(shop_item_nodes) != TYPE_ARRAY:
		return

	# Do not call ShopItemsContainer.set_shop_items(active_items) here. The host's
	# raw _shop_items array is compacted by vanilla after buy/ban, but the visual
	# ShopItem nodes keep their physical slots. Applying by visual slot prevents
	# Client slots from sliding left after buying slot 2.
	var entry_by_slot = {}
	for entry in item_entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var slot_index = int(entry.get("slot_index", entry.get("index", -1)))
		if slot_index >= 0:
			entry_by_slot[slot_index] = entry

	for slot_index in range(shop_item_nodes.size()):
		var shop_item_node = shop_item_nodes[slot_index]
		if not _is_live_ref(shop_item_node):
			continue
		if not entry_by_slot.has(slot_index):
			_deactivate_shop_item_visual_if_needed(shop_item_node)
			continue
		var entry = entry_by_slot[slot_index]
		if bool(entry.get("slot_empty", false)) or not bool(entry.get("active", true)):
			_deactivate_shop_item_visual_if_needed(shop_item_node)
			_apply_shop_item_entry_button_state(container, entry)
			continue
		var item_data = _resolve_item_parent_data(entry.get("item", {}))
		if item_data == null:
			_deactivate_shop_item_visual_if_needed(shop_item_node)
			continue
		shop_item_node.item_steals = int(_safe_get(container, "item_steals", 0))
		if shop_item_node.has_method("set_shop_item"):
			shop_item_node.set_shop_item(item_data, int(entry.get("wave_value", RunData.current_wave)))
		if bool(entry.get("locked", false)):
			_apply_shop_item_lock_visual_only(shop_item_node, true)
		else:
			_apply_shop_item_lock_visual_only(shop_item_node, false)
		_apply_shop_item_entry_button_state(container, entry)


func _deactivate_shop_item_visual_if_needed(shop_item_node) -> void:
	if not _is_live_ref(shop_item_node):
		return
	if bool(_safe_get(shop_item_node, "active", false)) and shop_item_node.has_method("deactivate"):
		shop_item_node.deactivate()


func _sanitize_host_shop_items_for_client_content(shop: Node) -> bool:
	if not _is_game_host() or not _is_valid_shop_node(shop):
		return false
	if _host_client_item_lookup_by_steam_id.empty() and _host_client_weapon_lookup_by_steam_id.empty():
		return false
	var changed_any = false
	for player_index in range(_get_run_player_count()):
		var raw_items = _get_raw_shop_items_for_player(shop, player_index)
		if typeof(raw_items) != TYPE_ARRAY or raw_items.empty():
			continue
		var changed_player = false
		var new_items = raw_items.duplicate(true)
		for i in range(new_items.size()):
			var pair = new_items[i]
			var item_data = _get_item_data_from_shop_pair(pair)
			if item_data == null or _is_shop_item_available_on_all_clients(item_data):
				continue
			var fallback = _find_common_shop_fallback_for_missing_client_content(item_data)
			if fallback == null:
				continue
			var wave_value = _get_wave_value_from_shop_pair(pair, RunData.current_wave)
			new_items[i] = [fallback, wave_value]
			changed_player = true
			changed_any = true
		if changed_player:
			_set_shop_player_items_array(shop, player_index, new_items)
			var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
			if _is_live_ref(container):
				_apply_common_shop_items_to_host_container(container, new_items)
	if changed_any:
		_last_shop_state_key = ""
	return changed_any


func _apply_common_shop_items_to_host_container(container, player_shop_items: Array) -> void:
	if not _is_live_ref(container):
		return
	if container.has_method("set_shop_items"):
		container.set_shop_items(player_shop_items)
		return
	var nodes = _safe_get(container, "_shop_items", [])
	if typeof(nodes) != TYPE_ARRAY:
		return
	for i in range(nodes.size()):
		var node = nodes[i]
		if not _is_live_ref(node):
			continue
		if i >= player_shop_items.size():
			_deactivate_shop_item_visual_if_needed(node)
			continue
		var pair = player_shop_items[i]
		var item_data = _get_item_data_from_shop_pair(pair)
		if item_data == null:
			_deactivate_shop_item_visual_if_needed(node)
			continue
		if node.has_method("set_shop_item"):
			node.set_shop_item(item_data, _get_wave_value_from_shop_pair(pair, RunData.current_wave))


func _is_shop_item_available_on_all_clients(item_data) -> bool:
	if item_data == null:
		return true
	var active_ids = _get_active_remote_client_ids_for_dlc_gate()
	if active_ids.empty():
		return true
	var lookup_by_steam_id = _host_client_weapon_lookup_by_steam_id if item_data is WeaponData else _host_client_item_lookup_by_steam_id
	if typeof(lookup_by_steam_id) != TYPE_DICTIONARY or lookup_by_steam_id.empty():
		# Old/early clients did not report shop content. Fail open rather than replacing
		# every Host shop item.
		return true
	for steam_id_value in active_ids:
		var steam_id = str(steam_id_value)
		if not lookup_by_steam_id.has(steam_id):
			# Unknown capability for this peer: fail open for compatibility.
			continue
		var lookup = lookup_by_steam_id.get(steam_id, {})
		if typeof(lookup) != TYPE_DICTIONARY or lookup.empty():
			continue
		if not _data_object_matches_lookup(item_data, lookup):
			return false
	return true


func _find_common_shop_fallback_for_missing_client_content(item_data):
	if item_data == null:
		return null
	var data_type = "weapon" if item_data is WeaponData else "item"
	var desired_tier = int(_safe_get(item_data, "tier", -1))
	var cache_key = data_type + ":" + str(desired_tier)
	if _host_common_shop_fallback_cache.has(cache_key):
		var cached = _host_common_shop_fallback_cache[cache_key]
		if cached != null:
			return cached
	var pool = ItemService.weapons if data_type == "weapon" else ItemService.items
	var fallback = _find_common_shop_fallback_in_pool(pool, desired_tier, true)
	if fallback == null:
		fallback = _find_common_shop_fallback_in_pool(pool, desired_tier, false)
	if fallback != null:
		_host_common_shop_fallback_cache[cache_key] = fallback
	return fallback


func _find_common_shop_fallback_in_pool(pool, desired_tier: int, require_same_tier: bool):
	if typeof(pool) != TYPE_ARRAY:
		return null
	for candidate in pool:
		if not _is_live_ref(candidate):
			continue
		if require_same_tier and desired_tier >= 0 and int(_safe_get(candidate, "tier", -1)) != desired_tier:
			continue
		if _is_shop_item_available_on_all_clients(candidate):
			return candidate
	return null


func _get_cached_host_shop_run_data_key(player_index: int) -> String:
	if player_index < 0:
		return ""
	return str(_host_shop_run_data_key_by_player.get(player_index, ""))


func _build_all_shop_player_states(force_run_data_full: bool = false) -> Array:
	var states = []
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return states
	_sanitize_host_shop_items_for_client_content(shop)
	for player_index in range(_get_run_player_count()):
		var state = _build_shop_player_state(player_index, shop, force_run_data_full)
		if typeof(state) == TYPE_DICTIONARY and not state.empty():
			states.append(state)
	return states


func _build_all_shop_player_states_for_menu_scene() -> Array:
	# menu_scene_state already carries authoritative RunData in run_config.
	# Build only shop slots/scalars here; do not serialize PlayerRunData again just to strip it.
	var states = []
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return states
	_sanitize_host_shop_items_for_client_content(shop)
	for player_index in range(_get_run_player_count()):
		var state = _build_shop_player_state(player_index, shop, false, false)
		if typeof(state) == TYPE_DICTIONARY and not state.empty():
			state["run_data_full"] = false
			state["run_data"] = {}
			state["run_data_source"] = "run_config"
			states.append(state)
	return states


func _build_shop_player_state(player_index: int, shop: Node = null, force_run_data_full: bool = false, include_run_data_sync: bool = true) -> Dictionary:
	if shop == null:
		shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return {}
	if player_index < 0 or player_index >= RunData.get_player_count():
		return {}

	var shop_items = []
	var raw_items = _get_raw_shop_items_for_player(shop, player_index)
	var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
	var visual_items = _safe_get(container, "_shop_items", []) if _is_live_ref(container) else []

	if typeof(visual_items) == TYPE_ARRAY and not visual_items.empty():
		for slot_index in range(visual_items.size()):
			var shop_item_node = visual_items[slot_index]
			if not _is_live_ref(shop_item_node) or not bool(_safe_get(shop_item_node, "active", false)) or _safe_get(shop_item_node, "item_data", null) == null:
				shop_items.append(_build_empty_shop_slot_entry(slot_index))
				continue
			shop_items.append(_build_visual_shop_item_entry(container, shop_item_node, slot_index))
	else:
		# Fallback for non-visual states. This path can still compact, but normal CoopShop
		# has four ShopItem nodes and uses the visual-slot path above.
		for raw_index in range(raw_items.size()):
			var pair = raw_items[raw_index]
			var item_data = _get_item_data_from_shop_pair(pair)
			if item_data == null:
				continue
			shop_items.append({
				"index": raw_index,
				"slot_index": raw_index,
				"item": _serialize_item_parent_data(item_data),
				"wave_value": _get_wave_value_from_shop_pair(pair, RunData.current_wave),
				"locked": false,
				"active": true,
				"disabled": false,
				"buy_disabled": false,
				"steal_disabled": false,
				"lock_disabled": false,
				"ban_disabled": false,
				"slot_empty": false
			})

	var run_data_sync = {}
	if include_run_data_sync:
		run_data_sync = _build_shop_run_data_sync_state(player_index, force_run_data_full, _resolve_shop_held_items_sync_mode(SHOP_HELD_ITEMS_SYNC_HASH_ONLY))
	var run_data_state = run_data_sync.get("run_data", {})
	var run_data_key = str(run_data_sync.get("run_data_key", _get_cached_host_shop_run_data_key(player_index)))

	return {
		"mode": "shop",
		"player_index": player_index,
		"current_wave": int(RunData.current_wave),
		"gold": int(RunData.get_player_gold(player_index)),
		"current_health": _get_player_current_health_value(player_index),
		"shop_items": shop_items,
		"shop_slot_count": shop_items.size(),
		"reroll_price": int(_get_node_array_value(shop, "_reroll_price", player_index, 0)),
		"reroll_count": int(_get_node_array_value(shop, "_reroll_count", player_index, 0)),
		"paid_reroll_count": int(_get_node_array_value(shop, "_paid_reroll_count", player_index, 0)),
		"initial_free_rerolls": int(_get_node_array_value(shop, "_initial_free_rerolls", player_index, 0)),
		"free_rerolls": int(_get_node_array_value(shop, "_free_rerolls", player_index, 0)),
		"item_steals": int(_get_node_array_value(shop, "_item_steals", player_index, 0)),
		"pressed_go": bool(_get_node_array_value(shop, "_player_pressed_go_button", player_index, false)),
		"run_data_key": run_data_key,
		"run_data_full": bool(run_data_sync.get("run_data_full", false)),
		"run_data": run_data_state
	}


func _compact_player_run_data_for_shop_sync(player_index: int, run_data_state, held_items_mode: String = SHOP_HELD_ITEMS_SYNC_COMPACT, force_full_held_items: bool = false) -> Dictionary:
	# Keep Host-authoritative PlayerRunData runtime fields. Level-up choices, Ghost max HP,
	# Baby weapon slots, set bonuses, unique effects and weapon-slot upgrades all live in
	# PlayerRunData.effects / active_set_effects, not in the id-only inventory list.
	# Owned normal items are still compacted as id+count; weapons stay fully serialized
	# because their runtime stats/effects can be changed by shop/player choices.
	if typeof(run_data_state) != TYPE_DICTIONARY or run_data_state.empty():
		return {}
	held_items_mode = _resolve_shop_held_items_sync_mode(held_items_mode, force_full_held_items)
	# In incremental-only mode we immediately replace the large items array with [], so
	# avoid deep-copying hundreds of serialized held items just to discard them.
	var compact_state = run_data_state.duplicate(held_items_mode != SHOP_HELD_ITEMS_SYNC_INCREMENTAL_ONLY)
	compact_state["online_compact_run_data"] = true
	compact_state["compact_run_data_version"] = SHOP_RUN_DATA_ID_ONLY_VERSION + 1
	compact_state["player_index"] = player_index
	compact_state["weapons"] = _build_light_weapon_inventory_entries(run_data_state.get("weapons", []))

	var serialized_items = run_data_state.get("items", [])
	compact_state["held_items_sync_mode"] = held_items_mode
	if held_items_mode == SHOP_HELD_ITEMS_SYNC_INCREMENTAL_ONLY:
		# Endless wave 21+ can have hundreds of held items. Do not build a full compact
		# list and do not calculate the held-items hash. Clients preserve their local
		# item list and receive only action deltas (buy/steal/mirror/etc.) plus runtime
		# fields such as weapons/effects/active sets.
		compact_state["items"] = []
		compact_state["items_compact"] = false
		compact_state["items_hash_only"] = false
		compact_state["items_incremental_only"] = true
		compact_state["held_items_hash"] = "0"
		compact_state["held_items_hash_scope"] = "incremental_only"
		compact_state["held_items_hash_version"] = 3
		compact_state["held_items_count"] = -1
		compact_state["tracked_item_effects"] = _build_shop_tracked_item_effects_snapshot(player_index)
		return compact_state

	var compact_items_result = _build_compact_owned_items_for_shop_sync(player_index, serialized_items)
	var held_items_hash = _build_serialized_held_items_hash(serialized_items)
	compact_state["held_items_hash"] = held_items_hash
	compact_state["held_items_hash_scope"] = "whole_compact_item_list"
	compact_state["held_items_hash_version"] = 2
	compact_state["held_items_count"] = _count_serialized_inventory_entries(serialized_items)
	if held_items_mode == SHOP_HELD_ITEMS_SYNC_HASH_ONLY:
		# The client normally already has the same owned-item list from the previous
		# authoritative shop/battle transition. Carry only a deterministic hash here;
		# weapons/effects/active_set_effects remain fully serialized in this run_data.
		compact_state["items"] = []
		compact_state["items_compact"] = false
		compact_state["items_hash_only"] = true
		compact_state["items_incremental_only"] = false
	else:
		compact_state["items"] = compact_items_result.get("items", [])
		compact_state["items_compact"] = true
		compact_state["items_hash_only"] = false
		compact_state["items_incremental_only"] = false
	compact_state["tracked_item_effects"] = _build_shop_tracked_item_effects_snapshot(player_index, compact_items_result.get("item_hashes", {}))
	return compact_state


func _build_light_weapon_inventory_entries(serialized_entries) -> Array:
	var result = []
	if typeof(serialized_entries) != TYPE_ARRAY:
		return result
	for serialized in serialized_entries:
		if typeof(serialized) == TYPE_DICTIONARY:
			# Keep full WeaponData.serialize() entries. They preserve selected scaling
			# stats/effects/tracking fields while staying small because weapon count is capped.
			result.append(serialized.duplicate(true))
			continue
		var entry = _serialized_inventory_entry_to_id_only(serialized, "weapon")
		if not entry.empty():
			result.append(entry)
	return result


func _build_id_only_player_run_data_for_join_sync(player_index: int, run_data_state) -> Dictionary:
	if typeof(run_data_state) != TYPE_DICTIONARY or run_data_state.empty():
		return {}
	var character_id = str(run_data_state.get("current_character", ""))
	return {
		"online_light_run_data": true,
		"light_run_data_version": SHOP_RUN_DATA_ID_ONLY_VERSION,
		"player_index": player_index,
		"current_character": character_id,
		"current_health": int(run_data_state.get("current_health", PlayerRunData.DEFAULT_MAX_HP)),
		"current_level": int(run_data_state.get("current_level", 0)),
		"current_xp": float(run_data_state.get("current_xp", 0.0)),
		"gold": int(run_data_state.get("gold", 0)),
		"selected_weapon": str(run_data_state.get("selected_weapon", "")),
		"selected_item": str(run_data_state.get("selected_item", "")),
		# Legacy light packets still preserve full weapon entries. Rebuilding weapons by id
		# resets runtime-selected weapon stats/effects.
		"weapons": _build_light_weapon_inventory_entries(run_data_state.get("weapons", [])),
		"items": _build_id_only_inventory_entries(run_data_state.get("items", []), "item", true),
		"banned_items": _build_id_only_banned_items(run_data_state.get("banned_items", [])),
		"remaining_ban_token": int(run_data_state.get("remaining_ban_token", 0)),
		"uses_ban": bool(run_data_state.get("uses_ban", false)),
		"chal_recycling_current": int(run_data_state.get("chal_recycling_current", 0)),
		"consumables_picked_up_this_run": int(run_data_state.get("consumables_picked_up_this_run", 0)),
		"curse_locked_shop_items_pity": int(run_data_state.get("curse_locked_shop_items_pity", 0))
	}


func _build_id_only_inventory_entries(serialized_entries, entry_type: String, compact_counts: bool) -> Array:
	var result = []
	var index_by_key = {}
	if typeof(serialized_entries) != TYPE_ARRAY:
		return result
	for serialized in serialized_entries:
		var entry = _serialized_inventory_entry_to_id_only(serialized, entry_type)
		if entry.empty():
			continue
		if compact_counts:
			var key = str(entry.get("my_id", "")) + ":" + str(entry.get("my_id_hash", 0))
			if index_by_key.has(key):
				var idx = int(index_by_key[key])
				var existing = result[idx]
				existing["count"] = int(existing.get("count", 1)) + int(entry.get("count", 1))
				result[idx] = existing
				continue
			index_by_key[key] = result.size()
		result.append(entry)
	return result


func _serialized_inventory_entry_to_id_only(serialized, entry_type: String) -> Dictionary:
	var item_id = ""
	var item_hash = 0
	var weapon_id = ""
	var weapon_hash = 0
	if typeof(serialized) == TYPE_STRING:
		item_id = str(serialized)
	elif typeof(serialized) == TYPE_DICTIONARY:
		item_id = str(serialized.get("my_id", serialized.get("id", "")))
		item_hash = int(serialized.get("my_id_hash", serialized.get("id_hash", 0)))
		weapon_id = str(serialized.get("weapon_id", ""))
		weapon_hash = int(serialized.get("weapon_id_hash", 0))
	else:
		return {}
	if item_id == "" and item_hash == 0:
		return {}
	if item_hash == 0 and item_id != "":
		item_hash = int(Keys.generate_hash(item_id))
	if entry_type == "weapon" and weapon_id == "":
		weapon_id = item_id
	if entry_type == "weapon" and weapon_hash == 0 and weapon_id != "":
		weapon_hash = int(Keys.generate_hash(weapon_id))
	var entry = {
		"id_only": true,
		"type": entry_type,
		"my_id": item_id,
		"my_id_hash": item_hash,
		"count": 1
	}
	if entry_type == "weapon":
		entry["weapon_id"] = weapon_id
		entry["weapon_id_hash"] = weapon_hash
	return entry


func _build_id_only_banned_items(value) -> Array:
	var result = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for raw in value:
		if typeof(raw) == TYPE_STRING:
			result.append(str(raw))
		elif typeof(raw) == TYPE_INT or typeof(raw) == TYPE_REAL:
			result.append(int(raw))
		elif typeof(raw) == TYPE_DICTIONARY:
			var item_id = str(raw.get("my_id", raw.get("id", "")))
			if item_id != "":
				result.append(item_id)
	return result


func _count_serialized_inventory_entries(serialized_items) -> int:
	if typeof(serialized_items) != TYPE_ARRAY:
		return 0
	return serialized_items.size()


func _build_serialized_held_items_hash(serialized_items) -> String:
	# One hash for the whole owned-item list, not one hash per item. The payload is
	# the same compact inventory representation we would resend on mismatch: normal
	# uncursed items collapse to id+count, while cursed/runtime-mutated items keep a
	# stable full-state string. Weapons are intentionally excluded.
	if typeof(serialized_items) != TYPE_ARRAY:
		return "0"
	var payload = _build_serialized_held_items_hash_payload(serialized_items)
	if payload == "":
		return "0"
	return str(Keys.generate_hash(payload))


func _build_serialized_held_items_hash_payload(serialized_items: Array) -> String:
	var compact_counts = {}
	var full_entries = []
	var total_count = 0
	for item in serialized_items:
		total_count += 1
		if typeof(item) == TYPE_DICTIONARY:
			var item_id = str(item.get("my_id", item.get("id", "")))
			if item_id != "" and _is_owned_item_state_compactable_for_shop_sync(item):
				var compact_key = _build_stable_hash_string({
					"compact_item": true,
					"my_id": item_id,
					"value": int(item.get("value", 0)),
					"tier": int(item.get("tier", -1)),
					"resource_path": str(item.get("resource_path", ""))
				})
				compact_counts[compact_key] = int(compact_counts.get(compact_key, 0)) + 1
				continue
			full_entries.append(_build_stable_hash_string(item))
		else:
			full_entries.append(_build_stable_hash_string(item))
	var parts = []
	var compact_keys = compact_counts.keys()
	compact_keys.sort()
	for key in compact_keys:
		parts.append("compact:" + str(compact_counts[key]) + "x" + str(key))
	full_entries.sort()
	for entry in full_entries:
		parts.append("full:" + str(entry))
	if parts.empty():
		return ""
	return "held_items_list_v2|count=" + str(total_count) + "|" + "||".join(parts)


func _build_stable_hash_string(value) -> String:
	var value_type = typeof(value)
	if value_type == TYPE_DICTIONARY:
		var parts = []
		for raw_key in value.keys():
			parts.append(str(typeof(raw_key)) + ":" + var2str(raw_key) + "=" + _build_stable_hash_string(value[raw_key]))
		parts.sort()
		return "d{" + "|".join(parts) + "}"
	if value_type == TYPE_ARRAY:
		var parts = []
		for entry in value:
			parts.append(_build_stable_hash_string(entry))
		return "a[" + "|".join(parts) + "]"
	return str(value_type) + ":" + var2str(value)


func _build_local_held_items_hash(player_index: int) -> String:
	if player_index < 0 or player_index >= RunData.players_data.size():
		return "0"
	var player_data = RunData.players_data[player_index]
	if player_data == null or not player_data.has_method("serialize"):
		return "0"
	var serialized = player_data.serialize()
	if typeof(serialized) != TYPE_DICTIONARY:
		return "0"
	return _build_serialized_held_items_hash(serialized.get("items", []))


func _get_local_serialized_held_items(player_index: int) -> Array:
	if player_index < 0 or player_index >= RunData.players_data.size():
		return []
	var player_data = RunData.players_data[player_index]
	if player_data == null or not player_data.has_method("serialize"):
		return []
	var serialized = player_data.serialize()
	if typeof(serialized) != TYPE_DICTIONARY:
		return []
	var items = serialized.get("items", [])
	if typeof(items) == TYPE_ARRAY:
		return items.duplicate(true)
	return []


func _prepare_hash_only_run_data_for_apply(player_index: int, run_data_state: Dictionary) -> Dictionary:
	if typeof(run_data_state) != TYPE_DICTIONARY or not bool(run_data_state.get("items_hash_only", false)):
		return run_data_state
	var prepared = run_data_state.duplicate(true)
	var host_hash = str(prepared.get("held_items_hash", "0"))
	var local_items = _get_local_serialized_held_items(player_index)
	var local_hash = _build_serialized_held_items_hash(local_items)
	prepared["items"] = local_items
	prepared["items_compact"] = false
	prepared["items_hash_only_applied_from_local"] = true
	prepared["items_hash_matched_local"] = host_hash == local_hash
	if host_hash != local_hash:
		_queue_shop_items_resync_request(player_index, host_hash, local_hash, "hash_mismatch")
	return prepared


func _prepare_incremental_only_run_data_for_apply(player_index: int, run_data_state: Dictionary) -> Dictionary:
	if typeof(run_data_state) != TYPE_DICTIONARY or not bool(run_data_state.get("items_incremental_only", false)):
		return run_data_state
	var prepared = run_data_state.duplicate(true)
	prepared["items"] = _get_local_serialized_held_items(player_index)
	prepared["items_compact"] = false
	prepared["items_hash_only"] = false
	prepared["items_incremental_only_applied_from_local"] = true
	return prepared


func _queue_shop_items_resync_request(player_index: int, host_hash: String, local_hash: String, reason: String = "") -> void:
	if _is_game_host() or player_index < 0:
		return
	if _should_use_endless_incremental_items_only_shop_sync():
		return
	var now = OS.get_ticks_msec()
	var key = str(player_index) + ":" + host_hash
	if str(_pending_shop_items_resync_key_by_player.get(player_index, "")) == key and now < int(_pending_shop_items_resync_until_by_player.get(player_index, 0)):
		return
	_pending_shop_items_resync_key_by_player[player_index] = key
	_pending_shop_items_resync_until_by_player[player_index] = now + SHOP_ITEMS_RESYNC_REQUEST_COOLDOWN_MSEC
	_queued_local_run_page_action_messages.append({
		"msg_type": "run_page_action_sync",
		"action_type": "shop_items_resync_request",
		"screen": "shop",
		"player_index": player_index,
		"requested_player_index": player_index,
		"host_held_items_hash": host_hash,
		"local_held_items_hash": local_hash,
		"reason": reason
	})


func _build_compact_owned_items_for_shop_sync(player_index: int, serialized_items: Array) -> Dictionary:
	var compact_items = []
	var compact_index_by_key = {}
	var item_hashes = {}
	for serialized in serialized_items:
		if typeof(serialized) != TYPE_DICTIONARY:
			continue
		var item_id = str(serialized.get("my_id", ""))
		if item_id == "":
			compact_items.append(serialized.duplicate(true))
			continue
		var item_hash = int(serialized.get("my_id_hash", 0))
		if item_hash == 0:
			item_hash = int(Keys.generate_hash(item_id))
		item_hashes[item_hash] = true
		if not _is_owned_item_state_compactable_for_shop_sync(serialized):
			compact_items.append(serialized.duplicate(true))
			continue
		var compact_key = item_id + ":" + str(item_hash)
		if compact_index_by_key.has(compact_key):
			var existing_index = int(compact_index_by_key[compact_key])
			var existing = compact_items[existing_index]
			existing["count"] = int(existing.get("count", 1)) + 1
			compact_items[existing_index] = existing
			continue
		var compact_entry = {
			"compact_item": true,
			"my_id": item_id,
			"my_id_hash": item_hash,
			"count": 1,
			"value": int(serialized.get("value", 0)),
			"tier": int(serialized.get("tier", -1)),
			"is_cursed": false,
			"curse_factor": 0.0,
			"resource_path": str(serialized.get("resource_path", ""))
		}
		compact_index_by_key[compact_key] = compact_items.size()
		compact_items.append(compact_entry)
	return {"items": compact_items, "item_hashes": item_hashes}


func _is_owned_item_state_compactable_for_shop_sync(serialized: Dictionary) -> bool:
	if bool(serialized.get("is_cursed", false)):
		return false
	if serialized.has("serialized_data"):
		return false
	# Anything with a runtime-mutated effect list must stay full. Normal uncursed items
	# can be reconstructed from ItemService by my_id on the receiver.
	return true


func _expand_compact_player_run_data_from_shop_sync(player_index: int, run_data_state) -> Dictionary:
	if typeof(run_data_state) != TYPE_DICTIONARY or run_data_state.empty():
		return {}
	if bool(run_data_state.get("online_light_run_data", false)):
		return _expand_id_only_player_run_data_for_placeholders(player_index, run_data_state)
	if bool(run_data_state.get("items_incremental_only", false)):
		run_data_state = _prepare_incremental_only_run_data_for_apply(player_index, run_data_state)
	elif bool(run_data_state.get("items_hash_only", false)):
		run_data_state = _prepare_hash_only_run_data_for_apply(player_index, run_data_state)
	if not bool(run_data_state.get("items_compact", false)):
		return run_data_state
	var expanded_state = run_data_state.duplicate(true)
	expanded_state["items"] = _expand_compact_owned_items_for_shop_sync(expanded_state.get("items", []))
	return expanded_state


func _expand_id_only_player_run_data_for_placeholders(player_index: int, run_data_state: Dictionary) -> Dictionary:
	var expanded_state = run_data_state.duplicate(true)
	expanded_state["items"] = _expand_id_only_inventory_entries(expanded_state.get("items", []))
	expanded_state["weapons"] = _expand_id_only_inventory_entries(expanded_state.get("weapons", []))
	return expanded_state


func _expand_id_only_inventory_entries(entries) -> Array:
	var expanded = []
	if typeof(entries) != TYPE_ARRAY:
		return expanded
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var count = max(1, int(entry.get("count", 1)))
		var copy = entry.duplicate(true)
		copy.erase("count")
		for _i in range(count):
			expanded.append(copy.duplicate(true))
	return expanded


func _expand_compact_owned_items_for_shop_sync(serialized_items) -> Array:
	var expanded = []
	if typeof(serialized_items) != TYPE_ARRAY:
		return expanded
	for serialized in serialized_items:
		if typeof(serialized) != TYPE_DICTIONARY:
			continue
		if not bool(serialized.get("compact_item", false)):
			expanded.append(serialized.duplicate(true))
			continue
		var count = max(1, int(serialized.get("count", 1)))
		var full_state = _build_full_item_state_from_compact_shop_entry(serialized)
		for _i in range(count):
			expanded.append(full_state.duplicate(true))
	return expanded


func _build_full_item_state_from_compact_shop_entry(entry: Dictionary) -> Dictionary:
	var item_id = str(entry.get("my_id", ""))
	var full_state = {}
	var item_data = null
	if item_id != "":
		item_data = ItemService.get_element_safe(ItemService.items, item_id)
		if item_data == null:
			item_data = ItemService.get_element_safe(ItemService.characters, item_id)
	if item_data != null and item_data.has_method("serialize"):
		full_state = item_data.serialize()
	else:
		full_state = entry.duplicate(true)
		full_state.erase("compact_item")
		full_state.erase("count")
	if item_id != "":
		full_state["my_id"] = item_id
	if entry.has("value") and int(entry.get("value", 0)) != 0:
		full_state["value"] = str(int(entry.get("value", 0)))
	if entry.has("tier") and int(entry.get("tier", -1)) >= 0:
		full_state["tier"] = str(int(entry.get("tier", -1)))
	full_state["is_cursed"] = false
	full_state["curse_factor"] = 0.0
	return full_state


func _build_shop_tracked_item_effects_snapshot(player_index: int, owned_hashes: Dictionary = {}) -> Dictionary:
	var result = {}
	if player_index < 0 or player_index >= RunData.tracked_item_effects.size():
		return result
	var source = RunData.tracked_item_effects[player_index]
	if typeof(source) != TYPE_DICTIONARY:
		return result
	for raw_key in source.keys():
		var key_hash = int(raw_key)
		if not owned_hashes.empty() and not owned_hashes.has(key_hash):
			continue
		result[str(key_hash)] = _duplicate_shop_sync_variant(source[raw_key])
	return result


func _build_shop_tracked_item_effects_key(player_index: int) -> String:
	var snapshot = _build_shop_tracked_item_effects_snapshot(player_index)
	if snapshot.empty():
		return ""
	var parts = []
	var keys = snapshot.keys()
	keys.sort()
	for key in keys:
		parts.append(str(key) + ":" + to_json(snapshot[key]))
	return "|".join(parts)


func _apply_shop_tracked_item_effects_from_run_data(player_index: int, run_data_state: Dictionary) -> void:
	if player_index < 0 or typeof(run_data_state) != TYPE_DICTIONARY:
		return
	var tracked = run_data_state.get("tracked_item_effects", {})
	if typeof(tracked) != TYPE_DICTIONARY or tracked.empty():
		return
	while RunData.tracked_item_effects.size() <= player_index:
		RunData.tracked_item_effects.append({})
	if typeof(RunData.tracked_item_effects[player_index]) != TYPE_DICTIONARY:
		RunData.tracked_item_effects[player_index] = {}
	for raw_key in tracked.keys():
		var key_hash = int(raw_key)
		RunData.tracked_item_effects[player_index][key_hash] = _duplicate_shop_sync_variant(tracked[raw_key])


func _duplicate_shop_sync_variant(value):
	var value_type = typeof(value)
	if value_type == TYPE_DICTIONARY or value_type == TYPE_ARRAY:
		return value.duplicate(true)
	return value


func _build_shop_run_data_sync_state(player_index: int, force_full_snapshot: bool = false, held_items_mode: String = SHOP_HELD_ITEMS_SYNC_HASH_ONLY, force_full_held_items: bool = false) -> Dictionary:
	held_items_mode = _resolve_shop_held_items_sync_mode(held_items_mode, force_full_held_items)
	var run_data_key = ""
	var run_data_state = {}
	var include_full = true

	# Only the Host broadcasts shop_state. After the first shop snapshot, keep a cached
	# inventory key and refresh it only when a cheap display stamp changes or a known
	# inventory mutation marks the player dirty. This avoids scanning/serializing hundreds
	# of owned items every observe tick.
	var force_full = false
	if _is_game_host():
		var stamp = _build_shop_run_data_dirty_stamp(player_index)
		var cached_key = str(_host_shop_run_data_key_by_player.get(player_index, ""))
		var dirty = bool(_host_shop_run_data_dirty_by_player.get(player_index, false))
		force_full = dirty or force_full_snapshot
		if cached_key != "" and not dirty and str(_host_shop_run_data_stamp_by_player.get(player_index, "")) == stamp:
			run_data_key = cached_key
		else:
			run_data_key = _build_shop_run_data_sync_key(player_index)
			if cached_key != run_data_key:
				_host_shop_run_data_cache_by_player.erase(player_index)
			_host_shop_run_data_cache_mode_by_player.erase(player_index)
			_host_shop_run_data_key_by_player[player_index] = run_data_key
			_host_shop_run_data_stamp_by_player[player_index] = stamp
			_host_shop_run_data_dirty_by_player.erase(player_index)
		include_full = force_full or str(_host_shop_run_data_sent_key_by_player.get(player_index, "")) != run_data_key
	else:
		# Client-side prediction keys still need a local full state snapshot.
		run_data_key = _build_shop_run_data_sync_key(player_index)
		include_full = true

	if include_full and player_index >= 0 and player_index < RunData.players_data.size() and RunData.players_data[player_index] != null and RunData.players_data[player_index].has_method("serialize"):
		if _is_game_host() and not force_full and _host_shop_run_data_cache_by_player.has(player_index) and typeof(_host_shop_run_data_cache_by_player.get(player_index, {})) == TYPE_DICTIONARY and str(_host_shop_run_data_cache_mode_by_player.get(player_index, "")) == held_items_mode and str(_host_shop_run_data_key_by_player.get(player_index, "")) == run_data_key and not bool(_host_shop_run_data_dirty_by_player.get(player_index, false)):
			run_data_state = _host_shop_run_data_cache_by_player[player_index].duplicate(true)
		else:
			var serialized_for_shop = _serialize_player_run_data_for_shop_sync(player_index, held_items_mode)
			run_data_state = _compact_player_run_data_for_shop_sync(player_index, serialized_for_shop, held_items_mode, force_full_held_items)
			if _is_game_host():
				_host_shop_run_data_key_by_player[player_index] = run_data_key
				_host_shop_run_data_cache_by_player[player_index] = run_data_state.duplicate(true)
				_host_shop_run_data_cache_mode_by_player[player_index] = held_items_mode
		if _is_game_host():
			_host_shop_run_data_sent_key_by_player[player_index] = run_data_key

	return {
		"run_data_key": run_data_key,
		"run_data_full": include_full and typeof(run_data_state) == TYPE_DICTIONARY and not run_data_state.empty(),
		"run_data": run_data_state
	}


func _mark_host_shop_run_data_dirty(player_index: int = -1) -> void:
	if player_index >= 0:
		_host_shop_run_data_dirty_by_player[player_index] = true
		return
	for idx in range(_get_run_player_count()):
		_host_shop_run_data_dirty_by_player[idx] = true


func _serialize_player_run_data_for_shop_sync(player_index: int, held_items_mode: String) -> Dictionary:
	if player_index < 0 or player_index >= RunData.players_data.size():
		return {}
	var player_data = RunData.players_data[player_index]
	if player_data == null or not player_data.has_method("serialize"):
		return {}
	if held_items_mode == SHOP_HELD_ITEMS_SYNC_INCREMENTAL_ONLY and player_data.has_method("duplicate"):
		# Avoid serializing hundreds of held items on late endless shop entry. The client keeps
		# its local held-item list and receives only explicit inventory deltas after this point.
		var snapshot = player_data.duplicate()
		snapshot.items = []
		return snapshot.serialize()
	return player_data.serialize()


func _build_shop_run_data_dirty_stamp(player_index: int) -> String:
	if player_index < 0 or player_index >= RunData.players_data.size() or RunData.players_data[player_index] == null:
		return ""
	var player_data = RunData.players_data[player_index]
	if _should_use_endless_incremental_items_only_shop_sync():
		return "late_incremental:w=" + _build_id_only_live_inventory_key(_safe_get(player_data, "weapons", []), false) + ";scalar=" + _build_player_scalar_runtime_key_for_incremental_items(player_index)
	return "w=" + _build_id_only_live_inventory_key(_safe_get(player_data, "weapons", []), false) + ";i=" + _build_id_only_live_inventory_key(_safe_get(player_data, "items", []), true) + ";fx=" + _build_player_effects_runtime_key(player_index)


func _build_shop_run_data_sync_key(player_index: int) -> String:
	if player_index < 0 or player_index >= RunData.get_player_count():
		return ""
	if _should_use_endless_incremental_items_only_shop_sync():
		return to_json({
			"compact_run_data": true,
			"items_incremental_only": true,
			"weapons": _build_id_only_live_inventory_key(RunData.get_player_weapons(player_index), false),
			"scalar": _build_player_scalar_runtime_key_for_incremental_items(player_index)
		})
	return to_json({
		"compact_run_data": true,
		"weapons": _build_id_only_live_inventory_key(RunData.get_player_weapons(player_index), false),
		"items": _build_id_only_live_inventory_key(RunData.get_player_items(player_index), true),
		"effects": _build_player_effects_runtime_key(player_index)
	})


func _build_player_scalar_runtime_key_for_incremental_items(player_index: int) -> String:
	if player_index < 0 or player_index >= RunData.players_data.size():
		return ""
	var player_data = RunData.players_data[player_index]
	if player_data == null:
		return ""
	return to_json({
		"current_wave": int(RunData.current_wave),
		"gold": int(RunData.get_player_gold(player_index)),
		"current_health": _get_player_current_health_value(player_index),
		"current_level": int(_safe_get(player_data, "current_level", 0)),
		"current_xp": int(_safe_get(player_data, "current_xp", 0)),
		"dirty": bool(_host_shop_run_data_dirty_by_player.get(player_index, false))
	})


func _build_id_only_live_inventory_key(items, compact_counts: bool) -> String:
	if typeof(items) != TYPE_ARRAY:
		return ""
	if compact_counts:
		var counts = {}
		for item in items:
			var key = _build_live_inventory_id_key(item)
			if key == "":
				continue
			counts[key] = int(counts.get(key, 0)) + 1
		var parts = []
		var keys = counts.keys()
		keys.sort()
		for key in keys:
			parts.append(str(key) + "x" + str(counts[key]))
		return ",".join(parts)
	var result = []
	for item in items:
		var key = _build_live_inventory_id_key(item)
		if key != "":
			result.append(key)
	return ",".join(result)


func _build_live_inventory_id_key(item) -> String:
	if item == null:
		return ""
	var item_id = str(_safe_get(item, "my_id", ""))
	var item_hash = int(_safe_get(item, "my_id_hash", 0))
	var weapon_hash = int(_safe_get(item, "weapon_id_hash", 0))
	var key = item_id + ":" + str(item_hash) + ":" + str(weapon_hash)
	if item is WeaponData:
		key += ":" + _build_live_weapon_runtime_key(item)
	return key


func _build_live_weapon_runtime_key(weapon) -> String:
	if weapon == null:
		return ""
	if weapon.has_method("serialize"):
		var serialized = weapon.serialize()
		if typeof(serialized) == TYPE_DICTIONARY:
			return to_json(serialized)
	return ""


func _build_player_effects_runtime_key(player_index: int) -> String:
	if player_index < 0 or player_index >= RunData.players_data.size():
		return ""
	var player_data = RunData.players_data[player_index]
	if player_data == null or not player_data.has_method("serialize"):
		return ""
	var serialized = player_data.serialize()
	if typeof(serialized) != TYPE_DICTIONARY:
		return ""
	return to_json({
		"current_health": serialized.get("current_health", 0),
		"current_level": serialized.get("current_level", 0),
		"current_xp": serialized.get("current_xp", 0),
		"effects": serialized.get("effects", {}),
		"active_sets": serialized.get("active_sets", {}),
		"active_set_effects": serialized.get("active_set_effects", []),
		"unique_effects": serialized.get("unique_effects", []),
		"additional_weapon_effects": serialized.get("additional_weapon_effects", []),
		"tier_iv_weapon_effects": serialized.get("tier_iv_weapon_effects", []),
		"tier_i_weapon_effects": serialized.get("tier_i_weapon_effects", []),
		"tracked_item_effects": _build_shop_tracked_item_effects_snapshot(player_index)
	})


func _build_visual_shop_item_entry(container, shop_item_node, slot_index: int) -> Dictionary:
	var item_data = _safe_get(shop_item_node, "item_data", null)
	var active = bool(_safe_get(shop_item_node, "active", true)) and item_data != null
	if not active:
		return _build_empty_shop_slot_entry(slot_index)

	var buy_button = _safe_get(shop_item_node, "_button", null)
	var steal_button = _safe_get(shop_item_node, "_steal_button", null)
	var lock_button = _safe_get(shop_item_node, "_lock_button", null)
	var ban_button = _safe_get(shop_item_node, "_ban_button", null)
	var locked = bool(_safe_get(shop_item_node, "locked", false))
	if _is_live_ref(container) and container.has_method("is_shop_item_locked_visually"):
		locked = bool(container.is_shop_item_locked_visually(slot_index))
	var buy_disabled = _is_button_disabled(buy_button)
	var steal_disabled = _is_button_disabled(steal_button)
	var lock_disabled = _is_button_disabled(lock_button)
	var ban_disabled = _is_button_disabled(ban_button)
	return {
		"index": slot_index,
		"slot_index": slot_index,
		"item": _serialize_item_parent_data(item_data),
		"item_key": _get_shop_item_identity_key(item_data),
		"wave_value": int(_safe_get(shop_item_node, "wave_value", RunData.current_wave)),
		"locked": locked,
		"active": true,
		"disabled": buy_disabled,
		"buy_disabled": buy_disabled,
		"steal_disabled": steal_disabled,
		"lock_disabled": lock_disabled,
		"ban_disabled": ban_disabled,
		"slot_empty": false
	}


func _build_empty_shop_slot_entry(slot_index: int) -> Dictionary:
	return {
		"index": slot_index,
		"slot_index": slot_index,
		"item": {},
		"item_key": "",
		"wave_value": int(RunData.current_wave),
		"locked": false,
		"active": false,
		"disabled": true,
		"buy_disabled": true,
		"steal_disabled": true,
		"lock_disabled": true,
		"ban_disabled": true,
		"slot_empty": true
	}


func _get_raw_shop_items_for_player(shop: Node, player_index: int) -> Array:
	var raw_all_items = _safe_get(shop, "_shop_items", [])
	if typeof(raw_all_items) == TYPE_ARRAY and player_index >= 0 and player_index < raw_all_items.size() and typeof(raw_all_items[player_index]) == TYPE_ARRAY:
		return raw_all_items[player_index]
	return []


func _get_item_data_from_shop_pair(pair):
	if typeof(pair) == TYPE_ARRAY:
		return pair[0] if pair.size() > 0 else null
	if typeof(pair) == TYPE_DICTIONARY:
		return pair.get("item_data", pair.get("item", null))
	return null


func _get_wave_value_from_shop_pair(pair, fallback: int) -> int:
	if typeof(pair) == TYPE_ARRAY:
		return int(pair[1]) if pair.size() > 1 else fallback
	if typeof(pair) == TYPE_DICTIONARY:
		return int(pair.get("wave_value", fallback))
	return fallback


func _get_shop_item_identity_key(item_data) -> String:
	if item_data == null:
		return ""
	var curse_suffix = ":C0"
	if bool(_safe_get(item_data, "is_cursed", false)):
		curse_suffix = ":C1:" + str(float(_safe_get(item_data, "curse_factor", 0.0)))
	var path = _get_resource_path(item_data)
	if path != "":
		return "path:" + path + curse_suffix
	var id_hash = int(_safe_get(item_data, "my_id_hash", 0))
	if id_hash != 0:
		return "hash:" + str(id_hash) + curse_suffix
	return "id:" + str(_safe_get(item_data, "my_id", "")) + curse_suffix


func _close_shop_popup_for_player(shop: Node, player_index: int, focus_hint = null) -> void:
	if not _is_valid_shop_node(shop):
		return
	# This is not a custom focus router. It mirrors the vanilla cleanup done by
	# BaseShop._on_item_combine_button_pressed/_on_item_discard_button_pressed().
	# Client-side action interception disconnects those vanilla signal handlers,
	# so without this reset PopupManager can keep _elements_pressed set and all
	# later inventory/shop navigation appears frozen.
	var popup_manager = _safe_get(shop, "_popup_manager", null)
	if _is_live_ref(popup_manager) and popup_manager.has_method("reset_focus"):
		popup_manager.reset_focus(player_index)
	var item_popup = shop._get_item_popup(player_index) if shop.has_method("_get_item_popup") else null
	if _is_live_ref(item_popup):
		if item_popup.has_method("hide"):
			item_popup.hide(player_index)
		else:
			item_popup.hide()
	var player_container = null
	if shop.has_method("_get_coop_player_container"):
		player_container = shop._get_coop_player_container(player_index)
	if _is_live_ref(player_container):
		if player_container.has_method("on_hide_focused_inventory_popup"):
			player_container.on_hide_focused_inventory_popup()
		var dim = player_container.get_node_or_null("%PopupDimScreen")
		if _is_live_ref(dim):
			dim.hide()

	_restore_shop_focus_after_popup_close(shop, player_index, focus_hint)


func _restore_shop_focus_after_popup_close(shop: Node, player_index: int, focus_hint = null) -> void:
	if not _is_valid_shop_node(shop) or player_index < 0:
		return
	call_deferred("_deferred_restore_shop_focus_after_popup_close", shop, player_index, focus_hint)


func _deferred_restore_shop_focus_after_popup_close(shop: Node, player_index: int, focus_hint = null) -> void:
	if not _is_valid_shop_node(shop) or player_index < 0:
		return
	var focus_emulator = Utils.get_focus_emulator(player_index)
	if _is_live_ref(focus_emulator):
		var current = _safe_get(focus_emulator, "focused_control", null)
		if _is_live_ref(current) and current is Control and current.is_visible_in_tree():
			return

	var target = _find_shop_focus_restore_control(shop, player_index, focus_hint)
	if not _is_live_ref(target):
		return
	if not (target is Control) or not target.is_visible_in_tree():
		return

	if _is_live_ref(focus_emulator):
		Utils.focus_player_control(target, player_index, focus_emulator)
	else:
		target.call_deferred("grab_focus")

	var target_key = _get_inventory_focus_target_for_control(shop, player_index, target)
	if target_key == "":
		target_key = _get_current_shop_focus_target(shop, player_index)
	if target_key != "":
		_last_shop_focus_target_by_player[player_index] = target_key
		_last_local_shop_focus_key.erase(player_index)


func _find_shop_focus_restore_control(shop: Node, player_index: int, focus_hint = null):
	if not _is_valid_shop_node(shop):
		return null
	var preferred_index = -1
	if typeof(focus_hint) == TYPE_INT:
		preferred_index = int(focus_hint)
	elif typeof(focus_hint) == TYPE_DICTIONARY:
		preferred_index = int(focus_hint.get("weapon_slot_index", -1))
	elif _is_live_ref(focus_hint):
		preferred_index = _get_player_weapon_index_for_action_payload(player_index, focus_hint)

	var weapons = _get_shop_inventory_elements(shop, player_index, true)
	if not weapons.empty():
		if preferred_index < 0:
			preferred_index = 0
		preferred_index = clamp(preferred_index, 0, weapons.size() - 1)
		return weapons[preferred_index]

	var items = _get_shop_inventory_elements(shop, player_index, false)
	if not items.empty():
		return items[0]

	var reroll_button = shop._get_reroll_button(player_index) if shop.has_method("_get_reroll_button") else null
	if _is_live_ref(reroll_button) and reroll_button is Control and reroll_button.is_visible_in_tree():
		return reroll_button
	var go_button = shop._get_go_button(player_index) if shop.has_method("_get_go_button") else null
	if _is_live_ref(go_button) and go_button is Control and go_button.is_visible_in_tree():
		return go_button
	return null


func _force_shop_go_visual_state_for_player(player_index: int, pressed: bool) -> void:
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return
	_force_shop_go_visual_state(shop, player_index, pressed)


func _force_shop_go_visual_state(shop: Node, player_index: int, pressed: bool) -> void:
	if not _is_valid_shop_node(shop):
		return
	_set_node_array_value(shop, "_player_pressed_go_button", player_index, pressed)
	var checkmark = shop._get_checkmark(player_index) if shop.has_method("_get_checkmark") else null
	if _is_live_ref(checkmark):
		if pressed:
			checkmark.show()
		else:
			checkmark.hide()
	if pressed:
		_local_shop_go_pending_until_by_player.erase(player_index)

func _get_shop_item_node_from_container(container, index: int):
	if not _is_live_ref(container):
		return null
	if container.has_method("get_shop_item_node"):
		return container.get_shop_item_node(index)
	var shop_item_nodes = _safe_get(container, "_shop_items", [])
	if typeof(shop_item_nodes) == TYPE_ARRAY and index >= 0 and index < shop_item_nodes.size():
		return shop_item_nodes[index]
	return null


func _is_button_disabled(button) -> bool:
	if not _is_live_ref(button):
		return false
	return bool(_safe_get(button, "disabled", false))


func _apply_shop_item_lock_visual_only(shop_item, locked: bool) -> void:
	if not _is_live_ref(shop_item):
		return
	if locked:
		if shop_item.has_method("lock_visually"):
			shop_item.lock_visually()
	else:
		if shop_item.has_method("unlock_visually"):
			shop_item.unlock_visually()


func _apply_shop_item_entry_button_state(container, entry: Dictionary) -> void:
	if not _is_live_ref(container) or typeof(entry) != TYPE_DICTIONARY:
		return
	var item_index = int(entry.get("index", -1))
	var shop_item_node = _get_shop_item_node_from_container(container, item_index)
	if not _is_live_ref(shop_item_node):
		return
	var buy_button = _safe_get(shop_item_node, "_button", null)
	var steal_button = _safe_get(shop_item_node, "_steal_button", null)
	var lock_button = _safe_get(shop_item_node, "_lock_button", null)
	var ban_button = _safe_get(shop_item_node, "_ban_button", null)
	_set_button_disabled_from_state(buy_button, bool(entry.get("buy_disabled", entry.get("disabled", false))))
	_set_button_disabled_from_state(steal_button, bool(entry.get("steal_disabled", false)))
	_set_button_disabled_from_state(lock_button, bool(entry.get("lock_disabled", false)))
	_set_button_disabled_from_state(ban_button, bool(entry.get("ban_disabled", false)))


func _set_button_disabled_from_state(button, disabled: bool) -> void:
	if not _is_live_ref(button):
		return
	if disabled:
		if button.has_method("disable"):
			button.disable()
		else:
			button.disabled = true
		if button is Control:
			button.focus_mode = Control.FOCUS_NONE
	else:
		if button.has_method("activate"):
			button.activate()
		else:
			button.disabled = false


func _apply_endless_mode_to_current_ui(endless_value: bool) -> void:
	var current = get_tree().current_scene
	if not _is_live_ref(current):
		return
	var buttons = []
	_collect_nodes_named(current, "EndlessButton", buttons)
	for button in buttons:
		if not _is_live_ref(button):
			continue
		if button is BaseButton:
			if button.has_method("set_pressed_no_signal"):
				button.set_pressed_no_signal(endless_value)
			else:
				button.pressed = endless_value


func _collect_nodes_named(node: Node, target_name: String, out: Array) -> void:
	if not _is_live_ref(node):
		return
	if str(node.name) == target_name:
		out.append(node)
	for child in node.get_children():
		if child is Node:
			_collect_nodes_named(child, target_name, out)


func _describe_node_short(node) -> String:
	if not _is_live_ref(node):
		return "<null>"
	var name = str(node.name)
	var cls = node.get_class() if node is Object else "Object"
	return name + "#" + str(node.get_instance_id()) + "<" + cls + ">"


func _get_host_local_player_index() -> int:
	var indices = _get_host_local_player_indices()
	if not indices.empty():
		return int(indices[0])
	return 0 if RunData.get_player_count() > 0 else -1


func _get_host_local_player_indices() -> Array:
	var result = []
	var player_count = max(1, RunData.get_player_count())
	var slot_manager = _get_slot_manager()
	if slot_manager != null:
		if slot_manager.has_method("get_local_player_indices"):
			var local_indices = slot_manager.get_local_player_indices()
			if typeof(local_indices) == TYPE_ARRAY:
				for idx_value in local_indices:
					var idx = int(idx_value)
					if idx >= 0 and idx < player_count and not result.has(idx):
						result.append(idx)
				if not result.empty():
					return result
		if slot_manager.has_method("is_remote_player_index"):
			for idx in range(player_count):
				if not bool(slot_manager.is_remote_player_index(idx)):
					result.append(idx)
			if not result.empty():
				return result
	if player_count > 0:
		result.append(0)
	return result


func _is_node_ancestor_of(ancestor: Node, node: Node) -> bool:
	if not _is_live_ref(ancestor) or not _is_live_ref(node):
		return false
	var cur = node
	while _is_live_ref(cur):
		if cur == ancestor:
			return true
		cur = cur.get_parent()
	return false


func _find_shop_node() -> Node:
	var current = get_tree().current_scene
	if _is_valid_shop_node(current):
		return current
	if _is_live_ref(current):
		return _find_shop_node_recursive(current)
	return null


func _find_shop_node_recursive(node: Node) -> Node:
	if not _is_live_ref(node):
		return null
	if _is_valid_shop_node(node):
		return node
	for child in node.get_children():
		var found = _find_shop_node_recursive(child)
		if _is_live_ref(found):
			return found
	return null


func _is_valid_shop_node(node) -> bool:
	if not _is_live_ref(node):
		return false
	if node.has_method("get_player_shop_items") and node.has_method("_get_shop_items_container"):
		return true
	var script_path = _get_script_path(node)
	return script_path.find("ui/menus/shop/base_shop.gd") != -1 or script_path.find("ui/menus/shop/coop_shop.gd") != -1 or script_path.find("ui/menus/shop/shop.gd") != -1


func _get_current_shop_focus_target(shop: Node, player_index: int) -> String:
	if not _is_valid_shop_node(shop):
		return ""
	var focus_emulator = Utils.get_focus_emulator(player_index)
	var focused_control = _safe_get(focus_emulator, "focused_control", null)
	if _is_live_ref(focused_control):
		var reroll_button = shop._get_reroll_button(player_index) if shop.has_method("_get_reroll_button") else null
		if _is_live_ref(reroll_button) and focused_control == reroll_button:
			return "reroll"
		var go_button = shop._get_go_button(player_index) if shop.has_method("_get_go_button") else null
		if _is_live_ref(go_button) and focused_control == go_button:
			return "go"
		var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
		if _is_live_ref(container):
			var shop_items = _safe_get(container, "_shop_items", [])
			if typeof(shop_items) == TYPE_ARRAY:
				for i in range(shop_items.size()):
					var item = shop_items[i]
					if not _is_live_ref(item):
						continue
					var button = _safe_get(item, "_button", null)
					if _is_live_ref(button) and focused_control == button:
						return "item_" + str(i)
		var inv_target = _get_inventory_focus_target_for_control(shop, player_index, focused_control)
		if inv_target != "":
			return inv_target

	# Fallback for the vanilla shop state variable. This only tracks shop buy items,
	# not inventory weapons/items, so keep it after the actual FocusEmulator check.
	var focused_items = _safe_get(shop, "_focused_shop_item", [])
	if typeof(focused_items) == TYPE_ARRAY and player_index >= 0 and player_index < focused_items.size():
		var focused_shop_item = focused_items[player_index]
		var idx = _get_shop_item_index(focused_shop_item, player_index)
		if idx >= 0:
			return "item_" + str(idx)
	return ""


func _get_control_for_shop_target(shop: Node, player_index: int, target: String):
	if target == "reroll":
		return shop._get_reroll_button(player_index) if shop.has_method("_get_reroll_button") else null
	if target == "go":
		return shop._get_go_button(player_index) if shop.has_method("_get_go_button") else null
	var shop_item = _get_shop_item_for_target(shop, player_index, target)
	if _is_live_ref(shop_item):
		return _safe_get(shop_item, "_button", shop_item)
	var inv_element = _get_inventory_element_for_shop_target(shop, player_index, target)
	if _is_live_ref(inv_element):
		return inv_element
	return null


func _get_inventory_focus_target_for_control(shop: Node, player_index: int, focused_control) -> String:
	# InventoryElement itself is normally the focused Control, but after opening an
	# inventory popup vanilla focus can temporarily sit on a child/popup button.
	# Accept descendants as belonging to the same inventory target so shop_focus
	# packets continue to describe weapons/items instead of falling back to shop
	# items only.
	var weapons = _get_shop_inventory_elements(shop, player_index, true)
	for i in range(weapons.size()):
		if _control_matches_or_contains(weapons[i], focused_control):
			return "weapon_" + str(i)
	var items = _get_shop_inventory_elements(shop, player_index, false)
	for i in range(items.size()):
		if _control_matches_or_contains(items[i], focused_control):
			return "inventory_item_" + str(i)
	return ""


func _control_matches_or_contains(owner, control) -> bool:
	if not _is_live_ref(owner) or not _is_live_ref(control):
		return false
	if owner == control:
		return true
	if _safe_node_is_parent_of(owner, control):
		return true
	return false


func _get_inventory_element_for_shop_target(shop: Node, player_index: int, target: String):
	var is_weapon = false
	var index = -1
	if target.begins_with("weapon_"):
		is_weapon = true
		var raw_weapon = target.substr(String("weapon_").length(), target.length())
		if raw_weapon.is_valid_integer():
			index = int(raw_weapon)
	elif target.begins_with("inventory_item_"):
		is_weapon = false
		var raw_item = target.substr(String("inventory_item_").length(), target.length())
		if raw_item.is_valid_integer():
			index = int(raw_item)
	else:
		return null
	if index < 0:
		return null
	var elements = _get_shop_inventory_elements(shop, player_index, is_weapon)
	if index >= 0 and index < elements.size():
		return elements[index]
	return null


func _get_shop_inventory_elements(shop: Node, player_index: int, is_weapon: bool) -> Array:
	var result = []
	if not _is_valid_shop_node(shop) or not shop.has_method("_get_gear_container"):
		return result
	var gear = shop._get_gear_container(player_index)
	if not _is_live_ref(gear):
		return result
	var inv_container = _safe_get(gear, "weapons_container", null) if is_weapon else _safe_get(gear, "items_container", null)
	if not _is_live_ref(inv_container):
		return result
	var elements_node = _safe_get(inv_container, "_elements", null)
	if not _is_live_ref(elements_node):
		return result
	for child in elements_node.get_children():
		if _is_live_ref(child) and child is Control and child.is_visible_in_tree():
			result.append(child)
	return result


func _set_focus_emulator_control_safely(focus_emulator, control) -> bool:
	if not _is_live_ref(focus_emulator) or not _is_live_ref(control):
		return false

	# FocusEmulator._set_focused_control_with_style(control, false) intentionally
	# avoids emitting focus_entered/focus_exited. That is safer for online menu
	# sync, but ButtonWithIcon uses those signals to restore child Label font
	# colors/outlines. Without this manual mirror, the old shop/reroll/go button
	# loses its focus border while its text can stay in the focused/dimmed state.
	var previous_control = _safe_get(focus_emulator, "focused_control", null)
	if previous_control == control:
		_sync_button_with_icon_visual_focus(control, true)
		return true
	_sync_button_with_icon_visual_focus(previous_control, false)

	if focus_emulator.has_method("_set_focused_control_with_style"):
		focus_emulator._set_focused_control_with_style(control, false)
	else:
		focus_emulator.set("focused_control", control)

	_sync_button_with_icon_visual_focus(control, true)
	return true


func _sync_button_with_icon_visual_focus(control, focused: bool) -> void:
	if not _is_live_ref(control) or not control.has_method("_update_focus_colors"):
		return
	if _has_property(control, "_focused"):
		control.set("_focused", focused)
	if not focused:
		var hovered = bool(_safe_get(control, "_hovered", false))
		if not hovered and _has_property(control, "_pressed"):
			control.set("_pressed", false)
	control._update_focus_colors()


func _apply_shop_focus_popup_side_effects(shop: Node, player_index: int, previous_target: String, target: String, force_refresh: bool = false) -> void:
	if previous_target == target and not force_refresh:
		return
	if previous_target != target:
		_hide_shop_focus_popup_for_target(shop, player_index, previous_target)
	# Always show/refresh the new target. This is required for observer panels: the
	# remote FocusEmulator visual box can move without emitting the vanilla focus
	# signals that normally refresh CoopShopPlayerContainer.item_popup.
	_show_shop_focus_popup_for_target(shop, player_index, target)


func _hide_shop_focus_popup_for_target(shop: Node, player_index: int, target: String) -> void:
	if target == "":
		return
	var player_container = _get_shop_player_container_safe(shop, player_index)
	var item_popup = shop._get_item_popup(player_index) if _is_valid_shop_node(shop) and shop.has_method("_get_item_popup") else null
	var shop_item = _get_shop_item_for_target(shop, player_index, target)
	if _is_live_ref(shop_item):
		if _is_live_ref(player_container) and player_container.has_method("on_hide_shop_item_popup"):
			player_container.on_hide_shop_item_popup(shop_item)
		elif _is_live_ref(item_popup) and item_popup.has_method("hide_hints"):
			item_popup.hide_hints()
		elif shop.has_method("_on_shop_item_unfocused"):
			shop._on_shop_item_unfocused(shop_item, player_index)
		return
	var inv_element = _get_inventory_element_for_shop_target(shop, player_index, target)
	if _is_live_ref(inv_element):
		if _is_live_ref(player_container) and player_container.has_method("on_hide_inventory_popup"):
			player_container.on_hide_inventory_popup(inv_element)
		elif _is_live_ref(item_popup) and item_popup.has_method("hide_hints"):
			item_popup.hide_hints()
		elif shop.has_method("_on_element_unfocused"):
			shop._on_element_unfocused(inv_element, player_index)


func _show_shop_focus_popup_for_target(shop: Node, player_index: int, target: String) -> void:
	if target == "":
		return
	var player_container = _get_shop_player_container_safe(shop, player_index)
	var item_popup = shop._get_item_popup(player_index) if _is_valid_shop_node(shop) and shop.has_method("_get_item_popup") else null
	var shop_item = _get_shop_item_for_target(shop, player_index, target)
	if _is_live_ref(shop_item):
		# The vanilla PopupManager first calls display_item_data(), then CoopShop only
		# adds coop-specific lock/steal/ban hints. Calling show_shop_hints() alone keeps
		# the previous item panel content (for example SMG text while Toxic Sludge is
		# highlighted), so refresh the actual panel data explicitly.
		_set_node_array_value(shop, "_focused_shop_item", player_index, shop_item)
		_set_node_array_value(shop, "_latest_focused_shop_item", player_index, shop_item)
		if _is_live_ref(item_popup):
			if item_popup.has_method("display_item_data"):
				var button = _safe_get(shop_item, "_button", shop_item)
				item_popup.display_item_data(shop_item.item_data, button)
			if item_popup.has_method("set_synergies_visible"):
				item_popup.set_synergies_visible(true)
			item_popup.shop_item = shop_item
			if item_popup.has_method("show_shop_hints"):
				item_popup.show_shop_hints(shop_item)
			return
		if _is_live_ref(player_container) and player_container.has_method("on_show_shop_item_popup"):
			player_container.on_show_shop_item_popup(shop_item)
		elif shop.has_method("_on_shop_item_focused"):
			shop._on_shop_item_focused(shop_item, player_index)
		return
	var inv_element = _get_inventory_element_for_shop_target(shop, player_index, target)
	if _is_live_ref(inv_element):
		if _is_live_ref(item_popup):
			if item_popup.has_method("display_element"):
				item_popup.display_element(inv_element)
			if item_popup.has_method("set_synergies_visible"):
				var synergies_visible = false
				if _is_live_ref(player_container) and player_container.has_method("_should_show_synergies"):
					synergies_visible = bool(player_container._should_show_synergies())
				item_popup.set_synergies_visible(synergies_visible)
			if item_popup.has_method("show_inventory_hint"):
				item_popup.show_inventory_hint(inv_element.item)
			return
		if _is_live_ref(player_container) and player_container.has_method("on_show_inventory_popup"):
			player_container.on_show_inventory_popup(inv_element)
		elif shop.has_method("_on_element_focused"):
			shop._on_element_focused(inv_element, player_index)


func _get_shop_player_container_safe(shop: Node, player_index: int):
	if _is_valid_shop_node(shop) and shop.has_method("_get_coop_player_container") and player_index >= 0:
		var container = shop._get_coop_player_container(player_index)
		if _is_live_ref(container):
			return container
	return null


func _get_shop_item_for_action(shop: Node, player_index: int, message: Dictionary):
	var target = str(message.get("target", ""))
	if target == "":
		target = "item_" + str(int(message.get("shop_index", -1)))
	var preferred = _get_shop_item_for_target(shop, player_index, target)
	if _is_live_ref(preferred) and _shop_item_matches_action(preferred, message):
		return preferred

	# After a buy, vanilla compacts _shop_items. A delayed input can therefore carry
	# a stale index. Prefer the item hash/resource identity over the index so Host
	# never buys the wrong slot.
	var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
	if _is_live_ref(container):
		var shop_item_nodes = _safe_get(container, "_shop_items", [])
		if typeof(shop_item_nodes) == TYPE_ARRAY:
			for shop_item in shop_item_nodes:
				if _is_live_ref(shop_item) and _shop_item_matches_action(shop_item, message):
					return shop_item

	# Only fall back to the indexed target if the packet did not include an item id.
	if int(message.get("item_id_hash", 0)) == 0 and str(message.get("item_log", "")) == "":
		return preferred
	return null


func _shop_item_matches_action(shop_item, message: Dictionary) -> bool:
	if not _is_live_ref(shop_item):
		return false
	if not bool(_safe_get(shop_item, "active", true)):
		return false
	var item_data = _safe_get(shop_item, "item_data", null)
	if item_data == null:
		return false
	var wanted_hash = int(message.get("item_id_hash", 0))
	if wanted_hash != 0 and int(_safe_get(item_data, "my_id_hash", 0)) == wanted_hash:
		return true
	var wanted_item = message.get("item", {})
	if typeof(wanted_item) == TYPE_DICTIONARY:
		var wanted_item_hash = int(wanted_item.get("my_id_hash", 0))
		if wanted_item_hash != 0 and int(_safe_get(item_data, "my_id_hash", 0)) == wanted_item_hash:
			return true
		var wanted_path = str(wanted_item.get("resource_path", ""))
		if wanted_path != "" and _get_resource_path(item_data) == wanted_path:
			return true
	var wanted_key = str(message.get("item_key", ""))
	if wanted_key != "" and _get_shop_item_identity_key(item_data) == wanted_key:
		return true
	var wanted_log = str(message.get("item_log", ""))
	if wanted_log != "" and _get_item_id_for_log(item_data) == wanted_log:
		return true
	return wanted_hash == 0 and wanted_log == "" and wanted_key == ""


func _get_player_weapon_index_for_action_payload(player_index: int, weapon_data) -> int:
	if player_index < 0 or player_index >= RunData.get_player_count() or weapon_data == null:
		return -1
	var weapons = RunData.get_player_weapons(player_index)
	for i in range(weapons.size()):
		if weapons[i] == weapon_data:
			return i
	for i in range(weapons.size()):
		var weapon = weapons[i]
		if weapon == null:
			continue
		if _weapon_data_identity_matches(weapon, weapon_data):
			return i
	return -1


func _weapon_data_identity_matches(candidate, wanted) -> bool:
	if candidate == null or wanted == null:
		return false
	var wanted_my_hash = int(_safe_get(wanted, "my_id_hash", 0))
	if wanted_my_hash != 0 and int(_safe_get(candidate, "my_id_hash", 0)) == wanted_my_hash:
		return true
	var wanted_weapon_hash = int(_safe_get(wanted, "weapon_id_hash", 0))
	if wanted_weapon_hash != 0 and int(_safe_get(candidate, "weapon_id_hash", 0)) == wanted_weapon_hash:
		return true
	var wanted_my_id = str(_safe_get(wanted, "my_id", ""))
	if wanted_my_id != "" and str(_safe_get(candidate, "my_id", "")) == wanted_my_id:
		return true
	var wanted_weapon_id = str(_safe_get(wanted, "weapon_id", ""))
	if wanted_weapon_id != "" and str(_safe_get(candidate, "weapon_id", "")) == wanted_weapon_id:
		return true
	var wanted_path = _get_resource_path(wanted)
	if wanted_path != "" and _get_resource_path(candidate) == wanted_path:
		return true
	return false


func _find_player_weapon_for_shop_action(player_index: int, message: Dictionary):
	if player_index < 0 or player_index >= RunData.get_player_count():
		return null
	var weapons = RunData.get_player_weapons(player_index)
	var wanted_slot = int(message.get("weapon_slot_index", -1))
	if wanted_slot >= 0 and wanted_slot < weapons.size():
		var slot_weapon = weapons[wanted_slot]
		if slot_weapon != null and _weapon_matches_shop_action(slot_weapon, message):
			return slot_weapon

	for weapon in weapons:
		if weapon == null:
			continue
		if _weapon_matches_shop_action(weapon, message):
			return weapon

	# If the packet came from an older client or all identity fields failed but the
	# slot is still valid, use the slot as a final fallback. It is better to recycle
	# the selected slot than to accept the client action visually and leave Host unchanged.
	if wanted_slot >= 0 and wanted_slot < weapons.size():
		return weapons[wanted_slot]
	return null


func _weapon_matches_shop_action(weapon, message: Dictionary) -> bool:
	if weapon == null:
		return false
	var weapon_state = message.get("weapon", {})
	var wanted_my_hashes = []
	_append_unique_id_value(wanted_my_hashes, int(message.get("weapon_my_id_hash", 0)))
	# Legacy field name used by earlier builds.
	_append_unique_id_value(wanted_my_hashes, int(message.get("weapon_id_hash", 0)))
	if typeof(weapon_state) == TYPE_DICTIONARY:
		_append_unique_id_value(wanted_my_hashes, int(weapon_state.get("my_id_hash", 0)))
	for wanted_my_hash in wanted_my_hashes:
		if int(wanted_my_hash) != 0 and int(_safe_get(weapon, "my_id_hash", 0)) == int(wanted_my_hash):
			return true

	var wanted_weapon_hashes = []
	_append_unique_id_value(wanted_weapon_hashes, int(message.get("weapon_weapon_id_hash", 0)))
	if typeof(weapon_state) == TYPE_DICTIONARY:
		_append_unique_id_value(wanted_weapon_hashes, int(weapon_state.get("weapon_id_hash", 0)))
	for wanted_weapon_hash in wanted_weapon_hashes:
		if int(wanted_weapon_hash) != 0 and int(_safe_get(weapon, "weapon_id_hash", 0)) == int(wanted_weapon_hash):
			return true

	var wanted_ids = []
	_append_unique_string_value(wanted_ids, str(message.get("weapon_my_id", "")))
	_append_unique_string_value(wanted_ids, str(message.get("weapon_id", "")))
	if typeof(weapon_state) == TYPE_DICTIONARY:
		_append_unique_string_value(wanted_ids, str(weapon_state.get("my_id", "")))
	for wanted_id in wanted_ids:
		if str(wanted_id) != "" and str(_safe_get(weapon, "my_id", "")) == str(wanted_id):
			return true

	var wanted_weapon_ids = []
	_append_unique_string_value(wanted_weapon_ids, str(message.get("weapon_weapon_id", "")))
	if typeof(weapon_state) == TYPE_DICTIONARY:
		_append_unique_string_value(wanted_weapon_ids, str(weapon_state.get("weapon_id", "")))
	for wanted_weapon_id in wanted_weapon_ids:
		if str(wanted_weapon_id) != "" and str(_safe_get(weapon, "weapon_id", "")) == str(wanted_weapon_id):
			return true

	if typeof(weapon_state) == TYPE_DICTIONARY:
		var wanted_path = str(weapon_state.get("resource_path", ""))
		if wanted_path != "" and _get_resource_path(weapon) == wanted_path:
			return true
	var wanted_log = str(message.get("item_log", ""))
	if wanted_log != "" and _get_item_id_for_log(weapon) == wanted_log:
		return true
	return false


func _get_shop_item_for_target(shop: Node, player_index: int, target: String):
	var idx = _shop_target_to_index(target)
	if idx < 0:
		return null
	var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
	if _is_live_ref(container) and container.has_method("get_shop_item_node"):
		return container.get_shop_item_node(idx)
	return null


func _get_shop_item_index(shop_item, player_index: int) -> int:
	if not _is_live_ref(shop_item):
		return -1
	var shop = _find_shop_node()
	if not _is_valid_shop_node(shop):
		return -1
	var container = shop._get_shop_items_container(player_index) if shop.has_method("_get_shop_items_container") else null
	if not _is_live_ref(container):
		return -1
	var shop_items = _safe_get(container, "_shop_items", [])
	if typeof(shop_items) != TYPE_ARRAY:
		return -1
	for i in range(shop_items.size()):
		if shop_items[i] == shop_item:
			return i
	return -1


func _shop_target_to_index(target: String) -> int:
	if not target.begins_with("item_"):
		return -1
	var raw = target.substr(String("item_").length(), target.length())
	if not raw.is_valid_integer():
		return -1
	return int(raw)


func _set_shop_player_items_array(shop: Node, player_index: int, player_shop_items: Array) -> void:
	var all_items = _safe_get(shop, "_shop_items", [])
	if typeof(all_items) != TYPE_ARRAY:
		all_items = []
	var min_size = max(4, _get_run_player_count())
	while all_items.size() < min_size:
		all_items.append([])
	all_items[player_index] = player_shop_items
	shop.set("_shop_items", all_items)


func _get_node_array_value(node: Node, prop_name: String, index: int, fallback):
	var arr = _safe_get(node, prop_name, [])
	if typeof(arr) != TYPE_ARRAY:
		return fallback
	if index < 0 or index >= arr.size():
		return fallback
	return arr[index]


func _set_node_array_value(node: Node, prop_name: String, index: int, value) -> void:
	var arr = _safe_get(node, prop_name, [])
	if typeof(arr) != TYPE_ARRAY:
		arr = []
	var min_size = max(4, _get_run_player_count())
	while arr.size() < min_size:
		arr.append(value)
	arr[index] = value
	node.set(prop_name, arr)


func _apply_serialized_players_run_data(players: Array, preserve_client_local_runtime_state: bool = true) -> bool:
	var applied = false
	for player_state in players:
		if typeof(player_state) != TYPE_DICTIONARY:
			continue
		var player_index = int(player_state.get("player_index", -1))
		var run_data_state = player_state.get("run_data", {})
		if _apply_one_serialized_player_run_data(player_index, run_data_state, preserve_client_local_runtime_state):
			_apply_missing_host_inventory_placeholders_from_serialized_state(player_index, _expand_compact_player_run_data_from_shop_sync(player_index, run_data_state))
			applied = true
	return applied


func _apply_one_serialized_player_run_data(player_index: int, run_data_state, preserve_client_local_runtime_state: bool = true) -> bool:
	if player_index < 0:
		return false
	if typeof(run_data_state) != TYPE_DICTIONARY or run_data_state.empty():
		return false
	if bool(run_data_state.get("online_light_run_data", false)):
		return _apply_id_only_player_run_data(player_index, run_data_state, preserve_client_local_runtime_state)
	run_data_state = _expand_compact_player_run_data_from_shop_sync(player_index, run_data_state)
	if RunData.get_player_count() <= player_index:
		RunData.set_player_count(player_index + 1, false)

	var preserve_local_health = preserve_client_local_runtime_state and _should_preserve_client_local_player_runtime_state(player_index)
	var preserved_current_health = -1
	if preserve_local_health and player_index < RunData.players_data.size() and RunData.players_data[player_index] != null:
		preserved_current_health = int(RunData.players_data[player_index].current_health)

	var player_data = PlayerRunData.new()
	player_data.deserialize(run_data_state)
	_repair_player_run_data_weapon_subclass_effect_fields(player_data, "serialized_player_run_data")
	if player_data.current_character == null and run_data_state.has("current_character") and run_data_state.current_character != null:
		var character_state = {"id": str(run_data_state.current_character), "log": str(run_data_state.current_character)}
		var fallback_character = _resolve_character_data_for_run_config(character_state, player_index, "serialized_run_data")
		if fallback_character != null:
			player_data.current_character = fallback_character
			if not player_data.items.has(fallback_character):
				player_data.items.push_front(fallback_character)
	RunData.players_data[player_index] = player_data
	_rebind_selected_weapon_from_inventory(player_index)
	_apply_shop_tracked_item_effects_from_run_data(player_index, run_data_state)

	if preserve_local_health and preserved_current_health >= 0:
		var max_health = int(RunData.get_player_max_health(player_index)) if RunData.has_method("get_player_max_health") else preserved_current_health
		RunData.players_data[player_index].current_health = int(clamp(preserved_current_health, 1, max(1, max_health)))
	return true


func _rebind_selected_weapon_from_inventory(player_index: int) -> void:
	if player_index < 0 or player_index >= RunData.players_data.size():
		return
	var player_data = RunData.players_data[player_index]
	if player_data == null:
		return
	var selected = _safe_get(player_data, "selected_weapon", null)
	if selected == null:
		return
	var selected_id = str(_safe_get(selected, "my_id", ""))
	var selected_weapon_id = str(_safe_get(selected, "weapon_id", ""))
	for weapon in _safe_get(player_data, "weapons", []):
		if weapon == null:
			continue
		if selected_id != "" and str(_safe_get(weapon, "my_id", "")) == selected_id:
			player_data.selected_weapon = weapon
			return
		if selected_weapon_id != "" and str(_safe_get(weapon, "weapon_id", "")) == selected_weapon_id:
			player_data.selected_weapon = weapon
			return


func _repair_player_run_data_weapon_subclass_effect_fields(player_data, reason: String = "") -> void:
	if player_data == null:
		return
	var weapons = _safe_get(player_data, "weapons", [])
	if typeof(weapons) != TYPE_ARRAY:
		return
	for weapon in weapons:
		_repair_weapon_subclass_effect_runtime_fields(weapon, null, reason)
	var selected_weapon = _safe_get(player_data, "selected_weapon", null)
	if selected_weapon != null:
		_repair_weapon_subclass_effect_runtime_fields(selected_weapon, null, reason + ":selected")


func _repair_weapon_subclass_effect_runtime_fields(weapon_data, source_weapon = null, reason: String = "") -> void:
	if weapon_data == null or not (weapon_data is WeaponData):
		return
	var effects = _safe_get(weapon_data, "effects", [])
	if typeof(effects) != TYPE_ARRAY or effects.empty():
		return
	var base_weapon = source_weapon
	if base_weapon == null or not (base_weapon is WeaponData):
		base_weapon = _resolve_base_weapon_resource_for_effect_repair(weapon_data)
	if base_weapon == null or not (base_weapon is WeaponData):
		return
	var base_effects = _safe_get(base_weapon, "effects", [])
	if typeof(base_effects) != TYPE_ARRAY or base_effects.empty():
		return
	var repaired_count = 0
	for i in range(effects.size()):
		var effect = effects[i]
		if effect == null:
			continue
		var effect_id = _get_effect_id_for_repair(effect)
		if effect_id != "weapon_gain_stat_for_every_stat":
			continue
		if str(_safe_get(effect, "increased_stat_name", "")) != "":
			continue
		var base_effect = _find_matching_base_effect_for_repair(base_effects, effect, i, effect_id)
		var increased_stat_name = str(_safe_get(base_effect, "increased_stat_name", ""))
		if increased_stat_name == "":
			continue
		effect.set("increased_stat_name", increased_stat_name)
		repaired_count += 1
	if repaired_count > 0:
		pass


func _resolve_base_weapon_resource_for_effect_repair(weapon_data):
	if weapon_data == null:
		return null
	var resource_path = str(_safe_get(weapon_data, "resource_path", ""))
	if resource_path != "" and ResourceLoader.exists(resource_path):
		var loaded = load(resource_path)
		if loaded != null and loaded is WeaponData:
			return loaded
	var my_id = str(_safe_get(weapon_data, "my_id", ""))
	if my_id != "" and ItemService != null and ItemService.has_method("get_element_safe"):
		var by_id = ItemService.get_element_safe(ItemService.weapons, my_id)
		if by_id != null and by_id is WeaponData:
			return by_id
	var my_id_hash = int(_safe_get(weapon_data, "my_id_hash", 0))
	if my_id_hash != 0 and ItemService != null and ItemService.has_method("get_element"):
		var by_hash = ItemService.get_element(ItemService.weapons, my_id_hash)
		if by_hash != null and by_hash is WeaponData:
			return by_hash
	var weapon_id_hash = int(_safe_get(weapon_data, "weapon_id_hash", 0))
	if weapon_id_hash != 0 and ItemService != null and ItemService.has_method("get_element"):
		var by_weapon_hash = ItemService.get_element(ItemService.weapons, weapon_id_hash)
		if by_weapon_hash != null and by_weapon_hash is WeaponData:
			return by_weapon_hash
	return null


func _find_matching_base_effect_for_repair(base_effects: Array, effect, preferred_index: int, effect_id: String):
	if preferred_index >= 0 and preferred_index < base_effects.size():
		var candidate = base_effects[preferred_index]
		if _get_effect_id_for_repair(candidate) == effect_id:
			return candidate
	for candidate in base_effects:
		if _get_effect_id_for_repair(candidate) == effect_id:
			return candidate
	return null


func _get_effect_id_for_repair(effect) -> String:
	if effect == null:
		return ""
	if effect.has_method("get_id"):
		return str(effect.get_id())
	return ""

func _apply_id_only_player_run_data(player_index: int, run_data_state: Dictionary, preserve_client_local_runtime_state: bool = true) -> bool:
	if player_index < 0:
		return false
	if RunData.get_player_count() <= player_index:
		RunData.set_player_count(player_index + 1, false)

	var preserve_local_health = preserve_client_local_runtime_state and _should_preserve_client_local_player_runtime_state(player_index)
	var preserved_current_health = -1
	if preserve_local_health and player_index < RunData.players_data.size() and RunData.players_data[player_index] != null:
		preserved_current_health = int(RunData.players_data[player_index].current_health)

	while RunData.players_data.size() <= player_index:
		RunData.players_data.append(PlayerRunData.new())
	RunData.players_data[player_index] = PlayerRunData.new()

	var character_id = str(run_data_state.get("current_character", ""))
	var character_hash = 0
	if character_id != "":
		character_hash = int(Keys.generate_hash(character_id))
	var character = _resolve_character_resource_from_id_only(character_id, character_hash, player_index, "id_only_run_data")
	if character != null:
		RunData.add_character(character.duplicate(), player_index)

	var selected_weapon_id = str(run_data_state.get("selected_weapon", ""))
	var selected_item_id = str(run_data_state.get("selected_item", ""))
	_apply_id_only_weapon_entries(player_index, run_data_state.get("weapons", []))
	_apply_id_only_item_entries(player_index, run_data_state.get("items", []), character_id)
	_set_id_only_selected_weapon(player_index, selected_weapon_id)
	_set_id_only_selected_item(player_index, selected_item_id)

	var player_data = RunData.players_data[player_index]
	player_data.current_level = int(run_data_state.get("current_level", 0))
	player_data.current_xp = float(run_data_state.get("current_xp", 0.0))
	player_data.gold = int(run_data_state.get("gold", 0))
	player_data.uses_ban = bool(run_data_state.get("uses_ban", false))
	player_data.remaining_ban_token = int(run_data_state.get("remaining_ban_token", 0))
	player_data.banned_items = _duplicate_array_safe(run_data_state.get("banned_items", []))
	player_data.chal_recycling_current = int(run_data_state.get("chal_recycling_current", 0))
	player_data.consumables_picked_up_this_run = int(run_data_state.get("consumables_picked_up_this_run", 0))
	player_data.curse_locked_shop_items_pity = int(run_data_state.get("curse_locked_shop_items_pity", 0))

	var host_health = int(run_data_state.get("current_health", PlayerRunData.DEFAULT_MAX_HP))
	if preserve_local_health and preserved_current_health >= 0:
		var max_health = int(RunData.get_player_max_health(player_index)) if RunData.has_method("get_player_max_health") else preserved_current_health
		player_data.current_health = int(clamp(preserved_current_health, 1, max(1, max_health)))
	else:
		player_data.current_health = host_health
	return true


func _apply_id_only_weapon_entries(player_index: int, entries) -> void:
	if typeof(entries) != TYPE_ARRAY:
		return
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var count = max(1, int(entry.get("count", 1)))
		var weapon = _resolve_weapon_resource_from_id_only(entry)
		if weapon == null:
			continue
		if _is_full_serialized_weapon_entry(entry):
			weapon = _duplicate_weapon_from_serialized_entry(weapon, entry)
		for _i in range(count):
			RunData.add_weapon(weapon, player_index, false)


func _is_full_serialized_weapon_entry(entry: Dictionary) -> bool:
	return entry.has("stats") or entry.has("effects") or entry.has("sets") or entry.has("serialized_data")


func _duplicate_weapon_from_serialized_entry(base_weapon, entry: Dictionary):
	if base_weapon == null:
		return null
	var copy = base_weapon.duplicate()
	var serialized = entry.get("serialized_data", entry)
	if typeof(serialized) == TYPE_DICTIONARY and copy.has_method("deserialize_and_merge"):
		copy.deserialize_and_merge(serialized)
		_repair_weapon_subclass_effect_runtime_fields(copy, base_weapon, "serialized_weapon_entry")
	return copy


func _apply_id_only_item_entries(player_index: int, entries, character_id: String = "") -> void:
	if typeof(entries) != TYPE_ARRAY:
		return
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item_id = str(entry.get("my_id", entry.get("id", "")))
		if character_id != "" and item_id == character_id:
			continue
		var count = max(1, int(entry.get("count", 1)))
		var item = _resolve_item_resource_from_id_only(entry)
		if item == null:
			continue
		for _i in range(count):
			RunData.add_item(item.duplicate(), player_index, false)


func _set_id_only_selected_weapon(player_index: int, weapon_id: String) -> void:
	if weapon_id == "" or player_index < 0 or player_index >= RunData.players_data.size():
		return
	var weapon = ItemService.get_element_safe(ItemService.weapons, weapon_id)
	if weapon != null:
		RunData.players_data[player_index].selected_weapon = weapon.duplicate()


func _set_id_only_selected_item(player_index: int, item_id: String) -> void:
	if item_id == "" or player_index < 0 or player_index >= RunData.players_data.size():
		return
	var item = ItemService.get_element_safe(ItemService.items, item_id)
	if item != null:
		RunData.players_data[player_index].selected_item = item.duplicate()


func _resolve_weapon_resource_from_id_only(entry: Dictionary):
	var item_id = str(entry.get("my_id", entry.get("id", "")))
	var weapon_id = str(entry.get("weapon_id", ""))
	var item_hash = int(entry.get("my_id_hash", entry.get("id_hash", 0)))
	var weapon_hash = int(entry.get("weapon_id_hash", 0))
	var weapon = null
	if item_id != "":
		weapon = ItemService.get_element_safe(ItemService.weapons, item_id)
	if weapon == null and weapon_id != "":
		weapon = ItemService.get_element_safe(ItemService.weapons, weapon_id)
	if weapon == null and item_hash != 0:
		weapon = ItemService.get_element(ItemService.weapons, item_hash)
	if weapon == null and weapon_hash != 0:
		weapon = ItemService.get_element(ItemService.weapons, weapon_hash)
	return weapon


func _resolve_item_resource_from_id_only(entry: Dictionary):
	var item_id = str(entry.get("my_id", entry.get("id", "")))
	var item_hash = int(entry.get("my_id_hash", entry.get("id_hash", 0)))
	var item = null
	if item_id != "":
		item = ItemService.get_element_safe(ItemService.items, item_id)
		if item == null:
			item = ItemService.get_element_safe(ItemService.characters, item_id)
	if item == null and item_hash != 0:
		item = ItemService.get_element(ItemService.items, item_hash)
		if item == null:
			item = ItemService.get_element(ItemService.characters, item_hash)
	return item


func _resolve_character_resource_from_id_only(character_id: String, character_hash: int, player_index: int, target_screen: String):
	if character_id != "":
		var character = ItemService.get_element_safe(ItemService.characters, character_id)
		if character != null:
			return character
	if character_hash != 0:
		var character_by_hash = ItemService.get_element(ItemService.characters, character_hash)
		if character_by_hash != null:
			return character_by_hash
	return _get_dlc_safe_fallback_character_data({"id": character_id, "id_hash": character_hash}, player_index, target_screen)


func _apply_missing_host_inventory_placeholders_from_serialized_state(player_index: int, run_data_state: Dictionary) -> void:
	if player_index < 0 or typeof(run_data_state) != TYPE_DICTIONARY:
		return
	if player_index >= RunData.players_data.size() or RunData.players_data[player_index] == null:
		return
	var player_data = RunData.players_data[player_index]
	_append_missing_serialized_inventory_placeholders(player_data, "items", run_data_state.get("items", []), "item")
	_append_missing_serialized_inventory_placeholders(player_data, "weapons", run_data_state.get("weapons", []), "weapon")


func _append_missing_serialized_inventory_placeholders(player_data, list_prop: String, serialized_entries, data_type: String) -> void:
	if player_data == null or typeof(serialized_entries) != TYPE_ARRAY:
		return
	var current_entries = _safe_get(player_data, list_prop, [])
	if typeof(current_entries) != TYPE_ARRAY:
		return
	var existing_ids = {}
	for existing in current_entries:
		var existing_id = str(_safe_get(existing, "my_id", ""))
		if existing_id != "":
			existing_ids[existing_id] = true
	for serialized in serialized_entries:
		if typeof(serialized) != TYPE_DICTIONARY:
			continue
		var item_id = str(serialized.get("my_id", ""))
		if item_id == "" or existing_ids.has(item_id):
			continue
		if _serialized_inventory_entry_exists_locally(serialized, data_type):
			continue
		var placeholder = _get_cached_missing_host_item_placeholder(serialized, data_type)
		if placeholder == null:
			continue
		current_entries.append(placeholder)
		existing_ids[item_id] = true
	player_data.set(list_prop, current_entries)


func _serialized_inventory_entry_exists_locally(serialized: Dictionary, data_type: String) -> bool:
	var item_id = str(serialized.get("my_id", ""))
	if item_id == "":
		return true
	if data_type == "weapon":
		return ItemService.get_element_safe(ItemService.weapons, item_id) != null
	return ItemService.get_element_safe(ItemService.items, item_id) != null or ItemService.get_element_safe(ItemService.characters, item_id) != null


func _get_cached_missing_host_item_placeholder(serialized: Dictionary, data_type: String):
	var state = _normalize_serialized_inventory_placeholder_state(serialized, data_type)
	var key = data_type + ":" + to_json(state)
	if _missing_host_item_placeholder_cache.has(key):
		var cached = _missing_host_item_placeholder_cache[key]
		return cached.duplicate() if cached != null and cached.has_method("duplicate") else cached
	var placeholder = _make_missing_host_item_placeholder(state, data_type)
	if placeholder != null:
		_missing_host_item_placeholder_cache[key] = placeholder
		return placeholder.duplicate() if placeholder.has_method("duplicate") else placeholder
	return null


func _normalize_serialized_inventory_placeholder_state(serialized: Dictionary, data_type: String) -> Dictionary:
	var item_id = str(serialized.get("my_id", ""))
	var item_hash = int(serialized.get("my_id_hash", 0))
	if item_hash == 0 and item_id != "":
		item_hash = int(Keys.generate_hash(item_id))
	var state = {
		"type": data_type,
		"my_id": item_id,
		"my_id_hash": item_hash,
		"resource_path": str(serialized.get("resource_path", "")),
		"value": int(serialized.get("value", 0)),
		"tier": int(serialized.get("tier", -1))
	}
	if data_type == "weapon":
		var weapon_id = str(serialized.get("weapon_id", item_id))
		var weapon_hash = int(serialized.get("weapon_id_hash", 0))
		if weapon_hash == 0 and weapon_id != "":
			weapon_hash = int(Keys.generate_hash(weapon_id))
		state["weapon_id"] = weapon_id
		state["weapon_id_hash"] = weapon_hash
	return state


func _should_preserve_client_local_player_runtime_state(player_index: int) -> bool:
	if _is_game_host():
		return false
	return player_index >= 0 and player_index == _get_local_client_player_index()


func _poll_progression_page_focus_and_state() -> void:
	if _is_game_start_guard_active():
		return
	var ui = _find_progression_ui(true)
	if not _is_valid_progression_ui_visible(ui):
		_client_progression_intercept_container_id = 0
		_last_local_run_page_focus_key.clear()
		_last_progression_options_processed_key = ""
		return

	if _is_game_host():
		var host_player_indices = _get_host_local_player_indices()
		_configure_online_focus_emulator_input_owners(host_player_indices, "progression_host")
		_ensure_host_progression_ban_button_connections(ui)
		var player_count = _get_run_player_count()
		for player_index in range(player_count):
			_queue_progression_state_if_changed(player_index, ui)
		# Host-origin focus is emitted only for Host-local players. Remote player focus
		# is received from that client; rebroadcasting it as Host-origin causes jitter.
		for host_player_index in host_player_indices:
			_queue_progression_focus_if_changed(int(host_player_index), ui)
		return

	var local_player_index = _get_local_client_player_index()
	if local_player_index < 0:
		return
	_configure_online_focus_emulator_input_owner(local_player_index, "progression_client")
	var container = _get_progression_player_container(ui, local_player_index)
	if not _is_live_ref(container):
		return
	_install_client_progression_press_intercept(container, local_player_index)
	_ensure_local_progression_focus(container, local_player_index, "poll")
	_queue_progression_focus_if_changed(local_player_index, ui)


func _ensure_host_progression_ban_button_connections(ui: Node) -> void:
	if not _is_live_ref(ui):
		return
	if not _is_game_host():
		return
	if RunData == null or not bool(RunData.get("is_coop_run")):
		return
	var player_count = _get_run_player_count()
	for player_index in range(player_count):
		var container = _get_progression_player_container(ui, player_index)
		if not _is_live_ref(container):
			continue
		var ban_button = _safe_get(container, "_ban_button", null)
		if not _is_live_ref(ban_button):
			continue
		# CoopUpgradesUIPlayerContainer.tscn wires Take/Recycle but not the Ban button.
		# Clients install their own intercept; the Host must keep the vanilla local handler.
		if container.has_method("_on_BanButton_pressed") and not ban_button.is_connected("pressed", container, "_on_BanButton_pressed"):
			ban_button.connect("pressed", container, "_on_BanButton_pressed")
		if container.has_method("_on_BanButton_button_up") and not ban_button.is_connected("button_up", container, "_on_BanButton_button_up"):
			ban_button.connect("button_up", container, "_on_BanButton_button_up")


func _queue_progression_state_if_changed(player_index: int, ui: Node = null) -> void:
	var visible = _build_progression_visible_option(player_index, ui)
	if visible.empty():
		return
	var mode = str(visible.get("mode", "none"))
	if mode == "none":
		return
	var key = str(player_index) + ":" + to_json(visible)
	if str(_last_local_run_page_state_key_by_player.get(player_index, "")) == key:
		return
	_last_local_run_page_state_key_by_player[player_index] = key
	var msg = {
		"msg_type": "run_page_action_sync",
		"action_type": "upgrade_state",
		"screen": "progression",
		"player_index": player_index,
		"state_after": visible,
		"host_state_after": visible
	}
	var all_states = _build_all_progression_visible_options(ui)
	if not all_states.empty():
		msg["host_states_after"] = all_states
	_queue_local_run_page_action(msg)


func _queue_progression_focus_if_changed(player_index: int, ui: Node = null) -> void:
	if not _is_valid_progression_ui_visible(ui):
		ui = _find_progression_ui(true)
	if not _is_valid_progression_ui_visible(ui):
		return
	var container = _get_progression_player_container(ui, player_index)
	if not _is_live_ref(container):
		return
	var target = _get_current_progression_focus_target(container, player_index)
	if target == "":
		return
	var visible = _build_progression_visible_option(player_index, ui)
	var key = str(player_index) + ":" + target + ":" + to_json(visible)
	if key == str(_last_local_run_page_focus_key.get(player_index, "")):
		return
	_last_local_run_page_focus_key[player_index] = key
	var msg = {
		"msg_type": "run_page_action_sync",
		"action_type": "upgrade_focus",
		"screen": "progression_upgrade",
		"player_index": player_index,
		"target": target,
		"state_key": to_json(visible)
	}
	var upgrade_data = _get_upgrade_data_for_progression_target(container, target)
	if upgrade_data != null:
		msg["upgrade_id_hash"] = int(_safe_get(upgrade_data, "upgrade_id_hash", _safe_get(upgrade_data, "my_id_hash", 0)))
		msg["item_id_hash"] = int(_safe_get(upgrade_data, "my_id_hash", 0))
	_queue_local_run_page_action(msg)


func _queue_local_run_page_action(message: Dictionary) -> void:
	if typeof(message) != TYPE_DICTIONARY or message.empty():
		return
	var action_type = str(message.get("action_type", ""))
	if _is_game_start_guard_active() and _is_guarded_run_page_action(action_type):
		return
	_ensure_run_page_action_identity(message)
	_queued_local_run_page_action_messages.append(message)


func _ensure_run_page_action_identity(message: Dictionary) -> void:
	if not message.has("origin_steam_id") or str(message.get("origin_steam_id", "")) == "":
		message["origin_steam_id"] = _get_self_steam_id()
	var origin = str(message.get("origin_steam_id", ""))
	if origin == "":
		origin = "local"
		message["origin_steam_id"] = origin
	var action_type = str(message.get("action_type", ""))
	if not _is_mutating_run_page_action(action_type):
		return
	if not message.has("action_id") or str(message.get("action_id", "")) == "":
		message["action_id"] = origin + ":" + str(_next_local_run_page_action_seq) + ":" + action_type
		_next_local_run_page_action_seq += 1


func _install_client_progression_press_intercept(container: Node, player_index: int) -> void:
	if _is_game_host() or _applying_remote_run_page_action:
		return
	if not _is_live_ref(container):
		return
	var container_id = container.get_instance_id()
	if _client_progression_intercept_container_id == container_id:
		return
	_client_progression_intercept_container_id = container_id

	var upgrade_uis = []
	if container.has_method("_get_upgrade_uis"):
		upgrade_uis = container._get_upgrade_uis()
	for i in range(upgrade_uis.size()):
		var upgrade_ui = upgrade_uis[i]
		if not _is_live_ref(upgrade_ui):
			continue
		if upgrade_ui.is_connected("choose_button_pressed", container, "_on_choose_button_pressed"):
			upgrade_ui.disconnect("choose_button_pressed", container, "_on_choose_button_pressed")
		if not upgrade_ui.is_connected("choose_button_pressed", self, "_on_client_upgrade_choose_button_pressed"):
			upgrade_ui.connect("choose_button_pressed", self, "_on_client_upgrade_choose_button_pressed", [player_index, i])

	var reroll_button = _safe_get(container, "_reroll_button", null)
	if _is_live_ref(reroll_button):
		if reroll_button.is_connected("pressed", container, "_on_RerollButton_pressed"):
			reroll_button.disconnect("pressed", container, "_on_RerollButton_pressed")
		if not reroll_button.is_connected("pressed", self, "_on_client_upgrade_reroll_pressed"):
			reroll_button.connect("pressed", self, "_on_client_upgrade_reroll_pressed", [player_index])

	# Item-box pages use the same UpgradesUIPlayerContainer as level-up pages.
	# On clients, do not let Take/Recycle/Ban mutate local RunData; send intent to Host.
	var take_button = _safe_get(container, "_take_button", null)
	if _is_live_ref(take_button):
		if take_button.is_connected("pressed", container, "_on_TakeButton_pressed"):
			take_button.disconnect("pressed", container, "_on_TakeButton_pressed")
		if not take_button.is_connected("pressed", self, "_on_client_item_box_take_pressed"):
			take_button.connect("pressed", self, "_on_client_item_box_take_pressed", [player_index])

	var discard_button = _safe_get(container, "_discard_button", null)
	if _is_live_ref(discard_button):
		if discard_button.is_connected("pressed", container, "_on_DiscardButton_pressed"):
			discard_button.disconnect("pressed", container, "_on_DiscardButton_pressed")
		if not discard_button.is_connected("pressed", self, "_on_client_item_box_discard_pressed"):
			discard_button.connect("pressed", self, "_on_client_item_box_discard_pressed", [player_index])

	var ban_button = _safe_get(container, "_ban_button", null)
	if _is_live_ref(ban_button):
		if ban_button.is_connected("pressed", container, "_on_BanButton_pressed"):
			ban_button.disconnect("pressed", container, "_on_BanButton_pressed")
		if not ban_button.is_connected("pressed", self, "_on_client_item_box_ban_pressed"):
			ban_button.connect("pressed", self, "_on_client_item_box_ban_pressed", [player_index])



func _ensure_local_progression_focus(container: Node, player_index: int, reason: String = "") -> void:
	if _is_game_host() or _applying_remote_run_page_action:
		return
	if player_index != _get_local_client_player_index():
		return
	if not _is_live_ref(container):
		return

	var focus_emulator = _safe_get(container, "focus_emulator", null)
	if not _is_live_ref(focus_emulator):
		focus_emulator = Utils.get_focus_emulator(player_index)
	if not _is_live_ref(focus_emulator):
		return

	# CoopUpgradesUIPlayerContainer.finish() sets focus_emulator.player_index = -1.
	# When Host later shows this client's upgrade/card page through serialized state,
	# vanilla focus() is not called on the client, so the FocusEmulator can stay inactive.
	if _has_property(focus_emulator, "player_index") and int(_safe_get(focus_emulator, "player_index", -1)) != player_index:
		focus_emulator.set("player_index", player_index)
	if focus_emulator is CanvasItem:
		focus_emulator.show()
	focus_emulator.set_process(true)
	# Keep the vanilla FocusEmulator active for the local progression page.
	focus_emulator.set_process_input(true)

	var current = _safe_get(focus_emulator, "focused_control", null)
	if _is_live_ref(current) and current is Control and current.is_visible_in_tree() and _safe_node_is_parent_of(container, current):
		return

	var target = _get_default_progression_focus_control(container)
	if not _is_live_ref(target):
		return
	Utils.focus_player_control(target, player_index, focus_emulator)
	if _has_property(container, "_resume_upgrade_control_focus"):
		container.set("_resume_upgrade_control_focus", target)


func _get_default_progression_focus_control(container: Node):
	if not _is_live_ref(container):
		return null

	var items_container = _safe_get(container, "_items_container", null)
	if _is_canvas_visible(items_container):
		var take_button = _safe_get(container, "_take_button", null)
		if _is_live_ref(take_button) and take_button is Control and take_button.is_visible_in_tree():
			return take_button
		var discard_button = _safe_get(container, "_discard_button", null)
		if _is_live_ref(discard_button) and discard_button is Control and discard_button.is_visible_in_tree():
			return discard_button

	var upgrades_container = _safe_get(container, "_upgrades_container", null)
	if _is_canvas_visible(upgrades_container):
		var resume = _safe_get(container, "_resume_upgrade_control_focus", null)
		if _is_live_ref(resume) and resume is Control and resume.is_visible_in_tree() and _safe_node_is_parent_of(container, resume):
			return resume
		var upgrade_uis = []
		if container.has_method("_get_upgrade_uis"):
			upgrade_uis = container._get_upgrade_uis()
		# Match vanilla CoopUpgradesUIPlayerContainer.focus(): prefer UpgradeUI2 if visible.
		if upgrade_uis.size() > 1:
			var upgrade_ui_2 = upgrade_uis[1]
			if _is_live_ref(upgrade_ui_2) and (not (upgrade_ui_2 is CanvasItem) or bool(upgrade_ui_2.visible)):
				var button_2 = _safe_get(upgrade_ui_2, "button", null)
				if _is_live_ref(button_2) and button_2 is Control and button_2.is_visible_in_tree():
					return button_2
		for upgrade_ui in upgrade_uis:
			if not _is_live_ref(upgrade_ui):
				continue
			if upgrade_ui is CanvasItem and not bool(upgrade_ui.visible):
				continue
			var button = _safe_get(upgrade_ui, "button", null)
			if _is_live_ref(button) and button is Control and button.is_visible_in_tree():
				return button

	var reroll_button = _safe_get(container, "_reroll_button", null)
	if _is_live_ref(reroll_button) and reroll_button is Control and reroll_button.is_visible_in_tree():
		return reroll_button
	return null


func _on_client_upgrade_choose_button_pressed(upgrade_data: UpgradeData, player_index: int, upgrade_index: int) -> void:
	if _applying_remote_run_page_action:
		return
	if _is_game_host() or player_index != _get_local_client_player_index():
		return
	var visible = _build_progression_visible_option(player_index)
	var msg = {
		"msg_type": "run_page_action_sync",
		"action_type": "upgrade_select",
		"screen": "progression_upgrade",
		"player_index": player_index,
		"target": "upgrade_" + str(upgrade_index),
		"upgrade_index": upgrade_index,
		"upgrade_id_hash": int(_safe_get(upgrade_data, "upgrade_id_hash", _safe_get(upgrade_data, "my_id_hash", 0))),
		"item_id_hash": int(_safe_get(upgrade_data, "my_id_hash", 0)),
		"level": int(visible.get("level", 0)),
		"state_key": to_json(visible)
	}
	_queue_local_run_page_action(msg)
	_mark_client_progression_button_pressed(player_index)
	_client_reduce_local_progression_marker(player_index, "upgrade", int(visible.get("level", 0)))


func _on_client_upgrade_reroll_pressed(player_index: int) -> void:
	if _applying_remote_run_page_action:
		return
	if _is_game_host() or player_index != _get_local_client_player_index():
		return
	var visible = _build_progression_visible_option(player_index)
	_queue_local_run_page_action({
		"msg_type": "run_page_action_sync",
		"action_type": "upgrade_reroll",
		"screen": "progression_upgrade",
		"player_index": player_index,
		"level": int(visible.get("level", 0)),
		"reroll_count": int(visible.get("reroll_count", 0)),
		"state_key": to_json(visible)
	})


func _on_client_item_box_take_pressed(player_index: int) -> void:
	_queue_client_item_box_action("item_box_take", player_index)


func _on_client_item_box_discard_pressed(player_index: int) -> void:
	_queue_client_item_box_action("item_box_discard", player_index)


func _on_client_item_box_ban_pressed(player_index: int) -> void:
	_queue_client_item_box_action("item_box_ban", player_index)


func _queue_client_item_box_action(action_type: String, player_index: int) -> void:
	if _applying_remote_run_page_action:
		return
	if _is_game_host() or player_index != _get_local_client_player_index():
		return
	var visible = _build_progression_visible_option(player_index)
	if str(visible.get("mode", "")) != "item_box":
		return
	_queue_local_run_page_action({
		"msg_type": "run_page_action_sync",
		"action_type": action_type,
		"screen": "progression_item_box",
		"player_index": player_index,
		"item": visible.get("item_data", {}),
		"consumable": visible.get("consumable_data", {}),
		"item_id_hash": int(_get_dict_or_empty(visible.get("item_data", {})).get("my_id_hash", 0)),
		"state_key": to_json(visible)
	})
	_mark_client_progression_button_pressed(player_index)
	_client_reduce_local_progression_marker(player_index, "item_box", 0)


func _mark_client_progression_button_pressed(player_index: int) -> void:
	if _is_game_host():
		return
	var ui = _find_progression_ui()
	if not _is_live_ref(ui):
		return
	var container = _get_progression_player_container(ui, player_index)
	if not _is_live_ref(container):
		return
	if _has_property(container, "_button_pressed"):
		container.set("_button_pressed", true)
	var timer = _safe_get(container, "_button_delay_timer", null)
	if _is_live_ref(timer) and timer.has_method("start"):
		timer.start()


func _client_reduce_local_progression_marker(player_index: int, marker_type: String, level_hint: int = 0) -> void:
	if _is_game_host():
		return
	var ui = _find_progression_ui()
	if not _is_live_ref(ui):
		return
	var container = _get_progression_player_container(ui, player_index)
	if not _is_live_ref(container):
		return
	var holder = _safe_get(container, "_things_to_process_container", null)
	if not _is_live_ref(holder):
		holder = _get_things_to_process_holder_from_main(player_index)
	if not _is_live_ref(holder):
		return
	if marker_type == "upgrade":
		var upgrade_list = _safe_get(holder, "upgrades", null)
		if not _is_live_ref(upgrade_list):
			return
		var current = _get_ui_marker_count(upgrade_list)
		if current <= 0:
			return
		_rebuild_upgrade_marker_count(upgrade_list, current - 1, level_hint)
	elif marker_type == "item_box":
		var consumable_list = _safe_get(holder, "consumables", null)
		if not _is_live_ref(consumable_list):
			return
		var counts = _get_consumable_marker_counts(consumable_list)
		var consumable_data = _safe_get(container, "_consumable_data", null)
		var kind = _get_consumable_marker_kind(consumable_data)
		if kind == "legendary_item_box":
			if int(counts.get("legendary_item_box", 0)) <= 0:
				return
			counts["legendary_item_box"] = int(counts["legendary_item_box"]) - 1
		else:
			if int(counts.get("item_box", 0)) <= 0:
				return
			counts["item_box"] = int(counts["item_box"]) - 1
		_rebuild_consumable_marker_counts(consumable_list, int(counts.get("item_box", 0)), int(counts.get("legendary_item_box", 0)))


func _get_things_to_process_holder_from_main(player_index: int):
	var main = get_tree().current_scene
	if not _is_live_ref(main):
		return null
	var containers = _safe_get(main, "_things_to_process_player_containers", [])
	if typeof(containers) != TYPE_ARRAY or player_index < 0 or player_index >= containers.size():
		return null
	return containers[player_index]


func _get_ui_marker_count(list_node: Node) -> int:
	if not _is_live_ref(list_node):
		return 0
	var elements = _safe_get(list_node, "_elements", [])
	if typeof(elements) == TYPE_ARRAY:
		return elements.size()
	return list_node.get_child_count()


func _rebuild_upgrade_marker_count(upgrade_list: Node, desired_count: int, level_hint: int = 0) -> void:
	_clear_ui_marker_list(upgrade_list)
	if not _is_live_ref(upgrade_list) or desired_count <= 0:
		return
	var icon = ItemService.get_icon(Keys.icon_upgrade_to_process_hash)
	for _i in range(desired_count):
		if upgrade_list.has_method("add_element"):
			upgrade_list.add_element(icon, level_hint)


func _resolve_consumable_data_by_kind(consumable_kind: String):
	match consumable_kind:
		"legendary_item_box":
			return ItemService.get_element(ItemService.consumables, int(Keys.consumable_legendary_item_box_hash))
		"item_box":
			return ItemService.get_element(ItemService.consumables, int(Keys.consumable_item_box_hash))
		_:
			return null


func _rebuild_consumable_marker_counts(consumable_list: Node, item_box_count: int, legendary_item_box_count: int) -> void:
	_clear_ui_marker_list(consumable_list)
	if not _is_live_ref(consumable_list):
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


func _clear_ui_marker_list(list_node: Node) -> void:
	if not _is_live_ref(list_node):
		return
	if _has_property(list_node, "_elements"):
		list_node.set("_elements", [])
	for child in list_node.get_children():
		if child is Node:
			list_node.remove_child(child)
			child.queue_free()


func _get_consumable_marker_counts(list_node: Node) -> Dictionary:
	var counts = {"item_box": 0, "legendary_item_box": 0}
	if not _is_live_ref(list_node):
		return counts
	var elements = _safe_get(list_node, "_elements", [])
	if typeof(elements) == TYPE_ARRAY:
		for item_data in elements:
			var kind = _get_consumable_marker_kind(item_data)
			if kind == "legendary_item_box":
				counts["legendary_item_box"] = int(counts["legendary_item_box"]) + 1
			else:
				counts["item_box"] = int(counts["item_box"]) + 1
		return counts
	for child in list_node.get_children():
		var item_data = _safe_get(child, "item_data", null) if child != null else null
		var kind = _get_consumable_marker_kind(item_data)
		if kind == "legendary_item_box":
			counts["legendary_item_box"] = int(counts["legendary_item_box"]) + 1
		else:
			counts["item_box"] = int(counts["item_box"]) + 1
	return counts


func _get_consumable_marker_kind(item_data) -> String:
	if item_data == null:
		return "item_box"
	var id_hash = int(_safe_get(item_data, "my_id_hash", 0))
	var my_id = str(_safe_get(item_data, "my_id", ""))
	if id_hash == int(Keys.consumable_legendary_item_box_hash) or my_id == "consumable_legendary_item_box":
		return "legendary_item_box"
	return "item_box"


func _apply_progression_item_box_action(player_index: int, message: Dictionary, kind: String) -> bool:
	var ui = _find_progression_ui()
	if not _is_valid_progression_ui_visible(ui):
		return false
	var container = _get_progression_player_container(ui, player_index)
	if not _is_live_ref(container):
		return false
	var current_mode = str(_build_progression_visible_option(player_index).get("mode", ""))
	if current_mode != "item_box":
		return false
	var current_item = _safe_get(container, "_item_data", null)
	var wanted_hash = int(message.get("item_id_hash", 0))
	if wanted_hash != 0 and current_item != null and int(_safe_get(current_item, "my_id_hash", 0)) != wanted_hash:
		return false
	if kind == "take" and container.has_method("_on_TakeButton_pressed"):
		container._on_TakeButton_pressed()
		return true
	if kind == "discard" and container.has_method("_on_DiscardButton_pressed"):
		container._on_DiscardButton_pressed()
		return true
	if kind == "ban" and container.has_method("_on_BanButton_pressed"):
		container._on_BanButton_pressed()
		return true
	return false


func _apply_progression_focus_action(player_index: int, message: Dictionary) -> bool:
	var ui = _find_progression_ui()
	if not _is_valid_progression_ui_visible(ui):
		return false
	var container = _get_progression_player_container(ui, player_index)
	if not _is_live_ref(container):
		return false
	var target = str(message.get("target", ""))
	var control = _get_control_for_progression_target(container, target)
	if not _is_live_ref(control):
		return false
	if target.begins_with("upgrade_") and _has_property(container, "_resume_upgrade_control_focus"):
		container.set("_resume_upgrade_control_focus", control)
	var focus_emulator = _safe_get(container, "focus_emulator", null)
	if not _is_live_ref(focus_emulator):
		focus_emulator = Utils.get_focus_emulator(player_index)
	if _is_live_ref(focus_emulator):
		Utils.focus_player_control(control, player_index, focus_emulator)
	else:
		control.call_deferred("grab_focus")
	return true


func _apply_progression_select_action(player_index: int, message: Dictionary) -> bool:
	var ui = _find_progression_ui()
	if not _is_valid_progression_ui_visible(ui):
		return false
	var container = _get_progression_player_container(ui, player_index)
	if not _is_live_ref(container):
		return false
	var upgrade_data = _get_upgrade_data_from_select_action(container, message)
	if upgrade_data == null:
		return false
	_apply_progression_focus_action(player_index, message)
	if container.has_method("_on_choose_button_pressed"):
		container._on_choose_button_pressed(upgrade_data)
		return true
	return false


func _apply_progression_reroll_action(player_index: int, message: Dictionary) -> bool:
	var ui = _find_progression_ui()
	if not _is_valid_progression_ui_visible(ui):
		return false
	var container = _get_progression_player_container(ui, player_index)
	if not _is_live_ref(container):
		return false
	if container.has_method("_on_RerollButton_pressed"):
		container._on_RerollButton_pressed()
		return true
	return false


func _get_upgrade_data_from_select_action(container: Node, message: Dictionary):
	var wanted_upgrade_hash = int(message.get("upgrade_id_hash", 0))
	var wanted_item_hash = int(message.get("item_id_hash", 0))
	var upgrade_uis = []
	if container.has_method("_get_upgrade_uis"):
		upgrade_uis = container._get_upgrade_uis()
	for upgrade_ui in upgrade_uis:
		if not _is_live_ref(upgrade_ui):
			continue
		if upgrade_ui is CanvasItem and not bool(upgrade_ui.visible):
			continue
		var data = _safe_get(upgrade_ui, "upgrade_data", null)
		if data == null:
			continue
		var data_upgrade_hash = int(_safe_get(data, "upgrade_id_hash", 0))
		var data_item_hash = int(_safe_get(data, "my_id_hash", 0))
		if wanted_upgrade_hash != 0 and data_upgrade_hash == wanted_upgrade_hash:
			return data
		if wanted_item_hash != 0 and data_item_hash == wanted_item_hash:
			return data
	if wanted_upgrade_hash != 0 or wanted_item_hash != 0:
		return null
	var target = str(message.get("target", ""))
	var fallback_data = _get_upgrade_data_for_progression_target(container, target)
	return fallback_data


func _get_current_progression_focus_target(container: Node, player_index: int) -> String:
	var focus_emulator = _safe_get(container, "focus_emulator", null)
	if not _is_live_ref(focus_emulator):
		focus_emulator = Utils.get_focus_emulator(player_index)
	if not _is_live_ref(focus_emulator):
		return ""
	var focused = _safe_get(focus_emulator, "focused_control", null)
	if not _is_live_ref(focused):
		return ""
	var reroll_button = _safe_get(container, "_reroll_button", null)
	if _is_live_ref(reroll_button) and focused == reroll_button:
		return "reroll"
	var upgrade_uis = []
	if container.has_method("_get_upgrade_uis"):
		upgrade_uis = container._get_upgrade_uis()
	for i in range(upgrade_uis.size()):
		var upgrade_ui = upgrade_uis[i]
		if not _is_live_ref(upgrade_ui):
			continue
		var button = _safe_get(upgrade_ui, "button", null)
		if _is_live_ref(button) and focused == button:
			return "upgrade_" + str(i)
	return ""


func _get_control_for_progression_target(container: Node, target: String):
	if target == "reroll":
		return _safe_get(container, "_reroll_button", null)
	if target.begins_with("upgrade_"):
		var raw = target.substr(String("upgrade_").length(), target.length())
		var idx = int(raw)
		var upgrade_uis = []
		if container.has_method("_get_upgrade_uis"):
			upgrade_uis = container._get_upgrade_uis()
		if idx >= 0 and idx < upgrade_uis.size():
			return _safe_get(upgrade_uis[idx], "button", null)
	return null


func _get_upgrade_data_for_progression_target(container: Node, target: String):
	if not target.begins_with("upgrade_"):
		return null
	var raw = target.substr(String("upgrade_").length(), target.length())
	var idx = int(raw)
	var upgrade_uis = []
	if container.has_method("_get_upgrade_uis"):
		upgrade_uis = container._get_upgrade_uis()
	if idx < 0 or idx >= upgrade_uis.size():
		return null
	return _safe_get(upgrade_uis[idx], "upgrade_data", null)


func _apply_progression_visible_option_to_ui(player_index: int, visible: Dictionary) -> bool:
	if typeof(visible) != TYPE_DICTIONARY or visible.empty():
		return false
	var ui = _find_progression_ui()
	if not _is_live_ref(ui):
		return false
	var container = _get_progression_player_container(ui, player_index)
	if not _is_live_ref(container):
		return false
	var mode = str(visible.get("mode", "none"))
	if mode == "upgrade":
		_prepare_progression_ui_for_state(ui, container, player_index, visible)
		var ok = _apply_upgrade_options_to_progression_container(container, player_index, visible)
		if ok and not _is_game_host() and player_index == _get_local_client_player_index():
			_install_client_progression_press_intercept(container, player_index)
			_ensure_local_progression_focus(container, player_index, "apply_upgrade_state")
		return ok
	elif mode == "item_box":
		_prepare_progression_ui_for_state(ui, container, player_index, visible)
		var item_ok = _apply_item_box_option_to_progression_container(container, player_index, visible)
		if item_ok and not _is_game_host() and player_index == _get_local_client_player_index():
			_install_client_progression_press_intercept(container, player_index)
			_ensure_local_progression_focus(container, player_index, "apply_item_box_state")
		return item_ok
	elif mode == "hidden" or mode == "idle" or mode == "none":
		return _apply_progression_idle_state(ui, container, player_index)
	return false


func _prepare_progression_ui_for_state(ui: Node, container: Node, player_index: int, visible: Dictionary) -> void:
	if ui is CanvasItem:
		ui.show()
	_last_progression_options_processed_key = ""
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


func _set_progression_checkmark_visible(container: Node, visible: bool) -> void:
	if not _is_live_ref(container):
		return
	var checkmark_group = _safe_get(container, "_checkmark_group", null)
	if not _is_live_ref(checkmark_group) and container.has_method("get_node_or_null"):
		checkmark_group = container.get_node_or_null("%CheckmarkGroup")
	if not _is_live_ref(checkmark_group) and container.has_method("get_node_or_null"):
		checkmark_group = container.get_node_or_null("CheckmarkGroup")
	if not _is_live_ref(checkmark_group):
		return
	if visible:
		checkmark_group.show()
	else:
		checkmark_group.hide()


func _apply_upgrade_options_to_progression_container(container: Node, player_index: int, visible: Dictionary) -> bool:
	_set_progression_checkmark_visible(container, false)
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
		if not _is_live_ref(upgrade_ui):
			continue
		if upgrade_ui is CanvasItem:
			upgrade_ui.visible = i < upgrades.size()
		if i < upgrades.size() and upgrade_ui.has_method("set_upgrade"):
			upgrade_ui.set_upgrade(upgrades[i], player_index)
	var reroll_button = container.get("_reroll_button")
	if _is_live_ref(reroll_button) and reroll_button.has_method("init"):
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


func _apply_item_box_option_to_progression_container(container: Node, player_index: int, visible: Dictionary) -> bool:
	_set_progression_checkmark_visible(container, false)
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


func _apply_progression_idle_state(ui: Node, container: Node, player_index: int) -> bool:
	var choosing = ui.get("_player_is_choosing")
	if typeof(choosing) == TYPE_ARRAY and player_index >= 0 and player_index < choosing.size():
		choosing[player_index] = false
		ui.set("_player_is_choosing", choosing)
	var showing = ui.get("_showing_option")
	if typeof(showing) == TYPE_ARRAY and player_index >= 0 and player_index < showing.size():
		showing[player_index] = null
		ui.set("_showing_option", showing)
	if container.has_method("finish"):
		container.finish()
	_maybe_emit_progression_options_processed_if_complete(ui)
	return true


func _maybe_emit_progression_options_processed_if_complete(ui: Node) -> void:
	if _is_game_host():
		return
	if not _is_live_ref(ui):
		return
	var choosing = ui.get("_player_is_choosing")
	if typeof(choosing) != TYPE_ARRAY:
		return
	var player_count = _get_run_player_count()
	for i in range(player_count):
		if i < choosing.size() and bool(choosing[i]):
			return
	var key = str(ui.get_instance_id()) + ":" + str(RunData.current_wave)
	if key == _last_progression_options_processed_key:
		return
	_last_progression_options_processed_key = key
	call_deferred("_emit_progression_options_processed_safely", ui.get_instance_id(), int(RunData.current_wave))


func _emit_progression_options_processed_safely(ui_instance_id: int, wave: int) -> void:
	var ui = instance_from_id(ui_instance_id)
	if not _is_live_ref(ui):
		return
	_sanitize_current_main_pool("before_progression_options_processed")
	if not _is_live_ref(ui):
		return
	ui.emit_signal("options_processed")


func _sanitize_current_main_pool(reason: String) -> void:
	var scene = get_tree().current_scene
	if not _is_live_ref(scene):
		return
	var pool_dict = scene.get("_pool")
	if typeof(pool_dict) != TYPE_DICTIONARY:
		return
	var removed_invalid = 0
	var removed_queued = 0
	for key in pool_dict.keys():
		var pool = pool_dict[key]
		if typeof(pool) != TYPE_ARRAY:
			continue
		var kept = []
		for node in pool:
			if not is_instance_valid(node):
				removed_invalid += 1
				continue
			if node is Node and node.is_queued_for_deletion():
				removed_queued += 1
				continue
			kept.append(node)
		pool_dict[key] = kept
	scene.set("_pool", pool_dict)
	if removed_invalid > 0 or removed_queued > 0:
		pass


func _build_progression_visible_option(player_index: int, ui: Node = null) -> Dictionary:
	if not _is_live_ref(ui):
		ui = _find_progression_ui(true)
	if not _is_live_ref(ui):
		return {"mode": "none"}
	if ui is CanvasItem and not bool(ui.visible):
		return {"mode": "hidden", "player_index": player_index}
	var choosing = ui.get("_player_is_choosing")
	if typeof(choosing) == TYPE_ARRAY and player_index < choosing.size() and not bool(choosing[player_index]):
		return {"mode": "idle", "player_index": player_index}
	var container = _get_progression_player_container(ui, player_index)
	if not _is_live_ref(container):
		return {"mode": "none", "player_index": player_index}
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
			if not _is_live_ref(upgrade_ui):
				continue
			if upgrade_ui is CanvasItem and not bool(upgrade_ui.visible):
				continue
			upgrades.append(_serialize_item_parent_data(upgrade_ui.get("upgrade_data")))
		return {
			"mode": "upgrade",
			"player_index": player_index,
			"level": int(_safe_get(container, "_level", 0)),
			"reroll_price": int(_safe_get(container, "_reroll_price", 0)),
			"reroll_count": int(_safe_get(container, "_reroll_count", 0)),
			"reroll_discount": int(_safe_get(container, "_reroll_discount", 0)),
			"upgrades": upgrades
		}
	return {"mode": "none", "player_index": player_index}


func _serialize_item_parent_identity_for_action(data) -> Dictionary:
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
		"my_id": str(_safe_get(data, "my_id", "")),
		"my_id_hash": int(_safe_get(data, "my_id_hash", Keys.empty_hash)),
		"resource_path": _get_resource_path(data),
		"value": int(_safe_get(data, "value", 0)),
		"tier": int(_safe_get(data, "tier", -1)),
		"is_cursed": bool(_safe_get(data, "is_cursed", false)),
		"curse_factor": float(_safe_get(data, "curse_factor", 0.0))
	}
	if data is WeaponData:
		result["weapon_id"] = str(_safe_get(data, "weapon_id", ""))
		result["weapon_id_hash"] = int(_safe_get(data, "weapon_id_hash", Keys.empty_hash))
	if data is UpgradeData:
		result["upgrade_id"] = str(_safe_get(data, "upgrade_id", ""))
		result["upgrade_id_hash"] = int(_safe_get(data, "upgrade_id_hash", Keys.empty_hash))
	return result


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
		"my_id": str(_safe_get(data, "my_id", "")),
		"my_id_hash": int(_safe_get(data, "my_id_hash", Keys.empty_hash)),
		"resource_path": _get_resource_path(data),
		"value": int(_safe_get(data, "value", 0)),
		"tier": int(_safe_get(data, "tier", -1)),
		"is_cursed": bool(_safe_get(data, "is_cursed", false)),
		"curse_factor": float(_safe_get(data, "curse_factor", 0.0))
	}
	# Cursed entries are runtime duplicates with boosted effects, so keep their full
	# payload. Do not serialize every normal shop/action WeaponData unconditionally:
	# vanilla Effect.serialize() does not include some weapon-effect subclass fields
	# such as WeaponGainStatForEveryStatEffect.increased_stat_name. Re-merging that
	# incomplete payload corrupts Captain's Sword-style weapons and can crash in
	# WeaponService.init_base_stats() when entering/rendering the shop.
	if bool(result["is_cursed"]) and data.has_method("serialize"):
		result["serialized_data"] = data.serialize()
	if data is WeaponData:
		result["weapon_id"] = str(_safe_get(data, "weapon_id", ""))
		result["weapon_id_hash"] = int(_safe_get(data, "weapon_id_hash", Keys.empty_hash))
		result["dmg_dealt_last_wave"] = int(_safe_get(data, "dmg_dealt_last_wave", 0))
		result["tracked_value"] = int(_safe_get(data, "tracked_value", 0))
	if data is UpgradeData:
		result["upgrade_id"] = str(_safe_get(data, "upgrade_id", ""))
		result["upgrade_id_hash"] = int(_safe_get(data, "upgrade_id_hash", Keys.empty_hash))
	return result


func _resolve_item_parent_data(state: Dictionary):
	if typeof(state) != TYPE_DICTIONARY or state.empty():
		return null
	var resource_path = str(state.get("resource_path", ""))
	if resource_path != "" and ResourceLoader.exists(resource_path):
		var loaded = load(resource_path)
		if loaded != null:
			return _duplicate_with_synced_value_if_needed(loaded, state)
	var data_type = str(state.get("type", ""))
	var id_hash = int(state.get("my_id_hash", 0))
	var resolved = null
	if data_type == "upgrade":
		var upgrade_hash = int(state.get("upgrade_id_hash", id_hash))
		resolved = ItemService.get_element(ItemService.upgrades, upgrade_hash)
		if resolved == null and id_hash != 0:
			resolved = ItemService.get_element(ItemService.upgrades, id_hash)
	elif data_type == "weapon":
		resolved = ItemService.get_element(ItemService.weapons, id_hash)
		if resolved == null:
			var weapon_id_hash = int(state.get("weapon_id_hash", 0))
			resolved = ItemService.get_element(ItemService.weapons, weapon_id_hash)
	elif data_type == "consumable":
		resolved = ItemService.get_element(ItemService.consumables, id_hash)
	else:
		resolved = ItemService.get_element(ItemService.items, id_hash)
	if resolved != null:
		return _duplicate_with_synced_value_if_needed(resolved, state)
	var fallback = _get_cached_missing_host_item_placeholder(state, data_type)
	if fallback != null:
		pass
	return fallback


func _make_missing_host_item_placeholder(state: Dictionary, data_type: String):
	var pool = ItemService.items
	if data_type == "weapon":
		pool = ItemService.weapons
	elif data_type == "upgrade":
		pool = ItemService.upgrades
	elif data_type == "consumable":
		pool = ItemService.consumables
	if typeof(pool) != TYPE_ARRAY or pool.empty():
		return null
	var source = null
	for candidate in pool:
		if candidate != null:
			source = candidate
			break
	if source == null:
		return null
	var copy = source.duplicate()
	# Keep the Host identity on the placeholder. Without this, a DLC-missing client
	# displays a base-game placeholder whose resource_path belongs to the fallback item;
	# later lock/buy prediction keys no longer match the Host's authoritative shop item.
	if state.has("resource_path"):
		copy.resource_path = str(state.get("resource_path", copy.resource_path))
	copy.set("my_id", str(state.get("my_id", copy.get("my_id"))))
	copy.set("my_id_hash", int(state.get("my_id_hash", copy.get("my_id_hash"))))
	if state.has("weapon_id"):
		copy.set("weapon_id", str(state.get("weapon_id", copy.get("weapon_id"))))
	if state.has("weapon_id_hash"):
		copy.set("weapon_id_hash", int(state.get("weapon_id_hash", copy.get("weapon_id_hash"))))
	if state.has("upgrade_id"):
		copy.set("upgrade_id", str(state.get("upgrade_id", copy.get("upgrade_id"))))
	if state.has("upgrade_id_hash"):
		copy.set("upgrade_id_hash", int(state.get("upgrade_id_hash", copy.get("upgrade_id_hash"))))
	if state.has("value"):
		copy.set("value", int(state.get("value", copy.get("value"))))
	if state.has("tier"):
		copy.set("tier", int(state.get("tier", copy.get("tier"))))
	if state.has("is_cursed") and copy.get("is_cursed") != null:
		copy.set("is_cursed", bool(state.get("is_cursed", copy.get("is_cursed"))))
	if state.has("curse_factor") and copy.get("curse_factor") != null:
		copy.set("curse_factor", float(state.get("curse_factor", copy.get("curse_factor"))))
	return copy


func _duplicate_with_synced_value_if_needed(data, state: Dictionary):
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
		if copy is WeaponData:
			_repair_weapon_subclass_effect_runtime_fields(copy, data, "item_parent_serialized_data")
	else:
		if state.has("value"):
			copy.set("value", int(state.get("value", data.get("value"))))
		if state.has("is_cursed") and copy.get("is_cursed") != null:
			copy.set("is_cursed", bool(state.get("is_cursed", copy.get("is_cursed"))))
		if state.has("curse_factor") and copy.get("curse_factor") != null:
			copy.set("curse_factor", float(state.get("curse_factor", copy.get("curse_factor"))))
	if copy is WeaponData:
		if state.has("dmg_dealt_last_wave") and copy.get("dmg_dealt_last_wave") != null:
			copy.set("dmg_dealt_last_wave", int(state.get("dmg_dealt_last_wave", copy.get("dmg_dealt_last_wave"))))
		if state.has("tracked_value") and copy.get("tracked_value") != null:
			copy.set("tracked_value", int(state.get("tracked_value", copy.get("tracked_value"))))
	return copy


func _get_resource_path(data) -> String:
	if data == null:
		return ""
	var path = str(data.resource_path)
	return path


func _is_canvas_visible(node) -> bool:
	return node != null and is_instance_valid(node) and node is CanvasItem and bool(node.visible)


func _find_progression_ui(allow_recursive: bool = true) -> Node:
	var current = get_tree().current_scene
	if current == null:
		_cached_progression_ui = null
		_cached_progression_ui_scene_id = 0
		return null

	var scene_id = current.get_instance_id()
	if _cached_progression_ui_scene_id == scene_id and _is_live_ref(_cached_progression_ui):
		return _cached_progression_ui

	var direct = null
	if RunData != null and bool(RunData.get("is_coop_run")):
		direct = current.get("_coop_upgrades_ui")
	else:
		direct = current.get("_upgrades_ui")
	if _is_live_ref(direct):
		_cached_progression_ui = direct
		_cached_progression_ui_scene_id = scene_id
		return direct

	if not allow_recursive:
		return null

	# In main.tscn this fallback can walk the full battle tree. Keep it as a safety net
	# for unusual upgrade UI setups, but do not let normal battle polling scan every 120/250 ms.
	if _get_current_menu_screen_fast() == SCREEN_GAME:
		var now = OS.get_ticks_msec()
		if now - _last_progression_ui_recursive_scan_msec < PROGRESSION_UI_RECURSIVE_SCAN_INTERVAL_MSEC:
			return null
		_last_progression_ui_recursive_scan_msec = now

	var found = _find_progression_ui_recursive(current)
	if _is_live_ref(found):
		_cached_progression_ui = found
		_cached_progression_ui_scene_id = scene_id
		return found
	return null


func _find_progression_ui_recursive(node: Node) -> Node:
	if not _is_live_ref(node):
		return null
	var script_path = _get_script_path(node)
	if script_path.find("ui/menus/ingame/upgrades_ui.gd") != -1:
		return node
	for child in node.get_children():
		var found = _find_progression_ui_recursive(child)
		if found != null:
			return found
	return null


func _is_valid_progression_ui_visible(ui) -> bool:
	return _is_live_ref(ui) and ui is CanvasItem and bool(ui.visible)


func _get_progression_player_container(ui: Node, player_index: int):
	if not _is_live_ref(ui):
		return null
	if player_index < 0:
		return null
	if ui.has_method("_get_player_container"):
		return ui._get_player_container(player_index)
	return null


func _get_run_player_count() -> int:
	if RunData != null and RunData.has_method("get_player_count"):
		return int(RunData.get_player_count())
	return 1


func _resolve_run_page_action_player_index(origin_steam_id: String, from_steam_id: String, self_steam_id: String, message: Dictionary) -> int:
	var slot_manager = _get_slot_manager()
	if origin_steam_id == "" or origin_steam_id == self_steam_id:
		return int(message.get("player_index", 0))
	var host_steam_id = _get_game_host_steam_id()
	# One Steam peer can own several Host-local players. Do not collapse every
	# Host-origin shop/upgrade action to P0 on clients; trust the authoritative
	# player_index carried in the Host packet.
	if host_steam_id != "" and origin_steam_id == host_steam_id:
		return int(message.get("player_index", 0))
	if slot_manager != null and slot_manager.has_method("get_player_index_for_steam_id"):
		var mapped = int(slot_manager.get_player_index_for_steam_id(origin_steam_id))
		if mapped >= 0:
			return mapped
	return int(message.get("player_index", -1))


func _build_all_progression_visible_options(ui: Node = null) -> Array:
	var states = []
	if not _is_live_ref(ui):
		ui = _find_progression_ui(true)
	var player_count = _get_run_player_count()
	for i in range(player_count):
		var state = _build_progression_visible_option(i, ui)
		if typeof(state) == TYPE_DICTIONARY and not state.empty():
			states.append(state)
	return states


func _is_stale_run_page_action(action_id: String) -> bool:
	var parts = action_id.split(":")
	if parts.size() < 2:
		return false
	var origin = str(parts[0])
	var seq = int(parts[1])
	if origin == "" or seq <= 0:
		return false
	var last_seq = int(_last_run_page_action_seq_by_origin.get(origin, 0))
	if seq <= last_seq:
		return true
	_last_run_page_action_seq_by_origin[origin] = seq
	return false


func _is_duplicate_mutating_run_page_action(message: Dictionary, origin_steam_id: String = "") -> bool:
	var action_type = str(message.get("action_type", ""))
	if not _is_mutating_run_page_action(action_type):
		return false
	var key = _build_mutating_run_page_action_fingerprint(message, origin_steam_id)
	if key == "":
		return false
	var now = OS.get_ticks_msec()
	for old_key in _recent_mutating_run_page_action_keys.keys():
		if now - int(_recent_mutating_run_page_action_keys[old_key]) > MUTATING_RUN_PAGE_ACTION_DEDUP_MSEC:
			_recent_mutating_run_page_action_keys.erase(old_key)
	if _recent_mutating_run_page_action_keys.has(key) and now - int(_recent_mutating_run_page_action_keys[key]) <= MUTATING_RUN_PAGE_ACTION_DEDUP_MSEC:
		return true
	_recent_mutating_run_page_action_keys[key] = now
	return false


func _is_mutating_run_page_action(action_type: String) -> bool:
	return [
		"upgrade_select",
		"upgrade_reroll",
		"item_box_take",
		"item_box_discard",
		"item_box_ban",
		"shop_buy",
		"shop_combine_weapon",
		"shop_discard_weapon",
		"shop_reroll",
		"shop_go",
		"shop_lock"
	].has(action_type)


func _build_mutating_run_page_action_fingerprint(message: Dictionary, origin_steam_id: String = "") -> String:
	var parts = []
	parts.append(origin_steam_id if origin_steam_id != "" else str(message.get("origin_steam_id", "")))
	parts.append(str(message.get("action_type", "")))
	parts.append(str(message.get("screen", "")))
	parts.append(str(message.get("player_index", "")))
	parts.append(str(message.get("target", "")))
	parts.append(str(message.get("shop_index", "")))
	parts.append(str(message.get("upgrade_index", "")))
	parts.append(str(message.get("upgrade_id_hash", "")))
	parts.append(str(message.get("item_id_hash", "")))
	parts.append(str(message.get("weapon_id_hash", "")))
	parts.append(str(message.get("weapon_my_id_hash", "")))
	parts.append(str(message.get("weapon_weapon_id_hash", "")))
	parts.append(str(message.get("weapon_slot_index", "")))
	parts.append(str(message.get("state_key", "")))
	return "|".join(parts)


func _trim_processed_run_page_actions() -> void:
	if _processed_run_page_action_ids.size() <= 256:
		return
	var now = OS.get_ticks_msec()
	for key in _processed_run_page_action_ids.keys():
		if now - int(_processed_run_page_action_ids[key]) > 30000:
			_processed_run_page_action_ids.erase(key)


func _get_steam_lobby_manager() -> Node:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineSteamLobbyManager")


func _is_online_session_active() -> bool:
	var steam_lobby = _get_steam_lobby_manager()
	if steam_lobby != null:
		if steam_lobby.has_method("is_online_session_active"):
			return bool(steam_lobby.is_online_session_active())
		if steam_lobby.has_method("has_active_online_session"):
			return bool(steam_lobby.has_active_online_session())
	return false


func _is_game_host() -> bool:
	var steam_lobby = _get_steam_lobby_manager()
	if steam_lobby != null and steam_lobby.has_method("is_game_host"):
		return bool(steam_lobby.is_game_host())
	return false


func _get_online_coop_layout_player_count() -> int:
	if not _is_online_session_active():
		return -1
	if CoopService == null:
		return -1
	var count = int(CoopService.connected_players.size())
	if count <= 0:
		return -1
	return int(clamp(count, 1, 4))


func _force_run_player_count_to_online_coop_layout(reason: String) -> void:
	var target_count = _get_online_coop_layout_player_count()
	if target_count <= 0:
		return
	if RunData == null or not RunData.has_method("set_player_count"):
		return
	var current_count = int(RunData.get_player_count())
	var raw_count = RunData.players_data.size() if typeof(RunData.players_data) == TYPE_ARRAY else current_count
	if current_count == target_count and raw_count == target_count:
		return
	RunData.set_player_count(target_count, false)
	if target_count > 1:
		RunData.play_mode = RunData.PlayMode.COOP
		RunData.set_coop_run(true)


func _get_game_host_steam_id() -> String:
	var steam_lobby = _get_steam_lobby_manager()
	if steam_lobby != null and steam_lobby.has_method("get_game_host_steam_id"):
		return str(steam_lobby.get_game_host_steam_id())
	return ""


func _get_self_steam_id() -> String:
	var steam_lobby = _get_steam_lobby_manager()
	if steam_lobby != null and steam_lobby.has_method("get_self_steam_id"):
		return str(steam_lobby.get_self_steam_id())
	return _local_client_steam_id


func _resolve_client_player_index_for_host(client_steam_id: String, players: Array) -> int:
	var player_index = _find_player_index_in_players(players, client_steam_id)
	if player_index >= 0:
		return player_index
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("get_player_index_for_steam_id"):
		return int(slot_manager.get_player_index_for_steam_id(client_steam_id))
	return -1


func _tag_selection_state_for_target_client(selection_state: Dictionary, client_steam_id: String, client_player_index: int) -> void:
	if typeof(selection_state) != TYPE_DICTIONARY:
		return
	if client_steam_id == "" or client_steam_id == "0":
		return
	selection_state["target_client_steam_id"] = client_steam_id
	selection_state["target_client_player_index"] = client_player_index
	selection_state["client_player_index"] = client_player_index


func _clear_client_local_ready_after_send(selection: Node, player_index: int) -> void:
	# Client 只发送选择意图，不允许本地 BaseSelection 因为 ready 状态自行完成跳转。
	var selected_flags = selection.get("_has_player_selected")
	if typeof(selected_flags) == TYPE_ARRAY and player_index >= 0 and player_index < selected_flags.size():
		selected_flags[player_index] = false

	var panels = selection._get_panels() if selection.has_method("_get_panels") else []
	if typeof(panels) == TYPE_ARRAY and player_index >= 0 and player_index < panels.size():
		if _is_live_ref(panels[player_index]):
			panels[player_index].selected = false

	var timer = _safe_get(selection, "_selections_completed_timer", null)
	if _is_live_ref(timer) and timer.has_method("stop"):
		timer.stop()


func _configure_online_focus_emulator_input_owner(owner_player_index: int, reason: String = "") -> void:
	_configure_online_focus_emulator_input_owners([owner_player_index], reason)


func _configure_online_focus_emulator_input_owners(owner_player_indices: Array, reason: String = "") -> void:
	if not _is_online_session_active():
		return
	var owner_lookup = {}
	for idx_value in owner_player_indices:
		var idx = int(idx_value)
		if idx >= 0:
			owner_lookup[idx] = true
	if owner_lookup.empty():
		return
	var count = int(max(4, int(RunData.get_player_count())))
	for player_index in range(count):
		var focus_emulator = Utils.get_focus_emulator(player_index)
		if not _is_live_ref(focus_emulator):
			continue
		var should_process = bool(owner_lookup.get(player_index, false))
		var was_processing = focus_emulator.is_processing_input()
		if was_processing != should_process:
			_bo_ui_diag_log("FOCUS_OWNER_SET", "reason=" + reason + " owners=" + str(owner_player_indices) + " player=" + str(player_index) + " from=" + str(was_processing) + " to=" + str(should_process) + " fe=" + _bo_ui_diag_node_desc(focus_emulator))
			focus_emulator.set_process_input(should_process)
	_bo_ui_diag_log_focus("owner_config_" + reason, false)


func _enable_only_local_inventory_mouse_focus(selection: Node, player_index: int) -> void:
	var inventories = []
	if selection.has_method("_get_inventories"):
		inventories = selection._get_inventories()
	if typeof(inventories) != TYPE_ARRAY or inventories.empty():
		return

	var local_inventory_index = player_index % inventories.size()
	for i in range(inventories.size()):
		var inv = inventories[i]
		if not _is_live_ref(inv):
			continue
		if _has_property(inv, "mouse_focus_enabled"):
			inv.set("mouse_focus_enabled", i == local_inventory_index)


func _disable_selection_buttons(selection: Node, disabled: bool) -> void:
	var inventories = []
	if selection.has_method("_get_inventories"):
		inventories = selection._get_inventories()
	if typeof(inventories) != TYPE_ARRAY:
		return

	for inv in inventories:
		if not _is_live_ref(inv):
			continue
		for child in inv.get_children():
			if child is BaseButton:
				child.disabled = disabled


func build_host_character_setup_state(client_steam_id: String, host_steam_id: String = "") -> Dictionary:
	# Host -> one client. This is sent once after the client joined and the Host COOP slot exists.
	var selection_state = build_selection_state()
	var players = selection_state.get("players", [])
	var client_player_index = _resolve_client_player_index_for_host(client_steam_id, players)
	_tag_selection_state_for_target_client(selection_state, client_steam_id, client_player_index)
	return {
		"msg_type": "host_character_setup",
		"screen": SCREEN_CHARACTER_SELECTION,
		"scene_path": _get_scene_path_for_screen(SCREEN_CHARACTER_SELECTION),
		"host_steam_id": host_steam_id,
		"client_steam_id": client_steam_id,
		"client_player_index": client_player_index,
		"player_count": int(RunData.get_player_count()),
		"players": players,
		"selection_state": selection_state,
		"run_config": _build_run_config_for_scene_sync(),
		"character_catalog": _build_host_catalog_for_screen(SCREEN_CHARACTER_SELECTION)
	}


func build_host_weapon_setup_state(client_steam_id: String, host_steam_id: String = "") -> Dictionary:
	# Host -> one client. Sent when Host has already entered weapon_selection.
	var selection_state = build_selection_state()
	var players = selection_state.get("players", [])
	var client_player_index = _resolve_client_player_index_for_host(client_steam_id, players)
	_tag_selection_state_for_target_client(selection_state, client_steam_id, client_player_index)
	return {
		"msg_type": "host_weapon_setup",
		"screen": SCREEN_WEAPON_SELECTION,
		"scene_path": _get_scene_path_for_screen(SCREEN_WEAPON_SELECTION),
		"host_steam_id": host_steam_id,
		"client_steam_id": client_steam_id,
		"client_player_index": client_player_index,
		"player_count": int(RunData.get_player_count()),
		"players": players,
		"selection_state": selection_state,
		"run_config": _build_run_config_for_scene_sync(),
		"weapon_catalog": _build_host_catalog_for_screen(SCREEN_WEAPON_SELECTION)
	}


func _apply_host_setup_run_config_once(config: Dictionary, target_screen: String) -> void:
	if typeof(config) != TYPE_DICTIONARY or config.empty():
		return
	var run_config_key = target_screen + "|" + to_json(config)
	if run_config_key == _last_applied_run_config_key:
		return
	_apply_run_config_before_client_scene_change(config, target_screen)
	_last_applied_run_config_key = run_config_key


func receive_host_character_setup_from_host(state: Dictionary, self_steam_id: String = "", host_steam_id: String = "") -> void:
	_local_client_steam_id = self_steam_id
	_last_menu_scene_state_from_host = state
	var catalog = _get_dict_or_empty(state.get("character_catalog", {}))

	_store_host_catalog(SCREEN_CHARACTER_SELECTION, catalog)
	_apply_host_slot_layout_from_phase_state(state, self_steam_id, host_steam_id)
	_apply_host_setup_run_config_once(_get_dict_or_empty(state.get("run_config", {})), SCREEN_CHARACTER_SELECTION)
	_change_to_host_phase_scene(state, SCREEN_CHARACTER_SELECTION)

	var selection_state = _get_dict_or_empty(state.get("selection_state", {}))
	if not selection_state.empty():
		_last_state_from_host = selection_state
		_pending_state_from_host = selection_state

	_schedule_client_prime_local_first_focus(SCREEN_CHARACTER_SELECTION)
	_try_apply_pending_host_state()


func receive_host_weapon_setup_from_host(state: Dictionary, self_steam_id: String = "", host_steam_id: String = "") -> void:
	_local_client_steam_id = self_steam_id
	_last_menu_scene_state_from_host = state
	var catalog = _get_dict_or_empty(state.get("weapon_catalog", {}))

	_store_host_catalog(SCREEN_WEAPON_SELECTION, catalog)
	_apply_host_slot_layout_from_phase_state(state, self_steam_id, host_steam_id)
	_apply_host_setup_run_config_once(_get_dict_or_empty(state.get("run_config", {})), SCREEN_WEAPON_SELECTION)
	_change_to_host_phase_scene(state, SCREEN_WEAPON_SELECTION)

	var selection_state = _get_dict_or_empty(state.get("selection_state", {}))
	if not selection_state.empty():
		_last_state_from_host = selection_state
		_pending_state_from_host = selection_state

	_schedule_client_prime_local_first_focus(SCREEN_WEAPON_SELECTION)
	_try_apply_pending_host_state()


func _apply_host_slot_layout_from_phase_state(state: Dictionary, self_steam_id: String, host_steam_id: String) -> void:
	var players = state.get("players", [])
	if typeof(players) != TYPE_ARRAY or players.empty():
		return
	var pseudo_state = {
		"msg_type": "selection_state",
		"screen": str(state.get("screen", "")),
		"players": players,
		"target_client_steam_id": str(state.get("target_client_steam_id", state.get("client_steam_id", self_steam_id))),
		"target_client_player_index": int(state.get("target_client_player_index", state.get("client_player_index", -1))),
		"client_player_index": int(state.get("client_player_index", state.get("target_client_player_index", -1)))
	}
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("apply_host_selection_layout"):
		slot_manager.apply_host_selection_layout(pseudo_state, self_steam_id, host_steam_id)


func _change_to_host_phase_scene(state: Dictionary, expected_screen: String) -> void:
	var target_scene_path = str(state.get("scene_path", ""))
	if target_scene_path == "":
		target_scene_path = _get_scene_path_for_screen(expected_screen)
	if target_scene_path == "":
		return

	var current_screen = get_current_menu_screen()
	var current_scene_path = _get_current_scene_resource_path()
	if current_screen == expected_screen or current_scene_path == target_scene_path:
		return

	_clear_focus_emulators_before_client_scene_change(current_screen, expected_screen)
	var err = get_tree().change_scene(target_scene_path)
	if err != OK:
		pass

func _find_player_index_in_players(players, steam_id: String) -> int:
	if typeof(players) != TYPE_ARRAY:
		return -1
	for p in players:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		if str(p.get("steam_id", "")) == steam_id:
			return int(p.get("player_index", -1))
	return -1


func _get_dict_or_empty(value) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func _get_array_size_for_log(value) -> int:
	if typeof(value) == TYPE_ARRAY:
		return value.size()
	return 0


func _schedule_client_prime_local_first_focus(screen: String) -> void:
	if not _is_client_interactive_selection_screen(screen):
		return
	_pending_client_prime_screen = screen
	_pending_client_prime_until_msec = OS.get_ticks_msec() + 1600
	_last_client_prime_key = ""
	call_deferred("_try_apply_pending_client_prime_focus")
	var tree = get_tree()
	if tree != null:
		var timer = tree.create_timer(0.20)
		timer.connect("timeout", self, "_try_apply_pending_client_prime_focus")


func _try_apply_pending_client_prime_focus() -> void:
	if _pending_client_prime_screen == "":
		return
	if OS.get_ticks_msec() > _pending_client_prime_until_msec:
		_pending_client_prime_screen = ""
		return

	var selection = _find_current_selection_node()
	if selection == null:
		return
	var screen = _get_selection_screen(selection)
	if screen != _pending_client_prime_screen:
		return

	var player_index = _get_local_client_player_index()
	if player_index < 0 or player_index >= RunData.get_player_count():
		return

	var existing = _get_latest_focused_element(selection, player_index)
	if _is_live_ref(existing) and not bool(_safe_get(existing, "is_locked", false)) and not bool(_safe_get(existing, "is_special", false)):
		_pending_client_prime_screen = ""
		return

	_try_apply_online_catalog_to_current_selection()
	var elements = _get_selectable_elements_for_player(selection, player_index, false)
	var filtered_elements = []
	for candidate in elements:
		var candidate_state = _element_to_state(candidate)
		if _is_host_catalog_item_selectable(screen, player_index, candidate_state):
			filtered_elements.append(candidate)
	elements = filtered_elements
	if elements.empty():
		return

	var element = elements[0]
	if not _is_live_ref(element):
		return

	var prime_key = screen + ":" + str(player_index) + ":" + _get_item_id_for_log(_safe_get(element, "item", null))
	if prime_key == _last_client_prime_key:
		return
	_last_client_prime_key = prime_key

	_apply_focus_element(selection, player_index, element)
	_clear_client_local_ready_after_send(selection, player_index)
	_pending_client_prime_screen = ""

func receive_selection_state_from_host(state: Dictionary, self_steam_id: String = "", host_steam_id: String = "") -> void:
	# Client 侧：Host 的 selection_state 是菜单显示的权威来源。
	var state_screen = str(state.get("screen", ""))
	if _is_client_interactive_selection_screen(state_screen) and not _host_catalog_by_screen.has(state_screen):
		# A selection_state without its matching host_*_setup is not sufficient. Applying it
		# would rebuild slots/focus against a stale local catalog from the previous room.
		return

	_local_client_steam_id = self_steam_id
	_last_state_from_host = state
	_pending_state_from_host = state

	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("apply_host_selection_layout"):
		slot_manager.apply_host_selection_layout(state, self_steam_id, host_steam_id)

	_try_apply_pending_host_state()


func _build_slot_layout_for_scene_sync() -> Dictionary:
	var players = []
	var slot_manager = _get_slot_manager()
	var host_steam_id = _get_game_host_steam_id()
	if host_steam_id == "":
		host_steam_id = _get_self_steam_id()

	for player_index in range(RunData.get_player_count()):
		var is_remote = false
		var steam_id = ""
		if slot_manager != null:
			if slot_manager.has_method("is_remote_player_index"):
				is_remote = bool(slot_manager.is_remote_player_index(player_index))
			if is_remote and slot_manager.has_method("get_remote_steam_id"):
				steam_id = str(slot_manager.get_remote_steam_id(player_index))

		if steam_id == "" and player_index == 0:
			steam_id = host_steam_id

		players.append({
			"player_index": player_index,
			"remote": is_remote,
			"steam_id": steam_id
		})

	return {
		"players": players
	}


func _apply_host_slot_layout_from_menu_scene_state(state: Dictionary, self_steam_id: String, host_steam_id: String) -> void:
	if _is_game_host():
		return
	var slot_layout = state.get("slot_layout", {})
	if typeof(slot_layout) != TYPE_DICTIONARY:
		return
	var players = slot_layout.get("players", [])
	if typeof(players) != TYPE_ARRAY or players.empty():
		return
	var pseudo_state = {
		"msg_type": "selection_state",
		"screen": str(state.get("screen", "")),
		"players": players,
		"target_client_steam_id": str(state.get("target_client_steam_id", state.get("client_steam_id", self_steam_id))),
		"target_client_player_index": int(state.get("target_client_player_index", state.get("client_player_index", -1))),
		"client_player_index": int(state.get("client_player_index", state.get("target_client_player_index", -1)))
	}
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("apply_host_selection_layout"):
		slot_manager.apply_host_selection_layout(pseudo_state, self_steam_id, host_steam_id)


func build_menu_scene_state(include_shop_state: bool = true, include_full_run_config: bool = true, force_full_held_items: bool = false) -> Dictionary:
	# Host 侧：同步“当前处于哪个官方流程界面”，并携带 Client 切场景前需要写入 RunData 的最小配置。
	var screen = get_current_menu_screen()
	var held_items_mode = SHOP_HELD_ITEMS_SYNC_HASH_ONLY if screen == SCREEN_SHOP else SHOP_HELD_ITEMS_SYNC_COMPACT
	if force_full_held_items:
		held_items_mode = SHOP_HELD_ITEMS_SYNC_COMPACT
	var state = {
		"msg_type": "menu_scene_state",
		"screen": screen,
		"scene_path": _get_scene_path_for_screen(screen),
		"run_config": _build_run_config_for_scene_sync(include_full_run_config, held_items_mode, force_full_held_items),
		"slot_layout": _build_slot_layout_for_scene_sync(),
		"availability": _build_host_availability_for_scene(screen)
	}
	if screen == SCREEN_SHOP and include_shop_state:
		var shop_states = _build_all_shop_player_states_for_menu_scene()
		if not shop_states.empty():
			state["shop_state"] = {
				"players": shop_states,
				"full_snapshot": true,
				"run_data_source": "run_config"
			}
	return state


func get_current_menu_screen() -> String:
	var fast_screen = _get_current_menu_screen_fast()
	if fast_screen != SCREEN_NONE:
		return fast_screen
	var selection = _find_current_selection_node()
	if selection != null:
		return _get_selection_screen(selection)
	return SCREEN_NONE


func receive_menu_scene_state_from_host(state: Dictionary, self_steam_id: String = "", host_steam_id: String = "") -> void:
	# Client 侧：Host 的 menu_scene_state 是流程跳转的权威来源。
	# self_steam_id / host_steam_id 当前保留，后面输入同步和玩家标签会继续用。
	var state_screen_for_guard = str(state.get("screen", ""))
	if _is_game_start_guard_active() and state_screen_for_guard != SCREEN_GAME:
		# Old shop/difficulty packets during shop->battle transition must still be ignored.
		# But if a progression overlay is already visible in main.tscn, a non-game state
		# from Host is the normal wave-end/progression->shop transition and must be accepted.
		var progression_ui_for_guard = _find_progression_ui(false)
		if _get_current_menu_screen_fast() == SCREEN_GAME and _is_valid_progression_ui_visible(progression_ui_for_guard):
			_end_game_start_guard("accept_menu_scene_after_progression:" + state_screen_for_guard)
		else:
			return

	_last_menu_scene_state_from_host = state
	_pending_menu_scene_state_from_host = state
	_apply_host_slot_layout_from_menu_scene_state(state, self_steam_id, host_steam_id)
	_queue_availability_from_menu_scene_state(state)
	if state_screen_for_guard == SCREEN_GAME:
		var game_start_sync = state.get("game_start_sync", {})
		var scene_start_id = _run_page_game_start_guard_start_id
		if typeof(game_start_sync) == TYPE_DICTIONARY:
			scene_start_id = int(game_start_sync.get("start_id", scene_start_id))
		# A duplicate/late screen=game menu_scene_state can arrive while the client is
		# already in main.tscn. Re-arming the 10s guard here drops real wave-end
		# upgrade_state/shop transitions, which is the wave-30 stuck case.
		if _get_current_menu_screen_fast() != SCREEN_GAME:
			begin_game_start_guard(scene_start_id, "menu_scene_game")
		else:
			pass
		_try_apply_pending_menu_scene_state()
		return
	else:
		_queue_shop_state_from_menu_scene_state(state)
	_try_apply_pending_menu_scene_state()
	_try_apply_pending_host_state()
	_try_apply_pending_shop_state()

func _try_apply_pending_menu_scene_state() -> void:
	if typeof(_pending_menu_scene_state_from_host) != TYPE_DICTIONARY or _pending_menu_scene_state_from_host.empty():
		return

	if _apply_menu_scene_state_from_host(_pending_menu_scene_state_from_host):
		_pending_menu_scene_state_from_host = {}


func _apply_menu_scene_state_from_host(state: Dictionary) -> bool:
	var target_screen = str(state.get("screen", SCREEN_NONE))
	if target_screen == "" or target_screen == SCREEN_NONE:
		return true

	var target_scene_path = str(state.get("scene_path", ""))
	if target_scene_path == "":
		target_scene_path = _get_scene_path_for_screen(target_screen)

	if target_scene_path == "":
		return true

	var run_config = state.get("run_config", {})
	var run_config_key = target_screen + "|" + to_json(run_config)
	var force_scene_reload = bool(state.get("force_scene_reload", false))
	var current_screen = get_current_menu_screen()
	var current_scene_path = _get_current_scene_resource_path()
	var now = OS.get_ticks_msec()

	# Godot 3 change_scene() is deferred enough that current_scene can still report the
	# previous scene for a short time. Host can send duplicate menu_scene_state packets
	# while the first change_scene() is still in flight. This must be suppressed for
	# shop as well as game: reloading CoopShop during reconnect can overwrite the
	# authoritative Host shop_state that was just applied, making shop items diverge.
	if _client_scene_change_in_flight_screen == target_screen and _client_scene_change_in_flight_path == target_scene_path and now < _client_scene_change_in_flight_until_msec:
		if typeof(run_config) == TYPE_DICTIONARY and run_config_key != _last_applied_run_config_key:
			_apply_run_config_before_client_scene_change(run_config, target_screen)
			_last_applied_run_config_key = run_config_key
		_queue_availability_from_menu_scene_state(state)
		_queue_shop_state_from_menu_scene_state(state)
		_try_apply_pending_shop_state()
		var flight_key = target_screen + "|" + target_scene_path
		if flight_key != _client_scene_change_in_flight_logged_key:
			_client_scene_change_in_flight_logged_key = flight_key
		_pending_state_from_host = _last_state_from_host
		return true

	# If already in the target scene, only update RunData and transient OnlineCatalog.
	# Do not reload the scene and do not mirror ProgressData; both caused unstable UI state.
	if not force_scene_reload and (current_screen == target_screen or current_scene_path == target_scene_path):
		if _client_scene_change_in_flight_screen == target_screen and (_client_scene_change_in_flight_path == target_scene_path or current_scene_path == target_scene_path):
			_client_scene_change_in_flight_screen = ""
			_client_scene_change_in_flight_path = ""
			_client_scene_change_in_flight_until_msec = 0
			_client_scene_change_in_flight_logged_key = ""
		if typeof(run_config) == TYPE_DICTIONARY and run_config_key != _last_applied_run_config_key:
			_apply_run_config_before_client_scene_change(run_config, target_screen)
			_last_applied_run_config_key = run_config_key
		_queue_availability_from_menu_scene_state(state)
		_queue_shop_state_from_menu_scene_state(state)
		_try_apply_online_catalog_to_current_selection()
		_try_apply_pending_shop_state()
		_pending_state_from_host = _last_state_from_host
		return true

	var apply_key = target_screen + "|" + target_scene_path + "|" + to_json(run_config)
	if apply_key == _last_client_scene_apply_key and now - _last_client_scene_apply_msec < MENU_SCENE_APPLY_DEBOUNCE_MSEC:
		return false

	_last_client_scene_apply_key = apply_key
	_last_client_scene_apply_msec = now

	if typeof(run_config) == TYPE_DICTIONARY:
		_apply_run_config_before_client_scene_change(run_config, target_screen)
		_last_applied_run_config_key = run_config_key

	_repair_client_slot_layout_before_scene_change(target_screen)
	_queue_availability_from_menu_scene_state(state)

	# Important: clear FocusEmulator while the old scene controls are still alive.
	# If a weapon/character button is freed by change_scene while a FocusEmulator still
	# keeps it as focused_control, the next keyboard event can crash inside the vanilla
	# focus_emulator.gd _disconnect_focused_control(null/invalid).
	_clear_focus_emulators_before_client_scene_change(current_screen, target_screen)

	_client_scene_change_in_flight_screen = target_screen
	_client_scene_change_in_flight_path = target_scene_path
	_client_scene_change_in_flight_until_msec = now + MENU_SCENE_CHANGE_IN_FLIGHT_MSEC
	_client_scene_change_in_flight_logged_key = ""
	var err = get_tree().change_scene(target_scene_path)
	if err != OK:
		return false

	# 切完场景后，selection_state / availability / shop_state 可能已经先收到；保留 pending，让新场景 ready 后再套 UI 显示。
	_queue_availability_from_menu_scene_state(state)
	_queue_shop_state_from_menu_scene_state(state)
	_pending_state_from_host = _last_state_from_host
	return true


func _repair_client_slot_layout_before_scene_change(target_screen: String) -> void:
	if _is_game_host():
		return
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("repair_mirrored_layout_now"):
		slot_manager.repair_mirrored_layout_now("before_client_scene_change:" + target_screen)


func _build_run_config_for_scene_sync(include_player_run_data: bool = true, held_items_mode: String = SHOP_HELD_ITEMS_SYNC_COMPACT, force_full_held_items: bool = false) -> Dictionary:
	held_items_mode = _resolve_shop_held_items_sync_mode(held_items_mode, force_full_held_items)
	var players = []
	for player_index in range(RunData.get_player_count()):
		var player_data = null
		if player_index >= 0 and player_index < RunData.players_data.size():
			player_data = RunData.players_data[player_index]

		var character = null
		var selected_weapon = null
		var selected_item = null
		if player_data != null:
			character = _safe_get(player_data, "current_character", null)
			selected_weapon = _safe_get(player_data, "selected_weapon", null)
			selected_item = _safe_get(player_data, "selected_item", null)

		var serialized_run_data = {}
		if include_player_run_data and player_data != null and player_data.has_method("serialize"):
			if (held_items_mode == SHOP_HELD_ITEMS_SYNC_HASH_ONLY or held_items_mode == SHOP_HELD_ITEMS_SYNC_INCREMENTAL_ONLY) and _is_game_host():
				var run_data_sync = _build_shop_run_data_sync_state(player_index, true, held_items_mode, force_full_held_items)
				serialized_run_data = run_data_sync.get("run_data", {})
			else:
				serialized_run_data = _compact_player_run_data_for_shop_sync(player_index, player_data.serialize(), held_items_mode, force_full_held_items)

		players.append({
			"player_index": player_index,
			"character": _data_object_to_sync_state(character),
			"selected_weapon": _data_object_to_sync_state(selected_weapon),
			"selected_item": _data_object_to_sync_state(selected_item),
			"run_data": serialized_run_data
		})

	return {
		"play_mode": int(RunData.play_mode),
		"is_coop_run": bool(RunData.is_coop_run),
		"is_endless_run": bool(RunData.is_endless_run),
		"endless_mode_toggled": bool(ProgressData.settings.endless_mode_toggled),
		"player_count": int(RunData.get_player_count()),
		"current_zone": int(RunData.current_zone),
		"current_difficulty": int(RunData.current_difficulty),
		"current_wave": int(RunData.current_wave),
		"full_item_list_for_scene_sync": bool(force_full_held_items),
		"zone_selected": int(ProgressData.settings.zone_selected),
		"zone_is_random": bool(ProgressData.settings.zone_is_random),
		# Host-authoritative future-wave schedule. This is required for D6+
		# nightmare warning icons/fog/bullet-hell waves and for elite/horde
		# warnings. Clients must not regenerate these RNG tables locally.
		"constant_projectile": int(RunData.constant_projectile),
		"nb_of_waves": int(RunData.nb_of_waves),
		"elites_spawn": RunData.elites_spawn.duplicate(true),
		"bosses_spawn": RunData.bosses_spawn.duplicate(true),
		"events_spawn": RunData.events_spawn.duplicate(true),
		"events_fog_of_war": RunData.events_fog_of_war.duplicate(true),
		"events_bullet_hell": RunData.events_bullet_hell.duplicate(true),
		"players": players
	}


func _apply_run_config_before_client_scene_change(config: Dictionary, target_screen: String) -> void:
	var player_count = int(config.get("player_count", 1))
	if player_count < 1:
		player_count = 1

	# Battle scene creation uses both RunData.players_data and CoopService.connected_players.
	# If a stale/compact run_config tries to shrink RunData below the mirrored COOP layout
	# just before main.tscn, EntitySpawner may create player nodes whose player_index has
	# no RunData entry, then Main._on_EntitySpawner_players_spawned crashes at
	# RunData.get_player_effects(i). Keep battle entry count at least the local COOP layout.
	if target_screen == SCREEN_GAME or target_screen == "game":
		var coop_player_count = int(CoopService.connected_players.size()) if CoopService != null else 0
		if coop_player_count > player_count:
			player_count = coop_player_count

	RunData.play_mode = int(config.get("play_mode", RunData.play_mode))
	if config.has("is_coop_run"):
		RunData.set_coop_run(bool(config.get("is_coop_run", player_count > 1)))
	else:
		RunData.set_coop_run(player_count > 1)

	if config.has("is_endless_run") or config.has("endless_mode_toggled"):
		var endless_value = bool(config.get("is_endless_run", config.get("endless_mode_toggled", RunData.is_endless_run)))
		RunData.is_endless_run = endless_value
		ProgressData.settings.endless_mode_toggled = bool(config.get("endless_mode_toggled", endless_value))
		_apply_endless_mode_to_current_ui(endless_value)

	if config.has("current_zone"):
		RunData.current_zone = int(config.get("current_zone", RunData.current_zone))
	if config.has("current_difficulty"):
		RunData.current_difficulty = int(config.get("current_difficulty", RunData.current_difficulty))
	if config.has("current_wave"):
		RunData.current_wave = int(config.get("current_wave", RunData.current_wave))
	if config.has("retries"):
		RunData.retries = int(config.get("retries", RunData.retries))
	if config.has("zone_selected"):
		ProgressData.settings.zone_selected = int(config.get("zone_selected", ProgressData.settings.zone_selected))
	if config.has("zone_is_random"):
		ProgressData.settings.zone_is_random = bool(config.get("zone_is_random", ProgressData.settings.zone_is_random))

	_apply_host_wave_schedule_from_run_config(config)

	# Client 进入后续界面前必须有与 Host 一致的 RunData 数量；否则 weapon_selection / difficulty_selection 的 _ready 会读空角色或空武器。
	# 但不能无条件 reset players_data，否则 shop hash-only 依赖的本地 items 会先被清空，导致每次进商店都 hash mismatch。
	var need_fix_player_count = RunData.get_player_count() != player_count or RunData.players_data.size() != player_count
	if not need_fix_player_count:
		for i in range(player_count):
			if i >= RunData.players_data.size() or RunData.players_data[i] == null:
				need_fix_player_count = true
				break
	if need_fix_player_count:
		RunData.set_player_count(player_count, false)

	var players = config.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		players = []

	var applied_full_run_data = false
	var should_apply_full_run_data = _run_config_has_serialized_player_run_data(players) or target_screen == SCREEN_SHOP or target_screen == "shop" or bool(config.get("full_player_run_data_authoritative", false))
	if should_apply_full_run_data:
		var preserve_local_runtime_state = str(config.get("run_config_source", "")) != "retry_wave"
		applied_full_run_data = _apply_serialized_players_run_data(players, preserve_local_runtime_state)

	if not applied_full_run_data:
		_rebuild_run_data_from_selection_states(players, player_count, target_screen)

	if target_screen == SCREEN_GAME and _should_apply_difficulty_start_for_client(config):
		var difficulty_start_key = _build_difficulty_start_apply_key(config)
		if difficulty_start_key == "" or difficulty_start_key != _last_applied_difficulty_start_key:
			_apply_difficulty_start_for_client(config)
			_last_applied_difficulty_start_key = difficulty_start_key


func _run_config_has_serialized_player_run_data(players: Array) -> bool:
	for player_state in players:
		if typeof(player_state) != TYPE_DICTIONARY:
			continue
		var run_data_state = player_state.get("run_data", {})
		if typeof(run_data_state) == TYPE_DICTIONARY and not run_data_state.empty():
			return true
	return false


func _rebuild_run_data_from_selection_states(players: Array, player_count: int, target_screen: String) -> void:
	# Fallback for legacy/minimal run_config packets. Rebuild from Host selections instead
	# of additively calling add_character/add_weapon/add_starting_items_and_weapons on
	# whatever local PlayerRunData currently contains. Those add_* calls apply item
	# effects immediately, so repeating this path stacks character effects and starting
	# weapons.
	var should_rebuild = target_screen == SCREEN_WEAPON_SELECTION or target_screen == SCREEN_DIFFICULTY_SELECTION or target_screen == SCREEN_GAME
	if not should_rebuild:
		return
	RunData.set_player_count(player_count, true)

	for player_state in players:
		if typeof(player_state) != TYPE_DICTIONARY:
			continue
		var player_index = int(player_state.get("player_index", -1))
		if player_index < 0 or player_index >= RunData.get_player_count():
			continue
		var character_state = _get_dict_or_empty(player_state.get("character", {}))
		var character = _resolve_character_data_for_run_config(character_state, player_index, target_screen)
		if character != null:
			RunData.add_character(character, player_index)

	if target_screen != SCREEN_DIFFICULTY_SELECTION and target_screen != SCREEN_GAME:
		return

	for player_state in players:
		if typeof(player_state) != TYPE_DICTIONARY:
			continue
		var player_index = int(player_state.get("player_index", -1))
		if player_index < 0 or player_index >= RunData.get_player_count():
			continue
		var selected_weapon = _find_weapon_data_by_sync_state(player_state.get("selected_weapon", {}))
		if selected_weapon != null:
			RunData.add_weapon(selected_weapon, player_index, true)
		else:
			var selected_item = _find_item_data_by_sync_state(player_state.get("selected_item", {}))
			if selected_item != null:
				RunData.add_item(selected_item, player_index, true)

	RunData.add_starting_items_and_weapons()


func _should_apply_difficulty_start_for_client(config: Dictionary) -> bool:
	var source = str(config.get("run_config_source", ""))
	if source == "shop_start" or source == "retry_wave":
		return false
	if source == "difficulty_start":
		return true
	# Untagged screen=game scene_state can be a late in-battle/reconnect snapshot whose
	# serialized PlayerRunData already contains difficulty effects. Do not guess here.
	return false


func _build_difficulty_start_apply_key(config: Dictionary) -> String:
	return to_json({
		"source": str(config.get("run_config_source", "difficulty_start")),
		"game_start_id": int(config.get("game_start_id", config.get("retry_start_id", 0))),
		"difficulty": int(config.get("current_difficulty", RunData.current_difficulty)),
		"wave": int(config.get("current_wave", RunData.current_wave)),
		"player_count": int(config.get("player_count", RunData.get_player_count()))
	})


func _apply_difficulty_start_for_client(config: Dictionary) -> void:
	var difficulty_value = int(config.get("current_difficulty", RunData.current_difficulty))
	RunData.current_difficulty = difficulty_value
	var has_host_wave_schedule = _run_config_has_host_wave_schedule(config)
	if has_host_wave_schedule:
		_apply_host_wave_schedule_from_run_config(config)
	else:
		RunData.reset_elites_spawn()
		RunData.init_elites_spawn()
		RunData.init_events_nightmare()
	RunData.enabled_dlcs = ProgressData.get_active_dlc_ids()

	var difficulty = ItemService.get_element(ItemService.difficulties, Keys.empty_hash, difficulty_value)
	if difficulty != null:
		for effect in difficulty.effects:
			effect.apply(0)

	for player_index in range(RunData.get_player_count()):
		var player_run_data = RunData.players_data[player_index]
		player_run_data.uses_ban = RunData.is_ban_mode_active
		player_run_data.remaining_ban_token = RunData.BAN_MAX_TOKEN

	if has_host_wave_schedule:
		_apply_host_wave_schedule_from_run_config(config)
	else:
		RunData.init_bosses_spawn()
	RunData.current_run_accessibility_settings = ProgressData.settings.enemy_scaling.duplicate()
	ProgressData.load_status = LoadStatus.SAVE_OK
	ProgressData.data["chal_hourglass_quit_wave"] = false


func _run_config_has_host_wave_schedule(config: Dictionary) -> bool:
	return config.has("elites_spawn") or config.has("events_spawn") or config.has("events_fog_of_war") or config.has("events_bullet_hell")


func _apply_host_wave_schedule_from_run_config(config: Dictionary) -> void:
	if config.has("constant_projectile"):
		RunData.constant_projectile = int(config.get("constant_projectile", RunData.constant_projectile))
	if config.has("nb_of_waves"):
		RunData.nb_of_waves = int(config.get("nb_of_waves", RunData.nb_of_waves))
	if config.has("elites_spawn"):
		RunData.elites_spawn = _sanitize_elites_spawn_array(config.get("elites_spawn", []))
	if config.has("bosses_spawn"):
		RunData.bosses_spawn = _duplicate_array_safe(config.get("bosses_spawn", []))
	if config.has("events_spawn"):
		RunData.events_spawn = _sanitize_events_spawn_array(config.get("events_spawn", []))
	if config.has("events_fog_of_war"):
		RunData.events_fog_of_war = _sanitize_int_array(config.get("events_fog_of_war", []))
	if config.has("events_bullet_hell"):
		RunData.events_bullet_hell = _sanitize_int_array(config.get("events_bullet_hell", []))


func _sanitize_elites_spawn_array(value) -> Array:
	var result = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) != TYPE_ARRAY or entry.size() < 3:
			continue
		var elite_id = entry[2]
		match typeof(elite_id):
			TYPE_STRING:
				elite_id = Keys.generate_hash(str(elite_id)) if str(elite_id) != "" else Keys.empty_hash
			TYPE_REAL:
				elite_id = int(elite_id)
			TYPE_INT:
				elite_id = int(elite_id)
			_:
				elite_id = Keys.empty_hash
		result.push_back([int(entry[0]), int(entry[1]), elite_id])
	return result


func _sanitize_events_spawn_array(value) -> Array:
	var result = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		if typeof(entry) != TYPE_ARRAY or entry.size() < 2:
			continue
		result.push_back([int(entry[0]), str(entry[1])])
	return result


func _sanitize_int_array(value) -> Array:
	var result = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for entry in value:
		result.push_back(int(entry))
	return result


func _duplicate_array_safe(value) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return []


func _data_object_to_sync_state(obj) -> Dictionary:
	if obj == null:
		return {}

	var data_type = "data"
	if obj is CharacterData:
		data_type = "character"
	elif obj is WeaponData:
		data_type = "weapon"
	elif obj is ItemData:
		data_type = "item"

	# Menu/run-config identity sync is id-only. Do not include resource_path/name or
	# serialized resource data in join/setup packets. All receivers resolve local
	# ItemService resources by id/hash.
	var state = {
		"type": data_type,
		"id": _safe_get(obj, "my_id", ""),
		"id_hash": _safe_get(obj, "my_id_hash", "")
	}
	var weapon_hash = _safe_get(obj, "weapon_id_hash", "")
	if str(weapon_hash) != "" and int(weapon_hash) != 0:
		state["weapon_id_hash"] = weapon_hash
	return state


func _find_character_data_by_sync_state(state):
	return _find_data_object_by_sync_state(ItemService.characters, state)


func _find_weapon_data_by_sync_state(state):
	return _find_data_object_by_sync_state(ItemService.weapons, state)


func _find_item_data_by_sync_state(state):
	return _find_data_object_by_sync_state(ItemService.items, state)


func _find_data_item_for_screen(screen: String, state):
	if typeof(state) != TYPE_DICTIONARY or state.empty():
		return null

	if screen == SCREEN_CHARACTER_SELECTION or screen == "character_selection":
		return _find_character_data_by_sync_state(state)
	if screen == SCREEN_WEAPON_SELECTION or screen == "weapon_selection":
		var weapon = _find_weapon_data_by_sync_state(state)
		if weapon != null:
			return weapon
		return _find_item_data_by_sync_state(state)

	return _find_data_object_by_sync_state(ItemService.characters, state)


func _find_data_object_by_sync_state(candidates: Array, state):
	if typeof(state) != TYPE_DICTIONARY or state.empty():
		return null

	var id = str(state.get("id", ""))
	var id_hash = str(state.get("id_hash", ""))
	var weapon_id_hash = str(state.get("weapon_id_hash", ""))
	var log_id = str(state.get("log", ""))

	for candidate in candidates:
		if candidate == null:
			continue
		if id != "" and str(_safe_get(candidate, "my_id", "")) == id:
			return candidate
		if id_hash != "" and str(_safe_get(candidate, "my_id_hash", "")) == id_hash:
			return candidate
		if weapon_id_hash != "" and str(_safe_get(candidate, "weapon_id_hash", "")) == weapon_id_hash:
			return candidate
		if log_id != "" and _get_item_id_for_log(candidate) == log_id:
			return candidate

	return null


func _resolve_character_data_for_run_config(state, player_index: int, target_screen: String):
	var character = _find_character_data_by_sync_state(state)
	if character != null:
		return character
	if typeof(state) != TYPE_DICTIONARY or state.empty():
		return null
	return _get_dlc_safe_fallback_character_data(state, player_index, target_screen)


func _get_dlc_safe_fallback_character_data(host_state: Dictionary, player_index: int, target_screen: String):
	# Host may own a DLC/modded character that the client cannot load. The client still
	# needs a non-null CharacterData before weapon_selection/main.tscn loads, because
	# vanilla WeaponSelection reads RunData.get_player_character(i).starting_weapons.
	# Use a local base-game placeholder instead of mirroring ProgressData or loading a
	# missing DLC resource. This keeps the client alive; Host remains authoritative for
	# menus/battle synchronization.
	var fallback = _find_character_data_by_id("character_well_rounded")
	if fallback == null and ItemService != null and typeof(ItemService.characters) == TYPE_ARRAY:
		for candidate in ItemService.characters:
			if candidate != null:
				fallback = candidate
				break
	if fallback == null:
		return null

	var warning_key = str(player_index) + ":" + str(host_state.get("id", host_state.get("log", ""))) + ":" + target_screen
	if not _dlc_safe_fallback_warning_keys.has(warning_key):
		_dlc_safe_fallback_warning_keys[warning_key] = true

	var copy = fallback.duplicate()
	copy.is_locked = false
	return copy


func _find_character_data_by_id(character_id: String):
	if character_id == "":
		return null
	if ItemService == null or typeof(ItemService.characters) != TYPE_ARRAY:
		return null
	for candidate in ItemService.characters:
		if candidate == null:
			continue
		if str(_safe_get(candidate, "my_id", "")) == character_id:
			return candidate
	return null


func build_local_client_content_capability_for_hello() -> Dictionary:
	# Sent by the Client once during hello/retry. Keep this id-only: the Host only
	# needs presence/absence for DLC/content gating, not serialized resources.
	var characters = _build_data_object_id_state_array(ItemService.characters) if ItemService != null else []
	var items = _build_data_object_id_state_array(ItemService.items) if ItemService != null else []
	var weapons = _build_data_object_id_state_array(ItemService.weapons) if ItemService != null else []
	return {
		"version": 3,
		"id_only": true,
		"characters": characters,
		"items": items,
		"weapons": weapons,
		"character_count": characters.size(),
		"item_count": items.size(),
		"weapon_count": weapons.size()
	}


func _build_data_object_id_state_array(pool) -> Array:
	var result = []
	if typeof(pool) != TYPE_ARRAY:
		return result
	for data in pool:
		if not _is_live_ref(data):
			continue
		var item_id = str(_safe_get(data, "my_id", ""))
		if item_id == "":
			continue
		var state = {
			"id": item_id,
			"id_hash": _safe_get(data, "my_id_hash", "")
		}
		var weapon_hash = _safe_get(data, "weapon_id_hash", "")
		if str(weapon_hash) != "" and int(weapon_hash) != 0:
			state["weapon_id_hash"] = weapon_hash
		result.append(state)
	return result


func _build_data_object_sync_state_array(pool) -> Array:
	# Backward-compatible wrapper for any older call sites. New hello packets use
	# _build_data_object_id_state_array() directly.
	return _build_data_object_id_state_array(pool)


func _invalidate_host_character_catalog_cache() -> void:
	_host_built_catalog_by_screen.erase(SCREEN_CHARACTER_SELECTION)
	_host_built_catalog_build_key_by_screen.erase(SCREEN_CHARACTER_SELECTION)
	_host_catalog_by_screen.erase(SCREEN_CHARACTER_SELECTION)
	_host_catalog_key_by_screen.erase(SCREEN_CHARACTER_SELECTION)
	_host_catalog_player_key_by_screen.erase(SCREEN_CHARACTER_SELECTION)
	_last_applied_catalog_key_by_screen.erase(SCREEN_CHARACTER_SELECTION)
	_clear_applied_catalog_player_keys_for_screen(SCREEN_CHARACTER_SELECTION)
	_last_host_dlc_gate_apply_key = ""
	_last_host_dlc_gate_log_key = ""
	_host_dlc_gate_logged_missing_keys.clear()


func receive_client_content_capability_from_hello(steam_id: String, message: Dictionary) -> bool:
	# Host-only. Returns true only when the Client's content list changed, so the
	# Steam layer can force one Host catalog rebroadcast. No continuous polling.
	if steam_id == "" or steam_id == "0":
		return false
	var capability = message.get("content_capability", {})
	if typeof(capability) != TYPE_DICTIONARY:
		return false
	var characters = capability.get("characters", [])
	if typeof(characters) != TYPE_ARRAY:
		return false

	var character_lookup = _build_lookup_from_sync_state_array(characters)
	if character_lookup.empty():
		# Fail open instead of locking the entire character page if the Client sent an
		# early/invalid list. Normal Clients still report all base-game characters, so
		# missing-DLC detection is not affected.
		return false

	var items = capability.get("items", [])
	var weapons = capability.get("weapons", [])
	if typeof(items) != TYPE_ARRAY:
		items = []
	if typeof(weapons) != TYPE_ARRAY:
		weapons = []
	var item_lookup = _build_lookup_from_sync_state_array(items)
	var weapon_lookup = _build_lookup_from_sync_state_array(weapons)

	var stable_states = []
	for state in characters:
		if typeof(state) != TYPE_DICTIONARY:
			continue
		stable_states.append({
			"kind": "character",
			"id": str(state.get("id", "")),
			"id_hash": str(state.get("id_hash", "")),
			"weapon_id_hash": str(state.get("weapon_id_hash", "")),
			"log": str(state.get("log", ""))
		})
	for state in items:
		if typeof(state) != TYPE_DICTIONARY:
			continue
		stable_states.append({
			"kind": "item",
			"id": str(state.get("id", "")),
			"id_hash": str(state.get("id_hash", "")),
			"log": str(state.get("log", ""))
		})
	for state in weapons:
		if typeof(state) != TYPE_DICTIONARY:
			continue
		stable_states.append({
			"kind": "weapon",
			"id": str(state.get("id", "")),
			"id_hash": str(state.get("id_hash", "")),
			"weapon_id_hash": str(state.get("weapon_id_hash", "")),
			"log": str(state.get("log", ""))
		})
	var key = to_json(stable_states)
	if str(_host_client_character_catalog_key_by_steam_id.get(steam_id, "")) == key and str(_host_client_shop_content_catalog_key_by_steam_id.get(steam_id, "")) == key:
		return false

	_host_client_character_catalog_key_by_steam_id[steam_id] = key
	_host_client_shop_content_catalog_key_by_steam_id[steam_id] = key
	_host_client_character_lookup_by_steam_id[steam_id] = character_lookup
	if not item_lookup.empty():
		_host_client_item_lookup_by_steam_id[steam_id] = item_lookup
	else:
		_host_client_item_lookup_by_steam_id.erase(steam_id)
	if not weapon_lookup.empty():
		_host_client_weapon_lookup_by_steam_id[steam_id] = weapon_lookup
	else:
		_host_client_weapon_lookup_by_steam_id.erase(steam_id)
	_host_common_shop_fallback_cache.clear()
	_host_dlc_gate_catalog_dirty = true
	_invalidate_host_character_catalog_cache()
	return true


func _get_active_remote_client_ids_for_dlc_gate() -> Array:
	var result = []
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("get_remote_steam_id"):
		for player_index in range(RunData.get_player_count()):
			var steam_id = str(slot_manager.get_remote_steam_id(player_index))
			if steam_id == "" or steam_id == "0" or result.has(steam_id):
				continue
			result.append(steam_id)
		return result

	# Fallback for very early hello handling before slot remapping has settled.
	for steam_id_value in _host_client_character_lookup_by_steam_id.keys():
		var steam_id = str(steam_id_value)
		if steam_id != "" and steam_id != "0" and not result.has(steam_id):
			result.append(steam_id)
	return result


func _get_clients_missing_character(item) -> Array:
	var missing = []
	if not _is_live_ref(item):
		return missing
	var active_ids = _get_active_remote_client_ids_for_dlc_gate()
	for steam_id_value in active_ids:
		var steam_id = str(steam_id_value)
		if not _host_client_character_lookup_by_steam_id.has(steam_id):
			# Unknown means old/early client. Do not lock on unknown capability.
			continue
		var lookup = _host_client_character_lookup_by_steam_id.get(steam_id, {})
		if typeof(lookup) != TYPE_DICTIONARY or lookup.empty():
			continue
		if not _data_object_matches_lookup(item, lookup):
			missing.append(steam_id)
	return missing

func _clear_ready_for_characters_missing_client_content(selection: Node) -> void:
	if not _is_live_ref(selection):
		return
	if _get_selection_screen(selection) != SCREEN_CHARACTER_SELECTION:
		return
	var selected_flags = selection.get("_has_player_selected")
	if typeof(selected_flags) != TYPE_ARRAY:
		return
	for player_index in range(RunData.get_player_count()):
		if player_index < 0 or player_index >= selected_flags.size():
			continue
		if not bool(selected_flags[player_index]):
			continue
		var selected_item = _get_selected_item_for_player(selection, player_index)
		var missing_clients = _get_clients_missing_character(selected_item)
		if missing_clients.empty():
			continue
		_clear_client_local_ready_after_send(selection, player_index)


func apply_host_dlc_gate_now() -> bool:
	_host_dlc_gate_catalog_dirty = true
	return _try_apply_host_dlc_gate_to_current_selection()


func _try_apply_host_dlc_gate_to_current_selection(fast_screen: String = "") -> bool:
	# Host UI application is event-gated: the expensive catalog/inventory walk only
	# happens after a Client capability changes or after CharacterSelection is rebuilt.
	if not _is_game_host():
		return false
	if _host_client_character_lookup_by_steam_id.empty():
		return false
	if fast_screen != "" and fast_screen != SCREEN_CHARACTER_SELECTION:
		return false
	var selection = _find_current_selection_node()
	if selection == null:
		return false
	var screen = _get_selection_screen(selection)
	if screen != SCREEN_CHARACTER_SELECTION:
		return false
	if not _selection_inventories_ready(selection):
		return false
	var selection_id = str(selection.get_instance_id())
	var cap_key_parts = []
	for steam_id in _host_client_character_catalog_key_by_steam_id.keys():
		cap_key_parts.append(str(steam_id) + "=" + str(_host_client_character_catalog_key_by_steam_id.get(steam_id, "")))
	cap_key_parts.sort()
	var apply_key = selection_id + "|" + ";".join(cap_key_parts)
	if not _host_dlc_gate_catalog_dirty and _last_host_dlc_gate_apply_key == apply_key:
		return true

	var catalog = _build_host_catalog_for_screen(SCREEN_CHARACTER_SELECTION)
	var players = catalog.get("players", [])
	if typeof(players) != TYPE_ARRAY or players.empty():
		return false
	for player_catalog in players:
		if typeof(player_catalog) != TYPE_DICTIONARY:
			continue
		var player_index = int(player_catalog.get("player_index", -1))
		if player_index < 0 or player_index >= RunData.get_player_count():
			continue
		_apply_online_catalog_to_player_inventory(selection, SCREEN_CHARACTER_SELECTION, player_index, player_catalog)
	_clear_ready_for_characters_missing_client_content(selection)
	_last_host_dlc_gate_apply_key = apply_key
	_host_dlc_gate_catalog_dirty = false
	return true


func _make_host_catalog_build_key(screen: String, selection: Node) -> String:
	var parts = [screen, str(selection.get_instance_id()), str(RunData.get_player_count())]
	if screen == SCREEN_CHARACTER_SELECTION:
		var active_ids = _get_active_remote_client_ids_for_dlc_gate()
		active_ids.sort()
		for steam_id_value in active_ids:
			var steam_id = str(steam_id_value)
			parts.append(steam_id + "=" + str(_host_client_character_catalog_key_by_steam_id.get(steam_id, "")))
	return "|".join(parts)


func _build_host_catalog_for_screen(screen: String) -> Dictionary:
	# Character DLC/catalog data is stable until client capability, member set, or the
	# CharacterSelection node changes. Reuse it for duplicate hello/menu_focus/setup checks.
	if screen != SCREEN_CHARACTER_SELECTION:
		return _build_host_catalog_for_screen_uncached(screen)
	var selection = _find_current_selection_node()
	if selection == null:
		return {"screen": screen, "players": []}
	if _get_selection_screen(selection) != screen:
		return {"screen": screen, "players": []}
	var build_key = _make_host_catalog_build_key(screen, selection)
	if _host_built_catalog_by_screen.has(screen) and str(_host_built_catalog_build_key_by_screen.get(screen, "")) == build_key:
		return _get_dict_or_empty(_host_built_catalog_by_screen.get(screen, {}))
	var catalog = _build_host_catalog_for_screen_uncached(screen)
	_host_built_catalog_by_screen[screen] = catalog
	_host_built_catalog_build_key_by_screen[screen] = build_key
	return catalog


func _build_host_catalog_for_screen_uncached(screen: String) -> Dictionary:
	var selection = _find_current_selection_node()
	if selection == null:
		return {"screen": screen, "players": []}
	if _get_selection_screen(selection) != screen:
		return {"screen": screen, "players": []}

	var players = []
	for player_index in range(RunData.get_player_count()):
		var possible = []
		var unlocked_lookup = _get_host_unlocked_lookup_for_selection(selection, player_index)
		if selection.has_method("_get_all_possible_elements"):
			possible = selection._get_all_possible_elements(player_index)
		if typeof(possible) != TYPE_ARRAY:
			possible = []

		var options = []
		for item in possible:
			if not _is_live_ref(item):
				continue
			var state = _data_object_to_sync_state(item)
			var host_unlocked = _data_object_matches_lookup(item, unlocked_lookup)
			var client_content_available = true
			var missing_clients = []
			if screen == SCREEN_CHARACTER_SELECTION and host_unlocked:
				missing_clients = _get_clients_missing_character(item)
				client_content_available = missing_clients.empty()
			var host_selectable = host_unlocked and client_content_available
			state["host_selectable"] = host_selectable
			state["host_locked"] = not host_selectable
			state["host_unlocked"] = host_unlocked
			state["client_content_available"] = client_content_available
			if not client_content_available:
				state["blocked_by_client_dlc"] = true
				state["missing_client_steam_ids"] = missing_clients
				var log_key = _get_item_id_for_log(item) + ":" + ",".join(missing_clients)
				if not _host_dlc_gate_logged_missing_keys.has(log_key):
					_host_dlc_gate_logged_missing_keys[log_key] = true
					_last_host_dlc_gate_log_key = log_key
			options.append(state)

		players.append({
			"player_index": player_index,
			"options": options
		})

	return {
		"screen": screen,
		"players": players
	}


func _store_host_catalog(screen: String, catalog: Dictionary) -> void:
	if screen == "" or typeof(catalog) != TYPE_DICTIONARY or catalog.empty():
		return
	var players = catalog.get("players", [])
	if typeof(players) == TYPE_ARRAY and players.empty() and _host_catalog_by_screen.has(screen):
		return

	# Host setup / menu_scene_state can arrive repeatedly while focus is moving. The
	# visible selection inventory only needs to be rebuilt when catalog content changes;
	# otherwise 3+ player lobbies keep walking every inventory and recomputing focus links.
	var catalog_key = _make_catalog_stable_key(catalog)
	if _host_catalog_by_screen.has(screen) and str(_host_catalog_key_by_screen.get(screen, "")) == catalog_key:
		return

	_host_catalog_by_screen[screen] = catalog
	_host_catalog_key_by_screen[screen] = catalog_key
	_host_catalog_player_key_by_screen[screen] = _build_catalog_player_key_map(catalog)
	_last_applied_catalog_key_by_screen.erase(screen)
	_clear_applied_catalog_player_keys_for_screen(screen)


func _make_catalog_stable_key(catalog: Dictionary) -> String:
	if typeof(catalog) != TYPE_DICTIONARY:
		return ""
	return to_json(catalog)


func _build_catalog_player_key_map(catalog: Dictionary) -> Dictionary:
	var result = {}
	if typeof(catalog) != TYPE_DICTIONARY:
		return result
	var players = catalog.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return result
	for player_catalog in players:
		if typeof(player_catalog) != TYPE_DICTIONARY:
			continue
		var player_index = int(player_catalog.get("player_index", -1))
		if player_index < 0:
			continue
		result[player_index] = to_json(player_catalog)
	return result


func _get_catalog_player_stable_key(screen: String, player_index: int, player_catalog: Dictionary) -> String:
	var by_player = _host_catalog_player_key_by_screen.get(screen, {})
	if typeof(by_player) == TYPE_DICTIONARY and by_player.has(player_index):
		return str(by_player.get(player_index, ""))
	if typeof(player_catalog) == TYPE_DICTIONARY:
		return to_json(player_catalog)
	return ""


func _clear_applied_catalog_player_keys_for_screen(screen: String) -> void:
	var prefix = screen + "|"
	for key in _last_applied_catalog_player_key_by_inventory.keys():
		if str(key).begins_with(prefix):
			_last_applied_catalog_player_key_by_inventory.erase(key)

func _try_apply_online_catalog_to_current_selection() -> bool:
	if _local_client_steam_id == "":
		return false
	var selection = _find_current_selection_node()
	if selection == null:
		return false
	var screen = _get_selection_screen(selection)
	if not _is_client_interactive_selection_screen(screen):
		return false
	if not _host_catalog_by_screen.has(screen):
		return false
	var catalog = _get_dict_or_empty(_host_catalog_by_screen.get(screen, {}))
	if catalog.empty():
		return false
	if not _selection_inventories_ready(selection):
		return false

	var catalog_key = str(_host_catalog_key_by_screen.get(screen, ""))
	if catalog_key == "":
		catalog_key = _make_catalog_stable_key(catalog)
		_host_catalog_key_by_screen[screen] = catalog_key
		_host_catalog_player_key_by_screen[screen] = _build_catalog_player_key_map(catalog)

	var key = str(selection.get_instance_id()) + "|" + catalog_key
	if str(_last_applied_catalog_key_by_screen.get(screen, "")) == key:
		return true

	var players = catalog.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return false

	var changed = false
	for player_catalog in players:
		if typeof(player_catalog) != TYPE_DICTIONARY:
			continue
		var player_index = int(player_catalog.get("player_index", -1))
		if player_index < 0 or player_index >= RunData.get_player_count():
			continue
		if _apply_online_catalog_to_player_inventory(selection, screen, player_index, player_catalog):
			changed = true

	_last_applied_catalog_key_by_screen[screen] = key
	if changed:
		pass
	return true


func _selection_inventories_ready(selection: Node) -> bool:
	if not selection.has_method("_get_inventories"):
		return false
	var inventories = selection._get_inventories()
	if typeof(inventories) != TYPE_ARRAY or inventories.empty():
		return false
	var required_count = RunData.get_player_count()
	if required_count < 1:
		required_count = 1
	if required_count > inventories.size():
		required_count = inventories.size()
	for i in range(required_count):
		var inventory = inventories[i]
		if not _is_live_ref(inventory):
			return false
		if inventory.get_child_count() <= 0:
			return false
	return true


func _apply_online_catalog_to_player_inventory(selection: Node, screen: String, player_index: int, player_catalog: Dictionary) -> bool:
	if not selection.has_method("_get_inventories"):
		return false
	var inventories = selection._get_inventories()
	if typeof(inventories) != TYPE_ARRAY or inventories.empty():
		return false
	var inv_index = player_index % inventories.size()
	var inventory = inventories[inv_index]
	if not _is_live_ref(inventory):
		return false

	var cache_slot = screen + "|" + str(selection.get_instance_id()) + "|" + str(inventory.get_instance_id()) + "|" + str(player_index)
	var player_key = _get_catalog_player_stable_key(screen, player_index, player_catalog)
	var apply_key = str(inventory.get_child_count()) + "|" + player_key
	if str(_last_applied_catalog_player_key_by_inventory.get(cache_slot, "")) == apply_key:
		return false

	var selectable_lookup = _build_selectable_lookup_from_player_catalog(player_catalog)
	var existing_lookup = {}
	var changed = false

	for child in inventory.get_children():
		if not _is_live_ref(child):
			continue
		if _safe_get(child, "is_random", false):
			continue
		var item = _safe_get(child, "item", null)
		if not _is_live_ref(item):
			continue
		_add_item_ids_to_lookup(existing_lookup, item)
		var host_selectable = _data_object_matches_lookup(item, selectable_lookup)
		if _apply_catalog_state_to_inventory_element(child, inventory, screen, host_selectable):
			changed = true

	for state in _get_catalog_options_for_player(player_catalog, true):
		if typeof(state) != TYPE_DICTIONARY:
			continue
		if _state_matches_lookup(state, existing_lookup):
			continue
		var data_item = _find_data_item_for_screen(screen, state)
		if not _is_live_ref(data_item):
			continue
		var new_item = data_item.duplicate()
		new_item.is_locked = false
		inventory.add_element(new_item, false, true)
		_add_item_ids_to_lookup(existing_lookup, new_item)
		changed = true

	_last_applied_catalog_player_key_by_inventory[cache_slot] = apply_key
	if changed and inventory.has_method("queue_set_focus_neighbours"):
		inventory.queue_set_focus_neighbours()
	return changed

func _apply_catalog_state_to_inventory_element(element, inventory: Node, screen: String, host_selectable: bool) -> bool:
	if not _is_live_ref(element):
		return false
	var item = _safe_get(element, "item", null)
	if not _is_live_ref(item):
		return false

	var current_locked = bool(_safe_get(item, "is_locked", false))

	if host_selectable:
		var already_selectable = element.visible and not current_locked
		if element is BaseButton:
			already_selectable = already_selectable and not element.disabled
		if element is Control:
			already_selectable = already_selectable and element.focus_mode == Control.FOCUS_ALL
		already_selectable = already_selectable and not bool(_safe_get(element, "is_special", false)) and not bool(_safe_get(element, "is_random", false)) and element.modulate.a >= 0.99
		if already_selectable:
			return false
		var item_copy_selectable = item.duplicate()
		item_copy_selectable.is_locked = false
		element.visible = true
		if element is BaseButton:
			element.disabled = false
		if element is Control:
			element.focus_mode = Control.FOCUS_ALL
		element.is_special = false
		element.is_random = false
		element.modulate.a = 1.0
		element.set_element(item_copy_selectable)
		return true

	if screen == SCREEN_WEAPON_SELECTION:
		# Official weapon selection normally hides locked initial weapons/items.
		var already_hidden_locked = not element.visible and current_locked
		if element is BaseButton:
			already_hidden_locked = already_hidden_locked and element.disabled
		if element is Control:
			already_hidden_locked = already_hidden_locked and element.focus_mode == Control.FOCUS_NONE
		if already_hidden_locked:
			return false
		var item_copy_weapon = item.duplicate()
		item_copy_weapon.is_locked = true
		element.visible = false
		if element is BaseButton:
			element.disabled = true
		if element is Control:
			element.focus_mode = Control.FOCUS_NONE
		element.item = item_copy_weapon
		return true

	# Character selection keeps locked characters visible as lock tiles.
	var already_character_locked = element.visible and current_locked and bool(_safe_get(element, "is_special", false)) and not bool(_safe_get(element, "is_random", false)) and element.modulate.a <= 0.51
	if element is BaseButton:
		already_character_locked = already_character_locked and not element.disabled
	if element is Control:
		already_character_locked = already_character_locked and element.focus_mode == Control.FOCUS_ALL
	if already_character_locked:
		return false

	var item_copy_character = item.duplicate()
	item_copy_character.is_locked = true
	element.visible = true
	if element is BaseButton:
		element.disabled = false
	if element is Control:
		element.focus_mode = Control.FOCUS_ALL
	element.is_special = true
	element.is_random = false
	element.modulate.a = 0.5
	var locked_icon = _safe_get(inventory, "locked_icon", null)
	if locked_icon != null:
		element.set_icon(locked_icon)
	element.item = item_copy_character
	return true

func _get_catalog_options_for_player(player_catalog: Dictionary, selectable_only: bool = false) -> Array:
	var result = []
	if typeof(player_catalog) != TYPE_DICTIONARY:
		return result

	if player_catalog.has("options"):
		var options = player_catalog.get("options", [])
		if typeof(options) == TYPE_ARRAY:
			for state in options:
				if typeof(state) != TYPE_DICTIONARY:
					continue
				if selectable_only and not bool(state.get("host_selectable", false)):
					continue
				result.append(state)
		return result

	# Compatibility with the older menu_scene_state availability format. In that format
	# every entry under available is already Host-selectable and has no host_selectable flag.
	var available = player_catalog.get("available", [])
	if typeof(available) != TYPE_ARRAY:
		return result
	for state in available:
		if typeof(state) != TYPE_DICTIONARY:
			continue
		var normalized = state.duplicate(true)
		normalized["host_selectable"] = true
		normalized["host_locked"] = false
		result.append(normalized)
	return result


func _build_selectable_lookup_from_player_catalog(player_catalog: Dictionary) -> Dictionary:
	var lookup = {}
	for state in _get_catalog_options_for_player(player_catalog, true):
		_add_state_ids_to_lookup(lookup, state)
	return lookup


func _build_known_lookup_from_player_catalog(player_catalog: Dictionary) -> Dictionary:
	var lookup = {}
	for state in _get_catalog_options_for_player(player_catalog, false):
		_add_state_ids_to_lookup(lookup, state)
	return lookup


func _get_host_selectable_states_for_player(screen: String, player_index: int) -> Array:
	var result = []
	if _local_client_steam_id == "" or not _host_catalog_by_screen.has(screen):
		return result
	var player_catalog = _get_player_catalog(screen, player_index)
	if player_catalog.empty():
		return result
	for state in _get_catalog_options_for_player(player_catalog, true):
		if typeof(state) == TYPE_DICTIONARY:
			result.append(state)
	return result


func _pick_random_host_selectable_element(selection: Node, screen: String, player_index: int):
	var states = _get_host_selectable_states_for_player(screen, player_index)
	if states.empty():
		return null

	# When the player presses the random tile after already selecting something, avoid
	# immediately resolving back to the same item when another Host-selectable option exists.
	# Otherwise it looks like the random button did nothing.
	var selected_state = _element_to_state(_get_selected_element_for_player(selection, player_index))
	if states.size() > 1 and typeof(selected_state) == TYPE_DICTIONARY and not selected_state.empty():
		var filtered_states = []
		for candidate_state in states:
			if typeof(candidate_state) != TYPE_DICTIONARY:
				continue
			if _element_states_match(candidate_state, selected_state):
				continue
			filtered_states.append(candidate_state)
		if not filtered_states.empty():
			states = filtered_states

	var picked_state = Utils.get_rand_element(states)
	if typeof(picked_state) != TYPE_DICTIONARY:
		return null
	var element = _find_element_by_state(selection, player_index, picked_state, true)
	if _is_live_ref(element):
		return element

	# If the client inventory has not been rebuilt yet, create a transient UI element for
	# the Host-available item so the local panel/highlight can still show the concrete pick.
	var data_item = _find_data_item_for_screen(screen, picked_state)
	if not _is_live_ref(data_item):
		return null
	if selection.has_method("_get_inventories"):
		var inventories = selection._get_inventories()
		if typeof(inventories) == TYPE_ARRAY and not inventories.empty():
			var inventory = inventories[player_index % inventories.size()]
			if _is_live_ref(inventory) and inventory.has_method("add_element"):
				var new_item = data_item.duplicate()
				new_item.is_locked = false
				inventory.add_element(new_item, false, true)
				if inventory.has_method("queue_set_focus_neighbours"):
					inventory.queue_set_focus_neighbours()
				return _find_element_by_state(selection, player_index, picked_state, true)
	return null


func _get_player_catalog(screen: String, player_index: int) -> Dictionary:
	if not _host_catalog_by_screen.has(screen):
		return {}
	var catalog = _get_dict_or_empty(_host_catalog_by_screen.get(screen, {}))
	var players = catalog.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return {}
	for player_catalog in players:
		if typeof(player_catalog) == TYPE_DICTIONARY and int(player_catalog.get("player_index", -1)) == player_index:
			return player_catalog
	return {}


func _is_host_catalog_item_selectable(screen: String, player_index: int, item_state) -> bool:
	if typeof(item_state) != TYPE_DICTIONARY or item_state.empty():
		return false
	if _local_client_steam_id == "":
		return true
	if not _host_catalog_by_screen.has(screen):
		# No catalog yet: do not let client confirm; focus messages may wait too.
		return false
	var player_catalog = _get_player_catalog(screen, player_index)
	if player_catalog.empty():
		return false
	var selectable_lookup = _build_selectable_lookup_from_player_catalog(player_catalog)
	return _state_matches_lookup(item_state, selectable_lookup)


func _is_host_catalog_item_known(screen: String, player_index: int, item_state) -> bool:
	if typeof(item_state) != TYPE_DICTIONARY or item_state.empty():
		return false
	if _local_client_steam_id == "":
		return true
	if not _host_catalog_by_screen.has(screen):
		return false
	var player_catalog = _get_player_catalog(screen, player_index)
	if player_catalog.empty():
		return false
	var known_lookup = _build_known_lookup_from_player_catalog(player_catalog)
	return _state_matches_lookup(item_state, known_lookup)


func _state_matches_lookup(state: Dictionary, lookup: Dictionary) -> bool:
	if lookup.empty():
		return false
	for key in ["id", "id_hash", "weapon_id_hash", "resource_path", "log"]:
		var value = str(state.get(key, ""))
		if value != "" and lookup.has(value):
			return true
	return false


func _add_item_ids_to_lookup(lookup: Dictionary, item) -> void:
	if not _is_live_ref(item):
		return
	var state = _data_object_to_sync_state(item)
	_add_state_ids_to_lookup(lookup, state)


func _install_client_press_intercept(selection: Node, screen: String, player_index: int) -> void:
	if _local_client_steam_id == "":
		return
	if not _is_client_interactive_selection_screen(screen):
		return
	if not selection.has_method("_get_inventories"):
		return

	# CharacterSelection can be found before its onready Inventory references are ready.
	# Do not mark this selection as intercepted until every returned Inventory is live
	# and the client callback is actually connected; otherwise later retries are skipped.
	var inventories = selection._get_inventories()
	if typeof(inventories) != TYPE_ARRAY or inventories.empty():
		return
	for inventory in inventories:
		if not _is_live_ref(inventory):
			return

	var selection_id = selection.get_instance_id()
	if _client_intercept_selection_instance_id == selection_id:
		return

	for inv_index in range(inventories.size()):
		var inventory = inventories[inv_index]
		if inventory.is_connected("element_pressed", selection, "_on_element_pressed"):
			inventory.disconnect("element_pressed", selection, "_on_element_pressed")
		if not inventory.is_connected("element_pressed", self, "_on_client_inventory_element_pressed"):
			inventory.connect("element_pressed", self, "_on_client_inventory_element_pressed", [selection, screen, inv_index])
		if not inventory.is_connected("element_pressed", self, "_on_client_inventory_element_pressed"):
			return

	_client_intercept_selection_instance_id = selection_id



func _is_player_currently_ready_with_item(selection: Node, player_index: int, item_state: Dictionary) -> bool:
	if not _is_live_ref(selection):
		return false
	var selected_flags = selection.get("_has_player_selected")
	if typeof(selected_flags) != TYPE_ARRAY or player_index < 0 or player_index >= selected_flags.size():
		return false
	if not bool(selected_flags[player_index]):
		return false
	var selected_element = _get_selected_element_for_player(selection, player_index)
	return _element_states_match(_element_to_state(selected_element), item_state)


func _reset_local_select_dedup_for_player(player_index: int) -> void:
	if _local_client_steam_id == "":
		return
	var local_player_index = _get_local_client_player_index()
	if local_player_index < 0 or local_player_index == player_index:
		_last_sent_local_select_key = ""


func _on_client_inventory_element_pressed(element, selection: Node, screen: String, inventory_player_index: int) -> void:
	if _local_client_steam_id == "":
		return
	if not _is_live_ref(selection) or not _is_live_ref(element):
		return
	var current_screen = _get_selection_screen(selection)
	if current_screen != screen:
		return
	if not _is_client_interactive_selection_screen(screen):
		return

	var player_index = FocusEmulatorSignal.get_player_index(element)
	if player_index < 0:
		player_index = inventory_player_index
	var local_player_index = _get_local_client_player_index()
	if player_index != local_player_index:
		return

	var item_state = _element_to_state(element)
	var concrete_element = element
	var pressed_random = bool(_safe_get(element, "is_random", false))
	if pressed_random:
		concrete_element = _pick_random_host_selectable_element(selection, screen, player_index)
		if not _is_live_ref(concrete_element):
			_clear_client_local_ready_after_send(selection, player_index)
			return
		item_state = _element_to_state(concrete_element)

	if not _is_host_catalog_item_selectable(screen, player_index, item_state):
		_clear_client_local_ready_after_send(selection, player_index)
		return

	var item_id = _get_item_id_from_state(item_state)
	if item_id == "":
		return
	var msg_type = "select_character" if screen == SCREEN_CHARACTER_SELECTION else "select_weapon"
	var key = screen + ":" + str(player_index) + ":" + msg_type + ":" + item_id
	if not pressed_random and key == _last_sent_local_select_key and _is_player_currently_ready_with_item(selection, player_index, item_state):
		return
	_last_sent_local_select_key = key
	_queued_local_client_menu_messages.append({
		"msg_type": msg_type,
		"screen": screen,
		"item_id": item_id,
		"item_id_hash": item_state.get("id_hash", ""),
		"item_log": item_state.get("log", "")
	})
	_apply_focus_element(selection, player_index, concrete_element)
	_clear_client_local_ready_after_send(selection, player_index)


func _build_host_availability_for_scene(screen: String) -> Dictionary:
	# Host authoritative menu rule:
	# Client local progression must not decide what can be selected. The host sends the
	# exact characters/weapons/items that are available on the host for each player slot.
	if screen != SCREEN_CHARACTER_SELECTION and screen != SCREEN_WEAPON_SELECTION:
		return {}

	var selection = _find_current_selection_node()
	if selection == null:
		return {}

	var current_screen = _get_selection_screen(selection)
	if current_screen != screen:
		return {}

	var players = []
	for player_index in range(RunData.get_player_count()):
		var unlocked_lookup = _get_host_unlocked_lookup_for_selection(selection, player_index)
		var available = []
		var possible = []
		if selection.has_method("_get_all_possible_elements"):
			possible = selection._get_all_possible_elements(player_index)
		if typeof(possible) != TYPE_ARRAY:
			possible = []

		for item in possible:
			if not _is_live_ref(item):
				continue
			if _data_object_matches_lookup(item, unlocked_lookup):
				available.append(_data_object_to_sync_state(item))

		players.append({
			"player_index": player_index,
			"available": available
		})

	return {
		"screen": screen,
		"mode": "host_authoritative_unlocks",
		"players": players
	}


func _get_host_unlocked_lookup_for_selection(selection: Node, player_index: int) -> Dictionary:
	var result = {}
	var unlocked = []
	if selection != null and selection.has_method("_get_unlocked_elements"):
		unlocked = selection._get_unlocked_elements(player_index)
	if typeof(unlocked) != TYPE_ARRAY:
		return result

	for id_value in unlocked:
		result[str(id_value)] = true
	return result


func _data_object_matches_lookup(item, lookup: Dictionary) -> bool:
	if not _is_live_ref(item):
		return false
	if lookup.empty():
		return false

	var my_id_hash = str(_safe_get(item, "my_id_hash", ""))
	if my_id_hash != "" and lookup.has(my_id_hash):
		return true

	var weapon_id_hash = str(_safe_get(item, "weapon_id_hash", ""))
	if weapon_id_hash != "" and lookup.has(weapon_id_hash):
		return true

	var my_id = str(_safe_get(item, "my_id", ""))
	if my_id != "" and lookup.has(my_id):
		return true

	var resource_path = _get_resource_path(item)
	if resource_path != "" and lookup.has(resource_path):
		return true

	var log_id = _get_item_id_for_log(item)
	if log_id != "" and lookup.has(log_id):
		return true

	return false


func _queue_availability_from_menu_scene_state(state: Dictionary) -> void:
	if typeof(state) != TYPE_DICTIONARY:
		return

	var availability = state.get("availability", {})
	if typeof(availability) != TYPE_DICTIONARY or availability.empty():
		return

	_last_availability_from_host = availability
	_pending_availability_from_host = availability
	var screen = str(availability.get("screen", ""))
	if screen != "":
		_store_host_catalog(screen, availability)

func _append_unique_string_value(array: Array, value) -> void:
	var normalized = str(value)
	if normalized == "":
		return
	if not array.has(normalized):
		array.append(normalized)


func _append_unique_id_value(array: Array, value) -> void:
	# IMPORTANT: Brotato stores these arrays as int hashes.
	# P2P messages go through to_json()/parse_json(), and Godot 3 may parse
	# numeric JSON values as TYPE_REAL. Array.has() is type-sensitive, so
	# float(123) or String("123") will not unlock an element whose hash is int(123).
	var normalized = _normalize_progress_hash_value(value)
	if _is_empty_id_value(normalized):
		return
	if not array.has(normalized):
		array.append(normalized)


func _normalize_progress_hash_value(value):
	if value == null:
		return null

	var value_type = typeof(value)
	if value_type == TYPE_INT:
		return int(value)
	if value_type == TYPE_REAL:
		return int(value)
	if value_type == TYPE_STRING:
		if value == "":
			return null
		if value.is_valid_integer():
			return int(value)
		if value.is_valid_float():
			return int(float(value))
		# Keep a string fallback only for unusual modded data that really uses string ids.
		return value

	return value


func _is_empty_id_value(value) -> bool:
	if value == null:
		return true
	if typeof(value) == TYPE_STRING and value == "":
		return true
	return false

func _append_unique_string(array: Array, value: String) -> void:
	if value == "":
		return
	if not array.has(value):
		array.append(value)

func restore_progress_mirror() -> void:
	_progress_mirror_active = false
	_last_applied_progress_mirror_key = ""


func _build_lookup_from_sync_state_array(states) -> Dictionary:
	var result = {}
	if typeof(states) != TYPE_ARRAY:
		return result

	for state in states:
		if typeof(state) != TYPE_DICTIONARY:
			continue
		_add_state_ids_to_lookup(result, state)
	return result


func _add_state_ids_to_lookup(lookup: Dictionary, state: Dictionary) -> void:
	for key in ["id", "id_hash", "weapon_id_hash", "resource_path", "log"]:
		var value = str(state.get(key, ""))
		if value != "":
			lookup[value] = true

func _clear_selected_flag_only(selection: Node, player_index: int) -> void:
	var selected_flags = selection.get("_has_player_selected")
	if typeof(selected_flags) == TYPE_ARRAY and player_index >= 0 and player_index < selected_flags.size():
		selected_flags[player_index] = false

	var panels = selection._get_panels() if selection.has_method("_get_panels") else []
	if typeof(panels) == TYPE_ARRAY and player_index >= 0 and player_index < panels.size():
		if _is_live_ref(panels[player_index]):
			panels[player_index].selected = false
	_reset_local_select_dedup_for_player(player_index)

func _collect_focus_emulator_nodes() -> Array:
	var result = []
	var root = get_tree().root
	if root == null:
		return result
	_collect_focus_emulator_nodes_recursive(root, result)
	return result


func _collect_focus_emulator_nodes_recursive(node: Node, result: Array) -> void:
	if not _is_live_ref(node):
		return

	if _is_focus_emulator_like_node(node):
		result.append(node)

	for child in node.get_children():
		if child is Node:
			_collect_focus_emulator_nodes_recursive(child, result)


func _is_focus_emulator_like_node(node: Node) -> bool:
	if not _is_live_ref(node):
		return false
	if not _has_property(node, "focused_control"):
		return false
	if not _has_property(node, "player_index"):
		return false
	if not node.has_method("_set_focused_control_with_style"):
		return false
	return true


func _clear_focus_emulator_live_control(focus_emulator: Node) -> void:
	if not _is_live_ref(focus_emulator):
		return

	var focused = _safe_get(focus_emulator, "focused_control", null)
	if _is_live_ref(focused):
		if focus_emulator.has_method("_clear_focused_control"):
			focus_emulator._clear_focused_control()
		elif _has_property(focus_emulator, "focused_control"):
			focus_emulator.set("focused_control", null)
	else:
		_neutralize_stale_focus_emulator(focus_emulator, false)


func _neutralize_stale_focus_emulator(focus_emulator: Node, disable_device: bool) -> void:
	if not _is_live_ref(focus_emulator):
		return

	# Avoid setting focused_control = null when it already points to a freed
	# Control: the vanilla setter can call _clear_focused_control() and touch the
	# freed object. Instead, make the emulator inert and invisible until a new
	# valid focus is assigned.
	if disable_device and _has_property(focus_emulator, "_device"):
		focus_emulator.set("_device", -1)
	if _has_property(focus_emulator, "_focused_control_index"):
		focus_emulator.set("_focused_control_index", -1)
	if _has_property(focus_emulator, "_focused_parent"):
		focus_emulator.set("_focused_parent", null)
	if focus_emulator is CanvasItem:
		focus_emulator.visible = false


func _get_scene_path_for_screen(screen: String) -> String:
	if screen == SCREEN_CHARACTER_SELECTION:
		return MenuData.character_selection_scene
	if screen == SCREEN_WEAPON_SELECTION:
		return MenuData.weapon_selection_scene
	if screen == SCREEN_DIFFICULTY_SELECTION:
		return MenuData.difficulty_selection_scene
	if screen == SCREEN_GAME:
		return MenuData.game_scene
	if screen == SCREEN_SHOP or screen == "shop":
		if RunData != null and RunData.has_method("get_shop_scene_path"):
			return RunData.get_shop_scene_path()
		if RunData != null and bool(RunData.get("is_coop_run")):
			return "res://ui/menus/shop/coop_shop.tscn"
		return MenuData.shop_scene
	return ""


func _is_shop_scene_path(scene_path: String) -> bool:
	var lowered = str(scene_path).to_lower()
	if lowered == "":
		return false
	if lowered == "res://ui/menus/shop/shop.tscn" or lowered == "res://ui/menus/shop/coop_shop.tscn":
		return true
	return lowered.find("/ui/menus/shop/") != -1 or lowered.find("ui/menus/shop/") != -1


func _get_current_scene_resource_path() -> String:
	var current = get_tree().current_scene
	if current == null:
		return ""
	return str(_safe_get(current, "filename", ""))


func _clear_focus_emulators_before_client_scene_change(from_screen: String, to_screen: String) -> void:
	# Client scene following must not leave any scene-local FocusEmulator drawing a
	# control from the scene being freed. Clear all FocusEmulator-like nodes, not
	# only Utils.get_focus_emulator(0..3).
	for focus_emulator in _collect_focus_emulator_nodes():
		if not _is_live_ref(focus_emulator):
			continue

		if _has_property(focus_emulator, "_device"):
			focus_emulator.set("_device", -1)

		var focused = _safe_get(focus_emulator, "focused_control", null)
		if _is_live_ref(focused):
			_clear_focus_emulator_live_control(focus_emulator)
		else:
			_neutralize_stale_focus_emulator(focus_emulator, true)



func _try_apply_pending_host_state() -> void:
	if typeof(_pending_state_from_host) != TYPE_DICTIONARY or _pending_state_from_host.empty():
		return

	if _apply_host_selection_state_to_current_ui(_pending_state_from_host):
		_pending_state_from_host = {}


func _apply_host_selection_state_to_current_ui(state: Dictionary) -> bool:
	var selection = _find_current_selection_node()
	if selection == null:
		return false

	var state_screen = str(state.get("screen", ""))
	var current_screen = _get_selection_screen(selection)
	if state_screen == "" or state_screen == "none":
		return true

	if state_screen != current_screen:
		# Host 已进入另一个菜单时，后续会做 scene transition 同步；当前先不要在错误界面强行应用。
		return false

	if current_screen == "difficulty_selection":
		_disable_selection_buttons(selection, true)
		_apply_host_difficulty_focus(selection, state)
		return true

	_disable_selection_buttons(selection, false)

	var players = state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return true

	for player_state in players:
		if typeof(player_state) != TYPE_DICTIONARY:
			continue

		var player_index = int(player_state.get("player_index", -1))
		if player_index < 0 or player_index >= RunData.get_player_count():
			continue

		var focus_state = player_state.get("focus", {})
		var selected_state = player_state.get("selected", {})
		var ready = bool(player_state.get("ready", false))
		var player_steam_id = str(player_state.get("steam_id", ""))
		var is_local_self = _local_client_steam_id != "" and player_steam_id == _local_client_steam_id

		# 本地玩家自己的 hover/locked 显示交给原版 UI。否则 Host 回声会把“未解锁条件窗口”覆盖成角色详情窗口。
		# ready 的视觉仍然可以吃 Host 回包，因为 Host 才是确认选择是否成立的权威。
		if is_local_self:
			var local_selected_element = _find_element_by_state(selection, player_index, selected_state, true)
			_apply_selected_visual_only(selection, player_index, local_selected_element, ready, selected_state)
			if not ready:
				_reset_local_select_dedup_for_player(player_index)
			continue

		# Client display must allow locked characters/weapons. The client may not have unlocked
		# the same content as the host, but it still has the data resource in most cases.
		# Local input/select paths remain strict; this relaxed lookup is only for host-authoritative display.
		var focus_element = _find_element_by_state(selection, player_index, focus_state, true)
		if focus_element != null:
			_apply_focus_element_for_host_display(selection, player_index, focus_element, focus_state)
		else:
			_apply_item_state_to_panel(selection, player_index, focus_state)

		var selected_element = _find_element_by_state(selection, player_index, selected_state, true)
		_apply_selected_visual_only(selection, player_index, selected_element, ready, selected_state)

	return true


func _apply_selected_visual_only(selection: Node, player_index: int, element, ready: bool, item_state = {}) -> void:
	var selected_flags = selection.get("_has_player_selected")
	if typeof(selected_flags) == TYPE_ARRAY and player_index >= 0 and player_index < selected_flags.size():
		selected_flags[player_index] = ready

	var panels = selection._get_panels() if selection.has_method("_get_panels") else []
	if typeof(panels) == TYPE_ARRAY and player_index >= 0 and player_index < panels.size():
		panels[player_index].selected = ready

	if not ready and (typeof(item_state) != TYPE_DICTIONARY or item_state.empty()):
		_clear_selection_item_cache(selection, player_index)
		return

	var item = null
	if _is_live_ref(element):
		item = _safe_get(element, "item", null)

	if not _is_live_ref(item):
		item = _find_data_item_for_screen(_get_selection_screen(selection), item_state)

	if _is_live_ref(item):
		# Do not call the normal CharacterSelection locked-element path here. Locked remote choices
		# should still show the actual character/weapon panel, not just the local lock placeholder.
		_apply_item_to_panel(selection, player_index, item)
		_apply_item_to_selection_cache(selection, player_index, item)


func _apply_focus_element_for_host_display(selection: Node, player_index: int, element, item_state = {}) -> void:
	if not _is_live_ref(element):
		_apply_item_state_to_panel(selection, player_index, item_state)
		return

	# Client 侧应用 Host 状态时只做“显示同步”：直接同步 FocusEmulator 高亮，
	# 不调用官方 _on_element_focused，避免 locked/special 元素把面板切回锁说明，也避免触发本地选择流程。
	_apply_focus_visual_only(player_index, element)
	_set_latest_focused_element(selection, player_index, element)

	var item = _safe_get(element, "item", null)
	if _is_live_ref(item):
		_apply_item_to_panel(selection, player_index, item)
	else:
		_apply_item_state_to_panel(selection, player_index, item_state)


func _apply_focus_visual_only(player_index: int, element) -> void:
	if not _is_live_ref(element):
		return

	FocusEmulatorSignal.set_expected_control(element, player_index)
	var focus_emulator = Utils.get_focus_emulator(player_index)
	if _is_live_ref(focus_emulator):
		if focus_emulator is CanvasItem:
			focus_emulator.visible = true
		var old_control = focus_emulator.get("focused_control")
		if old_control != null and not is_instance_valid(old_control):
			# The global FocusEmulator may still point at a freed control during
			# guards this path, but do not force a visual update while the emulator is stale.
			return
		if _set_focus_emulator_control_safely(focus_emulator, element):
			return

	var fallback_focus = Utils.get_focus_emulator(player_index)
	if _is_live_ref(fallback_focus):
		Utils.focus_player_control(element, player_index, fallback_focus)


func _apply_item_state_to_panel(selection: Node, player_index: int, item_state) -> void:
	var item = _find_data_item_for_screen(_get_selection_screen(selection), item_state)
	if _is_live_ref(item):
		_apply_item_to_panel(selection, player_index, item)


func _apply_item_to_panel(selection: Node, player_index: int, item) -> void:
	if not _is_live_ref(item):
		return
	if not selection.has_method("_get_panels"):
		return

	var panels = selection._get_panels()
	if typeof(panels) != TYPE_ARRAY or player_index < 0 or player_index >= panels.size():
		return

	var panel = panels[player_index]
	if not _is_live_ref(panel):
		return

	panel.visible = true
	if panel.has_method("set_data"):
		panel.set_data(item, player_index)


func _apply_item_to_selection_cache(selection: Node, player_index: int, item) -> void:
	if not _is_live_ref(item):
		return

	var screen = _get_selection_screen(selection)
	if screen == "character_selection":
		var player_characters = selection.get("_player_characters")
		if typeof(player_characters) == TYPE_ARRAY and player_index >= 0 and player_index < player_characters.size():
			player_characters[player_index] = item
	elif screen == "weapon_selection":
		var player_weapons = selection.get("_player_weapons")
		if typeof(player_weapons) == TYPE_ARRAY and player_index >= 0 and player_index < player_weapons.size():
			player_weapons[player_index] = item


func _set_latest_focused_element(selection: Node, player_index: int, element) -> void:
	var latest = selection.get("_latest_focused_element")
	if typeof(latest) == TYPE_ARRAY and player_index >= 0 and player_index < latest.size():
		latest[player_index] = element


func _apply_host_difficulty_focus(selection: Node, state: Dictionary) -> void:
	var focus_state = state.get("host_focus", {})
	if typeof(focus_state) != TYPE_DICTIONARY or focus_state.empty():
		focus_state = _build_difficulty_state_from_last_scene_config()
	if typeof(focus_state) != TYPE_DICTIONARY or focus_state.empty():
		return

	var element = _find_element_by_state(selection, 0, focus_state, true)
	if element != null:
		# DifficultySelection is Host-only on clients. Do not drive the local FocusEmulator
		# here; only mirror the panel/cache. This avoids stale focus after weapon ->
		# difficulty transition while keeping the displayed Host difficulty correct.
		var item = _safe_get(element, "item", null)
		if _is_live_ref(item):
			_apply_item_to_panel(selection, 0, item)
			_apply_item_to_selection_cache(selection, 0, item)
		else:
			_apply_item_state_to_panel(selection, 0, focus_state)
	else:
		_apply_item_state_to_panel(selection, 0, focus_state)


func _build_difficulty_state_from_last_scene_config() -> Dictionary:
	var cfg = _last_menu_scene_state_from_host.get("run_config", {}) if typeof(_last_menu_scene_state_from_host) == TYPE_DICTIONARY else {}
	if typeof(cfg) != TYPE_DICTIONARY or not cfg.has("current_difficulty"):
		return {}

	var diff_value = int(cfg.get("current_difficulty", RunData.current_difficulty))
	for diff in ItemService.difficulties:
		if _is_live_ref(diff) and int(_safe_get(diff, "value", -999)) == diff_value:
			return _data_object_to_sync_state(diff)
	return {}


func _find_element_by_state(selection: Node, player_index: int, item_state, include_locked: bool = false):
	if typeof(item_state) != TYPE_DICTIONARY or item_state.empty():
		return null

	var item_id = str(item_state.get("id", ""))
	if item_id != "":
		var by_id = _find_element_by_item_id(selection, player_index, item_id, include_locked)
		if by_id != null:
			return by_id

	var item_id_hash = str(item_state.get("id_hash", ""))
	if item_id_hash != "":
		var by_hash = _find_element_by_item_id(selection, player_index, item_id_hash, include_locked)
		if by_hash != null:
			return by_hash

	var log_id = str(item_state.get("log", ""))
	if log_id != "":
		return _find_element_by_item_id(selection, player_index, log_id, include_locked)

	return null

func host_auto_prime_character_selection_after_remote_join() -> bool:
	# Host-only helper. This is intentionally a focus/hover prime, not a real selection/ready.
	# It emulates the harmless part of the host moving/clicking once: CharacterSelection gets
	# non-null focused elements for every visible player slot, then selection_state can be
	# broadcast with P0/P1 populated immediately after a client joins.
	var selection = _find_current_selection_node()
	if selection == null:
		return false

	var screen = _get_selection_screen(selection)
	if screen != "character_selection":
		return false

	var changed = false
	for player_index in range(RunData.get_player_count()):
		var existing = _get_latest_focused_element(selection, player_index)
		if _is_live_ref(existing):
			continue

		var elements = _get_selectable_elements_for_player(selection, player_index, true)
		if elements.empty():
			continue

		var element = elements[0]
		if not _is_live_ref(element):
			continue

		# Use the same official focus path as normal menu focus, but do not call _set_selected_element().
		_apply_focus_element(selection, player_index, element)
		changed = true

	if changed:
		_last_state_key = ""

	return changed

func apply_remote_focus_by_item_id(player_index: int, item_id) -> void:
	var selection = _find_current_selection_node()
	if selection == null:
		return

	var screen = _get_selection_screen(selection)
	if screen == "difficulty_selection":
		return

	var element = _find_element_by_item_id(selection, player_index, item_id, true)
	if element == null:
		return

	_apply_focus_element(selection, player_index, element)


func apply_remote_select_by_item_id(player_index: int, item_id, expected_screen: String = "") -> void:
	var selection = _find_current_selection_node()
	if selection == null:
		return

	var screen = _get_selection_screen(selection)
	if screen == "difficulty_selection":
		return

	if expected_screen != "" and screen != expected_screen:
		return

	var element = _find_element_by_item_id(selection, player_index, item_id)
	if element == null:
		return

	if screen == SCREEN_CHARACTER_SELECTION:
		var selected_item = _safe_get(element, "item", null)
		var missing_clients = _get_clients_missing_character(selected_item)
		if not missing_clients.empty():
			return

	_apply_focus_element(selection, player_index, element)

	if screen == "character_selection":
		_select_character_element(selection, player_index, element)
	elif screen == "weapon_selection":
		_select_weapon_element(selection, player_index, element)



func build_selection_state() -> Dictionary:
	var fast_screen = _get_current_menu_screen_fast()
	if fast_screen == SCREEN_GAME or fast_screen == SCREEN_SHOP:
		return {
			"msg_type": "selection_state",
			"screen": "none",
			"players": []
		}

	var selection = _find_current_selection_node()
	if selection == null:
		return {
			"msg_type": "selection_state",
			"screen": "none",
			"players": []
		}

	var players = []
	var slot_manager = _get_slot_manager()
	var selected_flags = selection.get("_has_player_selected")

	for player_index in range(RunData.get_player_count()):
		var focus_element = _get_latest_focused_element(selection, player_index)
		var selected_state = _get_selected_state_for_player(selection, player_index)
		var ready = false
		if typeof(selected_flags) == TYPE_ARRAY and player_index >= 0 and player_index < selected_flags.size():
			ready = bool(selected_flags[player_index])

		var is_remote = false
		var steam_id = ""
		if slot_manager != null:
			if slot_manager.has_method("is_remote_player_index"):
				is_remote = bool(slot_manager.is_remote_player_index(player_index))
			if slot_manager.has_method("get_remote_steam_id"):
				steam_id = str(slot_manager.get_remote_steam_id(player_index))

		players.append({
			"player_index": player_index,
			"remote": is_remote,
			"steam_id": steam_id,
			"focus": _element_to_state(focus_element),
			"selected": selected_state,
			"ready": ready
		})

	var screen = _get_selection_screen(selection)
	var result = {
		"msg_type": "selection_state",
		"screen": screen,
		"players": players
	}

	if screen == "difficulty_selection":
		result["host_focus"] = _element_to_state(_get_latest_focused_element(selection, 0))

	return result

func _poll_selection_state_change() -> void:
	var state = build_selection_state()
	if str(state.get("screen", "")) == "none":
		_last_state_key = ""
		return

	var key = to_json(state)
	if key == _last_state_key:
		return

	_last_state_key = key


func _compact_players_state(state: Dictionary) -> String:
	var parts = []
	var players = state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return "[]"

	for p in players:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var focus = p.get("focus", {})
		var selected = p.get("selected", {})
		var focus_log = "null"
		var selected_log = "null"
		if typeof(focus) == TYPE_DICTIONARY:
			focus_log = str(focus.get("id", focus.get("id_hash", "null")))
		if typeof(selected) == TYPE_DICTIONARY:
			selected_log = str(selected.get("id", selected.get("id_hash", "null")))
		parts.append("P%s focus=%s selected=%s ready=%s" % [str(p.get("player_index", -1)), focus_log, selected_log, str(p.get("ready", false))])

	return "[" + "; ".join(parts) + "]"

func _select_character_element(selection: Node, player_index: int, element) -> void:
	if not _is_live_ref(element):
		return

	var item = _safe_get(element, "item", null)
	if not _is_live_ref(item):
		return

	var player_characters = selection.get("_player_characters")
	if typeof(player_characters) != TYPE_ARRAY:
		return

	if player_index < 0 or player_index >= player_characters.size():
		return

	player_characters[player_index] = item
	selection.set("_player_characters", player_characters)

	if selection.has_method("_display_element_panel_data"):
		selection._display_element_panel_data(element, player_index)

	if selection.has_method("_set_selected_element"):
		selection._set_selected_element(player_index)


func _select_weapon_element(selection: Node, player_index: int, element) -> void:
	if not _is_live_ref(element):
		return

	var item = _safe_get(element, "item", null)
	if not _is_live_ref(item):
		return

	var player_weapons = selection.get("_player_weapons")
	if typeof(player_weapons) != TYPE_ARRAY:
		return

	if player_index < 0 or player_index >= player_weapons.size():
		return

	player_weapons[player_index] = item
	selection.set("_player_weapons", player_weapons)

	if selection.has_method("_display_element_panel_data"):
		selection._display_element_panel_data(element, player_index)

	if selection.has_method("_set_selected_element"):
		selection._set_selected_element(player_index)


func _apply_focus_element(selection: Node, player_index: int, element) -> void:
	if not _is_live_ref(element):
		return

	_cancel_ready_if_focus_changes(selection, player_index, element, false)
	Utils.focus_player_control(element, player_index)
	FocusEmulatorSignal.set_expected_control(element, player_index)
	if selection.has_method("_on_element_focused"):
		selection._on_element_focused(element, player_index)


func _ensure_local_client_focus_exists(selection: Node) -> void:
	var player_index = _get_local_client_player_index()
	if player_index < 0 or player_index >= RunData.get_player_count():
		return

	var existing = _get_latest_focused_element(selection, player_index)
	if _is_live_ref(existing):
		return

	_try_apply_online_catalog_to_current_selection()

	var current_screen: String = _get_selection_screen(selection)

	var elements = _get_selectable_elements_for_player(selection, player_index, false)
	var filtered_elements = []
	for candidate in elements:
		var candidate_state = _element_to_state(candidate)
		if _is_host_catalog_item_selectable(current_screen, player_index, candidate_state):
			filtered_elements.append(candidate)

	if filtered_elements.empty():
		return

	_apply_focus_element(selection, player_index, filtered_elements[0])
	_clear_client_local_ready_after_send(selection, player_index)


func _enforce_focus_change_cancels_ready_on_current_selection() -> void:
	var selection = _find_current_selection_node()
	if selection == null:
		return
	var screen = _get_selection_screen(selection)
	if not _is_client_interactive_selection_screen(screen):
		return

	var selected_flags = selection.get("_has_player_selected")
	if typeof(selected_flags) != TYPE_ARRAY:
		return

	var first_player = 0
	var last_player = RunData.get_player_count() - 1
	if _local_client_steam_id != "":
		var local_idx = _get_local_client_player_index()
		if local_idx < 0:
			return
		first_player = local_idx
		last_player = local_idx

	for player_index in range(first_player, last_player + 1):
		if player_index < 0 or player_index >= selected_flags.size():
			continue
		if not bool(selected_flags[player_index]):
			continue
		var focused = _get_latest_focused_element(selection, player_index)
		_cancel_ready_if_focus_changes(selection, player_index, focused, true)


func _cancel_ready_if_focus_changes(selection: Node, player_index: int, focused_element, refresh_panel: bool) -> bool:
	if not _is_live_ref(selection) or not _is_live_ref(focused_element):
		return false
	if bool(_safe_get(focused_element, "is_random", false)):
		# A random press stores a concrete selected item while the focused control remains
		# the random tile. Do not immediately clear that valid ready state.
		return false

	var selected_flags = selection.get("_has_player_selected")
	if typeof(selected_flags) != TYPE_ARRAY or player_index < 0 or player_index >= selected_flags.size():
		return false
	if not bool(selected_flags[player_index]):
		return false

	var selected_state = _get_selected_state_for_player(selection, player_index)
	if _element_states_match(_element_to_state(focused_element), selected_state):
		return false

	_clear_selected_flag_only(selection, player_index)
	_clear_selection_item_cache(selection, player_index)
	_reset_local_select_dedup_for_player(player_index)
	if refresh_panel:
		_refresh_panel_for_focus_after_cancel(selection, player_index, focused_element)
	return true


func _clear_selection_item_cache(selection: Node, player_index: int) -> void:
	var screen = _get_selection_screen(selection)
	if screen == SCREEN_CHARACTER_SELECTION:
		var player_characters = selection.get("_player_characters")
		if typeof(player_characters) == TYPE_ARRAY and player_index >= 0 and player_index < player_characters.size():
			player_characters[player_index] = null
			selection.set("_player_characters", player_characters)
	elif screen == SCREEN_WEAPON_SELECTION:
		var player_weapons = selection.get("_player_weapons")
		if typeof(player_weapons) == TYPE_ARRAY and player_index >= 0 and player_index < player_weapons.size():
			player_weapons[player_index] = null
			selection.set("_player_weapons", player_weapons)


func _refresh_panel_for_focus_after_cancel(selection: Node, player_index: int, focused_element) -> void:
	if not _is_live_ref(focused_element):
		return
	FocusEmulatorSignal.set_expected_control(focused_element, player_index)
	if selection.has_method("_on_element_focused"):
		selection._on_element_focused(focused_element, player_index)
	elif selection.has_method("_display_element_panel_data"):
		selection._display_element_panel_data(focused_element, player_index)


func _element_states_match(a: Dictionary, b: Dictionary) -> bool:
	if typeof(a) != TYPE_DICTIONARY or typeof(b) != TYPE_DICTIONARY:
		return false
	if a.empty() or b.empty():
		return false
	for key in ["id", "id_hash", "weapon_id_hash", "resource_path", "log"]:
		var av = str(a.get(key, ""))
		var bv = str(b.get(key, ""))
		if av != "" and bv != "" and av == bv:
			return true
	return false

func _get_local_client_player_index() -> int:
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("get_local_mirrored_player_index"):
		var idx = int(slot_manager.get_local_mirrored_player_index())
		if idx >= 0 and idx < max(1, RunData.get_player_count()):
			return idx

	# 没收到 Host selection_state 前，Client 不知道自己是 P1/P2/P3。
	# 不能回退成 P0，否则本地键盘/鼠标会改自己的 P0，同时 P2P 又让 Host 改远程槽，表现成两个槽一起变。
	return -1

func _get_latest_focused_element(selection: Node, player_index: int):
	var latest = selection.get("_latest_focused_element")
	if typeof(latest) == TYPE_ARRAY and player_index >= 0 and player_index < latest.size():
		return latest[player_index]
	return null


func _get_selected_item_for_player(selection: Node, player_index: int):
	var screen = _get_selection_screen(selection)
	if screen == "character_selection":
		var player_characters = selection.get("_player_characters")
		if typeof(player_characters) == TYPE_ARRAY and player_index >= 0 and player_index < player_characters.size():
			return player_characters[player_index]
	elif screen == "weapon_selection":
		var player_weapons = selection.get("_player_weapons")
		if typeof(player_weapons) == TYPE_ARRAY and player_index >= 0 and player_index < player_weapons.size():
			return player_weapons[player_index]
	return null


func _get_selected_state_for_player(selection: Node, player_index: int) -> Dictionary:
	var selected_item = _get_selected_item_for_player(selection, player_index)
	if not _is_live_ref(selected_item):
		return {}
	return _element_to_state(_make_item_state_proxy(selected_item))


func _get_selected_element_for_player(selection: Node, player_index: int):
	var selected_item = _get_selected_item_for_player(selection, player_index)
	if selected_item == null:
		return null

	var elements = _get_selectable_elements_for_player(selection, player_index, true)
	for element in elements:
		if not _is_live_ref(element):
			continue
		var element_item = _safe_get(element, "item", null)
		if _is_live_ref(element_item) and element_item == selected_item:
			return element

	return _make_item_state_proxy(selected_item)


func _safe_node_is_parent_of(parent, child) -> bool:
	if not _is_live_ref(parent) or not _is_live_ref(child):
		return false
	if not (parent is Node) or not (child is Node):
		return false
	if parent == child:
		return true
	return parent.is_a_parent_of(child)


func _is_live_ref(obj) -> bool:
	if obj == null:
		return false

	if typeof(obj) == TYPE_OBJECT and not is_instance_valid(obj):
		return false

	return true


func _make_item_state_proxy(item) -> Dictionary:
	return {
		"__item_proxy": true,
		"item": item
	}


func _element_to_state(element) -> Dictionary:
	if not _is_live_ref(element):
		return {}

	var item = null
	if typeof(element) == TYPE_DICTIONARY and bool(element.get("__item_proxy", false)):
		item = element.get("item", null)
	elif _has_property(element, "item"):
		item = _safe_get(element, "item", null)
	else:
		return {}

	if not _is_live_ref(item):
		return {}

	var state = {
		"id": _safe_get(item, "my_id", ""),
		"id_hash": _safe_get(item, "my_id_hash", "")
	}
	var weapon_hash = _safe_get(item, "weapon_id_hash", "")
	if str(weapon_hash) != "" and int(weapon_hash) != 0:
		state["weapon_id_hash"] = weapon_hash
	return state


func _get_selectable_elements_for_player(selection: Node, player_index: int, include_locked: bool = false) -> Array:
	var result = []
	var displayed = selection.get("displayed_elements")
	if typeof(displayed) == TYPE_ARRAY and player_index >= 0 and player_index < displayed.size():
		var elements = displayed[player_index]
		if typeof(elements) == TYPE_ARRAY:
			for element in elements:
				if _is_selectable_inventory_element(element, include_locked):
					result.append(element)

	if selection.has_method("_get_inventories"):
		var inventories = selection._get_inventories()
		if typeof(inventories) == TYPE_ARRAY and inventories.size() > 0:
			var inv_index = player_index % inventories.size()
			var inv = inventories[inv_index]
			if _is_live_ref(inv):
				for child in inv.get_children():
					if _is_selectable_inventory_element(child, include_locked):
						if not result.has(child):
							result.append(child)

	return result


func _find_element_by_item_id(selection: Node, player_index: int, item_id, include_locked: bool = false):
	var target = str(item_id)
	var elements = _get_selectable_elements_for_player(selection, player_index, include_locked)
	for element in elements:
		if not _is_live_ref(element):
			continue

		var item = _safe_get(element, "item", null)
		if not _is_live_ref(item):
			continue

		if str(_safe_get(item, "my_id_hash", "")) == target:
			return element
		if str(_safe_get(item, "weapon_id_hash", "")) == target:
			return element
		if str(_safe_get(item, "my_id", "")) == target:
			return element
		if _get_item_id_for_log(item) == target:
			return element
	return null


func _is_selectable_inventory_element(element, include_locked: bool = false) -> bool:
	if not _is_live_ref(element):
		return false

	if not _has_property(element, "item"):
		return false

	if not _is_live_ref(_safe_get(element, "item", null)):
		return false

	if include_locked:
		return true

	if _safe_get(element, "is_special", false):
		return false

	if _safe_get(element, "is_locked", false):
		return false

	return true


func _find_current_selection_node() -> Node:
	var current = get_tree().current_scene
	if current == null:
		return null

	if _is_supported_selection_node(current):
		return current

	var fast_screen = _get_current_menu_screen_fast()
	if fast_screen == SCREEN_GAME or fast_screen == SCREEN_SHOP:
		return null

	return _find_supported_selection_node_recursive(current)


func _find_supported_selection_node_recursive(node: Node) -> Node:
	if not _is_live_ref(node):
		return null

	for child in node.get_children():
		if _is_supported_selection_node(child):
			return child

		var found = _find_supported_selection_node_recursive(child)
		if found != null:
			return found

	return null


func _is_supported_selection_node(node: Node) -> bool:
	if node == null:
		return false

	var script_path = _get_script_path(node)
	return script_path.find("ui/menus/run/character_selection.gd") != -1 \
		or script_path.find("ui/menus/run/weapon_selection.gd") != -1 \
		or script_path.find("ui/menus/run/difficulty_selection/difficulty_selection.gd") != -1


func _get_selection_screen(selection: Node) -> String:
	var script_path = _get_script_path(selection)
	if script_path.find("character_selection.gd") != -1:
		return "character_selection"
	if script_path.find("weapon_selection.gd") != -1:
		return "weapon_selection"
	if script_path.find("difficulty_selection.gd") != -1:
		return "difficulty_selection"
	return "unknown"


func _get_item_id_for_log(item) -> String:
	if not _is_live_ref(item):
		return "null"

	var my_id = _safe_get(item, "my_id", null)
	if my_id != null:
		return str(my_id)

	var name = _safe_get(item, "name", null)
	if name != null:
		return str(name)

	var my_id_hash = _safe_get(item, "my_id_hash", null)
	if my_id_hash != null:
		return str(my_id_hash)

	return str(item)


func _get_script_path(node: Node) -> String:
	if node == null:
		return ""

	var script_res = node.get_script()
	if script_res == null:
		return ""

	return str(script_res.resource_path)


func _safe_get(obj, prop_name: String, default_value):
	if not _is_live_ref(obj):
		return default_value

	if typeof(obj) == TYPE_DICTIONARY:
		return obj.get(prop_name, default_value)

	if not _has_property(obj, prop_name):
		return default_value

	return obj.get(prop_name)


func _has_property(obj, prop_name: String) -> bool:
	if not _is_live_ref(obj):
		return false

	if typeof(obj) != TYPE_OBJECT:
		return false

	if not obj.has_method("get_property_list"):
		return false

	for prop in obj.get_property_list():
		if prop.has("name") and prop["name"] == prop_name:
			return true

	return false


func _get_slot_manager() -> Node:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineOnlinePlayerSlotManager")

func _input(event: InputEvent) -> void:
	if not _is_online_session_active():
		return
	if _is_game_start_guard_active():
		return
	_bo_ui_diag_log_input_event(event, "menu_sync_manager")
	var t_input = OS.get_ticks_usec()
	# Lock changes are already captured by the lock-button signal and by the
	# shop-state diff poll. The old raw select-input probe could run while backing
	# out to the stats panel with focus still on an item and submit a false lock
	# action, which then disabled/locked that entry on Host and Client.
	_bo_ui_diag_log_cost("input_handler", t_input)
