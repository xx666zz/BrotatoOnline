extends "res://singletons/item_service.gd"


func _rebuild_items() -> void:
	._rebuild_items()
	_bo_append_session_content(_items, "items")


func _rebuild_weapons() -> void:
	._rebuild_weapons()
	_bo_append_session_content(_weapons, "weapons")


func _rebuild_characters() -> void:
	._rebuild_characters()
	_bo_append_session_content(_characters, "characters")


func _bo_append_session_content(pool: Array, kind: String) -> void:
	if not has_meta("brotato_online_session_content"):
		return
	for data in get_meta("brotato_online_session_content").get(kind, []):
		if data != null and not pool.has(data):
			pool.append(data)
