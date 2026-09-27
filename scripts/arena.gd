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

## Counter-Strike style surf ramp: a floating wedge whose faces are steeper than
## the player's floor angle (45 deg), so they are surfed rather than walked.
## Group read by the player for Source-style velocity clipping.
const SURF_GROUP := &"surf"
const SURF_COLOR := Color("3fc1c9")
const SURF_ANGLE_DEG := 55.0
const SURF_HALF_WIDTH := 2.5
## Height of the wedge's lower edges; players can walk underneath.
const SURF_BOTTOM := 3.0
const SURF_LENGTH := 36.5
## Wedge center on the floor plane (x, z). Runs from z = -23.5 to z = 13.
const SURF_CENTER := Vector2(-15.0, -5.25)
## Start deck at the back-left corner, reached by stairs along the back wall.
const SURF_DECK_TOP := 7.5
const SURF_STEP_COUNT := 7
const SURF_STEP_WIDTH := 1.4

## Christmas trees on open floor cells, each with chrome truck nuts dangling
## from its lowest bough on the +Z side.
const CHRISTMAS_TREE_SPOTS := [
	Vector3(-4, 0, -12),
	Vector3(-4, 0, -4),
	Vector3(8, 0, 12),
	Vector3(16, 0, 20),
	Vector3(8, 0, 24),
]
const TRUCK_NUT_SWING_SPEED := 2.2
const TRUCK_NUT_SWING_ANGLE := 0.35

var _sculpture_gem: Node3D
var _truck_nuts: Array[Node3D] = []
var _truck_nut_time := 0.0


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
	_build_surf_ramp()
	_build_christmas_trees()
	_sign("AIR STRAFE / HOP", Vector3(-9, 2.6, -20))
	_sign("RAMP / MOMENTUM", Vector3(8, 3.4, -16))
	_sign("CORNFLOWER STEPS", Vector3(-13, 2.6, 18))


func _process(delta: float) -> void:
	if _sculpture_gem:
		_sculpture_gem.rotate_y(SCULPTURE_SPIN_SPEED * delta)
	_truck_nut_time += delta
	for i in _truck_nuts.size():
		_truck_nuts[i].rotation.x = sin(_truck_nut_time * TRUCK_NUT_SWING_SPEED + i * 1.3) * TRUCK_NUT_SWING_ANGLE


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


## Surf line along the left side: stairs on the back wall climb to a start deck,
## from which players drop onto a floating two-sided wedge. Its 55 deg faces are
## too steep to stand on; hold strafe toward the face to ride it. One prism mesh
## and one convex collider keep it cheap on mobile.
func _build_surf_ramp() -> void:
	var height := SURF_HALF_WIDTH * tan(deg_to_rad(SURF_ANGLE_DEG))
	var half_h := height * 0.5
	var half_l := SURF_LENGTH * 0.5
	var body := StaticBody3D.new()
	body.name = "SurfRamp"
	body.position = Vector3(SURF_CENTER.x, SURF_BOTTOM + half_h, SURF_CENTER.y)
	body.add_to_group(SURF_GROUP)
	var prism := PrismMesh.new()
	prism.size = Vector3(SURF_HALF_WIDTH * 2.0, height, SURF_LENGTH)
	var material := StandardMaterial3D.new()
	material.albedo_color = SURF_COLOR
	material.roughness = 1.0
	prism.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = prism
	body.add_child(visual)
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array([
		Vector3(-SURF_HALF_WIDTH, -half_h, -half_l),
		Vector3(SURF_HALF_WIDTH, -half_h, -half_l),
		Vector3(0, half_h, -half_l),
		Vector3(-SURF_HALF_WIDTH, -half_h, half_l),
		Vector3(SURF_HALF_WIDTH, -half_h, half_l),
		Vector3(0, half_h, half_l),
	])
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	# Start deck in the back-left corner, a short drop above the wedge's ridge.
	var deck_back := -27.75
	var deck_front := SURF_CENTER.y - half_l
	var deck_color := SURF_COLOR.darkened(0.35)
	_box("SurfDeck", Vector3(SURF_CENTER.x, SURF_DECK_TOP - 0.25, (deck_back + deck_front) * 0.5), Vector3(7, 0.5, deck_front - deck_back), deck_color)
	# Stairs along the back wall, each rise well within a single jump.
	var deck_edge_x := SURF_CENTER.x + 3.5
	for i in SURF_STEP_COUNT:
		var top := SURF_DECK_TOP * float(i + 1) / float(SURF_STEP_COUNT + 1)
		var x := deck_edge_x + SURF_STEP_WIDTH * (SURF_STEP_COUNT - i - 0.5)
		var shade := deck_color.lightened(0.05 * float(i % 2))
		_box("SurfStep", Vector3(x, top * 0.5, -26.25), Vector3(SURF_STEP_WIDTH, top, 3.0), shade)
	_sign("SURF RAMP", Vector3(SURF_CENTER.x, SURF_DECK_TOP + 1.2, deck_front + 0.1))
	_sign("SURF STAIRS", Vector3(-4.5, 2.6, -24.5), 48)


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


