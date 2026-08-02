class_name LobbyProps
extends RefCounted
## Procedural props for the Entrance Zone (visitor lobby) of THE FIRST MUSEUM.
##
## The map has no 3D content on disk -- scenes/FirstMuseumMap.tscn is empty and
## FirstMuseumMap.build_map() builds the whole building at runtime. This file
## follows AtriumProps.gd: every builder takes (parent, origin, ...), puts one
## prop under a single Node3D and returns that root, so the map places a whole
## lobby in one line. Nothing here reads or writes any other script.
##
## THE BRIEF
## This is the first room the player ever stands in, and until now it was a
## flat box desk and a locker slab. A real museum lobby reads as a SERVICE
## COUNTER plus a QUEUE plus WAYFINDING: you come in, you see where to pay, you
## see where the coats go, you see which way the halls are. Everything is built
## at the heights a real front-of-house desk uses -- 1.10 m transaction top for
## the visitor, 0.75 m work surface for the staff behind it -- so the room
## reads correctly from standing eye height rather than from a screenshot.
##
## ROOM ENVELOPE (from FirstMuseumMap.build_map)
##   Entrance Zone  centre (0, 0, 25), 22 x 20 m, so x in [-11, 11],
##   z in [15, 35]. Interior wall faces at x +-10.65, z 15.35 and 34.65
##   (WALL_THICKNESS 0.35). Floor top y = 0, ceiling underside y = 3.39.
##   Doorways (DOOR_GAP 1.8) at (0, 0, 15) to the Central Atrium and
##   (0, 0, 35) to the street.
##   Kept map furniture this file is routed clear of: entrance pylons at
##   z 34.45, vestibule glass at x +-2.75 / z 31.9, tambour canopy and carpet
##   at z 32, night shutter at z 34.2.
##
## NAVIGATION
## The Curator bakes on agent_radius 0.45 through 1.8 m doorways, and both this
## room's doorways sit on the x = 0 axis. Every collider in this file stays
## outside |x| < 2.6, so the spine from the street door to the atrium door is a
## clear 5.2 m corridor end to end. Queue stanchions and floor paint carry no
## collision at all -- you can walk through a rope, you cannot walk through the
## desk. Cylinders get a CylinderShape3D, never a box, so no invisible corner
## walls appear out at radius * sqrt(2).
##
## ACCESSIBILITY
## Nothing animates, pulses or flickers, so SettingsManager.reduced_flashes has
## nothing to switch off. Signage is pale text (0.82, 0.86, 0.84) on near-black
## panels (0.072, 0.076, 0.082) and is never billboarded -- text that swivels to
## face the rendering camera has already put a fan of rotating labels through
## every CCTV feed in this project once. All new signage is numerals, arrows and
## symbols, so it needs no new translation keys; the two localised strings the
## room already had (EXHIBIT_RECEPTION, EXHIBIT_CLOAKROOM) are passed in by the
## caller.

static var _materials := {}

# Предзагрузка, а не глобальное имя MaterialLib: тесты запускаются через --script,
# а там глобальные class_name могут быть ещё не зарегистрированы.
const MatLib := preload("res://game/props/MaterialLib.gd")

const VISIBILITY_RANGE := 44.0

# Palette. Warm stone and dark walnut for the joinery, cold steel for the
# fittings: the lobby should feel like a civic building that is still trying.
const STONE := Color(0.60, 0.58, 0.55)
const STONE_DARK := Color(0.42, 0.41, 0.39)
const WOOD := Color(0.20, 0.14, 0.095)
const WOOD_LIGHT := Color(0.33, 0.23, 0.15)
const STEEL_DARK := Color(0.16, 0.17, 0.18)
const STEEL := Color(0.42, 0.44, 0.46)
const BRASS := Color(0.50, 0.40, 0.19)
const PANEL := Color(0.072, 0.076, 0.082)
const SIGN_TEXT := Color(0.82, 0.86, 0.84)
const SCREEN := Color(0.12, 0.26, 0.30)
const FELT := Color(0.24, 0.07, 0.065)
const ROPE := Color(0.32, 0.09, 0.09)
const PAPER := Color(0.74, 0.72, 0.66)
const LEAF := Color(0.14, 0.26, 0.13)

# Front-of-house ergonomics, all in metres.
const COUNTER_TOP := 1.10   # visitor side transaction surface
const WORK_TOP := 0.75      # staff side work surface
const TOE_KICK := 0.12


# =============================================================================
#  Entry point
# =============================================================================

