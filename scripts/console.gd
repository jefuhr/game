extends Control
## Source-style developer console. ` / ~ toggles it; Tab completes, Up/Down recall history.

const INK := Color(0.9, 0.96, 1.0)
const ACCENT := Color(0.34, 0.94, 0.76)
const WARN := Color(1.0, 0.62, 0.45)
## Console variable -> [player property, help text].
const PLAYER_CVARS := {
	"sv_gravity": ["gravity", "Downward acceleration in m/s²"],
	"sv_maxspeed": ["max_speed", "Ground wish speed in m/s"],
	"sv_accelerate": ["ground_acceleration", "Ground acceleration"],
	"sv_airaccelerate": ["air_acceleration", "Air strafe acceleration"],
	"sv_aircap": ["air_wish_speed_cap", "Projected air wish speed cap in m/s"],
	"sv_friction": ["friction", "Ground friction"],
	"sv_stopspeed": ["stop_speed", "Speed below which friction stops you quickly"],
	"sv_jumpspeed": ["jump_speed", "Jump launch speed in m/s"],
	"sv_autobunnyhopping": ["auto_bunny_hop", "1 = hold jump to hop, 0 = re-press each hop"],
}

var _log: RichTextLabel
var _line: LineEdit
var _commands := {}
var _defaults := {}
var _history: PackedStringArray = []
var _history_index := 0
var _resume := false
var _base_sensitivity := 0.0
## Untyped so player.gd members (camera, noclip, respawn) resolve at runtime.
@onready var player = get_node("../../Player")


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_sensitivity = Controls.mouse_sensitivity
	for verb: String in PLAYER_CVARS:
		_defaults[verb] = player.get(PLAYER_CVARS[verb][0])
	_commands = {
		"help": [_help, "List commands, or describe one: help <name>"],
		"clear": [func(_args: PackedStringArray) -> void: _log.clear(), "Clear the console"],
		"echo": [func(args: PackedStringArray) -> void: print_line(" ".join(args)), "Print text"],
		"cvarlist": [_cvarlist, "Show every movement cvar and its value"],
		"resetcvars": [_reset_cvars, "Restore every movement cvar to its default"],
		"sensitivity": [_sensitivity, "Mouse sensitivity multiplier (1 = default)"],
		"fov": [_fov, "Camera field of view in degrees"],
		"noclip": [_noclip, "Toggle flying through walls"],
		"kill": [func(_args: PackedStringArray) -> void: player.respawn(), "Respawn at the start"],
		"getpos": [_getpos, "Print your position as a setpos command"],
		"setpos": [_setpos, "Teleport: setpos <x> <y> <z>"],
		"music": [_music, "Toggle music, or music 0 / music 1"],
	}
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.06, 0.92)
	style.border_color = ACCENT
	style.border_width_bottom = 2
	style.set_content_margin_all(12)
	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.45
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.focus_mode = Control.FOCUS_NONE
	_log.add_theme_font_size_override("normal_font_size", 16)
	_log.add_theme_color_override("default_color", INK)
	column.add_child(_log)
	_line = LineEdit.new()
	_line.placeholder_text = "Type help for commands"
	_line.keep_editing_on_text_submit = true
	_line.add_theme_font_size_override("font_size", 16)
	_line.text_submitted.connect(_submit)
	column.add_child(_line)
	print_line("Console ready. Type help for commands.", ACCENT)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	# Handled here so the key never reaches the LineEdit as text.
	if event.physical_keycode == KEY_QUOTELEFT:
		if event.echo:
			pass
		elif visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif not visible:
		return
	elif event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_TAB:
		_complete()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_UP or event.physical_keycode == KEY_DOWN:
		_recall(-1 if event.physical_keycode == KEY_UP else 1)
		get_viewport().set_input_as_handled()


func open() -> void:
	if visible:
		return
	_resume = Controls.playing and Controls.device == Controls.Device.KEYBOARD
	Controls.pause()
	Controls.console_open = true
	visible = true
	_line.clear()
	_line.grab_focus()
	_line.edit()


func close() -> void:
	if not visible:
		return
	visible = false
	Controls.console_open = false
	_line.release_focus()
	if _resume:
		Controls.start(true)


func print_line(text: String, color := INK) -> void:
	_log.push_color(color)
	_log.add_text(text + "\n")
	_log.pop()


## Runs one or more commands separated by semicolons.
func run(text: String) -> void:
	for part in text.split(";", false):
		var args := part.strip_edges().split(" ", false)
		if args.is_empty():
			continue
		var verb := args[0].to_lower()
		args.remove_at(0)
		if PLAYER_CVARS.has(verb):
			_cvar(verb, args)
		elif _commands.has(verb):
			_commands[verb][0].call(args)
		else:
			print_line("Unknown command \"%s\". Type help." % verb, WARN)


