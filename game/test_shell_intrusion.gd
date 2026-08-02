extends SceneTree

## WHAT THIS ANSWERS
## "Some exterior details end up inside the interior." Eyeballing screenshots
## cannot tell you WHICH mesh, so this builds the real map and intersects every
## piece of BuildingShell against the volume the player actually occupies in
## each room. Anything it prints is a thing you can see from indoors.
##
## THE TEST VOLUME
## Rooms are the rectangles FirstMuseumMap.build_map uses. Interior walls are
## WALL_THICKNESS 0.35 centred on the boundary, so the free air of a room stops
## 0.175 m short of its nominal edge -- that inset is applied here, otherwise
## every wall in the building would report itself. Ceiling slabs sit at 3.45
## with a 3.39 soffit, so the band checked is y 0.02 .. 3.44: floor to ceiling,
## which is all the player can ever see.
##
## Run: godot --headless --path . --script res://game/test_shell_intrusion.gd

const SHELL_ROOT_NAME := "Museum Shell"
const WALL_HALF := 0.175
const FLOOR_Y := 0.02
const CEILING_Y := 3.44

## name, centre x, centre z, width (x), depth (z)
const ROOMS := [
	["Entrance Zone", 0.0, 25.0, 22.0, 20.0],
	["Central Atrium", 0.0, 0.0, 30.0, 30.0],
	["Watcher Office", -25.0, 0.0, 20.0, 14.0],
	["Equipment Storage", -25.0, 12.0, 20.0, 10.0],
	["Archive", -25.0, -12.0, 20.0, 10.0],
	["Restoration Lab", -25.0, 22.0, 20.0, 10.0],
	["Gravity Wing A", 28.0, 0.0, 26.0, 18.0],
	["Mass Wing D", 52.0, 0.0, 22.0, 16.0],
	["Time Wing B", 0.0, -24.0, 26.0, 18.0],
	["Space Wing C", 24.0, -24.0, 22.0, 16.0],
	["Planetarium", 0.0, -41.0, 20.0, 16.0],
]


func _init() -> void:
	print("==================================================")
	print("SHELL INTRUSION SCAN")
	print("==================================================")

	var packed := load("res://scenes/FirstMuseumMap.tscn") as PackedScene
	if packed == null:
		print("[FAIL] FirstMuseumMap.tscn did not load")
		quit(1)
		return
	var map_root: Node = packed.instantiate()
	root.add_child(map_root)
	await process_frame
	await process_frame  # _ready() + build_map()

	var shell: Node = map_root.find_child(SHELL_ROOT_NAME, true, false)
	if shell == null:
		print("[FAIL] No '%s' node -- BuildingShell is not in the map" % SHELL_ROOT_NAME)
		quit(1)
		return

	var meshes := shell.find_children("*", "MeshInstance3D", true, false)
	print("Shell meshes scanned: %d" % meshes.size())

	var hits: Array = []
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		if box.position.y > CEILING_Y or box.position.y + box.size.y < FLOOR_Y:
			continue
		for room in ROOMS:
			var room_box := _room_volume(room)
			if not room_box.intersects(box):
				continue
			var overlap := room_box.intersection(box)
			# Sub-centimetre slivers are float noise on a shared plane, not a
			# prop standing in the room.
			if overlap.size.x < 0.01 or overlap.size.z < 0.01 or overlap.size.y < 0.01:
				continue
			hits.append([mi.name, String(room[0]), overlap])

	if hits.is_empty():
		print("\n[OK] No shell geometry reaches into any room.")
		quit(0)
		return

	# Grouped by room so the report reads like a walkthrough, and sorted by how
	# far in the piece reaches, because the deepest one is what you notice.
	print("\n%d intruding piece(s):" % hits.size())
	for room in ROOMS:
		var room_name := String(room[0])
		var in_room: Array = []
		for hit in hits:
			if String(hit[1]) == room_name:
				in_room.append(hit)
		if in_room.is_empty():
			continue
		in_room.sort_custom(func(a, b): return _depth(a[2]) > _depth(b[2]))
		print("\n  %s -- %d piece(s)" % [room_name, in_room.size()])
		for hit in in_room:
			var overlap: AABB = hit[2]
			print("    %-46s reaches %.2f m in, box %.2f x %.2f x %.2f at (%.2f %.2f %.2f)"
				% [String(hit[0]), _depth(overlap), overlap.size.x, overlap.size.y,
					overlap.size.z, overlap.position.x, overlap.position.y,
					overlap.position.z])
	quit(1)


## The air inside one room: its rectangle pulled in by half a wall, floor to
## ceiling soffit.
func _room_volume(room: Array) -> AABB:
	var cx: float = float(room[1])
	var cz: float = float(room[2])
	var hw: float = float(room[3]) * 0.5 - WALL_HALF
	var hd: float = float(room[4]) * 0.5 - WALL_HALF
	return AABB(Vector3(cx - hw, FLOOR_Y, cz - hd),
		Vector3(hw * 2.0, CEILING_Y - FLOOR_Y, hd * 2.0))


## How far into the room the piece reaches, measured in plan.
func _depth(overlap: AABB) -> float:
	return maxf(overlap.size.x, overlap.size.z)
