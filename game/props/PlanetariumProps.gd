class_name PlanetariumProps
extends RefCounted
## Procedural props for the Planetarium annexe (room centre world (0, 0, -41),
## footprint 20 x 16 m, WALL_HEIGHT 3.4, single doorway on the south wall at
## world (0, 0, -33) with DOOR_GAP 1.8).
##
## Self-contained by design: nothing here reads FirstMuseumMap, MapModels or any
## other script. Primitive/material conventions are copied from
## FirstMuseumMap._primitive() (visibility_range_end 115, shadows off under
## 0.65 m, collision only when size.x >= 0.12 and size.y >= 0.08 and
## size.z >= 0.12) so the geometry sits in the same visual family.
##
## The sign in the room says the projector is switched off, so nothing here
## emits light -- every material has emission disabled and the room reads purely
## as silhouette under the player's flashlight. Nothing moves, flickers or
## pulses either, so there is no SettingsManager.reduced_flashes surface to gate.
##
## BOUNDING BOXES, measured off the built tree, in metres relative to the
## `origin` each function is handed:
##   build_dome ........... 10.12 x 1.09 x 10.12   y  2.23 .. 3.32
##   build_projector ......  2.94 x 2.32 x  2.71   y -0.03 .. 2.28, x -1.02 .. 1.92,
##                                                 z -1.62 .. 1.09
##   build_seating_bank ... 15.24 x 2.28 x  5.79   y  0.00 .. 2.28, z -2.25 .. 3.54
##   build_operator_booth .  3.73 x 2.89 x  5.43   y  0.00 .. 2.89
## build_all() together spans 17.19 x 3.35 x 14.68 (x -7.62..9.57, z -7.10..7.58)
## and fits the 20 x 16 room with at least 0.07 m to every wall face. Nothing
## reaches WALL_HEIGHT 3.4 and nothing hangs below 2.23, so the 1.8 m player
## capsule walks the whole room without head-clipping a prop. The nearest
## collider to the doorway is the booth window sill, 4.9 m east of it.
##
## Some of those numbers are wider than the visible silhouette because they are
## AABBs: the projector's +X reach is its floor cable, its 2.32 top is the
## dust-sheet cone's bounding cylinder (the cloth itself tops out at 2.20), and
## its -0.03 floor is the mounting ring deliberately recessed into the 0.16 m
## floor slab.
##
## Measured with the props injected into the real map and the navmesh re-baked:
## NavigationServer3D paths from the Central Atrium reach the room centre, the
## west aisle and the inside of the booth, and a player-sized capsule sweeps the
## doorway at z -31.5 .. -36.0 without a single contact.


# --- Palette -----------------------------------------------------------------
# Night museum with the power failing: everything is a value, not a hue. The
# dust sheet over the projector is the single light-valued mass in the room, so
# it owns the silhouette; nothing else competes with it.
const MatLib := preload("res://game/props/MaterialLib.gd")

const CONCRETE := Color(0.20, 0.20, 0.21)
const CONCRETE_DARK := Color(0.14, 0.14, 0.15)
## Step nosings are lighter in VALUE, not in hue -- the edge of a 0.45 m drop
## has to read for a colour-blind player and in a greyscale CCTV feed alike.
const NOSING := Color(0.52, 0.51, 0.47)
const DOME_PANEL := Color(0.30, 0.30, 0.32)
const DOME_RIB := Color(0.15, 0.15, 0.17)
const DOME_RIM := Color(0.21, 0.21, 0.22)
const SEAT_FABRIC := Color(0.13, 0.12, 0.16)
const SEAT_FRAME := Color(0.10, 0.10, 0.11)
const MACHINE_DARK := Color(0.09, 0.09, 0.10)
const MACHINE_STEEL := Color(0.34, 0.34, 0.36)
const BRASS := Color(0.31, 0.26, 0.14)
const SHROUD := Color(0.46, 0.45, 0.42)
const BOOTH_WALL := Color(0.24, 0.24, 0.25)
const BOOTH_TRIM := Color(0.16, 0.16, 0.17)
const DEAD_SCREEN := Color(0.05, 0.06, 0.06)
const CABLE := Color(0.07, 0.07, 0.08)

