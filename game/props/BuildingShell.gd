class_name BuildingShell
extends RefCounted
## The museum as seen from OUTSIDE: massing, all four elevations, roofs, the
## atrium dome and the planetarium dome.
##
## WHY THIS FILE EXISTS
## FacadeProps builds a single street elevation at z = 35 -- eleven metres of
## portico, pediment and balustrade, and nothing behind it. Standing in the
## forecourt you saw a flat card with sky on both sides of it: no roof, no
## side walls, no back, no volume. This file wraps the actual room footprint in
## a building, so the museum reads as a solid mass from the forecourt, from the
## drive-in cutscene and from any camera that ever ends up outside.
##
## THE FOOTPRINT IT WRAPS (room centres and sizes from FirstMuseumMap.build_map)
##   Entrance Zone     (0, 25)   22 x 20   -> x [-11, 11],   z [15, 35]
##   Central Atrium    (0, 0)    30 x 30   -> x [-15, 15],   z [-15, 15]
##   Watcher Office    (-25, 0)  20 x 14   -> x [-35, -15],  z [-7, 7]
##   Equipment Storage (-25, 12) 20 x 10   -> x [-35, -15],  z [7, 17]
##   Archive           (-25,-12) 20 x 10   -> x [-35, -15],  z [-17, -7]
##   Restoration Lab   (-25, 22) 20 x 10   -> x [-35, -15],  z [17, 27]
##   Gravity Wing A    (28, 0)   26 x 18   -> x [15, 41],    z [-9, 9]
##   Mass Wing D       (52, 0)   22 x 16   -> x [41, 63],    z [-8, 8]
##   Time Wing B       (0, -24)  26 x 18   -> x [-13, 13],   z [-33, -15]
##   Space Wing C      (24, -24) 22 x 16   -> x [13, 35],    z [-32, -16]
##   Planetarium       (0, -41)  20 x 16   -> x [-10, 10],   z [-49, -33]
##
## THE ONE RULE THAT KEEPS THIS OUT OF THE ROOMS
## Interior walls are WALL_THICKNESS 0.35 centred on the room boundary, so a
## room's stone reaches 0.175 m past its nominal edge. Every mass here is the
## room rectangle grown by 1.0 m and its elevation slabs are WALL_T 0.70 thick
## turned INWARD, so the inner face of the new skin lands 0.30 m outside the
## boundary -- 0.125 m clear of the interior wall's outer face, and nowhere
## near the floor the player walks on.
##
## That rule is why elevations are built face by face instead of as a solid
## block. The first cut of this file used one box per plinth course, and those
## boxes filled the west range from the inside: map verification came back with
## "Shell West Range Plinth stands in the 0.90 m channel" over the Office <->
## Storage and Office <-> Archive doorways. Faces also let a mass drop an
## elevation where another mass already stands (`skips`) or open a hole in one
## where the portico or an adjoining wing does (`gaps`), which is what the
## atrium block needs on three of its four sides.
##
## NO COLLISION, ON PURPOSE
## Nothing here carries a collider and nothing joins the "museum_nav_source"
## group, so the navmesh the Curator bakes is untouched. The player cannot
## reach any of it: the forecourt is closed by the facade at z = 35 (which has
## its own colliders in FacadeProps) and by the lot walls at x +-31.5 and
## z 35.2. Colliders out here could only produce invisible walls in the one
## place the game lets you walk outdoors.
##
## HEIGHTS, AND WHY THE ROOF HAS TO SHOW
## FacadeProps puts its cornice at 6.60 and its pediment apex at 8.15. The
## entrance block carries its own cornice at exactly 6.60 so the two line up,
## an attic band to 7.39, and a hipped roof climbing to 10.5 -- the pediment
## stands IN FRONT of a roof visibly taller than it, which is what makes the
## front read as a building rather than as a billboard. The atrium block behind
## it goes higher again (cornice 9.0, balustrade over it) and carries the dome
## to 19.4, so the silhouette from the street is portico, then roof, then dome.

static var _materials := {}

# Palette kept in step with FacadeProps so the new stone matches the portico.
const MatLib := preload("res://game/props/MaterialLib.gd")

const COL_STONE := Color(0.75, 0.73, 0.70)
const COL_STONE_WARM := Color(0.71, 0.68, 0.63)
const COL_PLINTH := Color(0.55, 0.53, 0.50)
const COL_MOLDING := Color(0.82, 0.80, 0.77)
const COL_RECESS := Color(0.44, 0.43, 0.41)
const COL_GLASS := Color(0.05, 0.06, 0.08)
const COL_MUNTIN := Color(0.22, 0.20, 0.17)
const COL_ROOF := Color(0.26, 0.28, 0.30)
const COL_ROOF_RIDGE := Color(0.20, 0.22, 0.24)
const COL_COPPER := Color(0.29, 0.44, 0.39)
const COL_BRONZE := Color(0.35, 0.30, 0.20)
const COL_LEAD := Color(0.38, 0.39, 0.40)

const WALL_T := 0.70        # elevation slab thickness, turned inward
const PLINTH_TOP := 0.95
const STRING_Y := 4.35      # band dividing the storeys
const OVERHANG := 0.45      # roof overhang past the wall face

# Face keys used by the `skips` dictionary.
const FACE_YAW := {"n": 0.0, "s": PI, "e": PI * 0.5, "w": -PI * 0.5}

