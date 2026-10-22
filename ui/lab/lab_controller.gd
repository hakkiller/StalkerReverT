# ui/lab/lab_controller.gd
extends Control
class_name LabController

## Контроллер лабораторного комплекса

signal run_started
signal upgrade_station_opened(station_type: String)
signal storage_opened
signal settings_opened

# Основная информация
@onready var run_number_label: Label = $VBox/Header/RunNumber
@onready var biomass_label: Label = $VBox/InfoPanel/HBox/BiomassValue
@onready var start_run_button: Button = $VBox/InfoPanel/StartRunButton

# Станции
@onready var anomaly_station: Button = $VBox/Stations/AnomalyStation
@onready var mutant_station: Button = $VBox/Stations/MutantStation
@onready var monolith_station: Button = $VBox/Stations/MonolithStation

# Хранилище
@onready var artifact_storage_button: Button = $VBox/StoragePanel/OpenStorageButton
@onready var artifact_counts_label: Label = $VBox/StoragePanel/HBox/ArtifactCounts

# Статистика
@onready var stats_label: Label = $VBox/StatsPanel/StatsLabel

# Нижние кнопки
@onready var menu_button: Button = $VBox/BottomButtons/MenuButton
@onready var settings_button: Button = $VBox/BottomButtons/SettingsButton
@onready var settings_screen: Control = $SettingsScreen
@onready var settings_music_slider: HSlider = $SettingsScreen/Panel/MusicSlider
@onready var settings_sfx_slider: HSlider = $SettingsScreen/Panel/SfxSlider
@onready var settings_back_button: Button = $SettingsScreen/Panel/BackButton
@onready var shop_button: Button = $VBox/BottomButtons/ShopButton
@onready var shop_panel: Control = $ShopPanel
@onready var shop_close_button: Button = $ShopPanel/Panel/ShopClose
@onready var shop_biomass_label: Label = $ShopPanel/Panel/ShopBiomass
@onready var mutant_grid: GridContainer = $ShopPanel/Panel/MutantGrid
@onready var artifact_grid: GridContainer = $ShopPanel/Panel/ArtifactGrid
@onready var save_button: Button = $VBox/BottomButtons/SaveButton

# Панели
@onready var upgrade_panel: Control = $UpgradePanel
@onready var storage_panel: Control = $StoragePanel
@onready var result_panel: Control = $ResultPanel

# Данные
var lab_data: LabData
var statistics: GameStatistics
var game_manager: Node

# Кампания: выбранный уровень и элементы селектора (строятся кодом в Header)
var _campaign_level: int = 1
# Выбранный этаж Башни Монолита (в режиме "Башня")
var _tower_floor: int = 1
# Анимированная полоса пути по Зоне (внизу лабы, на месте Spacer)
var _journey: JourneyMap = null
var _campaign_prev_button: Button
var _campaign_next_button: Button
var _campaign_mode_button: Button
var _campaign_label: Label
# Кнопка врат ярусов (видна только в режиме Башни)
var _gates_button: Button
# Переключатель режима забега: кампания / выживание
var _run_mode_button: Button


func _ready():
        # print("lab_controller: _ready started")
        
        _load_cover_art()
        
        # Ищем GameManager один раз при старте
        game_manager = get_tree().get_first_node_in_group("game_manager")
        
        _load_data()
        _setup_connections()
        _apply_static_texts()
        _refresh_ui()
        _setup_campaign_selector()
        _refresh_campaign_ui()
        _build_star_ui()
        _build_farm_ui()
        _build_gacha_ui()
        _build_gallery_ui()
        _build_profile_ui()
        _build_language_button()
        _build_arena_ui()
        _build_gates_ui()
        _apply_bunker_style()
        _apply_bunker_layout_sizes()
        Loc.changed.connect(_apply_static_texts)
        _show_last_run_result()

        # print("lab_controller: initialized, GameManager найден: ", game_manager != null)


func _show_last_run_result():
        """Панель итогов последнего забега (результат кладёт GameManager.process_run_result)"""
        if not get_tree().root.has_meta("last_run_result"):
                return

        var result: Dictionary = get_tree().root.get_meta("last_run_result")
        get_tree().root.remove_meta("last_run_result")
        show_run_result(result)


func _load_cover_art():
        """Фоновая обложка лаборатории: БУНКЕР-зал (ui/lab/bunker_lab.svg).
        Файла нет - остаётся тёмная подложка Background."""
        var cover: TextureRect = get_node_or_null("CoverArt")
        if not cover:
                return
        const COVER_PATH := "res://ui/lab/bunker_lab.svg"
        if ResourceLoader.exists(COVER_PATH):
                cover.texture = load(COVER_PATH)
                # print("lab_controller: обложка лаборатории загружена")
        else:
                cover.visible = false


func _load_data():
        # print("lab_controller: загрузка данных...")
        
        if game_manager:
                # print("GameManager НАЙДЕН!")
                lab_data = game_manager.get_lab_data()
                statistics = game_manager.get_statistics()
                # Рубеж кампании для проверки разблокировки расширенных тиров
                lab_data.campaign_level_reached = game_manager.get_campaign_level()
        else:
                # print("GameManager НЕ НАЙДЕН! Создаем временные данные")
                lab_data = LabData.new()
                statistics = GameStatistics.new()
        
        # print("lab_controller: данные загружены")


func _setup_connections():
        start_run_button.pressed.connect(_on_start_run_pressed)
        menu_button.pressed.connect(_on_menu_pressed)
        settings_button.pressed.connect(_on_settings_pressed)
        settings_back_button.pressed.connect(_on_settings_back_pressed)
        shop_button.pressed.connect(_on_shop_pressed)
        shop_close_button.pressed.connect(_on_shop_close_pressed)
        _setup_settings_sliders()
        _setup_save_slot_selector()
        save_button.pressed.connect(_on_save_pressed)
        artifact_storage_button.pressed.connect(_on_storage_pressed)
        
        anomaly_station.pressed.connect(_on_anomaly_station_pressed)
        mutant_station.pressed.connect(_on_mutant_station_pressed)
        monolith_station.pressed.connect(_on_monolith_station_pressed)
        
        _setup_sounds()


func _setup_sounds():
        var buttons = [
                start_run_button, menu_button, settings_button, 
                save_button, artifact_storage_button,
                anomaly_station, mutant_station, monolith_station
        ]
        
        for btn in buttons:
                if btn:
                        btn.mouse_entered.connect(_play_hover_sound)


func _play_hover_sound():
        var sm = get_tree().get_first_node_in_group("sound_manager")
        if sm and sm.has_method("play_sound"):
                sm.play_sound("ui_hover", 0.3)


func _apply_static_texts():
        """Все статические надписи лаборатории по текущему языку (Loc.changed пере apply)"""
        var title: Label = get_node_or_null("VBox/Header/Title")
        if title:
                title.text = Loc.t("lab.title")
        var info: Label = get_node_or_null("VBox/InfoPanel/HBox/InfoLabel")
        if info:
                info.text = Loc.t("lab.info_header")
        var biomass_prefix: Label = get_node_or_null("VBox/InfoPanel/HBox/BiomassLabel")
        if biomass_prefix:
                biomass_prefix.text = Loc.t("lab.biomass_prefix")
        start_run_button.text = Loc.t("lab.start_run")
        menu_button.text = Loc.t("lab.menu")
        settings_button.text = Loc.t("lab.settings")
        shop_button.text = Loc.t("lab.shop")
        save_button.text = Loc.t("lab.save")
        artifact_storage_button.text = Loc.t("lab.storage_open")
        var storage_label: Label = get_node_or_null("VBox/StoragePanel/HBox/StorageLabel")
        if storage_label:
                storage_label.text = Loc.t("lab.storage")
        var settings_title: Label = get_node_or_null("SettingsScreen/Panel/SettingsTitle")
        if settings_title:
                settings_title.text = Loc.t("lab.settings")
        var music_label: Label = get_node_or_null("SettingsScreen/Panel/MusicLabel")
        if music_label:
                music_label.text = Loc.t("lab.settings_music")
        var sfx_label: Label = get_node_or_null("SettingsScreen/Panel/SfxLabel")
        if sfx_label:
                sfx_label.text = Loc.t("lab.settings_sfx")
        var settings_back: Button = get_node_or_null("SettingsScreen/Panel/BackButton")
        if settings_back:
                settings_back.text = Loc.t("lab.back")
        var shop_title: Label = get_node_or_null("ShopPanel/Panel/ShopTitle")
        if shop_title:
                shop_title.text = Loc.t("shop.title")
        var mutants_header: Label = get_node_or_null("ShopPanel/Panel/MutantsHeader")
        if mutants_header:
                mutants_header.text = Loc.t("shop.mutants_header")
        var artifacts_header: Label = get_node_or_null("ShopPanel/Panel/ArtifactsHeader")
        if artifacts_header:
                artifacts_header.text = Loc.t("shop.artifacts_header")
        var shop_close: Button = get_node_or_null("ShopPanel/Panel/ShopClose")
        if shop_close:
                shop_close.text = Loc.t("lab.back")
        # Панели звёзд/фермы (строятся кодом) - перезаполнить
        if star_panel and star_panel.visible:
                _rebuild_star_panel()
        if farm_panel and farm_panel.visible:
                _rebuild_farm_panel()
        # Языковая кнопка показывает текущий язык
        if _lang_button:
                _lang_button.text = Loc.t("menu.language")


func _play_click_sound():
        var sm = get_tree().get_first_node_in_group("sound_manager")
        if sm and sm.has_method("play_sound"):
                sm.play_sound("ui_click", 0.6)


func _refresh_ui():
        if not lab_data:
                # print("lab_data отсутствует, создаем новый")
                lab_data = LabData.new()
        _refresh_gacha_deck()
        
        run_number_label.text = Loc.t("lab.day", {"n": lab_data.run_number})
        biomass_label.text = _format_number(lab_data.biomass)
        
        _update_station_button(anomaly_station, Loc.t("lab.anomalies"), lab_data.get_total_anomaly_levels())
        _update_station_button(mutant_station, Loc.t("lab.mutants"), lab_data.get_total_mutant_levels())
        _update_station_button(monolith_station, Loc.t("lab.monolith"), lab_data.get_total_monolith_levels())
        
        var common = lab_data.get_artifact_count("common")
        var rare = lab_data.get_artifact_count("rare")
        var legendary = lab_data.get_artifact_count("legendary")
        artifact_counts_label.text = Loc.t("lab.storage_counts", {"c": common, "r": rare, "l": legendary})
        
        if statistics:
                stats_label.text = "Всего забегов: %d   Побед: %d   Поражений: %d\nСталкеров убито: %d   Артефактов украдено: %d\nРекорд выживания: %d волн" % [
                        statistics.total_runs,
                        statistics.wins,
                        statistics.losses,
                        statistics.stalkers_killed,
                        statistics.artifacts_stolen,
                        statistics.best_survival_wave
                ]


func _update_station_button(station: Button, station_name: String, total_levels: int):
        var name_label = station.get_node_or_null("StationName")
        if name_label and name_label is Label:
                name_label.text = station_name
        
        var level_label = station.get_node_or_null("StationLevel")
        if level_label and level_label is Label:
                level_label.text = Loc.t("lab.level_short", {"n": total_levels})


func _format_number(value: float) -> String:
        var s = str(int(value))
        var result = ""
        var count = 0
        
        for i in range(s.length() - 1, -1, -1):
                if count > 0 and count % 3 == 0:
                        result = " " + result
                result = s[i] + result
                count += 1
        
        return result


# ==================== КАМПАНИЯ ====================

func _setup_campaign_selector():
        """Селектор уровня кампании в шапке лаборатории: ◀ уровень ▶ и режим сложности"""
        # По умолчанию стоим на ТЕКУЩЕМ рубеже, а не переигрываем первый уровень
        if game_manager:
                _campaign_level = game_manager.get_campaign_level()
                _tower_floor = game_manager.get_tower_frontier()
        var header: HBoxContainer = get_node_or_null("VBox/Header")
        if not header:
                # print("lab_controller: Header не найден, селектор кампании не построен")
                return

        var row := HBoxContainer.new()
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.alignment = BoxContainer.ALIGNMENT_END
        row.add_theme_constant_override("separation", 8)

        _campaign_label = Label.new()
        _campaign_label.add_theme_font_size_override("font_size", 16)
        _campaign_label.clip_text = true
        _campaign_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

        _run_mode_button = Button.new()
        _run_mode_button.text = "Кампания"
        _run_mode_button.tooltip_text = "Режим забега: Кампания → Башня Монолита → Выживание"
        _campaign_prev_button = Button.new()
        _campaign_prev_button.text = "◀"
        _campaign_prev_button.tooltip_text = "Предыдущий уровень / этаж"
        _campaign_next_button = Button.new()
        _campaign_next_button.text = "▶"
        _campaign_next_button.tooltip_text = "Следующий уровень / этаж"
        _campaign_mode_button = Button.new()

        _gates_button = Button.new()
        _gates_button.text = "ВРАТА"
        _gates_button.tooltip_text = "Врата ярусов башни"
        row.add_child(_run_mode_button)
        row.add_child(_campaign_prev_button)
        row.add_child(_campaign_label)
        row.add_child(_campaign_next_button)
        row.add_child(_campaign_mode_button)
        row.add_child(_gates_button)
        header.add_child(row)
        _gates_button.pressed.connect(_on_gates_open_pressed)
        _gates_button.visible = false

        _run_mode_button.pressed.connect(_on_run_mode_pressed)
        _campaign_prev_button.pressed.connect(_on_campaign_prev_pressed)
        _campaign_next_button.pressed.connect(_on_campaign_next_pressed)
        _campaign_mode_button.pressed.connect(_on_campaign_mode_pressed)
        for btn in [_run_mode_button, _campaign_prev_button, _campaign_next_button, _campaign_mode_button, _gates_button]:
                btn.mouse_entered.connect(_play_hover_sound)


func _refresh_campaign_ui():
        if not game_manager or not _campaign_label:
                return

        # Карта пути внизу лабы (однократная замена Spacer'а)
        if _journey == null:
                _setup_journey_map()
        _update_journey()

        # Режим забега определяет, что показывает строка
        var mode: String = game_manager.get_selected_run_mode()
        var is_survival: bool = mode == "survival"
        _run_mode_button.text = "Башня" if mode == "tower" else ("Выживание" if is_survival else "Кампания")
        # Множитель сложности применяется в обоих режимах
        _campaign_mode_button.text = "Сложность: %s" % CampaignData.get_mode_name(game_manager.get_campaign_mode())

        if mode == "tower":
                # Башня Монолита: выбор этажа в пределах открытого рубежа
                if _gates_button:
                        _gates_button.visible = true
                var tower_frontier: int = game_manager.get_tower_frontier()
                _tower_floor = clampi(_tower_floor, 1, tower_frontier)
                var tower_tier: Dictionary = TowerData.get_tier(_tower_floor)
                var saved_stars: int = 0
                if game_manager.current_save_data:
                        saved_stars = int(game_manager.current_save_data.tower_stars.get(str(_tower_floor), 0))
                var tower_text: String = "БАШНЯ %d/100 - %s" % [_tower_floor, str(tower_tier.get("name", ""))]
                if _tower_floor >= TowerData.TOTAL_FLOORS and tower_frontier >= TowerData.TOTAL_FLOORS:
                        tower_text = "БАШНЯ ПОКОРЕНА! Финальный этаж: 100/100"
                elif saved_stars > 0:
                        tower_text += "  " + "★".repeat(saved_stars)
                _campaign_label.text = tower_text
                _campaign_prev_button.disabled = _tower_floor <= 1
                _campaign_next_button.disabled = _tower_floor >= tower_frontier
                return

        if is_survival:
                var record: int = 0
                var stats = game_manager.get_statistics()
                if stats:
                        record = stats.best_survival_wave
                _campaign_label.text = "ВЫЖИВАНИЕ - волны без предела, награда за каждую (рекорд: %d)" % record
                _campaign_prev_button.disabled = true
                _campaign_next_button.disabled = true
                return

        var frontier: int = game_manager.get_campaign_level()
        _campaign_level = clampi(_campaign_level, 1, frontier)
        if _gates_button:
                _gates_button.visible = false

        var params: Dictionary = CampaignData.get_level_params(_campaign_level, game_manager.get_campaign_mode())
        var text: String
        if params.get("is_boss", false):
                text = "КАРАВАН %d/100: «%s»" % [_campaign_level, params.get("title", "")]
        else:
                text = "Уровень %d/100 - %s" % [_campaign_level, params.get("chapter_title", "")]
        if _campaign_level < frontier:
                text += " (пройден)"
        if game_manager.is_campaign_completed() and _campaign_level >= CampaignData.TOTAL_LEVELS:
                text = "КАМПАНИЯ ПРОЙДЕНА! Финальный уровень: 100/100"
        _campaign_label.text = text

        _campaign_prev_button.disabled = _campaign_level <= 1
        _campaign_next_button.disabled = _campaign_level >= frontier
        _campaign_mode_button.text = "Сложность: %s" % CampaignData.get_mode_name(game_manager.get_campaign_mode())


# ==================== КАРТА ПУТИ ====================

func _setup_journey_map():
        """Анимированная полоса пути по Зоне вместо пустого Spacer'а:
        кампания - 100 уровней до Саркофага, башня - 100 этажей, выживание - волны."""
        var vbox: VBoxContainer = get_node_or_null("VBox")
        var spacer: Control = get_node_or_null("VBox/Spacer")
        if vbox == null:
                return
        _journey = JourneyMap.new()
        _journey.custom_minimum_size = Vector2(0, 240)
        _journey.size_flags_vertical = Control.SIZE_EXPAND_FILL
        # Тач-жест карты пути: свайп = шаг ◀▶ (та же логика, что у кнопок)
        _journey.step_requested.connect(_on_journey_step)
        if spacer:
                vbox.add_child(_journey)
                vbox.move_child(_journey, spacer.get_index())
                spacer.queue_free()
        else:
                vbox.add_child(_journey)


func _update_journey():
        if _journey == null or game_manager == null:
                return
        var jmode: String = game_manager.get_selected_run_mode()
        if jmode == "tower":
                _journey.set_tower(_tower_floor, game_manager.get_tower_frontier(),
                        str(TowerData.get_tier(_tower_floor).get("name", "")))
        elif jmode == "survival":
                var rec: int = 0
                var stats = game_manager.get_statistics()
                if stats:
                        rec = stats.best_survival_wave
                _journey.set_survival(rec)
        else:
                var params: Dictionary = CampaignData.get_level_params(_campaign_level, game_manager.get_campaign_mode())
                _journey.set_campaign(_campaign_level, game_manager.get_campaign_level(),
                        str(params.get("chapter_title", "")))


func _on_journey_step(dir: int) -> void:
        """Свайп по ленте пути (тач-жест карты этажей) — шаг как кнопками ◀▶."""
        if dir < 0:
                _on_campaign_prev_pressed()
        else:
                _on_campaign_next_pressed()


