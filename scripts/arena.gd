extends Node3D
## Lightweight primitive geometry keeps the playground inexpensive on mobile GPUs.

const CORNFLOWER_BLUE := Color("6495ed")
const SCULPTURE_SPIN_SPEED := 0.6

var _sculpture_gem: Node3D


func _ready() -> void:
	_box("Floor", Vector3(0, -0.5, 0), Vector3(40, 1, 56), Color("283e4b"))
	_box("BackWall", Vector3(0, 1.5, -28), Vector3(40, 3, 0.5), Color("416071"))
	_box("LeftWall", Vector3(-20, 1.5, 0), Vector3(0.5, 3, 56), Color("416071"))
	_box("RightWall", Vector3(20, 1.5, 0), Vector3(0.5, 3, 56), Color("416071"))
	_box("FrontWall", Vector3(0, 1.5, 28), Vector3(40, 3, 0.5), Color("416071"))
	for x in range(-18, 20, 4):
		_box("Grid", Vector3(x, 0.006, 0), Vector3(0.025, 0.01, 55), Color("3b5663"), false)
	for z in range(-26, 28, 4):
		_box("Grid", Vector3(0, 0.007, z), Vector3(39, 0.01, 0.025), Color("3b5663"), false)
	for i in range(5):
		_box("JumpBlock", Vector3(-9, 0.2 + i * 0.1, 5 - i * 4), Vector3(3, 0.4 + i * 0.2, 2.5), Color("5ae3bc"))
	_box("Platform", Vector3(8, 1, -12), Vector3(6, 2, 6), Color("e9ac65"))
	var ramp := _box("Ramp", Vector3(8, 0.9, -6), Vector3(6, 0.3, 7), Color("d39451"))
	ramp.rotation.x = deg_to_rad(16)
	for z in [-18, -4, 10]:
		_box("Pillar", Vector3(0, 1.5, z), Vector3(1.4, 3, 1.4), Color("7494a5"))
	# Cornflower blue steps in the open front-left corner.
	_box("CornflowerStepLow", Vector3(-13, 0.2, 18), Vector3(5, 0.4, 5), CORNFLOWER_BLUE)
	_box("CornflowerStepHigh", Vector3(-13, 0.4, 18), Vector3(2.5, 0.8, 2.5), CORNFLOWER_BLUE.lightened(0.15))
	_build_cornflower_sculpture(Vector3(14, 0, 14))
	_build_relaxation_station()
	_sign("AIR STRAFE / HOP", Vector3(-9, 2.6, -20))
	_sign("RAMP / MOMENTUM", Vector3(8, 3.4, -16))
	_sign("CORNFLOWER STEPS", Vector3(-13, 2.6, 18))


func _process(delta: float) -> void:
	if _sculpture_gem:
		_sculpture_gem.rotate_y(SCULPTURE_SPIN_SPEED * delta)


## "Cornflower Twist": a twisting stack of cubes crowned by a spinning,
## corner-balanced gem. Five boxes total to stay cheap on mobile.
func _build_cornflower_sculpture(base: Vector3) -> void:
	_box("SculpturePedestal", base + Vector3(0, 0.3, 0), Vector3(3, 0.6, 3), CORNFLOWER_BLUE.darkened(0.35))
	var tiers := [
		[1.8, 1.5, 15.0, 0.0],
		[1.3, 3.05, 40.0, 0.1],
		[0.9, 4.15, 65.0, 0.2],
	]
	for tier in tiers:
		var size: float = tier[0]
		var cube := _box("SculptureTier", base + Vector3(0, tier[1], 0), Vector3(size, size, size), CORNFLOWER_BLUE.lightened(tier[3]))
		cube.rotation.y = deg_to_rad(tier[2])
	# Gem: a cube balanced on its corner; its pivot spins, the mesh stays tilted.
	_sculpture_gem = Node3D.new()
	_sculpture_gem.name = "SculptureGemPivot"
	_sculpture_gem.position = base + Vector3(0, 5.35, 0)
	add_child(_sculpture_gem)
	var gem := _box("SculptureGem", Vector3.ZERO, Vector3(0.7, 0.7, 0.7), CORNFLOWER_BLUE.lightened(0.45), false)
	remove_child(gem)
	_sculpture_gem.add_child(gem)
	gem.rotation = Vector3(deg_to_rad(45), 0, deg_to_rad(35.26))
	_sign("CORNFLOWER TWIST", base + Vector3(0, 0.3, 1.52), 40)


