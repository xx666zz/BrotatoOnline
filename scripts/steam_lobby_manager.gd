extends Node


const BROTATO_APP_ID = 1942280
const MAX_LOBBY_MEMBERS = 4
const MOD_VERSION = "4.0.0"
const META_AUTO_JOIN_HOST_PLAYER = "brotato_online_auto_join_host_player"
const META_PUBLIC_LOBBY_ENABLED = "brotato_online_public_lobby_enabled"

# GodotSteam exposes these lobby types as integer enums. Keep explicit fallbacks
# because the Brotato build used by the mod does not expose constants uniformly.
const LOBBY_TYPE_FRIENDS_ONLY_FALLBACK = 1
const LOBBY_TYPE_PUBLIC_FALLBACK = 2
const LOBBY_CONNECT_PREFIX = "+connect_lobby "
const LOBBY_JOIN_SUCCESS_RESPONSE = 1
const LOBBY_JOIN_TIMEOUT_MSEC = 12000
const P2P_CHANNEL_MENU = 0
const P2P_CHANNEL_BATTLE = 1
const P2P_CHANNEL_LOBBY_BROWSER = 2
const P2P_POLL_LIMIT_PER_FRAME = 32
const P2P_BATTLE_POLL_LIMIT_PER_FRAME = 64
const SELECTION_BROADCAST_INTERVAL_MSEC = 250
const MENU_SCENE_BROADCAST_INTERVAL_MSEC = 250
const CLIENT_MENU_INPUT_POLL_INTERVAL_MSEC = 50
const STEAM_NETWORKING_SEND_RELIABLE = 8
const FORCE_ALL_STEAM_MESSAGES_RELIABLE = true
# SteamNetworkingMessages reliable packets can fail around large payload limits.
# Keep each chunk well below 64KB after the JSON/base64 wrapper is added.
const P2P_JSON_CHUNK_TRIGGER_BYTES = 400 * 1024
const P2P_JSON_CHUNK_RAW_BYTES = 44000
const P2P_JSON_CHUNK_SENDS_PER_FRAME = 1
# When SteamNetworkingMessages refuses a reliable chunk because the send buffer is
# full, keep the packet at the head of the queue and retry after a few frames.
const P2P_JSON_CHUNK_RETRY_DELAY_MSEC = 100
const P2P_JSON_CHUNK_RETRY_LOG_INTERVAL_MSEC = 1000
const P2P_JSON_CHUNK_TTL_MSEC = 15000
const CLIENT_HELLO_RETRY_DURATION_MSEC = 5000
const CLIENT_HELLO_RETRY_INTERVAL_MSEC = 1000
const CLIENT_SETUP_DUPLICATE_SUPPRESS_MSEC = 5000
const BATTLE_SNAPSHOT_SEND_INTERVAL_MSEC = 120
# Diagnostic switch: do not forward broad death claims/reports or broadcast death_event packets.
const ENABLE_DEATH_REPORT_MESSAGES = false
# Narrow exceptions: allow boss/elite death claims and Vorpal/one-shot boss damage
# claims without re-enabling general entity death sync, which could freeze battles.
# In Brotato, elites and bosses both arrive as category == "boss".
const ENABLE_BOSS_ELITE_DEATH_REPORT_MESSAGES = true
const ENABLE_BOSS_ONE_SHOT_REPORT_MESSAGES = true
const ENABLE_DEATH_EVENT_MESSAGES = false
const GAME_START_COMMIT_LEAD_MSEC = 1200
const CLIENT_GAME_START_EARLY_MSEC = 250
const CLIENT_STALE_MENU_GUARD_MSEC = 10000
const GAME_START_ACK_TIMEOUT_MSEC = 1200
const GAME_START_MAX_WAIT_MSEC = 2200
const GAME_START_READY_TIMEOUT_MSEC = 4500
const CLIENT_BATTLE_SNAPSHOT_LOG_INTERVAL_MSEC = 5000
const CLIENT_BATTLE_SNAPSHOT_LOG_FIRST_COUNT = 1
const AUTO_CREATE_LOBBY_ON_OFFICIAL_COOP_CONTINUE = true
const OFFICIAL_COOP_CONTINUE_AUTO_LOBBY_DELAY_MSEC = 300
const HOST_SELECTION_REQUEST_REPLY_MIN_INTERVAL_MSEC = 300
const HOST_SELECTION_REQUEST_SETUP_MIN_INTERVAL_MSEC = 2000
const BROWSER_PING_REPLY_MIN_INTERVAL_MSEC = 100
const UPGRADE_DIRECT_FALLBACK_FIRST_SEND_MSEC = 650
const UPGRADE_DIRECT_FALLBACK_RESEND_MSEC = 900
const UPGRADE_DIRECT_FALLBACK_TTL_MSEC = 9000
const UPGRADE_DIRECT_PENDING_TTL_MSEC = 9000
const RETRY_WAVE_STATE_BROADCAST_INTERVAL_MSEC = 400
const BATTLE_TERMINAL_STATE_RESEND_MSEC = 500
const BATTLE_START_GENERATION_FENCE_MSEC = 12000
const HOST_RETRY_TERMINAL_SUPPRESS_MSEC = 8000
const HOST_RETRY_BATTLE_SEND_WARMUP_MSEC = 900
const HOST_RETRY_BATTLE_SEND_MAX_WAIT_MSEC = 5000
const HOST_RETRY_FIRST_SNAPSHOT_BLOCK_LOG_MSEC = 500
# First normal battle_snapshot after any synced battle start must come from a live
# battle frame.  Host can briefly have a stale/pre-start WaveTimer at 0 on wave 1.
const HOST_FIRST_BATTLE_SNAPSHOT_MIN_TIME_LEFT_SEC = 1.0

# Network lag diagnostics.  Routine low-cost polling is silent.  Logs are emitted
# only for slow packet handling, send-buffer/backlog pressure, large packets/chunks,
# or repeated medium-cost polling inside a short window.
const BO_NET_DIAG_ENABLED = true
const BO_NET_DIAG_SINGLE_COST_USEC = 10000
const BO_NET_DIAG_BURST_COST_USEC = 3000
const BO_NET_DIAG_BURST_TOTAL_USEC = 20000
const BO_NET_DIAG_BURST_COUNT = 5
const BO_NET_DIAG_BURST_WINDOW_MSEC = 2000
const BO_NET_DIAG_LARGE_PACKET_BYTES = 65536
const BO_NET_DIAG_LARGE_BATCH_BYTES = 131072
const BO_NET_DIAG_PENDING_QUEUE_WARN = 4
const BO_NET_DIAG_PENDING_AGE_WARN_MSEC = 500

var _steam = null
var _steam_ready = false
var _lobby_id = 0
var _is_lobby_owner = false
var _online_role = "none" # "none" / "host" / "client". Game authority never follows Steam owner migration.
var _game_host_steam_id = ""
var _online_run_slots_locked = false
var _last_slot_lock_skip_log_msec = 0
var _self_steam_id = ""
var _members = []
var _open_invite_overlay_after_create = false
var _last_key_time = 0
# Steam may deliver a join request while Brotato is still running its boot-time
# data/language initialization. Keep that request separate from the normal join
# state until the vanilla main menu has appeared once.
var _startup_main_menu_ready = false
var _startup_pending_join_lobby_id = 0
var _pending_join_lobby_id = 0
var _client_join_requested_lobby_id = 0
var _client_join_request_started_msec = 0
var _join_failure_dialog = null
var _join_failure_dialog_parent = null
var _checked_launch_args = false
var _last_selection_broadcast_msec = 0
var _last_broadcast_selection_key = ""
var _last_client_menu_input_poll_msec = 0
var _accepted_p2p_sessions = {}
var _online_flow_started = false
var _online_flow_left_since_msec = 0
var _host_known_remote_ids = []
var _client_hello_retry_until_msec = 0
var _last_client_hello_retry_msec = 0
var _sent_character_setup_key_by_steam_id = {}
var _sent_weapon_setup_key_by_steam_id = {}
var _sent_scene_transition_key_by_steam_id = {}
var _full_item_list_scene_sync_required_by_steam_id = {}
var _host_scene_transition_payload_cache_key = ""
var _host_scene_transition_payload_cache_msec = 0
var _host_scene_transition_payload_cache_state = {}
var _pending_p2p_chunk_sends = []
var _incoming_p2p_chunks = {}
var _p2p_chunk_seq = 0
var _seen_client_hello_by_steam_id = {}
var _client_seen_host_setup_key_by_sender = {}
var _client_seen_host_setup_msec_by_sender = {}
var _last_selection_request_reply_msec_by_steam_id = {}
var _last_selection_request_setup_msec_by_steam_id = {}
var _browser_ping_last_reply_msec_by_steam_id = {}
var _last_host_phase_poll_msec = 0
var _last_battle_snapshot_send_msec = 0
var _last_battle_snapshot_sent_tick_by_steam_id = {}
var _last_battle_reliable_sent_key_by_steam_id = {}
var _last_battle_snapshot_tx_log_msec = 0
var _client_battle_snapshot_rx_count = 0
var _last_client_battle_snapshot_rx_log_msec = 0
var _last_client_battle_snapshot_rx_tick = -1
var _host_difficulty_intercept_selection_id = 0
var _pending_host_game_start = {}
var _pending_host_game_start_id = 0
var _host_game_start_ack_by_steam_id = {}
var _host_game_start_ready_by_steam_id = {}
var _pending_client_game_start_commit = {}
var _pending_client_game_start_apply_msec = 0
var _pending_client_game_start_deferred_commit = {}
var _pending_client_game_start_deferred_call_queued = false
var _client_game_start_prepare_msec = 0
var _last_client_game_start_commit_id = 0
var _client_ignore_stale_menu_until_msec = 0
var _client_last_game_scene_apply_msec = 0
var _pending_client_game_scene_ready_start_id = 0
var _sent_client_game_scene_ready_start_id = 0
var _local_run_page_action_seq = 0
var _direct_upgrade_ui_instance_id = 0
var _direct_upgrade_action_seq = 0
var _direct_upgrade_local_actions = {}
var _direct_upgrade_seen_action_ids = {}
var _direct_upgrade_pending_remote_actions = []
var _direct_upgrade_apply_guard = false
var _direct_upgrade_last_prune_msec = 0
var _lobby_toggle_button = null
var _lobby_toggle_panel = null
var _lobby_toggle_pending_create = false
var _lobby_toggle_close_after_create = false
var _lobby_toggle_signal_guard = false
var _last_lobby_create_failed_result = 0
var _last_lobby_toggle_ui_poll_msec = 0
var _main_menu_online_button = null
var _main_menu_online_button_parent = null
var _main_menu_online_start_pending = false
var _main_menu_online_start_deadline_msec = 0
var _last_main_menu_online_ui_poll_msec = 0
var _character_invite_button = null
var _character_invite_button_parent = null
var _character_lobby_status_label = null
var _last_character_invite_button_ui_poll_msec = 0
var _continue_invite_button = null
var _continue_invite_button_parent = null
var _continue_lobby_status_label = null
var _last_continue_invite_button_ui_poll_msec = 0
var _joining_overlay = null
var _joining_overlay_parent = null
var _joining_overlay_label = null
var _joining_overlay_active = false
var _last_joining_overlay_ui_poll_msec = 0
var _join_presence_cleared_at_boot = false
var _official_continue_auto_lobby_armed = false
var _official_continue_auto_lobby_first_seen_msec = 0
var _official_continue_auto_lobby_done_for_scene_id = 0
var _retry_wave_intercept_scene_id = 0
var _retry_wave_intercept_node_id = 0
var _retry_wave_intercept_button_id = 0
var _retry_wave_intercept_cancel_button_id = 0
var _retry_wave_intercept_ok_button_id = 0
var _retry_wave_ready_by_steam_id = {}
var _retry_wave_ready_context_key = ""
var _retry_wave_local_waiting_context_key = ""
var _retry_wave_last_state_broadcast_msec = 0
var _retry_wave_starting_context_key = ""
var _retry_wave_last_started_context_key = ""
var _retry_wave_host_context_key = ""
var _retry_wave_ending_context_key = ""
var _client_retry_wave_setting_override_active = false
var _client_retry_wave_setting_before_override = false
var _end_run_intercept_scene_id = 0
var _end_run_intercept_restart_button_id = 0
var _end_run_intercept_new_run_button_id = 0
var _end_run_intercept_exit_button_id = 0
var _last_battle_terminal_state_key_by_steam_id = {}
var _last_battle_terminal_state_msec_by_steam_id = {}
var _host_current_battle_start_id = 0
var _host_current_battle_start_kind = ""
var _host_current_retry_context_key = ""
var _host_battle_start_fence_until_msec = 0
var _host_retry_terminal_suppress_until_msec = 0
var _host_retry_terminal_suppress_scene_id = 0
var _host_retry_battle_send_min_until_msec = 0
var _host_retry_battle_send_deadline_msec = 0
var _host_retry_battle_send_old_scene_id = 0
var _host_retry_battle_send_started_msec = 0
var _host_retry_battle_send_fresh_after_msec = 0
var _host_retry_battle_send_require_fresh_snapshot = false
var _host_retry_first_snapshot_pending_start_id = 0
var _host_retry_first_snapshot_accepted_start_id = 0
var _host_retry_battle_send_last_block_log_msec = 0
var _client_expected_battle_start_id = 0
var _client_expected_battle_start_kind = ""
var _client_expected_retry_context_key = ""
var _client_battle_start_fence_until_msec = 0
var _client_active_battle_start_id = 0
var _client_active_battle_start_kind = ""
var _client_active_retry_context_key = ""
var _pending_client_game_scene_ready_requires_new_scene = false
var _pending_client_game_scene_ready_old_scene_id = 0
var _online_session_generation = 0
var _last_online_character_selection_restage_scene_id = 0
var _bo_net_diag_cost_stats_by_scope = {}
var _bo_net_diag_last_state_key_by_tag = {}
var _bo_net_diag_last_state_msec_by_tag = {}


func _bo_net_diag_log(tag: String, msg: String) -> void:
	if not BO_NET_DIAG_ENABLED:
		return
	print("[BO_LAG][NET][" + tag + "] " + msg)


func _bo_net_diag_cost(scope: String, start_usec: int, extra: String = "") -> void:
	if not BO_NET_DIAG_ENABLED:
		return
	var cost = OS.get_ticks_usec() - start_usec
	var now = OS.get_ticks_msec()
	if cost >= BO_NET_DIAG_SINGLE_COST_USEC:
		_bo_net_diag_log("SLOW", "scope=" + scope + " us=" + str(cost) + " " + extra)
		return
	if cost < BO_NET_DIAG_BURST_COST_USEC:
		return
	var stats = _bo_net_diag_cost_stats_by_scope.get(scope, {})
	if typeof(stats) != TYPE_DICTIONARY or stats.empty() or now - int(stats.get("start_msec", now)) > BO_NET_DIAG_BURST_WINDOW_MSEC:
		stats = {"start_msec": now, "count": 0, "total_usec": 0, "max_usec": 0, "last_log_msec": 0}
	stats["count"] = int(stats.get("count", 0)) + 1
	stats["total_usec"] = int(stats.get("total_usec", 0)) + cost
	stats["max_usec"] = max(int(stats.get("max_usec", 0)), cost)
	_bo_net_diag_cost_stats_by_scope[scope] = stats
	var should_log = int(stats.get("count", 0)) >= BO_NET_DIAG_BURST_COUNT or int(stats.get("total_usec", 0)) >= BO_NET_DIAG_BURST_TOTAL_USEC
	if not should_log:
		return
	if now - int(stats.get("last_log_msec", 0)) < BO_NET_DIAG_BURST_WINDOW_MSEC:
		return
	stats["last_log_msec"] = now
	_bo_net_diag_cost_stats_by_scope[scope] = stats
	_bo_net_diag_log("BURST", "scope=" + scope + " count=" + str(stats.get("count", 0)) + " total_us=" + str(stats.get("total_usec", 0)) + " max_us=" + str(stats.get("max_usec", 0)) + " window_ms=" + str(now - int(stats.get("start_msec", now))) + " " + extra)


func _bo_net_diag_state_change(tag: String, key: String, msg: String, min_interval_msec: int = BO_NET_DIAG_BURST_WINDOW_MSEC) -> void:
	if not BO_NET_DIAG_ENABLED:
		return
	var now = OS.get_ticks_msec()
	var last_key = str(_bo_net_diag_last_state_key_by_tag.get(tag, ""))
	var last_msec = int(_bo_net_diag_last_state_msec_by_tag.get(tag, 0))
	if key == last_key and now - last_msec < min_interval_msec:
		return
	_bo_net_diag_last_state_key_by_tag[tag] = key
	_bo_net_diag_last_state_msec_by_tag[tag] = now
	_bo_net_diag_log(tag, msg)


func _bo_net_diag_message_summary(message: Dictionary) -> String:
	if typeof(message) != TYPE_DICTIONARY:
		return "msg=null"
	var msg_type = str(message.get("msg_type", ""))
	var parts = ["type=" + msg_type]
	if message.has("screen"):
		parts.append("screen=" + str(message.get("screen", "")))
	if message.has("action_type"):
		parts.append("action=" + str(message.get("action_type", "")))
	if message.has("tick"):
		parts.append("tick=" + str(message.get("tick", 0)))
	elif message.has("t"):
		parts.append("tick=" + str(message.get("t", 0)))
	if message.has("battle_start_id") or message.has("bs"):
		parts.append("bs=" + str(_extract_battle_start_id(message)))
	if message.has("compact"):
		parts.append("compact=" + str(message.get("compact", false)))
	return " ".join(parts)


func _bo_net_diag_log_large_or_queued_send(target_steam_id: String, msg_type: String, payload_size: int, channel: int, reliable: bool, reason: String, pending_count: int = -1) -> void:
	if not BO_NET_DIAG_ENABLED:
		return
	if payload_size < BO_NET_DIAG_LARGE_PACKET_BYTES and pending_count < BO_NET_DIAG_PENDING_QUEUE_WARN and reason != "send_failed":
		return
	var key = reason + ":" + msg_type + ":" + str(channel) + ":" + str(payload_size) + ":" + str(pending_count)
	_bo_net_diag_state_change("SEND", key, "reason=" + reason + " type=" + msg_type + " bytes=" + str(payload_size) + " channel=" + str(channel) + " reliable=" + str(reliable) + " pending=" + str(pending_count) + " target=" + target_steam_id, 1000)


func _connect_ui_language_signal() -> void:
	if ProgressData == null:
		return
	if not ProgressData.has_signal("language_changed"):
		return
	if not ProgressData.is_connected("language_changed", self, "_on_ui_language_changed"):
		ProgressData.connect("language_changed", self, "_on_ui_language_changed")


func _on_ui_language_changed() -> void:
	_update_lobby_toggle_button_state()
	_update_main_menu_online_button_state()
	_update_character_invite_button_state()
	_update_continue_invite_button_state()
	_update_character_lobby_status_label_state()
	_update_continue_lobby_status_label_state()


func _ui_text(key: String) -> String:
	var translation_key = "BROTATO_ONLINE_STEAM_" + key.to_upper()
	var parent = get_parent()
	if parent != null:
		var i18n = parent.get_node_or_null("BrotatoOnlineI18n")
		if i18n != null and i18n.has_method("get_text"):
			return str(i18n.call("get_text", translation_key))
	return translation_key


func _get_auto_join_host_player_enabled() -> bool:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return true
	return bool(tree.root.get_meta(META_AUTO_JOIN_HOST_PLAYER, true))


func _disable_custom_button_auto_translation(button: Node) -> void:
	if button != null and button.has_method("set_message_translation"):
		button.set_message_translation(false)


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	set_process(true)
	set_process_input(true)
	_connect_ui_language_signal()
	_setup_steam()
	_connect_steam_signals()
	_clear_stale_join_presence_at_boot()
	call_deferred("_check_launch_join_args")
	_update_online_session_runtime_flag()


func _input(_event: InputEvent) -> void:
	# While Steam join / host setup is in flight, prevent the vanilla main menu or
	# newly-opened character-selection page from accepting accidental confirm/move input.
	if _joining_overlay_active:
		get_tree().set_input_as_handled()


func _process(_delta: float) -> void:
	var process_start_usec = OS.get_ticks_usec()
	# Steam callbacks and F6/join handling must keep running even before a lobby exists.
	var t_boot = OS.get_ticks_usec()
	_run_steam_callbacks()
	_poll_startup_main_menu_ready()
	_consume_startup_join_if_ready()
	_consume_pending_join_if_ready()
	_poll_join_request_timeout()
	_handle_shortcuts()
	_bo_net_diag_cost("steam_callbacks_and_shortcuts", t_boot)

	# Button injection belongs to menu scenes only. In main.tscn these polls fall back
	# to recursive scene-tree searches for RunOptionsPanel / StartButton / invite nodes.
	# Keep Steam/P2P running, but do not scan menu UI during battle.
	var in_game_scene = _is_in_game_scene()
	var in_normal_shop_scene = _is_in_shop_scene() and not _is_in_official_coop_resume_scene()
	if not in_game_scene and not in_normal_shop_scene:
		var t_ui = OS.get_ticks_usec()
		_poll_lobby_toggle_button()
		_poll_character_invite_button()
		_poll_continue_invite_button()
		_poll_main_menu_online_button()
		_poll_main_menu_online_start_pending()
		_poll_official_continue_auto_lobby()
		_poll_joining_overlay()
		_bo_net_diag_cost("menu_button_poll", t_ui)
	else:
		_clear_non_game_ui_button_refs()
		_remove_joining_overlay()
	_update_online_session_runtime_flag()

	# Offline/single-player must be a no-op for the online sync layer.
	# The previous flow kept polling menu/battle sync with _lobby_id == 0;
	# downstream managers then interpreted "not host" as "client", which broke solo waves.
	if not _has_active_online_session():
		_bo_net_diag_cost("steam_process_offline_total", process_start_usec)
		return

	var t_retry = OS.get_ticks_usec()
	_poll_retry_wave_intercept()
	_poll_end_run_intercept()
	_bo_net_diag_cost("poll_retry_wave_intercept", t_retry)
	var t_start = OS.get_ticks_usec()
	_poll_host_difficulty_start_intercept()
	_poll_host_game_start_sync()
	_poll_client_game_start_commit()
	_poll_client_game_scene_ready()
	_poll_client_hello_retry()
	_bo_net_diag_cost("poll_game_start_sync", t_start)
	var t_p2p = OS.get_ticks_usec()
	_poll_p2p_packets()
	_bo_net_diag_cost("poll_p2p_packets", t_p2p, "pending_chunks=" + str(_pending_p2p_chunk_sends.size()))
	var t_chunks = OS.get_ticks_usec()
	_poll_pending_p2p_chunk_sends()
	_bo_net_diag_cost("poll_pending_chunks", t_chunks, "pending_chunks=" + str(_pending_p2p_chunk_sends.size()))
	var t_menu_send = OS.get_ticks_usec()
	_poll_and_send_local_client_menu_input()
	_poll_and_send_local_run_page_actions()
	_poll_direct_upgrade_action_sync()
	_bo_net_diag_cost("poll_client_menu_send", t_menu_send)
	var t_battle_send = OS.get_ticks_usec()
	_poll_and_send_local_client_battle_input()
	_poll_and_send_host_battle_snapshot()
	_bo_net_diag_cost("poll_battle_send", t_battle_send)
	var t_phase = OS.get_ticks_usec()
	_poll_and_send_host_phase_messages()
	_poll_and_broadcast_selection_state()
	_poll_online_flow_lifecycle()
	_bo_net_diag_cost("poll_phase_selection", t_phase)
	_bo_net_diag_cost("steam_process_total", process_start_usec, "in_game=" + str(in_game_scene) + " pending_chunks=" + str(_pending_p2p_chunk_sends.size()))

func create_lobby_and_invite(open_overlay_after_create: bool = false) -> void:
	# F6, the Run Options toggle, and the invite button share this path.
	# Only the invite button passes open_overlay_after_create=true.
	# Official Continue support: after Host presses Continue on a saved COOP run, the
	# vanilla flow enters coop_resume.tscn and waits for the missing COOP players.
	# Creating the Steam lobby there lets remote clients join and be inserted into
	# the official CoopResume sequence instead of using a custom resume/save path.
	if not _can_create_lobby_from_current_scene():
		_lobby_toggle_pending_create = false
		_update_lobby_toggle_button_state()
		_update_character_invite_button_state()
		_update_continue_invite_button_state()
		_update_character_lobby_status_label_state()
		_update_continue_lobby_status_label_state()
		return

	if not _ensure_steam_ready():
		_lobby_toggle_pending_create = false
		_last_lobby_create_failed_result = -1
		_update_lobby_toggle_button_state()
		_update_character_invite_button_state()
		_update_continue_invite_button_state()
		_update_character_lobby_status_label_state()
		_update_continue_lobby_status_label_state()
		return

	if _lobby_id != 0:
		_lobby_toggle_pending_create = false
		_lobby_toggle_close_after_create = false
		_last_lobby_create_failed_result = 0
		_setup_join_presence()
		_update_lobby_toggle_button_state()
		_update_character_invite_button_state()
		_update_continue_invite_button_state()
		_update_character_lobby_status_label_state()
		_update_continue_lobby_status_label_state()
		if open_overlay_after_create:
			open_invite_overlay()
		return

	_open_invite_overlay_after_create = open_overlay_after_create
	var lobby_type = _get_steam_const("LOBBY_TYPE_PUBLIC", LOBBY_TYPE_PUBLIC_FALLBACK) if _get_public_lobby_enabled() else _get_steam_const("LOBBY_TYPE_FRIENDS_ONLY", LOBBY_TYPE_FRIENDS_ONLY_FALLBACK)

	if not _steam_has_method("createLobby"):
		_lobby_toggle_pending_create = false
		_last_lobby_create_failed_result = -2
		_update_lobby_toggle_button_state()
		_update_character_invite_button_state()
		_update_continue_invite_button_state()
		_update_character_lobby_status_label_state()
		_update_continue_lobby_status_label_state()
		return

	_lobby_toggle_pending_create = true
	_lobby_toggle_close_after_create = false
	_last_lobby_create_failed_result = 0
	_update_lobby_toggle_button_state()
	_update_character_invite_button_state()
	_update_continue_invite_button_state()
	_update_character_lobby_status_label_state()
	_update_continue_lobby_status_label_state()
	_steam.createLobby(lobby_type, MAX_LOBBY_MEMBERS)


func open_invite_overlay() -> void:
	if not _ensure_steam_ready():
		return

	if _lobby_id == 0:
		return

	# Disabling Public closes the lobby immediately so stale public-browser rows
	# cannot still enter. Opening the explicit Steam invite dialog re-enables the
	# friends-only lobby for invited players without publishing it publicly again.
	if _is_game_host() and not _get_public_lobby_enabled():
		_prepare_friends_only_lobby_for_invite()

	if _steam_has_method("activateGameOverlayInviteDialog"):
		_steam.activateGameOverlayInviteDialog(_lobby_id)
	else:
		pass


func join_lobby(lobby_id) -> void:
	if lobby_id == null:
		_show_join_failure(_ui_text("join_failed_invalid"))
		return

	var target_lobby_id = _normalize_lobby_id(lobby_id)
	if target_lobby_id == 0:
		_show_join_failure(_ui_text("join_failed_invalid"))
		return

	# Only the first boot is gated. After the vanilla main menu has appeared once,
	# Steam Join continues to work from character selection, shop, battle, or any
	# other screen exactly as before.
	if not _startup_main_menu_ready:
		_startup_pending_join_lobby_id = target_lobby_id
		return

	if _client_join_request_started_msec == 0:
		_client_join_request_started_msec = OS.get_ticks_msec()

	if not _ensure_steam_ready():
		_pending_join_lobby_id = target_lobby_id
		return

	if _lobby_id != 0 and str(_lobby_id) == str(target_lobby_id):
		# Re-clicking Steam Join while the client is already in the lobby used to be a no-op.
		# If the first handshake was lost or suppressed by stale reliable packets, this left
		# the client stuck until the host restarted. Treat it as a handshake refresh.
		if not _is_game_host():
			_client_hello_retry_until_msec = OS.get_ticks_msec() + CLIENT_HELLO_RETRY_DURATION_MSEC
			_last_client_hello_retry_msec = 0
			_send_client_hello_to_host()
		return

	if _lobby_id != 0:
		leave_lobby()

	_reset_transient_online_state_for_new_session("join_lobby")
	_client_join_requested_lobby_id = target_lobby_id

	if not _steam_has_method("joinLobby"):
		_clear_pending_join_request()
		_show_join_failure(_ui_text("join_failed_steam_unavailable"))
		return

	var join_result = _steam.joinLobby(target_lobby_id)
	if typeof(join_result) == TYPE_BOOL and not bool(join_result):
		_clear_pending_join_request()
		_show_join_failure(_ui_text("join_failed_steam_unavailable"))


func leave_lobby() -> void:
	var leaving_lobby_id = _lobby_id
	_bump_online_session_generation("leave_lobby")
	_restore_client_retry_wave_setting_override()
	_close_tracked_p2p_sessions()
	_lobby_toggle_pending_create = false
	_lobby_toggle_close_after_create = false
	_last_lobby_create_failed_result = 0
	_open_invite_overlay_after_create = false
	if _steam != null and leaving_lobby_id != 0:
		if _steam_has_method("setLobbyJoinable"):
			_steam.setLobbyJoinable(leaving_lobby_id, false)
		if _steam_has_method("setLobbyData"):
			_steam.setLobbyData(leaving_lobby_id, "state", "closed")
			_steam.setLobbyData(leaving_lobby_id, "connect", "")
		if _steam_has_method("leaveLobby"):
			_steam.leaveLobby(leaving_lobby_id)

	_lobby_id = 0
	_is_lobby_owner = false
	_online_role = "none"
	_game_host_steam_id = ""
	_update_online_session_runtime_flag()
	_unlock_online_run_slots()
	_online_flow_started = false
	_online_flow_left_since_msec = 0
	_members.clear()
	_startup_pending_join_lobby_id = 0
	_pending_join_lobby_id = 0
	_client_join_requested_lobby_id = 0
	_client_join_request_started_msec = 0
	_clear_join_presence()
	_accepted_p2p_sessions.clear()
	_host_known_remote_ids.clear()
	_client_hello_retry_until_msec = 0
	_last_client_hello_retry_msec = 0
	_last_broadcast_selection_key = ""
	_sent_character_setup_key_by_steam_id.clear()
	_sent_weapon_setup_key_by_steam_id.clear()
	_sent_scene_transition_key_by_steam_id.clear()
	_full_item_list_scene_sync_required_by_steam_id.clear()
	_pending_p2p_chunk_sends.clear()
	_incoming_p2p_chunks.clear()
	_seen_client_hello_by_steam_id.clear()
	_client_seen_host_setup_key_by_sender.clear()
	_client_seen_host_setup_msec_by_sender.clear()
	_last_selection_request_reply_msec_by_steam_id.clear()
	_last_selection_request_setup_msec_by_steam_id.clear()
	_browser_ping_last_reply_msec_by_steam_id.clear()
	_last_battle_snapshot_send_msec = 0
	_last_battle_snapshot_sent_tick_by_steam_id.clear()
	_last_battle_reliable_sent_key_by_steam_id.clear()
	_last_battle_terminal_state_key_by_steam_id.clear()
	_last_battle_terminal_state_msec_by_steam_id.clear()
	_last_battle_snapshot_tx_log_msec = 0
	_client_battle_snapshot_rx_count = 0
	_last_client_battle_snapshot_rx_log_msec = 0
	_last_client_battle_snapshot_rx_tick = -1
	_official_continue_auto_lobby_armed = false
	_official_continue_auto_lobby_first_seen_msec = 0
	_official_continue_auto_lobby_done_for_scene_id = 0

	var slot_manager = _get_slot_manager()
	if slot_manager != null:
		if slot_manager.has_method("online_reset_to_offline"):
			slot_manager.online_reset_to_offline("leave_lobby")
		elif slot_manager.has_method("online_clear_remote_players"):
			slot_manager.online_clear_remote_players()

	var menu_sync = _get_menu_sync_manager()
	if menu_sync != null:
		if menu_sync.has_method("reset_online_session_state"):
			menu_sync.reset_online_session_state("leave_lobby")
		elif menu_sync.has_method("restore_progress_mirror"):
			menu_sync.restore_progress_mirror()

	var input_manager = _get_online_input_manager()
	if input_manager != null and input_manager.has_method("clear_remote_inputs"):
		input_manager.clear_remote_inputs()

	var battle_replica = _get_battle_replica_manager()
	if battle_replica != null and battle_replica.has_method("_clear_all"):
		battle_replica._clear_all("leave_lobby")

	_reset_game_start_sync_state()
	_clear_retry_wave_sync_state("game_start_reset")
	_drain_stale_p2p_packets()
	_update_lobby_toggle_button_state()
	_update_character_invite_button_state()
	_update_continue_invite_button_state()
	_update_character_lobby_status_label_state()
	_update_continue_lobby_status_label_state()
	_update_online_session_runtime_flag()

func is_host() -> bool:
	return _is_game_host()


func is_game_host() -> bool:
	return _is_game_host()


func is_lobby_host() -> bool:
	return _is_game_host()


func is_online_session_active() -> bool:
	return _has_active_online_session()


func has_active_online_session() -> bool:
	return _has_active_online_session()


func get_lobby_id() -> int:
	return int(_lobby_id)


func get_online_role() -> String:
	return _online_role


func is_public_lobby_enabled() -> bool:
	return _get_public_lobby_enabled()


func set_public_lobby_enabled(enabled: bool) -> void:
	var tree = get_tree()
	if tree != null and tree.root != null:
		tree.root.set_meta(META_PUBLIC_LOBBY_ENABLED, enabled)

	if _steam == null or _lobby_id == 0 or not _is_game_host():
		return

	# Close first. This invalidates stale public-browser rows before changing the
	# advertised type/metadata. A private lobby is reopened only through the
	# explicit Invite Friend action below.
	if _steam_has_method("setLobbyJoinable"):
		_steam.setLobbyJoinable(_lobby_id, false)

	var lobby_type = _get_steam_const("LOBBY_TYPE_PUBLIC", LOBBY_TYPE_PUBLIC_FALLBACK) if enabled else _get_steam_const("LOBBY_TYPE_FRIENDS_ONLY", LOBBY_TYPE_FRIENDS_ONLY_FALLBACK)
	if _steam_has_method("setLobbyType"):
		_steam.setLobbyType(_lobby_id, lobby_type)
	if _steam_has_method("setLobbyData"):
		_steam.setLobbyData(_lobby_id, "visibility", "public" if enabled else "friends")

	if enabled and _steam_has_method("setLobbyJoinable"):
		var joinable = _is_host_at_character_selection_for_lobby() or _is_in_official_coop_resume_scene()
		_steam.setLobbyJoinable(_lobby_id, joinable)


func _prepare_friends_only_lobby_for_invite() -> void:
	if _steam == null or _lobby_id == 0 or not _is_game_host():
		return
	if _steam_has_method("setLobbyType"):
		_steam.setLobbyType(_lobby_id, _get_steam_const("LOBBY_TYPE_FRIENDS_ONLY", LOBBY_TYPE_FRIENDS_ONLY_FALLBACK))
	if _steam_has_method("setLobbyData"):
		_steam.setLobbyData(_lobby_id, "visibility", "friends")
	if _steam_has_method("setLobbyJoinable"):
		var joinable = _is_host_at_character_selection_for_lobby() or _is_in_official_coop_resume_scene()
		_steam.setLobbyJoinable(_lobby_id, joinable)


func _get_public_lobby_enabled() -> bool:
	var tree = get_tree()
	if tree == null or tree.root == null or not tree.root.has_meta(META_PUBLIC_LOBBY_ENABLED):
		return false
	return bool(tree.root.get_meta(META_PUBLIC_LOBBY_ENABLED))


func get_self_steam_id() -> String:
	return _self_steam_id


func get_game_host_steam_id() -> String:
	return _get_game_host_steam_id()


func are_online_run_slots_locked() -> bool:
	return _online_run_slots_locked


func _get_version_adapter():
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineVersionAdapter")


func _steam_has_method(method_name: String) -> bool:
	if _steam == null:
		return false
	var adapter = _get_version_adapter()
	if adapter != null and adapter.has_method("has_method_cached"):
		return bool(adapter.has_method_cached(_steam, method_name))
	return _steam.has_method(method_name)


func _steam_has_signal(signal_name: String) -> bool:
	if _steam == null:
		return false
	var adapter = _get_version_adapter()
	if adapter != null and adapter.has_method("has_signal_cached"):
		return bool(adapter.has_signal_cached(_steam, signal_name))
	return _steam.has_signal(signal_name)


func _setup_steam() -> void:
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")
	else:
		return

	_try_init_steam()
	_update_self_steam_id()
	_steam_ready = _self_steam_id != "" and _self_steam_id != "0"


func _try_init_steam() -> void:
	if _steam == null:
		return

	# Do not call Steam.loggedOn() here. Some Brotato/GodotSteam builds expose the
	# method name but fail at runtime with "User class not found when calling loggedOn".
	# steamInitEx/steamInit plus getSteamID() is enough for this mod stage.
	if _steam_has_method("steamInitEx"):
		var init_result = _steam.steamInitEx(BROTATO_APP_ID, true)
	elif _steam_has_method("steamInit"):
		var init_result2 = _steam.steamInit()

	if _steam_has_method("initRelayNetworkAccess"):
		_steam.initRelayNetworkAccess()


func _connect_steam_signals() -> void:
	if _steam == null:
		return

	_connect_signal_if_exists("lobby_created", "_on_lobby_created")
	_connect_signal_if_exists("lobby_joined", "_on_lobby_joined")
	_connect_signal_if_exists("lobby_chat_update", "_on_lobby_chat_update")
	_connect_signal_if_exists("lobby_data_update", "_on_lobby_data_update")

	# GodotSteam 版本之间信号名可能不同，所以尽量兼容。
	_connect_signal_if_exists("join_requested", "_on_lobby_join_requested")
	_connect_signal_if_exists("game_lobby_join_requested", "_on_lobby_join_requested")
	_connect_signal_if_exists("rich_presence_join_requested", "_on_rich_presence_join_requested")
	_connect_signal_if_exists("game_rich_presence_join_requested", "_on_rich_presence_join_requested")
	_connect_signal_if_exists("join_game_requested", "_on_join_game_requested")
	_connect_signal_if_exists("game_join_requested", "_on_join_game_requested")
	_connect_signal_if_exists("network_messages_session_request", "_on_network_messages_session_request")
	_connect_signal_if_exists("networking_messages_session_request", "_on_network_messages_session_request")
	_connect_signal_if_exists("network_messages_session_failed", "_on_network_messages_session_failed")
	_connect_signal_if_exists("networking_messages_session_failed", "_on_network_messages_session_failed")


func _connect_signal_if_exists(signal_name: String, method_name: String) -> void:
	if not _steam_has_signal(signal_name):
		return

	if _steam.is_connected(signal_name, self, method_name):
		return

	var err = _steam.connect(signal_name, self, method_name)


func _on_lobby_created(connect_result = 0, lobby_id = 0) -> void:

	_lobby_toggle_pending_create = false
	if int(connect_result) != 1:
		_lobby_toggle_close_after_create = false
		_open_invite_overlay_after_create = false
		_last_lobby_create_failed_result = int(connect_result)
		_update_lobby_toggle_button_state()
		_update_character_invite_button_state()
		_update_continue_invite_button_state()
		_update_character_lobby_status_label_state()
		_update_continue_lobby_status_label_state()
		return

	_reset_transient_online_state_for_new_session("lobby_created")
	_last_lobby_create_failed_result = 0
	_lobby_id = lobby_id
	_client_join_requested_lobby_id = 0
	_is_lobby_owner = true
	_online_role = "host"
	_game_host_steam_id = _self_steam_id
	_unlock_online_run_slots()
	_online_flow_started = true
	_online_flow_left_since_msec = 0
	_pending_join_lobby_id = 0
	_seen_client_hello_by_steam_id.clear()
	_client_seen_host_setup_key_by_sender.clear()
	_client_seen_host_setup_msec_by_sender.clear()
	_last_selection_request_reply_msec_by_steam_id.clear()
	_last_selection_request_setup_msec_by_steam_id.clear()
	_direct_upgrade_ui_instance_id = 0
	_direct_upgrade_local_actions.clear()
	_direct_upgrade_seen_action_ids.clear()
	_direct_upgrade_pending_remote_actions.clear()
	_direct_upgrade_apply_guard = false
	_reset_game_start_sync_state()
	_clear_retry_wave_sync_state("game_start_reset")
	_sent_character_setup_key_by_steam_id.clear()
	_sent_weapon_setup_key_by_steam_id.clear()
	_sent_scene_transition_key_by_steam_id.clear()
	_update_self_steam_id()
	_setup_lobby_data()
	_setup_join_presence()
	_refresh_lobby_members(true)

	var should_open_invite_overlay = _open_invite_overlay_after_create
	_open_invite_overlay_after_create = false

	if _lobby_toggle_close_after_create:
		_lobby_toggle_close_after_create = false
		leave_lobby()
		return

	_update_lobby_toggle_button_state()
	_update_character_invite_button_state()
	_update_continue_invite_button_state()
	_update_character_lobby_status_label_state()
	_update_continue_lobby_status_label_state()
	_update_online_session_runtime_flag()
	if should_open_invite_overlay:
		call_deferred("open_invite_overlay")


func _on_lobby_joined(lobby_id = 0, permissions = 0, locked = false, response = 0) -> void:
	var response_code = int(response)
	var join_succeeded = response_code == LOBBY_JOIN_SUCCESS_RESPONSE
	# Compatibility with older GodotSteam builds that emitted only three signal
	# arguments and therefore leave the optional response parameter at zero.
	if response_code == 0 and int(lobby_id) != 0 and _steam != null and _steam_has_method("getLobbyOwner"):
		join_succeeded = int(_steam.getLobbyOwner(lobby_id)) != 0
	if not join_succeeded or int(lobby_id) == 0:
		_clear_pending_join_request()
		_show_join_failure(_get_lobby_join_failure_text(response_code))
		return

	var joined_from_client_request = _client_join_requested_lobby_id != 0 and str(_client_join_requested_lobby_id) == str(lobby_id)
	_client_join_request_started_msec = 0
	_reset_transient_online_state_for_new_session("lobby_joined")
	_lobby_id = lobby_id
	_pending_join_lobby_id = 0
	_online_flow_left_since_msec = 0
	_update_self_steam_id()
	_update_lobby_owner_state()
	var lobby_host_id = _read_lobby_game_host_steam_id()
	var owner_id = _get_lobby_owner_id()
	if joined_from_client_request:
		# A Steam lobby can migrate ownership to the client after the real host closes it.
		# Joining such a stale lobby must not promote this client to game host, otherwise
		# both peers wait for authority and the difficulty page becomes unusable.
		if lobby_host_id != "" and lobby_host_id != _self_steam_id:
			_game_host_steam_id = lobby_host_id
			_online_role = "client"
		elif owner_id != "" and owner_id != _self_steam_id:
			_game_host_steam_id = owner_id
			_online_role = "client"
		else:
			leave_lobby()
			_show_join_failure(_ui_text("join_failed_stale"))
			return
	else:
		_game_host_steam_id = lobby_host_id
		if _game_host_steam_id == "":
			_game_host_steam_id = owner_id
		if _game_host_steam_id == _self_steam_id or (_game_host_steam_id == "" and _is_lobby_owner):
			_online_role = "host"
			_game_host_steam_id = _self_steam_id
		else:
			_online_role = "client"
	_client_join_requested_lobby_id = 0
	_unlock_online_run_slots()
	_reset_game_start_sync_state()
	_clear_retry_wave_sync_state("game_start_reset")
	if _is_game_host():
		_setup_lobby_data()
		_setup_join_presence()
		_client_hello_retry_until_msec = 0
		_last_client_hello_retry_msec = 0
	else:
		_setup_client_presence()
		_client_hello_retry_until_msec = OS.get_ticks_msec() + CLIENT_HELLO_RETRY_DURATION_MSEC
		_last_client_hello_retry_msec = 0
	_refresh_lobby_members(true)
	_update_lobby_toggle_button_state()
	_update_character_invite_button_state()
	_update_continue_invite_button_state()
	_update_character_lobby_status_label_state()
	_update_continue_lobby_status_label_state()
	_update_online_session_runtime_flag()
	if not _is_game_host():
		_send_client_hello_to_host()


func _clear_pending_join_request() -> void:
	_startup_pending_join_lobby_id = 0
	_pending_join_lobby_id = 0
	_client_join_requested_lobby_id = 0
	_client_join_request_started_msec = 0
	_remove_joining_overlay()
	_update_online_session_runtime_flag()


func _poll_join_request_timeout() -> void:
	if _pending_join_lobby_id == 0 and _client_join_requested_lobby_id == 0:
		_client_join_request_started_msec = 0
		return
	if _client_join_request_started_msec == 0:
		_client_join_request_started_msec = OS.get_ticks_msec()
		return
	if OS.get_ticks_msec() - _client_join_request_started_msec < LOBBY_JOIN_TIMEOUT_MSEC:
		return
	_clear_pending_join_request()
	_show_join_failure(_ui_text("join_failed_timeout"))


func _get_lobby_join_failure_text(response_code: int) -> String:
	match response_code:
		2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 15:
			return _ui_text("join_response_" + str(response_code))
		_:
			return _ui_text("join_response_unknown") % response_code


func _show_join_failure(message: String) -> void:
	_remove_joining_overlay()
	call_deferred("_show_join_failure_deferred", message)


func _show_join_failure_deferred(message: String) -> void:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return
	var parent = tree.current_scene
	if parent == null:
		parent = tree.root

	if _join_failure_dialog != null and is_instance_valid(_join_failure_dialog):
		_join_failure_dialog.dialog_text = message
		_join_failure_dialog.window_title = _ui_text("join_failed_title")
		_join_failure_dialog.popup_centered(Vector2(520, 220))
		return

	var dialog = AcceptDialog.new()
	dialog.name = "BrotatoOnlineJoinFailureDialog"
	dialog.pause_mode = Node.PAUSE_MODE_PROCESS
	dialog.window_title = _ui_text("join_failed_title")
	dialog.dialog_text = message
	dialog.rect_min_size = Vector2(520, 220)
	parent.add_child(dialog)
	_join_failure_dialog = dialog
	_join_failure_dialog_parent = parent
	dialog.connect("popup_hide", self, "_on_join_failure_dialog_hidden")
	dialog.popup_centered(Vector2(520, 220))


func _on_join_failure_dialog_hidden() -> void:
	if _join_failure_dialog != null and is_instance_valid(_join_failure_dialog):
		_join_failure_dialog.queue_free()
	_join_failure_dialog = null
	_join_failure_dialog_parent = null


func _on_lobby_chat_update(lobby_id = 0, changed_id = 0, making_change_id = 0, chat_state = 0) -> void:
	if _lobby_id == 0 or str(lobby_id) != str(_lobby_id):
		return

	_refresh_lobby_members()


func _on_lobby_data_update(success = false, lobby_id = 0, member_id = 0) -> void:
	if _lobby_id == 0 or str(lobby_id) != str(_lobby_id):
		return

	_refresh_lobby_members()


func _on_lobby_join_requested(lobby_id = 0, friend_id = 0) -> void:
	join_lobby(lobby_id)


func _on_rich_presence_join_requested(friend_id = 0, connect_string = "") -> void:
	var parsed_lobby_id = _parse_lobby_id_from_connect_string(str(connect_string))
	if parsed_lobby_id == 0:
		return

	join_lobby(parsed_lobby_id)


func _on_join_game_requested(arg0 = null, arg1 = null) -> void:
	# GodotSteam builds disagree on join_game_requested signature. Some emit one
	# argument, others emit two. Accept both to avoid a dead Steam Join path.
	var parsed_lobby_id = 0

	if typeof(arg0) == TYPE_ARRAY:
		parsed_lobby_id = _parse_lobby_id_from_args(arg0)
	elif arg0 != null:
		parsed_lobby_id = _parse_lobby_id_from_connect_string(str(arg0))

	if parsed_lobby_id == 0 and arg1 != null:
		if typeof(arg1) == TYPE_ARRAY:
			parsed_lobby_id = _parse_lobby_id_from_args(arg1)
		else:
			parsed_lobby_id = _parse_lobby_id_from_connect_string(str(arg1))

	if parsed_lobby_id == 0:
		var combined_args = []
		if arg0 != null:
			combined_args.append(arg0)
		if arg1 != null:
			combined_args.append(arg1)
		parsed_lobby_id = _parse_lobby_id_from_args(combined_args)

	if parsed_lobby_id == 0:
		return

	join_lobby(parsed_lobby_id)


func _setup_lobby_data() -> void:
	if _steam == null or _lobby_id == 0:
		return

	var public_lobby = _get_public_lobby_enabled()
	var lobby_type = _get_steam_const("LOBBY_TYPE_PUBLIC", LOBBY_TYPE_PUBLIC_FALLBACK) if public_lobby else _get_steam_const("LOBBY_TYPE_FRIENDS_ONLY", LOBBY_TYPE_FRIENDS_ONLY_FALLBACK)
	if _steam_has_method("setLobbyType"):
		_steam.setLobbyType(_lobby_id, lobby_type)
	if _steam_has_method("setLobbyJoinable"):
		_steam.setLobbyJoinable(_lobby_id, true)

	if _steam_has_method("setLobbyData"):
		var host_name = _self_steam_id
		if _steam_has_method("getPersonaName"):
			host_name = str(_steam.getPersonaName()).strip_edges()
		if host_name.length() > 64:
			host_name = host_name.substr(0, 64)
		_steam.setLobbyData(_lobby_id, "mod", "six666-BrotatoOnline")
		_steam.setLobbyData(_lobby_id, "mod_version", MOD_VERSION)
		_steam.setLobbyData(_lobby_id, "game_version", "1.1.15.4")
		_steam.setLobbyData(_lobby_id, "state", "character_selection")
		_steam.setLobbyData(_lobby_id, "host", _self_steam_id)
		_steam.setLobbyData(_lobby_id, "host_name", host_name)
		_steam.setLobbyData(_lobby_id, "member_count", "1")
		_steam.setLobbyData(_lobby_id, "member_limit", str(MAX_LOBBY_MEMBERS))
		_steam.setLobbyData(_lobby_id, "visibility", "public" if public_lobby else "friends")
		_steam.setLobbyData(_lobby_id, "connect", _make_lobby_connect_string(_lobby_id))


func _setup_join_presence() -> void:
	if _steam == null or _lobby_id == 0:
		return

	var connect_string = _make_lobby_connect_string(_lobby_id)
	_set_rich_presence("status", "BrotatoOnline Lobby")
	_set_rich_presence("connect", connect_string)


func _setup_client_presence() -> void:
	if _steam == null or _lobby_id == 0:
		return

	_set_rich_presence("status", "BrotatoOnline Client")
	_set_rich_presence("connect", _make_lobby_connect_string(_lobby_id))


func _clear_join_presence() -> void:
	_set_rich_presence("connect", "")
	_set_rich_presence("status", "")


func _set_rich_presence(key: String, value: String) -> void:
	if _steam == null:
		return

	if _steam_has_method("setRichPresence"):
		var ok = _steam.setRichPresence(key, value)
	else:
		pass


func _clear_stale_join_presence_at_boot() -> void:
	if _join_presence_cleared_at_boot:
		return
	if _steam == null:
		return
	_join_presence_cleared_at_boot = true
	if _lobby_id != 0:
		return
	# Steam Rich Presence can survive a previous crash/forced quit long enough for
	# friends to still see a Join button. Never publish a connect string unless a
	# real BrotatoOnline lobby exists.
	_clear_join_presence()


func _refresh_lobby_members(force_slot_sync: bool = false) -> void:
	var previous_member_ids = []
	for previous_member in _members:
		var previous_id = str(previous_member.get("steam_id", ""))
		if previous_id != "":
			previous_member_ids.append(previous_id)
	previous_member_ids.sort()

	_members.clear()
	if _steam == null or _lobby_id == 0:
		return

	_update_lobby_owner_state()

	if not _steam_has_method("getNumLobbyMembers") or not _steam_has_method("getLobbyMemberByIndex"):
		return

	var owner_id = _get_lobby_owner_id()
	var count = int(_steam.getNumLobbyMembers(_lobby_id))
	var current_member_ids = []
	for i in range(count):
		var member_id = str(_steam.getLobbyMemberByIndex(_lobby_id, i))
		var member_name = member_id
		if _steam_has_method("getFriendPersonaName"):
			member_name = str(_steam.getFriendPersonaName(int(member_id)))

		_members.append({
			"steam_id": member_id,
			"name": member_name,
			"owner": member_id == owner_id
		})
		if member_id != "":
			current_member_ids.append(member_id)

	current_member_ids.sort()
	var membership_changed = to_json(previous_member_ids) != to_json(current_member_ids)

	if not _is_game_host() and _game_host_steam_id != "" and not _member_list_has_steam_id(_game_host_steam_id):
		leave_lobby()
		return

	# Ordinary lobby metadata updates (state, host name, visibility, etc.) must not
	# rebuild COOP slots. Creation/join/restage paths may force one repair because
	# P0 can be missing even when the Steam member set itself has not changed.
	if membership_changed or force_slot_sync:
		_sync_host_coop_slots_from_lobby()
	_update_character_lobby_status_label_state()
	_update_continue_lobby_status_label_state()


func _member_list_has_steam_id(steam_id: String) -> bool:
	for member in _members:
		if str(member.get("steam_id", "")) == steam_id:
			return true
	return false


func _sync_host_coop_slots_from_lobby() -> void:
	if not _is_game_host():
		return

	# COOP slot topology is only mutable during menu staging. Once the online run has entered
	# battle/shop, never rebuild from Steam lobby membership; doing so can erase P2 while the
	# authoritative run is alive.
	if _should_freeze_online_run_slots():
		_log_slot_sync_skipped("lobby_sync")
		_sync_slot_manager_lock_flag()
		return

	var slot_manager = _get_slot_manager()
	if slot_manager == null or not slot_manager.has_method("online_sync_remote_steam_ids"):
		return

	var remote_ids = _get_remote_ids_for_host_sync()
	slot_manager.online_sync_remote_steam_ids(remote_ids)
	_schedule_prime_and_broadcast_after_remote_join()


func _get_remote_ids_for_host_sync() -> Array:
	# Only current Steam lobby members may own online COOP placeholder slots.
	# _host_known_remote_ids is only a short-lived packet de-dupe/cache; using it as
	# authoritative membership can resurrect old clients after they left the room,
	# which creates an uncontrollable/never-confirmable character on the host.
	var remote_ids = []
	for member in _members:
		var steam_id = str(member.get("steam_id", ""))
		if steam_id == "" or steam_id == _self_steam_id or remote_ids.has(steam_id):
			continue
		remote_ids.append(steam_id)

	_prune_host_known_remote_ids_to_current_members(remote_ids)
	return remote_ids


func _prune_host_known_remote_ids_to_current_members(current_remote_ids: Array) -> void:
	for i in range(_host_known_remote_ids.size() - 1, -1, -1):
		var known_id = str(_host_known_remote_ids[i])
		if known_id == "" or known_id == _self_steam_id or not current_remote_ids.has(known_id):
			_host_known_remote_ids.remove(i)


func _is_current_lobby_remote_member(steam_id: String) -> bool:
	if steam_id == "" or steam_id == "0" or steam_id == _self_steam_id:
		return false
	if _lobby_id == 0 or _steam == null:
		return false
	for member in _members:
		if str(member.get("steam_id", "")) == steam_id:
			return true
	if _steam_has_method("getNumLobbyMembers") and _steam_has_method("getLobbyMemberByIndex"):
		var count = int(_steam.getNumLobbyMembers(_lobby_id))
		for i in range(count):
			if str(_steam.getLobbyMemberByIndex(_lobby_id, i)) == steam_id:
				return true
	return false


func _remember_host_remote_id(steam_id: String) -> bool:
	if steam_id == "" or steam_id == "0" or steam_id == _self_steam_id:
		return false
	if _host_known_remote_ids.has(steam_id):
		return false
	_host_known_remote_ids.append(steam_id)
	return true


func _ensure_host_coop_slot_for_remote(steam_id: String) -> bool:
	if not _is_game_host() or _lobby_id == 0:
		return false
	if steam_id == "" or steam_id == "0" or steam_id == _self_steam_id:
		return false
	# Reliable P2P packets from a previous room can arrive late. Do not let such
	# packets recreate a remote placeholder unless the sender is still in the
	# current Steam lobby.
	if not _is_current_lobby_remote_member(steam_id):
		_host_known_remote_ids.erase(steam_id)
		return false

	var was_new = _remember_host_remote_id(steam_id)
	var needs_sync = was_new
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("get_player_index_for_steam_id"):
		if int(slot_manager.get_player_index_for_steam_id(steam_id)) < 0:
			needs_sync = true

	if needs_sync:
		if _should_freeze_online_run_slots():
			_log_slot_sync_skipped("ensure_remote:" + steam_id)
			return false
		_sync_host_coop_slots_from_lobby()
	return needs_sync


func _schedule_prime_and_broadcast_after_remote_join() -> void:
	# CharacterSelection updates via vanilla connected_players_updated. Give it a tick,
	# then prime empty focus slots and broadcast the resulting complete state.
	# The generation fence prevents delayed callbacks from a closed/reopened lobby
	# from touching the next CharacterSelection scene.
	var generation = _online_session_generation
	call_deferred("_prime_character_selection_and_broadcast_for_generation", generation)
	var tree = get_tree()
	if tree != null:
		var timer_a = tree.create_timer(0.10)
		timer_a.connect("timeout", self, "_prime_character_selection_and_broadcast_for_generation", [generation])
		var timer_b = tree.create_timer(0.25)
		timer_b.connect("timeout", self, "_prime_character_selection_and_broadcast_for_generation", [generation])


func _prime_character_selection_and_broadcast_for_generation(generation: int) -> void:
	if int(generation) != int(_online_session_generation):
		return
	_prime_character_selection_and_broadcast()


func _prime_character_selection_and_broadcast() -> void:
	if not _is_game_host() or _lobby_id == 0:
		return

	var menu_sync = _get_menu_sync_manager()
	if menu_sync != null and menu_sync.has_method("host_auto_prime_character_selection_after_remote_join"):
		menu_sync.host_auto_prime_character_selection_after_remote_join()

	_send_host_phase_messages_to_all(false)
	_broadcast_selection_state(true)

func _update_lobby_owner_state() -> void:
	var owner_id = _get_lobby_owner_id()
	_update_self_steam_id()
	_is_lobby_owner = owner_id != "" and _self_steam_id != "" and owner_id == _self_steam_id


func _get_lobby_owner_id() -> String:
	if _steam == null or _lobby_id == 0:
		return ""

	if _steam_has_method("getLobbyOwner"):
		return str(_steam.getLobbyOwner(_lobby_id))

	return ""


func _update_self_steam_id() -> void:
	if _steam != null and _steam_has_method("getSteamID"):
		_self_steam_id = str(_steam.getSteamID())


func _ensure_steam_ready() -> bool:
	if _steam == null:
		_setup_steam()
		_connect_steam_signals()

	if _steam == null:
		return false

	_update_self_steam_id()
	_steam_ready = _self_steam_id != "" and _self_steam_id != "0"

	if not _steam_ready:
		return false

	if _lobby_id == 0:
		_clear_stale_join_presence_at_boot()

	return true


func _run_steam_callbacks() -> void:
	if _steam == null:
		return

	if _steam_has_method("run_callbacks"):
		_steam.run_callbacks()
	elif _steam_has_method("runCallbacks"):
		_steam.runCallbacks()


func _poll_and_send_local_client_menu_input() -> void:
	if _lobby_id == 0 or _is_game_host():
		return

	var now = OS.get_ticks_msec()
	if now - _last_client_menu_input_poll_msec < CLIENT_MENU_INPUT_POLL_INTERVAL_MSEC:
		return
	_last_client_menu_input_poll_msec = now

	var menu_sync_client = _get_menu_sync_manager()
	if menu_sync_client == null or not menu_sync_client.has_method("consume_local_client_menu_messages"):
		return

	var messages = menu_sync_client.consume_local_client_menu_messages()
	if typeof(messages) != TYPE_ARRAY:
		return

	for msg in messages:
		if typeof(msg) == TYPE_DICTIONARY and not msg.empty():
			send_menu_message_to_host(msg)


func _poll_and_send_local_client_battle_input() -> void:
	if _lobby_id == 0 or _is_game_host():
		return

	var input_manager = _get_online_input_manager()
	if input_manager == null or not input_manager.has_method("consume_local_battle_input_messages"):
		return

	var messages = input_manager.consume_local_battle_input_messages()
	if typeof(messages) != TYPE_ARRAY:
		return

	for msg in messages:
		if typeof(msg) == TYPE_DICTIONARY and not msg.empty():
			send_battle_message_to_host(msg, true)


func _notify_menu_sync_game_start_guard(start_id: int, reason: String) -> void:
	var menu_sync = _get_menu_sync_manager()
	if menu_sync != null and menu_sync.has_method("begin_game_start_guard"):
		menu_sync.begin_game_start_guard(start_id, reason)


func _is_run_page_action_guarded_by_game_start(action_type: String) -> bool:
	return action_type.begins_with("shop") or action_type.begins_with("upgrade") or action_type.begins_with("item_box")


func _poll_and_send_local_run_page_actions() -> void:
	if _lobby_id == 0:
		return
	if _is_game_host() and not _pending_host_game_start.empty():
		return
	if not _is_game_host() and OS.get_ticks_msec() < _client_ignore_stale_menu_until_msec:
		return
	var menu_sync = _get_menu_sync_manager()
	if menu_sync == null or not menu_sync.has_method("consume_local_run_page_action_messages"):
		return
	var messages = menu_sync.consume_local_run_page_action_messages()
	if typeof(messages) != TYPE_ARRAY:
		return
	for msg in messages:
		if typeof(msg) != TYPE_DICTIONARY or msg.empty():
			continue
		# Shop/upgrade focus packets are cosmetic. Receivers apply shop focus visual-only
		# and clients ignore their own echoed focus packets.
		_local_run_page_action_seq += 1
		msg["origin_steam_id"] = _self_steam_id
		msg["action_id"] = _self_steam_id + ":" + str(_local_run_page_action_seq)
		if _is_game_host():
			_broadcast_run_page_action_sync(msg, "")
		else:
			send_menu_message_to_host(msg)


func _client_should_drop_stale_menu_scene_state(message: Dictionary) -> bool:
	if _is_game_host():
		return false
	var screen = str(message.get("screen", ""))
	if screen == "":
		return false
	var now = OS.get_ticks_msec()
	var in_game = _is_in_game_scene()
	var in_game_start_guard = now < _client_ignore_stale_menu_until_msec

	# After game_start_prepare/commit, reliable packets from the old shop/difficulty
	# page may still arrive. Drop them before they enter MenuSyncManager, otherwise the
	# client can spend a long frame applying stale page state while main.tscn is loading.
	if in_game_start_guard and screen != "game":
		var menu_sync_guard = _get_menu_sync_manager()
		if menu_sync_guard != null and menu_sync_guard.has_method("should_accept_page_state_during_game_start_guard") and bool(menu_sync_guard.should_accept_page_state_during_game_start_guard("menu_scene", screen)):
			return false
		return true

	# game_start_commit is now the only normal shop/difficulty -> battle scene entry.
	# Host still broadcasts screen=game as phase state after it enters battle; that packet
	# is useful as an old-host fallback, but during/just after a commit it is a duplicate
	# and caused a second receive_menu_scene_state_from_host() path on the client.
	if in_game_start_guard and screen == "game":
		var commit_pending = not _pending_client_game_start_commit.empty()
		var commit_deferred = not _pending_client_game_start_deferred_commit.empty() or _pending_client_game_start_deferred_call_queued
		var recently_applied_commit = _client_last_game_scene_apply_msec > 0 and now - _client_last_game_scene_apply_msec < CLIENT_STALE_MENU_GUARD_MSEC
		var recently_prepared = _client_game_start_prepare_msec > 0 and now - _client_game_start_prepare_msec < GAME_START_MAX_WAIT_MSEC
		if commit_pending or commit_deferred or recently_applied_commit or recently_prepared:
			return true

	# A large reliable screen=game menu_scene_state can be delivered very late (observed
	# near wave end). If it matches the already-applied start_id, dropping it here avoids
	# re-arming MenuSyncManager's game-start guard and losing upgrade_state/shop packets.
	if in_game and screen == "game":
		var game_start_sync = message.get("game_start_sync", {})
		var message_start_id = 0
		if typeof(game_start_sync) == TYPE_DICTIONARY:
			message_start_id = int(game_start_sync.get("start_id", 0))
		if message_start_id > 0 and _last_client_game_start_commit_id > 0 and message_start_id <= _last_client_game_start_commit_id:
			return true

	# There is no valid online transition from an active battle back to character/weapon/
	# difficulty selection. Shop is allowed after the guard window for normal wave end.
	if in_game and (screen == "character_selection" or screen == "weapon_selection" or screen == "difficulty_selection"):
		return true

	return false

func _client_should_drop_stale_run_page_action(message: Dictionary) -> bool:
	if _is_game_host():
		return false
	var action_type = str(message.get("action_type", ""))
	if action_type == "":
		return false
	var now = OS.get_ticks_msec()
	# Upgrade/item-box pages also live under main.tscn. Using _is_in_game_scene() here
	# incorrectly dropped legitimate wave-end upgrade_* actions after the first battle.
	# Only drop guarded page actions while the explicit shop/difficulty -> game transition
	# guard is active.
	if _is_run_page_action_guarded_by_game_start(action_type) and now < _client_ignore_stale_menu_until_msec:
		var menu_sync_guard = _get_menu_sync_manager()
		if menu_sync_guard != null and menu_sync_guard.has_method("should_accept_page_state_during_game_start_guard") and bool(menu_sync_guard.should_accept_page_state_during_game_start_guard("run_page_action", action_type)):
			return false
		return true
	return false


func _handle_run_page_action_sync(from_steam_id: String, message: Dictionary) -> void:
	var incoming_action_type = str(message.get("action_type", ""))
	if _is_game_host() and not _pending_host_game_start.empty() and _is_run_page_action_guarded_by_game_start(incoming_action_type):
		return
	if not _is_game_host():
		var menu_sync_client = _get_menu_sync_manager()
		if menu_sync_client != null and menu_sync_client.has_method("receive_run_page_action_sync"):
			menu_sync_client.receive_run_page_action_sync(from_steam_id, message, _self_steam_id)
		return

	_ensure_host_coop_slot_for_remote(from_steam_id)
	if not message.has("origin_steam_id") or str(message.get("origin_steam_id", "")) == "":
		message["origin_steam_id"] = from_steam_id
	var menu_sync_host = _get_menu_sync_manager()
	if menu_sync_host != null and menu_sync_host.has_method("receive_run_page_action_sync"):
		var corrected_state = menu_sync_host.receive_run_page_action_sync(from_steam_id, message, _self_steam_id)
		if incoming_action_type == "shop_buy":
			_route_host_shop_buy_result(from_steam_id, message, corrected_state)
			return
		if typeof(corrected_state) == TYPE_DICTIONARY and not corrected_state.empty():
			# resolved_item is only an internal Host helper for building state_after.
			# Do not echo it back, or a tiny action can become a large packet.
			message.erase("resolved_item")
			var state_for_action = corrected_state.duplicate(true)
			var all_states = state_for_action.get("all_player_states", [])
			if typeof(all_states) == TYPE_ARRAY and not all_states.empty():
				message["host_states_after"] = all_states
				state_for_action.erase("all_player_states")
			message["host_state_after"] = state_for_action
			message["state_after"] = state_for_action
	_broadcast_run_page_action_sync(message, "")


func _route_host_shop_buy_result(from_steam_id: String, request: Dictionary, result) -> void:
	if not _is_game_host() or from_steam_id == "":
		return
	if typeof(result) != TYPE_DICTIONARY or not bool(result.get("shop_buy_protocol", false)):
		return

	var base = request.duplicate(true)
	# Host-side execution may attach a resolved item for local use. Network purchase
	# packets stay identity-only.
	base.erase("resolved_item")
	base.erase("resolved_shop_index")
	base.erase("host_state_after")
	base.erase("state_after")
	base.erase("host_states_after")
	if result.has("steal_extra_enemies_next_wave"):
		base["steal_extra_enemies_next_wave"] = result.get("steal_extra_enemies_next_wave", []).duplicate(true)

	if bool(result.get("host_applied", false)):
		# The requester already executed the real purchase. Send only an acknowledgement
		# to it, then replay the purchase event on every other Client.
		var acknowledgement = base.duplicate(true)
		acknowledgement["shop_buy_result"] = "success"
		acknowledgement["shop_buy_event"] = false
		acknowledgement["host_applied"] = true
		_send_p2p_json(from_steam_id, acknowledgement, true)

		var purchase_event = base.duplicate(true)
		purchase_event.erase("shop_buy_result")
		purchase_event["shop_buy_event"] = true
		purchase_event["host_applied"] = true
		_broadcast_run_page_action_sync(purchase_event, from_steam_id)
		return

	# Failure is private to the requester. It receives an explicit failure plus the
	# authoritative full player/shop state; unrelated Clients receive nothing.
	var failure = base.duplicate(true)
	failure["shop_buy_result"] = "failure"
	failure["shop_buy_event"] = false
	failure["host_applied"] = false
	var full_sync = result.get("full_sync", {})
	if typeof(full_sync) == TYPE_DICTIONARY and not full_sync.empty():
		failure["host_state_after"] = full_sync
		failure["state_after"] = full_sync
	_send_p2p_json(from_steam_id, failure, true)


func _broadcast_run_page_action_sync(message: Dictionary, except_steam_id: String = "") -> void:
	if not _is_game_host() or _lobby_id == 0:
		return
	for member in _members:
		var steam_id = str(member.get("steam_id", ""))
		if steam_id == "" or steam_id == _self_steam_id:
			continue
		if except_steam_id != "" and steam_id == except_steam_id:
			continue
		_send_p2p_json(steam_id, message, true)


func _clear_focus_input_transition_guards() -> void:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return
	var root = tree.root
	var meta_keys = [
		"brotato_online_keyboard_move_latch",
		"brotato_online_device_move_press_latch",
		"brotato_online_focus_move_burst_guard",
		"brotato_online_keyboard_move_latch_log_msec",
		"brotato_online_device_move_latch_log_msec",
		"brotato_online_focus_move_burst_guard_log_msec"
	]
	for key in meta_keys:
		if root.has_meta(key):
			root.remove_meta(key)


func _bump_online_session_generation(reason: String = "") -> void:
	_online_session_generation += 1
	_clear_focus_input_transition_guards()


func _reset_transient_online_state_for_new_session(reason: String = "") -> void:
	_bump_online_session_generation(reason)
	_restore_client_retry_wave_setting_override()
	_last_online_character_selection_restage_scene_id = 0
	# Clear per-lobby runtime state before accepting a new lobby/session. Steam reliable P2P
	# can deliver old packets after leaving/rejoining; caches from the previous room must not
	# be reused by the next room.
	_unlock_online_run_slots()
	_reset_game_start_sync_state()
	_clear_retry_wave_sync_state("game_start_reset")
	_last_selection_broadcast_msec = 0
	_last_broadcast_selection_key = ""
	_sent_character_setup_key_by_steam_id.clear()
	_sent_weapon_setup_key_by_steam_id.clear()
	_sent_scene_transition_key_by_steam_id.clear()
	_full_item_list_scene_sync_required_by_steam_id.clear()
	_pending_p2p_chunk_sends.clear()
	_incoming_p2p_chunks.clear()
	_seen_client_hello_by_steam_id.clear()
	_client_seen_host_setup_key_by_sender.clear()
	_client_seen_host_setup_msec_by_sender.clear()
	_last_selection_request_reply_msec_by_steam_id.clear()
	_last_selection_request_setup_msec_by_steam_id.clear()
	_host_known_remote_ids.clear()
	_last_battle_snapshot_send_msec = 0
	_last_battle_snapshot_sent_tick_by_steam_id.clear()
	_last_battle_reliable_sent_key_by_steam_id.clear()
	_last_battle_terminal_state_key_by_steam_id.clear()
	_last_battle_terminal_state_msec_by_steam_id.clear()
	_pending_client_game_start_commit = {}
	_pending_client_game_start_deferred_commit = {}
	_pending_client_game_start_deferred_call_queued = false
	_client_game_start_prepare_msec = 0
	_last_client_game_start_commit_id = 0
	_client_ignore_stale_menu_until_msec = 0
	_client_last_game_scene_apply_msec = 0
	_pending_client_game_scene_ready_start_id = 0
	_sent_client_game_scene_ready_start_id = 0
	_direct_upgrade_ui_instance_id = 0
	_direct_upgrade_local_actions.clear()
	_direct_upgrade_seen_action_ids.clear()
	_direct_upgrade_pending_remote_actions.clear()
	_direct_upgrade_apply_guard = false
	var menu_sync = _get_menu_sync_manager()
	if menu_sync != null and menu_sync.has_method("reset_online_session_state"):
		menu_sync.reset_online_session_state(reason)
	var battle_replica = _get_battle_replica_manager()
	if battle_replica != null and battle_replica.has_method("_clear_all"):
		battle_replica._clear_all("new_session:" + str(reason))


func _annotate_online_session_message(message: Dictionary) -> Dictionary:
	var wire = message.duplicate(true)
	if _lobby_id != 0:
		wire["lobby_id"] = str(_lobby_id)
		wire["session_lobby_id"] = str(_lobby_id)
	var host_id = _get_game_host_steam_id()
	if host_id != "":
		wire["game_host_steam_id"] = host_id
	if _self_steam_id != "":
		wire["sender_steam_id"] = _self_steam_id
	_annotate_battle_generation_fields(wire)
	return wire


func _is_battle_generation_message_type(msg_type: String) -> bool:
	return msg_type == "battle_snapshot" or msg_type == "battle_reliable_events" or msg_type == "battle_terminal_state" or msg_type == "battle_input" or msg_type == "damage_claim_batch" or msg_type == "player_hp_state" or msg_type == "player_state" or msg_type == "entity_kill_claim" or msg_type == "boss_damage_report" or msg_type == "pickup_claim" or msg_type == "battle_entity_resync_request"


func _is_client_to_host_battle_message_type(msg_type: String) -> bool:
	return msg_type == "battle_input" or msg_type == "damage_claim_batch" or msg_type == "player_hp_state" or msg_type == "player_state" or msg_type == "entity_kill_claim" or msg_type == "boss_damage_report" or msg_type == "pickup_claim" or msg_type == "battle_entity_resync_request"


func _annotate_battle_generation_fields(wire: Dictionary) -> void:
	var msg_type = str(wire.get("msg_type", ""))
	if not _is_battle_generation_message_type(msg_type):
		return
	var start_id = _host_current_battle_start_id if _is_game_host() else _client_active_battle_start_id
	if start_id > 0:
		wire["battle_start_id"] = start_id
		# Compact battle_snapshot packets keep this short field too; receivers accept either.
		wire["bs"] = start_id
	var start_kind = _host_current_battle_start_kind if _is_game_host() else _client_active_battle_start_kind
	if start_kind != "":
		wire["battle_start_kind"] = start_kind
	var retry_context = _host_current_retry_context_key if _is_game_host() else _client_active_retry_context_key
	if retry_context != "":
		wire["battle_retry_context_key"] = retry_context


func _extract_battle_start_id(message: Dictionary) -> int:
	if typeof(message) != TYPE_DICTIONARY:
		return 0
	if message.has("battle_start_id"):
		return int(message.get("battle_start_id", 0))
	if message.has("bs"):
		return int(message.get("bs", 0))
	return 0


func _arm_client_battle_generation_fence(start_id: int, start_kind: String, retry_context_key: String, reason: String) -> void:
	if start_id <= 0:
		return
	_client_expected_battle_start_id = start_id
	_client_expected_battle_start_kind = start_kind
	_client_expected_retry_context_key = retry_context_key
	_client_battle_start_fence_until_msec = OS.get_ticks_msec() + BATTLE_START_GENERATION_FENCE_MSEC
	# A confirmed RetryWave leaves the local client in a waiting state until the
	# battle scene changes. Clear that latch as soon as the host starts any new
	# battle generation, otherwise a later failure on the same wave can inherit
	# the previous ready state and keep the Retry button disabled.
	_clear_client_retry_wave_waiting_latch("battle_generation_fence:" + str(reason))
	if retry_context_key != "":
		_retry_wave_host_context_key = retry_context_key


func _activate_client_battle_generation_for_send(start_id: int, start_kind: String, retry_context_key: String, reason: String) -> void:
	if start_id <= 0:
		return
	_client_active_battle_start_id = start_id
	_client_active_battle_start_kind = start_kind
	_client_active_retry_context_key = retry_context_key


func _activate_host_battle_generation(start_id: int, start_kind: String, retry_context_key: String, reason: String) -> void:
	if start_id <= 0:
		return
	_host_current_battle_start_id = start_id
	_host_current_battle_start_kind = start_kind
	_host_current_retry_context_key = retry_context_key
	_host_battle_start_fence_until_msec = OS.get_ticks_msec() + BATTLE_START_GENERATION_FENCE_MSEC
	# Gate the first battle snapshot for every synced start, not only RetryWave.
	# Difficulty wave 1 and shop->battle can otherwise leak a cached/pre-start 0s timer
	# snapshot to clients and make them run the vanilla wave timeout immediately.
	_ensure_host_retry_first_snapshot_gate_armed(start_id, "activate:" + str(reason), true, _current_scene_instance_id())
	_last_battle_snapshot_sent_tick_by_steam_id.clear()
	_last_battle_reliable_sent_key_by_steam_id.clear()
	_last_battle_terminal_state_key_by_steam_id.clear()
	_last_battle_terminal_state_msec_by_steam_id.clear()


func _should_drop_stale_client_battle_packet(from_steam_id: String, message: Dictionary) -> bool:
	if not _is_game_host():
		return false
	var msg_type = str(message.get("msg_type", ""))
	if not _is_client_to_host_battle_message_type(msg_type):
		return false
	if not _pending_host_game_start.empty() and str(_pending_host_game_start.get("start_kind", "")) == "retry_wave":
		return true
	if _host_retry_first_snapshot_needs_gate():
		return true
	var expected_start_id = int(_host_current_battle_start_id)
	if expected_start_id <= 0:
		return false
	var packet_start_id = _extract_battle_start_id(message)
	var now = OS.get_ticks_msec()
	if packet_start_id <= 0:
		if now < _host_battle_start_fence_until_msec:
			return true
		return false
	if packet_start_id != expected_start_id:
		return true
	var expected_context = str(_host_current_retry_context_key)
	var packet_context = str(message.get("battle_retry_context_key", ""))
	if expected_context != "" and packet_context != "" and packet_context != expected_context:
		return true
	return false


func _get_message_lobby_id(message: Dictionary) -> String:
	if message.has("session_lobby_id"):
		return str(message.get("session_lobby_id", ""))
	if message.has("lobby_id"):
		return str(message.get("lobby_id", ""))
	return ""


func _is_known_online_message_type(msg_type: String) -> bool:
	return msg_type == "hello" or msg_type == "request_selection_state" or msg_type == "menu_focus" or msg_type == "select_character" or msg_type == "select_weapon" or msg_type == "select_difficulty" or msg_type == "select_zone" or msg_type == "host_character_setup" or msg_type == "host_weapon_setup" or msg_type == "game_start_prepare" or msg_type == "game_start_time_ack" or msg_type == "client_game_scene_ready" or msg_type == "game_start_commit" or msg_type == "retry_wave_confirm" or msg_type == "retry_wave_decline" or msg_type == "retry_wave_state" or msg_type == "retry_wave_end" or msg_type == "menu_scene_state" or msg_type == "run_page_action_sync" or msg_type == "quick_chat" or msg_type == "battle_reliable_events" or msg_type == "battle_snapshot" or msg_type == "battle_terminal_state" or msg_type == "selection_state" or msg_type == "battle_input" or msg_type == "damage_claim_batch" or msg_type == "player_hp_state" or msg_type == "player_state" or msg_type == "entity_kill_claim" or msg_type == "boss_damage_report" or msg_type == "pickup_claim" or msg_type == "battle_entity_resync_request" or msg_type == "upgrade_direct_action" or msg_type == "bo_mod_message"


func _is_host_authoritative_message_type(msg_type: String) -> bool:
	return msg_type == "host_character_setup" or msg_type == "host_weapon_setup" or msg_type == "game_start_prepare" or msg_type == "game_start_commit" or msg_type == "retry_wave_state" or msg_type == "retry_wave_end" or msg_type == "menu_scene_state" or msg_type == "run_page_action_sync" or msg_type == "quick_chat" or msg_type == "battle_reliable_events" or msg_type == "battle_snapshot" or msg_type == "battle_terminal_state" or msg_type == "selection_state" or msg_type == "upgrade_direct_action"


func _should_drop_p2p_message_for_session(from_steam_id: String, message: Dictionary) -> bool:
	var msg_type = str(message.get("msg_type", ""))
	if not _is_known_online_message_type(msg_type):
		return false

	if _lobby_id == 0:
		return true

	var message_lobby_id = _get_message_lobby_id(message)
	if message_lobby_id == "":
		return true
	if message_lobby_id != str(_lobby_id):
		return true

	# Client hello is sent only after Steam reports lobby_joined. The helper also
	# queries Steam directly when the cached member list has not received its chat
	# update yet, so normal joins are not rejected by a cache race.
	if _is_game_host() and not _is_current_lobby_remote_member(from_steam_id):
		return true

	if not _is_game_host() and _is_host_authoritative_message_type(msg_type):
		var host_id = _get_game_host_steam_id()
		if host_id != "" and from_steam_id != host_id:
			return true

	return false


func _close_tracked_p2p_sessions() -> void:
	if _steam == null or not _steam_has_method("closeSessionWithUser"):
		return
	var ids = []
	for id_value in _accepted_p2p_sessions.keys():
		_append_unique_string(ids, id_value)
	for id_value in _host_known_remote_ids:
		_append_unique_string(ids, id_value)
	for member in _members:
		if typeof(member) == TYPE_DICTIONARY:
			_append_unique_string(ids, member.get("steam_id", ""))
	_append_unique_string(ids, _game_host_steam_id)
	for steam_id in ids:
		if steam_id == "" or steam_id == "0" or steam_id == _self_steam_id:
			continue
		var ok = _steam.closeSessionWithUser(int(steam_id))


func _drain_stale_p2p_packets() -> void:
	if _steam == null or not _steam_ready:
		return
	if not _steam_has_method("receiveMessagesOnChannel"):
		return
	for channel in [P2P_CHANNEL_MENU, P2P_CHANNEL_BATTLE]:
		var _dropped = _receive_steam_messages_on_channel(channel, 128)


func _append_unique_string(array: Array, value) -> void:
	var normalized = str(value)
	if normalized == "" or array.has(normalized):
		return
	array.append(normalized)


func bo_api_is_online() -> bool:
	return _has_active_online_session()


func bo_api_is_host() -> bool:
	return _has_active_online_session() and _is_game_host()


func bo_api_is_client() -> bool:
	return _has_active_online_session() and not _is_game_host()


func bo_api_get_self_steam_id() -> String:
	_update_self_steam_id()
	return _self_steam_id


func bo_api_get_host_steam_id() -> String:
	return _get_game_host_steam_id()


func bo_api_get_battle_id() -> int:
	if _is_game_host():
		return int(_host_current_battle_start_id)
	if int(_client_active_battle_start_id) > 0:
		return int(_client_active_battle_start_id)
	if int(_client_expected_battle_start_id) > 0:
		return int(_client_expected_battle_start_id)
	return 0


func bo_api_get_remote_member_steam_ids() -> Array:
	var result = []
	for member in _members:
		if typeof(member) != TYPE_DICTIONARY:
			continue
		var steam_id = str(member.get("steam_id", ""))
		if steam_id == "" or steam_id == "0" or steam_id == _self_steam_id:
			continue
		if not result.has(steam_id):
			result.append(steam_id)
	for steam_id_value in _host_known_remote_ids:
		var known_id = str(steam_id_value)
		if known_id == "" or known_id == "0" or known_id == _self_steam_id:
			continue
		if not result.has(known_id):
			result.append(known_id)
	return result


func bo_api_get_player_index_for_steam_id(steam_id: String) -> int:
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("get_player_index_for_steam_id"):
		return int(slot_manager.get_player_index_for_steam_id(steam_id))
	return -1


func bo_api_send_to_steam_id(target_steam_id: String, message: Dictionary, reliable: bool = true) -> bool:
	if typeof(message) != TYPE_DICTIONARY:
		return false
	if str(message.get("msg_type", "")) != "bo_mod_message":
		return false
	return _send_p2p_json(target_steam_id, message, reliable)

func send_menu_message_to_host(message: Dictionary) -> void:
	if _lobby_id == 0:
		return

	if _is_game_host():
		return

	var owner_id = _get_game_host_steam_id()
	if owner_id == "":
		return

	_send_p2p_json(owner_id, message, true)


func send_battle_message_to_host(message: Dictionary, reliable: bool = true) -> bool:
	if _lobby_id == 0:
		return false
	if _is_game_host():
		return false
	var msg_type = str(message.get("msg_type", ""))
	if _is_client_to_host_battle_message_type(msg_type) and int(_client_expected_battle_start_id) > 0 and int(_client_active_battle_start_id) != int(_client_expected_battle_start_id):
		var now = OS.get_ticks_msec()
		if now < _client_battle_start_fence_until_msec:
			return false
		_activate_client_battle_generation_for_send(_client_expected_battle_start_id, _client_expected_battle_start_kind, _client_expected_retry_context_key, "send_fence_expired")
	var owner_id = _get_game_host_steam_id()
	if owner_id == "":
		return false
	return _send_p2p_json(owner_id, message, reliable)



func send_or_broadcast_quick_chat(message: Dictionary) -> bool:
	if _lobby_id == 0:
		return false
	var wire = message.duplicate(true)
	wire["msg_type"] = "quick_chat"
	if not wire.has("origin_steam_id") or str(wire.get("origin_steam_id", "")) == "":
		wire["origin_steam_id"] = _self_steam_id
	if _is_game_host():
		_broadcast_quick_chat(wire, "")
		return true
	return _send_p2p_json(_get_game_host_steam_id(), wire, true)


func _broadcast_quick_chat(message: Dictionary, except_steam_id: String = "") -> void:
	if not _is_game_host() or _lobby_id == 0:
		return
	for member in _members:
		if typeof(member) != TYPE_DICTIONARY:
			continue
		var steam_id = str(member.get("steam_id", ""))
		if steam_id == "" or steam_id == _self_steam_id:
			continue
		if except_steam_id != "" and steam_id == except_steam_id:
			continue
		_send_p2p_json(steam_id, message, true)


func _handle_quick_chat_message(from_steam_id: String, message: Dictionary) -> void:
	var quick_chat = _get_quick_chat_manager()
	if _is_game_host():
		var relayed = message.duplicate(true)
		relayed["msg_type"] = "quick_chat"
		if not relayed.has("origin_steam_id") or str(relayed.get("origin_steam_id", "")) == "":
			relayed["origin_steam_id"] = from_steam_id
		if quick_chat != null and quick_chat.has_method("receive_remote_quick_chat"):
			quick_chat.receive_remote_quick_chat(relayed)
		_broadcast_quick_chat(relayed, from_steam_id)
		return
	if quick_chat != null and quick_chat.has_method("receive_remote_quick_chat"):
		quick_chat.receive_remote_quick_chat(message)


func _build_client_content_capability_for_hello() -> Dictionary:
	var menu_sync = _get_menu_sync_manager()
	if menu_sync != null and menu_sync.has_method("build_local_client_content_capability_for_hello"):
		return menu_sync.build_local_client_content_capability_for_hello()
	return {}


func _send_client_hello_to_host() -> void:
	if _lobby_id == 0 or _is_game_host():
		return

	var owner_id = _get_game_host_steam_id()
	if owner_id == "":
		return

	_send_p2p_json(owner_id, {
		"msg_type": "hello",
		"role": "client",
		"steam_id": _self_steam_id,
		"mod": "six666-BrotatoOnline",
		"mod_version": MOD_VERSION,
		"content_capability": _build_client_content_capability_for_hello()
	}, true)


func _stop_client_hello_retry(reason: String = "") -> void:
	if _client_hello_retry_until_msec == 0:
		return
	_client_hello_retry_until_msec = 0
	_last_client_hello_retry_msec = 0


func _poll_client_hello_retry() -> void:
	if _lobby_id == 0 or _is_game_host():
		return
	var now = OS.get_ticks_msec()
	if _client_hello_retry_until_msec == 0 or now > _client_hello_retry_until_msec:
		return
	if now - _last_client_hello_retry_msec < CLIENT_HELLO_RETRY_INTERVAL_MSEC:
		return
	_last_client_hello_retry_msec = now
	_send_client_hello_to_host()

func _poll_p2p_packets() -> void:
	if _steam == null or not _steam_ready:
		return

	if not _steam_has_method("receiveMessagesOnChannel"):
		return

	_poll_p2p_channel(P2P_CHANNEL_MENU, P2P_POLL_LIMIT_PER_FRAME)
	_poll_p2p_channel(P2P_CHANNEL_BATTLE, P2P_BATTLE_POLL_LIMIT_PER_FRAME)
	# The browser node owns channel 2 while searching from the title screen. A
	# public host polls it here only to answer pre-join latency probes.
	if _lobby_id != 0 and _is_game_host() and _get_public_lobby_enabled() and (_is_host_at_character_selection_for_lobby() or _is_in_official_coop_resume_scene()):
		_poll_p2p_channel(P2P_CHANNEL_LOBBY_BROWSER, P2P_POLL_LIMIT_PER_FRAME)


func _poll_p2p_channel(channel: int, limit: int) -> void:
	var prefix = "p2p_menu"
	if channel == P2P_CHANNEL_BATTLE:
		prefix = "p2p_battle"
	elif channel == P2P_CHANNEL_LOBBY_BROWSER:
		prefix = "p2p_browser"
	var t_receive = OS.get_ticks_usec()
	var messages = _receive_steam_messages_on_channel(channel, limit)
	_bo_net_diag_cost(prefix + "_receive", t_receive, "count=" + str(messages.size()) + " limit=" + str(limit))
	if messages.empty():
		return
	var total_bytes = 0
	var t_handle = OS.get_ticks_usec()
	for packet in messages:
		var packet_size = _extract_packet_bytes(packet).size() if typeof(packet) == TYPE_DICTIONARY else 0
		total_bytes += packet_size
		_handle_raw_p2p_packet(packet)
	_bo_net_diag_cost(prefix + "_handle_batch", t_handle, "count=" + str(messages.size()) + " bytes=" + str(total_bytes) + " limit=" + str(limit))
	if messages.size() >= limit or total_bytes >= BO_NET_DIAG_LARGE_BATCH_BYTES:
		var key = prefix + ":" + str(messages.size()) + ":" + str(total_bytes)
		_bo_net_diag_state_change("POLL_BACKLOG", key, "channel=" + str(channel) + " count=" + str(messages.size()) + " limit=" + str(limit) + " bytes=" + str(total_bytes), 1000)


func _receive_steam_messages_on_channel(channel: int, limit: int) -> Array:
	var result = _steam.receiveMessagesOnChannel(channel, limit)
	if typeof(result) == TYPE_ARRAY:
		return result
	if typeof(result) == TYPE_DICTIONARY:
		if result.has("messages") and typeof(result["messages"]) == TYPE_ARRAY:
			return result["messages"]
		if result.has("data") and typeof(result["data"]) == TYPE_ARRAY:
			return result["data"]
		if result.has("message") or result.has("payload") or result.has("bytes"):
			return [result]
	return []


func _handle_raw_p2p_packet(packet) -> void:
	if typeof(packet) != TYPE_DICTIONARY:
		return

	var packet_start_usec = OS.get_ticks_usec()
	var from_steam_id = _extract_packet_sender(packet)
	var bytes = _extract_packet_bytes(packet)
	if from_steam_id == "" or bytes.size() == 0:
		return

	var t_parse = OS.get_ticks_usec()
	var text = bytes.get_string_from_utf8()
	var parsed = parse_json(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var msg_type = str(parsed.get("msg_type", ""))
	_bo_net_diag_cost("packet_parse:" + msg_type, t_parse, "bytes=" + str(bytes.size()) + " from=" + from_steam_id)
	if msg_type == "p2p_json_chunk":
		var chunk_type = str(parsed.get("final_msg_type", ""))
		var chunk_count = int(parsed.get("chunk_count", 0))
		var original_bytes = int(parsed.get("original_bytes", 0))
		parsed = _receive_p2p_json_chunk(from_steam_id, parsed)
		if typeof(parsed) != TYPE_DICTIONARY or parsed.empty():
			if chunk_count > 0 and original_bytes >= BO_NET_DIAG_LARGE_PACKET_BYTES:
				_bo_net_diag_state_change("RX_CHUNK", from_steam_id + ":" + chunk_type + ":" + str(chunk_count) + ":" + str(original_bytes), "from=" + from_steam_id + " final_type=" + chunk_type + " chunks=" + str(chunk_count) + " original_bytes=" + str(original_bytes), 1000)
			return
		msg_type = str(parsed.get("msg_type", ""))
	# Browser probes are intentionally sent before joining a lobby, so they must
	# bypass the online-session generation/member filters used by game traffic.
	if msg_type == "lobby_ping_request":
		_handle_lobby_browser_ping_request(from_steam_id, parsed)
		_bo_net_diag_cost("packet_total:" + msg_type, packet_start_usec, "bytes=" + str(bytes.size()) + " from=" + from_steam_id)
		return
	if _should_drop_p2p_message_for_session(from_steam_id, parsed):
		return
	var t_handle = OS.get_ticks_usec()
	_handle_p2p_message(from_steam_id, parsed)
	_bo_net_diag_cost("packet_handle:" + msg_type, t_handle, "bytes=" + str(bytes.size()) + " from=" + from_steam_id + " " + _bo_net_diag_message_summary(parsed))
	_bo_net_diag_cost("packet_total:" + msg_type, packet_start_usec, "bytes=" + str(bytes.size()) + " from=" + from_steam_id + " " + _bo_net_diag_message_summary(parsed))


func _handle_lobby_browser_ping_request(from_steam_id: String, message: Dictionary) -> void:
	if _steam == null or _lobby_id == 0 or not _is_game_host() or not _get_public_lobby_enabled():
		return
	if from_steam_id == "" or from_steam_id == "0" or from_steam_id == _self_steam_id:
		return
	if int(str(message.get("lobby_id", "0"))) != int(_lobby_id):
		return
	var nonce = str(message.get("nonce", ""))
	if nonce == "" or nonce.length() > 160:
		return

	var now = OS.get_ticks_msec()
	var last_reply = int(_browser_ping_last_reply_msec_by_steam_id.get(from_steam_id, 0))
	if now - last_reply < BROWSER_PING_REPLY_MIN_INTERVAL_MSEC:
		return
	_browser_ping_last_reply_msec_by_steam_id[from_steam_id] = now

	if not _steam_has_method("sendMessageToUser"):
		return
	_prepare_steam_messages_session_with_peer(from_steam_id, "lobby_browser_ping")
	var response = {
		"msg_type": "lobby_ping_response",
		"lobby_id": str(_lobby_id),
		"nonce": nonce
	}
	var payload = to_json(response).to_utf8()
	var _result = _steam.sendMessageToUser(int(from_steam_id), payload, 0, P2P_CHANNEL_LOBBY_BROWSER)


func _extract_packet_sender(packet: Dictionary) -> String:
	var keys = ["remote_steam_id", "steam_id_remote", "steamIDRemote", "steam_id", "sender", "remote_id", "remote"]
	for key in keys:
		if packet.has(key):
			return _extract_steam_id_value(packet[key])
	var identity_keys = ["identity", "identity_remote", "remote_identity", "networking_identity"]
	for key in identity_keys:
		if packet.has(key):
			var steam_id = _extract_steam_id_value(packet[key])
			if steam_id != "":
				return steam_id
	return ""


func _extract_steam_id_value(value) -> String:
	if typeof(value) == TYPE_NIL:
		return ""
	if typeof(value) == TYPE_DICTIONARY:
		for key in ["steam_id", "steamID", "steamID64", "id", "remote_steam_id"]:
			if value.has(key):
				return str(value[key])
		return ""
	return str(value)


func _extract_packet_bytes(packet: Dictionary) -> PoolByteArray:
	var keys = ["data", "payload", "bytes", "message", "body"]
	for key in keys:
		if packet.has(key):
			var value = packet[key]
			if typeof(value) == TYPE_RAW_ARRAY:
				return value
			if typeof(value) == TYPE_ARRAY:
				var arr = PoolByteArray()
				for b in value:
					arr.append(int(b))
				return arr
			if typeof(value) == TYPE_STRING:
				return str(value).to_utf8()
	return PoolByteArray()


func _mark_full_item_list_scene_sync_required(steam_id: String, reason: String) -> void:
	if steam_id == "" or steam_id == "0" or steam_id == _self_steam_id:
		return
	# A fresh/rejoined client has no reliable local held-item baseline for endless 21+.
	# Keep this per-client latch until its next authoritative scene/game-start payload
	# carries a compact full item list.
	_full_item_list_scene_sync_required_by_steam_id[steam_id] = str(reason) + ":" + str(OS.get_ticks_msec())


func _should_force_full_item_list_for_scene_sync_to_client(steam_id: String) -> bool:
	if steam_id == "" or steam_id == "0" or steam_id == _self_steam_id:
		return false
	if _full_item_list_scene_sync_required_by_steam_id.has(steam_id):
		return true
	# While the official Continue gate is still visible, be conservative: the client is
	# bootstrapping a saved run rather than advancing from the previous online shop.
	return _is_in_official_coop_resume_scene()


func should_force_full_item_list_for_next_scene_sync() -> bool:
	# Public query used by MenuSync when building shop->battle run_config. If any client
	# still needs a baseline, send the full compact item list to everyone in that start
	# packet; it is cheaper and safer than per-client divergent game_start_commit payloads.
	return not _full_item_list_scene_sync_required_by_steam_id.empty() or _is_in_official_coop_resume_scene()


func _clear_full_item_list_scene_sync_requirement_for_client(steam_id: String) -> void:
	if steam_id == "" or steam_id == "0":
		return
	_full_item_list_scene_sync_required_by_steam_id.erase(steam_id)


func _handle_client_selection_state_request(from_steam_id: String, message: Dictionary) -> void:
	if not _is_game_host() or _lobby_id == 0:
		return

	_ensure_host_coop_slot_for_remote(from_steam_id)

	var now = OS.get_ticks_msec()
	var last_reply = int(_last_selection_request_reply_msec_by_steam_id.get(from_steam_id, 0))
	if last_reply > 0 and now - last_reply < HOST_SELECTION_REQUEST_REPLY_MIN_INTERVAL_MSEC:
		return
	_last_selection_request_reply_msec_by_steam_id[from_steam_id] = now

	# request_selection_state is a lightweight resync request. Do not force a full
	# host_character_setup / host_weapon_setup here; those packets include the
	# full Host catalog and are expensive to rebuild and send. A forced resend here
	# can create a feedback loop because older clients request state immediately
	# after receiving host_*_setup. Only allow a de-duplicated setup resend at a
	# low frequency for recovery from genuinely missing catalog/setup state.
	var reason = str(message.get("reason", ""))
	var should_consider_setup = reason != "after_host_character_setup" and reason != "after_host_weapon_setup"
	if should_consider_setup:
		var last_setup = int(_last_selection_request_setup_msec_by_steam_id.get(from_steam_id, 0))
		if last_setup <= 0 or now - last_setup >= HOST_SELECTION_REQUEST_SETUP_MIN_INTERVAL_MSEC:
			_last_selection_request_setup_msec_by_steam_id[from_steam_id] = now
			_send_host_phase_setup_to_client(from_steam_id, false)

	_send_selection_state_to_client(from_steam_id, true)

func _get_host_setup_dedup_key(message: Dictionary) -> String:
	var stable = message.duplicate(true)
	# selection_state is applied by a separate lightweight packet and should not
	# make setup packets unique. Setup is only scene/layout/catalog/run_config.
	stable.erase("selection_state")
	stable.erase("sent_msec")
	stable.erase("timestamp")
	return to_json(stable)


func _host_setup_has_valid_local_slot(message: Dictionary) -> bool:
	if _is_game_host():
		return false
	var target_client_steam_id = str(message.get("target_client_steam_id", message.get("client_steam_id", _self_steam_id)))
	if target_client_steam_id == "":
		target_client_steam_id = _self_steam_id
	if _self_steam_id != "" and target_client_steam_id != "" and target_client_steam_id != _self_steam_id:
		return false

	var players = message.get("players", [])
	if typeof(players) != TYPE_ARRAY or players.empty():
		return false
	var target_client_player_index = int(message.get("target_client_player_index", message.get("client_player_index", -1)))
	var matched = 0
	for player_data in players:
		if typeof(player_data) != TYPE_DICTIONARY:
			continue
		var player_index = int(player_data.get("player_index", -1))
		var steam_id = str(player_data.get("steam_id", ""))
		if _self_steam_id != "" and steam_id == _self_steam_id:
			matched += 1
		elif steam_id == "" and target_client_player_index >= 0 and player_index == target_client_player_index:
			matched += 1
	return matched == 1


func _should_ignore_duplicate_host_setup(from_steam_id: String, msg_type: String, message: Dictionary) -> bool:
	if _is_game_host():
		return false
	var sender = str(from_steam_id)
	if sender == "":
		return false
	var slot_key = sender + "|" + msg_type
	var setup_key = _get_host_setup_dedup_key(message)
	var now = OS.get_ticks_msec()
	var last_key = str(_client_seen_host_setup_key_by_sender.get(slot_key, ""))
	var last_msec = int(_client_seen_host_setup_msec_by_sender.get(slot_key, 0))
	if last_key == setup_key and last_msec > 0 and now - last_msec < CLIENT_SETUP_DUPLICATE_SUPPRESS_MSEC:
		return true
	_client_seen_host_setup_key_by_sender[slot_key] = setup_key
	_client_seen_host_setup_msec_by_sender[slot_key] = now
	return false


func _handle_p2p_message(from_steam_id: String, message: Dictionary) -> void:
	var msg_type = str(message.get("msg_type", ""))

	# Safety fallback: some SteamNetworkingMessages receive paths may dispatch directly
	# into _handle_p2p_message without passing through _handle_raw_p2p_packet's
	# chunk reassembly gate. Never let p2p_json_chunk fall through to the
	# unknown-message logger, because payload_b64 can be tens of KB per line and
	# the real final message will never be applied.
	if msg_type == "p2p_json_chunk":
		var reassembled = _receive_p2p_json_chunk(from_steam_id, message)
		if typeof(reassembled) != TYPE_DICTIONARY or reassembled.empty():
			return
		if _should_drop_p2p_message_for_session(from_steam_id, reassembled):
			return
		_handle_p2p_message(from_steam_id, reassembled)
		return

	if msg_type == "bo_mod_message":
		var api = _get_brotato_online_api()
		if api != null and api.has_method("receive_mod_message"):
			api.receive_mod_message(from_steam_id, message)
		return

	if _should_drop_stale_client_battle_packet(from_steam_id, message):
		return

	if msg_type == "hello":
		var first_hello = not _seen_client_hello_by_steam_id.has(from_steam_id)
		_seen_client_hello_by_steam_id[from_steam_id] = true
		var client_content_changed = false
		var menu_sync_for_capability = _get_menu_sync_manager()
		if _is_game_host() and menu_sync_for_capability != null and menu_sync_for_capability.has_method("receive_client_content_capability_from_hello"):
			client_content_changed = bool(menu_sync_for_capability.receive_client_content_capability_from_hello(from_steam_id, message))
		if first_hello or _is_in_official_coop_resume_scene() or _is_in_game_scene() or _is_in_shop_scene():
			_mark_full_item_list_scene_sync_required(from_steam_id, "hello")
		if first_hello:
			var cap_for_log = message.get("content_capability", {})
			var cap_count_for_log = 0
			if typeof(cap_for_log) == TYPE_DICTIONARY:
				cap_count_for_log = int(cap_for_log.get("character_count", 0))
		if _is_game_host():
			_ensure_host_coop_slot_for_remote(from_steam_id)
			if first_hello and not _should_freeze_online_run_slots():
				_refresh_lobby_members()
				_schedule_prime_and_broadcast_after_remote_join()
			if client_content_changed:
				_sent_character_setup_key_by_steam_id.clear()
				_last_broadcast_selection_key = ""
				if menu_sync_for_capability != null and menu_sync_for_capability.has_method("apply_host_dlc_gate_now"):
					menu_sync_for_capability.apply_host_dlc_gate_now()
			_send_host_phase_setup_to_client(from_steam_id, first_hello or client_content_changed)
			_send_selection_state_to_client(from_steam_id, first_hello or client_content_changed)
			if client_content_changed:
				_send_host_phase_messages_to_all(true, from_steam_id)
				_broadcast_selection_state(true)
		return

	if msg_type == "request_selection_state":
		if _is_game_host():
			_handle_client_selection_state_request(from_steam_id, message)
		return

	if msg_type == "menu_focus" or msg_type == "select_character" or msg_type == "select_weapon" or msg_type == "select_difficulty" or msg_type == "select_zone":
		if not _is_game_host():
			return

		_ensure_host_coop_slot_for_remote(from_steam_id)

		var menu_sync = _get_menu_sync_manager()
		if menu_sync == null or not menu_sync.has_method("receive_menu_message"):
			return

		menu_sync.receive_menu_message(from_steam_id, message)
		if msg_type == "menu_focus":
			# Focus changes can arrive every 50 ms. Do not immediately fan out a full
			# four-player selection_state for every intermediate tile. The normal
			# 250 ms selection poll broadcasts the latest authoritative focus, matching
			# Host-local focus cadence and preventing reliable-packet/UI refresh storms.
			return
		_send_host_phase_messages_to_all(false)
		_broadcast_selection_state(true)
		return

	if msg_type == "host_character_setup":
		if _is_game_host():
			return
		_stop_client_hello_retry("host_character_setup")
		# Do not unlock a valid battle/shop mirror for an incomplete or misdirected
		# setup packet. The next valid targeted setup/selection_state can recover it.
		if not _host_setup_has_valid_local_slot(message):
			return
		if _should_ignore_duplicate_host_setup(from_steam_id, msg_type, message):
			return
		# A fresh character setup means Host has returned to mutable staging. Clear the
		# previous battle/shop lock before MenuSync asks OnlinePlayerSlotManager to
		# rebuild the mirrored local/remote slot layout.
		_unlock_online_run_slots()
		_sync_slot_manager_lock_flag()
		_apply_host_zone_sync_for_client(message, "host_character_setup")
		var menu_sync_setup = _get_menu_sync_manager()
		if menu_sync_setup != null and menu_sync_setup.has_method("receive_host_character_setup_from_host"):
			_online_flow_started = true
			_online_flow_left_since_msec = 0
			menu_sync_setup.receive_host_character_setup_from_host(message, _self_steam_id, _get_game_host_steam_id())
		return

	if msg_type == "host_weapon_setup":
		if _is_game_host():
			return
		_stop_client_hello_retry("host_weapon_setup")
		if not _host_setup_has_valid_local_slot(message):
			return
		if _should_ignore_duplicate_host_setup(from_steam_id, msg_type, message):
			return
		_unlock_online_run_slots()
		_sync_slot_manager_lock_flag()
		_apply_host_zone_sync_for_client(message, "host_weapon_setup")
		var menu_sync_weapon_setup = _get_menu_sync_manager()
		if menu_sync_weapon_setup != null and menu_sync_weapon_setup.has_method("receive_host_weapon_setup_from_host"):
			_online_flow_started = true
			_online_flow_left_since_msec = 0
			menu_sync_weapon_setup.receive_host_weapon_setup_from_host(message, _self_steam_id, _get_game_host_steam_id())
		return

	if msg_type == "game_start_prepare":
		if _is_game_host():
			return
		_handle_game_start_prepare_from_host(message)
		return

	if msg_type == "game_start_time_ack":
		if _is_game_host():
			_handle_game_start_time_ack(from_steam_id, message)
		return

	if msg_type == "client_game_scene_ready":
		if _is_game_host():
			_handle_client_game_scene_ready(from_steam_id, message)
		return

	if msg_type == "game_start_commit":
		if _is_game_host():
			return
		_handle_game_start_commit_from_host(message)
		return

	if msg_type == "retry_wave_confirm":
		if _is_game_host():
			_handle_retry_wave_confirm_from_client(from_steam_id, message)
		return

	if msg_type == "retry_wave_decline":
		if _is_game_host():
			_handle_retry_wave_decline_from_client(from_steam_id, message)
		return

	if msg_type == "retry_wave_state":
		if not _is_game_host():
			_handle_retry_wave_state_from_host(message)
		return

	if msg_type == "retry_wave_end":
		if not _is_game_host():
			_handle_retry_wave_end_from_host(message)
		return

	if msg_type == "menu_scene_state":
		if _is_game_host():
			return
		if _client_should_drop_stale_menu_scene_state(message):
			return
		_stop_client_hello_retry("menu_scene_state")
		_apply_host_zone_sync_for_client(message, "menu_scene_state")
		var menu_sync_scene_client = _get_menu_sync_manager()
		if menu_sync_scene_client != null and menu_sync_scene_client.has_method("receive_menu_scene_state_from_host"):
			var screen = str(message.get("screen", ""))
			if screen != "" and screen != "none":
				_online_flow_started = true
				_online_flow_left_since_msec = 0
			# Apply Host slot_layout before locking the slot manager. Official Continue
			# clients join directly into shop flow and have not seen character/weapon
			# selection_state, so their local player index must be mirrored here.
			menu_sync_scene_client.receive_menu_scene_state_from_host(message, _self_steam_id, _get_game_host_steam_id())
			if screen == "game" or screen.find("shop") != -1:
				_lock_online_run_slots("client_scene_state:" + screen)
			# game_start_commit is the preferred path. A direct screen=game scene-state is kept as a fallback
			# for older hosts or duplicate broadcasts after the Host has already entered battle.
		return

	if msg_type == "upgrade_direct_action":
		_handle_upgrade_direct_action(from_steam_id, message)
		return

	if msg_type == "run_page_action_sync":
		if _client_should_drop_stale_run_page_action(message):
			return
		_handle_run_page_action_sync(from_steam_id, message)
		return

	if msg_type == "quick_chat":
		_handle_quick_chat_message(from_steam_id, message)
		return

	if msg_type == "battle_reliable_events":
		if _is_game_host():
			return
		if _should_drop_stale_retry_battle_packet(message):
			return
		_stop_client_hello_retry("battle_reliable_events")
		_handle_battle_reliable_events_from_host(message)
		return

	if msg_type == "battle_terminal_state":
		if _is_game_host():
			return
		if _should_drop_stale_retry_battle_packet(message):
			return
		_stop_client_hello_retry("battle_terminal_state")
		_handle_battle_terminal_state_from_host(message)
		return

	if msg_type == "battle_snapshot":
		if _is_game_host():
			return
		if _should_drop_stale_retry_battle_packet(message):
			return
		_stop_client_hello_retry("battle_snapshot")
		_handle_battle_snapshot_from_host(message)
		return

	if msg_type == "selection_state":
		var menu_sync_client = _get_menu_sync_manager()
		if not _is_game_host():
			_apply_host_zone_sync_for_client(message, "selection_state")
			var state_screen = str(message.get("screen", ""))
			if (state_screen == "character_selection" or state_screen == "weapon_selection") and menu_sync_client != null and menu_sync_client.has_method("has_host_catalog_for_screen") and not menu_sync_client.has_host_catalog_for_screen(state_screen):
				_send_client_hello_to_host()
				return
			_stop_client_hello_retry("selection_state")
		if menu_sync_client != null and menu_sync_client.has_method("receive_selection_state_from_host"):
			menu_sync_client.receive_selection_state_from_host(message, _self_steam_id, _get_game_host_steam_id())
		return

	if msg_type == "battle_input":
		if not _is_game_host():
			return

		_ensure_host_coop_slot_for_remote(from_steam_id)

		var input_manager = _get_online_input_manager()
		if input_manager == null or not input_manager.has_method("receive_battle_input"):
			return

		input_manager.receive_battle_input(from_steam_id, message)
		return

	if msg_type == "damage_claim_batch":
		if not _is_game_host():
			return
		_ensure_host_coop_slot_for_remote(from_steam_id)
		var snapshot_manager = _get_state_snapshot_manager()
		if snapshot_manager != null and snapshot_manager.has_method("apply_damage_claim_batch"):
			snapshot_manager.apply_damage_claim_batch(from_steam_id, message)
		else:
			pass
		return

	if msg_type == "player_hp_state":
		if not _is_game_host():
			return
		_ensure_host_coop_slot_for_remote(from_steam_id)
		var snapshot_manager_hp = _get_state_snapshot_manager()
		if snapshot_manager_hp != null and snapshot_manager_hp.has_method("apply_player_hp_state"):
			snapshot_manager_hp.apply_player_hp_state(from_steam_id, message)
		return

	if msg_type == "player_state":
		if not _is_game_host():
			return
		_ensure_host_coop_slot_for_remote(from_steam_id)
		var snapshot_manager_ps = _get_state_snapshot_manager()
		if snapshot_manager_ps != null and snapshot_manager_ps.has_method("apply_player_state"):
			snapshot_manager_ps.apply_player_state(from_steam_id, message)
		return

	if msg_type == "entity_kill_claim":
		var claim_category = str(message.get("category", ""))
		if not ENABLE_DEATH_REPORT_MESSAGES and not (ENABLE_BOSS_ELITE_DEATH_REPORT_MESSAGES and (claim_category == "boss" or claim_category == "elite")):
			return
		if not _is_game_host():
			return
		_ensure_host_coop_slot_for_remote(from_steam_id)
		var snapshot_manager_kill = _get_state_snapshot_manager()
		if snapshot_manager_kill != null and snapshot_manager_kill.has_method("apply_entity_kill_claim"):
			snapshot_manager_kill.apply_entity_kill_claim(from_steam_id, message)
		return

	if msg_type == "boss_damage_report":
		if not (ENABLE_DEATH_REPORT_MESSAGES or ENABLE_BOSS_ONE_SHOT_REPORT_MESSAGES):
			return
		if not _is_game_host():
			return
		_ensure_host_coop_slot_for_remote(from_steam_id)
		var snapshot_manager_boss = _get_state_snapshot_manager()
		if snapshot_manager_boss != null and snapshot_manager_boss.has_method("apply_boss_damage_report"):
			snapshot_manager_boss.apply_boss_damage_report(from_steam_id, message)
		return

	if msg_type == "battle_entity_resync_request":
		if not _is_game_host():
			return
		_ensure_host_coop_slot_for_remote(from_steam_id)
		_handle_battle_entity_resync_request(from_steam_id, message)
		return

	if msg_type == "pickup_claim":
		if not _is_game_host():
			return
		_ensure_host_coop_slot_for_remote(from_steam_id)
		var snapshot_manager_pickup = _get_state_snapshot_manager()
		if snapshot_manager_pickup != null and snapshot_manager_pickup.has_method("apply_pickup_claim"):
			snapshot_manager_pickup.apply_pickup_claim(from_steam_id, message)
		return

	_print_unknown_p2p_message(from_steam_id, message)


func _handle_battle_entity_resync_request(from_steam_id: String, message: Dictionary) -> void:
	var snapshot_manager = _get_state_snapshot_manager()
	if snapshot_manager == null or not snapshot_manager.has_method("build_battle_entity_resync_payload"):
		return
	var net_ids = []
	var raw_ids = message.get("net_ids", [])
	if typeof(raw_ids) == TYPE_ARRAY:
		for value in raw_ids:
			var id = str(value)
			if id != "" and not net_ids.has(id):
				net_ids.append(id)
	var single_id = str(message.get("net_id", ""))
	if single_id != "" and not net_ids.has(single_id):
		net_ids.append(single_id)
	if net_ids.empty():
		return
	var pending_reliable = snapshot_manager.build_battle_entity_resync_payload(net_ids)
	if typeof(pending_reliable) != TYPE_DICTIONARY or pending_reliable.empty():
		return
	var snapshot = {}
	if snapshot_manager.has_method("get_last_snapshot_message"):
		snapshot = snapshot_manager.get_last_snapshot_message()
	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.empty():
		if snapshot_manager.has_method("force_fresh_snapshot_message"):
			snapshot = snapshot_manager.force_fresh_snapshot_message()
		elif snapshot_manager.has_method("build_snapshot"):
			snapshot = snapshot_manager.build_snapshot()
	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.empty():
		snapshot = {
			"phase": "B12_delayed_death_sync",
			"tick": 0,
			"scene_instance_id": _current_scene_instance_id(),
			"time_msec": OS.get_ticks_msec(),
			"server_time_msec": OS.get_ticks_msec(),
			"removed": [],
			"events": []
		}
	var reliable_msg = _make_battle_reliable_events_message(snapshot, pending_reliable)
	if _battle_reliable_events_empty(reliable_msg):
		return
	_send_p2p_json(from_steam_id, reliable_msg, true)


func _print_unknown_p2p_message(from_steam_id: String, message: Dictionary) -> void:
	pass


func _summarize_p2p_message_for_log(message: Dictionary) -> Dictionary:
	var summary = {}
	for key in message.keys():
		var value = message[key]
		if key == "payload_b64" or key == "chunk_data" or key == "payload" or key == "data":
			var value_len = str(value).length()
			summary[key] = "<omitted " + str(value_len) + " chars>"
		elif typeof(value) == TYPE_STRING:
			if value.length() > 512:
				summary[key] = value.substr(0, 256) + "...<omitted " + str(value.length()) + " chars>"
			else:
				summary[key] = value
		elif typeof(value) == TYPE_DICTIONARY:
			summary[key] = "<dict keys=" + str(value.size()) + ">"
		elif typeof(value) == TYPE_ARRAY:
			summary[key] = "<array size=" + str(value.size()) + ">"
		else:
			summary[key] = value
	return summary


func _reset_game_start_sync_state() -> void:
	_host_difficulty_intercept_selection_id = 0
	_pending_host_game_start = {}
	_host_game_start_ack_by_steam_id.clear()
	_host_game_start_ready_by_steam_id.clear()
	_host_game_start_ready_by_steam_id.clear()
	_pending_client_game_start_commit = {}
	_pending_client_game_start_apply_msec = 0
	_pending_client_game_start_deferred_commit = {}
	_pending_client_game_start_deferred_call_queued = false
	_client_game_start_prepare_msec = 0
	_host_current_battle_start_id = 0
	_host_current_battle_start_kind = ""
	_host_current_retry_context_key = ""
	_host_battle_start_fence_until_msec = 0
	_host_retry_terminal_suppress_until_msec = 0
	_host_retry_terminal_suppress_scene_id = 0
	_host_retry_battle_send_min_until_msec = 0
	_host_retry_battle_send_deadline_msec = 0
	_host_retry_battle_send_old_scene_id = 0
	_host_retry_battle_send_started_msec = 0
	_host_retry_battle_send_fresh_after_msec = 0
	_host_retry_battle_send_require_fresh_snapshot = false
	_host_retry_first_snapshot_pending_start_id = 0
	_host_retry_first_snapshot_accepted_start_id = 0
	_host_retry_battle_send_last_block_log_msec = 0
	_client_expected_battle_start_id = 0
	_client_expected_battle_start_kind = ""
	_client_expected_retry_context_key = ""
	_client_battle_start_fence_until_msec = 0
	_client_active_battle_start_id = 0
	_client_active_battle_start_kind = ""
	_client_active_retry_context_key = ""
	_pending_client_game_scene_ready_requires_new_scene = false
	_pending_client_game_scene_ready_old_scene_id = 0


func _clear_retry_wave_sync_state(reason: String = "") -> void:
	_retry_wave_ready_by_steam_id.clear()
	_retry_wave_ready_context_key = ""
	_retry_wave_local_waiting_context_key = ""
	_retry_wave_last_state_broadcast_msec = 0
	_retry_wave_starting_context_key = ""
	_retry_wave_last_started_context_key = ""
	_retry_wave_host_context_key = ""
	_retry_wave_ending_context_key = ""
	if reason != "":
		pass


func _clear_client_retry_wave_waiting_latch(reason: String = "") -> void:
	if _retry_wave_local_waiting_context_key == "":
		return
	_retry_wave_local_waiting_context_key = ""


func _should_drop_stale_retry_battle_packet(message: Dictionary) -> bool:
	if _is_game_host():
		return false
	var msg_type = str(message.get("msg_type", ""))
	var now = OS.get_ticks_msec()
	var expected_start_id = int(_client_expected_battle_start_id)
	var packet_start_id = _extract_battle_start_id(message)
	if expected_start_id > 0:
		if packet_start_id > 0 and packet_start_id != expected_start_id:
			return true
		if packet_start_id <= 0 and now < _client_battle_start_fence_until_msec:
			return true
		var expected_context = str(_client_expected_retry_context_key)
		var packet_context = str(message.get("battle_retry_context_key", ""))
		if expected_context != "" and packet_context != "" and packet_context != expected_context:
			return true
	return false


func _poll_retry_wave_intercept() -> void:
	if not _has_active_online_session() or not _is_in_game_scene():
		_retry_wave_intercept_scene_id = 0
		_retry_wave_intercept_node_id = 0
		_retry_wave_intercept_button_id = 0
		_retry_wave_intercept_cancel_button_id = 0
		_retry_wave_intercept_ok_button_id = 0
		return
	var retry_wave = _get_retry_wave_node()
	if not _is_live_node(retry_wave):
		_retry_wave_intercept_node_id = 0
		_retry_wave_intercept_button_id = 0
		_retry_wave_intercept_cancel_button_id = 0
		_retry_wave_intercept_ok_button_id = 0
		return

	var confirm_button = _get_retry_wave_confirm_button(retry_wave)
	var cancel_button = _get_retry_wave_cancel_button(retry_wave)
	var ok_button = _get_retry_wave_ok_button(retry_wave)
	var scene = get_tree().current_scene
	var scene_id = scene.get_instance_id() if _is_live_node(scene) else 0
	var retry_id = retry_wave.get_instance_id()
	var confirm_id = confirm_button.get_instance_id() if _is_live_node(confirm_button) else 0
	var cancel_id = cancel_button.get_instance_id() if _is_live_node(cancel_button) else 0
	var ok_id = ok_button.get_instance_id() if _is_live_node(ok_button) else 0
	var same_nodes = scene_id == _retry_wave_intercept_scene_id and retry_id == _retry_wave_intercept_node_id and confirm_id == _retry_wave_intercept_button_id and cancel_id == _retry_wave_intercept_cancel_button_id and ok_id == _retry_wave_intercept_ok_button_id

	if not same_nodes:
		_retry_wave_intercept_scene_id = scene_id
		_retry_wave_intercept_node_id = retry_id
		_retry_wave_intercept_button_id = confirm_id
		_retry_wave_intercept_cancel_button_id = cancel_id
		_retry_wave_intercept_ok_button_id = ok_id
		if _is_live_node(confirm_button):
			if confirm_button.is_connected("pressed", retry_wave, "_on_ConfirmButton_pressed"):
				confirm_button.disconnect("pressed", retry_wave, "_on_ConfirmButton_pressed")
			if not confirm_button.is_connected("pressed", self, "_on_online_retry_wave_confirm_pressed"):
				confirm_button.connect("pressed", self, "_on_online_retry_wave_confirm_pressed")
		if _is_live_node(cancel_button):
			if cancel_button.is_connected("pressed", retry_wave, "_on_CancelButton_pressed"):
				cancel_button.disconnect("pressed", retry_wave, "_on_CancelButton_pressed")
			if not cancel_button.is_connected("pressed", self, "_on_online_retry_wave_cancel_pressed"):
				cancel_button.connect("pressed", self, "_on_online_retry_wave_cancel_pressed")
		if _is_live_node(ok_button):
			if ok_button.is_connected("pressed", retry_wave, "_on_CancelButton_pressed"):
				ok_button.disconnect("pressed", retry_wave, "_on_CancelButton_pressed")
			if not ok_button.is_connected("pressed", self, "_on_online_retry_wave_cancel_pressed"):
				ok_button.connect("pressed", self, "_on_online_retry_wave_cancel_pressed")

	_apply_retry_wave_policy_to_visible_node(retry_wave, bool(ProgressData.settings.retry_wave))
	_poll_retry_wave_waiting_visual(retry_wave)


func _on_online_retry_wave_confirm_pressed() -> void:
	var retry_wave = _get_retry_wave_node()
	if not _is_live_node(retry_wave):
		return
	if not _has_active_online_session():
		_call_vanilla_retry_wave_confirm(retry_wave)
		return
	if not _is_retry_wave_visible(retry_wave):
		return
	var local_context_key = _get_retry_wave_network_context_key()
	if local_context_key == "":
		return
	var context_key = local_context_key
	if not _is_game_host():
		context_key = _get_retry_wave_best_client_context_key(local_context_key)
	if _is_game_host():
		_mark_retry_wave_ready(_get_retry_wave_self_id(), context_key, "host_local")
		_update_retry_wave_waiting_visual(retry_wave, true, _get_retry_wave_ready_count(), _get_retry_wave_expected_ids().size())
		_broadcast_retry_wave_state(true)
		_try_start_retry_wave_if_all_ready()
		return
	_retry_wave_local_waiting_context_key = context_key
	_set_retry_wave_confirm_locked(retry_wave, true)
	_update_retry_wave_waiting_visual(retry_wave, true, 1, max(1, RunData.get_player_count()))
	var context_wave = _get_retry_wave_context_wave(context_key)
	var context_retries = _get_retry_wave_context_retries(context_key)
	var msg = {
		"msg_type": "retry_wave_confirm",
		"context_key": context_key,
		"local_context_key": local_context_key,
		"current_wave": context_wave if context_wave != -999999 else int(RunData.current_wave),
		"retries": context_retries if context_retries != -999999 else int(RunData.retries),
		"client_msec": OS.get_ticks_msec()
	}
	send_menu_message_to_host(msg)


func apply_host_retry_wave_setting(enabled: bool) -> void:
	if _is_game_host():
		return
	if not _client_retry_wave_setting_override_active:
		_client_retry_wave_setting_before_override = bool(ProgressData.settings.retry_wave)
		_client_retry_wave_setting_override_active = true
	ProgressData.settings.retry_wave = enabled
	var retry_wave = _get_retry_wave_node()
	if _is_live_node(retry_wave):
		_apply_retry_wave_policy_to_visible_node(retry_wave, enabled)


func _restore_client_retry_wave_setting_override() -> void:
	if not _client_retry_wave_setting_override_active:
		return
	ProgressData.settings.retry_wave = _client_retry_wave_setting_before_override
	_client_retry_wave_setting_override_active = false
	_client_retry_wave_setting_before_override = false


func _apply_retry_wave_policy_to_visible_node(retry_wave: Node, enabled: bool) -> void:
	if not _is_live_node(retry_wave):
		return
	var retry_container = retry_wave.get_node_or_null("Menu/Retry_WaveContainer")
	if not _is_live_node(retry_container):
		retry_container = retry_wave.find_node("Retry_WaveContainer", true, false)
	var ok_button = _get_retry_wave_ok_button(retry_wave)
	var changed = false
	if _is_live_node(retry_container) and retry_container is CanvasItem:
		changed = changed or bool(retry_container.visible) != enabled
		retry_container.visible = enabled
	if _is_live_node(ok_button) and ok_button is CanvasItem:
		changed = changed or bool(ok_button.visible) != (not enabled)
		ok_button.visible = not enabled
	if not changed or not _is_retry_wave_visible(retry_wave):
		return
	if enabled:
		var confirm_button = _get_retry_wave_confirm_button(retry_wave)
		if _is_live_node(confirm_button) and confirm_button is Control and not bool(confirm_button.get("disabled")):
			confirm_button.call_deferred("grab_focus")
	elif _is_live_node(ok_button) and ok_button is Control:
		ok_button.call_deferred("grab_focus")


func _on_online_retry_wave_cancel_pressed() -> void:
	var retry_wave = _get_retry_wave_node()
	if not _is_live_node(retry_wave):
		return
	if not _has_active_online_session():
		_call_vanilla_retry_wave_cancel(retry_wave)
		return
	if not _is_retry_wave_visible(retry_wave):
		return
	var local_context_key = _get_retry_wave_network_context_key()
	if local_context_key == "":
		return
	var context_key = local_context_key
	if not _is_game_host():
		context_key = _get_retry_wave_best_client_context_key(local_context_key)
	_set_retry_wave_all_buttons_locked(retry_wave, true)
	if _is_game_host():
		_start_synced_retry_wave_end(context_key, "host_local_decline")
		return
	_retry_wave_ending_context_key = context_key
	var context_wave = _get_retry_wave_context_wave(context_key)
	var context_retries = _get_retry_wave_context_retries(context_key)
	var msg = {
		"msg_type": "retry_wave_decline",
		"context_key": context_key,
		"local_context_key": local_context_key,
		"current_wave": context_wave if context_wave != -999999 else int(RunData.current_wave),
		"retries": context_retries if context_retries != -999999 else int(RunData.retries),
		"client_msec": OS.get_ticks_msec()
	}
	send_menu_message_to_host(msg)


func _handle_retry_wave_decline_from_client(from_steam_id: String, message: Dictionary) -> void:
	if not _is_game_host():
		return
	var retry_wave = _get_retry_wave_node()
	if not _is_live_node(retry_wave) or not _is_retry_wave_visible(retry_wave):
		return
	_ensure_host_coop_slot_for_remote(from_steam_id)
	var local_context_key = _get_retry_wave_network_context_key()
	if local_context_key == "":
		return
	var client_context_key = str(message.get("context_key", ""))
	# context_key is the Host-issued retry generation. The client's local RunData.retries
	# can legitimately be stale after joining/continuing, so never reject a valid choice
	# because of the redundant client-side counters.
	if client_context_key != local_context_key:
		return
	_start_synced_retry_wave_end(local_context_key, "client_decline:" + from_steam_id)


func _start_synced_retry_wave_end(context_key: String, reason: String = "") -> void:
	if not _is_game_host() or context_key == "":
		return
	if _retry_wave_ending_context_key == context_key:
		return

	# A decline wins while the retry restart is still in its prepare/ack phase. Once
	# RunData has already been reset for the retry commit, returning to EndRun would
	# display corrupted/empty run results, so a packet arriving that late is ignored.
	if not _pending_host_game_start.empty() and str(_pending_host_game_start.get("start_kind", "")) == "retry_wave":
		if bool(_pending_host_game_start.get("retry_run_data_reset_done", false)):
			return
		_pending_host_game_start = {}
		_host_game_start_ack_by_steam_id.clear()
		_host_game_start_ready_by_steam_id.clear()
		_retry_wave_starting_context_key = ""

	_retry_wave_ending_context_key = context_key

	var msg = {
		"msg_type": "retry_wave_end",
		"context_key": context_key,
		"current_wave": int(RunData.current_wave),
		"retries": int(RunData.retries),
		"reason": reason
	}
	for id_value in _get_retry_wave_expected_ids():
		var steam_id = str(id_value)
		if steam_id == "" or steam_id == _self_steam_id:
			continue
		_send_p2p_json(steam_id, msg, true)
	call_deferred("_apply_synced_retry_wave_end", context_key)


func _handle_retry_wave_end_from_host(message: Dictionary) -> void:
	if _is_game_host():
		return
	var retry_wave = _get_retry_wave_node()
	if not _is_live_node(retry_wave) or not _is_retry_wave_visible(retry_wave):
		return
	var context_key = str(message.get("context_key", ""))
	if context_key == "":
		return
	if _retry_wave_host_context_key != "" and context_key != _retry_wave_host_context_key:
		return
	var host_wave = _get_retry_wave_context_wave(context_key)
	var host_retries = _get_retry_wave_context_retries(context_key)
	if host_wave != -999999:
		RunData.current_wave = host_wave
	if host_retries != -999999:
		RunData.retries = host_retries
	_retry_wave_ending_context_key = context_key
	call_deferred("_apply_synced_retry_wave_end", context_key)


func _apply_synced_retry_wave_end(context_key: String) -> void:
	if context_key == "":
		return
	var retry_wave = _get_retry_wave_node()
	if not _is_live_node(retry_wave) or not _is_retry_wave_visible(retry_wave):
		return
	_reset_game_start_sync_state()
	var menu_sync = _get_menu_sync_manager()
	if menu_sync != null and menu_sync.has_method("_end_game_start_guard"):
		menu_sync._end_game_start_guard("retry_wave_declined")
	_set_retry_wave_all_buttons_locked(retry_wave, true)
	_call_vanilla_retry_wave_cancel(retry_wave)


func _set_retry_wave_all_buttons_locked(retry_wave: Node, locked: bool) -> void:
	for button in [_get_retry_wave_confirm_button(retry_wave), _get_retry_wave_cancel_button(retry_wave), _get_retry_wave_ok_button(retry_wave)]:
		if not _is_live_node(button):
			continue
		button.set("disabled", locked)


func _handle_retry_wave_confirm_from_client(from_steam_id: String, message: Dictionary) -> void:
	if not _is_game_host():
		return
	var retry_wave = _get_retry_wave_node()
	if not _is_live_node(retry_wave) or not _is_retry_wave_visible(retry_wave):
		return
	_ensure_host_coop_slot_for_remote(from_steam_id)
	var client_context_key = str(message.get("context_key", ""))
	var local_context_key = _get_retry_wave_network_context_key()
	if local_context_key == "":
		return
	# The Host context is authoritative. A client may still carry a retry count from
	# another local/continued run; accepting an exact context prevents the 1/2 deadlock.
	if client_context_key != local_context_key:
		return
	_mark_retry_wave_ready(from_steam_id, local_context_key, "client")
	_broadcast_retry_wave_state(true)
	_try_start_retry_wave_if_all_ready()


func _handle_retry_wave_state_from_host(message: Dictionary) -> void:
	if message.has("retry_wave_enabled"):
		apply_host_retry_wave_setting(bool(message.get("retry_wave_enabled", false)))
	var context_key = str(message.get("context_key", ""))
	if context_key == "":
		return
	_retry_wave_host_context_key = context_key
	var host_wave = _get_retry_wave_context_wave(context_key)
	var host_retries = _get_retry_wave_context_retries(context_key)
	if host_wave != -999999:
		RunData.current_wave = host_wave
	if host_retries != -999999:
		RunData.retries = host_retries
	var retry_wave = _get_retry_wave_node()
	if not _is_live_node(retry_wave):
		return
	var ready_ids = message.get("ready_ids", [])
	var self_ready = _retry_wave_contexts_exact(_retry_wave_local_waiting_context_key, context_key)
	if typeof(ready_ids) == TYPE_ARRAY:
		self_ready = self_ready or ready_ids.has(_get_retry_wave_self_id())
	var ready_count = int(message.get("ready_count", 0))
	var total_count = int(message.get("total_count", max(1, RunData.get_player_count())))
	var starting = bool(message.get("starting", false))
	if _retry_wave_contexts_exact(_retry_wave_ending_context_key, context_key):
		_set_retry_wave_all_buttons_locked(retry_wave, true)
		return
	if self_ready or starting:
		_set_retry_wave_confirm_locked(retry_wave, true)
	else:
		_set_retry_wave_confirm_locked(retry_wave, false)
		_ensure_retry_wave_confirm_focus(retry_wave)
	_update_retry_wave_waiting_visual(retry_wave, self_ready, ready_count, total_count)


func _mark_retry_wave_ready(steam_id: String, context_key: String, reason: String) -> void:
	if steam_id == "":
		steam_id = "local"
	if _retry_wave_ready_context_key != context_key:
		_retry_wave_ready_by_steam_id.clear()
		_retry_wave_ready_context_key = context_key
	_retry_wave_ready_by_steam_id[steam_id] = OS.get_ticks_msec()
	var retry_wave = _get_retry_wave_node()
	if _is_live_node(retry_wave) and steam_id == _get_retry_wave_self_id():
		_set_retry_wave_confirm_locked(retry_wave, true)


func _try_start_retry_wave_if_all_ready() -> void:
	if not _is_game_host():
		return
	if not _pending_host_game_start.empty():
		return
	var context_key = _get_retry_wave_network_context_key()
	if context_key == "" or _retry_wave_ready_context_key != context_key:
		return
	if _retry_wave_last_started_context_key == context_key:
		return
	var expected_ids = _get_retry_wave_expected_ids()
	if expected_ids.empty():
		return
	for steam_id_value in expected_ids:
		var steam_id = str(steam_id_value)
		if steam_id == "":
			continue
		if not _retry_wave_ready_by_steam_id.has(steam_id):
			return
	_retry_wave_last_started_context_key = context_key
	_start_synced_retry_wave_restart(context_key, expected_ids)


func _start_synced_retry_wave_restart(context_key: String, expected_ids: Array) -> void:
	var remote_ids = []
	for id_value in expected_ids:
		var steam_id = str(id_value)
		if steam_id == "" or steam_id == _get_retry_wave_self_id() or remote_ids.has(steam_id):
			continue
		remote_ids.append(steam_id)
	_pending_host_game_start_id += 1
	var start_id = _pending_host_game_start_id
	var now = OS.get_ticks_msec()
	_host_retry_terminal_suppress_until_msec = now + HOST_RETRY_TERMINAL_SUPPRESS_MSEC
	var suppress_scene = get_tree().current_scene
	_host_retry_terminal_suppress_scene_id = suppress_scene.get_instance_id() if _is_live_node(suppress_scene) else 0
	_host_battle_start_fence_until_msec = now + BATTLE_START_GENERATION_FENCE_MSEC
	_retry_wave_starting_context_key = context_key
	_pending_host_game_start = {
		"start_id": start_id,
		"start_kind": "retry_wave",
		"stage": "waiting_ack",
		"difficulty": _get_current_difficulty_value(),
		"host_prepare_msec": now,
		"run_config": {},
		"remote_ids": remote_ids,
		"retry_context_key": context_key,
		"retry_run_data_reset_done": false,
		"ack_deadline_msec": now + GAME_START_ACK_TIMEOUT_MSEC,
		"force_deadline_msec": now + GAME_START_MAX_WAIT_MSEC,
		"host_enter_msec": 0
	}
	_host_game_start_ack_by_steam_id.clear()
	_host_game_start_ready_by_steam_id.clear()
	_notify_menu_sync_game_start_guard(start_id, "host_retry_wave_prepare")
	_broadcast_retry_wave_state(true)
	if remote_ids.empty():
		_commit_host_game_start("no_remote_retry_wave")
		return
	var prepare = {
		"msg_type": "game_start_prepare",
		"start_id": start_id,
		"start_kind": "retry_wave",
		"difficulty": _get_current_difficulty_value(),
		"host_prepare_msec": now,
		"scene_path": MenuData.game_scene,
		"run_config": {},
		"force_scene_reload": true,
		"retry_context_key": context_key
	}
	for steam_id_value in remote_ids:
		var steam_id = str(steam_id_value)
		if steam_id == "" or steam_id == _self_steam_id:
			continue
		_send_p2p_json(steam_id, prepare, true)


func _prepare_retry_wave_run_config_for_commit() -> Dictionary:
	if _pending_host_game_start.empty():
		return {}
	if not bool(_pending_host_game_start.get("retry_run_data_reset_done", false)):
		RunData.reset_to_start_wave_state()
		RunData.retries += 1
		_pending_host_game_start["retry_run_data_reset_done"] = true
	var config = _build_game_start_run_config(_get_current_difficulty_value())
	config["full_player_run_data_authoritative"] = true
	config["run_config_source"] = "retry_wave"
	config["current_wave"] = int(RunData.current_wave)
	config["retries"] = int(RunData.retries)
	config["retry_context_key"] = str(_pending_host_game_start.get("retry_context_key", ""))
	config["retry_start_id"] = int(_pending_host_game_start.get("start_id", 0))
	_copy_current_host_wave_schedule_into_run_config(config)
	return config


func _execute_host_retry_wave_scene_restart(start_id: int, run_config: Dictionary) -> void:
	var old_scene = get_tree().current_scene
	var old_scene_id = old_scene.get_instance_id() if _is_live_node(old_scene) else 0
	_begin_host_retry_battle_send_warmup(start_id, old_scene_id, "host_retry_wave_scene_restart")
	_reset_battle_transient_caches_for_scene_restart("host_retry_wave")
	_clear_retry_wave_sync_state("host_retry_execute")
	var err = get_tree().change_scene(MenuData.game_scene)
	if err != OK:
		_host_retry_battle_send_min_until_msec = 0
		_host_retry_battle_send_deadline_msec = 0
		_host_retry_battle_send_old_scene_id = 0
		_host_retry_battle_send_started_msec = 0
		_host_retry_battle_send_fresh_after_msec = 0
		_host_retry_battle_send_require_fresh_snapshot = false
		_host_retry_first_snapshot_pending_start_id = 0
		_host_retry_first_snapshot_accepted_start_id = 0
		_host_retry_battle_send_last_block_log_msec = 0


func _broadcast_retry_wave_state(force: bool = false) -> void:
	if not _is_game_host() or _lobby_id == 0:
		return
	var now = OS.get_ticks_msec()
	if not force and now - _retry_wave_last_state_broadcast_msec < RETRY_WAVE_STATE_BROADCAST_INTERVAL_MSEC:
		return
	_retry_wave_last_state_broadcast_msec = now
	var context_key = _retry_wave_ready_context_key
	if context_key == "":
		context_key = _get_retry_wave_network_context_key()
	var expected_ids = _get_retry_wave_expected_ids()
	var ready_ids = _retry_wave_ready_by_steam_id.keys()
	var msg = {
		"msg_type": "retry_wave_state",
		"context_key": context_key,
		"ready_count": _get_retry_wave_ready_count(),
		"total_count": expected_ids.size(),
		"ready_ids": ready_ids,
		"starting": not _pending_host_game_start.empty() and str(_pending_host_game_start.get("start_kind", "")) == "retry_wave",
		"retry_wave_enabled": bool(ProgressData.settings.retry_wave)
	}
	for id_value in expected_ids:
		var steam_id = str(id_value)
		if steam_id == "" or steam_id == _self_steam_id:
			continue
		_send_p2p_json(steam_id, msg, true)


func _poll_retry_wave_waiting_visual(retry_wave: Node) -> void:
	if not _is_retry_wave_visible(retry_wave):
		return
	var context_key = _get_retry_wave_network_context_key()
	if context_key == "":
		return
	if not bool(ProgressData.settings.retry_wave):
		if _is_game_host():
			_broadcast_retry_wave_state(false)
		return
	if _is_game_host():
		if _retry_wave_ready_context_key == context_key:
			_update_retry_wave_waiting_visual(retry_wave, _retry_wave_ready_by_steam_id.has(_get_retry_wave_self_id()), _get_retry_wave_ready_count(), _get_retry_wave_expected_ids().size())
		else:
			_set_retry_wave_confirm_locked(retry_wave, false)
			_ensure_retry_wave_confirm_focus(retry_wave)
		# Also carries the Host-authoritative retry_wave_enabled setting. Broadcasting
		# while the prompt is open repairs any client that missed the earlier run config.
		_broadcast_retry_wave_state(false)
	else:
		if _retry_wave_contexts_exact(_retry_wave_local_waiting_context_key, context_key) or _retry_wave_contexts_exact(_retry_wave_local_waiting_context_key, _retry_wave_host_context_key):
			_set_retry_wave_confirm_locked(retry_wave, true)
		else:
			_set_retry_wave_confirm_locked(retry_wave, false)
			_ensure_retry_wave_confirm_focus(retry_wave)


func _update_retry_wave_waiting_visual(retry_wave: Node, local_waiting: bool, ready_count: int, total_count: int) -> void:
	var label = retry_wave.get_node_or_null("Menu/Retry_WaveContainer/Label_number_retry")
	if not _is_live_node(label):
		label = retry_wave.find_node("Label_number_retry", true, false)
	if not _is_live_node(label):
		return
	var base = ""
	if Text != null and Text.has_method("text"):
		base = Text.text("RETRY_NUMBER", [str(RunData.retries)])
	if base == "":
		base = "Retries: " + str(RunData.retries)
	var wait_text = "Waiting retry confirmations: " + str(ready_count) + "/" + str(max(1, total_count))
	if local_waiting:
		wait_text += "\nYou are ready."
	label.text = base + "\n" + wait_text


func _set_retry_wave_confirm_locked(retry_wave: Node, locked: bool) -> void:
	var button = _get_retry_wave_confirm_button(retry_wave)
	if not _is_live_node(button):
		return
	button.set("disabled", locked)
	var cancel_button = _get_retry_wave_cancel_button(retry_wave)
	if _is_live_node(cancel_button):
		# Once this player has confirmed retry, keep the whole local choice fixed.
		# Another player can still decline and make the Host end the run for everyone,
		# but this prevents a late local reversal racing the retry commit.
		cancel_button.set("disabled", locked)
	if locked:
		retry_wave.set("confirm_button_pressed", true)
	else:
		# Vanilla RetryWave uses this latch to avoid double-confirm. When the same
		# wave fails again, carrying the old latch forward makes the client unable
		# to press Continue/Retry even though the button is visible.
		retry_wave.set("confirm_button_pressed", false)


func _ensure_retry_wave_confirm_focus(retry_wave: Node) -> void:
	if not _is_retry_wave_visible(retry_wave):
		return
	var button = _get_retry_wave_confirm_button(retry_wave)
	if not _is_live_node(button) or not (button is Control):
		return
	if bool(button.get("disabled")):
		return
	button.focus_mode = Control.FOCUS_ALL

	# Godot 3.x does not expose focus ownership on SceneTree. Calling
	# get_tree().get_focus_owner() crashes the client on the RetryWave screen.
	var focus_owner = _get_gui_focus_owner_safe(button)
	if _safe_node_contains(retry_wave, focus_owner):
		return

	# This function is polled while the RetryWave is visible; throttle the deferred
	# focus request so a missing/stale focus owner cannot produce per-frame churn.
	var now = OS.get_ticks_msec()
	var last_focus_msec = 0
	if retry_wave.has_meta("brotato_online_retry_focus_last_msec"):
		last_focus_msec = int(retry_wave.get_meta("brotato_online_retry_focus_last_msec"))
	if now - last_focus_msec < 300:
		return
	retry_wave.set_meta("brotato_online_retry_focus_last_msec", now)
	button.call_deferred("grab_focus")


func _call_vanilla_retry_wave_confirm(retry_wave: Node) -> void:
	if _is_live_node(retry_wave) and retry_wave.has_method("_on_ConfirmButton_pressed"):
		retry_wave._on_ConfirmButton_pressed()


func _call_vanilla_retry_wave_cancel(retry_wave: Node) -> void:
	if _is_live_node(retry_wave) and retry_wave.has_method("_on_CancelButton_pressed"):
		retry_wave._on_CancelButton_pressed()


func _get_retry_wave_node() -> Node:
	var scene = get_tree().current_scene
	if not _is_live_node(scene):
		return null
	var retry_wave = scene.get_node_or_null("UI/RetryWave")
	if _is_live_node(retry_wave):
		return retry_wave
	return scene.find_node("RetryWave", true, false)


func _get_retry_wave_confirm_button(retry_wave: Node) -> Node:
	if not _is_live_node(retry_wave):
		return null
	var button = retry_wave.get_node_or_null("Menu/Retry_WaveContainer/ConfirmButton")
	if _is_live_node(button):
		return button
	return retry_wave.find_node("ConfirmButton", true, false)


func _get_retry_wave_cancel_button(retry_wave: Node) -> Node:
	if not _is_live_node(retry_wave):
		return null
	var button = retry_wave.get_node_or_null("Menu/Retry_WaveContainer/CancelButton")
	if _is_live_node(button):
		return button
	return retry_wave.find_node("CancelButton", true, false)


func _get_retry_wave_ok_button(retry_wave: Node) -> Node:
	if not _is_live_node(retry_wave):
		return null
	var button = retry_wave.get_node_or_null("Menu/OkButton")
	if _is_live_node(button):
		return button
	return retry_wave.find_node("OkButton", true, false)


func _is_retry_wave_visible(retry_wave: Node) -> bool:
	if not _is_live_node(retry_wave):
		return false
	if retry_wave is CanvasItem:
		return retry_wave.visible and retry_wave.is_visible_in_tree()
	return true


func _get_retry_wave_network_context_key() -> String:
	if not _is_in_game_scene():
		return ""
	return str(int(RunData.current_wave)) + ":" + str(int(RunData.retries))


func _get_retry_wave_best_client_context_key(local_context_key: String) -> String:
	if _retry_wave_contexts_same_wave(_retry_wave_host_context_key, local_context_key):
		return _retry_wave_host_context_key
	return local_context_key


func _get_retry_wave_context_wave(context_key: String) -> int:
	if context_key == "":
		return -999999
	var parts = context_key.split(":")
	if parts.size() <= 0:
		return -999999
	var wave_str = str(parts[0])
	if not wave_str.is_valid_integer():
		return -999999
	return int(wave_str)


func _get_retry_wave_context_retries(context_key: String) -> int:
	if context_key == "":
		return -999999
	var parts = context_key.split(":")
	if parts.size() < 2:
		return -999999
	var retries_str = str(parts[1])
	if not retries_str.is_valid_integer():
		return -999999
	return int(retries_str)


func _retry_wave_contexts_exact(a: String, b: String) -> bool:
	return a != "" and b != "" and a == b


func _retry_wave_contexts_same_wave(a: String, b: String) -> bool:
	var wave_a = _get_retry_wave_context_wave(a)
	var wave_b = _get_retry_wave_context_wave(b)
	return wave_a != -999999 and wave_a == wave_b


func _get_retry_wave_self_id() -> String:
	if _self_steam_id != "" and _self_steam_id != "0":
		return _self_steam_id
	return "local"


func _get_retry_wave_expected_ids() -> Array:
	var expected = []
	var self_id = _get_retry_wave_self_id()
	if self_id != "":
		expected.append(self_id)
	_refresh_lobby_members()
	for member in _members:
		var steam_id = str(member.get("steam_id", ""))
		if steam_id == "" or steam_id == _self_steam_id or expected.has(steam_id):
			continue
		expected.append(steam_id)
	return expected


func _get_retry_wave_ready_count() -> int:
	var expected = _get_retry_wave_expected_ids()
	var count = 0
	for id_value in expected:
		if _retry_wave_ready_by_steam_id.has(str(id_value)):
			count += 1
	return count


func _reset_battle_transient_caches_for_scene_restart(reason: String) -> void:
	_last_battle_snapshot_send_msec = 0
	_last_battle_snapshot_sent_tick_by_steam_id.clear()
	_last_battle_reliable_sent_key_by_steam_id.clear()
	_last_battle_terminal_state_key_by_steam_id.clear()
	_last_battle_terminal_state_msec_by_steam_id.clear()
	var state_snapshot = _get_state_snapshot_manager()
	if state_snapshot != null and state_snapshot.has_method("_on_left_game_scene"):
		state_snapshot._on_left_game_scene()
	var replica = _get_battle_replica_manager()
	if replica != null and replica.has_method("_clear_all"):
		replica._clear_all(reason)


func _host_retry_first_snapshot_needs_gate() -> bool:
	if not _is_game_host():
		return false
	if str(_host_current_battle_start_kind) == "":
		return false
	var start_id = int(_host_current_battle_start_id)
	if start_id <= 0:
		return false
	return int(_host_retry_first_snapshot_accepted_start_id) != start_id


func _ensure_host_retry_first_snapshot_gate_armed(start_id: int, reason: String, arm_warmup: bool = false, old_scene_id: int = 0) -> bool:
	if not _is_game_host() or start_id <= 0:
		return false
	if int(_host_retry_first_snapshot_accepted_start_id) == start_id:
		return false
	var now = OS.get_ticks_msec()
	var changed = false
	if int(_host_retry_first_snapshot_pending_start_id) != start_id:
		_host_retry_first_snapshot_pending_start_id = start_id
		_host_retry_first_snapshot_accepted_start_id = 0
		_host_retry_battle_send_started_msec = now
		_host_retry_battle_send_fresh_after_msec = now
		_host_retry_battle_send_last_block_log_msec = 0
		changed = true
	if not bool(_host_retry_battle_send_require_fresh_snapshot):
		_host_retry_battle_send_require_fresh_snapshot = true
		changed = true
	if int(_host_retry_battle_send_started_msec) <= 0:
		_host_retry_battle_send_started_msec = now
		changed = true
	if int(_host_retry_battle_send_fresh_after_msec) <= 0:
		_host_retry_battle_send_fresh_after_msec = now
		changed = true
	if arm_warmup:
		_host_retry_battle_send_min_until_msec = now + HOST_RETRY_BATTLE_SEND_WARMUP_MSEC
		_host_retry_battle_send_deadline_msec = now + HOST_RETRY_BATTLE_SEND_MAX_WAIT_MSEC
		_host_retry_battle_send_old_scene_id = old_scene_id
		_last_battle_snapshot_send_msec = now
		changed = true
	if changed:
		_last_battle_snapshot_sent_tick_by_steam_id.clear()
		_last_battle_reliable_sent_key_by_steam_id.clear()
		_last_battle_terminal_state_key_by_steam_id.clear()
		_last_battle_terminal_state_msec_by_steam_id.clear()
	return changed


func _begin_host_retry_battle_send_warmup(start_id: int, old_scene_id: int, reason: String) -> void:
	var now = OS.get_ticks_msec()
	_host_retry_battle_send_min_until_msec = now + HOST_RETRY_BATTLE_SEND_WARMUP_MSEC
	_host_retry_battle_send_deadline_msec = now + HOST_RETRY_BATTLE_SEND_MAX_WAIT_MSEC
	_host_retry_battle_send_old_scene_id = old_scene_id
	_host_retry_battle_send_started_msec = now
	_host_retry_battle_send_fresh_after_msec = now
	_host_retry_battle_send_require_fresh_snapshot = true
	_host_retry_first_snapshot_pending_start_id = start_id
	_host_retry_first_snapshot_accepted_start_id = 0
	_host_retry_battle_send_last_block_log_msec = 0
	_last_battle_snapshot_send_msec = now
	_last_battle_snapshot_sent_tick_by_steam_id.clear()
	_last_battle_reliable_sent_key_by_steam_id.clear()
	_last_battle_terminal_state_key_by_steam_id.clear()
	_last_battle_terminal_state_msec_by_steam_id.clear()


func _is_host_retry_battle_send_warmup_blocked() -> bool:
	if not _is_game_host():
		return false
	var now = OS.get_ticks_msec()
	if _host_retry_battle_send_min_until_msec <= 0 and _host_retry_battle_send_deadline_msec <= 0:
		return false
	var current_scene = get_tree().current_scene
	var current_scene_id = current_scene.get_instance_id() if _is_live_node(current_scene) else 0
	if now < _host_retry_battle_send_min_until_msec:
		return true
	if _host_retry_battle_send_old_scene_id > 0 and current_scene_id == _host_retry_battle_send_old_scene_id and now < _host_retry_battle_send_deadline_msec:
		return true
	if _host_retry_battle_send_min_until_msec > 0 or _host_retry_battle_send_deadline_msec > 0:
		_host_retry_battle_send_fresh_after_msec = now
		_host_retry_battle_send_require_fresh_snapshot = true
	_host_retry_battle_send_min_until_msec = 0
	_host_retry_battle_send_deadline_msec = 0
	_host_retry_battle_send_old_scene_id = 0
	_last_battle_snapshot_send_msec = 0
	_last_battle_snapshot_sent_tick_by_steam_id.clear()
	_last_battle_reliable_sent_key_by_steam_id.clear()
	_last_battle_terminal_state_key_by_steam_id.clear()
	_last_battle_terminal_state_msec_by_steam_id.clear()
	return false


func _current_scene_instance_id() -> int:
	var scene = get_tree().current_scene
	return scene.get_instance_id() if _is_live_node(scene) else 0


func _host_snapshot_scene_instance_id(snapshot: Dictionary) -> int:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return 0
	if snapshot.has("scene_instance_id"):
		return int(snapshot.get("scene_instance_id", 0))
	if snapshot.has("sid"):
		return int(snapshot.get("sid", 0))
	return 0


func _host_retry_snapshot_has_alive_players(snapshot: Dictionary) -> bool:
	var players = snapshot.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return false
	var expected_count = max(1, int(RunData.get_player_count()))
	if players.size() < expected_count:
		return false
	var checked = 0
	for p in players:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		checked += 1
		if bool(p.get("dead", false)):
			return false
		if int(p.get("health", -1)) <= 0:
			return false
	return checked >= expected_count


func _host_retry_log_first_snapshot_block(reason: String, snapshot: Dictionary) -> void:
	var now = OS.get_ticks_msec()
	if now - _host_retry_battle_send_last_block_log_msec < HOST_RETRY_FIRST_SNAPSHOT_BLOCK_LOG_MSEC:
		return
	_host_retry_battle_send_last_block_log_msec = now
	var wave_state = snapshot.get("wave_timer_state", {}) if typeof(snapshot) == TYPE_DICTIONARY else {}
	var players = snapshot.get("players", []) if typeof(snapshot) == TYPE_DICTIONARY else []
	var snapshot_time = int(snapshot.get("time_msec", snapshot.get("server_time_msec", 0))) if typeof(snapshot) == TYPE_DICTIONARY else 0
	var snapshot_tick = int(snapshot.get("tick", 0)) if typeof(snapshot) == TYPE_DICTIONARY else 0
	var wave_left = wave_state.get("time_left", -1) if typeof(wave_state) == TYPE_DICTIONARY else -1
	var wave_running = wave_state.get("running", false) if typeof(wave_state) == TYPE_DICTIONARY else false
	print("[BO_SYNC][first_snapshot_block] reason=" + str(reason)
		+ " kind=" + str(_host_current_battle_start_kind)
		+ " start_id=" + str(_host_current_battle_start_id)
		+ " tick=" + str(snapshot_tick)
		+ " snap_time=" + str(snapshot_time)
		+ " wave_left=" + str(wave_left)
		+ " running=" + str(wave_running)
		+ " players=" + str(_safe_array_size(players))
		+ " scene=" + str(_host_snapshot_scene_instance_id(snapshot))
		+ " current_scene=" + str(_current_scene_instance_id()))


func _host_retry_first_snapshot_gate_pending() -> bool:
	if str(_host_current_battle_start_kind) == "":
		return false
	if _host_retry_battle_send_require_fresh_snapshot:
		return true
	return _host_retry_first_snapshot_pending_start_id > 0 and _host_retry_first_snapshot_pending_start_id == int(_host_current_battle_start_id)


func _host_retry_snapshot_scene_enter_msec(snapshot: Dictionary) -> int:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return 0
	if snapshot.has("scene_enter_msec"):
		return int(snapshot.get("scene_enter_msec", 0))
	if snapshot.has("sem"):
		return int(snapshot.get("sem", 0))
	return 0


func _host_first_snapshot_wave_timer_ready(snapshot: Dictionary) -> bool:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return false
	var wave_state = snapshot.get("wave_timer_state", {})
	if typeof(wave_state) != TYPE_DICTIONARY or wave_state.empty():
		return false
	var snapshot_wave = int(snapshot.get("wave", wave_state.get("wave", -9999)))
	var local_wave = int(RunData.current_wave)
	if snapshot_wave != local_wave:
		return false
	var time_left = float(wave_state.get("time_left", -1.0))
	return _safe_bool(wave_state.get("running", false)) and time_left > HOST_FIRST_BATTLE_SNAPSHOT_MIN_TIME_LEFT_SEC


func _host_retry_allow_first_fresh_snapshot(snapshot: Dictionary) -> bool:
	if not _is_game_host():
		return true
	if not _host_retry_first_snapshot_needs_gate():
		return true
	if not _host_retry_first_snapshot_gate_pending():
		_ensure_host_retry_first_snapshot_gate_armed(int(_host_current_battle_start_id), "allow_missing_gate", false, 0)
	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.empty():
		_host_retry_log_first_snapshot_block("empty_snapshot", snapshot)
		return false
	var current_scene_id = _current_scene_instance_id()
	var snapshot_scene_id = _host_snapshot_scene_instance_id(snapshot)
	if snapshot_scene_id <= 0 or snapshot_scene_id != current_scene_id:
		_host_retry_log_first_snapshot_block("scene_mismatch_or_unstamped", snapshot)
		return false
	var scene_enter_msec = _host_retry_snapshot_scene_enter_msec(snapshot)
	if scene_enter_msec <= 0 or (_host_retry_battle_send_started_msec > 0 and scene_enter_msec < _host_retry_battle_send_started_msec):
		_host_retry_log_first_snapshot_block("scene_not_registered_after_start", snapshot)
		return false
	var snapshot_time = int(snapshot.get("time_msec", snapshot.get("server_time_msec", 0)))
	if _host_retry_battle_send_fresh_after_msec > 0 and snapshot_time < _host_retry_battle_send_fresh_after_msec:
		_host_retry_log_first_snapshot_block("cached_before_warmup_release", snapshot)
		return false
	if not _host_retry_snapshot_has_alive_players(snapshot):
		_host_retry_log_first_snapshot_block("players_not_alive_after_start", snapshot)
		return false
	if not _host_first_snapshot_wave_timer_ready(snapshot):
		_host_retry_log_first_snapshot_block("wave_timer_not_over_1s", snapshot)
		return false
	_host_retry_battle_send_require_fresh_snapshot = false
	_host_retry_first_snapshot_pending_start_id = 0
	_host_retry_first_snapshot_accepted_start_id = int(_host_current_battle_start_id)
	_host_retry_battle_send_last_block_log_msec = 0
	_last_battle_snapshot_sent_tick_by_steam_id.clear()
	_last_battle_reliable_sent_key_by_steam_id.clear()
	_last_battle_terminal_state_key_by_steam_id.clear()
	_last_battle_terminal_state_msec_by_steam_id.clear()
	return true


func _is_host_main_terminal_or_retry_state() -> bool:
	if not _is_game_host() or not _is_in_game_scene():
		return false
	var main = get_tree().current_scene
	if not _is_live_node(main):
		return false
	if bool(main.get("_cleaning_up")) or bool(main.get("_is_wave_failed")) or bool(main.get("_is_run_lost")) or bool(main.get("_is_run_won")):
		return true
	var retry_wave = main.get("_retry_wave")
	if _is_live_node(retry_wave) and retry_wave is CanvasItem and retry_wave.visible:
		return true
	var retry_node = main.get_node_or_null("UI/RetryWave")
	if _is_live_node(retry_node) and retry_node is CanvasItem and retry_node.visible:
		return true
	return false


func _poll_host_difficulty_start_intercept() -> void:
	if not _is_game_host() or _lobby_id == 0:
		return
	if not _is_in_difficulty_selection_scene():
		_host_difficulty_intercept_selection_id = 0
		return
	if not _pending_host_game_start.empty():
		return

	var selection = get_tree().current_scene
	if not _is_live_node(selection) or not selection.has_method("_get_inventories"):
		return

	var selection_id = selection.get_instance_id()
	if _host_difficulty_intercept_selection_id == selection_id:
		return
	_host_difficulty_intercept_selection_id = selection_id

	var inventories = selection._get_inventories()
	if typeof(inventories) != TYPE_ARRAY:
		return

	for inv_index in range(inventories.size()):
		var inventory = inventories[inv_index]
		if not _is_live_node(inventory):
			continue
		if inventory.is_connected("element_pressed", selection, "_on_element_pressed"):
			inventory.disconnect("element_pressed", selection, "_on_element_pressed")
		if not inventory.is_connected("element_pressed", self, "_on_host_difficulty_element_pressed"):
			inventory.connect("element_pressed", self, "_on_host_difficulty_element_pressed", [selection, inv_index])



func _on_host_difficulty_element_pressed(element, selection: Node, inventory_index: int) -> void:
	# Inventory.element_pressed emits only (element). The bound args below are (selection, inv_index),
	# so this handler receives exactly 3 arguments: element, selection, inventory_index.
	var inventory_player_index = int(inventory_index)
	if not _is_game_host() or _lobby_id == 0:
		_call_vanilla_difficulty_start(selection, element, inventory_player_index)
		return
	if not _is_live_node(selection) or not _is_live_node(element):
		return
	if not _pending_host_game_start.empty():
		return

	var difficulty_value = _get_difficulty_value_from_element(element)
	if difficulty_value < 0:
		return

	_pending_host_game_start_id += 1
	var start_id = _pending_host_game_start_id
	var now = OS.get_ticks_msec()
	var run_config = _build_game_start_run_config(difficulty_value, true)
	run_config["run_config_source"] = "difficulty_start"
	run_config["game_start_id"] = start_id
	var remote_ids = _get_remote_ids_for_host_sync()

	_pending_host_game_start = {
		"start_id": start_id,
		"start_kind": "difficulty",
		"stage": "waiting_ack",
		"difficulty": difficulty_value,
		"selection": selection,
		"element": element,
		"inventory_player_index": inventory_player_index,
		"inventory_index": inventory_index,
		"host_prepare_msec": now,
		"run_config": run_config,
		"remote_ids": remote_ids,
		"ack_deadline_msec": now + GAME_START_ACK_TIMEOUT_MSEC,
		"force_deadline_msec": now + GAME_START_MAX_WAIT_MSEC,
		"host_enter_msec": 0
	}
	_host_game_start_ack_by_steam_id.clear()
	_host_game_start_ready_by_steam_id.clear()
	_notify_menu_sync_game_start_guard(start_id, "host_difficulty_prepare")

	if remote_ids.empty():
		_commit_host_game_start("no_remote")
		return

	var prepare = {
		"msg_type": "game_start_prepare",
		"start_id": start_id,
		"difficulty": difficulty_value,
		"host_prepare_msec": now,
		"scene_path": MenuData.game_scene,
		"run_config": run_config
	}
	for steam_id_value in remote_ids:
		var steam_id = str(steam_id_value)
		if steam_id == "" or steam_id == _self_steam_id:
			continue
		_send_p2p_json(steam_id, prepare, true)



func has_pending_synced_shop_game_start() -> bool:
	return not _pending_host_game_start.empty() and str(_pending_host_game_start.get("start_kind", "")) == "shop"


func request_synced_shop_game_start(shop, player_index: int, run_config: Dictionary = {}) -> bool:
	if not _is_game_host() or _lobby_id == 0:
		return false
	if not _is_live_node(shop):
		return false
	if not _pending_host_game_start.empty():
		return false

	var difficulty_value = _get_current_difficulty_value()
	var start_run_config = {}
	if typeof(run_config) == TYPE_DICTIONARY:
		start_run_config = run_config.duplicate(true)
	if start_run_config.empty():
		start_run_config = _build_game_start_run_config(difficulty_value)
	elif should_force_full_item_list_for_next_scene_sync() and not bool(start_run_config.get("full_item_list_for_scene_sync", false)):
		# MenuSync may have built this shop-start config before SteamLobby knew a fresh
		# client needed a held-item baseline. Rebuild with forced compact items.
		start_run_config = _build_game_start_run_config(difficulty_value, false, true)
	if start_run_config.has("current_difficulty"):
		difficulty_value = int(start_run_config.get("current_difficulty", difficulty_value))
	else:
		start_run_config["current_difficulty"] = difficulty_value
	start_run_config["player_count"] = int(RunData.get_player_count())
	start_run_config["play_mode"] = int(RunData.play_mode)
	start_run_config["is_coop_run"] = bool(RunData.is_coop_run)
	start_run_config["is_endless_run"] = bool(RunData.is_endless_run)
	start_run_config["endless_mode_toggled"] = bool(ProgressData.settings.endless_mode_toggled)
	_augment_run_config_with_host_zone(start_run_config)
	_copy_current_host_wave_schedule_into_run_config(start_run_config)

	_pending_host_game_start_id += 1
	var start_id = _pending_host_game_start_id
	var now = OS.get_ticks_msec()
	var remote_ids = _get_remote_ids_for_host_sync()

	start_run_config["game_start_id"] = start_id
	_pending_host_game_start = {
		"start_id": start_id,
		"start_kind": "shop",
		"stage": "waiting_ack",
		"difficulty": difficulty_value,
		"shop": shop,
		"shop_player_index": player_index,
		"host_prepare_msec": now,
		"run_config": start_run_config,
		"remote_ids": remote_ids,
		"ack_deadline_msec": now + GAME_START_ACK_TIMEOUT_MSEC,
		"force_deadline_msec": now + GAME_START_MAX_WAIT_MSEC,
		"host_enter_msec": 0
	}
	_host_game_start_ack_by_steam_id.clear()
	_host_game_start_ready_by_steam_id.clear()
	_notify_menu_sync_game_start_guard(start_id, "host_shop_prepare")

	if remote_ids.empty():
		_commit_host_game_start("no_remote_shop")
		return true

	var prepare = {
		"msg_type": "game_start_prepare",
		"start_id": start_id,
		"start_kind": "shop",
		"difficulty": difficulty_value,
		"host_prepare_msec": now,
		"scene_path": MenuData.game_scene,
		"run_config": start_run_config
	}
	for steam_id_value in remote_ids:
		var steam_id = str(steam_id_value)
		if steam_id == "" or steam_id == _self_steam_id:
			continue
		_send_p2p_json(steam_id, prepare, true)

	return true


func _get_current_difficulty_value() -> int:
	var value = RunData.get("current_difficulty")
	if value == null:
		value = RunData.get("current_danger")
	if value == null:
		return 0
	return int(value)


func _build_game_start_run_config(difficulty_value: int, generate_difficulty_schedule: bool = false, force_full_held_items: bool = false) -> Dictionary:
	var run_config = {}
	var menu_sync = _get_menu_sync_manager()
	if not force_full_held_items:
		force_full_held_items = should_force_full_item_list_for_next_scene_sync()
	if menu_sync != null and menu_sync.has_method("build_menu_scene_state"):
		var state = menu_sync.build_menu_scene_state(false, true, force_full_held_items)
		if typeof(state) == TYPE_DICTIONARY:
			run_config = state.get("run_config", {})
	if typeof(run_config) != TYPE_DICTIONARY:
		run_config = {}
	run_config = run_config.duplicate(true)
	run_config["current_difficulty"] = difficulty_value
	run_config["player_count"] = int(RunData.get_player_count())
	run_config["play_mode"] = int(RunData.play_mode)
	run_config["is_coop_run"] = bool(RunData.is_coop_run)
	run_config["is_endless_run"] = bool(RunData.is_endless_run)
	run_config["endless_mode_toggled"] = bool(ProgressData.settings.endless_mode_toggled)
	run_config["retry_wave_enabled"] = bool(ProgressData.settings.retry_wave)
	_augment_run_config_with_host_zone(run_config)
	if generate_difficulty_schedule:
		_generate_host_difficulty_wave_schedule_into_run_config(run_config, difficulty_value)
	else:
		_copy_current_host_wave_schedule_into_run_config(run_config)
	return run_config


func _generate_host_difficulty_wave_schedule_into_run_config(run_config: Dictionary, difficulty_value: int) -> void:
	# Difficulty selection has not called vanilla _on_element_pressed yet, but the
	# future-wave RNG tables must already be in game_start_commit so clients do
	# not regenerate elite/horde and D6+ nightmare warning waves locally.
	RunData.current_difficulty = difficulty_value
	RunData.reset_elites_spawn()
	RunData.reset_events_nightmare()
	RunData.init_elites_spawn()
	RunData.init_events_nightmare()
	# This runs before vanilla difficulty effects are applied to PlayerRunData.
	# Calling init_bosses_spawn() here can therefore miss difficulty 5+'s
	# double_boss effect and lock game_start_commit to a one-boss wave 20.
	RunData.bosses_spawn = RunData.get_bosses_to_spawn(difficulty_value >= 5)
	_copy_current_host_wave_schedule_into_run_config(run_config)


func _copy_current_host_wave_schedule_into_run_config(run_config: Dictionary) -> void:
	run_config["constant_projectile"] = int(RunData.constant_projectile)
	run_config["nb_of_waves"] = int(RunData.nb_of_waves)
	run_config["elites_spawn"] = RunData.elites_spawn.duplicate(true)
	run_config["bosses_spawn"] = RunData.bosses_spawn.duplicate(true)
	run_config["events_spawn"] = RunData.events_spawn.duplicate(true)
	run_config["events_fog_of_war"] = RunData.events_fog_of_war.duplicate(true)
	run_config["events_bullet_hell"] = RunData.events_bullet_hell.duplicate(true)


func _apply_host_wave_schedule_from_run_config(config) -> void:
	if typeof(config) != TYPE_DICTIONARY:
		return
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


func _handle_game_start_prepare_from_host(message: Dictionary) -> void:
	_stop_client_hello_retry("game_start_prepare")
	_apply_host_zone_sync_for_client(message, "game_start_prepare")
	_online_flow_started = true
	_online_flow_left_since_msec = 0
	var start_id = int(message.get("start_id", 0))
	var start_kind = str(message.get("start_kind", "difficulty"))
	var retry_context_key = str(message.get("retry_context_key", ""))
	var client_recv_msec = OS.get_ticks_msec()
	_arm_client_battle_generation_fence(start_id, start_kind, retry_context_key, "prepare")
	_client_game_start_prepare_msec = client_recv_msec
	_last_client_game_start_commit_id = start_id
	_client_ignore_stale_menu_until_msec = client_recv_msec + CLIENT_STALE_MENU_GUARD_MSEC
	_notify_menu_sync_game_start_guard(start_id, "client_prepare")
	var host_prepare_msec = int(message.get("host_prepare_msec", 0))
	var ack = {
		"msg_type": "game_start_time_ack",
		"start_id": start_id,
		"difficulty": int(message.get("difficulty", -1)),
		"host_prepare_msec": host_prepare_msec,
		"client_recv_msec": client_recv_msec,
		"client_send_msec": OS.get_ticks_msec(),
		"client_time_delta_msec": client_recv_msec - host_prepare_msec
	}
	send_menu_message_to_host(ack)


func _handle_game_start_time_ack(from_steam_id: String, message: Dictionary) -> void:
	if _pending_host_game_start.empty():
		return
	var start_id = int(message.get("start_id", 0))
	if start_id != int(_pending_host_game_start.get("start_id", -1)):
		return
	var ack = message.duplicate(true)
	ack["host_ack_msec"] = OS.get_ticks_msec()
	_host_game_start_ack_by_steam_id[from_steam_id] = ack


func _handle_client_game_scene_ready(from_steam_id: String, message: Dictionary) -> void:
	if _pending_host_game_start.empty():
		return
	var start_id = int(message.get("start_id", 0))
	if start_id != int(_pending_host_game_start.get("start_id", -1)):
		return
	_host_game_start_ready_by_steam_id[from_steam_id] = message.duplicate(true)


func _poll_host_game_start_sync() -> void:
	if not _is_game_host() or _pending_host_game_start.empty():
		return
	var stage = str(_pending_host_game_start.get("stage", ""))
	var now = OS.get_ticks_msec()
	if stage == "waiting_ack":
		var remote_ids = _pending_host_game_start.get("remote_ids", [])
		var all_acked = true
		if typeof(remote_ids) == TYPE_ARRAY:
			for id_value in remote_ids:
				var steam_id = str(id_value)
				if steam_id == "" or steam_id == _self_steam_id:
					continue
				if not _host_game_start_ack_by_steam_id.has(steam_id):
					all_acked = false
					break
		if all_acked or now >= int(_pending_host_game_start.get("ack_deadline_msec", 0)):
			_commit_host_game_start("all_acked" if all_acked else "ack_timeout")
	elif stage == "waiting_client_scene_ready":
		var remote_ids_ready = _pending_host_game_start.get("remote_ids", [])
		var all_ready = true
		if typeof(remote_ids_ready) == TYPE_ARRAY:
			for id_value in remote_ids_ready:
				var ready_steam_id = str(id_value)
				if ready_steam_id == "" or ready_steam_id == _self_steam_id:
					continue
				if not _host_game_start_ready_by_steam_id.has(ready_steam_id):
					all_ready = false
					break
		if all_ready or now >= int(_pending_host_game_start.get("ready_deadline_msec", 0)):
			_execute_pending_host_game_start()
	elif stage == "committed":
		if now >= int(_pending_host_game_start.get("host_enter_msec", 0)) or now >= int(_pending_host_game_start.get("force_deadline_msec", 0)):
			_execute_pending_host_game_start()


func _commit_host_game_start(reason: String) -> void:
	if _pending_host_game_start.empty():
		return
	_notify_menu_sync_game_start_guard(int(_pending_host_game_start.get("start_id", 0)), "host_commit:" + reason)
	var now = OS.get_ticks_msec()
	var host_enter_msec = now + GAME_START_COMMIT_LEAD_MSEC
	var remote_ids_for_gate = _pending_host_game_start.get("remote_ids", [])
	var has_remote_gate = typeof(remote_ids_for_gate) == TYPE_ARRAY and not remote_ids_for_gate.empty()
	if has_remote_gate:
		_pending_host_game_start["stage"] = "waiting_client_scene_ready"
		_pending_host_game_start["ready_deadline_msec"] = now + GAME_START_READY_TIMEOUT_MSEC
	else:
		_pending_host_game_start["stage"] = "committed"
	_pending_host_game_start["host_enter_msec"] = host_enter_msec
	_host_game_start_ready_by_steam_id.clear()

	if str(_pending_host_game_start.get("start_kind", "")) == "retry_wave":
		_pending_host_game_start["run_config"] = _prepare_retry_wave_run_config_for_commit()
		_pending_host_game_start["difficulty"] = _get_current_difficulty_value()

	var run_config = _pending_host_game_start.get("run_config", {})
	var remote_ids = _pending_host_game_start.get("remote_ids", [])
	if typeof(remote_ids) != TYPE_ARRAY:
		remote_ids = []

	for id_value in remote_ids:
		var steam_id = str(id_value)
		if steam_id == "" or steam_id == _self_steam_id:
			continue
		var client_enter_msec = 0
		var offset_est = 0.0
		var rtt = -1
		if _host_game_start_ack_by_steam_id.has(steam_id):
			var ack = _host_game_start_ack_by_steam_id[steam_id]
			var t0 = int(_pending_host_game_start.get("host_prepare_msec", 0))
			var t1 = int(ack.get("client_recv_msec", 0))
			var t2 = int(ack.get("client_send_msec", t1))
			var t3 = int(ack.get("host_ack_msec", now))
			rtt = max(0, t3 - t0)
			offset_est = (float(t1 - t0) + float(t2 - t3)) * 0.5
			client_enter_msec = int(round(float(host_enter_msec) + offset_est))
		var start_kind_for_commit = str(_pending_host_game_start.get("start_kind", "difficulty"))
		var commit = {
			"msg_type": "game_start_commit",
			"wait_host_for_client_scene_ready": has_remote_gate,
			"force_scene_reload": start_kind_for_commit == "retry_wave",
			"start_id": int(_pending_host_game_start.get("start_id", 0)),
			"start_kind": start_kind_for_commit,
			"difficulty": int(_pending_host_game_start.get("difficulty", -1)),
			"scene_path": MenuData.game_scene,
			"run_config": run_config,
			"host_prepare_msec": int(_pending_host_game_start.get("host_prepare_msec", 0)),
			"host_commit_msec": now,
			"host_enter_msec": host_enter_msec,
			"client_enter_msec": client_enter_msec,
			"client_enter_delay_msec": 0 if has_remote_gate else GAME_START_COMMIT_LEAD_MSEC,
			"rtt_msec": rtt,
			"offset_est_msec": offset_est,
			"reason": reason
		}
		var commit_send_ok = _send_p2p_json(steam_id, commit, true)
		if commit_send_ok and bool(run_config.get("full_item_list_for_scene_sync", false)):
			_clear_full_item_list_scene_sync_requirement_for_client(steam_id)



func _handle_game_start_commit_from_host(message: Dictionary) -> void:
	_stop_client_hello_retry("game_start_commit")
	_apply_host_zone_sync_for_client(message, "game_start_commit")
	_online_flow_started = true
	_online_flow_left_since_msec = 0
	# Slot/device topology is established while staging the lobby and must stay fixed
	# for the whole run. Do not rebuild it again when every wave enters battle.
	_lock_online_run_slots("client_game_start_commit")
	_sync_slot_manager_lock_flag()

	var now = OS.get_ticks_msec()
	var commit_start_id = int(message.get("start_id", _last_client_game_start_commit_id))
	var commit_start_kind = str(message.get("start_kind", "difficulty"))
	var commit_retry_context_key = str(_safe_dict_get(message.get("run_config", {}), "retry_context_key", message.get("retry_context_key", "")))
	_arm_client_battle_generation_fence(commit_start_id, commit_start_kind, commit_retry_context_key, "commit")
	var apply_msec = int(message.get("client_enter_msec", 0))
	if bool(message.get("wait_host_for_client_scene_ready", false)):
		apply_msec = now
	elif apply_msec <= 0:
		apply_msec = now + int(message.get("client_enter_delay_msec", 0))
	if not bool(message.get("wait_host_for_client_scene_ready", false)):
		apply_msec -= CLIENT_GAME_START_EARLY_MSEC
	if apply_msec < now:
		apply_msec = now
	_last_client_game_start_commit_id = int(message.get("start_id", _last_client_game_start_commit_id))
	_client_ignore_stale_menu_until_msec = now + CLIENT_STALE_MENU_GUARD_MSEC
	_notify_menu_sync_game_start_guard(_last_client_game_start_commit_id, "client_commit")
	_pending_client_game_start_commit = message.duplicate(true)
	_pending_client_game_start_apply_msec = apply_msec


func _poll_client_game_start_commit() -> void:
	if _pending_client_game_start_commit.empty():
		return
	if OS.get_ticks_msec() < _pending_client_game_start_apply_msec:
		return
	var commit = _pending_client_game_start_commit
	_pending_client_game_start_commit = {}
	_pending_client_game_start_apply_msec = 0
	_queue_client_game_start_commit_apply(commit)


func _queue_client_game_start_commit_apply(commit: Dictionary) -> void:
	_pending_client_game_start_deferred_commit = commit.duplicate(true)
	if _pending_client_game_start_deferred_call_queued:
		return
	_pending_client_game_start_deferred_call_queued = true
	call_deferred("_apply_queued_client_game_start_commit")


func _apply_queued_client_game_start_commit() -> void:
	_pending_client_game_start_deferred_call_queued = false
	if _pending_client_game_start_deferred_commit.empty():
		return
	var commit = _pending_client_game_start_deferred_commit
	_pending_client_game_start_deferred_commit = {}
	_apply_client_game_start_commit_now(commit)


func _apply_client_game_start_commit_now(commit: Dictionary) -> void:
	var menu_sync = _get_menu_sync_manager()
	if menu_sync == null or not menu_sync.has_method("receive_menu_scene_state_from_host"):
		return
	var state = {
		"msg_type": "menu_scene_state",
		"screen": "game",
		"scene_path": str(commit.get("scene_path", MenuData.game_scene)),
		"run_config": commit.get("run_config", {}),
		"force_scene_reload": bool(commit.get("force_scene_reload", false)),
		"game_start_sync": {
			"mode": str(commit.get("start_kind", "difficulty")) + "_commit",
			"start_id": int(commit.get("start_id", 0)),
			"difficulty": int(commit.get("difficulty", -1)),
			"host_enter_msec": int(commit.get("host_enter_msec", 0)),
			"client_enter_msec": int(commit.get("client_enter_msec", 0)),
			"rtt_msec": int(commit.get("rtt_msec", -1)),
			"offset_est_msec": commit.get("offset_est_msec", 0)
		}
	}
	_apply_host_zone_sync_for_client(state, "client_apply_commit_state")
	_client_last_game_scene_apply_msec = OS.get_ticks_msec()
	var old_scene = get_tree().current_scene
	_pending_client_game_scene_ready_requires_new_scene = bool(commit.get("force_scene_reload", false))
	_pending_client_game_scene_ready_old_scene_id = old_scene.get_instance_id() if _is_live_node(old_scene) else 0
	_notify_menu_sync_game_start_guard(int(commit.get("start_id", _last_client_game_start_commit_id)), "client_apply_commit")
	if bool(commit.get("force_scene_reload", false)):
		_reset_battle_transient_caches_for_scene_restart("client_force_game_reload")
	# The mirrored slot layout is already authoritative from lobby/selection staging.
	# Re-applying it here emits connected_players_updated during scene creation and can
	# recreate FocusEmulator/input ownership several times in one wave transition.
	menu_sync.receive_menu_scene_state_from_host(state, _self_steam_id, _get_game_host_steam_id())
	_pending_client_game_scene_ready_start_id = int(commit.get("start_id", 0))


func _poll_client_game_scene_ready() -> void:
	if _is_game_host() or _pending_client_game_scene_ready_start_id <= 0:
		return
	if _sent_client_game_scene_ready_start_id == _pending_client_game_scene_ready_start_id:
		_pending_client_game_scene_ready_start_id = 0
		_pending_client_game_scene_ready_requires_new_scene = false
		_pending_client_game_scene_ready_old_scene_id = 0
		return
	if not _is_in_game_scene():
		return
	if _pending_client_game_scene_ready_requires_new_scene:
		var current_scene = get_tree().current_scene
		var current_scene_id = current_scene.get_instance_id() if _is_live_node(current_scene) else 0
		if current_scene_id == _pending_client_game_scene_ready_old_scene_id:
			return
	_activate_client_battle_generation_for_send(_pending_client_game_scene_ready_start_id, _client_expected_battle_start_kind, _client_expected_retry_context_key, "scene_ready")
	_pending_client_game_scene_ready_requires_new_scene = false
	_pending_client_game_scene_ready_old_scene_id = 0
	var msg = {
		"msg_type": "client_game_scene_ready",
		"start_id": _pending_client_game_scene_ready_start_id,
		"client_ready_msec": OS.get_ticks_msec(),
		"scene": _current_scene_desc()
	}
	_sent_client_game_scene_ready_start_id = _pending_client_game_scene_ready_start_id
	_pending_client_game_scene_ready_start_id = 0
	send_menu_message_to_host(msg)


func _execute_pending_host_game_start() -> void:
	if _pending_host_game_start.empty():
		return
	var start_kind = str(_pending_host_game_start.get("start_kind", "difficulty"))
	var selection = _pending_host_game_start.get("selection", null)
	var element = _pending_host_game_start.get("element", null)
	var inventory_player_index = int(_pending_host_game_start.get("inventory_player_index", 0))
	var shop = _pending_host_game_start.get("shop", null)
	var shop_player_index = int(_pending_host_game_start.get("shop_player_index", 0))
	var start_id = int(_pending_host_game_start.get("start_id", 0))
	var difficulty_value = int(_pending_host_game_start.get("difficulty", -1))
	var run_config = _pending_host_game_start.get("run_config", {})
	var retry_context_key = str(_pending_host_game_start.get("retry_context_key", ""))
	if retry_context_key == "" and typeof(run_config) == TYPE_DICTIONARY:
		retry_context_key = str(run_config.get("retry_context_key", ""))
	_activate_host_battle_generation(start_id, start_kind, retry_context_key, "host_execute")
	_notify_menu_sync_game_start_guard(start_id, "host_execute:" + start_kind)
	_pending_host_game_start = {}
	_host_game_start_ack_by_steam_id.clear()
	_host_game_start_ready_by_steam_id.clear()
	_lock_online_run_slots("host_game_start_execute:" + start_kind)
	_sync_slot_manager_lock_flag()
	_last_battle_snapshot_send_msec = 0
	_last_battle_snapshot_sent_tick_by_steam_id.clear()
	_last_battle_reliable_sent_key_by_steam_id.clear()
	if start_kind == "retry_wave":
		_execute_host_retry_wave_scene_restart(start_id, run_config)
		return
	if start_kind == "shop":
		var menu_sync = _get_menu_sync_manager()
		if menu_sync != null and menu_sync.has_method("execute_synced_shop_game_start"):
			if menu_sync.execute_synced_shop_game_start(shop, shop_player_index):
				return
		if _is_live_node(shop) and shop.has_method("_on_GoButton_pressed"):
			shop._on_GoButton_pressed(shop_player_index)
		else:
			pass
		return
	_call_vanilla_difficulty_start(selection, element, inventory_player_index)
	_apply_host_wave_schedule_from_run_config(run_config)


func _call_vanilla_difficulty_start(selection, element, inventory_player_index: int) -> void:
	if _is_live_node(selection) and _is_live_node(element) and selection.has_method("_on_element_pressed"):
		selection._on_element_pressed(element, inventory_player_index)
	else:
		pass


func _get_difficulty_value_from_element(element) -> int:
	if not _is_live_node(element):
		return -1
	var item = null
	if element.has_method("get"):
		item = element.get("item")
	if item == null:
		return -1
	if item.has_method("get"):
		return int(item.get("value"))
	return -1


func _poll_direct_upgrade_action_sync() -> void:
	if _lobby_id == 0:
		_direct_upgrade_ui_instance_id = 0
		_direct_upgrade_local_actions.clear()
		_direct_upgrade_pending_remote_actions.clear()
		return
	# 普通商店页没有 CoopUpgradesUI，不能每帧递归扫整棵商店 UI。
	# 升级页仍通过 main.tscn 的 UI/CoopUpgradesUI 直连路径处理。
	if _is_in_shop_scene():
		_direct_upgrade_ui_instance_id = 0
		_prune_direct_upgrade_state(false)
		return

	var upgrade_ui = _get_active_coop_upgrades_ui()
	if not _is_live_node(upgrade_ui):
		_direct_upgrade_ui_instance_id = 0
		_prune_direct_upgrade_state(false)
		return

	_connect_direct_upgrade_ui_signals(upgrade_ui)
	_process_pending_direct_upgrade_actions(upgrade_ui)
	_send_pending_local_direct_upgrade_actions(upgrade_ui)
	_prune_direct_upgrade_state(true)


func _get_active_coop_upgrades_ui() -> Node:
	if _is_in_shop_scene():
		return null
	var current = get_tree().current_scene
	if current == null:
		return null
	var upgrade_ui = null
	if current.has_node("UI/CoopUpgradesUI"):
		# main.tscn always contains CoopUpgradesUI at this direct path.
		# Do not fall back to recursive scene-tree scans while the wave/battle scene is active.
		upgrade_ui = current.get_node("UI/CoopUpgradesUI")
	elif not _is_in_game_scene():
		upgrade_ui = _find_node_recursive(current, "CoopUpgradesUI")
	else:
		return null
	if not _is_live_node(upgrade_ui):
		return null
	if upgrade_ui.has_method("is_visible_in_tree") and not upgrade_ui.is_visible_in_tree():
		return null
	return upgrade_ui


func _connect_direct_upgrade_ui_signals(upgrade_ui: Node) -> void:
	if not _is_live_node(upgrade_ui):
		return
	var instance_id = upgrade_ui.get_instance_id()
	if _direct_upgrade_ui_instance_id == instance_id:
		return
	_direct_upgrade_ui_instance_id = instance_id
	if upgrade_ui.has_signal("upgrade_selected") and not upgrade_ui.is_connected("upgrade_selected", self, "_on_direct_upgrade_ui_upgrade_selected"):
		upgrade_ui.connect("upgrade_selected", self, "_on_direct_upgrade_ui_upgrade_selected")


func _on_direct_upgrade_ui_upgrade_selected(upgrade_data, upgrade) -> void:
	if _direct_upgrade_apply_guard:
		return
	if _lobby_id == 0 or upgrade_data == null or not is_instance_valid(upgrade_data) or upgrade == null:
		return
	if not RunData.is_coop_run:
		return

	var action = _build_direct_upgrade_action(upgrade_data, upgrade)
	if action.empty():
		return

	var now = OS.get_ticks_msec()
	_direct_upgrade_local_actions[str(action.get("action_id", ""))] = {
		"message": action,
		"first_send_msec": now + UPGRADE_DIRECT_FALLBACK_FIRST_SEND_MSEC,
		"last_send_msec": 0,
		"expires_msec": now + UPGRADE_DIRECT_FALLBACK_TTL_MSEC
	}


func _build_direct_upgrade_action(upgrade_data, upgrade) -> Dictionary:
	_direct_upgrade_action_seq += 1
	var action_id = _self_steam_id + ":upgrade_direct:" + str(_direct_upgrade_action_seq)
	var upgrade_id = str(upgrade_data.upgrade_id)
	var my_id = str(upgrade_data.my_id)
	var upgrade_id_hash = int(upgrade_data.upgrade_id_hash)
	var my_id_hash = int(upgrade_data.my_id_hash)
	if upgrade_id_hash == 0 and upgrade_id != "":
		upgrade_id_hash = int(Keys.generate_hash(upgrade_id))
	if my_id_hash == 0 and my_id != "":
		my_id_hash = int(Keys.generate_hash(my_id))

	return {
		"msg_type": "upgrade_direct_action",
		"action_id": action_id,
		"origin_steam_id": _self_steam_id,
		"current_wave": int(RunData.current_wave),
		"player_index": int(upgrade.player_index),
		"level": int(upgrade.level),
		"upgrade_id": upgrade_id,
		"upgrade_id_hash": upgrade_id_hash,
		"my_id": my_id,
		"my_id_hash": my_id_hash,
		"tier": int(upgrade_data.tier),
		"resource_path": str(upgrade_data.resource_path),
		"created_msec": OS.get_ticks_msec()
	}


func _send_pending_local_direct_upgrade_actions(upgrade_ui: Node) -> void:
	if not _is_live_node(upgrade_ui):
		return
	var now = OS.get_ticks_msec()
	for action_id in _direct_upgrade_local_actions.keys():
		var record = _direct_upgrade_local_actions.get(action_id, {})
		if typeof(record) != TYPE_DICTIONARY:
			_direct_upgrade_local_actions.erase(action_id)
			continue
		if now > int(record.get("expires_msec", 0)):
			_direct_upgrade_local_actions.erase(action_id)
			continue
		if now < int(record.get("first_send_msec", 0)):
			continue
		var last_send = int(record.get("last_send_msec", 0))
		if last_send > 0 and now - last_send < UPGRADE_DIRECT_FALLBACK_RESEND_MSEC:
			continue
		var message = record.get("message", {})
		if typeof(message) != TYPE_DICTIONARY or message.empty():
			_direct_upgrade_local_actions.erase(action_id)
			continue
		_send_or_broadcast_direct_upgrade_action(message)
		record["last_send_msec"] = now
		_direct_upgrade_local_actions[action_id] = record


func _send_or_broadcast_direct_upgrade_action(message: Dictionary) -> void:
	if _is_game_host():
		_broadcast_direct_upgrade_action(message, "")
	else:
		send_menu_message_to_host(message)


func _broadcast_direct_upgrade_action(message: Dictionary, except_steam_id: String = "") -> void:
	if not _is_game_host() or _lobby_id == 0:
		return
	for member in _members:
		var steam_id = str(member.get("steam_id", ""))
		if steam_id == "" or steam_id == _self_steam_id:
			continue
		if except_steam_id != "" and steam_id == except_steam_id:
			continue
		_send_p2p_json(steam_id, message, true)


func _handle_upgrade_direct_action(from_steam_id: String, message: Dictionary) -> void:
	var action_id = str(message.get("action_id", ""))
	if action_id == "":
		action_id = from_steam_id + ":upgrade_direct_missing_id:" + str(message.get("player_index", -1)) + ":" + str(message.get("level", -1)) + ":" + str(message.get("my_id", ""))
		message["action_id"] = action_id

	if _direct_upgrade_seen_action_ids.has(action_id):
		return
	_direct_upgrade_seen_action_ids[action_id] = OS.get_ticks_msec()

	if _is_game_host():
		if str(message.get("origin_steam_id", "")) == "":
			message["origin_steam_id"] = from_steam_id
		var host_applied = _try_apply_direct_upgrade_action(message)
		if host_applied:
			_broadcast_direct_upgrade_action(message, "")
		else:
			_queue_pending_direct_upgrade_action(message)
		return

	var host_id = _get_game_host_steam_id()
	if host_id != "" and from_steam_id != host_id:
		return

	# Own echo means the Host has seen the action. The local UI already executed it.
	if str(message.get("origin_steam_id", "")) == _self_steam_id:
		return

	if not _try_apply_direct_upgrade_action(message):
		_queue_pending_direct_upgrade_action(message)


func _queue_pending_direct_upgrade_action(message: Dictionary) -> void:
	var action_id = str(message.get("action_id", ""))
	for existing in _direct_upgrade_pending_remote_actions:
		if typeof(existing) == TYPE_DICTIONARY and str(existing.get("action_id", "")) == action_id:
			return
	var pending = message.duplicate(true)
	pending["pending_since_msec"] = OS.get_ticks_msec()
	_direct_upgrade_pending_remote_actions.append(pending)


func _process_pending_direct_upgrade_actions(upgrade_ui: Node) -> void:
	if _direct_upgrade_pending_remote_actions.empty():
		return
	var now = OS.get_ticks_msec()
	var remaining = []
	for pending in _direct_upgrade_pending_remote_actions:
		if typeof(pending) != TYPE_DICTIONARY:
			continue
		if now - int(pending.get("pending_since_msec", now)) > UPGRADE_DIRECT_PENDING_TTL_MSEC:
			continue
		var applied = _try_apply_direct_upgrade_action(pending)
		if applied:
			if _is_game_host():
				_broadcast_direct_upgrade_action(pending, "")
		else:
			remaining.append(pending)
	_direct_upgrade_pending_remote_actions = remaining


func _try_apply_direct_upgrade_action(message: Dictionary) -> bool:
	var upgrade_ui = _get_active_coop_upgrades_ui()
	if not _is_live_node(upgrade_ui):
		return false
	if not RunData.is_coop_run:
		return true
	if int(message.get("current_wave", RunData.current_wave)) != int(RunData.current_wave):
		return true

	var player_index = int(message.get("player_index", -1))
	if player_index < 0 or player_index >= int(RunData.get_player_count()):
		return true

	var choosing = upgrade_ui.get("_player_is_choosing")
	if typeof(choosing) == TYPE_ARRAY and player_index < choosing.size():
		if not bool(choosing[player_index]):
			return true

	var upgrade_data = _find_visible_upgrade_data_for_direct_action(upgrade_ui, player_index, message)
	if upgrade_data == null:
		return false

	_direct_upgrade_apply_guard = true
	upgrade_ui.call("_on_choose_button_pressed", upgrade_data, player_index)
	_direct_upgrade_apply_guard = false
	return true


func _find_visible_upgrade_data_for_direct_action(upgrade_ui: Node, player_index: int, message: Dictionary):
	if not _is_live_node(upgrade_ui) or not upgrade_ui.has_method("_get_player_container"):
		return null
	var player_container = upgrade_ui.call("_get_player_container", player_index)
	if not _is_live_node(player_container) or not player_container.has_method("_get_upgrade_uis"):
		return null
	var upgrade_uis = player_container.call("_get_upgrade_uis")
	if typeof(upgrade_uis) != TYPE_ARRAY:
		return null
	for upgrade_ui_node in upgrade_uis:
		if not _is_live_node(upgrade_ui_node):
			continue
		if upgrade_ui_node.has_method("is_visible_in_tree") and not upgrade_ui_node.is_visible_in_tree():
			continue
		var data = upgrade_ui_node.get("upgrade_data")
		if data != null and _upgrade_data_matches_direct_action(data, message):
			return data
	return null


func _upgrade_data_matches_direct_action(data, message: Dictionary) -> bool:
	var msg_path = str(message.get("resource_path", ""))
	if msg_path != "" and str(data.resource_path) == msg_path:
		return true

	var msg_my_id = str(message.get("my_id", ""))
	if msg_my_id != "" and str(data.my_id) == msg_my_id:
		return true

	var msg_my_hash = int(message.get("my_id_hash", 0))
	var data_my_hash = int(data.my_id_hash)
	if data_my_hash == 0 and str(data.my_id) != "":
		data_my_hash = int(Keys.generate_hash(str(data.my_id)))
	if msg_my_hash != 0 and data_my_hash == msg_my_hash:
		return true

	return false


func _prune_direct_upgrade_state(upgrade_ui_active: bool) -> void:
	var now = OS.get_ticks_msec()
	if not upgrade_ui_active:
		_direct_upgrade_local_actions.clear()
		return
	if now - _direct_upgrade_last_prune_msec < 1500:
		return
	_direct_upgrade_last_prune_msec = now
	for action_id in _direct_upgrade_local_actions.keys():
		var record = _direct_upgrade_local_actions.get(action_id, {})
		if typeof(record) != TYPE_DICTIONARY or now > int(record.get("expires_msec", 0)):
			_direct_upgrade_local_actions.erase(action_id)
	for action_id in _direct_upgrade_seen_action_ids.keys():
		var seen_msec = int(_direct_upgrade_seen_action_ids.get(action_id, 0))
		if seen_msec <= 0 or now - seen_msec > 30000:
			_direct_upgrade_seen_action_ids.erase(action_id)


func _is_in_difficulty_selection_scene() -> bool:
	var current = get_tree().current_scene
	if current == null:
		return false
	return str(current.filename) == MenuData.difficulty_selection_scene or str(current.filename).find("difficulty_selection") != -1


func _is_live_node(value) -> bool:
	if value == null or typeof(value) != TYPE_OBJECT:
		return false
	return is_instance_valid(value) and value is Node and not value.is_queued_for_deletion()


func _safe_node_contains(parent, child) -> bool:
	if not _is_live_node(parent) or not _is_live_node(child):
		return false
	if not (parent is Node) or not (child is Node):
		return false
	if parent == child:
		return true
	return parent.is_a_parent_of(child)


func _get_gui_focus_owner_safe(anchor: Node = null) -> Node:
	# Prefer Control.get_focus_owner(), matching vanilla FocusEmulator usage.
	# Fall back to Viewport.gui_get_focus_owner() for custom Godot builds.
	if _is_live_node(anchor) and anchor.has_method("get_focus_owner"):
		var owner = anchor.get_focus_owner()
		if _is_live_node(owner) and owner is Node:
			return owner
	var viewport = get_viewport()
	if viewport != null and is_instance_valid(viewport) and viewport.has_method("gui_get_focus_owner"):
		var viewport_owner = viewport.gui_get_focus_owner()
		if _is_live_node(viewport_owner) and viewport_owner is Node:
			return viewport_owner
	return null


func _get_host_terminal_state() -> Dictionary:
	if not _is_game_host() or not _is_in_game_scene():
		return {}
	var main = get_tree().current_scene
	if not _is_live_node(main):
		return {}
	var retry_visible = false
	var retry_wave = main.get("_retry_wave")
	if _is_live_node(retry_wave) and retry_wave is CanvasItem and retry_wave.visible:
		retry_visible = true
	var retry_node = main.get_node_or_null("UI/RetryWave")
	if _is_live_node(retry_node) and retry_node is CanvasItem and retry_node.visible:
		retry_visible = true
	var wave_failed = bool(main.get("_is_wave_failed"))
	var run_lost = bool(main.get("_is_run_lost"))
	var run_won = bool(main.get("_is_run_won"))
	# Host stops normal battle_snapshot while Main is in terminal cleanup. Failure was
	# already sent through battle_terminal_state; final-wave boss kill also reaches
	# _is_run_won before WaveTimer reaches 0, so it must be terminal-synced too.
	if not wave_failed and not run_lost and not retry_visible and not run_won:
		return {}
	return {
		"wave_failed": wave_failed or retry_visible,
		"run_lost": run_lost,
		"run_won": run_won,
		"retry_visible": retry_visible,
		"cleaning_up": bool(main.get("_cleaning_up"))
	}


func _poll_and_send_host_battle_terminal_state() -> void:
	if not _is_game_host() or _lobby_id == 0 or not _is_in_game_scene():
		return
	if _is_host_retry_battle_send_warmup_blocked():
		return
	var now = OS.get_ticks_msec()
	if now < _host_retry_terminal_suppress_until_msec:
		var current_scene = get_tree().current_scene
		var current_scene_id = current_scene.get_instance_id() if _is_live_node(current_scene) else 0
		if _host_retry_terminal_suppress_scene_id <= 0 or current_scene_id == _host_retry_terminal_suppress_scene_id:
			return
		_host_retry_terminal_suppress_until_msec = 0
		_host_retry_terminal_suppress_scene_id = 0
		_host_retry_battle_send_min_until_msec = 0
		_host_retry_battle_send_deadline_msec = 0
		_host_retry_battle_send_old_scene_id = 0
	if not _pending_host_game_start.empty() and str(_pending_host_game_start.get("start_kind", "")) == "retry_wave":
		return
	if _host_retry_first_snapshot_needs_gate():
		return
	var terminal = _get_host_terminal_state()
	if terminal.empty():
		return
	var remote_ids = _get_remote_ids_for_host_sync()
	if remote_ids.empty():
		return

	var snapshot = {}
	var snapshot_manager = _get_state_snapshot_manager()
	if snapshot_manager != null and snapshot_manager.has_method("build_snapshot"):
		# Build one fresh terminal sample. Normal battle_snapshot is intentionally
		# suppressed in this state, so get_last_snapshot_message() can be one frame stale
		# exactly when Host dies.
		snapshot = snapshot_manager.build_snapshot()
	if (typeof(snapshot) != TYPE_DICTIONARY or snapshot.empty()) and snapshot_manager != null and snapshot_manager.has_method("get_last_snapshot_message"):
		snapshot = snapshot_manager.get_last_snapshot_message()
	if typeof(snapshot) != TYPE_DICTIONARY:
		snapshot = {}

	var msg = _make_battle_terminal_state_message(snapshot, terminal)
	var key = _make_battle_terminal_state_key(msg)
	for steam_id_value in remote_ids:
		var steam_id = str(steam_id_value)
		if steam_id == "" or steam_id == _self_steam_id:
			continue
		var last_key = str(_last_battle_terminal_state_key_by_steam_id.get(steam_id, ""))
		var last_msec = int(_last_battle_terminal_state_msec_by_steam_id.get(steam_id, 0))
		if last_key == key and last_msec > 0 and now - last_msec < BATTLE_TERMINAL_STATE_RESEND_MSEC:
			continue
		var ok = _send_p2p_json(steam_id, msg, true)
		_last_battle_terminal_state_key_by_steam_id[steam_id] = key
		_last_battle_terminal_state_msec_by_steam_id[steam_id] = now


func _make_battle_terminal_state_key(msg: Dictionary) -> String:
	var parts = [
		str(msg.get("battle_start_id", msg.get("bs", 0))),
		str(msg.get("battle_start_kind", "")),
		str(msg.get("battle_retry_context_key", "")),
		str(msg.get("wave", RunData.current_wave)),
		str(msg.get("r", RunData.retries)),
		str(int(bool(msg.get("wave_failed", false)))),
		str(int(bool(msg.get("run_lost", false)))),
		str(int(bool(msg.get("run_won", false)))),
		str(int(bool(msg.get("retry_visible", false))))
	]
	var players = msg.get("players", [])
	if typeof(players) == TYPE_ARRAY:
		for p in players:
			if typeof(p) != TYPE_DICTIONARY:
				continue
			parts.append(str(p.get("player_index", -1)) + ":" + str(p.get("health", -1)) + ":" + str(int(bool(p.get("dead", false)))) + ":" + str(p.get("hit_protection", -1)))
	return "|".join(parts)


func _make_battle_terminal_state_message(snapshot: Dictionary, terminal: Dictionary) -> Dictionary:
	var now = OS.get_ticks_msec()
	var players = _make_terminal_players(snapshot, terminal)
	var wave_state = snapshot.get("wave_timer_state", {})
	if typeof(wave_state) != TYPE_DICTIONARY:
		wave_state = {}
	else:
		wave_state = wave_state.duplicate(true)
	wave_state["wave"] = int(RunData.current_wave)
	wave_state["time_left"] = 0.0
	wave_state["running"] = false
	wave_state["server_time_msec"] = now
	if not wave_state.has("wait_time"):
		wave_state["wait_time"] = 0.0
	return {
		"msg_type": "battle_terminal_state",
		"phase": "B14_host_terminal_state",
		"battle_start_id": int(_host_current_battle_start_id),
		"bs": int(_host_current_battle_start_id),
		"battle_start_kind": str(_host_current_battle_start_kind),
		"battle_retry_context_key": str(_host_current_retry_context_key),
		"r": int(RunData.retries),
		"retries": int(RunData.retries),
		"tick": max(1, int(snapshot.get("tick", 0))),
		"scene_instance_id": int(snapshot.get("scene_instance_id", 0)),
		"sid": int(snapshot.get("scene_instance_id", 0)),
		"time_msec": now,
		"server_time_msec": now,
		"wave": int(RunData.current_wave),
		"player_count": int(RunData.get_player_count()),
		"players": players,
		"wave_timer_state": wave_state,
		"progression_state": {},
		"events": [],
		"removed": [],
		"prune_missing": false,
		"terminal": true,
		"wave_failed": bool(terminal.get("wave_failed", false)),
		"run_lost": bool(terminal.get("run_lost", false)),
		"run_won": bool(terminal.get("run_won", false)),
		"retry_visible": bool(terminal.get("retry_visible", false)),
		"cleaning_up": bool(terminal.get("cleaning_up", false))
	}


func _make_terminal_players(snapshot: Dictionary, terminal: Dictionary) -> Array:
	var result = []
	var force_dead = bool(terminal.get("wave_failed", false)) or bool(terminal.get("run_lost", false)) or bool(terminal.get("retry_visible", false))
	var players = snapshot.get("players", [])
	if typeof(players) == TYPE_ARRAY:
		for p in players:
			if typeof(p) != TYPE_DICTIONARY:
				continue
			var state = p.duplicate(true)
			# If Host has already entered failure/RetryWave, Main._set_run_states()
			# has determined all players are dead. Force HP=0 here so clients cannot
			# keep an old alive proxy and advance to upgrade/shop. For run_won, preserve
			# real player HP; final-wave victory should not look like a death packet.
			if force_dead:
				state["dead"] = true
				state["health"] = 0
			result.append(state)
	var expected_count = int(RunData.get_player_count())
	var seen_indices = {}
	for existing in result:
		if typeof(existing) == TYPE_DICTIONARY:
			seen_indices[int(existing.get("player_index", -1))] = true
	for i in range(expected_count):
		if seen_indices.has(i):
			continue
		result.append({
			"net_id": "player_%s" % str(i),
			"player_index": i,
			"pos": {"x": 0.0, "y": 0.0},
			"vel": {"x": 0.0, "y": 0.0},
			"dead": force_dead,
			"health": 0 if force_dead else -1,
			"max_health": -1,
			"hit_protection": 0
		})
	return result


func _poll_and_send_host_battle_snapshot() -> void:
	if not _is_game_host() or _lobby_id == 0:
		return
	if not _is_in_game_scene():
		return
	if _is_host_retry_battle_send_warmup_blocked():
		return
	if _host_retry_first_snapshot_needs_gate() and not _host_retry_first_snapshot_gate_pending():
		_ensure_host_retry_first_snapshot_gate_armed(int(_host_current_battle_start_id), "send_loop_missing_gate", false, 0)
		return
	if not _pending_host_game_start.empty() and str(_pending_host_game_start.get("start_kind", "")) == "retry_wave":
		return
	if _is_host_main_terminal_or_retry_state():
		# Failure/RetryWave stops normal battle_snapshot so stale stopped-timer snapshots
		# cannot leak into the next retry. Send a small reliable terminal packet first;
		# player death and failed-wave UI must not depend on normal snapshots here.
		_poll_and_send_host_battle_terminal_state()
		return

	var now = OS.get_ticks_msec()
	if now - _last_battle_snapshot_send_msec < BATTLE_SNAPSHOT_SEND_INTERVAL_MSEC:
		return
	_last_battle_snapshot_send_msec = now

	var snapshot_manager = _get_state_snapshot_manager()
	if snapshot_manager == null or not snapshot_manager.has_method("get_last_snapshot_message"):
		return

	var snapshot = snapshot_manager.get_last_snapshot_message()
	if _host_retry_first_snapshot_needs_gate():
		# get_last_snapshot_message() is a cache. During RetryWave scene reload it can still
		# contain the previous failed Main sample. Force one current-scene sample before
		# allowing the new battle generation to start sending.
		if snapshot_manager.has_method("force_fresh_snapshot_message"):
			snapshot = snapshot_manager.force_fresh_snapshot_message()
		elif snapshot_manager.has_method("build_snapshot"):
			snapshot = snapshot_manager.build_snapshot()
	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.empty():
		return

	var tick = int(snapshot.get("tick", 0))
	if tick <= 0:
		return
	if not _host_retry_allow_first_fresh_snapshot(snapshot):
		return

	var remote_ids = _get_remote_ids_for_host_sync()
	if remote_ids.empty():
		return

	var wire_snapshot = _make_battle_snapshot_wire_message(snapshot)
	var pending_reliable = {}
	if snapshot_manager.has_method("peek_pending_battle_reliable_events_for_send"):
		pending_reliable = snapshot_manager.peek_pending_battle_reliable_events_for_send()
	var reliable_msg = _make_battle_reliable_events_message(snapshot, pending_reliable)
	var reliable_needed = not _battle_reliable_events_empty(reliable_msg)
	var reliable_attempted = false
	var reliable_all_ok = true
	for steam_id_value in remote_ids:
		var steam_id = str(steam_id_value)
		if steam_id == "" or steam_id == _self_steam_id:
			continue

		# Reliable one-shot events are now pending-queue based, not tied to the
		# continuous snapshot tick. Send them before the tick de-dupe so a cached
		# snapshot cannot starve births/removals/death events. If any peer fails,
		# keep the whole batch pending and retry next send interval; clients de-dupe
		# by net_id/event_id.
		if reliable_needed:
			reliable_attempted = true
			var reliable_ok = _send_p2p_json(steam_id, reliable_msg, true)
			if not reliable_ok:
				reliable_all_ok = false

		var last_tick = int(_last_battle_snapshot_sent_tick_by_steam_id.get(steam_id, -1))
		if last_tick == tick:
			continue
		_last_battle_snapshot_sent_tick_by_steam_id[steam_id] = tick

		# experimental; it can reduce remote-player drift at the cost of possible backlog.
		var ok = _send_p2p_json(steam_id, wire_snapshot, true)
		_maybe_log_battle_snapshot_tx(steam_id, wire_snapshot, ok)
	if reliable_needed and reliable_attempted and reliable_all_ok and snapshot_manager.has_method("mark_battle_reliable_events_sent"):
		snapshot_manager.mark_battle_reliable_events_sent(reliable_msg)


func _maybe_log_battle_snapshot_tx(target_steam_id: String, snapshot: Dictionary, ok: bool) -> void:
	var now = OS.get_ticks_msec()
	var compact = _safe_bool(snapshot.get("compact", false))
	var entity_count = _safe_array_size(snapshot.get("e", [])) if compact else _safe_array_size(snapshot.get("entities", []))
	var event_count = _safe_array_size(snapshot.get("events", []))
	var player_count = _safe_array_size(snapshot.get("p", [])) if compact else _safe_array_size(snapshot.get("players", []))
	if ok and now - _last_battle_snapshot_tx_log_msec < 5000:
		return
	_last_battle_snapshot_tx_log_msec = now
	var payload_size = to_json(snapshot).to_utf8().size()


func _make_battle_reliable_events_message(snapshot: Dictionary, pending_reliable: Dictionary) -> Dictionary:
	var reliable_entities = []
	var births = pending_reliable.get("entities", [])
	if typeof(births) == TYPE_ARRAY:
		for entity in births:
			if typeof(entity) == TYPE_DICTIONARY:
				reliable_entities.append(_make_wire_entity_state(entity, false))

	var reliable_birth_markers = []
	var birth_markers = pending_reliable.get("births", [])
	if typeof(birth_markers) == TYPE_ARRAY:
		for birth in birth_markers:
			if typeof(birth) == TYPE_DICTIONARY:
				reliable_birth_markers.append(birth.duplicate(true))

	for state in reliable_entities:
		if typeof(state) == TYPE_DICTIONARY and str(state.get("category", "")) == "structure":
			pass
	for birth in reliable_birth_markers:
		if typeof(birth) == TYPE_DICTIONARY and str(birth.get("spawn_category", birth.get("category", ""))) == "structure":
			pass

	var death_events = []
	var events = pending_reliable.get("events", snapshot.get("events", []))
	if ENABLE_DEATH_EVENT_MESSAGES and typeof(events) == TYPE_ARRAY:
		for event in events:
			if typeof(event) == TYPE_DICTIONARY and str(event.get("event_type", "")) == "death_event":
				death_events.append(event)

	return {
		"msg_type": "battle_reliable_events",
		"phase": str(snapshot.get("phase", "B12_delayed_death_sync")),
		"battle_start_id": int(_host_current_battle_start_id),
		"bs": int(_host_current_battle_start_id),
		"battle_start_kind": str(_host_current_battle_start_kind),
		"battle_retry_context_key": str(_host_current_retry_context_key),
		"r": int(RunData.retries),
		"tick": int(snapshot.get("tick", 0)),
		"scene_instance_id": int(snapshot.get("scene_instance_id", 0)),
		"sid": int(snapshot.get("scene_instance_id", 0)),
		"time_msec": int(snapshot.get("time_msec", 0)),
		"server_time_msec": int(snapshot.get("server_time_msec", snapshot.get("time_msec", 0))),
		"entities": reliable_entities,
		"births": reliable_birth_markers,
		"removed": pending_reliable.get("removed", snapshot.get("removed", [])),
		"events": death_events
	}


func _battle_reliable_events_empty(message: Dictionary) -> bool:
	if typeof(message) != TYPE_DICTIONARY or message.empty():
		return true
	return _safe_array_size(message.get("entities", [])) <= 0 and _safe_array_size(message.get("births", [])) <= 0 and _safe_array_size(message.get("removed", [])) <= 0 and _safe_array_size(message.get("events", [])) <= 0


func _make_battle_snapshot_wire_message(snapshot: Dictionary) -> Dictionary:
	# Compact continuous state packet. battle_reliable_events carries one-shot
	# creation/removal/death/birth-warning events. Keep this packet small and never
	# repeat active birth markers here; repeating them every 120ms bloats reliable
	# queues and can make Steam P2P stall on later waves.
	return {
		"msg_type": "battle_snapshot",
		"compact": true,
		"phase": str(snapshot.get("phase", "B13_compact_unreliable_state")),
		"battle_start_id": int(_host_current_battle_start_id),
		"bs": int(_host_current_battle_start_id),
		"battle_start_kind": str(_host_current_battle_start_kind),
		"battle_retry_context_key": str(_host_current_retry_context_key),
		"r": int(RunData.retries),
		"t": int(snapshot.get("tick", 0)),
		"sid": int(snapshot.get("scene_instance_id", 0)),
		"m": int(snapshot.get("time_msec", 0)),
		"s": int(snapshot.get("server_time_msec", snapshot.get("time_msec", 0))),
		"pc": int(snapshot.get("player_count", 0)),
		"p": _compact_players(snapshot),
		"e": _compact_host_motion_entities(snapshot),
		"w": _compact_wave_timer_state(snapshot),
		"ec": _compact_economy_state(snapshot),
		"pr": _make_wire_progression_state(snapshot)
	}


func _compact_players(snapshot: Dictionary) -> Array:
	var result = []
	var players = snapshot.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return result
	for player in players:
		if typeof(player) != TYPE_DICTIONARY:
			continue
		var pos = _dict_to_xy(player.get("pos", {}))
		var vel = _dict_to_xy(player.get("vel", {}))
		result.append([
			int(player.get("player_index", -1)),
			pos[0], pos[1],
			vel[0], vel[1],
			1 if ENABLE_DEATH_EVENT_MESSAGES and _safe_bool(player.get("dead", false)) else 0,
			int(player.get("health", -1)),
			int(player.get("max_health", -1)),
			int(player.get("hit_protection", -1))
		])
	return result


func _compact_host_motion_entities(snapshot: Dictionary) -> Array:
	var result = []
	var entities = snapshot.get("entities", [])
	if typeof(entities) != TYPE_ARRAY:
		return result
	for entity in entities:
		if typeof(entity) != TYPE_DICTIONARY:
			continue
		var sync_mode = str(entity.get("sync_mode", ""))
		var category = str(entity.get("category", ""))
		# Birth-only entity creation is reliable and one-shot. Keep unreliable state for
		# boss/elite and pet motion only. Structures are static birth-only.
		if sync_mode != "host_motion" and category != "boss" and category != "pet":
			continue
		var pos = _dict_to_xy(entity.get("pos", {}))
		var vel = _dict_to_xy(entity.get("vel", {}))
		var flags = entity.get("status_flags", {})
		var cursed = false
		if typeof(flags) == TYPE_DICTIONARY:
			cursed = _safe_bool(flags.get("cursed", false))
		result.append([
			str(entity.get("net_id", "")),
			_category_to_compact_id(category),
			int(entity.get("entity_type", -1)),
			pos[0], pos[1],
			vel[0], vel[1],
			1 if ENABLE_DEATH_EVENT_MESSAGES and _safe_bool(entity.get("dead", false)) else 0,
			int(entity.get("health", -1)),
			int(entity.get("max_health", -1)),
			int(entity.get("speed", -1)),
			int(entity.get("damage", -1)),
			int(entity.get("armor", -1)),
			1 if cursed else 0,
			int(entity.get("player_index", -1))
		])
	return result

func _compact_wave_timer_state(snapshot: Dictionary) -> Array:
	var state = snapshot.get("wave_timer_state", {})
	if typeof(state) != TYPE_DICTIONARY:
		return []
	return [
		int(state.get("wave", snapshot.get("wave", 0))),
		float(state.get("wait_time", 0.0)),
		float(state.get("time_left", 0.0)),
		int(state.get("server_time_msec", snapshot.get("server_time_msec", snapshot.get("time_msec", 0)))),
		1 if _safe_bool(state.get("running", false)) else 0
	]


func _compact_economy_state(snapshot: Dictionary) -> Array:
	var economy = snapshot.get("economy_state", {})
	if typeof(economy) != TYPE_DICTIONARY:
		return []
	var result_players = []
	var players = economy.get("players", [])
	if typeof(players) == TYPE_ARRAY:
		for p in players:
			if typeof(p) != TYPE_DICTIONARY:
				continue
			result_players.append([
				int(p.get("player_index", -1)),
				int(p.get("materials", p.get("gold", 0))),
				int(p.get("gold", p.get("materials", 0))),
				float(p.get("xp", 0.0)),
				int(p.get("level", 0)),
				float(p.get("next_level_xp", 0.0)),
				int(p.get("hp", -1)),
				int(p.get("max_hp", -1))
			])
	return [int(economy.get("server_time_msec", snapshot.get("server_time_msec", 0))), result_players]


func _dict_to_xy(value) -> Array:
	if typeof(value) != TYPE_DICTIONARY:
		return [0, 0]
	return [int(round(float(value.get("x", 0.0)))), int(round(float(value.get("y", 0.0))))]


func _xy_to_dict(x, y) -> Dictionary:
	return {"x": float(x), "y": float(y)}


func _category_to_compact_id(category: String) -> int:
	match category:
		"enemy":
			return 0
		"boss":
			return 1
		"neutral":
			return 2
		"structure":
			return 3
		"pet":
			return 4
		"birth":
			return 5
		_:
			return -1


func _compact_id_to_category(category_id: int) -> String:
	match category_id:
		0:
			return "enemy"
		1:
			return "boss"
		2:
			return "neutral"
		3:
			return "structure"
		4:
			return "pet"
		5:
			return "birth"
		_:
			return ""

func _make_wire_progression_state(snapshot: Dictionary) -> Dictionary:
	var state = snapshot.get("progression_state", {})
	if typeof(state) != TYPE_DICTIONARY:
		return {}
	# Already compact: only ids/resource paths plus the currently visible Host-generated options.
	return state.duplicate(true)

func _make_wire_entity_state(entity: Dictionary, legacy_enemy: bool) -> Dictionary:
	var result = {
		"net_id": str(entity.get("net_id", "")),
		"pos": entity.get("pos", {}),
		"vel": entity.get("vel", {}),
		"dead": ENABLE_DEATH_EVENT_MESSAGES and _safe_bool(entity.get("dead", false)),
		"health": int(entity.get("health", -1)),
		"max_health": int(entity.get("max_health", -1)),
		"speed": int(entity.get("speed", -1)),
		"damage": int(entity.get("damage", -1)),
		"armor": int(entity.get("armor", -1)),
		"status_flags": entity.get("status_flags", {})
	}
	if not legacy_enemy:
		result["category"] = str(entity.get("category", ""))
		result["sync_mode"] = str(entity.get("sync_mode", ""))
		result["entity_type"] = int(entity.get("entity_type", -1))
		result["scene_path"] = str(entity.get("scene_path", ""))
		result["type_path"] = str(entity.get("type_path", ""))
		result["stats_path"] = str(entity.get("stats_path", ""))
		# Structure/pet/odd spawn data is needed by the Client spawner.
		# Keep both the original data_path and the runtime spawn_data payload:
		# cursed structure/pet resources are duplicated at runtime, so data_path
		# alone reloads the uncursed .tres and loses is_cursed/curse_factor/value.
		result["data_path"] = str(entity.get("data_path", ""))
		var spawn_data = entity.get("spawn_data", {})
		if typeof(spawn_data) == TYPE_DICTIONARY and not spawn_data.empty():
			result["spawn_data"] = spawn_data.duplicate(true)
		var online_drop_result = entity.get("online_drop_result", {})
		if typeof(online_drop_result) == TYPE_DICTIONARY and not online_drop_result.empty():
			result["online_drop_result"] = online_drop_result.duplicate(true)
		result["player_index"] = int(entity.get("player_index", -1))
	else:
		# B-2 fallback consumers can still use enemies as before, but scene_path is
		# included when available so mixed files can still recover.
		result["category"] = str(entity.get("category", "enemy"))
		result["entity_type"] = int(entity.get("entity_type", -1))
		result["scene_path"] = str(entity.get("scene_path", ""))
	return result


func _expand_compact_battle_snapshot(message: Dictionary) -> Dictionary:
	if typeof(message) != TYPE_DICTIONARY or message.empty():
		return {}
	var server_time_msec = int(message.get("s", message.get("m", 0)))
	var expanded = {
		"msg_type": "battle_snapshot",
		"compact": false,
		"phase": str(message.get("phase", "B13_compact_unreliable_state")),
		"battle_start_id": _extract_battle_start_id(message),
		"bs": _extract_battle_start_id(message),
		"battle_start_kind": str(message.get("battle_start_kind", "")),
		"battle_retry_context_key": str(message.get("battle_retry_context_key", "")),
		"tick": int(message.get("t", 0)),
		"scene_instance_id": int(message.get("sid", message.get("scene_instance_id", 0))),
		"sid": int(message.get("sid", message.get("scene_instance_id", 0))),
		"time_msec": int(message.get("m", server_time_msec)),
		"server_time_msec": server_time_msec,
		"player_count": int(message.get("pc", 0)),
		"players": [],
		"entities": [],
		"wave_timer_state": {},
		"economy_state": {},
		"progression_state": message.get("pr", {}),
		"events": [],
		"removed": [],
		"counts": {},
		"prune_missing": false
	}

	var packed_players = message.get("p", [])
	if typeof(packed_players) == TYPE_ARRAY:
		for row in packed_players:
			if typeof(row) != TYPE_ARRAY or row.size() < 8:
				continue
			var player_index = int(row[0])
			expanded["players"].append({
				"net_id": "player_%s" % str(player_index),
				"player_index": player_index,
				"pos": _xy_to_dict(row[1], row[2]),
				"vel": _xy_to_dict(row[3], row[4]),
				"dead": int(row[5]) != 0,
				"health": int(row[6]),
				"max_health": int(row[7]),
				"hit_protection": int(row[8]) if row.size() >= 9 else -1
			})

	var packed_entities = message.get("e", [])
	if typeof(packed_entities) == TYPE_ARRAY:
		for row in packed_entities:
			if typeof(row) != TYPE_ARRAY or row.size() < 15:
				continue
			var category = _compact_id_to_category(int(row[1]))
			var entity_state = {
				"net_id": str(row[0]),
				"category": category,
				"sync_mode": "host_motion",
				"entity_type": int(row[2]),
				"pos": _xy_to_dict(row[3], row[4]),
				"vel": _xy_to_dict(row[5], row[6]),
				"dead": int(row[7]) != 0,
				"health": int(row[8]),
				"max_health": int(row[9]),
				"speed": int(row[10]),
				"damage": int(row[11]),
				"armor": int(row[12]),
				"status_flags": {"cursed": int(row[13]) != 0},
				"player_index": int(row[14])
			}
			expanded["entities"].append(entity_state)

	var packed_births = message.get("b", [])
	if typeof(packed_births) == TYPE_ARRAY:
		for row in packed_births:
			if typeof(row) != TYPE_ARRAY or row.size() < 9:
				continue
			var birth_state = {
				"net_id": str(row[0]),
				"category": "birth",
				"entity_type": int(row[1]),
				"scene_path": str(row[2]),
				"pos": _xy_to_dict(row[3], row[4]),
				"dead": false,
				"player_index": int(row[5]),
				"time_before_spawn": float(row[6]),
				"current_time_before_spawn": float(row[7]),
				"server_time_msec": int(row[8])
			}
			if row.size() >= 12:
				var spawn_net_id = str(row[9])
				birth_state["spawn_net_id"] = spawn_net_id
				birth_state["entity_net_id"] = spawn_net_id
				birth_state["spawn_category"] = _compact_id_to_category(int(row[10]))
				birth_state["spawn_sync_mode"] = "host_motion" if int(row[11]) != 0 else "birth_only"
				birth_state["spawn_scene_path"] = str(row[2])
			if row.size() >= 13:
				birth_state["data_path"] = str(row[12])
			expanded["births"].append(birth_state)

	var w = message.get("w", [])
	if typeof(w) == TYPE_ARRAY and w.size() >= 5:
		expanded["wave_timer_state"] = {
			"wave": int(w[0]),
			"wait_time": float(w[1]),
			"time_left": float(w[2]),
			"server_time_msec": int(w[3]),
			"running": int(w[4]) != 0
		}

	var ec = message.get("ec", [])
	if typeof(ec) == TYPE_ARRAY and ec.size() >= 2:
		var eco_players = []
		var packed_eco_players = ec[1]
		if typeof(packed_eco_players) == TYPE_ARRAY:
			for row in packed_eco_players:
				if typeof(row) != TYPE_ARRAY or row.size() < 8:
					continue
				eco_players.append({
					"player_index": int(row[0]),
					"materials": int(row[1]),
					"gold": int(row[2]),
					"xp": float(row[3]),
					"level": int(row[4]),
					"next_level_xp": float(row[5]),
					"hp": int(row[6]),
					"max_hp": int(row[7])
				})
		expanded["economy_state"] = {"server_time_msec": int(ec[0]), "players": eco_players}

	return expanded


func _handle_battle_terminal_state_from_host(message: Dictionary) -> void:
	_apply_host_retry_count_from_battle_message(message)
	var replica_manager = _get_battle_replica_manager()
	if replica_manager != null and replica_manager.has_method("receive_battle_terminal_state_from_host"):
		replica_manager.receive_battle_terminal_state_from_host(message)
	else:
		var snapshot = message.duplicate(true)
		snapshot["msg_type"] = "battle_snapshot"
		_handle_battle_snapshot_from_host(snapshot)


func _handle_battle_reliable_events_from_host(message: Dictionary) -> void:
	var replica_manager = _get_battle_replica_manager()
	if replica_manager != null and replica_manager.has_method("receive_battle_reliable_events_from_host"):
		replica_manager.receive_battle_reliable_events_from_host(message)
	return


func _handle_battle_snapshot_from_host(message: Dictionary) -> void:
	# the transport boundary so BattleReplicaManager can keep its normal schema.
	var now = OS.get_ticks_msec()
	_apply_host_retry_count_from_battle_message(message)
	var t_expand = OS.get_ticks_usec()
	var expanded = _expand_compact_battle_snapshot(message) if _safe_bool(message.get("compact", false)) else message
	_bo_net_diag_cost("expand_battle_snapshot", t_expand, "compact=" + str(message.get("compact", false)) + " tick=" + str(expanded.get("tick", message.get("t", 0))))

	_client_battle_snapshot_rx_count += 1
	var tick = int(expanded.get("tick", 0))

	var t_apply = OS.get_ticks_usec()
	var replica_manager = _get_battle_replica_manager()
	if replica_manager != null and replica_manager.has_method("receive_battle_snapshot_from_host"):
		replica_manager.receive_battle_snapshot_from_host(expanded)
	else:
		var ghost_layer = _get_battle_ghost_layer()
		if ghost_layer != null and ghost_layer.has_method("receive_battle_snapshot_from_host"):
			ghost_layer.receive_battle_snapshot_from_host(expanded)
	_bo_net_diag_cost("apply_battle_snapshot", t_apply, "tick=" + str(tick) + " players=" + str(_safe_array_size(expanded.get("players", []))) + " entities=" + str(_safe_array_size(expanded.get("entities", []))) + " removed=" + str(_safe_array_size(expanded.get("removed", []))))

	var should_log = _client_battle_snapshot_rx_count <= CLIENT_BATTLE_SNAPSHOT_LOG_FIRST_COUNT
	if now - _last_client_battle_snapshot_rx_log_msec >= CLIENT_BATTLE_SNAPSHOT_LOG_INTERVAL_MSEC:
		should_log = true
	if not should_log:
		_last_client_battle_snapshot_rx_tick = tick
		return

	_last_client_battle_snapshot_rx_log_msec = now
	var players = expanded.get("players", [])
	var entities = expanded.get("entities", [])
	var removed = expanded.get("removed", [])
	var events = expanded.get("events", [])
	var progression = expanded.get("progression_state", {})
	var progression_players = []
	if typeof(progression) == TYPE_DICTIONARY:
		progression_players = progression.get("players", [])
	var counts = expanded.get("counts", {})
	var delta_tick = tick - int(_last_client_battle_snapshot_rx_tick)
	_last_client_battle_snapshot_rx_tick = tick


func _apply_host_retry_count_from_battle_message(message: Dictionary) -> void:
	if typeof(message) != TYPE_DICTIONARY:
		return
	if message.has("r"):
		RunData.retries = int(message.get("r", RunData.retries))
	elif message.has("retries"):
		RunData.retries = int(message.get("retries", RunData.retries))


func _safe_bool(value) -> bool:
	if typeof(value) == TYPE_BOOL:
		return value
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_REAL:
		return int(value) != 0
	var s = str(value).to_lower()
	return s == "true" or s == "1" or s == "yes"


func _build_host_zone_sync_state() -> Dictionary:
	var current_zone = int(RunData.current_zone)
	var zone_selected = current_zone
	var zone_is_random = false
	if typeof(ProgressData.settings) == TYPE_DICTIONARY:
		zone_selected = int(ProgressData.settings.get("zone_selected", current_zone))
		zone_is_random = bool(ProgressData.settings.get("zone_is_random", false))
	# In vanilla random-zone mode, the concrete map is kept in settings.zone_selected
	# until CharacterSelection._on_selections_completed() calls _setup_zone(). Network
	# clients must receive the concrete map, not re-roll locally.
	if zone_is_random:
		current_zone = zone_selected
	return {
		"current_zone": current_zone,
		"zone_selected": zone_selected,
		"zone_is_random": zone_is_random,
		"host_current_zone": current_zone,
		"host_zone_is_random": zone_is_random
	}


func _augment_run_config_with_host_zone(run_config: Dictionary) -> void:
	var zone_state = _build_host_zone_sync_state()
	for key in zone_state.keys():
		run_config[key] = zone_state[key]


func _augment_host_zone_sync_payload(payload: Dictionary) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var zone_state = _build_host_zone_sync_state()
	payload["zone_sync"] = zone_state.duplicate(true)
	for key in zone_state.keys():
		if not payload.has(key):
			payload[key] = zone_state[key]
	if payload.has("run_config") and typeof(payload.get("run_config")) == TYPE_DICTIONARY:
		_augment_run_config_with_host_zone(payload["run_config"])
	if payload.has("selection_state") and typeof(payload.get("selection_state")) == TYPE_DICTIONARY:
		var selection_state = payload["selection_state"]
		selection_state["zone_sync"] = zone_state.duplicate(true)
		for key in zone_state.keys():
			if not selection_state.has(key):
				selection_state[key] = zone_state[key]


func _extract_zone_sync_state(payload) -> Dictionary:
	if typeof(payload) != TYPE_DICTIONARY:
		return {}
	if payload.has("zone_sync") and typeof(payload.get("zone_sync")) == TYPE_DICTIONARY:
		return _normalize_zone_sync_state(payload.get("zone_sync"))
	if payload.has("run_config") and typeof(payload.get("run_config")) == TYPE_DICTIONARY:
		var run_config = payload.get("run_config")
		if _dict_has_zone_sync_fields(run_config):
			return _normalize_zone_sync_state(run_config)
	if payload.has("selection_state") and typeof(payload.get("selection_state")) == TYPE_DICTIONARY:
		var selection_state = payload.get("selection_state")
		if selection_state.has("zone_sync") and typeof(selection_state.get("zone_sync")) == TYPE_DICTIONARY:
			return _normalize_zone_sync_state(selection_state.get("zone_sync"))
		if selection_state.has("run_config") and typeof(selection_state.get("run_config")) == TYPE_DICTIONARY and _dict_has_zone_sync_fields(selection_state.get("run_config")):
			return _normalize_zone_sync_state(selection_state.get("run_config"))
		if _dict_has_zone_sync_fields(selection_state):
			return _normalize_zone_sync_state(selection_state)
	if _dict_has_zone_sync_fields(payload):
		return _normalize_zone_sync_state(payload)
	return {}


func _dict_has_zone_sync_fields(value) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	return value.has("current_zone") or value.has("zone_selected") or value.has("zone_is_random") or value.has("host_current_zone") or value.has("host_zone_is_random")


func _normalize_zone_sync_state(value) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var current_zone = int(value.get("current_zone", value.get("host_current_zone", value.get("zone_selected", 0))))
	var zone_selected = int(value.get("zone_selected", current_zone))
	var host_current_zone = int(value.get("host_current_zone", current_zone))
	var zone_is_random = bool(value.get("zone_is_random", value.get("host_zone_is_random", false)))
	return {
		"current_zone": current_zone,
		"zone_selected": zone_selected,
		"zone_is_random": zone_is_random,
		"host_current_zone": host_current_zone,
		"host_zone_is_random": bool(value.get("host_zone_is_random", zone_is_random))
	}


func _has_local_zone_id(zone_id: int) -> bool:
	if zone_id < 0:
		return false
	if ZoneService.zones == null:
		return false
	return zone_id < ZoneService.zones.size() and ZoneService.zones[zone_id] != null


func _get_local_zone_id_for_host_zone(host_zone_id: int) -> int:
	if _has_local_zone_id(host_zone_id):
		return host_zone_id
	if _has_local_zone_id(0):
		return 0
	return -1


func _apply_host_zone_sync_for_client(message: Dictionary, reason: String) -> void:
	if _is_game_host() or typeof(message) != TYPE_DICTIONARY:
		return
	var zone_state = _extract_zone_sync_state(message)
	if zone_state.empty():
		return
	var host_zone_id = int(zone_state.get("host_current_zone", zone_state.get("current_zone", 0)))
	var local_zone_id = _get_local_zone_id_for_host_zone(host_zone_id)
	if local_zone_id < 0:
		return
	var host_zone_available = local_zone_id == host_zone_id
	_sanitize_zone_sync_payload_for_local_client(message, local_zone_id, host_zone_id, host_zone_available)
	var old_zone = int(RunData.current_zone)
	RunData.current_zone = local_zone_id
	if typeof(ProgressData.settings) == TYPE_DICTIONARY:
		ProgressData.settings["zone_selected"] = local_zone_id
		# Never keep random-zone mode on clients. The host has already resolved the
		# concrete map; allowing clients to keep zone_is_random can re-roll locally.
		ProgressData.settings["zone_is_random"] = false
	if RunData.has_method("set_meta"):
		RunData.set_meta("brotato_online_host_current_zone", host_zone_id)
		RunData.set_meta("brotato_online_host_zone_available", host_zone_available)
	if old_zone != local_zone_id or not host_zone_available:
		pass
	_apply_zone_to_visible_character_selection_ui(local_zone_id, host_zone_id, host_zone_available, reason)


func _sanitize_zone_sync_payload_for_local_client(payload, local_zone_id: int, host_zone_id: int, host_zone_available: bool) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		return
	if _dict_has_zone_sync_fields(payload) or payload.has("zone_sync"):
		payload["host_current_zone"] = host_zone_id
		payload["host_zone_unavailable"] = not host_zone_available
		payload["current_zone"] = local_zone_id
		payload["zone_selected"] = local_zone_id
		payload["zone_is_random"] = false
		payload["host_zone_is_random"] = bool(payload.get("host_zone_is_random", false))
	if payload.has("zone_sync") and typeof(payload.get("zone_sync")) == TYPE_DICTIONARY:
		var zone_sync = payload.get("zone_sync")
		zone_sync["host_current_zone"] = host_zone_id
		zone_sync["host_zone_unavailable"] = not host_zone_available
		zone_sync["current_zone"] = local_zone_id
		zone_sync["zone_selected"] = local_zone_id
		zone_sync["zone_is_random"] = false
	if payload.has("run_config") and typeof(payload.get("run_config")) == TYPE_DICTIONARY:
		_sanitize_zone_sync_payload_for_local_client(payload.get("run_config"), local_zone_id, host_zone_id, host_zone_available)
	if payload.has("selection_state") and typeof(payload.get("selection_state")) == TYPE_DICTIONARY:
		_sanitize_zone_sync_payload_for_local_client(payload.get("selection_state"), local_zone_id, host_zone_id, host_zone_available)


func _apply_zone_to_visible_character_selection_ui(local_zone_id: int, host_zone_id: int, host_zone_available: bool, reason: String) -> void:
	var scene = get_tree().current_scene
	if not _is_live_node(scene):
		return
	var selection = scene
	if not selection.has_method("_setup_zone"):
		selection = scene.find_node("CharacterSelection", true, false) if scene.has_method("find_node") else null
	if not _is_live_node(selection) or not selection.has_method("_setup_zone"):
		return
	var zone_button = null
	if selection.has_method("get_node_or_null"):
		zone_button = selection.get_node_or_null("%ZoneSelectionButton")
	if not _is_live_node(zone_button):
		zone_button = selection.get("_zone_selection_button")
	if not _is_live_node(zone_button):
		return
	var zone_index = _find_zone_button_index_for_id(zone_button, local_zone_id)
	if zone_index < 0:
		zone_index = 0
	if zone_button.has_method("select"):
		zone_button.select(zone_index)
	else:
		zone_button.set("selected", zone_index)
	selection.call_deferred("_setup_zone", zone_index)
	if not host_zone_available:
		pass


func _find_zone_button_index_for_id(zone_button, zone_id: int) -> int:
	if not _is_live_node(zone_button) or not zone_button.has_method("get_item_count"):
		return -1
	var count = int(zone_button.get_item_count())
	for index in range(count):
		if zone_button.has_method("get_item_id") and int(zone_button.get_item_id(index)) == zone_id:
			return index
	return -1


func _safe_array_size(value) -> int:
	if typeof(value) == TYPE_ARRAY:
		return value.size()
	return 0


func _safe_dict_get(value, key: String, fallback):
	if typeof(value) == TYPE_DICTIONARY:
		return value.get(key, fallback)
	return fallback


func _poll_and_send_host_phase_messages() -> void:
	if not _is_game_host() or _lobby_id == 0:
		return

	var now = OS.get_ticks_msec()
	if now - _last_host_phase_poll_msec < MENU_SCENE_BROADCAST_INTERVAL_MSEC:
		return
	_last_host_phase_poll_msec = now

	_send_host_phase_messages_to_all(false)


func _send_host_phase_messages_to_all(force: bool = false, except_steam_id: String = "") -> void:
	if not _is_game_host() or _lobby_id == 0:
		return

	for member in _members:
		var steam_id = str(member.get("steam_id", ""))
		if steam_id == "" or steam_id == _self_steam_id:
			continue
		if except_steam_id != "" and steam_id == except_steam_id:
			continue
		_send_host_phase_setup_to_client(steam_id, force)


func _send_host_phase_setup_to_client(steam_id: String, force: bool = false) -> void:
	if not _is_game_host() or _lobby_id == 0:
		return
	if steam_id == "" or steam_id == _self_steam_id:
		return

	var menu_sync = _get_menu_sync_manager()
	if menu_sync == null or not menu_sync.has_method("get_current_menu_screen"):
		return

	var screen = str(menu_sync.get_current_menu_screen())
	if screen == "shop" and _is_in_official_coop_resume_scene() and not _official_continue_players_ready():
		# Official CoopResume has not collected all saved-run players yet. Do not send
		# clients to CoopShop before the Host's vanilla Continue flow advances.
		return
	if screen == "character_selection":
		_send_host_character_setup_to_client(steam_id, force)
	elif screen == "weapon_selection":
		_send_host_weapon_setup_to_client(steam_id, force)
	elif screen == "difficulty_selection" or screen == "game" or screen == "shop":
		_send_host_scene_transition_to_client(steam_id, force)


func _send_host_character_setup_to_client(steam_id: String, force: bool = false) -> void:
	var menu_sync = _get_menu_sync_manager()
	if menu_sync == null or not menu_sync.has_method("build_host_character_setup_state"):
		return

	var state = menu_sync.build_host_character_setup_state(steam_id, _self_steam_id)
	var current_scene = get_tree().current_scene
	state["host_scene_instance_id"] = current_scene.get_instance_id() if current_scene != null else 0
	_augment_host_zone_sync_payload(state)
	if str(state.get("screen", "")) != "character_selection":
		return

	var key = _get_host_phase_setup_stable_key(state)
	if not force and str(_sent_character_setup_key_by_steam_id.get(steam_id, "")) == key:
		return

	_sent_character_setup_key_by_steam_id[steam_id] = key
	_send_p2p_json(steam_id, state, true)


func _send_host_weapon_setup_to_client(steam_id: String, force: bool = false) -> void:
	var menu_sync = _get_menu_sync_manager()
	if menu_sync == null or not menu_sync.has_method("build_host_weapon_setup_state"):
		return

	var state = menu_sync.build_host_weapon_setup_state(steam_id, _self_steam_id)
	var current_scene = get_tree().current_scene
	state["host_scene_instance_id"] = current_scene.get_instance_id() if current_scene != null else 0
	_augment_host_zone_sync_payload(state)
	if str(state.get("screen", "")) != "weapon_selection":
		return

	var key = _get_host_phase_setup_stable_key(state)
	if not force and str(_sent_weapon_setup_key_by_steam_id.get(steam_id, "")) == key:
		return

	_sent_weapon_setup_key_by_steam_id[steam_id] = key
	_send_p2p_json(steam_id, state, true)


func _get_stable_scene_run_config(config) -> Dictionary:
	if typeof(config) != TYPE_DICTIONARY:
		return {}
	return {
		"play_mode": int(config.get("play_mode", 0)),
		"is_coop_run": bool(config.get("is_coop_run", false)),
		"is_endless_run": bool(config.get("is_endless_run", config.get("endless_mode_toggled", false))),
		"endless_mode_toggled": bool(config.get("endless_mode_toggled", config.get("is_endless_run", false))),
		"player_count": int(config.get("player_count", 1)),
		"current_zone": int(config.get("current_zone", 0)),
		"current_difficulty": int(config.get("current_difficulty", 0)),
		"current_wave": int(config.get("current_wave", 0)),
		"zone_selected": int(config.get("zone_selected", 0)),
		"zone_is_random": bool(config.get("zone_is_random", false)),
		"constant_projectile": int(config.get("constant_projectile", 0)),
		"nb_of_waves": int(config.get("nb_of_waves", 20)),
		"elites_spawn": config.get("elites_spawn", []),
		"bosses_spawn": config.get("bosses_spawn", []),
		"events_spawn": config.get("events_spawn", []),
		"events_fog_of_war": config.get("events_fog_of_war", []),
		"events_bullet_hell": config.get("events_bullet_hell", [])
	}


func _get_menu_scene_state_stable_key(state: Dictionary) -> String:
	var stable = state.duplicate(true)
	stable.erase("availability")
	stable.erase("selection_state")
	if stable.has("run_config"):
		# run_config contains full PlayerRunData, which changes during battle/shop and
		# made Host resend menu_scene_state constantly. Scene-state de-dup should only
		# track the phase identity; inventory/shop deltas are sent by dedicated packets.
		stable["run_config"] = _get_stable_scene_run_config(stable.get("run_config", {}))
	if str(stable.get("screen", "")) == "shop":
		stable.erase("shop_state")
	return to_json(stable)


func _is_complete_shop_scene_transition_state(state: Dictionary) -> bool:
	if str(state.get("screen", "")) != "shop":
		return true
	var shop_state = state.get("shop_state", {})
	if typeof(shop_state) != TYPE_DICTIONARY:
		return false
	var players = shop_state.get("players", [])
	if typeof(players) != TYPE_ARRAY:
		return false
	var run_config = state.get("run_config", {})
	var expected_player_count = 0
	if typeof(run_config) == TYPE_DICTIONARY:
		expected_player_count = int(run_config.get("player_count", 0))
	if expected_player_count <= 0 or players.size() < expected_player_count:
		return false
	var expected_shop_slot_count = int(ItemService.NB_SHOP_ITEMS)
	for player_index in range(expected_player_count):
		var player_state = players[player_index]
		if typeof(player_state) != TYPE_DICTIONARY:
			return false
		var shop_items = player_state.get("shop_items", [])
		if typeof(shop_items) != TYPE_ARRAY:
			return false
		if shop_items.size() < expected_shop_slot_count:
			return false
		if int(player_state.get("shop_slot_count", shop_items.size())) < expected_shop_slot_count:
			return false
	return true


func _send_host_scene_transition_to_client(steam_id: String, force: bool = false) -> void:
	var menu_sync = _get_menu_sync_manager()
	if menu_sync == null or not menu_sync.has_method("build_menu_scene_state"):
		return

	var force_full_item_list = _should_force_full_item_list_for_scene_sync_to_client(steam_id)
	var state = menu_sync.build_menu_scene_state(false, false, force_full_item_list)
	_augment_host_zone_sync_payload(state)
	var screen = str(state.get("screen", ""))
	if screen == "" or screen == "none" or screen == "character_selection" or screen == "weapon_selection":
		return

	# Once a synced game start is pending, game_start_prepare/game_start_commit is the
	# authoritative transition path. Suppress old difficulty/shop scene-state packets;
	# otherwise reliable delivery can make the Client bounce back to the previous page
	# after it has already loaded main.tscn.
	if not _pending_host_game_start.empty() and screen != "game":
		return

	# For difficulty/game keep the existing scene-state message; no unlock catalog is needed here.
	if screen == "game" or screen.find("shop") != -1:
		if not _is_in_official_coop_resume_scene():
			_lock_online_run_slots("host_scene_transition:" + screen)
			_sync_slot_manager_lock_flag()
	if state.has("run_config") and typeof(state.get("run_config", {})) == TYPE_DICTIONARY:
		var key_run_config = state.get("run_config", {}).duplicate(true)
		_copy_current_host_wave_schedule_into_run_config(key_run_config)
		state["run_config"] = key_run_config
	state.erase("availability")
	var key = _get_menu_scene_state_stable_key(state)
	if not force and not force_full_item_list and str(_sent_scene_transition_key_by_steam_id.get(steam_id, "")) == key:
		return

	var full_payload_cache_key = screen + "|" + key + "|full_items=" + str(force_full_item_list)
	var now = OS.get_ticks_msec()
	var loaded_from_payload_cache = false
	if not force and _host_scene_transition_payload_cache_key == full_payload_cache_key and now - int(_host_scene_transition_payload_cache_msec) <= MENU_SCENE_BROADCAST_INTERVAL_MSEC and typeof(_host_scene_transition_payload_cache_state) == TYPE_DICTIONARY and not _host_scene_transition_payload_cache_state.empty():
		state = _host_scene_transition_payload_cache_state.duplicate(true)
		loaded_from_payload_cache = true
	else:
		state = menu_sync.build_menu_scene_state(screen == "shop", true, force_full_item_list)
		_augment_host_zone_sync_payload(state)
		if state.has("run_config") and typeof(state.get("run_config", {})) == TYPE_DICTIONARY:
			var send_run_config = state.get("run_config", {}).duplicate(true)
			_copy_current_host_wave_schedule_into_run_config(send_run_config)
			state["run_config"] = send_run_config
		state.erase("availability")

	# CoopShop can already be detected as the current screen before every player's
	# visual sale slots have finished initializing. Do not send, cache, or mark this
	# transition as delivered until the authoritative shop_items arrays are complete.
	if screen == "shop" and not _is_complete_shop_scene_transition_state(state):
		if loaded_from_payload_cache:
			_host_scene_transition_payload_cache_key = ""
			_host_scene_transition_payload_cache_msec = 0
			_host_scene_transition_payload_cache_state = {}
		return

	if not force and not loaded_from_payload_cache:
		_host_scene_transition_payload_cache_key = full_payload_cache_key
		_host_scene_transition_payload_cache_msec = now
		_host_scene_transition_payload_cache_state = state.duplicate(true)

	var send_ok = _send_p2p_json(steam_id, state, true)
	if send_ok:
		_sent_scene_transition_key_by_steam_id[steam_id] = key
		if force_full_item_list:
			_clear_full_item_list_scene_sync_requirement_for_client(steam_id)
	else:
		_sent_scene_transition_key_by_steam_id.erase(steam_id)


func _get_host_phase_setup_stable_key(state: Dictionary) -> String:
	# Do not include focus/selected/ready in the setup de-dup key.
	# Setup messages are for slot layout + Host catalog; selection_state is sent separately.
	var stable = state.duplicate(true)
	stable.erase("selection_state")
	if stable.has("players"):
		var stable_players = []
		var players = stable.get("players", [])
		if typeof(players) == TYPE_ARRAY:
			for player in players:
				if typeof(player) != TYPE_DICTIONARY:
					continue
				stable_players.append({
					"player_index": int(player.get("player_index", -1)),
					"steam_id": str(player.get("steam_id", "")),
					"remote": bool(player.get("remote", false))
				})
		stable["players"] = stable_players
	return to_json(stable)


func _add_target_client_slot_to_selection_state(state: Dictionary, steam_id: String) -> void:
	if typeof(state) != TYPE_DICTIONARY:
		return
	if steam_id == "" or steam_id == "0" or steam_id == _self_steam_id:
		return
	state["target_client_steam_id"] = steam_id
	var player_index = -1
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("get_player_index_for_steam_id"):
		player_index = int(slot_manager.get_player_index_for_steam_id(steam_id))
	state["target_client_player_index"] = player_index
	state["client_player_index"] = player_index


func _send_selection_state_to_client(steam_id: String, force: bool = false) -> void:
	if not _is_game_host() or _lobby_id == 0:
		return

	var menu_sync = _get_menu_sync_manager()
	if menu_sync == null or not menu_sync.has_method("build_selection_state"):
		return
	if menu_sync.has_method("get_current_menu_screen"):
		var screen = str(menu_sync.get_current_menu_screen())
		if not _is_selection_state_broadcast_screen(screen):
			return

	var state = menu_sync.build_selection_state()
	_augment_host_zone_sync_payload(state)
	_add_target_client_slot_to_selection_state(state, steam_id)
	if str(state.get("screen", "")) == "none":
		return

	_send_p2p_json(steam_id, state, true)
	if force:
		pass

func _poll_and_broadcast_selection_state() -> void:
	if not _is_game_host() or _lobby_id == 0:
		return

	var now = OS.get_ticks_msec()
	if now - _last_selection_broadcast_msec < SELECTION_BROADCAST_INTERVAL_MSEC:
		return
	_last_selection_broadcast_msec = now

	var menu_sync = _get_menu_sync_manager()
	if menu_sync == null or not menu_sync.has_method("get_current_menu_screen"):
		return
	var screen = str(menu_sync.get_current_menu_screen())
	if not _is_selection_state_broadcast_screen(screen):
		_last_broadcast_selection_key = ""
		return

	_broadcast_selection_state(false)


func _broadcast_selection_state(force: bool = false) -> void:
	if not _is_game_host() or _lobby_id == 0:
		return

	var menu_sync = _get_menu_sync_manager()
	if menu_sync == null or not menu_sync.has_method("build_selection_state"):
		return
	if menu_sync.has_method("get_current_menu_screen"):
		var screen = str(menu_sync.get_current_menu_screen())
		if not _is_selection_state_broadcast_screen(screen):
			_last_broadcast_selection_key = ""
			return

	var state = menu_sync.build_selection_state()
	_augment_host_zone_sync_payload(state)
	if str(state.get("screen", "")) == "none":
		return

	# Keep broadcast de-dup based on the shared selection payload. The per-client
	# target slot is added only to the duplicated packet below, so it does not make
	# the Host resend every tick.
	var key = to_json(state)
	if not force and key == _last_broadcast_selection_key:
		return

	_last_broadcast_selection_key = key
	for member in _members:
		var steam_id = str(member.get("steam_id", ""))
		if steam_id == "" or steam_id == _self_steam_id:
			continue
		var targeted_state = state.duplicate(true)
		_add_target_client_slot_to_selection_state(targeted_state, steam_id)
		_send_p2p_json(steam_id, targeted_state, true)



func _prepare_steam_messages_session_with_peer(steam_id: String, reason: String = "") -> void:
	if _steam == null or steam_id == "" or steam_id == "0" or steam_id == _self_steam_id:
		return
	if _accepted_p2p_sessions.has(steam_id):
		return
	if not _steam_has_method("acceptSessionWithUser"):
		return
	var ok = _steam.acceptSessionWithUser(int(steam_id))
	_accepted_p2p_sessions[steam_id] = ok


func _reset_steam_messages_session_with_peer(steam_id: String, reason: String = "") -> void:
	if _steam == null or steam_id == "" or steam_id == "0" or steam_id == _self_steam_id:
		return
	_accepted_p2p_sessions.erase(steam_id)
	if _steam_has_method("closeSessionWithUser"):
		var closed = _steam.closeSessionWithUser(int(steam_id))
	if _steam_has_method("acceptSessionWithUser"):
		var ok = _steam.acceptSessionWithUser(int(steam_id))
		_accepted_p2p_sessions[steam_id] = ok


func _send_p2p_json(target_steam_id: String, message: Dictionary, reliable: bool = true) -> bool:
	if not _ensure_steam_ready():
		return false

	if target_steam_id == "" or target_steam_id == "0":
		return false

	if not _steam_has_method("sendMessageToUser"):
		return false

	_prepare_steam_messages_session_with_peer(target_steam_id, "send")

	var wire_message = _annotate_online_session_message(message)
	var msg_type = str(wire_message.get("msg_type", ""))
	var payload = to_json(wire_message).to_utf8()
	var send_flags = STEAM_NETWORKING_SEND_RELIABLE if (reliable or FORCE_ALL_STEAM_MESSAGES_RELIABLE) else 0
	var channel = _get_p2p_channel_for_message_type(msg_type)
	var coalesce_key = _get_p2p_send_queue_coalesce_key(target_steam_id, wire_message, channel)
	_bo_net_diag_log_large_or_queued_send(target_steam_id, msg_type, payload.size(), channel, reliable or FORCE_ALL_STEAM_MESSAGES_RELIABLE, "large_payload", _pending_p2p_chunk_sends.size())

	# Only pre-chunk very large messages. Medium reliable packets should keep Steam's
	# native message ordering; if Steam refuses one, fall back to the frame-paced chunk
	# queue below.
	if payload.size() > P2P_JSON_CHUNK_TRIGGER_BYTES:
		return _queue_p2p_json_chunks(target_steam_id, payload, msg_type, send_flags, channel, coalesce_key)

	# If a large message to this peer/channel is still being split across frames,
	# queue later small messages behind it. Otherwise shop_buy can be chunked while
	# shop_focus/shop_reroll goes out immediately, making the Host see a higher
	# action seq first and reject the delayed buy as stale.
	if _has_pending_p2p_send_for_target_channel(target_steam_id, channel):
		_bo_net_diag_log_large_or_queued_send(target_steam_id, msg_type, payload.size(), channel, reliable or FORCE_ALL_STEAM_MESSAGES_RELIABLE, "queued_behind_pending", _pending_p2p_chunk_sends.size())
		return _queue_p2p_json_direct_after_pending(target_steam_id, payload, msg_type, send_flags, channel, coalesce_key)

	var target_int = int(target_steam_id)
	var result = _steam.sendMessageToUser(target_int, payload, send_flags, channel)
	var ok = _steam_networking_send_ok(result)
	var result_name = _steam_networking_result_name(result)
	if not ok:
		_bo_net_diag_log_large_or_queued_send(target_steam_id, msg_type, payload.size(), channel, reliable or FORCE_ALL_STEAM_MESSAGES_RELIABLE, "send_failed", _pending_p2p_chunk_sends.size())
		_log_steam_message_send_failure(target_steam_id, msg_type, payload.size(), send_flags, channel, result, result_name)
		if payload.size() > P2P_JSON_CHUNK_RAW_BYTES:
			return _queue_p2p_json_chunks(target_steam_id, payload, msg_type, send_flags, channel, coalesce_key)
		if coalesce_key != "":
			return _queue_p2p_json_direct_after_pending(target_steam_id, payload, msg_type, send_flags, channel, coalesce_key)
	return ok


func _has_pending_p2p_send_for_target_channel(target_steam_id: String, channel: int) -> bool:
	for queued in _pending_p2p_chunk_sends:
		if typeof(queued) != TYPE_DICTIONARY:
			continue
		if str(queued.get("target_steam_id", "")) == target_steam_id and int(queued.get("channel", P2P_CHANNEL_MENU)) == channel:
			return true
	return false


func _get_p2p_send_queue_coalesce_key(target_steam_id: String, message: Dictionary, channel: int) -> String:
	# Only coalesce packets that describe a latest UI position/state. Normal sends are
	# untouched; this key is used only when Steam send buffering forces the packet into
	# _pending_p2p_chunk_sends.
	if typeof(message) != TYPE_DICTIONARY or message.empty():
		return ""
	var msg_type = str(message.get("msg_type", ""))
	if msg_type == "menu_focus":
		return target_steam_id + ":" + str(channel) + ":menu_focus:" + str(message.get("screen", "")) + ":" + str(message.get("origin_steam_id", "")) + ":" + str(message.get("player_index", ""))
	if msg_type != "run_page_action_sync":
		return ""
	var action_type = str(message.get("action_type", ""))
	if action_type != "shop_focus" and action_type != "upgrade_focus" and action_type != "shop_reroll":
		return ""
	var origin = str(message.get("origin_steam_id", ""))
	if origin == "":
		origin = _self_steam_id
	return target_steam_id + ":" + str(channel) + ":run_page_action_sync:" + action_type + ":" + str(message.get("screen", "")) + ":" + origin + ":" + str(message.get("player_index", ""))


func _drop_pending_p2p_coalesced_sends(coalesce_key: String, target_steam_id: String, channel: int) -> int:
	if coalesce_key == "":
		return 0
	var removed = 0
	var i = _pending_p2p_chunk_sends.size() - 1
	while i >= 0:
		var queued = _pending_p2p_chunk_sends[i]
		if typeof(queued) == TYPE_DICTIONARY and str(queued.get("coalesce_key", "")) == coalesce_key and str(queued.get("target_steam_id", "")) == target_steam_id and int(queued.get("channel", P2P_CHANNEL_MENU)) == channel:
			_pending_p2p_chunk_sends.remove(i)
			removed += 1
		i -= 1
	if removed > 0:
		_bo_net_diag_state_change("SEND_COALESCE", coalesce_key + ":" + str(removed), "removed=" + str(removed) + " key=" + coalesce_key, 500)
	return removed


func _queue_p2p_json_direct_after_pending(target_steam_id: String, payload: PoolByteArray, msg_type: String, send_flags: int, channel: int, coalesce_key: String = "") -> bool:
	if payload.size() <= 0:
		return false
	# A packet can be below the pre-chunk trigger but still too large for the
	# current SteamNetworkingMessages send buffer. If it is queued behind chunks,
	# do not retry it forever as a direct packet; split it now while preserving
	# ordering behind the already-pending sends.
	if payload.size() > P2P_JSON_CHUNK_RAW_BYTES:
		return _queue_p2p_json_chunks(target_steam_id, payload, msg_type, send_flags, channel, coalesce_key)
	_drop_pending_p2p_coalesced_sends(coalesce_key, target_steam_id, channel)
	var now = OS.get_ticks_msec()
	_pending_p2p_chunk_sends.append({
		"target_steam_id": target_steam_id,
		"payload": payload,
		"send_flags": send_flags,
		"channel": channel,
		"final_msg_type": msg_type,
		"direct": true,
		"chunk_id": "",
		"chunk_index": 0,
		"chunk_count": 1,
		"queued_msec": now,
		"next_send_msec": now,
		"retry_count": 0,
		"last_retry_log_msec": 0,
		"coalesce_key": coalesce_key
	})
	return true


func _queue_p2p_json_chunks(target_steam_id: String, payload: PoolByteArray, msg_type: String, send_flags: int, channel: int, coalesce_key: String = "") -> bool:
	if payload.size() <= 0:
		return false
	_p2p_chunk_seq += 1
	var now = OS.get_ticks_msec()
	var chunk_id = str(_self_steam_id) + ":" + str(_p2p_chunk_seq) + ":" + str(OS.get_ticks_usec()) + ":" + msg_type
	var chunk_count = int(ceil(float(payload.size()) / float(P2P_JSON_CHUNK_RAW_BYTES)))
	if chunk_count <= 1:
		return false
	_drop_pending_p2p_coalesced_sends(coalesce_key, target_steam_id, channel)
	_bo_net_diag_log_large_or_queued_send(target_steam_id, msg_type, payload.size(), channel, true, "chunk_queue", _pending_p2p_chunk_sends.size() + chunk_count)
	for chunk_index in range(chunk_count):
		var start = chunk_index * P2P_JSON_CHUNK_RAW_BYTES
		var length = min(P2P_JSON_CHUNK_RAW_BYTES, payload.size() - start)
		var raw_chunk = _slice_pool_byte_array(payload, start, length)
		var chunk_message = {
			"msg_type": "p2p_json_chunk",
			"chunk_id": chunk_id,
			"chunk_index": chunk_index,
			"chunk_count": chunk_count,
			"final_msg_type": msg_type,
			"original_bytes": payload.size(),
			"payload_b64": Marshalls.raw_to_base64(raw_chunk)
		}
		var chunk_wire = _annotate_online_session_message(chunk_message)
		var chunk_payload = to_json(chunk_wire).to_utf8()
		_pending_p2p_chunk_sends.append({
			"target_steam_id": target_steam_id,
			"payload": chunk_payload,
			"send_flags": send_flags,
			"channel": channel,
			"final_msg_type": msg_type,
			"chunk_id": chunk_id,
			"chunk_index": chunk_index,
			"chunk_count": chunk_count,
			"queued_msec": now,
			"next_send_msec": now,
			"retry_count": 0,
			"last_retry_log_msec": 0,
			"coalesce_key": coalesce_key
		})
	return true


func _poll_pending_p2p_chunk_sends() -> void:
	if _pending_p2p_chunk_sends.empty():
		return
	var poll_start_usec = OS.get_ticks_usec()
	if _steam == null or not _steam_ready or not _steam_has_method("sendMessageToUser"):
		return
	var now = OS.get_ticks_msec()
	var sent = 0
	var head_age = 0
	if not _pending_p2p_chunk_sends.empty() and typeof(_pending_p2p_chunk_sends[0]) == TYPE_DICTIONARY:
		head_age = now - int(_pending_p2p_chunk_sends[0].get("queued_msec", now))
	if _pending_p2p_chunk_sends.size() >= BO_NET_DIAG_PENDING_QUEUE_WARN or head_age >= BO_NET_DIAG_PENDING_AGE_WARN_MSEC:
		_bo_net_diag_state_change("SEND_QUEUE", str(_pending_p2p_chunk_sends.size()) + ":" + str(head_age), "pending=" + str(_pending_p2p_chunk_sends.size()) + " head_age_ms=" + str(head_age), 1000)
	while sent < P2P_JSON_CHUNK_SENDS_PER_FRAME and not _pending_p2p_chunk_sends.empty():
		var queued = _pending_p2p_chunk_sends[0]
		if typeof(queued) != TYPE_DICTIONARY:
			_pending_p2p_chunk_sends.pop_front()
			continue
		var next_send_msec = int(queued.get("next_send_msec", 0))
		if next_send_msec > now:
			# Keep strict ordering for this peer/channel. If the head packet hit
			# Steam's send-buffer limit, later packets must not jump ahead.
			break
		queued = _pending_p2p_chunk_sends.pop_front()
		var target_steam_id = str(queued.get("target_steam_id", ""))
		if target_steam_id == "" or target_steam_id == "0":
			continue
		_prepare_steam_messages_session_with_peer(target_steam_id, "send_chunk")
		var payload = queued.get("payload", PoolByteArray())
		if typeof(payload) != TYPE_RAW_ARRAY:
			continue
		var send_flags = int(queued.get("send_flags", STEAM_NETWORKING_SEND_RELIABLE))
		var channel = int(queued.get("channel", P2P_CHANNEL_MENU))
		var result = _steam.sendMessageToUser(int(target_steam_id), payload, send_flags, channel)
		var ok = _steam_networking_send_ok(result)
		var final_msg_type = str(queued.get("final_msg_type", ""))
		var is_direct = bool(queued.get("direct", false))
		if not ok:
			var result_name = _steam_networking_result_name(result)
			var log_type = final_msg_type if is_direct else "p2p_json_chunk:" + final_msg_type
			_log_steam_message_send_failure(target_steam_id, log_type, payload.size(), send_flags, channel, result, result_name)
			var retry_count = int(queued.get("retry_count", 0)) + 1
			queued["retry_count"] = retry_count
			queued["last_result"] = result
			queued["last_result_name"] = result_name
			queued["next_send_msec"] = now + P2P_JSON_CHUNK_RETRY_DELAY_MSEC
			_pending_p2p_chunk_sends.insert(0, queued)
			break
		sent += 1
	_bo_net_diag_cost("poll_pending_chunk_send_loop", poll_start_usec, "sent=" + str(sent) + " pending=" + str(_pending_p2p_chunk_sends.size()) + " head_age_ms=" + str(head_age))

func _slice_pool_byte_array(bytes: PoolByteArray, start: int, length: int) -> PoolByteArray:
	var out = PoolByteArray()
	if length <= 0:
		return out
	var end = min(bytes.size(), start + length)
	for i in range(start, end):
		out.append(bytes[i])
	return out


func _receive_p2p_json_chunk(from_steam_id: String, message: Dictionary) -> Dictionary:
	var message_lobby_id = _get_message_lobby_id(message)
	if _lobby_id != 0 and message_lobby_id != str(_lobby_id):
		return {}
	var chunk_id = str(message.get("chunk_id", ""))
	var chunk_index = int(message.get("chunk_index", -1))
	var chunk_count = int(message.get("chunk_count", 0))
	if chunk_id == "" or chunk_index < 0 or chunk_count <= 1 or chunk_index >= chunk_count:
		return {}
	var now = OS.get_ticks_msec()
	_prune_stale_p2p_json_chunks(now)
	var key = from_steam_id + ":" + chunk_id
	var entry = _incoming_p2p_chunks.get(key, {})
	if typeof(entry) != TYPE_DICTIONARY or entry.empty():
		entry = {
			"chunk_count": chunk_count,
			"final_msg_type": str(message.get("final_msg_type", "")),
			"original_bytes": int(message.get("original_bytes", 0)),
			"chunks": {},
			"created_msec": now,
			"last_msec": now
		}
		_incoming_p2p_chunks[key] = entry
	if int(entry.get("chunk_count", 0)) != chunk_count:
		return {}
	var chunks = entry.get("chunks", {})
	if typeof(chunks) != TYPE_DICTIONARY:
		chunks = {}
	var raw_chunk = Marshalls.base64_to_raw(str(message.get("payload_b64", "")))
	if raw_chunk.size() <= 0:
		return {}
	chunks[chunk_index] = raw_chunk
	entry["chunks"] = chunks
	entry["last_msec"] = now
	_incoming_p2p_chunks[key] = entry
	if chunks.size() < chunk_count:
		return {}
	var full_payload = PoolByteArray()
	for i in range(chunk_count):
		if not chunks.has(i):
			return {}
		var part = chunks[i]
		if typeof(part) != TYPE_RAW_ARRAY:
			return {}
		for j in range(part.size()):
			full_payload.append(part[j])
	_incoming_p2p_chunks.erase(key)
	var original_bytes = int(entry.get("original_bytes", 0))
	if original_bytes > 0 and full_payload.size() != original_bytes:
		return {}
	var text = full_payload.get_string_from_utf8()
	var parsed = parse_json(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _prune_stale_p2p_json_chunks(now: int) -> void:
	var stale = []
	for key in _incoming_p2p_chunks.keys():
		var entry = _incoming_p2p_chunks.get(key, {})
		if typeof(entry) != TYPE_DICTIONARY:
			stale.append(key)
			continue
		var last_msec = int(entry.get("last_msec", entry.get("created_msec", now)))
		if now - last_msec > P2P_JSON_CHUNK_TTL_MSEC:
			stale.append(key)
	for key in stale:
		_incoming_p2p_chunks.erase(key)


func _steam_networking_send_ok(result) -> bool:
	if typeof(result) == TYPE_BOOL:
		return bool(result)
	if typeof(result) == TYPE_INT or typeof(result) == TYPE_REAL:
		return int(result) == 1
	if typeof(result) == TYPE_DICTIONARY:
		for key in ["result", "status", "code", "response"]:
			if result.has(key):
				var value = result[key]
				if typeof(value) == TYPE_BOOL:
					return bool(value)
				if typeof(value) == TYPE_INT or typeof(value) == TYPE_REAL:
					return int(value) == 1
		return false
	return false


func _steam_networking_result_name(result) -> String:
	if typeof(result) == TYPE_BOOL:
		return "bool_true" if bool(result) else "bool_false"
	if typeof(result) == TYPE_DICTIONARY:
		for key in ["result", "status", "code", "response"]:
			if result.has(key):
				return _steam_networking_result_name(result[key])
		return "dictionary_without_result"
	if typeof(result) != TYPE_INT and typeof(result) != TYPE_REAL:
		return "unknown_type"

	var code = int(result)
	var names = {
		0: "k_EResultNone",
		1: "k_EResultOK",
		2: "k_EResultFail",
		3: "k_EResultNoConnection",
		5: "k_EResultInvalidPassword",
		6: "k_EResultLoggedInElsewhere",
		7: "k_EResultInvalidProtocolVer",
		8: "k_EResultInvalidParam",
		9: "k_EResultFileNotFound",
		10: "k_EResultBusy",
		11: "k_EResultInvalidState",
		12: "k_EResultInvalidName",
		13: "k_EResultInvalidEmail",
		14: "k_EResultDuplicateName",
		15: "k_EResultAccessDenied",
		16: "k_EResultTimeout",
		17: "k_EResultBanned",
		18: "k_EResultAccountNotFound",
		19: "k_EResultInvalidSteamID",
		20: "k_EResultServiceUnavailable",
		21: "k_EResultNotLoggedOn",
		22: "k_EResultPending",
		23: "k_EResultEncryptionFailure",
		24: "k_EResultInsufficientPrivilege",
		25: "k_EResultLimitExceeded",
		26: "k_EResultRevoked",
		27: "k_EResultExpired",
		28: "k_EResultAlreadyRedeemed",
		29: "k_EResultDuplicateRequest",
		30: "k_EResultAlreadyOwned",
		31: "k_EResultIPNotFound",
		32: "k_EResultPersistFailed",
		33: "k_EResultLockingFailed",
		34: "k_EResultLogonSessionReplaced",
		35: "k_EResultConnectFailed",
		36: "k_EResultHandshakeFailed",
		37: "k_EResultIOFailure",
		38: "k_EResultRemoteDisconnect",
		39: "k_EResultShoppingCartNotFound",
		40: "k_EResultBlocked",
		41: "k_EResultIgnored",
		42: "k_EResultNoMatch",
		43: "k_EResultAccountDisabled",
		44: "k_EResultServiceReadOnly",
		45: "k_EResultAccountNotFeatured",
		46: "k_EResultAdministratorOK",
		47: "k_EResultContentVersion",
		48: "k_EResultTryAnotherCM",
		49: "k_EResultPasswordRequiredToKickSession",
		50: "k_EResultAlreadyLoggedInElsewhere",
		51: "k_EResultSuspended",
		52: "k_EResultCancelled",
		53: "k_EResultDataCorruption",
		54: "k_EResultDiskFull",
		55: "k_EResultRemoteCallFailed",
		56: "k_EResultPasswordUnset",
		57: "k_EResultExternalAccountUnlinked",
		58: "k_EResultPSNTicketInvalid",
		59: "k_EResultExternalAccountAlreadyLinked",
		60: "k_EResultRemoteFileConflict"
	}
	return str(names.get(code, "k_EResultUnknown_" + str(code)))


func _log_steam_message_send_failure(target_steam_id: String, msg_type: String, bytes: int, send_flags: int, channel: int, result, result_name: String) -> void:
	var retry_left = 0
	if _client_hello_retry_until_msec > 0:
		retry_left = max(0, _client_hello_retry_until_msec - OS.get_ticks_msec())


func _get_p2p_channel_for_message_type(msg_type: String) -> int:
	if msg_type == "lobby_ping_request" or msg_type == "lobby_ping_response":
		return P2P_CHANNEL_LOBBY_BROWSER
	if msg_type == "battle_input" or msg_type == "battle_snapshot" or msg_type == "battle_reliable_events" or msg_type == "battle_terminal_state" or msg_type == "damage_claim_batch" or msg_type == "player_hp_state" or msg_type == "player_state" or msg_type == "entity_kill_claim" or msg_type == "boss_damage_report" or msg_type == "pickup_claim" or msg_type == "battle_entity_resync_request":
		return P2P_CHANNEL_BATTLE
	return P2P_CHANNEL_MENU


func _on_network_messages_session_request(remote_steam_id = 0) -> void:
	var steam_id = _extract_steam_id_value(remote_steam_id)
	if _steam != null and _steam_has_method("acceptSessionWithUser") and steam_id != "" and steam_id != "0":
		var ok = _steam.acceptSessionWithUser(int(steam_id))
		_accepted_p2p_sessions[steam_id] = ok


func _on_network_messages_session_failed(remote_steam_id = 0, session_error = 0, end_reason = 0, debug_message = "") -> void:
	# GodotSteam builds using ISteamNetworkingMessages can emit this signal with
	# either two or four arguments. Keep the signature wide enough so a failed
	# session does not throw and leave the Client stuck on the joining overlay.
	var steam_id = _extract_steam_id_value(remote_steam_id)
	if steam_id == "" and typeof(session_error) == TYPE_DICTIONARY:
		steam_id = _extract_steam_id_value(session_error)

	if steam_id == "" or steam_id == "0" or steam_id == _self_steam_id:
		return

	_reset_steam_messages_session_with_peer(steam_id, "session_failed")

	if _lobby_id == 0:
		return

	if _is_game_host():
		if _member_list_has_steam_id(steam_id):
			_remember_host_remote_id(steam_id)
			_schedule_host_phase_resend_after_session_recovery(steam_id)
	else:
		var host_id = _get_game_host_steam_id()
		if host_id != "" and steam_id == host_id:
			_client_hello_retry_until_msec = OS.get_ticks_msec() + CLIENT_HELLO_RETRY_DURATION_MSEC
			_last_client_hello_retry_msec = 0
			call_deferred("_send_client_hello_to_host")


func _schedule_host_phase_resend_after_session_recovery(steam_id: String) -> void:
	if steam_id == "" or steam_id == "0":
		return
	call_deferred("_resend_host_phase_after_session_recovery", steam_id)
	var tree = get_tree()
	if tree == null:
		return
	var timer_a = tree.create_timer(0.35)
	timer_a.connect("timeout", self, "_resend_host_phase_after_session_recovery", [steam_id])
	var timer_b = tree.create_timer(1.25)
	timer_b.connect("timeout", self, "_resend_host_phase_after_session_recovery", [steam_id])


func _resend_host_phase_after_session_recovery(steam_id: String) -> void:
	if not _is_game_host() or _lobby_id == 0:
		return
	if steam_id == "" or steam_id == _self_steam_id:
		return
	if not _member_list_has_steam_id(steam_id):
		return
	_prepare_steam_messages_session_with_peer(steam_id, "session_recovery_resend")
	_send_host_phase_setup_to_client(steam_id, true)
	_send_selection_state_to_client(steam_id, true)


func _poll_end_run_intercept() -> void:
	if not _has_active_online_session() or not _is_in_end_run_scene():
		_end_run_intercept_scene_id = 0
		_end_run_intercept_restart_button_id = 0
		_end_run_intercept_new_run_button_id = 0
		_end_run_intercept_exit_button_id = 0
		return
	var scene = get_tree().current_scene
	if not _is_live_node(scene):
		return
	var restart_button = _get_end_run_button(scene, "RestartButton")
	var new_run_button = _get_end_run_button(scene, "NewRunButton")
	var exit_button = _get_end_run_button(scene, "ExitButton")
	var scene_id = scene.get_instance_id()
	var restart_id = restart_button.get_instance_id() if _is_live_node(restart_button) else 0
	var new_run_id = new_run_button.get_instance_id() if _is_live_node(new_run_button) else 0
	var exit_id = exit_button.get_instance_id() if _is_live_node(exit_button) else 0
	var changed = scene_id != _end_run_intercept_scene_id or restart_id != _end_run_intercept_restart_button_id or new_run_id != _end_run_intercept_new_run_button_id or exit_id != _end_run_intercept_exit_button_id
	if changed:
		_end_run_intercept_scene_id = scene_id
		_end_run_intercept_restart_button_id = restart_id
		_end_run_intercept_new_run_button_id = new_run_id
		_end_run_intercept_exit_button_id = exit_id

	# Restart repeats the same build without the synchronized character-selection
	# handshake, so it is intentionally unavailable online. Host gets New Run and
	# Return to Lobby; clients only get Return to Lobby.
	if _is_live_node(restart_button):
		restart_button.set("disabled", true)
		if restart_button is CanvasItem:
			restart_button.visible = false
		if restart_button is Control:
			restart_button.focus_mode = Control.FOCUS_NONE

	if _is_live_node(new_run_button):
		var host_can_start_new_run = _is_game_host()
		new_run_button.set("disabled", not host_can_start_new_run)
		if new_run_button is CanvasItem:
			new_run_button.visible = host_can_start_new_run
		if new_run_button is Control:
			new_run_button.focus_mode = Control.FOCUS_ALL if host_can_start_new_run else Control.FOCUS_NONE

	if _is_live_node(exit_button):
		_disable_custom_button_auto_translation(exit_button)
		exit_button.text = _ui_text("return_to_lobby")
		exit_button.set("disabled", false)
		if exit_button is CanvasItem:
			exit_button.visible = true
		if exit_button is Control:
			exit_button.focus_mode = Control.FOCUS_ALL
		if exit_button.is_connected("pressed", scene, "_on_ExitButton_pressed"):
			exit_button.disconnect("pressed", scene, "_on_ExitButton_pressed")
		if not exit_button.is_connected("pressed", self, "_on_online_end_run_exit_pressed"):
			exit_button.connect("pressed", self, "_on_online_end_run_exit_pressed")

	if changed and not _is_game_host() and _is_live_node(exit_button) and exit_button is Control:
		exit_button.call_deferred("grab_focus")


func _get_end_run_button(scene: Node, button_name: String) -> Node:
	if not _is_live_node(scene):
		return null
	var button = scene.find_node(button_name, true, false)
	return button if _is_live_node(button) else null


func _on_online_end_run_exit_pressed() -> void:
	var scene = get_tree().current_scene
	if not _is_live_node(scene) or not _is_in_end_run_scene():
		return
	leave_lobby()
	if _is_live_node(scene) and scene.has_method("_on_ExitButton_pressed"):
		scene._on_ExitButton_pressed()
		return
	RunData.reset()
	get_tree().change_scene(MenuData.title_screen_scene)


func _poll_online_flow_lifecycle() -> void:
	if _lobby_id == 0 or not _online_flow_started:
		return

	var menu_sync = _get_menu_sync_manager()
	if menu_sync == null or not menu_sync.has_method("get_current_menu_screen"):
		return

	var screen = str(menu_sync.get_current_menu_screen())
	if _is_in_active_online_run_scene():
		_lock_online_run_slots("active_run_scene")
		_online_flow_left_since_msec = 0
		return

	if _is_in_end_run_scene():
		# Results are still part of the online session. Keep the lobby alive so the Host
		# can start a new run and restage all connected clients to character selection.
		_online_flow_left_since_msec = 0
		return

	if screen == "character_selection":
		_handle_online_character_selection_restage_after_new_run()
		_online_flow_left_since_msec = 0
		return

	var valid = screen == "weapon_selection" or screen == "difficulty_selection" or screen == "game" or screen.find("shop") != -1
	if valid:
		_online_flow_left_since_msec = 0
		return

	var now = OS.get_ticks_msec()
	if _online_run_slots_locked and not _is_scene_definitely_outside_online_run():
		_online_flow_left_since_msec = 0
		return

	if _online_flow_left_since_msec == 0:
		_online_flow_left_since_msec = now
		return

	if now - _online_flow_left_since_msec >= 1200:
		leave_lobby()


func _handle_online_character_selection_restage_after_new_run() -> void:
	# BaseEndRun._on_NewRunButton_pressed() calls RunData.reset(), which shrinks the
	# run back to SOLO/P1 before changing to CharacterSelection. During the previous
	# battle/shop we intentionally locked online slot mutation, so without this
	# restage pass the Host keeps the lock, never rebuilds P0/P2 from the Steam
	# lobby, and clients never receive a fresh character setup for the next run.
	if _lobby_id == 0:
		return

	if not _is_game_host():
		# Client layouts are rebuilt from the next host_character_setup. Make sure the
		# old battle/shop lock does not make OnlinePlayerSlotManager reject it.
		if _online_run_slots_locked:
			_unlock_online_run_slots()
			_sync_slot_manager_lock_flag()
		return

	var current = get_tree().current_scene
	var scene_id = current.get_instance_id() if current != null else 0
	var needs_restage = _online_run_slots_locked or _host_character_selection_slots_need_resync()
	if not needs_restage:
		return
	if scene_id != 0 and _last_online_character_selection_restage_scene_id == scene_id and not _online_run_slots_locked:
		return

	_unlock_online_run_slots()
	_sync_slot_manager_lock_flag()
	_reset_game_start_sync_state()
	_last_online_character_selection_restage_scene_id = scene_id
	_clear_retry_wave_sync_state("new_run_character_selection")
	_last_broadcast_selection_key = ""
	_sent_character_setup_key_by_steam_id.clear()
	_sent_weapon_setup_key_by_steam_id.clear()
	_sent_scene_transition_key_by_steam_id.clear()
	_last_battle_snapshot_send_msec = 0
	_last_battle_snapshot_sent_tick_by_steam_id.clear()
	_last_battle_reliable_sent_key_by_steam_id.clear()
	_last_battle_terminal_state_key_by_steam_id.clear()
	_last_battle_terminal_state_msec_by_steam_id.clear()

	# The slot layout can be stale even when Steam membership itself is unchanged.
	# Force one host-side sync so P0 and any remote placeholders are rebuilt.
	_refresh_lobby_members(true)
	_send_host_phase_messages_to_all(true)
	_broadcast_selection_state(true)


func _host_character_selection_slots_need_resync() -> bool:
	if not _is_game_host() or _lobby_id == 0:
		return false

	var remote_ids = _get_remote_ids_for_host_sync()
	var target_count = remote_ids.size() + 1
	if RunData.get_player_count() < target_count:
		return true
	if CoopService.connected_players.size() < target_count:
		return true

	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("get_player_index_for_steam_id"):
		for steam_id_value in remote_ids:
			var steam_id = str(steam_id_value)
			if steam_id == "" or steam_id == "0":
				continue
			if int(slot_manager.get_player_index_for_steam_id(steam_id)) < 0:
				return true

	return false


func _is_game_host() -> bool:
	if _online_role == "host":
		return true
	if _online_role == "client":
		return false
	return _is_lobby_owner and (_game_host_steam_id == "" or _game_host_steam_id == _self_steam_id)


func _has_active_online_session() -> bool:
	# Strict gate: local single-player / local COOP must not be treated as online just
	# because a previous menu flow flag is still set. Online systems are active only
	# while a real Steam lobby/join is present.
	return _lobby_id != 0 or _online_role == "host" or _online_role == "client" or _pending_join_lobby_id != 0


func _update_online_session_runtime_flag() -> void:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return
	tree.root.set_meta("brotato_online_session_active", _has_active_online_session())


func _get_game_host_steam_id() -> String:
	if _game_host_steam_id != "" and _game_host_steam_id != "0":
		return _game_host_steam_id
	var lobby_host = _read_lobby_game_host_steam_id()
	if lobby_host != "":
		_game_host_steam_id = lobby_host
		return _game_host_steam_id
	return _get_lobby_owner_id()


func _read_lobby_game_host_steam_id() -> String:
	if _steam == null or _lobby_id == 0 or not _steam_has_method("getLobbyData"):
		return ""
	var value = str(_steam.getLobbyData(_lobby_id, "host"))
	if value == "0":
		return ""
	return value


func _sync_slot_manager_lock_flag() -> void:
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("set_online_run_slots_locked"):
		slot_manager.set_online_run_slots_locked(_should_freeze_online_run_slots())


func _lock_online_run_slots(reason: String = "") -> void:
	if _online_run_slots_locked:
		return
	_online_run_slots_locked = true
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("set_online_run_slots_locked"):
		slot_manager.set_online_run_slots_locked(true)


func _unlock_online_run_slots() -> void:
	if not _online_run_slots_locked:
		var slot_manager_probe = _get_slot_manager()
		if slot_manager_probe != null and slot_manager_probe.has_method("set_online_run_slots_locked"):
			slot_manager_probe.set_online_run_slots_locked(false)
		return
	_online_run_slots_locked = false
	var slot_manager = _get_slot_manager()
	if slot_manager != null and slot_manager.has_method("set_online_run_slots_locked"):
		slot_manager.set_online_run_slots_locked(false)


func _should_freeze_online_run_slots() -> bool:
	# Official Continue uses coop_resume.tscn as the player-reconnect gate.
	# Even if the previous online run locked slot mutation during battle/shop,
	# remote placeholders must be insertable here so the vanilla CoopResume UI can
	# collect the saved COOP players and advance to CoopShop.
	if _is_in_official_coop_resume_scene():
		return false
	return _online_run_slots_locked or _is_in_active_online_run_scene()


func _log_slot_sync_skipped(reason: String) -> void:
	var now = OS.get_ticks_msec()
	if now - _last_slot_lock_skip_log_msec < 1000:
		return
	_last_slot_lock_skip_log_msec = now


func _is_in_game_scene() -> bool:
	var current = get_tree().current_scene
	if current == null:
		return false
	return str(current.filename) == "res://main.tscn"


func _clear_non_game_ui_button_refs() -> void:
	_lobby_toggle_button = null
	_lobby_toggle_panel = null
	_main_menu_online_button = null
	_main_menu_online_button_parent = null
	_character_invite_button = null
	_character_invite_button_parent = null
	_character_lobby_status_label = null
	_continue_invite_button = null
	_continue_invite_button_parent = null
	_continue_lobby_status_label = null
	_joining_overlay = null
	_joining_overlay_parent = null
	_joining_overlay_label = null
	_joining_overlay_active = false


func _is_selection_state_broadcast_screen(screen: String) -> bool:
	return screen == "character_selection" or screen == "weapon_selection" or screen == "difficulty_selection"


func _is_in_shop_scene() -> bool:
	var current = get_tree().current_scene
	if current == null:
		return false
	var filename = str(current.filename).to_lower()
	var node_name = str(current.name).to_lower()
	if filename.find("/shop") != -1 or filename.find("shop/") != -1:
		return true
	if node_name.find("shop") != -1:
		return true
	return false


func _is_in_active_online_run_scene() -> bool:
	# coop_resume.tscn is still Brotato's official player-reconnect gate, not the
	# mutable online run/shop itself. Remote placeholders must still be insertable
	# there so the vanilla CoopResume scene can advance to CoopShop.
	return _is_in_game_scene() or (_is_in_shop_scene() and not _is_in_official_coop_resume_scene())


func _is_in_end_run_scene() -> bool:
	var current = get_tree().current_scene
	if current == null:
		return false
	var filename = str(current.filename).to_lower()
	var node_name = str(current.name).to_lower()
	if filename.find("end_run") != -1 or filename.find("endrun") != -1:
		return true
	return node_name.find("endrun") != -1 or node_name.find("end_run") != -1


func _is_scene_definitely_outside_online_run() -> bool:
	var current = get_tree().current_scene
	if current == null:
		return false
	var filename = str(current.filename).to_lower()
	var node_name = str(current.name).to_lower()
	if filename.find("title_screen") != -1 or node_name.find("title") != -1:
		return true
	if filename.find("character_selection") != -1 or filename.find("weapon_selection") != -1 or filename.find("difficulty_selection") != -1:
		return true
	return false


func _current_scene_desc() -> String:
	var current = get_tree().current_scene
	if current == null:
		return "null"
	return str(current.name) + "|" + str(current.filename)


func _is_host_at_character_selection_for_lobby() -> bool:
	var menu_sync = _get_menu_sync_manager()
	if menu_sync != null and menu_sync.has_method("get_current_menu_screen"):
		if str(menu_sync.get_current_menu_screen()) == "character_selection":
			return true

	return _is_character_selection_scene()


func _is_character_selection_scene() -> bool:
	var current = get_tree().current_scene
	if current == null:
		return false
	var filename = str(current.filename).to_lower()
	var node_name = str(current.name).to_lower()
	return filename.find("character_selection") != -1 or node_name.find("characterselection") != -1


func _get_character_run_options_panel(current: Node = null) -> Node:
	if current == null:
		current = get_tree().current_scene
	if current == null:
		return null
	if _lobby_toggle_panel != null and is_instance_valid(_lobby_toggle_panel) and _lobby_toggle_panel.is_inside_tree():
		return _lobby_toggle_panel
	return current.get_node_or_null("MarginContainer/VBoxContainer/DescriptionContainer/RunOptionsPanel")


func _get_character_run_options_container(panel: Node) -> Node:
	if panel == null:
		return null
	return panel.get_node_or_null("MarginContainer/VBoxContainer/VBoxContainer")


func _poll_joining_overlay() -> void:
	var now = OS.get_ticks_msec()
	if now - _last_joining_overlay_ui_poll_msec < 100:
		_update_joining_overlay_state()
		return
	_last_joining_overlay_ui_poll_msec = now
	_update_joining_overlay_state()


func _update_joining_overlay_state() -> void:
	var current = get_tree().current_scene
	if current == null or _is_in_game_scene():
		_remove_joining_overlay()
		return

	if not _should_show_joining_overlay():
		_remove_joining_overlay()
		return

	if _joining_overlay_parent != current or _joining_overlay == null or not is_instance_valid(_joining_overlay):
		_remove_joining_overlay()
		_ensure_joining_overlay(current)

	if _joining_overlay != null and is_instance_valid(_joining_overlay):
		_update_joining_overlay_layout(_joining_overlay)
		_joining_overlay.visible = true
		_joining_overlay_active = true
		if _joining_overlay_label != null and is_instance_valid(_joining_overlay_label):
			_joining_overlay_label.text = _get_joining_overlay_text()
		if _joining_overlay.get_parent() != null:
			_joining_overlay.get_parent().move_child(_joining_overlay, _joining_overlay.get_parent().get_child_count() - 1)
		if _joining_overlay is Control:
			_joining_overlay.grab_focus()


func _should_show_joining_overlay() -> bool:
	if _is_in_game_scene() or _is_in_end_run_scene():
		# EndRun is a valid connected phase. Never cover its result controls with the
		# join/reconnect blocker, even if a stale hello-retry timer is still active.
		return false

	# Host path: main-menu 好友联机 just changed to character-selection and is still
	# creating/preparing the Steam lobby. Block the newly visible P1 selection UI.
	if _main_menu_online_start_pending:
		return true
	if _lobby_toggle_pending_create and not _lobby_toggle_close_after_create:
		return true

	# Client path: Steam join was requested, or lobby was joined but host setup / scene
	# apply has not reached an online menu yet. Block the local main menu while waiting.
	if _pending_join_lobby_id != 0 or _client_join_requested_lobby_id != 0:
		return true
	if _online_role == "client" and _lobby_id != 0:
		if _client_hello_retry_until_msec != 0:
			return true
		if not _is_client_in_usable_online_scene():
			return true

	return false


func _is_client_in_usable_online_scene() -> bool:
	var current = get_tree().current_scene
	if current == null:
		return false
	if _is_in_game_scene():
		return true
	var filename = str(current.filename).to_lower()
	var node_name = str(current.name).to_lower()
	if filename.find("character_selection") != -1 or node_name.find("characterselection") != -1:
		return true
	if filename.find("weapon_selection") != -1 or node_name.find("weaponselection") != -1:
		return true
	if filename.find("difficulty_selection") != -1 or node_name.find("difficultyselection") != -1:
		return true
	if filename.find("coop_resume") != -1 or node_name.find("coopresume") != -1 or node_name.find("coop_resume") != -1:
		return true
	if filename.find("shop") != -1 or node_name.find("shop") != -1:
		return true
	if _is_in_end_run_scene():
		return true
	return false


func _get_joining_overlay_text() -> String:
	if _online_role == "client" or _pending_join_lobby_id != 0 or _client_join_requested_lobby_id != 0:
		return _ui_text("joining_overlay_client")
	return _ui_text("joining_overlay_host")


func _ensure_joining_overlay(parent: Node) -> void:
	if parent == null:
		return

	var existing = parent.get_node_or_null("BrotatoOnlineJoiningOverlay")
	if existing != null and is_instance_valid(existing):
		_joining_overlay = existing
		_joining_overlay_parent = parent
		_joining_overlay_label = existing.get_node_or_null("Center/Panel/Label")
		return

	var overlay = Control.new()
	overlay.name = "BrotatoOnlineJoiningOverlay"
	overlay.pause_mode = Node.PAUSE_MODE_PROCESS
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.focus_mode = Control.FOCUS_ALL
	_update_joining_overlay_layout(overlay)

	var shade = ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0, 0, 0, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.anchor_left = 0.0
	shade.anchor_top = 0.0
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.margin_left = 0
	shade.margin_top = 0
	shade.margin_right = 0
	shade.margin_bottom = 0
	overlay.add_child(shade)

	var center = CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	center.anchor_left = 0.0
	center.anchor_top = 0.0
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.margin_left = 0
	center.margin_top = 0
	center.margin_right = 0
	center.margin_bottom = 0
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.rect_min_size = Vector2(360, 150)
	center.add_child(panel)

	var label = Label.new()
	label.name = "Label"
	label.text = _get_joining_overlay_text()
	label.align = Label.ALIGN_CENTER
	label.valign = Label.VALIGN_CENTER
	label.autowrap = true
	label.clip_text = false
	label.rect_min_size = Vector2(320, 110)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	label.hint_tooltip = ""
	if _main_menu_online_button != null and is_instance_valid(_main_menu_online_button) and _main_menu_online_button is Control:
		if _main_menu_online_button.has_font("font"):
			label.add_font_override("font", _main_menu_online_button.get_font("font"))
		if _main_menu_online_button.has_color("font_color"):
			label.add_color_override("font_color", _main_menu_online_button.get_color("font_color"))
	panel.add_child(label)

	parent.add_child(overlay)
	parent.move_child(overlay, parent.get_child_count() - 1)
	_joining_overlay = overlay
	_joining_overlay_parent = parent
	_joining_overlay_label = label
	_joining_overlay_active = true


func _update_joining_overlay_layout(overlay: Node) -> void:
	if overlay == null or not (overlay is Control):
		return
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.margin_left = 0
	overlay.margin_top = 0
	overlay.margin_right = 0
	overlay.margin_bottom = 0


func _remove_joining_overlay() -> void:
	_joining_overlay_active = false
	if _joining_overlay != null and is_instance_valid(_joining_overlay):
		_joining_overlay.queue_free()
	_joining_overlay = null
	_joining_overlay_parent = null
	_joining_overlay_label = null


func _get_character_coop_button(panel: Node = null) -> Node:
	if panel == null:
		panel = _get_character_run_options_panel()
	if panel == null:
		return null
	return panel.get_node_or_null("MarginContainer/VBoxContainer/VBoxContainer/CoopButton")


func _get_continue_player_info_container(current: Node = null) -> Node:
	if current == null:
		current = get_tree().current_scene
	if current == null:
		return null
	return current.get_node_or_null("MarginContainer/VBoxContainer/MarginContainer/VBoxContainer/PlayerInfoContainer")


func _should_show_character_lobby_status_label() -> bool:
	# Character-selection status is intentionally hidden for normal local/solo entry.
	# Show it only after the user has started the online flow or the lobby state is actionable.
	return _main_menu_online_start_pending or _lobby_toggle_pending_create or _lobby_id != 0 or _online_role != "none" or _last_lobby_create_failed_result != 0


func _get_lobby_status_text() -> String:
	var creating = _lobby_toggle_pending_create and not _lobby_toggle_close_after_create
	if creating and _lobby_id == 0:
		return _ui_text("status_creating_steam")

	if _main_menu_online_start_pending and _lobby_id == 0:
		return _ui_text("status_preparing")

	if _lobby_toggle_pending_create and _lobby_toggle_close_after_create:
		return _ui_text("status_close_after_creation")

	if _lobby_id != 0:
		var count = _members.size()
		if count <= 0:
			count = 1
		var text = _ui_text("status_open") % [count, MAX_LOBBY_MEMBERS]
		if not _get_auto_join_host_player_enabled():
			text += "\n" + _ui_text("status_auto_player_one_off")
		return text

	if _last_lobby_create_failed_result != 0:
		if _last_lobby_create_failed_result == -1:
			return _ui_text("status_failed_steam_not_ready")
		if _last_lobby_create_failed_result == -2:
			return _ui_text("status_failed_api_unavailable")
		return _ui_text("status_failed_code") % _last_lobby_create_failed_result

	return _ui_text("status_closed")


func _setup_lobby_status_label(label: Label, visual_source: Control = null) -> void:
	if label == null:
		return
	label.focus_mode = Control.FOCUS_NONE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = false
	label.autowrap = true
	label.align = Label.ALIGN_RIGHT
	label.valign = Label.VALIGN_CENTER
	label.rect_min_size = Vector2(320, 44)
	label.hint_tooltip = ""
	if visual_source != null and is_instance_valid(visual_source):
		if visual_source.has_font("font"):
			label.add_font_override("font", visual_source.get_font("font"))
		if visual_source.has_color("font_color"):
			label.add_color_override("font_color", visual_source.get_color("font_color"))


func _ensure_character_lobby_status_label(parent: Node) -> void:
	if parent == null:
		return

	# This label is injected as a direct child of the current character-selection scene.
	# Do not recursively scan the scene tree here; the UI poll already has the scene root.
	var existing = parent.get_node_or_null("BrotatoOnlineSteamLobbyStatusLabel")

	if existing != null and is_instance_valid(existing):
		if existing is Label:
			_character_lobby_status_label = existing
			_setup_lobby_status_label(_character_lobby_status_label, _character_invite_button)
		return

	var label = Label.new()
	label.name = "BrotatoOnlineSteamLobbyStatusLabel"
	_setup_lobby_status_label(label, _character_invite_button)
	parent.add_child(label)
	_character_lobby_status_label = label
	_update_character_lobby_status_label_layout(parent)
	_update_character_lobby_status_label_state()


func _update_character_lobby_status_label_layout(parent: Node) -> void:
	if parent == null or _character_lobby_status_label == null or not is_instance_valid(_character_lobby_status_label):
		return
	if not (_character_lobby_status_label is Control):
		return

	var label = _character_lobby_status_label
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.anchor_top = 0.0
	label.anchor_bottom = 0.0
	label.margin_left = -365
	label.margin_right = -25
	label.margin_top = 30
	label.margin_bottom = 86

	if _character_invite_button != null and is_instance_valid(_character_invite_button) and _character_invite_button is Control:
		label.margin_bottom = _character_invite_button.margin_top - 6
		label.margin_top = label.margin_bottom - 56


func _update_character_lobby_status_label_state() -> void:
	if _character_lobby_status_label == null or not is_instance_valid(_character_lobby_status_label):
		return
	if not _should_show_character_lobby_status_label():
		_character_lobby_status_label.visible = false
		_character_lobby_status_label.hint_tooltip = ""
		return
	_character_lobby_status_label.text = _get_lobby_status_text()
	_character_lobby_status_label.visible = true
	_character_lobby_status_label.hint_tooltip = ""


func _ensure_continue_lobby_status_label(parent: Node) -> void:
	if parent == null:
		return

	# This label is injected as a direct child of the current coop-resume scene.
	# Do not recursively scan the scene tree here; the UI poll already has the scene root.
	var existing = parent.get_node_or_null("BrotatoOnlineSteamContinueLobbyStatusLabel")

	if existing != null and is_instance_valid(existing):
		if existing is Label:
			_continue_lobby_status_label = existing
			_setup_lobby_status_label(_continue_lobby_status_label, _continue_invite_button)
		return

	var label = Label.new()
	label.name = "BrotatoOnlineSteamContinueLobbyStatusLabel"
	_setup_lobby_status_label(label, _continue_invite_button)
	parent.add_child(label)
	_continue_lobby_status_label = label
	_update_continue_lobby_status_label_layout(parent)
	_update_continue_lobby_status_label_state()


func _update_continue_lobby_status_label_layout(parent: Node) -> void:
	if parent == null or _continue_lobby_status_label == null or not is_instance_valid(_continue_lobby_status_label):
		return
	if not (_continue_lobby_status_label is Control):
		return

	var label = _continue_lobby_status_label
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.anchor_top = 0.0
	label.anchor_bottom = 0.0
	label.margin_left = -365
	label.margin_right = -25
	label.margin_top = 154
	label.margin_bottom = 210

	if _continue_invite_button != null and is_instance_valid(_continue_invite_button) and _continue_invite_button is Control:
		label.margin_top = _continue_invite_button.margin_bottom + 6
		label.margin_bottom = label.margin_top + 56


func _update_continue_lobby_status_label_state() -> void:
	if _continue_lobby_status_label == null or not is_instance_valid(_continue_lobby_status_label):
		return
	_continue_lobby_status_label.text = _get_lobby_status_text()
	_continue_lobby_status_label.visible = true
	_continue_lobby_status_label.hint_tooltip = ""


func _poll_character_invite_button() -> void:
	var now = OS.get_ticks_msec()
	if now - _last_character_invite_button_ui_poll_msec < 250:
		_update_character_invite_button_state()
		_update_character_lobby_status_label_state()
		_update_continue_invite_button_state()
		_update_continue_lobby_status_label_state()
		if not _should_show_character_lobby_status_label() or (_character_lobby_status_label != null and is_instance_valid(_character_lobby_status_label)):
			return
	_last_character_invite_button_ui_poll_msec = now

	var current = get_tree().current_scene
	if current == null or not _is_character_selection_scene():
		_character_invite_button = null
		_character_invite_button_parent = null
		_character_lobby_status_label = null
		return

	var should_show_status = _should_show_character_lobby_status_label()
	if _character_invite_button_parent != current or _character_invite_button == null or not is_instance_valid(_character_invite_button):
		_character_invite_button_parent = current
		_ensure_character_invite_button(current)

	if should_show_status and (_character_lobby_status_label == null or not is_instance_valid(_character_lobby_status_label)):
		_ensure_character_lobby_status_label(current)

	_update_character_invite_button_layout(current)
	if _character_lobby_status_label != null and is_instance_valid(_character_lobby_status_label):
		_update_character_lobby_status_label_layout(current)
	_update_character_invite_button_state()
	_update_character_lobby_status_label_state()
	_update_continue_invite_button_state()
	_update_continue_lobby_status_label_state()


func _ensure_character_invite_button(parent: Node) -> void:
	if parent == null:
		return

	# The injected invite button is a direct child of the character-selection scene.
	# Avoid recursive lookup on every scene re-entry.
	var existing = parent.get_node_or_null("BrotatoOnlineSteamInviteButton")

	if existing != null and is_instance_valid(existing):
		existing.hint_tooltip = ""
		_disable_custom_button_auto_translation(existing)
		_character_invite_button = existing
		if not _character_invite_button.is_connected("pressed", self, "_on_character_invite_button_pressed"):
			_character_invite_button.connect("pressed", self, "_on_character_invite_button_pressed")
		return

	var button = Button.new()
	button.name = "BrotatoOnlineSteamInviteButton"
	button.text = _ui_text("invite_friend")
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.hint_tooltip = ""
	button.clip_text = true
	button.align = 1
	button.rect_min_size = Vector2(190, 58)
	_disable_custom_button_auto_translation(button)

	var style_source = _get_character_coop_button(_get_character_run_options_panel(parent))
	if style_source != null and is_instance_valid(style_source):
		if style_source.has_font("font"):
			button.add_font_override("font", style_source.get_font("font"))
		if style_source.has_stylebox("hover_pressed"):
			button.add_stylebox_override("hover_pressed", style_source.get_stylebox("hover_pressed"))
		if style_source.has_stylebox("pressed"):
			button.add_stylebox_override("pressed", style_source.get_stylebox("pressed"))
		if style_source.has_stylebox("hover"):
			button.add_stylebox_override("hover", style_source.get_stylebox("hover"))
		if style_source.has_stylebox("normal"):
			button.add_stylebox_override("normal", style_source.get_stylebox("normal"))
		if style_source.has_color("font_color"):
			button.add_color_override("font_color", style_source.get_color("font_color"))

	parent.add_child(button)
	button.connect("pressed", self, "_on_character_invite_button_pressed")
	_character_invite_button = button
	_update_character_invite_button_layout(parent)
	_update_character_invite_button_state()
	_update_continue_invite_button_state()


func _update_character_invite_button_layout(parent: Node) -> void:
	if parent == null or _character_invite_button == null or not is_instance_valid(_character_invite_button):
		return
	if not (_character_invite_button is Control):
		return

	var button = _character_invite_button
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 0.0
	button.anchor_bottom = 0.0
	button.margin_left = -245
	button.margin_right = -25
	button.margin_top = 92
	button.margin_bottom = 150

	var panel = _get_character_run_options_panel(parent)
	if panel != null and is_instance_valid(panel) and panel is Control:
		var y = panel.rect_global_position.y - 74
		if y > 80:
			button.margin_top = y
			button.margin_bottom = y + 58


func _update_character_invite_button_state() -> void:
	if _character_invite_button == null or not is_instance_valid(_character_invite_button):
		return
	_character_invite_button.hint_tooltip = ""
	if _lobby_toggle_pending_create:
		_character_invite_button.text = _ui_text("creating")
		_character_invite_button.disabled = true
	else:
		_character_invite_button.text = _ui_text("invite_friend")
		_character_invite_button.disabled = false


func _on_character_invite_button_pressed() -> void:
	if _lobby_id != 0:
		open_invite_overlay()
		return

	if _lobby_toggle_pending_create:
		_open_invite_overlay_after_create = true
		return

	if not _is_host_at_character_selection_for_lobby():
		return

	create_lobby_and_invite(true)


func _poll_continue_invite_button() -> void:
	var now = OS.get_ticks_msec()
	if now - _last_continue_invite_button_ui_poll_msec < 250:
		_update_continue_invite_button_state()
		_update_continue_lobby_status_label_state()
		return
	_last_continue_invite_button_ui_poll_msec = now

	var current = get_tree().current_scene
	if current == null or not _is_in_official_coop_resume_scene():
		_continue_invite_button = null
		_continue_invite_button_parent = null
		_continue_lobby_status_label = null
		return

	if _continue_invite_button_parent != current or _continue_invite_button == null or not is_instance_valid(_continue_invite_button):
		_continue_invite_button_parent = current
		_ensure_continue_invite_button(current)
		_ensure_continue_lobby_status_label(current)

	_update_continue_invite_button_layout(current)
	_update_continue_lobby_status_label_layout(current)
	_update_continue_invite_button_state()
	_update_continue_lobby_status_label_state()


func _ensure_continue_invite_button(parent: Node) -> void:
	if parent == null:
		return

	# The injected continue invite button is a direct child of the coop-resume scene.
	# Avoid recursive lookup on every scene re-entry.
	var existing = parent.get_node_or_null("BrotatoOnlineSteamContinueInviteButton")

	if existing != null and is_instance_valid(existing):
		existing.hint_tooltip = ""
		_disable_custom_button_auto_translation(existing)
		_continue_invite_button = existing
		if not _continue_invite_button.is_connected("pressed", self, "_on_continue_invite_button_pressed"):
			_continue_invite_button.connect("pressed", self, "_on_continue_invite_button_pressed")
		return

	var button = Button.new()
	button.name = "BrotatoOnlineSteamContinueInviteButton"
	button.text = _ui_text("invite_friend")
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.hint_tooltip = ""
	button.clip_text = true
	button.align = 1
	button.rect_min_size = Vector2(190, 58)
	_disable_custom_button_auto_translation(button)

	if _character_invite_button != null and is_instance_valid(_character_invite_button):
		_copy_button_visuals(_character_invite_button, button)
	else:
		var info_panel = _get_continue_player_info_container(parent)
		if info_panel != null and is_instance_valid(info_panel):
			if info_panel.has_stylebox("panel"):
				button.add_stylebox_override("normal", info_panel.get_stylebox("panel"))

	parent.add_child(button)
	button.connect("pressed", self, "_on_continue_invite_button_pressed")
	_continue_invite_button = button
	_update_continue_invite_button_layout(parent)
	_update_continue_invite_button_state()


func _copy_button_visuals(source: Control, target: Control) -> void:
	if source == null or target == null:
		return
	if source.has_font("font"):
		target.add_font_override("font", source.get_font("font"))
	if source.has_stylebox("hover_pressed"):
		target.add_stylebox_override("hover_pressed", source.get_stylebox("hover_pressed"))
	if source.has_stylebox("pressed"):
		target.add_stylebox_override("pressed", source.get_stylebox("pressed"))
	if source.has_stylebox("hover"):
		target.add_stylebox_override("hover", source.get_stylebox("hover"))
	if source.has_stylebox("normal"):
		target.add_stylebox_override("normal", source.get_stylebox("normal"))
	if source.has_color("font_color"):
		target.add_color_override("font_color", source.get_color("font_color"))


func _update_continue_invite_button_layout(parent: Node) -> void:
	if parent == null or _continue_invite_button == null or not is_instance_valid(_continue_invite_button):
		return
	if not (_continue_invite_button is Control):
		return

	var button = _continue_invite_button
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 0.0
	button.anchor_bottom = 0.0
	button.margin_left = -245
	button.margin_right = -25
	button.margin_top = 92
	button.margin_bottom = 150

	var player_info = _get_continue_player_info_container(parent)
	if player_info != null and is_instance_valid(player_info) and player_info is Control:
		var y = player_info.rect_global_position.y - 100
		if y > 80:
			button.margin_top = y
			button.margin_bottom = y + 58


func _update_continue_invite_button_state() -> void:
	if _continue_invite_button == null or not is_instance_valid(_continue_invite_button):
		return

	_continue_invite_button.hint_tooltip = ""
	var creating = _lobby_toggle_pending_create and not _lobby_toggle_close_after_create
	_continue_invite_button.visible = true
	if creating and _lobby_id == 0:
		_continue_invite_button.text = _ui_text("creating")
		_continue_invite_button.disabled = true
	elif _lobby_id != 0:
		_continue_invite_button.text = _ui_text("invite_friend")
		_continue_invite_button.disabled = false
	elif _last_lobby_create_failed_result != 0:
		_continue_invite_button.text = _ui_text("recreate_lobby")
		_continue_invite_button.disabled = false
	else:
		_continue_invite_button.text = _ui_text("create_lobby")
		_continue_invite_button.disabled = false


func _on_continue_invite_button_pressed() -> void:
	if _lobby_id != 0:
		open_invite_overlay()
		return

	if _lobby_toggle_pending_create:
		_open_invite_overlay_after_create = true
		return

	if not _is_host_in_official_coop_continue_resume_scene():
		return

	create_lobby_and_invite(true)


func _poll_lobby_toggle_button() -> void:
	var now = OS.get_ticks_msec()
	if now - _last_lobby_toggle_ui_poll_msec < 250:
		_update_lobby_toggle_button_state()
		return
	_last_lobby_toggle_ui_poll_msec = now

	var current = get_tree().current_scene
	if current == null or not _is_character_selection_scene():
		_lobby_toggle_button = null
		_lobby_toggle_panel = null
		return

	var panel = _get_character_run_options_panel(current)
	if panel == null:
		_lobby_toggle_button = null
		_lobby_toggle_panel = null
		return

	if _lobby_toggle_panel != panel or _lobby_toggle_button == null or not is_instance_valid(_lobby_toggle_button):
		_lobby_toggle_panel = panel
		_ensure_lobby_toggle_button(panel)

	_update_lobby_toggle_button_state()


func _ensure_lobby_toggle_button(panel: Node) -> void:
	var existing = panel.get_node_or_null("BrotatoOnlineSteamLobbyButton")

	if existing != null and is_instance_valid(existing):
		existing.hint_tooltip = ""
		_disable_custom_button_auto_translation(existing)
		_lobby_toggle_button = existing
		if not _lobby_toggle_button.is_connected("toggled", self, "_on_lobby_toggle_button_toggled"):
			_lobby_toggle_button.connect("toggled", self, "_on_lobby_toggle_button_toggled")
		return

	var coop_button = _get_character_coop_button(panel)
	var parent = null
	if coop_button != null:
		parent = coop_button.get_parent()
	if parent == null:
		parent = _get_character_run_options_container(panel)
	if parent == null:
		return

	var button = CheckButton.new()
	button.name = "BrotatoOnlineSteamLobbyButton"
	button.text = _ui_text("friend_join_toggle")
	button.clip_text = true
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.hint_tooltip = ""
	button.rect_min_size = Vector2(260, 70)
	_disable_custom_button_auto_translation(button)

	if coop_button != null and is_instance_valid(coop_button):
		button.rect_min_size = coop_button.rect_min_size
		button.size_flags_horizontal = coop_button.size_flags_horizontal
		button.size_flags_vertical = coop_button.size_flags_vertical
		if coop_button.has_font("font"):
			button.add_font_override("font", coop_button.get_font("font"))
		if coop_button.has_stylebox("hover_pressed"):
			button.add_stylebox_override("hover_pressed", coop_button.get_stylebox("hover_pressed"))
		if coop_button.has_stylebox("pressed"):
			button.add_stylebox_override("pressed", coop_button.get_stylebox("pressed"))
		if coop_button.has_stylebox("hover"):
			button.add_stylebox_override("hover", coop_button.get_stylebox("hover"))
		if coop_button.has_stylebox("normal"):
			button.add_stylebox_override("normal", coop_button.get_stylebox("normal"))
		if coop_button.has_color("font_color"):
			button.add_color_override("font_color", coop_button.get_color("font_color"))

	parent.add_child(button)
	if coop_button != null and coop_button.get_parent() == parent:
		var target_index = coop_button.get_index() + 1
		parent.move_child(button, target_index)

	button.connect("toggled", self, "_on_lobby_toggle_button_toggled")
	_lobby_toggle_button = button
	_update_lobby_toggle_button_state()


func _on_lobby_toggle_button_toggled(button_pressed: bool) -> void:
	if _lobby_toggle_signal_guard:
		return

	if button_pressed:
		if _lobby_id != 0:
			_setup_join_presence()
			_update_lobby_toggle_button_state()
			return
		_lobby_toggle_close_after_create = false
		create_lobby_and_invite()
		return

	if _lobby_toggle_pending_create:
		_lobby_toggle_close_after_create = true
		_update_lobby_toggle_button_state()
		_update_character_lobby_status_label_state()
		_update_continue_lobby_status_label_state()
		return

	if _lobby_id != 0 or _has_active_online_session():
		leave_lobby()
	else:
		_clear_join_presence()
	_update_lobby_toggle_button_state()
	_update_character_lobby_status_label_state()
	_update_continue_lobby_status_label_state()


func _update_lobby_toggle_button_state() -> void:
	if _lobby_toggle_button == null or not is_instance_valid(_lobby_toggle_button):
		return

	_lobby_toggle_signal_guard = true
	_lobby_toggle_button.pressed = (_lobby_id != 0 or _lobby_toggle_pending_create) and not _lobby_toggle_close_after_create
	_lobby_toggle_button.disabled = false
	_lobby_toggle_button.text = _ui_text("friend_join_toggle")
	_lobby_toggle_button.hint_tooltip = ""
	_lobby_toggle_signal_guard = false


func _poll_main_menu_online_button() -> void:
	var now = OS.get_ticks_msec()
	if now - _last_main_menu_online_ui_poll_msec < 250:
		_update_main_menu_online_button_state()
		return
	_last_main_menu_online_ui_poll_msec = now

	var current = get_tree().current_scene
	if current == null:
		_main_menu_online_button = null
		_main_menu_online_button_parent = null
		return

	var start_button = _find_node_recursive(current, "StartButton")
	if start_button == null or not is_instance_valid(start_button):
		_main_menu_online_button = null
		_main_menu_online_button_parent = null
		return

	var parent = start_button.get_parent()
	if parent == null or str(parent.name) != "ButtonsLeft":
		_main_menu_online_button = null
		_main_menu_online_button_parent = null
		return

	if _main_menu_online_button_parent != parent or _main_menu_online_button == null or not is_instance_valid(_main_menu_online_button):
		_main_menu_online_button_parent = parent
		_ensure_main_menu_online_button(start_button)

	_update_main_menu_online_button_state()


func _ensure_main_menu_online_button(start_button: Node) -> void:
	if start_button == null:
		return
	var parent = start_button.get_parent()
	if parent == null:
		return

	var existing = parent.get_node_or_null("BrotatoOnlineMainMenuOnlineButton")
	if existing != null and is_instance_valid(existing):
		existing.hint_tooltip = ""
		_disable_custom_button_auto_translation(existing)
		_main_menu_online_button = existing
		if not _main_menu_online_button.is_connected("pressed", self, "_on_main_menu_online_button_pressed"):
			_main_menu_online_button.connect("pressed", self, "_on_main_menu_online_button_pressed")
		_update_main_menu_online_button_layout(parent, start_button, existing)
		return

	var button = Button.new()
	button.name = "BrotatoOnlineMainMenuOnlineButton"
	button.text = _ui_text("main_menu_online")
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = start_button.size_flags_horizontal
	button.size_flags_vertical = start_button.size_flags_vertical
	button.rect_min_size = Vector2(start_button.rect_min_size.x, 65)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.hint_tooltip = ""
	button.clip_text = true
	button.align = 0
	button.expand_icon = true
	_disable_custom_button_auto_translation(button)

	if start_button.get_script() != null:
		button.set_script(start_button.get_script())
	if start_button.has_font("font"):
		button.add_font_override("font", start_button.get_font("font"))
	if start_button.has_stylebox("hover_pressed"):
		button.add_stylebox_override("hover_pressed", start_button.get_stylebox("hover_pressed"))
	if start_button.has_stylebox("pressed"):
		button.add_stylebox_override("pressed", start_button.get_stylebox("pressed"))
	if start_button.has_stylebox("hover"):
		button.add_stylebox_override("hover", start_button.get_stylebox("hover"))
	if start_button.has_stylebox("normal"):
		button.add_stylebox_override("normal", start_button.get_stylebox("normal"))
	if start_button.has_color("font_color"):
		button.add_color_override("font_color", start_button.get_color("font_color"))

	parent.add_child(button)
	parent.move_child(button, start_button.get_index() + 1)
	button.connect("pressed", self, "_on_main_menu_online_button_pressed")
	_main_menu_online_button = button
	_update_main_menu_online_button_layout(parent, start_button, button)
	_update_main_menu_online_button_state()


func _update_main_menu_online_button_layout(parent: Node, start_button: Node, online_button: Node) -> void:
	if parent == null or start_button == null or online_button == null:
		return
	if parent.has_method("add_constant_override"):
		parent.add_constant_override("separation", 6)

	for child in parent.get_children():
		if not (child is Control):
			continue
		if str(child.name) == "empty_space":
			child.hide()
			child.rect_min_size = Vector2(0, 0)
			continue
		var min_size = child.rect_min_size
		if min_size.y > 65:
			min_size.y = 65
		child.rect_min_size = min_size

	var profile_button = parent.get_node_or_null("ProfileButton")
	var browser_button = parent.get_node_or_null("BrotatoOnlinePublicLobbyBrowserButton")
	var continue_button = parent.get_node_or_null("ContinueButton")
	var quit_button = parent.get_node_or_null("QuitButton")

	if start_button is Control:
		start_button.focus_neighbour_bottom = start_button.get_path_to(online_button)
		if continue_button != null and continue_button is Control and continue_button.visible:
			start_button.focus_neighbour_top = start_button.get_path_to(continue_button)
	if online_button is Control:
		online_button.focus_neighbour_top = online_button.get_path_to(start_button)
		if browser_button != null and browser_button is Control:
			online_button.focus_neighbour_bottom = online_button.get_path_to(browser_button)
		elif profile_button != null and profile_button is Control:
			online_button.focus_neighbour_bottom = online_button.get_path_to(profile_button)
		online_button.focus_neighbour_left = start_button.focus_neighbour_left
		online_button.focus_neighbour_right = start_button.focus_neighbour_right
	if browser_button != null and browser_button is Control:
		browser_button.focus_neighbour_top = browser_button.get_path_to(online_button)
		browser_button.focus_neighbour_left = online_button.focus_neighbour_left
		browser_button.focus_neighbour_right = online_button.focus_neighbour_right
		if profile_button != null and profile_button is Control:
			browser_button.focus_neighbour_bottom = browser_button.get_path_to(profile_button)
	if profile_button != null and profile_button is Control:
		if browser_button != null and browser_button is Control:
			profile_button.focus_neighbour_top = profile_button.get_path_to(browser_button)
		else:
			profile_button.focus_neighbour_top = profile_button.get_path_to(online_button)
	if continue_button != null and continue_button is Control:
		continue_button.focus_neighbour_bottom = start_button.get_path()
	if quit_button != null and quit_button is Control:
		if continue_button != null and continue_button is Control and continue_button.visible:
			quit_button.focus_neighbour_bottom = continue_button.get_path()
		else:
			quit_button.focus_neighbour_bottom = start_button.get_path()


func _update_main_menu_online_button_state() -> void:
	if _main_menu_online_button == null or not is_instance_valid(_main_menu_online_button):
		return

	if _lobby_toggle_pending_create:
		_main_menu_online_button.text = _ui_text("creating")
		_main_menu_online_button.hint_tooltip = ""
	elif _lobby_id != 0:
		_main_menu_online_button.text = _ui_text("main_menu_online")
		_main_menu_online_button.hint_tooltip = ""
	else:
		_main_menu_online_button.text = _ui_text("main_menu_online")
		_main_menu_online_button.hint_tooltip = ""

	_main_menu_online_button.disabled = false


func _on_main_menu_online_button_pressed() -> void:
	_main_menu_online_start_pending = true
	_main_menu_online_start_deadline_msec = OS.get_ticks_msec() + 6000

	if MusicManager != null:
		MusicManager.tween(-5)
	ProgressData.start_activity()
	var _error = get_tree().change_scene(MenuData.character_selection_scene)


func _poll_main_menu_online_start_pending() -> void:
	if not _main_menu_online_start_pending:
		return

	var now = OS.get_ticks_msec()
	if now > _main_menu_online_start_deadline_msec:
		_main_menu_online_start_pending = false
		return

	if not _is_character_selection_scene():
		return

	_ensure_character_selection_coop_enabled()

	if not _is_host_at_character_selection_for_lobby():
		return

	if _lobby_id != 0:
		_setup_join_presence()
		_main_menu_online_start_pending = false
		_update_lobby_toggle_button_state()
		return

	if not _lobby_toggle_pending_create:
		create_lobby_and_invite()
	_main_menu_online_start_pending = false


func _ensure_character_selection_coop_enabled() -> void:
	var current = get_tree().current_scene
	if current == null:
		return

	var coop_button = _get_character_coop_button(_get_character_run_options_panel(current))
	if coop_button != null and is_instance_valid(coop_button) and bool(coop_button.pressed):
		return

	if current.has_method("_play_mode_init"):
		current.call("_play_mode_init", RunData.PlayMode.COOP, false)
	elif coop_button != null and is_instance_valid(coop_button):
		coop_button.pressed = true
		if coop_button.has_signal("toggled"):
			coop_button.emit_signal("toggled", true)

	if coop_button != null and is_instance_valid(coop_button):
		coop_button.pressed = true

func _poll_official_continue_auto_lobby() -> void:
	if not AUTO_CREATE_LOBBY_ON_OFFICIAL_COOP_CONTINUE:
		return
	if _lobby_id != 0 or _lobby_toggle_pending_create or _online_role == "client":
		_official_continue_auto_lobby_armed = false
		_official_continue_auto_lobby_first_seen_msec = 0
		return
	if not _is_host_in_official_coop_continue_resume_scene():
		_official_continue_auto_lobby_armed = false
		_official_continue_auto_lobby_first_seen_msec = 0
		return

	var current = get_tree().current_scene
	var scene_id = current.get_instance_id() if current != null else 0
	if scene_id != 0 and scene_id == _official_continue_auto_lobby_done_for_scene_id:
		return

	if not _official_continue_auto_lobby_armed:
		_official_continue_auto_lobby_armed = true
		_official_continue_auto_lobby_first_seen_msec = OS.get_ticks_msec()
		return

	if OS.get_ticks_msec() - _official_continue_auto_lobby_first_seen_msec < OFFICIAL_COOP_CONTINUE_AUTO_LOBBY_DELAY_MSEC:
		return

	_official_continue_auto_lobby_done_for_scene_id = scene_id
	_official_continue_auto_lobby_armed = false
	_official_continue_auto_lobby_first_seen_msec = 0
	create_lobby_and_invite(false)


func _can_create_lobby_from_current_scene() -> bool:
	if _is_host_at_character_selection_for_lobby():
		return true
	if _is_host_in_official_coop_continue_resume_scene():
		return true
	return false


func _is_host_in_official_coop_continue_resume_scene() -> bool:
	if _online_role == "client":
		return false
	if RunData == null or not bool(RunData.is_coop_run):
		return false
	var current = get_tree().current_scene
	if current == null:
		return false
	var filename = str(current.filename).to_lower()
	var node_name = str(current.name).to_lower()
	if filename == "res://ui/menus/shop/coop_resume.tscn" or filename.find("coop_resume") != -1:
		return true
	return node_name.find("coopresume") != -1 or node_name.find("coop_resume") != -1


func _is_in_official_coop_resume_scene() -> bool:
	var current = get_tree().current_scene
	if current == null:
		return false
	var filename = str(current.filename).to_lower()
	var node_name = str(current.name).to_lower()
	return filename == "res://ui/menus/shop/coop_resume.tscn" or filename.find("coop_resume") != -1 or node_name.find("coopresume") != -1 or node_name.find("coop_resume") != -1


func _official_continue_players_ready() -> bool:
	if RunData == null or CoopService == null:
		return true
	var required = int(RunData.get_player_count())
	if required <= 1:
		return true
	return CoopService.connected_players.size() >= required


func _find_node_recursive(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if root.name == node_name:
		return root
	for child in root.get_children():
		if child is Node:
			var found = _find_node_recursive(child, node_name)
			if found != null:
				return found
	return null


func _handle_shortcuts() -> void:
	var now = OS.get_ticks_msec()
	if now - _last_key_time < 500:
		return

	# Only F6 is kept as a user-facing shortcut.
	# Non-F6 debug shortcuts and modifier variants are intentionally disabled.
	if Input.is_key_pressed(KEY_F6):
		_last_key_time = now
		create_lobby_and_invite()
		return


func _check_launch_join_args() -> void:
	if _checked_launch_args:
		return
	_checked_launch_args = true

	var args = OS.get_cmdline_args()
	var parsed_lobby_id = _parse_lobby_id_from_args(args)
	if parsed_lobby_id == 0:
		return

	join_lobby(parsed_lobby_id)


func _poll_startup_main_menu_ready() -> void:
	if _startup_main_menu_ready:
		return

	var tree = get_tree()
	if tree == null:
		return
	var current = tree.current_scene
	if current == null:
		return

	var start_button = _find_node_recursive(current, "StartButton")
	if start_button == null or not is_instance_valid(start_button):
		return
	var parent = start_button.get_parent()
	if parent == null or str(parent.name) != "ButtonsLeft":
		return

	# This is a one-way boot barrier. Do not close it again when leaving the main
	# menu, otherwise an invite received from another game screen would be blocked.
	_startup_main_menu_ready = true


func _consume_startup_join_if_ready() -> void:
	if not _startup_main_menu_ready or _startup_pending_join_lobby_id == 0:
		return

	var lobby_to_join = _startup_pending_join_lobby_id
	_startup_pending_join_lobby_id = 0
	join_lobby(lobby_to_join)


func _consume_pending_join_if_ready() -> void:
	if _pending_join_lobby_id == 0:
		return

	if not _ensure_steam_ready():
		return

	var lobby_to_join = _pending_join_lobby_id
	_pending_join_lobby_id = 0
	join_lobby(lobby_to_join)


func _parse_lobby_id_from_args(args: Array) -> int:
	for i in range(args.size()):
		var arg = str(args[i])
		if arg == "+connect_lobby" and i + 1 < args.size():
			return _normalize_lobby_id(args[i + 1])

		var parsed_from_arg = _parse_lobby_id_from_connect_string(arg)
		if parsed_from_arg != 0:
			return parsed_from_arg

	return 0


func _parse_lobby_id_from_connect_string(connect_string: String) -> int:
	var s = connect_string.strip_edges()
	if s == "":
		return 0

	if s.begins_with(LOBBY_CONNECT_PREFIX):
		return _normalize_lobby_id(s.substr(LOBBY_CONNECT_PREFIX.length(), s.length()))

	if s.begins_with("connect_lobby:"):
		return _normalize_lobby_id(s.substr("connect_lobby:".length(), s.length()))

	if s.begins_with("lobby:"):
		return _normalize_lobby_id(s.substr("lobby:".length(), s.length()))

	if s.find("+connect_lobby") != -1:
		var parts = s.split(" ", false)
		for i in range(parts.size()):
			if parts[i] == "+connect_lobby" and i + 1 < parts.size():
				return _normalize_lobby_id(parts[i + 1])

	return _normalize_lobby_id(s)


func _make_lobby_connect_string(lobby_id) -> String:
	return LOBBY_CONNECT_PREFIX + str(lobby_id)


func _normalize_lobby_id(value) -> int:
	var s = str(value).strip_edges()
	if s == "" or s == "0":
		return 0

	# Godot 3 int is 64-bit on the target builds used by Brotato/GodotSteam.
	# If this ever truncates on a specific build, keep lobby_id as String and pass String to joinLobby instead.
	return int(s)


func _get_steam_const(name: String, fallback: int) -> int:
	if _steam == null:
		return fallback

	if name == "LOBBY_TYPE_PRIVATE":
		return 0
	if name == "LOBBY_TYPE_FRIENDS_ONLY":
		return 1
	if name == "LOBBY_TYPE_PUBLIC":
		return 2

	return fallback


func _get_menu_sync_manager() -> Node:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineMenuSyncManager")


func _get_slot_manager() -> Node:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineOnlinePlayerSlotManager")


func _get_online_input_manager() -> Node:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineOnlineInputManager")


func _get_brotato_online_api() -> Node:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineAPI")


func _get_quick_chat_manager() -> Node:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineQuickChatWheel")


func _get_state_snapshot_manager() -> Node:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineStateSnapshot")


func _get_battle_replica_manager() -> Node:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineBattleReplicaManager")


func _get_battle_ghost_layer() -> Node:
	var parent = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("BrotatoOnlineBattleGhostLayer")
