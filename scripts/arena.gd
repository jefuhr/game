extends Node3D
## Lightweight primitive geometry keeps the playground inexpensive on mobile GPUs.

const CORNFLOWER_BLUE := Color("6495ed")
const SCULPTURE_SPIN_SPEED := 0.6
const TRAMPOLINE_COLOR := Color("e05ab4")
## Group read by the player; a trampoline's local +Y face is its bouncy side.
const TRAMPOLINE_GROUP := &"trampoline"
## The 40 x 56 m floor is 10 x 14 cells of 4 x 4 m. The map covers the 9 x 13
## interior cells between the grid lines; '#' marks a flush trampoline tile.
## 56 of the 140 floor cells (40% of the floor area) are trampolines. Rows run
## from the back wall (z = -24) to the front (z = 24); columns x = -16 .. 16.
const BOUNCE_FLOOR_MAP := [
	"####.####",
	"####.####",
	"####....#",
	"#...#...#",
	"#...#...#",
	"#........",
	"#...#....",
	"#...###..",
	"###....##",
	"###......",
	"..###....",
	"..###..#.",
	"#####..##",
]
const BOUNCE_TILE_SIZE := 4.0
## Tiles sit just above the floor so landings always hit the bouncy collider.
const BOUNCE_TILE_TOP := 0.03
const BOUNCE_TILE_THICKNESS := 0.1

var _sculpture_gem: Node3D


func _ready() -> void:
	_box("Floor", Vector3(0, -0.5, 0), Vector3(40, 1, 56), Color("283e4b"))
	_box("BackWall", Vector3(0, 1.5, -28), Vector3(40, 3, 0.5), Color("416071"))
	_box("LeftWall", Vector3(-20, 1.5, 0), Vector3(0.5, 3, 56), Color("416071"))
	_box("RightWall", Vector3(20, 1.5, 0), Vector3(0.5, 3, 56), Color("416071"))
	_box("FrontWall", Vector3(0, 1.5, 28), Vector3(40, 3, 0.5), Color("416071"))
	_build_bounce_guards()
	for x in range(-18, 20, 4):
		_box("Grid", Vector3(x, 0.006, 0), Vector3(0.025, 0.01, 55), Color("3b5663"), false)
	for z in range(-26, 28, 4):
		_box("Grid", Vector3(0, 0.007, z), Vector3(39, 0.01, 0.025), Color("3b5663"), false)
	_build_bounce_floor()
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


## Flush trampoline tiles covering 40% of the floor. One static body (in the
## trampoline group, +Y up) holds every tile collider; one MultiMesh draws them
## all in a single call to stay cheap on mobile.
func _build_bounce_floor() -> void:
	var body := StaticBody3D.new()
	body.name = "BounceFloor"
	body.add_to_group(TRAMPOLINE_GROUP)
	add_child(body)
	var tile_size := Vector3(BOUNCE_TILE_SIZE, BOUNCE_TILE_THICKNESS, BOUNCE_TILE_SIZE)
	var shape := BoxShape3D.new()
	shape.size = tile_size
	var centers: Array[Vector3] = []
	var colors: Array[Color] = []
	for row in BOUNCE_FLOOR_MAP.size():
		var line: String = BOUNCE_FLOOR_MAP[row]
		for column in line.length():
			if line[column] != "#":
				continue
			centers.append(Vector3(-16.0 + column * BOUNCE_TILE_SIZE, BOUNCE_TILE_TOP - BOUNCE_TILE_THICKNESS * 0.5, -24.0 + row * BOUNCE_TILE_SIZE))
			colors.append(TRAMPOLINE_COLOR if (row + column) % 2 == 0 else TRAMPOLINE_COLOR.darkened(0.25))
	var mesh := BoxMesh.new()
	mesh.size = tile_size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = centers.size()
	for i in centers.size():
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, centers[i]))
		multimesh.set_instance_color(i, colors[i])
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = centers[i]
		body.add_child(collider)
	var visual := MultiMeshInstance3D.new()
	visual.name = "BounceFloorTiles"
	visual.multimesh = multimesh
	body.add_child(visual)


## Invisible colliders stacked on the perimeter walls so big bounces cannot
## carry anyone out of the arena. Maximum launch (24 m/s) peaks near 14.4 m.
func _build_bounce_guards() -> void:
	var guard := StaticBody3D.new()
	guard.name = "BounceGuard"
	add_child(guard)
	var bottom := 3.0
	var height := 27.0
	var y := bottom + height * 0.5
	var walls := [
		[Vector3(0, y, -28), Vector3(40, height, 0.5)],
		[Vector3(0, y, 28), Vector3(40, height, 0.5)],
		[Vector3(-20, y, 0), Vector3(0.5, height, 56)],
		[Vector3(20, y, 0), Vector3(0.5, height, 56)],
	]
	for wall in walls:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = wall[1]
		collider.shape = shape
		collider.position = wall[0]
		guard.add_child(collider)


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
