extends SceneTree

func _init() -> void:
	print("[VISUAL CAPTURE] Overriding Camera3D positions directly...")
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
		
	# Wait for 3D world to render
	for i in range(40):
		await create_timer(0.033).timeout
	
	var out_dir := "C:/Users/litvi/.gemini/antigravity/brain/225e5e21-3ce7-4a87-86ed-e5f78516bf3d"
	var vp := root.get_viewport()
	var cam := vp.get_camera_3d()
	
	# Shot 1: Watcher Office (-25, 1.6, 0)
	if cam:
		cam.global_transform.origin = Vector3(-25.0, 1.6, 0.0)
		cam.rotation_degrees = Vector3(0.0, -90.0, 0.0)
	
	for i in range(20):
		await create_timer(0.033).timeout
	var img := vp.get_texture().get_image()
	img.save_png(out_dir + "/shot1_office_interior.png")
	print("[VISUAL CAPTURE] Saved shot1_office_interior.png")

	# Shot 2: Equipment Storage (-25, 1.6, 12)
	if cam:
		cam.global_transform.origin = Vector3(-25.0, 1.6, 12.0)
		cam.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		
	for i in range(20):
		await create_timer(0.033).timeout
	img = vp.get_texture().get_image()
	img.save_png(out_dir + "/shot2_storage_interior.png")
	print("[VISUAL CAPTURE] Saved shot2_storage_interior.png")

	# Shot 3: Central Atrium (0, 1.6, 0)
	if cam:
		cam.global_transform.origin = Vector3(0.0, 1.6, 0.0)
		cam.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		
	for i in range(20):
		await create_timer(0.033).timeout
	img = vp.get_texture().get_image()
	img.save_png(out_dir + "/shot3_atrium_interior.png")
	print("[VISUAL CAPTURE] Saved shot3_atrium_interior.png")

	quit()
