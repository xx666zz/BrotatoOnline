extends Node

const API_MOD_ID = "six666-BrotatoOnline"
const ROUTE_PING_REQUEST = "player_list_ping_request"
const ROUTE_PING_RESPONSE = "player_list_ping_response"
const ROUTE_SNAPSHOT = "player_list_snapshot"
const ROUTE_SNAPSHOT_REQUEST = "player_list_snapshot_request"

const KEYBOARD_KEY = KEY_TAB
const GAMEPAD_TOGGLE_BUTTON = 8 # L3 / left-stick click
const GAMEPAD_CANCEL_BUTTON = 1
const GAMEPAD_CONFIRM_BUTTON = 0
const GAMEPAD_DPAD_UP_BUTTON = 12
const GAMEPAD_DPAD_DOWN_BUTTON = 13
const GAMEPAD_LEFT_STICK_Y_AXIS = 1
const GAMEPAD_STICK_THRESHOLD = 0.58

const PING_INTERVAL_MSEC = 1500
const SNAPSHOT_INTERVAL_MSEC = 1000
const PING_TIMEOUT_MSEC = 5000
const SNAPSHOT_REQUEST_MIN_INTERVAL_MSEC = 900
const WATCHER_TTL_MSEC = 3000
const DISPLAY_NAME_LIMIT = 48
const FOCUS_EMULATOR_MODAL_SUSPEND_META = "bo_player_list_modal_input_suspended"
const LATENCY_STATUS_CLIENT_UNSUPPORTED = "client_unsupported"
const LATENCY_STATUS_HOST_UNSUPPORTED = "host_unsupported"
const PING_COLUMN_WIDTH = 160

const FONT_PATHS = [
	"res://resources/fonts/actual/base/font_26_outline.tres",
	"res://resources/fonts/actual/base/font_26.tres"
]

var _api = null
var _session = null
var _slot_manager = null
var _steam = null

var _overlay_layer = null
var _overlay_root = null
var _panel = null
var _rows_container = null
var _row_panels = []
var _row_profile_buttons = []
var _visible_rows = []
var _selected_row = 0
var _overlay_open = false
var _opened_by_gamepad = false
var _gamepad_device = -1
var _left_stick_y_latched = false
var _gamepad_toggle_was_pressed_by_device = {}
var _gamepad_up_was_pressed = false
var _gamepad_down_was_pressed = false
var _gamepad_confirm_was_pressed = false
var _gamepad_cancel_was_pressed = false
var _previous_mouse_mode = Input.MOUSE_MODE_VISIBLE
var _mouse_mode_overridden = false

# While the gamepad player list is open, raw joypad events belong to this overlay.
# Brotato also polls Input actions directly for movement and synthesizes UI actions
# from InputService, so set_input_as_handled() alone cannot make the overlay modal.
var _suppressed_gamepad_action_events = []
var _suspended_focus_emulators = []
var _input_service = null
var _input_service_was_processing = false
var _input_service_was_processing_input = false
var _input_service_suspended = false

var _latest_snapshot_rows = []
var _remote_display_name_by_player_index = {}
var _ping_ms_by_player_index = {}
var _pending_ping_by_player_index = {}
var _ping_sequence = 0
var _last_ping_round_msec = 0
var _last_snapshot_send_msec = 0
var _last_snapshot_request_msec = 0
var _watcher_until_msec_by_player_index = {}
var _last_render_key = ""
var _font = null


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	set_process(true)
	set_process_input(true)
	_resolve_dependencies()
	_connect_api_signal()
	_connect_language_signal()


func _input(event: InputEvent) -> void:
	if not _is_online():
		return

	# Keyboard Tab can still be handled immediately when it reaches us, but the
	# _process() polling path below is the authoritative fallback for menu scenes
	# that consume GUI input before this persistent mod node receives it.
	if event is InputEventKey and event.scancode == KEYBOARD_KEY and not event.echo:
		if event.pressed:
			_open_overlay(false, -1)
		else:
			if _overlay_open and not _opened_by_gamepad:
				_close_overlay()
		get_tree().set_input_as_handled()


func _process(_delta: float) -> void:
	_resolve_dependencies()
	_connect_api_signal()

	if not _is_online():
		if _overlay_open:
			_close_overlay()
		_latest_snapshot_rows.clear()
		_remote_display_name_by_player_index.clear()
		_ping_ms_by_player_index.clear()
		_pending_ping_by_player_index.clear()
		_watcher_until_msec_by_player_index.clear()
		_reset_gamepad_poll_state()
		return

	# Do not rely on SceneTree input propagation here. Shop / upgrade / pause GUI
	# can consume raw keyboard and joypad events before this persistent node sees
	# them. Physical polling keeps Tab and L3 available in every run scene.
	_poll_overlay_open_controls()

	if _overlay_open:
		_force_mouse_visible()
		if _opened_by_gamepad:
			_poll_gamepad_overlay_controls()
		if not _is_host():
			_request_snapshot_now()

	if _is_host():
		_poll_host_ping_and_snapshot()


