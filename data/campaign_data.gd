# data/campaign_data.gd
extends RefCounted
class_name CampaignData

## Кампания «100 колец Зоны».
## Уровень = один забег. Победа открывает следующий уровень, поражение - реплей.
## Все параметры врагов уровня считаются здесь: волны, состав рангов,
## множители HP/урона/скорости, награда. Полный дизайн - docs/campaign_design.md

const TOTAL_LEVELS: int = 100

# Режимы сложности: множитель к статам врагов, выбирается в лаборатории
const MODE_EASY: String = "easy"
const MODE_NORMAL: String = "normal"
const MODE_HARD: String = "hard"

const MODE_MULTIPLIERS := {
	MODE_EASY: 0.85,
	MODE_NORMAL: 1.0,
	MODE_HARD: 1.2
}

const MODE_NAMES := {
	MODE_EASY: "Сталкер",
	MODE_NORMAL: "Ветеран",
	MODE_HARD: "Легенда"
}

# Главы кампании: 10 глав по 10 уровней.
# waves_start      - число волн в начале главы
# waves_extra_from - уровень, с которого открывается ещё одна волна (0 = нет)
# count_start/end  - сталкеров на волну (интерполируется внутри главы)
# mix              - состав рангов [новички, ветераны, мастера] в процентах
# stat_start/end   - множитель HP и урона врагов (интерполируется)
# speed_start/end  - множитель скорости врагов (интерполируется)
# pulses_to_win    - выбросов для победы
# wave_break       - пауза между волнами, сек
const CHAPTERS := [
	{
		"start": 1, "end": 10, "title": "Тропы новичков",
		"desc": "Первые сталкеры заходят в Зону за лёгкой добычей.",
		"waves_start": 3, "waves_extra_from": 0,
		"count_start": 8, "count_end": 10,
		"mix": [90, 10, 0],
		"stat_start": 1.00, "stat_end": 1.08,
		"speed_start": 1.0, "speed_end": 1.0,
		"pulses_to_win": 3, "wave_break": 45.0
	},
	{
		"start": 11, "end": 20, "title": "Периметр",
		"desc": "Слухи о богатой Зоне привлекают организованные группы.",
		"waves_start": 3, "waves_extra_from": 0,
		"count_start": 10, "count_end": 12,
		"mix": [80, 20, 0],
		"stat_start": 1.08, "stat_end": 1.16,
		"speed_start": 1.0, "speed_end": 1.0,
		"pulses_to_win": 3, "wave_break": 45.0
	},
	{
		"start": 21, "end": 30, "title": "Стаи и ловушки",
		"desc": "Заходят ветераны, а с 26-го кольца Зона получает четвёртую волну.",
		"waves_start": 3, "waves_extra_from": 26,
		"count_start": 11, "count_end": 13,
		"mix": [70, 28, 2],
		"stat_start": 1.16, "stat_end": 1.24,
		"speed_start": 1.0, "speed_end": 1.0,
		"pulses_to_win": 3, "wave_break": 45.0
	},
	{
		"start": 31, "end": 40, "title": "Дороги смерти",
		"desc": "Четыре волны по проторённым маршрутам: ветераны доминируют.",
		"waves_start": 4, "waves_extra_from": 0,
		"count_start": 12, "count_end": 14,
		"mix": [60, 36, 4],
		"stat_start": 1.24, "stat_end": 1.30,
		"speed_start": 1.0, "speed_end": 1.0,
		"pulses_to_win": 4, "wave_break": 45.0
	},
	{
		"start": 41, "end": 50, "title": "Радиоактивный дождь",
		"desc": "С 46-го кольца идут пять волн, в составе замечены мастера.",
		"waves_start": 4, "waves_extra_from": 46,
		"count_start": 13, "count_end": 15,
		"mix": [52, 42, 6],
		"stat_start": 1.30, "stat_end": 1.36,
		"speed_start": 1.0, "speed_end": 1.0,
		"pulses_to_win": 4, "wave_break": 45.0
	},
	{
		"start": 51, "end": 60, "title": "Тёмная долина",
		"desc": "Пять волн без различий день-ночь: сталкеры больше не пугаются.",
		"waves_start": 5, "waves_extra_from": 0,
		"count_start": 14, "count_end": 16,
		"mix": [44, 48, 8],
		"stat_start": 1.36, "stat_end": 1.42,
		"speed_start": 1.0, "speed_end": 1.0,
		"pulses_to_win": 4, "wave_break": 45.0
	},
	{
		"start": 61, "end": 70, "title": "Лабиринт",
		"desc": "Каждый десятый сталкер - мастер. Он знает, где лежат артефакты.",
		"waves_start": 5, "waves_extra_from": 0,
		"count_start": 15, "count_end": 17,
		"mix": [38, 52, 10],
		"stat_start": 1.42, "stat_end": 1.46,
		"speed_start": 1.0, "speed_end": 1.0,
		"pulses_to_win": 4, "wave_break": 45.0
	},
	{
		"start": 71, "end": 80, "title": "Выжженная земля",
		"desc": "Пятая часть Зоны выгорела дотла, но караваны всё идут.",
		"waves_start": 5, "waves_extra_from": 0,
		"count_start": 16, "count_end": 18,
		"mix": [32, 54, 14],
		"stat_start": 1.46, "stat_end": 1.52,
		"speed_start": 1.0, "speed_end": 1.0,
		"pulses_to_win": 5, "wave_break": 40.0
	},
	{
		"start": 81, "end": 90, "title": "Территория Монолита",
		"desc": "С 86-го кольца волн шесть. Сердце Зоны бьётся чаще.",
		"waves_start": 5, "waves_extra_from": 86,
		"count_start": 17, "count_end": 19,
		"mix": [26, 56, 18],
		"stat_start": 1.52, "stat_end": 1.58,
		"speed_start": 1.0, "speed_end": 1.05,
		"pulses_to_win": 5, "wave_break": 40.0
	},
	{
		"start": 91, "end": 100, "title": "Последний рубеж",
		"desc": "Финальные кольца. Каждый караван - армия, каждый мастер - легенда.",
		"waves_start": 6, "waves_extra_from": 0,
		"count_start": 18, "count_end": 20,
		"mix": [22, 58, 20],
		"stat_start": 1.58, "stat_end": 1.65,
		"speed_start": 1.05, "speed_end": 1.10,
		"pulses_to_win": 5, "wave_break": 40.0
	}
]

