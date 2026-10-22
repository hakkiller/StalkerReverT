# ui/gacha/gacha_controller.gd
extends Control

## ГАЧА ЗОНЫ — отдельный полноэкранный узел комплекса (стиль БУНКЕР).
## Макет «ДАР ЗОНЫ»: шапка с джекпот-строкой, два ряда карточных полос,
## свечение редкости, большой ПРИЗЫВ ×10, шансы справа внизу.
## Два рукава: МУТАНТЫ / АРТЕФАКТЫ (вкладки под шапкой).
## Механики из data/gacha_data.gd: шансы по уровню кампании, джекпот-Химера
## (исключена до ур.30, гарантия ур.50), дубликаты, бонусы артефактов.

const RAR_ORDER := ["common", "uncommon", "rare", "legendary"]
const RAR_RU := {"common": "ОБЫЧНЫЙ", "uncommon": "НЕОБЫЧНЫЙ", "rare": "РЕДКИЙ", "legendary": "ЛЕГЕНДАРНЫЙ", "ex": "ЭКСКЛЮЗИВ"}
const RAR_SHORT := {"common": "ОБЫЧНЫЙ", "uncommon": "НЕОБЫЧНЫЙ", "rare": "РЕДКИЙ", "legendary": "ЛЕГЕНДА", "ex": "ЭКСКЛЮЗИВ"}

var _arm: String = "mutants"
var _arm_buttons: Dictionary = {}
var _arm_counts: Dictionary = {}
# Тач-жест: свайп по витрине = сменить рукав (как в вратах ярусов — только mouse-семейство)
var _swipe_catcher: Control
var _swipe_pos: Vector2 = Vector2.ZERO
var _swipe_active: bool = false
var _arm_tween: Tween
var _strips_home: Vector2 = Vector2.ZERO   # дом витрины (до сдвигов; присваивание position перезаписывает offsets!)
const SWIPE_THRESHOLD := 80.0
# Полосы призыва (2 ряда по 6)
var _strips_row1: HBoxContainer
var _strips_row2: HBoxContainer
var _jackpot_line: Label
var _rolls_plate_value: Label = null
var _tries_label: Label
var _chances_label: Label
var _spin1_btn: Button
var _spin10_btn: Button
# ПРИЗ НА ВЫБОР: кнопка супер-рукава + оверлей выбора из шести эксклюзивов
var _choice_btn: Button
var _choice_overlay: Control
var _choice_box: GridContainer
var _choice_title: Label
# Коллекция (оверлей)
var _coll_overlay: Control
var _coll_box: GridContainer
var _coll_title: Label
# Прочее
var _session_drops: Array = []
var _toast: PanelContainer
var _toast_label: Label
var _game_manager: Node


func _ready() -> void:
        # Фон
        var bg := TextureRect.new()
        bg.texture = load("res://ui/gacha/gacha_bg.svg")
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(bg)

        var dim := ColorRect.new()
        dim.color = Color(0.012, 0.014, 0.008, 0.88)
        dim.set_anchors_preset(Control.PRESET_FULL_RECT)
        dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(dim)

        BunkerUI.apply_bunker(self, true)

        _build_header()
        _build_strips()
        _build_bottom()
        _build_collection_overlay()
        _build_choice_overlay()
        _build_toast()

        _game_manager = get_tree().get_first_node_in_group("game_manager")
        _refresh_all()
        Loc.changed.connect(_refresh_all)


# ==================== ПОСТРОЕНИЕ ====================

func _build_header() -> void:
        var head := HBoxContainer.new()
        head.add_theme_constant_override("separation", 20)
        head.anchor_left = 0.0
        head.anchor_right = 1.0
        head.offset_left = 44
        head.offset_right = -44
        head.offset_top = 30
        head.offset_bottom = 96
        add_child(head)

        var tv := VBoxContainer.new()
        tv.add_theme_constant_override("separation", 0)
        var h1 := HBoxContainer.new()
        h1.add_theme_constant_override("separation", 10)
        var t1 := Label.new()
        t1.text = "ДАР"
        t1.add_theme_font_override("font", BunkerUI.font_title())
        t1.add_theme_font_size_override("font_size", 40)
        t1.add_theme_color_override("font_color", BunkerUI.TEXT_LIGHT)
        var t2 := Label.new()
        t2.text = "ЗОНЫ"
        t2.add_theme_font_override("font", BunkerUI.font_title())
        t2.add_theme_font_size_override("font_size", 40)
        t2.add_theme_color_override("font_color", BunkerUI.HAZARD)
        h1.add_child(t1)
        h1.add_child(t2)
        tv.add_child(h1)

        _jackpot_line = BunkerUI.make_mono_label("", 14, Color("66794f"))
        tv.add_child(_jackpot_line)
        head.add_child(tv)

        # Вкладки рукавов
        var arms := HBoxContainer.new()
        arms.add_theme_constant_override("separation", 8)
        arms.alignment = BoxContainer.ALIGNMENT_CENTER
        arms.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        arms.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        for arm in ["mutants", "artifacts", "super"]:
                var tab := Button.new()
                tab.custom_minimum_size = Vector2(190, 56)
                BunkerUI.style_button(tab, "steel", 17)
                tab.pressed.connect(_on_arm_pressed.bind(arm))
                tab.mouse_entered.connect(_play_hover_sound)
                _arm_buttons[arm] = tab
                var hb := HBoxContainer.new()
                hb.set_anchors_preset(Control.PRESET_FULL_RECT)
                hb.offset_left = 14
                hb.offset_right = -14
                hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
                hb.add_theme_constant_override("separation", 10)
                var lamp := BunkerUI.make_lamp(arm == _arm)
                hb.add_child(lamp)
                var tl := Label.new()
                tl.text = Loc.t("gacha.arm_" + arm)
                tl.add_theme_font_override("font", BunkerUI.font_body())
                tl.add_theme_font_size_override("font_size", 18)
                tl.add_theme_color_override("font_color", BunkerUI.TEXT_BRIGHT)
                tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
                hb.add_child(tl)
                var cnt := BunkerUI.make_mono_label("x0", 17, BunkerUI.GREEN)
                cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
                _arm_counts[arm] = cnt
                hb.add_child(cnt)
                tab.add_child(hb)
                arms.add_child(tab)
        head.add_child(arms)

        # Пластина круток текущего рукава
        var rolls_plate := BunkerUI.make_plate("0", "КРУТКИ", 150.0)
        rolls_plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        head.add_child(rolls_plate)
        _rolls_plate_value = rolls_plate.get_child(0).get_child(0)


