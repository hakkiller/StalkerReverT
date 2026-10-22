# data/profile_data.gd
extends RefCounted
class_name ProfileData

## Профиль игрока «СКАНЕР ЛИЧНОСТИ» (макет ПРОФИЛЬ_вариант_2).
## Четыре набора:
##   АВАТАРЫ - вся коллекция гачи (мутанты + артефакты, 28 типов),
##             открыт = лежит в lab_data (unlocked_mutants / won_artifacts).
##   РАМКИ   - 12 штук, разблокировка прогрессом (кампания/башня/арена/...).
##   ТИТУЛЫ  - 8 штук, разблокировка прогрессом.
##   СТАТУСЫ - 7 штук: текущий считается автоматом по действиям в Зоне,
##             любой открытый можно закрепить вручную.
## Выбор (аватар/рамка/титул/закреплённый статус) хранится в сейве:
## SaveData.profile_avatar / profile_frame / profile_title / profile_status.
## Условия НЕ хранятся - считаются на лету от контекста сейва (никаких
## миграций старых сейвов: недостающее = закрыто).

# ==================== КОНТЕКСТ ПРОГРЕССА ====================

## Контекст для проверки условий из сейва. null-безопасно (новая игра).
## keys: campaign, tower, wave, arena, runs, upgrades, chimera, collection,
##       anomalies, spent, wins
static func make_ctx(save) -> Dictionary:
        if save == null:
                return {
                        "campaign": 1, "tower": 1, "wave": 0, "arena": 0, "runs": 0,
                        "upgrades": 0, "chimera": false, "collection": 0,
                        "anomalies": 0, "spent": 0.0, "wins": 0,
                }
        var lab = save.lab_data
        var stats = save.statistics
        var collection := 0
        var upgrades := 0
        var chimera := false
        if lab:
                collection = lab.unlocked_mutants.size() + lab.won_artifacts.size()
                chimera = lab.unlocked_mutants.has("chimera")
                for key in ["anomaly_damage_level", "anomaly_radius_level", "anomaly_duration_level",
                                "mutant_health_level", "mutant_damage_level", "mutant_speed_level",
                                "mutant_cost_level", "monolith_energy_level", "monolith_regen_level",
                                "rare_chance_level"]:
                        upgrades += int(lab.get(key))
        return {
                "campaign": int(save.campaign_level),
                "tower": int(save.tower_floor),
                "wave": int(stats.best_survival_wave) if stats else 0,
                "arena": int(lab.arena_wins_challenge + lab.arena_wins_defense) if lab else 0,
                "runs": int(stats.total_runs) if stats else 0,
                "upgrades": upgrades,
                "chimera": chimera,
                "collection": collection,
                "anomalies": int(stats.anomalies_created) if stats else 0,
                "spent": float(stats.biomass_spent) if stats else 0.0,
                "wins": int(stats.wins) if stats else 0,
        }


## Все ключи need выполнены? need: {ключ: порог}; chimera - булев флаг.
static func is_unlocked(need: Dictionary, ctx: Dictionary) -> bool:
        for key in need:
                var need_val = need[key]
                if key == "chimera":
                        if not bool(ctx.get("chimera", false)):
                                return false
                elif int(ctx.get(key, 0)) < int(need_val):
                        return false
        return true


# ==================== АВАТАРЫ (коллекция гачи) ====================

## Порядок ленты: мутанты по редкости (слабые -> сильные), затем артефакты.
## {"id", "is_mutant", "rar"}
static func get_avatar_list() -> Array:
        var out: Array = []
        for rar in ["common", "uncommon", "rare", "legendary"]:
                for e in GachaData.MUTANT_POOL[rar]:
                        out.append({"id": e[0], "is_mutant": true, "rar": rar})
        for rar in ["common", "rare", "legendary"]:
                for id in GachaData.ARTIFACT_POOL[rar]:
                        out.append({"id": id, "is_mutant": false, "rar": rar})
        return out


static func get_avatar_count() -> int:
        return get_avatar_list().size()


## Открыт ли аватар (в коллекции лабы). null-лаба: только дефолтные мутанты.
static func is_avatar_unlocked(av: Dictionary, lab) -> bool:
        if lab == null:
                return GachaData.DEFAULT_UNLOCKED_MUTANTS.has(str(av.id))
        if bool(av.is_mutant):
                return lab.unlocked_mutants.has(str(av.id))
        return lab.won_artifacts.has(str(av.id))


## Иконка аватара: PNG художника в приоритете, SVG-фоллбек; серая для закрытых.
static func get_avatar_icon(av: Dictionary, unlocked: bool) -> String:
        return GachaData.card_icon_path(str(av.id), bool(av.is_mutant), not unlocked)


# ==================== РАМКИ ====================

