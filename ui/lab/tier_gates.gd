# ui/lab/tier_gates.gd
extends Control
class_name TierGates

## ВРАТА ЯРУСОВ БАШНИ (макет «вариант 4»): готические врата перед картой этажей.
## 10 врат = 10 ярусов башни. Показываются три врата: предыдущий/выбранный/следующий ярус.
## Всё рисуется кодом (_draw): скала, стрельчатая арка, свечение, цепи, искры, замки.
## Клик по вратам — выбрать ярус (signal selection_changed).

signal selection_changed(tier_idx: int)   # 0..9

const COL_ROCK_TOP := Color("2a2013")
const COL_ROCK_BOT := Color("0d0a06")
const COL_ARCH := Color("241a0e")
const COL_ARCH_DARK := Color("0d0906")
const COL_INNER := Color(0.02, 0.01, 0.005, 0.98)
const COL_GLOW := Color(1.0, 0.66, 0.2)
const COL_PLATE := Color("1c1508")
const COL_PLATE_EDGE := Color("4a3a1a")
const COL_NAME := Color("e8d5a8")
const COL_NAME_ON := Color("ffd94d")
const COL_SUB := Color("9a8349")
const COL_STAR := Color("ffd94d")
const COL_STAR_OFF := Color("4a4436")
const COL_CHAIN := Color("c9a23a")
const COL_FAINT := Color("6a614a")

var frontier_floor: int = 1            # открытый рубеж (лучший прогресс)
var tier_names: Array = []             # 10 имён ярусов
var tier_stars: Array = []             # 10 сумм звёзд яруса
var tier_bosses: Array = []            # 10 имён Хранителей
var selected_tier: int = 0             # выбранный ярус (0-based)

var _t: float = 0.0
var _slots: Array = []                 # Rect2 врат текущего кадра
var _slot_tiers: Array = []            # параллельно _slots: какой ЯРУС в каждом слоте
var _press_pos: Vector2 = Vector2.ZERO # точка нажатия (для свайпа)
var _press_active: bool = false
var _swiped: bool = false              # свайп в этом нажатии уже сработал
var _nudge: float = 0.0                # анимация упругого кивка (0..1)
var _nudge_dir: float = 0.0            # направление кивка (+1 вправо / -1 влево)

const SWIPE_THRESHOLD := 80.0          # пикселей (дизайн-координаты) для срабатывания жеста


func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
        _t += delta
        if _nudge > 0.0:
                _nudge = maxf(_nudge - delta * 4.5, 0.0)
        if visible:
                queue_redraw()


func setup(frontier: int, names: Array, stars: Array, bosses: Array, sel: int = -1) -> void:
        frontier_floor = clampi(frontier, 1, 100)
        tier_names = names
        tier_stars = stars
        tier_bosses = bosses
        if sel >= 0:
                selected_tier = sel
        elif frontier_floor >= 100:
                selected_tier = 9
        else:
                selected_tier = clampi((frontier_floor - 1) / 10, 0, 9)
        queue_redraw()


func _gui_input(event: InputEvent) -> void:
        # Тач на Android приходит как мышь (emulate_mouse_from_touch = true по умолчанию),
        # поэтому обрабатываем ТОЛЬКО mouse-семейство — иначе жест задвоится.
        if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
                if event.pressed:
                        _press_pos = event.position
                        _press_active = true
                        _swiped = false
                else:
                        _press_active = false
                        if not _swiped:
                                _select_gate_at(event.position)
                accept_event()
        elif event is InputEventMouseMotion and _press_active:
                var dx: float = event.position.x - _press_pos.x
                if absf(dx) >= SWIPE_THRESHOLD:
                        _swiped = true
                        _step_tier(1 if dx < 0.0 else -1)   # свайп влево = следующий ярус
                        _press_pos = event.position          # можно продолжить — ещё шаг
                accept_event()


## Клик по вратам — выбрать ярус НА ЭТОМ СЛОТЕ (слот ≠ номер яруса!)
func _select_gate_at(pos: Vector2) -> void:
        for i in range(_slots.size()):
                if (_slots[i] as Rect2).has_point(pos):
                        var tier: int = int(_slot_tiers[i]) if i < _slot_tiers.size() else i
                        if selected_tier != tier:
                                selected_tier = tier
                                selection_changed.emit(tier)
                                queue_redraw()
                        return


## Шаг на соседний ярус жестом (или упор в край с упругим кивком)
func _step_tier(dir: int) -> void:
        var nxt: int = clampi(selected_tier + dir, 0, 9)
        _nudge = 1.0
        _nudge_dir = float(dir)
        if nxt != selected_tier:
                selected_tier = nxt
                selection_changed.emit(nxt)
        queue_redraw()


func _tier_unlocked(idx: int) -> bool:
        return frontier_floor > idx * 10


