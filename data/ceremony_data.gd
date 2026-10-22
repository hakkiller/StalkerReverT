# data/ceremony_data.gd
extends RefCounted
class_name CeremonyData

## Церемония окончания этажа Башни: тайминги, количества, звуки.
## Все длительности - секунды. Оверлей-исполнитель: ui/hud/ceremony_overlay.gd.
## Что крутить при переборе - комментарии у каждой группы.
## Спека: design_inbox/tower_ceremony/tower_ceremony.md (§8).

# ==================== СЛОЙ И ВВОД ====================
const CANVAS_LAYER: int = 10            # выше HUD (постэффект - слой 1)
const SKIP_FADE_TIME: float = 0.3       # затемнение при скипе
const SKIP_HINT_DELAY: float = 1.5      # когда показать «нажмите, чтобы продолжить»

# ==================== ПУТИ АРТА И 3D (все опциональны) ====================
# Доставит агент-подготовщик (задания 4-5 COMMANDS.md); до доставки оверлей
# играет текстовыми заглушками с теми же таймингами.
const ART_DIR: String = "res://assets/ui/ceremony/"
const ART := {
	"banner_cleared": "banner_floor_cleared.png",
	"banner_floor_up": "banner_floor_up.png",
	"banner_break": "banner_break.png",
	"banner_keeper": "banner_keeper.png",
	"banner_victory": "banner_victory.png",
	"banner_defeat": "banner_defeat.png",
	"star_gold": "star_gold.png",
	"star_silver": "star_silver.png",
	"star_empty": "star_empty.png",
	"glyph_stairs": "glyph_stairs_up.png",
	"spark_star": "spark_star.png",
	"confetti_01": "confetti_01.png",
	"confetti_02": "confetti_02.png",
	"confetti_03": "confetti_03.png",
}
const MODEL_STAIRS: String = "res://models/tower/tower_staircase.glb"
const MODEL_PORTAL: String = "res://models/tower/portal_ring.glb"

# ==================== ТАЙМИНГ БАЗЫ (обычный этаж, 1 звезда) ====================
const FADE_IN_TIME: float = 0.35        # затемнение сцены в начале
const DIM_ALPHA: float = 0.55           # сила затемнения (поражение - DIM_ALPHA_DEFEAT)
const DIM_ALPHA_DEFEAT: float = 0.75
const BANNER_IN_TIME: float = 0.45      # влёт баннера
const BANNER_SLAM_SCALE: float = 1.15   # панч масштаба (1.15 -> 1.0)
const T_STARS_BASE: float = 1.50        # слоты звёзд проявляются
const STAR_SLOT_FADE: float = 0.30
const STAR_POP_INTERVAL: float = 0.38   # пауза между звёздами (сдвигает всё дальше)
const STAR_POP_TIME: float = 0.28
const T_REWARDS_LINE: float = 2.60      # строка наград (сдвигается звёздами: +интервал на каждую свыше 1-й)
const T_TRANSITION: float = 3.30        # старт 3D-перехода
const FADE_OUT_TIME: float = 0.5        # уход в чёрный
const TITLE_HOLD: float = 0.9           # титр «ЭТАЖ N+1»
const TITLE_HOLD_MAX: float = 1.5       # титр при 3 звёздах
const TITLE_LIST_HOLD: float = 1.6      # титр-список ярусов (этаж 100)
const SCENE_CHANGE_DELAY: float = 0.15  # страховка после титра

# Перебор: церемония кажется затянутой - первым делом STAR_POP_INTERVAL 0.38 -> 0.3
# и T_TRANSITION/T_REWARDS_LINE ближе к звёздам; вторым - CAM_RISE_TIME.

# ==================== ВАРИАНТЫ ====================
const BREAK_TIME_SCALE: float = 0.85    # Прорыв: интервалы быстрее
const KEEPER_PREROLL: float = 1.9       # Хранитель: баннер босса до базовой схемы
const KEEPER_SLAM_SHAKE: float = 6.0    # px тряски экрана на слэме босса
const DEFEAT_TOTAL: float = 2.8         # поражение: без звёзд и 3D
const REPLAY_TIME_SCALE: float = 0.85   # реплей пройденного этажа (без улучшения рекорда) - темп бодрее
const CONFETTI_EXTRA_HOLD: float = 0.6  # 3 звезды: праздник чуть длиннее