func _poll_overlay_open_controls() -> void:
	# Tab remains hold-to-show. It has priority while the overlay is closed.
	if _overlay_open and not _opened_by_gamepad:
		_poll_gamepad_toggle_edges(false)
		if not Input.is_key_pressed(KEYBOARD_KEY):
			_close_overlay()
		return

	if not _overlay_open and Input.is_key_pressed(KEYBOARD_KEY):
		_poll_gamepad_toggle_edges(false)
		_open_overlay(false, -1)
		return

	# L3 is toggle-to-show rather than hold-to-show. Holding the stick click while
	# also trying to move the left stick is awkward, so a second L3 press (or B)
	# closes the overlay. Edge polling also works when menu GUI consumed the event.
	var toggle_device = _poll_gamepad_toggle_edges(true)
	if toggle_device < 0:
		return
	if _overlay_open and _opened_by_gamepad:
		if toggle_device == _gamepad_device:
			_close_overlay()
	elif not _overlay_open:
		_open_overlay(true, toggle_device)


func _poll_gamepad_toggle_edges(return_pressed_device: bool) -> int:
	var pressed_device = -1
	var connected = {}
	for device_value in Input.get_connected_joypads():
		var device = int(device_value)
		connected[device] = true
		var pressed = Input.is_joy_button_pressed(device, GAMEPAD_TOGGLE_BUTTON)
		var was_pressed = bool(_gamepad_toggle_was_pressed_by_device.get(device, false))
		if return_pressed_device and pressed and not was_pressed and pressed_device < 0:
			pressed_device = device
		_gamepad_toggle_was_pressed_by_device[device] = pressed
	var stale = []
	for device in _gamepad_toggle_was_pressed_by_device.keys():
		if not connected.has(device):
			stale.append(device)
	for device in stale:
		_gamepad_toggle_was_pressed_by_device.erase(device)
	return pressed_device


func _poll_gamepad_overlay_controls() -> void:
	if _gamepad_device < 0:
		return

	var up_pressed = Input.is_joy_button_pressed(_gamepad_device, GAMEPAD_DPAD_UP_BUTTON)
	var down_pressed = Input.is_joy_button_pressed(_gamepad_device, GAMEPAD_DPAD_DOWN_BUTTON)
	var confirm_pressed = Input.is_joy_button_pressed(_gamepad_device, GAMEPAD_CONFIRM_BUTTON)
	var cancel_pressed = Input.is_joy_button_pressed(_gamepad_device, GAMEPAD_CANCEL_BUTTON)

	var moved = false
	if up_pressed and not _gamepad_up_was_pressed:
		_move_selection(-1)
		moved = true
	elif down_pressed and not _gamepad_down_was_pressed:
		_move_selection(1)
		moved = true

	# Left-stick navigation is polled directly too, because _input() motion events
	# are not reliable in focused shop / upgrade menus.
	var axis_value = Input.get_joy_axis(_gamepad_device, GAMEPAD_LEFT_STICK_Y_AXIS)
	if abs(axis_value) < GAMEPAD_STICK_THRESHOLD * 0.55:
		_left_stick_y_latched = false
	elif not moved and not _left_stick_y_latched:
		_left_stick_y_latched = true
		_move_selection(1 if axis_value > 0.0 else -1)

	if confirm_pressed and not _gamepad_confirm_was_pressed:
		_activate_selected_profile()
	if cancel_pressed and not _gamepad_cancel_was_pressed:
		_close_overlay()

	_gamepad_up_was_pressed = up_pressed
	_gamepad_down_was_pressed = down_pressed
	_gamepad_confirm_was_pressed = confirm_pressed
	_gamepad_cancel_was_pressed = cancel_pressed


func _reset_gamepad_poll_state() -> void:
	_left_stick_y_latched = false
	_gamepad_up_was_pressed = false
	_gamepad_down_was_pressed = false
	_gamepad_confirm_was_pressed = false
	_gamepad_cancel_was_pressed = false


func _open_overlay(by_gamepad: bool, device: int) -> void:
	if not _is_online():
		return
	_ensure_overlay()
	if _overlay_root == null:
		return
	_overlay_open = true
	_opened_by_gamepad = by_gamepad
	_gamepad_device = device if by_gamepad else -1
	_reset_gamepad_poll_state()
	if by_gamepad and device >= 0:
		_gamepad_toggle_was_pressed_by_device[device] = Input.is_joy_button_pressed(device, GAMEPAD_TOGGLE_BUTTON)
	_overlay_root.show()
	if _overlay_layer != null and _overlay_layer.get_parent() != null:
		_overlay_layer.get_parent().move_child(_overlay_layer, _overlay_layer.get_parent().get_child_count() - 1)
	_begin_mouse_interaction()
	_force_mouse_visible()
	call_deferred("_force_mouse_visible")
	_begin_modal_input(by_gamepad, device)
	_request_snapshot_now()
	_refresh_visible_rows(true)


func _close_overlay() -> void:
	if not _overlay_open:
		return
	_overlay_open = false
	_opened_by_gamepad = false
	_gamepad_device = -1
	_reset_gamepad_poll_state()
	_end_modal_input()
	_end_mouse_interaction()
	if _overlay_root != null and is_instance_valid(_overlay_root):
		_overlay_root.hide()


