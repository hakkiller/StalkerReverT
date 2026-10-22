
# terrain/terrain_generator.gd
extends Node3D
class_name TerrainGenerator

## Чанковый генератор рельефа Зоны: холмы и лощины по шуму, плоская арена
## вокруг монолита, болотные низины, мёртвые деревья. У КАЖДОГО чанка свой
## навмеш (печётся один раз при загрузке) - никакой глобальной перепечки,
## которая давала подлагивания при движении камеры.

signal chunk_generated(chunk_pos: Vector2i)

@export var chunk_size: int = 32
@export var load_distance: int = 4
@export var debug_mode: bool = false

# Рельеф: детерминированный (мир одинаков от забега к забегу)
@export var terrain_seed: int = 1979
@export var terrain_amplitude: float = 4.5
@export var monolith_flat_radius: float = 35.0
@export var monolith_blend: float = 35.0
@export var props_per_chunk: int = 3

# Рельеф Зоны: реальная высотная карта Припяти (Copernicus DSM, окно 330м)
var _hm_data: PackedFloat32Array = PackedFloat32Array()
var _hm_grid: int = 0
var _hm_min: float = 0.0
var _hm_range: float = 1.0
# Вертикальная экспансия и кривая (тёплые низины чуть подняты - меньше "жидко")
const HM_EXPANSION: float = 2.5
var noise: FastNoiseLite
var noise_detail: FastNoiseLite
var noise_patch: FastNoiseLite
var loaded_chunks: Dictionary = {}
var camera: Camera3D

# Материалы и меши декора (создаются лениво, общие для всех чанков)
var _terrain_mat: StandardMaterial3D
var _bark_mat: StandardMaterial3D
var _trunk_mesh: CylinderMesh
var _branch_mesh: CylinderMesh
var _concrete_mat: StandardMaterial3D
var _concrete_dark_mat: StandardMaterial3D
var _rust_mat: StandardMaterial3D
var _box_mesh: BoxMesh

const NAV_SEGMENTS: int = 12  # сетка вершин на чанк (12x12 = 288 треугольников)
const STALKER_HEIGHT: float = 1.8


func _ready():
	# print("TerrainGenerator: _ready() START")
	_load_zone_heightmap()
	_setup_noise()
	add_to_group("terrain_generator")

	await get_tree().process_frame
	await get_tree().process_frame

	camera = get_viewport().get_camera_3d()
	# print("TerrainGenerator: камера найдена = ", camera != null)

	_update_chunks()

	# Небо: HDR-панорама (раньше _apply_sky нигде не вызывался - фон был плоским)
	_apply_sky("res://assets/sky/sky_storm_gloomy_4k.hdr", 0.8)

	# print("TerrainGenerator: _ready() DONE, загружено чанков: ", loaded_chunks.size())


func _load_zone_heightmap():
	"""Copernicus DSM окно 330м: [u16 grid][f32 min][f32 max][u16*grid^2]"""
	var path := "res://terrain/zone_height.raw"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	_hm_grid = f.get_16()
	_hm_min = f.get_float()
	var hmax: float = f.get_float()
	_hm_range = maxf(hmax - _hm_min, 0.1)
	_hm_data.resize(_hm_grid * _hm_grid)
	for i in range(_hm_grid * _hm_grid):
		_hm_data[i] = float(f.get_16()) / 65535.0
	# Нормировка в метры с экспансией
	for i in range(_hm_grid * _hm_grid):
		_hm_data[i] = (_hm_data[i] * _hm_range + _hm_min - _hm_min) * HM_EXPANSION


func _setup_noise():
	# Крупная рябь рельефа
	noise = FastNoiseLite.new()
	noise.seed = terrain_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.008
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	# Мелкие детали (овражки, бугры)
	noise_detail = FastNoiseLite.new()
	noise_detail.seed = terrain_seed + 101
	noise_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_detail.frequency = 0.045
	noise_detail.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_detail.fractal_octaves = 2
	# Пятна почвы (сухой грунт / трава)
	noise_patch = FastNoiseLite.new()
	noise_patch.seed = terrain_seed + 707
	noise_patch.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_patch.frequency = 0.02


