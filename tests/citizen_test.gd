extends Node

var failures := 0


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	call_deferred("run")


func run() -> void:
	var world := preload("res://scenes/playground.tscn").instantiate()
	add_child(world)
	var citizen: CharacterBody3D = world.get_node("Citizen")
	var player: CharacterBody3D = world.get_node("Player")
	Controls.start(false)
	citizen._random.seed = 42
	await frames(30)
	check(citizen.is_on_floor(), "Citizen must stand on the floor")
	var start := citizen.position
	citizen._idle = false
	citizen._decision_time = 3.0
	await frames(90)
	check(citizen.position.distance_to(start) > 1.0, "Citizen must wander")
	Controls.pause()
	start = citizen.position
	await frames(5)
	check(citizen.position == start, "Citizen respects pause")
	Controls.start(false)
	# Force a heading into the perimeter; it must turn and stay inside the arena.
	citizen.position = Vector3(19.2, 0.05, 18)
	citizen._direction = Vector3.RIGHT
	citizen._idle = false
	citizen._decision_time = 10.0
	await frames(120)
	check(citizen.position.x < 19.4, "Wall must contain citizen")
	check(citizen.position.distance_to(Vector3(19.2, 0, 18)) > 0.5, "Citizen must escape a blocked heading")
	# A stationary citizen must physically stop the moving player.
	citizen.position = Vector3(4, 0, 14)
	citizen.velocity = Vector3.ZERO
	citizen.set_physics_process(false)
	player.respawn()
	Input.action_press("move_forward")
	await frames(90)
	Input.action_release("move_forward")
	check(player.position.z > 14.65, "Player must not pass through citizen")
	# The citizen's own swept capsule must detect solid arena props and the player.
	citizen.position = Vector3(0, 0, 12)
	check(citizen.test_move(citizen.global_transform, Vector3(0, 0, -2)), "Pillars block citizen")
	citizen.position = player.position + Vector3(0, 0, -2)
	check(citizen.test_move(citizen.global_transform, Vector3(0, 0, 2)), "Player blocks citizen")
	citizen.set_physics_process(true)
	citizen.position = Vector3(8, 0.05, -2)
	citizen._direction = Vector3.FORWARD
	citizen._idle = false
	citizen._decision_time = 10.0
	await frames(120)
	check(citizen.position.y > -0.1, "Citizen remains supported near ramp")
	print("Citizen checks: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
