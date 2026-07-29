@tool
class_name CorridorProps
extends RefCounted
## Connective tissue of the First Museum: the fixtures that live between the
## exhibits rather than in them -- door frames, extinguishers, emergency signs,
## floor scuffs, ceiling hatches, cable trays, rub rails, wall vents and a fire
## hose reel. Corridors are what the player walks through between every beat,
## and an empty corridor is the fastest way to make a building read as a set.
##
## SELF-CONTAINED ON PURPOSE. Nothing here preloads or calls into
## FirstMuseumMap. The primitive helpers at the bottom are a deliberate copy of
## its _box()/_primitive()/_material() conventions -- visibility range, shadow
## suppression on tiny meshes, the collision_worthy threshold, the shared
## material cache and the roughness/bump noise -- so props built here sit in the
## same PS1-horror surface language as the walls they hang on.
##
## CALL SHAPE. Every builder takes (parent, origin, ...), parents exactly one
## Node3D at `origin` and returns it, so the map places a prop in one line:
##
##     CorridorProps.fire_extinguisher(map_root, Vector3(-14.6, 0, 3.2), 90.0)
##
## Local axes inside a wall-mounted prop: +X runs along the wall, +Y is up and
## +Z points out of the wall into the room. `yaw_deg` turns the whole prop about
## Y, so the caller only ever decides "which wall, and which way is out".
## Godot's Y rotation sends local +Z to world +X at yaw +90 and to world -X at
## yaw -90 (local +X goes to world -Z and +Z respectively).
##
## DOORWAYS. DOOR_GAP is 1.8 m and the navmesh bake erodes 0.45 m per side, so
## 0.9 m of walkable width is every doorway's entire budget and the Curator's
## only way between rooms. No collider built by this file enters the band
## |along-wall| < DOOR_CLEAR_HALF; door_frame() holds its jambs 0.02 m further
## out again. Free-standing props (extinguisher, hose reel, vent) belong on wall
## runs, at least 1.2 m from any doorway centre.
##
## SCALE. Rooms are WALL_HEIGHT (3.4 m) tall. Every builder documents its
## bounding box in metres above its signature; nothing here exceeds 3.10 m.
##
## COST. Meshes per call, measured, so the integrator can budget against the
## ~1270 the map already builds: door_frame 14 (8 without casing),
## fire_extinguisher 10, exit_sign 7 (9 with an arrow, 13 suspended and
## labelled), floor_scuffs = count, ceiling_hatch 8 shut / 6 ajar, cable_tray
## 19 for an 8 m run of three cables, skirting_run 5 for 6 m, wall_vent 7,
## fire_hose_reel 9 (12 with the hose tail), dress_doorway 31 fully dressed.
##
## MOTION. There is none: no prop here animates, flickers or pulses, so nothing
## needs a SettingsManager.reduced_flashes reader. The horror is carried by
## silhouette and by the black inside a vent, not by movement. The emergency
## signs are lit by constant emission and are deliberately NOT registered with
## the map's powered-light system -- battery-backed exit signage staying up when
## the museum's lights fail is both correct for the fiction and the one
## navigational aid a player must never lose.


# --- The geometry the museum is built to ------------------------------------
# Mirrors of FirstMuseumMap constants. Copied rather than imported to keep this
# file free of the map's dependency chain; they are load-bearing here, so they
# are named instead of inlined.
const WALL_HEIGHT := 3.4
const WALL_THICKNESS := 0.35
const DOOR_GAP := 1.8
## Half of DOOR_GAP. Hard limit: no collider crosses this line.
const DOOR_CLEAR_HALF := DOOR_GAP * 0.5
## Underside of the ceiling slab (_add_room puts it at WALL_HEIGHT + 0.05,
## 0.12 thick). Ceiling fixtures hang from here, not from WALL_HEIGHT.
const CEILING_SOFFIT_Y := WALL_HEIGHT + 0.05 - 0.06
## Face of a shared wall, measured from the seam between two rooms. Both rooms
## inset their wall by half a thickness, so the pair is 2 x WALL_THICKNESS
## thick and each visible face sits this far from the seam.
const SHARED_WALL_FACE := WALL_THICKNESS

# --- Palette ----------------------------------------------------------------
# Service fittings, not gallery dressing: the museum's white marble is the
# bright thing, everything screwed to it is nearly black.
const STEEL := Color(0.135, 0.140, 0.148)
const STEEL_DARK := Color(0.060, 0.062, 0.066)
## The black behind a grille or an open hatch. Reads as a hole, not a surface.
const VOID_BLACK := Color(0.012, 0.012, 0.014)
const RUBBER := Color(0.045, 0.045, 0.050)
const EXTINGUISHER_RED := Color(0.34, 0.050, 0.045)
## Dark green field. Luminance 0.070 against the glyph's 0.812 is 7.2:1, so the
## pictogram clears 4.5:1 on albedo alone; the glyph also carries three times
## the field's emission, which only widens the rendered ratio.
const SIGN_FIELD := Color(0.06, 0.34, 0.16)
const SIGN_GLYPH := Color(0.86, 0.93, 0.88)
const BRASS := Color(0.30, 0.26, 0.17)