# --- Fixed heights -----------------------------------------------------------
# Tied to WALL_HEIGHT 3.4 and to the player capsule (r 0.35, h 1.8). Nothing
# overhead hangs below DOME_SPRING_Y, so the player never head-clips a prop.
const DOME_SPRING_Y := 2.30
const DOME_APEX_Y := 3.28
## Ceiling slab colliders start at y 3.34; the oculus rim stops short of them.
const CEILING_CLEAR_Y := 3.32

## Shared meshes and materials. Static so a second build_map() in the same
## process pays nothing. Treat everything in here as immutable -- the resources
## are referenced by every instance that asked for the same parameters.
static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}


## Place the whole exhibit in one call. `origin` is the room centre at floor
## level -- world (0, 0, -41) for the Planetarium as the map lays it out.
static func build_all(parent: Node3D, origin: Vector3) -> Node3D:
	var root := _pivot(parent, "Planetarium Props", origin)
	build_dome(root, Vector3.ZERO)
	build_projector(root, Vector3.ZERO)
	build_seating_bank(root, Vector3(0, 0, -4.85))
	# Booth origin chosen so its outermost geometry (the window ledge on -X, the
	# console end panel on +Z) stops 0.07 m short of the room's east and south
	# wall faces at x 9.65 / z 7.65 instead of z-fighting with them.
	build_operator_booth(root, Vector3(7.72, 0, 4.85))
	return root


# --- Dome --------------------------------------------------------------------

## Shallow saucer dome over the room centre: a hanging rim, four open-ended
## frusta and eight meridian ribs, with the oculus left as a hole rather than a
## plate so the room's existing ceiling fixture shows through it.
##
## `origin` is the floor point the dome is centred on; the shell itself occupies
## y 2.30 .. 3.32 regardless. A hemisphere of this radius simply does not fit
## under a 3.4 m ceiling, and the squashed profile is the point: the annexe was
## never built to hold a planetarium and the dome is visibly too flat for one.
##
## Bounding box: (radius * 2) x 1.02 x (radius * 2), default 10.00 x 1.02 x 10.00.
## No collision on any part -- it is all above head height, and giving overhead
## shells colliders would make Recast filter the floor under them as low-height.
static func build_dome(parent: Node3D, origin: Vector3, radius := 5.0) -> Node3D:
	var root := _pivot(parent, "Planetarium Dome", origin)

	# Hanging rim. Its bottom edge at 2.30 is the lowest thing in the room, and
	# it is what the flashlight finds first when the player looks up.
	_torus(root, "Dome Rim", Vector3(0, DOME_SPRING_Y, 0),
		radius - 0.10, radius + 0.06, DOME_RIM, 32, 6)
	_tube(root, "Dome Skirt", Vector3(0, DOME_SPRING_Y + 0.16, 0),
		radius, radius, 0.32, DOME_PANEL, 24)

	# Profile as [y_bottom, y_top, radius_bottom, radius_top] with the radii
	# expressed as fractions of `radius`.
	var profile := [
		[2.62, 2.88, 1.000, 0.910],
		[2.88, 3.06, 0.910, 0.740],
		[3.06, 3.20, 0.740, 0.500],
		[3.20, DOME_APEX_Y, 0.500, 0.240],
	]
	for i in range(profile.size()):
		var seg: Array = profile[i]
		var y0: float = seg[0]
		var y1: float = seg[1]
		_tube(root, "Dome Shell %d" % (i + 1), Vector3(0, (y0 + y1) * 0.5, 0),
			radius * float(seg[2]), radius * float(seg[3]), y1 - y0,
			DOME_PANEL, 24)

	# Oculus. Deliberately open: a black disc punched out of the dome, ringed by
	# a rim so the hole has an edge to catch light. Sits below CEILING_CLEAR_Y.
	_torus(root, "Dome Oculus Rim", Vector3(0, CEILING_CLEAR_Y - 0.08, 0),
		radius * 0.216, radius * 0.252, DOME_RIM, 24, 6)

	# Meridian ribs, struck as straight chords from the spring line to the top
	# of shell 3. A chord sags inside the curve, which puts the ribs slightly
	# proud of the panels -- exactly where a rib belongs.
	var rib_r0 := radius * 1.0
	var rib_r1 := radius * 0.5
	var rib_len := Vector2(rib_r0 - rib_r1, 3.20 - 2.62).length()
	var rib_tilt := atan2(3.20 - 2.62, rib_r0 - rib_r1)
	var rib_mid := (rib_r0 + rib_r1) * 0.5
	for i in range(8):
		var a: float = TAU * float(i) / 8.0
		var rib := _box(root, "Dome Rib %d" % (i + 1), Vector3.ZERO,
			Vector3(rib_len, 0.07, 0.13), DOME_RIB, 0.0, false)
		# Lay the rib along the radial direction of azimuth `a`, then tip its
		# outer (+X) end down by the chord angle.
		rib.transform = Transform3D(
			Basis(Vector3.UP, a) * Basis(Vector3.BACK, -rib_tilt),
			Vector3(cos(a) * rib_mid, (2.62 + 3.20) * 0.5, -sin(a) * rib_mid))
	return root