func _on_run_mode_pressed():
        """Переключение режима забега: кампания -> башня -> выживание -> кампания"""
        _play_click_sound()
        if not game_manager:
                return

        var cur: String = game_manager.get_selected_run_mode()
        var next_mode: String = "tower"
        if cur == "tower":
                next_mode = "survival"
        elif cur == "survival":
                next_mode = "campaign"

        game_manager.set_selected_run_mode(next_mode)
        _refresh_campaign_ui()
        # Врата ярусов встречают игрока при входе в режим Башни (макет «вариант 4»)
        if next_mode == "tower":
                _open_gates()
        elif gates_panel and gates_panel.visible:
                gates_panel.visible = false


func _on_campaign_prev_pressed():
        _play_click_sound()
        if game_manager and game_manager.get_selected_run_mode() == "tower":
                _tower_floor = maxi(1, _tower_floor - 1)
        else:
                _campaign_level = maxi(1, _campaign_level - 1)
        _refresh_campaign_ui()


func _on_campaign_next_pressed():
        _play_click_sound()
        if game_manager and game_manager.get_selected_run_mode() == "tower":
                var tower_frontier: int = game_manager.get_tower_frontier()
                _tower_floor = mini(tower_frontier, _tower_floor + 1)
        else:
                var frontier: int = game_manager.get_campaign_level() if game_manager else 1
                _campaign_level = mini(frontier, _campaign_level + 1)
        _refresh_campaign_ui()


func _on_campaign_mode_pressed():
        """Цикл режимов сложности: Сталкер -> Ветеран -> Легенда"""
        _play_click_sound()
        if not game_manager:
                return

        var current: String = game_manager.get_campaign_mode()
        var next_mode: String = CampaignData.MODE_EASY
        if current == CampaignData.MODE_EASY:
                next_mode = CampaignData.MODE_NORMAL
        elif current == CampaignData.MODE_NORMAL:
                next_mode = CampaignData.MODE_HARD

        game_manager.set_campaign_mode(next_mode)
        _refresh_campaign_ui()


# ==================== ОБРАБОТЧИКИ ====================

func _on_start_run_pressed():
        _play_click_sound()
        run_started.emit()
        
        if not game_manager:
                game_manager = get_tree().get_first_node_in_group("game_manager")
        
        if game_manager:
                # Выбранный в селекторе уровень кампании уходит в параметры забега
                game_manager.selected_campaign_level = _campaign_level
                # Башня: выбранный этаж уходит в параметры забега
                if game_manager.get_selected_run_mode() == "tower":
                        game_manager.set_selected_tower_floor(_tower_floor)
                # print("Запуск забега через GameManager (уровень кампании %d)" % _campaign_level)
                await get_tree().create_timer(0.2).timeout
                game_manager.change_scene("run")
        else:
                pass
                # print("GameManager не найден, не могу начать забег")


func _on_menu_pressed():
        _play_click_sound()
        
        if not game_manager:
                game_manager = get_tree().get_first_node_in_group("game_manager")
        
        if game_manager:
                await get_tree().create_timer(0.2).timeout
                game_manager.change_scene("main_menu")
        else:
                # print("GameManager не найден, переходим напрямую")
                get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _setup_settings_sliders():
        """Слайдеры громкости лаборатории - те же аудиошины Music/SFX,
        что и в главном меню (значения глобальные)"""
        settings_music_slider.value_changed.connect(
                func(v): _set_bus_volume("Music", v))
        settings_sfx_slider.value_changed.connect(
                func(v): _set_bus_volume("SFX", v))
        var music_idx = AudioServer.get_bus_index("Music")
        var sfx_idx = AudioServer.get_bus_index("SFX")
        if music_idx >= 0:
                settings_music_slider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(music_idx)))
        if sfx_idx >= 0:
                settings_sfx_slider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(sfx_idx)))


func _setup_save_slot_selector():
        """Выбор активного слота сохранения между слайдерами и кнопкой НАЗАД"""
        var panel = get_node_or_null("SettingsScreen/Panel")
        if not panel:
                # print("lab_controller: SettingsScreen/Panel не найден, селектор слота не построен")
                return

        var selector := SaveSlotSelector.new()
        selector.position = Vector2(30, 202)
        selector.size = Vector2(340, 28)
        panel.add_child(selector)


func _set_bus_volume(bus_name: String, value: float):
        var idx = AudioServer.get_bus_index(bus_name)
        if idx >= 0:
                AudioServer.set_bus_volume_db(idx, linear_to_db(max(value, 0.0001)))
                AudioServer.set_bus_mute(idx, value <= 0.001)


func _on_settings_back_pressed():
        _play_click_sound()
        settings_screen.visible = false


# ==================== МАГАЗИН ====================

func _on_shop_pressed():
        _play_click_sound()
        shop_panel.visible = true
        _rebuild_shop()


func _on_shop_close_pressed():
        _play_click_sound()
        shop_panel.visible = false


func _rebuild_shop():
        """Кнопки магазина из таблиц GachaData: имя + цена, покупка за биомассу лаборатории"""
        for child in mutant_grid.get_children():
                child.queue_free()
        for child in artifact_grid.get_children():
                child.queue_free()
        var lab_biomass: float = lab_data.biomass if lab_data else 0.0
        shop_biomass_label.text = Loc.t("shop.biomass", {"n": int(lab_biomass)})
        for entry in GachaData.get_shop_mutants():
                var type: String = entry[0]
                var price: float = entry[2]
                var btn := Button.new()
                if lab_data and not lab_data.unlocked_mutants.has(type):
                        btn.disabled = true
                        btn.text = entry[1] + "
" + Loc.t("shop.locked", {"n": GachaData.get_unlock_campaign_level(type)})
                else:
                        btn.text = _shop_item_text(entry[1], type, true) + "
🧬" + str(int(price))
                        btn.pressed.connect(_on_shop_buy.bind("mutant", type, price))
                _add_card_icon(btn, type, true)
                btn.custom_minimum_size = Vector2(160, 46)
                mutant_grid.add_child(btn)
        for entry in GachaData.get_shop_artifacts():
                var type: String = entry[0]
                var price: float = entry[2]
                var btn := Button.new()
                if lab_data and not lab_data.won_artifacts.has(type):
                        btn.disabled = true
                        btn.text = entry[1] + "
" + Loc.t("shop.locked", {"n": GachaData.get_unlock_campaign_level(type)})
                else:
                        btn.text = _shop_item_text(entry[1], type, false) + "
🧬" + str(int(price))
                        btn.pressed.connect(_on_shop_buy.bind("artifact", type, price))
                _add_card_icon(btn, type, false)
                btn.custom_minimum_size = Vector2(240, 46)
                artifact_grid.add_child(btn)


func _add_card_icon(btn: Button, type: String, is_mutant: bool):
        """Карточка-иконка слева от текста кнопки (магазин/дропы/ферма)"""
        var path: String = GachaData.card_icon_path(type, is_mutant)
        if ResourceLoader.exists(path):
                btn.icon = load(path)
                btn.expand_icon = true
                btn.add_theme_constant_override("icon_max_width", 24)


func _make_icon_rect(type: String, is_mutant: bool, icon_size: int = 24) -> TextureRect:
        var rect := TextureRect.new()
        var path: String = GachaData.card_icon_path(type, is_mutant)
        if ResourceLoader.exists(path):
                rect.texture = load(path)
        rect.custom_minimum_size = Vector2(icon_size, icon_size)
        rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        return rect


func _shop_item_text(item_name: String, type: String, is_mutant: bool) -> String:
        """Имя + звёзды, если тип уже в коллекции (в бою получит эти звёзды)"""
        if not lab_data:
                return item_name
        var stars: int = lab_data.get_mutant_stars(type) if is_mutant else lab_data.get_artifact_stars(type)
        var owned: bool = lab_data.unlocked_mutants.has(type) if is_mutant else lab_data.won_artifacts.has(type)
        if owned and stars > 1:
                return item_name + " " + "★".repeat(stars)
        if owned:
                return item_name + " ★"
        return item_name


func _on_shop_buy(kind: String, item_type: String, price: float):
        var bought := false
        if kind == "mutant":
                bought = game_manager.buy_shop_mutant(item_type, price)
        else:
                bought = game_manager.buy_shop_artifact(item_type, price)
        if bought:
                _play_click_sound()
                _rebuild_shop()
        else:
                _show_message(Loc.t("shop.not_enough"), 1.5)


# ==================== ЗВЁЗДНОСТЬ ====================

var star_panel: Control
var star_biomass_label: Label
var star_list: VBoxContainer
var _stars_return: String = ""  # откуда открыли звёзды: "farm" / "shop" — куда вернуться после закрытия


func _build_star_ui():
        """Кнопка ★ в магазине + панель прокачки звёзд (строится кодом)"""
        star_panel = Control.new()
        star_panel.name = "StarPanel"
        star_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
        star_panel.mouse_filter = Control.MOUSE_FILTER_STOP
        star_panel.visible = false
        add_child(star_panel)

        var shade := ColorRect.new()
        shade.set_anchors_preset(Control.PRESET_FULL_RECT)
        shade.color = Color(0, 0, 0, 0.6)
        star_panel.add_child(shade)

        var panel := Panel.new()
        panel.anchor_left = 0.5
        panel.anchor_top = 0.5
        panel.anchor_right = 0.5
        panel.anchor_bottom = 0.5
        panel.offset_left = -280.0
        panel.offset_top = -210.0
        panel.offset_right = 280.0
        panel.offset_bottom = 210.0
        star_panel.add_child(panel)

        var title := Label.new()
        title.text = Loc.t("stars.title")
        title.position = Vector2(0, 10)
        title.size = Vector2(560, 25)
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        panel.add_child(title)

        star_biomass_label = Label.new()
        star_biomass_label.position = Vector2(0, 36)
        star_biomass_label.size = Vector2(560, 20)
        star_biomass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        panel.add_child(star_biomass_label)

        var scroll := ScrollContainer.new()
        scroll.position = Vector2(20, 64)
        scroll.size = Vector2(520, 288)
        panel.add_child(scroll)

        star_list = VBoxContainer.new()
        star_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        star_list.add_theme_constant_override("separation", 4)
        scroll.add_child(star_list)

        var close_btn := Button.new()
        close_btn.text = "НАЗАД"
        close_btn.position = Vector2(200, 362)
        close_btn.size = Vector2(160, 35)
        close_btn.pressed.connect(_on_stars_close_pressed)
        close_btn.mouse_entered.connect(_play_hover_sound)
        panel.add_child(close_btn)


func _on_stars_pressed():
        _play_click_sound()
        # Запоминаем, откуда открыли звёзды, чтобы вернуть панель после закрытия (ферма не должна «пропадать»)
        if farm_panel.visible:
                _stars_return = "farm"
        elif shop_panel.visible:
                _stars_return = "shop"
        else:
                _stars_return = ""
        shop_panel.visible = false
        farm_panel.visible = false
        star_panel.visible = true
        _rebuild_star_panel()


func _on_stars_close_pressed():
        _play_click_sound()
        star_panel.visible = false
        # Возвращаем пользователя туда, откуда он открывал звёзды (обычно — ферма)
        if _stars_return == "farm":
                farm_panel.visible = true
                _rebuild_farm_panel()
        elif _stars_return == "shop":
                shop_panel.visible = true
                _rebuild_shop()
        _stars_return = ""


func _rebuild_star_panel():
        """Строка на каждого питомца коллекции: имя, звёзды, цена следующей звезды"""
        for child in star_list.get_children():
                child.queue_free()
        if not lab_data:
                return
        star_biomass_label.text = Loc.t("stars.biomass_line", {"n": int(lab_data.biomass)})

        var artifacts: Array[String] = []
        for t in lab_data.won_artifacts:
                if not artifacts.has(t):
                        artifacts.append(t)

        if artifacts.is_empty():
                var empty := Label.new()
                empty.text = Loc.t("stars.artifacts_only")
                star_list.add_child(empty)
                return

        star_list.add_child(_make_star_section(Loc.t("stars.artifacts_header")))
        for type in artifacts:
                star_list.add_child(_make_star_row("artifact", type))


func _make_star_section(text: String) -> Label:
        var label := Label.new()
        label.text = text
        return label


func _make_star_row(kind: String, type: String) -> Control:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 6)
        row.add_child(_make_icon_rect(type, kind == "mutant", 26))
        var stars: int = lab_data.get_mutant_stars(type) if kind == "mutant" else lab_data.get_artifact_stars(type)

        var name_label := Label.new()
        name_label.text = "%s  %s" % [GachaData.display_name(type), LabData.stars_text(stars)]
        name_label.tooltip_text = Loc.t("stars.mult_tip", {"n": "%.1f" % LabData.get_star_stat_mult(stars)})
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(name_label)

        if stars >= LabData.MAX_STARS:
                var max_label := Label.new()
                max_label.text = Loc.t("stars.max")
                row.add_child(max_label)
        else:
                var cost := lab_data.get_star_upgrade_cost(stars)
                var btn := Button.new()
                btn.text = "🧬 " + str(int(cost))
                btn.pressed.connect(_on_star_upgrade.bind(kind, type))
                btn.mouse_entered.connect(_play_hover_sound)
                row.add_child(btn)
        return row


func _on_star_upgrade(kind: String, type: String):
        _play_click_sound()
        var ok := false
        if kind == "mutant":
                ok = game_manager.upgrade_mutant_star(type)
        else:
                ok = game_manager.upgrade_artifact_star(type)
        if ok:
                lab_data = game_manager.get_lab_data()
                _rebuild_star_panel()
                if shop_panel.visible:
                        _rebuild_shop()
                _refresh_ui()
        else:
                _show_message(Loc.t("stars.fail_msg"), 1.5)


func _on_settings_pressed():
        _play_click_sound()
        settings_opened.emit()
        settings_screen.visible = true


func _on_save_pressed():
        _play_click_sound()

        if not game_manager:
                game_manager = get_tree().get_first_node_in_group("game_manager")

        if game_manager and game_manager.has_method("save_to_active_slot"):
                game_manager.save_to_active_slot()
                _show_message("Игра сохранена", 1.0)
        else:
                pass
                # print("GameManager не найден, не могу сохранить")


func _on_storage_pressed():
        _play_click_sound()
        storage_opened.emit()
        _open_storage()


func _on_anomaly_station_pressed():
        _play_click_sound()
        upgrade_station_opened.emit("anomaly")
        _open_upgrade_station("anomaly")


func _on_mutant_station_pressed():
        _play_click_sound()
        upgrade_station_opened.emit("mutant")
        _open_upgrade_station("mutant")


func _on_monolith_station_pressed():
        _play_click_sound()
        upgrade_station_opened.emit("monolith")
        _open_upgrade_station("monolith")


# ==================== ПАНЕЛИ ====================

func _open_upgrade_station(station_type: String):
        if upgrade_panel and upgrade_panel.has_method("setup"):
                upgrade_panel.setup(station_type, lab_data, _on_upgrade_purchased)
                upgrade_panel.visible = true
        else:
                # print("Upgrade panel not found or invalid")
                _show_message("Панель улучшений не найдена", 1.0)


func _on_upgrade_purchased(_upgrade_type: String):
        if not game_manager:
                game_manager = get_tree().get_first_node_in_group("game_manager")
        
        if game_manager:
                lab_data = game_manager.get_lab_data()
        _refresh_ui()
        _show_message("Улучшение приобретено!", 1.0)


func _open_storage():
        if storage_panel and storage_panel.has_method("setup"):
                storage_panel.setup(lab_data, _on_artifact_exchanged)
                storage_panel.visible = true
        else:
                # print("Storage panel not found or invalid")
                _show_message("Хранилище не найдено", 1.0)


func _on_artifact_exchanged():
        if not game_manager:
                game_manager = get_tree().get_first_node_in_group("game_manager")
        
        if game_manager:
                lab_data = game_manager.get_lab_data()
        _refresh_ui()
        _show_message("Артефакт обменян", 1.0)


func show_run_result(result: Dictionary):
        if result_panel and result_panel.has_method("show_result"):
                result_panel.show_result(result)
                result_panel.visible = true
        
        if not game_manager:
                game_manager = get_tree().get_first_node_in_group("game_manager")
        
        if game_manager:
                lab_data = game_manager.get_lab_data()
                statistics = game_manager.get_statistics()
        _refresh_ui()


func _show_message(text: String, duration: float = 2.0):
        var msg_label = Label.new()
        msg_label.text = text
        msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        msg_label.add_theme_color_override("font_color", Color.WHITE)
        msg_label.add_theme_color_override("font_shadow_color", Color.BLACK)
        msg_label.add_theme_constant_override("shadow_offset_x", 2)
        msg_label.add_theme_constant_override("shadow_offset_y", 2)
        
        add_child(msg_label)
        msg_label.position = Vector2(size.x / 2 - 100, size.y / 2)
        
        await get_tree().create_timer(duration).timeout
        if is_instance_valid(msg_label):
                msg_label.queue_free()

# ==================== ФЕРМА МУТАНТОВ (макет «ФЕРМА-ИНКУБАТОР») ====================
# Полноэкранная ферма: карточки питомцев слева + АЛТАРЬ ЗВЁЗД справа ВНУТРИ фермы.
# Звезда качается без выхода с фермы: бак копится кормами, прокат не закрывает список.

var farm_panel: Control
var farm_list: VBoxContainer          # содержимое левой зоны (карточки или списки режимов)
var farm_title_label: Label
# Режим кормления: [fodder_type] или []
var _feed_fodder: Array = []
# Режим «кормовая грелка»: выбор копии-корма
var _farm_mode: String = "cards"      # cards | feed_pick
var _farm_selected: String = ""       # выбранный питомец для алтаря
# Узлы фермы
var _farm_cards_scroll: ScrollContainer
var _farm_cards_box: HBoxContainer
var _farm_modes_scroll: ScrollContainer
var _farm_altar_panel: Panel
var _farm_altar_box: VBoxContainer
var _farm_biomass_chip: Label = null
var _farm_rolls_chip: Label = null


