extends Node3D
## A compressed East River crossing. +X points downriver, -Z toward Brooklyn.
## Roofs stay still: scenery supplies motion without moving a beginner's landing.

const FERRY_COUNT := 7
const DECK_HEIGHT := 3.2
const WATER_RESET_HEIGHT := 0.35
const NAVY := Color("173a51")
const WHITE := Color("f3eee0")
const BLUE := Color("299ac1")
const GOLD := Color("ffd079")
const MINT := Color("9bf2ca")

var route_points: Array[Vector3] = []
var checkpoint := 0
var completed := false
var elapsed := 0.0
var falls := 0
var notice := "Follow the gold arrows to Brooklyn"
var notice_time := 6.0
var _materials: Dictionary = {}
var _checkpoint_lights: Array[MeshInstance3D] = []
var _window_transforms: Array[Transform3D] = []
var _water: MeshInstance3D
@onready var player: CharacterBody3D = $Player


func _ready() -> void:
	route_points.append(Vector3(0, DECK_HEIGHT + 0.04, 21))
	for i in FERRY_COUNT:
		var offsets := [0.0, 0.8, -0.6, 0.5, -0.8, 0.0, 0.4]
		route_points.append(Vector3(offsets[i], DECK_HEIGHT + 0.04, 10 - i * 10))
	route_points.append(Vector3(0, DECK_HEIGHT + 0.04, -61))
	_build_river()
	_build_shores()
	for i in FERRY_COUNT:
		_build_ferry(i, route_points[i + 1])
	_build_bridge("BrooklynBridge", -35, false)
	_build_bridge("ManhattanBridge", -94, true)
	_build_manhattan()
	_build_brooklyn()
	_build_windows()
	_build_route()
	_batch_details()
	player.spawn_position = route_points[0]
	player.respawn()
	Controls.reset_requested.connect(_on_reset)


func _physics_process(delta: float) -> void:
	if not Controls.playing:
		return
	if completed:
		restart()
		return
	elapsed += delta
	notice_time = maxf(notice_time - delta, 0.0)
	if player.position.y < WATER_RESET_HEIGHT:
		falls += 1
		player.respawn()
		notice = "No worries. Back on your last safe landing."
		notice_time = 3.0
		return
	# Check real grounded position, not an Area entered while flying overhead.
	if not player.is_on_floor() or absf(player.position.y - DECK_HEIGHT) > 0.15:
		return
	var next := checkpoint + 1
	if next <= FERRY_COUNT:
		var target: Vector3 = route_points[next]
		if absf(player.position.x - target.x) < 5.8 and absf(player.position.z - target.z) < 4.05:
			checkpoint = next
			player.spawn_position = target
			_checkpoint_lights[next - 1].material_override = _material(MINT, true)
			notice = "Ferry %d / %d  ·  Checkpoint saved" % [checkpoint, FERRY_COUNT]
			notice_time = 2.5
	elif absf(player.position.x) < 8.0 and player.position.z < -56.0:
		completed = true
		Controls.pause()


func _on_reset() -> void:
	if completed:
		restart()


func restart() -> void:
	checkpoint = 0
	completed = false
	elapsed = 0.0
	falls = 0
	notice = "Follow the gold arrows to Brooklyn"
	notice_time = 6.0
	for light in _checkpoint_lights:
		light.material_override = _material(GOLD, true)
	player.spawn_position = route_points[0]
	player.respawn()


func time_text() -> String:
	return "%d:%04.1f" % [int(elapsed) / 60, fmod(elapsed, 60.0)]


func _material(color: Color, luminous := false) -> StandardMaterial3D:
	var key := str(color) + str(luminous)
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.8
		if luminous:
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[key] = mat
	return _materials[key]