# Боссовые уровни (каждый десятый): именной караван с модификаторами.
# mix_override  - заменить состав рангов
# count_pct     - прибавка к количеству сталкеров (0.10 = +10%)
# hp_extra      - прибавка к множителю HP поверх статов главы
# damage_extra  - прибавка к множителю урона
# speed_extra   - прибавка к множителю скорости
# wave_break    - переопределить паузу между волнами
# Награда за босса умножается на 2.5
const BOSSES := {
	10: {
		"title": "Первый караван", "desc": "Большая группа новичков под началом ветеранов.",
		"mix_override": [70, 30, 0]
	},
	20: {
		"title": "Ночные ходоки", "desc": "Караван идёт ночью и движется быстрее обычного.",
		"speed_extra": 0.15
	},
	30: {
		"title": "Военизированный отряд", "desc": "Полбоевой единицы ветеранов с ремнями и приборами.",
		"mix_override": [55, 45, 0], "count_pct": 0.10
	},
	40: {
		"title": "Бронеколонна", "desc": "Все в броне: жить будут заметно дольше.",
		"hp_extra": 0.20
	},
	50: {
		"title": "Полночный караван", "desc": "Первая полноценная встреча с мастерами Зоны.",
		"mix_override": [50, 40, 10], "count_pct": 0.10
	},
	60: {
		"title": "Картографы Зоны", "desc": "Знают тропы: паузы между волнами короче.",
		"wave_break": 30.0, "count_pct": 0.10
	},
	70: {
		"title": "Легенда Зоны", "desc": "Мастера с именем. Их боятся даже свои.",
		"mix_override": [45, 40, 15], "hp_extra": 0.15
	},
	80: {
		"title": "Штурм", "desc": "Не караван - штурмовой отряд. Идут волнами без передышки.",
		"count_pct": 0.15, "wave_break": 30.0
	},
	90: {
		"title": "Долг странников", "desc": "Пятая часть отряда - мастера. Идут вернуть своих, и идут толпой.",
		"mix_override": [40, 40, 20], "count_pct": 0.20
	},
	100: {
		"title": "Последний караван", "desc": "Финальный штурм Монолита. Всё, что у Зоны есть, - против всего, что есть у них.",
		"mix_override": [35, 40, 25], "hp_extra": 0.10, "damage_extra": 0.10, "count_pct": 0.10
	}
}

