# ui/ui_theme.gd
class_name UiTheme
extends RefCounted

## Общая тема UI-оболочки: НЕПРОЗРАЧНЫЕ тёмные панели — всплывающие окна
## читаются поверх живого фона (жалоба: текст просвечивал из-под панелей).
## Применять корню сцены: `theme = UiTheme.build()`.
## В теме описаны только панели — остальные контролы падают в тему по
## умолчанию Godot и выглядят как раньше.

static func build() -> Theme:
	var t := Theme.new()
	var box := panel_box()
	t.set_stylebox("panel", "PanelContainer", box)
	t.set_stylebox("panel", "Panel", box)
	t.set_stylebox("panel", "PopupPanel", box)
	return t


static func panel_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.07, 0.09, 0.98)  # почти непрозрачный графит
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.34, 0.42, 0.31, 0.9)  # болотная окантовка Зоны
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb
