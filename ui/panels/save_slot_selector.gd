# ui/panels/save_slot_selector.gd
extends HBoxContainer
class_name SaveSlotSelector

## Строка выбора активного слота сохранения для экранов настроек.
## Слот 0 - автосейв (подхватывается при старте игры), 1..3 - ручные слоты.
## Переключение меняет только ЦЕЛЬ следующего сохранения: файлы при выборе
## не создаются и не перезаписываются. Загрузка конкретного слота - через
## экран «Загрузить» в главном меню (загруженный слот становится активным).

var game_manager: Node

var _prev_button: Button
var _next_button: Button
var _slot_label: Label
var _info_label: Label

const MIN_SLOT: int = 0
const MAX_SLOT: int = 3


func _ready():
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "Слот:"

	_prev_button = Button.new()
	_prev_button.text = "◀"
	_slot_label = Label.new()
	_next_button = Button.new()
	_next_button.text = "▶"

	_info_label = Label.new()
	_info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	add_child(title)
	add_child(_prev_button)
	add_child(_slot_label)
	add_child(_next_button)
	add_child(_info_label)

	_prev_button.pressed.connect(_on_prev_pressed)
	_next_button.pressed.connect(_on_next_pressed)

	game_manager = get_tree().get_first_node_in_group("game_manager")
	_refresh()


func _on_prev_pressed():
	_change_slot(-1)


func _on_next_pressed():
	_change_slot(1)


func _change_slot(direction: int):
	if not game_manager or not game_manager.has_method("set_active_save_slot"):
		return

	var slot: int = clampi(game_manager.get_active_save_slot() + direction, MIN_SLOT, MAX_SLOT)
	game_manager.set_active_save_slot(slot)
	_refresh()


func _refresh():
	var slot: int = game_manager.get_active_save_slot() if game_manager else 0
	_slot_label.text = "Автосейв" if slot == 0 else "Слот %d" % slot

	var info: Dictionary = game_manager.get_save_info(slot) if game_manager else {}
	if info.get("exists", false):
		_info_label.text = "Забег #%d" % int(info.get("run_number", 1))
	else:
		_info_label.text = "пусто"

	_prev_button.disabled = slot <= MIN_SLOT
	_next_button.disabled = slot >= MAX_SLOT