func _build_strips() -> void:
        var box := VBoxContainer.new()
        box.add_theme_constant_override("separation", 12)
        box.anchor_left = 0.0
        box.anchor_right = 1.0
        box.anchor_top = 0.0
        box.anchor_bottom = 1.0
        box.offset_left = 44
        box.offset_right = -44
        box.offset_top = 112
        box.offset_bottom = -226
        add_child(box)

        _strips_row1 = HBoxContainer.new()
        _strips_row1.add_theme_constant_override("separation", 12)
        _strips_row1.size_flags_vertical = Control.SIZE_EXPAND_FILL
        box.add_child(_strips_row1)

        _strips_row2 = HBoxContainer.new()
        _strips_row2.add_theme_constant_override("separation", 12)
        _strips_row2.size_flags_vertical = Control.SIZE_EXPAND_FILL
        box.add_child(_strips_row2)

        # Ловушка свайпов поверх витрины (те же границы, что у box): полосы сами
        # некликабельны, так что перекрытие ничего не ломает; кнопки шапки/низа
        # и оверлеи добавляются позже — они выше и принимают ввод первыми.
        _swipe_catcher = Control.new()
        _swipe_catcher.anchor_left = 0.0
        _swipe_catcher.anchor_right = 1.0
        _swipe_catcher.anchor_top = 0.0
        _swipe_catcher.anchor_bottom = 1.0
        _swipe_catcher.offset_left = 44
        _swipe_catcher.offset_right = -44
        _swipe_catcher.offset_top = 112
        _swipe_catcher.offset_bottom = -226
        _swipe_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
        _swipe_catcher.gui_input.connect(_on_swipe_gui)
        add_child(_swipe_catcher)
        # Дом витрины для анимации смены рукава — фиксируем ДО каких-либо сдвигов:
        # присваивание position перезаписывает offsets, поэтому читать offsets
        # после сдвига нельзя (твин уедет вбок — поймал смоук на спам-смене).
        _strips_home = Vector2(box.offset_left, box.offset_top)


func _build_bottom() -> void:
        # НАЗАД слева
        var back := Button.new()
        back.text = "◄"
        back.custom_minimum_size = Vector2(92, 70)
        back.anchor_left = 0.0
        back.anchor_right = 0.0
        back.anchor_top = 1.0
        back.anchor_bottom = 1.0
        back.offset_left = 44
        back.offset_right = 136
        back.offset_top = -108
        back.offset_bottom = -38
        BunkerUI.style_button(back, "steel", 26)
        back.pressed.connect(_on_back_pressed)
        back.mouse_entered.connect(_play_hover_sound)
        add_child(back)

        # Центр: ПРИЗЫВ x1 + ПРИЗЫВ x10 + попытки
        var center := VBoxContainer.new()
        center.alignment = BoxContainer.ALIGNMENT_CENTER
        center.add_theme_constant_override("separation", 6)
        center.anchor_left = 0.5
        center.anchor_right = 0.5
        center.anchor_top = 1.0
        center.anchor_bottom = 1.0
        center.offset_left = -430
        center.offset_right = 430
        center.offset_top = -116
        center.offset_bottom = -30
        add_child(center)

        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 22)
        row.alignment = BoxContainer.ALIGNMENT_CENTER
        center.add_child(row)

        _spin1_btn = Button.new()
        _spin1_btn.text = "ПРИЗЫВ  ×1"
        _spin1_btn.custom_minimum_size = Vector2(230, 62)
        BunkerUI.style_button(_spin1_btn, "steel", 19)
        _spin1_btn.pressed.connect(_on_spin.bind(1))
        _spin1_btn.mouse_entered.connect(_play_hover_sound)
        row.add_child(_spin1_btn)

        _spin10_btn = Button.new()
        _spin10_btn.text = "ПРИЗЫВ  ×10"
        _spin10_btn.custom_minimum_size = Vector2(420, 74)
        BunkerUI.style_button(_spin10_btn, "hazard", 26, true)
        _spin10_btn.pressed.connect(_on_spin.bind(10))
        _spin10_btn.mouse_entered.connect(_play_hover_sound)
        row.add_child(_spin10_btn)

        _tries_label = BunkerUI.make_mono_label("", 15, Color("9fb57f"))
        _tries_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        center.add_child(_tries_label)

        # Шансы справа внизу
        _chances_label = BunkerUI.make_mono_label("", 13, Color("66794f"))
        _chances_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        _chances_label.anchor_left = 1.0
        _chances_label.anchor_right = 1.0
        _chances_label.anchor_top = 1.0
        _chances_label.anchor_bottom = 1.0
        _chances_label.offset_left = -560
        _chances_label.offset_right = -44
        _chances_label.offset_top = -104
        _chances_label.offset_bottom = -34
        add_child(_chances_label)
        
        # ПРИЗ НА ВЫБОР (супер-рукав): слева снизу, правее НАЗАД
        _choice_btn = Button.new()
        _choice_btn.text = "ПРИЗ НА ВЫБОР"
        _choice_btn.custom_minimum_size = Vector2(320, 70)
        _choice_btn.anchor_left = 0.0
        _choice_btn.anchor_right = 0.0
        _choice_btn.anchor_top = 1.0
        _choice_btn.anchor_bottom = 1.0
        _choice_btn.offset_left = 156
        _choice_btn.offset_right = 476
        _choice_btn.offset_top = -108
        _choice_btn.offset_bottom = -38
        BunkerUI.style_button(_choice_btn, "steel", 15)
        _choice_btn.pressed.connect(_on_choice_open)
        _choice_btn.mouse_entered.connect(_play_hover_sound)
        add_child(_choice_btn)