## dark - тело пояса, light - кромка/свечение/подпись (гекс вокруг аватара).
const FRAMES := [
        {"id": "steel", "rar": "common",
                "dark": Color("3a4a3a"), "light": Color("9aa89a"), "need": {}},
        {"id": "bronze", "rar": "common",
                "dark": Color("6e3f1c"), "light": Color("c9803a"), "need": {"campaign": 5}},
        {"id": "copper", "rar": "uncommon",
                "dark": Color("7a3b28"), "light": Color("d97a4a"), "need": {"runs": 3}},
        {"id": "jade", "rar": "uncommon",
                "dark": Color("14532e"), "light": Color("49ff80"), "need": {"collection": 8},
                "fx": "pulse"},
        {"id": "hazard", "rar": "uncommon",
                "dark": Color("8a6a10"), "light": Color("e8b93c"), "need": {"wave": 10}},
        {"id": "brass", "rar": "rare",
                "dark": Color("8a7020"), "light": Color("d4b048"), "need": {"arena": 3}},
        {"id": "titan", "rar": "rare",
                "dark": Color("44506a"), "light": Color("a8b8d8"), "need": {"campaign": 25}},
        {"id": "obsidian", "rar": "rare",
                "dark": Color("2a2338"), "light": Color("9a86c8"), "need": {"tower": 15}},
        {"id": "amethyst", "rar": "rare",
                "dark": Color("5a2a6a"), "light": Color("c07ae8"), "need": {"collection": 20},
                "fx": "pulse"},
        {"id": "gold", "rar": "legendary",
                "dark": Color("8a5f10"), "light": Color("ffb840"), "need": {"campaign": 50},
                "fx": "shine"},
        {"id": "platinum", "rar": "legendary",
                "dark": Color("5a6a78"), "light": Color("dce8f2"), "need": {"tower": 40},
                "fx": "shine"},
        {"id": "sarcophagus", "rar": "legendary",
                "dark": Color("9a5f10"), "light": Color("ffd23f"), "need": {"campaign": 100},
                "fx": "reactor"},
]


static func get_frame(id: String) -> Dictionary:
        for f in FRAMES:
                if str(f.id) == id:
                        return f
        return FRAMES[0]


static func get_frame_index(id: String) -> int:
        for i in FRAMES.size():
                if str(FRAMES[i].id) == id:
                        return i
        return 0


static func is_frame_unlocked(f: Dictionary, ctx: Dictionary) -> bool:
        return is_unlocked(f.need, ctx)


## Эффект рамки: "none" / "pulse" (пульс кромки) /
## "shine" (бегущий блик) / "reactor" (свечение САРКОФАГА).
static func frame_fx(id: String) -> String:
        return str(get_frame(id).get("fx", "none"))


## Имя/условие/редкость рамки - через Loc (profile.frame_<id> / fhow_<id>).
static func frame_name(id: String) -> String:
        return Loc.t("profile.frame_" + id)


static func frame_how(id: String) -> String:
        return Loc.t("profile.fhow_" + id)


# ==================== ТИТУЛЫ ====================

const TITLES := [
        {"id": "green", "need": {}},
        {"id": "veteran", "need": {"campaign": 10}},
        {"id": "host", "need": {"upgrades": 12}},
        {"id": "hunter", "need": {"chimera": 1}},
        {"id": "keeper", "need": {"tower": 20}},
        {"id": "monolith", "need": {"tower": 100}},
        {"id": "arena", "need": {"arena": 10}},
        {"id": "legend", "need": {"campaign": 100}},
]


static func get_title(id: String) -> Dictionary:
        for t in TITLES:
                if str(t.id) == id:
                        return t
        return TITLES[0]


static func is_title_unlocked(t: Dictionary, ctx: Dictionary) -> bool:
        return is_unlocked(t.need, ctx)


static func title_name(id: String) -> String:
        return Loc.t("profile.title_" + id)


static func title_how(id: String) -> String:
        return Loc.t("profile.thow_" + id)


# ==================== СТАТУСЫ ====================

## Порядок = «свежесть» активности: автомат берёт самый верхний открытый
## (кроме дефолтного «В БУНКЕРЕ», если открыт хоть один другой).
const STATUSES := [
        {"id": "in_bunker", "need": {}},
        {"id": "outing", "need": {"runs": 1}},
        {"id": "emission", "need": {"wins": 1}},
        {"id": "cleaning", "need": {"anomalies": 5}},
        {"id": "trading", "need": {"spent": 100}},
        {"id": "night_monolith", "need": {"tower": 2}},
        {"id": "sleeping", "need": {"runs": 5}},
]


static func get_status(id: String) -> Dictionary:
        for s in STATUSES:
                if str(s.id) == id:
                        return s
        return STATUSES[0]


static func is_status_unlocked(s: Dictionary, ctx: Dictionary) -> bool:
        return is_unlocked(s.need, ctx)


static func status_name(id: String) -> String:
        return Loc.t("profile.st_" + id)


static func status_how(id: String) -> String:
        return Loc.t("profile.show_" + id)


## Автоматический статус: самый «свежий» открытый (идём с конца списка).
static func auto_status(ctx: Dictionary) -> String:
        for i in range(STATUSES.size() - 1, 0, -1):
                if is_status_unlocked(STATUSES[i], ctx):
                        return str(STATUSES[i].id)
        return "in_bunker"


## Итоговый статус: закреплённый (если ещё открыт) либо автомат.
static func effective_status(pinned: String, ctx: Dictionary) -> String:
        if not pinned.is_empty() and is_status_unlocked(get_status(pinned), ctx):
                return pinned
        return auto_status(ctx)


# ==================== СЛУЖЕБНОЕ ====================

## Имя сталкера: кастомное (если задано в редакторе имени), иначе
## автоматом «СТАЛКЕР-XX» по номеру забега.
static func stalker_name(save) -> String:
        if save != null:
                var custom = save.get("profile_name")
                if custom != null and not str(custom).is_empty():
                        return str(custom)
        var run := 1
        if save and save.lab_data:
                run = int(save.lab_data.run_number)
        return "СТАЛКЕР-%02d" % clampi(run, 1, 99)


static func zone_day(save) -> int:
        if save and save.lab_data:
                return clampi(int(save.lab_data.run_number), 1, 999)
        return 1
