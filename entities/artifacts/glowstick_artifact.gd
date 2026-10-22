extends BaseArtifact
class_name GlowstickArtifact

func _ready():
	artifact_name = "Светяшка"
	artifact_value = 8
	energy_reward = 4.0
	color = Color(0.5, 1, 0.5, 1)
	super._ready()

func _collect_hook(collector: Node):
	if collector.has_method("apply_night_vision"):
		collector.apply_night_vision(10.0)
