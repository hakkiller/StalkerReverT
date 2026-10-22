# components/memory_component.gd
extends Node
class_name MemoryComponent

## Компонент памяти - хранит информацию об окружении

signal threat_detected(threat: Node, type: String)
signal threat_lost(threat: Node)
signal artifact_detected(artifact: Node)
signal artifact_lost(artifact: Node)
signal memory_cleared

# Владелец
var stalker: BaseStalker

# Известные объекты
var known_anomalies: Array[Node] = []
var known_mutants: Array[Node] = []
var known_artifacts: Array[Node] = []
var known_stalkers: Array[Node] = []

# Параметры
var vision_range: float = 30.0:
	set(value):
		vision_range = max(1.0, value)
		# print("Дальность зрения изменена на " + str(vision_range))

var update_interval: float = 1.0
var memory_duration: float = 10.0
var max_memory_size: int = 50

# Внутреннее состояние
var time_since_update: float = 0.0
var object_timers: Dictionary = {}  # instance_id -> time_seen


func _ready():
	set_process(true)
	# print("MemoryComponent инициализирован с дальностью " + str(vision_range))


func _process(delta):
	if not stalker or not is_instance_valid(stalker):
		return
	
	time_since_update += delta
	if time_since_update >= update_interval:
		time_since_update = 0.0
		_refresh_memory()


func _refresh_memory():
	var tree = stalker.get_tree()
	if not tree:
		return
	
	var pos = stalker.global_position
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Очищаем невалидные объекты
	_clean_invalid_objects(current_time)
	
	# Сканируем окружение
	_scan_for_anomalies(tree, pos, current_time)
	_scan_for_mutants(tree, pos, current_time)
	_scan_for_artifacts(tree, pos, current_time)
	_scan_for_stalkers(tree, pos, current_time)


func _clean_invalid_objects(current_time: float):
	# Освобождённые объекты нельзя передавать в erase() типизированного массива,
	# поэтому списки пересобираются фильтрацией, а не чистятся по одному
	var kept: Array[Node] = []
	
	# Аномалии
	for a in known_anomalies:
		if not is_instance_valid(a):
			continue
		var id = a.get_instance_id()
		if object_timers.has(id) and current_time - object_timers[id] > memory_duration:
			threat_lost.emit(a)
			object_timers.erase(id)
			continue
		kept.append(a)
	known_anomalies = kept
	
	# Мутанты
	kept = []
	for m in known_mutants:
		if not is_instance_valid(m):
			continue
		var id = m.get_instance_id()
		if object_timers.has(id) and current_time - object_timers[id] > memory_duration:
			threat_lost.emit(m)
			object_timers.erase(id)
			continue
		kept.append(m)
	known_mutants = kept
	
	# Артефакты
	kept = []
	for a in known_artifacts:
		if not is_instance_valid(a):
			continue
		var id = a.get_instance_id()
		var is_collected = a.get("is_collected") if "is_collected" in a else false
		if is_collected:
			artifact_lost.emit(a)
			object_timers.erase(id)
			continue
		if object_timers.has(id) and current_time - object_timers[id] > memory_duration:
			artifact_lost.emit(a)
			object_timers.erase(id)
			continue
		kept.append(a)
	known_artifacts = kept
	
	# Сталкеры
	kept = []
	for sk in known_stalkers:
		if not is_instance_valid(sk) or sk == stalker:
			continue
		var id = sk.get_instance_id()
		if object_timers.has(id) and current_time - object_timers[id] > memory_duration:
			object_timers.erase(id)
			continue
		kept.append(sk)
	known_stalkers = kept


func _scan_for_anomalies(tree: SceneTree, pos: Vector3, current_time: float):
	var anomalies = tree.get_nodes_in_group("anomalies")
	for a in anomalies:
		if not is_instance_valid(a):
			continue
		
		var dist = pos.distance_to(a.global_position)
		if dist <= vision_range:
			var id = a.get_instance_id()
			if not object_timers.has(id):
				known_anomalies.append(a)
				threat_detected.emit(a, "anomaly")
				# print("Обнаружена аномалия на расстоянии " + str(dist))
			object_timers[id] = current_time


func _scan_for_mutants(tree: SceneTree, pos: Vector3, current_time: float):
	var mutants = tree.get_nodes_in_group("mutants")
	for m in mutants:
		if not is_instance_valid(m):
			continue
		
		var dist = pos.distance_to(m.global_position)
		if dist <= vision_range:
			var id = m.get_instance_id()
			if not object_timers.has(id):
				known_mutants.append(m)
				threat_detected.emit(m, "mutant")
				# print("Обнаружен мутант на расстоянии " + str(dist))
			object_timers[id] = current_time


