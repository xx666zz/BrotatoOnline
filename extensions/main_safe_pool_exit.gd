extends "res://main.gd"

# BrotatoOnline safety extension.
# 1) The online client can have already-freed / queued pickup nodes left in Main._pool
#    when the host-authoritative upgrade page advances to the shop. Vanilla Main._exit_tree()
#    blindly queue_free()s every pool entry, which can crash on those stale references.
# 2) Online placeholder COOP slots can reference remapped devices whose ui_pause_<device>
#    InputMap action was not created by vanilla InputService in this runtime. Vanilla
#    Main._check_for_pause() calls Input.is_action_just_released() directly and Godot logs
#    an error every physics frame when the action is missing. Guard the lookup first.


# Do not override Main._ready() here. In Godot 3.x script extension inheritance,
# the parent lifecycle callback can be invoked automatically; calling ._ready() from
# an extension can make vanilla Main._ready() run twice. That duplicates EntitySpawner.init(),
# leaves stale players in EntitySpawner._players, and breaks single-player battle entry.



# Host-side consumable drop pre-roll state. This is intentionally separate from
# vanilla _items_spawned_this_wave: vanilla is updated only when the consumable is
# really spawned, while this prediction counter is used to keep early rolls close
# to the original crate probability curve without waiting for a death packet.
var _brotato_online_drop_prediction_wave = -1
var _brotato_online_predicted_item_boxes_this_wave = 0


func _brotato_online_get_current_drop_wave() -> int:
	if RunData == null:
		return -1
	return int(RunData.current_wave)


func _brotato_online_clear_drop_meta(node: Node, reason: String = "") -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_meta("brotato_online_drop_result"):
		node.remove_meta("brotato_online_drop_result")


func _brotato_online_is_drop_result_valid_for_unit(drop_result, net_id: String = "", category: String = "") -> bool:
	if typeof(drop_result) != TYPE_DICTIONARY:
		return false
	var current_wave = _brotato_online_get_current_drop_wave()
	if current_wave >= 0 and int(drop_result.get("wave", -999999)) != current_wave:
		return false
	if net_id != "":
		var existing_net_id = str(drop_result.get("net_id", ""))
		if existing_net_id != "" and existing_net_id != net_id:
			return false
	if category != "" and category != "death_fallback":
		var existing_category = str(drop_result.get("category", ""))
		if existing_category != "" and existing_category != category:
			return false
	return true


func _brotato_online_get_valid_drop_meta(unit: Node, net_id: String = "", category: String = "") -> Dictionary:
	if unit == null or not is_instance_valid(unit):
		return {}
	if not unit.has_meta("brotato_online_drop_result"):
		return {}
	var existing = unit.get_meta("brotato_online_drop_result")
	if _brotato_online_is_drop_result_valid_for_unit(existing, net_id, category):
		return existing
	_brotato_online_clear_drop_meta(unit, "stale_drop_meta")
	return {}


func _brotato_online_get_run_players_data_size() -> int:
	if RunData == null:
		return 0
	var players_data_value = RunData.get("players_data")
	if typeof(players_data_value) == TYPE_ARRAY:
		return players_data_value.size()
	if RunData.has_method("get_player_count"):
		return int(RunData.get_player_count())
	return 0


func _brotato_online_get_authoritative_online_player_count() -> int:
	if not _brotato_online_is_online_session_active():
		return -1
	if CoopService == null:
		return -1
	var coop_count = int(CoopService.connected_players.size())
	if coop_count <= 0:
		return -1
	return int(clamp(coop_count, 1, 4))


func _brotato_online_set_run_player_count_exact(target_count: int, reason: String) -> void:
	if target_count <= 0:
		return
	if not _brotato_online_is_online_session_active():
		return
	if RunData == null or not RunData.has_method("set_player_count"):
		return
	var data_count = _brotato_online_get_run_players_data_size()
	if data_count == target_count:
		return
	RunData.set_player_count(target_count, false)
	if target_count > 1:
		RunData.play_mode = RunData.PlayMode.COOP
		RunData.set_coop_run(true)


func _brotato_online_repair_run_data_player_count_for_spawn(expected_count: int, reason: String) -> void:
	# Only an active online COOP layout is authoritative. Never use spawned
	# players.size() as a fallback, because repeated EntitySpawner.init() or stale
	# player nodes would turn a dirty runtime array into RunData.players_data.
	var authoritative_count = _brotato_online_get_authoritative_online_player_count()
	if authoritative_count <= 0:
		return
	_brotato_online_set_run_player_count_exact(authoritative_count, reason)


