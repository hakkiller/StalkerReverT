# ui/profile/profile_controller.gd
extends Control
class_name ProfileScreen

## ПРОФИЛЬ // СКАНЕР ЛИЧНОСТИ — отдельный полноэкранный терминал (стиль БУНКЕР).
## Макет «ВАРИАНТ 2 · СКАНЕР ЛИЧНОСТИ»: гексагональный сканер с вращающимися
## кольцами и скан-линией в центре, терминал титулов слева, статусы-радио
## справа, ленты аватаров и рамок снизу, строка статистики внизу.
## Аватары = коллекция гачи (28 типов, иконки карточек), рамки/титулы =
## прогресс (кампания/башня/арена/коллекция), статусы = действия в Зоне.
## Выбор хранится в сейве (SaveData.profile_*), разблокировки считаются
## на лету (data/profile_data.gd). Вход: кнопка ПРОФИЛЬ в лабе.

# ==================== СОСТОЯНИЕ ====================

var _gm: Node
var _save = null
var _ctx: Dictionary = {}

# Шапка
var _name_label: Label
var _sub_label: Label
var _title_val: Label
var _status_val: Label
# Титулы
var _title_rows: Array = []          # {id, btn, name_l, how_l, cur_l}
var _titles_count: Label
# Статусы
var _status_rows: Array = []         # {id, btn, name_l, mood_l, dot: ColorRect}
# Сканер
var _scanner: ScannerView
var _cap_av: Label
var _cap_frame: Label
var _cap_sub: Label
# Ленты
var _av_buttons: Dictionary = {}     # id -> Button
var _av_badges: Dictionary = {}      # id -> HexBadge
var _fr_buttons: Dictionary = {}
var _fr_badges: Dictionary = {}
var _av_count: Label
var _fr_count: Label
# Статистика внизу
var _stat_vals: Dictionary = {}      # ключ -> Label значения
# Редактор имени
var _name_edit_btn: Button
var _name_dlg: Control
var _name_input: LineEdit
var _name_counter: Label
# Окно «ЗАГРУЗКА АВАТАРА»: выбор из архива + свой снимок с диска
var _av_dlg: Control
var _dl_grid: GridContainer
var _dl_count: Label
var _dlg_tiles: Dictionary = {}      # id -> Button карточки в окне
var _file_dlg: FileDialog
# Анимированные бейджи рамок (эффекты pulse/shine/reactor)
var _anim_fr_ids: Array = []
# Прочее
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
        # Непрозрачный фон терминала
        var bg := ColorRect.new()
        bg.color = Color("0a0f0a")
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(bg)

        BunkerUI.apply_bunker(self, true)

        _gm = get_tree().get_first_node_in_group("game_manager")
        if _gm and "current_save_data" in _gm:
                _save = _gm.current_save_data
        _ctx = ProfileData.make_ctx(_save)

        _build_header()
        _build_name_row()
        _build_mid()
        _build_strips()
        _build_stats_line()
        _build_toast()
        _build_name_dialog()
        _build_avatar_dlg()

        _refresh_all()
        Loc.changed.connect(_refresh_all)


func _process(_delta: float) -> void:
        # анимация эффектов рамок в ленте (перерисовываются только нужные бейджи)
        for id_v in _anim_fr_ids:
                var b = _fr_badges.get(str(id_v))
                if b:
                        b.queue_redraw()


func _input(event: InputEvent) -> void:
        # ESC закрывает окна (до обработки GUI): имя, затем загрузка аватара
        if event is InputEventKey and event.pressed and not event.echo \
                        and event.keycode == KEY_ESCAPE:
                if _name_dlg and _name_dlg.visible:
                        get_viewport().set_input_as_handled()
                        _on_name_cancel_pressed()
                elif _av_dlg and _av_dlg.visible:
                        get_viewport().set_input_as_handled()
                        _on_avatar_dlg_close()


func _play_hover_sound() -> void:
        var sm = get_tree().get_first_node_in_group("sound_manager")
        if sm and sm.has_method("play_sound"):
                sm.play_sound("ui_hover", 0.3)


func _play_click_sound() -> void:
        var sm = get_tree().get_first_node_in_group("sound_manager")
        if sm and sm.has_method("play_sound"):
                sm.play_sound("ui_click", 0.6)


# ==================== ПОСТРОЕНИЕ ====================

func _build_header() -> void:
        var head := HBoxContainer.new()
        head.add_theme_constant_override("separation", 14)
        head.anchor_left = 0.0
        head.anchor_right = 1.0
        head.offset_left = 44
        head.offset_right = -44
        head.offset_top = 26
        head.offset_bottom = 92
        add_child(head)

        head.add_child(BunkerUI.make_lamp(true))

        var tv := VBoxContainer.new()
        tv.add_theme_constant_override("separation", 0)
        var h1 := HBoxContainer.new()
        h1.add_theme_constant_override("separation", 10)
        var t1 := Label.new()
        t1.text = Loc.t("profile.h1")
        t1.add_theme_font_override("font", BunkerUI.font_title())
        t1.add_theme_font_size_override("font_size", 26)
        t1.add_theme_color_override("font_color", BunkerUI.TEXT_LIGHT)
        var t2 := Label.new()
        t2.text = "//"
        t2.add_theme_font_override("font", BunkerUI.font_mono())
        t2.add_theme_font_size_override("font_size", 22)
        t2.add_theme_color_override("font_color", BunkerUI.TEXT_FAINT)
        var t3 := Label.new()
        t3.text = Loc.t("profile.h1_accent")
        t3.add_theme_font_override("font", BunkerUI.font_title())
        t3.add_theme_font_size_override("font_size", 26)
        t3.add_theme_color_override("font_color", BunkerUI.GREEN)
        h1.add_child(t1)
        h1.add_child(t2)
        h1.add_child(t3)
        tv.add_child(h1)
        var crumb := BunkerUI.make_mono_label(Loc.t("profile.crumb"), 12, Color("66794f"))
        tv.add_child(crumb)
        head.add_child(tv)

        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        head.add_child(spacer)

        var back := Button.new()
        back.text = Loc.t("profile.back")
        back.custom_minimum_size = Vector2(180, 56)
        BunkerUI.style_button(back, "steel", 18)
        back.pressed.connect(_on_back_pressed)
        back.mouse_entered.connect(_play_hover_sound)
        head.add_child(back)


func _build_name_row() -> void:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 20)
        row.anchor_left = 0.0
        row.anchor_right = 1.0
        row.offset_left = 48
        row.offset_right = -48
        row.offset_top = 100
        row.offset_bottom = 168
        add_child(row)

        _name_label = Label.new()
        _name_label.add_theme_font_override("font", BunkerUI.font_title())
        _name_label.add_theme_font_size_override("font_size", 44)
        _name_label.add_theme_color_override("font_color", BunkerUI.TEXT_BRIGHT)
        row.add_child(_name_label)

        var edit_btn := Button.new()
        edit_btn.text = Loc.t("profile.name_edit")
        edit_btn.custom_minimum_size = Vector2(120, 38)
        edit_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        BunkerUI.style_button(edit_btn, "steel", 13)
        edit_btn.pressed.connect(_on_name_edit_pressed)
        edit_btn.mouse_entered.connect(_play_hover_sound)
        _name_edit_btn = edit_btn
        row.add_child(edit_btn)

        _sub_label = BunkerUI.make_mono_label("", 14, BunkerUI.TEXT_DIM)
        _sub_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        row.add_child(_sub_label)

        var spacer := Control.new()
        spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(spacer)

        var right := HBoxContainer.new()
        right.add_theme_constant_override("separation", 4)
        right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        var tp := Label.new()
        tp.text = Loc.t("profile.title_prefix")
        tp.add_theme_font_override("font", BunkerUI.font_mono())
        tp.add_theme_font_size_override("font_size", 14)
        tp.add_theme_color_override("font_color", BunkerUI.HAZARD)
        _title_val = Label.new()
        _title_val.add_theme_font_override("font", BunkerUI.font_body())
        _title_val.add_theme_font_size_override("font_size", 15)
        _title_val.add_theme_color_override("font_color", BunkerUI.TEXT_LIGHT)
        var sp := Label.new()
        sp.text = Loc.t("profile.status_prefix")
        sp.add_theme_font_override("font", BunkerUI.font_mono())
        sp.add_theme_font_size_override("font_size", 14)
        sp.add_theme_color_override("font_color", BunkerUI.HAZARD)
        _status_val = Label.new()
        _status_val.add_theme_font_override("font", BunkerUI.font_body())
        _status_val.add_theme_font_size_override("font_size", 15)
        _status_val.add_theme_color_override("font_color", BunkerUI.GREEN_SOFT)
        right.add_child(tp)
        right.add_child(_title_val)
        right.add_child(sp)
        right.add_child(_status_val)
        row.add_child(right)


