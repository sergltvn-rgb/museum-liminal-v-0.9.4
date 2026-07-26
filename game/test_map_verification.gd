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

## Owner of the exhibit -> required-camera mapping the night-2 scan depends on.
const EXHIBIT_PUZZLE_SCRIPT := "res://game/ExhibitPuzzleController.gd"

## Group every CCTV mount joins (FirstMuseumMap.SECURITY_CAMERA_GROUP). The mount
## is either an imported .fbx root or a procedural pivot, so it can only be found
## by group, never by class or by name.
const SECURITY_CAMERA_GROUP := "security_camera"

## A mount and the feed it drives are authored from the same literal, so this
## tolerance exists to absorb float round-tripping, not to excuse a moved post.
const CAMERA_POSITION_EPSILON := 0.01

## The housing's yaw and the yaw implied by the feed's aim target must agree to
## within a degree. Past that the operator watches one room while the prop on the
## wall points at another, which is exactly what a node count cannot see.
const CAMERA_YAW_EPSILON_DEG := 1.0

## Mini-map rectangles are drawn from the same centres and sizes _add_room builds.
const ROOM_RECT_EPSILON := 0.01

## Anything a sightline ray meets within this radius of the exhibit's own anchor
## is that exhibit's dressing, not an occluder: the glass case is 2.25 m across
## (1.59 m corner to corner in plan) and the pedestal 2.8 m, and both carry
## colliders. Hits further out than this are things standing in the way.
const EXHIBIT_SELF_CLEARANCE := 1.7

## How close a placed model's node has to sit to an exhibit's anchor to BE that
## exhibit. MapModels.place() drops the model on the anchor outright, so this is
## an equality test with room for float round-tripping only.
const MODEL_ORIGIN_EPSILON := 0.01

## Night handed to the exhibit chooser while reading the exhibit -> camera
## mapping. Deliberately higher than any wing's unlock night so that every
## exhibit is a candidate and none of them is missed.
const ALL_WINGS_NIGHT := 9

## Draws allowed while sampling that (random) chooser. Collecting a dozen
## exhibits takes around forty draws; the cap only bounds a pathological run.
const EXHIBIT_SAMPLE_DRAWS := 5000

var _failed := false
var _digits := RegEx.new()


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

	var generated: Node = map_root.get_node_or_null("GeneratedMap")
	if generated != null:
		# Resolved once: both cross-checks below need the mounts, and a mount that
		# cannot be identified should be reported once, not once per check.
		var mounts := _camera_mounts(generated)
		_verify_camera_geometry(mounts)
		_verify_minimap_rooms(generated)
		# The sightline sweep queries the physics world, which is only readable
		# once a physics step has run and the freshly added static bodies have
		# been flushed into the space.
		await physics_frame
		_verify_exhibit_sightlines(generated, mounts)

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
	for node in get_nodes_in_group(SECURITY_CAMERA_GROUP):
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


# One constant off a shipping script, or null. Every cross-check below reads its
# numbers this way instead of keeping a second copy of them here, so the test
# follows the game when a post moves and fails only when the two files disagree.
func _script_constant(script_path: String, constant_name: String) -> Variant:
	var script := load(script_path) as Script
	if script == null:
		_fail("Cannot load %s" % script_path)
		return null
	var constants := script.get_script_constant_map()
	if constants.is_empty():
		# A script with a parse error still loads, it just carries nothing.
		_fail("%s declares no constants at all — it did not compile" % script_path)
		return null
	var value: Variant = constants.get(constant_name, null)
	if value == null:
		_fail("%s exposes no %s constant" % [script_path, constant_name])
	return value


