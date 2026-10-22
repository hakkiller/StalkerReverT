# terrain/pripyat_map_3d.gd
extends Node3D
class_name PripyatMap3D

## 3D-карта Припяти/ЧАЭС из OSM-данных (data/pripyat/).
## Заменяет TerrainGenerator в режиме «Припять»: строит рельеф из хайтмапа,
## экструдированные здания с коллизией, основные дороги; отдаёт навмеш
## (bake движком) и совместимый API ("terrain_generator").
## Монолит перемещается по маршруту ярусов кампании: центр Припяти -> Саркофаг.

const DATA_DIR := "res://data/pripyat/"
const GRID_STEP := 12.0            # шаг сетки рельефа (метры, = родное разрешение хайтмапа)
const ROAD_WIDTH_DEFAULT := 6.0
const MAX_ROADS := 120             # дороги в район: ленты на земле
const NAV_BAKE_DELAY := 0.5

# Район игры (bbox): покрывает центр Припяти -> промзону -> Янов -> ЧАЭС
@export var lat_min: float = 51.387
@export var lat_max: float = 51.410
@export var lon_min: float = 30.051
@export var lon_max: float = 30.105

# Маршрут Монолита по ярусам кампании (lat, lon): чем ближе к Саркофагу,
# тем выше ярус и сложнее волны (сложность уже растёт по уровням кампании).
const MONOLITH_ROUTE := [
	[51.4050, 30.0560],  # ярус 1: центр Припяти (площадь у ДК)
	[51.4047, 30.0615],  # ярус 2: стадион
	[51.4025, 30.0530],  # ярус 3: автостанция
	[51.4080, 30.0600],  # ярус 4: северный парк
	[51.4055, 30.0730],  # ярус 5: выезд из города
	[51.3990, 30.0770],  # ярус 6: промзона
	[51.4070, 30.0960],  # ярус 7: станция Янов
	[51.3965, 30.0930],  # ярус 8: подъезд к ЧАЭС
	[51.3905, 30.0985],  # ярус 9: машзал ЧАЭС
	[51.3890, 30.0996],  # ярус 10: Саркофаг
]

# Высоты зданий по типам OSM (метры), остальное - джиттер вокруг дефолта
const KIND_HEIGHTS := {
	"school": 15.0, "hospital": 25.0, "apartments": 18.0, "house": 8.0,
	"industrial": 12.0, "commercial": 12.0, "retail": 10.0, "office": 16.0,
	"church": 20.0, "garage": 4.0, "shed": 4.0, "roof": 6.0
}

var _meta: Dictionary = {}
var _data: Dictionary = {}
var _height_img: Image
var _nav_region: NavigationRegion3D
var _rng := RandomNumberGenerator.new()
# Полигоны земли района (вода/лес/промзона) с AABB - для тонировки вершин
var _ground_tints: Array = []
var _decal_textures: Array = []

# Кэш высоты под запросы
var _origin_lat: float = 51.4075
var _origin_lon: float = 30.07
var _hm_lat0: float = 51.435   # северная кромка хайтмапа
var _hm_lon0: float = 30.01    # западная кромка
var _hm_lat_span: float = 0.055
var _hm_lon_span: float = 0.12


func _ready():
	add_to_group("terrain_generator")
	_rng.seed = 20260426
	print("PripyatMap3D: загрузка данных...")
	_load_meta()
	_load_game_json()
	_collect_ground_tints()
	_load_decal_textures()
	_build_terrain()
	_build_buildings()
	_build_roads()
	_build_props()
	_setup_navigation()
	# Небо Припяти: грозовое (polyhaven CC0), чуть глуше обычного
	_apply_sky("res://assets/sky/sky_storm_gloomy_4k.hdr", 0.85)
	print("PripyatMap3D: готов. Зданий в районе: ", _data.get("_buildings_built", 0))


# ==================== ЗАГРУЗКА ДАННЫХ ====================

