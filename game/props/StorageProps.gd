@tool
class_name StorageProps
extends RefCounted
## Procedural props for Equipment Storage -- the room where the Observer has to
## FIND one of twelve containment devices while the clock runs.
##
## Design brief, in order of priority:
##   1. LEGIBILITY. The player is timed. Everything that identifies a location is
##      a stencilled number in reading order (top-left first), backed by an opaque
##      black outline so it survives the lights failing. Colour never carries
##      meaning on its own: an empty charging station is an empty recess plus a
##      raised amber tab plus a printed number; a missing tool is a flat painted
##      outline plus a bare peg hook. Strip all colour out and the room still
##      reads.
##   2. SILHOUETTE. Dark steel frames, deep black recesses, pale stencils. Detail
##      is spent on the shape of the negative space -- the slot with nothing in it
##      -- not on surface decoration.
##   3. BUDGET. The map already builds ~1270 MeshInstance3D nodes in one frame.
##      Every builder states its measured node cost and bounding box in its doc
##      comment, materials are shared through a static cache, cylinders are cut
##      to 10 radial segments (a default CylinderMesh is 64 segments and roughly
##      500 triangles), and each prop carries at most ONE StaticBody3D instead of
##      the map's per-mesh colliders.
##
##      MEASURED, per prop, fully dressed: shelving_bay 46 nodes / 348 tris;
##      charging_rack 62 / 696; hazard_cabinet 28 / 380; tool_board 48 / 840;
##      device_cradle 11 / 108; bay_sign 10 / 156; floor_bay_marker 9 / 84.
##      A full room -- 3 bays, 3 floor markers, 1 rack, 1 tool board, 2 cabinets,
##      2 signs and 12 cradles -- is 478 nodes and about 5,300 triangles, sharing
##      23 StandardMaterial3D instances. That is a 38 percent rise on the map's
##      current node count, so if the integrator needs headroom, drop to 2 bays
##      and 1 cabinet (-74 nodes) before touching anything else; the 12 cradles
##      are load-bearing for the puzzle and replace GameManager's 12 plain slot
##      plates (36 nodes) rather than adding to them.
##
## MOTION: there is none. Nothing here animates, pulses or flickers, so there is
## nothing for SettingsManager.reduced_flashes to switch off. Emissive surfaces
## are constant-intensity indicator paint, not light sources.
##
## PLACEMENT CONTRACT. Every builder takes (parent, origin, facing_deg, ...) and
## returns the root Node3D it added, so the map can place one in a single line.
## Props are modelled in local space with their BACK PLANE AT local z = 0, facing
## local +Z; `origin` is therefore the point where the prop meets the wall, at
## floor level. `facing_deg` rotates about Y: 0 faces +Z, 90 faces +X, 180 faces
## -Z, -90 faces -X.
##
## COLLISION. Doorways are DOOR_GAP = 1.8 m wide and the navmesh bake erodes
## 0.45 m per side, so anything solid parked in a doorway strands the Curator.
## Only shelving_bay(), charging_rack() and hazard_cabinet() add a collider, each
## a single box matching the real blocking volume. The tool board, the hanging
## sign, the floor marker and the device cradle add none -- they are wall trim,
## overhead geometry (2.38 m clearance, above the 2.2 m nav agent) or bench-top
## dressing.
##
## TEXT. Player-visible wording arrives as a String parameter; this file holds no
## user-facing literals and no translation keys of its own. Numbers are printed as
## digits, which need no catalogue row. Callers pass tr("KEY") for the wording.
## Each text slot has a width budget, stated on the function that owns it.

# --- Palette -----------------------------------------------------------------
# Industrial night-shift storeroom: near-black steel, one worn paint tone, three
# indicator tints. STENCIL against the opaque black outline measures 15.9:1.
const STEEL_DARK := Color(0.100, 0.110, 0.120)
const STEEL := Color(0.135, 0.145, 0.155)
const STEEL_PALE := Color(0.300, 0.310, 0.330)
const PAINT_DARK := Color(0.115, 0.130, 0.122)
const PAINT_WORN := Color(0.560, 0.545, 0.480)
const STENCIL := Color(0.880, 0.880, 0.840)
const SHADOW := Color(0.026, 0.028, 0.032)
const HAZARD := Color(0.760, 0.620, 0.090)
const SIGNAL_GREEN := Color(0.200, 0.780, 0.420)
const SIGNAL_AMBER := Color(0.950, 0.620, 0.180)
const SIGNAL_DEAD := Color(0.260, 0.090, 0.080)
const GRIME := Color(0.150, 0.105, 0.075)
const BRASS := Color(0.520, 0.460, 0.280)
const CRATE := Color(0.190, 0.180, 0.150)
const TOOL_STEEL := Color(0.240, 0.250, 0.270)
const PAINT_LINE := Color(0.720, 0.710, 0.660)
const FLOOR_PAINT := Color(0.620, 0.580, 0.300)