## Every room in the plan as centre x, centre z, width, depth -- the same
## rectangles FirstMuseumMap.build_map lays out. The shell reads this list
## instead of trusting hand-written holes: a mass is the room grown by 1.0 m a
## side, so where two masses overlap (the entrance block is 32 m wide and the
## west range starts 15 m out) one of them WILL cross the other's rooms. The
## first cut of this file answered that with `skips` and `gaps` written by
## hand, and a scan of the built map found 163 pieces of elevation standing
## indoors: nine metres of the entrance block's west front inside the
## Restoration Lab, the whole south front of the Time range through the
## Planetarium, window sills and plinths in the Atrium and the Archive.
const ROOMS := [
	[0.0, 25.0, 22.0, 20.0],    # Entrance Zone
	[0.0, 0.0, 30.0, 30.0],     # Central Atrium
	[-25.0, 0.0, 20.0, 14.0],   # Watcher Office
	[-25.0, 12.0, 20.0, 10.0],  # Equipment Storage
	[-25.0, -12.0, 20.0, 10.0], # Archive
	[-25.0, 22.0, 20.0, 10.0],  # Restoration Lab
	[28.0, 0.0, 26.0, 18.0],    # Gravity Wing A
	[52.0, 0.0, 22.0, 16.0],    # Mass Wing D
	[0.0, -24.0, 26.0, 18.0],   # Time Wing B
	[24.0, -24.0, 22.0, 16.0],  # Space Wing C
	[0.0, -41.0, 20.0, 16.0],   # Planetarium
]

## Half an interior wall: a room's own stone reaches this far past its nominal
## edge, so anything closer than this is inside that room's fabric.
const ROOM_CLEAR := 0.175

## Where an elevation stops caring about the rooms. Ceiling slabs sit at 3.45
## and no interior prop goes above 3.39, so everything from here up is free to
## run the full length of a mass -- which is what closes the daylight gap that
## was showing between the entrance-block roof and the atrium block.
const SPLIT_Y := 3.70


# =============================================================================
#  Entry point
# =============================================================================

## Builds the whole exterior. Masses are placed in world coordinates; they
## overlap each other freely, because a seam buried inside stone is invisible
## and a gap between two masses is not.
static func build_museum_shell(parent: Node3D, origin := Vector3.ZERO) -> Node3D:
	var root := _root(parent, "Museum Shell", origin)

	# --- entrance block, 32 m wide so the 22 m portico sits centred on it ---
	# North elevation keeps a 22.4 m hole: that span IS the FacadeProps portico
	# wall. South is dropped where the atrium block takes over.
	build_range(root, "Shell Entrance Block", Vector3(0.0, 0.0, 25.7),
		Vector2(32.0, 19.6), 6.60, 3.10, {"s": true}, {"n": 22.4}, 0, false)

	# --- central atrium block: the tall heart of the plan, dome on top ------
	# North is dropped (entrance block covers it). South opens 27 m for the
	# Time range and east opens 20 m for the Gravity range -- without those
	# holes the skin would land inside those two rooms. West is dropped for the
	# west range, which runs past this block on both sides.
	build_range(root, "Shell Atrium Block", Vector3(0.0, 0.0, 0.0),
		Vector2(32.0, 32.0), 9.00, 0.0, {"n": true, "w": true},
		{"s": 27.0, "e": 20.0}, 0, true)
	build_dome(root, Vector3(0.0, 9.90, 0.0), 6.60, 3.10, 4.30, true)

	# --- west range: office, storage, archive, restoration lab --------------
	build_range(root, "Shell West Range", Vector3(-25.0, 0.0, 5.0),
		Vector2(22.0, 46.0), 5.80, 2.60, {"e": true}, {}, 5, false)

	# --- east ranges: gravity wing, then the mass wing beyond it ------------
	build_range(root, "Shell Gravity Range", Vector3(28.0, 0.0, 0.0),
		Vector2(28.0, 20.0), 6.20, 2.70, {"w": true}, {"e": 18.0}, 4, false)
	build_range(root, "Shell Mass Range", Vector3(52.0, 0.0, 0.0),
		Vector2(24.0, 18.0), 5.60, 2.40, {"w": true}, {}, 3, false)

	# --- south ranges: time wing, space wing, planetarium -------------------
	# Time and Space share a party wall at x = 13, so neither can own an
	# elevation there: Time drops its east face and Space (west edge x 13)
	# covers the seam.
	build_range(root, "Shell Time Range", Vector3(0.0, 0.0, -25.1),
		Vector2(28.0, 17.8), 6.20, 2.70, {"n": true, "e": true}, {}, 4, false)
	build_range(root, "Shell Space Range", Vector3(24.5, 0.0, -24.5),
		Vector2(23.0, 19.0), 5.60, 2.40, {"w": true}, {}, 3, false)
	build_range(root, "Shell Planetarium Base", Vector3(0.0, 0.0, -41.5),
		Vector2(22.0, 17.0), 5.40, 0.0, {"n": true}, {}, 0, false)
	# A planetarium gets the one dome in the plan that is honestly functional.
	build_dome(root, Vector3(0.0, 6.35, -41.5), 6.80, 1.60, 4.90, false)

	# --- service back door, so the plan is not all front --------------------
	build_service_entrance(root, Vector3(-25.0, 0.0, 28.0))
	return root


# =============================================================================
#  One rectangular mass
# =============================================================================

