# core/game_manager.gd
extends Node
## Глобальный менеджер игры (автозагрузка)

signal game_loaded(save_data)
signal game_saved(slot)
signal scene_changed(scene_name)

# Текущее состояние
var current_save_data = null
var is_in_lab: bool = true
var is_loading: bool = false
var current_scene_name: String = ""

# Уровень кампании, выбранный в лаборатории для следующего забега.
# 0 = идти на текущий рубеж (campaign_level сейва)
var selected_campaign_level: int = 0

# Режим следующего забега: "campaign", "tower" или "survival" (выбор в
# лаборатории, запоминается в настройках клиента)
var selected_run_mode: String = "campaign"

# Этаж Башни Монолита, выбранный в лаборатории (1..TowerData.TOTAL_FLOORS).
# Открытый рубеж хранится в сейве (tower_floor), выбранный этаж - в настройках.
var selected_tower_floor: int = 1

# Константы
const SAVE_DIR = "user://saves/"
const SAVE_FILE_PREFIX = "save_"
const SAVE_FILE_EXT = ".tres"
# Настройки клиента (вне сейвов): активный слот сохранения
const SETTINGS_PATH = "user://settings.cfg"
const AUTOSAVE_SLOT = 0
const MANUAL_SLOTS = 3

# Активный слот: 0 - автосейв, 1..3 - ручные слоты. Выбирается в настройках,
# привязывается при загрузке слота через главное меню
var active_save_slot: int = 0


func _ready():
        add_to_group("game_manager")
        pass # print("GameManager: инициализирован")
        _create_save_directory()
        _load_settings()
        _load_boot_save()
        Signals.game_started.emit()


func grant_mutant_reward(mutant_type: String, _rarity: String) -> String:
        """Награда гачи: новый мутант в коллекцию, дубль - КОПИЯ на ферму.
        Копию можно скормить на звезду этого же типа или как корм другому."""
        if not current_save_data or not current_save_data.lab_data:
                return ""
        var lab = current_save_data.lab_data
        if lab.unlocked_mutants.has(mutant_type):
                var copies: int = lab.add_farm_copy(mutant_type)
                save_game(0)
                return "ДУБЛЬ: копия на ферме (всего %d)" % copies
        lab.unlocked_mutants.append(mutant_type)
        save_game(0)
        return "НОВЫЙ МУТАНТ В КОЛЛЕКЦИИ"


func grant_artifact_reward(artifact_type: String):
        """Награда гачи: артефакт в коллекцию Зоны. Дубль даёт +1 звезду"""
        if not current_save_data or not current_save_data.lab_data:
                return
        var lab = current_save_data.lab_data
        if lab.won_artifacts.has(artifact_type):
                lab.add_artifact_star(artifact_type)
        else:
                lab.won_artifacts.append(artifact_type)
        save_game(0)


func upgrade_mutant_star(mutant_type: String) -> bool:
        """Лаборатория: поднять звезду мутанта за биомассу (500 * 2^(звёзды-1))"""
        var lab = get_lab_data()
        if not lab.unlocked_mutants.has(mutant_type):
                pass # print("Звёзды: мутант не в коллекции: " + mutant_type)
                return false
        var stars: int = lab.get_mutant_stars(mutant_type)
        if stars >= LabData.MAX_STARS:
                pass # print("Звёзды: у " + mutant_type + " уже максимальные звёзды")
                return false
        var cost: float = lab.get_star_upgrade_cost(stars)
        if lab.biomass < cost:
                pass # print("Звёзды: недостаточно биомассы (нужно %.0f, есть %.0f)" % [cost, lab.biomass])
                return false
        lab.biomass -= cost
        lab.add_mutant_star(mutant_type)
        pass # print("Звёзды: %s теперь %d/%d★ (за %.0f биомассы)" % [mutant_type, stars + 1, LabData.MAX_STARS, cost])
        save_to_active_slot()
        return true


func upgrade_artifact_star(artifact_type: String) -> bool:
        var lab = get_lab_data()
        if not lab.won_artifacts.has(artifact_type):
                pass # print("Звёзды: артефакт не в коллекции: " + artifact_type)
                return false
        var stars: int = lab.get_artifact_stars(artifact_type)
        if stars >= LabData.MAX_STARS:
                pass # print("Звёзды: у " + artifact_type + " уже максимальные звёзды")
                return false
        var cost: float = lab.get_star_upgrade_cost(stars)
        if lab.biomass < cost:
                pass # print("Звёзды: недостаточно биомассы (нужно %.0f, есть %.0f)" % [cost, lab.biomass])
                return false
        lab.biomass -= cost
        lab.add_artifact_star(artifact_type)
        pass # print("Звёзды: %s теперь %d/%d★ (за %.0f биомассы)" % [artifact_type, stars + 1, LabData.MAX_STARS, cost])
        save_to_active_slot()
        return true


# ==================== ФЕРМА: КОПИИ И КОРМ ====================