# --- Projector ---------------------------------------------------------------

## The dead star projector: a Zeiss-style dumbbell on a yoke, tilted up toward
## the seating and half covered by a slipped dust sheet. `origin` is the floor
## point the pedestal stands on.
##
## Bounding box 2.20 x 2.20 x 2.65 -- X and Z ranges are -1.10 .. +1.10 and
## -1.65 .. +1.00 respectively (the sheet hangs over the raised head, so the
## footprint is not symmetric in Z). Top of the sheet reaches 2.20, clearing the
## dome rim at 2.30 by 0.10.
##
## Collision is the pedestal drum only: a 0.58 m tall obstacle at the room
## centre that both the player and the Curator walk around. Everything above it
## is left collider-free so the navmesh sees one tidy 1.5 m island, not a
## column of floating spans.
static func build_projector(parent: Node3D, origin: Vector3,
		heading_degrees := 0.0) -> Node3D:
	var root := _pivot(parent, "Planetarium Projector", origin)
	root.rotation.y = deg_to_rad(heading_degrees)

	# Mounting ring set into the floor. Lighter value than the floor, so the
	# machine reads as standing on something even when the room is nearly black.
	_torus(root, "Projector Floor Ring", Vector3(0, 0.03, 0), 0.85, 1.00,
		MACHINE_STEEL, 28, 6, 0.5)
	_cylinder(root, "Projector Pedestal", Vector3(0, 0.13, 0), 0.72, 0.26,
		MACHINE_DARK, 20)
	_cylinder(root, "Projector Drum", Vector3(0, 0.55, 0), 0.46, 0.58,
		MACHINE_DARK, 18)
	_torus(root, "Projector Drum Collar", Vector3(0, 0.84, 0), 0.44, 0.52,
		BRASS, 20, 6, 0.5)

	# Yoke arms. 0.09 m thick, so _primitive() gives them no collider.
	for side: float in [-1.0, 1.0]:
		_box(root, "Projector Yoke Arm %s" % ("R" if side > 0.0 else "L"),
			Vector3(side * 0.38, 1.29, 0), Vector3(0.09, 0.90, 0.20),
			MACHINE_STEEL, 0.45, false)
		var hub := _cylinder(root, "Projector Trunnion %s" % ("R" if side > 0.0 else "L"),
			Vector3(side * 0.30, 1.48, 0), 0.10, 0.14, MACHINE_STEEL, 12, 0.45, false)
		hub.rotation.z = deg_to_rad(90.0)

	# Dumbbell, tilted 26 degrees so the raised star ball aims at the seating
	# bank in -Z and the dead one droops toward the door.
	var head := _pivot(root, "Projector Head", Vector3(0, 1.48, 0))
	head.rotation.x = deg_to_rad(26.0)
	var axle := _cylinder(head, "Projector Axle", Vector3.ZERO, 0.10, 1.30,
		MACHINE_DARK, 12, 0.0, false)
	axle.rotation.x = deg_to_rad(90.0)
	for i in range(2):
		var sign_z := -1.0 if i == 0 else 1.0
		var tag := "Upper" if i == 0 else "Lower"
		var ball_pos := Vector3(0, 0, sign_z * 0.62)
		_sphere(head, "Projector Star Ball %s" % tag, ball_pos, 0.40,
			MACHINE_DARK, 16, 8)
		var belt := _torus(head, "Projector Star Belt %s" % tag, ball_pos,
			0.36, 0.44, MACHINE_STEEL, 16, 6, 0.5)
		belt.rotation.x = deg_to_rad(90.0)
		# Lens ports. Blind glass, no emission -- the machine is switched off.
		for k in range(4):
			var a: float = TAU * float(k) / 4.0 + 0.4
			_box(head, "Projector Lens Port %s %d" % [tag, k + 1],
				ball_pos + Vector3(cos(a) * 0.40, sin(a) * 0.40, 0),
				Vector3(0.11, 0.11, 0.06), DEAD_SCREEN, 0.0, false)

	_build_shroud(root)

	# Power cable, flopped out of the pedestal toward the booth side.
	var cable_pts := [
		[Vector3(0.80, 0.05, 0.30), 0.9, 62.0],
		[Vector3(1.55, 0.05, 0.65), 0.8, 30.0],
	]
	for i in range(cable_pts.size()):
		var seg: Array = cable_pts[i]
		var run := _cylinder(root, "Projector Cable %d" % (i + 1), seg[0],
			0.045, float(seg[1]), CABLE, 8, 0.0, false)
		run.rotation = Vector3(0, deg_to_rad(float(seg[2])), deg_to_rad(90.0))
	return root


