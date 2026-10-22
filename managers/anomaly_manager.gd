# managers/anomaly_manager.gd
extends Node
class_name AnomalyManager

## Менеджер аномалий - создание, уничтожение, связь с артефактами

signal anomaly_created(anomaly: Node, anomaly_type: String, difficulty: int)
signal anomaly_destroyed(anomaly_type: String, position: Vector3, difficulty: int)
signal artifact_created(artifact: Node, artifact_type: String, position: Vector3)
signal artifact_stolen(artifact: Node, stalker: Node)

# Сцены аномалий (загружаются из конфига)
var anomaly_scenes: Dictionary = {}

# Маппинг аномалия -> артефакт
var anomaly_artifact_map: Dictionary = {}

# Ценности артефактов по редкости
var artifact_values: Dictionary = {}

# Маппинг сложности -> редкость
var difficulty_to_rarity: Dictionary = {}

# Активные объекты
var active_anomalies: Array[Node] = []
var active_artifacts: Array[Node] = []

# Таймеры для артефактов
var artifact_timers: Dictionary = {}  # artifact_instance_id -> Timer

# Множители из лаборатории
var damage_multiplier: float = 1.0
var radius_multiplier: float = 1.0


func _ready():
	add_to_group("anomaly_manager")
	
	# Заполняем сцены аномалий
	anomaly_scenes = {
		"heat_anomaly": preload("res://anomalies/heat_anomaly.tscn"),
		"electric_anomaly": preload("res://anomalies/electric_anomaly.tscn"),
		"acid_anomaly": preload("res://anomalies/acid_anomaly.tscn"),
		"gravity_vortex": preload("res://anomalies/gravity_vortex.tscn"),
		"gravity_lift": preload("res://anomalies/gravity_lift.tscn"),
		"gravity_whirlwind": preload("res://anomalies/gravity_whirlwind.tscn"),
		"thermal_steam": preload("res://anomalies/thermal_steam.tscn"),
		"thermal_comet": preload("res://anomalies/thermal_comet.tscn"),
		"chemical_jelly": preload("res://anomalies/chemical_jelly.tscn"),
		"chemical_gas": preload("res://anomalies/chemical_gas.tscn"),
		"chemical_acid_cloud": preload("res://anomalies/chemical_acid_cloud.tscn"),
		"radiation_hotspot": preload("res://anomalies/radiation_hotspot.tscn"),
		"time_dilation": preload("res://anomalies/time_dilation.tscn"),
		"teleport": preload("res://anomalies/teleport.tscn"),
		"electric_tesla": preload("res://anomalies/electric_tesla.tscn"),
		"bio_burning_fluff": preload("res://anomalies/bio_burning_fluff.tscn")
	}
	
	# print("AnomalyManager инициализирован")


# ==================== АНОМАЛИИ ====================

func create_anomaly(anomaly_type: String, position: Vector3, difficulty: int, _energy_cost: float) -> Node:
	if not anomaly_scenes.has(anomaly_type):
		# print("Неизвестный тип аномалии: " + anomaly_type)
		return null
	
	var scene = anomaly_scenes[anomaly_type]
	var anomaly = scene.instantiate()
	
	# Проекция на рельеф: аномалия всегда стоит на земле, а не в воздухе
	var space = get_viewport().get_world_3d().direct_space_state
	var ray = PhysicsRayQueryParameters3D.new()
	ray.from = Vector3(position.x, position.y + 40.0, position.z)
	ray.to = Vector3(position.x, position.y - 60.0, position.z)
	ray.collision_mask = 1
	var hit = space.intersect_ray(ray)
	position.y = hit.position.y if hit else 0.0
	anomaly.position = position
	
	# Применяем множители из лаборатории
	if anomaly.has_method("set_damage_multiplier"):
		anomaly.set_damage_multiplier(damage_multiplier)
	if anomaly.has_method("set_radius_multiplier"):
		anomaly.set_radius_multiplier(radius_multiplier)
	
	# Подключаем сигнал уничтожения
	if anomaly.has_signal("destroyed"):
		anomaly.destroyed.connect(_on_anomaly_destroyed)
	
	anomaly.add_to_group("anomalies")
	get_tree().current_scene.add_child(anomaly)
	
	# Сложность задаем ПОСЛЕ add_child: _ready() подклассов сбрасывает
	# difficulty_level на 1 (аналогично артефактам)
	if anomaly.has_method("set_difficulty"):
		anomaly.set_difficulty(difficulty)
	
	active_anomalies.append(anomaly)
	
	anomaly_created.emit(anomaly, anomaly_type, difficulty)
	# print("Аномалия создана: " + anomaly_type + " на позиции " + str(position))
	
	return anomaly


