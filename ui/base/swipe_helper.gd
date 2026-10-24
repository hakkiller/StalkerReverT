extends Control
class_name SwipeHelper

## Единый свайп-слой игры (v0.29.2): тянешь - список едет за пальцем 1:1,
## отпускаешь на ходу - инерция с плавным торможением, тап без движения -
## нажимает кнопку/карточку под пальцем. Скроллбары обёрнутого ScrollContainer
## делаются невидимыми (Godot 4 рисует их ПОВЕРХ контента - перекрывали надписи).
##
## Математика против "плохого свайпа":
##  - дельта копится во float (старый int(round()) глотал медленные
##    микродвижения пальца);
##  - скорость сглаживается EMA, а не берётся с последнего кадра (флик был
##    непредсказуем: либо мёртвый, либо случайный);
##  - "отпустил после остановки" не даёт флинг (отсекатель устаревшего замера);
##  - инерция тормозит мягче (была почти мгновенная - список "умирал" под рукой);
##  - тап работает при любой длительности нажатия (был лимит 450 мс).

const DEADZONE_PX := 10.0        # порог "это уже свайп, а не тап"
const VEL_SMOOTH := 0.4          # вес нового замера в EMA скорости
const STALE_MS := 110            # отпустил позже - флинга нет (палец стоял)
const MIN_FLING := 60.0          # ниже - не инертно, а сразу стоп
const MAX_INST := 8000.0         # защита от выброса замера, px/s
const INERTIA_BASE := 0.05       # торможение: v *= base^delta (мягче старого 0.002)

var scroll: ScrollContainer = null
var horiz: bool = false
var tap_cb: Callable = Callable()   # Callable(scroll, global_pos); пусто - кнопка под пальцем

var _active := false
var _moved := false
var _total := 0.0
var _acc := 0.0                     # дробный хвост скролла (точное следование пальцу)
var _last_pos := 0.0
var _lt_ms := 0
var _vel := 0.0
var _inertia_vel := 0.0
var _inertia_on := false


## Обёртка над scroll: свайп-слой поверх + невидимые скроллбары.
## reserve_bottom/right - резерв пустого поля под/справа от списка (px).
static func attach(sc: ScrollContainer, horizontal: bool, reserve_bottom: float = 0.0, reserve_right: float = 0.0, tap_callback: Callable = Callable()) -> Control:
	var wrap := Control.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.offset_bottom = -reserve_bottom
	sc.offset_right = -reserve_right
	wrap.add_child(sc)
	var lay: SwipeHelper = SwipeHelper.new()
	lay.name = "SwipeLayer"
	lay.set_anchors_preset(Control.PRESET_FULL_RECT)
	lay.offset_bottom = -reserve_bottom
	lay.offset_right = -reserve_right
	lay.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.add_child(lay)
	lay.scroll = sc
	lay.horiz = horizontal
	lay.tap_cb = tap_callback
	lay.hide_scrollbars()
	return wrap


## Полоса прокрутки исчезает: нулевой размер, прозрачность, мышь мимо.
## Прокрутка (свайпом/колесом/инерцией) остаётся живой.
func hide_scrollbars() -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	for bar in [scroll.get_h_scroll_bar(), scroll.get_v_scroll_bar()]:
		if bar == null:
			continue
		bar.custom_minimum_size = Vector2(0, 0)
		bar.modulate = Color(1, 1, 1, 0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gui_input(ev: InputEvent) -> void:
	if scroll == null or not is_instance_valid(scroll) or not scroll.visible:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_active = true
			_moved = false
			_total = 0.0
			_acc = 0.0
			_last_pos = ev.position.x if horiz else ev.position.y
			_lt_ms = Time.get_ticks_msec()
			_vel = 0.0
			_inertia_on = false
			accept_event()
		elif _active:
			_active = false
			if not _moved:
				_emit_tap(ev.position)
			else:
				var stale: bool = Time.get_ticks_msec() - _lt_ms > STALE_MS
				var v: float = 0.0 if stale else _vel
				if absf(v) > MIN_FLING:
					_inertia_vel = -v
					_inertia_on = true
			accept_event()
	elif ev is InputEventMouseMotion and _active and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var pos: float = ev.position.x if horiz else ev.position.y
		var dx: float = pos - _last_pos
		_last_pos = pos
		_total += dx
		if absf(_total) > DEADZONE_PX:
			_moved = true
		if _moved:
			_apply_scroll_delta(-dx)
			var now := Time.get_ticks_msec()
			var dt: float = float(maxi(now - _lt_ms, 1)) / 1000.0
			_lt_ms = now
			var inst: float = clampf(dx / dt, -MAX_INST, MAX_INST)
			_vel = inst if _vel == 0.0 else lerpf(_vel, inst, VEL_SMOOTH)
		accept_event()


## Плавное движение списка на d пикселей (дробь доезжает следующими событиями)
func _apply_scroll_delta(d: float) -> void:
	_acc += d
	var step := int(_acc)
	if step == 0:
		return
	_acc -= float(step)
	var bar: ScrollBar = scroll.get_h_scroll_bar() if horiz else scroll.get_v_scroll_bar()
	var mx := int(bar.max_value) if bar else 0
	if horiz:
		scroll.scroll_horizontal = clampi(scroll.scroll_horizontal + step, 0, maxi(mx, 0))
	else:
		scroll.scroll_vertical = clampi(scroll.scroll_vertical + step, 0, maxi(mx, 0))


func _process(delta: float) -> void:
	if not _inertia_on or scroll == null or not is_instance_valid(scroll):
		return
	var bar: ScrollBar = scroll.get_h_scroll_bar() if horiz else scroll.get_v_scroll_bar()
	var mx := int(bar.max_value) if bar else 0
	var cur: int = scroll.scroll_horizontal if horiz else scroll.scroll_vertical
	_apply_scroll_delta(_inertia_vel * delta)
	var nxt: int = scroll.scroll_horizontal if horiz else scroll.scroll_vertical
	_inertia_vel *= pow(INERTIA_BASE, delta)
	if absf(_inertia_vel) < MIN_FLING or nxt == cur:
		_inertia_on = false


## Тап по слою: свой колбэк (карточки фермы) или кнопка под пальцем
func _emit_tap(local_pos: Vector2) -> void:
	var gp: Vector2 = get_global_transform() * local_pos
	if tap_cb.is_valid():
		tap_cb.call(scroll, gp)
		return
	var btns: Array = scroll.find_children("*", "Button", true, false)
	btns.reverse()
	for b in btns:
		var btn := b as Button
		if btn == null or btn.is_queued_for_deletion() or not btn.visible or btn.disabled:
			continue
		if btn.get_global_rect().has_point(gp):
			btn.pressed.emit()
			return