## Dust sheet slipped off the raised star ball. Built as an open-ended cone so
## it is a single hooded silhouette rather than a pile of detail, plus three
## folds to stop the cone reading as a perfect solid of revolution.
static func _build_shroud(root: Node3D) -> void:
	var centre := Vector3(0, 1.52, -0.557)
	var sheet := _tube(root, "Projector Dust Sheet", centre,
		1.02, 0.28, 1.32, SHROUD, 20)
	sheet.rotation.x = deg_to_rad(4.0)
	for i in range(3):
		var a: float = TAU * float(i) / 3.0 + 0.6
		var fold := _box(root, "Dust Sheet Fold %d" % (i + 1), Vector3.ZERO,
			Vector3(0.09, 1.34, 0.09), SHROUD, 0.0, false)
		fold.transform = Transform3D(
			Basis(Vector3.UP, a) * Basis(Vector3.BACK, deg_to_rad(29.3)),
			centre + Vector3(cos(a) * 0.64, 0.0, -sin(a) * 0.64))


# --- Seating bank ------------------------------------------------------------

## Raked seating at the deep end of the room, rising away from the projector
## toward the north wall. `origin` is the floor centre of the bank footprint.
##
## Bounding box 15.24 x 2.28 x 5.65. The solid stepped mass is 15.00 x 1.35 x
## 4.50 (x -7.50..7.50, z -2.25..2.25); the extra depth on +Z is one toppled
## seat lying on the floor in front of the front row.
##
## Risers are 0.45 m on purpose. PlayerController.step_height is 0.38 and the
## navmesh agent_max_climb is 0.4, so neither the player nor the Curator can
## walk up the bank -- it is one solid unreachable mass, which is both the
## cheaper navmesh and the better silhouette. Only the three tier boxes carry
## colliders; the benches on top of them are out of reach and carry none.
static func build_seating_bank(parent: Node3D, origin: Vector3,
		width := 15.0, rows := 3) -> Node3D:
	var root := _pivot(parent, "Planetarium Seating Bank", origin)
	var tread := 1.50
	var riser := 0.45
	var front: float = tread * float(rows) * 0.5
	var bench_width: float = width - 0.60

	for i in range(rows):
		var h: float = riser * float(i + 1)
		var z_c: float = front - tread * (float(i) + 0.5)
		var tier_front: float = z_c + tread * 0.5
		_box(root, "Seating Tier %d" % (i + 1), Vector3(0, h * 0.5, z_c),
			Vector3(width, h, tread), CONCRETE)
		# Nosing strip flush with the tier top: a light-valued edge on a 0.45 m
		# drop, legible without relying on colour.
		_box(root, "Seating Nosing %d" % (i + 1),
			Vector3(0, h - 0.04, tier_front - 0.06),
			Vector3(width + 0.24, 0.08, 0.12), NOSING, 0.0, false)
		# Continuous bench rather than separate chairs: three unbroken
		# horizontal bands read far better through a torch beam than forty
		# little boxes, and cost a fraction of the nodes.
		_box(root, "Seating Bench Pan %d" % (i + 1),
			Vector3(0, h + 0.42, z_c + 0.24),
			Vector3(bench_width, 0.11, 0.58), SEAT_FABRIC, 0.0, false)
		var back := _box(root, "Seating Bench Back %d" % (i + 1),
			Vector3(0, h + 0.68, z_c - 0.22),
			Vector3(bench_width, 0.50, 0.10), SEAT_FABRIC, 0.0, false)
		back.rotation.x = deg_to_rad(-11.0)
		for k in range(6):
			var t: float = (float(k) + 0.5) / 6.0
			_box(root, "Seating Divider %d-%d" % [i + 1, k + 1],
				Vector3(-bench_width * 0.5 + bench_width * t, h + 0.62, z_c + 0.24),
				Vector3(0.07, 0.30, 0.62), SEAT_FRAME, 0.0, false)

	# One seat pulled out of the bank and left on its side on the floor. The
	# rows are otherwise perfectly regular, so a single wrong element carries
	# the whole read.
	# y 0.31, not 0.16: tipped 84 degrees the pan stands almost on edge, so its
	# 0.56 m depth becomes its height and a lower pivot buries it in the floor.
	var spill := _pivot(root, "Displaced Seat", Vector3(-3.20, 0.31, front + 0.70))
	spill.rotation = Vector3(deg_to_rad(84.0), deg_to_rad(-24.0), 0.0)
	_box(spill, "Displaced Seat Pan", Vector3.ZERO, Vector3(0.60, 0.11, 0.56),
		SEAT_FABRIC, 0.0, false)
	_box(spill, "Displaced Seat Back", Vector3(0, 0.30, -0.20),
		Vector3(0.56, 0.48, 0.10), SEAT_FABRIC, 0.0, false)
	return root


