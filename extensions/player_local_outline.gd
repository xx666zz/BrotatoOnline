extends "res://entities/units/player/player.gd"

# Online-only display override.
# This option adds a real shader outline to the locally controlled character.
# It does not change the vanilla coop highlight circle under players.

const META_LOCAL_OUTLINE_COLOR = "brotato_online_local_outline_color"
const META_LOCAL_OUTLINE_OWNED = "brotato_online_local_outline_owned"




# Brotato's Player._set_outlines() assumes the leg container is still alive.
# During online coop death/room cleanup, the online settings manager may remove
# the optional local outline after player internals have already started being
# freed. Re-implement the Entity outline setup with validity guards, then mirror
# the material to surviving leg sprites only. This keeps the visual option from
# crashing the end-of-run death path.
func _set_outlines(alpha: float = 1.0, desaturation: float = 0.0) -> void:
	if _brotato_online_can_use_vanilla_outline_setup():
		._set_outlines(alpha, desaturation)
		return
	_brotato_online_set_sprite_outline_material(alpha, desaturation)
	_brotato_online_copy_outline_material_to_legs()


func _brotato_online_can_use_vanilla_outline_setup() -> bool:
	if sprite == null or not is_instance_valid(sprite):
		return false
	if not _outline_colors:
		return _brotato_online_has_live_leg_sprites()
	if outline_material == null or outline_material.shader == null or sprite.texture == null:
		return false
	return _brotato_online_has_live_leg_sprites()


func _brotato_online_has_live_leg_sprites() -> bool:
	if _legs == null or not is_instance_valid(_legs):
		return false
	for leg in _legs.get_children():
		if leg == null or not is_instance_valid(leg):
			return false
		var leg_sprite = leg.get_node_or_null("Sprite")
		if leg_sprite == null or not is_instance_valid(leg_sprite):
			return false
	return true


func _brotato_online_set_sprite_outline_material(alpha: float = 1.0, desaturation: float = 0.0) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return

	if not _outline_colors:
		sprite.material = null
		return

	if outline_material == null or outline_material.shader == null:
		return

	sprite.material = ShaderMaterial.new()
	sprite.material.shader = outline_material.shader

	if sprite.texture != null:
		sprite.material.set_shader_param("texture_size", sprite.texture.get_size())

	if alpha < 1.0:
		_current_material_alpha = alpha
		sprite.material.set_shader_param("alpha", alpha)
	else:
		sprite.material.set_shader_param("alpha", _current_material_alpha)

	if desaturation > 0.0:
		_current_material_desaturation = desaturation
		sprite.material.set_shader_param("desaturation", desaturation)
	else:
		sprite.material.set_shader_param("desaturation", _current_material_desaturation)

	for i in range(_outline_colors.size()):
		sprite.material.set_shader_param("outline_color_%s" % i, _outline_colors[i])


func _brotato_online_copy_outline_material_to_legs() -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	if _legs == null or not is_instance_valid(_legs):
		return

	for leg in _legs.get_children():
		if leg == null or not is_instance_valid(leg):
			continue
		var leg_sprite = leg.get_node_or_null("Sprite")
		if leg_sprite != null and is_instance_valid(leg_sprite):
			leg_sprite.material = sprite.material


func update_highlight() -> void:
	.update_highlight()
	_brotato_online_apply_local_character_outline()


func free_entity() -> void:
	_brotato_online_remove_local_outline()
	.free_entity()


func _brotato_online_apply_local_character_outline() -> void:
	if dead:
		_brotato_online_remove_local_outline()
		return
	if RunData == null or not bool(RunData.is_coop_run):
		_brotato_online_remove_local_outline()
		return

	var settings_manager = _brotato_online_get_settings_manager()
	if settings_manager == null or not settings_manager.has_method("is_online_session_active"):
		_brotato_online_remove_local_outline()
		return
	if not bool(settings_manager.call("is_online_session_active")):
		_brotato_online_remove_local_outline()
		return

	var local_index = -1
	if settings_manager.has_method("get_local_player_index"):
		local_index = int(settings_manager.call("get_local_player_index"))
	if local_index < 0:
		_brotato_online_remove_local_outline()
		return

	var local_outline_enabled = false
	if settings_manager.has_method("get_local_character_outline_enabled"):
		local_outline_enabled = bool(settings_manager.call("get_local_character_outline_enabled"))

	var is_local_player = int(player_index) == local_index
	if is_local_player and local_outline_enabled:
		_brotato_online_add_or_update_local_outline()
	else:
		_brotato_online_remove_local_outline()


func _brotato_online_add_or_update_local_outline() -> void:
	var outline_color = Utils.HIGHLIGHT_COLOR
	if CoopService != null and CoopService.has_method("get_player_color"):
		outline_color = CoopService.get_player_color(player_index)
	outline_color.a = 1.0

	if has_meta(META_LOCAL_OUTLINE_COLOR):
		var old_color = get_meta(META_LOCAL_OUTLINE_COLOR)
		if old_color == outline_color and has_outline(outline_color):
			return
		_brotato_online_remove_local_outline()

	var already_had_same_outline = has_outline(outline_color)
	if not already_had_same_outline:
		# Entity.add_outline asserts when more than four outlines exist. If another
		# item/effect already fills all slots, skip this purely visual marker rather
		# than risking a crash.
		if _outline_colors.size() >= 4:
			return
		add_outline(outline_color)

	set_meta(META_LOCAL_OUTLINE_COLOR, outline_color)
	set_meta(META_LOCAL_OUTLINE_OWNED, not already_had_same_outline)


func _brotato_online_remove_local_outline() -> void:
	if not has_meta(META_LOCAL_OUTLINE_COLOR):
		return

	var outline_color = get_meta(META_LOCAL_OUTLINE_COLOR)
	var owned_outline = false
	if has_meta(META_LOCAL_OUTLINE_OWNED):
		owned_outline = bool(get_meta(META_LOCAL_OUTLINE_OWNED))

	if owned_outline and has_outline(outline_color):
		remove_outline(outline_color)

	remove_meta(META_LOCAL_OUTLINE_COLOR)
	if has_meta(META_LOCAL_OUTLINE_OWNED):
		remove_meta(META_LOCAL_OUTLINE_OWNED)


func _brotato_online_get_settings_manager() -> Node:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	var direct = tree.root.get_node_or_null("ModLoader/six666-BrotatoOnline/BrotatoOnlineModSettingsManager")
	if direct != null and is_instance_valid(direct):
		return direct
	return _brotato_online_find_node_named(tree.root, "BrotatoOnlineModSettingsManager", 0)


func _brotato_online_find_node_named(node: Node, target_name: String, depth: int) -> Node:
	if node == null or not is_instance_valid(node) or depth > 6:
		return null
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found = _brotato_online_find_node_named(child, target_name, depth + 1)
		if found != null:
			return found
	return null
