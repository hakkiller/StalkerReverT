extends BaseArtifact
class_name AcidDropArtifact

func _ready():
	artifact_name = "Кислотная капля"
	artifact_value = 11
	energy_reward = 5.0
	color = Color(0.7, 1, 0, 1)
	super._ready()

func _collect_hook(collector: Node):
	if collector.has_method("apply_acid_resistance"):
		collector.apply_acid_resistance(4.0)