func _begin_mouse_interaction() -> void:
	if not _mouse_mode_overridden:
		_previous_mouse_mode = Input.get_mouse_mode()
		_mouse_mode_overridden = true
	_force_mouse_visible()


func _force_mouse_visible() -> void:
	if not _overlay_open:
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _end_mouse_interaction() -> void:
	if not _mouse_mode_overridden:
		return
	_mouse_mode_overridden = false
	Input.set_mouse_mode(_previous_mouse_mode)


func _begin_modal_input(by_gamepad: bool, physical_device: int) -> void:
	_end_modal_input()
	# InputService hides the cursor in co-op and synthesizes d-pad/stick UI actions.
	# FocusEmulator can also consume the same raw event before the overlay gets it.
	# Suspend both for the lifetime of this modal overlay.
	_suspend_input_service()
	_suspend_focus_emulators()
	if by_gamepad and physical_device >= 0:
		_suppress_gamepad_actions(physical_device)


func _end_modal_input() -> void:
	_restore_gamepad_actions()
	_restore_focus_emulators()
	_restore_input_service()


func _suppress_gamepad_actions(physical_device: int) -> void:
	_restore_gamepad_actions()
	var remapped_device = _get_remapped_gamepad_device(physical_device)
	if remapped_device < 0:
		return
	var suffix = "_" + str(remapped_device)
	for action_value in InputMap.get_actions():
		var action_name = str(action_value)
		if not action_name.ends_with(suffix):
			continue
		var events = InputMap.get_action_list(action_name).duplicate()
		var removed_any = false
		for input_event in events:
			if not (input_event is InputEventJoypadButton or input_event is InputEventJoypadMotion):
				continue
			if int(input_event.device) != physical_device:
				continue
			_suppressed_gamepad_action_events.append({
				"action": action_name,
				"event": input_event
			})
			InputMap.action_erase_event(action_name, input_event)
			removed_any = true
		if removed_any:
			# If the player was already holding a stick/d-pad direction when the player-list button was
			# pressed, clear the cached action state immediately as well.
			Input.action_release(action_name)


func _restore_gamepad_actions() -> void:
	for state in _suppressed_gamepad_action_events:
		if typeof(state) != TYPE_DICTIONARY:
			continue
		var action_name = str(state.get("action", ""))
		var input_event = state.get("event", null)
		if action_name == "" or input_event == null:
			continue
		if not InputMap.has_action(action_name):
			continue
		InputMap.action_add_event(action_name, input_event)
	_suppressed_gamepad_action_events.clear()


func _get_remapped_gamepad_device(physical_device: int) -> int:
	if physical_device < 0:
		return -1
	if CoopService != null and physical_device == 0:
		return int(CoopService.GAMEPAD_REMAPPED_DEVICE_ID)
	return physical_device


func _suspend_input_service() -> void:
	if _input_service_suspended:
		return
	_input_service = get_node_or_null("/root/InputService")
	if _input_service == null or not is_instance_valid(_input_service):
		_input_service = null
		return
	_input_service_was_processing = _input_service.is_processing()
	_input_service_was_processing_input = _input_service.is_processing_input()
	_input_service_suspended = true
	_input_service.set_process(false)
	_input_service.set_process_input(false)


func _restore_input_service() -> void:
	if not _input_service_suspended:
		return
	if _input_service != null and is_instance_valid(_input_service):
		_input_service.set_process(_input_service_was_processing)
		_input_service.set_process_input(_input_service_was_processing_input)
	_input_service = null
	_input_service_suspended = false


func _suspend_focus_emulators() -> void:
	_restore_focus_emulators()
	if Utils == null:
		return
	for player_index in range(8):
		var focus_emulator = Utils.get_focus_emulator(player_index)
		if focus_emulator == null or not is_instance_valid(focus_emulator):
			continue
		var already_added = false
		for state in _suspended_focus_emulators:
			if typeof(state) == TYPE_DICTIONARY and state.get("node", null) == focus_emulator:
				already_added = true
				break
		if already_added:
			continue
		_suspended_focus_emulators.append({
			"node": focus_emulator,
			"was_processing_input": focus_emulator.is_processing_input()
		})
		# MenuSyncManager continuously repairs FocusEmulator ownership on shop /
		# progression pages. Mark this as an intentional modal suspension so that
		# repair code cannot re-enable _input() and consume mouse events before the
		# player-list Controls receive them.
		focus_emulator.set_meta(FOCUS_EMULATOR_MODAL_SUSPEND_META, true)
		focus_emulator.set_process_input(false)


func _restore_focus_emulators() -> void:
	for state in _suspended_focus_emulators:
		if typeof(state) != TYPE_DICTIONARY:
			continue
		var focus_emulator = state.get("node", null)
		if focus_emulator == null or not is_instance_valid(focus_emulator):
			continue
		if focus_emulator.has_meta(FOCUS_EMULATOR_MODAL_SUSPEND_META):
			focus_emulator.remove_meta(FOCUS_EMULATOR_MODAL_SUSPEND_META)
		focus_emulator.set_process_input(bool(state.get("was_processing_input", false)))
	_suspended_focus_emulators.clear()


