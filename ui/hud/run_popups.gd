extends CanvasLayer
class_name RunPopups

## Поп-апы забега (v0.28.0 «ПЕРЕДЫШКА С ПРИВКУСОМ»):
##  - show_event: событие Зоны, выбор 1 из 2 (эффект применяет zone_controller)
##  - show_shop: магазин торговца «Седого» за биомассу забега
## Слой живёт над HUD, на время выбора ставит паузу сцены: волны, таймеры
## и выброс замирают, кнопки поп-апа работают (PROCESS_MODE_ALWAYS).

signal modal_closed

const COL_GOLD := Color("ffd94d")
const COL_ORANGE := Color(1.0, 0.62, 0.2)
const COL_SAFE := Color(0.55, 0.9, 0.4)
const COL_RISK := Color(1.0, 0.55, 0.25)
const COL_TEXT := Color(0.92, 0.9, 0.8)
const COL_DIM := Color(0.72, 0.7, 0.58)
const COL_BG := Color(0.05, 0.045, 0.03, 0.97)

var _root: Control = null
var _center: CenterContainer = null
var _pause_set: bool = false
# Магазин
var _on_buy: Callable = Callable()
var _biomass_getter: Callable = Callable()
var _items_getter: Callable = Callable()
var _biomass_label: Label = null
var _biomass_last: float = -1.0
var _shop_note_label: Label = null
var _shop_note_seq: int = 0
var _shop_grid: GridContainer = null
var _shop_buttons: Dictionary = {}


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_modal_open() -> bool:
	return is_instance_valid(_root)


# ==================== СОБЫТИЕ ЗОНЫ (ВЫБОР 1 ИЗ 2) ====================