## Builds the whole lobby set under one node. `origin` is the room centre --
## (0, 0, 25) for the Entrance Zone -- and every builder below is placed in
## room-local coordinates from there, so the set can be moved in one edit.
static func build_lobby(parent: Node3D, origin: Vector3,
		ceiling_y := 3.39) -> Node3D:
	var root := _root(parent, "Lobby Set", origin)
	build_reception_counter(root, Vector3(-6.0, 0.0, 0.6), ceiling_y)
	build_back_office(root, Vector3(-9.4, 0.0, 0.6))
	build_rope_queue(root, Vector3(-6.0, 0.0, 3.1))
	build_cloakroom(root, Vector3(8.6, 0.0, -2.4))
	build_audioguide_kiosk(root, Vector3(6.9, 0.0, 2.6))
	build_wayfinding(root, Vector3(0.0, 0.0, -9.2))
	build_waiting_area(root, Vector3(0.0, 0.0, -5.4))
	build_lobby_lighting(root, Vector3.ZERO, ceiling_y)
	return root


# =============================================================================
#  Reception counter
# =============================================================================

## L-shaped front desk. The long run faces the street door; the short return
## wing closes the staff side so the player cannot walk in behind it. Real desks
## are two surfaces, not one slab: a 1.10 m ledge the visitor leans on and a
## 0.75 m worktop 35 cm lower where the monitor and the till actually live.
static func build_reception_counter(parent: Node3D, origin: Vector3,
		ceiling_y := 3.39) -> Node3D:
	var root := _root(parent, "Reception Counter", origin)
	var run := 4.6      # long axis, along x
	var depth := 0.92   # front to back, along z

	# --- main run -------------------------------------------------------
	# Recessed toe kick, so the carcass does not look like it was dropped on
	# the floor. The kick is 6 cm shallower than the body on every side.
	_box(root, "Counter Kick", Vector3(0.0, TOE_KICK * 0.5, 0.0),
		Vector3(run - 0.12, TOE_KICK, depth - 0.12), STONE_DARK,
		0.0, 0.0, false, "concrete")
	_box(root, "Counter Carcass", Vector3(0.0, 0.43, 0.0),
		Vector3(run, 0.62, depth), WOOD, 0.0, 0.0, true)
	# Staff worktop at 0.75, set back from the visitor edge.
	_box(root, "Counter Worktop", Vector3(0.0, WORK_TOP - 0.02, -0.17),
		Vector3(run - 0.10, 0.04, depth - 0.42), WOOD_LIGHT, 0.0, 0.15)
	# Visitor ledge at 1.10, overhanging the front by 9 cm.
	# Столешница — травертин с мелким масштабом: на полосе шириной 1.1 м
	# полноразмерная плита в 2.4 м не показала бы ни одного шва.
	_box(root, "Counter Ledge", Vector3(0.0, COUNTER_TOP - 0.04, 0.09),
		Vector3(run + 0.24, 0.08, depth + 0.18), STONE, 0.0, 0.25, true,
		"travertine")
	_box(root, "Counter Ledge Nosing", Vector3(0.0, COUNTER_TOP - 0.11, 0.55),
		Vector3(run + 0.24, 0.06, 0.05), BRASS, 0.0, 0.6)
	# Fascia panelling: three recessed fields between four stiles, which is how
	# joinery this size is actually built and reads far better than a flat face.
	_box(root, "Counter Fascia", Vector3(0.0, 0.60, 0.475),
		Vector3(run, 0.94, 0.05), WOOD)
	for i in 3:
		var fx: float = -1.5 + float(i) * 1.5
		_box(root, "Counter Fascia Field %d" % (i + 1),
			Vector3(fx, 0.60, 0.505), Vector3(1.22, 0.66, 0.02), WOOD_LIGHT)
	for sx: float in [-1.0, 0.5]:
		_box(root, "Counter Fascia Stile %.1f" % sx,
			Vector3(sx - 0.25 + 0.25, 0.60, 0.505),
			Vector3(0.06, 0.94, 0.02), STONE_DARK)
	for ex: float in [-1.0, 1.0]:
		_box(root, "Counter End Panel %s" % ("West" if ex < 0.0 else "East"),
			Vector3(ex * (run * 0.5 + 0.03), 0.60, 0.0),
			Vector3(0.06, 0.94, depth), WOOD_LIGHT)

	# --- return wing ----------------------------------------------------
	# Runs back along -z from the west end, closing the staff enclosure.
	var wing_len := 2.3
	var wing_x: float = -(run * 0.5) + 0.46
	var wing_z: float = -(depth * 0.5) - wing_len * 0.5 + 0.10
	_box(root, "Counter Wing Kick", Vector3(wing_x, TOE_KICK * 0.5, wing_z),
		Vector3(depth - 0.12, TOE_KICK, wing_len - 0.12), STONE_DARK,
		0.0, 0.0, false, "concrete")
	_box(root, "Counter Wing Carcass", Vector3(wing_x, 0.43, wing_z),
		Vector3(depth, 0.62, wing_len), WOOD, 0.0, 0.0, true)
	_box(root, "Counter Wing Ledge", Vector3(wing_x, COUNTER_TOP - 0.04, wing_z),
		Vector3(depth + 0.18, 0.08, wing_len), STONE, 0.0, 0.25, true,
		"travertine")
	_box(root, "Counter Wing Fascia",
		Vector3(wing_x - depth * 0.5 - 0.025, 0.60, wing_z),
		Vector3(0.05, 0.94, wing_len), WOOD_LIGHT)

	# --- what a staffed desk has on it ----------------------------------
	# Two monitors on the 0.75 worktop, canted 14 deg back off vertical, which
	# is the same pitch the CCTV props in this project use.
	for i in 2:
		var mx: float = -1.25 + float(i) * 2.5
		_cyl(root, "Monitor Foot %d" % (i + 1), Vector3(mx, WORK_TOP + 0.02, -0.22),
			0.10, 0.02, STEEL_DARK, 10, 0.4)
		_box(root, "Monitor Stem %d" % (i + 1), Vector3(mx, WORK_TOP + 0.11, -0.22),
			Vector3(0.05, 0.18, 0.05), STEEL_DARK, 0.0, 0.4)
		var shell := _box(root, "Monitor Shell %d" % (i + 1),
			Vector3(mx, WORK_TOP + 0.36, -0.21),
			Vector3(0.54, 0.34, 0.03), STEEL_DARK, 0.0, 0.35)
		shell.rotation.x = deg_to_rad(14.0)
		var face := _box(root, "Monitor Screen %d" % (i + 1),
			Vector3(mx, WORK_TOP + 0.36, -0.185),
			Vector3(0.50, 0.30, 0.01), SCREEN, 0.55)
		face.rotation.x = deg_to_rad(14.0)
		_box(root, "Keyboard %d" % (i + 1), Vector3(mx, WORK_TOP + 0.02, -0.05),
			Vector3(0.42, 0.02, 0.15), PANEL)
	# Card terminal on the visitor ledge, tilted up to the customer.
	_box(root, "Card Terminal Base", Vector3(1.62, COUNTER_TOP + 0.02, 0.05),
		Vector3(0.13, 0.04, 0.18), STEEL_DARK, 0.0, 0.3)
	var term := _box(root, "Card Terminal", Vector3(1.62, COUNTER_TOP + 0.08, 0.04),
		Vector3(0.12, 0.12, 0.03), PANEL, 0.18)
	term.rotation.x = deg_to_rad(-38.0)
	# Ticket roll, brochure stack, pen cup, bell: the small change of a real desk.
	_box(root, "Ticket Stack", Vector3(0.72, COUNTER_TOP + 0.03, 0.02),
		Vector3(0.22, 0.05, 0.11), PAPER)
	_box(root, "Brochure Stack A", Vector3(-0.85, COUNTER_TOP + 0.04, 0.10),
		Vector3(0.21, 0.07, 0.29), PAPER)
	_box(root, "Brochure Stack B", Vector3(-1.35, COUNTER_TOP + 0.03, 0.08),
		Vector3(0.21, 0.05, 0.29), Color(0.66, 0.60, 0.50))
	_cyl(root, "Pen Cup", Vector3(-0.35, COUNTER_TOP + 0.06, -0.02),
		0.045, 0.11, STEEL, 10, 0.5)
	_cyl(root, "Service Bell Base", Vector3(2.05, COUNTER_TOP + 0.02, -0.02),
		0.06, 0.02, BRASS, 12, 0.7)
	_sphere(root, "Service Bell", Vector3(2.05, COUNTER_TOP + 0.06, -0.02),
		0.055, BRASS)
	# Badge rack on the staff side, and a wastebin under the worktop.
	_box(root, "Badge Rack", Vector3(-1.95, WORK_TOP + 0.09, -0.30),
		Vector3(0.28, 0.16, 0.10), STEEL_DARK, 0.0, 0.4)
	_cyl(root, "Desk Bin", Vector3(1.85, 0.16, -0.20), 0.15, 0.32, STEEL_DARK,
		12, 0.35)

	# --- suspended sign over the desk -----------------------------------
	# Hung on two rods off the slab so it floats in the sightline from the door
	# instead of being lost against the wall behind the staff.
	var sign_y: float = 2.52
	for rx: float in [-1.5, 1.5]:
		_beam(root, "Sign Rod %s" % ("West" if rx < 0.0 else "East"),
			Vector3(rx, ceiling_y - 0.04, 0.35),
			Vector3(rx, sign_y + 0.22, 0.35), 0.014, STEEL)
	_box(root, "Reception Sign Board", Vector3(0.0, sign_y, 0.35),
		Vector3(3.5, 0.44, 0.06), PANEL, 0.10)
	_box(root, "Reception Sign Frame", Vector3(0.0, sign_y, 0.39),
		Vector3(3.58, 0.50, 0.02), BRASS, 0.0, 0.6)
	return root


