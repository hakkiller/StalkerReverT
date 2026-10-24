# managers/spawn_manager.gd
extends Node
class_name SpawnManager

## Менеджер спавна - управляет сталкерами и мутантами

signal wave_started(wave_number: int, count: int)
signal wave_ended(wave_number: int, survivors: int)
signal break_started(wave_number: int, break_duration: float)
signal all_waves_cleared
signal stalker_spawned(stalker: Node, stalker_type: String)
signal mutant_spawned(mutant: Node, mutant_type: String)
signal stalker_died(stalker: Node, biomass_returned: float)

# Параметры спавна
@export var max_waves: int = 3
@export var wave_break: float = 45.0
@export var min_stalkers_per_wave: int = 12
@export var max_stalkers_per_wave: int = 24
@export var spawn_radius: float = 120.0
@export var min_spawn_distance: float = 70.0

# События Зоны (v0.28.0): добавка сталкеров к каждой волне
var crowd_bonus: int = 0

# Сцены сталкеров
var stalker_scenes: Dictionary = {
	"novice": null,
	"veteran": null,
	"master": null
}

# Сцены мутантов
var mutant_scenes: Dictionary = {}

# Стоимость мутантов
var mutant_costs: Dictionary = {
	"dog_mutant": 15.0,
	"flesh": 15.0,
	"snork_mutant": 25.0,
	"pseudodog": 25.0,
	"controller_mutant": 40.0,
	"poltergeist": 40.0,
	"bloodsucker": 50.0,
	"chimera": 75.0,
	"pseudogiant": 75.0,
	"zombie": 10.0
}

# Возврат биомассы за сталкеров
var stalker_biomass_returns: Dictionary = {
	"novice": 16.0,
	"veteran": 30.0,
	"master": 60.0
}

# Множители из лаборатории
var health_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var cost_multiplier: float = 1.0

# Звёздность мутантов (тип -> звёзды 1-5): статы и подпись спавнящихся
var mutant_stars: Dictionary = {}

# Активные объекты
var active_stalkers: Array[Node] = []
var active_mutants: Array[Node] = []

# Состояние
var current_wave: int = 0
var is_spawning: bool = false
var is_active: bool = true
var _difficulty: float = 1.0

# Кампания: весовой состав рангов [новички, ветераны, мастера] в процентах.
# Пустой словарь = старое поведение (пороги по _difficulty)
var rank_weights: Dictionary = {}
var elite_share: float = 0.0
# Кампания: множители статов спавнящихся сталкеров
var campaign_hp_mult: float = 1.0
var campaign_damage_mult: float = 1.0
var campaign_speed_mult: float = 1.0

# Выживание: волны бесконечны, параметры каждой волны обновляет ZoneController
var endless_mode: bool = false

# Статистика
var _stalkers_killed: int = 0
var _artifacts_stolen: int = 0
var _mutants_spawned: int = 0

# Кеш для монолита
var _last_monolith_check: float = 0.0
var _cached_monolith: Node = null
const MONOLITH_CACHE_TIME: float = 1.0

# Для предотвращения спавна в одной точке
var _last_spawn_positions: Array[Vector3] = []
# Наградные мутанты (гача/вехи выживания): спавнятся бесплатно у монолита на старте волны
var reward_mutants: Array[String] = []
const MIN_SPAWN_DISTANCE_BETWEEN_STALKERS: float = 10.0

# ВЫСОТА СПАВНА - origin тела сталкера на 1.8 над землёй
# (капсула высотой 1.8 со смещением -0.9 в base_stalker.tscn занимает диапазон
# origin-1.8 .. origin, поэтому на земле Y=0 origin тела = 1.8)
const SPAWN_HEIGHT: float = 1.8


