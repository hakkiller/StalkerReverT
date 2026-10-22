extends BaseArtifact
class_name HeartArtifact

func _ready():
	artifact_name = "Сердце"
	artifact_value = 22
	energy_reward = 11.0
	color = Color(1, 0.2, 0.3, 1)
	super._ready()

func _collect_hook(collector: Node):
	if collector.has_method("apply_max_health_boost"):
		collector.apply_max_health_boost(20.0)
