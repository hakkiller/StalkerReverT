# entities/mutants/dog_mutant.gd
extends BaseMutant
class_name DogMutant

@export var pack_bonus: float = 1.2
@export var dodge_chance: float = 0.3

func _ready():
	health = 50.0
	max_health = 50.0
	speed = 8.0
	damage = 8.0
	armor = 0.0
	biomass_cost = 30.0
	mutant_type = "dog"
	
	# Целевая высота модели: нормализация по AABB в base_mutant
	model_target_height = 0.9
	super._ready()
	
	_setup_label()
	# "Dog mutant initialized"  # (лог отключён)


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	var nearby_dogs = _count_nearby_dogs()
	if nearby_dogs > 0:
		var original_speed = speed
		speed = original_speed * (1.0 + (nearby_dogs * 0.1))
		super._physics_process(delta)
		speed = original_speed
	else:
		super._physics_process(delta)


func _count_nearby_dogs() -> int:
	var count = 0
	var mutants = get_tree().get_nodes_in_group("mutants")
	
	for mutant in mutants:
		if mutant == self:
			continue
		if mutant is DogMutant and global_position.distance_to(mutant.global_position) < 10.0:
			count += 1
	
	return count


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
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist < 2.0:
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
		attack_timer.start()
		# "DogMutant атакует!"  # (лог отключён)


func take_damage(dmg: float, source = null):
	if randf() < dodge_chance:
		# "DogMutant уклонился!"  # (лог отключён)
		return
	
	super.take_damage(dmg, source)


func _setup_label():
	var label = Label3D.new()
	label.name = "MutantLabel"
	label.position = Vector3(0, 2.5, 0)
	label.font_size = 24
	label.outline_size = 2
	label.outline_modulate = Color.BLACK
	label.modulate = Color(1, 0.8, 0.4)  # светло-оранжевый
	label.text = "🐕 СОБАКА"
	add_child(label)
