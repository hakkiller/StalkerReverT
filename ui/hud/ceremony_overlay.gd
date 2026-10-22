# ui/hud/ceremony_overlay.gd
extends CanvasLayer
class_name CeremonyOverlay

## Церемония «ЭТАЖ ПРОЙДЕН» для Башни Монолита: баннер -> звёзды -> конфетти
## -> 3D-переход (лестница/портал с кат-камерой) -> титр -> лаборатория.
## Строится кодом (правило проекта: UI - кодом, без .tscn). Арт и 3D-модели
## опциональны: нет файла - текстовая/цветная заглушка, церемония не может
## сломать выход из забега. Всё скипается одним кликом/тапом/Enter.
## Спека: design_inbox/tower_ceremony/tower_ceremony.md. Константы: CeremonyData.

signal finished

var _skipped: bool = false
var _time_scale: float = 1.0
var _party_level: int = 1
var _tweens: Array[Tween] = []
var _particles_budget: int = CeremonyData.CONFETTI_MAX_TOTAL
var _portal: Node3D = null
var _cut_cam: Camera3D = null
var _game_cam: Camera3D = null

# Узлы UI (собираются в _ready)
var _root: Control
var _dim: ColorRect
var _fade: ColorRect
var _banner: Control
var _banner_panel: Panel
var _banner_texture: TextureRect
var _banner_title: Label
var _banner_sub: Label
var _banner_base_y: float = 0.0
var _stars_row: HBoxContainer
var _star_slots: Array[Control] = []
var _rewards_label: Label
var _record_label: Label
var _title_label: Label
var _skip_hint: Label
var _confetti_host: Control
var _star_size: float = 128.0


func _ready():
	layer = CeremonyData.CANVAS_LAYER
	set_process(false)
	_build_ui()


# ==================== СБОРКА UI ====================

func _build_ui():
	var vp := get_viewport().get_visible_rect().size
	_star_size = clampf(vp.y * 0.1, 96.0, 160.0)

	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_dim = _make_rect(Color(0, 0, 0, 0))
	_root.add_child(_dim)

	# Баннер: полоса сверху
	_banner = Control.new()
	_banner.name = "Banner"
	_banner.position = Vector2(vp.x * 0.04, vp.y * 0.06)
	_banner.size = Vector2(vp.x * 0.92, vp.y * 0.19)
	_banner_base_y = _banner.position.y
	_banner.visible = false
	_root.add_child(_banner)

	_banner_panel = Panel.new()
	_banner_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.add_child(_banner_panel)

	_banner_texture = TextureRect.new()
	_banner_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_banner_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner.add_child(_banner_texture)

	_banner_title = Label.new()
	_banner_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_title.add_theme_font_size_override("font_size", clampi(vp.y * 0.055, 40, 68))
	_banner_title.add_theme_color_override("font_color", Color(0.93, 0.9, 0.78))
	_banner.add_child(_banner_title)

	_banner_sub = Label.new()
	_banner_sub.anchor_left = 0.0
	_banner_sub.anchor_right = 1.0
	_banner_sub.anchor_top = 0.62
	_banner_sub.anchor_bottom = 0.62
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.add_theme_font_size_override("font_size", clampi(vp.y * 0.026, 18, 28))
	_banner_sub.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	_banner.add_child(_banner_sub)

	# Ряд звёзд под баннером (слоты показываются пустыми, звёзды «выстреливают»)
	_stars_row = HBoxContainer.new()
	_stars_row.name = "StarsRow"
	_stars_row.add_theme_constant_override("separation", int(vp.x * 0.02))
	_stars_row.visible = false
	_root.add_child(_stars_row)
	var slot_w := _star_size + vp.x * 0.02
	_stars_row.size = Vector2(slot_w * 3.0 - vp.x * 0.02, _star_size)
	_stars_row.position = Vector2(vp.x * 0.5 - _stars_row.size.x * 0.5,
		_banner.position.y + _banner.size.y + vp.y * 0.03)
	for i in 3:
		var slot := _make_star_slot()
		_stars_row.add_child(slot)
		_star_slots.append(slot)

	# Строка наград и пометка рекорда
	_rewards_label = Label.new()
	_rewards_label.position = Vector2(0.0, _stars_row.position.y + _star_size + vp.y * 0.02)
	_rewards_label.size = Vector2(vp.x, vp.y * 0.04)
	_rewards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rewards_label.add_theme_font_size_override("font_size", clampi(vp.y * 0.028, 20, 30))
	_rewards_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.6))
	_rewards_label.modulate = Color(1, 1, 1, 0)
	_root.add_child(_rewards_label)

	_record_label = Label.new()
	_record_label.position = Vector2(0.0, _rewards_label.position.y + vp.y * 0.045)
	_record_label.size = Vector2(vp.x, vp.y * 0.03)
	_record_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_record_label.add_theme_font_size_override("font_size", clampi(vp.y * 0.022, 16, 24))
	_record_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.55))
	_record_label.modulate = Color(1, 1, 1, 0)
	_root.add_child(_record_label)

	# Конфетти (2D-частицы)
	_confetti_host = Control.new()
	_confetti_host.name = "ConfettiHost"
	_confetti_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confetti_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_confetti_host)

	# Затемнение в чёрный + титр на нём
	_fade = _make_rect(Color(0, 0, 0, 0))
	_root.add_child(_fade)

	_title_label = Label.new()
	_title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", clampi(vp.y * 0.08, 52, 96))
	_title_label.add_theme_color_override("font_color", Color(0.93, 0.9, 0.78))
	_title_label.visible = false
	_root.add_child(_title_label)

	# Подсказка скипа (появляется не сразу, чтобы первый просмотр не дразнить)
	_skip_hint = Label.new()
	_skip_hint.anchor_left = 0.0
	_skip_hint.anchor_right = 1.0
	_skip_hint.anchor_top = 1.0
	_skip_hint.anchor_bottom = 1.0
	_skip_hint.offset_top = -vp.y * 0.055
	_skip_hint.offset_bottom = -vp.y * 0.015
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skip_hint.add_theme_font_size_override("font_size", clampi(vp.y * 0.02, 14, 22))
	_skip_hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.75))
	_skip_hint.text = Loc.t("tower_ceremony.skip_hint")
	_skip_hint.modulate = Color(1, 1, 1, 0)
	_root.add_child(_skip_hint)


