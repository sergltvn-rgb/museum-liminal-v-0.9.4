@tool
class_name FacadeProps
extends RefCounted
## Procedural classicist-baroque street facade for the First Museum, plus the
## entrance perron in front of it. Two public builders:
##
##   build_classical_facade()  rusticated plinth, giant-order pilasters, six
##                             ionic columns, entablature with dentils, the
##                             signed frieze, a pedimented portico with a
##                             baroque cartouche, a parapet balustrade and six
##                             tall framed windows.
##   build_entrance_porch()    the stylobate deck the columns stand on, three
##                             walkable steps, cheek parapets with lanterns,
##                             and the moulded door portal with wall sconces.
##
## SELF-CONTAINED BY DESIGN, like every other file in game/props: primitives,
## StandardMaterial3D and a static material cache only. Nothing here preloads
## or references another project script.
##
## ---------------------------------------------------------------------------
## LOCAL FRAME
## ---------------------------------------------------------------------------
## Both builders take (parent, origin, yaw_deg) and author children in the
## root's LOCAL space:
##
##   * origin is the point where the CENTRE of the building's street wall
##     meets the ground: for FirstMuseumMap that is (0, 0, 35), the exterior
##     face of the Entrance Zone south wall;
##   * z = 0 is the wall face and +Z points AT THE STREET. Wall-applied
##     pieces start at z = -0.02, i.e. embedded 2 cm into the wall, so no
##     face of this file is ever coplanar with the wall slab itself;
##   * x = 0 is the doorway axis. The facade is symmetrical about it.
##
## ---------------------------------------------------------------------------
## WALKING CONTRACT — read before moving anything
## ---------------------------------------------------------------------------
## The interior lobby floor is y = 0 and cannot be raised, so the perron works
## in BOTH directions off PlayerController's step mechanics (step_height 0.38,
## floor_snap_length 0.38):
##
##   plaza 0.045 -> step 0.150 -> step 0.255 -> deck DECK_TOP 0.36
##
## Every riser is 0.105 m; the door sill itself is the deck edge, a 0.36 m
## step that stays under step_height going out and under floor_snap_length
## going in. The clear walk between the portal jambs is 2.40 m and the
## central intercolumniation leaves 2.55 m between column shafts, both wider
## than the 1.8 m DOOR_GAP behind them: the entrance never narrows.
##
## ---------------------------------------------------------------------------
## COLLISION
## ---------------------------------------------------------------------------
## Nothing gets an implicit body. _collider() declares blocking volumes by
## hand: the deck, the two steps, the two cheek parapets, the six columns,
## the four pilasters, the two plinth runs and the two portal jambs. All
## mouldings, window dressings, balusters and the pediment are collision-free
## scenery — they are either on the wall or far above the head.
##
## ---------------------------------------------------------------------------
## HEIGHTS (local y)
## ---------------------------------------------------------------------------
##   0.36  deck (DECK_TOP)          5.41  architrave top
##   1.03  plinth cap top           6.03  frieze top (sign board on it)
##   3.16  string course            6.60  cornice top / balustrade base
##   3.46  attic storey base        7.25  balustrade rail top
##   5.01  column/pilaster top      8.15  pediment apex (finial to ~8.55)
##
## The facade deliberately rises above the interior WALL_HEIGHT of 3.4 m: the
## attic storey band stands ON TOP of the wall, in front of the ceiling slab,
## so the roof geometry behind it is untouched.

# --- Layout constants the integrator may read --------------------------------

## Top of the porch stylobate; also the height of the door sill step.
const DECK_TOP := 0.36
## Deck depth from the wall face to the first riser.
const DECK_DEPTH := 3.0
## Half-width of the whole facade (the Entrance Zone wall is 22 m wide).
const HALF_WIDTH := 11.0
## Half-width of the pedimented portico bay.
const PORTICO_HALF := 5.7
## Column axes, local x. Hexastyle with a widened central intercolumniation.
const COLUMN_XS := [-5.1, -3.3, -1.5, 1.5, 3.3, 5.1]
## Column axis distance from the wall face.
const COLUMN_Z := 1.9
## Soffit of the architrave == top of every column and pilaster.
const ORDER_TOP := 5.01
const ARCHITRAVE_TOP := 5.41
const FRIEZE_TOP := 6.03
const CORNICE_TOP := 6.60
const PEDIMENT_APEX := 8.15
## Centre of the "Museum Sign" board on the portico frieze, local space. The
## board's street face is at z 2.36; the map's Label3D belongs ~0.08 in front.
const SIGN_CENTRE := Vector3(0.0, 5.72, 2.31)