# Two metallic values, not eight. Painted frames and machined parts are the only
# distinction the eye makes at these sizes, and every extra value forks the
# material cache into another StandardMaterial3D for no visible gain.
const METAL_STEEL := 0.35
const METAL_BRIGHT := 0.55

# Matches FirstMuseumMap.WALL_HEIGHT. Duplicated rather than imported so this
# file keeps no cross-script dependency; the ceiling-hung builders take it as an
# overridable parameter.
const ROOM_HEIGHT := 3.4

# Beyond this is outside the room and its two doorways.
const CULL_DISTANCE := 45.0
const LABEL_CULL_DISTANCE := 26.0

# Label3D renders `font_size` pixels per em at `pixel_size` metres per pixel, and
# capitals occupy roughly 0.72 of the em box. One fixed font size keeps the glyph
# atlas shared across every stencil in the room. Average advance per character is
# close to 0.6 * cap height, which is where the width budgets below come from.
const STENCIL_FONT_SIZE := 64
const STENCIL_CAP_RATIO := 0.72

static var _materials: Dictionary = {}


# =============================================================================
# Public builders
# =============================================================================

## Steel shelving bay: numbered fascia, four decks, twelve numbered slots.
##
## Slots are numbered `first_slot` .. `first_slot` + 11 in READING ORDER -- top
## deck left to right first, then downwards -- so a player scanning from the
## doorway meets the low numbers where they expect them. `bay_label` is the
## wording beside the bay number on the fascia (pass tr("KEY"), or "" for none);
## budget roughly 38 characters. `stocked` lists the slot numbers that still hold
## a crate. Every other slot is deliberately, visibly empty, and the last crate in
## the list is left askew and pulled forward: someone was here, in a hurry.
##
## BOUNDING BOX (measured): 2.40 (X) x 2.40 (Y) x 0.65 (Z); local
## x in [-1.20, 1.20], y in [0, 2.40], z in [0.01, 0.66]. Clears the 3.40 m
## ceiling by 1.00 m.
## COLLISION: one box, 2.40 x 2.40 x 0.64 at local (0, 1.20, 0.32).
## NODES: 42 + 1 per stocked slot (46 with four crates).
static func shelving_bay(parent: Node3D, origin: Vector3, facing_deg: float,
		bay_number: int, first_slot := 1, bay_label := "",
		stocked := PackedInt32Array()) -> Node3D:
	var root := _root(parent, "Shelving Bay %02d" % bay_number, origin, facing_deg)

	var decks := [0.28, 0.84, 1.40, 1.96]  # index 0 is the bottom deck
	var slot_xs := [-0.80, 0.0, 0.80]

	# Frame: four uprights and an X-brace on the back plane. The brace is the
	# whole reason this reads as industrial from across the room.
	for sx: float in [-1.165, 1.165]:
		for sz: float in [0.055, 0.565]:
			_box(root, "Upright", Vector3(sx, 1.20, sz),
				Vector3(0.07, 2.40, 0.07), STEEL_DARK, 0.0, METAL_STEEL)
	for tilt: float in [-63.6, 63.6]:
		var brace := _box(root, "Back Brace", Vector3(0, 1.40, 0.035),
			Vector3(0.05, 2.522, 0.03), STEEL_DARK, 0.0, METAL_STEEL)
		brace.rotation_degrees = Vector3(0, 0, tilt)
	_box(root, "Kick Plate", Vector3(0, 0.10, 0.585),
		Vector3(2.40, 0.20, 0.04), STEEL_DARK, 0.0, METAL_STEEL)

	# Decks, their label lips, and the dividers that make a slot a slot.
	for d in range(decks.size()):
		var dy: float = decks[d]
		_box(root, "Deck %d" % (d + 1), Vector3(0, dy, 0.31),
			Vector3(2.40, 0.05, 0.60), STEEL, 0.0, METAL_STEEL)
		_box(root, "Deck Lip %d" % (d + 1), Vector3(0, dy - 0.02, 0.625),
			Vector3(2.40, 0.09, 0.03), PAINT_DARK)
		for bx: float in [-0.40, 0.40]:
			_box(root, "Slot Divider", Vector3(bx, dy + 0.105, 0.31),
				Vector3(0.02, 0.16, 0.56), STEEL_PALE, 0.0, METAL_BRIGHT)

	# Slot numbers on the lips, top deck first.
	for row in range(4):
		var dy: float = decks[3 - row]
		for col in range(3):
			var slot: int = first_slot + row * 3 + col
			_stencil(root, "Slot Number %02d" % slot,
				Vector3(slot_xs[col], dy - 0.02, 0.645), "%02d" % slot, 0.055)

	# Fascia: the one element a player reads from the doorway.
	_box(root, "Fascia", Vector3(0, 2.29, 0.615),
		Vector3(2.40, 0.22, 0.05), PAINT_DARK)
	_box(root, "Fascia Edge", Vector3(0, 2.385, 0.645),
		Vector3(2.40, 0.02, 0.04), PAINT_WORN)
	_stencil(root, "Bay Number", Vector3(-1.02, 2.29, 0.645),
		"%02d" % bay_number, 0.135)
	_stencil(root, "Bay Label", Vector3(0.15, 2.29, 0.645), bay_label, 0.085)

	var last_slot: int = stocked[stocked.size() - 1] if stocked.size() > 0 else -1
	for slot: int in stocked:
		var index: int = slot - first_slot
		if index < 0 or index > 11:
			continue
		var dy: float = decks[3 - (index / 3)]
		var cx: float = slot_xs[index % 3]
		var askew: bool = slot == last_slot
		var crate := _box(root, "Crate %02d" % slot,
			Vector3(cx, dy + 0.205, 0.36 if askew else 0.30),
			Vector3(0.60, 0.36, 0.44), CRATE)
		if askew:
			crate.rotation_degrees = Vector3(0, 7.0, 0)

	_solid(root, "Shelving Body", Vector3(0, 1.20, 0.32), Vector3(2.40, 2.40, 0.64))
	return root