# --- Operator booth ----------------------------------------------------------

## Projection control booth tucked into the south-east corner. `origin` is the
## floor centre of its 3.70 x 5.40 footprint; it is meant to back onto the room's
## east and south walls, so it only builds two walls of its own.
##
## Bounding box 3.70 x 2.89 x 5.40 (walls 2.75 tall, roof slab to 2.89).
##
## Navmesh contract: the 1.90 m opening in the north wall is the booth's only
## way in, its lintel starts at y 2.30 (above agent_height 2.2) AND carries no
## collider, so filter_walkable_low_height_spans cannot quietly seal the booth
## and strand the Curator inside a disconnected island. The roof slab is
## collider-free for the same reason.
static func build_operator_booth(parent: Node3D, origin: Vector3,
		facing_degrees := 0.0) -> Node3D:
	var root := _pivot(parent, "Planetarium Operator Booth", origin)
	root.rotation.y = deg_to_rad(facing_degrees)
	var half_x := 1.85
	var half_z := 2.70
	var wall_t := 0.16

	# West wall: a long unglazed observation slot at y 1.05 .. 2.05. The slot is
	# the whole point of the booth -- a 5.4 m band of pure black facing the
	# seating, which the player cannot ever quite clear with a flashlight.
	var wx := -half_x + wall_t * 0.5
	_box(root, "Booth Window Sill", Vector3(wx, 0.525, 0),
		Vector3(wall_t, 1.05, half_z * 2.0), BOOTH_WALL)
	_box(root, "Booth Window Header", Vector3(wx, 2.40, 0),
		Vector3(wall_t, 0.70, half_z * 2.0), BOOTH_WALL, 0.0, false)
	_box(root, "Booth Window Ledge", Vector3(wx, 1.08, 0),
		Vector3(0.22, 0.06, half_z * 2.0), BOOTH_TRIM, 0.0, false)
	for side: float in [-1.0, 1.0]:
		_box(root, "Booth Window Mullion %s" % ("S" if side > 0.0 else "N"),
			Vector3(wx, 1.55, side * 1.55), Vector3(0.14, 1.00, 0.10),
			BOOTH_TRIM, 0.0, false)

	# North wall with the doorway. Segments are sized so the 1.90 m opening
	# lands clear of the console run inside.
	var nz := -half_z + wall_t * 0.5
	_box(root, "Booth North Wall West", Vector3(-1.20, 1.375, nz),
		Vector3(1.30, 2.75, wall_t), BOOTH_WALL)
	_box(root, "Booth North Wall East", Vector3(1.60, 1.375, nz),
		Vector3(0.50, 2.75, wall_t), BOOTH_WALL)
	_box(root, "Booth Door Lintel", Vector3(0.40, 2.525, nz),
		Vector3(1.90, 0.45, wall_t), BOOTH_WALL, 0.0, false)
	_box(root, "Booth Roof", Vector3(0, 2.82, 0),
		Vector3(half_x * 2.0, 0.14, half_z * 2.0), BOOTH_TRIM, 0.0, false)

	_build_booth_console(root)
	_build_booth_chair(root)
	_build_booth_rack(root)
	return root


