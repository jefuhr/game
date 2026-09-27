extends SceneTree
## Reproducible rendered views; run with a display (or xvfb-run), not --headless.

var world: Node3D
var player: CharacterBody3D
var controls: Node
var hud: Control


func _initialize() -> void:
	call_deferred("run")


func capture(label: String) -> void:
	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://build/verification/" + label + ".png"
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save " + path)
		quit(1)
	print("Screenshot: " + path)


func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/verification")
	root.size = Vector2i(1440, 900)
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	player = world.get_node("Player")
	hud = world.get_node("CanvasLayer/HUD")
	if not hud.has_method("reset_button"):
		push_error("HUD failed to load")
		quit(1)
		return
	controls = root.get_node("Controls")
	player.set_physics_process(false)
	world.set_physics_process(false)
	await capture("level-one-welcome")
	controls.start(false)
	player.camera.rotation.x = -0.17
	await capture("level-one-route")
	player.position = Vector3(38, 36, 2)
	player.look_at(Vector3(-25, 12, -23))
	player.camera.rotation = Vector3.ZERO
	hud.hide()
	await capture("level-one-bridges")
	player.position = Vector3(-9, 21, -45)
	player.look_at(Vector3(22, 36, 95))
	await capture("level-one-skyline")
	hud.show()
	player.respawn()
	player.camera.rotation.x = -0.17
	root.size = Vector2i(390, 844)
	controls.use_touch()
	await capture("level-one-mobile")
	controls.pause()
	await capture("level-one-mobile-welcome")
	root.size = Vector2i(844, 390)
	controls.start(false)
	await capture("level-one-mobile-landscape")
	root.size = Vector2i(1440, 900)
	controls.pause()
	world.completed = true
	world.checkpoint = 7
	world.elapsed = 48.3
	player.position = Vector3(0, 3.24, -60)
	await capture("level-one-complete")
	world.queue_free()
	await process_frame
	quit()