func _brotato_online_repair_run_data_player_count_from_coop(reason: String) -> void:
	var authoritative_count = _brotato_online_get_authoritative_online_player_count()
	if authoritative_count <= 0:
		return
	_brotato_online_set_run_player_count_exact(authoritative_count, reason)


func _brotato_online_free_stale_player_runtime_nodes(player: Node, reason: String) -> void:
	if player == null or not is_instance_valid(player):
		return
	var jellyshields = player.get("jellyshields")
	if typeof(jellyshields) == TYPE_ARRAY:
		for jellyshield in jellyshields:
			if jellyshield != null and is_instance_valid(jellyshield) and not jellyshield.is_queued_for_deletion():
				jellyshield.queue_free()
		jellyshields.clear()
	var effect_behaviors = player.get("effect_behaviors")
	if effect_behaviors != null and is_instance_valid(effect_behaviors) and effect_behaviors is Node:
		for child in effect_behaviors.get_children():
			if child != null and is_instance_valid(child) and not child.is_queued_for_deletion():
				effect_behaviors.remove_child(child)
				child.queue_free()


func _brotato_online_trim_spawned_players_to_authoritative_count(players: Array, reason: String) -> Array:
	var authoritative_count = _brotato_online_get_authoritative_online_player_count()
	if authoritative_count <= 0 or players.size() <= authoritative_count:
		return players

	var safe_players = []
	for i in range(players.size()):
		var player = players[i]
		if i < authoritative_count:
			safe_players.append(player)
		else:
			if player != null and is_instance_valid(player):
				_brotato_online_free_stale_player_runtime_nodes(player, reason)
				if not player.is_queued_for_deletion():
					player.queue_free()

	if _entity_spawner != null and is_instance_valid(_entity_spawner):
		_entity_spawner.set("_players", safe_players)
	return safe_players


func _on_EntitySpawner_players_spawned(players: Array) -> void:
	var safe_players = _brotato_online_trim_spawned_players_to_authoritative_count(players, "players_spawned")
	_brotato_online_repair_run_data_player_count_for_spawn(safe_players.size(), "players_spawned")
	._on_EntitySpawner_players_spawned(safe_players)


func _brotato_online_is_online_session_active() -> bool:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return false
	return bool(tree.root.get_meta("brotato_online_session_active", false))

func _brotato_online_get_steam_lobby_manager() -> Node:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	var direct = tree.root.get_node_or_null("ModLoader/six666-BrotatoOnline/BrotatoOnlineSteamLobbyManager")
	if direct != null and is_instance_valid(direct):
		return direct
	return _brotato_online_find_node_named(tree.root, "BrotatoOnlineSteamLobbyManager", 0)


func _brotato_online_get_battle_replica_manager() -> Node:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	var direct = tree.root.get_node_or_null("ModLoader/six666-BrotatoOnline/BrotatoOnlineBattleReplicaManager")
	if direct != null and is_instance_valid(direct):
		return direct
	return _brotato_online_find_node_named(tree.root, "BrotatoOnlineBattleReplicaManager", 0)

func _brotato_online_get_slot_manager() -> Node:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	var direct = tree.root.get_node_or_null("ModLoader/six666-BrotatoOnline/BrotatoOnlineOnlinePlayerSlotManager")
	if direct != null and is_instance_valid(direct):
		return direct
	return _brotato_online_find_node_named(tree.root, "BrotatoOnlineOnlinePlayerSlotManager", 0)


func _brotato_online_get_local_client_player_index() -> int:
	var slot_manager = _brotato_online_get_slot_manager()
	if slot_manager != null and slot_manager.has_method("get_local_mirrored_player_index"):
		return int(slot_manager.get_local_mirrored_player_index())
	return -1


func _brotato_online_get_player_index_from_node(p_player: Node, fallback: int = -1) -> int:
	if p_player == null or not is_instance_valid(p_player):
		return fallback
	var value = p_player.get("player_index")
	if value == null:
		return fallback
	return int(value)


func _brotato_online_is_owned_client_player(p_player: Node) -> bool:
	var local_index = _brotato_online_get_local_client_player_index()
	var player_index = _brotato_online_get_player_index_from_node(p_player, -1)
	if local_index < 0 or player_index < 0:
		# If ownership cannot be resolved, keep the old behavior instead of hiding a real local death.
		return true
	return player_index == local_index


func _brotato_online_send_client_player_death(p_player: Node, reason: String) -> void:
	if not _brotato_online_is_online_client():
		return
	var replica = _brotato_online_get_battle_replica_manager()
	if replica != null and replica.has_method("send_owned_player_terminal_state"):
		replica.send_owned_player_terminal_state(p_player, reason)