func _build_farm_ui():
        """Кнопка ФЕРМА + полноэкранная ферма-инкубатор (строится кодом)"""
        var bottom: HBoxContainer = get_node_or_null("VBox/BottomButtons")
        if bottom:
                var farm_btn := Button.new()
                farm_btn.name = "FarmButton"
                farm_btn.text = Loc.t("lab.farm")
                farm_btn.custom_minimum_size = Vector2(0, 62)
                farm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                BunkerUI.style_button(farm_btn, "steel", 18)
                farm_btn.pressed.connect(_on_farm_pressed)
                farm_btn.mouse_entered.connect(_play_hover_sound)
                bottom.add_child(farm_btn)

        farm_panel = Control.new()
        farm_panel.name = "FarmPanel"
        farm_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
        farm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
        farm_panel.visible = false
        add_child(farm_panel)

        # Тёмный фон инкубатора
        var bg := ColorRect.new()
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.color = Color(0.024, 0.031, 0.016, 0.985)
        farm_panel.add_child(bg)

        var shade := ColorRect.new()
        shade.set_anchors_preset(Control.PRESET_FULL_RECT)
        shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
        shade.color = Color(0, 0, 0, 0.0)
        farm_panel.add_child(shade)

        var root := VBoxContainer.new()
        root.name = "FarmRoot"
        root.set_anchors_preset(Control.PRESET_FULL_RECT)
        root.offset_left = 28
        root.offset_right = -28
        root.offset_top = 18
        root.offset_bottom = -16
        root.add_theme_constant_override("separation", 10)
        farm_panel.add_child(root)

        # ---- Шапка: заголовок + пластины био/круток ----
        var head := HBoxContainer.new()
        head.add_theme_constant_override("separation", 16)
        root.add_child(head)

        var title := Label.new()
        title.name = "FarmTitle"
        title.text = "ФЕРМА МУТАНТОВ"
        title.add_theme_font_override("font", BunkerUI.font_title())
        title.add_theme_font_size_override("font_size", 36)
        title.add_theme_color_override("font_color", BunkerUI.TEXT_LIGHT)
        head.add_child(title)
        farm_title_label = title

        var sub := Label.new()
        sub.text = "ИНКУБАТОР · КОПИИ · ЗВЁЗДНЫЙ БАК"
        sub.add_theme_font_override("font", BunkerUI.font_mono())
        sub.add_theme_font_size_override("font_size", 13)
        sub.add_theme_color_override("font_color", BunkerUI.TEXT_FAINT)
        sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        head.add_child(sub)

        var spacer0 := Control.new()
        spacer0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        head.add_child(spacer0)

        var bio_plate := BunkerUI.make_plate("0", "БИО", 150.0)
        head.add_child(bio_plate)
        _farm_biomass_chip = bio_plate.get_child(0).get_child(0)

        var rolls_plate := BunkerUI.make_plate("0", "КРУТКИ", 130.0)
        head.add_child(rolls_plate)
        _farm_rolls_chip = rolls_plate.get_child(0).get_child(0)

        # ---- Тело: карточки (лево) + алтарь (право) ----
        var body := HBoxContainer.new()
        body.size_flags_vertical = Control.SIZE_EXPAND_FILL
        body.add_theme_constant_override("separation", 16)
        root.add_child(body)

        # Горизонтальный скролл карточек (обычный режим)
        _farm_cards_scroll = ScrollContainer.new()
        _farm_cards_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _farm_cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _farm_cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
        _farm_cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        body.add_child(_farm_cards_scroll)

        _farm_cards_box = HBoxContainer.new()
        _farm_cards_box.add_theme_constant_override("separation", 14)
        _farm_cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _farm_cards_scroll.add_child(_farm_cards_box)

        # Вертикальный скролл режимов (кормление/грелка/утилизация)
        _farm_modes_scroll = ScrollContainer.new()
        _farm_modes_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _farm_modes_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _farm_modes_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        _farm_modes_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
        _farm_modes_scroll.visible = false
        body.add_child(_farm_modes_scroll)

        farm_list = VBoxContainer.new()
        farm_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        farm_list.add_theme_constant_override("separation", 10)
        _farm_modes_scroll.add_child(farm_list)

        _farm_altar_panel = Panel.new()
        _farm_altar_panel.custom_minimum_size = Vector2(440, 0)
        body.add_child(_farm_altar_panel)

        _farm_altar_box = VBoxContainer.new()
        _farm_altar_box.set_anchors_preset(Control.PRESET_FULL_RECT)
        _farm_altar_box.offset_left = 22
        _farm_altar_box.offset_right = -22
        _farm_altar_box.offset_top = 14
        _farm_altar_box.offset_bottom = -14
        _farm_altar_box.add_theme_constant_override("separation", 7)
        _farm_altar_panel.add_child(_farm_altar_box)

        # ---- Подвал: НАЗАД / УТИЛИЗАЦИЯ / КОРМОВАЯ ГРЕЛКА ----
        var foot := HBoxContainer.new()
        foot.add_theme_constant_override("separation", 14)
        root.add_child(foot)

        var back_btn := Button.new()
        back_btn.text = "◄  НАЗАД"
        back_btn.custom_minimum_size = Vector2(190, 62)
        BunkerUI.style_button(back_btn, "steel", 20)
        back_btn.pressed.connect(_on_farm_close_pressed)
        back_btn.mouse_entered.connect(_play_hover_sound)
        foot.add_child(back_btn)

        var recycle_btn := Button.new()
        recycle_btn.text = "УТИЛИЗАЦИЯ КОПИЙ"
        recycle_btn.custom_minimum_size = Vector2(280, 62)
        BunkerUI.style_button(recycle_btn, "danger", 18)
        recycle_btn.pressed.connect(_on_recycle_pressed)
        recycle_btn.mouse_entered.connect(_play_hover_sound)
        foot.add_child(recycle_btn)

        var heater_btn := Button.new()
        heater_btn.text = "КОРМОВАЯ ГРЕЛКА"
        heater_btn.custom_minimum_size = Vector2(280, 62)
        BunkerUI.style_button(heater_btn, "steel", 18)
        heater_btn.pressed.connect(_on_feed_heater_pressed)
        heater_btn.mouse_entered.connect(_play_hover_sound)
        foot.add_child(heater_btn)

        var hint := Label.new()
        hint.name = "FarmHint"
        hint.text = "звёзды живут внутри фермы:\nвыберите питомца — алтарь справа"
        hint.add_theme_font_override("font", BunkerUI.font_mono())
        hint.add_theme_font_size_override("font_size", 12)
        hint.add_theme_color_override("font_color", BunkerUI.TEXT_FAINT)
        hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        foot.add_child(hint)


func _on_farm_pressed():
        _play_click_sound()
        _hide_lab_overlays("farm")
        _feed_fodder.clear()
        _farm_mode = "cards"
        if _farm_selected.is_empty() and lab_data and not lab_data.unlocked_mutants.is_empty():
                _farm_selected = str(lab_data.unlocked_mutants[0])
        farm_panel.visible = true
        _rebuild_farm_panel()


func _on_farm_close_pressed():
        _play_click_sound()
        farm_panel.visible = false


## Скрыть все оверлеи лабы, кроме except ("farm"/"shop"/"" и т.п.)
func _hide_lab_overlays(except: String = "") -> void:
        for entry in [[shop_panel, "shop"], [star_panel, "shop"], [farm_panel, "farm"],
                        [gallery_panel, "gallery"], [arena_panel, "arena"], [gates_panel, "gates"],
                        [defense_panel, "defense"]]:
                var pnl: Control = entry[0]
                if pnl and except != entry[1]:
                        pnl.visible = false


func _on_feed_heater_pressed():
        _play_click_sound()
        _feed_fodder.clear()
        _farm_mode = "feed_pick"
        _rebuild_farm_panel()


func _make_farm_card(type: String) -> Control:
        """Вертикальная карточка питомца: свечение редкости, звёзды, бак, множитель"""
        var stars: int = lab_data.get_mutant_stars(type)
        var copies: int = lab_data.get_farm_copies(type)
        var rar: String = GachaData.get_mutant_rarity(type)
        var rcol: Color = BunkerUI.RARHEX.get(rar, BunkerUI.TEXT)
        var selected: bool = _farm_selected == type

        var card := Button.new()
        card.custom_minimum_size = Vector2(236, 0)
        card.size_flags_vertical = Control.SIZE_EXPAND_FILL
        card.focus_mode = Control.FOCUS_NONE

        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(0.086, 0.11, 0.062, 1.0)
        sb.border_color = BunkerUI.HAZARD if selected else Color(rcol, 0.55)
        sb.set_border_width_all(2)
        sb.set_corner_radius_all(12)
        sb.shadow_color = Color(rcol, 0.30) if not selected else Color(BunkerUI.HAZARD, 0.5)
        sb.shadow_size = 18 if (rar == "legendary" or selected) else 8
        sb.shadow_offset = Vector2.ZERO
        sb.content_margin_top = 10.0
        sb.content_margin_bottom = 10.0
        sb.content_margin_left = 8.0
        sb.content_margin_right = 8.0
        card.add_theme_stylebox_override("normal", sb)
        var hv := sb.duplicate()
        hv.border_color = BunkerUI.HAZARD
        card.add_theme_stylebox_override("hover", hv)
        card.add_theme_stylebox_override("pressed", sb)

        var v := VBoxContainer.new()
        v.set_anchors_preset(Control.PRESET_FULL_RECT)
        v.offset_left = 10
        v.offset_right = -10
        v.offset_top = 8
        v.offset_bottom = -10
        v.add_theme_constant_override("separation", 6)
        v.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(v)

        # Верхний чип: копии или бак
        var chip := Label.new()
        var feed_cost: int = GachaData.get_star_feed_cost(maxi(stars, 1))
        if lab_data.get_star_feed(type) >= 1:
                chip.text = "звёздный бак ГОТОВ"
                chip.add_theme_color_override("font_color", Color("ffd94d"))
        elif stars < LabData.MAX_STARS:
                chip.text = "бак %d/%d" % [lab_data.get_star_progress(type), feed_cost]
                chip.add_theme_color_override("font_color", Color("a8ff7a"))
        else:
                chip.text = "копии ×%d" % copies
                chip.add_theme_color_override("font_color", Color("a8ff7a"))
        chip.add_theme_font_override("font", BunkerUI.font_mono())
        chip.add_theme_font_size_override("font_size", 12)
        chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.add_child(chip)

        # Большая буква питомца со свечением редкости
        var letter := Label.new()
        letter.text = GachaData.display_name(type).substr(0, 1)
        letter.add_theme_font_override("font", BunkerUI.font_title())
        letter.add_theme_font_size_override("font_size", 88)
        letter.add_theme_color_override("font_color", Color(rcol, 0.75))
        letter.size_flags_vertical = Control.SIZE_EXPAND_FILL
        letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.add_child(letter)

        # Звёзды
        var st := Label.new()
        if stars >= LabData.MAX_STARS:
                st.text = "★".repeat(LabData.MAX_STARS)
        else:
                st.text = "★".repeat(stars) + "☆".repeat(LabData.MAX_STARS - stars)
        st.add_theme_font_override("font", BunkerUI.font_mono())
        st.add_theme_font_size_override("font_size", 19)
        st.add_theme_color_override("font_color", Color("ffd94d"))
        st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.add_child(st)

        # Бак-полоса (прогресс к следующему корму)
        if stars < LabData.MAX_STARS:
            var bak := ProgressBar.new()
            bak.max_value = maxi(feed_cost, 1)
            bak.value = lab_data.get_star_progress(type)
            bak.show_percentage = false
            bak.custom_minimum_size = Vector2(0, 8)
            var bbg := StyleBoxFlat.new()
            bbg.bg_color = Color(0.03, 0.045, 0.024)
            bbg.border_color = BunkerUI.STEEL_EDGE
            bbg.set_border_width_all(1)
            bbg.set_corner_radius_all(4)
            var bfill := StyleBoxFlat.new()
            bfill.bg_color = Color("8dff5a")
            bfill.set_corner_radius_all(4)
            bak.add_theme_stylebox_override("background", bbg)
            bak.add_theme_stylebox_override("fill", bfill)
            v.add_child(bak)

        var nm := Label.new()
        nm.text = GachaData.display_name(type).to_upper()
        nm.add_theme_font_override("font", BunkerUI.font_title())
        nm.add_theme_font_size_override("font_size", 15)
        nm.add_theme_color_override("font_color", BunkerUI.TEXT_LIGHT)
        nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.add_child(nm)

        var meta := Label.new()
        if stars < LabData.MAX_STARS:
                meta.text = "копии ×%d · бак %d/%d" % [copies, lab_data.get_star_progress(type), maxi(feed_cost, 1)]
        else:
                meta.text = "копии ×%d" % copies
        meta.add_theme_font_override("font", BunkerUI.font_mono())
        meta.add_theme_font_size_override("font_size", 11)
        meta.add_theme_color_override("font_color", Color("8ba06e"))
        meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.add_child(meta)

        var mult := Label.new()
        mult.text = "×%.1f к силе" % LabData.get_star_stat_mult(stars)
        mult.add_theme_font_override("font", BunkerUI.font_mono())
        mult.add_theme_font_size_override("font_size", 13)
        mult.add_theme_color_override("font_color", BunkerUI.HAZARD)
        mult.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        v.add_child(mult)

        card.pressed.connect(_on_farm_card_selected.bind(type))
        card.mouse_entered.connect(_play_hover_sound)
        return card


func _on_farm_card_selected(type: String):
        _play_click_sound()
        _farm_selected = type
        _farm_mode = "cards"
        _rebuild_farm_panel()


## Одна строка «ключ — значение» алтаря
func _make_altar_kv(k: String, v: String, vcol: Color = BunkerUI.TEXT_LIGHT) -> HBoxContainer:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        var kl := BunkerUI.make_mono_label(k, 14, Color("a9bd8d"))
        kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(kl)
        var vl := BunkerUI.make_mono_label(v, 14, vcol)
        vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        row.add_child(vl)
        return row


func _rebuild_farm_altar():
        """АЛТАРЬ ЗВЁЗД справа: выбранный питомец, бак, кнопки прокачки без выхода"""
        for child in _farm_altar_box.get_children():
                child.queue_free()
        if _farm_selected.is_empty() or lab_data == null or lab_data.unlocked_mutants.is_empty():
                return

        var head := Label.new()
        head.text = "АЛТАРЬ ЗВЁЗД"
        head.add_theme_font_override("font", BunkerUI.font_title())
        head.add_theme_font_size_override("font_size", 24)
        head.add_theme_color_override("font_color", BunkerUI.HAZARD)
        head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _farm_altar_box.add_child(head)

        var sub := Label.new()
        sub.text = "прокачка без выхода с фермы"
        sub.add_theme_font_override("font", BunkerUI.font_body())
        sub.add_theme_font_size_override("font_size", 13)
        sub.add_theme_color_override("font_color", Color("7d8f6a"))
        sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _farm_altar_box.add_child(sub)

        var type := _farm_selected
        var stars: int = lab_data.get_mutant_stars(type)
        var req: Dictionary = game_manager.get_star_requirements(type) if game_manager else {}
        var rar: String = GachaData.get_mutant_rarity(type)
        var rcol: Color = BunkerUI.RARHEX.get(rar, BunkerUI.TEXT)

        # Круг питомца
        var big := Panel.new()
        big.custom_minimum_size = Vector2(140, 140)
        big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        var bsb := StyleBoxFlat.new()
        bsb.set_corner_radius_all(70)
        bsb.bg_color = Color(0.06, 0.09, 0.045)
        bsb.border_color = Color(rcol, 0.7)
        bsb.set_border_width_all(2)
        bsb.shadow_color = Color(rcol, 0.25)
        bsb.shadow_size = 26
        bsb.shadow_offset = Vector2.ZERO
        big.add_theme_stylebox_override("panel", bsb)
        _farm_altar_box.add_child(big)

        var big_l := Label.new()
        big_l.set_anchors_preset(Control.PRESET_FULL_RECT)
        big_l.text = GachaData.display_name(type).substr(0, 1)
        big_l.add_theme_font_override("font", BunkerUI.font_title())
        big_l.add_theme_font_size_override("font_size", 64)
        big_l.add_theme_color_override("font_color", Color(rcol, 0.6))
        big_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        big_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        big.add_child(big_l)

        var big_st := Label.new()
        if stars >= LabData.MAX_STARS:
                big_st.text = "★".repeat(LabData.MAX_STARS)
        else:
                big_st.text = "★".repeat(stars) + "☆".repeat(LabData.MAX_STARS - stars)
        big_st.add_theme_font_override("font", BunkerUI.font_mono())
        big_st.add_theme_font_size_override("font_size", 17)
        big_st.add_theme_color_override("font_color", Color("ffd94d"))
        big_st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _farm_altar_box.add_child(big_st)

        # Характеристики
        var next_mult: float = LabData.get_star_stat_mult(mini(stars + 1, LabData.MAX_STARS))
        _farm_altar_box.add_child(_make_altar_kv("Мутант", GachaData.display_name(type).to_upper(), rcol))
        _farm_altar_box.add_child(_make_altar_kv("Сила отряда", "×%.1f → ×%.1f" % [LabData.get_star_stat_mult(stars), next_mult]))
        _farm_altar_box.add_child(_make_altar_kv("Бонус звезды", "+%d%% статов" % roundi(LabData.STAR_STAT_BONUS * 100.0), Color("a8ff7a")))

        # Бак прогресс
        if stars < LabData.MAX_STARS:
                var feed_cost: int = GachaData.get_star_feed_cost(stars)
                var bar := ProgressBar.new()
                bar.max_value = maxi(feed_cost, 1)
                bar.value = lab_data.get_star_progress(type)
                bar.show_percentage = false
                bar.custom_minimum_size = Vector2(0, 12)
                var bbg := StyleBoxFlat.new()
                bbg.bg_color = Color(0.03, 0.045, 0.024)
                bbg.border_color = BunkerUI.STEEL_EDGE
                bbg.set_border_width_all(1)
                bbg.set_corner_radius_all(6)
                var bfill := StyleBoxFlat.new()
                bfill.bg_color = Color("8dff5a")
                bfill.set_corner_radius_all(6)
                bar.add_theme_stylebox_override("background", bbg)
                bar.add_theme_stylebox_override("fill", bfill)
                _farm_altar_box.add_child(bar)

                var bak_lbl := BunkerUI.make_mono_label(
                        "ЗВЁЗДНЫЙ БАК %d/%d" % [lab_data.get_star_progress(type), feed_cost],
                        13, Color("a8ff7a"))
                bak_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                _farm_altar_box.add_child(bak_lbl)

                # Копии/корм для рецепта
                if not req.is_empty():
                        _farm_altar_box.add_child(_make_altar_kv(
                                "Копии цели",
                                "%d/%d" % [int(req.get("copies_have", 0)), int(req.get("copies_need", 0))],
                                Color("e8f5d0") if int(req.get("copies_have", 0)) >= int(req.get("copies_need", 0)) else BunkerUI.HAZARD))
                        _farm_altar_box.add_child(_make_altar_kv(
                                "Простой корм",
                                "%d/%d" % [int(req.get("simple_have", 0)), int(req.get("simple_need", 0))],
                                Color("e8f5d0") if int(req.get("simple_have", 0)) >= int(req.get("simple_need", 0)) else BunkerUI.HAZARD))
        else:
                var maxl := Label.new()
                maxl.text = "МАКСИМУМ ЗВЁЗД"
                maxl.add_theme_font_override("font", BunkerUI.font_title())
                maxl.add_theme_font_size_override("font_size", 18)
                maxl.add_theme_color_override("font_color", Color("ffd94d"))
                maxl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                _farm_altar_box.add_child(maxl)

        var push := Control.new()
        push.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _farm_altar_box.add_child(push)

        # Кнопки: собрать рецепт (существующий диалог поверх фермы) + кормить
        if stars < LabData.MAX_STARS:
                var up_btn := Button.new()
                up_btn.text = "СОБРАТЬ РЕЦЕПТ · ★%d" % (stars + 1)
                up_btn.custom_minimum_size = Vector2(0, 58)
                BunkerUI.style_button(up_btn, "hazard", 19, true)
                up_btn.pressed.connect(_on_farm_upgrade.bind(type))
                up_btn.mouse_entered.connect(_play_hover_sound)
                _farm_altar_box.add_child(up_btn)

        if lab_data.get_farm_copies(type) > 0 and stars < LabData.MAX_STARS:
                var feed_btn := Button.new()
                feed_btn.text = "КОРМИТЬ (выбрать копию-корм)"
                feed_btn.custom_minimum_size = Vector2(0, 48)
                BunkerUI.style_button(feed_btn, "steel", 15)
                feed_btn.pressed.connect(_on_farm_feed_pressed.bind(type))
                feed_btn.mouse_entered.connect(_play_hover_sound)
                _farm_altar_box.add_child(feed_btn)


