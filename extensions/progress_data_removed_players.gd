extends "res://singletons/progress_data.gd"


func get_run_state(shop_items = [], reroll_count = [], paid_reroll_count = [], initial_free_rerolls = [], free_rerolls = [], item_steals = []) -> Dictionary:
	var state = .get_run_state(shop_items, reroll_count, paid_reroll_count, initial_free_rerolls, free_rerolls, item_steals)
	var removal = get_node_or_null("/root/ModLoader/six666-BrotatoOnline/BrotatoOnlinePlayerRemovalManager")
	if removal != null:
		return removal.filter_saved_state(state)
	return state
