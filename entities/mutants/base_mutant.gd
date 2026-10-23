# entities/mutants/base_mutant.gd
extends CharacterBody3D
class_name BaseMutant

signal died(mutant: BaseMutant)
signal attacked_stalker(stalker: Node3D)
signal spotted_stalker(stalker: Node3D)

@export var health: float = 100.0
@export var max_health: float = 100.0
@export var speed: float = 5.0
@export var damage: float = 20.0
@export var armor: float = 0.0
@export var detection_radius: float = 20.0
@export var attack_cooldown: float = 1.0
@export var biomass_cost: float = 50.0
@export var mutant_type: String = "base"
@export var gravity: float = 15.0
# >0 - мутант летает: держится на этой высоте над землёй (полтергейст)
@export var hover_height: float = 0.0

enum State { PATROL, CHASE, ATTACK, DEAD }
var current_state: State = State.PATROL
var target_stalker: Node3D = null
var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0

# Патруль вокруг точки спавна
@export var patrol_radius: float = 12.0
@export var patrol_points_count: int = 5
# Поводок: погоня дальше этого радиуса от точки спавна прекращается
@export var leash_radius: float = 40.0
var _spawn_position: Vector3 = Vector3.ZERO
# Процедурная анимация статичной модели (models/*.glb)
var _model_base_y: float = 0.0
var _model_skeletal: bool = false
# Отключить боди-боб (мутант анимирует кости сам, напр. галоп химеры)
var disable_body_bob := false  # у модели есть риг и AnimationPlayer
var _air_time: float = 0.0
var _stuck_pos: Vector3 = Vector3.ZERO
var _stuck_time: float = 0.0
# Перф (v0.23.1): поиск целей не каждый физ-кадр — толпа мутантов x сталкеры
# превращалась в O(N*M)*60fps. Скан не чаще 0.35с, фаза сдвинута случайно.
const TARGET_SCAN_INTERVAL: float = 0.35
var _target_scan_cd: float = 0.0

# Скелетная анимация (модели models/animals/* и кровосос):
# клипы подбираются по суффиксам имён («AnimalArmature|Walk» -> Walk)
# 0 = не нормализовать размер
@export var model_target_height: float = 0.0
# Разворот модели к направлению движения (у большинства экспортов +Z вперёд)
@export var model_yaw_degrees: float = 180.0
# false - наследник сам управляет AnimationPlayer (кровосос)
var use_builtin_clip_player: bool = true
var _anim: AnimationPlayer
var _clip_idle: String = ""
var _clip_move: String = ""
var _clip_run: String = ""
var _clip_attack: String = ""
var _clip_death: String = ""
var _current_clip: String = ""

# Множители статов (лаборатория + звёздность), задаётся до add_child,
# применяются в _ready() после статов наследника
var _stat_health_mult: float = 1.0
var _stat_damage_mult: float = 1.0
# Звёзды этого типа (1-5): для подписи и эффектов
var star_level: int = 1

# Навигационный компонент
var navigation_component: NavigationComponent
var zone_controller: Node = null

@onready var detection_area: Area3D = $DetectionArea
@onready var attack_timer: Timer = $AttackTimer


func _ready():
	if not detection_area:
		push_error("Mutant: DetectionArea не найден!")
		return
	
	if not attack_timer:
		push_error("Mutant: AttackTimer не найден!")
		return
	
	# Создаем навигационный компонент
	_setup_navigation_component()
	
	detection_area.body_entered.connect(_on_stalker_detected)
	detection_area.body_exited.connect(_on_stalker_lost)
	
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_cooldown_ended)
	
	add_to_group("mutants")
	
	# Генерируем точки патруля вокруг места появления
	_generate_patrol_points()
	
	zone_controller = get_tree().get_first_node_in_group("zone_controller")
	if zone_controller and zone_controller.has_method("register_mutant"):
		zone_controller.register_mutant(self)
	
	# Запомнить базовую высоту модели для процедурной анимации
	var model := get_node_or_null("Model")
	if model:
		_model_base_y = model.position.y
		_model_skeletal = not model.find_children("*", "AnimationPlayer", true, false).is_empty()
		if _model_skeletal:
			_setup_skeletal_animation(model)
			_model_base_y = model.position.y
	
	health = max_health
	
	# Множители применяются последними: наследник уже задал базовые статы
	if _stat_health_mult != 1.0:
		max_health *= _stat_health_mult
		health = max_health
	if _stat_damage_mult != 1.0:
		damage *= _stat_damage_mult
	
	# Звёзды в подписи - после того как наследник настроит Label3D
	_apply_star_label.call_deferred()