func _rebuild_farm_panel():
        """Карточки питомцев + алтарь. Режимы: cards / feed_pick / кормление / утилизация"""
        for child in farm_list.get_children():
                child.queue_free()
        if not lab_data:
                return
        if _farm_biomass_chip:
                _farm_biomass_chip.text = _format_number(lab_data.biomass)
        if _farm_rolls_chip:
                _farm_rolls_chip.text = str(lab_data.gacha_rolls_mutants)
        _farm_altar_panel.visible = _farm_mode == "cards" and _feed_fodder.is_empty() and not _recycle_mode
        var cards_mode: bool = _farm_mode == "cards" and _feed_fodder.is_empty() and not _recycle_mode
        _farm_cards_scroll.visible = cards_mode
        _farm_modes_scroll.visible = not cards_mode

        # Режим кормления: выбор цели для выбранного корма
        if not _feed_fodder.is_empty():
                var fodder_type: String = _feed_fodder[0]
                var fodder_stars: int = lab_data.get_mutant_stars(fodder_type)
                farm_list.add_child(_make_farm_section("ВЫБЕРИТЕ, КОГО КОРМИТЬ (%s)" % Loc.type_name(fodder_type).to_upper()))
                var cancel := Button.new()
                cancel.text = Loc.t("lab.back")
                cancel.custom_minimum_size = Vector2(0, 40)
                BunkerUI.style_button(cancel, "steel", 15)
                cancel.pressed.connect(_on_feed_cancel)
                farm_list.add_child(cancel)
                var found := false
                for type in lab_data.unlocked_mutants:
                        if type == fodder_type or lab_data.get_farm_copies(type) <= 0:
                                continue
                        found = true
                        var t_stars: int = lab_data.get_mutant_stars(type)
                        var to_star_bucket: bool = fodder_stars == t_stars and lab_data.get_star_feed(type) < 1
                        var row := HBoxContainer.new()
                        row.add_theme_constant_override("separation", 10)
                        row.add_child(_make_icon_rect(type, true, 30))
                        var name_label := Label.new()
                        name_label.text = "%s  %s   (%s)" % [
                                Loc.type_name(type), LabData.stars_text(t_stars),
                                Loc.t("farm.progress", {"cur": lab_data.get_star_progress(type), "need": GachaData.get_star_feed_cost(t_stars)})]
                        name_label.add_theme_color_override("font_color", Color("ffd94d") if to_star_bucket else BunkerUI.TEXT)
                        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                        row.add_child(name_label)
                        var mark := BunkerUI.make_mono_label("→ ЗВЁЗДНЫЙ БАК" if to_star_bucket else "→ ПРОСТОЙ КОРМ", 12,
                                Color("ffd94d") if to_star_bucket else Color("8ba06e"))
                        row.add_child(mark)
                        var btn := Button.new()
                        btn.text = "КОРМИТЬ"
                        btn.custom_minimum_size = Vector2(130, 40)
                        BunkerUI.style_button(btn, "primary", 14)
                        btn.pressed.connect(_on_feed_confirm.bind(type))
                        row.add_child(btn)
                        farm_list.add_child(row)
                if not found:
                        var none := Label.new()
                        none.text = Loc.t("farm.empty")
                        farm_list.add_child(none)
                return

        # Режим утилизации
        if _recycle_mode:
                _rebuild_farm_recycle()
                return

        # Режим «кормовая грелка»: выбрать копию-корм
        if _farm_mode == "feed_pick":
                farm_list.add_child(_make_farm_section("КОРМОВАЯ ГРЕЛКА — ВЫБЕРИТЕ КОПИЮ-КОРМ"))
                var cancel2 := Button.new()
                cancel2.text = Loc.t("lab.back")
                cancel2.custom_minimum_size = Vector2(0, 40)
                BunkerUI.style_button(cancel2, "steel", 15)
                cancel2.pressed.connect(func():
                        _farm_mode = "cards"
                        _rebuild_farm_panel())
                farm_list.add_child(cancel2)
                var any_fodder := false
                for type in lab_data.unlocked_mutants:
                        if lab_data.get_farm_copies(type) <= 0:
                                continue
                        any_fodder = true
                        var row2 := HBoxContainer.new()
                        row2.add_theme_constant_override("separation", 10)
                        row2.add_child(_make_icon_rect(type, true, 30))
                        var lbl := Label.new()
                        lbl.text = "%s  %s  ·  копий: %d" % [Loc.type_name(type), LabData.stars_text(lab_data.get_mutant_stars(type)), lab_data.get_farm_copies(type)]
                        lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                        row2.add_child(lbl)
                        var pick := Button.new()
                        pick.text = "КОРМИТЬ ЭТОЙ"
                        pick.custom_minimum_size = Vector2(170, 40)
                        BunkerUI.style_button(pick, "steel", 13)
                        pick.pressed.connect(_on_farm_feed_pressed.bind(type))
                        row2.add_child(pick)
                        farm_list.add_child(row2)
                if not any_fodder:
                        var empty2 := Label.new()
                        empty2.text = Loc.t("farm.empty")
                        farm_list.add_child(empty2)
                return

        # Обычный режим: карточки питомцев в ряд
        for child in _farm_cards_box.get_children():
                child.queue_free()
        for type in lab_data.unlocked_mutants:
                _farm_cards_box.add_child(_make_farm_card(str(type)))
        if lab_data.unlocked_mutants.is_empty():
                var empty3 := Label.new()
                empty3.text = Loc.t("farm.empty")
                _farm_cards_box.add_child(empty3)

        _rebuild_farm_altar()


func _make_farm_section(text: String) -> Label:
        var label := Label.new()
        label.text = text
        label.add_theme_font_override("font", BunkerUI.font_title())
        label.add_theme_font_size_override("font_size", 16)
        label.add_theme_color_override("font_color", BunkerUI.HAZARD)
        return label


func _on_farm_feed_pressed(type: String):
        _play_click_sound()
        _feed_fodder = [type]
        _farm_mode = "cards"
        _rebuild_farm_panel()


func _on_feed_cancel():
        _play_click_sound()
        _feed_fodder.clear()
        _rebuild_farm_panel()


func _on_feed_confirm(target_type: String):
        _play_click_sound()
        var msg: String = game_manager.feed_fodder(_feed_fodder[0], target_type)
        _show_message(msg, 2.0)
        _feed_fodder.clear()
        _rebuild_farm_panel()
        _refresh_ui()


# ==================== ЯЗЫК ====================

var _lang_button: Button = null


func _build_language_button():
        """Кнопка RU/EN в настройках лаборатории"""
        var panel = get_node_or_null("SettingsScreen/Panel")
        if not panel:
                return
        _lang_button = Button.new()
        _lang_button.text = Loc.t("menu.language")
        _lang_button.position = Vector2(30, 262)
        _lang_button.size = Vector2(340, 34)
        _lang_button.pressed.connect(_on_language_pressed)
        _lang_button.mouse_entered.connect(_play_hover_sound)
        panel.add_child(_lang_button)


func _on_language_pressed():
        _play_click_sound()
        Loc.toggle()


# ==================== ГАЧА ====================

var gacha_panel: Control
var gacha_list: VBoxContainer
# Сессионная статистика шансов: [всего, common, uncommon, rare, legendary]
var _mutant_spin_stats: Array = [0, 0, 0, 0, 0]
var _artifact_spin_stats: Array = [0, 0, 0, 0, 0]
# Последние дропы для показа
var _mutant_last_drops: Array = []
var _artifact_last_drops: Array = []


func _build_gacha_ui():
        """ДЕКА ГАЧИ (БУНКЕР): большая жёлтая 3D-кнопка ГАЧА ЗОНЫ + пластины круток.
        Гача - ОТДЕЛЬНЫЙ полноэкранный узел: change_scene("gacha")."""
        var vbox: VBoxContainer = get_node_or_null("VBox")
        if vbox:
                var deck := PanelContainer.new()
                deck.name = "GachaDeck"
                vbox.add_child(deck)
                vbox.move_child(deck, 3)

                var dk := HBoxContainer.new()
                dk.name = "DeckRow"
                dk.add_theme_constant_override("separation", 16)
                deck.add_child(dk)

                var gacha_btn := Button.new()
                gacha_btn.name = "GachaButton"
                gacha_btn.text = Loc.t("gacha.bunker_entry")
                gacha_btn.custom_minimum_size = Vector2(320, 84)
                BunkerUI.style_button(gacha_btn, "hazard", 24, true)
                gacha_btn.pressed.connect(_on_gacha_pressed)
                gacha_btn.mouse_entered.connect(_play_hover_sound)
                dk.add_child(gacha_btn)

                var mut_plate := BunkerUI.make_plate("0", Loc.t("gacha.plate_mut_rolls"))
                mut_plate.name = "MutRollsPlate"
                dk.add_child(mut_plate)
                var art_plate := BunkerUI.make_plate("0", Loc.t("gacha.plate_art_rolls"))
                art_plate.name = "ArtRollsPlate"
                dk.add_child(art_plate)

                var hint := Label.new()
                hint.name = "GachaHint"
                hint.text = Loc.t("gacha.deck_hint")
                hint.add_theme_font_override("font", BunkerUI.font_body())
                hint.add_theme_font_size_override("font_size", 15)
                hint.add_theme_color_override("font_color", BunkerUI.TEXT_DIM)
                hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
                hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
                dk.add_child(hint)

        # Старая панель круток не используется (гача - отдельная сцена),
        # оставляем скрытую заглушку для совместимости старых ссылок.
        gacha_panel = Control.new()
        gacha_panel.name = "GachaPanel"
        gacha_panel.visible = false
        add_child(gacha_panel)


func _on_gacha_pressed():
        _play_click_sound()
        if not game_manager:
                game_manager = get_tree().get_first_node_in_group("game_manager")
        if game_manager:
                game_manager.change_scene("gacha")


func _on_gacha_close_pressed():
        _play_click_sound()
        gacha_panel.visible = false


func _gacha_spin_buttons(kind: String) -> Control:
        """Ряд кнопок круток x1/x10/x100/x1000"""
        var row := HBoxContainer.new()
        for times in [1, 10, 100, 1000]:
                var btn := Button.new()
                btn.text = "x%d" % times
                btn.custom_minimum_size = Vector2(70, 30)
                btn.pressed.connect(_on_gacha_spin.bind(kind, times))
                btn.mouse_entered.connect(_play_hover_sound)
                row.add_child(btn)
        return row


func _on_gacha_spin(kind: String, times: int):
        _play_click_sound()
        var results: Array = []
        if kind == "mutants":
                results = game_manager.spin_mutant_gacha(times)
                for r in results:
                        _mutant_spin_stats[0] += 1
                        var idx: int = {"common": 1, "uncommon": 2, "rare": 3, "legendary": 4}.get(str(r.get("rarity")), 1)
                        _mutant_spin_stats[idx] += 1
                        _mutant_last_drops.push_front(r)
                        while _mutant_last_drops.size() > 8:
                                _mutant_last_drops.pop_back()
        else:
                results = game_manager.spin_artifact_gacha(times)
                for r in results:
                        _artifact_spin_stats[0] += 1
                        var idx: int = {"common": 1, "uncommon": 2, "rare": 3, "legendary": 4}.get(str(r.get("rarity")), 1)
                        _artifact_spin_stats[idx] += 1
                        _artifact_last_drops.push_front(r)
                        while _artifact_last_drops.size() > 8:
                                _artifact_last_drops.pop_back()
        if results.is_empty():
                _show_message(Loc.t("gacha.no_rolls"), 1.5)
        _rebuild_gacha_panel()
        _refresh_ui()


func _make_drop_row(r: Dictionary, is_mutant: bool) -> Control:
        """Строка дропа гачи: карточка-иконка + имя, окрашенное по редкости"""
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 6)
        row.add_child(_make_icon_rect(str(r.get("type", "")), is_mutant, 24))
        var label := Label.new()
        label.text = _format_drop(r)
        label.add_theme_color_override("font_color", GachaData.rarity_color(str(r.get("rarity", "common"))))
        return row


func _format_drop(r: Dictionary) -> String:
        var rarity: String = str(r.get("rarity", "common"))
        var line: String = "[%s] %s" % [Loc.t("rarity." + rarity), Loc.type_name(str(r.get("type")))]
        match str(r.get("status", "")):
                "new":
                        line += " - " + Loc.t("gacha.new_mark")
                "dup":
                        line += " - " + Loc.t("gacha.dup_mark")
                "star":
                        line += " - " + Loc.t("gacha.star_mark")
        return line


func _gacha_stats_line(stats: Array, has_uncommon: bool) -> String:
        var total: int = stats[0]
        if total <= 0:
                return ""
        var pct := func(n: int) -> String:
                return "%.1f" % (100.0 * float(n) / float(total))
        if has_uncommon:
                return Loc.t("gacha.stats", {"n": total, "cp": pct.call(stats[1]), "up": pct.call(stats[2]), "rp": pct.call(stats[3]), "lp": pct.call(stats[4])})
        return Loc.t("gacha.stats_short", {"n": total, "cp": pct.call(stats[1]), "rp": pct.call(stats[3]), "lp": pct.call(stats[4])})


func _rebuild_gacha_panel():
        """Два рукава гачи: крутки, кнопки, статистика шансов, последние дропы"""
        for child in gacha_list.get_children():
                child.queue_free()
        if not lab_data or not game_manager:
                return

        var level_line := Label.new()
        level_line.text = Loc.t("gacha.level_used", {"n": game_manager.get_campaign_level()})
        gacha_list.add_child(level_line)

        # === МУТАНТЫ ===
        gacha_list.add_child(_make_star_section(Loc.t("gacha.mutants_header")))
        var mut_rolls := Label.new()
        mut_rolls.text = Loc.t("gacha.rolls", {"n": lab_data.gacha_rolls_mutants})
        gacha_list.add_child(mut_rolls)
        gacha_list.add_child(_gacha_spin_buttons("mutants"))
        var mut_stats := Label.new()
        mut_stats.text = _gacha_stats_line(_mutant_spin_stats, true)
        if not mut_stats.text.is_empty():
                gacha_list.add_child(mut_stats)
        if not _mutant_last_drops.is_empty():
                gacha_list.add_child(_make_star_section(Loc.t("gacha.last_drops")))
                for r in _mutant_last_drops:
                        gacha_list.add_child(_make_drop_row(r, true))

        # === АРТЕФАКТЫ ===
        gacha_list.add_child(_make_star_section(Loc.t("gacha.artifacts_header")))
        var art_rolls := Label.new()
        art_rolls.text = Loc.t("gacha.rolls", {"n": lab_data.gacha_rolls_artifacts})
        gacha_list.add_child(art_rolls)
        gacha_list.add_child(_gacha_spin_buttons("artifacts"))
        var art_stats := Label.new()
        art_stats.text = _gacha_stats_line(_artifact_spin_stats, false)
        if not art_stats.text.is_empty():
                gacha_list.add_child(art_stats)
        if not _artifact_last_drops.is_empty():
                gacha_list.add_child(_make_star_section(Loc.t("gacha.last_drops")))
                for r in _artifact_last_drops:
                        gacha_list.add_child(_make_drop_row(r, false))


# ==================== ГАЛЕРЕЯ ====================

var gallery_panel: Control
var gallery_list: VBoxContainer


func _build_profile_ui():
        """Кнопка ПРОФИЛЬ: терминал «Сканер личности» — отдельная сцена
        (как гача): аватары из коллекции, рамки/титулы/статусы за прогресс."""
        var bottom: HBoxContainer = get_node_or_null("VBox/BottomButtons")
        if bottom:
                var prof_btn := Button.new()
                prof_btn.name = "ProfileButton"
                prof_btn.text = Loc.t("profile.title_btn")
                prof_btn.custom_minimum_size = Vector2(0, 62)
                prof_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                BunkerUI.style_button(prof_btn, "steel", 18)
                prof_btn.pressed.connect(_on_profile_pressed)
                prof_btn.mouse_entered.connect(_play_hover_sound)
                bottom.add_child(prof_btn)


func _on_profile_pressed():
        _play_click_sound()
        if not game_manager:
                game_manager = get_tree().get_first_node_in_group("game_manager")
        if game_manager:
                game_manager.change_scene("profile")


func _build_gallery_ui():
        """Кнопка ГАЛЕРЕЯ + панель коллекции: открытые цветные, закрытые серые"""
        var bottom: HBoxContainer = get_node_or_null("VBox/BottomButtons")
        if bottom:
                var gal_btn := Button.new()
                gal_btn.name = "GalleryButton"
                gal_btn.text = Loc.t("lab.gallery")
                gal_btn.custom_minimum_size = Vector2(0, 62)
                gal_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                BunkerUI.style_button(gal_btn, "steel", 18)
                gal_btn.pressed.connect(_on_gallery_pressed)
                gal_btn.mouse_entered.connect(_play_hover_sound)
                bottom.add_child(gal_btn)

        gallery_panel = Control.new()
        gallery_panel.name = "GalleryPanel"
        gallery_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
        gallery_panel.mouse_filter = Control.MOUSE_FILTER_STOP
        gallery_panel.visible = false
        add_child(gallery_panel)

        var shade := ColorRect.new()
        shade.set_anchors_preset(Control.PRESET_FULL_RECT)
        shade.color = Color(0, 0, 0, 0.6)
        gallery_panel.add_child(shade)

        var panel := Panel.new()
        panel.anchor_left = 0.5
        panel.anchor_top = 0.5
        panel.anchor_right = 0.5
        panel.anchor_bottom = 0.5
        panel.offset_left = -280.0
        panel.offset_top = -210.0
        panel.offset_right = 280.0
        panel.offset_bottom = 210.0
        gallery_panel.add_child(panel)

        var title := Label.new()
        title.text = Loc.t("gallery.title")
        title.position = Vector2(0, 10)
        title.size = Vector2(560, 25)
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        panel.add_child(title)

        var scroll := ScrollContainer.new()
        scroll.position = Vector2(20, 44)
        scroll.size = Vector2(520, 308)
        panel.add_child(scroll)

        gallery_list = VBoxContainer.new()
        gallery_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        gallery_list.add_theme_constant_override("separation", 6)
        scroll.add_child(gallery_list)

        var close_btn := Button.new()
        close_btn.text = Loc.t("lab.back")
        close_btn.position = Vector2(200, 362)
        close_btn.size = Vector2(160, 35)
        close_btn.pressed.connect(_on_gallery_close_pressed)
        close_btn.mouse_entered.connect(_play_hover_sound)
        panel.add_child(close_btn)


