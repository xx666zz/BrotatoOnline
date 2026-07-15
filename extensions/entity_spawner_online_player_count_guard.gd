extends "res://global/entity_spawner.gd"

# BrotatoOnline safety extension.
# Continue/Resume can leave a stale 4-player RunData layout while the online COOP
# session only has 2 connected slots. EntitySpawner.init() uses RunData.get_player_count()
# directly, so force the count to the authoritative online COOP layout immediately
# before vanilla player spawning.
#
# Online clients still run enough vanilla item/death behavior locally that queued
# EntityBirth creation can duplicate Host-owned objects (for example tree-spawned
# turrets, pets, or Scapegoat-style revive helpers). Block only client-created
# birth/queue spawns. Direct spawn_entity() is kept vanilla so Host snapshot
# reconciliation can instantiate through EntitySpawner and keep pooling/signals valid.
# consumable/material drops are handled by Main and remain outside this guard.

func _brotato_online_is_online_session_active() -> bool:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return false
	return bool(tree.root.get_meta("brotato_online_session_active", false))


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


func _brotato_online_get_steam_lobby_manager() -> Node:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	var direct = tree.root.get_node_or_null("ModLoader/six666-BrotatoOnline/BrotatoOnlineSteamLobbyManager")
	if direct != null and is_instance_valid(direct):
		return direct
	return _brotato_online_find_node_named(tree.root, "BrotatoOnlineSteamLobbyManager", 0)


func _brotato_online_get_slot_manager() -> Node:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	var direct = tree.root.get_node_or_null("ModLoader/six666-BrotatoOnline/BrotatoOnlineOnlinePlayerSlotManager")
	if direct != null and is_instance_valid(direct):
		return direct
	return _brotato_online_find_node_named(tree.root, "BrotatoOnlineOnlinePlayerSlotManager", 0)


func _brotato_online_is_online_client() -> bool:
	if not _brotato_online_is_online_session_active():
		return false
	var steam = _brotato_online_get_steam_lobby_manager()
	if steam != null and steam.has_method("is_game_host"):
		return not bool(steam.is_game_host())
	return false


func _brotato_online_get_authoritative_online_player_count() -> int:
	if not _brotato_online_is_online_session_active():
		return -1

	# Vanilla can rebuild connected_players during main.tscn construction, after the
	# previous scene's pre-change guard but before EntitySpawner.init(). Restore the
	# immutable run snapshot synchronously here so both vanilla player spawning and the
	# RunData count below observe the original online topology.
	var slot_manager = _brotato_online_get_slot_manager()
	if slot_manager != null:
		if slot_manager.has_method("restore_online_run_slot_snapshot_now"):
			slot_manager.restore_online_run_slot_snapshot_now("entity_spawner_init")
		if slot_manager.has_method("get_online_run_slot_snapshot_count"):
			var snapshot_count = int(slot_manager.get_online_run_slot_snapshot_count())
			if snapshot_count > 0:
				return int(clamp(snapshot_count, 1, 4))

	if CoopService == null:
		return -1
	var coop_count = int(CoopService.connected_players.size())
	if coop_count <= 0:
		return -1
	return int(clamp(coop_count, 1, 4))


func _brotato_online_force_run_player_count(reason: String) -> void:
	var target_count = _brotato_online_get_authoritative_online_player_count()
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


func _brotato_online_get_spawn_args_type(args) -> int:
	if args == null:
		return -999999
	var value = args.get("type")
	if value == null:
		return -999999
	return int(value)


func _brotato_online_should_block_client_spawn_type(entity_type: int) -> bool:
	if not _brotato_online_is_online_client():
		return false
	# Player creation and non-catalog helper entities used by vanilla player init
	# (for example JellyShield's type -1 helper) are still local/vanilla-owned.
	# Catalog combat entities (structures, pets, enemies, neutrals, bosses) must
	# come from Host snapshots.
	if entity_type == EntityType.PLAYER or entity_type < 0:
		return false
	return true


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, current_wave_data: WaveData, wave_timer: Timer) -> void:
	_brotato_online_force_run_player_count("entity_spawner_init_before_vanilla")
	.init(zone_min_pos, zone_max_pos, current_wave_data, wave_timer)
	_brotato_online_force_run_player_count("entity_spawner_init_after_vanilla")


func spawn_entity_birth(type: int, scene: PackedScene, pos: Vector2, data: Resource = null, player_index: int = -1, source = null, charmed_by: int = -1) -> void:
	if _brotato_online_should_block_client_spawn_type(type):
		return
	.spawn_entity_birth(type, scene, pos, data, player_index, source, charmed_by)


func spawn_entity(scene: PackedScene, args: SpawnEntityArgs, data: Resource = null, source = null, charmed_by: int = -1) -> KinematicBody2D:
	# Do not block direct spawns here. The only vanilla direct caller in normal play is
	# player/helper creation, and BattleReplicaManager also uses this path to apply
	# Host snapshot entities. Blocking it forced raw PackedScene fallback and broke
	# vanilla pool ownership on death.
	return .spawn_entity(scene, args, data, source, charmed_by)


func on_entity_birth_timeout(birth: EntityBirth) -> void:
	if birth != null and _brotato_online_should_block_client_spawn_type(int(birth.type)):
		active_births = int(max(0, int(active_births) - 1))
		if is_instance_valid(birth):
			if _main != null and is_instance_valid(_main) and _main.has_method("add_node_to_pool"):
				_main.add_node_to_pool(birth, _entity_birth_pool_id)
			elif not birth.is_queued_for_deletion():
				birth.queue_free()
		return
	.on_entity_birth_timeout(birth)