func _build_collection_overlay() -> void:
        _coll_overlay = Control.new()
        _coll_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
        _coll_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
        _coll_overlay.visible = false
        add_child(_coll_overlay)

        var shade := ColorRect.new()
        shade.set_anchors_preset(Control.PRESET_FULL_RECT)
        shade.color = Color(0, 0, 0, 0.78)
        shade.gui_input.connect(func(ev):
                if ev is InputEventMouseButton and ev.pressed:
                        _coll_overlay.visible = false)
        _coll_overlay.add_child(shade)

        var panel := PanelContainer.new()
        panel.anchor_left = 0.5
        panel.anchor_top = 0.5
        panel.anchor_right = 0.5
        panel.anchor_bottom = 0.5
        panel.offset_left = -560
        panel.offset_top = -330
        panel.offset_right = 560
        panel.offset_bottom = 330
        _coll_overlay.add_child(panel)

        var v := VBoxContainer.new()
        v.add_theme_constant_override("separation", 10)
        panel.add_child(v)

        var top := HBoxContainer.new()
        _coll_title = BunkerUI.make_section_label("")
        _coll_title.add_theme_font_size_override("font_size", 20)
        _coll_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        top.add_child(_coll_title)
        var cback := Button.new()
        cback.text = "НАЗАД"
        cback.custom_minimum_size = Vector2(140, 44)
        BunkerUI.style_button(cback, "steel", 15)
        cback.pressed.connect(func(): _coll_overlay.visible = false)
        top.add_child(cback)
        v.add_child(top)

        var scroll := ScrollContainer.new()
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        v.add_child(scroll)

        _coll_box = GridContainer.new()
        _coll_box.columns = 10
        _coll_box.add_theme_constant_override("h_separation", 8)
        _coll_box.add_theme_constant_override("v_separation", 8)
        _coll_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll.add_child(_coll_box)


func _build_toast() -> void:
        _toast = PanelContainer.new()
        var sb := BunkerUI.steel()
        sb.border_color = BunkerUI.HAZARD
        _toast.add_theme_stylebox_override("panel", sb)
        _toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
        _toast.visible = false
        _toast.z_index = 50
        _toast_label = Label.new()
        _toast_label.add_theme_font_size_override("font_size", 18)
        _toast_label.add_theme_color_override("font_color", BunkerUI.HAZARD_BRIGHT)
        _toast.add_child(_toast_label)
        add_child(_toast)


# ==================== ДАННЫЕ ====================

func _lab():
        if _game_manager:
                return _game_manager.get_lab_data()
        return null


func _level() -> int:
        if _game_manager:
                return _game_manager.get_campaign_level()
        return 1


func _rolls_text(n: int) -> String:
        return "∞" if n >= 1000000 else str(n)


func _collection_types() -> Array:
        # 10 мутантов + 18 артефактов = 28, порядок как в пулах
        var out: Array = []
        for rarity in RAR_ORDER:
                for e in GachaData.MUTANT_POOL[rarity]:
                        out.append(["mut", e[0]])
        for rarity in ["common", "rare", "legendary"]:
                for t in GachaData.ARTIFACT_POOL[rarity]:
                        out.append(["art", t])
        # Эксклюзивы Чёрного ящика замыкают коллекцию (фиолетовая рамка)
        for ex in GachaData.EXCLUSIVE_MUTANTS:
                out.append(["mut", str(ex["type"])])
        for ax in GachaData.EXCLUSIVE_ANOMALIES:
                out.append(["art", str(ax["type"])])
        return out


## Витрина пула рукава: 12 позиций, легендарки первыми
func _showcase_items() -> Array:
        var out: Array = []
        if _arm == "super":
                for ex in GachaData.EXCLUSIVE_MUTANTS:
                        out.append(["mut", str(ex["type"]), "ex"])
                for ax in GachaData.EXCLUSIVE_ANOMALIES:
                        out.append(["art", str(ax["type"]), "ex"])
                return out
        if _arm == "mutants":
                for rarity in ["legendary", "rare", "uncommon", "common"]:
                        for e in GachaData.MUTANT_POOL[rarity]:
                                out.append(["mut", str(e[0]), rarity])
        else:
                for rarity in ["legendary", "rare", "common"]:
                        for t in GachaData.ARTIFACT_POOL[rarity]:
                                out.append(["art", str(t), rarity])
        return out