func _make_rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _make_star_slot() -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(_star_size, _star_size)
	slot.size = Vector2(_star_size, _star_size)
	slot.pivot_offset = Vector2(_star_size, _star_size) * 0.5
	var star_tex: Texture2D = _art("star_empty")
	if star_tex:
		var tex_rect := TextureRect.new()
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.add_child(tex_rect)
	else:
		var glyph := Label.new()
		glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.add_theme_font_size_override("font_size", int(_star_size * 0.8))
		slot.add_child(glyph)
	return slot


func _art(key: String) -> Texture2D:
	if not CeremonyData.ART.has(key):
		return null
	var path := CeremonyData.ART_DIR + String(CeremonyData.ART[key])
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


# ==================== ЗАПУСК ====================

## Играет церемонию по результату забега Башни и возвращается по концу/скипу.
## Вызов awaits из zone_controller.finish_run.
func play(result: Dictionary) -> void:
	if str(result.get("mode", "")) != "tower":
		return

	var success: bool = bool(result.get("success", false))
	var summary: Dictionary = result.get("tower_summary", {})
	var floor_num: int = int(summary.get("floor", int(result.get("tower_floor", 1))))
	var stars: int = int(summary.get("stars", 1 if success else 0))
	var stars_before: int = int(summary.get("stars_before", 0))

	_begin()

	if success:
		await _play_victory(summary, floor_num, maxi(stars, 1), stars_before)
	else:
		await _play_defeat(summary)

	# Скип - короткое затемнение и выход; естественный конец уже в чёрном
	if _skipped:
		_fade.color.a = 0.0
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, CeremonyData.SKIP_FADE_TIME)
		await _wait_raw(CeremonyData.SKIP_FADE_TIME)
	finished.emit()


## Подготовка: курсор, музыка, HUD, отключение боевой камеры
func _begin():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("stop_music"):
		sm.stop_music(1.2)

	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.visible = false

	_game_cam = get_viewport().get_camera_3d()
	if _game_cam:
		_game_cam.set_process(false)
		_game_cam.set_physics_process(false)
		_game_cam.set_process_input(false)
		_game_cam.set_process_unhandled_input(false)

	set_process(true)
	var tw := _tween()
	tw.tween_property(_skip_hint, "modulate:a", 0.5, 0.4) \
		.set_delay(CeremonyData.SKIP_HINT_DELAY)


# ==================== ВАРИАНТ: ПОБЕДА ====================

