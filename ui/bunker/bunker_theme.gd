# ui/bunker/bunker_theme.gd
extends RefCounted
class_name BunkerUI

## Тема «БУНКЕР» — единый стиль главного меню, лаборатории и гачи Зоны.
## Сталь, хазард-полосы, 3D-кнопки, штампы, пластины с цифрами.
## Макеты: МЕНЮ_вариант_4 / ЛАБОРАТОРИЯ_вариант_4 / ГАЧА_вариант_4.

# ==== ПАЛИТРА (из макетов) ====
const GREEN := Color("49ff80")
const GREEN_SOFT := Color("8dffb8")
const BTN_GREEN := Color("2dbf6a")
const BTN_GREEN_HI := Color("b7ffce")
const GREEN_DARK := Color("14532e")
const BTN_EDGE_GREEN := Color("04120a")
const HAZARD := Color("e8b93c")
const HAZARD_BRIGHT := Color("ffd23f")
const BTN_HAZARD := Color("c99a1e")
const DANGER := Color("c23f1d")
const DANGER_HI := Color("ff8d5c")
const DANGER_DARK := Color("5e1c0b")
const BTN_EDGE_DARK := Color("171003")
const TEXT := Color("cfe0cf")
const TEXT_LIGHT := Color("e8f2e4")
const TEXT_BRIGHT := Color("eafff0")
const TEXT_DIM := Color("8fa38c")
const TEXT_FAINT := Color("587059")
const STEEL := Color("0d130c")
const STEEL_HI := Color("182017")
const STEEL_LO := Color("131a12")
const STEEL_EDGE := Color("2c382c")
const FRAME := Color("1f291e")
const FRAME_OUT := Color("3a4a3a")
const INK := Color("04170a")
const INK_WARM := Color("2b0b06")

# Цвета редкости (как в cards_util: common/uncommon/rare/legendary)
const RARHEX := {
        "common": Color("bfbfc7"),
        "uncommon": Color("73d980"),
        "rare": Color("73a6ff"),
        "legendary": Color("ffb840"),
}

static var _f_title: FontFile
static var _f_body: FontFile
static var _f_mono: FontFile
static var _shader: Shader


# ==================== ШРИФТЫ ====================

static func font_title() -> Font:
        # Russo One — заголовки и большие кнопки
        if _f_title == null:
                _f_title = load("res://fonts/RussoOne-Regular.ttf")
        return _f_title


static func font_body() -> Font:
        # Oswald — основной текст и кнопки
        if _f_body == null:
                _f_body = load("res://fonts/Oswald-Variable.ttf")
        return _f_body


static func font_mono() -> Font:
        # JetBrains Mono — цифры и технические подписи
        if _f_mono == null:
                _f_mono = load("res://fonts/JetBrainsMono-Variable.ttf")
        return _f_mono


# ==================== СТИЛЬБОКСЫ ====================

## Стальная панель (как .steel в макетах)
static func steel(border: int = 2) -> StyleBoxFlat:
        var sb := StyleBoxFlat.new()
        sb.bg_color = STEEL
        sb.border_color = STEEL_EDGE
        sb.set_border_width_all(border)
        sb.shadow_color = Color(0, 0, 0, 0.55)
        sb.shadow_size = 10
        sb.shadow_offset = Vector2(0, 4)
        sb.content_margin_left = 14.0
        sb.content_margin_right = 14.0
        sb.content_margin_top = 10.0
        sb.content_margin_bottom = 10.0
        return sb


## Стальная панель для Panel/PanelContainer (без больших отступов)
static func steel_panel() -> StyleBoxFlat:
        var sb := steel(2)
        sb.content_margin_left = 8.0
        sb.content_margin_right = 8.0
        sb.content_margin_top = 6.0
        sb.content_margin_bottom = 6.0
        return sb


static func _sb3d(bg: Color, edge: Color, shadow: Color, drop: float, radius: int = 20) -> StyleBoxFlat:
        # 3D-кнопка: жёсткая тень снизу = грибовидная «механическая» клавиша
        var sb := StyleBoxFlat.new()
        sb.bg_color = bg
        sb.border_color = edge
        sb.set_border_width_all(4)
        sb.set_corner_radius_all(radius)
        sb.shadow_color = shadow
        sb.shadow_size = 0
        sb.shadow_offset = Vector2(0, drop)
        sb.content_margin_left = 20.0
        sb.content_margin_right = 20.0
        sb.content_margin_top = 8.0
        sb.content_margin_bottom = 8.0
        return sb


## Тёмная рамка-контур по периметру экрана (как .frame)
static func frame_style() -> StyleBoxFlat:
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(0, 0, 0, 0)
        sb.border_color = FRAME_OUT
        sb.set_border_width_all(1)
        return sb