func _brotato_online_find_node_named(node: Node, target_name: String, depth: int) -> Node:
	if node == null or not is_instance_valid(node) or depth > 6:
		return null
	if node.name == target_name:
		return node
	for child in node.get_children():
		if not (child is Node):
			continue
		var found = _brotato_online_find_node_named(child, target_name, depth + 1)
		if found != null:
			return found
	return null


func _brotato_online_is_online_client() -> bool:
	if not _brotato_online_is_online_session_active():
		return false
	var steam = _brotato_online_get_steam_lobby_manager()
	if steam != null and steam.has_method("is_game_host"):
		return not bool(steam.is_game_host())
	return false


func _brotato_online_get_effect_behaviors_container(node: Node) -> Node:
	if node == null or not is_instance_valid(node):
		return null
	var direct = node.get("effect_behaviors")
	if direct != null and is_instance_valid(direct) and direct is Node:
		return direct
	var by_name = node.get_node_or_null("EffectBehaviors")
	if by_name != null and is_instance_valid(by_name):
		return by_name
	return null


func _brotato_online_should_sanitize_pool_node(node: Node) -> bool:
	if not _brotato_online_is_online_client():
		return false
	if node == null or not is_instance_valid(node):
		return false
	if not node.has_meta("brotato_online_host_entity"):
		return false
	if not bool(node.get_meta("brotato_online_host_entity")):
		return false
	var category = ""
	if node.has_meta("brotato_online_category"):
		category = str(node.get_meta("brotato_online_category"))
	return category == "" or category == "enemy" or category == "boss" or category == "neutral"


func _brotato_online_sanitize_pool_node(node: Node, reason: String) -> void:
	if not _brotato_online_should_sanitize_pool_node(node):
		return
	var container = _brotato_online_get_effect_behaviors_container(node)
	if container == null:
		return
	var children = container.get_children()
	if children.empty():
		return
	for child in children:
		if child == null or not is_instance_valid(child):
			continue
		container.remove_child(child)
		child.queue_free()


func _brotato_online_is_shop_scene_path(path: String) -> bool:
	if path == "":
		return false
	if RunData != null and RunData.has_method("get_shop_scene_path"):
		var shop_path = str(RunData.get_shop_scene_path())
		if shop_path != "" and path == shop_path:
			return true
	return path.to_lower().find("shop") != -1


func _brotato_online_should_block_local_wave_timeout() -> bool:
	if not _brotato_online_is_online_client():
		return false
	var replica = _brotato_online_get_battle_replica_manager()
	if replica != null and replica.has_method("should_block_local_wave_timeout_until_host_active"):
		return bool(replica.should_block_local_wave_timeout_until_host_active())
	return false


func _brotato_online_restart_wave_timer_while_waiting_for_host(reason: String) -> void:
	var timer = _wave_timer
	if timer == null or not is_instance_valid(timer):
		timer = get_node_or_null("WaveTimer")
	if timer != null and is_instance_valid(timer) and timer is Timer:
		timer.start(1.0)


func _on_WaveTimer_timeout() -> void:
	# Online clients must not let their local vanilla Timer complete the wave before
	# at least one clearly-active Host snapshot has been accepted for this battle.
	# Otherwise wave-1/pre-start Timer state can run Main._set_run_states() locally
	# and show an instant victory while Host is still in combat.
	if _brotato_online_should_block_local_wave_timeout():
		_brotato_online_restart_wave_timer_while_waiting_for_host("wait_host_active_snapshot")
		return
	._on_WaveTimer_timeout()


func _change_scene(path: String) -> void:
	# Online clients must not advance from the post-wave upgrade flow into Shop by
	# their own local Main coroutine. With 3+ players, one client can have an empty or
	# stale local _upgrades_to_process queue and emit options_processed before the
	# Host has finished every player's progression. The Host's menu_scene_state is the
	# authoritative shop transition and will call SceneTree.change_scene() directly.
	if _brotato_online_is_online_client() and _brotato_online_is_shop_scene_path(path):
		return

	._change_scene(path)

func _brotato_online_pool_or_free_client_pickup(node: Node, pool_id: int, reason: String) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_method("reset"):
		node.reset()
	else:
		node.hide()
		node.set_physics_process(false)
	if "already_picked_up" in node:
		node.already_picked_up = true
	if "attracted_by" in node:
		node.attracted_by = null
	if _pool != null and typeof(_pool) == TYPE_DICTIONARY and _pool.has(pool_id) and node.get_parent() != null:
		add_node_to_pool(node, pool_id)
	elif not node.is_queued_for_deletion():
		node.queue_free()


