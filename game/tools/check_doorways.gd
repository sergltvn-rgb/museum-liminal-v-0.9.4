extends SceneTree
## Doorway z-fighting probe. Инструмент, а не глаза.
##
## Строит карту тем же способом, что test_map_verification (instantiate + два
## кадра), собирает мировые AABB всех видимых MeshInstance3D вокруг каждого
## проёма и ищет пары, у которых ОДНОИМЁННЫЕ грани (обе max либо обе min по
## одной оси) лежат в одной плоскости с зазором меньше COPLANAR_EPS, а по двум
## другим осям тела перекрываются. Это ровно то условие, при котором поверхность
## мерцает при вращении камеры.
##
## Пары «max к min» (тела просто стоят спина к спине) не считаются: такие грани
## смотрят в разные стороны и отсекаются backface culling.
##
## Найденное делится на четыре корзины, иначе шум топит дефекты:
##   VISIBLE — грани могут попасть в кадр, это и есть работа;
##   BURIED  — снаружи от пары стоит третье тело (стена, косяк, перемычка):
##             грани замурованы и не рисуются вообще;
##   FLOOR   — нижние грани на уровне пола: смотрят вниз, под плиту;
##   ROTATED — хотя бы одно тело повёрнуто, AABB даёт только оценку сверху
##             (реальные грани не параллельны) — смотреть глазами.
##
## Запуск (можно с --headless, кадры здесь не снимаются):
##   Godot --path . --headless --script res://game/tools/check_doorways.gd

const SCENE_PATH := "res://scenes/FirstMuseumMap.tscn"
## 2 мм — порог из плана: ближе этого две грани уже дерутся за глубину.
const COPLANAR_EPS := 0.002
## Общая грань меньше 2 см по любой из осей — это шов, а не мерцающее пятно.
const MIN_OVERLAP := 0.02
## Полупролёт зоны вокруг центра проёма (DOOR_GAP 1.8 плюс косяки и наличник).
const REACH := 1.9
const CEILING := 3.9
## Нижние грани не выше этой отметки лежат на плите пола и не видны.
const FLOOR_LEVEL := 0.021
## На сколько отступаем от плоскости наружу, чтобы понять, есть ли там тело.
const PROBE_OFFSET := 0.004
const MAX_PAIRS := 24

## Те же одиннадцать центров, что build_map() передаёт в _add_door_frame().
const DOORWAYS := [
	[Vector3(0, 0, 15), "x", "Atrium-Entrance"],
	[Vector3(-15, 0, 0), "z", "Atrium-Office"],
	[Vector3(15, 0, 0), "z", "Atrium-Gravity"],
	[Vector3(0, 0, -15), "x", "Atrium-Time"],
	[Vector3(-25, 0, 7), "x", "Office-Storage"],
	[Vector3(-25, 0, -7), "x", "Office-Archive"],
	[Vector3(0, 0, -33), "x", "Time-Planetarium"],
	[Vector3(-25, 0, 17), "x", "Storage-RestorationLab"],
	[Vector3(0, 0, 35), "x", "Entrance-Street"],
	[Vector3(13, 0, -24), "z", "Time-SpaceC"],
	[Vector3(41, 0, 0), "z", "Gravity-MassD"],
]

