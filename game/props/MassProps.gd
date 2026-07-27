@tool
class_name MassProps
extends RefCounted
## Procedural prop set for Mass Wing D — the exhibits and the wing dressing.
##
## Self-contained by design: nothing outside this file is imported, so it can be
## dropped into the map without waiting on any other module. Every builder takes
## `(parent, origin, ...)` and returns the root Node3D it parented, so a call
## site is one line:
##
##     MassProps.build_superheavy_sphere(parent, Vector3(52, 0, -3))
##
## `origin` is a FLOOR point. The museum floor slab is centred at y = -0.08 with
## height 0.16, so its top surface is exactly y = 0.0 and every local coordinate
## in here is measured up from there. Rooms are WALL_HEIGHT 3.4 m tall and the
## ceiling slab's soffit is at y = 3.39; the two overhead builders top out at
## 3.12 (gantry) and 3.345 (chain anchor) so neither punches through it.
##
##
## WHAT THE WING IS SUPPOSED TO SAY
##
## Wing D exhibits mass, and the museum is losing the argument. Every prop here
## is a piece of structure that has already failed: a plinth split into wedges by
## the sphere standing on it, a bearing plate that sagged under something the
## size of a brick, a pendulum hanging taut and off-axis with nothing pulling it,
## a hoist holding an absence. The deformation is the exhibit. Detail is
## deliberately thin — at night, with the lights failing, the player reads
## silhouette and negative space, so the heavy objects are the darkest thing in
## any room (DENSE, luminance 0.004) and register as holes punched in the light
## rather than as objects.
##
## Nothing here moves, flickers or pulses, so there is nothing for
## SettingsManager.reduced_flashes to switch off. That is a decision, not an
## omission: a wing about mass is more frightening still than animated, and the
## project bans decorative motion. If a later round animates any of it, the
## reduced-flashes gate has to be added at the same time.
##
##
## COLLISION, AND WHY MOST OF THIS HAS NONE
##
## The Curator's navmesh bakes from STATIC COLLIDERS only (NavigationMesh with
## PARSED_GEOMETRY_STATIC_COLLIDERS, agent_radius 0.45, agent_max_climb 0.4), and
## the props here are parented under the map root, which is the bake's source
## group. A collider added by this file is therefore a hole in the Curator's
## navmesh, eroded 0.45 m on every side. So:
##
##   * only things a player can genuinely walk into are solid — plinths, frame
##     legs, gantry legs, the pendulum bob, the hoist block;
##   * everything at floor level (deck plates, cracks, trench, chevrons, shims)
##     is collider-free, which also makes it navmesh-transparent and safe to run
##     straight through a doorway;
##   * everything overhead is collider-free, so nothing bakes a low-ceiling
##     span;
##   * DOOR_GAP is 1.8 m and the bake erodes 0.45 m per side, leaving 0.9 m of
##     navmesh through a door. Keep the SOLID footprint of any builder at least
##     1.6 m clear of a doorway centre line. The bounding boxes below are stated
##     twice for that reason: the visual box, and the smaller solid box.
##
## Where a box collider would misrepresent the shape, the collider follows the
## mesh (SphereShape3D for the superheavy sphere, CylinderShape3D for the
## pendulum bob). Anything below the same thresholds the map uses
## (x/z >= 0.12, y >= 0.08) gets no collider at all whatever `solid` says.
##
##
## BOUNDING BOXES
##
## Measured, not estimated: every figure below was read back off the built tree
## by transforming each mesh's own AABB into the returned root's space, at
## default arguments. X x Y x Z in metres, relative to `origin`.
##
##   builder                  visual box            solid box
##   build_superheavy_sphere  3.27 x 1.57 x 3.27    1.84 x 1.54 x 1.84
##   build_dense_ingot        1.85 x 1.03 x 2.12    1.34 x 0.76 x 1.32
##   build_mass_pendulum      3.06 x 3.10 x 0.86    2.80 x 2.92 x 0.60
##   build_buckled_deck       6.71 x 0.35 x 6.71    none
##   build_load_frame         3.66 x 0.27 x 3.95    none by default
##   build_crane_gantry       5.90 x 3.12 x 2.36    5.60 x 2.86 x 2.10
##   build_tension_chains     2.13 x 3.35 x 2.22    none
##
## A solid box is the envelope of the colliders, not a solid volume: the
## pendulum's 2.80 x 2.92 x 0.60 is two 0.16 m columns and a 0.60 m bob with
## open floor between them, and the gantry's 5.60 x 2.86 x 2.10 is four 0.20 m
## legs plus one hoist block. Plan doorway clearance against the individual
## pieces called out in each builder's own comment, not against these envelopes.
##
## Y is measured from the floor, and three builders deliberately go below it: the
## superheavy sphere's dish plates dip to -0.117 and the buckled deck's settled
## plates to -0.076, so their low edges vanish into the slab instead of ending in
## a visible cut line, and the pendulum's west leg is sunk 0.02 m because it is
## the one that is failing.
##
## Every exhibit builder brings its own plinth. They replace what stands in an
## exhibit slot, pedestal included; they are not dressing to add on top of one.
##
##
## COST
##
## The map already builds roughly 1270 MeshInstance3D nodes synchronously in one
## frame, so these stay cheap. Mesh segment counts are set explicitly (the engine
## defaults — 64 radial segments on a cylinder, 64x32 on a torus — are wasteful
## at this scale) and every material is shared through a static cache keyed on
## its parameters: all seven builders together allocate 13 StandardMaterial3D and
## two 128 px noise textures, once per process.
##
##   builder                  nodes   meshes   triangles   colliders
##   build_superheavy_sphere     27       26         828           6
##   build_dense_ingot           20       19         228           3
##   build_mass_pendulum         26       25         544           3
##   build_buckled_deck          18       17         204           0
##   build_load_frame            28       27         468           0
##   build_crane_gantry          29       28         792           5
##   build_tension_chains        30       29         708           0
##
## All seven at once: 178 nodes and 3772 triangles, against a map that already
## carries 1173 meshes.