# --- Palette ------------------------------------------------------------------
# Limestone family tuned for the night scene: light body stone, a darker
# rusticated base, near-white mouldings, and exactly two warm emissive glows
# (the porch lanterns and the door sconces) so the entrance reads at night.

const MatLib := preload("res://game/props/MaterialLib.gd")
# Только через preload: глобальное имя класса в голом --script-прогоне не
# регистрируется и вся цепочка падает (раздел 14 плана).
# Фасад — единственное место, где камень светлее роли: тут `tone()` идёт
# в плюс, а не в минус. Объявлено `static var`: вызов функции не константен.
const Pal := preload("res://game/props/Palette.gd")

static var COL_STONE := Pal.tone(Pal.STONE, 0.40)
static var COL_PLINTH := Pal.tone(Pal.STONE, -0.05)
static var COL_MOLDING := Pal.tone(Pal.STONE, 0.57)
static var COL_RECESS := Pal.tone(Pal.STONE, -0.24)
static var COL_GLASS := Pal.tone(Pal.SHELL, -0.20)
static var COL_MUNTIN := Pal.tone(Pal.WOOL, -0.27)
static var COL_SIGN_BOARD := Pal.tone(Pal.SLATE, -0.45)
static var COL_BRONZE := Pal.tone(Pal.BRASS, -0.30)
const COL_LAMP_GLOW := Color(0.95, 0.83, 0.55)

# --- Static caches ------------------------------------------------------------
# Shared across every call: a dressed facade costs about a dozen
# StandardMaterial3D and the two 128 px noise textures.

static var _materials: Dictionary = {}
static var _roughness_noise: NoiseTexture2D = null
static var _normal_noise: NoiseTexture2D = null


# ===========================================================================
# Primitive layer — mirrors OfficeProps so a reader is never surprised.
# ===========================================================================


## Root node every builder returns. Named, positioned and yawed before its
## children are authored, so all child coordinates are local.
static func _root(parent: Node3D, node_name: String, origin: Vector3,
		yaw_deg: float) -> Node3D:
	var root := Node3D.new()
	# A repeated sibling name makes Godot rename the second prop to @Node3D@NNN.
	if parent.has_node(NodePath(node_name)):
		node_name = "%s %s" % [node_name, origin]
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
	mesh.radial_segments = 12
	mesh.rings = 6
	return _primitive(parent, node_name, sphere_position, mesh,
		Vector3(radius * 2.0, radius * 2.0, radius * 2.0), color, false,
		emission_energy, 0.0)


static func _prism(parent: Node3D, node_name: String, prism_position: Vector3,
		size: Vector3, color: Color, emission_energy := 0.0) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _primitive(parent, node_name, prism_position, mesh, size, color,
		false, emission_energy, 0.0)


## TorusMesh lies flat in the XZ plane by default; `upright` stands it up the
## way FirstMuseumMap._torus does (the cartouche wreath wants that).
static func _torus(parent: Node3D, node_name: String, torus_position: Vector3,
		inner_radius: float, outer_radius: float, color: Color,
		upright := false) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 18
	mesh.ring_segments = 6
	var thickness := outer_radius - inner_radius
	var inst := _primitive(parent, node_name, torus_position, mesh,
		Vector3(outer_radius * 2.0, thickness, outer_radius * 2.0), color,
		false, 0.0, 0.0)
	if upright:
		inst.rotate_x(deg_to_rad(90))
	return inst


static func _primitive(parent: Node3D, node_name: String,
		prim_position: Vector3, mesh: PrimitiveMesh, size: Vector3,
		color: Color, transparent: bool, emission_energy: float,
		metallic: float) -> MeshInstance3D:
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
	# Same culling policy as the rest of the museum.
	instance.visibility_range_end = 115.0
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if size.length() < 0.65:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


## The only source of physics bodies in this file. One box per blocking
## volume, sized to what the player can actually walk into.
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


## Цвет ордера -> набор карт. Колонны и фронтон игрок видит вплотную,
## поднимаясь по крыльцу, — шума на такой дистанции не хватает.
static func _pack_for(color: Color) -> String:
	if color.is_equal_approx(COL_STONE) or color.is_equal_approx(COL_MOLDING):
		return "quartzite"
	if color.is_equal_approx(COL_PLINTH) or color.is_equal_approx(COL_RECESS):
		return "concrete"
	if color.is_equal_approx(COL_MUNTIN) or color.is_equal_approx(COL_BRONZE) \
			or color.is_equal_approx(COL_SIGN_BOARD):
		return "painted_metal"
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

	# Enough grain that night-lit limestone is not a flat swatch, not so much
	# that it turns into television static.
	if not transparent and emission_energy <= 0.0 and not MatLib.apply_flat_style(mat) and metallic < 0.35:
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