const AXIS_NAME := ["X", "Y", "Z"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("[DOORWAY PROBE] cannot load %s" % SCENE_PATH)
		quit(1)
		return
	var map_root: Node = packed.instantiate()
	if map_root == null:
		push_error("[DOORWAY PROBE] scene instantiated to null")
		quit(1)
		return
	root.add_child(map_root)
	await process_frame
	await process_frame
	var generated: Node = map_root.get_node_or_null("GeneratedMap")
	if generated == null:
		push_error("[DOORWAY PROBE] GeneratedMap missing - build_map() did not run")
		quit(1)
		return
	var boxes: Array = []
	_collect(generated, generated, boxes)
	print("[DOORWAY PROBE] visible meshes under GeneratedMap: %d" % boxes.size())
	var total_visible := 0
	var total_buried := 0
	var total_floor := 0
	var total_rot := 0
	for entry in DOORWAYS:
		var centre: Vector3 = entry[0]
		var axis: String = entry[1]
		var label: String = entry[2]
		var probe := AABB(
			Vector3(centre.x - REACH, -0.25, centre.z - REACH),
			Vector3(REACH * 2.0, CEILING, REACH * 2.0))
		var near: Array = []
		for b in boxes:
			if probe.intersects(b["aabb"]):
				near.append(b)
		var pairs: Array = []
		var buried := 0
		var floor_hidden := 0
		var rotated := 0
		for i in range(near.size()):
			for j in range(i + 1, near.size()):
				var hit: Dictionary = _coplanar(near[i]["aabb"], near[j]["aabb"])
				if hit.is_empty():
					continue
				if int(hit["axis"]) == 1 and String(hit["face"]) == "min" \
						and float(hit["plane"]) <= FLOOR_LEVEL:
					floor_hidden += 1
					continue
				if not bool(near[i]["aligned"]) or not bool(near[j]["aligned"]):
					rotated += 1
					continue
				if _face_buried(near, i, j, hit):
					buried += 1
					continue
				hit["a"] = near[i]["path"]
				hit["b"] = near[j]["path"]
				pairs.append(hit)
		pairs.sort_custom(func(x, y): return float(x["area"]) > float(y["area"]))
		total_visible += pairs.size()
		total_buried += buried
		total_floor += floor_hidden
		total_rot += rotated
		print("")
		print("== %s at %s axis %s : meshes %d, VISIBLE %d (buried %d, floor %d, rotated %d)"
			% [label, centre, axis, near.size(), pairs.size(), buried, floor_hidden, rotated])
		var shown := 0
		for p in pairs:
			if shown >= MAX_PAIRS:
				print("   ... %d more visible pairs" % (pairs.size() - shown))
				break
			print("   [%s %s = %.4f] gap %.2f mm, shared %.3f m2" % [
				AXIS_NAME[int(p["axis"])], String(p["face"]), float(p["plane"]),
				float(p["gap"]) * 1000.0, float(p["area"])])
			print("      A: %s" % p["a"])
			print("      B: %s" % p["b"])
			shown += 1
	print("")
	print("[DOORWAY PROBE] VISIBLE %d | buried %d | floor %d | rotated %d"
		% [total_visible, total_buried, total_floor, total_rot])
	quit()


func _collect(node: Node, base: Node, out: Array) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null and mi.is_visible_in_tree():
			out.append({
				"path": str(base.get_path_to(mi)),
				"aabb": mi.global_transform * mi.mesh.get_aabb(),
				"aligned": _is_axis_aligned(mi.global_transform.basis),
			})
	for child in node.get_children():
		_collect(child, base, out)


## У повёрнутого тела грани не параллельны осям, и совпадение AABB ещё не
## значит совпадения плоскостей — такие пары считаются отдельно.
func _is_axis_aligned(basis: Basis) -> bool:
	for v in [basis.x, basis.y, basis.z]:
		var nonzero := 0
		for k in range(3):
			if absf(v[k]) > 0.001:
				nonzero += 1
		if nonzero != 1:
			return false
	return true


## Две совпавшие грани смотрят в одну сторону. Если с той стороны стоит третье
## тело (стена, косяк, перемычка), спор за глубину никто не увидит.
func _face_buried(near: Array, i: int, j: int, hit: Dictionary) -> bool:
	var ax: int = int(hit["axis"])
	var u: int = (ax + 1) % 3
	var v: int = (ax + 2) % 3
	var a: AABB = near[i]["aabb"]
	var b: AABB = near[j]["aabb"]
	var lo_u: float = maxf(a.position[u], b.position[u])
	var hi_u: float = minf(a.position[u] + a.size[u], b.position[u] + b.size[u])
	var lo_v: float = maxf(a.position[v], b.position[v])
	var hi_v: float = minf(a.position[v] + a.size[v], b.position[v] + b.size[v])
	var dir := 1.0 if String(hit["face"]) == "max" else -1.0
	var outside: float = float(hit["plane"]) + dir * PROBE_OFFSET
	var spots := [
		[0.5, 0.5], [0.12, 0.12], [0.88, 0.12], [0.12, 0.88], [0.88, 0.88],
	]
	for spot in spots:
		var coords := [0.0, 0.0, 0.0]
		coords[ax] = outside
		coords[u] = lerpf(lo_u, hi_u, float(spot[0]))
		coords[v] = lerpf(lo_v, hi_v, float(spot[1]))
		var point := Vector3(coords[0], coords[1], coords[2])
		if not _inside_third_body(near, i, j, point):
			return false
	return true


func _inside_third_body(near: Array, i: int, j: int, point: Vector3) -> bool:
	for k in range(near.size()):
		if k == i or k == j:
			continue
		if not bool(near[k]["aligned"]):
			continue
		var c: AABB = near[k]["aabb"]
		# Плоские наклейки и таблички ничего не замуровывают.
		if c.size.x < 0.02 or c.size.y < 0.02 or c.size.z < 0.02:
			continue
		if c.grow(0.0015).has_point(point):
			return true
	return false


## Возвращает самую крупную пару одноимённых компланарных граней или {}.
func _coplanar(a: AABB, b: AABB) -> Dictionary:
	var best: Dictionary = {}
	for axis in range(3):
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		var ov_u := _overlap(a, b, u)
		var ov_v := _overlap(a, b, v)
		if ov_u < MIN_OVERLAP or ov_v < MIN_OVERLAP:
			continue
		var a_min: float = a.position[axis]
		var a_max: float = a.position[axis] + a.size[axis]
		var b_min: float = b.position[axis]
		var b_max: float = b.position[axis] + b.size[axis]
		# Тела должны реально пересекаться по этой оси, иначе общая плоскость —
		# просто совпадение двух стоящих врозь коробок.
		if minf(a_max, b_max) - maxf(a_min, b_min) <= 0.0:
			continue
		var checks := [
			[absf(a_max - b_max), a_max, "max"],
			[absf(a_min - b_min), a_min, "min"],
		]
		for c in checks:
			var gap: float = c[0]
			if gap > COPLANAR_EPS:
				continue
			var area: float = ov_u * ov_v
			if best.is_empty() or area > float(best["area"]):
				best = {
					"axis": axis,
					"plane": float(c[1]),
					"gap": gap,
					"area": area,
					"face": String(c[2]),
				}
	return best


func _overlap(a: AABB, b: AABB, axis: int) -> float:
	var lo: float = maxf(a.position[axis], b.position[axis])
	var hi: float = minf(a.position[axis] + a.size[axis], b.position[axis] + b.size[axis])
	return hi - lo