# --- Palette -----------------------------------------------------------------
#
# The heavy things are darker than anything else in the museum. Wing D's floor is
# Color(0.76, 0.72, 0.63) and its walls are Color(0.87, 0.86, 0.83), so DENSE
# against either is a silhouette with no readable interior — a shape the eye
# cannot resolve, which is the whole point. Nothing emits: the wing's story is
# that the lights are failing.
#
# CAUTION is the only colour carrying a warning, and it never carries it alone —
# it is painted as repeated diagonal chevrons, so the meaning survives both a
# monochrome CRT feed and any colour vision deficiency. It is not text and never
# sits under text, so the 4.5:1 text rule does not apply to it; for the record it
# measures 2.05:1 against the concrete it is painted on, which is contrast enough
# for a large shape.

## Impossible mass. Near-black, faintly metallic, deliberately unreadable.
const DENSE := Color(0.042, 0.041, 0.048)
## Structural steel: gantry rails, bearing plates, load-frame beams.
const STEEL := Color(0.145, 0.150, 0.160)
## Older, unpainted steel: legs, chains, deck plates.
const STEEL_WORN := Color(0.095, 0.098, 0.105)
## Plinth and pad concrete.
const CONCRETE := Color(0.330, 0.320, 0.295)
## Broken concrete, shims, rubble.
const CONCRETE_DARK := Color(0.185, 0.180, 0.165)
## The inside of a crack. Darker than DENSE so cracks read even across a mass.
const VOID := Color(0.012, 0.012, 0.016)
## Corrosion on bolt heads, turnbuckles and packing shims.
const RUST := Color(0.245, 0.135, 0.075)
## Faded floor hazard paint. Always applied as chevrons, never as a flat field.
const CAUTION := Color(0.560, 0.500, 0.330)

# --- Mesh resolution ---------------------------------------------------------
const CYL_SEGMENTS := 12
const SPHERE_RADIAL := 16
const SPHERE_RINGS := 8
const TORUS_RINGS := 18
const TORUS_RING_SEGMENTS := 6

# Mirrors FirstMuseumMap._primitive: a prop smaller than this in any horizontal
# axis, or flatter than 0.08, never gets a collider however it is flagged.
const MIN_COLLIDER_SPAN := 0.12
const MIN_COLLIDER_HEIGHT := 0.08

## Shared across every call in the process. Keyed on the material parameters, so
## two builders asking for the same steel get the same resource.
static var _materials: Dictionary = {}
static var _noise_texture: NoiseTexture2D = null
static var _bump_texture: NoiseTexture2D = null


# =============================================================================
# EXHIBITS
# =============================================================================


## Superheavy sphere: a mass that has sunk into the plinth it stands on and split
## it into wedges, while the floor around it dishes inward.
##
## The lie the shape tells is geometric and deliberate. The sphere's widest
## circle sits at y = 0.831, well above the plinth top at 0.552, so the circle
## where it crosses that top is 1.11 m across while the ball itself is 1.24 m —
## 13 cm wider than the hole it is standing in. It cannot have been lowered in
## and it cannot be lifted out. Read at a glance it is a dark sphere on a broken
## plinth; read for a second longer it stops making sense.
##
## Footprint scales with `radius`: the visual box is 5.3 x radius on a side and
## the solid box 3.0 x radius. At the default 0.62 that is 3.27 x 1.57 x 3.27 m
## visual (y -0.117 to 1.451) and 1.84 x 1.54 x 1.84 m solid — the five plinth
## wedges, whose tilt swings their corners a little past the nominal drum, plus
## the sphere. 27 nodes, 26 meshes, 828 triangles, 6 colliders.
static func build_superheavy_sphere(parent: Node3D, origin: Vector3,
		radius := 0.62, yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, "Superheavy Mass", origin, yaw_deg)

	var plinth_h: float = radius * 0.89       # 0.552
	var plinth_r: float = radius * 1.37       # 0.849
	var sink: float = radius * 0.55           # 0.341 of the ball is below the top
	var ball_y: float = plinth_h + radius - sink

	# Black core first, so the gaps between the split wedges look into nothing
	# rather than onto the pale museum floor.
	_cyl(root, "Plinth Core", Vector3(0, plinth_h * 0.48, 0),
		radius * 0.49, plinth_h * 0.96, VOID, 0.0, false)

	# Five wedges of what used to be one drum of radius plinth_r. Each has tipped
	# outward and settled by a different amount; the uneven settle is what stops
	# it reading as a decorative five-piece pedestal.
	var wedge_r: float = plinth_r - radius * 0.45
	for i in range(5):
		var a: float = TAU * float(i) / 5.0 + 0.24
		var tilt: float = 2.5 + float(i) * 1.6
		_box(root, "Plinth Wedge %d" % i,
			Vector3(sin(a) * wedge_r, plinth_h * 0.5 - float(i) * 0.012,
				cos(a) * wedge_r),
			Vector3(radius * 1.16, plinth_h, radius * 0.90),
			CONCRETE, 0.0, true, _yaw(rad_to_deg(a)) * _pitch(tilt))

	# The mass itself. A real sphere collider: a box hull here would let the
	# player stand on corners of empty air a third of a metre out from the
	# surface, on the one prop in the museum whose silhouette is the exhibit.
	var ball := _ball(root, "Superheavy Sphere", Vector3(0, ball_y, 0), radius,
		DENSE, 0.50, false)
	_shape(ball, "Superheavy Sphere", SphereShape3D.new(), radius)

	# Contact seam where the ball crosses the plinth top. Cheap, and it is what
	# sells "pressed into" over "resting on".
	_ring(root, "Contact Seam", Vector3(0, plinth_h, 0),
		radius * 0.86, radius * 0.99, VOID)

	# Eight floor plates funnelling inward. Each is tilted so its inner edge
	# drops below y = 0 and vanishes into the slab, which reads as the floor
	# being drawn down rather than as eight loose plates.
	var dish_r: float = radius * 1.87
	for i in range(8):
		var a: float = TAU * float(i) / 8.0
		_box(root, "Dish Plate %d" % i,
			Vector3(sin(a) * dish_r, -0.02, cos(a) * dish_r),
			Vector3(radius * 1.00, 0.055, radius * 1.53),
			CONCRETE, 0.0, false, _yaw(rad_to_deg(a)) * _pitch(-8.5))

	# Cracks running out past the plates. Uneven lengths and off-radial angles;
	# a symmetric star would read as ornament.
	var crack_len := [0.95, 0.62, 1.05, 0.74, 0.88, 0.58]
	for i in range(crack_len.size()):
		var a: float = TAU * float(i) / 6.0 + 0.41
		var length: float = float(crack_len[i]) * radius * 1.61
		var at: float = radius * 1.20 + length * 0.5
		_box(root, "Floor Crack %d" % i,
			Vector3(sin(a) * at, 0.012, cos(a) * at),
			Vector3(0.05, 0.014, length), VOID, 0.0, false,
			_yaw(rad_to_deg(a) + 7.0 * float(i % 3) - 7.0))

	# Spall thrown clear of the plinth.
	var rubble := [Vector2(1.24, 0.7), Vector2(1.61, 2.4),
		Vector2(1.05, 3.9), Vector2(1.48, 5.2)]
	for i in range(rubble.size()):
		var spec: Vector2 = rubble[i]
		var at: float = spec.x * radius
		_box(root, "Spall %d" % i,
			Vector3(sin(spec.y) * at, 0.048, cos(spec.y) * at),
			Vector3(0.11, 0.085, 0.10), CONCRETE_DARK, 0.0, false,
			_yaw(spec.y * 31.0) * _pitch(9.0))

	return root


