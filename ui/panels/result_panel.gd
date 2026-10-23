# ui/panels/result_panel.gd
extends BasePanel
class_name ResultPanel

## Панель результатов забега

@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var result_label: Label = $Panel/Margin/VBox/ResultLabel
@onready var reward_label: Label = $Panel/Margin/VBox/RewardLabel
@onready var stats_label: Label = $Panel/Margin/VBox/StatsLabel
@onready var artifacts_label: Label = $Panel/Margin/VBox/ArtifactsLabel
@onready var continue_button: Button = $Panel/Margin/VBox/ContinueButton

var run_result: Dictionary = {}


func _ready():
    panel_name = "ResultPanel"
    continue_button.pressed.connect(_on_continue_pressed)


func show_result(result: Dictionary):
    run_result = result
    
    title_label.text = "ИТОГИ ЗАБЕГА #%d" % result.get("run_number", 1)
    
    var success = result.get("success", false)
    if success:
        result_label.text = "ПОБЕДА"
        result_label.add_theme_color_override("font_color", Color(0, 1, 0))
    else:
        result_label.text = "ПОРАЖЕНИЕ"
        result_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
    
    var reward = result.get("reward", 0)
    reward_label.text = "Получено биомассы: %d" % reward
    
    if result.has("statistics"):
        var stats = result["statistics"]
        stats_label.text = "Сталкеров убито: %d\nАномалий создано: %d\nМутантов создано: %d\nАртефактов украдено: %d" % [
            stats.get("stalkers_killed", 0),
            stats.get("anomalies_created", 0),
            stats.get("mutants_created", 0),
            stats.get("artifacts_stolen", 0)
        ]

    if result.get("mode", "") == "survival":
        stats_label.text += "\nВолн пройдено: %d" % int(result.get("waves_survived", 0))
        # Логика победы v0.21.0: причина исхода выживания
        var vreason := str(result.get("victory_reason", ""))
        var atarget := int(result.get("arena_target_wave", 0))
        if success and vreason == "arena_target":
            stats_label.text += "\nВЫЗОВ ВЫИГРАН: волна %d превзойдена!" % atarget
        elif success and vreason == "waves30":
            stats_label.text += "\nЛЕГЕНДА: 30+ волн пережито - ПОБЕДА!"
        elif atarget > 0:
            stats_label.text += "\nЦель вызова: волна %d (не превзойдена)" % atarget
    
    if result.has("artifacts_collected"):
        var common = 0
        var rare = 0
        var legendary = 0
        
        for a in result["artifacts_collected"]:
            match a.get("type", "common"):
                "common": common += 1
                "rare": rare += 1
                "legendary": legendary += 1
        
        artifacts_label.text = Loc.t("result.artifacts") + "\nCommon: %d   Rare: %d   Legendary: %d" % [common, rare, legendary]
        artifacts_label.visible = true
    else:
        artifacts_label.visible = false

    var gacha: Array = result.get("gacha_rewards", [])
    if not gacha.is_empty():
        artifacts_label.text += "\n" + Loc.t("result.gacha_header") + "\n" + "\n".join(gacha)
        artifacts_label.visible = true
    
    open()


func _on_continue_pressed():
    close()

    # Автозагрузки не зарегистрированы как Engine-синглтоны -
    # GameManager ищем через группу (Engine.get_singleton здесь всегда падал)
    var gm = get_tree().get_first_node_in_group("game_manager")
    if gm and gm.has_method("change_scene"):
        gm.change_scene("lab")
