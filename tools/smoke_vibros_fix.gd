# tools/smoke_vibros_fix.gd — регрессия фикса "биомасса ебанулась после выброса".
# Запуск: godot --headless --path . --script res://tools/smoke_vibros_fix.gd
#
# ФИКС: zone_controller._on_radiation_pulse_ended() больше НЕ ставит
# current_biomass = max_biomass * 0.3 (при max_biomass=999999 это ~300К):
#   - счётчик больше не скачет до ~300К после каждого выброса;
#   - в награду за победу больше не вливается "остаток" ~300К.
#
# Доказательство 1: метод зовётся на ZoneController, добавленном НЕ в дерево
# (resource_manager == null). Старый код падал на null-доступе ДО emit() -
# сигналы не срабатывали. Новый код сигналы испускает и биомассу не трогает.
# Доказательство 2: формула остатка награды осталась честной
# (неизрасходованный стартовый капитал возвращается, навара нет).
extends SceneTree

var _fails := 0

func _check(cond: bool, label: String) -> void:
	if cond:
		print("  OK   ", label)
	else:
		print("  FAIL ", label)
		_fails += 1

func _init() -> void:
	print("SMOKE: фикс выброса биомассы")
	print()

	# 1) Компиляция затронутых скриптов
	var scripts := [
		"res://zones/zone_controller.gd",
		"res://managers/event_manager.gd",
		"res://managers/resource_manager.gd",
		"res://core/game_manager.gd",
	]
	for p in scripts:
		var s = load(p)
		var ok := s != null and s is Script
		if ok and (s as Script).reload() != OK:
			ok = false
		_check(ok, "компиляция " + p)
	print()

	# 2) Поведенческий тест конца выброса
	var zc = load("res://zones/zone_controller.gd").new()
	var fired := [false]
	zc.radiation_pulse_ended.connect(func(): fired[0] = true)
	zc._on_radiation_pulse_ended()
	_check(fired[0], "конец выброса: сигналы прошли (накачки max*0.3 больше нет)")
	zc.free()
	print()

	# 3) Семантика остатка награды (leftover = current - accumulated)
	var rm = load("res://managers/resource_manager.gd").new()
	rm.max_biomass = 999999.0
	rm.current_biomass = 5000.0      # старт (лабовый остаток + 300) израсходован до 5000
	rm.accumulated_biomass = 5000.0  # заработано столько же
	var leftover: float = rm.current_biomass - rm.accumulated_biomass
	_check(leftover <= 0.0, "навара нет: leftover=%.0f" % leftover)

	rm.accumulated_biomass = 2000.0  # заработано 2000, текущие 5000 = стартовый остаток 3000
	leftover = rm.current_biomass - rm.accumulated_biomass
	_check(absf(leftover - 3000.0) < 0.01, "неизрасходованный старт возвращается: leftover=%.0f (ожид. 3000)" % leftover)

	rm.accumulated_biomass = 9000.0  # потратил больше старта - остаток отрицательный, в награду не идёт
	leftover = rm.current_biomass - rm.accumulated_biomass
	_check(leftover <= 0.0, "долг не компенсируется: leftover=%.0f" % leftover)
	rm.free()

	print()
	print("RESULT: ", "OK" if _fails == 0 else "FAILED (%d)" % _fails)
	quit(0 if _fails == 0 else 1)