func _load_meta():
	var f := FileAccess.open(DATA_DIR + "heightmap_meta.json", FileAccess.READ)
	if f == null:
		push_error("PripyatMap3D: нет heightmap_meta.json")
		return
	_meta = JSON.parse_string(f.get_as_text())
	_origin_lat = float(_meta.get("origin_lat", _origin_lat))
	_origin_lon = float(_meta.get("origin_lon", _origin_lon))
	var bbox: Dictionary = _meta.get("bbox", {})
	_hm_lat0 = float(bbox.get("north", _hm_lat0))
	_hm_lon0 = float(bbox.get("west", _hm_lon0))
	_hm_lat_span = float(bbox.get("north", 51.435)) - float(bbox.get("south", 51.38))
	_hm_lon_span = float(bbox.get("east", 30.13)) - float(bbox.get("west", 30.01))
	var tex: Texture2D = load(DATA_DIR + "pripyat_heightmap.png")
	_height_img = tex.get_image()
	if _height_img.is_compressed():
		_height_img.decompress()
	print("PripyatMap3D: хайтмап %dx%d, высоты %.0f..%.0f м" % [
		_height_img.get_width(), _height_img.get_height(),
		float(_meta.get("elev_min_m", 97.0)), float(_meta.get("elev_max_m", 159.0))])


func _load_game_json():
	var f := FileAccess.open(DATA_DIR + "pripyat_zone_game.json", FileAccess.READ)
	if f == null:
		push_error("PripyatMap3D: нет pripyat_zone_game.json")
		return
	_data = JSON.parse_string(f.get_as_text())
	if _data == null or not _data.has("layers"):
		push_error("PripyatMap3D: битый игровой JSON")
		_data = {}


# ==================== КООРДИНАТЫ (как в лоадере 2D) ====================

func latlon_to_world(lat: float, lon: float) -> Vector2:
	var x := (lon - _origin_lon) * 111320.0 * cos(deg_to_rad(_origin_lat))
	var y := (_origin_lat - lat) * 110574.0
	return Vector2(x, y)


func get_terrain_height(wx: float, wz: float) -> float:
	"""Высота рельефа в мировых координатах (билинейно по хайтмапу)."""
	if _height_img == null:
		return 0.0
	var lat := _origin_lat - wz / 110574.0
	var lon := _origin_lon + wx / (111320.0 * cos(deg_to_rad(_origin_lat)))
	var px_f := (lon - _hm_lon0) / _hm_lon_span * float(_height_img.get_width() - 1)
	var py_f := (_hm_lat0 - lat) / _hm_lat_span * float(_height_img.get_height() - 1)
	px_f = clampf(px_f, 0.0, _height_img.get_width() - 1.001)
	py_f = clampf(py_f, 0.0, _height_img.get_height() - 1.001)
	var x0 := int(px_f)
	var y0 := int(py_f)
	var fx := px_f - float(x0)
	var fy := py_f - float(y0)
	var h00 := _height_at(x0, y0)
	var h10 := _height_at(x0 + 1, y0)
	var h01 := _height_at(x0, y0 + 1)
	var h11 := _height_at(x0 + 1, y0 + 1)
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fy)


func _height_at(px: int, py: int) -> float:
	var elev_min := float(_meta.get("elev_min_m", 97.0))
	var elev_max := float(_meta.get("elev_max_m", 159.0))
	var c := _height_img.get_pixel(clampi(px, 0, _height_img.get_width() - 1),
		clampi(py, 0, _height_img.get_height() - 1))
	return elev_min + float(c.r) * (elev_max - elev_min)


# ==================== ТОНТИРОВКА ЗЕМЛИ И ДЕКАЛИ ====================

