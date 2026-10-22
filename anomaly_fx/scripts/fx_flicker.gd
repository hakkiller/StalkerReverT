extends OmniLight3D
## Мерцание света аномалии: быстрый шум поверх медленной волны.

@export var flicker_speed := 14.0
@export var flicker_amount := 0.35
@export var base_energy := 0.0


func _ready() -> void:
	if base_energy <= 0.0:
		base_energy = light_energy


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var fast := fmod(sin(t * flicker_speed * 7.13) * 43758.5453, 1.0)
	var slow := 0.5 + 0.5 * sin(t * 2.1)
	light_energy = base_energy * (1.0 - flicker_amount * fast * slow)
