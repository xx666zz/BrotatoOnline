extends Control
var _players_to_join = []
var advance_count = 0
var finished = false
func _ready():
	for index in range(RunData.get_player_count()):
		_players_to_join.append(index)
	CoopService.connect("connected_players_updated", self, "_on_connected_players_updated")
	_setup_next_player()
func _setup_next_player():
	advance_count += 1
	if _players_to_join.empty():
		finished = true
	else:
		_players_to_join.pop_front()
func _on_connected_players_updated(_players):
	_setup_next_player()
