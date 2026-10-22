extends BaseAnomaly
class_name TimeDilation

@export var dilation_radius: float = 6.0
@export var dilation_color: Color = Color(0.6, 0.3, 0.8, 1)
@export var time_scale: float = 0.3


func _ready():
	anomaly_type = "time_dilation"
	difficulty_level = 3
	damage_per_second = 5.0
	
	super._ready()
	_update_size()
	_update_color()


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = dilation_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = dilation_radius
		mesh.mesh.height = dilation_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = dilation_color
		mesh.material_override.emission = dilation_color


func _physics_process(_delta):
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker) and stalker.has_method("apply_time_dilation"):
			stalker.apply_time_dilation(time_scale)
