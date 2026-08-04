extends SceneTree
## Systematic visual audit for every authored decorative group.
## Reads decor_shots.json and saves a full PNG, review JPEG and four detail tiles.

const Shots := preload("res://game/AgentShots.gd")
const CONFIG_PATH := "res://decor_shots.json"
const DEFAULT_SCENE := "res://scenes/FirstMuseumMap.tscn"
const DEFAULT_OUT := "res://shots/decor_audit/after"
const SETTLE_FRAMES := 40
const SHOT_FRAMES := 6

const ROOM_CENTRES: Array[Vector3] = [
	Vector3(0, 0, 25), Vector3(0, 0, 0), Vector3(-25, 0, 0),
	Vector3(-25, 0, 12), Vector3(-25, 0, -12), Vector3(-25, 0, 22),
	Vector3(28, 0, 0), Vector3(52, 0, 0), Vector3(0, 0, -24),
	Vector3(24, 0, -24), Vector3(0, 0, -41),
	# Exterior camera hints. Without these, the nearest point for every outdoor
	# prop was inside a gallery, so automatic shots travelled through the shell.
	Vector3(0, 0, 47), Vector3(42, 0, 59), Vector3(78, 0, 58),
	Vector3(-34, 0, 38), Vector3(-44, 0, 2),
]

func _init() -> void:
	print("[DECOR CAPTURE] starting")
	call_deferred("_run")

func _run() -> void:
	var config := _load_config()
	if config.is_empty():
		quit(1)
		return
	var packed: PackedScene = load(str(config.get("scene", DEFAULT_SCENE)))
	if packed == null:
		push_error("[DECOR CAPTURE] main scene failed to load")
		quit(1)
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	paused = false
	for node in get_nodes_in_group("menu_manager"):
		node.queue_free()
	for child in instance.get_children():
		if child.name.begins_with("MenuManager"):
			child.queue_free()
	for _i in range(int(config.get("settle", SETTLE_FRAMES))):
		await create_timer(0.033).timeout
	# The capture is evidence about the world, not about a transient objective.
	# Hide every 2D layer recursively after the game has had time to create it.
	_hide_capture_ui(root)
	var generated := instance.find_child("GeneratedMap", true, false)
	var viewport := root.get_viewport()
	var camera := viewport.get_camera_3d()
	if generated == null or camera == null:
		push_error("[DECOR CAPTURE] GeneratedMap or Camera3D missing")
		quit(1)
		return
	var holder := camera.get_parent()
	if holder is Node3D:
		holder.set_process(false)
		holder.set_physics_process(false)
	camera.far = 4000.0
	camera.near = 0.03
	var out_dir := ProjectSettings.globalize_path(str(config.get("out_dir", DEFAULT_OUT)))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var manifest_lines: Array[String] = ["name\tnode_path\tcamera\ttarget\tstatus"]
	var written := 0
	for raw: Variant in config.get("shots", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var shot: Dictionary = raw
		var shot_name := str(shot.get("name", "decor_%03d" % written))
		var node_path := str(shot.get("node_path", ""))
		var camera_pos := Vector3.ZERO
		var target_pos := Vector3.ZERO
		var status := "manual"
		if shot.has("pos") and shot.has("look_at"):
			camera_pos = _vec3(shot.get("pos"))
			target_pos = _vec3(shot.get("look_at"))
		else:
			var target_node := generated.get_node_or_null(NodePath(node_path))
			if target_node == null:
				push_warning("[DECOR CAPTURE] missing target: %s" % node_path)
				manifest_lines.append("%s\t%s\t\t\tmissing" % [shot_name, node_path])
				continue
			var bounds_info := _bounds_of(target_node)
			if not bool(bounds_info.get("valid", false)):
				push_warning("[DECOR CAPTURE] no visible mesh bounds: %s" % node_path)
				manifest_lines.append("%s\t%s\t\t\tno_bounds" % [shot_name, node_path])
				continue
			var bounds: AABB = bounds_info["aabb"]
			target_pos = bounds.get_center()
			var hint := _nearest_room(target_pos)
			var direction := hint - target_pos
			direction.y = 0.0
			if direction.length() < 1.2:
				direction = Vector3(0, 0, 1)
			else:
				direction = direction.normalized()
			var span: float = maxf(bounds.size.x, maxf(bounds.size.z, bounds.size.y * 0.85))
			var distance := clampf(span * 1.35 + 1.7, 2.3, 9.0)
			camera_pos = target_pos + direction * distance
			camera_pos.y = clampf(target_pos.y + maxf(0.28, bounds.size.y * 0.12), 1.20, 2.45)
			status = "auto"
		camera.fov = float(shot.get("fov", 54.0))
		for _frame in range(int(config.get("frames", SHOT_FRAMES))):
			await create_timer(0.033).timeout
			camera.global_position = camera_pos
			if not camera_pos.is_equal_approx(target_pos):
				camera.look_at(target_pos, Vector3.UP)
		# A late notification can be spawned while a shot settles. Hide again on
		# the last frame so no objective banner or inventory strip enters proof.
		_hide_capture_ui(root)
		var image := viewport.get_texture().get_image()
		var result := Shots.save_set(image, out_dir, shot_name, int(config.get("tiles", 2)))
		Shots.report(result, "DECOR")
		manifest_lines.append("%s\t%s\t%s\t%s\t%s" % [
			shot_name, node_path, str(camera_pos), str(target_pos), status])
		written += 1
	var manifest_path := "%s/manifest.tsv" % out_dir
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(manifest_lines) + "\n")
		file.close()
	print("[DECOR CAPTURE] done: %d shots -> %s" % [written, out_dir])
	quit()

func _load_config() -> Dictionary:
	# Focused recaptures use a small alternate config without rewriting the
	# canonical 132-shot inventory. The environment value is a res:// path.
	var config_path: String = OS.get_environment("DECOR_CONFIG")
	if config_path.is_empty():
		config_path = CONFIG_PATH
	if not FileAccess.file_exists(config_path):
		push_error("[DECOR CAPTURE] missing %s" % config_path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[DECOR CAPTURE] invalid JSON: %s" % config_path)
		return {}
	return parsed

func _vec3(value: Variant) -> Vector3:
	if typeof(value) != TYPE_ARRAY or value.size() < 3:
		return Vector3.ZERO
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _nearest_room(point: Vector3) -> Vector3:
	var best := ROOM_CENTRES[0]
	var best_distance := INF
	for room in ROOM_CENTRES:
		var flat := Vector2(point.x - room.x, point.z - room.z).length_squared()
		if flat < best_distance:
			best_distance = flat
			best = room
	return best

func _hide_capture_ui(node: Node) -> void:
	if node is CanvasLayer:
		(node as CanvasLayer).visible = false
	elif node is Control:
		(node as Control).visible = false
	for child in node.get_children():
		_hide_capture_ui(child)

func _bounds_of(node: Node) -> Dictionary:
	var state := {"valid": false, "aabb": AABB()}
	_collect_bounds(node, state)
	return state

func _collect_bounds(node: Node, state: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.visible and mesh_node.mesh != null:
			var world_box: AABB = mesh_node.global_transform * mesh_node.mesh.get_aabb()
			if bool(state["valid"]):
				state["aabb"] = (state["aabb"] as AABB).merge(world_box)
			else:
				state["aabb"] = world_box
				state["valid"] = true
	for child in node.get_children():
		_collect_bounds(child, state)
