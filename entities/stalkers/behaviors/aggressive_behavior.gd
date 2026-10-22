# entities/stalkers/behaviors/aggressive_behavior.gd
extends StalkerBehaviorStrategy
class_name StalkerBehaviorAggressive

## Агрессивное поведение - атакует мутантов в первую очередь


func evaluate(_state_machine) -> GameEnums.StalkerState:
    # 1. Если есть артефакт - несем его
    if stalker.has_artifact():
        return GameEnums.StalkerState.CARRY_ARTIFACT
    
    # 2. Атакуем мутантов в приоритете
    if stalker.memory_component and stalker.memory_component.has_mutants():
        return GameEnums.StalkerState.ATTACK_MUTANT
    
    # 3. Проверка других опасностей
    if stalker.memory_component and stalker.memory_component.has_anomalies():
        var nearest = stalker.memory_component.get_nearest_threat()
        if nearest and should_flee_from(nearest):
            return GameEnums.StalkerState.FLEE
    
    # 4. Ищем артефакты
    if stalker.memory_component and stalker.memory_component.has_artifacts():
        return GameEnums.StalkerState.SEEK_ARTIFACT
    
    # 5. Идем к монолиту
    return GameEnums.StalkerState.SEEK_MONOLITH


func get_target_position() -> Vector3:
    if stalker.memory_component:
        # Сначала мутанты
        var mutant = stalker.memory_component.get_nearest_mutant()
        if mutant:
            return mutant.global_position
        
        # Потом артефакты
        var artifact = stalker.memory_component.get_nearest_artifact()
        if artifact:
            return artifact.global_position
    
    if stalker.monolith:
        return stalker.monolith.global_position
    
    return Vector3.ZERO


func should_attack(threat: Node) -> bool:
    # Атакует все, что движется
    if not threat:
        return false
    
    # Приоритет - мутанты
    if threat.is_in_group("mutants"):
        return true
    
    # Аномалии атакует, если здоровье хорошее
    if threat.is_in_group("anomalies"):
        if stalker.health_component and stalker.health_component.get_health_percent() > 0.7:
            return true
    
    return false


func should_flee_from(threat: Node) -> bool:
    # Никогда не убегает от мутантов
    if threat.is_in_group("mutants"):
        return false
    
    # От аномалий убегает только при критическом здоровье
    if threat.is_in_group("anomalies"):
        if stalker.health_component and stalker.health_component.is_critical():
            return true
    
    return false


func prefers_artifacts() -> bool:
    return true


func get_priority_for_target(target: Node) -> float:
    var priority = super.get_priority_for_target(target)
    
    # Мутанты имеют наивысший приоритет
    if target.is_in_group("mutants"):
        priority *= 5.0
    # Артефакты тоже важны
    elif target.is_in_group("artifacts"):
        priority *= 2.0
    
    return priority
