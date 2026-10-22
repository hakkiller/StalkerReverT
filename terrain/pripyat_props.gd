# terrain/pripyat_props.gd
extends RefCounted
class_name PripyatProps

## Раскладка уличных пропсов на карте Припяти «по смыслу местности»:
## машины/фонари/остановки/автобусы - вдоль дорог OSM; деревья/кусты -
## лес и поля; бочки/бетон/ящики/шины - промзона; лавки/качели/трава -
## дворы жилой застройки; заборы - у гаражей и сараев.
## Модели: models/props/ (CC0, см. CREDITS.md там). Плотности: PripyatPropsData.
## Коллизии крупных пропсов - один StaticBody3D с боксами: вызывать ДО
## запечки навмеша, тогда пропсы вырезаются из него.

static var _scenes: Dictionary = {}
static var _rng := RandomNumberGenerator.new()

# Контекст запретных зон (собирается один раз на раскладку)
class Ctx:
	var road_grid: Dictionary = {}     # Vector2i(ячейка 30м) -> [{p, half}]
	var road_samples: Array = []      # [{p: Vector2, half: float}]
	var building_rects: Array = []    # Rect2 (уже с запасом BUILDING_PAD)
	var water_polys: Array = []       # [{pts: PackedVector2Array, rect: Rect2}]
	var green_polys: Array = []       # лес/поля - чтобы не дублировать глобальные деревья


const ROAD_GRID_CELL := 30.0


static func _road_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / ROAD_GRID_CELL)), int(floor(p.y / ROAD_GRID_CELL)))


## Строит и возвращает корень пропсов (добавить ребёнком карты до навмеша).
static func build(_host: Node3D, layers: Dictionary, bounds: Rect2,
		height_fn: Callable) -> Node3D:
	_rng.seed = PripyatPropsData.SEED
	_scenes.clear()

	var root := Node3D.new()
	root.name = "PropsRoot"
	var body := StaticBody3D.new()
	body.name = "PropsBody"
	root.add_child(body)

	var ctx := Ctx.new()
	_collect_context(ctx, layers, bounds)

	var stats := {}
	stats["машины"] = _scatter_roads(root, body, layers, bounds, height_fn, ctx)
	stats.merge(_scatter_green(root, body, layers, bounds, height_fn, ctx))
	stats.merge(_scatter_industrial(root, body, layers, bounds, height_fn, ctx))
	stats.merge(_scatter_yards(root, body, layers, bounds, height_fn, ctx))
	stats.merge(_scatter_fences(root, body, layers, bounds, height_fn, ctx))
	stats["одинокие деревья"] = _scatter_global_trees(root, body, bounds, height_fn, ctx)

	var parts: Array = []
	for key in stats:
		if int(stats[key]) > 0:
			parts.append("%s: %d" % [key, stats[key]])
	print("PripyatProps: раскладка готова (", " · ".join(parts), ")")
	return root


# ==================== КОНТЕКСТ ЗАПРЕТНЫХ ЗОН ====================

static func _collect_context(ctx: Ctx, layers: Dictionary, bounds: Rect2) -> void:
	# Дороги: точки-образцы с полушириной (все точки полилиний) + сетка-бакет
	for line in layers.get("roads", {}).get("lines", []):
		var width := clampf(float(line.get("props", {}).get("width", 6.0)), 3.0, 14.0)
		for p in line.get("points", []):
			var v := Vector2(float(p[0]), float(p[1]))
			if bounds.has_point(v):
				var sample := {"p": v, "half": width * 0.5}
				ctx.road_samples.append(sample)
				var cell := _road_cell(v)
				if not ctx.road_grid.has(cell):
					ctx.road_grid[cell] = []
				(ctx.road_grid[cell] as Array).append(sample)

	# Здания: AABB с запасом
	for layer_name in ["buildings", "building_parts"]:
		for poly in layers.get(layer_name, {}).get("polygons", []):
			var rect := _ring_rect(poly.get("outer", []))
			if rect.size == Vector2.ZERO:
				continue
			ctx.building_rects.append(rect.grow(PripyatPropsData.BUILDING_PAD))

	# Вода: полигоны (не только AABB - берега кривые)
	for poly in layers.get("water", {}).get("polygons", []):
		var packed := _ring_packed(poly.get("outer", []))
		if packed.size() >= 3:
			var rect := _packed_rect(packed).grow(PripyatPropsData.WATER_PAD)
			ctx.water_polys.append({"pts": packed, "rect": rect})

	# Зелёные полигоны: лес + wood/grass/meadow/wetland
	ctx.green_polys = _collect_polys(layers, [
		["forest", []],
		["landuse", ["wood", "grass", "meadow", "wetland"]],
	])


