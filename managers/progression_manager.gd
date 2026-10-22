# managers/progression_manager.gd
extends Node
class_name ProgressionManager

## Менеджер прогрессии - управляет сложностью и статистикой

signal run_started(run_number: int, difficulty: float)
signal run_ended(run_number: int, reward: float, success: bool)
signal difficulty_changed(new_difficulty: float)

# Параметры сложности
@export var base_difficulty: float = 1.0
@export var difficulty_increase_per_run: float = 0.2
@export var pulses_to_win_base: int = 3
@export var difficulty_increase_per_pulse: float = 0.15

# Параметры масштабирования
@export var health_scale_per_run: float = 0.15
@export var speed_scale_per_run: float = 0.05
@export var damage_scale_per_run: float = 0.15

# Текущее состояние
var current_run: int = 1
var current_difficulty: float = 1.0
var pulses_to_win: int = 5

# Статистика
var total_runs: int = 0
var total_wins: int = 0
var stalkers_killed: int = 0
var anomalies_created: int = 0
var mutants_spawned: int = 0
var artifacts_stolen: int = 0
var total_biomass_earned: float = 0.0

# Внутреннее
var _current_biomass: float = 0.0


func _ready():
    add_to_group("progression_manager")
    pass # print("ProgressionManager инициализирован", "ProgressionManager")


# ==================== ЗАБЕГИ ====================

func start_new_run() -> Dictionary:
    current_run = total_runs + 1
    current_difficulty = base_difficulty + (current_run - 1) * difficulty_increase_per_run
    # Фиксированная цель, совпадает с pulses_to_win в EventManager
    pulses_to_win = pulses_to_win_base
    _current_biomass = 0.0
    
    pass # print("Забег #" + str(current_run) + " | Сложность: " + str(current_difficulty) + " | Цель: " + str(pulses_to_win) + " выбросов", "ProgressionManager")
    
    run_started.emit(current_run, current_difficulty)
    
    return {
        "run_number": current_run,
        "difficulty": current_difficulty,
        "pulses_to_win": pulses_to_win
    }


func end_run(success: bool, accumulated_biomass: float) -> float:
    total_runs += 1
    _current_biomass = accumulated_biomass
    
    var reward = 0.0
    if success:
        total_wins += 1
        reward = _calculate_reward(accumulated_biomass)
        total_biomass_earned += reward
    
    pass # print("Забег #" + str(current_run) + " завершён. Успех: " + str(success) + " | Награда: " + str(reward), "ProgressionManager")
    run_ended.emit(current_run, reward, success)
    
    return reward


func _calculate_reward(accumulated: float) -> float:
    var base_reward = 100.0 * current_run
    var difficulty_mult = current_difficulty
    var accumulated_part = accumulated * 0.3
    return accumulated_part + (base_reward * difficulty_mult)


func increase_difficulty(amount: float = difficulty_increase_per_pulse):
    current_difficulty += amount
    difficulty_changed.emit(current_difficulty)
    pass # print("Сложность увеличена до: " + str(current_difficulty), "ProgressionManager")


# ==================== МНОЖИТЕЛИ ====================

func get_health_multiplier() -> float:
    return 1.0 + (current_run - 1) * health_scale_per_run


func get_speed_multiplier() -> float:
    return 1.0 + (current_run - 1) * speed_scale_per_run


func get_damage_multiplier() -> float:
    return 1.0 + (current_run - 1) * damage_scale_per_run


# ==================== СТАТИСТИКА ====================

func record_stalker_killed():
    stalkers_killed += 1


func record_anomaly_created():
    anomalies_created += 1


func record_mutant_spawned():
    mutants_spawned += 1


func record_artifact_stolen():
    artifacts_stolen += 1


func get_stalkers_killed() -> int:
    return stalkers_killed


func get_anomalies_created() -> int:
    return anomalies_created


func get_mutants_spawned() -> int:
    return mutants_spawned


func get_artifacts_stolen() -> int:
    return artifacts_stolen


func get_statistics() -> Dictionary:
    return {
        "total_runs": total_runs,
        "total_wins": total_wins,
        "win_rate": float(total_wins) / max(1, total_runs) * 100.0,
        "stalkers_killed": stalkers_killed,
        "anomalies_created": anomalies_created,
        "mutants_spawned": mutants_spawned,
        "artifacts_stolen": artifacts_stolen,
        "total_biomass_earned": total_biomass_earned,
        "current_run": current_run,
        "current_difficulty": current_difficulty
    }


func reset_statistics():
    total_runs = 0
    total_wins = 0
    stalkers_killed = 0
    anomalies_created = 0
    mutants_spawned = 0
    artifacts_stolen = 0
    total_biomass_earned = 0.0
    _current_biomass = 0.0
    pass # print("Статистика сброшена", "ProgressionManager")


# ==================== ГЕТТЕРЫ ====================

func get_current_run() -> int:
    return current_run


func get_current_difficulty() -> float:
    return current_difficulty


func get_pulses_to_win() -> int:
    return pulses_to_win


func is_first_run() -> bool:
    return current_run == 1
