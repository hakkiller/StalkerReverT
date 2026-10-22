extends RefCounted
class_name ZoneEvents

## События выживания: каждая 5-я волна - нападение группировки Зоны.
## Чем выше волна, тем сильнее враг (растут множители и состав рангов)
## и тем щедрее награда (биомасса + гача с бонусом уровня).

const EVENT_WAVE_STEP: int = 5

# mix = [новички, ветераны, мастера] в процентах
const EVENTS := [
	{
		"id": "duty_scouts", "title_ru": "РАЗВЕДКА «ДОЛГА»", "title_en": "DUTY SCOUTS",
		"desc_ru": "Долг выслал разведгруппу к Монолиту", "desc_en": "Duty dispatched a recon squad to the Monolith",
		"mix": [70, 30, 0], "count_mult": 1.0, "hp_mult": 1.2, "dmg_mult": 1.2,
		"reward_mult": 2.0, "gacha_bonus": 5,
	},
	{
		"id": "duty_assault", "title_ru": "ШТУРМ «ДОЛГА»", "title_en": "DUTY ASSAULT",
		"desc_ru": "Штурмовая группа Долга идёт на прорыв", "desc_en": "A Duty assault group is pushing through",
		"mix": [40, 50, 10], "count_mult": 1.1, "hp_mult": 1.4, "dmg_mult": 1.4,
		"reward_mult": 2.5, "gacha_bonus": 10,
	},
	{
		"id": "mercenaries", "title_ru": "НАЁМНИКИ", "title_en": "MERCENARIES",
		"desc_ru": "Кто-то хорошо заплатил за Монолит", "desc_en": "Someone paid well for the Monolith",
		"mix": [20, 60, 20], "count_mult": 1.2, "hp_mult": 1.6, "dmg_mult": 1.6,
		"reward_mult": 3.0, "gacha_bonus": 15,
	},
	{
		"id": "monolith_fanatics", "title_ru": "ФАНАТИКИ «МОНОЛИТА»", "title_en": "MONOLITH FANATICS",
		"desc_ru": "Ослеплённые верой идут на смерть", "desc_en": "Blinded by faith, they march to death",
		"mix": [10, 50, 40], "count_mult": 1.3, "hp_mult": 1.8, "dmg_mult": 1.8,
		"reward_mult": 3.5, "gacha_bonus": 20,
	},
	{
		"id": "legend_hunters", "title_ru": "ОХОТНИКИ ЗА ЛЕГЕНДОЙ", "title_en": "LEGEND HUNTERS",
		"desc_ru": "Лучшие сталкеры Зоны идут за артефактами", "desc_en": "The Zone's finest stalkers come for artifacts",
		"mix": [0, 40, 60], "count_mult": 1.4, "hp_mult": 2.0, "dmg_mult": 2.0,
		"reward_mult": 4.0, "gacha_bonus": 25,
	},
]


static func is_event_wave(wave: int) -> bool:
	return wave > 0 and wave % EVENT_WAVE_STEP == 0


## Событие волны: базовый тир по номеру + эскалация за каждый полный цикл
static func get_event(wave: int) -> Dictionary:
	if not is_event_wave(wave):
		return {}
	@warning_ignore("integer_division")
	var cycle: int = (wave / EVENT_WAVE_STEP - 1) / EVENTS.size()
	@warning_ignore("integer_division")
	var tier: int = (wave / EVENT_WAVE_STEP - 1) % EVENTS.size()
	var event: Dictionary = EVENTS[tier].duplicate()
	# Каждый пройденный цикл событий (25 волн) усиливает врага и награду
	var escalation: float = 1.0 + float(cycle) * 0.25
	event["hp_mult"] = float(event["hp_mult"]) * escalation
	event["dmg_mult"] = float(event["dmg_mult"]) * escalation
	event["reward_mult"] = float(event["reward_mult"]) * escalation
	event["gacha_bonus"] = int(event["gacha_bonus"]) + cycle * 10
	event["wave"] = wave
	return event
