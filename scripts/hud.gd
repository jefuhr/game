extends Control
## Drawing and hit testing share viewport coordinates, including after resizing.

const INK := Color(0.9, 0.96, 1.0)
const ACCENT := Color(0.34, 0.94, 0.76)
var move_finger := -1
var look_finger := -1
var jump_finger := -1
var move_origin := Vector2.ZERO
var _was_touch := false
var _was_playing := false
var master_watermark := "master / unstamped dev"
@onready var player: CharacterBody3D = get_node("../../Player")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_clear_fingers)
	if FileAccess.file_exists("res://build_info.json"):
		var metadata = JSON.parse_string(FileAccess.get_file_as_string("res://build_info.json"))
		if metadata is Dictionary and metadata.get("master_hash", "") is String:
			var revision: String = metadata.get("master_hash", "")
			if revision.length() == 40 and revision.is_valid_hex_number():
				master_watermark = "master / " + revision.left(8)


func _process(_delta: float) -> void:
	if _was_touch != Controls.touch_visible() or _was_playing != Controls.playing:
		_clear_fingers()
	_was_touch = Controls.touch_visible()
	_was_playing = Controls.playing
	queue_redraw()


func _clear_fingers() -> void:
	move_finger = -1
	look_finger = -1
	jump_finger = -1
	Controls.clear_touch()


func touch_button() -> Rect2:
	return Rect2(size.x - 208, 20, 184, 64)


func pause_button() -> Rect2:
	return Rect2(size.x - 296, 20, 76, 64)


func reset_button() -> Rect2:
	return Rect2(size.x * 0.5 - 90, size.y * 0.5 + 125, 180, 64)


func jump_center() -> Vector2:
	return Vector2(size.x - 106, size.y - 116)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			_release_finger(event.index)
			return
		if _button_press(event.position):
			get_viewport().set_input_as_handled()
			return
		if Controls.device != Controls.Device.TOUCH:
			_clear_fingers()
		Controls.use_touch()
		_was_touch = true
		if not Controls.playing:
			Controls.start(false)
			_was_playing = true
			_was_touch = true
		if event.position.distance_to(jump_center()) <= 62 and jump_finger == -1:
			jump_finger = event.index
			Controls.touch_jump = true
		elif event.position.x < size.x * 0.45 and move_finger == -1:
			move_finger = event.index
			move_origin = event.position
		elif event.position.x >= size.x * 0.45 and look_finger == -1:
			look_finger = event.index
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and Controls.playing:
		if event.index == move_finger:
			Controls.touch_move = ((event.position - move_origin) / 76.0).limit_length()
		elif event.index == look_finger:
			Controls.look_delta += event.screen_relative * Controls.touch_sensitivity
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if not _button_press(event.position):
				Controls.start(true)
			get_viewport().set_input_as_handled()


func _button_press(point: Vector2) -> bool:
	if touch_button().has_point(point):
		Controls.toggle_touch()
		_clear_fingers()
		return true
	if Controls.playing and pause_button().has_point(point):
		Controls.pause()
		_clear_fingers()
		return true
	if not Controls.playing and reset_button().has_point(point):
		Controls.reset_requested.emit()
		return true
	return false


func _release_finger(index: int) -> void:
	if index == move_finger:
		move_finger = -1
		Controls.touch_move = Vector2.ZERO
	if index == look_finger:
		look_finger = -1
	if index == jump_finger:
		jump_finger = -1
		Controls.touch_jump = false


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, size.x, 104), Color(0.025, 0.045, 0.07, 0.8))
	draw_string(font, Vector2(28, 42), "TFPP / MOVEMENT LAB", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ACCENT)
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	draw_string(font, Vector2(28, 76), "%s  /  %.1f m/s" % [
		["KEYBOARD + MOUSE", "GAMEPAD", "TOUCH"][Controls.device], speed], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
	_button(touch_button(), "TOUCH: " + ("ON" if Controls.force_touch else "AUTO"))
	if Controls.playing:
		_button(pause_button(), "II")
		var center := size * 0.5
		draw_line(center - Vector2(6, 0), center + Vector2(6, 0), INK, 2)
		draw_line(center - Vector2(0, 6), center + Vector2(0, 6), INK, 2)
		if Controls.touch_visible():
			_draw_touch()
		else:
			var hint := "WASD / MOVE     MOUSE / LOOK     SPACE / HOP     ESC / PAUSE     R / RESET"
			if Controls.device == Controls.Device.GAMEPAD:
				hint = "LEFT STICK / MOVE     RIGHT STICK / LOOK     A / HOP     START / PAUSE"
			draw_rect(Rect2(0, size.y - 50, size.x, 50), Color(0.025, 0.045, 0.07, 0.8))
			_centered(hint, size.y - 32, 16, INK)
	else:
		draw_rect(Rect2(0, 104, size.x, size.y - 104), Color(0.02, 0.04, 0.06, 0.74))
		_centered("MAKE YOUR MOVE", size.y * 0.5 - 70, 40, INK)
		_centered("Build speed. Strafe in the air. Keep your momentum.", size.y * 0.5 - 25, 20, INK)
		_centered("Click / tap to play  ·  Gamepad A to start", size.y * 0.5 + 25, 22, ACCENT)
		_centered("Hold jump to bunny hop  ·  R / Back to respawn", size.y * 0.5 + 67, 18, INK)
		_centered("Touch: left side moves, right side looks", size.y * 0.5 + 99, 18, INK)
		_button(reset_button(), "RESPAWN")
	# Draw last, including over the pause overlay; keep clear of the jump target.
	var watermark_width := font.get_string_size(master_watermark, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var watermark_position := Vector2(size.x - watermark_width - 24, size.y - 14)
	draw_rect(Rect2(watermark_position - Vector2(8, 19), Vector2(watermark_width + 16, 27)), Color(0.02, 0.04, 0.06, 0.65))
	draw_string(font, watermark_position, master_watermark, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.96, 1, 0.65))


func _draw_touch() -> void:
	var center := Vector2(132, size.y - 132) if move_finger == -1 else move_origin
	draw_circle(center, 76, Color(0.06, 0.1, 0.14, 0.45))
	draw_arc(center, 76, 0, TAU, 48, Color(0.9, 0.96, 1, 0.55), 2, true)
	draw_circle(center + Controls.touch_move * 56, 28, Color(0.34, 0.94, 0.76, 0.65))
	draw_circle(jump_center(), 62, Color(0.06, 0.1, 0.14, 0.6))
	draw_arc(jump_center(), 62, 0, TAU, 48, ACCENT, 2, true)
	draw_string(ThemeDB.fallback_font, jump_center() + Vector2(-26, 7), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.63, size.y - 42), "DRAG TO LOOK", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)


func _button(rect: Rect2, label: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.17, 0.21, 0.95)
	style.set_corner_radius_all(12)
	draw_style_box(style, rect)
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(font, rect.get_center() + Vector2(-width * 0.5, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)


func _centered(label: String, y: float, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - width) * 0.5, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
