# entities/stalkers/behaviors/stalker_behavior.gd
class_name StalkerBehaviorStrategy
extends RefCounted

## Базовый класс стратегии поведения сталкера

var stalker: BaseStalker


func _init(stalker_node: BaseStalker):
    stalker = stalker_node


## Кеш скриптов поведения: раньше create() делал load() при каждом спавне.
static var _script_cache: Dictionary = {}


static func create(behavior_type: GameEnums.StalkerBehavior, stalker_node: BaseStalker) -> StalkerBehaviorStrategy:
        if _script_cache.is_empty():
                _script_cache = {
                        GameEnums.StalkerBehavior.GREEDY: load("res://entities/stalkers/behaviors/greedy_behavior.gd"),
                        GameEnums.StalkerBehavior.BRAVE: load("res://entities/stalkers/behaviors/brave_behavior.gd"),
                        GameEnums.StalkerBehavior.CAUTIOUS: load("res://entities/stalkers/behaviors/cautious_behavior.gd"),
                        GameEnums.StalkerBehavior.AGGRESSIVE: load("res://entities/stalkers/behaviors/aggressive_behavior.gd"),
                        GameEnums.StalkerBehavior.STEALTHY: load("res://entities/stalkers/behaviors/stealthy_behavior.gd"),
                }
        var script: GDScript = _script_cache.get(behavior_type)
        if script:
                return script.new(stalker_node)

        return StalkerBehaviorStrategy.new(stalker_node)


# Методы для оценки ситуации - переопределяются в наследниках
func evaluate(_state_machine) -> GameEnums.StalkerState:
    return GameEnums.StalkerState.PATROL


func get_target_position() -> Vector3:
    return Vector3.ZERO


func should_flee_from(threat: Node) -> bool:
    # По умолчанию: убегаем от опасных угроз
    if not threat:
        return false
    
    # Проверяем тип угрозы
    if threat.is_in_group("anomalies"):
        # От аномалий убегаем, если здоровье низкое
        if stalker.health_component and stalker.health_component.is_critical():
            return true
    
    return false


func should_attack(threat: Node) -> bool:
    # По умолчанию атакуем мутантов и аномалии, вставшие на путь к монолиту
    if not threat:
        return false
    return threat.is_in_group("mutants") or threat.is_in_group("anomalies")


func prefers_artifacts() -> bool:
    return false


func get_priority_for_target(target: Node) -> float:
    # Возвращает приоритет цели (чем выше, тем важнее)
    if not target:
        return 0.0
    
    var dist = stalker.global_position.distance_to(target.global_position)
    var base_priority = 100.0 / (dist + 1.0)
    
    if target.is_in_group("artifacts"):
        return base_priority * (2.0 if prefers_artifacts() else 1.0)
    elif target.is_in_group("mutants"):
        return base_priority * (1.5 if should_attack(target) else 0.5)
    elif target.is_in_group("anomalies"):
        return base_priority * 0.3
    
    return base_priority