func show_event(ev: Dictionary, on_choose: Callable) -> void:
	if is_modal_open():
		return
	_open_root()
	var ru: bool = Loc.lang == "ru"
	var panel := _make_panel(Vector2(920, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.add_child(_make_label(Loc.t("run_ev.title"), 40, COL_ORANGE, true))
	v.add_child(_make_label(str(ev.get("title_ru" if ru else "title_en", "")), 52, COL_GOLD, true))
	v.add_child(_make_label(str(ev.get("desc_ru" if ru else "desc_en", "")), 24, COL_TEXT))
	v.add_child(_make_label(Loc.t("run_ev.choose"), 19, COL_DIM))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var opts: Array = ev.get("options", [])
	for i in range(opts.size()):
		h.add_child(_build_event_option(opts[i], i, on_choose))
	v.add_child(h)
	panel.add_child(v)
	_show_panel(panel)


func _build_event_option(opt: Dictionary, index: int, on_choose: Callable) -> PanelContainer:
	var ru: bool = Loc.lang == "ru"
	var safe: bool = RunEventsData.tone_of(opt) != "risk"
	var accent: Color = COL_SAFE if safe else COL_RISK
	var pc := PanelContainer.new()
	var sb := _box_style(accent, Color(0.06, 0.055, 0.035, 0.98))
	sb.set_border_width_all(3)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	pc.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.custom_minimum_size = Vector2(400, 0)
	v.add_child(_make_label(Loc.t("run_ev.safe") if safe else Loc.t("run_ev.risk"), 17, accent, true))
	v.add_child(_make_label(str(opt.get("label_ru" if ru else "label_en", "")), 34, Color.WHITE, true))
	v.add_child(_make_label(str(opt.get("desc_ru" if ru else "desc_en", "")), 20, COL_TEXT))
	var btn := Button.new()
	btn.text = Loc.t("run_ev.pick")
	_style_button(btn, accent, 22)
	btn.custom_minimum_size = Vector2(0, 62)
	btn.pressed.connect(func():
		btn.disabled = true
		var res: String = str(on_choose.call(index))
		_flash_and_close(res))
	v.add_child(btn)
	pc.add_child(v)
	return pc


# ==================== МАГАЗИН ТОРГОВЦА ====================

func show_shop(items: Array, on_buy: Callable, biomass_getter: Callable, items_getter: Callable) -> void:
	if is_modal_open():
		return
	_on_buy = on_buy
	_biomass_getter = biomass_getter
	_items_getter = items_getter
	_open_root()
	var panel := _make_panel(Vector2(1024, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.add_child(_make_label(Loc.t("trader.title"), 44, COL_GOLD, true))
	v.add_child(_make_label(Loc.t("trader.note"), 18, COL_DIM))
	_biomass_label = _make_label("", 23, COL_SAFE, true)
	_biomass_label.add_theme_color_override("font_color", COL_SAFE)
	_biomass_last = -1.0
	v.add_child(_biomass_label)
	_shop_note_label = _make_label("", 19, COL_RISK, true)
	_shop_note_label.visible = false
	v.add_child(_shop_note_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 14)
	_shop_grid = grid
	scroll.add_child(grid)
	# Свайп-слой (v0.29.2): тянешь - едет, флик - инерция, тап - КУПИТЬ под пальцем
	v.add_child(SwipeHelper.attach(scroll, false))
	var close_btn := Button.new()
	close_btn.text = Loc.t("trader.close")
	_style_button(close_btn, COL_GOLD, 19)
	close_btn.custom_minimum_size = Vector2(220, 54)
	close_btn.pressed.connect(_close_root)
	var ch := HBoxContainer.new()
	ch.alignment = BoxContainer.ALIGNMENT_END
	ch.add_child(close_btn)
	v.add_child(ch)
	panel.add_child(v)
	_fill_shop(items)
	_update_biomass_label()
	_show_panel(panel)


func _fill_shop(items: Array) -> void:
	for c in _shop_grid.get_children():
		_shop_grid.remove_child(c)
		c.queue_free()
	_shop_buttons.clear()
	var ru: bool = Loc.lang == "ru"
	for item in items:
		var id: String = str(item.get("id", ""))
		var cost: int = int(item.get("cost", 0))
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", _box_style(Color(0.5, 0.46, 0.3), Color(0.07, 0.065, 0.045, 0.98)))
		var iv := VBoxContainer.new()
		iv.add_theme_constant_override("separation", 5)
		iv.custom_minimum_size = Vector2(462, 0)
		var nm: String = str(item.get("name", ""))
		if nm.is_empty():
			nm = str(item.get("name_ru", "") if ru else item.get("name_en", ""))
		var name_l := _make_label(nm, 25, COL_GOLD, true)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		iv.add_child(name_l)
		var cost_l := _make_label("%d" % cost, 21, COL_SAFE, true)
		cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		iv.add_child(cost_l)
		var ds: String = str(item.get("desc", ""))
		if ds.is_empty():
			ds = str(item.get("desc_ru", "") if ru else item.get("desc_en", ""))
		var desc_l := _make_label(ds, 17, COL_TEXT)
		desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		desc_l.custom_minimum_size = Vector2(0, 62)
		iv.add_child(desc_l)
		var btn := Button.new()
		_style_button(btn, COL_SAFE, 17)
		btn.custom_minimum_size = Vector2(0, 52)
		if bool(item.get("sold", false)):
			_mark_sold(btn)
		else:
			btn.text = "%s  %d" % [Loc.t("trader.buy"), cost]
			btn.pressed.connect(func():
				var res: String = str(_on_buy.call(id))
				if res.is_empty():
					_shop_note(Loc.t("trader.no_money"), Color(1.0, 0.42, 0.3))
				else:
					_shop_note(res, COL_SAFE)
					_refresh_shop())
		_shop_buttons[id] = btn
		iv.add_child(btn)
		pc.add_child(iv)
		_shop_grid.add_child(pc)


## Перечитать товар и биомассу после покупки (состояние ведёт zone_controller)
func _refresh_shop() -> void:
	_update_biomass_label()
	if not _items_getter.is_valid():
		return
	var items: Array = _items_getter.call()
	for item in items:
		var id: String = str(item.get("id", ""))
		var btn: Button = _shop_buttons.get(id, null)
		if btn == null or not is_instance_valid(btn):
			continue
		if bool(item.get("sold", false)) and not btn.disabled:
			_mark_sold(btn)
		elif not bool(item.get("sold", false)) and btn.disabled:
			btn.disabled = false
			btn.text = "%s  %d" % [Loc.t("trader.buy"), int(item.get("cost", 0))]


func _mark_sold(btn: Button) -> void:
	btn.disabled = true
	btn.text = Loc.t("trader.sold")


func _update_biomass_label() -> void:
	if _biomass_label == null or not is_instance_valid(_biomass_label):
		return
	var value: float = float(_biomass_getter.call()) if _biomass_getter.is_valid() else 0.0
	_biomass_label.text = Loc.t("trader.biomass", {"n": int(value)})
	# Списание видно глазом: цифра вздрагивает красным при трате, зелёным - к пополнению
	if _biomass_last >= 0.0 and not is_equal_approx(value, _biomass_last):
		var col: Color = Color(1.0, 0.42, 0.3) if value < _biomass_last else COL_SAFE
		_biomass_label.add_theme_color_override("font_color", col)
		var tw := create_tween()
		tw.tween_interval(0.6)
		tw.tween_callback(func():
			if is_instance_valid(_biomass_label):
				_biomass_label.add_theme_color_override("font_color", COL_SAFE))
	_biomass_last = value


func _shop_note(text: String, col: Color) -> void:
	if _shop_note_label == null or not is_instance_valid(_shop_note_label):
		return
	_shop_note_label.text = text
	_shop_note_label.add_theme_color_override("font_color", col)
	_shop_note_label.visible = true
	_shop_note_seq += 1
	var seq := _shop_note_seq
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(func():
		if seq == _shop_note_seq and is_instance_valid(_shop_note_label):
			_shop_note_label.visible = false)


# ==================== КАРКАС ПОП-АПА ====================

func _open_root() -> void:
	if is_instance_valid(_root):
		return
	_root = Control.new()
	_root.name = "RunPopupRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_center)
	add_child(_root)
	# Пауза сцены на время выбора: волны/таймеры/выброс замирают
	if not get_tree().paused:
		get_tree().paused = true
		_pause_set = true


func _close_root() -> void:
	if not is_instance_valid(_root):
		return
	var root := _root
	_root = null
	_center = null
	_shop_grid = null
	_shop_buttons.clear()
	if _pause_set:
		_pause_set = false
		get_tree().paused = false
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func():
		if is_instance_valid(root):
			root.queue_free()
		modal_closed.emit())


func _show_panel(panel: PanelContainer) -> void:
	_center.add_child(panel)
	panel.reset_size()
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = panel.size / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Итог выбора: вспышка-итог на месте панели, затем закрытие и снятие паузы
func _flash_and_close(text: String) -> void:
	if not is_instance_valid(_root):
		return
	var ok: bool = not text.is_empty()
	var panel := _make_panel(Vector2(620, 0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(_make_label(Loc.t("run_ev.outcome"), 21, COL_DIM))
	v.add_child(_make_label(text if ok else Loc.t("trader.no_money"), 30, COL_SAFE if ok else Color(1.0, 0.42, 0.3), true))
	panel.add_child(v)
	for c in _center.get_children():
		c.visible = false
	_center.add_child(panel)
	panel.reset_size()
	panel.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.2)
	tw.tween_callback(_close_root)


# ==================== СТИЛЬ (БУНКЕР) ====================

func _make_panel(min_size: Vector2) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := _box_style(COL_GOLD, COL_BG)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 24
	sb.content_margin_left = 30.0
	sb.content_margin_right = 30.0
	sb.content_margin_top = 20.0
	sb.content_margin_bottom = 20.0
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = min_size
	return pc


func _box_style(border: Color, bg: Color = Color(0.09, 0.085, 0.06, 1.0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


func _style_button(btn: Button, accent: Color, fs: int = 20) -> void:
	btn.add_theme_font_override("font", BunkerUI.font_title())
	btn.add_theme_font_size_override("font_size", fs)
	btn.add_theme_color_override("font_color", COL_GOLD)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.53, 0.45))
	btn.add_theme_stylebox_override("normal", _box_style(accent))
	var hv := _box_style(accent, Color(0.16, 0.14, 0.07, 1.0))
	btn.add_theme_stylebox_override("hover", hv)
	btn.add_theme_stylebox_override("pressed", hv)
	btn.add_theme_stylebox_override("disabled", _box_style(Color(0.35, 0.33, 0.25), Color(0.06, 0.055, 0.04, 1.0)))
	btn.focus_mode = Control.FOCUS_NONE


func _make_label(text: String, fs: int, color: Color, title := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", BunkerUI.font_title() if title else BunkerUI.font_body())
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
