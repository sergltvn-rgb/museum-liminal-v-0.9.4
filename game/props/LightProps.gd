@tool
class_name LightProps
extends RefCounted
## Light fittings for the museum, built out of primitives at runtime.
##
## scenes/FirstMuseumMap.tscn contains no 3D content at all -- FirstMuseumMap
## .build_map() assembles the entire building every time the scene loads. These
## builders follow the same rule and the same primitive vocabulary as
## FirstMuseumMap._box()/_primitive(): BoxMesh, CylinderMesh and PrismMesh with a
## StandardMaterial3D each, pulled from a shared cache.
##
## Every builder returns the root Node3D it added and carries its own Light3D
## inside, so a call site places a complete fitting -- housing, lamp faces, light
## -- on one line:
##
##     LightProps.troffer(map_root, Vector3(0, LightProps.SOFFIT_Y, 6.0))
##     LightProps.spot_rig(map_root, Vector3(28, LightProps.SOFFIT_Y, -1.2),
##         Vector3(28, 1.1, -4.5), 3)
##     LightProps.failing_tube(map_root, Vector3(-25, LightProps.SOFFIT_Y, 8.0),
##         0.0, 11.0)
##
## Reach the light again with light_of() / lights_of() -- e.g. to append it to
## FirstMuseumMap._powered_lights so the blackout kills it with everything else.
##
## NO COLLISION, ANYWHERE IN THIS FILE.
## Every fitting here is bolted to a ceiling soffit at 3.39 m or a wall above head
## height; the player cannot walk into any of it. That is also what makes the file
## navigation-safe by construction: _bake_navigation() uses
## PARSED_GEOMETRY_STATIC_COLLIDERS, so geometry with no StaticBody3D is invisible
## to the bake and cannot erode a doorway or strand the Curator. Put a fitting
## directly over a threshold if the shot wants it.
##
## HORROR NOTE. These read as a working building's fittings seen after the working
## day ended: flat steel channels, dead diffuser halves, a batten hanging off one
## hanger. Nothing is decorative and nothing is charming. The failing tube's
## flicker is diegetic -- the containment core is losing the building -- which is
## the only reason an animated prop is allowed here at all.
##
## ACCESSIBILITY. attach_flicker() holds the fitting at a steady, unmodulated
## level for as long as SettingsManager.reduced_flashes is true, and resumes the
## moment it is switched back off. The flag is polled rather than connected to
## `settings_changed` because the manager is a sibling node that may not exist yet
## when the map builds. Nothing in this file conveys meaning by colour alone: the
## emergency luminaire reads as an emergency luminaire from its shape and its
## visor, not from being red.


## Underside of the ceiling slab. FirstMuseumMap._add_room() puts a 0.12 m ceiling
## box centred at WALL_HEIGHT + 0.05 = 3.45, so the visible soffit is 3.39. Ceiling
## fittings take this as their origin and build downward; wall fittings take a
## point on the wall face and build outward. Mirrored rather than imported so this
## file has no dependency on the map script.
const SOFFIT_Y := 3.39

## Rooms are 3.4 m tall and the player is a 1.8 m capsule of radius 0.35
## (FirstMuseumMap._add_player). Every bounding box quoted below is measured, not
## estimated, and the lowest point any fitting here can reach is 2.36 m -- the
## failing tube at its 42-degree sag clamp -- which still leaves 0.56 m of head
## room. Wrong scale is this project's most common art defect; treat the quoted
## boxes as the contract.
const WALL_HEIGHT := 3.4

## Every Light3D built here joins this group; every fitting root joins the other.
## Lowercase snake to match the project's existing groups (player, museum_map,
## settings_manager, security_camera).
const LIGHT_GROUP := "museum_light"
const FIXTURE_GROUP := "light_fixture"

## Marks a MeshInstance3D as a lamp face, so attach_flicker() knows which surfaces
## must dim with the light. Node metadata rather than a group: metadata works on
## nodes that are not in the SceneTree yet, group queries do not.
const LAMP_FACE_META := "lamp_face"

## Name of the child attach_flicker() adds. flicker_of() looks it up.
const FLICKER_NODE_NAME := "Fixture Flicker"
## The dying-tube hum: a 24.0 s steady cut of a transformer recording, baked
## down to -35.0 dBFS RMS and wrapped with a 1.5 s equal-power crossfade so
## the loop has no seam. Loops through its .import flag.
const LAMP_HUM_PATH := "res://audio/generated/новые звуки/звук ламп луп.mp3"

# Fitting tints. Cold fluorescent for the public halls, warm halogen for the
# exhibit rigs and the sconces, red for emergency gear, sodium-amber for the
# fittings that are on their way out.
const TINT_FLUORESCENT := Color(0.86, 0.90, 0.96)
const TINT_HALOGEN := Color(1.00, 0.88, 0.70)
const TINT_EMERGENCY := Color(0.96, 0.24, 0.16)
const TINT_FAILING := Color(0.98, 0.74, 0.38)