# =============================================================================
#  Back office wall behind the counter
# =============================================================================

## Shelving, key board and a locker bank on the wall the staff have their back
## to. Without this the desk floats in front of bare plaster and the whole
## corner reads as unfinished.
static func build_back_office(parent: Node3D, origin: Vector3) -> Node3D:
	var root := _root(parent, "Back Office Wall", origin)
	_box(root, "Back Unit Carcass", Vector3(0.0, 1.05, 0.0),
		Vector3(0.42, 2.10, 4.2), WOOD, 0.0, 0.0, true)
	_box(root, "Back Unit Plinth", Vector3(0.0, 0.06, 0.0),
		Vector3(0.44, 0.12, 4.2), STONE_DARK)
	for i in 4:
		_box(root, "Back Shelf %d" % (i + 1),
			Vector3(0.10, 0.46 + float(i) * 0.48, 1.05),
			Vector3(0.24, 0.03, 1.9), WOOD_LIGHT)
	# Ring binders, stacked in leaning runs rather than a solid block.
	for i in 9:
		var row: int = i % 3
		var tint: float = 0.20 + float(i % 4) * 0.06
		_box(root, "Binder %d" % (i + 1),
			Vector3(0.10, 0.62 + float(row) * 0.48, 0.35 + float(i) * 0.15),
			Vector3(0.20, 0.28, 0.055), Color(tint, tint * 0.55, tint * 0.42))
	# Key cabinet with a grid of hooks -- the museum's spare keys have to live
	# somewhere the night shift can be sent to.
	_box(root, "Key Cabinet", Vector3(0.14, 1.62, -1.35),
		Vector3(0.10, 0.62, 0.86), STEEL_DARK, 0.0, 0.45)
	for i in 8:
		_cyl(root, "Key Hook %d" % (i + 1),
			Vector3(0.20, 1.78 - float(i / 4) * 0.26, -1.65 + float(i % 4) * 0.20),
			0.012, 0.05, BRASS, 6, 0.7)
	# Staff lockers at the far end of the run.
	for i in 3:
		_box(root, "Staff Locker %d" % (i + 1),
			Vector3(0.0, 0.95, -2.45 - float(i) * 0.46),
			Vector3(0.44, 1.86, 0.44), STEEL_DARK, 0.0, 0.5, true)
		_box(root, "Staff Locker Vent %d" % (i + 1),
			Vector3(0.23, 1.62, -2.45 - float(i) * 0.46),
			Vector3(0.02, 0.16, 0.24), PANEL)
	return root


