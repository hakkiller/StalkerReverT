extends Camera3D
## Медленный облёт витрины аномалий. Скролл мыши — изменить высоту.

@export var radius := 26.0
@export var height := 8.0
@export var speed := 0.12


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0 * speed
	var pos := Vector3(cos(t) * radius, height + sin(t * 0.7) * 2.0, sin(t) * radius)
	look_at_from_position(pos, Vector3.ZERO, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			height = clampf(height + 1.0, 2.0, 24.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			height = clampf(height - 1.0, 2.0, 24.0)