# Structural greys. The museum's fittings are painted steel, not chrome.
const STEEL_DARK := Color(0.075, 0.080, 0.088)
const STEEL_MID := Color(0.145, 0.150, 0.155)
const LAMP_DEAD := Color(0.115, 0.118, 0.122)

# Flicker patterns for attach_flicker(). All four are closed-form functions of
# time -- no RNG, no per-frame allocation, and identical on every machine.
# Measured over two simulated minutes at 60 fps:
#
#   pattern   output range   time under 60%   dropouts per minute
#   STEADY    1.00 - 1.00      0.0%             0
#   STARVED   0.05 - 1.00     11.8%             7.0
#   BALLAST   0.30 - 1.00     75.7%           203.0
#   DYING     0.03 - 1.00     59.3%             7.5
#
# STARVED is the default because a fitting that flickers constantly stops being
# frightening in about ten seconds; one that runs clean for six and then loses
# itself does not.
enum {
	PATTERN_STEADY,   ## No modulation. Use to build a fitting that flickers later.
	PATTERN_STARVED,  ## Long clean stretches broken by short violent dropouts.
	PATTERN_BALLAST,  ## Continuous nervous buzz, never fully dark, never fully on.
	PATTERN_DYING,    ## Slow sag with periodic collapse to almost nothing.
}

# --- Performance budget ------------------------------------------------------
#
# FirstMuseumMap already builds about 1270 MeshInstance3D nodes and 20 lights in
# a single synchronous frame, so the ceiling on this file is tight. Each builder
# reports its own mesh and light count in its doc comment; the shared measures
# are:
#
#   * every mesh here has cast_shadow OFF. A ceiling fitting sits above its own
#     light and would contribute nothing but shadow-map fill.
#   * cylinders are cut to 10 radial segments and 0 rings (the map's _cylinder()
#     leaves CylinderMesh at its 64/4 default, which is ~256 triangles for a
#     0.02 m hanger rod). A fitting here costs 40-300 triangles.
#   * every light gets distance fade, so a fitting four rooms away costs nothing,
#     and a shadow cutoff well inside that, because shadow maps are the expensive
#     half. FADE_SHADOW is deliberately shorter than any room's diagonal: the
#     shadows a fitting casts stop mattering long before its light does.
#   * lights are excluded from lightmap baking; this whole museum is realtime.
#
# Measured cost per fitting (meshes / triangles / lights / shadow-casting lights
# / total nodes):
#
#   troffer            4 /  48 / 1 / 0 /  6
#   spot_rig 2 heads   7 / 252 / 2 / 1 / 12
#   spot_rig 3 heads  10 / 372 / 3 / 1 / 17
#   emergency          8 / 204 / 1 / 0 / 10
#   sconce             4 / 132 / 1 / 0 /  6
#   failing_tube       6 / 156 / 1 / 0 / 10
#
# Only spot_rig() casts shadows, and only from one head. The default set the map
# is likely to want -- say eight troffers, four two-head rigs, six emergency
# units, six sconces and three failing tubes -- is 27 fittings: 118 meshes, ~3.6k
# triangles, 31 lights of which 4 cast shadows. That roughly doubles the map's
# current light count, so anything beyond it wants measuring first; the cheapest
# lever is dropping shadow_heads to 0 on rigs the player never walks under.
const FADE_BEGIN := 36.0
const FADE_LENGTH := 10.0
const FADE_SHADOW := 20.0

## Matches FirstMuseumMap._primitive(): decorative geometry stops drawing at 115 m
## and fades itself out rather than popping.
const CULL_DISTANCE := 115.0

## Shared StandardMaterial3D cache, keyed by colour/emission/metallic. Static, so
## it survives an editor rebuild of the map and the second build reuses the first
## build's materials. clear_material_cache() empties it; a few dozen materials is
## the entire footprint.
static var _materials: Dictionary = {}


# =============================================================================
# Fittings
# =============================================================================


