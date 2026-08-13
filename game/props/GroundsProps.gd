@tool
class_name GroundsProps
extends RefCounted
## The permanent estate the museum stands in: terrain, the service ring road
## around the building, lawns, hedges, flower beds, the boundary wall with its
## gates, tree avenues, the forest belts beyond them, a lake, a river and the
## mountain horizon.
##
## WHY THIS FILE EXISTS
## The museum used to stand on nothing. "Forecourt Ground" covers x -32..32,
## z 35..55 and the drive set lays meadow over x >= 32 -- so the west flank,
## the whole south side and the ground under the building itself were empty
## space, which is what every flank and overview shot looked into.
##
## COLLISION -- DELIBERATELY NONE
## Same rule as ExteriorProps: not one node here gets a physics body. The
## navigation bake parses static colliders, the map's door-channel and
## hide-spot checks weigh meshes against walking channels, and the player is
## fenced into the forecourt by the 1.2 m lot walls anyway. Scenery that
## cannot be reached does not need to be solid.
##
## HEIGHTS, chosen so no two top faces are ever coplanar:
##   ground plate -0.08 | fields -0.05 | water -0.06 | ring road -0.04
##   lawn panels -0.02 | kerb tops 0.06 | painted lines float above their slab
## The drive set's meadow tops out at -0.03 and the forecourt at 0.00, so the
## plate passes safely under both.

# --- Palette ------------------------------------------------------------------

# Только через preload: глобальное имя класса в голом --script-прогоне не
# регистрируется и вся цепочка падает (раздел 14 плана). Объявлен
# выше всех цветов, чтобы порядок объявлений читался сверху вниз.
# На палитру переведено рукотворное: камень, мощение, асфальт,
# металл, дерево. Трава, вода, цветы и камыш остаются своими.
# Производные — `static var`: вызов `tone()` не константное выражение.
const Pal := preload("res://game/props/Palette.gd")
const MuseumModels := preload("res://game/MapModels.gd")

const COL_MEADOW := Color(0.29, 0.35, 0.24)
const COL_LAWN := Color(0.26, 0.38, 0.22)
const COL_FIELD_A := Color(0.35, 0.38, 0.24)
const COL_FIELD_B := Color(0.44, 0.42, 0.26)
const COL_FIELD_C := Color(0.31, 0.37, 0.26)
const COL_HEDGE := Color(0.17, 0.27, 0.16)
const COL_EARTH := Color(0.33, 0.27, 0.20)
static var COL_GRAVEL := Pal.tone(Pal.STONE, -0.19)
static var COL_ASPHALT := Pal.tone(Pal.SLATE, -0.47)
static var COL_KERB := Pal.tone(Pal.STONE, 0.05)
static var COL_STONE := Pal.tone(Pal.STONE, 0.24)
static var COL_STONE_DARK := Pal.tone(Pal.STONE, -0.10)
static var COL_COPING := Pal.tone(Pal.STONE, 0.38)
const COL_WATER := Color(0.17, 0.28, 0.33)
const COL_ROCK := Color(0.44, 0.43, 0.40)
static var COL_IRON := Pal.tone(Pal.STEEL_DARK, -0.29)
static var COL_BRONZE := Pal.tone(Pal.BRASS, -0.30)
const COL_GLOW := Color(0.95, 0.83, 0.55)
const COL_REED := Color(0.36, 0.40, 0.24)
const COL_FLOWER_A := Color(0.72, 0.30, 0.32)
const COL_FLOWER_B := Color(0.84, 0.74, 0.36)
const COL_FLOWER_C := Color(0.56, 0.43, 0.70)
static var COL_WOOD := Pal.tone(Pal.WOOD, 0.10)

# --- Estate geometry ----------------------------------------------------------
# The building's bounding box is x -36..64, z -50..35. Everything below is set
# out from those faces, working outward: lawn, kerb, road, kerb, hedge,
# avenue, wall.

const GROUND_TOP := -0.08
const ROAD_TOP := -0.04
const LAWN_TOP := -0.02

const WEST_ROAD_X := -42.2
const EAST_ROAD_X := 70.2
const SOUTH_ROAD_Z := -56.2
const ROAD_HALF := 3.0

const WEST_LAWN_X := -37.7
const EAST_LAWN_X := 65.6
const SOUTH_LAWN_Z := -51.6
const LAWN_W := 3.0

const WEST_HEDGE_X := -46.6
const EAST_HEDGE_X := 74.6
const SOUTH_HEDGE_Z := -60.6

const WEST_AVENUE_X := -50.5
const EAST_AVENUE_X := 79.0
const SOUTH_AVENUE_Z := -65.0

const WALL_WEST_X := -56.0
const WALL_EAST_X := 85.0
const WALL_SOUTH_Z := -70.0
const WALL_NORTH_Z := 34.0

# The ring's legs meet edge to edge rather than overlapping: two coplanar road
# slabs sharing a corner would z-fight along the whole seam.
const RING_Z_MIN := -53.2
const RING_WEST_Z_MAX := 30.0
const RING_EAST_Z_MAX := 20.0
const RING_X_MIN := -45.2
const RING_X_MAX := 73.2

# --- Static caches ------------------------------------------------------------

static var _materials: Dictionary = {}
static var _grain_cache: Dictionary = {}
static var _bump_cache: Dictionary = {}


# ===========================================================================
#  Entry point
# ===========================================================================