func _build_mid() -> void:
        var mid := HBoxContainer.new()
        mid.add_theme_constant_override("separation", 20)
        mid.anchor_left = 0.0
        mid.anchor_right = 1.0
        mid.offset_left = 44
        mid.offset_right = -44
        mid.offset_top = 176
        mid.offset_bottom = -242
        add_child(mid)

        # --- слева: терминал титулов ---
        var titles_panel := _make_panel(Loc.t("profile.titles_head"))
        titles_panel.custom_minimum_size = Vector2(430, 0)
        mid.add_child(titles_panel)
        var tbox: VBoxContainer = titles_panel.get_child(0)
        var thead: HBoxContainer = tbox.get_child(0)
        _titles_count = thead.get_child(2)
        var tlist := VBoxContainer.new()
        tlist.add_theme_constant_override("separation", 8)
        tlist.size_flags_vertical = Control.SIZE_EXPAND_FILL
        tbox.add_child(tlist)
        for t in ProfileData.TITLES:
                var row := _make_title_row(str(t.id))
                tlist.add_child(row)
                _title_rows.append(row.get_meta("refs"))

        # --- центр: сканер + подпись ---
        var center := VBoxContainer.new()
        center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        center.add_theme_constant_override("separation", 4)
        mid.add_child(center)

        _scanner = ScannerView.new()
        _scanner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _scanner.size_flags_vertical = Control.SIZE_EXPAND_FILL
        center.add_child(_scanner)

        _cap_av = BunkerUI.make_mono_label("", 13, BunkerUI.TEXT_DIM)
        _cap_av.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        center.add_child(_cap_av)
        _cap_frame = Label.new()
        _cap_frame.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _cap_frame.add_theme_font_override("font", BunkerUI.font_title())
        _cap_frame.add_theme_font_size_override("font_size", 21)
        center.add_child(_cap_frame)
        _cap_sub = BunkerUI.make_mono_label("", 12, BunkerUI.TEXT_FAINT)
        _cap_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        center.add_child(_cap_sub)

        var btns := HBoxContainer.new()
        btns.add_theme_constant_override("separation", 10)
        btns.alignment = BoxContainer.ALIGNMENT_CENTER
        btns.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        center.add_child(btns)

        var ca_btn := Button.new()
        ca_btn.text = Loc.t("profile.change_avatar")
        ca_btn.custom_minimum_size = Vector2(276, 48)
        BunkerUI.style_button(ca_btn, "primary", 15)
        ca_btn.pressed.connect(_on_change_avatar_pressed)
        ca_btn.mouse_entered.connect(_play_hover_sound)
        btns.add_child(ca_btn)

        var cf_btn := Button.new()
        cf_btn.text = Loc.t("profile.change_frame")
        cf_btn.custom_minimum_size = Vector2(256, 48)
        BunkerUI.style_button(cf_btn, "steel", 15)
        cf_btn.pressed.connect(_on_change_frame_pressed)
        cf_btn.mouse_entered.connect(_play_hover_sound)
        btns.add_child(cf_btn)

        var dl_btn := Button.new()
        dl_btn.text = Loc.t("profile.open_dl")
        dl_btn.custom_minimum_size = Vector2(256, 48)
        BunkerUI.style_button(dl_btn, "steel", 15)
        dl_btn.pressed.connect(_on_avatar_dlg_open)
        dl_btn.mouse_entered.connect(_play_hover_sound)
        btns.add_child(dl_btn)

        # клик по самому сканеру тоже открывает окно загрузки аватара
        _scanner.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        _scanner.gui_input.connect(_on_scanner_input)

        # --- справа: статусы-радио ---
        var st_panel := _make_panel(Loc.t("profile.statuses_head"))
        st_panel.custom_minimum_size = Vector2(430, 0)
        mid.add_child(st_panel)
        var sbox: VBoxContainer = st_panel.get_child(0)
        var shead: HBoxContainer = sbox.get_child(0)
        # лампа в голове панели статусов - жёлтая (как в макете)
        var head_lamp: Panel = shead.get_child(0)
        var lsb := StyleBoxFlat.new()
        lsb.set_corner_radius_all(7)
        lsb.bg_color = BunkerUI.HAZARD
        lsb.border_color = BunkerUI.HAZARD_BRIGHT
        lsb.set_border_width_all(2)
        head_lamp.add_theme_stylebox_override("panel", lsb)
        var srr: Label = shead.get_child(2)
        srr.text = Loc.t("profile.statuses_rr")
        var slist := VBoxContainer.new()
        slist.add_theme_constant_override("separation", 7)
        slist.size_flags_vertical = Control.SIZE_EXPAND_FILL
        sbox.add_child(slist)
        for s in ProfileData.STATUSES:
                var row := _make_status_row(str(s.id))
                slist.add_child(row)
                _status_rows.append(row.get_meta("refs"))
        slist.add_child(_make_note(Loc.t("profile.status_note")))


## Стальная панель с головой «лампа + название + счётчик справа».
## Возвращает PanelContainer; внутри VBox: [head, line, content...]
func _make_panel(head_text: String) -> PanelContainer:
        var p := PanelContainer.new()
        p.add_theme_stylebox_override("panel", BunkerUI.steel())
        var v := VBoxContainer.new()
        v.add_theme_constant_override("separation", 8)
        p.add_child(v)

        var head := HBoxContainer.new()
        head.add_theme_constant_override("separation", 10)
        var lamp := BunkerUI.make_lamp(true)
        head.add_child(lamp)
        var tt := Label.new()
        tt.text = head_text
        tt.add_theme_font_override("font", BunkerUI.font_title())
        tt.add_theme_font_size_override("font_size", 15)
        tt.add_theme_color_override("font_color", BunkerUI.TEXT_LIGHT)
        tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        head.add_child(tt)
        var rr := BunkerUI.make_mono_label("", 12, BunkerUI.TEXT_FAINT)
        rr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        head.add_child(rr)
        v.add_child(head)

        var line := ColorRect.new()
        line.color = BunkerUI.STEEL_EDGE
        line.custom_minimum_size = Vector2(0, 1)
        v.add_child(line)
        return p


func _make_title_row(id: String) -> Button:
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(0, 44)
        btn.focus_mode = Control.FOCUS_NONE
        var refs := {"id": id, "btn": btn}

        var hb := HBoxContainer.new()
        hb.set_anchors_preset(Control.PRESET_FULL_RECT)
        hb.offset_left = 10
        hb.offset_right = -10
        hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
        hb.add_theme_constant_override("separation", 8)

        var cur := Label.new()
        cur.text = ">"
        cur.custom_minimum_size = Vector2(14, 0)
        cur.add_theme_font_override("font", BunkerUI.font_mono())
        cur.add_theme_font_size_override("font_size", 14)
        cur.add_theme_color_override("font_color", BunkerUI.GREEN)
        cur.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        hb.add_child(cur)

        var name_l := Label.new()
        name_l.add_theme_font_override("font", BunkerUI.font_title())
        name_l.add_theme_font_size_override("font_size", 14)
        name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        hb.add_child(name_l)

        var how_l := BunkerUI.make_mono_label("", 11, BunkerUI.TEXT_FAINT)
        how_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        hb.add_child(how_l)

        btn.add_child(hb)
        btn.pressed.connect(_on_title_pressed.bind(id))
        btn.mouse_entered.connect(_play_hover_sound)
        refs["name_l"] = name_l
        refs["how_l"] = how_l
        refs["cur_l"] = cur
        btn.set_meta("refs", refs)
        return btn


func _make_status_row(id: String) -> Button:
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(0, 42)
        btn.focus_mode = Control.FOCUS_NONE
        var refs := {"id": id, "btn": btn}

        var hb := HBoxContainer.new()
        hb.set_anchors_preset(Control.PRESET_FULL_RECT)
        hb.offset_left = 10
        hb.offset_right = -10
        hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
        hb.add_theme_constant_override("separation", 10)

        # радио: тёмный круг + зелёная точка (видна на выбранном)
        var radio := Panel.new()
        radio.custom_minimum_size = Vector2(16, 16)
        var rsb := StyleBoxFlat.new()
        rsb.set_corner_radius_all(8)
        rsb.bg_color = Color("0d130c")
        rsb.border_color = BunkerUI.STEEL_EDGE
        rsb.set_border_width_all(2)
        radio.add_theme_stylebox_override("panel", rsb)
        var dot := ColorRect.new()
        dot.color = BunkerUI.GREEN
        dot.set_anchors_preset(Control.PRESET_CENTER)
        dot.offset_left = -3
        dot.offset_top = -3
        dot.offset_right = 3
        dot.offset_bottom = 3
        dot.visible = false
        radio.add_child(dot)
        radio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        hb.add_child(radio)

        var name_l := Label.new()
        name_l.add_theme_font_override("font", BunkerUI.font_title())
        name_l.add_theme_font_size_override("font_size", 13)
        name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        hb.add_child(name_l)

        var mood_l := BunkerUI.make_mono_label("", 10, BunkerUI.TEXT_FAINT)
        mood_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        hb.add_child(mood_l)

        btn.add_child(hb)
        btn.pressed.connect(_on_status_pressed.bind(id))
        btn.mouse_entered.connect(_play_hover_sound)
        refs["name_l"] = name_l
        refs["mood_l"] = mood_l
        refs["dot"] = dot
        btn.set_meta("refs", refs)
        return btn