## Штамп «ДОСТУП РАЗРЕШЁН» (повёрнутая зелёная рамка)
static func make_stamp(text: String) -> PanelContainer:
        var p := PanelContainer.new()
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(0.02, 0.05, 0.03, 0.55)
        sb.border_color = GREEN
        sb.set_border_width_all(3)
        sb.content_margin_left = 16.0
        sb.content_margin_right = 16.0
        sb.content_margin_top = 8.0
        sb.content_margin_bottom = 8.0
        p.add_theme_stylebox_override("panel", sb)
        var l := Label.new()
        l.text = text
        l.add_theme_font_override("font", font_body())
        l.add_theme_font_size_override("font_size", 20)
        l.add_theme_color_override("font_color", GREEN)
        p.add_child(l)
        p.rotation_degrees = -6.0
        return p


## Пластина с цифрой и подписью (шапка меню/гачи)
static func make_plate(value: String, caption: String, width: float = 120.0) -> PanelContainer:
        var p := PanelContainer.new()
        p.add_theme_stylebox_override("panel", steel())
        p.custom_minimum_size = Vector2(width, 0)
        var v := VBoxContainer.new()
        v.add_theme_constant_override("separation", 0)
        var lv := Label.new()
        lv.text = value
        lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lv.add_theme_font_override("font", font_mono())
        lv.add_theme_font_size_override("font_size", 22)
        lv.add_theme_color_override("font_color", HAZARD_BRIGHT)
        var lk := Label.new()
        lk.text = caption
        lk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lk.add_theme_font_override("font", font_body())
        lk.add_theme_font_size_override("font_size", 12)
        lk.add_theme_color_override("font_color", TEXT_DIM)
        v.add_child(lv)
        v.add_child(lk)
        p.add_child(v)
        return p


## Хазард-полоса (ColorRect с шейдером)
static func hazard_stripes(height: float = 14.0) -> ColorRect:
        var cr := ColorRect.new()
        cr.custom_minimum_size = Vector2(0, height)
        cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
        if _shader == null:
                _shader = load("res://ui/bunker/hazard_stripes.gdshader")
        var mat := ShaderMaterial.new()
        mat.shader = _shader
        cr.material = mat
        return cr


## Лампа-индикатор (круглая, on/off)
static func make_lamp(on: bool) -> Panel:
        var p := Panel.new()
        p.custom_minimum_size = Vector2(18, 18)
        var sb := StyleBoxFlat.new()
        sb.set_corner_radius_all(9)
        if on:
                sb.bg_color = GREEN
                sb.border_color = GREEN_SOFT
        else:
                sb.bg_color = Color("8a5a12")
                sb.border_color = Color("c08a24")
        sb.set_border_width_all(2)
        p.add_theme_stylebox_override("panel", sb)
        p.mouse_filter = Control.MOUSE_FILTER_IGNORE
        return p


# ==================== ТЕМЫ КНОПОК ====================

