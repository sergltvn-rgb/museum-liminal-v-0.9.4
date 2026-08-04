@tool
class_name SpaceProps
extends RefCounted
## Procedural props for Space Wing C -- the wing that exhibits the constant of
## distance. Everything here is built from Godot primitives at runtime, the
## same way scenes/FirstMuseumMap.tscn builds the rest of the museum (that
## scene holds zero 3D content; build_map() makes all of it).
##
## WHY PROCEDURAL. The five "real" exhibits that used to stand here and in the
## other wings were stock Khronos glTF samples -- a rubber duck, a flight
## helmet, an avocado, a 25.7 m lamp post, a PBR material-test grid. They are
## refused by MapModels.PLACEHOLDER_MODELS now. This file is the replacement
## for Wing C's three slots plus the wing dressing around them.
##
## THE IDEA. Wing C is where distance stops agreeing with itself. None of that
## is a shader: it is all geometry that measures wrong. Frames recede faster
## than they should. Orbits do not share a centre. A floor grid meets its own
## other half at an angle. The player cannot point at the trick, only feel the
## room is the wrong size.
##
## CONTRACT (every builder follows it)
##   * signature is (parent: Node3D, origin: Vector3, ...) -> Node3D
##   * `origin` is the surface the prop stands on -- floor level for standing
##     props, the wall face for wall pieces -- and is the horizontal CENTRE of
##     the prop. Geometry grows upward/outward from there.
##   * the returned node is a fresh Node3D already added to `parent`; move,
##     rotate or free it as one unit.
##   * `facing_deg` is a yaw about +Y. At 0 the prop's front faces local +Z.
##
## SCALE. Rooms are WALL_HEIGHT 3.4 m. Bounding boxes measured from `origin`
## on the built nodes, not estimated:
##   portal_arch     2.36 W x 2.62 H x 0.94 D  x+-1.18  y 0..2.62   z -0.63..+0.31
##   star_globe      1.38 W x 1.69 H x 1.24 D  x+-0.69  y 0..1.69   z -0.61..+0.63
##   orrery          1.58 W x 1.25 H x 1.61 D  x -0.86..+0.73       z -0.71..+0.91
##   false_corridor  2.52 W x 2.76 H x 1.85 D  x+-1.26  y 0..2.76   z -1.79..+0.06
##   nested_frames   1.45 W x 1.83 H x 0.19 D  x+-0.73  y+-0.92     z +0.01..+0.20
##   floor_grid      <=size.x+0.05 W x 0.022 H x <=size.y D, y 0.001..0.023
## The star globe read 1.21 D / z -0.58..+0.63 here until it was re-measured: the
## -0.58 is the globe's own back, and _star_field's pins hang 0.02 m further out
## than that (they sit at radius 0.598 on a 0.58 sphere and are cubes up to
## 0.041 across). z -0.61 is the whole prop. NOTE: a MultiMesh's transforms live
## on the RenderingServer, and the headless dummy renderer reads them all back as
## identity -- measure the star field by re-running its lattice, not by walking
## the built node, or it will report a 0.024 m box at the origin.
## The orrery's extents are asymmetric on purpose: its orbits do not share a
## centre. Star globe and orrery both clear the 2.25 x 2.10 x 2.25 glass case
## FirstMuseumMap._add_exhibit builds; the portal arch does not (see its note).
##
## COLLISION. Opt-in per mesh, never automatic. Only the parts a walking player
## can actually shoulder into get a StaticBody3D, because the Curator's navmesh
## is baked from static colliders (PARSED_GEOMETRY_STATIC_COLLIDERS) and erodes
## agent_radius 0.45 m per side. Nothing here may be placed in a doorway:
## DOOR_GAP is 1.8 m and every solid prop in this file is wider than that.
##
## ACCESSIBILITY. Nothing in this file moves, flickers or pulses, so there is
## no SettingsManager.reduced_flashes path to honour -- the wrongness is in the
## shapes and stays legible when every animation in the game is switched off.
## Emissive parts are steady seams and pin-point stars, never strobes. No
## meaning is carried by colour: each anomaly is a silhouette (an orbit with a
## gap, a sky with a hole in it, a corridor that ends too soon).


# --- Shared with FirstMuseumMap ---------------------------------------------
# Duplicated rather than imported: this file must stay standalone, and these
# are load-bearing numbers a reader needs in front of them.

## Room height. Nothing here may exceed it.
const WALL_HEIGHT := 3.4
## Clear width of every doorway. Nothing solid here may cross one.
const DOOR_GAP := 1.8
## Matches FirstMuseumMap._primitive: cull decorative geometry past this.
const VISIBILITY_RANGE := 115.0
## Props smaller than this diagonal stop casting shadows.
const SHADOW_CUTOFF := 0.65

# --- Palette ----------------------------------------------------------------
# Wing C's room colour is Color(0.68, 0.70, 0.75), a cold grey. These sit under
# it: the exhibits are darker than their room so they read as silhouettes when
# the wing lights fail.

const MatLib := preload("res://game/props/MaterialLib.gd")
# Только через preload: глобальное имя класса в голом --script-прогоне не
# регистрируется и вся цепочка падает (раздел 14 плана).
const Pal := preload("res://game/props/Palette.gd")