func remove_anomaly(anomaly: Node):
	if is_instance_valid(anomaly):
		active_anomalies.erase(anomaly)
		anomaly.queue_free()
	# print("Аномалия удалена")


func get_active_anomalies() -> Array[Node]:
	return active_anomalies.filter(func(a): return is_instance_valid(a))


func get_anomaly_count() -> int:
	return active_anomalies.size()


func get_anomaly_cost(anomaly_type: String) -> float:
	match anomaly_type:
		"heat_anomaly": return 50.0
		"electric_anomaly": return 75.0
		"acid_anomaly": return 100.0
		"gravity_vortex": return 150.0
		"gravity_lift": return 80.0
		"gravity_whirlwind": return 120.0
		"thermal_steam": return 70.0
		"thermal_comet": return 100.0
		"chemical_jelly": return 60.0
		"chemical_gas": return 85.0
		"chemical_acid_cloud": return 110.0
		"radiation_hotspot": return 95.0
		"time_dilation": return 200.0
		"teleport": return 180.0
		"electric_tesla": return 90.0
		"bio_burning_fluff": return 75.0
		_: return 50.0


func _on_anomaly_destroyed(anomaly: Node):
	# Получаем информацию
	var anomaly_type = "unknown"
	var difficulty = 1
	var position = anomaly.global_position
	
	if anomaly.has_method("get_type_name"):
		anomaly_type = anomaly.get_type_name()
	if anomaly.has_method("get_difficulty"):
		difficulty = anomaly.get_difficulty()
	
	# Удаляем из списка
	active_anomalies.erase(anomaly)
	
	# Создаём артефакт
	var artifact_type = anomaly_artifact_map.get(anomaly_type, "common_artifact")
	var rarity = difficulty_to_rarity.get(difficulty, "common")
	var values = artifact_values.get(rarity, [10])
	var value = values[randi() % values.size()]
	
	create_artifact(artifact_type, position, rarity, value)
	
	anomaly_destroyed.emit(anomaly_type, position, difficulty)
	# print("Аномалия уничтожена, создан артефакт: " + artifact_type)


# ==================== АРТЕФАКТЫ ====================

func create_artifact(artifact_type: String, position: Vector3, rarity: String = "common", value: float = 10.0) -> Node:
	# Пробуем загрузить сцену
	var scene_path = "res://entities/artifacts/" + artifact_type + ".tscn"
	if not ResourceLoader.exists(scene_path):
		# print("Сцена артефакта не найдена: " + scene_path)
		return null
	
	var scene = load(scene_path)
	var artifact = scene.instantiate()
	artifact.position = position
	
	# Подключаем сигналы
	if artifact.has_signal("stolen"):
		artifact.stolen.connect(_on_artifact_stolen)
	if artifact.has_signal("collected"):
		artifact.collected.connect(_on_artifact_collected)
	
	artifact.add_to_group("artifacts")
	get_tree().current_scene.add_child(artifact)
	
	# Редкость и ценность задаём ПОСЛЕ add_child: _ready() артефакта
	# перетирает их экспортными значениями по умолчанию
	if artifact.has_method("set_rarity_and_value"):
		artifact.set_rarity_and_value(rarity, value)
	
	active_artifacts.append(artifact)
	
	# Запускаем таймер для артефактов на земле
	_start_artifact_timer(artifact)
	
	artifact_created.emit(artifact, artifact_type, position)
	# print("Артефакт создан: " + artifact_type + " на позиции " + str(position))
	
	return artifact


