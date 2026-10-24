extends RefCounted
class_name RunEventsData

## События Зоны (v0.28.0 «ПЕРЕДЫШКА С ПРИВКУСОМ»): во время передышки между
## волнами забег прерывается поп-апом с выбором 1 из 2. Тексты живут в
## определениях (как в ZoneEvents) - Loc не задействован, UI собирает строки.
## Эффекты применяет zone_controller (_apply_run_effect), поп-ап рисует
## ui/hud/run_popups.gd (RunPopups).
##
## Словарь эффектов:
##   biomass_now    - биомасса сразу
##   energy_now     - энергия сразу
##   reward_mult    - множитель ИТОГОВОЙ награды забега (перемножается)
##   bonus_flat     - плоский бонус к итоговой награде
##   crowd_next     - все следующие волны плотнее на N сталкеров
##   harvest_next   - множитель добычи с убийств до конца следующей волны
##   regen_next     - множитель регена энергии до конца следующей волны
##   heal_all       - полное лечение всех мутантов в бою
##   hp_buff/dmg_buff - множители статов новых мутантов до конца забега
##   cost_mult      - множитель цены мутантов (0.7 = дешевле)
##   reward_mutant  - наградной мутант в очередь спавна
##   artifact       - "random": случайный артефакт у Монолита + в коллекцию
##   rolls/anomaly_rolls - крутки мутантов/артефактов
##   storm_free     - N бесплатных случайных аномалий возле Монолита

