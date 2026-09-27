extends CharacterBody3D
## Simple low-poly frog: a tiny citizen that wanders the arena in short hops.
## Feet are the origin; a small sphere covers the body. Faces -Z like citizens.

## Obstacle probes start slightly raised so flush floor trampolines' thin lip
## does not count as a wall.
const PROBE_LIFT := 0.06
const GRAVITY := 20.0

enum Kind { GREEN, BLUE, RED, PURPLE, GOLDEN }
## Kinds are rolled by weight (out of 100). Worn as a hat, a frog's multipliers
## apply to the player: "jump" scales jump height, "speed" run speed, "gravity"
## fall acceleration and "bounce" trampoline launches. Frogs hop the same way.
const KINDS := {
	Kind.GREEN: {"name": "Green Frog", "rarity": "Common", "weight": 50, "skin": Color("4f9d3a"),
		"summary": "Just a very nice hat."},
	Kind.BLUE: {"name": "Blue Frog", "rarity": "Uncommon", "weight": 24, "skin": Color("2f7fd8"),
		"speed": 1.25, "summary": "Run 25% faster."},
	Kind.RED: {"name": "Red Frog", "rarity": "Uncommon", "weight": 14, "skin": Color("d8452f"),
		"bounce": 1.5, "summary": "Trampolines launch you higher."},
	Kind.PURPLE: {"name": "Purple Frog", "rarity": "Rare", "weight": 8, "skin": Color("8a4fd0"),
		"gravity": 0.7, "summary": "Floaty low gravity."},
	Kind.GOLDEN: {"name": "Golden Frog", "rarity": "Legendary", "weight": 4, "skin": Color("e8b923"),
		"jump": 2.0, "summary": "Jump twice as high."},
}

## Which kind this frog is; -1 rolls a random kind by rarity.
@export var kind := -1
## Horizontal speed of a hop.
@export var hop_speed := 2.5
## Upward speed at the start of a hop.
@export var hop_height := 4.0
## Upward speed a frog springs with when landing on an upward-facing trampoline.
@export var trampoline_hop_speed := 6.0
var _random := RandomNumberGenerator.new()
var _direction := Vector3.FORWARD
var _rest_time := 0.0
var _hopping := false
var _spawn := Vector3.ZERO
var _bounced := false
var _squash := 0.0
var _visual: Node3D
var _body: Node3D
var _back_legs: Array[Node3D] = []
var _gravity := GRAVITY
var _home: Node
## True while sitting on someone's head; physics and collision are off.
var worn := false


func _ready() -> void:
	add_to_group(&"frog")
	_random.randomize()
	_spawn = position
	_home = get_parent()
	if not KINDS.has(kind):
		kind = _roll_kind()
	var stats := info()
	hop_speed *= stats.get("speed", 1.0)
	hop_height *= sqrt(stats.get("jump", 1.0))
	trampoline_hop_speed *= stats.get("bounce", 1.0)
	_gravity *= stats.get("gravity", 1.0)
	_build_frog()
	var angle := _random.randf_range(-PI, PI)
	_direction = Vector3(sin(angle), 0, cos(angle))
	_visual.rotation.y = atan2(-_direction.x, -_direction.z)
	_rest_time = _random.randf_range(0.3, 2.0)


func _physics_process(delta: float) -> void:
	if not Controls.playing or worn:
		return
	# The floor state from a trampoline hop is stale: treat that frame as airborne.
	var grounded := is_on_floor() and not _bounced
	if grounded:
		if _hopping:
			_hopping = false
			_squash = 1.0
			_rest_time = _random.randf_range(0.6, 2.4)
		velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
		velocity.y = -0.5
		_rest_time -= delta
		if _rest_time <= 0.0:
			_start_hop()
	else:
		velocity.y -= _gravity * delta
	var incoming_y := velocity.y
	move_and_slide()
	_bounced = _hop_on_trampolines(incoming_y)
	if _bounced:
		_hopping = true
	if position.y < -15.0:
		position = _spawn
		velocity = Vector3.ZERO
		_bounced = false
		_hopping = false
	_animate(delta)


func info() -> Dictionary:
	return KINDS[kind]


func _roll_kind() -> int:
	var roll := _random.randi_range(1, 100)
	for candidate: int in KINDS:
		roll -= KINDS[candidate]["weight"]
		if roll <= 0:
			return candidate
	return Kind.GREEN


## Sits on `head` facing the same way; the frog stops hopping and colliding.
func put_on(head: Node3D) -> void:
	worn = true
	velocity = Vector3.ZERO
	_hopping = false
	_bounced = false
	_squash = 0.0
	$CollisionShape3D.set_deferred(&"disabled", true)
	reparent(head, false)
	transform = Transform3D.IDENTITY
	_direction = Vector3.FORWARD
	_visual.rotation.y = 0.0
	_body.scale = Vector3.ONE
	for leg in _back_legs:
		leg.rotation.x = 0.0