## Wall charging rack: a grid of numbered stations, some of them empty.
##
## Stations are numbered `first_slot` .. `first_slot` + rows * columns - 1 in
## reading order (top row left to right). `charged` lists the stations that still
## hold a battery brick; every other station is a black recess with a raised amber
## vacancy tab, so full and empty differ in silhouette, in text and in colour
## rather than in colour alone. `header` is the wording on the strip above the
## grid (pass tr("KEY"), or "" for none); budget roughly 50 characters at six
## columns. Pass 0.0 for `riser_ceiling_y` to omit the conduit risers.
##
## BOUNDING BOX (measured, defaults 6 x 2): 2.66 (X) x 2.68 (Y) x 0.22 (Z),
## occupying y in [0.72, 3.40] -- nothing hangs below 0.72 m. The rack itself
## stops at y 2.41; only the two conduit risers reach the ceiling, and without
## them the box is 2.66 x 1.69 x 0.22. Width is columns * 0.42 + 0.14, grid
## height rows * 0.62 + 0.16.
## COLLISION: one box, width x grid height x 0.22 at local (0, 1.42, 0.11). It
## floats 0.72 m above the floor and protrudes 0.22 m, so it costs a strip of
## navmesh no wider than skirting board.
## NODES: 9 + 5 per charged station + 4 per empty station (62 at the defaults
## with five charged).
static func charging_rack(parent: Node3D, origin: Vector3, facing_deg: float,
		columns := 6, rows := 2, first_slot := 1,
		charged := PackedInt32Array(), header := "",
		riser_ceiling_y := ROOM_HEIGHT) -> Node3D:
	columns = maxi(1, columns)
	rows = maxi(1, rows)
	var root := _root(parent, "Charging Rack", origin, facing_deg)

	var pitch_x := 0.42
	var pitch_y := 0.62
	var width: float = float(columns) * pitch_x + 0.14
	var grid_height: float = float(rows) * pitch_y + 0.16
	var base_y := 0.72
	var plate_y: float = base_y + grid_height * 0.5

	_box(root, "Rack Backplate", Vector3(0, plate_y, 0.025),
		Vector3(width, grid_height, 0.05), STEEL_DARK, 0.0, METAL_STEEL)

	for r in range(rows):
		var y: float = base_y + grid_height - 0.08 - pitch_y * 0.5 - float(r) * pitch_y
		for c in range(columns):
			var x: float = -width * 0.5 + 0.07 + pitch_x * 0.5 + float(c) * pitch_x
			var slot: int = first_slot + r * columns + c
			# The recess is the prop; everything else hangs off it.
			_box(root, "Station Recess %02d" % slot, Vector3(x, y + 0.03, 0.06),
				Vector3(0.34, 0.42, 0.06), SHADOW)
			_box(root, "Station Shoe %02d" % slot, Vector3(x, y - 0.19, 0.11),
				Vector3(0.36, 0.03, 0.16), STEEL_PALE, 0.0, METAL_BRIGHT)
			_stencil(root, "Station Number %02d" % slot,
				Vector3(x, y - 0.26, 0.056), "%02d" % slot, 0.055)
			if _contains(charged, slot):
				_box(root, "Battery %02d" % slot, Vector3(x, y + 0.04, 0.145),
					Vector3(0.26, 0.30, 0.14), Color(0.160, 0.170, 0.190), 0.0, 0.4)
				_box(root, "Charge Pip %02d" % slot, Vector3(x, y + 0.21, 0.155),
					Vector3(0.06, 0.025, 0.02), SIGNAL_GREEN, 1.4)
			else:
				# The empty state gets its own silhouette, not just another hue.
				_box(root, "Vacancy Tab %02d" % slot,
					Vector3(x + 0.125, y + 0.03, 0.10),
					Vector3(0.06, 0.10, 0.014), SIGNAL_AMBER, 0.5)

	var header_y: float = base_y + grid_height + 0.08
	_box(root, "Rack Header", Vector3(0, header_y, 0.05),
		Vector3(width, 0.16, 0.03), PAINT_DARK)
	_stencil(root, "Rack Header Text", Vector3(0, header_y, 0.070), header, 0.085)

	var conduit_y: float = base_y + grid_height + 0.26
	var conduit := _cylinder(root, "Rack Conduit", Vector3(0, conduit_y, 0.06),
		0.035, maxf(0.2, width - 0.30), STEEL_PALE, 0.0, METAL_BRIGHT)
	conduit.rotation_degrees = Vector3(0, 0, 90)
	if riser_ceiling_y > conduit_y:
		var riser_len: float = riser_ceiling_y - conduit_y
		for sx: float in [-0.86, 0.86]:
			_cylinder(root, "Conduit Riser",
				Vector3(sx, conduit_y + riser_len * 0.5, 0.06),
				0.028, riser_len, STEEL_PALE, 0.0, METAL_BRIGHT)

	_solid(root, "Rack Body", Vector3(0, plate_y, 0.11),
		Vector3(width, grid_height, 0.22))
	return root


