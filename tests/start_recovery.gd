extends "res://mods-unpacked/six666-BrotatoOnline/tests/retry_reload.gd"

func _run():
	ProgressData.apply_settings()
	ProgressData.settings.pause_on_focus_lost = false
	ProgressData.settings.retry_wave = true
	DebugService.invulnerable = true
	_setup_run()
	var manager = load("res://mods-unpacked/six666-BrotatoOnline/tests/retry_reload_manager.gd").new()
	add_child(manager)
	manager.set_process(false)
	get_tree().current_scene = null
	manager.receive_menu_scene_state_from_host({"screen": "game", "scene_path": MenuData.game_scene, "run_config": {}, "game_start_sync": {"start_id": 100}})
	yield(_settle(), "completed")
	var old_scene = get_tree().current_scene
	old_scene._wave_timer.stop()
	old_scene._is_wave_failed = true
	old_scene._retry_wave.show()
	var old_id = old_scene.get_instance_id()
	var host = load("res://mods-unpacked/six666-BrotatoOnline/tests/start_recovery_session.gd").new()
	var client = load("res://mods-unpacked/six666-BrotatoOnline/tests/start_recovery_session.gd").new()
	host.test_host = true
	for session in [host, client]:
		add_child(session)
		session.set_process(false)
		session.set_process_input(false)
		session._session_active = true
	client.test_menu = manager
	client._self_steam_id = "client"
	host._self_steam_id = "host"
	host._connection_by_peer_key["client"] = {}
	host._pending_host_game_start = {"start_id": 101, "start_kind": "retry_wave", "remote_ids": ["client"], "retry_context_key": "1:0", "host_prepare_msec": OS.get_ticks_msec()}
	host._commit_host_game_start("regression")
	var first_commit = host.sent.back().message
	_check(host._host_unconfirmed_game_start_by_peer.has("client"), "start commit retained until client confirms")
	# Drop the first commit, then exercise the real timeout-to-host-start branch.
	host._pending_host_game_start.ready_deadline_msec = 0
	host._poll_host_game_start_sync()
	_check(host.host_entered and host._pending_host_game_start.empty(), "host starts after ready timeout")
	_check(host._should_drop_stale_client_battle_packet("client", {"msg_type": "player_state", "battle_start_id": 101}), "unready client cannot overwrite new battle state")
	host._host_game_start_recovery_sent_msec["client"] = 0
	host._poll_host_game_start_recovery()
	_check(host.sent.size() == 2 and host.sent.back().message.start_id == 101, "host automatically resends commit after entering battle")
	var resend_count = host.sent.size()
	host._poll_host_game_start_recovery()
	_check(host.sent.size() == resend_count, "recovery resend is rate limited")
	host.queued = true
	host._host_game_start_recovery_sent_msec["client"] = 0
	host._poll_host_game_start_recovery()
	_check(host.sent.size() == resend_count, "queued reliable packet is not duplicated")
	host.queued = false
	client._handle_game_start_commit_from_host(host.sent.back().message)
	client._poll_client_game_start_commit()
	client._handle_game_start_commit_from_host(first_commit)
	yield(_settle(), "completed")
	client._poll_client_game_scene_ready()
	var entered_id = get_tree().current_scene.get_instance_id()
	_check(entered_id != old_id and not get_tree().current_scene._retry_wave.visible, "late client automatically enters new battle")
	_check(client._client_active_battle_start_id == 101 and client.sent.size() == 1, "client confirms actual scene entry")
	get_tree().current_scene._wave_timer.stop()
	_save_frame("late-client-entered.png")
	# Drop the first ACK too; recovery must solicit another ACK without a reload.
	var config_count = manager.config_apply_count
	host._host_game_start_recovery_sent_msec["client"] = 0
	host._poll_host_game_start_recovery()
	client._handle_game_start_commit_from_host(host.sent.back().message)
	client._poll_client_game_start_commit()
	yield(_settle(), "completed")
	_check(client.sent.size() == 2 and get_tree().current_scene.get_instance_id() == entered_id and manager.config_apply_count == config_count, "lost ACK recovered without reload or RunData replay")
	host._handle_client_game_scene_ready("intruder", client.sent.back().message)
	host._handle_client_game_scene_ready("client", {"start_id": 100})
	_check(host._host_unconfirmed_game_start_by_peer.has("client"), "wrong peer or stale ACK cannot confirm battle entry")
	host._handle_client_game_scene_ready("client", client.sent.back().message)
	host._poll_host_game_start_recovery()
	_check(host._host_unconfirmed_game_start_by_peer.empty() and host.catchup_count == 1, "late ACK accepted after host start and battle catchup scheduled")
	_check(host.test_snapshot.requested_ids == ["enemy_existing"] and host.sent[host.sent.size() - 2].message.msg_type == "battle_reliable_events" and host.sent.back().message.msg_type == "battle_snapshot" and host.sent.back().message.battle_start_id == 101, "catchup sends existing entities and current-generation snapshot")
	resend_count = host.sent.size()
	host._poll_host_game_start_recovery()
	_check(host.sent.size() == resend_count and host.catchup_count == 1, "confirmed client stops receiving retries and catchup")
	_check(not host._should_drop_stale_client_battle_packet("client", {"msg_type": "player_state", "battle_start_id": 101}), "confirmed client battle messages accepted")
	var old_commit = first_commit.duplicate(true)
	old_commit.start_id = 100
	client._handle_game_start_commit_from_host(old_commit)
	client._handle_game_start_prepare_from_host({"start_id": 100})
	_check(client._client_expected_battle_start_id == 101 and client._pending_client_game_start_commit.empty(), "old prepare and commit cannot rewind client generation")
	host._host_unconfirmed_game_start_by_peer["client"] = first_commit
	host._host_game_start_recovery_sent_msec["client"] = 0
	host.terminal = true
	host._poll_host_game_start_recovery()
	_check(host.sent.size() == resend_count, "host never pulls client into a finished battle")
	host.terminal = false
	host._host_current_battle_start_id = 102
	host._poll_host_game_start_recovery()
	_check(host._host_unconfirmed_game_start_by_peer.empty(), "new battle generation retires old recovery")
	host._host_unconfirmed_game_start_by_peer["client"] = first_commit
	host._reset_game_start_sync_state()
	_check(host._host_unconfirmed_game_start_by_peer.empty() and host._host_pending_battle_catchup_by_peer.empty(), "session reset clears recovery state")
	print("START_RECOVERY_RESULT: ", checks, " checks, ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
