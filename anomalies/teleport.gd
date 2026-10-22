extends BaseAnomaly
class_name TeleportAnomaly

@export var teleport_radius: float = 5.0
@export var teleport_color: Color = Color(0.5, 0, 1, 1)
@export var teleport_range: float = 30.0
@export var teleport_cooldown: float = 3.0

var teleport_timers: Dictionary = {}


func _ready():
	anomaly_type = "teleport"
	difficulty_level = 3
	damage_per_second = 3.0
	
	super._ready()
	_update_size()
	_update_color()
	set_difficulty(difficulty_level)


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = teleport_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = teleport_radius
		mesh.mesh.height = teleport_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = teleport_color
		mesh.material_override.emission = teleport_color


func _process(delta):
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			var id = stalker.get_instance_id()
			if not teleport_timers.has(id):
				teleport_timers[id] = 0.0
			
			teleport_timers[id] += delta
			
			if teleport_timers[id] >= teleport_cooldown:
				_teleport_stalker(stalker)
				teleport_timers[id] = 0.0


func _teleport_stalker(stalker: Node):
	if stalker.has_method("take_damage"):
		stalker.take_damage(damage_per_second * 5.0)
	
	var random_offset = Vector3(
		randf_range(-teleport_range, teleport_range),
		0,
		randf_range(-teleport_range, teleport_range)
	)
	stalker.global_position += random_offset
	
	energy_consumed.emit(damage_per_second * 5.0)