# ===========================================================================
# Public builders
# ===========================================================================


## The street face of the museum: everything from the rusticated plinth up to
## the pediment finial. Purely applied architecture — it decorates the wall,
## it does not replace it. Bounding box ~22.0 x 8.6 x 2.9 (from the wall out).
## `width` is the full width of the wall being dressed.
static func build_classical_facade(parent: Node3D, origin: Vector3,
		width := 22.0, yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, "Museum Facade", origin, yaw_deg)
	var half := width * 0.5

	_facade_plinth(root, half)
	_facade_string_courses(root, width)
	_facade_attic(root)

	# Giant-order pilasters: one pair bracketing the whole front, one pair
	# bracketing the portico bay. They carry the visual load of the flanks.
	for px: float in [-(half - 0.5), -5.85, 5.85, half - 0.5]:
		_pilaster(root, px)

	# The hexastyle colonnade stands on the porch deck, not on the ground:
	# classical orders never grow out of pavement.
	for cx: float in COLUMN_XS:
		_column(root, Vector3(cx, DECK_TOP, COLUMN_Z))

	_entablature(root)
	_pediment(root)
	_balustrade(root, half)

	# Six tall windows on the flanks, clear of the portico bay.
	for wx: float in [-9.15, -7.05, -3.4, 3.4, 7.05, 9.15]:
		_window(root, wx)

	_sign_board(root)
	return root


# ---------------------------------------------------------------------------
# Facade parts
# ---------------------------------------------------------------------------


## Rusticated base storey, one run per side of the doorway. A dark core sits
## 2 cm into the wall; three rows of running-bond blocks stand proud of it so
## the joints between them read as shadow grooves. Cap moulding on top.
static func _facade_plinth(root: Node3D, half: float) -> void:
	for side: float in [-1.0, 1.0]:
		var side_name := "West" if side < 0.0 else "East"
		# The run spans from the door surround (x 1.7) to the facade edge.
		var inner := 1.7
		var run := half - inner
		var cx := side * (inner + run * 0.5)
		# The dark core reaches 2 cm further in than the blocks, under the
		# door surround. It used to stop dead on x = 1.7, the same plane the
		# R1 bond block and the R2 closer start on, and those ends flickered
		# against each other (0.022 m2 a pair, four pairs). The core is a
		# shadow gap nobody reads, so widening it costs nothing.
		var core_inner := inner - 0.02
		var core_run := half - core_inner
		var core_cx := side * (core_inner + core_run * 0.5)
		_box(root, "Plinth Core %s" % side_name,
			Vector3(core_cx, 0.46, 0.11), Vector3(core_run, 0.92, 0.26),
			COL_RECESS)
		_collider(root, "Plinth %s" % side_name,
			Vector3(cx, 0.46, 0.12), Vector3(run, 0.92, 0.28))
		# Three courses of blocks, odd rows shifted half a block (running
		# bond). Blocks are 1.62 long with 0.09 gaps that expose the core.
		for row in range(3):
			var row_y := 0.15 + 0.30 * row
			var offset := 0.855 if row % 2 == 1 else 0.0
			var x := inner + offset
			if offset > 0.0:
				# Odd rows start with a shorter bond block at the surround.
				_box(root, "Plinth Bond %s R%d" % [side_name, row],
					Vector3(side * (inner + 0.375), row_y, 0.245),
					Vector3(0.75, 0.27, 0.17), COL_PLINTH)
			var block := 0
			while x + 1.62 <= half - 0.05:
				_box(root, "Plinth Block %s R%d %d" % [side_name, row, block],
					Vector3(side * (x + 0.81), row_y, 0.245),
					Vector3(1.62, 0.27, 0.17), COL_PLINTH)
				x += 1.71
				block += 1
			# Closer block fills the remainder at the facade edge.
			var rest := half - 0.05 - x
			if rest > 0.2:
				_box(root, "Plinth Closer %s R%d" % [side_name, row],
					Vector3(side * (x + rest * 0.5), row_y, 0.245),
					Vector3(rest, 0.27, 0.17), COL_PLINTH)
		_box(root, "Plinth Cap %s" % side_name,
			Vector3(cx, 0.975, 0.16), Vector3(run + 0.10, 0.11, 0.40),
			COL_MOLDING)


