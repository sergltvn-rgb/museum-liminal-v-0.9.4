@tool
class_name ExteriorProps
extends RefCounted
## Procedural countryside scenery for the arrival drive: the road from the
## forest to the museum, the forest itself, the mountain backdrop, a river
## with its bridge, classical lamp posts, a bus shelter, the staff parking
## lot with its painted bays, extra parked cars and the player's own sedan
## (which carries a full driver-POV interior).
##
## SELF-CONTAINED BY DESIGN, like every other file in game/props: primitives,
## StandardMaterial3D and a static material cache only. Nothing here preloads
## or references another project script.
##
## ---------------------------------------------------------------------------
## LOCAL FRAME
## ---------------------------------------------------------------------------
## Every builder takes (parent, origin, yaw_deg) and authors children in the
## root's LOCAL space. For the vehicles the convention is Godot's own:
## -Z is the nose of the car, +X its right flank, so a root yawed with
## rotation.y drives "forward" along its own -Z.
##
## ---------------------------------------------------------------------------
## COLLISION — DELIBERATELY NONE
## ---------------------------------------------------------------------------
## This whole set is cutscene scenery on the far side of the forecourt lot
## walls, which the player cannot climb (1.2 m against a 1.0 m jump apex).
## Not one node here gets a physics body: the navigation bake parses static
## colliders, and a collider-free set costs the bake and the physics server
## nothing at all.
##
## ---------------------------------------------------------------------------
## CULLING
## ---------------------------------------------------------------------------
## The set stretches ~230 m down the road, so the museum's blanket 115 m
## visibility range would pop whole shots in and out mid-drive. Every builder
## passes its own range through `vis` instead: 0.0 means "never cull" and is
## reserved for the ground planes and the mountain backdrop, which must
## survive every camera position of the cutscene.

# --- Palette ------------------------------------------------------------------
# Overcast-afternoon country palette, tuned to sit against the existing
# forecourt (grass 0.34/0.37/0.31, asphalt 0.16/0.17/0.19) without repainting
# either. Warm lamp glow matches FacadeProps' COL_LAMP_GLOW family.

const MatLib := preload("res://game/props/MaterialLib.gd")

const COL_GRASS := Color(0.31, 0.36, 0.27)
const COL_EARTH := Color(0.36, 0.30, 0.22)
const COL_ASPHALT := Color(0.16, 0.17, 0.19)
const COL_SHOULDER := Color(0.42, 0.40, 0.35)
const COL_MARKING := Color(0.88, 0.84, 0.65)
const COL_BAY_LINE := Color(0.85, 0.85, 0.82)
const COL_BARK_OAK := Color(0.30, 0.23, 0.15)
const COL_BARK_PINE := Color(0.33, 0.24, 0.16)
const COL_BARK_BIRCH := Color(0.80, 0.79, 0.74)
const COL_BIRCH_MARK := Color(0.14, 0.13, 0.12)
const COL_LEAF_OAK := Color(0.21, 0.32, 0.15)
const COL_LEAF_PINE := Color(0.13, 0.24, 0.14)
const COL_LEAF_BIRCH := Color(0.30, 0.40, 0.18)
const COL_MOUNT_NEAR := Color(0.33, 0.36, 0.34)
const COL_MOUNT_MID := Color(0.44, 0.48, 0.50)
const COL_MOUNT_FAR := Color(0.58, 0.63, 0.70)
const COL_SNOW := Color(0.82, 0.85, 0.88)
const COL_WATER := Color(0.16, 0.26, 0.32)
const COL_ROCK := Color(0.45, 0.44, 0.41)
const COL_IRON := Color(0.12, 0.13, 0.14)
const COL_BRONZE := Color(0.35, 0.30, 0.20)
const COL_LAMP_GLOW := Color(0.95, 0.83, 0.55)
const COL_CONCRETE := Color(0.58, 0.57, 0.54)
const COL_WOOD := Color(0.42, 0.32, 0.20)
const COL_SIGN := Color(0.20, 0.32, 0.55)
const COL_GLASS_TINT := Color(0.10, 0.13, 0.16, 0.35)
const COL_CAR_TRIM := Color(0.09, 0.09, 0.10)
const COL_CAR_INTERIOR := Color(0.13, 0.12, 0.11)
const COL_CAR_SEAT := Color(0.22, 0.19, 0.15)
const COL_HEADLIGHT := Color(0.92, 0.90, 0.80)
const COL_TAILLIGHT := Color(0.55, 0.10, 0.08)

## Driver eye point of build_player_car(), in the car's LOCAL frame: left-hand
## seat, behind the wheel, under the roof (roof soffit 1.32). The map's driving
## cutscene adds this (yaw-rotated) to the car origin to place its POV camera,
## so dash, wheel, mirror, pillars and hood all hold their screen positions.
const DRIVER_EYE := Vector3(-0.37, 1.08, 0.12)