## `footprint` is width (x) by depth (z), already grown 1.0 m past the rooms.
## `eave_y` is the top of the cornice. `ridge_extra` is how far the roof ridge
## rises above the eave; 0.0 gives a flat lead roof behind the parapet.
## `skips` no longer drops an elevation -- every mass now carries all four --
## it only marks the sides that are buried in a neighbouring mass, so no
## quoins, urns, gutters or dormers are wasted there. Where the ground storey
## may stand is computed from ROOMS, not declared.
static func build_range(parent: Node3D, node_name: String, centre: Vector3,
		footprint: Vector2, eave_y: float, ridge_extra := 2.4,
		skips := {}, _gaps := {}, dormers := 0,
		balustrade := false) -> Node3D:
	var root := _root(parent, node_name, centre)
	var hw: float = footprint.x * 0.5
	var hd: float = footprint.y * 0.5

	for key: String in ["n", "s", "e", "w"]:
		var along: float = footprint.x if key == "n" or key == "s" else footprint.y
		var plane: float = hd if key == "n" or key == "s" else hw
		var spans := _free_spans(along, _blocked_spans(key, centre, hw, hd))
		_build_face(root, "%s %s" % [node_name, key.to_upper()], along, plane,
			eave_y, float(FACE_YAW[key]), balustrade, spans)

	# --- quoined corners ----------------------------------------------------
	# Alternating long and short blocks up every arris, but only where both
	# adjoining elevations actually exist -- a quoin on a dropped face would be
	# a stone spur floating inside the neighbouring mass.
	for sx: float in [-1.0, 1.0]:
		var key_x: String = "e" if sx > 0.0 else "w"
		for sz: float in [-1.0, 1.0]:
			var key_z: String = "n" if sz > 0.0 else "s"
			if bool(skips.get(key_x, false)) or bool(skips.get(key_z, false)):
				continue
			# A quoin is over a metre of stone hugging the arris. At a corner a
			# room reaches, it would surface inside that room.
			if _point_in_room(centre.x + sx * (hw - 0.58),
					centre.z + sz * (hd - 0.58)):
				continue
			var course := 0
			var qy: float = PLINTH_TOP + 0.24
			while qy < eave_y - 0.90:
				var long_course: bool = course % 2 == 0
				var qw: float = 1.15 if long_course else 0.75
				var qd: float = 0.75 if long_course else 1.15
				_box(root, "%s Quoin %d%d %d" % [node_name, int(sx), int(sz), course],
					Vector3(sx * (hw - qw * 0.5 + 0.09), qy,
						sz * (hd - qd * 0.5 + 0.09)),
					Vector3(qw, 0.46, qd), COL_MOLDING)
				qy += 0.52
				course += 1

	# --- roof ---------------------------------------------------------------
	# Roof geometry starts above the attic, which is above every ceiling in the
	# building (WALL_HEIGHT 3.4), so unlike the walls it can span the whole
	# footprint without reaching into a room.
	var roof_base: float = eave_y + (0.24 if balustrade else 0.86)
	if ridge_extra > 0.01:
		_hip_roof(root, node_name, footprint, roof_base, ridge_extra, dormers,
			skips)
	else:
		_box(root, "%s Flat Roof" % node_name, Vector3(0.0, roof_base + 0.12, 0.0),
			Vector3(footprint.x - 0.60, 0.24, footprint.y - 0.60), COL_LEAD)
		# Lead rolls across the flat, so it is not one blank grey rectangle.
		var rolls: int = int(footprint.x / 2.6)
		for i in rolls:
			_box(root, "%s Lead Roll %d" % [node_name, i],
				Vector3(-footprint.x * 0.5 + 1.3 + float(i) * 2.6,
					roof_base + 0.28, 0.0),
				Vector3(0.16, 0.12, footprint.y - 0.90), COL_ROOF_RIDGE)
	if balustrade:
		_balustrade(root, node_name, hw + 0.30, hd + 0.30, eave_y + 0.14)
	else:
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				if bool(skips.get("e" if sx > 0.0 else "w", false)):
					continue
				if bool(skips.get("n" if sz > 0.0 else "s", false)):
					continue
				_urn(root, "%s Urn %d%d" % [node_name, int(sx), int(sz)],
					Vector3(sx * (hw - 0.35), eave_y + 0.86, sz * (hd - 0.35)))
	return root


# =============================================================================
#  One elevation
# =============================================================================

## Builds a single face inside a yawed node, so all the geometry below is
## authored once for a +z-facing wall. `plane` is the distance from the mass
## centre out to the face. `lower_spans` are the stretches of the ground
## storey that are clear of every room, as [centre_u, length] pairs.
##
## TWO STOREYS, TWO DIFFERENT RULES
## Below SPLIT_Y the face only exists on those spans. That is what keeps
## plinths, rustication and window sills out of rooms belonging to a
## neighbouring mass.
## Above SPLIT_Y the face is always continuous for its whole length, because
## nothing indoors reaches that high and every hole up there is a hole in the
## silhouette. The void you could see from the forecourt between the entrance
## block's roof and the atrium's was exactly this: the atrium's north wall had
## been dropped whole, and its top 1.5 m stood above the roof in front of it
## with nothing in it.
static func _build_face(parent: Node3D, tag: String, length: float,
		plane: float, eave_y: float, yaw: float, balustrade: bool,
		lower_spans: Array) -> void:
	var face := Node3D.new()
	face.name = "Elevation %s" % tag
	face.rotation.y = yaw
	parent.add_child(face)

	# On a low mass the split would leave no upper storey worth the name, so it
	# gives way rather than the cornice.
	var split: float = minf(SPLIT_Y, eave_y - 1.60)

	# --- ground storey, only where no room stands behind it -----------------
	var lower_h: float = split - PLINTH_TOP
	var lower_mid: float = PLINTH_TOP + lower_h * 0.5
	for s in lower_spans:
		var u: float = s[0]
		var seg_len: float = s[1]

		# Structural slab, turned inward off the face plane.
		_box(face, "%s Wall %.1f" % [tag, u],
			Vector3(u, lower_mid, plane - WALL_T * 0.5),
			Vector3(seg_len, lower_h, WALL_T), COL_STONE)

		# Courses. Each band is a box whose outer skin passes the face plane by
		# `out` and which reaches 0.40 m back into the mass.
		_band(face, "%s Base Course" % tag, u, seg_len, plane, 0.22, 0.44,
			0.35, COL_PLINTH)
		_band(face, "%s Plinth" % tag, u, seg_len, plane, 0.70, 0.52,
			0.20, COL_PLINTH)
		_band(face, "%s Plinth Cap" % tag, u, seg_len, plane, 1.00, 0.12,
			0.26, COL_MOLDING)

		# A stopped run gets a reveal on its cut end, so it reads as a corner
		# and not as a slab someone sawed through.
		for side: float in [-1.0, 1.0]:
			var edge: float = u + side * seg_len * 0.5
			if absf(edge) > length * 0.5 - 0.06:
				continue
			_box(face, "%s Reveal %.1f %d" % [tag, u, int(side)],
				Vector3(edge, lower_mid, plane - WALL_T * 0.5),
				Vector3(0.22, lower_h, WALL_T + 0.06), COL_MOLDING)

		_dress_lower(face, "%s %.1f" % [tag, u], u, seg_len, plane, split)

	# --- upper storey and entablature: one unbroken run ---------------------
	# Bands are stretched 0.70 m past the face so they wrap the corners.
	var wrap: float = 0.70
	_box(face, "%s Upper Wall" % tag,
		Vector3(0.0, (split + eave_y) * 0.5, plane - WALL_T * 0.5),
		Vector3(length, eave_y - split, WALL_T), COL_STONE)
	_band(face, "%s Architrave" % tag, 0.0, length + wrap, plane,
		eave_y - 0.62, 0.26, 0.11, COL_MOLDING)
	_band(face, "%s Frieze" % tag, 0.0, length + wrap, plane, eave_y - 0.36,
		0.30, 0.07, COL_STONE_WARM)
	_band(face, "%s Cornice Lower" % tag, 0.0, length + wrap, plane,
		eave_y - 0.14, 0.22, 0.31, COL_MOLDING)
	_band(face, "%s Cornice Upper" % tag, 0.0, length + wrap, plane,
		eave_y + 0.05, 0.18, 0.43, COL_MOLDING)
	if not balustrade:
		_band(face, "%s Attic" % tag, 0.0, length + wrap, plane, eave_y + 0.44,
			0.60, 0.15, COL_STONE_WARM)
		_band(face, "%s Attic Cap" % tag, 0.0, length + wrap, plane,
			eave_y + 0.79, 0.14, 0.24, COL_MOLDING)

	# Dentils under the cornice.
	var dentils: int = int(length / 0.62)
	for i in dentils:
		var dx: float = -length * 0.5 + 0.31 + float(i) * 0.62
		_box(face, "%s Dentil %d" % [tag, i],
			Vector3(dx, eave_y - 0.30, plane + 0.20),
			Vector3(0.30, 0.20, 0.22), COL_MOLDING)

	_dress_upper(face, tag, length, plane, eave_y, split)


