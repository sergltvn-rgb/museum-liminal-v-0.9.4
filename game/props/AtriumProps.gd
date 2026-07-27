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
##   and rotunda floor r 4.9 (top y 0.16), four columns at (+-11.5, +-11.5),
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
## FirstMuseumMap's "Skylight Beam" is a SpotLight3D at (0, 3.28, 0) aimed down
## with spot_angle 24 deg, so its cone is only 1.39 m across at the floor and the
## core column stands inside it. The column will occlude the beam and throw a
## hard radial shadow instead of a floor pool. That is a better image than the
## bare pool was, but if a light pool is wanted back, widen spot_angle to about
## 40 deg (2.6 m radius at the floor) so the beam lands as a ring around the
## dais. This file adds no lights of its own.


# --- Palette -----------------------------------------------------------------
# Museum-grade steel and concrete. Values are deliberately dark: the atrium
# walls are near-white marble (0.87) and the core has to read as a hole in it.
const CONCRETE := Color(0.128, 0.134, 0.140)
const CONCRETE_DARK := Color(0.088, 0.092, 0.096)
const STEEL := Color(0.175, 0.185, 0.195)
const STEEL_DARK := Color(0.100, 0.105, 0.110)
const IRON := Color(0.062, 0.066, 0.070)
const CABLE := Color(0.045, 0.048, 0.052)
const PANEL := Color(0.072, 0.076, 0.082)
const SIGN_TEXT := Color(0.82, 0.86, 0.84)
const HAZARD := Color(0.50, 0.39, 0.10)
const HAZARD_BRIGHT := Color(0.88, 0.62, 0.16)
const BRASS := Color(0.34, 0.28, 0.14)
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
const WOOD := Color(0.105, 0.088, 0.070)
const STONE := Color(0.140, 0.145, 0.150)
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
	_build_core_column(root)
	_build_core_status_ring(root)
	_build_core_head(root, trunk_top)
	_build_core_gantries(root)
	_build_core_shutters(root)
	_build_core_plaque(root)
	return root


## Slab, kerb and the painted hazard hatching on the deck. Two shallow steps of
## 0.11 and 0.13 m, both well under the bake's agent_max_climb of 0.4, so the
## deck stays connected to the atrium floor and the Curator can walk onto it.
static func _build_core_slab(root: Node3D) -> void:
	_cyl(root, "Core Base Lip", Vector3(0, 0.055, 0), 2.22, 0.11,
		CONCRETE_DARK, 12, 0.0, 0.0, true)
	_cyl(root, "Core Base Slab", Vector3(0, 0.12, 0), 2.05, 0.24,
		CONCRETE, 12, 0.0, 0.0, true)
	# Radial hazard dashes at the deck edge: geometry, not a texture.
	for i in range(8):
		var a: float = TAU * float(i) / 8.0 + PI / 8.0
		_radial_box(root, "Core Deck Hatch %d" % i, a, 1.72, 0.247,
			Vector3(0.44, 0.014, 0.13), HAZARD, 0.10)


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

	# The two nodes GameManager drives. Keep the names.
	# 1.8, up from 1.6, buys back the throw that the darker CORE_GLOW gave up:
	# 0.58 * 1.8 = 1.044 puts green a hair over unity, so the sphere still
	# carries a thin halo and is still the first thing seen from the entrance
	# 15 m away, while the two channels that used to blow out (0.792 and 0.936)
	# now stay inside the frame and the glow stays a colour instead of a flare.
	_sphere(root, CORE_NODE_NAME, Vector3(0, 1.44, 0), 0.33, CORE_GLOW, 1.8)
	_containment_window(root, Vector3(0, 1.44, 0), 0.50, 0.86)

	_cyl(root, "Core Shield Flange Upper", Vector3(0, 1.92, 0), 0.82, 0.12,
		STEEL_DARK, 12, 0.60)
	_cyl(root, "Core Shield Drum Upper", Vector3(0, 2.30, 0), 0.66, 0.64,
		STEEL, 12, 0.55, 0.0, true)


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
static func _build_core_head(root: Node3D, trunk_top: float) -> void:
	_cone(root, "Core Head Cap", Vector3(0, 2.74, 0), 0.66, 0.36, 0.24,
		STEEL_DARK, 12)
	_cyl(root, "Core Head Collar", Vector3(0, 2.95, 0), 0.40, 0.18,
		CONCRETE_DARK, 10)
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
		var a: float = deg_to_rad(45.0 + 90.0 * float(i))
		var tag := "Gantry %d" % (i + 1)
		# Deck spans r 0.64 .. 2.08 at waist height, so it blocks rather than
		# invites -- there is no way up onto it, which is the point.
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
## hanging to local y 1.60, alternating steel and hazard so the pattern is
## legible without colour, with the core glow leaking out underneath.
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
	for s in range(5):
		var slat_y: float = 2.38 - 0.175 * float(s)
		var tint: Color = HAZARD if s % 2 == 1 else Color(0.130, 0.135, 0.140)
		_radial_box(root, "Blast Shutter Slat %d" % s, south, 1.70, slat_y,
			Vector3(0.14, 0.16, 1.34), tint, 0.0, 0.40, true)


