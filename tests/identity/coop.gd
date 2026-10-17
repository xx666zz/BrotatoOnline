extends Node
signal connected_players_updated(players)
var connected_players = []
var listening_for_inputs = false
const KEYBOARD_REMAPPED_DEVICE_ID = 7
const GAMEPAD_REMAPPED_DEVICE_ID = 6
enum PlayerType {KEYBOARD_AND_MOUSE, GAMEPAD_XBOX, GAMEPAD_PLAYSTATION, GAMEPAD_SWITCH}