const SIGN_FIELD_ENERGY := 0.5
const SIGN_GLYPH_ENERGY := 1.4

# Small fittings are culled sooner than the map's 115 m walls: at 70 m a
# 0.3 m extinguisher is a pixel and a half.
const PROP_VISIBILITY_RANGE := 70.0


# =============================================================================
#  Door frames
# =============================================================================

## Inner face of a jamb, 0.02 m clear of DOOR_CLEAR_HALF.
const JAMB_HALF := 0.92
const JAMB_THICK := 0.16
## Spans both back-to-back walls plus a lip on each side.
const FRAME_DEPTH := WALL_THICKNESS * 2.0 + 0.16
## Underside of the header. WALL_HEIGHT - 0.7 matches the lintel the wall
## builder drops into every doorway gap.
const DOOR_HEAD_HEIGHT := WALL_HEIGHT - 0.7


## A doorway lining with real jambs, a header, architrave casing on both faces
## and a walked-over threshold plate.
##
## `origin` is the seam between the two rooms, at floor level -- the same point
## the map's own door frames are placed on. `axis` is "x" for a wall running
## east-west (the doorway faces north/south) or "z" for a north-south wall; the
## whole prop is built along local X and the root is yawed for "z", which is
## structurally why this cannot repeat the swapped-axis bug that once planted
## every frame sideways.
##
## This REPLACES FirstMuseumMap._add_door_frame on a given doorway -- placing
## both puts two lots of jambs in the same 0.86 m of wall.
##
## Bounding box: 2.36 (along the wall) x 3.10 (h) x 0.96 (through the wall).
## Colliders: the two jambs (outer faces at +-1.08, inner at +-0.92) and the
## header at 2.70-3.00 m. The clear opening is 1.84 m, which bakes to 0.94 m of
## navmesh -- 0.04 m more than the map's own frames leave.
static func door_frame(parent: Node3D, origin: Vector3, axis: String,
		casing := true, threshold := true) -> Node3D:
	var root := _root(parent, "Door Frame %s" % [origin], origin, _axis_yaw(axis))
	var jamb_offset := JAMB_HALF + JAMB_THICK * 0.5
	var jamb_outer := JAMB_HALF + JAMB_THICK
	var header_y := DOOR_HEAD_HEIGHT + 0.15

	for i in range(2):
		var s: float = -1.0 if i == 0 else 1.0
		_box(root, "Jamb %d" % i, Vector3(s * jamb_offset, DOOR_HEAD_HEIGHT * 0.5, 0),
			Vector3(JAMB_THICK, DOOR_HEAD_HEIGHT, FRAME_DEPTH), STEEL_DARK)
		# Kick plate: outer face lands exactly on DOOR_CLEAR_HALF, so it fills
		# the jamb reveal without stealing a millimetre of the opening.
		_box(root, "Jamb Kick Plate %d" % i, Vector3(s * 0.91, 0.17, 0),
			Vector3(0.02, 0.34, FRAME_DEPTH), RUBBER, 0.0, 0.0, false)
	_box(root, "Header", Vector3(0, header_y, 0),
		Vector3(jamb_outer * 2.0, 0.30, FRAME_DEPTH), STEEL_DARK)

	if casing:
		# Architrave stands 0.05 m proud of each wall face. Too thin to collide,
		# which is what keeps a doorway's approach clean.
		var casing_z := FRAME_DEPTH * 0.5 + 0.025
		var casing_half := jamb_outer + 0.10
		for i in range(2):
			var sz: float = -1.0 if i == 0 else 1.0
			_box(root, "Head Casing %d" % i, Vector3(0, 3.05, sz * casing_z),
				Vector3(casing_half * 2.0, 0.10, 0.05), STEEL_DARK, 0.0, 0.0, false)
			for j in range(2):
				var sx: float = -1.0 if j == 0 else 1.0
				_box(root, "Side Casing %d%d" % [i, j],
					Vector3(sx * (jamb_outer + 0.05), 1.50, sz * casing_z),
					Vector3(0.10, 3.00, 0.05), STEEL_DARK, 0.0, 0.0, false)

	if threshold:
		# Visual only. A colliding threshold is a tiny wall that CharacterBody3D
		# cannot step over, and it would sit squarely in the doorway.
		_box(root, "Threshold", Vector3(0, 0.015, 0),
			Vector3(jamb_outer * 2.0, 0.03, FRAME_DEPTH), STEEL_DARK.darkened(0.2),
			0.0, 0.0, false)
		for i in range(2):
			var s: float = -1.0 if i == 0 else 1.0
			_box(root, "Threshold Wear Strip %d" % i,
				Vector3(0, 0.037, s * 0.30),
				Vector3(jamb_outer * 2.0, 0.014, 0.05), BRASS, 0.0, 0.55, false)
	return root


