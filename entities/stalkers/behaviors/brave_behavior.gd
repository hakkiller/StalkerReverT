# entities/stalkers/behaviors/brave_behavior.gd
extends StalkerBehaviorStrategy
class_name StalkerBehaviorBrave

## Храброе поведение - всегда идет к монолиту, игнорируя опасности


func evaluate(_state_machine) -> GameEnums.StalkerState:
    # 1. Если есть артефакт - несем его (но можем игнорировать)
    if stalker.has_artifact():
        return GameEnums.StalkerState.CARRY_ARTIFACT
    
    # 2. Всегда идем к монолиту, независимо от опасностей
    if stalker.monolith:
        return GameEnums.StalkerState.SEEK_MONOLITH
    
    return GameEnums.StalkerState.PATROL


func get_target_position() -> Vector3:
    if stalker.monolith:
        return stalker.monolith.global_position
    return Vector3.ZERO


func should_flee_from(_threat: Node) -> bool:
    # Никогда не убегает
    return false


func should_attack(threat: Node) -> bool:
    # Атакует только если мешает идти к монолиту
    if not threat or not stalker.monolith:
        return false
    
    var threat_pos = threat.global_position
    var monolith_pos = stalker.monolith.global_position
    var stalker_pos = stalker.global_position
    
    # Проверяем, находится ли угроза на пути к монолиту
    var to_monolith = (monolith_pos - stalker_pos).normalized()
    var to_threat = (threat_pos - stalker_pos).normalized()
    
    var dot = to_monolith.dot(to_threat)
    var dist_to_threat = stalker_pos.distance_to(threat_pos)
    
    # Если угроза близко и примерно по направлению к монолиту - атакуем
    return dot > 0.7 and dist_to_threat < 15.0


func prefers_artifacts() -> bool:
    return false