# =============================================================================
#  Queue barrier
# =============================================================================

## Belt stanchions marking the approach to the desk. Deliberately COLLISION
## FREE: a rope line that physically blocks a 0.45 m nav agent turns a lobby
## into a maze, and the Curator bakes its mesh through this room.
static func build_rope_queue(parent: Node3D, origin: Vector3) -> Node3D:
	var root := _root(parent, "Queue Barrier", origin)
	var posts: Array[Vector3] = [
		Vector3(-2.3, 0.0, 0.0), Vector3(-0.4, 0.0, 0.0),
		Vector3(1.5, 0.0, 0.0), Vector3(1.5, 0.0, -1.9),
	]
	for i in posts.size():
		var p: Vector3 = posts[i]
		_cyl(root, "Stanchion Base %d" % (i + 1), p + Vector3(0.0, 0.02, 0.0),
			0.17, 0.04, STEEL_DARK, 14, 0.5)
		_cyl(root, "Stanchion Post %d" % (i + 1), p + Vector3(0.0, 0.48, 0.0),
			0.028, 0.92, STEEL, 10, 0.65)
		_sphere(root, "Stanchion Cap %d" % (i + 1), p + Vector3(0.0, 0.96, 0.0),
			0.038, BRASS)
		if i > 0:
			var a: Vector3 = posts[i - 1] + Vector3(0.0, 0.86, 0.0)
			var b: Vector3 = p + Vector3(0.0, 0.86, 0.0)
			# Two slightly offset segments give the rope a sag without needing
			# a curve: the midpoint drops 7 cm, which is what a 1.9 m span does.
			var mid: Vector3 = (a + b) * 0.5 - Vector3(0.0, 0.07, 0.0)
			_beam(root, "Queue Rope %dA" % i, a, mid, 0.022, ROPE)
			_beam(root, "Queue Rope %dB" % i, mid, b, 0.022, ROPE)
	return root


