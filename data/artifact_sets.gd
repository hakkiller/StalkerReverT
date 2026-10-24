# data/artifact_sets.gd
extends RefCounted
class_name ArtifactSets

## СЕТЫ АРТЕФАКТОВ (v0.27.0 «ГОЛОС ЗОНЫ»).
## Артефакты гачи разбиты на 5 элементов по семьям аномалий. Пока в коллекции
## лежат 2+ арта одного элемента, аномалии этого элемента усиливаются в забеге:
## множитель урона (и радиус на 3-й ступени у управляющих сетов).
## Элементы подобраны по ANOMALY_ARTIFACT_MAP: каждый арт отвечает своей аномалии.
## Эксклюзивы Чёрных ящиков наследуют элемент базы (ash_tornado -> gravity_whirlwind).
## Не входят ни в один сет: common_artifact, rare_artifact.

const SETS := [
	{
		"id": "thermal", "name": "ЖАР", "color": Color(1.0, 0.55, 0.25),
		"artifacts": ["fireball_artifact", "gas_bottle_artifact", "storm_artifact"],
		"stage2": {"dmg": 1.18}, "stage3": {"dmg": 1.35},
	},
	{
		"id": "gravity", "name": "ГРАВИ", "color": Color(0.62, 0.55, 1.0),
		"artifacts": ["graviton_artifact", "jumper_artifact", "hourglass_artifact"],
		"stage2": {"dmg": 1.12}, "stage3": {"dmg": 1.25, "rad": 1.15},
	},
	{
		"id": "chem", "name": "ХИМИЯ", "color": Color(0.5, 0.9, 0.4),
		"artifacts": ["slime_artifact", "flesh_artifact", "void_artifact", "uranium_artifact"],
		"stage2": {"dmg": 1.15}, "stage3": {"dmg": 1.28},
	},
	{
		"id": "energy", "name": "ЭНЕРГО", "color": Color(0.4, 0.8, 1.0),
		"artifacts": ["spark_artifact", "battery_artifact", "energy_artifact"],
		"stage2": {"dmg": 1.15}, "stage3": {"dmg": 1.30},
	},
	{
		"id": "mystery", "name": "ТАЙНА", "color": Color(0.95, 0.8, 0.35),
		"artifacts": ["glowstick_artifact", "clock_artifact", "heart_artifact"],
		"stage2": {"dmg": 1.10}, "stage3": {"dmg": 1.22, "rad": 1.25},
	},
]


## Сет по артефакту (пусто - арт без элемента)
static func set_of_artifact(artifact_type: String) -> Dictionary:
	for s in SETS:
		if (s["artifacts"] as Array).has(artifact_type):
			return s
	return {}


## Сет по типу аномалии: тип -> арт (ANOMALY_ARTIFACT_MAP) -> сет.
## Эксклюзивные аномалии в бою несут БАЗОВЫЙ anomaly_type, так что отдельная
## карта не нужна - но на всякий случай проверяем базу эксклюзива.
static func set_of_anomaly(anomaly_type: String) -> Dictionary:
	var art: String = GachaData.get_artifact_for_anomaly(anomaly_type)
	if not art.is_empty():
		return set_of_artifact(art)
	for ax in GachaData.EXCLUSIVE_ANOMALIES:
		if str(ax["type"]) == anomaly_type:
			return set_of_artifact(GachaData.get_artifact_for_anomaly(str(ax["base"])))
	return {}


## Сколько артов сета есть в коллекции (won_artifacts - типы артов)
static func owned_count(set_def: Dictionary, won_artifacts: Array) -> int:
	if set_def.is_empty() or won_artifacts.is_empty():
		return 0
	var n := 0
	for t in set_def["artifacts"]:
		if won_artifacts.has(str(t)):
			n += 1
	return n


## Ступень сета: 0 (нет), 2, 3.
static func set_stage(set_def: Dictionary, won_artifacts: Array) -> int:
	var n := owned_count(set_def, won_artifacts)
	if n >= 3:
		return 3
	if n >= 2:
		return 2
	return 0


## Множитель урона аномалии от сета (1.0 - сета нет или не собран)
static func damage_mult_for_anomaly(anomaly_type: String, won_artifacts: Array) -> float:
	var s := set_of_anomaly(anomaly_type)
	if s.is_empty():
		return 1.0
	var stage := set_stage(s, won_artifacts)
	if stage < 2:
		return 1.0
	var b: Dictionary = s["stage3"] if stage >= 3 else s["stage2"]
	return float(b.get("dmg", 1.0))


## Множитель радиуса аномалии от сета (только управляющие сеты на 3-й ступени)
static func radius_mult_for_anomaly(anomaly_type: String, won_artifacts: Array) -> float:
	var s := set_of_anomaly(anomaly_type)
	if s.is_empty():
		return 1.0
	var stage := set_stage(s, won_artifacts)
	if stage < 3:
		return 1.0
	var b: Dictionary = s["stage3"]
	return float(b.get("rad", 1.0))


## Состояние всех сетов для UI галереи: [{def, have, size, stage}]
static func sets_state(won_artifacts: Array) -> Array:
	var out: Array = []
	for s in SETS:
		out.append({
			"def": s,
			"have": owned_count(s, won_artifacts),
			"size": (s["artifacts"] as Array).size(),
			"stage": set_stage(s, won_artifacts),
		})
	return out


## Ключ локализации текста ступени сета: "sets.bonus.{id}.{n}"
static func bonus_loc_key(set_id: String, stage: int) -> String:
	return "sets.bonus.%s.%d" % [set_id, stage]
