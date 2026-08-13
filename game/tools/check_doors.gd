extends SceneTree
## Проба распашных дверей. Инструмент, а не глаза.
##
## Строит карту тем же способом, что test_map_verification (instantiate + два
## кадра), находит узлы "Door Swing ..." и меряет то, чего не видно на
## скриншоте:
##   MODEL — служебные створки стальные, планетарий повторяет язык входа,
##           а главный вход использует свою широкую парадную модель;
##   BODY  — петля это RigidBody3D с ОДНИМ боксом и БЕЗ StaticBody3D внутри:
##           статика поперёк проёма запекается в навмеш как стена;
##   OPEN  — в построенной позе коллайдеры створок стоят вне ходового
##           просвета, а меш не залезает в него глубже ручки;
##   SHUT  — закрытая пара перекрывает проём и не залезает в косяки.
##
## Ход анимации гоняем детерминированно: дёргаем _physics_process(1/60)
## руками, а не ждём реального времени. Иначе прогон стоит секунды и врёт при
## разной загрузке машины.
##
## Запуск (можно с --headless, кадры здесь не снимаются):
##   Godot --path . --headless --script res://game/tools/check_doors.gd

const SCENE_PATH := "res://scenes/FirstMuseumMap.tscn"
const STEP := 1.0 / 60.0
const MAX_STEPS := 600
## Полупролёт проёма (DOOR_GAP 1.8 / 2) и внутренняя щека косяка (JAMB_HALF).
const HALF_GAP := 0.9
const JAMB_HALF := 0.92
## Открытую створку меряем дважды, потому что торчит у неё разное.
##
## OPEN_CLEAR_BODY — коллайдер, единственное, обо что игрок действительно
## ударится. Порог считается, а не подбирается: полотно подвешено ЗА
## КРОМКУ, так что при повороте его дальний угол неизбежно уходит за ось
## петли на полтолщины: 0.030 * cos(104° - 90°) = 29 мм. Так устроена любая
## распашная дверь; проход от этого становится 1.74 м вместо 1.80 м при
## диаметре игрока 0.70 м. Ставим 40 мм запаса: створка, повёрнутая не в ту
## сторону или вовсе не открытая, даст здесь ноль и всё равно упадёт.
##
## OPEN_CLEAR_MESH — вся геометрия. У распахнутой двери в проём смотрит РУЧКА:
## рычаг отходит от полотна на 45 мм, и при повороте его выносит поперёк
## прохода. Это неустранимо: при 90° ручка торчала бы глубже, а распахнуть
## створку дальше 104° не даёт стена. Примитив, который мы заменили, залезал
## в просвет на 82 мм, модель — на 76 мм. Порог стоит так, чтобы ловить не
## ручку, а случай, когда в проходе окажется само полотно.
const OPEN_CLEAR_BODY := 0.86
const OPEN_CLEAR_MESH := 0.78
## Допуски закрытой пары: автоматические полотна сохраняют прежний 80 мм
## технический стык, но у парадной музейной пары допускается не более 12 мм.
const SHUT_GAP_MAX := 0.09
const MANUAL_SHUT_GAP_MAX := 0.012
const JAMB_OVERRUN_MAX := 0.005
## Низ полотна и низ перемычки (WALL_HEIGHT - 0.7).
const FLOOR_CLEAR_MIN := 0.02
const HEADER_Y := 2.7


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("[DOOR PROBE] cannot load %s" % SCENE_PATH)
		quit(1)
		return
	var map_root: Node = packed.instantiate()
	if map_root == null:
		push_error("[DOOR PROBE] scene instantiated to null")
		quit(1)
		return
	root.add_child(map_root)
	await process_frame
	await process_frame
	var generated: Node = map_root.get_node_or_null("GeneratedMap")
	if generated == null:
		push_error("[DOOR PROBE] GeneratedMap missing - build_map() did not run")
		quit(1)
		return
	var swings: Array[Node] = []
	_collect_swings(generated, swings)
	var tally := {"static": 0, "rigid": 0}
	_count_bodies(generated, tally)
	print("[DOORS] swings %d | map StaticBody3D %d | map RigidBody3D %d"
		% [swings.size(), tally["static"], tally["rigid"]])
	var problems := 0
	for swing in swings:
		problems += _audit(swing)
	if problems == 0:
		print("[DOORS] OK")
	else:
		print("[DOORS] %d PROBLEM(S)" % problems)
	quit(0 if problems == 0 else 1)