static func _ring_rect(ring: Array) -> Rect2:
	if ring.size() < 3:
		return Rect2()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in ring:
		var v := Vector2(float(p[0]), float(p[1]))
		lo = lo.min(v)
		hi = hi.max(v)
	return Rect2(lo, hi - lo)


static func _ring_packed(ring: Array) -> PackedVector2Array:
	var packed := PackedVector2Array()
	for p in ring:
		packed.append(Vector2(float(p[0]), float(p[1])))
	return packed


static func _packed_rect(pts: PackedVector2Array) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v in pts:
		lo = lo.min(v)
		hi = hi.max(v)
	return Rect2(lo, hi - lo)


## Полигоны слоя с фильтром по kind: [[слой, [kinds]], ...] -> [{pts, rect}]
static func _collect_polys(layers: Dictionary, recipes: Array) -> Array:
	var out: Array = []
	for recipe in recipes:
		var layer: Dictionary = layers.get(str(recipe[0]), {})
		var kinds: Array = recipe[1]
		for poly in layer.get("polygons", []):
			if not kinds.is_empty() and not kinds.has(str(poly.get("props", {}).get("kind", ""))):
				continue
			var packed := _ring_packed(poly.get("outer", []))
			if packed.size() >= 3:
				out.append({"pts": packed, "rect": _packed_rect(packed)})
	return out


## Площадь полигона (шнурки) - для плотностей на площадь
static func _poly_area(pts: PackedVector2Array) -> float:
	var area := 0.0
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		area += a.x * b.y - b.x * a.y
	return absf(area) * 0.5


static func _in_polys(_ctx: Ctx, p: Vector2, polys: Array) -> bool:
	for poly in polys:
		if not (poly["rect"] as Rect2).has_point(p):
			continue
		if Geometry2D.is_point_in_polygon(p, poly["pts"]):
			return true
	return false


## Общая проверка «сюда ставить нельзя»: здания, вода, дороги (с зазором).
## Дороги смотрим по сетке 3x3 ячейки - полный скан всех точек слишком долог.
static func _blocked(ctx: Ctx, p: Vector2) -> bool:
	for rect in ctx.building_rects:
		if (rect as Rect2).has_point(p):
			return true
	if _in_polys(ctx, p, ctx.water_polys):
		return true
	var c := _road_cell(p)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var cell := Vector2i(c.x + dx, c.y + dy)
			if not ctx.road_grid.has(cell):
				continue
			for sample in ctx.road_grid[cell]:
				if p.distance_to(sample["p"]) < float(sample["half"]) \
						+ PripyatPropsData.ROAD_CLEAR_PAD + 1.0:
					return true
	return false


# ==================== ВДОЛЬ ДОРОГ ====================

