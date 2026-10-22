# entities/stalkers/behaviors/stealthy_behavior.gd
extends StalkerBehaviorStrategy
class_name StalkerBehaviorStealthy

## Скрытное поведение - избегает любых контактов


func evaluate(_state_machine) -> GameEnums.StalkerState:
    # 1. Если есть артефакт - несем его (быстро и скрытно)
    if stalker.has_artifact():
        return GameEnums.StalkerState.CARRY_ARTIFACT
    
    # 2. Проверка любых опасностей - немедленное бегство
    if stalker.memory_component:
        if stalker.memory_component.has_threats():
            return GameEnums.StalkerState.FLEE
        
        # 3. Если есть другие сталкеры - тоже избегаем
        if stalker.memory_component.known_stalkers.size() > 0:
            return GameEnums.StalkerState.FLEE
    
    # 4. Ищем артефакты (только если безопасно)
    if stalker.memory_component and stalker.memory_component.has_artifacts():
        return GameEnums.StalkerState.SEEK_ARTIFACT
    
    # 5. Осторожно идем к монолиту
    if stalker.monolith and _is_area_safe(stalker.monolith.global_position):
        return GameEnums.StalkerState.SEEK_MONOLITH
    
    return GameEnums.StalkerState.PATROL


func _is_area_safe(position: Vector3) -> bool:
    if not stalker.memory_component:
        return true
    
    var threats = stalker.memory_component.get_all_threats()
    for threat in threats:
        if not is_instance_valid(threat):
            continue
        if position.distance_to(threat.global_position) < 20.0:
            return false
    
    return true


func get_target_position() -> Vector3:
    if stalker.memory_component:
        # Если есть артефакты - идем к самому дальнему от опасностей
        if stalker.memory_component.has_artifacts():
            var best_artifact = null
            var best_score = -INF
            
            for artifact in stalker.memory_component.known_artifacts:
                if not is_instance_valid(artifact):
                    continue
                var score = _get_safety_score(artifact.global_position)
                if score > best_score:
                    best_score = score
                    best_artifact = artifact
            
            if best_artifact:
                return best_artifact.global_position
    
    if stalker.monolith and _is_area_safe(stalker.monolith.global_position):
        return stalker.monolith.global_position
    
    # Ищем безопасное направление
    return _get_safe_direction() * 30


func _get_safe_direction() -> Vector3:
    if not stalker.memory_component:
        return Vector3.FORWARD

    # Безопасность считает _get_safety_score() - список угроз берёт сам
    var best_dir = Vector3.FORWARD
    var best_score = -INF
    
    for angle in range(0, 360, 15):  # Более точный поиск
        var dir = Vector3(cos(deg_to_rad(angle)), 0, sin(deg_to_rad(angle)))
        var check_pos = stalker.global_position + dir * 20
        var score = _get_safety_score(check_pos)
        
        if score > best_score:
            best_score = score
            best_dir = dir
    
    return best_dir


func _get_safety_score(position: Vector3) -> float:
    if not stalker.memory_component:
        return 100.0
    
    var threats = stalker.memory_component.get_all_threats()
    var score = 100.0
    
    for threat in threats:
        if not is_instance_valid(threat):
            continue
        var dist = position.distance_to(threat.global_position)
        if dist < 30.0:
            # Чем ближе угроза, тем меньше очков
            score -= (30.0 - dist) * 5.0
    
    return score


func should_flee_from(threat: Node) -> bool:
    # Убегает от всего
    return threat != null


func should_attack(_threat: Node) -> bool:
    # Никогда не атакует
    return false


func prefers_artifacts() -> bool:
    return true
