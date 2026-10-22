extends BaseAnomaly
class_name BioBurningFluff

@export var fluff_radius: float = 5.0
@export var fluff_color: Color = Color(1, 0.4, 0.1, 1)
@export var burn_damage: float = 16.0


func _ready():
	anomaly_type = "bio_burning_fluff"
	difficulty_level = 2
	damage_per_second = burn_damage
	
	super._ready()
	_update_size()
	_update_color()


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = fluff_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = fluff_radius
		mesh.mesh.height = fluff_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = fluff_color
		mesh.material_override.emission = fluff_color