func _poll_host_ping_and_snapshot() -> void:
	var now = OS.get_ticks_msec()
	_prune_watchers(now)
	if not _overlay_open and _watcher_until_msec_by_player_index.empty():
		return
	_prune_stale_pings(now)
	if now - _last_ping_round_msec >= PING_INTERVAL_MSEC:
		_last_ping_round_msec = now
		_start_ping_round(now)
	if now - _last_snapshot_send_msec >= SNAPSHOT_INTERVAL_MSEC:
		_last_snapshot_send_msec = now
		_publish_snapshot()


func _prune_watchers(now: int) -> void:
	var stale = []
	for player_index in _watcher_until_msec_by_player_index.keys():
		if now >= int(_watcher_until_msec_by_player_index[player_index]):
			stale.append(player_index)
	for player_index in stale:
		_watcher_until_msec_by_player_index.erase(player_index)


func _start_ping_round(now: int) -> void:
	if _api == null or not _api.has_method("send_to_player"):
		return
	for player_index in _get_remote_player_indices():
		var idx = int(player_index)
		var peer_key = _get_remote_peer_key(idx)
		if not _peer_supports_player_list(peer_key):
			_pending_ping_by_player_index.erase(idx)
			_ping_ms_by_player_index[idx] = -1
			continue
		_ping_sequence += 1
		var nonce = str(idx) + ":" + str(_ping_sequence) + ":" + str(OS.get_ticks_usec())
		_pending_ping_by_player_index[idx] = {
			"nonce": nonce,
			"sent_msec": now
		}
		_api.send_to_player(idx, API_MOD_ID, ROUTE_PING_REQUEST, {
			"nonce": nonce,
			"sent_msec": now
		}, {"reliable": false})


func _prune_stale_pings(now: int) -> void:
	var stale = []
	for player_index in _pending_ping_by_player_index.keys():
		var pending = _pending_ping_by_player_index[player_index]
		if now - int(pending.get("sent_msec", now)) > PING_TIMEOUT_MSEC:
			stale.append(player_index)
	for player_index in stale:
		_pending_ping_by_player_index.erase(player_index)
		_ping_ms_by_player_index[int(player_index)] = -1


func _publish_snapshot() -> void:
	if not _is_host():
		return
	var rows = _build_host_rows()
	_latest_snapshot_rows = rows.duplicate(true)
	if _api != null and _api.has_method("broadcast"):
		_api.broadcast(API_MOD_ID, ROUTE_SNAPSHOT, {"rows": rows}, {"reliable": false})
	if _overlay_open:
		_refresh_visible_rows(false)


func _request_snapshot_now() -> void:
	var now = OS.get_ticks_msec()
	if now - _last_snapshot_request_msec < SNAPSHOT_REQUEST_MIN_INTERVAL_MSEC:
		return
	_last_snapshot_request_msec = now
	if _is_host():
		_publish_snapshot()
		return
	if _api != null and _api.has_method("send_to_host"):
		_api.send_to_host(API_MOD_ID, ROUTE_SNAPSHOT_REQUEST, {}, {"reliable": false})


func _on_mod_message_received(mod_id: String, route: String, payload: Dictionary, meta: Dictionary) -> void:
	if mod_id != API_MOD_ID:
		return
	if route == ROUTE_PING_REQUEST:
		_handle_ping_request(payload)
		return
	if route == ROUTE_PING_RESPONSE:
		_handle_ping_response(payload, meta)
		return
	if route == ROUTE_SNAPSHOT:
		_handle_snapshot(payload)
		return
	if route == ROUTE_SNAPSHOT_REQUEST:
		if _is_host():
			var watcher_index = int(meta.get("from_player_index", -1))
			if watcher_index >= 0:
				_watcher_until_msec_by_player_index[watcher_index] = OS.get_ticks_msec() + WATCHER_TTL_MSEC
			_publish_snapshot()


func _handle_ping_request(payload: Dictionary) -> void:
	if _is_host() or _api == null or not _api.has_method("send_to_host"):
		return
	var nonce = str(payload.get("nonce", ""))
	if nonce == "" or nonce.length() > 160:
		return
	_api.send_to_host(API_MOD_ID, ROUTE_PING_RESPONSE, {
		"nonce": nonce,
		"display_name": _get_local_primary_display_name()
	}, {"reliable": false})


func _handle_ping_response(payload: Dictionary, meta: Dictionary) -> void:
	if not _is_host():
		return
	var player_index = int(meta.get("from_player_index", -1))
	if player_index < 0 or not _pending_ping_by_player_index.has(player_index):
		return
	var pending = _pending_ping_by_player_index[player_index]
	var nonce = str(payload.get("nonce", ""))
	if nonce == "" or nonce != str(pending.get("nonce", "")):
		return
	var ping_ms = max(0, OS.get_ticks_msec() - int(pending.get("sent_msec", OS.get_ticks_msec())))
	_pending_ping_by_player_index.erase(player_index)
	_ping_ms_by_player_index[player_index] = ping_ms
	var display_name = _sanitize_display_name(str(payload.get("display_name", "")))
	if display_name != "":
		_remote_display_name_by_player_index[player_index] = display_name


