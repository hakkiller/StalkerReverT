# zones/zone_controller.gd
extends Node
class_name ZoneController

## Единый контроллер зоны - оркестрирует все менеджеры

# Сигналы (прокси для менеджеров)
signal energy_changed(current: float, max_value: float)
signal biomass_changed(current: float, max_value: float)
signal radiation_pulse_started(level: int)
signal radiation_pulse_ended
signal wave_started(wave_number: int, count: int)
signal wave_ended(wave_number: int, survivors: int)
signal wave_break_started(wave_number: int, break_duration: float)
signal game_over
signal game_won(run_number: int, reward: float)

# Сигналы от HUD
# Менеджеры
var resource_manager: ResourceManager
var anomaly_manager: AnomalyManager
var spawn_manager: SpawnManager
var event_manager: EventManager
var progression_manager: ProgressionManager

# Визуальные менеджеры
var fog_manager: FogManager
var particle_manager: ParticleManager
var sound_manager: SoundManager

# Конфигурация (загружается из сцены)
@export var anomaly_scenes: Dictionary = {}
@export var anomaly_artifact_map: Dictionary = {}
@export var artifact_values: Dictionary = {}
@export var difficulty_to_rarity: Dictionary = {}

@export var novice_stalker_scene: PackedScene
@export var veteran_stalker_scene: PackedScene
@export var master_stalker_scene: PackedScene
@export var mutant_scenes: Dictionary = {}

@export var max_energy: float = 1000.0
@export var max_biomass: float = 999999.0
@export var critical_biomass_threshold: float = 0.4
@export var pulse_duration: float = 5.0
# Победа: 3 выброса (от кнопки или от переполнения биомассы) ИЛИ отбить все волны
@export var pulses_to_win: int = 3

# Параметры забега
var run_params: Dictionary = {}
var is_initialized: bool = false
# Забег уже завершается (одноразовый finish_run)
var is_run_finished: bool = false
# Купленные в магазине артефакты: спавн у монолита на старте забега
var _shop_artifacts_pending: Array[String] = []
# Награды гачи/вех/событий за забег (для панели итогов)
var _gacha_rewards_log: Array[String] = []
# Фаза подготовки: сталкеры не спавнятся, пока игрок не нажмёт СТАРТ
var is_prep_phase: bool = true
# Мобильный режим «тап = ставить»: "" | "anomaly:<type>" | "mutant:<type>"
# Включается/выключается из HUD (кнопки аномалий/мутантов на тач-устройствах),
# тап по земле (Signals.ground_tapped) ставит выбранное в точку
var _pending_placement: String = ""


func _ready():
                pass # print("ZoneController: инициализация...")
                add_to_group("zone_controller")

                # Мобильный режим «тап = ставить»: камера шлёт тапы по земле
                Signals.ground_tapped.connect(_on_ground_tapped)

                # Загружаем параметры забега из GameManager
                if get_tree().root.has_meta("run_params"):
                                run_params = get_tree().root.get_meta("run_params")
                                get_tree().root.remove_meta("run_params")
                                pass # print("Параметры забега загружены: " + str(run_params))

                _setup_managers()
                _connect_managers()

                # Ждём появления TerrainGenerator
                await _wait_for_terrain_generator()

                # Принудительно загружаем чанки вокруг монолита
                await _force_initial_chunk_load()

                # Инициализируем забег
                _initialize_run()

                # Подключаемся к HUD
                await _connect_to_hud()

                # Постэффект «мрачная зона»: Припять мрачнее, процедурная Зона мягче
                add_child(GrimPostfxLayer.new(1.25 if str(run_params.get("map", "procedural")) == "pripyat" else 1.0))

                # Боевая музыка
                var sm = get_tree().get_first_node_in_group("sound_manager")
                if sm and sm.has_method("play_music"):
                                sm.play_music("run")

                is_initialized = true
                pass # print("ZoneController: готов!")


func _wait_for_terrain_generator():
                """Ждёт появления TerrainGenerator"""
                pass # print("ZoneController: ожидание TerrainGenerator...")
                var attempts = 0
                var max_attempts = 30

                while not get_tree().get_first_node_in_group("terrain_generator") and attempts < max_attempts:
                                await get_tree().process_frame
                                attempts += 1

                if get_tree().get_first_node_in_group("terrain_generator"):
                                pass # print("ZoneController: TerrainGenerator НАЙДЕН!")
                else:
                                pass # print("ZoneController: TerrainGenerator НЕ НАЙДЕН после ", max_attempts, " попыток!")


func _force_initial_chunk_load():
                """Принудительно загружает чанки вокруг монолита при старте"""
                var terrain = get_tree().get_first_node_in_group("terrain_generator")
                if not terrain:
                                pass # print("ZoneController: TerrainGenerator не найден, пропускаем загрузку чанков")
                                return

                var monolith_node = get_tree().get_first_node_in_group("monolith")
                if not monolith_node:
                                pass # print("ZoneController: Монолит не найден!")
                                return

                pass # print("ZoneController: принудительная загрузка чанков вокруг монолита...")

                # Сохраняем позицию камеры
                var camera = get_viewport().get_camera_3d()
                var original_pos = camera.global_position if camera else Vector3.ZERO

                # Временно перемещаем камеру к монолиту
                if camera:
                                camera.global_position = monolith_node.global_position + Vector3(0, 50, 0)
                                await get_tree().process_frame
                                await get_tree().process_frame

                # Принудительно обновляем чанки несколько раз
                for i in range(3):
                                if terrain.has_method("_update_chunks"):
                                                terrain._update_chunks()
                                await get_tree().process_frame

                # Принудительно перестраиваем навигацию
                if terrain.has_method("force_rebuild_navigation"):
                                terrain.force_rebuild_navigation()

                # Возвращаем камеру на место
                if camera and original_pos != Vector3.ZERO:
                                camera.global_position = original_pos

                pass # print("ZoneController: начальная загрузка чанков завершена. Загружено чанков: ", 
                                # terrain.get_loaded_chunks_count() if terrain.has_method("get_loaded_chunks_count") else 0)


func start_run():
                """Запускает спавн сталкеров после фазы подготовки"""
                if not is_prep_phase:
                                return
                is_prep_phase = false
                pass # print("ZoneController: СТАРТ - сталкеры пошли!")
                spawn_manager.start_spawning()


func _on_wave_break_started(wave_number: int, break_duration: float):
                wave_break_started.emit(wave_number, break_duration)


func _on_all_waves_cleared():
                """Все 3 волны отбиты, сталкеров не осталось - победа"""
                if is_run_finished:
                                return
                pass # print("ПОБЕДА: все волны отбиты!")
                finish_run(true)


func _connect_to_hud():
                """Подключается к HUD после его создания"""
                var hud = get_tree().get_first_node_in_group("hud")
                var attempts = 0
                var max_attempts = 10

                while not hud and attempts < max_attempts:
                                await get_tree().create_timer(0.5).timeout
                                hud = get_tree().get_first_node_in_group("hud")
                                attempts += 1

                if hud:
                                hud.anomaly_requested.connect(_on_hud_anomaly_requested)
                                hud.mutant_requested.connect(_on_hud_mutant_requested)
                                if hud.has_signal("start_run_requested"):
                                                hud.start_run_requested.connect(start_run)
                                pass # print("ZoneController: HUD подключен")
                else:
                                pass # print("ZoneController: HUD не найден после ", max_attempts, " попыток")


