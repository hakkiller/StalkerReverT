# managers/particle_manager.gd
extends Node
class_name ParticleManager

## Менеджер частиц - управляет визуальными эффектами

signal particle_spawned(particle_type: String, position: Vector3)

# Предустановленные эффекты (можно настроить в редакторе)
@export var dust_particles: PackedScene
@export var spark_particles: PackedScene
@export var smoke_particles: PackedScene

# Пулы частиц
var _particle_pools: Dictionary = {}
@export var max_particles_per_type: int = 20
var _active_particles: Array[GPUParticles3D] = []


func _ready():
    add_to_group("particle_manager")
    _initialize_pools()
    pass # print("ParticleManager инициализирован", "ParticleManager")


func _initialize_pools():
    var particle_types = ["dust", "spark", "smoke"]
    
    for type in particle_types:
        _particle_pools[type] = []
        for i in range(max_particles_per_type):
            var particles = _create_particles_node(type)
            _particle_pools[type].append(particles)
            add_child(particles)
            particles.emitting = false


func _create_particles_node(particle_type: String) -> GPUParticles3D:
    var particles = GPUParticles3D.new()
    particles.name = "Particle_" + particle_type
    particles.amount = 20
    particles.lifetime = 2.0
    particles.explosiveness = 0.0
    particles.randomness = 0.3
    
    # Настраиваем процессный материал
    var material = ParticleProcessMaterial.new()
    material.direction = Vector3(0, 1, 0)
    material.spread = 45.0
    material.initial_velocity_min = 0.5
    material.initial_velocity_max = 1.5
    material.gravity = Vector3(0, -0.5, 0)
    material.scale_min = 0.1
    material.scale_max = 0.3
    
    match particle_type:
        "dust":
            material.color = Color(0.7, 0.6, 0.5, 0.5)
            material.initial_velocity_min = 0.3
            material.initial_velocity_max = 0.8
            particles.amount = 15
        "spark":
            material.color = Color(1.0, 0.8, 0.3, 0.8)
            material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
            material.emission_sphere_radius = 0.5
            material.initial_velocity_min = 2.0
            material.initial_velocity_max = 4.0
            material.gravity = Vector3(0, -2, 0)
            particles.amount = 30
            particles.lifetime = 0.5
        "smoke":
            material.color = Color(0.3, 0.3, 0.3, 0.4)
            material.initial_velocity_min = 0.2
            material.initial_velocity_max = 0.5
            material.scale_min = 0.5
            material.scale_max = 1.0
            particles.amount = 25
            particles.lifetime = 3.0
    
    particles.process_material = material
    
    # Простой квадратный меш
    var mesh = QuadMesh.new()
    mesh.size = Vector2(0.2, 0.2)
    var mat = StandardMaterial3D.new()
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    mat.albedo_color = material.color
    mesh.material = mat
    particles.draw_pass_1 = mesh
    
    return particles


# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================

func spawn_particles_at(position: Vector3, particle_type: String, duration: float = 2.0):
    if not _particle_pools.has(particle_type):
        pass # print("Неизвестный тип частиц: " + particle_type, "ParticleManager")
        return
    
    # Ищем свободные частицы
    var pool = _particle_pools[particle_type]
    var particles: GPUParticles3D = null
    
    for p in pool:
        if not p.emitting:
            particles = p
            break
    
    # Если все заняты, создаём новые
    if not particles:
        particles = _create_particles_node(particle_type)
        add_child(particles)
        pool.append(particles)
    
    # Запускаем
    particles.global_position = position
    particles.emitting = true
    
    # Останавливаем через duration
    if duration > 0:
        get_tree().create_timer(duration).timeout.connect(
            func(): _stop_particles(particles)
        )
    
    _active_particles.append(particles)
    particle_spawned.emit(particle_type, position)
    pass # print("Частицы " + particle_type + " созданы на " + str(position), "ParticleManager")


func spawn_dust_at(position: Vector3, intensity: float = 1.0):
    spawn_particles_at(position, "dust", 1.5 * intensity)


func spawn_sparks_at(position: Vector3):
    spawn_particles_at(position, "spark", 0.5)


func spawn_smoke_at(position: Vector3, duration: float = 3.0):
    spawn_particles_at(position, "smoke", duration)


func spawn_anomaly_effects(position: Vector3, anomaly_type: String):
    """Создаёт эффекты в зависимости от типа аномалии"""
    match anomaly_type:
        "electric_anomaly", "electric_tesla", "electric":
            spawn_sparks_at(position)
        "heat_anomaly", "thermal_steam", "thermal_comet", "heat":
            spawn_smoke_at(position, 2.0)
        "radiation_hotspot", "radiation":
            spawn_dust_at(position, 2.0)
        "gravity_vortex", "gravity_whirlwind", "gravity":
            spawn_dust_at(position, 2.0)
        _:
            spawn_dust_at(position)


func spawn_pulse_effect():
    # Эффект выброса - частицы по всей карте
    var camera = get_viewport().get_camera_3d()
    if camera:
        spawn_smoke_at(camera.global_position + Vector3(0, 5, 0), 5.0)
    pass # print("Эффект выброса создан", "ParticleManager")


func _stop_particles(particles: GPUParticles3D):
    if is_instance_valid(particles):
        particles.emitting = false
        if particles in _active_particles:
            _active_particles.erase(particles)


func clear_all_particles():
    for particles in _active_particles:
        if is_instance_valid(particles):
            particles.emitting = false
    _active_particles.clear()
    pass # print("Все частицы очищены", "ParticleManager")


func get_active_count() -> int:
    return _active_particles.size()
