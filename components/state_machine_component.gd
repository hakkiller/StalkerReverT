# components/state_machine_component.gd
extends Node
class_name StateMachineComponent

## Компонент конечного автомата - управляет состояниями сталкера

signal state_changed(old_state: GameEnums.StalkerState, new_state: GameEnums.StalkerState)
signal state_entered(state: GameEnums.StalkerState)
signal state_exited(state: GameEnums.StalkerState)

# Владелец
var stalker: BaseStalker

# Текущее состояние
var current_state: GameEnums.StalkerState = GameEnums.StalkerState.SEEK_MONOLITH:
	set(value):
		if current_state != value:
			var old = current_state
			current_state = value
			# "StateMachine: состояние изменено с ", _get_state_name(old), " на ", _get_state_name(value)  # (лог отключён)
			state_changed.emit(old, value)
			_on_state_entered(value)

# Предыдущее состояние
var previous_state: GameEnums.StalkerState = GameEnums.StalkerState.SEEK_MONOLITH

# Зависимости
var behavior_strategy: StalkerBehaviorStrategy
var navigation: NavigationComponent
var memory: MemoryComponent
var carry: CarryComponent
var health: HealthComponent
var monolith: Node

# Таймеры состояний
var current_state_time: float = 0.0

# Флаги
var can_transition: bool = true
var debug_mode: bool = true  # Включаем debug
var _last_target_position: Vector3 = Vector3.ZERO
var _target_update_timer: float = 0.0
var _log_timer: float = 0.0
# Одноразовый триггер прибытия к монолиту
var _monolith_reached: bool = false
# Антизастревание: стоим на месте слишком долго - перпендикулярный обход
# с эскалацией радиуса (обходные точки ВДОЛЬ маршрута вели в то же препятствие)
var _stuck_pos: Vector3 = Vector3.ZERO
var _stuck_time: float = 0.0
var _stuck_detours: int = 0
# Прямой ход при потере пути (дыры в навмеше на стыках чанков)
var _lost_path_time: float = 0.0


func _ready():
	set_process(true)
	# "StateMachineComponent инициализирован"  # (лог отключён)


func setup(deps: Dictionary):
	behavior_strategy = deps.get("behavior")
	navigation = deps.get("navigation")
	memory = deps.get("memory")
	carry = deps.get("carry")
	health = deps.get("health")
	monolith = deps.get("monolith")
	
	# "StateMachine: зависимости установлены"  # (лог отключён)
	# "  - поведение: ", behavior_strategy  # (лог отключён)
	# "  - навигация: ", navigation != null  # (лог отключён)
	# "  - память: ", memory != null  # (лог отключён)
	# "  - переноска: ", carry != null  # (лог отключён)
	# "  - здоровье: ", health != null  # (лог отключён)
	# "  - монолит: ", monolith != null  # (лог отключён)


func _process(delta):
	if not stalker or not stalker.is_alive():
		return
	
	current_state_time += delta
	_target_update_timer += delta
	_log_timer += delta
	
	# Логируем состояние каждые 3 секунды
	if _log_timer > 3.0:
		_log_timer = 0.0
		# "StateMachine: текущее состояние=", _get_state_name(current_state)  # (лог отключён)
	
	# Обработка текущего состояния
	match current_state:
		GameEnums.StalkerState.IDLE:
			_process_idle(delta)
		GameEnums.StalkerState.PATROL:
			_process_patrol(delta)
		GameEnums.StalkerState.SEEK_ARTIFACT:
			_process_seek_artifact(delta)
		GameEnums.StalkerState.SEEK_MONOLITH:
			_process_seek_monolith(delta)
		GameEnums.StalkerState.FLEE:
			_process_flee(delta)
		GameEnums.StalkerState.ATTACK_ANOMALY:
			_process_attack_anomaly(delta)
		GameEnums.StalkerState.ATTACK_MUTANT:
			_process_attack_mutant(delta)
		GameEnums.StalkerState.CARRY_ARTIFACT:
			_process_carry_artifact(delta)
	
	# Проверка переходов
	_check_transitions()
	
	# Подобрать артефакт на бегу: проезжал мимо и не схватил - теперь схватит
	_try_opportunistic_pickup()


# ==================== ОБРАБОТЧИКИ СОСТОЯНИЙ ====================

