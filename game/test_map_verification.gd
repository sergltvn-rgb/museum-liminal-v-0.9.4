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

## Storage-side double doors are visual geometry, but a closed-looking panel in
## a collisionless doorway lies to the player. Keep the three service-room
## thresholds clear through the full body-height band.
const STORAGE_DOOR_CENTERS := [
	Vector3(-25, 0, 7), Vector3(-25, 0, -7), Vector3(-25, 0, 17),
]
const DOOR_VISUAL_CLEARANCE := 0.75
const DOOR_CLEARANCE_BOTTOM := 0.15
const DOOR_CLEARANCE_TOP := 2.2
## A radius from the opening's centre point is NOT a corridor, and a player who
## could not walk into Equipment Storage proved it: Office Records Credenza Lid
## measured 0.820 m from the centre -- over the visual gate above -- while
## spanning the whole opening and leaving 0.645 m between itself and the wall,
## against a 0.70 m capsule. So also measure the channel a body walks down:
## capsule width plus a shoulder of slack, a metre of run-up either side. All
## three service doorways sit in walls that run along X, so the channel runs
## along Z.
const DOOR_WALK_WIDTH := 0.90
const DOOR_WALK_DEPTH := 1.00

## Owner of the office wall's panel -> feed layout (stage 10.3).
const MONITOR_WALL_SCRIPT := "res://game/MonitorWall.gd"
## Groups the wall and the bank it dresses join, which is the only way either is
## found: both are built procedurally, so neither has a stable node path.
const MONITOR_WALL_GROUP := "monitor_wall"
const MONITOR_BANK_GROUP := "monitor_bank"
## Consumer of the wall's watched_feed() contract -- the night-two source scan.
const ENHANCEMENTS_NODE := "GameplayEnhancements"
## Cycling feeds must stay reachable without a keyboard. InputBootstrap binds
## these two to the shoulder triggers as well as to , and .
const CAMERA_CYCLE_ACTIONS := ["cam_prev", "cam_next"]

## The anomaly terminal, stage A: the office device that tells the operator what
## to fetch. Found by node name because GameManager builds it under GeneratedMap.
const TERMINAL_ROOT_NAME := "Anomaly Terminal"
const TERMINAL_SCREEN_NAME := "Anomaly Terminal Screen"
const TERMINAL_READOUT_NAME := "Anomaly Terminal Readout"
const TERMINAL_ORDER_NAME := "Anomaly Terminal Order"
## Top face of the alarm console the head is mounted on: pedestal 0.55 +- 0.55,
## console box 1.18 +- 0.11. The device's lowest part must MEET this surface --
## it used to float 0.86 m above it, which is why it read as a coloured
## rectangle parked in mid-air instead of as equipment.
const TERMINAL_CONSOLE_TOP_Y := 1.29
## How far the lowest part may sit above the console before it is floating again.
## Negative overlap (seating into the console) is fine and expected.
const TERMINAL_MOUNT_TOLERANCE := 0.02
## Slack allowed between the text stack and the lit face it must stay inside.
## Measured worst case is 0.712 m of text on a 0.740 m face.
const TERMINAL_TEXT_MARGIN := 0.0

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
		_verify_forecourt_lamps(generated)
		_verify_exterior_fixture_lights(generated)
		_verify_block3_landscape(generated)
		_verify_block3_parking(generated)
		_verify_arrival_exit(generated)
		_verify_drive_alignment(map_root, generated)
		_verify_court_composition(generated)
		_verify_office_fixtures(generated)
		_verify_entrance_approach(generated)
		_verify_plaza_footing(generated)
		_verify_planetarium_composition(generated)
		# 10.6. MonitorWall assembles itself in _process and not in _ready --
		# the player, the bank and the tablet are all created in the same frame
		# it is -- so it is asserted after one more idle frame, not inside
		# _verify().
		await process_frame
		await _verify_monitor_wall(map_root, generated)
		_verify_camera_cycle_actions()
		# The sightline sweep queries the physics world, which is only readable
		# once a physics step has run and the freshly added static bodies have
		# been flushed into the space.
		await physics_frame
		_verify_exhibit_sightlines(generated, mounts)
		# Last of the world checks on purpose: it opens a real incident to read
		# what the screen then says, and that lights the alarm state up.
		await _verify_anomaly_terminal(map_root, generated)
		# Before the blackout on purpose: this one teleports the player out to
		# the forecourt and holds a key down, which wants a lit, quiet world.
		await _verify_crouch()
		await _verify_curator_cover(map_root)
		await _verify_route_covers(map_root, generated)
		await _verify_noise_model(map_root)
		await _verify_curator_states(map_root)
		await _verify_hide_spots()
		await _verify_rift_gate(map_root)
		# Dead last: this one walks the player into the office and cuts the
		# power, which is a world state no later check should have to expect.
		await _verify_blackout(map_root, generated)

	_verify_localization()
	_verify_incident_signs()
	_verify_rift_shift()
	_verify_curator_pace()
	_verify_wrong_tool_cost()
	_verify_sign_matrix()

	if _failed:
		print("\n❌ VERIFICATION FAILED — see errors above")
		_quit(1)
	else:
		print("\n✅ ALL CHECKS PASSED")
		_quit(0)


## BLOCK 3: THE SIX FORECOURT LAMPS ARE FINISHED FIXTURES, AND THEY ARE LIT
##
## The visible walk from the parked car to the portico used to be lined by six
## cylinders with glowing boxes on top. Block 3 replaced those placeholders with
## ExteriorProps.build_lamp_post at the authored coordinates.
##
## REWRITTEN 2026-08-13 with the owner's word, the same way the parking block
## was: build_lamp_post now places the lp_alley_lamp module and keeps its own
## primitives only as a fallback, so the old ["Pedestal", "Column",
## "Lantern Glass"] child-name list could never match the finished product. It
## would have failed the model and passed a bare stub carrying three correctly
## named empty boxes -- the exact inversion of what a check is for. What the
## walk actually needs is asserted instead, and it holds for the module and for
## the primitives alike:
##   1. a post standing at each authored position,
##   2. carrying real geometry rather than being an empty Node3D,
##   3. tall enough to be a lamp post at all (module 4.188 m, primitives
##      4.256 m; a wheel stop is 0.18 m and a bollard 0.845 m),
##   4. and carrying an emissive lantern -- the one part the opaque model atlas
##      cannot supply, and the one that decides whether this walk reads at all
##      after dark.
## Point 4 is the point: a mesh swap that photographs correctly at noon and
## leaves the approach pitch black would otherwise ship green.
const FORECOURT_LAMP_POSITIONS := [
	Vector2(-4.5, 39.5), Vector2(4.5, 39.5),
	Vector2(-4.5, 45.0), Vector2(4.5, 45.0),
	Vector2(-4.5, 50.5), Vector2(4.5, 50.5),
]
const FORECOURT_LAMP_EPSILON := 0.02
## Measured from the fixture's own origin, so it reads the same on the forecourt
## (y 0.0) and on the ring road (y -0.02). Both branches clear 4.18 m, so this
## gate only ever catches something that is not a lamp post.
const FORECOURT_LAMP_MIN_HEIGHT := 4.0


func _verify_forecourt_lamps(generated: Node) -> void:
	var found: Array[bool] = []
	found.resize(FORECOURT_LAMP_POSITIONS.size())
	found.fill(false)
	var bare: Array[String] = []
	var stunted: Array[String] = []
	var dark: Array[String] = []
	for candidate in generated.find_children("Country Lamp*", "Node3D", true, false):
		var lamp := candidate as Node3D
		if lamp == null:
			continue
		var xz := Vector2(lamp.global_position.x, lamp.global_position.z)
		for i in range(FORECOURT_LAMP_POSITIONS.size()):
			if xz.distance_to(FORECOURT_LAMP_POSITIONS[i]) > FORECOURT_LAMP_EPSILON:
				continue
			found[i] = true
			# The primitive fixture is a tree of meshes hung straight off the
			# root; the module keeps its mesh one level down. Collect either
			# shape and judge the whole post, not a node name.
			var meshes: Array[Node] = lamp.find_children(
				"*", "MeshInstance3D", true, false)
			if lamp is MeshInstance3D:
				meshes.append(lamp)
			if meshes.is_empty():
				bare.append("%s carries no mesh" % lamp.name)
				break
			var top := -INF
			var lit := false
			for node in meshes:
				var mesh_node := node as MeshInstance3D
				if mesh_node == null:
					continue
				var box: AABB = mesh_node.global_transform * mesh_node.get_aabb()
				top = maxf(top, box.end.y)
				# Imported atlas materials arrive on the mesh itself and carry no
				# emission; the lantern glow is a material_override this project
				# builds by hand, in both branches. So that is what is asked for.
				var mat := mesh_node.material_override as StandardMaterial3D
				if mat != null and mat.emission_enabled \
						and mat.emission_energy_multiplier > 0.0:
					lit = true
			var height := top - lamp.global_position.y
			if height < FORECOURT_LAMP_MIN_HEIGHT:
				stunted.append("%s stands %.2f m" % [lamp.name, height])
			if not lit:
				dark.append(str(lamp.name))
			break
	var missing: Array[String] = []
	for i in range(found.size()):
		if not found[i]:
			missing.append(str(FORECOURT_LAMP_POSITIONS[i]))
	if not missing.is_empty() or not bare.is_empty() \
			or not stunted.is_empty() or not dark.is_empty():
		_fail("Forecourt lamps: missing [%s], empty [%s], too short [%s], unlit [%s]"
			% [", ".join(missing), ", ".join(bare), ", ".join(stunted),
				", ".join(dark)])
	else:
		_ok("Forecourt lamps: six fixtures over %.1f m, each with a lit lantern, "
			% FORECOURT_LAMP_MIN_HEIGHT + "at the authored positions")


## The street modules and gate piers used to carry dark atlas glass only. An
## emissive mesh is not illumination, so require both the readable source and a
## live Light3D on every authored fixture.
func _verify_exterior_fixture_lights(generated: Node) -> void:
	var street_lights := generated.find_children(
		"Street Lamp Light", "SpotLight3D", true, false)
	var street_glows := generated.find_children(
		"Street Lamp Glow", "MeshInstance3D", true, false)
	var gate_lights := generated.find_children(
		"Court Gate Light*", "OmniLight3D", true, false)
	var gate_glows := generated.find_children(
		"Gate Lantern Glow", "MeshInstance3D", true, false)
	var weak: Array[String] = []
	for node in street_lights:
		var spot := node as SpotLight3D
		if spot == null or not spot.visible or spot.light_energy < 5.9 \
				or spot.spot_range < 10.9 or spot.spot_angle < 67.9:
			weak.append(str(node.name))
	for node in gate_lights:
		var omni := node as OmniLight3D
		if omni == null or not omni.visible or omni.light_energy < 4.4 \
				or omni.omni_range < 7.4:
			weak.append(str(node.name))
	for node in street_glows + gate_glows:
		var glow := node as MeshInstance3D
		var mat := glow.material_override as StandardMaterial3D if glow != null else null
		if mat == null or not mat.emission_enabled \
				or mat.emission_energy_multiplier < 2.5:
			weak.append(str(node.name))
	var west := generated.find_child("Court Gate Lantern West", true, false) as Node3D
	var east := generated.find_child("Court Gate Lantern East", true, false) as Node3D
	var symmetry_ok := west != null and east != null \
		and absf(west.global_position.x + east.global_position.x) < 0.02 \
		and absf(west.global_position.y - east.global_position.y) < 0.02 \
		and absf(west.global_position.z - east.global_position.z) < 0.02
	if gate_lights.size() == 2:
		var gate_a := gate_lights[0] as OmniLight3D
		var gate_b := gate_lights[1] as OmniLight3D
		symmetry_ok = symmetry_ok and gate_a != null and gate_b != null \
			and absf(gate_a.light_energy - gate_b.light_energy) < 0.001 \
			and absf(gate_a.omni_range - gate_b.omni_range) < 0.001 \
			and gate_a.light_color.is_equal_approx(gate_b.light_color)
	if street_lights.size() != 6 or street_glows.size() != 6 \
			or gate_lights.size() != 2 or gate_glows.size() != 2 \
			or not weak.is_empty() or not symmetry_ok:
		_fail("Exterior fixture lights: street %d/%d, gate %d/%d, weak [%s], symmetric %s"
			% [street_lights.size(), street_glows.size(), gate_lights.size(),
				gate_glows.size(), ", ".join(weak), symmetry_ok])
	else:
		_ok("Exterior fixture lights: 6 strong street spots + 2 symmetric gate omnis, all live")


## BLOCK 3: THE OUTER TREE LINE AND ROAD VEHICLES USE EXTERIOR BUILDERS
##
## The remaining placeholders in the authored block-3 scope are four trunk/cone
## trees at x +-25 and two hand-built box vehicles on z 59. TreeLib-backed props
## are single named meshes; parked cars expose a body, cabin and windshield.
## Assert those finished products at the existing coordinates and reject the two
## legacy vehicle roots so adding builders without removing the boxes cannot pass.
const BLOCK3_TREE_POSITIONS := [
	Vector2(-25.0, 39.5), Vector2(-25.0, 50.5),
	Vector2(25.0, 39.5), Vector2(25.0, 50.5),
]
## Both cars moved with the street, and this constant has now had to move with
## them twice. z 59 was the centre of the old 64 x 8 m slab; P0 then put them
## in far-side pockets at z 66.2, which parked two visitor cars on the opposite
## bank of a seven-metre road with no crossing and no footway to reach them by.
## STREET_SCHEME_V2 deletes those pockets outright and gives the museum side a
## single 26 m kerbside strip at z 56.75, which is where they stand now --
## both WEST of the player's own spot at x 8.5, because the arrival cut-scene
## drives in from the east along that strip and would otherwise pass through
## them on camera. What this check is for is unchanged: finished ExteriorProps
## vehicles with a body, cabin and windshield, at the authored coordinates, and
## no legacy box roots.
const BLOCK3_ROAD_CAR_POSITIONS := [Vector2(-6.0, 56.75), Vector2(1.5, 56.75)]
const BLOCK3_PROP_EPSILON := 0.02
const BLOCK3_CAR_PARTS := ["Body", "Cabin", "Windshield"]
const BLOCK3_TREE_PREFIXES := ["Oak Tree", "Pine Tree", "Birch Tree"]
const BLOCK3_LEGACY_VEHICLES := ["Visitor Car Body", "Museum Service Van"]


func _verify_block3_landscape(generated: Node) -> void:
	var trees_found: Array[bool] = []
	trees_found.resize(BLOCK3_TREE_POSITIONS.size())
	trees_found.fill(false)
	for candidate in generated.find_children("*Tree*", "MeshInstance3D", true, false):
		var tree := candidate as MeshInstance3D
		if tree == null:
			continue
		var finished_tree := false
		for prefix: String in BLOCK3_TREE_PREFIXES:
			if str(tree.name).begins_with(prefix):
				finished_tree = true
				break
		if not finished_tree:
			continue
		var xz := Vector2(tree.global_position.x, tree.global_position.z)
		for i in range(BLOCK3_TREE_POSITIONS.size()):
			if xz.distance_to(BLOCK3_TREE_POSITIONS[i]) <= BLOCK3_PROP_EPSILON:
				trees_found[i] = true
				break

	var cars_found: Array[bool] = []
	cars_found.resize(BLOCK3_ROAD_CAR_POSITIONS.size())
	cars_found.fill(false)
	var malformed: Array[String] = []
	for candidate in generated.find_children("Parked Car*", "Node3D", true, false):
		var car := candidate as Node3D
		if car == null:
			continue
		var xz := Vector2(car.global_position.x, car.global_position.z)
		for i in range(BLOCK3_ROAD_CAR_POSITIONS.size()):
			if xz.distance_to(BLOCK3_ROAD_CAR_POSITIONS[i]) > BLOCK3_PROP_EPSILON:
				continue
			cars_found[i] = true
			for part: String in BLOCK3_CAR_PARTS:
				if car.get_node_or_null(part) == null:
					malformed.append("%s missing %s" % [car.name, part])
			break

	var missing_trees: Array[String] = []
	for i in range(trees_found.size()):
		if not trees_found[i]:
			missing_trees.append(str(BLOCK3_TREE_POSITIONS[i]))
	var missing_cars: Array[String] = []
	for i in range(cars_found.size()):
		if not cars_found[i]:
			missing_cars.append(str(BLOCK3_ROAD_CAR_POSITIONS[i]))
	var legacy: Array[String] = []
	for node_name: String in BLOCK3_LEGACY_VEHICLES:
		if generated.get_node_or_null(node_name) != null:
			legacy.append(node_name)
	if not missing_trees.is_empty() or not missing_cars.is_empty() \
			or not malformed.is_empty() or not legacy.is_empty():
		_fail("Block 3 landscape: missing trees [%s], cars [%s], malformed [%s], legacy [%s]"
			% [", ".join(missing_trees), ", ".join(missing_cars),
				", ".join(malformed), ", ".join(legacy)])
	else:
		_ok("Block 3 landscape: four TreeLib trees and two finished road cars")


## BLOCK 3: THE STAFF LOT IS A COMPOSITION, NOT AN ASPHALT PLACEHOLDER
##
## Five lines only enclosed four bays, the lot had one kerb, no sign or bollards,
## and the broad east strip was empty. The authored plan explicitly asks for
## better markings, kerbs, signs, posts and more cars. Pin the finished dressing
## while leaving the player's centre bay and door-side exit position untouched.
## REWRITTEN AGAIN 2026-08-13, same reason as the posts below, one step
## further. The lot is models now: lp_park_deck carries the asphalt, BOTH
## kerbs and all six bay separators in one mesh, and each sign is a single
## mesh. So "Parking Kerb East", "Parking Bay Line 5", "Parking Sign Pole",
## "Parking Sign Board", "Parking Exit Pole" and "Parking Exit Board" are not
## nodes any more -- that list would now fail the finished lot while still
## passing a bare asphalt slab, which is the wrong way round.
##
## What the list actually defended was: the lot is dressed at these three
## spots, not empty. That is pinned directly instead -- something standing at
## each authored position, carrying real geometry. The prefixes match both
## branches on purpose: the model is "Parking Sign", the fallback primitive is
## "Parking Sign Pole", and both begin with "Parking Sign".
const BLOCK3_PARKING_FIXTURES := [
	{"prefix": "Museum Parking Lot", "at": Vector2(42.4, 46.5)},
	{"prefix": "Parking Sign", "at": Vector2(51.9, 40.0)},
	{"prefix": "Parking Exit", "at": Vector2(33.2, 52.6)},
]
const BLOCK3_PARKING_WHEEL_STOPS := 5
const BLOCK3_PARKING_BOLLARDS := 3
## REWRITTEN 2026-08-13 with the owner's word: the three east-margin posts are
## lp_street_bollard models now, and MapModels.place() returns a Node3D root
## with the mesh inside it, so the old "at least three MeshInstance3D named
## Parking Bollard*" filter could never match one -- it would have failed the
## finished product and passed the placeholder. The check now pins the
## observable outcome instead: a post at each authored position, each carrying
## real geometry. That holds for the model and for the cylinder fallback alike,
## and still fails on a missing post or an empty node.
const BLOCK3_PARKING_BOLLARD_POSITIONS := [
	Vector2(52.1, 45.0), Vector2(52.1, 48.0), Vector2(52.1, 51.0),
]
const BLOCK3_EXTRA_CAR_POS := Vector2(49.5, 42.6)


