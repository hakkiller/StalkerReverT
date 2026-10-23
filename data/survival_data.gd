# data/survival_data.gd
extends RefCounted
class_name SurvivalData

## Режим выживания: волны бесконечны, каждая следующая сильнее,
## награда растёт с числом пройденных волн. Забег заканчивается только
## гибелью Зоны (сталкер коснулся Монолита).
## Все параметры волны считаются здесь - единственное место правки баланса.
##
## ФАЗА ЛЕГЕНДЫ (волны 31+, спека design_inbox/_done/survival_lategame):
## до 31-й формулы прежние; дальше потолок количества держим (28 - нет пула
## сущностей), давление растёт составом (мастера до 70%, новички исчезают),
## мягким склоном статов, модификаторами волн и бесплатными выбросами.

# Награда за пройденные волны: base x N + growth x N x (N+1).
# N=10: 1440, N=20: 3680, N=30: 6720, N=50: 15200 биомассы (плюс боевой доход)
const REWARD_PER_WAVE_BASE: float = 100.0
const REWARD_PER_WAVE_GROWTH: float = 4.0

# Потолки, чтобы ранние волны не были пустыми, а поздние - не рвали производительность
const MAX_COUNT_PER_WAVE: int = 28
const MAX_MASTER_PERCENT: int = 30
const MAX_VETERAN_PERCENT: int = 55
const MAX_SPEED_MULT: float = 1.15
const MIN_WAVE_BREAK: float = 30.0

# Логика победы (v0.21.0 «ЛИГА ВОЛН»): пережил 30+ волн - ПОБЕДА забега,
# независимо от волны, на которой Зона пала. До порога гибель Зоны
# у Монолита остаётся поражением.
const VICTORY_WAVE: int = 30

# ==================== ФАЗА ЛЕГЕНДЫ (волны 31+) ====================
# Всё ниже 31-й не меняется. Давление растёт составом/статами/модификаторами,
# НЕ численностью: потолок 28 сталкеров держим (нет пула сущностей).

const LEGEND_START: int = 31             # первая волна фазы легенд
const LEGEND_STAT_SLOPE: float = 0.035   # склон статов после 30-й (было 0.04).
                                          # Перебор лютый -> 0.03; вяло -> 0.04
const PHASE_NAMES := {
	31: "ЛЕГЕНДЫ ЗОНЫ", 41: "ВЛАДЫКИ ЗОНЫ", 51: "СЕРДЦЕ ЗОНЫ",
}
const PHASE_POSTFX_STEP: float = 1.1     # постэффект темнее на входе в фазу
const POSTFX_NIGHT_CAP: float = 1.6      # суммарный кап (Припять x1.25 + ночь x1.4)

# Состав: мастера растут, новички исчезают (пол новичка = 0 с 31-й)
const MASTER_T1_PER_WAVE: float = 2.0    # 31-40: 30 -> 50%
const MASTER_T2_PER_WAVE: float = 1.0    # 41-50: 50 -> 60%
const MASTER_T3_PER_WAVE: float = 0.5    # 51+: к 70% к 70-й волне
const MASTER_CAP: int = 70               # жёсткий потолок мастеров навсегда
const VETERAN_CAP_LATE: int = 55         # как сейчас

# Скорость и передышка позднего хвоста
const SPEED_SLOPE_LATE: float = 0.005    # с 41-й, +0.5%/волна
const SPEED_CAP_LATE: float = 1.25       # к 60-й (было 1.15)
const BREAK_LORDS: float = 25.0          # передышка с 41-й
const BREAK_HEART: float = 20.0          # передышка с 51-й

# ==================== МОДИФИКАТОРЫ ВОЛН ====================
# Вешаются на волны >= 32, кроме событийных (N%5==0) и выбросных (N%10==3).
# Один модификатор на волну. Ротация детерминированная - расклад выучиваем.
# Словари совпадают по полям с show_event_note (title_ru/desc_ru и т.д.)

const MODIFIER_START_WAVE: int = 32
const MODIFIER_HASH_A: int = 7           # idx = (N*A + B) % pool.size()
const MODIFIER_HASH_B: int = 13          # перемешать ротацию - поменять A/B