func _process_idle(_delta):
	if current_state_time > 2.0:
		# "StateMachine: IDLE -> PATROL (таймаут)"  # (лог отключён)
		set_state(GameEnums.StalkerState.PATROL)


func _process_patrol(_delta):
	if navigation and not navigation.is_navigating():
		var random_pos = stalker.global_position + Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
		# "StateMachine: PATROL - двигаюсь к случайной точке ", random_pos  # (лог отключён)
		navigation.move_to(random_pos)


func _process_seek_artifact(_delta):
	if memory and memory.has_artifacts():
		var target = memory.get_nearest_artifact()
		if target and is_instance_valid(target):
			var dist = stalker.global_position.distance_to(target.global_position)
			if dist < 2.0 and carry and not carry.has_artifact():
				if carry.can_pick_up(target):
					# "StateMachine: SEEK_ARTIFACT - подбираю артефакт"  # (лог отключён)
					carry.pick_up_artifact(target)
			elif navigation and (not navigation.is_navigating() or _target_update_timer > 1.0):
				# "StateMachine: SEEK_ARTIFACT - двигаюсь к артефакту ", target.global_position  # (лог отключён)
				navigation.move_to(target.global_position)
				_target_update_timer = 0.0
				_last_target_position = target.global_position
	elif navigation and navigation.is_navigating():
		# "StateMachine: SEEK_ARTIFACT - нет артефактов, останавливаюсь"  # (лог отключён)
		navigation.stop()


func _process_seek_monolith(delta):
	if _monolith_reached:
		return
	if monolith and is_instance_valid(monolith):
		var dist = stalker.global_position.distance_to(monolith.global_position)
		if dist < 5.0:
			_monolith_reached = true
			# "StateMachine: SEEK_MONOLITH - достиг монолита!"  # (лог отключён)
			if navigation:
				navigation.stop()
			var zc = get_tree().get_first_node_in_group("zone_controller")
			if zc:
				zc.finish_run(false)
		elif navigation and not navigation.is_navigating():
			# Путь потерян (например, дыра в навмеше на стыке чанков):
			# идём к монолиту напрямую по рельефу, периодически пробуя
			# вернуть навигацию
			_lost_path_time += delta
			var to_monolith = monolith.global_position - stalker.global_position
			to_monolith.y = 0.0
			if to_monolith.length() > 1.0:
				to_monolith = to_monolith.normalized()
				stalker.velocity.x = to_monolith.x * stalker.speed
				stalker.velocity.z = to_monolith.z * stalker.speed
			if _lost_path_time > 1.0:
				_lost_path_time = 0.0
				navigation.move_to(monolith.global_position)
		else:
			_lost_path_time = 0.0
		# Антизастревание v2: перпендикулярный обход с эскалацией
		_update_anti_stuck(monolith.global_position, delta)


## Антизастревание v3: 5с без СЕТЕВОГО смещения 2.5м -> обходная точка
## перпендикулярно маршруту, радиус растёт с числом попыток.
## Порог 2.5м (было 1.0): RVO-дрожь у стены сбрасывала таймер микродвижением,
## и сталкеры вечно толклись у дома. На 3-й попытке - жёсткое спасение:
## агента, слезшего с навмеша (крыша, пролом), ставит на ближайшую его точку.
## target_pos - куда сталкер идёт (монолит, край карты)
func _update_anti_stuck(target_pos: Vector3, delta):
	_stuck_time += delta
	if stalker.global_position.distance_to(_stuck_pos) >= 2.5:
		_stuck_pos = stalker.global_position
		_stuck_time = 0.0
		_stuck_detours = 0
		return
	if _stuck_time < 5.0 or not navigation:
		return
	_stuck_time = 0.0
	_stuck_detours += 1
	var dir: Vector3 = target_pos - stalker.global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	var perp := Vector3(-dir.z, 0.0, dir.x)
	var side := 1.0 if randf() < 0.5 else -1.0
	var radius: float = 10.0 + 8.0 * float(_stuck_detours)
	var detour: Vector3 = stalker.global_position + perp * side * radius + dir * 5.0
	var flat := Vector2(detour.x, detour.z)
	if flat.length() > 145.0:
		flat = flat.normalized() * 145.0
		detour = Vector3(flat.x, detour.y, detour.z)

	# Жёсткое спасение: три обхода не помогли - скорее всего агент вне навмеша
	# (стоит на крыше/проломе, путь не строится). Ставим на ближайшую его точку.
	if _stuck_detours >= 3 and navigation.nav_agent:
		var map: RID = navigation.nav_agent.get_navigation_map()
		var snap := NavigationServer3D.map_get_closest_point(map, stalker.global_position)
		var flat_gap := Vector2(snap.x, snap.z).distance_to(
			Vector2(stalker.global_position.x, stalker.global_position.z))
		if flat_gap > 2.0:
			stalker.global_position = snap + Vector3.UP * 1.8
			stalker.velocity = Vector3.ZERO
			_stuck_detours = 0
			_stuck_pos = stalker.global_position
			# "StateMachine: спасение - агент вне навмеша, поставлен на него"  # (лог отключён)

	# "StateMachine: антизастревание #", _stuck_detours, " - обходная точка ", detour  # (лог отключён)
	navigation.move_to(detour)


