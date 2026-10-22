# scripts/game_camera.gd
extends Camera3D

## ПК: WASD-полёт + осмотр мышью (как раньше, без изменений).
## Мобилка: RTS-камера — пан пальцем с инерцией («палец тянет карту»),
## pinch-зум, кнопки +/− у миникарты, двойной тап — центр на монолите,
## тап по земле -> Signals.ground_tapped (режим «тап = ставить» из HUD).

@export var move_speed: float = 20.0
@export var look_speed: float = 0.002

var mouse_captured: bool = false
var rotation_x: float = 0.0
var rotation_y: float = 0.0

# --- Мобильный RTS-режим ---
var touch_mode: bool = false
const RTS_PITCH: float = -1.05            # ~60 градусов вниз
const RTS_YAW: float = 0.0                # север вверх, как на миникарте
const ZOOM_MIN: float = 25.0
const ZOOM_MAX: float = 150.0
const TERRAIN_MARGIN: float = 8.0         # не нырять в рельеф при пане по холмам
const TOUCH_SLOP: float = 14.0            # px: меньше - тап, больше - пан
const TAP_MAX_TIME: float = 0.35          # сек: дольше - это пан
const DOUBLE_TAP_TIME: float = 0.35
const INERTIA_DECAY: float = 0.04         # остаток скорости через 1 сек

var _touches: Dictionary = {}             # index -> Vector2 (последняя позиция)
var _pinch_dist0: float = 0.0
var _pinch_height0: float = 0.0
var _pan_velocity: Vector2 = Vector2.ZERO # px/сек, для инерции после отпускания
var _drag_total: float = 0.0
var _press_time: float = -10.0
var _last_drag_time: float = 0.0
var _last_tap_time: float = -10.0
var _last_tap_pos: Vector2 = Vector2.ZERO


func _ready():
        touch_mode = DisplayServer.is_touchscreen_available()
        if touch_mode:
                _setup_mobile_rts()
        else:
                Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
                mouse_captured = true


func _exit_tree():
        # При выходе из забега (лаборатория/меню - UI-сцены) курсор должен вернуться
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _input(event):
        # ПК-ветка: осмотр мышью + ESC переключает захват курсора (как раньше).
        # На мобилке не мешаем: там своя обработка в _unhandled_input.
        if touch_mode:
                return
        if event is InputEventMouseMotion and mouse_captured:
                rotation_y -= event.relative.x * look_speed
                rotation_x -= event.relative.y * look_speed
                rotation_x = clamp(rotation_x, -1.4, 1.4)

                rotation.y = rotation_y
                rotation.x = rotation_x

        if event.is_action_pressed("ui_cancel"):
                if mouse_captured:
                        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
                        mouse_captured = false
                else:
                        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
                        mouse_captured = true


# ==================== МОБИЛЬНЫЙ RTS-РЕЖИМ ====================

func _setup_mobile_rts() -> void:
        var monolith: Node3D = get_tree().get_first_node_in_group("monolith")
        var center: Vector3 = monolith.global_position if monolith else Vector3.ZERO
        global_position = center + Vector3(0, 65, 45)
        rotation = Vector3(RTS_PITCH, RTS_YAW, 0)
        _make_zoom_buttons()


func _make_zoom_buttons() -> void:
        # Две круглые кнопки +/− над миникартой (справа внизу). Только для тача.
        var layer := CanvasLayer.new()
        layer.name = "TouchZoom"
        layer.layer = 2
        add_child(layer)
        for i in 2:
                var b := Button.new()
                b.text = "+" if i == 0 else "−"
                b.anchor_left = 1.0
                b.anchor_right = 1.0
                b.anchor_top = 1.0
                b.anchor_bottom = 1.0
                b.offset_left = -104.0 if i == 0 else -56.0
                b.offset_right = -60.0 if i == 0 else -12.0
                b.offset_top = -320.0
                b.offset_bottom = -276.0
                b.add_theme_font_size_override("font_size", 24)
                b.pressed.connect(_on_zoom_button.bind(1 if i == 0 else -1))
                layer.add_child(b)


func _on_zoom_button(dir: int) -> void:
        var target := clampf(global_position.y + dir * 20.0, ZOOM_MIN, ZOOM_MAX)
        var tw := create_tween()
        tw.tween_property(self, "global_position:y", target, 0.18)


func _unhandled_input(event: InputEvent) -> void:
        # _unhandled_input: тапы по кнопкам/панелям HUD сюда не доходят
        if not touch_mode:
                return

        if event is InputEventScreenTouch:
                if event.pressed:
                        _touches[event.index] = event.position
                        if _touches.size() == 1:
                                _press_time = Time.get_ticks_msec() / 1000.0
                                _drag_total = 0.0
                                _pan_velocity = Vector2.ZERO   # тап гасит инерцию
                                _last_drag_time = _press_time
                        elif _touches.size() == 2:
                                var points: Array = _touches.values()
                                _pinch_dist0 = points[0].distance_to(points[1])
                                _pinch_height0 = global_position.y
                else:
                        var was_single: bool = _touches.size() == 1 and _touches.has(event.index)
                        _touches.erase(event.index)
                        if was_single:
                                _maybe_tap(event.position)
                        if _touches.size() == 1:
                                # после pinch оставшийся палец заново якорит пан
                                _press_time = Time.get_ticks_msec() / 1000.0
                                _drag_total = 0.0
                                _last_drag_time = _press_time

        elif event is InputEventScreenDrag:
                if not _touches.has(event.index):
                        return
                _touches[event.index] = event.position
                if _touches.size() == 1:
                        _drag_total += event.relative.length()
                        var now := Time.get_ticks_msec() / 1000.0
                        var dt: float = maxf(now - _last_drag_time, 1.0 / 120.0)
                        _last_drag_time = now
                        var inst_v: Vector2 = event.relative / dt
                        _pan_velocity = _pan_velocity.lerp(inst_v, 0.35)
                        _pan_by_pixels(event.relative)
                elif _touches.size() == 2:
                        var points: Array = _touches.values()
                        var d: float = points[0].distance_to(points[1])
                        if _pinch_dist0 > 1.0:
                                var h: float = clampf(_pinch_height0 * _pinch_dist0 / maxf(d, 1.0), ZOOM_MIN, ZOOM_MAX)
                                global_position.y = h


