extends SceneTree

## Where the localization sweep looks for translation keys and for the answers.
const LOCALIZATION_CSV := "res://localization/game.csv"
const LOCALIZATION_CODE_DIR := "res://game"

## Matches a string literal that is entirely UPPER_SNAKE and at least four
## characters long -- the shape of every translation key in this project. Kept
## byte-for-byte equivalent to KEY_LITERAL_RE in tools/check_localization.py so
## the in-engine sweep and the standalone script cannot disagree.
const KEY_LITERAL_PATTERN := '"([A-Z][A-Z0-9_]{3,})"'

## UPPER_SNAKE literals that look like keys but are not, so they must never be
## demanded of the catalogue: input actions, group and node names, and uppercase
## UI text. Mirrors NOT_KEYS in tools/check_localization.py -- adding a name here
## means adding it there too.
const NON_KEY_LITERALS := [
	"WASD", "START", "LMB", "RMB", "ESC",
]

## Test scripts are excluded from the sweep entirely. They name production
## constants as strings to resolve them through get_script_constant_map()
## (EXHIBITS, CAMS, ANOMALY_SCALE_SPAN, SCALE_MIN/MAX, KILL_PLANE_Y), and none of
## them renders text to a player. Excusing each one by name meant that every time
## a suite reached for another constant this check went red for a reason that had
## nothing to do with localization.
const NON_UI_SOURCE_PREFIX := "test_"

## The tablet declares one feed per physical mount and switches between them by
## index, so the map's camera count is not a free number -- it is whatever
## SecurityCameraTablet.CAMS says. Read from the shipping script rather than
## copied here; the literal is only the fallback for an unreadable script.
const CAMERA_TABLET_SCRIPT := "res://game/SecurityCameraTablet.gd"
const CAMERA_TABLET_FEEDS_FALLBACK := 11

var _failed := false