# Множитель награды при переигрывании уже пройденного уровня
const REPLAY_REWARD_FACTOR: float = 0.3


static func get_chapter(level: int) -> Dictionary:
	var lvl: int = clampi(level, 1, TOTAL_LEVELS)
	for chapter in CHAPTERS:
		if lvl >= int(chapter["start"]) and lvl <= int(chapter["end"]):
			return chapter
	return CHAPTERS[CHAPTERS.size() - 1]


static func get_boss_data(level: int) -> Dictionary:
	return BOSSES.get(clampi(level, 1, TOTAL_LEVELS), {})


## Полный набор параметров уровня: их применяют ZoneController и SpawnManager
static func get_level_params(level: int, mode: String = MODE_NORMAL) -> Dictionary:
	var lvl: int = clampi(level, 1, TOTAL_LEVELS)
	var chapter: Dictionary = get_chapter(lvl)
	var span: float = float(int(chapter["end"]) - int(chapter["start"]))
	var t: float = 0.0 if span <= 0.0 else float(lvl - int(chapter["start"])) / span

	var waves: int = int(chapter["waves_start"])
	var extra_from: int = int(chapter["waves_extra_from"])
	if extra_from > 0 and lvl >= extra_from:
		waves += 1

	var count_min: int = roundi(lerpf(float(chapter["count_start"]), float(chapter["count_end"]), t))
	var count_max: int = count_min + 2

	var mix: Array = (chapter["mix"] as Array).duplicate()

	var mode_mult: float = float(MODE_MULTIPLIERS.get(mode, 1.0))
	var stat_mult: float = lerpf(float(chapter["stat_start"]), float(chapter["stat_end"]), t) * mode_mult
	var speed_mult: float = lerpf(float(chapter["speed_start"]), float(chapter["speed_end"]), t)

	var is_boss: bool = BOSSES.has(lvl)
	var boss: Dictionary = get_boss_data(lvl)
	var hp_mult: float = stat_mult
	var damage_mult: float = stat_mult

	if is_boss:
		if boss.has("mix_override"):
			mix = (boss["mix_override"] as Array).duplicate()
		if boss.has("count_pct"):
			count_min = roundi(count_min * (1.0 + float(boss["count_pct"])))
			count_max = count_min + 2
		if boss.has("hp_extra"):
			hp_mult *= 1.0 + float(boss["hp_extra"])
		if boss.has("damage_extra"):
			damage_mult *= 1.0 + float(boss["damage_extra"])
		if boss.has("speed_extra"):
			speed_mult *= 1.0 + float(boss["speed_extra"])

	var wave_break: float = float(boss.get("wave_break", chapter["wave_break"]))
	var reward_bonus: float = (100.0 + 8.0 * float(lvl)) * (2.5 if is_boss else 1.0)

	return {
		"level": lvl,
		"chapter_title": String(chapter["title"]),
		"chapter_desc": String(chapter["desc"]),
		"title": String(boss.get("title", "Уровень %d" % lvl)),
		"desc": String(boss.get("desc", chapter["desc"])),
		"is_boss": is_boss,
		"waves": waves,
		"count_min": count_min,
		"count_max": count_max,
		"mix": mix,
		"hp_mult": hp_mult,
		"damage_mult": damage_mult,
		"speed_mult": speed_mult,
		"wave_break": wave_break,
		"pulses_to_win": int(chapter["pulses_to_win"]),
		"reward_bonus": reward_bonus,
		"mode": mode
	}


## Короткая подпись для UI: «Уровень 23/100 - Стаи и ловушки»
static func get_progress_label(level: int) -> String:
	var lvl: int = clampi(level, 1, TOTAL_LEVELS)
	var chapter: Dictionary = get_chapter(lvl)
	var prefix: String = "КАРАВАН " if BOSSES.has(lvl) else "Уровень "
	return "%s%d/100 - %s" % [prefix, lvl, chapter["title"]]


static func get_mode_name(mode: String) -> String:
	return String(MODE_NAMES.get(mode, MODE_NAMES[MODE_NORMAL]))