# ==================== ПОЛОСЫ ПРИЗЫВА ====================

func _make_strip(kind: String, type: String, rar: String, stars: int, status: String = "") -> Control:
        """Карточная полоса призыва: свечение редкости, тег редкости, буква, звёзды, имя"""
        var is_mut := kind == "mut"
        var col: Color = Color("b48cff") if rar == "ex" else BunkerUI.RARHEX.get(rar, BunkerUI.TEXT)
        var owned := stars > 0

        var strip := Panel.new()
        strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(0.078, 0.098, 0.055)
        sb.border_color = Color(col, 0.75 if owned else 0.35)
        sb.set_border_width_all(2)
        sb.set_corner_radius_all(10)
        var glow_power := 0.0
        match rar:
                "legendary": glow_power = 40.0
                "ex": glow_power = 40.0
                "rare": glow_power = 22.0
                "uncommon": glow_power = 10.0
        if owned:
                glow_power = maxf(glow_power, 14.0)
        sb.shadow_color = Color(col, 0.35)
        sb.shadow_size = int(glow_power)
        sb.shadow_offset = Vector2.ZERO
        strip.add_theme_stylebox_override("panel", sb)

        var v := VBoxContainer.new()
        v.set_anchors_preset(Control.PRESET_FULL_RECT)
        v.offset_left = 8
        v.offset_right = -8
        v.offset_top = 8
        v.offset_bottom = -8
        v.add_theme_constant_override("separation", 4)
        v.mouse_filter = Control.MOUSE_FILTER_IGNORE
        strip.add_child(v)

        # Тег редкости
        var tag := Label.new()
        var tag_txt: String = RAR_SHORT.get(rar, "—")
        if not is_mut:
                tag_txt += " АРТ"
        if status == "new":
                tag_txt += " · НОВЫЙ"
        elif status == "dup":
                tag_txt += " · ДУБЛЬ"
        elif status == "star":
                tag_txt += " · +★"
        elif status == "dup_max":
                tag_txt += " · В БИО"
        tag.text = tag_txt
        tag.add_theme_font_override("font", BunkerUI.font_mono())
        tag.add_theme_font_size_override("font_size", 11)
        tag.add_theme_color_override("font_color", Color("171003") if rar == "legendary" else col)
        var tag_sb := StyleBoxFlat.new()
        tag_sb.bg_color = BunkerUI.HAZARD if rar == "legendary" else Color(col, 0.16)
        tag_sb.set_corner_radius_all(4)
        tag_sb.content_margin_left = 6.0
        tag_sb.content_margin_right = 6.0
        tag_sb.content_margin_top = 2.0
        tag_sb.content_margin_bottom = 2.0
        tag.add_theme_stylebox_override("normal", tag_sb)
        v.add_child(tag)

        # Большая буква
        var letter := Label.new()
        letter.text = Loc.type_name(type).substr(0, 1)
        letter.add_theme_font_override("font", BunkerUI.font_title())
        letter.add_theme_font_size_override("font_size", 84)
        letter.add_theme_color_override("font_color", Color(col, 0.5 if owned else 0.22))
        letter.size_flags_vertical = Control.SIZE_EXPAND_FILL
        letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.add_child(letter)

        # Звёзды (для витрины — по редкости, для дропа — реальные)
        var st := Label.new()
        var shown: int = stars
        if stars < 0:
                match rar:
                        "legendary": shown = 3
                        "ex": shown = 3
                        "rare": shown = 2
                        _: shown = 1
        if shown > 0:
                st.text = "★".repeat(shown) + "☆".repeat(maxi(5 - shown, 0))
        else:
                st.text = "☆ ☆ ☆ ☆ ☆"
        st.add_theme_font_override("font", BunkerUI.font_mono())
        st.add_theme_font_size_override("font_size", 16)
        st.add_theme_color_override("font_color", Color("ffd94d") if owned else Color("454b39"))
        st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.add_child(st)

        var nm := Label.new()
        nm.text = Loc.type_name(type).to_upper()
        nm.add_theme_font_override("font", BunkerUI.font_title())
        nm.add_theme_font_size_override("font_size", 14)
        nm.add_theme_color_override("font_color", BunkerUI.TEXT_LIGHT if owned else BunkerUI.TEXT_DIM)
        nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        nm.clip_text = true
        v.add_child(nm)
        return strip


## Звёзды витрины для любых типов: эксклюзивные аномалии живут в
## exclusive_anomalies (не в won_artifacts) - единая точка проверки владения.
func _owned_stars(kind: String, type: String, lab) -> int:
        if lab == null:
                return -1
        if kind == "mut":
                if lab.unlocked_mutants.has(type):
                        return lab.get_mutant_stars(type)
        elif lab.won_artifacts.has(type) or lab.exclusive_anomalies.has(type):
                return lab.get_artifact_stars(type)
        return -1


