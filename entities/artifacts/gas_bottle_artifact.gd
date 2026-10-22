extends BaseArtifact
class_name GasBottleArtifact

func _ready():
	artifact_name = "Газовая бутылка"
	artifact_value = 13
	energy_reward = 6.0
	color = Color(0.5, 0.8, 0.3, 1)
	super._ready()

func _collect_hook(collector: Node):
	if collector.has_method("apply_gas_mask"):
		collector.apply_gas_mask(6.0)
