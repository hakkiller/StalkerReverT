# data/game_statistics.gd
extends Resource
class_name GameStatistics

## Статистика игры

@export var total_runs: int = 0
@export var wins: int = 0
@export var losses: int = 0
@export var stalkers_killed: int = 0
@export var anomalies_created: int = 0
@export var mutants_created: int = 0
@export var artifacts_stolen: int = 0
@export var biomass_earned: float = 0.0
@export var biomass_spent: float = 0.0

# Режим выживания: лучший результат (пройдено волн за забег)
@export var best_survival_wave: int = 0


func get_win_rate() -> float:
    if total_runs == 0:
        return 0.0
    return float(wins) / float(total_runs) * 100.0


func get_total_biomass() -> float:
    return biomass_earned - biomass_spent


func reset():
    total_runs = 0
    wins = 0
    losses = 0
    stalkers_killed = 0
    anomalies_created = 0
    mutants_created = 0
    artifacts_stolen = 0
    biomass_earned = 0.0
    biomass_spent = 0.0
    best_survival_wave = 0
