extends Control
## Drawing and hit testing share viewport coordinates, including after resizing.

const INK := Color(0.9, 0.96, 1.0)
const ACCENT := Color(0.34, 0.94, 0.76)
var ui_scale := 1.0
var ui_size := Vector2.ZERO
var safe_bounds := Rect2()
var _browser: JavaScriptObject
var _safe_area_refresh := 0.0
var move_finger := -1
var look_finger := -1
var jump_finger := -1
var move_origin := Vector2.ZERO
var look_position := Vector2.ZERO
var _was_touch := false
var _was_playing := false
var master_watermark := "master / unstamped dev"
@onready var hud_font: Font = ThemeDB.fallback_font.duplicate()
@onready var player: CharacterBody3D = get_node("../../Player")
@onready var level: Node3D = get_node("../..")
@onready var is_crossing: bool = level.has_method("time_text")


func _ready() -> void:
	if is_crossing and hud_font is FontFile:
		# Manual canvas scaling otherwise enlarges low-resolution glyph caches.
		hud_font.oversampling = 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if OS.has_feature("web"):
		_browser = JavaScriptBridge.get_interface("window")
	resized.connect(_resize_layout)
	_resize_layout()
	if FileAccess.file_exists("res://build_info.json"):
		var metadata = JSON.parse_string(FileAccess.get_file_as_string("res://build_info.json"))
		if metadata is Dictionary and metadata.get("master_hash", "") is String:
			var revision: String = metadata.get("master_hash", "")
			if revision.length() == 40 and revision.is_valid_hex_number():
				master_watermark = "master / " + revision.left(8)
			var preview: String = metadata.get("preview_hash", "")
			if preview.length() == 40 and preview.is_valid_hex_number():
				master_watermark = "PR #%d / %s · %s" % [int(metadata.get("pr_number", 0)), preview.left(8), master_watermark]


func _process(delta: float) -> void:
	# iOS can update CSS safe areas after its resize event, especially on rotation.
	_safe_area_refresh -= delta
	if _safe_area_refresh <= 0.0:
		_update_safe_area()
		_safe_area_refresh = 0.5
	if _was_touch != Controls.touch_visible() or _was_playing != Controls.playing:
		_clear_fingers()
	_was_touch = Controls.touch_visible()
	_was_playing = Controls.playing
	queue_redraw()


func _resize_layout() -> void:
	# Portrait should retain thumb-sized controls instead of shrinking a desktop HUD.
	ui_scale = clampf(size.y / maxf(size.x, 1.0), 1.0, 2.0)
	if is_crossing and _browser != null:
		# The Web canvas uses device pixels; targets must be sized in CSS pixels.
		var area = JSON.parse_string(_browser.getGameSafeArea())
		if area is Dictionary and float(area.get("width", 0)) > 0:
			ui_scale = maxf(1.0, size.x / float(area["width"]))
	elif is_crossing and DisplayServer.get_name() != "headless":
		ui_scale = maxf(1.0, 1.0 / maxf(get_viewport().get_screen_transform().get_scale().x, 0.01))
	ui_size = size / ui_scale
	_update_safe_area()
	_clear_fingers()


func _update_safe_area() -> void:
	safe_bounds = Rect2(Vector2.ZERO, ui_size)
	if _browser == null:
		return
	var area = JSON.parse_string(_browser.getGameSafeArea())
	if not area is Dictionary:
		return
	var css_size := Vector2(float(area.get("width", 0)), float(area.get("height", 0)))
	if css_size.x <= 0.0 or css_size.y <= 0.0:
		return
	var css_to_ui := ui_size / css_size
	var start := Vector2(float(area.get("left", 0)), float(area.get("top", 0))) * css_to_ui
	var end := Vector2(float(area.get("right", 0)), float(area.get("bottom", 0))) * css_to_ui
	safe_bounds = Rect2(start, ui_size - start - end)


func _clear_fingers() -> void:
	move_finger = -1
	look_finger = -1
	jump_finger = -1
	Controls.clear_touch()