## Рецепт новой звезды N: N копий цели + 1 звёздный корм (копия мутанта
## той же звёздности, что и цель) + простые корма (2/4/6/8 копий 1★)
func get_star_requirements(mutant_type: String) -> Dictionary:
        var lab = get_lab_data()
        var stars: int = lab.get_mutant_stars(mutant_type)
        var copies_need: int = stars + 1
        var star_feed_need := 1
        var simple_need: int = GachaData.get_star_feed_cost(stars)
        var copies_have: int = lab.get_farm_copies(mutant_type)
        var star_have: int = lab.get_star_feed(mutant_type)
        var simple_have: int = lab.get_star_progress(mutant_type)
        var has_enough := copies_have >= copies_need and star_have >= star_feed_need and simple_have >= simple_need
        return {
                "stars": stars,
                "max": stars >= LabData.MAX_STARS,
                "copies_have": copies_have, "copies_need": copies_need,
                "star_have": star_have, "star_need": star_feed_need,
                "simple_have": simple_have, "simple_need": simple_need,
                "ready": has_enough,
        }


## Повысить звезду по полному рецепту (кнопка на ферме)
## Утилизация копий с фермы: очки по редкости (1/2/3/5),
## каждые 10 очков = 1 крутка артефактов, остаток копится в lab.recycle_points
func recycle_copies(batch: Dictionary) -> Dictionary:
        var lab = get_lab_data()
        var points: int = lab.recycle_points
        var consumed := 0
        for t in batch:
                var type := str(t)
                var have: int = lab.get_farm_copies(type)
                var cnt: int = mini(int(batch[t]), have)
                for i in range(cnt):
                        lab.consume_farm_copy(type)
                        points += GachaData.get_fodder_value(type, true)
                        consumed += 1
        var rolls: int = int(points / 10.0)
        lab.recycle_points = points % 10
        if rolls > 0:
                grant_anomaly_rolls(rolls, "утилизация копий")
        else:
                save_to_active_slot()
        pass # print("Утилизация: %d копий = %d очков -> %d круток (остаток %d)" % [consumed, points, rolls, lab.recycle_points])
        return {"rolls": rolls, "consumed": consumed, "points": points, "leftover": lab.recycle_points}


## Применить собранный в диалоге рецепт разом: копии цели + звёздный корм +
## словарь простых кормов {тип: количество}. Всё проверяется и списывается здесь.
func apply_star_recipe(target: String, copies: int, star_feed: String, simple: Dictionary) -> String:
        var lab = get_lab_data()
        var req: Dictionary = get_star_requirements(target)
        if bool(req.get("max")):
                return "Звёзды уже максимальны"
        var copies_need: int = int(req.get("copies_need"))
        if copies < copies_need:
                return "Нужно копий цели: %d/%d" % [copies, copies_need]
        if lab.get_star_feed(target) < 1 and star_feed.is_empty():
                return "Нужен звёздный корм - копия мутанта с %d★" % int(req.get("stars"))
        if lab.get_star_feed(target) < 1 and not star_feed.is_empty() and lab.get_mutant_stars(star_feed) != int(req.get("stars")):
                return "Звёздный корм должен быть с %d★ (у %s %d★)" % [int(req.get("stars")), GachaData.display_name(star_feed), lab.get_mutant_stars(star_feed)]
        var simple_need: int = int(req.get("simple_need"))
        if lab.get_star_progress(target) < simple_need:
                var total: int = lab.get_star_progress(target)
                for t in simple:
                        total += int(simple[t])
                if total < simple_need:
                        return "Нужно простых кормов: %d/%d" % [total, simple_need]
        # Бюджет копий цели: слот копий + звёздный корм + простые из себя - не больше запаса
        var self_needed: int = copies
        if star_feed == target:
                self_needed += 1
        self_needed += int(simple.get(target, 0))
        if self_needed > lab.get_farm_copies(target):
                return "Не хватает копий цели: нужно %d, на ферме %d" % [self_needed, lab.get_farm_copies(target)]
        
        # Списываем копии цели
        for i in range(copies):
                lab.consume_farm_copy(target)
        # Звёздный корм (если ещё не заполнен быстрым кормлением)
        if lab.get_star_feed(target) < 1 and not star_feed.is_empty():
                lab.consume_farm_copy(star_feed)
                lab.add_star_feed(target)
        # Простые корма с клампом до потребности
        for t in simple:
                var remaining: int = simple_need - lab.get_star_progress(target)
                if remaining <= 0:
                        break
                var cnt: int = mini(int(simple[t]), lab.get_farm_copies(str(t)))
                cnt = mini(cnt, remaining)
                for i in range(cnt):
                        lab.consume_farm_copy(str(t))
                        lab.add_star_progress(target, 1)
        
        lab.clear_star_progress(target)
        lab.star_feed_progress.erase(target)
        lab.add_mutant_star(target)
        var new_stars: int = lab.get_mutant_stars(target)
        pass # print("Ферма: рецепт применён - %s -> %d/%d★" % [target, new_stars, LabData.MAX_STARS])
        save_to_active_slot()
        return "ЗВЕЗДА! %s теперь %d/%d★" % [GachaData.display_name(target), new_stars, LabData.MAX_STARS]