## Dense ingot: a bar 52 cm long that has crushed the steel plate it lies on,
## sheared the plinth under that, and bowed the lifting yoke that was left over
## it. The prop is the damage; the exhibit is almost too small to see.
##
## Scale is the joke and it has to survive being looked at, so nothing here is
## enlarged for legibility: the ingot really is 0.52 x 0.145 x 0.20 m, the
## bearing plate really is 4 cm of steel, and the plinth really has stepped
## sideways by 3.5 cm along a horizontal shear line.
##
## Visual box 1.85 x 1.03 x 2.12 m, deliberately not square — the four floor
## cracks have different lengths and none of them is radial, because a symmetric
## star reads as ornament. Plan it as a 2.2 m square and it will always fit.
## Solid box 1.34 x 0.76 x 1.32 m: the two plinth blocks and the ingot itself,
## which sits on top of them and so adds no reachable obstacle.
## 20 nodes, 19 meshes, 228 triangles, 3 colliders.
static func build_dense_ingot(parent: Node3D, origin: Vector3,
		yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, "Dense Ingot", origin, yaw_deg)

	# Plinth sheared in half. The upper block has walked 3.5 cm and rotated 2.2
	# degrees off the lower one, with a black seam between them.
	_box(root, "Plinth Base", Vector3(0, 0.15, 0), Vector3(1.30, 0.30, 1.30),
		CONCRETE)
	_box(root, "Plinth Shear Seam", Vector3(0, 0.305, 0),
		Vector3(1.36, 0.022, 1.36), VOID, 0.0, false)
	_box(root, "Plinth Cap", Vector3(0.035, 0.466, -0.02),
		Vector3(1.26, 0.30, 1.26), CONCRETE, 0.0, true, _yaw(2.2))

	# Load-spreading bearing plate, sagged. Three pieces: two halves that have
	# tipped inward and a centre pad pushed 2.5 cm lower than either.
	_box(root, "Bearing Plate West", Vector3(-0.245, 0.636, 0),
		Vector3(0.44, 0.042, 0.88), STEEL, 0.62, false, _roll(-4.2))
	_box(root, "Bearing Plate East", Vector3(0.245, 0.636, 0),
		Vector3(0.44, 0.042, 0.88), STEEL, 0.62, false, _roll(4.2))
	_box(root, "Bearing Pad", Vector3(0, 0.606, 0),
		Vector3(0.30, 0.048, 0.88), STEEL, 0.62, false)

	# The exhibit. Bottom face at 0.6155, pad top at 0.630 — 1.5 cm into solid
	# steel.
	_box(root, "Ingot", Vector3(0, 0.688, 0), Vector3(0.52, 0.145, 0.20),
		DENSE, 0.60)

	# Lifting yoke, splayed and bowed. Never solid: it stands entirely over the
	# plinth, which already stops the player 0.65 m short of it.
	for side: float in [-1.0, 1.0]:
		_box(root, "Yoke Post %s" % ("W" if side < 0.0 else "E"),
			Vector3(side * 0.44, 0.80, 0), Vector3(0.052, 0.36, 0.052),
			STEEL_WORN, 0.45, false, _roll(-9.0 * side))
	_box(root, "Yoke Bar West", Vector3(-0.30, 0.985, 0),
		Vector3(0.38, 0.05, 0.05), STEEL_WORN, 0.45, false, _roll(-5.0))
	_box(root, "Yoke Bar East", Vector3(0.30, 0.985, 0),
		Vector3(0.38, 0.05, 0.05), STEEL_WORN, 0.45, false, _roll(5.0))
	_box(root, "Yoke Bar Sag", Vector3(0, 0.951, 0),
		Vector3(0.28, 0.05, 0.05), STEEL_WORN, 0.45, false)

	# Cracks leaving the plinth footprint, and the chips they threw.
	var cracks := [0.52, 0.38, 0.57, 0.44]
	for i in range(cracks.size()):
		var a: float = TAU * float(i) / 4.0 + 0.62
		var length: float = float(cracks[i])
		var at: float = 0.72 + length * 0.5
		_box(root, "Ingot Floor Crack %d" % i,
			Vector3(sin(a) * at, 0.012, cos(a) * at),
			Vector3(0.045, 0.013, length), VOID, 0.0, false,
			_yaw(rad_to_deg(a) + 5.0 * float(i) - 7.0))
	var chips := [Vector2(0.82, 1.1), Vector2(1.02, 3.3), Vector2(0.88, 4.9)]
	for i in range(chips.size()):
		var spec: Vector2 = chips[i]
		_box(root, "Ingot Chip %d" % i,
			Vector3(sin(spec.y) * spec.x, 0.038, cos(spec.y) * spec.x),
			Vector3(0.10, 0.075, 0.095), CONCRETE_DARK, 0.0, false,
			_yaw(spec.y * 43.0) * _pitch(-8.0))

	return root


