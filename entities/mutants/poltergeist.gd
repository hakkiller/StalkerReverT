# entities/mutants/poltergeist.gd
extends BaseMutant
class_name PoltergeistMutant

@export var flight_height: float = 5.0
@export var telekinesis_range: float = 20.0
@export var throw_damage: float = 30.0
@export var invisibility_threshold: float = 0.3

var can_telekinesis: bool = true
var telekinesis_timer: Timer
var is_invisible: bool = false
var float_offset: float = 0.0
var mesh_instance: MeshInstance3D

func _ready():
	health = 60.0
	max_health = 60.0
	speed = 6.0
	damage = 0.0
	armor = 0.0
	biomass_cost = 120.0
	detection_radius = 25.0
	mutant_type = "poltergeist"
	
	mesh_instance = $MeshInstance3D
	
	# Целевая высота модели: нормализация по AABB в base_mutant
	model_target_height = 1.6
	# Летает: парит на 1.6 м над рельефом (клип Flying_Idle), гравитация off
	hover_height = 1.6
	super._ready()
	
	telekinesis_timer = Timer.new()
	telekinesis_timer.one_shot = true
	telekinesis_timer.wait_time = 3.0
	telekinesis_timer.timeout.connect(_on_telekinesis_cooldown_ended)
	add_child(telekinesis_timer)
	
	_setup_label()
	# "Poltergeist mutant initialized"  # (лог отключён)


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	_float(delta)
	
	if current_state == State.CHASE and randf() < 0.01:
		_try_become_invisible()
	
	_update_invisibility()
	
	super._physics_process(delta)


func _float(delta):
	float_offset += delta * 2.0
	var hover_y = sin(float_offset) * 0.5
	
	if global_position.y < flight_height:
		velocity.y = 2.0
	elif global_position.y > flight_height + 1:
		velocity.y = -2.0
	else:
		velocity.y = hover_y


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
	
	var dist = global_position.distance_to(target_stalker.global_position)
	
	if dist < telekinesis_range and can_telekinesis:
		_use_telekinesis()
	
	if dist < telekinesis_range * 0.7:
		var retreat = (global_position - target_stalker.global_position).normalized()
		velocity.x = retreat.x * speed
		velocity.z = retreat.z * speed
	else:
		var direction = (target_stalker.global_position - global_position).normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed


func _use_telekinesis():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	# "Poltergeist использует телекинез!"  # (лог отключён)
	can_telekinesis = false
	
	if target_stalker.has_method("take_damage"):
		target_stalker.take_damage(throw_damage, self)
		attacked_stalker.emit(target_stalker)
	
	telekinesis_timer.start()


func _on_telekinesis_cooldown_ended():
	can_telekinesis = true


func _try_become_invisible():
	if not is_invisible and randf() < invisibility_threshold:
		is_invisible = true
		# "Poltergeist стал невидимым!"  # (лог отключён)


func _update_invisibility():
	if not mesh_instance:
		return
	
	var alpha = 0.3 if is_invisible else 1.0
	if mesh_instance.material_override:
		mesh_instance.material_override.albedo_color.a = alpha


func take_damage(dmg: float, source = null):
	if randf() < 0.3:
		# "Poltergeist избежал урона!"  # (лог отключён)
		return
	
	is_invisible = false
	super.take_damage(dmg * 1.5, source)


func _setup_label():
	var label = Label3D.new()
	label.name = "MutantLabel"
	label.position = Vector3(0, 3.0, 0)
	label.font_size = 24
	label.outline_size = 2
	label.outline_modulate = Color.BLACK
	label.modulate = Color(0.5, 0.8, 1.0)  # голубой
	label.text = "👻 ПОЛТЕРГЕЙСТ"
	add_child(label)
