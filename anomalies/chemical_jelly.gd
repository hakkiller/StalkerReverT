extends BaseAnomaly
class_name ChemicalJelly

@export var jelly_radius: float = 4.0
@export var jelly_color: Color = Color(0.2, 1, 0.4, 0.8)
@export var slow_factor: float = 0.5


func _ready():
	anomaly_type = "chemical_jelly"
	difficulty_level = 1
	damage_per_second = 8.0
	
	super._ready()
	_update_size()
	_update_color()


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = jelly_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = jelly_radius
		mesh.mesh.height = jelly_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = jelly_color
		mesh.material_override.emission = jelly_color


func _apply_damage():
	if not is_active:
		return
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			if stalker.has_method("take_damage"):
				stalker.take_damage(damage_per_second)
				if stalker.has_method("apply_slow"):
					stalker.apply_slow(slow_factor)
				energy_consumed.emit(damage_per_second)
