extends Node

var checks = 0
var failures = 0

func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	DebugService.disable_saving = true
	get_tree().create_timer(45).connect("timeout", self, "_timeout")
	call_deferred("_run")

func _timeout() -> void:
	printerr("RETRY_RELOAD_FAIL: watchdog")
	get_tree().quit(2)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("RETRY_RELOAD_FAIL: " + label)
	else:
		print("RETRY_RELOAD_PASS: " + label)

func _settle():
	for _i in 6:
		yield(get_tree(), "idle_frame")

func _setup_run() -> void:
	RunData.reset()
	RunData.set_player_count(2, true)
	RunData.set_coop_run(true)
	CoopService.connected_players.clear()
	for i in 2:
		CoopService.connected_players.append([7 if i == 0 else i - 1, 0 if i == 0 else 1])
		RunData.add_character(load("res://items/characters/well_rounded/well_rounded_data.tres"), i)
		RunData.add_weapon(load("res://weapons/ranged/pistol/1/pistol_data.tres"), i, true)
	RunData.current_wave = 1
	RunData.is_endless_run = true
	ZoneService.set_current_zone(ZoneService.get_zone_data(RunData.current_zone).duplicate())
	ItemService.init_unlocked_pool()

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
	var initial = {"screen": "game", "scene_path": MenuData.game_scene, "run_config": {"player_count": 2}, "game_start_sync": {"start_id": 100}}
	manager.receive_menu_scene_state_from_host(initial)
	yield(_settle(), "completed")
	var old_scene = get_tree().current_scene
	var old_id = old_scene.get_instance_id()
	_check(old_scene.filename == MenuData.game_scene, "initial real battle scene loaded")
	old_scene._wave_timer.stop()
	old_scene._is_wave_failed = true
	old_scene._retry_wave.show()
	_save_frame("before-retry.png")
	var retry = initial.duplicate(true)
	retry["force_scene_reload"] = true
	retry["game_start_sync"] = {"start_id": 101, "mode": "retry_wave_commit"}
	manager.begin_game_start_guard(101, "regression_retry_prepare")
	_check(OS.get_ticks_msec() < manager._client_scene_change_in_flight_until_msec, "retry arrives inside old flight window")
	# Same RunData/path, different generation; exercise debounce as well as flight guard.
	manager.receive_menu_scene_state_from_host(retry)
	manager.receive_menu_scene_state_from_host(retry)
	yield(_settle(), "completed")
	var retry_id = get_tree().current_scene.get_instance_id()
	_check(retry_id != old_id, "new retry generation reloads failed scene immediately")
	_check(not get_tree().current_scene._retry_wave.visible, "retry UI gone after reload")
	_check(manager._pending_menu_scene_state_from_host.empty(), "successful retry consumed")
	get_tree().current_scene._wave_timer.stop()
	_save_frame("after-retry.png")
	var apply_count = manager.config_apply_count
	manager.receive_menu_scene_state_from_host(retry)
	yield(_settle(), "completed")
	_check(get_tree().current_scene.get_instance_id() == retry_id and manager.config_apply_count == apply_count, "duplicate commit does not reload or reapply RunData")
	# Ordinary scene refresh clears the flight marker; duplicates must still be safe.
	var refresh = retry.duplicate(true)
	refresh["force_scene_reload"] = false
	manager._client_scene_change_in_flight_until_msec = 0
	manager.receive_menu_scene_state_from_host(refresh)
	manager.receive_menu_scene_state_from_host(retry)
	yield(_settle(), "completed")
	_check(get_tree().current_scene.get_instance_id() == retry_id, "duplicate stays ignored after ordinary scene refresh")
	# A second new generation also reloads, then allow its 12s window to expire naturally.
	var next_retry = retry.duplicate(true)
	next_retry["game_start_sync"]["start_id"] = 102
	manager.receive_menu_scene_state_from_host(next_retry)
	yield(_settle(), "completed")
	var next_id = get_tree().current_scene.get_instance_id()
	_check(next_id != retry_id, "next retry generation reloads same path and config")
	get_tree().current_scene._wave_timer.stop()
	while OS.get_ticks_msec() <= manager._client_scene_change_in_flight_until_msec + 100:
		yield(get_tree(), "idle_frame")
	apply_count = manager.config_apply_count
	manager.receive_menu_scene_state_from_host(next_retry)
	var stale = retry.duplicate(true)
	stale["run_config"]["retries"] = 999
	manager.receive_menu_scene_state_from_host(stale)
	yield(_settle(), "completed")
	_check(get_tree().current_scene.get_instance_id() == next_id and manager.config_apply_count == apply_count, "late duplicate and older retry do not reload or roll back RunData")
	manager.reset_online_session_state("regression_new_session")
	manager.receive_menu_scene_state_from_host(retry)
	yield(_settle(), "completed")
	_check(get_tree().current_scene.get_instance_id() != next_id, "new session can reuse start IDs")
	print("RETRY_RELOAD_RESULT: ", checks, " checks, ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)

func _save_frame(filename: String) -> void:
	var folder = OS.get_environment("BROTATO_TEST_DIR")
	if folder.empty():
		return
	var frame = get_viewport().get_texture().get_data()
	frame.flip_y()
	frame.save_png(folder.plus_file(filename))