func _box(parent: Node3D, label: String, center: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.material_override = _material(color)
	visual.position = center
	parent.add_child(visual)
	if solid:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
		visual.add_child(body)
	return visual


func _beam(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var beam := _box(parent, "Beam", (a + b) * 0.5, Vector3(width, a.distance_to(b), width), color)
	var direction := (b - a).normalized()
	beam.quaternion = Quaternion(Vector3.UP, direction)


func _label(parent: Node3D, words: String, point: Vector3, size := 50, color := WHITE) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.position = point
	label.font_size = size
	label.pixel_size = 0.012
	label.modulate = color
	label.outline_size = 5
	label.outline_modulate = Color("173a51")
	parent.add_child(label)
	return label


func _build_ferry(index: int, point: Vector3) -> void:
	var ferry := Node3D.new()
	ferry.name = "Ferry%d" % (index + 1)
	ferry.position = Vector3(point.x, 0, point.z)
	add_child(ferry)
	# Twin dark hulls, white main deck, wraparound blue glazing, and an open roof.
	for z in [-2.8, 2.8]:
		_box(ferry, "CatamaranHull", Vector3(0, 0.25, z), Vector3(16, 1.0, 1.7), NAVY)
		var bow := PrismMesh.new()
		bow.size = Vector3(1.7, 2.0, 1.0)
		var tip := MeshInstance3D.new()
		tip.mesh = bow
		tip.material_override = _material(NAVY)
		tip.rotation = Vector3(PI / 2, 0, -PI / 2)
		tip.position = Vector3(8.7, 0.25, z)
		ferry.add_child(tip)
	_box(ferry, "MainDeck", Vector3(0, 0.9, 0), Vector3(17, 0.35, 7.8), WHITE, true)
	_box(ferry, "BlueStripe", Vector3(0, 1.17, 0), Vector3(15.9, 0.25, 7.85), BLUE)
	_box(ferry, "Cabin", Vector3(0, 2.05, 0), Vector3(11.8, 1.8, 7.5), WHITE, true)
	_box(ferry, "Windows", Vector3(0, 2.15, 0), Vector3(11.9, 0.85, 7.58), NAVY)
	for x in range(-5, 6, 2):
		for z in [-3.81, 3.81]:
			_box(ferry, "WindowDivider", Vector3(x, 2.15, z), Vector3(0.09, 0.87, 0.04), WHITE)
	_box(ferry, "LandingRoof", Vector3(0, DECK_HEIGHT - 0.13, 0), Vector3(12, 0.26, 8), WHITE, true)
	_box(ferry, "RoofWalkway", Vector3(0, DECK_HEIGHT + 0.006, 0), Vector3(5.5, 0.012, 7.6), Color("d3e2da"))
	# Rails protect the sides; the entire forward/back edge stays open for jumps.
	for x in [-5.8, 5.8]:
		_box(ferry, "SideRail", Vector3(x, 3.65, 0), Vector3(0.12, 0.9, 7.7), BLUE, true)
		_box(ferry, "RailCap", Vector3(x, 4.13, 0), Vector3(0.18, 0.08, 7.8), WHITE)
	for z in [-3.83, 3.83]:
		_box(ferry, "JumpEdge", Vector3(0, 3.22, z), Vector3(11.4, 0.035, 0.22), GOLD)
	var beacon := _box(ferry, "CheckpointLight", Vector3(-5.25, 4.35, 0), Vector3(0.3, 0.45, 0.3), GOLD)
	beacon.material_override = _material(GOLD, true)
	_checkpoint_lights.append(beacon)
	_label(ferry, "%02d" % (index + 1), Vector3(-4.4, 3.75, 3.95), 44, NAVY)
	_label(ferry, "NYC  FERRY", Vector3(0, 1.55, 3.84), 32)
	# Bow wheelhouse and mast sit beside the route rather than obstructing it.
	_box(ferry, "Wheelhouse", Vector3(7, 1.75, 0), Vector3(1.7, 1.4, 4), WHITE)
	_box(ferry, "BridgeGlass", Vector3(7.02, 2, 0), Vector3(1.75, 0.55, 4.06), NAVY)
	_box(ferry, "Mast", Vector3(7, 3.2, 0), Vector3(0.12, 1.6, 0.12), WHITE)
	_box(ferry, "Radar", Vector3(7, 4, 0), Vector3(1.0, 0.1, 0.12), WHITE)
	for z in [-3.97, 3.97]:
		for x in [-6.7, 6.7]:
			_box(ferry, "Fender", Vector3(x, 0.9, z), Vector3(0.65, 0.7, 0.28), NAVY)


func _build_route() -> void:
	for point in route_points:
		for offset in [-1.1, 1.1]:
			var center := Vector3(point.x, DECK_HEIGHT + 0.025, point.z + offset)
			_beam(self, center + Vector3(-0.45, 0, 0.4), center + Vector3(0, 0, -0.15), 0.1, GOLD)
			_beam(self, center + Vector3(0.45, 0, 0.4), center + Vector3(0, 0, -0.15), 0.1, GOLD)
	_label(self, "DUMBO", Vector3(0, 7.5, -63), 120)
	_label(self, "BROOKLYN  /  FINISH", Vector3(0, 6.15, -62.9), 32, GOLD)
	for x in [-6.8, 6.8]:
		_box(self, "FinishPost", Vector3(x, 5.3, -62), Vector3(0.2, 4.2, 0.2), WHITE)
	_box(self, "FinishHeader", Vector3(0, 7.45, -63.2), Vector3(15, 2.5, 0.3), NAVY)
	for i in range(16):
		_box(self, "FinishStripe", Vector3(-7.5 + i, DECK_HEIGHT + 0.012, -59.5), Vector3(0.5, 0.025, 1.0), WHITE if i % 2 == 0 else NAVY)
	_label(self, "LOWER MANHATTAN", Vector3(0, 5.7, 28), 62).rotation.y = PI
	_label(self, "EAST RIVER  /  PIER 11", Vector3(0, 4.6, 27.95), 28, GOLD).rotation.y = PI
	_label(self, "NEXT STOP\nBROOKLYN", Vector3(5.8, 4.5, 16), 28, NAVY)
	_box(self, "DepartureSign", Vector3(5.8, 4.6, 15.9), Vector3(3.4, 1.7, 0.15), GOLD)


func _build_river() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(1800, 1800)
	_water = MeshInstance3D.new()
	_water.name = "EastRiver"
	_water.mesh = plane
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://scripts/river.gdshader")
	_water.material_override = shader
	add_child(_water)
	# Small pale streaks hint at current without transparency or extra lighting.
	var random := RandomNumberGenerator.new()
	random.seed = 11
	var streaks := MultiMesh.new()
	streaks.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 0.012, 0.07)
	mesh.material = _material(Color("81b5b5"))
	streaks.mesh = mesh
	streaks.instance_count = 260
	for i in streaks.instance_count:
		var pos := Vector3(random.randf_range(-210, 180), 0.035, random.randf_range(-55, 30))
		streaks.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(random.randf_range(0.5, 3), 1, 1)), pos))
	var visual := MultiMeshInstance3D.new()
	visual.multimesh = streaks
	add_child(visual)