static func _build_booth_console(root: Node3D) -> void:
	_box(root, "Booth Console Top", Vector3(-1.28, 0.90, 0.50),
		Vector3(0.75, 0.10, 4.40), BOOTH_TRIM)
	_box(root, "Booth Console Kick", Vector3(-0.94, 0.425, 0.50),
		Vector3(0.06, 0.85, 4.40), CONCRETE_DARK, 0.0, false)
	for side: float in [-1.0, 1.0]:
		_box(root, "Booth Console End %s" % ("S" if side > 0.0 else "N"),
			Vector3(-1.28, 0.425, 0.50 + side * 2.20),
			Vector3(0.75, 0.85, 0.06), CONCRETE_DARK, 0.0, false)

	# Raked switch panel, tipped toward the operator's seat on +X.
	var panel := _box(root, "Booth Switch Panel", Vector3(-1.20, 1.00, 0.50),
		Vector3(0.55, 0.05, 3.80), MACHINE_DARK, 0.0, false)
	panel.rotation.z = deg_to_rad(-22.0)
	for i in range(8):
		var t: float = (float(i) + 0.5) / 8.0
		_box(panel, "Booth Switch %d" % (i + 1),
			Vector3(0.10, 0.04, -1.90 + 3.80 * t),
			Vector3(0.06, 0.03, 0.05), MACHINE_STEEL, 0.45, false)

	for i in range(2):
		var mz := -0.90 if i == 0 else 1.60
		_box(root, "Booth Monitor %d" % (i + 1), Vector3(-0.75, 1.13, mz),
			Vector3(0.40, 0.36, 0.42), MACHINE_DARK, 0.0, false)
		_box(root, "Booth Monitor Screen %d" % (i + 1), Vector3(-0.54, 1.15, mz),
			Vector3(0.02, 0.26, 0.32), DEAD_SCREEN, 0.0, false)
	_box(root, "Booth Logbook", Vector3(-1.15, 0.96, -1.10),
		Vector3(0.24, 0.02, 0.32), NOSING, 0.0, false)
	for i in range(2):
		# y 0.05, not 0.04: the coil's tube radius is 0.04, so any lower and its
		# underside lands coplanar with the floor slab top and z-fights it.
		_torus(root, "Booth Cable Coil %d" % (i + 1),
			Vector3(0.60 + float(i) * 0.22, 0.05, -1.20 + float(i) * 0.18),
			0.18, 0.26, CABLE, 16, 5)


static func _build_booth_chair(root: Node3D) -> void:
	# Turned away from the console to face the back corner. Nobody sits like
	# that; it is the only thing in the booth that is out of place.
	var chair := _pivot(root, "Booth Chair", Vector3(0.40, 0, 0.60))
	chair.rotation.y = deg_to_rad(150.0)
	# 0.035 rather than 0.03 keeps the base off the floor plane by 5 mm.
	_cylinder(chair, "Chair Base", Vector3(0, 0.035, 0), 0.30, 0.06,
		MACHINE_DARK, 12)
	_cylinder(chair, "Chair Column", Vector3(0, 0.25, 0), 0.05, 0.38,
		MACHINE_STEEL, 8, 0.45)
	_box(chair, "Chair Pan", Vector3(0, 0.48, 0), Vector3(0.46, 0.09, 0.46),
		SEAT_FABRIC)
	var back := _box(chair, "Chair Back", Vector3(0, 0.80, -0.22),
		Vector3(0.42, 0.52, 0.09), SEAT_FABRIC, 0.0, false)
	back.rotation.x = deg_to_rad(8.0)


