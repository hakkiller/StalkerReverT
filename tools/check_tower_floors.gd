extends SceneTree
## Прогон ВСЕХ этажей башни 1-100: порог/потолок/достижимость/валидность условий.
## Запуск: Godot --headless --path . --script res://tools/check_tower_floors.gd

func _init():
	var bad: Array = []
	var total_ceiling_low: int = 0
	for f in range(1, 101):
		var tier: Dictionary = TowerData.get_tier(f)
		var waves: int = int(tier["waves"])
		var count: int = int(tier["count"]) + (1 if f % 10 >= 5 else 0)
		var mix: Array = tier["mix"]
		var avg: float = (float(mix[0]) * 16.0 + float(mix[1]) * 30.0 + float(mix[2]) * 60.0) / 100.0
		var ceiling: float = float(waves * (count + 2)) * avg
		var thr: int = TowerData.rich_threshold(f)
		if thr <= 0 or thr > ceiling:
			bad.append("этаж %d: порог %d vs потолок %.0f" % [f, thr, ceiling])
		if thr < ceiling * 0.5:
			total_ceiling_low += 1
		# условия звёзд: валидные id, непустые тексты
		var conds: Array = TowerData.get_star_conditions(f)
		if conds.size() != 2:
			bad.append("этаж %d: conds.size()=%d" % [f, conds.size()])
			continue
		for c in conds:
			if not TowerData.STAR_CONDITIONS.has(c):
				bad.append("этаж %d: неизвестное условие %s" % [f, str(c)])
				continue
			var txt: String = TowerData.condition_text(c, f)
			if txt.is_empty():
				bad.append("этаж %d: пустой текст условия %s" % [f, str(c)])
		# параметры этажа и награды валидны
		var params: Dictionary = TowerData.get_floor_params(f)
		if int(params.get("waves", 0)) <= 0 or int(params.get("count_max", 0)) <= 0:
			bad.append("этаж %d: params invalid" % f)
		var rew: Dictionary = TowerData.get_floor_rewards(f)
		if float(rew.get("biomass", 0.0)) <= 0.0:
			bad.append("этаж %d: rewards invalid" % f)
		# evaluate_stars на эталонных результатах не падает
		var res_ok: Dictionary = {"success": true, "stalkers_total": 10, "stalkers_killed_sm": 10,
			"artifacts_stolen": 0, "mutants_spawned": 4, "pulses_used": 1,
			"biomass_earned": float(thr + 10.0)}
		var stars: int = TowerData.evaluate_stars(f, res_ok)
		if stars < 1:
			bad.append("этаж %d: evaluate_stars вернул %d при идеальном забеге" % [f, stars])
	print("RICH_FRACTION=", TowerData.RICH_FRACTION)
	print("порог эт.1=", TowerData.rich_threshold(1), " эт.11=", TowerData.rich_threshold(11),
		" эт.31=", TowerData.rich_threshold(31), " эт.51=", TowerData.rich_threshold(51),
		" эт.100=", TowerData.rich_threshold(100))
	print("floors=100 bad=", bad.size())
	for b in bad:
		print("  BAD: ", b)
	print("TOWER_CHECK: ", "OK" if bad.is_empty() else "FAIL")
	quit(0)
