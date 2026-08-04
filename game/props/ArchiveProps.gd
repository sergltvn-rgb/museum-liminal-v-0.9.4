@tool
class_name ArchiveProps
extends RefCounted
## Back-of-house furniture: the Archive and the Restoration Lab.
##
## scenes/FirstMuseumMap.tscn holds no 3D content at all -- FirstMuseumMap
## .build_map() assembles the whole building every time the scene loads. These
## builders follow the same rule and the same primitive vocabulary as
## FirstMuseumMap._box()/_primitive(): BoxMesh, CylinderMesh, SphereMesh,
## TorusMesh and PrismMesh, one StandardMaterial3D each, pulled from a shared
## cache.
##
## Every builder takes (parent, origin, ...) and returns the root Node3D it
## added, so a call site places a finished object on one line:
##
##     ArchiveProps.build_archive(map_root, Vector3(-25, 0, -12))
##     ArchiveProps.build_restoration_lab(map_root, Vector3(-25, 0, 22), 0.0,
##         tr(exhibit_tag_key), tr(crate_stencil_key))
##     ArchiveProps.build_card_catalogue(map_root, Vector3(-23, 0, -15.9))
##
## The two room builders are pure composition: they call the piece builders and
## nothing else, so a call site that wants a different arrangement can skip them
## and place the pieces itself.
##
## NO TEXT LITERALS. Player-visible strings arrive as parameters -- see the
## `tag_text` arguments -- because localization/game.csv belongs to another agent
## this round and tools/check_localization.py treats an unanswered UPPER_SNAKE
## literal anywhere under res://game as fatal, comments included. A builder given
## "" builds the physical tag and no Label3D, which is a complete object either
## way. The two keys this file wants are, unquoted so the sweep does not demand
## them before they exist: PROP_EXHIBIT_9_TAG on the dust sheet, and
## PROP_CRATE_DO_NOT_OPEN stencilled on the emptied crate.
##
## NO ANIMATION, ANYWHERE IN THIS FILE. Nothing here moves, flickers or pulses,
## so there is nothing for SettingsManager.reduced_flashes to switch off. The
## horror is silhouette and negative space: a dark slot between two rolled-apart
## shelving carriages, a draped figure too tall to be a person, a packing crate
## whose foam cut-out is the shape of what is no longer in it. Nothing in this
## file conveys meaning by colour alone -- the keep-back line around exhibit 9 is
## a square painted on the floor, readable as an enclosure with no colour vision
## at all.
##
## SCALE. Rooms are 3.4 m tall (FirstMuseumMap.WALL_HEIGHT) and the ceiling
## soffit is at 3.39. The tallest thing built here is the fume hood duct at
## 3.35 m; every builder states its bounding box in its own doc comment.
##
## COLLISION. Visible geometry never carries a collider. Each builder adds one
## or two explicit StaticBody3D volumes covering the walk-blocking bulk instead,
## which keeps the node count down and -- because _bake_navigation() parses
## static colliders -- gives the Curator clean boxes to path around rather than a
## rubble of shelf boards. Nothing here is placed in a doorway.


## Rooms are 3.4 m tall and the visible ceiling soffit is at 3.39 m. Mirrored
## from FirstMuseumMap rather than imported so this file stands alone.
const WALL_HEIGHT := 3.4
const SOFFIT_Y := 3.39

## Doorways are 1.8 m wide and the navigation bake erodes 0.45 m per side.
## Room builders keep every collider clear of the door approach; the figure in
## the Restoration Lab is the closest thing to a threshold and stands 6.1 m back
## from it.
const DOOR_GAP := 1.8

## Practical lights built here join this group, matching game/props/LightProps
## .LIGHT_GROUP, so whatever wires the blackout can collect them all in one
## sweep. Lowercase snake to match the project's existing groups.
const LIGHT_GROUP := "museum_light"

## Beyond this the museum's decorative geometry fades out. Same value as
## FirstMuseumMap._primitive().
const CULL_DISTANCE := 115.0

## Meshes whose bounding box is shorter than this across the diagonal stop
## casting shadows. Same threshold as FirstMuseumMap._primitive(): tiny props
## contribute nothing to a shadow map but cost a draw in it.
const SHADOW_CUTOFF := 0.65

# --- Palette ----------------------------------------------------------------
# Back-of-house, unrestored, lit by whatever still works. Everything is
# desaturated except the tape and the brass, which are the only two things in
# either room anybody ever bothered to keep bright.
const MatLib := preload("res://game/props/MaterialLib.gd")
# Только через preload: глобальное имя класса в голом --script-прогоне не
# регистрируется и вся цепочка падает (раздел 14 плана).
const Pal := preload("res://game/props/Palette.gd")

# Затемнённые роли — `static var`: вызов `tone()` не константное выражение.
# Прямой `Pal.STEEL` здесь был бы вдвое светлее нужного: архив не освещён.
static var _STEEL_DARK := Pal.tone(Pal.STEEL_DARK, -0.30)
static var _STEEL := Pal.tone(Pal.STEEL, -0.55)
# Rolling-stack faces need one readable value step above the archive's deep
# background. The old shared steel turned both banks into near-black cuboids.
static var _STACK_FACE := Pal.tone(Pal.STEEL, -0.30)
const _STACK_TRIM := Color(0.410, 0.435, 0.430)
const _STACK_LABEL := Color(0.650, 0.620, 0.500)
const _STEEL_LIT := Pal.SLATE
# Тёмное дерево, картон и переплёт остаются своими: в палитре есть
# один `WOOD` и два бумажных тона, а архиву нужна градация внутри стопки.
const _WOOD_DARK := Color(0.135, 0.105, 0.075)
const _WOOD := Pal.WOOD
static var _PAPER := Pal.tone(Pal.PAPER, -0.13)
const _CARD := Color(0.545, 0.520, 0.445)
const _BOARD := Color(0.310, 0.265, 0.195)
const _SHEET := Pal.PAPER
const _SHEET_FOLD := Color(0.430, 0.420, 0.395)
const _FOAM := Color(0.275, 0.270, 0.255)
const _VOID := Pal.DARK
static var _BRASS := Pal.tone(Pal.BRASS, -0.37)
const _TAPE := Color(0.560, 0.480, 0.140)
const _LAMP_WARM := Color(0.960, 0.830, 0.560)

## Shared across every builder and every room, so the two rooms together add a
## couple of dozen materials rather than one per mesh. Static: the cache
## outlives any single build_map() call, which is what makes a second load of
## the scene cheap.
static var _materials: Dictionary = {}
static var _roughness_noise: NoiseTexture2D = null
static var _bump_noise: NoiseTexture2D = null


# --- Primitive helpers ------------------------------------------------------
# Deliberately parallel to FirstMuseumMap._box()/_cylinder()/_primitive(), minus
# the collision argument: see the COLLISION note in the class doc.


## Root node for one placed object. Children are authored in its local space, so
## `yaw_degrees` turns the whole thing and the call site never does trigonometry.
##
## force_readable_name is on. Without it, add_child() throws away a name that a
## sibling already holds and substitutes "@Node3D@41", so the second work bench
## in a room -- and the second covered object, and the third stack of box files
## -- would be unidentifiable in the remote scene tree and in the editor after
## FirstMuseumMap._make_generated_map_editable(). It costs a string compare on
## the couple of dozen placed objects per room and buys "Lab Work Bench2".
static func _mount(parent: Node3D, node_name: String, origin: Vector3,
		yaw_degrees: float) -> Node3D:
	var root := Node3D.new()
	# A repeated sibling name makes Godot rename the second prop to @Node3D@NNN,
	# which loses it for anything that looks props up by name. Tag it instead.
	if parent.has_node(NodePath(node_name)):
		node_name = "%s %s" % [node_name, origin]
	root.name = node_name
	root.position = origin
	root.rotation_degrees = Vector3(0, yaw_degrees, 0)
	parent.add_child(root, true)
	return root