## Mass pendulum: a bob hanging dead still on a taut cable, `hang_deg` off
## vertical, over a wear trench that is centred somewhere else.
##
## Everything about it is ordinary except the one thing that matters. A pendulum
## at rest hangs at the bottom of its arc, over the middle of the groove it has
## worn; this one hangs 0.61 m to one side of that groove, on a cable — not a
## rod — that is pulled straight. A cable can only be straight if something is
## pulling it, and there is nothing there. The frame has noticed: the west leg is
## 1.6 degrees out of plumb and packed up on a shim.
##
## Visual box 3.06 x 3.10 x 0.86 m; the crossbar tops out at 3.080, leaving
## 0.31 m under the soffit. The solid envelope measures 2.80 x 2.92 x 0.60 m but
## contains only three pieces: the two legs (0.16 m square columns at
## x = +/-1.30) and the bob (a 0.60 x 0.46 m cylinder centred at x = 0.47, hanging
## from y = 0.61 to 1.16). Everything between the legs is open floor, so the
## Curator paths straight through the frame unless the bob is in the way.
## 26 nodes, 25 meshes, 544 triangles, 3 colliders.
static func build_mass_pendulum(parent: Node3D, origin: Vector3,
		yaw_deg := 0.0, hang_deg := 14.0) -> Node3D:
	var root := _root(parent, "Mass Pendulum", origin, yaw_deg)

	# Portal frame. The west leg is the one that is losing.
	_box(root, "Frame Leg West", Vector3(-1.30, 1.43, 0),
		Vector3(0.16, 2.90, 0.16), STEEL_WORN, 0.55, true, _roll(1.6))
	_box(root, "Frame Leg East", Vector3(1.30, 1.45, 0),
		Vector3(0.16, 2.90, 0.16), STEEL_WORN, 0.55)
	for side: float in [-1.0, 1.0]:
		_box(root, "Frame Foot %s" % ("W" if side < 0.0 else "E"),
			Vector3(side * 1.30, 0.028, 0), Vector3(0.46, 0.055, 0.46),
			STEEL, 0.55, false)
	_box(root, "Frame Shim", Vector3(-1.30, 0.070, 0.10),
		Vector3(0.30, 0.028, 0.24), RUST, 0.25, false)
	_box(root, "Frame Crossbar", Vector3(0, 2.99, 0),
		Vector3(2.92, 0.18, 0.18), STEEL, 0.55, false)
	_wedge(root, "Frame Gusset West", Vector3(-1.05, 2.73, 0),
		Vector3(0.34, 0.34, 0.14), STEEL, 0.0)
	_wedge(root, "Frame Gusset East", Vector3(1.05, 2.73, 0),
		Vector3(0.34, 0.34, 0.14), STEEL, 1.0)
	_box(root, "Swivel Housing", Vector3(0, 2.83, 0),
		Vector3(0.24, 0.18, 0.24), STEEL, 0.55, false)

	# Cable, pulled straight to one side by nothing.
	var pivot := Vector3(0, 2.80, 0)
	var hang := deg_to_rad(hang_deg)
	var down := Vector3(sin(hang), -cos(hang), 0.0)
	var cable_end: Vector3 = pivot + down * 1.72
	_span(root, "Suspension Cable", pivot, cable_end, 0.024, STEEL_WORN, 0.55)
	for i in range(3):
		var t: float = 0.25 + 0.30 * float(i)
		_cyl(root, "Cable Swage %d" % i, pivot + down * (1.72 * t),
			0.045, 0.07, STEEL, 0.55, false, _aim(down))

	# Bob: a squat disc weight with a point on the end, hung on the cable's axis.
	# The cylinder collider matters here — the player walks into this one.
	var aim := _aim(down)
	_cyl(root, "Bob Collar", cable_end + down * 0.035, 0.335, 0.05,
		STEEL, 0.55, false, aim)
	var bob := _cyl(root, "Bob", cable_end + down * 0.23, 0.30, 0.46,
		DENSE, 0.50, false, aim)
	var bob_shape := CylinderShape3D.new()
	bob_shape.height = 0.46
	_shape(bob, "Bob", bob_shape, 0.30)
	_cone(root, "Bob Point", cable_end + down * 0.63, 0.30, 0.02, 0.34,
		DENSE, 0.50, aim)

	# The trench the bob wore, centred under the pivot — which is 0.61 m from
	# where the bob actually is. Deepest and widest in the middle.
	for i in range(7):
		var t: float = -1.0 + float(i) / 3.0
		var wear: float = 1.0 - absf(t)
		_box(root, "Wear Trench %d" % i, Vector3(t * 1.02, 0.008, 0),
			Vector3(0.24, 0.016, 0.40 + wear * 0.22),
			VOID if wear > 0.55 else CONCRETE_DARK, 0.0, false)
	for side: float in [-1.0, 1.0]:
		_box(root, "Strike Scar %s" % ("W" if side < 0.0 else "E"),
			Vector3(side * 1.12, 0.008, 0), Vector3(0.06, 0.014, 0.86),
			VOID, 0.0, false)

	return root