## Recessed ceiling troffer: a steel pan let into the ceiling behind two square
## acrylic diffuser panels, split by a centre tee-bar.
##
## `origin` is the point on the ceiling soffit; the fitting builds downward from
## there. `dead_lamps` blacks out one or both panels -- 1 is the useful value, and
## it also drags the light off-centre toward the half that still works, so the
## fitting is visibly lopsided from across the room. 2 leaves an unlit steel hole
## in the ceiling, which is the cheapest scare in the file.
##
## Bounding box 1.28 W x 0.16 H x 0.70 D, hanging 0.16 m below the soffit
## (bottom face at y = 3.23, clear of the 1.8 m player by 1.43 m).
## 4 meshes, 48 triangles, 1 SpotLight3D, shadows off by default.
static func troffer(parent: Node3D, origin: Vector3, tint := TINT_FLUORESCENT,
		energy := 0.85, dead_lamps := 0, shadows := false,
		node_name := "") -> Node3D:
	var root := _root(parent, origin, node_name if node_name != "" else "Ceiling Troffer")
	var dead: int = clampi(dead_lamps, 0, 2)

	_box(root, "Troffer Pan", Vector3(0, -0.07, 0), Vector3(1.28, 0.14, 0.70),
		STEEL_DARK, 0.0, 0.45)
	_box(root, "Troffer Tee Bar", Vector3(0, -0.14, 0), Vector3(0.05, 0.04, 0.62),
		STEEL_MID, 0.0, 0.5)

	# Panel A is the last to die, so a troffer with dead_lamps == 1 always keeps
	# its west half lit and the map gets a consistent direction of failure.
	var lit_a: bool = dead < 2
	var lit_b: bool = dead < 1
	_diffuser(root, "Troffer Diffuser A", Vector3(-0.30, -0.145, 0), tint, lit_a)
	_diffuser(root, "Troffer Diffuser B", Vector3(0.30, -0.145, 0), tint, lit_b)

	# Two lamps -> centred; one lamp -> biased to the lit half; none -> dark.
	var bias := 0.0
	var scale := 1.0
	if dead == 1:
		bias = -0.30
		scale = 0.45
	elif dead == 2:
		scale = 0.0

	var lamp := SpotLight3D.new()
	lamp.name = "Troffer Lamp"
	lamp.position = Vector3(bias, -0.17, 0)
	lamp.rotation_degrees = Vector3(-90, 0, 0)
	lamp.light_color = tint
	lamp.light_energy = energy * scale
	lamp.spot_range = 5.4
	lamp.spot_angle = 58.0
	lamp.spot_angle_attenuation = 0.9
	_tune(lamp, shadows and scale > 0.0)
	lamp.visible = scale > 0.0
	root.add_child(lamp)
	return root


## Track of gimballed exhibit spots aimed at a single point.
##
## `origin` is the ceiling soffit point the track is screwed to; `aim` is the
## point the heads look at, in the SAME coordinate space as `origin` (the parent's
## local space -- for FirstMuseumMap that is effectively world space, since its
## GeneratedMap root sits at the origin). The aim basis is computed rather than
## taken from Node3D.look_at(), so the rig is correct before the parent is ever in
## the tree.
##
## `shadow_heads` is how many of the heads cast shadows, counted from the west
## end. It defaults to 1 on purpose: three shadow-casting spots over one plinth
## costs three shadow maps and looks no different from one, because the extra two
## only wash out the first one's shadow.
##
## Bounding box, measured: width is 0.34 + 0.52 per head (2 heads 1.38, 3 heads
## 1.90). Height and depth trade off against each other with the aim -- heads
## straight down gives 0.51 H x 0.12 D, heads horizontal gives 0.32 H x 0.30 D --
## so the envelope that bounds every aim is 1.38 x 0.51 x 0.30 for 2 heads and
## 1.90 x 0.51 x 0.30 for 3. Lowest possible point y = 3.39 - 0.51 = 2.88, clear
## of the player by 1.08 m.
## 1 + 3 per head meshes (7 for the default 2 heads, 10 for 3), 252 / 372
## triangles, `heads` SpotLight3D of which `shadow_heads` cast shadows.
static func spot_rig(parent: Node3D, origin: Vector3, aim: Vector3, heads := 2,
		tint := TINT_HALOGEN, energy := 1.1, shadow_heads := 1,
		node_name := "") -> Node3D:
	var root := _root(parent, origin, node_name if node_name != "" else "Exhibit Spot Rig")
	var count: int = clampi(heads, 1, 4)
	var span := 0.52
	var track_length: float = 0.34 + span * float(count)
	_box(root, "Spot Rig Track", Vector3(0, -0.04, 0),
		Vector3(track_length, 0.08, 0.10), STEEL_DARK, 0.0, 0.5)

	for i in range(count):
		var x: float = (float(i) - float(count - 1) * 0.5) * span
		var pivot_local := Vector3(x, -0.26, 0)
		_strut(root, "Spot Rig Stem %d" % i, Vector3(x, -0.08, 0), pivot_local,
			0.022, STEEL_MID, 0.6)

		var pivot := Node3D.new()
		pivot.name = "Spot Rig Head %d" % i
		pivot.position = pivot_local
		pivot.basis = _aim_basis(aim - (origin + pivot_local))
		root.add_child(pivot)

		# CylinderMesh runs along +Y; -90 about X lays it along -Z, which is the
		# axis Basis.looking_at() and SpotLight3D both aim down.
		var barrel := _cylinder(pivot, "Spot Rig Barrel %d" % i,
			Vector3(0, 0, -0.12), 0.062, 0.24, STEEL_DARK, 0.0, 0.55)
		barrel.rotation_degrees = Vector3(-90, 0, 0)
		var lens := _cylinder(pivot, "Spot Rig Lens %d" % i,
			Vector3(0, 0, -0.242), 0.058, 0.012, tint, 1.6, 0.0)
		lens.rotation_degrees = Vector3(-90, 0, 0)
		lens.set_meta(LAMP_FACE_META, true)

		var throw: float = maxf((aim - (origin + pivot_local)).length(), 1.0)
		var lamp := SpotLight3D.new()
		lamp.name = "Spot Rig Lamp %d" % i
		lamp.position = Vector3(0, 0, -0.25)
		lamp.light_color = tint
		lamp.light_energy = energy
		lamp.spot_range = throw * 1.3
		lamp.spot_angle = 24.0
		lamp.spot_angle_attenuation = 1.4
		_tune(lamp, i < shadow_heads)
		pivot.add_child(lamp)

	return root