func _setup_managers():
                # ResourceManager
                resource_manager = ResourceManager.new()
                resource_manager.max_energy = max_energy
                resource_manager.max_biomass = max_biomass
                resource_manager.critical_threshold = critical_biomass_threshold
                add_child(resource_manager)
                pass # print("ResourceManager создан")

                # AnomalyManager
                anomaly_manager = AnomalyManager.new()
                anomaly_manager.anomaly_scenes = anomaly_scenes
                anomaly_manager.anomaly_artifact_map = anomaly_artifact_map if not anomaly_artifact_map.is_empty() else GachaData.ANOMALY_ARTIFACT_MAP
                anomaly_manager.artifact_values = artifact_values
                anomaly_manager.difficulty_to_rarity = difficulty_to_rarity
                add_child(anomaly_manager)
                pass # print("AnomalyManager создан")

                # SpawnManager
                spawn_manager = SpawnManager.new()
                spawn_manager.stalker_scenes = {
                                "novice": novice_stalker_scene,
                                "veteran": veteran_stalker_scene,
                                "master": master_stalker_scene
                }
                spawn_manager.mutant_scenes = mutant_scenes
                add_child(spawn_manager)
                pass # print("SpawnManager создан")

                # EventManager
                event_manager = EventManager.new()
                event_manager.pulse_duration = pulse_duration
                add_child(event_manager)
                pass # print("EventManager создан")

                # ProgressionManager
                progression_manager = ProgressionManager.new()
                add_child(progression_manager)
                pass # print("ProgressionManager создан")

                # FogManager
                fog_manager = FogManager.new()
                fog_manager.enabled = true
                add_child(fog_manager)
                pass # print("FogManager создан")

                # ParticleManager
                particle_manager = ParticleManager.new()
                add_child(particle_manager)
                pass # print("ParticleManager создан")

                # SoundManager
                sound_manager = SoundManager.new()
                add_child(sound_manager)
                pass # print("SoundManager создан")


func _connect_managers():
                # ResourceManager
                resource_manager.energy_changed.connect(_on_energy_changed)
                resource_manager.biomass_changed.connect(_on_biomass_changed)
                resource_manager.critical_biomass_reached.connect(_on_critical_biomass)

                # EventManager
                event_manager.radiation_pulse_started.connect(_on_radiation_pulse_started)
                event_manager.radiation_pulse_ended.connect(_on_radiation_pulse_ended)
                event_manager.game_over.connect(_on_game_over)
                event_manager.game_won.connect(_on_game_won)

                # SpawnManager
                spawn_manager.wave_started.connect(_on_wave_started)
                spawn_manager.wave_ended.connect(_on_wave_ended)
                spawn_manager.break_started.connect(_on_wave_break_started)
                spawn_manager.all_waves_cleared.connect(_on_all_waves_cleared)
                spawn_manager.stalker_died.connect(_on_stalker_died)
                spawn_manager.mutant_spawned.connect(_on_mutant_spawned)

                # AnomalyManager
                anomaly_manager.anomaly_created.connect(_on_anomaly_created)
                anomaly_manager.anomaly_destroyed.connect(_on_anomaly_destroyed)
                anomaly_manager.artifact_created.connect(_on_artifact_created)
                anomaly_manager.artifact_stolen.connect(_on_artifact_stolen)

                # Прокси сигналы в глобальные
                anomaly_manager.anomaly_created.connect(func(a, t, d): Signals.anomaly_created.emit(a, t, a.global_position, d))
                anomaly_manager.artifact_created.connect(func(a, t, p): Signals.artifact_created.emit(a, t, p, a.get_value() if a.has_method("get_value") else 0))
                spawn_manager.stalker_spawned.connect(func(s, t): Signals.stalker_spawned.emit(s, t, s.global_position))
                spawn_manager.mutant_spawned.connect(func(m, t): Signals.mutant_spawned.emit(m, t, m.global_position, spawn_manager.get_mutant_cost(t)))


func _initialize_run():
                var run_data = progression_manager.start_new_run()
                var run_number: int = run_data.run_number
                var run_difficulty: float = run_data.difficulty
                var pulses: int = pulses_to_win

                # Кампания: параметры уровня перекрывают дефолтную прогрессию забегов
                if run_params.has("campaign_params"):
                                var campaign: Dictionary = run_params["campaign_params"]
                                run_number = int(run_params.get("campaign_level", run_data.run_number))
                                run_difficulty = float(campaign.get("hp_mult", 1.0))
                                pulses = int(campaign.get("pulses_to_win", pulses_to_win))

                                progression_manager.current_run = run_number
                                progression_manager.current_difficulty = run_difficulty

                                spawn_manager.max_waves = int(campaign.get("waves", spawn_manager.max_waves))
                                spawn_manager.min_stalkers_per_wave = int(campaign.get("count_min", spawn_manager.min_stalkers_per_wave))
                                spawn_manager.max_stalkers_per_wave = int(campaign.get("count_max", spawn_manager.max_stalkers_per_wave))
                                spawn_manager.wave_break = float(campaign.get("wave_break", spawn_manager.wave_break))
                                # Количество сталкеров задаёт уровень кампании, а не множитель сложности
                                spawn_manager.set_difficulty(1.0)
                                spawn_manager.set_rank_weights(campaign.get("mix", [90, 10, 0]))
                                spawn_manager.set_campaign_scaling(
                                                float(campaign.get("hp_mult", 1.0)),
                                                float(campaign.get("damage_mult", 1.0)),
                                                float(campaign.get("speed_mult", 1.0)))

                                # Стражи башни (25/50/75/100): доля элиты в волнах
                                spawn_manager.set_elite_share(float(campaign.get("elite_pct", 0.0)))

                                # Припять: Монолит перемещается по маршруту ярусов
                                # (центр города -> Саркофаг), точка - от уровня/этажа
                                if str(run_params.get("map", "procedural")) == "pripyat":
                                                var pm := get_tree().get_first_node_in_group("terrain_generator")
                                                var mono := get_tree().get_first_node_in_group("monolith")
                                                if pm and pm.has_method("monolith_position_for_level") and mono:
                                                                mono.global_position = pm.monolith_position_for_level(
                                                                                int(campaign.get("level", 1)))
                elif run_params.get("run_mode", "campaign") == "survival":
                                # Выживание: волны бесконечны, победы нет; эскалацию считает SurvivalData
                                var survival: Dictionary = run_params.get("survival_params", {})

                                progression_manager.current_run = run_data.run_number
                                progression_manager.current_difficulty = float(survival.get("hp_mult", 1.0))

                                spawn_manager.endless_mode = true
                                spawn_manager.set_difficulty(1.0)
                                _apply_survival_wave(survival)

                                # Сброс состояния фазы легенды на новом забеге
                                _next_wave_modifier = {}
                                _wave_modifier = {}
                                _harvest_mult = 1.0
                                _phase_announced = {}

                                # Припять: Монолит выживания - старт маршрута (центр Припяти),
                                # а не мировое (0,0) района
                                if str(run_params.get("map", "procedural")) == "pripyat":
                                                var pm_s := get_tree().get_first_node_in_group("terrain_generator")
                                                var mono_s := get_tree().get_first_node_in_group("monolith")
                                                if pm_s and pm_s.has_method("monolith_position_for_level") and mono_s:
                                                                mono_s.global_position = pm_s.monolith_position_for_level(1)

                                event_manager.endless_mode = true
                                pulses = 0

                event_manager.set_pulses_to_win(pulses)
                event_manager.set_run_number(run_number)
                event_manager.set_difficulty(run_difficulty)

                # Применяем бонусы из лаборатории
                _apply_lab_bonuses()

                # Звёздность коллекции: спавнящиеся мутанты получают свои звёзды
                if spawn_manager and run_params.has("mutant_stars"):
                                spawn_manager.set_mutant_stars(run_params["mutant_stars"])

                # Стартовая биомасса забега (остаток лаборатории + 300)
                resource_manager.current_biomass = clamp(
                                run_params.get("start_biomass", 300.0), 0.0, max_biomass)

                # Покупки магазина: наградные мутанты в очередь, артефакты у монолита
                var gm = get_tree().get_first_node_in_group("game_manager")
                if gm and gm.has_method("consume_shop_purchases"):
                                var shop: Dictionary = gm.consume_shop_purchases()
                                for t in shop.get("mutants", []):
                                                spawn_manager.queue_reward_mutant(t)
                                for a in shop.get("artifacts", []):
                                                _shop_artifacts_pending.append(a)

                # Эксклюзивы Чёрного ящика: питомцы коллекции каждый забег у монолита
                if gm and gm.has_method("get_owned_exclusives"):
                                for t in gm.get_owned_exclusives():
                                                spawn_manager.queue_reward_mutant(t)

                # Артефакты из магазина - приманка у монолита
                for a in _shop_artifacts_pending:
                                if anomaly_manager:
                                                anomaly_manager.create_artifact(a, Vector3(8.0, 1.8, 8.0), "common", 0.0)
                                                pass # print("Магазин: артефакт ", a, " размещён у монолита")
                _shop_artifacts_pending.clear()

                _gacha_rewards_log.clear()
                _trophy_artifacts.clear()
                # Фаза подготовки: спавн сталкеров начнётся по кнопке СТАРТ в HUD
                # (лог отключён)
                if run_params.has("campaign_params"):
                                pass # (лог отключён)
                elif run_params.get("run_mode", "") == "survival":
                                pass # (лог отключён)
                Signals.run_started.emit(run_number, run_difficulty, pulses)
                pass # print(run_label + " в фазе подготовки (множитель врагов: " + str(run_difficulty) + "). Расставьте защиты и нажмите СТАРТ.")


