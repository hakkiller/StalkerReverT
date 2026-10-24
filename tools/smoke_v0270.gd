extends SceneTree

## Смок v0.27.0 «ГОЛОС ЗОНЫ»: Стражи башни + сеты артефактов + брифинги + локализация

func _initialize() -> void:
	var fails: Array[String] = []

	# --- Стражи: параметры, награды, title/desc/elite ---
	if TowerData.get_warden(24) != null:
		fails.append("floor 24 must have no warden")
	for f in [25, 50, 75, 100]:
		var w = TowerData.get_warden(f)
		if w == null:
			fails.append("no warden on floor %d" % f)
		else:
			if str(w["name"]) == "" or str(w["desc"]) == "":
				fails.append("warden %d: empty name/desc" % f)
			if float(w["elite_pct"]) <= 0.0 or float(w["stat_extra"]) <= 1.0:
				fails.append("warden %d: bad stats" % f)
	var p25: Dictionary = TowerData.get_floor_params(25)
	if not bool(p25["is_boss"]) or str(p25["warden"]) != "Ткач ржавых троп":
		fails.append("floor 25 params broken")
	if float(p25["elite_pct"]) != 0.25:
		fails.append("floor 25 elite_pct broken")
	if str(p25["title"]) != "СТРАЖ: Ткач ржавых троп":
		fails.append("floor 25 title broken: " + str(p25["title"]))
	if str(p25["desc"]) == "":
		fails.append("floor 25 desc empty")
	var p50: Dictionary = TowerData.get_floor_params(50)
	if not bool(p50["is_boss"]):
		fails.append("floor 50 must be boss (break+warden)")
	var p100: Dictionary = TowerData.get_floor_params(100)
	if str(p100["warden"]) != "Голос Монолита":
		fails.append("floor 100 warden broken")
	var p30: Dictionary = TowerData.get_floor_params(30)
	if str(p30["warden"]) != "":
		fails.append("floor 30 must have no warden")
	# награда Стража = x2 поверх Прорыва/Хранителя
	var r25: Dictionary = TowerData.get_floor_rewards(25)
	var r24: Dictionary = TowerData.get_floor_rewards(24)
	# base = 120+10f; r25 = (120+250)*1.5*2.0=1110; r24 = (120+240)*1.0=360
	if float(r25["biomass"]) <= float(r24["biomass"]) * 2.0:
		fails.append("warden 25 reward too small: %s vs %s" % [r25["biomass"], r24["biomass"]])
	if int(r25["anomaly_rolls"]) < 2:
		fails.append("warden 25 anomaly rolls missing")
	var r100: Dictionary = TowerData.get_floor_rewards(100)
	if int(r100["anomaly_rolls"]) < 5:
		fails.append("warden 100 anomaly rolls broken: %d" % int(r100["anomaly_rolls"]))
	# обычные этажи не задеты
	var p12: Dictionary = TowerData.get_floor_params(12)
	if str(p12["warden"]) != "" or str(p12["title"]).begins_with("СТРАЖ"):
		fails.append("floor 12 must be plain")

	# --- Сеты: стадии, множители, маппинг аномалий ---
	var won2: Array = ["fireball_artifact", "gas_bottle_artifact"]
	var won3: Array = won2 + ["storm_artifact"]
	if absf(ArtifactSets.damage_mult_for_anomaly("heat_anomaly", won2) - 1.18) > 0.001:
		fails.append("thermal stage2 dmg broken")
	if absf(ArtifactSets.damage_mult_for_anomaly("heat_anomaly", won3) - 1.35) > 0.001:
		fails.append("thermal stage3 dmg broken")
	if ArtifactSets.radius_mult_for_anomaly("heat_anomaly", won3) != 1.0:
		fails.append("thermal must not give radius")
	var grav2: Array = ["graviton_artifact", "jumper_artifact"]
	if absf(ArtifactSets.damage_mult_for_anomaly("gravity_vortex", grav2) - 1.12) > 0.001:
		fails.append("gravity stage2 broken")
	if ArtifactSets.radius_mult_for_anomaly("gravity_vortex", grav2) != 1.0:
		fails.append("gravity radius must wait stage3")
	var grav3: Array = grav2 + ["hourglass_artifact"]
	if absf(ArtifactSets.radius_mult_for_anomaly("gravity_vortex", grav3) - 1.15) > 0.001:
		fails.append("gravity stage3 radius broken")
	if absf(ArtifactSets.damage_mult_for_anomaly("gravity_whirlwind", grav3) - 1.25) > 0.001:
		fails.append("gravity stage3 dmg broken")
	# посторонние: урон без сета, чужая семья
	if ArtifactSets.damage_mult_for_anomaly("electric_anomaly", won3) != 1.0:
		fails.append("cross-element leak to electric")
	if ArtifactSets.damage_mult_for_anomaly("acid_anomaly", won3) != 1.0:
		fails.append("cross-element leak to acid")
	# арты вне сетов
	var none: Array = ["common_artifact", "rare_artifact"]
	if ArtifactSets.damage_mult_for_anomaly("heat_anomaly", none) != 1.0:
		fails.append("setless artifacts must not boost")
	# эксклюзив наследует элемент базы
	if ArtifactSets.set_of_anomaly("ash_tornado").get("id", "") != "gravity":
		fails.append("exclusive base mapping broken")
	if ArtifactSets.set_of_anomaly("crimson_heat").get("id", "") != "thermal":
		fails.append("exclusive crimson mapping broken")
	# химия: 4 арта, стадия 3 тремя
	var chem3: Array = ["slime_artifact", "flesh_artifact", "void_artifact"]
	if absf(ArtifactSets.damage_mult_for_anomaly("chemical_gas", chem3) - 1.28) > 0.001:
		fails.append("chem stage3 broken")
	# состояние для UI
	var st: Array = ArtifactSets.sets_state(won3)
	if st.size() != 5:
		fails.append("sets_state must have 5 entries")
	var thermal_state: Dictionary = {}
	for s in st:
		if str(s["def"]["id"]) == "thermal":
			thermal_state = s
	if int(thermal_state["have"]) != 3 or int(thermal_state["stage"]) != 3:
		fails.append("thermal state broken")

	# --- Брифинги: ключи, hot, границы ---
	var b1: Dictionary = BriefingData.for_campaign(1)
	if int(b1["keys"].size()) != 2 or bool(b1["hot"]):
		fails.append("campaign 1 briefing broken")
	var b10: Dictionary = BriefingData.for_campaign(10)
	if not bool(b10["hot"]) or int(b10["keys"].size()) != 2:
		fails.append("campaign 10 (caravan) must be hot")
	var b7: Dictionary = BriefingData.for_campaign(7)
	if bool(b7["hot"]) or int(b7["keys"].size()) != 1:
		fails.append("campaign 7 must be plain chapter")
	var b100: Dictionary = BriefingData.for_campaign(100)
	if not bool(b100["hot"]):
		fails.append("campaign 100 must be hot")
	var t5: Dictionary = BriefingData.for_tower(5)
	if int(t5["keys"].size()) != 2:
		fails.append("tower 5 (break) briefing broken")
	var t10: Dictionary = BriefingData.for_tower(10)
	if not bool(t10["hot"]) or int(t10["keys"].size()) != 2:
		fails.append("tower 10 (keeper) must be hot")
	var t25: Dictionary = BriefingData.for_tower(25)
	if not bool(t25["hot"]) or str(t25["keys"][1]) != "brf.wd.1":
		fails.append("tower 25 warden key broken")
	var t100: Dictionary = BriefingData.for_tower(100)
	if str(t100["keys"][1]) != "brf.wd.4":
		fails.append("tower 100 warden key broken: " + str(t100["keys"]))
	var t12: Dictionary = BriefingData.for_tower(12)
	if int(t12["keys"].size()) != 1 or bool(t12["hot"]):
		fails.append("tower 12 must be plain tier line")

	# --- Локализация: все новые ключи на 2 языках ---
	var loc = load("res://core/localization.gd").new()
	var keys: Array = ["brf.title", "brf.go", "brf.cancel", "brf.hint",
		"brf.place.lv", "brf.place.cb", "brf.place.tower", "brf.place.survival",
		"brf.chip.waves", "brf.chip.pulses", "brf.chip.biomass", "brf.chip.endless",
		"brf.chip.record", "brf.chip.boss", "brf.chip.break", "brf.chip.keeper",
		"brf.chip.warden", "brf.chip.elite",
		"sets.title", "sets.hint", "sets.none",
		"sets.bonus.thermal.2", "sets.bonus.thermal.3",
		"sets.bonus.gravity.2", "sets.bonus.gravity.3",
		"sets.bonus.chem.2", "sets.bonus.chem.3",
		"sets.bonus.energy.2", "sets.bonus.energy.3",
		"sets.bonus.mystery.2", "sets.bonus.mystery.3",
		"medals.done_msg"]
	for i in range(1, 11):
		keys.append("brf.ch.%d" % i)
		keys.append("brf.cb.%d" % i)
		keys.append("brf.tw.%d" % i)
	for i in range(1, 5):
		keys.append("brf.wd.%d" % i)
	keys.append("brf.brk")
	keys.append("brf.kpr")
	keys.append("brf.srv")
	keys.append("brf.hello")
	for key in keys:
		var ru: String = loc.t(key)
		if ru == "" or ru == key:
			fails.append("loc missing ru: " + key)
		loc.set_lang("en")
		var en: String = loc.t(key)
		loc.set_lang("ru")
		if en == "" or en == key:
			fails.append("loc missing en: " + key)
	# ремонт v0.26.0: medals.done_msg больше не в DISPLAY_NAMES_EN
	var dn: Dictionary = loc.DISPLAY_NAMES_EN
	if dn.has("medals.done_msg"):
		fails.append("medals.done_msg still in DISPLAY_NAMES_EN")

	# --- речи брифинга в формате (плейсхолдеры чипов) ---
	var wv: String = loc.t("brf.chip.waves", {"n": 4})
	if not wv.contains("4"):
		fails.append("chip placeholder broken")

	if fails.is_empty():
		print("SMOKE v0.27.0: ALL OK (wardens 25/50/75/100, sets 5x stages, briefings 24+ keys, loc %d keys x2)" % keys.size())
		quit(0)
	else:
		for f in fails:
			printerr("FAIL: " + f)
		quit(1)
