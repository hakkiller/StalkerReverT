extends BaseArtifact
class_name SlimeArtifact

func _ready():
	artifact_name = "Слизь"
	artifact_value = 9
	energy_reward = 4.0
	color = Color(0.3, 1, 0.5, 1)
	super._ready()

func _collect_hook(collector: Node):
	if collector.has_method("apply_healing"):
		collector.apply_healing(15.0)
