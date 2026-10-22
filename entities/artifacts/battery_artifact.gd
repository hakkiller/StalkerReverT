extends BaseArtifact
class_name BatteryArtifact

func _ready():
	artifact_name = "Батарея"
	artifact_value = 14
	energy_reward = 7.0
	color = Color(0.2, 0.8, 0.2, 1)
	super._ready()

func _collect_hook(collector: Node):
	if collector.has_method("add_energy"):
		collector.add_energy(energy_reward * 2)
