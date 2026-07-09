extends "res://entities/units/pet/jellyshield/jellyshield.gd"

# BrotatoOnline safety extension.
# If a stale online player slot was spawned and then trimmed, vanilla Jellyshield can keep
# a reference to the freed owner Player and crash in _physics_process() on global_position.

func init_trajectory(id: int, count: int, owner_player: Player) -> void:
	if owner_player == null or not is_instance_valid(owner_player) or owner_player.is_queued_for_deletion():
		queue_free()
		return
	.init_trajectory(id, count, owner_player)


func _physics_process(delta: float) -> void:
	if _owner_player == null or not is_instance_valid(_owner_player) or _owner_player.is_queued_for_deletion():
		if not has_meta("brotato_online_invalid_owner_logged"):
			set_meta("brotato_online_invalid_owner_logged", true)
		queue_free()
		return
	._physics_process(delta)