## "Relaxation Station #1102": a cozy booth in the front-right corner. Its
## signage confidently implies 1101 sibling stations elsewhere. There are none.
func _build_relaxation_station() -> void:
	var wall := Color("8a6f5a")
	var trim := Color("5e4a3c")
	# Walls: the arena's front wall (z = 28) closes the back of the room.
	_box("StationWallLeft", Vector3(9, 1.5, 24.375), Vector3(0.3, 3, 6.75), wall)
	_box("StationWallRight", Vector3(17, 1.5, 24.375), Vector3(0.3, 3, 6.75), wall)
	_box("StationFrontLeft", Vector3(10.5, 1.5, 21), Vector3(3, 3, 0.3), wall)
	_box("StationFrontRight", Vector3(15.5, 1.5, 21), Vector3(3, 3, 0.3), wall)
	_box("StationLintel", Vector3(13, 2.75, 21), Vector3(2, 0.5, 0.3), trim)
	# Interior.
	_box("StationCarpet", Vector3(13, 0.012, 24.4), Vector3(7.6, 0.01, 6.4), Color("7a2f3b"), false)
	_box("StationArmchairSeat", Vector3(13, 0.25, 26.6), Vector3(1.6, 0.5, 1.2), Color("b5654a"))
	_box("StationArmchairBack", Vector3(13, 0.85, 27.35), Vector3(1.6, 1.2, 0.3), Color("a4583f"))
	for side in [-1.0, 1.0]:
		_box("StationArmchairArm", Vector3(13 + side * 0.95, 0.4, 26.7), Vector3(0.3, 0.8, 1.2), Color("a4583f"))
	_box("StationSideTable", Vector3(15.3, 0.35, 26.8), Vector3(0.8, 0.7, 0.8), trim)
	_box("StationMug", Vector3(15.2, 0.8, 26.7), Vector3(0.15, 0.2, 0.15), Color("e8e2d0"), false)
	_box("StationLampPole", Vector3(10.2, 0.8, 27.1), Vector3(0.08, 1.6, 0.08), Color("3a3a3a"), false)
	_box("StationLampShade", Vector3(10.2, 1.7, 27.1), Vector3(0.6, 0.4, 0.6), Color("ffe7a8"), false)
	# Signage. Label3D faces +Z by default, so rotate to face each viewer.
	var marquee := _sign("RELAXATION STATION #1102", Vector3(13, 3.45, 20.8), 56)
	marquee.rotation.y = PI
	var serving := _sign("NOW SERVING: #1102", Vector3(15.5, 2.3, 20.8), 28)
	serving.rotation.y = PI
	var previous := _sign("<- STATION #1101\nNEXT DOOR", Vector3(10.5, 2.1, 20.8), 28)
	previous.rotation.y = PI
	var here := _sign("STATION #1102\nYOU ARE HERE", Vector3(13, 2.3, 27.7), 40)
	here.rotation.y = PI
	var rules := _sign("Please report issues with this station\nto Station #1101.", Vector3(13, 1.65, 27.7), 20)
	rules.rotation.y = PI
	var directory := _sign("DIRECTORY\n<- STATIONS #1 - #1101\n(please use other entrance)", Vector3(9.2, 1.8, 24.4), 30)
	directory.rotation.y = PI / 2
	var next := _sign("STATION #1103 ->\nOPENING SOON", Vector3(16.8, 1.8, 24.4), 30)
	next.rotation.y = -PI / 2
	var mat := _sign("#1102", Vector3(13, 0.03, 23.2), 48)
	mat.rotation.x = -PI / 2


func _box(label: String, center: Vector3, dimensions: Vector3, color: Color, solid := true) -> Node3D:
	var body := StaticBody3D.new() if solid else Node3D.new()
	body.name = label
	body.position = center
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	box.material = material
	mesh.mesh = box
	body.add_child(mesh)
	if solid:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collider.shape = shape
		body.add_child(collider)
	add_child(body)
	return body


func _sign(label: String, center: Vector3, font_size := 64) -> Label3D:
	var sign_label := Label3D.new()
	sign_label.text = label
	sign_label.position = center
	sign_label.font_size = font_size
	sign_label.pixel_size = 0.008
	add_child(sign_label)
	return sign_label
