# core/progression.gd
extends Node
class_name Progression

## Прогрессия профиля (автолоад Prog):
##   - уровень игрока и опыт (растёт от ЛЮБЫХ боёв, задач и гачи);
##   - ежедневные и еженедельные задачи (ротация по дате/неделе);
##   - трек наград: шкала очков задач -> 20 ступеней с сундуками;
##   - флаги онбординга (сюжетные диалоги кампании/выживания/башни).
## Состояние хранится в сейве: SaveData.prog_profile / prog_quests /
## prog_track / prog_onboard. Старые сейвы без этих полей мигрируют
## автоматически (пустой словарь = первый запуск).

signal xp_changed(level: int, xp: int, need: int)
signal level_up(level: int)
signal tasks_changed
signal task_completed(title: String, xp: int, pts: int)
signal track_changed
signal toast(text: String)

const DAILY_SLOTS := 6
const WEEKLY_SLOTS := 5
const TRACK_TIERS := 30
const TIER_COST := 10
const POOL_VERSION := 2

# ==================== ПУЛЫ ЗАДАЧ ====================
# key - счётчик прогресса; need - цель; xp/pts - награда за закрытие.

const DAILY_POOL := [
        {"id": "d_runs", "title": "Сделай 3 забега в Зону", "need": 3, "key": "runs", "xp": 40, "pts": 10},
        {"id": "d_runs5", "title": "Сделай 5 забегов в Зону", "need": 5, "key": "runs", "xp": 45, "pts": 12},
        {"id": "d_wins", "title": "Победи в 2 забегах", "need": 2, "key": "wins", "xp": 40, "pts": 10},
        {"id": "d_waves", "title": "Пройди 6 волн выживания", "need": 6, "key": "waves", "xp": 40, "pts": 10},
        {"id": "d_waves12", "title": "Пройди 12 волн выживания", "need": 12, "key": "waves", "xp": 45, "pts": 12},
        {"id": "d_kills", "title": "Устрани 15 сталкеров", "need": 15, "key": "kills", "xp": 40, "pts": 10},
        {"id": "d_kills30", "title": "Устрани 30 сталкеров", "need": 30, "key": "kills", "xp": 45, "pts": 12},
        {"id": "d_art", "title": "Добудь 3 артефакта", "need": 3, "key": "artifacts", "xp": 40, "pts": 10},
        {"id": "d_gacha", "title": "Сделай призыв в гаче Зоны", "need": 1, "key": "gacha", "xp": 40, "pts": 10},
        {"id": "d_gacha5", "title": "Сделай 5 призывов в гаче Зоны", "need": 5, "key": "gacha", "xp": 45, "pts": 12},
        {"id": "d_arena", "title": "Победи на арене выживания", "need": 1, "key": "arena_wins", "xp": 40, "pts": 10},
        {"id": "d_arena3", "title": "Одержи 3 победы на арене", "need": 3, "key": "arena_wins", "xp": 45, "pts": 12},
        {"id": "d_tower", "title": "Пройди этаж башни", "need": 1, "key": "tower_wins", "xp": 40, "pts": 10},
        {"id": "d_tower3", "title": "Пройди 3 этажа башни", "need": 3, "key": "tower_wins", "xp": 45, "pts": 12},
        {"id": "d_camp", "title": "Заверши 2 уровня кампании", "need": 2, "key": "campaign_wins", "xp": 40, "pts": 10},
        {"id": "d_xp", "title": "Заработай 300 опыта за день", "need": 300, "key": "xp", "xp": 50, "pts": 15},
]

