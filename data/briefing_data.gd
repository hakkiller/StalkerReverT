# data/briefing_data.gd
extends RefCounted
class_name BriefingData

## БРИФИНГИ ПРОВОДНИКА (v0.27.0 «ГОЛОС ЗОНЫ»).
## Перед каждым забегом Проводник - старый ходок, знающий Зону - даёт короткую
## речь о месте, куда идёт отряд: глава кампании, караван-босс, ярус башни,
## Прорыв/Хранитель/Страж. Тексты лежат в Loc (brf.*), здесь - выбор ключа.
## ВАЖНО: файл НЕ ссылается на autoload'ы (Loc и т.п.) - чтобы грузиться и в
## смок-тестах через godot -s. Строки собирает UI (lab_controller).
## Возвращаем словарь: {keys: [loc_key...], hot: bool, place: {...}} -
## hot = особый забег (босс/Страж), place = данные для подзаголовка.

## Кампания: строка главы (+ вступление на 1-м уровне, + речь на караване)
static func for_campaign(level: int) -> Dictionary:
        var lvl: int = clampi(level, 1, CampaignData.TOTAL_LEVELS)
        var keys: Array = []
        @warning_ignore("integer_division")
        var chapter_idx: int = (lvl - 1) / 10
        keys.append("brf.ch.%d" % (chapter_idx + 1))
        if lvl == 1:
                keys.append("brf.hello")
        var chapter: Dictionary = CampaignData.get_chapter(lvl)
        var place := {
                "kind": "cb" if CampaignData.BOSSES.has(lvl) else "lv",
                "level": lvl,
                "title": str(chapter["title"]),
        }
        if CampaignData.BOSSES.has(lvl):
                keys.append("brf.cb.%d" % (lvl / 10))
                return {"keys": keys, "hot": true, "place": place}
        return {"keys": keys, "hot": false, "place": place}


## Башня: строка яруса (+ Прорыв / Хранитель / Страж 25/50/75/100)
static func for_tower(floor_num: int) -> Dictionary:
        var f: int = clampi(floor_num, 1, TowerData.TOTAL_FLOORS)
        var keys: Array = []
        @warning_ignore("integer_division")
        var tier_idx: int = (f - 1) / 10
        keys.append("brf.tw.%d" % (tier_idx + 1))
        var place := {
                "kind": "tower",
                "level": f,
                "title": str(TowerData.get_tier(f).get("name", "")),
        }
        if TowerData.get_warden(f) != null:
                @warning_ignore("integer_division")
                keys.append("brf.wd.%d" % (((f - 1) / 25) + 1))
                return {"keys": keys, "hot": true, "place": place}
        var ftype: String = TowerData.get_floor_type(f)
        if ftype == "keeper":
                keys.append("brf.kpr")
                return {"keys": keys, "hot": true, "place": place}
        if ftype == "break":
                keys.append("brf.brk")
        return {"keys": keys, "hot": false, "place": place}


## Выживание: короткая вводная
static func for_survival() -> Dictionary:
        return {"keys": ["brf.srv"], "hot": false, "place": {"kind": "survival"}}


## Полный брифинг для текущего выбора забега (gm = GameManager).
## Без строк: UI собирает подзаголовок из place через Loc.
static func for_current_selection(gm) -> Dictionary:
        if gm == null:
                return {"keys": ["brf.srv"], "hot": false, "place": {"kind": "survival"}}
        var mode: String = gm.get_selected_run_mode()
        if mode == "tower":
                return for_tower(gm.get_selected_tower_floor())
        if mode == "survival":
                return for_survival()
        return for_campaign(gm.get_selected_or_frontier_level())