## Wall-mounted emergency luminaire: a sealed battery box with two swivelled
## lamp heads under a pressed-steel visor, and one live charge pip.
##
## `origin` is a point on the wall face; `yaw_degrees` turns the unit so it faces
## out of that wall. At yaw 0 the unit faces -Z (a fitting on a room's north wall
## facing south into the room); 90 faces -X, 180 faces +Z, 270 faces +X.
##
## `lit` false leaves the whole unit dark with its light hidden, which is the
## state it should be built in: FirstMuseumMap does not turn the emergency
## lighting on until the blackout. Flip `light_of(root).visible` and re-emit the
## lenses then, or just build it lit and add it to _powered_lights inverted.
##
## The visor is the point. An emergency luminaire has to be identifiable as one
## when it is unlit and when the player cannot see its colour, so the silhouette
## carries the identity and the red is only confirmation.
##
## Bounding box 0.40 W x 0.22 H x 0.18 D, protruding 0.18 m from the wall face
## and nothing behind it. Mount at y >= 2.4.
## 8 meshes, 204 triangles, 1 SpotLight3D, no shadows.
static func emergency(parent: Node3D, origin: Vector3, yaw_degrees := 0.0,
		tint := TINT_EMERGENCY, energy := 1.0, lit := true,
		node_name := "") -> Node3D:
	var root := _root(parent, origin,
		node_name if node_name != "" else "Emergency Luminaire")
	root.rotation_degrees = Vector3(0, yaw_degrees, 0)

	_box(root, "Emergency Backplate", Vector3(0, 0, -0.01),
		Vector3(0.40, 0.21, 0.02), STEEL_MID, 0.0, 0.5)
	_box(root, "Emergency Body", Vector3(0, 0, -0.05),
		Vector3(0.36, 0.17, 0.10), STEEL_DARK, 0.0, 0.4)

	# PrismMesh tapers along +X as it rises along +Y; -90 about X tips that rise
	# out of the wall, so the wedge becomes a visor with a vertical ridge.
	var visor := _prism(root, "Emergency Visor", Vector3(0, 0.09, -0.13),
		Vector3(0.38, 0.10, 0.05), STEEL_MID, 0.5)
	visor.rotation_degrees = Vector3(-90, 0, 0)

	for side in [-1.0, 1.0]:
		var tag := "West" if side < 0.0 else "East"
		var head := _cylinder(root, "Emergency Head %s" % tag,
			Vector3(side * 0.10, -0.005, -0.125), 0.055, 0.07, STEEL_DARK, 0.0, 0.4)
		head.rotation_degrees = Vector3(-90, 0, 0)
		var lens := _cylinder(root, "Emergency Lens %s" % tag,
			Vector3(side * 0.10, -0.005, -0.166), 0.050, 0.012,
			tint if lit else LAMP_DEAD, 2.0 if lit else 0.0, 0.0)
		lens.rotation_degrees = Vector3(-90, 0, 0)
		lens.set_meta(LAMP_FACE_META, true)

	# The charge indicator stays lit whether the heads are firing or not: it is
	# the only thing alive in a corridor that has lost its power.
	_box(root, "Emergency Charge Pip", Vector3(0.155, 0.058, -0.104),
		Vector3(0.022, 0.022, 0.016), Color(0.35, 0.95, 0.45), 1.4, 0.0)

	var lamp := SpotLight3D.new()
	lamp.name = "Emergency Lamp"
	lamp.position = Vector3(0, -0.03, -0.18)
	# -Z rotated -24 degrees about X aims the beam out of the wall and downward.
	lamp.rotation_degrees = Vector3(-24, 0, 0)
	lamp.light_color = tint
	lamp.light_energy = energy
	lamp.spot_range = 8.0
	lamp.spot_angle = 58.0
	lamp.spot_angle_attenuation = 1.0
	_tune(lamp, false)
	lamp.visible = lit
	root.add_child(lamp)
	return root