# =============================================================================
# WING DRESSING
# =============================================================================


## Buckled deck: a raised steel floor whose plates have stopped lying flat.
##
## Nothing in it collides, which means nothing in it touches the navmesh either,
## so unlike the rest of this file it is safe to run straight across a doorway.
## The trade is that the player walks over it without feeling it; that is the
## right trade, because a tilted plate with a collider is exactly the geometry
## that snags a capsule.
##
## The plates sit 4.5 cm above the museum floor over a single black slab, so the
## joints between them read as gaps into the dark rather than as bright marble
## lines. Tilting then sends the high corner of a lifted plate to y = 0.272 and
## the low corner of a settled one to y = -0.076, where it disappears into the
## slab instead of ending on a visible cut line. The high figure is what matters:
## 0.272 m is inside both the player's step_height (0.38) and the Curator's
## agent_max_climb (0.4), and since nothing here collides neither of them has to
## climb it anyway.
##
## Extent is `cols * plate_size + (cols - 1) * 0.07 + 0.10` on each axis — the
## black slab overhangs the plates by 5 cm a side. At the defaults (4 x 4 plates
## of 1.6 m) that is 6.71 x 0.35 x 6.71 m. `rng_seed` makes the buckling
## deterministic, so two builds of the map produce the same floor.
## 18 nodes, 17 meshes, 204 triangles, no colliders.
static func build_buckled_deck(parent: Node3D, origin: Vector3,
		cols := 4, rows := 4, plate_size := 1.6, yaw_deg := 0.0,
		rng_seed := 0) -> Node3D:
	var root := _root(parent, "Buckled Deck", origin, yaw_deg)
	var gap := 0.07
	var pitch: float = plate_size + gap
	var extent_x: float = float(cols) * plate_size + float(cols - 1) * gap
	var extent_z: float = float(rows) * plate_size + float(rows - 1) * gap

	# One slab of black under everything, so every joint looks into a void.
	_box(root, "Deck Void", Vector3(0, 0.012, 0),
		Vector3(extent_x + 0.10, 0.05, extent_z + 0.10), VOID, 0.0, false)

	# Three fixed shades rather than a per-plate tint: the plates still read as
	# individually weathered, and the material cache stays at three entries.
	var shades: Array[Color] = [STEEL_WORN, Color(0.118, 0.120, 0.126),
		Color(0.072, 0.076, 0.082)]
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for iz in range(rows):
		for ix in range(cols):
			var at := Vector3(
				(float(ix) - float(cols - 1) * 0.5) * pitch, 0.0,
				(float(iz) - float(rows - 1) * 0.5) * pitch)
			var lifted: bool = rng.randf() < 0.20
			var tilt_x: float = rng.randf_range(-3.4, 3.4)
			var tilt_z: float = rng.randf_range(-3.4, 3.4)
			var height := 0.045
			if lifted:
				tilt_x = rng.randf_range(5.5, 8.0) * signf(tilt_x)
				height = 0.10
			elif rng.randf() < 0.30:
				height = 0.014
			at.y = height
			var shade: Color = shades[rng.randi_range(0, shades.size() - 1)]
			_box(root, "Deck Plate %d-%d" % [ix, iz], at,
				Vector3(plate_size, 0.05, plate_size),
				shade, 0.45, false,
				_pitch(tilt_x) * _roll(tilt_z))
	return root