func _draw() -> void:
        var w := size.x
        var h := size.y
        if w < 300.0 or h < 300.0:
                return

        # Водяной знак БАШНЯ
        draw_string(BunkerUI.font_title(), Vector2(w * 0.5 - 560, h * 0.42), "БАШНЯ",
                HORIZONTAL_ALIGNMENT_CENTER, 1120, 210, Color(1.0, 0.7, 0.24, 0.045))

        _slots.clear()
        _slot_tiers.clear()
        # Три врата: окно из трёх ярусов, зажатое в 0..9 (выбранный в центре)
        var idxs: Array = []
        if selected_tier == 0:
                idxs = [0, 1, 2]
        elif selected_tier == 9:
                idxs = [7, 8, 9]
        else:
                idxs = [selected_tier - 1, selected_tier, selected_tier + 1]

        var gate_w: float = minf(520.0, w / 3.2)
        var gap: float = (w - float(idxs.size()) * gate_w) / float(idxs.size() + 1)
        var base_y: float = h - 90.0
        # Упругий кинок окна врат при свайпе/упоре в край (затухает в _process)
        var slide: float = _nudge_dir * sin(_nudge * PI) * 16.0

        # Цепи между вратами — рисуем после врат (поверх), координаты соберём
        var centers: Array = []
        for k in range(idxs.size()):
                var gx: float = gap + float(k) * (gate_w + gap)
                # Слот БЕЗ сдвига — хит-тест клика стабильный; визуально кивает
                _slots.append(Rect2(gx, base_y - h * 0.62, gate_w, h * 0.62))
                _slot_tiers.append(int(idxs[k]))
                centers.append(Vector2(gx + gate_w * 0.5 + slide, base_y - 160.0))
                _draw_gate(Rect2(gx + slide, base_y - h * 0.62, gate_w, h * 0.62), int(idxs[k]), base_y)

        # Цепи + искры между центрами врат
        for c in range(centers.size() - 1):
                var zig: float = 40.0 if c % 2 == 0 else -30.0
                var a2: Vector2 = centers[c] + Vector2(0, zig)
                var b2: Vector2 = centers[c + 1] + Vector2(0, -zig * 0.6)
                _draw_chain(a2, b2)


