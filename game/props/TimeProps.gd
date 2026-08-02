@tool
class_name TimeProps
extends RefCounted
## Procedural prop set for Time Wing B of the First Museum.
##
## THE IDEA IS DISAGREEMENT. Nothing in this wing agrees about what time it is,
## and every prop carries the contradiction in its silhouette rather than in a
## texture: a clock with two hour hands at different hours, a splash crown that
## already happened under a drop that has not landed, a pendulum whose shadow
## lies under vertical while the bob hangs to one side, a sand pile far too
## large for the funnel above it with a broken column of sand in between.
## The player should feel the wrongness from the doorway, before reading a
## single label.
##
## USAGE. Everything is static; nothing here holds state between calls beyond a
## shared material cache. Each builder takes (parent, origin, ...) where `origin`
## is in the PARENT's local space at FLOOR level, and returns the root Node3D it
## added, so a caller places a prop in one line:
##
##     TimeProps.broken_clock(gallery, Vector3(-8, 0, -27.5))
##     TimeProps.dress_time_wing(map_root, Vector3(0, 0, -24), Vector2(26, 18))
##
## The three exhibit builders (broken_clock, frozen_drop, time_loop) build the
## exhibit CONTENT only. The pedestal (2.8 x 0.7 x 2.8, top at y 0.70), the glass
## case (2.25 x 2.10 x 2.25, y 0.35 .. 2.45) and the plaque belong to the caller;
## all three props are sized to sit on that pedestal top and clear that glass.
##
## SCALE. Rooms are 3.4 m tall. Every function documents its measured bounding
## box. No exhibit is wider than 1.52 m, the tallest free-standing prop is the
## pendulum frame at 2.57 m, and the only thing that reaches 3.4 m is the sand
## column, which is hung from the ceiling slab and stops exactly at it.
##
## COLLISION. Only geometry the player can genuinely walk into gets a body: the
## clock drum, the drop, the pendulum posts and bob, the sand pile. Rings never
## get one -- a box shape would fill the hole the ring is made of. Everything
## floating above head height is explicitly collision-free -- a collider hanging
## at 2 m carves a hole in the navmesh underneath it (the bake filters spans
## with less than agent_height 2.2 m of clearance) and would strand the Curator.
## Nothing here is ever placed in a doorway: DOOR_GAP is 1.8 m and the bake
## erodes 0.45 m per side.
##
## ACCESSIBILITY. Every prop is static geometry -- there is no animation, no
## flicker and no pulse anywhere in this file, so there is nothing for
## SettingsManager.reduced_flashes to switch off. Emission is constant. Meaning
## is carried by shape and position (hand angles, a missing hand, a displaced
## shadow), never by colour alone, and the pale clock faces sit on a near-black
## backboard so they stay legible for low-vision players in a dark room.
##
## PERFORMANCE. The map already builds ~1270 meshes in one frame. Materials are
## shared through a static cache and every round mesh is cut down to PS1 segment
## counts (spheres 16x8, cylinders 16, tori 24x8 instead of Godot's 64x32
## defaults), so a fully dressed wing costs roughly 150 low-poly meshes.


# Mirrors FirstMuseumMap's geometry constants. Duplicated deliberately: this
# file must not depend on the map script, which is rebuilt by other hands.
const WALL_HEIGHT := 3.4
const WALL_THICKNESS := 0.35

# Wing B palette: warm amber brass, bone-pale dials, cold water for the drop.
const MatLib := preload("res://game/props/MaterialLib.gd")

const BRASS := Color(0.30, 0.25, 0.13)
const BRASS_LIT := Color(0.46, 0.38, 0.20)
const IRON := Color(0.10, 0.11, 0.12)
const CASE_DARK := Color(0.13, 0.12, 0.11)
const DIAL_PALE := Color(0.74, 0.71, 0.62)
const DIAL_DEAD := Color(0.28, 0.27, 0.24)
const HAND_BLACK := Color(0.05, 0.05, 0.05)
const WATER := Color(0.22, 0.45, 0.58)
const WATER_DIM := Color(0.13, 0.26, 0.33)
const SAND := Color(0.72, 0.62, 0.40)
const SAND_DIM := Color(0.56, 0.48, 0.32)
const SHADOW := Color(0.02, 0.02, 0.025)

static var _materials: Dictionary = {}
static var _noise_texture: NoiseTexture2D = null
static var _bump_texture: NoiseTexture2D = null


