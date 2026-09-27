extends Node3D
## Lightweight primitive geometry keeps the playground inexpensive on mobile GPUs.

const CORNFLOWER_BLUE := Color("6495ed")
const SCULPTURE_SPIN_SPEED := 0.6
const TRAMPOLINE_COLOR := Color("e05ab4")
## Group read by the player; a trampoline's local +Y face is its bouncy side.
const TRAMPOLINE_GROUP := &"trampoline"

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
	_build_trampoline_court()
	_sign("AIR STRAFE / HOP", Vector3(-9, 2.6, -20))
	_sign("RAMP / MOMENTUM", Vector3(8, 3.4, -16))
	_sign("CORNFLOWER STEPS", Vector3(-13, 2.6, 18))


func _process(delta: float) -> void:
	if _sculpture_gem:
		_sculpture_gem.rotate_y(SCULPTURE_SPIN_SPEED * delta)


## Trampolines on a floor, ceiling, wall, and slope. Each is one cuboid whose
## local +Y face bounces, so any rotation works.
func _build_trampoline_court() -> void:
	# Floor pad with a ceiling pad overhead: bounces escalate between them.
	_trampoline("TrampolineFloor", Vector3(14, 0.125, 4), Vector3(3, 0.25, 3), Vector3.ZERO)
	var frame_color := Color("7494a5")
	_box("TrampolinePost", Vector3(12.05, 2.75, 4), Vector3(0.3, 5.5, 0.3), frame_color)
	_box("TrampolinePost", Vector3(15.95, 2.75, 4), Vector3(0.3, 5.5, 0.3), frame_color)
	_box("TrampolineRoof", Vector3(14, 5.75, 4), Vector3(4.2, 0.5, 4.2), frame_color)
	_trampoline("TrampolineCeiling", Vector3(14, 5.35, 4), Vector3(3, 0.3, 3), Vector3(PI, 0, 0))
	_sign("TRAMPOLINES", Vector3(14, 5.75, 6.12))
	# Slope facing the right wall, and a pad mounted on that wall's inner face.
	_trampoline("TrampolineSlope", Vector3(15, 0.75, -4), Vector3(2.5, 0.3, 2.5), Vector3(0, 0, deg_to_rad(-35)))
	_trampoline("TrampolineWall", Vector3(19.6, 1.5, -4), Vector3(2.4, 0.3, 3), Vector3(0, 0, PI / 2))


func _trampoline(label: String, center: Vector3, dimensions: Vector3, rot: Vector3) -> Node3D:
	var pad := _box(label, center, dimensions, TRAMPOLINE_COLOR)
	pad.rotation = rot
	pad.add_to_group(TRAMPOLINE_GROUP)
	return pad


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


func _sign(label: String, center: Vector3, font_size := 64) -> void:
	var sign_label := Label3D.new()
	sign_label.text = label
	sign_label.position = center
	sign_label.font_size = font_size
	sign_label.pixel_size = 0.008
	add_child(sign_label)
