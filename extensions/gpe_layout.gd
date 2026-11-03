extends "res://global/gpe_spawner.gd"

var online_hole_layout = ""

func spawn_holes_full_scene() -> void:
	var session = get_node_or_null("/root/ModLoader/six666-BrotatoOnline/BrotatoOnlineSessionManager")
	if session != null and session.bo_api_is_client():
		return
	.spawn_holes_full_scene()
	online_hole_layout = _gpe_container.get_child(_gpe_container.get_child_count() - 1).filename

func apply_online_hole_layout(path: String) -> void:
	if path == "" or online_hole_layout != "":
		return
	for packed in holes_scene + holes_explorer_scene + holes_old_scene:
		if packed.resource_path == path:
			var layout = packed.instance()
			layout.position = Vector2.ONE
			_gpe_container.add_child(layout)
			online_hole_layout = path
			return
