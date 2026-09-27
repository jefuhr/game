extends RefCounted
## Bursts a box-built NPC into physics gibs made from its own mesh parts.

## Seconds gibs lie around before shrinking away.
const LIFETIME := 8.0
const BLOOD := Color("7a1010")


## Replaces `body` with flying chunks carried along by `impact` velocity.
static func explode(body: Node3D, impact: Vector3) -> void:
	var world := body.get_parent() as Node3D
	if world == null or body.is_queued_for_deletion():
		return
	var random := RandomNumberGenerator.new()
	random.randomize()
	var center := body.global_position + Vector3.UP * 0.5
	var meshes: Array[MeshInstance3D] = []
	for node in body.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node)
	for mesh in meshes:
		var box := mesh.mesh as BoxMesh
		if box == null:
			continue
		var scale := mesh.global_basis.get_scale()
		var spot := mesh.global_transform.orthonormalized()
		mesh.get_parent().remove_child(mesh)
		mesh.transform = Transform3D(Basis.from_scale(scale), Vector3.ZERO)
		_spawn_chunk(world, spot, mesh, box.size * scale, center, impact, random)
	# A spray of blood chunks on top of the body parts.
	for i in 10:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * random.randf_range(0.05, 0.12)
		var material := StandardMaterial3D.new()
		material.albedo_color = BLOOD
		material.roughness = 0.4
		box.material = material
		mesh.mesh = box
		var offset := Vector3(random.randf_range(-0.2, 0.2), random.randf_range(0.0, 1.0), random.randf_range(-0.2, 0.2))
		var spot := Transform3D(Basis.IDENTITY, body.global_position + offset)
		_spawn_chunk(world, spot, mesh, box.size, center, impact, random)
	# Stop blocking right away, even if more physics ticks run before the free.
	if body is CollisionObject3D:
		body.collision_layer = 0
		body.collision_mask = 0
	body.set_physics_process(false)
	body.queue_free()


static func _spawn_chunk(world: Node3D, spot: Transform3D, mesh: MeshInstance3D, size: Vector3,
		center: Vector3, impact: Vector3, random: RandomNumberGenerator) -> void:
	var chunk := RigidBody3D.new()
	# Gibs rest on the world but are on no layer, so nothing (least of all the
	# player) is ever blocked by them.
	chunk.collision_layer = 0
	chunk.collision_mask = 1
	chunk.continuous_cd = true
	chunk.mass = maxf(size.x * size.y * size.z * 50.0, 0.05)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size.abs().max(Vector3.ONE * 0.04)
	shape.shape = box_shape
	chunk.add_child(shape)
	chunk.add_child(mesh)
	world.add_child(chunk)
	chunk.global_transform = spot
	var outward := (spot.origin - center).normalized()
	var spread := Vector3(random.randf_range(-1, 1), random.randf_range(0.2, 1.2), random.randf_range(-1, 1))
	chunk.linear_velocity = impact * random.randf_range(0.6, 1.0) + (outward + spread) * random.randf_range(2.0, 5.0)
	chunk.angular_velocity = Vector3(random.randf_range(-15, 15), random.randf_range(-15, 15), random.randf_range(-15, 15))
	var fade := chunk.create_tween()
	fade.tween_interval(LIFETIME + random.randf_range(0.0, 2.0))
	fade.tween_property(mesh, "scale", Vector3.ZERO, 0.6)
	fade.tween_callback(chunk.queue_free)