func _verify_block3_parking(generated: Node) -> void:
	var missing: Array[String] = []
	var bare: Array[String] = []
	for fixture: Dictionary in BLOCK3_PARKING_FIXTURES:
		var prefix: String = fixture["prefix"]
		var at: Vector2 = fixture["at"]
		var standing := false
		for candidate in generated.find_children(
				"%s*" % prefix, "Node3D", true, false):
			var piece := candidate as Node3D
			if piece == null:
				continue
			var piece_xz := Vector2(piece.global_position.x, piece.global_position.z)
			if piece_xz.distance_to(at) > BLOCK3_PROP_EPSILON:
				continue
			standing = true
			# Same geometry rule as the posts: the primitive IS the mesh, the
			# model keeps it in a child, a bare Node3D is neither.
			if not (piece is MeshInstance3D) and piece.find_children(
					"*", "MeshInstance3D", true, false).is_empty():
				bare.append("%s carries no mesh" % piece.name)
			break
		if not standing:
			missing.append("%s at %s" % [prefix, at])
	# The wheel stops are models too, so the old "MeshInstance3D named Parking
	# Wheel Stop*" filter would count zero of the five. Count nodes that carry
	# geometry, either way round.
	var wheel_stops: Array[Node3D] = []
	for candidate in generated.find_children(
			"Parking Wheel Stop*", "Node3D", true, false):
		var stop := candidate as Node3D
		if stop == null:
			continue
		if stop is MeshInstance3D or not stop.find_children(
				"*", "MeshInstance3D", true, false).is_empty():
			wheel_stops.append(stop)
	var extra_car: Node3D = null
	for candidate in generated.find_children("Parked Car*", "Node3D", true, false):
		var car := candidate as Node3D
		if car == null:
			continue
		var xz := Vector2(car.global_position.x, car.global_position.z)
		if xz.distance_to(BLOCK3_EXTRA_CAR_POS) <= BLOCK3_PROP_EPSILON:
			extra_car = car
			break
	var malformed: Array[String] = []
	if extra_car == null:
		missing.append("extra parked car at %s" % BLOCK3_EXTRA_CAR_POS)
	else:
		for part: String in BLOCK3_CAR_PARTS:
			if extra_car.get_node_or_null(part) == null:
				malformed.append("%s missing %s" % [extra_car.name, part])
	var bollard_found: Array[bool] = []
	bollard_found.resize(BLOCK3_PARKING_BOLLARD_POSITIONS.size())
	bollard_found.fill(false)
	for candidate in generated.find_children(
			"Parking Bollard*", "Node3D", true, false):
		var post := candidate as Node3D
		if post == null:
			continue
		var post_xz := Vector2(post.global_position.x, post.global_position.z)
		for i in range(BLOCK3_PARKING_BOLLARD_POSITIONS.size()):
			if post_xz.distance_to(BLOCK3_PARKING_BOLLARD_POSITIONS[i]) \
					> BLOCK3_PROP_EPSILON:
				continue
			bollard_found[i] = true
			# A post has to carry geometry: the primitive IS the mesh, the model
			# keeps it in a child. A bare Node3D satisfies neither branch.
			if not (post is MeshInstance3D) and post.find_children(
					"*", "MeshInstance3D", true, false).is_empty():
				malformed.append("%s carries no mesh" % post.name)
			break
	var bollards_missing: Array[String] = []
	for i in range(bollard_found.size()):
		if not bollard_found[i]:
			bollards_missing.append(str(BLOCK3_PARKING_BOLLARD_POSITIONS[i]))
	if not missing.is_empty() \
			or not bare.is_empty() \
			or wheel_stops.size() < BLOCK3_PARKING_WHEEL_STOPS \
			or not bollards_missing.is_empty() \
			or not malformed.is_empty():
		_fail("Block 3 parking: missing [%s], empty [%s], wheel stops %d/%d, bollard posts missing [%s] of %d, malformed [%s]"
			% [", ".join(missing), ", ".join(bare),
				wheel_stops.size(), BLOCK3_PARKING_WHEEL_STOPS,
				", ".join(bollards_missing), BLOCK3_PARKING_BOLLARDS,
				", ".join(malformed)])
	else:
		_ok("Block 3 parking: deck, five wheel stops, both signs, four cars and three posts, all carrying geometry")


## ARRIVAL: THE GROUND THE DRIVE HANDS CONTROL BACK ON MUST BE STANDABLE
##
## _place_player_at_car() ends the arrival cutscene by teleporting the player to
## DRIVE_EXIT_POS next to the sedan, and two things have to be true there. The
## point needs a floor that carries a collider: everything east of Lot Wall East
## is authored as collider-free dressing -- _add_drive_set says so in as many
## words -- so an exit inside the driving set is a fall, not a first step. And the
## point has to be on the museum's side of the perimeter: "Lot Wall West", "Lot
## Wall East" and "Lot Wall South" are 1.2 m and deliberately unclimbable, so an
## exit outside them fences the player out of their own forecourt however solid
## the asphalt under their feet is. The sedan is asserted with them, because the
## player is set down an arm's length from it and a walk-through silhouette reads
## as a bug the moment they turn around.
const ARRIVAL_MAP_SCRIPT := "res://game/FirstMuseumMap.gd"
const ARRIVAL_FLOOR_DROP := 1.2
const ARRIVAL_FLOOR_RISE := 0.25
const ARRIVAL_CAR_REACH := 3.2
const ARRIVAL_PERIMETER := ["Lot Wall West", "Lot Wall East", "Lot Wall South"]


func _verify_arrival_exit(generated: Node) -> void:
	var raw: Variant = _script_constant(ARRIVAL_MAP_SCRIPT, "DRIVE_EXIT_POS")
	if typeof(raw) != TYPE_VECTOR3:
		_fail("Arrival exit: DRIVE_EXIT_POS is not a Vector3 in the map script")
		return
	var exit_pos: Vector3 = raw
	var problems: Array[String] = []

	# 1. Floor: a box whose footprint covers the exit, whose top face is at the
	#    player's feet rather than a storey below them, and which has a collider.
	var found_floor := ""
	for node: Node in generated.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null:
			continue
		var box := mesh_instance.mesh as BoxMesh
		if box == null:
			continue
		var at: Vector3 = mesh_instance.global_position
		var half: Vector3 = box.size * 0.5
		if absf(at.x - exit_pos.x) > half.x or absf(at.z - exit_pos.z) > half.z:
			continue
		var top: float = at.y + half.y
		if top > exit_pos.y + ARRIVAL_FLOOR_RISE \
				or top < exit_pos.y - ARRIVAL_FLOOR_DROP:
			continue
		if mesh_instance.find_children("*", "StaticBody3D", true, false).is_empty():
			continue
		found_floor = str(mesh_instance.name)
		break
	if found_floor.is_empty():
		problems.append("no floor with collision under (%.2f, %.2f)"
			% [exit_pos.x, exit_pos.z])

	# 2. On the museum's side of every wall that closes the grounds.
	for wall_name: String in ARRIVAL_PERIMETER:
		var wall := generated.find_child(wall_name, true, false) as Node3D
		if wall == null:
			problems.append("%s is missing" % wall_name)
			continue
		var wall_at: Vector3 = wall.global_position
		var outside := false
		if wall_name == "Lot Wall West":
			outside = exit_pos.x <= wall_at.x
		elif wall_name == "Lot Wall East":
			outside = exit_pos.x >= wall_at.x
		else:
			outside = exit_pos.z >= wall_at.z
		if outside:
			problems.append("exit is on the far side of %s" % wall_name)

	# 3. The car the player steps out of: within reach, and not walk-through.
	var car := generated.find_child("Player Car", true, false) as Node3D
	if car == null:
		problems.append("Player Car is missing")
	else:
		var reach: float = Vector2(car.global_position.x - exit_pos.x,
			car.global_position.z - exit_pos.z).length()
		if reach > ARRIVAL_CAR_REACH:
			problems.append("Player Car stands %.1f m from the exit" % reach)
		if car.find_children("*", "StaticBody3D", true, false).is_empty():
			problems.append("Player Car has no collider")

	if problems.is_empty():
		_ok("Arrival exit: %s under the exit, inside the walls, solid car alongside"
			% found_floor)
	else:
		_fail("Arrival exit: %s" % ", ".join(problems))


## THE ARRIVAL MUST DRIVE ON THE ROAD THAT WAS ACTUALLY BUILT
##
## This check exists because its absence cost us an entire street rebuild.
## The first port shifted the carriageway and nobody compared the new slab to
## `_drive_track`. The result: the arrival car spent the whole cut-scene
## sliding along z 57.2 through what had become the pavement, while the road
## sat at 58.0..65.0 two metres away. Every suite in this file was green.
##
## So every number below is READ from StreetProps and FirstMuseumMap, never
## copied into this file. Move the road again and this fails the same day
## instead of surviving until somebody looks at a screenshot.
const DRIVE_STREET_SCRIPT := "res://game/props/StreetProps.gd"
const DRIVE_LANE_HALF := 3.5
const DRIVE_LANE_EPS := 0.35
const DRIVE_CAR_HALF_WIDTH := 0.975
const DRIVE_CAR_HALF_LENGTH := 2.40
const DRIVE_BAY_HALF_DEPTH := 1.25
const DRIVE_WALK_HALF := 1.55
const DRIVE_BODY_RADIUS := 0.35


func _verify_drive_alignment(map_root: Node, generated: Node) -> void:
	var road: Variant = _script_constant(DRIVE_STREET_SCRIPT, "ROAD_Z")
	var walk: Variant = _script_constant(DRIVE_STREET_SCRIPT, "WALK_Z")
	var bay: Variant = _script_constant(DRIVE_STREET_SCRIPT, "BAY_Z")
	var bay_x: Variant = _script_constant(DRIVE_STREET_SCRIPT, "CAR_BAY_X")
	var bay_pitch: Variant = _script_constant(DRIVE_STREET_SCRIPT, "BAY_PITCH")
	var bay_tiles: Variant = _script_constant(DRIVE_STREET_SCRIPT, "CAR_BAY_TILES")
	for pair in [["ROAD_Z", road], ["WALK_Z", walk], ["BAY_Z", bay],
			["CAR_BAY_X", bay_x], ["BAY_PITCH", bay_pitch],
			["CAR_BAY_TILES", bay_tiles]]:
		var probe: Variant = pair[1]
		if not (probe is float or probe is int):
			_fail("Drive alignment: StreetProps.%s is missing" % pair[0])
			return

	var road_z: float = float(road)
	var walk_z: float = float(walk)
	var bay_z: float = float(bay)
	var bay_centre_x: float = float(bay_x)
	var strip_half: float = float(bay_pitch) * float(bay_tiles) * 0.5
	# The arrival comes in from the east, so it belongs in the museum-side lane:
	# the near half of the slab, centred one half-lane in from the near kerb.
	var lane_axis: float = road_z - DRIVE_LANE_HALF * 0.5
	var road_near: float = road_z - DRIVE_LANE_HALF

	var problems: Array[String] = []

	# Constants agreeing with each other proves nothing if the scene disagrees.
	var slab := generated.find_child("Street Floor Carriageway", true, false) as Node3D if generated != null else null
	if slab == null:
		problems.append("no Street Floor Carriageway was built")
	elif absf(slab.global_position.z - road_z) > 0.01:
		problems.append("carriageway stands at z %.2f but StreetProps.ROAD_Z claims %.2f"
			% [slab.global_position.z, road_z])

	var parked_at: Variant = _script_constant(ARRIVAL_MAP_SCRIPT, "DRIVE_CAR_PARKED_POS")
	var exit_at: Variant = _script_constant(ARRIVAL_MAP_SCRIPT, "DRIVE_EXIT_POS")

	# `_drive_track` is filled in by `_drive_shots()`, so it has to be called
	# first -- it is a var, not a constant, and cannot be read off the script.
	var shots: Variant = map_root.call("_drive_shots")
	if not (shots is Array) or (shots as Array).is_empty():
		problems.append("_drive_shots() produced no shots")
	var track: Variant = map_root.get("_drive_track")
	if not (track is Array) or (track as Array).is_empty():
		problems.append("_drive_track is empty after _drive_shots()")
	else:
		var parked_ref := Vector3.ZERO
		var has_parked: bool = parked_at is Vector3
		if has_parked:
			parked_ref = parked_at
		var strays: int = 0
		var worst_offset: float = 0.0
		for segment in (track as Array):
			if not (segment is Dictionary):
				continue
			var leg: Dictionary = segment
			for key in ["from", "to"]:
				if not leg.has(key):
					continue
				var sample: Variant = leg[key]
				if not (sample is Vector3):
					continue
				var at: Vector3 = sample
				# The last leg parks in the bay, which is off the running lane
				# on purpose. Everything else is still driving.
				if has_parked and at.distance_to(parked_ref) < 0.01:
					continue
				if at.z < road_near or at.z > road_z:
					strays += 1
				worst_offset = maxf(worst_offset, absf(at.z - lane_axis))
		if strays > 0:
			problems.append("%d drive-track samples sit outside the carriageway z %.2f..%.2f"
				% [strays, road_near, road_z])
		if worst_offset > DRIVE_LANE_EPS:
			problems.append("drive track wanders %.2f m off the museum-side lane axis z %.2f"
				% [worst_offset, lane_axis])

	if parked_at is Vector3:
		var parked: Vector3 = parked_at
		if absf(parked.z - bay_z) > 0.01:
			problems.append("parked car z %.2f is not on the marked strip z %.2f"
				% [parked.z, bay_z])
		if parked.z + DRIVE_CAR_HALF_WIDTH > bay_z + DRIVE_BAY_HALF_DEPTH + 0.01:
			problems.append("parked car overhangs the strip back into the running lane")
		if parked.x - DRIVE_CAR_HALF_LENGTH < bay_centre_x - strip_half - 0.01 \
				or parked.x + DRIVE_CAR_HALF_LENGTH > bay_centre_x + strip_half + 0.01:
			problems.append("parked car x %.2f runs off the strip %.2f..%.2f"
				% [parked.x, bay_centre_x - strip_half, bay_centre_x + strip_half])
	else:
		problems.append("DRIVE_CAR_PARKED_POS is missing")

	if exit_at is Vector3:
		var door_at: Vector3 = exit_at
		if absf(door_at.z - walk_z) + DRIVE_BODY_RADIUS > DRIVE_WALK_HALF:
			problems.append("exit point z %.2f leaves the player hanging off the pavement"
				% door_at.z)
		if door_at.z >= road_near:
			problems.append("exit point z %.2f drops the player onto the carriageway"
				% door_at.z)
	else:
		problems.append("DRIVE_EXIT_POS is missing")

	if problems.is_empty():
		_ok("Drive alignment: track holds lane z %.2f, car parks on the strip, exit lands on the pavement"
			% lane_axis)
	else:
		_fail("Drive alignment: %s" % ", ".join(problems))


## THE FORECOURT CORE IS A COMPOSITION, NOT A PROP DUMP
##
## Everything between the portico steps and the kerb strip -- x +-20,
## z 38.4..53.0 -- is the museum's formal court: walkway flags on the axis, then
## the lamp row, urns, benches, flag poles, topiary, parterres and the fountain,
## every one of them answered by a twin on the other side of the axis. Single
## props dropped into that band are what makes the court read as haphazard: an
## imported street lamp at (19.5, 46) standing beside the authored six-lamp row,
## a bus shelter and a refuse skip on the lawn, a bike rack and an opening-hours
## sign on the east half with nothing on the west, and both flag cloths offset
## the same way (+0.5 in x) instead of outward from their poles.
##
## The core therefore carries two hard rules: none of the imported one-offs may
## stand inside it, and every mesh inside it is either on the axis or has a
## mirror twin within 6 cm. Utilities a real museum needs but a formal court
## cannot absorb -- bins, bike rack, hours sign, hydrant -- belong to the kerb
## strip past z 53, and refuse handling to the service corner past x -20;
## neither of those claims symmetry, so neither is checked here.
const COURT_CORE_HALF_X := 20.0
const COURT_CORE_Z0 := 38.4
const COURT_CORE_Z1 := 53.0
const COURT_MIRROR_EPS := 0.06
const COURT_LONELY_SHOWN := 6
const COURT_BANNED_IN_CORE := [
	"dumpster_closed",
	"dumpster_open",
	"papers",
	"trash_bags",
	"Bench_m_bench*",
	"Street_Lamp_m_lamp*",
	"Delivery Pallet",
	"Delivery Crate*",
]


func _in_court_core(at: Vector3) -> bool:
	return absf(at.x) <= COURT_CORE_HALF_X and at.z >= COURT_CORE_Z0 \
		and at.z <= COURT_CORE_Z1


func _verify_court_composition(generated: Node) -> void:
	var problems: Array[String] = []
	for pattern: String in COURT_BANNED_IN_CORE:
		for node: Node in generated.find_children(pattern, "Node3D", true, false):
			var stray := node as Node3D
			if stray == null or not _in_court_core(stray.global_position):
				continue
			problems.append("%s at (%.1f, %.1f)" % [stray.name,
				stray.global_position.x, stray.global_position.z])

	var spots: Array[Dictionary] = []
	for node: Node in generated.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or not _in_court_core(mesh.global_position):
			continue
		spots.append({"name": str(mesh.name), "at": mesh.global_position})

	var lonely: Array[String] = []
	for spot: Dictionary in spots:
		var at: Vector3 = spot["at"]
		if absf(at.x) <= COURT_MIRROR_EPS:
			continue
		var twinned := false
		for other: Dictionary in spots:
			var twin: Vector3 = other["at"]
			if absf(twin.x + at.x) <= COURT_MIRROR_EPS \
					and absf(twin.y - at.y) <= COURT_MIRROR_EPS \
					and absf(twin.z - at.z) <= COURT_MIRROR_EPS:
				twinned = true
				break
		if not twinned:
			lonely.append("%s (%.2f, %.2f)" % [spot["name"], at.x, at.z])

	if not lonely.is_empty():
		problems.append("%d unmirrored meshes: %s" % [lonely.size(),
			", ".join(lonely.slice(0, COURT_LONELY_SHOWN))])
	if problems.is_empty():
		_ok("Forecourt core: %d meshes, each on the axis or mirrored, no stray one-offs"
			% spots.size())
	else:
		_fail("Forecourt core: %s" % ", ".join(problems))