# =============================================================================
#  Cloakroom
# =============================================================================

## Coat drop with a hatch counter, hanging rail with coats, and a numbered tag
## board. Replaces the single locker slab the room used to have.
static func build_cloakroom(parent: Node3D, origin: Vector3) -> Node3D:
	var root := _root(parent, "Cloakroom", origin)
	# Hatch counter facing west into the room.
	_box(root, "Cloak Counter Kick", Vector3(0.0, TOE_KICK * 0.5, 0.0),
		Vector3(0.70, TOE_KICK, 2.9), STONE_DARK)
	_box(root, "Cloak Counter Carcass", Vector3(0.0, 0.44, 0.0),
		Vector3(0.82, 0.64, 3.0), WOOD, 0.0, 0.0, true)
	_box(root, "Cloak Counter Top", Vector3(-0.06, COUNTER_TOP - 0.04, 0.0),
		Vector3(1.02, 0.08, 3.1), STONE, 0.0, 0.25, true)
	_box(root, "Cloak Counter Fascia", Vector3(-0.43, 0.60, 0.0),
		Vector3(0.05, 0.94, 3.0), WOOD_LIGHT)
	# Hatch surround: two jambs and a head, so the opening reads as cut into a
	# partition rather than as a free-standing table.
	for jz: float in [-1.55, 1.55]:
		_box(root, "Cloak Jamb %s" % ("South" if jz < 0.0 else "North"),
			Vector3(0.0, 1.60, jz), Vector3(0.30, 3.20, 0.26), STONE_DARK)
	_box(root, "Cloak Hatch Head", Vector3(0.0, 2.62, 0.0),
		Vector3(0.30, 0.56, 2.86), STONE_DARK)
	# Rail and coats behind the hatch.
	_beam(root, "Coat Rail", Vector3(0.85, 1.72, -1.35), Vector3(0.85, 1.72, 1.35),
		0.022, STEEL)
	for i in 11:
		var cz: float = -1.25 + float(i) * 0.25
		var shade: float = 0.10 + float(i % 5) * 0.035
		_cyl(root, "Hanger %d" % (i + 1), Vector3(0.85, 1.66, cz),
			0.010, 0.12, STEEL, 6, 0.6)
		_box(root, "Coat %d" % (i + 1), Vector3(0.87, 1.16, cz),
			Vector3(0.26, 0.92, 0.12), Color(shade, shade * 0.95, shade * 0.88))
	# Numbered tag board on the jamb the visitor faces.
	_box(root, "Tag Board", Vector3(-0.14, 1.86, -1.62),
		Vector3(0.03, 0.52, 0.42), PANEL, 0.08)
	for i in 12:
		_cyl(root, "Tag %d" % (i + 1),
			Vector3(-0.17, 2.02 - float(i / 4) * 0.14, -1.77 + float(i % 4) * 0.11),
			0.022, 0.006, BRASS, 8, 0.7)
	_label(root, "01 - 48", Vector3(-0.20, 2.20, -1.62), SIGN_TEXT, 26, 0.0040)
	return root


# =============================================================================
#  Audio guide kiosk
# =============================================================================