func _on_artifact_stolen(artifact: Node, stalker: Node):
	# Останавливаем таймер
	_stop_artifact_timer(artifact)
	
	artifact_stolen.emit(artifact, stalker)
	# print("Артефакт украден сталкером: " + str(stalker))


func _on_artifact_collected(artifact: Node, _collector: Node):
	if artifact in active_artifacts:
		active_artifacts.erase(artifact)
	_stop_artifact_timer(artifact)
	# print("Артефакт собран: " + str(collector))


func _start_artifact_timer(artifact: Node):
	var id = artifact.get_instance_id()
	if artifact_timers.has(id):
		return
	
	var timer = Timer.new()
	timer.wait_time = 30.0  # 30 секунд до превращения
	timer.one_shot = true
	timer.timeout.connect(_on_artifact_timeout.bind(artifact, id))
	add_child(timer)
	timer.start()
	
	artifact_timers[id] = timer
	# print("Таймер артефакта запущен на 30с")


func _stop_artifact_timer(artifact: Node):
	var id = artifact.get_instance_id()
	if artifact_timers.has(id):
		var timer = artifact_timers[id]
		if is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
		artifact_timers.erase(id)


func _on_artifact_timeout(artifact: Node, timer_id: int):
	# Таймер одноразовый: запись в artifact_timers больше не нужна
	artifact_timers.erase(timer_id)
	
	if not is_instance_valid(artifact):
		return
	
	# Артефакт пролежал на земле 30 секунд - кристаллизуется в аномалию
	# (закрытый TODO ZCode: раньше артефакт просто исчезал)
	var pos: Vector3 = artifact.global_position
	var scene_name: String = String(artifact.scene_file_path.get_file().get_basename())
	
	# Удаляем артефакт
	active_artifacts.erase(artifact)
	_stop_artifact_timer(artifact)
	artifact.queue_free()
	
	# Ищем аномалию-хозяина по обратной карте аномалия -> артефакт
	var anomaly_type: String = ""
	for a_type in anomaly_artifact_map:
		if String(anomaly_artifact_map[a_type]) == scene_name:
			anomaly_type = String(a_type)
			break
	
	if not anomaly_type.is_empty() and anomaly_scenes.has(anomaly_type):
		create_anomaly(anomaly_type, pos, 1, 0.0)
	# print("Артефакт ", scene_name, " кристаллизовался в аномалию ", anomaly_type)


func remove_all_artifacts():
	for artifact in active_artifacts:
		if is_instance_valid(artifact):
			artifact.queue_free()
	active_artifacts.clear()
	
	for timer in artifact_timers.values():
		if is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
	artifact_timers.clear()
	
	# print("Все артефакты удалены")


func stop_all_timers():
	for timer in artifact_timers.values():
		if is_instance_valid(timer):
			timer.stop()
	# print("Все таймеры артефактов остановлены")


func get_active_artifacts() -> Array[Node]:
	return active_artifacts.filter(func(a): return is_instance_valid(a))


func get_artifact_count() -> int:
	return active_artifacts.size()


# ==================== НАСТРОЙКИ ====================

func set_damage_multiplier(value: float):
	damage_multiplier = value
	# print("Множитель урона аномалий: " + str(value))


func set_radius_multiplier(value: float):
	radius_multiplier = value
	# print("Множитель радиуса аномалий: " + str(value))


func load_config(config: Dictionary):
	if config.has("anomaly_scenes"):
		anomaly_scenes = config["anomaly_scenes"]
	if config.has("anomaly_artifact_map"):
		anomaly_artifact_map = config["anomaly_artifact_map"]
	if config.has("artifact_values"):
		artifact_values = config["artifact_values"]
	if config.has("difficulty_to_rarity"):
		difficulty_to_rarity = config["difficulty_to_rarity"]
	
	# print("Конфигурация загружена")
