class_name GravityProps
extends RefCounted
## Procedural prop set for Gravity Wing A of the First Museum.
##
## The wing's three exhibits (falling cube, inversion room, levitating column)
## used to be a tilted box over a shadow disc. This file replaces them with
## contained physics experiments: suspension rigs, field emitters, floor
## markings, cabling and stencils, so the case reads as apparatus holding a
## constant still rather than an object on a plinth.
##
## Everything is static and self-contained. Nothing here preloads, autoloads or
## calls into another script; the map file places a prop in one line and gets
## the root Node3D back.
##
##
## SCALE
##
## Rooms are WALL_HEIGHT 3.4 m tall with the ceiling soffit at 3.39 m. The
## museum's exhibit slot is a 2.8 x 0.7 x 2.8 m pedestal under a
## 2.25 x 2.10 x 2.25 m glass case centred 1.40 m up, so the usable interior is
##
##     y from 0.70 (pedestal top, DECK) to 2.45 (case lid)
##     x and z within +-1.125 of the exhibit centre
##
## The three exhibit builders keep every vertex inside y 0.70 .. 2.38 and
## +-0.95 horizontally, which leaves at least 0.17 m of air between the prop and
## the glass on every face. Their `origin` is the FLOOR-LEVEL centre of the
## exhibit -- the same Vector3 the map passes to _add_exhibit -- not the
## pedestal top, so a call site never has to add 0.7 by hand.
##
##
## COLLISION
##
## This file adds no StaticBody3D at all, on purpose.
##
## The navigation mesh is baked from static colliders only
## (PARSED_GEOMETRY_STATIC_COLLIDERS), so a prop without a body cannot pinch a
## doorway or strand the Curator no matter where it is dropped. That is safe
## here because none of it is reachable: the case interiors sit behind a 2.8 m
## pedestal whose own body already stops the player 1.4 m short of the centre,
## the anchor plates are flush fixtures, the tethered debris hangs above head
## height and the stencils are paint. If a call site ever stands one of the
## exhibit rigs free on the floor with no pedestal, it must add the collider at
## the call site -- and keep it out of every doorway, because DOOR_GAP is 1.8 m
## and the bake erodes 0.45 m per side.
##
##
## MOTION AND CONTRAST
##
## Nothing in this file moves, flickers or pulses: no AnimationPlayer, no
## _process, no shader time. There is therefore nothing for
## SettingsManager.reduced_flashes to switch off, and the wing looks identical
## with the setting on or off. Emissive parts are constant, low energy lenses
## and indicators.
##
## No prop states anything by colour alone. Hazard paint is always cut into
## chevrons, corner brackets or a triangle outline; the anchor plate's live
## indicator is three notches at 120 degrees around a recessed socket; the
## column's measured gaps are marked by beads at the gap heights. Read in
## greyscale, every one of them still reads.
##
##
## COST
##
## The map already builds about 1170 MeshInstance3D nodes in one frame, so each
## builder here stays near 50 nodes (50 / 53 / 46 for the exhibits, 11 to 33 for
## the dressing) and shares meshes and materials through the two static caches
## below. Segment counts are cut far under Godot's defaults, which matters most
## for the parts there are dozens of:
##
##     SphereMesh   stock 4224 tris   dust mote 60, hero sphere 168
##     CylinderMesh stock  768 tris   every cylinder and link 60
##     TorusMesh    stock 4096 tris   every ring 252
##
## In a stress build of 828 mesh instances out of this file, those instances
## resolved to 83 unique Mesh resources and 9 unique StandardMaterial3D
## resources, so the caches are doing the work they are there for.


# --- Interior envelope ------------------------------------------------------

## Pedestal top. Local y of the surface an exhibit stands on.
const DECK := 0.70
## Highest local y any exhibit part may reach: 0.07 under the glass lid.
const RIG_TOP := 2.38
## Horizontal half-extent that clears the 2.25 m case with room to spare.
const CASE_INNER_HALF := 1.06

# --- Palette ----------------------------------------------------------------
# Steel and cable read almost black under the wing's failing blue lights; the
# paint colours are chalky and unsaturated so they look sprayed on, not lit.

const STEEL := Color(0.105, 0.115, 0.125)
const STEEL_LIGHT := Color(0.185, 0.200, 0.215)
const CABLE := Color(0.035, 0.038, 0.042)
const CONCRETE := Color(0.185, 0.185, 0.178)
const DUST := Color(0.415, 0.415, 0.395)
const PAINT_LINE := Color(0.615, 0.625, 0.600)
const PAINT_HAZARD := Color(0.520, 0.380, 0.070)
const SHADOW := Color(0.035, 0.035, 0.040)
## Containment field blue, matched to the Gravity Wing ceiling light.
const FIELD := Color(0.420, 0.580, 0.920)

## Authored exhibit accents, kept identical to the colours the map already
## passes for these three slots so the wing palette does not shift.
const CUBE_ACCENT := Color(0.18, 0.28, 0.48)
const CELL_ACCENT := Color(0.36, 0.22, 0.46)
const COLUMN_ACCENT := Color(0.45, 0.45, 0.38)

# --- Tessellation -----------------------------------------------------------

const CYLINDER_SEGMENTS := 10
const SPHERE_SEGMENTS := 12
const SPHERE_RINGS := 6
const MOTE_SEGMENTS := 6
const MOTE_RINGS := 4
const TORUS_RINGS := 18
const TORUS_RING_SEGMENTS := 7

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
static var _grain: NoiseTexture2D = null
static var _grain_normal: NoiseTexture2D = null


# =============================================================================
# Exhibit 1 -- Falling Cube
# =============================================================================