func _brotato_online_discard_client_end_wave_pickups(reason: String) -> void:
	if not _brotato_online_is_online_client():
		return
	if typeof(_active_golds) == TYPE_ARRAY and not _active_golds.empty():
		var golds = _active_golds.duplicate()
		_active_golds.clear()
		for gold in golds:
			_brotato_online_pool_or_free_client_pickup(gold, _gold_pool_id, reason)
	if typeof(_consumables) == TYPE_ARRAY and not _consumables.empty():
		var consumables = _consumables.duplicate()
		_consumables.clear()
		for consumable in consumables:
			_brotato_online_pool_or_free_client_pickup(consumable, _consumable_pool_id, reason)


func clean_up_room() -> void:
	if _brotato_online_is_online_client():
		# The Host already owns bonus-gold/material and item-box queues. Letting the
		# client run vanilla end-wave attraction briefly appends local boxes/materials,
		# which makes HUD icons multiply or flash before the Host correction arrives.
		_brotato_online_discard_client_end_wave_pickups("client_clean_up_room_pre")
	.clean_up_room()


func on_gold_picked_up(gold: Node, player_index: int) -> void:
	if _brotato_online_is_online_client() and bool(_cleaning_up):
		_active_golds.erase(gold)
		_brotato_online_pool_or_free_client_pickup(gold, _gold_pool_id, "client_cleanup_gold_signal")
		return
	.on_gold_picked_up(gold, player_index)


func on_consumable_picked_up(consumable: Node, player_index: int) -> void:
	if _brotato_online_is_online_client() and bool(_cleaning_up):
		_consumables.erase(consumable)
		_brotato_online_pool_or_free_client_pickup(consumable, _consumable_pool_id, "client_cleanup_consumable_signal")
		return
	.on_consumable_picked_up(consumable, player_index)


func _on_player_died(p_player, _args) -> void:
	if not _brotato_online_is_online_client():
		._on_player_died(p_player, _args)
		return

	# Client-side battle failure must not reset the local saved run. The Host owns the
	# authoritative retry/end-run flow. Vanilla Main._on_player_died() calls
	# ProgressData.reset_and_save_new_run_state() after clean_up_room(); on the client
	# this can erase run_v3 while Host battle packets are still in flight.
	if p_player == null or not is_instance_valid(p_player):
		return

	# On an online client, only the locally owned player is allowed to drive the
	# local failure / RetryWave flow. Remote proxy deaths are rendered from Host
	# snapshots; letting them enter vanilla Main._on_player_died() can clean up the
	# room locally and make the retry wave jump straight to shop.
	if not _brotato_online_is_owned_client_player(p_player):
		return

	# Main._on_player_died() immediately enters the local fail/cleanup path on the client.
	# Send the authoritative owned-player death before cleanup suspends battle replication.
	_brotato_online_send_client_player_death(p_player, "main_on_player_died")

	if _args != null:
		if _args.from is BulletHell:
			_args.is_bullet_hell = true
		else:
			_args.is_bullet_hell = false
		if p_player.get("player_index") != null and RunData != null and RunData.get("_players_die_args") != null:
			RunData._players_die_args[p_player.player_index] = _args

	var player_index = int(p_player.get("player_index")) if p_player.get("player_index") != null else -1
	if player_index >= 0 and typeof(_players_ui) == TYPE_ARRAY and player_index < _players_ui.size():
		var player_ui = _players_ui[player_index]
		if player_ui != null:
			if player_ui.player_life_bar != null:
				player_ui.player_life_bar.hide()
			if RunData != null and bool(RunData.get("is_coop_run")) and player_ui.life_bar != null:
				player_ui.life_bar.set_value(100)
				player_ui.life_bar.progress_color = Color.white
				player_ui.life_bar.hide_with_flash()

	var highlight = p_player.get("highlight")
	if highlight != null and is_instance_valid(highlight) and highlight is CanvasItem:
		highlight.hide()

	SoundManager.play(Utils.get_rand_element(run_lost_sounds), -5, 0, true)

	var live_players = _get_live_players()
	if not live_players.empty():
		return

	clean_up_room()





func _brotato_online_is_game_host() -> bool:
	if not _brotato_online_is_online_session_active():
		return false
	var steam = _brotato_online_get_steam_lobby_manager()
	if steam != null and steam.has_method("is_game_host"):
		return bool(steam.is_game_host())
	return false