static func _scatter_roads(root: Node3D, body: StaticBody3D, layers: Dictionary,
		bounds: Rect2, height_fn: Callable, ctx: Ctx) -> int:
	var placed := 0
	var cars := 0
	var trucks := 0
	var buses := 0
	var lamps := 0
	var stops := 0

	for line in layers.get("roads", {}).get("lines", []):
		var pts: Array = line.get("points", [])
		if pts.size() < 2:
			continue
		var width := clampf(float(line.get("props", {}).get("width", 6.0)), 3.0, 14.0)
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var lamp_side := 1.0 if _rng.randf() < 0.5 else -1.0
		var next_car := _rng.randf_range(0.3, 1.0) * PripyatPropsData.CAR_SPACING
		var next_lamp := _rng.randf_range(0.0, 0.5) * PripyatPropsData.LAMP_SPACING
		var next_stop := _rng.randf_range(0.2, 1.0) * PripyatPropsData.STOP_SPACING
		var next_bus := _rng.randf_range(0.3, 1.0) * PripyatPropsData.BUS_SPACING

		for i in range(1, pts.size()):
			var a := Vector2(float(pts[i - 1][0]), float(pts[i - 1][1]))
			var b := Vector2(float(pts[i][0]), float(pts[i][1]))
			var seg := b - a
			var seg_len := seg.length()
			if seg_len < 0.01:
				continue
			var dir := seg / seg_len
			var perp := Vector2(-dir.y, dir.x)
			var yaw := rad_to_deg(atan2(dir.x, dir.y))

			var travelled := 0.0
			while travelled < seg_len:
				var step := minf(5.0, seg_len - travelled)
				travelled += step
				next_car -= step
				next_lamp -= step
				next_stop -= step
				next_bus -= step
				var p := a + dir * travelled
				if not bounds.has_point(p):
					continue
				var on_road_blocked := false
				for rect in ctx.building_rects:
					if (rect as Rect2).has_point(p):
						on_road_blocked = true
						break
				if on_road_blocked or _in_polys(ctx, p, ctx.water_polys):
					continue

				# Фонарь: мелкий, у самой кромки
				if next_lamp <= 0.0 and lamps < PripyatPropsData.MAX_LAMPS:
					next_lamp = PripyatPropsData.LAMP_SPACING
					var lp := p + perp * lamp_side * (width * 0.5 + PripyatPropsData.LAMP_SIDE_MARGIN)
					if bounds.has_point(lp):
						lamps += _spawn(root, body, "lamp_post", _at(height_fn, lp), yaw, height_fn)

				# Машина/грузовик: у обочины, доворот от направления дороги.
				# Имена - по факту поставки: car_body / _02 / _03 (без _01)
				if next_car <= 0.0 and cars + trucks < PripyatPropsData.MAX_CARS:
					next_car = PripyatPropsData.CAR_SPACING * _rng.randf_range(0.7, 1.3)
					var cp := p + perp * side * (width * 0.5
						+ PripyatPropsData.CAR_SIDE_MARGIN + _rng.randf_range(0.0, 1.5))
					if not bounds.has_point(cp):
						continue
					var is_truck := _rng.randf() < PripyatPropsData.TRUCK_CHANCE \
						and trucks < PripyatPropsData.MAX_TRUCKS
					var car_names := ["car_body", "car_body_02", "car_body_03"]
					var name: String = car_names[_rng.randi_range(0, car_names.size() - 1)]
					if is_truck:
						name = "truck"
						trucks += 1
					else:
						cars += 1
					var yaw_j := yaw + _rng.randf_range(-1.0, 1.0) \
						* PripyatPropsData.ROAD_ALIGN_JITTER \
						+ (180.0 if _rng.randf() < 0.5 else 0.0)
					placed += _spawn(root, body, name, _at(height_fn, cp), yaw_j, height_fn)

				# Остановка: павильон + изредка брошенный автобус рядом
				if next_stop <= 0.0 and stops < PripyatPropsData.MAX_STOPS:
					next_stop = PripyatPropsData.STOP_SPACING * _rng.randf_range(0.8, 1.2)
					var sp := p + perp * side * (width * 0.5 + 4.0)
					if bounds.has_point(sp):
						stops += _spawn(root, body, "bus_stop", _at(height_fn, sp),
							yaw + (90.0 if side > 0.0 else -90.0), height_fn)
				if next_bus <= 0.0 and buses < PripyatPropsData.MAX_BUSES:
					next_bus = PripyatPropsData.BUS_SPACING * _rng.randf_range(0.7, 1.3)
					var bp := p + perp * -side * (width * 0.5 + 2.5)
					if bounds.has_point(bp):
						buses += _spawn(root, body, "bus", _at(height_fn, bp),
							yaw + _rng.randf_range(-8.0, 8.0), height_fn)

	print("PripyatProps: дороги - машин %d (грузовики %d), автобусов %d, фонарей %d, остановок %d" % [
		cars, trucks, buses, lamps, stops])
	return placed


# ==================== ЛЕС И ПОЛЯ ====================