func get_terrain_height(x: float, z: float) -> float:
	"""Высота рельефа: реальная карта Припяти (картa покрывает весь мир).
	Вокруг монолита - плоская арена, на краю мира - плавный спад к воде."""
	var h: float = _sample_heightmap(x, z)
	var dist := Vector2(x, z).length()
	var flat: float = clamp((dist - monolith_flat_radius) / monolith_blend, 0.0, 1.0)
	return h * flat


func _sample_heightmap(x: float, z: float) -> float:
	"""Билинейная выборка: мир [-165..165] -> карта [0..1]; v=0 север"""
	if _hm_grid == 0:
		return noise.get_noise_2d(x, z) * terrain_amplitude
	var u: float = clampf((x + 165.0) / 330.0, 0.0, 1.0)
	var v: float = clampf((z + 165.0) / 330.0, 0.0, 1.0)
	var fx: float = u * float(_hm_grid - 1)
	var fy: float = v * float(_hm_grid - 1)
	var x0 := int(fx)
	var y0 := int(fy)
	var tx: float = fx - float(x0)
	var ty: float = fy - float(y0)
	var x1 := mini(x0 + 1, _hm_grid - 1)
	var y1 := mini(y0 + 1, _hm_grid - 1)
	var a: float = _hm_data[y0 * _hm_grid + x0]
	var b: float = _hm_data[y0 * _hm_grid + x1]
	var c: float = _hm_data[y1 * _hm_grid + x0]
	var d: float = _hm_data[y1 * _hm_grid + x1]
	return (a * (1.0 - tx) + b * tx) * (1.0 - ty) + (c * (1.0 - tx) + d * tx) * ty


func _terrain_color(x: float, z: float, h: float) -> Color:
	# Полосы по НОРМИРОВАННОЙ высоте карты: реальный рельеф 0..~32м,
	# старые абсолютные пороги (-1.2/2.5) красили всё в выцветший грунт
	var patch = (noise_patch.get_noise_2d(x, z) + 1.0) * 0.5
	var t: float = clampf(h / maxf(_hm_range * HM_EXPANSION, 1.0), 0.0, 1.0) if _hm_grid > 0 else 0.5
	var col = Color(0.23, 0.27, 0.14)  # трава поймы
	col = col.lerp(Color(0.27, 0.30, 0.16), patch)  # вариация почвы
	if t > 0.55:
		col = col.lerp(Color(0.30, 0.30, 0.18), clampf((t - 0.55) / 0.25, 0.0, 1.0))  # сухой луг
	if t > 0.8:
		col = col.lerp(Color(0.34, 0.32, 0.27), clampf((t - 0.8) / 0.2, 0.0, 1.0))  # вершины
	return col


func _terrain_material() -> StandardMaterial3D:
	if _terrain_mat == null:
		_terrain_mat = StandardMaterial3D.new()
		_terrain_mat.albedo_color = Color.WHITE
		_terrain_mat.vertex_color_use_as_albedo = true
		_terrain_mat.roughness = 1.0
		# Сухая земля (CC0 ambientCG) трипланаром поверх vertex colors:
		# вершины красят зону, текстура даёт растрескавшийся микрофактуру
		if ResourceLoader.exists("res://assets/textures/pbr/dirt_dry/albedo.jpg"):
			_terrain_mat.albedo_texture = load("res://assets/textures/pbr/dirt_dry/albedo.jpg")
			_terrain_mat.uv1_triplanar = true
			_terrain_mat.uv1_scale = Vector3(0.08, 0.08, 0.08)
			if ResourceLoader.exists("res://assets/textures/pbr/dirt_dry/normal.png"):
				_terrain_mat.normal_enabled = true
				_terrain_mat.normal_texture = load("res://assets/textures/pbr/dirt_dry/normal.png")
				_terrain_mat.normal_scale = 0.6
	return _terrain_mat