func _apply_lab_bonuses():
                if not run_params.has("bonuses"):
                                return

                var bonuses = run_params["bonuses"]

                # Применяем бонусы к менеджерам
                if bonuses.has("anomaly_damage_mult") and anomaly_manager:
                                anomaly_manager.damage_multiplier = bonuses["anomaly_damage_mult"]

                if bonuses.has("anomaly_radius_mult") and anomaly_manager:
                                anomaly_manager.radius_multiplier = bonuses["anomaly_radius_mult"]

                if bonuses.has("mutant_health_mult") and spawn_manager:
                                spawn_manager.health_multiplier = bonuses["mutant_health_mult"]

                if bonuses.has("mutant_damage_mult") and spawn_manager:
                                spawn_manager.damage_multiplier = bonuses["mutant_damage_mult"]

                if bonuses.has("mutant_cost_mult") and spawn_manager:
                                spawn_manager.cost_multiplier = bonuses["mutant_cost_mult"]
                                # Ценники HUD рисуются до применения бонусов - перерисовать
                                var hud_prices = get_tree().get_first_node_in_group("hud")
                                if hud_prices and hud_prices.has_method("_apply_prices"):
                                                hud_prices._apply_prices.call_deferred()

                pass # print("Бонусы лаборатории применены: " + str(bonuses))


## Параметры волны выживания: тот же формат, что у уровня кампании
# ==================== ФАЗА ЛЕГЕНДЫ: СОСТОЯНИЕ ВОЛНЫ ====================
var _next_wave_modifier: Dictionary = {}   # модификатор СЛЕДУЮЩЕЙ волны (анонс)
var _wave_modifier: Dictionary = {}        # модификатор ТЕКУЩЕЙ волны
var _saved_regen: float = -1.0             # базовый реген до осадки ЭМ-туманом
var _saved_fog_density: float = -1.0       # базовая плотность тумана до Ночи
var _harvest_mult: float = 1.0             # ЖАТВА: множитель добычи за килл
var _phase_announced: Dictionary = {}      # анонсированные фазы (30/40/50)

func _apply_survival_wave(params: Dictionary):
                spawn_manager.min_stalkers_per_wave = int(params.get("count_min", 8))
                spawn_manager.max_stalkers_per_wave = int(params.get("count_max", 10))
                spawn_manager.wave_break = float(params.get("wave_break", 45.0))
                spawn_manager.set_rank_weights(params.get("mix", [100, 0, 0]))
                spawn_manager.set_campaign_scaling(
                                float(params.get("hp_mult", 1.0)),
                                float(params.get("damage_mult", 1.0)),
                                float(params.get("speed_mult", 1.0)))
                pass # print("Волна выживания %d: сталкеров %d-%d, состав н/в/м %s, множитель x%.2f" % [
                                # int(params.get("wave", 1)),
                                # int(params.get("count_min", 8)),
                                # int(params.get("count_max", 10)),
                                # str(params.get("mix", [])),
                                # float(params.get("hp_mult", 1.0))])

## Применить модификатор текущей волны (осадка/ночь/жатва)
func _apply_wave_modifier(mod: Dictionary):
                _harvest_mult = float(mod.get("kill_reward_mult", 1.0))
                if mod.has("regen_mult") and resource_manager:
                                if _saved_regen < 0.0:
                                                _saved_regen = resource_manager.energy_regen_rate
                                resource_manager.energy_regen_rate = _saved_regen * float(mod["regen_mult"])
                if mod.has("vision_mult"):
                                var vm: float = float(mod["vision_mult"])
                                for s in spawn_manager.get_active_stalkers():
                                                if is_instance_valid(s) and s.get("memory_component"):
                                                                s.memory_component.set_vision_range(s.detection_radius * vm)
                if mod.has("fog_mult"):
                                var fm = get_tree().get_first_node_in_group("fog_manager")
                                if fm != null:
                                                if _saved_fog_density < 0.0:
                                                                _saved_fog_density = fm.max_density
                                                fm.max_density = _saved_fog_density * float(mod["fog_mult"])
                _update_postfx_strength(float(mod.get("postfx_mult", 1.0)))
                if not mod.is_empty():
                                _note_hud(mod)


## Снять модификатор завершившейся волны
func _clear_wave_modifier():
                _harvest_mult = 1.0
                if _saved_regen >= 0.0 and resource_manager:
                                resource_manager.energy_regen_rate = _saved_regen
                _saved_regen = -1.0
                for s in spawn_manager.get_active_stalkers():
                                if is_instance_valid(s) and s.get("memory_component"):
                                                s.memory_component.set_vision_range(s.detection_radius)
                if _saved_fog_density >= 0.0:
                                var fm = get_tree().get_first_node_in_group("fog_manager")
                                if fm != null:
                                                fm.max_density = _saved_fog_density
                _saved_fog_density = -1.0
                _update_postfx_strength(1.0)