func _draw_gate(rect: Rect2, tier_idx: int, base_y: float) -> void:
        var cx: float = rect.get_center().x
        var is_sel: bool = tier_idx == selected_tier
        var unlocked: bool = _tier_unlocked(tier_idx)
        var glow: float = 0.6 + 0.4 * sin(_t * 2.2)
        var pulse: float = 0.5 + 0.5 * sin(_t * 3.1)

        # ----- Скала -----
        var rock_h: float = rect.size.y * 0.30
        var rock_top: float = base_y - rock_h
        var jag: Array = [0.0, 0.30, 0.55, 0.22, 0.44, 0.12, 0.38, 0.20, 0.48]
        var pts := PackedVector2Array()
        pts.append(Vector2(rect.position.x + 30, base_y))
        for j in range(jag.size()):
                var fx: float = rect.position.x + 30.0 + (rect.size.x - 60.0) * (float(j) / float(jag.size() - 1))
                pts.append(Vector2(fx, rock_top + rock_h * 0.35 * jag[j]))
        pts.append(Vector2(rect.position.x + rect.size.x - 30, base_y))
        draw_colored_polygon(pts, COL_ROCK_BOT)
        # Подсветка скалы у нутра
        if unlocked:
                draw_circle(Vector2(cx, base_y - rock_h * 0.15), rect.size.x * 0.24, Color(COL_GLOW, 0.05 + 0.05 * glow))

        # ----- Арка -----
        var arch_w: float = rect.size.x * 0.54
        var arch_h: float = rect.size.y * 0.72
        var arch_l: float = cx - arch_w * 0.5
        var arch_r: float = cx + arch_w * 0.5
        var arch_top: float = base_y - rock_h - arch_h
        # Внешний корпус (стрельчатая арка)
        var body := PackedVector2Array()
        body.append(Vector2(arch_l, base_y))
        body.append(Vector2(arch_l, arch_top + arch_h * 0.42))
        body.append(Vector2(arch_l + arch_w * 0.18, arch_top + arch_h * 0.10))
        body.append(Vector2(cx, arch_top))
        body.append(Vector2(arch_r - arch_w * 0.18, arch_top + arch_h * 0.10))
        body.append(Vector2(arch_r, arch_top + arch_h * 0.42))
        body.append(Vector2(arch_r, base_y))
        draw_colored_polygon(body, COL_ARCH if not (unlocked and is_sel) else COL_ARCH.lightened(0.03))

        # Внутренний проём (уже и темнее)
        var in_l: float = cx - arch_w * 0.34
        var in_r: float = cx + arch_w * 0.34
        var in_top: float = arch_top + arch_h * 0.16
        var inner := PackedVector2Array()
        inner.append(Vector2(in_l, base_y))
        inner.append(Vector2(in_l, in_top + arch_h * 0.40))
        inner.append(Vector2(cx - arch_w * 0.12, in_top))
        inner.append(Vector2(cx, in_top - arch_h * 0.045))
        inner.append(Vector2(cx + arch_w * 0.12, in_top))
        inner.append(Vector2(in_r, in_top + arch_h * 0.40))
        inner.append(Vector2(in_r, base_y))
        draw_colored_polygon(inner, COL_INNER)

        # Свечение нутра открытых врат
        if unlocked:
            var a: float = (0.35 + 0.25 * glow) if is_sel else 0.14
            draw_circle(Vector2(cx, base_y - arch_h * 0.22), arch_w * 0.30, Color(COL_GLOW, a * 0.35))
            draw_circle(Vector2(cx, base_y - arch_h * 0.16), arch_w * 0.18, Color(COL_GLOW, a * 0.5))
            draw_line(Vector2(cx, base_y - arch_h * 0.5), Vector2(cx, base_y - 6.0), Color(COL_GLOW, a * 0.30), 3.0)
        else:
            # Замок над аркой
            var lw: float = 46.0
            var lrect := Rect2(cx - lw * 0.5, arch_top - 74.0, lw, 40.0)
            draw_rect(Rect2(lrect.position, lrect.size), COL_PLATE)
            draw_rect(Rect2(lrect.position, lrect.size), COL_PLATE_EDGE, false, 2.0)
            draw_arc(Vector2(cx, arch_top - 74.0), 14.0, PI, TAU, 16, COL_SUB, 4.0)

        # ----- Табличка -----
        var plate_w: float = minf(rect.size.x * 0.9, 440.0)
        var plate_rect := Rect2(cx - plate_w * 0.5, base_y - 6.0, plate_w, 64.0)
        draw_rect(plate_rect, COL_PLATE)
        draw_rect(plate_rect, COL_PLATE_EDGE, false, 2.0)
        var tname: String = "ЯРУС %d · %s" % [tier_idx + 1, str(tier_names[tier_idx]) if tier_idx < tier_names.size() else ""]
        if is_sel:
                tname = "ЯРУС %d · «%s»" % [tier_idx + 1, str(tier_names[tier_idx]) if tier_idx < tier_names.size() else ""]
        draw_string(BunkerUI.font_title(), Vector2(cx - plate_w * 0.5 + 8, base_y + 26), tname,
                HORIZONTAL_ALIGNMENT_CENTER, plate_w - 16, 19, COL_NAME_ON if is_sel else COL_NAME)
        var sub := "этажи %d–%d · босс: %s" % [tier_idx * 10 + 1, tier_idx * 10 + 10,
                str(tier_bosses[tier_idx]) if tier_idx < tier_bosses.size() else "—"]
        draw_string(BunkerUI.font_mono(), Vector2(cx - plate_w * 0.5 + 8, base_y + 48), sub,
                HORIZONTAL_ALIGNMENT_CENTER, plate_w - 16, 12, COL_SUB)

        # ----- Звёзды яруса над аркой (или пометка заперта) -----
        var stars: int = int(tier_stars[tier_idx]) if tier_idx < tier_stars.size() else 0
        var star_txt: String
        var star_col: Color
        if unlocked:
                star_txt = "★".repeat(stars) + "☆".repeat(maxi(30 - stars, 0)) + "  /30"
                # Сокращаем: максимум 30 знаков слишком длинно — рисуем компактно
                star_txt = "★ ×%d  / 30" % stars
                star_col = COL_STAR
        else:
                star_txt = "ЗАПЕРТО · дойдите до этажа %d" % (tier_idx * 10 + 1)
                star_col = COL_FAINT
        draw_string(BunkerUI.font_mono(), Vector2(cx - 240, arch_top - (28.0 if unlocked else 148.0)), star_txt,
                HORIZONTAL_ALIGNMENT_CENTER, 480, 15, star_col)

        # ----- Тэг над вратами -----
        var tag := "ВЫБРАНО" if is_sel else ("ОТКРЫТО" if unlocked else "ВПЕРЕДИ")
        var tag_col := COL_STAR if is_sel else (Color("a8ff7a") if unlocked else COL_FAINT)
        draw_string(BunkerUI.font_title(), Vector2(cx - 240, arch_top - (58.0 if unlocked else 186.0)), tag,
                HORIZONTAL_ALIGNMENT_CENTER, 480, 15, tag_col)

        # Искра на выбранных вратах
        if is_sel and unlocked:
                var sp: float = fmod(_t, 2.4) / 2.4
                draw_circle(Vector2(cx + sin(_t * 1.7) * arch_w * 0.22, base_y - arch_h * 0.35 - 24.0 * sp),
                        3.0 + 2.0 * pulse, Color("ffcf6a", 0.8))


func _draw_chain(a: Vector2, b: Vector2) -> void:
        var dir := (b - a).normalized()
        var n := int(a.distance_to(b) / 26.0)
        for i in range(n + 1):
                var p := a + dir * (26.0 * float(i))
                draw_circle(p, 3.0, Color(COL_CHAIN, 0.55))
        draw_line(a, b, Color(COL_CHAIN, 0.35), 2.0)
