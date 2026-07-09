extends "res://entities/units/player/player.gd"

# BrotatoOnline safety extension.
# During online client end-of-wave cleanup a Player can have already run vanilla die(),
# which queue_free()s RunningSmoke, while the replica layer may keep Player.dead false
# for presentation safety. Vanilla on_room_cleanup() only checks dead and then calls
# _running_smoke.stop(), which crashes on the freed CPUParticles2D reference.


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


func _brotato_online_get_local_client_player_index() -> int:
	var slot_manager = _brotato_online_get_slot_manager()
	if slot_manager != null and slot_manager.has_method("get_local_mirrored_player_index"):
		return int(slot_manager.get_local_mirrored_player_index())
	return -1


func _brotato_online_get_self_player_index() -> int:
	var value = get("player_index")
	if value == null:
		return -1
	return int(value)


func _brotato_online_is_remote_online_proxy() -> bool:
	if not _brotato_online_is_online_client():
		return false
	var local_index = _brotato_online_get_local_client_player_index()
	var self_index = _brotato_online_get_self_player_index()
	# Do not fall back to meta-only ownership. During scene changes the slot manager can
	# briefly return -1; a meta-only fallback can wrongly protect the local player's death
	# path and make the player appear unable to die in-wave. If ownership is unresolved,
	# prefer allowing vanilla damage/death; MainSafePoolExit already ignores non-owned
	# death callbacks on online clients.
	if local_index < 0 or self_index < 0:
		return false
	return self_index != local_index


func _brotato_online_is_owned_online_client_player() -> bool:
	if not _brotato_online_is_online_client():
		return false
	var local_index = _brotato_online_get_local_client_player_index()
	var self_index = _brotato_online_get_self_player_index()
	return local_index >= 0 and self_index >= 0 and self_index == local_index


func _brotato_online_get_hitbox_parent(hitbox) -> Node:
	if hitbox == null or not is_instance_valid(hitbox):
		return null
	var parent = hitbox.get_parent()
	if parent != null and is_instance_valid(parent) and parent is Node:
		return parent
	return null


func _brotato_online_is_enemy_projectile_hit(args: TakeDamageArgs) -> bool:
	if args == null or args.hitbox == null or not is_instance_valid(args.hitbox):
		return false
	var projectile_parent = _brotato_online_get_hitbox_parent(args.hitbox)
	var projectile_script_path = ""
	if projectile_parent != null:
		var projectile_script = projectile_parent.get_script()
		if projectile_script != null and projectile_script is Resource:
			projectile_script_path = str(projectile_script.resource_path).to_lower()
	var from_node = args.from
	if from_node == null or not is_instance_valid(from_node):
		from_node = args.hitbox.from if is_instance_valid(args.hitbox.from) else null
	var from_script_path = ""
	if from_node != null and is_instance_valid(from_node):
		var from_script = from_node.get_script()
		if from_script != null and from_script is Resource:
			from_script_path = str(from_script.resource_path).to_lower()
	if projectile_script_path.find("enemy_projectile") != -1:
		return true
	if projectile_parent != null and str(projectile_parent.name).to_lower().find("enemyprojectile") != -1:
		return true
	return from_script_path.find("entities/units/enemies") != -1 and projectile_parent != null and projectile_script_path.find("projectile") != -1


func _brotato_online_get_enemy_projectile_source(args: TakeDamageArgs) -> Node:
	if args == null:
		return null
	if args.from != null and is_instance_valid(args.from) and args.from is Node:
		return args.from
	if args.hitbox != null and is_instance_valid(args.hitbox) and args.hitbox.from != null and is_instance_valid(args.hitbox.from) and args.hitbox.from is Node:
		return args.hitbox.from
	return null


func _brotato_online_get_enemy_id(source: Node) -> String:
	if source == null or not is_instance_valid(source):
		return ""
	var enemy_id_value = source.get("enemy_id")
	if enemy_id_value != null:
		return str(enemy_id_value).to_lower()
	return str(source.name).to_lower()


func _brotato_online_should_guard_enemy_projectile(source: Node) -> bool:
	var enemy_id = _brotato_online_get_enemy_id(source)
	return enemy_id == "junkie" or enemy_id == "dire_junkie" or enemy_id == "lamprey" or enemy_id == "pufferfish" or enemy_id == "bloated_pufferfish"


func _brotato_online_get_synced_enemy_contact_damage(source: Node) -> int:
	if source == null or not is_instance_valid(source):
		return -1
	var current_stats_value = source.get("current_stats")
	if current_stats_value != null and current_stats_value.get("damage") != null:
		return int(current_stats_value.damage)
	var hitbox = source.get_node_or_null("Hitbox")
	if hitbox != null and hitbox.get("damage") != null:
		return int(hitbox.damage)
	return -1


func _brotato_online_clamp_owned_enemy_projectile_damage(value: int, args: TakeDamageArgs) -> int:
	if value <= 0:
		return value
	if not _brotato_online_is_owned_online_client_player():
		return value
	if not _brotato_online_is_enemy_projectile_hit(args):
		return value
	var source = _brotato_online_get_enemy_projectile_source(args)
	if not _brotato_online_should_guard_enemy_projectile(source):
		return value
	var contact_damage = _brotato_online_get_synced_enemy_contact_damage(source)
	if contact_damage <= 0:
		return value
	# These enemies' projectile damage is in the same range as their contact damage
	# (Pufferfish death shots are only moderately higher). If a guest-side projectile
	# was locally recalculated with a corrupted RunData / multiplier cache, it can become
	# hundreds or thousands of damage and instantly kill the owning client. Keep a wide
	# 2x ceiling so normal endless/curse/coop scaling from Host-side contact damage still
	# passes, while impossible one-shot values are clamped before the client reports death.
	var safe_cap = max(1, int(ceil(float(contact_damage) * 2.0)))
	if value > safe_cap:
		return safe_cap
	return value


