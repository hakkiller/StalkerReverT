# entities/artifacts/common_artifact.gd
extends BaseArtifact
class_name CommonArtifact


func _ready_hook():
    artifact_name = "Common Artifact"
    artifact_value = 5 + randi() % 6  # 5-10
    energy_reward = 2.0
    rotation_speed = 1.0
    float_amplitude = 0.2
    
    pass # print("CommonArtifact создан, ценность: " + str(artifact_value), "Artifact")


func _collect_hook(collector: Node):
    super._collect_hook(collector)
    pass # print("CommonArtifact собран! Даёт +" + str(energy_reward) + " энергии", "Artifact")
