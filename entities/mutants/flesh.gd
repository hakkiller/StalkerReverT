# entities/mutants/flesh.gd
extends BaseMutant
class_name FleshMutant

@export var aggression_threshold: float = 30.0
@export var charge_speed: float = 15.0
@export var charge_damage: float = 35.0
@export var charge_cooldown: float = 5.0

var accumulated_damage: float = 0.0
var can_charge: bool = true
var is_charging: bool = false
var charge_target: Vector3
var charge_timer: Timer

func _ready():
	health = 200.0
	max_health = 200.0
	speed = 6.0
	damage = 15.0
	armor = 20.0
	biomass_cost = 60.0
	mutant_type = "flesh"
	
	# Целевая высота модели: нормализация по AABB в base_mutant
	model_target_height = 1.6
	super._ready()
	
	charge_timer = Timer.new()
	charge_timer.one_shot = true
	charge_timer.wait_time = charge_cooldown
	charge_timer.timeout.connect(_on_charge_cooldown_ended)
	add_child(charge_timer)
	
	_setup_label()
	# "Flesh mutant initialized"  # (лог отключён)


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	if is_charging:
		_handle_charge(delta)
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
		accumulated_damage = 0.0
		# "Flesh стал агрессивным!"  # (лог отключён)
	
	super._patrol(delta)


func _chase(_delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	var direction = (target_stalker.global_position - global_position).normalized()
	velocity = direction * speed
	
	if can_charge and not is_charging:
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < 10.0 and dist > 4.0:
			_start_charge()
	
	if global_position.distance_to(target_stalker.global_position) < 2.0:
		current_state = State.ATTACK


func _start_charge():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	# "Flesh начинает таран!"  # (лог отключён)
	is_charging = true
	can_charge = false
	charge_target = target_stalker.global_position
	
	charge_timer.start()


func _handle_charge(_delta):
	if is_instance_valid(target_stalker):
		charge_target = target_stalker.global_position
	
	var direction = (charge_target - global_position).normalized()
	velocity = direction * charge_speed
	velocity.y = 0
	
	move_and_slide()
	
	if is_on_wall() or global_position.distance_to(charge_target) < 2.0:
		_end_charge()


func _end_charge():
	# "Flesh закончил таран!"  # (лог отключён)
	is_charging = false
	
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	for stalker in stalkers:
		if is_instance_valid(stalker):
			var dist = global_position.distance_to(stalker.global_position)
			if dist < 4.0:
				stalker.take_damage(charge_damage, self)
				attacked_stalker.emit(stalker)
				# "Flesh нанёс урон тараном!"  # (лог отключён)
	
	if is_instance_valid(target_stalker):
		current_state = State.CHASE
	else:
		current_state = State.PATROL


func _on_charge_cooldown_ended():
	can_charge = true


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
		# "Flesh атакует!"  # (лог отключён)


func take_damage(dmg: float, source = null):
	accumulated_damage += dmg
	
	if accumulated_damage > aggression_threshold and current_state == State.PATROL:
		current_state = State.CHASE
		accumulated_damage = 0.0
		# "Flesh разъярен!"  # (лог отключён)
	
	super.take_damage(dmg, source)


func _setup_label():
	var label = Label3D.new()
	label.name = "MutantLabel"
	label.position = Vector3(0, 2.8, 0)  # Выше, потому что плоть крупная
	label.font_size = 24
	label.outline_size = 2
	label.outline_modulate = Color.BLACK
	label.modulate = Color(0.9, 0.5, 0.5)  # розовый
	label.text = "🐗 ПЛОТЬ"
	add_child(label)
