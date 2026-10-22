# entities/mutants/zombie.gd
extends BaseMutant
class_name ZombieMutant

@export var rage_threshold: float = 50.0
@export var infection_chance: float = 0.2

var accumulated_rage: float = 0.0
var is_raging: bool = false

func _ready():
	health = 180.0
	max_health = 180.0
	speed = 2.0
	damage = 10.0
	armor = 15.0
	biomass_cost = 30.0
	mutant_type = "zombie"
	
	# Целевая высота модели: нормализация по AABB в base_mutant
	model_target_height = 1.7
	super._ready()
	
	_setup_label()
	# "Zombie mutant initialized"  # (лог отключён)


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	if accumulated_rage > rage_threshold and not is_raging:
		_become_raging()
	
	if is_raging:
		speed = 4.0
	else:
		speed = 2.0
	
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
	
	if global_position.distance_to(target_stalker.global_position) < 1.5:
		current_state = State.ATTACK


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
		
		if randf() < infection_chance:
			_try_infect(target_stalker)
		
		attack_timer.start()
		# "Zombie атакует!"  # (лог отключён)


func _try_infect(stalker: Node3D):
	if stalker.has_method("apply_infection"):
		stalker.apply_infection(10.0)
		# "Zombie: заразил сталкера!"  # (лог отключён)


func _become_raging():
	# "Zombie: вхожу в ярость!"  # (лог отключён)
	is_raging = true
	accumulated_rage = 0.0
	damage = 25.0


func take_damage(dmg: float, source = null):
	accumulated_rage += dmg
	
	if health < max_health:
		health += dmg * 0.1
	
	super.take_damage(dmg, source)


func _setup_label():
	var label = Label3D.new()
	label.name = "MutantLabel"
	label.position = Vector3(0, 2.5, 0)
	label.font_size = 24
	label.outline_size = 2
	label.outline_modulate = Color.BLACK
	label.modulate = Color(0.3, 0.8, 0.3)  # зеленый
	label.text = "🧟 ЗОМБИ"
	add_child(label)