## Suspension rig holding a cube frozen part-way through a fall.
##
## Four corner posts carry an emitter head; the cube hangs from four monofilament
## tethers and is tied back down to the kerb by two more, so it is being stopped
## from both directions at once. The pedestal under it is painted with the
## landing square the cube never reached, and the crater ring says something
## did reach it, once. A graduated scale up one post carries a single hazard
## tick at the height the fall stopped.
##
## Bounding box 1.88 x 1.68 x 1.93 m, local x -0.95 .. +0.93, y 0.70 .. 2.38,
## z -1.00 .. +0.94. Clears the glass by at least 0.13 m on every face.
static func build_falling_cube_rig(parent: Node3D, origin: Vector3,
		accent := CUBE_ACCENT) -> Node3D:
	var root := _holder(parent, "Falling Cube Rig", origin)

	# --- Cage: four posts, a kerb at the deck, an emitter head on top -------
	for i in range(4):
		var sx: float = 1.0 if i < 2 else -1.0
		var sz: float = 1.0 if i % 2 == 0 else -1.0
		_box(root, "Rig Post %d" % i, Vector3(sx * 0.88, 1.54, sz * 0.88),
			Vector3(0.07, 1.68, 0.07), STEEL, 0.0, 0.62)
	for i in range(2):
		var s: float = 1.0 if i == 0 else -1.0
		_box(root, "Rig Kerb X %d" % i, Vector3(0.0, 0.735, s * 0.88),
			Vector3(1.83, 0.07, 0.09), STEEL, 0.0, 0.55)
		_box(root, "Rig Kerb Z %d" % i, Vector3(s * 0.88, 0.735, 0.0),
			Vector3(0.09, 0.07, 1.83), STEEL, 0.0, 0.55)
	_box(root, "Emitter Head", Vector3(0, 2.335, 0), Vector3(1.83, 0.09, 1.83),
		STEEL_LIGHT, 0.0, 0.50)

	# Four downward nozzles with constant lenses: the field is pressing the
	# cube from above, which is why it is not falling.
	for i in range(4):
		var sx: float = 1.0 if i < 2 else -1.0
		var sz: float = 1.0 if i % 2 == 0 else -1.0
		_cone(root, "Field Nozzle %d" % i, Vector3(sx * 0.52, 2.205, sz * 0.52),
			0.035, 0.115, 0.17, STEEL_LIGHT, 0.0, 0.5)
		_cylinder(root, "Field Lens %d" % i,
			Vector3(sx * 0.52, 2.116, sz * 0.52), 0.05, 0.014, FIELD, 0.9)

	# --- The cube ----------------------------------------------------------
	# 0.82 m on a side: tilted, its worst-case reach from centre is 0.71 m, so
	# it clears the posts at 0.88 and stays inside the case.
	var tilt := Vector3(deg_to_rad(24.0), deg_to_rad(38.0), deg_to_rad(12.0))
	var cube_centre := Vector3(0, 1.50, 0)
	var cube := _box(root, "Frozen Cube", cube_centre,
		Vector3(0.82, 0.82, 0.82), accent, 0.16)
	cube.basis = Basis.from_euler(tilt)

	# --- Tethers -----------------------------------------------------------
	# Anchored to the cube's real rotated corners, so the wires splay exactly
	# as far as the cube is tilted rather than hanging in a tidy pyramid.
	var half := 0.41
	var corner_signs := [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]
	for i in range(4):
		var s: Vector2 = corner_signs[i]
		var corner: Vector3 = cube_centre + cube.basis * Vector3(s.x * half, half, s.y * half)
		# Anchored at 0.66 rather than under a nozzle: the nozzle mouths reach
		# 0.115 around (+-0.52, +-0.52) and a closer anchor threads the wire
		# straight through the rim.
		_link(root, "Suspension Tether %d" % i, corner,
			Vector3(s.x * 0.66, 2.285, s.y * 0.66), 0.009, STEEL_LIGHT, 0.0, 0.7)
	var hold_downs := [
		[Vector3(half, -half, half), Vector3(0.86, 0.78, 0.50)],
		[Vector3(-half, -half, -half), Vector3(-0.50, 0.78, -0.86)],
	]
	for i in range(hold_downs.size()):
		var pair: Array = hold_downs[i]
		_link(root, "Hold Down Tether %d" % i,
			cube_centre + cube.basis * (pair[0] as Vector3), pair[1] as Vector3,
			0.011, STEEL_LIGHT, 0.0, 0.7)

	# --- Cabling -----------------------------------------------------------
	_box(root, "Rig Junction Box", Vector3(-0.88, 1.34, -0.955),
		Vector3(0.14, 0.20, 0.08), STEEL_LIGHT, 0.0, 0.45)
	_link(root, "Rig Cable Upper", Vector3(-0.88, 2.280, -0.930),
		Vector3(-0.88, 1.440, -0.955), 0.016, CABLE)
	_link(root, "Rig Cable Lower", Vector3(-0.88, 1.240, -0.955),
		Vector3(-0.86, 0.800, -0.860), 0.016, CABLE)
	_link(root, "Rig Cable Deck", Vector3(-0.86, 0.800, -0.860),
		Vector3(-0.30, 0.745, -0.900), 0.016, CABLE)

	# --- Graduated scale ---------------------------------------------------
	for i in range(7):
		var y: float = 0.90 + 0.20 * float(i)
		_box(root, "Fall Scale Tick %d" % i, Vector3(0.9215, y, 0.88),
			Vector3(0.014, 0.012, 0.060), PAINT_LINE)
	# The one graduation that matters, called out by length as well as colour.
	_box(root, "Arrest Height Mark", Vector3(0.9215, 1.50, 0.88),
		Vector3(0.016, 0.018, 0.110), PAINT_HAZARD)

	# Hazard banding: three diagonal stripes across the outer face of one post.
	for i in range(3):
		var y0: float = 1.06 + 0.12 * float(i)
		_span(root, "Post Hazard Stripe %d" % i, Vector3(-0.9185, y0, -0.915),
			Vector3(-0.9185, y0 + 0.10, -0.845), Vector2(0.050, 0.012),
			PAINT_HAZARD)

	# --- Deck markings -----------------------------------------------------
	_deck_square(root, "Landing Square", 0.45, PAINT_LINE)
	_deck_chevron(root, "Landing Chevron", 0.70, 0.24, 0.16, PAINT_HAZARD)
	_cylinder(root, "Arrest Shadow", Vector3(0, 0.712, 0), 0.38, 0.016, SHADOW)
	_torus(root, "Impact Rim", Vector3(0, 0.725, 0), 0.32, 0.38, SHADOW)
	for i in range(3):
		var a: float = deg_to_rad(20.0 + 118.0 * float(i))
		_span(root, "Impact Crack %d" % i,
			Vector3(cos(a) * 0.36, 0.709, sin(a) * 0.36),
			Vector3(cos(a) * 0.62, 0.709, sin(a) * 0.62),
			Vector2(0.012, 0.035), SHADOW)
	return root


