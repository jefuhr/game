extends Node
## Shared input state. Touch uses independent pointer IDs; gamepads use a radial deadzone.

signal reset_requested

enum Device { KEYBOARD, GAMEPAD, TOUCH }

const DEADZONE := 0.18
var device := Device.KEYBOARD
var touch_available := false
var force_touch := false
var playing := false
var joypad := -1
var touch_move := Vector2.ZERO
var touch_jump := false
var look_delta := Vector2.ZERO
var mouse_sensitivity := 0.0022
var touch_sensitivity := 0.004
var stick_sensitivity := 2.6
var _had_capture := false


func _ready() -> void:
	for action: String in ["move_left", "move_right", "move_forward", "move_back", "jump"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var bindings := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN], "jump": [KEY_SPACE]}
	for action: String in bindings:
		for key: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	touch_available = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		touch_available = bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0"))
	device = Device.TOUCH if touch_available else Device.KEYBOARD
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		joypad = pads[0]
		device = Device.GAMEPAD
	Input.joy_connection_changed.connect(_joy_connection_changed)
	get_window().focus_exited.connect(pause)


func touch_visible() -> bool:
	return force_touch or device == Device.TOUCH


func _process(_delta: float) -> void:
	# Escape can release browser pointer lock without a key event reaching the game.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _had_capture and not captured and device == Device.KEYBOARD:
		pause()
	_had_capture = captured


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			pause()
		elif event.physical_keycode == KEY_T:
			toggle_touch()
		elif event.physical_keycode == KEY_R:
			reset_requested.emit()
		elif event.is_action("move_left") or event.is_action("move_right") \
				or event.is_action("move_forward") or event.is_action("move_back") or event.is_action("jump"):
			_select_device(Device.KEYBOARD)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_select_device(Device.KEYBOARD)
		if playing:
			look_delta += event.screen_relative * mouse_sensitivity
	elif event is InputEventJoypadMotion:
		if event.axis <= JOY_AXIS_RIGHT_Y and absf(event.axis_value) > DEADZONE:
			joypad = event.device
			_select_device(Device.GAMEPAD)
	elif event is InputEventJoypadButton and event.pressed:
		joypad = event.device
		_select_device(Device.GAMEPAD)
		if event.button_index == JOY_BUTTON_START:
			if playing:
				pause()
			else:
				start(false)
		elif event.button_index == JOY_BUTTON_BACK:
			reset_requested.emit()
		elif event.button_index == JOY_BUTTON_A and not playing:
			start(false)


func _select_device(next: Device) -> void:
	if device == next:
		return
	device = next
	clear_touch()
	look_delta = Vector2.ZERO
	if next != Device.KEYBOARD:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_had_capture = false


func use_touch() -> void:
	touch_available = true
	_select_device(Device.TOUCH)


func toggle_touch() -> void:
	force_touch = not force_touch
	clear_touch()
	if force_touch:
		use_touch()
	else:
		device = Device.GAMEPAD if joypad >= 0 else Device.KEYBOARD
		pause()


func start(capture_mouse: bool) -> void:
	clear_touch()
	look_delta = Vector2.ZERO
	playing = true
	if capture_mouse:
		_select_device(Device.KEYBOARD)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func pause() -> void:
	playing = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for action: String in ["move_left", "move_right", "move_forward", "move_back", "jump"]:
		Input.action_release(action)
	clear_touch()
	look_delta = Vector2.ZERO
	_had_capture = false


func clear_touch() -> void:
	touch_move = Vector2.ZERO
	touch_jump = false


func movement() -> Vector2:
	if not playing:
		return Vector2.ZERO
	var result := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if device == Device.GAMEPAD and joypad >= 0:
		result += stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	if touch_visible():
		result += touch_move
	return result.limit_length()


func jumping() -> bool:
	return playing and (Input.is_action_pressed("jump") or touch_jump or
		(device == Device.GAMEPAD and joypad >= 0 and Input.is_joy_button_pressed(joypad, JOY_BUTTON_A)))


func consume_look(delta: float) -> Vector2:
	var result := look_delta
	look_delta = Vector2.ZERO
	if not playing:
		return Vector2.ZERO
	if device == Device.GAMEPAD and joypad >= 0:
		result += stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y) * stick_sensitivity * delta
	return result


func stick(x_axis: JoyAxis, y_axis: JoyAxis) -> Vector2:
	return deadzone(Vector2(Input.get_joy_axis(joypad, x_axis), Input.get_joy_axis(joypad, y_axis)))


func deadzone(value: Vector2) -> Vector2:
	var length := value.length()
	if length <= DEADZONE:
		return Vector2.ZERO
	return value / length * minf((length - DEADZONE) / (1.0 - DEADZONE), 1.0)


func _joy_connection_changed(id: int, connected: bool) -> void:
	if connected:
		joypad = id
		_select_device(Device.GAMEPAD)
	elif id == joypad:
		var pads := Input.get_connected_joypads()
		joypad = -1 if pads.is_empty() else pads[0]
		_select_device(Device.GAMEPAD if joypad >= 0 else (Device.TOUCH if touch_available else Device.KEYBOARD))
		pause()