func set_health_multiplier(value: float):
	_stat_health_mult = value


func set_damage_multiplier(value: float):
	_stat_damage_mult = value


func set_star_level(stars: int):
	star_level = maxi(stars, 1)


func _apply_star_label():
	"""Дописываем звёзды к подписи мутанта (если она есть)"""
	if star_level <= 1:
		return
	var label = get_node_or_null("Label3D")
	if not label:
		var found = find_children("*", "Label3D", false, false)
		if not found.is_empty():
			label = found[0]
	if label:
		label.text += " " + "★".repeat(star_level)


# ==================== ЭКСКЛЮЗИВНЫЙ ВАРИАНТ (ЧЁРНЫЙ ЯЩИК) ====================

var _variant_type: String = ""
var _variant_name: String = ""
var _variant_tint: Color = Color.WHITE
var _variant_speed_mult: float = 1.0
var _variant_accent: Color = Color.WHITE


## Вариант окраса/имени для эксклюзивных мутантов трека наград.
## Зовётся из spawn_manager ДО add_child: перекраска и имя применяются
## после _ready наследника (deferred), звёзды допишутся поверх имени.
func apply_exclusive_variant(type: String, display_name: String, tint: Color, speed_mult: float = 1.0, accent: Color = Color.WHITE) -> void:
	_variant_type = type
	_variant_name = display_name
	_variant_tint = tint
	_variant_speed_mult = speed_mult
	_variant_accent = accent
	_apply_variant_look.call_deferred()


func _apply_variant_look():
	# deferred: наследник успевает отработать _ready (перетирает тип/скорость) —
	# теперь эксклюзив закрепляется поверх.
	if not _variant_type.is_empty():
		mutant_type = _variant_type
	if not is_equal_approx(_variant_speed_mult, 1.0):
		speed *= _variant_speed_mult
	if _variant_tint != Color.WHITE:
		_tint_model(_variant_tint)
	if _variant_name.is_empty():
		return
	var label = get_node_or_null("Label3D")
	if not label:
		var found = find_children("*", "Label3D", false, false)
		if not found.is_empty():
			label = found[0]
	if label:
		label.text = _variant_name
		if _variant_accent != Color.WHITE:
			label.modulate = _variant_accent


func _tint_model(tint: Color):
	"""Умножает albedo всех материалов модели на tint (общие ресурсы не трогаем)."""
	var stack: Array = [self]
	while not stack.is_empty():
		var node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for si in range(mi.mesh.get_surface_count()):
			var mat := mi.get_active_material(si)
			var base_mat := mat as BaseMaterial3D
			if base_mat == null:
				continue
			var dup: BaseMaterial3D = base_mat.duplicate()
			dup.albedo_color = Color(
				base_mat.albedo_color.r * tint.r,
				base_mat.albedo_color.g * tint.g,
				base_mat.albedo_color.b * tint.b,
				base_mat.albedo_color.a)
			mi.set_surface_override_material(si, dup)


# ==================== СКЕЛЕТНАЯ АНИМАЦИЯ ====================
# Модели из models/animals/* (CC0, Quaternius): все клипы внутри модели,
# имена вида «AnimalArmature|Walk». Проигрыватель общий для всех мутантов.

func _setup_skeletal_animation(model: Node3D):
	"""Нормализует размер модели и подбирает клипы по суффиксам имён"""
	var players = model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_anim = players[0]
	_model_skeletal = true

	var names := _anim.get_animation_list()
	_clip_death = _match_clip(names, ["death"])
	_clip_move = _match_clip(names, ["walk", "fast_flying"])
	_clip_run = _match_clip(names, ["run", "gallop"])
	_clip_attack = _match_clip(names, ["punch", "attack_headbutt", "attack_kick", "attack", "bite_front", "headbutt"])
	_clip_idle = _match_clip(names, ["idle"])

	# Циклические - передвижение и стойки, одиночные - атаки/смерть/реакции
	for n in names:
		var low := n.to_lower()
		var one_shot := low.ends_with("attack") or low.ends_with("punch") \
			or low.ends_with("death") or low.ends_with("bite_front") \
			or low.ends_with("headbutt") or low.contains("hitreact")
		_anim.get_animation(n).loop_mode = Animation.LOOP_NONE if one_shot else Animation.LOOP_LINEAR

	# Повтор одиночного клипа (атаки) доступен сразу после завершения
	_anim.animation_finished.connect(func(_name): _current_clip = "")

	# Нормализация размера: локальный AABB модели -> целевая высота, ноги на землю
	if model_target_height > 0.0:
		var aabb := _compute_model_aabb(model)
		if aabb.size.y > 0.001:
			var s := model_target_height / aabb.size.y
			model.scale = Vector3.ONE * s
			model.rotation.y = deg_to_rad(model_yaw_degrees)
			model.position.y = _model_base_y - aabb.position.y * s


