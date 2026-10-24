# anomalies/base_anomaly.gd
extends Area3D
class_name BaseAnomaly

## Базовый класс для всех аномалиЙ

signal stalker_entered(stalker: Node3D)
signal stalker_exited(stalker: Node3D)
signal energy_consumed(amount: float)
signal destroyed(anomaly: BaseAnomaly)
signal damaged(amount: float, current_health: float)

# Параметры
@export var anomaly_type: String = "base"
@export var damage_per_second: float = 10.0
@export var is_active: bool = true
@export var difficulty_level: int = 1
@export var health: float = 100.0
@export var max_health: float = 100.0
@export var radius: float = 5.0
@export var color: Color = Color.WHITE

# Визуал
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null
@onready var light: OmniLight3D = $OmniLight3D if has_node("OmniLight3D") else null
@onready var particles: GPUParticles3D = $GPUParticles3D if has_node("GPUParticles3D") else null

# Состояние
var stalkers_in_zone: Array[Node3D] = []
var damage_timer: Timer
var _is_dying: bool = false
var creation_time: float = 0.0


func _ready():
	creation_time = Time.get_ticks_msec() / 1000.0
	_apply_artifact_sets()
	max_health = health
	
	add_to_group("anomalies")
	add_to_group("anomalies_" + anomaly_type)
	
	_setup_timers()
	_update_size()
	_update_color()
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)



## Сеты артефактов (v0.27.0): 2-3 арта одного элемента усиливают аномалии
## своего элемента (урон; радиус - на 3-й ступени управляющих сетов).
## Данные читаются из лаборатории сейва; вне забега/сейва - no-op.
func _apply_artifact_sets():
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm == null or gm.current_save_data == null or gm.current_save_data.lab_data == null:
		return
	var won: Array = gm.current_save_data.lab_data.won_artifacts
	var dmg: float = ArtifactSets.damage_mult_for_anomaly(anomaly_type, won)
	if dmg != 1.0:
		damage_per_second *= dmg
	var rad: float = ArtifactSets.radius_mult_for_anomaly(anomaly_type, won)
	if rad != 1.0:
		radius *= rad


func _setup_timers():
	damage_timer = Timer.new()
	damage_timer.wait_time = 1.0
	damage_timer.timeout.connect(_apply_damage)
	add_child(damage_timer)
	damage_timer.start()


func _update_size():
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is SphereShape3D:
			collision_shape.shape.radius = radius
	
	if mesh_instance and mesh_instance.mesh:
		if mesh_instance.mesh is SphereMesh:
			mesh_instance.mesh.radius = radius
			mesh_instance.mesh.height = radius * 2


func _update_color():
	if mesh_instance and mesh_instance.material_override:
		mesh_instance.material_override.albedo_color = color
		mesh_instance.material_override.emission = color
	
	if light:
		light.light_color = color


func _on_body_entered(body: Node3D):
	if body.has_method("take_damage") and not body in stalkers_in_zone:
		stalkers_in_zone.append(body)
		stalker_entered.emit(body)


func _on_body_exited(body: Node3D):
	if body in stalkers_in_zone:
		stalkers_in_zone.erase(body)
		stalker_exited.emit(body)


func _apply_damage():
	if not is_active:
		return
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker) and stalker.has_method("take_damage"):
			stalker.take_damage(damage_per_second, self)
			energy_consumed.emit(damage_per_second)


func take_damage(amount: float, _attacker = null):
	if _is_dying:
		return
	
	health -= amount
	damaged.emit(amount, health)
	
	if health <= 0:
		_destroy()


func _destroy():
	if _is_dying:
		return
	_is_dying = true
	
	destroyed.emit(self)
	queue_free()


func set_difficulty(difficulty: int):
	difficulty_level = difficulty
	health = 100.0 * difficulty
	max_health = health
	damage_per_second *= (1.0 + (difficulty - 1) * 0.5)


func set_radius(new_radius: float):
	radius = new_radius
	_update_size()


func set_active(active: bool):
	is_active = active
	if mesh_instance:
		mesh_instance.visible = active


func get_type_name() -> String:
	return anomaly_type


func get_difficulty() -> int:
	return difficulty_level


func get_health_percent() -> float:
	return health / max_health if max_health > 0 else 0.0


func get_stalker_count() -> int:
	return stalkers_in_zone.size()

# ==================== ЭКСКЛЮЗИВНЫЙ ВАРИАНТ (ЧЁРНЫЙ ЯЩИК) ====================

var _exclusive_label: String = ""
var _exclusive_color: Color = Color(0, 0, 0, 0)
var _exclusive_accent: Color = Color.WHITE
var _exclusive_dmg: float = 1.0
var _exclusive_rad: float = 1.0
var _exclusive_props: Dictionary = {}


func apply_exclusive_anomaly(ex: Dictionary) -> void:
	if ex.is_empty():
		return
	_exclusive_label = str(ex.get("label", ""))
	var col_arr: Array = ex.get("color", [1.0, 1.0, 1.0])
	_exclusive_color = Color(float(col_arr[0]), float(col_arr[1]), float(col_arr[2]))
	_exclusive_accent = Color(str(ex.get("accent", "ffffff")))
	_exclusive_dmg = float(ex.get("dmg", 1.0))
	_exclusive_rad = float(ex.get("rad", 1.0))
	_exclusive_props = ex.get("props", {})
	_apply_exclusive_look.call_deferred()


func _apply_exclusive_look():
	# Подклассы перетирают color/_update_color в _ready - применяем строго после
	if _exclusive_color.a > 0.0:
		for p in get_property_list():
			var n := str(p["name"])
			if n.ends_with("_color") and get(n) is Color:
				set(n, _exclusive_color)
		color = _exclusive_color
	damage_per_second = damage_per_second * _exclusive_dmg
	# Радиус живёт в базовом radius или в полях подклассов (*_radius) - множим все
	for p in get_property_list():
		var rn := str(p["name"])
		if (rn == "radius" or rn.ends_with("_radius")) and get(rn) is float:
			set(rn, float(get(rn)) * _exclusive_rad)
	for key in _exclusive_props:
		if get(str(key)) != null:
			set(str(key), _exclusive_props[key])
	_update_size()
	_update_color()
	if not _exclusive_label.is_empty():
		var lbl := Label3D.new()
		lbl.text = _exclusive_label
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.font_size = 40
		lbl.pixel_size = 0.01
		lbl.outline_size = 10
		lbl.modulate = _exclusive_accent
		lbl.outline_modulate = Color(0.05, 0.04, 0.03, 0.95)
		add_child(lbl)
		lbl.position = Vector3(0.0, radius + 1.4, 0.0)
