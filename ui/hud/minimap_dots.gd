# ui/hud/minimap_dots.gd
extends Control
class_name MinimapDots

## Слой живых объектов поверх SVG-карты: сталкеры, мутанты, монолит.
## Мировые координаты (XZ от монолита в центре) проецируются на квадрат карты.

# Метры от монолита до края карты (спавн-кольцо 90-150м + запас)
const WORLD_HALF: float = 160.0
# Перерисовка точек (чаще незачем, точки и так двигаются медленно)
const UPDATE_INTERVAL: float = 0.2

var _t: float = 0.0


func _process(delta):
	_t += delta
	if _t >= UPDATE_INTERVAL:
		_t = 0.0
		queue_redraw()


func world_to_map(world_pos: Vector3) -> Vector2:
	"""Мировая позиция -> пиксели карты (масштаб по текущему размеру контрола)"""
	var half = size / 2.0
	var p = Vector2(world_pos.x, world_pos.z) / WORLD_HALF * half + half
	return p.clamp(Vector2.ZERO, size)


func _draw():
	# Монолит - янтарное кольцо в центре
	draw_arc(size / 2.0, 5.0, 0, TAU, 24, Color(1.0, 0.75, 0.2), 2.0)
	draw_circle(size / 2.0, 2.0, Color(1.0, 0.75, 0.2))

	# Мутанты - зелёные точки
	for m in get_tree().get_nodes_in_group("mutants"):
		if not is_instance_valid(m):
			continue
		draw_circle(world_to_map(m.global_position), 3.5, Color(0.32, 1.0, 0.54))

	# Сталкеры - красные точки с тёмной обводкой
	for s in get_tree().get_nodes_in_group("stalkers"):
		if not is_instance_valid(s):
			continue
		var p = world_to_map(s.global_position)
		draw_circle(p, 4.5, Color(0.1, 0.05, 0.05))
		draw_circle(p, 3.2, Color(1.0, 0.27, 0.27))

	_draw_camera()


func _draw_camera():
	"""Маркер камеры: белый треугольник по направлению взгляда.
	Без него непонятно, какой участок карты смотришь."""
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	var p = world_to_map(camera.global_position)
	var fwd = -camera.global_transform.basis.z
	var fwd_flat = Vector2(fwd.x, fwd.z)
	if fwd_flat.length() < 0.05:
		fwd_flat = Vector2.RIGHT
	fwd_flat = fwd_flat.normalized()
	# Треугольник-стрелка
	var tip = p + fwd_flat * 8.0
	var left = p + fwd_flat.rotated(2.5) * 5.0
	var right = p + fwd_flat.rotated(-2.5) * 5.0
	var points = PackedVector2Array([tip, left, right])
	draw_colored_polygon(points, Color(1, 1, 1, 0.95))
	draw_circle(p, 2.0, Color(1, 1, 1, 0.9))