## Hops off the head back into the world at `where`, heading along `facing`.
func take_off(where: Vector3, facing: Vector3) -> void:
	worn = false
	reparent(_home, false)
	transform = Transform3D.IDENTITY
	global_position = where
	velocity = Vector3.ZERO
	_hopping = true
	_direction = facing
	_visual.rotation.y = atan2(-facing.x, -facing.z)
	_rest_time = _random.randf_range(0.6, 1.5)
	$CollisionShape3D.set_deferred(&"disabled", false)


func _start_hop() -> void:
	# Usually keep a similar heading; sometimes wander off somewhere new.
	var base := atan2(_direction.x, _direction.z)
	for attempt in range(12):
		var angle := base + _random.randf_range(-0.8, 0.8)
		if attempt > 2 or _random.randf() < 0.3:
			angle = _random.randf_range(-PI, PI)
		var candidate := Vector3(sin(angle), 0, cos(angle))
		if not _blocked(candidate * 1.0):
			_direction = candidate
			velocity = candidate * hop_speed + Vector3.UP * hop_height
			_hopping = true
			return
	# Boxed in: sit tight and try again shortly.
	_rest_time = 0.5


## Frogs spring higher whenever they land on the top of a trampoline.
func _hop_on_trampolines(incoming_y: float) -> bool:
	if incoming_y > 0.0:
		return false
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var pad := collision.get_collider() as Node3D
		if pad == null or not pad.is_in_group(&"trampoline"):
			continue
		var face := pad.global_basis.y.normalized()
		if face.y < 0.7 or collision.get_normal().dot(face) < 0.7:
			continue
		velocity.y = trampoline_hop_speed
		return true
	return false


func _blocked(motion: Vector3) -> bool:
	return test_move(global_transform.translated(Vector3.UP * PROBE_LIFT), motion)


func _animate(delta: float) -> void:
	_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-_direction.x, -_direction.z), delta * 10.0)
	_squash = move_toward(_squash, 0.0, delta * 5.0)
	var crouch := 0.0
	if not _hopping and _rest_time < 0.2:
		crouch = 1.0 - maxf(_rest_time, 0.0) / 0.2
	var flatten := maxf(_squash, crouch) * 0.25
	var stretch := 0.15 if _hopping else 0.0
	_body.scale = Vector3(1.0 + flatten * 0.6, 1.0 - flatten + stretch, 1.0 - stretch * 0.3)
	var kick := 0.9 if _hopping else 0.0
	for leg in _back_legs:
		leg.rotation.x = lerpf(leg.rotation.x, kick, delta * 14.0)


func _build_frog() -> void:
	_visual = Node3D.new()
	_visual.name = "Appearance"
	add_child(_visual)
	_body = Node3D.new()
	_body.name = "Body"
	_visual.add_child(_body)
	var skin: Color = info()["skin"]
	if kind == Kind.GREEN:
		skin = skin.lerp(Color("8fae2e"), _random.randf_range(0.0, 0.6))
	else:
		skin = skin.lightened(_random.randf_range(0.0, 0.12))
	var dark := skin.darkened(0.35)
	var belly := Color("d6d98a")
	var eye := Color("e8e070")
	var pupil := Color("141612")
	_part(_body, Vector3(0, 0.17, 0.03), Vector3(0.34, 0.2, 0.4), skin)
	_part(_body, Vector3(0, 0.08, 0.0), Vector3(0.3, 0.05, 0.34), belly)
	_part(_body, Vector3(0, 0.23, -0.18), Vector3(0.3, 0.14, 0.18), skin)
	_part(_body, Vector3(0, 0.195, -0.271), Vector3(0.24, 0.014, 0.01), dark)
	_part(_body, Vector3(0.05, 0.28, 0.1), Vector3(0.08, 0.02, 0.08), dark)
	_part(_body, Vector3(-0.07, 0.28, -0.02), Vector3(0.06, 0.02, 0.06), dark)
	for side in [-1.0, 1.0]:
		_part(_body, Vector3(side * 0.1, 0.32, -0.2), Vector3(0.09, 0.09, 0.09), eye)
		_part(_body, Vector3(side * 0.1, 0.325, -0.248), Vector3(0.05, 0.05, 0.01), pupil)
		_part(_body, Vector3(side * 0.13, 0.05, -0.15), Vector3(0.06, 0.1, 0.06), skin)
		_part(_body, Vector3(side * 0.14, 0.01, -0.19), Vector3(0.1, 0.02, 0.08), dark)
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.16, 0.13, 0.14)
		_visual.add_child(leg)
		_part(leg, Vector3(0, -0.03, 0.03), Vector3(0.1, 0.1, 0.2), skin)
		_part(leg, Vector3(0, -0.115, 0.03), Vector3(0.12, 0.03, 0.2), dark)
		_back_legs.append(leg)


func _part(parent: Node3D, center: Vector3, dimensions: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	# Golden frogs shine and glow faintly so the rarest hat is easy to spot.
	if kind == Kind.GOLDEN and color.s > 0.5:
		material.metallic = 0.5
		material.roughness = 0.35
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.35
	mesh.material = material
	instance.mesh = mesh
	instance.position = center
	parent.add_child(instance)