static func _scatter_green(root: Node3D, body: StaticBody3D, layers: Dictionary,
		bounds: Rect2, height_fn: Callable, ctx: Ctx) -> Dictionary:
	var out := {"деревья": 0, "кусты": 0}
	var polys := _collect_polys(layers, [
		["forest", []],
		["landuse", ["wood", "grass", "meadow"]],
	])
	var wetland := _collect_polys(layers, [["landuse", ["wetland"]]])

	var tree_name := func() -> String:
		if _rng.randf() < PripyatPropsData.PINE_SHARE:
			return "tree_pine" if _rng.randf() < 0.5 else "tree_pine_02"
		# Сухие - по факту поставки два варианта (без tree_dead_03)
		return ["tree_dead", "tree_dead_02"][_rng.randi_range(0, 1)]
	var bush_name := func() -> String:
		return "bush_dead"

	out["деревья"] = _scatter_in_polys(root, body, polys, bounds, height_fn, ctx,
		PripyatPropsData.TREE_PER_M2, PripyatPropsData.MAX_TREES, tree_name)

	# Кусты: лес/поля/болота, реже
	var bush_polys: Array = polys.duplicate()
	bush_polys.append_array(wetland)
	out["кусты"] = _scatter_in_polys(root, body, bush_polys, bounds, height_fn, ctx,
		PripyatPropsData.BUSH_PER_M2, PripyatPropsData.MAX_BUSHES, bush_name)
	return out


## Равномерный посев по площади полигонов с капом и запретными зонами
static func _scatter_in_polys(root: Node3D, body: StaticBody3D, polys: Array,
		bounds: Rect2, height_fn: Callable, ctx: Ctx, per_m2: float, cap: int,
		name_fn: Callable) -> int:
	if polys.is_empty() or per_m2 <= 0.0:
		return 0
	# Сколько хотим в каждом полигоне - пропорционально площади
	var wants: Array = []
	var total_want := 0
	for poly in polys:
		var want: int = mini(cap, int(_poly_area(poly["pts"]) * per_m2))
		wants.append(want)
		total_want += want
	if total_want == 0:
		return 0

	var placed := 0
	for i in polys.size():
		if placed >= cap:
			break
		var poly: Dictionary = polys[i]
		var want: int = mini(wants[i], cap - placed)
		var rect: Rect2 = poly["rect"].intersection(bounds)
		if rect.size == Vector2.ZERO:
			continue
		var tries := 0
		var local := 0
		while local < want and tries < want * 8:
			tries += 1
			var p := Vector2(
				_rng.randf_range(rect.position.x, rect.position.x + rect.size.x),
				_rng.randf_range(rect.position.y, rect.position.y + rect.size.y))
			if not Geometry2D.is_point_in_polygon(p, poly["pts"]):
				continue
			if _blocked(ctx, p):
				continue
			local += _spawn(root, body, String(name_fn.call()), _at(height_fn, p),
				_rng.randf_range(0.0, 360.0), height_fn)
		placed += local
	return placed


# ==================== ПРОМЗОНА ====================

static func _scatter_industrial(root: Node3D, body: StaticBody3D, layers: Dictionary,
		bounds: Rect2, height_fn: Callable, ctx: Ctx) -> Dictionary:
	var out := {"бочки": 0, "бетон": 0, "ящики": 0, "шины": 0}
	var polys := _collect_polys(layers, [["landuse", ["industrial", "quarry"]]])
	if polys.is_empty():
		return out

	var pick := func() -> Vector2:
		var poly: Dictionary = polys[_rng.randi_range(0, polys.size() - 1)]
		var rect: Rect2 = poly["rect"].intersection(bounds)
		if rect.size == Vector2.ZERO:
			return Vector2(INF, INF)
		for _try in 12:
			var p := Vector2(
				_rng.randf_range(rect.position.x, rect.position.x + rect.size.x),
				_rng.randf_range(rect.position.y, rect.position.y + rect.size.y))
			if Geometry2D.is_point_in_polygon(p, poly["pts"]) \
					and not PripyatProps._blocked(ctx, p):
				return p
		return Vector2(INF, INF)

	# Бочки гроздями по 1-3
	var clusters := 0
	while clusters < PripyatPropsData.BARREL_CLUSTERS:
		clusters += 1
		var p: Vector2 = pick.call()
		if p.x == INF:
			continue
		var n := _rng.randi_range(1, 3)
		for i in n:
			var off := Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.2, 1.2))
			var bp: Vector2 = p + off
			if _blocked(ctx, bp):
				continue
			out["бочки"] += _spawn(root, body, "barrel_radioactive",
				_at(height_fn, bp), _rng.randf_range(0.0, 360.0), height_fn)

	for key_name in [["бетон", "concrete_block", PripyatPropsData.MAX_CONCRETE],
			["ящики", "crate", PripyatPropsData.MAX_CRATES],
			["шины", "tire_pile", PripyatPropsData.MAX_TIRE_PILES]]:
		var placed := 0
		while placed < int(key_name[2]):
			var p: Vector2 = pick.call()
			if p.x == INF:
				break
			var name: String = key_name[1]
			if name == "concrete_block" and _rng.randf() < 0.4:
				name = "concrete_block_02"
			if name == "crate" and _rng.randf() < 0.5:
				name = "crate_02"
			placed += _spawn(root, body, name, _at(height_fn, p),
				_rng.randf_range(0.0, 360.0), height_fn)
		out[String(key_name[0])] = placed
	return out