func touch_button() -> Rect2:
	if is_crossing:
		return Rect2(safe_bounds.end.x - 134, safe_bounds.position.y + 16, 112, 44)
	return Rect2(safe_bounds.end.x - 208, safe_bounds.position.y + 20, 184, 64)


func pause_button() -> Rect2:
	if is_crossing:
		return Rect2(safe_bounds.end.x - 190, safe_bounds.position.y + 16, 44, 44)
	return Rect2(safe_bounds.end.x - 296, safe_bounds.position.y + 20, 76, 64)


## Sits just below the header so it never collides with the title in portrait.
func music_button() -> Rect2:
	if is_crossing:
		return Rect2(safe_bounds.end.x - 134, safe_bounds.position.y + 66, 112, 44)
	return Rect2(safe_bounds.end.x - 208, safe_bounds.position.y + 116, 184, 52)


func reset_button() -> Rect2:
	if is_crossing and ui_size.y < 540:
		return Rect2(ui_size.x * 0.5 - 90, safe_bounds.end.y - 80, 180, 64)
	return Rect2(ui_size.x * 0.5 - 90, ui_size.y * 0.5 + 125, 180, 64)


func jump_center() -> Vector2:
	return safe_bounds.end - Vector2(106, 116)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var point: Vector2 = event.position / ui_scale
		if not event.pressed or event.canceled:
			_release_finger(event.index)
			return
		if _button_press(point):
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
		if point.distance_to(jump_center()) <= 62 and jump_finger == -1:
			jump_finger = event.index
			Controls.touch_jump = true
		elif point.x < ui_size.x * 0.45 and move_finger == -1:
			move_finger = event.index
			move_origin = point
		elif point.x >= ui_size.x * 0.45 and look_finger == -1:
			look_finger = event.index
			look_position = event.position
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and Controls.playing:
		if event.index == move_finger:
			Controls.touch_move = ((event.position / ui_scale - move_origin) / 76.0).limit_length()
		elif event.index == look_finger:
			# Web multitouch can report another finger's position in the first relative
			# delta. Track this finger ourselves, then convert to unscaled screen pixels.
			var delta: Vector2 = event.position - look_position
			look_position = event.position
			var screen_delta := get_viewport().get_screen_transform().basis_xform(delta)
			Controls.look_delta += screen_delta * Controls.touch_sensitivity
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if not _button_press(event.position / ui_scale):
				Controls.start(true)
			get_viewport().set_input_as_handled()


