# res://zones/monolith/monolith.gd
extends Node3D
class_name Monolith

## Центр игры. Сталкеры пытаются его коснуться (GAME OVER)
## Источник энергии и прогрессии

signal energy_changed(current: float, max_energy: float)
signal game_over

# Радиусы защиты (настраиваются в редакторе)
@export var inner_radius: float = 20.0      # 0-20м: уровень 3 аномалии (сильные)
@export var middle_radius: float = 40.0     # 20-40м: уровень 2 аномалии
@export var outer_radius: float = 60.0      # 40-60м: уровень 1 аномалии
@export var spawn_radius: float = 80.0      # >60м: спавн сталкеров

# Базовые параметры
@export var base_energy: float = 500.0
@export var energy_regen_rate: float = 1.0
@export var current_level: int = 1

# Текущее состояние
var current_energy: float
var radiation_pulse_count: int = 0
var is_radiating: bool = false
var run_number: int = 1

# Визуал
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var point_light: OmniLight3D = $OmniLight3D
@onready var label: Label3D = $Label3D


func _ready():
    # Добавляем в группу для поиска из других скриптов
    add_to_group("monolith")
    
    current_energy = get_max_energy()
    
    # Визуальная инициализация
    if label:
        label.text = "Монолит\nУровень " + str(current_level)
    
    pass # print("🔮 Monolith: инициализирован на уровне ", current_level)


func get_max_energy() -> float:
    """Максимальная энергия растёт с уровнем и номером забега"""
    return base_energy + (current_level * 100.0) + ((run_number - 1) * 100.0)


func spend_energy(amount: float) -> bool:
    """Трата энергии на создание артефактов"""
    if current_energy >= amount:
        current_energy -= amount
        energy_changed.emit(current_energy, get_max_energy())
        return true
    return false


func add_energy(amount: float):
    """Добавление энергии (регенерация)"""
    current_energy = min(current_energy + amount, get_max_energy())
    energy_changed.emit(current_energy, get_max_energy())


func _process(delta):
    if not is_radiating:
        add_energy(energy_regen_rate * delta)
    
    # Анимация свечения
    if point_light:
        var pulse = sin(Time.get_ticks_msec() * 0.003) * 0.3 + 0.7
        point_light.light_energy = pulse * 2.0


func check_stalker_touch(stalker: Node3D):
    """Проверка касания сталкера"""
    if global_position.distance_to(stalker.global_position) < 5.0:
        game_over.emit()
        get_tree().paused = true
        pass # print("💀 GAME OVER - Сталкер коснулся Монолита!")


func get_inner_radius() -> float:
    return inner_radius


func get_middle_radius() -> float:
    return middle_radius


func get_outer_radius() -> float:
    return outer_radius


func get_spawn_radius() -> float:
    return spawn_radius
