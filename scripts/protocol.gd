extends Reference

# Package and wire versions are independent.
const MOD_VERSION = "6.6.6"
const NETWORK_PROTOCOL_VERSION = "6.3.0"
const LAN_PROTOCOL_VERSION = 4
const DISCOVERY_PROTOCOL_VERSION = 2

# Birth markers have a scene path before the spawner has a live Looter or EvilMob.
const LOOT_ENEMY_SYNC_MODES = {
	"res://entities/units/enemies/crash_zone/basic/looter/looter.tscn": "host_motion",
	"res://entities/units/enemies/abyss/basic/looting_pig/looting_pig.tscn": "host_motion",
	"res://entities/units/enemies/jungle/basic/harpymimus_looter/harpymimus_looter.tscn": "host_motion",
	"res://entities/units/enemies/crash_zone/basic/evil_mob/evil_mob.tscn": "host_target",
	"res://entities/units/enemies/abyss/basic/evil_mob_swimmer/evil_mob_swimmer.tscn": "host_target",
	"res://entities/units/enemies/jungle/basic/evil_mob_jungle/evil_mob_jungle.tscn": "host_target"
}


static func get_game_version() -> String:
	return str(ProgressData.VERSION)


static func is_compatible(protocol_version, game_version) -> bool:
	var local_version = get_game_version()
	return local_version != "" and str(protocol_version) == NETWORK_PROTOCOL_VERSION and str(game_version) == local_version


static func display_version(value, unknown: String) -> String:
	return unknown if value == null or str(value).strip_edges() == "" else str(value)


static func format_mismatch(protocol_template: String, game_template: String, peer_protocol, peer_game, unknown: String) -> String:
	if str(peer_protocol) != NETWORK_PROTOCOL_VERSION:
		return protocol_template % [NETWORK_PROTOCOL_VERSION, display_version(peer_protocol, unknown)]
	return game_template % [get_game_version(), display_version(peer_game, unknown)]