func _make_note(text: String) -> PanelContainer:
        var p := PanelContainer.new()
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(BunkerUI.STEEL, 0.4)
        sb.border_color = Color(BunkerUI.STEEL_EDGE, 0.8)
        sb.set_border_width_all(1)
        sb.content_margin_left = 12
        sb.content_margin_right = 12
        sb.content_margin_top = 8
        sb.content_margin_bottom = 8
        p.add_theme_stylebox_override("panel", sb)
        var l := BunkerUI.make_mono_label(text, 12, BunkerUI.TEXT_FAINT)
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        p.add_child(l)
        return p


func _build_strips() -> void:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 20)
        row.anchor_left = 0.0
        row.anchor_right = 1.0
        row.offset_left = 44
        row.offset_right = -44
        row.offset_top = -232
        row.offset_bottom = -74
        add_child(row)

        # --- АВАТАР-СЕАНС ---
        var av_panel := _make_panel(Loc.t("profile.avatars_head"))
        av_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(av_panel)
        var avbox: VBoxContainer = av_panel.get_child(0)
        var avhead: HBoxContainer = avbox.get_child(0)
        _av_count = avhead.get_child(2)
        var av_scroll := ScrollContainer.new()
        av_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
        av_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        av_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        avbox.add_child(av_scroll)
        var av_hb := HBoxContainer.new()
        av_hb.add_theme_constant_override("separation", 10)
        av_scroll.add_child(av_hb)
        for av in ProfileData.get_avatar_list():
                var item := _make_avatar_item(av)
                av_hb.add_child(item)
                _av_buttons[str(av.id)] = item
                _av_badges[str(av.id)] = item.get_meta("badge")

        # --- РАМКИ ---
        var fr_panel := _make_panel(Loc.t("profile.frames_head"))
        fr_panel.custom_minimum_size = Vector2(660, 0)
        row.add_child(fr_panel)
        var frbox: VBoxContainer = fr_panel.get_child(0)
        var frhead: HBoxContainer = frbox.get_child(0)
        _fr_count = frhead.get_child(2)
        var fr_scroll := ScrollContainer.new()
        fr_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
        fr_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        fr_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        frbox.add_child(fr_scroll)
        var fr_hb := HBoxContainer.new()
        fr_hb.add_theme_constant_override("separation", 10)
        fr_scroll.add_child(fr_hb)
        for f in ProfileData.FRAMES:
                var item := _make_frame_item(f)
                fr_hb.add_child(item)
                _fr_buttons[str(f.id)] = item
                _fr_badges[str(f.id)] = item.get_meta("badge")


func _make_avatar_item(av: Dictionary) -> Button:
        var id := str(av.id)
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(116, 122)
        btn.focus_mode = Control.FOCUS_NONE
        var vb := VBoxContainer.new()
        vb.set_anchors_preset(Control.PRESET_FULL_RECT)
        vb.offset_top = 6
        vb.offset_bottom = -4
        vb.alignment = BoxContainer.ALIGNMENT_CENTER
        vb.add_theme_constant_override("separation", 3)
        vb.mouse_filter = Control.MOUSE_FILTER_IGNORE

        var badge := HexBadge.new()
        badge.custom_minimum_size = Vector2(76, 76)
        badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        vb.add_child(badge)

        var name_l := Label.new()
        name_l.add_theme_font_override("font", BunkerUI.font_body())
        name_l.add_theme_font_size_override("font_size", 12)
        name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        vb.add_child(name_l)

        btn.add_child(vb)
        btn.pressed.connect(_on_avatar_pressed.bind(id, av))
        btn.mouse_entered.connect(_play_hover_sound)
        btn.set_meta("badge", badge)
        btn.set_meta("name_l", name_l)
        btn.set_meta("av", av)
        return btn


func _make_frame_item(f: Dictionary) -> Button:
        var id := str(f.id)
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(118, 122)
        btn.focus_mode = Control.FOCUS_NONE
        var vb := VBoxContainer.new()
        vb.set_anchors_preset(Control.PRESET_FULL_RECT)
        vb.offset_top = 6
        vb.offset_bottom = -4
        vb.alignment = BoxContainer.ALIGNMENT_CENTER
        vb.add_theme_constant_override("separation", 3)
        vb.mouse_filter = Control.MOUSE_FILTER_IGNORE

        var badge := HexBadge.new()
        badge.custom_minimum_size = Vector2(70, 70)
        badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        badge.is_frame_preview = true
        vb.add_child(badge)

        var name_l := Label.new()
        name_l.add_theme_font_override("font", BunkerUI.font_body())
        name_l.add_theme_font_size_override("font_size", 12)
        name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        vb.add_child(name_l)

        btn.add_child(vb)
        btn.pressed.connect(_on_frame_pressed.bind(id))
        btn.mouse_entered.connect(_play_hover_sound)
        btn.set_meta("badge", badge)
        btn.set_meta("name_l", name_l)
        return btn


func _build_stats_line() -> void:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 10)
        row.anchor_left = 0.0
        row.anchor_right = 1.0
        row.offset_left = 48
        row.offset_right = -48
        row.offset_top = -64
        row.offset_bottom = -30
        add_child(row)

        var defs := ["campaign", "floor", "waves", "arena", "runs", "coll", "rolls"]
        var first := true
        for key_i in defs:
                var key := str(key_i)
                if not first:
                        var sep := Control.new()
                        sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                        row.add_child(sep)
                first = false
                var cap := BunkerUI.make_mono_label(Loc.t("profile.stat_" + key) + " ", 13, BunkerUI.TEXT_DIM)
                cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                row.add_child(cap)
                var val := BunkerUI.make_mono_label("", 13, BunkerUI.GREEN)
                val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
                row.add_child(val)
                _stat_vals[key] = val


func _art_rolls() -> int:
        if _save and _save.lab_data:
                return int(_save.lab_data.gacha_rolls_artifacts)
        return 0


func _build_toast() -> void:
        _toast = PanelContainer.new()
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(BunkerUI.STEEL, 0.96)
        sb.border_color = BunkerUI.GREEN
        sb.set_border_width_all(2)
        sb.set_corner_radius_all(10)
        sb.content_margin_left = 18
        sb.content_margin_right = 18
        sb.content_margin_top = 8
        sb.content_margin_bottom = 8
        _toast.add_theme_stylebox_override("panel", sb)
        _toast_label = BunkerUI.make_mono_label("", 14, BunkerUI.TEXT_LIGHT)
        _toast.add_child(_toast_label)
        _toast.anchor_left = 0.5
        _toast.anchor_right = 0.5
        _toast.anchor_top = 1.0
        _toast.anchor_bottom = 1.0
        _toast.offset_left = -260
        _toast.offset_right = 260
        _toast.offset_top = -118
        _toast.offset_bottom = -74
        _toast.modulate.a = 0.0
        add_child(_toast)


func _show_toast(text: String) -> void:
        _toast_label.text = text
        if _toast_tween and _toast_tween.is_valid():
                _toast_tween.kill()
        _toast.modulate.a = 1.0
        _toast_tween = create_tween()
        _toast_tween.tween_interval(1.6)
        _toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


# ==================== РЕДАКТОР ИМЕНИ ====================

