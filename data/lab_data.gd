# data/lab_data.gd
extends Resource
class_name LabData

## Данные лабораторного комплекса

# Основные данные
@export var run_number: int = 1
@export var biomass: float = 0.0

# Рубеж кампании на момент загрузки (runtime-кэш из SaveData.campaign_level,
# не сохраняется - источник истины кампании в GameManager)
var campaign_level_reached: int = 1

# Улучшения аномалий
@export var anomaly_damage_level: int = 0
@export var anomaly_radius_level: int = 0
@export var anomaly_duration_level: int = 0

# Улучшения мутантов
@export var mutant_health_level: int = 0
@export var mutant_damage_level: int = 0
@export var mutant_speed_level: int = 0
@export var mutant_cost_level: int = 0

# Улучшения монолита
@export var monolith_energy_level: int = 0

# Награды гачи: выигранные мутанты и артефакты
@export var unlocked_mutants: Array[String] = []
@export var won_artifacts: Array[String] = []

# Покупки магазина: придут в бой / заспавнятся у монолита в начале забега
@export var pending_mutants: Array[String] = []
@export var pending_artifacts: Array[String] = []
@export var monolith_regen_level: int = 0
@export var rare_chance_level: int = 0

# Звёздность: прокачка отдельных мутантов/артефактов (1-5 звёзд, поверх редкости).
# Ключ - тип (как в GachaData), значение - число звёзд; отсутствует = 1 звезда.
# Старые сейвы без этих полей совместимы (по умолчанию пусто).
@export var mutant_stars: Dictionary = {}
@export var artifact_stars: Dictionary = {}

# ФЕРМА МУТАНТОВ: копии, выпавшие дублями из гачи/вех. Копия того же типа
# повышает звезду, копии других типов - корм (очки звезды).
@export var farm_copies: Dictionary = {}

# Простой корм (копии 1★ и прочих типов) к следующей звезде (тип -> счёт)
@export var mutant_star_progress: Dictionary = {}

# Звёздный корм: копия мутанта ТОЙ ЖЕ звёздности, что и цель (тип -> 0/1)
@export var star_feed_progress: Dictionary = {}

# Очки утилизации копий (10 очков = 1 крутка артефактов)
@export var recycle_points: int = 0

# АРЕНА ВЫЖИВАНИЯ: победы в вызовах / удержанные обороны + защитный отряд
# (мутанты, которые держат арену, пока игрок в вылазке)
@export var arena_wins_challenge: int = 0
@export var arena_wins_defense: int = 0
@export var arena_defense_squad: Array[String] = []

# СЕЗОННЫЕ НАГРАДЫ: забранные медали и сезонные задачи (индекс -> true)
@export var arena_medals_claimed: Dictionary = {}
@export var arena_season_tasks_claimed: Dictionary = {}

# Эксклюзивные аномалии Чёрных ящиков (типы из GachaData.EXCLUSIVE_ANOMALIES)
@export var exclusive_anomalies: Array[String] = []

# ПОЛЕВОЙ НАБОР: какие виды берём в бой (макс 9 видов на каждый список).
# Пусто = автосбор из открытых при входе в бой (старые сейвы совместимы).
# Выбор - на кнопках HUD до старта забега; после старта доступны только взятые.
@export var loadout_anomalies: Array[String] = []
@export var loadout_mutants: Array[String] = []

# КРУТКИ ГАЧИ. DEV: мутантные - миллион по запросу игрока (смотреть шансы),
# аномалийные крутки - серьёзная валюта (30-й уровень/30 волн = +10), дефолт 0.
@export var gacha_rolls_mutants: int = 1000000
@export var gacha_rolls_artifacts: int = 0
# Супер-гача: прогресс бонуса обычных круток и доступные супер-крутки
# (каждые GachaData.SUPER_PITY обычных призывов = +1 супер-крутка).
@export var super_pull_progress: int = 0
@export var super_pulls: int = 0

# Хранилище артефактов
@export var artifacts_common: Array[Dictionary] = []
@export var artifacts_rare: Array[Dictionary] = []
@export var artifacts_legendary: Array[Dictionary] = []

# Максимальные уровни (базовые тиры + расширенные, открываются кампанией)
const MAX_LEVELS = {
    "anomaly_damage": 8,
    "anomaly_radius": 8,
    "anomaly_duration": 5,
    "mutant_health": 8,
    "mutant_damage": 8,
    "mutant_speed": 5,
    "mutant_cost": 5,
    "monolith_energy": 8,
    "monolith_regen": 5,
    "rare_chance": 5
}

