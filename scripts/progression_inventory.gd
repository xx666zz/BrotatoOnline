extends Reference

var manager

func wire(ui: Node, index: int) -> void:
	if not is_instance_valid(ui) or not ui.has_method("_get_weapons_item_popup"):
		return
	var popup = ui._get_weapons_item_popup(index)
	if not is_instance_valid(popup):
		return
	for spec in [["item_combine_button_pressed", "_on_weapon_combine_button_pressed", "combine"], ["item_discard_button_pressed", "_on_weapon_discard_button_pressed", "discard"]]:
		if manager._is_game_host():
			if not popup.is_connected(spec[0], self, "_host_changed"):
				popup.connect(spec[0], self, "_host_changed", [index])
		elif index == manager._get_local_client_player_index():
			if popup.is_connected(spec[0], ui, spec[1]):
				popup.disconnect(spec[0], ui, spec[1])
			if not popup.is_connected(spec[0], self, "_request"):
				popup.connect(spec[0], self, "_request", [index, spec[2]])

func _request(weapon, index: int, kind: String) -> void:
	if manager._applying_remote_run_page_action or weapon == null:
		return
	var ui = manager._find_progression_ui()
	var offer = manager._build_progression_visible_option(index, ui)
	if offer.get("mode", "") != "item_box":
		return
	var container = manager._get_progression_player_container(ui, index)
	manager._queue_local_run_page_action({
		"msg_type": "run_page_action_sync", "action_type": "item_box_weapon_" + kind,
		"screen": "progression_item_box", "player_index": index,
		"offer_id": container.get_meta("bo_box_offer", ""),
		"weapon_slot_index": manager._get_player_weapon_index_for_action_payload(index, weapon),
		"item_identity": manager._build_shop_item_stable_identity(weapon)
	})
	# Leave the crate pending. This action changes inventory, not the reward queue.
	ui._popup_manager.reset_focus(index)

func apply(index: int, message: Dictionary) -> bool:
	var ui = manager._find_progression_ui()
	if not manager._is_valid_progression_ui_visible(ui):
		return false
	var offer = manager._build_progression_visible_option(index, ui)
	if offer.get("mode", "") != "item_box" or str(offer.get("offer_id", "")) != str(message.get("offer_id", "")):
		return false
	if RunData.get_player_effect_bool(Keys.lock_current_weapons_hash, index):
		return false
	var weapons = RunData.get_player_weapons(index)
	var slot = int(message.get("weapon_slot_index", -1))
	if slot < 0 or slot >= weapons.size():
		return false
	var weapon = weapons[slot]
	var identity = message.get("item_identity", {})
	if typeof(identity) != TYPE_DICTIONARY or identity.empty() or not manager._shop_item_matches_stable_identity(weapon, identity):
		return false
	var before = weapons.size()
	if message.get("action_type", "") == "item_box_weapon_combine":
		if RunData.get_combine_partner(weapon, index) == null:
			return false
		ui._on_weapon_combine_button_pressed(weapon, index)
	elif message.get("action_type", "") == "item_box_weapon_discard":
		ui._on_weapon_discard_button_pressed(weapon, index)
	else:
		return false
	manager._mark_host_shop_run_data_dirty(index)
	return RunData.get_player_weapons(index).size() < before

func attach(state: Dictionary, index: int) -> void:
	var repair = manager._build_forced_full_shop_run_data_repair_state(index, "crate_inventory")
	if repair.has("run_data"):
		state["crate_inventory_run_data"] = repair.run_data

func _host_changed(_weapon, index: int) -> void:
	if manager._applying_remote_run_page_action:
		return
	call_deferred("_broadcast_host_inventory", index)

func _broadcast_host_inventory(index: int) -> void:
	if not manager._is_online_session_active() or not manager._is_game_host():
		return
	var state = manager._build_progression_visible_option(index)
	attach(state, index)
	manager._queue_local_run_page_action({"msg_type": "run_page_action_sync", "action_type": "item_box_inventory_state", "screen": "progression_item_box", "player_index": index, "host_state_after": state})