func _brotato_online_reset_drop_prediction_if_needed(reason: String = "") -> void:
	var wave = -1
	if RunData != null:
		wave = int(RunData.current_wave)
	if _brotato_online_drop_prediction_wave == wave:
		return
	_brotato_online_drop_prediction_wave = wave
	_brotato_online_predicted_item_boxes_this_wave = 0




func _brotato_online_get_prop(source, prop: String, fallback = null):
	if source == null:
		return fallback
	var source_type = typeof(source)
	if source_type == TYPE_DICTIONARY:
		return source.get(prop, fallback)
	if source_type == TYPE_OBJECT:
		var value = source.get(prop)
		if value == null:
			return fallback
		return value
	return fallback


func _brotato_online_get_prop_bool(source, prop: String, fallback: bool = false) -> bool:
	return bool(_brotato_online_get_prop(source, prop, fallback))


func _brotato_online_get_prop_float(source, prop: String, fallback: float = 0.0) -> float:
	return float(_brotato_online_get_prop(source, prop, fallback))


func _brotato_online_get_prop_int(source, prop: String, fallback: int = 0) -> int:
	return int(_brotato_online_get_prop(source, prop, fallback))


func _brotato_online_get_total_luck_for_drops() -> float:
	var luck = 0.0
	if RunData == null:
		return luck
	for player_index in RunData.get_player_count():
		luck += Utils.get_stat(Keys.stat_luck_hash, player_index) / 100.0
	return luck


func _brotato_online_is_forced_item_box_roll(unit: Node) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	var stats = unit.get("stats")
	if stats == null:
		return false
	return _brotato_online_get_prop_bool(stats, "always_drop_consumables", false) and _brotato_online_get_prop_float(stats, "item_drop_chance", 0.0) >= 1.0 and RunData.current_wave <= RunData.nb_of_waves


func _brotato_online_calculate_preroll_item_chance(unit: Node, forced_box_roll: bool) -> float:
	var stats = unit.get("stats")
	if stats == null:
		return 0.0
	var luck = _brotato_online_get_total_luck_for_drops()
	var item_chance: float = (_brotato_online_get_prop_float(stats, "item_drop_chance", 0.0) * (1.0 + luck)) / (1.0 + float(_brotato_online_predicted_item_boxes_this_wave))
	var total_chance_change: float = RunData.sum_all_player_effects(Keys.crate_chance_hash) / 100.0
	item_chance = item_chance + item_chance * total_chance_change
	if forced_box_roll:
		item_chance = 1.0
	return item_chance


func _brotato_online_preroll_consumable_without_tracking(unit: Node, item_chance: float) -> Dictionary:
	var result = {"consumable": null, "from_enemy_fruit_effect": false}
	if unit == null or not is_instance_valid(unit):
		return result
	var stats = unit.get("stats")
	if stats == null:
		return result

	var luck = _brotato_online_get_total_luck_for_drops()
	var consumable_drop_chance = min(1.0, _brotato_online_get_prop_float(stats, "base_drop_chance", 0.0) * (1.0 + luck))
	if RunData.current_wave > RunData.nb_of_waves:
		consumable_drop_chance /= (1.0 + RunData.get_endless_factor())

	if DebugService.always_drop_crates:
		consumable_drop_chance = 1.0
		item_chance = 1.0

	var consumable_to_drop = null
	if Utils.get_chance_success(consumable_drop_chance) or _brotato_online_get_prop_bool(stats, "always_drop_consumables", false):
		var consumable_tier: int = Utils.randi_range(_brotato_online_get_prop_int(stats, "min_consumable_tier", 0), _brotato_online_get_prop_int(stats, "max_consumable_tier", 0))
		if Utils.get_chance_success(item_chance):
			if unit is Boss and RunData.current_wave <= RunData.nb_of_waves:
				consumable_tier = Tier.LEGENDARY
			else:
				consumable_tier = Tier.UNCOMMON
		consumable_to_drop = ItemService.get_consumable_for_tier(consumable_tier)
	elif Utils.get_chance_success(RunData.sum_all_player_effects(Keys.enemy_fruit_drops_hash) / 100.0):
		consumable_to_drop = ItemService.get_consumable_for_tier(Tier.COMMON)
		result["from_enemy_fruit_effect"] = true

	result["consumable"] = consumable_to_drop
	return result


func _brotato_online_is_item_box_consumable(consumable_data) -> bool:
	if consumable_data == null:
		return false
	var id_hash = 0
	if consumable_data.get("my_id_hash") != null:
		id_hash = int(consumable_data.my_id_hash)
	return id_hash == int(Keys.consumable_item_box_hash) or id_hash == int(Keys.consumable_legendary_item_box_hash)