const MODIFIERS := {
	"em_fog": {
		"title_ru": "ЭМ-ТУМАН", "title_en": "EM FOG",
		"desc_ru": "Осадка энергии: реген x0.5 на волну",
		"desc_en": "Energy drain: regen x0.5 for the wave",
		"regen_mult": 0.5,
	},
	"night": {
		"title_ru": "НОЧЬ", "title_en": "NIGHT",
		"desc_ru": "Зрение сталкеров x0.7, экран темнее",
		"desc_en": "Stalker vision x0.7, darker screen",
		"vision_mult": 0.7, "postfx_mult": 1.4, "fog_mult": 1.5,
	},
	"harvest": {
		"title_ru": "ЖАТВА", "title_en": "HARVEST",
		"desc_ru": "Добыча за убийство x2, но враг крепче на 15%",
		"desc_en": "Kill reward x2, but enemies 15% tougher",
		"kill_reward_mult": 2.0, "stat_mult": 1.15,
	},
}

# Бесплатный выброс: волны 33, 43, 53, ...
const BLOWOUT_START_WAVE: int = 33
const BLOWOUT_STEP: int = 10             # N % 10 == 3
const BLOWOUT_DELAY: float = 75.0        # сек от старта волны до удара
const BLOWOUT_FINAL_WARNING: float = 5.0 # повторный pulse_warning за N сек

# ==================== ВЕХИ (каждая 10-я волна) ====================
# Заменяет GachaData.milestone_wave_reward (кран: >=30 выдавал каждую волну).
const MILESTONE_STEP: int = 10
const MILESTONES := {
	10: {"mutant": "snork_mutant", "artifact": "battery_artifact", "label": "10 волн"},
	20: {"mutant": "bloodsucker", "artifact": "energy_artifact", "label": "20 волн"},
	30: {"mutant": "pseudogiant", "artifact": "rare_artifact", "biomass": 1000.0, "label": "30 волн"},
	40: {"mutant": "controller_mutant", "artifact": "rare_artifact", "rolls": 5, "biomass": 2000.0, "label": "40 волн"},
	50: {"mutant": "chimera", "artifact": "rare_artifact", "anomaly_rolls": 10, "biomass": 4000.0, "label": "50 волн"},
}
# Цикл 60+: химера-копия на ферму + 10 аномалийных + 4000 биомассы
const MILESTONE_LOOP := {"mutant": "chimera", "anomaly_rolls": 10, "biomass": 4000.0, "label": "легенда"}


## Параметры волны N: тот же формат, что у уровня кампании (ZoneController
## применяет их через те же поля SpawnManager)
static func get_wave_params(wave: int, mode: String = CampaignData.MODE_NORMAL) -> Dictionary:
	var w: int = maxi(1, wave)
	var mode_mult: float = float(CampaignData.MODE_MULTIPLIERS.get(mode, 1.0))

	var count_min: int = mini(MAX_COUNT_PER_WAVE, 8 + int(round(0.7 * (w - 1))))

	# Состав: до 30-й - как раньше; дальше фаза легенды (мастера растут,
	# новички к 40-й исчезают, ветераны забирают остаток)
	var mix: Array
	if w < LEGEND_START:
		var veteran: int = clampi(3 * (w - 2), 0, MAX_VETERAN_PERCENT)
		var master: int = clampi(int(round(1.2 * (w - 8))), 0, MAX_MASTER_PERCENT)
		var novice: int = clampi(100 - veteran - master, 10, 100)
		mix = [novice, veteran, master]
	else:
		var master: int
		if w <= 40:
			master = clampi(30 + int(MASTER_T1_PER_WAVE * (w - 30)), 0, MASTER_CAP)
		elif w <= 50:
			master = clampi(50 + int(MASTER_T2_PER_WAVE * (w - 40)), 0, MASTER_CAP)
		else:
			master = clampi(60 + int(MASTER_T3_PER_WAVE * (w - 50)), 0, MASTER_CAP)
		var veteran: int = mini(VETERAN_CAP_LATE, 100 - master)
		mix = [100 - master - veteran, veteran, master]

	# Статы: до 30-й +4%/волна, дальше склон мягче (модификаторы давят сами)
	var stat_base: float = (1.0 + 0.04 * (w - 1)) if w < LEGEND_START \
			else (1.0 + 0.04 * 29.0) + LEGEND_STAT_SLOPE * (w - 30.0)
	var stat_mult: float = stat_base * mode_mult

	# Скорость: с 41-й медленно растёт до x1.25 к 60-й
	var speed_mult: float
	if w <= 40:
		speed_mult = minf(MAX_SPEED_MULT, 1.0 + 0.01 * (w - 1))
	else:
		speed_mult = minf(SPEED_CAP_LATE, MAX_SPEED_MULT + SPEED_SLOPE_LATE * (w - 40))

	# Передышка: 45->30 как раньше; 25 с с 41-й, 20 с 51-й
	var wave_break: float
	if w < 41:
		wave_break = maxf(MIN_WAVE_BREAK, 45.0 - (w - 1))
	elif w < 51:
		wave_break = BREAK_LORDS
	else:
		wave_break = BREAK_HEART

	return {
		"wave": w,
		"count_min": count_min,
		"count_max": count_min + 2,
		"mix": mix,
		"hp_mult": stat_mult,
		"damage_mult": stat_mult,
		"speed_mult": speed_mult,
		"wave_break": wave_break
	}


