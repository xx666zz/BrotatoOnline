extends "res://entities/units/pet/jellyshield/jellyshield.gd"

func init_trajectory(id: int, count: int, owner_player: Player) -> void:
	if is_instance_valid(_owner_player) and _owner_player.is_connected("tree_exiting", self, "_on_online_owner_exiting"):
		_owner_player.disconnect("tree_exiting", self, "_on_online_owner_exiting")
	if not is_instance_valid(owner_player) or owner_player.is_queued_for_deletion() or count <= 0:
		_on_online_owner_exiting()
		return
	.init_trajectory(id, count, owner_player)
	owner_player.connect("tree_exiting", self, "_on_online_owner_exiting", [], CONNECT_ONESHOT)

func _on_online_owner_exiting() -> void:
	set_physics_process(false)
	queue_free()