## THE WATCH OFFICE CABINET MUST STAND IN THE ROOM, NOT IN THE WALL
##
## The stabilization locker is 1.35 m deep and was centred at x -34.05, which
## put its back face at -34.725 while the office's west wall face is -34.65:
## 7.5 cm of the cabinet was buried in the wall, measured by the prop audit as
## a 0.56 m3 intersection, the largest prop-into-structure overlap in the
## building. The four shelf strips are drawn a couple of millimetres in front
## of the cabinet face, so they have to travel with it instead of ending up
## floating in the room or sunk inside the box.
const OFFICE_WEST_WALL_FACE := -34.65
const OFFICE_WALL_CLEAR := 0.01
const OFFICE_SHELF_STANDOFF := 0.05


func _verify_office_fixtures(generated: Node) -> void:
	var locker := generated.find_child("Stabilization Locker", true, false) as MeshInstance3D
	if locker == null:
		_fail("Office fixtures: Stabilization Locker is missing")
		return
	var box: AABB = locker.global_transform * locker.get_aabb()
	var back: float = box.position.x
	var front: float = box.position.x + box.size.x
	var problems: Array[String] = []
	if back < OFFICE_WEST_WALL_FACE + OFFICE_WALL_CLEAR:
		problems.append("locker back face x %.3f is inside the west wall at %.2f"
			% [back, OFFICE_WEST_WALL_FACE])
	var shelves := generated.find_children("Locker Shelf*", "MeshInstance3D", true, false)
	if shelves.is_empty():
		problems.append("no Locker Shelf strips found")
	for shelf in shelves:
		var mesh := shelf as MeshInstance3D
		var strip: AABB = mesh.global_transform * mesh.get_aabb()
		var standoff: float = strip.position.x - front
		if standoff < 0.0 or standoff > OFFICE_SHELF_STANDOFF:
			problems.append("%s sits %.3f m off the cabinet face" % [mesh.name, standoff])
	if problems.is_empty():
		_ok("Office fixtures: locker back x %.3f clears the west wall at %.2f, %d shelf strips on its face"
			% [back, OFFICE_WEST_WALL_FACE, shelves.size()])
	else:
		_fail("Office fixtures: %s" % ", ".join(problems))


## THE FRONT DOOR IS REACHED ON A PROMENADE, NOT THROUGH A SLOT
##
## PlayerController gives the body a 0.35 m capsule radius and a step_height of
## 0.38, so anything whose top rises more than a step above the court floor is a
## wall to be walked around, and a route exists only where the centre line keeps
## 0.35 m of clearance on every side. Measured on the built map, the widest walk
## from the arrival exit to the perron was 0.90 m across, because three things
## crowd the same 6.4 m Museum Walkway: the fountain basin fills its full width,
## the bollard ring drops posts at x +-2.55 inside that paving -- in the gate
## throat to the north and on the approach to the south -- and the parterre hedge
## closes on the basin to 1.09 m. A guest should not have to shuffle sideways
## between a hedge and a fountain to reach the front door, so the widest route
## has to beat APPROACH_MIN_WIDTH, which is wider than the museum's own 1.20 m
## doors and lets two people pass.
##
## The search is a clearance field over the court plus a widest-path flood fill:
## for every cell the distance to the nearest wall, then the largest radius that
## still connects the exit to the perron. Reporting the tightest cell and the two
## walls that pinch it keeps the failure actionable instead of merely red.
##
## Standing beside one's own car is not a corridor. The drop-off deliberately
## leaves the body 0.65 m off the car's flank, so measuring the promenade from
## that cell would only ever report the width of a car door. The first
## APPROACH_START_GRACE metres therefore have to admit the body and nothing more,
## the promenade is measured beyond them, and that the driver can stand up at all
## is asserted on its own as APPROACH_EXIT_ROOM of room at the exit.
const APPROACH_MIN_WIDTH := 1.6
const APPROACH_BODY_RADIUS := 0.35
const APPROACH_EXIT_ROOM := 0.45
const APPROACH_START_GRACE := 2.5
const APPROACH_STEP_HEIGHT := 0.38
const APPROACH_HEAD_ROOM := 1.75
const APPROACH_CELL := 0.25
const APPROACH_X_LIMIT := 22.0
const APPROACH_Z_MIN := 35.5
const APPROACH_Z_MAX := 59.0
const APPROACH_GOAL := Vector2(0.0, 38.6)
const APPROACH_RADII := [1.4, 1.2, 1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.45, 0.4, 0.35]


func _verify_entrance_approach(generated: Node) -> void:
	var raw: Variant = _script_constant(ARRIVAL_MAP_SCRIPT, "DRIVE_EXIT_POS")
	if typeof(raw) != TYPE_VECTOR3:
		_fail("Entrance approach: DRIVE_EXIT_POS is not a Vector3 in the map script")
		return
	var exit_pos: Vector3 = raw
	var walls := _approach_walls(generated)
	var nx := int((APPROACH_X_LIMIT * 2.0) / APPROACH_CELL) + 1
	var nz := int((APPROACH_Z_MAX - APPROACH_Z_MIN) / APPROACH_CELL) + 1
	var field := PackedFloat32Array()
	field.resize(nx * nz)
	for iz: int in nz:
		for ix: int in nx:
			field[iz * nx + ix] = _approach_clearance(walls, _approach_point(ix, iz))
	var start := Vector2(exit_pos.x, exit_pos.z)
	var from_idx := _approach_index(nx, nz, start)
	var to_idx := _approach_index(nx, nz, APPROACH_GOAL)
	if from_idx < 0 or to_idx < 0:
		_fail("Entrance approach: the exit or the perron falls outside the measured court")
		return
	if field[from_idx] < APPROACH_EXIT_ROOM:
		_fail("Entrance approach: only %.2f m of standing room where the driver steps out, %s"
			% [field[from_idx], _approach_pinch(walls, start)])
		return
	var best_radius := 0.0
	var best_path := PackedInt32Array()
	for radius: float in APPROACH_RADII:
		var path := _approach_route(field, nx, nz, from_idx, to_idx, radius, start)
		if path.size() > 0:
			best_radius = radius
			best_path = path
			break
	if best_path.is_empty():
		_fail("Entrance approach: nothing walkable joins the arrival exit to the perron, %d walls stand in the court"
			% walls.size())
		return
	var tight_idx := -1
	for idx: int in best_path:
		if _approach_point(idx % nx, idx / nx).distance_to(start) <= APPROACH_START_GRACE:
			continue
		if tight_idx < 0 or field[idx] < field[tight_idx]:
			tight_idx = idx
	if tight_idx < 0:
		tight_idx = best_path[best_path.size() - 1]
	var tight := _approach_point(tight_idx % nx, tight_idx / nx)
	var width: float = best_radius * 2.0
	if width < APPROACH_MIN_WIDTH - 0.001:
		_fail("Entrance approach: the widest walk from the car to the perron is %.2f m, under %.2f m, pinched at (%.2f, %.2f) by %s"
			% [width, APPROACH_MIN_WIDTH, tight.x, tight.y,
				_approach_pinch(walls, tight)])
	else:
		_ok("Entrance approach: %.2f m of walking width from the arrival exit to the perron, narrowest at (%.2f, %.2f)"
			% [width, tight.x, tight.y])


func _approach_walls(generated: Node) -> Array[Dictionary]:
	var walls: Array[Dictionary] = []
	for node: Node in generated.find_children("*", "CollisionShape3D", true, false):
		var shape_node := node as CollisionShape3D
		if shape_node == null:
			continue
		var extents := Vector3.ZERO
		var round_radius := 0.0
		if shape_node.shape is BoxShape3D:
			extents = (shape_node.shape as BoxShape3D).size * 0.5
		elif shape_node.shape is CylinderShape3D:
			var cyl := shape_node.shape as CylinderShape3D
			extents = Vector3(cyl.radius, cyl.height * 0.5, cyl.radius)
			round_radius = cyl.radius
		else:
			continue
		var xf := shape_node.global_transform
		var lo := Vector3(1e9, 1e9, 1e9)
		var hi := Vector3(-1e9, -1e9, -1e9)
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					var corner: Vector3 = xf * Vector3(extents.x * sx,
						extents.y * sy, extents.z * sz)
					lo = lo.min(corner)
					hi = hi.max(corner)
		if hi.x < -APPROACH_X_LIMIT or lo.x > APPROACH_X_LIMIT \
				or hi.z < APPROACH_Z_MIN or lo.z > APPROACH_Z_MAX:
			continue
		if hi.y <= APPROACH_STEP_HEIGHT or lo.y > APPROACH_HEAD_ROOM:
			continue
		var label := str(shape_node.name)
		var body := shape_node.get_parent()
		if body != null:
			label = str(body.name)
		var wall := {
			"name": label,
			"lo": Vector2(lo.x, lo.z),
			"hi": Vector2(hi.x, hi.z),
			"round": false,
			"centre": Vector2.ZERO,
			"radius": 0.0,
		}
		# A round basin is round. Measured by its bounding square the fountain
		# grows corners nobody can walk into, and those corners reach to within
		# 0.91 m of the gate piers and report the promenade as a slot, while the
		# real arc keeps 2.55 m of stone-free ground there. Upright cylinders are
		# therefore measured as the circles they are.
		if round_radius > 0.0 and absf(xf.basis.y.normalized().dot(Vector3.UP)) > 0.99:
			wall["round"] = true
			wall["centre"] = Vector2(xf.origin.x, xf.origin.z)
			wall["radius"] = round_radius * xf.basis.x.length()
		walls.append(wall)
	return walls


func _approach_point(ix: int, iz: int) -> Vector2:
	return Vector2(-APPROACH_X_LIMIT + float(ix) * APPROACH_CELL,
		APPROACH_Z_MIN + float(iz) * APPROACH_CELL)


func _approach_index(nx: int, nz: int, at: Vector2) -> int:
	var ix := int(round((at.x + APPROACH_X_LIMIT) / APPROACH_CELL))
	var iz := int(round((at.y - APPROACH_Z_MIN) / APPROACH_CELL))
	if ix < 0 or ix >= nx or iz < 0 or iz >= nz:
		return -1
	return iz * nx + ix


func _wall_distance(wall: Dictionary, at: Vector2) -> float:
	if bool(wall["round"]):
		var centre: Vector2 = wall["centre"]
		return maxf(centre.distance_to(at) - float(wall["radius"]), 0.0)
	var lo: Vector2 = wall["lo"]
	var hi: Vector2 = wall["hi"]
	var dx: float = maxf(maxf(lo.x - at.x, 0.0), at.x - hi.x)
	var dz: float = maxf(maxf(lo.y - at.y, 0.0), at.y - hi.y)
	return sqrt(dx * dx + dz * dz)


func _approach_clearance(walls: Array[Dictionary], at: Vector2) -> float:
	var best := 99.0
	for wall: Dictionary in walls:
		var d: float = _wall_distance(wall, at)
		if d < best:
			best = d
			if best <= 0.0:
				return 0.0
	return best


func _approach_route(field: PackedFloat32Array, nx: int, nz: int, from_idx: int,
		to_idx: int, radius: float, start: Vector2) -> PackedInt32Array:
	if field[to_idx] < radius or field[from_idx] < APPROACH_BODY_RADIUS:
		return PackedInt32Array()
	var came := PackedInt32Array()
	came.resize(nx * nz)
	came.fill(-2)
	came[from_idx] = -1
	var queue := PackedInt32Array()
	queue.push_back(from_idx)
	var head := 0
	while head < queue.size():
		var idx := queue[head]
		head += 1
		if idx == to_idx:
			var path := PackedInt32Array()
			var walk := idx
			while walk != -1:
				path.push_back(walk)
				walk = came[walk]
			return path
		var ix := idx % nx
		var iz := idx / nx
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
				Vector2i(0, -1)]:
			var jx := ix + step.x
			var jz := iz + step.y
			if jx < 0 or jx >= nx or jz < 0 or jz >= nz:
				continue
			var jdx := jz * nx + jx
			if came[jdx] != -2:
				continue
			# Getting clear of the car only needs the body to fit; the promenade is
			# what has to be wide, and it starts once the car is behind you.
			var reach: float = radius
			if _approach_point(jx, jz).distance_to(start) <= APPROACH_START_GRACE:
				reach = APPROACH_BODY_RADIUS
			if field[jdx] < reach:
				continue
			came[jdx] = idx
			queue.push_back(jdx)
	return PackedInt32Array()


func _approach_pinch(walls: Array[Dictionary], at: Vector2) -> String:
	var ranked: Array[Dictionary] = []
	for wall: Dictionary in walls:
		ranked.append({"name": wall["name"], "d": _wall_distance(wall, at)})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["d"]) < float(b["d"]))
	var shown: Array[String] = []
	for i: int in mini(2, ranked.size()):
		shown.append("%s at %.2f m" % [str(ranked[i]["name"]), float(ranked[i]["d"])])
	return " and ".join(shown)


## STONE STANDS ON STONE: PLAZA FIXTURES KEEP BOTH FEET ON THE PAVING
##
## The urns carry their weight on a plinth, and a plinth with one edge hanging
## over bare ground reads as dropped rather than placed. The pair at z 41.4 was
## exactly that: 0.83 m of its 0.86 m footprint stood off the "Entrance Plaza"
## slab, which ends at z 41.0. Such fixtures must sit inside the paving with a
## margin, and they must not crowd the rest of the court furniture -- a plinth
## grazing a lamp or a hedge is the same defect seen from the side.
const PLAZA_HALF_X := 8.5
const PLAZA_Z_MIN := 35.4
const PLAZA_Z_MAX := 41.0
const PLAZA_FOOT_INSET := 0.15
const PLAZA_PROP_GAP := 0.40
const PLAZA_PLINTH_NAMES := ["Urn Plinth", "lp_court_urn"]


func _verify_plaza_footing(generated: Node) -> void:
	var plinths: Array[Dictionary] = []
	for node: Node in generated.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		# Repeated props get their position appended to the name, so compare the
		# stem: "Urn Plinth" and "Urn Plinth (7_7, 0_22, 38_6)" are both plinths.
		var stem: String = str(mesh_node.name).split(" (")[0]
		if not PLAZA_PLINTH_NAMES.has(stem):
			continue
		var box := mesh_node.get_aabb()
		var xf := mesh_node.global_transform
		var lo := Vector3(1e9, 1e9, 1e9)
		var hi := Vector3(-1e9, -1e9, -1e9)
		for sx: float in [0.0, 1.0]:
			for sy: float in [0.0, 1.0]:
				for sz: float in [0.0, 1.0]:
					var corner: Vector3 = xf * (box.position + Vector3(
						box.size.x * sx, box.size.y * sy, box.size.z * sz))
					lo = lo.min(corner)
					hi = hi.max(corner)
		plinths.append({
			"name": str(mesh_node.name),
			"lo": Vector2(lo.x, lo.z),
			"hi": Vector2(hi.x, hi.z),
		})
	if plinths.is_empty():
		_fail("Plaza footing: no plinth-footed fixture stands on the entrance plaza")
		return
	var adrift: Array[String] = []
	for plinth: Dictionary in plinths:
		var lo: Vector2 = plinth["lo"]
		var hi: Vector2 = plinth["hi"]
		var over: float = maxf(-PLAZA_HALF_X + PLAZA_FOOT_INSET - lo.x,
			hi.x - PLAZA_HALF_X + PLAZA_FOOT_INSET)
		over = maxf(over, maxf(PLAZA_Z_MIN + PLAZA_FOOT_INSET - lo.y,
			hi.y - PLAZA_Z_MAX + PLAZA_FOOT_INSET))
		if over > 0.0:
			adrift.append("%s [x %.2f..%.2f, z %.2f..%.2f] hangs over the edge by %.2f m"
				% [str(plinth["name"]), lo.x, hi.x, lo.y, hi.y, over])
	if not adrift.is_empty():
		_fail("Plaza footing: %d of %d plinths do not stand on the paving: %s"
			% [adrift.size(), plinths.size(), ", ".join(adrift)])
		return
	var walls := _approach_walls(generated)
	var crowded: Array[String] = []
	for plinth: Dictionary in plinths:
		var lo: Vector2 = plinth["lo"]
		var hi: Vector2 = plinth["hi"]
		var centre: Vector2 = (lo + hi) * 0.5
		var reach: float = maxf(hi.x - centre.x, hi.y - centre.y)
		var nearest := 99.0
		var nearest_name := "nothing"
		for wall: Dictionary in walls:
			var wlo: Vector2 = wall["lo"]
			var whi: Vector2 = wall["hi"]
			# The urn's own collider wraps its plinth; skip whatever this plinth
			# stands inside of.
			if wlo.x <= centre.x and centre.x <= whi.x \
					and wlo.y <= centre.y and centre.y <= whi.y:
				continue
			var gap: float = _wall_distance(wall, centre) - reach
			if gap < nearest:
				nearest = gap
				nearest_name = str(wall["name"])
		if nearest < PLAZA_PROP_GAP:
			crowded.append("%s is %.2f m from %s"
				% [str(plinth["name"]), nearest, nearest_name])
	if not crowded.is_empty():
		_fail("Plaza footing: %d plinths crowd the court furniture: %s"
			% [crowded.size(), ", ".join(crowded)])
		return
	_ok("Plaza footing: %d plinths stand on the paving, %.2f m clear of its edges and of the furniture"
		% [plinths.size(), PLAZA_FOOT_INSET])


