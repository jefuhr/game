extends CharacterBody3D
## Source-inspired movement in meters/second; intentionally not an exact Source port.

## Bodies in this group are surf ramps: steep faces clip velocity Source-style.
const SURF_GROUP := &"surf"
## Bodies in this group receive the player's velocity when bumped into.
const FROG_GROUP := &"frog"

@export var max_speed := 7.0
@export var ground_acceleration := 10.0
@export var friction := 6.0
@export var stop_speed := 2.5
@export var air_acceleration := 12.0
@export var air_wish_speed_cap := 0.8
@export var gravity := 20.0
@export var jump_speed := 7.0
@export var auto_bunny_hop := true
## Trampoline launch speed = min_launch + impact speed * restitution, capped.
@export var trampoline_min_launch := 6.0
@export var trampoline_restitution := 0.6
@export var trampoline_max_launch := 24.0

@onready var camera: Camera3D = $Camera3D
var spawn_position := Vector3.ZERO
var _jump_was_held := false
var _bounced := false


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
	# The floor state from a trampoline landing is stale: treat that frame as airborne.
	var grounded := is_on_floor() and not _bounced
	_bounced = false
	var jump_held := Controls.jumping()
	var jump_now := jump_held and (auto_bunny_hop or not _jump_was_held) and grounded
	_jump_was_held = jump_held
	# Jump before ground friction so a well-timed hop preserves horizontal momentum.
	if grounded and not jump_now:
		apply_friction(delta)
		accelerate(wish_direction, wish_speed, ground_acceleration * wish_speed * delta)
		velocity.y = 0.0
	else:
		# Cap only projected wish speed, allowing air strafes to build lateral momentum.
		accelerate(wish_direction, minf(wish_speed, air_wish_speed_cap), air_acceleration * wish_speed * delta)
		velocity.y -= gravity * delta
	if jump_now:
		velocity.y = jump_speed
	var incoming := velocity
	move_and_slide()
	_push_frogs(incoming)
	_bounced = _apply_trampolines(incoming)
	if not _bounced:
		_apply_surf(incoming)
	if position.y < -15.0:
		respawn()


## Simple push: any frog hit this frame gets the player's pre-impact velocity added.
func _push_frogs(incoming: Vector3) -> void:
	for i in get_slide_collision_count():
		var frog := get_slide_collision(i).get_collider() as Node
		if frog == null or not frog.is_in_group(FROG_GROUP) or not frog.has_method(&"push"):
			continue
		frog.push(incoming)


## Reflects off the bouncy (+Y) face of any trampoline hit this frame, at any
## orientation. Faster impacts give faster launches; tangential speed is kept.
func _apply_trampolines(incoming: Vector3) -> bool:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var pad := collision.get_collider() as Node3D
		if pad == null or not pad.is_in_group(&"trampoline"):
			continue
		var face := pad.global_basis.y.normalized()
		if collision.get_normal().dot(face) < 0.7:
			continue
		var impact := -incoming.dot(face)
		if impact <= 0.01:
			continue
		var launch := minf(trampoline_min_launch + impact * trampoline_restitution, trampoline_max_launch)
		velocity = incoming + face * (impact + launch)
		return true
	return false


## Source-style surf: on a too-steep-to-stand, upward-facing surf face, only the
## velocity into the face is removed, so all speed along the ramp is kept.
## Holding strafe toward the face converts air acceleration into lift along it.
func _apply_surf(incoming: Vector3) -> bool:
	if is_on_floor():
		return false
	var steepest_floor_y := cos(floor_max_angle)
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var ramp := collision.get_collider() as Node
		if ramp == null or not ramp.is_in_group(SURF_GROUP):
			continue
		var normal := collision.get_normal()
		# Ignore vertical end caps, undersides, and walkable tops.
		if normal.y <= 0.05 or normal.y >= steepest_floor_y:
			continue
		var into := incoming.dot(normal)
		if into < 0.0:
			velocity = incoming - normal * into
		return true
	return false


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
	_bounced = false
	Controls.look_delta = Vector2.ZERO