# --- Exhibit 1: the broken clock -------------------------------------------
#
# Bounding box 1.48 W x 1.57 H x 0.98 D, occupying y 0.70 .. 2.28 above `origin`.
# Sits on the 0.7 m pedestal and clears the 2.25 x 2.10 x 2.25 glass case with
# 0.17 m of headroom.
#
# The case hangs askew on all three axes so the numeral 12 is not where it
# should be, the dial is cracked, three numerals have fallen off, and it carries
# TWO hour hands pointing at different hours -- the object cannot even agree
# with itself. A third hand lies on the pedestal where it dropped.
static func broken_clock(parent: Node3D, origin: Vector3,
		node_name := "Broken Clock") -> Node3D:
	var root := _root(parent, node_name, origin)

	# Everything rigid rides on a tilted holder; the debris below does not.
	var case_node := Node3D.new()
	case_node.name = "Case"
	case_node.position = Vector3(0, 1.52, 0)
	case_node.rotation_degrees = Vector3(-7, 9, -14)
	root.add_child(case_node)

	# The one collider: the drum the whole exhibit hangs off.
	_disc(case_node, "Clock Drum", Vector3(0, 0, -0.06), 0.50, 0.20,
		CASE_DARK, 0.0, 0.15, true)
	_torus(case_node, "Clock Bezel", Vector3(0, 0, 0.03), 0.52, 0.62,
		BRASS, 0.0, 0.45, true)
	_disc(case_node, "Clock Dial", Vector3(0, 0, 0.055), 0.51, 0.03,
		DIAL_PALE, 0.10, 0.0, false)

	# Twelve numerals, three of them missing.
	var shed := [2, 7, 11]
	for i in range(12):
		if shed.has(i):
			continue
		var a := deg_to_rad(float(i) * 30.0)
		var mark := _box(case_node, "Numeral %d" % i,
			Vector3(sin(a) * 0.41, cos(a) * 0.41, 0.075),
			Vector3(0.05, 0.075, 0.02), HAND_BLACK, 0.0, 0.0, false)
		mark.rotation_degrees = Vector3(0, 0, -float(i) * 30.0)

	# Cracks radiating from the hub. Thin, unlit, no bodies.
	var crack_angles := [22.0, 96.0, 158.0, 251.0]
	for i in range(crack_angles.size()):
		var ca: float = crack_angles[i]
		var dir := Vector3(sin(deg_to_rad(ca)), cos(deg_to_rad(ca)), 0.0)
		var crack := _box(case_node, "Dial Crack %d" % i,
			dir * 0.24 + Vector3(0, 0, 0.072),
			Vector3(0.012, 0.48, 0.006), Color(0.03, 0.03, 0.03), 0.0, 0.0, false)
		crack.rotation_degrees = Vector3(0, 0, -ca)

	# Two hour hands at 3:00 and 7:44, one minute hand at :48. No arrangement
	# of a working clock can produce this.
	_hand(case_node, "Hour Hand A", Vector3(0, 0, 0.085), 0.28, 0.045, 0.014,
		_hour_angle(3, 0), HAND_BLACK)
	_hand(case_node, "Hour Hand B", Vector3(0, 0, 0.098), 0.28, 0.045, 0.014,
		_hour_angle(7, 44), HAND_BLACK)
	_hand(case_node, "Minute Hand", Vector3(0, 0, 0.111), 0.44, 0.028, 0.012,
		_minute_angle(48), HAND_BLACK)
	_sphere(case_node, "Hand Hub", Vector3(0, 0, 0.10), 0.05, BRASS_LIT, 0.0, 0.5)

	# Debris on the pedestal top (y 0.70): a snapped-off hand and two numerals.
	var fallen := _box(root, "Fallen Hand", Vector3(0.40, 0.716, 0.34),
		Vector3(0.42, 0.012, 0.03), HAND_BLACK, 0.0, 0.35, false)
	fallen.rotation_degrees = Vector3(0, 26, 0)
	_box(root, "Fallen Numeral A", Vector3(-0.33, 0.712, 0.46),
		Vector3(0.05, 0.02, 0.075), HAND_BLACK, 0.0, 0.0, false)
	var num_b := _box(root, "Fallen Numeral B", Vector3(0.18, 0.712, -0.44),
		Vector3(0.05, 0.02, 0.075), HAND_BLACK, 0.0, 0.0, false)
	num_b.rotation_degrees = Vector3(0, 48, 0)
	return root


