extends "res://effect_behaviors/scenes/dig_site_scene_effect_behavior.gd"

func spawn_dig_sites(container: Node) -> void:
	var session = get_node_or_null("/root/ModLoader/six666-BrotatoOnline/BrotatoOnlineSessionManager")
	if session != null and session.bo_api_is_client():
		return
	.spawn_dig_sites(container)
