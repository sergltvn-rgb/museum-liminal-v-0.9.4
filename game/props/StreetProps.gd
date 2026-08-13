@tool
class_name StreetProps
extends RefCounted
## The street, rebuilt to STREET_SCHEME_V2.md.
##
## WHY V2 EXISTS
## The P0 port passed every check and was rejected outright. The reason was
## not taste: P0 moved the carriageway to z 58.0..65.0, but all six segments of
## _drive_track in game/FirstMuseumMap.gd drive down z 57.2, and the shot-4
## camera sits at z 61.6 with the author's comment "static camera on the far
## edge of the road". So the first thirty seconds of the game had the car
## driving down the PAVEMENT and then swerving into the live lane to park.
## Nothing caught it because no test compared the drive track to the street.
##
## V2 puts the carriageway back where the cut-scene was authored -- z 55.5 to
## 62.5, centre 59.0 -- and everything else is derived from that one line.
##
## THE RULE THIS FILE IS BUILT ON
## "Everything that does not serve a real from -> to is not built."
## The museum stands alone: forest starts at z 72, there is no development
## opposite, and there is not one city asset in the project. So there is no far
## pavement, no crossing, and no visitor pocket on the far side -- P0 had all
## of them, and not one connected two places a person could actually be.
##
## CROSS-SECTION, museum side to forest (STREET_SCHEME_V2 section 4)
##   court            +0.055
##   museum pavement  +0.150   z 52.40..55.50   3.10 m   <- the only pavement
##   kerb             +0.150 -> 0.000 at z 55.50
##   carriageway       0.000   z 55.50..62.50   7.00 m   two 3.50 m lanes
##   gravel verge     +0.020   z 62.50..64.60   2.10 m
##   bollard line              z 64.60
##   trees                     z 66.00..72.00
##   existing forest           z 72.00..86.00
## The westbound lane axis lands on z 57.25, which is the cut-scene's z 57.2
## to within 50 mm. That agreement is the entire point of the rebuild.
##
## WHERE THE NUMBERS COME FROM
## tools/lowpoly/blender_street_v2.py builds eight modules and prints their
## measured bounds into street_master_review/street_v2_modules.json. Module
## origins are on the FLOOR and centred in X and Z, so a placement Y is the
## level of the module's underside, not its middle. If a number here disagrees
## with the scheme, the scheme wins and the module is rebuilt; nothing in this
## file is nudged by eye.
##
## HOW LONG EACH RUN IS, AND WHY
##   carriageway  x -80..260   the drive enters at x 236, so the road has to
##                             exist that far out
##   pavement     x -60..40    the museum frontage. East of x 40 the frontage
##                             is the car park, which needs no pavement; west
##                             of x -60 it is forest road
##   verge        x -40..60    the inhabited strip (scheme T01)
##   lamps        x -40..60    one row, museum side, 18 m pitch. Outside that
##                             the road is unlit, because it is a forest road
##                             and should read as one from the car
##
## COLLISION -- WHY THE GROUND IS NOT HULLED
## MapModels.place() derives one convex hull per MeshInstance3D, and that is
## essentially the whole synchronous cost of building the museum. Forty-odd
## flat tiles would pay it forty-odd times to re-describe three rectangles.
## Every flat module therefore has its generated hull stripped and the walkable
## ground is three explicit boxes: exact instead of approximated, and floor
## that still exists if a .glb ever fails to resolve.

# Только через preload: глобальное имя класса в голом --script-прогоне не
# регистрируется, и вся цепочка построения карты падает.
const Models := preload("res://game/MapModels.gd")

# --- Long surface runs, all on the same 20 m tile ----------------------------
const TILE_PITCH := 20.0

const ROAD_FIRST_X := -70.0
const ROAD_TILE_COUNT := 17
const ROAD_Y := -0.200
const ROAD_Z := 59.00

const WALK_FIRST_X := -50.0
const WALK_TILE_COUNT := 5
const WALK_Y := 0.0
const WALK_Z := 53.95

const VERGE_FIRST_X := -30.0
const VERGE_TILE_COUNT := 5
const VERGE_Y := -0.020
const VERGE_Z := 63.55