## Two horizontal bands that tie the flanks together and, not incidentally,
## mask interior wall trims that leak through to the street face (the accent
## stripe at y 1.25 and the wall cornice at y 3.26 both protrude ~2 cm).
static func _facade_string_courses(root: Node3D, width: float) -> void:
	# Both bands stop 2 cm short of the building corner. Run them out to
	# x = 11 and they end on the very plane where the Entrance Zone's wall
	# segments and its ceiling slab end: five pairs of end faces shared it
	# (0.005 m2 twice, 0.003 twice, 0.001 once). A stopped moulding is
	# ordinary detailing, and the corner itself is dressed by BuildingShell.
	var stop := 0.02
	for side: float in [-1.0, 1.0]:
		var side_name := "West" if side < 0.0 else "East"
		var run := width * 0.5 - 1.7 - stop
		var cx := side * (1.7 + run * 0.5)
		_box(root, "Sill Course %s" % side_name,
			Vector3(cx, 1.21, 0.05), Vector3(run, 0.16, 0.14), COL_MOLDING)
	# Full-width course at the wall top; also the visual floor of the attic.
	_box(root, "String Course", Vector3(0.0, 3.31, 0.30),
		Vector3(width - stop * 2.0, 0.30, 0.64), COL_MOLDING)


## Attic storey: a full-width band standing ON TOP of the 3.4 m interior
## wall, in FRONT of the ceiling slab (which ends at the wall plane), with
## four recessed panels over the flank windows.
static func _facade_attic(root: Node3D) -> void:
	_box(root, "Attic Band", Vector3(0.0, 4.235, 0.20),
		Vector3(HALF_WIDTH * 2.0, 1.55, 0.40), COL_STONE)
	for px: float in [-9.15, -7.05, 7.05, 9.15]:
		var tag := "%.2f" % px
		_box(root, "Attic Panel Field %s" % tag,
			Vector3(px, 4.235, 0.41), Vector3(1.30, 0.86, 0.04), COL_RECESS)
		_box(root, "Attic Panel Rail Top %s" % tag,
			Vector3(px, 4.70, 0.42), Vector3(1.46, 0.08, 0.06), COL_MOLDING)
		_box(root, "Attic Panel Rail Bottom %s" % tag,
			Vector3(px, 3.77, 0.42), Vector3(1.46, 0.08, 0.06), COL_MOLDING)
		_box(root, "Attic Panel Stile West %s" % tag,
			Vector3(px - 0.69, 4.235, 0.42), Vector3(0.08, 1.01, 0.06),
			COL_MOLDING)
		_box(root, "Attic Panel Stile East %s" % tag,
			Vector3(px + 0.69, 4.235, 0.42), Vector3(0.08, 1.01, 0.06),
			COL_MOLDING)


## Flat giant-order pilaster applied to the wall: base block, shaft with one
## recessed flute, neck ring and cap. Runs from the plinth cap to ORDER_TOP.
static func _pilaster(root: Node3D, px: float) -> void:
	var tag := "%.2f" % px
	_box(root, "Pilaster Base %s" % tag,
		Vector3(px, 1.20, 0.28), Vector3(0.84, 0.34, 0.60), COL_MOLDING)
	_box(root, "Pilaster Shaft %s" % tag,
		Vector3(px, 2.95, 0.26), Vector3(0.72, 3.16, 0.56), COL_STONE)
	# One central flute: a dark strip on the shaft face that reads as a
	# carved groove at night.
	_box(root, "Pilaster Flute %s" % tag,
		Vector3(px, 2.95, 0.55), Vector3(0.16, 2.86, 0.02), COL_RECESS)
	_box(root, "Pilaster Neck %s" % tag,
		Vector3(px, 4.60, 0.27), Vector3(0.78, 0.10, 0.58), COL_MOLDING)
	_box(root, "Pilaster Cap %s" % tag,
		Vector3(px, 4.86, 0.29), Vector3(0.88, 0.16, 0.62), COL_MOLDING)
	_collider(root, "Pilaster %s" % tag,
		Vector3(px, 2.86, 0.28), Vector3(0.86, 5.00, 0.60))


