extends SceneTree
## Screenshot proof for the rebuilt Entrance Zone (see LobbyProps.gd).
##
## Run WITH a rendering window -- not --headless, which has no framebuffer to
## read back:
##   Godot_v4.7-stable_win64_console.exe --path . --script res://game/test_lobby_capture.gd
##
## Shots land in <project>/lobby_captures. Written the same way as
## test_visual_capture.gd: instance the map, drop the menu, let the world
## settle, then drive the active Camera3D by hand.

const SETTLE_FRAMES := 40
const SHOT_FRAMES := 22

# name, camera position, rotation in degrees
const SHOTS: Array = [
	["lobby1_from_entrance", Vector3(0.0, 1.65, 33.2), Vector3(-2.0, 180.0, 0.0)],
	["lobby2_reception", Vector3(-5.2, 1.62, 30.0), Vector3(-6.0, 197.0, 0.0)],
	["lobby3_cloakroom", Vector3(4.5, 1.62, 28.0), Vector3(-4.0, -37.0, 0.0)],
	["lobby4_wayfinding", Vector3(0.0, 1.62, 22.0), Vector3(-3.0, 180.0, 0.0)],
	["lobby5_overview", Vector3(8.4, 3.05, 33.0), Vector3(-19.0, 208.0, 0.0)],
	["lobby6_back_to_door", Vector3(-3.0, 1.62, 18.0), Vector3(0.0, 8.0, 0.0)],
]


func _init() -> void:
	print("[LOBBY CAPTURE] starting")
	call_deferred("_capture_flow")


func _capture_flow() -> void:
	var main_scene: PackedScene = load("res://scenes/FirstMuseumMap.tscn")
	var map_instance: Node = main_scene.instantiate()
	root.add_child(map_instance)
	paused = false

	# The menu sits over the 3D world and would be in every frame.
	for c in map_instance.get_children():
		if c.name.begins_with("MenuManager"):
			c.queue_free()
	for m in get_nodes_in_group("menu_manager"):
		m.queue_free()

	var out_dir := ProjectSettings.globalize_path("res://lobby_captures")
	DirAccess.make_dir_recursive_absolute(out_dir)

	for i in range(SETTLE_FRAMES):
		await create_timer(0.033).timeout

	var vp := root.get_viewport()
	var cam := vp.get_camera_3d()
	if cam == null:
		push_error("[LOBBY CAPTURE] no active Camera3D")
		quit(1)
		return
	# The player controller owns this camera and would steer it back.
	var holder := cam.get_parent()
	if holder is Node3D:
		holder.set_process(false)
		holder.set_physics_process(false)

	for shot in SHOTS:
		var shot_name: String = shot[0]
		cam.global_transform.origin = shot[1]
		cam.rotation_degrees = shot[2]
		for i in range(SHOT_FRAMES):
			await create_timer(0.033).timeout
			cam.global_transform.origin = shot[1]
			cam.rotation_degrees = shot[2]
		var img := vp.get_texture().get_image()
		var path := "%s/%s.png" % [out_dir, shot_name]
		var err := img.save_png(path)
		if err != OK:
			push_error("[LOBBY CAPTURE] save failed: %s (%d)" % [path, err])
		else:
			print("[LOBBY CAPTURE] saved %s.png" % shot_name)

	print("[LOBBY CAPTURE] done -> %s" % out_dir)
	quit()