## Door frame + the wear a doorway accumulates: scuffed floor either side and an
## illuminated way-out sign on one flank, arrow pointing back at the opening.
##
## `sign_side` is -1, 0 or +1: which side of the doorway the sign hangs on along
## the wall, 0 for none. The sign is placed at +-1.50 m along the wall (clear of
## the 1.18 m casing) at 2.25 m, flat against one wall face -- world +Z for axis
## "x", world +X for axis "z". A doorway that wants signage on both approaches
## takes a second exit_sign() call on the far face, yawed 180 degrees.
##
## Bounding box: 3.50 (along the wall, the sign end) x 3.10 (h) x 4.70 (through
## the wall). Everything outside door_frame's own 2.36 x 3.10 x 0.96 is either a
## 0.02 m floor mark -- the scuff patches reach 2.35 m either side of the seam --
## or the 0.05 m sign. Colliders: door_frame's only.
static func dress_doorway(parent: Node3D, origin: Vector3, axis: String,
		sign_side := 0, scuffs := true, frame := true) -> Node3D:
	var root := _root(parent, "Doorway Dressing %s" % [origin], origin, _axis_yaw(axis))
	if frame:
		# Built inside the dressing root at zero yaw: the root already carries
		# the axis rotation, so the frame must not apply it a second time.
		door_frame(root, Vector3.ZERO, "x")
	if scuffs:
		for i in range(2):
			var s: float = -1.0 if i == 0 else 1.0
			floor_scuffs(root, Vector3(0, 0, s * 1.25), 2.2, 4,
				hash(origin) + i * 7919)
	if sign_side != 0:
		var side: float = signf(float(sign_side))
		exit_sign(root, Vector3(side * 1.50, 2.25, SHARED_WALL_FACE + 0.025),
			0.0, -sign_side)
	return root


# =============================================================================
#  Wall fittings
# =============================================================================

## Extinguisher on a wall bracket under a fire-point plate. `origin` is where
## the prop meets the wall, at floor level; +Z leaves the wall, so `yaw_deg`
## 0 faces south (+Z), 180 north, +90 east, -90 west.
##
## Bounding box: 0.30 (w) x 0.95 (h) x 0.19 (out of the wall), occupying
## y 0.87-1.82 above origin.y. Collider: the bottle only, 0.15 x 0.44 x 0.15,
## reaching 0.19 m into the room.
static func fire_extinguisher(parent: Node3D, origin: Vector3,
		yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, "Fire Extinguisher %s" % [origin], origin, yaw_deg)
	_box(root, "Backboard", Vector3(0, 1.20, 0.016),
		Vector3(0.30, 0.66, 0.03), STEEL_DARK, 0.0, 0.0, false)
	for i in range(2):
		var y: float = 1.36 if i == 0 else 1.02
		_box(root, "Bracket %d" % i, Vector3(0, y, 0.075),
			Vector3(0.11, 0.05, 0.13), STEEL, 0.0, 0.45, false)
	_cylinder(root, "Bottle", Vector3(0, 1.19, 0.115), 0.075, 0.44,
		EXTINGUISHER_RED)
	_cylinder(root, "Valve Neck", Vector3(0, 1.455, 0.115), 0.030, 0.09, STEEL)
	_box(root, "Carry Handle", Vector3(0, 1.515, 0.115),
		Vector3(0.14, 0.028, 0.05), STEEL, 0.0, 0.5, false)
	var gauge := _cylinder(root, "Pressure Gauge", Vector3(0.055, 1.445, 0.16),
		0.026, 0.018, BRASS, false, 0.0, false)
	gauge.rotation_degrees = Vector3(90, 0, 0)
	var hose := _cylinder(root, "Discharge Hose", Vector3(0.035, 1.29, 0.175),
		0.014, 0.26, RUBBER, false, 0.0, false)
	hose.rotation_degrees = Vector3(0, 0, 22)
	# Fire-point marker: a plate and a flame, no text. A pictogram needs no
	# translation and reads at a glance in a dark corridor.
	_box(root, "Fire Point Plate", Vector3(0, 1.72, 0.02),
		Vector3(0.20, 0.20, 0.012), EXTINGUISHER_RED.darkened(0.15), 0.0, 0.0, false)
	_prism(root, "Fire Point Glyph", Vector3(0, 1.705, 0.031),
		Vector3(0.09, 0.12, 0.014), SIGN_GLYPH)
	return root