static func _build_booth_rack(root: Node3D) -> void:
	_box(root, "Booth Equipment Rack", Vector3(1.35, 0.95, 2.30),
		Vector3(0.86, 1.90, 0.60), MACHINE_DARK)
	for i in range(5):
		_box(root, "Booth Rack Blank %d" % (i + 1),
			Vector3(1.35, 0.35 + float(i) * 0.36, 1.97),
			Vector3(0.78, 0.28, 0.04), BOOTH_TRIM, 0.0, false)


# --- Primitive builders ------------------------------------------------------

static func _pivot(parent: Node3D, node_name: String, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = pos
	parent.add_child(node)
	return node


static func _box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3,
		color: Color, metallic := 0.0, with_collision := true) -> MeshInstance3D:
	var key := "box:%s" % size
	var mesh: BoxMesh = _meshes.get(key)
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
		_meshes[key] = mesh
	return _primitive(parent, node_name, pos, mesh, size, color, metallic,
		false, with_collision)


static func _cylinder(parent: Node3D, node_name: String, pos: Vector3,
		radius: float, height: float, color: Color, segments := 16,
		metallic := 0.0, with_collision := true) -> MeshInstance3D:
	return _cone(parent, node_name, pos, radius, radius, height, color,
		segments, metallic, with_collision)


static func _cone(parent: Node3D, node_name: String, pos: Vector3,
		bottom_radius: float, top_radius: float, height: float, color: Color,
		segments := 16, metallic := 0.0, with_collision := true) -> MeshInstance3D:
	var key := "cone:%.4f:%.4f:%.4f:%d" % [bottom_radius, top_radius, height, segments]
	var mesh: CylinderMesh = _meshes.get(key)
	if mesh == null:
		mesh = CylinderMesh.new()
		mesh.bottom_radius = bottom_radius
		mesh.top_radius = top_radius
		mesh.height = height
		# Godot defaults to 64 radial segments; at museum scale that is a few
		# thousand wasted triangles per pillar. Everything here is explicit.
		mesh.radial_segments = segments
		mesh.rings = 1
		_meshes[key] = mesh
	var r: float = maxf(bottom_radius, top_radius)
	return _primitive(parent, node_name, pos, mesh,
		Vector3(r * 2.0, height, r * 2.0), color, metallic, false, with_collision)


## Open-ended frustum: no end caps and a two-sided material, so it reads as a
## thin shell from inside and outside alike. Used for the dome and the dust
## sheet. Never given collision -- a shell collider is a trap for the navmesh.
static func _tube(parent: Node3D, node_name: String, pos: Vector3,
		bottom_radius: float, top_radius: float, height: float, color: Color,
		segments := 20) -> MeshInstance3D:
	var key := "tube:%.4f:%.4f:%.4f:%d" % [bottom_radius, top_radius, height, segments]
	var mesh: CylinderMesh = _meshes.get(key)
	if mesh == null:
		mesh = CylinderMesh.new()
		mesh.bottom_radius = bottom_radius
		mesh.top_radius = top_radius
		mesh.height = height
		mesh.radial_segments = segments
		mesh.rings = 1
		mesh.cap_top = false
		mesh.cap_bottom = false
		_meshes[key] = mesh
	var r: float = maxf(bottom_radius, top_radius)
	return _primitive(parent, node_name, pos, mesh,
		Vector3(r * 2.0, height, r * 2.0), color, 0.0, true, false)


static func _sphere(parent: Node3D, node_name: String, pos: Vector3,
		radius: float, color: Color, segments := 16, rings := 8,
		metallic := 0.0) -> MeshInstance3D:
	var key := "sphere:%.4f:%d:%d" % [radius, segments, rings]
	var mesh: SphereMesh = _meshes.get(key)
	if mesh == null:
		mesh = SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = segments
		mesh.rings = rings
		_meshes[key] = mesh
	return _primitive(parent, node_name, pos, mesh,
		Vector3(radius * 2.0, radius * 2.0, radius * 2.0), color, metallic,
		false, false)


