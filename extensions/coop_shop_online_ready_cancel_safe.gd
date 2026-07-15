extends "res://ui/menus/shop/coop_shop.gd"

# Brotato maps Escape to both cancel (pressed) and pause (released). Route the
# online Client's ready cancellation through MenuSync before BaseShop can clear
# only the local flag and then pause the outgoing shop scene.


func _input(event: InputEvent) -> void:
	var manager = _brotato_online_get_menu_sync_manager()
	if manager != null and manager.has_method("handle_client_shop_ready_cancel_input"):
		if bool(manager.handle_client_shop_ready_cancel_input(event)):
			return
	._input(event)


func _brotato_online_get_menu_sync_manager():
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(
		"ModLoader/six666-BrotatoOnline/BrotatoOnlineMenuSyncManager"
	)
