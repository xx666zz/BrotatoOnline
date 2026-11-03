extends "res://projectiles/laser_enemy/enemy_laser.gd"

func shoot() -> void:
	# A pooled laser can retain a freed Boss between host removal and reuse.
	if is_instance_valid(_hitbox) and not is_instance_valid(_hitbox.from):
		_hitbox.from = null
	.shoot()
