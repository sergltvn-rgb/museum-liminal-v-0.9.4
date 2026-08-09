extends SceneTree
## Floor z-fighting probe. Инструмент, а не глаза.
##
## Сосед game/tools/check_doorways.gd, но смотрит не в проёмы, а вниз: ищет
## горизонтальные ВЕРХНИЕ грани, лежащие в одной плоскости. Именно они мерцают
## при проходе по полу.
##
## Главное отличие от дверного probe: одного AABB здесь мало. Пол атриума
## круглый: плита ротонды — диск, филёнки — кольца, разметка повёрнута на
## 22.5 градуса. Квадратная оболочка кольца радиусом 5.7 перекрывает всё в центре
## зала, и по AABB такая пара выглядит катастрофой на 100 м2, а на деле тела не
## касаются. Поэтому след каждого тела на плоскости XZ считается честно:
##   rect    — прямоугольник с поворотом вокруг Y (коробки, плиты, разметка);
##   annulus — кольцо/диск (TorusMesh, CylinderMesh, SphereMesh);
##   aabb    — тело наклонено, оценка сверху (помечается approx).
## Площадь общего следа считается сеткой SAMPLES x SAMPLES по пересечению AABB.
##
## Второе отличие: в полу работает правило INLAY_DEPTH — вставка утоплена
## на 12 см, и если верхняя грань нижнего тела оказывается ВНУТРИ объёма
## верхнего, спора за глубину нет вообще: нижнюю грань никто не рисует. Такие
## пары уходят в корзину COVERED и не шумят.
##
## Корзины:
##   FIGHT   — две видимые верхние грани на одной глубине — это и есть работа;
##   COVERED — нижняя грань утоплена в объём соседа (штатная схема вставок);
##   BURIED  — обе грани замурованы третьим телом (плинтус внутри стены).
##
## Запуск (можно с --headless, кадры здесь не снимаются):
##   Godot --path . --headless --script res://game/tools/check_floor_zfight.gd

const SCENE_PATH := "res://scenes/FirstMuseumMap.tscn"
## 3 мм: 2 мм — порог дефекта из плана, миллиметр сверху — чтобы видеть соседние
## случаи, которые поедут от любой правки рядом.
const COPLANAR_EPS := 0.003
## Ближе этого грани считаются совпавшими: утопить одну под другую уже нельзя.
const HARD_EPS := 0.0004
## Общий след меньше 200 см2 — это шов или уголок, а не мерцающее пятно.
const MIN_AREA := 0.02
## Верхние грани выше этой отметки — это уже не пол, а мебель и подоконники.
const TOP_LIMIT := 1.25
## Тело тоньше этого по Y — разметка/наклейка, помечаем в отчёте.
const DECAL_THICKNESS := 0.05
## Плоская наклейка ничего не замуровывает: тело считается плотным от 2 см.
const SOLID_MIN := 0.02
## На сколько отступаем от плоскости вверх, чтобы понять, есть ли там тело.
const PROBE_OFFSET := 0.002
const SAMPLES := 16
const MAX_PAIRS := 30
const MAX_LAYERS := 18