func _ready():
	add_to_group("spawn_manager")
	
	# Заполняем сцены мутантов
	mutant_scenes = {
		"dog_mutant": preload("res://entities/mutants/dog_mutant.tscn"),
		"flesh": preload("res://entities/mutants/flesh.tscn"),
		"snork_mutant": preload("res://entities/mutants/snork_mutant.tscn"),
		"pseudodog": preload("res://entities/mutants/pseudodog.tscn"),
		"controller_mutant": preload("res://entities/mutants/controller_mutant.tscn"),
		"poltergeist": preload("res://entities/mutants/poltergeist.tscn"),
		"bloodsucker": preload("res://entities/mutants/bloodsucker.tscn"),
		"chimera": preload("res://entities/mutants/chimera.tscn"),
		"pseudogiant": preload("res://entities/mutants/pseudogiant.tscn"),
		"zombie": preload("res://entities/mutants/zombie.tscn")
	}

	# Эксклюзивы Чёрного ящика: тип -> сцена-основа (вариант окраса/статов).
	# Отдельные модели художника позже заменят сцену по ключу base.
	for ex in GachaData.EXCLUSIVE_MUTANTS:
		var base_type: String = str(ex["base"])
		if mutant_scenes.has(base_type) and not mutant_scenes.has(str(ex["type"])):
			mutant_scenes[str(ex["type"])] = mutant_scenes[base_type]
	
	# print("SpawnManager инициализирован")


func _get_monolith() -> Node:
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - _last_monolith_check > MONOLITH_CACHE_TIME or not is_instance_valid(_cached_monolith):
		_cached_monolith = get_tree().get_first_node_in_group("monolith")
		_last_monolith_check = current_time
	return _cached_monolith


# ==================== УПРАВЛЕНИЕ ====================

func start_spawning():
	is_active = true
	await get_tree().create_timer(1.0).timeout
	if not is_active:
		return
	_start_wave()
	# print("Спавн сталкеров запущен")


func stop_spawning():
	is_active = false
	# print("Спавн сталкеров остановлен")


func force_wave():
	if is_active and not is_spawning:
		_start_wave()


func set_difficulty(difficulty: float):
	_difficulty = difficulty
	# print("Сложность спавна: " + str(difficulty))


# ==================== ВОЛНЫ СТАЛКЕРОВ ====================

func _start_wave():
	if is_spawning or not is_active:
		return

	# В выживании волны не кончаются
	if not endless_mode and current_wave >= max_waves:
		return

	is_spawning = true
	current_wave += 1

	_spawn_reward_mutants()

	var stalkers_to_spawn = _calculate_stalker_count()
	wave_started.emit(current_wave, stalkers_to_spawn)
	# print("Волна " + str(current_wave) + " начата, сталкеров: " + str(stalkers_to_spawn))

	var spawned = 0
	for i in range(stalkers_to_spawn):
		if _spawn_stalker():
			spawned += 1
		await get_tree().create_timer(0.3).timeout

	is_spawning = false
	wave_ended.emit(current_wave, spawned)
	# print("Волна " + str(current_wave) + " завершена, создано: " + str(spawned))

	if not endless_mode and current_wave >= max_waves:
		_watch_field_clear()
	else:
		_schedule_next_wave()


func _schedule_next_wave():
	"""Пауза между волнами, затем следующая волна"""
	if not is_active:
		return
	break_started.emit(current_wave, wave_break)
	# print("Пауза между волнами: " + str(wave_break) + " с. Следующая волна: " + str(current_wave + 1))
	await get_tree().create_timer(wave_break).timeout
	if not is_active:
		return
	_start_wave()


func _watch_field_clear():
	"""Последняя волна заспавнена: победа, когда игрок перебьёт всех сталкеров"""
	while is_active and get_stalker_count() > 0:
		await get_tree().create_timer(1.0).timeout
	if is_active:
		# print("Все волны отбиты, сталкеров не осталось!")
		all_waves_cleared.emit()


func queue_reward_mutant(mutant_type: String):
	"""Наградный мутант (гача/веха): бесплатно вступит в бой на старте волны"""
	reward_mutants.append(mutant_type)
	# print("SpawnManager: награда - ", mutant_type, " вступит в бой со следующей волной")


func _spawn_reward_mutants():
	while not reward_mutants.is_empty():
		var type: String = reward_mutants.pop_front()
		var angle = randf() * TAU
		var dist = randf_range(45.0, 70.0)
		var ray = PhysicsRayQueryParameters3D.create(
			Vector3(cos(angle) * dist, 30.0, sin(angle) * dist),
			Vector3(cos(angle) * dist, -30.0, sin(angle) * dist), 1)
		var hit = get_viewport().get_world_3d().direct_space_state.intersect_ray(ray)
		var pos = hit.get("position", Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)) + Vector3(0, 1.8, 0)
		var mutant = spawn_mutant(type, pos, 0.0)
		if mutant:
			pass
			# print("SpawnManager: наградный мутант вступил в бой: ", type)