# --- Exhibit 2: the frozen drop --------------------------------------------
#
# Bounding box 1.52 W x 1.72 H x 1.52 D, occupying y 0.68 .. 2.40 above `origin`.
# The two ripple rings deliberately sink 20 mm into the pedestal top so they
# read as rising out of the stone rather than resting on it.
#
# Rebuild of the map's old "drop" fallback, which had the right idea -- teardrop,
# tail, splash ring -- and the wrong reading: the ring alone looked like a plinth
# decoration. The contradiction is now explicit. The impact ALREADY HAPPENED:
# there is a crown of frozen splash spikes with beads on their tips and two
# spreading ripples on the pedestal. The drop that will cause it is still in the
# air, and the thread trailing behind it has snapped into separate droplets.
static func frozen_drop(parent: Node3D, origin: Vector3,
		node_name := "Frozen Drop") -> Node3D:
	var root := _root(parent, node_name, origin)

	# The splash that has not been caused yet.
	_cylinder(root, "Ripple Sheet", Vector3(0, 0.714, 0), 0.76, 0.012,
		WATER_DIM, 0.10, 0.0, false)
	_torus(root, "Ripple Outer", Vector3(0, 0.722, 0), 0.66, 0.74,
		WATER_DIM, 0.20, 0.0, false)
	_torus(root, "Splash Ring", Vector3(0, 0.745, 0), 0.46, 0.58,
		WATER, 0.30, 0.0, false)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var spike := _prism(root, "Crown Spike %d" % i,
			Vector3(cos(a) * 0.52, 0.87, sin(a) * 0.52),
			Vector3(0.07, 0.26, 0.07), Color(0.26, 0.50, 0.62), 0.30)
		spike.rotation_degrees = Vector3(sin(a) * 17.0, 0.0, cos(a) * -17.0)
		if i % 2 == 0:
			_sphere(root, "Crown Bead %d" % i,
				Vector3(cos(a) * 0.60, 1.02, sin(a) * 0.60), 0.037,
				Color(0.34, 0.58, 0.70), 0.45)

	# The drop itself, elongated by the fall it never finished. The stretch is
	# in the mesh, not in the node scale: scaling the node would drag its
	# collision shape into a non-uniform transform.
	_sphere(root, "Drop Body", Vector3(0, 1.46, 0), 0.36,
		WATER, 0.55, 0.0, true, 1.22)
	_cone(root, "Drop Tail", Vector3(0, 2.02, 0), 0.17, 0.02, 0.50,
		WATER, 0.40)
	# The thread has snapped: two droplets left behind, going nowhere.
	_sphere(root, "Trailing Bead A", Vector3(0.03, 2.33, -0.02), 0.068,
		WATER, 0.50)
	_sphere(root, "Trailing Bead B", Vector3(-0.05, 2.30, 0.04), 0.040,
		WATER, 0.50)
	return root


# --- Exhibit 3: the time loop ----------------------------------------------
#
# Bounding box 1.11 W x 1.40 H x 1.00 D, occupying y 0.71 .. 2.10 above `origin`.
#
# A ring hanging off vertical with a second ring threaded through it at an
# impossible angle, and a single object printed seven times around the loop --
# the same instant, over and over, each copy a little further gone. One copy is
# missing. The gap is where the thing actually is.
static func time_loop(parent: Node3D, origin: Vector3,
		node_name := "Time Loop") -> Node3D:
	var root := _root(parent, node_name, origin)

	# A soft contact shadow on the pedestal, matching the map's floating props.
	_cylinder(root, "Loop Shadow", Vector3(0, 0.716, 0), 0.50, 0.02,
		SHADOW, 0.0, 0.0, false)

	var ring := Node3D.new()
	ring.name = "Loop Plane"
	ring.position = Vector3(0, 1.55, 0)
	ring.rotation_degrees = Vector3(8, 22, 0)
	root.add_child(ring)

	_torus(ring, "Loop Ring", Vector3.ZERO, 0.40, 0.54,
		Color(0.50, 0.35, 0.25), 0.45, 0.0, true)
	var inner := _torus(ring, "Counter Ring", Vector3.ZERO, 0.16, 0.22,
		Color(0.35, 0.28, 0.22), 0.20, 0.0, false)
	# Threaded through the first ring rather than nested inside it.
	inner.rotation_degrees = Vector3(90, 0, 62)

	# Seven copies of one moment; index 4 never arrives.
	for i in range(7):
		if i == 4:
			continue
		var a := deg_to_rad(-28.0 + float(i) * 47.0)
		var fade: float = 1.0 - float(i) / 7.0
		var edge: float = 0.19 if i == 0 else 0.15
		var tint := Color(0.62, 0.50, 0.34).lerp(Color(0.17, 0.13, 0.11),
			1.0 - fade)
		var ghost := _box(ring, "Loop Ghost %d" % i,
			Vector3(sin(a) * 0.47, cos(a) * 0.47, 0.0),
			Vector3(edge, edge, edge), tint, 0.85 * fade, 0.0, false)
		ghost.rotation_degrees = Vector3(14.0 * float(i), 23.0 * float(i),
			-rad_to_deg(a))
	return root