func _on_gallery_pressed():
        _play_click_sound()
        _hide_lab_overlays("")
        gallery_panel.visible = true
        _rebuild_gallery_panel()


func _on_gallery_close_pressed():
        _play_click_sound()
        gallery_panel.visible = false


func _gallery_tile(type: String, is_mutant: bool) -> Control:
        """Плитка карточки: цветная если открыто, серая если нет"""
        var unlocked: bool = lab_data.unlocked_mutants.has(type) if is_mutant else lab_data.won_artifacts.has(type)
        var tile := VBoxContainer.new()
        tile.custom_minimum_size = Vector2(82, 0)
        tile.add_theme_constant_override("separation", 2)
        tile.alignment = BoxContainer.ALIGNMENT_BEGIN

        var rect := TextureRect.new()
        rect.texture = load(GachaData.card_icon_path(type, is_mutant, not unlocked))
        rect.custom_minimum_size = Vector2(72, 72)
        rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        if not unlocked:
                rect.modulate = Color(0.85, 0.85, 0.9, 0.9)
        tile.add_child(rect)

        var name_label := Label.new()
        name_label.text = Loc.type_name(type)
        name_label.add_theme_font_size_override("font_size", 9)
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
        name_label.custom_minimum_size = Vector2(82, 0)
        name_label.add_theme_color_override("font_color", GachaData.rarity_color(GachaData.get_artifact_rarity(type) if not is_mutant else GachaData.get_mutant_rarity(type)) if unlocked else Color(0.5, 0.5, 0.55))
        tile.add_child(name_label)

        var stars_label := Label.new()
        var stars: int = lab_data.get_mutant_stars(type) if is_mutant else lab_data.get_artifact_stars(type)
        stars_label.text = LabData.stars_text(stars) if unlocked else "🔒"
        stars_label.add_theme_font_size_override("font_size", 9)
        stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        stars_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.25) if unlocked else Color(0.5, 0.5, 0.55))
        tile.add_child(stars_label)

        var unlock_level: int = GachaData.get_unlock_campaign_level(type)
        tile.tooltip_text = Loc.t("gallery.unlocked_tip") if unlocked else Loc.t("gallery.locked_tip", {"n": unlock_level})
        tile.mouse_filter = Control.MOUSE_FILTER_STOP
        tile.gui_input.connect(_on_gallery_tile_input.bind(type, is_mutant, unlocked))
        return tile


func _on_gallery_tile_input(event: InputEvent, type: String, is_mutant: bool, unlocked: bool):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
                _play_click_sound()
                _show_card_detail(type, is_mutant, unlocked)


# ==================== КАРТОЧКА-ПРОСМОТР ====================

var detail_panel: Control
var detail_image: TextureRect
var detail_name: Label
var detail_meta: Label
var detail_desc: Label


func _build_card_detail():
        """Большая карточка: арт художника (PNG) + описание. Открывается кликом по плитке"""
        detail_panel = Control.new()
        detail_panel.name = "CardDetail"
        detail_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
        detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
        detail_panel.visible = false
        add_child(detail_panel)

        var shade := ColorRect.new()
        shade.set_anchors_preset(Control.PRESET_FULL_RECT)
        shade.color = Color(0, 0, 0, 0.7)
        shade.gui_input.connect(func(ev):
                if ev is InputEventMouseButton and ev.pressed:
                        detail_panel.visible = false)
        detail_panel.add_child(shade)

        var panel := Panel.new()
        panel.anchor_left = 0.5
        panel.anchor_top = 0.5
        panel.anchor_right = 0.5
        panel.anchor_bottom = 0.5
        panel.offset_left = -230.0
        panel.offset_top = -230.0
        panel.offset_right = 230.0
        panel.offset_bottom = 230.0
        detail_panel.add_child(panel)

        detail_image = TextureRect.new()
        detail_image.position = Vector2(110, 16)
        detail_image.size = Vector2(240, 240)
        detail_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        detail_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        panel.add_child(detail_image)

        detail_name = Label.new()
        detail_name.position = Vector2(20, 262)
        detail_name.size = Vector2(420, 26)
        detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        detail_name.add_theme_font_size_override("font_size", 17)
        panel.add_child(detail_name)

        detail_meta = Label.new()
        detail_meta.position = Vector2(20, 290)
        detail_meta.size = Vector2(420, 20)
        detail_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        detail_meta.add_theme_font_size_override("font_size", 11)
        panel.add_child(detail_meta)

        detail_desc = Label.new()
        detail_desc.position = Vector2(30, 318)
        detail_desc.size = Vector2(400, 90)
        detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
        detail_desc.add_theme_font_size_override("font_size", 11)
        detail_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        panel.add_child(detail_desc)

        var close := Button.new()
        close.text = Loc.t("lab.back")
        close.position = Vector2(150, 412)
        close.size = Vector2(160, 34)
        close.pressed.connect(func(): _play_click_sound(); detail_panel.visible = false)
        panel.add_child(close)


func _show_card_detail(type: String, is_mutant: bool, unlocked: bool):
        """Заполнить карточку: большой арт (PNG художника или SVG), имя, редкость,
        звёзды, описание, открываемая аномалия"""
        if not detail_panel:
                _build_card_detail()
        var rarity: String = GachaData.get_mutant_rarity(type) if is_mutant else GachaData.get_artifact_rarity(type)
        var rarity_color: Color = GachaData.rarity_color(rarity)

        detail_image.texture = load(GachaData.card_icon_path(type, is_mutant, not unlocked))
        detail_image.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.85, 0.85, 0.9, 0.9)

        detail_name.text = Loc.type_name(type)
        detail_name.add_theme_color_override("font_color", rarity_color if unlocked else Color(0.6, 0.6, 0.65))

        var meta_parts: Array[String] = [Loc.t("card.rarity", {"r": Loc.t("rarity." + rarity)})]
        if unlocked:
                var stars: int = lab_data.get_mutant_stars(type) if is_mutant else lab_data.get_artifact_stars(type)
                meta_parts.append("%s %s" % [LabData.stars_text(stars), Loc.t("stars.mult_tip", {"n": "%.1f" % LabData.get_star_stat_mult(stars)})])
        else:
                meta_parts.append(Loc.t("card.locked"))
        if not is_mutant:
                var anomaly: String = GachaData.get_anomaly_for_artifact(type)
                if not anomaly.is_empty():
                        meta_parts.append(Loc.t("card.opens_anomaly", {"n": Loc.t("an." + _anomaly_loc_key(anomaly))}))
        detail_meta.text = "   ".join(meta_parts)
        detail_meta.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))

        detail_desc.text = Loc.t("desc." + type)
        detail_panel.visible = true


## anomaly_type "heat_anomaly" -> ключ локализации "heat"
func _anomaly_loc_key(anomaly_type: String) -> String:
        var key: String = anomaly_type
        for suf in ["gravity_", "thermal_", "chemical_", "electric_", "bio_"]:
                key = key.trim_prefix(suf)
        key = key.trim_suffix("_anomaly")
        match key:
                "radiation_hotspot":
                        key = "radiation"
                "time_dilation":
                        key = "time"
                "teleport":
                        key = "teleport"
                "acid_cloud":
                        key = "acid_cloud"
        return key


func _rebuild_gallery_panel():
        """Все мутанты и арты: открытые цветные, закрытые серые силуэты"""
        for child in gallery_list.get_children():
                child.queue_free()
        if not lab_data:
                return

        gallery_list.add_child(_make_farm_section(Loc.t("lab.mutants")))
        var mut_grid := GridContainer.new()
        mut_grid.columns = 6
        mut_grid.add_theme_constant_override("h_separation", 4)
        mut_grid.add_theme_constant_override("v_separation", 4)
        gallery_list.add_child(mut_grid)
        for entry in GachaData.MUTANT_POOL.values():
                for e in entry:
                        mut_grid.add_child(_gallery_tile(str(e[0]), true))

        gallery_list.add_child(_gallery_section(" "))
        gallery_list.add_child(_gallery_section(Loc.t("shop.artifacts_header").split(" (")[0]))
        var art_grid := GridContainer.new()
        art_grid.columns = 6
        art_grid.add_theme_constant_override("h_separation", 4)
        art_grid.add_theme_constant_override("v_separation", 4)
        gallery_list.add_child(art_grid)
        for rarity in GachaData.ARTIFACT_POOL.values():
                for type in rarity:
                        art_grid.add_child(_gallery_tile(str(type), false))


func _gallery_section(text: String) -> Label:
        var label := Label.new()
        label.text = text
        return label


# ==================== ДИАЛОГ ПОВЫШЕНИЯ ЗВЕЗДЫ ====================

var up_panel: Control
var up_title: Label
var up_body: VBoxContainer
# Состояние сбора рецепта
var _up_target: String = ""
var _up_copies: int = 0
var _up_star_feed: String = ""
var _up_simple: Dictionary = {}
var _up_chooser: String = ""  # "" | "star" | "simple"


func _build_upgrade_dialog():
        """Окно повышения: слоты копий/звёздного/простого корма с '+', ОК применяет"""
        up_panel = Control.new()
        up_panel.name = "UpgradeStarDialog"
        up_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
        up_panel.mouse_filter = Control.MOUSE_FILTER_STOP
        up_panel.visible = false
        add_child(up_panel)

        var shade := ColorRect.new()
        shade.set_anchors_preset(Control.PRESET_FULL_RECT)
        shade.color = Color(0, 0, 0, 0.7)
        shade.gui_input.connect(func(ev):
                if ev is InputEventMouseButton and ev.pressed:
                        _close_upgrade_dialog())
        up_panel.add_child(shade)

        var panel := Panel.new()
        panel.anchor_left = 0.5
        panel.anchor_top = 0.5
        panel.anchor_right = 0.5
        panel.anchor_bottom = 0.5
        panel.offset_left = -240.0
        panel.offset_top = -210.0
        panel.offset_right = 240.0
        panel.offset_bottom = 210.0
        up_panel.add_child(panel)

        up_title = Label.new()
        up_title.position = Vector2(20, 12)
        up_title.size = Vector2(440, 24)
        up_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        up_title.add_theme_font_size_override("font_size", 14)
        panel.add_child(up_title)

        var scroll := ScrollContainer.new()
        scroll.position = Vector2(20, 44)
        scroll.size = Vector2(440, 300)
        panel.add_child(scroll)

        up_body = VBoxContainer.new()
        up_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        up_body.add_theme_constant_override("separation", 6)
        scroll.add_child(up_body)

        var back := Button.new()
        back.text = Loc.t("lab.back")
        back.position = Vector2(160, 356)
        back.size = Vector2(160, 34)
        back.pressed.connect(_close_upgrade_dialog)
        panel.add_child(back)


func _on_farm_upgrade(type: String):
        """↑N★ - открыть окно сбора рецепта по этому мутанту (ПОВЕРХ фермы)"""
        _play_click_sound()
        _up_target = type
        _up_copies = 0
        _up_star_feed = ""
        _up_simple.clear()
        _up_chooser = ""
        if not up_panel:
                _build_upgrade_dialog()
        # Ферму НЕ прячем: алтарь звёзд живёт внутри фермы, диалог рисуется поверх
        up_panel.visible = true
        _rebuild_upgrade_dialog()


func _close_upgrade_dialog():
        up_panel.visible = false
        _up_target = ""
        _up_chooser = ""


func _up_remaining_simple() -> int:
        var req: Dictionary = game_manager.get_star_requirements(_up_target)
        return maxi(0, int(req.get("simple_need")) - int(req.get("simple_have")))


func _up_pending_simple_total() -> int:
        var total := 0
        for t in _up_simple:
                total += int(_up_simple[t])
        return total


func _rebuild_upgrade_dialog():
        for child in up_body.get_children():
                child.queue_free()
        if _up_target.is_empty():
                return
        var lab = get_tree().get_first_node_in_group("game_manager").get_lab_data()
        var stars: int = lab.get_mutant_stars(_up_target)
        var req: Dictionary = game_manager.get_star_requirements(_up_target)
        up_title.text = Loc.t("up.title", {"name": Loc.type_name(_up_target), "n": stars + 1})

        # Режим выбора корма
        if _up_chooser != "":
                _rebuild_upgrade_chooser()
                return

        # --- Слот 1: копии цели ---
        var copies_row := HBoxContainer.new()
        copies_row.add_theme_constant_override("separation", 6)
        var copies_label := Label.new()
        var copies_have: int = int(req.get("copies_have"))
        copies_label.text = Loc.t("up.copies_slot", {"have": _up_copies, "need": copies_have})
        copies_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        copies_row.add_child(copies_label)
        if _up_copies < stars + 1:
                var add_copies := Button.new()
                add_copies.text = Loc.t("up.copies_btn", {"n": stars + 1})
                add_copies.tooltip_text = Loc.t("up.copies_slot", {"have": copies_have, "need": stars + 1})
                add_copies.pressed.connect(_on_up_add_copies.bind(stars + 1))
                copies_row.add_child(add_copies)
        elif _up_copies > 0:
                var done1 := Label.new()
                done1.text = Loc.t("up.done_mark")
                copies_row.add_child(done1)
        up_body.add_child(copies_row)

        # --- Слот 2: звёздный корм ---
        var star_row := HBoxContainer.new()
        star_row.add_theme_constant_override("separation", 6)
        var star_label := Label.new()
        var star_text: String = Loc.t("up.star_slot", {"n": stars})
        if int(req.get("star_have")) >= 1:
                star_text += Loc.t("up.star_filled")
        elif not _up_star_feed.is_empty():
                star_text += Loc.type_name(_up_star_feed)
        star_label.text = star_text
        star_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        star_row.add_child(star_label)
        if int(req.get("star_have")) < 1:
                var add_star := Button.new()
                add_star.text = Loc.t("farm.star_btn")
                add_star.pressed.connect(_on_up_pick_star)
                star_row.add_child(add_star)
        up_body.add_child(star_row)

        # --- Слот 3: простой корм ---
        var simple_row := HBoxContainer.new()
        simple_row.add_theme_constant_override("separation", 6)
        var simple_label := Label.new()
        var simple_total: int = int(req.get("simple_have")) + _up_pending_simple_total()
        var simple_text: String = Loc.t("up.simple_slot", {"have": simple_total, "need": int(req.get("simple_need"))})
        var parts := []
        for t in _up_simple:
                parts.append("%s x%d" % [Loc.type_name(str(t)), int(_up_simple[t])])
        if not parts.is_empty():
                simple_text += "   " + " · ".join(parts)
        simple_label.text = simple_text
        simple_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        simple_row.add_child(simple_label)
        var add_simple := Button.new()
        add_simple.text = Loc.t("farm.star_btn")
        add_simple.pressed.connect(_on_up_pick_simple)
        simple_row.add_child(add_simple)
        if not _up_simple.is_empty():
                var reset_btn := Button.new()
                reset_btn.text = Loc.t("up.reset")
                reset_btn.pressed.connect(_on_up_reset_simple)
                simple_row.add_child(reset_btn)
        up_body.add_child(simple_row)

        # --- АВТО: заполнить всё из слабых и многочисленных ---
        var auto_btn := Button.new()
        auto_btn.text = Loc.t("up.auto")
        auto_btn.custom_minimum_size = Vector2(0, 34)
        auto_btn.pressed.connect(_on_up_auto)
        up_body.add_child(auto_btn)

        # --- ОК ---
        var ok_btn := Button.new()
        ok_btn.text = Loc.t("up.ok")
        ok_btn.custom_minimum_size = Vector2(0, 40)
        var copies_need: int = stars + 1
        var has_enough: bool = _up_copies >= copies_need and (int(req.get("star_have")) >= 1 or not _up_star_feed.is_empty()) and simple_total >= int(req.get("simple_need"))
        ok_btn.disabled = not has_enough
        ok_btn.pressed.connect(_on_up_confirm)
        up_body.add_child(ok_btn)
        if not ready:
                var hint := Label.new()
                hint.text = Loc.t("up.not_ready")
                hint.add_theme_font_size_override("font_size", 9)
                hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                up_body.add_child(hint)


func _on_up_add_copies(max_copies: int):
        _play_click_sound()
        # Кламп к потребности рецепта: лишние копии не сжигаем
        var stars: int = game_manager.get_lab_data().get_mutant_stars(_up_target)
        _up_copies = mini(max_copies, stars + 1)
        _rebuild_upgrade_dialog()


func _on_up_pick_star():
        _play_click_sound()
        _up_chooser = "star"
        _rebuild_upgrade_dialog()


func _on_up_pick_simple():
        _play_click_sound()
        _up_chooser = "simple"
        _rebuild_upgrade_dialog()


func _on_up_reset_simple():
        _play_click_sound()
        _up_simple.clear()
        _rebuild_upgrade_dialog()


func _on_up_confirm():
        _play_click_sound()
        var msg: String = game_manager.apply_star_recipe(_up_target, _up_copies, _up_star_feed, _up_simple)
        _show_message(msg, 2.0)
        _close_upgrade_dialog()
        _rebuild_farm_panel()
        _refresh_ui()