## Free-standing ionic column: plinth, torus base, shaft with entasis
## (top radius 0.205 against 0.235 at the foot), echinus, two volute rolls
## and a square abacus meeting the architrave soffit at ORDER_TOP.
## `foot` is the centre of the plinth's underside, in root space.
static func _column(root: Node3D, foot: Vector3) -> void:
	var tag := "%.2f" % foot.x
	var x := foot.x
	var z := foot.z
	var y := foot.y
	_box(root, "Column Plinth %s" % tag,
		Vector3(x, y + 0.05, z), Vector3(0.62, 0.10, 0.62), COL_MOLDING)
	_torus(root, "Column Base Torus %s" % tag,
		Vector3(x, y + 0.145, z), 0.175, 0.295, COL_MOLDING)
	_cone(root, "Column Base Fillet %s" % tag,
		Vector3(x, y + 0.225, z), 0.27, 0.235, 0.07, COL_MOLDING)
	_cone(root, "Column Shaft %s" % tag,
		Vector3(x, y + 2.26, z), 0.235, 0.205, 4.00, COL_STONE)
	_cone(root, "Column Echinus %s" % tag,
		Vector3(x, y + 4.315, z), 0.21, 0.30, 0.11, COL_MOLDING)
	# Ionic volutes: two horizontal rolls flanking the echinus.
	for side: float in [-1.0, 1.0]:
		var roll := _cylinder(root,
			"Column Volute %s %s" % ["West" if side < 0.0 else "East", tag],
			Vector3(x + side * 0.27, y + 4.40, z), 0.115, 0.16, COL_MOLDING)
		roll.rotate_z(deg_to_rad(90))
	_box(root, "Column Abacus %s" % tag,
		Vector3(x, y + 4.575, z), Vector3(0.66, 0.15, 0.66), COL_MOLDING)
	_collider(root, "Column %s" % tag,
		Vector3(x, y + 2.325, z), Vector3(0.55, 4.65, 0.55))


## The horizontal beam the whole order carries: a deep architrave-and-frieze
## bay over the portico (its soffit is the porch ceiling, so it gets a row of
## dark coffers) and a shallow applied run over each flank, all crowned by
## the stepped cornice.
static func _entablature(root: Node3D) -> void:
	# --- Portico bay: spans the six columns, from the wall out past them.
	_box(root, "Portico Architrave", Vector3(0.0, 5.21, 1.185),
		Vector3(11.4, 0.40, 2.41), COL_STONE)
	_box(root, "Portico Tenia", Vector3(0.0, 5.38, 2.41),
		Vector3(11.5, 0.06, 0.08), COL_MOLDING)
	_box(root, "Portico Frieze", Vector3(0.0, 5.72, 1.13),
		Vector3(11.4, 0.62, 2.30), COL_STONE)
	_cornice_stack(root, "Portico", 0.0, 11.4, 2.28)
	# Coffered porch soffit, embedded 1 cm up into the architrave.
	for i in range(8):
		var cx := -4.2 + 1.2 * i
		_box(root, "Porch Coffer %d" % i, Vector3(cx, 4.99, 1.13),
			Vector3(0.95, 0.06, 1.60), COL_RECESS)
	# --- Flank runs: shallow, hugging the wall from the portico to the edge.
	for side: float in [-1.0, 1.0]:
		var side_name := "West" if side < 0.0 else "East"
		_box(root, "Flank Architrave %s" % side_name,
			Vector3(side * 8.35, 5.21, 0.32), Vector3(5.3, 0.40, 0.68),
			COL_STONE)
		_box(root, "Flank Frieze %s" % side_name,
			Vector3(side * 8.35, 5.72, 0.30), Vector3(5.3, 0.62, 0.64),
			COL_STONE)
		_cornice_stack(root, "Flank %s" % side_name, side * 8.35, 5.3, 0.62,
			side)


## Three cornice steps with growing overhang and, under them, a dentil row.
## `shift_sign` 0 widens the steps symmetrically (portico); ±1 keeps the run
## constant and shifts each step outward so flank steps butt EXACTLY against
## the portico steps — overlapping them would put two upward faces in the
## same plane and shimmer.
static func _cornice_stack(root: Node3D, tag: String, cx: float, run: float,
		front: float, shift_sign := 0.0) -> void:
	var juts: Array[float] = [0.17, 0.32, 0.47]
	var widens: Array[float] = [0.10, 0.22, 0.34]
	for i in range(3):
		var step_width := run + (widens[i] if shift_sign == 0.0 else 0.0)
		var step_x := cx + shift_sign * widens[i] * 0.5
		var step_front := front + juts[i]
		_box(root, "%s Cornice Step %d" % [tag, i],
			Vector3(step_x, 6.125 + 0.19 * i, (step_front - 0.02) * 0.5),
			Vector3(step_width, 0.19, step_front + 0.02), COL_MOLDING)
	# Dentil row tucked under the first step, embedded 1 cm into the frieze.
	var count := int(floor((run - 0.4) / 0.48))
	var start := cx - 0.48 * (count - 1) * 0.5
	for d in range(count):
		_box(root, "%s Dentil %d" % [tag, d],
			Vector3(start + 0.48 * d, 5.955, front + 0.05),
			Vector3(0.15, 0.13, 0.12), COL_MOLDING)


