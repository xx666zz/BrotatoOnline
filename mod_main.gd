extends Node

const MOD_DIR = "six666-BrotatoOnline"
const LOG_NAME = "six666-BrotatoOnline"

var mod_dir_path = ""


func _init() -> void:
	mod_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR)
	_install_player_local_outline_extension()
	_install_main_safe_pool_exit_extension()
	_install_entity_spawner_online_player_count_guard_extension()
	_install_jellyshield_safe_owner_extension()
	_install_follow_target_safe_parent_extension()
	_install_player_safe_room_cleanup_extension()
	_install_player_projectile_safe_speed_extension()
	_install_stats_manager_safe_queues_extension()
	_install_focus_emulator_safe_disconnect_extension()
	_install_pause_menu_focus_safe_extension()
	_install_coop_shop_online_ready_cancel_safe_extension()



func _install_main_safe_pool_exit_extension() -> void:
	var extension_path = mod_dir_path.plus_file("extensions/main_safe_pool_exit.gd")
	var file = File.new()
	if file.file_exists(extension_path):
		ModLoaderMod.install_script_extension(extension_path)
	else:
		pass


func _install_entity_spawner_online_player_count_guard_extension() -> void:
	var extension_path = mod_dir_path.plus_file("extensions/entity_spawner_online_player_count_guard.gd")
	var file = File.new()
	if file.file_exists(extension_path):
		ModLoaderMod.install_script_extension(extension_path)
	else:
		pass


func _install_jellyshield_safe_owner_extension() -> void:
	var extension_path = mod_dir_path.plus_file("extensions/jellyshield_safe_owner.gd")
	var file = File.new()
	if file.file_exists(extension_path):
		ModLoaderMod.install_script_extension(extension_path)
	else:
		pass


func _install_follow_target_safe_parent_extension() -> void:
	var extension_path = mod_dir_path.plus_file("extensions/follow_target_movement_safe_parent.gd")
	var file = File.new()
	if file.file_exists(extension_path):
		ModLoaderMod.install_script_extension(extension_path)
	else:
		pass


func _install_player_safe_room_cleanup_extension() -> void:
	var extension_path = mod_dir_path.plus_file("extensions/player_safe_room_cleanup.gd")
	var file = File.new()
	if file.file_exists(extension_path):
		ModLoaderMod.install_script_extension(extension_path)
	else:
		pass


func _install_player_projectile_safe_speed_extension() -> void:
	var extension_path = mod_dir_path.plus_file("extensions/player_projectile_safe_speed.gd")
	var file = File.new()
	if file.file_exists(extension_path):
		ModLoaderMod.install_script_extension(extension_path)
	else:
		pass


func _install_stats_manager_safe_queues_extension() -> void:
	var extension_path = mod_dir_path.plus_file("extensions/stats_manager_safe_queues.gd")
	var file = File.new()
	if file.file_exists(extension_path):
		ModLoaderMod.install_script_extension(extension_path)
	else:
		pass


func _install_focus_emulator_safe_disconnect_extension() -> void:
	var extension_path = mod_dir_path.plus_file("extensions/focus_emulator_safe_disconnect.gd")
	var file = File.new()
	if file.file_exists(extension_path):
		ModLoaderMod.install_script_extension(extension_path)
	else:
		pass


func _install_pause_menu_focus_safe_extension() -> void:
	var extension_path = mod_dir_path.plus_file("extensions/pause_menu_focus_safe.gd")
	var file = File.new()
	if file.file_exists(extension_path):
		ModLoaderMod.install_script_extension(extension_path)


func _install_coop_shop_online_ready_cancel_safe_extension() -> void:
	var extension_path = mod_dir_path.plus_file("extensions/coop_shop_online_ready_cancel_safe.gd")
	var file = File.new()
	if file.file_exists(extension_path):
		ModLoaderMod.install_script_extension(extension_path)



func _install_player_local_outline_extension() -> void:
	var extension_path = mod_dir_path.plus_file("extensions/player_local_outline.gd")
	var file = File.new()
	if file.file_exists(extension_path):
		ModLoaderMod.install_script_extension(extension_path)
	else:
		pass