# =============================================================================
#  Where an elevation is allowed to stand
# =============================================================================

## The stretches of one elevation that must NOT be built, because a room sits
## in the depth the wall would occupy. Returned in that face's own local u.
##
## The depth tested is the wall slab itself (WALL_T inward) plus 0.62 m of
## mouldings outward -- the sills and sandriks reach furthest, and they were
## among the pieces the scan found indoors.
static func _blocked_spans(key: String, centre: Vector3, hw: float,
		hd: float) -> Array:
	var along_x: bool = key == "n" or key == "s"
	var dir: float = 1.0 if key == "n" or key == "e" else -1.0
	var plane_w: float = (centre.z + dir * hd) if along_x else (centre.x + dir * hw)
	var edge_a: float = plane_w - dir * WALL_T
	var edge_b: float = plane_w + dir * 0.62
	var band_lo: float = minf(edge_a, edge_b)
	var band_hi: float = maxf(edge_a, edge_b)

	var out: Array = []
	for room in ROOMS:
		var rx0: float = float(room[0]) - float(room[2]) * 0.5 - ROOM_CLEAR
		var rx1: float = float(room[0]) + float(room[2]) * 0.5 + ROOM_CLEAR
		var rz0: float = float(room[1]) - float(room[3]) * 0.5 - ROOM_CLEAR
		var rz1: float = float(room[1]) + float(room[3]) * 0.5 + ROOM_CLEAR
		if along_x:
			if rz1 <= band_lo or rz0 >= band_hi:
				continue
			out.append(_local_span(key, rx0 - centre.x, rx1 - centre.x))
		else:
			if rx1 <= band_lo or rx0 >= band_hi:
				continue
			out.append(_local_span(key, rz0 - centre.z, rz1 - centre.z))
	return out


## A world-axis interval turned into a face's local u. The "s" and "e" faces
## are yawed so their local +x runs against the world axis, which mirrors the
## interval.
static func _local_span(key: String, a: float, b: float) -> Array:
	if key == "s" or key == "e":
		return [-b, -a]
	return [a, b]


## What is left of a face once the blocked intervals are cut out of it.
## Slivers under 0.80 m are dropped: a stub of plinth between two rooms reads
## as debris, not as a building.
static func _free_spans(length: float, blocked: Array) -> Array:
	var spans: Array = [[-length * 0.5, length * 0.5]]
	for b in blocked:
		var b0: float = float(b[0])
		var b1: float = float(b[1])
		var next: Array = []
		for s in spans:
			var s0: float = float(s[0])
			var s1: float = float(s[1])
			if b1 <= s0 or b0 >= s1:
				next.append(s)
				continue
			if b0 > s0:
				next.append([s0, b0])
			if b1 < s1:
				next.append([b1, s1])
		spans = next

	var out: Array = []
	for s in spans:
		var span_len: float = float(s[1]) - float(s[0])
		if span_len >= 0.80:
			out.append([(float(s[0]) + float(s[1])) * 0.5, span_len])
	return out


## True when a point in plan falls inside any room's fabric.
static func _point_in_room(x: float, z: float) -> bool:
	for room in ROOMS:
		if absf(x - float(room[0])) <= float(room[2]) * 0.5 + ROOM_CLEAR \
				and absf(z - float(room[1])) <= float(room[3]) * 0.5 + ROOM_CLEAR:
			return true
	return false