## Load-spreading frame: a steel grillage laid on the floor to take an exhibit's
## weight, packed up on shims because the slab under it is no longer flat.
##
## The tell is the shims and the two dark gaps under the mid-spans of the north
## and south beams: the frame is bridging a low spot, so the thing it was built
## to support has already pushed the floor down. Hazard chevrons run along the
## north edge — repeated diagonal bars, so the warning survives a monochrome CCTV
## feed and does not depend on the paint colour.
##
## Visual box `span_x + 0.26` by 0.273 by `span_z + 0.55` with chevrons, or
## `span_z + 0.26` without; at the defaults 3.66 x 0.27 x 3.95 m, the Z being the
## one asymmetric axis because the chevron band runs along -Z only. Solid box is
## empty by default. Passing `solid = true` gives the four perimeter webs
## colliders — the frame stands 0.23 m at the flange, inside both the player step
## (0.38) and the agent max climb (0.4), so it stays traversable, but it does
## carve a raised island out of the navmesh and must not then sit within 1.6 m of
## a doorway. 28 nodes, 27 meshes, 468 triangles.
static func build_load_frame(parent: Node3D, origin: Vector3,
		span_x := 3.4, span_z := 3.4, yaw_deg := 0.0,
		solid := false, chevrons := true) -> Node3D:
	var root := _root(parent, "Load Frame", origin, yaw_deg)
	var base := 0.03          # sitting on shims, not on the floor
	var web := 0.15
	var flange := 0.05

	# Perimeter beams: web plus top flange, the flange overhanging 3 cm a side.
	for side: float in [-1.0, 1.0]:
		var tag: String = "North" if side < 0.0 else "South"
		_box(root, "Frame Beam %s Web" % tag,
			Vector3(0, base + web * 0.5, side * span_z * 0.5),
			Vector3(span_x, web, 0.20), STEEL, 0.62, solid)
		_box(root, "Frame Beam %s Flange" % tag,
			Vector3(0, base + web + flange * 0.5, side * span_z * 0.5),
			Vector3(span_x, flange, 0.26), STEEL, 0.62, false)
		var tag_wz: String = "West" if side < 0.0 else "East"
		_box(root, "Frame Beam %s Web" % tag_wz,
			Vector3(side * span_x * 0.5, base + web * 0.5, 0),
			Vector3(0.20, web, span_z - 0.26), STEEL, 0.62, solid)
		_box(root, "Frame Beam %s Flange" % tag_wz,
			Vector3(side * span_x * 0.5, base + web + flange * 0.5, 0),
			Vector3(0.26, flange, span_z - 0.26), STEEL, 0.62, false)
		# Corner shim packs, two per diagonal, at different heights.
		_box(root, "Frame Shim %s" % tag,
			Vector3(side * span_x * 0.42, base * 0.5, side * span_z * 0.42),
			Vector3(0.32, base, 0.32), RUST, 0.25, false)
		_box(root, "Frame Shim %s Cross" % tag,
			Vector3(-side * span_x * 0.42, base * 0.33, side * span_z * 0.42),
			Vector3(0.28, base * 0.66, 0.28), CONCRETE_DARK, 0.0, false)
		# The gap the frame is bridging.
		_box(root, "Frame Gap %s" % tag,
			Vector3(0, 0.014, side * span_z * 0.5),
			Vector3(span_x * 0.55, 0.028, 0.20), VOID, 0.0, false)

	# Cross members, sitting lower than the perimeter because they have sunk.
	for side: float in [-1.0, 1.0]:
		var tag: String = "Inner North" if side < 0.0 else "Inner South"
		_box(root, "Frame Beam %s Web" % tag,
			Vector3(0, 0.065, side * span_z * 0.17),
			Vector3(span_x - 0.26, 0.13, 0.16), STEEL, 0.62, false)
		_box(root, "Frame Beam %s Flange" % tag,
			Vector3(0, 0.1525, side * span_z * 0.17),
			Vector3(span_x - 0.26, 0.045, 0.22), STEEL, 0.62, false)

	# Bolt heads on the perimeter flanges.
	for i in range(4):
		var sx: float = -1.0 if i % 2 == 0 else 1.0
		var sz: float = -1.0 if i < 2 else 1.0
		_cyl(root, "Frame Bolt %d" % i,
			Vector3(sx * span_x * 0.36, base + web + flange + 0.02,
				sz * span_z * 0.5),
			0.055, 0.045, RUST, 0.25, false)

	if chevrons:
		for i in range(5):
			_box(root, "Hazard Chevron %d" % i,
				Vector3((float(i) - 2.0) * 0.34, 0.010,
					-span_z * 0.5 - 0.30),
				Vector3(0.30, 0.016, 0.09), CAUTION, 0.0, false, _yaw(34.0))
	return root


## Crane gantry: a runway over the wing with a trolley parked off-centre and a
## hoist hook hanging almost to the floor, holding nothing.
##
## An empty hook 55 cm off the ground in the middle of a gallery is the cheapest
## piece of dread in this file. Something was lifted out, or something is about
## to be put in, and the wing is not currently telling which.
##
## Visual box `span + 0.5` by 3.12 by 2.36 m; at the default span 5.4 that is
## 5.90 x 3.12 x 2.36 m, leaving 0.27 m under the 3.39 m soffit. Solid parts are
## the four legs (0.20 m square at x = +/-span/2, z = +/-0.95) and the hoist block
## (0.30 x 0.40 x 0.24 m at y = 1.11 to 1.51 above `hook_tip_y - 0.55`). The legs
## define the clearance rule: with agent_radius 0.45 the walkable slot between a
## leg pair is 2 * 0.95 - 0.20 - 0.90 = 0.80 m, so the Curator can path BETWEEN
## the rails but not diagonally past a leg — keep any leg at least 1.6 m from a
## doorway centre line.
##
## `hook_tip_y` is the height of the bottom of the hoist ring. Raising it above
## about 2.1 m puts the whole block over the player's head and the collider stops
## mattering; lowering it below 0.4 m starts to intersect the floor.
## 29 nodes, 28 meshes, 792 triangles, 5 colliders.
static func build_crane_gantry(parent: Node3D, origin: Vector3,
		span := 5.4, yaw_deg := 0.0, trolley_x := -0.9,
		hook_tip_y := 0.55) -> Node3D:
	var root := _root(parent, "Crane Gantry", origin, yaw_deg)
	var half: float = span * 0.5
	var rail_z := 0.95
	var rail_y := 2.99

	for i in range(4):
		var sx: float = -1.0 if i % 2 == 0 else 1.0
		var sz: float = -1.0 if i < 2 else 1.0
		_box(root, "Gantry Leg %d" % i,
			Vector3(sx * half, 1.43, sz * rail_z),
			Vector3(0.20, 2.86, 0.20), STEEL_WORN, 0.55)
		_box(root, "Gantry Base Plate %d" % i,
			Vector3(sx * half, 0.03, sz * rail_z),
			Vector3(0.46, 0.06, 0.46), STEEL, 0.55, false)
		# Knee brace into the rail above.
		_span(root, "Gantry Brace %d" % i,
			Vector3(sx * half, 2.28, sz * rail_z),
			Vector3(sx * (half - 0.66), 2.86, sz * rail_z),
			0.055, STEEL_WORN, 0.55)

	for side: float in [-1.0, 1.0]:
		_box(root, "Gantry Rail %s" % ("North" if side < 0.0 else "South"),
			Vector3(0, rail_y, side * rail_z),
			Vector3(span + 0.50, 0.26, 0.18), STEEL, 0.62, false)
		_box(root, "Gantry End Tie %s" % ("West" if side < 0.0 else "East"),
			Vector3(side * half, rail_y, 0),
			Vector3(0.18, 0.18, rail_z * 2.0 + 0.18), STEEL, 0.62, false)

	_box(root, "Hoist Trolley", Vector3(trolley_x, 2.73, 0),
		Vector3(0.86, 0.26, 1.72), STEEL, 0.62, false)
	_cyl(root, "Hoist Drum", Vector3(trolley_x, 2.88, 0), 0.14, 0.62,
		STEEL_WORN, 0.55, false, _pitch(90.0))

	# Falls, block and ring. The chain is drawn taut: the hook is loaded by its
	# own weight and nothing else, which is exactly why the empty ring reads.
	var block_y: float = hook_tip_y + 0.76
	_span(root, "Hoist Chain", Vector3(trolley_x, 2.60, 0),
		Vector3(trolley_x, block_y + 0.20, 0), 0.022, STEEL_WORN, 0.55, 6)
	# "Hoist Block" is the one node below head height in this builder that
	# carries a collider; the name is worth keeping stable for anything that
	# sweeps the map looking for path blockers.
	_box(root, "Hoist Block", Vector3(trolley_x, block_y, 0),
		Vector3(0.30, 0.40, 0.24), STEEL, 0.62)
	_cyl(root, "Hoist Shank", Vector3(trolley_x, hook_tip_y + 0.45, 0),
		0.05, 0.22, STEEL_WORN, 0.55, false)
	_ring(root, "Hoist Ring", Vector3(trolley_x, hook_tip_y + 0.17, 0),
		0.07, 0.17, STEEL_WORN, 0.55, _pitch(90.0))
	return root