func _calculate_stalker_count() -> int:
	var base = randi_range(min_stalkers_per_wave, max_stalkers_per_wave)
	if crowd_bonus != 0:
		base += crowd_bonus
	base = maxi(base, 1)
	return ceil(base * _difficulty)


func _spawn_stalker() -> bool:
	var scene = _get_stalker_scene_by_difficulty()
	if not scene:
		# print("Нет сцены для сталкера")
		return false
	
	var pos = _get_spawn_position()
	if pos == Vector3.ZERO:
		pos = _get_fallback_spawn_position()
		if pos == Vector3.ZERO:
			# print("Не удалось найти позицию для спавна")
			return false
	
	var stalker = scene.instantiate()
	stalker.position = pos

	get_tree().current_scene.add_child(stalker)

	# Масштабирование кампании: после add_child - статы задаёт _ready() ранга
	if campaign_hp_mult != 1.0 or campaign_damage_mult != 1.0 or campaign_speed_mult != 1.0:
		if stalker.has_method("apply_campaign_scaling"):
			stalker.apply_campaign_scaling(campaign_hp_mult, campaign_damage_mult, campaign_speed_mult)

	# Элита Стражей (25/50/75/100): часть отряда получает метку и бафф
	if elite_share > 0.0 and randf() < elite_share and stalker.has_method("promote_elite"):
		stalker.promote_elite()

	var monolith = _get_monolith()
	if monolith:
		var dir = (monolith.global_position - pos).normalized()
		stalker.look_at(pos + dir, Vector3.UP)
	
	if stalker.has_signal("died"):
		stalker.died.connect(_on_stalker_died)
	
	active_stalkers.append(stalker)
	
	var stalker_type = "novice"
	if scene == stalker_scenes.get("veteran"):
		stalker_type = "veteran"
	elif scene == stalker_scenes.get("master"):
		stalker_type = "master"
	
	stalker_spawned.emit(stalker, stalker_type)
	# print("Сталкер заспавнен: " + stalker_type + " на позиции " + str(pos))
	
	return true


func _get_stalker_scene_by_difficulty() -> PackedScene:
	# Кампания: состав рангов задаётся весами уровня, а не порогами сложности
	if not rank_weights.is_empty():
		return _get_stalker_scene_by_weights()

	var rand_val = randf()

	if _difficulty < 1.2:
		if rand_val < 0.6: return stalker_scenes.get("novice")
		elif rand_val < 0.9: return stalker_scenes.get("veteran")
		else: return stalker_scenes.get("master")
	elif _difficulty < 1.5:
		if rand_val < 0.4: return stalker_scenes.get("novice")
		elif rand_val < 0.8: return stalker_scenes.get("veteran")
		else: return stalker_scenes.get("master")
	elif _difficulty < 2.0:
		if rand_val < 0.3: return stalker_scenes.get("novice")
		elif rand_val < 0.7: return stalker_scenes.get("veteran")
		else: return stalker_scenes.get("master")
	else:
		if rand_val < 0.2: return stalker_scenes.get("novice")
		elif rand_val < 0.6: return stalker_scenes.get("veteran")
		else: return stalker_scenes.get("master")


func _get_stalker_scene_by_weights() -> PackedScene:
	var novice: float = float(rank_weights.get("novice", 0.0))
	var veteran: float = float(rank_weights.get("veteran", 0.0))
	var master: float = float(rank_weights.get("master", 0.0))
	var total: float = novice + veteran + master

	if total <= 0.0:
		return stalker_scenes.get("novice")

	var roll: float = randf() * total
	if roll < novice:
		return stalker_scenes.get("novice")
	elif roll < novice + veteran:
		return stalker_scenes.get("veteran")
	return stalker_scenes.get("master")


func _get_spawn_position() -> Vector3:
	var monolith = _get_monolith()
	if not monolith:
		return Vector3.ZERO
	
	for attempt in range(20):
		var angle = randf() * TAU
		var distance = min_spawn_distance + randf() * (spawn_radius - min_spawn_distance)
		var pos = monolith.global_position + Vector3(cos(angle) * distance, 100, sin(angle) * distance)
		
		var space = get_viewport().get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.new()
		query.from = pos
		query.to = pos + Vector3(0, -200, 0)
		query.collision_mask = 1
		query.hit_from_inside = true
		
		var result = space.intersect_ray(query)
		if result:
			# СТАЛКЕР НА ВЫСОТЕ SPAWN_HEIGHT НАД РЕЛЬЕФОМ
			var ground_pos = Vector3(result.position.x, result.position.y + SPAWN_HEIGHT, result.position.z)
			
			var too_close = false
			for existing_pos in _last_spawn_positions:
				if ground_pos.distance_to(existing_pos) < MIN_SPAWN_DISTANCE_BETWEEN_STALKERS:
					too_close = true
					break
			
			if not too_close:
				_last_spawn_positions.append(ground_pos)
				if _last_spawn_positions.size() > 10:
					_last_spawn_positions.pop_front()
				return ground_pos
	
	return Vector3.ZERO