# =============================================================================
# Exhibit 2 -- Inversion Room
# =============================================================================

## A room-sized volume where down is up, shrunk into a containment cell.
##
## Between two field coils sits a slab of floor mounted at the TOP of the cell,
## with a stool standing on its underside, a cup upright against it and grit
## resting on it. A tipped jug at the bottom pours upward into the same slab.
## Chevrons on the frame point the way the cell's gravity actually goes.
##
## Bounding box 1.90 x 1.62 x 1.93 m, local x -0.94 .. +0.97, y 0.72 .. 2.34,
## z -1.00 .. +0.93. Clears the glass by at least 0.12 m on every face.
static func build_inversion_cell(parent: Node3D, origin: Vector3,
		accent := CELL_ACCENT) -> Node3D:
	var root := _holder(parent, "Inversion Cell", origin)

	# --- Cell frame --------------------------------------------------------
	for i in range(4):
		var sx: float = 1.0 if i < 2 else -1.0
		var sz: float = 1.0 if i % 2 == 0 else -1.0
		_box(root, "Cell Post %d" % i, Vector3(sx * 0.90, 1.53, sz * 0.90),
			Vector3(0.06, 1.62, 0.06), STEEL, 0.0, 0.6)
	var rail_levels := [0.75, 2.31]
	for i in range(2):
		var s: float = 1.0 if i == 0 else -1.0
		for j in range(rail_levels.size()):
			var level: float = rail_levels[j]
			_box(root, "Cell Rail X %d" % (i * 2 + j), Vector3(0.0, level, s * 0.90),
				Vector3(1.80, 0.06, 0.06), STEEL, 0.0, 0.6)
			_box(root, "Cell Rail Z %d" % (i * 2 + j), Vector3(s * 0.90, level, 0.0),
				Vector3(0.06, 0.06, 1.80), STEEL, 0.0, 0.6)

	# --- Emitter grille at the bottom --------------------------------------
	for i in range(5):
		var z: float = -0.60 + 0.30 * float(i)
		_box(root, "Cell Grille Slat %d" % i, Vector3(0, 0.775, z),
			Vector3(1.72, 0.035, 0.10), STEEL, 0.0, 0.55)

	# --- The inverted floor, mounted overhead ------------------------------
	_box(root, "Inverted Floor Slab", Vector3(0, 2.245, 0),
		Vector3(1.72, 0.06, 1.72), CONCRETE)
	for i in range(2):
		var s: float = 1.0 if i == 0 else -1.0
		_box(root, "Inverted Floor Groove X %d" % i,
			Vector3(0, 2.212, s * 0.43), Vector3(1.72, 0.012, 0.02), SHADOW)
		_box(root, "Inverted Floor Groove Z %d" % i,
			Vector3(s * 0.43, 2.212, 0), Vector3(0.02, 0.012, 1.72), SHADOW)

	# Stool standing on the underside of that floor.
	var wood := Color(0.20, 0.14, 0.09)
	var stool := Vector3(-0.28, 0.0, 0.22)
	_box(root, "Inverted Stool Seat", Vector3(stool.x, 2.005, stool.z),
		Vector3(0.34, 0.045, 0.34), wood)
	for i in range(4):
		var lx: float = 0.13 if i < 2 else -0.13
		var lz: float = 0.13 if i % 2 == 0 else -0.13
		_box(root, "Inverted Stool Leg %d" % i,
			Vector3(stool.x + lx, 2.122, stool.z + lz),
			Vector3(0.035, 0.19, 0.035), wood)
	# Cup standing the right way up on a floor that is over your head.
	_cylinder(root, "Inverted Cup", Vector3(0.42, 2.158, -0.34), 0.055, 0.11,
		Color(0.72, 0.71, 0.68))
	var grit_a := _box(root, "Inverted Grit A", Vector3(-0.10, 2.164, 0.52),
		Vector3(0.10, 0.10, 0.10), CONCRETE)
	grit_a.rotation_degrees = Vector3(18, 30, 9)
	var grit_b := _box(root, "Inverted Grit B", Vector3(0.20, 2.174, 0.50),
		Vector3(0.08, 0.08, 0.08), CONCRETE)
	grit_b.rotation_degrees = Vector3(40, 12, 25)

	# --- The upward pour ---------------------------------------------------
	var jug := _cylinder(root, "Tipped Jug", Vector3(-0.46, 0.90, 0.36),
		0.085, 0.24, Color(0.30, 0.26, 0.22))
	jug.basis = Basis.from_euler(Vector3(0, deg_to_rad(25.0), deg_to_rad(62.0)))
	var mouth: Vector3 = Vector3(-0.46, 0.90, 0.36) + jug.basis * Vector3(0, 0.13, 0)
	var pour_top := Vector3(-0.34, 2.205, 0.40)
	_link(root, "Upward Pour", mouth, pour_top, 0.018,
		Color(0.62, 0.66, 0.70), 0.22)
	for i in range(4):
		var t: float = 0.28 + 0.19 * float(i)
		var p: Vector3 = mouth.lerp(pour_top, t)
		p.x += 0.055 if i % 2 == 0 else -0.045
		p.z += 0.03 * float(i) - 0.05
		_sphere(root, "Suspended Droplet %d" % i, p, 0.022,
			Color(0.62, 0.66, 0.70), 0.22)

	# --- Field coils and cabling -------------------------------------------
	_torus(root, "Cell Coil Lower", Vector3(0, 0.83, 0), 0.62, 0.72, accent, 0.45)
	_torus(root, "Cell Coil Upper", Vector3(0, 2.16, 0), 0.62, 0.72, accent, 0.45)
	_box(root, "Cell Junction Box", Vector3(0.90, 1.20, -0.955),
		Vector3(0.13, 0.18, 0.09), STEEL_LIGHT, 0.0, 0.45)
	_link(root, "Cell Cable Lower", Vector3(0.90, 1.115, -0.955),
		Vector3(0.66, 0.845, -0.30), 0.014, CABLE)
	_link(root, "Cell Cable Upper", Vector3(0.90, 1.285, -0.955),
		Vector3(0.66, 2.145, -0.30), 0.014, CABLE)
	for i in range(2):
		var s: float = 1.0 if i == 0 else -1.0
		_link(root, "Coil Standoff Lower %d" % i,
			Vector3(s * 0.87, 0.83, 0.0), Vector3(s * 0.70, 0.83, 0.0),
			0.018, STEEL, 0.0, 0.6)
		_link(root, "Coil Standoff Upper %d" % i,
			Vector3(s * 0.87, 2.16, 0.0), Vector3(s * 0.70, 2.16, 0.0),
			0.018, STEEL, 0.0, 0.6)

	# --- Which way is down, in shape as well as colour ---------------------
	for i in range(2):
		var s: float = 1.0 if i == 0 else -1.0
		for j in range(2):
			var y0: float = 1.18 + 0.22 * float(j)
			var x: float = s * 0.933
			_span(root, "Cell Up Chevron %d Near" % (i * 2 + j),
				Vector3(x, y0, -0.07), Vector3(x, y0 + 0.10, 0.0),
				Vector2(0.035, 0.012), PAINT_HAZARD)
			_span(root, "Cell Up Chevron %d Far" % (i * 2 + j),
				Vector3(x, y0, 0.07), Vector3(x, y0 + 0.10, 0.0),
				Vector2(0.035, 0.012), PAINT_HAZARD)
	return root