func _button_press(point: Vector2) -> bool:
	if touch_button().has_point(point):
		Controls.toggle_touch()
		_clear_fingers()
		return true
	if music_button().has_point(point):
		Music.toggle_mute()
		return true
	if Controls.playing and pause_button().has_point(point):
		Controls.pause()
		_clear_fingers()
		return true
	if not Controls.playing and reset_button().has_point(point):
		var replay: bool = is_crossing and level.completed
		Controls.reset_requested.emit()
		if replay:
			Controls.start(Controls.device == Controls.Device.KEYBOARD)
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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ui_scale)
	if is_crossing:
		_draw_crossing()
		return
	var font := hud_font
	var header_bottom := safe_bounds.position.y + 104
	draw_rect(Rect2(0, 0, ui_size.x, header_bottom), Color(0.025, 0.045, 0.07, 0.8))
	draw_string(font, safe_bounds.position + Vector2(28, 42), ("TFPP / MOVE LAB" if safe_bounds.size.x < 720 else "TFPP / MOVEMENT LAB"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ACCENT)
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	draw_string(font, safe_bounds.position + Vector2(28, 76), "%s  /  %.1f m/s" % [
		["KEYBOARD + MOUSE", "GAMEPAD", "TOUCH"][Controls.device], speed], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)
	_button(touch_button(), "TOUCH: " + ("ON" if Controls.force_touch else "AUTO"))
	if Controls.playing:
		_button(pause_button(), "II")
		var center := ui_size * 0.5
		draw_line(center - Vector2(6, 0), center + Vector2(6, 0), INK, 2)
		draw_line(center - Vector2(0, 6), center + Vector2(0, 6), INK, 2)
		if Controls.touch_visible():
			_draw_touch()
		else:
			var hint := "WASD / MOVE     MOUSE / LOOK     SPACE / HOP     ESC / PAUSE     R / RESET     M / MUSIC"
			if Controls.device == Controls.Device.GAMEPAD:
				hint = "LEFT STICK / MOVE     RIGHT STICK / LOOK     A / HOP     START / PAUSE"
			draw_rect(Rect2(0, safe_bounds.end.y - 50, ui_size.x, ui_size.y - safe_bounds.end.y + 50), Color(0.025, 0.045, 0.07, 0.8))
			_centered(hint, safe_bounds.end.y - 32, 16, INK)
	else:
		draw_rect(Rect2(0, header_bottom, ui_size.x, ui_size.y - header_bottom), Color(0.02, 0.04, 0.06, 0.74))
		_centered("MAKE YOUR MOVE", ui_size.y * 0.5 - 70, 40, INK)
		_centered("Build speed. Strafe in the air. Keep your momentum.", ui_size.y * 0.5 - 25, 20, INK)
		_centered("Click / tap to play  ·  Gamepad A to start", ui_size.y * 0.5 + 25, 22, ACCENT)
		_centered("Hold jump to bunny hop  ·  R / Back to respawn", ui_size.y * 0.5 + 67, 18, INK)
		_centered("Touch: left side moves, right side looks", ui_size.y * 0.5 + 99, 18, INK)
		_button(reset_button(), "RESPAWN")
	# Drawn after the pause overlay so it stays bright in both states.
	_button(music_button(), "MUSIC: " + ("OFF" if Music.muted else "ON"))
	# Draw last, including over the pause overlay; keep clear of the jump target.
	var watermark_width := font.get_string_size(master_watermark, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var watermark_position := safe_bounds.end - Vector2(watermark_width + 24, 14)
	draw_rect(Rect2(watermark_position - Vector2(8, 19), Vector2(watermark_width + 16, 27)), Color(0.02, 0.04, 0.06, 0.65))
	draw_string(font, watermark_position, master_watermark, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.96, 1, 0.65))


func _draw_touch() -> void:
	var center := Vector2(safe_bounds.position.x + 132, safe_bounds.end.y - 132) if move_finger == -1 else move_origin
	draw_circle(center, 76, Color(0.06, 0.1, 0.14, 0.45))
	draw_arc(center, 76, 0, TAU, 48, Color(0.9, 0.96, 1, 0.55), 2, true)
	draw_circle(center + Controls.touch_move * 56, 28, Color(0.34, 0.94, 0.76, 0.65))
	draw_circle(jump_center(), 62, Color(0.06, 0.1, 0.14, 0.6))
	draw_arc(jump_center(), 62, 0, TAU, 48, ACCENT, 2, true)
	draw_string(hud_font, jump_center() + Vector2(-26, 7), "JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
	draw_string(hud_font, Vector2(safe_bounds.position.x + safe_bounds.size.x * 0.63, safe_bounds.end.y - 42), "DRAG TO LOOK", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)


func _button(rect: Rect2, label: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.17, 0.21, 0.95)
	style.set_corner_radius_all(12)
	draw_style_box(style, rect)
	var font := hud_font
	var font_size := 14 if rect.size.x < 150 else 18
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, rect.get_center() + Vector2(-width * 0.5, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)


func _centered(label: String, y: float, font_size: int, color: Color) -> void:
	var font := hud_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((ui_size.x - width) * 0.5, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _crossing_line(words: String, y: float, font_size: int, color: Color) -> void:
	var width := hud_font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var fitted := clampi(int(font_size * (safe_bounds.size.x - 40) / maxf(width, 1)), 1, font_size)
	_centered(words, y, fitted, color)


func _draw_crossing() -> void:
	var font := hud_font
	var gold := Color("ffd079")
	var left := safe_bounds.position + Vector2(22, 36)
	draw_rect(Rect2(0, 0, ui_size.x, safe_bounds.position.y + 116), Color(0.04, 0.12, 0.16, 0.9))
	draw_string(font, left, "01 / EAST RIVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, gold)
	draw_string(font, left + Vector2(0, 24), "MANHATTAN / DUMBO", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
	var status := "FERRY %d / 7   ·   %s" % [level.checkpoint, level.time_text()]
	draw_string(font, left + Vector2(0, 53), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
	for i in range(7):
		draw_circle(left + Vector2(5 + i * 21, 67), 3.5, ACCENT if i < level.checkpoint else Color(0.5, 0.65, 0.7, 0.6))
	_button(touch_button(), "TOUCH: " + ("ON" if Controls.force_touch else "AUTO"))
	if Controls.playing:
		_button(pause_button(), "II")
		var center := ui_size * 0.5
		draw_circle(center, 2.5, INK)
		if Controls.touch_visible():
			_draw_touch()
		else:
			var hint := "WASD move   ·   SPACE jump   ·   R checkpoint   ·   ESC pause"
			if Controls.device == Controls.Device.GAMEPAD:
				hint = "LEFT STICK move   ·   A jump   ·   BACK checkpoint   ·   START pause"
			draw_rect(Rect2(0, safe_bounds.end.y - 59, ui_size.x, 59), Color(0.04, 0.12, 0.16, 0.85))
			_crossing_line(hint, safe_bounds.end.y - 34, 16, INK)
		if level.notice_time > 0:
			draw_rect(Rect2(0, safe_bounds.position.y + 116, ui_size.x, 36), Color(0.04, 0.12, 0.16, 0.7))
			_crossing_line(level.notice, safe_bounds.position.y + 140, 17, gold)
	else:
		draw_rect(Rect2(0, safe_bounds.position.y + 116, ui_size.x, ui_size.y), Color(0.025, 0.08, 0.11, 0.68))
		var compact := ui_size.y < 540
		var cy := ui_size.y * 0.5 if not compact else safe_bounds.position.y + 149 + 76
		var spacing := 0.72 if compact else 1.0
		var title_y := cy - 76
		if level.completed:
			_crossing_line("HELLO, BROOKLYN.", title_y, 28 if compact else 40, gold)
			_crossing_line("Level one complete", title_y + 49 * spacing, 22, INK)
			_crossing_line("7 ferries  ·  " + level.time_text() + "  ·  %d splashes" % level.falls, title_y + 90 * spacing, 20, INK)
			_crossing_line("You made it from Manhattan to DUMBO.", title_y + 130 * spacing, 18, INK)
			_crossing_line("Click / tap or press A to cross again", title_y + 168 * spacing, 18, gold)
			_button(reset_button(), "PLAY AGAIN")
		else:
			_crossing_line("THE EAST RIVER HOP", title_y, 28 if compact else 38, INK)
			_crossing_line("Lower Manhattan to DUMBO", title_y + 43 * spacing, 23, gold)
			_crossing_line("Seven ferries. Short jumps. Take your time.", title_y + 82 * spacing, 18, INK)
			_crossing_line("Jump at the gold edges. Every ferry saves your spot.", title_y + 112 * spacing, 17, INK)
			_crossing_line("Click / tap to play  ·  Gamepad A to start", title_y + 152 * spacing, 20, gold)
			_crossing_line("Touch: drag left to move, right to look, JUMP to hop", title_y + 180 * spacing, 15, INK)
			_button(reset_button(), "CHECKPOINT")
	_button(music_button(), "MUSIC: " + ("OFF" if Music.muted else "ON"))
	var watermark_width := font.get_string_size(master_watermark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var watermark_position := safe_bounds.end - Vector2(watermark_width + 16, 10)
	draw_rect(Rect2(watermark_position - Vector2(5, 14), Vector2(watermark_width + 10, 20)), Color(0.02, 0.04, 0.06, 0.6))
	draw_string(font, watermark_position, master_watermark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.96, 1, 0.65))