func _init() -> void:
	print("==================================================")
	print("MUSEUM MAP VERIFICATION TEST")
	print("==================================================")

	var packed := load("res://scenes/FirstMuseumMap.tscn") as PackedScene
	if packed == null:
		_fail("Failed to load FirstMuseumMap.tscn as PackedScene")
		_quit(1)
		return

	var map_root: Node = packed.instantiate()
	if map_root == null:
		_fail("FirstMuseumMap.tscn instantiated to null")
		_quit(1)
		return
	if not map_root.has_method("build_map"):
		_fail("Instantiated root is not a FirstMuseumMap (no build_map())")
		_quit(1)
		return

	# FirstMuseumMap._ready() runs once the node is in the SceneTree.
	root.add_child(map_root)
	await process_frame
	await process_frame  # let _ready() + build_map() complete

	_verify(map_root)
	_verify_localization()

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

	# Rooms: all 11 that build_map() emits. Planetarium and Restoration Lab were
	# missing from this list, so deleting either of them went unnoticed.
	var room_names := [
		"Entrance Zone", "Central Atrium", "Watcher Office",
		"Equipment Storage", "Archive", "Gravity Wing A",
		"Time Wing B", "Space Wing C Locked", "Mass Wing D Locked",
		"Planetarium", "Restoration Lab",
	]
	var found_rooms := 0
	for rname in room_names:
		if generated.get_node_or_null(rname) != null:
			found_rooms += 1
		else:
			_fail("Room missing: %s" % rname)
	if found_rooms == room_names.size():
		_ok("All %d rooms present" % found_rooms)

	# Door frames. Prefix counting also matched the generated "... Collision" and
	# "... CollisionShape" children, so the old >0 threshold only tripped if every
	# doorway vanished at once. Check each doorway build_map() dresses.
	# _add_door_frame() names its header "Door Frame Header %s" % [center]; Node
	# strips the characters . : @ / " % from any name it is given, so the same
	# validate_node_name() pass is applied here. Without it the lookup would break
	# the moment Vector3.to_string() emits a decimal point.
	var doorway_centers := [
		Vector3(0, 0, 15), Vector3(-15, 0, 0), Vector3(15, 0, 0), Vector3(0, 0, -15),
		Vector3(-25, 0, 7), Vector3(-25, 0, -7), Vector3(0, 0, -33),
		Vector3(-25, 0, 17), Vector3(0, 0, 35), Vector3(13, 0, -24), Vector3(41, 0, 0),
	]
	var door_frames := 0
	for centre in doorway_centers:
		var header: String = ("Door Frame Header %s" % [centre]).validate_node_name()
		if generated.find_child(header, true, false) != null:
			door_frames += 1
		else:
			_fail("Door frame missing at %s" % [centre])
	if door_frames == doorway_centers.size():
		_ok("Door frames built: %d" % door_frames)

	# Exhibits: each has a "Glass Case".
	var glass_cases := _count_contains(generated, "Glass Case")
	if glass_cases < 8:
		_fail("Only %d glass cases (expected >=8 exhibits)" % glass_cases)
	else:
		_ok("Exhibits built: %d" % glass_cases)

	# Security cameras. Counted by group membership, not by node name: the mount
	# is either an imported .fbx root or a procedural fallback pivot, and its
	# name is a display string. Scoped to GeneratedMap because get_nodes_in_group
	# is tree-wide and other tests put a second museum under the same root.
	var cams := 0
	for node in get_nodes_in_group("security_camera"):
		if generated.is_ancestor_of(node):
			cams += 1
	# The contract is equality, not a floor: SecurityCameraTablet.CAMS addresses
	# its feeds by index, so one physical mount must exist per entry. A >= check
	# let the last three posts (Planetarium, Restoration Lab, Mass Wing D) vanish
	# while the tablet still offered three feeds with nothing behind them, and it
	# would equally miss the two files drifting apart in the other direction.
	var expected_cams := _tablet_feed_count()
	if cams != expected_cams:
		_fail("Security cameras: map emits %d nodes in group 'security_camera' but SecurityCameraTablet.CAMS declares %d feeds"
			% [cams, expected_cams])
	else:
		_ok("Security cameras built: %d (matches SecurityCameraTablet.CAMS)" % cams)

	# Locked doors. Substring counting also matched the rooms named "... Locked"
	# and every descendant of them, so the old check could never drop below 2 and
	# its _fail branch (which was also missing its %d argument) was dead code.
	# Assert the exact nodes unlock_wing() resolves with find_child() instead.
	var locked_door_names := [
		"Wing C Locked Blast Door",
		"Wing D Locked Blast Door",
		"Causality Wing E Sealed Door",
	]
	var locked := 0
	for door_name in locked_door_names:
		if generated.find_child(door_name, true, false) != null:
			locked += 1
		else:
			_fail("Locked door missing: %s" % door_name)
	if locked == locked_door_names.size():
		_ok("Locked doors built: %d" % locked)

	# Shared-wall sanity, measured instead of asserted in prose. _add_room insets
	# each wall by half a thickness, so the Atrium east slab sits at x=14.825 and
	# the Gravity Wing west slab at x=15.175; both touching faces land on x=15.
	# The half-thickness is taken off each slab's own BoxMesh, so the check reads
	# the geometry that actually shipped instead of a second copy of the constant.
	var atrium_east := generated.find_child("Central Atrium East Wall Near Segment", true, false) as MeshInstance3D
	var gravity_west := generated.find_child("Gravity Wing A West Wall Near Segment", true, false) as MeshInstance3D
	if atrium_east == null or gravity_west == null:
		_fail("Shared-wall check: Atrium east / Gravity west segment not found")
	else:
		var atrium_box := atrium_east.mesh as BoxMesh
		var gravity_box := gravity_west.mesh as BoxMesh
		if atrium_box == null or gravity_box == null:
			_fail("Shared-wall check: wall segments are not box slabs")
		else:
			var seam_a: float = atrium_east.global_position.x + atrium_box.size.x * 0.5
			var seam_b: float = gravity_west.global_position.x - gravity_box.size.x * 0.5
			if absf(seam_a - 15.0) > 0.01 or absf(seam_b - 15.0) > 0.01:
				_fail("Atrium/Gravity shared wall does not meet at x=15 (%.3f vs %.3f)" % [seam_a, seam_b])
			else:
				_ok("Atrium/Gravity shared wall coincides at x=15")


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