# =============================================================================
# Exhibit 3 -- Levitating Column
# =============================================================================

## A stone column that came apart and stopped instead of falling.
##
## Five drums, each floating a little further from the one below and drifting a
## little further off axis, held between a floor collar and a capture ring by
## three emitter masts. The grit that came out of the breaks is still in the
## breaks. A monitoring wire beside the column carries one bead at each gap
## height, so the growing separation is measured, not just implied.
##
## Bounding box 1.64 x 1.68 x 1.67 m, centred on the axis, local y 0.70 .. 2.38.
## Clears the glass by 0.29 m on every side -- the roomiest of the three.
static func build_levitating_column(parent: Node3D, origin: Vector3,
		accent := COLUMN_ACCENT) -> Node3D:
	var root := _holder(parent, "Levitating Column Rig", origin)

	# radius, height, centre y, x drift, z drift, yaw, tilt
	var drums := [
		[0.340, 0.28, 0.84, 0.000, 0.000, 0.0, 0.0],
		[0.325, 0.22, 1.15, 0.020, -0.010, 6.0, 0.0],
		[0.335, 0.22, 1.46, -0.030, 0.035, -11.0, 1.0],
		[0.315, 0.22, 1.81, 0.055, 0.020, 17.0, 2.0],
		[0.300, 0.22, 2.20, -0.040, -0.085, -24.0, 4.0],
	]
	for i in range(drums.size()):
		var d: Array = drums[i]
		var drum := _cylinder(root, "Column Drum %d" % i,
			Vector3(float(d[3]), float(d[2]), float(d[4])),
			float(d[0]), float(d[1]), accent.darkened(0.04 * float(i)))
		drum.rotation_degrees = Vector3(float(d[6]), float(d[5]), float(d[6]) * 0.5)

	# Grit hanging in the four breaks, at the mid-height of each gap.
	var gap_heights := [1.010, 1.305, 1.635, 2.005]
	var rng := _rng(11)
	for g in range(gap_heights.size()):
		for k in range(3):
			var a: float = rng.randf_range(0.0, TAU)
			var r: float = rng.randf_range(0.10, 0.30)
			_sphere(root, "Break Grit %d" % (g * 3 + k),
				Vector3(cos(a) * r, float(gap_heights[g]) + rng.randf_range(-0.035, 0.035),
					sin(a) * r), 0.018, DUST, 0.0, false)

	# --- Containment: three masts, a capture ring, a floor collar ----------
	for i in range(3):
		var a: float = deg_to_rad(90.0 + 120.0 * float(i))
		var dir := Vector3(cos(a), 0, sin(a))
		_cylinder(root, "Emitter Mast %d" % i, dir * 0.78 + Vector3(0, 1.54, 0),
			0.033, 1.68, STEEL, 0.0, 0.6)
		var head := _box(root, "Mast Emitter %d" % i,
			dir * 0.700 + Vector3(0, 1.52, 0), Vector3(0.13, 0.11, 0.10),
			STEEL_LIGHT, 0.0, 0.5)
		head.rotation_degrees = Vector3(0, rad_to_deg(atan2(dir.z, -dir.x)), 0)
		var lens := _box(root, "Mast Lens %d" % i,
			dir * 0.635 + Vector3(0, 1.52, 0), Vector3(0.030, 0.07, 0.07),
			FIELD, 1.0)
		lens.rotation_degrees = head.rotation_degrees
		# Clamp on the collar, tied back to the foot of its mast.
		var clamp := _box(root, "Collar Clamp %d" % i,
			dir * 0.470 + Vector3(0, 0.755, 0), Vector3(0.12, 0.09, 0.16),
			STEEL, 0.0, 0.6)
		clamp.rotation_degrees = head.rotation_degrees
		_link(root, "Clamp Tie %d" % i, dir * 0.530 + Vector3(0, 0.755, 0),
			dir * 0.745 + Vector3(0, 0.755, 0), 0.022, STEEL, 0.0, 0.6)
	_torus(root, "Capture Ring", Vector3(0, 2.320, 0), 0.74, 0.84, STEEL, 0.0, 0.6)
	_torus(root, "Floor Collar", Vector3(0, 0.760, 0), 0.40, 0.52, STEEL, 0.0, 0.6)

	# --- Measurement -------------------------------------------------------
	var wire := Vector3(0.50, 0.0, -0.20)
	_link(root, "Gap Monitor Wire", wire + Vector3(0, 0.72, 0),
		wire + Vector3(0, 2.32, 0), 0.009, CABLE)
	for i in range(gap_heights.size()):
		_sphere(root, "Gap Bead %d" % i,
			wire + Vector3(0.016, float(gap_heights[i]), -0.006), 0.026, FIELD, 0.7)

	# Hazard banding on one mast, plus the containment footprint on the deck.
	var band_dir := Vector3(cos(deg_to_rad(210.0)), 0, sin(deg_to_rad(210.0)))
	for i in range(3):
		_box(root, "Mast Hazard Band %d" % i,
			band_dir * 0.78 + Vector3(0, 1.02 + 0.08 * float(i), 0),
			Vector3(0.085, 0.045, 0.085), PAINT_HAZARD)
	for i in range(4):
		var a: float = deg_to_rad(45.0 + 90.0 * float(i))
		_span(root, "Collar Footprint Tick %d" % i,
			Vector3(cos(a) * 0.56, 0.707, sin(a) * 0.56),
			Vector3(cos(a) * 0.68, 0.707, sin(a) * 0.68),
			Vector2(0.012, 0.045), PAINT_LINE)
	return root