# Базовые тиры: доступны с самого начала, дают полный бонус
const BASE_MAX_LEVELS = {
    "anomaly_damage": 5,
    "anomaly_radius": 5,
    "anomaly_duration": 3,
    "mutant_health": 5,
    "mutant_damage": 5,
    "mutant_speed": 3,
    "mutant_cost": 3,
    "monolith_energy": 5,
    "monolith_regen": 3,
    "rare_chance": 3
}

# Уровень кампании, на котором открывается следующий тир улучшения.
# Для 5-уровневых треков это тиры 6/7/8, для 3-уровневых - тиры 4/5
const EXTENDED_UNLOCK_CAMPAIGN_LEVELS = {
    4: 40,
    5: 70,
    6: 45,
    7: 65,
    8: 85
}

# Доля полного бонуса за уровни сверх базового тира
const EXTENDED_BONUS_FACTOR = 0.5

# Стоимости улучшений (последние значения - расширенные тиры из кампании)
const COSTS = {
    "anomaly_damage": [100, 200, 400, 800, 1600, 3200, 5600, 8400],
    "anomaly_radius": [150, 300, 600, 1200, 2400, 3200, 5600, 8400],
    "anomaly_duration": [200, 400, 800, 1600, 4200],
    "mutant_health": [100, 200, 400, 800, 1600, 3200, 5600, 8400],
    "mutant_damage": [120, 240, 480, 960, 1920, 3200, 5600, 8400],
    "mutant_speed": [150, 300, 600, 1600, 4200],
    "mutant_cost": [200, 400, 800, 1600, 4200],
    "monolith_energy": [150, 300, 600, 1200, 2400, 3200, 5600, 8400],
    "monolith_regen": [200, 400, 800, 1600, 4200],
    "rare_chance": [300, 600, 1200, 1600, 4200]
}

# Бонусы за уровень
const BONUS_PER_LEVEL = {
    "anomaly_damage": 0.10,
    "anomaly_radius": 0.10,
    "anomaly_duration": 0.20,
    "mutant_health": 0.10,
    "mutant_damage": 0.10,
    "mutant_speed": 0.10,
    "mutant_cost": -0.10,
    "monolith_energy": 100.0,
    "monolith_regen": 0.20,
    "rare_chance": 0.10
}


# ==================== УЛУЧШЕНИЯ ====================

func get_upgrade_level(upgrade_type: String) -> int:
    match upgrade_type:
        "anomaly_damage": return anomaly_damage_level
        "anomaly_radius": return anomaly_radius_level
        "anomaly_duration": return anomaly_duration_level
        "mutant_health": return mutant_health_level
        "mutant_damage": return mutant_damage_level
        "mutant_speed": return mutant_speed_level
        "mutant_cost": return mutant_cost_level
        "monolith_energy": return monolith_energy_level
        "monolith_regen": return monolith_regen_level
        "rare_chance": return rare_chance_level
        _: return 0


func get_max_level(upgrade_type: String) -> int:
    return MAX_LEVELS.get(upgrade_type, 5)


func can_upgrade(upgrade_type: String) -> bool:
    var current = get_upgrade_level(upgrade_type)
    var max_lvl = get_max_level(upgrade_type)
    return current < max_lvl


func get_upgrade_cost(upgrade_type: String) -> float:
    var current = get_upgrade_level(upgrade_type)
    if not COSTS.has(upgrade_type):
        return 100.0
    
    var costs = COSTS[upgrade_type]
    if current >= costs.size():
        return 99999.0
    
    return costs[current]


func purchase_upgrade(upgrade_type: String) -> bool:
    if not can_upgrade(upgrade_type):
        return false

    # Расширенные тиры открываются прогрессом кампании
    if not is_next_level_unlocked(upgrade_type, campaign_level_reached):
        return false

    match upgrade_type:
        "anomaly_damage": anomaly_damage_level += 1
        "anomaly_radius": anomaly_radius_level += 1
        "anomaly_duration": anomaly_duration_level += 1
        "mutant_health": mutant_health_level += 1
        "mutant_damage": mutant_damage_level += 1
        "mutant_speed": mutant_speed_level += 1
        "mutant_cost": mutant_cost_level += 1
        "monolith_energy": monolith_energy_level += 1
        "monolith_regen": monolith_regen_level += 1
        "rare_chance": rare_chance_level += 1
    
    return true


