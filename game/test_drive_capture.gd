extends SceneTree
## Visual capture of the arrival-drive set and its cutscene framings.
## Run WITH rendering (no --headless):
##   Godot --path . --script res://game/test_drive_capture.gd
## Saves PNGs into res://drive_captures/ (kept out of the importer by the
## .gdignore this script writes there).

const OUT_DIR := "res://drive_captures"

func _init() -> void:
	print("[DRIVE CAPTURE] Overriding Camera3D positions directly...")
	call_deferred("_capture_flow")

func _capture_flow() -> void:
	var main_scene: PackedScene = load("res://scenes/FirstMuseumMap.tscn")
	var map_instance: Node = main_scene.instantiate()
	root.add_child(map_instance)

	paused = false

	# Remove menu UI
	for c in map_instance.get_children():
		if c.name.begins_with("MenuManager"):
			c.queue_free()
	for m in get_nodes_in_group("menu_manager"):
		m.queue_free()

	# Wait for the 3D world to render
	for i in range(40):
		await create_timer(0.033).timeout

	# End any opening cutscene so the stills are framed by this script's
	# camera, not by whatever shot the chain happens to be inside.
	for _hop in range(8):
		var opening: Cutscene = null
		for child in map_instance.get_children():
			if child is Cutscene and (child as Cutscene).is_playing():
				opening = child
				break
		if opening == null:
			break
		opening.skip()
		await create_timer(0.05).timeout

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var gdignore := FileAccess.open(OUT_DIR + "/.gdignore", FileAccess.WRITE)
	if gdignore != null:
		gdignore.close()
	var vp := root.get_viewport()
	var cam := vp.get_camera_3d()
	var car := map_instance.find_child("Player Car", true, false) as Node3D

	# Shot 1: the driver POV the three drive shots use — car mid-road, camera
	# at ExteriorProps.DRIVER_EYE, dashboard/wheel/hood in frame.
	if car != null:
		car.position = Vector3(200, 0.01, 57.2)
		car.rotation.y = deg_to_rad(90.0)
	if cam:
		var eye: Vector3 = ExteriorProps.DRIVER_EYE.rotated(Vector3.UP, deg_to_rad(90.0))
		cam.look_at_from_position(Vector3(200, 0.01, 57.2) + eye, Vector3(40, 1.0, 57.2))
	await _settle()
	_save(vp, OUT_DIR + "/drive1_pov_cabin.png")

	# Shot 2: the bridge over the river, southern mountain planes behind.
	if cam:
		cam.look_at_from_position(Vector3(170, 4.0, 48.0), Vector3(140, 1.0, 70.0))
	await _settle()
	_save(vp, OUT_DIR + "/drive2_bridge_river.png")

	# Shot 3: bus stop and the lamp rows on the museum end of the road.
	if cam:
		cam.look_at_from_position(Vector3(85, 2.0, 55.5), Vector3(70, 1.5, 52.5))
	await _settle()
	_save(vp, OUT_DIR + "/drive3_bus_stop_lamps.png")

	# Shot 4: the staff parking lot with all three cars back in their bays.
	if car != null:
		car.position = Vector3(43.5, 0.005, 42.6)
		car.rotation.y = 0.0
	if cam:
		cam.look_at_from_position(Vector3(55, 3.5, 52.0), Vector3(38, 1.0, 43.0))
	await _settle()
	_save(vp, OUT_DIR + "/drive4_parking.png")

	# Shot 5: the cutscene's closing frame — facade reveal over the lot wall.
	if cam:
		cam.look_at_from_position(Vector3(14, 4.0, 51.0), Vector3(0, 4.2, 35.0))
	await _settle()
	_save(vp, OUT_DIR + "/drive5_facade_reveal.png")

	# Shot 6: down the road the other way — forest bands and both mountain
	# backdrops, the countryside the drive starts in.
	if cam:
		cam.look_at_from_position(Vector3(120, 3.0, 57.5), Vector3(220, 12.0, 90.0))
	await _settle()
	_save(vp, OUT_DIR + "/drive6_forest_mountains.png")

	quit()

func _settle() -> void:
	for i in range(20):
		await create_timer(0.033).timeout

func _save(vp: Viewport, path: String) -> void:
	var img := vp.get_texture().get_image()
	img.save_png(path)
	print("[DRIVE CAPTURE] Saved %s" % path)