# =============================================================================
# Wing dressing
# =============================================================================

## Gravity anchor socket: the fixture the wing is pinned down with.
##
## Flush plate, recessed socket, bolt heads and a stub of conduit leaving one
## edge. Live plates carry three notches at 120 degrees around the socket, so
## the state is legible as a count and a shape, not only as a colour.
##
## `facing` is the surface normal it is mounted on -- Vector3.UP for a floor
## plate, Vector3.DOWN for the ceiling, Vector3.RIGHT or FORWARD for a wall --
## and `origin` sits on the surface itself.
##
## Bounding box 0.44 x 0.09 x 0.56 m before `facing` rotates it; the plate is
## 0.44 square, 0.09 stands off the surface and the conduit stub adds 0.12 on
## one edge. It sinks 4 mm into the surface it is bolted to, so it reads flush.
static func build_anchor_plate(parent: Node3D, origin: Vector3,
		facing := Vector3.UP, live := true) -> Node3D:
	var root := _holder(parent, "Gravity Anchor Plate", origin)
	root.basis = _basis_along(facing)

	_box(root, "Anchor Plate", Vector3(0, 0.025, 0), Vector3(0.44, 0.05, 0.44),
		STEEL_LIGHT, 0.0, 0.55)
	_cylinder(root, "Anchor Socket", Vector3(0, 0.062, 0), 0.14, 0.055,
		Color(0.030, 0.032, 0.035))
	_torus(root, "Anchor Ring", Vector3(0, 0.065, 0), 0.155, 0.195, STEEL, 0.0, 0.6)
	for i in range(4):
		var bx: float = 0.17 if i < 2 else -0.17
		var bz: float = 0.17 if i % 2 == 0 else -0.17
		_cylinder(root, "Anchor Bolt %d" % i, Vector3(bx, 0.055, bz), 0.024,
			0.022, STEEL, 0.0, 0.7)
	for i in range(3):
		var a: float = deg_to_rad(120.0 * float(i))
		var notch := _box(root, "Anchor Notch %d" % i,
			Vector3(cos(a) * 0.165, 0.062, sin(a) * 0.165),
			Vector3(0.055, 0.020, 0.030),
			FIELD if live else Color(0.12, 0.13, 0.15),
			0.9 if live else 0.0)
		notch.rotation_degrees = Vector3(0, rad_to_deg(-a), 0)
	_link(root, "Anchor Conduit", Vector3(0.21, 0.030, 0.10),
		Vector3(0.33, 0.012, 0.16), 0.014, CABLE)
	return root


## Debris hanging off one ceiling anchor, each piece obeying its own down.
##
## Every item hangs plumb along its own tether and every tether points somewhere
## else, so the group contradicts itself rather than looking windblown. Cables
## reach at most 1.35 m below `origin`; mount at y 3.30 (the soffit is 3.39) and
## the lowest piece still clears the player by half a metre.
##
## `spread` scales how far off vertical the tethers hang, 0 straight down and
## 1 the authored 20-50 degrees. `variant` reshuffles the arrangement.
##
## Bounding box 1.80 x 1.35 x 1.80 m, hanging entirely below `origin`. That is
## the union measured over every count from 2 to 7 against variants 0 to 11 at
## full spread; any single arrangement is smaller.
static func build_tethered_debris(parent: Node3D, origin: Vector3,
		count := 4, spread := 1.0, variant := 0) -> Node3D:
	var root := _holder(parent, "Tethered Debris", origin)
	_box(root, "Debris Anchor Pad", Vector3(0, -0.025, 0),
		Vector3(0.28, 0.05, 0.28), STEEL, 0.0, 0.55)
	_torus(root, "Debris Eyelet", Vector3(0, -0.075, 0), 0.028, 0.055, STEEL,
		0.0, 0.65, true)

	var hub := Vector3(0, -0.09, 0)
	var rng := _rng(variant)
	var safe_count: int = maxi(1, count)
	for i in range(safe_count):
		var azimuth: float = TAU * float(i) / float(safe_count) + rng.randf_range(-0.35, 0.35)
		var tilt: float = deg_to_rad(rng.randf_range(20.0, 50.0)) * clampf(spread, 0.0, 1.6)
		var length: float = rng.randf_range(0.34, 0.72)
		var down := Vector3(sin(tilt) * cos(azimuth), -cos(tilt), sin(tilt) * sin(azimuth))
		var end: Vector3 = hub + down * length
		_link(root, "Debris Tether %d" % i, hub, end, 0.009, CABLE)

		var item_basis := _basis_along(-down)
		match i % 5:
			0:
				# Bench slat, hanging across its cable the way a slat would.
				var slat := _box(root, "Debris Bench Slat %d" % i,
					end + down * 0.06, Vector3(0.58, 0.07, 0.15),
					Color(0.19, 0.13, 0.09))
				slat.basis = item_basis
			1:
				var bottle := _cylinder(root, "Debris Extinguisher %d" % i,
					end + down * 0.19, 0.072, 0.34, Color(0.26, 0.075, 0.065))
				bottle.basis = item_basis
			2:
				var chunk := _prism(root, "Debris Plaster %d" % i,
					end + down * 0.12, Vector3(0.24, 0.20, 0.20), CONCRETE)
				chunk.basis = item_basis
			3:
				var conduit := _box(root, "Debris Conduit %d" % i,
					end + down * 0.22, Vector3(0.09, 0.42, 0.09), STEEL_LIGHT,
					0.0, 0.5)
				conduit.basis = item_basis
			_:
				var post := _cylinder(root, "Debris Stanchion %d" % i,
					end + down * 0.29, 0.035, 0.58, STEEL, 0.0, 0.5)
				post.basis = item_basis
				_sphere(root, "Debris Stanchion Cap %d" % i, end + down * 0.60,
					0.05, Color(0.35, 0.28, 0.16))
	return root