## Lectern plaque on the south edge of the slab, angled up at the reader.
## Pale text on a near-black plate: 13.4:1, well past the 4.5:1 floor.
static func _build_core_plaque(root: Node3D) -> void:
	_box(root, "Core Plaque Post", Vector3(0, 0.36, 2.40),
		Vector3(0.12, 0.72, 0.12), STEEL_DARK, 0.0, 0.5, true)
	var plate := _box(root, "Core Plaque Plate", Vector3(0, 0.86, 2.40),
		Vector3(0.86, 0.46, 0.05), PANEL)
	# -32 deg pitch tips the plate's +z face up towards a reader standing south
	# of it; the label rides the same basis, so it needs no rotation of its own.
	plate.rotation_degrees = Vector3(-32, 0, 0)
	_label(plate, _tr("EXHIBIT_CONTAINMENT_CORE"), Vector3(0, 0.02, 0.032),
		SIGN_TEXT, 40, 0.0035, 0.80)


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
		_cyl(root, "Barrier Base %d" % i, p + Vector3(0, 0.025, 0), 0.17, 0.05,
			CONCRETE_DARK, 8)
		_cyl(root, "Barrier Post %d" % i, p + Vector3(0, 0.50, 0), 0.033, 0.95,
			IRON, 6)
		_sphere(root, "Barrier Cap %d" % i, p + Vector3(0, 1.00, 0), 0.052, BRASS)
		tops.append(p + Vector3(0, 0.96, 0))

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
#  Reception desk
# =============================================================================

## Atrium reception: an L-shaped counter with a dead monitor pair, an abandoned
## visitor log and a keycard left on the ledge, under a sign hung from the
## ceiling on two rods. Front face is local +z; `facing_deg` yaws the whole
## thing, so 0 faces the entrance doorway at z = +15.
##
## Bounding box 4.17 x 1.60 x 2.44 m for the furniture, growing to
## 4.17 x (ceiling_y - origin.y) x 2.44 once the hanging sign and its rods are
## counted -- 4.17 x 3.39 x 2.44 at the defaults.
static func build_reception_desk(parent: Node3D, origin: Vector3,
		facing_deg := 0.0, ceiling_y := 3.39) -> Node3D:
	var root := _root(parent, "Atrium Reception", origin)
	root.rotation_degrees.y = facing_deg

	_box(root, "Reception Counter Body", Vector3(0, 0.50, 0),
		Vector3(3.60, 1.00, 0.86), WOOD, 0.0, 0.0, true)
	_box(root, "Reception Counter Fascia", Vector3(0, 0.62, 0.445),
		Vector3(3.30, 0.60, 0.04), Color(0.175, 0.145, 0.110))
	_box(root, "Reception Counter Top", Vector3(0, 1.05, 0),
		Vector3(3.92, 0.10, 1.10), STONE, 0.0, 0.25, true)
	_box(root, "Reception Transaction Shelf", Vector3(0, 0.78, 0.60),
		Vector3(3.40, 0.07, 0.30), Color(0.120, 0.125, 0.130), 0.0, 0.2, true)

	_box(root, "Reception Return Body", Vector3(-1.72, 0.50, -1.03),
		Vector3(0.86, 1.00, 1.20), WOOD, 0.0, 0.0, true)
	_box(root, "Reception Return Top", Vector3(-1.72, 1.05, -1.03),
		Vector3(0.98, 0.10, 1.32), STONE, 0.0, 0.25, true)

	for i in range(2):
		var side: float = -1.0 + 2.0 * float(i)
		_box(root, "Reception Monitor Stand %d" % i,
			Vector3(side * 0.90, 1.17, -0.14),
			Vector3(0.10, 0.15, 0.14), STEEL_DARK, 0.0, 0.5)
		var screen := _box(root, "Reception Monitor %d" % i,
			Vector3(side * 0.90, 1.32, -0.14), Vector3(0.50, 0.34, 0.05),
			Color(0.028, 0.032, 0.036), 0.0, 0.30)
		screen.rotation_degrees = Vector3(-14, 0, 0)
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
		# Left-aligned text fills a 1.32 m box centred on the node, so the node
		# sits half a box right of where the first glyph should land (-0.58).
		var text := _label(root, _tr(WING_KEYS[i]), Vector3(0.08, row_y, 0.058),
			SIGN_TEXT, 30, 0.0040, 1.32)
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
## Placement was chosen against the room's real contents: the reception desk at
## (-8.4, 11.6) clears the rotunda kerb (r 5.8), the column at (-11.5, 11.5) by
## 3.1 m and the planter at (-10.8, 10.8) by 2.5 m; the directory board at
## (6.4, 11.6) clears the bench at (0, 8.4) by 7.1 m and the column at
## (11.5, 11.5) by 5.3 m. Both sit well clear of the 1.8 m entrance doorway
## channel at x in [-0.9, 0.9].
static func build_atrium(parent: Node3D, origin: Vector3, dais_y := 0.16,
		ceiling_y := 3.39) -> Node3D:
	var root := _root(parent, "Atrium Props", origin)
	var dais := Vector3(0, dais_y, 0)
	build_containment_core(root, dais, ceiling_y)
	build_floor_signage(root, dais)
	build_rope_barrier(root, dais)
	build_cable_runs(root, Vector3.ZERO, [], ceiling_y)
	build_reception_desk(root, Vector3(-8.4, 0, 11.6), 0.0, ceiling_y)
	build_directory_board(root, Vector3(6.4, 0, 11.6), 0.0)
	return root


# =============================================================================
#  Primitives
# =============================================================================

static func _root(parent: Node3D, node_name: String, origin: Vector3) -> Node3D:
	var node := Node3D.new()
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


static func _material(color: Color, emission := 0.0,
		metallic := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(true), emission, metallic]
	if _materials.has(key):
		return _materials[key]
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
