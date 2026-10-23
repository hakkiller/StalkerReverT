# entities/mutants/pseudogiant.gd
extends BaseMutant
class_name PseudogiantMutant

@export var shockwave_radius: float = 10.0
@export var shockwave_damage: float = 40.0
@export var stomp_cooldown: float = 5.0

var can_stomp: bool = true
var stomp_timer: Timer
var is_stomping: bool = false

func _ready():
	health = 400.0
	max_health = 400.0
	speed = 2.5
	damage = 45.0
	armor = 40.0
	biomass_cost = 250.0
	detection_radius = 30.0
	mutant_type = "pseudogiant"
	
	# Целевая высота модели: нормализация по AABB в base_mutant
	model_target_height = 3.2
	super._ready()
	
	stomp_timer = Timer.new()
	stomp_timer.one_shot = true
	stomp_timer.wait_time = stomp_cooldown
	stomp_timer.timeout.connect(_on_stomp_cooldown_ended)
	add_child(stomp_timer)
	
	_setup_label()
	# "Pseudogiant mutant initialized"  # (лог отключён)


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	if is_stomping:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	super._physics_process(delta)


func _patrol(delta):
	# Перф (v0.23.1): скан целей не каждый физ-кадр
	if not _target_scan_tick(delta):
		super._patrol(delta)
		return
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
	
	if can_stomp and not is_stomping:
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < shockwave_radius * 1.5:
			_ground_stomp()
	
	if global_position.distance_to(target_stalker.global_position) < 2.5:
		current_state = State.ATTACK


func _ground_stomp():
	# "Pseudogiant: удар по земле!"  # (лог отключён)
	is_stomping = true
	can_stomp = false
	
	await get_tree().create_timer(0.5).timeout
	
	_create_shockwave()
	
	await get_tree().create_timer(0.5).timeout
	is_stomping = false
	
	stomp_timer.start()


func _create_shockwave():
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	
	for stalker in stalkers:
		if is_instance_valid(stalker):
			var dist = global_position.distance_to(stalker.global_position)
			if dist < shockwave_radius:
				var damage_mult = 1.0 - (dist / shockwave_radius)
				var final_damage = shockwave_damage * damage_mult
				
				stalker.take_damage(final_damage, self)
				attacked_stalker.emit(stalker)
				
				if stalker.has_method("stun"):
					stalker.stun(1.0 * damage_mult)
	
	# "Pseudogiant создал ударную волну!"  # (лог отключён)


func _on_stomp_cooldown_ended():
	can_stomp = true


func _attack(_delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist > 3.0:
		current_state = State.CHASE
		return
	
	if attack_timer.is_stopped():
		target_stalker.take_damage(damage, self)
		attacked_stalker.emit(target_stalker)
		
		if randf() < 0.3 and target_stalker.has_method("stun"):
			target_stalker.stun(0.5)
		
		attack_timer.start()
		# "Pseudogiant атакует!"  # (лог отключён)


func _setup_label():
	var label = Label3D.new()
	label.name = "MutantLabel"
	label.position = Vector3(0, 4.0, 0)  # Очень высоко, потому что гигант
	label.font_size = 30
	label.outline_size = 3
	label.outline_modulate = Color.BLACK
	label.modulate = Color(0.5, 0.2, 0.2)  # темно-красный
	label.text = "👺 ПСЕВДОГИГАНТ"
	add_child(label)