## PLANETARIUM: THE NEW SILHOUETTE ROOM MUST NOT KEEP THE LEGACY STAR GRID
##
## PlanetariumProps defines the current composition as a switched-off machine
## read by flashlight: shallow dome, shrouded projector, raked seating and an
## operator booth. The older map layer still glues emissive pixel boxes to the
## ceiling, contradicting that state and bleeding through the dome's oculus.
## Keep both halves of the contract here: the new four-part room is present and
## no legacy "Star N" mesh remains inside its 20 x 16 m footprint.
const PLANETARIUM_RECT := Rect2(Vector2(-10.0, -49.0), Vector2(20.0, 16.0))
const PLANETARIUM_PARTS := [
	"Planetarium Dome", "Planetarium Projector",
	"Planetarium Seating Bank", "Planetarium Operator Booth",
]


func _verify_planetarium_composition(generated: Node) -> void:
	var props := generated.get_node_or_null("Planetarium Props") as Node3D
	var missing: Array[String] = []
	if props == null:
		missing.append("Planetarium Props")
	else:
		for part: String in PLANETARIUM_PARTS:
			if props.get_node_or_null(part) == null:
				missing.append(part)
	var legacy_stars: Array[String] = []
	for candidate in generated.find_children("Star *", "MeshInstance3D", true, false):
		var star := candidate as MeshInstance3D
		if star == null:
			continue
		var xz := Vector2(star.global_position.x, star.global_position.z)
		if PLANETARIUM_RECT.has_point(xz):
			legacy_stars.append(str(star.name))
	if not missing.is_empty() or not legacy_stars.is_empty():
		_fail("Planetarium composition: missing [%s], legacy ceiling stars %d"
			% [", ".join(missing), legacy_stars.size()])
	else:
		_ok("Planetarium composition: dome/projector/seating/booth, projector-off ceiling")


## WALKING INTO THE OFFICE MUST ACTUALLY PUT THE LIGHTS OUT
##
## The failure this pins down shipped and was visible in the first screenshot of
## the room: the player entered the Watcher Office, the blackout flag flipped,
## the sound played -- and every ceiling lamp stayed on.
##
## The cause was not in _trigger_blackout(). It is that build_map() is what fills
## _powered_lights, and the shipping scene carries a serialized layout, so
## _ready() skips build_map() and the blackout then switched off an empty list:
## measured 0 registered lamps against 5 still burning inside the office.
##
## So the check is written against the observable, not against the flag: after
## the player stands in the office, nothing in the room may still be lit except
## the battery lamp and the flashlight in the player's own hand.
const OFFICE_RECT := Rect2(Vector2(-34.6, -6.6), Vector2(19.2, 13.2))
const BLACKOUT_ALLOWED_LIT := ["Emergency Lamp", "Player Flashlight"]
const OFFICE_TUBE_NAME := "Office Fluorescent Tube"

func _verify_blackout(map_root: Node, generated: Node) -> void:
	var registered: Array = map_root.get("_powered_lights")
	if registered == null or registered.is_empty():
		_fail("Blackout: no mains lamps registered, so cutting the power "
			+ "would switch off nothing")
		return
	var player := get_first_node_in_group("player") as Node3D
	if player == null:
		_fail("Blackout: no player in the tree, the trigger can never fire")
		return
	paused = false
	# The opening chain (arrival drive -> prologue -> intro) may be in flight
	# on a profile that has not seen it yet, and FirstMuseumMap._process()
	# deliberately stays out of the way while any cutscene plays -- so the
	# blackout could never fire, however long this check waited. End the chain
	# the way a player would, piece by piece: each skip() finishes one
	# cutscene, its finished-handler may start the next, so loop until the map
	# has no playing Cutscene child left.
	for _hop in range(8):
		var opening: Cutscene = null
		for child in map_root.get_children():
			if child is Cutscene and (child as Cutscene).is_playing():
				opening = child
				break
		if opening == null:
			break
		opening.skip()
		await process_frame
	player.global_position = Vector3(-25.0, 1.0, -1.0)
	for _i in range(8):
		await process_frame
	if not bool(map_root.get("_blackout_done")):
		_fail("Blackout: the player stood in the middle of the office and the "
			+ "power never went")
		return
	var still_lit: Array = []
	_collect_lit_in_office(generated, still_lit)
	if not still_lit.is_empty():
		_fail("Blackout: %d light(s) still on in the office after the power "
			% still_lit.size() + "went: %s" % [", ".join(still_lit)])
		return
	var tube := generated.get_node_or_null(OFFICE_TUBE_NAME) as MeshInstance3D
	if tube != null:
		var mat := tube.material_override as StandardMaterial3D
		if mat != null and mat.emission_enabled \
				and mat.emission_energy_multiplier > 0.01:
			_fail("Blackout: the office tube housing still glows at %.2f"
				% mat.emission_energy_multiplier)
			return
	var exterior_lights := generated.find_children(
		"Street Lamp Light", "SpotLight3D", true, false)
	exterior_lights.append_array(generated.find_children(
		"Court Gate Light*", "OmniLight3D", true, false))
	var exterior_dark: Array[String] = []
	for node in exterior_lights:
		var exterior := node as Light3D
		if exterior == null or not exterior.is_visible_in_tree() \
				or exterior.light_energy <= 0.01:
			exterior_dark.append(str(node.name))
	if exterior_lights.size() != 8 or not exterior_dark.is_empty():
		_fail("Blackout: exterior circuit has %d/8 fixtures, dark [%s]"
			% [exterior_lights.size(), ", ".join(exterior_dark)])
		return
	_ok("Blackout: %d mains lamps registered, office dark, 8 exterior fixtures live"
		% registered.size())


## Everything lit inside the office rectangle that is not allowed to be.
func _collect_lit_in_office(node: Node, into: Array) -> void:
	var n3 := node as Node3D
	if n3 != null and n3.is_inside_tree():
		var p := n3.global_position
		if OFFICE_RECT.has_point(Vector2(p.x, p.z)):
			var light := node as Light3D
			if light != null and light.is_visible_in_tree() \
					and light.light_energy > 0.01 \
					and not BLACKOUT_ALLOWED_LIT.has(str(light.name)):
				into.append(str(light.name))
	for child in node.get_children():
		_collect_lit_in_office(child, into)


## THE TERMINAL MUST BE EQUIPMENT, AND IT MUST ANSWER THE QUESTION
##
## Two failures this pins down, both of which shipped:
##
## 1. Geometry. The readout was a single 1.3 x 0.8 box at y 2.15 with a Label3D
##    floating beside it -- 0.86 m of empty air above the console it reports
##    for, with no stand, bezel or bracket. It read as a coloured rectangle
##    standing nowhere.
## 2. Legibility and content. The alarm text measured up to 0.91 m tall and
##    2.06 m wide on a 1.3 x 0.8 face, i.e. it ran off its own screen for every
##    anomaly in the catalogue. And only 6 of the 10 anomaly readouts name the
##    tool at all, so for mirror_maze, yellow_halls, scrap_run and ascent the
##    room never told the player what to fetch once the 3-second flash was gone.
##
## So: the parts must meet the console, the text must fit the glass for EVERY
## anomaly, and an open incident must leave the tool named on the device.
func _verify_anomaly_terminal(map_root: Node, generated: Node) -> void:
	var term := generated.get_node_or_null(TERMINAL_ROOT_NAME) as Node3D
	if term == null:
		_fail("Anomaly terminal: no '%s' node — the readout is not a mounted device"
			% TERMINAL_ROOT_NAME)
		return
	var screen := term.get_node_or_null(TERMINAL_SCREEN_NAME) as MeshInstance3D
	var readout := term.get_node_or_null(TERMINAL_READOUT_NAME) as Label3D
	var order := term.get_node_or_null(TERMINAL_ORDER_NAME) as Label3D
	if screen == null or readout == null or order == null:
		_fail("Anomaly terminal: screen/readout/order parts missing (%s/%s/%s)"
			% [screen != null, readout != null, order != null])
		return

	# 1. Does it stand on anything?
	var lowest := INF
	var parts := 0
	for child in term.get_children():
		var mi := child as MeshInstance3D
		if mi == null or not (mi.mesh is BoxMesh):
			continue
		parts += 1
		lowest = minf(lowest, mi.global_position.y - (mi.mesh as BoxMesh).size.y * 0.5)
	var gap: float = lowest - TERMINAL_CONSOLE_TOP_Y
	if parts < 3:
		_fail("Anomaly terminal: only %d box parts — a bare slab again, expected a mount (posts + bezel + face)"
			% parts)
	elif gap > TERMINAL_MOUNT_TOLERANCE:
		_fail("Anomaly terminal: lowest part sits %.3f m above the console top (y %.3f) — it is floating"
			% [gap, TERMINAL_CONSOLE_TOP_Y])
	else:
		_ok("Anomaly terminal: %d parts, lowest meets the console top (gap %.3f m)"
			% [parts, gap])

	# 2. Does the text stay on the glass, for every anomaly, in this locale?
	var face: Vector3 = (screen.mesh as BoxMesh).size
	var gm: Node = map_root.get_node_or_null("GameManager")
	var consts: Dictionary = {}
	if gm != null and gm.get_script() != null:
		consts = (gm.get_script() as GDScript).get_script_constant_map()
	var anomalies: Dictionary = consts.get("ANOMALIES", {})
	var equipment: Dictionary = consts.get("EQUIPMENT", {})
	var sign_texts: Dictionary = consts.get("SIGNS", {})
	var saved_readout: String = readout.text
	var saved_order: String = order.text
	var worst_h := 0.0
	var worst_w := 0.0
	var worst_id := ""
	var unnamed := 0
	for id in anomalies:
		var info: Dictionary = anomalies[id]
		var device: String = tr(str(equipment[str(info["equipment"])]["name"]))
		# The same three lines GameManager._incident_signs_text() composes. Built
		# here rather than called, because this check measures what the plate will
		# hold in a locale the running game has not necessarily loaded.
		var lines := PackedStringArray()
		for sign_id in (info.get("signs", []) as Array):
			lines.append(tr(str(sign_texts.get(str(sign_id), ""))))
		var printed := "\n".join(lines)
		readout.text = Loc.fmt("HUD_TERMINAL_BREACH", [tr(str(info["title"])), printed])
		order.text = "%s\n%s" % [tr("HUD_PROTO_TAKE"), device]
		await process_frame
		var stack: float = readout.get_aabb().size.y + order.get_aabb().size.y
		var wide: float = maxf(readout.get_aabb().size.x, order.get_aabb().size.x)
		if stack > worst_h:
			worst_h = stack
			worst_id = str(id)
		worst_w = maxf(worst_w, wide)
		if printed.to_upper().find(device.to_upper()) < 0:
			unnamed += 1
	readout.text = saved_readout
	order.text = saved_order
	if anomalies.is_empty():
		_fail("Anomaly terminal: could not read ANOMALIES off GameManager — text fit unverified")
	elif worst_h > face.y - TERMINAL_TEXT_MARGIN or worst_w > face.x - TERMINAL_TEXT_MARGIN:
		_fail("Anomaly terminal: text spills off the %.2f x %.2f face — worst %.3f m tall (%s), %.3f m wide"
			% [face.x, face.y, worst_h, worst_id, worst_w])
	else:
		_ok("Anomaly terminal: all %d anomaly readouts fit the glass (worst %.3f x %.3f on %.2f x %.2f)"
			% [anomalies.size(), worst_w, worst_h, face.x, face.y])
	print("    (%d of %d anomaly readouts do not name the tool themselves — the order line is what covers them)"
		% [unnamed, anomalies.size()])

	# 3. Open a real incident: the stand sign must SAY SOMETHING and must NOT be the
	# answer. This check used to demand the opposite -- that the tool be named on
	# the screen -- which was right while the terminal did the diagnosing. Now all
	# ten anomalies leave the device to the operator (audit 16.6 п. 1), so the same
	# plate is held to the inverse rule: never blank, never a device name.
	if gm == null or not gm.has_method("_start_accident"):
		_fail("Anomaly terminal: no GameManager._start_accident() — cannot verify the order line")
		return
	gm.call("_start_accident")
	for _i in range(3):
		await process_frame
	var shown: String = order.text
	var names_a_tool := false
	for key in equipment:
		var name_text: String = tr(str(equipment[key]["name"]))
		if not name_text.is_empty() and shown.find(name_text) >= 0:
			names_a_tool = true
			break
	if shown.strip_edges().is_empty():
		_fail("Anomaly terminal: incident open and the order line is blank — the operator is told nothing at all")
	elif names_a_tool:
		_fail("Anomaly terminal: order line reads '%s' and hands over the device"
			% shown.replace("\n", " / "))
	else:
		_ok("Anomaly terminal: an open incident leaves the device to the operator ('%s')"
			% shown.replace("\n", " / "))


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
	_verify_storage_door_clearance(generated)

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


## The three service-room portals must be visually clear when the player opens
## them. They now start shut by design, so drive the same manual contract the
## gameplay E action uses, measure the body-height channel, then restore shut.
func _verify_storage_door_clearance(generated: Node) -> void:
	var problems: Array[String] = []
	var measured: Array[float] = []
	var scanned := 0
	var opened_swings: Array[Node] = []
	var all_swings := generated.find_children("Door Swing*", "Node3D", true, false)
	for center in STORAGE_DOOR_CENTERS:
		var swing: Node = null
		for candidate in all_swings:
			var candidate_3d := candidate as Node3D
			if candidate_3d != null \
					and candidate_3d.global_position.distance_to(center) < 0.05:
				swing = candidate
				break
		if swing == null or not swing.has_method("set_open"):
			problems.append("%s has no manual Door Swing" % center)
			continue
		swing.call("set_open", true)
		for _step in range(90):
			swing.call("_physics_process", 1.0 / 60.0)
		opened_swings.append(swing)
	var meshes := generated.find_children("*", "MeshInstance3D", true, false)
	for center in STORAGE_DOOR_CENTERS:
		var nearest := INF
		var nearest_name := ""
		for node in meshes:
			var instance := node as MeshInstance3D
			if instance == null or not (instance.mesh is BoxMesh):
				continue
			var box := instance.mesh as BoxMesh
			var half := box.size * 0.5
			var bottom := instance.global_position.y - half.y
			var top := instance.global_position.y + half.y
			if top <= DOOR_CLEARANCE_BOTTOM or bottom >= DOOR_CLEARANCE_TOP:
				continue
			var at_height := Vector3(center.x, instance.global_position.y, center.z)
			var local := instance.global_transform.affine_inverse() * at_height
			var local_near := Vector3(
				clampf(local.x, -half.x, half.x), 0.0,
				clampf(local.z, -half.z, half.z))
			var world_near := instance.global_transform * local_near
			var distance := Vector2(
				world_near.x - center.x, world_near.z - center.z).length()
			if distance < nearest:
				nearest = distance
				nearest_name = str(instance.name)
		measured.append(nearest)
		if nearest < DOOR_VISUAL_CLEARANCE:
			problems.append("%s has %s at %.3f m" % [center, nearest_name, nearest])
		# The walking channel. Rendered geometry rather than colliders, for the
		# same reason the radius above uses it: several museum props are drawn
		# without a body, and a doorway a player reads as shut is shut.
		var channel := AABB(
			Vector3(center.x - DOOR_WALK_WIDTH * 0.5, DOOR_CLEARANCE_BOTTOM,
				center.z - DOOR_WALK_DEPTH),
			Vector3(DOOR_WALK_WIDTH,
				DOOR_CLEARANCE_TOP - DOOR_CLEARANCE_BOTTOM,
				DOOR_WALK_DEPTH * 2.0))
		for other in meshes:
			var walker := other as MeshInstance3D
			if walker == null or walker.mesh == null:
				continue
			scanned += 1
			var walk_box := walker.global_transform * walker.get_aabb()
			if not channel.intersects(walk_box):
				continue
			var mid := walk_box.get_center()
			problems.append("%s cannot be walked through, %s stands in the %.2f m channel at (%.2f %.2f %.2f)"
				% [center, walker.name, DOOR_WALK_WIDTH, mid.x, mid.y, mid.z])
	for swing in opened_swings:
		swing.call("set_open", false)
		for _step in range(90):
			swing.call("_physics_process", 1.0 / 60.0)
	if problems.is_empty():
		_ok("Storage door visuals: %d manual openings clear by %.3f/%.3f/%.3f m (gate %.2f m), %d meshes weighed against the %.2f x %.2f m walking channels"
			% [STORAGE_DOOR_CENTERS.size(), measured[0], measured[1], measured[2],
				DOOR_VISUAL_CLEARANCE, scanned, DOOR_WALK_WIDTH,
				DOOR_WALK_DEPTH * 2.0])
	else:
		_fail("Storage door visuals: %s (gate %.2f m)"
			% [", ".join(problems), DOOR_VISUAL_CLEARANCE])


