extends CharacterBody3D
## Source-inspired movement in meters/second; intentionally not an exact Source port.

@export var max_speed := 7.0
@export var ground_acceleration := 10.0
@export var friction := 6.0
@export var stop_speed := 2.5
@export var air_acceleration := 12.0
@export var air_wish_speed_cap := 0.8
@export var gravity := 20.0
@export var jump_speed := 7.0
@export var auto_bunny_hop := true

@onready var camera: Camera3D = $Camera3D
var spawn_position := Vector3.ZERO
var _jump_was_held := false


func _ready() -> void:
	spawn_position = position
	Controls.reset_requested.connect(respawn)


func _physics_process(delta: float) -> void:
	if not Controls.playing:
		return
	var look := Controls.consume_look(delta)
	rotation.y = wrapf(rotation.y - look.x, -PI, PI)
	camera.rotation.x = clampf(camera.rotation.x - look.y, deg_to_rad(-89), deg_to_rad(89))
	var input := Controls.movement()
	var wish := global_basis * Vector3(input.x, 0, input.y)
	var wish_speed := max_speed * input.length()
	var wish_direction := wish.normalized()
	var jump_held := Controls.jumping()
	var jump_now := jump_held and (auto_bunny_hop or not _jump_was_held) and is_on_floor()
	_jump_was_held = jump_held
	# Jump before ground friction so a well-timed hop preserves horizontal momentum.
	if is_on_floor() and not jump_now:
		apply_friction(delta)
		accelerate(wish_direction, wish_speed, ground_acceleration * wish_speed * delta)
		velocity.y = 0.0
	else:
		# Cap only projected wish speed, allowing air strafes to build lateral momentum.
		accelerate(wish_direction, minf(wish_speed, air_wish_speed_cap), air_acceleration * wish_speed * delta)
		velocity.y -= gravity * delta
	if jump_now:
		velocity.y = jump_speed
	move_and_slide()
	if position.y < -15.0:
		respawn()


func accelerate(direction: Vector3, wish_speed: float, amount: float) -> void:
	var remaining := wish_speed - velocity.dot(direction)
	if remaining > 0.0:
		velocity += direction * minf(remaining, amount)


func apply_friction(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.001:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var next_speed := maxf(speed - maxf(speed, stop_speed) * friction * delta, 0.0)
	velocity.x *= next_speed / speed
	velocity.z *= next_speed / speed


func respawn() -> void:
	position = spawn_position
	velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	_jump_was_held = false
	Controls.look_delta = Vector2.ZERO
