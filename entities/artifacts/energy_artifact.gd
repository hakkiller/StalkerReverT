# entities/artifacts/energy_artifact.gd
extends BaseArtifact
class_name EnergyArtifact


func _ready_hook():
    artifact_name = "Energy Core"
    artifact_value = 25 + randi() % 11  # 25-35
    energy_reward = 20.0
    rotation_speed = 2.0
    float_amplitude = 0.4
    
    # Особый цвет
    if mesh_instance and mesh_instance.material_override:
        mesh_instance.material_override.albedo_color = Color(0.2, 0.8, 1.0)
        mesh_instance.material_override.emission = Color(0.2, 0.8, 1.0)
    
    pass # print("EnergyArtifact создан, ценность: " + str(artifact_value), "Artifact")


func _collect_hook(collector: Node):
    super._collect_hook(collector)
    
    # Восстанавливает здоровье
    if collector.has_method("heal"):
        var healed = collector.heal(10)
        pass # print("EnergyArtifact: восстановлено " + str(healed) + " HP", "Artifact")
    
    pass # print("EnergyArtifact собран! Даёт +" + str(energy_reward) + " энергии", "Artifact")
