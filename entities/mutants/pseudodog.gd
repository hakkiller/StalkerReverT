# entities/mutants/pseudodog.gd
extends BaseMutant
class_name PseudodogMutant

@export_enum("Adult", "Grey", "PsyDog") var subspecies: String = "Adult"
@export var howl_cooldown: float = 15.0
@export var pack_attack_bonus: float = 1.5
@export var max_distance_from_monolith: float = 100.0

var can_howl: bool = true
var howl_timer: Timer
var pack_count: int = 0
var _original_speed: float
var _monolith: Node = null
var _last_monolith_check: float = 0.0
var _returning_to_monolith: bool = false


func _ready():
	match subspecies:
		"Adult":
			health = 120.0
			max_health = 120.0
			speed = 7.0
			damage = 25.0
			armor = 10.0
			biomass_cost = 70.0
		"Grey":
			health = 80.0
			max_health = 80.0
			speed = 9.0
			damage = 15.0
			armor = 5.0
			biomass_cost = 50.0
		"PsyDog":
			health = 60.0
			max_health = 60.0
			speed = 8.0
			damage = 20.0
			armor = 0.0
			biomass_cost = 90.0
	
	mutant_type = "pseudodog"
	_original_speed = speed
	
	# Целевая высота модели: нормализация по AABB в base_mutant
	model_target_height = 0.7
	super._ready()
	
	howl_timer = Timer.new()
	howl_timer.one_shot = true
	howl_timer.wait_time = howl_cooldown
	howl_timer.timeout.connect(_on_howl_cooldown_ended)
	add_child(howl_timer)
	
	_setup_label()
	# "Pseudodog mutant initialized: ", subspecies  # (лог отключён)


func _find_monolith() -> Node:
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - _last_monolith_check > 2.0 or not is_instance_valid(_monolith):
		_monolith = get_tree().get_first_node_in_group("monolith")
		_last_monolith_check = current_time
	return _monolith


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	# ПРОВЕРКА ВАЛИДНОСТИ ЦЕЛИ - ЭТО ГЛАВНОЕ ИСПРАВЛЕНИЕ
	if target_stalker and not is_instance_valid(target_stalker):
		target_stalker = null
		current_state = State.PATROL
		if navigation_component:
			navigation_component.stop()
	
	# Проверяем расстояние от монолита
	var monolith = _find_monolith()
	if monolith and is_instance_valid(monolith) and not _returning_to_monolith and not target_stalker:
		var dist_to_monolith = global_position.distance_to(monolith.global_position)
		if dist_to_monolith > max_distance_from_monolith:
			# Возвращаемся ближе к монолиту
			_returning_to_monolith = true
			var dir_to_monolith = (monolith.global_position - global_position).normalized()
			var target_pos = monolith.global_position + dir_to_monolith * (max_distance_from_monolith * 0.7)
			if navigation_component:
				navigation_component.move_to(target_pos)
				# "Pseudodog возвращается к монолиту"  # (лог отключён)
			return
	
	# Если мы возвращались и уже достаточно близко - сбрасываем флаг
	if _returning_to_monolith and monolith and is_instance_valid(monolith):
		var dist_to_monolith = global_position.distance_to(monolith.global_position)
		if dist_to_monolith < max_distance_from_monolith * 0.8:
			_returning_to_monolith = false
			if navigation_component:
				navigation_component.stop()
	
	# Обновляем стайный бонус
	pack_count = _count_nearby_pseudodogs()
	if pack_count > 0:
		speed = _original_speed * (1.0 + pack_count * 0.1)
	else:
		speed = _original_speed
	
	if subspecies == "PsyDog" and can_howl and current_state == State.CHASE:
		_try_psy_howl()
	
	# Если не возвращаемся к монолиту, работаем как обычно
	if not _returning_to_monolith:
		super._physics_process(delta)
	else:
		# NavigationComponent обновляется сам, здесь только физика
		move_and_slide()


func _count_nearby_pseudodogs() -> int:
	var count = 0
	var mutants = get_tree().get_nodes_in_group("mutants")
	
	for mutant in mutants:
		if mutant == self or not is_instance_valid(mutant):
			continue
		if mutant is PseudodogMutant and global_position.distance_to(mutant.global_position) < 15.0:
			count += 1
	
	return count


func _patrol(delta):
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	var nearest_stalker = null
	var nearest_dist = INF
	
	for stalker in stalkers:
		if not is_instance_valid(stalker):
			continue
		
		var dist = global_position.distance_to(stalker.global_position)
		if dist < detection_radius and dist < nearest_dist:
			nearest_dist = dist
			nearest_stalker = stalker
	
	if nearest_stalker:
		target_stalker = nearest_stalker
		current_state = State.CHASE
		_returning_to_monolith = false
		# "Pseudodog нашёл цель: ", nearest_stalker.name  # (лог отключён)
	
	super._patrol(delta)


func _chase(delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		target_stalker = null
		if navigation_component:
			navigation_component.stop()
		return
	
	# Используем навигацию для преследования
	if navigation_component:
		navigation_component.move_to(target_stalker.global_position)
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist < 2.0:
		current_state = State.ATTACK
	elif dist < 5.0 and randf() < 0.01:
		_flank_target()
	
	super._chase(delta)


func _flank_target():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	var to_target = (target_stalker.global_position - global_position).normalized()
	var right = Vector3(to_target.z, 0, -to_target.x).normalized()
	
	if randf() > 0.5:
		right = -right
	
	var flank_dir = (to_target + right * 0.5).normalized()
	
	# Временно отключаем навигацию для фланга
	if navigation_component:
		navigation_component.stop()
	
	velocity.x = flank_dir.x * speed
	velocity.z = flank_dir.z * speed
	# "Pseudodog фланкирует!"  # (лог отключён)


func _try_psy_howl():
	if not target_stalker or not is_instance_valid(target_stalker) or randf() > 0.05:
		return
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist < detection_radius:
		_psy_howl()


func _psy_howl():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	# "Pseudodog использует пси-вой!"  # (лог отключён)
	can_howl = false
	
	if target_stalker.has_method("stun"):
		target_stalker.stun(2.0)
	
	target_stalker.take_damage(damage * 0.5, self)
	
	howl_timer.start()


func _on_howl_cooldown_ended():
	can_howl = true


func _attack(delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		target_stalker = null
		return
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist > 2.0:
		current_state = State.CHASE
		return
	
	var total_damage = damage * (1.0 + pack_count * pack_attack_bonus * 0.2)
	
	if attack_timer.is_stopped():
		target_stalker.take_damage(total_damage, self)
		attacked_stalker.emit(target_stalker)
		attack_timer.start()
		# "Pseudodog атакует! Урон: ", total_damage  # (лог отключён)
	
	super._attack(delta)


func _setup_label():
	var label = Label3D.new()
	label.name = "MutantLabel"
	label.position = Vector3(0, 2.5, 0)
	label.font_size = 24
	label.outline_size = 2
	label.outline_modulate = Color.BLACK
	label.modulate = Color(0.6, 0.4, 0.2)
	label.text = "🐺 ПСЕВДОСОБАКА"
	add_child(label)