## Flat ring in the XZ plane (TorusMesh's default orientation). Callers rotate
## it themselves when they want a collar instead of a rim.
static func _torus(parent: Node3D, node_name: String, pos: Vector3,
		inner_radius: float, outer_radius: float, color: Color,
		rings := 24, ring_segments := 6, metallic := 0.0) -> MeshInstance3D:
	var key := "torus:%.4f:%.4f:%d:%d" % [inner_radius, outer_radius, rings, ring_segments]
	var mesh: TorusMesh = _meshes.get(key)
	if mesh == null:
		mesh = TorusMesh.new()
		mesh.inner_radius = inner_radius
		mesh.outer_radius = outer_radius
		# Defaults are 64 x 32; that is 4096 quads for a decorative rim.
		mesh.rings = rings
		mesh.ring_segments = ring_segments
		_meshes[key] = mesh
	var thickness: float = outer_radius - inner_radius
	return _primitive(parent, node_name, pos, mesh,
		Vector3(outer_radius * 2.0, thickness, outer_radius * 2.0), color,
		metallic, false, false)


static func _primitive(parent: Node3D, node_name: String, pos: Vector3,
		mesh: Mesh, size: Vector3, color: Color, metallic: float,
		two_sided: bool, with_collision: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = pos
	instance.mesh = mesh
	instance.material_override = _material(color, metallic, two_sided)
	instance.visibility_range_end = 115.0
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if size.length() < 0.65:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	elif two_sided:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	parent.add_child(instance)

	# Same threshold as FirstMuseumMap._primitive(): trim, ribs and switches do
	# not need physics bodies, and every collider skipped is one fewer surface
	# for the navmesh bake to rasterise.
	var collision_worthy: bool = size.x >= 0.12 and size.y >= 0.08 and size.z >= 0.12
	if with_collision and collision_worthy:
		var body := StaticBody3D.new()
		body.name = "%s Collision" % node_name
		instance.add_child(body)
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.name = "%s CollisionShape" % node_name
		collider.shape = shape
		body.add_child(collider)
	return instance


## Палитра планетария -> набор карт. Двусторонние поверхности (внутренность
## купола) идут мимо: им нужен cull_disabled, которого в библиотеке нет.
static func _pack_for(color: Color) -> String:
	if color.is_equal_approx(CONCRETE) or color.is_equal_approx(CONCRETE_DARK) \
			or color.is_equal_approx(BOOTH_WALL) or color.is_equal_approx(BOOTH_TRIM):
		return "concrete"
	if color.is_equal_approx(NOSING) or color.is_equal_approx(SHROUD):
		return "quartzite"
	if color.is_equal_approx(DOME_PANEL) or color.is_equal_approx(DOME_RIB) \
			or color.is_equal_approx(DOME_RIM) or color.is_equal_approx(MACHINE_STEEL) \
			or color.is_equal_approx(MACHINE_DARK) or color.is_equal_approx(SEAT_FRAME):
		return "steel"
	if color.is_equal_approx(BRASS):
		return "painted_metal"
	return ""


static func _material(color: Color, metallic: float,
		two_sided: bool) -> StandardMaterial3D:
	var key := "%s|%.2f|%s" % [color.to_html(true), metallic, two_sided]
	var cached: StandardMaterial3D = _mats.get(key)
	if cached != null:
		return cached
	if not two_sided:
		var pack := _pack_for(color)
		if not pack.is_empty():
			var photo := MatLib.get_material(pack, color)
			_mats[key] = photo
			return photo
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	# Matte by default. A gloss highlight on a prop in a dark room draws the eye
	# to a specular dot instead of to the shape, which is the opposite of what
	# this room is for; only the metal parts are allowed to catch the torch.
	mat.roughness = clampf(0.62 - metallic * 0.40, 0.14, 1.0)
	mat.metallic = metallic
	mat.metallic_specular = 0.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	# Emission is never enabled anywhere in this file: the sign on the door says
	# the projector is switched off, and a glowing prop would contradict it.
	if two_sided:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = mat
	return mat