static func _primitive(parent: Node3D, node_name: String, prim_position: Vector3,
		mesh: Mesh, extent: Vector3, color: Color, emission_energy: float,
		metallic: float, tilt: Vector3, transparent: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	# Repeated sibling names make Godot fall back to @MeshInstance3D@NNN, which
	# no test or feed can address. Tag the twin with its local offset instead.
	if parent.has_node(NodePath(node_name)):
		node_name = "%s %s" % [node_name, prim_position]
	instance.name = node_name
	instance.position = prim_position
	instance.rotation_degrees = tilt
	instance.mesh = mesh
	instance.material_override = _material(color, transparent, emission_energy, metallic)
	instance.visibility_range_end = CULL_DISTANCE
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if extent.length() < SHADOW_CUTOFF:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func _box(parent: Node3D, node_name: String, box_position: Vector3,
		size: Vector3, color: Color, emission_energy := 0.0, metallic := 0.0,
		tilt := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _primitive(parent, node_name, box_position, mesh, size, color,
		emission_energy, metallic, tilt, false)


static func _cylinder(parent: Node3D, node_name: String, cyl_position: Vector3,
		radius: float, height: float, color: Color, emission_energy := 0.0,
		metallic := 0.0, tilt := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = radius
	mesh.top_radius = radius
	# Half the default rings and segments. Nothing here is bigger than a hand
	# except the fume duct, and none of it is ever seen against the sky.
	mesh.radial_segments = 10
	mesh.rings = 1
	return _primitive(parent, node_name, cyl_position, mesh,
		Vector3(radius * 2.0, height, radius * 2.0), color, emission_energy,
		metallic, tilt, false)


static func _cone(parent: Node3D, node_name: String, cone_position: Vector3,
		bottom_radius: float, top_radius: float, height: float, color: Color,
		emission_energy := 0.0, tilt := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.radial_segments = 10
	mesh.rings = 1
	var widest: float = maxf(bottom_radius, top_radius)
	return _primitive(parent, node_name, cone_position, mesh,
		Vector3(widest * 2.0, height, widest * 2.0), color, emission_energy,
		0.0, tilt, false)


static func _prism(parent: Node3D, node_name: String, prism_position: Vector3,
		size: Vector3, color: Color, tilt := Vector3.ZERO) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _primitive(parent, node_name, prism_position, mesh, size, color,
		0.0, 0.0, tilt, false)


## Rounded pressure point beneath a sheet. Scaling the unit sphere avoids the
## lampshade silhouette made by a cone while keeping this low-poly vocabulary.
static func _ellipsoid(parent: Node3D, node_name: String, sphere_position: Vector3,
		size: Vector3, color: Color, tilt := Vector3.ZERO) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var instance := _primitive(parent, node_name, sphere_position, mesh, size,
		color, 0.0, 0.0, tilt, false)
	instance.scale = size
	return instance


## Invisible semantic child retained for stable inspection/test names when one
## continuous cloth mesh replaces several disconnected primitive panels.
static func _marker(parent: Node3D, node_name: String) -> Node3D:
	var marker := Node3D.new()
	marker.name = node_name
	parent.add_child(marker)
	return marker


## Point on an irregular elliptical cloth ring. The bottom ring gets a wavy hem;
## middle rings can grow one broad lobe where a hidden arm or corner pushes out.
static func _fabric_point(ring_centres: PackedVector3Array,
		ring_radii: PackedVector2Array, ring_index: int, segment: int,
		segment_count: int, hem_wave: float, lobe_angle: float,
		lobe_strength: float) -> Vector3:
	var angle: float = TAU * float(segment % segment_count) / float(segment_count)
	var ring_ratio: float = float(ring_index) / maxf(
		float(ring_centres.size() - 1), 1.0)
	var centre: Vector3 = ring_centres[ring_index]
	var radius: Vector2 = ring_radii[ring_index]
	var fold_scale: float = 1.0 + 0.035 * sin(angle * 4.0 + ring_ratio * 1.6)
	var delta: float = wrapf(angle - lobe_angle, -PI, PI)
	var lobe: float = pow(maxf(cos(delta), 0.0), 6.0) * lobe_strength \
		* sin(PI * ring_ratio)
	var point := centre
	point.x += cos(angle) * (radius.x * fold_scale + lobe)
	point.z += sin(angle) * (radius.y * fold_scale + lobe * 0.60)
	if ring_index == 0:
		point.y += hem_wave * (0.55 * sin(angle * 3.0 + 0.6) \
			+ 0.45 * sin(angle * 5.0 - 0.2))
	return point


## Closed-at-the-top, open-at-the-hem cloth shell. Sixteen sides are enough for
## a readable fall line while preserving small, light-reactive fabric facets.
static func _fabric_shell(parent: Node3D, node_name: String,
		ring_centres: PackedVector3Array, ring_radii: PackedVector2Array,
		color: Color, hem_wave: float, lobe_angle: float,
		lobe_strength: float) -> MeshInstance3D:
	var ring_count: int = mini(ring_centres.size(), ring_radii.size())
	if ring_count < 2:
		return _box(parent, node_name, Vector3.ZERO, Vector3(0.02, 0.02, 0.02), color)

	const SEGMENTS := 16
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring_index in range(ring_count - 1):
		for segment in range(SEGMENTS):
			var p00 := _fabric_point(ring_centres, ring_radii, ring_index,
				segment, SEGMENTS, hem_wave, lobe_angle, lobe_strength)
			var p01 := _fabric_point(ring_centres, ring_radii, ring_index + 1,
				segment, SEGMENTS, hem_wave, lobe_angle, lobe_strength)
			var p11 := _fabric_point(ring_centres, ring_radii, ring_index + 1,
				segment + 1, SEGMENTS, hem_wave, lobe_angle, lobe_strength)
			var p10 := _fabric_point(ring_centres, ring_radii, ring_index,
				segment + 1, SEGMENTS, hem_wave, lobe_angle, lobe_strength)
			surface.add_vertex(p00)
			surface.add_vertex(p01)
			surface.add_vertex(p11)
			surface.add_vertex(p00)
			surface.add_vertex(p11)
			surface.add_vertex(p10)

	var top_index: int = ring_count - 1
	var top_centre: Vector3 = ring_centres[top_index]
	for segment in range(SEGMENTS):
		var current := _fabric_point(ring_centres, ring_radii, top_index,
			segment, SEGMENTS, hem_wave, lobe_angle, lobe_strength)
		var next := _fabric_point(ring_centres, ring_radii, top_index,
			segment + 1, SEGMENTS, hem_wave, lobe_angle, lobe_strength)
		surface.add_vertex(top_centre)
		surface.add_vertex(next)
		surface.add_vertex(current)
	surface.generate_normals()
	var mesh: ArrayMesh = surface.commit()

	var min_point := _fabric_point(ring_centres, ring_radii, 0, 0,
		SEGMENTS, hem_wave, lobe_angle, lobe_strength)
	var max_point := min_point
	for ring_index in range(ring_count):
		for segment in range(SEGMENTS):
			var point := _fabric_point(ring_centres, ring_radii, ring_index,
				segment, SEGMENTS, hem_wave, lobe_angle, lobe_strength)
			min_point.x = minf(min_point.x, point.x)
			min_point.y = minf(min_point.y, point.y)
			min_point.z = minf(min_point.z, point.z)
			max_point.x = maxf(max_point.x, point.x)
			max_point.y = maxf(max_point.y, point.y)
			max_point.z = maxf(max_point.z, point.z)
	var extent: Vector3 = max_point - min_point + Vector3.ONE * 0.02
	return _primitive(parent, node_name, Vector3.ZERO, mesh, extent, color,
		0.0, 0.0, Vector3.ZERO, false)


static func _torus(parent: Node3D, node_name: String, torus_position: Vector3,
		inner_radius: float, outer_radius: float, color: Color,
		metallic := 0.0, tilt := Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 12
	mesh.ring_segments = 6
	return _primitive(parent, node_name, torus_position, mesh,
		Vector3(outer_radius * 2.0, outer_radius - inner_radius, outer_radius * 2.0),
		color, 0.0, metallic, tilt, false)


## Horizontal quad for paper on a floor and for painted floor markings. Two
## triangles, no collider: paper does not stop anybody.
static func _flat(parent: Node3D, node_name: String, flat_position: Vector3,
		size: Vector2, color: Color, yaw_degrees := 0.0) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	return _primitive(parent, node_name, flat_position, mesh,
		Vector3(size.x, 0.01, size.y), color, 0.0, 0.0,
		Vector3(0, yaw_degrees, 0), false)


## The fume hood sash. Its own material, not the cached opaque one, because
## transparency has to stay off the noise-textured path.
static func _glass(parent: Node3D, node_name: String, glass_position: Vector3,
		size: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _primitive(parent, node_name, glass_position, mesh, size,
		Color(0.52, 0.60, 0.58, 0.16), 0.0, 0.0, Vector3.ZERO, true)


## One walk-blocking volume, no mesh. Callers pass the bulk of the object rather
## than one of these per board -- see the COLLISION note in the class doc.
static func _collider(parent: Node3D, node_name: String, body_position: Vector3,
		size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = body_position
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "%s Shape" % node_name
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body


## Hand-written tag on an object. `text` is already translated by the caller;
## empty means the physical tag is built and no Label3D goes on it. Pale text
## over a hard black outline, so it stays legible against the dust sheet it hangs
## on and against the dark behind it.
static func _tag_label(parent: Node3D, text: String, label_position: Vector3,
		yaw_degrees: float) -> Label3D:
	var label := Label3D.new()
	label.name = "Tag Text"
	label.text = text
	label.position = label_position
	label.rotation_degrees = Vector3(0, yaw_degrees, 0)
	label.modulate = Color(0.94, 0.92, 0.86)
	label.font_size = 44
	# 44 px at 0.0016 m/px is a 7 cm cap height: a luggage tag, not signage.
	label.pixel_size = 0.0016
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = false
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.92)
	label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	label.visibility_range_end = 14.0
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(label)
	return label


## Палитра архива -> набор карт. Бумага, картон и листы — ровный цвет.
static func _pack_for(color: Color) -> String:
	if color.is_equal_approx(_STEEL_DARK) or color.is_equal_approx(_STEEL) \
			or color.is_equal_approx(_STEEL_LIT):
		return "steel"
	if color.is_equal_approx(_WOOD_DARK) or color.is_equal_approx(_WOOD):
		return "wood"
	if color.is_equal_approx(_BRASS):
		return "painted_metal"
	if color.is_equal_approx(_FOAM):
		return "plastic_worn"
	return ""


static func _material(color: Color, transparent: bool, emission_energy: float,
		metallic: float) -> StandardMaterial3D:
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
	mat.metallic_specular = 0.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_energy

	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Same restrained surface break-up FirstMuseumMap._material() gives the
	# walls, so a shelving carriage does not read as a different material system
	# from the room it stands in.
	if not transparent and emission_energy <= 0.0 and not MatLib.apply_flat_style(mat) and metallic < 0.35:
		mat.roughness_texture = _roughness_texture()
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		mat.normal_enabled = true
		mat.normal_texture = _bump_texture()
		mat.normal_scale = 0.08
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.22, 0.22, 0.22)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_materials[key] = mat
	return mat


static func _roughness_texture() -> NoiseTexture2D:
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


static func _bump_texture() -> NoiseTexture2D:
	if _bump_noise != null:
		return _bump_noise
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.12
	noise.fractal_octaves = 2
	_bump_noise = NoiseTexture2D.new()
	_bump_noise.width = 128
	_bump_noise.height = 128
	_bump_noise.noise = noise
	_bump_noise.seamless = true
	_bump_noise.as_normal_map = true
	_bump_noise.bump_strength = 1.2
	return _bump_noise


# ============================================================================
# ARCHIVE
# ============================================================================

# One shelving carriage of the compact rolling stacks. Travel is along the
# carriage's local X; the operating end with the handwheel faces local +Z.
const STACK_CARRIAGE_W := 0.94
const STACK_CARRIAGE_L := 3.0
const STACK_CARRIAGE_H := 2.2
## Carriage width plus 0.04 m of running clearance.
const STACK_PITCH := 0.98
## Clear width of the aisle opened between two carriages, before clearance. The
## player capsule is 0.7 m across and walks in comfortably; the Curator capsule
## is 0.76 m across and the navigation bake erodes 0.45 m per side, so 1.28 m of
## opening leaves it at most one 0.15 m cell of navmesh. Whether that cell
## survives the bake is deliberately left to chance -- the slot is a dead end,
## not a route, so losing it strands nobody and gains the player somewhere the
## Curator probably cannot follow.
const STACK_OPEN_GAP := 1.24

## Files run out at a different point on every level, so the aisle wall reads as
## a used archive rather than one row repeated four times.
const _SHELF_LEVELS := [0.44, 0.90, 1.36, 1.82]
const _SHELF_ROW_LENGTH := [2.42, 2.06, 2.64, 1.78]
const _SHELF_ROW_OFFSET := [0.18, -0.36, 0.06, 0.52]


## Compact rolling shelving: `bays` carriages on floor rails, pushed together
## except for one aisle opened immediately before carriage `open_before`. Pass
## an `open_before` outside 1..bays-1 for a fully closed block.
##
## Only the two carriages facing the open aisle carry shelves and files, because
## those are the only shelves anything can see -- the rest stand 0.04 m apart.
##
## Bounding box (bays 5, one aisle): 6.10 x 2.20 x 3.19 m.
## Bounding box (bays 3, closed):    2.90 x 2.20 x 3.19 m.
## Depth includes the handwheels standing 0.19 m proud of the end panels.
static func build_rolling_stacks(parent: Node3D, origin: Vector3,
		bays := 5, open_before := 3, yaw_degrees := 0.0) -> Node3D:
	var root := _mount(parent, "Archive Rolling Stacks", origin, yaw_degrees)
	var opens: bool = open_before > 0 and open_before < bays
	var run_width: float = (bays - 1) * STACK_PITCH + STACK_CARRIAGE_W
	if opens:
		run_width += STACK_OPEN_GAP

	for rail_z in [-1.22, 1.22]:
		_box(root, "Stack Rail %s" % [rail_z], Vector3(0, 0.025, rail_z),
			Vector3(run_width, 0.05, 0.09), _STEEL_DARK, 0.0, 0.45)

	var x: float = -run_width * 0.5 + STACK_CARRIAGE_W * 0.5
	for i in range(bays):
		if i == open_before:
			x += STACK_OPEN_GAP
		_stack_carriage(root, i, x, bays, open_before if opens else -1)
		x += STACK_PITCH
	return root


static func _stack_carriage(root: Node3D, index: int, x: float, bays: int,
		open_before: int) -> void:
	_box(root, "Carriage %d Plinth" % index, Vector3(x, 0.06, 0),
		Vector3(STACK_CARRIAGE_W, 0.12, STACK_CARRIAGE_L), _STEEL_DARK)
	for end_z in [-1.48, 1.48]:
		var face_z: float = end_z + signf(end_z) * 0.025
		_box(root, "Carriage %d End Panel" % index, Vector3(x, 1.13, end_z),
			Vector3(STACK_CARRIAGE_W, 2.02, 0.04), _STACK_FACE)
		# Raised perimeter and two seams keep the operating ends legible even when
		# the room is running only on spill light.
		for edge_x in [-0.40, 0.40]:
			_box(root, "Carriage %d End Upright %s" % [index, edge_x],
				Vector3(x + edge_x, 1.13, face_z),
				Vector3(0.045, 1.88, 0.025), _STACK_TRIM, 0.0, 0.35)
		for edge_y in [0.22, 2.04]:
			_box(root, "Carriage %d End Rail %s" % [index, edge_y],
				Vector3(x, edge_y, face_z),
				Vector3(0.82, 0.045, 0.025), _STACK_TRIM, 0.0, 0.35)
		for seam_y in [0.76, 1.30]:
			_box(root, "Carriage %d End Seam %s" % [index, seam_y],
				Vector3(x, seam_y, face_z + signf(end_z) * 0.004),
				Vector3(0.74, 0.018, 0.018), _STEEL_DARK)
	_box(root, "Carriage %d Top Cap" % index, Vector3(x, 2.17, 0),
		Vector3(STACK_CARRIAGE_W, 0.06, STACK_CARRIAGE_L), _STEEL_DARK)
	# A wheel riding the front rail makes each carriage read as machinery rather
	# than as a solid cabinet. It is visual only; the carriage collider stays one
	# clean box for navigation.
	_cylinder(root, "Carriage %d Drive Wheel" % index, Vector3(x, 0.13, 1.28),
		0.12, 0.075, _STACK_TRIM, 0.0, 0.55, Vector3(90, 0, 0))
	_cylinder(root, "Carriage %d Drive Axle" % index, Vector3(x, 0.13, 1.33),
		0.035, 0.10, _STEEL_DARK, 0.0, 0.55, Vector3(90, 0, 0))
	# Operating handwheel, on the aisle end where a hand would reach it.
	_torus(root, "Carriage %d Handwheel" % index, Vector3(x, 1.15, 1.54),
		0.11, 0.19, _STACK_TRIM, 0.55, Vector3(90, 0, 0))
	_cylinder(root, "Carriage %d Hub" % index, Vector3(x, 1.15, 1.54),
		0.032, 0.085, _STACK_TRIM, 0.0, 0.55, Vector3(90, 0, 0))
	_cylinder(root, "Carriage %d Handwheel Grip" % index,
		Vector3(x + 0.15, 1.15, 1.585), 0.022, 0.075, _STACK_LABEL,
		0.0, 0.2, Vector3(90, 0, 0))
	# The index card is missing off one carriage. Nobody wrote down what went
	# back into it.
	if index != 1:
		_box(root, "Carriage %d Index Holder" % index, Vector3(x, 1.66, 1.525),
			Vector3(0.31, 0.135, 0.018), _STACK_TRIM, 0.0, 0.35)
		_box(root, "Carriage %d Index Card" % index, Vector3(x, 1.66, 1.538),
			Vector3(0.255, 0.085, 0.010), _STACK_LABEL)

	# The outer faces of the block are seen from the room and have to be skinned.
	if index == 0 or index == bays - 1:
		var side: float = -1.0 if index == 0 else 1.0
		var skin_x: float = x + side * 0.47
		var detail_x: float = skin_x + side * 0.025
		_box(root, "Carriage %d Outer Skin" % index, Vector3(skin_x, 1.13, 0),
			Vector3(0.03, 2.02, 2.94), _STACK_FACE)
		for frame_z in [-1.38, 1.38]:
			_box(root, "Carriage %d Outer Frame Upright %s" % [index, frame_z],
				Vector3(detail_x, 1.13, frame_z),
				Vector3(0.035, 1.90, 0.055), _STACK_TRIM, 0.0, 0.35)
		_box(root, "Carriage %d Outer Frame Top" % index,
			Vector3(detail_x, 2.05, 0),
			Vector3(0.035, 0.055, 2.82), _STACK_TRIM, 0.0, 0.35)
		_box(root, "Carriage %d Outer Frame Bottom" % index,
			Vector3(detail_x, 0.21, 0),
			Vector3(0.035, 0.055, 2.82), _STACK_TRIM, 0.0, 0.35)
		for panel_y in [0.68, 1.15, 1.62]:
			_box(root, "Carriage %d Outer Panel Seam %s" % [index, panel_y],
				Vector3(detail_x + side * 0.004, panel_y, 0),
				Vector3(0.025, 0.022, 2.68), _STEEL_DARK)

	# Shelves and files only where the open aisle exposes them.
	var side := 0.0
	if index == open_before - 1:
		side = 1.0
	elif index == open_before:
		side = -1.0
	if side != 0.0:
		_stack_shelves(root, index, x, side)

	_collider(root, "Carriage %d Body" % index, Vector3(x, 1.1, 0),
		Vector3(STACK_CARRIAGE_W, STACK_CARRIAGE_H, STACK_CARRIAGE_L))


static func _stack_shelves(root: Node3D, index: int, x: float, side: float) -> void:
	var face_x: float = x + side * 0.245
	_box(root, "Carriage %d Spine" % index, Vector3(x, 1.13, 0),
		Vector3(0.06, 2.02, 2.92), _STEEL)
	for level in range(_SHELF_LEVELS.size()):
		var y: float = _SHELF_LEVELS[level]
		_box(root, "Carriage %d Shelf %d" % [index, level],
			Vector3(face_x, y, 0), Vector3(0.42, 0.035, 2.90), _STEEL)
		_box(root, "Carriage %d File Row %d" % [index, level],
			Vector3(face_x, y + 0.1675, _SHELF_ROW_OFFSET[level]),
			Vector3(0.34, 0.30, _SHELF_ROW_LENGTH[level]), _BOARD)
	# The top shelf of the left-hand carriage is bare except for this. It is not
	# labelled, it is not a box file, and it is the only black thing in the run.
	if side > 0.0:
		_box(root, "Unlabelled Object", Vector3(face_x, 2.0075, -1.15),
			Vector3(0.18, 0.34, 0.16), _VOID)


## Card catalogue: a bank of small drawers, one pulled right out and its cards
## on the floor. `open_drawer` indexes row-major from the bottom left; pass a
## negative value to leave every drawer shut.
##
## Bounding box: 1.51 x 1.32 x 0.99 m. The cabinet alone is 1.51 x 1.32 x 0.58;
## the pulled drawer and the spilled cards account for the rest of the depth.
static func build_card_catalogue(parent: Node3D, origin: Vector3,
		yaw_degrees := 0.0, columns := 4, rows := 4, open_drawer := 6) -> Node3D:
	var root := _mount(parent, "Archive Card Catalogue", origin, yaw_degrees)
	var carcass_w: float = columns * 0.345 + 0.05
	var carcass_h: float = rows * 0.28 + 0.04

	_box(root, "Catalogue Plinth", Vector3(0, 0.05, 0),
		Vector3(carcass_w - 0.10, 0.10, 0.44), _WOOD_DARK)
	_box(root, "Catalogue Carcass", Vector3(0, 0.10 + carcass_h * 0.5, 0),
		Vector3(carcass_w, carcass_h, 0.52), _WOOD_DARK)
	_box(root, "Catalogue Top", Vector3(0, 0.13 + carcass_h, 0),
		Vector3(carcass_w + 0.08, 0.06, 0.58), _WOOD)

	for r in range(rows):
		for c in range(columns):
			var index: int = r * columns + c
			var col_x: float = (c - (columns - 1) * 0.5) * 0.345
			var row_y: float = 0.245 + 0.28 * r
			var front_z := 0.262
			if index == open_drawer:
				front_z = 0.682
				_box(root, "Catalogue Drawer Body",
					Vector3(col_x, row_y - 0.01, 0.44),
					Vector3(0.30, 0.20, 0.44), _WOOD_DARK)
				_box(root, "Catalogue Drawer Cards",
					Vector3(col_x, row_y - 0.02, 0.44),
					Vector3(0.26, 0.15, 0.40), _CARD)
			_box(root, "Catalogue Drawer Front %d" % index,
				Vector3(col_x, row_y, front_z),
				Vector3(0.32, 0.25, 0.018), _WOOD)
			_box(root, "Catalogue Index Slip %d" % index,
				Vector3(col_x, row_y - 0.005, front_z + 0.011),
				Vector3(0.115, 0.042, 0.010), _CARD)

	# Somebody went through the drawer on the floor and did not put it back.
	for i in range(_CARD_SPILL.size()):
		_flat(root, "Catalogue Loose Card %d" % i,
			_CARD_SPILL[i] + Vector3(0, 0.011, 0), Vector2(0.085, 0.06),
			_PAPER, _CARD_SPILL_YAW[i])

	_collider(root, "Catalogue Body", Vector3(0, (0.13 + carcass_h) * 0.5, 0),
		Vector3(carcass_w, 0.16 + carcass_h, 0.52))
	return root


const _CARD_SPILL := [
	Vector3(0.12, 0, 0.86), Vector3(-0.24, 0, 0.74), Vector3(0.38, 0, 0.62),
	Vector3(-0.05, 0, 1.02), Vector3(0.52, 0, 0.94), Vector3(-0.41, 0, 0.98),
	Vector3(0.20, 0, 1.14),
]
const _CARD_SPILL_YAW := [14.0, -37.0, 62.0, -8.0, 41.0, -71.0, 25.0]


## Reading desk with a shaded lamp, an open ledger and a chair shoved back at an
## angle. `lamp_lit` adds a small OmniLight3D in the group LIGHT_GROUP; it never
## flickers, so nothing here has to answer to reduced_flashes.
##
## Bounding box: 1.70 x 1.19 x 1.62 m. The desk alone is 1.70 x 1.19 x 0.82; the
## chair standing off the back edge accounts for the rest of the depth.
static func build_reading_desk(parent: Node3D, origin: Vector3,
		yaw_degrees := 0.0, lamp_lit := true) -> Node3D:
	var root := _mount(parent, "Archive Reading Desk", origin, yaw_degrees)
	_box(root, "Desk Top", Vector3(0, 0.75, 0), Vector3(1.70, 0.06, 0.82), _WOOD)
	for leg in [Vector3(-0.78, 0.36, -0.34), Vector3(0.78, 0.36, -0.34),
			Vector3(-0.78, 0.36, 0.34), Vector3(0.78, 0.36, 0.34)]:
		_box(root, "Desk Leg %s" % [leg], leg, Vector3(0.07, 0.72, 0.07), _WOOD_DARK)
	_box(root, "Desk Modesty Panel", Vector3(0, 0.55, -0.38),
		Vector3(1.56, 0.34, 0.03), _WOOD_DARK)
	_box(root, "Desk Drawer", Vector3(-0.34, 0.65, 0.06),
		Vector3(0.62, 0.13, 0.72), _WOOD_DARK)

	# Shaded reading lamp. The shade is opaque and the pool it throws is small:
	# the desk is the only lit thing and the shelving behind it is not.
	_cylinder(root, "Lamp Base", Vector3(0.58, 0.795, -0.18), 0.09, 0.03, _BRASS,
		0.0, 0.55)
	_cylinder(root, "Lamp Stem", Vector3(0.58, 0.95, -0.18), 0.018, 0.30, _BRASS,
		0.0, 0.55)
	_cone(root, "Lamp Shade", Vector3(0.58, 1.14, -0.18), 0.05, 0.14, 0.10,
		Color(0.055, 0.150, 0.105))
	_cylinder(root, "Lamp Lens", Vector3(0.58, 1.085, -0.18), 0.10, 0.012,
		_LAMP_WARM, 2.0)
	if lamp_lit:
		var light := OmniLight3D.new()
		light.name = "Desk Lamp Light"
		light.position = Vector3(0.58, 1.03, -0.18)
		light.light_color = Color(1.0, 0.86, 0.62)
		light.light_energy = 0.9
		light.omni_range = 3.6
		light.shadow_enabled = false
		light.add_to_group(LIGHT_GROUP)
		root.add_child(light)

	_box(root, "Ledger Page Left", Vector3(-0.16, 0.795, 0.04),
		Vector3(0.28, 0.015, 0.40), _PAPER, 0.0, 0.0, Vector3(0, 4, 0))
	_box(root, "Ledger Page Right", Vector3(0.14, 0.795, 0.04),
		Vector3(0.28, 0.015, 0.40), _CARD, 0.0, 0.0, Vector3(0, -4, 0))
	_cylinder(root, "Pen", Vector3(-0.02, 0.792, 0.30), 0.008, 0.16, _STEEL_DARK,
		0.0, 0.3, Vector3(0, 0, 90))

	var chair := _mount(root, "Reading Chair", Vector3(-0.12, 0, 0.78), 24.0)
	_box(chair, "Chair Seat", Vector3(0, 0.45, 0), Vector3(0.46, 0.06, 0.46), _WOOD)
	_box(chair, "Chair Back", Vector3(0, 0.74, -0.21),
		Vector3(0.44, 0.52, 0.05), _WOOD)
	for leg in [Vector3(-0.19, 0.22, -0.19), Vector3(0.19, 0.22, -0.19),
			Vector3(-0.19, 0.22, 0.19), Vector3(0.19, 0.22, 0.19)]:
		_box(chair, "Chair Leg %s" % [leg], leg, Vector3(0.05, 0.44, 0.05), _WOOD_DARK)
	_collider(chair, "Chair Body", Vector3(0, 0.50, -0.06),
		Vector3(0.46, 1.00, 0.52))

	_collider(root, "Desk Body", Vector3(0, 0.39, 0), Vector3(1.70, 0.78, 0.82))
	return root


## Stack of archive box files, each with a written label on the front. The
## stacking is deliberately imperfect and the top box of a tall stack leans.
##
## Bounding box: 0.52 x (count * 0.31) x 0.44 m. A stack of five is 1.55 m tall.
static func build_box_file_stack(parent: Node3D, origin: Vector3,
		count := 4, yaw_degrees := 0.0) -> Node3D:
	var root := _mount(parent, "Archive Box Files", origin, yaw_degrees)
	for i in range(count):
		var slot: int = i % _BOX_NUDGE_X.size()
		var yaw: float = _BOX_NUDGE_YAW[slot]
		var tilt := Vector3(0, yaw, 0)
		if i == count - 1 and count >= 3:
			# The top one was put back in a hurry.
			tilt = Vector3(0, yaw, 6)
		var at := Vector3(_BOX_NUDGE_X[slot], 0.155 + i * 0.31, 0.0)
		_box(root, "Box File %d" % i, at, Vector3(0.42, 0.30, 0.34), _BOARD,
			0.0, 0.0, tilt)
		_box(root, "Box File Label %d" % i, at + Vector3(0, 0.02, 0.176),
			Vector3(0.20, 0.10, 0.008), _CARD, 0.0, 0.0, tilt)
	_collider(root, "Box File Stack Body", Vector3(0, count * 0.155, 0),
		Vector3(0.50, count * 0.31, 0.42))
	return root


const _BOX_NUDGE_X := [0.0, 0.04, -0.03, 0.05, -0.02]
const _BOX_NUDGE_YAW := [-6.0, 4.0, -2.0, 7.0, -5.0]


# ============================================================================
# RESTORATION LAB
# ============================================================================


## Work bench: scarred top, steel frame, lower shelf, and a bench vice at the
## right-hand end. `with_pegboard` raises a tool board off the back edge -- give
## it to the bench against a wall and leave it off the one in the open, or the
## room turns into a hardware shop.
##
## Two of the pegboard's hooks are empty and the paint behind them still carries
## the outline of what used to hang there.
##
## Bounding box: 2.40 x 2.08 x 0.90 m with the pegboard, 2.40 x 0.96 x 0.90
## without it. Working surface at 0.955 m -- put tool trays at that height.
static func build_work_bench(parent: Node3D, origin: Vector3,
		yaw_degrees := 0.0, with_pegboard := true) -> Node3D:
	var root := _mount(parent, "Lab Work Bench", origin, yaw_degrees)
	_box(root, "Bench Top", Vector3(0, 0.92, 0), Vector3(2.40, 0.07, 0.86),
		Color(0.205, 0.160, 0.115))
	for leg in [Vector3(-1.12, 0.44, -0.35), Vector3(1.12, 0.44, -0.35),
			Vector3(-1.12, 0.44, 0.35), Vector3(1.12, 0.44, 0.35)]:
		_box(root, "Bench Leg %s" % [leg], leg, Vector3(0.06, 0.88, 0.06), _STEEL_DARK)
	_box(root, "Bench Lower Shelf", Vector3(0, 0.28, 0),
		Vector3(2.26, 0.04, 0.72), _STEEL_DARK)
	_box(root, "Bench Skirt Rail", Vector3(0, 0.84, -0.41),
		Vector3(2.30, 0.08, 0.04), _STEEL_DARK)

	_box(root, "Bench Vice Body", Vector3(1.02, 1.03, 0.30),
		Vector3(0.18, 0.14, 0.22), _STEEL, 0.0, 0.5)
	_box(root, "Bench Vice Jaw", Vector3(1.02, 1.02, 0.42),
		Vector3(0.20, 0.10, 0.05), _STEEL_LIT, 0.0, 0.6)
	_cylinder(root, "Bench Vice Handle", Vector3(1.02, 1.06, 0.16), 0.012, 0.26,
		_STEEL_LIT, 0.0, 0.6, Vector3(0, 0, 90))

	if with_pegboard:
		_box(root, "Pegboard", Vector3(0, 1.55, -0.44),
			Vector3(2.30, 1.05, 0.03), Color(0.165, 0.140, 0.115))
		_box(root, "Pegboard Wrench", Vector3(-0.85, 1.75, -0.415),
			Vector3(0.05, 0.30, 0.02), _STEEL, 0.0, 0.55, Vector3(0, 0, 6))
		_box(root, "Pegboard Spanner", Vector3(-0.72, 1.72, -0.415),
			Vector3(0.05, 0.24, 0.02), _STEEL, 0.0, 0.55, Vector3(0, 0, -4))
		_cylinder(root, "Pegboard Mallet", Vector3(-0.40, 1.70, -0.415),
			0.022, 0.28, _WOOD_DARK)
		_prism(root, "Pegboard Chisel", Vector3(0.10, 1.72, -0.415),
			Vector3(0.05, 0.22, 0.02), _STEEL_LIT, Vector3(0, 0, 180))
		_box(root, "Pegboard Saw", Vector3(0.62, 1.80, -0.415),
			Vector3(0.34, 0.12, 0.02), _STEEL, 0.0, 0.5, Vector3(0, 0, -8))
		_torus(root, "Pegboard Coil", Vector3(1.00, 1.62, -0.40), 0.06, 0.11,
			_STEEL_DARK, 0.3, Vector3(90, 0, 0))
		# Painted outlines with nothing hanging on them. The board was drawn
		# round every tool so a missing one would be obvious. Two are missing.
		for empty in [Vector3(-0.10, 1.68, -0.421), Vector3(0.36, 1.60, -0.421)]:
			_box(root, "Pegboard Empty Hook", empty,
				Vector3(0.09, 0.24, 0.006), Color(0.235, 0.215, 0.185))

	_collider(root, "Bench Body", Vector3(0, 0.478, 0),
		Vector3(2.40, 0.955, 0.86))
	return root


## Shallow instrument tray for a bench top. `variant` swaps the contents:
## 0 is edged tools, anything else is jars and swabs. No collider -- it is 9 cm
## tall and it sits on something that already has one.
##
## Bounding box: 0.46 x 0.09 x 0.30 m. Place its origin on the bench surface.
static func build_tool_tray(parent: Node3D, origin: Vector3,
		yaw_degrees := 0.0, variant := 0) -> Node3D:
	var root := _mount(parent, "Lab Tool Tray", origin, yaw_degrees)
	_box(root, "Tray Floor", Vector3(0, 0.008, 0), Vector3(0.46, 0.016, 0.30),
		_STEEL, 0.0, 0.5)
	for rim_z in [-0.143, 0.143]:
		_box(root, "Tray Rim Z %s" % [rim_z], Vector3(0, 0.036, rim_z),
			Vector3(0.46, 0.055, 0.014), _STEEL, 0.0, 0.5)
	for rim_x in [-0.223, 0.223]:
		_box(root, "Tray Rim X %s" % [rim_x], Vector3(rim_x, 0.036, 0),
			Vector3(0.014, 0.055, 0.30), _STEEL, 0.0, 0.5)

	if variant == 0:
		_box(root, "Scalpel", Vector3(-0.10, 0.024, 0.06),
			Vector3(0.16, 0.012, 0.014), _STEEL_LIT, 0.0, 0.7, Vector3(0, 12, 0))
		_box(root, "Tweezers", Vector3(0.06, 0.024, -0.04),
			Vector3(0.13, 0.010, 0.020), _STEEL_LIT, 0.0, 0.7, Vector3(0, -22, 0))
		_cylinder(root, "Brush", Vector3(0.10, 0.026, 0.08), 0.008, 0.17,
			_WOOD_DARK, 0.0, 0.0, Vector3(0, 20, 90))
	else:
		for i in range(3):
			_cylinder(root, "Solvent Jar %d" % i,
				Vector3(-0.14 + i * 0.13, 0.043, -0.02 + i * 0.03), 0.032, 0.07,
				Color(0.180, 0.195, 0.175))

	return root


## Fume hood: base cabinet, black-lined enclosure, a sash left half open and a
## duct that runs to the ceiling. The strip light inside is the sickliest thing
## in either room and it is the only light in the enclosure.
##
## Bounding box: 1.66 x 3.35 x 0.86 m. The duct tops out at 3.35, clearing the
## 3.39 m ceiling soffit by 4 cm -- this is the tallest prop in the file, so
## check the ceiling before moving it into a room that is not 3.4 m.
static func build_fume_hood(parent: Node3D, origin: Vector3,
		yaw_degrees := 0.0) -> Node3D:
	var root := _mount(parent, "Lab Fume Hood", origin, yaw_degrees)
	_box(root, "Hood Base Cabinet", Vector3(0, 0.43, 0),
		Vector3(1.60, 0.86, 0.78), _STEEL_DARK)
	for door_x in [-0.39, 0.39]:
		_box(root, "Hood Cabinet Door", Vector3(door_x, 0.45, 0.40),
			Vector3(0.74, 0.72, 0.02), _STEEL)
	_box(root, "Hood Cabinet Handle", Vector3(0, 0.45, 0.42),
		Vector3(0.60, 0.02, 0.03), _STEEL_LIT, 0.0, 0.6)
	_box(root, "Hood Work Surface", Vector3(0, 0.885, 0),
		Vector3(1.66, 0.05, 0.84), Color(0.105, 0.115, 0.115))
	# The back of the enclosure is painted out, so the hood reads as a hole in
	# the wall rather than as a cupboard.
	_box(root, "Hood Rear Lining", Vector3(0, 1.52, -0.39),
		Vector3(1.60, 1.20, 0.04), _VOID)
	for side_x in [-0.78, 0.78]:
		_box(root, "Hood Side", Vector3(side_x, 1.52, 0),
			Vector3(0.05, 1.20, 0.80), _STEEL)
	_box(root, "Hood Canopy", Vector3(0, 2.15, 0),
		Vector3(1.66, 0.06, 0.84), _STEEL_DARK)
	_glass(root, "Hood Sash", Vector3(0, 1.80, 0.38), Vector3(1.52, 0.62, 0.02))
	_box(root, "Hood Sash Frame", Vector3(0, 1.47, 0.38),
		Vector3(1.56, 0.05, 0.045), _STEEL_LIT, 0.0, 0.6)
	_box(root, "Hood Strip Light", Vector3(0, 2.08, 0),
		Vector3(1.30, 0.05, 0.10), Color(0.620, 0.660, 0.580), 0.9)
	_box(root, "Hood Duct Elbow", Vector3(0, 2.29, -0.10),
		Vector3(0.36, 0.22, 0.36), _STEEL)
	# Stops 4 cm short of the ceiling slab rather than at a hard-coded height,
	# so the one prop in this file tall enough to hit a ceiling cannot.
	var duct_bottom := 2.35
	var duct_height: float = SOFFIT_Y - 0.04 - duct_bottom
	_cylinder(root, "Hood Duct",
		Vector3(0, duct_bottom + duct_height * 0.5, -0.10), 0.16, duct_height,
		_STEEL, 0.0, 0.35)
	_box(root, "Hood Tray", Vector3(0.30, 0.92, -0.10),
		Vector3(0.40, 0.03, 0.26), _STEEL, 0.0, 0.5)
	_box(root, "Hood Contents", Vector3(-0.25, 0.95, -0.12),
		Vector3(0.14, 0.10, 0.12), _VOID)

	_collider(root, "Hood Body", Vector3(0, 1.09, 0), Vector3(1.66, 2.18, 0.86))
	return root


## Exhibit 9: a shape on a dolly under a dust sheet.
##
## It is 2.49 m tall on a 0.35 m deck, which is roughly a third again the height
## of a person, and the sheet is the palest thing in the room. It has shoulders,
## a head set slightly wrong on the neck, and one arm out under the cloth. The
## hem stops 0.27 m above the deck, and in that gap there is one support where
## there should be two. A corner of the sheet has been lifted and dropped back;
## behind the fold there is no highlight at all.
##
## `tag_text` is already translated by the caller. Empty builds the tag card and
## leaves it blank, which still reads as a tagged object in restoration.
##
## Bounding box: 1.72 x 2.49 x 1.06 m. The collider is 1.60 x 2.49 x 1.06 -- the
## arm under the cloth is not solid, so a player can brush through it.
static func build_shrouded_exhibit(parent: Node3D, origin: Vector3,
		yaw_degrees := 0.0, tag_text := "") -> Node3D:
	var root := _mount(parent, "Exhibit 9 Under Sheet", origin, yaw_degrees)
	_box(root, "Dolly Deck", Vector3(0, 0.30, 0), Vector3(1.42, 0.10, 1.06),
		_STEEL_DARK)
	for castor in [Vector3(-0.58, 0.11, -0.42), Vector3(0.58, 0.11, -0.42),
			Vector3(-0.58, 0.11, 0.42), Vector3(0.58, 0.11, 0.42)]:
		_cylinder(root, "Dolly Castor %s" % [castor], castor, 0.09, 0.06, _STEEL_DARK, 0.0,
			0.4, Vector3(0, 0, 90))
	# One support, off-centre, in a gap wide enough to show two.
	_cylinder(root, "Support", Vector3(0.16, 0.50, 0.0), 0.15, 0.30, _VOID)

	# One continuous irregular shell replaces the old stack of cones, shoulder
	# prism and four rectangular wall panels. Its rings overlap the hidden form,
	# widen into an uneven hem, and bulge once where an arm presses from below.
	var sheet_centres := PackedVector3Array([
		Vector3(0.00, 0.45, 0.00),
		Vector3(-0.01, 0.96, 0.00),
		Vector3(-0.04, 1.57, -0.01),
		Vector3(-0.08, 1.82, 0.01),
		Vector3(-0.04, 1.96, 0.00),
		Vector3(0.01, 2.08, -0.01),
		Vector3(0.06, 2.18, -0.03),
		Vector3(0.11, 2.27, -0.045),
		Vector3(0.14, 2.34, -0.055),
		Vector3(0.16, 2.38, -0.060),
		Vector3(0.16, 2.395, -0.060),
	])
	var sheet_radii := PackedVector2Array([
		Vector2(0.73, 0.55),
		Vector2(0.65, 0.50),
		Vector2(0.50, 0.42),
		Vector2(0.63, 0.43),
		Vector2(0.58, 0.40),
		Vector2(0.47, 0.35),
		Vector2(0.35, 0.29),
		Vector2(0.23, 0.21),
		Vector2(0.13, 0.12),
		Vector2(0.055, 0.050),
		Vector2(0.012, 0.011),
	])
	_fabric_shell(root, "Sheet Front Drape", sheet_centres, sheet_radii,
		_SHEET, 0.075, 0.25, 0.26)
	for part_name in ["Sheet Skirt Mass", "Sheet Torso", "Sheet Shoulders",
			"Sheet Neck", "Sheet Back Drape", "Sheet Left Drape",
			"Sheet Right Drape", "Sheet Arm"]:
		_marker(root, part_name)
	# The crown is part of the shell profile above; keep a semantic marker for
	# audits without layering a second mesh that reads as a ball or hat.
	_marker(root, "Sheet Crown")

	# Narrow, shallow strips catch light as folds without becoming separate walls.
	_prism(root, "Sheet Front Fold Left", Vector3(-0.28, 1.02, 0.52),
		Vector3(0.055, 0.72, 0.045), _SHEET_FOLD, Vector3(3, 0, -5))
	_prism(root, "Sheet Front Fold Right", Vector3(0.23, 0.98, 0.51),
		Vector3(0.045, 0.64, 0.040), _SHEET_FOLD, Vector3(-2, 0, 7))
	_prism(root, "Sheet Rear Fold", Vector3(0.18, 1.03, -0.49),
		Vector3(0.050, 0.68, 0.040), _SHEET_FOLD, Vector3(2, 0, -5))
	# Somebody lifted this corner and put it back. The small dark gap is visible,
	# but the flap no longer reads as a large triangular armour plate.
	_prism(root, "Sheet Lifted Corner", Vector3(-0.49, 0.57, -0.43),
		Vector3(0.16, 0.20, 0.045), _SHEET_FOLD, Vector3(0, 0, 156))
	_box(root, "Under The Sheet", Vector3(-0.49, 0.55, -0.39),
		Vector3(0.13, 0.13, 0.06), _VOID)

	for strap_z in [-0.49, 0.49]:
		_box(root, "Restraint Strap", Vector3(0, 1.30, strap_z),
			Vector3(1.30, 0.05, 0.04), _STEEL_DARK)

	_cylinder(root, "Tag Wire", Vector3(0.10, 1.44, 0.50), 0.006, 0.16, _STEEL_LIT)
	_box(root, "Tag Card", Vector3(0.10, 1.33, 0.50),
		Vector3(0.17, 0.11, 0.008), _CARD)
	if tag_text != "":
		_tag_label(root, tag_text, Vector3(0.10, 1.33, 0.507), 0.0)

	_collider(root, "Exhibit 9 Body", Vector3(0, 1.245, 0),
		Vector3(1.60, 2.49, 1.06))
	return root


## Packing crate, opened and emptied. The lid leans against the front, the
## packing wool is spilling over the rim, and the foam inside still holds the
## shape of what came out of it.
##
## `stencil_text` is already translated by the caller; empty leaves the painted
## panel blank.
##
## Bounding box: 1.75 x 1.10 x 1.70 m. The crate alone is 1.46 x 0.98 x 1.10;
## the leaning lid and the crowbar on the floor account for the rest.
static func build_open_crate(parent: Node3D, origin: Vector3,
		yaw_degrees := 0.0, stencil_text := "") -> Node3D:
	var root := _mount(parent, "Lab Exhibit Crate", origin, yaw_degrees)
	_box(root, "Crate Floor", Vector3(0, 0.03, 0), Vector3(1.46, 0.06, 1.10), _WOOD)
	for wall_z in [-0.525, 0.525]:
		_box(root, "Crate Wall Z %s" % [wall_z], Vector3(0, 0.52, wall_z),
			Vector3(1.46, 0.92, 0.05), _WOOD)
	for wall_x in [-0.705, 0.705]:
		_box(root, "Crate Wall X %s" % [wall_x], Vector3(wall_x, 0.52, 0),
			Vector3(0.05, 0.92, 1.00), _WOOD)
	for bx in [-0.71, 0.71]:
		for bz in [-0.53, 0.53]:
			_box(root, "Crate Corner Batten %s" % [Vector2(bx, bz)], Vector3(bx, 0.49, bz),
				Vector3(0.08, 0.98, 0.08), _WOOD_DARK)
	for band_y in [0.30, 0.76]:
		_box(root, "Crate Band", Vector3(0, band_y, 0.545),
			Vector3(1.48, 0.09, 0.06), _WOOD_DARK)

	# Foam packed round a void. The cut-out has shoulders and a waist, and
	# nothing is in it.
	_box(root, "Crate Foam Rear", Vector3(0, 0.58, -0.34),
		Vector3(1.32, 0.52, 0.22), _FOAM)
	_box(root, "Crate Foam Front", Vector3(0, 0.58, 0.34),
		Vector3(1.32, 0.52, 0.22), _FOAM)
	for foam_x in [-0.50, 0.50]:
		_box(root, "Crate Foam Side", Vector3(foam_x, 0.58, 0),
			Vector3(0.30, 0.52, 0.50), _FOAM)
	for waist_x in [-0.28, 0.28]:
		_box(root, "Crate Foam Waist", Vector3(waist_x, 0.58, 0),
			Vector3(0.16, 0.52, 0.16), _FOAM)
	_box(root, "Crate Cavity Floor", Vector3(0, 0.33, 0),
		Vector3(0.72, 0.02, 0.48), _VOID)

	for i in range(3):
		_prism(root, "Crate Packing Wool %d" % i,
			Vector3(-0.42 + i * 0.44, 0.98, 0.50), Vector3(0.11, 0.26, 0.09),
			Color(0.400, 0.345, 0.230), Vector3(-24 + i * 9, i * 31, 12.0 * i - 12.0))

	var lid := _mount(root, "Crate Lid", Vector3(0.10, 0.55, 0.86), 0.0)
	lid.rotation_degrees = Vector3(-28, 0, 0)
	_box(lid, "Lid Panel", Vector3.ZERO, Vector3(1.46, 1.10, 0.05), _WOOD)
	for batten_y in [-0.38, 0.38]:
		_box(lid, "Lid Batten", Vector3(0, batten_y, 0.05),
			Vector3(1.50, 0.09, 0.05), _WOOD_DARK)

	_box(root, "Crowbar", Vector3(0.62, 0.018, 0.80),
		Vector3(0.92, 0.03, 0.035), _STEEL, 0.0, 0.6, Vector3(0, 34, 0))
	_box(root, "Crowbar Hook", Vector3(0.99, 0.020, 0.55),
		Vector3(0.10, 0.03, 0.09), _STEEL, 0.0, 0.6, Vector3(0, 34, 0))

	_box(root, "Crate Stencil Panel", Vector3(0, 0.64, 0.556),
		Vector3(0.58, 0.15, 0.012), Color(0.500, 0.460, 0.340))
	if stencil_text != "":
		_tag_label(root, stencil_text, Vector3(0, 0.64, 0.564), 0.0)

	_collider(root, "Crate Body", Vector3(0, 0.49, 0), Vector3(1.46, 0.98, 1.10))
	_collider(root, "Crate Lid Body", Vector3(0.10, 0.52, 0.90),
		Vector3(1.46, 1.04, 0.44))
	return root


## A smaller thing under its own dust sheet, for filling the corners of the lab.
## One rounded, asymmetric shell now carries the full silhouette; there are no
## flat side walls or lid-like top left to make it resemble a chair or lampshade.
##
## Bounding box: 0.92 x (height * 1.04) x 0.86 m.
static func build_shrouded_lump(parent: Node3D, origin: Vector3,
		yaw_degrees := 0.0, height := 1.10) -> Node3D:
	var root := _mount(parent, "Lab Covered Object", origin, yaw_degrees)
	var cover_centres := PackedVector3Array([
		Vector3(0.00, height * 0.07, 0.00),
		Vector3(-0.02, height * 0.40, 0.01),
		Vector3(0.01, height * 0.68, -0.02),
		Vector3(0.05, height * 0.88, -0.03),
		Vector3(0.06, height * 1.02, -0.04),
	])
	var cover_radii := PackedVector2Array([
		Vector2(0.46, 0.42),
		Vector2(0.44, 0.39),
		Vector2(0.35, 0.31),
		Vector2(0.23, 0.21),
		Vector2(0.09, 0.08),
	])
	_fabric_shell(root, "Cover Front Drape", cover_centres, cover_radii,
		_SHEET, height * 0.055, -1.15, 0.10)
	for part_name in ["Cover Lower Mass", "Cover Upper Mass", "Cover Back Drape",
			"Cover Side Left", "Cover Side Right"]:
		_marker(root, part_name)
	_ellipsoid(root, "Cover Crown", Vector3(0.05, height * 0.92, -0.03),
		Vector3(0.27, height * 0.24, 0.25), _SHEET, Vector3(0, 12, -4))
	_prism(root, "Cover Front Fold", Vector3(0.16, height * 0.36, 0.405),
		Vector3(0.045, height * 0.42, 0.040), _SHEET_FOLD, Vector3(3, 0, 7))
	_prism(root, "Cover Dropped Corner", Vector3(-0.35, height * 0.20, 0.31),
		Vector3(0.12, height * 0.18, 0.055), _SHEET_FOLD,
		Vector3(-6, 18, -9))
	_collider(root, "Cover Body", Vector3(0, height * 0.5, 0),
		Vector3(0.86, height, 0.80))
	return root


## Tripod work lamp. `pitch_degrees` tilts the head down from horizontal; the
## beam leaves along the lamp's local -Z, so `yaw_degrees` aims it. The light is
## steady -- nothing here is animated, so reduced_flashes has nothing to switch
## off -- and it joins LIGHT_GROUP so the blackout can find it.
##
## `cast_shadow` is worth leaving on for exactly one of these: the Restoration
## Lab's ceiling fixture casts none, so this lamp draws the only real shadow in
## the room and it falls off the thing under the sheet.
##
## Bounding box: 0.56 x 2.01 x 0.56 m.
static func build_task_lamp(parent: Node3D, origin: Vector3,
		yaw_degrees := 0.0, pitch_degrees := -6.0, lit := true,
		cast_shadow := true) -> Node3D:
	var root := _mount(parent, "Lab Task Lamp", origin, yaw_degrees)
	for i in range(3):
		var a: float = TAU * float(i) / 3.0
		var leg := _cylinder(root, "Tripod Leg %d" % i,
			Vector3(cos(a) * 0.16, 0.48, sin(a) * 0.16), 0.018, 1.00, _STEEL_DARK)
		leg.rotation_degrees = Vector3(sin(a) * 13.0, 0, -cos(a) * 13.0)
	_cylinder(root, "Lamp Column", Vector3(0, 1.42, 0), 0.028, 0.95, _STEEL_DARK)

	var head := _mount(root, "Lamp Head", Vector3(0, 1.90, 0), 0.0)
	head.rotation_degrees = Vector3(pitch_degrees, 0, 0)
	_box(head, "Head Housing", Vector3.ZERO, Vector3(0.26, 0.22, 0.30), _STEEL_DARK)
	_cylinder(head, "Head Lens", Vector3(0, 0, -0.16), 0.11, 0.02, _LAMP_WARM,
		2.4, 0.0, Vector3(90, 0, 0))
	if lit:
		var light := SpotLight3D.new()
		light.name = "Task Lamp Light"
		light.position = Vector3(0, 0, -0.10)
		light.light_color = Color(1.0, 0.90, 0.74)
		light.light_energy = 1.5
		light.spot_range = 8.0
		light.spot_angle = 34.0
		light.spot_angle_attenuation = 1.4
		light.shadow_enabled = cast_shadow
		light.add_to_group(LIGHT_GROUP)
		head.add_child(light)

	_collider(root, "Lamp Column Body", Vector3(0, 0.98, 0),
		Vector3(0.14, 1.95, 0.14))
	return root


## Keep-back line painted on the floor. A rectangle drawn in four strips: it
## reads as an enclosure from its shape and its position alone, so it still says
## stay out with the colour removed and it still says it in the dark, which is
## more than the wall sign manages.
##
## Bounding box: size.x x 0.012 x size.y. No collider -- paint stops nobody, and
## a collider here would sit right where the Curator has to walk.
static func build_keep_back_line(parent: Node3D, origin: Vector3,
		size := Vector2(2.9, 2.6), yaw_degrees := 0.0) -> Node3D:
	var root := _mount(parent, "Keep Back Line", origin, yaw_degrees)
	for edge_z in [-size.y * 0.5, size.y * 0.5]:
		_box(root, "Floor Line Z %s" % [edge_z], Vector3(0, 0.006, edge_z),
			Vector3(size.x, 0.012, 0.07), _TAPE)
	for edge_x in [-size.x * 0.5, size.x * 0.5]:
		_box(root, "Floor Line X %s" % [edge_x], Vector3(edge_x, 0.006, 0),
			Vector3(0.07, 0.012, size.y - 0.14), _TAPE)
	return root


# ============================================================================
# ROOMS
# ============================================================================


## A dropped box file and the paper that came out of it, trailing away along the
## builder's local +Z. Point it out of somewhere dark and the trail reads as an
## arrow: the player follows paper back to where it came from.
##
## Bounding box: 0.62 x 0.44 x (count * 0.34 + 0.40) m. No collider.
static func build_paper_trail(parent: Node3D, origin: Vector3,
		yaw_degrees := 0.0, count := 7) -> Node3D:
	var root := _mount(parent, "Paper Trail", origin, yaw_degrees)
	# On its side, lid open, most of the way out of the aisle.
	_box(root, "Dropped Box File", Vector3(0, 0.22, 0),
		Vector3(0.42, 0.30, 0.34), _BOARD, 0.0, 0.0, Vector3(0, 26, 84))
	for i in range(count):
		var slot: int = i % _PAPER_NUDGE.size()
		_flat(root, "Loose Sheet %d" % i,
			Vector3(_PAPER_NUDGE[slot], 0.011, 0.34 + i * 0.34),
			Vector2(0.21, 0.297), _PAPER, _PAPER_YAW[slot])
	return root


const _PAPER_NUDGE := [0.06, -0.19, 0.24, -0.08, 0.15, -0.26]
const _PAPER_YAW := [11.0, -48.0, 73.0, -21.0, 39.0, -66.0]


## The Archive, laid out around its own room centre. Pass the centre of the
## room -- FirstMuseumMap builds Archive at (-25, 0, -12), 20 x 10 m, with its
## only doorway on the south wall.
##
## Interior half-extents are 9.65 x 4.65 m from the centre. Every collider here
## sits at least 1.2 m clear of the doorway gap at local (+/-0.9, 4.65), and the
## walking route from that doorway to the far wall along local x = 0 is empty.
##
## The room is two blocks of compact shelving with one aisle wound open in the
## larger block, and a paper trail running out of that aisle into the room. The
## reading desk is the only lit surface; the aisle is the only place in the
## Archive the ceiling fixture cannot reach.
##
## Occupied floor, in local metres, for anything placing props alongside these:
##   x -8.25..-2.15, z -4.44..-1.06   rolling stacks, 5 bays
##   x  4.45..7.35,  z -4.44..-1.06   rolling stacks, 3 bays
##   x  0.60..2.11,  z -4.24..-2.81   card catalogue and its spilled cards
##   x -4.45..-2.75, z  1.90..3.11    reading desk and chair
##   x  8.02..8.68,  z  0.87..2.48    box files, east wall
##   x -9.03..-8.37, z  2.07..2.73    box files, west wall
##   x -5.10..-4.32, z -1.10..1.30    paper trail out of the open aisle
static func build_archive(parent: Node3D, origin: Vector3,
		yaw_degrees := 0.0) -> Node3D:
	var root := _mount(parent, "Archive Props", origin, yaw_degrees)
	# Five bays with the aisle wound open before bay 3, which puts the slot
	# mouth at local x -4.71 facing the room.
	build_rolling_stacks(root, Vector3(-5.2, 0, -2.75), 5, 3)
	build_rolling_stacks(root, Vector3(5.9, 0, -2.75), 3, -1)
	build_card_catalogue(root, Vector3(1.35, 0, -3.95))
	build_reading_desk(root, Vector3(-3.6, 0, 2.7), 172.0)
	build_box_file_stack(root, Vector3(8.35, 0, 1.2), 4, -12.0)
	build_box_file_stack(root, Vector3(8.35, 0, 2.15), 5, 8.0)
	build_box_file_stack(root, Vector3(-8.7, 0, 2.4), 3, 18.0)
	build_paper_trail(root, Vector3(-4.71, 0, -1.10), 8.0, 7)
	return root


## The Restoration Lab, laid out around its own room centre. Pass the centre of
## the room -- FirstMuseumMap builds Restoration Lab at (-25, 0, 22), 20 x 10 m,
## with its only doorway on the north wall.
##
## `exhibit_tag_text` and `crate_stencil_text` are already translated by the
## caller; either one empty builds the physical tag and leaves it blank.
##
## Exhibit 9 stands on the room's centre line, 5.98 m in from the doorway, so it
## is the first thing in the beam when the player comes through and the last
## thing between them and the far wall -- but the doorway approach along local
## x = 0 stays clear for 6 m and the Curator has 8.7 m of open floor to either
## side of the dolly. It is the only lit thing in the room: the ceiling fixture
## casts no shadows, and the tripod lamp aimed at the sheet does.
##
## Occupied floor, in local metres:
##   x -0.95..0.95,  z  1.33..2.67    exhibit 9 on its dolly
##   x -1.60..1.60,  z  0.60..3.40    painted keep-back line (no collider)
##   x  2.62..3.18,  z  0.12..0.68    tripod task lamp
##   x -7.20..-4.80, z -4.36..-3.46   work bench with pegboard, north wall
##   x -8.83..-7.97, z -0.20..2.20    work bench, west wall
##   x  8.17..9.03,  z -2.43..-0.77   fume hood, east wall
##   x  3.90..6.10,  z  1.80..4.00    opened crate and its lid
##   x -4.15..-3.05, z  2.90..3.90    covered object
##   x  7.47..8.33,  z  0.60..1.40    covered object
static func build_restoration_lab(parent: Node3D, origin: Vector3,
		yaw_degrees := 0.0, exhibit_tag_text := "",
		crate_stencil_text := "") -> Node3D:
	var root := _mount(parent, "Restoration Lab Props", origin, yaw_degrees)
	build_shrouded_exhibit(root, Vector3(0, 0, 2.0), 14.0, exhibit_tag_text)
	build_keep_back_line(root, Vector3(0, 0, 2.0), Vector2(2.9, 2.6), 14.0)
	# Aimed at the sheet from the player's right: yaw and pitch resolve to the
	# unit vector from the lamp head at (2.9, 1.90, 0.4) to (0, 1.6, 2.0).
	build_task_lamp(root, Vector3(2.9, 0, 0.4), 119.2, -5.2, true, true)
	build_work_bench(root, Vector3(-6.0, 0, -3.9), 0.0, true)
	build_work_bench(root, Vector3(-8.4, 0, 1.0), 90.0, false)
	build_tool_tray(root, Vector3(-6.5, 0.955, -3.9), 8.0, 0)
	build_tool_tray(root, Vector3(-8.4, 0.955, 1.6), 96.0, 1)
	build_fume_hood(root, Vector3(8.6, 0, -1.6), -90.0)
	build_open_crate(root, Vector3(5.0, 0, 2.9), -28.0, crate_stencil_text)
	build_shrouded_lump(root, Vector3(-3.6, 0, 3.4), 22.0, 1.05)
	build_shrouded_lump(root, Vector3(7.9, 0, 1.0), -14.0, 1.42)
	return root