const WEEKLY_POOL := [
        {"id": "w_runs", "title": "12 забегов за неделю", "need": 12, "key": "runs", "xp": 120, "pts": 30},
        {"id": "w_runs25", "title": "25 забегов за неделю", "need": 25, "key": "runs", "xp": 140, "pts": 35},
        {"id": "w_wins", "title": "8 побед за неделю", "need": 8, "key": "wins", "xp": 120, "pts": 30},
        {"id": "w_waves", "title": "25 волн за неделю", "need": 25, "key": "waves", "xp": 120, "pts": 30},
        {"id": "w_waves60", "title": "60 волн за неделю", "need": 60, "key": "waves", "xp": 140, "pts": 35},
        {"id": "w_kills", "title": "80 сталкеров за неделю", "need": 80, "key": "kills", "xp": 120, "pts": 30},
        {"id": "w_kills200", "title": "200 сталкеров за неделю", "need": 200, "key": "kills", "xp": 140, "pts": 35},
        {"id": "w_art", "title": "12 артефактов за неделю", "need": 12, "key": "artifacts", "xp": 120, "pts": 30},
        {"id": "w_arena", "title": "5 побед на арене за неделю", "need": 5, "key": "arena_wins", "xp": 120, "pts": 30},
        {"id": "w_tower", "title": "4 этажа башни за неделю", "need": 4, "key": "tower_wins", "xp": 120, "pts": 30},
        {"id": "w_tower8", "title": "8 этажей башни за неделю", "need": 8, "key": "tower_wins", "xp": 140, "pts": 35},
        {"id": "w_camp", "title": "6 уровней кампании за неделю", "need": 6, "key": "campaign_wins", "xp": 120, "pts": 30},
        {"id": "w_gacha", "title": "15 призывов в гаче за неделю", "need": 15, "key": "gacha", "xp": 120, "pts": 30},
        {"id": "w_xp", "title": "600 опыта за неделю", "need": 600, "key": "xp", "xp": 150, "pts": 40},
]

# ==================== СЛУЖЕБНОЕ ====================

var _gm_node: Node = null
var _mem: Dictionary = {}          # фолбэк, когда сейва нет (тесты/редактор)
var _story_box: CanvasLayer = null # активный диалог (не плодить дубли)


func _gm() -> Node:
        if not is_instance_valid(_gm_node):
                _gm_node = get_tree().get_first_node_in_group("game_manager")
        return _gm_node


func _save():
        var gm = _gm()
        if gm and gm.has_method("get_current_save_data"):
                return gm.get_current_save_data()
        return null


func _persist() -> void:
        var gm = _gm()
        if gm and gm.has_method("save_to_active_slot"):
                gm.save_to_active_slot()


# ==================== ПРОФИЛЬ: УРОВЕНЬ / ОПЫТ ====================

func xp_need(level: int) -> int:
        return 100 + (level - 1) * 50


func _prof() -> Dictionary:
        var s = _save()
        if s == null:
                if not _mem.has("prof"):
                        _mem["prof"] = {"level": 1, "xp": 0, "xp_total": 0}
                return _mem["prof"]
        if s.prog_profile == null or s.prog_profile.is_empty():
                s.prog_profile = {"level": 1, "xp": 0, "xp_total": 0}
        return s.prog_profile


func level() -> int:
        return int(_prof().get("level", 1))


func xp_in_level() -> int:
        return int(_prof().get("xp", 0))


## Начисление опыта. Счётчик "xp" кормит недельную задачу w_xp.
func add_xp(amount: int, reason: String = "") -> void:
        if amount <= 0:
                return
        var p := _prof()
        p["xp"] = int(p.get("xp", 0)) + amount
        p["xp_total"] = int(p.get("xp_total", 0)) + amount
        _bump("xp", amount)
        var ups := 0
        while int(p["xp"]) >= xp_need(int(p["level"])):
                p["xp"] = int(p["xp"]) - xp_need(int(p["level"]))
                p["level"] = int(p["level"]) + 1
                ups += 1
        xp_changed.emit(int(p["level"]), int(p["xp"]), xp_need(int(p["level"])))
        if ups > 0:
                var gm = _gm()
                if gm and gm.has_method("grant_mutant_rolls"):
                        gm.grant_mutant_rolls(ups, "уровень %d" % int(p["level"]))
                level_up.emit(int(p["level"]))
                toast.emit("НОВЫЙ УРОВЕНЬ: %d · +1 крутка мутантов" % int(p["level"]))


