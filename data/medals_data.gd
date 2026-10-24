extends RefCounted
class_name MedalsData

## Медали Зоны — ачивки на пожизненных счётчиках сейва (Prog.counts).
## Условия — простые пороги (cond.type / cond.value), награды выдаёт
## тот же движок, что сундуки трека (Prog._apply_reward).
## Тексты в определениях (как в ZoneEvents) — Loc не задействован.

const MEDALS := [
	{
		"id": "first_run", "icon": "▶", "t_ru": "ПЕРВЫЙ ШАГ", "t_en": "FIRST STEP",
		"d_ru": "Провести первый забег", "d_en": "Complete your first run",
		"cond": {"type": "runs", "value": 1}, "reward": {"bio": 500},
	},
	{
		"id": "first_win", "icon": "✚", "t_ru": "ПЕРВАЯ ПОБЕДА", "t_en": "FIRST BLOOD",
		"d_ru": "Выиграть свой первый забег", "d_en": "Win your first run",
		"cond": {"type": "wins", "value": 1}, "reward": {"bio": 800},
	},
	{
		"id": "veteran25", "icon": "★", "t_ru": "ОБЫВАТЕЛЬ", "t_en": "REGULAR",
		"d_ru": "Провести 25 забегов", "d_en": "Complete 25 runs",
		"cond": {"type": "runs", "value": 25}, "reward": {"mut": 2},
	},
	{
		"id": "champion25", "icon": "☠", "t_ru": "ГРОЗА ЗОНЫ", "t_en": "ZONE TERROR",
		"d_ru": "Выиграть 25 забегов", "d_en": "Win 25 runs",
		"cond": {"type": "wins", "value": 25}, "reward": {"mut": 3},
	},
	{
		"id": "centurion100", "icon": "☑", "t_ru": "СТАЯ ЗА СОБОЙ", "t_en": "PACK LEADER",
		"d_ru": "Провести 100 забегов", "d_en": "Complete 100 runs",
		"cond": {"type": "runs", "value": 100}, "reward": {"sp": 25},
	},
	{
		"id": "floor10", "icon": "▲", "t_ru": "ПЕРВЫЙ ЯРУС", "t_en": "FIRST TIER",
		"d_ru": "Открыть этаж 10 Башни Монолита", "d_en": "Reach Tower floor 10",
		"cond": {"type": "tower_floor", "value": 10}, "reward": {"ano": 2},
	},
	{
		"id": "floor50", "icon": "▲▲", "t_ru": "СЕРДИНА БАШНИ", "t_en": "TOWER HEART",
		"d_ru": "Открыть этаж 50 Башни Монолита", "d_en": "Reach Tower floor 50",
		"cond": {"type": "tower_floor", "value": 50}, "reward": {"sp": 40},
	},
	{
		"id": "sarcofag", "icon": "☢", "t_ru": "САРКОФАГ", "t_en": "SARCOPHAGUS",
		"d_ru": "Открыть этаж 100 — вершину Башни", "d_en": "Reach floor 100 - the Tower top",
		"cond": {"type": "tower_floor", "value": 100}, "reward": {"sp": 100},
	},
	{
		"id": "waves10", "icon": "≈", "t_ru": "ДЕСЯТКА", "t_en": "THE TEN",
		"d_ru": "Пережить 10 волн выживания за забег", "d_en": "Survive 10 waves in one run",
		"cond": {"type": "best_wave", "value": 10}, "reward": {"bio": 1500},
	},
	{
		"id": "waves30", "icon": "≈≈", "t_ru": "ФАЗА ЛЕГЕНДЫ", "t_en": "LEGEND PHASE",
		"d_ru": "Пережить 30 волн — фаза легенды", "d_en": "Survive 30 waves - the legend phase",
		"cond": {"type": "best_wave", "value": 30}, "reward": {"sp": 30},
	},
	{
		"id": "chimera", "icon": "◉", "t_ru": "ДЖЕКПОТ", "t_en": "JACKPOT",
		"d_ru": "Поймать Химеру в гаче", "d_en": "Pull the Chimera from gacha",
		"cond": {"type": "has_chimera", "value": 1}, "reward": {"sp": 20},
	},
	{
		"id": "collector20", "icon": "▦", "t_ru": "КОЛЛЕКЦИОНЕР", "t_en": "COLLECTOR",
		"d_ru": "Собрать 20 видов галереи Зоны", "d_en": "Collect 20 gallery species",
		"cond": {"type": "collection", "value": 20}, "reward": {"mut": 2},
	},
	{
		"id": "collector34", "icon": "▩", "t_ru": "ПОЛНЫЙ АРХИВ", "t_en": "FULL ARCHIVE",
		"d_ru": "Собрать все 34 вида галереи", "d_en": "Collect all 34 gallery species",
		"cond": {"type": "collection", "value": 34}, "reward": {"sp": 80},
	},
	{
		"id": "maxstar", "icon": "★5", "t_ru": "ПЯТАЯ ЗВЕЗДА", "t_en": "FIFTH STAR",
		"d_ru": "Прокачать любого мутанта до ★5", "d_en": "Raise any mutant to 5 stars",
		"cond": {"type": "max_star", "value": 1}, "reward": {"ano": 3},
	},
	{
		"id": "bio100k", "icon": "$", "t_ru": "БИОМАСС-БАРОН", "t_en": "BIOMASS BARON",
		"d_ru": "Заработать 100 000 биомассы за всё время", "d_en": "Earn 100,000 biomass lifetime",
		"cond": {"type": "biomass_earned", "value": 100000}, "reward": {"mut": 2},
	},
	{
		"id": "arena5", "icon": "⚔", "t_ru": "ГЛАДИАТОР", "t_en": "GLADIATOR",
		"d_ru": "Победить в 5 боях арены", "d_en": "Win 5 arena fights",
		"cond": {"type": "arena_wins", "value": 5}, "reward": {"bio": 2000},
	},
	{
		"id": "kills100", "icon": "✖", "t_ru": "МРАЗОБОЙ", "t_en": "STALKER BANE",
		"d_ru": "Уничтожить 100 сталкеров", "d_en": "Destroy 100 stalkers",
		"cond": {"type": "kills", "value": 100}, "reward": {"ano": 2},
	},
	{
		"id": "week_calendar", "icon": "⚑", "t_ru": "ВЕРНЫЙ СТОРОЖ", "t_en": "FAITHFUL WARDEN",
		"d_ru": "Закрыть полный цикл календаря входа (7 дней)", "d_en": "Complete a full login calendar cycle (7 days)",
		"cond": {"type": "calendar_cycles", "value": 1}, "reward": {"sp": 15},
	},
]


static func by_id(id: String) -> Dictionary:
	for m in MEDALS:
		if str(m["id"]) == id:
			return m
	return {}
