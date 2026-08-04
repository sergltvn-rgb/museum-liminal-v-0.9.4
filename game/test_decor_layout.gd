extends SceneTree

## Layout regression for wall decor that can be physically separate yet still
## hide safety fittings when their wall-plane silhouettes overlap.
const SCENE := "res://scenes/FirstMuseumMap.tscn"

var _failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load(SCENE)
	if packed == null:
		_fail("cannot load %s" % SCENE)
		quit(1)
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var generated := instance.find_child("GeneratedMap", true, false)
	if generated == null:
		_fail("GeneratedMap not found")
		quit(1)
		return

	var banner := generated.find_child("Wing Banner NW", true, false)
	var sign := generated.find_child("Way Out Sign (-2_6, 2_25, -14_65)", true, false)
	var emergency := _find_node_near(generated, "Emergency Luminaire",
		Vector3(-3.5, 2.6, -14.65))
	_require_clear_wall_projection(banner, sign, "NW banner / way-out sign", "x")
	_require_clear_wall_projection(banner, emergency, "NW banner / emergency light", "x")

	instance.queue_free()
	await process_frame
	if _failures == 0:
		print("RESULT: PASS")
		quit(0)
	else:
		print("RESULT: FAIL (%d failure(s))" % _failures)
		quit(1)

func _find_node_near(base: Node, node_name: String, target: Vector3) -> Node:
	var best: Node = null
	var best_distance := INF
	for child in base.find_children(node_name, "Node3D", true, false):
		var distance := (child as Node3D).global_position.distance_to(target)
		if distance < best_distance:
			best = child
			best_distance = distance
	return best

func _require_clear_wall_projection(a: Node, b: Node, label: String, axis: String) -> void:
	if a == null or b == null:
		_fail("%s node missing" % label)
		return
	var rect_a := _wall_rect(a, axis)
	var rect_b := _wall_rect(b, axis)
	if rect_a.intersects(rect_b):
		_fail("%s overlaps in wall projection: %s vs %s" % [label, rect_a, rect_b])
	else:
		print("[OK] %s is visually clear" % label)

func _wall_rect(node: Node, axis: String) -> Rect2:
	var world_box := _combined_aabb(node)
	if axis == "z":
		return Rect2(Vector2(world_box.position.z, world_box.position.y),
			Vector2(world_box.size.z, world_box.size.y))
	return Rect2(Vector2(world_box.position.x, world_box.position.y),
		Vector2(world_box.size.x, world_box.size.y))

func _combined_aabb(node: Node) -> AABB:
	var found := false
	var combined := AABB()
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		combined = mesh_node.global_transform * mesh_node.get_aabb()
		found = true
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := mesh as MeshInstance3D
		var world_box: AABB = mesh_node.global_transform * mesh_node.get_aabb()
		combined = combined.merge(world_box) if found else world_box
		found = true
	return combined

func _fail(message: String) -> void:
	_failures += 1
	push_error(message)
	print("[FAIL] %s" % message)