## Собирает полигоны земли района (вода/лес/промзона) для тонировки вершин.
## Порядок = приоритет: вода перекрывает всё, потом промзона, болото, лес.
func _collect_ground_tints():
	var layers: Dictionary = _data.get("layers", {})
	var recipes := [
		{"layer": "water", "kinds": {}, "color": Color(0.16, 0.20, 0.22)},
		{"layer": "landuse", "kinds": ["industrial", "quarry"], "color": Color(0.60, 0.58, 0.56)},
		{"layer": "landuse", "kinds": ["wetland"], "color": Color(0.36, 0.42, 0.32)},
		{"layer": "forest", "kinds": {}, "color": Color(0.50, 0.46, 0.28)},
		{"layer": "landuse", "kinds": ["wood", "grass", "meadow"], "color": Color(0.55, 0.52, 0.33)},
	]
	for recipe in recipes:
		var layer: Dictionary = layers.get(str(recipe["layer"]), {})
		for poly in layer.get("polygons", []):
			var outer: Array = poly.get("outer", [])
			if outer.size() < 3:
				continue
			var props: Dictionary = poly.get("props", {})
			var kinds: Array = recipe["kinds"]
			if not kinds.is_empty() and not kinds.has(str(props.get("kind", ""))):
				continue
			var pts := PackedVector2Array()
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for p in outer:
				var v := Vector2(float(p[0]), float(p[1]))
				pts.append(v)
				lo = lo.min(v)
				hi = hi.max(v)
			# Грубое отсечение районом по AABB
			if hi.x < _w_min() or lo.x > _w_max() or hi.y < _d_min() or lo.y > _d_max():
				continue
			_ground_tints.append({
				"pts": pts, "rect": Rect2(lo, hi - lo), "color": recipe["color"]})


func _tint_at(wx: float, wz: float) -> Color:
	"""Цвет земли в точке: первый по приоритету полигон, содержащий точку."""
	for tint in _ground_tints:
		var rect: Rect2 = tint["rect"]
		if not rect.has_point(Vector2(wx, wz)):
			continue
		if Geometry2D.is_point_in_polygon(Vector2(wx, wz), tint["pts"]):
			return tint["color"]
	return Color.WHITE


func _load_decal_textures():
	for layer_name in ["crack_01", "crack_02", "crack_03", "rust_streak_01", "rust_streak_02",
			"stain_dark_01", "stain_dark_02", "stain_oil_01", "moss_patch_01",
			"moss_patch_02", "sign_radiation", "paint_x_white"]:
		var path := "res://assets/decals/%s.png" % name
		if ResourceLoader.exists(path):
			_decal_textures.append(load(path))


## Декаль на случайной стене здания (высота h, контур outer, база base_y)
func _add_wall_decal(outer: Array, base_y: float, h: float, center: Vector2):
	if _decal_textures.is_empty() or outer.size() < 3:
		return
	var i := _rng.randi_range(0, outer.size() - 1)
	var p0: Array = outer[i]
	var p1: Array = outer[(i + 1) % outer.size()]
	var a := Vector2(float(p0[0]), float(p0[1]))
	var b := Vector2(float(p1[0]), float(p1[1]))
	var edge := b - a
	if edge.length() < 2.0:
		return
	var outward := (Vector2(a.x, a.y) + (b - a) * 0.5 - center).normalized()
	var normal := Vector3(-edge.normalized().y * sign(outward.cross(edge.normalized())), 0,
		edge.normalized().x * sign(outward.cross(edge.normalized())))
	# sign может занулиться на вырожденных случаях - фолбэк наружу от центра
	if normal.length_squared() < 0.01:
		normal = Vector3(outward.x, 0, outward.y)
	normal = normal.normalized()

	var wall_y := base_y + _rng.randf_range(1.0, minf(h - 0.5, 5.0))
	var t := _rng.randf_range(0.25, 0.75)
	var pos3 := Vector3(lerpf(a.x, b.x, t), wall_y, lerpf(a.y, b.y, t))

	var decal := Decal.new()
	var w := _rng.randf_range(1.8, 3.2)
	decal.size = Vector3(w, w, 2.0)
	decal.texture_albedo = _decal_textures[_rng.randi_range(0, _decal_textures.size() - 1)]
	decal.modulate = Color(1, 1, 1, 0.85)
	# Локальная ось Y дефаля = нормаль стены (проекция через стену)
	var y_axis := normal
	var x_axis := Vector3.UP.cross(y_axis)
	if x_axis.length_squared() < 0.01:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	decal.basis = Basis(x_axis, y_axis, z_axis)
	decal.position = pos3 + normal * 1.0
	add_child(decal)


# ==================== РЕЛЬЕФ ====================