func try_upgrade_star(mutant_type: String) -> String:
        var lab = get_lab_data()
        var req: Dictionary = get_star_requirements(mutant_type)
        if bool(req.get("max")):
                return "Звёзды уже максимальны"
        if int(req.get("copies_have")) < int(req.get("copies_need")):
                return "Нужно копий: %d/%d" % [int(req.get("copies_have")), int(req.get("copies_need"))]
        if int(req.get("star_have")) < int(req.get("star_need")):
                return "Нужен звёздный корм: копия мутанта с %d★" % int(req.get("stars"))
        if int(req.get("simple_have")) < int(req.get("simple_need")):
                return "Нужно простых кормов: %d/%d" % [int(req.get("simple_have")), int(req.get("simple_need"))]
        for i in range(int(req.get("copies_need"))):
                lab.consume_farm_copy(mutant_type)
        lab.clear_star_progress(mutant_type)
        lab.star_feed_progress.erase(mutant_type)
        lab.add_mutant_star(mutant_type)
        var new_stars: int = lab.get_mutant_stars(mutant_type)
        pass # print("Ферма: %s -> %d/%d★ (копий списано %d)" % [mutant_type, new_stars, LabData.MAX_STARS, int(req.get("copies_need"))])
        save_to_active_slot()
        return "ЗВЕЗДА! %s теперь %d/%d★" % [GachaData.display_name(mutant_type), new_stars, LabData.MAX_STARS]


## Начислить крутки гачи МУТАНТОВ
func grant_mutant_rolls(count: int, _source: String = ""):
        if count <= 0 or not current_save_data or not current_save_data.lab_data:
                return
        var lab = current_save_data.lab_data
        lab.gacha_rolls_mutants += count
        pass # print("Крутки гачи мутантов +", count, " (", source, "), всего ", lab.gacha_rolls_mutants)
        save_to_active_slot()


## Начислить крутки АНОМАЛИЙНОЙ гачи (артефакты открывают аномалии)
func grant_anomaly_rolls(count: int, _source: String = ""):
        if count <= 0 or not current_save_data or not current_save_data.lab_data:
                return
        var lab = current_save_data.lab_data
        lab.gacha_rolls_artifacts += count
        pass # print("Аномалийные крутки +", count, " (", source, "), всего ", lab.gacha_rolls_artifacts)
        save_to_active_slot()


# ==================== ГАЧА: КРУТКИ ====================

## Батч-крутка гачи мутантов: новый -> коллекция, дубль -> копия на ферму.
## Возвращает список {type, rarity, status}, status: new/dup
func spin_mutant_gacha(times: int) -> Array:
        var results: Array = []
        if times <= 0 or not current_save_data or not current_save_data.lab_data:
                return results
        var lab = current_save_data.lab_data
        times = mini(times, int(lab.gacha_rolls_mutants))
        if times <= 0:
                pass # print("Гача: крутки мутантов закончились")
                return results
        var level := get_campaign_level()
        for i in range(times):
                var roll: Dictionary = GachaData.roll_mutant_gacha(level)
                if lab.unlocked_mutants.has(roll["type"]):
                        lab.add_farm_copy(roll["type"])
                        roll["status"] = "dup"
                else:
                        lab.unlocked_mutants.append(roll["type"])
                        roll["status"] = "new"
                results.append(roll)
        lab.gacha_rolls_mutants -= times
        pass # print("Гача мутантов: %d круток (ур. %d), осталось %d" % [times, level, lab.gacha_rolls_mutants])
        save_to_active_slot()
        return results


## Батч-крутка гачи артефактов: новый -> коллекция, дубль -> +1 звезда.
## status: new/star/dup_max
func spin_artifact_gacha(times: int) -> Array:
        var results: Array = []
        if times <= 0 or not current_save_data or not current_save_data.lab_data:
                return results
        var lab = current_save_data.lab_data
        times = mini(times, int(lab.gacha_rolls_artifacts))
        if times <= 0:
                pass # print("Гача: крутки артефактов закончились")
                return results
        var level := get_campaign_level()
        for i in range(times):
                var roll: Dictionary = GachaData.roll_artifact_gacha(level)
                if lab.won_artifacts.has(roll["type"]):
                        if lab.add_artifact_star(roll["type"]):
                                roll["status"] = "star"
                        else:
                                roll["status"] = "dup_max"
                else:
                        lab.won_artifacts.append(roll["type"])
                        roll["status"] = "new"
                # Ресурсный бонус артефакта: биомасса сразу в лабораторию,
                # энергия - в копилку забега (учитывается в параметрах запуска)
                lab.biomass += float(roll.get("biomass", 0.0))
                results.append(roll)
        lab.gacha_rolls_artifacts -= times
        pass # print("Гача артефактов: %d круток (ур. %d), осталось %d" % [times, level, lab.gacha_rolls_artifacts])
        save_to_active_slot()
        return results


## Скормить копию ДРУГОГО типа как корм: очки по редкости корма.
## Корм должен быть с тем же числом звёзд, что у цели (звёздная пирамида)
func feed_fodder(fodder_type: String, target_type: String) -> String:
        var lab = get_lab_data()
        if lab.get_farm_copies(fodder_type) <= 0:
                return "Нет копий корма на ферме"
        var stars: int = lab.get_mutant_stars(target_type)
        if stars >= LabData.MAX_STARS:
                return "У цели уже максимальные звёзды"
        var fodder_stars: int = lab.get_mutant_stars(fodder_type)
        lab.consume_farm_copy(fodder_type)
        # Маршрут по бакам: корм той же звёздности -> звёздный (нужен 1),
        # всё остальное -> простой (2/4/6/8 копий)
        if fodder_stars == stars and lab.get_star_feed(target_type) < 1:
                var fed: int = lab.add_star_feed(target_type)
                pass # print("Ферма: %s (%d★) -> звёздный корм для %s (%d/1)" % [fodder_type, fodder_stars, target_type, fed])
                save_to_active_slot()
                return "Звёздный корм принят (%d/1)" % fed
        var progress: int = lab.add_star_progress(target_type, 1)
        var need: int = GachaData.get_star_feed_cost(stars)
        pass # print("Ферма: копия %s (%d★) -> простой корм для %s (%d/%d)" % [fodder_type, fodder_stars, target_type, progress, need])
        save_to_active_slot()
        if progress >= need:
                return "Простых кормов достаточно (%d/%d)" % [progress, need]
        return "Простой корм принят: %d/%d" % [progress, need]


