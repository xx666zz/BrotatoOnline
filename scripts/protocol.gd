extends Reference

# Package and wire versions are independent.
const MOD_VERSION = "6.6.6"
const NETWORK_PROTOCOL_VERSION = "6.3.0"
const LAN_PROTOCOL_VERSION = 4
const DISCOVERY_PROTOCOL_VERSION = 2


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