func _process_flee(_delta):
	if not navigation or not navigation.is_navigating():
		if memory and memory.has_threats():
			var threat = memory.get_nearest_threat()
			if threat and is_instance_valid(threat):
				var flee_dir = (stalker.global_position - threat.global_position).normalized()
				var flee_pos = stalker.global_position + flee_dir * 30
				# "StateMachine: FLEE - убегаю от ", threat.name, " в ", flee_pos  # (лог отключён)
				navigation.move_to(flee_pos)


func _process_attack_anomaly(_delta):
	var target = _get_attack_target()
	if target and is_instance_valid(target):
		var dist = stalker.global_position.distance_to(target.global_position)
		if dist < 5.0:
			# Атака с кулдауном сталкера: без проверки attack_timer урон
			# наносился каждый кадр (~480 DPS) и мутанты умирали мгновенно
			if target.has_method("take_damage") and stalker.attack_timer <= 0.0:
				target.take_damage(stalker.damage, stalker)
				stalker.attack_timer = stalker.attack_cooldown
		elif navigation and (not navigation.is_navigating() or _target_update_timer > 1.0):
			# "StateMachine: ATTACK_ANOMALY - двигаюсь к аномалии"  # (лог отключён)
			navigation.move_to(target.global_position)
			_target_update_timer = 0.0


func _process_attack_mutant(_delta):
	var target = _get_attack_target()
	if target and is_instance_valid(target):
		var to_target = target.global_position - stalker.global_position
		var horizontal_dist = Vector2(to_target.x, to_target.z).length()
		var dy: float = abs(to_target.y)
		# Прыгающие мутанты висят в воздухе: бьём только когда цель рядом
		# по горизонтали и не выше 2.5м; пока летает - спокойно ждём внизу
		if horizontal_dist < 3.0 and dy < 2.5:
			if target.has_method("take_damage") and stalker.attack_timer <= 0.0:
				target.take_damage(stalker.damage, stalker)
				stalker.attack_timer = stalker.attack_cooldown
		elif horizontal_dist >= 3.0 and navigation and (not navigation.is_navigating() or _target_update_timer > 1.0):
			# "StateMachine: ATTACK_MUTANT - двигаюсь к мутанту"  # (лог отключён)
			navigation.move_to(target.global_position)
			_target_update_timer = 0.0


func _process_carry_artifact(delta):
	if carry and carry.has_artifact():
		# Артефакт украден, когда сталкер вынес его за периметр Зоны
		var dist_from_monolith: float = stalker.global_position.distance_to(
			monolith.global_position if monolith and is_instance_valid(monolith) else Vector3.ZERO)
		if dist_from_monolith > 150.0:
			# "StateMachine: CARRY_ARTIFACT - артефакт украден (вышел за периметр)"  # (лог отключён)
			carry.steal_artifact()
			set_state(GameEnums.StalkerState.SEEK_MONOLITH)
			return
		_update_anti_stuck(_get_edge_position(), delta)
		if navigation and (not navigation.is_navigating() or _target_update_timer > 2.0):
			# "StateMachine: CARRY_ARTIFACT - несу артефакт к краю"  # (лог отключён)
			navigation.move_to(_get_edge_position())
			_target_update_timer = 0.0


