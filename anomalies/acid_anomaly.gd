extends BaseAnomaly
class_name AcidAnomaly

@export var acid_radius: float = 5.0
@export var acid_color: Color = Color(0.8, 1, 0, 1)
@export var corrosion_damage: float = 15.0


func _ready():
	anomaly_type = "acid_anomaly"
	difficulty_level = 1
	damage_per_second = corrosion_damage
	
	super._ready()
	_update_size()
	_update_color()
	set_difficulty(difficulty_level)


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = acid_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = acid_radius
		mesh.mesh.height = acid_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = acid_color
		mesh.material_override.emission = acid_color