func _build_name_dialog() -> void:
        _name_dlg = Control.new()
        _name_dlg.set_anchors_preset(Control.PRESET_FULL_RECT)
        _name_dlg.mouse_filter = Control.MOUSE_FILTER_STOP
        _name_dlg.visible = false
        add_child(_name_dlg)

        var dim := ColorRect.new()
        dim.color = Color(0, 0, 0, 0.72)
        dim.set_anchors_preset(Control.PRESET_FULL_RECT)
        dim.mouse_filter = Control.MOUSE_FILTER_STOP
        _name_dlg.add_child(dim)

        var panel := PanelContainer.new()
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(BunkerUI.STEEL, 0.98)
        sb.border_color = BunkerUI.GREEN
        sb.set_border_width_all(2)
        sb.set_corner_radius_all(14)
        sb.content_margin_left = 26
        sb.content_margin_right = 26
        sb.content_margin_top = 20
        sb.content_margin_bottom = 22
        panel.add_theme_stylebox_override("panel", sb)
        panel.anchor_left = 0.5
        panel.anchor_right = 0.5
        panel.anchor_top = 0.5
        panel.anchor_bottom = 0.5
        panel.offset_left = -300
        panel.offset_right = 300
        panel.offset_top = -172
        panel.offset_bottom = 172
        _name_dlg.add_child(panel)

        var v := VBoxContainer.new()
        v.add_theme_constant_override("separation", 12)
        panel.add_child(v)

        var head := HBoxContainer.new()
        head.add_theme_constant_override("separation", 10)
        head.add_child(BunkerUI.make_lamp(true))
        var tt := Label.new()
        tt.text = Loc.t("profile.name_head")
        tt.add_theme_font_override("font", BunkerUI.font_title())
        tt.add_theme_font_size_override("font_size", 19)
        tt.add_theme_color_override("font_color", BunkerUI.TEXT_LIGHT)
        tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        head.add_child(tt)
        _name_counter = BunkerUI.make_mono_label("0/18", 13, BunkerUI.TEXT_FAINT)
        head.add_child(_name_counter)
        v.add_child(head)

        var line := ColorRect.new()
        line.color = BunkerUI.STEEL_EDGE
        line.custom_minimum_size = Vector2(0, 1)
        v.add_child(line)

        _name_input = LineEdit.new()
        _name_input.custom_minimum_size = Vector2(0, 58)
        _name_input.max_length = 18
        _name_input.add_theme_font_override("font", BunkerUI.font_mono())
        _name_input.add_theme_font_size_override("font_size", 22)
        _name_input.add_theme_color_override("font_color", BunkerUI.TEXT_BRIGHT)
        _name_input.add_theme_color_override("caret_color", BunkerUI.GREEN)
        _name_input.add_theme_color_override("font_placeholder_color",
                Color(BunkerUI.TEXT_FAINT, 0.7))
        _name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
        var isb := StyleBoxFlat.new()
        isb.bg_color = Color("0d130c")
        isb.border_color = BunkerUI.STEEL_EDGE
        isb.set_border_width_all(2)
        isb.set_corner_radius_all(10)
        isb.content_margin_left = 14
        isb.content_margin_right = 14
        _name_input.add_theme_stylebox_override("normal", isb)
        var fsb := isb.duplicate()
        fsb.border_color = BunkerUI.GREEN
        _name_input.add_theme_stylebox_override("focus", fsb)
        _name_input.text_changed.connect(_update_name_counter)
        _name_input.text_submitted.connect(_on_name_submitted)
        v.add_child(_name_input)

        var hint := BunkerUI.make_mono_label(Loc.t("profile.name_hint"), 11, BunkerUI.TEXT_FAINT)
        hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.add_child(hint)

        var btns := HBoxContainer.new()
        btns.add_theme_constant_override("separation", 10)
        btns.alignment = BoxContainer.ALIGNMENT_CENTER
        var save := Button.new()
        save.text = Loc.t("profile.name_save")
        save.custom_minimum_size = Vector2(180, 50)
        BunkerUI.style_button(save, "primary", 15)
        save.pressed.connect(_on_name_save_pressed)
        save.mouse_entered.connect(_play_hover_sound)
        btns.add_child(save)
        var reset := Button.new()
        reset.text = Loc.t("profile.name_reset")
        reset.custom_minimum_size = Vector2(140, 50)
        BunkerUI.style_button(reset, "steel", 15)
        reset.pressed.connect(_on_name_reset_pressed)
        reset.mouse_entered.connect(_play_hover_sound)
        btns.add_child(reset)
        var cancel := Button.new()
        cancel.text = Loc.t("profile.name_cancel")
        cancel.custom_minimum_size = Vector2(140, 50)
        BunkerUI.style_button(cancel, "steel", 15)
        cancel.pressed.connect(_on_name_cancel_pressed)
        cancel.mouse_entered.connect(_play_hover_sound)
        btns.add_child(cancel)
        v.add_child(btns)


func _on_name_edit_pressed() -> void:
        _play_click_sound()
        var custom := ""
        if _save:
                custom = str(_save.profile_name)
        _name_input.text = custom
        var run := 1
        if _save and _save.lab_data:
                run = int(_save.lab_data.run_number)
        _name_input.placeholder_text = "СТАЛКЕР-%02d" % clampi(run, 1, 99)
        _update_name_counter(custom)
        _name_dlg.visible = true
        _name_input.call_deferred("grab_focus")
        _name_input.call_deferred("select_all")


func _on_name_submitted(_text: String) -> void:
        _on_name_save_pressed()


func _on_name_save_pressed() -> void:
        var t := _name_input.text.strip_edges()
        if _save:
                _save.profile_name = t
                _persist()
        _name_dlg.visible = false
        _refresh_all()
        _show_toast(Loc.t("profile.name_saved"))


func _on_name_reset_pressed() -> void:
        _play_click_sound()
        if _save:
                _save.profile_name = ""
                _persist()
        _name_dlg.visible = false
        _refresh_all()


func _on_name_cancel_pressed() -> void:
        _play_click_sound()
        _name_dlg.visible = false


func _update_name_counter(text: String) -> void:
        var n := text.length()
        _name_counter.text = "%d/18" % n
        _name_counter.add_theme_color_override("font_color",
                BunkerUI.HAZARD if n >= 15 else BunkerUI.TEXT_FAINT)


# ==================== ОБРАБОТЧИКИ ====================

func _on_back_pressed() -> void:
        _play_click_sound()
        if _gm and _gm.has_method("change_scene"):
                _gm.change_scene("lab")
        else:
                get_tree().change_scene_to_file("res://scenes/lab/lab.tscn")


func _on_title_pressed(id: String) -> void:
        _play_click_sound()
        var t := ProfileData.get_title(id)
        if not ProfileData.is_title_unlocked(t, _ctx):
                _show_toast("%s%s" % [Loc.t("profile.locked_tag").to_upper() + ": ", ProfileData.title_how(id)])
                return
        if _save:
                _save.profile_title = id
                _persist()
        _refresh_all()


func _on_status_pressed(id: String) -> void:
        _play_click_sound()
        var s := ProfileData.get_status(id)
        if not ProfileData.is_status_unlocked(s, _ctx):
                _show_toast("%s%s" % [Loc.t("profile.locked_tag").to_upper() + ": ", ProfileData.status_how(id)])
                return
        # повторный клик по закреплённому снимает закрепление (обратно на авто)
        if _save:
                _save.profile_status = "" if str(_save.profile_status) == id else id
                _persist()
        _refresh_all()


func _on_avatar_pressed(id: String, av: Dictionary) -> void:
        _play_click_sound()
        if not ProfileData.is_avatar_unlocked(av, _save.lab_data if _save else null):
                _show_toast("%s%s" % [Loc.t("profile.locked_tag").to_upper() + ": ", Loc.t("profile.show_in_bunker")])
                return
        if _save:
                _save.profile_avatar = id
                _persist()
        _refresh_all()


func _on_frame_pressed(id: String) -> void:
        _play_click_sound()
        var f := ProfileData.get_frame(id)
        if not ProfileData.is_frame_unlocked(f, _ctx):
                _show_toast("%s%s" % [Loc.t("profile.locked_tag").to_upper() + ": ", ProfileData.frame_how(id)])
                return
        if _save:
                _save.profile_frame = id
                _persist()
        _refresh_all()


func _on_change_frame_pressed() -> void:
        _play_click_sound()
        var cur_id := str(_save.profile_frame) if _save else "steel"
        var start := ProfileData.get_frame_index(cur_id)
        var n := ProfileData.FRAMES.size()
        for step in range(1, n + 1):
                var idx := (start + step) % n
                var f: Dictionary = ProfileData.FRAMES[idx]
                if ProfileData.is_frame_unlocked(f, _ctx):
                        if _save:
                                _save.profile_frame = str(f.id)
                                _persist()
                        _refresh_all()
                        return
        _show_toast("%s%s" % [Loc.t("profile.locked_tag").to_upper() + ": ", Loc.t("profile.fhow_bronze")])


func _on_change_avatar_pressed() -> void:
        # цикл по открытым аватарам коллекции (как у рамок)
        _play_click_sound()
        var list := ProfileData.get_avatar_list()
        var cur_id := str(_save.profile_avatar) if _save else "zombie"
        var start := 0
        for i in list.size():
                if str(list[i].id) == cur_id:
                        start = i
                        break
        var n := list.size()
        for step in range(1, n + 1):
                var av: Dictionary = list[(start + step) % n]
                if ProfileData.is_avatar_unlocked(av, _save.lab_data if _save else null):
                        if _save:
                                _save.profile_avatar = str(av.id)
                                _persist()
                        _refresh_all()
                        _show_toast("%s%s" % [Loc.t("profile.dl_installed"),
                                        GachaData.display_name(str(av.id))])
                        return
        _show_toast("%s%s" % [Loc.t("profile.locked_tag").to_upper() + ": ",
                        Loc.t("profile.show_in_bunker")])


func _on_scanner_input(event: InputEvent) -> void:
        if event is InputEventMouseButton and event.pressed \
                        and event.button_index == MOUSE_BUTTON_LEFT:
                _on_avatar_dlg_open()


func _on_avatar_dlg_open() -> void:
        _play_click_sound()
        _refresh_avatar_dlg()
        _av_dlg.visible = true


func _on_avatar_dlg_close() -> void:
        _play_click_sound()
        _av_dlg.visible = false


