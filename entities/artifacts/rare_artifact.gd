# entities/artifacts/rare_artifact.gd
extends BaseArtifact
class_name RareArtifact


func _ready_hook():
    artifact_name = "Rare Artifact"
    artifact_value = 15 + randi() % 11  # 15-25
    energy_reward = 8.0
    rotation_speed = 1.5
    float_amplitude = 0.3
    
    pass # print("RareArtifact создан, ценность: " + str(artifact_value), "Artifact")


func _collect_hook(collector: Node):
    super._collect_hook(collector)
    
    # Временный бафф скорости
    if collector.has_method("set_temporary_speed_boost"):
        collector.set_temporary_speed_boost(1.5, 5.0)
        pass # print("RareArtifact: скорость увеличена на 50% на 5с", "Artifact")
    
    pass # print("RareArtifact собран! Даёт +" + str(energy_reward) + " энергии", "Artifact")
