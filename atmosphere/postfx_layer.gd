# atmosphere/postfx_layer.gd
class_name GrimPostfxLayer
extends CanvasLayer

## Экранный постэффект «мрачная зона»: десатурация, болезненный тинт,
## выцветшие чёрные, виньетка, зерно, мерцание. Шейдер из архива карты
## Припяти (оригинальный). Слой ниже HUD - интерфейс остаётся чётким.

const SHADER_PATH := "res://shaders/grim_postfx.gdshader"

## 1.0 - базовая мрачность; Припять может задать 1.25
var strength: float = 1.0

var _mat: ShaderMaterial


func _init(postfx_strength: float = 1.0):
	strength = postfx_strength
	layer = 1  # тот же уровень, что HUD; добавляется раньше - рисуется под ним


func _ready():
	if not ResourceLoader.exists(SHADER_PATH):
		queue_free()
		return

	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH)
	rect.material = _mat
	add_child(rect)
	_apply_strength()


## Динамическая мрачность: Ночь (x1.4) и ступени фаз легенды поверх базы
func set_strength(new_strength: float):
	strength = new_strength
	if _mat != null:
		_apply_strength()


func _apply_strength():
	if _mat == null:
		return
	_mat.set_shader_parameter("desaturation", 0.15 * strength)
	_mat.set_shader_parameter("tint_strength", 0.12 * strength)
	_mat.set_shader_parameter("wash", 0.12 * strength)
	_mat.set_shader_parameter("vignette_strength", 1.1 * strength)
	_mat.set_shader_parameter("grain_amount", 0.04 * strength)
	_mat.set_shader_parameter("flicker_amount", 0.02 * strength)
