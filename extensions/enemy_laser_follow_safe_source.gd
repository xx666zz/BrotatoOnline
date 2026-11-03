extends "res://projectiles/laser_enemy/enemy_laser_follow.gd"

func shoot() -> void:
	# Both the pooled source and its current target can outlive Host replica removal.
	if is_instance_valid(_hitbox):
		var source = _hitbox.from
		if not is_instance_valid(source) or source.is_queued_for_deletion() or not is_instance_valid(source.get("current_target")):
			_hitbox.from = null
	target = null
	.shoot()
