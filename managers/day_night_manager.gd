extends Node
class_name DayNightManager

## Цикл дня и ночи забега (v0.29.0 «СВЕТ И ТЕНЬ»): ведёт часы суток,
## плавно красит DirectionalLight3D / фон / ambient / туман по профилям
## DayNightData, обновляет часы в HUD и сообщает о смене фазы.
##
## Туман красится через fog_manager.fog_color: FogManager сам каждый кадр
## пишет env.fog_light_color из этого поля - прямая запись в Environment
## затиралась бы его _process'ом. Выживание «Ночь» (fog_mult волны) -
## отдельная система, они не конфликтуют: мы трогаем только цвет.

signal phase_changed(phase: String)

var elapsed: float = 0.0
var running: bool = true

var _light: DirectionalLight3D
var _env: WorldEnvironment
var _fog: FogManager
var _accum: float = 1.0          # первый тик применяем сразу
var _last_minute: int = -1
var _last_phase: String = ""
var _base_rotation: Vector3
var _resolved: bool = false


func _ready() -> void:
	# Ноды сцены могли ещё не войти в дерево - разрешаем лениво
	_resolve.call_deferred()


func _resolve() -> void:
	if not _resolved:
		var scene := get_tree().current_scene
		if scene:
			_light = scene.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
		_env = get_tree().get_first_node_in_group("world_environment") as WorldEnvironment
		_fog = get_tree().get_first_node_in_group("fog_manager") as FogManager
		if _light:
			_base_rotation = _light.rotation
		_resolved = _light != null and _env != null


func _process(delta: float) -> void:
	if running:
		elapsed += delta
	_accum += delta
	if _accum < 0.25:
		return
	_accum = 0.0
	if not _resolved:
		_resolve()
	_apply()


func _apply() -> void:
	var h := DayNightData.hour_at(elapsed)
	var s := DayNightData.sample(h)

	# Свет: цвет/яркость + медленный обход солнца по азимуту за цикл
	if _light:
		_light.light_color = s["light"]
		_light.light_energy = s["energy"]
		var r := _base_rotation
		_light.rotation = Vector3(r.x, r.y - TAU * (h / 24.0), r.z)

	if _env and _env.environment:
		_env.environment.background_color = s["bg"]
		_env.environment.ambient_light_color = s["amb"]
		_env.environment.ambient_light_energy = s["amb_e"]

	if _fog:
		_fog.fog_color = s["fog"]

	# HUD-часы: обновляем при смене отображаемой минуты
	var phase := DayNightData.phase_at(h)
	var minute := int(h) * 60 + int(fposmod(h, 1.0) * 60.0)
	if minute != _last_minute:
		_last_minute = minute
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("update_daynight"):
			hud.update_daynight(DayNightData.clock_text(h), DayNightData.phase_icon(phase), DayNightData.label_color(phase))

	if phase != _last_phase:
		var first := _last_phase.is_empty()
		_last_phase = phase
		if not first:
			phase_changed.emit(phase)


## Сейчас ночь? (для бонуса добычи в зоне)
func is_night() -> bool:
	return DayNightData.is_night_at(DayNightData.hour_at(elapsed))


## Текущая фаза ("day"/"dusk"/"night"/"dawn")
func current_phase() -> String:
	return DayNightData.phase_at(DayNightData.hour_at(elapsed))
