# terrain/map_bootstrap.gd
extends Node

## Ставит нужную карту ДО того, как ZoneController начнёт искать террейн.
## Узел в main.tscn стоит первым среди детей Main - его _ready отрабатывает
## раньше _ready остальных, поэтому подмена проходит без ожидания кадров.

func _ready():
	var params: Dictionary = {}
	if get_tree().root.has_meta("run_params"):
		params = get_tree().root.get_meta("run_params")
	if str(params.get("map", "procedural")) != "pripyat":
		return

	var main := get_parent()
	var old_terrain := main.get_node_or_null("TerrainGenerator")
	if old_terrain:
		main.remove_child(old_terrain)
		old_terrain.queue_free()

	var pripyat: PripyatMap3D = PripyatMap3D.new()
	pripyat.name = "PripyatMap3D"
	main.add_child(pripyat)
	print("MapBootstrap: карта - Припять (процедурная Зона снята)")
