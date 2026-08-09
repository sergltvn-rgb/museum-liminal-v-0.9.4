class_name AtriumProps
extends RefCounted
## Procedural props for the Central Atrium of THE FIRST MUSEUM.
##
## The map has no 3D content on disk -- scenes/FirstMuseumMap.tscn is empty and
## FirstMuseumMap.build_map() constructs the whole building at runtime from
## primitives. This file is the same idea, factored out: every function takes
## (parent, origin, ...), builds one prop under a single Node3D and returns that
## root, so the map places it in one line. Nothing here reads or writes any
## other script.
##
## THE BRIEF
## The atrium centrepiece is the containment core: the machine that holds the
## museum's four physical constants stable, and the thing that breaks on night
## one. It has to read as INDUSTRIAL CONTAINMENT seen from the entrance door
## 15 m away -- a shielded column, service gantries, cable runs, a status ring
## and blast shutters -- not as a glowing sci-fi bauble on a plinth. The horror
## is in the silhouette and in what is missing: one gantry was never built, one
## blast shutter is stuck half-open, two status cells are dead and recessed, and
## a length of barrier rope is lying on the floor where someone stepped over it.
##
## ROOM ENVELOPE (from FirstMuseumMap.build_map)
##   Central Atrium  centre (0,0,0), 30 x 30 m, so x,z in [-15, 15].
##   Interior wall faces at +-14.65; floor top y = 0; ceiling underside y = 3.39
##   (WALL_HEIGHT 3.4, ceiling slab 3.45 +- 0.06).
##   Doorways (DOOR_GAP 1.8 m) at (0,0,15) entrance, (0,0,-15) Time Wing B,
##   (15,0,0) Gravity Wing A, (-15,0,0) Watcher Office.
##   Existing atrium furniture this file is routed clear of: rotunda kerb r 5.8
##   and rotunda floor r 4.9 (top y 0.16; the kerb tops out 1 cm lower at
##   0.15 so the two never share a plane), four columns at (+-11.5, +-11.5),
##   four benches at radius 8.4 on the cardinal axes, planters at
##   (+-10.8, 0, 10.8), distribution board at (12.5, ., 14.5).
##
## NAVIGATION
## The Curator bakes on agent_radius 0.45 through 1.8 m doorways, so nothing in
## this file goes anywhere near a doorway. The furthest collider from the atrium
## axis is 2.46 m (the core's reading plaque); the barrier ring at 3.40 m and
## the floor paint out at 4.74 m carry none. That leaves an 11 m walkable
## annulus out to the walls. Swept with a 0.35 x 1.8 player capsule inward from
## all four doorways in 0.5 m steps: every step is clear until 12.5 m in, which
## is the core itself. Collision is given only to geometry the player can
## genuinely bump into, and cylinders get a CylinderShape3D rather than a box,
## so there are no invisible corner walls out at r * sqrt(2) -- 199 meshes,
## 45 static bodies, 5520 triangles, 45 shared materials for the whole set.
##
## ACCESSIBILITY
## Nothing in this file animates, pulses or flickers -- these are static meshes
## with static materials, so SettingsManager.reduced_flashes has nothing to
## switch off here. Status is encoded by count and by geometry (dead cells are
## recessed 5 cm into the ring), never by colour alone; the wing colour tabs on
## the directory board sit beside the wing name, they do not replace it. Signage
## is pale text (0.82, 0.86, 0.84) on near-black panels (0.072, 0.076, 0.082),
## which is 13.4:1 -- Label3D renders unshaded, so that ratio holds under any
## lighting the map throws at it.
##
## LIGHTING NOTE FOR THE INTEGRATOR
## FirstMuseumMap's "Skylight Beam" is a SpotLight3D at (0, 3.28, 0) aimed down.
## spot_angle is 40 deg now, so the beam lands as a ring around the dais instead
## of the 1.39 m pinspot it used to be. Careful reading that number: Godot's
## spot_angle is the HALF angle, so 40 deg is a pool about 5.5 m across at the
## floor (3.28 * tan 40 = 2.75 m radius), not the 2.6 m radius an earlier note
## here claimed.
##
## That beam cannot light the core, and no amount of energy will change it. It
## is a point source sitting dead over the column, and the head cap is a 0.66 m
## cone at 2.74 with the collar above it, so the whole drum stands in the umbra
## of its own head; the three gantry decks finish off whatever is left. Only
## side light reaches the column. _build_core_spots() therefore adds the two
## lights this file owns -- a pair of ceiling rigs on the +-X axis that rake the
## drum and give it back a silhouette. Everything else here is unlit geometry.


# --- Palette -----------------------------------------------------------------
# Museum-grade steel and concrete. Values are deliberately dark: the atrium
# walls are near-white marble (0.87) and the core has to read as a hole in it.
const MatLib := preload("res://game/props/MaterialLib.gd")
# Только через preload: глобальное имя класса в голом --script-прогоне не
# регистрируется и вся цепочка падает (раздел 14 плана).
const Pal := preload("res://game/props/Palette.gd")
## Same reason as Pal above: reached by preload, never by global class name, so
## the atrium still builds under a bare `--script` run. Models.place() returns
## null when the .glb is absent, and that null is exactly the signal every
## procedural fallback below keys off -- delete models/lowpoly/ and this file
## still produces the same atrium it produced before batch 3.
const Models := preload("res://game/MapModels.gd")
const Lights := preload("res://game/props/LightProps.gd")

# Атриум строится на контрасте: стены — почти белый мрамор (0.87), а ядро
# и его каркас обязаны читаться как дыра в нём. Прямой `Pal.STONE` в
# четыре раза светлее здешнего бетона и этот контраст убивает, поэтому
# тёмные роли — производные через `tone()` и потому `static var`, а не `const`.
static var CONCRETE := Pal.tone(Pal.SLATE, -0.55)
static var CONCRETE_DARK := Pal.tone(Pal.SLATE, -0.68)
static var STEEL := Pal.tone(Pal.STEEL, -0.56)
static var STEEL_DARK := Pal.tone(Pal.STEEL_DARK, -0.38)
# Чёрное железо и кабель остаются своими: нужны две ступени ниже
# `STEEL_DARK`, чтобы оплётка ядра не слилась с его каркасом.
const IRON := Color(0.062, 0.066, 0.070)
const CABLE := Color(0.045, 0.048, 0.052)
const PANEL := Pal.PANEL
const SIGN_TEXT := Pal.SIGN_TEXT
# Глухая предупредительная краска — своя: это тёмная пара к `AMBER`,
# одним тоном полосатую разметку не собрать.
const HAZARD := Color(0.50, 0.39, 0.10)
const HAZARD_BRIGHT := Pal.AMBER
static var BRASS := Pal.tone(Pal.BRASS, -0.32)
## The core at rest. Not a colour choice so much as a brightness one: at the old
## (0.42, 0.92, 0.74) the emissive pass pushed green to 1.47 and blue to 1.18,
## both past unity, so the sphere clipped into the glow buffer and bloomed white
## -- a reactor from a spaceship. Held under unity on every channel but green it
## stops blooming and starts LIGHTING: a mercury-vapour tube behind a cage,
## the colour of a failing lamp in a plant room. Saturation 0.54 -> 0.24 at a
## near-constant hue (158 -> 154 deg), so it is the same object, dimmed and
## gone grey, and GameManager's incident tint still reads as a change of state
## rather than as the core finally turning on.
const CORE_GLOW := Color(0.44, 0.58, 0.52)
static var WOOD := Pal.tone(Pal.WOOD, -0.52)
static var STONE := Pal.tone(Pal.STONE, -0.76)
## Столешницы ресепшена — единственная светлая горизонталь в зале, и они
## сознательно выведены из-под общего правила «тёмное ядро». `STONE` при -0.76
## даёт около 0.14 люмы: рядом с чёрным корпусом стойки весь ресепшен слипался
## в одно чёрное пятно и от входа (13 м) его просто не было видно. -0.08 — это
## тот же тон, что свотч `stone_pale` в tools/lowpoly/glb.py, поэтому модель
## `lp_reception_counter`, её процедурный фолбэк и приставной стол читаются
## одним и тем же камнем, а не тремя разными.
static var COUNTER_STONE := Pal.tone(Pal.STONE, -0.08)
const ACCENT_DEEP := Color(0.115, 0.235, 0.215)

## Wing tabs on the directory board. Same four hues as the wing banners
## FirstMuseumMap hangs beside the atrium doorways, so the board agrees with
## the building. The name beside each tab carries the meaning; the colour is
## decoration.
const WING_TINTS: Array[Color] = [
	Color(0.30, 0.42, 0.72),  # A - Gravity
	Color(0.72, 0.50, 0.30),  # B - Time
	Color(0.50, 0.36, 0.66),  # C - Space
	Color(0.55, 0.45, 0.28),  # D - Mass
]
const WING_KEYS: Array[String] = [
	"EXHIBIT_WING_A", "EXHIBIT_WING_B", "EXHIBIT_WING_C", "EXHIBIT_WING_D",
]

## Matches MapPrimitives._primitive so these props fade out with the rest of
## the museum instead of popping at a different distance.
const VISIBILITY_RANGE := 115.0

## Optional force-field shader for the containment window. Absent in a stripped
## build, in which case the window falls back to plain glass and GameManager's
## _set_dome_breach() hides the mesh instead of cracking it.
const DOME_SHADER := "res://shaders/ContainmentDome.gdshader"

## GameManager.find_child()s these two by name. Renaming either one silently
## breaks the anomaly tint and the breach effect, so they are constants.
const CORE_NODE_NAME := "Anomalous Core"
const DOME_NODE_NAME := "Containment Dome"

# Materials are shared across every prop and every call. The map builds ~1270
# meshes in one frame; handing each of them its own StandardMaterial3D is the
# expensive part, not the triangles.
static var _materials: Dictionary = {}


# =============================================================================
#  Containment core
# =============================================================================

