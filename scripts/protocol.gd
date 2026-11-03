extends Reference

# Package and wire versions are independent. All transports require Brotato 1.2.
const MOD_VERSION = "6.6.6"
const GAME_VERSION = "1.2.0.0"
const NETWORK_PROTOCOL_VERSION = "6.2.0"
const LAN_PROTOCOL_VERSION = 4
const DISCOVERY_PROTOCOL_VERSION = 2


static func get_game_version() -> String:
	return str(ProgressData.VERSION)


static func is_compatible(protocol_version, game_version) -> bool:
	return str(protocol_version) == NETWORK_PROTOCOL_VERSION and str(game_version) == GAME_VERSION and get_game_version() == GAME_VERSION


static func display_version(value, unknown: String) -> String:
	return unknown if value == null or str(value).strip_edges() == "" else str(value)


static func format_mismatch(template: String, peer_protocol, peer_game, unknown: String) -> String:
	return template % [NETWORK_PROTOCOL_VERSION, display_version(peer_protocol, unknown), get_game_version(), display_version(peer_game, unknown)]