func _build_shores() -> void:
	_box(self, "ManhattanShore", Vector3(-25, 0.8, 99), Vector3(560, 3.5, 120), Color("647e79"), true)
	_box(self, "BrooklynShore", Vector3(-25, 0.8, -135), Vector3(560, 3.5, 125), Color("899a84"), true)
	for z in [38.7, -72.3]:
		_box(self, "Seawall", Vector3(-25, 1.25, z), Vector3(560, 3.5, 1.4), Color("8f9486"))
		_box(self, "Promenade", Vector3(-25, 2.6, z + (3 if z > 0 else -3)), Vector3(560, 0.15, 7), Color("d4c7a8"))
	_build_pier("Pier11", 24, 16)
	_build_pier("DumboPier", -65, 18)
	for x in range(-140, 161, 12):
		for z in [37.8, -73.5]:
			_box(self, "WaterfrontLamp", Vector3(x, 4.6, z), Vector3(0.13, 4.2, 0.13), NAVY)
			var lamp := _box(self, "LampGlow", Vector3(x, 6.75, z), Vector3(0.42, 0.35, 0.42), GOLD)
			lamp.material_override = _material(GOLD, true)
	# DUMBO's waterfront park frames the landing with trees and benches.
	for x in [-23, -16, 16, 23, 34, 45]:
		_tree(Vector3(x, 2.65, -80))
		_box(self, "ParkBench", Vector3(x, 3.1, -75.7), Vector3(3.2, 0.2, 0.8), Color("a56e4c"))
		_box(self, "BenchBack", Vector3(x, 3.6, -76), Vector3(3.2, 0.9, 0.15), Color("a56e4c"))


