# entities/stalkers/base_stalker.gd
extends CharacterBody3D
class_name BaseStalker

## Базовый класс для всех сталкеров.
## Содержит общие переменные и методы, которые могут быть переопределены.

# Сигналы
signal died(stalker: BaseStalker)
signal attacked(target: Node3D)
signal artifact_picked_up(artifact: Node, value: int)
signal artifact_dropped(artifact: Node)
signal artifact_stolen(artifact: Node, value: int)
signal target_acquired(target: Node, type: String)
signal target_lost(target: Node)

# Основные параметры (будут переопределены в наследниках)
@export var stalker_type: GameEnums.StalkerType = GameEnums.StalkerType.NOVICE
@export var behavior_type: GameEnums.StalkerBehavior = GameEnums.StalkerBehavior.GREEDY
@export var health: float = 100.0
@export var max_health: float = 100.0
@export var speed: float = 3.5
@export var damage: float = 10.0
@export var armor: float = 0.0
@export var detection_radius: float = 20.0
@export var attack_range: float = 3.0
@export var attack_cooldown: float = 1.0
@export var biomass_return: float = 20.0
@export var gravity: float = 15.0

# Компоненты (будут инициализированы в наследниках)
var health_component: HealthComponent
var navigation_component: NavigationComponent
var memory_component: MemoryComponent
var carry_component: CarryComponent
var state_machine: StateMachineComponent
var behavior_strategy: StalkerBehaviorStrategy

# Ссылки
var monolith: Node
var current_target: Node = null

# Визуальные узлы (ожидаются в сцене)
@onready var visuals: Node3D = $Visuals if has_node("Visuals") else null
@onready var label: Label3D = $Label3D if has_node("Label3D") else null

# Таймер атаки
var attack_timer: float = 0.0

# Шаги: позиционный звук по пройденной дистанции
var _step_player: AudioStreamPlayer3D
var _step_accum: float = 0.0
var _step_surface: String = "grass"
const STEP_INTERVAL: float = 2.2

# Состояния эффектов (для аномалий)
var is_stunned: bool = false
var stun_timer: float = 0.0
var slow_factor: float = 1.0
var time_dilation: float = 1.0


# ==================== МЕТОДЫ, КОТОРЫЕ МОГУТ БЫТЬ ПЕРЕОПРЕДЕЛЕНЫ ====================

func _ready():
	# Хук для наследников
	_ready_hook()
	
	# Добавляем в группы
	add_to_group("stalkers")
	add_to_group("stalkers_" + GameEnums.StalkerType.keys()[stalker_type].to_lower())
	
	# Позиционные шаги
	_setup_footsteps()
	
	# Настройка подписи
	_setup_label()
	
	# Поиск ZoneController для регистрации
	var zc = get_tree().get_first_node_in_group("zone_controller")
	if zc and zc.has_method("register_stalker"):
		zc.register_stalker(self)


func _setup_label():
	if label:
		match stalker_type:
			GameEnums.StalkerType.NOVICE:
				label.text = "🟢 НОВИЧОК"
				label.modulate = Color(0.2, 0.8, 0.2)
			GameEnums.StalkerType.VETERAN:
				label.text = "🔵 ВЕТЕРАН"
				label.modulate = Color(0.2, 0.4, 1.0)
			GameEnums.StalkerType.MASTER:
				label.text = "🟣 МАСТЕР"
				label.modulate = Color(0.8, 0.2, 0.8)
		label.font_size = 24
		label.outline_size = 2
		label.outline_modulate = Color.BLACK


func _setup_footsteps():
	"""Позиционный шаг: свой 3D-плеер, поверхность спрашиваем у карты"""
	_step_player = AudioStreamPlayer3D.new()
	_step_player.max_distance = 20.0
	_step_player.bus = "SFX"
	add_child(_step_player)
	var terrain = get_tree().get_first_node_in_group("terrain_generator")
	if terrain and terrain.has_method("get_footstep_surface"):
		_step_surface = terrain.get_footstep_surface()


func _play_footstep():
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm == null or not sm.has_method("get_footstep_stream") or _step_player == null:
		return
	var stream: AudioStream = sm.get_footstep_stream(_step_surface)
	if stream == null:
		return
	_step_player.stream = stream
	_step_player.pitch_scale = randf_range(0.9, 1.1)
	_step_player.play()