func buy_shop_mutant(mutant_type: String, price: float) -> bool:
        """Магазин: купить мутанта за биомассу лаборатории (придёт на забег)"""
        if not current_save_data or not current_save_data.lab_data:
                return false
        var lab = current_save_data.lab_data
        if not is_mutant_unlocked(mutant_type):
                pass # print("Магазин: мутант не разблокирован (кампания): " + mutant_type)
                return false
        if lab.biomass < price:
                pass # print("Магазин: недостаточно биомассы (нужно ", price, ")")
                return false
        lab.biomass -= price
        lab.pending_mutants.append(mutant_type)
        save_game(0)
        return true


func buy_shop_artifact(artifact_type: String, price: float) -> bool:
        if not current_save_data or not current_save_data.lab_data:
                return false
        var lab = current_save_data.lab_data
        if not is_artifact_unlocked(artifact_type):
                pass # print("Магазин: артефакт не разблокирован (кампания): " + artifact_type)
                return false
        if lab.biomass < price:
                pass # print("Магазин: недостаточно биомассы (нужно ", price, ")")
                return false
        lab.biomass -= price
        lab.pending_artifacts.append(artifact_type)
        # Купленный арт получен - соответствующая аномалия открывается
        if not lab.won_artifacts.has(artifact_type):
                lab.won_artifacts.append(artifact_type)
                pass # print("КОЛЛЕКЦИЯ: открыт артефакт из магазина - аномалия доступна: " + artifact_type)
        save_game(0)
        return true


func consume_shop_purchases() -> Dictionary:
        """Забег начинается: забираем купленное из лаборатории"""
        var result := {"mutants": [], "artifacts": []}
        if current_save_data and current_save_data.lab_data:
                var lab = current_save_data.lab_data
                result["mutants"] = lab.pending_mutants.duplicate()
                result["artifacts"] = lab.pending_artifacts.duplicate()
                lab.pending_mutants.clear()
                lab.pending_artifacts.clear()
                save_game(0)
        return result


func has_chimera_unlocked() -> bool:
        if current_save_data and current_save_data.lab_data:
                return current_save_data.lab_data.unlocked_mutants.has("chimera")
        return false


# ==================== ГЕЙТИНГ КОЛЛЕКЦИИ ====================

func is_mutant_unlocked(mutant_type: String) -> bool:
        return get_lab_data().unlocked_mutants.has(mutant_type)


func is_artifact_unlocked(artifact_type: String) -> bool:
        return get_lab_data().won_artifacts.has(artifact_type)


## Коллекция = слабейшие с самого начала + всё, что открыл уровень кампании.
## Вызывается при загрузке сейва, новой игре и после победы на уровне:
## старые сейвы и пропущенные награды подтягиваются автоматически.
func sync_collection_unlocks():
        if not current_save_data or not current_save_data.lab_data:
                return
        var lab = current_save_data.lab_data
        var changed := false
        for type in GachaData.get_default_unlocked_mutants():
                if not lab.unlocked_mutants.has(type):
                        lab.unlocked_mutants.append(type)
                        changed = true
        for type in GachaData.get_default_unlocked_artifacts():
                if not lab.won_artifacts.has(type):
                        lab.won_artifacts.append(type)
                        changed = true
        var level := get_campaign_level()
        for l in range(1, level + 1):
                if _grant_campaign_unlocks(lab, l):
                        changed = true
        if changed:
                pass # print("Коллекция синхронизирована с кампанией (уровень ", level, ")")


## Открыть всё, что положено на уровне кампании. True - если что-то открылось
func _grant_campaign_unlocks(lab, level: int) -> bool:
        var entry: Dictionary = GachaData.get_unlocks_at(level)
        var changed := false
        for type in entry.get("mutants", []):
                if not lab.unlocked_mutants.has(type):
                        lab.unlocked_mutants.append(type)
                        pass # print("КОЛЛЕКЦИЯ: открыт мутант ", type, " (уровень кампании ", level, ")")
                        changed = true
        for type in entry.get("artifacts", []):
                if not lab.won_artifacts.has(type):
                        lab.won_artifacts.append(type)
                        pass # print("КОЛЛЕКЦИЯ: открыт артефакт ", type, " (уровень кампании ", level, ")")
                        changed = true
        return changed


func _create_save_directory():
        var dir = DirAccess.open("user://")
        if not dir.dir_exists("saves"):
                dir.make_dir("saves")
        pass # print("Директория сохранений создана")


# ==================== НАСТРОЙКИ КЛИЕНТА ====================

func _load_settings():
        var cfg = ConfigFile.new()
        if cfg.load(SETTINGS_PATH) == OK:
                active_save_slot = clampi(int(cfg.get_value("game", "active_save_slot", AUTOSAVE_SLOT)), AUTOSAVE_SLOT, MANUAL_SLOTS)
                selected_run_mode = str(cfg.get_value("game", "run_mode", "campaign"))
        pass # print("Активный слот сохранения: " + ("автосейв" if active_save_slot == AUTOSAVE_SLOT else str(active_save_slot)))


