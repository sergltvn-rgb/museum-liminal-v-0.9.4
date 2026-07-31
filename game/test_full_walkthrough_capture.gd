extends SceneTree

func _init() -> void:
	print("[MAP AUDIT] Starting full step-by-step map capture...")
	call_deferred("_run_audit_capture")

func _run_audit_capture() -> void:
	var out_dir := "C:/Users/litvi/.gemini/antigravity/brain/225e5e21-3ce7-4a87-86ed-e5f78516bf3d"
	
	var main_scene: PackedScene = load("res://scenes/FirstMuseumMap.tscn")
	var map_instance: Node = main_scene.instantiate()
	root.add_child(map_instance)
	
	paused = false
	
	# Destroy menu layer to see raw 3D views
	var menu_nodes = get_nodes_in_group("menu_manager")
	for m in menu_nodes:
		m.queue_free()
	for c in map_instance.get_children():
		if c.name.begins_with("MenuManager"):
			c.queue_free()
			
	# Wait for 3D world lighting and meshes to build
	for i in range(40):
		await create_timer(0.033).timeout
	
	var vp := root.get_viewport()
	var cam := vp.get_camera_3d()
	
	var locations = [
		{"name": "01_entrance_forecourt", "pos": Vector3(0.0, 1.6, 25.0), "rot": Vector3(-10.0, 180.0, 0.0)},
		{"name": "02_watcher_office_monitors", "pos": Vector3(-25.0, 1.6, 0.0), "rot": Vector3(0.0, -90.0, 0.0)},
		{"name": "03_watcher_office_terminal", "pos": Vector3(-23.5, 1.5, 2.0), "rot": Vector3(-15.0, 45.0, 0.0)},
		{"name": "04_equipment_storage", "pos": Vector3(-25.0, 1.6, 12.0), "rot": Vector3(0.0, 180.0, 0.0)},
		{"name": "05_restoration_lab", "pos": Vector3(-25.0, 1.6, 22.0), "rot": Vector3(0.0, 0.0, 0.0)},
		{"name": "06_archive", "pos": Vector3(-25.0, 1.6, -12.0), "rot": Vector3(0.0, 180.0, 0.0)},
		{"name": "07_central_atrium", "pos": Vector3(0.0, 1.6, 0.0), "rot": Vector3(-5.0, 135.0, 0.0)},
		{"name": "08_time_wing_b", "pos": Vector3(0.0, 1.6, -24.0), "rot": Vector3(0.0, 0.0, 0.0)},
		{"name": "09_planetarium", "pos": Vector3(0.0, 1.6, -41.0), "rot": Vector3(0.0, 180.0, 0.0)},
		{"name": "10_gravity_wing_a", "pos": Vector3(28.0, 1.6, 0.0), "rot": Vector3(0.0, -90.0, 0.0)},
		{"name": "11_space_wing_c", "pos": Vector3(24.0, 1.6, -24.0), "rot": Vector3(0.0, 90.0, 0.0)},
		{"name": "12_mass_wing_d", "pos": Vector3(52.0, 1.6, 0.0), "rot": Vector3(0.0, -90.0, 0.0)}
	]
	
	for loc in locations:
		if cam:
			cam.global_transform.origin = loc["pos"]
			cam.rotation_degrees = loc["rot"]
		for i in range(15):
			await create_timer(0.033).timeout
		var img := vp.get_texture().get_image()
		var file_path = out_dir + "/walkthrough_" + loc["name"] + ".png"
		img.save_png(file_path)
		print("[MAP AUDIT] Saved ", file_path)

	map_instance.queue_free()
	
	# Now let's capture Pocket Dimensions (Rift Trials)
	var trial_scenes = [
		{"name": "trial_01_void_rift", "path": "res://scenes/trials/VoidRiftTrial.tscn"},
		{"name": "trial_02_ascent", "path": "res://scenes/trials/AscentTrial.tscn"},
		{"name": "trial_03_radiation_bloom", "path": "res://scenes/trials/RadiationBloomTrial.tscn"}
	]
	
	for t in trial_scenes:
		var scene_res = load(t["path"])
		if scene_res:
			var trial_inst = scene_res.instantiate()
			root.add_child(trial_inst)
			for i in range(25):
				await create_timer(0.033).timeout
			var img := vp.get_texture().get_image()
			var file_path = out_dir + "/walkthrough_" + t["name"] + ".png"
			img.save_png(file_path)
			print("[MAP AUDIT] Saved ", file_path)
			trial_inst.queue_free()
			
	quit()
