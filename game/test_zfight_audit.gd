extends SceneTree
## Z-fighting audit. Finds pairs of nearly coplanar faces whose real footprints
## overlap -- exactly the geometry that flickers when the camera moves. Looking
## for this by eye does not work; this harness walks every MeshInstance3D of the
## generated map and compares actual face planes.
##
## Two passes, because the cheap one lies:
##   1. AABB pre-filter buckets every face plane by millimetre and pairs up
##      candidates. Fast, but a bounding box says two concentric rings overlap
##      when they never touch, and says two bench slats rotated 45 degrees
##      overlap when they sit side by side.
##   2. Footprint refinement rasterises ONLY the triangles that are actually
##      coplanar with the shared plane and intersects the two cell sets. That is
##      the number worth reporting.
##
## Environment knobs (cmd syntax: set "ZF_BOX=-17,17,-17,17" && ...):
##   ZF_BOX      "xmin,xmax,zmin,zmax" filter by mesh centre, default whole map
##   ZF_EPS      max face-plane distance in metres, default 0.002
##   ZF_MIN_AREA min shared face area in square metres, default 0.05
##   ZF_LIMIT    max reported pairs per group, default 60
##   ZF_AXES     subset of "XYZ", default "XYZ"
##   ZF_OUT      report path, default res://shots/zfight/report.txt

const SETTLE_FRAMES := 30
const CELL := 0.12
const KEY_SPAN := 500000
const KEY_BIAS := 200000

var _eps := 0.002
var _min_area := 0.05
var _limit := 60
var _axes := "XYZ"
var _has_box := false
var _bx0 := 0.0
var _bx1 := 0.0
var _bz0 := 0.0
var _bz1 := 0.0
var _out_path := "res://shots/zfight/report.txt"
var _lines: Array[String] = []
var _fp_cache: Dictionary = {}

func _init() -> void:
	print("[ZFIGHT] starting")
	call_deferred("_run")

func _run() -> void:
	_read_env()
	var packed: PackedScene = load("res://scenes/FirstMuseumMap.tscn")
	if packed == null:
		push_error("[ZFIGHT] main scene failed to load")
		quit(1)
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	paused = false
	for _i in range(SETTLE_FRAMES):
		await create_timer(0.033).timeout
	var generated := instance.find_child("GeneratedMap", true, false)
	if generated == null:
		push_error("[ZFIGHT] GeneratedMap missing")
		quit(1)
		return
	var items: Array = []
	_collect(generated, generated, items)
	_log("[ZFIGHT] region meshes: %d   eps %.4f m   min area %.3f m2   cell %.2f m" % [
		items.size(), _eps, _min_area, CELL])
	if _axes.contains("Y"):
		_audit(items, 1, "Y horizontal faces (floors, slabs, markings)")
	if _axes.contains("X"):
		_audit(items, 0, "X vertical faces (facing east/west)")
	if _axes.contains("Z"):
		_audit(items, 2, "Z vertical faces (facing north/south)")
	_flush()
	quit()

func _collect(node: Node, base: Node, items: Array) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null and mi.is_visible_in_tree():
			var xform := mi.global_transform
			var box: AABB = xform * mi.mesh.get_aabb()
			var cx: float = box.position.x + box.size.x * 0.5
			var cz: float = box.position.z + box.size.z * 0.5
			var inside := true
			if _has_box:
				inside = cx >= _bx0 and cx <= _bx1 and cz >= _bz0 and cz <= _bz1
			if inside:
				items.append({
					"path": str(base.get_path_to(mi)),
					"aabb": box,
					"mesh": mi.mesh,
					"xform": xform,
				})
	for child in node.get_children():
		_collect(child, base, items)