func _build_chunk_mesh(chunk_pos: Vector2i) -> ArrayMesh:
	var origin = Vector3(chunk_pos.x * chunk_size, 0.0, chunk_pos.y * chunk_size)
	var step = float(chunk_size) / NAV_SEGMENTS
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	for iz in NAV_SEGMENTS + 1:
		for ix in NAV_SEGMENTS + 1:
			var wx = origin.x + ix * step
			var wz = origin.z + iz * step
			var h = get_terrain_height(wx, wz)
			verts.append(Vector3(wx, h, wz))
			# Нормаль из высотного поля - корректна независимо от winding
			var nx = get_terrain_height(wx - step, wz) - get_terrain_height(wx + step, wz)
			var nz = get_terrain_height(wx, wz - step) - get_terrain_height(wx, wz + step)
			norms.append(Vector3(nx, 2.0 * step, nz).normalized())
			colors.append(_terrain_color(wx, wz, h))

	for iz in NAV_SEGMENTS:
		for ix in NAV_SEGMENTS:
			var a = iz * (NAV_SEGMENTS + 1) + ix
			var b = a + 1
			var c = a + NAV_SEGMENTS + 1
			var d = c + 1
			# Winding проверен на плоских квадратах - навмеш печётся
			indices.append_array([a, b, d, a, d, c])

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_nav_mesh() -> NavigationMesh:
	var nav_mesh = NavigationMesh.new()
	nav_mesh.cell_size = 0.3
	nav_mesh.cell_height = 0.25  # Должен совпадать с cell_height карты (0.25 по умолчанию)
	# Значения выровнены по сетке (кратны cell_size/cell_height), иначе Godot
	# при бейке округляет их и пишет warning о потере точности
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_radius = 0.6
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0
	return nav_mesh


func _process(_delta):
	if camera:
		_update_chunks()


func _update_chunks():
	if not camera:
		return

	var cam_pos = camera.global_position
	var current_chunk = _world_to_chunk(cam_pos)

	var chunks_to_load = []
	for x in range(current_chunk.x - load_distance, current_chunk.x + load_distance + 1):
		for z in range(current_chunk.y - load_distance, current_chunk.y + load_distance + 1):
			var chunk_pos = Vector2i(x, z)
			if not loaded_chunks.has(chunk_pos):
				chunks_to_load.append(chunk_pos)

	for chunk_pos in chunks_to_load:
		_load_chunk(chunk_pos)

	var chunks_to_unload = []
	for chunk_pos in loaded_chunks.keys():
		# Чанки вокруг монолита всегда загружены: арена спавна сталкеров,
		# из них не должен исчезать пол при уходе камеры
		if abs(chunk_pos.x) <= load_distance + 1 and abs(chunk_pos.y) <= load_distance + 1:
			continue
		if abs(chunk_pos.x - current_chunk.x) > load_distance + 1 or \
		   abs(chunk_pos.y - current_chunk.y) > load_distance + 1:
			chunks_to_unload.append(chunk_pos)

	for chunk_pos in chunks_to_unload:
		_unload_chunk(chunk_pos)


func _world_to_chunk(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / chunk_size)),
		int(floor(world_pos.z / chunk_size))
	)


func _load_chunk(chunk_pos: Vector2i):
	var chunk = Node3D.new()
	chunk.name = "Chunk_%d_%d" % [chunk_pos.x, chunk_pos.y]

	var mesh = _build_chunk_mesh(chunk_pos)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _terrain_material()
	chunk.add_child(mesh_instance)

	_add_collision(chunk, mesh)
	var nav_faces := _build_nav_faces(chunk_pos)
	nav_faces = _add_structures(chunk, chunk_pos, nav_faces)
	_bake_chunk_navigation(chunk, nav_faces)
	_add_props(chunk, chunk_pos)

	add_child(chunk)
	loaded_chunks[chunk_pos] = chunk
	chunk_generated.emit(chunk_pos)


