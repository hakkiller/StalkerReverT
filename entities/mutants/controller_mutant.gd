# entities/mutants/controller_mutant.gd
extends BaseMutant
class_name ControllerMutant

@export var control_range: float = 15.0
@export var control_duration: float = 5.0
@export var control_cooldown: float = 10.0

var control_timer: Timer
var is_controlling: bool = false
var controlled_stalker: Node3D = null
var can_control: bool = true

func _ready():
	health = 80.0
	max_health = 80.0
	speed = 4.0
	damage = 0.0
	armor = 10.0
	biomass_cost = 100.0
	mutant_type = "controller"
	
	# Целевая высота модели: нормализация по AABB в base_mutant
	model_target_height = 1.8
	super._ready()
	
	control_timer = Timer.new()
	control_timer.one_shot = true
	control_timer.timeout.connect(_on_control_ended)
	add_child(control_timer)
	
	_setup_label()
	# "Controller mutant initialized"  # (лог отключён)


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	if is_controlling:
		velocity = Vector3.ZERO
		move_and_slide()
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
	velocity = direction * speed
	
	if can_control and not is_controlling:
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < control_range:
			_try_control()
	
	if global_position.distance_to(target_stalker.global_position) < 2.0:
		current_state = State.ATTACK


func _try_control():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	# "Controller пытается взять контроль!"  # (лог отключён)
	is_controlling = true
	can_control = false
	controlled_stalker = target_stalker
	current_state = State.ATTACK
	
	_apply_control_effect(target_stalker)
	
	control_timer.wait_time = control_duration
	control_timer.start()


func _apply_control_effect(stalker: Node3D):
	if stalker.has_method("set_controlled"):
		stalker.set_controlled(true, self)
		# "Controller взял под контроль!"  # (лог отключён)


func _on_control_ended():
	if is_instance_valid(controlled_stalker) and controlled_stalker.has_method("set_controlled"):
		controlled_stalker.set_controlled(false, self)
		# "Controller отпустил контроль"  # (лог отключён)
	
	is_controlling = false
	controlled_stalker = null
	
	await get_tree().create_timer(control_cooldown).timeout
	can_control = true
	
	if is_instance_valid(target_stalker):
		current_state = State.CHASE
	else:
		current_state = State.PATROL


func _attack(_delta):
	if is_controlling:
		velocity = Vector3.ZERO
		return
	
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist > 2.0:
		current_state = State.CHASE
		return
	
	if can_control and not is_controlling and control_timer.is_stopped():
		_try_control()


func take_damage(dmg: float, source = null):
	if is_controlling and randf() < 0.3:
		# "Контроль прерван уроном!"  # (лог отключён)
		control_timer.stop()
		_on_control_ended()
	
	super.take_damage(dmg, source)


func _setup_label():
	var label = Label3D.new()
	label.name = "MutantLabel"
	label.position = Vector3(0, 2.8, 0)
	label.font_size = 24
	label.outline_size = 2
	label.outline_modulate = Color.BLACK
	label.modulate = Color(0.8, 0.4, 1.0)  # сиреневый
	label.text = "🧙 КОНТРОЛЛЕР"
	add_child(label)
