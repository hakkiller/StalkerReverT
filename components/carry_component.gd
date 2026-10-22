# components/carry_component.gd
extends Node
class_name CarryComponent

## Компонент переноски - управляет артефактами у сталкеров

signal artifact_picked_up(artifact: Node)
signal artifact_dropped(artifact: Node)
signal artifact_stolen(artifact: Node)
signal carry_state_changed(is_carrying: bool)

# Владелец
var stalker: BaseStalker

# Переносимый артефакт
var carried_artifact: Node = null
var is_carrying: bool = false:
    set(value):
        if is_carrying != value:
            is_carrying = value
            carry_state_changed.emit(is_carrying)

# Параметры
var drop_on_damage_chance: float = 0.3
var drop_on_death: bool = true
var max_carry_weight: float = 10.0


func _ready():
    pass # (лог отключён)


func pick_up_artifact(artifact: Node) -> bool:
    if is_carrying:
        pass # (лог отключён)
        return false
    
    if not is_instance_valid(artifact):
        pass # (лог отключён)
        return false
    
    # Проверяем, что это артефакт
    if not artifact.has_method("collect"):
        pass # (лог отключён)
        return false
    
    # Подбираем
    carried_artifact = artifact
    is_carrying = true
    
    # Скрываем визуально
    artifact.visible = false
    
    # Сохраняем позицию для возможного возврата
    artifact.set_meta("pickup_position", artifact.global_position)
    
    # Перемещаем в сталкера
    if stalker and stalker.has_method("add_child"):
        artifact.reparent(stalker)
        artifact.position = Vector3(0, 1.5, 0)
    
    artifact_picked_up.emit(artifact)
    pass # (лог отключён)
    
    return true


func drop_artifact() -> bool:
    if not is_carrying or not is_instance_valid(carried_artifact):
        return false
    
    # Возвращаем в мир
    var world_pos = stalker.global_position + Vector3(0, 1, 0)
    
    # Проверяем коллизию
    var space = stalker.get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.new()
    query.from = world_pos + Vector3(0, 2, 0)
    query.to = world_pos - Vector3(0, 2, 0)
    query.collision_mask = 1
    
    var result = space.intersect_ray(query)
    if result:
        world_pos = result.position + Vector3(0, 0.5, 0)
    
    carried_artifact.reparent(stalker.get_tree().current_scene)
    carried_artifact.global_position = world_pos
    carried_artifact.visible = true
    
    # Сбрасываем состояние
    if carried_artifact.has_method("set_collected"):
        carried_artifact.set_collected(false)
    
    artifact_dropped.emit(carried_artifact)
    pass # (лог отключён)
    
    carried_artifact = null
    is_carrying = false
    
    return true


func steal_artifact() -> bool:
    if not is_carrying or not is_instance_valid(carried_artifact):
        return false
    
    # "Кража" - артефакт исчезает (уносится за пределы карты)
    artifact_stolen.emit(carried_artifact)
    
    carried_artifact.queue_free()
    carried_artifact = null
    is_carrying = false
    
    return true


func try_drop_on_damage() -> bool:
    if not is_carrying:
        return false
    
    if randf() < drop_on_damage_chance:
        return drop_artifact()
    
    return false


func has_artifact() -> bool:
    return is_carrying and is_instance_valid(carried_artifact)


func get_artifact_value() -> int:
    if not has_artifact() or not carried_artifact.has_method("get_value"):
        return 0
    return carried_artifact.get_value()


func get_artifact_rarity() -> String:
    if not has_artifact() or not carried_artifact.has_method("get_rarity_name"):
        return "common"
    return carried_artifact.get_rarity_name()


func get_artifact_type() -> String:
    if not has_artifact():
        return ""
    return carried_artifact.name


func get_artifact() -> Node:
    return carried_artifact


func get_carry_weight() -> float:
    if not has_artifact():
        return 0.0
    
    return float(get_artifact_value()) / 10.0  # Пример: 10 единиц ценности = 1 вес


func can_pick_up(artifact: Node) -> bool:
    if is_carrying:
        return false
    
    if not artifact.has_method("get_value"):
        return false
    
    var weight = artifact.get_value() / 10.0
    return weight <= max_carry_weight


func get_status() -> Dictionary:
    return {
        "is_carrying": is_carrying,
        "has_artifact": has_artifact(),
        "artifact_value": get_artifact_value() if has_artifact() else 0,
        "artifact_rarity": get_artifact_rarity() if has_artifact() else "",
        "carry_weight": get_carry_weight(),
        "max_weight": max_carry_weight
    }
