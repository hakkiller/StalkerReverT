extends BaseAnomaly
class_name ChemicalGas

@export var gas_radius: float = 8.0
@export var gas_color: Color = Color(0.5, 0.8, 0.3, 0.6)
@export var poison_damage: float = 12.0


func _ready():
	anomaly_type = "chemical_gas"
	difficulty_level = 1
	damage_per_second = poison_damage
	
	super._ready()
	_update_size()
	_update_color()


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = gas_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = gas_radius
		mesh.mesh.height = gas_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = gas_color
		mesh.material_override.emission = gas_color
