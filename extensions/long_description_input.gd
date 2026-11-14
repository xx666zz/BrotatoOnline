extends "res://ui/menus/shop/item_description.gd"

var _bo_original_scroll = null

func set_item(item_data: ItemParentData, player_index: int, item_count := 1) -> void:
	if _bo_original_scroll == null:
		_bo_original_scroll = allow_scroll_when_crowded
	allow_scroll_when_crowded = _bo_original_scroll or (item_data != null and item_data.is_mutant and is_inside_tree() and get_tree().root.get_meta("brotato_online_session_active", false))
	.set_item(item_data, player_index, item_count)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not is_instance_valid(_scroll_container) or not _scroll_container.visible:
		return
	if not get_tree().root.get_meta("brotato_online_session_active", false):
		._input(event)
		return
	var slots = get_node_or_null("/root/ModLoader/six666-BrotatoOnline/BrotatoOnlineOnlinePlayerSlotManager")
	if slots != null and not slots.get_local_player_indices().has(_player_index):
		return
	var focused = get_focus_owner()
	var emulator = Utils.get_focus_emulator(_player_index)
	if is_instance_valid(emulator) and is_instance_valid(emulator.focused_control):
		focused = emulator.focused_control
	var panel = get_parent()
	# Buy/effect buttons can be siblings outside the description's immediate VBox.
	var ancestor = panel
	while ancestor != null:
		if ancestor.get("_item_description") == self:
			panel = ancestor
			break
		ancestor = ancestor.get_parent()
	var hovered = panel.get_global_rect().has_point(get_global_mouse_position()) if panel is Control else false
	# Wheel follows the pointer; page keys follow the local co-op focus.
	# A focused card must not steal wheel input from a different hovered card.
	var focus_matches = is_instance_valid(focused) and (focused == panel or panel.is_a_parent_of(focused))
	if event is InputEventMouseButton and not hovered:
		return
	if not hovered and not focus_matches:
		return
	var step = 0.0
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == BUTTON_WHEEL_UP:
			step = -MOUSE_SCROLL_STEP
		elif event.button_index == BUTTON_WHEEL_DOWN:
			step = MOUSE_SCROLL_STEP
	elif event is InputEventKey and event.pressed:
		if event.scancode == KEY_PAGEUP:
			step = -_scroll_container.rect_size.y
		elif event.scancode == KEY_PAGEDOWN:
			step = _scroll_container.rect_size.y
	if step == 0 or _scroll_container.get_v_scrollbar().max_value <= _scroll_container.rect_size.y:
		return
	_scroll_container.scroll_vertical += step
	get_viewport().set_input_as_handled()
