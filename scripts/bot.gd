extends "res://scripts/player.gd"
## Computer-controlled runner. Shares the player's Source-style movement,
## trampoline bounces and surf clipping, but steers itself between waypoints
## and bunny hops across the arena. Feet are the origin, like the player.

## Obstacle probes start slightly raised so flush floor trampolines' thin lip
## does not count as a wall.
const PROBE_LIFT := 0.06
## Random waypoints stay inside the walls, clear of the edges (x, z).
const ROAM_MIN := Vector2(-17.0, -25.0)
const ROAM_MAX := Vector2(17.0, 25.0)
## Spots the bot likes to visit besides random ones.
const LANDMARKS := [
	Vector3(14, 0, 4), # trampoline under the roof
	Vector3(-9, 0, -12), # far end of the jump blocks
	Vector3(-13, 0, 18), # cornflower steps
	Vector3(15, 0, -4), # sloped trampoline
]
const SUIT_COLOR := Color("f08a24")

@export var arrive_distance := 1.5
## The bot bunny hops while its waypoint is further away than this.
@export var hop_distance := 5.0
## Seconds of barely moving before the bot gives up on a waypoint.
@export var stuck_timeout := 1.0

var _random := RandomNumberGenerator.new()
var _target := Vector3.ZERO
var _target_time := 0.0
var _stuck_time := 0.0
var _visual: Node3D


func _ready() -> void:
	_random.randomize()
	spawn_position = position
	_build_body()
	_pick_target()


func _physics_process(delta: float) -> void:
	if not Controls.playing:
		return
	_target_time -= delta
	var to_target := Vector3(_target.x - global_position.x, 0, _target.z - global_position.z)
	if to_target.length() < arrive_distance or _target_time <= 0.0:
		_pick_target()
		to_target = Vector3(_target.x - global_position.x, 0, _target.z - global_position.z)
	var distance := to_target.length()
	var wish_direction := to_target / maxf(distance, 0.001)
	# Same movement step as the player, with the bot's steering as input.
	var grounded := is_on_floor() and not _bounced
	_bounced = false
	var jump_now := grounded and (distance > hop_distance or _blocked(wish_direction * 0.6))
	if grounded and not jump_now:
		apply_friction(delta)
		accelerate(wish_direction, max_speed, ground_acceleration * max_speed * delta)
		velocity.y = 0.0
	else:
		accelerate(wish_direction, air_wish_speed_cap, air_acceleration * max_speed * delta)
		velocity.y -= gravity * delta
	if jump_now:
		velocity.y = jump_speed
	var incoming := velocity
	move_and_slide()
	_bounced = _apply_trampolines(incoming)
	if not _bounced:
		_apply_surf(incoming)
	var moving := Vector2(get_real_velocity().x, get_real_velocity().z)
	_stuck_time = _stuck_time + delta if moving.length() < 1.0 else 0.0
	if _stuck_time > stuck_timeout:
		_pick_target()
	if moving.length() > 0.5:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-moving.x, -moving.y), delta * 10.0)
	if position.y < -15.0:
		respawn()


func respawn() -> void:
	position = spawn_position
	velocity = Vector3.ZERO
	_bounced = false
	_pick_target()


func _blocked(motion: Vector3) -> bool:
	return test_move(global_transform.translated(Vector3.UP * PROBE_LIFT), motion)


func _pick_target() -> void:
	_target_time = _random.randf_range(6.0, 10.0)
	_stuck_time = 0.0
	if _random.randf() < 0.3:
		_target = LANDMARKS[_random.randi() % LANDMARKS.size()]
	else:
		_target = Vector3(_random.randf_range(ROAM_MIN.x, ROAM_MAX.x), 0, _random.randf_range(ROAM_MIN.y, ROAM_MAX.y))


## Blocky orange runner with a glowing visor and a "BOT" tag overhead.
func _build_body() -> void:
	_visual = Node3D.new()
	_visual.name = "Appearance"
	add_child(_visual)
	var dark := Color("2b2f33")
	for side in [-1.0, 1.0]:
		_part(Vector3(side * 0.11, 0.45, 0), Vector3(0.17, 0.9, 0.2), dark)
		_part(Vector3(side * 0.31, 1.2, 0), Vector3(0.13, 0.55, 0.16), SUIT_COLOR)
	_part(Vector3(0, 1.2, 0), Vector3(0.46, 0.6, 0.28), SUIT_COLOR)
	_part(Vector3(0, 1.64, 0), Vector3(0.3, 0.3, 0.3), Color("c9ced1"))
	var visor := _part(Vector3(0, 1.66, -0.155), Vector3(0.24, 0.09, 0.02), Color("3fe0ff"))
	var glow: StandardMaterial3D = visor.mesh.material
	glow.emission_enabled = true
	glow.emission = Color("3fe0ff")
	var tag := Label3D.new()
	tag.text = "BOT"
	tag.position = Vector3(0, 2.1, 0)
	tag.font_size = 40
	tag.pixel_size = 0.008
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = SUIT_COLOR.lightened(0.3)
	add_child(tag)


func _part(center: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh.material = material
	instance.mesh = mesh
	instance.position = center
	_visual.add_child(instance)
	return instance