func _save_settings():
        var cfg = ConfigFile.new()
        cfg.set_value("game", "active_save_slot", active_save_slot)
        cfg.set_value("game", "run_mode", selected_run_mode)
        var error = cfg.save(SETTINGS_PATH)
        if error != OK:
                pass # print("Не удалось сохранить настройки: код " + str(error))


## Режим забега: кампания, Башня Монолита или выживание
func get_selected_run_mode() -> String:
        if selected_run_mode == "survival" or selected_run_mode == "tower":
                return selected_run_mode
        return "campaign"


func set_selected_run_mode(mode: String) -> bool:
        if mode != "campaign" and mode != "survival" and mode != "tower":
                return false
        selected_run_mode = mode
        _save_settings()
        return true


## Рубеж Башни: самый высокий открытый этаж (из сейва)
func get_tower_frontier() -> int:
        if current_save_data:
                return clampi(int(current_save_data.tower_floor), 1, TowerData.TOTAL_FLOORS)
        return 1


## Выбранный этаж Башни (клампится к открытому рубежу)
func get_selected_tower_floor() -> int:
        return clampi(selected_tower_floor, 1, get_tower_frontier())


func set_selected_tower_floor(floor_num: int) -> bool:
        if floor_num < 1 or floor_num > get_tower_frontier():
                return false
        selected_tower_floor = floor_num
        return true


func get_active_save_slot() -> int:
        return active_save_slot


func set_active_save_slot(slot: int) -> bool:
        if slot < AUTOSAVE_SLOT or slot > MANUAL_SLOTS:
                return false
        active_save_slot = slot
        _save_settings()
        return true


## Сохранить прогресс в активный слот (автосейвы и UI-кнопки)
func save_to_active_slot() -> bool:
        return save_game(active_save_slot)


func _load_boot_save():
        # При старте подхватываем сохранение активного слота: автосейв или ручной
        var path = SAVE_DIR + SAVE_FILE_PREFIX + str(active_save_slot) + SAVE_FILE_EXT
        if FileAccess.file_exists(path):
                var save = load(path)
                if save and save is SaveData:
                        current_save_data = save
                        _migrate_campaign_progress(save)
                        sync_collection_unlocks()
                        pass # print("Сохранение активного слота загружено: " + str(active_save_slot))
                else:
                        pass # print("Файл сохранения активного слота поврежден: " + path)
        else:
                pass # print("Сохранение активного слота не найдено: " + path)


func change_scene(scene_name: String, params: Dictionary = {}):
        pass # print("Смена сцены на: " + scene_name)
        current_scene_name = scene_name
        scene_changed.emit(scene_name)
        
        match scene_name:
                "main_menu":
                        is_in_lab = true
                        _transition_to_scene("res://scenes/ui/main_menu.tscn")
                "lab":
                        is_in_lab = true
                        _transition_to_scene("res://scenes/lab/lab.tscn")
                "gacha":
                        # Гача Зоны - отдельный полноэкранный узел комплекса
                        is_in_lab = true
                        _transition_to_scene("res://scenes/ui/gacha.tscn")
                "profile":
                        # Профиль «Сканер личности» - отдельный полноэкранный терминал
                        is_in_lab = true
                        _transition_to_scene("res://scenes/ui/profile.tscn")
                "run":
                        is_in_lab = false
                        _setup_run_params(params)
                        _transition_to_scene("res://scenes/main/main.tscn")
                _:
                        pass # print("Неизвестная сцена: " + scene_name)


func _transition_to_scene(scene_path: String):
        is_loading = true
        var error = get_tree().change_scene_to_file(scene_path)
        if error != OK:
                pass # print("Ошибка загрузки сцены: " + scene_path + " код: " + str(error))
                Signals.error_occurred.emit(error, "Ошибка загрузки сцены", "GameManager")
        is_loading = false


