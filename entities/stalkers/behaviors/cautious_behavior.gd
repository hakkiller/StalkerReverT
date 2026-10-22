# entities/stalkers/behaviors/cautious_behavior.gd
extends StalkerBehaviorStrategy
class_name StalkerBehaviorCautious

## Осторожное поведение - проверяет безопасность пути


func evaluate(_state_machine) -> GameEnums.StalkerState:
	# 1. Если есть артефакт - несем его
	if stalker.has_artifact():
		return GameEnums.StalkerState.CARRY_ARTIFACT
	
	# 2. Проверка опасностей - высший приоритет
	if stalker.memory_component and stalker.memory_component.has_threats():
		var nearest = stalker.memory_component.get_nearest_threat()
		if nearest and should_flee_from(nearest):
			return GameEnums.StalkerState.FLEE
	
	# 3. Проверяем безопасность пути к монолиту
	if stalker.monolith:
		if _is_path_to_monolith_safe():
			return GameEnums.StalkerState.SEEK_MONOLITH
		else:
			# Ищем обходной путь
			return GameEnums.StalkerState.PATROL
	
	return GameEnums.StalkerState.PATROL


func _is_path_to_monolith_safe() -> bool:
	if not stalker.monolith:
		return false
	
	# Проверяем наличие аномалий вокруг
	if stalker.memory_component and stalker.memory_component.has_anomalies():
		# Если есть аномалии рядом - путь небезопасен
		var nearest_threat = stalker.memory_component.get_nearest_threat()
		if nearest_threat:
			var dist_to_threat = stalker.global_position.distance_to(nearest_threat.global_position)
			if dist_to_threat < 20.0:
				return false
	
	return true


func get_target_position() -> Vector3:
	if stalker.monolith and _is_path_to_monolith_safe():
		return stalker.monolith.global_position
	
	# Возвращаем безопасное направление
	return _get_safe_direction() * 30


func _get_safe_direction() -> Vector3:
	if not stalker.memory_component or not stalker.memory_component.has_threats():
		return Vector3.FORWARD
	
	var threats = stalker.memory_component.get_all_threats()
	var best_dir = Vector3.FORWARD
	var best_score = -INF
	
	for angle in range(0, 360, 30):
		var dir = Vector3(cos(deg_to_rad(angle)), 0, sin(deg_to_rad(angle)))
		var score = 0.0
		
		for threat in threats:
			if not is_instance_valid(threat):
				continue
			var threat_dir = (threat.global_position - stalker.global_position).normalized()
			var dot = dir.dot(threat_dir)
			var dist = stalker.global_position.distance_to(threat.global_position)
			
			# Чем дальше от угрозы и чем меньше направление совпадает, тем лучше
			score += dist * (1.0 - max(0.0, dot))
		
		if score > best_score:
			best_score = score
			best_dir = dir
	
	return best_dir


func should_flee_from(threat: Node) -> bool:
	# Осторожные сталкеры убегают от любой опасности
	if not threat:
		return false
	
	var dist = stalker.global_position.distance_to(threat.global_position)
	var health_percent = stalker.health_component.get_health_percent() if stalker.health_component else 1.0
	
	# Убегаем, если:
	# 1. Угроза слишком близко
	# 2. Здоровье низкое
	# 3. Угроза - аномалия (всегда опасно)
	return dist < 15.0 or health_percent < 0.5 or threat.is_in_group("anomalies")


func prefers_artifacts() -> bool:
	# Артефакты важны, но безопасность важнее
	return true