func _audit(items: Array, axis: int, label: String) -> void:
	_fp_cache.clear()
	var buckets: Dictionary = {}
	for i in range(items.size()):
		var box: AABB = items[i]["aabb"]
		for side in range(2):
			var v: float = box.position[axis]
			if side == 1:
				v += box.size[axis]
			var key: int = int(round(v * 1000.0))
			if not buckets.has(key):
				buckets[key] = []
			var list: Array = buckets[key]
			list.append([i, v, side])
	var span: int = int(ceil(_eps * 1000.0)) + 1
	var candidates: Dictionary = {}
	for raw_key in buckets.keys():
		var key: int = int(raw_key)
		var list_a: Array = buckets[key]
		for k in range(key, key + span + 1):
			if not buckets.has(k):
				continue
			var list_b: Array = buckets[k]
			for entry_a in list_a:
				var a: Array = entry_a
				var ia: int = int(a[0])
				var box_a: AABB = items[ia]["aabb"]
				for entry_b in list_b:
					var b: Array = entry_b
					var ib: int = int(b[0])
					if ia == ib:
						continue
					var d: float = absf(float(a[1]) - float(b[1]))
					if d > _eps:
						continue
					var box_b: AABB = items[ib]["aabb"]
					if _aabb_overlap(box_a, box_b, axis) < _min_area:
						continue
					var same: bool = int(a[2]) == int(b[2])
					var tag := "S"
					if not same:
						tag = "T"
					var pk := "%d_%d_%s" % [mini(ia, ib), maxi(ia, ib), tag]
					if candidates.has(pk):
						continue
					candidates[pk] = [ia, ib, d, same, float(a[1]), float(b[1])]
	var same_rows: Array = []
	var stack_rows: Array = []
	for value in candidates.values():
		var row: Array = value
		var ia: int = int(row[0])
		var ib: int = int(row[1])
		var plane_a: float = float(row[4])
		var plane_b: float = float(row[5])
		var cells_a: Dictionary = _footprint(ia, axis, plane_a, items)
		var cells_b: Dictionary = _footprint(ib, axis, plane_b, items)
		var shared := 0
		var small: Dictionary = cells_a
		var large: Dictionary = cells_b
		if cells_b.size() < cells_a.size():
			small = cells_b
			large = cells_a
		for cell in small.keys():
			if large.has(cell):
				shared += 1
		var area: float = float(shared) * CELL * CELL
		if area < _min_area:
			continue
		var out_row: Array = [ia, ib, float(row[2]), area, bool(row[3]), plane_a]
		if bool(row[3]):
			same_rows.append(out_row)
		else:
			stack_rows.append(out_row)
	same_rows.sort_custom(_by_area)
	stack_rows.sort_custom(_by_area)
	_log("")
	_log("=== %s ===" % label)
	_log("candidates %d -> real co-facing %d, real stacked %d" % [
		candidates.size(), same_rows.size(), stack_rows.size()])
	_dump("CO-FACING -- both faces point the same way, THIS is the flicker", same_rows, items)
	_dump("STACKED -- opposite faces touching, usually hidden", stack_rows, items)

func _by_area(x: Array, y: Array) -> bool:
	return float(x[3]) > float(y[3])

func _dump(title: String, rows: Array, items: Array) -> void:
	_log("-- %s (%d) --" % [title, rows.size()])
	var shown := 0
	for value in rows:
		var row: Array = value
		if shown >= _limit:
			_log("   ... %d more" % (rows.size() - shown))
			break
		var ia: int = int(row[0])
		var ib: int = int(row[1])
		_log("   gap %.4f  area %8.2f  plane %9.4f   %s   <>   %s" % [
			float(row[2]), float(row[3]), float(row[5]),
			str(items[ia]["path"]), str(items[ib]["path"])])
		shown += 1

## Cell set of the triangles that really lie on `plane`. Cached per mesh+plane.
func _footprint(index: int, axis: int, plane: float, items: Array) -> Dictionary:
	var key := "%d|%d|%d" % [index, axis, int(round(plane * 1000.0))]
	if _fp_cache.has(key):
		return _fp_cache[key]
	var cells: Dictionary = {}
	var mesh: Mesh = items[index]["mesh"]
	var xform: Transform3D = items[index]["xform"]
	var faces: PackedVector3Array = mesh.get_faces()
	var u_axis := 0
	var v_axis := 2
	if axis == 0:
		u_axis = 1
		v_axis = 2
	elif axis == 2:
		u_axis = 0
		v_axis = 1
	var i := 0
	while i + 2 < faces.size():
		var p0: Vector3 = xform * faces[i]
		var p1: Vector3 = xform * faces[i + 1]
		var p2: Vector3 = xform * faces[i + 2]
		i += 3
		if absf(p0[axis] - plane) > _eps:
			continue
		if absf(p1[axis] - plane) > _eps:
			continue
		if absf(p2[axis] - plane) > _eps:
			continue
		_raster(Vector2(p0[u_axis], p0[v_axis]), Vector2(p1[u_axis], p1[v_axis]),
			Vector2(p2[u_axis], p2[v_axis]), cells)
	_fp_cache[key] = cells
	return cells