func _rebuild_upgrade_chooser():
        var lab = get_tree().get_first_node_in_group("game_manager").get_lab_data()
        var target_stars: int = lab.get_mutant_stars(_up_target)
        var header := Label.new()
        if _up_chooser == "star":
                header.text = Loc.t("up.pick_star", {"n": target_stars})
        else:
                header.text = Loc.t("up.pick_simple")
        up_body.add_child(header)

        var found := false
        for type in lab.unlocked_mutants:
                if type == _up_target or lab.get_farm_copies(type) <= 0:
                        continue
                var t_stars: int = lab.get_mutant_stars(type)
                if _up_chooser == "star" and t_stars != target_stars:
                        continue
                found = true
                var row := HBoxContainer.new()
                row.add_theme_constant_override("separation", 6)
                row.add_child(_make_icon_rect(type, true, 26))
                var name_label := Label.new()
                name_label.text = "%s %s - %s" % [Loc.type_name(type), LabData.stars_text(t_stars), Loc.t("farm.copies", {"n": lab.get_farm_copies(type)})]
                name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                row.add_child(name_label)
                if _up_chooser == "star":
                        var pick := Button.new()
                        pick.text = Loc.t("up.ok").replace("★ ", "")
                        pick.pressed.connect(_on_up_choose_star.bind(type))
                        row.add_child(pick)
                else:
                        var available: int = lab.get_farm_copies(type)
                        var remaining: int = _up_remaining_simple() - _up_pending_simple_total()
                        for qty in [1, 5]:
                                if qty <= available and qty <= remaining:
                                        var q_btn := Button.new()
                                        q_btn.text = "+%d" % qty
                                        q_btn.pressed.connect(_on_up_choose_simple.bind(type, qty))
                                        row.add_child(q_btn)
                        if available > 0 and remaining > 0:
                                var max_btn := Button.new()
                                max_btn.text = Loc.t("up.qty_max")
                                max_btn.pressed.connect(_on_up_choose_simple.bind(type, mini(available, remaining)))
                                row.add_child(max_btn)
                up_body.add_child(row)
        # Копии самого мутанта тоже годятся в корм (бюджет проверит ОК)
        var self_copies: int = lab.get_farm_copies(_up_target)
        var self_ok := false
        if self_copies > 0:
                if _up_chooser == "simple":
                        self_ok = true
                elif _up_chooser == "star" and target_stars == lab.get_mutant_stars(_up_target):
                        self_ok = true  # цель всегда своей звёздности
        if self_ok:
                var srow := HBoxContainer.new()
                srow.add_theme_constant_override("separation", 6)
                srow.add_child(_make_icon_rect(_up_target, true, 26))
                var slabel := Label.new()
                slabel.text = "%s %s - %s %s" % [Loc.type_name(_up_target), LabData.stars_text(lab.get_mutant_stars(_up_target)), Loc.t("farm.copies", {"n": self_copies}), Loc.t("up.self_mark")]
                slabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                srow.add_child(slabel)
                if _up_chooser == "star":
                        var pick := Button.new()
                        pick.text = Loc.t("up.ok").replace("★ ", "")
                        pick.pressed.connect(_on_up_choose_star.bind(_up_target))
                        srow.add_child(pick)
                else:
                        var available: int = lab.get_farm_copies(_up_target)
                        var remaining: int = _up_remaining_simple() - _up_pending_simple_total()
                        for qty in [1, 5]:
                                if qty <= available and qty <= remaining:
                                        var q_btn := Button.new()
                                        q_btn.text = "+%d" % qty
                                        q_btn.pressed.connect(_on_up_choose_simple.bind(_up_target, qty))
                                        srow.add_child(q_btn)
                        if available > 0 and remaining > 0:
                                var max_btn := Button.new()
                                max_btn.text = Loc.t("up.qty_max")
                                max_btn.pressed.connect(_on_up_choose_simple.bind(_up_target, mini(available, remaining)))
                                srow.add_child(max_btn)
                up_body.add_child(srow)
                found = true
        if not found:
                var none := Label.new()
                none.text = Loc.t("farm.empty")
                up_body.add_child(none)

        var cancel := Button.new()
        cancel.text = Loc.t("lab.back")
        cancel.pressed.connect(_on_up_cancel_chooser)
        up_body.add_child(cancel)


func _on_up_choose_star(type: String):
        _play_click_sound()
        _up_star_feed = type
        _up_chooser = ""
        _rebuild_upgrade_dialog()


func _on_up_choose_simple(type: String, qty: int):
        _play_click_sound()
        _up_simple[type] = int(_up_simple.get(type, 0)) + qty
        # Если больше нечего выбирать - вернуться к слотам
        var lab = get_tree().get_first_node_in_group("game_manager").get_lab_data()
        var remaining: int = _up_remaining_simple() - _up_pending_simple_total()
        var any_left := false
        for t in lab.unlocked_mutants:
                if t != _up_target and lab.get_farm_copies(t) > 0:
                        any_left = true
                        break
        if remaining <= 0 or not any_left:
                _up_chooser = ""
        _rebuild_upgrade_dialog()


func _on_up_cancel_chooser():
        _play_click_sound()
        _up_chooser = ""
        _rebuild_upgrade_dialog()


## АВТО: копии цели + слабейший звёздный корм + простой корм из 1★ по запасам
func _on_up_auto():
        _play_click_sound()
        var lab = game_manager.get_lab_data()
        if _up_target.is_empty():
                return
        var stars: int = lab.get_mutant_stars(_up_target)
        var req: Dictionary = game_manager.get_star_requirements(_up_target)

        # 1. Копии цели - ровно потребность (не больше, лишние копии не сжигаем)
        _up_copies = mini(int(req.get("copies_have")), stars + 1)

        # 2. Звёздный корм: чужие той же звёздности; если их нет - копии самого типа
        if int(req.get("star_have")) < 1:
                var cands: Array[String] = []
                for t in lab.unlocked_mutants:
                        if t != _up_target and lab.get_mutant_stars(t) == stars and lab.get_farm_copies(t) > 0:
                                cands.append(str(t))
                cands.sort_custom(func(a, b):
                        var ca: int = lab.get_farm_copies(a)
                        var cb: int = lab.get_farm_copies(b)
                        if ca != cb:
                                return ca > cb
                        return GachaData.get_fodder_value(a, true) < GachaData.get_fodder_value(b, true))
                if not cands.is_empty():
                        _up_star_feed = cands[0]
                elif lab.get_farm_copies(_up_target) > _up_copies:
                        _up_star_feed = _up_target  # свои копии в звёздный бак

        # 3. Простой корм: сначала 1★-кормовые по запасам, затем прочие не-звёздные
        var remaining: int = _up_remaining_simple() - _up_pending_simple_total()
        var simple_cands: Array[String] = []
        var other_cands: Array[String] = []
        for t in lab.unlocked_mutants:
                if t == _up_target or t == _up_star_feed or lab.get_farm_copies(t) <= 0:
                        continue
                if lab.get_mutant_stars(t) == 1:
                        simple_cands.append(str(t))
                elif lab.get_mutant_stars(t) != stars:
                        other_cands.append(str(t))
        simple_cands.sort_custom(func(a, b):
                var ca: int = lab.get_farm_copies(a)
                var cb: int = lab.get_farm_copies(b)
                if ca != cb:
                        return ca > cb
                return GachaData.get_fodder_value(a, true) < GachaData.get_fodder_value(b, true))
        other_cands.sort_custom(func(a, b):
                var ca: int = lab.get_farm_copies(a)
                var cb: int = lab.get_farm_copies(b)
                if ca != cb:
                        return ca > cb
                return GachaData.get_fodder_value(a, true) < GachaData.get_fodder_value(b, true))
        for t in simple_cands + other_cands:
                if remaining <= 0:
                        break
                var take: int = mini(lab.get_farm_copies(t), remaining)
                if take > 0:
                        _up_simple[t] = int(_up_simple.get(t, 0)) + take
                        remaining -= take
        # Резерв: копии самого мутанта (не занятые слотом копий и звёздным)
        if remaining > 0:
                var self_used: int = int(_up_simple.get(_up_target, 0))
                if _up_star_feed == _up_target:
                        self_used += 1
                var spare: int = lab.get_farm_copies(_up_target) - _up_copies - self_used
                if spare > 0:
                        _up_simple[_up_target] = int(_up_simple.get(_up_target, 0)) + mini(spare, remaining)

        _rebuild_upgrade_dialog()


# ==================== УТИЛИЗАЦИЯ КОПИЙ ====================

var _recycle_mode: bool = false
var _recycle_batch: Dictionary = {}


func _on_recycle_pressed():
        _play_click_sound()
        _recycle_mode = true
        _recycle_batch.clear()
        _rebuild_farm_panel()


func _on_recycle_cancel():
        _play_click_sound()
        _recycle_mode = false
        _recycle_batch.clear()
        _rebuild_farm_panel()


func _recycle_pending_points() -> int:
        var points: int = 0
        for t in _recycle_batch:
                points += GachaData.get_fodder_value(str(t), true) * int(_recycle_batch[t])
        return points


func _rebuild_farm_recycle():
        """Сдача копий: очки по редкости, 10 очков = 1 крутка артефактов"""
        for child in farm_list.get_children():
                child.queue_free()
        if not lab_data:
                return

        var pending: int = _recycle_pending_points()
        var total: int = lab_data.recycle_points + pending
        var header := Label.new()
        header.text = Loc.t("farm.recycle_title")
        farm_list.add_child(header)
        var progress := Label.new()
        progress.text = Loc.t("farm.recycle_progress", {"points": total % 10 if total < 10 else 10, "consumed": pending, "left": lab_data.recycle_points})
        progress.add_theme_font_size_override("font_size", 10)
        farm_list.add_child(progress)
        # Прогресс полосой
        var bar := ProgressBar.new()
        bar.min_value = 0
        bar.max_value = 10
        bar.value = total % 10
        bar.custom_minimum_size = Vector2(0, 16)
        farm_list.add_child(bar)
        # Уже гарантированные крутки из партии
        var ready_rolls := int(total / 10.0)
        if ready_rolls > 0:
                var ready_label := Label.new()
                ready_label.text = Loc.t("farm.recycle_confirm", {"n": ready_rolls})
                ready_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.25))
                farm_list.add_child(ready_label)

        var found := false
        for type in lab_data.unlocked_mutants:
                var copies: int = lab_data.get_farm_copies(type)
                if copies <= 0:
                        continue
                found = true
                var row := HBoxContainer.new()
                row.add_theme_constant_override("separation", 6)
                row.add_child(_make_icon_rect(type, true, 26))
                var name_label := Label.new()
                var value: int = GachaData.get_fodder_value(type, true)
                name_label.text = "%s - %s (+%d)" % [Loc.type_name(type), Loc.t("farm.copies", {"n": copies}), value]
                name_label.tooltip_text = Loc.t("farm.value_tip", {"points": value})
                name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                row.add_child(name_label)
                var pending_n: int = int(_recycle_batch.get(type, 0))
                if pending_n > 0:
                        var mark := Label.new()
                        mark.text = "x%d" % pending_n
                        mark.add_theme_color_override("font_color", Color(1.0, 0.72, 0.25))
                        row.add_child(mark)
                for qty in [1, 5, 10]:
                        if qty <= copies:
                                var q_btn := Button.new()
                                q_btn.text = "+%d" % qty
                                q_btn.pressed.connect(_on_recycle_add.bind(type, qty))
                                row.add_child(q_btn)
                if pending_n > 0:
                        var sub_btn := Button.new()
                        sub_btn.text = "-%d" % pending_n
                        sub_btn.pressed.connect(_on_recycle_remove.bind(type))
                        row.add_child(sub_btn)
                farm_list.add_child(row)
        if not found:
                var none := Label.new()
                none.text = Loc.t("farm.recycle_nothing")
                farm_list.add_child(none)

        var confirm := Button.new()
        confirm.text = Loc.t("farm.recycle_confirm", {"n": ready_rolls})
        confirm.disabled = ready_rolls <= 0
        confirm.custom_minimum_size = Vector2(0, 36)
        confirm.pressed.connect(_on_recycle_confirm)
        farm_list.add_child(confirm)

        var cancel := Button.new()
        cancel.text = Loc.t("lab.back")
        cancel.pressed.connect(_on_recycle_cancel)
        farm_list.add_child(cancel)


func _on_recycle_add(type: String, qty: int):
        _play_click_sound()
        _recycle_batch[type] = int(_recycle_batch.get(type, 0)) + qty
        _rebuild_farm_panel()


func _on_recycle_remove(type: String):
        _play_click_sound()
        _recycle_batch.erase(type)
        _rebuild_farm_panel()


func _on_recycle_confirm():
        _play_click_sound()
        var result: Dictionary = game_manager.recycle_copies(_recycle_batch)
        if int(result.get("rolls", 0)) > 0:
                _show_message(Loc.t("farm.recycle_done", {"n": int(result.get("rolls", 0)), "c": int(result.get("consumed", 0))}), 2.5)
        else:
                _show_message(Loc.t("farm.recycle_zero"), 1.5)
        _recycle_batch.clear()
        _rebuild_farm_panel()
        _refresh_ui()


# ==================== СТИЛЬ БУНКЕР ====================

func _apply_bunker_style():
        """Тема и декорации БУНКЕР для лаборатории (вариант 4)."""
        BunkerUI.apply_bunker(self, true)

        # Заголовок шапки
        var title: Label = get_node_or_null("VBox/Header/Title")
        if title:
                title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
                title.add_theme_font_override("font", BunkerUI.font_title())
                title.add_theme_font_size_override("font_size", 26)
                title.add_theme_color_override("font_color", BunkerUI.TEXT_LIGHT)
        var run_no: Label = get_node_or_null("VBox/Header/RunNumber")
        if run_no:
                run_no.add_theme_font_override("font", BunkerUI.font_mono())
                run_no.add_theme_font_size_override("font_size", 17)
                run_no.add_theme_color_override("font_color", BunkerUI.HAZARD_BRIGHT)

        # Старт забега - большая зелёная 3D-кнопка
        start_run_button.custom_minimum_size = Vector2(340, 62)
        BunkerUI.style_button(start_run_button, "primary", 20, true)

        # Станции - стальные панели с жёлтым уровнем
        for st in [anomaly_station, mutant_station, monolith_station]:
                BunkerUI.style_button(st, "steel", 16)
                var nm: Label = st.get_node_or_null("StationName")
                if nm:
                        nm.add_theme_font_override("font", BunkerUI.font_body())
                        nm.add_theme_font_size_override("font_size", 19)
                        nm.add_theme_color_override("font_color", BunkerUI.TEXT_BRIGHT)
                var lv: Label = st.get_node_or_null("StationLevel")
                if lv:
                        lv.add_theme_font_override("font", BunkerUI.font_mono())
                        lv.add_theme_font_size_override("font_size", 14)
                        lv.add_theme_color_override("font_color", BunkerUI.HAZARD)

        # Рядовые кнопки - сталь
        for b in [menu_button, settings_button, shop_button, save_button, artifact_storage_button]:
                BunkerUI.style_button(b, "steel", 16)


func _refresh_gacha_deck():
        """Пластины круток в деке гачи."""
        var deck: PanelContainer = get_node_or_null("VBox/GachaDeck")
        if deck == null or lab_data == null:
                return
        var mut_plate: PanelContainer = deck.get_node_or_null("DeckRow/MutRollsPlate")
        if mut_plate:
                var mut_label: Label = mut_plate.get_child(0).get_child(0)
                mut_label.text = _rolls_lab_text(lab_data.gacha_rolls_mutants)
        var art_plate: PanelContainer = deck.get_node_or_null("DeckRow/ArtRollsPlate")
        if art_plate:
                var art_label: Label = art_plate.get_child(0).get_child(0)
                art_label.text = str(lab_data.gacha_rolls_artifacts)


func _rolls_lab_text(n: int) -> String:
        return "∞" if n >= 1000000 else str(n)


func _apply_bunker_layout_sizes():
        """Компактные размеры рядов в духе макета: станции ниже, статистика дышит."""
        var stations_row: HBoxContainer = get_node_or_null("VBox/Stations")
        if stations_row:
                stations_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
                stations_row.custom_minimum_size = Vector2(0, 170)


# ==================== АРЕНА ВЫЖИВАНИЯ (макет «АРЕНА») ====================
# Полноэкранная арена: вызовы соперников (бот-отряды), сезон, награды, вкладки.
# «Вызов» запускает забег Выживания против конфигурации соперника.

var arena_panel: Control
var _arena_board_box: VBoxContainer
var _arena_foes_box: VBoxContainer
var _arena_timer_label: Label
var _arena_tab: int = 0
var _arena_season_timer: Timer
var _arena_rivals: Array = []
var _arena_season_label: Label = null
var _arena_rank_label: Label = null
var _arena_rank_sub: Label = null
var _arena_bless_label: Label = null
var defense_panel: Control = null
var _defense_list_box: VBoxContainer = null
var _defense_power_label: Label = null