## Rustication and the ground tier of windows on ONE clear stretch of a face.
## Everything here lives below SPLIT_Y, so it is only ever placed on a span
## that has no room behind it.
static func _dress_lower(face: Node3D, tag: String, u: float, length: float,
		plane: float, top_y: float) -> void:
	if length < 2.2:
		return

	# Rusticated ground storey: horizontal joints every 0.55 m.
	var bands: int = int((top_y - PLINTH_TOP) / 0.55)
	for i in bands:
		_box(face, "%s Rustication %d" % [tag, i],
			Vector3(u, PLINTH_TOP + 0.28 + float(i) * 0.55, plane + 0.05),
			Vector3(length - 0.60, 0.46, 0.10), COL_STONE_WARM)

	# A window needs a bay to sit in; a 2 m stub of wall gets none.
	if length < 3.6:
		return
	var bays: int = maxi(1, int(round((length - 2.4) / 4.2)))
	var usable: float = length - 2.6
	var step: float = usable / float(bays)
	var head: float = minf(3.30, top_y - 0.40)
	var win_h: float = minf(1.95, head - 1.35)
	if win_h < 1.20:
		return
	for i in bays:
		var wx: float = u - usable * 0.5 + step * (float(i) + 0.5)
		_window(face, "%s Win G%d" % [tag, i],
			Vector3(wx, head - win_h * 0.5, plane), 1.45, win_h, false)


## String course, pilasters and the upper tier of windows. This one runs the
## whole face, because everything it places sits above SPLIT_Y and therefore
## above every ceiling in the building.
static func _dress_upper(face: Node3D, tag: String, length: float,
		plane: float, eave_y: float, bottom_y: float) -> void:
	if length < 2.6:
		return

	var string_y: float = maxf(STRING_Y, bottom_y + 0.32)
	_box(face, "%s String Course" % tag, Vector3(0.0, string_y, plane + 0.10),
		Vector3(length - 0.10, 0.26, 0.20), COL_MOLDING)

	# One bay roughly every 4.2 m, never fewer than two.
	var bays: int = maxi(2, int(round((length - 2.4) / 4.2)))
	var usable: float = length - 2.6
	var step: float = usable / float(bays)
	var sill_y: float = string_y + 0.35
	var upper_h: float = eave_y - sill_y - 0.75
	var win_h: float = minf(upper_h, 2.40)
	for i in bays:
		var wx: float = -usable * 0.5 + step * (float(i) + 0.5)
		if upper_h > 1.10:
			# A sandrik needs head room between the window and the architrave;
			# on a low storey it would collide with it.
			_window(face, "%s Win U%d" % [tag, i],
				Vector3(wx, sill_y + win_h * 0.5, plane), 1.45, win_h,
				upper_h > 1.95)
		if i > 0:
			var px: float = -usable * 0.5 + step * float(i)
			_box(face, "%s Pilaster %d" % [tag, i],
				Vector3(px, (bottom_y + eave_y) * 0.5, plane + 0.11),
				Vector3(0.62, eave_y - bottom_y - 0.30, 0.22), COL_STONE_WARM)
			_box(face, "%s Pilaster Cap %d" % [tag, i],
				Vector3(px, eave_y - 0.80, plane + 0.14),
				Vector3(0.80, 0.18, 0.28), COL_MOLDING)
			_box(face, "%s Pilaster Base %d" % [tag, i],
				Vector3(px, bottom_y + 0.02, plane + 0.14),
				Vector3(0.80, 0.20, 0.28), COL_MOLDING)


## One window: reveal, glass, muntins, sill, apron, and optionally a sandrik.
## The glass sits 0.10 m behind the wall face so the opening reads as a hole
## with depth rather than as a sticker.
static func _window(parent: Node3D, tag: String, at: Vector3, w: float,
		h: float, sandrik: bool) -> void:
	_box(parent, "%s Reveal" % tag, Vector3(at.x, at.y, at.z + 0.01),
		Vector3(w + 0.34, h + 0.34, 0.14), COL_RECESS)
	_box(parent, "%s Glass" % tag, Vector3(at.x, at.y, at.z - 0.10),
		Vector3(w, h, 0.06), COL_GLASS, 0.06)
	_box(parent, "%s Muntin V" % tag, Vector3(at.x, at.y, at.z - 0.05),
		Vector3(0.05, h, 0.04), COL_MUNTIN)
	for i in 2:
		_box(parent, "%s Muntin H%d" % [tag, i],
			Vector3(at.x, at.y - h * 0.5 + h * (0.34 + 0.33 * float(i)),
				at.z - 0.05), Vector3(w, 0.05, 0.04), COL_MUNTIN)
	_box(parent, "%s Frame" % tag, Vector3(at.x, at.y, at.z + 0.06),
		Vector3(w + 0.16, h + 0.16, 0.06), COL_MOLDING)
	_box(parent, "%s Sill" % tag,
		Vector3(at.x, at.y - h * 0.5 - 0.14, at.z + 0.14),
		Vector3(w + 0.52, 0.16, 0.30), COL_MOLDING)
	_box(parent, "%s Apron" % tag,
		Vector3(at.x, at.y - h * 0.5 - 0.42, at.z + 0.07),
		Vector3(w * 0.72, 0.34, 0.10), COL_STONE_WARM)
	if sandrik:
		_box(parent, "%s Sandrik Shelf" % tag,
			Vector3(at.x, at.y + h * 0.5 + 0.20, at.z + 0.16),
			Vector3(w + 0.62, 0.14, 0.34), COL_MOLDING)
		_prism(parent, "%s Sandrik" % tag,
			Vector3(at.x, at.y + h * 0.5 + 0.44, at.z + 0.16),
			Vector3(w + 0.56, 0.34, 0.30), COL_MOLDING)
		for sx: float in [-1.0, 1.0]:
			_box(parent, "%s Console %d" % [tag, int(sx)],
				Vector3(at.x + sx * (w * 0.5 + 0.12), at.y + h * 0.5 - 0.06,
					at.z + 0.13), Vector3(0.14, 0.36, 0.26), COL_MOLDING)


## A horizontal course on one face segment. `out` is how far its outer skin
## passes the face plane; the band always reaches 0.40 m back into the mass so
## it cannot float free of the wall behind it.
static func _band(face: Node3D, tag: String, u: float, length: float,
		plane: float, y: float, height: float, out: float,
		color: Color) -> void:
	var depth: float = out + 0.40
	_box(face, tag + " %.1f" % u,
		Vector3(u, y, plane + out - depth * 0.5),
		Vector3(length, height, depth), color)


# =============================================================================
#  Roofs
# =============================================================================

