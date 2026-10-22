extends BaseAnomaly
class_name RadiationHotspot

@export var radiation_radius: float = 6.0
@export var radiation_color: Color = Color(0.3, 1, 0.3, 1)
@export var radiation_damage: float = 14.0


func _ready():
	anomaly_type = "radiation_hotspot"
	difficulty_level = 2
	damage_per_second = radiation_damage
	
	super._ready()
	_update_size()
	_update_color()


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = radiation_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = radiation_radius
		mesh.mesh.height = radiation_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = radiation_color
		mesh.material_override.emission = radiation_color