func _handle_snapshot(payload: Dictionary) -> void:
	var rows = payload.get("rows", [])
	if typeof(rows) != TYPE_ARRAY:
		return
	var sanitized = []
	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var player_index = int(raw_row.get("player_index", -1))
		if player_index < 0:
			continue
		var steam_id = str(raw_row.get("steam_id", ""))
		if not _is_numeric_steam_id(steam_id):
			steam_id = ""
		sanitized.append({
			"player_index": player_index,
			"name": _sanitize_display_name(str(raw_row.get("name", ""))),
			"ping_ms": int(raw_row.get("ping_ms", -1)),
			"latency_status": _sanitize_latency_status(str(raw_row.get("latency_status", ""))),
			"steam_id": steam_id,
			"steam_connection": bool(raw_row.get("steam_connection", false)) and steam_id != "",
			"local": bool(raw_row.get("local", false)),
			"host": bool(raw_row.get("host", false))
		})
	_latest_snapshot_rows = sanitized
	if _overlay_open:
		_refresh_visible_rows(false)


func _build_host_rows() -> Array:
	var rows = []
	var player_count = int(CoopService.connected_players.size()) if CoopService != null else 0
	if player_count <= 0:
		player_count = 1
	var local_indices = _get_local_player_indices()
	var primary_local_index = int(local_indices[0]) if not local_indices.empty() else 0
	var primary_name = _get_local_primary_display_name()
	var self_id = _get_self_peer_key()
	var self_has_steam_profile = _host_self_has_steam_profile(self_id)

	for player_index in range(player_count):
		var is_local = local_indices.has(player_index)
		var peer_key = ""
		var steam_connection = false
		var steam_id = ""
		var display_name = ""
		var ping_ms = 0 if is_local else int(_ping_ms_by_player_index.get(player_index, -1))
		var latency_status = ""
		if is_local:
			if player_index == primary_local_index:
				display_name = primary_name
				if self_has_steam_profile:
					steam_id = self_id
					steam_connection = true
			else:
				display_name = _txt("BROTATO_ONLINE_PLAYER_LIST_LOCAL_PLAYER") % [player_index + 1]
		else:
			peer_key = _get_remote_peer_key(player_index)
			if not _peer_supports_player_list(peer_key):
				latency_status = LATENCY_STATUS_CLIENT_UNSUPPORTED
			steam_connection = _is_peer_steam_connection(peer_key)
			if steam_connection and _is_numeric_steam_id(peer_key):
				steam_id = peer_key
				display_name = _get_steam_persona_name(peer_key)
			if display_name == "":
				display_name = _sanitize_display_name(str(_remote_display_name_by_player_index.get(player_index, "")))
			if display_name == "":
				display_name = _txt("BROTATO_ONLINE_PLAYER_LIST_PLAYER") % [player_index + 1]

		rows.append({
			"player_index": player_index,
			"name": display_name,
			"ping_ms": ping_ms,
			"latency_status": latency_status,
			"steam_id": steam_id,
			"steam_connection": steam_connection and steam_id != "",
			"local": is_local,
			"host": player_index == primary_local_index
		})
	return rows


func _refresh_visible_rows(force: bool) -> void:
	if not _overlay_open or _rows_container == null or not is_instance_valid(_rows_container):
		return
	var rows = _build_host_rows() if _is_host() else _latest_snapshot_rows.duplicate(true)
	if rows.empty():
		rows = _build_fallback_rows()
	var render_key = to_json(rows)
	if not force and render_key == _last_render_key:
		_refresh_row_selection_styles()
		return
	_last_render_key = render_key
	_visible_rows = rows
	_selected_row = int(clamp(_selected_row, 0, max(0, rows.size() - 1)))
	_rebuild_rows()


func _build_fallback_rows() -> Array:
	var result = []
	var player_count = int(max(1, CoopService.connected_players.size())) if CoopService != null else 1
	var local_indices = _get_local_player_indices()
	var primary_local_index = int(local_indices[0]) if not local_indices.empty() else 0
	var primary_name = _get_local_primary_display_name()
	var self_id = _get_self_peer_key()
	var self_has_steam_profile = _host_self_has_steam_profile(self_id)
	var host_supports_player_list = _host_supports_player_list()
	for i in range(player_count):
		var is_local = local_indices.has(i)
		var peer_key = ""
		var steam_id = ""
		var steam_connection = false
		var display_name = ""
		var latency_status = ""
		if is_local:
			if i == primary_local_index:
				display_name = primary_name
				if self_has_steam_profile:
					steam_id = self_id
					steam_connection = true
			else:
				display_name = _txt("BROTATO_ONLINE_PLAYER_LIST_LOCAL_PLAYER") % [i + 1]
		else:
			peer_key = _get_remote_peer_key(i)
			steam_connection = _is_peer_steam_connection(peer_key)
			if steam_connection and _is_numeric_steam_id(peer_key):
				steam_id = peer_key
				display_name = _get_steam_persona_name(peer_key)
			if display_name == "":
				display_name = _sanitize_display_name(str(_remote_display_name_by_player_index.get(i, "")))
			if display_name == "":
				display_name = _txt("BROTATO_ONLINE_PLAYER_LIST_PLAYER") % [i + 1]
			if not _is_host() and not host_supports_player_list:
				latency_status = LATENCY_STATUS_HOST_UNSUPPORTED
			elif _is_host() and not _peer_supports_player_list(peer_key):
				latency_status = LATENCY_STATUS_CLIENT_UNSUPPORTED
		result.append({
			"player_index": i,
			"name": display_name,
			"ping_ms": 0 if is_local else -1,
			"latency_status": latency_status,
			"steam_id": steam_id,
			"steam_connection": steam_connection and steam_id != "",
			"local": is_local,
			"host": i == 0
		})
	return result