# ==================== ЛОГИКА ПЕРЕХОДОВ ====================

func _check_transitions():
	if not can_transition:
		return
	
	# 1. Проверка на смерть
	if health and not health.is_alive:
		return
	
	# 2. Если несем артефакт
	if carry and carry.has_artifact():
		if current_state != GameEnums.StalkerState.CARRY_ARTIFACT:
			# "StateMachine: переход в CARRY_ARTIFACT (есть артефакт)"  # (лог отключён)
			set_state(GameEnums.StalkerState.CARRY_ARTIFACT)
		return
	
	# 3. Проверка опасностей
	if memory:
		var nearest_threat = memory.get_nearest_threat()
		if nearest_threat and is_instance_valid(nearest_threat):
			# Реагируем только на угрозы в зоне видимости, а не «по памяти»:
			# иначе сталкер вечно возвращается к забытому противнику
			var threat_dist = stalker.global_position.distance_to(nearest_threat.global_position)
			if threat_dist <= memory.vision_range:
				if behavior_strategy and behavior_strategy.should_flee_from(nearest_threat):
					# Паника не бесконечна: уже бежим и угроза дальше 15м - хватит
					var keep_fleeing: bool = current_state != GameEnums.StalkerState.FLEE or threat_dist <= 8.0
					if keep_fleeing:
						if current_state != GameEnums.StalkerState.FLEE:
							# "StateMachine: переход в FLEE от ", nearest_threat.name  # (лог отключён)
							set_state(GameEnums.StalkerState.FLEE)
							if navigation:
								var flee_dir = (stalker.global_position - nearest_threat.global_position).normalized()
								var flee_target = stalker.global_position + flee_dir * 15
								# Не убегаем за периметр (за 150м кончается земля)
								var flat_f = Vector2(flee_target.x, flee_target.z)
								if flat_f.length() > 145.0:
									flat_f = flat_f.normalized() * 145.0
									flee_target = Vector3(flat_f.x, flee_target.y, flee_target.z)
								navigation.move_to(flee_target)
						return
					# Выпадаем из паники - идут обычные переходы (обычно SEEK_MONOLITH)
				elif behavior_strategy and behavior_strategy.should_attack(nearest_threat):
					var target_state = GameEnums.StalkerState.ATTACK_ANOMALY
					if nearest_threat.is_in_group("mutants"):
						target_state = GameEnums.StalkerState.ATTACK_MUTANT
					
					if current_state != target_state:
						# "StateMachine: переход в атаку на ", nearest_threat.name  # (лог отключён)
						set_state(target_state)
					return
	
	# 4. Поиск артефактов
	if memory and memory.has_artifacts() and behavior_strategy and behavior_strategy.prefers_artifacts():
		if current_state != GameEnums.StalkerState.SEEK_ARTIFACT:
			# "StateMachine: переход в SEEK_ARTIFACT"  # (лог отключён)
			set_state(GameEnums.StalkerState.SEEK_ARTIFACT)
		return
	
	# 5. По умолчанию цель сталкера - монолит. После победы над угрозой
	# стейт вернётся сюда автоматически (угроза исчезнет из памяти).
	# Без монолита - патрулируем.
	if current_state != GameEnums.StalkerState.SEEK_MONOLITH:
		if monolith and is_instance_valid(monolith):
			# "StateMachine: переход в SEEK_MONOLITH (цель по умолчанию)"  # (лог отключён)
			set_state(GameEnums.StalkerState.SEEK_MONOLITH)
		elif current_state != GameEnums.StalkerState.PATROL:
			set_state(GameEnums.StalkerState.PATROL)


func _on_state_entered(state: GameEnums.StalkerState):
	current_state_time = 0.0
	state_entered.emit(state)
	
	# "StateMachine: вход в состояние ", _get_state_name(state)  # (лог отключён)
	
	_stuck_time = 0.0
	_stuck_detours = 0
	
	match state:
		GameEnums.StalkerState.IDLE:
			if navigation:
				navigation.stop()
		
		GameEnums.StalkerState.PATROL:
			if navigation:
				navigation.set_patrol_points(_generate_patrol_points())
		
		GameEnums.StalkerState.FLEE:
			if navigation and stalker:
				navigation.set_speed(stalker.speed * 1.3)
		
		GameEnums.StalkerState.SEEK_ARTIFACT, GameEnums.StalkerState.SEEK_MONOLITH:
			_target_update_timer = 1.0