func _build_terrain():
	var w_min := (lon_min - _origin_lon) * 111320.0 * cos(deg_to_rad(_origin_lat))
	var w_max := (lon_max - _origin_lon) * 111320.0 * cos(deg_to_rad(_origin_lat))
	var d_min := (_origin_lat - lat_max) * 110574.0
	var d_max := (_origin_lat - lat_min) * 110574.0

	var cols := int(ceil((w_max - w_min) / GRID_STEP))
	var rows := int(ceil((d_max - d_min) / GRID_STEP))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for iz in range(rows):
		for ix in range(cols):
			var x0 := w_min + ix * GRID_STEP
			var z0 := d_min + iz * GRID_STEP
			var x1 := x0 + GRID_STEP
			var z1 := z0 + GRID_STEP
			var h00 := get_terrain_height(x0, z0)
			var h10 := get_terrain_height(x1, z0)
			var h01 := get_terrain_height(x0, z1)
			var h11 := get_terrain_height(x1, z1)
			# Тонировка: вода/лес/промзона красят вершины (умножаются на текстуру)
			var tint := _tint_at(x0 + GRID_STEP * 0.5, z0 + GRID_STEP * 0.5)
			# Два треугольника, нормали вверх (порядок против часовой сверху)
			_tri(st, tint,
				Vector3(x0, h00, z0), Vector3(x0, h01, z1), Vector3(x1, h11, z1))
			_tri(st, tint,
				Vector3(x0, h00, z0), Vector3(x1, h11, z1), Vector3(x1, h10, z0))

	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = mesh
	# Тот же материал, что в процедурной Зоне: грязь + vertex colors не нужны
	mi.material_override = _ground_material()
	add_child(mi)

	# Коллизия рельефа одним тримешем
	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(mesh.get_faces())
	shape.shape = concave
	body.add_child(shape)
	add_child(body)
	print("PripyatMap3D: рельеф %dx%d ячеек" % [cols, rows])


func _tri(st: SurfaceTool, color: Color, a: Vector3, b: Vector3, c: Vector3):
	var n := (b - a).cross(c - a).normalized()
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(a)
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(c)


func _ground_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.52, 0.50, 0.42)
	m.roughness = 1.0
	# Vertex colors (вода/лес/промзона) умножаются на текстуру земли
	m.vertex_color_use_as_albedo = true
	if ResourceLoader.exists("res://assets/textures/pbr/dirt_dry/albedo.jpg"):
		m.albedo_texture = load("res://assets/textures/pbr/dirt_dry/albedo.jpg")
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.08, 0.08, 0.08)
		if ResourceLoader.exists("res://assets/textures/pbr/dirt_dry/normal.png"):
			m.normal_enabled = true
			m.normal_texture = load("res://assets/textures/pbr/dirt_dry/normal.png")
			m.normal_scale = 0.6
	return m


# ==================== ЗДАНИЯ ====================

func _build_buildings():
	var layers: Dictionary = _data.get("layers", {})
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var collision_faces := PackedVector3Array()
	var built := 0

	for layer_name in ["buildings", "building_parts"]:
		var layer: Dictionary = layers.get(layer_name, {})
		for poly in layer.get("polygons", []):
			var outer: Array = poly.get("outer", [])
			if outer.size() < 3:
				continue
			# Фильтр района: центр контура в bbox
			var c := _ring_center(outer)
			if c.x < _w_min() or c.x > _w_max() or c.y < _d_min() or c.y > _d_max():
				continue

			var props: Dictionary = poly.get("props", {})
			var height := _building_height(props)
			var base_y := get_terrain_height(c.x, c.y) - 0.5
			var top_y := base_y + height

			# Декали грязи на крупных зданиях
			if height >= 6.0 and _rng.randf() < 0.5:
				_add_wall_decal(outer, base_y, height, c)

			# Стены по контуру
			var n := outer.size()
			for i in range(n):
				var p0: Array = outer[i]
				var p1: Array = outer[(i + 1) % n]
				var a := Vector3(float(p0[0]), base_y, float(p0[1]))
				var b := Vector3(float(p1[0]), base_y, float(p1[1]))
				_quad(st,
					Vector3(a.x, base_y, a.z), Vector3(b.x, base_y, b.z),
					Vector3(b.x, top_y, b.z), Vector3(a.x, top_y, a.z))
				# Коллизия: те же грани
				collision_faces.append_array(PackedVector3Array([
					Vector3(a.x, base_y, a.z), Vector3(b.x, base_y, b.z), Vector3(b.x, top_y, b.z),
					Vector3(a.x, base_y, a.z), Vector3(b.x, top_y, b.z), Vector3(a.x, top_y, a.z)]))

			# Крыша: триангуляция контура
			var poly2d := PackedVector2Array()
			for p in outer:
				poly2d.append(Vector2(float(p[0]), float(p[1])))
			var tris := Geometry2D.triangulate_polygon(poly2d)
			if tris.size() >= 3:
				for i in range(0, tris.size(), 3):
					var a2 := poly2d[tris[i]]
					var b2 := poly2d[tris[i + 1]]
					var c2 := poly2d[tris[i + 2]]
					_quad(st,
						Vector3(a2.x, top_y, a2.y), Vector3(b2.x, top_y, b2.y),
						Vector3(c2.x, top_y, c2.y), Vector3(c2.x, top_y, c2.y))
			built += 1

	var mi := MeshInstance3D.new()
	mi.name = "BuildingsMesh"
	mi.mesh = st.commit()
	mi.material_override = _building_material()
	add_child(mi)

	# Одна коллизия на все здания (тримеш)
	var body := StaticBody3D.new()
	body.name = "BuildingsBody"
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(collision_faces)
	shape.shape = concave
	body.add_child(shape)
	add_child(body)

	_data["_buildings_built"] = built