# ---------------------------------------------------------------------------
# 10.6. The office wall, and the two things about it that a screenshot proves
# and a test suite otherwise cannot.
#
# The bank has been six framed panels since the office was rebuilt; since 10.3
# five of them show pictures. Three separate contracts hold that up, and each of
# them has already been broken once by an ordinary refactor elsewhere:
#
#   1. The dead panel stays dead. Its darkness and its three-degree tilt are the
#      prop's whole point, and the layout deliberately gives it the one wing the
#      player cannot get into on night one.
#   2. The layout is by wing, not by index. "The first six feeds" would put two
#      Atrium cameras and the office's own camera on the wall and no wing at all.
#   3. ONE texture per feed. The wall and the handheld are two consumers of the
#      same SubViewport; the failure mode is a second set of viewports appearing
#      quietly and doubling the render cost while looking completely correct.
func _verify_monitor_wall(map_root: Node, generated: Node) -> void:
	var wall: Node = null
	for node in get_nodes_in_group(MONITOR_WALL_GROUP):
		if generated.is_ancestor_of(node) or node == generated:
			wall = node
			break
	if wall == null:
		_fail("Monitor wall: no node in group '%s' — the office bank has no live feeds"
			% MONITOR_WALL_GROUP)
		return

	var bank: Node3D = null
	for node in get_nodes_in_group(MONITOR_BANK_GROUP):
		var candidate := node as Node3D
		if candidate != null and generated.is_ancestor_of(candidate):
			bank = candidate
			break
	if bank == null:
		_fail("Monitor wall: no monitor bank in group '%s'" % MONITOR_BANK_GROUP)
		return

	var panels := int(bank.get_meta("panels", 0))
	var dead_panel := int(bank.get_meta("dead_panel", -1))
	if panels != 6:
		_fail("Monitor wall: the bank carries %d panels, not the six the office is built around" % panels)
	if dead_panel < 0 or dead_panel >= panels:
		_fail("Monitor wall: no dead panel — the bank publishes dead_panel %d of %d"
			% [dead_panel, panels])

	var layout: Variant = _script_constant(MONITOR_WALL_SCRIPT, "PANEL_FEEDS")
	if typeof(layout) != TYPE_ARRAY:
		return
	var feeds: Variant = _script_constant(CAMERA_TABLET_SCRIPT, "CAMS")
	if typeof(feeds) != TYPE_ARRAY:
		return
	var cams: Array = feeds
	var panel_feeds: Array = layout
	if panel_feeds.size() != panels:
		_fail("Monitor wall: PANEL_FEEDS names %d panels but the bank builds %d"
			% [panel_feeds.size(), panels])

	# Every panel addresses a real post, and no post is on the wall twice: two
	# panels showing one feed would look like a working bank while wasting a
	# sixth of it.
	var seen := {}
	for panel in range(panel_feeds.size()):
		var feed_index := int(panel_feeds[panel])
		if feed_index < 0 or feed_index >= cams.size():
			_fail("Monitor wall: panel %d asks for feed %d, and CAMS declares %d"
				% [panel, feed_index, cams.size()])
			continue
		if seen.has(feed_index):
			_fail("Monitor wall: panels %d and %d both show feed %d"
				% [seen[feed_index], panel, feed_index])
			continue
		seen[feed_index] = panel

	# Contract 1: the live panels are every panel but the dead one, and the dead
	# one's post is on nobody's screen.
	var live: Array = wall.call("live_feeds") if wall.has_method("live_feeds") else []
	if live.size() != panels - 1:
		_fail("Monitor wall: %d panels hold feeds, expected %d (six panels, one dead)"
			% [live.size(), panels - 1])
	if dead_panel >= 0 and dead_panel < panel_feeds.size():
		var dead_feed := int(panel_feeds[dead_panel])
		if live.has(dead_feed):
			_fail("Monitor wall: the dead panel's feed %d is being drawn — the broken monitor lit up"
				% dead_feed)
		if bank.get_node_or_null("Monitor Feed %d" % dead_panel) != null:
			_fail("Monitor wall: panel %d is the dead one but carries a picture quad" % dead_panel)
		# It is dark, and it still says which camera the operator has lost.
		if bank.get_node_or_null("Monitor Caption %d" % dead_panel) == null:
			_fail("Monitor wall: the dead panel %d carries no caption — the room does not say which post is gone"
				% dead_panel)

	# Every live panel has a quad, and every quad is on the CCTV-hidden layer so
	# CAM 04 -- which is aimed at this very wall -- cannot film a monitor showing
	# itself showing a monitor.
	var hidden_layer := int(_script_constant(MONITOR_WALL_SCRIPT, "CCTV_HIDDEN_LAYER"))
	var hidden_mask := 1 << (hidden_layer - 1)
	var quads := 0
	for panel in range(panel_feeds.size()):
		if panel == dead_panel:
			continue
		var quad := bank.get_node_or_null("Monitor Feed %d" % panel) as MeshInstance3D
		if quad == null:
			_fail("Monitor wall: live panel %d has no picture quad" % panel)
			continue
		if quad.layers != hidden_mask:
			_fail("Monitor wall: panel %d's picture is on layers %d, not the CCTV-hidden layer %d — the office feed will film itself"
				% [panel, quad.layers, hidden_layer])
			continue
		quads += 1
	if quads == panels - 1:
		_ok("Monitor wall: %d live panels, one dead, all pictures hidden from the CCTV layer" % quads)

	# Contract 2: the layout is by wing. "First six feeds" is the failure this
	# rules out, so the assertion is about which ROOMS are on the wall, read off
	# the catalogue keys CAMS already carries.
	var wings := {}
	for feed_index in live:
		var row: Dictionary = cams[int(feed_index)]
		var label := str(row.get("label", ""))
		if label.begins_with("CAM_WING_"):
			wings[label] = true
	if wings.size() < 3:
		_fail("Monitor wall: only %d exhibit wings are on the bank — the layout has fallen back to feed order"
			% wings.size())
	else:
		_ok("Monitor wall: layout spans %d exhibit wings plus the approach" % wings.size())

	# Contract 3: one texture per feed, shared. Taking the same feed twice must
	# hand back the SAME texture, and the tablet must still own exactly one
	# viewport per post -- a wall that quietly built its own would pass every
	# check above while costing twice the frame.
	var tablet: Node = map_root.get_node_or_null("SecurityCameraTablet")
	if tablet == null or not tablet.has_method("feed_texture"):
		_fail("Monitor wall: SecurityCameraTablet exposes no feed_texture() to share")
		return
	var viewports := 0
	for child in tablet.get_children():
		if child is SubViewport:
			viewports += 1
	if viewports != cams.size():
		_fail("Monitor wall: the tablet owns %d feed viewports for %d posts — the wall is rendering its own copies"
			% [viewports, cams.size()])
	else:
		_ok("Monitor wall: %d feed viewports for %d posts — wall and handheld share one render each"
			% [viewports, cams.size()])
	var shared := 0
	for feed_index in live:
		var first: Texture2D = tablet.call("feed_texture", int(feed_index))
		var second: Texture2D = tablet.call("feed_texture", int(feed_index))
		if first == null:
			_fail("Monitor wall: feed %d hands back no texture" % int(feed_index))
		elif first != second:
			_fail("Monitor wall: feed %d hands a different texture to each consumer" % int(feed_index))
		else:
			shared += 1
		# Taken only to compare; a test must not leave five feeds rendering.
		tablet.call("release_feed", int(feed_index))
	if shared == live.size() and shared > 0:
		_ok("Monitor wall: all %d wall feeds are the same textures the handheld shows" % shared)

	# The scan may be satisfied from the wall as well as from the handheld, and
	# only from inside the office: the wall answers -1 while it holds no feeds,
	# and the player spawns at the entrance, twenty-five metres away.
	if not wall.has_method("watched_feed"):
		_fail("Monitor wall: no watched_feed() — the source scan cannot be confirmed from the bank")
	elif int(wall.call("watched_feed")) != -1:
		_fail("Monitor wall: watched_feed() answers a post while the player is not in the office")
	else:
		_ok("Monitor wall: watched_feed() is silent outside the office")
	var enhancements: Node = map_root.get_node_or_null(ENHANCEMENTS_NODE)
	if enhancements == null:
		_fail("Monitor wall: %s is missing, so nothing reads the bank" % ENHANCEMENTS_NODE)
	elif not enhancements.has_method("_wall_shows_required"):
		_fail("Monitor wall: %s no longer consults the bank — the scan is handheld-only again"
			% ENHANCEMENTS_NODE)
	else:
		_ok("Monitor wall: the source scan accepts the bank as well as the handheld")

	# ...and the branch is only real if watched_feed() can ever answer. Stand at
	# each panel in turn and aim at it: five must name their own post and the dead
	# one must stay silent. Without this the wall could hold five pictures, report
	# -1 forever, and no other check would notice the feature was decorative.
	var player := get_first_node_in_group("player") as Node3D
	var player_camera := player.get_node_or_null("Player Camera") as Camera3D if player != null else null
	if player == null or player_camera == null:
		_fail("Monitor wall: no player camera to aim at the bank")
		return
	# The map is generated paused, and the wall only tracks the operator's gaze on
	# unpaused frames. Both the pause flag and the player's pose are put back.
	var was_paused := paused
	var player_pose := player.global_transform
	var camera_pose := player_camera.transform
	paused = false
	var answered := 0
	for panel in range(panel_feeds.size()):
		var screen := bank.get_node_or_null("Monitor Screen %d" % panel) as Node3D
		if screen == null:
			continue
		# 1.5 m out along the bank's own facing, eyes at panel height.
		player.global_position = screen.global_position \
			+ bank.global_basis.z * 1.5 - Vector3(0.0, 0.9, 0.0)
		# Teleporting a CharacterBody3D does not stop it: gravity and depenetration
		# keep moving the body for several frames after the jump. Aiming before it
		# settles bakes a pitch that is already stale when the wall is read -- the
		# lower row starts 0.45 m above the floor, and 0.45 m of drop at 1.5 m range
		# is 16.7 deg against a WATCH_PANEL_ANGLE_DEG gate of 9.0. That is why this
		# answered -1 for a panel the operator was staring straight at, and why the
		# answer moved when unrelated props changed the weight of the scene: the
		# check was measuring settle timing, not aim. Settle FIRST, then aim, and
		# keep re-aiming while the wall latches its gaze, so a last millimetre of
		# settling cannot swing the result.
		for _i in range(8):
			await process_frame
		for _i in range(4):
			player_camera.look_at(screen.global_position, Vector3.UP)
			await process_frame
		player_camera.look_at(screen.global_position, Vector3.UP)
		var watched := int(wall.call("watched_feed"))
		if panel == dead_panel:
			if watched != -1:
				_fail("Monitor wall: looking at the dead panel %d reports post %d"
					% [panel, watched])
			else:
				answered += 1
		elif watched != int(panel_feeds[panel]):
			_fail("Monitor wall: looking at panel %d reports post %d, expected %d"
				% [panel, watched, int(panel_feeds[panel])])
		else:
			answered += 1
	# Put the operator back at the entrance and let the wall drop its feeds before
	# the tree is paused again, so the sweep leaves nothing rendering.
	player.global_transform = player_pose
	player_camera.transform = camera_pose
	for _i in range(3):
		await process_frame
	paused = was_paused
	if answered == panel_feeds.size():
		_ok("Monitor wall: each of the %d panels names its own post when looked at, the dead one stays silent"
			% answered)


# Cycling feeds must remain reachable on a controller. Both actions carry a key
# AND a shoulder trigger; a refactor that rebinds them to keys only takes the
# CCTV pages away from a gamepad player entirely, which no other check notices.
func _verify_camera_cycle_actions() -> void:
	var bound := 0
	for action_variant in CAMERA_CYCLE_ACTIONS:
		var action := str(action_variant)
		if not InputMap.has_action(action):
			_fail("Camera cycling: input action '%s' does not exist" % action)
			continue
		var has_pad := false
		var has_key := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion or event is InputEventJoypadButton:
				has_pad = true
			elif event is InputEventKey:
				has_key = true
		if not has_pad:
			_fail("Camera cycling: '%s' has no gamepad binding" % action)
		elif not has_key:
			_fail("Camera cycling: '%s' has no keyboard binding" % action)
		else:
			bound += 1
	if bound == CAMERA_CYCLE_ACTIONS.size():
		_ok("Camera cycling: %d actions bound on both keyboard and gamepad" % bound)


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


## EVERY SLICE ANOMALY HAS TO SHOW ITS WORK
##
## The price the audit sets for taking the diagnosis off the terminal (12.7 p.12):
## an anomaly that stops naming the device owes at least two independent signs in
## its place, and must still have exactly one canonical way to be closed. Both
## halves matter. Signs with no single closure is a guessing game with ten
## answers; a single closure with no signs is the progress bar the slice exists
## to delete.
##
## A CLOSED RIFT LEAVES THE MUSEUM CHANGED (audit 16.6 п. 15).
##
## The night calls GameManager.rift_shift_targets() with the map's live
## _powered_lights; this asks the same function the same question with a
## hand-built shelf of fixtures, so the rule is checked without a map or a
## physics frame. Three things have to hold: only lit fixtures are eligible,
## the nearest ones are the ones taken, and the count never exceeds
## RIFT_SHIFT_LIGHTS. The flash key is checked too -- a shift the operator is
## never told about is indistinguishable from a lighting bug.
func _verify_rift_shift() -> void:
	var script: Variant = load("res://game/GameManager.gd")
	if script == null or not script.has_method("rift_shift_targets"):
		_fail("Rift shift: GameManager exposes no rift_shift_targets()")
		return
	var limit: Variant = _script_constant("res://game/GameManager.gd", "RIFT_SHIFT_LIGHTS")
	if typeof(limit) != TYPE_INT or int(limit) <= 0:
		_fail("Rift shift: RIFT_SHIFT_LIGHTS is missing or not a positive count")
		return
	var count := int(limit)
	# Distances 1, 2, 3, 4 and 5 metres from the exit. The 2 m fixture is already
	# dark, so a correct answer skips it and reaches for the 3 m one instead.
	var shelf: Array = []
	for step in range(1, 6):
		var light := OmniLight3D.new()
		light.name = "Rift Shift Probe %d" % step
		light.position = Vector3(float(step), 0.0, 0.0)
		light.visible = step != 2
		shelf.append(light)
	var picked: Variant = script.call("rift_shift_targets", shelf, Vector3.ZERO, count)
	var problems: Array[String] = []
	if typeof(picked) != TYPE_ARRAY:
		problems.append("rift_shift_targets() returned no array")
	else:
		var chosen: Array = picked
		if chosen.size() != count:
			problems.append("took %d fixtures, expected %d" % [chosen.size(), count])
		var last := -1.0
		for node in chosen:
			var light := node as Node3D
			if light == null:
				problems.append("a taken entry is not a Node3D")
				continue
			if not light.visible:
				problems.append("%s was already dark and was taken anyway" % light.name)
			var here := light.position.x
			if here < last:
				problems.append("%s breaks the nearest-first order" % light.name)
			last = here
	# Never leave probes behind: these were never in the tree, so free() is the
	# only thing that reclaims them.
	for node in shelf:
		(node as Node).free()
	# _catalogue_rows() is keyed by localisation key, so membership is the whole
	# question here.
	var rows := _catalogue_rows()
	if not rows.has("HUD_RIFT_RETURN_SHIFT"):
		problems.append("HUD_RIFT_RETURN_SHIFT is missing from the catalogue")
	if problems.is_empty():
		_ok("Rift shift: the %d nearest lit fixtures go dark on the way out, announced" % count)
	else:
		_fail("Rift shift: %s" % "; ".join(problems))


## THE CHASE HAS TO STAY A DECISION (audit 16.6 п. 4, corrected here).
##
## The audit claimed the night-3 Curator at 4.9 + 0.7 x 2 = 6.3 m/s outruns the
## operator, reading GAIT_RUN_SPEED 6.0 as the player's sprint. It is not: that
## constant is the Curator's own noise classifier, the threshold above which a
## moving player counts as running. The real sprint is PlayerController's
## run_speed, and it is 7.5. So the pace is sound and nothing needed changing --
## but nothing was holding it either, and the two numbers live in files that do
## not know about each other. This gate is that hold. Three rules:
##
##   1. Sprinting always gains ground, on every night, with a margin to spare.
##   2. From the night it hunts, walking always loses ground -- otherwise the
##      sprint, and the stamina it spends, is decoration.
##   3. The null lantern keeps its promise: a slowed Curator falls below a walk,
##      so carrying it means leaving without spending stamina at all.
func _verify_curator_pace() -> void:
	const CURATOR := "res://game/CuratorMonster.gd"
	## Metres per second of headroom the sprint must keep over the fastest night.
	## 1.0 is one second of sprinting buying a metre of gap -- thin enough to feel
	## like a chase, wide enough that a doorway does not decide it.
	const PACE_MARGIN := 1.0
	var base: Variant = _script_constant(CURATOR, "BASE_SPEED")
	var per_night: Variant = _script_constant(CURATOR, "SPEED_PER_NIGHT")
	var lantern: Variant = _script_constant(CURATOR, "NULL_LANTERN_FACTOR")
	var max_night: Variant = _script_constant("res://game/GameManager.gd", "MAX_NIGHT")
	if typeof(base) not in [TYPE_FLOAT, TYPE_INT] \
			or typeof(per_night) not in [TYPE_FLOAT, TYPE_INT] \
			or typeof(lantern) not in [TYPE_FLOAT, TYPE_INT] \
			or typeof(max_night) != TYPE_INT:
		_fail("Curator pace: speed or night constants are missing")
		return
	# The player's speeds are exports, not constants, so the defaults have to be
	# read off a real instance. It never enters the tree, so nothing runs.
	var player_script: Variant = load("res://game/PlayerController.gd")
	if player_script == null:
		_fail("Curator pace: PlayerController.gd will not load")
		return
	var player: Node = player_script.new()
	var run_speed := float(player.get("run_speed"))
	var walk_speed := float(player.get("walk_speed"))
	var stamina := float(player.get("max_stamina"))
	var drain := float(player.get("stamina_drain_per_second"))
	player.free()
	var problems: Array[String] = []
	var nights: Array[String] = []
	var top := 0.0
	for night in range(1, int(max_night) + 1):
		var speed := float(base) + float(per_night) * float(night - 1)
		top = maxf(top, speed)
		nights.append("%.2f" % speed)
		if speed > run_speed - PACE_MARGIN:
			problems.append("night %d at %.2f m/s leaves the sprint (%.2f) under %.2f m/s of headroom"
				% [night, speed, run_speed, PACE_MARGIN])
		# It only hunts from the second night; the first one is the museum alone.
		if night >= 2 and speed <= walk_speed:
			problems.append("night %d at %.2f m/s does not out-walk the operator (%.2f)"
				% [night, speed, walk_speed])
	var slowed := top * float(lantern)
	if slowed >= walk_speed:
		problems.append("the lantern leaves %.2f m/s, at or above a walk (%.2f)" % [slowed, walk_speed])
	if problems.is_empty():
		# One full stamina bar of sprinting, and the ground it buys against the
		# fastest night: the number the whole chase is balanced on.
		var burst := stamina / maxf(drain, 0.001)
		var gained := (run_speed - top) * burst
		_ok("Curator pace: nights %s m/s vs sprint %.2f, walk %.2f, lantern %.2f; one bar buys %.1f m in %.1f s"
			% ["/".join(nights), run_speed, walk_speed, slowed, gained, burst])
	else:
		_fail("Curator pace: %s" % "; ".join(problems))