# ==================== КОНФЕТТИ И ИСКРЫ (2D) ====================
# По узлу GPUParticles2D на текстуру: amount делится списком [confetti_01, 02, 03]
const CONFETTI_WAVE_2STARS: Array[int] = [30, 20, 10]      # 60
const CONFETTI_WAVE_3STARS: Array[int] = [70, 45, 25]      # 140
const CONFETTI_SIDE_BURST: Array[int] = [15, 10, 5]        # 45, только 3★ и рекорд
const CONFETTI_PORTAL_FOUNTAIN: Array[int] = [30, 20, 10]  # 60, Хранитель 3★
const CONFETTI_LIFETIME: float = 3.0
const CONFETTI_GRAVITY: float = 480.0     # px/с^2
const CONFETTI_VELOCITY_MIN: float = 250.0
const CONFETTI_VELOCITY_MAX: float = 420.0
const CONFETTI_EMISSION_WIDTH: float = 0.8  # доля ширины экрана (полоса сверху)
const CONFETTI_MAX_TOTAL: int = 200         # жёсткий потолок всех частиц сразу
const SPARKS_PER_STAR: int = 6              # твинклы spark_star за gold-звездой

# Перебор: праздник «переслащён» - убираем SIDE_BURST (оставляем волну),
# частицы «редкие» - множим первые элементы списков (01 - крупная фракция).

# ==================== ПЕРЕХОД 3D ====================
const STAIRS_OFFSET: float = 6.0        # м от Монолита до лестницы/портала
const CAM_TO_TARGET_TIME: float = 0.6   # подлёт кат-камеры к цели
const CAM_RISE_TIME: float = 2.0        # подъём вдоль лестницы
const CAM_RISE_HEIGHT: float = 4.0      # м (высота tower_staircase.glb)
const PORTAL_SPIN_SPEED: float = 1.2    # рад/с вращения portal_ring.glb
# game_camera на время церемонии отключается (set_process(false)) - см. спеку §3

# ==================== ЗВУК (только существующие ключи SoundManager) ====================
# ВНИМАНИЕ: ключи соответствуют регистрации в sound_manager._register_real_sounds
# (upgrade/exchange/ui_* - footstep_sounds; gravity/electric - anomaly_sounds;
# chimera - mutant_sounds). Имена файлов arта звука тут не подходят.
const STAR_PITCH_STEP: float = 0.15     # лесенка питча звёзд: 1.0 / 1.15 / 1.30
const SFX_MAP := {
	"banner_slam": {"key": "upgrade", "vol": 0.9, "pitch": 0.85},
	"banner_slam_break": {"key": "exchange", "vol": 0.9, "pitch": 1.1},
	"keeper_slam": {"key": "pulse_warning", "vol": 0.6, "pitch": 0.65},
	"keeper_roar": {"key": "chimera", "vol": 0.5, "pitch": 0.7},
	"star_pop": {"key": "upgrade", "vol": 0.75, "pitch": 1.0},        # pitch = 1.0 + STAR_PITCH_STEP * i
	"star_third": {"key": "exchange", "vol": 0.4, "pitch": 1.0},
	"star_silver": {"key": "ui_hover", "vol": 0.35, "pitch": 1.0},
	"confetti_burst": {"key": "exchange", "vol": 0.5, "pitch": 1.1},
	"transition_stairs": {"key": "gravity", "vol": 0.45, "pitch": 0.8},
	"transition_portal": {"key": "gravity", "vol": 0.55, "pitch": 1.05},
	"transition_portal_spark": {"key": "electric", "vol": 0.25, "pitch": 1.0},
	"floor_title": {"key": "ui_click", "vol": 0.5, "pitch": 1.0},
	"defeat": {"key": "pulse_warning", "vol": 0.45, "pitch": 0.6},
	"skip": {"key": "ui_click", "vol": 0.6, "pitch": 1.0},
}