func _refresh_strips() -> void:
        for c in _strips_row1.get_children():
                _strips_row1.remove_child(c)
                c.queue_free()
        for c in _strips_row2.get_children():
                _strips_row2.remove_child(c)
                c.queue_free()
        var lab = _lab()
        var rows: Array = [[], []]

        if _session_drops.is_empty():
                # Витрина пула: 12 позиций, звёзды «по редкости» (stars = -1)
                for item in _showcase_items().slice(0, 12):
                        rows[0].append([item[0], item[1], item[2], _owned_stars(item[0], item[1], lab), ""])
        else:
                for r in _session_drops.slice(0, 12):
                        var dkind: String = str(r.get("kind", "mut" if str(r.get("arm", "mutants")) == "mutants" else "art"))
                        rows[0].append([dkind, str(r.get("type", "")), str(r.get("rarity", "common")), -2, str(r.get("status", ""))])
                # Реальные звёзды дропов
                var fixed: Array = []
                for item in rows[0]:
                        fixed.append([item[0], item[1], item[2], _owned_stars(item[0], item[1], lab), item[4]])
                rows[0] = fixed

        # Второй ряд: если дропов мало — добираем витриной пула
        if rows[0].size() <= 6:
                var showcase: Array = _showcase_items()
                var used: Array = []
                for item in rows[0]:
                        used.append(item[1])
                for item in showcase:
                        if rows[0].size() + rows[1].size() >= 12:
                                break
                        if used.has(item[1]):
                                continue
                        rows[1].append([item[0], item[1], item[2], _owned_stars(item[0], item[1], lab), ""])
        else:
                for item in rows[0].slice(6, 12):
                        rows[1].append(item)
                rows[0] = rows[0].slice(0, 6)

        for item in rows[0]:
                _strips_row1.add_child(_make_strip(item[0], item[1], item[2], int(item[3]), str(item[4])))
        for item in rows[1]:
                _strips_row2.add_child(_make_strip(item[0], item[1], item[2], int(item[3]), str(item[4])))


# ==================== ОБНОВЛЕНИЕ ====================

func _refresh_all() -> void:
        _refresh_header()
        _refresh_arms()
        _refresh_strips()
        _refresh_bottom()
        _refresh_collection()


func _refresh_header() -> void:
        var lab = _lab()
        var unlocked := 0
        if lab:
                unlocked = lab.unlocked_mutants.size() + lab.won_artifacts.size()
        var jack_line := "джекпот: Химера · гарантия на 50-м уровне · хранилище %d/%d · дубликаты идут в копии и звёзды" % [unlocked, GachaData.total_collection_size()]
        if _arm == "artifacts":
                jack_line = "артефактный рукав · бонусы энергии и биомассы · хранилище %d/28" % unlocked
        if _arm == "super":
                jack_line = "супер-призыв: ТОЛЬКО эксклюзивы Чёрных ящиков · гарантия нового, пока собраны не все · хранилище %d/%d" % [unlocked, GachaData.total_collection_size()]
        _jackpot_line.text = jack_line


func _refresh_arms() -> void:
        var lab = _lab()
        for arm in ["mutants", "artifacts", "super"]:
            if _arm_buttons.has(arm):
                var tab: Button = _arm_buttons[arm]
                var is_on: bool = arm == _arm
                var cnt: Label = _arm_counts[arm]
                var n: int = lab.super_pulls if arm == "super" else (lab.gacha_rolls_mutants if arm == "mutants" else lab.gacha_rolls_artifacts)
                cnt.text = "x" + _rolls_text(n)
                cnt.add_theme_color_override("font_color", BunkerUI.GREEN if is_on else BunkerUI.TEXT_DIM)
                var sb: StyleBoxFlat = tab.get_theme_stylebox("normal")
                if sb:
                        sb.border_color = BunkerUI.HAZARD if is_on else BunkerUI.STEEL_EDGE
        if _rolls_plate_value and lab:
                var n2: int = lab.super_pulls if _arm == "super" else (lab.gacha_rolls_mutants if _arm == "mutants" else lab.gacha_rolls_artifacts)
                _rolls_plate_value.text = _rolls_text(n2)