## The atrium centrepiece: a shielded column on a hazard-marked slab, three
## service gantries, four blast shutter bays (one stuck half-open), a status
## ring and the cable trunks that leave through the ceiling.
##
## `origin` is the point the assembly STANDS ON, not its centre: pass
## Vector3(0, 0.16, 0) to set it on the rotunda plate that FirstMuseumMap lays
## at the middle of the atrium. `ceiling_y` is the ceiling underside in the
## parent's space (3.39 in this museum); the cable trunks stop 0.16 m short of
## it so build_cable_runs() can pick them up.
##
## Bounding box 4.44 x 3.18 x 4.76 m, y from origin.y to origin.y + 3.18
## (measured, not estimated). The x extent is the base lip at r 2.22; the z
## extent is 0.32 m longer only because the reading plaque stands off the south
## edge at z 2.54. Furthest collider from the axis: 2.46 m, the plaque post.
static func build_containment_core(parent: Node3D, origin: Vector3,
		ceiling_y := 3.39) -> Node3D:
	var root := _root(parent, "Containment Core Assembly", origin)
	var trunk_top: float = maxf(3.05, ceiling_y - origin.y - 0.16)

	_build_core_slab(root)

	# The column is ONE model now. lp_core_column carries both shield drums,
	# both bolted flanges, the eight-rib cage, the heat fins, the status ring
	# and the head cap and collar -- everything _build_core_column,
	# _build_core_status_ring, _build_core_head_cap and the bolts and fins of
	# _build_core_service used to draw as eighty-odd separate primitives, each
	# with its own material and each meeting its neighbour on a shared plane.
	# It stands ON the base deck, hence the 0.24: the model's own origin is its
	# floor, so every height inside it is measured from there.
	var column := Models.place(root, "lp_core_column", Vector3(0, 0.24, 0))
	if column == null:
		_build_core_column(root)
		_build_core_status_ring(root)
		_build_core_head_cap(root)
		_build_core_service(root)
	else:
		column.name = "Core Shield Column"

	# Four things are never part of any model and are built either way. The
	# sphere and the window are the two nodes GameManager drives by name, the
	# window is shader-driven, the trunks are sized per-map from the soffit
	# height, and the beacon lamp is emissive -- nothing in the lp_ pipeline
	# emits, by design.
	_build_core_glow(root)
	_build_core_trunks(root, trunk_top)
	_build_core_beacon(root)

	_build_core_gantries(root)
	_build_core_shutters(root)
	_build_core_plant(root)
	_build_core_plaque(root)
	return root


## Slab, kerb and the painted hazard hatching on the deck. Two shallow steps of
## 0.11 and 0.13 m, both well under the bake's agent_max_climb of 0.4, so the
## deck stays connected to the atrium floor and the Curator can walk onto it.
##
## The slab starts 8 mm above the lip's underside on purpose. Both used to
## begin at the assembly origin, which is 13.54 m2 of coplanar downward face
## and the second-largest z-fight in the atrium. The 8 mm is inside the lip
## (r 2.22 against the slab's 2.05) and is never seen; the deck top is
## unchanged at 0.24 so nothing standing on it moves.
static func _build_core_slab(root: Node3D) -> void:
	# lp_core_base is the lip, the deck and all eight hatch covers as one mesh.
	# Same radii as the primitives it replaces (2.22 / 2.05 / 1.72) because the
	# barrier ring, the floor signage and the three gantries are all surveyed
	# against them, and the same 0.240 deck top so nothing standing on it moves.
	#
	# The model is NOT in MapModels.NON_BLOCKING: its convex hull is the dais,
	# which is what the two CylinderShape3D colliders below described anyway,
	# and losing it would open a hole in the middle of the atrium navmesh.
	var dais := Models.place(root, "lp_core_base", Vector3.ZERO)
	if dais == null:
		_cyl(root, "Core Base Lip", Vector3(0, 0.055, 0), 2.22, 0.11,
			CONCRETE_DARK, 12, 0.0, 0.0, true)
		_cyl(root, "Core Base Slab", Vector3(0, 0.124, 0), 2.05, 0.232,
			CONCRETE, 12, 0.0, 0.0, true)
		# Radial hazard dashes at the deck edge: geometry, not a texture.
		for i in range(8):
			var a: float = TAU * float(i) / 8.0 + PI / 8.0
			_radial_box(root, "Core Deck Hatch %d" % i, a, 1.72, 0.254,
				Vector3(0.44, 0.014, 0.13), HAZARD, 0.10)
	else:
		dais.name = "Core Base"


## Two bolted drums with an open window band between them. The band is what
## makes the prop: eight shield ribs with 0.32 m slots, the core burning behind
## them. A slot is less than half the player capsule's 0.70 m diameter, so the
## cage seals the column without a hidden collider.
static func _build_core_column(root: Node3D) -> void:
	_cyl(root, "Core Shield Drum Lower", Vector3(0, 0.57, 0), 0.66, 0.66,
		STEEL, 12, 0.55, 0.0, true)
	_ring(root, "Core Drum Bolt Ring", Vector3(0, 0.34, 0), 0.66, 0.74,
		STEEL_DARK, 16)
	_cyl(root, "Core Shield Flange Lower", Vector3(0, 0.96, 0), 0.82, 0.12,
		STEEL_DARK, 12, 0.60)

	# Ribs sit on the half-step, so an open slot faces each of the four
	# doorways: walk in from any wing and you are looking straight into the
	# core, not at a plate. Verified by raycast -- an eyeline at 1.70 m from
	# z = 14, 8 and 5 reaches the core mesh unobstructed.
	for i in range(8):
		var a: float = TAU * float(i) / 8.0 + PI / 8.0
		_radial_box(root, "Core Shield Rib %d" % i, a, 0.64, 1.44,
			Vector3(0.14, 0.84, 0.18), IRON, 0.0, 0.50, true)
	_ring(root, "Core Cage Belt", Vector3(0, 1.44, 0), 0.70, 0.78, IRON, 16)

	_cyl(root, "Core Shield Flange Upper", Vector3(0, 1.92, 0), 0.82, 0.12,
		STEEL_DARK, 12, 0.60)
	_cyl(root, "Core Shield Drum Upper", Vector3(0, 2.30, 0), 0.66, 0.64,
		STEEL, 12, 0.55, 0.0, true)


## The two nodes GameManager drives, and the only part of the column that is
## never a model. Built whether lp_core_column landed or not, and at the same
## height either way: the model's rib cage leaves its inner faces at r 0.540
## and runs from local y 0.77 to 1.63, which is assembly y 1.01 to 1.87 -- the
## exact band the 0.86 m window occupies, with 40 mm of clearance.
##
## 1.8, up from 1.6, buys back the throw that the darker CORE_GLOW gave up:
## 0.58 * 1.8 = 1.044 puts green a hair over unity, so the sphere still carries
## a thin halo and is still the first thing seen from the entrance 15 m away,
## while the two channels that used to blow out (0.792 and 0.936) now stay
## inside the frame and the glow stays a colour instead of a flare.
static func _build_core_glow(root: Node3D) -> void:
	_sphere(root, CORE_NODE_NAME, Vector3(0, 1.44, 0), 0.33, CORE_GLOW, 1.8)
	_containment_window(root, Vector3(0, 1.44, 0), 0.50, 0.86)


## Containment status: eight cells around the upper drum, six live and two
## dead. The dead pair is recessed 7 cm and unlit, so the reading survives
## greyscale, colour blindness and the blackout -- count and depth carry it, not
## hue. Cells 6 and 7 sit at 270 and 315 deg: the arc from north round to the
## diagonal where the fourth service gantry was never built.
static func _build_core_status_ring(root: Node3D) -> void:
	_ring(root, "Core Status Ring", Vector3(0, 2.22, 0), 0.68, 0.86, IRON, 20)
	for i in range(8):
		var a: float = TAU * float(i) / 8.0
		var dead: bool = i == 6 or i == 7
		var radius: float = 0.72 if dead else 0.79
		var tint: Color = Color(0.085, 0.088, 0.092) if dead else HAZARD_BRIGHT
		var glow: float = 0.0 if dead else 1.8
		_radial_box(root, "Core Status Cell %d" % i, a, radius, 2.22,
			Vector3(0.10, 0.12, 0.15), tint, glow)


## Cap, collar and the four cable trunks that splay out to the ceiling. The
## trunks are what break the column's silhouette against the skylight.
static func _build_core_head_cap(root: Node3D) -> void:
	_cone(root, "Core Head Cap", Vector3(0, 2.74, 0), 0.66, 0.36, 0.24,
		STEEL_DARK, 12)
	_cyl(root, "Core Head Collar", Vector3(0, 2.95, 0), 0.40, 0.18,
		CONCRETE_DARK, 10)


## The four cable trunks that splay out to the ceiling. Always procedural:
## their length is derived per-map from the soffit height, so they cannot be
## baked into a mesh. They leave at y 3.00, which is inside lp_core_column's
## cap ring (assembly 2.98 .. 3.035), so they read as coming out of the head
## rather than as starting in mid-air above it.
static func _build_core_trunks(root: Node3D, trunk_top: float) -> void:
	for i in range(4):
		var a: float = TAU * float(i) / 4.0 + PI / 4.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		_beam(root, "Core Cable Trunk %d" % i, dir * 0.32 + Vector3(0, 3.00, 0),
			dir * 1.55 + Vector3(0, trunk_top, 0), 0.075, CABLE, 8)


## Three railed service catwalks on the diagonals, at 45, 135 and 225 degrees.
## The 315-degree quarter is empty on purpose: the fourth gantry was never
## built, which is also the quarter CAM 03 looks into from (13.6, 3.0, -12.6)
## and the quarter the two dead status cells face.
static func _build_core_gantries(root: Node3D) -> void:
	for i in range(3):
		var angle: float = 45.0 + 90.0 * float(i)
		var a: float = deg_to_rad(angle)
		var tag := "Gantry %d" % (i + 1)
		# lp_core_gantry is one mesh: kicked feet, two legs, the deck, three toe
		# boards and the whole guardrail. It is authored with the WALKWAY ALONG
		# ITS LOCAL Z and local +Z pointing AWAY from the core, standing on its
		# own floor -- so it goes on the base deck at y 0.24, at radius 1.36, and
		# the yaw follows from Godot sending local +Z to (sin y, 0, cos y) while
		# the outward radius is (cos a, 0, sin a): y = 90 - angle.
		#
		# "Along Z" is the load-bearing half of that sentence. Authored along X
		# instead -- which is how it shipped the first time -- the same yaw turns
		# the walkway into a tangential balcony at r 0.93 .. 1.79: 190 mm short of
		# the cage, 260 mm short of the slab edge, and clipping the south shutter
		# rails by 105 mm. tools/lowpoly/check_core_layout.py asserts all three.
		var deck := Models.place(root, "lp_core_gantry",
			Vector3(cos(a) * 1.36, 0.24, sin(a) * 1.36), 1.0, 90.0 - angle)
		if deck != null:
			deck.name = tag
			continue
		# Deck spans r 0.64 .. 2.08 at waist height, so it blocks rather than
		# invites -- there is no way up onto it, which is the point. The model
		# above reproduces this span exactly. Note that _radial_box takes size as
		# (radial, y, tangential), so the 1.44 below is the RADIAL run and the
		# 0.86 is the width underfoot -- the model has them the other way round in
		# its own axes, and that is not a discrepancy, it is the convention swap.
		_radial_box(root, "%s Deck" % tag, a, 1.36, 1.21,
			Vector3(1.44, 0.10, 0.86), Color(0.115, 0.120, 0.125), 0.0, 0.45, true)
		for s in range(2):
			var side: float = -1.0 + 2.0 * float(s)
			_radial_box(root, "%s Leg %d" % [tag, s], a, 1.92, 0.70,
				Vector3(0.15, 0.92, 0.15), STEEL_DARK, 0.0, 0.45, true,
				side * 0.32)
			_radial_box(root, "%s Rail Post %d" % [tag, s], a, 2.02, 1.75,
				Vector3(0.09, 0.98, 0.09), IRON, 0.0, 0.0, false, side * 0.38)
			_radial_box(root, "%s Side Rail %d" % [tag, s], a, 1.36, 2.20,
				Vector3(1.40, 0.07, 0.08), IRON, 0.0, 0.0, false, side * 0.40)
		_radial_box(root, "%s End Rail" % tag, a, 2.02, 2.20,
			Vector3(0.09, 0.07, 0.85), IRON)
		_radial_box(root, "%s Toe Board" % tag, a, 2.04, 1.32,
			Vector3(0.06, 0.12, 0.85), HAZARD, 0.08)


