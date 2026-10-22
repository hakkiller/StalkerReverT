extends BaseArtifact
class_name SparkArtifact

func _ready():
	artifact_name = "Искра"
	artifact_value = 10
	energy_reward = 5.0
	color = Color(1, 0.9, 0.3, 1)
	super._ready()

func _collect_hook(collector: Node):
	if collector.has_method("apply_electric_charge"):
		collector.apply_electric_charge(3.0)