func _build_pier(label: String, z: float, length: float) -> void:
	var pier := Node3D.new()
	pier.name = label
	add_child(pier)
	_box(pier, "Deck", Vector3(0, DECK_HEIGHT - 0.3, z), Vector3(16, 0.6, length), Color("aa8a69"), true)
	# Gangway connects each playable dock to its decorative shoreline.
	var shore_z := 38.0 if z > 0 else -73.0
	_box(pier, "Gangway", Vector3(0, 2.9, (z + shore_z) * 0.5), Vector3(12, 0.6, absf(z - shore_z)), Color("b9a080"), true)
	for dz in range(int(-length / 2) + 1, int(length / 2)):
		_box(pier, "PlankSeam", Vector3(0, DECK_HEIGHT + 0.006, z + dz), Vector3(15.8, 0.012, 0.025), Color("7d6c59"))
	for x in [-7.7, 7.7]:
		_box(pier, "PierRail", Vector3(x, 3.7, z), Vector3(0.12, 1.0, length), NAVY, true)
		for dz in [-length / 2 + 0.3, 0.0, length / 2 - 0.3]:
			_box(pier, "Piling", Vector3(x, 1.4, z + dz), Vector3(0.6, 4.2, 0.6), Color("5b655f"))


func _tree(point: Vector3) -> void:
	_box(self, "TreeTrunk", point + Vector3(0, 1.7, 0), Vector3(0.5, 3.4, 0.5), Color("675342"))
	var mesh := SphereMesh.new()
	mesh.radius = 2.2
	mesh.height = 4.5
	mesh.radial_segments = 8
	mesh.rings = 4
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material(Color("58765d"))
	visual.position = point + Vector3(0, 4.6, 0)
	add_child(visual)


func _build_bridge(label: String, x: float, steel: bool) -> void:
	var bridge := Node3D.new()
	bridge.name = label
	bridge.position.x = x
	add_child(bridge)
	var color := Color("64858a") if steel else Color("bca582")
	var cable_color := Color("4c686d") if steel else Color("847961")
	var road := 17.0 if steel else 14.0
	var height := 44.0 if steel else 37.0
	_box(bridge, "RoadDeck", Vector3(0, road, -17), Vector3(10, 1, 182), color)
	_box(bridge, "RoadSurface", Vector3(0, road + 0.52, -17), Vector3(8.4, 0.04, 182), Color("586c6d"))
	for side in [-4.7, 4.7]:
		_box(bridge, "EdgeGirder", Vector3(side, road + 1.1, -17), Vector3(0.3, 1.8, 182), cable_color)
	for z in [20.0, -59.0]:
		_box(bridge, "Foundation", Vector3(0, 1.4, z), Vector3(14, 4, 7), Color("969782"))
		for side in [-5.3, 0.0, 5.3] if not steel else [-5.3, 5.3]:
			_box(bridge, "TowerLeg", Vector3(side, height / 2, z), Vector3(1.9 if not steel else 1.3, height, 3.8 if not steel else 2.1), color)
		if steel:
			for y in [road + 4, road + 15, height - 1]:
				_box(bridge, "SteelCrossbar", Vector3(0, y, z), Vector3(12, 1.0, 2), color)
			for y in [road + 4, road + 15]:
				_beam(bridge, Vector3(-5, y, z), Vector3(5, y + 10, z), 0.55, color)
				_beam(bridge, Vector3(5, y, z), Vector3(-5, y + 10, z), 0.55, color)
			for side in [-5.3, 5.3]:
				_box(bridge, "TowerCrown", Vector3(side, height + 0.7, z), Vector3(2.5, 1.6, 3.1), color)
		else:
			# Twin pointed Gothic portals are the Brooklyn Bridge's defining outline.
			for side in [-2.65, 2.65]:
				_beam(bridge, Vector3(side - 1.7, height - 8, z), Vector3(side, height - 4, z), 1.25, color)
				_beam(bridge, Vector3(side + 1.7, height - 8, z), Vector3(side, height - 4, z), 1.25, color)
			_box(bridge, "StoneCrown", Vector3(0, height - 1.5, z), Vector3(12.7, 3.0, 4.4), color)
			_box(bridge, "Cornice", Vector3(0, height + 0.15, z), Vector3(13.2, 0.4, 4.7), Color("d5bf98"))
			for side in [-5.3, 0.0, 5.3]:
				for y in range(5, int(height) - 2, 4):
					_box(bridge, "StoneCourse", Vector3(side, y, z + 1.93), Vector3(1.95, 0.07, 0.05), Color("96896f"))
	for side in [-5.0, 5.0]:
		# Cables sag between towers; vertical hangers meet the deck at each sample.
		var previous := Vector3.ZERO
		for i in range(33):
			var t := float(i) / 32.0
			var z := lerpf(20, -59, t)
			var y := road + 3.0 + (height - road - 3.0) * pow(2.0 * t - 1.0, 2)
			var point := Vector3(side, y, z)
			if i > 0:
				_beam(bridge, previous, point, 0.22, cable_color)
			_beam(bridge, Vector3(side, road + 1, z), point, 0.075, cable_color)
			previous = point
		for ends in [[20.0, 74.0], [-59.0, -108.0]]:
			_beam(bridge, Vector3(side, height, ends[0]), Vector3(side, road + 1, ends[1]), 0.23, cable_color)
		if not steel:
			for tower_z in [20.0, -59.0]:
				for reach in [10, 20, 30]:
					var direction := -1.0 if tower_z > 0 else 1.0
					_beam(bridge, Vector3(side, height - 3, tower_z), Vector3(side, road + 1, tower_z + direction * reach), 0.075, cable_color)


