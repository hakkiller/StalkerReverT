# data/pripyat_props_data.gd
extends RefCounted
class_name PripyatPropsData

## Плотности и правила раскладки уличных пропсов на карте Припяти.
## Исполнитель: terrain/pripyat_props.gd. Модели: models/props/ (CC0,
## источники - models/props/CREDITS.md).
## Перебор: «пусто на улицах» - множь *_SPACING вниз; «замусорено» -
## вверх; лагает - режь MAX_* (коллизии и инстансы дороже картинок).

const SEED: int = 20260427            # детерминизм раскладки между запусками

# ==================== ВДОЛЬ ДОРОГ ====================
const CAR_SPACING: float = 90.0       # м дороги между машинами (в среднем)
const CAR_SIDE_MARGIN: float = 2.0    # м от кромки проезжей части до борта
const MAX_CARS: int = 110
const TRUCK_CHANCE: float = 0.22      # вместо легковушки - грузовик
const MAX_TRUCKS: int = 18
const BUS_SPACING: float = 650.0      # брошенные автобусы - редко
const MAX_BUSES: int = 7
const LAMP_SPACING: float = 45.0      # фонари вдоль дорог
const LAMP_SIDE_MARGIN: float = 1.2
const MAX_LAMPS: int = 140
const STOP_SPACING: float = 420.0     # остановки: павильон + иногда автобус
const MAX_STOPS: int = 12
const ROAD_ALIGN_JITTER: float = 12.0 # град доворота от направления дороги

# ==================== РАСТИТЕЛЬНОСТЬ (лес/поля ОСМ) ====================
const TREE_PER_M2: float = 1.0 / 800.0     # плотность деревьев в лесу
const MAX_TREES: int = 260
const PINE_SHARE: float = 0.35              # доля сосен среди деревьев
const BUSH_PER_M2: float = 1.0 / 1600.0     # кусты
const MAX_BUSHES: int = 110
const GLOBAL_DEAD_TREES: int = 60           # редкие сухие вне полигонов
const GLOBAL_TREE_MIN_GAP: float = 40.0     # м между случайными деревьями

# ==================== ПРОМЗОНА (landuse industrial/quarry) ====================
const BARREL_CLUSTERS: int = 22      # точек-гроздей бочек (1-3 в грозди)
const MAX_CONCRETE: int = 24
const MAX_CRATES: int = 20
const MAX_TIRE_PILES: int = 14

# ==================== ДВОРЫ ЖИЛОЙ ЗАСТРОЙКИ ====================
# Лавки/качели/трава - кольцом у жилых зданий (apartments/house/school)
const YARD_BENCH_CHANCE: float = 0.55
const MAX_BENCHES: int = 26
const YARD_SWING_CHANCE: float = 0.18   # качели - только у house (частный сектор)
const MAX_SWINGS: int = 10
const GRASS_TUFTS_MAX: int = 90         # пучки травы у зданий
const YARD_RING_MIN: float = 3.0        # м от AABB здания до пропса
const YARD_RING_SPAN: float = 5.0

# ==================== ЗАБОРЫ ====================
# Секции вдоль гаражей/сараев (garage/shed), со сдвигом от стены
const FENCE_MAX_SECTIONS: int = 70
const FENCE_SIDE_OFFSET: float = 2.0    # м от стены
const FENCE_SECTION_LEN: float = 2.4    # м на секцию (шаг расстановки)

# ==================== ОБЩЕЕ ====================
const SCALE_JITTER: float = 0.12       # ± разброс масштаба
const BUILDING_PAD: float = 1.5        # запретная зона вокруг зданий
const ROAD_CLEAR_PAD: float = 1.0      # доп. зазор от кромки дороги
const WATER_PAD: float = 3.0           # отступ от воды

# Аппроксимация габаритов для коллизий (полуразмеры, м; размеры моделей -
# из README поставки pripyat_props). Мелочь без коллизий: grass_tuft,
# bush_dead, lamp_post.
const COLLIDER_BOXES := {
	"car_body": Vector3(0.9, 0.75, 2.25),     # седан 1.8x1.5x4.5
	"car_body_02": Vector3(0.95, 0.9, 2.4),   # внедорожник 1.9x1.8x4.8
	"car_body_03": Vector3(0.9, 0.7, 2.2),    # такси 1.8x1.4x4.4
	"truck": Vector3(1.1, 1.3, 3.4),          # 2.2x2.6x6.8
	"bus": Vector3(1.3, 1.55, 5.75),          # 2.6x3.1x11.5
	"bus_stop": Vector3(2.0, 1.4, 1.3),       # 4.0x2.8x2.6
	"tree_dead": Vector3(0.35, 3.0, 0.35),    # ствол (крона не коллизится)
	"tree_dead_02": Vector3(0.35, 3.0, 0.35),
	"tree_pine": Vector3(0.4, 3.5, 0.4),
	"tree_pine_02": Vector3(0.35, 3.2, 0.35),
	"barrel_radioactive": Vector3(0.45, 0.6, 0.45),  # 0.9x1.2x0.9
	"concrete_block": Vector3(0.7, 0.7, 0.7),         # 1.4x1.4x1.4
	"concrete_block_02": Vector3(0.4, 0.2, 0.2),      # шлакоблок 0.8x0.4x0.4
	"crate": Vector3(0.45, 0.45, 0.45),               # 0.9x0.9x0.9
	"crate_02": Vector3(0.35, 0.35, 0.35),            # 0.7x0.7x0.7
	"tire_pile": Vector3(0.6, 0.35, 0.4),             # 1.2x0.7x0.8
	"bench": Vector3(0.9, 0.45, 0.3),                 # 1.8x0.9x0.6
	"swing": Vector3(1.6, 1.25, 1.75),                # 3.2x2.5x3.5
	"fence_section": Vector3(1.0, 0.6, 0.2),          # 2.0x1.2x0.4
}