func _ring_center(ring: Array) -> Vector2:
	var cx := 0.0
	var cy := 0.0
	for p in ring:
		cx += float(p[0])
		cy += float(p[1])
	return Vector2(cx / float(ring.size()), cy / float(ring.size()))


func _building_height(props: Dictionary) -> float:
	var kind := str(props.get("kind", ""))
	var base: float = float(KIND_HEIGHTS.get(kind, 12.0))
	return base * _rng.randf_range(0.85, 1.15)


func _w_min() -> float:
	return (lon_min - _origin_lon) * 111320.0 * cos(deg_to_rad(_origin_lat))


func _w_max() -> float:
	return (lon_max - _origin_lon) * 111320.0 * cos(deg_to_rad(_origin_lat))


func _d_min() -> float:
	return (_origin_lat - lat_max) * 110574.0


func _d_max() -> float:
	return (_origin_lat - lat_min) * 110574.0


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3):
	# Два треугольника a-b-c и a-c-d с общей плоской нормалью
	var n := (b - a).cross(c - a).normalized()
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.set_normal(n)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


func _building_material() -> StandardMaterial3D:
	# Единый бетон панелек - как в процедурной Зоне
	var m := _ground_material()
	m.albedo_color = Color(0.50, 0.50, 0.47)
	if ResourceLoader.exists("res://assets/textures/pbr/concrete_wall_dirty/albedo.jpg"):
		m.albedo_texture = load("res://assets/textures/pbr/concrete_wall_dirty/albedo.jpg")
		m.uv1_scale = Vector3(0.3, 0.3, 0.3)
		if ResourceLoader.exists("res://assets/textures/pbr/concrete_wall_dirty/normal.png"):
			m.normal_texture = load("res://assets/textures/pbr/concrete_wall_dirty/normal.png")
			m.normal_enabled = true
			m.normal_scale = 0.8
	return m


# ==================== ДОРОГИ ====================

