# anomalies/heat_anomaly.gd
extends BaseAnomaly
class_name HeatAnomaly

@export var heat_radius: float = 5.0
@export var heat_color: Color = Color(1, 0.5, 0, 1)


func _ready():
	anomaly_type = "heat_anomaly"
	difficulty_level = 1
	damage_per_second = 10.0
	radius = heat_radius
	color = heat_color
	
	super._ready()
