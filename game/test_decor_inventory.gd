extends SceneTree
## Inventory authored decorative roots before the visual pass.
## Headless-safe: this only inspects the generated node tree.

const SCENE := "res://scenes/FirstMuseumMap.tscn"
const OUT_PATH := "res://shots/decor_audit/inventory.tsv"
const MAX_REPORT_DEPTH := 3
const MIN_MESHES := 2

var _rows: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load(SCENE)
	if packed == null:
		push_error("[DECOR INVENTORY] cannot load %s" % SCENE)
		quit(1)
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	paused = false
	await process_frame
	await process_frame
	var generated := instance.find_child("GeneratedMap", true, false)
	if generated == null:
		push_error("[DECOR INVENTORY] GeneratedMap not found")
		quit(1)
		return
	_rows.append("path\tdepth\tmeshes\tposition\tdirect_children")
	_scan(generated, 0, generated)
	var absolute := ProjectSettings.globalize_path(OUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		push_error("[DECOR INVENTORY] cannot write %s" % absolute)
		quit(1)
		return
	file.store_string("\n".join(_rows) + "\n")
	file.close()
	print("[DECOR INVENTORY] wrote %d candidates -> %s" % [_rows.size() - 1, OUT_PATH])
	quit()

func _scan(node: Node, depth: int, base: Node) -> int:
	var mesh_count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		mesh_count += _scan(child, depth + 1, base)
	if node is Node3D and depth <= MAX_REPORT_DEPTH and mesh_count >= MIN_MESHES:
		var n3 := node as Node3D
		_rows.append("%s\t%d\t%d\t%s\t%d" % [
			str(base.get_path_to(node)), depth, mesh_count,
			str(n3.global_position), node.get_child_count()])
	return mesh_count
