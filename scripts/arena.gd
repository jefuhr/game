extends Node3D
## Lightweight primitive geometry keeps the playground inexpensive on mobile GPUs.


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
	_sign("AIR STRAFE / HOP", Vector3(-9, 2.6, -20))
	_sign("RAMP / MOMENTUM", Vector3(8, 3.4, -16))


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


func _sign(label: String, center: Vector3) -> void:
	var sign_label := Label3D.new()
	sign_label.text = label
	sign_label.position = center
	sign_label.font_size = 64
	sign_label.pixel_size = 0.008
	add_child(sign_label)
