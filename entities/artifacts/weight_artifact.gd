extends BaseArtifact
class_name WeightArtifact

func _ready():
	artifact_name = "Гиря"
	artifact_value = 12
	energy_reward = 6.0
	color = Color(0.2, 0.2, 0.3, 1)
	super._ready()

func _collect_hook(collector: Node):
	if collector.has_method("apply_weight"):
		collector.apply_weight(1.5)
