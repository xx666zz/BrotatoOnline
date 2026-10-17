extends Node
enum PlayMode {SOLO, COOP}
var players_data = []
var start_wave_state = {}
func get_player_count() -> int:
	return players_data.size()
func get_player_character(_index):
	return null

var is_coop_run = true
var play_mode = PlayMode.COOP
func set_player_count(count):
	players_data.resize(count)
func set_coop_run(value):
	is_coop_run = value
