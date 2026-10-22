# components/health_component.gd
extends Node
class_name HealthComponent

## Компонент здоровья - управляет HP, регенерацией, смертью

signal health_changed(current: float, max_health: float)
signal damaged(amount: float, source: Node, critical: bool)
signal died(source: Node)

# Владелец
var entity: Node

# Параметры
var max_health: float = 100.0:
    set(value):
        max_health = max(1.0, value)
        current_health = min(current_health, max_health)
        health_changed.emit(current_health, max_health)

var current_health: float = 100.0:
    set(value):
        var old_value = current_health
        current_health = clamp(value, 0.0, max_health)
        if current_health != old_value:
            health_changed.emit(current_health, max_health)

var armor: float = 0.0
var is_alive: bool = true

# Регенерация
var regen_rate: float = 0.0
var regen_delay: float = 5.0
var regen_timer: float = 0.0

# Неуязвимость
var is_invulnerable: bool = false
var invulnerability_timer: float = 0.0
var invulnerability_duration: float = 0.0

# Защита
var damage_reduction: float = 1.0
var last_damage_source: Node = null
var last_damage_time: float = 0.0


func _ready():
    # Загружаем параметры из владельца
    if entity:
        if "max_health" in entity:
            max_health = entity.max_health
        if "armor" in entity:
            armor = entity.armor
    
    current_health = max_health
    set_process(true)
    
    pass # print("HealthComponent инициализирован: HP=" + str(max_health) + " броня=" + str(armor), "HealthComponent")


func _process(delta):
    if not is_alive:
        return
    
    # Обновление неуязвимости
    if is_invulnerable:
        invulnerability_timer += delta
        if invulnerability_timer >= invulnerability_duration:
            is_invulnerable = false
            invulnerability_timer = 0.0
            pass # print("Неуязвимость закончилась", "HealthComponent")
    
    # Регенерация
    if regen_rate > 0 and is_alive and current_health < max_health:
        regen_timer += delta
        if regen_timer >= regen_delay:
            var heal_amount = regen_rate * delta
            current_health = min(current_health + heal_amount, max_health)
            pass # print("Регенерация: +" + str(heal_amount), "HealthComponent")


func take_damage(amount: float, source: Node = null) -> float:
    if not is_alive:
        pass # print("Попытка нанести урон мертвому entity", "HealthComponent")
        return 0.0
    
    if is_invulnerable:
        pass # print("Урон поглощен (неуязвимость)", "HealthComponent")
        return 0.0
    
    last_damage_time = Time.get_ticks_msec() / 1000.0
    last_damage_source = source
    
    # Расчет урона с учетом брони
    var mitigated_damage = max(1.0, amount - armor)
    var final_damage = mitigated_damage * damage_reduction
    
    current_health -= final_damage
    
    # Критичность урона (для визуальных эффектов)
    var is_critical_hit = final_damage > amount * 0.8
    damaged.emit(final_damage, source, is_critical_hit)
    
    # (лог отключён)
    
    if current_health <= 0:
        die(source)
        return final_damage
    
    return final_damage


func heal(amount: float) -> float:
    if not is_alive:
        return 0.0
    
    var old_health = current_health
    current_health = min(current_health + amount, max_health)
    var healed = current_health - old_health
    
    if healed > 0:
        pass # print("Вылечено: " + str(healed), "HealthComponent")
    
    return healed


func die(source: Node = null):
    if not is_alive:
        return
    
    is_alive = false
    current_health = 0.0
    died.emit(source)
    
    pass # print("Entity умер от " + str(source), "HealthComponent")


func set_invulnerable(duration: float):
    is_invulnerable = true
    invulnerability_duration = duration
    invulnerability_timer = 0.0
    pass # print("Неуязвимость активирована на " + str(duration) + "с", "HealthComponent")


func set_armor(value: float):
    armor = max(0.0, value)
    pass # print("Броня изменена на " + str(armor), "HealthComponent")


func set_regen(rate: float, delay: float = 5.0):
    regen_rate = max(0.0, rate)
    regen_delay = max(0.1, delay)
    pass # print("Регенерация установлена: " + str(rate) + "/с с задержкой " + str(delay) + "с", "HealthComponent")


func set_max_health(value: float, keep_percent: bool = false):
    var old_max = max_health
    max_health = max(1.0, value)
    
    if keep_percent:
        var percent = current_health / old_max
        current_health = max_health * percent
    else:
        current_health = min(current_health, max_health)
    
    pass # print("Макс. здоровье изменено: " + str(old_max) + " -> " + str(max_health), "HealthComponent")


func get_health() -> float:
    return current_health


func get_max_health() -> float:
    return max_health


func get_health_percent() -> float:
    return current_health / max_health if max_health > 0 else 0.0


func get_health_percent_str() -> String:
    return str(int(get_health_percent() * 100)) + "%"


func is_critical() -> bool:
    return get_health_percent() < 0.25


func is_injured() -> bool:
    return current_health < max_health


func is_full() -> bool:
    return current_health >= max_health


func get_missing_health() -> float:
    return max_health - current_health


func get_status() -> Dictionary:
    return {
        "current": current_health,
        "max": max_health,
        "percent": get_health_percent(),
        "armor": armor,
        "alive": is_alive,
        "regen": regen_rate,
        "invulnerable": is_invulnerable
    }
