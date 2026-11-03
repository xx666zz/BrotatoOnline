extends "res://ui/menus/shop/shop_item.gd"

# Event bridge for Brotato's two lock input paths.
# Mouse activation reaches ShopItem through LockButton.toggled, while keyboard/gamepad
# select in BaseShop._input() calls change_lock_status() directly. Observing the mutation
# here catches both paths without polling every shop slot.

signal bo_lock_status_changed(button_pressed, shop_item)


func _enter_tree() -> void:
	# The coop scene omits the label that ShopItem resolves in its onready fields.
	var button = get_node_or_null("%DismantleButton")
	if button == null or get_node_or_null("%DismantlePartsLabel") != null:
		return
	var row = button.get_node_or_null("HBoxContainer")
	if row == null:
		return
	var label = row.get_node_or_null("DismantlePartsLabel")
	if label == null:
		label = Label.new()
		label.name = "DismantlePartsLabel"
		label.visible = false
		label.add_font_override("font", button.get_font("font"))
		row.add_child(label)
	label.owner = self
	label.unique_name_in_owner = true


func _online_shop_focus_emulator():
	var tree = get_tree()
	if tree == null or not RunData.is_coop_run or not tree.root.get_meta("brotato_online_session_active", false) or not is_instance_valid(tree.current_scene):
		return null
	return Utils.get_focus_emulator(player_index, tree.current_scene)


func focus_mecha_effect_choice() -> void:
	var emulator = _online_shop_focus_emulator()
	if emulator == null:
		.focus_mecha_effect_choice()
		return
	_effect_button_0.focus_mode = FOCUS_ALL
	_effect_button_1.focus_mode = FOCUS_ALL
	_effect_button_0.focus_neighbour_right = _effect_button_0.get_path_to(_effect_button_1)
	_effect_button_1.focus_neighbour_left = _effect_button_1.get_path_to(_effect_button_0)
	emulator.focused_control = _effect_button_0


func focus_buy_button() -> void:
	var emulator = _online_shop_focus_emulator()
	if emulator == null:
		.focus_buy_button()
		return
	if active:
		_button.focus_mode = FOCUS_ALL
		emulator.focused_control = _button


func change_lock_status(button_pressed: bool) -> void:
	var was_locked = bool(locked)
	.change_lock_status(button_pressed)
	var is_locked = bool(locked)
	if is_locked != was_locked:
		emit_signal("bo_lock_status_changed", is_locked, self)


func _update_dismantle_parts_label() -> void:
	# Some recovered scenes lose unique-name ownership. Use the known local path once.
	if not is_instance_valid(_dismantle_parts_label) and is_instance_valid(_dismantle_button):
		_dismantle_parts_label = _dismantle_button.get_node_or_null("HBoxContainer/DismantlePartsLabel")
	if is_instance_valid(_dismantle_parts_label):
		._update_dismantle_parts_label()
