extends BaseAnomaly
class_name ChemicalAcidCloud

@export var cloud_radius: float = 7.0
@export var cloud_color: Color = Color(0.6, 1, 0, 0.7)


func _ready():
	anomaly_type = "chemical_acid_cloud"
	difficulty_level = 2
	damage_per_second = 18.0
	
	super._ready()
	_update_size()
	_update_color()


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = cloud_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = cloud_radius
		mesh.mesh.height = cloud_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = cloud_color
		mesh.material_override.emission = cloud_color