## Four blast shutter bays on the cardinal axes. Three read as retracted -- only
## the header housing is out. The south bay, the one the player walks straight
## into coming from the entrance, is jammed a third of the way down: five slats
## hanging to local y 1.60. The count is carried by geometry, not by paint:
## every lath is tapered so it leans away from the eye and drops a hard shadow
## line onto the one below it, and a recessed 7.5 mm gap separates them. That
## reads in greyscale, in colour blindness and in the blackout alike, which the
## old alternating hazard stripe only managed in the first of the three.
## Hazard paint survives on the bottom rail. The core glow still leaks out
## underneath.
static func _build_core_shutters(root: Node3D) -> void:
	for i in range(4):
		var a: float = TAU * float(i) / 4.0
		_radial_box(root, "Blast Shutter Header %d" % i, a, 1.70, 2.62,
			Vector3(0.30, 0.34, 1.50), STEEL_DARK, 0.0, 0.50, true)

	# South bay: +z, the entrance side.
	var south: float = PI * 0.5
	for i in range(2):
		var side: float = -1.0 + 2.0 * float(i)
		_radial_box(root, "Blast Shutter Rail %d" % i, south, 1.70, 1.35,
			Vector3(0.13, 2.20, 0.13), IRON, 0.0, 0.45, true, side * 0.70)
	# Lowest slat bottoms out at local y 1.60. Standing on the 0.40 deck the
	# player is stopped by it; the eyeline from the entrance doorway passes
	# 14 cm under it, so the core is still framed by the half-open bay.
	#
	# The curtain is a single model now. Five flat boxes painted alternately
	# hazard and near-black read from the gantry as a striped BILLBOARD leaning
	# against the core -- no depth, no shadow, just a sign. lp_blast_shutter
	# keeps the same 1.34 x 0.86 x 0.15 envelope but tapers every lath and
	# recesses a shadow gap between them, so the same five laths read as a
	# jammed shutter. Yaw 180 turns the model's -Z public face out towards the
	# entrance; the model's origin is its own floor, so the 1.60 below is the
	# underside of the bottom rail exactly, not a centre.
	var curtain := Models.place(root, "lp_blast_shutter",
		Vector3(0, 1.60, 1.70), 1.0, 180.0)
	if curtain == null:
		for s in range(5):
			var slat_y: float = 2.38 - 0.175 * float(s)
			var tint: Color = HAZARD if s % 2 == 1 else Color(0.130, 0.135, 0.140)
			_radial_box(root, "Blast Shutter Slat %d" % s, south, 1.70, slat_y,
				Vector3(0.14, 0.16, 1.34), tint, 0.0, 0.40, true)
	else:
		curtain.name = "Blast Shutter Curtain"


## The service pass. The column had a silhouette and nothing that said the
## machine is plumbed in: no fasteners, no pipework, no heat rejection and
## nothing at all above the collar. Every part below is either surface detail
## on a drum or sits under the window band, so the four cardinal sightlines
## into the core are exactly as open as they were, and none of it takes a
## collider -- the drums and the rib cage already seal the column.
static func _build_core_service(root: Node3D) -> void:
	# Flange bolts, sixteen a flange at r 0.84. The cheapest detail there is: a
	# smooth steel disc becomes a disc somebody bolted down.
	for i in range(16):
		var a: float = TAU * float(i) / 16.0
		_radial_box(root, "Core Flange Bolt Lower %d" % i, a, 0.84, 0.96,
			Vector3(0.07, 0.07, 0.07), STEEL_DARK, 0.0, 0.55)
		_radial_box(root, "Core Flange Bolt Upper %d" % i, a, 0.84, 1.92,
			Vector3(0.07, 0.07, 0.07), STEEL_DARK, 0.0, 0.55)
	# Heat rejection fins round the upper drum. They stop under the status ring
	# at 2.22 so they never cut into a status cell, which has to stay countable.
	for i in range(24):
		var a: float = TAU * float(i) / 24.0
		_radial_box(root, "Core Heat Fin %d" % i, a, 0.72, 2.05,
			Vector3(0.12, 0.26, 0.035), STEEL_DARK, 0.0, 0.45)
	# Coolant loop. y 0.86 is the load-bearing number: the window band starts at
	# 1.02 and a standing eyeline is 1.70, so the loop passes under the view from
	# every doorway. r 0.92 clears the lower flange at 0.82 and the gantry legs
	# do not start until 1.92, so it fouls nothing.
	var loop := _ring(root, "Core Coolant Loop", Vector3(0, 0.86, 0),
		0.92, 1.04, STEEL_DARK, 24)
	loop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The coolant plant: two skids in the gantry-free quarter.
##
## This is what the rejected primitive service rig was reaching for. Same parts
## -- pump, motor, handwheel, tank, riser, junction box -- but lp_core_plant is
## one object standing on one skid, instead of thirty loose cylinders floating
## at radii that touched nothing.
##
## 279 AND 351 ARE NOT THE OLD 292.5 AND 337.5, AND THEY ARE NOT 285 AND 345
## EITHER. A skid is 0.90 m wide AND 0.52 m deep at radius 1.20, so its inner
## corners subtend 51 deg, not the 41 deg the width alone suggests. CAM 03 sits
## at (13.6, 3.0, -12.6), i.e. on the 317.2 deg ray, and the sector that has to
## stay open is 305..325. At 285 and 345 the skids ate into that sector from
## both sides and left an 8.8 deg slot with 2.2 deg of margin on the camera
## ray; 279 and 351 clear it completely. They are also the OUTERMOST angles
## available, because going further walks the skid into the 225 deg gantry --
## there is 21 mm between them as it stands. Do not tidy these to round
## numbers, and do not widen them.
##
## tools/lowpoly/check_core_layout.py solves both bounds and asserts them.
##
## The thin primitive risers in the fallback keep their original 292.5 / 337.5,
## and that part is safe: at r 0.98 a 0.055 pipe subtends 3.2 deg, so they sit
## at 289.3..295.7 and 334.3..340.7 and never reach the window.
##
## The REST of the fallback is not clear, and this comment used to imply it was.
## The valve wheel (315 deg, r 0.98, outer 0.16) covers 305.6..324.4, and the
## three cable coils (315 deg, r 1.62, outer 0.32) cover 303.6..326.4 -- they
## straddle the whole window and sit right on the 317.2 ray. They are low: the
## coils live at y 0.29..0.38 and the wheel tops out at 1.22, so from CAM 03 at
## y 3.0 they clip the plinth rather than the core body, and none of it draws
## unless the .glb failed to load. Tolerated, not correct.
##
## check_core_layout.py models the MODEL layout only. It will not catch a
## regression in here.
static func _build_core_plant(root: Node3D) -> void:
	var placed := 0
	for deg: float in [279.0, 351.0]:
		var a: float = deg_to_rad(deg)
		var skid := Models.place(root, "lp_core_plant",
			Vector3(cos(a) * 1.20, 0.24, sin(a) * 1.20), 1.0, 90.0 - deg)
		if skid == null:
			break
		skid.name = "Core Coolant Skid %d" % int(deg)
		placed += 1
	if placed > 0:
		return

	# Fallback: the primitive plant, unchanged.
	for deg: float in [292.5, 337.5]:
		var a: float = deg_to_rad(deg)
		var foot := Vector3(cos(a) * 0.98, 0.86, sin(a) * 0.98)
		var head := Vector3(foot.x, 1.95, foot.z)
		_beam(root, "Core Coolant Riser %d" % int(deg), foot, head, 0.055,
			STEEL_DARK, 8)
		_beam(root, "Core Coolant Elbow %d" % int(deg), head,
			Vector3(cos(a) * 0.80, 1.95, sin(a) * 0.80), 0.055, STEEL_DARK, 8)
	var wheel_a: float = deg_to_rad(315.0)
	var stem := Vector3(cos(wheel_a) * 0.98, 1.02, sin(wheel_a) * 0.98)
	_beam(root, "Core Valve Stem", Vector3(stem.x, 0.86, stem.z), stem, 0.035,
		IRON, 6)
	var wheel := _ring(root, "Core Valve Wheel", Vector3(stem.x, 1.06, stem.z),
		0.11, 0.16, IRON, 12)
	wheel.basis = Basis(Vector3.UP, -wheel_a) * Basis(Vector3.RIGHT, PI * 0.5)
	for i in range(3):
		var coil := _ring(root, "Core Cable Coil %d" % i,
			Vector3(cos(wheel_a) * 1.62, 0.29 + 0.045 * float(i),
				sin(wheel_a) * 1.62), 0.22, 0.32, CABLE, 14)
		coil.scale.y = 0.45
		coil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Rotating beacon on a bracket off the head cap: the only thing on the core