# --- Lay-bys, cut into the museum-side edge of the carriageway ---------------
# L01 carries the player's car, B01 the bus. Both are flush with the road at
# y 0.000 and 2.5 m deep, so a parked car stands clear of the running lane.
# This is the fix for the P0 defect where DRIVE_CAR_PARKED_POS was z 59.6 --
# the middle of the lane the player had just driven down.
const BAY_PITCH := 2.0
const BAY_Y := -0.040
const BAY_Z := 56.75
# 26 m rather than the scheme's 18: the two visitor cars that used to sit in
# the far-side pockets have nowhere to be now that the pockets are gone, and
# they have to stand WEST of the player's spot at x 8.5 -- the arrival drives
# in from the east down this very strip, and a car parked on the approach
# would be driven straight through during the cut-scene. x -8.50..17.50.
const CAR_BAY_X := 4.5
const CAR_BAY_TILES := 13
const BUS_BAY_X := 26.0
const BUS_BAY_TILES := 7

# --- Furniture ---------------------------------------------------------------
const LAMP_FIRST_X := -40.0
const LAMP_PITCH := 18.0
const LAMP_COUNT := 6
const LAMP_Z := 55.10
# 0.120 sinks the cast foot 30 mm into the +0.150 pavement, so the foot is
# planted rather than sitting on the slab with a shared face.
const LAMP_Y := 0.120
# The imported atlas cannot emit and a dark glass swatch does not illuminate
# anything. These are measured from build_street_lamp's neck endpoint: the
# lantern centre is y 4.020 and z +1.832 in the module's local frame.
const LAMP_GLOW_LOCAL := Vector3(0.0, 4.020, 1.832)
const LAMP_GLOW_SIZE := Vector3(0.22, 0.20, 0.22)
const LAMP_GLOW_COLOR := Color(0.95, 0.78, 0.46)
const LAMP_LIGHT_ENERGY := 6.0
const LAMP_LIGHT_RANGE := 11.0
static var _lamp_glow_material: StandardMaterial3D = null
# The box that stops the player at a lamp: the SHAFT only, foot to head of
# mast, arc and plafond deliberately left open. See _place_lamp for why the
# generated hull cannot be used and why this is 0.30 and not the plinth's
# true 0.440.
const LAMP_MAST_COLLIDER := Vector3(0.30, 3.93, 0.30)

const BOLLARD_FIRST_X := -40.0
const BOLLARD_PITCH := 8.0
const BOLLARD_COUNT := 13
const BOLLARD_Z := 64.60
# The post's own measured footprint, 0.18 x 0.85 x 0.18 (blender_street_v2
# EXPECT_SIZE). Unlike the lamp there is nothing to trim here: the module is a
# plain upright, so the box is the module. See _build_furniture for why the
# posts inside the walkable band now carry one.
const BOLLARD_COLLIDER := Vector3(0.18, 0.85, 0.18)

# The stop moves to the MUSEUM side. In P0 it stood on the far pavement, so
# the only way to reach it was across seven metres of carriageway.
const SHELTER_POS := Vector3(26.0, 0.140, 53.00)

# The car park at (42.4, 46.5) has had no connection to the road for the whole
# project. This is it: a dropped crossing east of where the pavement ends, so
# it breaks no pavement run.
const APRON_POS := Vector3(44.0, -0.030, 54.50)

# BG01. The P0 bridge model is correct as a shape; only its z moves, with the
# carriageway.
const BRIDGE_POS := Vector3(150.0, -0.130, 59.00)

# --- Walkable band -----------------------------------------------------------
# Lot Wall East/West stand at x +-31.5 and are 0.4 m thick, so the reachable
# street is x -31.7..31.7. The floor boxes run to the wall centreline so no
# seam opens under a player brushing the wall (capsule radius 0.35).
const BAND_HALF_X := 31.7