## GUESSING THE DEVICE HAS TO COST (audit 16.6 п. 3).
##
## The failure this guards is a whole missing game rather than a bug: with a free
## wrong answer the ten instruments are a keyring, and the terminal readout, the
## signs and the walk to storage are all decoration. The numbers have to stay in a
## narrow band on both sides -- large enough that brute force loses the night,
## small enough that one honest mistake does not.
func _verify_wrong_tool_cost() -> void:
	const MANAGER := "res://game/GameManager.gd"
	## A single mistake may not take more than this share of the shortest night;
	## the whole storage row must take more than the second share of it.
	const SINGLE_MAX_SHARE := 0.10
	const THREE_MIN_SHARE := 0.20
	var penalty: Variant = _script_constant(MANAGER, "WRONG_TOOL_PENALTY")
	var noise: Variant = _script_constant(MANAGER, "WRONG_TOOL_NOISE")
	var floor_left: Variant = _script_constant(MANAGER, "WRONG_TOOL_FLOOR")
	var nights: Variant = _script_constant(MANAGER, "NIGHT_CONFIG")
	var run_noise: Variant = _script_constant("res://game/CuratorMonster.gd", "NOISE_RUN")
	var throw_noise: Variant = _script_constant("res://game/CuratorMonster.gd", "NOISE_THROW")
	if typeof(penalty) not in [TYPE_FLOAT, TYPE_INT] \
			or typeof(noise) not in [TYPE_FLOAT, TYPE_INT] \
			or typeof(floor_left) not in [TYPE_FLOAT, TYPE_INT] \
			or typeof(run_noise) not in [TYPE_FLOAT, TYPE_INT] \
			or typeof(throw_noise) not in [TYPE_FLOAT, TYPE_INT] \
			or typeof(nights) != TYPE_DICTIONARY:
		_fail("Wrong-tool cost: the penalty or noise constants are missing")
		return
	# The shortest night is the one the price has to be judged against: it is the
	# night with the least room for a mistake.
	var shortest := 0.0
	for key in (nights as Dictionary).keys():
		var row: Variant = (nights as Dictionary)[key]
		if typeof(row) == TYPE_DICTIONARY and (row as Dictionary).has("timer"):
			var seconds := float((row as Dictionary)["timer"])
			shortest = seconds if shortest <= 0.0 else minf(shortest, seconds)
	var problems: Array[String] = []
	if shortest <= 0.0:
		problems.append("NIGHT_CONFIG carries no timers to price the guess against")
	else:
		var one := float(penalty)
		# The three guesses of an escalating price, which is what walking the
		# storage row actually costs: 1x, then 2x, then 3x.
		var three := one * 6.0
		if one > shortest * SINGLE_MAX_SHARE:
			problems.append("one mistake costs %.0f s of a %.0f s night, over %d%%"
				% [one, shortest, int(SINGLE_MAX_SHARE * 100.0)])
		if three < shortest * THREE_MIN_SHARE:
			problems.append("three guesses cost %.0f s of a %.0f s night, under %d%%"
				% [three, shortest, int(THREE_MIN_SHARE * 100.0)])
		if float(floor_left) <= 0.0 or float(floor_left) >= shortest:
			problems.append("the floor of %.0f s does not sit inside a %.0f s night"
				% [float(floor_left), shortest])
	# Heard, and heard as something louder than a running operator: the exhibit
	# answering is the loudest thing in the wing short of a thrown object.
	if float(noise) <= float(run_noise) or float(noise) >= float(throw_noise):
		problems.append("the noise %.2f is not between a run (%.2f) and a throw (%.2f)"
			% [float(noise), float(run_noise), float(throw_noise)])
	var rows := _catalogue_rows()
	for key in ["HUD_WRONG_TOOL", "HUD_WRONG_TOOL_COST"]:
		if not rows.has(key):
			problems.append("%s is missing from the catalogue" % key)
	if problems.is_empty():
		_ok("Wrong-tool cost: %.0f/%.0f/%.0f s of a %.0f s night and a noise of %.2f, floor %.0f s"
			% [float(penalty), float(penalty) * 2.0, float(penalty) * 3.0, shortest,
			float(noise), float(floor_left)])
	else:
		_fail("Wrong-tool cost: %s" % "; ".join(problems))


## THE DISCRIMINATION MATRIX HAS TO STAY SOLVABLE (audit 16.6 п. 2).
##
## The matrix in GameManager.SIGNS is content, and content drifts: someone adds an
## eleventh anomaly, reuses a memorable sign twice, and the wing quietly becomes
## either unsolvable or free. Neither failure shows up in a playtest as a bug --
## it shows up as a player who guesses. So the four invariants are checked here
## rather than trusted to review.
func _verify_sign_matrix() -> void:
	## Three observations per anomaly: two would be the answer itself, four a list.
	const SIGNS_PER_ANOMALY := 3
	## No sign may belong to a single anomaly, or one glance names the device.
	const MIN_ANOMALIES_PER_SIGN := 2
	## Two anomalies may share at most one sign, which is what makes any PAIR of
	## observations conclusive and the third sign a check against a misread.
	const MAX_SHARED_SIGNS := 1
	var anomalies: Variant = _script_constant("res://game/GameManager.gd", "ANOMALIES")
	var signs: Variant = _script_constant("res://game/GameManager.gd", "SIGNS")
	if typeof(anomalies) != TYPE_DICTIONARY or typeof(signs) != TYPE_DICTIONARY:
		_fail("Sign matrix: GameManager exposes no anomaly or sign table")
		return
	var rows := _catalogue_rows()
	if rows.is_empty():
		_fail("Sign matrix: %s is empty or unreadable" % LOCALIZATION_CSV)
		return
	var problems: Array[String] = []
	# Which anomalies each sign belongs to, built once and read three times below.
	var owners := {}
	var sets := {}
	for id in anomalies:
		var info: Dictionary = anomalies[id]
		var list: Variant = info.get("signs", null)
		if typeof(list) != TYPE_ARRAY or (list as Array).size() != SIGNS_PER_ANOMALY:
			problems.append("%s does not carry %d signs" % [id, SIGNS_PER_ANOMALY])
			continue
		var unique := {}
		for sign_id in (list as Array):
			var key := str(sign_id)
			if unique.has(key):
				problems.append("%s lists %s twice" % [id, key])
				continue
			unique[key] = true
			if not signs.has(key):
				problems.append("%s names an unknown sign %s" % [id, key])
				continue
			if not owners.has(key):
				owners[key] = [] as Array[String]
			(owners[key] as Array).append(str(id))
		sets[str(id)] = unique
	# 2. A sign nobody shares is an answer key, and a sign nobody uses is a lie in
	# the table.
	for key in signs:
		var count: int = (owners[key] as Array).size() if owners.has(key) else 0
		if count < MIN_ANOMALIES_PER_SIGN:
			problems.append("%s belongs to %d anomaly(ies)" % [key, count])
		var row := str(signs[key])
		if not rows.has(row):
			problems.append("%s has no catalogue row" % row)
			continue
		var texts: PackedStringArray = rows[row]
		for i in range(texts.size()):
			if texts[i].strip_edges() == "":
				problems.append("%s is empty in column %d" % [row, i])
	# 3. Any two anomalies have to differ in at least two of their three signs.
	var ids := sets.keys()
	ids.sort()
	var closest := SIGNS_PER_ANOMALY
	for a in range(ids.size()):
		for b in range(a + 1, ids.size()):
			var left: Dictionary = sets[ids[a]]
			var right: Dictionary = sets[ids[b]]
			var shared := 0
			for key in left:
				if right.has(key):
					shared += 1
			closest = mini(closest, SIGNS_PER_ANOMALY - shared)
			if shared > MAX_SHARED_SIGNS:
				problems.append("%s and %s share %d signs" % [ids[a], ids[b], shared])
	if problems.is_empty():
		_ok("Sign matrix: %d anomalies over %d signs, every sign shared by %d+, closest pair still differs in %d of %d"
			% [ids.size(), signs.size(), MIN_ANOMALIES_PER_SIGN, closest, SIGNS_PER_ANOMALY])
	else:
		_fail("Sign matrix: %s" % "; ".join(problems))


## Catalogue-only, so it stands next to _verify_localization() instead of inside
## the world sweep: nothing here needs a built map or a physics frame.
func _verify_incident_signs() -> void:
	var anomalies: Variant = _script_constant("res://game/GameManager.gd", "ANOMALIES")
	var equipment: Variant = _script_constant("res://game/GameManager.gd", "EQUIPMENT")
	if typeof(anomalies) != TYPE_DICTIONARY or typeof(equipment) != TYPE_DICTIONARY:
		_fail("Incident signs: GameManager exposes no anomaly or equipment table")
		return
	var rows := _catalogue_rows()
	if rows.is_empty():
		_fail("Incident signs: %s is empty or unreadable" % LOCALIZATION_CSV)
		return
	var signs_table: Variant = _script_constant("res://game/GameManager.gd", "SIGNS")
	if typeof(signs_table) != TYPE_DICTIONARY:
		_fail("Incident signs: GameManager exposes no sign table")
		return
	var problems: Array[String] = []
	var posts := 0
	var checked := 0
	for id in anomalies:
		var info: Dictionary = anomalies[id]
		var equip := str(info.get("equipment", ""))
		# One canonical closure, and one the storage shelf actually holds.
		if equip == "" or not equipment.has(equip):
			problems.append("%s names no device on the shelf" % id)
			continue
		# The written readout is gone on purpose: it was the second description of an
		# incident and the one the prescription survived in. A new anomaly that
		# brings it back would be diagnosed for the operator again.
		if info.has("readout"):
			problems.append("%s still carries a written readout" % id)
		if not bool(info.get("self_diagnosed", false)):
			problems.append("%s is still diagnosed for the operator" % id)
		var device_key := str((equipment[equip] as Dictionary).get("name", ""))
		if not rows.has(device_key):
			problems.append("%s has no catalogue row for its device" % id)
			continue
		var names: PackedStringArray = rows[device_key]
		# Everything the operator gets to read about this incident: the three signs
		# the terminal prints and the line its camera post yields. All of it is held
		# to the same rule, because the answer only has to leak from one of them.
		var keys := PackedStringArray()
		for sign_id in (info.get("signs", []) as Array):
			keys.append(str(signs_table.get(str(sign_id), "")))
		# The camera post owes a readable line too, or "signs instead of a bar" is
		# only true of the terminal and the CCTV is still a fill with a percentage.
		var evidence := str(info.get("evidence", ""))
		if evidence == "" or not rows.has(evidence):
			problems.append("%s promises no evidence line for its camera post" % id)
		else:
			posts += 1
			keys.append(evidence)
		for key in keys:
			if key == "" or not rows.has(key):
				problems.append("%s reads a line with no catalogue row" % id)
				continue
			checked += 1
			var texts: PackedStringArray = rows[key]
			# Every shipped locale, not just the one this run happens to boot in: a
			# translation that kept the old prescription hands the answer back to half
			# the players and nothing else in the build would notice.
			for i in range(texts.size()):
				var upper := texts[i].to_upper()
				if upper.strip_edges() == "":
					problems.append("%s is empty in column %d" % [key, i])
				if i < names.size() and names[i].strip_edges() != "" and upper.contains(names[i].to_upper()):
					problems.append("%s names %s in column %d" % [key, names[i], i])
				if upper.contains("PROTOCOL:") or upper.contains("ПРОТОКОЛ:"):
					problems.append("%s still prescribes a protocol in column %d" % [key, i])
	if problems.is_empty():
		_ok("Incident signs: %d anomalies self-diagnosed, %d camera posts yielding a line, %d readable lines and none names its device"
			% [anomalies.size(), posts, checked])
	else:
		_fail("Incident signs: %s" % [", ".join(problems)])


## Whole rows, not just the first column: the signs gate has to read what the
## catalogue actually says in every shipped locale.
func _catalogue_rows() -> Dictionary:
	var rows := {}
	var file := FileAccess.open(LOCALIZATION_CSV, FileAccess.READ)
	if file == null:
		return rows
	var header := true
	while not file.eof_reached():
		var row := file.get_csv_line()
		if header:
			header = false
			continue
		if row.is_empty():
			continue
		var key := row[0].strip_edges()
		if key == "":
			continue
		rows[key] = row.slice(1)
	file.close()
	return rows


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


## CROUCH MUST STAY A REAL STEALTH VERB
##
## Confirmed by hand once, then pinned here, because three different owners can
## break it without a single error in the log:
##
## 1. PlayerScaleController owns the capsule, the collision offset and the camera
##    height, and rewrites all three every frame an anomaly is resizing the
##    player. Crouch therefore lives inside it as a second multiplier. If it is
##    ever moved back into PlayerController, the two owners fight over the shape
##    and the winner depends on the frame.
## 2. Standing up is refused while there is no headroom. Without that check,
##    releasing the key under a shelf grows the capsule into the shelf, and the
##    body is either shoved sideways or pushed through the floor.
## 3. The radius must NOT shrink with the crouch. A thinner player slips through
##    gaps the level was never built to let anything pass.
const CROUCH_PROBE_SPOT := Vector3(0.0, 1.0, 44.0)
const CROUCH_LID_CLEARANCE := 1.25
const CROUCH_HEIGHT_TOLERANCE := 0.02
## Live stealth-kit gate behind the office credenza. Y comes from the actual
## bodies; only the authored floor-plan coordinates are fixed here.
const CURATOR_COVER_PLAYER_XZ := Vector2(-25.0, 4.85)
const CURATOR_COVER_WATCHER_XZ := Vector2(-25.0, 9.0)
const CURATOR_EXPECTED_SEARCH := 6.0
const CURATOR_EXPECTED_VISIBLE_CATCH := 1.25
const CURATOR_EXPECTED_BLIND_CATCH := 0.7
const CURATOR_SEARCH_MAX_TICKS := 420
## A thrown device pulls the Curator this far in three seconds, measured at
## 7.72 m; the floor leaves room for pathing noise but fails on a dead decoy.
const CURATOR_DECOY_MIN_CLOSED := 5.0
const CURATOR_SEARCH_TOLERANCE := 0.05
## One existing object per room: no new furniture, just a permanent contract
## that the night route keeps offering crouch-height cover.
const ROUTE_COVERS := [
	{"label": "Gravity", "owner": "Inversion Room Exhibit Pedestal",
		"player": Vector2(28.0, -2.65), "curator": Vector2(28.0, -8.0)},
	{"label": "Time", "owner": "Time Loop Exhibit Pedestal",
		"player": Vector2(8.0, -25.65), "curator": Vector2(8.0, -31.5)},
	{"label": "Archive", "owner": "Archive Card Catalogue",
		"player": Vector2(-22.58, -15.95), "curator": Vector2(-26.5, -15.95)},
]
const ROUTE_COVER_MIN_HEIGHT := 1.0
const ROUTE_COVER_MAX_HEIGHT := 1.4
const ROUTE_COVER_MIN_SPAN := 1.0
const CROUCH_EYE_CLEARANCES := {
	"terminal console top": 1.29,
	"reception counter top": 1.16,
}

func _verify_crouch() -> void:
	if not InputMap.has_action("crouch") \
			or InputMap.action_get_events("crouch").is_empty():
		_fail("Crouch: the crouch action is missing or carries no events, so "
			+ "the verb cannot be reached at all")
		return
	# R3 was taken from slot_next for the crouch; the belt must keep a way to cycle.
	if InputMap.has_action("slot_next") \
			and InputMap.action_get_events("slot_next").is_empty():
		_fail("Crouch: slot_next lost every event when R3 was reassigned, the "
			+ "belt can no longer be cycled")
		return
	var player := get_first_node_in_group("player") as Node3D
	if player == null:
		_fail("Crouch: no player in the tree")
		return
	var col := player.get_node_or_null("Player Collision") as CollisionShape3D
	if col == null:
		_fail("Crouch: the player carries no Player Collision node")
		return
	var capsule := col.shape as CapsuleShape3D
	var cam := player.get_node_or_null("Player Camera") as Node3D
	if capsule == null or cam == null:
		_fail("Crouch: the player capsule or the camera is missing")
		return
	var scaler := get_first_node_in_group("player_scale_controller")
	if scaler == null or not scaler.has_method("set_crouch"):
		_fail("Crouch: the scale controller is absent or no longer owns the "
			+ "crouch, which means the capsule has two owners again")
		return

	paused = false
	var prior_controls := bool(player.get("controls_enabled"))
	player.set("controls_enabled", true)
	player.global_position = CROUCH_PROBE_SPOT
	await _spin(8)
	var stand_h := capsule.height
	var stand_r := capsule.radius
	var problems: Array[String] = []

	Input.action_press("crouch")
	await _spin(30)
	var crouch_h := capsule.height
	var crouch_r := capsule.radius
	var crouch_eye := cam.position.y
	if crouch_h > stand_h - 0.3:
		problems.append("holding the key shrank the capsule from %.3f only to "
			% stand_h + "%.3f" % crouch_h)
	if not bool(player.get("crouching")):
		problems.append("the player never reported itself as crouching")
	if absf(crouch_r - stand_r) > 0.001:
		problems.append("the radius moved with the crouch, %.3f -> %.3f"
			% [stand_r, crouch_r])
	for label in CROUCH_EYE_CLEARANCES:
		var top: float = CROUCH_EYE_CLEARANCES[label]
		if crouch_eye >= top:
			problems.append("the crouched eye at %.3f does not clear the %s at "
				% [crouch_eye, label] + "%.2f" % top)

	# Releasing the key under a low lid must leave the player down.
	var lid := StaticBody3D.new()
	lid.name = "Crouch Gate Lid"
	var lid_shape := CollisionShape3D.new()
	var lid_box := BoxShape3D.new()
	lid_box.size = Vector3(3.0, 0.2, 3.0)
	lid_shape.shape = lid_box
	lid.add_child(lid_shape)
	player.get_parent().add_child(lid)
	lid.global_position = player.global_position \
		+ Vector3(0.0, CROUCH_LID_CLEARANCE, 0.0)
	await _spin(4)
	Input.action_release("crouch")
	await _spin(20)
	if capsule.height > crouch_h + CROUCH_HEIGHT_TOLERANCE:
		problems.append("the player stood up under a %.2f m lid, capsule %.3f"
			% [CROUCH_LID_CLEARANCE, capsule.height])
	lid.queue_free()
	await _spin(40)
	if absf(capsule.height - stand_h) > CROUCH_HEIGHT_TOLERANCE:
		problems.append("the player never stood back up once the lid was gone, "
			+ "capsule %.3f against %.3f" % [capsule.height, stand_h])

	Input.action_release("crouch")
	player.set("controls_enabled", prior_controls)
	if problems.is_empty():
		_ok("Crouch: capsule %.3f -> %.3f, eye %.3f, radius held at %.3f, "
			% [stand_h, crouch_h, crouch_eye, stand_r]
			+ "stand-up refused under a %.2f m lid" % CROUCH_LID_CLEARANCE)
	else:
		_fail("Crouch: %s" % [", ".join(problems)])


## How far a locker's approach point may sit from navigable floor. Doorways keep
## 0.9 m of mesh, so anything inside this is a point the Curator can path to.
const HIDE_APPROACH_TOLERANCE := 0.6


