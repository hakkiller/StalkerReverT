extends BaseAnomaly
class_name ElectricTesla

@export var tesla_radius: float = 5.0
@export var tesla_color: Color = Color(0.3, 0.8, 1, 1)
@export var chain_lightnings: int = 3
@export var chain_range: float = 8.0


func _ready():
	anomaly_type = "electric_tesla"
	difficulty_level = 3
	damage_per_second = 18.0
	
	super._ready()
	_update_size()
	_update_color()
	set_difficulty(difficulty_level)


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = tesla_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = tesla_radius
		mesh.mesh.height = tesla_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = tesla_color
		mesh.material_override.emission = tesla_color


func _apply_damage():
	if not is_active:
		return
	
	var targets = stalkers_in_zone.duplicate()
	for i in range(min(chain_lightnings, targets.size())):
		if i < targets.size() and is_instance_valid(targets[i]):
			if targets[i].has_method("take_damage"):
				targets[i].take_damage(damage_per_second)
				energy_consumed.emit(damage_per_second)