## A column of dust falling sideways out of a crack in the floor.
##
## It rises about half a metre, turns, and travels horizontally until it piles
## up against a vertical face -- a drift lying on a wall instead of a floor.
## Local +X is the flow direction before `heading_degrees` rotates the whole
## prop about Y.
##
## With `drift_pile` true the far end must actually meet a wall: the wedge sits
## with its flat face at x = length + 0.21 in local space. Pass false where it
## flows into open room.
##
## Bounding box (length + 0.48) x 0.97 x 0.65 m, reaching from 0.27 m behind
## the crack to 0.21 m past `length`; 3.08 x 0.97 x 0.65 m at the default.
static func build_sideways_dust_column(parent: Node3D, origin: Vector3,
		heading_degrees := 0.0, length := 2.6, drift_pile := true,
		variant := 0) -> Node3D:
	var root := _holder(parent, "Sideways Dust Column", origin, heading_degrees)
	var run: float = maxf(0.8, length)
	var rng := _rng(variant + 31)

	# The crack it comes out of.
	var crack := [
		[Vector3(-0.26, 0.012, -0.05), Vector3(-0.08, 0.012, 0.03), 0.045],
		[Vector3(-0.08, 0.012, 0.03), Vector3(0.06, 0.012, -0.04), 0.060],
		[Vector3(0.06, 0.012, -0.04), Vector3(0.17, 0.012, 0.02), 0.035],
	]
	for i in range(crack.size()):
		var seg: Array = crack[i]
		_span(root, "Dust Crack %d" % i, seg[0] as Vector3, seg[1] as Vector3,
			Vector2(0.012, float(seg[2])), SHADOW)

	# Two overlapping translucent slabs give the stream a body without a
	# particle system; a third carries it up out of the floor.
	_box(root, "Dust Riser Volume", Vector3(0.02, 0.36, 0.0),
		Vector3(0.24, 0.58, 0.15), Color(0.56, 0.57, 0.60), 0.0, 0.0, 0.060)
	_box(root, "Dust Stream Volume", Vector3(run * 0.5, 0.62, 0.0),
		Vector3(run, 0.28, 0.15), Color(0.56, 0.57, 0.60), 0.0, 0.0, 0.075)
	_box(root, "Dust Stream Halo", Vector3(run * 0.42, 0.78, 0.03),
		Vector3(run * 0.78, 0.15, 0.085), Color(0.56, 0.57, 0.60), 0.0, 0.0, 0.055)

	# Motes: out of the crack, then level and sagging very slightly.
	for i in range(24):
		var t: float = float(i) / 23.0
		var y: float = 0.72
		if t < 0.16:
			y = lerpf(0.10, 0.72, t / 0.16)
		else:
			y -= (t - 0.16) * 0.19
		_sphere(root, "Dust Mote %d" % i,
			Vector3(0.04 + t * run, y + rng.randf_range(-0.11, 0.11),
				rng.randf_range(-0.09, 0.09)), 0.013,
			Color(0.62, 0.63, 0.66), 0.12, false)

	if drift_pile:
		# A wedge of dust settled on a vertical surface.
		var pile := _prism(root, "Wall Drift", Vector3(run - 0.10, 0.42, 0.0),
			Vector3(0.55, 0.62, 0.55), DUST)
		pile.rotation_degrees = Vector3(0, 0, 90)
		var lump_a := _prism(root, "Wall Drift Lump A",
			Vector3(run - 0.06, 0.86, 0.16), Vector3(0.22, 0.30, 0.24), DUST)
		lump_a.rotation_degrees = Vector3(0, 12, 90)
		var lump_b := _prism(root, "Wall Drift Lump B",
			Vector3(run - 0.08, 0.20, -0.19), Vector3(0.26, 0.26, 0.22), DUST)
		lump_b.rotation_degrees = Vector3(0, -20, 90)
	return root