# ---------------------------------------------------------------------------
# 1. Geometry agreement between the tablet's feeds and the map's mounts.
#
# Counting cameras proves eleven mounts exist; it says nothing about where they
# are or which way they face. The tablet builds each feed at CAMS[i].pos and
# points it at CAMS[i].target, while _add_cameras builds the housing the player
# sees from its own literals. When those drift apart the feed shows a room the
# prop is not aimed at, and no count notices.
func _verify_camera_geometry(mounts: Dictionary) -> void:
	var feeds: Variant = _script_constant(CAMERA_TABLET_SCRIPT, "CAMS")
	if typeof(feeds) != TYPE_ARRAY:
		return
	if mounts.is_empty():
		_fail("Camera geometry: no mounts found in group '%s'" % SECURITY_CAMERA_GROUP)
		return

	var agreed := 0
	for feed_variant in (feeds as Array):
		var feed: Dictionary = feed_variant
		var feed_id := str(feed.get("id", "?"))
		var post := _post_number(feed_id)
		if post < 0:
			_fail("Camera geometry: feed id %s carries no post number" % feed_id)
			continue
		if not mounts.has(post):
			_fail("Camera geometry: %s has no mount — the map builds no post %02d"
				% [feed_id, post])
			continue
		var mount: Node3D = mounts[post]
		var feed_pos: Vector3 = feed.get("pos", Vector3.ZERO)
		var mount_pos := mount.global_position
		var offset := mount_pos.distance_to(feed_pos)
		var placed := offset <= CAMERA_POSITION_EPSILON
		if not placed:
			_fail("Camera geometry: %s feed sits at %v but its mount '%s' sits at %v (%.3f m apart)"
				% [feed_id, feed_pos, mount.name, mount_pos, offset])

		# Yaw the feed's aim target implies. The tablet aims with look_at(), which
		# points -Z at the target, and a node yawed by θ has -Z = (-sin θ, 0, -cos θ).
		var feed_target: Vector3 = feed.get("target", feed_pos)
		var aim := Vector2(feed_target.x - feed_pos.x, feed_target.z - feed_pos.z)
		if aim.length() < 0.001:
			_fail("Camera geometry: %s aims at its own mount, so it implies no yaw" % feed_id)
			continue
		var feed_yaw := rad_to_deg(atan2(-aim.x, -aim.y))
		# The housing's own yaw, as _camera() set it: the raw euler, not a value
		# recomposed from the basis, because an imported .fbx root carries a pitch
		# from its import and euler decomposition is ambiguous at +-90 deg of it.
		var mount_yaw := mount.rotation_degrees.y
		var drift := absf(wrapf(feed_yaw - mount_yaw, -180.0, 180.0))
		if drift > CAMERA_YAW_EPSILON_DEG:
			_fail("Camera geometry: %s feed looks along yaw %.2f deg (target %v) but its mount '%s' is yawed %.2f deg — %.2f deg apart"
				% [feed_id, feed_yaw, feed_target, mount.name, mount_yaw, drift])
		elif placed:
			agreed += 1
	if agreed == (feeds as Array).size():
		_ok("Camera geometry: all %d feeds sit on their mount and aim where it points" % agreed)


# Every CCTV mount under GeneratedMap, keyed by the post number in its name
# ("Камера 07 - ..." -> 7). Scoped to GeneratedMap because get_nodes_in_group is
# tree-wide and the tablet in the same scene builds its own Camera3D nodes.
func _camera_mounts(generated: Node) -> Dictionary:
	var mounts := {}
	for node in get_nodes_in_group(SECURITY_CAMERA_GROUP):
		var mount := node as Node3D
		if mount == null or not generated.is_ancestor_of(mount):
			continue
		var post := _post_number(mount.name)
		if post < 0:
			_fail("Camera mount '%s' carries no post number in its name" % mount.name)
			continue
		if mounts.has(post):
			_fail("Two camera mounts claim post %02d: '%s' and '%s'"
				% [post, (mounts[post] as Node3D).name, mount.name])
			continue
		mounts[post] = mount
	return mounts


# First run of digits in a name: "CAM 07" and "Камера 07 - Space Wing C Door"
# both answer 7. -1 when the name carries no number at all.
func _post_number(text: String) -> int:
	if _digits.get_pattern() == "" and _digits.compile("([0-9]+)") != OK:
		return -1
	var found := _digits.search(text)
	if found == null:
		return -1
	return int(found.get_string(1))


