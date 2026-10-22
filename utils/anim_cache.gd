# utils/anim_cache.gd
class_name AnimCache
extends RefCounted

## Кеш анимаций, извлечённых из тяжёлых моделей (FBX/GLB).
##
## ПРОБЛЕМА, КОТОРУЮ РЕШАЕТ:
## раньше каждый спавн сталкера делал load("..._убит.fbx") + instantiate()
## модели с 4K-текстурами только ради одного клипа смерти, а кровосос грузил
## bloodsucker_run.glb. Первый такой load в сессии давал фриз на 0.2-2 с
## (диск + декомпрессия VRAM-текстур + instantiate скелета), последующие -
## хитчи по 5-20 мс на instantiate/free целой модели ради анимации.
##
## РЕШЕНИЕ:
## 1) warm_up() вызывается SpawnManager'ом на старте уровня - вся загрузка
##    происходит до боя, по одной модели за кадр.
## 2) Animation - это Resource, их можно безопасно разделять между многими
##    AnimationPlayer'ами. Кеш отдаёт готовые клипы, спавн больше не трогает
##    тяжёлые модели вообще.

static var _cache: Dictionary = {}

# Модели, из которых извлекаются клипы (грузятся на старте уровня).
const WARMUP_PATHS: Array[String] = [
	"res://models/новичёк_убит.fbx",
	"res://models/ветеран_убит.fbx",
	"res://models/мастер_убит.fbx",
	"res://models/bloodsucker_run.glb",
]


## Возвращает словарь {имя_клипа: Animation} для модели по пути.
## Первое обращение грузит модель (на старте это уже сделано warm_up'ом).
static func get_animations(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]

	var result: Dictionary = {}
	if ResourceLoader.exists(path):
		var ps: PackedScene = load(path) as PackedScene
		if ps:
			var inst: Node = ps.instantiate()
			for ap in inst.find_children("*", "AnimationPlayer", true, false):
				var apl := ap as AnimationPlayer
				for an in apl.get_animation_list():
					if not result.has(an):
						result[an] = apl.get_animation(an)
			inst.free()
	_cache[path] = result
	return result


## Добавляет клипы из кеша в AnimationPlayer сущности.
## Возвращает имя добавленного клипа смерти (или "").
static func apply_animations(player: AnimationPlayer, path: String, skip_names: Array = []) -> String:
	var added_name: String = ""
	var anims: Dictionary = get_animations(path)
	var lib: AnimationLibrary = player.get_animation_library("")
	for an in anims:
		if an in skip_names or player.has_animation(an):
			continue
		lib.add_animation(an, anims[an])
		if added_name == "":
			added_name = an
	return added_name


## Прогрев: грузит все WARMUP_PATHS. Вызывается из SpawnManager._ready()
## распределённо (по одной модели за кадр), чтобы не подвесить загрузку уровня.
static func warm_up_step(index: int) -> void:
	if index < 0 or index >= WARMUP_PATHS.size():
		return
	get_animations(WARMUP_PATHS[index])