## Hipped roof: four sloped slabs meeting at a ridge, lead ridge cap, gutters
## and downpipes on the elevations that exist, and dormers on the +z slope.
##
## The slab maths, once, so the four faces are not four different bugs: a slab
## runs from the ridge down to the eave, so its length along the slope is
## sqrt(run^2 + rise^2). Rotating by t about +x sends local +z to
## (0, -sin t, cos t), so t = atan2(rise, run) lays local +z straight down the
## +z slope; the -z slope is the same angle mirrored to PI - t, and the x
## slopes use that pair about the z axis with the sign flipped.
static func _hip_roof(parent: Node3D, node_name: String, footprint: Vector2,
		eave_y: float, rise: float, dormers: int, skips: Dictionary) -> void:
	var hw: float = footprint.x * 0.5 + OVERHANG
	var hd: float = footprint.y * 0.5 + OVERHANG
	var ridge_y: float = eave_y + rise
	var t_z: float = atan2(rise, hd)
	var len_z: float = sqrt(hd * hd + rise * rise)
	var t_x: float = atan2(rise, hw)
	var len_x: float = sqrt(hw * hw + rise * rise)
	var mid_y: float = (eave_y + ridge_y) * 0.5

	var north := _box(parent, "%s Roof North" % node_name,
		Vector3(0.0, mid_y, hd * 0.5), Vector3(hw * 2.0, 0.20, len_z), COL_ROOF)
	north.rotation.x = t_z
	var south := _box(parent, "%s Roof South" % node_name,
		Vector3(0.0, mid_y, -hd * 0.5), Vector3(hw * 2.0, 0.20, len_z), COL_ROOF)
	south.rotation.x = PI - t_z
	var east := _box(parent, "%s Roof East" % node_name,
		Vector3(hw * 0.5, mid_y, 0.0), Vector3(len_x, 0.20, hd * 2.0), COL_ROOF)
	east.rotation.z = -t_x
	var west := _box(parent, "%s Roof West" % node_name,
		Vector3(-hw * 0.5, mid_y, 0.0), Vector3(len_x, 0.20, hd * 2.0), COL_ROOF)
	west.rotation.z = t_x - PI

	var ridge_len: float = maxf(absf(hw - hd) * 2.0, 0.9)
	if footprint.x >= footprint.y:
		_box(parent, "%s Ridge" % node_name, Vector3(0.0, ridge_y + 0.06, 0.0),
			Vector3(ridge_len, 0.22, 0.46), COL_ROOF_RIDGE)
	else:
		_box(parent, "%s Ridge" % node_name, Vector3(0.0, ridge_y + 0.06, 0.0),
			Vector3(0.46, 0.22, ridge_len), COL_ROOF_RIDGE)

	# Gutters follow the eaves of the elevations that were actually built.
	for sz: float in [-1.0, 1.0]:
		if bool(skips.get("n" if sz > 0.0 else "s", false)):
			continue
		_box(parent, "%s Gutter %d" % [node_name, int(sz)],
			Vector3(0.0, eave_y - 0.06, sz * hd), Vector3(hw * 2.0, 0.18, 0.26),
			COL_LEAD)
	for sx: float in [-1.0, 1.0]:
		if bool(skips.get("e" if sx > 0.0 else "w", false)):
			continue
		for sz: float in [-1.0, 1.0]:
			if bool(skips.get("n" if sz > 0.0 else "s", false)):
				continue
			# Outside the wall face, not inside the mass. At hw - 0.75 every
			# downpipe in the building was buried in its own elevation, and at
			# a corner a room reaches it would have come out indoors -- so the
			# corner is tested before the pipe is hung.
			var px: float = sx * (footprint.x * 0.5 + 0.13)
			var pz: float = sz * (footprint.y * 0.5 - 0.55)
			if _point_in_room(parent.position.x + px, parent.position.z + pz):
				continue
			_cyl(parent, "%s Downpipe %d%d" % [node_name, int(sx), int(sz)],
				Vector3(px, PLINTH_TOP + (eave_y - PLINTH_TOP) * 0.5, pz),
				0.11, eave_y - PLINTH_TOP, COL_LEAD, 8, 0.35)

	if dormers <= 0 or bool(skips.get("n", false)):
		return
	var span: float = footprint.x - 4.0
	for i in dormers:
		var dx: float = -span * 0.5 + span * (float(i) + 0.5) / float(dormers)
		var dz: float = hd * 0.52
		var dy: float = eave_y + rise * (1.0 - dz / hd) * 0.55 + 0.55
		_box(parent, "%s Dormer Cheek %d" % [node_name, i],
			Vector3(dx, dy, dz), Vector3(1.30, 1.10, 1.10), COL_STONE_WARM)
		_box(parent, "%s Dormer Glass %d" % [node_name, i],
			Vector3(dx, dy + 0.02, dz + 0.56), Vector3(0.86, 0.78, 0.06),
			COL_GLASS, 0.05)
		_box(parent, "%s Dormer Frame %d" % [node_name, i],
			Vector3(dx, dy + 0.02, dz + 0.60), Vector3(1.00, 0.92, 0.05),
			COL_MOLDING)
		_prism(parent, "%s Dormer Hood %d" % [node_name, i],
			Vector3(dx, dy + 0.78, dz + 0.10), Vector3(1.54, 0.52, 1.40),
			COL_ROOF_RIDGE)


# =============================================================================
#  Domes
# =============================================================================