## above the collar, so it is what breaks the silhouette against the skylight
## from the far end of the room. Always procedural -- the lamp is emissive and
## nothing in the lp_ pipeline emits.
static func _build_core_beacon(root: Node3D) -> void:
	_box(root, "Core Beacon Bracket", Vector3(0.52, 2.80, 0.0),
		Vector3(0.34, 0.05, 0.09), STEEL_DARK, 0.0, 0.50)
	_cyl(root, "Core Beacon Base", Vector3(0.66, 2.86, 0.0), 0.075, 0.07,
		IRON, 8, 0.40)
	_cyl(root, "Core Beacon Lamp", Vector3(0.66, 2.96, 0.0), 0.085, 0.14,
		HAZARD_BRIGHT, 8, 0.0, 1.50)
	_cyl(root, "Core Beacon Cap", Vector3(0.66, 3.05, 0.0), 0.090, 0.04,
		STEEL_DARK, 8, 0.50)


## Lectern plaque on the south edge of the slab, angled up at the reader.
## Pale text on a near-black plate: 13.4:1, well past the 4.5:1 floor.
static func _build_core_plaque(root: Node3D) -> void:
	_box(root, "Core Plaque Post", Vector3(0, 0.36, 2.40),
		Vector3(0.12, 0.72, 0.12), STEEL_DARK, 0.0, 0.5, true)
	# Plate widened 0.86 -> 1.00. At 0.86 the label's wrap box was 0.80 m, which
	# is 228 px at pixel_size 0.0035, and the second line of the Russian string
	# ("СДЕРЖИВАНИЯ", 11 glyphs at font_size 40) needs about 264 px -- so it was
	# rendering clipped, as "ЦЕНТР / СДЕРЖИВА", in every frame of the atrium
	# focus pass. Label3D crops rather than shrinks, so the plate has to grow.
	var plate := _box(root, "Core Plaque Plate", Vector3(0, 0.86, 2.40),
		Vector3(1.00, 0.46, 0.05), PANEL)
	# -32 deg pitch tips the plate's +z face up towards a reader standing south
	# of it; the label rides the same basis, so it needs no rotation of its own.
	plate.rotation_degrees = Vector3(-32, 0, 0)
	# 36 px inside a 0.94 m wrap box = 268 px of room for a ~238 px line, with
	# both lines together 0.29 m tall inside a 0.46 m plate.
	_label(plate, _tr("EXHIBIT_CONTAINMENT_CORE"), Vector3(0, 0.02, 0.032),
		SIGN_TEXT, 36, 0.0035, 0.94)


## The force-field window over the core. Cylindrical rather than the old cube so
## it sits inside the rib cage, with the shader applied under the same guard
## chain FirstMuseumMap._apply_dome_shader() used: absent shader means plain
## glass, and GameManager falls back to hiding the mesh on a breach.
static func _containment_window(parent: Node3D, window_position: Vector3,
		radius: float, height: float) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.radial_segments = 12
	mesh.rings = 0
	var inst := MeshInstance3D.new()
	inst.name = DOME_NODE_NAME
	inst.position = window_position
	inst.mesh = mesh
	inst.visibility_range_end = VISIBILITY_RANGE
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	inst.material_override = _glass_material()
	parent.add_child(inst)

	if not ResourceLoader.exists(DOME_SHADER):
		return inst
	var shader: Shader = load(DOME_SHADER)
	if shader == null:
		return inst
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("damage", 0.0)
	inst.material_override = mat
	return inst


# =============================================================================
#  Cable runs
# =============================================================================

## Ceiling trays from the core head out to four anchor points, then a downpipe
## and a junction box at each anchor. In the atrium the anchors are the rotunda
## columns at (+-11.5, +-11.5), which is why the core's cable trunks leave on
## the diagonals: the museum's power visibly comes out of the core and walks
## down the columns.
##
## `origin` is the floor point the runs are centred on. `anchors` are offsets
## from it; an empty array uses the four rotunda columns. Nothing here gets
## collision -- every part is either overhead or flush against a column.
##
## Bounding box with the default anchors: 23.21 x 2.63 x 23.21 m, y from
## origin.y + 0.74 to origin.y + 3.37.
static func build_cable_runs(parent: Node3D, origin: Vector3,
		anchors: Array = [], ceiling_y := 3.39) -> Node3D:
	var root := _root(parent, "Atrium Cable Runs", origin)
	var points: Array = anchors
	if points.is_empty():
		points = [
			Vector3(11.5, 0, 11.5), Vector3(-11.5, 0, 11.5),
			Vector3(-11.5, 0, -11.5), Vector3(11.5, 0, -11.5),
		]
	var tray_y: float = ceiling_y - origin.y - 0.09
	for i in range(points.size()):
		var anchor: Vector3 = points[i]
		var flat := Vector3(anchor.x, 0.0, anchor.z)
		var span: float = flat.length()
		if span < 2.0:
			continue
		var dir := flat / span
		var start: float = 1.55
		var mid: float = (start + span) * 0.5
		var tray := _box(root, "Cable Tray %d" % i,
			Vector3(dir.x * mid, tray_y, dir.z * mid),
			Vector3(span - start, 0.13, 0.30), CABLE, 0.0, 0.35)
		tray.rotation.y = -atan2(dir.z, dir.x)
		# 15 m of ceiling trunking is not worth four more shadow casters.
		tray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Down the inside face of the anchor column to a junction box.
		var down := flat - dir * 0.52
		_beam(root, "Cable Downpipe %d" % i,
			Vector3(down.x, tray_y - 0.06, down.z),
			Vector3(down.x, 1.22, down.z), 0.09, CABLE, 8)
		var junction := _box(root, "Cable Junction Box %d" % i,
			Vector3(down.x, 0.98, down.z), Vector3(0.36, 0.48, 0.26),
			STEEL_DARK, 0.0, 0.45, true)
		junction.rotation.y = -atan2(dir.z, dir.x)
		var latch := _box(root, "Cable Junction Latch %d" % i,
			Vector3(down.x, 0.98, down.z), Vector3(0.10, 0.16, 0.30), IRON)
		latch.rotation.y = -atan2(dir.z, dir.x)
	return root


# =============================================================================
#  Barrier ring
# =============================================================================

## Rope barrier around the core. Heavier than the museum's generic stanchions:
## cast bases, sagging rope in two segments per span, and one span missing --
## its rope is coiled on the floor where somebody unhooked it and stepped over.
##
## Circumscribed diameter 2 * radius + 0.34, so 7.14 m at the default radius;
## the measured AABB is 6.62 x 1.07 x 6.62 m because the posts are offset half
## a step and none of them lands on an axis. Nothing here has collision: the
## rope is waist height and the posts are 6 cm across, so colliders would only
## snag the player without ever reading as a wall.
static func build_rope_barrier(parent: Node3D, origin: Vector3,
		radius := 3.40, posts := 8) -> Node3D:
	var root := _root(parent, "Core Barrier Ring", origin)
	var count: int = maxi(4, posts)
	var tops: Array[Vector3] = []
	for i in range(count):
		var a: float = TAU * float(i) / float(count) + PI / float(count)
		var p := Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		# lp_stanchion carries the cast base, the tapered post, the collar and the
		# brass finial as one 106-tri mesh, so the three primitives below are the
		# fallback rather than something placed alongside it.
		#
		# The yaw turns the model's rope eyes (local +-Z) along the run instead of
		# at the core. Godot maps local +Z to (sin y, 0, cos y); the tangent to the
		# ring at angle a is (-sin a, 0, cos a); equating the two gives y = -a.
		var stanchion := Models.place(root, "lp_stanchion", p, 1.0,
			-rad_to_deg(a))
		# Where the rope lands depends on which stanchion you got. The fallback's
		# brass cap is a sphere centred at 1.00, so 0.96 hooks the rope over the top
		# of it. The model is a different object: it tops out at 0.947 and carries
		# real rope eyes at 0.868, and those eyes are the entire reason for the yaw
		# computed above. Leaving the rope at 0.96 floated it 1.3 cm clear of the
		# finial and 9 cm above the eyes it was supposed to thread, so the ring was
		# aimed correctly at nothing.
		var rope_y := 0.96
		if stanchion == null:
			_cyl(root, "Barrier Base %d" % i, p + Vector3(0, 0.025, 0), 0.17, 0.05,
				CONCRETE_DARK, 8)
			_cyl(root, "Barrier Post %d" % i, p + Vector3(0, 0.50, 0), 0.033, 0.95,
				IRON, 6)
			_sphere(root, "Barrier Cap %d" % i, p + Vector3(0, 1.00, 0), 0.052, BRASS)
		else:
			stanchion.name = "Barrier Stanchion %d" % i
			rope_y = 0.868
		tops.append(p + Vector3(0, rope_y, 0))

	# Span 0 is the missing one; its rope is on the floor just inside the ring.
	for i in range(1, count):
		var a0: Vector3 = tops[i]
		var b0: Vector3 = tops[(i + 1) % count]
		var sag := (a0 + b0) * 0.5 - Vector3(0, 0.11, 0)
		_beam(root, "Barrier Rope %d A" % i, a0, sag, 0.017, Color(0.30, 0.075, 0.065), 6)
		_beam(root, "Barrier Rope %d B" % i, sag, b0, 0.017, Color(0.30, 0.075, 0.065), 6)

	var slack_a: Vector3 = tops[0] * 0.94
	var slack_b: Vector3 = tops[1] * 0.94
	slack_a.y = 0.028
	slack_b.y = 0.028
	var bend: Vector3 = (slack_a + slack_b) * 0.5
	bend = bend.normalized() * (bend.length() - 0.55)
	bend.y = 0.028
	_beam(root, "Barrier Rope Fallen A", slack_a, bend, 0.017, Color(0.26, 0.065, 0.055), 6)
	_beam(root, "Barrier Rope Fallen B", bend, slack_b, 0.017, Color(0.26, 0.065, 0.055), 6)
	_sphere(root, "Barrier Rope Fallen Hook", bend, 0.045, BRASS)
	return root


# =============================================================================
#  Floor signage
# =============================================================================