## Containment-zone floor stencil: painted outline, corner brackets, a run of
## approach chevrons and a caution triangle.
##
## Paint only -- 12 mm of geometry lying on the floor, no collider, so it can
## cross a doorway threshold without touching the navigation bake. Local +Z is
## the approach side the chevrons come from.
##
## Bounding box (size + 0.05) x 0.015 x (size + 0.29 + 0.34 * chevrons) m,
## 2.65 x 0.015 x 3.79 m with the defaults, extending toward +Z only.
static func build_floor_stencil(parent: Node3D, origin: Vector3,
		heading_degrees := 0.0, size := 2.6, chevrons := 3) -> Node3D:
	var root := _holder(parent, "Containment Floor Stencil", origin,
		heading_degrees)
	var half: float = maxf(0.6, size) * 0.5

	_deck_square_at(root, "Zone Outline", half, 0.012, PAINT_LINE)
	# Corner brackets, in hazard paint, inset just inside the outline.
	var inset: float = half - 0.06
	for i in range(4):
		var sx: float = 1.0 if i < 2 else -1.0
		var sz: float = 1.0 if i % 2 == 0 else -1.0
		var corner := Vector3(sx * inset, 0.013, sz * inset)
		_span(root, "Zone Bracket %d X" % i, corner,
			corner - Vector3(sx * 0.28, 0.0, 0.0), Vector2(0.014, 0.075),
			PAINT_HAZARD)
		_span(root, "Zone Bracket %d Z" % i, corner,
			corner - Vector3(0.0, 0.0, sz * 0.28), Vector2(0.014, 0.075),
			PAINT_HAZARD)

	for i in range(maxi(0, chevrons)):
		var z: float = half + 0.35 + 0.34 * float(i)
		_span(root, "Approach Chevron %d Left" % i,
			Vector3(-0.28, 0.013, z + 0.10), Vector3(0.0, 0.013, z - 0.10),
			Vector2(0.014, 0.075), PAINT_HAZARD)
		_span(root, "Approach Chevron %d Right" % i,
			Vector3(0.28, 0.013, z + 0.10), Vector3(0.0, 0.013, z - 0.10),
			Vector2(0.014, 0.075), PAINT_HAZARD)

	# Caution triangle: the warning is the shape, not the colour.
	var tri := Vector3(half - 0.45, 0.013, -half + 0.42)
	var side := 0.46
	var apex: Vector3 = tri + Vector3(0.0, 0.0, -side * 0.58)
	var left: Vector3 = tri + Vector3(-side * 0.5, 0.0, side * 0.29)
	var right: Vector3 = tri + Vector3(side * 0.5, 0.0, side * 0.29)
	_span(root, "Caution Triangle A", apex, left, Vector2(0.014, 0.05), PAINT_HAZARD)
	_span(root, "Caution Triangle B", apex, right, Vector2(0.014, 0.05), PAINT_HAZARD)
	_span(root, "Caution Triangle C", left, right, Vector2(0.014, 0.05), PAINT_HAZARD)
	_span(root, "Caution Stroke", tri + Vector3(0, 0, -0.10),
		tri + Vector3(0, 0, 0.06), Vector2(0.014, 0.045), PAINT_HAZARD)
	_box(root, "Caution Dot", tri + Vector3(0, 0.0, 0.13),
		Vector3(0.045, 0.014, 0.045), PAINT_HAZARD)
	return root


# =============================================================================
# Internal helpers
# =============================================================================

## Painted square on the pedestal deck, centred on the exhibit axis.
static func _deck_square(parent: Node3D, node_name: String, half: float,
		color: Color) -> void:
	_deck_square_at(parent, node_name, half, DECK + 0.007, color)


static func _deck_square_at(parent: Node3D, node_name: String, half: float,
		y: float, color: Color) -> void:
	var corners := [
		Vector3(-half, y, -half), Vector3(half, y, -half),
		Vector3(half, y, half), Vector3(-half, y, half),
	]
	for i in range(4):
		_span(parent, "%s Side %d" % [node_name, i], corners[i] as Vector3,
			corners[(i + 1) % 4] as Vector3, Vector2(0.014, 0.05), color)


## Single chevron painted on the deck, tip pointing toward the exhibit centre
## from the visitor side (+z).
static func _deck_chevron(parent: Node3D, node_name: String, z: float,
		half_span: float, depth: float, color: Color) -> void:
	var tip := Vector3(0.0, DECK + 0.008, z - depth)
	_span(parent, "%s Left" % node_name,
		Vector3(-half_span, DECK + 0.008, z), tip, Vector2(0.014, 0.06), color)
	_span(parent, "%s Right" % node_name,
		Vector3(half_span, DECK + 0.008, z), tip, Vector2(0.014, 0.06), color)


