extends BaseAnomaly
class_name ElectricAnomaly

@export var electric_radius: float = 4.0
@export var electric_color: Color = Color(0.2, 0.6, 1, 1)
@export var stun_chance: float = 0.3
@export var stun_duration: float = 1.5


func _ready():
	anomaly_type = "electric_anomaly"
	difficulty_level = 1
	damage_per_second = 15.0
	
	super._ready()
	_update_size()
	_update_color()


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = electric_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = electric_radius
		mesh.mesh.height = electric_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = electric_color
		mesh.material_override.emission = electric_color


func _apply_damage():
	if not is_active:
		return
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			if stalker.has_method("take_damage"):
				stalker.take_damage(damage_per_second)
				if randf() < stun_chance and stalker.has_method("stun"):
					stalker.stun(stun_duration)
				energy_consumed.emit(damage_per_second)