func _brotato_online_kind_for_consumable(consumable_data) -> String:
	if consumable_data == null:
		return "none"
	var id_hash = 0
	if consumable_data.get("my_id_hash") != null:
		id_hash = int(consumable_data.my_id_hash)
	if id_hash == int(Keys.consumable_legendary_item_box_hash):
		return "legendary_item_box"
	if id_hash == int(Keys.consumable_item_box_hash):
		return "item_box"
	if id_hash == int(Keys.consumable_poisoned_fruit_hash):
		return "poisoned_fruit"
	if id_hash == int(Keys.consumable_fruit_hash):
		return "fruit"
	return "consumable"


func _brotato_online_serialize_consumable_drop(consumable_data, from_enemy_fruit_effect: bool, forced_box_roll: bool, prediction_counted: bool, unit: Node) -> Dictionary:
	var wave = 0
	if RunData != null:
		wave = int(RunData.current_wave)
	var result = {
		"has_drop": consumable_data != null,
		"wave": wave,
		"id_hash": 0,
		"my_id": "",
		"resource_path": "",
		"kind": "none",
		"is_box": false,
		"forced_box_roll": forced_box_roll,
		"prediction_counted": prediction_counted,
		"from_enemy_fruit_effect": from_enemy_fruit_effect,
		"drop_area": 0.0,
		"drop_rand_x": 0.5,
		"drop_rand_y": 0.5
	}
	if consumable_data == null:
		return result
	if consumable_data.get("my_id_hash") != null:
		result["id_hash"] = int(consumable_data.my_id_hash)
	if consumable_data.get("my_id") != null:
		result["my_id"] = str(consumable_data.my_id)
	if consumable_data is Resource:
		result["resource_path"] = str(consumable_data.resource_path)
	result["kind"] = _brotato_online_kind_for_consumable(consumable_data)
	result["is_box"] = _brotato_online_is_item_box_consumable(consumable_data)
	var stats = null
	if unit != null and is_instance_valid(unit):
		stats = unit.get("stats")
	var gold_spread = 0.0
	if stats != null:
		gold_spread = _brotato_online_get_prop_float(stats, "gold_spread", 0.0)
	result["drop_area"] = rand_range(50.0, 100.0 + gold_spread)
	result["drop_rand_x"] = randf()
	result["drop_rand_y"] = randf()
	return result


func brotato_online_preroll_drop_for_unit(unit: Node, net_id: String = "", category: String = "") -> Dictionary:
	if unit == null or not is_instance_valid(unit):
		return {}
	var existing_drop = _brotato_online_get_valid_drop_meta(unit, net_id, category)
	if not existing_drop.empty():
		return existing_drop
	if not _brotato_online_is_online_session_active() or not _brotato_online_is_game_host():
		return {}
	var stats = unit.get("stats")
	if stats == null:
		return {}
	if unit.get("can_drop_loot") != null and not bool(unit.get("can_drop_loot")):
		return {}
	if not _brotato_online_get_prop_bool(stats, "can_drop_consumables", false):
		return {}

	_brotato_online_reset_drop_prediction_if_needed("preroll")
	var forced_box_roll = _brotato_online_is_forced_item_box_roll(unit)
	var item_chance = _brotato_online_calculate_preroll_item_chance(unit, forced_box_roll)
	var rolled = _brotato_online_preroll_consumable_without_tracking(unit, item_chance)
	var consumable_data = rolled.get("consumable", null)
	var is_box = _brotato_online_is_item_box_consumable(consumable_data)
	var prediction_counted = false
	# User-requested rule: forced boxes are pre-rolled and synced, but they do not
	# enter the prediction counter until the Host really kills/drops that source.
	if is_box and not forced_box_roll:
		_brotato_online_predicted_item_boxes_this_wave += 1
		prediction_counted = true
	var result = _brotato_online_serialize_consumable_drop(consumable_data, bool(rolled.get("from_enemy_fruit_effect", false)), forced_box_roll, prediction_counted, unit)
	if net_id != "":
		result["net_id"] = net_id
	if category != "":
		result["category"] = category
	unit.set_meta("brotato_online_drop_result", result.duplicate(true))
	return result