func _refresh_bottom() -> void:
        var lab = _lab()
        var rolls := 0
        if lab:
                rolls = lab.super_pulls if _arm == "super" else (lab.gacha_rolls_mutants if _arm == "mutants" else lab.gacha_rolls_artifacts)
        _spin1_btn.disabled = rolls < 1
        _spin10_btn.disabled = rolls < 1
        _spin1_btn.text = "СУПЕР-ПРИЗЫВ  ×1" if _arm == "super" else "ПРИЗЫВ  ×1"
        _spin10_btn.text = "СУПЕР-ПРИЗЫВ  ×10" if _arm == "super" else "ПРИЗЫВ  ×10"
        var prog: int = int(lab.super_pull_progress) if lab else 0
        if _arm == "super":
                _tries_label.text = "Супер-крутки: %d · бонус обычных: %d/%d · ВЫБОР приза: %d/%d" % [rolls, prog, GachaData.SUPER_PITY, int(lab.super_choice_progress) if lab else 0, GachaData.SUPER_CHOICE_PITY]
        elif _arm == "mutants":
                var to_guarantee: int = maxi(GachaData.CHIMERA_GUARANTEE_LEVEL - _level(), 0)
                if to_guarantee > 0:
                        _tries_label.text = "Попытки: %s · до гаранта Химеры ещё %d ур." % [_rolls_text(rolls), to_guarantee]
                else:
                        _tries_label.text = "Попытки: %s · гарант Химеры АКТИВЕН" % _rolls_text(rolls)
        else:
                _tries_label.text = "Попытки: %s · артефакты дают энергию и биомассу" % _rolls_text(rolls)

        # Шансы
        var w := GachaData.rarity_weights(_level())
        if _arm == "super":
                _chances_label.text = "пул: 3 эксклюзивных мутанта + 3 эксклюзивные аномалии\n+1 супер-крутка за каждые %d обычных призывов\n+1 ПРИЗ НА ВЫБОР за каждые %d супер-призывов" % [GachaData.SUPER_PITY, GachaData.SUPER_CHOICE_PITY]
        elif _arm == "mutants":
                _chances_label.text = "шансы: %d%% обычный · %d%% необычный · %d%% редкий · %d%% легенда\n+1 крутка за 10-ю и 30-ю волну выживания" % [
                        roundi(w["common"]), roundi(w["uncommon"]), roundi(w["rare"]), roundi(w["legendary"])]
        else:
                _chances_label.text = "шансы: %d%% обычный · %d%% редкий · %d%% легенда\nсдача копий: 10 очков = 1 крутка артефактов" % [
                        roundi(w["common"]), roundi(w["rare"] + w["uncommon"]), roundi(w["legendary"])]
        
        # Кнопка приза на выбор: видна только в супер-рукаве
        var tokens: int = int(lab.super_choice_tokens) if lab else 0
        _choice_btn.visible = _arm == "super"
        _choice_btn.disabled = tokens < 1
        if tokens > 0:
                _choice_btn.text = "ПРИЗ НА ВЫБОР ГОТОВ ×%d" % tokens
                BunkerUI.style_button(_choice_btn, "hazard", 16, true)
        else:
                _choice_btn.text = "ПРИЗ НА ВЫБОР · %d/%d супер-призывов" % [int(lab.super_choice_progress) if lab else 0, GachaData.SUPER_CHOICE_PITY]
                BunkerUI.style_button(_choice_btn, "steel", 14)


func _refresh_collection() -> void:
        for c in _coll_box.get_children():
                c.queue_free()
        var lab = _lab()
        var unlocked := 0
        for pair in _collection_types():
                var kind: String = pair[0]
                var type: String = pair[1]
                var is_mut := kind == "mut"
                var has := false
                if lab:
                        if is_mut:
                                has = lab.unlocked_mutants.has(type)
                        elif GachaData.is_exclusive_anomaly(type):
                                has = lab.exclusive_anomalies.has(type)
                        else:
                                has = lab.won_artifacts.has(type)
                if has:
                        unlocked += 1
                _coll_box.add_child(_make_coll_tile(kind, type, has))
        _coll_title.text = "КОЛЛЕКЦИЯ %d/%d" % [unlocked, GachaData.total_collection_size()]


func _make_coll_tile(kind: String, type: String, has: bool) -> Control:
        var tile := Panel.new()
        tile.custom_minimum_size = Vector2(74, 74)
        var tsb := StyleBoxFlat.new()
        tsb.bg_color = Color("0a100b")
        tsb.set_border_width_all(2)
        tsb.set_corner_radius_all(8)
        if has:
                if GachaData.is_exclusive(type) or GachaData.is_exclusive_anomaly(type):
                        tsb.border_color = Color("b48cff")
                else:
                        var rar := GachaData.get_mutant_rarity(type) if kind == "mut" else GachaData.get_artifact_rarity(type)
                        tsb.border_color = BunkerUI.RARHEX.get(rar, BunkerUI.STEEL_EDGE)
        else:
                tsb.border_color = Color("232b23")
                tsb.bg_color = Color("0c0f0c")
        tile.add_theme_stylebox_override("panel", tsb)
        if has and (GachaData.is_exclusive(type) or GachaData.is_exclusive_anomaly(type)):
                tile.tooltip_text = Loc.type_name(type) + "\nэксклюзив Чёрного ящика"
        else:
                tile.tooltip_text = Loc.type_name(type) if has else Loc.t("card.locked")
        var icon := TextureRect.new()
        var path := GachaData.card_icon_path(type, kind == "mut", not has)
        if ResourceLoader.exists(path):
                icon.texture = load(path)
        icon.set_anchors_preset(Control.PRESET_FULL_RECT)
        icon.offset_left = 3
        icon.offset_top = 3
        icon.offset_right = -3
        icon.offset_bottom = -3
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        tile.add_child(icon)
        return tile


# ==================== ОБРАБОТЧИКИ ====================

func _on_arm_pressed(arm: String) -> void:
        _play_click_sound()
        if _arm == arm:
                return
        var arm_order := ["mutants", "artifacts", "super"]
        var dir: int = 1 if arm_order.find(arm) > arm_order.find(_arm) else -1   # СУПЕР правее АРТЕФАКТОВ
        _arm = arm
        _session_drops.clear()
        _refresh_all()
        _animate_strips(dir)


func _on_swipe_gui(event: InputEvent) -> void:
        # Тач на Android приходит как мышь (emulate_mouse_from_touch = true по умолчанию),
        # поэтому обрабатываем ТОЛЬКО mouse-семейство — иначе жест задвоится.
        if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
                _swipe_active = event.pressed
                _swipe_pos = event.position
        elif event is InputEventMouseMotion and _swipe_active:
                var dx: float = event.position.x - _swipe_pos.x
                if absf(dx) >= SWIPE_THRESHOLD:
                        _swipe_active = false   # один жест = одна смена
                        var arm_order := ["mutants", "artifacts", "super"]
                        var nxt: int = clampi(arm_order.find(_arm) + (1 if dx < 0.0 else -1), 0, 2)   # влево = вперёд
                        if nxt != arm_order.find(_arm):
                                _on_arm_pressed(arm_order[nxt])