## Podium, drum with an engaged colonnade, ribbed hemisphere, lantern, finial.
static func build_dome(parent: Node3D, base: Vector3, radius: float,
		drum_h: float, dome_h: float, ribbed := true) -> Node3D:
	var root := _root(parent, "Dome %.0f %.0f" % [base.x, base.z], base)

	_box(root, "Dome Podium", Vector3(0.0, 0.30, 0.0),
		Vector3(radius * 2.30, 0.60, radius * 2.30), COL_STONE_WARM)
	_box(root, "Dome Podium Cap", Vector3(0.0, 0.66, 0.0),
		Vector3(radius * 2.44, 0.16, radius * 2.44), COL_MOLDING)

	_cyl(root, "Dome Drum", Vector3(0.0, 0.74 + drum_h * 0.5, 0.0), radius,
		drum_h, COL_STONE, 24)
	var columns := 12
	for i in columns:
		var a: float = TAU * float(i) / float(columns)
		_cyl(root, "Drum Column %d" % i,
			Vector3(cos(a) * (radius + 0.16), 0.86 + drum_h * 0.5,
				sin(a) * (radius + 0.16)), 0.26, drum_h - 0.30, COL_MOLDING, 10)
		if i % 2 == 0:
			var b: float = a + TAU / float(columns) * 0.5
			var win := _box(root, "Drum Window %d" % i,
				Vector3(cos(b) * (radius + 0.02), 0.90 + drum_h * 0.5,
					sin(b) * (radius + 0.02)),
				Vector3(0.92, drum_h * 0.62, 0.14), COL_GLASS, 0.10)
			win.rotation.y = -b
	var cornice_y: float = 0.74 + drum_h
	_cyl(root, "Drum Cornice", Vector3(0.0, cornice_y + 0.12, 0.0),
		radius + 0.48, 0.24, COL_MOLDING, 24)

	# SphereMesh authors a full sphere, so the hemisphere flag is what keeps
	# the bottom half from hanging into the drum.
	var shell := SphereMesh.new()
	shell.radius = radius * 0.98
	shell.height = dome_h * 2.0
	shell.is_hemisphere = true
	shell.radial_segments = 24
	shell.rings = 12
	_attach(root, "Dome Shell", Vector3(0.0, cornice_y + 0.20, 0.0), shell,
		Vector3(radius * 2.0, dome_h, radius * 2.0), COL_COPPER, 0.0, 0.25)

	if ribbed:
		for i in 12:
			var a: float = TAU * float(i) / 12.0
			var prev := Vector3(cos(a) * radius * 0.97, cornice_y + 0.22,
				sin(a) * radius * 0.97)
			for s in range(1, 5):
				var ang: float = float(s) / 4.0 * PI * 0.5
				var next := Vector3(cos(a) * radius * 0.97 * cos(ang),
					cornice_y + 0.22 + dome_h * sin(ang),
					sin(a) * radius * 0.97 * cos(ang))
				_beam(root, "Dome Rib %d-%d" % [i, s], prev, next, 0.09,
					COL_MOLDING)
				prev = next

	var lantern_y: float = cornice_y + 0.20 + dome_h
	_cyl(root, "Lantern Base", Vector3(0.0, lantern_y + 0.18, 0.0),
		radius * 0.30, 0.36, COL_MOLDING, 16)
	_cyl(root, "Lantern Drum", Vector3(0.0, lantern_y + 0.96, 0.0),
		radius * 0.24, 1.20, COL_STONE, 16)
	for i in 8:
		var a: float = TAU * float(i) / 8.0
		_cyl(root, "Lantern Post %d" % i,
			Vector3(cos(a) * radius * 0.25, lantern_y + 0.96,
				sin(a) * radius * 0.25), 0.09, 1.20, COL_MOLDING, 8)
	_cyl(root, "Lantern Cornice", Vector3(0.0, lantern_y + 1.66, 0.0),
		radius * 0.34, 0.18, COL_MOLDING, 16)
	_cone(root, "Lantern Cap", Vector3(0.0, lantern_y + 2.16, 0.0),
		radius * 0.28, 0.02, 0.86, COL_COPPER, 16)
	_sphere(root, "Finial Ball", Vector3(0.0, lantern_y + 2.74, 0.0), 0.26,
		COL_BRONZE)
	_cyl(root, "Finial Spike", Vector3(0.0, lantern_y + 3.22, 0.0), 0.05, 0.72,
		COL_BRONZE, 6, 0.7)
	return root


# =============================================================================
#  Small pieces
# =============================================================================

## Service entrance on the back of the west range: loading door, canopy, steps,
## bollards. A museum with only a ceremonial front is a stage set.
static func build_service_entrance(parent: Node3D, at: Vector3) -> Node3D:
	var root := _root(parent, "Service Entrance", at)
	_box(root, "Service Door Surround", Vector3(0.0, 1.75, 0.30),
		Vector3(3.60, 3.50, 0.36), COL_STONE_WARM)
	_box(root, "Service Door", Vector3(0.0, 1.55, 0.50),
		Vector3(2.90, 3.10, 0.14), COL_RECESS)
	for i in 6:
		_box(root, "Service Door Rib %d" % i,
			Vector3(0.0, 0.35 + float(i) * 0.50, 0.58),
			Vector3(2.80, 0.34, 0.04), COL_LEAD)
	_box(root, "Service Canopy", Vector3(0.0, 3.62, 1.05),
		Vector3(4.40, 0.18, 1.90), COL_LEAD)
	for sx: float in [-1.0, 1.0]:
		_beam(root, "Canopy Stay %d" % int(sx), Vector3(sx * 1.9, 4.35, 0.32),
			Vector3(sx * 1.9, 3.62, 1.85), 0.05, COL_LEAD)
		_cyl(root, "Bollard %d" % int(sx), Vector3(sx * 2.6, 0.45, 2.30), 0.16,
			0.90, COL_BRONZE, 10, 0.5)
	_box(root, "Loading Platform", Vector3(0.0, 0.14, 1.55),
		Vector3(4.20, 0.28, 2.40), COL_PLINTH)
	for i in 2:
		_box(root, "Loading Step %d" % i,
			Vector3(0.0, 0.07 - float(i) * 0.07, 2.90 + float(i) * 0.40),
			Vector3(3.40, 0.14, 0.40), COL_PLINTH)
	return root