func _match_clip(names: PackedStringArray, suffixes: Array) -> String:
	for suffix in suffixes:
		for n in names:
			if n.to_lower().ends_with(suffix):
				return n
	return ""


func _compute_model_aabb(model: Node3D) -> AABB:
	"""Габариты модели в её локальном пространстве (до масштабирования)"""
	var result := AABB()
	var first := true
	var inv := model.global_transform.affine_inverse()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var rel: Transform3D = inv * mi.global_transform
		var box: AABB = rel * mi.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _update_skeletal_anim():
	"""Состояние -> клип: патруль идёт, погоня бежит, атака бьёт"""
	if _anim == null or not use_builtin_clip_player:
		return
	if current_state == State.DEAD:
		return

	var want := ""
	match current_state:
		State.ATTACK:
			want = _clip_attack if _clip_attack != "" else _clip_idle
		State.CHASE:
			want = _clip_run if _clip_run != "" else _clip_move
		State.PATROL:
			var moving := Vector2(velocity.x, velocity.z).length() > 0.6
			want = _clip_move if moving else _clip_idle

	if want != "" and want != _current_clip and _anim.has_animation(want):
		_anim.play(want, 0.2)
		_current_clip = want


func _ground_below_y() -> float:
	"""Высота земли под мутантом (для парения). Рей вниз с маской рельефа."""
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.0,
		global_position + Vector3.DOWN * 12.0, 1)
	var hit := space.intersect_ray(query)
	if hit and hit.has("position"):
		return hit["position"].y
	return _spawn_position.y


func _setup_navigation_component():
	# Создаем NavigationAgent3D если его нет
	var nav_agent = get_node_or_null("NavigationAgent3D")
	if not nav_agent:
		nav_agent = NavigationAgent3D.new()
		nav_agent.name = "NavigationAgent3D"
		add_child(nav_agent)
	
	# Создаем компонент навигации
	navigation_component = NavigationComponent.new()
	navigation_component.entity = self
	navigation_component.nav_agent = nav_agent
	navigation_component.move_speed = speed
	add_child(navigation_component)
	# "NavigationComponent добавлен для мутанта"  # (лог отключён)


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	# Гравитация или парение (летающие мутанты держат высоту над рельефом)
	if hover_height > 0.0:
		var target_y := _ground_below_y() + hover_height
		velocity.y = clampf((target_y - global_position.y) * 2.5, -2.5, 2.5)
	elif not is_on_floor():
		velocity.y -= gravity * delta
	
	# NavigationComponent обновляется сам в своём _physics_process
	
	match current_state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase(delta)
		State.ATTACK:
			_attack(delta)
	
	# Плавный разворот в сторону движения (для моделей)
	var horizontal := Vector2(velocity.x, velocity.z)
	if horizontal.length() > 0.5:
		var target_yaw := atan2(-horizontal.x, -horizontal.y)
		rotation.y = lerp_angle(rotation.y, target_yaw, 8.0 * delta)
	
	# Антизастревание: 6 секунд на месте (в т.ч. на крыше дома) - телепорт домой
	if global_position.distance_to(_stuck_pos) < 0.15 and current_state != State.DEAD:
		_stuck_time += delta
	else:
		_stuck_pos = global_position
		_stuck_time = 0.0
	if _stuck_time > 6.0:
		_stuck_time = 0.0
		global_position = _spawn_position + Vector3(randf_range(-2, 2), 1.0, randf_range(-2, 2))
		if navigation_component:
			navigation_component.stop()
		current_state = State.PATROL
		patrol_points.clear()
		_generate_patrol_points()
		# print("Мутант: застрял - возвращён на точку спавна")
	
	# Скелетная анимация: состояние -> клип
	_update_skeletal_anim()

	# Процедурная анимация статичной модели (скелетная анимирует сама себя)
	var model := get_node_or_null("Model")
	if model and not _model_skeletal and not disable_body_bob:
		var t := Time.get_ticks_msec() / 1000.0
		# Воздух-наклон после 0.3с в воздухе: у земли is_on_floor мигает на кочках
		_air_time = 0.0 if is_on_floor() else _air_time + delta
		if _air_time > 0.3:
			model.rotation.x = lerp_angle(model.rotation.x, clampf(velocity.y * 0.04, -0.2, 0.2), 2.0 * delta)
		elif horizontal.length() > 0.5:
			# бег: подпрыгивание + крен + лёгкий наклон носа вниз
			var gait: float = clampf(horizontal.length() / 6.0, 0.4, 1.5)
			model.position.y = _model_base_y + absf(sin(t * horizontal.length() * 2.4)) * 0.08 * gait
			model.rotation.z = sin(t * horizontal.length() * 1.2) * 0.05
			model.rotation.x = lerp_angle(model.rotation.x, -0.10, 3.0 * delta)
		else:
			# стойка: дыхание
			model.position.y = _model_base_y + sin(t * 1.8) * 0.02
			model.rotation.z = lerp_angle(model.rotation.z, 0.0, 3.0 * delta)
			model.rotation.x = lerp_angle(model.rotation.x, 0.0, 3.0 * delta)
	
	move_and_slide()