## kind: "primary" (зелёная 3D), "hazard" (жёлтая 3D), "danger" (красная 3D),
##       "steel" (плоская сталь), "ghost" (приглушённая)
static func style_button(btn: Button, kind: String = "steel", font_size: int = 18, big: bool = false) -> void:
        var fnt: Font = font_title() if (kind != "steel" and kind != "ghost") else font_body()
        btn.add_theme_font_override("font", fnt)
        btn.add_theme_font_size_override("font_size", font_size)
        btn.focus_mode = Control.FOCUS_NONE

        var empty := StyleBoxEmpty.new()

        match kind:
                "primary":
                        btn.add_theme_color_override("font_color", INK)
                        btn.add_theme_color_override("font_hover_color", INK)
                        btn.add_theme_color_override("font_pressed_color", INK)
                        btn.add_theme_color_override("font_disabled_color", Color(INK, 0.5))
                        btn.add_theme_stylebox_override("normal", _sb3d(BTN_GREEN, BTN_EDGE_GREEN, GREEN_DARK, 10 if big else 7, 22 if big else 16))
                        btn.add_theme_stylebox_override("hover", _sb3d(BTN_GREEN.lightened(0.1), BTN_EDGE_GREEN, GREEN_DARK, 10 if big else 7, 22 if big else 16))
                        var pr := _sb3d(BTN_GREEN.darkened(0.08), BTN_EDGE_GREEN, GREEN_DARK, 2, 22 if big else 16)
                        pr.content_margin_top = 14.0
                        pr.content_margin_bottom = 6.0
                        btn.add_theme_stylebox_override("pressed", pr)
                        var ds := _sb3d(BTN_GREEN.darkened(0.35), BTN_EDGE_GREEN, GREEN_DARK, 10 if big else 7, 22 if big else 16)
                        ds.bg_color = BTN_GREEN.darkened(0.45)
                        btn.add_theme_stylebox_override("disabled", ds)
                "hazard":
                        btn.add_theme_color_override("font_color", Color("171003"))
                        btn.add_theme_color_override("font_hover_color", Color("171003"))
                        btn.add_theme_color_override("font_pressed_color", Color("171003"))
                        btn.add_theme_color_override("font_disabled_color", Color(0.09, 0.06, 0.01, 0.5))
                        btn.add_theme_stylebox_override("normal", _sb3d(HAZARD, BTN_EDGE_DARK, Color("7a5a10"), 9, 22 if big else 16))
                        btn.add_theme_stylebox_override("hover", _sb3d(HAZARD_BRIGHT, BTN_EDGE_DARK, Color("7a5a10"), 9, 22 if big else 16))
                        var pr := _sb3d(HAZARD.darkened(0.1), BTN_EDGE_DARK, Color("7a5a10"), 2, 22 if big else 16)
                        pr.content_margin_top = 13.0
                        pr.content_margin_bottom = 5.0
                        btn.add_theme_stylebox_override("pressed", pr)
                        var ds := _sb3d(HAZARD.darkened(0.45), BTN_EDGE_DARK, Color("7a5a10"), 9, 22 if big else 16)
                        btn.add_theme_stylebox_override("disabled", ds)
                "danger":
                        btn.add_theme_color_override("font_color", INK_WARM)
                        btn.add_theme_color_override("font_hover_color", INK_WARM)
                        btn.add_theme_color_override("font_pressed_color", INK_WARM)
                        btn.add_theme_color_override("font_disabled_color", Color(INK_WARM, 0.5))
                        btn.add_theme_stylebox_override("normal", _sb3d(DANGER, BTN_EDGE_DARK, DANGER_DARK, 9, 22 if big else 16))
                        btn.add_theme_stylebox_override("hover", _sb3d(DANGER_HI, BTN_EDGE_DARK, DANGER_DARK, 9, 22 if big else 16))
                        var pr := _sb3d(DANGER.darkened(0.08), BTN_EDGE_DARK, DANGER_DARK, 2, 22 if big else 16)
                        pr.content_margin_top = 13.0
                        pr.content_margin_bottom = 5.0
                        btn.add_theme_stylebox_override("pressed", pr)
                        btn.add_theme_stylebox_override("disabled", _sb3d(DANGER.darkened(0.45), BTN_EDGE_DARK, DANGER_DARK, 9, 22 if big else 16))
                "ghost":
                        btn.add_theme_color_override("font_color", TEXT_DIM)
                        btn.add_theme_color_override("font_hover_color", TEXT_LIGHT)
                        btn.add_theme_color_override("font_pressed_color", GREEN)
                        btn.add_theme_stylebox_override("normal", ghost_box())
                        btn.add_theme_stylebox_override("hover", ghost_box(Color(GREEN, 0.5)))
                        btn.add_theme_stylebox_override("pressed", ghost_box(Color(GREEN, 0.8)))
                        btn.add_theme_stylebox_override("disabled", ghost_box())
                _:
                        # steel: плоская стальная кнопка (рядовые кнопки)
                        btn.add_theme_color_override("font_color", TEXT_LIGHT)
                        btn.add_theme_color_override("font_hover_color", TEXT_BRIGHT)
                        btn.add_theme_color_override("font_pressed_color", GREEN)
                        btn.add_theme_color_override("font_disabled_color", TEXT_FAINT)
                        btn.add_theme_stylebox_override("normal", steel_btn_box())
                        var hv := steel_btn_box()
                        hv.border_color = Color(GREEN, 0.55)
                        btn.add_theme_stylebox_override("hover", hv)
                        var pr := steel_btn_box()
                        pr.bg_color = STEEL_HI
                        btn.add_theme_stylebox_override("pressed", pr)
                        var ds := steel_btn_box()
                        ds.bg_color = Color(STEEL, 0.6)
                        btn.add_theme_stylebox_override("disabled", ds)

        btn.add_theme_stylebox_override("focus", empty)


static func steel_btn_box() -> StyleBoxFlat:
        var sb := StyleBoxFlat.new()
        sb.bg_color = STEEL
        sb.border_color = STEEL_EDGE
        sb.set_border_width_all(2)
        sb.set_corner_radius_all(14)
        sb.content_margin_left = 16.0
        sb.content_margin_right = 16.0
        sb.content_margin_top = 8.0
        sb.content_margin_bottom = 8.0
        return sb