## Wall sconce: a bracket, a short arm and a shallow cup that throws its light up
## the wall and leaves the floor to the player's torch.
##
## `origin` is a point on the wall face, `yaw_degrees` as for emergency().
## `tilt_degrees` is how far the beam is rotated up from straight out of the wall:
## 70 (the default) is a near-vertical wall wash, 0 would aim it flat across the
## room. The short throw is deliberate. A sconce that lit the room would be a
## lamp; this one proves the museum has lighting and then declines to help, which
## is what the wing is meant to feel like. Screen-space indirect light is on in
## the map's Environment, so the wash off the wall does carry a little further
## than the 2.8 m range implies.
##
## Bounding box 0.32 W x 0.43 H x 0.38 D. The cup is tilted, so that depth splits
## into 0.30 m protruding into the room and 0.08 m buried in the wall -- well
## inside the 0.35 m WALL_THICKNESS, so nothing pokes out into the room beyond.
## Mount at y >= 2.3. 4 meshes, 132 triangles, 1 SpotLight3D, no shadows.
static func sconce(parent: Node3D, origin: Vector3, yaw_degrees := 0.0,
		tint := TINT_HALOGEN, energy := 0.5, tilt_degrees := 70.0,
		node_name := "") -> Node3D:
	var root := _root(parent, origin, node_name if node_name != "" else "Wall Sconce")
	root.rotation_degrees = Vector3(0, yaw_degrees, 0)

	_box(root, "Sconce Backplate", Vector3(0, 0, -0.015),
		Vector3(0.13, 0.40, 0.03), STEEL_MID, 0.0, 0.5)
	var arm := _cylinder(root, "Sconce Arm", Vector3(0, -0.02, -0.06),
		0.020, 0.11, STEEL_DARK, 0.0, 0.55)
	arm.rotation_degrees = Vector3(-90, 0, 0)

	# Tapered cup: narrow at the arm, open at the top. CylinderMesh with two
	# radii is the cheapest primitive that reads as a shade.
	var cup := _cone(root, "Sconce Cup", Vector3(0, 0.10, -0.115),
		0.05, 0.17, 0.17, STEEL_DARK, 0.0, 0.35)
	cup.rotation_degrees = Vector3(-18, 0, 0)

	# The glow disc sits inside the cup mouth. It is the lamp face, so it is what
	# attach_flicker() dims; the cup itself stays a dark silhouette.
	var glow := _cylinder(root, "Sconce Glow", Vector3(0, 0.175, -0.128),
		0.145, 0.010, tint, 0.9, 0.0)
	glow.rotation_degrees = Vector3(-18, 0, 0)
	glow.set_meta(LAMP_FACE_META, true)

	var lamp := SpotLight3D.new()
	lamp.name = "Sconce Lamp"
	lamp.position = Vector3(0, 0.20, -0.13)
	lamp.rotation_degrees = Vector3(clampf(tilt_degrees, -80.0, 85.0), 0, 0)
	lamp.light_color = tint
	lamp.light_energy = energy
	lamp.spot_range = 2.8
	lamp.spot_angle = 64.0
	lamp.spot_angle_attenuation = 0.7
	_tune(lamp, false)
	root.add_child(lamp)
	return root


## Surface-mounted fluorescent batten hanging off the ceiling, wired to fail.
##
## `origin` is the ceiling soffit point. `yaw_degrees` turns the batten about the
## vertical. `sag_degrees` drops the far end: the west hanger holds, the east one
## has let go and the batten now dangles from its supply flex, which is drawn as
## a thin strut between the ceiling and wherever the end fell to. 10-16 degrees is
## the range that reads as broken rather than as an art installation; 0 leaves the
## batten level.
##
## A flicker driver is attached automatically -- pass PATTERN_STEADY to build the
## fitting without one, or call attach_flicker() again later to change pattern.
##
## Bounding boxes, measured at three sags:
##   sag  0 deg: 1.46 W x 0.19 H x 0.11 D, lowest point y = 3.20
##   sag 16 deg: 1.42 W x 0.54 H x 0.11 D, lowest point y = 2.85
##   sag 42 deg: 1.33 W x 1.05 H x 0.11 D, lowest point y = 2.36 (the clamp)
## Even at the clamp the batten clears the 1.8 m player by 0.56 m, which is what
## the clamp is for.
## 6 meshes, 156 triangles, 1 OmniLight3D (no shadows), 1 flicker driver Node.
static func failing_tube(parent: Node3D, origin: Vector3, yaw_degrees := 0.0,
		sag_degrees := 0.0, tint := TINT_FAILING, energy := 0.8,
		pattern := PATTERN_STARVED, node_name := "") -> Node3D:
	var root := _root(parent, origin, node_name if node_name != "" else "Failing Tube")
	root.rotation_degrees = Vector3(0, yaw_degrees, 0)

	var sag: float = clampf(sag_degrees, 0.0, 42.0)
	var anchor := Vector3(-0.58, -0.09, 0)
	_strut(root, "Failing Tube Hanger", Vector3(-0.58, 0, 0), anchor,
		0.014, STEEL_MID, 0.6)

	# The whole batten hangs off the surviving hanger. Rotating about -Z drops the
	# +X end, so "sag" always means "the east end fell".
	var arm := Node3D.new()
	arm.name = "Failing Tube Arm"
	arm.position = anchor
	arm.rotation_degrees = Vector3(0, 0, -sag)
	root.add_child(arm)

	_box(arm, "Failing Tube Batten", Vector3(0.58, -0.015, 0),
		Vector3(1.46, 0.07, 0.11), STEEL_DARK, 0.0, 0.45)
	var tube := _cylinder(arm, "Failing Tube Lamp", Vector3(0.58, -0.06, 0),
		0.028, 1.30, tint, 1.3, 0.0)
	tube.rotation_degrees = Vector3(0, 0, 90)
	tube.set_meta(LAMP_FACE_META, true)
	for side in [-1.0, 1.0]:
		_box(arm, "Failing Tube Cap %s" % ("West" if side < 0.0 else "East"),
			Vector3(0.58 + side * 0.68, -0.06, 0), Vector3(0.06, 0.075, 0.075),
			STEEL_MID, 0.0, 0.5)

	# Supply flex from the ceiling to the dropped end. Drawn in root space from
	# the arm's transform so it always meets the batten, whatever the sag.
	var dropped: Vector3 = anchor + arm.transform.basis * Vector3(1.16, -0.015, 0)
	_strut(root, "Failing Tube Flex", Vector3(0.58, 0, 0), dropped,
		0.009, Color(0.05, 0.05, 0.055), 0.2)

	var lamp := OmniLight3D.new()
	lamp.name = "Failing Tube Light"
	lamp.position = Vector3(0.58, -0.22, 0)
	lamp.light_color = tint
	lamp.light_energy = energy
	lamp.omni_range = 7.5
	lamp.omni_attenuation = 1.2
	_tune(lamp, false)
	arm.add_child(lamp)

	if pattern != PATTERN_STEADY:
		attach_flicker(root, pattern)
	# The dying tube hums: +12 dB over the baked -35.0 dBFS RMS loop puts it
	# at -23 dBFS RMS at the batten, level with the room tone at arm's length
	# and gone by six metres, so it never drills into the player's ear. In
	# lamp_hum so the blackout can cut it with the mains.
	var hum := AudioStreamPlayer3D.new()
	hum.name = "Lamp Hum"
	hum.position = Vector3(0.58, -0.06, 0)
	hum.stream = load(LAMP_HUM_PATH)
	if hum.stream != null:
		hum.unit_size = 2.2
		hum.max_distance = 6.0
		hum.volume_db = 12.0
		hum.bus = "Ambience"
		hum.autoplay = true
		hum.add_to_group("lamp_hum")
		arm.add_child(hum)
	return root


