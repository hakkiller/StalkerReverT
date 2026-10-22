# ui/panels/upgrade_panel.gd
extends BasePanel
class_name UpgradePanel

## Панель улучшений станции


@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var upgrades_container: VBoxContainer = $Panel/Margin/VBox/UpgradesContainer
@onready var back_button: Button = $Panel/Margin/VBox/BackButton

var current_station: String = ""
var lab_data: LabData = null
var upgrade_callback: Callable = Callable()


func _ready():
	panel_name = "UpgradePanel"
	back_button.pressed.connect(_on_back_pressed)


func setup(station_type: String, data: LabData, callback: Callable):
	current_station = station_type
	lab_data = data
	upgrade_callback = callback
	
	match station_type:
		"anomaly":
			title_label.text = "СТАНЦИЯ АНОМАЛИЙ"
		"mutant":
			title_label.text = "СТАНЦИЯ МУТАНТОВ"
		"monolith":
			title_label.text = "СТАНЦИЯ МОНОЛИТА"
	
	_refresh_upgrades()
	open()


func _refresh_upgrades():
	# Очищаем контейнер
	for child in upgrades_container.get_children():
		child.queue_free()
	
	var upgrades = _get_upgrades_for_station()
	
	for upgrade in upgrades:
		var item = _create_upgrade_item(upgrade)
		upgrades_container.add_child(item)


func _get_upgrades_for_station() -> Array:
	match current_station:
		"anomaly":
			return [
				{"id": "anomaly_damage", "name": "Урон аномалий", "desc": "Увеличивает урон всех аномалий"},
				{"id": "anomaly_radius", "name": "Радиус аномалий", "desc": "Увеличивает радиус действия"},
				{"id": "anomaly_duration", "name": "Длительность", "desc": "Увеличивает время жизни"}
			]
		"mutant":
			return [
				{"id": "mutant_health", "name": "Здоровье мутантов", "desc": "Увеличивает HP мутантов"},
				{"id": "mutant_damage", "name": "Урон мутантов", "desc": "Увеличивает урон мутантов"},
				{"id": "mutant_speed", "name": "Скорость мутантов", "desc": "Увеличивает скорость"},
				{"id": "mutant_cost", "name": "Скидка", "desc": "Уменьшает стоимость создания"}
			]
		"monolith":
			return [
				{"id": "monolith_energy", "name": "Макс. энергия", "desc": "Увеличивает базовую энергию"},
				{"id": "monolith_regen", "name": "Регенерация", "desc": "Ускоряет восстановление"},
				{"id": "rare_chance", "name": "Редкие артефакты", "desc": "Повышает шанс Rare/Legendary"}
			]
	return []


func _create_upgrade_item(upgrade: Dictionary) -> HBoxContainer:
	var container = HBoxContainer.new()
	container.custom_minimum_size.y = 80
	
	# Информация
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var name_label = Label.new()
	name_label.text = upgrade["name"]
	name_label.add_theme_font_size_override("font_size", 18)
	info_vbox.add_child(name_label)
	
	var desc_label = Label.new()
	desc_label.text = upgrade["desc"]
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_vbox.add_child(desc_label)
	
	var level_label = Label.new()
	level_label.name = "LevelLabel"
	level_label.add_theme_color_override("font_color", Color(0, 1, 0))
	info_vbox.add_child(level_label)
	
	container.add_child(info_vbox)
	
	# Кнопка улучшения
	var upgrade_button = Button.new()
	upgrade_button.name = "UpgradeButton"
	upgrade_button.custom_minimum_size = Vector2(150, 60)
	upgrade_button.pressed.connect(_on_upgrade_clicked.bind(upgrade["id"]))
	container.add_child(upgrade_button)
	
	container.set_meta("upgrade_id", upgrade["id"])
	
	_update_upgrade_item(container, upgrade["id"])
	
	return container


func _update_upgrade_item(container: HBoxContainer, upgrade_id: String):
	if not lab_data:
		return
	
	var level = lab_data.get_upgrade_level(upgrade_id)
	var max_level = lab_data.get_max_level(upgrade_id)
	var cost = lab_data.get_upgrade_cost(upgrade_id)
	
	# LevelLabel лежит внутри info_vbox, поэтому поиск рекурсивный;
	# owned=false, т.к. узлы созданы кодом и не имеют owner
	var level_label = container.find_child("LevelLabel", true, false)
	var upgrade_button = container.find_child("UpgradeButton", true, false)
	if not level_label or not upgrade_button:
		pass # print("UpgradePanel: в элементе апгрейда нет LevelLabel/UpgradeButton")
		return
	
	level_label.text = "Уровень %d/%d" % [level, max_level]
	
	if level >= max_level:
		upgrade_button.text = "MAX"
		upgrade_button.disabled = true
		return
	
	# Расширенные тиры открываются прогрессом кампании
	var unlock_level: int = lab_data.get_next_unlock_campaign_level(upgrade_id)
	var campaign_level: int = CampaignData.TOTAL_LEVELS
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("get_campaign_level"):
		campaign_level = gm.get_campaign_level()
	if campaign_level < unlock_level:
		upgrade_button.text = "ОТКРОЕТСЯ\nна уровне %d" % unlock_level
		upgrade_button.disabled = true
		return
	
	var can_upgrade = lab_data.biomass >= cost
	upgrade_button.text = "УЛУЧШИТЬ\n%d биомассы" % int(cost)
	upgrade_button.disabled = not can_upgrade


func _on_upgrade_clicked(upgrade_id: String):
	if not lab_data:
		return
	
	var cost = lab_data.get_upgrade_cost(upgrade_id)
	
	# can_upgrade проверяет и разблокировку кампанией (внутри purchase_upgrade),
	# но здесь - ранний выход, чтобы не списать биомассу за закрытый тир
	if not lab_data.is_next_level_unlocked(upgrade_id, lab_data.campaign_level_reached):
		return
	
	if lab_data.biomass >= cost and lab_data.can_upgrade(upgrade_id):
		lab_data.biomass -= cost
		lab_data.purchase_upgrade(upgrade_id)
		
		# Автозагрузки не зарегистрированы как Engine-синглтоны:
		# GameManager ищем через группу (см. соглашения проекта)
		var gm = get_tree().get_first_node_in_group("game_manager")
		if gm and gm.has_method("save_to_active_slot"):
			gm.save_to_active_slot()
		
		# Обновляем UI
		for child in upgrades_container.get_children():
			var uid = child.get_meta("upgrade_id", "")
			_update_upgrade_item(child, uid)
		
		var sm = get_tree().get_first_node_in_group("sound_manager")
		if sm and sm.has_method("play_sound"):
			sm.play_sound("upgrade", 0.8)
		
		upgrade_callback.call(upgrade_id)
		show_message("Улучшение приобретено!", 1.0)


func _on_back_pressed():
	close()