const EVENTS := [
	{
		"id": "caravan_passes",
		"title_ru": "КАРАВАН МИМО", "title_en": "CARAVAN PASSING",
		"desc_ru": "Караван ходоков идёт краем Зоны и пока не видит тебя.",
		"desc_en": "A stalker caravan skirts the Zone and has not spotted you yet.",
		"options": [
			{"key": "trade", "label_ru": "ТОРГ", "label_en": "TRADE", "tone": "safe",
			 "desc_ru": "Сбагрить пару трофеев по-тихому: биомасса сразу.",
			 "desc_en": "Quietly sell a few trophies: biomass right away.",
			 "result_ru": "+450 биомассы от торговцев", "result_en": "+450 biomass from traders",
			 "effect": {"biomass_now": 450.0}},
			{"key": "rob", "label_ru": "ОБОБРАТЬ", "label_en": "PLUNDER", "tone": "risk",
			 "desc_ru": "Снять хабар со спящих: случайный артефакт у Монолита.",
			 "desc_en": "Lift loot off the sleeping: a random artifact at the Monolith.",
			 "result_ru": "Артефакт доставлен к Монолиту", "result_en": "An artifact was delivered to the Monolith",
			 "effect": {"artifact": "random"}},
		],
	},
	{
		"id": "anomaly_storm",
		"title_ru": "АНОМАЛЬНЫЙ ШТОРМ", "title_en": "ANOMALY STORM",
		"desc_ru": "Зона кипит: поле вокруг Монолита вспучивается новыми пятнами.",
		"desc_en": "The Zone boils: new blotches swell around the Monolith.",
		"options": [
			{"key": "wait", "label_ru": "ПЕРЕЖИДАТЬ", "label_en": "HOLD UP", "tone": "safe",
			 "desc_ru": "Укрыться в коконе: энергия копится вдвое быстрее.",
			 "desc_en": "Hunker in a cocoon: energy regenerates twice as fast.",
			 "result_ru": "Реген энергии x2 до конца следующей волны", "result_en": "Energy regen x2 until the next wave ends",
			 "effect": {"regen_next": 2.0}},
			{"key": "catch", "label_ru": "ЛОВИТЬ МОМЕНТ", "label_en": "RIDE IT OUT", "tone": "risk",
			 "desc_ru": "Шторм роняет чужую добычу: 3 бесплатных аномалии у Монолита.",
			 "desc_en": "The storm drops foreign prey: 3 free anomalies near the Monolith.",
			 "result_ru": "3 аномалии выросли у Монолита", "result_en": "3 anomalies sprang up near the Monolith",
			 "effect": {"storm_free": 3}},
		],
	},
	{
		"id": "pack_hunting",
		"title_ru": "СТАЯ НА ПОДХОДЕ", "title_en": "PACK INBOUND",
		"desc_ru": "Собаки подняли движуху: следующая волна придёт шумной.",
		"desc_en": "Dogs stirred the ground: the next wave comes loud.",
		"options": [
			{"key": "den", "label_ru": "ЛОГОВО", "label_en": "DEN DOWN", "tone": "safe",
			 "desc_ru": "Перевязать раненых: все мутанты в бою полностью здоровы.",
			 "desc_en": "Patch up the wounded: every mutant in the field is fully healed.",
			 "result_ru": "Мутанты вылечены полностью", "result_en": "Mutants fully healed",
			 "effect": {"heal_all": true}},
			{"key": "lure", "label_ru": "ПРИМАНКА", "label_en": "BAIT", "tone": "risk",
			 "desc_ru": "Заманить стаю в мясорубку: волна +3 сталкера, зато добыча x2.",
			 "desc_en": "Lure the pack into the grinder: wave +3 stalkers, but harvest x2.",
			 "result_ru": "Волна +3 сталкера, добыча x2 на волну", "result_en": "Wave +3 stalkers, harvest x2 for one wave",
			 "effect": {"crowd_next": 3, "harvest_next": 2.0}},
		],
	},
	{
		"id": "cargo_drop",
		"title_ru": "СБРОС ГРУЗА", "title_en": "CARGO DROP",
		"desc_ru": "Кто-то выронил контейнер, уходя от выброса. Он прямо там.",
		"desc_en": "Someone dropped a container fleeing a blowout. It is right there.",
		"options": [
			{"key": "take", "label_ru": "ЗАБРАТЬ", "label_en": "TAKE IT", "tone": "safe",
			 "desc_ru": "Вскрыть на месте: биомасса сразу.",
			 "desc_en": "Crack it open on the spot: biomass right away.",
			 "result_ru": "+350 биомассы из контейнера", "result_en": "+350 biomass from the container",
			 "effect": {"biomass_now": 350.0}},
			{"key": "stake", "label_ru": "ЗАЯВИТЬ", "label_en": "STAKE IT", "tone": "risk",
			 "desc_ru": "Сделать клеймо Зоны: волна +2 сталкера, награда забега +15%.",
			 "desc_en": "Brand it with the Zone: wave +2 stalkers, run reward +15%.",
			 "result_ru": "Волна +2 сталкера, награда забега +15%", "result_en": "Wave +2 stalkers, run reward +15%",
			 "effect": {"crowd_next": 2, "reward_mult": 1.15}},
		],
	},
	{
		"id": "blind_dog",
		"title_ru": "СЛЕПОЙ ПЁС", "title_en": "BLIND DOG",
		"desc_ru": "Хромой слепыш бродит у Монолита и скулит на луну.",
		"desc_en": "A lame blind whelp wanders near the Monolith, whining at the moon.",
		"options": [
			{"key": "kill", "label_ru": "ПРИСТРЕЛИТЬ", "label_en": "PUT DOWN", "tone": "safe",
			 "desc_ru": "Шкура и мясо тоже ресурс: биомасса сразу.",
			 "desc_en": "Hide and meat are resources too: biomass right away.",
			 "result_ru": "+200 биомассы со слепыша", "result_en": "+200 biomass off the whelp",
			 "effect": {"biomass_now": 200.0}},
			{"key": "tame", "label_ru": "ПРИРУЧИТЬ", "label_en": "TAME IT", "tone": "risk",
			 "desc_ru": "Накормить и пометить: 1 крутка мутантов.",
			 "desc_en": "Feed it and tag it: 1 mutant roll.",
			 "result_ru": "1 крутка мутантов получена", "result_en": "1 mutant roll received",
			 "effect": {"rolls": 1}},
		],
	},
	{
		"id": "early_hush",
		"title_ru": "РАННЯЯ ТИШИНА", "title_en": "EARLY HUSH",
		"desc_ru": "Зона замолчала не к добру: воздух звенит перед броском.",
		"desc_en": "The Zone went quiet the bad way: the air rings before a lunge.",
		"options": [
			{"key": "hide", "label_ru": "ЗАТАИТЬСЯ", "label_en": "LIE LOW", "tone": "safe",
			 "desc_ru": "Собрать конденсат в тишине: энергия сразу.",
			 "desc_en": "Gather condensate in the hush: energy right away.",
			 "result_ru": "+250 энергии собрано", "result_en": "+250 energy gathered",
			 "effect": {"energy_now": 250.0}},
			{"key": "push", "label_ru": "ПОДНАЖАТЬ", "label_en": "PUSH ON", "tone": "risk",
			 "desc_ru": "Идти на звук: волна +2 сталкера, цены мутантов -30%.",
			 "desc_en": "Move toward the sound: wave +2 stalkers, mutant costs -30%.",
			 "result_ru": "Волна +2 сталкера, мутанты дешевле на 30%", "result_en": "Wave +2 stalkers, mutants 30% cheaper",
			 "effect": {"crowd_next": 2, "cost_mult": 0.7}},
		],
	},
	{
		"id": "corpse_loot",
		"title_ru": "ХАБАР ХОДОКОВ", "title_en": "WALKER'S LOOT",
		"desc_ru": "Поле боя остывает. На трупах - рюкзаки, в рюкзаках - удача.",
		"desc_en": "The battlefield cools. Packs on the dead, luck inside the packs.",
		"options": [
			{"key": "search", "label_ru": "ОБЫСКАТЬ", "label_en": "SEARCH", "tone": "safe",
			 "desc_ru": "Перетрясти всё: биомасса сразу.",
			 "desc_en": "Turn everything out: biomass right away.",
			 "result_ru": "+300 биомассы из рюкзаков", "result_en": "+300 biomass from the packs",
			 "effect": {"biomass_now": 300.0}},
			{"key": "greed", "label_ru": "ЖАДНИЧАТЬ", "label_en": "GET GREEDY", "tone": "risk",
			 "desc_ru": "Снять всё до нитки: добыча с убийств x2 на следующей волне.",
			 "desc_en": "Strip them to the bone: kill harvest x2 for the next wave.",
			 "result_ru": "Добыча x2 до конца следующей волны", "result_en": "Harvest x2 until the next wave ends",
			 "effect": {"harvest_next": 2.0}},
		],
	},
	{
		"id": "dark_bargain",
		"title_ru": "ТЁМНАЯ СДЕЛКА", "title_en": "DARK BARGAIN",
		"desc_ru": "Кто-то шепчет из-под земли: «Отдай малое - получишь великое».",
		"desc_en": "Something whispers from below: \"Give the small - receive the great.\"",
		"options": [
			{"key": "refuse", "label_ru": "ОТКАЗАТЬСЯ", "label_en": "REFUSE", "tone": "safe",
			 "desc_ru": "Не вестись: мутанты окрепнут для новых спавнов (+20% HP).",
			 "desc_en": "Pay it no mind: newly spawned mutants harden (+20% HP).",
			 "result_ru": "Новые мутанты +20% HP до конца забега", "result_en": "New mutants +20% HP for the run",
			 "effect": {"hp_buff": 1.2}},
			{"key": "accept", "label_ru": "СОГЛАСИТЬСЯ", "label_en": "ACCEPT", "tone": "risk",
			 "desc_ru": "Шептун щедр: награда забега +25%, но волна +3 сталкера.",
			 "desc_en": "The whisperer is generous: run reward +25%, but wave +3 stalkers.",
			 "result_ru": "Награда забега +25%, волна +3 сталкера", "result_en": "Run reward +25%, wave +3 stalkers",
			 "effect": {"reward_mult": 1.25, "crowd_next": 3}},
		],
	},
]