func _build_roads():
	var layers: Dictionary = _data.get("layers", {})
	var roads: Dictionary = layers.get("roads", {})
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var road_count := 0

	for line in roads.get("lines", []):
		if road_count >= MAX_ROADS:
			break
		var points: Array = line.get("points", [])
		if points.size() < 2:
			continue
		var props: Dictionary = line.get("props", {})
		var width: float = float(props.get("width", ROAD_WIDTH_DEFAULT))
		width = clampf(width, 3.0, 14.0)
		road_count += 1

	# Лента по полилинии с выборкой каждой второй точки (экономия)
		var prev_left: Vector3
		var prev_right: Vector3
		var started := false
		for i in range(0, points.size(), 2):
			var p: Array = points[i]
			var wx := float(p[0])
			var wz := float(p[1])
			if wx < _w_min() or wx > _w_max() or wz < _d_min() or wz > _d_max():
				started = false
				continue
			# Направление - к следующей выбранной точке (или от предыдущей)
			var dir := Vector3.ZERO
			if i + 1 < points.size():
				var q: Array = points[i + 1]
				dir = Vector3(float(q[0]) - wx, 0, float(q[1]) - wz)
			elif started:
				dir = Vector3(wx - (prev_left.x + prev_right.x) * 0.5, 0,
					wz - (prev_left.z + prev_right.z) * 0.5)
			if dir.length() < 0.01:
				continue
			dir = dir.normalized()
			var perp := Vector3(-dir.z, 0, dir.x) * width * 0.5
			var y := get_terrain_height(wx, wz) + 0.15
			var left := Vector3(wx, y, wz) - perp
			var right := Vector3(wx, y, wz) + perp
			if started:
				_quad(st, prev_left, prev_right, right, left)
			prev_left = left
			prev_right = right
			started = true

	var mi := MeshInstance3D.new()
	mi.name = "RoadsMesh"
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.18, 0.18, 0.19)
	m.roughness = 0.95
	if ResourceLoader.exists("res://assets/textures/pbr/asphalt_old/albedo.jpg"):
		m.albedo_texture = load("res://assets/textures/pbr/asphalt_old/albedo.jpg")
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	mi.material_override = m
	add_child(mi)


# ==================== ПРОПСЫ УЛИЦ ====================

## Рассыпает машины/фонари/деревья/бочки/лавки «по смыслу местности»
## (terrain/pripyat_props.gd, плотности - PripyatPropsData). Вызов до
## _setup_navigation: коллизии пропсов вырезаются из навмеша.
func _build_props():
	var layers: Dictionary = _data.get("layers", {})
	var bounds := Rect2(_w_min(), _d_min(), _w_max() - _w_min(), _d_max() - _d_min())
	var props_root := PripyatProps.build(self, layers, bounds, get_terrain_height)
	add_child(props_root)


# ==================== НАВМЕШ И СОВМЕСТИМОСТЬ ====================

func _setup_navigation():
	_nav_region = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.7
	nm.agent_height = 2.0
	nm.agent_max_climb = 0.6
	nm.cell_size = 0.5
	_nav_region.navigation_mesh = nm
	add_child(_nav_region)
	# Печатаём геометрию района (рельеф+здания уже дети) и печём в потоке
	_nav_region.bake_navigation_mesh(true)
	_nav_region.bake_finished.connect(func():
		print("PripyatMap3D: навмеш испечён"))
	# Совместимость: пока печётся, движок использует пустой навмеш;
	# сталкеры начнут ходить после NAV_BAKE_DELAY - см. force_rebuild_navigation


func _update_chunks():
	pass  # совместимость с ZoneController._force_initial_chunk_load


func force_rebuild_navigation():
	# Печь один раз; повторные вызовы игнорируем
	if _nav_region and not _nav_region.navigation_mesh.has_polygon(0):
		_nav_region.bake_navigation_mesh(true)


func get_loaded_chunks_count() -> int:
	return 1


# ==================== МАРШРУТ МОНОЛИТА ====================

## Позиция Монолита для яруса кампании (1-10): центр Припяти -> Саркофаг
func monolith_position_for_level(level: int) -> Vector3:
	var tier: int = clampi((level - 1) / 10 + 1, 1, MONOLITH_ROUTE.size())
	var wp: Array = MONOLITH_ROUTE[tier - 1]
	var w := latlon_to_world(float(wp[0]), float(wp[1]))
	var y := get_terrain_height(w.x, w.y)
	print("PripyatMap3D: Монолит яруса %d -> %.0f, %.0f (h=%.1f)" % [tier, w.x, w.y, y])
	return Vector3(w.x, y, w.y)


func get_footstep_surface() -> String:
	return "stone"


func _apply_sky(hdr_path: String, energy: float):
	"""Панорамное небо в WorldEnvironment главной сцены; Припять глушит энергию"""
	var we := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null or not ResourceLoader.exists(hdr_path):
		return
	var mat := PanoramaSkyMaterial.new()
	mat.panorama = load(hdr_path)
	mat.energy_multiplier = energy
	var sky := Sky.new()
	sky.sky_material = mat
	we.environment.background_mode = Environment.BG_SKY
	we.environment.sky = sky
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