## Illuminated way-out sign: a running figure and, optionally, a direction
## arrow. `origin` is the centre of the panel, `arrow` is -1 (left), 0 (none) or
## +1 (right) in the sign's own frame. `suspend_from` >= 0 hangs the panel from
## that world Y on two rods instead of mounting it flat to a wall; `label` is a
## caller-translated string rendered on a second plate below the pictogram --
## pass tr("...") or leave it empty for pictogram-only, which is the default and
## needs no catalogue entry.
##
## No colour-only meaning: the pictogram carries it, the green is decoration.
##
## Bounding box: 0.50 (w) x 0.26 (h) x 0.05 (out of the wall); 0.40 h with a
## label; when suspended the height grows by (suspend_from - origin.y) and the
## depth to 0.10 for the ceiling plate. No collider.
static func exit_sign(parent: Node3D, origin: Vector3, yaw_deg := 0.0,
		arrow := 0, suspend_from := -1.0, label := "") -> Node3D:
	var root := _root(parent, "Way Out Sign %s" % [origin], origin, yaw_deg)
	_box(root, "Backer", Vector3(0, 0, -0.012), Vector3(0.50, 0.26, 0.02),
		STEEL_DARK, 0.0, 0.0, false)
	_box(root, "Field", Vector3(0, 0, 0.005), Vector3(0.46, 0.22, 0.03),
		SIGN_FIELD, SIGN_FIELD_ENERGY, 0.0, false)

	# Running figure, five boxes, left third of the panel. Everything stays
	# inside the +-0.11 half-height of the field.
	var glyph_z := 0.024
	_box(root, "Figure Head", Vector3(-0.148, 0.060, glyph_z),
		Vector3(0.040, 0.040, 0.012), SIGN_GLYPH, SIGN_GLYPH_ENERGY, 0.0, false)
	var torso := _box(root, "Figure Torso", Vector3(-0.132, 0.005, glyph_z),
		Vector3(0.048, 0.095, 0.012), SIGN_GLYPH, SIGN_GLYPH_ENERGY, 0.0, false)
	torso.rotation_degrees = Vector3(0, 0, 12)
	var arm := _box(root, "Figure Arm", Vector3(-0.088, 0.028, glyph_z),
		Vector3(0.030, 0.070, 0.012), SIGN_GLYPH, SIGN_GLYPH_ENERGY, 0.0, false)
	arm.rotation_degrees = Vector3(0, 0, -58)
	var lead_leg := _box(root, "Figure Lead Leg", Vector3(-0.098, -0.058, glyph_z),
		Vector3(0.034, 0.078, 0.012), SIGN_GLYPH, SIGN_GLYPH_ENERGY, 0.0, false)
	lead_leg.rotation_degrees = Vector3(0, 0, -34)
	var back_leg := _box(root, "Figure Trailing Leg", Vector3(-0.168, -0.055, glyph_z),
		Vector3(0.034, 0.075, 0.012), SIGN_GLYPH, SIGN_GLYPH_ENERGY, 0.0, false)
	back_leg.rotation_degrees = Vector3(0, 0, 30)

	if arrow != 0:
		var dir: float = signf(float(arrow))
		var head := _prism(root, "Arrow Head", Vector3(dir * 0.145, 0, glyph_z),
			Vector3(0.085, 0.090, 0.012), SIGN_GLYPH, SIGN_GLYPH_ENERGY)
		head.rotation_degrees = Vector3(0, 0, -90.0 * dir)
		_box(root, "Arrow Shaft", Vector3(dir * 0.072, 0, glyph_z),
			Vector3(0.085, 0.030, 0.012), SIGN_GLYPH, SIGN_GLYPH_ENERGY, 0.0, false)

	if label != "":
		# Own plate under the pictogram rather than crammed beside it: pale
		# glyph on STEEL_DARK is 15.6:1, and the figure keeps its full panel.
		_box(root, "Label Plate", Vector3(0, -0.20, 0.0),
			Vector3(0.50, 0.14, 0.024), STEEL_DARK, 0.0, 0.0, false)
		var text := Label3D.new()
		text.name = "Label Text"
		text.text = label
		text.position = Vector3(0, -0.20, 0.014)
		text.modulate = SIGN_GLYPH
		text.font_size = 64
		text.pixel_size = 0.0014
		# Not billboarded: this is a fixture bolted to a wall, and a swivelling
		# panel is exactly what made the CCTV feeds unreadable elsewhere.
		text.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		text.outline_size = 6
		text.outline_modulate = Color(0, 0, 0, 0.9)
		text.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		text.visibility_range_end = 26.0
		text.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		root.add_child(text)

	if suspend_from >= 0.0:
		var rod_length: float = maxf(0.05, suspend_from - origin.y - 0.13)
		for i in range(2):
			var s: float = -1.0 if i == 0 else 1.0
			_cylinder(root, "Suspension Rod %d" % i,
				Vector3(s * 0.17, 0.13 + rod_length * 0.5, 0),
				0.008, rod_length, STEEL, false, 0.0, false)
		_box(root, "Ceiling Plate", Vector3(0, 0.13 + rod_length, 0),
			Vector3(0.42, 0.02, 0.10), STEEL_DARK, 0.0, 0.0, false)
	return root