## Сила постэффекта: база карты x ночь x ступень фазы, кап из спеки
func _update_postfx_strength(night_mult: float = 1.0):
                var base: float = 1.25 if str(run_params.get("map", "procedural")) == "pripyat" else 1.0
                var phase_mult: float = pow(SurvivalData.PHASE_POSTFX_STEP, SurvivalData.phase_index(spawn_manager.current_wave))
                var strength: float = clampf(base * night_mult * phase_mult, 0.5, SurvivalData.POSTFX_NIGHT_CAP)
                for child in get_children():
                                if child is GrimPostfxLayer:
                                                child.set_strength(strength)


## Бесплатный выброс на волнах 33/43/53: таймер 75 с + два гудка
func _start_blowout_countdown():
                var sm = get_tree().get_first_node_in_group("sound_manager")
                if sm and sm.has_method("play_pulse_warning"):
                                sm.play_pulse_warning()
                await get_tree().create_timer(SurvivalData.BLOWOUT_DELAY - SurvivalData.BLOWOUT_FINAL_WARNING).timeout
                if is_run_finished or not is_inside_tree():
                                return
                if sm and sm.has_method("play_pulse_warning"):
                                sm.play_pulse_warning()
                await get_tree().create_timer(SurvivalData.BLOWOUT_FINAL_WARNING).timeout
                if is_run_finished or not is_inside_tree() or not event_manager:
                                return
                event_manager.start_radiation_pulse()


## Нота в HUD (события/модификаторы/фазы)
func _note_hud(note: Dictionary):
                var hud = get_tree().get_first_node_in_group("hud")
                if hud and hud.has_method("show_event_note"):
                                hud.show_event_note(note)


## Анонс особенностей следующей волны в передышке
func _preview_survival_wave(next_wave: int):
                var note := SurvivalData.wave_preview(next_wave)
                if not note.is_empty():
                                _note_hud(note)


# ==================== ОБРАБОТЧИКИ HUD ====================

func _on_hud_anomaly_requested(anomaly_type: String):
                # Закрытая аномалия: гвард в create_anomaly, здесь подсказка игроку
                var artifact_key: String = GachaData.get_artifact_for_anomaly(anomaly_type)
                var gm_hint = get_tree().get_first_node_in_group("game_manager")
                if gm_hint and not artifact_key.is_empty() and not gm_hint.is_artifact_unlocked(artifact_key):
                                var hud_locked = get_tree().get_first_node_in_group("hud")
                                if hud_locked and hud_locked.has_method("show_reward_note"):
                                                hud_locked.show_reward_note(Loc.t("hud.anomaly_locked", {"artifact": Loc.type_name(artifact_key)}))
                pass # print("Запрос аномалии: " + anomaly_type)
                var pos = _get_spawn_position_from_camera()
                var anomaly = create_anomaly(anomaly_type, pos, 1)
                if anomaly:
                                pass # print("Аномалия создана: " + anomaly_type)
                else:
                                pass # print("Не удалось создать аномалию: " + anomaly_type)


func _on_hud_mutant_requested(mutant_type: String):
                pass # print("Запрос мутанта: " + mutant_type)
                var pos = _get_spawn_position_from_camera() + Vector3.UP * 1.0
                var mutant = spawn_mutant(mutant_type, pos)
                if mutant:
                                pass # print("Мутант создан: " + mutant_type)
                else:
                                pass # print("Не удалось создать мутанта: " + mutant_type)


# ==================== РЕЖИМ «ТАП = СТАВИТЬ» (МОБИЛКА) ====================

## HUD включает/выключает режим кисти: item_id = "anomaly:X" / "mutant:X" / ""
func set_pending_placement(item_id: String):
                _pending_placement = item_id


## Тап по земле из мобильной камеры: ставим выбранное в кисти в точку
func _on_ground_tapped(world_position: Vector3):
                if _pending_placement.is_empty():
                                return
                if _pending_placement.begins_with("anomaly:"):
                                var anomaly_type: String = _pending_placement.substr(len("anomaly:"))
                                create_anomaly(anomaly_type, world_position, 1)
                elif _pending_placement.begins_with("mutant:"):
                                var mutant_type: String = _pending_placement.substr(len("mutant:"))
                                spawn_mutant(mutant_type, world_position + Vector3.UP * 1.0)


func _get_spawn_position_from_camera() -> Vector3:
                var camera = get_viewport().get_camera_3d()
                if not camera:
                                return Vector3.ZERO

                # Берём точку перед камерой и проецируем её лучом вниз на рельеф:
                # на какой бы высоте ни висела камера, аномалия ставится на землю
                var point = camera.global_position + camera.global_transform.basis.z * -10.0

                var space = get_viewport().get_world_3d().direct_space_state
                var query = PhysicsRayQueryParameters3D.new()
                query.from = Vector3(point.x, point.y + 50.0, point.z)
                query.to = Vector3(point.x, point.y - 200.0, point.z)
                query.collision_mask = 1
                var result = space.intersect_ray(query)
                if result:
                                point = result.position
                else:
                                point.y = 0.0

                # Не размещаем за периметром Зоны
                point.x = clampf(point.x, -Helpers.WORLD_LIMIT, Helpers.WORLD_LIMIT)
                point.z = clampf(point.z, -Helpers.WORLD_LIMIT, Helpers.WORLD_LIMIT)
                return point


# ==================== ОБРАБОТЧИКИ МЕНЕДЖЕРОВ ====================

func _on_energy_changed(current: float, max_val: float):
                energy_changed.emit(current, max_val)
                Signals.energy_changed.emit(current, max_val, current / max_val if max_val > 0 else 0.0)


func _on_biomass_changed(current: float, max_val: float):
                biomass_changed.emit(current, max_val)
                Signals.biomass_changed.emit(current, max_val, current / max_val if max_val > 0 else 0.0)


func can_start_pulse() -> bool:
                return event_manager.can_start_pulse() if event_manager else false


func start_radiation_pulse() -> bool:
                return event_manager.start_radiation_pulse() if event_manager else false


func _on_critical_biomass(_percent: float):
                # Аргумент обязателен: сигнал critical_biomass_reached передаёт процент,
                # и вызов без параметра отклонялся Godot - выброс никогда не запускался
                # Канон: выброс запускается ТОЛЬКО кнопкой за 1000 энергии
                pass # print("Критический уровень биомассы! (Выброс - только за 1000 энергии)")


func _on_radiation_pulse_started(level: int):
                # В кампании эскалация живёт на уровнях кампании, выброс сложность не крутит
                if not run_params.has("campaign_params"):
                                progression_manager.increase_difficulty()
                                event_manager.set_difficulty(progression_manager.get_current_difficulty())

                radiation_pulse_started.emit(level)
                Signals.radiation_pulse_started.emit(level, pulse_duration)

                # Визуальные/звуковые эффекты
                if particle_manager:
                                particle_manager.spawn_pulse_effect()
                if sound_manager:
                                sound_manager.play_pulse_warning()

                pass # print("ВЫБРОС начался! Уровень: " + str(level))