func _brotato_online_resolve_consumable_from_drop_result(drop_result: Dictionary):
	if typeof(drop_result) != TYPE_DICTIONARY or not bool(drop_result.get("has_drop", false)):
		return null
	var resource_path = str(drop_result.get("resource_path", ""))
	var consumable_data = null
	if resource_path != "":
		var loaded = load(resource_path)
		if loaded != null:
			consumable_data = loaded
	if consumable_data == null:
		var id_hash = int(drop_result.get("id_hash", 0))
		if id_hash != 0:
			consumable_data = ItemService.get_element(ItemService.consumables, id_hash)
	if consumable_data == null:
		var my_id = str(drop_result.get("my_id", ""))
		if my_id != "" and ItemService.has_method("get_element_safe"):
			consumable_data = ItemService.get_element_safe(ItemService.consumables, my_id)
	if consumable_data == null:
		match str(drop_result.get("kind", "")):
			"legendary_item_box":
				consumable_data = ItemService.get_element(ItemService.consumables, int(Keys.consumable_legendary_item_box_hash))
			"item_box":
				consumable_data = ItemService.get_element(ItemService.consumables, int(Keys.consumable_item_box_hash))
			"fruit":
				consumable_data = ItemService.get_element(ItemService.consumables, int(Keys.consumable_fruit_hash))
			"poisoned_fruit":
				consumable_data = ItemService.get_element(ItemService.consumables, int(Keys.consumable_poisoned_fruit_hash))
	if consumable_data == null:
		return null
	var copy = consumable_data.duplicate()
	var cur_zone: Resource = ZoneService.get_zone_data(RunData.current_zone)
	if cur_zone != null and copy.get("icon") != null:
		copy.icon = cur_zone.get_zone_consumable_sprite(copy)
	return copy


func _brotato_online_apply_deferred_drop_side_effects(drop_result: Dictionary) -> void:
	if typeof(drop_result) != TYPE_DICTIONARY:
		return
	if bool(drop_result.get("from_enemy_fruit_effect", false)):
		for player_index in RunData.get_player_count():
			RunData.add_tracked_value(player_index, Keys.item_fruit_basket_hash, 1)


func _brotato_online_get_prerolled_push_destination(pos: Vector2, drop_result: Dictionary) -> Vector2:
	var area = float(drop_result.get("drop_area", 0.0))
	if area <= 0.0:
		return ZoneService.get_rand_pos_in_area(pos, 50.0, 0)
	var edge = 0
	var min_x = ZoneService.current_zone_min_position.x + edge + area / 2.0
	var max_x = ZoneService.current_zone_max_position.x - edge - area / 2.0
	var min_y = ZoneService.current_zone_min_position.y + edge + area / 2.0
	var max_y = ZoneService.current_zone_max_position.y - edge - area / 2.0
	var clamped_pos = Vector2(clamp(pos.x, min_x, max_x), clamp(pos.y, min_y, max_y))
	var rx = clamp(float(drop_result.get("drop_rand_x", 0.5)), 0.0, 1.0)
	var ry = clamp(float(drop_result.get("drop_rand_y", 0.5)), 0.0, 1.0)
	return Vector2((clamped_pos.x - area / 2.0) + rx * area, (clamped_pos.y - area / 2.0) + ry * area)


func spawn_consumables(unit: Unit) -> void:
	if not _brotato_online_is_online_session_active():
		.spawn_consumables(unit)
		return

	var drop_result = _brotato_online_get_valid_drop_meta(unit)

	if drop_result.empty() and _brotato_online_is_game_host():
		drop_result = brotato_online_preroll_drop_for_unit(unit, "", "death_fallback")

	# Online clients must not run their own random drop path. Missing metadata means
	# the Host birth event has not arrived or this source was never authoritative.
	if drop_result.empty():
		return
	if not bool(drop_result.get("has_drop", false)):
		return

	var consumable_to_spawn = _brotato_online_resolve_consumable_from_drop_result(drop_result)
	if consumable_to_spawn == null:
		return

	_brotato_online_reset_drop_prediction_if_needed("spawn")
	_brotato_online_apply_deferred_drop_side_effects(drop_result)

	var pos = unit.global_position
	if _brotato_online_is_item_box_consumable(consumable_to_spawn):
		_items_spawned_this_wave += 1
		if _brotato_online_is_game_host() and bool(drop_result.get("forced_box_roll", false)) and not bool(drop_result.get("prediction_counted", false)):
			_brotato_online_predicted_item_boxes_this_wave += 1
			drop_result["prediction_counted"] = true
			if unit != null and is_instance_valid(unit):
				unit.set_meta("brotato_online_drop_result", drop_result.duplicate(true))

	var consumable: Consumable = get_node_from_pool(_consumable_pool_id, _consumables_container)
	if consumable == null:
		consumable = consumable_scene.instance()
		_consumables_container.call_deferred("add_child", consumable)
		var _error = consumable.connect("picked_up", self, "on_consumable_picked_up")
		yield(consumable, "ready")

	consumable.already_picked_up = false
	consumable.consumable_data = consumable_to_spawn
	consumable.set_texture(consumable_to_spawn.icon)
	var push_back_destination: Vector2 = _brotato_online_get_prerolled_push_destination(pos, drop_result)
	consumable.drop(pos, 0, push_back_destination)
	_consumables.push_back(consumable)