# ==================== ДВОРЫ ЖИЛОЙ ЗАСТРОЙКИ ====================

static func _scatter_yards(root: Node3D, body: StaticBody3D, layers: Dictionary,
		bounds: Rect2, height_fn: Callable, ctx: Ctx) -> Dictionary:
	var out := {"лавки": 0, "качели": 0, "трава": 0}
	var benches := 0
	var swings := 0
	var grass := 0

	for poly in layers.get("buildings", {}).get("polygons", []):
		var kind := str(poly.get("props", {}).get("kind", ""))
		var is_residential := kind in ["apartments", "house", "school", "residential"]
		if not is_residential:
			continue
		var rect := _ring_rect(poly.get("outer", []))
		if rect.size == Vector2.ZERO or not bounds.intersects(rect.grow(8.0)):
			continue

		# Лавка у жилого дома
		if _rng.randf() < PripyatPropsData.YARD_BENCH_CHANCE \
				and benches < PripyatPropsData.MAX_BENCHES:
			var p := _yard_point(rect)
			if p.x != INF and not _blocked(ctx, p):
				benches += _spawn(root, body, "bench", _at(height_fn, p),
					_rng.randf_range(0.0, 360.0), height_fn)

		# Качели в частном секторе
		if kind == "house" and _rng.randf() < PripyatPropsData.YARD_SWING_CHANCE \
				and swings < PripyatPropsData.MAX_SWINGS:
			var p := _yard_point(rect)
			if p.x != INF and not _blocked(ctx, p):
				swings += _spawn(root, body, "swing", _at(height_fn, p),
					_rng.randf_range(0.0, 360.0), height_fn)

		# Пучки травы у зданий
		var tufts: int = mini(3, PripyatPropsData.GRASS_TUFTS_MAX - grass)
		for i in tufts:
			var p := _yard_point(rect)
			if p.x == INF or _blocked(ctx, p):
				continue
			var name := "grass_tuft" if _rng.randf() < 0.6 else "grass_tuft_02"
			grass += _spawn(root, body, name, _at(height_fn, p),
				_rng.randf_range(0.0, 360.0), height_fn)

	out["лавки"] = benches
	out["качели"] = swings
	out["трава"] = grass
	return out


## Точка «кольцом» вокруг AABB здания: сторона + доля длины + отступ
static func _yard_point(rect: Rect2) -> Vector2:
	var dist := PripyatPropsData.YARD_RING_MIN \
		+ _rng.randf_range(0.0, PripyatPropsData.YARD_RING_SPAN)
	var side := _rng.randi_range(0, 3)
	var t := _rng.randf()
	match side:
		0:
			return Vector2(lerpf(rect.position.x, rect.position.x + rect.size.x, t),
				rect.position.y - dist)
		1:
			return Vector2(lerpf(rect.position.x, rect.position.x + rect.size.x, t),
				rect.position.y + rect.size.y + dist)
		2:
			return Vector2(rect.position.x - dist,
				lerpf(rect.position.y, rect.position.y + rect.size.y, t))
		_:
			return Vector2(rect.position.x + rect.size.x + dist,
				lerpf(rect.position.y, rect.position.y + rect.size.y, t))


# ==================== ЗАБОРЫ У ГАРАЖЕЙ ====================