func _audit(swing: Node) -> int:
	var problems := 0
	var notes: Array[String] = []
	var pivot := swing as Node3D
	var hinges: Array[Node3D] = []
	for child in swing.get_children():
		if String(child.name).begins_with("Door Hinge"):
			hinges.append(child as Node3D)
	var label := String(swing.name)
	if pivot == null or hinges.size() != 2:
		print("[DOORS] %s: %d hinges (expected 2)" % [label, hinges.size()])
		return 1
	var centre := pivot.global_position
	var sep := hinges[1].global_position - hinges[0].global_position
	var wall_axis := 0 if absf(sep.x) >= absf(sep.z) else 2
	var thru_axis := 2 if wall_axis == 0 else 0
	var half_gap := sep.length() * 0.5
	var open_clear_body := half_gap - 0.04
	var open_clear_mesh := half_gap - 0.12
	var jamb_half := half_gap + 0.02
	var manual := swing.has_method("is_interaction_required") \
		and bool(swing.call("is_interaction_required"))
	var header_y := 3.05 if manual else HEADER_Y
	var model_name := str(swing.get_meta("door_model", ""))
	var expected_model := "lp_museum_door_leaf" if manual else \
		("lp_gallery_door_leaf" if centre.distance_to(Vector3(0, 0, -33)) < 0.05 \
		else "lp_service_door_leaf")
	if model_name != expected_model:
		notes.append("uses %s, expected %s" % [model_name, expected_model])
		problems += 1
	if manual:
		if not bool(swing.call("is_closed")):
			notes.append("manual entrance was not built shut")
			problems += 1
		if swing.get_node_or_null("Door Sensor") != null:
			notes.append("manual entrance still has an automatic sensor")
			problems += 1
		_drive(swing, true)

	var kids: Array[String] = []
	for c in hinges[0].get_children():
		kids.append("%s(%s)" % [String(c.name), c.get_class()])

	for i in range(2):
		var hinge := hinges[i]
		if not (hinge is RigidBody3D):
			notes.append("hinge %d is %s, not RigidBody3D" % [i, hinge.get_class()])
			problems += 1
		else:
			var body := hinge as RigidBody3D
			if not body.freeze or body.freeze_mode != RigidBody3D.FREEZE_MODE_KINEMATIC:
				notes.append("hinge %d is not frozen kinematic" % i)
				problems += 1
		if hinge.get_node_or_null("Door Leaf %d" % i) != null:
			notes.append("leaf %d fell back to the primitive panel" % i)
			problems += 1
		var statics := 0
		var shapes := 0
		var meshes := 0
		var stack: Array[Node] = [hinge]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c in n.get_children():
				stack.append(c)
			if n is StaticBody3D:
				statics += 1
			if n is CollisionShape3D:
				shapes += 1
			if n is MeshInstance3D:
				meshes += 1
		if statics > 0:
			notes.append("hinge %d carries %d StaticBody3D" % [i, statics])
			problems += 1
		if shapes != 1:
			notes.append("hinge %d has %d collision shapes (expected 1)" % [i, shapes])
			problems += 1
		if meshes < 1:
			notes.append("hinge %d has no mesh at all" % i)
			problems += 1

	# --- поза, в которой карта построена: обе створки должны стоять вне просвета
	var open_clear := [0.0, 0.0]
	var open_body := [0.0, 0.0]
	var open_depth := [0.0, 0.0]
	for i in range(2):
		var box := _leaf_aabb(hinges[i])
		var clear := _inner_clearance(box, centre, wall_axis)
		var solid := _inner_clearance(_body_aabb(hinges[i]), centre, wall_axis)
		open_clear[i] = clear
		open_body[i] = solid
		open_depth[i] = box.size[thru_axis]
		if solid < open_clear_body:
			notes.append("open leaf %d blocks the gap: collider %.3f m off the axis, need %.2f"
				% [i, solid, open_clear_body])
			problems += 1
		if clear < open_clear_mesh:
			notes.append("open leaf %d hangs %.3f m into the gap, need %.2f"
				% [i, clear, open_clear_mesh])
			problems += 1

	# --- закрываем
	var shut_steps := _drive(swing, false)
	var inner := [0.0, 0.0]
	var outer := [0.0, 0.0]
	var thickness := 0.0
	var top := -9.0
	var bottom := 9.0
	for i in range(2):
		var box := _leaf_aabb(hinges[i])
		var lo: float = box.position[wall_axis] - centre[wall_axis]
		var hi: float = lo + box.size[wall_axis]
		inner[i] = minf(absf(lo), absf(hi))
		outer[i] = maxf(absf(lo), absf(hi))
		thickness = maxf(thickness, box.size[thru_axis])
		top = maxf(top, box.position.y + box.size.y)
		bottom = minf(bottom, box.position.y)
	var centre_gap: float = float(inner[0]) + float(inner[1])
	var overrun: float = maxf(float(outer[0]), float(outer[1])) - jamb_half
	var shut_gap_max := MANUAL_SHUT_GAP_MAX if manual else SHUT_GAP_MAX
	if centre_gap > shut_gap_max:
		notes.append("shut pair leaves a %.3f m gap down the middle (max %.3f)"
			% [centre_gap, shut_gap_max])
		problems += 1
	if overrun > JAMB_OVERRUN_MAX:
		notes.append("shut leaf runs %.3f m into the jamb" % overrun)
		problems += 1
	if bottom < FLOOR_CLEAR_MIN:
		notes.append("shut leaf bottom at %.3f m sits in the threshold" % bottom)
		problems += 1
	if top > header_y:
		notes.append("shut leaf top at %.3f m fouls the header" % top)
		problems += 1

	# --- и открываем обратно: поза обязана вернуться в ту, что построена
	var open_steps := _drive(swing, true)
	var back := [0.0, 0.0]
	for i in range(2):
		back[i] = _inner_clearance(_leaf_aabb(hinges[i]), centre, wall_axis)
		if absf(float(back[i]) - float(open_clear[i])) > 0.001:
			notes.append("leaf %d came back to %.3f m, not the built %.3f m"
				% [i, back[i], open_clear[i]])
			problems += 1

	print("[DOORS] %s | wall axis %s | %s | gap %.2f" % [
		label, "X" if wall_axis == 0 else "Z",
		"manual" if manual else "automatic", half_gap * 2.0])
	print("        hinge 0: %s" % ", ".join(kids))
	print("        built open  body %.3f / %.3f  mesh %.3f / %.3f  reach into room %.2f / %.2f m"
		% [open_body[0], open_body[1], open_clear[0], open_clear[1],
			open_depth[0], open_depth[1]])
	print("        shut  %3d steps (%.2f s)  centre gap %.3f  jamb %+.3f  slab %.3f thick  y %.3f..%.3f"
		% [shut_steps, float(shut_steps) * STEP, centre_gap, overrun, thickness, bottom, top])
	print("        open  %3d steps (%.2f s)  clear %.3f / %.3f m"
		% [open_steps, float(open_steps) * STEP, back[0], back[1]])
	for note in notes:
		print("        !! %s" % note)
	return problems


