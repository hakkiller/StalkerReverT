extends BaseArtifact
class_name HourglassArtifact

func _ready():
	artifact_name = "Песочные часы"
	artifact_value = 17
	energy_reward = 8.5
	color = Color(0.7, 0.5, 0.9, 1)
	super._ready()

func _collect_hook(collector: Node):
	if collector.has_method("apply_time_stop"):
		collector.apply_time_stop(2.0)