func _rebuild_rows() -> void:
	for child in _rows_container.get_children():
		child.queue_free()
	_row_panels.clear()
	_row_profile_buttons.clear()

	for row_index in range(_visible_rows.size()):
		var row_data = _visible_rows[row_index]
		var panel = PanelContainer.new()
		panel.rect_min_size = Vector2(705, 58)
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		_rows_container.add_child(panel)
		_row_panels.append(panel)
		panel.connect("gui_input", self, "_on_row_gui_input", [row_index])

		var margin = MarginContainer.new()
		margin.add_constant_override("margin_left", 14)
		margin.add_constant_override("margin_right", 14)
		margin.add_constant_override("margin_top", 7)
		margin.add_constant_override("margin_bottom", 7)
		panel.add_child(margin)

		var hbox = HBoxContainer.new()
		hbox.add_constant_override("separation", 12)
		margin.add_child(hbox)

		var name_label = Label.new()
		name_label.text = "P" + str(int(row_data.get("player_index", row_index)) + 1) + "  " + str(row_data.get("name", ""))
		name_label.rect_min_size = Vector2(385, 42)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.valign = Label.VALIGN_CENTER
		_apply_font(name_label)
		hbox.add_child(name_label)

		var ping_label = Label.new()
		ping_label.text = _format_ping(int(row_data.get("ping_ms", -1)), str(row_data.get("latency_status", "")))
		ping_label.rect_min_size = Vector2(PING_COLUMN_WIDTH, 42)
		ping_label.align = Label.ALIGN_CENTER
		ping_label.valign = Label.VALIGN_CENTER
		_apply_font(ping_label)
		hbox.add_child(ping_label)

		var profile_button = Button.new()
		profile_button.rect_min_size = Vector2(130, 42)
		profile_button.text = _txt("BROTATO_ONLINE_PLAYER_LIST_PROFILE")
		profile_button.focus_mode = Control.FOCUS_NONE
		_apply_font(profile_button)
		var steam_id = str(row_data.get("steam_id", ""))
		var can_profile = bool(row_data.get("steam_connection", false)) and _is_numeric_steam_id(steam_id)
		profile_button.visible = can_profile
		profile_button.disabled = not can_profile
		if can_profile:
			profile_button.connect("button_down", self, "_on_profile_button_pressed", [steam_id])
		hbox.add_child(profile_button)
		_row_profile_buttons.append(profile_button)

	_refresh_row_selection_styles()


func _on_row_gui_input(event: InputEvent, row_index: int) -> void:
	if event is InputEventMouseMotion:
		if row_index != _selected_row:
			_selected_row = row_index
			_refresh_row_selection_styles()
	elif event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
		_selected_row = row_index
		_refresh_row_selection_styles()


func _move_selection(direction: int) -> void:
	if _visible_rows.empty():
		return
	_selected_row = (_selected_row + direction + _visible_rows.size()) % _visible_rows.size()
	_refresh_row_selection_styles()


func _activate_selected_profile() -> void:
	if _selected_row < 0 or _selected_row >= _visible_rows.size():
		return
	var row = _visible_rows[_selected_row]
	if not bool(row.get("steam_connection", false)):
		return
	_open_steam_profile(str(row.get("steam_id", "")))


func _on_profile_button_pressed(steam_id: String) -> void:
	_open_steam_profile(steam_id)


func _open_steam_profile(steam_id: String) -> void:
	if not _is_numeric_steam_id(steam_id):
		return
	_resolve_steam()
	if _steam == null:
		return
	if _steam.has_method("activateGameOverlayToUser"):
		_steam.activateGameOverlayToUser("steamid", int(steam_id))
		return
	if _steam.has_method("activateGameOverlayToWebPage"):
		_steam.activateGameOverlayToWebPage("https://steamcommunity.com/profiles/" + steam_id)


func _refresh_row_selection_styles() -> void:
	for i in range(_row_panels.size()):
		var panel = _row_panels[i]
		if panel == null or not is_instance_valid(panel):
			continue
		var selected = _overlay_open and _opened_by_gamepad and i == _selected_row
		var bg = Color(0.28, 0.20, 0.07, 0.94) if selected else Color(0.08, 0.08, 0.08, 0.88)
		var border = Color(1.0, 0.82, 0.30, 0.95) if selected else Color(1.0, 1.0, 1.0, 0.16)
		panel.add_stylebox_override("panel", _make_panel_style(bg, border, 8))