# --- Dressing: a single wall clock -----------------------------------------
#
# Bounding box (2 * radius) W x (2 * radius) H x 0.10 D. At the default radius
# 0.28 that is 0.56 x 0.56 x 0.10.
#
# `origin` is the point on the WALL SURFACE the clock is screwed to; the body
# grows out of the wall along local +Z, so yaw_degrees 0 faces +Z, 90 faces +X,
# 180 faces -Z and -90 faces -X. `roll_degrees` hangs it crooked in its own
# plane. `dead` strips the hands off entirely and darkens the dial -- a clock
# with nothing to say. No collision anywhere: these are flat wall fittings.
static func wall_clock(parent: Node3D, origin: Vector3, radius := 0.28,
		hour := 3, minute := 0, yaw_degrees := 0.0, roll_degrees := 0.0,
		dead := false, node_name := "Wall Clock") -> Node3D:
	var root := _root(parent, node_name, origin)
	# Node3D rotates YXZ, so the roll is applied in the dial plane first and
	# the yaw turns the finished clock to face its wall.
	root.rotation_degrees = Vector3(0, yaw_degrees, roll_degrees)

	_disc(root, "Body", Vector3(0, 0, 0.03), radius * 0.92, 0.06,
		Color(0.09, 0.09, 0.10), 0.0, 0.0, false)
	_torus(root, "Bezel", Vector3(0, 0, 0.055), radius * 0.86, radius,
		BRASS, 0.0, 0.45, true)
	# A faint constant glow keeps pale dials readable in a dark gallery.
	_disc(root, "Dial", Vector3(0, 0, 0.07), radius * 0.86, 0.02,
		DIAL_DEAD if dead else DIAL_PALE, 0.0 if dead else 0.10, 0.0, false)

	if radius >= 0.20:
		for i in range(4):
			var a := deg_to_rad(float(i) * 90.0)
			var tick := _box(root, "Tick %d" % i,
				Vector3(sin(a) * radius * 0.72, cos(a) * radius * 0.72, 0.082),
				Vector3(0.018, radius * 0.16, 0.012),
				Color(0.10, 0.10, 0.09), 0.0, 0.0, false)
			tick.rotation_degrees = Vector3(0, 0, -float(i) * 90.0)

	if not dead:
		_hand(root, "Hour Hand", Vector3(0, 0, 0.086), radius * 0.50,
			0.020, 0.010, _hour_angle(hour, minute), HAND_BLACK)
		_hand(root, "Minute Hand", Vector3(0, 0, 0.096), radius * 0.78,
			0.014, 0.010, _minute_angle(minute), HAND_BLACK)
	return root


# --- Dressing: the wall of clocks ------------------------------------------
#
# Bounding box 1.92 W x 1.92 H x 0.15 D, centred on `origin`. Mount the centre
# at y 1.95 and it spans 0.99 .. 2.91 under the 3.4 m ceiling.
#
# Nine clocks on one near-black board, hung by whoever ran this wing, and no two
# of them agree. Two hang crooked. The middle one -- the one the eye lands on
# first -- has no hands at all.
static func clock_bank(parent: Node3D, origin: Vector3, yaw_degrees := 0.0,
		node_name := "Clock Bank") -> Node3D:
	var root := _root(parent, node_name, origin)
	root.rotation_degrees = Vector3(0, yaw_degrees, 0)
	_box(root, "Backboard", Vector3(0, 0, 0.025), Vector3(1.92, 1.92, 0.05),
		Color(0.06, 0.06, 0.07), 0.0, 0.0, false)

	# hour, minute, roll, dead -- deliberately incoherent.
	var faces := [
		[11, 48, 0.0, false], [3, 7, 0.0, false], [6, 0, -12.0, false],
		[9, 15, 0.0, false], [12, 0, 0.0, true], [2, 41, 5.0, false],
		[7, 33, 0.0, false], [4, 4, 0.0, false], [1, 26, 18.0, false],
	]
	for i in range(faces.size()):
		var f: Array = faces[i]
		var col := i % 3
		var row := int(i / 3.0)
		wall_clock(root,
			Vector3(-0.62 + float(col) * 0.62, 0.62 - float(row) * 0.62, 0.05),
			0.24, int(f[0]), int(f[1]), 0.0, float(f[2]), bool(f[3]),
			"Bank Clock %d" % i)
	return root