func _animate_strips(dir: int) -> void:
        """Витрина проявляется и выезжает с направления свайпа (полировка смены рукава)."""
        var box := _strips_row1.get_parent() as Control
        if box == null or box.size.x < 100.0:
                return   # до первичной раскладки анимировать нечего
        if _arm_tween and _arm_tween.is_valid():
                _arm_tween.kill()   # спам-свайпы не должны драться за свойства
        # «Дом» витрины — захвачен при построении (см. _build_strips):
        # ни offsets, ни текущая position после сдвига доверять нельзя.
        var home := _strips_home
        box.position = home + Vector2(34.0 * float(dir), 0.0)
        box.modulate.a = 0.2
        _arm_tween = create_tween().set_parallel(true)
        _arm_tween.tween_property(box, "position", home, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        _arm_tween.tween_property(box, "modulate:a", 1.0, 0.20)


func _on_spin(times: int) -> void:
        _play_click_sound()
        if not _game_manager:
                return
        var results: Array = []
        var lab = _lab()
        var super_before: int = int(lab.super_pulls) if lab else 0
        var choice_before: int = int(lab.super_choice_tokens) if lab else 0
        if _arm == "super":
                results = _game_manager.spin_super_gacha(times)
        elif _arm == "mutants":
                results = _game_manager.spin_mutant_gacha(times)
        else:
                results = _game_manager.spin_artifact_gacha(times)
        if results.is_empty():
                _show_toast(Loc.t("gacha.super_no_pulls") if _arm == "super" else Loc.t("gacha.no_rolls"))
                return
        # Дропы разворачиваются новыми полосами (новые — первыми)
        for r in results:
                var kind: String = str(r.get("kind", "mut"))
                if _arm == "mutants":
                        kind = "mut"
                elif _arm == "artifacts":
                        kind = "art"
                var rar: String = str(r.get("rarity", "common"))
                if _arm == "super":
                        rar = "ex"   # фиолетовая рамка и тег «ЭКСКЛЮЗИВ» на полосе
                _session_drops.push_front({"arm": _arm, "kind": kind, "type": r.get("type"), "rarity": rar, "status": r.get("status", "")})
        while _session_drops.size() > 12:
                _session_drops.pop_back()

        # Прогрессия: задачи и опыт за призыв (супер-призыв — награда, без прогрессии)
        if _arm != "super":
                Prog.notify_gacha(times)

        _refresh_all()
        # Тост: заработанная супер-крутка важнее легендарки
        var lab2 = _lab()
        var super_earned: bool = lab2 != null and int(lab2.super_pulls) > super_before
        if super_earned:
                _show_toast("СУПЕР-КРУТКА +1 · ВКЛАДКА «СУПЕР»")
                return
        var choice_earned: bool = lab2 != null and int(lab2.super_choice_tokens) > choice_before
        if choice_earned:
                _show_toast("ВЫБОР ПРИЗА ГОТОВ · КНОПКА «ПРИЗ НА ВЫБОР»")
                return
        # Мигнуть тостом при легендарке
        var any_legend := false
        for r in results:
                if str(r.get("rarity")) == "legendary":
                        any_legend = true
                        break
        if any_legend:
                _show_toast(Loc.t("gacha.legend_toast"))


func _on_back_pressed() -> void:
        _play_click_sound()
        if _game_manager:
                _game_manager.change_scene("lab")
        else:
                get_tree().change_scene_to_file("res://scenes/lab/lab.tscn")



# ==================== ПРИЗ НА ВЫБОР ====================

func _build_choice_overlay() -> void:
        _choice_overlay = Control.new()
        _choice_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
        _choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
        _choice_overlay.visible = false
        add_child(_choice_overlay)

        var shade := ColorRect.new()
        shade.set_anchors_preset(Control.PRESET_FULL_RECT)
        shade.color = Color(0, 0, 0, 0.82)
        shade.gui_input.connect(func(ev):
                if ev is InputEventMouseButton and ev.pressed:
                        _choice_overlay.visible = false)
        _choice_overlay.add_child(shade)

        var panel := PanelContainer.new()
        panel.anchor_left = 0.5
        panel.anchor_top = 0.5
        panel.anchor_right = 0.5
        panel.anchor_bottom = 0.5
        panel.offset_left = -560
        panel.offset_top = -280
        panel.offset_right = 560
        panel.offset_bottom = 280
        _choice_overlay.add_child(panel)

        var v := VBoxContainer.new()
        v.add_theme_constant_override("separation", 10)
        panel.add_child(v)

        var top := HBoxContainer.new()
        _choice_title = BunkerUI.make_section_label("ПРИЗ НА ВЫБОР · эксклюзивы Чёрных ящиков")
        _choice_title.add_theme_font_size_override("font_size", 20)
        _choice_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        top.add_child(_choice_title)
        var cback := Button.new()
        cback.text = "НАЗАД"
        cback.custom_minimum_size = Vector2(140, 44)
        BunkerUI.style_button(cback, "steel", 15)
        cback.pressed.connect(func(): _choice_overlay.visible = false)
        top.add_child(cback)
        v.add_child(top)

        var note := BunkerUI.make_mono_label("каждые %d супер-призывов = 1 выбор · дубль мутанта = копия на ферму · дубль аномалии = +400 биомассы" % GachaData.SUPER_CHOICE_PITY, 13, Color("66794f"))
        v.add_child(note)

        var scroll := ScrollContainer.new()
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        v.add_child(scroll)

        _choice_box = GridContainer.new()
        _choice_box.columns = 3
        _choice_box.add_theme_constant_override("h_separation", 14)
        _choice_box.add_theme_constant_override("v_separation", 14)
        _choice_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll.add_child(_choice_box)


func _rebuild_choice_tiles() -> void:
        for c in _choice_box.get_children():
                c.queue_free()
        for ex in GachaData.EXCLUSIVE_MUTANTS:
                _choice_box.add_child(_make_choice_tile("mut", str(ex["type"]), str(ex.get("label", "")), str(ex.get("desc", ""))))
        for ax in GachaData.EXCLUSIVE_ANOMALIES:
                _choice_box.add_child(_make_choice_tile("art", str(ax["type"]), str(ax.get("label", "")), str(ax.get("desc", ""))))


func _make_choice_tile(kind: String, type: String, label: String, desc: String) -> Control:
        var lab = _lab()
        var owned: bool = false
        if lab:
                owned = lab.unlocked_mutants.has(type) if kind == "mut" else lab.exclusive_anomalies.has(type)
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(340, 118)
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color("0a100b")
        sb.set_border_width_all(2)
        sb.set_corner_radius_all(10)
        sb.border_color = Color("b48cff") if owned else Color("3a4433")
        btn.add_theme_stylebox_override("normal", sb)
        var sbh := sb.duplicate()
        sbh.border_color = BunkerUI.HAZARD
        btn.add_theme_stylebox_override("hover", sbh)
        var sbp := sb.duplicate()
        sbp.border_color = Color("ffd94d")
        btn.add_theme_stylebox_override("pressed", sbp)
        btn.add_theme_stylebox_override("focus", sb.duplicate())

        var icon := TextureRect.new()
        var path := GachaData.card_icon_path(type, kind == "mut", false)
        if ResourceLoader.exists(path):
                icon.texture = load(path)
        icon.anchor_left = 0.0
        icon.anchor_right = 0.0
        icon.anchor_top = 0.0
        icon.anchor_bottom = 1.0
        icon.offset_left = 10
        icon.offset_right = 110
        icon.offset_top = 10
        icon.offset_bottom = -10
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        btn.add_child(icon)

        var nm := Label.new()
        nm.text = label
        nm.add_theme_font_override("font", BunkerUI.font_title())
        nm.add_theme_font_size_override("font_size", 15)
        nm.add_theme_color_override("font_color", Color("b48cff") if owned else BunkerUI.TEXT_LIGHT)
        nm.anchor_left = 1.0
        nm.anchor_right = 1.0
        nm.offset_left = -222
        nm.offset_right = -12
        nm.offset_top = 12
        nm.offset_bottom = 48
        nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
        btn.add_child(nm)

        var ds := BunkerUI.make_mono_label(("В КОЛЛЕКЦИИ · дубль = " + ("копия" if kind == "mut" else "+400 био")) if owned else ("НОВЫЙ · " + desc), 11, Color("66794f"))
        ds.anchor_left = 1.0
        ds.anchor_right = 1.0
        ds.anchor_top = 1.0
        ds.anchor_bottom = 1.0
        ds.offset_left = -222
        ds.offset_right = -12
        ds.offset_top = -46
        ds.offset_bottom = -10
        ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        ds.mouse_filter = Control.MOUSE_FILTER_IGNORE
        btn.add_child(ds)

        btn.pressed.connect(_on_choice_pick.bind(kind, type))
        return btn


func _on_choice_open() -> void:
        _play_click_sound()
        var lab = _lab()
        if lab == null or int(lab.super_choice_tokens) <= 0:
                _show_toast("Выбор не готов: %d/%d супер-призывов" % [int(lab.super_choice_progress) if lab else 0, GachaData.SUPER_CHOICE_PITY])
                return
        _rebuild_choice_tiles()
        _choice_overlay.visible = true


func _on_choice_pick(kind: String, type: String) -> void:
        _play_click_sound()
        if not _game_manager:
                return
        var roll: Dictionary = _game_manager.claim_super_choice(kind, type)
        if roll.is_empty():
                _show_toast("Выбор недоступен")
                return
        _choice_overlay.visible = false
        _session_drops.push_front({"arm": "super", "kind": kind, "type": type, "rarity": "ex", "status": roll.get("status", "new")})
        while _session_drops.size() > 12:
                _session_drops.pop_back()
        _refresh_all()
        var nm: String = Loc.type_name(type)
        if str(roll.get("status", "new")) == "dup":
                _show_toast("ПРИЗ ВЫБРАН: %s · дубль — %s" % [nm, "копия на ферму" if kind == "mut" else "+400 биомассы"])
        else:
                _show_toast("ПРИЗ ВЫБРАН: %s · новый в коллекции!" % nm)

func _show_toast(text: String) -> void:
        _toast_label.text = text
        _toast.visible = true
        _toast.reset_size()
        await get_tree().create_timer(1.6).timeout
        if is_instance_valid(_toast):
                _toast.visible = false


func _play_hover_sound() -> void:
        var sm = get_tree().get_first_node_in_group("sound_manager")
        if sm and sm.has_method("play_sound"):
                sm.play_sound("ui_hover", 0.3)


func _play_click_sound() -> void:
        var sm = get_tree().get_first_node_in_group("sound_manager")
        if sm and sm.has_method("play_sound"):
                sm.play_sound("ui_click", 0.6)
