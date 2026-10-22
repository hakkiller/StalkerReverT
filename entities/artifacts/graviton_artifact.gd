extends BaseArtifact
class_name GravitonArtifact

func _ready():
	artifact_name = "Гравитон"
	artifact_value = 15
	energy_reward = 8.0
	color = Color(0.4, 0, 0.6, 1)
	super._ready()

func _collect_hook(collector: Node):
	if collector.has_method("apply_gravity_boost"):
		collector.apply_gravity_boost(2.0)