func _on_radiation_pulse_ended():
                # БАГ "биомасса ебанулась после выброса": здесь было
                # current_biomass = max_biomass * 0.3. При max_biomass=999999 это
                # ~300К: счётчик после КАЖДОГО выброса скакал до ~300К, а при победе
                # (выбросы - условие победы) "неизрасходованный остаток"
                # (current - accumulated) в _collect_run_result вливал те же ~300К
                # в награду - баланс раздувался дважды. Накачка убрана: биомасса за
                # сжигённых выбросом сталкеров честно приходит через biomass_return
                # во время импульса. Защёлка критического уровня снимается сама,
                # когда баланс ниже порога (40% max) - отдельный сброс не нужен.
                radiation_pulse_ended.emit()
                Signals.radiation_pulse_ended.emit()
                pass # print("Выброс закончился")


func _on_wave_started(wave_number: int, count: int):
                wave_started.emit(wave_number, count)
                Signals.wave_started.emit(wave_number, count, progression_manager.get_current_difficulty())

                pass # print("Волна " + str(wave_number) + " началась, сталкеров: " + str(count))

                # Анонс события выживания (волна уже усилена в _on_wave_ended прошлой волны)
                if run_params.get("run_mode", "") == "survival" and _pending_event:
                                var hud = get_tree().get_first_node_in_group("hud")
                                if hud and hud.has_method("show_event_note"):
                                                hud.show_event_note(_pending_event)
                # Фаза легенды: активация модификатора волны / выбросной таймер / вход в фазу
                if run_params.get("run_mode", "") == "survival":
                                _wave_modifier = _next_wave_modifier
                                _apply_wave_modifier(_wave_modifier)
                                if SurvivalData.is_blowout_wave(wave_number):
                                                _start_blowout_countdown()
                                var phase_note := SurvivalData.get_phase_note(wave_number)
                                if not phase_note.is_empty() and not _phase_announced.has(wave_number):
                                                _phase_announced[wave_number] = true
                                                _note_hud(phase_note)
                                                _update_postfx_strength()


func _on_wave_ended(wave_number: int, survivors: int):
                wave_ended.emit(wave_number, survivors)
                Signals.wave_ended.emit(wave_number, survivors, spawn_manager.get_stalker_count())

                pass # print("Волна " + str(wave_number) + " закончилась, выжило: " + str(survivors))

                # Фаза легенды: снять модификатор завершившейся волны
                if run_params.get("run_mode", "") == "survival":
                                _clear_wave_modifier()

                                # Следующая волна: параметры + стат её модификатора + анонс в передышке
                                var next_wave := wave_number + 1
                                var next_params := SurvivalData.get_wave_params(
                                                next_wave, run_params.get("campaign_mode", CampaignData.MODE_NORMAL))
                                _next_wave_modifier = SurvivalData.get_wave_modifier(next_wave)
                                if _next_wave_modifier.has("stat_mult"):
                                                var stat_m: float = float(_next_wave_modifier["stat_mult"])
                                                next_params["hp_mult"] = float(next_params["hp_mult"]) * stat_m
                                                next_params["damage_mult"] = float(next_params["damage_mult"]) * stat_m
                                _apply_survival_wave(next_params)
                                _preview_survival_wave(next_wave)

                                _grant_wave_milestone(wave_number)
                                _grant_survival_rolls(wave_number)
                                _grant_survival_event_reward(wave_number)
                                _prepare_survival_event(wave_number + 1)


## Крутки за пройденный уровень кампании: 5-й +3, 10-й +5
func _grant_campaign_rolls():
                if not run_params.has("campaign_params"):
                                return
                var completed: int = int(run_params.get("campaign_level", 0))
                var gm_rolls = get_tree().get_first_node_in_group("game_manager")
                if not gm_rolls:
                                return
                var rolls: int = GachaData.campaign_roll_reward(completed)
                if rolls > 0:
                                gm_rolls.grant_mutant_rolls(rolls, "кампания: уровень " + str(completed))
                                _gacha_rewards_log.append(Loc.t("reward.gacha_rolls", {"n": rolls}))
                var anomaly_rolls: int = GachaData.campaign_anomaly_roll_reward(completed)
                if anomaly_rolls > 0:
                                gm_rolls.grant_anomaly_rolls(anomaly_rolls, "кампания: уровень " + str(completed))
                                _gacha_rewards_log.append(Loc.t("reward.anomaly_rolls", {"n": anomaly_rolls}))


## Крутки за каждые 10 волн выживания (видимо в HUD сразу)
func _grant_survival_rolls(wave_number: int):
                var gm_rolls = get_tree().get_first_node_in_group("game_manager")
                if not gm_rolls:
                                return
                var hud_rolls = get_tree().get_first_node_in_group("hud")
                var rolls: int = GachaData.survival_roll_reward(wave_number)
                if rolls > 0:
                                gm_rolls.grant_mutant_rolls(rolls, "выживание: волна " + str(wave_number))
                                _gacha_rewards_log.append(Loc.t("reward.gacha_rolls", {"n": rolls}))
                                if hud_rolls and hud_rolls.has_method("show_reward_note"):
                                                hud_rolls.show_reward_note(Loc.t("hud.rolls_note", {"n": rolls}))
                var anomaly_rolls: int = GachaData.survival_anomaly_roll_reward(wave_number)
                if anomaly_rolls > 0:
                                gm_rolls.grant_anomaly_rolls(anomaly_rolls, "выживание: волна " + str(wave_number))
                                _gacha_rewards_log.append(Loc.t("reward.anomaly_rolls", {"n": anomaly_rolls}))
                                if hud_rolls and hud_rolls.has_method("show_reward_note"):
                                                hud_rolls.show_reward_note(Loc.t("hud.anomaly_rolls_note", {"n": anomaly_rolls}))


# ==================== СОБЫТИЯ ВЫЖИВАНИЯ ====================

var _pending_event: Dictionary = {}


## Волна-событие отбита: усиленная награда (биомасса x множитель + жирная гача)
func _grant_survival_event_reward(wave_number: int):
                if is_run_finished or not ZoneEvents.is_event_wave(wave_number):
                                return
                var event: Dictionary = ZoneEvents.get_event(wave_number)
                var reward: float = 150.0 * float(event.get("reward_mult", 1.0))
                if resource_manager:
                                resource_manager.add_biomass(reward)
                pass # print("=== СОБЫТИЕ ОТБИТО: ", event.get("title_ru", ""), " - награда ", reward, " биомассы ===")
                # Гача события с бонусом уровня: выше волна - жирнее дроп
                var gacha_level: int = 1
                var gm = get_tree().get_first_node_in_group("game_manager")
                if gm:
                                gacha_level = gm.get_campaign_level()
                _grant_gacha_rewards(clampi(gacha_level + int(event.get("gacha_bonus", 0)), 1, 100))


## Следующая волна - событие: усиливаем состав и статы поверх эскалации выживания
func _prepare_survival_event(next_wave: int):
                if not ZoneEvents.is_event_wave(next_wave):
                                return
                var event: Dictionary = ZoneEvents.get_event(next_wave)
                spawn_manager.set_rank_weights(event.get("mix", [50, 50, 0]))
                spawn_manager.min_stalkers_per_wave = int(float(spawn_manager.min_stalkers_per_wave) * float(event.get("count_mult", 1.0)))
                spawn_manager.max_stalkers_per_wave = int(float(spawn_manager.max_stalkers_per_wave) * float(event.get("count_mult", 1.0)))
                spawn_manager.set_campaign_scaling(
                                spawn_manager.campaign_hp_mult * float(event.get("hp_mult", 1.0)),
                                spawn_manager.campaign_damage_mult * float(event.get("dmg_mult", 1.0)),
                                spawn_manager.campaign_speed_mult)
                _pending_event = event
                pass # print("=== СОБЫТИЕ (волна ", next_wave, "): ", event.get("title_ru", ""), " - враг сильнее, награда щедрее ===")