## Louvred wall vent: a steel surround, a black interior and tilted slats. The
## darkness behind the louvres is the point -- it is the only place in a
## corridor where the museum admits it has an inside.
##
## `origin` is the centre of the grille on the wall face; +Z leaves the wall.
##
## Bounding box: (width + 0.06) x (height + 0.06) x 0.052; 0.66 x 0.42 x 0.05 at
## the defaults. No collider -- 0.05 m of relief is not something to bump into.
static func wall_vent(parent: Node3D, origin: Vector3, yaw_deg := 0.0,
		width := 0.60, height := 0.36, louvres := 5) -> Node3D:
	var root := _root(parent, "Wall Vent %s" % [origin], origin, yaw_deg)
	_box(root, "Surround", Vector3(0, 0, 0.009),
		Vector3(width + 0.06, height + 0.06, 0.018), STEEL_DARK, 0.0, 0.4, false)
	_box(root, "Interior", Vector3(0, 0, 0.016),
		Vector3(width - 0.02, height - 0.02, 0.012), VOID_BLACK, 0.0, 0.0, false)
	var blades: int = maxi(2, louvres)
	var span: float = height - 0.07
	var step: float = span / float(blades - 1)
	for i in range(blades):
		var slat := _box(root, "Louvre %d" % i,
			Vector3(0, height * 0.5 - 0.035 - step * float(i), 0.028),
			Vector3(width - 0.05, 0.030, 0.035), STEEL, 0.0, 0.35, false)
		# Tipped down and out, the way a real louvre sheds water: the top edge
		# catches the light and the gap under it stays black.
		slat.rotation_degrees = Vector3(-28, 0, 0)
	return root


## Fire hose reel in a shallow open cabinet, with the nozzle end of the hose
## paid out across the floor when `hose_tail` is set. Somebody was here.
##
## `origin` is where the cabinet meets the wall, at floor level; +Z leaves the
## wall.
##
## Bounding box: 0.78 (w) x 0.78 (h, y 0.81-1.59) x 0.26 (out of the wall).
## `hose_tail` grows that to 1.40 x 1.59 x 0.85 -- the paid-out hose lies 0.04 m
## tall, running 1.01 m to -X and 0.85 m into the room, so leave that corner of
## floor free. Collider: the coil, a 0.60 x 0.60 x 0.19 upright slab reaching
## 0.20 m into the room.
static func fire_hose_reel(parent: Node3D, origin: Vector3, yaw_deg := 0.0,
		hose_tail := true) -> Node3D:
	var root := _root(parent, "Fire Hose Reel %s" % [origin], origin, yaw_deg)
	var cabinet_y := 1.20
	_box(root, "Cabinet Back", Vector3(0, cabinet_y, 0.015),
		Vector3(0.78, 0.78, 0.03), STEEL_DARK, 0.0, 0.0, false)
	for i in range(2):
		var s: float = -1.0 if i == 0 else 1.0
		_box(root, "Cabinet Return %d" % i, Vector3(s * 0.3725, cabinet_y, 0.12),
			Vector3(0.035, 0.78, 0.24), STEEL, 0.0, 0.3, false)
		_box(root, "Cabinet Rail %d" % i, Vector3(0, cabinet_y + s * 0.3725, 0.12),
			Vector3(0.78, 0.035, 0.24), STEEL, 0.0, 0.3, false)
	var drum := _cylinder(root, "Reel Drum", Vector3(0, cabinet_y, 0.10),
		0.11, 0.14, STEEL_DARK, false, 0.0, false)
	drum.rotation_degrees = Vector3(90, 0, 0)
	_torus(root, "Hose Coil", Vector3(0, cabinet_y, 0.11), 0.115, 0.30,
		EXTINGUISHER_RED.darkened(0.25))
	_cylinder(root, "Feed Pipe", Vector3(0.30, 1.10, 0.055), 0.022, 0.32,
		STEEL, false, 0.0, false)
	_torus(root, "Valve Wheel", Vector3(0.30, 0.95, 0.075), 0.045, 0.075, BRASS)

	if hose_tail:
		var drop := _cylinder(root, "Hose Drop", Vector3(-0.26, 0.46, 0.20),
			0.018, 0.82, RUBBER, false, 0.0, false)
		drop.rotation_degrees = Vector3(-9, 0, 12)
		var run := _cylinder(root, "Hose Run", Vector3(-0.62, 0.020, 0.50),
			0.018, 0.95, RUBBER, true, 0.0, false)
		run.rotation_degrees = Vector3(0, -38, 90)
		_box(root, "Hose Nozzle", Vector3(-0.98, 0.024, 0.78),
			Vector3(0.05, 0.045, 0.14), BRASS, 0.0, 0.5, false)
	return root


