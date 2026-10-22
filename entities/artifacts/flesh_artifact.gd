extends BaseArtifact
class_name FleshArtifact

func _ready():
	artifact_name = "Плоть"
	artifact_value = 10
	energy_reward = 5.0
	color = Color(0.9, 0.4, 0.5, 1)
	super._ready()

func _collect_hook(collector: Node):
	if collector.has_method("apply_health_boost"):
		collector.apply_health_boost(25.0)