func _building(parent: Node3D, label: String, point: Vector3, size: Vector3, color: Color, windows := true) -> void:
	_box(parent, label, point + Vector3(0, size.y / 2, 0), size, color)
	_box(parent, "RoofCap", point + Vector3(0, size.y + 0.2, 0), Vector3(size.x + 0.3, 0.4, size.z + 0.3), color.lightened(0.13))
	if not windows:
		return
	# All city windows share one draw call, including the distant skyline.
	for y in range(4, int(size.y) - 1, 3):
		for x in range(2, int(size.x) - 1, 3):
			for side in [-1, 1]:
				var p := point + Vector3(x - size.x / 2, y, side * (size.z / 2 + 0.025))
				_window_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1, 1.4, 0.06)), p))
		for z in range(2, int(size.z) - 1, 3):
			for side in [-1, 1]:
				var p := point + Vector3(side * (size.x / 2 + 0.025), y, z - size.z / 2)
				_window_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.06, 1.4, 1)), p))


func _build_manhattan() -> void:
	var city := Node3D.new()
	city.name = "ManhattanSkyline"
	add_child(city)
	var random := RandomNumberGenerator.new()
	random.seed = 11201
	var colors := [Color("718c93"), Color("9d9e90"), Color("69838c"), Color("b3ab94"), Color("81959a"), Color("8d8275")]
	for row in range(3):
		for i in range(19):
			var x := -235.0 + i * 21 + random.randf_range(-3, 3)
			var z := 60.0 + row * 29
			var height := random.randf_range(15, 42) + row * 8
			var width := random.randf_range(11, 18)
			var color: Color = colors[random.randi_range(0, colors.size() - 1)]
			_building(city, "CityBlock", Vector3(x, 2.5, z), Vector3(width, height, 16), color)
			if i % 3 == 0:
				_building(city, "Setback", Vector3(x, height + 2.5, z), Vector3(width * 0.7, 8, 12), color, false)
	# One World Trade Center: faceted glass shaft, tapered crown, and tall antenna.
	var tower := Node3D.new()
	tower.name = "OneWorldTradeCenter"
	tower.position = Vector3(64, 2.5, 105)
	city.add_child(tower)
	var vertices := PackedVector3Array()
	var bottom := [Vector3(-11, 0, -11), Vector3(11, 0, -11), Vector3(11, 0, 11), Vector3(-11, 0, 11)]
	var top := [Vector3(0, 100, -8.5), Vector3(8.5, 100, 0), Vector3(0, 100, 8.5), Vector3(-8.5, 100, 0)]
	for i in range(4):
		var j := (i + 1) % 4
		vertices.append_array(PackedVector3Array([bottom[i], top[i], bottom[j], bottom[j], top[i], top[j]]))
		vertices.append_array(PackedVector3Array([top[i], Vector3(0, 100, 0), top[j]]))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in vertices:
		surface.add_vertex(vertex)
	surface.generate_normals()
	var glass := MeshInstance3D.new()
	glass.mesh = surface.commit()
	glass.material_override = _material(Color("a5cbd0"))
	tower.add_child(glass)
	_box(tower, "Antenna", Vector3(0, 113, 0), Vector3(0.7, 26, 0.7), WHITE)
	for y in range(8, 96, 4):
		var t := float(y) / 100.0
		for i in range(4):
			var j := (i + 1) % 4
			_beam(tower, bottom[i].lerp(top[i], t), bottom[j].lerp(top[j], t), 0.12, Color("d0deda"))
	_building(city, "LimestoneTower", Vector3(18, 2.5, 81), Vector3(18, 56, 18), Color("c3b99c"))
	_building(city, "LimestoneCrown", Vector3(18, 58.5, 81), Vector3(12, 12, 12), Color("d3c6a3"))
	var crown := PrismMesh.new()
	crown.size = Vector3(13, 13, 13)
	var crown_visual := MeshInstance3D.new()
	crown_visual.mesh = crown
	crown_visual.position = Vector3(18, 77, 81)
	crown_visual.material_override = _material(Color("60958c"))
	city.add_child(crown_visual)
	for x in [25, 46, 89, 112]:
		_building(city, "SeaportWarehouse", Vector3(x, 2.5, 48), Vector3(18, 11, 14), Color("af8166"))