## Triangular pediment over the portico, with a recessed tympanum field and
## a baroque cartouche (laurel torus, boss and volute rolls) at its centre.
static func _pediment(root: Node3D) -> void:
	_prism(root, "Pediment", Vector3(0.0, 7.375, 1.38),
		Vector3(12.0, 1.55, 2.72), COL_MOLDING)
	_prism(root, "Pediment Tympanum", Vector3(0.0, 7.17, 2.755),
		Vector3(10.2, 1.14, 0.07), COL_STONE)
	_torus(root, "Cartouche Wreath", Vector3(0.0, 7.0, 2.82), 0.16, 0.30,
		COL_MOLDING, true)
	_sphere(root, "Cartouche Boss", Vector3(0.0, 7.0, 2.82), 0.14,
		COL_MOLDING)
	for side: float in [-1.0, 1.0]:
		var roll := _cylinder(root,
			"Cartouche Volute %s" % ("West" if side < 0.0 else "East"),
			Vector3(side * 0.42, 6.94, 2.80), 0.09, 0.22, COL_MOLDING)
		roll.rotate_z(deg_to_rad(90))
	_box(root, "Pediment Apex Pedestal", Vector3(0.0, 8.22, 1.38),
		Vector3(0.40, 0.14, 0.40), COL_MOLDING)
	_sphere(root, "Pediment Finial", Vector3(0.0, 8.42, 1.38), 0.16,
		COL_MOLDING)


## Parapet balustrade along each flank cornice, between the pediment and the
## facade corners: pedestal-urn bookends, a sill, turned balusters (cones)
## and a flat rail. Pure scenery — nothing up here needs a collider.
static func _balustrade(root: Node3D, half: float) -> void:
	for side: float in [-1.0, 1.0]:
		var side_name := "West" if side < 0.0 else "East"
		var inner := 6.15
		var outer := half - 0.3
		for px: float in [inner, outer]:
			var tag := "%s %.2f" % [side_name, px]
			_box(root, "Balustrade Pedestal %s" % tag,
				Vector3(side * px, 6.875, 0.30), Vector3(0.42, 0.55, 0.42),
				COL_MOLDING)
			_sphere(root, "Balustrade Urn %s" % tag,
				Vector3(side * px, 7.28, 0.30), 0.13, COL_MOLDING)
		var mid := (inner + outer) * 0.5
		var span := outer - inner - 0.42
		_box(root, "Balustrade Sill %s" % side_name,
			Vector3(side * mid, 6.665, 0.30), Vector3(span, 0.13, 0.36),
			COL_MOLDING)
		var count := int(floor((span - 0.3) / 0.44))
		var start := mid - 0.44 * (count - 1) * 0.5
		for b in range(count):
			_cone(root, "Baluster %s %d" % [side_name, b],
				Vector3(side * (start + 0.44 * b), 6.93, 0.30),
				0.075, 0.045, 0.40, COL_MOLDING)
		_box(root, "Balustrade Rail %s" % side_name,
			Vector3(side * mid, 7.19, 0.30), Vector3(span, 0.12, 0.24),
			COL_MOLDING)


## Tall flank window: near-black recessed glazing with proud muntins, framed
## by jambs, a bracketed sill and a corniced lintel with a keystone. Purely
## applied — the wall behind it is solid, so the glass stays opaque-dark,
## which is exactly what an unlit museum window looks like at night.
static func _window(root: Node3D, wx: float) -> void:
	var tag := "%.2f" % wx
	# Glazing: centre y 2.20, 1.10 x 1.85, its face 3 cm proud of the wall.
	_box(root, "Window Glass %s" % tag,
		Vector3(wx, 2.20, 0.03), Vector3(1.10, 1.85, 0.10), COL_GLASS)
	_box(root, "Window Muntin V %s" % tag,
		Vector3(wx, 2.20, 0.075), Vector3(0.06, 1.85, 0.03), COL_MUNTIN)
	_box(root, "Window Muntin H1 %s" % tag,
		Vector3(wx, 2.66, 0.075), Vector3(1.10, 0.06, 0.03), COL_MUNTIN)
	_box(root, "Window Muntin H2 %s" % tag,
		Vector3(wx, 1.74, 0.075), Vector3(1.10, 0.06, 0.03), COL_MUNTIN)
	# Surround.
	_box(root, "Window Jamb West %s" % tag,
		Vector3(wx - 0.64, 2.20, 0.07), Vector3(0.18, 2.05, 0.18),
		COL_MOLDING)
	_box(root, "Window Jamb East %s" % tag,
		Vector3(wx + 0.64, 2.20, 0.07), Vector3(0.18, 2.05, 0.18),
		COL_MOLDING)
	_box(root, "Window Sill %s" % tag,
		Vector3(wx, 1.135, 0.11), Vector3(1.62, 0.12, 0.30), COL_MOLDING)
	for side: float in [-1.0, 1.0]:
		_box(root, "Window Sill Bracket %s %s"
			% ["West" if side < 0.0 else "East", tag],
			Vector3(wx + side * 0.52, 1.02, 0.08), Vector3(0.12, 0.11, 0.16),
			COL_MOLDING)
	_box(root, "Window Lintel %s" % tag,
		Vector3(wx, 3.305, 0.07), Vector3(1.54, 0.16, 0.18), COL_MOLDING)
	_box(root, "Window Lintel Cornice %s" % tag,
		Vector3(wx, 3.435, 0.10), Vector3(1.70, 0.10, 0.24), COL_MOLDING)
	_box(root, "Window Keystone %s" % tag,
		Vector3(wx, 3.32, 0.17), Vector3(0.24, 0.30, 0.10), COL_MOLDING)