## Exhibit casework and arch stone.
# Зал космоса тёмный по замыслу: светятся только звёзды и инкрустация,
# поэтому камень и чернота — затемнённые производные палитры (`static var`,
# так как вызов `tone()` не константное выражение).
static var STONE := Pal.tone(Pal.SLATE, -0.48)
## Lit faces of the same stone -- top surfaces, crowns.
static var STONE_LIT := Pal.tone(Pal.SLATE, -0.25)
## Near-black. Holes, thresholds, the far end of things.
static var VOID := Pal.tone(Pal.DARK, -0.42)
## Tarnished instrument brass for rings, arms and plaques.
static var BRASS := Pal.tone(Pal.BRASS, -0.34)
## Cold light leaking from somewhere the player cannot get to.
const GLOW := Color(0.560, 0.680, 0.820)
## Pin-point starlight.
const STAR := Color(0.800, 0.860, 1.000)
## The membrane in the arch: visible, not passable.
const MEMBRANE := Color(0.105, 0.135, 0.195, 0.42)
## Inlaid floor lines.
static var INLAY := Pal.tone(Pal.SLATE, 0.20)


# --- Material cache ---------------------------------------------------------
# One StandardMaterial3D per distinct look, shared by every prop this file ever
# builds. The map already spawns ~1270 MeshInstance3D in a single frame; a
# fresh material per mesh on top of that is what makes it stutter.

static var _materials: Dictionary = {}
static var _roughness_noise: NoiseTexture2D = null
static var _normal_noise: NoiseTexture2D = null


## Cached StandardMaterial3D. Opaque, non-emissive, low-metal materials get the
## same restrained triplanar noise the museum walls use, so a prop standing
## against a wall does not read as a slab of plastic next to it.
static func _pack_for(color: Color) -> String:
	if color.is_equal_approx(STONE) or color.is_equal_approx(STONE_LIT):
		return "quartzite"
	if color.is_equal_approx(BRASS):
		return "painted_metal"
	return ""


static func _mat(color: Color, emission := 0.0, metallic := 0.0,
		transparent := false) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s" % [color.to_html(true), emission, metallic,
		transparent]
	if _materials.has(key):
		return _materials[key]

	if not transparent and emission <= 0.0:
		var pack := _pack_for(color)
		if not pack.is_empty():
			var photo := MatLib.get_material(pack, color)
			_materials[key] = photo
			return photo

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = clampf(0.5 - metallic * 0.35, 0.12, 1.0)
	mat.metallic = metallic
	mat.metallic_specular = 0.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission

	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Seen from both sides: the player walks around the arch.
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	if not transparent and emission <= 0.0 and not MatLib.apply_flat_style(mat) and metallic < 0.35:
		mat.roughness_texture = _surface_noise()
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.normal_enabled = true
		mat.normal_texture = _surface_bump()
		mat.normal_scale = 0.08
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.22, 0.22, 0.22)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_materials[key] = mat
	return mat


static func _surface_noise() -> NoiseTexture2D:
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


static func _surface_bump() -> NoiseTexture2D:
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


# --- Primitive builders -----------------------------------------------------
# Same shape as FirstMuseumMap._primitive, with one deliberate difference:
# `collide` defaults to FALSE. The map infers collision from a size threshold,
# which is right for a map that must not forget a wall; a prop file must not
# accidentally drop a navmesh obstacle into a room, so every collider here is
# written out by hand at the call site.

static func _spawn(parent: Node3D, node_name: String, local_position: Vector3,
		mesh: PrimitiveMesh, size: Vector3, mat: StandardMaterial3D,
		collide := false) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.position = local_position
	inst.mesh = mesh
	inst.material_override = mat
	inst.visibility_range_end = VISIBILITY_RANGE
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if size.length() < SHADOW_CUTOFF:
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)

	if collide:
		var body := StaticBody3D.new()
		body.name = "%s Collision" % node_name
		inst.add_child(body)
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.name = "%s CollisionShape" % node_name
		collider.shape = shape
		body.add_child(collider)
	return inst


