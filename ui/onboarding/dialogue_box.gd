# ui/onboarding/dialogue_box.gd
extends CanvasLayer
class_name DialogueBox

## Сюжетный диалог онбординга: нижняя плашка с портретом, имя, печатающийся
## текст, «ДАЛЕЕ» и «ПРОПУСТИТЬ». Клик/тап и Enter тоже листают.
## Сигналы:
##   finished - показаны все строки (Prog помечает историю прочитанной)
##   closed   - бокс закрыт и освободился (Prog снимает активность)

signal finished
signal closed

const CPS := 46.0  # скорость печати, символов в секунду

const WHO_COLOR := {
        "ПРОВОДНИК": Color("e8b93c"),
        "ДИСПЕТЧЕР": Color("49ff80"),
        "СТАРОЖИЛ": Color("6fc4ff"),
}

var _lines: Array = []
var _idx := -1
var _visible_chars := 0.0
var _typing := false
var _built := false

var _dim: ColorRect
var _name_label: Label
var _text_label: Label
var _next_label: Label
var _portrait: PanelContainer
var _portrait_letter: Label
var _plate: PanelContainer


func show_dialogue(lines: Array) -> void:
        _lines = lines
        _idx = -1
        _build()
        _advance()


func _build() -> void:
        if _built:
                return
        _built = true
        layer = 90

        _dim = ColorRect.new()
        _dim.color = Color(0.0, 0.0, 0.0, 0.45)
        _dim.set_anchors_preset(Control.PRESET_FULL_RECT)
        _dim.mouse_filter = Control.MOUSE_FILTER_STOP
        _dim.gui_input.connect(_on_dim_input)
        add_child(_dim)

        _plate = PanelContainer.new()
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(0.05, 0.07, 0.045, 0.97)
        sb.border_color = Color("3a4a3a")
        sb.set_border_width_all(2)
        sb.corner_radius_top_left = 14
        sb.corner_radius_top_right = 14
        sb.content_margin_left = 18.0
        sb.content_margin_right = 18.0
        sb.content_margin_top = 14.0
        sb.content_margin_bottom = 12.0
        _plate.add_theme_stylebox_override("panel", sb)
        _plate.anchor_left = 0.0
        _plate.anchor_right = 1.0
        _plate.anchor_top = 1.0
        _plate.anchor_bottom = 1.0
        _plate.offset_left = 14
        _plate.offset_right = -14
        _plate.offset_top = -214
        _plate.offset_bottom = -12
        _plate.mouse_filter = Control.MOUSE_FILTER_STOP
        _plate.gui_input.connect(_on_dim_input)
        add_child(_plate)

        var h := HBoxContainer.new()
        h.add_theme_constant_override("separation", 14)
        _plate.add_child(h)

        # Портрет: рамка с первой буквой имени персонажа.
        _portrait = PanelContainer.new()
        var psb := StyleBoxFlat.new()
        psb.bg_color = Color(0.09, 0.12, 0.08)
        psb.border_color = Color("e8b93c")
        psb.set_border_width_all(2)
        psb.set_corner_radius_all(12)
        psb.content_margin_left = 12.0
        psb.content_margin_right = 12.0
        psb.content_margin_top = 8.0
        psb.content_margin_bottom = 8.0
        _portrait.add_theme_stylebox_override("panel", psb)
        _portrait.custom_minimum_size = Vector2(64, 64)
        _portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
        h.add_child(_portrait)
        _portrait_letter = Label.new()
        _portrait_letter.add_theme_font_override("font", BunkerUI.font_title())
        _portrait_letter.add_theme_font_size_override("font_size", 34)
        _portrait_letter.add_theme_color_override("font_color", Color("e8b93c"))
        _portrait_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _portrait_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        _portrait.add_child(_portrait_letter)

        var vb := VBoxContainer.new()
        vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vb.add_theme_constant_override("separation", 6)
        h.add_child(vb)

        _name_label = Label.new()
        _name_label.add_theme_font_override("font", BunkerUI.font_title())
        _name_label.add_theme_font_size_override("font_size", 19)
        _name_label.add_theme_color_override("font_color", Color("e8b93c"))
        vb.add_child(_name_label)

        _text_label = Label.new()
        _text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _text_label.add_theme_font_override("font", BunkerUI.font_body())
        _text_label.add_theme_font_size_override("font_size", 18)
        _text_label.add_theme_color_override("font_color", BunkerUI.TEXT_LIGHT)
        _text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
        vb.add_child(_text_label)

        var foot := HBoxContainer.new()
        foot.add_theme_constant_override("separation", 12)
        vb.add_child(foot)

        _next_label = Label.new()
        _next_label.text = "▼  ДАЛЕЕ"
        _next_label.add_theme_font_override("font", BunkerUI.font_body())
        _next_label.add_theme_font_size_override("font_size", 16)
        _next_label.add_theme_color_override("font_color", BunkerUI.GREEN)
        foot.add_child(_next_label)

        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        foot.add_child(spacer)

        var skip := Button.new()
        skip.text = "ПРОПУСТИТЬ"
        skip.custom_minimum_size = Vector2(170, 40)
        BunkerUI.style_button(skip, "steel", 15)
        skip.pressed.connect(_on_skip)
        skip.mouse_entered.connect(func() -> void: _play_hover())
        foot.add_child(skip)


func _advance() -> void:
        if _typing:
                _text_label.visible_characters = -1
                _typing = false
                return
        _idx += 1
        if _idx >= _lines.size():
                _finish()
                return
        var line: Dictionary = _lines[_idx]
        var who := str(line.get("who", ""))
        var col: Color = WHO_COLOR.get(who, BunkerUI.TEXT_LIGHT)
        _name_label.text = who
        _name_label.add_theme_color_override("font_color", col)
        _portrait_letter.text = who.substr(0, 1)
        _portrait_letter.add_theme_color_override("font_color", col)
        var psb: StyleBoxFlat = _portrait.get_theme_stylebox("panel")
        if psb:
                psb.border_color = col
        _text_label.text = str(line.get("text", ""))
        _text_label.visible_characters = 0
        _visible_chars = 0.0
        _typing = true
        _play_hover()


func _finish() -> void:
        finished.emit()
        closed.emit()
        queue_free()


func _on_skip() -> void:
        _finish()


func _on_dim_input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
                _advance()
        elif event is InputEventScreenTouch and event.pressed:
                _advance()


func _unhandled_input(event: InputEvent) -> void:
        if event.is_action_pressed("ui_accept"):
                _advance()


func _process(delta: float) -> void:
        if not _typing:
                return
        _visible_chars += delta * CPS
        _text_label.visible_characters = int(_visible_chars)
        if _text_label.visible_characters >= _text_label.text.length():
                _typing = false


func _play_hover() -> void:
        var sm = get_tree().get_first_node_in_group("sound_manager")
        if sm and sm.has_method("play_sound"):
                sm.play_sound("ui_hover", 0.3)