# ==================== ОКНО «ЗАГРУЗКА АВАТАРА» ====================

## Окно выбора аватара: плитка «СВОЙ СНИМОК» (файл с диска, ПК) + вся
## коллекция (28 карточек). Клик по открытой карточке сразу надевает её.
func _build_avatar_dlg() -> void:
        _av_dlg = Control.new()
        _av_dlg.set_anchors_preset(Control.PRESET_FULL_RECT)
        _av_dlg.mouse_filter = Control.MOUSE_FILTER_STOP
        _av_dlg.visible = false
        add_child(_av_dlg)

        var dim := ColorRect.new()
        dim.color = Color(0, 0, 0, 0.74)
        dim.set_anchors_preset(Control.PRESET_FULL_RECT)
        dim.mouse_filter = Control.MOUSE_FILTER_STOP
        _av_dlg.add_child(dim)

        var panel := PanelContainer.new()
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(BunkerUI.STEEL, 0.98)
        sb.border_color = BunkerUI.GREEN
        sb.set_border_width_all(2)
        sb.set_corner_radius_all(14)
        sb.content_margin_left = 26
        sb.content_margin_right = 26
        sb.content_margin_top = 18
        sb.content_margin_bottom = 20
        panel.add_theme_stylebox_override("panel", sb)
        panel.anchor_left = 0.5
        panel.anchor_right = 0.5
        panel.anchor_top = 0.5
        panel.anchor_bottom = 0.5
        panel.offset_left = -508
        panel.offset_right = 508
        panel.offset_top = -300
        panel.offset_bottom = 300
        _av_dlg.add_child(panel)

        var v := VBoxContainer.new()
        v.add_theme_constant_override("separation", 10)
        panel.add_child(v)

        var head := HBoxContainer.new()
        head.add_theme_constant_override("separation", 10)
        head.add_child(BunkerUI.make_lamp(true))
        var tt := Label.new()
        tt.text = Loc.t("profile.dl_head")
        tt.add_theme_font_override("font", BunkerUI.font_title())
        tt.add_theme_font_size_override("font_size", 19)
        tt.add_theme_color_override("font_color", BunkerUI.TEXT_LIGHT)
        tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        head.add_child(tt)
        _dl_count = BunkerUI.make_mono_label("", 13, BunkerUI.TEXT_FAINT)
        head.add_child(_dl_count)
        v.add_child(head)

        var line := ColorRect.new()
        line.color = BunkerUI.STEEL_EDGE
        line.custom_minimum_size = Vector2(0, 1)
        v.add_child(line)

        var hint := BunkerUI.make_mono_label(Loc.t("profile.dl_hint"), 12, BunkerUI.TEXT_FAINT)
        hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.add_child(hint)

        var scroll := ScrollContainer.new()
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
        v.add_child(scroll)

        _dl_grid = GridContainer.new()
        _dl_grid.columns = 7
        _dl_grid.add_theme_constant_override("h_separation", 10)
        _dl_grid.add_theme_constant_override("v_separation", 10)
        scroll.add_child(_dl_grid)

        var cust := _make_dlg_custom_tile()
        _dl_grid.add_child(cust)
        _dlg_tiles["custom"] = cust

        for av in ProfileData.get_avatar_list():
                var tile := _make_dlg_avatar_tile(av)
                _dl_grid.add_child(tile)
                _dlg_tiles[str(av.id)] = tile

        var btns := HBoxContainer.new()
        btns.add_theme_constant_override("separation", 10)
        btns.alignment = BoxContainer.ALIGNMENT_CENTER
        var close := Button.new()
        close.text = Loc.t("profile.name_cancel")
        close.custom_minimum_size = Vector2(220, 46)
        BunkerUI.style_button(close, "steel", 15)
        close.pressed.connect(_on_avatar_dlg_close)
        close.mouse_entered.connect(_play_hover_sound)
        btns.add_child(close)
        v.add_child(btns)

        _file_dlg = FileDialog.new()
        _file_dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
        _file_dlg.access = FileDialog.ACCESS_FILESYSTEM
        _file_dlg.title = Loc.t("profile.dl_custom_pick")
        _file_dlg.size = Vector2i(760, 500)
        _file_dlg.filters = ["*.png ; PNG", "*.jpg ; JPG", "*.jpeg ; JPEG", "*.webp ; WebP"]
        _file_dlg.file_selected.connect(_on_custom_photo_picked)
        _av_dlg.add_child(_file_dlg)


func _make_dlg_avatar_tile(av: Dictionary) -> Button:
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(128, 128)
        btn.focus_mode = Control.FOCUS_NONE
        var badge := HexBadge.new()
        badge.custom_minimum_size = Vector2(72, 72)
        badge.set_anchors_preset(Control.PRESET_CENTER)
        badge.offset_left = -36
        badge.offset_top = -36
        badge.offset_right = 36
        badge.offset_bottom = 36
        badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
        btn.add_child(badge)
        var name_l := BunkerUI.make_mono_label("", 11, BunkerUI.TEXT_DIM)
        name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        name_l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        name_l.offset_left = 4
        name_l.offset_right = -4
        name_l.offset_top = -22
        name_l.offset_bottom = -6
        name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        btn.add_child(name_l)
        btn.set_meta("badge", badge)
        btn.set_meta("name_l", name_l)
        btn.set_meta("av", av)
        btn.pressed.connect(_on_dlg_avatar_pressed.bind(str(av.id), av))
        btn.mouse_entered.connect(_play_hover_sound)
        return btn


func _make_dlg_custom_tile() -> Button:
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(128, 128)
        btn.focus_mode = Control.FOCUS_NONE
        btn.tooltip_text = Loc.t("profile.dl_custom_hint")
        var badge := HexBadge.new()
        badge.custom_minimum_size = Vector2(72, 72)
        badge.set_anchors_preset(Control.PRESET_CENTER)
        badge.offset_left = -36
        badge.offset_top = -36
        badge.offset_right = 36
        badge.offset_bottom = 36
        badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
        btn.add_child(badge)
        var name_l := BunkerUI.make_mono_label("", 11, BunkerUI.TEXT_DIM)
        name_l.text = Loc.t("profile.dl_custom")
        name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        name_l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        name_l.offset_left = 4
        name_l.offset_right = -4
        name_l.offset_top = -22
        name_l.offset_bottom = -6
        name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
        btn.add_child(name_l)
        btn.set_meta("badge", badge)
        btn.set_meta("name_l", name_l)
        btn.pressed.connect(_on_dlg_custom_pressed)
        btn.mouse_entered.connect(_play_hover_sound)
        return btn


func _refresh_avatar_dlg() -> void:
        var unlocked := 0
        for id_v in _dlg_tiles:
                var id := str(id_v)
                var btn: Button = _dlg_tiles[id]
                var badge: HexBadge = btn.get_meta("badge")
                var name_l: Label = btn.get_meta("name_l")
                var sel := id == (str(_save.profile_avatar) if _save else "zombie")
                if id == "custom":
                        var tex := _load_custom_tex()
                        badge.tex = tex
                        badge.locked = false
                        badge.rarity = ""
                        badge.queue_redraw()
                        name_l.add_theme_color_override("font_color",
                                BunkerUI.GREEN if tex else BunkerUI.TEXT_FAINT)
                        _style_item(btn, sel, false)
                        continue
                var av: Dictionary = btn.get_meta("av")
                var ok := ProfileData.is_avatar_unlocked(av, _save.lab_data if _save else null)
                if ok:
                        unlocked += 1
                badge.tex = load(ProfileData.get_avatar_icon(av, ok))
                badge.locked = not ok
                badge.rarity = str(av.rar)
                badge.queue_redraw()
                name_l.text = GachaData.display_name(id)
                name_l.add_theme_color_override("font_color",
                        GachaData.rarity_color(str(av.rar)) if ok else BunkerUI.TEXT_FAINT)
                _style_item(btn, sel, not ok)
        _dl_count.text = "%d / %d" % [unlocked, ProfileData.get_avatar_count()]


func _on_dlg_avatar_pressed(id: String, av: Dictionary) -> void:
        _play_click_sound()
        if not ProfileData.is_avatar_unlocked(av, _save.lab_data if _save else null):
                _show_toast(Loc.t("profile.dl_locked"))
                return
        if _save:
                _save.profile_avatar = id
                _persist()
        _refresh_all()
        _refresh_avatar_dlg()
        _show_toast("%s%s" % [Loc.t("profile.dl_installed"), GachaData.display_name(id)])


func _on_dlg_custom_pressed() -> void:
        _play_click_sound()
        if OS.get_name() == "Android" or OS.get_name() == "iOS":
                _show_toast(Loc.t("profile.dl_custom_pc_only"))
                return
        var dir := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
        if dir.is_empty():
                dir = OS.get_environment("USERPROFILE")
        if dir.is_empty():
                dir = OS.get_environment("HOME")
        if not dir.is_empty():
                _file_dlg.current_dir = dir
        _file_dlg.popup_centered()