## Sealed hazard cabinet: tall steel locker, chevron band, warning triangle,
## louvres, padlocked hasp and one long stain down the right leaf.
##
## The hazard reading is carried by the triangle silhouette and the tilted
## chevron bars as much as by the yellow, so it survives greyscale. `placard` is
## the wording on the plate at eye level (pass tr("KEY"), or "" for none); the
## plate is small, so budget roughly 13 characters and pass a short word.
##
## BOUNDING BOX (measured): 1.00 (X) x 2.05 (Y) x 0.60 (Z); local
## x in [-0.50, 0.50], y in [0, 2.05], z in [0, 0.60].
## COLLISION: one box, 1.00 x 2.05 x 0.58 at local (0, 1.025, 0.29).
## NODES: 24 + 2 when sealed + 2 for a placard (28 fully dressed).
static func hazard_cabinet(parent: Node3D, origin: Vector3, facing_deg: float,
		placard := "", sealed := true) -> Node3D:
	var root := _root(parent, "Hazard Cabinet", origin, facing_deg)

	_box(root, "Cabinet Plinth", Vector3(0, 0.05, 0.27),
		Vector3(0.98, 0.10, 0.50), SHADOW)
	_box(root, "Cabinet Body", Vector3(0, 1.075, 0.26),
		Vector3(1.00, 1.95, 0.52), STEEL_DARK, 0.0, METAL_STEEL)
	# Two leaves with a 0.02 m gap. That vertical seam is the strongest line on
	# the prop and it reads at any distance.
	for sx: float in [-0.245, 0.245]:
		_box(root, "Cabinet Door", Vector3(sx, 1.05, 0.535),
			Vector3(0.47, 1.80, 0.035), STEEL, 0.0, METAL_STEEL)
		_cylinder(root, "Cabinet Handle", Vector3(sx * 0.225, 1.10, 0.565),
			0.018, 0.30, STEEL_PALE, 0.0, METAL_BRIGHT)

	if sealed:
		_box(root, "Hasp", Vector3(0, 1.24, 0.570),
			Vector3(0.10, 0.14, 0.03), STEEL_PALE, 0.0, METAL_BRIGHT)
		_box(root, "Padlock", Vector3(0, 1.14, 0.585),
			Vector3(0.07, 0.09, 0.035), Color(0.220, 0.225, 0.235), 0.0, 0.5)

	# Chevrons are tilted inside a 0.20 m dark strip, so nothing overhangs the
	# door edges: a 0.17 x 0.075 bar at 35 degrees is 0.182 tall and 0.159 wide.
	_box(root, "Hazard Band", Vector3(0, 1.88, 0.560),
		Vector3(1.00, 0.20, 0.012), SHADOW)
	for i in range(7):
		var bar := _box(root, "Hazard Chevron %d" % i,
			Vector3(-0.42 + float(i) * 0.14, 1.88, 0.570),
			Vector3(0.075, 0.17, 0.008), HAZARD)
		bar.rotation_degrees = Vector3(0, 0, 35.0)

	# Warning triangle: shape first, colour second.
	_prism(root, "Warning Triangle", Vector3(-0.245, 1.50, 0.560),
		Vector3(0.24, 0.22, 0.012), HAZARD)
	_box(root, "Warning Bar", Vector3(-0.245, 1.487, 0.568),
		Vector3(0.028, 0.075, 0.006), SHADOW)
	_box(root, "Warning Dot", Vector3(-0.245, 1.428, 0.568),
		Vector3(0.028, 0.028, 0.006), SHADOW)

	for i in range(3):
		_box(root, "Louvre %d" % i, Vector3(0, 0.30 + float(i) * 0.06, 0.558),
			Vector3(0.60, 0.025, 0.006), SHADOW)
	# Cheap, and it stops the cabinet reading as a catalogue product.
	_box(root, "Cabinet Stain", Vector3(0.355, 0.95, 0.558),
		Vector3(0.055, 0.90, 0.006), GRIME)

	if placard != "":
		_box(root, "Placard Plate", Vector3(0.245, 1.50, 0.562),
			Vector3(0.44, 0.16, 0.012), PAINT_DARK)
		_stencil(root, "Placard Text", Vector3(0.245, 1.50, 0.575), placard, 0.055)

	_solid(root, "Cabinet Volume", Vector3(0, 1.025, 0.29), Vector3(1.00, 2.05, 0.58))
	return root