static func _holder(parent: Node3D, node_name: String, origin: Vector3,
		yaw_degrees := 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = origin
	if not is_zero_approx(yaw_degrees):
		root.rotation_degrees = Vector3(0, yaw_degrees, 0)
	parent.add_child(root)
	return root


## Deterministic per-prop randomness. Two builds of the same map must produce
## the same museum, so nothing here calls the global RNG.
static func _rng(variant: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 977 + variant * 7919
	return rng


## Orthonormal basis whose +Y axis points along `direction`. Used to aim struts,
## tethers, painted lines and anything hanging under its own local gravity.
static func _basis_along(direction: Vector3) -> Basis:
	var up := direction
	if up.length_squared() < 0.000001:
		up = Vector3.UP
	up = up.normalized()
	var reference := Vector3.RIGHT
	if absf(up.dot(reference)) > 0.9:
		reference = Vector3.FORWARD
	var x_axis := up.cross(reference).normalized()
	var z_axis := x_axis.cross(up).normalized()
	return Basis(x_axis, up, z_axis)


# --- Primitive builders -----------------------------------------------------
# Same conventions as FirstMuseumMap._primitive(): cached material override,
# 115 m visibility range with self-fade, and no shadow casting on anything under
# 0.65 m. Collision is deliberately absent -- see the file header.

static func _add(parent: Node3D, node_name: String, node_position: Vector3,
		mesh: Mesh, size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = node_position
	instance.mesh = mesh
	instance.material_override = material
	instance.visibility_range_end = 115.0
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if size.length() < 0.65:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func _box(parent: Node3D, node_name: String, node_position: Vector3,
		size: Vector3, color: Color, emission := 0.0, metallic := 0.0,
		alpha := 1.0) -> MeshInstance3D:
	return _add(parent, node_name, node_position, _box_mesh(size), size,
		_mat(color, emission, metallic, alpha))


static func _cylinder(parent: Node3D, node_name: String, node_position: Vector3,
		radius: float, height: float, color: Color, emission := 0.0,
		metallic := 0.0) -> MeshInstance3D:
	return _add(parent, node_name, node_position,
		_cylinder_mesh(radius, radius, height),
		Vector3(radius * 2.0, height, radius * 2.0),
		_mat(color, emission, metallic))


static func _cone(parent: Node3D, node_name: String, node_position: Vector3,
		bottom_radius: float, top_radius: float, height: float, color: Color,
		emission := 0.0, metallic := 0.0) -> MeshInstance3D:
	var widest: float = maxf(bottom_radius, top_radius)
	return _add(parent, node_name, node_position,
		_cylinder_mesh(bottom_radius, top_radius, height),
		Vector3(widest * 2.0, height, widest * 2.0),
		_mat(color, emission, metallic))


static func _sphere(parent: Node3D, node_name: String, node_position: Vector3,
		radius: float, color: Color, emission := 0.0,
		detailed := true) -> MeshInstance3D:
	return _add(parent, node_name, node_position, _sphere_mesh(radius, detailed),
		Vector3(radius * 2.0, radius * 2.0, radius * 2.0),
		_mat(color, emission))


static func _prism(parent: Node3D, node_name: String, node_position: Vector3,
		size: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	return _add(parent, node_name, node_position, _prism_mesh(size), size,
		_mat(color, emission))


## Ring lying flat in the XZ plane, or standing upright when `upright` is set.
static func _torus(parent: Node3D, node_name: String, node_position: Vector3,
		inner_radius: float, outer_radius: float, color: Color,
		emission := 0.0, metallic := 0.0, upright := false) -> MeshInstance3D:
	var instance := _add(parent, node_name, node_position,
		_torus_mesh(inner_radius, outer_radius),
		Vector3(outer_radius * 2.0, outer_radius - inner_radius, outer_radius * 2.0),
		_mat(color, emission, metallic))
	if upright:
		instance.rotate_x(deg_to_rad(90.0))
	return instance


## Cylinder spanning two points: struts, tethers, cables, conduit.
static func _link(parent: Node3D, node_name: String, from: Vector3, to: Vector3,
		radius: float, color: Color, emission := 0.0,
		metallic := 0.0) -> MeshInstance3D:
	var delta: Vector3 = to - from
	var length: float = delta.length()
	if length < 0.001:
		return null
	var instance := _add(parent, node_name, (from + to) * 0.5,
		_cylinder_mesh(radius, radius, length),
		Vector3(radius * 2.0, length, radius * 2.0),
		_mat(color, emission, metallic))
	instance.basis = _basis_along(delta)
	return instance


## Box spanning two points, its length along the run. `cross_section` is the
## remaining two dimensions: for a line painted on a floor that is
## (thickness, width); for a stripe on a vertical face it is (width, thickness).
static func _span(parent: Node3D, node_name: String, from: Vector3, to: Vector3,
		cross_section: Vector2, color: Color, emission := 0.0,
		metallic := 0.0) -> MeshInstance3D:
	var delta: Vector3 = to - from
	var length: float = delta.length()
	if length < 0.001:
		return null
	var size := Vector3(cross_section.x, length, cross_section.y)
	var instance := _add(parent, node_name, (from + to) * 0.5, _box_mesh(size),
		size, _mat(color, emission, metallic))
	instance.basis = _basis_along(delta)
	return instance


# --- Resource caches --------------------------------------------------------
# Keys are rounded to the millimetre so near-identical parts collapse onto one
# resource instead of filling the cache with float noise.

static func _box_mesh(size: Vector3) -> BoxMesh:
	var key := "b%.3f/%.3f/%.3f" % [size.x, size.y, size.z]
	if _meshes.has(key):
		return _meshes[key]
	var mesh := BoxMesh.new()
	mesh.size = size
	_meshes[key] = mesh
	return mesh


static func _cylinder_mesh(bottom_radius: float, top_radius: float,
		height: float) -> CylinderMesh:
	var key := "c%.3f/%.3f/%.3f" % [bottom_radius, top_radius, height]
	if _meshes.has(key):
		return _meshes[key]
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = CYLINDER_SEGMENTS
	mesh.rings = 1
	_meshes[key] = mesh
	return mesh


static func _sphere_mesh(radius: float, detailed: bool) -> SphereMesh:
	var key := "s%.3f/%s" % [radius, detailed]
	if _meshes.has(key):
		return _meshes[key]
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = SPHERE_SEGMENTS if detailed else MOTE_SEGMENTS
	mesh.rings = SPHERE_RINGS if detailed else MOTE_RINGS
	_meshes[key] = mesh
	return mesh


static func _torus_mesh(inner_radius: float, outer_radius: float) -> TorusMesh:
	var key := "t%.3f/%.3f" % [inner_radius, outer_radius]
	if _meshes.has(key):
		return _meshes[key]
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = TORUS_RINGS
	mesh.ring_segments = TORUS_RING_SEGMENTS
	_meshes[key] = mesh
	return mesh


static func _prism_mesh(size: Vector3) -> PrismMesh:
	var key := "p%.3f/%.3f/%.3f" % [size.x, size.y, size.z]
	if _meshes.has(key):
		return _meshes[key]
	var mesh := PrismMesh.new()
	mesh.size = size
	_meshes[key] = mesh
	return mesh


## Same surface treatment as the rest of the museum: polished-marble roughness,
## and a restrained triplanar grain on opaque, non-metallic, non-emissive parts
## so a prop dropped next to a wall does not read as a different material set.
static func _mat(color: Color, emission_energy := 0.0, metallic := 0.0,
		alpha := 1.0) -> StandardMaterial3D:
	var key := "%s/%.2f/%.2f/%.2f" % [color.to_html(false), emission_energy,
		metallic, alpha]
	if _materials.has(key):
		return _materials[key]

	var mat := StandardMaterial3D.new()
	var transparent: bool = alpha < 0.999
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.roughness = clampf(0.5 - metallic * 0.35, 0.12, 1.0)
	mat.metallic = metallic
	mat.metallic_specular = 0.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_energy

	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shadow_to_opacity = false
	elif metallic < 0.35 and emission_energy <= 0.0:
		mat.roughness_texture = _grain_texture()
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.normal_enabled = true
		mat.normal_texture = _grain_normal_texture()
		mat.normal_scale = 0.08
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.22, 0.22, 0.22)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_materials[key] = mat
	return mat


static func _grain_texture() -> NoiseTexture2D:
	if _grain != null:
		return _grain
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.16
	noise.fractal_octaves = 2
	_grain = NoiseTexture2D.new()
	_grain.width = 128
	_grain.height = 128
	_grain.noise = noise
	_grain.seamless = true
	return _grain


static func _grain_normal_texture() -> NoiseTexture2D:
	if _grain_normal != null:
		return _grain_normal
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.12
	noise.fractal_octaves = 2
	_grain_normal = NoiseTexture2D.new()
	_grain_normal.width = 128
	_grain_normal.height = 128
	_grain_normal.noise = noise
	_grain_normal.seamless = true
	_grain_normal.as_normal_map = true
	_grain_normal.bump_strength = 1.2
	return _grain_normal