func _on_custom_photo_picked(path: String) -> void:
        var img := Image.new()
        if img.load(path) != OK or img.is_empty():
                _show_toast(Loc.t("profile.dl_custom_fail"))
                return
        # центр-кроп до квадрата, затем 256×256 (иконка сканера квадратная)
        var s := mini(img.get_width(), img.get_height())
        if s < 8:
                _show_toast(Loc.t("profile.dl_custom_fail"))
                return
        var ox := (img.get_width() - s) / 2
        var oy := (img.get_height() - s) / 2
        img = img.get_region(Rect2i(ox, oy, s, s))
        img.resize(256, 256, Image.INTERPOLATE_LANCZOS)
        if img.save_png("user://custom_avatar.png") != OK:
                _show_toast(Loc.t("profile.dl_custom_fail"))
                return
        if _save:
                _save.profile_avatar = "custom"
                _persist()
        _refresh_all()
        _refresh_avatar_dlg()
        _show_toast(Loc.t("profile.dl_custom_saved"))


func _load_custom_tex() -> Texture2D:
        if not FileAccess.file_exists("user://custom_avatar.png"):
                return null
        var img := Image.new()
        if img.load("user://custom_avatar.png") != OK or img.is_empty():
                return null
        return ImageTexture.create_from_image(img)


func _persist() -> void:
        if _gm and _gm.has_method("save_to_active_slot"):
                _gm.save_to_active_slot()


# ==================== ОБНОВЛЕНИЕ ====================

func _refresh_all() -> void:
        _ctx = ProfileData.make_ctx(_save)
        _refresh_header()
        _refresh_titles()
        _refresh_statuses()
        _refresh_scanner()
        _refresh_strips()
        _refresh_stats()


func _refresh_header() -> void:
        _name_label.text = ProfileData.stalker_name(_save)
        _sub_label.text = Loc.t("profile.sub_line", {
                "lvl": str(_ctx.campaign),
                "day": "%03d" % ProfileData.zone_day(_save),
        })
        var cur_title := str(_save.profile_title) if _save else "green"
        _title_val.text = ProfileData.title_name(cur_title)
        var pinned := str(_save.profile_status) if _save else ""
        var eff := ProfileData.effective_status(pinned, _ctx)
        _status_val.text = ProfileData.status_name(eff)


func _refresh_titles() -> void:
        var unlocked := 0
        for refs_v in _title_rows:
                var refs: Dictionary = refs_v
                var id := str(refs.id)
                var t := ProfileData.get_title(id)
                var ok := ProfileData.is_title_unlocked(t, _ctx)
                if ok:
                        unlocked += 1
                var is_cur := id == (str(_save.profile_title) if _save else "green")
                var name_l: Label = refs.name_l
                var how_l: Label = refs.how_l
                var cur_l: Label = refs.cur_l
                var btn: Button = refs.btn
                name_l.text = ProfileData.title_name(id)
                name_l.add_theme_color_override("font_color",
                        BunkerUI.TEXT_BRIGHT if is_cur else (BunkerUI.TEXT_LIGHT if ok else BunkerUI.TEXT_FAINT))
                how_l.text = ProfileData.title_how(id)
                cur_l.visible = is_cur
                btn.modulate = Color(1, 1, 1, 0.55) if not ok else Color.WHITE
                var sb := StyleBoxFlat.new()
                sb.bg_color = Color(BunkerUI.GREEN, 0.10) if is_cur else Color(0.08, 0.10, 0.06, 0.55)
                sb.border_color = BunkerUI.GREEN if is_cur else (BunkerUI.STEEL_EDGE if ok else Color(BunkerUI.STEEL_EDGE, 0.6))
                sb.border_width_left = 3
                sb.border_width_top = 1
                sb.border_width_bottom = 1
                sb.border_width_right = 1
                sb.content_margin_left = 4
                sb.content_margin_right = 4
                btn.add_theme_stylebox_override("normal", sb)
                var hv := sb.duplicate()
                hv.border_color = Color(BunkerUI.GREEN, 0.6) if not is_cur else BunkerUI.GREEN
                btn.add_theme_stylebox_override("hover", hv)
                btn.add_theme_stylebox_override("pressed", hv)
                btn.add_theme_stylebox_override("disabled", sb)
        _titles_count.text = "%d/%d" % [unlocked, ProfileData.TITLES.size()]


func _refresh_statuses() -> void:
        var pinned := str(_save.profile_status) if _save else ""
        var eff := ProfileData.effective_status(pinned, _ctx)
        for refs_v in _status_rows:
                var refs: Dictionary = refs_v
                var id := str(refs.id)
                var s := ProfileData.get_status(id)
                var ok := ProfileData.is_status_unlocked(s, _ctx)
                var is_pinned := id == pinned and ok
                var is_eff := id == eff
                var name_l: Label = refs.name_l
                var mood_l: Label = refs.mood_l
                var dot: ColorRect = refs.dot
                var btn: Button = refs.btn
                name_l.text = ProfileData.status_name(id)
                name_l.add_theme_color_override("font_color",
                        BunkerUI.TEXT_BRIGHT if is_eff else (BunkerUI.TEXT_LIGHT if ok else BunkerUI.TEXT_FAINT))
                if is_pinned:
                        mood_l.text = Loc.t("profile.pinned")
                else:
                        mood_l.text = ProfileData.status_how(id)
                # закреплённый - зелёная точка; авто-текущий - жёлтая
                dot.visible = is_eff
                dot.color = BunkerUI.GREEN if is_pinned else BunkerUI.HAZARD
                btn.modulate = Color(1, 1, 1, 0.55) if not ok else Color.WHITE
                var sb := StyleBoxFlat.new()
                sb.bg_color = Color(BunkerUI.GREEN, 0.10) if is_eff else Color(0.08, 0.10, 0.06, 0.55)
                sb.border_color = Color("3d5a2a") if is_eff else BunkerUI.STEEL_EDGE
                sb.set_border_width_all(1)
                sb.set_corner_radius_all(8)
                sb.content_margin_left = 4
                sb.content_margin_right = 4
                btn.add_theme_stylebox_override("normal", sb)
                var hv := sb.duplicate()
                hv.border_color = Color(BunkerUI.GREEN, 0.6)
                btn.add_theme_stylebox_override("hover", hv)
                btn.add_theme_stylebox_override("pressed", hv)
                btn.add_theme_stylebox_override("disabled", sb)


func _refresh_scanner() -> void:
        var av_id := str(_save.profile_avatar) if _save else "zombie"
        var fr_id := str(_save.profile_frame) if _save else "steel"
        if av_id == "custom":
                _refresh_scanner_custom(fr_id)
                return
        var av: Dictionary = {"id": av_id, "is_mutant": true, "rar": "common"}
        for a in ProfileData.get_avatar_list():
                if str(a.id) == av_id:
                        av = a
                        break
        var unlocked := ProfileData.is_avatar_unlocked(av, _save.lab_data if _save else null)
        var f := ProfileData.get_frame(fr_id)
        _scanner.set_avatar(ProfileData.get_avatar_icon(av, unlocked), unlocked)
        _scanner.set_frame_colors(f.dark, f.light)
        var fx := ProfileData.frame_fx(fr_id)
        _scanner.set_frame_fx(fx)
        _cap_av.text = Loc.t("profile.avatar_prefix") + GachaData.display_name(av_id) + (" · " + Loc.t("profile.rar_" + str(av.rar)) if unlocked else "")
        _cap_av.add_theme_color_override("font_color", GachaData.rarity_color(str(av.rar)) if unlocked else BunkerUI.TEXT_FAINT)
        _cap_frame.text = Loc.t("profile.frame_prefix") + ProfileData.frame_name(fr_id)
        _cap_frame.add_theme_color_override("font_color", f.light)
        var fx_txt := "" if fx == "none" else " · ◈ " + Loc.t("profile.fx_" + fx)
        _cap_sub.text = "%s · %s%s" % [Loc.t("profile.rar_" + str(f.rar)), ProfileData.frame_how(fr_id), fx_txt]


## Сканер для аватара «СВОЙ СНИМОК»: PNG из user://, фоллбек — серый зомби.
func _refresh_scanner_custom(fr_id: String) -> void:
        var f := ProfileData.get_frame(fr_id)
        var fx := ProfileData.frame_fx(fr_id)
        _scanner.set_frame_colors(f.dark, f.light)
        _scanner.set_frame_fx(fx)
        var tex := _load_custom_tex()
        if tex:
                _scanner.set_avatar_tex(tex, false)
        else:
                _scanner.set_avatar(ProfileData.get_avatar_icon(
                        {"id": "zombie", "is_mutant": true}, false), true)
        _cap_av.text = Loc.t("profile.avatar_prefix") + Loc.t("profile.dl_custom")
        _cap_av.add_theme_color_override("font_color",
                BunkerUI.GREEN if tex else BunkerUI.TEXT_FAINT)
        _cap_frame.text = Loc.t("profile.frame_prefix") + ProfileData.frame_name(fr_id)
        _cap_frame.add_theme_color_override("font_color", f.light)
        var fx_txt := "" if fx == "none" else " · ◈ " + Loc.t("profile.fx_" + fx)
        _cap_sub.text = "%s · %s%s" % [Loc.t("profile.rar_" + str(f.rar)), ProfileData.frame_how(fr_id), fx_txt]


