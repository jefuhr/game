extends CharacterBody3D
## Original low-poly civilian. Feet are the origin; the capsule covers the body.

@export var walk_speed := 1.35
var _random := RandomNumberGenerator.new()
var _direction := Vector3.FORWARD
var _decision_time := 0.0
var _idle := false
var _stride := 0.0
var _spawn := Vector3.ZERO
var _visual: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D


func _ready() -> void:
	_random.randomize()
	_spawn = position
	_build_person()
	_choose_direction()


func _physics_process(delta: float) -> void:
	if not Controls.playing:
		return
	_decision_time -= delta
	if _decision_time <= 0.0:
		_idle = _random.randf() < 0.25
		_choose_direction()
	# Probe with the actual body shape so corners and other characters count too.
	if not _idle and test_move(global_transform, _direction * 0.7):
		_choose_direction(true)
	var speed := 0.0 if _idle else walk_speed
	velocity.x = _direction.x * speed
	velocity.z = _direction.z * speed
	velocity.y = -0.5 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	if is_on_wall():
		_choose_direction(true)
	if position.y < -15.0:
		position = _spawn
		velocity = Vector3.ZERO
	var moving := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if moving > 0.05:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-_direction.x, -_direction.z), delta * 8.0)
		_stride += delta * moving * 5.0
	var swing := sin(_stride) * 0.45 * minf(moving / maxf(walk_speed, 0.01), 1.0)
	_left_leg.rotation.x = swing
	_right_leg.rotation.x = -swing
	_left_arm.rotation.x = -swing * 0.7
	_right_arm.rotation.x = swing * 0.7


func _choose_direction(avoid_obstacle := false) -> void:
	_decision_time = _random.randf_range(1.5, 4.0)
	if avoid_obstacle:
		_idle = false
	# Try several headings, then pause briefly if surrounded instead of jittering.
	for attempt in range(12):
		var angle := _random.randf_range(-PI, PI)
		var candidate := Vector3(sin(angle), 0, cos(angle))
		if not test_move(global_transform, candidate * 0.8):
			_direction = candidate
			return
	_idle = true
	_decision_time = 0.5


func _build_person() -> void:
	_visual = Node3D.new()
	_visual.name = "Appearance"
	add_child(_visual)
	var jacket := Color("536a78")
	var trousers := Color("3d4145")
	var skin := Color("be9275")
	var boots := Color("25282b")
	_part(_visual, Vector3(0, 1.20, 0), Vector3(0.46, 0.55, 0.27), jacket)
	_part(_visual, Vector3(0, 0.91, 0), Vector3(0.39, 0.13, 0.26), trousers)
	_part(_visual, Vector3(0, 1.49, 0), Vector3(0.13, 0.12, 0.13), skin)
	_part(_visual, Vector3(0, 1.66, 0), Vector3(0.25, 0.29, 0.23), skin)
	_part(_visual, Vector3(0, 1.80, 0.015), Vector3(0.26, 0.07, 0.24), Color("423931"))
	_part(_visual, Vector3(0, 1.69, 0.106), Vector3(0.26, 0.19, 0.04), Color("423931"))
	_part(_visual, Vector3(0, 1.65, -0.135), Vector3(0.055, 0.07, 0.05), skin)
	for side in [-1.0, 1.0]:
		_part(_visual, Vector3(side * 0.065, 1.70, -0.118), Vector3(0.035, 0.025, 0.012), boots)
		_part(_visual, Vector3(side * 0.13, 1.32, -0.145), Vector3(0.13, 0.12, 0.025), Color("647c89"))
	_part(_visual, Vector3(0, 1.22, -0.145), Vector3(0.018, 0.49, 0.02), Color("a0a3a0"))
	_left_leg = _limb(Vector3(-0.115, 0.90, 0))
	_right_leg = _limb(Vector3(0.115, 0.90, 0))
	for leg in [_left_leg, _right_leg]:
		_part(leg, Vector3(0, -0.37, 0), Vector3(0.17, 0.74, 0.20), trousers)
		_part(leg, Vector3(0, -0.82, -0.045), Vector3(0.19, 0.16, 0.30), boots)
	_left_arm = _limb(Vector3(-0.30, 1.43, 0))
	_right_arm = _limb(Vector3(0.30, 1.43, 0))
	for arm in [_left_arm, _right_arm]:
		_part(arm, Vector3(0, -0.24, 0), Vector3(0.15, 0.48, 0.19), jacket)
		_part(arm, Vector3(0, -0.53, 0), Vector3(0.12, 0.15, 0.14), skin)


func _limb(origin: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = origin
	_visual.add_child(pivot)
	return pivot


func _part(parent: Node3D, center: Vector3, dimensions: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh.material = material
	instance.mesh = mesh
	instance.position = center
	parent.add_child(instance)