## The museum's name board, centred on the portico frieze. Keeps the legacy
## node name "Museum Sign": the Label3D the map hangs in front of it expects
## the board 5 cm behind its text.
static func _sign_board(root: Node3D) -> void:
	_box(root, "Museum Sign", SIGN_CENTRE + Vector3(0.0, 0.0, -0.02),
		Vector3(6.8, 0.55, 0.10), COL_SIGN_BOARD)
	for side: float in [-1.0, 1.0]:
		_sphere(root, "Sign Rosette %s" % ("West" if side < 0.0 else "East"),
			SIGN_CENTRE + Vector3(side * 3.15, 0.0, 0.02), 0.055, COL_BRONZE)


# ===========================================================================
# Entrance porch
# ===========================================================================


## The stylobate the colonnade stands on: deck, two walkable steps, cheek
## parapets carrying lanterns, and the moulded door portal on the wall.
## Bounding box ~11.9 x 4.4 x 4.0 (from the wall out). See the WALKING
## CONTRACT in the header before touching any height here.
static func build_entrance_porch(parent: Node3D, origin: Vector3,
		yaw_deg := 0.0) -> Node3D:
	var root := _root(parent, "Entrance Porch", origin, yaw_deg)
	_porch_deck(root)
	_porch_parapets(root)
	_door_portal(root)
	return root


## Deck at DECK_TOP plus two full-width treads. Every walkable top gets its
## own collider box — the navmesh outside is not baked, so the only cost is
## the player's capsule.
static func _porch_deck(root: Node3D) -> void:
	_box(root, "Porch Deck", Vector3(0.0, DECK_TOP * 0.5, DECK_DEPTH * 0.5),
		Vector3(11.1, DECK_TOP, DECK_DEPTH), COL_PLINTH)
	_collider(root, "Porch Deck",
		Vector3(0.0, DECK_TOP * 0.5, DECK_DEPTH * 0.5),
		Vector3(11.1, DECK_TOP, DECK_DEPTH))
	_box(root, "Porch Deck Nosing", Vector3(0.0, DECK_TOP - 0.025, 3.02),
		Vector3(11.1, 0.05, 0.12), COL_MOLDING)
	# Treads: name, top height, near z, far z. Risers of 0.105 land on the
	# plaza slab at 0.045 (see the header).
	var treads: Array = [
		["Upper", 0.255, 3.0, 3.46],
		["Lower", 0.150, 3.46, 3.92],
	]
	for tread: Array in treads:
		var tread_name: String = tread[0]
		var top: float = tread[1]
		var near_z: float = tread[2]
		var far_z: float = tread[3]
		var depth := far_z - near_z
		var centre := Vector3(0.0, top * 0.5, near_z + depth * 0.5)
		var size := Vector3(11.1, top, depth)
		_box(root, "Porch Step %s" % tread_name, centre, size, COL_PLINTH)
		_collider(root, "Porch Step %s" % tread_name, centre, size)
		_box(root, "Porch Step %s Nosing" % tread_name,
			Vector3(0.0, top - 0.02, far_z - 0.05),
			Vector3(11.1, 0.04, 0.10), COL_MOLDING)