static func build_audioguide_kiosk(parent: Node3D, origin: Vector3) -> Node3D:
	var root := _root(parent, "Audio Guide Kiosk", origin)
	_box(root, "Kiosk Plinth", Vector3(0.0, 0.06, 0.0),
		Vector3(0.78, 0.12, 0.58), STONE_DARK)
	_box(root, "Kiosk Body", Vector3(0.0, 0.60, 0.0),
		Vector3(0.72, 1.08, 0.52), PANEL, 0.0, 0.3, true)
	# Sloped face at 22 deg: the angle a standing adult reads a screen at.
	var face := _box(root, "Kiosk Screen", Vector3(0.0, 1.24, -0.13),
		Vector3(0.60, 0.42, 0.03), SCREEN, 0.50)
	face.rotation.x = deg_to_rad(22.0)
	var bezel := _box(root, "Kiosk Bezel", Vector3(0.0, 1.24, -0.15),
		Vector3(0.68, 0.50, 0.03), STEEL_DARK, 0.0, 0.4)
	bezel.rotation.x = deg_to_rad(22.0)
	# Charging cradle of handsets on the side.
	for i in 6:
		_box(root, "Handset %d" % (i + 1),
			Vector3(-0.24 + float(i % 3) * 0.24, 1.12, 0.20 + float(i / 3) * 0.13),
			Vector3(0.07, 0.16, 0.04), STEEL_DARK, 0.0, 0.35)
	_label(root, "i", Vector3(0.0, 1.66, -0.02), SIGN_TEXT, 44, 0.0060)
	return root


# =============================================================================
#  Wayfinding
# =============================================================================

## Hall directory, floor plan and painted floor bands. This is the piece that
## makes the room legible: from the street door you can see which way the halls
## are before you have spoken to anyone.
static func build_wayfinding(parent: Node3D, origin: Vector3) -> Node3D:
	var root := _root(parent, "Wayfinding", origin)
	# Free-standing directory beside the atrium doorway, well clear of the
	# 1.8 m gap on the axis.
	for sx: float in [-3.1, 3.1]:
		var side: String = "West" if sx < 0.0 else "East"
		_box(root, "Directory Foot %s" % side, Vector3(sx, 0.03, 0.0),
			Vector3(0.62, 0.06, 0.46), STEEL_DARK)
		_cyl(root, "Directory Mast %s" % side, Vector3(sx, 1.02, 0.0),
			0.045, 1.98, STEEL, 10, 0.55, 0.0, true)
		_box(root, "Directory Panel %s" % side, Vector3(sx, 1.66, 0.05),
			Vector3(0.86, 1.14, 0.05), PANEL, 0.09)
		_box(root, "Directory Frame %s" % side, Vector3(sx, 1.66, 0.08),
			Vector3(0.92, 1.20, 0.02), BRASS, 0.0, 0.6)
		# Four hall rows. The wing colour tab sits BESIDE the numeral, never
		# instead of it, so the board still works without colour vision.
		var tints: Array[Color] = [
			Color(0.30, 0.46, 0.62), Color(0.58, 0.42, 0.24),
			Color(0.34, 0.54, 0.38), Color(0.52, 0.34, 0.52),
		]
		for i in 4:
			var ry: float = 2.02 - float(i) * 0.26
			_box(root, "Directory Tab %s %d" % [side, i + 1],
				Vector3(sx - 0.34, ry, 0.09), Vector3(0.10, 0.16, 0.01),
				tints[i], 0.16)
			_label(root, "%d" % (i + 1), Vector3(sx - 0.16, ry, 0.10),
				SIGN_TEXT, 30, 0.0042)
			_box(root, "Directory Rule %s %d" % [side, i + 1],
				Vector3(sx + 0.06, ry - 0.10, 0.09),
				Vector3(0.62, 0.008, 0.01), STONE_DARK)
	# Painted floor bands leading from the street door to the atrium door. No
	# collision, 1.4 cm proud of the slab so they never z-fight the floor.
	for i in 7:
		var bz: float = 1.4 + float(i) * 1.55
		_box(root, "Floor Band %d" % (i + 1), Vector3(0.0, 0.007, bz),
			Vector3(1.34, 0.014, 0.16), Color(0.56, 0.50, 0.22), 0.10)
	# Threshold arrows either side of the atrium doorway.
	for ax: float in [-1.15, 1.15]:
		var arrow := _prism(root, "Threshold Arrow %s" % ("West" if ax < 0.0 else "East"),
			Vector3(ax, 0.008, 0.55), Vector3(0.44, 0.62, 0.014),
			Color(0.56, 0.50, 0.22), 0.10)
		arrow.rotation.x = deg_to_rad(90.0)
		arrow.rotation.z = PI
	return root


# =============================================================================
#  Waiting area
# =============================================================================

