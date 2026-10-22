# entities/base/collectible.gd
extends Node3D
class_name Collectible

## Интерфейс для собираемых объектов (артефакты, ресурсы)

signal collected(collector: Node, value: int)
signal expired(collectible: Collectible)

# Параметры
@export var collectible_name: String = "Collectible"
@export var value: int = 10
@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
@export var lifespan: float = 0.0  # 0 = бесконечно

# Состояние
var is_collected: bool = false
var spawn_time: float = 0.0
var collection_cooldown: float = 0.5  # Защита от множественного сбора


func _ready():
    add_to_group("collectibles")
    spawn_time = Time.get_ticks_msec() / 1000.0
    
    if lifespan > 0:
        _start_lifetime_timer()
    
    _ready_hook()
    pass # print("Collectible создан: " + collectible_name + " ценность: " + str(value), "Collectible")


func _ready_hook():
    """Для переопределения в наследниках"""
    pass


func _start_lifetime_timer():
    var timer = Timer.new()
    timer.wait_time = lifespan
    timer.one_shot = true
    timer.timeout.connect(_on_lifetime_expired)
    add_child(timer)
    timer.start()
    pass # print("Таймер жизни запущен: " + str(lifespan) + "с", "Collectible")


func _on_lifetime_expired():
    if not is_collected and is_instance_valid(self):
        expired.emit(self)
        pass # print("Collectible истек: " + collectible_name, "Collectible")
        queue_free()


# ==================== ПУБЛИЧНОЕ API ====================

func get_value() -> int:
    return value


func get_rarity() -> GameEnums.Rarity:
    return rarity


func get_rarity_name() -> String:
    return GameEnums.Rarity.keys()[rarity].to_lower()


func collect(collector: Node) -> bool:
    if is_collected:
        pass # print("Попытка собрать уже собранный collectible", "Collectible")
        return false
    
    # Защита от множественного сбора
    if Time.get_ticks_msec() / 1000.0 - spawn_time < collection_cooldown:
        pass # print("Слишком рано для сбора", "Collectible")
        return false
    
    is_collected = true
    
    # Хук для эффектов
    _collect_hook(collector)
    
    collected.emit(collector, value)
    pass # print("Collectible собран: " + collectible_name + " ценность: " + str(value), "Collectible")
    
    # Эффект сбора
    _spawn_collect_effect()
    
    queue_free()
    return true


func _collect_hook(_collector: Node):
    """Для переопределения в наследниках"""
    pass


func _spawn_collect_effect():
    """Эффект при сборе"""
    # Создаем простой эффект частиц
    if has_node("GPUParticles3D"):
        var particles = $GPUParticles3D
        particles.emitting = true
        await get_tree().create_timer(particles.lifetime).timeout


func get_age() -> float:
    return (Time.get_ticks_msec() / 1000.0) - spawn_time


func get_lifetime_remaining() -> float:
    if lifespan <= 0:
        return INF
    return max(0.0, lifespan - get_age())


func get_info() -> Dictionary:
    return {
        "name": collectible_name,
        "value": value,
        "rarity": get_rarity_name(),
        "age": get_age(),
        "lifetime": lifespan,
        "remaining": get_lifetime_remaining()
    }