## Stone balustrade round a flat roof.
static func _balustrade(parent: Node3D, tag: String, hw: float, hd: float,
		y: float) -> void:
	var spacing := 0.86
	for sz: float in [-1.0, 1.0]:
		_box(parent, "%s Balustrade Plinth N%d" % [tag, int(sz)],
			Vector3(0.0, y + 0.10, sz * hd),
			Vector3(hw * 2.0 + 0.30, 0.20, 0.52), COL_MOLDING)
		_box(parent, "%s Balustrade Rail N%d" % [tag, int(sz)],
			Vector3(0.0, y + 1.06, sz * hd),
			Vector3(hw * 2.0 + 0.30, 0.18, 0.46), COL_MOLDING)
		var n: int = int((hw * 2.0) / spacing)
		for i in n:
			_baluster(parent, "%s Bal N%d %d" % [tag, int(sz), i],
				Vector3(-hw + spacing * (float(i) + 0.5), y + 0.20, sz * hd))
	for sx: float in [-1.0, 1.0]:
		_box(parent, "%s Balustrade Plinth E%d" % [tag, int(sx)],
			Vector3(sx * hw, y + 0.10, 0.0),
			Vector3(0.52, 0.20, hd * 2.0 + 0.30), COL_MOLDING)
		_box(parent, "%s Balustrade Rail E%d" % [tag, int(sx)],
			Vector3(sx * hw, y + 1.06, 0.0),
			Vector3(0.46, 0.18, hd * 2.0 + 0.30), COL_MOLDING)
		var m: int = int((hd * 2.0) / spacing)
		for i in m:
			_baluster(parent, "%s Bal E%d %d" % [tag, int(sx), i],
				Vector3(sx * hw, y + 0.20, -hd + spacing * (float(i) + 0.5)))


static func _baluster(parent: Node3D, node_name: String, at: Vector3) -> void:
	_cone(parent, "%s A" % node_name, at + Vector3(0.0, 0.24, 0.0), 0.15, 0.09,
		0.48, COL_MOLDING, 8)
	_cone(parent, "%s B" % node_name, at + Vector3(0.0, 0.66, 0.0), 0.09, 0.14,
		0.36, COL_MOLDING, 8)


static func _urn(parent: Node3D, node_name: String, at: Vector3) -> void:
	_box(parent, "%s Pedestal" % node_name, at + Vector3(0.0, 0.22, 0.0),
		Vector3(0.62, 0.44, 0.62), COL_MOLDING)
	_cone(parent, "%s Bowl" % node_name, at + Vector3(0.0, 0.66, 0.0), 0.16,
		0.34, 0.52, COL_MOLDING, 10)
	_sphere(parent, "%s Lid" % node_name, at + Vector3(0.0, 0.98, 0.0), 0.20,
		COL_MOLDING)


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
		size: Vector3, color: Color, emission := 0.0,
		metallic := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _attach(parent, node_name, box_position, mesh, size, color, emission,
		metallic)


static func _cyl(parent: Node3D, node_name: String, cyl_position: Vector3,
		radius: float, height: float, color: Color, segments := 12,
		metallic := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.radial_segments = segments
	mesh.rings = 0
	return _attach(parent, node_name, cyl_position, mesh,
		Vector3(radius * 2.0, height, radius * 2.0), color, 0.0, metallic)


static func _cone(parent: Node3D, node_name: String, cone_position: Vector3,
		bottom_radius: float, top_radius: float, height: float, color: Color,
		segments := 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.radial_segments = segments
	mesh.rings = 0
	var widest: float = maxf(bottom_radius, top_radius)
	return _attach(parent, node_name, cone_position, mesh,
		Vector3(widest * 2.0, height, widest * 2.0), color, 0.0, 0.2)


static func _sphere(parent: Node3D, node_name: String, sphere_position: Vector3,
		radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 7
	return _attach(parent, node_name, sphere_position, mesh,
		Vector3(radius * 2.0, radius * 2.0, radius * 2.0), color, 0.0, 0.3)


static func _prism(parent: Node3D, node_name: String, prism_position: Vector3,
		size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _attach(parent, node_name, prism_position, mesh, size, color)


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
		Vector3(radius * 2.0, length, radius * 2.0), color, 0.0, 0.2)
	var dir := delta / length
	var axis := Vector3.UP.cross(dir)
	if axis.length_squared() > 0.000001:
		inst.rotate(axis.normalized(), Vector3.UP.angle_to(dir))
	elif dir.y < 0.0:
		inst.rotate(Vector3.RIGHT, PI)
	return inst


## No visibility_range_end here, unlike the interior prop libraries: this
## building has to still be there when the drive-in cutscene looks at it from a
## hundred metres away, and a faded-out museum would be worse than none.
static func _attach(parent: Node3D, node_name: String, prim_position: Vector3,
		mesh: PrimitiveMesh, size: Vector3, color: Color, emission := 0.0,
		metallic := 0.0) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.position = prim_position
	inst.mesh = mesh
	inst.material_override = _material(color, emission, metallic)
	if size.length() < 0.90:
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	return inst


## Цвет оболочки -> набор карт. Фасад — самая большая поверхность в кадре
## и единственная, которую видно всю катсцену приезда, поэтому голого цвета
## здесь не остаётся нигде, кроме стекла и светящихся деталей.
static func _pack_for(color: Color) -> String:
	if color.is_equal_approx(COL_STONE) or color.is_equal_approx(COL_STONE_WARM) \
			or color.is_equal_approx(COL_MOLDING):
		return "quartzite"
	if color.is_equal_approx(COL_PLINTH) or color.is_equal_approx(COL_RECESS):
		return "concrete"
	if color.is_equal_approx(COL_ROOF) or color.is_equal_approx(COL_ROOF_RIDGE) \
			or color.is_equal_approx(COL_LEAD):
		return "painted_metal"
	if color.is_equal_approx(COL_COPPER):
		return "corroded_metal"
	if color.is_equal_approx(COL_BRONZE) or color.is_equal_approx(COL_MUNTIN):
		return "painted_metal"
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
	mat.metallic_specular = 0.55
	mat.roughness = clampf(0.70 - metallic * 0.30, 0.16, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	_materials[key] = mat
	return mat