## Painted floor graphics: a hazard hatch collar around the core slab, a raised
## containment perimeter strip, and eight chevrons on the four cardinal axes
## pointing out towards the four doorways. Direction is carried by the arrow
## shape, not by the paint colour. All of it is 1.4 cm proud of the floor with
## no collision, so it never touches navigation.
##
## Bounding box (2 * perimeter + 0.08) x 0.08 x (2 * perimeter + 0.08).
## Default: 9.48 x 0.08 x 9.48 m, all of it between y 0.00 and y 0.08.
static func build_floor_signage(parent: Node3D, origin: Vector3,
		hatch_radius := 2.45, perimeter := 4.70) -> Node3D:
	var root := _root(parent, "Atrium Floor Signage", origin)
	# Diagonal hazard hatching, 20 dashes, each canted 35 deg off radial.
	for i in range(20):
		var a: float = TAU * float(i) / 20.0
		_radial_box(root, "Atrium Hazard Hatch %d" % i, a, hatch_radius, 0.012,
			Vector3(0.42, 0.014, 0.16), HAZARD, 0.10, 0.0, false, 0.0,
			deg_to_rad(35.0))
	var band := _ring(root, "Atrium Containment Perimeter", Vector3(0, 0.022, 0),
		perimeter - 0.04, perimeter + 0.04, HAZARD, 32, 0.10)
	# A 9.5 m ring lying flat clears the size threshold in _attach, but paint on
	# the floor has no business in the shadow map.
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Two chevrons per exit axis, the outer one larger.
	for i in range(4):
		var a: float = TAU * float(i) / 4.0
		_chevron(root, "Atrium Wayfinding Chevron %d Near" % i, a, 3.45, 0.012,
			0.46, 0.34, BRASS)
		_chevron(root, "Atrium Wayfinding Chevron %d Far" % i, a, 3.98, 0.012,
			0.62, 0.44, BRASS)
	return root


# =============================================================================
#  Rotunda benches
# =============================================================================

## The four-seater that stands on each rotunda diagonal: two cast-iron end
## frames, a slatted timber seat, a slatted back, timber arms and brass foot
## plates.
##
## IT REPLACES лавочки.glb. That model is authored as a BACK-TO-BACK pair, so
## every placement of it put one bench facing the core and a second one facing
## the wall behind it. The map worked around that by finding the child node
## "BenchB_m_benchB_0" after each placement and setting visible = false, which
## left half a model, carrying its own imported materials, in a room where every
## other prop is built from the palette at the top of this file. The parts below
## are the same bench in the same iron, timber and brass as the rope barrier and
## the reception desk, so the four of them read as one set of museum furniture.
##
## Local axes: +x is the length, +z is the BACK. With the origin on a radius and
## facing_deg = -(angle + 90) the back goes to the wall and the seat looks at
## the containment core -- the one thing in this room worth sitting to look at.
##
## Bounding box 3.34 x 1.03 x 0.78 m; seat top y 0.45, back rail top y 1.03.
## ONE collider, a 3.40 x 0.47 x 0.70 box round the seat volume: the slats, the
## arms and the back are decoration, and a body each would only litter the bake.
static func build_rotunda_bench(parent: Node3D, origin: Vector3,
		facing_deg := 0.0, tag := "") -> Node3D:
	var node_name := "Rotunda Bench"
	if not tag.is_empty():
		node_name = "Rotunda Bench %s" % tag
	var root := _root(parent, node_name, origin)
	root.rotation_degrees.y = facing_deg

	# Seat: five boards on a 0.13 pitch, 2.5 cm of daylight between them. Slats
	# rather than a slab because a slab at this size reads as a kerb.
	for i in range(5):
		var seat_z: float = -0.26 + 0.13 * float(i)
		_box(root, "Bench Seat Slat %d" % i, Vector3(0, 0.455, seat_z),
			Vector3(3.28, 0.05, 0.105), WOOD)
	# Back: three boards stepping outward as they rise, each on a 5.5 deg lean.
	for i in range(3):
		var back_y: float = 0.63 + 0.16 * float(i)
		var slat := _box(root, "Bench Back Slat %d" % i,
			Vector3(0, back_y, 0.270 + 0.015 * float(i)),
			Vector3(3.28, 0.13, 0.045), WOOD)
		slat.rotation_degrees.x = -5.5

	for side: float in [-1.0, 1.0]:
		var end_tag: String = "West" if side < 0.0 else "East"
		var x: float = side * 1.48
		# End frame: two legs, the rail they carry the seat on, the back post.
		_box(root, "Bench Leg Front %s" % end_tag, Vector3(x, 0.215, -0.20),
			Vector3(0.09, 0.43, 0.10), IRON)
		_box(root, "Bench Leg Rear %s" % end_tag, Vector3(x, 0.215, 0.22),
			Vector3(0.09, 0.43, 0.10), IRON)
		_box(root, "Bench Frame Rail %s" % end_tag, Vector3(x, 0.415, 0.01),
			Vector3(0.08, 0.07, 0.64), IRON)
		_box(root, "Bench Back Post %s" % end_tag, Vector3(x, 0.73, 0.315),
			Vector3(0.08, 0.60, 0.07), IRON)
		# Armrest on one front bracket, timber to match the seat.
		_box(root, "Bench Arm %s" % end_tag, Vector3(side * 1.46, 0.70, -0.01),
			Vector3(0.07, 0.06, 0.60), WOOD)
		_box(root, "Bench Arm Bracket %s" % end_tag,
			Vector3(side * 1.46, 0.57, -0.25), Vector3(0.06, 0.30, 0.06), IRON)
		# Brass foot plate: the museum bolts its benches to the floor.
		_box(root, "Bench Foot Plate %s" % end_tag, Vector3(x, 0.012, 0.0),
			Vector3(0.17, 0.024, 0.68), BRASS, 0.0, 0.4)

	_box(root, "Bench Stretcher", Vector3(0, 0.155, 0.01),
		Vector3(2.86, 0.06, 0.06), IRON)
	_box(root, "Bench Back Rail", Vector3(0, 1.00, 0.315),
		Vector3(3.04, 0.06, 0.075), IRON)
	_collider(root, "Bench Body", Vector3(0, 0.235, 0.0),
		Vector3(3.40, 0.47, 0.70))
	return root


# =============================================================================
#  Atrium floor
# =============================================================================

# Floor tints. They are down here rather than in the palette block at the top
# because nothing but the floor uses them, and because _pack_for() must never
# match them: these are tints applied to a named MaterialLib pack, not prop
# colours looking for a pack.
const FLOOR_FIELD := Color(0.745, 0.735, 0.705)
const FLOOR_WARM := Color(0.790, 0.760, 0.690)
const FLOOR_DARK := Color(0.300, 0.305, 0.300)
const FLOOR_BORDER := Color(0.345, 0.340, 0.330)
const FLOOR_JOINT := Color(0.255, 0.255, 0.245)
const FLOOR_TRIM := Color(0.520, 0.440, 0.240)

## How far the rotunda kerb ring (r 5.8) sits BELOW the mosaic plate (r 4.9)
## that stands on it. The two used to top out at the same 0.16, which put
## 77.36 m2 of kerb top face in exactly the plane of the plate above it --
## the largest z-fight on the map and the shimmer seen when panning across
## the atrium. FirstMuseumMap now builds the kerb 0.15 tall to match, so the
## plate edge reads as a 1 cm reveal instead of fighting for the same depth.
## Anything placed on the kerb annulus must measure from dais_y - KERB_DROP.
const KERB_DROP := 0.010

## The stone floor of the atrium: a medallion on the rotunda plate and a slab
## layout across the field around it.
##
## EVERYTHING HERE IS INLAY. The floor itself already exists -- the map builds
## Кольцо ротонды (r 5.8, top y 0.15) and Пол ротонды (r 4.9, top y 0.16)
## on a 30 x 30 m field at y 0 -- so this function only lays bands,
## wedges and joints on top of it, between 0.4 and 2.4 cm proud, with no
## collision anywhere. Navigation, the 1.8 m doorway channels and the bake are
## untouched by construction, not by luck.
##
## Two rules kept the pattern out of trouble:
##   * The plate already carries paint. build_floor_signage() owns the hazard
##     hatching at r 2.45 (dashes reach 2.66), the chevrons at 3.45 and 3.98
##     (which reach 3.28 and 4.20) and the perimeter band at 4.70 (4.66..4.74),
##     so the inlay only uses the rings those leave free: 2.70-3.26 for the
##     sunburst and 4.31-4.64 for the border.
##   * No two pieces share a height. Two coplanar faces at the same y is the
##     definition of z-fighting, and a floor is the easiest place to see it.
##
## Tone comes from MaterialLib packs rather than from the palette: travertine
## for the light field, quartzite for the dark bands, mosaic for the medallion
## tiles, painted_metal for the brass trim.
## models/modern_grey_stone_tile_texture.glb is deliberately NOT used here --
## see the note at the end of _add_model_archive(): it is a 920 m texture swatch
## buried 7 m under the museum, a material sample and not a floor.
static func build_atrium_floor(parent: Node3D, origin: Vector3,
		dais_y := 0.16) -> Node3D:
	var root := _root(parent, "Atrium Floor", origin)
	_build_floor_field(root)
	_build_floor_medallion(root, dais_y)
	return root


## The field outside the rotunda: slab joints, a border band round the walls,
## a runner out to each doorway and a plinth square under each column.
##
## Tones, not photo packs. The slab under all of this is already wearing a
## stone map; a second map on top of it at a different scale is what read as a
## texture inside a texture up close, and at a grazing angle its high-frequency
## detail is what crawled. _floor_plate defaults to a flat tint now.
##
## Every visible top face has its own height, and no two that can overlap share
## one. The crossing pairs are what matter: the two joint directions cross at
## sixteen points and the two brass trims at four, so each pair is 2 mm apart.
static func _build_floor_field(root: Node3D) -> void:
	# Slab joints on a 3 m grid, stopping 2.5 cm short of the border band. They
	# pass UNDER the rotunda kerb, which is a solid 0.15 m disc, so the middle of
	# each line is inside it and never seen.
	for i in range(4):
		var d: float = 3.0 + 3.0 * float(i)
		for side: float in [-1.0, 1.0]:
			var at: float = side * d
			_floor_plate(root, "Floor Joint NS %s" % at,
				Vector3(at, 0.016, 0.0), Vector3(0.05, 0.0, 27.4),
				FLOOR_JOINT)
			_floor_plate(root, "Floor Joint WE %s" % at,
				Vector3(0.0, 0.014, at), Vector3(27.4, 0.0, 0.05),
				FLOOR_JOINT)
	# A dark band round all four walls, the way a gallery frames a floor. The two
	# pairs stop short of each other instead of overlapping at the corners.
	for side: float in [-1.0, 1.0]:
		_floor_plate(root, "Floor Border NS %s" % side,
			Vector3(0.0, 0.008, side * 14.15), Vector3(29.3, 0.0, 0.85),
			FLOOR_BORDER)
		_floor_plate(root, "Floor Border WE %s" % side,
			Vector3(side * 14.15, 0.008, 0.0), Vector3(0.85, 0.0, 27.4),
			FLOOR_BORDER)
		# Brass trim 8 cm inside the band.
		_floor_plate(root, "Floor Border Trim NS %s" % side,
			Vector3(0.0, 0.020, side * 13.62), Vector3(27.3, 0.0, 0.05),
			FLOOR_TRIM)
		_floor_plate(root, "Floor Border Trim WE %s" % side,
			Vector3(side * 13.62, 0.018, 0.0), Vector3(0.05, 0.0, 27.3),
			FLOOR_TRIM)
	# A runner from the kerb out to each of the four doorways: 2.6 m of warmer
	# stone against a 1.8 m door gap, so it reads as the route. The map's brass
	# axis strips sit at y 0.015, so the runner tops out at 6 mm and passes under
	# them instead of arguing with them.
	for i in range(4):
		var a: float = TAU * float(i) / 4.0
		_floor_radial(root, "Floor Runner %d" % i, a, 10.25, 0.006,
			Vector3(8.70, 0.0, 2.60), FLOOR_WARM)
	# The four columns stand in open floor; a plinth square each gives them a
	# reason to be where they are.
	for p: Vector3 in [Vector3(-11.5, 0, -11.5), Vector3(11.5, 0, -11.5),
			Vector3(-11.5, 0, 11.5), Vector3(11.5, 0, 11.5)]:
		_floor_plate(root, "Floor Column Plinth %s" % p,
			Vector3(p.x, 0.008, p.z), Vector3(1.90, 0.0, 1.90),
			FLOOR_BORDER)
		_floor_plate(root, "Floor Column Inlay %s" % p,
			Vector3(p.x, 0.013, p.z), Vector3(1.42, 0.0, 1.42),
			FLOOR_WARM)


