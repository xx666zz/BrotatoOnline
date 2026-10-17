extends Node
var saved_run_state = {}
var last_saved_run_state = {}
var saves = 0
var SAVE_PATH = "res://save_v3_0.json"
func save():
	saves += 1
