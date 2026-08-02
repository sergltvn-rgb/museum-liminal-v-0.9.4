extends SceneTree
## Capture any viewpoint in any scene, without editing GDScript.
##
## The fixed capture scripts (test_exterior_capture, test_lobby_capture, ...)
## each hard-code their angles, so inspecting anything new meant editing a
## const array, and checking one suspect corner meant re-shooting eight views.
## This script takes its shot list from a JSON file instead, which means a new
## viewpoint costs one file_write and no code change.
##
## Run WITH a rendering window -- never --headless, which has no framebuffer
## to read back:
##   Godot_v4.7-stable_win64_console.exe --path . --script res://game/test_shot.gd
##
## It reads res://agent_shots.json:
##
## {
##   "scene": "res://scenes/FirstMuseumMap.tscn",   // optional
##   "out_dir": "res://shots",                      // optional
##   "tiles": 2,                                    // 2 = four detail crops
##   "settle": 40,                                  // warm-up frames
##   "frames": 22,                                  // frames held per shot
##   "shots": [
##     {"name": "court_axis", "pos": [0, 1.7, 52], "look_at": [0, 4, 36]},
##     {"name": "roof_seam", "pos": [24, 12, 44], "rot": [-14, 62, 0], "fov": 40}
##   ]
## }
##
## Each shot takes either "look_at" (aim at a world point) or "rot" (explicit
## Euler degrees). look_at is what you almost always want: reaching a specific
## piece of geometry by guessing yaw and pitch by hand wastes a run per guess.
## "fov" is optional and narrowing it is the cheap way to inspect a detail
## from far enough away that nothing near-clips.
##
## Output goes through AgentShots, so every shot lands as a full-resolution
## PNG plus small JPEGs that survive the reader's size limit. Sizes are
## printed for each file.

# Preloaded rather than reached through its class_name: global class names are
# only registered by a project import scan, and a bare `--script` run does not
# do one, so a freshly added class_name is not in scope here.
const Shots := preload("res://game/AgentShots.gd")

const CONFIG_PATH := "res://agent_shots.json"
const DEFAULT_SCENE := "res://scenes/FirstMuseumMap.tscn"
const DEFAULT_OUT := "res://shots"
const DEFAULT_SETTLE := 40
const DEFAULT_FRAMES := 22
const DEFAULT_TILES := 2


func _init() -> void:
	print("[SHOT] starting")
	call_deferred("_flow")


func _flow() -> void:
	var config := _load_config()
	if config.is_empty():
		quit(1)
		return

	var shots: Array = config.get("shots", [])
	if shots.is_empty():
		push_error("[SHOT] no shots listed in %s" % CONFIG_PATH)
		quit(1)
		return

	var scene_path: String = str(config.get("scene", DEFAULT_SCENE))
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error("[SHOT] cannot load scene %s" % scene_path)
		quit(1)
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	paused = false

	# The menu sits over the 3D world and would be in every frame.
	for c in instance.get_children():
		if c.name.begins_with("MenuManager"):
			c.queue_free()
	for m in get_nodes_in_group("menu_manager"):
		m.queue_free()

	var out_dir := ProjectSettings.globalize_path(
		str(config.get("out_dir", DEFAULT_OUT)))
	DirAccess.make_dir_recursive_absolute(out_dir)

	var settle: int = int(config.get("settle", DEFAULT_SETTLE))
	var frames: int = int(config.get("frames", DEFAULT_FRAMES))
	var tiles: int = int(config.get("tiles", DEFAULT_TILES))

	for i in range(settle):
		await create_timer(0.033).timeout

	var vp := root.get_viewport()
	var cam := vp.get_camera_3d()
	if cam == null:
		push_error("[SHOT] no active Camera3D in %s" % scene_path)
		quit(1)
		return

	# The player controller owns this camera and would steer it back every
	# frame, so the shot would drift back to the player's head mid-capture.
	var holder := cam.get_parent()
	if holder is Node3D:
		holder.set_process(false)
		holder.set_physics_process(false)
	var base_fov := cam.fov
	cam.far = float(config.get("far", 4000.0))

	var written := 0
	for shot_variant: Variant in shots:
		var shot: Dictionary = shot_variant
		var shot_name: String = str(shot.get("name", "shot%d" % written))
		var pos := _to_vec3(shot.get("pos", []), Vector3.ZERO)
		cam.fov = float(shot.get("fov", base_fov))

		# Aim once, then re-apply every frame: physics and the tween-free
		# camera rig can both nudge a transform between frames.
		var aim_at: Variant = shot.get("look_at", null)
		var rot := _to_vec3(shot.get("rot", []), Vector3.ZERO)
		for i in range(frames):
			await create_timer(0.033).timeout
			cam.global_transform.origin = pos
			if aim_at != null:
				var target := _to_vec3(aim_at, Vector3.ZERO)
				if not target.is_equal_approx(pos):
					cam.look_at(target, Vector3.UP)
			else:
				cam.rotation_degrees = rot

		var img := vp.get_texture().get_image()
		var result := Shots.save_set(img, out_dir, shot_name, tiles)
		print("[SHOT] %s  pos %s" % [shot_name, pos])
		Shots.report(result, "SHOT")
		written += 1

	print("[SHOT] done -> %s  (%d shot(s))" % [out_dir, written])
	quit()


func _load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("[SHOT] missing %s" % CONFIG_PATH)
		return {}
	var text := FileAccess.get_file_as_string(CONFIG_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SHOT] %s is not a JSON object" % CONFIG_PATH)
		return {}
	return parsed


func _to_vec3(value: Variant, fallback: Vector3) -> Vector3:
	if typeof(value) != TYPE_ARRAY:
		return fallback
	var arr: Array = value
	if arr.size() < 3:
		return fallback
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