func get_bonus(upgrade_type: String) -> float:
    var level = get_upgrade_level(upgrade_type)
    var bonus = BONUS_PER_LEVEL.get(upgrade_type, 0.0)

    # Базовые тиры дают полный бонус, расширенные (открываются кампанией) - половинный
    var base_max = int(BASE_MAX_LEVELS.get(upgrade_type, 5))
    var base_levels = mini(level, base_max)
    var extended_levels = maxi(0, level - base_max)

    if upgrade_type == "monolith_energy":
        return base_levels * bonus + extended_levels * bonus * EXTENDED_BONUS_FACTOR

    return 1.0 + base_levels * bonus + extended_levels * bonus * EXTENDED_BONUS_FACTOR


# ==================== РАЗБЛОЧКА КАМПАНИЕЙ ====================

## Уровень кампании, требуемый для покупки СЛЕДУЮЩЕГО тира улучшения
func get_next_unlock_campaign_level(upgrade_type: String) -> int:
    var next_level = get_upgrade_level(upgrade_type) + 1
    return int(EXTENDED_UNLOCK_CAMPAIGN_LEVELS.get(next_level, 1))


func is_next_level_unlocked(upgrade_type: String, campaign_level: int) -> bool:
    return campaign_level >= get_next_unlock_campaign_level(upgrade_type)


# ==================== БОНУСЫ ====================

func get_bonuses() -> Dictionary:
    return {
        "anomaly_damage_mult": get_bonus("anomaly_damage"),
        "anomaly_radius_mult": get_bonus("anomaly_radius"),
        "anomaly_duration_mult": get_bonus("anomaly_duration"),
        "mutant_health_mult": get_bonus("mutant_health"),
        "mutant_damage_mult": get_bonus("mutant_damage"),
        "mutant_speed_mult": get_bonus("mutant_speed"),
        "mutant_cost_mult": get_bonus("mutant_cost")
    }


func get_monolith_energy_bonus() -> float:
    return get_bonus("monolith_energy")


func get_monolith_regen_mult() -> float:
    return get_bonus("monolith_regen")


func get_rare_chance_bonus() -> float:
    return get_bonus("rare_chance")


func get_total_anomaly_levels() -> int:
    return anomaly_damage_level + anomaly_radius_level + anomaly_duration_level


func get_total_mutant_levels() -> int:
    return mutant_health_level + mutant_damage_level + mutant_speed_level + mutant_cost_level


func get_total_monolith_levels() -> int:
    return monolith_energy_level + monolith_regen_level + rare_chance_level


# ==================== АРТЕФАКТЫ ====================

func add_artifact(rarity: String, value: int):
    var artifact = {"value": value}
    
    match rarity:
        "common":
            artifacts_common.append(artifact)
        "rare":
            artifacts_rare.append(artifact)
        "legendary":
            artifacts_legendary.append(artifact)


func remove_artifact(rarity: String) -> bool:
    match rarity:
        "common":
            if artifacts_common.size() > 0:
                artifacts_common.pop_back()
                return true
        "rare":
            if artifacts_rare.size() > 0:
                artifacts_rare.pop_back()
                return true
        "legendary":
            if artifacts_legendary.size() > 0:
                artifacts_legendary.pop_back()
                return true
    return false


func get_artifact_count(rarity: String) -> int:
    match rarity:
        "common": return artifacts_common.size()
        "rare": return artifacts_rare.size()
        "legendary": return artifacts_legendary.size()
    return 0


func get_total_artifact_value(rarity: String) -> int:
    var artifacts: Array
    match rarity:
        "common": artifacts = artifacts_common
        "rare": artifacts = artifacts_rare
        "legendary": artifacts = artifacts_legendary
        _: return 0
    
    var total = 0
    for a in artifacts:
        total += a.get("value", 0)
    return total


func exchange_all_of_rarity(rarity: String) -> int:
    var total = get_total_artifact_value(rarity)
    
    match rarity:
        "common": artifacts_common.clear()
        "rare": artifacts_rare.clear()
        "legendary": artifacts_legendary.clear()
    
    return total


func get_all_artifacts() -> Dictionary:
    return {
        "common": {
            "count": get_artifact_count("common"),
            "value": get_total_artifact_value("common"),
            "items": artifacts_common
        },
        "rare": {
            "count": get_artifact_count("rare"),
            "value": get_total_artifact_value("rare"),
            "items": artifacts_rare
        },
        "legendary": {
            "count": get_artifact_count("legendary"),
            "value": get_total_artifact_value("legendary"),
            "items": artifacts_legendary
        }
    }