## The rotunda plate is already carrying build_floor_signage's twenty hazard
## dashes, eight chevrons and the containment perimeter band. The first pass
## answered "the floor is not finished" by adding a 24-wedge sunburst, 32
## border tiles and eight kerb setts in the gaps between them: sixty-odd small
## light rectangles, each carrying its own photo texture on top of the plate's
## own, which from the entrance read as confetti rather than as a floor.
##
## So this pass is subtraction. Four brass fillets, one in each radial gap the
## signage leaves free, and nothing else:
##
##   hatching out to 2.66 | RING 2.86..2.94 | chevrons 3.28..4.20
##   | RING 4.36..4.44 | perimeter band 4.66..4.74 | plate edge 4.90
##   | kerb annulus: RING 5.02..5.08 and RING 5.66..5.72 | kerb edge 5.80
static func _build_floor_medallion(root: Node3D, dais_y: float) -> void:
	var kerb_y: float = dais_y - KERB_DROP
	_floor_ring(root, "Floor Medallion Fillet", dais_y + 0.012, 2.86, 2.94)
	_floor_ring(root, "Floor Medallion Edge", dais_y + 0.012, 4.36, 4.44)
	# The kerb annulus (plate r 4.9 out to kerb r 5.8, one KERB_DROP below the
	# plate) is bare walkable stone; two thin fillets give it the same
	# family of detail without narrowing the step up.
	_floor_ring(root, "Floor Kerb Fillet Inner", kerb_y + 0.009, 5.02, 5.08)
	_floor_ring(root, "Floor Kerb Fillet Outer", kerb_y + 0.009, 5.66, 5.72)


# =============================================================================
#  Reception desk
# =============================================================================

## Atrium reception: the lp_reception_counter model with a procedural return
## wing beside it, a dead monitor pair, an abandoned visitor log and a keycard
## left on the ledge, under a sign hung from the ceiling on two rods. Front face
## is local +z; `facing_deg` yaws the whole thing, so 0 faces the entrance
## doorway at z = +15.
##
## The counter is the model and measures 3.920 x 1.100 x 1.240. That 1.100 is
## load-bearing: the log book, the keycard, both monitors and the task lamp are
## all placed against it, so changing the model's height silently floats every
## one of them. The return wing carries the envelope out to x = -2.21 and
## z = -1.69, and the hanging sign takes the height to ceiling_y.
##
## Do not quote a furniture AABB from this comment. The batch 3 model replaced
## the three boxes that used to stand here and changed the depth; the old
## 4.17 x 1.60 x 2.44 figure is dead. Measure it if you need it.
static func build_reception_desk(parent: Node3D, origin: Vector3,
		facing_deg := 0.0, ceiling_y := 3.39) -> Node3D:
	var root := _root(parent, "Atrium Reception", origin)
	root.rotation_degrees.y = facing_deg

	# One mesh for carcass + fascia + stone top. The model's public face is its
	# local -Z and this root's is local +Z, hence the 180 deg yaw. Its worktop is
	# at y = 1.10, the same height the old Counter Top presented, so the log
	# book, keycard, monitors and lamp below need no adjustment.
	var counter := Models.place(root, "lp_reception_counter", Vector3.ZERO,
		1.0, 180.0)
	if counter == null:
		_box(root, "Reception Counter Body", Vector3(0, 0.50, 0),
			Vector3(3.60, 1.00, 0.86), WOOD, 0.0, 0.0, true)
		_box(root, "Reception Counter Fascia", Vector3(0, 0.62, 0.445),
			Vector3(3.30, 0.60, 0.04), Color(0.175, 0.145, 0.110))
		_box(root, "Reception Counter Top", Vector3(0, 1.05, 0),
			Vector3(3.92, 0.10, 1.10), COUNTER_STONE, 0.0, 0.10, true)
	else:
		counter.name = "Reception Counter"
	# Pulled in twice now: 0.60 -> 0.55 -> 0.47. At 0.55 the shelf's REAR edge
	# did meet the carcass front at z 0.40, but its FRONT edge ran out to z 0.70,
	# 80 mm proud of the worktop lip at 0.62 -- and metallic 0.2 made that
	# overhang pick up the cold atrium fill as a pale bar straight across the
	# desk. From the entrance it read as a lit stripe painted on a black box.
	# At 0.47 the shelf spans 0.32..0.62: buried 80 mm in the carcass, flush
	# with the lip, no overhang to catch light. Matte dark timber, not steel.
	_box(root, "Reception Transaction Shelf", Vector3(0, 0.78, 0.47),
		Vector3(3.40, 0.07, 0.30), Color(0.088, 0.070, 0.048), 0.0, 0.0, true)

	_box(root, "Reception Return Body", Vector3(-1.72, 0.50, -1.03),
		Vector3(0.86, 1.00, 1.20), WOOD, 0.0, 0.0, true)
	# Крышка крыла на 2 мм ниже столешницы стойки (1.098 против 1.100).
	# Ровно на 1.100 они давали 0.18 м2 общей плоскости в месте стыка —
	# две каменные плиты на одной глубине прямо перед входом. Два миллиметра
	# убирают спор: в месте перекрытия верх крыла уходит внутрь столешницы
	# и не рисуется вообще, а ступенька в 2 мм с роста человека не читается.
	_box(root, "Reception Return Top", Vector3(-1.72, 1.048, -1.03),
		Vector3(0.98, 0.10, 1.32), COUNTER_STONE, 0.0, 0.10, true)

	for i in range(2):
		var side: float = -1.0 + 2.0 * float(i)
		# The same lp_desk_monitor the Watcher Office desk set uses, so reception
		# and the office are visibly the same product. It ships its own moulded
		# foot and stalk, which is why the stand box is inside the fallback and
		# not placed next to the model. It stands ON the worktop at y = 1.10, its
		# screen already faces local -Z (the clerk, not the public), and its head
		# is tipped back 7 deg in the mesh -- so no rotation is applied here.
		var monitor := Models.place(root, "lp_desk_monitor",
			Vector3(side * 0.90, 1.10, -0.14))
		if monitor == null:
			_box(root, "Reception Monitor Stand %d" % i,
				Vector3(side * 0.90, 1.17, -0.14),
				Vector3(0.10, 0.15, 0.14), STEEL_DARK, 0.0, 0.5)
			var screen := _box(root, "Reception Monitor %d" % i,
				Vector3(side * 0.90, 1.32, -0.14), Vector3(0.50, 0.34, 0.05),
				Color(0.028, 0.032, 0.036), 0.0, 0.30)
			screen.rotation_degrees = Vector3(-14, 0, 0)
		else:
			monitor.name = "Reception Monitor %d" % i
		# Two screens and nothing to type on: the c2 desk-top frame showed a pair
		# of monitors standing on bare stone. lp_keyboard is authored the same way
		# as the monitor -- origin on its standing surface, facing -Z -- so it
		# keeps the same zero yaw and sits 0.36 m clerk-side of its screen, the
		# spacing the office workstation already uses (monitor z -2.06, keyboard
		# z -1.70). At z -0.50 the 0.15 m deep model clears the monitor foot and
		# still lands inside the counter's rear edge at z -0.62.
		var keyboard := Models.place(root, "lp_keyboard",
			Vector3(side * 0.90 - 0.04, 1.10, -0.50))
		if keyboard == null:
			_box(root, "Reception Keyboard %d" % i,
				Vector3(side * 0.90 - 0.04, 1.11, -0.50),
				Vector3(0.44, 0.022, 0.15), Color(0.055, 0.058, 0.062))
		else:
			keyboard.name = "Reception Keyboard %d" % i
	# The system unit belongs on the floor, not on the worktop. The clerk's nook
	# runs from the counter's rear face (z -0.62) back past the return wing,
	# which ends at x -1.29, so x 1.30 / z -0.95 stands clear of both and of the
	# task lamp above it. Same yaw rule as the rest of the set: front to -Z.
	var tower := Models.place(root, "lp_pc_tower", Vector3(1.30, 0.00, -0.95))
	if tower == null:
		_box(root, "Reception Tower", Vector3(1.30, 0.22, -0.95),
			Vector3(0.20, 0.44, 0.45), Color(0.10, 0.105, 0.11))
	else:
		tower.name = "Reception Tower"
	_box(root, "Reception Log Book", Vector3(0.42, 1.12, 0.06),
		Vector3(0.34, 0.035, 0.26), Color(0.62, 0.60, 0.52))
	_box(root, "Reception Keycard", Vector3(-0.30, 1.11, 0.20),
		Vector3(0.085, 0.006, 0.055), Color(0.30, 0.44, 0.42), 0.15)
	_cyl(root, "Reception Task Lamp Stem", Vector3(1.55, 1.28, -0.20),
		0.022, 0.36, STEEL_DARK, 6)
	_cone(root, "Reception Task Lamp Hood", Vector3(1.55, 1.50, -0.20),
		0.13, 0.05, 0.11, STEEL_DARK, 8)

	var rod_height: float = maxf(0.30, ceiling_y - origin.y - 2.86)
	for i in range(2):
		var side: float = -1.0 + 2.0 * float(i)
		_cyl(root, "Reception Sign Rod %d" % i,
			Vector3(side * 0.85, 2.86 + rod_height * 0.5, 0.10),
			0.02, rod_height, CABLE, 6)
	_box(root, "Reception Sign Panel", Vector3(0, 2.60, 0.10),
		Vector3(2.30, 0.50, 0.07), PANEL)
	_box(root, "Reception Sign Rule", Vector3(0, 2.37, 0.10),
		Vector3(2.30, 0.04, 0.08), ACCENT_DEEP, 0.20)
	_label(root, _tr("EXHIBIT_RECEPTION"), Vector3(0, 2.62, 0.145),
		SIGN_TEXT, 44, 0.0048, 2.10)
	return root


