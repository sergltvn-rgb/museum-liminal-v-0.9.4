extends SceneTree

## Structural regression test for decor pieces whose readability depends on
## silhouette and surface breakup, not just on existing in the scene tree.
const ArchiveProps := preload("res://game/props/ArchiveProps.gd")

var _failures := 0


func _init() -> void:
	print("==================================================")
	print("DECOR QUALITY REGRESSION TEST")
	print("==================================================")

	var host := Node3D.new()
	root.add_child(host)

	var stacks := ArchiveProps.build_rolling_stacks(host, Vector3.ZERO, 5, 3, 0.0)
	_require_child(stacks, "Carriage 0 Outer Frame Top")
	_require_child(stacks, "Carriage 4 Outer Frame Top")
	_require_child(stacks, "Carriage 0 Drive Wheel")
	_require_child(stacks, "Carriage 4 Drive Wheel")

	var exhibit := ArchiveProps.build_shrouded_exhibit(
		host, Vector3(10, 0, 0), 0.0, "")
	_require_child(exhibit, "Sheet Front Drape")
	_require_child(exhibit, "Sheet Back Drape")
	_require_child(exhibit, "Sheet Left Drape")
	_require_child(exhibit, "Sheet Right Drape")
	_require_child(exhibit, "Sheet Crown")
	_require_child(exhibit, "Sheet Front Fold Left")
	_require_child(exhibit, "Sheet Front Fold Right")
	_require_mesh_class(exhibit, "Sheet Front Drape", "ArrayMesh")
	_require_marker(exhibit, "Sheet Crown")

	var covered := ArchiveProps.build_shrouded_lump(
		host, Vector3(14, 0, 0), 0.0, 1.10)
	_require_child(covered, "Cover Front Drape")
	_require_child(covered, "Cover Back Drape")
	_require_child(covered, "Cover Side Left")
	_require_child(covered, "Cover Side Right")
	_require_child(covered, "Cover Front Fold")
	_require_mesh_class(covered, "Cover Front Drape", "ArrayMesh")

	host.free()
	if _failures == 0:
		print("RESULT: PASS")
		quit(0)
	else:
		print("RESULT: FAIL (%d failure(s))" % _failures)
		quit(1)


func _require_child(parent: Node, child_name: String) -> void:
	if parent.find_child(child_name, true, false) == null:
		_fail("%s is missing %s" % [parent.name, child_name])
	else:
		print("[OK] %s / %s" % [parent.name, child_name])


func _require_marker(parent: Node, child_name: String) -> void:
	var child := parent.find_child(child_name, true, false)
	if child == null:
		_fail("%s is missing %s" % [parent.name, child_name])
	elif child is MeshInstance3D:
		_fail("%s / %s must be an integrated shell marker, not a separate mesh" % [
			parent.name, child_name])
	else:
		print("[OK] %s / %s is an integrated shell marker" % [parent.name, child_name])


func _require_mesh_class(parent: Node, child_name: String, expected_class: String) -> void:
	var child := parent.find_child(child_name, true, false)
	if not child is MeshInstance3D:
		_fail("%s / %s is not a mesh" % [parent.name, child_name])
		return
	var mesh_node := child as MeshInstance3D
	if mesh_node.mesh == null or mesh_node.mesh.get_class() != expected_class:
		var actual := "null" if mesh_node.mesh == null else mesh_node.mesh.get_class()
		_fail("%s / %s mesh is %s, expected %s" % [
			parent.name, child_name, actual, expected_class])
	else:
		print("[OK] %s / %s uses %s" % [parent.name, child_name, expected_class])


func _fail(message: String) -> void:
	_failures += 1
	push_error(message)
	print("[FAIL] %s" % message)
