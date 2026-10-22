# data/tower_data.gd
extends RefCounted
class_name TowerData

## Башня Монолита - 100 этажей бесконечно растущей сложности.
## Этаж = один забег. За этаж дают звёзды (1-3) по условиям, биомассу и
## КРУТКИ существующей гачи (мутанты/артефакты - см. GachaData).
## Каждый 5-й этаж «Прорыв» (награда x1.5), каждый 10-й «Хранитель»
## (босс, награда x3). Весь дизайн в данных здесь; параметры этажа
## совместимы с campaign_params - ZoneController применяет их тем же кодом.

const TOTAL_FLOORS: int = 100

# ==================== ЯРУСЫ (по 10 этажей) ====================
# waves  - волн на этаже
# count  - сталкеров на волну (в ярусе +1 со второй половины)
# mix    - состав рангов [новички, ветераны, мастера], %
# stat   - множитель HP/урона от stat до stat_end внутри яруса
# pulses - выбросов до победы
# boss   - имя Хранителя (10-й этаж яруса)
const TIERS := [
	{"name": "Корни", "waves": 3, "count": 8, "mix": [90, 10, 0], "stat": 1.00, "stat_end": 1.06, "pulses": 3,
		"boss": "Смотритель корней"},
	{"name": "Трубы", "waves": 3, "count": 9, "mix": [80, 20, 0], "stat": 1.06, "stat_end": 1.12, "pulses": 3,
		"boss": "Хозяин труб"},
	{"name": "Свалка", "waves": 3, "count": 10, "mix": [70, 28, 2], "stat": 1.12, "stat_end": 1.18, "pulses": 3,
		"boss": "Король свалки"},
	{"name": "Тёмная долина", "waves": 4, "count": 11, "mix": [60, 36, 4], "stat": 1.18, "stat_end": 1.24, "pulses": 4,
		"boss": "Тень долины"},
	{"name": "Ржавый лес", "waves": 4, "count": 12, "mix": [52, 42, 6], "stat": 1.24, "stat_end": 1.30, "pulses": 4,
		"boss": "Ржавый великан"},
	{"name": "Буерак", "waves": 5, "count": 13, "mix": [44, 48, 8], "stat": 1.30, "stat_end": 1.36, "pulses": 4,
		"boss": "Буерачница"},
	{"name": "Саркофаг", "waves": 5, "count": 14, "mix": [38, 52, 10], "stat": 1.36, "stat_end": 1.42, "pulses": 4,
		"boss": "Жрец Саркофага"},
	{"name": "Полигон", "waves": 5, "count": 15, "mix": [32, 54, 14], "stat": 1.42, "stat_end": 1.48, "pulses": 5,
		"boss": "Испытательный образец"},
	{"name": "Рубеж", "waves": 6, "count": 16, "mix": [26, 56, 18], "stat": 1.48, "stat_end": 1.54, "pulses": 5,
		"boss": "Комендант рубежа"},
	{"name": "Сердце Зоны", "waves": 6, "count": 17, "mix": [22, 58, 20], "stat": 1.54, "stat_end": 1.62, "pulses": 5,
		"boss": "Антагонист Монолита"}
]

# ==================== УСЛОВИЯ ЗВЁЗД ====================
# id -> {name, desc}. Проверяются по результату забега в evaluate_stars().
const STAR_CONDITIONS := {
	"no_steal": {
		"name": "Ни пятнышка",
		"desc": "Сталкеры не унесли ни одного артефакта"
	},
	"no_pulse": {
		"name": "Своими руками",
		"desc": "Победа без единого выброса"
	},
	"hunter75": {
		"name": "Зачистка",
		"desc": "Перебить 75% всех сталкеров"
	},
	"hunter90": {
		"name": "Никто не уйдёт",
		"desc": "Перебить 90% всех сталкеров"
	},
	"budget4": {
		"name": "Экономия",
		"desc": "Создать не больше 4 мутантов"
	},
	"budget8": {
		"name": "Скупо",
		"desc": "Создать не больше 8 мутантов"
	},
	"rich": {
		"name": "Богатый улов",
		"desc": "Заработать норму биомассы за забег"
	}
}