func _play_victory(summary: Dictionary, floor_num: int, stars: int, stars_before: int) -> void:
	var floor_type := TowerData.get_floor_type(floor_num)
	var is_final := floor_num >= TowerData.TOTAL_FLOORS
	var record_improved := stars > stars_before
	var replay := (not record_improved) and stars_before >= 1

	# Уровень праздника: звёзды; улучшение рекорда и Прорыв - минимум «2 звезды»
	_party_level = stars
	if record_improved or floor_type == "break":
		_party_level = maxi(_party_level, 2)

	# Темп: Прорыв и реплей пройденного - бодрее
	_time_scale = CeremonyData.BREAK_TIME_SCALE if (floor_type == "break" or replay) else 1.0

	# 1. Затемнение сцены
	_fade_to(CeremonyData.DIM_ALPHA, CeremonyData.FADE_IN_TIME)
	await _wait(CeremonyData.FADE_IN_TIME)
	var t := CeremonyData.FADE_IN_TIME
	if _dead():
		return

	# 2. Пре-ролл Хранителя: баннер босса, двойной слэм с тряской, рык
	if floor_type == "keeper":
		await _keeper_preroll(floor_num)
		if _dead():
			return
		t += CeremonyData.KEEPER_PREROLL

	# 3. Баннер «ЭТАЖ ПРОЙДЕН» (вариант: Прорыв / Башня покорена)
	var kind := "cleared"
	var sub := ""
	if is_final:
		kind = "victory"
	elif floor_type == "break":
		kind = "break"
		sub = Loc.t("tower_ceremony.break_tag")
	_set_banner(kind, Loc.t("tower_ceremony.cleared"), sub)
	_slam_banner("banner_slam_break" if kind == "break" else "banner_slam")
	await _wait(CeremonyData.BANNER_IN_TIME)
	t += CeremonyData.BANNER_IN_TIME
	if _dead():
		return

	# 4. Слоты звёзд проявляются пустыми
	var kinds := _star_kinds(stars, stars_before)
	var shown: int = mini(stars + maxi(0, mini(stars_before, 3) - stars), 3)
	var shift: float = maxf(0.0, shown - 1) * CeremonyData.STAR_POP_INTERVAL

	await _wait(maxf(0.05, CeremonyData.T_STARS_BASE - t))
	_show_star_slots()
	await _wait(CeremonyData.STAR_SLOT_FADE)
	if _dead():
		return

	# 5. Поп-звёзды по очереди: gold - панч и лесенка звука, silver - тихо
	var gold_i := 0
	for i in shown:
		var slot: Control = _star_slots[i]
		if String(kinds[i]) == "gold":
			_pop_star(slot, gold_i)
			gold_i += 1
		else:
			_reveal_silver(slot)
		if i < shown - 1:
			await _wait(CeremonyData.STAR_POP_INTERVAL)
		if _dead():
			return
	t = maxf(t, CeremonyData.T_STARS_BASE) + CeremonyData.STAR_SLOT_FADE \
		+ maxf(0.0, shown - 1) * CeremonyData.STAR_POP_INTERVAL

	# Конфетти и искры - по уровню праздника (1★ без улучшения рекорда - сдержанно)
	if _party_level >= 2:
		_confetti(CeremonyData.CONFETTI_WAVE_3STARS if _party_level >= 3
			else CeremonyData.CONFETTI_WAVE_2STARS, "wave")
		if _party_level >= 3:
			_confetti(CeremonyData.CONFETTI_SIDE_BURST, "side")
		_sfx("confetti_burst")

	# 6. Строка наград (+ пометка рекорда, если реплей хуже)
	await _wait(maxf(0.05, CeremonyData.T_REWARDS_LINE + shift - t))
	_show_rewards(summary)
	t = maxf(t, CeremonyData.T_REWARDS_LINE + shift)
	if _dead():
		return

	# 7. Переход: лестница (обычный/Прорыв) или портал (Хранитель, финал)
	var use_portal := is_final or floor_type == "keeper"
	if _party_level >= 3:
		shift += CeremonyData.CONFETTI_EXTRA_HOLD
	await _wait(maxf(0.05, CeremonyData.T_TRANSITION + shift - t))
	if _dead():
		return
	await _transition("portal" if use_portal else "stairs", floor_num, stars)
	if _dead():
		return

	# 8. Затемнение в чёрный и титр
	var hold := CeremonyData.TITLE_HOLD_MAX if _party_level >= 3 else CeremonyData.TITLE_HOLD
	if is_final:
		await _show_title(Loc.t("tower_ceremony.tower_done") + "\n"
			+ Loc.t("tower_ceremony.tower_done_list"), CeremonyData.TITLE_LIST_HOLD)
	elif floor_type == "keeper":
		var next_tier: Dictionary = TowerData.get_tier(floor_num + 1)
		await _show_title(Loc.t("tower_ceremony.tier_up",
			{"name": String(next_tier.get("name", ""))}), hold)
	else:
		await _show_title(Loc.t("tower_ceremony.next_floor",
			{"n": floor_num + 1}), hold)