func _grant_wave_milestone(waves: int):
                """Вехи выживания (10/20/30/40/50, цикл 60+): SurvivalData.get_milestone.
                Замена крана GachaData.milestone_wave_reward (там >=30 капало ежеволнно)."""
                var reward: Dictionary = SurvivalData.get_milestone(waves)
                if reward.is_empty() or is_run_finished:
                                return
                pass # print("=== ВЕХА ВЫЖИВАНИЯ: ", reward.get("label", ""), " ===")
                if reward.has("mutant"):
                                spawn_manager.queue_reward_mutant(reward["mutant"])
                                # Мутант мог открыться впервые - обновляем замки в HUD
                                var hud = get_tree().get_first_node_in_group("hud")
                                if hud and hud.has_method("refresh_mutant_unlocks"):
                                                hud.refresh_mutant_unlocks()
                if reward.has("artifact"):
                                _grant_artifact_reward(reward["artifact"], reward.get("label", ""))
                var gm_milestone = get_tree().get_first_node_in_group("game_manager")
                if reward.has("rolls") and gm_milestone and gm_milestone.has_method("grant_mutant_rolls"):
                                gm_milestone.grant_mutant_rolls(int(reward["rolls"]), "выживание: веха " + str(waves))
                if reward.has("anomaly_rolls") and gm_milestone and gm_milestone.has_method("grant_anomaly_rolls"):
                                gm_milestone.grant_anomaly_rolls(int(reward["anomaly_rolls"]), "выживание: веха " + str(waves))
                if reward.has("biomass") and resource_manager:
                                resource_manager.add_biomass(float(reward["biomass"]))
                var reward_hud = get_tree().get_first_node_in_group("hud")
                if reward_hud and reward_hud.has_method("show_reward_note"):
                                reward_hud.show_reward_note("ВЕХА: %s" % reward.get("label", str(waves)))


func _grant_artifact_reward(artifact_type: String, _source_label: String):
                """Артефакт-награда: спавнится у монолита как реликвия + ресурсный бонус.
                Звёзды типа умножают бонус и ценность реликвии"""
                var rarity := "common"
                for r in ["legendary", "rare"]:
                                if GachaData.ARTIFACT_POOL[r].has(artifact_type):
                                                rarity = r
                                                break
                # Звёзды артефакта читаем живьём из коллекции (дубли в гаче качают звёзды mid-run)
                var stars := 1
                var gm = get_tree().get_first_node_in_group("game_manager")
                if gm and gm.get_lab_data():
                                stars = gm.get_lab_data().get_artifact_stars(artifact_type)
                var star_mult := LabData.get_star_stat_mult(stars)
                var bonus: Array = GachaData.ARTIFACT_BONUS[rarity].duplicate()
                bonus[0] = bonus[0] * star_mult
                bonus[1] = bonus[1] * star_mult
                if resource_manager:
                                resource_manager.add_energy(bonus[0])
                                resource_manager.add_biomass(bonus[1])
                var monolith = get_tree().get_first_node_in_group("monolith")
                var drop_pos: Vector3 = monolith.global_position + Vector3(6.0, 0.0, 6.0) if monolith else Vector3(6.0, 0.0, 6.0)
                pass # print("=== НАГРАДА (", source_label, "): артефакт ", artifact_type, " (", rarity, ", ", stars, "★) +", bonus[0], " энергии, +", bonus[1], " биомассы ===")
                _gacha_rewards_log.append(Loc.t("reward.gacha_artifact", {"name": Loc.type_name(artifact_type)}))
                # Новый арт открывает свою аномалию - обновляем замки HUD
                var hud_unlock = get_tree().get_first_node_in_group("hud")
                if hud_unlock and hud_unlock.has_method("refresh_mutant_unlocks"):
                                hud_unlock.refresh_mutant_unlocks()
                var reward_value: float = 10.0 if rarity == "common" else (30.0 if rarity == "rare" else 80.0)
                anomaly_manager.create_artifact(artifact_type, drop_pos, rarity, reward_value * star_mult)


func _grant_gacha_rewards(level: int):
                """Гача за пройденный уровень кампании: мутант + артефакт по уровню"""
                var gm = get_tree().get_first_node_in_group("game_manager")
                var mutant_roll: Dictionary = GachaData.roll_mutant_gacha(level)
                var artifact_roll: Dictionary = GachaData.roll_artifact_gacha(level)

                # Химера - гарантия середины кампании (уровень 50), если не выпала из гачи
                if level >= GachaData.CHIMERA_GUARANTEE_LEVEL and gm and not gm.has_chimera_unlocked():
                                mutant_roll = {"type": "chimera", "rarity": "legendary", "guaranteed": true}

                var _unlocked_msg := ""
                if gm:
                                pass # (лог отключён)
                                # Дубль качнул звёзды - спавнящиеся мутанты должны узнать об этом сразу
                                if spawn_manager and gm.get_lab_data():
                                                spawn_manager.set_mutant_stars(gm.get_lab_data().mutant_stars)
                spawn_manager.queue_reward_mutant(mutant_roll["type"])
                pass # print("=== ГАЧА МУТАНТОВ (ур. ", level, "): ", mutant_roll["type"], " [", mutant_roll["rarity"], "] ", unlocked_msg, " ===")
                _gacha_rewards_log.append(Loc.t("reward.gacha_mutant", {"name": Loc.type_name(mutant_roll["type"])}))

                _grant_artifact_reward(artifact_roll["type"], "гача ур. " + str(level))
                if gm:
                                gm.grant_artifact_reward(artifact_roll["type"])
                # Видимая награда: нота в HUD
                var hud_reward = get_tree().get_first_node_in_group("hud")
                if hud_reward and hud_reward.has_method("show_reward_note"):
                                hud_reward.show_reward_note(Loc.t("hud.reward_note", {
                                                "text": Loc.type_name(mutant_roll["type"]) + " + " + Loc.type_name(artifact_roll["type"])}))


# Трофеи: артефакты с убитых сталкеров-носителей идут в хранилище
var _trophy_artifacts: Array = []


func _on_stalker_died(stalker: Node, biomass_returned: float):
                if stalker and stalker.has_method("has_artifact") and stalker.has_artifact():
                                var rarity: String = stalker.get_artifact_rarity() if stalker.has_method("get_artifact_rarity") else "common"
                                var value: int = int(stalker.get_artifact_value()) if stalker.has_method("get_artifact_value") else 10
                                if rarity == "":
                                                rarity = "common"
                                _trophy_artifacts.append({"type": rarity, "value": value})
                                pass # print("Трофей: артефакт (", rarity, ", ", value, ") убитого сталкера - в хранилище")
                # Биомассу начисляет ТОЛЬКО BaseStalker._on_died -> on_stalker_died:
                # здесь был второй счёт (плюс третий в SpawnManager) - доход завышался втрое
                progression_manager.record_stalker_killed()

                var stalker_type = "unknown"
                if stalker.has_method("get_stalker_type"):
                                stalker_type = stalker.get_stalker_type()

                Signals.stalker_died.emit(stalker, stalker_type, stalker.global_position, biomass_returned)
                # (лог отключён)


