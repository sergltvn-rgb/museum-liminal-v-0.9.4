extends SceneTree

const SCENE := "res://scenes/FirstMuseumMap.tscn"
const TARGET := Vector3(-3.0, 2.3, -14.65)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load(SCENE)
	if packed == null:
		push_error("cannot load scene")
		quit(1)
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var generated := instance.find_child("GeneratedMap", true, false)
	if generated == null:
		push_error("GeneratedMap not found")
		quit(1)
		return
	print("=== WALL MESHES NEAR %s ===" % [TARGET])
	_scan(generated, generated)
	print("=== TARGET ROOTS ===")
	for wanted in ["Way Out Sign (-2_6, 2_25, -14_65)", "Emergency Luminaire"]:
		var found := generated.find_child(wanted, true, false)
		if found != null:
			print("ROOT\t%s\t%s" % [generated.get_path_to(found), (found as Node3D).global_position])
			for child in found.get_children():
				if child is MeshInstance3D:
					_print_mesh(child as MeshInstance3D, generated, "CHILD")
	quit()

func _scan(node: Node, base: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var world_aabb: AABB = mesh_node.global_transform * mesh_node.get_aabb()
		var centre := world_aabb.get_center()
		if centre.distance_to(TARGET) <= 4.0 and absf(centre.z - TARGET.z) <= 1.5:
			_print_mesh(mesh_node, base, "NEAR")
	for child in node.get_children():
		_scan(child, base)

func _print_mesh(mesh_node: MeshInstance3D, base: Node, prefix: String) -> void:
	var world_aabb: AABB = mesh_node.global_transform * mesh_node.get_aabb()
	print("%s\t%s\tcenter=%s\tsize=%s\tvisible=%s\tmesh=%s" % [
		prefix, base.get_path_to(mesh_node), world_aabb.get_center(), world_aabb.size,
		mesh_node.visible, mesh_node.mesh.get_class() if mesh_node.mesh != null else "null"])