func _refresh_strips() -> void:
        var av_unlocked := 0
        for av in ProfileData.get_avatar_list():
                var id := str(av.id)
                var ok := ProfileData.is_avatar_unlocked(av, _save.lab_data if _save else null)
                if ok:
                        av_unlocked += 1
                var btn: Button = _av_buttons[id]
                var badge: HexBadge = _av_badges[id]
                var name_l: Label = btn.get_meta("name_l")
                var sel := id == (str(_save.profile_avatar) if _save else "zombie")
                badge.tex = load(ProfileData.get_avatar_icon(av, ok))
                badge.locked = not ok
                badge.rarity = str(av.rar)
                badge.queue_redraw()
                name_l.text = GachaData.display_name(id)
                name_l.add_theme_color_override("font_color",
                        GachaData.rarity_color(str(av.rar)) if ok else BunkerUI.TEXT_FAINT)
                _style_item(btn, sel, not ok)
        _av_count.text = "%d / %d · %s" % [av_unlocked, ProfileData.get_avatar_count(), Loc.t("profile.scroll_hint")]

        var fr_unlocked := 0
        _anim_fr_ids = []
        for f in ProfileData.FRAMES:
                var id := str(f.id)
                var ok := ProfileData.is_frame_unlocked(f, _ctx)
                if ok:
                        fr_unlocked += 1
                var btn: Button = _fr_buttons[id]
                var badge: HexBadge = _fr_badges[id]
                var name_l: Label = btn.get_meta("name_l")
                var sel := id == (str(_save.profile_frame) if _save else "steel")
                badge.light = f.light
                badge.dark = f.dark
                badge.fx = str(f.get("fx", "none"))
                badge.locked = not ok
                badge.queue_redraw()
                if ok and badge.fx != "none":
                        _anim_fr_ids.append(id)
                name_l.text = ProfileData.frame_name(id)
                name_l.add_theme_color_override("font_color",
                        f.light if ok else BunkerUI.TEXT_FAINT)
                _style_item(btn, sel, not ok)
        _fr_count.text = "%d / %d · %s" % [fr_unlocked, ProfileData.FRAMES.size(), Loc.t("profile.scroll_hint")]


func _style_item(btn: Button, selected: bool, locked: bool) -> void:
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(0.055, 0.075, 0.05, 0.85)
        sb.set_corner_radius_all(12)
        sb.set_border_width_all(2)
        if selected:
                sb.border_color = BunkerUI.HAZARD
        else:
                sb.border_color = Color(BunkerUI.STEEL_EDGE, 0.9 if not locked else 0.5)
        sb.content_margin_left = 4
        sb.content_margin_right = 4
        sb.content_margin_top = 4
        sb.content_margin_bottom = 4
        btn.add_theme_stylebox_override("normal", sb)
        var hv := sb.duplicate()
        hv.border_color = BunkerUI.HAZARD if selected else Color(BunkerUI.GREEN, 0.55)
        btn.add_theme_stylebox_override("hover", hv)
        btn.add_theme_stylebox_override("pressed", hv)
        btn.add_theme_stylebox_override("disabled", sb)
        btn.modulate = Color(1, 1, 1, 0.62) if locked else Color.WHITE


func _refresh_stats() -> void:
        for key in _stat_vals:
                var text := ""
                match key:
                        "campaign":
                                text = "%d/100" % int(_ctx.campaign)
                        "floor":
                                text = str(int(_ctx.tower))
                        "waves":
                                text = str(int(_ctx.wave))
                        "arena":
                                text = str(int(_ctx.arena))
                        "runs":
                                text = str(int(_ctx.runs))
                        "coll":
                                text = "%d/%d" % [int(_ctx.collection), ProfileData.get_avatar_count()]
                        "rolls":
                                text = str(_art_rolls())
                _stat_vals[key].text = text


# ==================== ВНУТРЕННИЕ КЛАССЫ ====================