func _on_mutant_spawned(_mutant: Node, _mutant_type: String):
                progression_manager.record_mutant_spawned()
                # Рык нового мутанта (пак CC0: bloodsucker/chimera/controller/flesh/
                # poltergeist/pseudodog/snork/zombie; пёс озвучен псевдопсом)
                var sm = get_tree().get_first_node_in_group("sound_manager")
                if sm and sm.has_method("play_mutant_spawn_sound"):
                                sm.play_mutant_spawn_sound(_mutant_type)
                pass # print("Мутант заспавнен: " + mutant_type)


func _on_anomaly_created(anomaly: Node, anomaly_type: String, _difficulty: int):
                if particle_manager:
                                particle_manager.spawn_anomaly_effects(anomaly.global_position, anomaly_type)
                if sound_manager:
                                sound_manager.play_anomaly_sound(anomaly_type)

                progression_manager.record_anomaly_created()
                pass # print("Аномалия создана: " + anomaly_type)


func _on_anomaly_destroyed(anomaly_type: String, position: Vector3, difficulty: int):
                # Создаем артефакт
                var artifact_type = anomaly_artifact_map.get(anomaly_type, "common")
                var rarity = difficulty_to_rarity.get(difficulty, "common")
                var values = artifact_values.get(rarity, [10])
                var value = values[randi() % values.size()]

                create_artifact(artifact_type, position, rarity, value)

                if particle_manager:
                                particle_manager.spawn_particles_at(position, "spark", 1.0)

                pass # print("Аномалия уничтожена, создан артефакт: " + artifact_type)


func _on_artifact_created(_artifact: Node, _artifact_type: String, position: Vector3):
                if particle_manager:
                                particle_manager.spawn_particles_at(position, "spark", 0.5)

                pass # print("Артефакт создан: " + artifact_type)


func _on_artifact_stolen(artifact: Node, stalker: Node):
                var loss = 10.0
                if artifact.has_method("get_value"):
                                loss = artifact.get_value()

                resource_manager.spend_biomass(loss)
                progression_manager.record_artifact_stolen()

                Signals.artifact_stolen.emit(artifact, stalker, loss)
                pass # print("Артефакт украден! Потеряно биомассы: " + str(loss))


func _on_game_over():
                game_over.emit()
                Signals.game_over.emit(false, progression_manager.get_current_run(), 0)

                pass # print("GAME OVER")
                finish_run(false)


func _on_game_won(run_number: int, reward: float):
                # В кампании награда считается в _collect_run_result (боевой доход + бонус уровня);
                # дефолтная формула event_manager (100 x забег x сложность) в кампанию не течёт
                if not run_params.has("campaign_params"):
                                resource_manager.add_biomass(reward)
                game_won.emit(run_number, reward)
                Signals.game_won.emit(run_number, reward)

                pass # print("ПОБЕДА! Забег #" + str(run_number) + " награда: " + str(reward))
                # Гача по уровню КАМПАНИИ, а не по номеру забега
                var gacha_level := run_number
                if run_params.has("campaign_params"):
                                gacha_level = int(run_params.get("campaign_level", run_number))
                _grant_gacha_rewards(clampi(gacha_level, 1, 100))
                _grant_campaign_rolls()
                finish_run(true)


# ==================== ПУБЛИЧНОЕ API ====================

# Ресурсы
func get_energy() -> float: 
                return resource_manager.get_energy() if resource_manager else 0.0

func get_biomass() -> float: 
                return resource_manager.get_biomass() if resource_manager else 0.0

func add_energy(amount: float): 
                if resource_manager: resource_manager.add_energy(amount)

func add_biomass(amount: float): 
                if resource_manager: resource_manager.add_biomass(amount)

func spend_energy(amount: float) -> bool: 
                return resource_manager.spend_energy(amount) if resource_manager else false

func spend_biomass(amount: float) -> bool: 
                return resource_manager.spend_biomass(amount) if resource_manager else false

func can_afford(energy: float, biomass: float) -> bool: 
                return resource_manager.can_afford(energy, biomass) if resource_manager else false

# Аномалии
func create_anomaly(type: String, position: Vector3, difficulty: int = 1) -> Node:
                if not anomaly_manager:
                                return null

                # Гейтинг: каждый арт открывает свою аномалию, пока арта нет - в бой нельзя
                var artifact_key: String = GachaData.get_artifact_for_anomaly(type)
                var gm_guard = get_tree().get_first_node_in_group("game_manager")
                if gm_guard and not artifact_key.is_empty() and not gm_guard.is_artifact_unlocked(artifact_key):
                                pass # print("Зона: аномалия закрыта - нужен её артефакт (", artifact_key, ")")
                                return null

                var cost = anomaly_manager.get_anomaly_cost(type)
                if not resource_manager.spend_energy(cost):
                                pass # print("Недостаточно энергии для " + type + " (нужно: " + str(cost) + ")")
                                return null

                var anomaly = anomaly_manager.create_anomaly(type, position, difficulty, cost)
                if anomaly and gm_guard:
                                # Эксклюзив Чёрного ящика: полученная аномалия ставит усиленную версию
                                var ex_type: String = gm_guard.owned_anomaly_exclusive_for(type)
                                if not ex_type.is_empty():
                                                anomaly.apply_exclusive_anomaly(GachaData.get_exclusive_anomaly(ex_type))
                return anomaly

# Артефакты
func create_artifact(artifact_type: String, position: Vector3, rarity: String = "common", value: float = 10.0) -> Node:
                if not anomaly_manager:
                                return null
                return anomaly_manager.create_artifact(artifact_type, position, rarity, value)

# Мутанты
func spawn_mutant(mutant_type: String, position: Vector3) -> Node:
                if not spawn_manager:
                                return null

                # Гейтинг коллекции: не разблокирован кампанией/гачей - в бой не применить.
                # Наградные мутанты идут мимо (spawn_manager напрямую) - они уже разблокированы.
                # Эксклюзив Чёрного ящика заменяет базу: владеешь Пепельным снорком -
                # кнопка снорка ставит его (v0.21.0)
                var gm = get_tree().get_first_node_in_group("game_manager")
                var ex_type: String = ""
                if gm:
                                if gm.has_method("owned_mutant_exclusive_for"):
                                                ex_type = gm.owned_mutant_exclusive_for(mutant_type)
                                if not gm.is_mutant_unlocked(mutant_type) and ex_type.is_empty():
                                                pass # print("Зона: мутант не разблокирован - откройте его кампанией или гачей: " + mutant_type)
                                                return null

                var cost = spawn_manager.get_mutant_cost(mutant_type)
                if not resource_manager.spend_biomass(cost):
                                pass # print("Недостаточно биомассы для " + mutant_type + " (нужно: " + str(cost) + ")")
                                return null

                var spawn_type: String = ex_type if not ex_type.is_empty() else mutant_type
                # Звёзды прокачки хранятся по базовому виду - передаём базу отдельно
                return spawn_manager.spawn_mutant(spawn_type, position, cost, mutant_type)

