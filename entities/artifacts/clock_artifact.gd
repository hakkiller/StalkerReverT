extends BaseArtifact
class_name ClockArtifact

func _ready():
	artifact_name = "Часы"
	artifact_value = 16
	energy_reward = 8.0
	color = Color(0.6, 0.3, 0.8, 1)
	super._ready()

func _collect_hook(collector: Node):
	if collector.has_method("apply_time_slow"):
		collector.apply_time_slow(0.5)