# Лёгкие условия для 2-й звезды, жёсткие - для 3-й.
# Выбор детерминированный по номеру этажа - условия меняются от этажа к этажу.
const EASY_POOL := ["no_steal", "hunter75", "budget8", "no_steal", "budget4"]
const HARD_POOL := ["no_pulse", "hunter90", "rich", "hunter90", "no_pulse", "rich"]

# «Богатый улов»: порог = доля от ПОТОЛКА дохода этажа (волны x сталкеры x
# средний чек рангового микса). 0.73 - по решению игрока (было предложение 85%).
const RICH_FRACTION: float = 0.73

# ==================== НАГРАДЫ ====================
const REWARD_BASE: float = 120.0          # биомасса: база + за этаж
const REWARD_PER_FLOOR: float = 10.0
const ROLLS_BASE: int = 1                 # крутки мутантов: база + этаж/20
const BREAK_REWARD_MULT: float = 1.5      # Прорыв (каждый 5-й)
const KEEPER_REWARD_MULT: float = 3.0     # Хранитель (каждый 10-й)
const BREAK_STAT_MULT: float = 1.08
const KEEPER_STAT_MULT: float = 1.15
const KEEPER_COUNT_PCT: float = 0.15
const STAR_ROLL_BONUS: int = 1            # +1 крутка за звезду сверх первой


static func get_tier(floor_num: int) -> Dictionary:
	var f: int = clampi(floor_num, 1, TOTAL_FLOORS)
	@warning_ignore("integer_division")
	var idx: int = (f - 1) / 10
	return TIERS[idx]


## Тип этажа: "keeper" (каждый 10-й), "break" (каждый 5-й), "normal"
static func get_floor_type(floor_num: int) -> String:
	var f: int = clampi(floor_num, 1, TOTAL_FLOORS)
	if f % 10 == 0:
		return "keeper"
	if f % 5 == 0:
		return "break"
	return "normal"


## Условия звёзд этажа: [условие 2 звезд, условие 3 звезд]
static func get_star_conditions(floor_num: int) -> Array:
	var f: int = clampi(floor_num, 1, TOTAL_FLOORS)
	var easy: String = EASY_POOL[(f - 1) % EASY_POOL.size()]
	var hard: String = HARD_POOL[(f * 2 + floori(f / 10.0)) % HARD_POOL.size()]
	if hard == easy:
		hard = HARD_POOL[(HARD_POOL.find(hard) + 1) % HARD_POOL.size()]
	return [easy, hard]


## Порог «Богатого улова» для этажа: доля RICH_FRACTION от потолка дохода.
## Потолок = волны x (сталкеров на волну + 2) x средний чек рангов (16/30/60).
## Нижняя граница 150, округление до десятков - для читаемости в HUD.
static func rich_threshold(floor_num: int) -> int:
	var tier := get_tier(floor_num)
	var waves: int = int(tier["waves"])
	var count: int = int(tier["count"]) + (1 if floor_num % 10 >= 5 else 0)
	var mix: Array = tier["mix"]
	var avg: float = (float(mix[0]) * 16.0 + float(mix[1]) * 30.0 + float(mix[2]) * 60.0) / 100.0
	var ceiling: float = float(waves * (count + 2)) * avg
	return maxi(150, roundi(ceiling * RICH_FRACTION / 10.0) * 10)


## Единый текст условия с реальными числами (тултипы лаборатории, HUD).
static func condition_text(cond_id: String, floor_num: int) -> String:
	if cond_id == "rich":
		return "Заработать %d биомассы за забег" % rich_threshold(floor_num)
	var c: Dictionary = STAR_CONDITIONS.get(cond_id, {})
	return str(c.get("desc", ""))