## Benches, bins, planters and a poster stand in the middle of the room, held
## off the door axis so the walk from street to atrium is never obstructed.
static func build_waiting_area(parent: Node3D, origin: Vector3) -> Node3D:
	var root := _root(parent, "Waiting Area", origin)
	for i in 2:
		var bx: float = -4.6 + float(i) * 9.2
		var side: String = "West" if bx < 0.0 else "East"
		# Bench: slatted seat on two stone cheeks, 0.45 m seat height.
		for cz: float in [-0.78, 0.78]:
			_box(root, "Bench %s Cheek %.2f" % [side, cz],
				Vector3(bx, 0.21, cz), Vector3(0.44, 0.42, 0.16), STONE_DARK)
		for s in 4:
			_box(root, "Bench %s Slat %d" % [side, s + 1],
				Vector3(bx - 0.18 + float(s) * 0.12, 0.45, 0.0),
				Vector3(0.10, 0.06, 1.86), WOOD_LIGHT, 0.0, 0.0, s == 0)
		# Bin beside each bench.
		_cyl(root, "Lobby Bin %s" % side, Vector3(bx + 0.85, 0.30, -1.15),
			0.19, 0.60, STEEL_DARK, 12, 0.4, 0.0, true)
		_ring(root, "Lobby Bin Rim %s" % side, Vector3(bx + 0.85, 0.60, -1.15),
			0.17, 0.20, STEEL, 14)
		# Planter: tub, soil, and a few leaf masses rather than one green ball.
		_cyl(root, "Planter %s" % side, Vector3(bx - 0.10, 0.28, 2.4),
			0.40, 0.56, STONE, 14, 0.0, 0.0, true)
		_cyl(root, "Planter Soil %s" % side, Vector3(bx - 0.10, 0.57, 2.4),
			0.36, 0.03, Color(0.13, 0.10, 0.08), 14)
		for l in 5:
			var ang: float = TAU * float(l) / 5.0
			_sphere(root, "Planter Leaf %s %d" % [side, l + 1],
				Vector3(bx - 0.10 + cos(ang) * 0.17, 0.78 + float(l % 2) * 0.14,
					2.4 + sin(ang) * 0.17), 0.21, LEAF)
	# Poster stand on the axis but pushed to the room's south-east quarter.
	_box(root, "Poster Stand Foot", Vector3(3.4, 0.04, -2.2),
		Vector3(0.70, 0.08, 0.40), STEEL_DARK)
	_box(root, "Poster Stand Board", Vector3(3.4, 1.05, -2.2),
		Vector3(0.86, 1.94, 0.06), PANEL, 0.0, 0.2, true)
	_box(root, "Poster Sheet", Vector3(3.4, 1.10, -2.24),
		Vector3(0.72, 1.66, 0.01), Color(0.44, 0.36, 0.30), 0.12)
	return root


# =============================================================================
#  Lighting
# =============================================================================

## Two ceiling pools plus a warm wash on the counter. Kept to three lights: the
## map already runs a room light per room and this is a forward+ renderer.
static func build_lobby_lighting(parent: Node3D, origin: Vector3,
		ceiling_y := 3.39) -> Node3D:
	var root := _root(parent, "Lobby Lighting", origin)
	for i in 2:
		var lz: float = -4.2 + float(i) * 8.4
		_cyl(root, "Lobby Pendant Can %d" % (i + 1),
			Vector3(0.0, ceiling_y - 0.14, lz), 0.34, 0.16,
			Color(0.20, 0.21, 0.22), 16, 0.4)
		_cyl(root, "Lobby Pendant Lens %d" % (i + 1),
			Vector3(0.0, ceiling_y - 0.23, lz), 0.30, 0.03,
			Color(0.96, 0.90, 0.74), 16, 0.0, 1.7)
		var lamp := OmniLight3D.new()
		lamp.name = "Lobby Lamp %d" % (i + 1)
		lamp.position = Vector3(0.0, ceiling_y - 0.32, lz)
		lamp.light_color = Color(1.0, 0.94, 0.83)
		lamp.light_energy = 1.5
		lamp.omni_range = 11.0
		lamp.shadow_enabled = false
		root.add_child(lamp)
	# Counter wash, aimed straight down over the desk so the staff side reads.
	var desk_lamp := OmniLight3D.new()
	desk_lamp.name = "Reception Wash"
	desk_lamp.position = Vector3(-6.0, 2.30, 0.6)
	desk_lamp.light_color = Color(1.0, 0.90, 0.74)
	desk_lamp.light_energy = 1.25
	desk_lamp.omni_range = 6.4
	desk_lamp.shadow_enabled = false
	root.add_child(desk_lamp)
	return root


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
		with_collision := false, pack := "") -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var inst := _attach(parent, node_name, box_position, mesh, size, color,
		emission, metallic, pack)
	if with_collision:
		var shape := BoxShape3D.new()
		shape.size = size
		_add_body(inst, node_name, shape)
	return inst


