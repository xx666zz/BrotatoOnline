extends "res://projectiles/player_projectile.gd"

# BrotatoOnline safety extension.
# Some online client-side replicated structures can momentarily own an invalid
# RangedWeaponStats with projectile_speed == 0. Vanilla PlayerProjectile divides
# by projectile_speed in _set_time_until_max_range(), so guard the denominator
# to prevent a hard editor/runtime error while the authoritative Host state
# catches up.

const BROTATO_ONLINE_FALLBACK_PROJECTILE_SPEED = 3000.0


func _set_time_until_max_range() -> void:
	var add_dist = PROJECTILE_ADDITIONAL_DISTANCE
	if Utils.is_manual_aim(player_index):
		add_dist /= 2.0

	var speed = 0.0
	if _weapon_stats != null:
		var speed_value = _weapon_stats.get("projectile_speed")
		if speed_value != null:
			speed = float(speed_value)

	if speed <= 0.0:
		speed = BROTATO_ONLINE_FALLBACK_PROJECTILE_SPEED
		if _weapon_stats != null and _weapon_stats.get("projectile_speed") != null:
			_weapon_stats.set("projectile_speed", int(speed))
		if not has_meta("brotato_online_warned_zero_projectile_speed"):
			set_meta("brotato_online_warned_zero_projectile_speed", true)

	_time_until_max_range = (_max_range + add_dist) as float / speed