## Награда за этаж: биомасса + крутки обеих гач (без учёта звёзд)
static func get_floor_rewards(floor_num: int) -> Dictionary:
	var f: int = clampi(floor_num, 1, TOTAL_FLOORS)
	var type := get_floor_type(f)
	var mult: float = 1.0
	match type:
		"keeper": mult = KEEPER_REWARD_MULT
		"break": mult = BREAK_REWARD_MULT

	var biomass: float = (REWARD_BASE + REWARD_PER_FLOOR * f) * mult
	var mutant_rolls := roundi((ROLLS_BASE + float(f) / 20.0) * mult)
	# Аномалийные крутки: на Прорывах и Хранителях щедрее
	var anomaly_rolls := 0
	match type:
		"keeper": anomaly_rolls = 3
		"break": anomaly_rolls = 2
		_: anomaly_rolls = 1 if f % 3 == 0 else 0
	return {"biomass": biomass, "mutant_rolls": mutant_rolls, "anomaly_rolls": anomaly_rolls}


## Полный набор параметров этажа - совместим с campaign_params
static func get_floor_params(floor_num: int) -> Dictionary:
	var f: int = clampi(floor_num, 1, TOTAL_FLOORS)
	var tier: Dictionary = get_tier(f)
	var type := get_floor_type(f)
	var t: float = float((f - 1) % 10) / 9.0

	var waves: int = int(tier["waves"])
	var count: int = int(tier["count"]) + (1 if f % 10 >= 5 else 0)
	var mix: Array = (tier["mix"] as Array).duplicate()
	var stat: float = lerpf(float(tier["stat"]), float(tier["stat_end"]), t)

	var title: String = "%d-й этаж: %s" % [f, tier["name"]]
	match type:
		"keeper":
			title = "ХРАНИТЕЛЬ: %s" % tier["boss"]
			stat *= KEEPER_STAT_MULT
			count = roundi(count * (1.0 + KEEPER_COUNT_PCT))
		"break":
			title = "ПРОРЫВ: %d-й этаж" % f
			stat *= BREAK_STAT_MULT

	return {
		"level": f,
		"chapter_title": String(tier["name"]),
		"chapter_desc": "",
		"title": title,
		"desc": "",
		"is_boss": type == "keeper",
		"waves": waves,
		"count_min": count,
		"count_max": count + 2,
		"mix": mix,
		"hp_mult": stat,
		"damage_mult": stat,
		"speed_mult": 1.0,
		"wave_break": 45.0,
		"pulses_to_win": int(tier["pulses"]),
		"reward_bonus": 0.0,
		"mode": "tower",
		"floor_type": type
	}


## Проверка условий звёзд по результату забега. Возвращает 0-3 (0 = поражение).
static func evaluate_stars(floor_num: int, result: Dictionary) -> int:
	if not bool(result.get("success", false)):
		return 0

	var stars := 1
	var conditions := get_star_conditions(floor_num)

	# ГЛАВНЫЙ ФИКС (fix6): вся статистика забега лежит в result["statistics"]
	# (zone_controller._collect_run_result кладёт её туда, а game_manager читает
	# именно оттуда). Раньше поля читали с верхнего уровня - их там НЕТ:
	# rich видел всегда 0.0 (звезда недостижима), no_steal/budget проходили всегда.
	# Фолбэк на верхний уровень оставлен для совместимости со старыми тестами.
	var stats: Dictionary = result.get("statistics", {})
	var total_stalkers := int(result.get("stalkers_total", 0))
	# Убитые и всего - из одного источника (SpawnManager), иначе проценты врут
	var killed := int(result.get("stalkers_killed_sm", stats.get("stalkers_killed", 0)))
	var stolen := int(stats.get("artifacts_stolen", result.get("artifacts_stolen", 0)))
	var mutants_used := int(stats.get("mutants_created", result.get("mutants_spawned", 0)))
	var pulses := int(result.get("pulses_used", 0))
	var earned := float(stats.get("biomass_earned", result.get("biomass_earned", 0.0)))

	for cond in conditions:
		var ok := false
		match cond:
			"no_steal":
				ok = stolen == 0
			"no_pulse":
				ok = pulses == 0
			"hunter75":
				ok = total_stalkers > 0 and float(killed) / total_stalkers >= 0.75
			"hunter90":
				ok = total_stalkers > 0 and float(killed) / total_stalkers >= 0.90
			"budget4":
				ok = mutants_used <= 4
			"budget8":
				ok = mutants_used <= 8
			"rich":
				ok = earned >= float(rich_threshold(floor_num))
		if ok:
			stars += 1
		else:
			break
	return stars
