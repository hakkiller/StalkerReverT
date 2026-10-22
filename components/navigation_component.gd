# components/navigation_component.gd
extends Node
class_name NavigationComponent

## Компонент навигации - управляет движением к цели с улучшенной отладкой

signal target_reached
signal target_updated(new_target: Vector3)
signal path_blocked
signal navigation_failed

# Владелец
var entity: CharacterBody3D

# Навигационный агент
var nav_agent: NavigationAgent3D = null:
	set(value):
		nav_agent = value
		if nav_agent:
			nav_agent.velocity_computed.connect(_on_velocity_computed)
			nav_agent.navigation_finished.connect(_on_navigation_finished)
			# Origin тела сталкера висит на 1.8 над навмешем (капсула со смещением -0.9),
			# а точки пути лежат на навмеше. Пороги - 3D-дистанции, поэтому должны быть
			# больше вертикального смещения, иначе агент никогда не перейдёт к следующей
			# точке пути и не засчитает прибытие.
			nav_agent.path_desired_distance = 2.5
			nav_agent.target_desired_distance = 2.5
			
			# RVO-избегание: агенты расходятся друг от друга заранее, а не
			# упираются лбами на общем пути к монолиту
			nav_agent.avoidance_enabled = true
			nav_agent.radius = 0.5
			nav_agent.height = 1.8
			nav_agent.neighbor_distance = 12.0
			nav_agent.max_neighbors = 8
			nav_agent.avoidance_layers = 1
			nav_agent.avoidance_mask = 1
			# Привязываем к карте навигации
			if entity:
				nav_agent.set_navigation_map(entity.get_world_3d().navigation_map)
			# "NavigationComponent: NavigationAgent3D подключен"  # (лог отключён)

# Параметры
var move_speed: float = 5.0:
	set(value):
		move_speed = value
		if nav_agent:
			nav_agent.max_speed = move_speed

var target_position: Vector3 = Vector3.ZERO
var is_moving: bool = false
var is_patrolling: bool = false
var terrain_multiplier: float = 1.0

# Патрулирование
var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0
var patrol_loop: bool = true

# Внутреннее состояние
var _last_entity_pos: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _stuck_threshold: float = 5.0
var _stuck_distance: float = 1.0
var _last_target: Vector3 = Vector3.ZERO
var _move_start_time: float = 0.0
var _retry_count: int = 0
var _max_retries: int = 3
var _log_timer: float = 0.0
var _debug_enabled: bool = false  # Включается через enable_debug(true)


func _ready():
	if not nav_agent and entity:
		nav_agent = entity.get_node_or_null("NavigationAgent3D")
		if nav_agent:
			self.nav_agent = nav_agent
			# "NavigationComponent: NavigationAgent3D найден у entity"  # (лог отключён)
		else:
			pass
			# "NavigationComponent: NavigationAgent3D НЕ НАЙДЕН у entity!"  # (лог отключён)
	
	set_process(true)
	set_physics_process(true)
	
	# "NavigationComponent инициализирован для ", entity.name  # (лог отключён)


func _process(delta):
	if not is_moving or not nav_agent:
		return
	
	_log_timer += delta
	_move_start_time += delta
	
	# === УЛУЧШЕННАЯ ПРОВЕРКА НА ЗАСТРЕВАНИЕ ===
	# _stuck_distance трактуется как порог скорости (м/с): за кадр entity должна
	# проходить больше чем _stuck_distance * delta, иначе считаем застрявшей
	if _move_start_time > 2.0:
		var distance_moved = _last_entity_pos.distance_to(entity.global_position)
		if distance_moved < _stuck_distance * delta:
			_stuck_timer += delta
			if _stuck_timer >= _stuck_threshold:
				# "NavigationComponent: застревание обнаружено! Позиция: ", entity.global_position, " Цель: ", target_position  # (лог отключён)
				path_blocked.emit()
				
				# Проверяем, достижима ли цель
				if _last_target != Vector3.ZERO:
					var is_reachable = _check_target_reachable(_last_target)
					if not is_reachable:
						# "NavigationComponent: цель НЕДОСТИЖИМА!"  # (лог отключён)
						navigation_failed.emit()
					elif _retry_count < _max_retries:
						_retry_count += 1
						var random_offset = Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
						# "NavigationComponent: повторная попытка ", _retry_count, " со смещением ", random_offset  # (лог отключён)
						nav_agent.target_position = _last_target + random_offset
				_stuck_timer = 0.0
		else:
			_stuck_timer = 0.0
			_retry_count = 0
	
	_last_entity_pos = entity.global_position
	
	# === ОТЛАДКА КАЖДЫЕ 2 СЕКУНДЫ ===
	if _debug_enabled and _log_timer > 2.0:
		_log_timer = 0.0
		var _next = nav_agent.get_next_path_position()
		var _dist_to_target = entity.global_position.distance_to(target_position) if target_position != Vector3.ZERO else 0.0
		var _path_size = nav_agent.get_current_navigation_path().size()
		# print("Navigation: entity=", entity.name, 
			  # " moving=", is_moving,
			  # " pos=", Vector3(entity.global_position.x, 0, entity.global_position.z),
			  # " target=", Vector3(target_position.x, 0, target_position.z),
			  # " dist=", dist_to_target,
			  # " next=", Vector3(next.x, 0, next.z),
			  # " path_len=", path_size)