static func _scatter_fences(root: Node3D, body: StaticBody3D, layers: Dictionary,
		bounds: Rect2, height_fn: Callable, ctx: Ctx) -> Dictionary:
	var placed := 0
	for poly in layers.get("buildings", {}).get("polygons", []):
		if placed >= PripyatPropsData.FENCE_MAX_SECTIONS:
			break
		var kind := str(poly.get("props", {}).get("kind", ""))
		if kind != "garage" and kind != "shed":
			continue
		if _rng.randf() > 0.6:
			continue
		var rect := _ring_rect(poly.get("outer", []))
		if rect.size == Vector2.ZERO:
			continue

		# Длинная сторона: секции забора параллельно ей
		var horizontal := rect.size.x >= rect.size.y
		var yaw := 0.0 if horizontal else 90.0
		var along := rect.size.x if horizontal else rect.size.y
		var count: int = int(along / PripyatPropsData.FENCE_SECTION_LEN)
		var base := rect.position
		var i := 0
		while i < count and placed < PripyatPropsData.FENCE_MAX_SECTIONS:
			i += 1
			var t := (float(i) + 0.5) / float(count) * along
			var p: Vector2
			if horizontal:
				p = Vector2(base.x + t, base.y - PripyatPropsData.FENCE_SIDE_OFFSET)
			else:
				p = Vector2(base.x - PripyatPropsData.FENCE_SIDE_OFFSET, base.y + t)
			if not bounds.has_point(p) or _blocked(ctx, p):
				continue
			placed += _spawn(root, body, "fence_section", _at(height_fn, p), yaw, height_fn)
	return {"заборы": placed}


# ==================== ОДИНОКИЕ СУХИЕ ДЕРЕВЬЯ ====================

static func _scatter_global_trees(root: Node3D, body: StaticBody3D, bounds: Rect2,
		height_fn: Callable, ctx: Ctx) -> int:
	var placed := 0
	var existing: Array = []
	var tries := 0
	while placed < PripyatPropsData.GLOBAL_DEAD_TREES and tries < PripyatPropsData.GLOBAL_DEAD_TREES * 20:
		tries += 1
		var p := Vector2(
			_rng.randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
			_rng.randf_range(bounds.position.y, bounds.position.y + bounds.size.y))
		if _blocked(ctx, p) or _in_polys(ctx, p, ctx.green_polys):
			continue
		# Минимальный зазор между одиночными
		var too_close := false
		for q in existing:
			if p.distance_to(q) < PripyatPropsData.GLOBAL_TREE_MIN_GAP:
				too_close = true
				break
		if too_close:
			continue
		existing.append(p)
		var name: String = ["tree_dead", "tree_dead_02"][_rng.randi_range(0, 1)]
		placed += _spawn(root, body, name, _at(height_fn, p),
			_rng.randf_range(0.0, 360.0), height_fn)
	return placed


# ==================== СПАВН ОДНОГО ПРОПСА ====================

static func _at(height_fn: Callable, p: Vector2) -> Vector3:
	var y := 0.0
	if height_fn.is_valid():
		y = float(height_fn.call(p.x, p.y))
	return Vector3(p.x, y, p.y)


## Инстанс модели + при наличии габарита - бокс в общий StaticBody.
## Возвращает 1 если создан (нет модели - 0, тихо).
static func _spawn(root: Node3D, body: StaticBody3D, name: String,
		pos: Vector3, yaw_deg: float, _height_fn: Callable) -> int:
	var scene := _get_scene(name)
	if scene == null:
		return 0
	var node := scene.instantiate() as Node3D
	node.name = name
	node.position = pos
	node.rotation.y = deg_to_rad(yaw_deg)
	var s := 1.0 + _rng.randf_range(-PripyatPropsData.SCALE_JITTER,
		PripyatPropsData.SCALE_JITTER)
	node.scale = Vector3(s, s, s)
	root.add_child(node)

	var box: Vector3 = PripyatPropsData.COLLIDER_BOXES.get(name, Vector3.ZERO)
	if box != Vector3.ZERO:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box * 2.0
		cs.shape = shape
		cs.position = pos + Vector3(0.0, box.y, 0.0)
		cs.rotation.y = deg_to_rad(yaw_deg)
		body.add_child(cs)
	return 1


static func _get_scene(name: String) -> PackedScene:
	if _scenes.has(name):
		return _scenes[name]
	var path := "res://models/props/%s.glb" % name
	var ps: PackedScene = null
	if ResourceLoader.exists(path):
		ps = load(path) as PackedScene
	_scenes[name] = ps
	return ps
