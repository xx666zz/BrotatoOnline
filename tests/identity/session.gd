extends Node
const AUTO_CREATE_LOBBY_ON_OFFICIAL_COOP_CONTINUE = true
const MAX_LOBBY_MEMBERS = 4
const LAN_PROTOCOL_VERSION = 3
const NETWORK_PROTOCOL_VERSION = "5.0.0"
const P2P_CHANNEL_MENU = 0
var _self_steam_id = "1"
var _online_role = "host"
var _session_active = true
var _pending_lan_join = false
var _lan_transport = null
var _lan_identity_challenges = {}
var _connection_by_peer_key = {}
var _peer_key_by_connection = {}
var _connections = {}
var _session_remote_peer_keys = []
var _host_known_remote_ids = []
var _kicked_departing_peer_keys = {}
var _rejected_peer_keys = {}
var _last_broadcast_selection_key = ""
var _sent_scene_transition_key_by_steam_id = {}
var _seen_client_hello_by_steam_id = {}
var frozen = false
var received_sender = ""
var failures = []
var welcomes = []
var kicked = []
func detach_kicked_peer(key):
	kicked.append(key)
	_seen_client_hello_by_steam_id.erase(key)
func is_online_session_active():
	return _session_active
func is_game_host():
	return _online_role == "host"
func _is_game_host():
	return is_game_host()
func get_self_steam_id():
	return _self_steam_id
func _get_slot_manager():
	return get_parent().get_node("BrotatoOnlineOnlinePlayerSlotManager")
func get_session_member_count():
	return max(1, _get_slot_manager().get_local_player_indices().size()) + _session_remote_peer_keys.size()
func _should_freeze_online_run_slots():
	return frozen
func _lock_online_run_slots(_reason):
	frozen = true
func _unlock_online_run_slots():
	frozen = false
func _remember_host_remote_id(key):
	if not _host_known_remote_ids.has(key):
		_host_known_remote_ids.append(key)
func _publish_session_metadata():
	pass
func _sync_host_coop_slots_from_lobby():
	pass
func get_lobby_state():
	return "shop"
func _get_wire_session_id():
	return "test-session"
func get_peer_display_name(key):
	return "Player " + key
func _handle_client_host_disconnect(_reason):
	pass
func _handle_transport_welcome(_transport, _peer, message):
	if not bool(message.get("identity_required", false)):
		welcomes.append(message)
	_apply_transport_welcome(_transport, _peer, message)
func _handle_transport_session_id(_transport, _message):
	pass
func _handle_raw_p2p_packet(packet):
	received_sender = str(packet.sender)
	var message = parse_json(packet.bytes.get_string_from_utf8())
	if typeof(message) == TYPE_DICTIONARY and str(message.get("msg_type", "")) == "hello":
		_seen_client_hello_by_steam_id[received_sender] = true
func _ui_text(key):
	return key
func _show_join_failure(text):
	failures.append(text)
const DEFAULT_LAN_PORT = 27462
const LAN_DISCOVERY_PORT = 27463
const LOBBY_TYPE_FRIENDS_ONLY_FALLBACK = 1
const LOBBY_TYPE_PUBLIC_FALLBACK = 2
const LOBBY_JOIN_TIMEOUT_MSEC = 12000
const OFFICIAL_COOP_CONTINUE_AUTO_LOBBY_DELAY_MSEC = 300
var _steam = null
var _steam_transport = null
var _lan_discovery = null
var _session_id = ""
var _lan_game_port = DEFAULT_LAN_PORT
var _lobby_id = 0
var _is_lobby_owner = false
var _game_host_steam_id = ""
var _members = []
var _open_invite_overlay_after_create = false
var _startup_pending_join_lobby_id = 0
var _pending_join_lobby_id = 0
var _client_join_requested_lobby_id = 0
var _client_join_request_started_msec = 0
var _accepted_p2p_sessions = {}
var _pending_received_menu_focus_by_sender = {}
var _pending_received_menu_focus_order = []
var _online_flow_started = false
var _online_flow_left_since_msec = 0
var _sent_character_setup_key_by_steam_id = {}
var _sent_weapon_setup_key_by_steam_id = {}
var _full_item_list_scene_sync_required_by_steam_id = {}
var _pending_p2p_chunk_sends = []
var _incoming_p2p_chunks = {}
var _player_list_enabled_by_peer_key = {}
var _client_seen_host_setup_key_by_sender = {}
var _client_seen_host_setup_msec_by_sender = {}
var _last_selection_request_reply_msec_by_steam_id = {}
var _last_selection_request_setup_msec_by_steam_id = {}
var _browser_ping_last_reply_msec_by_steam_id = {}
var _last_battle_snapshot_send_msec = 0
var _last_battle_snapshot_sent_tick_by_steam_id = {}
var _last_battle_reliable_sent_key_by_steam_id = {}
var _client_battle_snapshot_rx_count = 0
var _last_client_battle_snapshot_rx_log_msec = 0
var _last_client_battle_snapshot_rx_tick = -1
var _lobby_toggle_pending_create = false
var _lobby_toggle_close_after_create = false
var _last_lobby_create_failed_result = 0
var _official_continue_auto_lobby_armed = false
var _official_continue_auto_lobby_first_seen_msec = 0
var _official_continue_auto_lobby_done_for_scene_id = 0
var _last_battle_terminal_state_key_by_steam_id = {}
var _last_battle_terminal_state_msec_by_steam_id = {}
# Unrelated scene/Steam side effects are stubbed; admission, handshake,
# timeout, creation, leave, and resume decisions are appended from production.
var hello_starts = 0
var hello_sends = 0
func open_invite_overlay():
	pass