func _brotato_online_restore_remote_proxy_hp() -> void:
	if current_stats == null:
		return
	var max_health = int(max_stats.health) if max_stats != null else 1
	var restore_hp = int(current_stats.health)
	if has_meta("brotato_online_last_host_hp"):
		restore_hp = int(get_meta("brotato_online_last_host_hp"))
	elif restore_hp <= 0:
		restore_hp = 1
	if restore_hp <= 0:
		restore_hp = max(1, min(max_health, 1))
	if max_health > 0:
		restore_hp = clamp(restore_hp, 1, max_health)
	current_stats.health = restore_hp
	if has_signal("health_updated"):
		emit_signal("health_updated", self, current_stats.health, max_health)


func _brotato_online_is_remote_bull_hurtbox_proxy() -> bool:
	if not _brotato_online_is_online_session_active():
		return false
	if not has_meta("brotato_online_remote_bull_hurtbox_proxy"):
		return false
	if not bool(get_meta("brotato_online_remote_bull_hurtbox_proxy")):
		return false
	return _brotato_online_is_bull_character_index(_brotato_online_get_self_player_index())


func _brotato_online_is_bull_character_index(index: int) -> bool:
	if index < 0:
		return false
	if RunData != null and RunData.has_method("get_player_count") and index >= int(RunData.get_player_count()):
		return false
	var character = null
	if RunData != null and RunData.has_method("get_player_character"):
		character = RunData.get_player_character(index)
	elif RunData != null and RunData.get("players_data") != null:
		var players_data = RunData.get("players_data")
		if typeof(players_data) == TYPE_ARRAY and index < players_data.size():
			var player_data = players_data[index]
			if player_data != null:
				character = player_data.get("current_character")
	if character == null:
		return false
	return str(character.get("my_id")) == "character_bull"


func _brotato_online_remote_bull_can_take_proxy_hit(args: TakeDamageArgs) -> bool:
	if args != null and args.hitbox != null and args.hitbox.get("is_healing") != null and bool(args.hitbox.is_healing):
		return false
	if args != null and bool(args.bypass_invincibility):
		return true
	if _invincibility_timer != null and is_instance_valid(_invincibility_timer) and not _invincibility_timer.is_stopped():
		return false
	return true


func _brotato_online_trigger_remote_bull_explosion() -> void:
	var explode_on_hit_effects = RunData.get_player_effect(Keys.explode_on_hit_hash, player_index)
	if typeof(explode_on_hit_effects) != TYPE_ARRAY or explode_on_hit_effects.empty():
		return
	init_exploding_stats(false)
	var explode_when_below_hp_effects = RunData.get_player_effect(Keys.explode_when_below_hp_hash, player_index)
	var nb_explosions = explode_on_hit_effects.size()
	if typeof(explode_when_below_hp_effects) == TYPE_ARRAY:
		nb_explosions += explode_when_below_hp_effects.size()
	if nb_explosions <= 0:
		nb_explosions = 1
	for effect in explode_on_hit_effects:
		if not _explode_on_hit_stats.has(effect):
			continue
		explode(_explode_on_hit_stats[effect], effect, nb_explosions)
	if has_method("flash"):
		flash()


func _brotato_online_start_remote_bull_proxy_iframes() -> void:
	if has_method("disable_hurtbox"):
		disable_hurtbox()
	if _invincibility_timer != null and is_instance_valid(_invincibility_timer):
		_invincibility_timer.start(MIN_IFRAMES)


func take_damage(value: int, args: TakeDamageArgs) -> Array:
	# Host-side remote Bull keeps its Hurtbox enabled so enemy hits can trigger the
	# Bull explosion, but the local hit must never own HP/death for that remote player.
	if _brotato_online_is_remote_bull_hurtbox_proxy():
		if _brotato_online_remote_bull_can_take_proxy_hit(args):
			_brotato_online_trigger_remote_bull_explosion()
			_brotato_online_start_remote_bull_proxy_iframes()
		_brotato_online_restore_remote_proxy_hp()
		return [0, 0, false]

	# Remote players on an online client are Host-driven display proxies. Local enemy
	# simulation can still overlap them before/after snapshots, so block all local damage
	if _brotato_online_is_remote_online_proxy():
		disable_hurtbox()
		_brotato_online_restore_remote_proxy_hp()
		return [0, 0, false]
	value = _brotato_online_clamp_owned_enemy_projectile_damage(value, args)
	return .take_damage(value, args)


func die(args = Utils.default_die_args) -> void:
	# Local overlap damage must not kill a remote Bull proxy. Remote death sync sets
	# brotato_online_allow_remote_die before calling die(), so synced deaths still work.
	if _brotato_online_is_remote_bull_hurtbox_proxy() and not bool(get_meta("brotato_online_allow_remote_die", false)):
		_brotato_online_restore_remote_proxy_hp()
		return
	# filtered in take_damage(); actual death callbacks are filtered in MainSafePoolExit.
	.die(args)

func on_room_cleanup() -> void:
	if not _brotato_online_is_online_session_active():
		.on_room_cleanup()
		return

	if dead:
		return

	if _running_smoke != null and is_instance_valid(_running_smoke) and not _running_smoke.is_queued_for_deletion():
		_running_smoke.stop()

	if _animation_player != null and is_instance_valid(_animation_player) and not _animation_player.is_queued_for_deletion():
		_animation_player.play(animation_idle)

	if not cleaning_up:
		_clean_up()