func xp_total() -> int:
        return int(_prof().get("xp_total", 0))


# ==================== ЗАДАЧИ: ПЕРИОДЫ И РОТАЦИЯ ====================

func _day_key() -> String:
        return Time.get_date_string_from_system()


func _week_key() -> String:
        var d := Time.get_date_dict_from_system()
        var doy := _day_of_year(int(d["year"]), int(d["month"]), int(d["day"]))
        return "%d-W%02d" % [int(d["year"]), (doy - 1) / 7 + 1]


func _day_of_year(y: int, m: int, d: int) -> int:
        var cum := [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
        var idx: int = clampi(m - 1, 0, 11)
        return cum[idx] + d


func _quests() -> Dictionary:
        var s = _save()
        if s == null:
                if not _mem.has("q"):
                        _mem["q"] = {"day": "", "week": "", "dpool": [], "wpool": [],
                                "dprog": {}, "wprog": {}, "dclaim": {}, "wclaim": {}}
                var mq: Dictionary = _mem["q"]
                _ensure_quests(mq)
                return mq
        if s.prog_quests == null or s.prog_quests.is_empty():
                s.prog_quests = {"day": "", "week": "", "dpool": [], "wpool": [],
                        "dprog": {}, "wprog": {}, "dclaim": {}, "wclaim": {}}
        _ensure_quests(s.prog_quests)
        return s.prog_quests


func _ensure_quests(q: Dictionary) -> void:
        var dk := _day_key()
        var wk := _week_key()
        if int(q.get("pv", 0)) != POOL_VERSION:
                q["pv"] = POOL_VERSION
                q["day"] = ""
                q["week"] = ""
        if str(q.get("day", "")) != dk:
                q["day"] = dk
                q["dprog"] = {}
                q["dclaim"] = {}
                q["dpool"] = _pick_pool(DAILY_POOL, DAILY_SLOTS, "day:" + dk)
        if str(q.get("week", "")) != wk:
                q["week"] = wk
                q["wprog"] = {}
                q["wclaim"] = {}
                q["wpool"] = _pick_pool(WEEKLY_POOL, WEEKLY_SLOTS, "week:" + wk)


func _pick_pool(pool: Array, slots: int, seed_str: String) -> Array:
        # Детерминированная ротация: одинаковый набор на день/неделю.
        var order: Array = []
        for i in pool.size():
                order.append(i)
        var h: int = hash(seed_str)
        for i in range(order.size() - 1, 0, -1):
                h = int((int(h) * 1103515245 + 12345) & 0x7fffffff)
                var j: int = h % (i + 1)
                var tmp = order[i]
                order[i] = order[j]
                order[j] = tmp
        var out: Array = []
        for i in mini(slots, order.size()):
                out.append(pool[order[i]])
        return out


## Активные задачи: [{"def":..., "prog":int, "done":bool, "claimed":bool}]
func daily_tasks() -> Array:
        return _task_view("d")


func weekly_tasks() -> Array:
        return _task_view("w")


func _task_view(kind: String) -> Array:
        var q := _quests()
        var pool: Array = q["dpool"] if kind == "d" else q["wpool"]
        var prog: Dictionary = q["dprog"] if kind == "d" else q["wprog"]
        var claim: Dictionary = q["dclaim"] if kind == "d" else q["wclaim"]
        var out: Array = []
        for defn in pool:
                var id := str(defn["id"])
                var cur := int(prog.get(id, 0))
                var need := int(defn["need"])
                out.append({
                        "def": defn,
                        "prog": mini(cur, need),
                        "done": cur >= need,
                        "claimed": bool(claim.get(id, false)),
                })
        return out


func _bump(key: String, amount: int) -> void:
        if amount <= 0:
                return
        var q := _quests()
        var touched := false
        for pair in [["dprog", "dpool"], ["wprog", "wpool"]]:
                var prog: Dictionary = q[pair[0]]
                var pool: Array = q[pair[1]]
                for defn in pool:
                        if str(defn["key"]) == key:
                                var id := str(defn["id"])
                                var was := int(prog.get(id, 0))
                                if was < int(defn["need"]):
                                        prog[id] = was + amount
                                        touched = true
                                        if int(prog[id]) >= int(defn["need"]):
                                                task_completed.emit(str(defn["title"]), int(defn["xp"]), int(defn["pts"]))
        if touched:
                tasks_changed.emit()


## Забрать награду за задачу. Возвращает true если закрыто.
func claim_task(kind: String, id: String) -> bool:
        var q := _quests()
        var pool: Array = q["dpool"] if kind == "d" else q["wpool"]
        var prog: Dictionary = q["dprog"] if kind == "d" else q["wprog"]
        var claim: Dictionary = q["dclaim"] if kind == "d" else q["wclaim"]
        for defn in pool:
                if str(defn["id"]) == id:
                        if bool(claim.get(id, false)):
                                return false
                        if int(prog.get(id, 0)) < int(defn["need"]):
                                return false
                        claim[id] = true
                        add_xp(int(defn["xp"]), "task")
                        add_points(int(defn["pts"]))
                        _persist()
                        tasks_changed.emit()
                        return true
        return false


# ==================== ТРЕК: ШКАЛА С СУНДУКАМИ ====================

func _track() -> Dictionary:
        var s = _save()
        if s == null:
                if not _mem.has("tr"):
                        _mem["tr"] = {"points": 0, "cycle": 1, "claimed": {}}
                return _mem["tr"]
        if s.prog_track == null or s.prog_track.is_empty():
                s.prog_track = {"points": 0, "cycle": 1, "claimed": {}}
        return s.prog_track


func track_points() -> int:
        return int(_track().get("points", 0))


func track_cycle() -> int:
        return maxi(1, int(_track().get("cycle", 1)))


func tier_claimed(tier: int) -> bool:
        return bool(_track()["claimed"].get(str(tier), false))


func add_points(amount: int) -> void:
        if amount <= 0:
                return
        var t := _track()
        t["points"] = int(t.get("points", 0)) + amount
        track_changed.emit()


## Тип сундука ступени: wood / military / science / gold / black.
## Золотые - каждая 5-я, чёрные ящики - милстоуны 10/20/30.
func chest_kind(tier: int) -> String:
        if tier % 10 == 0:
                return "black"
        if tier % 5 == 0:
                return "gold"
        var order := ["wood", "military", "science", "wood"]
        return order[(tier - 1) % order.size()]


func chest_name(kind: String) -> String:
        match kind:
                "black": return "ЧЁРНЫЙ ЯЩИК"
                "gold": return "ЗОЛОТОЙ СУНДУК"
                "military": return "ВОЕННЫЙ СУНДУК"
                "science": return "НАУЧНЫЙ СУНДУК"
                _: return "ДЕРЕВЯННЫЙ СУНДУК"


func chest_color(kind: String) -> Color:
        match kind:
                "black": return Color("b48cff")
                "gold": return Color("ffd23f")
                "military": return Color("9aa89a")
                "science": return Color("6fc4ff")
                _: return Color("c9803a")


## Содержимое сундука ступени: цикл трека (x1.25 за цикл) + сезонный рост
## (к концу трека сундуки жирнее до +50%). Чёрные ящики - джекпот милстоунов.
func chest_contents(tier: int) -> Dictionary:
        var kind := chest_kind(tier)
        var mult: float = 1.0 + 0.25 * float(track_cycle() - 1)
        var season: float = 1.0 + 0.5 * float(tier - 1) / float(maxi(1, TRACK_TIERS - 1))
        var bio := 0
        var mut := 0
        var ano := 0
        match kind:
                "black":
                        bio = 600
                        mut = 3
                        ano = 3
                "gold":
                        bio = 400
                        mut = 2
                        ano = 2
                "military":
                        bio = 100
                        mut = 2
                "science":
                        bio = 140
                        ano = 2
                _:
                        bio = 200
                        ano = 1
        return {
                "kind": kind,
                "biomass": int(round(float(bio) * mult * season)),
                "mutant_rolls": int(ceil(float(mut) * mult * season)),
                "anomaly_rolls": int(ceil(float(ano) * mult * season)),
                "exclusive": 1 if kind == "black" else 0,
        }


## Забрать сундук ступени. Возвращает содержимое либо {} если нельзя.
func claim_tier(tier: int) -> Dictionary:
        if tier < 1 or tier > TRACK_TIERS:
                return {}
        if tier_claimed(tier):
                return {}
        var t := _track()
        var need_points := tier * TIER_COST
        if int(t.get("points", 0)) < need_points:
                return {}
        var rewards := chest_contents(tier)
        t["claimed"][str(tier)] = true
        var gm = _gm()
        if gm:
                if int(rewards["biomass"]) > 0 and gm.get_lab_data():
                        gm.get_lab_data().biomass += float(int(rewards["biomass"]))
                if int(rewards["mutant_rolls"]) > 0:
                        gm.grant_mutant_rolls(int(rewards["mutant_rolls"]), "сундук трека")
                if int(rewards["anomaly_rolls"]) > 0:
                        gm.grant_anomaly_rolls(int(rewards["anomaly_rolls"]), "сундук трека")
                if int(rewards.get("exclusive", 0)) > 0:
                        # Чёрный ящик несёт эксклюзивного мутанта (ротация по циклам)
                        var ex := GachaData.exclusive_for_milestone(track_cycle(), int(tier / 10.0))
                        var ex_res: Dictionary = gm.grant_exclusive_mutant(str(ex["type"]))
                        if not ex_res.is_empty():
                                rewards["exclusive_type"] = str(ex["type"])
                                rewards["exclusive_name"] = str(ex["name"])
                                rewards["exclusive_new"] = str(ex_res.get("status", "new")) == "new"
                        # Чёрный ящик несёт и эксклюзивную аномалию (ротация сдвинута)
                        var ax := GachaData.exclusive_anomaly_for_milestone(track_cycle(), int(tier / 10.0))
                        var ax_res: Dictionary = gm.grant_exclusive_anomaly(str(ax["type"]))
                        if not ax_res.is_empty():
                                rewards["ex_anomaly_type"] = str(ax["type"])
                                rewards["ex_anomaly_name"] = str(ax["name"])
                                rewards["ex_anomaly_new"] = str(ax_res.get("status", "new")) == "new"
        # Все ступени закрыты: новый цикл, очки обнуляются, награды жирнее.
        var all_done := true
        for i in range(1, TRACK_TIERS + 1):
                if not bool(t["claimed"].get(str(i), false)):
                        all_done = false
                        break
        if all_done:
                t["cycle"] = track_cycle() + 1
                t["points"] = 0
                t["claimed"] = {}
                toast.emit("ТРЕК ЗАКРЫТ! Цикл %d: сундуки жирнее на 25%%" % track_cycle())
        _persist()
        track_changed.emit()
        xp_changed.emit(level(), xp_in_level(), xp_need(level()))
        return rewards


# ============ СОБЫТИЯ БОЁВ (вызывается из GameManager.process_run_result) ====

func on_run_result(result: Dictionary) -> void:
        var mode := str(result.get("mode", "campaign"))
        var success := bool(result.get("success", false))
        var stats: Dictionary = result.get("statistics", {})
        var kills := int(stats.get("stalkers_killed", 0))
        var arts := 0
        if result.has("artifacts_collected"):
                arts = (result["artifacts_collected"] as Array).size()

        _bump("runs", 1)
        if success:
                _bump("wins", 1)
        if kills > 0:
                _bump("kills", kills)
        if arts > 0:
                _bump("artifacts", arts)

        var xp := 0
        var pts := 1
        var gm = _gm()
        var is_replay := bool(result.get("campaign_replay", false))

        match mode:
                "survival":
                        var waves := int(result.get("waves_survived", 0))
                        if waves > 0:
                                _bump("waves", waves)
                                xp += 8 * waves
                                pts += waves
                        # Арена: тип забега ставится лабораторией перед стартом
                        var kind_val = gm.get("arena_run_kind") if gm != null else null
                        if kind_val != null and not str(kind_val).is_empty():
                                if success:
                                        _bump("arena_wins", 1)
                                        xp += 50
                                        pts += 3
                                gm.set("arena_run_kind", "")
                "tower":
                        if success:
                                _bump("tower_wins", 1)
                                xp += 70 + 3 * int(result.get("tower_floor", 1))
                                pts += 2
                        else:
                                xp += 25
                _:
                        if success:
                                _bump("campaign_wins", 1)
                                xp += 60 + 2 * int(result.get("campaign_level", 1))
                                if is_replay:
                                        xp = 25
                                pts += 2
                        else:
                                xp += 20

        if kills > 0:
                xp += kills / 5
        add_xp(xp, "run")
        add_points(pts)


## Призыв гачи (из GachaController._on_spin при успехе).
func notify_gacha(times: int) -> void:
        var n := clampi(times, 1, 10)
        _bump("gacha", n)
        add_xp(2 * n, "gacha")


# ==================== ОНБОРДИНГ / СЮЖЕТ ====================

func _onboard() -> Dictionary:
        var s = _save()
        if s == null:
                if not _mem.has("ob"):
                        _mem["ob"] = {}
                return _mem["ob"]
        if s.prog_onboard == null:
                s.prog_onboard = {}
        return s.prog_onboard


func story_seen(key: String) -> bool:
        return bool(_onboard().get(key, false))


func mark_story(key: String) -> void:
        _onboard()[key] = true
        _persist()


## Какой сюжет ждёт в контексте: "lab" / "arena" / "gates". {} - нечего показать.
func story_pending(context: String) -> Dictionary:
        if _story_box != null and is_instance_valid(_story_box):
                return {}
        if context == "arena":
                if not story_seen("surv_intro"):
                        return {"key": "surv_intro", "lines": Story.surv_intro()}
                return {}
        if context == "gates":
                if not story_seen("tower_intro"):
                        return {"key": "tower_intro", "lines": Story.tower_intro()}
                return {}
        # Лаборатория: вводная кампании и диалоги глав (между этапами).
        var frontier := 1
        var gm = _gm()
        if gm and gm.has_method("get_campaign_level"):
                frontier = int(gm.get_campaign_level())
        if not story_seen("camp_intro"):
                return {"key": "camp_intro", "lines": Story.camp_intro()}
        for i in CampaignData.CHAPTERS.size():
                if i == 0:
                        continue  # первая глава закрыта вводной camp_intro
                var ch: Dictionary = CampaignData.CHAPTERS[i]
                var key := "ch_%d" % (i + 1)
                if frontier >= int(ch["start"]) and not story_seen(key):
                        return {"key": key, "lines": Story.chapter_intro(i, str(ch["title"]))}
        return {}


## Показать сюжет, если есть что показать. host - любой узел сцены.
func request_story(context: String, host: Node) -> void:
        var story := story_pending(context)
        if story.is_empty():
                return
        var box := DialogueBox.new()
        _story_box = box
        var key := str(story["key"])
        box.finished.connect(func() -> void: mark_story(key))
        box.closed.connect(func() -> void: _story_box = null)
        host.get_tree().root.add_child(box)
        box.show_dialogue(story["lines"])