# --- Static caches ------------------------------------------------------------

static var _materials: Dictionary = {}
static var _roughness_noise: NoiseTexture2D = null
static var _normal_noise: NoiseTexture2D = null


# ===========================================================================
# Primitive layer — mirrors FacadeProps so a reader is never surprised.
# ===========================================================================


static func _root(parent: Node3D, node_name: String, origin: Vector3,
		yaw_deg: float) -> Node3D:
	var root := Node3D.new()
	if parent.has_node(NodePath(node_name)):
		node_name = "%s %s" % [node_name, origin]
	root.name = node_name
	root.position = origin
	root.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(root)
	return root


static func _box(parent: Node3D, node_name: String, box_position: Vector3,
		size: Vector3, color: Color, vis := 130.0, emission_energy := 0.0,
		metallic := 0.0, transparent := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _primitive(parent, node_name, box_position, mesh, size, color,
		transparent, emission_energy, metallic, vis)


static func _cylinder(parent: Node3D, node_name: String,
		cylinder_position: Vector3, radius: float, height: float, color: Color,
		vis := 130.0, emission_energy := 0.0, metallic := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = radius
	mesh.top_radius = radius
	mesh.radial_segments = 8 if radius < 0.12 else 12
	mesh.rings = 1
	return _primitive(parent, node_name, cylinder_position, mesh,
		Vector3(radius * 2.0, height, radius * 2.0), color, false,
		emission_energy, metallic, vis)


static func _cone(parent: Node3D, node_name: String, cone_position: Vector3,
		bottom_radius: float, top_radius: float, height: float, color: Color,
		vis := 130.0, emission_energy := 0.0, metallic := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.radial_segments = 10
	mesh.rings = 1
	var max_radius: float = maxf(bottom_radius, top_radius)
	return _primitive(parent, node_name, cone_position, mesh,
		Vector3(max_radius * 2.0, height, max_radius * 2.0), color, false,
		emission_energy, metallic, vis)


static func _sphere(parent: Node3D, node_name: String, sphere_position: Vector3,
		radius: float, color: Color, vis := 130.0,
		emission_energy := 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	return _primitive(parent, node_name, sphere_position, mesh,
		Vector3(radius * 2.0, radius * 2.0, radius * 2.0), color, false,
		emission_energy, 0.0, vis)


static func _prism(parent: Node3D, node_name: String, prism_position: Vector3,
		size: Vector3, color: Color, vis := 130.0,
		emission_energy := 0.0) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _primitive(parent, node_name, prism_position, mesh, size, color,
		false, emission_energy, 0.0, vis)


static func _torus(parent: Node3D, node_name: String, torus_position: Vector3,
		inner_radius: float, outer_radius: float, color: Color,
		vis := 130.0) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 16
	mesh.ring_segments = 6
	var thickness := outer_radius - inner_radius
	return _primitive(parent, node_name, torus_position, mesh,
		Vector3(outer_radius * 2.0, thickness, outer_radius * 2.0), color,
		false, 0.0, 0.0, vis)


static func _primitive(parent: Node3D, node_name: String,
		prim_position: Vector3, mesh: PrimitiveMesh, size: Vector3,
		color: Color, transparent: bool, emission_energy: float,
		metallic: float, vis: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	# Repeated sibling names make Godot fall back to @MeshInstance3D@NNN, which
	# no test or feed can address. Tag the twin with its local offset instead.
	if parent.has_node(NodePath(node_name)):
		node_name = "%s %s" % [node_name, prim_position]
	instance.name = node_name
	instance.position = prim_position
	instance.mesh = mesh
	instance.material_override = _material(color, transparent, emission_energy,
		metallic)
	if vis > 0.0:
		instance.visibility_range_end = vis
		instance.visibility_range_fade_mode = \
			GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if size.length() < 0.65:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## Цвет улицы -> набор карт. Дорога, обочина и парковка занимают нижнюю
## треть экрана всю катсцену приезда — это самая долго рассматриваемая
## поверхность в игре. Кроны, трава, горы и вода остаются на шуме.
static func _pack_for(color: Color) -> String:
	if color.is_equal_approx(COL_ASPHALT):
		return "asphalt"
	if color.is_equal_approx(COL_SHOULDER) or color.is_equal_approx(COL_EARTH) \
			or color.is_equal_approx(COL_ROCK):
		return "dirt"
	if color.is_equal_approx(COL_CONCRETE):
		return "concrete"
	if color.is_equal_approx(COL_WOOD):
		return "wood"
	if color.is_equal_approx(COL_IRON) or color.is_equal_approx(COL_BRONZE):
		return "painted_metal"
	if color.is_equal_approx(COL_CAR_TRIM) or color.is_equal_approx(COL_CAR_INTERIOR) \
			or color.is_equal_approx(COL_CAR_SEAT):
		return "plastic_worn"
	return ""


static func _material(color: Color, transparent: bool,
		emission_energy: float, metallic: float) -> StandardMaterial3D:
	var key := "%s:%s:%s:%s" % [color.to_html(true), transparent,
		emission_energy, metallic]
	if _materials.has(key):
		return _materials[key]

	if not transparent and emission_energy <= 0.0:
		var pack := _pack_for(color)
		if not pack.is_empty():
			var photo := MatLib.get_material(pack, color)
			_materials[key] = photo
			return photo

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = clampf(0.68 - metallic * 0.4, 0.12, 1.0)
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

	# Same restrained grain policy as FacadeProps: matte natural surfaces get
	# noise, glass / lit / metallic surfaces stay clean.
	if not transparent and metallic < 0.35 and emission_energy <= 0.0:
		mat.roughness_texture = _shared_roughness_noise()
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.normal_enabled = true
		mat.normal_texture = _shared_normal_noise()
		mat.normal_scale = 0.08
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
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


# ===========================================================================
# Trees — three species, each with seeded variation so no two copies of the
# same builder read as clones: scale, yaw, crown asymmetry and (for the
# birch) the bark-mark pattern all come from the per-tree RNG.
# ===========================================================================


## Broadleaf oak: a leaning two-piece trunk, one heavy bough and a cluster of
## 4-5 crown spheres pushed off-axis by the seed. ~9-11 m tall at scale 1.
static func build_oak(parent: Node3D, origin: Vector3, seed_value: int,
		vis := 160.0) -> Node3D:
	var rng := _rng(seed_value)
	var s := rng.randf_range(0.8, 1.2)
	var root := _root(parent, "Oak Tree", origin, rng.randf_range(0.0, 360.0))
	var lean := rng.randf_range(2.0, 7.0)
	var lower := _cone(root, "Trunk Lower", Vector3(0, 1.5 * s, 0),
		0.34 * s, 0.26 * s, 3.0 * s, COL_BARK_OAK, vis)
	lower.rotation_degrees.z = lean
	var upper := _cone(root, "Trunk Upper", Vector3(0.28 * s, 3.9 * s, 0),
		0.24 * s, 0.14 * s, 2.4 * s, COL_BARK_OAK, vis)
	upper.rotation_degrees.z = lean + rng.randf_range(4.0, 9.0)
	var bough := _cone(root, "Bough", Vector3(-0.5 * s, 3.4 * s, 0.3 * s),
		0.13 * s, 0.06 * s, 1.9 * s, COL_BARK_OAK, vis)
	bough.rotation_degrees = Vector3(rng.randf_range(15.0, 30.0), 0.0, -38.0)
	var crowns := 4 + (seed_value % 2)
	for i in range(crowns):
		var a := TAU * float(i) / float(crowns) + rng.randf_range(-0.4, 0.4)
		var r := rng.randf_range(0.5, 1.15) * s
		_sphere(root, "Crown %d" % i,
			Vector3(0.25 * s + cos(a) * r, (5.6 + rng.randf_range(-0.5, 0.9)) * s,
				sin(a) * r),
			rng.randf_range(1.15, 1.75) * s, COL_LEAF_OAK, vis)
	_sphere(root, "Crown Top", Vector3(0.3 * s, 6.9 * s, 0.0),
		rng.randf_range(1.0, 1.3) * s, COL_LEAF_OAK, vis)
	return root


## Conifer pine: straight trunk and 3-4 cone tiers that shrink upward, each
## tier nudged slightly off the axis so the silhouette is not a lathe.
static func build_pine(parent: Node3D, origin: Vector3, seed_value: int,
		vis := 160.0) -> Node3D:
	var rng := _rng(seed_value)
	var s := rng.randf_range(0.8, 1.3)
	var root := _root(parent, "Pine Tree", origin, rng.randf_range(0.0, 360.0))
	_cone(root, "Trunk", Vector3(0, 2.4 * s, 0), 0.26 * s, 0.12 * s, 4.8 * s,
		COL_BARK_PINE, vis)
	var tiers := 3 + (seed_value % 2)
	for i in range(tiers):
		var t := float(i)
		_cone(root, "Tier %d" % i,
			Vector3(rng.randf_range(-0.15, 0.15) * s,
				(3.0 + 1.75 * t) * s,
				rng.randf_range(-0.15, 0.15) * s),
			(2.1 - 0.42 * t) * s, 0.05 * s,
			(2.4 - 0.22 * t) * s, COL_LEAF_PINE, vis)
	return root


## Birch: slim pale trunk with seeded dark bark marks and two light, airy
## crown spheres. Reads as a different species even at cutscene speed.
static func build_birch(parent: Node3D, origin: Vector3, seed_value: int,
		vis := 160.0) -> Node3D:
	var rng := _rng(seed_value)
	var s := rng.randf_range(0.85, 1.15)
	var root := _root(parent, "Birch Tree", origin, rng.randf_range(0.0, 360.0))
	var trunk := _cone(root, "Trunk", Vector3(0, 3.0 * s, 0),
		0.16 * s, 0.07 * s, 6.0 * s, COL_BARK_BIRCH, vis)
	trunk.rotation_degrees.z = rng.randf_range(-4.0, 4.0)
	for i in range(4):
		var my := (0.8 + 1.3 * float(i) + rng.randf_range(-0.25, 0.25)) * s
		var mark := _box(root, "Bark Mark %d" % i,
			Vector3(rng.randf_range(-0.02, 0.02) * s, my,
				(0.135 - 0.011 * float(i)) * s),
			Vector3(0.10 * s, 0.06 * s, 0.05 * s), COL_BIRCH_MARK, vis)
		mark.rotation_degrees.y = rng.randf_range(-25.0, 25.0)
	_sphere(root, "Crown Lower",
		Vector3(rng.randf_range(-0.35, 0.35) * s, 5.0 * s,
			rng.randf_range(-0.35, 0.35) * s),
		rng.randf_range(0.95, 1.25) * s, COL_LEAF_BIRCH, vis)
	_sphere(root, "Crown Upper", Vector3(0.1 * s, 6.15 * s, 0.0),
		rng.randf_range(0.7, 0.95) * s, COL_LEAF_BIRCH, vis)
	return root


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# ===========================================================================
# Street furniture
# ===========================================================================


## Classical lamp post to match the museum facade: stepped pedestal, turned
## column with base and neck rings, a curved bracket and a warm glass lantern
## under a bronze cap. No Light3D on purpose — the map's light budget is
## verified, so the glow is emissive like the forecourt lamps.
static func build_lamp_post(parent: Node3D, origin: Vector3, yaw_deg := 0.0,
		vis := 150.0) -> Node3D:
	var root := _root(parent, "Country Lamp", origin, yaw_deg)
	_box(root, "Pedestal", Vector3(0, 0.14, 0), Vector3(0.46, 0.28, 0.46),
		COL_CONCRETE, vis)
	_box(root, "Pedestal Cap", Vector3(0, 0.31, 0), Vector3(0.36, 0.06, 0.36),
		COL_IRON, vis, 0.0, 0.5)
	_torus(root, "Base Ring", Vector3(0, 0.40, 0), 0.055, 0.135, COL_IRON, vis)
	_cone(root, "Column", Vector3(0, 2.05, 0), 0.085, 0.055, 3.3, COL_IRON,
		vis, 0.0, 0.5)
	_torus(root, "Neck Ring", Vector3(0, 3.68, 0), 0.035, 0.085, COL_IRON, vis)
	var arm := _cone(root, "Bracket", Vector3(0, 3.86, -0.24),
		0.045, 0.03, 0.62, COL_IRON, vis, 0.0, 0.5)
	arm.rotation_degrees.x = 65.0
	_box(root, "Lantern Body", Vector3(0, 3.94, -0.5),
		Vector3(0.26, 0.4, 0.26), COL_BRONZE, vis, 0.0, 0.6)
	_box(root, "Lantern Glass", Vector3(0, 3.94, -0.5),
		Vector3(0.2, 0.3, 0.2), COL_LAMP_GLOW, vis, 1.2)
	_cone(root, "Lantern Cap", Vector3(0, 4.19, -0.5), 0.19, 0.03, 0.13,
		COL_BRONZE, vis, 0.0, 0.6)
	return root


## Bus shelter: concrete pad, three-sided iron-and-glass pavilion, wooden
## bench and a route sign on its own pole. Opening faces local -Z (the road).
static func build_bus_stop(parent: Node3D, origin: Vector3,
		yaw_deg := 0.0, vis := 150.0) -> Node3D:
	var root := _root(parent, "Bus Stop", origin, yaw_deg)
	_box(root, "Pad", Vector3(0, 0.05, 0.2), Vector3(4.6, 0.1, 2.6),
		COL_CONCRETE, vis)
	for side: float in [-1.0, 1.0]:
		var side_name := "West" if side < 0.0 else "East"
		_box(root, "Post Front %s" % side_name,
			Vector3(side * 1.9, 1.35, -0.7), Vector3(0.1, 2.5, 0.1),
			COL_IRON, vis, 0.0, 0.5)
		_box(root, "Post Back %s" % side_name,
			Vector3(side * 1.9, 1.35, 1.1), Vector3(0.1, 2.5, 0.1),
			COL_IRON, vis, 0.0, 0.5)
		_box(root, "Side Glass %s" % side_name,
			Vector3(side * 1.9, 1.45, 0.2), Vector3(0.04, 1.7, 1.7),
			COL_GLASS_TINT, vis, 0.0, 0.0, true)
	_box(root, "Back Glass", Vector3(0, 1.45, 1.12), Vector3(3.7, 1.7, 0.04),
		COL_GLASS_TINT, vis, 0.0, 0.0, true)
	_box(root, "Roof", Vector3(0, 2.66, 0.2), Vector3(4.3, 0.12, 2.5),
		COL_IRON, vis, 0.0, 0.5)
	_box(root, "Roof Trim", Vector3(0, 2.58, -1.02), Vector3(4.3, 0.16, 0.06),
		COL_BRONZE, vis, 0.0, 0.6)
	_box(root, "Bench Seat", Vector3(0, 0.52, 0.7), Vector3(2.8, 0.09, 0.5),
		COL_WOOD, vis)
	_box(root, "Bench Back", Vector3(0, 0.92, 0.96), Vector3(2.8, 0.45, 0.07),
		COL_WOOD, vis)
	for side: float in [-1.0, 1.0]:
		_box(root, "Bench Leg %s" % ("West" if side < 0.0 else "East"),
			Vector3(side * 1.2, 0.28, 0.7), Vector3(0.1, 0.38, 0.44),
			COL_IRON, vis, 0.0, 0.5)
	_cylinder(root, "Sign Pole", Vector3(2.6, 1.35, -0.9), 0.045, 2.7,
		COL_IRON, vis, 0.0, 0.5)
	_box(root, "Sign Board", Vector3(2.6, 2.5, -0.9), Vector3(0.56, 0.42, 0.05),
		COL_SIGN, vis, 0.25)
	_box(root, "Sign Stripe", Vector3(2.6, 2.5, -0.93), Vector3(0.42, 0.1, 0.02),
		COL_BAY_LINE, vis, 0.25)
	return root


# ===========================================================================
# Landscape
# ===========================================================================


## One row of low-poly ridge prisms along local +X. `tone` picks the plane:
## 0 = near (dark), 1 = mid, 2 = far (light, hazy, snow caps). Peaks are
## seeded so the three planes never repeat the same skyline.
static func build_mountain_range(parent: Node3D, origin: Vector3, length: float,
		tone: int, seed_value: int, yaw_deg := 0.0) -> Node3D:
	var rng := _rng(seed_value)
	var root := _root(parent, "Mountain Range %d" % tone, origin, yaw_deg)
	var color := COL_MOUNT_NEAR
	var base_h := 16.0
	var depth := 26.0
	if tone == 1:
		color = COL_MOUNT_MID
		base_h = 26.0
		depth = 34.0
	elif tone >= 2:
		color = COL_MOUNT_FAR
		base_h = 38.0
		depth = 46.0
	var x := 0.0
	var peak := 0
	while x < length:
		var w := rng.randf_range(0.8, 1.4) * base_h * 1.7
		var h := rng.randf_range(0.7, 1.25) * base_h
		var cx := x + w * 0.5
		# Mountains never cull: they are the horizon of every drive shot.
		_prism(root, "Peak %d" % peak,
			Vector3(cx, h * 0.5, rng.randf_range(-0.12, 0.12) * depth),
			Vector3(w, h, depth), color, 0.0)
		if tone >= 2 and h > base_h:
			# Snow cap on the tall far peaks only: a smaller prism seated into
			# the summit, 4% proud of the parent's slope so no face is shared.
			_prism(root, "Snow Cap %d" % peak,
				Vector3(cx, h * 0.82, 0.0),
				Vector3(w * 0.30, h * 0.30, depth * 1.04), COL_SNOW, 0.0)
		x += w * rng.randf_range(0.55, 0.8)
		peak += 1
	return root


## River segment running along local +Z: water ribbon, two earth banks and a
## seeded scatter of rocks. The water sits 1 cm above the terrain slab the
## caller lays underneath, so it reads as a surface, never fights it.
static func build_river(parent: Node3D, origin: Vector3, length: float,
		width: float, seed_value: int, yaw_deg := 0.0) -> Node3D:
	var rng := _rng(seed_value)
	var root := _root(parent, "River", origin, yaw_deg)
	# Slight gloss: metallic 0.4 keeps the noise grain off and adds the sheen.
	_box(root, "Water", Vector3(0, -0.02, length * 0.5),
		Vector3(width, 0.05, length), COL_WATER, 0.0, 0.0, 0.4)
	for side: float in [-1.0, 1.0]:
		var bank_name := "West" if side < 0.0 else "East"
		_box(root, "Bank %s" % bank_name,
			Vector3(side * (width * 0.5 + 0.55), 0.02, length * 0.5),
			Vector3(1.1, 0.12, length), COL_EARTH, 0.0)
	for i in range(7):
		var rz := rng.randf_range(2.0, length - 2.0)
		var rx := rng.randf_range(-0.42, 0.42) * width
		_sphere(root, "Rock %d" % i, Vector3(rx, 0.02, rz),
			rng.randf_range(0.2, 0.5), COL_ROCK, 170.0)
	return root


## Road bridge over the river: two abutments, a deck slab that carries the
## road surface across, and stone parapets with end posts. Spans local X,
## `span` wide; deck top sits at the same 0.01 the road surface uses.
static func build_bridge(parent: Node3D, origin: Vector3, span: float,
		road_width: float, yaw_deg := 0.0, vis := 170.0) -> Node3D:
	var root := _root(parent, "River Bridge", origin, yaw_deg)
	var half := span * 0.5
	_box(root, "Deck", Vector3(0, -0.12, 0),
		Vector3(span, 0.26, road_width + 1.2), COL_CONCRETE, vis)
	for side: float in [-1.0, 1.0]:
		var side_name := "North" if side < 0.0 else "South"
		var pz := side * (road_width * 0.5 + 0.42)
		_box(root, "Parapet %s" % side_name, Vector3(0, 0.36, pz),
			Vector3(span, 0.7, 0.3), COL_CONCRETE, vis)
		_box(root, "Parapet Rail %s" % side_name, Vector3(0, 0.76, pz),
			Vector3(span + 0.2, 0.1, 0.4), COL_ROCK, vis)
		for ex: float in [-half, half]:
			_box(root, "Bridge Post %s %.0f" % [side_name, ex],
				Vector3(ex, 0.55, pz), Vector3(0.5, 1.1, 0.5), COL_ROCK, vis)
	for ex: float in [-half + 0.6, half - 0.6]:
		_box(root, "Abutment %.0f" % ex, Vector3(ex, -0.85, 0),
			Vector3(1.2, 1.5, road_width + 1.6), COL_ROCK, vis)
	return root


# ===========================================================================
# Vehicles
# ===========================================================================


## Background parked car: full one-piece silhouette (body, cabin with tinted
## glass, bumpers, wheels, lights) but no interior — it is set dressing.
## Local -Z is the nose.
static func build_parked_car(parent: Node3D, origin: Vector3, color: Color,
		yaw_deg := 0.0, vis := 150.0) -> Node3D:
	var root := _root(parent, "Parked Car", origin, yaw_deg)
	_box(root, "Body", Vector3(0, 0.55, 0), Vector3(1.76, 0.52, 4.1),
		color, vis, 0.0, 0.45)
	_box(root, "Cabin", Vector3(0, 1.06, 0.25), Vector3(1.6, 0.5, 2.0),
		color, vis, 0.0, 0.45)
	_box(root, "Windshield", Vector3(0, 1.06, -0.79),
		Vector3(1.5, 0.44, 0.06), COL_GLASS_TINT, vis, 0.0, 0.0, true)
	_box(root, "Rear Glass", Vector3(0, 1.06, 1.29),
		Vector3(1.5, 0.44, 0.06), COL_GLASS_TINT, vis, 0.0, 0.0, true)
	for side: float in [-1.0, 1.0]:
		_box(root, "Side Glass %s" % ("L" if side < 0.0 else "R"),
			Vector3(side * 0.79, 1.06, 0.25), Vector3(0.05, 0.4, 1.8),
			COL_GLASS_TINT, vis, 0.0, 0.0, true)
	_box(root, "Bumper Front", Vector3(0, 0.4, -2.08), Vector3(1.78, 0.22, 0.14),
		COL_CAR_TRIM, vis, 0.0, 0.3)
	_box(root, "Bumper Rear", Vector3(0, 0.4, 2.08), Vector3(1.78, 0.22, 0.14),
		COL_CAR_TRIM, vis, 0.0, 0.3)
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		_box(root, "Headlight %s" % tag, Vector3(side * 0.62, 0.62, -2.06),
			Vector3(0.34, 0.14, 0.06), COL_HEADLIGHT, vis, 0.3)
		_box(root, "Taillight %s" % tag, Vector3(side * 0.62, 0.62, 2.06),
			Vector3(0.34, 0.14, 0.06), COL_TAILLIGHT, vis, 0.3)
		for wz: float in [-1.32, 1.32]:
			var wheel := _cylinder(root, "Wheel %s %.0f" % [tag, wz],
				Vector3(side * 0.83, 0.33, wz), 0.33, 0.24, COL_CAR_TRIM, vis)
			wheel.rotation_degrees.z = 90.0
	return root


## The player's own sedan. Exterior matches build_parked_car's silhouette;
## on top of it the cabin is genuinely hollow and furnished for the
## from-behind-the-wheel POV at DRIVER_EYE: dashboard, instrument cowl,
## steering wheel on its column, rear-view mirror, A-pillars, roof soffit,
## seats — and the hood falls exactly into the bottom of a 66-degree frame.
static func build_player_car(parent: Node3D, origin: Vector3,
		yaw_deg := 0.0, vis := 170.0) -> Node3D:
	var color := Color(0.36, 0.33, 0.28)  # service-issue beige, museum motor pool
	var root := _root(parent, "Player Car", origin, yaw_deg)

	# --- Exterior shell -----------------------------------------------------
	_box(root, "Body", Vector3(0, 0.55, 0.35), Vector3(1.78, 0.52, 3.4),
		color, vis, 0.0, 0.45)
	_box(root, "Hood", Vector3(0, 0.86, -1.62), Vector3(1.7, 0.1, 1.35),
		color, vis, 0.0, 0.45)
	_box(root, "Nose", Vector3(0, 0.58, -2.2), Vector3(1.74, 0.46, 0.5),
		color, vis, 0.0, 0.45)
	_box(root, "Trunk Lid", Vector3(0, 0.86, 1.75), Vector3(1.7, 0.1, 0.9),
		color, vis, 0.0, 0.45)
	_box(root, "Bumper Front", Vector3(0, 0.4, -2.48), Vector3(1.8, 0.22, 0.14),
		COL_CAR_TRIM, vis, 0.0, 0.3)
	_box(root, "Bumper Rear", Vector3(0, 0.4, 2.24), Vector3(1.8, 0.22, 0.14),
		COL_CAR_TRIM, vis, 0.0, 0.3)
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		_box(root, "Headlight %s" % tag, Vector3(side * 0.62, 0.64, -2.44),
			Vector3(0.34, 0.15, 0.06), COL_HEADLIGHT, vis, 0.35)
		_box(root, "Taillight %s" % tag, Vector3(side * 0.62, 0.64, 2.22),
			Vector3(0.34, 0.15, 0.06), COL_TAILLIGHT, vis, 0.35)
		_box(root, "Mirror Arm %s" % tag, Vector3(side * 0.95, 1.0, -0.78),
			Vector3(0.14, 0.04, 0.05), COL_CAR_TRIM, vis, 0.0, 0.3)
		_box(root, "Wing Mirror %s" % tag, Vector3(side * 1.06, 1.02, -0.78),
			Vector3(0.08, 0.14, 0.2), COL_CAR_TRIM, vis, 0.0, 0.3)
		for wz: float in [-1.42, 1.32]:
			var wheel := _cylinder(root, "Wheel %s %.1f" % [tag, wz],
				Vector3(side * 0.84, 0.34, wz), 0.34, 0.25, COL_CAR_TRIM, vis)
			wheel.rotation_degrees.z = 90.0
			_sphere(root, "Hubcap %s %.1f" % [tag, wz],
				Vector3(side * 0.965, 0.34, wz), 0.09, COL_CONCRETE, vis)

	# --- Cabin shell: hollow, so the POV sees out ----------------------------
	# Floor pan, firewall behind the engine bay, rear bulkhead, roof.
	_box(root, "Cabin Floor", Vector3(0, 0.42, 0.45), Vector3(1.7, 0.06, 2.1),
		COL_CAR_INTERIOR, vis)
	_box(root, "Firewall", Vector3(0, 0.72, -0.72), Vector3(1.7, 0.55, 0.08),
		COL_CAR_INTERIOR, vis)
	_box(root, "Rear Bulkhead", Vector3(0, 0.95, 1.42), Vector3(1.66, 1.0, 0.08),
		COL_CAR_INTERIOR, vis)
	_box(root, "Roof", Vector3(0, 1.38, 0.35), Vector3(1.64, 0.09, 1.9),
		color, vis, 0.0, 0.45)
	_box(root, "Roof Soffit", Vector3(0, 1.32, 0.35), Vector3(1.56, 0.03, 1.8),
		COL_CAR_INTERIOR, vis)
	for side: float in [-1.0, 1.0]:
		var tag := "L" if side < 0.0 else "R"
		# Doors: solid below the belt line, glass above, so the side windows
		# read from inside as well as outside.
		_box(root, "Door %s" % tag, Vector3(side * 0.86, 0.68, 0.35),
			Vector3(0.07, 0.55, 1.9), color, vis, 0.0, 0.45)
		_box(root, "Door Glass %s" % tag, Vector3(side * 0.84, 1.11, 0.35),
			Vector3(0.04, 0.36, 1.7), COL_GLASS_TINT, vis, 0.0, 0.0, true)
		# A-pillar from the dash corner to the roof's front edge.
		var a_pillar := _box(root, "A Pillar %s" % tag,
			Vector3(side * 0.79, 1.12, -0.63), Vector3(0.09, 0.62, 0.11),
			COL_CAR_INTERIOR, vis)
		a_pillar.rotation_degrees.x = -28.0
		var c_pillar := _box(root, "C Pillar %s" % tag,
			Vector3(side * 0.79, 1.12, 1.33), Vector3(0.09, 0.62, 0.11),
			COL_CAR_INTERIOR, vis)
		c_pillar.rotation_degrees.x = 24.0
	# Raked windshield between the A-pillars; faint tint, fully see-through.
	var windshield := _box(root, "Windshield", Vector3(0, 1.11, -0.62),
		Vector3(1.52, 0.62, 0.03), COL_GLASS_TINT, vis, 0.0, 0.0, true)
	windshield.rotation_degrees.x = -28.0
	var rear_glass := _box(root, "Rear Glass", Vector3(0, 1.11, 1.32),
		Vector3(1.48, 0.6, 0.03), COL_GLASS_TINT, vis, 0.0, 0.0, true)
	rear_glass.rotation_degrees.x = 24.0

	# --- Driver's furniture, framed for DRIVER_EYE ---------------------------
	# Dash top at 0.98: 10 cm under the eye, so it holds the bottom third of
	# the frame with the hood visible past it.
	_box(root, "Dashboard", Vector3(0, 0.9, -0.5), Vector3(1.56, 0.16, 0.42),
		COL_CAR_INTERIOR, vis)
	_box(root, "Dash Top Roll", Vector3(0, 0.995, -0.56), Vector3(1.56, 0.05, 0.34),
		COL_CAR_TRIM, vis)
	_box(root, "Instrument Cowl", Vector3(-0.37, 1.03, -0.44),
		Vector3(0.42, 0.07, 0.16), COL_CAR_TRIM, vis)
	_box(root, "Instrument Dial", Vector3(-0.37, 0.99, -0.415),
		Vector3(0.3, 0.05, 0.02), Color(0.55, 0.75, 0.55), vis, 0.6)
	_box(root, "Center Console", Vector3(0.02, 0.62, -0.1),
		Vector3(0.26, 0.34, 0.85), COL_CAR_INTERIOR, vis)
	_box(root, "Radio Face", Vector3(0.02, 0.86, -0.44),
		Vector3(0.2, 0.08, 0.03), Color(0.7, 0.55, 0.3), vis, 0.4)
	# Steering: column out of the dash, torus rim, three spokes, horn boss.
	var column := _cylinder(root, "Steering Column",
		Vector3(-0.37, 0.83, -0.32), 0.035, 0.3, COL_CAR_TRIM, vis)
	column.rotation_degrees.x = 65.0
	var wheel_rim := _torus(root, "Steering Wheel", Vector3(-0.37, 0.89, -0.2),
		0.155, 0.19, COL_CAR_TRIM, vis)
	wheel_rim.rotation_degrees.x = 65.0
	_sphere(root, "Horn Boss", Vector3(-0.37, 0.89, -0.2), 0.055,
		COL_CAR_TRIM, vis)
	for spoke_deg: float in [0.0, 120.0, 240.0]:
		var spoke := _box(root, "Wheel Spoke %.0f" % spoke_deg,
			Vector3(-0.37, 0.89, -0.2), Vector3(0.03, 0.015, 0.31),
			COL_CAR_TRIM, vis)
		spoke.rotation_degrees = Vector3(65.0 - 90.0, 0.0, 0.0)
		spoke.rotate_object_local(Vector3(0, 1, 0), deg_to_rad(spoke_deg))
	# Rear-view mirror hangs from the roof's front edge, dead centre.
	_box(root, "Mirror Stalk", Vector3(0, 1.27, -0.5),
		Vector3(0.03, 0.08, 0.03), COL_CAR_TRIM, vis)
	_box(root, "Rear View Mirror", Vector3(0, 1.21, -0.48),
		Vector3(0.3, 0.09, 0.03), Color(0.62, 0.68, 0.72), vis, 0.0, 0.6)
	# Two seats; the driver's is the one under DRIVER_EYE.
	for side: float in [-1.0, 1.0]:
		var seat_tag := "Driver" if side < 0.0 else "Passenger"
		_box(root, "%s Seat" % seat_tag, Vector3(side * 0.37, 0.62, 0.35),
			Vector3(0.56, 0.14, 0.6), COL_CAR_SEAT, vis)
		_box(root, "%s Seat Back" % seat_tag, Vector3(side * 0.37, 0.94, 0.68),
			Vector3(0.56, 0.62, 0.14), COL_CAR_SEAT, vis)
	return root
