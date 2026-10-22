@tool
extends EditorScript

func _run():
	var output = ""
	
	# project.godot
	output += "=== project.godot ===\n"
	output += _read_file("res://project.godot")
	output += "\n\n"
	
	# Структура папок
	output += "=== СТРУКТУРА ПАПОК ===\n"
	output += _get_folder_structure("res://")
	output += "\n\n"
	
	# Все .gd файлы
	output += "=== ВСЕ GD ФАЙЛЫ ===\n"
	var gd_files = []
	_collect_files("res://scripts/", ".gd", gd_files)
	for file in gd_files:
		output += "\n--- " + file + " ---\n"
		output += _read_file(file)
		output += "\n"
	
	# Все .tscn файлы (основные)
	output += "=== ВАЖНЫЕ TSCN ФАЙЛЫ ===\n"
	var tscn_files = []
	_collect_files("res://scenes/main/", ".tscn", tscn_files)
	_collect_files("res://scenes/lab/", ".tscn", tscn_files)
	_collect_files("res://scenes/ui/", ".tscn", tscn_files)
	for file in tscn_files:
		output += "\n--- " + file + " ---\n"
		output += _read_file(file)
		output += "\n"
	
	# Сохраняем
	var file = FileAccess.open("res://project_export.txt", FileAccess.WRITE)
	file.store_string(output)
	print("✅ Экспорт завершён! Файл: res://project_export.txt")

func _collect_files(path: String, ext: String, files: Array):
	var dir = DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and file_name != "." and file_name != "..":
			_collect_files(path + file_name + "/", ext, files)
		elif file_name.ends_with(ext):
			files.append(path + file_name)
		file_name = dir.get_next()

func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "Файл не найден: " + path + "\n"
	var file = FileAccess.open(path, FileAccess.READ)
	return file.get_as_text()

func _get_folder_structure(path: String, prefix: String = "") -> String:
	var result = ""
	var dir = DirAccess.open(path)
	if not dir:
		return "Не удалось открыть " + path + "\n"
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		if dir.current_is_dir():
			result += prefix + "📁 " + file_name + "/\n"
			result += _get_folder_structure(path + file_name + "/", prefix + "    ")
		else:
			result += prefix + "📄 " + file_name + "\n"
		file_name = dir.get_next()
	return result