## The box a locker door has to swing into and a player has to walk through: one
## metre out from the door face, the full outer width of the shell, from 0.05 m
## to 1.95 m up. Built from the locker's own transform, so it turns with it.
func _doorway_volume(spot: Node3D) -> AABB:
	var half_width := HideSpot.INTERIOR.x * 0.5 + HideSpot.WALL
	var near_z := -(HideSpot.INTERIOR.z * 0.5 + HideSpot.WALL)
	var far_z := -(HideSpot.INTERIOR.z * 0.5 + 1.0)
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for local in [Vector3(-half_width, 0.05, near_z), Vector3(half_width, 0.05, near_z),
			Vector3(-half_width, 1.95, far_z), Vector3(half_width, 1.95, far_z)]:
		var point: Vector3 = spot.to_global(local)
		low = Vector3(minf(low.x, point.x), minf(low.y, point.y), minf(low.z, point.z))
		high = Vector3(maxf(high.x, point.x), maxf(high.y, point.y), maxf(high.z, point.z))
	return AABB(low, high - low)


## A LOCKER MUST BE ENTERABLE, OPAQUE AND SEARCHABLE
##
## Three separate facts make a hiding place, and scenery passes none of them:
## the real player capsule fits inside, a sightline into it dies on the shut
## door and lives when that door is open, and the Curator's own check() hands
## back an occupant. The approach point is measured against the baked navigation
## mesh, because a locker the Curator cannot walk up to can never be searched.
## The doorway itself is measured twice over: with rays at four heights, and
## against raw mesh geometry, because a prop with no collider blocks a door just
## as thoroughly as one with a collider and no ray will ever find it.
func _verify_hide_spots() -> void:
	# This script is a SceneTree, not a Node: groups and the world come off self
	# and off `root`, exactly as the other world checks in this file do it.
	var spots: Array = get_nodes_in_group("hide_spot")
	if spots.size() < 2:
		_fail("Hide spots: the map builds %d lockers, expected 2" % spots.size())
		return
	var player := get_first_node_in_group("player") as CharacterBody3D
	var collision := player.get_node_or_null("Player Collision") as CollisionShape3D if player != null else null
	var capsule := collision.shape as CapsuleShape3D if collision != null else null
	if capsule == null:
		_fail("Hide spots: the player capsule is missing")
		return

	var problems: Array[String] = []
	var width_slack := HideSpot.INTERIOR.x - capsule.radius * 2.0
	var head_slack := HideSpot.INTERIOR.y - capsule.height
	if width_slack <= 0.0 or head_slack <= 0.0:
		problems.append("the capsule does not fit: %.2f wide and %.2f tall against %.2f x %.2f"
			% [capsule.radius * 2.0, capsule.height, HideSpot.INTERIOR.x, HideSpot.INTERIOR.y])

	var world: World3D = root.world_3d
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var nav_map: RID = world.navigation_map
	var blocked := 0
	var cleared := 0
	var reachable := 0
	var handed_over := 0
	# A check that finds nothing and says nothing is indistinguishable from a
	# check that never ran, so the mesh sweep below reports how much geometry it
	# looked at and what the closest thing to each door actually is.
	var scanned := 0
	var neighbours: Array[String] = []
	for node in spots:
		var spot := node as Node3D
		var inside: Vector3 = spot.call("hide_point") + Vector3.UP * (capsule.height * 0.5)
		var approach: Vector3 = spot.call("approach_point")
		var eye := approach + Vector3.UP * 1.6

		spot.call("set_closed", true)
		await _spin(2)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, inside)).is_empty():
			blocked += 1
		else:
			problems.append("%s does not stop a sightline while shut" % spot.name)

		spot.call("set_closed", false)
		await _spin(2)
		var open_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, inside))
		if open_hit.is_empty():
			cleared += 1
		else:
			# Name the blocker: an open locker that still hides its occupant is
			# almost always a prop the placement walked into, and the name says
			# which one without another run.
			var blocker := open_hit["collider"] as Node
			var where: Vector3 = open_hit["position"]
			problems.append("%s stays opaque with its door open, the ray dies on %s at (%.2f %.2f %.2f)"
				% [spot.name, "nothing" if blocker == null else blocker.name, where.x, where.y, where.z])

		# The ray above leaves the eye at 1.6 m and flies straight over furniture.
		# Reported live: a locker with a waist-high cabinet parked against its door,
		# invisible to a single chest-height ray and impossible to walk into. The
		# doorway is now measured at four heights, from shin to eye, with the door
		# still open from the check above.
		for height in [0.25, 0.6, 1.1, 1.6]:
			var from_point: Vector3 = approach + Vector3.UP * height
			var to_point: Vector3 = spot.call("hide_point") + Vector3.UP * height
			var door_query := PhysicsRayQueryParameters3D.create(from_point, to_point)
			door_query.collision_mask = 1
			var door_hit := space.intersect_ray(door_query)
			if door_hit.is_empty():
				continue
			var stopper := door_hit["collider"] as Node
			var stop_at: Vector3 = door_hit["position"]
			problems.append("%s cannot be walked into at %.2f m, %s stands in the doorway at (%.2f %.2f %.2f)"
				% [spot.name, height, "nothing" if stopper == null else stopper.name, stop_at.x, stop_at.y, stop_at.z])

		# Rays only find colliders, and a prop can hide a door perfectly well with
		# nothing but a mesh -- several props in this museum are deliberately
		# collider-free so they cost the aisle beside them nothing. Reported live:
		# a cabinet standing over a locker door that every ray above flew through.
		# So the swing volume in front of the door is also measured against raw
		# geometry: 1.0 m out from the door face, the full width of the shell, from
		# ankle to head.
		var swing := _doorway_volume(spot)
		var door_face: Vector3 = spot.to_global(Vector3(0.0, 1.0,
			-(HideSpot.INTERIOR.z * 0.5 + HideSpot.WALL)))
		var nearest_name := "nothing"
		var nearest_distance := INF
		for mesh_node in root.find_children("*", "MeshInstance3D", true, false):
			var mesh := mesh_node as MeshInstance3D
			if mesh == null or mesh.mesh == null or spot.is_ancestor_of(mesh):
				continue
			scanned += 1
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			var centre := box.get_center()
			var gap := door_face.distance_to(centre)
			if gap < nearest_distance:
				nearest_distance = gap
				nearest_name = mesh.name
			if not swing.intersects(box):
				continue
			problems.append("%s has %s standing over its door at (%.2f %.2f %.2f)"
				% [spot.name, mesh.name, centre.x, centre.y, centre.z])
		neighbours.append("%s: nearest %s at %.2f m" % [spot.name, nearest_name, nearest_distance])

		spot.call("set_closed", true)
		await _spin(2)

		var on_mesh := NavigationServer3D.map_get_closest_point(nav_map, approach)
		var drift := Vector2(on_mesh.x - approach.x, on_mesh.z - approach.z).length()
		if drift <= HIDE_APPROACH_TOLERANCE:
			reachable += 1
		else:
			problems.append("%s stands %.2f m off the navigation mesh" % [spot.name, drift])

		spot.call("take", true)
		if bool(spot.call("check")):
			handed_over += 1
		else:
			problems.append("%s keeps an occupant from a Curator opening it" % spot.name)
		spot.call("take", false)
		spot.call("set_closed", true)
	await _spin(2)

	if problems.is_empty():
		_ok("Hide spots: %d lockers, the capsule fits with %.2f m spare sideways and %.2f m overhead, %d block a sightline shut and %d clear it open, %d approach points on the navmesh, %d hand over an occupant, %d meshes weighed against the doorways (%s)"
			% [spots.size(), width_slack, head_slack, blocked, cleared, reachable, handed_over, scanned, ", ".join(neighbours)])
	else:
		_fail("Hide spots: %s" % [", ".join(problems)])


## How far a gate's approach point may sit from navigable floor. Same tolerance a
## locker gets, for the same reason: a threshold nobody can walk up to is scenery.
const GATE_APPROACH_TOLERANCE := 0.6
const EXHIBIT_SCRIPT := "res://game/ExhibitPuzzleController.gd"


## A RIFT MUST BE A DOORWAY IN THIS ROOM, NOT A LEVEL CHANGE
##
## Audit 16.6 п. 6: the pocket dimension used to start the instant the device
## touched the exhibit, and the player was moved 262 m along Z and 72 m up. The
## rift is now a RiftGate standing in the hall's own geometry, and the transition
## only happens when the operator walks through it. That is only true if the gate
## can actually be walked through, at every exhibit the incident can pick.
##
## For each exhibit origin in ExhibitPuzzleController.EXHIBITS this builds the
## real gate, then measures three things on the shipping map: the heading picker
## found a facing with RiftGate.CLEARANCE of clear floor in front of the opening,
## the approach point lands on the baked navigation mesh, and the opening itself
## is passable — a ray from the approach point through the threshold and out the
## far side hits nothing.
func _verify_rift_gate(map_root: Node) -> void:
	var exhibits_script := load(EXHIBIT_SCRIPT) as Script
	if exhibits_script == null:
		_fail("Rift gate: cannot load %s" % EXHIBIT_SCRIPT)
		return
	var table: Variant = exhibits_script.get_script_constant_map().get("EXHIBITS", null)
	if typeof(table) != TYPE_DICTIONARY:
		_fail("Rift gate: %s exposes no EXHIBITS table" % EXHIBIT_SCRIPT)
		return
	var world: World3D = root.world_3d
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var nav_map: RID = map_root.get_world_3d().navigation_map
	var problems: Array[String] = []
	var built := 0
	var worst_drift := 0.0
	for kind in (table as Dictionary).keys():
		for entry in (table as Dictionary)[kind]:
			var origin: Vector3 = (entry as Dictionary).get("origin", Vector3.ZERO)
			var label := str((entry as Dictionary).get("name", kind))
			# The preferred facing is deliberately arbitrary here: the picker is
			# what has to find a clear one, and a test that hands it the answer
			# would measure nothing.
			var gate: RiftGate = RiftGate.build(map_root as Node3D, str(kind), origin,
				origin + Vector3(0.0, 0.0, 3.0), Color(0.7, 0.8, 1.0))
			await _spin(1)
			built += 1
			var forward: Vector3 = gate.global_transform.basis.z
			var approach: Vector3 = gate.approach_point()

			var front := PhysicsRayQueryParameters3D.create(
				gate.global_position + Vector3(0.0, 1.10, 0.0),
				approach + Vector3(0.0, 1.10, 0.0))
			front.collision_mask = 1
			var front_hit := space.intersect_ray(front)
			if not front_hit.is_empty():
				problems.append("%s has no clear facing — %s blocks the opening at %.2f m"
					% [label, str((front_hit["collider"] as Node).name),
					gate.global_position.distance_to(front_hit["position"] as Vector3)])

			# The ray stops at the far face of the threshold, not beyond it: the
			# transition fires the moment the body enters the gate volume, so what
			# stands behind the doorway is the exhibit's business, not the walk's.
			var through := PhysicsRayQueryParameters3D.create(
				approach + Vector3(0.0, 1.10, 0.0),
				gate.global_position - forward * (RiftGate.DEPTH * 0.5) + Vector3(0.0, 1.10, 0.0))
			through.collision_mask = 1
			var through_hit := space.intersect_ray(through)
			if not through_hit.is_empty():
				problems.append("%s cannot be walked through — %s stands in the threshold"
					% [label, str((through_hit["collider"] as Node).name)])

			var on_mesh := NavigationServer3D.map_get_closest_point(nav_map, approach)
			var drift := Vector2(on_mesh.x - approach.x, on_mesh.z - approach.z).length()
			worst_drift = maxf(worst_drift, drift)
			if drift > GATE_APPROACH_TOLERANCE:
				problems.append("%s stands %.2f m off the navigation mesh" % [label, drift])

			gate.queue_free()
			await _spin(1)

	if problems.is_empty():
		_ok("Rift gate: %d exhibit thresholds, every one with %.2f m of clear floor in front, passable, worst navmesh drift %.2f m"
			% [built, RiftGate.CLEARANCE, worst_drift])
	else:
		_fail("Rift gate: %s" % [", ".join(problems)])


## CROUCHING BEHIND THE OFFICE CREDENZA MUST BREAK CONTACT
##
## This is the observable contract for the whole first stealth slice: on the
## shipping map and the real player capsule, standing is visible, crouching is
## hidden, knowledge expires after six seconds, and a blind grab is shorter.
func _verify_curator_cover(map_root: Node) -> void:
	var player := get_first_node_in_group("player") as CharacterBody3D
	var scaler := get_first_node_in_group("player_scale_controller")
	var curator := map_root.get_node_or_null("The Curator") as CharacterBody3D
	if curator == null:
		curator = map_root.find_child("The Curator", true, false) as CharacterBody3D
	if player == null or scaler == null or curator == null:
		_fail("Curator cover: player/scaler/Curator missing")
		return
	var camera := player.get_node_or_null("Player Camera") as Camera3D
	var collision := player.get_node_or_null("Player Collision") as CollisionShape3D
	var capsule := collision.shape as CapsuleShape3D if collision != null else null
	if camera == null or capsule == null:
		_fail("Curator cover: player camera or capsule missing")
		return

	var player_transform := player.global_transform
	var camera_transform := camera.global_transform
	var curator_transform := curator.global_transform
	var player_processing := player.is_physics_processing()
	var curator_processing := curator.is_physics_processing()
	var prior_controls := bool(player.get("controls_enabled"))
	var prior_active := bool(curator.get("active"))
	var prior_caught := bool(curator.get("_caught"))
	var prior_known := bool(curator.get("_has_last_known"))
	var prior_last_known: Vector3 = curator.get("_last_known")
	var prior_search := float(curator.get("_search_left"))

	player.set("controls_enabled", false)
	player.set_physics_process(false)
	curator.set_physics_process(false)
	player.velocity = Vector3.ZERO
	curator.velocity = Vector3.ZERO
	player.global_position = Vector3(CURATOR_COVER_PLAYER_XZ.x,
		player.global_position.y, CURATOR_COVER_PLAYER_XZ.y)
	curator.global_position = Vector3(CURATOR_COVER_WATCHER_XZ.x,
		curator.global_position.y, CURATOR_COVER_WATCHER_XZ.y)
	curator.look_at(Vector3(player.global_position.x, curator.global_position.y,
		player.global_position.z), Vector3.UP)
	curator.call("_resolve_player")

	# GameplayEnhancements oscillates the player scale while an anomaly is
	# live, and these probes run inside real frames where that driver ticks.
	# Freeze it and pin the scale at 1.0, or the capsule heights read below
	# are whatever the oscillator happened to be doing that frame.
	var enhancements := get_first_node_in_group("gameplay_enhancements")
	var enhancements_processing := false
	if enhancements != null:
		enhancements_processing = enhancements.is_processing()
		enhancements.set_process(false)
	scaler.call("set_target", 1.0)
	scaler.call("_process", 1.0)
	scaler.call("_process", 1.0)

	scaler.call("set_crouch", false)
	scaler.call("_process", 1.0)
	scaler.call("_process", 1.0)
	await _spin(2)
	var stand_h := capsule.height
	var standing_seen := bool(curator.call("_can_see_player"))

	scaler.call("set_crouch", true)
	scaler.call("_process", 1.0)
	scaler.call("_process", 1.0)
	await _spin(2)
	var crouch_h := capsule.height
	var crouched_seen := bool(curator.call("_can_see_player"))

	# Look away so the weeping-angel guard does not freeze the knowledge timer.
	camera.look_at(Vector3(player.global_position.x, camera.global_position.y,
		player.global_position.z - 1.0), Vector3.UP)
	curator.set("active", true)
	curator.set("_caught", false)
	curator.set("_has_last_known", true)
	curator.set("_last_known", curator.global_position)
	curator.set("_search_left", CURATOR_EXPECTED_SEARCH)
	var anchor := curator.global_position
	var forgot_ticks := 0
	while not curator.has_lost_player() and forgot_ticks < CURATOR_SEARCH_MAX_TICKS:
		# Navigation may retain a target from an earlier check. Keep this test at
		# the last-known point: it measures the search hold, not path following.
		curator.global_position = anchor
		curator.velocity = Vector3.ZERO
		curator.call("_physics_process", 1.0 / 60.0)
		forgot_ticks += 1
	var forgot_seconds := float(forgot_ticks) / 60.0

	var constants: Dictionary = (curator.get_script() as GDScript).get_script_constant_map()
	var visible_catch := float(constants.get("CATCH_DISTANCE", -1.0))
	var blind_catch := float(constants.get("CATCH_BLIND_DISTANCE", -1.0))
	var search_hold := float(constants.get("SEARCH_HOLD", -1.0))
	var problems: Array[String] = []
	if not standing_seen or crouched_seen:
		problems.append("visibility standing/crouched=%s/%s" % [standing_seen, crouched_seen])
	if not curator.has_lost_player() \
			or absf(forgot_seconds - CURATOR_EXPECTED_SEARCH) > CURATOR_SEARCH_TOLERANCE \
			or curator.search_ratio() > 0.001:
		problems.append("forgot in %.3f s, lost=%s, ratio=%.3f"
			% [forgot_seconds, curator.has_lost_player(), curator.search_ratio()])
	if absf(search_hold - CURATOR_EXPECTED_SEARCH) > 0.001:
		problems.append("SEARCH_HOLD %.3f" % search_hold)
	if absf(visible_catch - CURATOR_EXPECTED_VISIBLE_CATCH) > 0.001 \
			or absf(blind_catch - CURATOR_EXPECTED_BLIND_CATCH) > 0.001 \
			or blind_catch >= visible_catch:
		problems.append("catch visible/blind=%.3f/%.3f" % [visible_catch, blind_catch])

	# Restore the world for the blackout check that deliberately runs next.
	scaler.call("set_crouch", false)
	scaler.call("_process", 1.0)
	scaler.call("_process", 1.0)
	if enhancements != null:
		enhancements.set_process(enhancements_processing)
	player.global_transform = player_transform
	camera.global_transform = camera_transform
	curator.global_transform = curator_transform
	player.velocity = Vector3.ZERO
	curator.velocity = Vector3.ZERO
	player.set("controls_enabled", prior_controls)
	curator.set("active", prior_active)
	curator.set("_caught", prior_caught)
	curator.set("_has_last_known", prior_known)
	curator.set("_last_known", prior_last_known)
	curator.set("_search_left", prior_search)
	player.set_physics_process(player_processing)
	curator.set_physics_process(curator_processing)

	if problems.is_empty():
		_ok("Curator cover: standing/crouched sees=%s/%s, capsule %.3f/%.3f, "
			% [standing_seen, crouched_seen, stand_h, crouch_h]
			+ "forgot %.3f s, catch %.2f/%.2f m"
			% [forgot_seconds, visible_catch, blind_catch])
	else:
		_fail("Curator cover: %s" % [", ".join(problems)])