## Rub rail along a wall run, with the matching skirting board when the wall was
## not built by FirstMuseumMap._wall_segment -- that helper already emits a
## 0.22 m baseboard on every segment it makes, and a second one in the same
## place z-fights. The rail itself is always safe: nothing else in the museum
## occupies 0.92 m.
##
## `origin` is floor level at the wall face, at the CENTRE of the run; the run
## extends +-length/2 along local X and +Z leaves the wall.
##
## Bounding box: length x 0.965 (h) x 0.046 (out of the wall). No collider --
## 46 mm of relief would only snag the player on a wall they are sliding along.
static func skirting_run(parent: Node3D, origin: Vector3, length: float,
		yaw_deg := 0.0, with_skirt := false) -> Node3D:
	var root := _root(parent, "Skirting Run %s" % [origin], origin, yaw_deg)
	var run: float = maxf(0.4, length)
	_box(root, "Rub Rail", Vector3(0, 0.92, 0.024),
		Vector3(run, 0.09, 0.045), RUBBER, 0.0, 0.0, false)
	var brackets: int = maxi(2, int(run / 2.0))
	var spacing: float = run / float(brackets)
	for i in range(brackets):
		var x: float = -run * 0.5 + spacing * (float(i) + 0.5)
		_box(root, "Rail Bracket %d" % i, Vector3(x, 0.86, 0.012),
			Vector3(0.05, 0.15, 0.028), STEEL, 0.0, 0.35, false)
	if with_skirt:
		_box(root, "Skirting", Vector3(0, 0.11, 0.018),
			Vector3(run, 0.22, 0.035), STEEL_DARK, 0.0, 0.0, false)
	return root


# =============================================================================
#  Ceiling and floor
# =============================================================================

## Service hatch in the ceiling: a steel ring, the black above it and a leaf
## that can hang open. `origin` is a point on the ceiling soffit -- pass
## CEILING_SOFFIT_Y as origin.y and the fixture builds downward from there.
##
## `ajar_deg` is clamped to 0-45. At the maximum a 0.9 m leaf drops 0.64 m, so
## its lowest edge sits at 2.75 m: clear of the player's eyeline and of the
## Curator's 2.25 m capsule. Nothing here collides, so the hatch cannot catch
## either of them.
##
## Bounding box: (size + 0.12) square x (0.07 + size * sin(ajar_deg)) tall,
## hanging below origin.y. Measured at the default 0.9 m: 1.02 x 0.07 x 1.02
## closed, 1.02 x 0.68 x 1.02 at 45 degrees.
static func ceiling_hatch(parent: Node3D, origin: Vector3, size := 0.9,
		ajar_deg := 0.0) -> Node3D:
	var root := _root(parent, "Ceiling Hatch %s" % [origin], origin, 0.0)
	var half: float = size * 0.5
	# Flange built as four bars, not one slab: a slab would cover the very
	# darkness the hatch exists to show.
	for i in range(2):
		var s: float = -1.0 if i == 0 else 1.0
		_box(root, "Flange Bar %d" % i, Vector3(0, -0.022, s * (half + 0.03)),
			Vector3(size + 0.12, 0.045, 0.06), STEEL_DARK, 0.0, 0.35, false)
		_box(root, "Flange Return %d" % i, Vector3(s * (half + 0.03), -0.022, 0),
			Vector3(0.06, 0.045, size), STEEL_DARK, 0.0, 0.35, false)
	_box(root, "Hatch Interior", Vector3(0, -0.030, 0),
		Vector3(size, 0.02, size), VOID_BLACK, 0.0, 0.0, false)

	var swing: float = clampf(ajar_deg, 0.0, 45.0)
	var hinge := Node3D.new()
	hinge.name = "Hatch Hinge"
	hinge.position = Vector3(-half, -0.038, 0)
	hinge.rotation_degrees = Vector3(0, 0, -swing)
	root.add_child(hinge)
	_box(hinge, "Hatch Leaf", Vector3(half, 0, 0),
		Vector3(size - 0.02, 0.03, size - 0.02), STEEL, 0.0, 0.3, false)
	if swing <= 0.0:
		for i in range(2):
			var s: float = -1.0 if i == 0 else 1.0
			_box(root, "Hatch Latch %d" % i,
				Vector3(half - 0.06, -0.055, s * 0.16),
				Vector3(0.05, 0.02, 0.09), STEEL, 0.0, 0.5, false)
	return root