# =============================================================================
# Flicker
# =============================================================================


## Attach a flicker driver to any fitting built by this file.
##
## Drives every Light3D under `root` and every mesh tagged as a lamp face from one
## closed-form function of time, so the glass and the light it casts always agree.
## Idempotent: calling it twice retunes the existing driver instead of stacking a
## second one. `phase` below zero derives a stable offset from the fitting's own
## position, which is what keeps a row of failing battens from blinking in unison.
##
## ACCESSIBILITY CONTRACT. While SettingsManager.reduced_flashes is true the
## driver pins the fitting at its authored energy and emission and performs no
## modulation of any kind -- not a reduced one, none. A flickering museum is the
## whole look, and it is also precisely the thing that setting exists to switch
## off. The flag is re-read continuously (throttled group lookup, one property
## read per frame), so toggling it in the settings panel takes effect immediately
## and in both directions without rebuilding the map.
##
## The driver also disables itself under Engine.is_editor_hint(), matching
## FirstMuseumMap._process(): the map is a @tool script and builds in the editor.
static func attach_flicker(root: Node3D, pattern := PATTERN_STARVED,
		phase := -1.0) -> Node:
	if root == null:
		return null
	var existing := root.get_node_or_null(NodePath(FLICKER_NODE_NAME))
	if existing != null:
		existing.set("pattern", pattern)
		if phase >= 0.0:
			existing.set("phase", phase)
		return existing

	var driver := Flicker.new()
	driver.name = FLICKER_NODE_NAME
	driver.pattern = pattern
	# A deterministic, position-derived offset. Two fittings 1 m apart are ~0.4 s
	# out of step; nothing in the museum is ever in sync with anything else.
	driver.phase = phase if phase >= 0.0 \
		else fposmod(root.position.x * 0.37 + root.position.z * 0.71, 12.0)

	for light in lights_of(root):
		driver.lights.append(light)
		driver.light_energy.append(light.light_energy)
	for face in _lamp_faces(root):
		# The builders hand out materials from the shared static cache. Mutating
		# one in place would dim every other fitting that happens to use the same
		# colour, so a flickering fitting gets private copies here -- once, at
		# attach time, not per frame.
		var mat := face.material_override as StandardMaterial3D
		if mat == null:
			continue
		mat = mat.duplicate() as StandardMaterial3D
		face.material_override = mat
		driver.faces.append(mat)
		driver.face_emission.append(mat.emission_energy_multiplier)

	root.add_child(driver)
	return driver


## The flicker driver added by attach_flicker(), or null. Exposed so a call site
## can retune `pattern` or `phase` on a fitting it already placed.
static func flicker_of(root: Node3D) -> Node:
	if root == null:
		return null
	return root.get_node_or_null(NodePath(FLICKER_NODE_NAME))


