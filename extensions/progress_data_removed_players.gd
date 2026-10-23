extends "res://singletons/progress_data.gd"


var _bo_retry_save_guard_depth = 0


func begin_online_retry_save_guard() -> void:
	_bo_retry_save_guard_depth += 1


func end_online_retry_save_guard() -> void:
	_bo_retry_save_guard_depth = max(0, _bo_retry_save_guard_depth - 1)


func reset_and_save_new_run_state() -> void:
	# Only the Host's online death callback opens this guard. Preserve the last
	# valid shop checkpoint while a retry is undecided, without saving dead actors
	# or altering ordinary offline/game-over/new-run resets. Wave 1 may have none.
	if _bo_retry_save_guard_depth > 0 and bool(saved_run_state.get("has_run_state", false)):
		var checkpoint = saved_run_state.duplicate()
		checkpoint["retries"] = int(RunData.retries) + 1
		saved_run_state = checkpoint
		last_saved_run_state = checkpoint
		save()
		return
	.reset_and_save_new_run_state()


func get_run_state(shop_items = [], reroll_count = [], paid_reroll_count = [], initial_free_rerolls = [], free_rerolls = [], item_steals = []) -> Dictionary:
	var state = .get_run_state(shop_items, reroll_count, paid_reroll_count, initial_free_rerolls, free_rerolls, item_steals)
	var removal = get_node_or_null("/root/ModLoader/six666-BrotatoOnline/BrotatoOnlinePlayerRemovalManager")
	if removal != null:
		state = removal.filter_saved_state(state)
	return state


func save() -> void:
	.save()
	var identity = get_node_or_null("/root/ModLoader/six666-BrotatoOnline/BrotatoOnlinePlayerIdentityManager")
	if identity != null:
		identity.persist_saved_identity()