## Low-poly Christmas trees: stacked cones, a star, a few baubles and swinging
## truck nuts. Meshes and materials are shared across trees; one slim cylinder
## collider per tree keeps the foliage from being walked through.
func _build_christmas_trees() -> void:
	var trunk_mat := _flat_material(Color("6b4226"))
	var needle_mat := _flat_material(Color("2f7d3a"))
	var star_mat := _flat_material(Color("ffd84a"))
	star_mat.emission_enabled = true
	star_mat.emission = Color("ffd84a")
	star_mat.emission_energy_multiplier = 0.6
	var chrome := _flat_material(Color("d8dde3"))
	chrome.metallic = 1.0
	chrome.roughness = 0.2
	var bauble_mats := [_flat_material(Color("d93a3a")), _flat_material(Color("f2f2f2")), _flat_material(Color("3a6fd9"))]
	var trunk := BoxMesh.new()
	trunk.size = Vector3(0.4, 0.8, 0.4)
	trunk.material = trunk_mat
	var tiers: Array[CylinderMesh] = []
	for radius in [1.3, 1.0, 0.7]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = radius
		cone.height = 1.2
		cone.radial_segments = 8
		cone.rings = 1
		cone.material = needle_mat
		tiers.append(cone)
	var star := BoxMesh.new()
	star.size = Vector3(0.3, 0.3, 0.3)
	star.material = star_mat
	var bauble := SphereMesh.new()
	bauble.radius = 0.08
	bauble.height = 0.16
	bauble.radial_segments = 8
	bauble.rings = 4
	var hitch := BoxMesh.new()
	hitch.size = Vector3(0.1, 0.06, 0.2)
	hitch.material = chrome
	var strap := BoxMesh.new()
	strap.size = Vector3(0.03, 0.14, 0.03)
	strap.material = chrome
	var nut := SphereMesh.new()
	nut.radius = 0.1
	nut.height = 0.22
	nut.radial_segments = 10
	nut.rings = 5
	nut.material = chrome
	var bauble_spots := [
		Vector3(0.9, 0.95, 0.4), Vector3(-0.7, 0.95, -0.6), Vector3(-0.5, 0.95, 0.8),
		Vector3(0.55, 1.75, -0.45), Vector3(-0.6, 1.75, 0.2), Vector3(0.15, 2.5, 0.45),
	]
	for base in CHRISTMAS_TREE_SPOTS:
		var tree := StaticBody3D.new()
		tree.name = "ChristmasTree"
		tree.position = base
		tree.rotation.y = randf_range(-0.4, 0.4)
		add_child(tree)
		var shape := CylinderShape3D.new()
		shape.radius = 0.45
		shape.height = 3.4
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = Vector3(0, 1.7, 0)
		tree.add_child(collider)
		_mesh_part(tree, trunk, Vector3(0, 0.4, 0))
		for i in tiers.size():
			_mesh_part(tree, tiers[i], Vector3(0, 1.3 + i * 0.75, 0))
		var topper := _mesh_part(tree, star, Vector3(0, 3.55, 0))
		topper.rotation = Vector3(deg_to_rad(45), 0, deg_to_rad(35.26))
		for i in bauble_spots.size():
			var ball := _mesh_part(tree, bauble, bauble_spots[i])
			ball.material_override = bauble_mats[i % bauble_mats.size()]
		# Truck nuts: a chrome hitch under the lowest bough, with the pair on a pivot.
		_mesh_part(tree, hitch, Vector3(0, 0.68, 1.15))
		var pivot := Node3D.new()
		pivot.name = "TruckNuts"
		pivot.position = Vector3(0, 0.65, 1.22)
		tree.add_child(pivot)
		_mesh_part(pivot, strap, Vector3(0, -0.07, 0))
		for side in [-1.0, 1.0]:
			_mesh_part(pivot, nut, Vector3(side * 0.085, -0.22, 0))
		_truck_nuts.append(pivot)


func _mesh_part(parent: Node3D, mesh: Mesh, center: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = center
	parent.add_child(instance)
	return instance


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


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