## Tool board: painted silhouettes with the tools gone from most of them.
##
## Eight numbered stations. `present` lists the stations whose tool is still
## hanging; every other station shows only the flat painted outline and a bare peg
## hook, which is the entire point of the prop -- the outline of a thing that is
## not there. Station 5 carries a deliberately unreadable silhouette: whatever
## hung there was not a tool. `notice` is the wording on the plate above the board
## (pass tr("KEY"), or "" for none); budget roughly 26 characters.
##
## BOUNDING BOX (measured): 2.28 (X) x 1.60 (Y) x 0.10 (Z); local y in
## [mount_y - 0.05, mount_y + 1.55], which is 0.90 .. 2.50 at the default.
## COLLISION: none. At 0.10 m deep it is wall trim, and keeping it out of the bake
## leaves the aisle beside it at full width.
## NODES: 40 + 2 per hung tool + 2 for the notice (48 with three tools left).
static func tool_board(parent: Node3D, origin: Vector3, facing_deg: float,
		notice := "", present := PackedInt32Array(), mount_y := 0.95) -> Node3D:
	var root := _root(parent, "Tool Board", origin, facing_deg)

	var mid_y: float = mount_y + 0.75
	_box(root, "Board Panel", Vector3(0, mid_y, 0.02),
		Vector3(2.20, 1.50, 0.04), Color(0.085, 0.095, 0.090))
	for sy: float in [mount_y - 0.025, mount_y + 1.525]:
		_box(root, "Board Rail", Vector3(0, sy, 0.025),
			Vector3(2.28, 0.05, 0.05), STEEL_DARK, 0.0, METAL_STEEL)
	for sx: float in [-1.115, 1.115]:
		_box(root, "Board Stile", Vector3(sx, mid_y, 0.025),
			Vector3(0.05, 1.50, 0.05), STEEL_DARK, 0.0, METAL_STEEL)
	for sy: float in [mount_y + 0.28, mount_y + 1.16]:
		_box(root, "Registration Line", Vector3(0, sy, 0.042),
			Vector3(2.14, 0.012, 0.006), Color(0.300, 0.310, 0.280))

	var row_y: float = mount_y + 0.80
	for i in range(8):
		var station: int = i + 1
		var x: float = -0.91 + float(i) * 0.26
		_paint_tool_outline(root, station, Vector3(x, row_y, 0.042))
		var hook := _cylinder(root, "Peg Hook %d" % station,
			Vector3(x, row_y + 0.24, 0.065), 0.010, 0.08, STEEL_PALE, 0.0, METAL_BRIGHT)
		hook.rotation_degrees = Vector3(90.0, 0, 0)  # lay the peg along +Z
		_stencil(root, "Station Number %d" % station,
			Vector3(x, mount_y + 0.16, 0.045), "%02d" % station, 0.050)
		if _contains(present, station):
			# The hung tool sits proud of its own outline and mostly, but not
			# quite, covers it.
			_box(root, "Tool Shaft %d" % station, Vector3(x, row_y - 0.02, 0.078),
				Vector3(0.045, 0.40, 0.030), TOOL_STEEL, 0.0, 0.55)
			_box(root, "Tool Head %d" % station, Vector3(x, row_y + 0.19, 0.078),
				Vector3(0.135, 0.105, 0.038), Color(0.200, 0.210, 0.230), 0.0, 0.55)

	if notice != "":
		_box(root, "Notice Plate", Vector3(0, mount_y + 1.36, 0.045),
			Vector3(1.10, 0.16, 0.012), PAINT_DARK)
		_stencil(root, "Notice Text", Vector3(0, mount_y + 1.36, 0.058), notice, 0.070)

	return root