## Награда за N пройденных волн поверх боевого дохода; платится при любом исходе
static func wave_bonus(waves_survived: int) -> float:
	var n: int = maxi(0, waves_survived)
	return REWARD_PER_WAVE_BASE * n + REWARD_PER_WAVE_GROWTH * n * (n + 1.0)


# ==================== МОДИФИКАТОРЫ / ВЫБРОСЫ / ФАЗЫ ====================

## Выбросная волна? 33, 43, 53, ... (бесплатный выброс в середине волны)
static func is_blowout_wave(wave: int) -> bool:
	return wave >= BLOWOUT_START_WAVE and wave % BLOWOUT_STEP == 3


## Модификатор волны: {} если не положен (ранняя/событийная/выбросная волна)
static func get_wave_modifier(wave: int) -> Dictionary:
	if wave < MODIFIER_START_WAVE or wave % 5 == 0 or is_blowout_wave(wave):
		return {}
	var pool: Array = MODIFIERS.keys()
	var idx: int = (wave * MODIFIER_HASH_A + MODIFIER_HASH_B) % pool.size()
	# Не повторяем модификатор двух волн подряд: сдвиг по кругу
	var prev_idx: int = ((wave - 1) * MODIFIER_HASH_A + MODIFIER_HASH_B) % pool.size()
	if idx == prev_idx:
		idx = (idx + 1) % pool.size()
	return MODIFIERS[pool[idx]]


## Нота входа в фазу (30/40/50) для анонса; {} если не фазовая волна
static func get_phase_note(wave: int) -> Dictionary:
	if PHASE_NAMES.has(wave):
		return {
			"title_ru": "ФАЗА: %s" % PHASE_NAMES[wave],
			"title_en": "PHASE: %s" % PHASE_NAMES[wave],
			"desc_ru": "Зона меняет законы",
			"desc_en": "The Zone changes its laws",
		}
	return {}


## Анонс волны для передышки: выброс > модификатор > фаза; {} - без особенностей
static func wave_preview(wave: int) -> Dictionary:
	if is_blowout_wave(wave):
		return {
			"title_ru": "СЛЕДУЮЩАЯ: ВЫБРОС ЗОНЫ", "title_en": "NEXT: ZONE BLOWOUT",
			"desc_ru": "Через 75 секунд после старта - бесплатный выброс",
			"desc_en": "Free blowout 75 seconds after the wave starts",
		}
	var modifier := get_wave_modifier(wave)
	if not modifier.is_empty():
		return modifier
	return get_phase_note(wave)


## Веха выживания (10/20/30/40/50, цикл 60+): {} на не круглых волнах
static func get_milestone(wave: int) -> Dictionary:
	if wave <= 0 or wave % MILESTONE_STEP != 0:
		return {}
	if MILESTONES.has(wave):
		return MILESTONES[wave].duplicate()
	if wave >= 60:
		var loop: Dictionary = MILESTONE_LOOP.duplicate()
		loop["label"] = "%d волн" % wave
		return loop
	return {}


## Имя фазы для постэффекта (ступени затемнения на 30/40/50)
static func phase_index(wave: int) -> int:
	var idx := 0
	for threshold in PHASE_NAMES.keys():
		if wave >= int(threshold):
			idx += 1
	return idx


## Короткая подпись для UI
static func get_mode_label() -> String:
	return "ВЫЖИВАНИЕ"
