extends Node
## Exercise the real level and capsule: jumps, safe checkpoints, water, and replay.

var failures := 0
var checks := 0
var world: Node3D
var player: CharacterBody3D


func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		push_error("Level one checks timed out")
		get_tree().quit(1)
	)
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
	Controls.start(false)
	await frames(15)
	check(player.is_on_floor(), "Start pier supports player")
	check(world.checkpoint == 0 and not world.completed, "Level starts with no ferry checkpoints")
	check(world.has_node("BrooklynBridge") and world.has_node("ManhattanBridge"), "Both bridges exist")
	check(world.has_node("ManhattanSkyline/OneWorldTradeCenter"), "Recognizable Manhattan skyline exists")
	# Flying over a roof must never save an unsafe midair checkpoint.
	player.position = world.route_points[1] + Vector3(0, 4, 0)
	player.velocity = Vector3.ZERO
	await frames(1)
	check(world.checkpoint == 0, "Flying above a ferry does not claim its checkpoint")
	player.respawn()
	await frames(15)
	# Every gap must be crossable using ordinary forward movement and one jump.
	# No bunny hop momentum, air strafing, or precise aiming is needed.
	for leg in range(world.route_points.size() - 1):
		var origin: Vector3 = world.route_points[leg]
		var destination: Vector3 = world.route_points[leg + 1]
		player.position = origin + Vector3(0, 0.05, -1.0)
		player.velocity = Vector3.ZERO
		player.rotation = Vector3.ZERO
		await frames(12)
		Input.action_press("move_forward")
		await frames(16)
		Input.action_press("jump")
		await frames(1)
		Input.action_release("jump")
		await frames(44)
		Input.action_release("move_forward")
		await frames(12)
		check(player.is_on_floor(), "Leg %d lands on a solid roof or pier" % (leg + 1))
		check(absf(player.position.z - destination.z) < 4.0, "Leg %d is reachable with a normal jump" % (leg + 1))
		if leg < world.FERRY_COUNT:
			check(world.checkpoint == leg + 1, "Landing saves ferry %d" % (leg + 1))
			var saved: Vector3 = player.spawn_position
			player.position = Vector3(25, -0.5, destination.z)
			await frames(3)
			check(player.position.distance_to(saved) < 0.3, "Water restores ferry %d checkpoint" % (leg + 1))
	check(world.completed, "Landing at DUMBO completes level one")
	var finish_time: float = world.elapsed
	await frames(5)
	check(world.elapsed == finish_time, "Completion freezes the crossing time")
	Controls.reset_requested.emit()
	await frames(3)
	check(not world.completed and world.checkpoint == 0, "Replay clears completion and checkpoint")
	check(player.spawn_position == world.route_points[0], "Replay restores the Manhattan start")
	Controls.start(false)
	await frames(10)
	Controls.pause()
	var paused_time: float = world.elapsed
	player.position = Vector3(25, -0.5, 0)
	await frames(5)
	check(world.elapsed == paused_time and player.position.y < 0, "Pause freezes timer and water recovery")
	Controls.start(false)
	await frames(3)
	check(player.position.distance_to(world.route_points[0]) < 0.3, "Resuming recovers from water")
	# Shortcuts and walking along a lower deck cannot award roof checkpoints.
	player.position = world.route_points[4]
	player.velocity = Vector3.ZERO
	await frames(10)
	check(world.checkpoint == 0, "Out-of-order landings do not skip the route")
	player.position = Vector3(7.9, 1.08, 10)
	player.velocity = Vector3.ZERO
	await frames(10)
	check(world.checkpoint == 0, "Lower ferry deck is not a roof checkpoint")
	player.position = world.route_points[1]
	player.velocity = Vector3.ZERO
	await frames(12)
	Controls.reset_requested.emit()
	await frames(3)
	check(world.checkpoint == 1 and player.position.distance_to(world.route_points[1]) < 0.3, "Manual reset keeps the current ferry checkpoint")
	# A generic play gesture (including gamepad A) restarts after completion.
	world.completed = true
	Controls.pause()
	Controls.start(false)
	await frames(3)
	check(not world.completed and world.checkpoint == 0, "Play gesture after completion starts a fresh crossing")
	var hud: Control = world.get_node("CanvasLayer/HUD")
	world.completed = true
	Controls.pause()
	Controls.use_touch()
	hud._button_press(hud.reset_button().get_center())
	await frames(3)
	check(Controls.playing and not world.completed and world.checkpoint == 0, "Touch replay button starts a fresh crossing")
	print("Level one checks: %d passed, %d failed" % [checks - failures, failures])
	world.queue_free()
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