## Generic cradle for one containment device -- usable for all twelve.
##
## `origin` is the point on the BENCH TOP where the device rests, NOT the floor:
## the cradle builds upward from local y = 0, and GameManager's device body sits
## 0.38 m above that same point, inside the retaining frame. `slot_number` is
## stencilled on a tag tilted 22 degrees back so it faces a standing player.
## `tint` colour-codes the slot to the device that belongs in it, but is always
## paired with the printed number and, when the device is out, with a raised
## vacancy flag standing where the status pip would be.
##
## BOUNDING BOX (measured): 0.86 (X) x 0.32 (Y) x 0.68 (Z) above the bench top;
## local x in [-0.43, 0.43], y in [0, 0.32], z in [-0.33, 0.35]. Fits inside
## GameManager's 1.05 x 0.85 slot footprint and its 1.25 m deep bench.
## COLLISION: none. Every part is under the map's collision-worthy threshold
## (0.12 x 0.08 x 0.12) and the bench underneath is already solid.
## NODES: 11 loaded, 12 empty.
static func device_cradle(parent: Node3D, origin: Vector3, facing_deg: float,
		slot_number: int, tint := Color(0.55, 0.57, 0.60),
		loaded := true) -> Node3D:
	var root := _root(parent, "Device Cradle %02d" % slot_number, origin, facing_deg)

	_box(root, "Cradle Base", Vector3(0, 0.0225, 0.0),
		Vector3(0.86, 0.045, 0.66), STEEL, 0.0, METAL_STEEL)
	_box(root, "Cradle Well", Vector3(0, 0.055, 0.0),
		Vector3(0.60, 0.020, 0.44), SHADOW)
	# Two arms and a rail behind the device. When the slot is empty the frame is
	# still standing there, holding nothing.
	for sx: float in [-0.29, 0.29]:
		var arm := _box(root, "Retaining Arm", Vector3(sx, 0.175, -0.20),
			Vector3(0.04, 0.26, 0.05), STEEL_PALE, 0.0, METAL_BRIGHT)
		arm.rotation_degrees = Vector3(0, 0, 10.0 if sx > 0.0 else -10.0)
	_box(root, "Retaining Rail", Vector3(0, 0.300, -0.20),
		Vector3(0.66, 0.035, 0.035), STEEL_PALE, 0.0, METAL_BRIGHT)
	_box(root, "Contact Strip", Vector3(0, 0.052, 0.16),
		Vector3(0.34, 0.015, 0.05), BRASS, 0.0, 0.7)
	_box(root, "Tint Stripe", Vector3(0, 0.048, -0.28),
		Vector3(0.60, 0.012, 0.035), tint, 0.35)

	var tag := _box(root, "Slot Tag", Vector3(0, 0.11, 0.315),
		Vector3(0.24, 0.13, 0.015), PAINT_DARK)
	tag.rotation_degrees = Vector3(-22.0, 0, 0)
	var tag_text := _stencil(root, "Slot Tag Text", Vector3(0, 0.1145, 0.326),
		"%02d" % slot_number, 0.075)
	if tag_text != null:
		tag_text.rotation_degrees = Vector3(-22.0, 0, 0)

	if loaded:
		_box(root, "Status Pip", Vector3(0.24, 0.055, 0.16),
			Vector3(0.05, 0.02, 0.03), SIGNAL_GREEN, 1.4)
	else:
		_box(root, "Status Pip", Vector3(0.24, 0.050, 0.16),
			Vector3(0.05, 0.01, 0.03), SIGNAL_DEAD, 0.1)
		_box(root, "Vacancy Flag", Vector3(0.24, 0.100, 0.16),
			Vector3(0.05, 0.09, 0.012), SIGNAL_AMBER, 0.5)

	return root


