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

## Frogs this close (horizontally) and roughly ahead can be put on as a hat.
@export var hat_reach := 2.2

@onready var camera: Camera3D = $Camera3D
@onready var hat_mount: Node3D = $Hat
var spawn_position := Vector3.ZERO
## The frog currently worn, or null.
var hat: Node3D
var _jump_was_held := false
var _bounced := false
var _base_stats := {}


func _ready() -> void:
	spawn_position = position
	_base_stats = {"max_speed": max_speed, "jump_speed": jump_speed, "gravity": gravity,
		"trampoline_min_launch": trampoline_min_launch, "trampoline_restitution": trampoline_restitution,
		"trampoline_max_launch": trampoline_max_launch}
	Controls.reset_requested.connect(respawn)
	Controls.hat_requested.connect(toggle_hat)


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


## The nearest free frog within reach in front of the player, or null.
func frog_in_reach() -> Node3D:
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best: Node3D = null
	var best_distance := INF
	for frog: Node3D in get_tree().get_nodes_in_group(&"frog"):
		if frog.worn:
			continue
		var offset := frog.global_position - global_position
		if absf(offset.y) > 2.0:
			continue
		offset.y = 0.0
		var distance := offset.length()
		# Frogs right at the feet count from any direction.
		if distance > hat_reach or (distance > 0.6 and forward.dot(offset / distance) < 0.5):
			continue
		if distance < best_distance:
			best = frog
			best_distance = distance
	return best


## Puts on the frog in reach, swapping out any current hat, or takes the hat off.
func toggle_hat() -> void:
	var frog := frog_in_reach()
	if hat != null:
		_take_off_hat()
	if frog != null:
		hat = frog
		frog.put_on(hat_mount)
	_apply_hat()


func _take_off_hat() -> void:
	var forward := -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var drop := global_position + forward * 0.9 + Vector3.UP * 0.3
	if test_move(global_transform, forward * 1.0):
		# No room ahead: the frog hops off the top of the head instead.
		drop = global_position + Vector3.UP * 1.9
	hat.take_off(drop, forward)
	hat = null


## Resets movement stats, then applies the worn frog's multipliers.
func _apply_hat() -> void:
	var effects: Dictionary = hat.info() if hat != null else {}
	for stat: String in _base_stats:
		set(stat, _base_stats[stat])
	max_speed *= effects.get("speed", 1.0)
	# Jump height scales with speed squared, so "jump" multiplies height directly.
	jump_speed *= sqrt(effects.get("jump", 1.0))
	gravity *= effects.get("gravity", 1.0)
	var bounce: float = effects.get("bounce", 1.0)
	trampoline_min_launch *= bounce
	trampoline_restitution *= bounce
	trampoline_max_launch *= bounce


func respawn() -> void:
	position = spawn_position
	velocity = Vector3.ZERO
	rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	_jump_was_held = false
	_bounced = false
	Controls.look_delta = Vector2.ZERO