## Пре-ролл Хранителя: баннер босса, двойной слэм с тряской, рык
func _keeper_preroll(floor_num: int) -> void:
	var tier: Dictionary = TowerData.get_tier(floor_num)
	_set_banner("keeper", Loc.t("tower_ceremony.keeper_down",
		{"name": String(tier.get("boss", ""))}), "")
	_banner.position.y = _banner_base_y
	_banner.scale = Vector2(CeremonyData.BANNER_SLAM_SCALE, CeremonyData.BANNER_SLAM_SCALE)
	_sfx("keeper_roar")
	_sfx("keeper_slam")
	var tw := _tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.25)
	await _wait(0.25)
	_shake_banner(CeremonyData.KEEPER_SLAM_SHAKE)
	await _wait(CeremonyData.KEEPER_PREROLL - 0.45)
	if _dead():
		return
	# второй слэм перед уходом пре-ролла
	_sfx("keeper_slam")
	_banner.scale = Vector2(CeremonyData.BANNER_SLAM_SCALE, CeremonyData.BANNER_SLAM_SCALE)
	var tw2 := _tween()
	tw2.tween_property(_banner, "scale", Vector2.ONE, 0.15)
	await _wait(0.2)
	_hide_banner()


# ==================== ВАРИАНТ: ПОРАЖЕНИЕ ====================

func _play_defeat(summary: Dictionary) -> void:
	_party_level = 0
	_time_scale = 1.0

	_fade_to(CeremonyData.DIM_ALPHA_DEFEAT, CeremonyData.FADE_IN_TIME)
	await _wait(CeremonyData.FADE_IN_TIME)
	if _dead():
		return

	_set_banner("defeat", Loc.t("result.defeat"),
		Loc.t("tower_ceremony.consolation", {"b": int(summary.get("biomass", 0))}))
	_slam_banner("defeat")
	await _wait(maxf(0.1, CeremonyData.DEFEAT_TOTAL - CeremonyData.FADE_IN_TIME
		- CeremonyData.BANNER_IN_TIME))
	if _dead():
		return

	_fade.color.a = 0.0
	_fade_to(1.0, CeremonyData.FADE_OUT_TIME)
	await _wait(CeremonyData.FADE_OUT_TIME)


# ==================== ЗВЁЗДЫ ====================

## Порядок слотов: gold (заработано), silver (рекорд сверх заработанного), empty
func _star_kinds(stars: int, stars_before: int) -> Array:
	var kinds: Array = []
	for i in mini(stars, 3):
		kinds.append("gold")
	var silver_n: int = maxi(0, mini(stars_before, 3) - stars)
	for i in silver_n:
		kinds.append("silver")
	while kinds.size() < 3:
		kinds.append("empty")
	return kinds


## Слоты появляются пустыми (star_empty), звёзды «выстреливают» позже
func _show_star_slots() -> void:
	if _skipped:
		return
	_stars_row.visible = true
	for slot: Control in _star_slots:
		_style_star_slot(slot, "empty")
		slot.modulate = Color(1, 1, 1, 0)
		var tw := _tween()
		tw.tween_property(slot, "modulate:a", 0.45, CeremonyData.STAR_SLOT_FADE)


func _style_star_slot(slot: Control, kind: String) -> void:
	var colors := {
		"gold": Color(0.93, 0.78, 0.3),
		"silver": Color(0.72, 0.76, 0.82),
		"empty": Color(0.28, 0.3, 0.32),
	}
	var color: Color = colors.get(kind, colors["empty"])
	for child in slot.get_children():
		if child is TextureRect:
			var tex: Texture2D = _art("star_" + kind)
			if tex == null:
				tex = _art("star_empty")
			if tex:
				(child as TextureRect).texture = tex
		elif child is Label:
			(child as Label).text = "★"
			(child as Label).add_theme_color_override("font_color", color)