func _check_target_reachable(target: Vector3) -> bool:
	"""Проверяет, достижима ли цель"""
	if not nav_agent:
		return false
	
	var map = nav_agent.get_navigation_map()
	var closest_point = NavigationServer3D.map_get_closest_point(map, target)
	# 3.0 с запасом: origin тела на 1.8 выше навмеша, это добавляется к дистанции
	return closest_point.distance_to(target) < 3.0


func _physics_process(_delta):
	if not nav_agent or not is_moving:
		return
	
	if nav_agent.is_navigation_finished():
		_on_navigation_finished()
		return
	
	var next_pos = nav_agent.get_next_path_position()
	if next_pos == Vector3.ZERO:
		return
	
	# Направление считаем только по горизонтали: точки пути лежат на навмеше
	# и всегда ниже origin тела, иначе normalized даст вектор в землю
	var direction = next_pos - entity.global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	direction = direction.normalized()
	
	var desired_velocity = direction * move_speed * terrain_multiplier
	# Стенка по курсу: RVO знает только про других агентов, а не про строения.
	# Если луч вперёд упирается в крутизну (стена), скользим вдоль неё -
	# сталкер огибает дом по стенке вместо давления лбом в угол.
	desired_velocity = _slide_along_walls(desired_velocity)
	desired_velocity.y = 0
	_last_desired = desired_velocity
	
	# Используем избегание препятствий если включено
	if nav_agent.avoidance_enabled:
		nav_agent.velocity = desired_velocity
	else:
		entity.velocity.x = desired_velocity.x
		entity.velocity.z = desired_velocity.z


var _last_desired := Vector3.ZERO

func _slide_along_walls(velocity: Vector3) -> Vector3:
	"""Крутизна впереди в 1.2м - проецируем скорость на плоскость стенки.
	Пологие склоны (normal.y >= 0.7) не трогаем, иначе сдует на рельефе."""
	if entity == null or not is_instance_valid(entity):
		return velocity
	var from := entity.global_position + Vector3.UP * 0.9
	var space := entity.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		from, from + velocity.normalized() * 1.2 if velocity.length() > 0.1 else from, 1)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return velocity
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	if normal.y >= 0.7:
		return velocity
	normal.y = 0.0
	if normal.length_squared() < 0.01:
		return velocity
	normal = normal.normalized()
	var into_wall := velocity.dot(normal)
	if into_wall >= 0.0:
		return velocity
	return (velocity - normal * into_wall).normalized() * velocity.length()


func _on_velocity_computed(safe_velocity: Vector3):
	# RVO-сервер Godot периодически занижает безопасную скорость при живом
	# желании двигаться (замороженный агент без соседей) - в этом случае идём
	# по желаемой напрямую, иначе сталкеры вечно стоят на месте
	if safe_velocity.length() < 0.1 and _last_desired.length() > 0.1:
		safe_velocity = _last_desired
	# Итоговую скорость тоже снимаем со стенки: соседи толкают в стену,
	# и давление толпы не ломает огибание дома
	safe_velocity = _slide_along_walls(safe_velocity)
	entity.velocity.x = safe_velocity.x
	entity.velocity.z = safe_velocity.z


func _on_navigation_finished():
	if not is_moving:
		# Уже обработано (physics и сигнал navigation_finished срабатывают оба)
		return
	is_moving = false
	_retry_count = 0
	if _debug_enabled:
		pass
		# "NavigationComponent: цель достигнута! Позиция: ", entity.global_position  # (лог отключён)
	target_reached.emit()
	
	if is_patrolling and patrol_points.size() > 0:
		_advance_patrol()


func _advance_patrol():
	current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	# "NavigationComponent: переход к следующей точке патруля"  # (лог отключён)
	move_to(patrol_points[current_patrol_index])