func _build_arena_ui():
        """Кнопка АРЕНА + полноэкранная арена выживания (строится кодом)"""
        var bottom: HBoxContainer = get_node_or_null("VBox/BottomButtons")
        if bottom:
                var arena_btn := Button.new()
                arena_btn.name = "ArenaButton"
                arena_btn.text = "АРЕНА"
                arena_btn.custom_minimum_size = Vector2(0, 62)
                arena_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                BunkerUI.style_button(arena_btn, "steel", 18)
                arena_btn.pressed.connect(_on_arena_pressed)
                arena_btn.mouse_entered.connect(_play_hover_sound)
                bottom.add_child(arena_btn)

        arena_panel = Control.new()
        arena_panel.name = "ArenaPanel"
        arena_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
        arena_panel.mouse_filter = Control.MOUSE_FILTER_STOP
        arena_panel.visible = false
        add_child(arena_panel)

        var bg := ColorRect.new()
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.color = Color(0.023, 0.033, 0.018, 0.985)
        arena_panel.add_child(bg)

        var root := VBoxContainer.new()
        root.set_anchors_preset(Control.PRESET_FULL_RECT)
        root.offset_left = 30
        root.offset_right = -30
        root.offset_top = 16
        root.offset_bottom = -14
        root.add_theme_constant_override("separation", 10)
        arena_panel.add_child(root)

        # ---- Шапка: НАЗАД + заголовок + сезон + место + таймер ----
        var head := HBoxContainer.new()
        head.add_theme_constant_override("separation", 18)
        root.add_child(head)

        var back := Button.new()
        back.name = "ArenaBackButton"
        back.text = "◄  НАЗАД"
        back.custom_minimum_size = Vector2(180, 56)
        back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        BunkerUI.style_button(back, "steel", 18)
        back.pressed.connect(_on_arena_close_pressed)
        back.mouse_entered.connect(_play_hover_sound)
        head.add_child(back)

        var t1 := Label.new()
        t1.text = "АРЕНА"
        t1.add_theme_font_override("font", BunkerUI.font_title())
        t1.add_theme_font_size_override("font_size", 34)
        t1.add_theme_color_override("font_color", BunkerUI.TEXT_LIGHT)
        head.add_child(t1)
        var t2 := Label.new()
        t2.text = "ВЫЖИВАНИЯ"
        t2.add_theme_font_override("font", BunkerUI.font_title())
        t2.add_theme_font_size_override("font_size", 34)
        t2.add_theme_color_override("font_color", BunkerUI.DANGER_HI)
        head.add_child(t2)

        var season := PanelContainer.new()
        season.add_theme_stylebox_override("panel", BunkerUI.steel())
        var sv := VBoxContainer.new()
        sv.add_theme_constant_override("separation", 0)
        var sa := Label.new()
        sa.text = "ВЫБРОС I"
        sa.add_theme_font_override("font", BunkerUI.font_title())
        sa.add_theme_font_size_override("font_size", 18)
        sa.add_theme_color_override("font_color", BunkerUI.HAZARD)
        sa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        var sb := Label.new()
        _arena_season_label = sb
        sb.text = "сезон %d · лига «САРКОФАГ»" % _arena_season_number()
        sb.add_theme_font_override("font", BunkerUI.font_mono())
        sb.add_theme_font_size_override("font_size", 12)
        sb.add_theme_color_override("font_color", BunkerUI.TEXT_DIM)
        sb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        sv.add_child(sa)
        sv.add_child(sb)
        season.add_child(sv)
        head.add_child(season)

        var sp0 := Control.new()
        sp0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        head.add_child(sp0)

        var rank := PanelContainer.new()
        var rsb := StyleBoxFlat.new()
        rsb.bg_color = Color(0.10, 0.082, 0.03)
        rsb.border_color = Color("8a6d1e")
        rsb.set_border_width_all(1)
        rsb.set_corner_radius_all(8)
        rsb.content_margin_left = 16.0
        rsb.content_margin_right = 16.0
        rsb.content_margin_top = 6.0
        rsb.content_margin_bottom = 6.0
        rank.add_theme_stylebox_override("panel", rsb)
        var rv := VBoxContainer.new()
        rv.add_theme_constant_override("separation", 0)
        var r1 := Label.new()
        _arena_rank_label = r1
        r1.text = "— МЕСТО"
        r1.add_theme_font_override("font", BunkerUI.font_title())
        r1.add_theme_font_size_override("font_size", 18)
        r1.add_theme_color_override("font_color", Color("ffd94d"))
        r1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        var r2 := Label.new()
        _arena_rank_sub = r2
        r2.text = "зона повышения"
        r2.add_theme_font_override("font", BunkerUI.font_mono())
        r2.add_theme_font_size_override("font_size", 11)
        r2.add_theme_color_override("font_color", Color("9a8349"))
        r2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        rv.add_child(r1)
        rv.add_child(r2)
        rank.add_child(rv)
        head.add_child(rank)

        var tv := VBoxContainer.new()
        tv.add_theme_constant_override("separation", 0)
        _arena_timer_label = BunkerUI.make_mono_label("00:00:00", 24, BunkerUI.GREEN)
        _arena_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        var tl := BunkerUI.make_mono_label("ДО КОНЦА СЕЗОНА", 11, BunkerUI.TEXT_FAINT)
        tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        tv.add_child(_arena_timer_label)
        tv.add_child(tl)
        head.add_child(tv)

        # ---- Тело: список вызовов (лево) + доска (право) ----
        var body := HBoxContainer.new()
        body.size_flags_vertical = Control.SIZE_EXPAND_FILL
        body.add_theme_constant_override("separation", 16)
        root.add_child(body)

        var list_scroll := ScrollContainer.new()
        list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        body.add_child(list_scroll)

        _arena_foes_box = VBoxContainer.new()
        _arena_foes_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _arena_foes_box.add_theme_constant_override("separation", 10)
        list_scroll.add_child(_arena_foes_box)

        var side := VBoxContainer.new()
        side.custom_minimum_size = Vector2(520, 0)
        side.add_theme_constant_override("separation", 10)
        body.add_child(side)

        var board := PanelContainer.new()
        board.size_flags_vertical = Control.SIZE_EXPAND_FILL
        side.add_child(board)
        _arena_board_box = VBoxContainer.new()
        _arena_board_box.add_theme_constant_override("separation", 6)
        board.add_child(_arena_board_box)

        var bless := PanelContainer.new()
        var bsb2 := StyleBoxFlat.new()
        bsb2.bg_color = Color(0.10, 0.082, 0.03)
        bsb2.border_color = Color("8a6d1e")
        bsb2.set_border_width_all(1)
        bsb2.set_corner_radius_all(10)
        bsb2.content_margin_left = 16.0
        bsb2.content_margin_right = 16.0
        bsb2.content_margin_top = 10.0
        bsb2.content_margin_bottom = 10.0
        bless.add_theme_stylebox_override("panel", bsb2)
        var bl := Label.new()
        _arena_bless_label = bl
        bl.text = "Благословение сезона: +10% биомассы с волн выживания и +1 крутка за каждую 5-ю победу в вызове."
        bl.add_theme_font_override("font", BunkerUI.font_body())
        bl.add_theme_font_size_override("font_size", 14)
        bl.add_theme_color_override("font_color", Color("c9b06a"))
        bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        bless.add_child(bl)
        side.add_child(bless)

        var quick := HBoxContainer.new()
        quick.add_theme_constant_override("separation", 12)
        side.add_child(quick)
        var q1 := Button.new()
        q1.text = "▶  БЫСТРЫЙ ВЫЗОВ"
        q1.custom_minimum_size = Vector2(0, 60)
        q1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        BunkerUI.style_button(q1, "hazard", 17, true)
        q1.pressed.connect(_on_arena_challenge.bind("БЫСТРЫЙ ВЫЗОВ"))
        q1.mouse_entered.connect(_play_hover_sound)
        quick.add_child(q1)
        var q2 := Button.new()
        q2.text = "СМЕНА ОБОРОНЫ"
        q2.custom_minimum_size = Vector2(0, 60)
        q2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        BunkerUI.style_button(q2, "steel", 15)
        q2.pressed.connect(_on_defense_open_pressed)
        q2.mouse_entered.connect(_play_hover_sound)
        quick.add_child(q2)

        # ---- Вкладки ----
        var tabs := HBoxContainer.new()
        tabs.add_theme_constant_override("separation", 8)
        root.add_child(tabs)
        var tab_names := ["НАГРАДЫ", "ЗАЛ СЛАВЫ", "ОТЧЁТЫ БОЁВ", "ЗАЩИТНЫЙ ОТРЯД", "ЗАДАЧИ СЕЗОНА"]
        for i in range(tab_names.size()):
                var tb := Button.new()
                tb.text = tab_names[i]
                tb.custom_minimum_size = Vector2(0, 50)
                tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                BunkerUI.style_button(tb, "steel", 14)
                tb.pressed.connect(_on_arena_tab.bind(i))
                tb.mouse_entered.connect(_play_hover_sound)
                tabs.add_child(tb)

        # Таймер сезона
        _arena_season_timer = Timer.new()
        _arena_season_timer.wait_time = 1.0
        _arena_season_timer.timeout.connect(_update_arena_timer)
        arena_panel.add_child(_arena_season_timer)

        _build_defense_ui()


func _on_arena_pressed():
        _play_click_sound()
        _hide_lab_overlays("arena")
        arena_panel.visible = true
        _arena_tab = 0
        _rebuild_arena_panel()
        _update_arena_timer()
        _arena_season_timer.start()


func _on_arena_close_pressed():
        _play_click_sound()
        arena_panel.visible = false
        _arena_season_timer.stop()


## Сила отряда игрока (арена): звёзды питомцев + рекорд выживания
func _arena_player_power() -> int:
        var power := 1200
        if lab_data:
                for t in lab_data.unlocked_mutants:
                        power += 340 * lab_data.get_mutant_stars(str(t))
                        power += 15 * lab_data.get_farm_copies(str(t))
        var rec := 0
        if statistics:
                rec = statistics.best_survival_wave
        power += rec * 45
        return power


## Десять символических соперников: фиксированная лестница Зоны.
## Цифры НЕ привязаны к игроку — их нужно просто превзойти, снизу вверх:
## КРОТ (старт, 4 волны) -> ШТЫРЬ -> БАРМЕН -> ДЕГТЯРЁВ -> КЛЫК -> ЛУЧНИК
## -> ПРИЗРАК -> ВОЛК -> СТРЕЛОК -> МЕЧЕНЫЙ (топ лиги, волна 50).
func _arena_make_rivals() -> Array:
        var defs := [
                ["МЕЧЕНЫЙ", "«Легенда Зоны»", 21500, 50, "Химера"],
                ["СТРЕЛОК", "«Легенда Зоны»", 17800, 44, "Псевдогигант"],
                ["ВОЛК", "«Долг»", 14400, 38, "Кровосос"],
                ["ПРИЗРАК", "«Свобода»", 11500, 32, "Полтергейст"],
                ["ЛУЧНИК", "«Наёмники»", 9100, 26, "Контролёр"],
                ["КЛЫК", "«Наёмники»", 7100, 21, "Псевдопёс"],
                ["ДЕГТЯРЁВ", "«Долг»", 5200, 16, "Кровосос"],
                ["БАРМЕН", "«Долг»", 3800, 12, "Снорк"],
                ["ШТЫРЬ", "«Одиночки»", 2400, 8, "Псевдопёс"],
                ["КРОТ", "«Одиночки»", 1100, 4, "Снорк"],
        ]
        var out: Array = []
        for d in defs:
                out.append({
                        "name": str(d[0]), "clan": str(d[1]),
                        "power": int(d[2]), "wave": int(d[3]),
                        "pet": str(d[4])
                })
        return out


func _make_arena_foe_row(foe: Dictionary, is_me: bool) -> Control:
        var row := PanelContainer.new()
        var sb := StyleBoxFlat.new()
        sb.bg_color = Color(0.062, 0.086, 0.041)
        sb.border_color = BunkerUI.HAZARD if is_me else BunkerUI.STEEL_EDGE
        sb.set_border_width_all(2)
        sb.set_corner_radius_all(10)
        sb.content_margin_left = 18.0
        sb.content_margin_right = 18.0
        sb.content_margin_top = 10.0
        sb.content_margin_bottom = 10.0
        if is_me:
                sb.shadow_color = Color(BunkerUI.HAZARD, 0.35)
                sb.shadow_size = 16
                sb.shadow_offset = Vector2.ZERO
        row.add_theme_stylebox_override("panel", sb)

        var h := HBoxContainer.new()
        h.add_theme_constant_override("separation", 16)
        row.add_child(h)

        # Круг-аватар
        var ava := Panel.new()
        ava.custom_minimum_size = Vector2(64, 64)
        ava.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        var asb := StyleBoxFlat.new()
        asb.set_corner_radius_all(32)
        asb.bg_color = Color(0.06, 0.09, 0.045)
        asb.border_color = BunkerUI.HAZARD if is_me else Color("4a5c2e")
        asb.set_border_width_all(2)
        ava.add_theme_stylebox_override("panel", asb)
        var al := Label.new()
        al.set_anchors_preset(Control.PRESET_FULL_RECT)
        al.text = "Я" if is_me else str(foe.get("name", "?")).substr(0, 1)
        al.add_theme_font_override("font", BunkerUI.font_title())
        al.add_theme_font_size_override("font_size", 28)
        al.add_theme_color_override("font_color", Color("ffd94d") if is_me else Color(0.9, 1.0, 0.8, 0.3))
        al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        al.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        ava.add_child(al)
        h.add_child(ava)

        # Кто
        var who := VBoxContainer.new()
        who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        who.alignment = BoxContainer.ALIGNMENT_CENTER
        who.add_theme_constant_override("separation", 0)
        var nm := Label.new()
        nm.text = "СТАЛКЕР" if is_me else str(foe.get("name", ""))
        nm.add_theme_font_override("font", BunkerUI.font_title())
        nm.add_theme_font_size_override("font_size", 19)
        nm.add_theme_color_override("font_color", Color("ffd94d") if is_me else BunkerUI.TEXT_LIGHT)
        who.add_child(nm)
        var cl := Label.new()
        if is_me:
                var mcount := 0
                if lab_data:
                        mcount = lab_data.unlocked_mutants.size()
                cl.text = "в обороне %d из %d мутантов" % [lab_data.arena_defense_squad.size(), mcount]
        else:
                cl.text = "%s · %s в отряде" % [str(foe.get("clan", "")), str(foe.get("pet", ""))]
        cl.add_theme_font_override("font", BunkerUI.font_body())
        cl.add_theme_font_size_override("font_size", 13)
        cl.add_theme_color_override("font_color", BunkerUI.TEXT_DIM)
        who.add_child(cl)
        h.add_child(who)

        # Сила
        var pw := VBoxContainer.new()
        pw.add_theme_constant_override("separation", 0)
        var pv := BunkerUI.make_mono_label(_format_number(float(foe.get("power", 0))), 20, BunkerUI.GREEN)
        pv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        var pl2 := BunkerUI.make_mono_label("СИЛА", 11, BunkerUI.TEXT_FAINT)
        pl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        pw.add_child(pv)
        pw.add_child(pl2)
        h.add_child(pw)

        # Волна
        var wv := VBoxContainer.new()
        wv.add_theme_constant_override("separation", 0)
        var rec := 0
        if statistics:
                rec = statistics.best_survival_wave
        var wv_val: int = rec if is_me else int(foe.get("wave", 1))
        var wv1 := BunkerUI.make_mono_label(str(wv_val), 20, BunkerUI.DANGER_HI)
        wv1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        var wv2 := BunkerUI.make_mono_label("ВОЛНА", 11, BunkerUI.TEXT_FAINT)
        wv2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        wv.add_child(wv1)
        wv.add_child(wv2)
        h.add_child(wv)

        # Кнопка
        var call_btn := Button.new()
        call_btn.custom_minimum_size = Vector2(170, 50)
        call_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        if is_me:
                call_btn.text = "ОБОРОНА"
                BunkerUI.style_button(call_btn, "ghost", 15)
                call_btn.pressed.connect(_on_arena_defend_run_pressed)
        else:
                call_btn.text = "ВЫЗОВ"
                BunkerUI.style_button(call_btn, "hazard", 16, true)
                call_btn.pressed.connect(_on_arena_challenge.bind(str(foe.get("name", ""))))
        call_btn.mouse_entered.connect(_play_hover_sound)
        h.add_child(call_btn)
        return row


func _make_arena_board_row(k: String, v: String, gold: bool = false) -> Control:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        var kl := BunkerUI.make_mono_label(k, 15, Color("a9bd8d"))
        kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(kl)
        var vl := BunkerUI.make_mono_label(v, 15, Color("ffd94d") if gold else BunkerUI.TEXT_LIGHT)
        vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        row.add_child(vl)
        var line := ColorRect.new()
        line.custom_minimum_size = Vector2(0, 1)
        line.color = Color(BunkerUI.STEEL_EDGE, 0.6)
        var wrap := VBoxContainer.new()
        wrap.add_theme_constant_override("separation", 2)
        wrap.add_child(row)
        wrap.add_child(line)
        return wrap


func _rebuild_arena_panel():
        """Список вызовов + доска по активной вкладке"""
        for child in _arena_foes_box.get_children():
                child.queue_free()
        for child in _arena_board_box.get_children():
                child.queue_free()
        if not lab_data:
                return

        _arena_rivals = _arena_make_rivals()
        _arena_foes_box.add_child(_make_arena_foe_row({"power": _arena_player_power()}, true))
        for foe in _arena_rivals:
                _arena_foes_box.add_child(_make_arena_foe_row(foe, false))

        var rec := 0
        var total_runs := 0
        var wins := 0
        var losses := 0
        var kills := 0
        if statistics:
                rec = statistics.best_survival_wave
                total_runs = statistics.total_runs
                wins = statistics.wins
                losses = statistics.losses
                kills = statistics.stalkers_killed

        # Зал славы: сортировка по реальной силе, моё место
        var board: Array = _arena_rivals.duplicate()
        board.append({"name": "СТАЛКЕР (ВЫ)", "power": _arena_player_power(), "wave": rec})
        board.sort_custom(func(a, b): return int(a.get("power", 0)) > int(b.get("power", 0)))
        var my_place := 1
        for i in range(board.size()):
                if str(board[i].get("name", "")).begins_with("СТАЛКЕР"):
                        my_place = i + 1
                        break

        # Живая шапка: сезон, место, благословение
        if _arena_season_label:
                _arena_season_label.text = "сезон %d · лига «САРКОФАГ»" % _arena_season_number()
        if _arena_rank_label:
                _arena_rank_label.text = "%d МЕСТО" % my_place
        if _arena_rank_sub:
                _arena_rank_sub.text = "зона повышения" if my_place <= 2 else "закрепись в топ-2"
        if _arena_bless_label:
                var wins_total: int = lab_data.arena_wins_challenge + lab_data.arena_wins_defense
                var to_spin: int = 5 - (wins_total % 5)
                _arena_bless_label.text = "Благословение сезона: +10%% биомассы с волн выживания и +1 крутка за каждую 5-ю победу в вызове. Побед: %d · до крутки: %d" % [wins_total, to_spin]

        var title := Label.new()
        title.add_theme_font_override("font", BunkerUI.font_title())
        title.add_theme_font_size_override("font_size", 19)
        title.add_theme_color_override("font_color", BunkerUI.GREEN)
        _arena_board_box.add_child(title)

        match _arena_tab:
                0:
                        var medals := _arena_medals(my_place)
                        var done_count := 0
                        for m in medals:
                                if bool(m[3]):
                                        done_count += 1
                        title.text = "СЕЗОННЫЕ НАГРАДЫ · медалей %d/%d" % [done_count, medals.size()]
                        for m in medals:
                                var val: String = str(m[1]) if bool(m[3]) else str(m[2])
                                _arena_board_box.add_child(_make_arena_board_row(str(m[0]), val, bool(m[3])))
                1:
                        title.text = "ЗАЛ СЛАВЫ · лига «САРКОФАГ»"
                        var place := 1
                        for e in board:
                                _arena_board_box.add_child(_make_arena_board_row(
                                        "%d. %s" % [place, str(e.get("name", ""))],
                                        "%s · волна %d" % [_format_number(float(e.get("power", 0))), int(e.get("wave", 1))],
                                        str(e.get("name", "")).begins_with("СТАЛКЕР")))
                                place += 1
                2:
                        title.text = "ОТЧЁТЫ БОЁВ"
                        _arena_board_box.add_child(_make_arena_board_row("Забегов всего", str(total_runs)))
                        _arena_board_box.add_child(_make_arena_board_row("Побед", str(wins), true))
                        _arena_board_box.add_child(_make_arena_board_row("Поражений", str(losses)))
                        _arena_board_box.add_child(_make_arena_board_row("Лучший результат", "%d волн" % rec, true))
                        _arena_board_box.add_child(_make_arena_board_row("Сталкеров перебито", str(kills)))
                        _arena_board_box.add_child(_make_arena_board_row("Артефактов в хранилище", str(lab_data.won_artifacts.size())))
                3:
                        title.text = "ЗАЩИТНЫЙ ОТРЯД"
                        for t in lab_data.unlocked_mutants:
                                _arena_board_box.add_child(_make_arena_board_row(
                                        Loc.type_name(str(t)),
                                        "%s · копий %d" % [LabData.stars_text(lab_data.get_mutant_stars(str(t))), lab_data.get_farm_copies(str(t))]))
                        if lab_data.unlocked_mutants.is_empty():
                                _arena_board_box.add_child(_make_arena_board_row("Отряд пуст", "крутите Гачу Зоны"))
                _:
                        title.text = "ЗАДАЧИ СЕЗОНА"
                        _arena_board_box.add_child(_make_arena_board_row("Победы сезона", "%d / 10" % mini(wins, 10)))
                        _arena_board_box.add_child(_make_arena_board_row("Рекорд волны 30", "%d / 30" % mini(rec, 30), rec >= 30))
                        _arena_board_box.add_child(_make_arena_board_row("Вызовы приняты", "%d / 5" % mini(total_runs, 5)))
                        _arena_board_box.add_child(_make_arena_board_row("Перебить 500 сталкеров", "%d / 500" % mini(kills, 500)))


func _on_arena_tab(idx: int):
        _play_click_sound()
        _arena_tab = idx
        _rebuild_arena_panel()


func _on_arena_challenge(foe_name: String):
        _play_click_sound()
        if not game_manager:
                return
        if foe_name != "БЫСТРЫЙ ВЫЗОВ":
                _show_message("Вызов принят: %s. Готовьте отряд!" % foe_name, 1.6)
        game_manager.arena_run_kind = "challenge"
        _arena_season_timer.stop()
        game_manager.set_selected_run_mode("survival")
        _refresh_campaign_ui()
        _on_start_run_pressed()