func _setup_run_params(params: Dictionary):
        var bonuses = {}
        if current_save_data and current_save_data.lab_data:
                bonuses = current_save_data.lab_data.get_bonuses()

        # Режим забега: кампания (уровень из лаборатории) или выживание
        var run_mode := get_selected_run_mode()
        params["run_mode"] = run_mode
        params["campaign_mode"] = get_campaign_mode()

        if run_mode == "tower":
                # Башня Монолита: параметры этажа совместимы с campaign_params
                # (ZoneController применяет их в кампанной ветке), при этом рубеж
                # кампании не двигается - гвард в _apply_campaign_result
                var tower_floor := get_selected_tower_floor()
                params["tower_floor"] = tower_floor
                params["campaign_level"] = tower_floor
                params["campaign_params"] = TowerData.get_floor_params(tower_floor)
        elif run_mode == "survival":
                # Выживание: параметры первой волны; следующие считает ZoneController
                # после каждой волны (эскалация - в SurvivalData)
                params["survival_params"] = SurvivalData.get_wave_params(1, get_campaign_mode())
        else:
                # Кампания: уровень выбран в лаборатории (или текущий рубеж)
                var campaign_level := get_selected_or_frontier_level()
                params["campaign_level"] = campaign_level
                params["campaign_params"] = CampaignData.get_level_params(campaign_level, get_campaign_mode())
                # Переигрывание пройденного уровня: награда урезана, рубеж не двигается
                params["campaign_replay"] = campaign_level < get_campaign_level()

        # Стартовая биомасса в бою: остаток лаборатории + 300 базы.
        # Остаток СПИСЫВАЕТСЯ из лаборатории (перенос припасов на фронт)
        params["start_biomass"] = 300.0
        if current_save_data and current_save_data.lab_data:
                params["start_biomass"] += current_save_data.lab_data.biomass
                current_save_data.lab_data.biomass = 0.0
                
                if params.has("bonuses"):
                        for key in bonuses:
                                if params["bonuses"].has(key):
                                        params["bonuses"][key] *= bonuses[key]
                                else:
                                        params["bonuses"][key] = bonuses[key]
                else:
                        params["bonuses"] = bonuses
                
                params["bonuses"]["monolith_energy_bonus"] = current_save_data.lab_data.get_monolith_energy_bonus()
                params["bonuses"]["monolith_regen_mult"] = current_save_data.lab_data.get_monolith_regen_mult()
                params["bonuses"]["rare_chance_bonus"] = current_save_data.lab_data.get_rare_chance_bonus()
                # Звёздность коллекции: спавнящиеся мутанты получают свои звёзды
                params["mutant_stars"] = current_save_data.lab_data.mutant_stars.duplicate()
                params["artifact_stars"] = current_save_data.lab_data.artifact_stars.duplicate()
        
        get_tree().root.set_meta("run_params", params)
        pass # print("Параметры забега установлены: " + str(params))


func save_game(slot: int) -> bool:
        if not current_save_data:
                current_save_data = SaveData.new()
                pass # print("Создан новый SaveData")
        
        current_save_data.save_time = Time.get_datetime_string_from_system()
        
        var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
        var error = ResourceSaver.save(current_save_data, path)
        
        if error == OK:
                game_saved.emit(slot)
                Signals.game_saved.emit(slot, current_save_data.save_time)
                pass # print("Игра сохранена в слот " + str(slot))
                
                if slot != 0:
                        var autopath = SAVE_DIR + SAVE_FILE_PREFIX + "0" + SAVE_FILE_EXT
                        ResourceSaver.save(current_save_data, autopath)
                        pass # print("Автосохранение обновлено")
                
                return true
        else:
                pass # print("Ошибка сохранения в слот " + str(slot) + " код: " + str(error))
                Signals.error_occurred.emit(error, "Ошибка сохранения", "GameManager")
                return false


func load_game(slot: int) -> bool:
        var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
        
        if not FileAccess.file_exists(path):
                pass # print("Сохранение не найдено: " + path)
                return false
        
        var save = load(path)
        if save and save is SaveData:
                current_save_data = save
                _migrate_campaign_progress(save)
                sync_collection_unlocks()
                # Загруженный слот становится активным: весь дальнейший прогресс пишется сюда
                active_save_slot = clampi(slot, AUTOSAVE_SLOT, MANUAL_SLOTS)
                _save_settings()
                game_loaded.emit(save)
                Signals.game_loaded.emit(slot, save)
                pass # print("Игра загружена из слота " + str(slot) + ", слот активирован")
                return true
        
        pass # print("Файл сохранения поврежден: " + path)
        return false


func delete_save(slot: int) -> bool:
        var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
        
        if FileAccess.file_exists(path):
                var error = DirAccess.remove_absolute(path)
                if error == OK:
                        Signals.save_deleted.emit(slot)
                        pass # print("Сохранение удалено из слота " + str(slot))
                        return true
                else:
                        pass # print("Ошибка удаления сохранения: " + str(error))
                        return false
        
        return false


func get_save_info(slot: int) -> Dictionary:
        var path = SAVE_DIR + SAVE_FILE_PREFIX + str(slot) + SAVE_FILE_EXT
        
        if not FileAccess.file_exists(path):
                return {
                        "exists": false,
                        "slot": slot
                }
        
        var save = load(path)
        if save and save is SaveData:
                return {
                        "exists": true,
                        "slot": slot,
                        "save_time": save.save_time,
                        "run_number": save.lab_data.run_number if save.lab_data else 1,
                        "biomass": save.lab_data.biomass if save.lab_data else 0.0,
                        "wins": save.statistics.wins if save.statistics else 0,
                        "losses": save.statistics.losses if save.statistics else 0,
                        "total_runs": save.statistics.total_runs if save.statistics else 0,
                        "anomaly_upgrades": save.lab_data.get_total_anomaly_levels() if save.lab_data else 0,
                        "mutant_upgrades": save.lab_data.get_total_mutant_levels() if save.lab_data else 0,
                        "monolith_upgrades": save.lab_data.get_total_monolith_levels() if save.lab_data else 0
                }
        
        return {"exists": false, "slot": slot}


func get_all_saves_info() -> Array[Dictionary]:
        # Ручные слоты 1..3; автосейв (0) в список загрузки не входит -
        # он подхватывается сам при старте, если активен
        var info: Array[Dictionary] = []
        for i in range(1, MANUAL_SLOTS + 1):
                info.append(get_save_info(i))
        return info


func start_new_game():
        pass # print("Начало новой игры")
        current_save_data = SaveData.new()
        current_save_data.lab_data = LabData.new()
        current_save_data.statistics = GameStatistics.new()
        selected_campaign_level = 0
        sync_collection_unlocks()

        if save_to_active_slot():
                change_scene("lab")
        else:
                pass # print("Не удалось создать новую игру")