func get_node_from_pool(id: int, parent: Node) -> Node:
	var node = .get_node_from_pool(id, parent)
	if node != null and is_instance_valid(node):
		_brotato_online_clear_drop_meta(node, "pool_pop")
		_brotato_online_sanitize_pool_node(node, "pool_pop")
	return node


func add_node_to_pool(node: Node, id: int) -> void:
	_brotato_online_clear_drop_meta(node, "pool_add")
	_brotato_online_sanitize_pool_node(node, "pool_add")
	.add_node_to_pool(node, id)


func _exit_tree() -> void:
	if not _brotato_online_is_online_session_active():
		._exit_tree()
		return

	var skipped_pool_entries = _brotato_online_prepare_pool_for_vanilla_exit()
	._exit_tree()
	_brotato_online_clear_pool_arrays_after_exit()
	_brotato_online_restore_skipped_pool_entries(skipped_pool_entries)


func _brotato_online_prepare_pool_for_vanilla_exit() -> Dictionary:
	var skipped_entries = {}
	if _pool == null:
		return skipped_entries
	for key in _pool.keys():
		var pool = _pool[key]
		if typeof(pool) != TYPE_ARRAY:
			skipped_entries[key] = pool
			_pool.erase(key)
			continue
		for index in range(pool.size() - 1, -1, -1):
			var node = pool[index]
			if not is_instance_valid(node) or (node is Node and node.is_queued_for_deletion()):
				pool.remove(index)
	return skipped_entries


func _brotato_online_clear_pool_arrays_after_exit() -> void:
	if _pool == null:
		return
	for key in _pool.keys():
		var pool = _pool[key]
		if typeof(pool) == TYPE_ARRAY:
			pool.clear()


func _brotato_online_restore_skipped_pool_entries(skipped_entries: Dictionary) -> void:
	if _pool == null:
		return
	for key in skipped_entries.keys():
		_pool[key] = skipped_entries[key]


func _check_for_pause() -> void:
	# Normal input maps use the original Main implementation. The fallback only runs
	# while online teardown leaves a missing action or a temporary -1 device mapping.
	if _brotato_online_can_use_vanilla_pause_check():
		._check_for_pause()
		return

	if _skip_pause_check:
		_skip_pause_check = false
		return

	var player_index = _brotato_online_get_safe_pause_request_player()
	if player_index >= 0:
		_pause_menu.pause(player_index)


func _brotato_online_can_use_vanilla_pause_check() -> bool:
	if _skip_pause_check:
		return true
	if not RunData.is_coop_run:
		return InputMap.has_action("ui_pause")
	if RunData.is_streamplay_run:
		return _brotato_online_has_pause_action_for_player(0)
	for player_index in RunData.get_player_count():
		if not _brotato_online_has_pause_action_for_player(player_index):
			return false
	return true


func _brotato_online_has_pause_action_for_player(player_index: int) -> bool:
	var remapped_device = CoopService.get_remapped_player_device(player_index)
	if remapped_device < 0:
		return false
	return InputMap.has_action("ui_pause_%s" % remapped_device)


func _brotato_online_get_safe_pause_request_player() -> int:
	if not RunData.is_coop_run:
		return 0 if _brotato_online_is_action_just_released_safe("ui_pause") else -1
	if RunData.is_streamplay_run:
		return 0 if _brotato_online_is_player_pause_released_safe(0) else -1
	for player_index in RunData.get_player_count():
		if _brotato_online_is_player_pause_released_safe(player_index):
			return player_index
	return -1


func _brotato_online_is_player_pause_released_safe(player_index: int) -> bool:
	var remapped_device = CoopService.get_remapped_player_device(player_index)
	if remapped_device < 0:
		return false
	return _brotato_online_is_action_just_released_safe("ui_pause_%s" % remapped_device)


func _brotato_online_is_action_just_released_safe(action_name: String) -> bool:
	if action_name == "" or not InputMap.has_action(action_name):
		return false
	return Input.is_action_just_released(action_name)
