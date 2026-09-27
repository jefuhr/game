extends Node3D
## Another player's avatar. Visual only (no collider); eases toward the latest
## networked position so 20 Hz updates look smooth.

const SMOOTHING := 14.0

var peer_id := 0
var target_position := Vector3.ZERO
var target_yaw := 0.0
var _has_state := false


func _ready() -> void:
	var color := Color.from_hsv(fmod(peer_id * 0.618034, 1.0), 0.6, 0.95)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	capsule.material = material
	var body := MeshInstance3D.new()
	body.mesh = capsule
	body.position.y = 0.9
	add_child(body)
	# A visor shows which way the player is facing (-Z is forward).
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.5, 0.14, 0.12)
	var visor_material := StandardMaterial3D.new()
	visor_material.albedo_color = Color(0.05, 0.08, 0.12)
	visor_mesh.material = visor_material
	var visor := MeshInstance3D.new()
	visor.mesh = visor_mesh
	visor.position = Vector3(0, 1.55, -0.32)
	add_child(visor)
	var label := Label3D.new()
	label.text = "PLAYER %d" % (peer_id % 10000)
	label.position.y = 2.2
	label.font_size = 40
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color.lightened(0.3)
	add_child(label)


func apply_state(next_position: Vector3, yaw: float) -> void:
	target_position = next_position
	target_yaw = yaw
	if not _has_state:
		_has_state = true
		position = next_position
		rotation.y = yaw


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-SMOOTHING * delta)
	# Snap on respawns and other teleports instead of gliding across the arena.
	if position.distance_to(target_position) > 8.0:
		position = target_position
	else:
		position = position.lerp(target_position, weight)
	rotation.y = lerp_angle(rotation.y, target_yaw, weight)