## Cylinders get a CylinderShape3D, never a box. A BoxShape3D fitted to a
## cylinder's bounding size puts invisible walls out at radius * sqrt(2).
static func _cyl(parent: Node3D, node_name: String, cyl_position: Vector3,
		radius: float, height: float, color: Color, segments := 12,
		metallic := 0.0, emission := 0.0,
		with_collision := false, pack := "") -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.radial_segments = segments
	mesh.rings = 0
	var inst := _attach(parent, node_name, cyl_position, mesh,
		Vector3(radius * 2.0, height, radius * 2.0), color, emission, metallic,
		pack)
	if with_collision:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		_add_body(inst, node_name, shape)
	return inst


static func _sphere(parent: Node3D, node_name: String, sphere_position: Vector3,
		radius: float, color: Color, emission := 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _attach(parent, node_name, sphere_position, mesh,
		Vector3(radius * 2.0, radius * 2.0, radius * 2.0), color, emission)


## Flat ring lying in the XZ plane: bin rims, floor bands, drum belts.
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


## PrismMesh is authored upright with its apex on +y and extruded along z; the
## caller lays it down with a +90 deg pitch for a floor arrow.
static func _prism(parent: Node3D, node_name: String, prism_position: Vector3,
		size: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _attach(parent, node_name, prism_position, mesh, size, color,
		emission, 0.0)


## Cylinder stretched between two points: rails, rods, ropes.
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


## Unshaded, non-billboarded signage. A plaque that swivels to face whatever
## camera is rendering is what put a fan of rotating text through every CCTV
## feed in this project once already.
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
static func _tr(key: String) -> String:
	return String(TranslationServer.translate(key))


## `pack` — имя набора из MaterialLib.PACKS ("travertine", "concrete", "steel"...).
## Пустая строка оставляет старое поведение — ровный цвет. Так фототекстуры
## включаются точечно, на тех поверхностях, где они что-то дают, а не везде
## сразу: мелкая фурнитура вроде ручек и кнопок от 2K-карты не выигрывает, а
## выборок текстуры тратит втрое больше из-за трипланара.
static func _attach(parent: Node3D, node_name: String, prim_position: Vector3,
		mesh: PrimitiveMesh, size: Vector3, color: Color, emission := 0.0,
		metallic := 0.0, pack := "") -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.position = prim_position
	inst.mesh = mesh
	# Набор можно не указывать: палитра вестибюля сама говорит, из чего
	# сделана деталь — WOOD это дуб, STEEL это сталь, PANEL это пластик.
	# Без этого пришлось бы дописывать имя набора в сотню вызовов и при любом
	# пропуске оставалась бы голая заливка посреди текстурированной сцены.
	var resolved := pack
	if resolved.is_empty():
		resolved = _pack_for(color)
	if resolved.is_empty() or emission > 0.0:
		# Светящиеся детали всегда идут мимо библиотеки: там важен ровный
		# цвет свечения, а не рисунок камня поверх лампы.
		inst.material_override = _material(color, emission, metallic)
	else:
		inst.material_override = MatLib.get_material(resolved, color)
	inst.visibility_range_end = VISIBILITY_RANGE
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# Trim and fasteners do not earn a slot in the shadow map.
	if size.length() < 0.65:
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	return inst


## Цвет палитры -> набор карт. Сравнение по приближённому равенству, а не по
## словарю: цвета приходят и в виде констант, и в виде их оттенков.
static func _pack_for(color: Color) -> String:
	if color.is_equal_approx(WOOD) or color.is_equal_approx(WOOD_LIGHT):
		return "wood"
	if color.is_equal_approx(STEEL) or color.is_equal_approx(STEEL_DARK):
		return "steel"
	if color.is_equal_approx(BRASS):
		return "painted_metal"
	if color.is_equal_approx(PANEL):
		return "plastic_dry"
	if color.is_equal_approx(STONE):
		return "travertine"
	if color.is_equal_approx(STONE_DARK):
		return "concrete"
	return ""


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