## THE NIGHT ROUTE MUST KEEP A THIRD HEIGHT CLASS
##
## Each entry uses an object already furnishing the room. The check measures its
## real collider and then puts the real player and Curator close on opposite
## sides, because a nominal 1.15 m box is not cover if the sightline clears it.
func _verify_route_covers(map_root: Node, generated: Node) -> void:
	var player := get_first_node_in_group("player") as CharacterBody3D
	var scaler := get_first_node_in_group("player_scale_controller")
	var curator := map_root.get_node_or_null("The Curator") as CharacterBody3D
	if curator == null:
		curator = map_root.find_child("The Curator", true, false) as CharacterBody3D
	if player == null or scaler == null or curator == null:
		_fail("Route covers: player/scaler/Curator missing")
		return
	var collision := player.get_node_or_null("Player Collision") as CollisionShape3D
	var capsule := collision.shape as CapsuleShape3D if collision != null else null
	if capsule == null:
		_fail("Route covers: player capsule missing")
		return

	var player_transform := player.global_transform
	var curator_transform := curator.global_transform
	var player_processing := player.is_physics_processing()
	var curator_processing := curator.is_physics_processing()
	var prior_controls := bool(player.get("controls_enabled"))
	var prior_active := bool(curator.get("active"))
	player.set("controls_enabled", false)
	player.set_physics_process(false)
	curator.set_physics_process(false)
	curator.set("active", false)
	player.velocity = Vector3.ZERO
	curator.velocity = Vector3.ZERO
	curator.call("_resolve_player")

	# GameplayEnhancements oscillates the player scale while an anomaly is
	# live, and the cover probes stand next to the exhibits those anomalies
	# radiate from. Freeze the driver and pin the scale at 1.0, or a cover
	# is measured against a capsule the oscillator was mid-swing on.
	var enhancements := get_first_node_in_group("gameplay_enhancements")
	var enhancements_processing := false
	if enhancements != null:
		enhancements_processing = enhancements.is_processing()
		enhancements.set_process(false)
	scaler.call("set_target", 1.0)
	scaler.call("_process", 1.0)
	scaler.call("_process", 1.0)

	var problems: Array[String] = []
	var results: Array[String] = []
	for cover in ROUTE_COVERS:
		var owner_name := str(cover["owner"])
		var owner := generated.find_child(owner_name, true, false) as Node3D
		if owner == null:
			problems.append("%s missing" % owner_name)
			continue
		var bounds := _cover_collider_bounds(owner)
		var player_xz: Vector2 = cover["player"]
		var curator_xz: Vector2 = cover["curator"]
		player.global_position = Vector3(player_xz.x, player.global_position.y,
			player_xz.y)
		curator.global_position = Vector3(curator_xz.x, curator.global_position.y,
			curator_xz.y)
		curator.look_at(Vector3(player.global_position.x, curator.global_position.y,
			player.global_position.z), Vector3.UP)

		scaler.call("set_crouch", false)
		scaler.call("_process", 1.0)
		scaler.call("_process", 1.0)
		await _spin(2)
		var standing_seen := bool(curator.call("_can_see_player"))
		var stand_h := capsule.height
		scaler.call("set_crouch", true)
		scaler.call("_process", 1.0)
		scaler.call("_process", 1.0)
		await _spin(2)
		var crouched_seen := bool(curator.call("_can_see_player"))
		var crouch_h := capsule.height

		if bounds.x < ROUTE_COVER_MIN_HEIGHT \
				or bounds.x > ROUTE_COVER_MAX_HEIGHT:
			problems.append("%s height %.3f" % [cover["label"], bounds.x])
		if maxf(bounds.y, bounds.z) < ROUTE_COVER_MIN_SPAN:
			problems.append("%s span %.3f/%.3f"
				% [cover["label"], bounds.y, bounds.z])
		if not standing_seen or crouched_seen:
			problems.append("%s sees %s/%s"
				% [cover["label"], standing_seen, crouched_seen])
		results.append("%s %.3f m sees=%s/%s"
			% [cover["label"], bounds.x, standing_seen, crouched_seen])
		if absf(stand_h - 1.8) > 0.02 or absf(crouch_h - 1.044) > 0.02:
			problems.append("%s capsule %.3f/%.3f"
				% [cover["label"], stand_h, crouch_h])

	scaler.call("set_crouch", false)
	scaler.call("_process", 1.0)
	scaler.call("_process", 1.0)
	if enhancements != null:
		enhancements.set_process(enhancements_processing)
	player.global_transform = player_transform
	curator.global_transform = curator_transform
	player.velocity = Vector3.ZERO
	curator.velocity = Vector3.ZERO
	player.set("controls_enabled", prior_controls)
	curator.set("active", prior_active)
	player.set_physics_process(player_processing)
	curator.set_physics_process(curator_processing)

	if problems.is_empty():
		_ok("Route covers: %s" % [", ".join(results)])
	else:
		_fail("Route covers: %s" % [", ".join(problems)])


## The Curator hears rather than only sees: gait loudness falls off with range,
## and a thrown device has to pull it away from the player it cannot see.
## Distances below are one side of a threshold the model computes, so a change
## to HEARING_THRESHOLD or NOISE_RANGE fails here instead of silently retuning
## every stealth room.
func _verify_noise_model(map_root: Node) -> void:
	var player := get_first_node_in_group("player") as CharacterBody3D
	var curator := map_root.get_node_or_null("The Curator") as CharacterBody3D
	if curator == null:
		curator = map_root.find_child("The Curator", true, false) as CharacterBody3D
	if player == null or curator == null:
		_fail("Curator hearing: player/Curator missing")
		return

	var player_transform := player.global_transform
	var curator_transform := curator.global_transform
	var player_processing := player.is_physics_processing()
	var prior_controls := bool(player.get("controls_enabled"))
	var prior_active := bool(curator.get("active"))
	var prior_night: int = curator.get("night")
	var prior_paused := paused
	player.set("controls_enabled", false)
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	# Far past SIGHT_RANGE, so nothing below can be explained by sight.
	player.global_position = Vector3(28.0, player.global_position.y, -4.5)
	curator.call("reset_at", Vector3(-25.0, 0.0, -12.0))
	curator.set("night", 2)
	paused = false
	curator.visible = true
	curator.set("active", true)
	await _spin(1)

	var problems: Array[String] = []
	var home := curator.global_position
	if bool(curator.call("_can_see_player")):
		problems.append("player visible from spawn")

	# label, loudness, distance, expected
	var cases := [
		["run 15 m", 1.0, 15.0, true], ["run 16 m", 1.0, 16.0, false],
		["walk 8 m", 0.55, 8.0, true], ["walk 9 m", 0.55, 9.0, false],
		["crouch 0.5 m", 0.22, 0.5, false], ["crouch 4 m", 0.22, 4.0, false],
		["throw 18 m", 1.6, 18.0, true], ["throw 20 m", 1.6, 20.0, false],
	]
	for entry: Array in cases:
		var label := str(entry[0])
		var loudness: float = entry[1]
		var distance: float = entry[2]
		var expected: bool = entry[3]
		curator.call("hear_noise", home + Vector3(distance, 0.0, 0.0), loudness)
		var heard := bool(curator.call("_consume_noise"))
		if heard != expected:
			problems.append("%s heard=%s" % [label, heard])

	if absf(float(curator.call("_footstep_loudness"))) > 0.001:
		problems.append("standing player is audible")

	# The decoy: a device landing 8 m away must own the Curator's attention even
	# though the player is 45 m in the other direction.
	var decoy := home + Vector3(8.0, 0.0, 0.0)
	paused = false
	curator.set("active", true)
	curator.call("hear_noise", decoy, 1.6)
	await _spin(1)
	var known: Vector3 = curator.get("_last_known")
	var decoy_error := known.distance_to(decoy)
	if decoy_error > 0.05:
		problems.append("decoy target off by %.2f m" % decoy_error)

	var before := curator.global_position.distance_to(decoy)
	for _i in range(180):
		paused = false
		curator.set("active", true)
		await physics_frame
	var closed := before - curator.global_position.distance_to(decoy)
	if closed < CURATOR_DECOY_MIN_CLOSED:
		problems.append("decoy approach closed only %.2f m" % closed)

	# And it has to give up, or one thrown device would pin it forever.
	var forget := 0
	while forget < CURATOR_SEARCH_MAX_TICKS and bool(curator.get("_has_last_known")):
		paused = false
		curator.set("active", true)
		await physics_frame
		forget += 1
	if bool(curator.get("_has_last_known")):
		problems.append("never forgot the decoy")

	paused = prior_paused
	player.global_transform = player_transform
	curator.global_transform = curator_transform
	player.velocity = Vector3.ZERO
	curator.velocity = Vector3.ZERO
	player.set("controls_enabled", prior_controls)
	player.set_physics_process(player_processing)
	curator.set("night", prior_night)
	curator.set("active", prior_active)
	curator.call("reset_at", curator_transform.origin)

	if problems.is_empty():
		_ok("Curator hearing: thresholds hold, decoy closed %.2f m, forgot in %.2f s"
			% [closed, float(forget) / 60.0])
	else:
		_fail("Curator hearing: %s" % [", ".join(problems)])


## Curator states. Each case drives the machine into one named state and then
## checks the behaviour that state promises: a name that does not change what
## the Curator does is worth nothing to the player watching from a cupboard.
const CURATOR_STATE_PATROL_TICKS := 420
const CURATOR_STATE_PATROL_MIN_TRAVEL := 0.5
## How close a navigation path has to end to its waypoint before the leg counts
## as connected. Bigger than the mesh cell 0.15 and smaller than PATROL_ARRIVED.
const CURATOR_STATE_LEG_TOLERANCE := 0.6
## Half a second of lantern. Short on purpose: at RETREAT_SPEED a full second
## would carry the Curator past RETREAT_RANGE, and the state would drop on the
## very tick the check reads it.
const CURATOR_STATE_RETREAT_TICKS := 30
const CURATOR_STATE_RETREAT_MIN_GAIN := 0.5
## Same pair the Gravity route cover uses, where a standing player is provably
## visible: borrowing a measured sightline beats inventing a new one.
const CURATOR_STATE_SEEN_PLAYER_XZ := Vector2(28.0, -2.65)
const CURATOR_STATE_SEEN_CURATOR_XZ := Vector2(28.0, -8.0)
const CURATOR_STATE_LANTERN_CURATOR_XZ := Vector2(28.0, -6.0)


func _verify_curator_states(map_root: Node) -> void:
	var player := get_first_node_in_group("player") as CharacterBody3D
	var curator := map_root.get_node_or_null("The Curator") as CharacterBody3D
	if curator == null:
		curator = map_root.find_child("The Curator", true, false) as CharacterBody3D
	if player == null or curator == null:
		_fail("Curator states: player/Curator missing")
		return

	var player_transform := player.global_transform
	var curator_transform := curator.global_transform
	var player_processing := player.is_physics_processing()
	var prior_controls := bool(player.get("controls_enabled"))
	var prior_active := bool(curator.get("active"))
	var prior_night: int = curator.get("night")
	var prior_slowed := bool(curator.get("slowed"))
	var prior_paused := paused
	player.set("controls_enabled", false)
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	# Far past SIGHT_RANGE for the knowledge cases below.
	player.global_position = Vector3(28.0, player.global_position.y, -4.5)
	curator.call("reset_at", Vector3(-25.0, 0.0, -12.0))
	curator.set("night", 2)
	curator.set("slowed", false)
	paused = false
	curator.visible = true
	curator.set("active", true)
	await _spin(1)

	var problems: Array[String] = []

	# Knows nothing: walks its round. Standing still here is the bug this state
	# machine exists to kill.
	var patrol_state := str(curator.call("state_name"))
	if patrol_state != "PATROL":
		problems.append("no knowledge -> %s" % patrol_state)
	var patrol_from := curator.global_position
	for _i in range(CURATOR_STATE_PATROL_TICKS):
		paused = false
		curator.set("active", true)
		await physics_frame
	var patrol_travel := patrol_from.distance_to(curator.global_position)
	if patrol_travel < CURATOR_STATE_PATROL_MIN_TRAVEL:
		problems.append("patrol stood still (%.2f m)" % patrol_travel)

	# Walking for seven seconds only proves the first leg. Every leg of the round
	# has to be a real path on the baked mesh: waypoints written from the map
	# layout can land on an island the Curator enters and never leaves, and the
	# state machine would keep reporting PATROL while standing in a corner.
	var nav_agent := curator.get("_agent") as NavigationAgent3D
	var round_points: Array = curator.get_script().get_script_constant_map()["PATROL_POINTS"]
	var round_length := 0.0
	if nav_agent == null:
		problems.append("Curator has no navigation agent")
	else:
		var nav_map: RID = nav_agent.get_navigation_map()
		for i in range(round_points.size()):
			var next_i: int = (i + 1) % round_points.size()
			var leg_from: Vector3 = curator.call("_navigable", round_points[i])
			var leg_to: Vector3 = curator.call("_navigable", round_points[next_i])
			var leg: PackedVector3Array = NavigationServer3D.map_get_path(
				nav_map, leg_from, leg_to, true)
			if leg.size() == 0:
				problems.append("leg %d->%d has no path" % [i, next_i])
				continue
			for n in range(1, leg.size()):
				round_length += leg[n - 1].distance_to(leg[n])
			var short_by: float = leg[leg.size() - 1].distance_to(leg_to)
			if short_by > CURATOR_STATE_LEG_TOLERANCE:
				problems.append("leg %d->%d stops %.2f m short" % [i, next_i, short_by])

	# A fresh noise is an errand.
	paused = false
	curator.set("active", true)
	curator.call("hear_noise", curator.global_position + Vector3(8.0, 0.0, 0.0), 1.6)
	# Exactly one physics tick, not _spin(): the noise is consumed on the tick it
	# arrives, so a second tick would already read as the stale SEARCH below.
	await physics_frame
	var heard_state := str(curator.call("state_name"))
	if heard_state != "INVESTIGATE":
		problems.append("fresh noise -> %s" % heard_state)

	# One tick later the noise is stale but the place is still believed in.
	paused = false
	curator.set("active", true)
	await physics_frame
	var search_state := str(curator.call("state_name"))
	if search_state != "SEARCH":
		problems.append("stale noise -> %s" % search_state)

	# Seen and close. The player faces away on purpose: an observed Curator is
	# frozen by the weeping-angel rule and would never reach COMMIT.
	var seen_player := Vector3(CURATOR_STATE_SEEN_PLAYER_XZ.x,
		player.global_position.y, CURATOR_STATE_SEEN_PLAYER_XZ.y)
	player.global_position = seen_player
	player.global_rotation = Vector3(0.0, PI, 0.0)
	var commit_spot := Vector3(CURATOR_STATE_SEEN_CURATOR_XZ.x, 0.0,
		CURATOR_STATE_SEEN_CURATOR_XZ.y)
	curator.call("reset_at", commit_spot)
	curator.look_at(Vector3(seen_player.x, curator.global_position.y,
		seen_player.z), Vector3.UP)
	paused = false
	curator.set("active", true)
	await _spin(2)
	var commit_range := curator.global_position.distance_to(player.global_position)
	var commit_state := str(curator.call("state_name"))
	if not bool(curator.call("_can_see_player")):
		problems.append("commit case lost its sightline")
	elif commit_state != "COMMIT":
		problems.append("seen at %.2f m -> %s" % [commit_range, commit_state])

	# Null lantern held close: it has to give ground, not just slow down.
	curator.call("reset_at", Vector3(CURATOR_STATE_LANTERN_CURATOR_XZ.x, 0.0,
		CURATOR_STATE_LANTERN_CURATOR_XZ.y))
	# Re-armed every tick: the lantern is a held tool, and whatever owns it in a
	# real night keeps writing this flag too.
	curator.set("slowed", true)
	paused = false
	curator.set("active", true)
	var retreat_from := curator.global_position.distance_to(player.global_position)
	# The state is read on the LAST tick, not the first: a flag written between
	# frames can still be cleared by whoever owns the lantern before the Curator
	# processes, so only a tick that ran with the flag in force proves anything.
	var retreat_state := ""
	for _i in range(CURATOR_STATE_RETREAT_TICKS):
		paused = false
		curator.set("active", true)
		curator.set("slowed", true)
		await physics_frame
		retreat_state = str(curator.call("state_name"))
	var retreat_gain := curator.global_position.distance_to(player.global_position) \
		- retreat_from
	if retreat_state != "RETREAT":
		problems.append("lantern at %.2f m -> %s" % [retreat_from, retreat_state])
	if retreat_gain < CURATOR_STATE_RETREAT_MIN_GAIN:
		problems.append("lantern gained only %.2f m" % retreat_gain)

	paused = prior_paused
	player.global_transform = player_transform
	curator.global_transform = curator_transform
	player.velocity = Vector3.ZERO
	curator.velocity = Vector3.ZERO
	player.set("controls_enabled", prior_controls)
	player.set_physics_process(player_processing)
	curator.set("night", prior_night)
	curator.set("slowed", prior_slowed)
	curator.set("active", prior_active)
	curator.call("reset_at", curator_transform.origin)

	if problems.is_empty():
		_ok("Curator states: patrol walked %.2f m of a %.2f m round, noise -> INVESTIGATE -> SEARCH, seen at %.2f m -> COMMIT, lantern pushed it back %.2f m"
			% [patrol_travel, round_length, commit_range, retreat_gain])
	else:
		_fail("Curator states: %s" % [", ".join(problems)])


## Returns top Y, widest X and widest Z across an object's real box colliders.
func _cover_collider_bounds(owner: Node) -> Vector3:
	var top := 0.0
	var width := 0.0
	var depth := 0.0
	for node in owner.find_children("*", "CollisionShape3D", true, false):
		var shape_node := node as CollisionShape3D
		if shape_node == null or not (shape_node.shape is BoxShape3D):
			continue
		var size := (shape_node.shape as BoxShape3D).size
		top = maxf(top, shape_node.global_position.y + size.y * 0.5)
		width = maxf(width, size.x)
		depth = maxf(depth, size.z)
	return Vector3(top, width, depth)


## Advances both steps, which a held input needs to be seen and acted upon.
func _spin(frames: int) -> void:
	for _i in range(frames):
		await physics_frame
		await process_frame


func _ok(text: String) -> void:
	print("✓ ", text)


func _fail(text: String) -> void:
	_failed = true
	print("❌ ", text)


func _quit(code := 0) -> void:
	quit(code)