## Правильный шестиугольник (острая вершина сверху), 6 точек по часовой.
static func hex_points(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
        var fxs := [0.5, 1.0, 1.0, 0.5, 0.0, 0.0]
        var fys := [0.0, 0.25, 0.75, 1.0, 0.75, 0.25]
        var pts := PackedVector2Array()
        for i in 6:
                pts.append(center + Vector2((fxs[i] - 0.5) * 2.0 * rx, (fys[i] - 0.5) * 2.0 * ry))
        return pts


## Точка и направление на границе гекса при параметре u (0..1 по периметру).
static func hex_walk(outer: PackedVector2Array, u: float) -> Dictionary:
        var lens := PackedFloat32Array()
        var total := 0.0
        for i in 6:
                var l := outer[i].distance_to(outer[(i + 1) % 6])
                lens.append(l)
                total += l
        var d := fposmod(u, 1.0) * total
        for i in 6:
                if d <= lens[i] or i == 5:
                        var dir := (outer[(i + 1) % 6] - outer[i]).normalized()
                        return {"pos": outer[i] + dir * d, "dir": dir}
                d -= lens[i]
        return {"pos": outer[0], "dir": Vector2.RIGHT}


class ScannerView:
        extends Control

        ## Гексагональный сканер: сетка-фон, три кольца (пунктир зелёный,
        ## тонкая зелёная, жёлтая) с разным направлением вращения, шестигранник
        ## с поясом рамки (конический перелив имитируется цветом кромок),
        ## иконка аватара и бегающая скан-линия.

        var ring_ang := [0.0, 0.0, 0.0]
        var scan_t := 0.0
        var fx_t := 0.0
        var fx := "none"
        var frame_dark: Color = Color("3a4a3a")
        var frame_light: Color = Color("9aa89a")
        var avatar_tex: Texture2D = null
        var avatar_locked := false

        func set_avatar(path: String, locked: bool) -> void:
                avatar_locked = locked
                avatar_tex = null
                if not path.is_empty() and ResourceLoader.exists(path):
                        avatar_tex = load(path)
                queue_redraw()

        func set_avatar_tex(tex: Texture2D, locked: bool) -> void:
                avatar_locked = locked
                avatar_tex = tex
                queue_redraw()

        func set_frame_colors(dark: Color, light: Color) -> void:
                frame_dark = dark
                frame_light = light
                queue_redraw()

        func set_frame_fx(fx_id: String) -> void:
                var changed := fx_id != fx
                fx = fx_id
                if changed:
                        queue_redraw()

        func _process(delta: float) -> void:
                ring_ang[0] += delta * (TAU / 40.0)
                ring_ang[1] -= delta * (TAU / 28.0)
                ring_ang[2] += delta * (TAU / 34.0)
                scan_t += delta
                fx_t += delta
                queue_redraw()

        func _draw() -> void:
                _draw_grid()
                var c := size * 0.5
                var ring_r := minf(size.x, size.y) * 0.49
                if ring_r < 40.0:
                        return
                _draw_rings(c, ring_r)
                _draw_hex(c, ring_r)
                _draw_scanline(c, ring_r)

        func _draw_grid() -> void:
                var g := 44.0
                var col := Color(BunkerUI.GREEN, 0.035)
                var x := 0.0
                while x < size.x:
                        draw_line(Vector2(x, 0), Vector2(x, size.y), col, 1.0)
                        x += g
                var y := 0.0
                while y < size.y:
                        draw_line(Vector2(0, y), Vector2(size.x, y), col, 1.0)
                        y += g

        func _draw_dashed(c: Vector2, r: float, col: Color, rot: float, dash_deg: float, gap_deg: float) -> void:
                var step := deg_to_rad(dash_deg + gap_deg)
                var a := rot
                while a < rot + TAU:
                        draw_arc(c, r, a, a + deg_to_rad(dash_deg), 4, col, 2.0, true)
                        a += step

        func _draw_rings(c: Vector2, ring_r: float) -> void:
                # внешняя: зелёный пунктир, вращение вперёд
                _draw_dashed(c, ring_r, Color(BunkerUI.GREEN, 0.32), ring_ang[0], 7.0, 7.0)
                # средняя: тонкая зелёная, вращение назад
                draw_arc(c, ring_r * 0.885, 0, TAU, 96, Color(BunkerUI.GREEN, 0.15), 2.0, true)
                # внутренняя: жёлтая, вперёд
                draw_arc(c, ring_r * 0.775, 0, TAU, 96, Color(BunkerUI.HAZARD, 0.30), 2.0, true)
                # яркий тик на внешнем кольце
                var a: float = ring_ang[0]
                var p := c + Vector2(cos(a), sin(a)) * ring_r
                var tang := Vector2(-sin(a), cos(a))
                draw_line(p - tang * 9.0, p + tang * 9.0, Color(BunkerUI.GREEN, 0.30), 7.0, true)
                draw_line(p - tang * 8.0, p + tang * 8.0, BunkerUI.GREEN, 3.0, true)

        func _draw_hex(c: Vector2, ring_r: float) -> void:
                var rx := ring_r / 1.41
                var ry := rx * 1.1547
                var outer := ProfileScreen.hex_points(c, rx, ry)
                # пояс рамки: тело тёмное, кромки с переливом (светлее сверху)
                draw_colored_polygon(outer, frame_dark)
                var mid := ProfileScreen.hex_points(c, rx * 0.88, ry * 0.88)
                draw_colored_polygon(mid, Color("0e130d"))
                var inner := ProfileScreen.hex_points(c, rx * 0.80, ry * 0.80)
                draw_colored_polygon(inner, Color("151c12"))
                # мягкое свечение по контуру
                var closed := outer.duplicate()
                closed.append(outer[0])
                draw_polyline(closed, Color(frame_light, 0.22), 9.0, true)
                # кромки: цвет ребра зависит от угла его середины (имитация коники)
                for i in 6:
                        var a: Vector2 = outer[i]
                        var b: Vector2 = outer[(i + 1) % 6]
                        var m := (a + b) * 0.5
                        var ang := atan2(m.y - c.y, m.x - c.x)
                        var t := 0.5 + 0.5 * cos(ang + PI * 0.5)
                        var edge_col := frame_dark.lerp(frame_light, 0.30 + 0.70 * t)
                        draw_line(a, b, edge_col, 3.0, true)
                _draw_fx(c, rx, ry, outer)
                # иконка аватара (квадратная карточка внутри шестигранника)
                if avatar_tex:
                        var side := rx * 1.16
                        var rect := Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side))
                        var tint := Color(0.62, 0.66, 0.62, 0.85) if avatar_locked else Color.WHITE
                        draw_texture_rect(avatar_tex, rect, false, tint)

        func _draw_scanline(c: Vector2, ring_r: float) -> void:
                var rx := ring_r / 1.41
                var ry := rx * 1.1547
                var y := c.y + sin(scan_t * 1.15) * ry * 0.82
                var x0 := c.x - rx * 0.92
                var x1 := c.x + rx * 0.92
                draw_line(Vector2(x0, y), Vector2(x1, y), Color(BunkerUI.GREEN, 0.12), 10.0, true)
                draw_line(Vector2(x0, y), Vector2(x1, y), Color(BunkerUI.GREEN, 0.28), 5.0, true)
                draw_line(Vector2(x0, y), Vector2(x1, y), Color(BunkerUI.GREEN, 0.95), 2.0, true)

        ## Эффекты рамок поверх кромок: pulse (пульс) / shine (бегущий блик) /
        ## reactor (свечение САРКОФАГА: гало, дуги-обход, искры, мерцание).
        func _draw_fx(c: Vector2, rx: float, ry: float, outer: PackedVector2Array) -> void:
                match fx:
                        "pulse":
                                var k := 0.5 + 0.5 * sin(fx_t * 1.9)
                                var g := ProfileScreen.hex_points(c, rx * 1.05, ry * 1.05)
                                var gc := g.duplicate()
                                gc.append(g[0])
                                draw_polyline(gc, Color(frame_light, 0.05 + 0.15 * k), 10.0, true)
                        "shine":
                                var u := fposmod(fx_t * 0.11, 1.0)
                                for i in 3:
                                        var w := ProfileScreen.hex_walk(outer, u - 0.055 * float(i))
                                        var wp: Vector2 = w.pos
                                        var wd: Vector2 = w.dir
                                        var tail: Vector2 = wp - wd * (rx * 0.11)
                                        var a := 0.85 - 0.25 * float(i)
                                        draw_line(wp, tail, Color(frame_light, a * 0.5), 6.0, true)
                                        draw_line(wp, tail, Color(1, 1, 1, a), 2.2, true)
                        "reactor":
                                var kr := 0.5 + 0.5 * sin(fx_t * 2.6)
                                var fl := pow(maxf(0.0, sin(fx_t * 7.3 + sin(fx_t * 2.9) * 1.7)), 24.0)
                                var g2 := ProfileScreen.hex_points(c, rx * 1.07, ry * 1.07)
                                var g2c := g2.duplicate()
                                g2c.append(g2[0])
                                draw_polyline(g2c, Color(frame_light, 0.06 + 0.10 * kr), 24.0, true)
                                draw_polyline(g2c, Color(frame_light, 0.10 + 0.16 * kr + 0.22 * fl), 11.0, true)
                                var sr := rx * 1.26
                                for s_i in 2:
                                        var a0 := fx_t * 0.85 + PI * float(s_i)
                                        draw_arc(c, sr, a0, a0 + 0.5, 12,
                                                Color(frame_light, 0.10 + 0.22 * kr), 3.0, true)
                                for i in 10:
                                        var fi := float(i)
                                        var ph := fi * 0.618034
                                        var yy := fposmod(fx_t * (0.055 + 0.03 * fmod(fi, 3.0)) + ph, 1.0)
                                        var ang := TAU * (0.18 * yy + ph * 0.13) + fi * TAU / 10.0
                                        var rad := rx * (1.12 + 0.08 * yy)
                                        var pos := c + Vector2(cos(ang) * rad, sin(ang) * rad * 1.1547)
                                        var al := sin(yy * PI)
                                        draw_circle(pos, 1.6 + 0.9 * fmod(fi, 2.0),
                                                Color(frame_light, 0.45 * al))
                                        draw_circle(pos, 0.8, Color(1.0, 0.95, 0.8, 0.6 * al))


class HexBadge:
        extends Control

        ## Мини-шестигранник для лент: рамка-пояс + иконка карточки
        ## (серая, если закрыто) или пустой центр для превью рамок.

        var light: Color = Color("9aa89a")
        var dark: Color = Color("3a4a3a")
        var tex: Texture2D = null
        var locked := false
        var rarity := ""
        var is_frame_preview := false
        var fx := "none"

        func _draw() -> void:
                if size.x < 8.0 or size.y < 8.0:
                        return
                var c := size * 0.5
                var rx := size.x * 0.5
                var ry := size.y * 0.5
                var outer := ProfileScreen.hex_points(c, rx, ry)
                draw_colored_polygon(outer, dark)
                var inner := ProfileScreen.hex_points(c, rx * 0.84, ry * 0.84)
                draw_colored_polygon(inner, Color("10150f"))
                if is_frame_preview:
                        # превью рамки: подсветить цвет пояса изнутри
                        var belt := ProfileScreen.hex_points(c, rx * 0.70, ry * 0.70)
                        draw_colored_polygon(belt, Color(dark.lightened(0.10), 0.9))
                        var core := ProfileScreen.hex_points(c, rx * 0.52, ry * 0.52)
                        draw_colored_polygon(core, Color("10150f"))
                elif tex:
                        var side := minf(size.x, size.y) * 0.66
                        var rect := Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side))
                        var tint := Color(0.55, 0.58, 0.55, 0.75) if locked else Color.WHITE
                        draw_texture_rect(tex, rect, false, tint)
                var border_col := light
                if not is_frame_preview and not rarity.is_empty():
                        border_col = GachaData.rarity_color(rarity)
                if locked:
                        border_col = Color(border_col, 0.35)
                var closed := outer.duplicate()
                closed.append(outer[0])
                draw_polyline(closed, border_col, 2.0, true)
                if locked:
                        draw_string(BunkerUI.font_title(), Vector2(0, size.y * 0.5 + 8), "?",
                                HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(light, 0.55))
                        return
                if fx == "none":
                        return
                # эффекты рамок на открытых бейджах (время общее, без состояния)
                var t := Time.get_ticks_msec() / 1000.0
                match fx:
                        "pulse":
                                var k := 0.5 + 0.5 * sin(t * 2.0)
                                draw_polyline(closed, Color(light, 0.10 + 0.22 * k), 4.0, true)
                        "shine":
                                var u := fposmod(t * 0.13, 1.0)
                                var w: Dictionary = ProfileScreen.hex_walk(outer, u)
                                var wp: Vector2 = w.pos
                                draw_circle(wp, 2.8, Color(light, 0.85))
                                draw_circle(wp, 1.2, Color(1, 1, 1, 0.8))
                        "reactor":
                                var k2 := 0.5 + 0.5 * sin(t * 2.6)
                                draw_polyline(closed, Color(light, 0.12 + 0.26 * k2), 5.0, true)
                                for i in 2:
                                        var fi := float(i)
                                        var yy := fposmod(t * 0.22 + fi * 0.5, 1.0)
                                        var yoff := (0.5 - yy) * ry * 0.9
                                        var xoff := sin(t * 1.7 + fi * PI) * rx * 0.35
                                        draw_circle(c + Vector2(xoff, yoff), 1.8,
                                                Color(light, 0.55 * sin(yy * PI)))
