extends "res://projectiles/player_projectile.gd"

# Guard the vanilla range calculation against transient zero/missing projectile
# speed on replicated structures. Once a usable speed exists, vanilla performs
# the actual calculation.

const BROTATO_ONLINE_FALLBACK_PROJECTILE_SPEED = 3000.0


func _set_time_until_max_range() -> void:
	if _weapon_stats != null:
		var speed_value = _weapon_stats.get("projectile_speed")
		if speed_value != null and float(speed_value) > 0.0:
			._set_time_until_max_range()
			return
		if speed_value != null:
			_weapon_stats.set("projectile_speed", int(BROTATO_ONLINE_FALLBACK_PROJECTILE_SPEED))
			if not has_meta("brotato_online_warned_zero_projectile_speed"):
				set_meta("brotato_online_warned_zero_projectile_speed", true)
			._set_time_until_max_range()
			return

	var add_dist = PROJECTILE_ADDITIONAL_DISTANCE
	if Utils.is_manual_aim(player_index):
		add_dist /= 2.0
	_time_until_max_range = (_max_range + add_dist) as float / BROTATO_ONLINE_FALLBACK_PROJECTILE_SPEED