# ==================== ПУБЛИЧНОЕ API ====================

func move_to(position: Vector3):
	if not nav_agent:
		# "NavigationComponent: NavigationAgent3D не назначен!"  # (лог отключён)
		navigation_failed.emit()
		return
	
	if _last_target.distance_to(position) < 1.0 and is_moving:
		if _debug_enabled:
			pass
			# "NavigationComponent: уже двигаюсь к этой цели"  # (лог отключён)
		return
	
	# Проверяем, находится ли цель на навмеше
	var map = nav_agent.get_navigation_map()
	var closest_point = NavigationServer3D.map_get_closest_point(map, position)
	# Горизонтальная дистанция: прыгающие мутанты (химера) висят над проходимой
	# землёй, и 3D-дистанция давала ложные "цель далеко от навмеша"
	var target_xz := Vector2(position.x, position.z)
	var closest_xz := Vector2(closest_point.x, closest_point.z)
	var distance_to_navmesh = target_xz.distance_to(closest_xz)
	
	if distance_to_navmesh > 5.0:
		pass
		# НЕ подменяем цель ближайшей точкой: при пустом или неполном навмеше
		# ближайшая точка - это край карты, и сталкеры уйдут туда вместо цели.
		# State machine периодически повторяет move_to, так что цель заработает,
		# когда навмеш достроится.
		# print("NavigationComponent: цель далеко от навмеша! Цель: ", position,
			  # " Ближайшая точка: ", closest_point, " Дистанция: ", distance_to_navmesh)
	
	# Печатаем только значимые перенацеливания: погоня шагами по 0.3м
	# не должна заваливать консоль (output overflow в редакторе)
	if _debug_enabled or _last_target.distance_to(position) > 2.0:
		pass
		# "NavigationComponent: двигаюсь к цели ", position  # (лог отключён)
	_last_target = position
	target_position = position
	nav_agent.target_position = position
	is_moving = true
	is_patrolling = false
	_stuck_timer = 0.0
	_retry_count = 0
	_move_start_time = 0.0
	_last_entity_pos = entity.global_position
	target_updated.emit(position)


func set_patrol_points(points: Array[Vector3], start_index: int = 0, loop: bool = true):
	# Фильтруем точки, проверяя их на навмеше
	patrol_points.clear()
	for p in points:
		var map = nav_agent.get_navigation_map() if nav_agent else RID()
		if map != RID():
			var closest = NavigationServer3D.map_get_closest_point(map, p)
			if closest.distance_to(p) < 2.0:
				patrol_points.append(p)
			else:
				pass
				# "NavigationComponent: точка патруля ", p, " не на навмеше, пропускаем"  # (лог отключён)
		else:
			patrol_points.append(p)
	
	current_patrol_index = clamp(start_index, 0, patrol_points.size() - 1) if patrol_points.size() > 0 else 0
	patrol_loop = loop
	is_patrolling = true
	
	if patrol_points.size() > 0:
		# "NavigationComponent: установлен патруль из ", patrol_points.size(), " точек"  # (лог отключён)
		move_to(patrol_points[current_patrol_index])
	else:
		pass
		# "NavigationComponent: патруль без точек"  # (лог отключён)


func stop():
	is_moving = false
	is_patrolling = false
	_retry_count = 0
	if nav_agent:
		nav_agent.target_position = entity.global_position
	# "NavigationComponent: движение остановлено"  # (лог отключён)


func pause():
	is_moving = false
	# "NavigationComponent: движение приостановлено"  # (лог отключён)


func resume():
	if target_position != Vector3.ZERO:
		move_to(target_position)
		# "NavigationComponent: движение возобновлено"  # (лог отключён)


func set_speed(speed: float):
	move_speed = speed
	# "NavigationComponent: скорость изменена на ", speed  # (лог отключён)


func set_terrain_multiplier(mult: float):
	terrain_multiplier = mult
	# "NavigationComponent: множитель местности изменен на ", mult  # (лог отключён)


func get_distance_to_target() -> float:
	if not is_moving:
		return INF
	return entity.global_position.distance_to(target_position)


func has_valid_path() -> bool:
	if not nav_agent:
		return false
	return not nav_agent.is_navigation_finished() and nav_agent.get_current_navigation_path().size() > 1


func is_navigating() -> bool:
	return is_moving


func get_current_patrol_index() -> int:
	return current_patrol_index


func get_patrol_points() -> Array[Vector3]:
	return patrol_points.duplicate()


func enable_debug(enable: bool):
	_debug_enabled = enable
