extends BaseAnomaly
class_name GravityVortex

@export var vortex_radius: float = 8.0
@export var vortex_color: Color = Color(0.3, 0, 0.5, 1)
@export var pull_strength: float = 5.0
@export var rotation_speed: float = 2.0


func _ready():
	anomaly_type = "gravity_vortex"
	difficulty_level = 2
	damage_per_second = 12.0
	
	super._ready()
	_update_size()
	_update_color()


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = vortex_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = vortex_radius
		mesh.mesh.height = vortex_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = vortex_color
		mesh.material_override.emission = vortex_color


func _physics_process(delta):
	var mesh = $MeshInstance3D
	if mesh:
		mesh.rotate_y(rotation_speed * delta)
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			var direction = (global_position - stalker.global_position).normalized()
			stalker.global_position += direction * pull_strength * delta
