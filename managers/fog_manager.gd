# managers/fog_manager.gd
extends Node
class_name FogManager

## Менеджер тумана - управляет атмосферным туманом.
## ПАК №3 (фикс «молока»): туман облегчен под RTS-камеру. Старые значения
## (base 0.02) на дистанции 100 м съедали ~87% картинки в серую пелену -
## поэтому сцена выглядела размытой бело-серой массой. Высотный туман
## (плотность 0.5 на 3 м) дополнительно заливал уровень земли.
## Новые значения: дымка остается, читаемость карты возвращается.
## Ручки: base_density / max_density / ground_fog_height / fog_color.
## Ночь (модификатор выживания) умножает max_density ×1.5 - учтено.

signal fog_density_changed(density: float)

@export var enabled: bool = true
@export var base_density: float = 0.005
@export var max_density: float = 0.018
@export var height_falloff: float = 8.0
@export var ground_fog_height: float = 2.0
@export var fog_color: Color = Color(0.66, 0.70, 0.72)

var camera: Camera3D = null
var world_environment: WorldEnvironment = null
var current_density: float = 0.0


func _ready():
	add_to_group("fog_manager")
	_find_camera_and_environment()
	# print("FogManager инициализирован") - ЗАКОММЕНТИРОВАНО


func _find_camera_and_environment():
	camera = get_viewport().get_camera_3d()

	var env_node = get_tree().get_first_node_in_group("world_environment")
	if env_node:
		world_environment = env_node
	else:
		world_environment = WorldEnvironment.new()
		world_environment.name = "WorldEnvironment"

		var env = Environment.new()
		env.background_mode = Environment.BG_SKY
		env.fog_enabled = true
		env.fog_light_color = fog_color
		env.fog_density = base_density
		env.fog_height = ground_fog_height
		env.fog_height_density = 0.12

		world_environment.environment = env
		world_environment.add_to_group("world_environment")
		add_child.call_deferred(world_environment)

	# print("WorldEnvironment " + ("найден" if world_environment else "создан")) - ЗАКОММЕНТИРОВАНО


func _process(_delta):
	if not enabled or not camera or not world_environment:
		return

	var camera_height = camera.global_position.y
	var new_density = _calculate_density(camera_height)

	if abs(new_density - current_density) > 0.001:
		current_density = new_density
		_apply_fog(new_density)
		fog_density_changed.emit(new_density)


func _calculate_density(camera_height: float) -> float:
	var height_factor = clamp(1.0 - (camera_height / height_falloff), 0.0, 1.0)
	var density = base_density + (max_density - base_density) * height_factor
	density += sin(Time.get_ticks_msec() * 0.001) * 0.001
	return clamp(density, 0.0, max_density)


func _apply_fog(density: float):
	if not world_environment or not world_environment.environment:
		return

	var env = world_environment.environment
	env.fog_enabled = enabled
	env.fog_density = density
	env.fog_light_color = fog_color
	env.fog_height = ground_fog_height
	env.fog_height_density = 0.12

	# print("Плотность тумана: " + str(density)) - ЗАКОММЕНТИРОВАНО


func set_enabled(value: bool):
	enabled = value
	if not enabled and world_environment and world_environment.environment:
		world_environment.environment.fog_enabled = false
	# print("Туман " + ("включен" if value else "выключен")) - ЗАКОММЕНТИРОВАНО


func set_density(value: float):
	base_density = value
	current_density = value
	_apply_fog(value)


func set_fog_color(color: Color):
	fog_color = color
	if world_environment and world_environment.environment:
		world_environment.environment.fog_light_color = color


func get_current_density() -> float:
	return current_density


func is_visible() -> bool:
	return enabled and current_density > 0.003
