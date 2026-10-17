extends Node
var translations = {}
func _ready():
	var file = File.new()
	file.open("res://zh.json", File.READ)
	translations = parse_json(file.get_as_text())
	file.close()
func get_text(key):
	return str(translations.get(key, key))