func _generate_patrol_points():
	"""Точки патруля в радиусе patrol_radius от точки спавна"""
	_spawn_position = global_position
	patrol_points.clear()
	for i in range(patrol_points_count):
		var angle = TAU * i / patrol_points_count + randf_range(-0.4, 0.4)
		var dist = patrol_radius * randf_range(0.4, 1.0)
		var pos = _spawn_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		patrol_points.append(pos)


func _patrol(_delta):
	if patrol_points.is_empty():
		# Если нет точек патруля, просто стоим
		if navigation_component and not navigation_component.is_navigating():
			# Ищем сталкеров
			# Ищем сталкеров (редко: перф толпы, v0.23.1)
			if _target_scan_tick(_delta):
				_find_best_target()
		return
	
	var target_pos = patrol_points[current_patrol_index]
	
	# Используем навигацию для движения к точке патруля
	if navigation_component and not navigation_component.is_navigating():
		navigation_component.move_to(target_pos)
	
	# Прибытие по горизонтали: вертикальные 1.8м до навмеша съедали порог
	# и превращали подход к точке в ползание с "цель достигнута" каждый кадр
	var to_point = target_pos - global_position
	if Vector2(to_point.x, to_point.z).length() < 1.5:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		if navigation_component:
			navigation_component.move_to(patrol_points[current_patrol_index])
	
	# В патруле тоже ищем цели
	if _target_scan_tick(_delta):
		_find_best_target()


func _chase(_delta):
	if not target_stalker or not is_instance_valid(target_stalker) or (target_stalker.has_method("is_alive") and not target_stalker.is_alive()):
		if _target_scan_tick(_delta):
			_find_best_target()
		if not target_stalker:
			current_state = State.PATROL
			target_stalker = null
			if navigation_component:
				navigation_component.stop()
		return
	
	var to_target = target_stalker.global_position - global_position
	var horizontal_dist = Vector2(to_target.x, to_target.z).length()
	if horizontal_dist < 2.0:
		current_state = State.ATTACK
		_try_attack()
	elif horizontal_dist < 2.6:
		# Мёртвая зона навигации (в 2.5м путь сразу finished): идём напрямую
		var dir = Vector3(to_target.x, 0.0, to_target.z).normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	elif horizontal_dist > detection_radius * 1.5:
		# Потеряли цель
		target_stalker = null
		current_state = State.PATROL
		if navigation_component and navigation_component.is_navigating():
			navigation_component.stop()


func _attack(_delta):
	if not target_stalker or not is_instance_valid(target_stalker) or (target_stalker.has_method("is_alive") and not target_stalker.is_alive()):
		current_state = State.PATROL
		target_stalker = null
		if navigation_component:
			navigation_component.stop()
		return
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist > 3.0:
		current_state = State.CHASE
		return
	
	# Не двигаемся во время атаки
	if navigation_component and navigation_component.is_navigating():
		navigation_component.stop()
	
	velocity.x = 0
	velocity.z = 0
	
	# Пытаемся атаковать
	_try_attack()