## Chains under tension: a ceiling anchor with taut chains running down to floor
## bolts, converging on nothing.
##
## The negative space in the middle is the prop. Chains only go straight when
## something is pulling on them, so a ring of straight chains around an empty
## patch of floor states, without a word of signage, that whatever they restrain
## is still there and is no longer visible. Turnbuckles part-way down make the
## tension deliberate rather than accidental.
##
## The whole thing fits inside a cylinder of `radius + 0.13` and reaches
## `anchor_y + 0.045` high. Its AABB is not square, because three chains at 120
## degrees do not make a square: at the defaults it measures 2.13 x 3.35 x 2.22 m
## with the anchor plate topping out at 3.345 m against a 3.39 m soffit. Reserve
## the 2.56 m circle and it fits at any `count`.
##
## Nothing collides, so it is navmesh-neutral — which also means the player can
## walk through the chains. That is intentional: a 2 cm collider ring around an
## empty patch of floor is a trap for the Curator and a snag for the player, and
## the image survives the omission.
## 30 nodes at the defaults, 29 meshes, 708 triangles. Node count is
## `2 + count * (4 + links)`.
static func build_tension_chains(parent: Node3D, origin: Vector3,
		anchor_y := 3.30, count := 3, radius := 1.15, yaw_deg := 0.0,
		links := 5) -> Node3D:
	var root := _root(parent, "Tension Chains", origin, yaw_deg)

	_box(root, "Chain Anchor Plate", Vector3(0, anchor_y, 0),
		Vector3(0.40, 0.09, 0.40), STEEL, 0.62, false)
	_cyl(root, "Chain Anchor Boss", Vector3(0, anchor_y - 0.12, 0),
		0.09, 0.16, STEEL_WORN, 0.55, false)

	var top := Vector3(0, anchor_y - 0.20, 0)
	for i in range(count):
		var a: float = TAU * float(i) / float(count) + 0.35
		var pad := Vector3(sin(a) * radius, 0.035, cos(a) * radius)
		_box(root, "Chain Pad %d" % i, pad, Vector3(0.26, 0.07, 0.26),
			STEEL_WORN, 0.55, false)
		_cyl(root, "Chain Eye Bolt %d" % i, pad + Vector3(0, 0.11, 0),
			0.035, 0.12, RUST, 0.25, false)
		var foot: Vector3 = pad + Vector3(0, 0.19, 0)
		_span(root, "Chain %d" % i, top, foot, 0.021, STEEL_WORN, 0.55, links)
		# Turnbuckle a fifth of the way up from the floor anchor.
		var along: Vector3 = (top - foot).normalized()
		_cyl(root, "Chain Turnbuckle %d" % i,
			foot + along * ((top - foot).length() * 0.22),
			0.055, 0.26, STEEL, 0.62, false, _aim(along))
	return root


# =============================================================================
# PRIMITIVES
#
# Deliberately parallel to FirstMuseumMap._box()/_primitive() — same visibility
# range, same shadow cutoff, same collision thresholds, same material shape —
# but static, and taking a Basis so a prop can be tilted without a pivot node per
# piece. Tilt is where the horror lives in this set, so it had to be free.
# =============================================================================


static func _root(parent: Node3D, node_name: String, origin: Vector3,
		yaw_deg: float) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = origin
	node.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(node)
	return node


static func _yaw(deg: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(deg))


## Rotation about local X. Positive leans a tall box's top toward +Z, which is
## the same thing as dipping a flat plate's +Z edge.
static func _pitch(deg: float) -> Basis:
	return Basis(Vector3.RIGHT, deg_to_rad(deg))


## Rotation about local Z. Positive leans a tall box's top toward -X, which is
## the same thing as lifting a flat plate's +X edge.
static func _roll(deg: float) -> Basis:
	return Basis(Vector3.BACK, deg_to_rad(deg))


## Basis whose local +Y points along `dir`. Cylinders and cones are built along
## +Y, so this aims one down a cable, a chain or a brace.
static func _aim(dir: Vector3) -> Basis:
	var up: Vector3 = dir.normalized()
	if up.length_squared() < 0.5:
		return Basis.IDENTITY
	var reference := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 \
		else Vector3.FORWARD
	var x: Vector3 = reference.cross(up).normalized()
	return Basis(x, up, x.cross(up))


