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
		if not has_meta("brotato_online_warned_zero_projectile_speed"):
			set_meta("brotato_online_warned_zero_projectile_speed", true)

	var add_dist = PROJECTILE_ADDITIONAL_DISTANCE
	if Utils.is_manual_aim(player_index):
		add_dist /= 2.0
	_time_until_max_range = float(_max_range + add_dist) / BROTATO_ONLINE_FALLBACK_PROJECTILE_SPEED
