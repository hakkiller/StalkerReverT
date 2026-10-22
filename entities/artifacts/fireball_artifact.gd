# entities/artifacts/fireball_artifact.gd
extends BaseArtifact
class_name FireballArtifact


func _ready_hook():
    artifact_name = "Fireball"
    artifact_value = 15 + randi() % 11  # 15-25
    energy_reward = 10.0
    rotation_speed = 1.8
    float_amplitude = 0.3
    
    # Огненный цвет
    if mesh_instance and mesh_instance.material_override:
        mesh_instance.material_override.albedo_color = Color(1, 0.3, 0)
        mesh_instance.material_override.emission = Color(1, 0.3, 0)
    
    pass # print("FireballArtifact создан, ценность: " + str(artifact_value), "Artifact")


func _collect_hook(collector: Node):
    super._collect_hook(collector)
    
    # Поджигает сталкера (наносит урон огнем)
    if collector.has_method("take_damage"):
        collector.take_damage(5, self)
        pass # print("FireballArtifact: нанесён урон огнём 5", "Artifact")
    
    pass # print("FireballArtifact собран! Даёт +" + str(energy_reward) + " энергии", "Artifact")