func _get_fallback_spawn_position() -> Vector3:
	var monolith = _get_monolith()
	if not monolith:
		return Vector3.ZERO
	
	for angle_offset in range(0, 8):
		var angle = (randf() + angle_offset) * TAU / 4
		var distance = min_spawn_distance + 5.0
		var pos = monolith.global_position + Vector3(cos(angle) * distance, 100, sin(angle) * distance)
		
		var space = get_viewport().get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.new()
		query.from = pos
		query.to = pos + Vector3(0, -200, 0)
		query.collision_mask = 1
		
		var result = space.intersect_ray(query)
		if result:
			var ground_pos = Vector3(result.position.x, result.position.y + SPAWN_HEIGHT, result.position.z)
			
			var too_close = false
			for existing_pos in _last_spawn_positions:
				if ground_pos.distance_to(existing_pos) < MIN_SPAWN_DISTANCE_BETWEEN_STALKERS:
					too_close = true
					break
			
			if not too_close:
				_last_spawn_positions.append(ground_pos)
				if _last_spawn_positions.size() > 10:
					_last_spawn_positions.pop_front()
				return ground_pos
	
	for i in range(5):
		var fallback_pos = monolith.global_position + Vector3(10 + i * 5, 0, 10 + i * 5)
		return Vector3(fallback_pos.x, SPAWN_HEIGHT, fallback_pos.z)
	
	return Vector3(monolith.global_position.x, SPAWN_HEIGHT, monolith.global_position.z)


func _on_stalker_died(stalker: Node):
	if stalker in active_stalkers:
		active_stalkers.erase(stalker)
	
	var return_value = 8.0
	if stalker.has_method("get_stalker_type"):
		var stalker_type = stalker.get_stalker_type()
		return_value = stalker_biomass_returns.get(stalker_type, 8.0)
	
	_stalkers_killed += 1
	
	stalker_died.emit(stalker, return_value)
	# (лог отключён)
	# Биомассу начисляет BaseStalker._on_died -> ZoneController.on_stalker_died


# ==================== МУТАНТЫ ====================

func spawn_mutant(mutant_type: String, position: Vector3, _biomass_cost: float, stars_for: String = "") -> Node:
	if not mutant_scenes.has(mutant_type):
		# print("Неизвестный тип мутанта: " + mutant_type)
		return null
	
	var scene = mutant_scenes[mutant_type]
	if not scene:
		# print("Сцена не найдена для мутанта: " + mutant_type)
		return null
	
	var mutant = scene.instantiate()
	# Спавн не за периметром Зоны
	position.x = clampf(position.x, -Helpers.WORLD_LIMIT, Helpers.WORLD_LIMIT)
	position.z = clampf(position.z, -Helpers.WORLD_LIMIT, Helpers.WORLD_LIMIT)
	mutant.position = position
	
	# Звёздность типа: множитель статов + уровень для подписи
	var star_key: String = stars_for if not stars_for.is_empty() else mutant_type
	var stars := maxi(int(mutant_stars.get(star_key, 1)), 1)
	var star_mult := LabData.get_star_stat_mult(stars)
	if stars > 1 and mutant.has_method("set_star_level"):
		mutant.set_star_level(stars)
	
	var hp_mult := health_multiplier * star_mult
	var dmg_mult := damage_multiplier * star_mult
	var ex: Dictionary = GachaData.get_exclusive(mutant_type)
	if not ex.is_empty():
		hp_mult *= float(ex.get("hp", 1.0))
		dmg_mult *= float(ex.get("dmg", 1.0))
	if hp_mult != 1.0 and mutant.has_method("set_health_multiplier"):
		mutant.set_health_multiplier(hp_mult)
	if dmg_mult != 1.0 and mutant.has_method("set_damage_multiplier"):
		mutant.set_damage_multiplier(dmg_mult)
	
	if not ex.is_empty() and mutant.has_method("apply_exclusive_variant"):
		var t: Array = ex.get("tint", [1.0, 1.0, 1.0])
		var tint := Color(float(t[0]), float(t[1]), float(t[2]))
		var accent := Color(str(ex.get("accent", "ffffff")))
		mutant.apply_exclusive_variant(
			mutant_type, str(ex.get("label", "")), tint,
			float(ex.get("speed", 1.0)), accent)
	
	get_tree().current_scene.add_child(mutant)
	active_mutants.append(mutant)
	_mutants_spawned += 1
	
	mutant_spawned.emit(mutant, mutant_type)
	var _star_note := " [%d★ x%.1f]" % [stars, star_mult] if stars > 1 else ""
	# print("Мутант заспавнен: " + mutant_type + " на позиции " + str(position) + star_note)
	
	return mutant