func _count_contains(node: Node, substr: String) -> int:
	var total := 0
	if node.name.find(substr) != -1:
		total += 1
	for child in node.get_children():
		total += _count_contains(child, substr)
	return total


# How many feeds the tablet offers. Read off the shipping script instead of
# duplicating the number here, so the assertion follows CAMS when a camera post
# is added or retired and fails loudly when only one of the two files moves.
func _tablet_feed_count() -> int:
	var tablet := load(CAMERA_TABLET_SCRIPT) as Script
	if tablet == null:
		print("⚠  Cannot load %s — assuming %d camera feeds"
			% [CAMERA_TABLET_SCRIPT, CAMERA_TABLET_FEEDS_FALLBACK])
		return CAMERA_TABLET_FEEDS_FALLBACK
	var feeds: Variant = tablet.get_script_constant_map().get("CAMS", null)
	if typeof(feeds) != TYPE_ARRAY:
		print("⚠  %s exposes no CAMS array — assuming %d camera feeds"
			% [CAMERA_TABLET_SCRIPT, CAMERA_TABLET_FEEDS_FALLBACK])
		return CAMERA_TABLET_FEEDS_FALLBACK
	return (feeds as Array).size()


# A key the code asks for that the catalogue cannot answer reaches the player as
# the raw KEY, and any row fed to `%` with the wrong specifier count aborts the
# calling function mid-body (see game/Loc.gd). This sweep covers the first case
# only -- it asserts PRESENCE: every key literal used under res://game has a row
# in game.csv. It does not look at format specifiers at all.
# tools/check_localization.py runs the same presence scan and adds the
# specifier-arity cross-check on top, so it is the stricter of the two. The
# shared halves must stay in step: KEY_LITERAL_PATTERN mirrors KEY_LITERAL_RE and
# NON_KEY_LITERALS mirrors NOT_KEYS, or a literal excused here is demanded there.
func _verify_localization() -> void:
	var catalogue := _catalogue_keys()
	if catalogue.is_empty():
		_fail("Localization: %s is empty or unreadable" % LOCALIZATION_CSV)
		return
	var sources := _gd_sources(LOCALIZATION_CODE_DIR)
	if sources.is_empty():
		_fail("Localization: no .gd sources found under %s" % LOCALIZATION_CODE_DIR)
		return

	var key_regex := RegEx.new()
	if key_regex.compile(KEY_LITERAL_PATTERN) != OK:
		_fail("Localization: key literal pattern did not compile")
		return

	var seen := {}
	var missing := PackedStringArray()
	for path in sources:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_fail("Localization: cannot read %s" % path)
			continue
		var line_no := 0
		while not file.eof_reached():
			line_no += 1
			for found in key_regex.search_all(file.get_line()):
				var key := found.get_string(1)
				if key in NON_KEY_LITERALS or seen.has(key):
					continue
				seen[key] = true
				if not catalogue.has(key):
					missing.append("%s (%s:%d)" % [key, path, line_no])
		file.close()

	if missing.is_empty():
		_ok("Localization: %d keys used in code, all answered by %d catalogue rows"
			% [seen.size(), catalogue.size()])
	else:
		_fail("Localization: %d key(s) absent from game.csv -> %s"
			% [missing.size(), ", ".join(missing)])


# First column of the catalogue. get_csv_line() is used rather than split(",")
# because translated rows contain commas inside quoted fields.
func _catalogue_keys() -> Dictionary:
	var keys := {}
	var file := FileAccess.open(LOCALIZATION_CSV, FileAccess.READ)
	if file == null:
		return keys
	var header := true
	while not file.eof_reached():
		var row := file.get_csv_line()
		if header:
			header = false
			continue
		if row.is_empty():
			continue
		var key := row[0].strip_edges()
		if key != "":
			keys[key] = true
	file.close()
	return keys


func _gd_sources(dir_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				found.append_array(_gd_sources(dir_path.path_join(entry)))
		elif entry.ends_with(".gd") and not entry.begins_with(NON_UI_SOURCE_PREFIX):
			found.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found


func _ok(text: String) -> void:
	print("✓ ", text)


func _fail(text: String) -> void:
	_failed = true
	print("❌ ", text)


func _quit(code := 0) -> void:
	quit(code)