func _on_arena_defend_run_pressed():
        """Кнопка ОБОРОНА на строке «Я»: старт выживания от лица защитного отряда"""
        _play_click_sound()
        if not game_manager:
                return
        game_manager.arena_run_kind = "defense"
        _show_message("Оборона арены: отряд принял бой!", 1.6)
        _arena_season_timer.stop()
        game_manager.set_selected_run_mode("survival")
        _refresh_campaign_ui()
        _on_start_run_pressed()


func _update_arena_timer():
        if _arena_timer_label == null or not arena_panel.visible:
                return
        # Конец сезона: предстоящий понедельник 00:00 локального времени
        var now := Time.get_datetime_dict_from_system()
        var days_ahead := (8 - int(now.get("weekday", 1))) % 7
        if days_ahead == 0:
                days_ahead = 7
        var secs_left := days_ahead * 86400.0 - float(now.get("hour", 0)) * 3600.0 - float(now.get("minute", 0)) * 60.0 - float(now.get("second", 0))
        secs_left = maxf(secs_left, 0.0)
        var hh := int(secs_left) / 3600
        var mm := (int(secs_left) % 3600) / 60
        var ss := int(secs_left) % 60
        _arena_timer_label.text = "%02d:%02d:%02d" % [hh, mm, ss]


## Номер сезона: недели с 19.10.2026 (тот самый «сезон 7») + 6
func _arena_season_number() -> int:
        var start := Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 19, "hour": 0, "minute": 0, "second": 0})
        var now := Time.get_unix_time_from_system()
        return 7 + int(floor(maxf(0.0, now - start) / 604800.0))


## 9 сезонных медалей по реальным условиям: [название, награда, прогресс, выполнено]
func _arena_medals(my_place: int) -> Array:
        var rec := 0
        var runs := 0
        if statistics:
                rec = statistics.best_survival_wave
                runs = statistics.total_runs
        var wins_total: int = lab_data.arena_wins_challenge + lab_data.arena_wins_defense
        var mutants: int = lab_data.unlocked_mutants.size()
        var power := _arena_player_power()
        return [
                ["Топ-1 лиги", "Химера ★ + 30 круток", "место %d из 11" % my_place, my_place == 1],
                ["10 побед сезона", "медаль «Выброс»", "%d / 10 побед" % mini(wins_total, 10), wins_total >= 10],
                ["Рекорд волны 30", "+25 круток", "%d / 30 волн" % mini(rec, 30), rec >= 30],
                ["Защита удержана ×5", "+120 000 био", "%d / 5 оборон" % mini(lab_data.arena_wins_defense, 5), lab_data.arena_wins_defense >= 5],
                ["Защита удержана ×10", "медаль «Саркофаг»", "%d / 10 оборон" % mini(lab_data.arena_wins_defense, 10), lab_data.arena_wins_defense >= 10],
                ["5 побед в вызовах", "+5 круток", "%d / 5 вызовов" % mini(lab_data.arena_wins_challenge, 5), lab_data.arena_wins_challenge >= 5],
                ["Участие: 10 вылазок", "+5 круток", "%d / 10 забегов" % mini(runs, 10), runs >= 10],
                ["Отряд из 10 мутантов", "+10 круток", "%d / 10 видов" % mini(mutants, 10), mutants >= 10],
                ["Сила отряда 5000", "медаль «Монолит»", "%s / 5000 силы" % _format_number(float(mini(power, 5000))), power >= 5000],
        ]


## Сила защитного отряда: только назначенные в оборону мутанты
func _defense_power() -> int:
        var power := 0
        if not lab_data:
                return 0
        for t in lab_data.arena_defense_squad:
                power += 340 * lab_data.get_mutant_stars(str(t))
                power += 15 * lab_data.get_farm_copies(str(t))
        return power


func _build_defense_ui():
        """СМЕНА ОБОРОНЫ: выбор мутантов, держащих арену (строится кодом)"""
        defense_panel = Control.new()
        defense_panel.name = "DefensePanel"
        defense_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
        defense_panel.mouse_filter = Control.MOUSE_FILTER_STOP
        defense_panel.visible = false
        add_child(defense_panel)

        var bg := ColorRect.new()
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.color = Color(0.028, 0.022, 0.014, 0.97)
        defense_panel.add_child(bg)

        var root := VBoxContainer.new()
        root.set_anchors_preset(Control.PRESET_FULL_RECT)
        root.offset_left = 60
        root.offset_right = -60
        root.offset_top = 24
        root.offset_bottom = -24
        root.add_theme_constant_override("separation", 12)
        defense_panel.add_child(root)

        var head := HBoxContainer.new()
        head.add_theme_constant_override("separation", 16)
        root.add_child(head)
        var title := Label.new()
        title.text = "СМЕНА ОБОРОНЫ"
        title.add_theme_font_override("font", BunkerUI.font_title())
        title.add_theme_font_size_override("font_size", 34)
        title.add_theme_color_override("font_color", BunkerUI.HAZARD)
        head.add_child(title)
        var sub := Label.new()
        sub.text = "кто держит арену, пока ты в вылазке"
        sub.add_theme_font_override("font", BunkerUI.font_body())
        sub.add_theme_font_size_override("font_size", 15)
        sub.add_theme_color_override("font_color", BunkerUI.TEXT_DIM)
        sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        head.add_child(sub)
        var sp := Control.new()
        sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        head.add_child(sp)
        var done_btn := Button.new()
        done_btn.text = "ГОТОВО"
        done_btn.custom_minimum_size = Vector2(160, 56)
        BunkerUI.style_button(done_btn, "hazard", 17, true)
        done_btn.pressed.connect(_on_defense_close_pressed)
        done_btn.mouse_entered.connect(_play_hover_sound)
        head.add_child(done_btn)

        _defense_power_label = BunkerUI.make_mono_label("", 18, BunkerUI.GREEN)
        root.add_child(_defense_power_label)

        var scroll := ScrollContainer.new()
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        root.add_child(scroll)
        _defense_list_box = VBoxContainer.new()
        _defense_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _defense_list_box.add_theme_constant_override("separation", 8)
        scroll.add_child(_defense_list_box)


func _rebuild_defense_panel():
        """Список мутантов с переключателем В ОБОРОНЕ/В РЕЗЕРВ"""
        for child in _defense_list_box.get_children():
                child.queue_free()
        if not lab_data:
                return
        # Первое открытие: весь текущий отряд считаем обороной
        if lab_data.arena_defense_squad.is_empty() and not lab_data.unlocked_mutants.is_empty():
                for t in lab_data.unlocked_mutants:
                        lab_data.arena_defense_squad.append(str(t))
        for t in lab_data.unlocked_mutants:
                var in_squad: bool = lab_data.arena_defense_squad.has(str(t))
                var row := PanelContainer.new()
                var sb := StyleBoxFlat.new()
                sb.bg_color = Color(0.062, 0.086, 0.041)
                sb.border_color = BunkerUI.HAZARD if in_squad else BunkerUI.STEEL_EDGE
                sb.set_border_width_all(2)
                sb.set_corner_radius_all(10)
                sb.content_margin_left = 18.0
                sb.content_margin_right = 18.0
                sb.content_margin_top = 8.0
                sb.content_margin_bottom = 8.0
                row.add_theme_stylebox_override("panel", sb)
                var h := HBoxContainer.new()
                h.add_theme_constant_override("separation", 14)
                row.add_child(h)
                var who := VBoxContainer.new()
                who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                who.alignment = BoxContainer.ALIGNMENT_CENTER
                var nm := Label.new()
                nm.text = Loc.type_name(str(t))
                nm.add_theme_font_override("font", BunkerUI.font_title())
                nm.add_theme_font_size_override("font_size", 17)
                nm.add_theme_color_override("font_color", BunkerUI.TEXT_LIGHT)
                who.add_child(nm)
                var info := BunkerUI.make_mono_label(
                        "%s · копий %d" % [LabData.stars_text(lab_data.get_mutant_stars(str(t))), lab_data.get_farm_copies(str(t))],
                        13, BunkerUI.TEXT_DIM)
                who.add_child(info)
                h.add_child(who)
                var tog := Button.new()
                tog.text = "В ОБОРОНЕ" if in_squad else "В РЕЗЕРВ"
                tog.custom_minimum_size = Vector2(190, 48)
                BunkerUI.style_button(tog, "hazard" if in_squad else "ghost", 14)
                tog.pressed.connect(_on_defense_toggle.bind(str(t)))
                tog.mouse_entered.connect(_play_hover_sound)
                h.add_child(tog)
                _defense_list_box.add_child(row)
        if lab_data.unlocked_mutants.is_empty():
                var empty := BunkerUI.make_mono_label("Отряд пуст — крутите Дар Зоны", 16, BunkerUI.TEXT_DIM)
                _defense_list_box.add_child(empty)
        _defense_power_label.text = "СИЛА ОБОРОНЫ: %d" % _defense_power()


func _on_defense_toggle(type: String):
        _play_click_sound()
        if not lab_data:
                return
        var key := str(type)
        if lab_data.arena_defense_squad.has(key):
                lab_data.arena_defense_squad.erase(key)
        else:
                lab_data.arena_defense_squad.append(key)
        _rebuild_defense_panel()


func _on_defense_open_pressed():
        _play_click_sound()
        _hide_lab_overlays("defense")
        defense_panel.visible = true
        _rebuild_defense_panel()


func _on_defense_close_pressed():
        _play_click_sound()
        defense_panel.visible = false
        _on_arena_pressed()


# ==================== ВРАТА ЯРУСОВ БАШНИ (макет «ВРАТА ЯРУСОВ») ====================
# Полноэкранные готические врата: 10 ярусов башни, выбор яруса перед этажами.
# Открываются автоматически при переключении в режим Башни и кнопкой ВРАТА.

var gates_panel: Control
var _gates_control: TierGates
var _gates_info_box: VBoxContainer
var _gates_floor_plate: Label = null
var _gates_star_plate: Label = null
var _gates_go_button: Button


func _build_gates_ui():
        """Полноэкранные врата ярусов (строится кодом, рисует TierGates)"""
        gates_panel = Control.new()
        gates_panel.name = "GatesPanel"
        gates_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
        gates_panel.mouse_filter = Control.MOUSE_FILTER_STOP
        gates_panel.visible = false
        add_child(gates_panel)

        var bg := ColorRect.new()
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        bg.color = Color(0.028, 0.022, 0.014, 0.99)
        gates_panel.add_child(bg)

        var root := VBoxContainer.new()
        root.set_anchors_preset(Control.PRESET_FULL_RECT)
        root.offset_left = 30
        root.offset_right = -30
        root.offset_top = 16
        root.offset_bottom = -16
        root.add_theme_constant_override("separation", 8)
        gates_panel.add_child(root)

        # ---- Шапка ----
        var head := HBoxContainer.new()
        head.add_theme_constant_override("separation", 16)
        root.add_child(head)

        var title := Label.new()
        title.text = "БАШНЯ · "
        title.add_theme_font_override("font", BunkerUI.font_title())
        title.add_theme_font_size_override("font_size", 34)
        title.add_theme_color_override("font_color", BunkerUI.TEXT_LIGHT)
        head.add_child(title)
        var title2 := Label.new()
        title2.text = "ВРАТА ЯРУСОВ"
        title2.add_theme_font_override("font", BunkerUI.font_title())
        title2.add_theme_font_size_override("font_size", 34)
        title2.add_theme_color_override("font_color", BunkerUI.HAZARD)
        head.add_child(title2)

        var sp := Control.new()
        sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        head.add_child(sp)

        var floor_plate := BunkerUI.make_plate("1", "ЛУЧШИЙ ЭТАЖ", 150.0)
        head.add_child(floor_plate)
        _gates_floor_plate = floor_plate.get_child(0).get_child(0)

        var star_plate := BunkerUI.make_plate("0", "ЗВЁЗД ИЗ 300", 150.0)
        head.add_child(star_plate)
        _gates_star_plate = star_plate.get_child(0).get_child(0)

        # ---- Тело: врата (лево) + панель яруса (право) ----
        var body := HBoxContainer.new()
        body.size_flags_vertical = Control.SIZE_EXPAND_FILL
        body.add_theme_constant_override("separation", 14)
        root.add_child(body)

        _gates_control = TierGates.new()
        _gates_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _gates_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _gates_control.selection_changed.connect(_on_gate_selected)
        body.add_child(_gates_control)

        var info := Panel.new()
        info.custom_minimum_size = Vector2(460, 0)
        body.add_child(info)

        _gates_info_box = VBoxContainer.new()
        _gates_info_box.set_anchors_preset(Control.PRESET_FULL_RECT)
        _gates_info_box.offset_left = 22
        _gates_info_box.offset_right = -22
        _gates_info_box.offset_top = 18
        _gates_info_box.offset_bottom = -18
        _gates_info_box.add_theme_constant_override("separation", 8)
        info.add_child(_gates_info_box)

        # ---- Подвал ----
        var foot := HBoxContainer.new()
        foot.add_theme_constant_override("separation", 14)
        root.add_child(foot)

        var back := Button.new()
        back.text = "◄  НАЗАД"
        back.custom_minimum_size = Vector2(190, 60)
        BunkerUI.style_button(back, "steel", 19)
        back.pressed.connect(_on_gates_close_pressed)
        back.mouse_entered.connect(_play_hover_sound)
        foot.add_child(back)

        var hint := Label.new()
        hint.text = "10 врат = 10 ярусов башни.\nВыбор этажа — ◀▶ в шапке лабы после входа в ярус."
        hint.add_theme_font_override("font", BunkerUI.font_mono())
        hint.add_theme_font_size_override("font_size", 12)
        hint.add_theme_color_override("font_color", Color("8a744a"))
        hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        foot.add_child(hint)

        _gates_go_button = Button.new()
        _gates_go_button.text = "▶  ИДТИ НА ЭТАЖ"
        _gates_go_button.custom_minimum_size = Vector2(430, 60)
        BunkerUI.style_button(_gates_go_button, "hazard", 19, true)
        _gates_go_button.pressed.connect(_on_gates_go_pressed)
        _gates_go_button.mouse_entered.connect(_play_hover_sound)
        foot.add_child(_gates_go_button)


func _gates_tier_stars_array() -> Array:
        var out: Array = []
        for t in range(10):
                var s := 0
                if game_manager and game_manager.current_save_data:
                        for f in range(t * 10 + 1, t * 10 + 11):
                                s += int(game_manager.current_save_data.tower_stars.get(str(f), 0))
                out.append(s)
        return out


func _gates_total_stars() -> int:
        var total := 0
        for s in _gates_tier_stars_array():
                total += int(s)
        return total


func _open_gates():
        if not game_manager:
                return
        _hide_lab_overlays("gates")
        _refresh_gates_data()
        gates_panel.visible = true


func _on_gates_open_pressed():
        _play_click_sound()
        _open_gates()


func _on_gates_close_pressed():
        _play_click_sound()
        gates_panel.visible = false


func _refresh_gates_data():
        if not game_manager:
                return
        var frontier: int = game_manager.get_tower_frontier()
        var names: Array = []
        var bosses: Array = []
        for t in TowerData.TIERS:
                names.append(str(t.get("name", "")))
                bosses.append(str(t.get("boss", "")))
        var sel := clampi((_tower_floor - 1) / 10, 0, 9)
        _gates_control.setup(frontier, names, _gates_tier_stars_array(), bosses, sel)
        if _gates_floor_plate:
                _gates_floor_plate.text = "%d/100" % frontier
        if _gates_star_plate:
                _gates_star_plate.text = "%d" % _gates_total_stars()
        _rebuild_gates_info()


func _on_gate_selected(tier_idx: int):
        _play_click_sound()
        # Программный выбор тоже двигает врата (клик обрабатывает сам TierGates)
        if _gates_control and _gates_control.selected_tier != tier_idx:
                _gates_control.selected_tier = clampi(tier_idx, 0, 9)
                _gates_control.queue_redraw()
        _rebuild_gates_info()


func _rebuild_gates_info():
        """Панель выбранного яруса справа"""
        for child in _gates_info_box.get_children():
                child.queue_free()
        var t := clampi(_gates_control.selected_tier, 0, 9)
        var tier: Dictionary = TowerData.TIERS[t]
        var unlocked: bool = game_manager and game_manager.get_tower_frontier() > t * 10

        var head := Label.new()
        head.text = "ЯРУС %d · «%s»" % [t + 1, str(tier.get("name", ""))]
        head.add_theme_font_override("font", BunkerUI.font_title())
        head.add_theme_font_size_override("font_size", 22)
        head.add_theme_color_override("font_color", Color("ffd94d") if unlocked else BunkerUI.TEXT_DIM)
        head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _gates_info_box.add_child(head)

        var sub := BunkerUI.make_mono_label(
                "этажи %d–%d · %s" % [t * 10 + 1, t * 10 + 10,
                "открыт" if unlocked else "нужно дойти до этажа %d" % (t * 10 + 1)],
                13, Color("9a8349"))
        sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _gates_info_box.add_child(sub)

        var stars: int = int(_gates_tier_stars_array()[t])
        _gates_info_box.add_child(_make_altar_kv("Звёзды яруса", "★ ×%d / 30" % stars, Color("ffd94d")))
        _gates_info_box.add_child(_make_altar_kv("Волн на этаже", str(int(tier.get("waves", 3)))))
        _gates_info_box.add_child(_make_altar_kv("Сталкеров на волну", str(int(tier.get("count", 8)))))
        _gates_info_box.add_child(_make_altar_kv("Состав рангов", "%d/%d/%d %%" % [int(tier["mix"][0]), int(tier["mix"][1]), int(tier["mix"][2])]))
        _gates_info_box.add_child(_make_altar_kv("Сила врагов", "×%.2f → ×%.2f" % [float(tier.get("stat", 1.0)), float(tier.get("stat_end", 1.0))]))
        _gates_info_box.add_child(_make_altar_kv("Хранитель", str(tier.get("boss", "—")), BunkerUI.HAZARD))
        _gates_info_box.add_child(_make_altar_kv("Выбросов до победы", str(int(tier.get("pulses", 3)))))

        var push := Control.new()
        push.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _gates_info_box.add_child(push)

        if unlocked:
                var target_floor: int = mini(t * 10 + 10, game_manager.get_tower_frontier())
                _gates_go_button.text = "▶  ИДТИ НА ЭТАЖ %d" % target_floor
                _gates_go_button.disabled = false
                _gates_go_button.set_meta("target_floor", target_floor)
        else:
                _gates_go_button.text = "ВРАТА ЗАПЕРТЫ"
                _gates_go_button.disabled = true


func _on_gates_go_pressed():
        _play_click_sound()
        if not game_manager or _gates_go_button.disabled:
                return
        var target: int = int(_gates_go_button.get_meta("target_floor", game_manager.get_tower_frontier()))
        _tower_floor = clampi(target, 1, game_manager.get_tower_frontier())
        gates_panel.visible = false
        _refresh_campaign_ui()
        _show_message("Этаж %d выбран — жмите ЗАБЕГ" % _tower_floor, 1.8)

