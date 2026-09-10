extends "res://ui/menus/ingame/upgrades_ui_player_container.gd"

# The vanilla gamepad shortcut does not press BanButton. UpgradesUIPlayerContainer._input()
# calls _on_BanButton_pressed() directly, so a client-side BanButton.pressed signal
# intercept cannot see that path. Route only online clients through MenuSyncManager while
# preserving vanilla hold-to-ban / release-to-cancel behavior. Host and offline play keep
# the original implementation unchanged.


func _on_BanButton_pressed():
	if not _brotato_online_should_route_item_box_ban_to_host():
		._on_BanButton_pressed()
		return

	if ProgressData.settings.holding_button:
		is_pressing_b = true

		while true:
			_progress_ban.value += 0.025
			yield(get_tree(), "physics_frame")
			if _button_pressed:
				return
			if _progress_ban.value >= 1:
				_ban_button_label.modulate = Color(1, 1, 1, 1)
				break
			elif not is_pressing_b:
				_ban_button_label.modulate = Color(1, 1, 1, 1)
				_progress_ban.value = 0
				return
		_progress_ban.value = 0

		yield(UIService._ban_item_control(_item_panel_container), "completed")

	var menu_sync = _brotato_online_get_menu_sync_manager()
	if menu_sync != null and menu_sync.has_method("request_client_item_box_ban_from_shortcut"):
		menu_sync.request_client_item_box_ban_from_shortcut(player_index)


func _brotato_online_should_route_item_box_ban_to_host() -> bool:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return false
	if not bool(tree.root.get_meta("brotato_online_session_active", false)):
		return false

	var session = tree.root.get_node_or_null(
		"ModLoader/six666-BrotatoOnline/BrotatoOnlineSessionManager"
	)
	if session != null and is_instance_valid(session) and session.has_method("is_game_host"):
		return not bool(session.is_game_host())

	# During an active online session, failing closed is safer than applying the
	# authoritative RunData mutation locally before the session manager is reachable.
	return true


func _brotato_online_get_menu_sync_manager() -> Node:
	var tree = get_tree()
	if tree == null or tree.root == null:
		return null
	var manager = tree.root.get_node_or_null(
		"ModLoader/six666-BrotatoOnline/BrotatoOnlineMenuSyncManager"
	)
	if manager != null and is_instance_valid(manager):
		return manager
	return null