## Build the whole street. Returns the root so the caller can keep placing
## things under it.
static func build_street(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Street V2"
	parent.add_child(root)

	_build_surfaces(root)
	_build_bays(root)
	_build_furniture(root)
	_build_ground_collision(root)
	return root


## R01 carriageway, S01 museum pavement, V01 gravel verge.
static func _build_surfaces(root: Node3D) -> void:
	for i in range(ROAD_TILE_COUNT):
		var x := ROAD_FIRST_X + float(i) * TILE_PITCH
		_place_flat(root, "lp_street_road_20", Vector3(x, ROAD_Y, ROAD_Z))
	for i in range(WALK_TILE_COUNT):
		var x := WALK_FIRST_X + float(i) * TILE_PITCH
		_place_flat(root, "lp_street_walk_20", Vector3(x, WALK_Y, WALK_Z))
	for i in range(VERGE_TILE_COUNT):
		var x := VERGE_FIRST_X + float(i) * TILE_PITCH
		_place_flat(root, "lp_street_verge_20", Vector3(x, VERGE_Y, VERGE_Z))


## L01 and B01, both built from the same 2 m tile.
static func _build_bays(root: Node3D) -> void:
	_place_bay_run(root, CAR_BAY_X, CAR_BAY_TILES)
	_place_bay_run(root, BUS_BAY_X, BUS_BAY_TILES)


static func _place_bay_run(root: Node3D, centre_x: float, tiles: int) -> void:
	var first := centre_x - BAY_PITCH * float(tiles - 1) * 0.5
	for i in range(tiles):
		var x := first + float(i) * BAY_PITCH
		# Yawed 180 so the tile's painted edge line lands on the traffic side at
		# z 57.85 instead of down in the gutter at 55.65. That line is the only
		# thing on the ground that says "this strip is not the running lane".
		_place_flat(root, "lp_street_bay_2", Vector3(x, BAY_Y, BAY_Z), 180.0)


## Lamps, bollards, the stop, the car-park crossover and the bridge.
static func _build_furniture(root: Node3D) -> void:
	for i in range(LAMP_COUNT):
		var x := LAMP_FIRST_X + float(i) * LAMP_PITCH
		_place_lamp(root, x)

	# WHY THESE ARE SOLID NOW (2026-08-13, owner's call to align the rule)
	# The line this replaced said "the verge is set dressing seen from a moving
	# car ... the far side is unreachable anyway". Half of that is wrong, and it
	# is the half that mattered. The verge is NOT the far side: it is z 62.50 to
	# 64.60 on the museum bank, and _build_ground_collision lays a walkable
	# Street Floor Verge across it for the full band, x -31.7..31.7. So a player
	# can stand at the bollard line and walk straight through seven of these
	# posts -- x -24, -16, -8, 0, 8, 16, 24 by BOLLARD_FIRST_X -40 and pitch 8.
	# The same model in the car park was solid the whole time, because
	# FirstMuseumMap._cylinder defaults to with_collision. One post that stops
	# you and an identical post that does not, forty metres apart, is not a
	# trade-off -- it is an accident. Aligned on the honest side.
	#
	# The hull is still discarded and a box put back by hand, exactly as the
	# lamp does: MapModels' convex hull costs a hull per mesh, and a 0.18 m
	# upright deserves a 0.18 m box, not an approximation of one. Posts outside
	# the band keep no body: there is no floor out there to stand on, so a body
	# would guard ground the player can never reach.
	for i in range(BOLLARD_COUNT):
		var x := BOLLARD_FIRST_X + float(i) * BOLLARD_PITCH
		var post := _place_flat(root, "lp_street_bollard",
				Vector3(x, 0.0, BOLLARD_Z))
		if post == null or absf(x) > BAND_HALF_X:
			continue
		_upright_box(post, "Bollard Post", BOLLARD_COLLIDER)

	# The shelter keeps its hull deliberately. MapModels derives ONE convex
	# hull per mesh, so the pavilion is a solid mass rather than a room you can
	# step into -- which is the right trade here: the player's route is the
	# pavement to the door, the stop is something to walk around, and a
	# walk-through pavilion reads far worse than a solid one. It leaves 1.46 m
	# of clear pavement between its roof edge and the kerb.
	_place_solid(root, "lp_street_shelter", SHELTER_POS, 0.0)

	_place_flat(root, "lp_street_drive_apron", APRON_POS)
	_place_flat(root, "lp_street_bridge", BRIDGE_POS)


## The lamp is the one piece of street furniture whose generated hull lies.
##
## MapModels derives ONE convex hull per mesh, and the remade lamp's neck
## reaches 1.832 m over the carriageway -- glass at z 56.93 against the lane
## axis 57.25, which is the whole point of the remake. A hull of that mesh is
## therefore a WEDGE from the cast foot up to the plafond, and the air under
## the arc becomes solid: at 1.8 m, head height, the invisible face stands at
## about z 56.1, which is 0.6 m past the kerb and inside the running lane.
## (Computed from the hull, not measured in engine.)
##
## Nobody walks out there, which is why this was never a visible bug. It would
## become one two steps from here: B puts visitor cars and C the player's car
## on that z 57.25 axis, and a 1.5 m-tall body centred on the lane clears the
## wedge by only ~0.3 m. Cheaper to be honest now than to debug a car catching
## on nothing later.
##
## So the hull goes and the mast alone carries a box. 0.30 across rather than
## the plinth's true 0.440: the player capsule is r 0.35, so it can never bring
## its surface within 0.50 m of the axis and the plinth at 0.22 m is
## unreachable either way -- while a 0.44 box would hold a player 0.57 m off an
## 0.085 m shaft, which is the same invisible-fat complaint in a smaller size.
## 3.93 m is the top of the shaft, so the arc overhead stops nothing and a
## player can walk right under it.
##
## Node counts are unchanged BY DESIGN: _place_flat frees the body MapModels
## attached and this puts exactly one back, one StaticBody3D with one
## CollisionShape3D. Only the three lamps inside the walkable band get it --
## x -40, 32 and 50 are outside BAND_HALF_X 31.7, so half the row never had
## collision and still has none.
static func _place_lamp(root: Node3D, x: float) -> void:
	var pos := Vector3(x, LAMP_Y, LAMP_Z)
	var node := _place_flat(root, "lp_street_lamp", pos)
	if node == null:
		return
	_add_street_lamp_light(node)
	if absf(x) <= BAND_HALF_X:
		_upright_box(node, "Lamp Mast", LAMP_MAST_COLLIDER)


## One small emissive bulb inside the authored glass and one real downward
## light. The mesh makes the source itself readable; the SpotLight3D is what
## finally paints the pavement and carriageway. Keeping the light shadowless
## avoids six extra shadow maps for fixtures whose iron shell already provides
## the silhouette.
static func _add_street_lamp_light(node: Node3D) -> void:
	var bulb_mesh := BoxMesh.new()
	bulb_mesh.size = LAMP_GLOW_SIZE
	var bulb := MeshInstance3D.new()
	bulb.name = "Street Lamp Glow"
	bulb.position = LAMP_GLOW_LOCAL
	bulb.mesh = bulb_mesh
	bulb.material_override = _street_lamp_glow_material()
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(bulb)

	var light := SpotLight3D.new()
	light.name = "Street Lamp Light"
	light.position = LAMP_GLOW_LOCAL + Vector3(0.0, -0.05, 0.0)
	light.rotation_degrees.x = -90.0
	light.light_color = LAMP_GLOW_COLOR
	light.light_energy = LAMP_LIGHT_ENERGY
	light.spot_range = LAMP_LIGHT_RANGE
	light.spot_angle = 68.0
	light.shadow_enabled = false
	node.add_child(light)


static func _street_lamp_glow_material() -> StandardMaterial3D:
	if _lamp_glow_material != null:
		return _lamp_glow_material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = LAMP_GLOW_COLOR
	mat.roughness = 0.34
	mat.emission_enabled = true
	mat.emission = LAMP_GLOW_COLOR
	mat.emission_energy_multiplier = 3.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_lamp_glow_material = mat
	return mat


## One upright box standing on a placed module's own floor origin, parented to
## the instance so it inherits that placement's position and yaw and needs no
## world-space arithmetic. Built by hand rather than through _ground_box
## because this one needs no BoxMesh: the module itself is the visible thing,
## and no test looks for a slab here.
##
## Named _upright_box rather than _mast_box since 2026-08-13: the bollard row
## uses it too, and a helper called "mast" that also fences posts is a comment
## that lies. Callers pass their own node_name, so the collider reads as
## "Lamp Mast Collision" or "Bollard Post Collision" in the tree.
static func _upright_box(node: Node3D, node_name: String, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "%s Collision" % node_name
	body.position = Vector3(0.0, size.y * 0.5, 0.0)
	node.add_child(body)

	var shape := BoxShape3D.new()
	shape.size = size

	var collision := CollisionShape3D.new()
	collision.name = "%s CollisionShape" % node_name
	collision.shape = shape
	body.add_child(collision)


## The walkable floor: three boxes, invisible, covering the street inside the
## perimeter walls. GroundsProps' "Forecourt Ground" carries z 35..55, so these
## pick up at the pavement and run to the bollard line.
static func _build_ground_collision(root: Node3D) -> void:
	# S01 museum pavement, top +0.150, z 52.40..55.50.
	_ground_box(root, "Street Floor Pavement",
		Vector3(0.0, 0.075, WALK_Z), Vector3(BAND_HALF_X * 2.0, 0.15, 3.10))
	# R01 carriageway including both lay-bys, top 0.000, z 55.50..62.50.
	_ground_box(root, "Street Floor Carriageway",
		Vector3(0.0, -0.10, ROAD_Z), Vector3(BAND_HALF_X * 2.0, 0.20, 7.00))
	# V01 gravel verge, top +0.020, z 62.50..64.60.
	_ground_box(root, "Street Floor Verge",
		Vector3(0.0, 0.0, VERGE_Z), Vector3(BAND_HALF_X * 2.0, 0.04, 2.10))


## A box slab that carries a collider, drawn by nobody.
##
## The mesh is deliberately hidden: the .glb tiles are the visible surface and
## a slab in the same millimetres would z-fight them. But it has to BE a
## MeshInstance3D with a real BoxMesh rather than a bare body, because
## test_map_verification's arrival check looks for a box slab whose footprint
## covers DRIVE_EXIT_POS and which carries a StaticBody3D descendant. Floor
## that exists only as a collision shape is invisible to that check in both
## senses of the word, and the player would be reported as stepping out into
## thin air on ground they can actually stand on.
static func _ground_box(root: Node3D, node_name: String, centre: Vector3,
		size: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size

	var slab := MeshInstance3D.new()
	slab.name = node_name
	slab.mesh = mesh
	slab.position = centre
	slab.visible = false
	root.add_child(slab)

	var shape := BoxShape3D.new()
	shape.size = size

	var body := StaticBody3D.new()
	body.name = "%s Collision" % node_name
	slab.add_child(body)

	var collision := CollisionShape3D.new()
	collision.name = "%s CollisionShape" % node_name
	collision.shape = shape
	body.add_child(collision)


## Flat ground module: placed for its looks, its generated hull discarded.
static func _place_flat(root: Node3D, model: String, pos: Vector3,
		yaw := 0.0) -> Node3D:
	var node := Models.place(root, model, pos, 1.0, yaw)
	if node == null:
		push_warning("StreetProps: %s did not resolve; run Godot --headless --import after exporting" % model)
		return null
	_strip_collision(node)
	return node


## Module that keeps whatever collision MapModels generated for it.
static func _place_solid(root: Node3D, model: String, pos: Vector3,
		yaw: float) -> Node3D:
	var node := Models.place(root, model, pos, 1.0, yaw)
	if node == null:
		push_warning("StreetProps: %s did not resolve; run Godot --headless --import after exporting" % model)
	return node


## Remove the bodies MapModels._ensure_collisions() attached. Children are
## collected before anything is freed: freeing while iterating get_children()
## skips siblings. free() rather than queue_free() so the node is gone before
## the verification pass counts anything.
static func _strip_collision(node: Node) -> void:
	var bodies: Array[Node] = []
	_find_bodies(node, bodies)
	for body in bodies:
		body.get_parent().remove_child(body)
		body.free()


static func _find_bodies(node: Node, out: Array[Node]) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			out.append(child)
		else:
			_find_bodies(child, out)