func _build_nav_faces(chunk_pos: Vector2i) -> PackedVector3Array:
	"""Треугольники навмеша чанка с НАХЛЁСТОМ на шаг за границы:
	соседние навмеши перекрываются, и на швах между чанками не остаётся
	дыр (иначе сталкеры залипали на стыках, ходя 3-5м туда-сюда)"""
	var origin = Vector3(chunk_pos.x * chunk_size, 0.0, chunk_pos.y * chunk_size)
	var step = float(chunk_size) / NAV_SEGMENTS
	var n = NAV_SEGMENTS + 3  # точек на сторону: от -1 до NAV_SEGMENTS+1
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	for iz in n:
		for ix in n:
			var wx = origin.x + (ix - 1) * step
			var wz = origin.z + (iz - 1) * step
			verts.append(Vector3(wx, get_terrain_height(wx, wz), wz))
	for iz in n - 1:
		for ix in n - 1:
			var a = iz * n + ix
			var b = a + 1
			var c = a + n
			var d = c + 1
			indices.append_array([a, b, d, a, d, c])
	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for i in range(indices.size()):
		faces[i] = verts[indices[i]]
	return faces


func _bake_chunk_navigation(chunk: Node3D, nav_faces: PackedVector3Array):
	"""Навмеш чанка печётся ОДИН раз при загрузке (мелкий, ~2мс).
	Каждый чанк - своя NavigationRegion3D: загрузка/выгрузка чанка
	просто добавляет/убирает регион с карты, без глобальной перепечки."""
	var region = NavigationRegion3D.new()
	region.name = "ChunkNav"
	var source = NavigationMeshSourceGeometryData3D.new()
	source.add_faces(nav_faces, Transform3D.IDENTITY)
	var nav_mesh = _make_nav_mesh()
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source)
	region.navigation_mesh = nav_mesh
	chunk.add_child(region)


func _add_collision(chunk: Node3D, mesh: ArrayMesh):
	var body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0

	var shape = ConcavePolygonShape3D.new()
	shape.set_faces(mesh.get_faces())
	shape.backface_collision = true

	var col = CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	chunk.add_child(body)


# ==================== СТРУКТУРЫ ЗОНЫ ====================