# ==================== ЗВЁЗДНОСТЬ ====================

const MAX_STARS: int = 5
const STAR_STAT_BONUS: float = 0.2  # +20% базовых статов за звезду сверх первой
const STAR_UPGRADE_BASE_COST: float = 500.0  # цена 500 * 2^(звёзды-1)


func get_mutant_stars(type: String) -> int:
    return maxi(int(mutant_stars.get(type, 1)), 1)


func get_artifact_stars(type: String) -> int:
    return maxi(int(artifact_stars.get(type, 1)), 1)


func add_mutant_star(type: String) -> bool:
    """+1 звезда мутанту. False - звёзды уже максимальные."""
    var stars := get_mutant_stars(type)
    if stars >= MAX_STARS:
        return false
    mutant_stars[type] = stars + 1
    return true


func add_artifact_star(type: String) -> bool:
    var stars := get_artifact_stars(type)
    if stars >= MAX_STARS:
        return false
    artifact_stars[type] = stars + 1
    return true


func get_star_upgrade_cost(current_stars: int) -> float:
    return STAR_UPGRADE_BASE_COST * pow(2.0, float(maxi(current_stars, 1) - 1))


## Множитель статов для звёзд: 1 звезда = x1.0, 5 звёзд = x2.0
static func get_star_stat_mult(stars: int) -> float:
    return 1.0 + float(maxi(stars, 1) - 1) * STAR_STAT_BONUS


func get_star_progress(type: String) -> int:
    return int(mutant_star_progress.get(type, 0))


func add_star_progress(type: String, points: int) -> int:
    mutant_star_progress[type] = get_star_progress(type) + points
    return int(mutant_star_progress[type])


func clear_star_progress(type: String):
    mutant_star_progress.erase(type)


func get_star_feed(type: String) -> int:
    return int(star_feed_progress.get(type, 0))


func add_star_feed(type: String) -> int:
    star_feed_progress[type] = get_star_feed(type) + 1
    return int(star_feed_progress[type])


func get_farm_copies(type: String) -> int:
    return int(farm_copies.get(type, 0))


func add_farm_copy(type: String) -> int:
    farm_copies[type] = get_farm_copies(type) + 1
    return int(farm_copies[type])


func consume_farm_copy(type: String) -> bool:
    if get_farm_copies(type) <= 0:
        return false
    farm_copies[type] = get_farm_copies(type) - 1
    if int(farm_copies[type]) <= 0:
        farm_copies.erase(type)
    return true


## "★★★☆☆" для UI
static func stars_text(stars: int) -> String:
    var text := ""
    for i in range(MAX_STARS):
        text += "★" if i < stars else "☆"
    return text


# ==================== ПОЛЕВОЙ НАБОР ====================

const MAX_LOADOUT: int = 9


func loadout_list(kind: String) -> Array[String]:
    return loadout_anomalies if kind == "anomaly" else loadout_mutants


func loadout_count(kind: String) -> int:
    return loadout_list(kind).size()


func in_loadout(kind: String, type: String) -> bool:
    return loadout_list(kind).has(type)


## Взять/снять вид из набора. "added" / "removed" / "full" (лимит 9)
func toggle_loadout(kind: String, type: String) -> String:
    var list := loadout_list(kind)
    if list.has(type):
        list.erase(type)
        return "removed"
    if list.size() >= MAX_LOADOUT:
        return "full"
    list.append(type)
    return "added"


# ==================== СБРОС ====================

func reset():
    run_number = 1
    biomass = 0.0
    
    anomaly_damage_level = 0
    anomaly_radius_level = 0
    anomaly_duration_level = 0
    mutant_health_level = 0
    mutant_damage_level = 0
    mutant_speed_level = 0
    mutant_cost_level = 0
    monolith_energy_level = 0
    monolith_regen_level = 0
    rare_chance_level = 0
    
    artifacts_common.clear()
    artifacts_rare.clear()
    artifacts_legendary.clear()
    mutant_stars.clear()
    artifact_stars.clear()
    farm_copies.clear()
    mutant_star_progress.clear()
    star_feed_progress.clear()
    recycle_points = 0
    super_pull_progress = 0
    super_pulls = 0
    exclusive_anomalies.clear()
    loadout_anomalies.clear()
    loadout_mutants.clear()