## Cable tray: two rails, rungs, a bundle of cables and wall brackets. Runs
## along local X from `origin`, which is the CENTRE of the run.
##
## NEVER route a tray across a doorway. At the 3.0 m these want to live at, the
## doorway is already full of the lintel the wall builder drops there
## (2.70-3.40 m); stop the run at the wall and start another one beyond it.
##
## `dangle` pays a loose cable down from near the +X end. Keep
## origin.y - dangle >= 1.9 or the player walks their face through it.
##
## Bounding box: length x 0.15 (h, +0.074 / -0.075 about origin.y) x 0.36 (out
## of the wall), plus `dangle` downward. No collider anywhere -- it is 3 m up
## and nothing should ever pathfind into it.
static func cable_tray(parent: Node3D, origin: Vector3, length: float,
		yaw_deg := 0.0, cables := 3, dangle := 0.0) -> Node3D:
	var root := _root(parent, "Cable Tray %s" % [origin], origin, yaw_deg)
	var run: float = maxf(0.7, length)
	for i in range(2):
		var s: float = -1.0 if i == 0 else 1.0
		_box(root, "Tray Rail %d" % i, Vector3(0, 0, s * 0.135),
			Vector3(run, 0.09, 0.02), STEEL, 0.0, 0.5, false)
	var rungs: int = maxi(2, int(run / 0.7))
	var rung_step: float = run / float(rungs)
	for i in range(rungs):
		_box(root, "Tray Rung %d" % i,
			Vector3(-run * 0.5 + rung_step * (float(i) + 0.5), -0.03, 0),
			Vector3(0.028, 0.012, 0.27), STEEL, 0.0, 0.5, false)
	var bundle: int = clampi(cables, 0, 3)
	for i in range(bundle):
		var cable := _cylinder(root, "Cable %d" % i,
			Vector3(0, 0.052, -0.09 + 0.09 * float(i)), 0.022, run,
			RUBBER.lightened(0.02 * float(i)), true, 0.0, false)
		cable.rotation_degrees = Vector3(0, 0, 90)
	var brackets: int = maxi(2, int(run / 2.1))
	var bracket_step: float = run / float(brackets)
	for i in range(brackets):
		_box(root, "Tray Bracket %d" % i,
			Vector3(-run * 0.5 + bracket_step * (float(i) + 0.5), -0.055, 0),
			Vector3(0.05, 0.03, 0.36), STEEL_DARK, 0.0, 0.4, false)
	if dangle > 0.0:
		var loose := _cylinder(root, "Loose Cable",
			Vector3(run * 0.5 - 0.55, -dangle * 0.5, 0.02), 0.020, dangle,
			RUBBER, false, 0.0, false)
		loose.rotation_degrees = Vector3(0, 0, 7)
		_box(root, "Cable Gland", Vector3(run * 0.5 - 0.55, -0.03, 0.02),
			Vector3(0.06, 0.05, 0.06), STEEL_DARK, 0.0, 0.4, false)
	return root