# PBR-материал из пака ambientCG (CC0): albedo+normal+roughness(+ao) трипланаром
func _pbr_material(path: String, tint: Color, tile: float, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = metal
	var base := "res://assets/textures/pbr/" + path
	if ResourceLoader.exists(base + "/albedo.jpg"):
		m.albedo_texture = load(base + "/albedo.jpg")
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * tile
		if ResourceLoader.exists(base + "/normal.png"):
			m.normal_enabled = true
			m.normal_texture = load(base + "/normal.png")
			m.normal_scale = 0.8
		if ResourceLoader.exists(base + "/roughness.jpg"):
			m.roughness_texture = load(base + "/roughness.jpg")
		if ResourceLoader.exists(base + "/ao.jpg"):
			m.ao_enabled = true
			m.ao_texture = load(base + "/ao.jpg")
			m.ao_light_affect = 0.5
	return m

func _structure_materials():
	if _concrete_mat == null:
		# Панельки-руины: грязный бетон (CC0 ambientCG), тинт сохраняет цветовую
		# гамму Зоны, трипланар не тянет UV на боксах любого размера
		_concrete_mat = _pbr_material("concrete_wall_dirty", Color(0.55, 0.55, 0.51), 0.3, 0.95)
		_concrete_dark_mat = _pbr_material("concrete_floor", Color(0.30, 0.30, 0.29), 0.35, 1.0)
		_rust_mat = _pbr_material("corrugated_rust", Color(0.55, 0.36, 0.24), 0.4, 1.0, 0.35)
		_box_mesh = BoxMesh.new()
		_box_mesh.size = Vector3.ONE


func _add_box_instance(parent: Node3D, mat: StandardMaterial3D, pos: Vector3, size: Vector3, yaw: float) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = _box_mesh
	mi.scale = size
	mi.position = pos
	mi.rotation.y = yaw
	mi.material_override = mat
	parent.add_child(mi)
	return mi


# Декали грязи (CC0, из архива Припяти) - грузятся один раз
var _decal_textures: Array = []

func _add_wall_decal(body: Node3D, size: Vector3):
	"""Декаль на случайной вертикальной стене коробки (в локальных координатах body)"""
	if _decal_textures.is_empty():
		for sky_name in ["crack_01", "crack_02", "rust_streak_01", "stain_dark_01",
				"moss_patch_01", "stain_oil_01"]:
			var p := "res://assets/decals/%s.png" % name
			if ResourceLoader.exists(p):
				_decal_textures.append(load(p))
	if _decal_textures.is_empty():
		return

	var decal := Decal.new()
	var w := randf_range(1.4, 2.4)
	decal.size = Vector3(w, w, 1.6)
	decal.texture_albedo = _decal_textures[randi() % _decal_textures.size()]
	decal.modulate = Color(1, 1, 1, 0.8)

	# Случайная стена: 0/1 - широкие (X), 2/3 - торцы (Z)
	var face := randi() % 4
	var h := randf_range(-size.y * 0.1, size.y * 0.25)
	var pos: Vector3
	var normal: Vector3
	match face:
		0: pos = Vector3(randf_range(-1, 1) * size.x * 0.25, h, size.z * 0.5 + 0.4); normal = Vector3(0, 0, 1)
		1: pos = Vector3(randf_range(-1, 1) * size.x * 0.25, h, -size.z * 0.5 - 0.4); normal = Vector3(0, 0, -1)
		2: pos = Vector3(size.x * 0.5 + 0.4, h, randf_range(-1, 1) * size.z * 0.25); normal = Vector3(1, 0, 0)
		_: pos = Vector3(-size.x * 0.5 - 0.4, h, randf_range(-1, 1) * size.z * 0.25); normal = Vector3(-1, 0, 0)

	var y_axis := normal
	var x_axis := Vector3.UP.cross(y_axis).normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	decal.basis = Basis(x_axis, y_axis, z_axis)
	decal.position = pos
	body.add_child(decal)


func _find_structure_spot(origin: Vector3, rng: RandomNumberGenerator, placed: Array, min_gap: float) -> Vector3:
	for attempt in range(8):
		var px = origin.x + rng.randf() * chunk_size
		var pz = origin.z + rng.randf() * chunk_size
		var dist = Vector2(px, pz).length()
		if dist < monolith_flat_radius + 15.0 or dist > 148.0:
			continue
		var h = get_terrain_height(px, pz)
		if abs(get_terrain_height(px + 2.0, pz) - h) > 1.5:
			continue
		var clear = true
		for p in placed:
			if Vector2(px - p.x, pz - p.z).length() < min_gap:
				clear = false
				break
		if clear:
			return Vector3(px, h, pz)
	return Vector3.ZERO


static func _append_box_faces(faces: PackedVector3Array, center: Vector3, size: Vector3, yaw: float) -> void:
	# Грани строения в навмеш: берём грани настоящего BoxMesh (гарантированно
	# правильный winding - самописные грани вертикальных стен не растеризовались
	# Recast'ом, стены не вырезались из навмеша и сталкеры застревали в домах)
	var bm = BoxMesh.new()
	bm.size = size
	var box_faces = bm.get_faces()
	var cs = cos(yaw)
	var sn = sin(yaw)
	for v in box_faces:
		faces.append(center + Vector3(v.x * cs + v.z * sn, v.y, -v.x * sn + v.z * cs))


func _add_structures(chunk: Node3D, chunk_pos: Vector2i, nav_faces: PackedVector3Array) -> PackedVector3Array:
	_structure_materials()
	var origin = Vector3(chunk_pos.x * chunk_size, 0.0, chunk_pos.y * chunk_size)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(chunk_pos) ^ (terrain_seed + 555)
	var placed: Array = []

	# Руина дома: коробка + проём + обрушенный угол, коллизия и обход по навмешу
	if rng.randf() < 0.30:
		var spot = _find_structure_spot(origin, rng, placed, 8.0)
		if spot != Vector3.ZERO:
			placed.append(spot)
			var yaw = rng.randf() * TAU
			var size = Vector3(rng.randf_range(5.0, 8.0), rng.randf_range(3.0, 4.5), rng.randf_range(4.0, 6.0))
			var body = StaticBody3D.new()
			body.position = spot + Vector3(0.0, size.y / 2.0 - 0.3, 0.0)
			body.rotation.y = yaw
			var col = CollisionShape3D.new()
			var shape = BoxShape3D.new()
			shape.size = size
			col.shape = shape
			body.add_child(col)
			chunk.add_child(body)
			_add_box_instance(body, _concrete_mat, Vector3.ZERO, size, 0.0)
			_add_box_instance(body, _concrete_dark_mat, Vector3(0.0, -size.y * 0.15, size.z / 2.0 + 0.06), Vector3(1.2, size.y * 0.5, 0.12), 0.0)
			_add_wall_decal(body, size)
			_add_box_instance(chunk, _concrete_dark_mat, spot + Vector3(rng.randf_range(-4.5, 4.5), -0.4, rng.randf_range(-4.5, 4.5)), size * 0.4, rng.randf() * TAU)
			_append_box_faces(nav_faces, body.position, size, yaw)

	# Ржавый гараж
	if rng.randf() < 0.18:
		var spot = _find_structure_spot(origin, rng, placed, 6.0)
		if spot != Vector3.ZERO:
			placed.append(spot)
			var yaw = rng.randf() * TAU
			var size = Vector3(rng.randf_range(3.5, 4.5), rng.randf_range(2.0, 2.8), rng.randf_range(3.0, 4.0))
			var body = StaticBody3D.new()
			body.position = spot + Vector3(0.0, size.y / 2.0 - 0.25, 0.0)
			body.rotation.y = yaw
			var col = CollisionShape3D.new()
			var shape = BoxShape3D.new()
			shape.size = size
			col.shape = shape
			body.add_child(col)
			chunk.add_child(body)
			_add_box_instance(body, _rust_mat, Vector3.ZERO, size, 0.0)
			_add_box_instance(body, _concrete_dark_mat, Vector3(0.0, size.y * 0.55, 0.0), size * Vector3(1.05, 0.12, 1.05), 0.0)
			if rng.randf() < 0.5:
				_add_wall_decal(body, size)
			_append_box_faces(nav_faces, body.position, size, yaw)

	# Полузатопленная труба
	if rng.randf() < 0.20:
		var spot = _find_structure_spot(origin, rng, placed, 5.0)
		if spot != Vector3.ZERO:
			var pipe = MeshInstance3D.new()
			var pm = CylinderMesh.new()
			pm.top_radius = 0.9
			pm.bottom_radius = 0.9
			pm.height = rng.randf_range(5.0, 8.0)
			pipe.mesh = pm
			pipe.material_override = _rust_mat
			pipe.rotation = Vector3(0.0, rng.randf() * TAU, PI / 2.0)
			pipe.position = spot + Vector3(0.0, 0.25, 0.0)
			chunk.add_child(pipe)

	# Бетонные плиты
	if rng.randf() < 0.55:
		for i in range(rng.randi_range(1, 2)):
			var px = origin.x + rng.randf() * chunk_size
			var pz = origin.z + rng.randf() * chunk_size
			if Vector2(px, pz).length() < monolith_flat_radius + 8.0:
				continue
			var h = get_terrain_height(px, pz)
			_add_box_instance(chunk, _concrete_dark_mat, Vector3(px, h - 0.25, pz), Vector3(rng.randf_range(1.2, 2.2), 0.5, rng.randf_range(1.0, 1.8)), rng.randf() * TAU)

	# Ржавые бочки
	if rng.randf() < 0.35:
		for i in range(rng.randi_range(1, 2)):
			var px = origin.x + rng.randf() * chunk_size
			var pz = origin.z + rng.randf() * chunk_size
			if Vector2(px, pz).length() < monolith_flat_radius + 8.0:
				continue
			var h = get_terrain_height(px, pz)
			var barrel = MeshInstance3D.new()
			var bm = CylinderMesh.new()
			bm.top_radius = 0.35
			bm.bottom_radius = 0.35
			bm.height = 0.95
			barrel.mesh = bm
			barrel.material_override = _rust_mat
			barrel.position = Vector3(px, h + 0.35, pz)
			barrel.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.1, 0.1))
			chunk.add_child(barrel)

	return nav_faces