# --- Dressing: the stopped pendulum ----------------------------------------
#
# Bounding box 2.54 W x 2.57 H x 0.56 D, standing on the floor at `origin`.
# The bob swings in the local XZ-facing plane, displaced toward local +X.
#
# It hangs 22 degrees off vertical and does not move. The floor shadow is not
# under the bob -- it is under the pivot, where the bob would be if the world
# still worked -- and the graduated arc it swings over is mis-marked, its ticks
# at unequal intervals. Posts and bob are solid; the crossbar overhead is not,
# so it cannot punch a hole in the Curator's navmesh.
static func stopped_pendulum(parent: Node3D, origin: Vector3,
		yaw_degrees := 0.0, node_name := "Stopped Pendulum") -> Node3D:
	var root := _root(parent, node_name, origin)
	root.rotation_degrees = Vector3(0, yaw_degrees, 0)

	# 0.14 and not 0.12: Vector3 stores float32, so a component written as 0.12
	# comes back as 0.11999999 and loses the >= 0.12 collision test by a
	# rounding error. Anything meant to block the player is kept clear of it.
	for s in [-1.0, 1.0]:
		_box(root, "Frame Post %d" % int(s), Vector3(1.10 * s, 1.25, 0),
			Vector3(0.14, 2.50, 0.14), IRON, 0.0, 0.55, true)
		_box(root, "Frame Foot %d" % int(s), Vector3(1.10 * s, 0.03, 0),
			Vector3(0.34, 0.06, 0.34), IRON, 0.0, 0.55, false)
	_box(root, "Frame Crossbar", Vector3(0, 2.50, 0),
		Vector3(2.34, 0.14, 0.14), IRON, 0.0, 0.55, false)
	_disc(root, "Pivot", Vector3(0, 2.44, 0), 0.06, 0.16, BRASS, 0.0, 0.5, false)

	# 22 degrees off vertical, on a 1.88 m rod, going nowhere.
	var tilt := deg_to_rad(22.0)
	var rod_len := 1.88
	var pivot := Vector3(0, 2.44, 0)
	var swing := Vector3(sin(tilt), -cos(tilt), 0.0)
	var rod := _box(root, "Pendulum Rod", pivot + swing * (rod_len * 0.5),
		Vector3(0.05, rod_len, 0.05), Color(0.16, 0.15, 0.14), 0.0, 0.6, false)
	rod.rotation_degrees = Vector3(0, 0, -22.0)
	var bob_at := pivot + swing * rod_len
	_disc(root, "Pendulum Bob", bob_at, 0.27, 0.10, BRASS_LIT, 0.0, 0.6, true)
	_torus(root, "Pendulum Bob Rim", bob_at + Vector3(0, 0, 0.005),
		0.24, 0.29, BRASS, 0.0, 0.5, true)

	# The shadow disagrees with the bob: it sits under the pivot.
	_cylinder(root, "Bob Shadow", Vector3(0, 0.008, 0), 0.28, 0.015,
		SHADOW, 0.0, 0.0, false)
	# A graduated arc whose graduations are not graduated.
	var ticks := [-0.92, -0.51, -0.06, 0.28, 0.86]
	for i in range(ticks.size()):
		_box(root, "Arc Tick %d" % i, Vector3(float(ticks[i]), 0.008, 0),
			Vector3(0.03, 0.012, 0.16), Color(0.45, 0.42, 0.35), 0.10, 0.0, false)
	return root