static func build_grounds(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Museum Grounds"
	parent.add_child(root)

	_terrain(root)
	_fields(root)
	_horizon(root)
	_water(root)
	_forest(root)
	_boundary(root)
	_ring_road(root)
	_planting(root)
	_fixtures(root)


# ===========================================================================
#  Procedural surfaces
#
#  Every ground material is generated at load: a seamless FastNoiseLite field
#  driving albedo through a grey colour ramp, the same field again as a normal
#  map, and a second octave set for roughness. The ramp is deliberately grey
#  so one texture serves every tint -- albedo_color multiplies it, which is
#  how grass, ochre stubble and olive pasture all come off one grass grain.
#  Everything is triplanar, so a 760 m plate and a 0.4 m kerb get the same
#  physical grain size without a single UV being authored.
# ===========================================================================


const MatLib := preload("res://game/props/MaterialLib.gd")

## Где у нас есть фотоскан — он бьёт любой шум. Шум даёт разнотон, но не
## даёт камешков в асфальте, колеи на грунте и сколов на камне — а именно
## это игрок видит у себя под ногами всю дорогу от машины до крыльца.
## Трава, листва и вода остаются процедурными: подходящих сканов нет, а
## шум на них читается честно.
const PHOTO_PACKS := {
	"asphalt": "asphalt",
	"gravel": "dirt",
	"earth": "dirt",
	"stone": "quartzite",
	"metal": "steel",
}

## kind -> [frequency, octaves, ramp_low, ramp_high, uv_scale, roughness,
##          normal_scale, metallic]
const SURFACES := {
	"grass": [0.42, 4, 0.58, 1.20, 0.85, 0.96, 0.45, 0.0],
	"meadow": [0.22, 4, 0.66, 1.16, 0.40, 0.96, 0.35, 0.0],
	"asphalt": [1.30, 3, 0.82, 1.10, 0.70, 0.88, 0.30, 0.0],
	"gravel": [2.10, 4, 0.70, 1.24, 1.25, 0.94, 0.60, 0.0],
	"stone": [0.55, 3, 0.84, 1.12, 0.38, 0.72, 0.28, 0.0],
	"earth": [0.75, 4, 0.68, 1.18, 0.60, 0.95, 0.40, 0.0],
	"foliage": [2.60, 3, 0.66, 1.22, 1.40, 0.90, 0.35, 0.0],
	"water": [0.30, 2, 0.90, 1.06, 0.22, 0.10, 0.12, 0.30],
	"metal": [1.00, 2, 0.92, 1.06, 0.60, 0.42, 0.15, 0.65],
	"plain": [0.90, 2, 0.88, 1.10, 0.55, 0.80, 0.20, 0.0],
}


static func _material(kind: String, color: Color, emission := 0.0) -> StandardMaterial3D:
	var key := "%s:%s:%s" % [kind, color.to_html(true), emission]
	if _materials.has(key):
		return _materials[key]

	# Фотоскан вместо шума там, где он есть. Кэш общий, поэтому повторные
	# вызовы с тем же цветом ничего не стоят.
	if emission <= 0.0 and PHOTO_PACKS.has(kind):
		var photo := MatLib.get_material(String(PHOTO_PACKS[kind]), color)
		_materials[key] = photo
		return photo

	var spec: Array = SURFACES.get(kind, SURFACES["plain"])
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = float(spec[5])
	mat.metallic = float(spec[7])
	mat.metallic_specular = 0.5

	if emission > 0.0:
		# Lit glass gets no grain: a noisy lantern reads as a dirty lantern.
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
		_materials[key] = mat
		return mat

	mat.albedo_texture = _grain(kind)
	mat.uv1_triplanar = true
	var s := float(spec[4])
	mat.uv1_scale = Vector3(s, s, s)
	if not MatLib.apply_flat_style(mat):
		mat.normal_enabled = true
		mat.normal_texture = _bump(kind)
		mat.normal_scale = float(spec[6])
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_materials[key] = mat
	return mat


## Grey albedo grain. The ramp runs past 1.0 on purpose: multiplied into the
## albedo tint it lifts the highlights instead of only darkening, so a lawn
## gets sun-bleached patches rather than looking uniformly dirty.
static func _grain(kind: String) -> NoiseTexture2D:
	if _grain_cache.has(kind):
		return _grain_cache[kind]

	var spec: Array = SURFACES.get(kind, SURFACES["plain"])
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = float(spec[0])
	noise.fractal_octaves = int(spec[1])
	noise.fractal_lacunarity = 2.1
	noise.fractal_gain = 0.52
	noise.seed = abs(hash(kind)) % 100000

	var ramp := Gradient.new()
	ramp.set_color(0, Color(spec[2], spec[2], spec[2]))
	ramp.set_color(1, Color(spec[3], spec[3], spec[3]))

	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp
	_grain_cache[kind] = tex
	return tex


## The same field turned into a normal map, one octave finer so the bump does
## not simply repeat the albedo blotches.
static func _bump(kind: String) -> NoiseTexture2D:
	if _bump_cache.has(kind):
		return _bump_cache[kind]

	var spec: Array = SURFACES.get(kind, SURFACES["plain"])
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = float(spec[0]) * 1.7
	noise.fractal_octaves = int(spec[1]) + 1
	noise.seed = abs(hash(kind + "bump")) % 100000

	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.as_normal_map = true
	tex.bump_strength = 2.4
	_bump_cache[kind] = tex
	return tex


# ===========================================================================
#  Primitive layer
# ===========================================================================


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func _box(parent: Node3D, node_name: String, at: Vector3, size: Vector3,
		kind: String, color: Color, vis := 260.0, shadows := true,
		emission := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _primitive(parent, node_name, at, mesh, size, kind, color, vis,
		shadows, emission)


static func _cyl(parent: Node3D, node_name: String, at: Vector3, radius: float,
		height: float, kind: String, color: Color, vis := 260.0,
		segments := 12, shadows := true) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.radial_segments = segments
	mesh.rings = 1
	return _primitive(parent, node_name, at, mesh,
		Vector3(radius * 2.0, height, radius * 2.0), kind, color, vis, shadows,
		0.0)


static func _cone(parent: Node3D, node_name: String, at: Vector3,
		bottom_radius: float, top_radius: float, height: float, kind: String,
		color: Color, vis := 260.0, segments := 10,
		shadows := true) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.radial_segments = segments
	mesh.rings = 1
	var r: float = maxf(bottom_radius, top_radius)
	return _primitive(parent, node_name, at, mesh, Vector3(r * 2.0, height, r * 2.0),
		kind, color, vis, shadows, 0.0)


static func _sphere(parent: Node3D, node_name: String, at: Vector3,
		radius: float, kind: String, color: Color, vis := 260.0,
		shadows := true) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	return _primitive(parent, node_name, at, mesh,
		Vector3(radius * 2.0, radius * 2.0, radius * 2.0), kind, color, vis,
		shadows, 0.0)


static func _torus(parent: Node3D, node_name: String, at: Vector3,
		inner_radius: float, outer_radius: float, kind: String, color: Color,
		vis := 200.0) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 16
	mesh.ring_segments = 6
	return _primitive(parent, node_name, at, mesh,
		Vector3(outer_radius * 2.0, outer_radius - inner_radius,
			outer_radius * 2.0), kind, color, vis, true, 0.0)


static func _primitive(parent: Node3D, node_name: String, at: Vector3,
		mesh: PrimitiveMesh, size: Vector3, kind: String, color: Color,
		vis: float, shadows: bool, emission: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	# A repeated sibling name makes Godot fall back to @MeshInstance3D@NNN,
	# which no test can address. Tag the twin with its position instead.
	if parent.has_node(NodePath(node_name)):
		node_name = "%s %s" % [node_name, at]
	mi.name = node_name
	mi.position = at
	mi.mesh = mesh
	mi.material_override = _material(kind, color, emission)
	if vis > 0.0:
		mi.visibility_range_end = vis
		mi.visibility_range_fade_mode = \
			GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# Huge plates and pebbles are both pointless shadow casters -- the first
	# fills the shadow atlas with a flat slab, the second with nothing.
	if not shadows or size.length() < 0.65:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ===========================================================================
#  Terrain
# ===========================================================================


static func _terrain(root: Node3D) -> void:
	var ground := Node3D.new()
	ground.name = "Terrain"
	root.add_child(ground)

	# One plate under the whole world. 760 m square: the far mountain feet sit
	# at ~260 m and the drive set runs to x 300, so nothing overhangs its edge.
	_box(ground, "Ground Plate", Vector3(14, GROUND_TOP - 0.06, 5),
		Vector3(760, 0.12, 760), "meadow", COL_MEADOW, 0.0, false)

	# Low rolling swells so the horizon is not a drawing-board plane. Flattened
	# spheres sunk into the plate, well outside the estate wall.
	var rng := _rng(50731)
	for i in range(16):
		var angle: float = TAU * (float(i) + rng.randf_range(0.1, 0.9)) / 16.0
		var dist: float = rng.randf_range(150.0, 280.0)
		var cx: float = 14.0 + cos(angle) * dist
		var cz: float = 5.0 + sin(angle) * dist
		var rise: float = rng.randf_range(3.0, 9.0)
		var spread: float = rng.randf_range(35.0, 85.0)
		var mound := _sphere(ground, "Swell %d" % i, Vector3(cx, -rise * 0.35, cz),
			1.0, "meadow", COL_MEADOW.lerp(COL_FIELD_C, rng.randf()), 0.0, false)
		mound.scale = Vector3(spread, rise, spread * rng.randf_range(0.7, 1.3))


## Far pasture: flat tinted rectangles with hedgerow borders, in the three
## wedges the drive set and the building leave free. They give the distance a
## worked, farmed look instead of one flat green.
static func _fields(root: Node3D) -> void:
	var fields := Node3D.new()
	fields.name = "Far Fields"
	root.add_child(fields)

	var zones := [
		[-260.0, -75.0, -200.0, 120.0],   # west
		[-200.0, 115.0, -260.0, -95.0],   # south
		[95.0, 260.0, -240.0, -50.0],     # south-east
	]
	var tints := [COL_FIELD_A, COL_FIELD_B, COL_FIELD_C, COL_LAWN]
	var rng := _rng(90731)
	for i in range(21):
		var zone: Array = zones[i % zones.size()]
		var w: float = rng.randf_range(42.0, 92.0)
		var d: float = rng.randf_range(34.0, 72.0)
		var cx: float = rng.randf_range(float(zone[0]) + w * 0.5, float(zone[1]) - w * 0.5)
		var cz: float = rng.randf_range(float(zone[2]) + d * 0.5, float(zone[3]) - d * 0.5)
		var tint: Color = tints[rng.randi() % tints.size()]
		_box(fields, "Field %d" % i, Vector3(cx, GROUND_TOP - 0.02, cz),
			Vector3(w, 0.10, d), "grass", tint, 0.0, false)
		# Hedgerow border, broken at one corner so it does not read as a box.
		var h: float = rng.randf_range(0.9, 1.5)
		for side in range(4):
			if side == rng.randi() % 4:
				continue
			var along_x: bool = side < 2
			var sgn: float = -1.0 if side % 2 == 0 else 1.0
			var at := Vector3(cx, h * 0.5 + GROUND_TOP, cz)
			var size := Vector3(w, h, 0.9)
			if along_x:
				at.z += sgn * d * 0.5
			else:
				at.x += sgn * w * 0.5
				size = Vector3(0.9, h, d)
			_box(fields, "Field %d Hedgerow %d" % [i, side], at, size, "foliage",
				COL_HEDGE, 0.0, false)


## Mountain planes on the three sides the drive set does not cover. Tone 0 is
## the dark near ridge, 2 the hazy snow-capped far one; the builder seeds its
## own peaks so no two ranges share a skyline.
static func _horizon(root: Node3D) -> void:
	var horizon := Node3D.new()
	horizon.name = "Horizon"
	root.add_child(horizon)

	# [x, z, length, tone, seed, yaw]
	var ranges := [
		[-150.0, -150.0, 220.0, 0, 61, 35.0],
		[-215.0, -20.0, 260.0, 1, 62, 90.0],
		[-268.0, 15.0, 320.0, 2, 63, 90.0],
		[5.0, -195.0, 300.0, 1, 64, 0.0],
		[35.0, -248.0, 340.0, 2, 65, 0.0],
		[195.0, -125.0, 230.0, 1, 66, 118.0],
	]
	for r in ranges:
		ExteriorProps.build_mountain_range(horizon,
			Vector3(float(r[0]), -0.05, float(r[1])), float(r[2]), int(r[3]),
			int(r[4]), float(r[5]))


# ===========================================================================
#  Water
# ===========================================================================


static func _water(root: Node3D) -> void:
	var water := Node3D.new()
	water.name = "Water"
	root.add_child(water)

	# A lake in the south-west meadow, read from the west flank and overview
	# shots. Water sits 2 cm above the plate so it never fights it, and the
	# earth rim is another 4 cm up, which makes a basin out of two flat slabs.
	var cx := -118.0
	var cz := -92.0
	var w := 76.0
	var d := 52.0
	_box(water, "Lake", Vector3(cx, -0.12, cz), Vector3(w, 0.12, d), "water",
		COL_WATER, 0.0, false)
	for side in range(4):
		var along_x: bool = side < 2
		var sgn: float = -1.0 if side % 2 == 0 else 1.0
		var at := Vector3(cx, -0.06, cz)
		var size := Vector3(w + 6.0, 0.16, 3.4)
		if along_x:
			at.z += sgn * (d * 0.5 + 1.5)
		else:
			at.x += sgn * (w * 0.5 + 1.5)
			size = Vector3(3.4, 0.16, d + 6.0)
		_box(water, "Lake Bank %d" % side, at, size, "earth", COL_EARTH, 0.0,
			false)

	# Rocks and reed clumps break the rectangle of the shoreline.
	var rng := _rng(7715)
	for i in range(26):
		var angle: float = TAU * float(i) / 26.0
		var rx: float = cx + cos(angle) * (w * 0.5 + rng.randf_range(0.5, 3.2))
		var rz: float = cz + sin(angle) * (d * 0.5 + rng.randf_range(0.5, 3.2))
		if i % 3 == 0:
			var rock := _sphere(water, "Lake Rock %d" % i,
				Vector3(rx, rng.randf_range(-0.1, 0.25), rz),
				rng.randf_range(0.4, 1.3), "stone", COL_ROCK, 0.0)
			rock.scale = Vector3(1.0, rng.randf_range(0.5, 0.8), rng.randf_range(0.8, 1.4))
		else:
			for blade in range(5):
				_cone(water, "Reed %d %d" % [i, blade],
					Vector3(rx + rng.randf_range(-0.7, 0.7), 0.55,
						rz + rng.randf_range(-0.7, 0.7)),
					0.09, 0.01, rng.randf_range(0.9, 1.5), "foliage", COL_REED,
					180.0, 5, false)

	# A river down the far west, running north-south past the lake.
	ExteriorProps.build_river(water, Vector3(-168, -0.02, -40), 230.0, 8.0, 91)


# ===========================================================================
#  Trees
# ===========================================================================


## Species cycle. Every copy is seeded, so the same three builders give oaks
## that lean differently, pines with different tier counts and birches with
## different bark marks -- the reuse the brief asks for, without a clone row.
static func _tree(parent: Node3D, index: int, at: Vector3, vis: float) -> void:
	match index % 3:
		0:
			ExteriorProps.build_oak(parent, at, 4100 + index, vis)
		1:
			ExteriorProps.build_pine(parent, at, 4100 + index, vis)
		_:
			ExteriorProps.build_birch(parent, at, 4100 + index, vis)


static func _forest(root: Node3D) -> void:
	var forest := Node3D.new()
	forest.name = "Forest"
	root.add_child(forest)

	var rng := _rng(31071)
	var index := 0

	# Belts, given as [x0, x1, z0, z1, count]. All three sit outside the
	# boundary wall and clear of the drive set (x >= 32, z >= 24).
	var belts := [
		[-132.0, -64.0, -150.0, 110.0, 54],
		[-140.0, 88.0, -142.0, -78.0, 48],
		[96.0, 156.0, -150.0, -46.0, 26],
	]
	for belt in belts:
		for i in range(int(belt[4])):
			var tx: float = rng.randf_range(float(belt[0]), float(belt[1]))
			var tz: float = rng.randf_range(float(belt[2]), float(belt[3]))
			_tree(forest, index, Vector3(tx, -0.05, tz), 300.0)
			index += 1

	# Avenues inside the wall, lining the ring road. These are close to the
	# building and appear in every flank shot, so they never cull.
	var avenue := Node3D.new()
	avenue.name = "Avenues"
	root.add_child(avenue)
	var z := -50.0
	while z <= 26.0:
		_tree(avenue, index, Vector3(WEST_AVENUE_X, -0.05, z), 0.0)
		index += 1
		z += 12.0
	var x := -40.0
	while x <= 68.0:
		_tree(avenue, index, Vector3(x, -0.05, SOUTH_AVENUE_Z), 0.0)
		index += 1
		x += 12.0
	var ez := -50.0
	while ez <= 16.0:
		_tree(avenue, index, Vector3(EAST_AVENUE_X, -0.05, ez), 0.0)
		index += 1
		ez += 12.0


# ===========================================================================
#  Boundary wall
# ===========================================================================


static func _boundary(root: Node3D) -> void:
	var wall := Node3D.new()
	wall.name = "Estate Wall"
	root.add_child(wall)

	_wall_run(wall, "West", WALL_SOUTH_Z, WALL_NORTH_Z, WALL_WEST_X, false)
	_wall_run(wall, "South", WALL_WEST_X, WALL_EAST_X, WALL_SOUTH_Z, true)
	_wall_run(wall, "East", WALL_SOUTH_Z, 24.0, WALL_EAST_X, false)

	# Two service gates, on the axes the ring road already runs to.
	_gate(wall, "West Gate", Vector3(WALL_WEST_X, 0.0, -10.0), 90.0)
	_gate(wall, "South Gate", Vector3(12.0, 0.0, WALL_SOUTH_Z), 0.0)


## One straight run of estate wall: plinth, panelled face, coping, and a
## pier every 24 m carrying a pyramid cap.
static func _wall_run(parent: Node3D, tag: String, a: float, b: float,
		fixed: float, along_x: bool) -> void:
	var length: float = b - a
	var centre: float = (a + b) * 0.5

	var def := func(u: float, y: float, run: float, thick: float,
			height: float) -> Array:
		if along_x:
			return [Vector3(u, y, fixed), Vector3(run, height, thick)]
		return [Vector3(fixed, y, u), Vector3(thick, height, run)]

	var plinth: Array = def.call(centre, 0.15, length, 1.10, 0.36)
	_box(parent, "%s Wall Plinth" % tag, plinth[0], plinth[1], "stone",
		COL_STONE_DARK, 0.0)
	var face: Array = def.call(centre, 0.95, length, 0.75, 1.24)
	_box(parent, "%s Wall Face" % tag, face[0], face[1], "stone", COL_STONE, 0.0)
	var coping: Array = def.call(centre, 1.65, length, 0.95, 0.16)
	_box(parent, "%s Wall Coping" % tag, coping[0], coping[1], "stone",
		COL_COPING, 0.0)

	var u := a
	var i := 0
	while u <= b + 0.1:
		var pier: Array = def.call(u, 1.00, 1.00, 1.00, 2.00)
		_box(parent, "%s Pier %d" % [tag, i], pier[0], pier[1], "stone",
			COL_STONE, 0.0)
		var cap_at: Vector3 = pier[0]
		cap_at.y = 2.16
		_cone(parent, "%s Pier Cap %d" % [tag, i], cap_at, 0.78, 0.06, 0.32,
			"stone", COL_COPING, 0.0, 4)
		u += 24.0
		i += 1


static func _gate(parent: Node3D, tag: String, at: Vector3, yaw_deg: float) -> void:
	var root := Node3D.new()
	root.name = tag
	root.position = at
	root.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(root)

	# Local +X runs along the wall, so the opening is a 7 m gap between piers.
	for side: float in [-1.0, 1.0]:
		var sx: float = side * 3.9
		var tag_side: String = "L" if side < 0.0 else "R"
		_box(root, "Gate Pier %s" % tag_side, Vector3(sx, 1.35, 0),
			Vector3(1.3, 2.70, 1.3), "stone", COL_STONE, 0.0)
		_cone(root, "Gate Pier Cap %s" % tag_side, Vector3(sx, 2.86, 0), 0.95,
			0.08, 0.36, "stone", COL_COPING, 0.0, 4)
		_box(root, "Gate Lantern %s" % tag_side, Vector3(sx, 3.24, 0),
			Vector3(0.34, 0.44, 0.34), "plain", COL_GLOW, 0.0, false, 0.9)
		_cone(root, "Gate Lantern Cap %s" % tag_side, Vector3(sx, 3.52, 0), 0.26,
			0.03, 0.16, "metal", COL_BRONZE, 0.0, 4)

		# An iron leaf, standing open against its pier.
		var leaf := Node3D.new()
		leaf.name = "Gate Leaf %s" % tag_side
		leaf.position = Vector3(sx - side * 0.65, 0.0, 0.0)
		leaf.rotation.y = deg_to_rad(-side * 72.0)
		root.add_child(leaf)
		_box(leaf, "Leaf Rail Top", Vector3(side * 1.5, 1.90, 0),
			Vector3(3.0, 0.12, 0.08), "metal", COL_IRON, 200.0)
		_box(leaf, "Leaf Rail Bottom", Vector3(side * 1.5, 0.30, 0),
			Vector3(3.0, 0.12, 0.08), "metal", COL_IRON, 200.0)
		for bar in range(7):
			_cyl(leaf, "Leaf Bar %d" % bar,
				Vector3(side * (0.25 + float(bar) * 0.42), 1.05, 0), 0.035, 1.72,
				"metal", COL_IRON, 200.0, 6, false)


# ===========================================================================
#  Service ring road, kerbs and lawn aprons
# ===========================================================================


static func _ring_road(root: Node3D) -> void:
	var ring := Node3D.new()
	ring.name = "Service Ring"
	root.add_child(ring)

	# Three legs meeting edge to edge. Asphalt with a gravel shoulder, because
	# this is the back-of-house route, not the visitor approach.
	_leg(ring, "West", RING_Z_MIN, RING_WEST_Z_MAX, WEST_ROAD_X, false)
	_leg(ring, "East", RING_Z_MIN, RING_EAST_Z_MAX, EAST_ROAD_X, false)
	_leg(ring, "South", RING_X_MIN, RING_X_MAX, SOUTH_ROAD_Z, true)

	# Lawn aprons between the road and the building's own faces.
	_apron(ring, "West", RING_Z_MIN, RING_WEST_Z_MAX, WEST_LAWN_X, false)
	_apron(ring, "East", RING_Z_MIN, RING_EAST_Z_MAX, EAST_LAWN_X, false)
	_apron(ring, "South", RING_X_MIN, 64.0, SOUTH_LAWN_Z, true)


static func _leg(parent: Node3D, tag: String, a: float, b: float, fixed: float,
		along_x: bool) -> void:
	var length: float = b - a
	var centre: float = (a + b) * 0.5
	var at := Vector3(centre, ROAD_TOP - 0.06, fixed) if along_x \
		else Vector3(fixed, ROAD_TOP - 0.06, centre)
	var size := Vector3(length, 0.12, ROAD_HALF * 2.0) if along_x \
		else Vector3(ROAD_HALF * 2.0, 0.12, length)
	_box(parent, "Ring Road %s" % tag, at, size, "asphalt", COL_ASPHALT, 0.0,
		false)

	for side: float in [-1.0, 1.0]:
		var side_tag: String = "A" if side < 0.0 else "B"
		var kerb_at := at
		kerb_at.y = -0.02
		var kerb_size := Vector3(length, 0.16, 0.4)
		var gravel_at := at
		gravel_at.y = ROAD_TOP - 0.05
		var gravel_size := Vector3(length, 0.10, 1.2)
		if along_x:
			kerb_at.z += side * (ROAD_HALF + 0.2)
			gravel_at.z += side * (ROAD_HALF + 1.0)
		else:
			kerb_at.x += side * (ROAD_HALF + 0.2)
			gravel_at.x += side * (ROAD_HALF + 1.0)
			kerb_size = Vector3(0.4, 0.16, length)
			gravel_size = Vector3(1.2, 0.10, length)
		_box(parent, "Ring Kerb %s %s" % [tag, side_tag], kerb_at, kerb_size,
			"stone", COL_KERB, 0.0, false)
		_box(parent, "Ring Shoulder %s %s" % [tag, side_tag], gravel_at,
			gravel_size, "gravel", COL_GRAVEL, 0.0, false)

	# Centre dashes, floating 8 mm over the asphalt.
	var u := a + 4.0
	var i := 0
	while u < b - 3.0:
		var dash_at := Vector3(u, ROAD_TOP + 0.008, fixed) if along_x \
			else Vector3(fixed, ROAD_TOP + 0.008, u)
		var dash_size := Vector3(2.2, 0.01, 0.16) if along_x \
			else Vector3(0.16, 0.01, 2.2)
		_box(parent, "Ring Dash %s %d" % [tag, i], dash_at, dash_size, "plain",
			Color(0.86, 0.83, 0.66), 0.0, false)
		u += 9.0
		i += 1


static func _apron(parent: Node3D, tag: String, a: float, b: float,
		fixed: float, along_x: bool) -> void:
	var length: float = b - a
	var centre: float = (a + b) * 0.5
	var at := Vector3(centre, LAWN_TOP - 0.05, fixed) if along_x \
		else Vector3(fixed, LAWN_TOP - 0.05, centre)
	var size := Vector3(length, 0.10, LAWN_W) if along_x \
		else Vector3(LAWN_W, 0.10, length)
	_box(parent, "Lawn Apron %s" % tag, at, size, "grass", COL_LAWN, 0.0, false)


# ===========================================================================
#  Hedges, beds and borders
# ===========================================================================


static func _planting(root: Node3D) -> void:
	var planting := Node3D.new()
	planting.name = "Planting"
	root.add_child(planting)

	_hedge_row(planting, "West", RING_Z_MIN, RING_WEST_Z_MAX, WEST_HEDGE_X, false, 6100)
	_hedge_row(planting, "East", RING_Z_MIN, RING_EAST_Z_MAX, EAST_HEDGE_X, false, 6200)
	_hedge_row(planting, "South", RING_X_MIN, RING_X_MAX, SOUTH_HEDGE_Z, true, 6300)

	# Beds on the aprons, on the axes of the building's own masses.
	var beds := [
		[WEST_LAWN_X, -12.0, 6401],
		[WEST_LAWN_X, 14.0, 6402],
		[-6.0, SOUTH_LAWN_Z, 6403],
		[30.0, SOUTH_LAWN_Z, 6404],
		[EAST_LAWN_X, -18.0, 6405],
		[EAST_LAWN_X, 6.0, 6406],
	]
	for bed in beds:
		_flower_bed(planting, Vector3(float(bed[0]), 0.0, float(bed[1])), 1.35,
			int(bed[2]))


## A clipped hedge, built as separate modules with seeded height and a 6 cm
## joint between them: one 80 m box would read as a painted wall.
static func _hedge_row(parent: Node3D, tag: String, a: float, b: float,
		fixed: float, along_x: bool, seed_value: int) -> void:
	var rng := _rng(seed_value)
	var u := a
	var i := 0
	while u < b - 1.0:
		var run: float = minf(3.8, b - u)
		var h: float = rng.randf_range(1.02, 1.24)
		var centre: float = u + run * 0.5
		var at := Vector3(centre, h * 0.5 - 0.04, fixed) if along_x \
			else Vector3(fixed, h * 0.5 - 0.04, centre)
		var size := Vector3(run - 0.06, h, 1.05) if along_x \
			else Vector3(1.05, h, run - 0.06)
		_box(parent, "Hedge %s %d" % [tag, i], at, size, "foliage", COL_HEDGE,
			0.0)
		u += run
		i += 1


static func _flower_bed(parent: Node3D, centre: Vector3, radius: float,
		seed_value: int, flip_x := false) -> void:
	var rng := _rng(seed_value)
	var tag := "Bed %d" % seed_value
	if flip_x:
		tag = "Bed %d Mirror" % seed_value
	_cyl(parent, "%s Soil" % tag, centre + Vector3(0, 0.08, 0), radius, 0.20,
		"earth", COL_EARTH, 220.0, 14)
	_torus(parent, "%s Rim" % tag, centre + Vector3(0, 0.16, 0), radius,
		radius + 0.22, "stone", COL_STONE_DARK, 220.0)

	var tints := [COL_FLOWER_A, COL_FLOWER_B, COL_FLOWER_C]
	for i in range(18):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = sqrt(rng.randf()) * (radius - 0.22)
		# flip_x mirrors the scatter for beds west of the museum axis: given the
		# same seed, such a bed reads as the reflection of its twin instead of an
		# unrelated spray of flowers.
		var offset_x: float = cos(angle) * dist
		if flip_x:
			offset_x = -offset_x
		var at := centre + Vector3(offset_x, 0.26, sin(angle) * dist)
		_sphere(parent, "%s Bloom %d" % [tag, i], at, rng.randf_range(0.11, 0.19),
			"foliage", tints[rng.randi() % tints.size()], 90.0, false)


# ===========================================================================
#  Fixtures
# ===========================================================================


static func _fixtures(root: Node3D) -> void:
	var fixtures := Node3D.new()
	fixtures.name = "Grounds Fixtures"
	root.add_child(fixtures)

	# Lamp posts down the ring, lanterns turned to the carriageway. Emissive
	# only -- the map's light count is verified by test_map_verification.
	var z := -48.0
	while z <= 26.0:
		ExteriorProps.build_lamp_post(fixtures,
			Vector3(WEST_ROAD_X - ROAD_HALF - 1.9, -0.02, z), 90.0, 0.0)
		z += 22.0
	var x := -36.0
	while x <= 68.0:
		ExteriorProps.build_lamp_post(fixtures,
			Vector3(x, -0.02, SOUTH_ROAD_Z - ROAD_HALF - 1.9), 0.0, 0.0)
		x += 22.0
	var ez := -48.0
	while ez <= 14.0:
		ExteriorProps.build_lamp_post(fixtures,
			Vector3(EAST_ROAD_X + ROAD_HALF + 1.9, -0.02, ez), -90.0, 0.0)
		ez += 22.0

	# Staff benches on the aprons, backs to the hedge, facing the building.
	var benches := [
		[WEST_LAWN_X - 0.4, 2.0, 90.0],
		[WEST_LAWN_X - 0.4, -26.0, 90.0],
		[12.0, SOUTH_LAWN_Z - 0.4, 0.0],
		[46.0, SOUTH_LAWN_Z - 0.4, 0.0],
	]
	for b in benches:
		_bench(fixtures, Vector3(float(b[0]), 0.0, float(b[1])), float(b[2]))

	# Bollards guarding the building's corners from the service traffic.
	var corners := [
		[-36.6, -50.6], [-36.6, 30.0], [64.6, -50.6], [64.6, 18.0],
	]
	for c in corners:
		for step in range(4):
			_cyl(fixtures, "Bollard",
				Vector3(float(c[0]), 0.42, float(c[1]) + float(step) * 1.6), 0.11,
				0.88, "metal", COL_IRON, 140.0, 8)


static func _bench(parent: Node3D, at: Vector3, yaw_deg: float) -> void:
	var root := Node3D.new()
	root.name = "Grounds Bench"
	if parent.has_node(NodePath(root.name)):
		root.name = "Grounds Bench %s" % at
	root.position = at
	root.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(root)

	_box(root, "Seat", Vector3(0, 0.45, 0), Vector3(2.2, 0.10, 0.62), "plain",
		COL_WOOD, 160.0)
	_box(root, "Back", Vector3(0, 0.80, -0.27), Vector3(2.2, 0.48, 0.08),
		"plain", COL_WOOD, 160.0)
	for side: float in [-1.0, 1.0]:
		var tag: String = "L" if side < 0.0 else "R"
		_box(root, "Leg %s" % tag, Vector3(side * 0.95, 0.20, 0),
			Vector3(0.10, 0.40, 0.56), "metal", COL_IRON, 160.0)
		_box(root, "Back Post %s" % tag, Vector3(side * 0.95, 0.78, -0.27),
			Vector3(0.08, 0.52, 0.08), "metal", COL_IRON, 160.0)


# ===========================================================================
#  THE FORECOURT -- the one piece of ground the player actually walks on
# ===========================================================================
#
#  Everything above is scenery behind unclimbable walls. This section is not:
#  the player spawns at (0, 0.05, 46) facing the museum, so every object here
#  is either walked past at eye level or walked into.
#
#  TWO RULES FOLLOW FROM THAT.
#
#  1. Paving never gets a collider. The court's floor slabs already carry
#     collision ("Forecourt Ground" top 0.00, "Museum Walkway" 0.035,
#     "Entrance Plaza" 0.045). The stonework below is a decorative overlay
#     1-2 cm proud of them, so the surface the player stands on is exactly
#     the surface the walk tests already approved.
#  2. Anything tall DOES get one, or the player strolls through a fountain.
#     Colliders are cylinders for round things: a BoxShape3D on a drum puts
#     invisible walls out at radius * sqrt(2).
#
#  The fountain sits at z 49.5, not on the spawn point at z 46: its 2.95 m
#  basin plus the player capsule would have hatched the player inside the
#  bowl. At 3.5 m from spawn it stands just off the shoulder instead, framed
#  by the gate behind it and the portico ahead.

static var COL_PAVING_A := Pal.tone(Pal.STONE, 0.33)
static var COL_PAVING_B := Pal.tone(Pal.STONE, 0.12)
static var COL_JOINT := Pal.tone(Pal.STONE, -0.50)
static var COL_BASIN := Pal.tone(Pal.STONE, 0.19)

const COURT_SLAB_TOP := 0.055
const FOUNTAIN_Z := 49.5
const FOUNTAIN_BASIN_R := 2.95
const FOUNTAIN_APRON_R := 4.25
# Half width of the Museum Walkway the map paves down the axis (6.4 m wide).
# Court dressing has to stay off it: the walk from the gate to the perron is the
# one route every guest takes, and test_map_verification measures how wide it is
# left in _verify_entrance_approach.
const COURT_WALK_HALF := 3.2


static func build_forecourt(parent: Node3D) -> void:
	var court := Node3D.new()
	court.name = "Forecourt Dressing"
	parent.add_child(court)

	_court_paving(court)
	_fountain(court)
	_parterres(court)
	_street_gate(court)
	_court_fixtures(court)


# --- collision helpers --------------------------------------------------------


static func _solid_box(parent: Node3D, node_name: String, at: Vector3,
		size: Vector3) -> void:
	var body := StaticBody3D.new()
	if parent.has_node(NodePath(node_name)):
		node_name = "%s %s" % [node_name, at]
	body.name = node_name
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)


static func _solid_cyl(parent: Node3D, node_name: String, at: Vector3,
		radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	if parent.has_node(NodePath(node_name)):
		node_name = "%s %s" % [node_name, at]
	body.name = node_name
	body.position = at
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)


# --- paving -------------------------------------------------------------------


static func _slab(parent: Node3D, tag: String, at: Vector3, size: Vector3,
		rng: RandomNumberGenerator) -> void:
	# Every slab is tinted individually. A flagged court whose stones all match
	# is the single clearest tell of a game floor.
	_box(parent, tag, at, size, "stone",
		COL_PAVING_A.lerp(COL_PAVING_B, rng.randf()), 0.0, false)


static func _court_paving(root: Node3D) -> void:
	var paving := Node3D.new()
	paving.name = "Court Paving"
	root.add_child(paving)

	var rng := _rng(8801)

	# Dark bedding under every flagged area: the 8 cm joints between slabs read
	# as mortar because this is what shows through them.
	_box(paving, "Bedding Walk", Vector3(0, 0.018, 48.3),
		Vector3(6.9, 0.06, 13.6), "stone", COL_JOINT, 0.0, false)
	_box(paving, "Bedding Plaza", Vector3(0, 0.028, 39.8),
		Vector3(17.2, 0.06, 4.8), "stone", COL_JOINT, 0.0, false)
	_cyl(paving, "Bedding Apron", Vector3(0, 0.018, FOUNTAIN_Z),
		FOUNTAIN_APRON_R + 0.22, 0.06, "stone", COL_JOINT, 0.0, 32, false)

	# Approach walk: four courses of flags, opened out around the fountain.
	var centre := Vector2(0.0, FOUNTAIN_Z)
	var z := 41.6
	var row := 0
	while z < 54.6:
		for col in range(4):
			var x: float = -2.4 + float(col) * 1.6
			if Vector2(x, z).distance_to(centre) < FOUNTAIN_APRON_R + 1.0:
				continue
			_slab(paving, "Walk Flag %d %d" % [row, col],
				Vector3(x, COURT_SLAB_TOP - 0.03, z), Vector3(1.52, 0.06, 1.42),
				rng)
		z += 1.5
		row += 1

	# Entrance plaza in front of the perron, laid in a wider stone.
	for r in range(3):
		for col in range(11):
			_slab(paving, "Plaza Flag %d %d" % [r, col],
				Vector3(-8.0 + float(col) * 1.6, COURT_SLAB_TOP - 0.02,
					38.4 + float(r) * 1.5), Vector3(1.52, 0.06, 1.42), rng)

	# Fountain apron, laid in radiating courses like real basin surrounds.
	var rings := [[3.10, 3.48, 20], [3.48, 3.86, 22], [3.86, 4.25, 24]]
	for ring_index in range(rings.size()):
		var ring: Array = rings[ring_index]
		var r_in := float(ring[0])
		var r_out := float(ring[1])
		var count := int(ring[2])
		var r_mid := (r_in + r_out) * 0.5
		var arc := TAU * r_mid / float(count)
		for i in range(count):
			var angle: float = TAU * float(i) / float(count)
			var slab := _box(paving, "Apron Flag %d %d" % [ring_index, i],
				Vector3(cos(angle) * r_mid, COURT_SLAB_TOP - 0.03,
					FOUNTAIN_Z + sin(angle) * r_mid),
				Vector3(arc - 0.08, 0.06, r_out - r_in - 0.08), "stone",
				COL_PAVING_A.lerp(COL_PAVING_B, rng.randf()), 0.0, false)
			slab.rotation.y = -angle

	# Kerb courses framing the walk and the apron.
	for side: float in [-1.0, 1.0]:
		_box(paving, "Walk Kerb %s" % ("West" if side < 0.0 else "East"),
			Vector3(side * 3.34, 0.03, 48.3), Vector3(0.28, 0.09, 13.6), "stone",
			COL_KERB, 0.0, false)
	_torus(paving, "Apron Kerb", Vector3(0, 0.05, FOUNTAIN_Z),
		FOUNTAIN_APRON_R + 0.10, FOUNTAIN_APRON_R + 0.34, "stone", COL_KERB, 0.0)


# --- fountain -----------------------------------------------------------------


static func _fountain(root: Node3D) -> void:
	var authored := MuseumModels.place(root, "lp_court_fountain",
		Vector3(0, 0, FOUNTAIN_Z))
	if authored != null:
		authored.name = "Court Fountain"
		# Same honest round blocker as the old basin; the imported hollow ring
		# stays visual-only so a convex hull cannot fill the water and apron.
		_solid_cyl(root, "Fountain Collision", Vector3(0, 0.40, FOUNTAIN_Z),
			3.06, 0.80)
		return
	push_warning("lp_court_fountain did not resolve; using procedural fallback")
	var f := Node3D.new()
	f.name = "Court Fountain"
	f.position = Vector3(0, 0, FOUNTAIN_Z)
	root.add_child(f)

	# Basin floor, then a ring of 24 wall segments. A solid drum would hide its
	# own water: the water disc sits below the rim, so the wall has to be a
	# ring, not a cylinder.
	_cyl(f, "Basin Floor", Vector3(0, 0.10, 0), 2.90, 0.20, "stone",
		COL_STONE_DARK, 0.0, 32)
	var seg_count := 24
	var arc := TAU * 2.80 / float(seg_count)
	for i in range(seg_count):
		var angle: float = TAU * float(i) / float(seg_count)
		var seg := _box(f, "Basin Wall %d" % i,
			Vector3(cos(angle) * 2.80, 0.42, sin(angle) * 2.80),
			Vector3(arc + 0.02, 0.52, 0.34), "stone", COL_BASIN, 0.0)
		seg.rotation.y = -angle
	_torus(f, "Basin Coping", Vector3(0, 0.70, 0), 2.62, 3.04, "stone",
		COL_COPING, 0.0)

	# Still water, 2 cm under the coping, with a darker pool shadow beneath.
	_cyl(f, "Basin Water", Vector3(0, 0.47, 0), 2.74, 0.06, "water", COL_WATER,
		0.0, 32, false)

	# Two-tier centrepiece.
	_cyl(f, "Fountain Pedestal", Vector3(0, 0.45, 0), 0.92, 0.70, "stone",
		COL_BASIN, 0.0, 16)
	_torus(f, "Pedestal Torus", Vector3(0, 0.82, 0), 0.86, 1.06, "stone",
		COL_COPING, 0.0)
	_cone(f, "Lower Bowl", Vector3(0, 1.06, 0), 0.52, 1.62, 0.34, "stone",
		COL_BASIN, 0.0, 20)
	_torus(f, "Lower Bowl Rim", Vector3(0, 1.24, 0), 1.52, 1.70, "stone",
		COL_COPING, 0.0)
	_cyl(f, "Lower Bowl Water", Vector3(0, 1.22, 0), 1.48, 0.05, "water",
		COL_WATER, 0.0, 24, false)
	_cyl(f, "Fountain Stem", Vector3(0, 1.72, 0), 0.26, 1.00, "stone",
		COL_BASIN, 0.0, 12)
	_cone(f, "Upper Bowl", Vector3(0, 2.30, 0), 0.30, 0.92, 0.26, "stone",
		COL_BASIN, 0.0, 16)
	_torus(f, "Upper Bowl Rim", Vector3(0, 2.42, 0), 0.84, 0.98, "stone",
		COL_COPING, 0.0)
	_cyl(f, "Upper Bowl Water", Vector3(0, 2.40, 0), 0.80, 0.05, "water",
		COL_WATER, 0.0, 20, false)
	_sphere(f, "Fountain Finial", Vector3(0, 2.62, 0), 0.20, "stone",
		COL_COPING, 0.0)

	# Jet and falling sheets. Water is a material, not a simulation: a thin
	# bright column plus rim curtains is what sells it at walking speed.
	_cyl(f, "Fountain Jet", Vector3(0, 3.24, 0), 0.055, 1.05, "water",
		Color(0.72, 0.82, 0.86), 0.0, 8, false)
	_sphere(f, "Jet Crown", Vector3(0, 3.80, 0), 0.16, "water",
		Color(0.78, 0.86, 0.90), 0.0, false)
	for i in range(12):
		var angle: float = TAU * float(i) / 12.0
		_cyl(f, "Upper Fall %d" % i,
			Vector3(cos(angle) * 0.90, 1.86, sin(angle) * 0.90), 0.035, 1.02,
			"water", Color(0.66, 0.78, 0.82), 0.0, 6, false)
	for i in range(16):
		var angle: float = TAU * float(i) / 16.0
		_cyl(f, "Lower Fall %d" % i,
			Vector3(cos(angle) * 1.60, 0.86, sin(angle) * 1.60), 0.04, 0.70,
			"water", Color(0.66, 0.78, 0.82), 0.0, 6, false)

	# One cylinder keeps the player out of the bowl.
	_solid_cyl(root, "Fountain Collision", Vector3(0, 0.40, FOUNTAIN_Z), 3.06,
		0.80)


# --- parterres ----------------------------------------------------------------


## The two lawns were flat green rectangles with a stone border. They become
## box parterres: clipped hedge on the three outer sides, a gravel cross walk,
## four beds and four topiary cones. The side facing the axis stays open so
## the benches at (+-8, 43.5) are still reachable.
static func _parterres(root: Node3D) -> void:
	var east := MuseumModels.place(root, "lp_forecourt_garden",
		Vector3(12.0, 0.0, 45.0))
	if east != null:
		east.name = "Parterre East"
		var west := MuseumModels.place(root, "lp_forecourt_garden",
			Vector3(-12.0, 0.0, 45.0), 1.0, 180.0)
		if west != null:
			west.name = "Parterre West"
		_garden_colliders(root, 12.0)
		_garden_colliders(root, -12.0)
		return
	push_warning("lp_forecourt_garden did not resolve; using procedural fallback")
	var parterre := Node3D.new()
	parterre.name = "Parterres"
	root.add_child(parterre)

	for side: float in [-1.0, 1.0]:
		# 12.0 and not 10.5: at 10.5 the inner hedge face stood 4.15 from the axis
		# and closed on the fountain basin to 1.09 m, so the way round the fountain
		# was a slot between clipped yew and stone. Moved out, the hedge clears the
		# walkway paving and the bollard ring, and the parterres still read as the
		# pair of squares that flank the court.
		var cx: float = side * 12.0
		var tag: String = "West" if side < 0.0 else "East"
		# One seed for both halves. The west parterre has to be the east one
		# reflected, so its random hedge module heights must match its twin
		# across the axis rather than merely resemble it.
		var rng := _rng(9100)

		# Gravel cross walk over the lawn inset (top 0.105).
		_box(parterre, "Parterre %s Walk X" % tag, Vector3(cx, 0.135, 45.0),
			Vector3(12.4, 0.06, 1.5), "gravel", COL_GRAVEL, 0.0, false)
		_box(parterre, "Parterre %s Walk Z" % tag, Vector3(cx, 0.135, 45.0),
			Vector3(1.5, 0.06, 13.4), "gravel", COL_GRAVEL, 0.0, false)

		# Clipped hedge, in modules, on the outer face and both ends.
		var outer_x: float = cx + side * 6.1
		_parterre_hedge(parterre, "%s Outer" % tag, 38.4, 51.6, outer_x, false, rng)
		_parterre_hedge(parterre, "%s South" % tag, cx - 6.1, cx + 6.1, 38.4, true, rng)
		_parterre_hedge(parterre, "%s North" % tag, cx - 6.1, cx + 6.1, 51.6, true, rng)

		# Four beds and four topiary cones, one per quarter.
		for qx: float in [-3.0, 3.0]:
			for qz: float in [-3.2, 3.2]:
				# Seeded by distance from the axis instead of signed x, so the bed
				# at -13.5 and the bed at +13.5 draw the same scatter, and the west
				# halves are flipped so that scatter is its reflection.
				var bed_at := Vector3(cx + qx, 0.10, 45.0 + qz)
				_flower_bed(parterre, bed_at, 1.05,
					9200 + int(absf(bed_at.x) * 10.0) + int(qz),
					bed_at.x < 0.0)
		for tx: float in [-4.8, 4.8]:
			for tz: float in [-4.9, 4.9]:
				var at := Vector3(cx + tx, 0.0, 45.0 + tz)
				_cyl(parterre, "Topiary Tub", at + Vector3(0, 0.20, 0), 0.44,
					0.40, "stone", COL_STONE_DARK, 120.0, 12)
				_cone(parterre, "Topiary", at + Vector3(0, 1.22, 0), 0.62, 0.06,
					1.64, "foliage", COL_HEDGE, 120.0, 12)
				_solid_cyl(parterre, "Topiary Collision",
					at + Vector3(0, 1.00, 0), 0.56, 2.00)


static func _garden_colliders(parent: Node3D, cx: float) -> void:
	var side := signf(cx)
	# Three hedge runs keep the same open side toward the arrival axis.
	_solid_box(parent, "Garden Outer Hedge Collision %s" % cx,
		Vector3(cx + side * 6.03, 0.50, 45.0), Vector3(0.62, 0.64, 13.18))
	for z in [38.42, 51.58]:
		_solid_box(parent, "Garden End Hedge Collision %s %s" % [cx, z],
			Vector3(cx, 0.49, z), Vector3(12.36, 0.62, 0.62))
	for xoff in [-4.75, 4.75]:
		for zoff in [-4.88, 4.88]:
			_solid_cyl(parent, "Garden Topiary Collision %s %s" % [cx, Vector2(xoff, zoff)],
				Vector3(cx + xoff, 1.00, 45.0 + zoff), 0.55, 2.00)


static func _parterre_hedge(parent: Node3D, tag: String, a: float, b: float,
		fixed: float, along_x: bool, rng: RandomNumberGenerator) -> void:
	var u := a
	var i := 0
	while u < b - 0.4:
		var run: float = minf(3.3, b - u)
		var h: float = rng.randf_range(0.52, 0.64)
		var centre: float = u + run * 0.5
		# The sweep always starts at the low end, so the short closing module
		# lands on the high-x side of whichever bed is being built. Reflecting the
		# centre about the run's own midpoint on the west side makes the two runs
		# mirror images instead of copies shifted by 1.1 m.
		if along_x and a + b < 0.0:
			centre = a + b - centre
		var at := Vector3(centre, 0.11 + h * 0.5, fixed) if along_x \
			else Vector3(fixed, 0.11 + h * 0.5, centre)
		var size := Vector3(run - 0.06, h, 0.62) if along_x \
			else Vector3(0.62, h, run - 0.06)
		_box(parent, "Parterre Hedge %s %d" % [tag, i], at, size, "foliage",
			COL_HEDGE, 0.0)
		_solid_box(parent, "Parterre Hedge %s %d Collision" % [tag, i], at, size)
		u += run
		i += 1


# --- street gate --------------------------------------------------------------


## Two piers on the axis where the court meets the pavement ramp, with their
## leaves standing open.
##
## They stood at z 54.2 until the V2 street was built. That put the 1.46 m
## plinths across 53.47..54.93 -- squarely in the middle of the 3.10 m pavement
## (52.40..55.50), so anyone walking the street had to detour around a gate that
## belongs to the museum rather than to the road. At z 51.50 the plinths span
## 50.77..52.23: clear of the ramp at 52.40, inside the court core (38.4..53.0),
## and reading as the court's mouth instead of an obstacle on the footway.
##
## Moving them off the footway forced them wider apart as well. At the old
## +/-4.7 the piers' inner faces stand at x 3.97, and 1.27 m short of the
## fountain's z the walk from the car to the perron pinched to 0.90 m -- under
## APPROACH_MIN_WIDTH. Sliding them along z cannot fix that: even at the last z
## that stays off the pavement (51.67) the gap is only 1.16 m. The fountain's
## collider is a 3.06 m cylinder on the axis at z 49.5, so the piers have to
## move outward, not backward. At +/-5.9 the corner-to-cylinder gap is 2.26 m.
##
## No railing runs off them on purpose: a solid fence across the court mouth
## would cut the player off from the street, and a fence without a collider is
## a fence you walk through. The leaves are deliberately collider-free, so they
## never enter the approach measurement -- only "Court Gate Collision *" does.
static func _street_gate(root: Node3D) -> void:
	var gate := Node3D.new()
	gate.name = "Court Gate"
	root.add_child(gate)

	var first_pier := MuseumModels.place(gate, "lp_court_gate_pier",
		Vector3(-5.9, 0.0, 51.50))
	if first_pier != null:
		first_pier.name = "Court Gate Pier West"
		var second_pier := MuseumModels.place(gate, "lp_court_gate_pier",
			Vector3(5.9, 0.0, 51.50))
		if second_pier != null:
			second_pier.name = "Court Gate Pier East"
		for side: float in [-1.0, 1.0]:
			var sx := side * 5.9
			var tag := "West" if side < 0.0 else "East"
			# The GLB carries the iron-and-glass housing; this small source and
			# real light sit inside it. Both sides use the same helper, so the
			# east lantern can no longer silently diverge from the west one.
			_gate_lantern(gate, tag, Vector3(sx, 3.64, 51.50))
			_solid_box(gate, "Court Gate Collision %s" % tag,
				Vector3(sx, 1.60, 51.50), Vector3(1.46, 3.20, 1.46))
			var leaf := MuseumModels.place(gate, "lp_court_gate_leaf",
				Vector3(sx + side * 0.62, 0.0, 51.50), 1.0, -side * 102.0)
			if leaf != null:
				leaf.name = "Court Gate Leaf %s" % tag
			# Seven linked sections run from each pier to the side wall. This is
			# the missing fence the old gate commentary explicitly omitted.
			for i in range(7):
				var fx := side * (8.40 + float(i) * 3.50)
				var section := MuseumModels.place(gate, "lp_court_fence_section",
					Vector3(fx, 0.0, 51.50))
				if section != null:
					section.name = "Court Fence %s %d" % [tag, i]
				_solid_box(gate, "Court Fence Collision %s %d" % [tag, i],
					Vector3(fx, 0.91, 51.50), Vector3(3.50, 1.82, 0.16))
		return
	push_warning("lp_court_gate_pier did not resolve; using procedural gate fallback")

	for side: float in [-1.0, 1.0]:
		var sx: float = side * 5.9
		var tag: String = "West" if side < 0.0 else "East"
		_box(gate, "Court Gate Plinth %s" % tag, Vector3(sx, 0.16, 51.50),
			Vector3(1.46, 0.32, 1.46), "stone", COL_STONE_DARK, 0.0)
		_box(gate, "Court Gate Pier %s" % tag, Vector3(sx, 1.62, 51.50),
			Vector3(1.16, 2.60, 1.16), "stone", COL_STONE, 0.0)
		_box(gate, "Court Gate Cornice %s" % tag, Vector3(sx, 3.02, 51.50),
			Vector3(1.40, 0.20, 1.40), "stone", COL_COPING, 0.0)
		_cone(gate, "Court Gate Cap %s" % tag, Vector3(sx, 3.28, 51.50), 0.66,
			0.06, 0.32, "stone", COL_COPING, 0.0, 4)
		_box(gate, "Court Gate Lantern Housing %s" % tag,
			Vector3(sx, 3.66, 51.50), Vector3(0.34, 0.46, 0.34),
			"metal", COL_IRON, 0.0, false)
		_cone(gate, "Court Gate Lantern Cap %s" % tag, Vector3(sx, 3.96, 51.50),
			0.26, 0.03, 0.18, "metal", COL_BRONZE, 0.0, 4)
		_gate_lantern(gate, tag, Vector3(sx, 3.64, 51.50))
		_solid_box(gate, "Court Gate Collision %s" % tag,
			Vector3(sx, 1.60, 51.50), Vector3(1.46, 3.20, 1.46))

		# Leaf folded back against its pier, clear of the opening.
		#
		# The angle is mirrored, not offset. It used to read `90.0 - side * 12.0`,
		# giving 102 deg west and 78 deg east -- which is not a mirror pair. The
		# west leaf folded outward against its pier as intended, but the east one
		# swung the other way and lay across the opening: its last bar landed at
		# x 3.99 against a 5.32 m half-opening. Nothing caught it because the gate
		# stood at z 54.2, outside the court core the mirror check looks at, and
		# the leaves carry no colliders, so the approach walk passed straight
		# through. Rotating by -side * 102 sends both leaves outward.
		var leaf := Node3D.new()
		leaf.name = "Court Gate Leaf %s" % tag
		leaf.position = Vector3(sx + side * 0.62, 0.0, 51.50)
		leaf.rotation.y = deg_to_rad(-side * 102.0)
		gate.add_child(leaf)
		_box(leaf, "Rail Top", Vector3(0, 2.10, -1.35), Vector3(0.09, 0.13, 2.7),
			"metal", COL_IRON, 0.0)
		_box(leaf, "Rail Bottom", Vector3(0, 0.34, -1.35),
			Vector3(0.09, 0.13, 2.7), "metal", COL_IRON, 0.0)
		for bar in range(8):
			_cyl(leaf, "Bar %d" % bar, Vector3(0, 1.22, -0.28 - float(bar) * 0.33),
				0.035, 1.90, "metal", COL_IRON, 0.0, 6, false)
			_sphere(leaf, "Finial %d" % bar,
				Vector3(0, 2.24, -0.28 - float(bar) * 0.33), 0.055, "metal",
				COL_BRONZE, 0.0, false)


## Luminous core shared by the model and fallback gate piers. The surrounding
## housing is Blender geometry; this is deliberately tiny so it reads as a bulb
## behind glazing rather than the old glowing cube. The OmniLight3D provides the
## actual pool of light on both sides of the gate.
static func _gate_lantern(parent: Node3D, tag: String, at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Court Gate Lantern %s" % tag
	root.position = at
	parent.add_child(root)
	_box(root, "Gate Lantern Glow", Vector3.ZERO, Vector3(0.11, 0.22, 0.11),
		"plain", COL_GLOW, 0.0, false, 2.8)
	var light := OmniLight3D.new()
	light.name = "Court Gate Light %s" % tag
	light.light_color = COL_GLOW
	light.light_energy = 4.5
	light.omni_range = 7.5
	light.shadow_enabled = false
	root.add_child(light)


# --- court fixtures -----------------------------------------------------------


static func _court_fixtures(root: Node3D) -> void:
	var fixtures := Node3D.new()
	fixtures.name = "Court Fixtures"
	root.add_child(fixtures)

	# Urns flanking the perron. Both ranks have to stand on the "Entrance Plaza"
	# slab (x +-8.5, z 35.4..41.0): the old north rank at z 41.4 carried 0.98 m of
	# its 0.86 m plinth over bare ground, which reads as dropped, not placed. The
	# pair is now set symmetrically about the slab's centre line at z 38.2, with
	# 0.97 m of paving left beyond each foot.
	for ux: float in [-7.7, 7.7]:
		for uz: float in [36.8, 39.6]:
			var at := Vector3(ux, 0.0, uz)
			var urn := MuseumModels.place(fixtures, "lp_court_urn", at)
			if urn != null:
				urn.name = "Court Urn %s %s" % [ux, uz]
			else:
				# Missing-import fallback keeps the old stone silhouette, but the
				# production path is the authored vase with individual leaves.
				_box(fixtures, "Urn Plinth", at + Vector3(0, 0.22, 0),
					Vector3(0.86, 0.44, 0.86), "stone", COL_STONE_DARK, 0.0)
				_box(fixtures, "Urn Die", at + Vector3(0, 0.62, 0),
					Vector3(0.66, 0.40, 0.66), "stone", COL_STONE, 0.0)
				_cone(fixtures, "Urn Foot", at + Vector3(0, 0.92, 0),
					0.20, 0.34, 0.22, "stone", COL_BASIN, 0.0, 14)
				_sphere(fixtures, "Urn Body", at + Vector3(0, 1.28, 0), 0.44,
					"stone", COL_BASIN, 0.0)
				_torus(fixtures, "Urn Lip", at + Vector3(0, 1.58, 0),
					0.34, 0.48, "stone", COL_COPING, 0.0)
			_solid_cyl(fixtures, "Urn Collision", at + Vector3(0, 0.73, 0),
				0.46, 1.46)

	# Bollards ring the fountain apron and the walk down the axis is left clear.
	# Skipping the four axial posts was not enough: the ones at 60, 120, 240 and
	# 300 degrees landed at x +-2.55, inside the 6.4 m walkway they were meant to
	# leave open, so two stood in the gate throat and two on the perron approach
	# and squeezed the walk to 1.00 m against the basin. A post is placed only
	# where it clears the paving by more than a body's width, which leaves the
	# promenade the full width of the paving it runs on.
	for i in range(12):
		var angle: float = TAU * float(i) / 12.0
		var at := Vector3(cos(angle) * (FOUNTAIN_APRON_R + 0.85), 0.0,
			FOUNTAIN_Z + sin(angle) * (FOUNTAIN_APRON_R + 0.85))
		if absf(at.x) < COURT_WALK_HALF + 0.7:
			continue
		_cyl(fixtures, "Court Bollard", at + Vector3(0, 0.46, 0), 0.115, 0.92,
			"metal", COL_IRON, 0.0, 10)
		_sphere(fixtures, "Court Bollard Cap", at + Vector3(0, 0.94, 0), 0.12,
			"metal", COL_BRONZE, 0.0, false)
		_solid_cyl(fixtures, "Court Bollard Collision", at + Vector3(0, 0.46, 0),
			0.16, 0.92)