func _physics_process(delta):
	if not is_alive():
		return
	
	# Обновление таймера атаки
	if attack_timer > 0:
		attack_timer -= delta
	
	# Обновление состояний эффектов
	_update_effects(delta)
	
	# Шаги: копим пройденную по земле дистанцию
	if is_on_floor():
		_step_accum += Vector2(velocity.x, velocity.z).length() * delta
		if _step_accum >= STEP_INTERVAL:
			_step_accum = 0.0
			_play_footstep()
	
	# Плавный разворот в сторону движения (для моделей)
	var horizontal := Vector2(velocity.x, velocity.z)
	if horizontal.length() > 0.5:
		rotation.y = lerp_angle(rotation.y, atan2(-horizontal.x, -horizontal.y), 8.0 * delta)
	
	# Хук для наследников (они должны вызвать move_and_slide)
	if not is_stunned:
		_physics_hook(delta)
	else:
		# Если сталкер оглушён, не двигаемся
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
	
	# Граница мира ( Helpers.WORLD_LIMIT ) - периметр не выпускает
	global_position.x = clampf(global_position.x, -Helpers.WORLD_LIMIT, Helpers.WORLD_LIMIT)
	global_position.z = clampf(global_position.z, -Helpers.WORLD_LIMIT, Helpers.WORLD_LIMIT)


func _update_effects(delta):
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0:
			is_stunned = false
			# "Stalker: оглушение закончилось"  # (лог отключён)


func _ready_hook():
	"""Вызывается в _ready() после базовой инициализации."""
	pass


func _physics_hook(_delta: float):
	"""Вызывается каждый кадр в _physics_process. Должен содержать вызов move_and_slide."""
	# По умолчанию просто вызываем move_and_slide
	move_and_slide()


func _attack_hook(_target: Node) -> bool:
	"""Вызывается перед атакой. Вернуть true, чтобы отменить стандартную атаку."""
	return false


func _attack_target(target: Node):
	"""Стандартная атака. Может быть переопределена."""
	if target and target.has_method("take_damage"):
		target.take_damage(damage, self)
		attack_timer = attack_cooldown
		attacked.emit(target)
		# "BaseStalker: атака по ", target.name  # (лог отключён)


func _on_died(_source: Node):
	"""Вызывается при смерти."""
	# Носимый артефакт (поднятый с убитой аномалии) выпадает на месте смерти.
	# Не нёс - остаётся только биомасса.
	if carry_component and carry_component.has_artifact():
		carry_component.drop_artifact()
	died.emit(self)
	
	# Возвращаем биомассу через ZoneController
	var zc = get_tree().get_first_node_in_group("zone_controller")
	if zc and zc.has_method("on_stalker_died"):
		zc.on_stalker_died(self, biomass_return)
	elif zc and zc.has_method("add_biomass"):
		zc.add_biomass(biomass_return)
	
	queue_free()


func _on_damaged(_amount: float, _source: Node, _critical: bool):
	"""Визуальная реакция на получение урона."""
	if visuals:
		# Мигание красным
		var original_modulate = visuals.modulate
		visuals.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(visuals):
			visuals.modulate = original_modulate
	
	# При получении урона есть шанс выронить артефакт
	if carry_component and randf() < 0.3:
		carry_component.try_drop_on_damage()


func _on_threat_detected(threat: Node, type: String):
	if not current_target:
		current_target = threat
		target_acquired.emit(threat, type)
		# "BaseStalker: обнаружена угроза ", type, " - ", threat.name  # (лог отключён)


func _on_threat_lost(threat: Node):
	if current_target == threat:
		current_target = null
		target_lost.emit(threat)
		# "BaseStalker: угроза потеряна - ", threat.name  # (лог отключён)


func _on_artifact_detected(artifact: Node):
	if carry_component and not carry_component.has_artifact():
		if carry_component.can_pick_up(artifact) and navigation_component:
			navigation_component.move_to(artifact.global_position)
			# "BaseStalker: двигаюсь к артефакту"  # (лог отключён)


func _on_artifact_picked_up(artifact: Node):
	var value = artifact.get_value() if artifact.has_method("get_value") else 0
	artifact_picked_up.emit(artifact, value)
	# "BaseStalker: артефакт подобран, ценность ", value  # (лог отключён)


func _on_artifact_dropped(artifact: Node):
	artifact_dropped.emit(artifact)
	# "BaseStalker: артефакт выброшен"  # (лог отключён)


