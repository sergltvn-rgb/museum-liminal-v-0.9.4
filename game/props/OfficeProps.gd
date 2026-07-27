@tool
class_name OfficeProps
extends RefCounted
## Procedural furniture for the Watcher Office — the player's home base.
##
## The museum has no authored 3D content: scenes/FirstMuseumMap.tscn is empty and
## build_map() constructs the whole building from primitives at runtime. This file
## follows that decision for the one room the player spends the night in.
##
## SELF-CONTAINED BY DESIGN. Nothing here preloads, references or extends another
## project script. It is pure geometry: primitives, StandardMaterial3D, and a
## static material cache. It can be called from a @tool script in the editor or
## from a headless test without pulling the rest of the game into the load order.
##
## ---------------------------------------------------------------------------
## LOCAL FRAMES
## ---------------------------------------------------------------------------
## Every builder takes (parent, origin, ..., yaw_deg) and returns the Node3D it
## added, so the map places a prop in one line. Children are authored in the
## root's LOCAL space, which means:
##
##   * y = 0 is always the floor (or, for desktop props, the surface they stand
##     on — pass DESK_TOP_Y in the y of `origin`);
##   * +Z always points INTO THE ROOM. For a wall prop, z = 0 is the wall face;
##     for the desk and the chair, +Z is the side the operator sits on. Placing
##     a prop against a wall is therefore one `yaw_deg`: 0 for a wall the room
##     is north of, 180 for the opposite one, ±90 for the side walls;
##   * x = 0 is the horizontal centre of the prop's footprint.
##
## Because the roots are ordinary Node3Ds, props compose: build_draped_cardigan()
## is called with the chair's returned root as `parent` and inherits its yaw.
##
## ---------------------------------------------------------------------------
## COLLISION AND NAVIGATION — read before adding anything
## ---------------------------------------------------------------------------
## FirstMuseumMap bakes its navmesh from PARSED_GEOMETRY_STATIC_COLLIDERS with
## agent_radius 0.45 and cell_size 0.15. A collider therefore does not merely
## stop the player, it erodes 0.45 m of Curator navmesh on every side. So the
## one deliberate divergence from FirstMuseumMap._primitive() is that NOTHING in
## this file gets an implicit body: _primitive() here never builds a StaticBody3D
## and there is no `collision_worthy` size threshold. Blocking volumes are
## declared by hand with _collider(), one consolidated box per prop, and only
## four builders create one at all:
##
##   build_monitor_bank    bank_width x bank_height x 0.15, hugging the wall
##   build_desk            width x 0.74 x 0.72
##   build_swivel_chair    0.56 x 1.02 x 0.56
##   build_dead_plant      0.42 x 0.30 x 0.42
##
## Add 0.90 m to each footprint dimension to get the hole it punches in the
## navmesh. DOOR_GAP in the map is 1.8 m, so the desk (0.72 deep -> 1.62 m of
## erosion) must never sit in or beside a doorway, and the chair and the plant
## must keep 1.4 m of clearance from one. Paper, tags, cables, the key cabinet
## and everything on a desktop are collision-free on purpose.
##
## ---------------------------------------------------------------------------
## SCALE
## ---------------------------------------------------------------------------
## Rooms are 3.4 m tall. Every prop here is built to real furniture dimensions —
## desk surface 0.74 m, seat 0.50 m, monitor bank topping out at 2.02 m — and
## the tallest thing this file can produce is the roster board at 2.38 m. Each
## builder's doc comment states its bounding box.
##
## Note for the integrator: the office geometry currently inline in
## FirstMuseumMap._add_office_details() puts its desktops at y 1.09, which is bar
## height, and its "monitors" are 1.92 m wide. Those two numbers are why the room
## reads wrong. Nothing here is above 0.74 for a work surface.
##
## ---------------------------------------------------------------------------
## ACCESSIBILITY
## ---------------------------------------------------------------------------
## This file produces STATIC GEOMETRY ONLY — no Tween, no AnimationPlayer, no
## _process, no shader time. There is consequently nothing for
## SettingsManager.reduced_flashes to switch off, and no hook is needed. The dead
## monitor is distinguished from the live ones by darkness AND by a 3 degree tilt
## in its housing, and the cancelled roster column by a drawn cross as well as by
## its colour, so no state in the room is carried by hue alone.
##
## ---------------------------------------------------------------------------
## STRINGS
## ---------------------------------------------------------------------------
## There is not one player-visible string literal in this file. The two builders
## that can carry signage take a `label_text` argument defaulting to "" (no
## label), so the caller supplies tr("KEY"). Keys and both column texts are in
## the handoff.

# --- Surfaces the caller needs to know about --------------------------------

## Height of the desk's work surface. Pass `origin.y = DESK_TOP_Y` (plus the
## desk's own origin.y) when placing a kettle, a mug ring or anything else that
## stands on it.
const DESK_TOP_Y := 0.74

## Height of the seat pan, for anything that has to rest on the chair.
const SEAT_TOP_Y := 0.50

## Local offset of the backrest's top edge inside build_swivel_chair()'s root.
## build_draped_cardigan() expects exactly this point as its origin.
const CHAIR_BACK_TOP := Vector3(0.0, 1.03, -0.245)

# --- Palette ----------------------------------------------------------------
# Institutional greys with a cold cast, one dead-plant brown and exactly one
# warm colour (the cardigan) so the personal detail reads at a glance.

const COL_STEEL := Color(0.105, 0.115, 0.125)
const COL_SHELL := Color(0.062, 0.070, 0.078)
const COL_DARK := Color(0.035, 0.040, 0.046)
const COL_DESK := Color(0.155, 0.130, 0.100)
const COL_LAMINATE := Color(0.105, 0.112, 0.108)
const COL_PAPER := Color(0.700, 0.680, 0.600)
const COL_PAPER_AGED := Color(0.540, 0.505, 0.420)
const COL_INK := Color(0.160, 0.150, 0.140)
const COL_SCREEN := Color(0.055, 0.085, 0.090)
const COL_SCREEN_DEAD := Color(0.018, 0.020, 0.024)
const COL_SCREEN_GLARE := Color(0.420, 0.450, 0.440)
const COL_LED := Color(0.850, 0.100, 0.070)
const COL_LED_AMBER := Color(0.900, 0.560, 0.120)
const COL_PLASTIC := Color(0.560, 0.545, 0.480)
const COL_SOIL := Color(0.120, 0.098, 0.078)
const COL_DEAD_LEAF := Color(0.215, 0.180, 0.120)
const COL_WOOL := Color(0.300, 0.220, 0.180)
const COL_STAIN := Color(0.130, 0.075, 0.045, 0.720)
const COL_CANCELLED := Color(0.420, 0.100, 0.090)

# --- Static caches ----------------------------------------------------------
# The map already builds ~1270 MeshInstance3D nodes in a single frame. Materials
# are shared across every prop and across every call, so a fully dressed office
# costs a couple of dozen StandardMaterial3D and two 128px noise textures.

