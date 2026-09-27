extends CharacterBody3D
## Source-inspired movement in meters/second; intentionally not an exact Source port.

## Bodies in this group are surf ramps: steep faces clip velocity Source-style.
const SURF_GROUP := &"surf"

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
## Gravity bomb throw speed along the view, added to the player's velocity.
@export var bomb_throw_speed := 18.0
@export var bomb_cooldown := 0.5

const GravityBomb := preload("res://scripts/gravity_bomb.gd")

@onready var camera: Camera3D = $Camera3D
var spawn_position := Vector3.ZERO
var _jump_was_held := false
var _bounced := false
var _reverse_time := 0.0
var _bomb_cooldown_left := 0.0


func _ready() -> void:
	spawn_position = position
	add_to_group(GravityBomb.REVERSIBLE_GROUP)
	Controls.reset_requested.connect(respawn)
	Controls.throw_requested.connect(throw_bomb)


func _physics_process(delta: float) -> void:
	if not Controls.playing:
		return
	_bomb_cooldown_left = maxf(_bomb_cooldown_left - delta, 0.0)
	if _reverse_time > 0.0:
		_reverse_time -= delta
		if _reverse_time <= 0.0:
			up_direction = Vector3.UP
	# -1 while a gravity bomb has flipped us: "floor" becomes whatever is overhead.
	var up_sign := up_direction.y
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
		velocity.y -= gravity * delta * up_sign
	if jump_now:
		velocity.y = jump_speed * up_sign
	var incoming := velocity
	move_and_slide()
	_bounced = _apply_trampolines(incoming)
	if not _bounced:
		_apply_surf(incoming)
	if position.y < -15.0:
		respawn()


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
	if is_on_floor() or _reverse_time > 0.0:
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


## Called by gravity bombs; a fresh hit restarts the timer rather than stacking.
func reverse_gravity(duration: float) -> void:
	_reverse_time = duration
	up_direction = Vector3.DOWN


func throw_bomb() -> void:
	if not Controls.playing or _bomb_cooldown_left > 0.0:
		return
	_bomb_cooldown_left = bomb_cooldown
	var forward := -camera.global_basis.z
	var bomb := GravityBomb.new()
	bomb.velocity = velocity + forward * bomb_throw_speed
	bomb.exclude.append(get_rid())
	get_parent().add_child(bomb)
	bomb.global_position = camera.global_position + forward * 0.4


func respawn() -> void:
	position = spawn_position
	velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	_jump_was_held = false
	_bounced = false
	_reverse_time = 0.0
	up_direction = Vector3.UP
	Controls.look_delta = Vector2.ZERO
