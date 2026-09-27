extends Node3D
## Thrown projectile that falls under gravity and bursts on its first hit.
## Everything in REVERSIBLE_GROUP caught by the growing blast gets its gravity
## reversed for EFFECT_DURATION seconds.

## Characters in this group implement reverse_gravity(duration).
const REVERSIBLE_GROUP := &"gravity_reversible"
const GRAVITY := 20.0
const PROJECTILE_RADIUS := 0.12
const BLAST_RADIUS := 5.0
const BLAST_GROW_TIME := 0.1
const BLAST_FADE_TIME := 0.25
const BLAST_COLOR := Color(0.0, 0.5, 0.5, 0.3)
const EFFECT_DURATION := 5.0
const MAX_LIFETIME := 10.0

var velocity := Vector3.ZERO
## Collision objects the projectile passes through (the thrower).
var exclude: Array[RID] = []
var _age := 0.0
var _exploded := false
var _blast_time := 0.0
var _caught := {}
var _projectile: MeshInstance3D
var _blast: MeshInstance3D
var _blast_material: StandardMaterial3D


func _ready() -> void:
	_projectile = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = PROJECTILE_RADIUS
	mesh.height = PROJECTILE_RADIUS * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(BLAST_COLOR, 1.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	_projectile.mesh = mesh
	add_child(_projectile)


func _physics_process(delta: float) -> void:
	if not Controls.playing:
		return
	if _exploded:
		_update_blast(delta)
		return
	_age += delta
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		global_position = hit.position
		_explode()
	elif _age > MAX_LIFETIME or to.y < -15.0:
		queue_free()
	else:
		global_position = to


func _explode() -> void:
	_exploded = true
	_projectile.queue_free()
	_blast = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	_blast_material = StandardMaterial3D.new()
	_blast_material.albedo_color = BLAST_COLOR
	_blast_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blast_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Visible from inside the sphere too.
	_blast_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = _blast_material
	_blast.mesh = mesh
	_blast.scale = Vector3.ONE * 0.001
	add_child(_blast)
	_update_blast(0.0)


## Grows from 0 to BLAST_RADIUS over BLAST_GROW_TIME, catching anything the
## sphere reaches, then fades out.
func _update_blast(delta: float) -> void:
	_blast_time += delta
	if _blast_time <= BLAST_GROW_TIME + delta:
		var radius := BLAST_RADIUS * minf(_blast_time / BLAST_GROW_TIME, 1.0)
		_blast.scale = Vector3.ONE * maxf(radius, 0.001)
		for body: Node in get_tree().get_nodes_in_group(REVERSIBLE_GROUP):
			if _caught.has(body) or not body is Node3D:
				continue
			if (body as Node3D).global_position.distance_to(global_position) <= radius:
				_caught[body] = true
				body.call(&"reverse_gravity", EFFECT_DURATION)
		return
	var fade := (_blast_time - BLAST_GROW_TIME) / BLAST_FADE_TIME
	if fade >= 1.0:
		queue_free()
		return
	_blast_material.albedo_color.a = BLAST_COLOR.a * (1.0 - fade)