func _on_state_exited(state: GameEnums.StalkerState):
	state_exited.emit(state)
	
	# "StateMachine: выход из состояния ", _get_state_name(state)  # (лог отключён)
	
	match state:
		GameEnums.StalkerState.FLEE:
			if navigation and stalker:
				navigation.set_speed(stalker.speed)


# ==================== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ====================

## Артефакт рядом (3м по горизонтали) - подобрать независимо от состояния
func _try_opportunistic_pickup():
	if carry == null or carry.has_artifact():
		return
	if memory == null or not memory.has_artifacts():
		return
	var target = memory.get_nearest_artifact()
	if target and is_instance_valid(target):
		var to_target = target.global_position - stalker.global_position
		if Vector2(to_target.x, to_target.z).length() < 3.0 and carry.can_pick_up(target):
			# "StateMachine: подобрал артефакт на бегу - ", target.name  # (лог отключён)
			carry.pick_up_artifact(target)


func _get_attack_target() -> Node:
	if current_state == GameEnums.StalkerState.ATTACK_ANOMALY and memory:
		return memory.get_nearest_anomaly()
	elif current_state == GameEnums.StalkerState.ATTACK_MUTANT and memory:
		return memory.get_nearest_mutant()
	return null


func _get_edge_position() -> Vector3:
	# Точка кражи - У ПЕРИМЕТРА, внутри границ мира (200м были за клампом
	# и сталкер топтался на границе вечно, не доходя до цели)
	if monolith and is_instance_valid(monolith):
		var dir = (stalker.global_position - monolith.global_position).normalized()
		return monolith.global_position + dir * 150
	return stalker.global_position + Vector3(120, 0, 0)


func _generate_patrol_points(count: int = 3) -> Array[Vector3]:
	var points = []
	var center = stalker.global_position
	
	for i in range(count):
		var angle = (TAU / count) * i + randf_range(-0.5, 0.5)
		var distance = 15.0 + randf_range(-5, 5)
		var pos = center + Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		
		var space = stalker.get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.new()
		query.from = pos + Vector3(0, 20, 0)
		query.to = pos - Vector3(0, 20, 0)
		query.collision_mask = 1
		
		var result = space.intersect_ray(query)
		if result:
			pos.y = result.position.y + 0.5
		
		points.append(pos)
	
	return points


func _get_state_name(state: GameEnums.StalkerState) -> String:
	return GameEnums.StalkerState.keys()[state]


# ==================== ПУБЛИЧНОЕ API ====================

func set_state(new_state: GameEnums.StalkerState):
	if current_state == new_state:
		return
	
	_on_state_exited(current_state)
	previous_state = current_state
	current_state = new_state


func get_state() -> GameEnums.StalkerState:
	return current_state


func get_state_name() -> String:
	return _get_state_name(current_state)


func get_previous_state() -> GameEnums.StalkerState:
	return previous_state


func get_time_in_state() -> float:
	return current_state_time


func is_in_state(state: GameEnums.StalkerState) -> bool:
	return current_state == state


func is_in_combat() -> bool:
	return current_state in [GameEnums.StalkerState.ATTACK_ANOMALY, GameEnums.StalkerState.ATTACK_MUTANT]


func is_fleeing() -> bool:
	return current_state == GameEnums.StalkerState.FLEE


func is_carrying() -> bool:
	return current_state == GameEnums.StalkerState.CARRY_ARTIFACT


func is_moving_to_target() -> bool:
	return current_state in [
		GameEnums.StalkerState.SEEK_ARTIFACT,
		GameEnums.StalkerState.SEEK_MONOLITH,
		GameEnums.StalkerState.CARRY_ARTIFACT
	]


func enable_debug(enable: bool):
	debug_mode = enable


func get_status() -> Dictionary:
	return {
		"current_state": _get_state_name(current_state),
		"previous_state": _get_state_name(previous_state),
		"time_in_state": current_state_time,
		"in_combat": is_in_combat(),
		"fleeing": is_fleeing(),
		"carrying": is_carrying()
	}