# --- Dressing: the sand column ---------------------------------------------
#
# Bounding box 2.10 W x 3.40 H x 2.10 D when suspended from a 3.4 m ceiling;
# 2.10 W x 2.70 H x 2.10 D with `ceiling_y` <= 2.8, which drops the cables.
# The only collider is the pile at the bottom (1.16 x 0.58 x 1.16); the funnel,
# its cables and the column carry none.
#
# Sand pours out of a funnel hung from the ceiling, and the column BREAKS: it
# stops dead at 1.21 m with a single grain hanging in the gap below it, and the
# pile it should be feeding is already far larger than the funnel could ever
# have held. The pour is both unfinished and long over.
static func sand_column(parent: Node3D, origin: Vector3, ceiling_y := WALL_HEIGHT,
		node_name := "Sand Column") -> Node3D:
	var root := _root(parent, node_name, origin)

	if ceiling_y > 2.8:
		var cable_len: float = ceiling_y - 2.70
		for i in range(3):
			var a := TAU * float(i) / 3.0
			_cylinder(root, "Funnel Cable %d" % i,
				Vector3(cos(a) * 0.38, 2.70 + cable_len * 0.5, sin(a) * 0.38),
				0.012, cable_len, Color(0.08, 0.08, 0.09), 0.0, 0.0, false)

	# Suspended hardware: never collidable. A body up here would carve the
	# navmesh out from under it.
	_cone(root, "Funnel", Vector3(0, 2.34, 0), 0.05, 0.42, 0.72,
		Color(0.32, 0.28, 0.22))
	_cone(root, "Funnel Charge", Vector3(0, 2.42, 0), 0.04, 0.36, 0.50,
		SAND, 0.18)
	_cylinder(root, "Sand Column", Vector3(0, 1.60, 0), 0.035, 0.78,
		Color(0.78, 0.68, 0.45), 0.35, 0.0, false)
	# One grain left in the gap the column should be filling.
	_box(root, "Suspended Grain", Vector3(0.012, 0.95, -0.008),
		Vector3(0.05, 0.05, 0.05), Color(0.82, 0.72, 0.48), 0.50, 0.0, false)

	# The pile, and far too much of it.
	_cylinder(root, "Sand Spread Outer", Vector3(0, 0.006, 0), 1.05, 0.012,
		Color(0.48, 0.42, 0.29), 0.0, 0.0, false)
	_cylinder(root, "Sand Spread Inner", Vector3(0, 0.014, 0), 0.86, 0.015,
		SAND_DIM, 0.0, 0.0, false)
	_cone(root, "Sand Pile", Vector3(0, 0.29, 0), 0.58, 0.03, 0.58,
		Color(0.62, 0.54, 0.36), 0.0, true)
	return root


# --- One-line dressing for the whole wing ----------------------------------
#
# Places the four dressing props plus two fallen dials inside a room of
# `room_size` centred on `room_center` (Time Wing B is 26 x 18 at (0, 0, -24)).
# Returns the holder node; everything below it is in room-local coordinates.
#
# Clearances, all measured against the wing's three doorways at world
# (0, -15), (0, -33) and (13, -24): nothing collidable comes within 3 m of a
# door, the wall fittings carry no collision at all, and the two floor props
# (pendulum at world (-9.5, -20.5), sand column at world (9.0, -20.5)) sit in
# open floor away from the exhibit row at z -27.5 and the hourglass at (0, -20).
static func dress_time_wing(parent: Node3D, room_center: Vector3,
		room_size := Vector2(26, 18), node_name := "Time Wing Dressing") -> Node3D:
	var root := _root(parent, node_name, room_center)
	var half_x: float = room_size.x * 0.5 - WALL_THICKNESS * 0.5
	var half_z: float = room_size.y * 0.5 - WALL_THICKNESS * 0.5

	# West wall, facing east into the room: nine clocks, nine opinions.
	clock_bank(root, Vector3(-half_x, 1.95, 0), 90.0)
	# South wall beside the atrium door, north wall, east wall by Wing C.
	wall_clock(root, Vector3(4.2, 2.35, half_z), 0.40, 12, 57, 180.0, 0.0,
		false, "Gallery Clock South")
	wall_clock(root, Vector3(-5.0, 2.15, -half_z), 0.32, 6, 0, 0.0, 0.0,
		true, "Gallery Clock North")
	wall_clock(root, Vector3(half_x, 2.20, 4.6), 0.30, 8, 12, -90.0, -9.0,
		false, "Gallery Clock East")

	stopped_pendulum(root, Vector3(-9.5, 0, 3.5))
	sand_column(root, Vector3(9.0, 0, 3.5), WALL_HEIGHT)

	# Two dials that came off the wall, face-up on the floor.
	var fallen_a := wall_clock(root, Vector3(-11.0, 0.03, -5.5), 0.26,
		10, 9, 0.0, 0.0, false, "Fallen Dial A")
	fallen_a.rotation_degrees = Vector3(-90, 34, 0)
	var fallen_b := wall_clock(root, Vector3(-10.2, 0.02, -6.2), 0.22,
		5, 52, 0.0, 0.0, true, "Fallen Dial B")
	fallen_b.rotation_degrees = Vector3(-90, -18, 0)
	return root


