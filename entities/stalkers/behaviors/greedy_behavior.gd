# entities/stalkers/behaviors/greedy_behavior.gd
extends StalkerBehaviorStrategy
class_name StalkerBehaviorGreedy

## Жадное поведение - приоритет на сбор артефактов


func evaluate(_state_machine) -> GameEnums.StalkerState:
	# 1. Если есть артефакт - несем его
	if stalker.has_artifact():
		return GameEnums.StalkerState.CARRY_ARTIFACT
	
	# 2. Проверка опасностей
	if stalker.memory_component and stalker.memory_component.has_threats():
		var nearest = stalker.memory_component.get_nearest_threat()
		if nearest and should_flee_from(nearest):
			return GameEnums.StalkerState.FLEE
	
	# 3. Ищем артефакты
	if stalker.memory_component and stalker.memory_component.has_artifacts():
		return GameEnums.StalkerState.SEEK_ARTIFACT
	
	# 4. Идем к монолиту
	return GameEnums.StalkerState.SEEK_MONOLITH


func get_target_position() -> Vector3:
	if stalker.memory_component:
		var artifact = stalker.memory_component.get_nearest_artifact()
		if artifact:
			return artifact.global_position
	
	if stalker.monolith:
		return stalker.monolith.global_position
	
	return Vector3.ZERO


func prefers_artifacts() -> bool:
	return true


func should_flee_from(threat: Node) -> bool:
	# Жадные сталкеры убегают только от очень опасных угроз
	if not threat:
		return false
	
	# Если здоровье критическое - убегаем от всего
	if stalker.health_component and stalker.health_component.is_critical():
		return true
	
	# От аномалий не убегаем, если рядом есть артефакт
	if threat.is_in_group("anomalies"):
		if stalker.memory_component and stalker.memory_component.has_artifacts():
			var artifact_dist = stalker.global_position.distance_to(
				stalker.memory_component.get_nearest_artifact().global_position
			)
			var threat_dist = stalker.global_position.distance_to(threat.global_position)
			
			# Если артефакт ближе угрозы - игнорируем угрозу
			if artifact_dist < threat_dist:
				return false
	
	return super.should_flee_from(threat)


func get_priority_for_target(target: Node) -> float:
	var priority = super.get_priority_for_target(target)
	
	# Артефакты имеют максимальный приоритет
	if target.is_in_group("artifacts"):
		priority *= 3.0
	
	return priority