## Scuff marks worn into the floor: flat, unlit, slightly transparent quads,
## one in three of them elongated so the patch reads as drag marks rather than
## as dirt. Deterministic for a given `origin` (or an explicit `rng_seed`), so
## the museum rebuilds identically every run.
##
## `origin` is a point on the floor. Every quad is guaranteed to land inside a
## `spread` x `spread` square centred on it, including its rotation.
##
## Bounding box: spread x 0.02 x spread. No collider, no shadow.
static func floor_scuffs(parent: Node3D, origin: Vector3, spread := 2.0,
		count := 5, rng_seed := 0) -> Node3D:
	var root := _root(parent, "Floor Scuffs %s" % [origin], origin, 0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed if rng_seed != 0 else hash(origin)
	var marks: int = maxi(0, count)
	for i in range(marks):
		var width: float = rng.randf_range(0.30, 0.55)
		var length: float = width * (rng.randf_range(2.6, 4.2) if i % 3 == 2
			else rng.randf_range(0.7, 1.3))
		# Half-diagonal, so the quad stays inside `spread` at any rotation.
		var half_diagonal: float = sqrt(width * width + length * length) * 0.5
		var reach: float = maxf(0.0, spread * 0.5 - half_diagonal)
		var angle: float = rng.randf_range(0.0, TAU)
		var offset: float = rng.randf_range(0.0, reach)
		var shade: float = rng.randf_range(0.10, 0.22)
		# Each mark a hair higher than the last: co-planar transparent quads
		# fight for depth, stacked ones do not.
		_decal(root, "Scuff %d" % i,
			Vector3(cos(angle) * offset, 0.010 + 0.0012 * float(i),
				sin(angle) * offset),
			Vector2(width, length), Color(0.05, 0.05, 0.055, shade),
			rng.randf_range(0.0, 360.0))
	return root


# =============================================================================
#  Primitives
# =============================================================================
# Deliberate copies of FirstMuseumMap's builders: same argument order, same
# visibility range and shadow rules, same collision_worthy threshold, same
# cached materials. This file must not depend on the map, and the map must not
# have to know this file exists.


static var _materials: Dictionary = {}
static var _noise_texture: NoiseTexture2D = null
static var _bump_texture: NoiseTexture2D = null


static func _axis_yaw(axis: String) -> float:
	# "x" = wall running east-west, "z" = wall running north-south. Every prop
	# is authored along local X and the root is turned for "z", which is what
	# makes the two cases impossible to get out of step.
	return 90.0 if axis == "z" else 0.0


static func _root(parent: Node3D, node_name: String, origin: Vector3,
		yaw_deg: float) -> Node3D:
	var root := Node3D.new()
	# A repeated sibling name makes Godot rename the second prop to @Node3D@NNN.
	if parent.has_node(NodePath(node_name)):
		node_name = "%s %s" % [node_name, origin]
	root.name = node_name
	root.position = origin
	root.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(root)
	return root


static func _box(parent: Node, node_name: String, box_position: Vector3,
		size: Vector3, color: Color, emission_energy := 0.0, metallic := 0.0,
		with_collision := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _primitive(parent, node_name, box_position, mesh, size, color,
		false, emission_energy, metallic, with_collision)


static func _cylinder(parent: Node, node_name: String, cylinder_position: Vector3,
		radius: float, height: float, color: Color, horizontal := false,
		emission_energy := 0.0, with_collision := true) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = radius
	mesh.top_radius = radius
	# Service fittings are small and seen from a metre away at most; the
	# default 64 segments is a lot of triangles for a 40 mm pipe.
	mesh.radial_segments = 10
	mesh.rings = 0
	var size := Vector3(radius * 2.0, height, radius * 2.0)
	var inst := _primitive(parent, node_name, cylinder_position, mesh, size,
		color, false, emission_energy, 0.0, with_collision)
	if horizontal:
		# Lay the cylinder on its side (default points up along Y).
		inst.rotate_z(deg_to_rad(90))
	return inst


static func _prism(parent: Node, node_name: String, prism_position: Vector3,
		size: Vector3, color: Color, emission_energy := 0.0) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _primitive(parent, node_name, prism_position, mesh, size, color,
		false, emission_energy, 0.0, false)


static func _torus(parent: Node, node_name: String, torus_position: Vector3,
		inner_radius: float, outer_radius: float, color: Color,
		upright := true) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 16
	mesh.ring_segments = 8
	var thickness := outer_radius - inner_radius
	var inst := _primitive(parent, node_name, torus_position, mesh,
		Vector3(outer_radius * 2.0, thickness, outer_radius * 2.0), color,
		false, 0.0, 0.0)
	if upright:
		# Stand the ring up so it faces out of the wall.
		inst.rotate_x(deg_to_rad(90))
	return inst


## Flat, unlit-looking mark lying on the floor. Never collides (transparent
## geometry is skipped) and never casts a shadow.
static func _decal(parent: Node, node_name: String, decal_position: Vector3,
		size: Vector2, color: Color, yaw_deg := 0.0) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var inst := _primitive(parent, node_name, decal_position, mesh,
		Vector3(size.x, 0.01, size.y), color, true, 0.0, 0.0, false)
	inst.rotation_degrees = Vector3(0, yaw_deg, 0)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


static func _primitive(parent: Node, node_name: String, prim_position: Vector3,
		mesh: PrimitiveMesh, size: Vector3, color: Color, transparent: bool,
		emission_energy: float, metallic: float,
		with_collision := true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = prim_position
	instance.mesh = mesh
	instance.material_override = _material(color, transparent, emission_energy,
		metallic)
	instance.visibility_range_end = PROP_VISIBILITY_RANGE
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if size.length() < 0.65:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

	# Same threshold as the map: trim, slats, casing and cables carry no
	# physics body. Only what the player can walk into gets a collider, and
	# no collider built by this file crosses DOOR_CLEAR_HALF.
	var collision_worthy := size.x >= 0.12 and size.y >= 0.08 and size.z >= 0.12
	if not transparent and with_collision and collision_worthy:
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


static func _material(color: Color, transparent: bool,
		emission_energy: float = 0.0,
		metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s:%s:%s:%s" % [color.to_html(true), transparent,
		emission_energy, metallic]
	if _materials.has(key):
		return _materials[key]

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

	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# The same restrained surface detail the walls carry, so a bracket bolted
	# to a wall does not look like a different material system.
	if not transparent and metallic < 0.35 and emission_energy <= 0.0:
		if _noise_texture == null:
			var noise := FastNoiseLite.new()
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
			noise.frequency = 0.16
			noise.fractal_octaves = 2
			_noise_texture = NoiseTexture2D.new()
			_noise_texture.width = 128
			_noise_texture.height = 128
			_noise_texture.noise = noise
			_noise_texture.seamless = true
		mat.roughness_texture = _noise_texture
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		if _bump_texture == null:
			var bump_noise := FastNoiseLite.new()
			bump_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
			bump_noise.frequency = 0.12
			bump_noise.fractal_octaves = 2
			_bump_texture = NoiseTexture2D.new()
			_bump_texture.width = 128
			_bump_texture.height = 128
			_bump_texture.noise = bump_noise
			_bump_texture.seamless = true
			_bump_texture.as_normal_map = true
			_bump_texture.bump_strength = 1.2
		mat.normal_enabled = true
		mat.normal_texture = _bump_texture
		mat.normal_scale = 0.08
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.22, 0.22, 0.22)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_materials[key] = mat
	return mat