func _find_best_target():
	# У кромки повадка новую цель не берём: сначала возвращаемся к дому
	if _spawn_position.distance_to(global_position) > leash_radius * 0.85:
		return
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	var nearest = null
	var nearest_dist = INF
	
	for s in stalkers:
		if not is_instance_valid(s):
			continue
		if s == self:
			continue
		if s.has_method("is_alive") and not s.is_alive():
			continue
		
		var dist = global_position.distance_to(s.global_position)
		if dist < detection_radius and dist < nearest_dist:
			nearest_dist = dist
			nearest = s
	
	if nearest:
		target_stalker = nearest
		current_state = State.CHASE
		spotted_stalker.emit(nearest)
		# "Мутант нашёл цель: ", nearest.name  # (лог отключён)


## Общий троттлинг скана целей (v0.23.1): не чаще TARGET_SCAN_INTERVAL секунд.
## Фаза сдвинута randf() — толпа не сканирует в одном и том же кадре. true = пора.
func _target_scan_tick(delta: float) -> bool:
	_target_scan_cd -= delta
	if _target_scan_cd > 0.0:
		return false
	_target_scan_cd = TARGET_SCAN_INTERVAL + randf() * 0.1
	return true


func _on_stalker_detected(body: Node3D):
	if not is_instance_valid(body):
		return
		
	if body.has_method("take_damage") and body.is_in_group("stalkers"):
		# Если у сталкера есть артефакт - сразу в приоритет
		if body.has_method("has_artifact") and body.has_artifact():
			target_stalker = body
			current_state = State.CHASE
			spotted_stalker.emit(body)
		# Иначе если нет цели или новая цель ближе
		elif not target_stalker or not is_instance_valid(target_stalker) or (target_stalker.has_method("is_alive") and not target_stalker.is_alive()):
			target_stalker = body
			current_state = State.CHASE
			spotted_stalker.emit(body)
		else:
			var dist_to_new = global_position.distance_to(body.global_position)
			var dist_to_current = global_position.distance_to(target_stalker.global_position)
			if dist_to_new < dist_to_current:
				target_stalker = body
				spotted_stalker.emit(body)


func _on_stalker_lost(body: Node3D):
	if body == target_stalker:
		_find_best_target()


func _try_attack():
	if current_state != State.ATTACK:
		return
	
	if not target_stalker or not is_instance_valid(target_stalker) or (target_stalker.has_method("is_alive") and not target_stalker.is_alive()):
		return
	
	if attack_timer.time_left > 0:
		return
	
	if target_stalker.has_method("take_damage"):
		target_stalker.take_damage(damage, self)
		attacked_stalker.emit(target_stalker)
		attack_timer.start()
		# Удар: одиночный клип, после завершения обновление вернёт стойку/бег
		if _anim and _clip_attack != "" and use_builtin_clip_player:
			_anim.play(_clip_attack, 0.1)
			_current_clip = _clip_attack


func _on_attack_cooldown_ended():
	# Можно атаковать снова
	pass


func take_damage(dmg: float, _source = null):
	var actual_damage = max(dmg - armor, 1.0)
	health -= actual_damage
	
	if health <= 0:
		die()


func die():
	if current_state == State.DEAD:
		return

	current_state = State.DEAD

	# Клип смерти: труп лежит, пока клип не доиграет (1..3 с)
	var corpse_time := 1.0
	if _anim and _clip_death != "" and use_builtin_clip_player and _anim.has_animation(_clip_death):
		_anim.play(_clip_death, 0.15)
		_current_clip = _clip_death
		corpse_time = clampf(_anim.get_animation(_clip_death).length, 1.0, 3.0)

	if zone_controller and zone_controller.has_method("add_biomass"):
		zone_controller.add_biomass(biomass_cost * 0.5)

	died.emit(self)

	var timer = Timer.new()
	timer.wait_time = corpse_time
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()


func set_patrol_points(points: Array[Vector3]):
	patrol_points = points
	current_patrol_index = 0


func _exit_tree():
	if zone_controller and zone_controller.has_method("unregister_mutant"):
		zone_controller.unregister_mutant(self)
