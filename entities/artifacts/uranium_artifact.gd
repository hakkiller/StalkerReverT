extends BaseArtifact
class_name UraniumArtifact

func _ready():
	artifact_name = "Уран"
	artifact_value = 18
	energy_reward = 9.0
	color = Color(0.2, 1, 0.2, 1)
	super._ready()

func _collect_hook(collector: Node):
	if collector.has_method("apply_radiation_boost"):
		collector.apply_radiation_boost(5.0)
