extends RefCounted
class_name DayNightData

## Цикл дня и ночи (v0.29.0 «СВЕТ И ТЕНЬ»): чистые расчёты суток.
## Менеджер managers/day_night_manager.gd красит свет/фон/туман по профилям,
## HUD показывает часы, зона даёт ночью бонус добычи. Автозагрузок не трогаем -
## файл должен компилироваться в смоках через godot -s (как RunEventsData).
##
## Сутки забега = CYCLE_SECONDS секунд реального времени, старт в 08:00.
## Фазы: рассвет -> день -> закат -> ночь (окна в phase_at).
## Ночь: добыча биомассы за сталкеров x1.25 (зона применяет в on_stalker_died).

const CYCLE_SECONDS := 300.0   # полные сутки забега: 5 минут реального времени
const START_HOUR := 8.0        # забег начинается утром
const NIGHT_HARVEST_MULT := 1.25

## Профили освещения. ДЕНЬ совпадает с базовыми значениями сцены
## (main.tscn + fog_manager.fog_color) - днём картинка не меняется.
const NIGHT := {"light": Color(0.36, 0.44, 0.62), "energy": 0.30, "bg": Color(0.045, 0.05, 0.085), "fog": Color(0.30, 0.33, 0.40), "amb": Color(0.15, 0.18, 0.26), "amb_e": 0.70}
const DAWN := {"light": Color(0.98, 0.72, 0.58), "energy": 0.75, "bg": Color(0.09, 0.08, 0.11), "fog": Color(0.56, 0.50, 0.50), "amb": Color(0.30, 0.27, 0.30), "amb_e": 0.85}
const DAY := {"light": Color(1.0, 0.95, 0.88), "energy": 1.20, "bg": Color(0.09, 0.10, 0.13), "fog": Color(0.66, 0.70, 0.72), "amb": Color(0.35, 0.37, 0.45), "amb_e": 1.00}
const DUSK := {"light": Color(1.0, 0.60, 0.34), "energy": 0.80, "bg": Color(0.10, 0.075, 0.07), "fog": Color(0.60, 0.46, 0.38), "amb": Color(0.38, 0.29, 0.26), "amb_e": 0.80}

## Ключевые точки суток: час -> профиль (между точками - линейный переход).
const KEYS := [
	{"h": 0.0, "p": NIGHT},
	{"h": 3.0, "p": NIGHT},
	{"h": 5.0, "p": DAWN},
	{"h": 7.0, "p": DAY},
	{"h": 16.0, "p": DAY},
	{"h": 18.5, "p": DUSK},
	{"h": 20.5, "p": NIGHT},
	{"h": 24.0, "p": NIGHT},
]

## Тексты анонса ночи (в определениях, как у RunEventsData - без Loc)
const NIGHT_NOTE := {
	"title_ru": "НОЧЬ ОПУСКАЕТСЯ НА ЗОНУ",
	"title_en": "NIGHT FALLS ON THE ZONE",
	"desc_ru": "Сталкеры теряют бдительность: добыча биомассы за них +25% до рассвета",
	"desc_en": "Stalkers lose vigilance: biomass harvest from them +25% until dawn",
}


static func wrap_hour(h: float) -> float:
	return fposmod(h, 24.0)


## Час суток от секунд с начала забега
static func hour_at(elapsed: float) -> float:
	return wrap_hour(START_HOUR + elapsed / CYCLE_SECONDS * 24.0)


static func clock_text(h: float) -> String:
	var hh := int(h) % 24
	var mm := int(fposmod(h, 1.0) * 60.0)
	return "%02d:%02d" % [hh, mm]


## Окна фаз: рассвет 4.5-7, день 7-17.5, закат 17.5-20.5, ночь - остальное
static func phase_at(h: float) -> String:
	var x := wrap_hour(h)
	if x >= 4.5 and x < 7.0:
		return "dawn"
	if x >= 7.0 and x < 17.5:
		return "day"
	if x >= 17.5 and x < 20.5:
		return "dusk"
	return "night"


static func is_night_at(h: float) -> bool:
	return phase_at(h) == "night"


static func phase_icon(phase: String) -> String:
	match phase:
		"day":
			return "☀"
		"dusk":
			return "🌇"
		"dawn":
			return "🌅"
		_:
			return "🌙"


## Цвет строки часов HUD под фазу
static func label_color(phase: String) -> Color:
	match phase:
		"day":
			return Color(1.0, 0.9, 0.55)
		"dusk":
			return Color(1.0, 0.62, 0.35)
		"dawn":
			return Color(0.95, 0.72, 0.75)
		_:
			return Color(0.62, 0.72, 1.0)


## Профиль освещения в данный час: линейная интерполяция между KEYS
static func sample(h: float) -> Dictionary:
	var x := wrap_hour(h)
	var a: Dictionary = KEYS[0]
	var b: Dictionary = KEYS[KEYS.size() - 1]
	for i in range(KEYS.size() - 1):
		if x >= float(KEYS[i]["h"]) and x <= float(KEYS[i + 1]["h"]):
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var span: float = float(b["h"]) - float(a["h"])
	var f := 0.0
	if span > 0.0:
		f = clampf((x - float(a["h"])) / span, 0.0, 1.0)
	var pa: Dictionary = a["p"]
	var pb: Dictionary = b["p"]
	return {
		"light": (pa["light"] as Color).lerp(pb["light"], f),
		"energy": lerpf(pa["energy"], pb["energy"], f),
		"bg": (pa["bg"] as Color).lerp(pb["bg"], f),
		"fog": (pa["fog"] as Color).lerp(pb["fog"], f),
		"amb": (pa["amb"] as Color).lerp(pb["amb"], f),
		"amb_e": lerpf(pa["amb_e"], pb["amb_e"], f),
	}