func _on_artifact_stolen(artifact: Node):
	var value = artifact.get_value() if artifact.has_method("get_value") else 0
	artifact_stolen.emit(artifact, value)
	# "BaseStalker: артефакт украден, ценность ", value  # (лог отключён)


# ==================== МЕТОДЫ ДЛЯ ЭФФЕКТОВ АНОМАЛИЙ ====================

func stun(duration: float):
	"""Оглушение сталкера (не может двигаться/атаковать)"""
	is_stunned = true
	stun_timer = duration
	# Останавливаем движение
	if navigation_component:
		navigation_component.stop()
	# "Stalker оглушён на ", duration, " секунд"  # (лог отключён)


func apply_slow(factor: float):
	"""Замедление сталкера (множитель скорости)"""
	slow_factor = factor
	if navigation_component:
		navigation_component.set_speed(speed * slow_factor)
	# "Stalker замедлен, фактор ", factor  # (лог отключён)


func apply_time_dilation(time_scale: float):
	"""Изменение скорости времени для сталкера"""
	time_dilation = time_scale
	if navigation_component:
		navigation_component.set_speed(speed * time_dilation)
	# "Stalker: дилатация времени ", time_scale  # (лог отключён)


func reset_effects():
	"""Сброс всех эффектов"""
	is_stunned = false
	slow_factor = 1.0
	time_dilation = 1.0
	if navigation_component:
		navigation_component.set_speed(speed)
	# "Stalker: эффекты сброшены"  # (лог отключён)


# ==================== ПУБЛИЧНЫЕ МЕТОДЫ ====================

func get_stalker_type() -> String:
	"""Возвращает тип сталкера строкой"""
	return GameEnums.StalkerType.keys()[stalker_type].to_lower()


func get_state_name() -> String:
	"""Возвращает название текущего состояния для отладки"""
	if state_machine:
		return state_machine.get_state_name()
	return "no_state_machine"


func apply_campaign_scaling(hp_mult: float, damage_mult: float, speed_mult: float):
	"""Масштабирование статов параметрами кампании.
	Вызывается SpawnManager'ом ПОСЛЕ add_child - статы уже заданы _ready() ранга."""
	max_health = max_health * hp_mult
	health = max_health
	damage = damage * damage_mult
	speed = speed * speed_mult

	if health_component:
		health_component.max_health = max_health
		health_component.current_health = health
	if navigation_component:
		navigation_component.move_speed = speed


func take_damage(amount: float, source: Node = null):
	"""Получение урона"""
	if health_component:
		health_component.take_damage(amount, source)
	else:
		# Fallback если нет компонента здоровья
		health -= amount
		if health <= 0:
			_on_died(source)


func heal(amount: float) -> float:
	"""Лечение"""
	if health_component:
		return health_component.heal(amount)
	
	# Fallback
	var old_health = health
	health = min(health + amount, max_health)
	return health - old_health


func pick_up_artifact(artifact: Node) -> bool:
	"""Подобрать артефакт"""
	if carry_component:
		return carry_component.pick_up_artifact(artifact)
	return false


func drop_artifact() -> bool:
	"""Выбросить артефакт"""
	if carry_component:
		return carry_component.drop_artifact()
	return false


func has_artifact() -> bool:
	"""Есть ли артефакт"""
	return carry_component and carry_component.has_artifact()


func set_target(target: Node):
	"""Установить цель"""
	current_target = target


func is_alive() -> bool:
	"""Проверка, жив ли сталкер"""
	if health_component:
		return health_component.is_alive
	return health > 0


func get_health_percent() -> float:
	"""Процент здоровья"""
	if health_component:
		return health_component.get_health_percent()
	return health / max_health if max_health > 0 else 0.0


func get_artifact_value() -> int:
	"""Ценность текущего артефакта"""
	if carry_component:
		return carry_component.get_artifact_value()
	return 0


func get_artifact_rarity() -> String:
	"""Редкость текущего артефакта"""
	if carry_component:
		return carry_component.get_artifact_rarity()
	return ""


# ==================== МЕТОДЫ ДЛЯ НАСЛЕДНИКОВ ====================

func _notification(what):
	"""Обработка удаления"""
	if what == NOTIFICATION_PREDELETE:
		# Очищаем ссылки при удалении
		if memory_component:
			memory_component.clear_memory()