func _ensure_overlay() -> void:
	if _overlay_root != null and is_instance_valid(_overlay_root):
		return
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "BrotatoOnlinePlayerListLayer"
	_overlay_layer.layer = 90
	_overlay_layer.pause_mode = Node.PAUSE_MODE_PROCESS
	add_child(_overlay_layer)

	_overlay_root = Control.new()
	_overlay_root.name = "PlayerListOverlay"
	_overlay_root.anchor_right = 1.0
	_overlay_root.anchor_bottom = 1.0
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_root.pause_mode = Node.PAUSE_MODE_PROCESS
	_overlay_layer.add_child(_overlay_root)

	var dim = ColorRect.new()
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0, 0, 0, 0.28)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.add_child(dim)

	var center = CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.rect_min_size = Vector2(780, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_stylebox_override("panel", _make_panel_style(Color(0.035, 0.035, 0.035, 0.97), Color(1, 1, 1, 0.22), 12))
	center.add_child(_panel)

	var outer_margin = MarginContainer.new()
	outer_margin.add_constant_override("margin_left", 24)
	outer_margin.add_constant_override("margin_right", 24)
	outer_margin.add_constant_override("margin_top", 20)
	outer_margin.add_constant_override("margin_bottom", 20)
	_panel.add_child(outer_margin)

	var vbox = VBoxContainer.new()
	vbox.add_constant_override("separation", 10)
	outer_margin.add_child(vbox)

	var title = Label.new()
	title.name = "Title"
	title.text = _txt("BROTATO_ONLINE_PLAYER_LIST_TITLE")
	title.align = Label.ALIGN_CENTER
	title.rect_min_size = Vector2(0, 44)
	_apply_font(title)
	vbox.add_child(title)

	var header = HBoxContainer.new()
	header.add_constant_override("separation", 12)
	vbox.add_child(header)
	var player_header = _make_header_label(_txt("BROTATO_ONLINE_PLAYER_LIST_PLAYER_HEADER"), 385, Label.ALIGN_LEFT)
	player_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(player_header)
	header.add_child(_make_header_label(_txt("BROTATO_ONLINE_PLAYER_LIST_PING_HEADER"), PING_COLUMN_WIDTH, Label.ALIGN_CENTER))
	header.add_child(_make_header_label("", 130, Label.ALIGN_CENTER))

	_rows_container = VBoxContainer.new()
	_rows_container.name = "Rows"
	_rows_container.add_constant_override("separation", 6)
	vbox.add_child(_rows_container)

	var hint = Label.new()
	hint.name = "Hint"
	hint.text = _txt("BROTATO_ONLINE_PLAYER_LIST_HINT")
	hint.align = Label.ALIGN_CENTER
	hint.autowrap = true
	hint.rect_min_size = Vector2(705, 36)
	_apply_font(hint)
	vbox.add_child(hint)

	_overlay_root.hide()


func _make_header_label(text: String, width: int, align: int) -> Label:
	var label = Label.new()
	label.text = text
	label.rect_min_size = Vector2(width, 34)
	label.align = align
	label.valign = Label.VALIGN_CENTER
	_apply_font(label)
	return label


func _make_panel_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _apply_font(control: Control) -> void:
	if _font == null:
		for path in FONT_PATHS:
			var candidate = load(path)
			if candidate != null:
				_font = candidate
				break
	if _font != null:
		control.add_font_override("font", _font)


func _format_ping(ping_ms: int, latency_status: String = "") -> String:
	if ping_ms < 0:
		if latency_status == LATENCY_STATUS_CLIENT_UNSUPPORTED:
			return _txt("BROTATO_ONLINE_PLAYER_LIST_CLIENT_UNSUPPORTED")
		if latency_status == LATENCY_STATUS_HOST_UNSUPPORTED:
			return _txt("BROTATO_ONLINE_PLAYER_LIST_HOST_UNSUPPORTED")
		return "--"
	return str(ping_ms) + " ms"


func _sanitize_latency_status(value: String) -> String:
	if value == LATENCY_STATUS_CLIENT_UNSUPPORTED or value == LATENCY_STATUS_HOST_UNSUPPORTED:
		return value
	return ""


func _get_remote_player_indices() -> Array:
	var result = []
	if CoopService == null:
		return result
	for i in range(CoopService.connected_players.size()):
		if _is_remote_player_index(i):
			result.append(i)
	return result


func _get_local_player_indices() -> Array:
	if _slot_manager != null and _slot_manager.has_method("get_local_player_indices"):
		var result = _slot_manager.get_local_player_indices()
		if typeof(result) == TYPE_ARRAY:
			return result.duplicate(true)
	var fallback = []
	if CoopService != null:
		for i in range(CoopService.connected_players.size()):
			fallback.append(i)
	return fallback


func _is_remote_player_index(player_index: int) -> bool:
	return _slot_manager != null and _slot_manager.has_method("is_remote_player_index") and bool(_slot_manager.is_remote_player_index(player_index))


func _get_remote_peer_key(player_index: int) -> String:
	if _slot_manager != null and _slot_manager.has_method("get_remote_steam_id"):
		return str(_slot_manager.get_remote_steam_id(player_index))
	return ""


func _get_self_peer_key() -> String:
	if _session != null and _session.has_method("get_self_steam_id"):
		return str(_session.get_self_steam_id())
	return ""


func _is_peer_steam_connection(peer_key: String) -> bool:
	if _session != null and _session.has_method("is_peer_steam_connection"):
		if bool(_session.is_peer_steam_connection(peer_key)):
			return true
		# Clients normally have no direct SteamNetworkingMessages connection to the
		# other clients, but a numeric peer id in a Steam lobby is still sufficient
		# for persona lookup/profile opening in the local player-list fallback.
		if _session.has_method("get_lobby_id") and int(_session.get_lobby_id()) != 0 and _is_numeric_steam_id(peer_key):
			return true
	return _is_numeric_steam_id(peer_key)


func _peer_supports_player_list(peer_key: String) -> bool:
	if peer_key == "":
		return false
	if _session != null and _session.has_method("is_player_list_enabled_for_peer"):
		return bool(_session.is_player_list_enabled_for_peer(peer_key))
	return false


func _host_supports_player_list() -> bool:
	if _is_host():
		return true
	if _session != null and _session.has_method("is_game_host_player_list_enabled"):
		return bool(_session.is_game_host_player_list_enabled())
	return false


func _host_self_has_steam_profile(self_id: String) -> bool:
	if not _is_numeric_steam_id(self_id):
		return false
	if _session != null and _session.has_method("get_lobby_id"):
		return int(_session.get_lobby_id()) != 0
	return true


func _get_local_primary_display_name() -> String:
	_resolve_steam()
	if _steam != null and _steam.has_method("getPersonaName"):
		var name = _sanitize_display_name(str(_steam.getPersonaName()))
		if name != "":
			return name
	return _txt("BROTATO_ONLINE_PLAYER_LIST_PLAYER") % [1]


func _get_steam_persona_name(steam_id: String) -> String:
	if not _is_numeric_steam_id(steam_id):
		return ""
	_resolve_steam()
	if _steam != null and _steam.has_method("getFriendPersonaName"):
		return _sanitize_display_name(str(_steam.getFriendPersonaName(int(steam_id))))
	return ""


func _sanitize_display_name(value: String) -> String:
	var text = value.replace("\r", " ").replace("\n", " ").strip_edges()
	while text.find("  ") != -1:
		text = text.replace("  ", " ")
	if text.length() > DISPLAY_NAME_LIMIT:
		text = text.substr(0, DISPLAY_NAME_LIMIT)
	return text


func _is_numeric_steam_id(value: String) -> bool:
	if value == "" or value == "0" or value.begins_with("lan:"):
		return false
	return value.is_valid_integer() and int(value) > 0


func _is_online() -> bool:
	return _session != null and _session.has_method("is_online_session_active") and bool(_session.is_online_session_active())


func _is_host() -> bool:
	return _session != null and _session.has_method("is_game_host") and bool(_session.is_game_host())


func _resolve_dependencies() -> void:
	var parent = get_parent()
	if parent == null:
		return
	if _api == null or not is_instance_valid(_api):
		_api = parent.get_node_or_null("BrotatoOnlineAPI")
	if _session == null or not is_instance_valid(_session):
		_session = parent.get_node_or_null("BrotatoOnlineSessionManager")
	if _slot_manager == null or not is_instance_valid(_slot_manager):
		_slot_manager = parent.get_node_or_null("BrotatoOnlineOnlinePlayerSlotManager")
	_resolve_steam()


func _resolve_steam() -> void:
	if _steam != null:
		return
	if Engine.has_singleton("Steam"):
		_steam = Engine.get_singleton("Steam")


func _connect_api_signal() -> void:
	if _api == null or not is_instance_valid(_api) or not _api.has_signal("mod_message_received"):
		return
	if not _api.is_connected("mod_message_received", self, "_on_mod_message_received"):
		_api.connect("mod_message_received", self, "_on_mod_message_received")


func _connect_language_signal() -> void:
	if ProgressData == null or not ProgressData.has_signal("language_changed"):
		return
	if not ProgressData.is_connected("language_changed", self, "_on_language_changed"):
		ProgressData.connect("language_changed", self, "_on_language_changed")


func _on_language_changed() -> void:
	_last_render_key = ""
	if _overlay_layer != null and is_instance_valid(_overlay_layer):
		_overlay_layer.queue_free()
	_overlay_layer = null
	_overlay_root = null
	_panel = null
	_rows_container = null
	_row_panels.clear()
	_row_profile_buttons.clear()
	if _overlay_open:
		_ensure_overlay()
		_overlay_root.show()
		_refresh_visible_rows(true)


func _txt(key: String) -> String:
	var parent = get_parent()
	if parent != null:
		var i18n = parent.get_node_or_null("BrotatoOnlineI18n")
		if i18n != null and i18n.has_method("get_text"):
			return str(i18n.get_text(key))
	return key