func _pop_star(slot: Control, gold_index: int) -> void:
	if _skipped:
		return
	_style_star_slot(slot, "gold")
	slot.modulate = Color(1, 1, 1, 1)
	slot.scale = Vector2.ZERO
	var pitch := 1.0 + CeremonyData.STAR_PITCH_STEP * gold_index
	_sfx("star_pop", pitch)
	if gold_index >= 2:
		_sfx("star_third")
	var tw := _tween()
	tw.tween_property(slot, "scale", Vector2(1.2, 1.2),
		CeremonyData.STAR_POP_TIME * 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(slot, "scale", Vector2.ONE, CeremonyData.STAR_POP_TIME * 0.4)
	if _party_level >= 2:
		_spark_star(slot)
	if gold_index >= 2 and _party_level >= 3:
		_shake_banner(CeremonyData.KEEPER_SLAM_SHAKE * 0.6)


func _reveal_silver(slot: Control) -> void:
	if _skipped:
		return
	_style_star_slot(slot, "silver")
	slot.modulate = Color(1, 1, 1, 0)
	_sfx("star_silver")
	var tw := _tween()
	tw.tween_property(slot, "modulate:a", 1.0, 0.2)


func _show_rewards(summary: Dictionary) -> void:
	if _skipped:
		return
	_rewards_label.text = Loc.t("tower_ceremony.rewards_line", {
		"b": int(summary.get("biomass", 0)),
		"m": int(summary.get("mutant_rolls", 0)),
		"a": int(summary.get("anomaly_rolls", 0)),
	})
	var tw := _tween()
	tw.tween_property(_rewards_label, "modulate:a", 1.0, 0.3)
	var stars: int = int(summary.get("stars", 0))
	var stars_before: int = int(summary.get("stars_before", 0))
	if stars < stars_before:
		_record_label.text = Loc.t("tower_ceremony.record_note", {"n": stars_before})
		var tw2 := _tween()
		tw2.tween_property(_record_label, "modulate:a", 1.0, 0.3).set_delay(0.2)


# ==================== БАННЕР ====================

func _accent_for(kind: String) -> Color:
	var accents := {
		"cleared": Color(0.45, 0.5, 0.3),
		"break": Color(0.8, 0.5, 0.15),
		"keeper": Color(0.62, 0.16, 0.12),
		"victory": Color(0.85, 0.7, 0.25),
		"floor_up": Color(0.45, 0.5, 0.35),
		"defeat": Color(0.4, 0.22, 0.22),
	}
	return accents.get(kind, Color(0.45, 0.5, 0.3))


func _banner_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.06, 0.88)
	style.border_color = accent
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	return style


func _set_banner(kind: String, title_text: String, sub_text: String) -> void:
	if _skipped:
		return
	var art: Texture2D = _art("banner_" + kind)
	if art:
		_banner_texture.texture = art
		_banner_texture.visible = true
		_banner_panel.visible = false
	else:
		_banner_texture.visible = false
		_banner_panel.visible = true
		_banner_panel.add_theme_stylebox_override("panel", _banner_style(_accent_for(kind)))
	_banner.modulate = Color(1, 1, 1, 1)
	_banner_title.text = title_text
	_banner_sub.text = sub_text
	_banner_sub.visible = sub_text != ""
	_banner.visible = true