func _submit(text: String) -> void:
	var command := text.strip_edges()
	_line.clear()
	if command.is_empty():
		return
	if _history.is_empty() or _history[-1] != command:
		_history.append(command)
	_history_index = _history.size()
	print_line("] " + command, ACCENT)
	run(command)


func _names() -> PackedStringArray:
	var names := PackedStringArray(PLAYER_CVARS.keys() + _commands.keys())
	names.sort()
	return names


func _complete() -> void:
	var typed := _line.text.strip_edges().to_lower()
	if typed.is_empty() or " " in typed:
		return
	var matches := PackedStringArray()
	for verb in _names():
		if verb.begins_with(typed):
			matches.append(verb)
	if matches.is_empty():
		return
	var prefix := matches[0]
	for verb in matches:
		while not verb.begins_with(prefix):
			prefix = prefix.left(-1)
	if matches.size() == 1:
		prefix += " "
	else:
		print_line("  ".join(matches))
	_line.text = prefix
	_line.caret_column = prefix.length()


func _recall(step: int) -> void:
	if _history.is_empty():
		return
	_history_index = clampi(_history_index + step, 0, _history.size())
	_line.text = "" if _history_index == _history.size() else _history[_history_index]
	_line.caret_column = _line.text.length()


func _format(value: Variant) -> String:
	if value is bool:
		return "1" if value else "0"
	return str(snappedf(value, 0.0001))


func _cvar(verb: String, args: PackedStringArray) -> void:
	var property: String = PLAYER_CVARS[verb][0]
	if args.is_empty():
		print_line("%s = %s  (default %s) - %s" % [verb, _format(player.get(property)),
			_format(_defaults[verb]), PLAYER_CVARS[verb][1]])
		return
	if not args[0].is_valid_float():
		print_line("%s expects a number." % verb, WARN)
		return
	if player.get(property) is bool:
		player.set(property, args[0].to_float() != 0.0)
	else:
		player.set(property, args[0].to_float())
	print_line("%s = %s" % [verb, _format(player.get(property))])


func _help(args: PackedStringArray) -> void:
	if not args.is_empty():
		var verb := args[0].to_lower()
		if PLAYER_CVARS.has(verb):
			print_line("%s - %s" % [verb, PLAYER_CVARS[verb][1]])
		elif _commands.has(verb):
			print_line("%s - %s" % [verb, _commands[verb][1]])
		else:
			print_line("No such command \"%s\"." % verb, WARN)
		return
	for verb: String in _commands:
		print_line("%s - %s" % [verb, _commands[verb][1]])
	print_line("Movement cvars (type one to see it, add a value to set it):", ACCENT)
	print_line("  " + "  ".join(PackedStringArray(PLAYER_CVARS.keys())))


func _cvarlist(_args: PackedStringArray) -> void:
	for verb: String in PLAYER_CVARS:
		print_line("%s = %s" % [verb, _format(player.get(PLAYER_CVARS[verb][0]))])


func _reset_cvars(_args: PackedStringArray) -> void:
	for verb: String in PLAYER_CVARS:
		player.set(PLAYER_CVARS[verb][0], _defaults[verb])
	print_line("Movement cvars reset to defaults.")


func _sensitivity(args: PackedStringArray) -> void:
	if not args.is_empty() and args[0].is_valid_float():
		Controls.mouse_sensitivity = _base_sensitivity * maxf(args[0].to_float(), 0.01)
	print_line("sensitivity = %s" % _format(Controls.mouse_sensitivity / _base_sensitivity))


func _fov(args: PackedStringArray) -> void:
	if not args.is_empty() and args[0].is_valid_float():
		player.camera.fov = clampf(args[0].to_float(), 50.0, 130.0)
	print_line("fov = %s" % _format(player.camera.fov))


func _noclip(_args: PackedStringArray) -> void:
	player.noclip = not player.noclip
	print_line("noclip " + ("ON" if player.noclip else "OFF"))


func _getpos(_args: PackedStringArray) -> void:
	var p: Vector3 = player.position
	print_line("setpos %.2f %.2f %.2f" % [p.x, p.y, p.z])


func _setpos(args: PackedStringArray) -> void:
	if args.size() < 3 or not (args[0].is_valid_float() and args[1].is_valid_float() and args[2].is_valid_float()):
		print_line("Usage: setpos <x> <y> <z>", WARN)
		return
	player.position = Vector3(args[0].to_float(), args[1].to_float(), args[2].to_float())
	player.velocity = Vector3.ZERO


func _music(args: PackedStringArray) -> void:
	if not args.is_empty() and args[0].is_valid_float():
		Music.set_muted(args[0].to_float() == 0.0)
	else:
		Music.toggle_mute()
	print_line("music " + ("OFF" if Music.muted else "ON"))
