extends BaseArtifact
class_name StormArtifact

func _ready():
	artifact_name = "Шторм"
	artifact_value = 20
	energy_reward = 10.0
	color = Color(0.3, 0.5, 1, 1)
	super._ready()

func _collect_hook(collector: Node):
	if collector.has_method("apply_storm_shield"):
		collector.apply_storm_shield(8.0)