func _scan_for_artifacts(tree: SceneTree, pos: Vector3, current_time: float):
	var artifacts = tree.get_nodes_in_group("artifacts")
	for a in artifacts:
		if not is_instance_valid(a):
			continue
		
		var is_collected = a.get("is_collected") if "is_collected" in a else false
		if is_collected:
			continue
		
		var dist = pos.distance_to(a.global_position)
		if dist <= vision_range:
			var id = a.get_instance_id()
			if not object_timers.has(id):
				known_artifacts.append(a)
				artifact_detected.emit(a)
				# print("Обнаружен артефакт на расстоянии " + str(dist))
			object_timers[id] = current_time


func _scan_for_stalkers(tree: SceneTree, pos: Vector3, current_time: float):
	var stalkers = tree.get_nodes_in_group("stalkers")
	for s in stalkers:
		if not is_instance_valid(s) or s == stalker:
			continue
		
		var dist = pos.distance_to(s.global_position)
		if dist <= vision_range:
			var id = s.get_instance_id()
			if not object_timers.has(id):
				known_stalkers.append(s)
				# print("Обнаружен другой сталкер на расстоянии " + str(dist))
			object_timers[id] = current_time


# ==================== ПУБЛИЧНОЕ API ====================

func get_nearest_threat() -> Node:
	var nearest = null
	var min_dist = INF
	var pos = stalker.global_position
	
	for a in known_anomalies:
		if not is_instance_valid(a):
			continue
		var dist = pos.distance_to(a.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = a
	
	for m in known_mutants:
		if not is_instance_valid(m):
			continue
		var dist = pos.distance_to(m.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = m
	
	return nearest


func get_nearest_anomaly() -> Node:
	var nearest = null
	var min_dist = INF
	var pos = stalker.global_position
	
	for a in known_anomalies:
		if not is_instance_valid(a):
			continue
		var dist = pos.distance_to(a.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = a
	
	return nearest


func get_nearest_mutant() -> Node:
	var nearest = null
	var min_dist = INF
	var pos = stalker.global_position
	
	for m in known_mutants:
		if not is_instance_valid(m):
			continue
		var dist = pos.distance_to(m.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = m
	
	return nearest


func get_nearest_artifact() -> Node:
	var nearest = null
	var min_dist = INF
	var pos = stalker.global_position
	
	for a in known_artifacts:
		if not is_instance_valid(a):
			continue
		var dist = pos.distance_to(a.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = a
	
	return nearest


func get_all_threats() -> Array[Node]:
	var result = []
	for a in known_anomalies:
		if is_instance_valid(a):
			result.append(a)
	for m in known_mutants:
		if is_instance_valid(m):
			result.append(m)
	return result


func get_all_artifacts() -> Array[Node]:
	var result = []
	for a in known_artifacts:
		if is_instance_valid(a):
			result.append(a)
	return result


func get_all_mutants() -> Array[Node]:
	var result = []
	for m in known_mutants:
		if is_instance_valid(m):
			result.append(m)
	return result


func get_all_anomalies() -> Array[Node]:
	var result = []
	for a in known_anomalies:
		if is_instance_valid(a):
			result.append(a)
	return result


func get_threat_count() -> int:
	var count = 0
	for a in known_anomalies:
		if is_instance_valid(a):
			count += 1
	for m in known_mutants:
		if is_instance_valid(m):
			count += 1
	return count


func get_artifact_count() -> int:
	var count = 0
	for a in known_artifacts:
		if is_instance_valid(a):
			count += 1
	return count


func get_mutant_count() -> int:
	var count = 0
	for m in known_mutants:
		if is_instance_valid(m):
			count += 1
	return count


func get_anomaly_count() -> int:
	var count = 0
	for a in known_anomalies:
		if is_instance_valid(a):
			count += 1
	return count


func has_artifacts() -> bool:
	for a in known_artifacts:
		if is_instance_valid(a):
			return true
	return false


func has_mutants() -> bool:
	for m in known_mutants:
		if is_instance_valid(m):
			return true
	return false


func has_anomalies() -> bool:
	for a in known_anomalies:
		if is_instance_valid(a):
			return true
	return false


func has_threats() -> bool:
	return has_anomalies() or has_mutants()


func is_known(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	var id = node.get_instance_id()
	return object_timers.has(id)


func get_memory_age(node: Node) -> float:
	if not is_instance_valid(node):
		return INF
	var id = node.get_instance_id()
	if object_timers.has(id):
		return (Time.get_ticks_msec() / 1000.0) - object_timers[id]
	return INF


func clear_memory():
	known_anomalies.clear()
	known_mutants.clear()
	known_artifacts.clear()
	known_stalkers.clear()
	object_timers.clear()
	memory_cleared.emit()
	# print("Память очищена")


func set_vision_range(range_val: float):
	vision_range = max(1.0, range_val)


func get_vision_range() -> float:
	return vision_range


func get_memory_size() -> int:
	return known_anomalies.size() + known_mutants.size() + known_artifacts.size() + known_stalkers.size()


func get_memory_stats() -> Dictionary:
	return {
		"anomalies": get_anomaly_count(),
		"mutants": get_mutant_count(),
		"artifacts": get_artifact_count(),
		"stalkers": known_stalkers.size(),
		"total": get_memory_size()
	}
