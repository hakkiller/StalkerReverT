# ui/base/base_panel.gd
extends Control
class_name BasePanel

## Базовый класс для всех панелей UI

signal opened
signal closed
signal back_pressed

@export var panel_name: String = "BasePanel"
@export var close_on_escape: bool = true
@export var close_on_click_outside: bool = false
@export var animation_duration: float = 0.2

var is_open: bool = false


func _ready():
    visible = false
    _setup_connections()


func _setup_connections():
    if close_on_escape:
        var back_button = find_child("BackButton", true, false)
        if back_button and back_button is Button:
            back_button.pressed.connect(_on_back_pressed)


func _input(event):
    if close_on_escape and event.is_action_pressed("ui_cancel") and is_open:
        close()


func _on_back_pressed():
    back_pressed.emit()
    close()


# ==================== ПУБЛИЧНОЕ API ====================

func open():
    if is_open:
        return
    
    is_open = true
    visible = true
    
    if animation_duration > 0:
        _play_open_animation()
    
    opened.emit()
    pass # print("Панель открыта: " + panel_name, "BasePanel")


func close():
    if not is_open:
        return
    
    is_open = false
    
    if animation_duration > 0:
        await _play_close_animation()
    
    visible = false
    closed.emit()
    pass # print("Панель закрыта: " + panel_name, "BasePanel")


func toggle():
    if is_open:
        close()
    else:
        open()


func _play_open_animation():
    modulate.a = 0
    scale = Vector2(0.9, 0.9)
    
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 1.0, animation_duration)
    tween.parallel().tween_property(self, "scale", Vector2.ONE, animation_duration)
    await tween.finished


func _play_close_animation():
    var tween = create_tween()
    tween.tween_property(self, "modulate:a", 0.0, animation_duration)
    tween.parallel().tween_property(self, "scale", Vector2(0.9, 0.9), animation_duration)
    await tween.finished


func set_title(text: String):
    var title = find_child("Title", true, false)
    if title and title is Label:
        title.text = text


func show_message(message: String, duration: float = 2.0):
    var msg_label = Label.new()
    msg_label.text = message
    msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    msg_label.add_theme_color_override("font_color", Color.WHITE)
    msg_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    msg_label.add_theme_constant_override("shadow_offset_x", 2)
    msg_label.add_theme_constant_override("shadow_offset_y", 2)
    
    add_child(msg_label)
    msg_label.position = Vector2(size.x / 2 - 100, size.y / 2)
    
    await get_tree().create_timer(duration).timeout
    if is_instance_valid(msg_label):
        msg_label.queue_free()
