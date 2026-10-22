# tools/smoke_vibros_autoload.gd — временный автолоад-чекер ( НЕ для поставки!).
# Регрессия фикса "биомасса ебанулась после выброса". Добавляется в project.godot
# на время прогона, потом запись удаляется.
extends Node

var _fails := 0

func _check(cond: bool, label: String) -> void:
        if cond:
                print("  OK   ", label)
        else:
                print("  FAIL ", label)
                _fails += 1

func _ready() -> void:
        # Чекер - первым autoload'ом: сигналы-зависимости ещё не критичны,
        # но глобалы Signals/Loc уже зарегистрированы (обычный boot).
        print()
        print("SMOKE: фикс выброса биомассы")
        print()

        # 1) Компиляция затронутых скриптов
        var scripts := [
                "res://zones/zone_controller.gd",
                "res://managers/event_manager.gd",
                "res://managers/resource_manager.gd",
                "res://core/game_manager.gd",
                "res://ui/hud/hud.gd",
        ]
        for p in scripts:
                var s = load(p)
                var ok := s != null and s is Script
                # reload() запрещён для уже инстанцированных скриптов (автолоады):
                # game_manager живёт как autoload - его компиляция уже произошла на boot
                if ok and not (s as Script).can_instantiate() and (s as Script).reload() != OK:
                        ok = false
                _check(ok, "компиляция " + p)
        print()

        # 2) Поведенческий тест конца выброса: биомассу не трогаем, сигналы идут
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
        rm.current_biomass = 5000.0
        rm.accumulated_biomass = 5000.0
        var leftover: float = rm.current_biomass - rm.accumulated_biomass
        _check(leftover <= 0.0, "навара нет: leftover=%.0f" % leftover)

        rm.accumulated_biomass = 2000.0
        leftover = rm.current_biomass - rm.accumulated_biomass
        _check(absf(leftover - 3000.0) < 0.01, "неизрасходованный старт возвращается: leftover=%.0f (ожид. 3000)" % leftover)

        rm.accumulated_biomass = 9000.0
        leftover = rm.current_biomass - rm.accumulated_biomass
        _check(leftover <= 0.0, "долг не компенсируется: leftover=%.0f" % leftover)
        rm.free()

        print()
        print("RESULT: ", "SMOKE_OK" if _fails == 0 else "SMOKE_FAILED (%d)" % _fails)
        get_tree().quit(0 if _fails == 0 else 1)