func _maybe_tap(pos: Vector2) -> void:
        var now := Time.get_ticks_msec() / 1000.0
        if now - _press_time > TAP_MAX_TIME or _drag_total > TOUCH_SLOP:
                return

        # В режиме кисти (HUD) двойной тап - просто вторая постановка
        var placing: bool = false
        var zc: Node = get_tree().get_first_node_in_group("zone_controller")
        if zc and str(zc.get("_pending_placement")) != "":
                placing = true

        if not placing and now - _last_tap_time < DOUBLE_TAP_TIME and pos.distance_to(_last_tap_pos) < 48.0:
                _last_tap_time = -10.0
                _center_on_monolith()
                return

        _last_tap_time = now
        _last_tap_pos = pos

        var hit: Vector3 = _raycast_ground(pos)
        if hit.x != INF:
                Signals.ground_tapped.emit(hit)


func _center_on_monolith() -> void:
        var monolith: Node3D = get_tree().get_first_node_in_group("monolith")
        if not monolith:
                return
        var c: Vector3 = monolith.global_position
        var dir: Vector3 = (global_position - c)
        dir.y = 0.0
        if dir.length() < 1.0:
                dir = Vector3(0, 0, 45)  # смотрим с юга
        var dist: float = clampf(global_position.y * 0.7, 30.0, 70.0)
        var target: Vector3 = c + dir.normalized() * dist
        target.y = maxf(global_position.y, ZOOM_MIN)
        var tw := create_tween()
        tw.tween_property(self, "global_position", target, 0.3).set_trans(Tween.TRANS_SINE)


func _pan_by_pixels(pixel_delta: Vector2) -> void:
        var px2world: float = _ground_pixels_to_world()
        var right: Vector3 = global_transform.basis.x
        var fwd: Vector3 = global_transform.basis.z * -1.0
        right.y = 0.0
        fwd.y = 0.0
        if right.length() > 0.01:
                right = right.normalized()
        if fwd.length() > 0.01:
                fwd = fwd.normalized()
        # «Палец тянет карту»: контент следует за пальцем
        global_position += (right * -pixel_delta.x + fwd * pixel_delta.y) * px2world
        _clamp_mobile_position()


func _ground_pixels_to_world() -> float:
        # Метров мира на пиксель на текущей высоте (с учётом наклона)
        var vsize: float = float(get_viewport().get_visible_rect().size.y)
        var world_h: float = 2.0 * global_position.y * tan(deg_to_rad(fov) * 0.5)
        var tilt: float = maxf(sin(-rotation.x), 0.4)
        return world_h / maxf(vsize, 1.0) / tilt


func _raycast_ground(screen_pos: Vector2) -> Vector3:
        var origin: Vector3 = project_ray_origin(screen_pos)
        var dir: Vector3 = project_ray_normal(screen_pos)
        var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 500.0, 1)
        var hit: Dictionary = get_viewport().get_world_3d().direct_space_state.intersect_ray(query)
        if hit and hit.has("position"):
                return hit.position
        return Vector3.INF


func _clamp_mobile_position() -> void:
        global_position.x = clampf(global_position.x, -Helpers.WORLD_LIMIT, Helpers.WORLD_LIMIT)
        global_position.z = clampf(global_position.z, -Helpers.WORLD_LIMIT, Helpers.WORLD_LIMIT)
        global_position.y = clampf(global_position.y, ZOOM_MIN, ZOOM_MAX)
        var terrain: Node = get_tree().get_first_node_in_group("terrain_generator")
        if terrain and terrain.has_method("get_terrain_height"):
                var min_y: float = terrain.get_terrain_height(global_position.x, global_position.z) + TERRAIN_MARGIN
                if global_position.y < min_y:
                        global_position.y = min_y


func _process(delta):
        if touch_mode:
                # Инерция пана после отпускания пальца
                if _touches.is_empty() and _pan_velocity.length() > 8.0:
                        _pan_by_pixels(_pan_velocity * delta)
                        _pan_velocity *= pow(INERTIA_DECAY, delta)
                return

        var input_dir = Vector3.ZERO

        if Input.is_key_pressed(KEY_W):
                input_dir -= transform.basis.z
        if Input.is_key_pressed(KEY_S):
                input_dir += transform.basis.z
        if Input.is_key_pressed(KEY_A):
                input_dir -= transform.basis.x
        if Input.is_key_pressed(KEY_D):
                input_dir += transform.basis.x
        if Input.is_key_pressed(KEY_SPACE):
                input_dir += Vector3.UP
        if Input.is_key_pressed(KEY_SHIFT):
                input_dir -= Vector3.UP

        if input_dir.length() > 0:
                input_dir = input_dir.normalized()
                global_position += input_dir * move_speed * delta
                # Не ныряем под рельеф: осмотр снизу ломает картинку (задние грани)
                var terrain = get_tree().get_first_node_in_group("terrain_generator")
                var min_y := 2.0
                if terrain:
                        min_y = terrain.get_terrain_height(global_position.x, global_position.z) + 3.0
                if global_position.y < min_y:
                        global_position.y = min_y