## Self-driving flicker. Kept as an inner class so this file stays the single
## self-contained unit the map has to know about.
class Flicker extends Node:
	var pattern := PATTERN_STARVED
	var phase := 0.0
	var lights: Array[Light3D] = []
	var light_energy: Array[float] = []
	var faces: Array[StandardMaterial3D] = []
	var face_emission: Array[float] = []

	var _time := 0.0
	var _settings: Node = null
	var _resolve_in := 0.0
	## True while the fitting is pinned steady for reduced_flashes, so the restore
	## is written once instead of every frame.
	var _pinned := false

	func _ready() -> void:
		if Engine.is_editor_hint():
			set_process(false)
			return
		_apply(1.0)

	func _process(delta: float) -> void:
		if _reduced(delta):
			if not _pinned:
				_apply(1.0)
				_pinned = true
			return
		_pinned = false
		_time += delta
		_apply(_level(_time + phase))

	## Poll SettingsManager. The node is a sibling of the map that may not exist
	## when the map builds, so the lookup is retried once a second until it
	## resolves and then cached; the per-frame cost after that is one property
	## read. Absent manager means the option is off, which is its default.
	func _reduced(delta: float) -> bool:
		if not is_instance_valid(_settings):
			_settings = null
			_resolve_in -= delta
			if _resolve_in <= 0.0:
				_resolve_in = 1.0
				var tree := get_tree()
				if tree != null:
					_settings = tree.get_first_node_in_group("settings_manager")
			if _settings == null:
				return false
		return bool(_settings.get("reduced_flashes"))

	## Multiplier in [0, 1] applied to both light energy and lamp emission.
	func _level(t: float) -> float:
		match pattern:
			PATTERN_BALLAST:
				var buzz := 0.5 + 0.5 * sin(t * 37.0)
				var drift := 0.5 + 0.5 * sin(t * 11.3 + 2.1)
				return clampf(0.30 + 0.70 * buzz * drift, 0.05, 1.0)
			PATTERN_DYING:
				var breath := 0.55 + 0.45 * sin(t * 0.7)
				var collapse := 1.0 if sin(t * 0.31 + 0.7) > -0.86 else 0.08
				return clampf(breath * collapse, 0.03, 1.0)
			PATTERN_STARVED:
				# Two incommensurable sines gate the dropout, so the fitting runs
				# clean for seconds at a time and then stutters hard, without ever
				# repeating on a period the player can learn.
				var gate := sin(t * 0.83) + 0.55 * sin(t * 1.97 + 1.3)
				if gate > -1.05:
					return 1.0
				return clampf(0.05 + 0.40 * absf(sin(t * 41.0)), 0.0, 1.0)
			_:
				return 1.0

	func _apply(level: float) -> void:
		for i in range(lights.size()):
			var light := lights[i]
			if is_instance_valid(light):
				light.light_energy = light_energy[i] * level
		# Glass never goes fully black: a dead tube still catches what light is
		# left in the room, and a hole in the ceiling reads as missing geometry.
		var glass: float = maxf(level, 0.03)
		for i in range(faces.size()):
			faces[i].emission_energy_multiplier = face_emission[i] * glass


# =============================================================================
# Lookups
# =============================================================================


## First Light3D inside a fitting, or null. The one-light fittings (troffer,
## emergency, sconce, failing tube) have exactly one; spot_rig() has one per head,
## so use lights_of() there.
static func light_of(root: Node3D) -> Light3D:
	var found := lights_of(root)
	return found[0] if not found.is_empty() else null


## Every Light3D inside a fitting, in construction order. Append these to
## FirstMuseumMap._powered_lights to have the blackout kill them.
static func lights_of(root: Node3D) -> Array[Light3D]:
	var found: Array[Light3D] = []
	_collect_lights(root, found)
	return found


static func _collect_lights(node: Node, into: Array[Light3D]) -> void:
	if node == null:
		return
	var light := node as Light3D
	if light != null:
		into.append(light)
	for child in node.get_children():
		_collect_lights(child, into)


