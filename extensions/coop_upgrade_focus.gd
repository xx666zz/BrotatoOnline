extends "res://ui/menus/shop/coop_item_popup.gd"

func _focus_online_upgrade_control(control: Control) -> void:
	var tree = get_tree()
	if not _focused or not is_visible_in_tree() or not is_instance_valid(control) or not control.is_visible_in_tree():
		return
	if tree.current_scene == null or not tree.root.get_meta("brotato_online_session_active", false):
		return
	var emulator = Utils.get_focus_emulator(player_index, tree.current_scene)
	if emulator != null:
		emulator.focused_control = control

func _on_UpgradeButton_pressed() -> void:
	._on_UpgradeButton_pressed()
	if _pending_upgrade != null:
		_focus_online_upgrade_control(_effect_button_0)

func _leave_upgrade_choice() -> void:
	._leave_upgrade_choice()
	_focus_online_upgrade_control(_upgrade_button)