## Cheek parapets: solid blocks flanking the steps, capped, each carrying a
## warm-glow lantern — the porch's night-time light source cue.
static func _porch_parapets(root: Node3D) -> void:
	for side: float in [-1.0, 1.0]:
		var side_name := "West" if side < 0.0 else "East"
		var x := side * 5.95
		_box(root, "Porch Parapet %s" % side_name,
			Vector3(x, 0.415, 1.95), Vector3(0.80, 0.83, 3.90), COL_PLINTH)
		_box(root, "Porch Parapet Cap %s" % side_name,
			Vector3(x, 0.86, 1.95), Vector3(0.90, 0.06, 4.00), COL_MOLDING)
		_collider(root, "Porch Parapet %s" % side_name,
			Vector3(x, 0.445, 1.95), Vector3(0.90, 0.89, 4.00))
		# Lantern on the street end of the cap.
		_box(root, "Lantern Pedestal %s" % side_name,
			Vector3(x, 0.95, 3.60), Vector3(0.30, 0.12, 0.30), COL_PLINTH)
		_box(root, "Lantern Body %s" % side_name,
			Vector3(x, 1.19, 3.60), Vector3(0.22, 0.36, 0.22), COL_BRONZE,
			0.0, 0.6)
		# 1.3 clipped this glass to white. COL_LAMP_GLOW is (0.95, 0.83, 0.55), so
		# at 1.3 the emission is (1.235, 1.079, 0.715): red AND green sit over the
		# ceiling, the hue is gone and the porch lanterns render as white cubes --
		# which is what the owner saw in the acceptance shot and called strange.
		# 0.9 gives (0.855, 0.747, 0.495), still the brightest thing on the porch
		# and still amber. It is also the energy the gate lanterns in GroundsProps
		# have used all along, so the whole outdoor family now agrees.
		_box(root, "Lantern Glass %s" % side_name,
			Vector3(x, 1.19, 3.60), Vector3(0.16, 0.26, 0.16), COL_LAMP_GLOW,
			0.9)
		_cone(root, "Lantern Cap %s" % side_name,
			Vector3(x, 1.42, 3.60), 0.16, 0.02, 0.10, COL_BRONZE, 0.0, 0.6)


## Door portal: panelled jambs with consoles, an over-door frieze and
## cornice, a small pediment, and a warm sconce either side. The clear walk
## between the jamb faces is 2.40 m; the map's own door frame (jambs out to
## x 1.17, doorway signs at z 0.425-0.475 up to y 2.96) sits entirely inside
## and below this surround.
static func _door_portal(root: Node3D) -> void:
	for side: float in [-1.0, 1.0]:
		var side_name := "West" if side < 0.0 else "East"
		var x := side * 1.40
		_box(root, "Portal Jamb %s" % side_name,
			Vector3(x, 1.51, 0.24), Vector3(0.40, 3.02, 0.52), COL_MOLDING)
		_box(root, "Portal Jamb Panel %s" % side_name,
			Vector3(x, 1.60, 0.51), Vector3(0.22, 2.30, 0.02), COL_RECESS)
		_box(root, "Portal Jamb Base %s" % side_name,
			Vector3(x, 0.22, 0.26), Vector3(0.48, 0.44, 0.56), COL_PLINTH)
		_collider(root, "Portal Jamb %s" % side_name,
			Vector3(x, 1.51, 0.26), Vector3(0.48, 3.02, 0.56))
		# Console bracket carrying the over-door frieze.
		_box(root, "Portal Console %s" % side_name,
			Vector3(x, 2.90, 0.40), Vector3(0.32, 0.24, 0.30), COL_MOLDING)
	_box(root, "Portal Frieze", Vector3(0.0, 3.19, 0.24),
		Vector3(3.60, 0.34, 0.48), COL_MOLDING)
	_box(root, "Portal Cornice", Vector3(0.0, 3.42, 0.28),
		Vector3(3.80, 0.12, 0.56), COL_MOLDING)
	# The pediment starts 1 cm proud of the wall plane instead of sitting on
	# it: the Attic Band behind it has its own back face at z 0, and above
	# the 3.4 m wall there is no wall left to bury the pair -- 2.04 m2 of two
	# backs flickering. The front face stays at z 0.50, where the tympanum is.
	_prism(root, "Portal Pediment", Vector3(0.0, 3.78, 0.255),
		Vector3(3.40, 0.60, 0.49), COL_MOLDING)
	_prism(root, "Portal Tympanum", Vector3(0.0, 3.70, 0.505),
		Vector3(2.80, 0.36, 0.05), COL_STONE)
	# Wall sconces either side of the doorway, above head height.
	for side: float in [-1.0, 1.0]:
		var side_name := "West" if side < 0.0 else "East"
		var x := side * 2.05
		_box(root, "Sconce Bracket %s" % side_name,
			Vector3(x, 2.32, 0.06), Vector3(0.10, 0.24, 0.16), COL_BRONZE,
			0.0, 0.6)
		# Same ceiling rule as the porch lantern above: 1.3 clipped two channels
		# and turned the door sconces white.
		_box(root, "Sconce Glass %s" % side_name,
			Vector3(x, 2.44, 0.13), Vector3(0.14, 0.22, 0.14), COL_LAMP_GLOW,
			0.9)
		_cone(root, "Sconce Cap %s" % side_name,
			Vector3(x, 2.58, 0.13), 0.11, 0.02, 0.08, COL_BRONZE, 0.0, 0.6)