static func _lamp_faces(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	_collect_faces(root, found)
	return found


static func _collect_faces(node: Node, into: Array[MeshInstance3D]) -> void:
	if node == null:
		return
	var mesh := node as MeshInstance3D
	if mesh != null and mesh.has_meta(LAMP_FACE_META):
		into.append(mesh)
	for child in node.get_children():
		_collect_faces(child, into)


## Drop the shared material cache. Only useful to a test that wants to measure
## allocation, or to an editor rebuild that has changed the palette.
static func clear_material_cache() -> void:
	_materials.clear()


# =============================================================================
# Primitives
# =============================================================================


static func _root(parent: Node3D, origin: Vector3, node_name: String) -> Node3D:
	var root := Node3D.new()
	# A repeated sibling name makes Godot rename the second fitting to
	# @Node3D@NNN, so the blackout audit can no longer identify it.
	if parent.has_node(NodePath(node_name)):
		node_name = "%s %s" % [node_name, origin]
	root.name = node_name
	root.position = origin
	root.add_to_group(FIXTURE_GROUP)
	parent.add_child(root)
	return root


static func _box(parent: Node, node_name: String, offset: Vector3, size: Vector3,
		color: Color, emission := 0.0, metallic := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _instance(parent, node_name, offset, mesh, color, emission, metallic)


static func _cylinder(parent: Node, node_name: String, offset: Vector3,
		radius: float, height: float, color: Color, emission := 0.0,
		metallic := 0.0) -> MeshInstance3D:
	return _cone(parent, node_name, offset, radius, radius, height, color,
		emission, metallic)


static func _cone(parent: Node, node_name: String, offset: Vector3,
		bottom_radius: float, top_radius: float, height: float, color: Color,
		emission := 0.0, metallic := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	# 64 radial segments on a 0.02 m hanger rod is 256 triangles of nothing.
	mesh.radial_segments = 10
	mesh.rings = 0
	return _instance(parent, node_name, offset, mesh, color, emission, metallic)


static func _prism(parent: Node, node_name: String, offset: Vector3,
		size: Vector3, color: Color, metallic := 0.0) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _instance(parent, node_name, offset, mesh, color, 0.0, metallic)


## Cylinder spanning two points in the parent's local space. Used for hanger rods,
## spot stems and the failing tube's supply flex, none of which are axis-aligned
## once anything has sagged.
static func _strut(parent: Node, node_name: String, from: Vector3, to: Vector3,
		radius: float, color: Color, metallic := 0.0) -> MeshInstance3D:
	var delta := to - from
	var length := delta.length()
	if length < 0.001:
		return null
	var inst := _cylinder(parent, node_name, (from + to) * 0.5, radius, length,
		color, 0.0, metallic)
	# CylinderMesh runs along +Y; _aim_basis puts -Z on the span, and -90 about X
	# maps +Y onto -Z, so the composition puts the cylinder on the span.
	var xform := inst.transform
	xform.basis = _aim_basis(delta) * Basis(Vector3.RIGHT, deg_to_rad(-90))
	inst.transform = xform
	return inst


## Basis whose -Z axis lies along `dir` -- the axis SpotLight3D aims down.
## Computed rather than delegated to Node3D.look_at() so it is valid before the
## node is in the tree, and guarded against the straight-up/straight-down case
## that makes Basis.looking_at() degenerate.
static func _aim_basis(dir: Vector3) -> Basis:
	var d := dir
	if d.length_squared() < 0.000001:
		d = Vector3.DOWN
	d = d.normalized()
	var up := Vector3.UP
	if absf(d.dot(up)) > 0.999:
		up = Vector3.FORWARD
	return Basis.looking_at(d, up)


## Square acrylic panel in a troffer. Lit panels emit; dead ones are grey plastic
## that has stopped pretending, which is the only difference the player needs.
static func _diffuser(parent: Node, node_name: String, offset: Vector3,
		tint: Color, lit: bool) -> MeshInstance3D:
	var panel := _box(parent, node_name, offset, Vector3(0.56, 0.03, 0.56),
		tint if lit else LAMP_DEAD, 1.2 if lit else 0.0, 0.0)
	if lit:
		panel.set_meta(LAMP_FACE_META, true)
	return panel


static func _instance(parent: Node, node_name: String, offset: Vector3,
		mesh: PrimitiveMesh, color: Color, emission: float,
		metallic: float) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.position = offset
	inst.mesh = mesh
	inst.material_override = _material(color, emission, metallic)
	# No fitting in this file casts a shadow. Every one of them sits above or
	# behind its own light source, so the only thing it could shadow is itself.
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.visibility_range_end = CULL_DISTANCE
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# Deliberately no StaticBody3D -- see the file header. Collision here would
	# feed the navigation bake and could strand the Curator in a doorway.
	parent.add_child(inst)
	return inst


static func _material(color: Color, emission: float,
		metallic: float) -> StandardMaterial3D:
	var key := "%s|%.3f|%.3f" % [color.to_html(true), emission, metallic]
	if _materials.has(key):
		return _materials[key]

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.metallic_specular = 0.5
	# Painted steel: duller than the map's polished marble, and duller still the
	# more metallic it is, so the fittings never read as chrome.
	mat.roughness = clampf(0.66 - metallic * 0.34, 0.16, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
		# Emissive glass has no business being darkened by a shadow it is
		# standing inside; the map's glow pass picks it up either way.
		mat.disable_receive_shadows = true
	_materials[key] = mat
	return mat


## Shared setup for every Light3D in this file. Shadow settings are the expensive
## half of the budget, so they are stated in one place: bias tuned for the thin
## fixture geometry, a shadow cutoff at FADE_SHADOW well inside the light's own
## fade, and no lightmap participation anywhere.
static func _tune(light: Light3D, shadows: bool) -> void:
	light.light_bake_mode = Light3D.BAKE_DISABLED
	light.distance_fade_enabled = true
	light.distance_fade_begin = FADE_BEGIN
	light.distance_fade_length = FADE_LENGTH
	light.distance_fade_shadow = FADE_SHADOW
	light.shadow_enabled = shadows
	if shadows:
		light.shadow_bias = 0.035
		light.shadow_normal_bias = 1.4
		light.shadow_opacity = 0.92
	var omni := light as OmniLight3D
	if omni != null:
		# Dual paraboloid renders one shadow map instead of a cube's six. These
		# are ceiling fittings whose interesting hemisphere is the lower one.
		omni.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	light.add_to_group(LIGHT_GROUP)