func remove_mutant(mutant: Node):
	if mutant in active_mutants:
		active_mutants.erase(mutant)
	if is_instance_valid(mutant):
		mutant.queue_free()


func get_mutant_cost(mutant_type: String) -> float:
	var base_cost = mutant_costs.get(mutant_type, 20.0)
	return base_cost * cost_multiplier


# ==================== ГЕТТЕРЫ ====================

func get_active_stalkers() -> Array[Node]:
	return active_stalkers.filter(func(s): return is_instance_valid(s))


func get_active_mutants() -> Array[Node]:
	return active_mutants.filter(func(m): return is_instance_valid(m))


func get_stalker_count() -> int:
	return active_stalkers.size()


func get_mutant_count() -> int:
	return active_mutants.size()


func get_stalkers_killed() -> int:
	return _stalkers_killed


func get_artifacts_stolen() -> int:
	return _artifacts_stolen


func get_total_mutants_spawned() -> int:
	return _mutants_spawned


# ==================== СТАТИСТИКА ====================

func record_artifact_stolen():
	_artifacts_stolen += 1


func reset_statistics():
	_stalkers_killed = 0
	_artifacts_stolen = 0
	_mutants_spawned = 0
	# print("Статистика спавна сброшена")


# ==================== НАСТРОЙКИ ====================

func set_health_multiplier(value: float):
	health_multiplier = value
	# print("Множитель здоровья мутантов: " + str(value))


func set_damage_multiplier(value: float):
	damage_multiplier = value
	# print("Множитель урона мутантов: " + str(value))


func set_cost_multiplier(value: float):
	cost_multiplier = value
	# print("Множитель стоимости мутантов: " + str(value))


## Звёздность из коллекции (тип -> звёзды): применяется к спавнящимся мутантам
func set_mutant_stars(stars: Dictionary):
	mutant_stars = stars.duplicate()
	if not mutant_stars.is_empty():
		var starred := []
		for type in mutant_stars:
			if int(mutant_stars[type]) > 1:
				starred.append("%s:%d★" % [type, int(mutant_stars[type])])
		if not starred.is_empty():
			pass
			# print("Звёздность мутантов: " + ", ".join(starred))


# ==================== ПАРАМЕТРЫ КАМПАНИИ ====================

## Весовой состав рангов из кампании: mix = [новички, ветераны, мастера] в процентах
func set_rank_weights(mix: Array):
	if mix.size() < 3:
		# print("set_rank_weights: ожидается массив из 3 процентов, получено: " + str(mix))
		return
	rank_weights = {
		"novice": float(mix[0]),
		"veteran": float(mix[1]),
		"master": float(mix[2])
	}
	# print("Состав рангов: н/в/м = %d/%d/%d%%" % [int(mix[0]), int(mix[1]), int(mix[2])])


## Доля элиты в волнах (Стражи башни 25/50/75/100): 0.25 = четверть отряда
func set_elite_share(pct: float):
	elite_share = clampf(pct, 0.0, 1.0)


## Множители статов врагов для текущего уровня кампании
func set_campaign_scaling(hp_mult: float, damage_mult: float, speed_mult: float):
	campaign_hp_mult = hp_mult
	campaign_damage_mult = damage_mult
	campaign_speed_mult = speed_mult
	# print("Масштаб кампании: HP x%.2f, урон x%.2f, скорость x%.2f" % [hp_mult, damage_mult, speed_mult])
