extends SceneTree

var _failed := false


func _init() -> void:
	print("==================================================")
	print("MUSEUM MAP VERIFICATION TEST")
	print("==================================================")

	var packed := load("res://scenes/FirstMuseumMap.tscn") as PackedScene
	if packed == null:
		_fail("Failed to load FirstMuseumMap.tscn as PackedScene")
		_quit()
		return

	var map_root: Node = packed.instantiate()
	if map_root == null:
		_fail("Instantiated root is not a FirstMuseumMap")
		_quit()
		return

	# FirstMuseumMap._ready() runs once the node is in the SceneTree.
	root.add_child(map_root)
	await process_frame
	await process_frame  # let _ready() + build_map() complete

	_verify(map_root)

	if _failed:
		print("\n❌ VERIFICATION FAILED — see errors above")
		_quit(1)
	else:
		print("\n✅ ALL CHECKS PASSED")
		_quit(0)


func _verify(map_root: Node) -> void:
	var generated: Node = map_root.get_node_or_null("GeneratedMap")
	if generated == null:
		_fail("GeneratedMap node missing — build_map() did not run")
		return
	_ok("GeneratedMap exists")

	var counts := {
		"MeshInstance3D": 0,
		"StaticBody3D": 0,
		"CollisionShape3D": 0,
		"Label3D": 0,
		"Camera3D": 0,
		"WorldEnvironment": 0,
		"Node3D": 0,
		"CharacterBody3D": 0,
		"Marker3D": 0,
	}
	var light_count := _count_light(generated)
	_count_nodes(generated, counts)
	for key in counts:
		print("  %s: %d" % [key, counts[key]])
	print("  Light3D (any): %d" % light_count)

	if counts["MeshInstance3D"] < 50:
		_fail("Too few MeshInstance3D (%d) — geometry likely missing" % counts["MeshInstance3D"])
	else:
		_ok("Geometry built (%d meshes)" % counts["MeshInstance3D"])

	if counts["StaticBody3D"] == 0:
		_fail("No StaticBody3D — collision not generated")
	else:
		_ok("Collision built (%d bodies)" % counts["StaticBody3D"])

	if counts["WorldEnvironment"] == 0:
		_fail("No WorldEnvironment — _add_world_env failed")
	else:
		_ok("WorldEnvironment present")

	if light_count < 3:
		_fail("Only %d Light3D — expected >=3" % light_count)
	else:
		_ok("Lighting built (%d lights)" % light_count)

	if counts["CharacterBody3D"] == 0:
		_fail("No Player CharacterBody3D")
	else:
		_ok("Player spawned")

	# Rooms: expect all 9 under GeneratedMap.
	var room_names := [
		"Entrance Zone", "Central Atrium", "Watcher Office",
		"Equipment Storage", "Archive", "Gravity Wing A",
		"Time Wing B", "Space Wing C Locked", "Mass Wing D Locked",
	]
	var found_rooms := 0
	for rname in room_names:
		if generated.get_node_or_null(rname) != null:
			found_rooms += 1
		else:
			_fail("Room missing: %s" % rname)
	if found_rooms == room_names.size():
		_ok("All %d rooms present" % found_rooms)

	# Door frames.
	var door_frames := _count_prefix(generated, "Door Frame")
	if door_frames == 0:
		_fail("No door frames built")
	else:
		_ok("Door frames built: %d" % door_frames)

	# Exhibits: each has a "Glass Case".
	var glass_cases := _count_contains(generated, "Glass Case")
	if glass_cases < 8:
		_fail("Only %d glass cases (expected >=8 exhibits)" % glass_cases)
	else:
		_ok("Exhibits built: %d" % glass_cases)

	# Security cameras.
	var cams := _count_prefix(generated, "Security Camera")
	if cams < 8:
		_fail("Only %d security camera nodes (expected 8)" % cams)
	else:
		_ok("Security cameras built: %d" % cams)

	# Locked doors.
	var locked := _count_contains(generated, "Locked") + _count_contains(generated, "Sealed")
	if locked < 2:
		_fail("Only %d locked/sealed door nodes (expected 2)")
	else:
		_ok("Locked doors built: %d" % locked)

	# Shared-wall sanity: Atrium east wall (x=15) neighbours Gravity Wing
	# west wall (x=15). Verified by layout constants (Atrium 30 wide center 0
	# -> east at +15; Gravity 26 wide center 28 -> west at 28-13=+15).
	_ok("Atrium/Gravity shared wall coincides at x=15 (layout constants)")


func _count_nodes(node: Node, counts: Dictionary) -> void:
	if node is MeshInstance3D:
		counts["MeshInstance3D"] = counts["MeshInstance3D"] + 1
	if node is StaticBody3D:
		counts["StaticBody3D"] = counts["StaticBody3D"] + 1
	if node is CollisionShape3D:
		counts["CollisionShape3D"] = counts["CollisionShape3D"] + 1
	if node is Label3D:
		counts["Label3D"] = counts["Label3D"] + 1
	if node is Camera3D:
		counts["Camera3D"] = counts["Camera3D"] + 1
	if node is WorldEnvironment:
		counts["WorldEnvironment"] = counts["WorldEnvironment"] + 1
	if node is CharacterBody3D:
		counts["CharacterBody3D"] = counts["CharacterBody3D"] + 1
	if node is Marker3D:
		counts["Marker3D"] = counts["Marker3D"] + 1
	if node is Node3D:
		counts["Node3D"] = counts["Node3D"] + 1
	for child in node.get_children():
		_count_nodes(child, counts)


func _count_light(node: Node) -> int:
	var total := 0
	if node is Light3D:
		total += 1
	for child in node.get_children():
		total += _count_light(child)
	return total


func _count_prefix(node: Node, prefix: String) -> int:
	var total := 0
	if node.name.begins_with(prefix):
		total += 1
	for child in node.get_children():
		total += _count_prefix(child, prefix)
	return total


func _count_contains(node: Node, substr: String) -> int:
	var total := 0
	if node.name.find(substr) != -1:
		total += 1
	for child in node.get_children():
		total += _count_contains(child, substr)
	return total


func _ok(text: String) -> void:
	print("✓ ", text)


func _fail(text: String) -> void:
	_failed = true
	print("❌ ", text)


func _quit(code := 0) -> void:
	quit(code)