func _ready() -> void:

	# 子弹、命中、伤害跳字、死亡表现逐步改为 Host presentation event 驱动。
	_add_i18n_manager()
	_add_version_adapter()
	_add_online_player_slot_manager()
	_add_menu_sync_manager()
	_add_steam_lobby_manager()
	_add_public_lobby_browser()
	_add_quick_chat_wheel_manager()
	_add_online_input_manager()
	_add_runtime_locator()
	_add_online_mod_settings_manager()
	_add_net_id_registry()
	_add_state_snapshot()
	_add_battle_replica_manager()
	_add_brotato_online_api()
	_remove_legacy_battle_ghost_layer_if_present()
	_add_pause_focus_alias_manager()


func _add_i18n_manager() -> void:
	_add_script_node(
		"BrotatoOnlineI18n",
		"scripts/brotato_online_i18n.gd",
		true
	)


func _add_version_adapter() -> void:
	_add_script_node(
		"BrotatoOnlineVersionAdapter",
		"scripts/brotato_version_adapter.gd",
		true
	)


func _add_online_player_slot_manager() -> void:
	_add_script_node(
		"BrotatoOnlineOnlinePlayerSlotManager",
		"scripts/online_player_slot_manager.gd",
		true
	)


func _add_menu_sync_manager() -> void:
	_add_script_node(
		"BrotatoOnlineMenuSyncManager",
		"scripts/menu_sync_manager.gd",
		true
	)


func _add_steam_lobby_manager() -> void:
	_add_script_node(
		"BrotatoOnlineSteamLobbyManager",
		"scripts/steam_lobby_manager.gd",
		true
	)


func _add_public_lobby_browser() -> void:
	_add_script_node(
		"BrotatoOnlinePublicLobbyBrowser",
		"scripts/public_lobby_browser.gd",
		true
	)


func _add_quick_chat_wheel_manager() -> void:
	_add_script_node(
		"BrotatoOnlineQuickChatWheel",
		"scripts/quick_chat_wheel.gd",
		false
	)


func _add_online_input_manager() -> void:
	_add_script_node(
		"BrotatoOnlineOnlineInputManager",
		"scripts/online_input_manager.gd",
		false
	)


func _add_runtime_locator() -> void:
	_add_script_node(
		"BrotatoOnlineRuntimeLocator",
		"scripts/runtime_locator.gd",
		false
	)



func _add_online_mod_settings_manager() -> void:
	_add_script_node(
		"BrotatoOnlineModSettingsManager",
		"scripts/online_mod_settings_manager.gd",
		false
	)


func _add_net_id_registry() -> void:
	_add_script_node(
		"BrotatoOnlineNetIdRegistry",
		"scripts/net_id_registry.gd",
		false
	)


func _add_state_snapshot() -> void:
	_add_script_node(
		"BrotatoOnlineStateSnapshot",
		"scripts/state_snapshot.gd",
		false
	)


func _add_battle_replica_manager() -> void:
	# Enemy/tree replicas are local combat targets for the owning player; Host remains authoritative for final death/drop state.
	_add_script_node(
		"BrotatoOnlineBattleReplicaManager",
		"scripts/battle_replica_manager.gd",
		false
	)



func _add_brotato_online_api() -> void:
	_add_script_node(
		"BrotatoOnlineAPI",
		"scripts/brotato_online_api.gd",
		true
	)

func _remove_legacy_battle_ghost_layer_if_present() -> void:
	var old = get_node_or_null("BrotatoOnlineBattleGhostLayer")
	if old != null and is_instance_valid(old):
		old.queue_free()
	var tree = get_tree()
	if tree != null and tree.root != null:
		var root_old = tree.root.get_node_or_null("BrotatoOnlineBattleGhostLayer")
		if root_old != null and is_instance_valid(root_old):
			root_old.queue_free()


func _add_pause_focus_alias_manager() -> void:
	# Minimal compatibility shim only for battle pause/options.
	# It does not process input and does not replace vanilla navigation.
	_add_script_node(
		"BrotatoOnlinePauseFocusAliasManager",
		"scripts/pause_focus_alias_manager.gd",
		true
	)


func _add_script_node(node_name: String, script_rel_path: String, required: bool) -> void:
	var script_path = mod_dir_path.plus_file(script_rel_path)
	var file = File.new()

	if not file.file_exists(script_path):
		if required:
			ModLoaderLog.error("Missing required script: " + script_path, LOG_NAME)
		else:
			pass
		return

	var script_res = load(script_path)
	if script_res == null:
		if required:
			ModLoaderLog.error("Failed to load required script: " + script_path, LOG_NAME)
		else:
			pass
		return

	var node = Node.new()
	node.name = node_name
	node.set_script(script_res)
	add_child(node)

