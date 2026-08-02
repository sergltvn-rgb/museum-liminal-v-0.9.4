extends SceneTree
## Visual capture of the FacadeProps street facade and entrance porch.
## Run WITH rendering (no --headless):
##   Godot --path . --script res://game/test_facade_capture.gd
## Saves PNGs into res://facade_captures/.

func _init() -> void:
	print("[FACADE CAPTURE] Overriding Camera3D positions directly...")
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
	var menu_nodes = get_nodes_in_group("menu_manager")
	for m in menu_nodes:
		m.queue_free()

	# Wait for the 3D world to render
	for i in range(40):
		await create_timer(0.033).timeout

	var out_dir := "res://facade_captures"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var vp := root.get_viewport()
	var cam := vp.get_camera_3d()

	# Shot 1: establishing three-quarter view, whole order up to the finial.
	if cam:
		cam.look_at_from_position(Vector3(14.0, 6.5, 54.0), Vector3(0.0, 4.2, 35.0))
	await _settle()
	_save(vp, out_dir + "/facade1_three_quarter.png")

	# Shot 2: frontal elevation from the walkway axis.
	if cam:
		cam.look_at_from_position(Vector3(0.0, 3.6, 51.0), Vector3(0.0, 4.4, 35.0))
	await _settle()
	_save(vp, out_dir + "/facade2_frontal.png")

	# Shot 3: eye-level approach — perron, columns, portal and sign.
	if cam:
		cam.look_at_from_position(Vector3(-2.5, 1.75, 44.0), Vector3(0.0, 3.2, 35.0))
	await _settle()
	_save(vp, out_dir + "/facade3_porch_approach.png")

	# Shot 4: door portal close-up from the top of the perron.
	if cam:
		cam.look_at_from_position(Vector3(1.6, 1.7, 39.4), Vector3(-0.3, 2.0, 35.0))
	await _settle()
	_save(vp, out_dir + "/facade4_door_portal.png")

	quit()

func _settle() -> void:
	for i in range(20):
		await create_timer(0.033).timeout

func _save(vp: Viewport, path: String) -> void:
	var img := vp.get_texture().get_image()
	img.save_png(path)
	print("[FACADE CAPTURE] Saved %s" % path)
