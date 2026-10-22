# entities/mutants/snork_mutant.gd
extends BaseMutant
class_name SnorkMutant

@export var jump_force: float = 10.0
@export var jump_cooldown: float = 3.0
@export var jump_range: float = 8.0
@export var leap_damage_multiplier: float = 1.5
@export var max_jump_height: float = 5.0  # Максимальная высота прыжка

var can_jump: bool = true
var is_jumping: bool = false
var jump_target: Vector3
var jump_timer: Timer
var _jump_start_time: float = 0.0
var _jump_duration: float = 1.5

func _ready():
	health = 120.0
	max_health = 120.0
	speed = 6.0
	damage = 30.0
	armor = 5.0
	biomass_cost = 60.0
	mutant_type = "snork"
	
	# Целевая высота модели: нормализация по AABB в base_mutant
	model_target_height = 1.7
	super._ready()
	
	jump_timer = Timer.new()
	jump_timer.one_shot = true
	jump_timer.wait_time = jump_cooldown
	jump_timer.timeout.connect(_on_jump_cooldown_ended)
	add_child(jump_timer)
	
	_setup_label()
	# "Snork mutant initialized"  # (лог отключён)


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	if is_jumping:
		_handle_jump(delta)
		return
	
	super._physics_process(delta)


func _patrol(delta):
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	var nearest_stalker = null
	var nearest_dist = INF
	
	for stalker in stalkers:
		if is_instance_valid(stalker):
			var dist = global_position.distance_to(stalker.global_position)
			if dist < detection_radius and dist < nearest_dist:
				nearest_dist = dist
				nearest_stalker = stalker
	
	if nearest_stalker:
		target_stalker = nearest_stalker
		current_state = State.CHASE
	
	super._patrol(delta)


func _chase(_delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	var direction = (target_stalker.global_position - global_position).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
	if can_jump and not is_jumping:
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < jump_range and dist > 3.0:
			_try_jump()
	
	if global_position.distance_to(target_stalker.global_position) < 2.0:
		current_state = State.ATTACK


func _try_jump():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	# "Snork прыгает!"  # (лог отключён)
	jump_target = target_stalker.global_position
	is_jumping = true
	can_jump = false
	_jump_start_time = Time.get_ticks_msec() / 1000.0
	
	jump_timer.start()


func _handle_jump(_delta):
	var jump_progress = min(1.0, (Time.get_ticks_msec() / 1000.0 - _jump_start_time) / _jump_duration)
	
	if is_instance_valid(target_stalker):
		jump_target = target_stalker.global_position
	
	var direction = (jump_target - global_position).normalized()
	
	# Уменьшаем скорость к концу прыжка
	var current_jump_force = jump_force * (1.0 - jump_progress * 0.5)
	velocity.x = direction.x * current_jump_force
	velocity.z = direction.z * current_jump_force
	
	# Ограничиваем вертикальную скорость
	velocity.y = min(direction.y * current_jump_force * 0.5 + 2.0, max_jump_height)
	
	move_and_slide()
	
	# Условия окончания прыжка
	var hit_ground = is_on_floor() and velocity.y <= 0
	var max_height_reached = global_position.y > jump_target.y + max_jump_height
	var time_expired = jump_progress >= 1.0
	
	if hit_ground or max_height_reached or time_expired:
		_land()


func _land():
	is_jumping = false
	velocity.y = 0
	
	if is_instance_valid(target_stalker):
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < 3.0:
			target_stalker.take_damage(damage * leap_damage_multiplier, self)
			attacked_stalker.emit(target_stalker)
			# "Snork атакует с прыжка!"  # (лог отключён)
	
	if is_instance_valid(target_stalker):
		if global_position.distance_to(target_stalker.global_position) < 2.0:
			current_state = State.ATTACK
		else:
			current_state = State.CHASE
	else:
		current_state = State.PATROL


func _on_jump_cooldown_ended():
	can_jump = true


func _attack(_delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist > 2.0:
		current_state = State.CHASE
		return
	
	if attack_timer.is_stopped():
		target_stalker.take_damage(damage, self)
		attacked_stalker.emit(target_stalker)
		attack_timer.start()
		# "Snork атакует!"  # (лог отключён)
		
		if randf() < 0.3:
			_jump_away()


func _jump_away():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	var away = (global_position - target_stalker.global_position).normalized()
	jump_target = global_position + away * 5.0
	is_jumping = true
	can_jump = false
	_jump_start_time = Time.get_ticks_msec() / 1000.0
	velocity.y = 2.0
	jump_timer.start()
	# "Snork отпрыгивает!"  # (лог отключён)


func _setup_label():
	var label = Label3D.new()
	label.name = "MutantLabel"
	label.position = Vector3(0, 2.5, 0)
	label.font_size = 24
	label.outline_size = 2
	label.outline_modulate = Color.BLACK
	label.modulate = Color(1.0, 0.4, 0.2)  # оранжевый
	label.text = "👹 СНОРК"
	add_child(label)