# =============================================================================
#  Directory board
# =============================================================================

## Freestanding wing directory: header, four rows of wing name plus a colour
## tab, and a hooded strip lamp. Text carries the meaning; the tab is a second,
## redundant channel. Face is local +z, `facing_deg` yaws it.
##
## Bounding box 2.06 x 2.65 x 0.35 m.
static func build_directory_board(parent: Node3D, origin: Vector3,
		facing_deg := 0.0) -> Node3D:
	var root := _root(parent, "Atrium Directory Board", origin)
	root.rotation_degrees.y = facing_deg

	for i in range(2):
		var side: float = -1.0 + 2.0 * float(i)
		_box(root, "Directory Post %d" % i, Vector3(side * 0.86, 1.17, 0),
			Vector3(0.13, 2.34, 0.13), STEEL_DARK, 0.0, 0.5, true)
	_box(root, "Directory Panel", Vector3(0, 1.62, 0),
		Vector3(1.94, 1.34, 0.10), PANEL, 0.0, 0.0, true)
	_box(root, "Directory Header", Vector3(0, 2.42, 0),
		Vector3(2.06, 0.26, 0.12), ACCENT_DEEP)
	_label(root, _tr("EXHIBIT_MUSEUM_SIGN"), Vector3(0, 2.42, 0.068),
		SIGN_TEXT, 38, 0.0042, 1.90)

	for i in range(WING_KEYS.size()):
		var row_y: float = 2.10 - 0.30 * float(i)
		_box(root, "Directory Tab %d" % i, Vector3(-0.78, row_y, 0.055),
			Vector3(0.16, 0.16, 0.03), WING_TINTS[i], 0.25)
		# The first glyph of a LEFT-aligned Label3D lands on the node, not half a
		# box to the left of it -- the comment that used to be here claimed the
		# opposite and the rows were placed on that claim. Measured: the row text
		# began 5 cm right of the panel centre and "Крыло D — Масса" is 1.00 m
		# wide, so it ran to 1.08 on a panel that ends at 0.97, i.e. off the right
		# edge and into thin air. Starting at -0.62 clears the 0.16 colour tab at
		# -0.78 and leaves the longest row ending at 0.38, well inside the panel.
		var text := _label(root, _tr(WING_KEYS[i]), Vector3(-0.62, row_y, 0.058),
			SIGN_TEXT, 30, 0.0040, 1.50)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_box(root, "Directory Rule %d" % i, Vector3(0, row_y - 0.145, 0.055),
			Vector3(1.72, 0.012, 0.02), Color(0.20, 0.21, 0.22))

	_box(root, "Directory Hood", Vector3(0, 2.60, 0.13),
		Vector3(2.06, 0.10, 0.32), STEEL_DARK, 0.0, 0.45)
	_box(root, "Directory Hood Strip", Vector3(0, 2.545, 0.17),
		Vector3(1.78, 0.04, 0.09), Color(0.72, 0.70, 0.60), 0.90)
	return root


# =============================================================================
#  One-line placement
# =============================================================================

## Everything above, placed at its canonical spot in the 30 x 30 atrium.
## `origin` is the atrium centre at floor level, i.e. Vector3.ZERO in this map.
## `dais_y` is the top of the rotunda plate the core stands on (0.16 here);
## pass 0.0 if the plate is gone.
##
## Both pieces used to hug the entrance wall at z 11.6, square to it and 6.4 to
## 8.4 m out to the sides -- far enough into the corners that a visitor walking
## the doorway channel (x in [-0.9, 0.9], heading -z) passed them edge-on and
## never read either one. They now stand nearer the door and angled into it:
## the board 3.4 m to the RIGHT of the doorway and 2.2 m deeper into the room
## at (3.4, 9.4), yawed -22 so its face turns back toward the door; reception
## opposite it at (-5.6, 12.1), yawed +20 for the same reason.
##
## Clearances re-checked against the room's real contents: reception clears the
## rotunda kerb (r 5.8) by 7.5 m, the column at (-11.5, 11.5) by 3.9 m and the
## planter at (-10.8, 10.8) by 3.6 m; the board clears the kerb by 4.2 m and
## the bench at (0, 8.4) by 1.4 m. Rotated, reception reaches x -3.57 and the
## board x 2.38, so the 1.8 m doorway channel stays open.
static func build_atrium(parent: Node3D, origin: Vector3, dais_y := 0.16,
		ceiling_y := 3.39) -> Node3D:
	var root := _root(parent, "Atrium Props", origin)
	var dais := Vector3(0, dais_y, 0)
	build_containment_core(root, dais, ceiling_y)
	_build_core_spots(root, ceiling_y)
	# The floor goes down before the paint on it: the inlay lives between the
	# rings build_floor_signage() owns, and both are within 2.5 cm of the same
	# plate, so whoever edits either one needs to read the other.
	build_atrium_floor(root, Vector3.ZERO, dais_y)
	build_floor_signage(root, dais)
	build_rope_barrier(root, dais)
	build_cable_runs(root, Vector3.ZERO, [], ceiling_y)
	build_reception_desk(root, Vector3(-4.4, 0, 10.6), 24.0, ceiling_y)
	build_directory_board(root, Vector3(3.4, 0, 9.4), -22.0)
	# Four benches at r 8.4 on the DIAGONALS, not the cardinals: on the axes a
	# bench sits squarely on the circulation line between an opposing pair of
	# doorways (Entrance-Time Wing and Office-Gravity Wing both run through
	# one). The diagonals put them between the routes, where a bench belongs.
	# Yaw -(angle + 90) turns the long axis onto the tangent so the back faces
	# out and the seat faces the core. They used to be placed by
	# FirstMuseumMap._add_atrium_landmarks() from лавочки.glb.
	for angle: float in [45.0, 135.0, 225.0, 315.0]:
		var a: float = deg_to_rad(angle)
		build_rotunda_bench(root, Vector3(cos(a) * 8.4, 0.0, sin(a) * 8.4),
			-(angle + 90.0), "%d" % int(angle))
	return root


## Two ceiling rigs that rake the containment column from east and west.
##
## The skylight beam hangs at (0, 3.28, 0), dead over the core, and the head cap
## is a 0.66 m cone at 2.74 -- so the column stands in the umbra of its own head
## and reads as a shapeless smear instead of a cylinder. A brighter skylight
## cannot fix that; only side light can. These rigs cross-light the drum so its
## silhouette comes back. They are deliberately weak: the core is still meant to
## read as a hole punched in the near-white marble, so the job is to recover an
## edge, not to flood the thing.
##
## Mounted on the +-X axis at radius 2.80 -- the one band of ceiling that is
## clear of the 3.4 m skylight glass (+-1.70), of the cable trays (which run the
## diagonals outward from radius 1.55), and of the gantry rails, whose highest
## point is 2.24 against this rig's lowest at ceiling_y - 0.51 = 2.88.
##
## Single-headed and shadowless on purpose: a second shadow caster over the core
## would only fight the skylight. The lamps are named by LightProps and are not
## in BLACKOUT_EXEMPT_LIGHTS, so _collect_serialized_lights() files them under
## the mains and they die with everything else at the blackout.
static func _build_core_spots(root: Node3D, ceiling_y := 3.39) -> void:
	for i in range(2):
		var side: float = -1.0 + 2.0 * float(i)
		var tag: String = "West" if side < 0.0 else "East"
		Lights.spot_rig(root, Vector3(side * 2.80, ceiling_y, 0.0),
			Vector3(0, 1.55, 0), 1, Lights.TINT_HALOGEN, 1.3, 0,
			"Core Wash Rig %s" % tag)


# =============================================================================
#  Primitives
# =============================================================================

static func _root(parent: Node3D, node_name: String, origin: Vector3) -> Node3D:
	var node := Node3D.new()
	# A repeated sibling name makes Godot rename the second prop to @Node3D@NNN.
	if parent.has_node(NodePath(node_name)):
		node_name = "%s %s" % [node_name, origin]
	node.name = node_name
	node.position = origin
	parent.add_child(node)
	return node


