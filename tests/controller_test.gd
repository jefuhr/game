extends Node
## Integration tests run actual physics and input routing without requiring a GPU.

var failures := 0
var checks := 0
var world: Node3D
var player: CharacterBody3D
var hud: Control


func _ready() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func run() -> void:
	world = preload("res://scenes/main.tscn").instantiate()
	add_child(world)
	player = world.get_node("Player")
	hud = world.get_node("CanvasLayer/HUD")
	Controls.start(false)
	await frames(20)
	check(player.is_on_floor(), "Player must land on the floor")
	check(absf(player.position.y) < 0.05, "Feet should rest on the floor")
	Input.action_press("move_forward")
	await frames(30)
	check(is_equal_approx(-player.velocity.z, player.max_speed), "Ground movement reaches configured speed")
	Input.action_press("move_right")
	await frames(30)
	check(Vector2(player.velocity.x, player.velocity.z).length() <= player.max_speed + 0.01, "Diagonal input cannot exceed walking speed")
	Input.action_release("move_forward")
	Input.action_release("move_right")
	await frames(30)
	check(Vector2(player.velocity.x, player.velocity.z).length() < 0.01, "Ground friction stops movement")
	Input.action_press("jump")
	await frames(6)
	check(player.position.y > 0.25 and player.velocity.y > 0.0, "Jump rises off the ground")
	Input.action_release("jump")
	await frames(60)
	check(player.is_on_floor(), "Jump lands again")
	# The wish-direction cap must retain velocity perpendicular to the air strafe.
	player.velocity = Vector3(0, 0, -10)
	player.accelerate(Vector3.RIGHT, 0.8, 100)
	check(is_equal_approx(player.velocity.x, 0.8) and is_equal_approx(player.velocity.z, -10), "Air strafing preserves perpendicular momentum")
	player.respawn()
	player.position = Vector3(18, 0.05, 18)
	Input.action_press("move_right")
	await frames(60)
	check(player.position.x < 19.5, "Walls block the capsule")
	Input.action_release("move_right")
	player.respawn()
	player.position = Vector3(8, 0.05, 0)
	Input.action_press("move_forward")
	await frames(90)
	check(player.position.y > 1.8, "Player walks up the ramp onto its platform")
	Input.action_release("move_forward")
	player.position.y = -20
	await frames(2)
	check(player.position.distance_to(player.spawn_position) < 0.2, "Falling below the map respawns")
	Controls.pause()
	var paused_position := player.position
	Input.action_press("move_forward")
	await frames(5)
	check(player.position == paused_position, "Paused player cannot move")
	Controls.pause()
	check(not Input.is_action_pressed("move_forward"), "Pause clears held movement")
	check(Controls.deadzone(Vector2(0.1, 0)).is_zero_approx(), "Stick drift is filtered")
	check(is_equal_approx(Controls.deadzone(Vector2.ONE).length(), 1.0), "Diagonal gamepad input is normalized")
	Controls.start(false)
	await frames(1)
	# Three independent contacts: moving, aiming, and jumping simultaneously.
	var origin := Vector2(130, hud.size.y - 150)
	touch(0, origin, true)
	drag(0, origin - Vector2(0, 76), Vector2(0, -76))
	touch(1, Vector2(hud.size.x * 0.65, hud.size.y * 0.5), true)
	drag(1, Vector2(hud.size.x * 0.65 + 20, hud.size.y * 0.5), Vector2(20, 0))
	touch(2, hud.jump_center(), true)
	check(Controls.touch_visible() and Controls.touch_move.y < -0.9, "Touch activates and moves")
	check(Controls.look_delta.x > 0 and Controls.touch_jump, "Touch look and jump coexist with movement")
	await frames(2)
	check(Controls.touch_move.y < -0.9, "Input device switch must not drop the first touch")
	touch(1, Vector2.ZERO, false)
	check(Controls.touch_jump and Controls.touch_move.y < -0.9, "Releasing look must not release other fingers")
	touch(0, Vector2.ZERO, false)
	touch(2, Vector2.ZERO, false)
	check(Controls.touch_move == Vector2.ZERO and not Controls.touch_jump, "Released touches cannot stick")
	touch(0, origin, true)
	drag(0, origin - Vector2(0, 76), Vector2(0, -76))
	Controls.pause()
	await frames(2)
	check(hud.move_finger == -1 and Controls.touch_move == Vector2.ZERO, "Focus loss/pause clears touch IDs")
	Controls._joy_connection_changed(0, true)
	check(Controls.device == Controls.Device.GAMEPAD and not Controls.touch_visible(), "Gamepad connection hides automatic touch controls")
	Controls._joy_connection_changed(0, false)
	check(Controls.touch_visible() and not Controls.playing, "Gamepad disconnect restores touch and pauses")
	check(hud.master_watermark.begins_with("master / "), "Watermark is present")
	print("Controller checks: %d passed, %d failed" % [checks - failures, failures])
	get_tree().quit(1 if failures else 0)


func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	hud._input(event)


func drag(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.screen_relative = relative
	hud._input(event)