static func _box(parent: Node3D, node_name: String, at: Vector3, size: Vector3,
		color: Color, metallic := 0.0, solid := true,
		basis := Basis.IDENTITY) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, node_name, at, mesh, size, color, metallic, solid, basis)


static func _cyl(parent: Node3D, node_name: String, at: Vector3, radius: float,
		height: float, color: Color, metallic := 0.0, solid := true,
		basis := Basis.IDENTITY) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = CYL_SEGMENTS
	mesh.rings = 0
	return _add(parent, node_name, at, mesh,
		Vector3(radius * 2.0, height, radius * 2.0), color, metallic, solid,
		basis)


static func _cone(parent: Node3D, node_name: String, at: Vector3,
		bottom_radius: float, top_radius: float, height: float, color: Color,
		metallic := 0.0, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = CYL_SEGMENTS
	mesh.rings = 0
	var widest: float = maxf(bottom_radius, top_radius) * 2.0
	return _add(parent, node_name, at, mesh, Vector3(widest, height, widest),
		color, metallic, false, basis)


static func _ball(parent: Node3D, node_name: String, at: Vector3, radius: float,
		color: Color, metallic := 0.0, solid := true) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = SPHERE_RADIAL
	mesh.rings = SPHERE_RINGS
	return _add(parent, node_name, at, mesh, Vector3.ONE * radius * 2.0, color,
		metallic, solid)


static func _ring(parent: Node3D, node_name: String, at: Vector3,
		inner_radius: float, outer_radius: float, color: Color,
		metallic := 0.0, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = TORUS_RINGS
	mesh.ring_segments = TORUS_RING_SEGMENTS
	return _add(parent, node_name, at, mesh,
		Vector3(outer_radius * 2.0, outer_radius - inner_radius,
			outer_radius * 2.0),
		color, metallic, false, basis)


## Right-triangle gusset. `left_to_right` 0.0 stands the vertical face on the -X
## side, 1.0 on the +X side.
static func _wedge(parent: Node3D, node_name: String, at: Vector3,
		size: Vector3, color: Color, left_to_right: float) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	mesh.left_to_right = left_to_right
	return _add(parent, node_name, at, mesh, size, color, 0.55, false)


## Cylinder spanning `from` to `to`, optionally beaded with `link_count` chain
## links alternating 90 degrees about the run. One node for the run plus one per
## link — a modelled chain would be an order of magnitude more of both nodes and
## triangles for a silhouette the player reads from three metres away.
static func _span(parent: Node3D, node_name: String, from: Vector3, to: Vector3,
		radius: float, color: Color, metallic := 0.0,
		link_count := 0) -> MeshInstance3D:
	var delta: Vector3 = to - from
	var length: float = delta.length()
	if length < 0.001:
		return null
	var basis: Basis = _aim(delta / length)
	var run := _cyl(parent, node_name, (from + to) * 0.5, radius, length, color,
		metallic, false, basis)
	for i in range(link_count):
		var t: float = float(i + 1) / float(link_count + 1)
		_box(parent, "%s Link %d" % [node_name, i], from + delta * t,
			Vector3(radius * 3.6, radius * 4.8, radius * 1.3), color, metallic,
			false, basis * _yaw(90.0 * float(i % 2)))
	return run


static func _add(parent: Node3D, node_name: String, at: Vector3,
		mesh: PrimitiveMesh, size: Vector3, color: Color, metallic: float,
		solid: bool, basis := Basis.IDENTITY) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.transform = Transform3D(basis, at)
	instance.mesh = mesh
	instance.material_override = _material(color, metallic)
	instance.visibility_range_end = 115.0
	instance.visibility_range_fade_mode = \
		GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if size.length() < 0.65:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

	# Same gate as the map: cracks, shims, chain links and hazard paint are not
	# walk-blocking geometry and every collider they would add is a bite out of
	# the Curator's navmesh.
	if solid and size.x >= MIN_COLLIDER_SPAN and size.z >= MIN_COLLIDER_SPAN \
			and size.y >= MIN_COLLIDER_HEIGHT:
		var box := BoxShape3D.new()
		box.size = size
		_shape(instance, node_name, box, 0.0)
	return instance


## Attach (or replace) the collider on `instance`. `radius` feeds the shapes that
## have one; BoxShape3D ignores it.
static func _shape(instance: MeshInstance3D, node_name: String, shape: Shape3D,
		radius: float) -> void:
	var existing := instance.get_node_or_null(
		NodePath("%s Collision" % node_name))
	if existing != null:
		existing.free()
	if shape is SphereShape3D:
		(shape as SphereShape3D).radius = radius
	elif shape is CylinderShape3D:
		(shape as CylinderShape3D).radius = radius

	var body := StaticBody3D.new()
	body.name = "%s Collision" % node_name
	instance.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "%s CollisionShape" % node_name
	collision.shape = shape
	body.add_child(collision)


static func _material(color: Color, metallic: float) -> StandardMaterial3D:
	var key := "%s|%.2f" % [color.to_html(true), metallic]
	if _materials.has(key):
		return _materials[key]

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = clampf(0.5 - metallic * 0.35, 0.12, 1.0)
	mat.metallic = metallic
	mat.metallic_specular = 0.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	# Concrete only, on the same rule the map uses, so a plinth built here and a
	# plinth built by FirstMuseumMap._material() are the same surface. Metal is
	# left smooth: the noise reads as grit, and grit on a polished ingot fights
	# the one thing that prop has to communicate.
	if metallic < 0.35:
		mat.roughness_texture = _shared_noise()
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.normal_enabled = true
		mat.normal_texture = _shared_bump()
		mat.normal_scale = 0.08
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.22, 0.22, 0.22)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_materials[key] = mat
	return mat


static func _shared_noise() -> NoiseTexture2D:
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


static func _shared_bump() -> NoiseTexture2D:
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
