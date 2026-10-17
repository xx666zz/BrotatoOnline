extends Node

# Bind after the vanilla scene is ready. Inheriting its compiled script during
# ModLoader initialization makes Godot 3.7 resolve RunData before it is ready.
var scene = null
var identity = null
var _offline_inputs = {}
var _waiting_slot = -1


func bind(resume_scene: Node, manager: Node) -> void:
	scene = resume_scene
	identity = manager
	if CoopService.is_connected("connected_players_updated", scene, "_on_connected_players_updated"):
		CoopService.disconnect("connected_players_updated", scene, "_on_connected_players_updated")
	CoopService.connect("connected_players_updated", self, "_on_connected_players_updated")
	identity.attach_resume_scene(scene)


func _on_connected_players_updated(players: Array) -> void:
	if identity.guards_resume(scene):
		return
	if _waiting_slot >= 0:
		if players.size() <= _offline_inputs.size():
			return
		_offline_inputs[_waiting_slot] = players.back().duplicate()
		_advance_offline()
		return
	scene._on_connected_players_updated(players)


func identity_resume_committed() -> void:
	scene.get("_players_to_join").clear()
	scene._setup_next_player()


func identity_resume_offline(inputs: Dictionary) -> void:
	_offline_inputs = inputs.duplicate(true)
	var queue = scene.get("_players_to_join")
	queue.clear()
	for index in range(RunData.get_player_count()):
		if not _offline_inputs.has(index):
			queue.append(index)
	CoopService.connected_players = _offline_inputs.values()
	CoopService.listening_for_inputs = true
	_advance_offline()


func _advance_offline() -> void:
	var queue = scene.get("_players_to_join")
	_waiting_slot = int(queue.front()) if not queue.empty() else -1
	if _waiting_slot < 0:
		var players = []
		for index in range(RunData.get_player_count()):
			players.append(_offline_inputs[index])
		CoopService.connected_players = players
		CoopService.listening_for_inputs = false
	scene._setup_next_player()