static var _materials: Dictionary = {}
static var _roughness_noise: NoiseTexture2D = null
static var _normal_noise: NoiseTexture2D = null


# ===========================================================================
# Primitive layer
# ===========================================================================
# Signatures mirror FirstMuseumMap's _box/_cylinder/_sphere/_prism/_torus/_cone
# so a reader moving between the two files is never surprised. The single
# difference is the missing `with_collision` argument: see the header.


## Root node every builder returns. Named, positioned and yawed before its
## children are authored, so all child coordinates are local.
static func _root(parent: Node3D, node_name: String, origin: Vector3,
		yaw_deg: float) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = origin
	root.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(root)
	return root


static func _box(parent: Node3D, node_name: String, box_position: Vector3,
		size: Vector3, color: Color, emission_energy := 0.0,
		metallic := 0.0, transparent := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _primitive(parent, node_name, box_position, mesh, size, color,
		transparent, emission_energy, metallic)


static func _cylinder(parent: Node3D, node_name: String,
		cylinder_position: Vector3, radius: float, height: float, color: Color,
		emission_energy := 0.0, metallic := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = radius
	mesh.top_radius = radius
	# Office props are small and read in silhouette; the default 64 radial
	# segments is pure waste on a 0.03 m caster.
	mesh.radial_segments = 10 if radius < 0.08 else 16
	mesh.rings = 1
	return _primitive(parent, node_name, cylinder_position, mesh,
		Vector3(radius * 2.0, height, radius * 2.0), color, false,
		emission_energy, metallic)


static func _cone(parent: Node3D, node_name: String, cone_position: Vector3,
		bottom_radius: float, top_radius: float, height: float, color: Color,
		emission_energy := 0.0, metallic := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.radial_segments = 16
	mesh.rings = 1
	var max_radius: float = maxf(bottom_radius, top_radius)
	return _primitive(parent, node_name, cone_position, mesh,
		Vector3(max_radius * 2.0, height, max_radius * 2.0), color, false,
		emission_energy, metallic)


static func _sphere(parent: Node3D, node_name: String, sphere_position: Vector3,
		radius: float, color: Color, emission_energy := 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	return _primitive(parent, node_name, sphere_position, mesh,
		Vector3(radius * 2.0, radius * 2.0, radius * 2.0), color, false,
		emission_energy, 0.0)


static func _prism(parent: Node3D, node_name: String, prism_position: Vector3,
		size: Vector3, color: Color, emission_energy := 0.0) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _primitive(parent, node_name, prism_position, mesh, size, color,
		false, emission_energy, 0.0)


## TorusMesh lies flat in the XZ plane by default, which is what a stain or a
## desk grommet wants; `upright` stands it up the way FirstMuseumMap._torus does.
static func _torus(parent: Node3D, node_name: String, torus_position: Vector3,
		inner_radius: float, outer_radius: float, color: Color,
		upright := false, transparent := false) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 18
	mesh.ring_segments = 6
	var thickness := outer_radius - inner_radius
	var inst := _primitive(parent, node_name, torus_position, mesh,
		Vector3(outer_radius * 2.0, thickness, outer_radius * 2.0), color,
		transparent, 0.0, 0.0)
	if upright:
		inst.rotate_x(deg_to_rad(90))
	return inst


static func _primitive(parent: Node3D, node_name: String,
		prim_position: Vector3, mesh: PrimitiveMesh, size: Vector3,
		color: Color, transparent: bool, emission_energy: float,
		metallic: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = prim_position
	instance.mesh = mesh
	instance.material_override = _material(color, transparent, emission_energy,
		metallic)
	# Same culling policy as the rest of the museum.
	instance.visibility_range_end = 115.0
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if size.length() < 0.65:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## The only source of physics bodies in this file. One box per prop, sized to
## what the player can actually walk into -- never to the prop's full extent.
static func _collider(parent: Node3D, node_name: String, box_position: Vector3,
		size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "%s Collision" % node_name
	body.position = box_position
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "%s CollisionShape" % node_name
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body


static func _material(color: Color, transparent: bool,
		emission_energy: float, metallic: float) -> StandardMaterial3D:
	var key := "%s:%s:%s:%s" % [color.to_html(true), transparent,
		emission_energy, metallic]
	if _materials.has(key):
		return _materials[key]

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = clampf(0.62 - metallic * 0.4, 0.12, 1.0)
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

	# Matches the museum's restrained surface detail: enough grain that painted
	# steel is not a flat swatch, not so much that it turns into television
	# static.
	if not transparent and metallic < 0.35 and emission_energy <= 0.0:
		mat.roughness_texture = _shared_roughness_noise()
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.normal_enabled = true
		mat.normal_texture = _shared_normal_noise()
		mat.normal_scale = 0.08
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_materials[key] = mat
	return mat


static func _shared_roughness_noise() -> NoiseTexture2D:
	if _roughness_noise != null:
		return _roughness_noise
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.16
	noise.fractal_octaves = 2
	_roughness_noise = NoiseTexture2D.new()
	_roughness_noise.width = 128
	_roughness_noise.height = 128
	_roughness_noise.noise = noise
	_roughness_noise.seamless = true
	return _roughness_noise


static func _shared_normal_noise() -> NoiseTexture2D:
	if _normal_noise != null:
		return _normal_noise
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.12
	noise.fractal_octaves = 2
	_normal_noise = NoiseTexture2D.new()
	_normal_noise.width = 128
	_normal_noise.height = 128
	_normal_noise.noise = noise
	_normal_noise.seamless = true
	_normal_noise.as_normal_map = true
	_normal_noise.bump_strength = 1.2
	return _normal_noise


## Orthonormal right-handed basis whose +Y is `up`. Aims cylinders that are
## neither vertical nor axis-aligned (plant stems, cable slack).
static func _aim(up: Vector3) -> Basis:
	var y_axis := up.normalized()
	var reference := Vector3.RIGHT if absf(y_axis.x) < 0.9 else Vector3.FORWARD
	var x_axis := reference.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, x_axis.cross(y_axis))


## Deterministic pseudo-random in [0, 1). The office must look identical every
## time the map is built: it is a landmark and the player memorises it.
static func _jitter(n: float) -> float:
	var v := sin(n * 78.233 + 12.9898) * 43758.5453
	return v - floorf(v)


## Signage plate plus flat, non-billboarded text. The text sits on its own dark
## plate so contrast holds whatever the wall behind it is: luminance ratio of
## the pair is 14.1:1, well past the 4.5:1 floor. No-ops on empty text.
static func _label_plate(parent: Node3D, node_name: String, text: String,
		plate_position: Vector3, plate_size: Vector2) -> void:
	if text.strip_edges() == "":
		return
	_box(parent, "%s Plate" % node_name, plate_position,
		Vector3(plate_size.x, plate_size.y, 0.008), COL_SHELL)
	var label := Label3D.new()
	label.name = node_name
	label.text = text
	label.position = plate_position + Vector3(0, 0, 0.007)
	label.modulate = Color(0.86, 0.88, 0.86)
	label.font_size = 40
	label.pixel_size = 0.0013
	# Flat against the plate. A billboarded label would swivel to face Camera 04
	# and turn the office feed into a fan of floating text.
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.outline_size = 6
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	label.width = plate_size.x / 0.0013
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.visibility_range_end = 24.0
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(label)


# ===========================================================================
# The monitor bank
# ===========================================================================

const MONITOR_W := 0.52
const MONITOR_H := 0.40
const MONITOR_PITCH_X := 0.58
const MONITOR_PITCH_Y := 0.46
## Centre height of the bottom row. A seated operator's eye is around 1.20 m, so
## the grid starts just above the sightline and is read by looking slightly up.
const MONITOR_ROW0_Y := 1.28


## Wall-mounted CCTV grid on a unistrut rail: `columns` x `rows` framed panels,
## a cable trough beneath and slack loops hanging out of it.
##
## Local frame: z = 0 is the wall face, +Z into the room, x = 0 the centre.
##
## Bounding box at the default 3x2 — 1.79 W x 1.37 H x 0.15 D, occupying local
## y 0.650 (bottom of the hanging cable slack) to 2.020 (top of the end posts).
## The monitor grid itself spans y 1.08 to 1.94, and the slack hangs in the
## 0.12 m gap between the wall and the back of the desk, not through it.
## General case:
##   width  = columns * 0.58 + 0.05
##   height = (rows - 1) * 0.46 + 1.37
## A 4x3 bank measures 2.37 x 1.83 x 0.15 and tops out at 2.48 — still 0.9 m
## below the 3.4 m ceiling.
##
## Horror note: one panel is dead. It is distinguished by darkness AND by a
## three-degree tilt in its housing, never by colour alone, and the negative
## space it leaves in the grid is the point of the prop.
static func build_monitor_bank(parent: Node3D, origin: Vector3, columns := 3,
		rows := 2, yaw_deg := 0.0, with_collision := true) -> Node3D:
	columns = maxi(1, columns)
	rows = maxi(1, rows)
	var root := _root(parent, "Monitor Bank", origin, yaw_deg)

	var bank_w := float(columns) * MONITOR_PITCH_X
	var bottom_y := MONITOR_ROW0_Y - MONITOR_H * 0.5
	var top_y := MONITOR_ROW0_Y + float(rows - 1) * MONITOR_PITCH_Y \
		+ MONITOR_H * 0.5
	var mid_y := (bottom_y + top_y) * 0.5
	var frame_h := top_y - bottom_y + 0.14

	# Unistrut: two horizontal rails and two end posts. Everything else hangs
	# off this, so the bank reads as installed rather than glued to the wall.
	for rail_y in [bottom_y - 0.05, top_y + 0.05]:
		_box(root, "Monitor Rail", Vector3(0, rail_y, 0.025),
			Vector3(bank_w, 0.06, 0.05), COL_STEEL, 0.0, 0.55)
	for side in [-1.0, 1.0]:
		_box(root, "Monitor Rail Post", Vector3(side * bank_w * 0.5, mid_y, 0.025),
			Vector3(0.05, frame_h, 0.05), COL_STEEL, 0.0, 0.55)

	var panels := columns * rows
	# Deterministic, not random: the same panel is dead on every playthrough.
	var dead_index: int = 2 if panels > 3 else -1
	var glare_index: int = panels - 2

	for row in range(rows):
		for col in range(columns):
			var idx := row * columns + col
			var mx := (float(col) - float(columns - 1) * 0.5) * MONITOR_PITCH_X
			var my := MONITOR_ROW0_Y + float(row) * MONITOR_PITCH_Y
			_box(root, "Monitor Arm %d" % idx, Vector3(mx, my, 0.03),
				Vector3(0.07, 0.07, 0.06), COL_STEEL, 0.0, 0.5)
			var housing := _box(root, "Monitor Housing %d" % idx,
				Vector3(mx, my, 0.098), Vector3(MONITOR_W, MONITOR_H, 0.075),
				COL_SHELL, 0.0, 0.25)

			if idx == dead_index:
				# Knocked out of true. Reads as broken from across the room,
				# with no reliance on the screen's colour.
				housing.rotation_degrees = Vector3(0, 0, 3.0)
				_box(root, "Monitor Screen %d" % idx, Vector3(mx, my, 0.139),
					Vector3(0.46, 0.32, 0.006), COL_SCREEN_DEAD)
				continue

			if idx == glare_index:
				# Blown out: an empty corridor lighting the room. No overlay,
				# because there is nothing on it to read.
				_box(root, "Monitor Screen %d" % idx, Vector3(mx, my, 0.139),
					Vector3(0.46, 0.32, 0.006), COL_SCREEN_GLARE, 0.85)
			else:
				_box(root, "Monitor Screen %d" % idx, Vector3(mx, my, 0.139),
					Vector3(0.46, 0.32, 0.006), COL_SCREEN, 0.30)
				# Timestamp strip along the bottom of the picture.
				_box(root, "Monitor Overlay %d" % idx,
					Vector3(mx - 0.12, my - 0.13, 0.143),
					Vector3(0.18, 0.014, 0.004), COL_SCREEN_GLARE, 0.55)

			_box(root, "Monitor Tally %d" % idx,
				Vector3(mx + 0.225, my - 0.172, 0.140),
				Vector3(0.016, 0.016, 0.008), COL_LED, 1.5)

	# Cable management under the grid, and the slack nobody ever dressed in.
	var trough_y := bottom_y - 0.16
	_box(root, "Monitor Cable Trough", Vector3(0, trough_y, 0.05),
		Vector3(bank_w, 0.08, 0.09), COL_SHELL, 0.0, 0.4)
	for i in range(2):
		var slack_x := (float(i) - 0.5) * bank_w * 0.42
		var dir := Vector3(0.34 if i == 0 else -0.34, -1.0, 0.16).normalized()
		var slack := _cylinder(root, "Monitor Cable Slack %d" % i,
			Vector3.ZERO, 0.012, 0.24, COL_DARK)
		slack.transform = Transform3D(_aim(dir),
			Vector3(slack_x, trough_y - 0.04, 0.05) + dir * 0.12)

	if with_collision:
		# One box for the whole installation. 0.15 deep against the wall, so it
		# costs 0.60 m of navmesh measured out from that wall -- fine along a
		# room edge, never acceptable within 1.4 m of a doorway.
		_collider(root, "Monitor Bank", Vector3(0, mid_y, 0.075),
			Vector3(bank_w + 0.05, frame_h, 0.15))
	return root


# ===========================================================================
# The desk
# ===========================================================================

## Operator desk with a modesty panel, a drawer pedestal, a cable grommet and
## the tablet dock. Work surface at DESK_TOP_Y (0.74) — real desk height, not
## the 1.09 m the room is dressed with today.
##
## Local frame: origin on the floor at the centre of the footprint, +Z the side
## the operator sits on, so the monitor wall is at -Z.
##
## Bounding box at the default width — 2.40 W x 0.91 H x 0.72 D. The 0.91 is the
## tablet dock's cradle; the desktop itself is at 0.74. Width is clamped to a
## 1.20 m minimum so the pedestal and the dock cannot overlap.
static func build_desk(parent: Node3D, origin: Vector3, width := 2.4,
		yaw_deg := 0.0, with_collision := true) -> Node3D:
	width = maxf(1.2, width)
	var root := _root(parent, "Operator Desk", origin, yaw_deg)
	var half := width * 0.5

	_box(root, "Desk Top", Vector3(0, DESK_TOP_Y - 0.02, 0),
		Vector3(width, 0.04, 0.72), COL_DESK, 0.0, 0.1)
	_box(root, "Desk Modesty Panel", Vector3(0, 0.45, -0.30),
		Vector3(width - 0.20, 0.42, 0.03), COL_LAMINATE, 0.0, 0.2)
	_box(root, "Desk Foot Rail", Vector3(0, 0.09, -0.28),
		Vector3(width - 0.20, 0.04, 0.04), COL_STEEL, 0.0, 0.55)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(root, "Desk Leg", Vector3(sx * (half - 0.07), 0.35, sz * 0.28),
				Vector3(0.06, 0.70, 0.06), COL_STEEL, 0.0, 0.6)

	# Drawer pedestal on the left, so the dock has the right end to itself.
	var ped_x := -(half - 0.30)
	_box(root, "Desk Pedestal", Vector3(ped_x, 0.30, 0.0),
		Vector3(0.44, 0.60, 0.56), COL_LAMINATE, 0.0, 0.35)
	for i in range(3):
		_box(root, "Desk Drawer %d" % i,
			Vector3(ped_x, 0.13 + float(i) * 0.19, 0.285),
			Vector3(0.40, 0.15, 0.012), COL_SHELL, 0.0, 0.3)
		_box(root, "Desk Drawer Pull %d" % i,
			Vector3(ped_x, 0.13 + float(i) * 0.19, 0.295),
			Vector3(0.14, 0.016, 0.012), COL_STEEL, 0.0, 0.65)

	# Cable grommet: a flattened ring set into the desktop behind the keyboard.
	var grommet := _torus(root, "Desk Grommet",
		Vector3(half - 0.90, DESK_TOP_Y + 0.002, -0.24), 0.036, 0.050, COL_DARK)
	grommet.scale = Vector3(1.0, 0.25, 1.0)

	_build_tablet_dock(root, Vector3(half - 0.42, DESK_TOP_Y, -0.13))

	# Working surface: keyboard, mouse, the open shift ledger and a pen.
	_box(root, "Desk Keyboard", Vector3(-0.14, DESK_TOP_Y + 0.011, 0.14),
		Vector3(0.44, 0.022, 0.15), COL_DARK, 0.0, 0.1)
	_box(root, "Desk Mouse", Vector3(0.19, DESK_TOP_Y + 0.013, 0.15),
		Vector3(0.06, 0.026, 0.10), COL_DARK, 0.0, 0.1)
	for side in [-1.0, 1.0]:
		var page := _box(root, "Shift Ledger Page",
			Vector3(ped_x + 0.42 + side * 0.105, DESK_TOP_Y + 0.005, 0.02),
			Vector3(0.21, 0.006, 0.29), COL_PAPER)
		page.rotation_degrees = Vector3(0, 0, side * 1.6)
	_box(root, "Shift Ledger Spine", Vector3(ped_x + 0.42, DESK_TOP_Y + 0.008, 0.02),
		Vector3(0.018, 0.010, 0.29), COL_INK)
	var pen := _cylinder(root, "Desk Pen",
		Vector3(ped_x + 0.42, DESK_TOP_Y + 0.017, 0.19), 0.006, 0.14, COL_DARK)
	pen.rotation_degrees = Vector3(0, 0, 90)

	if with_collision:
		# Knee space is deliberately solid: the player must not stand inside the
		# desk. 2.40 x 0.72 costs 3.30 x 1.62 m of navmesh, so keep the desk
		# against the monitor wall and well clear of both office doorways.
		_collider(root, "Operator Desk", Vector3(0, DESK_TOP_Y * 0.5, 0),
			Vector3(width, DESK_TOP_Y, 0.72))
	return root


## Charging cradle for the camera tablet: a base plate, a spine leaning back
## 20 degrees, two retaining lips and the contact pins. Local origin is the desk
## surface; the cradle tops out 0.17 above it.
static func _build_tablet_dock(parent: Node3D, dock_origin: Vector3) -> void:
	var dock := _root(parent, "Tablet Dock", dock_origin, 0.0)
	_box(dock, "Dock Base", Vector3(0, 0.014, 0), Vector3(0.26, 0.028, 0.18),
		COL_SHELL, 0.0, 0.4)
	var spine := _box(dock, "Dock Spine", Vector3(0, 0.098, -0.106),
		Vector3(0.26, 0.15, 0.022), COL_SHELL, 0.0, 0.4)
	spine.rotation_degrees = Vector3(-20, 0, 0)
	for side in [-1.0, 1.0]:
		_box(dock, "Dock Lip", Vector3(side * 0.125, 0.043, 0.0),
			Vector3(0.018, 0.030, 0.15), COL_STEEL, 0.0, 0.6)
	for side in [-1.0, 1.0]:
		_box(dock, "Dock Contact", Vector3(side * 0.045, 0.031, -0.04),
			Vector3(0.022, 0.006, 0.012), COL_LED_AMBER, 1.2)


# ===========================================================================
# The chair
# ===========================================================================

## Five-star task chair: base, casters, gas column, seat, mid-height back and
## armrests. Seat pan tops out at SEAT_TOP_Y (0.50), backrest at 1.03 — a
## mid-back office chair, not a throne.
##
## Local frame: origin on the floor under the column, +Z the direction the seat
## faces. Turning the chair away from the desk is one `yaw_deg`, and that is the
## cheapest unease this room has: an empty chair facing the wrong way.
##
## Bounding box — 0.62 W x 1.04 H x 0.64 D, local y 0.003 to 1.038 (the caster
## circle governs the plan; the armrests are only 0.58 across).
static func build_swivel_chair(parent: Node3D, origin: Vector3, yaw_deg := 0.0,
		with_collision := true) -> Node3D:
	var root := _root(parent, "Swivel Chair", origin, yaw_deg)

	# Base: hub, five spokes, five casters.
	_cylinder(root, "Chair Hub", Vector3(0, 0.075, 0), 0.05, 0.07, COL_STEEL,
		0.0, 0.6)
	for i in range(5):
		var a := TAU * float(i) / 5.0
		var spoke := _box(root, "Chair Spoke %d" % i,
			Vector3(cos(a) * 0.16, 0.065, sin(a) * 0.16),
			Vector3(0.30, 0.035, 0.055), COL_STEEL, 0.0, 0.6)
		spoke.rotation.y = -a
		# The wheel rolls along the spoke, so its axle is tangential. Composing
		# a yaw with rotate_z() instead pointed every axle at -X, which put
		# three of the five wheels on edge.
		var caster := _cylinder(root, "Chair Caster %d" % i, Vector3.ZERO,
			0.028, 0.028, COL_DARK)
		caster.transform = Transform3D(_aim(Vector3(-sin(a), 0, cos(a))),
			Vector3(cos(a) * 0.30, 0.030, sin(a) * 0.30))

	# Gas column and its sleeve.
	_cylinder(root, "Chair Column", Vector3(0, 0.24, 0), 0.035, 0.30, COL_STEEL,
		0.0, 0.65)
	_cylinder(root, "Chair Column Sleeve", Vector3(0, 0.17, 0), 0.052, 0.14,
		COL_SHELL, 0.0, 0.35)
	_box(root, "Chair Mechanism", Vector3(0, 0.37, 0),
		Vector3(0.16, 0.08, 0.22), COL_SHELL, 0.0, 0.4)
	var lever := _cylinder(root, "Chair Tilt Lever", Vector3(0.15, 0.37, 0.05),
		0.012, 0.16, COL_DARK)
	lever.rotation_degrees = Vector3(0, 0, 78)

	# Seat: a pan with a softer overhanging cushion.
	_box(root, "Chair Seat Pan", Vector3(0, 0.455, 0),
		Vector3(0.46, 0.09, 0.44), COL_SHELL, 0.0, 0.15)
	_box(root, "Chair Seat Cushion", Vector3(0, 0.425, 0.01),
		Vector3(0.48, 0.05, 0.46), COL_DARK, 0.0, 0.05)

	# Backrest, leaning back 10 degrees off vertical.
	_box(root, "Chair Back Stem", Vector3(0, 0.50, -0.22),
		Vector3(0.07, 0.20, 0.07), COL_STEEL, 0.0, 0.6)
	var back := _box(root, "Chair Back", Vector3(0, 0.776, -0.245),
		Vector3(0.44, 0.52, 0.07), COL_SHELL, 0.0, 0.15)
	back.rotation_degrees = Vector3(-10, 0, 0)
	var lumbar := _box(root, "Chair Lumbar", Vector3(0, 0.640, -0.205),
		Vector3(0.42, 0.06, 0.03), COL_DARK)
	lumbar.rotation_degrees = Vector3(-10, 0, 0)

	# Armrests: a post and a pad each.
	for side in [-1.0, 1.0]:
		_box(root, "Chair Arm Post", Vector3(side * 0.255, 0.58, -0.03),
			Vector3(0.045, 0.20, 0.05), COL_STEEL, 0.0, 0.6)
		_box(root, "Chair Arm Pad", Vector3(side * 0.255, 0.695, -0.02),
			Vector3(0.07, 0.035, 0.22), COL_DARK, 0.0, 0.05)

	if with_collision:
		# Inset from the caster circle so the player can brush past the wheels
		# instead of being stopped 0.33 m away from them.
		_collider(root, "Swivel Chair", Vector3(0, 0.51, 0),
			Vector3(0.56, 1.02, 0.56))
	return root


# ===========================================================================
# The personal detail
# ===========================================================================

## A knitted cardigan left over the back of the chair.
##
## This is the one thing in the office that belongs to a person rather than to a
## post: the only warm colour in a room of institutional grey, and the only soft
## silhouette among the boxes. Someone hung it there at the start of a shift and
## did not come back for it. Nothing in the room says so out loud, which is why
## it works.
##
## Local frame: origin is the MIDPOINT OF THE TOP EDGE OF THE BACKREST, +Z the
## direction the seat faces. Pass the chair's returned root as `parent` and
## CHAIR_BACK_TOP as `origin` and it inherits the chair's yaw for free:
##
##   var chair := OfficeProps.build_swivel_chair(map, seat_pos, 156.0)
##   OfficeProps.build_draped_cardigan(chair, OfficeProps.CHAIR_BACK_TOP)
##
## Bounding box — 0.53 W x 0.52 H x 0.23 D, hanging DOWNWARD from the origin
## (local y +0.047 to -0.472). Deliberately asymmetric: one sleeve is folded
## over the yoke, the other hangs loose, so it reads as cloth and not as a slab.
static func build_draped_cardigan(parent: Node3D, origin: Vector3,
		yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, "Draped Cardigan", origin, yaw_deg)

	_box(root, "Cardigan Yoke", Vector3(0, -0.02, 0), Vector3(0.44, 0.07, 0.15),
		COL_WOOL)
	_box(root, "Cardigan Collar", Vector3(0, 0.022, -0.025),
		Vector3(0.21, 0.05, 0.11), COL_WOOL)

	var front := _box(root, "Cardigan Front", Vector3(0, -0.20, 0.055),
		Vector3(0.42, 0.30, 0.03), COL_WOOL)
	front.rotation_degrees = Vector3(6, 0, 0)
	var back := _box(root, "Cardigan Back", Vector3(0, -0.22, -0.065),
		Vector3(0.42, 0.34, 0.03), COL_WOOL)
	back.rotation_degrees = Vector3(-4, 0, 0)

	# Two folds break the flat panel up in silhouette.
	for i in range(2):
		var fold := _box(root, "Cardigan Fold %d" % i,
			Vector3(-0.10 + float(i) * 0.17, -0.26, 0.072),
			Vector3(0.05, 0.22, 0.018), COL_WOOL)
		fold.rotation_degrees = Vector3(0, 0, 4.0 - float(i) * 9.0)

	# Left sleeve: hanging, bent at the elbow.
	var upper := _box(root, "Cardigan Sleeve Upper", Vector3(-0.20, -0.15, 0.07),
		Vector3(0.075, 0.23, 0.055), COL_WOOL)
	upper.rotation_degrees = Vector3(0, 0, 7)
	var lower := _box(root, "Cardigan Sleeve Lower", Vector3(-0.238, -0.35, 0.09),
		Vector3(0.065, 0.22, 0.05), COL_WOOL)
	lower.rotation_degrees = Vector3(-8, 0, 3)
	_box(root, "Cardigan Cuff", Vector3(-0.245, -0.452, 0.10),
		Vector3(0.07, 0.04, 0.055), COL_WOOL)

	# Right sleeve: folded back over the yoke instead of hanging.
	var tucked := _box(root, "Cardigan Sleeve Tucked", Vector3(0.20, -0.055, 0.03),
		Vector3(0.075, 0.20, 0.06), COL_WOOL)
	tucked.rotation_degrees = Vector3(64, 0, -6)
	return root


# ===========================================================================
# The key cabinet
# ===========================================================================

## Grey steel key cabinet hanging open on the wall: three hook rails, twelve
## numbered fobs, one hook empty and its tag on the floor underneath.
##
## Local frame: z = 0 the wall face, +Z into the room, y = 0 the floor. The body
## hangs at chest height (y 1.34 to 1.90) and stands 0.10 proud of the wall.
##
## Bounding box — the cabinet itself is 0.54 W x 0.56 H x 0.40 D with the door
## open 105 degrees, hanging at y 1.34 to 1.90; the body alone is 0.42 x 0.56 x
## 0.10. The dropped fob on the floor 0.25 m out stretches the node's overall
## AABB to 0.54 x 1.90 x 0.40 measured from the floor up.
##
## NO COLLIDER. It is a 0.10 m protrusion on a wall the player already cannot
## walk through, and giving it a body would eat a 1.0 m strip of Curator navmesh
## along that wall for nothing.
##
## `empty_hook` is the index (0..11) of the hook whose key is out. `label_text`
## is optional signage for the door front; pass tr("KEY") or leave it empty.
static func build_key_cabinet(parent: Node3D, origin: Vector3,
		empty_hook := 4, yaw_deg := 0.0, label_text := "") -> Node3D:
	var root := _root(parent, "Key Cabinet", origin, yaw_deg)
	var body_y := 1.62

	_box(root, "Key Cabinet Body", Vector3(0, body_y, 0.05),
		Vector3(0.42, 0.56, 0.10), COL_STEEL, 0.0, 0.55)
	_box(root, "Key Cabinet Backboard", Vector3(0, body_y, 0.012),
		Vector3(0.38, 0.52, 0.006), COL_DARK)

	# Three hook rails, four fobs to a rail.
	for rail in range(3):
		var rail_y := body_y + 0.14 - float(rail) * 0.14
		_box(root, "Key Rail %d" % rail, Vector3(0, rail_y, 0.055),
			Vector3(0.36, 0.012, 0.012), COL_STEEL, 0.0, 0.7)
		for slot in range(4):
			var idx := rail * 4 + slot
			if idx == empty_hook:
				continue
			var fob_x := (float(slot) - 1.5) * 0.09
			_box(root, "Key Hook %d" % idx, Vector3(fob_x, rail_y - 0.012, 0.055),
				Vector3(0.008, 0.022, 0.008), COL_STEEL, 0.0, 0.7)
			_box(root, "Key Fob %d" % idx, Vector3(fob_x, rail_y - 0.050, 0.058),
				Vector3(0.026, 0.055, 0.006),
				COL_PAPER if idx % 5 else COL_CANCELLED)

	# The door, swung out into the room on its left hinge.
	var hinge := _root(root, "Key Cabinet Hinge",
		Vector3(-0.21, body_y, 0.012), -105.0)
	_box(hinge, "Key Cabinet Door", Vector3(0.20, 0, 0),
		Vector3(0.40, 0.54, 0.018), COL_STEEL, 0.0, 0.55)
	_box(hinge, "Key Cabinet Handle", Vector3(0.35, 0, 0.018),
		Vector3(0.03, 0.09, 0.016), COL_STEEL, 0.0, 0.7)
	_label_plate(hinge, "Key Cabinet Label", label_text,
		Vector3(0.20, 0.19, 0.011), Vector2(0.32, 0.09))

	# The tag that belongs on the empty hook, on the floor where it fell.
	var dropped := _box(root, "Dropped Key Fob", Vector3(0.06, 0.004, 0.25),
		Vector3(0.026, 0.006, 0.055), COL_CANCELLED)
	dropped.rotation_degrees = Vector3(0, 34, 0)
	return root


# ===========================================================================
# The document wall
# ===========================================================================

const SHEET_W := 0.21
const SHEET_H := 0.297
const SHEET_PITCH_X := 0.235
const SHEET_PITCH_Y := 0.325
## Centre height of the bottom row of protocol sheets.
const SHEET_ROW0_Y := 1.22


## A wall of printed protocol sheets under a shift roster.
##
## The sheets carry no text: the print is thin ink bars, which reads as a page of
## procedure at conversational distance, costs three nodes, and needs no
## translation. Ink on paper is a 6.7:1 luminance ratio. Sheets are jittered a
## few degrees each and shaded between fresh and yellowed by a deterministic
## hash, so no two are identical and the wall is identical on every playthrough.
##
## The roster above them is the horror: a ruled grid with every cell filled in
## except the last column, which is struck through. The schedule stops. Colour
## does not carry that on its own — the cancelled column is drawn as a cross.
##
## Local frame: z = 0 the wall face, +Z into the room, y = 0 the floor.
##
## Bounding box at the default 5x3 — the paperwork occupies a 1.27 W x 1.35 H x
## 0.03 D slab on the wall, local y 1.03 to 2.38 (roster top). One sheet has come
## down and lies on the floor, which puts the node's overall AABB at 1.27 x 2.38
## x 0.52 measured from the floor and 0.52 m out from the wall. General case:
##   width = columns * 0.235 + 0.10   (never less than the 0.46 m roster)
##
## NO COLLIDER — it is paper on a wall.
##
## COST: the heaviest prop in this file, roughly 75 nodes at the default. Turn
## `columns` and `rows` down if the office budget gets tight.
static func build_document_wall(parent: Node3D, origin: Vector3, columns := 5,
		rows := 3, yaw_deg := 0.0, label_text := "") -> Node3D:
	columns = maxi(1, columns)
	rows = maxi(1, rows)
	var root := _root(parent, "Document Wall", origin, yaw_deg)

	var board_w: float = maxf(float(columns) * SHEET_PITCH_X, 0.46)
	var bottom_y := SHEET_ROW0_Y - SHEET_H * 0.5
	var top_y := SHEET_ROW0_Y + float(rows - 1) * SHEET_PITCH_Y + SHEET_H * 0.5

	# Aluminium hanging rails top and bottom.
	for rail_y in [bottom_y - 0.026, top_y + 0.026]:
		_box(root, "Document Rail", Vector3(0, rail_y, 0.011),
			Vector3(board_w + 0.10, 0.026, 0.022), COL_STEEL, 0.0, 0.6)

	for row in range(rows):
		for col in range(columns):
			var idx := row * columns + col
			var noise := _jitter(float(idx) + 1.0)
			var sx := (float(col) - float(columns - 1) * 0.5) * SHEET_PITCH_X
			var sy := SHEET_ROW0_Y + float(row) * SHEET_PITCH_Y
			var sheet := _box(root, "Protocol Sheet %d" % idx,
				Vector3(sx, sy, 0.008), Vector3(SHEET_W, SHEET_H, 0.004),
				COL_PAPER.lerp(COL_PAPER_AGED, noise))
			sheet.rotation_degrees = Vector3(0, 0, (noise - 0.5) * 6.0)
			# Header bar on every sheet; body copy on most of them. A quarter of
			# the wall is blank stock or hung face-down, which is both cheaper
			# and truer than a perfectly filled grid.
			_box(root, "Protocol Header %d" % idx,
				Vector3(sx, sy + 0.10, 0.011), Vector3(0.13, 0.016, 0.003),
				COL_INK)
			if noise > 0.72:
				continue
			for line in range(2):
				_box(root, "Protocol Line %d-%d" % [idx, line],
					Vector3(sx - 0.02, sy + 0.02 - float(line) * 0.055, 0.011),
					Vector3(0.13 - float(line) * 0.03, 0.008, 0.003), COL_INK)

	_build_roster(root, Vector3(0, top_y + 0.20, 0.0))
	_label_plate(root, "Document Wall Label", label_text,
		Vector3(0, bottom_y - 0.10, 0.010), Vector2(board_w * 0.7, 0.09))

	# One sheet has come off the wall and nobody picked it up.
	var fallen := _box(root, "Fallen Protocol Sheet",
		Vector3(board_w * 0.22, 0.003, 0.34),
		Vector3(SHEET_W, 0.004, SHEET_H), COL_PAPER_AGED)
	fallen.rotation_degrees = Vector3(0, 24, 0)
	return root


## The shift roster: a ruled grid, three weeks of filled cells, and a fourth
## column struck out. Placed by build_document_wall above the sheet grid; 0.46 x
## 0.32 of paper, so it tops out 0.16 above `roster_origin`.
static func _build_roster(parent: Node3D, roster_origin: Vector3) -> void:
	var roster := _root(parent, "Shift Roster", roster_origin, 0.0)
	_box(roster, "Roster Sheet", Vector3(0, 0, 0.006),
		Vector3(0.46, 0.32, 0.005), COL_PAPER)
	_box(roster, "Roster Header", Vector3(0, 0.135, 0.009),
		Vector3(0.46, 0.036, 0.003), COL_INK)

	var cell_w := 0.46 / 4.0
	var cell_h := 0.28 / 3.0
	for i in range(5):
		_box(roster, "Roster Rule V %d" % i,
			Vector3(-0.23 + float(i) * cell_w, -0.02, 0.009),
			Vector3(0.003, 0.28, 0.002), COL_INK)
	for i in range(4):
		_box(roster, "Roster Rule H %d" % i,
			Vector3(0, -0.16 + float(i) * cell_h, 0.009),
			Vector3(0.46, 0.003, 0.002), COL_INK)

	# Columns 0-2 are signed off. Column 3 is not.
	for col in range(3):
		for row in range(3):
			_box(roster, "Roster Entry %d-%d" % [col, row],
				Vector3(-0.23 + (float(col) + 0.5) * cell_w,
					-0.16 + (float(row) + 0.5) * cell_h, 0.010),
				Vector3(cell_w * 0.62, 0.010, 0.002), COL_INK)

	# The empty column, crossed out. Shape carries the meaning; the dull red is
	# only reinforcement.
	for i in range(2):
		var stroke := _box(roster, "Roster Cancelled %d" % i,
			Vector3(-0.23 + 3.5 * cell_w, -0.02, 0.011),
			Vector3(0.012, 0.30, 0.002), COL_CANCELLED)
		stroke.rotation_degrees = Vector3(0, 0, 38.0 - float(i) * 76.0)


# ===========================================================================
# Desktop small props
# ===========================================================================

## Overlapping coffee rings and a drip, for the surface a mug has been put down
## on for years. Flattened tori plus one small blot, all on a single translucent
## brown material.
##
## Local frame: origin is ON the surface, so pass the desk's own origin plus
## Vector3(x, DESK_TOP_Y, z). Sits 1.5 mm proud to stay out of z-fighting.
##
## Bounding box — 0.14 W x 0.003 H x 0.19 D at the default three rings; the
## cluster is deliberately tight, because a mug goes down in the same spot for
## years. No collider, and none is wanted: the material is transparent.
static func build_coffee_ring(parent: Node3D, origin: Vector3, rings := 3,
		yaw_deg := 0.0) -> Node3D:
	rings = maxi(1, rings)
	var root := _root(parent, "Coffee Rings", origin, yaw_deg)
	for i in range(rings):
		var a := TAU * _jitter(float(i) + 3.0)
		var r := 0.09 * _jitter(float(i) + 7.0)
		var ring := _torus(root, "Coffee Ring %d" % i,
			Vector3(cos(a) * r, 0.0015, sin(a) * r), 0.036, 0.047,
			COL_STAIN, false, true)
		# A stain is flat. Left unscaled the torus is a 11 mm tube on the desk.
		ring.scale = Vector3(1.0, 0.10, 1.0)
	var blot := _cylinder(root, "Coffee Drip", Vector3(0.062, 0.0012, -0.048),
		0.013, 0.01, COL_STAIN)
	blot.scale = Vector3(1.0, 0.12, 1.0)
	return root


## Electric kettle on its power base — the most ordinary object in the museum,
## and the reason the office feels like somebody's job rather than a set.
##
## Local frame: origin is ON the surface it stands on, +Z the spout direction.
##
## Bounding box — the kettle is 0.19 W x 0.25 H x 0.26 D; the flex trailing off
## the back takes the node's overall AABB to 0.19 x 0.25 x 0.42.
## No collider (it is a 0.19 m object standing on a desk that has one).
##
## `switch_lit` leaves the boil lamp on. It has been on all night. Steady
## emission, never a flicker, so nothing here answers to reduced_flashes.
static func build_kettle(parent: Node3D, origin: Vector3, switch_lit := true,
		yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, "Kettle", origin, yaw_deg)

	_cylinder(root, "Kettle Base", Vector3(0, 0.011, 0), 0.095, 0.022,
		COL_SHELL, 0.0, 0.3)
	_cone(root, "Kettle Body", Vector3(0, 0.1145, 0), 0.082, 0.072, 0.185,
		COL_PLASTIC)
	_box(root, "Kettle Gauge", Vector3(0, 0.115, -0.074),
		Vector3(0.022, 0.13, 0.014), COL_DARK)
	_cylinder(root, "Kettle Lid", Vector3(0, 0.216, 0), 0.070, 0.018,
		COL_PLASTIC)
	_cylinder(root, "Kettle Knob", Vector3(0, 0.236, 0), 0.022, 0.022,
		COL_SHELL, 0.0, 0.3)

	var spout := _cone(root, "Kettle Spout", Vector3(0, 0.185, 0.088), 0.030,
		0.016, 0.075, COL_PLASTIC)
	spout.rotation_degrees = Vector3(52, 0, 0)

	# Handle: a C of three bars on the side opposite the spout.
	_box(root, "Kettle Handle", Vector3(0, 0.135, -0.118),
		Vector3(0.020, 0.155, 0.022), COL_SHELL, 0.0, 0.2)
	for link_y in [0.065, 0.205]:
		_box(root, "Kettle Handle Link", Vector3(0, link_y, -0.096),
			Vector3(0.020, 0.022, 0.055), COL_SHELL, 0.0, 0.2)

	_box(root, "Kettle Switch", Vector3(0, 0.052, -0.099),
		Vector3(0.030, 0.036, 0.016), COL_SHELL, 0.0, 0.2)
	if switch_lit:
		_box(root, "Kettle Boil Lamp", Vector3(0, 0.046, -0.108),
			Vector3(0.014, 0.009, 0.006), COL_LED, 1.6)

	# Flex, trailing off the back of the base.
	for i in range(2):
		var dir := Vector3(0.30 if i == 0 else 0.12, 0.0, -1.0).normalized()
		var flex := _cylinder(root, "Kettle Flex %d" % i, Vector3.ZERO, 0.007,
			0.10, COL_DARK)
		flex.transform = Transform3D(_aim(dir),
			Vector3(0, 0.007, -0.09) + dir * (0.05 + float(i) * 0.09))
	return root


## A plant that died some time ago: a tapered pot, cracked soil, bare stems and
## four curled leaves still hanging on. Grey-brown throughout, so it reads as
## absence rather than as decoration.
##
## Local frame: origin at the base of the pot, floor level.
##
## Bounding box — 0.51 W x 0.80 H x 0.49 D, including the shed leaf on the floor
## and the stems, which lean no further out than 0.27 from the centre.
##
## COLLIDER: 0.42 x 0.30 x 0.42 on the pot only, which costs 1.32 x 1.32 m of
## navmesh. Put it in a corner. Never within 1.4 m of a doorway.
static func build_dead_plant(parent: Node3D, origin: Vector3, yaw_deg := 0.0,
		with_collision := true) -> Node3D:
	var root := _root(parent, "Dead Plant", origin, yaw_deg)

	_cone(root, "Planter", Vector3(0, 0.15, 0), 0.160, 0.200, 0.30,
		Color(0.130, 0.115, 0.105))
	_cylinder(root, "Planter Rim", Vector3(0, 0.295, 0), 0.210, 0.030,
		Color(0.150, 0.132, 0.120))
	_cylinder(root, "Planter Soil", Vector3(0, 0.288, 0), 0.185, 0.030,
		COL_SOIL)
	var crack := _box(root, "Soil Crack", Vector3(0.02, 0.302, 0.01),
		Vector3(0.012, 0.006, 0.24), Color(0.070, 0.058, 0.048))
	crack.rotation_degrees = Vector3(0, 28, 0)

	# Seven bare stems, leaning out and slightly over.
	var soil_top := Vector3(0, 0.30, 0)
	for i in range(7):
		var a := TAU * float(i) / 7.0 + 0.4
		var tilt := deg_to_rad(12.0 + float(i % 3) * 11.0)
		var length := 0.34 + float(i % 4) * 0.055
		var dir := Vector3(sin(tilt) * cos(a), cos(tilt), sin(tilt) * sin(a))
		var stem := _cylinder(root, "Dead Stem %d" % i, Vector3.ZERO, 0.008,
			length, Color(0.175, 0.150, 0.115))
		stem.transform = Transform3D(_aim(dir), soil_top + dir * (length * 0.5))
		if i % 2 == 1:
			continue
		# What is left of the leaves, hanging straight down off the tips.
		var tip := soil_top + dir * length
		var leaf := _prism(root, "Dead Leaf %d" % i,
			tip + Vector3(0, -0.055, 0), Vector3(0.055, 0.11, 0.012),
			COL_DEAD_LEAF)
		leaf.rotation_degrees = Vector3(0, rad_to_deg(a), 172.0)

	var shed := _prism(root, "Shed Leaf", Vector3(0.24, 0.006, 0.21),
		Vector3(0.06, 0.10, 0.010), COL_DEAD_LEAF)
	shed.rotation_degrees = Vector3(90, 47, 0)

	if with_collision:
		_collider(root, "Dead Plant", Vector3(0, 0.15, 0),
			Vector3(0.42, 0.30, 0.42))
	return root


# ===========================================================================
# The whole workstation
# ===========================================================================

## Every prop above, placed relative to each other in one call. This is the
## intended entry point; the individual builders are exposed for dressing the
## rest of the room.
##
## Local frame: origin is ON THE FLOOR AT THE BASE OF THE MONITOR WALL, centred
## on the bank, +Z into the room. So `yaw_deg` is the yaw of the wall the
## monitors hang on: 0 when the room lies toward +Z.
##
## Suggested placement in the Watcher Office (centre -25, 0, 0; x -35..-15,
## z -7..7):
##
##   OfficeProps.build_watcher_office(map_root, Vector3(-25, 0, -2.4), 0.0)
##
## That keeps the bank at the rail height the prologue's seventh shot already
## looks at (it aims at -25, 2.05, -2.2; the bank tops out at 2.02) and leaves
## the whole assembly more than 4 m clear of the Archive door at (-25, -7), the
## Storage door at (-25, +7) and the Atrium door at (-15, 0).
##
## Bounding box — 4.50 W x 2.38 H x 1.79 D, local x -2.26 to +2.24, y 0 to 2.378
## and z +0.02 to +1.813 (the chair back is the deepest thing in the room).
##
## Colliders created, and nothing else:
##   Monitor Bank   1.79 x 0.15  at z 0.095
##   Operator Desk  2.40 x 0.72  at z 0.500
##   Swivel Chair   0.56 x 0.56  at (x 0.05, z 1.42)
##   Dead Plant     0.42 x 0.42  at (x -2.05, z 0.32)
## Their union is a 3.46 x 1.68 m block of floor, which the 0.45 m agent radius
## grows into a 4.36 x 2.58 m hole in the navmesh. At the suggested origin that
## leaves 4.6 m to the Archive door, 7.7 m to the Storage door and 8.7 m to the
## Atrium door. Re-check those three numbers if you move it.
##
## Node cost is 233 MeshInstance3D against the ~1270 the map already builds, and
## it replaces the ~90 inline nodes in _add_office_details.
static func build_watcher_office(parent: Node3D, origin: Vector3,
		yaw_deg := 0.0, cabinet_label := "", roster_label := "") -> Node3D:
	var root := _root(parent, "Watcher Office Workstation", origin, yaw_deg)

	build_monitor_bank(root, Vector3(0, 0, 0.02), 3, 2)
	build_desk(root, Vector3(0, 0, 0.50), 2.4)

	# The chair is turned 24 degrees off the desk and pushed back from it. An
	# empty chair facing the wrong way is the cheapest unease in the room.
	var chair := build_swivel_chair(root, Vector3(0.05, 0, 1.42), 156.0)
	build_draped_cardigan(chair, CHAIR_BACK_TOP)

	# Desktop clutter, on the desk's surface. The desk root sits at z 0.50, so
	# these are its own coordinates offset by that.
	build_kettle(root, Vector3(0.95, DESK_TOP_Y, 0.82), true, -24.0)
	build_coffee_ring(root, Vector3(0.52, DESK_TOP_Y, 0.86), 3)

	# The rest of the wall.
	build_key_cabinet(root, Vector3(-1.35, 0, 0.02), 4, 0.0, cabinet_label)
	build_document_wall(root, Vector3(1.55, 0, 0.02), 5, 3, 0.0, roster_label)
	build_dead_plant(root, Vector3(-2.05, 0, 0.32), 18.0)
	return root