func _steam_has_method(method):
	return _steam != null and _steam.has_method(method)
func _get_lobby_owner_id():
	return _self_steam_id
func _start_client_hello_retry():
	hello_starts += 1
func _send_client_hello_to_host():
	hello_sends += 1
func _broadcast_transport_session_id(_a=null, _b=null, _c=null):
	return null
func _bump_online_session_generation(_a=null, _b=null, _c=null):
	return null
func _clear_join_presence(_a=null, _b=null, _c=null):
	return null
func _clear_pending_join_request(_a=null, _b=null, _c=null):
	return null
func _clear_retry_wave_sync_state(_a=null, _b=null, _c=null):
	return null
func _close_tracked_p2p_sessions(_a=null, _b=null, _c=null):
	return null
func _drain_stale_p2p_packets(_a=null, _b=null, _c=null):
	return null
func _ensure_steam_ready(_a=null, _b=null, _c=null):
	return null
func _get_battle_replica_manager(_a=null, _b=null, _c=null):
	return null
func _get_menu_sync_manager(_a=null, _b=null, _c=null):
	return null
func _get_mod_settings_manager(_a=null, _b=null, _c=null):
	return null
func _get_online_input_manager(_a=null, _b=null, _c=null):
	return null
func _get_public_lobby_enabled(_a=null, _b=null, _c=null):
	return null
func _get_steam_const(_a=null, _b=null, _c=null):
	return null
func _is_host_at_character_selection_for_lobby(_a=null, _b=null, _c=null):
	return null
func _member_list_has_steam_id(_a=null, _b=null, _c=null):
	return null
func _poll_online_flow_lifecycle(_a=null, _b=null, _c=null):
	return null
func _reset_game_start_sync_state(_a=null, _b=null, _c=null):
	return null
func _reset_lobby_metadata_cache(_a=null, _b=null, _c=null):
	return null
func _reset_transient_online_state_for_new_session(_a=null, _b=null, _c=null):
	return null
func _restore_client_retry_wave_setting_override(_a=null, _b=null, _c=null):
	return null
func _set_lobby_joinable_if_changed(_a=null, _b=null, _c=null):
	return null
func _set_lobby_metadata_if_changed(_a=null, _b=null, _c=null):
	return null
func _setup_join_presence(_a=null, _b=null, _c=null):
	return null
func _setup_lobby_data(_a=null, _b=null, _c=null):
	return null
func _stop_client_hello_retry(_a=null, _b=null, _c=null):
	return null
func _update_character_invite_button_state(_a=null, _b=null, _c=null):
	return null
func _update_character_lobby_status_label_state(_a=null, _b=null, _c=null):
	return null
func _update_continue_invite_button_state(_a=null, _b=null, _c=null):
	return null
func _update_continue_lobby_status_label_state(_a=null, _b=null, _c=null):
	return null
func _update_lobby_owner_state(_a=null, _b=null, _c=null):
	return null
func _update_lobby_toggle_button_state(_a=null, _b=null, _c=null):
	return null
func _update_online_session_runtime_flag(_a=null, _b=null, _c=null):
	return null
func _update_self_steam_id(_a=null, _b=null, _c=null):
	return null