# --- Internals --------------------------------------------------------------

static func _root(parent: Node3D, node_name: String, origin: Vector3) -> Node3D:
	var root := Node3D.new()
	# A repeated sibling name makes Godot rename the second prop to @Node3D@NNN.
	if parent.has_node(NodePath(node_name)):
		node_name = "%s %s" % [node_name, origin]
	root.name = node_name
	root.position = origin
	parent.add_child(root)
	return root


## Clockwise angle in degrees from 12 o'clock for the hour hand.
static func _hour_angle(hour: int, minute: int) -> float:
	return (float(hour % 12) + float(minute) / 60.0) * 30.0


## Clockwise angle in degrees from 12 o'clock for the minute hand.
static func _minute_angle(minute: int) -> float:
	return float(minute % 60) * 6.0


## A clock hand of `length`, pointing `clock_degrees` clockwise from straight up
## in the local XY plane, with its tail pinned at `centre`.
static func _hand(parent: Node3D, node_name: String, centre: Vector3,
		length: float, width: float, depth: float, clock_degrees: float,
		color: Color) -> MeshInstance3D:
	var theta := deg_to_rad(clock_degrees)
	var offset := Vector3(sin(theta), cos(theta), 0.0) * (length * 0.5)
	var inst := _box(parent, node_name, centre + offset,
		Vector3(width, length, depth), color, 0.0, 0.35, false)
	inst.rotation_degrees = Vector3(0, 0, -clock_degrees)
	return inst