## Supercover rasterisation: cell centres inside the triangle plus every cell
## the three edges walk through, so a 5 cm joint does not vanish between cells.
func _raster(a: Vector2, b: Vector2, c: Vector2, cells: Dictionary) -> void:
	_walk(a, b, cells)
	_walk(b, c, cells)
	_walk(c, a, cells)
	var min_u: float = minf(a.x, minf(b.x, c.x))
	var max_u: float = maxf(a.x, maxf(b.x, c.x))
	var min_v: float = minf(a.y, minf(b.y, c.y))
	var max_v: float = maxf(a.y, maxf(b.y, c.y))
	var iu0 := int(floor(min_u / CELL))
	var iu1 := int(floor(max_u / CELL))
	var iv0 := int(floor(min_v / CELL))
	var iv1 := int(floor(max_v / CELL))
	if (iu1 - iu0 + 1) * (iv1 - iv0 + 1) > 400000:
		return
	for iu in range(iu0, iu1 + 1):
		for iv in range(iv0, iv1 + 1):
			var centre := Vector2((float(iu) + 0.5) * CELL, (float(iv) + 0.5) * CELL)
			if _inside(a, b, c, centre):
				cells[_cell_key(iu, iv)] = true

func _walk(from: Vector2, to: Vector2, cells: Dictionary) -> void:
	var delta := to - from
	var steps: int = int(ceil(delta.length() / (CELL * 0.4))) + 1
	if steps > 20000:
		steps = 20000
	for s in range(steps + 1):
		var point := from + delta * (float(s) / float(steps))
		cells[_cell_key(int(floor(point.x / CELL)), int(floor(point.y / CELL)))] = true

func _cell_key(iu: int, iv: int) -> int:
	return (iu + KEY_BIAS) * KEY_SPAN + (iv + KEY_BIAS)

func _inside(a: Vector2, b: Vector2, c: Vector2, p: Vector2) -> bool:
	var d1 := (p - b).cross(a - b)
	var d2 := (p - c).cross(b - c)
	var d3 := (p - a).cross(c - a)
	var has_neg: bool = d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var has_pos: bool = d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (has_neg and has_pos)

func _aabb_overlap(a: AABB, b: AABB, axis: int) -> float:
	var total := 1.0
	for ax in range(3):
		if ax == axis:
			continue
		var lo: float = maxf(a.position[ax], b.position[ax])
		var hi: float = minf(a.position[ax] + a.size[ax], b.position[ax] + b.size[ax])
		if hi <= lo:
			return 0.0
		total *= (hi - lo)
	return total

func _read_env() -> void:
	var raw := OS.get_environment("ZF_EPS")
	if not raw.is_empty():
		_eps = float(raw)
	raw = OS.get_environment("ZF_MIN_AREA")
	if not raw.is_empty():
		_min_area = float(raw)
	raw = OS.get_environment("ZF_LIMIT")
	if not raw.is_empty():
		_limit = int(raw)
	raw = OS.get_environment("ZF_AXES")
	if not raw.is_empty():
		_axes = raw.to_upper()
	raw = OS.get_environment("ZF_OUT")
	if not raw.is_empty():
		_out_path = raw
	raw = OS.get_environment("ZF_BOX")
	if not raw.is_empty():
		var parts := raw.split(",")
		if parts.size() == 4:
			_bx0 = float(parts[0])
			_bx1 = float(parts[1])
			_bz0 = float(parts[2])
			_bz1 = float(parts[3])
			_has_box = true

func _log(line: String) -> void:
	_lines.append(line)
	print(line)

func _flush() -> void:
	var abs_path := ProjectSettings.globalize_path(_out_path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var file := FileAccess.open(_out_path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_lines) + "\n")
		file.close()
	print("[ZFIGHT] report -> %s (%d lines)" % [_out_path, _lines.size()])
