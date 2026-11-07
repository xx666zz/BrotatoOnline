extends "res://mods-unpacked/six666-BrotatoOnline/scripts/session_manager.gd"

# Capture wire messages so tests can drop/reorder delivery deterministically.
# Host/client state machines are production code; both share one test SceneTree.
var test_host = false
var test_menu = null
var sent = []
var host_entered = false
var terminal = false
var queued = false
var catchup_count = 0
var test_snapshot = null

class CatchupSnapshot extends Node:
	var requested_ids = []
	func force_fresh_snapshot_message() -> Dictionary:
		return {"tick": 7, "active_entity_ids": ["enemy_existing"], "wave_timer_state": {"time_left": 18.0}, "player_count": 2}
	func build_battle_entity_resync_payload(ids: Array) -> Dictionary:
		requested_ids = ids.duplicate()
		return {"entities": [{"net_id": "enemy_existing", "category": "enemy", "sync_mode": "birth_only"}], "births": [], "removed": [], "events": []}

func _bind_transports() -> void:
	pass

func _check_launch_join_args() -> void:
	pass

func _update_online_session_runtime_flag() -> void:
	pass

func _is_game_host() -> bool:
	return test_host

func _has_active_online_session() -> bool:
	return true

func _get_menu_sync_manager() -> Node:
	return test_menu

func _get_game_host_steam_id() -> String:
	return "host"

func _lock_online_run_slots(_reason: String = "") -> void:
	pass

func _sync_slot_manager_lock_flag() -> void:
	pass

func _apply_host_zone_sync_for_client(_message: Dictionary, _reason: String) -> void:
	pass

func _send_p2p_json(peer: String, message: Dictionary, reliable: bool = true) -> bool:
	sent.append({"peer": peer, "message": message.duplicate(true), "reliable": reliable})
	return true

func _has_pending_p2p_send_for_target_channel(_peer: String, _channel: int) -> bool:
	return queued

func _prepare_retry_wave_run_config_for_commit() -> Dictionary:
	return {"player_count": 2, "run_config_source": "retry_wave", "retry_start_id": int(_pending_host_game_start.start_id)}

func _execute_host_retry_wave_scene_restart(_start_id: int, _config: Dictionary) -> void:
	# The actual SceneTree belongs to the client in this single-process test.
	host_entered = true

func _ensure_host_retry_first_snapshot_gate_armed(_start_id: int, _reason: String, _arm_warmup: bool = false, _old_scene_id: int = 0) -> bool:
	return true

func _host_retry_first_snapshot_needs_gate() -> bool:
	return false

func _is_host_retry_battle_send_warmup_blocked() -> bool:
	return false

func _is_host_main_terminal_or_retry_state() -> bool:
	return terminal

func _get_state_snapshot_manager() -> Node:
	if not test_host:
		return null
	if test_snapshot == null:
		test_snapshot = CatchupSnapshot.new()
		add_child(test_snapshot)
	return test_snapshot

func _host_retry_allow_first_fresh_snapshot(_snapshot: Dictionary) -> bool:
	return true

func _send_current_battle_catchup(peer: String) -> bool:
	catchup_count += 1
	return ._send_current_battle_catchup(peer)