static func _box(parent: Node3D, node_name: String, box_position: Vector3,
		size: Vector3, color: Color, emission := 0.0, metallic := 0.0,
		with_collision := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := _attach(parent, node_name, box_position, mesh, size, color,
		emission, metallic)
	if with_collision:
		var shape := BoxShape3D.new()
		shape.size = size
		_add_body(inst, node_name, shape)
	return inst


## Cylinders get a CylinderShape3D, never a box. A BoxShape3D fitted to a
## cylinder's bounding size puts invisible walls out at radius * sqrt(2) --
## a 0.66 m drum would stop the player 0.93 m away from it.
static func _cyl(parent: Node3D, node_name: String, cyl_position: Vector3,
		radius: float, height: float, color: Color, segments := 12,
		metallic := 0.0, emission := 0.0,
		with_collision := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.radial_segments = segments
	mesh.rings = 0
	var inst := _attach(parent, node_name, cyl_position, mesh,
		Vector3(radius * 2.0, height, radius * 2.0), color, emission, metallic)
	if with_collision:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		_add_body(inst, node_name, shape)
	return inst


static func _cone(parent: Node3D, node_name: String, cone_position: Vector3,
		bottom_radius: float, top_radius: float, height: float, color: Color,
		segments := 12, emission := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.radial_segments = segments
	mesh.rings = 0
	var widest: float = maxf(bottom_radius, top_radius)
	return _attach(parent, node_name, cone_position, mesh,
		Vector3(widest * 2.0, height, widest * 2.0), color, emission, 0.35)


static func _sphere(parent: Node3D, node_name: String, sphere_position: Vector3,
		radius: float, color: Color, emission := 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _attach(parent, node_name, sphere_position, mesh,
		Vector3(radius * 2.0, radius * 2.0, radius * 2.0), color, emission)


## Flat ring lying in the XZ plane. TorusMesh is authored flat with its axis on
## +y, which is exactly what a painted floor band or a drum belt needs.
static func _ring(parent: Node3D, node_name: String, ring_position: Vector3,
		inner_radius: float, outer_radius: float, color: Color,
		segments := 20, emission := 0.0) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = segments
	mesh.ring_segments = 4
	var thickness: float = outer_radius - inner_radius
	return _attach(parent, node_name, ring_position, mesh,
		Vector3(outer_radius * 2.0, thickness, outer_radius * 2.0), color,
		emission, 0.3)


## Box placed in polar coordinates about the prop's local origin. `size.x` runs
## RADIALLY outward and `size.z` runs tangentially, which is the natural way to
## think about ribs, catwalks and shutter slats. `offset` slides the box along
## the tangent; `skew` cants it in place for hatching.
##
## Yaw is -angle because rotating by t about +y sends local +x to
## (cos t, 0, -sin t); -angle therefore puts local +x on the outward radius and
## local +z on the tangent.
static func _radial_box(parent: Node3D, node_name: String, angle: float,
		radius: float, y: float, size: Vector3, color: Color,
		emission := 0.0, metallic := 0.0, with_collision := false,
		offset := 0.0, skew := 0.0) -> MeshInstance3D:
	var outward := Vector3(cos(angle), 0.0, sin(angle))
	var tangent := Vector3(-sin(angle), 0.0, cos(angle))
	var place: Vector3 = outward * radius + tangent * offset
	place.y = y
	var inst := _box(parent, node_name, place, size, color, emission, metallic,
		with_collision)
	inst.rotation.y = -angle + skew
	return inst


## Flat triangular floor arrow pointing outward along `angle`. PrismMesh is
## authored upright with its apex on +y and extruded along z, so it is laid
## down with a +90 deg pitch and then yawed so the apex lands on the radius.
static func _chevron(parent: Node3D, node_name: String, angle: float,
		radius: float, y: float, width: float, depth: float,
		color: Color) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(width, depth, 0.014)
	var place := Vector3(cos(angle) * radius, y, sin(angle) * radius)
	var inst := _attach(parent, node_name, place, mesh,
		Vector3(width, 0.014, depth), color, 0.10, 0.0)
	inst.basis = Basis(Vector3.UP, PI * 0.5 - angle) * Basis(Vector3.RIGHT, PI * 0.5)
	return inst


## Cylinder stretched between two points: cables, ropes, braces.
static func _beam(parent: Node3D, node_name: String, from: Vector3, to: Vector3,
		radius: float, color: Color, segments := 8) -> MeshInstance3D:
	var delta := to - from
	var length: float = delta.length()
	if length < 0.001:
		return null
	var mesh := CylinderMesh.new()
	mesh.height = length
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.radial_segments = segments
	mesh.rings = 0
	var inst := _attach(parent, node_name, (from + to) * 0.5, mesh,
		Vector3(radius * 2.0, length, radius * 2.0), color, 0.0, 0.35)
	var dir := delta / length
	var axis := Vector3.UP.cross(dir)
	if axis.length_squared() > 0.000001:
		inst.rotate(axis.normalized(), Vector3.UP.angle_to(dir))
	elif dir.y < 0.0:
		inst.rotate(Vector3.RIGHT, PI)
	return inst


## Museum signage. Unshaded and non-billboarded: a plaque that swivels to face
## whatever camera is rendering is what put a fan of rotating text through
## every CCTV feed in this project once already. `width` turns on autowrap so a
## long Russian string cannot run off the end of its panel.
static func _label(parent: Node3D, text: String, label_position: Vector3,
		color: Color, font_size := 32, pixel_size := 0.0045,
		width := 0.0) -> Label3D:
	var label := Label3D.new()
	label.name = "Label - %s" % text
	label.text = text
	label.position = label_position
	label.modulate = color
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = false
	label.outline_size = 5
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	label.visibility_range_end = 24.0
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if width > 0.0:
		label.width = width / maxf(pixel_size, 0.0001)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


## Object.tr() is an instance method and cannot be reached from a static
## function, so signage goes through the singleton tr() itself delegates to.
## Same lookup, same catalogue, same behaviour on a missing key (it echoes the
## key back). None of these strings take format arguments, so there is nothing
## here for Loc.fmt() to protect.
static func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))


static func _attach(parent: Node3D, node_name: String, prim_position: Vector3,
		mesh: PrimitiveMesh, size: Vector3, color: Color, emission := 0.0,
		metallic := 0.0) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.position = prim_position
	inst.mesh = mesh
	inst.material_override = _material(color, emission, metallic)
	inst.visibility_range_end = VISIBILITY_RANGE
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# Same threshold MapPrimitives uses: trim and fasteners do not earn a slot
	# in the shadow map.
	if size.length() < 0.65:
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	return inst


static func _add_body(inst: MeshInstance3D, node_name: String,
		shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	body.name = "%s Collision" % node_name
	inst.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "%s CollisionShape" % node_name
	collision.shape = shape
	body.add_child(collision)


## One walk-blocking volume with no mesh of its own -- the pattern ArchiveProps,
## FacadeProps and OfficeProps already use. A slatted bench is thirty-odd
## boards, rails and brackets; one box round the seat is the whole of its
## physics, and the nav bake thanks you for it.
static func _collider(parent: Node3D, node_name: String, body_position: Vector3,
		size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = body_position
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "%s Shape" % node_name
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body


## How deep a floor inlay is buried. Only the top face is ever seen; the rest
## is inside the slab, which is the point.
const INLAY_DEPTH := 0.12


## Floor inlay: a flat box with no collision that never enters the shadow map.
##
## plate_position.y IS THE TOP FACE, not the centre, and size.y is ignored. The
## box is INLAY_DEPTH deep and everything under the visible top is buried in
## the slab. The first pass laid 12 mm plates with their undersides exactly on
## the floor plane and separated the layers by 1-2 mm; wherever two of them
## overlapped that is a shared plane fighting for the same depth value, which
## is what the whole floor shimmered along. Burying the underside deletes the
## plane instead of trying to out-bias it.
##
## An empty `pack` -- the default now -- means a flat tinted material with no
## photo maps, which is what an inlay wants: the slab it sits on already wears
## a stone map, so a 5 cm joint carrying a second map at 3 m scale reads as a
## texture inside a texture up close and as speckle from across the room.
## Photo packs belong on surfaces measured in metres. `metres` is how many
## metres one texture square covers, for the cases that still take one.
static func _floor_plate(parent: Node3D, node_name: String,
		plate_position: Vector3, size: Vector3, tint: Color,
		pack := "", metres := 0.0, yaw := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, INLAY_DEPTH, size.z)
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.position = Vector3(plate_position.x,
		plate_position.y - INLAY_DEPTH * 0.5, plate_position.z)
	inst.rotation.y = yaw
	inst.mesh = mesh
	if pack.is_empty():
		inst.material_override = _flat_material(tint)
	else:
		inst.material_override = MatLib.get_material(pack, tint, metres)
	inst.visibility_range_end = VISIBILITY_RANGE
	# Deliberately no VISIBILITY_RANGE_FADE_SELF here. Fading dithers the mesh
	# through the margin, and a dithered 5 cm plate lying on a floor is one more
	# thing that can crawl in a slow pan.
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	return inst


## _floor_plate in polar coordinates, same convention as _radial_box: size.x
## runs radially outward, size.z along the tangent, yaw follows the angle.
static func _floor_radial(parent: Node3D, node_name: String, angle: float,
		radius: float, y: float, size: Vector3, tint: Color,
		pack := "", metres := 0.0) -> MeshInstance3D:
	var place := Vector3(cos(angle) * radius, y, sin(angle) * radius)
	return _floor_plate(parent, node_name, place, size, tint, pack, metres,
		-angle)


## A brass strip set into the floor: TorusMesh squashed to 30% so the tube
## reads as a 2 cm fillet instead of a trip hazard, positioned by its TOP so
## the underside of the tube ends up inside the slab. A torus laid on a floor
## touches it tangentially along its entire length, which is the worst case
## there is for depth fighting -- these four rings were the brightest part of
## the shimmer.
static func _floor_ring(parent: Node3D, node_name: String, top_y: float,
		inner_r: float, outer_r: float, segments := 48) -> MeshInstance3D:
	var half: float = (outer_r - inner_r) * 0.5 * 0.30
	var ring := _ring(parent, node_name, Vector3(0.0, top_y - half, 0.0),
		inner_r, outer_r, BRASS, segments)
	ring.scale.y = 0.30
	ring.material_override = _flat_material(BRASS, 0.35)
	ring.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring


## Flat tinted material with no photo maps, cached beside the palette ones.
## _material() matches a palette constant to a MaterialLib pack, which is right
## for props and wrong for floor inlays; this is how to ask for the tint alone.
static func _flat_material(color: Color,
		metallic := 0.0) -> StandardMaterial3D:
	var key := "flat|%s|%.2f" % [color.to_html(true), metallic]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.metallic_specular = 0.6
	mat.roughness = clampf(0.62 - metallic * 0.35, 0.14, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_materials[key] = mat
	return mat


## Палитра атриума -> набор карт.
static func _pack_for(color: Color) -> String:
	if color.is_equal_approx(CONCRETE) or color.is_equal_approx(CONCRETE_DARK):
		return "concrete"
	if color.is_equal_approx(STEEL) or color.is_equal_approx(STEEL_DARK):
		return "steel"
	if color.is_equal_approx(IRON) or color.is_equal_approx(BRASS):
		return "painted_metal"
	if color.is_equal_approx(PANEL):
		return "plastic_dry"
	if color.is_equal_approx(WOOD):
		return "wood"
	if color.is_equal_approx(STONE):
		return "quartzite"
	return ""


static func _material(color: Color, emission := 0.0,
		metallic := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(true), emission, metallic]
	if _materials.has(key):
		return _materials[key]
	if emission <= 0.0:
		var pack := _pack_for(color)
		if not pack.is_empty():
			var photo := MatLib.get_material(pack, color)
			_materials[key] = photo
			return photo
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.metallic_specular = 0.6
	mat.roughness = clampf(0.62 - metallic * 0.35, 0.14, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	_materials[key] = mat
	return mat


static func _glass_material() -> StandardMaterial3D:
	if _materials.has("__atrium_glass__"):
		return _materials["__atrium_glass__"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.75, 0.80, 0.10)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.04
	mat.metallic = 0.15
	mat.metallic_specular = 0.7
	_materials["__atrium_glass__"] = mat
	return mat