func _build_brooklyn() -> void:
	var city := Node3D.new()
	city.name = "DumboWaterfront"
	add_child(city)
	for i in range(9):
		var x := -140.0 + i * 31
		var h := 13.0 + (i % 3) * 3
		var color := Color("b78669") if i % 2 else Color("b2987a")
		_building(city, "Warehouse", Vector3(x, 2.5, -94), Vector3(27, h, 22), color)
		for column in range(6):
			_box(city, "BrickPilaster", Vector3(x - 12 + column * 4.8, h * 0.5 + 2.5, -82.92), Vector3(0.4, h, 0.25), color.lightened(0.13))
		_box(city, "WarehouseCornice", Vector3(x, h + 2.6, -94), Vector3(28, 0.8, 23), Color("d4bd9c"))
		if i % 2 == 0:
			var tank := CylinderMesh.new()
			tank.top_radius = 1.9
			tank.bottom_radius = 1.9
			tank.height = 3.4
			tank.radial_segments = 10
			var visual := MeshInstance3D.new()
			visual.mesh = tank
			visual.position = Vector3(x + 6, h + 5.3, -94)
			visual.material_override = _material(Color("6f6b60"))
			city.add_child(visual)
	_label(self, "EMPIRE  STORES", Vector3(-16, 14, -82.8), 42, Color("f5dec0"))
	for i in range(14):
		var x := -150.0 + i * 25
		var h := 24.0 + (i * 17 % 35)
		_building(city, "BrooklynSkyline", Vector3(x, 2, -152 - (i % 2) * 25), Vector3(15, h, 18), Color("889da0"))
	_box(self, "CarouselPavilion", Vector3(-19, 4.8, -76), Vector3(8, 4, 5), Color("94bebc"))
	_box(self, "CarouselRoof", Vector3(-19, 7, -76), Vector3(8.4, 0.3, 5.4), WHITE)
	for x in [-22.8, -19, -15.2]:
		_box(self, "PavilionFrame", Vector3(x, 4.8, -73.45), Vector3(0.12, 4, 0.12), WHITE)
	var frog := preload("res://scenes/frog.tscn").instantiate()
	frog.position = Vector3(11, 2.65, -78)
	add_child(frog)


func _build_windows() -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	multimesh.mesh = mesh
	multimesh.instance_count = _window_transforms.size()
	for i in _window_transforms.size():
		multimesh.set_instance_transform(i, _window_transforms[i])
		multimesh.set_instance_color(i, Color("eacb92") if i % 7 == 0 else Color("506a72"))
	var visual := MultiMeshInstance3D.new()
	visual.name = "CityWindows"
	visual.multimesh = multimesh
	add_child(visual)


func _batch_details() -> void:
	# Static boxes and cables share a draw call per material. Collision parents
	# and checkpoint lights stay individual so physics and feedback keep working.
	var batches: Dictionary = {}
	for node in find_children("*", "MeshInstance3D", true, false):
		var visual := node as MeshInstance3D
		if not visual.mesh is BoxMesh or visual.get_child_count() > 0 or visual.name == "CheckpointLight":
			continue
		var material := visual.material_override
		if not batches.has(material):
			batches[material] = []
		var transform := visual.global_transform
		transform.basis = transform.basis.scaled_local(visual.mesh.size)
		batches[material].append(transform)
		visual.queue_free()
	for material in batches:
		var instances: Array = batches[material]
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		mesh.material = material
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = instances.size()
		for i in instances.size():
			multimesh.set_instance_transform(i, instances[i])
		var visual := MultiMeshInstance3D.new()
		visual.multimesh = multimesh
		add_child(visual)