# Регистрация
func register_stalker(_stalker: Node):
                # В spawn_manager.active_stalkers сталкера уже добавил SpawnManager при спавне:
                # повторный append давал двойной счётчик и «вечных» призраков после смерти
                pass

# Прямой метод для добавления биомассы при смерти сталкера
func on_stalker_died(stalker: Node, biomass_returned: float):
                if resource_manager:
                                # ЖАТВА: множитель добычи за убийство (модификатор волны легенд)
                                resource_manager.add_biomass(biomass_returned * _harvest_mult)
                                # (лог отключён)

                progression_manager.record_stalker_killed()

                var stalker_type = "unknown"
                if stalker.has_method("get_stalker_type"):
                                stalker_type = stalker.get_stalker_type()

                Signals.stalker_died.emit(stalker, stalker_type, stalker.global_position, biomass_returned)

# Информация
func get_difficulty() -> float: 
                return progression_manager.get_current_difficulty() if progression_manager else 1.0

func get_run_number() -> int: 
                return progression_manager.get_current_run() if progression_manager else 1

func get_pulse_count() -> int: 
                return event_manager.get_pulse_count() if event_manager else 0

func get_pulses_remaining() -> int: 
                return event_manager.get_pulses_remaining() if event_manager else pulses_to_win

func is_radiating() -> bool: 
                return event_manager.is_pulse_active() if event_manager else false

func has_won() -> bool: 
                return event_manager.has_won() if event_manager else false

func get_status() -> Dictionary:
                return {
                                "energy": get_energy(),
                                "max_energy": max_energy,
                                "biomass": get_biomass(),
                                "max_biomass": max_biomass,
                                "difficulty": get_difficulty(),
                                "run_number": get_run_number(),
                                "pulse_count": get_pulse_count(),
                                "pulses_remaining": get_pulses_remaining(),
                                "radiating": is_radiating(),
                                "stalkers": spawn_manager.get_stalker_count() if spawn_manager else 0,
                                "mutants": spawn_manager.get_mutant_count() if spawn_manager else 0,
                                "anomalies": anomaly_manager.get_anomaly_count() if anomaly_manager else 0,
                                "artifacts": anomaly_manager.get_artifact_count() if anomaly_manager else 0
                }


# ==================== ЗАВЕРШЕНИЕ ЗАБЕГА ====================

func finish_run(success: bool):
                # Защита от повторного вызова (несколько сталкеров у монолита / game_over)
                if is_run_finished:
                                return
                is_run_finished = true

                pass # print("Завершение забега. Успех: " + str(success))

                # Останавливаем спавн
                if spawn_manager:
                                spawn_manager.stop_spawning()

                # Собираем результаты
                var result = _collect_run_result(success)

                # Передаем в GameManager
                var gm = get_tree().get_first_node_in_group("game_manager")
                if gm and gm.has_method("process_run_result"):
                                gm.process_run_result(result)

                # Церемония башни вместо мёртвой паузы (баннер/звёзды/конфетти/переход);
                # остальные режимы - как раньше, короткая пауза
                if run_params.get("run_mode", "") == "tower":
                                var ceremony := CeremonyOverlay.new()
                                add_child(ceremony)
                                await ceremony.play(result)
                                ceremony.queue_free()
                else:
                                await get_tree().create_timer(3.0).timeout
                get_tree().change_scene_to_file("res://scenes/lab/lab.tscn")


func _collect_run_result(success: bool) -> Dictionary:
                var run_number = progression_manager.get_current_run() if progression_manager else 1
                var reward = resource_manager.accumulated_biomass if resource_manager else 0.0
                # Неизрасходованный стартовый капитал (остаток лаборатории + 300 базы)
                # возвращается в награду: иначе он сгорает и награда меньше накопленного в бою
                if resource_manager:
                                var leftover: float = resource_manager.current_biomass - resource_manager.accumulated_biomass
                                if leftover > 0.0:
                                                reward += leftover

                # Кампания: бонус за уровень поверх боевого дохода; реплей пройденного - 30% бонуса
                if success and run_params.has("campaign_params"):
                                var campaign: Dictionary = run_params["campaign_params"]
                                var bonus: float = float(campaign.get("reward_bonus", 0.0))
                                if bool(run_params.get("campaign_replay", false)):
                                                bonus *= CampaignData.REPLAY_REWARD_FACTOR
                                reward += bonus

                # Выживание: награда за пройденные волны платится при любом исходе -
                # смерть здесь ожидаемый конец забега, а не провал
                var waves_survived := 0
                var final_success := success
                var victory_reason := ""
                var arena_target := 0
                if run_params.get("run_mode", "") == "survival":
                                waves_survived = maxi(0, (spawn_manager.current_wave if spawn_manager else 1) - 1)
                                reward += SurvivalData.wave_bonus(waves_survived)
                                # Логика победы (v0.21.0 «ЛИГА ВОЛН»):
                                # 1) арена-вызов: волна вызванного превзойдена - ПОБЕДА
                                var gm_node = get_tree().get_first_node_in_group("game_manager")
                                if gm_node != null:
                                                var t = gm_node.get("arena_target_wave")
                                                if t != null:
                                                                arena_target = int(t)
                                if arena_target > 0 and waves_survived > arena_target:
                                                final_success = true
                                                victory_reason = "arena_target"
                                # 2) пережил 30+ волн - ПОБЕДА независимо от волны гибели
                                elif waves_survived >= SurvivalData.VICTORY_WAVE:
                                                final_success = true
                                                victory_reason = "waves30"

                var stats = {
                                "stalkers_killed": progression_manager.get_stalkers_killed() if progression_manager else 0,
                                "anomalies_created": progression_manager.get_anomalies_created() if progression_manager else 0,
                                "mutants_created": progression_manager.get_mutants_spawned() if progression_manager else 0,
                                "artifacts_stolen": progression_manager.get_artifacts_stolen() if progression_manager else 0,
                                "biomass_earned": resource_manager.accumulated_biomass if resource_manager else 0.0,
                                "biomass_spent": 0
                }

                return {
                                "success": final_success,
                                "run_number": run_number,
                                "mode": str(run_params.get("run_mode", "campaign")),
                        "tower_floor": int(run_params.get("tower_floor", 0)),
                        "stalkers_total": (spawn_manager.get_stalkers_killed() if spawn_manager else 0) + (spawn_manager.get_stalker_count() if spawn_manager else 0),
                        "stalkers_killed_sm": spawn_manager.get_stalkers_killed() if spawn_manager else 0,
                        "pulses_used": event_manager.get_pulse_count() if event_manager else 0,
                                "campaign_level": int(run_params.get("campaign_level", 0)),
                                "waves_survived": waves_survived,
                                "victory_reason": victory_reason,
                                "arena_target_wave": arena_target,
                                "reward": reward,
                                "statistics": stats,
                                "gacha_rewards": _gacha_rewards_log.duplicate(),
                                "artifacts_collected": _collect_artifacts() + _trophy_artifacts
                }


func _collect_artifacts() -> Array:
                var artifacts = []
                var nodes = get_tree().get_nodes_in_group("artifacts")

                for a in nodes:
                                if is_instance_valid(a) and a.has_method("get_rarity_name") and a.has_method("get_value"):
                                                artifacts.append({
                                                                "type": a.get_rarity_name(),
                                                                "value": a.get_value()
                                                })

                return artifacts
