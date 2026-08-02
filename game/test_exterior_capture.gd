extends SceneTree
## Screenshot proof for the museum exterior (see props/BuildingShell.gd).
##
## Run WITH a rendering window -- not --headless, which has no framebuffer to
## read back:
##   Godot_v4.7-stable_win64_console.exe --path . --script res://game/test_exterior_capture.gd
##
## Shots land in <project>/exterior_captures, and a 960 x 540 copy of each one
## lands in <project>/exterior_captures/small. The small copies exist because
## the review tooling times out reading PNGs over about half a megabyte, so a
## full-resolution-only capture is a screenshot nobody can actually look at.
##
## Camera angles are aimed at the three things that were missing before: the
## roof over the portico, the dome behind it, and the fact that the building
## has sides and a back at all.

const SETTLE_FRAMES := 40
const SHOT_FRAMES := 22
const THUMB_WIDTH := 960
const THUMB_HEIGHT := 540

# name, camera position, rotation in degrees
const SHOTS: Array = [
	# Straight up the axis from the forecourt: portico, roof above it, dome behind.
	["ext1_front_axis", Vector3(0.0, 3.0, 56.0), Vector3(-2.0, 180.0, 0.0)],
	# Eye level from the east corner of the forecourt: the block has a flank.
	["ext2_forecourt_corner", Vector3(24.0, 1.70, 44.0), Vector3(11.3, 62.2, 0.0)],
	# Lifted off the axis: pediment in front, hipped roof and dome stacked behind.
	["ext3_dome_over_portico", Vector3(0.0, 12.0, 50.0), Vector3(3.4, 0.0, 0.0)],
	# West flank: the four-room range, its dormers and the service door.
	["ext4_west_flank", Vector3(-70.0, 26.0, 20.0), Vector3(-22.9, -71.6, 0.0)],
	# East flank over the gravity and mass wings.
	["ext5_east_flank", Vector3(110.0, 32.0, 40.0), Vector3(-18.0, 61.7, 0.0)],
	# The back, which never existed until now: time wing and planetarium dome.
	["ext6_rear_planetarium", Vector3(0.0, 30.0, -95.0), Vector3(-20.1, 180.0, 0.0)],
	# Whole plan from above, to check no mass is missing or floating.
	["ext7_overview", Vector3(-90.0, 70.0, 90.0), Vector3(-23.7, -45.0, 0.0)],
	# The approach the drive-in cutscene ends on.
	["ext8_from_car_park", Vector3(43.5, 2.20, 42.6), Vector3(2.0, 213.0, 0.0)],
]


func _init() -> void:
	print("[EXTERIOR CAPTURE] starting")
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

	var out_dir := ProjectSettings.globalize_path("res://exterior_captures")
	var thumb_dir := "%s/small" % out_dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.make_dir_recursive_absolute(thumb_dir)

	for i in range(SETTLE_FRAMES):
		await create_timer(0.033).timeout

	var vp := root.get_viewport()
	var cam := vp.get_camera_3d()
	if cam == null:
		push_error("[EXTERIOR CAPTURE] no active Camera3D")
		quit(1)
		return
	# The player controller owns this camera and would steer it back.
	var holder := cam.get_parent()
	if holder is Node3D:
		holder.set_process(false)
		holder.set_physics_process(false)
	# Overview shots sit far outside the play area, so the default near/far pair
	# has to be widened or the far masses clip away mid-shot.
	cam.far = 4000.0

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
			push_error("[EXTERIOR CAPTURE] save failed: %s (%d)" % [path, err])
		else:
			print("[EXTERIOR CAPTURE] saved %s.png" % shot_name)
		# Reviewable copy. duplicate() first: resizing the shot in place would
		# hand the next iteration a shrunken image.
		var thumb: Image = img.duplicate()
		thumb.resize(THUMB_WIDTH, THUMB_HEIGHT, Image.INTERPOLATE_BILINEAR)
		var thumb_path := "%s/%s.png" % [thumb_dir, shot_name]
		var thumb_err := thumb.save_png(thumb_path)
		if thumb_err != OK:
			push_error("[EXTERIOR CAPTURE] thumb failed: %s (%d)"
				% [thumb_path, thumb_err])

	print("[EXTERIOR CAPTURE] done -> %s" % out_dir)
	quit()