static func _box(parent: Node3D, node_name: String, local_position: Vector3,
		size: Vector3, mat: StandardMaterial3D, collide := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _spawn(parent, node_name, local_position, mesh, size, mat, collide)


static func _cylinder(parent: Node3D, node_name: String, local_position: Vector3,
		radius: float, height: float, mat: StandardMaterial3D,
		collide := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = radius
	mesh.top_radius = radius
	# Default is 64 -- far more than a 0.4 m museum plinth needs.
	mesh.radial_segments = 16
	mesh.rings = 1
	return _spawn(parent, node_name, local_position, mesh,
		Vector3(radius * 2.0, height, radius * 2.0), mat, collide)


static func _sphere(parent: Node3D, node_name: String, local_position: Vector3,
		radius: float, mat: StandardMaterial3D, collide := false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	return _spawn(parent, node_name, local_position, mesh,
		Vector3(radius * 2.0, radius * 2.0, radius * 2.0), mat, collide)


static func _prism(parent: Node3D, node_name: String, local_position: Vector3,
		size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _spawn(parent, node_name, local_position, mesh, size, mat, false)


## Flat ring. `radius` is to the centre of the tube, `tube` is its thickness.
## Never collidable: a torus box-collider is a solid slab the size of the whole
## ring, which is how you seal a room by accident.
static func _ring(parent: Node3D, node_name: String, local_position: Vector3,
		radius: float, tube: float, mat: StandardMaterial3D,
		tilt_deg := 0.0) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - tube * 0.5
	mesh.outer_radius = radius + tube * 0.5
	mesh.rings = 24
	mesh.ring_segments = 6
	var inst := _spawn(parent, node_name, local_position, mesh,
		Vector3((radius + tube) * 2.0, tube, (radius + tube) * 2.0), mat, false)
	# TorusMesh lies in the XZ plane. tilt_deg 0 leaves it flat (an orbit);
	# 69 stands it almost upright (a meridian leaning 21 deg off vertical).
	inst.rotation_degrees = Vector3(tilt_deg, 0, 0)
	return inst


## Root node every builder hands back. Named, positioned, yawed, scaled.
static func _root(parent: Node3D, node_name: String, origin: Vector3,
		facing_deg: float, scale_factor: float) -> Node3D:
	var node := Node3D.new()
	# A repeated sibling name makes Godot rename the second prop to @Node3D@NNN.
	if parent.has_node(NodePath(node_name)):
		node_name = "%s %s" % [node_name, origin]
	node.name = node_name
	node.position = origin
	node.rotation_degrees = Vector3(0, facing_deg, 0)
	node.scale = Vector3.ONE * scale_factor
	parent.add_child(node)
	return node


# ============================================================================
# EXHIBIT 1 -- PORTAL ARCH
# ============================================================================

## A stone doorway standing on the floor with a translucent membrane across it.
##
## Bounding box 2.36 W x 2.62 H x 0.94 D, spanning local z -0.63 .. +0.31.
## Opening 1.59 x 2.06. Front face is local +Z.
##
## What is wrong with it. Look through the membrane and there are three more
## arch mouths behind it, each smaller than the last -- a corridor receding
## into the wall. It is 0.6 m deep. And the mouths do not recede along the
## axis: each one sits a little further right and a little lower than the one
## before, so the vanishing point of the corridor is outside the doorway you
## are standing in front of. Whatever is at the far end, you are not looking
## at it head-on.
##
## PLACEMENT. Free-standing, on the floor, `origin` at the centre of the
## threshold. Leave 0.7 m clear BEHIND it (the recession overhangs the legs by
## 0.32 m) and never put it in a doorway: the membrane is solid, and at 2.36 m
## wide it is wider than DOOR_GAP. Its own opening is 1.59 m, under DOOR_GAP,
## so it must not be the only way through anywhere.
##
## Pass scale_factor 0.62 to shrink it to 1.46 x 1.62 x 0.58, which is the
## largest it can be and still stand on a 0.7 m exhibit pedestal inside the
## 2.25 x 2.10 x 2.25 glass case FirstMuseumMap._add_exhibit builds.
static func portal_arch(parent: Node3D, origin: Vector3, facing_deg := 0.0,
		scale_factor := 1.0) -> Node3D:
	var root := _root(parent, "Portal Arch", origin, facing_deg, scale_factor)
	var stone := _mat(STONE)
	var lit := _mat(STONE_LIT)
	var dark := _mat(VOID)

	# Two footings and two legs. The right leg is 0.34 m thick against the
	# left's 0.30 and its plinth is 0.03 m further out: the arch is not
	# symmetrical, and nobody notices until they try to say why.
	_box(root, "Portal Arch Footing L", Vector3(-0.95, 0.07, 0),
		Vector3(0.46, 0.14, 0.62), lit, true)
	_box(root, "Portal Arch Footing R", Vector3(0.96, 0.07, 0),
		Vector3(0.44, 0.14, 0.62), lit, true)
	_box(root, "Portal Arch Leg L", Vector3(-0.95, 1.17, 0),
		Vector3(0.30, 2.06, 0.44), stone, true)
	_box(root, "Portal Arch Leg R", Vector3(0.96, 1.17, 0),
		Vector3(0.34, 2.06, 0.44), stone, true)

	# Lintel and crown sit above 2.2 m -- out of reach, so no colliders. Every
	# collider in a room is a chunk the navmesh bake has to erode around.
	_box(root, "Portal Arch Lintel", Vector3(0, 2.32, 0),
		Vector3(2.36, 0.24, 0.48), stone)
	# The crown's peak is 0.06 m right of the arch's centre line.
	_prism(root, "Portal Arch Crown", Vector3(0.06, 2.53, 0),
		Vector3(2.00, 0.18, 0.44), lit)

	# The membrane. A 0.10 m slab rather than a PlaneMesh so it can carry a
	# collider: the point of the exhibit is that you can see through it and
	# cannot walk through it. Alpha 0.42, unlit, no glow -- it is a surface,
	# not a light source.
	_box(root, "Portal Arch Membrane", Vector3(0, 1.11, -0.06),
		Vector3(1.58, 2.02, 0.10), _mat(MEMBRANE, 0.0, 0.0, true), true)

	# A hole where the floor should be inside the arch.
	_box(root, "Portal Arch Threshold", Vector3(0, 0.012, -0.14),
		Vector3(1.58, 0.024, 0.66), dark)

	# The recession. Three mouths in 0.30 m of depth, each shifted right and
	# down: opening width, opening height, centre x, centre y, member, z.
	var mouths := [
		[1.24, 1.62, 0.07, 1.05, 0.09, -0.22],
		[0.88, 1.18, 0.16, 0.95, 0.08, -0.38],
		[0.56, 0.78, 0.24, 0.86, 0.07, -0.52],
	]
	for i in range(mouths.size()):
		var m: Array = mouths[i]
		var w: float = m[0]
		var h: float = m[1]
		var cx: float = m[2]
		var cy: float = m[3]
		var t: float = m[4]
		var z: float = m[5]
		var shade := _mat(STONE.lerp(VOID, 0.35 + 0.2 * float(i)))
		_box(root, "Portal Arch Mouth %d Left" % i,
			Vector3(cx - w * 0.5 - t * 0.5, cy, z), Vector3(t, h + t * 2.0, 0.09), shade)
		_box(root, "Portal Arch Mouth %d Right" % i,
			Vector3(cx + w * 0.5 + t * 0.5, cy, z), Vector3(t, h + t * 2.0, 0.09), shade)
		_box(root, "Portal Arch Mouth %d Head" % i,
			Vector3(cx, cy + h * 0.5 + t * 0.5, z), Vector3(w, t, 0.09), shade)

	# The far end, and the light under it. This is the only bright thing in the
	# exhibit and it is 0.6 m away pretending to be thirty.
	_box(root, "Portal Arch Far Wall", Vector3(0.24, 0.86, -0.60),
		Vector3(0.64, 0.86, 0.05), dark)
	_box(root, "Portal Arch Far Seam", Vector3(0.24, 0.47, -0.575),
		Vector3(0.46, 0.022, 0.02), _mat(GLOW, 1.0))
	return root


# ============================================================================
# EXHIBIT 2 -- STAR GLOBE
# ============================================================================

## A black globe in a brass meridian, with the stars on the OUTSIDE.
##
## Bounding box 1.38 W x 1.69 H x 1.24 D (z -0.61..+0.63; the back of the box is
## a star pin, not the globe). Fits the 2.25 x 2.10 x 2.25 glass case with
## 0.06 m of headroom when `origin` is the pedestal top -- the tightest exhibit
## in the wing, and the only axis with any slack left is not the vertical one.
##
## What is wrong with it. This is a sky map inside out: you are not under the
## stars, you are outside them looking in. One patch of the sky is simply
## missing -- a clean circular hole about 30 degrees across with no stars in
## it at all -- and a single star has come off the sphere and hangs a
## hand's width clear of the surface in the middle of that hole. The globe
## also does not sit centred in its cradle; it is 0.04 m off the meridian's
## axis, which is exactly enough to look like nobody has touched it in years.
##
## PLACEMENT. `origin` is the surface it stands on. To drop it into
## FirstMuseumMap._add_exhibit's "sphere" fallback slot, pass
## `exhibit_position + Vector3(0, 0.7, 0)` so it stands on the existing 0.7 m
## pedestal instead of inside it.
static func star_globe(parent: Node3D, origin: Vector3, facing_deg := 0.0,
		scale_factor := 1.0) -> Node3D:
	var root := _root(parent, "Star Globe", origin, facing_deg, scale_factor)

	_cylinder(root, "Star Globe Base", Vector3(0, 0.05, 0), 0.42, 0.10,
		_mat(STONE), true)
	_cylinder(root, "Star Globe Base Bevel", Vector3(0, 0.13, 0), 0.30, 0.06,
		_mat(STONE_LIT))
	_cylinder(root, "Star Globe Stem", Vector3(0, 0.30, 0), 0.055, 0.36,
		_mat(BRASS, 0.0, 0.5))

	# Blank plaque. No text: the label for this case is the museum's job, and a
	# plate you cannot read is better horror than one you can.
	_box(root, "Star Globe Plaque", Vector3(0, 0.06, 0.415),
		Vector3(0.30, 0.10, 0.02), _mat(BRASS, 0.0, 0.5))

	var centre := Vector3(0.04, 1.04, 0)
	_sphere(root, "Star Globe Sphere", centre, 0.58, _mat(VOID), true)
	# Meridian ring, leaning 21 degrees off vertical. Centred on the stand, not
	# on the globe -- the 0.04 m offset is the whole point.
	_ring(root, "Star Globe Meridian", Vector3(0, 1.04, 0), 0.665, 0.05,
		_mat(BRASS, 0.08, 0.5), 69.0)

	# The sky. One MultiMeshInstance3D instead of ~50 MeshInstance3D: the map
	# already builds ~1270 nodes in the frame this runs in.
	var missing := Vector3(0.55, 0.35, 0.76).normalized()
	_star_field(root, "Star Globe Sky", centre, 0.598, 64, missing, 0.86)
	# The star that came off, hanging in the empty patch.
	_box(root, "Star Globe Loose Star", centre + missing * 0.80,
		Vector3(0.05, 0.05, 0.05), _mat(STAR, 0.9))
	return root


## Pin-point stars on a sphere, minus a cone of sky around `void_dir`.
## Deterministic: a Fibonacci lattice for even coverage, jittered by a fixed
## seed so it does not read as a spiral.
static func _star_field(parent: Node3D, node_name: String, centre: Vector3,
		radius: float, count: int, void_dir: Vector3,
		void_cos: float) -> MultiMeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 913
	var golden := PI * (3.0 - sqrt(5.0))
	var dirs: Array[Vector3] = []
	for i in range(count):
		var y := 1.0 - 2.0 * (float(i) + 0.5) / float(count)
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var a := golden * float(i)
		var dir := Vector3(cos(a) * r, y, sin(a) * r)
		dir = (dir + Vector3(rng.randfn(0.0, 0.06), rng.randfn(0.0, 0.06),
			rng.randfn(0.0, 0.06))).normalized()
		if dir.dot(void_dir) > void_cos:
			continue  # the missing constellation
		dirs.append(dir)

	var star_mesh := BoxMesh.new()
	star_mesh.size = Vector3(0.024, 0.024, 0.024)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = star_mesh
	multi.instance_count = dirs.size()
	for i in range(dirs.size()):
		var s := rng.randf_range(0.55, 1.70)
		var basis := Basis.IDENTITY.rotated(Vector3.UP, rng.randf() * TAU) \
			.scaled(Vector3(s, s, s))
		multi.set_instance_transform(i,
			Transform3D(basis, centre + dirs[i] * radius))

	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = multi
	inst.material_override = _mat(STAR, 1.9)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.visibility_range_end = VISIBILITY_RANGE
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(inst)
	return inst


# ============================================================================
# EXHIBIT 3 -- ORRERY
# ============================================================================

## A model of a solar system that cannot exist.
##
## Bounding box 1.58 W x 1.25 H x 1.61 D. The rings are deliberately off-centre,
## so the extents are asymmetric: x -0.86 .. +0.73, z -0.71 .. +0.91 (the widest
## reach is an outer-track segment, whose tangent yaw grows its own box). Both
## stay inside the 2.25 m glass case, with 0.22 m to spare on the tight axis (+z,
## the missing quarter of the outer track) and 0.27 m on -x.
##
## What is wrong with it. The three orbits do not share a centre -- each ring
## is offset from the last, so the dead sun in the middle is at the centre of
## exactly one of them. The middle planet sits well inside its own ring on an
## arm that reaches all the way out to it, as though the planet slid down. The
## outer orbit is missing a quarter: eleven brass segments and then nothing,
## with the last planet parked in the gap where the track should be. The sun
## itself is a matte black ball inside a cold ring of light, which is not what
## a sun does.
##
## PLACEMENT. `origin` is the surface it stands on -- pass
## `exhibit_position + Vector3(0, 0.7, 0)` for FirstMuseumMap._add_exhibit's
## "torus" fallback slot so it stands on the pedestal rather than in it.
static func orrery(parent: Node3D, origin: Vector3, facing_deg := 0.0,
		scale_factor := 1.0) -> Node3D:
	var root := _root(parent, "Orrery", origin, facing_deg, scale_factor)
	var brass := _mat(BRASS, 0.0, 0.5)
	var brass_dim := _mat(BRASS.darkened(0.35), 0.0, 0.5)

	_cylinder(root, "Orrery Plinth", Vector3(0, 0.06, 0), 0.46, 0.12,
		_mat(STONE), true)
	_cylinder(root, "Orrery Plinth Step", Vector3(0, 0.145, 0), 0.30, 0.05,
		_mat(STONE_LIT))
	_cylinder(root, "Orrery Column", Vector3(0, 0.46, 0), 0.075, 0.58,
		brass_dim, true)

	# A sun that has gone out, ringed by light that is not coming from it.
	_sphere(root, "Orrery Dead Sun", Vector3(0, 0.88, 0), 0.16,
		_mat(Color(0.075, 0.075, 0.085)))
	_ring(root, "Orrery Corona", Vector3(0, 0.88, 0), 0.215, 0.028,
		_mat(GLOW, 0.8))

	# radius, height, centre offset. Nothing is concentric.
	var inner_c := Vector2(0.00, 0.00)
	var mid_c := Vector2(0.09, -0.05)
	var outer_c := Vector2(-0.07, 0.10)
	_ring(root, "Orrery Orbit Inner", Vector3(inner_c.x, 0.88, inner_c.y),
		0.42, 0.026, brass)
	_ring(root, "Orrery Orbit Middle", Vector3(mid_c.x, 1.04, mid_c.y),
		0.62, 0.024, brass)

	# The outer orbit is built from segments so it can be missing three of
	# them. A closed TorusMesh cannot have a hole in it.
	var segments := 14
	var outer_r := 0.76
	var gap: Array[int] = [5, 6, 7]
	var seg_len := TAU * outer_r / float(segments) * 1.04
	for k in range(segments):
		if k in gap:
			continue
		var a := TAU * float(k) / float(segments)
		var seg := _box(root, "Orrery Orbit Outer %d" % k,
			Vector3(outer_c.x + cos(a) * outer_r, 1.20,
				outer_c.y + sin(a) * outer_r),
			Vector3(seg_len, 0.024, 0.05), brass)
		# Lay each segment along the tangent at its own angle.
		seg.rotation.y = -(a + PI * 0.5)

	# Planet, ring centre, orbit height, radius the planet actually sits at,
	# angle, body radius, colour. Two of the three are in the wrong place.
	var bodies := [
		[inner_c, 0.88, 0.42, 0.85, 0.055, Color(0.36, 0.38, 0.42)],
		# Slid down its arm: inside a ring it should be standing on.
		[mid_c, 1.04, 0.38, 2.65, 0.075, Color(0.30, 0.24, 0.22)],
		# Parked in the gap in the outer track, at the exact radius of a rail
		# that is not there.
		[outer_c, 1.20, outer_r, TAU * 6.0 / 14.0, 0.050, Color(0.22, 0.26, 0.33)],
	]
	for i in range(bodies.size()):
		var b: Array = bodies[i]
		var c: Vector2 = b[0]
		var y: float = b[1]
		var r: float = b[2]
		var a: float = b[3]
		var body_r: float = b[4]
		var tint: Color = b[5]
		var px: float = c.x + cos(a) * r
		var pz: float = c.y + sin(a) * r
		_sphere(root, "Orrery Body %d" % i, Vector3(px, y, pz), body_r, _mat(tint))
		# The arm runs from the column to the planet -- from the centre the
		# orbits do not share.
		var arm_len := sqrt(px * px + pz * pz)
		if arm_len < 0.02:
			continue
		var arm := _box(root, "Orrery Arm %d" % i,
			Vector3(px * 0.5, y, pz * 0.5),
			Vector3(arm_len, 0.018, 0.018), brass_dim)
		arm.rotation.y = -atan2(pz, px)
	return root


# ============================================================================
# WING DRESSING
# ============================================================================

## A corridor set into a wall whose far end is nearer than it should be.
##
## Bounding box 2.52 W x 2.76 H x 1.85 D, receding along local -Z from the
## mouth at z +0.06 to the back plate at z -1.79. Front face is local +Z.
##
## What is wrong with it. Six frames step back and shrink hard enough to sell
## fifteen metres of corridor in 1.8 m of actual depth. Then the player walks
## in and stops dead 0.64 m from the mouth, head against a lintel, with four
## more doorways still ahead of them. The frames also sink as they recede --
## the centre line drops from 1.30 m to 0.38 m while the floor line RISES from
## 0.00 to 0.08 -- so the corridor reads as plunging away downhill while its
## floor climbs. There is a thin band of cold light along the bottom of the far
## end, the kind you get under a door, at a distance of 1.8 m.
##
## PLACEMENT. `origin` at floor level, at the MOUTH, on the centre line -- so
## the prop needs 1.85 m of clear room BEHIND `origin`, and `origin` itself
## stands 1.85 m off the wall it backs onto, not on it. The back plate spans
## y 0.05..0.91, which crosses a _wall_segment baseboard (y 0..0.22, 0.03 m
## proud of the slab face), so measure the 1.85 m from the baseboard plane and
## leave a hair: origin = wall face -+ (1.85 + 0.03 + margin). It is 2.52 m
## wide -- wider than DOOR_GAP -- and the first three frames are solid, so it
## must never be placed in or across a doorway.
static func false_corridor(parent: Node3D, origin: Vector3,
		facing_deg := 0.0) -> Node3D:
	var root := _root(parent, "False Corridor", origin, facing_deg, 1.0)

	# opening width, opening height, centre y, member thickness, z.
	# Widths shrink by an accelerating ratio (0.81, 0.79, 0.76, 0.72, 0.66):
	# real perspective shrinks by a constant one.
	var frames := [
		[2.20, 2.60, 1.30, 0.16, 0.00],
		[1.78, 2.12, 1.06, 0.14, -0.32],
		[1.40, 1.68, 0.86, 0.12, -0.64],
		[1.06, 1.28, 0.68, 0.10, -0.96],
		[0.76, 0.92, 0.52, 0.09, -1.28],
		[0.50, 0.60, 0.38, 0.08, -1.60],
	]
	for i in range(frames.size()):
		var f: Array = frames[i]
		var w: float = f[0]
		var h: float = f[1]
		var cy: float = f[2]
		var t: float = f[3]
		var z: float = f[4]
		# Each frame is darker than the one in front of it. That is the only
		# depth cue that is honest.
		var shade := _mat(STONE.lerp(VOID, 0.14 * float(i)))
		# Only the first three frames are solid. The player capsule (r 0.35,
		# h 1.8) is already stopped by frame 2's head at y 1.70; colliders on
		# frames 3-5 would be nine more holes for the navmesh bake to erode
		# around and nothing would ever touch them.
		var solid := i <= 2
		# Jambs run from the opening's own floor line upward past the head --
		# never below y 0, or the collider is buried in the floor slab.
		var jamb_h := h + t
		_box(root, "False Corridor Jamb %d L" % i,
			Vector3(-(w * 0.5 + t * 0.5), cy + t * 0.5, z),
			Vector3(t, jamb_h, 0.12), shade, solid)
		_box(root, "False Corridor Jamb %d R" % i,
			Vector3(w * 0.5 + t * 0.5, cy + t * 0.5, z),
			Vector3(t, jamb_h, 0.12), shade, solid)
		_box(root, "False Corridor Head %d" % i,
			Vector3(0, cy + h * 0.5 + t * 0.5, z),
			Vector3(w, t, 0.12), shade, solid)
		# Sills stay 0.04 m proud so nothing here is a step the player or the
		# Curator has to climb.
		_box(root, "False Corridor Sill %d" % i,
			Vector3(0, cy - h * 0.5 + 0.02, z),
			Vector3(w, 0.04, 0.12), _mat(STONE_LIT.lerp(VOID, 0.2 * float(i))))

	_box(root, "False Corridor Far Wall", Vector3(0, 0.48, -1.72),
		Vector3(0.72, 0.86, 0.14), _mat(VOID), true)
	_box(root, "False Corridor Far Seam", Vector3(0, 0.10, -1.645),
		Vector3(0.40, 0.022, 0.02), _mat(GLOW, 1.0))
	return root


## Picture frames nested inside one another with nothing in the middle.
##
## Bounding box 1.45 W x 1.83 H x 0.19 D, growing along local +Z off the wall.
## `origin` is the CENTRE of the outer frame, on the wall face. No colliders:
## this hangs at head height and a collider there is a snag, not a feature.
##
## PLACEMENT. Nothing here reaches back past local z +0.01, so `origin` may sit
## flat on the surface -- but it must be the SURFACE. Aim it at the line
## _add_room centres a wall slab on and 0.14 m of the set is inside the wall,
## which is what happened to all three of dress_wing_c's frames. On a
## _wall_segment wall the surface is not the slab face either: the accent stripe
## at y 1.18..1.32 stands 0.02 m proud of it and a frame hung at head height
## crosses that band, so aim at the trim plane, slab face -+ 0.03.
##
## What is wrong with it. Each frame is 0.74 of the one outside it and turns
## another 6 degrees, so the set winds inward instead of nesting; and the
## innermost frame does not contain a picture, it contains a matte black panel
## the same colour as the far end of everything else in this wing. The frames
## come TOWARD the viewer as they shrink, which is the opposite of what a set
## of nested frames does.
static func nested_frames(parent: Node3D, origin: Vector3, facing_deg := 0.0,
		count := 5) -> Node3D:
	var root := _root(parent, "Nested Frames", origin, facing_deg, 1.0)
	var w := 1.30
	var h := 1.68
	var z := 0.0
	var member := 0.075
	var levels := maxi(1, count)
	for i in range(levels):
		var shade := _mat(BRASS.lerp(VOID, 0.16 * float(i)), 0.0, 0.4)
		var frame := Node3D.new()
		frame.name = "Nested Frame %d" % i
		frame.position = Vector3(0, 0, z + member * 0.5)
		frame.rotation_degrees = Vector3(0, 0, 6.0 * float(i))
		root.add_child(frame)
		_box(frame, "Rail L", Vector3(-(w * 0.5 + member * 0.5), 0, 0),
			Vector3(member, h + member * 2.0, 0.055), shade)
		_box(frame, "Rail R", Vector3(w * 0.5 + member * 0.5, 0, 0),
			Vector3(member, h + member * 2.0, 0.055), shade)
		_box(frame, "Rail T", Vector3(0, h * 0.5 + member * 0.5, 0),
			Vector3(w, member, 0.055), shade)
		_box(frame, "Rail B", Vector3(0, -(h * 0.5 + member * 0.5), 0),
			Vector3(w, member, 0.055), shade)
		if i == levels - 1:
			# Not a canvas. A hole the shape of a canvas.
			_box(frame, "Aperture", Vector3(0, 0, -0.01),
				Vector3(w, h, 0.02), _mat(VOID))
		w *= 0.74
		h *= 0.74
		member *= 0.82
		z += 0.038
	return root


## An inlaid floor grid that does not meet itself.
##
## Bounding box size.x W x 0.02 H x at most size.y D, centred on `origin` at
## floor level (the turned far half is inset so it cannot spill past the
## footprint you asked for). No colliders anywhere -- 0.02 m of brass inlay
## must not appear in the Curator's navmesh -- so this one IS safe to run
## across a doorway.
##
## What is wrong with it. The floor is laid in two halves. The far half is
## turned 3.5 degrees and shifted half a cell, so not one line in it lines up
## with its opposite number across the seam; and the seam is a single straight
## joint, which is exactly what makes the mismatch impossible to explain away
## as a curve. In the near half the cross-lines also tighten as they go back --
## 0.90 m, 0.86, 0.80, 0.72 -- so the near half is quietly running out of floor
## before it reaches the seam. Four lines stop short of the edge and go nowhere.
static func floor_grid(parent: Node3D, origin: Vector3,
		size := Vector2(12.0, 6.4), facing_deg := 0.0) -> Node3D:
	var root := _root(parent, "Floor Grid", origin, facing_deg, 1.0)
	var line := _mat(INLAY, 0.22, 0.4)
	var half_x := size.x * 0.5
	var half_z := size.y * 0.5

	# --- Near half: z 0 .. +half_z, laid straight ---
	var near := Node3D.new()
	near.name = "Floor Grid Near Half"
	root.add_child(near)
	# Cross-lines converge where a floor has no business converging.
	var spacing: Array[float] = [0.90, 0.86, 0.80, 0.72]
	var at := 0.0
	for i in range(spacing.size()):
		at += spacing[i]
		if at > half_z:
			break
		# Two of these stop short and simply end.
		var run: float = size.x if i != 1 else size.x - 2.6
		var shift: float = 0.0 if i != 1 else -1.3
		_box(near, "Floor Grid Near Cross %d" % i, Vector3(shift, 0.011, at),
			Vector3(run, 0.02, 0.045), line)
	var columns := int(floor(size.x / 0.90))
	for j in range(columns + 1):
		var x := -half_x + float(j) * 0.90
		if x > half_x:
			break
		var run_z: float = half_z if j % 5 != 3 else half_z - 1.1
		_box(near, "Floor Grid Near Run %d" % j,
			Vector3(x, 0.011, run_z * 0.5),
			Vector3(0.045, 0.02, run_z), line)

	# --- Far half: z -half_z .. 0, turned and offset ---
	# Inset before rotating so the turned half still fits the declared bounding
	# box; the 3.5 degree turn is what pushes a couple of its lines back across
	# the seam, which is the whole trick.
	var far := Node3D.new()
	far.name = "Floor Grid Far Half"
	far.rotation_degrees = Vector3(0, 3.5, 0)
	root.add_child(far)
	var far_half_x := half_x - 0.30
	var far_half_z := half_z - 0.66
	# Half a cell out of step with the near half, and evenly spaced, which the
	# near half is not.
	var far_at := 0.45
	var k := 0
	while far_at < far_half_z:
		var run: float = far_half_x * 2.0 if k != 2 else far_half_x * 2.0 - 2.0
		_box(far, "Floor Grid Far Cross %d" % k, Vector3(0, 0.011, -far_at),
			Vector3(run, 0.02, 0.045), line)
		far_at += 0.90
		k += 1
	for j in range(columns + 1):
		var x := -far_half_x + float(j) * 0.90 + 0.45
		if x > far_half_x:
			break
		var run_z: float = far_half_z if j % 4 != 2 else far_half_z - 0.9
		_box(far, "Floor Grid Far Run %d" % j,
			Vector3(x, 0.011, -run_z * 0.5),
			Vector3(0.045, 0.02, run_z), line)

	# The seam itself, in two pieces with a gap where they should have met.
	_box(root, "Floor Grid Seam W", Vector3(-half_x * 0.5 - 0.15, 0.012, 0),
		Vector3(half_x - 0.3, 0.022, 0.07), _mat(INLAY.darkened(0.3), 0.10, 0.4))
	_box(root, "Floor Grid Seam E", Vector3(half_x * 0.5 + 0.15, 0.012, 0),
		Vector3(half_x - 0.3, 0.022, 0.07), _mat(INLAY.darkened(0.3), 0.10, 0.4))
	return root


# ============================================================================
# CONVENIENCE PLACEMENT
# ============================================================================

## Place the wing dressing (not the three exhibits) at its intended world
## positions in Space Wing C. One call for the integrator; ignore it and place
## the builders by hand if the wing gets rearranged.
##
## WHERE WING C'S WALLS ACTUALLY ARE. The room is _add_room(centre (24, 0, -24),
## size 22 x 16). _add_room CENTRES each wall slab on C +- (S / 2 -
## WALL_THICKNESS / 2) and gives it WALL_THICKNESS of depth, so the slab's
## room-side FACE -- the only surface a prop can be stood against -- is another
## half thickness inboard, at C +- (S / 2 - WALL_THICKNESS):
##
##   FACES          x 13.35 .. 34.65     z -31.65 .. -16.35
##   slab centres   x 13.175 .. 34.825   z -31.825 .. -16.175   NOT surfaces
##
## Every position in this function used to be aimed at the second row, the same
## mistake _add_wing_dressing spells out for Wings A, B and D. It pushed the
## false corridor 0.16 m of its 1.85 m depth through the north wall and left
## 0.14 m of each 0.19 m frame set -- three quarters of every one of them --
## buried inside the wall it was supposed to hang on.
##
## _wall_segment then dresses each slab with trim standing PROUD of that face:
## baseboard and cornice by 0.03 m (y 0..0.22 and y 3.18..3.34), accent stripe
## by 0.02 m (y 1.18..1.32). So the real inner surface of a wall is face -+ 0.03
## wherever those bands are, and everything below is aimed at that trim plane
## rather than at the slab: 0.02 m clear of the stripe, 0.05 m clear of the slab.
##
## Wing C's only door is on the west wall at (13.35, -24), gap z -24.9 .. -23.1.
## Every position below was checked against that door, against the three exhibit
## pedestals (2.8 x 2.8 m at (24,-20.5), (18.5,-27.5) and (29.5,-27.5)) and
## against the sight lines Камера 07 at (33.6, 2.9, -30.8) needs to the same
## three exhibits. Boxes are world-space, measured off the built tree:
##
##   false_corridor (24.00, 0, -29.80) yaw 0            north wall, mouth south
##       x 22.740..25.260  y 0.000..2.760  z -31.590..-29.740
##   nested_frames  (34.62, 1.55, -21.60) yaw -90       east wall trim plane
##       x 34.424..34.610  y 0.635..2.465  z -22.325..-20.875
##   nested_frames  (13.38, 1.55, -29.60) yaw  90       west wall trim plane
##       x 13.390..13.577  y 0.635..2.465  z -30.325..-28.875
##   nested_frames  (30.00, 1.50, -16.38) yaw 180 n=4   south wall trim plane
##       x 29.275..30.725  y 0.585..2.415  z -16.542..-16.390
##   floor_grid     (24.00, 0, -24.00) 12.0 x 6.4
##       x 17.978..30.000  y 0.001..0.023  z -26.876..-20.800
##
## Union: x 13.390..34.610, y 0.000..2.760, z -31.590..-16.390 -- inside the
## faces on all six sides. Tightest is the corridor's back plate: 0.06 m to the
## north slab, 0.03 m to its baseboard. Then the frames at 0.04 m to their slabs
## and 0.02 m to the accent stripe they hang across. 120 meshes, 162 nodes,
## 10 colliders, all ten of them in the corridor.
##
## The Curator is untouched by any of it. The frames are wall relief and the grid
## is 0.02 m of inlay -- neither carries a collider -- and the only colliders
## added, the corridor's ten, sit 9.39 m east of the west doorway, so the 1.8 m
## gap at (13.35, -24) still bakes to its full width after the 0.45 m erosion.
## The nearest non-collider piece to that gap is the west frame set, 3.98 m north
## of its near edge.
static func dress_wing_c(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Space Wing C Dressing"
	parent.add_child(root)
	# Origin z is the mouth; the prop recedes 1.79 m along -Z from it, so the
	# back plate lands at -31.59. Aiming the mouth at -30.02 (the old value,
	# derived from the -31.825 centre line) drove that plate to -31.81.
	false_corridor(root, Vector3(24.0, 0, -29.80), 0.0)
	nested_frames(root, Vector3(34.62, 1.55, -21.60), -90.0)
	nested_frames(root, Vector3(13.38, 1.55, -29.60), 90.0)
	nested_frames(root, Vector3(30.00, 1.50, -16.38), 180.0, 4)
	floor_grid(root, Vector3(24.0, 0, -24.0), Vector2(12.0, 6.4))
	return root
