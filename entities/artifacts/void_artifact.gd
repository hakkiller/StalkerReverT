extends BaseArtifact
class_name VoidArtifact

func _ready():
	artifact_name = "Пустота"
	artifact_value = 25
	energy_reward = 12.0
	color = Color(0.1, 0, 0.15, 1)
	super._ready()

func _collect_hook(collector: Node):
	if collector.has_method("apply_invisibility"):
		collector.apply_invisibility(5.0)