static func ghost_box(border := Color(STEEL_EDGE, 0.6)) -> StyleBoxFlat:
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(STEEL, 0.4)
        sb.border_color = border
        sb.set_border_width_all(1)
        sb.set_corner_radius_all(10)
        sb.content_margin_left = 12.0
        sb.content_margin_right = 12.0
        sb.content_margin_top = 6.0
        sb.content_margin_bottom = 6.0
        return sb


# ==================== ТЕМА ====================

## Общая тема: Oswald по умолчанию, стальные панели, стальные кнопки
static func build_theme() -> Theme:
        var th := Theme.new()
        th.default_font = font_body()
        th.default_font_size = 17

        th.set_stylebox("panel", "Panel", steel_panel())
        th.set_stylebox("panel", "PanelContainer", steel_panel())

        var btn_n := steel_btn_box()
        var btn_h := steel_btn_box()
        btn_h.border_color = Color(GREEN, 0.55)
        var btn_p := steel_btn_box()
        btn_p.bg_color = STEEL_HI
        var btn_d := steel_btn_box()
        btn_d.bg_color = Color(STEEL, 0.55)
        th.set_stylebox("normal", "Button", btn_n)
        th.set_stylebox("hover", "Button", btn_h)
        th.set_stylebox("pressed", "Button", btn_p)
        th.set_stylebox("disabled", "Button", btn_d)
        th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
        th.set_font("font", "Button", font_body())
        th.set_font_size("font_size", "Button", 17)
        th.set_color("font_color", "Button", TEXT_LIGHT)
        th.set_color("font_hover_color", "Button", TEXT_BRIGHT)
        th.set_color("font_pressed_color", "Button", GREEN)
        th.set_color("font_disabled_color", "Button", TEXT_FAINT)

        th.set_color("font_color", "Label", TEXT)
        th.set_font("font", "Label", font_body())
        th.set_font_size("font_size", "Label", 17)

        return th


## Применить тему и общие декорации БУНКЕР к корню сцены.
## Возвращает словарь созданных узлов: {haz_top, haz_bottom, frame, overlay}
static func apply_bunker(root: Control, with_frame: bool = true) -> Dictionary:
        root.theme = build_theme()

        var haz_top := hazard_stripes(14.0)
        haz_top.name = "HazTop"
        haz_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
        root.add_child(haz_top)

        var haz_bottom := hazard_stripes(14.0)
        haz_bottom.name = "HazBottom"
        haz_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        root.add_child(haz_bottom)

        var out := {"haz_top": haz_top, "haz_bottom": haz_bottom}

        if with_frame:
                var frame := Panel.new()
                frame.name = "BunkerFrame"
                frame.add_theme_stylebox_override("panel", frame_style())
                frame.set_anchors_preset(Control.PRESET_FULL_RECT)
                frame.offset_left = 10
                frame.offset_top = 10
                frame.offset_right = -10
                frame.offset_bottom = -10
                frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
                root.add_child(frame)
                out["frame"] = frame

        # Полосы и рамка остаются СВЕРХУ (добавлены последними) - это вид макета:
        # хазард-ленты лежат поверх всего по кромкам экрана.
        return out


## Заголовок шапки: главная строка + подстрока
static func make_header(title_text: String, sub_text: String) -> VBoxContainer:
        var v := VBoxContainer.new()
        v.add_theme_constant_override("separation", 2)
        var h1 := Label.new()
        h1.text = title_text
        h1.add_theme_font_override("font", font_body())
        h1.add_theme_font_size_override("font_size", 30)
        h1.add_theme_color_override("font_color", TEXT_LIGHT)
        var h2 := Label.new()
        h2.text = sub_text
        h2.add_theme_font_override("font", font_body())
        h2.add_theme_font_size_override("font_size", 15)
        h2.add_theme_color_override("font_color", TEXT_DIM)
        v.add_child(h1)
        v.add_child(h2)
        return v


## Заголовок секции «▼ ТЕКСТ» (жёлтый, как .lbl)
static func make_section_label(text: String) -> Label:
        var l := Label.new()
        l.text = text
        l.add_theme_font_override("font", font_body())
        l.add_theme_font_size_override("font_size", 14)
        l.add_theme_color_override("font_color", HAZARD)
        return l


## Моноширинный технический текст
static func make_mono_label(text: String, size: int = 13, color: Color = TEXT_DIM) -> Label:
        var l := Label.new()
        l.text = text
        l.add_theme_font_override("font", font_mono())
        l.add_theme_font_size_override("font_size", size)
        l.add_theme_color_override("font_color", color)
        return l
