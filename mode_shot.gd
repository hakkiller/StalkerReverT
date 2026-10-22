extends SceneTree
# Скриншот journey_map для проверки рисованных карт (запуск под Xvfb).

func _init() -> void:
	var which: String = OS.get_environment("SHOT_MODE")
	var out: String = OS.get_environment("SHOT_OUT")
	var jm = load("res://ui/lab/journey_map.gd").new()
	root.add_child(jm)
	jm.position = Vector2(180, 390)
	jm.size = Vector2(1560, 295)
	if which == "campaign":
		jm.set_campaign(27, 27, "Стаи и ловушки")
	elif which == "survival":
		jm.set_survival(12)
	elif which == "survival0":
		jm.set_survival(0)
	elif which == "campaign100":
		jm.set_campaign(100, 100, "Последний рубеж")
	elif which == "survival60":
		jm.set_survival(60)
	else:
		jm.set_tower(34, 34, "Корни")
	_go(24, out)

func _go(frames: int, out: String) -> void:
	for i in range(frames):
		await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png(out)
	print("SHOT_SAVED ", out)
	quit()