func get_lab_data():
        if not current_save_data:
                current_save_data = SaveData.new()
                current_save_data.lab_data = LabData.new()
                pass # print("Создан новый LabData")
        
        if not current_save_data.lab_data:
                current_save_data.lab_data = LabData.new()
                pass # print("LabData создан в существующем SaveData")
        
        return current_save_data.lab_data


func get_statistics():
        if not current_save_data:
                current_save_data = SaveData.new()
                current_save_data.statistics = GameStatistics.new()
                pass # print("Создан новый GameStatistics")
        
        if not current_save_data.statistics:
                current_save_data.statistics = GameStatistics.new()
                pass # print("GameStatistics создан в существующем SaveData")
        
        return current_save_data.statistics


# ==================== КАМПАНИЯ ====================

## Сейвы до введения кампании: рубеж восстановления - от числа забегов
func _migrate_campaign_progress(save: SaveData):
        if save.campaign_level <= 1 and save.lab_data and save.lab_data.run_number > 1:
                save.campaign_level = clampi(save.lab_data.run_number, 1, CampaignData.TOTAL_LEVELS)
                pass # print("Кампания восстановлена по числу забегов: уровень " + str(save.campaign_level))


func get_campaign_level() -> int:
        if current_save_data:
                return clampi(current_save_data.campaign_level, 1, CampaignData.TOTAL_LEVELS)
        return 1


func get_campaign_mode() -> String:
        if current_save_data and CampaignData.MODE_MULTIPLIERS.has(current_save_data.campaign_mode):
                return current_save_data.campaign_mode
        return CampaignData.MODE_NORMAL


func set_campaign_mode(mode: String):
        if current_save_data and CampaignData.MODE_MULTIPLIERS.has(mode):
                current_save_data.campaign_mode = mode
                save_to_active_slot()


## Уровень для следующего забега: выбранный в лаборатории или текущий рубеж
func get_selected_or_frontier_level() -> int:
        var frontier := get_campaign_level()
        if selected_campaign_level >= 1 and selected_campaign_level <= frontier:
                return selected_campaign_level
        return frontier


func is_campaign_completed() -> bool:
        return current_save_data != null and current_save_data.campaign_completed


## Победа в забеге: сдвигаем рубеж кампании, если пройден frontier-уровень
func _apply_campaign_result(result: Dictionary):
        # Башня: этажи Башни Монолита не двигают рубеж кампании
        if str(result.get("mode", "")) == "tower":
                return
        var success: bool = result.get("success", false)
        var level: int = result.get("campaign_level", 0)
        if not success or level <= 0:
                return

        if current_save_data.campaign_completed:
                return

        if level >= CampaignData.TOTAL_LEVELS:
                current_save_data.campaign_completed = true
                pass # print("КАМПАНИЯ ПРОЙДЕНА! Все 100 колец Зоны за спиной.")
                return

        if level >= current_save_data.campaign_level:
                current_save_data.campaign_level = mini(level + 1, CampaignData.TOTAL_LEVELS)
                pass # print("Кампания: открыт уровень " + str(current_save_data.campaign_level))
                _grant_campaign_unlocks(current_save_data.lab_data, current_save_data.campaign_level)


## Арена: какой тип забега стартован из арены ("challenge"/"defense"/"")
## Ставится lab_controller перед стартом выживания, гасится в process_run_result
var arena_run_kind: String = ""


func process_run_result(result: Dictionary):
        pass # print("Обработка результатов забега: " + str(result))

        var lab = get_lab_data()
        var stats = get_statistics()

        var reward = result.get("reward", 0.0)
        lab.biomass += reward
        pass # print("Добавлено биомассы: " + str(reward))

        _apply_campaign_result(result)

        # Выживание: рекорд пройденных волн
        if result.get("mode", "") == "survival":
                var waves_survived := int(result.get("waves_survived", 0))
                if waves_survived > stats.best_survival_wave:
                        stats.best_survival_wave = waves_survived
                        pass # print("Новый рекорд выживания: %d волн" % waves_survived)

                # Благословение сезона (арена): +10% биомассы с волн выживания
                if reward > 0.0:
                        var bless_bonus: float = reward * 0.10
                        lab.biomass += bless_bonus

                # Победы арены: вызовы/оборона; каждая 5-я победа = +1 крутка мутантов
                if not arena_run_kind.is_empty():
                        if bool(result.get("success", false)):
                                if arena_run_kind == "defense":
                                        lab.arena_wins_defense += 1
                                else:
                                        lab.arena_wins_challenge += 1
                                var total_wins: int = lab.arena_wins_challenge + lab.arena_wins_defense
                                if total_wins % 5 == 0:
                                        lab.gacha_rolls_mutants += 1
                        arena_run_kind = ""

        # Башня Монолита: звёзды этажа, награда этажа и открытие следующего
        if result.get("mode", "") == "tower" and current_save_data:
                var tower_floor := int(result.get("tower_floor", 0))
                if tower_floor >= 1:
                        var tower_stars: int = TowerData.evaluate_stars(tower_floor, result)
                        var star_key := str(tower_floor)
                        var old_stars: int = int(current_save_data.tower_stars.get(star_key, 0))
                        # Сводка для церемонии: звёзды считаются ДО обновления рекорда,
                        # иначе CeremonyOverlay показывает дефолтную 1 звезду
                        var tower_summary: Dictionary = {
                                "floor": tower_floor,
                                "stars": tower_stars,
                                "stars_before": old_stars,
                                "biomass": 0.0,
                                "mutant_rolls": 0,
                                "anomaly_rolls": 0,
                        }
                        if bool(result.get("success", false)):
                                # Награда этажа: биомасса + крутки обеих гач (+1 крутка
                                # за каждую звезду сверх первой)
                                var floor_rewards: Dictionary = TowerData.get_floor_rewards(tower_floor)
                                var star_rolls: int = maxi(0, tower_stars - 1) * TowerData.STAR_ROLL_BONUS
                                var mutant_rolls: int = int(floor_rewards.get("mutant_rolls", 0)) + star_rolls
                                var anomaly_rolls: int = int(floor_rewards.get("anomaly_rolls", 0))
                                var summary_biomass: float = float(floor_rewards.get("biomass", 0.0))
                                tower_summary["biomass"] = summary_biomass
                                tower_summary["mutant_rolls"] = mutant_rolls
                                tower_summary["anomaly_rolls"] = anomaly_rolls
                                lab.biomass += summary_biomass
                                if mutant_rolls > 0:
                                        grant_mutant_rolls(mutant_rolls, "этаж %d Башни" % tower_floor)
                                if anomaly_rolls > 0:
                                        grant_anomaly_rolls(anomaly_rolls, "этаж %d Башни" % tower_floor)
                                # Победа на открытом рубеже двигает рубеж Башни вперёд
                                if tower_floor >= current_save_data.tower_floor:
                                        current_save_data.tower_floor = mini(tower_floor + 1, TowerData.TOTAL_FLOORS)
                        else:
                                # Утешение при поражении: боевой доход забега (платится всегда)
                                tower_summary["biomass"] = float(result.get("reward", 0.0))
                        # Рекорд звёзд этажа обновляем ПОСЛЕ захвата stars_before
                        if tower_stars > old_stars:
                                current_save_data.tower_stars[star_key] = tower_stars
                        result["tower_summary"] = tower_summary

        stats.total_runs += 1
        var success = result.get("success", false)
        if success:
                stats.wins += 1
                pass # print("Победа")
        else:
                stats.losses += 1
                pass # print("Поражение")
        
        if result.has("artifacts_collected"):
                var artifacts = result["artifacts_collected"]
                for artifact in artifacts:
                        lab.add_artifact(str(artifact.get("type", "common")), int(artifact.get("value", 10)))
                pass # print("Добавлено артефактов: " + str(artifacts.size()))
        
        if result.has("statistics"):
                var run_stats = result["statistics"]
                stats.stalkers_killed += run_stats.get("stalkers_killed", 0)
                stats.anomalies_created += run_stats.get("anomalies_created", 0)
                stats.mutants_created += run_stats.get("mutants_created", 0)
                stats.artifacts_stolen += run_stats.get("artifacts_stolen", 0)
                stats.biomass_earned += run_stats.get("biomass_earned", 0)
                stats.biomass_spent += run_stats.get("biomass_spent", 0)
        
        lab.run_number += 1
        pass # print("Номер забега: " + str(lab.run_number))

        save_to_active_slot()

        # Результат для панели итогов в лаборатории (забирается и снимается там)
        get_tree().root.set_meta("last_run_result", result)

        Signals.run_ended.emit(lab.run_number - 1, success, reward)


func purchase_upgrade(upgrade_type: String, cost: float) -> bool:
        var lab = get_lab_data()

        # Расширенные тиры открываются прогрессом кампании
        if not lab.is_next_level_unlocked(upgrade_type, get_campaign_level()):
                pass # print("Улучшение %s откроется на уровне кампании %d" % [
                        # upgrade_type, lab.get_next_unlock_campaign_level(upgrade_type)])
                return false

        if lab.biomass < cost:
                pass # print("Недостаточно биомассы для " + upgrade_type + " (нужно: " + str(cost) + ", есть: " + str(lab.biomass) + ")")
                return false
        
        lab.biomass -= cost
        lab.purchase_upgrade(upgrade_type)
        
        pass # print("Куплено улучшение: " + upgrade_type + " за " + str(cost))
        
        save_to_active_slot()
        
        return true


func exchange_artifact(artifact_type: String, value: int) -> bool:
        var lab = get_lab_data()
        
        if lab.remove_artifact(artifact_type):
                lab.biomass += value
                pass # print("Обменян артефакт " + artifact_type + " на " + str(value) + " биомассы")
                save_to_active_slot()
                return true
        
        pass # print("Не удалось обменять артефакт " + artifact_type)
        return false


func exchange_all_artifacts(rarity: String) -> int:
        var lab = get_lab_data()
        var total = lab.exchange_all_of_rarity(rarity)
        
        if total > 0:
                lab.biomass += total
                pass # print("Обменяны все артефакты редкости " + rarity + " на " + str(total) + " биомассы")
                save_to_active_slot()
        else:
                pass # print("Нет артефактов редкости " + rarity + " для обмена")
        
        return total


func get_current_save_data():
        return current_save_data


func is_game_running() -> bool:
        return not is_in_lab and not is_loading


func get_current_scene() -> String:
        return current_scene_name


func reset_game():
        pass # print("Сброс игры")
        current_save_data = null
        is_in_lab = true
        is_loading = false
        current_scene_name = ""