## Зоны обхода: имя, минимальный угол, максимальный угол (мир).
const ZONES := [
	["Central Atrium", Vector3(-15.5, -0.6, -15.5), Vector3(15.5, 1.25, 15.5)],
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("[FLOOR PROBE] cannot load %s" % SCENE_PATH)
		quit(1)
		return
	var map_root: Node = packed.instantiate()
	if map_root == null:
		push_error("[FLOOR PROBE] scene instantiated to null")
		quit(1)
		return
	root.add_child(map_root)
	await process_frame
	await process_frame
	var generated: Node = map_root.get_node_or_null("GeneratedMap")
	if generated == null:
		push_error("[FLOOR PROBE] GeneratedMap missing - build_map() did not run")
		quit(1)
		return
	var bodies: Array = []
	_collect(generated, generated, bodies)
	print("[FLOOR PROBE] visible meshes under GeneratedMap: %d" % bodies.size())
	var total := 0
	for zone in ZONES:
		total += _scan_zone(String(zone[0]), zone[1], zone[2], bodies)
	print("")
	print("[FLOOR PROBE] TOTAL FIGHTS: %d" % total)
	quit()


func _scan_zone(label: String, lo: Vector3, hi: Vector3, bodies: Array) -> int:
	var zone := AABB(lo, hi - lo)
	var near: Array = []
	var blockers: Array = []
	var kinds := {"rect": 0, "annulus": 0, "aabb": 0}
	for b in bodies:
		var box: AABB = b["aabb"]
		if not zone.intersects(box):
			continue
		# Замуровать грань может что угодно, в первую очередь стена высотой 3.4 м,
		# поэтому список загораживающих тел собирается без потолка по высоте.
		if bool(b["solid"]):
			blockers.append(b)
		if box.position.y + box.size.y > TOP_LIMIT:
			continue
		near.append(b)
		var k: String = String(b["shape"]["kind"])
		kinds[k] = int(kinds[k]) + 1
	print("")
	print("===== %s : %d meshes with a top face below %.2f m (rect %d, round %d, tilted %d)"
		% [label, near.size(), TOP_LIMIT, kinds["rect"], kinds["annulus"], kinds["aabb"]])
	_print_layers(near)
	var fights: Array = []
	var covered := 0
	var buried := 0
	var tiny := 0
	for i in range(near.size()):
		var a: Dictionary = near[i]
		var top_a: float = float(a["top"])
		for j in range(i + 1, near.size()):
			var b: Dictionary = near[j]
			var top_b: float = float(b["top"])
			var gap: float = absf(top_a - top_b)
			if gap > COPLANAR_EPS:
				continue
			var shared: Dictionary = _shared_footprint(a, b)
			var area: float = float(shared["area"])
			if area < MIN_AREA:
				if area > 0.0:
					tiny += 1
				continue
			var spots: Array = shared["points"]
			var upper: float = maxf(top_a, top_b)
			var lower: float = minf(top_a, top_b)
			# Верхняя грань замурована третьим телом — этого не видно никому.
			if _all_inside(blockers, spots, upper + PROBE_OFFSET,
					int(a["id"]), int(b["id"])):
				buried += 1
				continue
			# Нижняя грань утоплена в объём соседа — штатная схема INLAY_DEPTH.
			if gap >= HARD_EPS:
				var lift: float = minf(gap * 0.5, PROBE_OFFSET)
				var skip: int = int(a["id"]) if top_a < top_b else int(b["id"])
				if _all_inside(blockers, spots, lower + lift, skip, -1):
					covered += 1
					continue
			fights.append({
				"top": upper,
				"gap": gap,
				"area": area,
				"a": a["path"],
				"b": b["path"],
				"ha": float(a["aabb"].size.y),
				"hb": float(b["aabb"].size.y),
				"approx": String(a["shape"]["kind"]) == "aabb" \
					or String(b["shape"]["kind"]) == "aabb",
			})
	fights.sort_custom(func(x, y): return float(x["area"]) > float(y["area"]))
	print("-- FIGHT %d | covered %d | buried %d | under %.0f cm2 %d"
		% [fights.size(), covered, buried, MIN_AREA * 10000.0, tiny])
	var shown := 0
	for p in fights:
		if shown >= MAX_PAIRS:
			print("   ... %d more" % (fights.size() - shown))
			break
		print("   [Y = %.4f] gap %.2f mm, shared %.3f m2%s%s" % [
			float(p["top"]), float(p["gap"]) * 1000.0, float(p["area"]),
			_decal_note(float(p["ha"]), float(p["hb"])),
			"  [approx]" if bool(p["approx"]) else ""])
		print("      A: %s  (h %.3f)" % [p["a"], float(p["ha"])])
		print("      B: %s  (h %.3f)" % [p["b"], float(p["hb"])])
		shown += 1
	return fights.size()


func _decal_note(ha: float, hb: float) -> String:
	if ha < DECAL_THICKNESS and hb < DECAL_THICKNESS:
		return "  <- two decals"
	if ha < DECAL_THICKNESS or hb < DECAL_THICKNESS:
		return "  <- decal on slab"
	return ""


## Карта слоёв: на каких отметках Y стоят верхние грани и сколько их там.
func _print_layers(near: Array) -> void:
	var layers: Dictionary = {}
	for b in near:
		var key := snappedf(float(b["top"]), 0.001)
		var entry: Dictionary = layers.get(key, {"count": 0, "area": 0.0})
		var box: AABB = b["aabb"]
		entry["count"] = int(entry["count"]) + 1
		entry["area"] = float(entry["area"]) + box.size.x * box.size.z
		layers[key] = entry
	var rows: Array = []
	for k in layers.keys():
		rows.append([float(k), int(layers[k]["count"]), float(layers[k]["area"])])
	rows.sort_custom(func(x, y): return float(x[2]) > float(y[2]))
	print("-- top-face layers (Y, bodies, bounding footprint m2): %d distinct" % rows.size())
	var shown := 0
	for r in rows:
		if shown >= MAX_LAYERS:
			print("   ... %d more layers" % (rows.size() - shown))
			break
		print("   Y %8.4f : %4d bodies, %9.2f m2" % [r[0], r[1], r[2]])
		shown += 1


## Общий след двух тел на плоскости XZ и точки внутри него.
func _shared_footprint(a: Dictionary, b: Dictionary) -> Dictionary:
	var ab: AABB = a["aabb"]
	var bb: AABB = b["aabb"]
	var lo_x: float = maxf(ab.position.x, bb.position.x)
	var hi_x: float = minf(ab.position.x + ab.size.x, bb.position.x + bb.size.x)
	var lo_z: float = maxf(ab.position.z, bb.position.z)
	var hi_z: float = minf(ab.position.z + ab.size.z, bb.position.z + bb.size.z)
	if hi_x <= lo_x or hi_z <= lo_z:
		return {"area": 0.0, "points": []}
	var step_x: float = (hi_x - lo_x) / float(SAMPLES)
	var step_z: float = (hi_z - lo_z) / float(SAMPLES)
	var hits: Array = []
	for i in range(SAMPLES):
		var x: float = lo_x + step_x * (float(i) + 0.5)
		for j in range(SAMPLES):
			var z: float = lo_z + step_z * (float(j) + 0.5)
			if _inside_xz(a, x, z) and _inside_xz(b, x, z):
				hits.append(Vector2(x, z))
	var area: float = float(hits.size()) * step_x * step_z
	# Для проверки видимости берём пять точек вразброс, а не все двести.
	var spots: Array = []
	if not hits.is_empty():
		for f in [0.5, 0.08, 0.3, 0.7, 0.92]:
			var idx: int = clampi(int(float(hits.size() - 1) * f), 0, hits.size() - 1)
			spots.append(hits[idx])
	return {"area": area, "points": spots}


## Все ли точки на высоте y лежат внутри какого-нибудь плотного тела.
func _all_inside(near: Array, spots: Array, y: float, skip_a: int,
		skip_b: int) -> bool:
	if spots.is_empty():
		return false
	for spot in spots:
		var p: Vector2 = spot
		if not _any_body(near, p.x, y, p.y, skip_a, skip_b):
			return false
	return true


func _any_body(near: Array, x: float, y: float, z: float, skip_a: int,
		skip_b: int) -> bool:
	for k in range(near.size()):
		var e: Dictionary = near[k]
		if int(e["id"]) == skip_a or int(e["id"]) == skip_b:
			continue
		if not bool(e["solid"]):
			continue
		var box: AABB = e["aabb"]
		if y < box.position.y - 0.0015 or y > box.position.y + box.size.y + 0.0015:
			continue
		if _inside_xz(e, x, z):
			return true
	return false


func _inside_xz(e: Dictionary, x: float, z: float) -> bool:
	var s: Dictionary = e["shape"]
	var kind: String = String(s["kind"])
	if kind == "rect":
		var d := Vector2(x - float(s["cx"]), z - float(s["cz"]))
		var u: Vector2 = s["ax"]
		var v: Vector2 = s["az"]
		if u.length_squared() > 0.0 and absf(d.dot(u)) > u.length_squared():
			return false
		if v.length_squared() > 0.0 and absf(d.dot(v)) > v.length_squared():
			return false
		return true
	if kind == "annulus":
		var r: float = Vector2(x - float(s["cx"]), z - float(s["cz"])).length()
		return r >= float(s["r0"]) and r <= float(s["r1"])
	var box: AABB = e["aabb"]
	return x >= box.position.x and x <= box.position.x + box.size.x \
		and z >= box.position.z and z <= box.position.z + box.size.z


func _collect(node: Node, base: Node, out: Array) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null and mi.is_visible_in_tree():
			var box: AABB = mi.global_transform * mi.mesh.get_aabb()
			out.append({
				"id": out.size(),
				"path": str(base.get_path_to(mi)),
				"aabb": box,
				"top": box.position.y + box.size.y,
				"shape": _shape(mi),
				"solid": box.size.x >= SOLID_MIN and box.size.y >= SOLID_MIN \
					and box.size.z >= SOLID_MIN,
			})
	for child in node.get_children():
		_collect(child, base, out)


## След тела на плоскости XZ. Круглое считается круглым — тот же урок, что с
## чашей фонтана в _wall_distance: квадратная мерка придумывает дефекты.
func _shape(mi: MeshInstance3D) -> Dictionary:
	var xf := mi.global_transform
	var upright: bool = absf(xf.basis.y.normalized().dot(Vector3.UP)) > 0.999
	if not upright:
		return {"kind": "aabb"}
	var radial: float = maxf(xf.basis.x.length(), xf.basis.z.length())
	var mesh := mi.mesh
	if mesh is TorusMesh:
		var torus := mesh as TorusMesh
		return {"kind": "annulus", "cx": xf.origin.x, "cz": xf.origin.z,
			"r0": torus.inner_radius * radial,
			"r1": torus.outer_radius * radial}
	if mesh is CylinderMesh:
		var cyl := mesh as CylinderMesh
		return {"kind": "annulus", "cx": xf.origin.x, "cz": xf.origin.z,
			"r0": 0.0, "r1": maxf(cyl.top_radius, cyl.bottom_radius) * radial}
	if mesh is SphereMesh:
		var sphere := mesh as SphereMesh
		return {"kind": "annulus", "cx": xf.origin.x, "cz": xf.origin.z,
			"r0": 0.0, "r1": sphere.radius * radial}
	var local: AABB = mesh.get_aabb()
	var centre: Vector3 = xf * (local.position + local.size * 0.5)
	var ex: Vector3 = xf.basis.x * (local.size.x * 0.5)
	var ez: Vector3 = xf.basis.z * (local.size.z * 0.5)
	return {"kind": "rect", "cx": centre.x, "cz": centre.z,
		"ax": Vector2(ex.x, ex.z), "az": Vector2(ez.x, ez.z)}