static func _box(parent: Node3D, node_name: String, box_position: Vector3,
		size: Vector3, color: Color, emission_energy := 0.0, metallic := 0.0,
		with_collision := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _prim(parent, node_name, box_position, mesh, size, color,
		emission_energy, metallic, with_collision)


static func _cylinder(parent: Node3D, node_name: String, cyl_position: Vector3,
		radius: float, height: float, color: Color, emission_energy := 0.0,
		metallic := 0.0, with_collision := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = radius
	mesh.top_radius = radius
	mesh.radial_segments = 16
	mesh.rings = 0
	return _prim(parent, node_name, cyl_position, mesh,
		Vector3(radius * 2.0, height, radius * 2.0), color,
		emission_energy, metallic, with_collision)


## A cylinder stood on end so it reads as a disc facing local +Z: dials, bobs
## and clock bodies all want this rather than the default upright barrel.
static func _disc(parent: Node3D, node_name: String, disc_position: Vector3,
		radius: float, thickness: float, color: Color, emission_energy := 0.0,
		metallic := 0.0, with_collision := false) -> MeshInstance3D:
	var inst := _cylinder(parent, node_name, disc_position, radius, thickness,
		color, emission_energy, metallic, with_collision)
	inst.rotate_x(deg_to_rad(90))
	return inst


static func _cone(parent: Node3D, node_name: String, cone_position: Vector3,
		bottom_radius: float, top_radius: float, height: float, color: Color,
		emission_energy := 0.0, with_collision := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.radial_segments = 16
	mesh.rings = 0
	var max_radius: float = maxf(bottom_radius, top_radius)
	return _prim(parent, node_name, cone_position, mesh,
		Vector3(max_radius * 2.0, height, max_radius * 2.0), color,
		emission_energy, 0.0, with_collision)


## `height_scale` above 1.0 stretches the sphere into a prolate droplet through
## SphereMesh.height, which keeps the node transform uniform.
static func _sphere(parent: Node3D, node_name: String, sphere_position: Vector3,
		radius: float, color: Color, emission_energy := 0.0, metallic := 0.0,
		with_collision := false, height_scale := 1.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0 * height_scale
	mesh.radial_segments = 16
	mesh.rings = 8
	return _prim(parent, node_name, sphere_position, mesh,
		Vector3(radius * 2.0, radius * 2.0 * height_scale, radius * 2.0), color,
		emission_energy, metallic, with_collision)


static func _prism(parent: Node3D, node_name: String, prism_position: Vector3,
		size: Vector3, color: Color, emission_energy := 0.0) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _prim(parent, node_name, prism_position, mesh, size, color,
		emission_energy, 0.0, false)


## `upright` stands the ring in the local XY plane so it faces +Z, matching the
## dials; leave it false for rings that lie flat on a floor or pedestal.
static func _torus(parent: Node3D, node_name: String, torus_position: Vector3,
		inner_radius: float, outer_radius: float, color: Color,
		emission_energy := 0.0, metallic := 0.0, upright := false) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 24
	mesh.ring_segments = 8
	var inst := _prim(parent, node_name, torus_position, mesh,
		Vector3(outer_radius * 2.0, outer_radius - inner_radius,
			outer_radius * 2.0), color, emission_energy, metallic, false)
	if upright:
		inst.rotate_x(deg_to_rad(90))
	return inst


static func _prim(parent: Node3D, node_name: String, prim_position: Vector3,
		mesh: PrimitiveMesh, size: Vector3, color: Color,
		emission_energy: float, metallic: float,
		with_collision: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = prim_position
	instance.mesh = mesh
	instance.material_override = _material(color, emission_energy, metallic)
	# Same culling budget the rest of the museum uses.
	instance.visibility_range_end = 115.0
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if size.length() < 0.65:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

	# Same threshold as FirstMuseumMap._primitive: hands, ticks, ropes and trim
	# never get a body, and callers opt in explicitly for the rest.
	var collision_worthy := size.x >= 0.12 and size.y >= 0.08 and size.z >= 0.12
	if with_collision and collision_worthy:
		var static_body := StaticBody3D.new()
		static_body.name = "%s Collision" % node_name
		instance.add_child(static_body)
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.name = "%s CollisionShape" % node_name
		collision.shape = shape
		static_body.add_child(collision)
	return instance


## Shared with every other prop built by this class for the lifetime of the
## process; the museum builds ~1270 meshes in one frame and cannot afford a
## StandardMaterial3D per node.
## Палитра крыла времени -> набор карт. Циферблаты, вода и песок — ровный цвет.
static func _pack_for(color: Color) -> String:
	if color.is_equal_approx(BRASS) or color.is_equal_approx(BRASS_LIT):
		return "painted_metal"
	if color.is_equal_approx(IRON):
		return "steel"
	if color.is_equal_approx(CASE_DARK):
		return "wood"
	return ""


static func _material(color: Color, emission_energy: float,
		metallic: float) -> StandardMaterial3D:
	var key := "%s:%s:%s" % [color.to_html(true), emission_energy, metallic]
	if _materials.has(key):
		return _materials[key]

	if emission_energy <= 0.0:
		var pack := _pack_for(color)
		if not pack.is_empty():
			var photo := MatLib.get_material(pack, color)
			_materials[key] = photo
			return photo

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = clampf(0.5 - metallic * 0.35, 0.12, 1.0)
	mat.metallic = metallic
	mat.metallic_specular = 0.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_energy

	# Matte, non-emissive surfaces pick up the museum's restrained grain so
	# these props sit in the same material family as the walls around them.
	if metallic < 0.35 and emission_energy <= 0.0:
		mat.roughness_texture = _grain_texture()
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.normal_enabled = true
		mat.normal_texture = _bump_map()
		mat.normal_scale = 0.08
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.22, 0.22, 0.22)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_materials[key] = mat
	return mat


static func _grain_texture() -> NoiseTexture2D:
	if _noise_texture != null:
		return _noise_texture
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.16
	noise.fractal_octaves = 2
	_noise_texture = NoiseTexture2D.new()
	_noise_texture.width = 128
	_noise_texture.height = 128
	_noise_texture.noise = noise
	_noise_texture.seamless = true
	return _noise_texture


static func _bump_map() -> NoiseTexture2D:
	if _bump_texture != null:
		return _bump_texture
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.12
	noise.fractal_octaves = 2
	_bump_texture = NoiseTexture2D.new()
	_bump_texture.width = 128
	_bump_texture.height = 128
	_bump_texture.noise = noise
	_bump_texture.seamless = true
	_bump_texture.as_normal_map = true
	_bump_texture.bump_strength = 1.2
	return _bump_texture
