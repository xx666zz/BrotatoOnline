extends Node

signal lobby_found(entry)

const PROTOCOL = "brotato_online_lan"
const PROTOCOL_VERSION = 1
const DEFAULT_GAME_PORT = 27462
const DISCOVERY_PORT = 27463
const SEARCH_DURATION_MSEC = 2500
const SEARCH_RETRY_MSEC = 500

var _host_socket: PacketPeerUDP = null
var _search_socket: PacketPeerUDP = null
var _searching = false
var _search_started_msec = 0
var _last_search_send_msec = 0
var _session_manager = null


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	set_process(true)
	call_deferred("_bind_session_manager")


func _bind_session_manager() -> void:
	var parent = get_parent()
	if parent != null:
		_session_manager = parent.get_node_or_null("BrotatoOnlineSessionManager")


func start_host_responder() -> int:
	stop_host_responder()
	_host_socket = PacketPeerUDP.new()
	var err = _host_socket.listen(DISCOVERY_PORT, "*", 65536)
	if err != OK:
		_host_socket = null
	return err


func stop_host_responder() -> void:
	if _host_socket != null:
		_host_socket.close()
	_host_socket = null


func start_search() -> int:
	stop_search()
	_search_socket = PacketPeerUDP.new()
	var err = _search_socket.listen(0, "*", 65536)
	if err != OK:
		_search_socket = null
		return err
	_search_socket.set_broadcast_enabled(true)
	_searching = true
	_search_started_msec = OS.get_ticks_msec()
	_last_search_send_msec = 0
	_send_search()
	return OK


func stop_search() -> void:
	_searching = false
	if _search_socket != null:
		_search_socket.close()
	_search_socket = null


func _process(_delta: float) -> void:
	_poll_host_requests()
	_poll_search_replies()
	if _searching:
		var now = OS.get_ticks_msec()
		if now - _search_started_msec >= SEARCH_DURATION_MSEC:
			stop_search()
		elif now - _last_search_send_msec >= SEARCH_RETRY_MSEC:
			_send_search()


func _send_search() -> void:
	if _search_socket == null:
		return
	_last_search_send_msec = OS.get_ticks_msec()
	_search_socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_search_socket.put_packet(to_json({"protocol": PROTOCOL, "protocol_version": PROTOCOL_VERSION, "action": "discover"}).to_utf8())


func _poll_host_requests() -> void:
	if _host_socket == null:
		return
	while _host_socket.get_available_packet_count() > 0:
		var data = _host_socket.get_packet()
		var address = _host_socket.get_packet_ip()
		var port = _host_socket.get_packet_port()
		var request = parse_json(data.get_string_from_utf8())
		if typeof(request) != TYPE_DICTIONARY or str(request.get("protocol", "")) != PROTOCOL or str(request.get("action", "")) != "discover":
			continue
		if _session_manager == null or not _session_manager.has_method("get_lan_discovery_info"):
			continue
		var response = _session_manager.get_lan_discovery_info()
		if typeof(response) != TYPE_DICTIONARY or response.empty():
			continue
		response["protocol"] = PROTOCOL
		response["protocol_version"] = PROTOCOL_VERSION
		_host_socket.set_dest_address(address, port)
		_host_socket.put_packet(to_json(response).to_utf8())


func _poll_search_replies() -> void:
	if _search_socket == null:
		return
	while _search_socket.get_available_packet_count() > 0:
		var data = _search_socket.get_packet()
		var address = _search_socket.get_packet_ip()
		var response = parse_json(data.get_string_from_utf8())
		if typeof(response) != TYPE_DICTIONARY or str(response.get("protocol", "")) != PROTOCOL:
			continue
		if int(response.get("protocol_version", 0)) != PROTOCOL_VERSION:
			continue
		var game_port = int(response.get("game_port", DEFAULT_GAME_PORT))
		var entry = response.duplicate(true)
		entry["source"] = "lan"
		entry["entry_id"] = address + ":" + str(game_port)
		entry["entry_key"] = "lan:" + address + ":" + str(game_port)
		entry["endpoint"] = {"address": address, "port": game_port}
		entry["ping_ms"] = max(0, OS.get_ticks_msec() - _search_started_msec)
		emit_signal("lobby_found", entry)