## Ceiling-hung aisle sign, readable from both sides.
##
## `text` is the wording (pass tr("KEY")); budget roughly 26 characters. When
## `slot_to` is greater than zero a second line prints the slot range this aisle
## covers, formatted straight from the integers, so it needs no catalogue row.
##
## BOUNDING BOX (measured): 1.70 (X) x 1.02 (Y) x 0.06 (Z) at the default
## ceiling; occupies y in [2.38, ceiling_y]. Clearance underneath is 2.38 m --
## above the 2.2 m nav agent and above the player, but BELOW the 2.70 m door
## lintels, so hang it in the room and never across a doorway.
## COLLISION: none.
## NODES: 8 + 2 when a slot range is printed.
static func bay_sign(parent: Node3D, origin: Vector3, facing_deg: float,
		text: String, slot_from := 0, slot_to := 0,
		ceiling_y := ROOM_HEIGHT) -> Node3D:
	var root := _root(parent, "Bay Sign", origin, facing_deg)

	_box(root, "Sign Board", Vector3(0, 2.60, 0.0),
		Vector3(1.70, 0.44, 0.05), PAINT_DARK)
	for sy: float in [2.395, 2.805]:
		_box(root, "Sign Edge", Vector3(0, sy, 0.0),
			Vector3(1.70, 0.03, 0.055), PAINT_WORN)
	var rod_len: float = maxf(0.05, ceiling_y - 2.82)
	for sx: float in [-0.62, 0.62]:
		_cylinder(root, "Sign Rod", Vector3(sx, 2.82 + rod_len * 0.5, 0.0),
			0.014, rod_len, STEEL_PALE, 0.0, METAL_BRIGHT)

	var range_text := ""
	if slot_to > 0:
		range_text = "%02d - %02d" % [slot_from, slot_to]
	# Both faces carry the same content; the back copy is turned to face -Z.
	for side: float in [1.0, -1.0]:
		var suffix := "Front" if side > 0.0 else "Back"
		var line := _stencil(root, "Sign Text %s" % suffix,
			Vector3(0, 2.66, 0.032 * side), text, 0.100)
		if line != null and side < 0.0:
			line.rotation_degrees = Vector3(0, 180.0, 0)
		var sub := _stencil(root, "Sign Range %s" % suffix,
			Vector3(0, 2.49, 0.032 * side), range_text, 0.070)
		if sub != null and side < 0.0:
			sub.rotation_degrees = Vector3(0, 180.0, 0)

	return root


## Painted keep-clear zone on the floor in front of a bay, with a large flat
## number oriented to read from the aisle. Give it the SAME origin and facing as
## the bay it belongs to; the paint runs `depth` metres out into the aisle.
##
## BOUNDING BOX (measured): `width` (X) x 0.012 (Y) x `depth` + 0.04 (Z), which
## is 2.40 x 0.012 x 0.94 at the defaults; local z in [0, depth + 0.04].
## COLLISION: none -- 0.012 m of paint, under the map's collision threshold and
## invisible to the navmesh bake.
## NODES: 9.
static func floor_bay_marker(parent: Node3D, origin: Vector3, facing_deg: float,
		number: int, width := 2.40, depth := 0.90) -> Node3D:
	var root := _root(parent, "Floor Bay Marker %02d" % number, origin, facing_deg)

	_box(root, "Zone Edge", Vector3(0, 0.006, depth),
		Vector3(width, 0.012, 0.08), FLOOR_PAINT)
	for sx: float in [-1.0, 1.0]:
		_box(root, "Zone Tick",
			Vector3(sx * (width * 0.5 - 0.04), 0.006, depth * 0.5),
			Vector3(0.08, 0.012, depth), FLOOR_PAINT)
	for i in range(4):
		var hatch := _box(root, "Zone Hatch %d" % i,
			Vector3(-width * 0.5 + 0.45 + float(i) * (width - 0.9) / 3.0,
				0.005, depth - 0.22),
			Vector3(0.09, 0.010, 0.30), Color(0.400, 0.380, 0.200))
		hatch.rotation_degrees = Vector3(0, 45.0, 0)

	var digits := _stencil(root, "Zone Number",
		Vector3(0, 0.014, depth * 0.38), "%02d" % number, 0.34)
	if digits != null:
		# Lay the text on the floor with its top pointing away from the bay, so it
		# is upright for a player walking up the aisle towards the shelves.
		digits.rotation_degrees = Vector3(-90.0, 0, 0)

	return root


## Drop the shared material cache. Only useful when the editor rebuilds the map
## repeatedly in one session and the palette constants have been edited.
static func clear_material_cache() -> void:
	_materials.clear()


# =============================================================================
# Internals
# =============================================================================

## The tool board's painted silhouettes: two flat quads each, cycling through
## wrench / hammer / pry bar / pliers. Station 5 falls through to the shape that
## does not resolve into a tool at all.
static func _paint_tool_outline(root: Node3D, station: int, at: Vector3) -> void:
	match station % 5:
		1:  # wrench
			_box(root, "Outline Shaft %d" % station, at,
				Vector3(0.045, 0.44, 0.006), PAINT_LINE)
			_box(root, "Outline Head %d" % station, at + Vector3(0, 0.22, 0),
				Vector3(0.130, 0.120, 0.006), PAINT_LINE)
		2:  # hammer
			_box(root, "Outline Shaft %d" % station, at,
				Vector3(0.040, 0.46, 0.006), PAINT_LINE)
			_box(root, "Outline Head %d" % station, at + Vector3(0, 0.20, 0),
				Vector3(0.200, 0.075, 0.006), PAINT_LINE)
		3:  # pry bar
			var bar := _box(root, "Outline Bar %d" % station, at,
				Vector3(0.050, 0.52, 0.006), PAINT_LINE)
			bar.rotation_degrees = Vector3(0, 0, 12.0)
			var foot := _box(root, "Outline Foot %d" % station,
				at + Vector3(-0.05, -0.26, 0),
				Vector3(0.100, 0.055, 0.006), PAINT_LINE)
			foot.rotation_degrees = Vector3(0, 0, 40.0)
		4:  # pliers
			for tilt: float in [-9.0, 9.0]:
				var jaw := _box(root, "Outline Jaw %d" % station, at,
					Vector3(0.035, 0.42, 0.006), PAINT_LINE)
				jaw.rotation_degrees = Vector3(0, 0, tilt)
		_:  # whatever hung here, it was not a tool
			_box(root, "Outline Unknown %d" % station, at + Vector3(0, 0.02, 0),
				Vector3(0.075, 0.50, 0.006), PAINT_LINE)
			var stub := _box(root, "Outline Stub %d" % station,
				at + Vector3(0.075, -0.16, 0),
				Vector3(0.140, 0.045, 0.006), PAINT_LINE)
			stub.rotation_degrees = Vector3(0, 0, -28.0)


