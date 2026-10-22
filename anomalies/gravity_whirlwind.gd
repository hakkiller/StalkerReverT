extends BaseAnomaly
class_name GravityWhirlwind

@export var whirlwind_radius: float = 6.0
@export var whirlwind_color: Color = Color(0.4, 0.2, 0.8, 1)
@export var rotation_speed: float = 3.0
@export var centrifugal_force: float = 4.0


func _ready():
	anomaly_type = "gravity_whirlwind"
	difficulty_level = 3
	damage_per_second = 10.0
	
	super._ready()
	_update_size()
	_update_color()


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = whirlwind_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = whirlwind_radius
		mesh.mesh.height = whirlwind_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = whirlwind_color
		mesh.material_override.emission = whirlwind_color


func _physics_process(delta):
	var mesh = $MeshInstance3D
	if mesh:
		mesh.rotate_y(rotation_speed * delta)
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			var to_stalker = stalker.global_position - global_position
			var perpendicular = Vector3(-to_stalker.z, 0, to_stalker.x).normalized()
			stalker.global_position += perpendicular * centrifugal_force * delta
