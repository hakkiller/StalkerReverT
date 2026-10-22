@tool
extends EditorScript

func _run():
	print("Начинаю сбор файлов...")
	
	var output = ""
	var file_count = 0
	
	# Просто собираем все файлы
	var all_files = []
	collect_files("res://", all_files)
	
	# Записываем каждый файл
	for file_path in all_files:
		# Пропускаем системные папки
		if file_path.contains(".godot/") or file_path.contains(".git"):
			continue
			
		file_count += 1
		print("Обрабатываю: " + file_path)
		
		# Разделитель
		output += "\n" + "----------------------------------------" + "\n"
		output += "ФАЙЛ: " + file_path + "\n"
		output += "----------------------------------------" + "\n\n"
		
		# Содержимое
		var content = read_file(file_path)
		output += content + "\n"
	
	# Сохраняем результат
	var save_path = "res://project_export.txt"
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(output)
		file.close()
		print("\n✅ ГОТОВО!")
		print("📁 Файлов обработано: " + str(file_count))
		print("📄 Результат: " + save_path)
	else:
		print("❌ Ошибка сохранения файла!")

func collect_files(path: String, files: Array):
	var dir = DirAccess.open(path)
	if dir == null:
		return
		
	dir.list_dir_begin()
	var item = dir.get_next()
	
	while item != "":
		if item == "." or item == "..":
			item = dir.get_next()
			continue
			
		var full = path + item
		
		if dir.current_is_dir():
			collect_files(full + "/", files)
		else:
			files.append(full)
			
		item = dir.get_next()
	
	dir.list_dir_end()

func read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "[ФАЙЛ НЕ НАЙДЕН]"
		
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		return file.get_as_text()
	else:
		return "[ОШИБКА ЧТЕНИЯ]"
