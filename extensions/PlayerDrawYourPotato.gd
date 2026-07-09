extends "res://entities/units/player/player.gd"


func apply_items_effects() -> void:
	var custom_manager = _custom_potato_get_manager()
	if custom_manager != null and custom_manager.has_custom_skin_for_player(player_index):
		_custom_potato_apply_textures(custom_manager)

	var weapons = RunData.get_player_weapons_ref(player_index)
	for i in weapons.size():
		add_weapon(weapons[i], i)

	RunData.sort_appearances()
	var appearances_behind = []

	for appearance in RunData.get_player_appearances(player_index):
		if custom_manager != null and custom_manager.should_skip_appearance_for_player(player_index, appearance):
			continue

		var item_sprite = Sprite.new()
		item_sprite.texture = appearance.get_sprite()
		_animation_node.add_child(item_sprite)

		if appearance.depth < - 1:
			appearances_behind.push_back(item_sprite)

		_item_appearances.push_back(item_sprite)

	var popped = appearances_behind.pop_back()

	while popped != null:
		popped.show_behind_parent = true
		_animation_node.move_child(popped, 0)
		popped = appearances_behind.pop_back()

	_sprites = $Animation.get_children()

	update_player_stats(true)


func _custom_potato_apply_textures(custom_manager) -> void:
	var body_tex = custom_manager.get_body_texture_for_player(player_index)
	if body_tex != null:
		var body_sprite = get_node_or_null("Animation/Sprite")
		if body_sprite != null and body_sprite is Sprite:
			body_sprite.texture = body_tex
		var shadow_sprite = get_node_or_null("Animation/Shadow")
		if shadow_sprite != null and shadow_sprite is Sprite:
			shadow_sprite.texture = body_tex

	var legs_tex = custom_manager.get_legs_texture_for_player(player_index)
	if legs_tex != null:
		var leg_l = get_node_or_null("Animation/Legs/LegL/Sprite")
		if leg_l != null and leg_l is Sprite:
			leg_l.texture = legs_tex
		var leg_r = get_node_or_null("Animation/Legs/LegR/Sprite")
		if leg_r != null and leg_r is Sprite:
			leg_r.texture = legs_tex


func _custom_potato_get_manager():
	var tree = get_tree()
	if tree == null:
		return null
	var managers = tree.get_nodes_in_group("DrawYourPotatoManager")
	if managers.empty():
		return null
	return managers[0]
