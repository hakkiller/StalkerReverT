extends BaseArtifact
class_name JumperArtifact

func _ready():
	artifact_name = "Прыгун"
	artifact_value = 12
	energy_reward = 6.0
	color = Color(0.5, 0.3, 0.9, 1)
	super._ready()

func _collect_hook(collector: Node):
	if collector.has_method("apply_teleport_blink"):
		collector.apply_teleport_blink(3)