static func _root(parent: Node3D, node_name: String, origin: Vector3,
		facing_deg: float) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	node.position = origin
	node.rotation_degrees = Vector3(0, facing_deg, 0)
	parent.add_child(node)
	return node


## One StaticBody3D per prop rather than the map's per-mesh colliders: far fewer
## nodes, and a navmesh bake that sees the prop's real blocking volume instead of
## the union of forty little boxes.
static func _solid(root: Node3D, node_name: String, center: Vector3,
		size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	root.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "%s Shape" % node_name
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


static func _box(parent: Node3D, node_name: String, at: Vector3, size: Vector3,
		color: Color, emission := 0.0, metallic := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, node_name, at, mesh, size, color, emission, metallic)


## Cut to 10 radial segments and one ring. A default CylinderMesh is 64 segments
## deep and costs an order of magnitude more triangles than any of these props is
## worth. The mesh stands along +Y; rotate the returned instance to lay it down.
static func _cylinder(parent: Node3D, node_name: String, at: Vector3,
		radius: float, height: float, color: Color, emission := 0.0,
		metallic := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	return _mesh(parent, node_name, at, mesh,
		Vector3(radius * 2.0, height, radius * 2.0), color, emission, metallic)


static func _prism(parent: Node3D, node_name: String, at: Vector3, size: Vector3,
		color: Color, emission := 0.0) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _mesh(parent, node_name, at, mesh, size, color, emission, 0.0)


static func _mesh(parent: Node3D, node_name: String, at: Vector3,
		mesh: PrimitiveMesh, size: Vector3, color: Color, emission: float,
		metallic: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = at
	instance.mesh = mesh
	instance.material_override = _material(color, emission, metallic)
	instance.visibility_range_end = CULL_DISTANCE
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# Stencil plates, pips, louvres and hooks: shadow-map work on them buys
	# nothing at this size.
	if size.length() < 0.65:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## Painted signage. Deliberately NOT billboarded: a billboarded Label3D swivels to
## face whatever camera renders it, which is exactly the defect FirstMuseumMap
## documents around CCTV_HIDDEN_LAYER. These stay flat on the surface they are
## painted on, so the security feeds see a storeroom rather than a fan of pivoting
## text, and no layer juggling is needed.
##
## Unshaded, so the wording survives the lights failing, and outlined in opaque
## black: STENCIL on black measures 15.9:1 against a 4.5:1 floor, and because the
## outline travels with the glyphs that ratio holds no matter what the text ends
## up sitting on. Returns null for empty text so callers can skip optional labels.
static func _stencil(parent: Node3D, node_name: String, at: Vector3, text: String,
		cap_height: float, color := STENCIL) -> Label3D:
	if text == "":
		return null
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = at
	label.font_size = STENCIL_FONT_SIZE
	label.pixel_size = cap_height / (float(STENCIL_FONT_SIZE) * STENCIL_CAP_RATIO)
	label.modulate = color
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 1)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = false
	label.shaded = false
	label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.visibility_range_end = LABEL_CULL_DISTANCE
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(label)
	return label


## Shared across every prop in this file and every room that uses it. Measured:
## one of each builder above, fully dressed, costs 23 distinct
## StandardMaterial3D instances between them; a real room adds one more per
## device tint passed to device_cradle(). No noise textures -- painted steel reads
## better smooth, and it saves generating the texture pair the map already pays
## for.
static func _material(color: Color, emission: float,
		metallic: float) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(true), emission, metallic]
	if _materials.has(key):
		return _materials[key]

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.metallic_specular = 0.55
	mat.roughness = clampf(0.62 - metallic * 0.34, 0.14, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	_materials[key] = mat
	return mat


static func _contains(values: PackedInt32Array, value: int) -> bool:
	for v: int in values:
		if v == value:
			return true
	return false