## Гоняем дверь до упора без реального времени. _hold обнуляем, иначе первые
## пять секунд после постройки дверь по замыслу держит открытую позу.
func _drive(swing: Node, want_open: bool) -> int:
	if swing.has_method("is_interaction_required") \
			and bool(swing.call("is_interaction_required")):
		swing.call("set_open", want_open)
	else:
		swing.set("_inside", 1 if want_open else 0)
		swing.set("_hold", 0.0)
	var steps := 0
	while steps < MAX_STEPS:
		swing.call("_physics_process", STEP)
		steps += 1
		if not bool(swing.call("is_swinging")):
			break
	return steps


## Насколько близко тело подходит к осевой линии проёма. Ноль означает, что
## оно эту линию пересекает, то есть стоит в проходе.
func _inner_clearance(box: AABB, centre: Vector3, axis: int) -> float:
	var lo: float = box.position[axis] - centre[axis]
	var hi: float = lo + box.size[axis]
	if lo > 0.0:
		return lo
	if hi < 0.0:
		return -hi
	return 0.0


func _leaf_aabb(node: Node3D) -> AABB:
	var out := AABB()
	var started := false
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.visible:
			continue
		var world: AABB = mi.global_transform * mi.mesh.get_aabb()
		if started:
			out = out.merge(world)
		else:
			out = world
			started = true
	return out


## То же самое, но по коллайдерам: только они останавливают игрока, а в меш
## входят ещё ручки и петли, которые ничего не держат.
func _body_aabb(node: Node3D) -> AABB:
	var out := AABB()
	var started := false
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var cs := n as CollisionShape3D
		if cs == null or cs.disabled or cs.shape == null:
			continue
		var box := cs.shape as BoxShape3D
		if box == null:
			continue
		var world: AABB = cs.global_transform * AABB(-box.size * 0.5, box.size)
		if started:
			out = out.merge(world)
		else:
			out = world
			started = true
	return out


func _collect_swings(node: Node, out: Array[Node]) -> void:
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if String(n.name).begins_with("Door Swing"):
			out.append(n)


func _count_bodies(node: Node, out: Dictionary) -> void:
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is StaticBody3D:
			out["static"] = int(out["static"]) + 1
		elif n is RigidBody3D:
			out["rigid"] = int(out["rigid"]) + 1