func _add_props(chunk: Node3D, chunk_pos: Vector2i):
	"""Мёртвые деревья: детерминированно по чанку, мимо арены монолита"""
	var origin = Vector3(chunk_pos.x * chunk_size, 0.0, chunk_pos.y * chunk_size)
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(chunk_pos) ^ terrain_seed

	for i in range(props_per_chunk):
		if rng.randf() < 0.45:
			continue
		var px = origin.x + rng.randf() * chunk_size
		var pz = origin.z + rng.randf() * chunk_size
		var dist = Vector2(px, pz).length()
		if dist < monolith_flat_radius + 10.0 or dist > 155.0:
			continue
		var h = get_terrain_height(px, pz)
		if abs(get_terrain_height(px + 1.0, pz) - h) > 1.2:
			continue  # не сажаем на крутых склонах
		var tree = _make_dead_tree(rng)
		tree.position = Vector3(px, h - 0.15, pz)
		chunk.add_child(tree)


func _make_dead_tree(rng: RandomNumberGenerator) -> Node3D:
	if _bark_mat == null:
		# Стволы: старое дерево (CC0), трипланар держит масштаб на тянутых цилиндрах
		_bark_mat = _pbr_material("wood_planks_old", Color(0.30, 0.24, 0.19), 0.7, 1.0)
		_trunk_mesh = CylinderMesh.new()
		_trunk_mesh.top_radius = 0.06
		_trunk_mesh.bottom_radius = 0.34
		_trunk_mesh.height = 1.0
		_branch_mesh = CylinderMesh.new()
		_branch_mesh.top_radius = 0.02
		_branch_mesh.bottom_radius = 0.09
		_branch_mesh.height = 1.0

	var root = Node3D.new()
	var trunk = MeshInstance3D.new()
	trunk.mesh = _trunk_mesh
	var trunk_h = rng.randf_range(4.5, 7.0)
	trunk.scale = Vector3(1, trunk_h, 1)
	trunk.position.y = trunk_h / 2.0
	trunk.material_override = _bark_mat
	root.add_child(trunk)

	for i in range(rng.randi_range(2, 3)):
		var branch = MeshInstance3D.new()
		branch.mesh = _branch_mesh
		var bl = rng.randf_range(1.4, 2.4)
		branch.scale = Vector3(1, bl, 1)
		branch.position.y = trunk_h * rng.randf_range(0.45, 0.8)
		branch.rotation = Vector3(rng.randf_range(0.7, 1.3), rng.randf() * TAU, 0)
		branch.material_override = _bark_mat
		root.add_child(branch)

	root.rotation.y = rng.randf() * TAU
	root.rotation.z = rng.randf_range(-0.08, 0.08)
	return root


