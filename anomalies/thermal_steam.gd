extends BaseAnomaly
class_name ThermalSteam

@export var steam_radius: float = 7.0
@export var steam_color: Color = Color(0.9, 0.9, 0.8, 0.7)


func _ready():
	anomaly_type = "thermal_steam"
	difficulty_level = 2
	damage_per_second = 8.0
	
	super._ready()
	_update_size()
	_update_color()


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = steam_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = steam_radius
		mesh.mesh.height = steam_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = steam_color
		mesh.material_override.emission = steam_color