## Влёт сверху + панч масштаба (слэм)
func _slam_banner(sfx_slot: String) -> void:
	if _skipped:
		return
	_banner.position.y = -_banner.size.y - 60.0
	_banner.scale = Vector2(CeremonyData.BANNER_SLAM_SCALE, CeremonyData.BANNER_SLAM_SCALE)
	_sfx(sfx_slot)
	var tw := _tween()
	tw.tween_property(_banner, "position:y", _banner_base_y,
		_scaled(CeremonyData.BANNER_IN_TIME)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var tw2 := _tween()
	tw2.tween_property(_banner, "scale", Vector2.ONE,
		_scaled(CeremonyData.BANNER_IN_TIME)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Быстрый свап содержимого (баннер «ПОДЪЁМ» на переходе)
func _swap_banner(kind: String, title_text: String) -> void:
	if _skipped:
		return
	var tw := _tween()
	tw.tween_property(_banner, "modulate:a", 0.0, 0.15)
	_set_banner(kind, title_text, "")
	var tw2 := _tween()
	tw2.tween_property(_banner, "modulate:a", 1.0, 0.15).set_delay(0.15)


func _hide_banner() -> void:
	var tw := _tween()
	tw.tween_property(_banner, "modulate:a", 0.0, 0.2)


func _shake_banner(px: float) -> void:
	var base_x := _banner.position.x
	var tw := _tween()
	tw.set_loops(3)
	tw.tween_property(_banner, "position:x", base_x + px, 0.05)
	tw.tween_property(_banner, "position:x", base_x - px, 0.05)
	tw.chain().tween_property(_banner, "position:x", base_x, 0.05)


# ==================== КОНФЕТТИ И ИСКРЫ ====================

func _confetti(amounts: Array[int], mode: String) -> void:
	if _skipped or _particles_budget <= 0:
		return
	var vp := get_viewport().get_visible_rect().size
	var dir := Vector2(0, 1)
	var spread := 32.0
	var origins: Array[Vector2] = []
	match mode:
		"wave":
			origins = [Vector2(vp.x * (1.0 - CeremonyData.CONFETTI_EMISSION_WIDTH) * 0.5, -20.0)]
		"side":
			spread = 25.0
			origins = [_banner.position + Vector2(20.0, _banner.size.y),
				Vector2(vp.x - 20.0, _banner.position.y + _banner.size.y)]
		"fountain":
			dir = Vector2(0, -1)
			spread = 40.0
			origins = [Vector2(vp.x * 0.5, vp.y * 0.75)]

	for origin in origins:
		var side_flip := 1.0 if (mode != "side" or origin.x < vp.x * 0.5) else -1.0
		for i in mini(amounts.size(), 3):
			var amount: int = amounts[i]
			if _particles_budget <= 0:
				return
			amount = mini(amount, _particles_budget)
			var tex: Texture2D = _art("confetti_0" + str(i + 1))
			if tex == null:
				continue
			_particles_budget -= amount
			var node := _confetti_node(tex, amount, origin,
				Vector2(dir.x * side_flip, dir.y), spread)
			_confetti_host.add_child(node)
			node.emitting = true


func _confetti_node(tex: Texture2D, amount: int, origin: Vector2, dir: Vector2, spread: float) -> GPUParticles2D:
	var node := GPUParticles2D.new()
	node.texture = tex
	node.position = origin
	node.amount = amount
	node.lifetime = CeremonyData.CONFETTI_LIFETIME
	node.one_shot = true
	node.explosiveness = 1.0

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(dir.x, dir.y, 0.0)
	pm.spread = spread
	pm.gravity = Vector3(0, CeremonyData.CONFETTI_GRAVITY, 0)
	pm.initial_velocity_min = CeremonyData.CONFETTI_VELOCITY_MIN
	pm.initial_velocity_max = CeremonyData.CONFETTI_VELOCITY_MAX
	pm.scale_min = 0.5
	pm.scale_max = 0.9
	pm.angular_velocity_min = -360.0
	pm.angular_velocity_max = 360.0
	pm.lifetime_randomness = 0.15
	node.process_material = pm
	# Самоочистка после одноразового залпа
	node.finished.connect(node.queue_free)
	return node


## Твинклы искр за gold-звездой
func _spark_star(slot: Control) -> void:
	var tex: Texture2D = _art("spark_star")
	if tex == null or _particles_budget < CeremonyData.SPARKS_PER_STAR:
		return
	_particles_budget -= CeremonyData.SPARKS_PER_STAR
	var node := GPUParticles2D.new()
	node.texture = tex
	node.position = slot.global_position + Vector2(_star_size * 0.5, _star_size * 0.5)
	node.amount = CeremonyData.SPARKS_PER_STAR
	node.lifetime = 0.6
	node.one_shot = true
	node.explosiveness = 1.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 180.0
	pm.gravity = Vector3(0, 220.0, 0)
	pm.initial_velocity_min = 70.0
	pm.initial_velocity_max = 150.0
	pm.scale_min = 0.4
	pm.scale_max = 0.9
	node.process_material = pm
	node.finished.connect(node.queue_free)
	_confetti_host.add_child(node)
	node.emitting = true


# ==================== ПЕРЕХОД 3D / 2D ====================

## Лестница/портал у Монолита + кат-камера. Нет glb - чисто 2D-переход
## (глиф + затемнение), ошибки не ломают выход в лабораторию.
func _transition(kind: String, floor_num: int, stars: int) -> void:
	var prop := _spawn_transition_prop(kind)
	if prop:
		if kind == "portal":
			_sfx("transition_portal")
			_sfx("transition_portal_spark")
			var pm = get_tree().get_first_node_in_group("particle_manager")
			if pm and pm.has_method("spawn_sparks_at"):
				pm.spawn_sparks_at(prop.global_position + Vector3.UP * 2.0)
		else:
			_sfx("transition_stairs")

	var ok_3d := false
	if prop:
		ok_3d = await _cut_camera_fly(prop)

	if ok_3d:
		_swap_banner("floor_up", Loc.t("tower_ceremony.floor_up", {"n": floor_num + 1}))
		await _wait(_scaled(CeremonyData.CAM_TO_TARGET_TIME + CeremonyData.CAM_RISE_TIME))
		if kind == "portal" and stars >= 3:
			_confetti(CeremonyData.CONFETTI_PORTAL_FOUNTAIN, "fountain")
	else:
		await _transition_2d_fallback(floor_num)


func _spawn_transition_prop(kind: String) -> Node3D:
	var monolith := get_tree().get_first_node_in_group("monolith") as Node3D
	if monolith == null:
		return null
	var path := CeremonyData.MODEL_PORTAL if kind == "portal" else CeremonyData.MODEL_STAIRS
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	get_tree().current_scene.add_child(node)

	# От Монолита в сторону боевой камеры, горизонтально
	var dir := Vector3(1, 0, 0)
	if _game_cam and is_instance_valid(_game_cam):
		var to_cam := _game_cam.global_position - monolith.global_position
		to_cam.y = 0.0
		if to_cam.length() > 0.5:
			dir = to_cam.normalized()
	node.global_position = monolith.global_position + dir * CeremonyData.STAIRS_OFFSET
	if _game_cam and is_instance_valid(_game_cam):
		node.look_at(_game_cam.global_position, Vector3.UP)
	if kind == "portal":
		_portal = node
	return node


## Кат-камера: спавн в текущей позе, подлёт к пропсу, подъём. false - без
## активной камеры (2D-фолбэк).
func _cut_camera_fly(prop: Node3D) -> bool:
	var active := get_viewport().get_camera_3d()
	if active == null:
		return false

	_cut_cam = Camera3D.new()
	_cut_cam.fov = 65.0
	get_tree().current_scene.add_child(_cut_cam)
	_cut_cam.global_transform = active.global_transform
	_cut_cam.make_current()

	# Направление «от Монолита наружу» - вдоль пропса, горизонтально
	var dir_out := Vector3(1, 0, 0)
	var monolith := get_tree().get_first_node_in_group("monolith") as Node3D
	if monolith:
		var v := prop.global_position - monolith.global_position
		v.y = 0.0
		if v.length() > 0.5:
			dir_out = v.normalized()

	var base := prop.global_position
	var fly_to := base + dir_out * 7.0 + Vector3.UP * 1.8
	_fly(fly_to, base + Vector3.UP * 2.2, CeremonyData.CAM_TO_TARGET_TIME)
	await _wait(_scaled(CeremonyData.CAM_TO_TARGET_TIME))
	if _dead():
		return true

	var rise_to := fly_to + Vector3.UP * CeremonyData.CAM_RISE_HEIGHT
	var look_b := base + Vector3.UP * (2.2 + CeremonyData.CAM_RISE_HEIGHT * 0.5)
	_fly(rise_to, look_b, CeremonyData.CAM_RISE_TIME)
	await _wait(_scaled(CeremonyData.CAM_RISE_TIME))
	return true


## Плавный перелёт кат-камеры (косинусный ease-in-out), ориентация на цель
func _fly(to: Vector3, look_target: Vector3, time: float) -> void:
	var from := _cut_cam.global_position
	var path := func(v: float):
		if _cut_cam == null or not is_instance_valid(_cut_cam):
			return
		var e := 0.5 - 0.5 * cos(PI * v)
		_cut_cam.global_position = from.lerp(to, e)
		if _cut_cam.global_position.distance_to(look_target) > 0.5:
			_cut_cam.look_at(look_target)
	var tw := _tween()
	tw.tween_method(path, 0.0, 1.0, _scaled(time))


## 2D-фолбэк перехода: глиф (арт или «▲») всплывает по центру экрана
func _transition_2d_fallback(floor_num: int) -> void:
	_swap_banner("floor_up", Loc.t("tower_ceremony.floor_up", {"n": floor_num + 1}))
	var vp := get_viewport().get_visible_rect().size

	var glyph := Control.new()
	glyph.position = Vector2(vp.x * 0.5 - _star_size, vp.y * 0.45)
	glyph.size = Vector2(_star_size * 2.0, _star_size * 2.0)
	glyph.pivot_offset = glyph.size * 0.5
	var tex: Texture2D = _art("glyph_stairs")
	if tex:
		var tex_rect := TextureRect.new()
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.texture = tex
		glyph.add_child(tex_rect)
	else:
		var label := Label.new()
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", int(_star_size * 1.2))
		label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.55))
		label.text = "▲"
		glyph.add_child(label)
	glyph.modulate = Color(1, 1, 1, 0)
	_root.add_child(glyph)

	var tw := _tween()
	tw.tween_property(glyph, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(glyph, "position:y", glyph.position.y - vp.y * 0.08, 1.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var tw2 := _tween()
	tw2.tween_property(glyph, "modulate:a", 0.0, 0.3).set_delay(1.4)

	await _wait(_scaled(CeremonyData.CAM_TO_TARGET_TIME + CeremonyData.CAM_RISE_TIME))


# ==================== ТИТР И ЗАТЕМНЕНИЕ ====================

func _show_title(text: String, hold: float) -> void:
	_fade_to(1.0, CeremonyData.FADE_OUT_TIME)
	await _wait(CeremonyData.FADE_OUT_TIME)
	if _dead():
		return
	_title_label.text = text
	_title_label.visible = true
	_sfx("floor_title")
	await _wait(_scaled(hold))
	await _wait(CeremonyData.SCENE_CHANGE_DELAY)


func _fade_to(alpha: float, time: float) -> void:
	var tw := _tween()
	tw.tween_property(_fade, "color:a", alpha, time)


# ==================== СЕРВИС ====================

func _sfx(slot: String, pitch_override: float = -1.0) -> void:
	if _skipped:
		return
	var cfg: Dictionary = CeremonyData.SFX_MAP.get(slot, {})
	if cfg.is_empty():
		return
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm == null or not sm.has_method("play_sound"):
		return
	var pitch: float = pitch_override if pitch_override >= 0.0 else float(cfg.get("pitch", 1.0))
	sm.play_sound(String(cfg.get("key", "")), float(cfg.get("vol", 1.0)), pitch)


func _tween() -> Tween:
	var tw := create_tween()
	_tweens.append(tw)
	return tw


func _scaled(seconds: float) -> float:
	return seconds * _time_scale


func _dead() -> bool:
	return _skipped


## Ожидание с отзывчивым скипом (поллинг 20 раз/с)
func _wait(seconds: float) -> void:
	var left := _scaled(seconds)
	while left > 0.0 and not _skipped:
		var step := minf(left, 0.05)
		await get_tree().create_timer(step).timeout
		left -= step


## Ожидание без проверки скипа (финальное затемнение при скипе)
func _wait_raw(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.05)
		await get_tree().create_timer(step).timeout
		left -= step


func _stop_all_particles() -> void:
	if not is_instance_valid(_confetti_host):
		return
	for child in _confetti_host.get_children():
		if child is GPUParticles2D:
			(child as GPUParticles2D).emitting = false


func _process(delta: float):
	if _portal and is_instance_valid(_portal) and not _skipped:
		_portal.rotate_y(CeremonyData.PORTAL_SPIN_SPEED * delta)


# ==================== СКИП ====================

func _input(event: InputEvent) -> void:
	if _skipped or not is_instance_valid(_root):
		return
	var do_skip := false
	if event is InputEventMouseButton and event.pressed:
		do_skip = true
	elif event is InputEventScreenTouch and event.pressed:
		do_skip = true
	elif not event.is_echo() and (event.is_action_pressed("ui_accept")
			or event.is_action_pressed("ui_select")):
		do_skip = true
	if do_skip:
		_skip()


func _skip():
	_sfx("skip")
	_skipped = true
	for tw in _tweens:
		if tw.is_valid():
			tw.kill()
	_tweens.clear()
	_stop_all_particles()
	_hide_all_ui()


func _hide_all_ui() -> void:
	if not is_instance_valid(_root):
		return
	for child in _root.get_children():
		if child != _fade:
			child.visible = false
