# core/enums.gd
extends Node
class_name GameEnums

# Типы аномалий
enum AnomalyType {
	HEAT,
	ELECTRIC,
	ACID,
	GRAVITY_VORTEX,
	GRAVITY_LIFT,
	GRAVITY_WHIRLWIND,
	THERMAL_STEAM,
	THERMAL_COMET,
	CHEMICAL_JELLY,
	CHEMICAL_GAS,
	CHEMICAL_ACID_CLOUD,
	RADIATION_HOTSPOT,
	TIME_DILATION,
	TELEPORT,
	ELECTRIC_TESLA,
	BIO_BURNING_FLUFF
}

# Типы сталкеров
enum StalkerType {
	NOVICE,
	VETERAN,
	MASTER
}

# Поведения сталкеров
enum StalkerBehavior {
	GREEDY,      # Приоритет артефактов
	BRAVE,       # Идет к монолиту, игнорируя опасности
	CAUTIOUS,    # Проверяет безопасность пути
	AGGRESSIVE,  # Атакует мутантов
	STEALTHY     # Избегает любых контактов
}

# Типы мутантов
enum MutantType {
	DOG,
	FLESH,
	SNORK,
	PSEUDODOG,
	CONTROLLER,
	POLTERGEIST,
	BLOODSUCKER,
	CHIMERA,
	PSEUDOGIANT,
	ZOMBIE
}

# Редкость артефактов
enum Rarity {
	COMMON,
	RARE,
	LEGENDARY
}

# Состояния сталкера
enum StalkerState {
	IDLE,
	PATROL,
	SEEK_ARTIFACT,
	SEEK_MONOLITH,
	FLEE,
	ATTACK_ANOMALY,
	ATTACK_MUTANT,
	CARRY_ARTIFACT
}

# Типы местности
enum TerrainType {
	PLAIN,
	FOREST,
	SWAMP,
	HILL,
	WATER,
	ROAD,
	VILLAGE,
	RUINS
}

# Типы уведомлений
enum AlertType {
	RADIATION_PULSE,
	STALKER_APPROACHING,
	MUTANT_DETECTED,
	ARTIFACT_DISCOVERED,
	MONOLITH_DANGER
}

# Типы ресурсов
enum ResourceType {
	ENERGY,
	BIOMASS
}

# Типы улучшений
enum UpgradeType {
	ANOMALY_DAMAGE,
	ANOMALY_RADIUS,
	ANOMALY_DURATION,
	MUTANT_HEALTH,
	MUTANT_DAMAGE,
	MUTANT_SPEED,
	MUTANT_COST,
	MONOLITH_ENERGY,
	MONOLITH_REGEN,
	RARE_CHANCE
}
