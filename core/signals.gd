# core/signals.gd
extends Node
class_name GameSignals

# Автозагрузка: Signals

# Игровые события
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal game_started
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal game_paused(paused: bool)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal game_over(victory: bool, run_number: int, reward: float)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal game_won(run_number: int, reward: float)

# События зоны
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal zone_entered(zone_name: String)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal zone_exited(zone_name: String)

# События сталкеров
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal stalker_spawned(stalker: Node, type: GameEnums.StalkerType, position: Vector3)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal stalker_died(stalker: Node, type: GameEnums.StalkerType, position: Vector3, biomass_returned: float)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal stalker_stole_artifact(stalker: Node, artifact: Node, value: int)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal stalker_picked_up_artifact(stalker: Node, artifact: Node)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal stalker_dropped_artifact(stalker: Node, artifact: Node)

# События мутантов
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal mutant_spawned(mutant: Node, type: GameEnums.MutantType, position: Vector3, cost: float)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal mutant_died(mutant: Node, type: GameEnums.MutantType, position: Vector3, biomass_returned: float)

# События аномалий
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal anomaly_created(anomaly: Node, type: GameEnums.AnomalyType, position: Vector3, difficulty: int)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal anomaly_destroyed(anomaly: Node, type: GameEnums.AnomalyType, position: Vector3, difficulty: int)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal anomaly_damaged(anomaly: Node, damage: float, health: float)

# События артефактов
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal artifact_created(artifact: Node, rarity: GameEnums.Rarity, position: Vector3, value: int)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal artifact_collected(artifact: Node, collector: Node, value: int)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal artifact_expired(artifact: Node, position: Vector3)

# События выброса
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal radiation_pulse_started(level: int, duration: float)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal radiation_pulse_ended
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal radiation_pulse_warning(seconds_left: float)

# События волн
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal wave_started(wave_number: int, stalker_count: int, difficulty: float)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal wave_ended(wave_number: int, survivors: int, killed: int)

# События ресурсов
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal energy_changed(current: float, max_value: float, percent: float)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal biomass_changed(current: float, max_value: float, percent: float)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal critical_biomass_reached(percent: float)

# События сложности
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal difficulty_changed(old_difficulty: float, new_difficulty: float)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal run_started(run_number: int, difficulty: float, pulses_to_win: int)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal run_ended(run_number: int, success: bool, reward: float)

# UI события
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal ui_button_hovered(button_name: String)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal ui_button_clicked(button_name: String)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal ui_panel_opened(panel_name: String)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal ui_panel_closed(panel_name: String)

# Аудио события
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal music_changed(track_name: String, fade_time: float)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal sound_played(sound_name: String, volume: float, pitch: float)

# Визуальные события
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal particle_spawned(particle_type: String, position: Vector3)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal fog_density_changed(density: float)

# Сохранения
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal game_saved(slot: int, save_time: String)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal game_loaded(slot: int, save_data: Resource)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal save_deleted(slot: int)

# Ошибки
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal error_occurred(error_code: int, error_message: String, source: String)

# Управление (мобильная камера)
@warning_ignore("unused_signal")  # глобальная шина: подключается извне
signal ground_tapped(world_position: Vector3)