## Торговец «Седой»: кнопка в HUD во время подготовки и передышек,
## магазин - поп-ап с паузой. Товар закрывается биомассой забега.
const TRADER_ITEMS := [
	{
		"id": "medkit", "name_ru": "АПТЕЧКА", "name_en": "MEDKIT",
		"desc_ru": "Полное лечение всех мутантов в бою. 2 раза за забег.",
		"desc_en": "Fully heal every mutant in the field. Twice per run.",
		"cost": 180.0, "stock": 2, "effect": {"heal_all": true},
	},
	{
		"id": "rage", "name_ru": "ЯРОСТЬ", "name_en": "FURY",
		"desc_ru": "Новые мутанты злее: +20% урона до конца забега.",
		"desc_en": "Fresh mutants turn meaner: +20% damage for the run.",
		"cost": 250.0, "stock": 1, "effect": {"dmg_buff": 1.2},
	},
	{
		"id": "armor", "name_ru": "БРОНЯ", "name_en": "ARMOR",
		"desc_ru": "Новые мутанты крепче: +20% HP до конца забега.",
		"desc_en": "Fresh mutants turn tougher: +20% HP for the run.",
		"cost": 250.0, "stock": 1, "effect": {"hp_buff": 1.2},
	},
	{
		"id": "crate", "name_ru": "ЯЩИК СНАБЖЕНИЯ", "name_en": "SUPPLY CRATE",
		"desc_ru": "Случайный артефакт у Монолита, сразу в коллекцию.",
		"desc_en": "A random artifact at the Monolith, straight to the collection.",
		"cost": 400.0, "stock": 1, "effect": {"artifact": "random"},
	},
	{
		"id": "roll", "name_ru": "КРУТКА", "name_en": "ROLL",
		"desc_ru": "1 крутка мутантов сразу, уровень забега.",
		"desc_en": "1 mutant roll right away, run level.",
		"cost": 350.0, "stock": 1, "effect": {"rolls": 1},
	},
	{
		"id": "harvester", "name_ru": "ЖАТВА", "name_en": "HARVEST",
		"desc_ru": "Добыча с убийств x2 до конца следующей волны.",
		"desc_en": "Kill harvest x2 until the next wave ends.",
		"cost": 220.0, "stock": 1, "effect": {"harvest_next": 2.0},
	},
]


## Типы аномалий для шторма (фильтруются по наличию сцены в забеге)
const STORM_TYPES := ["heat_anomaly", "electric_anomaly", "acid_anomaly", "gravity_vortex", "gravity_lift", "radiation_hotspot", "chemical_jelly", "thermal_steam"]


## Случайное событие, не равное предыдущему
static func pick_event(exclude_id: String = "") -> Dictionary:
	if EVENTS.is_empty():
		return {}
	var pool: Array = []
	for ev in EVENTS:
		if str(ev.get("id", "")) != exclude_id:
			pool.append(ev)
	if pool.is_empty():
		pool = EVENTS
	return pool[randi() % pool.size()]


## Цена товара у Седого: база + дорожает с каждой волной (+12% за волну)
static func trader_cost(item: Dictionary, wave: int) -> int:
	var w: int = maxi(wave - 1, 0)
	return int(round(float(item.get("cost", 0.0)) * (1.0 + 0.12 * float(w))))


## Метка тона опции: безопасно/риск
static func tone_of(option: Dictionary) -> String:
	return str(option.get("tone", "safe"))