func _unload_chunk(chunk_pos: Vector2i):
	if loaded_chunks.has(chunk_pos):
		var chunk = loaded_chunks[chunk_pos]
		chunk.queue_free()
		loaded_chunks.erase(chunk_pos)


func get_height_at(at: Vector3) -> float:
	return get_terrain_height(at.x, at.z)


func get_loaded_chunks_count() -> int:
	return loaded_chunks.size()


func get_nav_polygons_total() -> int:
	"""Суммарное число полигонов навмеша по всем загруженным чанкам"""
	var total = 0
	for chunk in loaded_chunks.values():
		if is_instance_valid(chunk):
			var region = chunk.get_node_or_null("ChunkNav")
			if region and region.navigation_mesh:
				total += region.navigation_mesh.get_polygon_count()
	return total


func clear_all_chunks():
	for chunk in loaded_chunks.values():
		if is_instance_valid(chunk):
			chunk.queue_free()
	loaded_chunks.clear()


func force_rebuild_navigation():
	"""Совместимость: у чанков свои навмеши, пересборка не нужна"""
	# print("TerrainGenerator: навигация на чанковых навмешах, чанков: ", loaded_chunks.size(),
		  # ", полигонов: ", get_nav_polygons_total())


func get_footstep_surface() -> String:
	return "grass"


func _apply_sky(hdr_path: String, energy: float):
	"""Панорамное небо в WorldEnvironment главной сцены (без UV/меша)."""
	var we := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null or not ResourceLoader.exists(hdr_path):
		return
	var mat := PanoramaSkyMaterial.new()
	mat.panorama = load(hdr_path)
	var sky := Sky.new()
	sky.sky_material = mat
	we.environment.background_mode = Environment.BG_SKY
	we.environment.sky = sky
	# Существующий мрачный ambient сохраняем: источник COLOR, не от неба
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
