extends Node
var packets = []
var closed = []
var host_result = OK
var hosting = false
var available = false
var stops = 0
func start_host(_port, _limit=0):
	hosting = host_result == OK
	return host_result
func is_hosting():
	return hosting
func is_available():
	return available
func send_packet(peer, bytes, _channel, _reliable):
	packets.append({"peer": peer, "message": parse_json(bytes.get_string_from_utf8())})
	return true
func close_peer(peer, _immediately=true):
	closed.append(peer)
func stop():
	hosting = false
	stops += 1