# ---------------------------------------------------------------------------
# 2. Mini-map agreement. Every rectangle the tablet paints is a room the player
# walks through, drawn from a centre and a size the tablet keeps in its own
# ROOMS table. Move or resize a room in build_map and the mini-map silently
# keeps painting the old footprint.
func _verify_minimap_rooms(generated: Node) -> void:
	var rooms: Variant = _script_constant(CAMERA_TABLET_SCRIPT, "ROOMS")
	if typeof(rooms) != TYPE_ARRAY:
		return
	var built := _built_rooms(generated)
	if built.is_empty():
		_fail("Mini-map: no rooms found under GeneratedMap")
		return

	var matched := {}
	var agreed := 0
	for entry_variant in (rooms as Array):
		var entry: Array = entry_variant
		var key := str(entry[0])
		var centre: Vector2 = entry[1]
		var size: Vector2 = entry[2]
		# ROOMS keys are catalogue keys and room nodes are named in English, so
		# the two tables can only be paired by position: take the nearest room
		# built and then demand that it actually coincides.
		var nearest := ""
		var nearest_gap := INF
		for room_name in built:
			var gap: float = (built[room_name]["centre"] as Vector2).distance_to(centre)
			if gap < nearest_gap:
				nearest_gap = gap
				nearest = room_name
		if nearest_gap > ROOM_RECT_EPSILON:
			_fail("Mini-map: %s is drawn at %v but no room stands there — nearest is '%s' at %v (%.3f m away)"
				% [key, centre, nearest, built[nearest]["centre"], nearest_gap])
			continue
		if matched.has(nearest):
			_fail("Mini-map: %s and %s both claim room '%s' at %v"
				% [matched[nearest], key, nearest, centre])
			continue
		matched[nearest] = key
		var built_size: Vector2 = built[nearest]["size"]
		if absf(built_size.x - size.x) > ROOM_RECT_EPSILON \
				or absf(built_size.y - size.y) > ROOM_RECT_EPSILON:
			_fail("Mini-map: %s is drawn %v but room '%s' is built %v"
				% [key, size, nearest, built_size])
			continue
		agreed += 1
	for room_name in built:
		if not matched.has(room_name):
			_fail("Mini-map: room '%s' at %v is built but the tablet draws no rectangle for it"
				% [room_name, built[room_name]["centre"]])
	if agreed == (rooms as Array).size() and matched.size() == built.size():
		_ok("Mini-map: all %d rectangles match the room they stand for" % agreed)


# Rooms as build_map left them: a direct Node3D child of GeneratedMap carrying
# the "<name> Floor" slab _add_room lays down. The slab is what fixes the room's
# footprint, so its BoxMesh is read for the size rather than the call literal.
func _built_rooms(generated: Node) -> Dictionary:
	var rooms := {}
	for child in generated.get_children():
		var room := child as Node3D
		if room == null or room.get_class() != "Node3D":
			continue
		var slab := room.get_node_or_null(NodePath("%s Floor" % room.name)) as MeshInstance3D
		if slab == null:
			continue
		var box := slab.mesh as BoxMesh
		if box == null:
			continue
		rooms[room.name] = {
			"centre": Vector2(room.global_position.x, room.global_position.z),
			"size": Vector2(box.size.x, box.size.z),
		}
	return rooms


# ---------------------------------------------------------------------------
# 3. Line of sight. From night 2 the incident cannot be closed until the player
# watches the affected exhibit on the camera ExhibitPuzzleController names for
# it. If a wall stands between that camera and that exhibit the shift is
# unwinnable, and nothing in the scene tree looks wrong: both nodes exist.
func _verify_exhibit_sightlines(generated: Node, mounts: Dictionary) -> void:
	var exhibits: Variant = _script_constant(EXHIBIT_PUZZLE_SCRIPT, "EXHIBITS")
	if typeof(exhibits) != TYPE_DICTIONARY:
		return
	var feeds: Variant = _script_constant(CAMERA_TABLET_SCRIPT, "CAMS")
	if typeof(feeds) != TYPE_ARRAY:
		return
	var required := _required_cameras(exhibits as Dictionary)
	if required.is_empty():
		return
	var space := root.world_3d.direct_space_state
	if space == null:
		_fail("Sightlines: no 3D physics space to cast through")
		return

	var visible := 0
	var checked := 0
	for family_variant in (exhibits as Dictionary).values():
		for entry_variant in (family_variant as Array):
			var entry: Dictionary = entry_variant
			var exhibit := str(entry.get("name", "?"))
			checked += 1
			if not required.has(exhibit):
				_fail("Sightline: %s is never offered by ExhibitPuzzleController, so no camera is required for it"
					% exhibit)
				continue
			var index: int = required[exhibit]
			if index < 0 or index >= (feeds as Array).size():
				_fail("Sightline: %s requires camera index %d but the tablet declares %d feeds"
					% [exhibit, index, (feeds as Array).size()])
				continue
			var feed: Dictionary = (feeds as Array)[index]
			var feed_id := str(feed.get("id", "?"))
			var post := _post_number(feed_id)
			if not mounts.has(post):
				_fail("Sightline: %s requires %s but the map builds no mount for that post"
					% [exhibit, feed_id])
				continue
			var mount: Node3D = mounts[post]
			var anchor := generated.find_child(str(entry.get("anchor", "")), true, false) as Node3D
			if anchor == null:
				_fail("Sightline: %s has no anchor '%s' in the built map"
					% [exhibit, entry.get("anchor", "")])
				continue

			var from := mount.global_position
			var to := anchor.global_position
			var query := PhysicsRayQueryParameters3D.create(from, to)
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				visible += 1
				continue
			var where: Vector3 = hit["position"]
			var slack := where.distance_to(to)
			var blocker := hit["collider"] as Node
			# Reaching the exhibit counts as seeing it. That happens two ways:
			# the ray lands on the exhibit's own plinth, case or body, all of
			# which stand within a case-width of the anchor; or it lands on the
			# exhibit's imported model, whose mesh may be far wider than the case
			# and is split into several separately hulled parts. The second is
			# recognised by ownership, not by distance: MapModels.place() drops
			# the model in as one node of GeneratedMap sitting exactly on the
			# anchor, so every collider under that node is the exhibit itself.
			if slack <= EXHIBIT_SELF_CLEARANCE or _stands_at(generated, blocker, to):
				visible += 1
				continue
			_fail("Sightline: %s cannot be seen from %s. Ray %v -> %v is stopped at %v by %s, %.2f m short of the exhibit (anything within %.2f m would be the exhibit itself)"
				% [exhibit, feed_id, from, to, where, _blocker_name(generated, blocker),
					slack, EXHIBIT_SELF_CLEARANCE])
	if visible == checked:
		_ok("Sightlines: all %d exhibits are visible from their required camera" % visible)


# True when `blocker` belongs to the one piece of the map that build_map parented
# straight to GeneratedMap at `spot`. Everything an imported model brings with it
# -- its meshes and the convex hulls generated for them -- hangs under that one
# node, however deeply nested.
func _stands_at(generated: Node, blocker: Node, spot: Vector3) -> bool:
	if blocker == null or not generated.is_ancestor_of(blocker):
		return false
	var owner_node := blocker
	while owner_node.get_parent() != generated:
		owner_node = owner_node.get_parent()
	var placed := owner_node as Node3D
	return placed != null \
		and placed.global_position.distance_to(spot) <= MODEL_ORIGIN_EPSILON


# What stopped the ray, in terms someone can act on. Procedural geometry names
# its body after the mesh ("... Collision"), but collision generated for an
# imported model is called "Mesh<N>_col", which says nothing on its own -- so the
# path down from GeneratedMap is printed with it.
func _blocker_name(generated: Node, blocker: Node) -> String:
	if blocker == null:
		return "<freed body>"
	if generated.is_ancestor_of(blocker):
		return "'%s' (%s)" % [blocker.name, generated.get_path_to(blocker)]
	return "'%s' (%s)" % [blocker.name, blocker.get_path()]


# The exhibit -> camera index mapping, read off ExhibitPuzzleController itself.
# The mapping is not a constant: _choose_exhibit() stamps "camera" onto the
# candidate it returns, so the table is sampled out of that function rather than
# copied here, and it follows the shipping rule when the rule is rewritten.
func _required_cameras(exhibits: Dictionary) -> Dictionary:
	var mapping := {}
	var total := 0
	for family in exhibits.values():
		total += (family as Array).size()
	if total == 0:
		_fail("Sightlines: ExhibitPuzzleController.EXHIBITS is empty")
		return mapping
	var script := load(EXHIBIT_PUZZLE_SCRIPT) as Script
	if script == null:
		_fail("Sightlines: cannot load %s" % EXHIBIT_PUZZLE_SCRIPT)
		return mapping
	var controller: Object = script.new()
	if controller == null:
		_fail("Sightlines: %s could not be instantiated" % EXHIBIT_PUZZLE_SCRIPT)
		return mapping
	if not controller.has_method("_choose_exhibit"):
		_fail("Sightlines: %s no longer offers _choose_exhibit() — the test cannot read the exhibit -> camera mapping"
			% EXHIBIT_PUZZLE_SCRIPT)
		_release(controller)
		return mapping
	for i in range(EXHIBIT_SAMPLE_DRAWS):
		var picked: Variant = controller.call("_choose_exhibit", ALL_WINGS_NIGHT)
		if typeof(picked) != TYPE_DICTIONARY:
			break
		var name_key := str((picked as Dictionary).get("name", ""))
		if name_key != "" and not mapping.has(name_key):
			mapping[name_key] = int((picked as Dictionary).get("camera", -1))
		if mapping.size() == total:
			break
	_release(controller)
	if mapping.size() != total:
		_fail("Sightlines: only %d of %d exhibits were ever offered by _choose_exhibit(night %d)"
			% [mapping.size(), total, ALL_WINGS_NIGHT])
	return mapping


# script.new() on a Node script hands back a node that never entered the tree, so
# nothing else will ever free it. A RefCounted one frees itself.
func _release(instance: Object) -> void:
	if instance == null or instance is RefCounted:
		return
	instance.free()


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
