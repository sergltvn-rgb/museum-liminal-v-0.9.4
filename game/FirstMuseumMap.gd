@tool
extends Node3D
# Monolithic map script for Godot 4.7. Keeping generation in one script avoids
# editor dependency-chain failures while preserving the existing module sections.

# ===== MapPrimitives.gd =====
# Base layer of the museum map: shared constants, cached PS1-style
# materials and low-poly primitive builders used by all other modules.
# Inheritance chain:
#   FirstMuseumMap < MapIntro < MapDecor < MapLighting
#     < MapStructure < MapPrimitives < Node3D
# Every module sees the constants, vars and helpers of the
# modules below it; call sites stay unchanged.

const MAP_STYLE := "PS1 Horror"
const WALL_HEIGHT := 3.4
const WALL_THICKNESS := 0.35

# Doorway gap used on shared walls between adjacent rooms. Wide enough for the
# player capsule (diameter 0.7) to pass comfortably, tight enough to feel
# like a liminal threshold rather than an open corridor.
const DOOR_GAP := 1.8

var _materials: Dictionary = {}
var _noise_texture: NoiseTexture2D = null
var _bump_texture: NoiseTexture2D = null


# Rope barrier ring around an exhibit: posts with brass caps and a red rope.
func _add_stanchions(parent: Node, center: Vector3, radius: float,
		posts: int) -> void:
	for i in range(posts):
		var a: float = TAU * float(i) / float(posts)
		var a2: float = TAU * float(i + 1) / float(posts)
		var p := center + Vector3(cos(a) * radius, 0, sin(a) * radius)
		var p2 := center + Vector3(cos(a2) * radius, 0, sin(a2) * radius)
		_cylinder(parent, "Stanchion Post %d" % i, Vector3(p.x, 0.5, p.z),
			0.035, 1.0, Color(0.07, 0.07, 0.075))
		_sphere(parent, "Stanchion Cap %d" % i, Vector3(p.x, 1.03, p.z),
			0.055, Color(0.35, 0.28, 0.16))
		var mid := (p + p2) * 0.5
		var rope := _cylinder(parent, "Stanchion Rope %d" % i,
			Vector3(mid.x, 0.86, mid.z), 0.018, p.distance_to(p2) - 0.08,
			Color(0.42, 0.1, 0.09), true)
		rope.rotation = Vector3(0, atan2(p2.z - p.z, -(p2.x - p.x)), PI * 0.5)


# Simple potted plant: tapered pot and a fan of dark leaves.
func _add_plant(parent: Node, plant_position: Vector3) -> void:
	# Every plant is a sibling of every other one under GeneratedMap, so a fixed
	# name means Godot silently renames all but the first to @MeshInstance3D@NNN.
	# The position tag is the same convention _add_door_frame already uses.
	_cone(parent, "Plant Pot %s" % [plant_position], plant_position + Vector3(0, 0.26, 0),
		0.3, 0.36, 0.52, Color(0.17, 0.1, 0.07))
	for i in range(6):
		var a: float = TAU * float(i) / 6.0 + plant_position.x * 0.7
		var leaf := _prism(parent, "Plant Leaf %d %s" % [i, plant_position],
			plant_position + Vector3(cos(a) * 0.14, 0.95, sin(a) * 0.14),
			Vector3(0.15, 0.95, 0.15), Color(0.05, 0.15, 0.07))
		leaf.rotation_degrees = Vector3(sin(a) * 22.0, 0, cos(a) * -22.0)


func _box(parent: Node, node_name: String, box_position: Vector3, size: Vector3,
		color: Color, emission_energy := 0.0, metallic := 0.0,
		with_collision := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _primitive(parent, node_name, box_position, mesh, size, color,
		false, emission_energy, metallic, with_collision)


func _cylinder(parent: Node, node_name: String, cylinder_position: Vector3,
		radius: float, height: float, color: Color,
		horizontal := false, emission_energy := 0.0,
		with_collision := true) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = radius
	mesh.top_radius = radius
	var size := Vector3(radius * 2.0, height, radius * 2.0)
	var inst := _primitive(parent, node_name, cylinder_position, mesh, size,
		color, false, emission_energy, 0.0, with_collision)
	if horizontal:
		# Lay the cylinder on its side (default points up along Y).
		inst.rotate_z(deg_to_rad(90))
	return inst


func _sphere(parent: Node, node_name: String, sphere_position: Vector3,
		radius: float, color: Color, emission_energy := 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _primitive(parent, node_name, sphere_position, mesh,
		Vector3(radius * 2.0, radius * 2.0, radius * 2.0), color,
		false, emission_energy, 0.0)


func _prism(parent: Node, node_name: String, prism_position: Vector3,
		size: Vector3, color: Color, emission_energy := 0.0) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _primitive(parent, node_name, prism_position, mesh, size,
		color, false, emission_energy, 0.0)


func _torus(parent: Node, node_name: String, torus_position: Vector3,
		inner_radius: float, outer_radius: float, color: Color,
		emission_energy := 0.0, upright := true) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	var thickness := outer_radius - inner_radius
	var inst := _primitive(parent, node_name, torus_position, mesh,
		Vector3(outer_radius * 2.0, thickness, outer_radius * 2.0),
		color, false, emission_energy, 0.0)
	if upright:
		# Stand the ring upright on its pedestal.
		inst.rotate_x(deg_to_rad(90))
	return inst


func _cone(parent: Node, node_name: String, cone_position: Vector3,
		bottom_radius: float, top_radius: float, height: float, color: Color,
		emission_energy := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	var max_radius: float = max(bottom_radius, top_radius)
	return _primitive(parent, node_name, cone_position, mesh,
		Vector3(max_radius * 2.0, height, max_radius * 2.0), color,
		false, emission_energy, 0.0)


func _glass_case(parent: Node, node_name: String, case_position: Vector3,
		size: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = case_position
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = _glass_material()
	parent.add_child(instance)
	return instance


func _plane(parent: Node, node_name: String, plane_position: Vector3,
		size: Vector2, color: Color, horizontal := false,
		transparent := false, emission_energy := 0.0,
		with_collision := true) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var inst := _primitive(parent, node_name, plane_position, mesh,
		Vector3(size.x, 0.01, size.y), color, transparent, emission_energy, 0.0,
		with_collision)
	if not horizontal:
		# PlaneMesh faces +Y by default; stand it up as a wall/sign.
		inst.rotate_x(deg_to_rad(90))
	return inst


func _capsule(parent: Node, node_name: String, capsule_position: Vector3,
		radius: float, height: float, color: Color,
		emission_energy := 0.0) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return _primitive(parent, node_name, capsule_position, mesh,
		Vector3(radius * 2.0, height, radius * 2.0), color,
		false, emission_energy, 0.0)


func _primitive(parent: Node, node_name: String, prim_position: Vector3,
		mesh: PrimitiveMesh, size: Vector3, color: Color, transparent: bool,
		emission_energy: float, metallic: float,
		with_collision := true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = prim_position
	instance.mesh = mesh
	instance.material_override = _material(color, transparent, emission_energy, metallic)
	# Cull distant decorative geometry and avoid shadow-map work for tiny props.
	instance.visibility_range_end = 115.0
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if size.length() < 0.65:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

	# Tiny trim, ropes and labels do not need physics bodies. Keeping collision
	# only on walk-blocking geometry substantially reduces generated nodes.
	var collision_worthy := size.x >= 0.12 and size.y >= 0.08 and size.z >= 0.12
	if not transparent and with_collision and collision_worthy:
		var static_body := StaticBody3D.new()
		static_body.name = "%s Collision" % node_name
		instance.add_child(static_body)

		var shape := BoxShape3D.new()
		shape.size = size

		var collision := CollisionShape3D.new()
		collision.name = "%s CollisionShape" % node_name
		collision.shape = shape
		static_body.add_child(collision)

	return instance


# --- Signage the security feeds must not see --------------------------------
#
# Three families of Label3D are museum signage to a player standing in front of
# them and pure debug overlay through a monitor: the room name floating in the
# middle of every room (_add_room), the mount tag above every CCTV post
# (_camera) and the English notices on the sealed wing doors (_add_locked_doors,
# unlock_wing). Because Label3D is billboarded they turn to face whatever camera
# is rendering, so every one of the eleven feeds used to show a fan of text
# swivelling to greet it.
#
# They are not deleted -- they are real world-building on foot -- they are moved
# onto their own visual layer. The player camera, the intro camera and the editor
# preview camera all keep Godot's default all-layers cull_mask and still see
# them; SecurityCameraTablet drops this one bit from the cull_mask of every feed
# camera it builds, in _make_cameras(), mirroring this number as its own
# CCTV_HIDDEN_LAYER. Layer 20 is the last of the twenty and nothing else in the
# project touches `layers` or `cull_mask` at all.
const CCTV_HIDDEN_LAYER := 20
const CCTV_HIDDEN_MASK := 1 << (CCTV_HIDDEN_LAYER - 1)


func _add_label(parent: Node, text: String, label_position: Vector3,
		color: Color, hide_from_cctv := false) -> void:
	var label := Label3D.new()
	label.name = "Label - %s" % text
	label.text = text
	label.position = label_position
	label.modulate = color
	label.font_size = 32
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visibility_range_end = 22.0
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# Compact museum plaques remain readable without covering entire rooms.
	label.outline_size = 4
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	if hide_from_cctv:
		# Exclusively on the hidden layer: leaving layer 1 set as well would keep
		# the feeds' default cull_mask matching and defeat the whole exercise.
		label.layers = CCTV_HIDDEN_MASK
	parent.add_child(label)


func _material(color: Color, transparent: bool, emission_energy: float = 0.0,
		metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s:%s:%s:%s" % [color.to_html(true), transparent,
		emission_energy, metallic]
	if _materials.has(key):
		return _materials[key]

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	# Polished-marble finish: smoother and a little glossy instead of the
	# old fully-matte plaster.
	mat.roughness = clampf(0.5 - metallic * 0.35, 0.12, 1.0)
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

	# Restrained surface detail. The previous high-frequency nearest-filtered
	# noise covered every wall and prop with distracting television static.
	if not transparent and metallic < 0.35 and emission_energy <= 0.0:
		if _noise_texture == null:
			var noise := FastNoiseLite.new()
			noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
			noise.frequency = 0.16
			noise.fractal_octaves = 2
			_noise_texture = NoiseTexture2D.new()
			_noise_texture.width = 128
			_noise_texture.height = 128
			_noise_texture.noise = noise
			_noise_texture.seamless = true
		mat.roughness_texture = _noise_texture
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		if _bump_texture == null:
			var bump_noise := FastNoiseLite.new()
			bump_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
			bump_noise.frequency = 0.12
			bump_noise.fractal_octaves = 2
			_bump_texture = NoiseTexture2D.new()
			_bump_texture.width = 128
			_bump_texture.height = 128
			_bump_texture.noise = bump_noise
			_bump_texture.seamless = true
			_bump_texture.as_normal_map = true
			_bump_texture.bump_strength = 1.2
		mat.normal_enabled = true
		mat.normal_texture = _bump_texture
		mat.normal_scale = 0.08
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.22, 0.22, 0.22)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_materials[key] = mat
	return mat


func _glass_material() -> StandardMaterial3D:
	if _materials.has("__glass__"):
		return _materials["__glass__"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.75, 0.8, 0.1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.04
	mat.metallic = 0.15
	mat.metallic_specular = 0.7
	_materials["__glass__"] = mat
	return mat

# ===== MapStructure.gd =====
const MuseumModels := preload("res://game/MapModels.gd")
# Structural layer: rooms, walls with door gaps, door frames and leaves,
# locked wing doors, security cameras and the player spawn.
# Inheritance chain:
#   FirstMuseumMap < MapIntro < MapDecor < MapLighting
#     < MapStructure < MapPrimitives < Node3D
# Every module sees the constants, vars and helpers of the
# modules below it; call sites stay unchanged.


## One room: floor, ceiling slab, four trimmed walls with optional doorway gaps,
## and the sign hanging in the middle of it.
##
## `room_name` is the NODE name and is deliberately not player-facing. It is the
## handle the whole project addresses this room by -- test_map_verification looks
## up "Central Atrium East Wall Near Segment" by path, GameManager and the
## security tablet find their props under these parents -- so it stays an English
## identifier and never moves with the locale.
##
## `sign_key` is what the player reads. All eleven rooms are already named in the
## catalogue, because SecurityCameraTablet.ROOMS labels the same eleven
## rectangles on the mini-map from CAM_ROOM_* / CAM_ENTRANCE / CAM_PLANETARIUM;
## the signs used to be drawn from `room_name` instead, so a Russian player
## walking the building read "Equipment Storage" on the wall and "Склад" on the
## monitor for the same room. Passing the key routes both through one row.
func _add_room(parent: Node, room_name: String, sign_key: String,
		center: Vector3, size: Vector2, floor_color: Color,
		doors: Dictionary = {}) -> void:
	var room := Node3D.new()
	room.name = room_name
	room.position = center
	parent.add_child(room)

	_box(room, "%s Floor" % room_name, Vector3(0, -0.08, 0),
		Vector3(size.x, 0.16, size.y), floor_color)
	_box(room, "%s Ceiling Shadow" % room_name, Vector3(0, WALL_HEIGHT + 0.05, 0),
		Vector3(size.x, 0.12, size.y), Color(0.80, 0.79, 0.76))

	# White marble halls: light walls with a darker per-room accent stripe
	# so rooms still read as distinct spaces.
	var wall_color := Color(0.87, 0.86, 0.83)
	var accent: Color = floor_color.darkened(0.45)
	var north_gap: float = doors.get("N", 0.0)
	var south_gap: float = doors.get("S", 0.0)
	var east_gap: float = doors.get("E", 0.0)
	var west_gap: float = doors.get("W", 0.0)

	# Walls are inset by half a thickness so this room's wall and the
	# neighbouring room's wall sit back-to-back instead of overlapping in
	# the same plane (the overlap caused visible z-fighting on every
	# shared wall).
	var wall_inset_z: float = size.y * 0.5 - WALL_THICKNESS * 0.5
	var wall_inset_x: float = size.x * 0.5 - WALL_THICKNESS * 0.5
	_horizontal_wall_with_gap(room, "%s North Wall" % room_name, -wall_inset_z,
		size.x, wall_color, north_gap, accent)
	_horizontal_wall_with_gap(room, "%s South Wall" % room_name, wall_inset_z,
		size.x, wall_color, south_gap, accent)
	_vertical_wall_with_gap(room, "%s West Wall" % room_name, -wall_inset_x,
		size.y, wall_color, west_gap, accent)
	_vertical_wall_with_gap(room, "%s East Wall" % room_name, wall_inset_x,
		size.y, wall_color, east_gap, accent)
	# Readable on foot, hidden from the CCTV feeds -- see CCTV_HIDDEN_LAYER.
	_add_label(room, tr(sign_key), Vector3(0, 2.2, size.y * 0.5 - 0.8),
		Color(0.24, 0.27, 0.24), true)


func _horizontal_wall_with_gap(parent: Node, wall_name: String, z: float,
		width: float, color: Color, gap: float = 0.0,
		accent := Color(0.16, 0.17, 0.16)) -> void:
	var y: float = WALL_HEIGHT * 0.5
	if gap <= 0.0:
		# Solid wall, no doorway.
		_wall_segment(parent, "%s Wall" % wall_name, Vector3(0, y, z),
			Vector3(width, WALL_HEIGHT, WALL_THICKNESS), color, accent)
		return
	var segment_width: float = max(0.4, (width - gap) * 0.5)
	var left_x: float = -(gap * 0.5 + segment_width * 0.5)
	var right_x: float = gap * 0.5 + segment_width * 0.5
	_wall_segment(parent, "%s Left Segment" % wall_name, Vector3(left_x, y, z),
		Vector3(segment_width, WALL_HEIGHT, WALL_THICKNESS), color, accent)
	_wall_segment(parent, "%s Right Segment" % wall_name, Vector3(right_x, y, z),
		Vector3(segment_width, WALL_HEIGHT, WALL_THICKNESS), color, accent)
	_box(parent, "%s Door Lintel" % wall_name, Vector3(0, WALL_HEIGHT - 0.35, z),
		Vector3(gap, 0.7, WALL_THICKNESS), color.darkened(0.08))


func _vertical_wall_with_gap(parent: Node, wall_name: String, x: float,
		depth: float, color: Color, gap: float = 0.0,
		accent := Color(0.16, 0.17, 0.16)) -> void:
	var y: float = WALL_HEIGHT * 0.5
	if gap <= 0.0:
		_wall_segment(parent, "%s Wall" % wall_name, Vector3(x, y, 0),
			Vector3(WALL_THICKNESS, WALL_HEIGHT, depth), color, accent)
		return
	var segment_depth: float = max(0.4, (depth - gap) * 0.5)
	var near_z: float = -(gap * 0.5 + segment_depth * 0.5)
	var far_z: float = gap * 0.5 + segment_depth * 0.5
	_wall_segment(parent, "%s Near Segment" % wall_name, Vector3(x, y, near_z),
		Vector3(WALL_THICKNESS, WALL_HEIGHT, segment_depth), color, accent)
	_wall_segment(parent, "%s Far Segment" % wall_name, Vector3(x, y, far_z),
		Vector3(WALL_THICKNESS, WALL_HEIGHT, segment_depth), color, accent)
	_box(parent, "%s Door Lintel" % wall_name, Vector3(x, WALL_HEIGHT - 0.35, 0),
		Vector3(WALL_THICKNESS, 0.7, gap), color.darkened(0.08))


# One wall slab dressed with a baseboard, an accent stripe and a cornice so
# rooms read as finished interiors instead of bare boxes. Trim automatically
# skips doorway gaps because it is emitted per wall segment.
func _wall_segment(parent: Node, seg_name: String, center: Vector3,
		size: Vector3, color: Color, accent: Color) -> void:
	_box(parent, seg_name, center, size, color)
	var trim_color := Color(0.05, 0.05, 0.048)
	var along_x: bool = size.x > size.z
	var base_size := Vector3(size.x, 0.22, size.z + 0.06) if along_x else Vector3(size.x + 0.06, 0.22, size.z)
	var stripe_size := Vector3(size.x, 0.14, size.z + 0.04) if along_x else Vector3(size.x + 0.04, 0.14, size.z)
	var crown_size := Vector3(size.x, 0.16, size.z + 0.06) if along_x else Vector3(size.x + 0.06, 0.16, size.z)
	_box(parent, "%s Baseboard" % seg_name, Vector3(center.x, 0.11, center.z),
		base_size, trim_color, 0.0, 0.0, false)
	_box(parent, "%s Accent Stripe" % seg_name, Vector3(center.x, 1.25, center.z),
		stripe_size, accent, 0.0, 0.0, false)
	_box(parent, "%s Cornice" % seg_name, Vector3(center.x, WALL_HEIGHT - 0.14, center.z),
		crown_size, trim_color, 0.0, 0.0, false)


# A door portal dressing the seam between two adjacent rooms: side jambs, a
# header beam, a threshold and glowing doorway signs. `axis` is "x" for an
# East-West wall (door faces N/S) or "z" for a North-South wall.
# NOTE: the old version had the two axis branches swapped, which planted the
# frame slabs sideways across every doorway -- the "crooked doors".
func _add_door_frame(parent: Node, center: Vector3, axis: String,
		leaves := false) -> void:
	var frame_color := Color(0.06, 0.06, 0.058)
	# Frames span both back-to-back walls (2 x WALL_THICKNESS) plus a lip.
	var frame_depth := WALL_THICKNESS * 2.0 + 0.14
	var jamb_thick := 0.18
	var jamb_height := WALL_HEIGHT - 0.7
	var jamb_y := jamb_height * 0.5
	var jamb_offset := DOOR_GAP * 0.5 + jamb_thick * 0.5
	var span := DOOR_GAP + jamb_thick * 2.0
	var header_y := jamb_height + 0.15
	var sign_color := Color(0.2, 0.78, 0.42)
	if axis == "x":
		# Wall runs along X: jambs sit left/right of the gap along X.
		_box(parent, "Door Frame Jamb -X %s" % [center], center + Vector3(-jamb_offset, jamb_y, 0),
			Vector3(jamb_thick, jamb_height, frame_depth), frame_color)
		_box(parent, "Door Frame Jamb +X %s" % [center], center + Vector3(jamb_offset, jamb_y, 0),
			Vector3(jamb_thick, jamb_height, frame_depth), frame_color)
		_box(parent, "Door Frame Header %s" % [center], center + Vector3(0, header_y, 0),
			Vector3(span, 0.3, frame_depth), frame_color)
		# Visual only: a colliding threshold acts as a tiny wall that
		# CharacterBody3D cannot step over and blocks the doorway.
		_box(parent, "Door Frame Threshold %s" % [center], center + Vector3(0, 0.02, 0),
			Vector3(span, 0.04, frame_depth), frame_color.darkened(0.1),
			0.0, 0.0, false)
		for i in range(2):
			var s: float = -1.0 if i == 0 else 1.0
			_box(parent, "Doorway Sign %s %d" % [center, i],
				center + Vector3(0, header_y, s * (frame_depth * 0.5 + 0.03)),
				Vector3(0.85, 0.22, 0.05), sign_color, 0.9, 0.0, false)
	else:
		# Wall runs along Z: jambs sit either side of the gap along Z.
		_box(parent, "Door Frame Jamb -Z %s" % [center], center + Vector3(0, jamb_y, -jamb_offset),
			Vector3(frame_depth, jamb_height, jamb_thick), frame_color)
		_box(parent, "Door Frame Jamb +Z %s" % [center], center + Vector3(0, jamb_y, jamb_offset),
			Vector3(frame_depth, jamb_height, jamb_thick), frame_color)
		_box(parent, "Door Frame Header %s" % [center], center + Vector3(0, header_y, 0),
			Vector3(frame_depth, 0.3, span), frame_color)
		# Visual only (see note above): no collision on the threshold.
		_box(parent, "Door Frame Threshold %s" % [center], center + Vector3(0, 0.02, 0),
			Vector3(frame_depth, 0.04, span), frame_color.darkened(0.1),
			0.0, 0.0, false)
		for i in range(2):
			var s: float = -1.0 if i == 0 else 1.0
			_box(parent, "Doorway Sign %s %d" % [center, i],
				center + Vector3(s * (frame_depth * 0.5 + 0.03), header_y, 0),
				Vector3(0.05, 0.22, 0.85), sign_color, 0.9, 0.0, false)
	if leaves:
		_door_leaves(parent, center, axis)


# Museum double doors frozen ajar on their hinges. Opened well past 80
# degrees so the panels hug the jambs and never block the walkable gap.
func _door_leaves(parent: Node, center: Vector3, axis: String) -> void:
	var leaf_h := WALL_HEIGHT - 0.98
	var leaf_w := DOOR_GAP * 0.5 - 0.04
	var leaf_color := Color(0.15, 0.11, 0.075)
	# Past 100 degrees the leaves lie flat against the room wall and their
	# collision boxes stay fully outside the walkable gap.
	var swings := [104.0, 100.0]
	for i in range(2):
		var s: float = -1.0 if i == 0 else 1.0
		var hinge := Node3D.new()
		hinge.name = "Door Hinge %s %d" % [center, i]
		if axis == "x":
			hinge.position = center + Vector3(s * DOOR_GAP * 0.5, 0, 0)
			hinge.rotation_degrees = Vector3(0, s * swings[i], 0)
			parent.add_child(hinge)
			_box(hinge, "Door Leaf %d" % i, Vector3(-s * leaf_w * 0.5, leaf_h * 0.5 + 0.05, 0),
				Vector3(leaf_w, leaf_h, 0.06), leaf_color)
			_box(hinge, "Door Handle %d" % i, Vector3(-s * (leaf_w - 0.12), leaf_h * 0.45, 0.06),
				Vector3(0.16, 0.04, 0.05), Color(0.35, 0.3, 0.2), 0.0, 0.6, false)
		else:
			hinge.position = center + Vector3(0, 0, s * DOOR_GAP * 0.5)
			hinge.rotation_degrees = Vector3(0, s * swings[i], 0)
			parent.add_child(hinge)
			_box(hinge, "Door Leaf %d" % i, Vector3(0, leaf_h * 0.5 + 0.05, -s * leaf_w * 0.5),
				Vector3(0.06, leaf_h, leaf_w), leaf_color)


# Every CCTV mount joins this group. Counting cameras must never depend on the
# node name: the mount is a procedural pivot whose display name is a plain
# string, and test_map_verification asserts one member per
# SecurityCameraTablet.CAMS entry.
const SECURITY_CAMERA_GROUP := "security_camera"

# Underside of the ceiling slab: _add_room puts it at WALL_HEIGHT + 0.05 with a
# thickness of 0.12, so the visible soffit is at 3.39. The mount brackets reach
# exactly this high, which is what turns them from props floating in mid-air
# into fixtures screwed to something.
const CEILING_SOFFIT_Y := WALL_HEIGHT + 0.05 - 0.06


## Eleven CCTV posts, listed as (name, mount point, the point the feed frames).
##
## The third argument used to be a hand-written yaw and the mount used to have no
## pitch at all, so the prop and the picture were two independent numbers. Ten of
## the eleven happened to agree to within half a degree; CAM 11 was 6.8 deg out
## and nothing noticed, because nothing compared them. Deriving both angles from
## the target makes that class of drift impossible.
##
## Keep index-aligned with SecurityCameraTablet.CAMS: the tablet addresses feeds
## by index, `pos` must equal the mount point and `target` the point below.
func _add_cameras(parent: Node) -> void:
	_camera(parent, "Камера 01 - Entrance", Vector3(-9.6, 3.0, 33.6), Vector3(0, 1.0, 25))
	_camera(parent, "Камера 02 - Atrium West", Vector3(-13.6, 3.0, 12.6), Vector3(0, 1.0, 0))
	_camera(parent, "Камера 03 - Atrium East", Vector3(13.6, 3.0, -12.6), Vector3(0, 1.0, 0))
	_camera(parent, "Камера 04 - Watcher Office", Vector3(-33.8, 2.9, -5.8), Vector3(-25, 1.0, 0))
	_camera(parent, "Камера 05 - Gravity Wing A", Vector3(16.4, 3.0, -7.8), Vector3(28, 1.0, 0))
	_camera(parent, "Камера 06 - Time Wing B", Vector3(-11.8, 3.0, -16.4), Vector3(0, 1.0, -24))
	# Post 07 used to hang at (9.6, 2.9, -20.6) -- inside Time Wing B, staring at
	# the Wing C blast door from 4.27 m -- and it was the only feed nominated for
	# all three Space Wing C exhibits. It could not see one of them: the solid
	# wall at x = 13 stopped the rays to the Portal Arch (11.40 m short) and the
	# Orrery (17.87 m short), and the blast door itself stopped the ray to the
	# Star Globe (7.76 m short). Wing C is reachable only through the 1.8 m
	# doorway at z = -24, so no mount outside the wing can do better; the post had
	# to move inside it. This corner -- 1.05 m off the east inner face at
	# x = 34.65 and 0.85 m off the south inner face at z = -31.65, the same
	# clearances CAM 05 uses -- reaches all three (Portal Arch 14.14 m, Star Globe
	# 15.52 m, Orrery 5.43 m, every off-axis angle inside the 53.8 deg horizontal
	# half-frustum) and still frames the blast door 21.7 m down the wing, 17 deg
	# off the optical axis, so the one way in is on camera too.
	_camera(parent, "Камера 07 - Space Wing C", Vector3(33.6, 2.9, -30.8), Vector3(24, 1.0, -24))
	# Post 08 was "Камера 08 - Basement Elevator". There is no basement, no lift
	# and no shaft anywhere in this museum -- that name was the only occurrence of
	# the word in the whole project -- and the feed framed 4.8 m of bare Atrium
	# floor in the south-east corner. The aim point is untouched; the corner it
	# points at now carries the museum's main distribution board
	# (_add_atrium_power_panel), which is a thing the night watch would genuinely
	# keep a camera on, given how night one begins. The optical axis lands on the
	# board's door 4.89 m out. The label the player reads comes from
	# SecurityCameraTablet.CAMS[7].label -> CAM_BASEMENT_LIFT, whose catalogue text
	# now reads "Atrium — Power Panel" / "Атриум — электрощит" in both columns.
	_camera(parent, "Камера 08 - Atrium Power Panel", Vector3(8.8, 2.9, 11.8), Vector3(12.5, 1.2, 14.4))
	_camera(parent, "Камера 09 - Planetarium", Vector3(-9.2, 3.0, -34.4), Vector3(0, 1.2, -41))
	_camera(parent, "Камера 10 - Restoration Lab", Vector3(-33.8, 2.9, 18.4), Vector3(-25, 1.0, 22))
	# Post 11 moved from the wing's north-west corner to its south-west one, a
	# mirror image across z = 0 with the same 0.85 m clearances. From the old
	# corner the imported superheavy_sphere model stood across the line to the
	# Mass Pendulum (blocked at (47.11, 2.48, -3.45), 13.23 m short) and 5.11 m of
	# it lay across the line to its own anchor. From here all three are clear:
	# Superheavy Sphere 13.92 m, Dense Ingot 5.31 m, Mass Pendulum 16.10 m.
	_camera(parent, "Камера 11 - Mass Wing D", Vector3(42.2, 2.9, 6.8), Vector3(52, 1.0, 0))


## One CCTV post, hung from the ceiling it is actually under: plate, drop stem,
## ball joint, and a pitched head carrying housing, lens and record LED.
##
## Built from primitives rather than from models/camera.fbx. That file is a
## 13.4 MB TRIPOD camera -- its two materials are literally named `camera` and
## `tripod` -- and it was being instantiated once per post, at whatever pitch the
## import gave it, with nothing holding it up at y ~ 2.9. It won every time
## because the procedural branch that used to live here was unreachable:
## MuseumModels.place() returns null only when ResourceLoader.exists() fails,
## and for a file that is present that never happens. Six primitives per post
## replace it -- lighter, supported, and aimed where the feed is aimed.
func _camera(parent: Node, camera_name: String, camera_position: Vector3,
		target: Vector3) -> void:
	# Same derivation SecurityCameraTablet's `cam.look_at(target)` performs, so
	# the housing and its picture cannot disagree. Godot's default YXZ Euler order
	# makes rotation_degrees (pitch, yaw, 0) aim -Z at the target.
	var to_target := target - camera_position
	var ground_run := Vector2(to_target.x, to_target.z).length()
	var yaw := rad_to_deg(atan2(-to_target.x, -to_target.z))
	var pitch := rad_to_deg(atan2(to_target.y, ground_run)) if ground_run > 0.001 else -90.0

	# The bracket only yaws: a drop stem that leaned with the head would read as
	# a bent pole rather than as a fixture.
	var mount := Node3D.new()
	mount.name = camera_name
	mount.position = camera_position
	mount.rotation_degrees = Vector3(0, yaw, 0)
	parent.add_child(mount)
	mount.add_to_group(SECURITY_CAMERA_GROUP, true)

	var bracket_color := Color(0.05, 0.05, 0.052)
	var drop: float = maxf(0.2, CEILING_SOFFIT_Y - camera_position.y)
	_box(mount, "%s Ceiling Plate" % camera_name, Vector3(0, drop - 0.02, 0),
		Vector3(0.26, 0.04, 0.26), bracket_color, 0.0, 0.35, false)
	# Runs from inside the housing up into the plate, so no gap opens at either
	# end whatever pitch the head is set to.
	_cylinder(mount, "%s Drop Stem" % camera_name,
		Vector3(0, (drop + 0.06) * 0.5, 0), 0.035, drop - 0.14,
		bracket_color, false, 0.0, false)
	_sphere(mount, "%s Ball Joint" % camera_name, Vector3(0, 0.16, 0), 0.055,
		Color(0.09, 0.09, 0.095))

	# Grouped under a head so housing, lens and LED tilt down together (the old
	# lens was a vertical cylinder poking out of the housing).
	var head := Node3D.new()
	head.name = "%s Head" % camera_name
	head.rotation_degrees = Vector3(pitch, 0, 0)
	mount.add_child(head)
	# Nothing on a CCTV post carries collision: MapModels lists "security_camera"
	# in NON_BLOCKING for exactly this reason, and a static body up at y~3 would
	# only give Recast an overhead obstacle to filter back out again.
	_box(head, "%s Body" % camera_name, Vector3.ZERO,
		Vector3(0.5, 0.28, 0.34), Color(0.03, 0.035, 0.035), 0.0, 0.0, false)
	var lens := _cylinder(head, "%s Lens" % camera_name, Vector3(0, 0, -0.24),
		0.09, 0.14, Color(0.01, 0.08, 0.07), false, 0.0, false)
	lens.rotation_degrees = Vector3(90, 0, 0)
	_box(head, "%s LED" % camera_name, Vector3(0.17, 0.08, -0.18),
		Vector3(0.04, 0.04, 0.04), Color(0.9, 0.1, 0.08), 1.8, 0.0, false)

	# Mount tag: legible to a player standing under the post, culled by the feeds.
	_add_label(parent, camera_name, camera_position + Vector3(0, 0.3, 0),
		Color(0.35, 0.95, 0.78), true)


func _add_locked_doors(parent: Node) -> void:
	# The three notices below hang on CCTV_HIDDEN_LAYER: they are door signage a
	# player reads standing in front of the blast door, not something the night
	# watch should be reading off a monitor.
	# Space Wing C blast door: the shared wall x=13 now has a real doorway,
	# sealed by this door until night 2 (see unlock_wing).
	_box(parent, "Wing C Locked Blast Door", Vector3(12.52, 1.25, -24),
		Vector3(0.22, 2.5, 3.5), Color(0.035, 0.04, 0.055), 0.0, 0.5)
	_add_label(parent, "Space Wing C - opens on Night 2", Vector3(12.3, 2.8, -24),
		Color(0.55, 0.65, 0.95), true)
	# Mass Wing D blast door on the Gravity Wing east wall (x=41), night 3.
	_box(parent, "Wing D Locked Blast Door", Vector3(40.52, 1.25, 0),
		Vector3(0.22, 2.5, 3.5), Color(0.05, 0.04, 0.03), 0.0, 0.5)
	_add_label(parent, "Mass Wing D - opens on Night 3", Vector3(40.3, 2.8, 0),
		Color(0.8, 0.65, 0.42), true)
	# Causality Wing E sealed door on the Office west wall (x=-35).
	_box(parent, "Causality Wing E Sealed Door", Vector3(-34.53, 1.25, 0),
		Vector3(0.22, 2.5, 3.6), Color(0.055, 0.025, 0.025), 0.0, 0.5)
	_add_label(parent, "Causality Wing E - do not schedule",
		Vector3(-34.3, 2.8, 0), Color(0.95, 0.25, 0.18), true)


func unlock_wing(wing: String) -> void:
	# Called by the GameManager on nights 2-3: removes the blast door so the
	# wing becomes reachable and marks the doorway as open.
	var root := get_node_or_null("GeneratedMap")
	if root == null:
		return
	var door_name := "Wing C Locked Blast Door" if "C" in wing \
		else "Wing D Locked Blast Door"
	var door := root.find_child(door_name, true, false)
	if door != null:
		# Detach before freeing: queue_free() only takes effect at the end of the
		# frame, and the navigation re-bake below would still see the door (and
		# its collider child) and keep baking the wing as sealed.
		door.get_parent().remove_child(door)
		door.queue_free()
	var label_pos := Vector3(12.3, 2.35, -24) if "C" in wing \
		else Vector3(40.3, 2.35, 0)
	# Replaces the notice removed with the door, so it inherits its layer too.
	_add_label(root, "%s - OPEN" % wing, label_pos, Color(0.45, 0.95, 0.6), true)
	# The wing was baked as unreachable; without this the Curator can never
	# path into the half of the museum it spawns in on nights 2-3.
	_bake_navigation()


# --- Navigation ------------------------------------------------------------
# The Curator paths through the museum with a NavigationAgent3D, which needs a
# baked navigation mesh. Geometry is parsed from static colliders, which is
# exactly the set of surfaces that also block the player: _primitive() gives a
# body only to walk-blocking geometry and skips trim, ropes, labels and glass.
const NAV_SOURCE_GROUP := "museum_nav_source"

var _nav_region: NavigationRegion3D = null

## A rebake that was asked for while the previous one was still on its worker
## thread. See _bake_navigation() for why dropping it sealed Mass Wing D.
var _nav_rebake_queued := false


func _add_navigation(parent: Node3D) -> void:
	# Parsing starts from the nodes in this group and walks their children.
	if not parent.is_in_group(NAV_SOURCE_GROUP):
		parent.add_to_group(NAV_SOURCE_GROUP)

	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = NAV_SOURCE_GROUP
	# The Curator capsule is r=0.38, h=2.25 (CuratorMonster). Recast erodes the
	# walkable area by agent_radius rounded up to whole cells, so these two
	# values together decide whether doorways survive the bake: jambs leave a
	# clear DOOR_GAP (1.8 m), and ceil(0.45 / 0.15) = 3 cells per side keeps
	# 0.9 m of navmesh through every door. Widening the radius or coarsening
	# the cell size pinches that shut and strands the Curator in one room.
	nav_mesh.agent_radius = 0.45
	nav_mesh.agent_height = 2.2
	nav_mesh.agent_max_climb = 0.4
	nav_mesh.agent_max_slope = 45.0
	nav_mesh.cell_size = 0.15
	nav_mesh.cell_height = 0.1
	# Door lintels hang at y 2.70-3.40 and ceiling slabs at 3.45; without these
	# filters the floor beneath them bakes as a walkable-but-too-low span.
	nav_mesh.filter_low_hanging_obstacles = true
	nav_mesh.filter_ledge_spans = true
	nav_mesh.filter_walkable_low_height_spans = true

	_nav_region = NavigationRegion3D.new()
	_nav_region.name = "Museum Navigation"
	_nav_region.navigation_mesh = nav_mesh
	parent.add_child(_nav_region)
	_watch_bakes()
	# Baking walks every collider in the museum — keep it off the frame that is
	# already building the entire map.
	call_deferred("_bake_navigation")


## Attach navigation to a GeneratedMap that came from the saved scene rather
## than from build_map(), reusing a serialized region if one is already there.
func _ensure_navigation() -> void:
	var root := get_node_or_null("GeneratedMap") as Node3D
	if root == null:
		return
	var existing := root.get_node_or_null("Museum Navigation") as NavigationRegion3D
	if existing == null:
		_add_navigation(root)
		return
	_nav_region = existing
	if not root.is_in_group(NAV_SOURCE_GROUP):
		root.add_to_group(NAV_SOURCE_GROUP)
	_watch_bakes()
	call_deferred("_bake_navigation")


## THE MAP'S GRID HAS TO MATCH THE MESH'S (found in a live run, 2026-07-30).
##
## A NavigationRegion3D bakes at the cell size given to its NavigationMesh, but
## the navigation MAP it joins rasterises paths on a grid of its own, and
## Godot's default is 0.25 / 0.25 -- coarser than the 0.15 / 0.10 baked in
## _add_navigation(). Every launch printed the engine's own mismatch warning
## twice per region, and the consequence is not cosmetic: a coarser map grid
## rounds mesh edges away precisely at door openings, which is the 0.9 m of
## navmesh that ceil(0.45 / 0.15) = 3 eroded cells per side leaves through a
## DOOR_GAP door -- the width the Curator needs to leave a room at all.
func _align_navigation_map() -> void:
	if not is_instance_valid(_nav_region) or not _nav_region.is_inside_tree():
		return
	var mesh := _nav_region.navigation_mesh
	if mesh == null:
		return
	var map: RID = _nav_region.get_world_3d().navigation_map
	if not map.is_valid():
		return
	NavigationServer3D.map_set_cell_size(map, mesh.cell_size)
	NavigationServer3D.map_set_cell_height(map, mesh.cell_height)


## Subscribe to the region's own completion signal, which is the only thing that
## can tell us when a queued rebake is allowed to start. Idempotent: both
## entry points call it, and _ensure_navigation() may adopt a region a previous
## _add_navigation() already wired up.
func _watch_bakes() -> void:
	if not is_instance_valid(_nav_region):
		return
	# Both entry points reach the region through here, and by this point it is in
	# the tree -- the one place where aligning the map costs nothing and cannot be
	# missed by whichever path built the region.
	_align_navigation_map()
	if not _nav_region.bake_finished.is_connected(_on_nav_bake_finished):
		_nav_region.bake_finished.connect(_on_nav_bake_finished)


## Rebuild the navigation mesh. The bake runs on a worker thread, so this is
## cheap enough to call whenever the layout changes -- but only ONE bake may be
## in flight at a time, and Godot does not queue the second request. It refuses
## it outright ("NavigationMesh is already baking. Wait for current bake to
## finish.") and throws it away.
##
## That dropped bake is how Mass Wing D stayed sealed to the Curator. unlock_wing()
## rebakes, and GameManager opens every wing the save has already earned in a
## single frame -- `for n in range(2, _night + 1): _unlock_for_night(n)` in its
## _ready(). On a night-3 resume that is two unlocks back to back: the first
## started a bake, the second hit the refusal, and the museum went on running a
## navmesh in which the Wing D blast door was still standing. The antagonist
## could not path into the room the game's climax happens in, and nothing said
## so. The same race also exists between the build-time bake and the first
## unlock, which can land in the very next frames.
##
## So a request that cannot run now is remembered and re-issued from
## bake_finished. One flag rather than a counter: a bake always reads the CURRENT
## scene, so however many unlocks land during one bake, one more bake afterwards
## satisfies all of them.
func _bake_navigation() -> void:
	if not is_instance_valid(_nav_region) or not _nav_region.is_inside_tree():
		return
	if _nav_region.is_baking():
		_nav_rebake_queued = true
		# The watchdog below now carries this. The reviewer measured a 1-in-3
		# loss here: a rebake request can land in a window where the signal it
		# waits on has already been emitted (worker done, result still
		# applying), leaving the flag set with nothing left to serve it -- the
		# mesh that stays on the server is one baked with a blast door still
		# standing, and only a manual extra bake repairs it. The window is
		# machine-timing dependent: it does not reproduce on every box, which is
		# exactly why the fix cannot rely on the bake_finished signal alone.
		return
	_nav_rebake_queued = false
	_nav_region.bake_navigation_mesh(true)


func _on_nav_bake_finished() -> void:
	if not _nav_rebake_queued:
		return
	# Deferred rather than immediate: bake_finished is emitted while the region is
	# still applying the result it just finished, and starting the next bake from
	# inside the handler re-enters that.
	call_deferred("_bake_navigation")


## Safety net under the bake_finished/deferred chain, called from _process():
## if a rebake is owed and the oven is free, start it. The signal path is the
## fast path and covers the common case; this covers any window that orphans
## the flag (see _bake_navigation). Cost when nothing is owed is one boolean
## check per frame, and every branch re-checks is_baking() before starting,
## so it can never double up with the deferred call -- whichever path gets
## there first clears the flag and the other stands down.
func _nav_watchdog() -> void:
	if not _nav_rebake_queued:
		return
	if not is_instance_valid(_nav_region) or not _nav_region.is_inside_tree():
		_nav_rebake_queued = false
		return
	if _nav_region.is_baking():
		return
	_nav_rebake_queued = false
	_nav_region.bake_navigation_mesh(true)


func _add_player_spawn(parent: Node) -> void:
	var spawn := Marker3D.new()
	spawn.name = "Player Spawn - Street"
	spawn.position = Vector3(0, 1.0, 46)
	parent.add_child(spawn)

	# The game opens on the street in daylight; the player walks in through
	# the main entrance, facing the museum (-z).
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.05, 46)
	player.rotation_degrees = Vector3(0, 0, 0)

	var collision_shape := CapsuleShape3D.new()
	collision_shape.radius = 0.35
	collision_shape.height = 1.8

	var collision := CollisionShape3D.new()
	collision.name = "Player Collision"
	collision.position = Vector3(0, 0.9, 0)
	collision.shape = collision_shape
	player.add_child(collision)

	var camera := Camera3D.new()
	camera.name = "Player Camera"
	camera.position = Vector3(0, 1.65, 0)
	camera.fov = 72.0
	camera.current = true
	player.add_child(camera)

	var flashlight := SpotLight3D.new()
	flashlight.name = "Player Flashlight"
	# Camera child: the beam follows both player yaw and camera pitch, so it
	# illuminates the point under the crosshair instead of staying horizontal.
	flashlight.position = Vector3(0.12, -0.10, -0.08)
	flashlight.rotation_degrees = Vector3.ZERO
	flashlight.light_energy = 2.4
	flashlight.spot_range = 20.0
	flashlight.spot_angle = 36.0
	flashlight.spot_angle_attenuation = 1.6
	flashlight.light_color = Color(0.95, 0.92, 0.82)
	flashlight.shadow_enabled = true
	camera.add_child(flashlight)

	# Attach the script last so PlayerController._ready() finds its children
	# ("Player Camera") already present under the Player node.
	player.script = load("res://game/PlayerController.gd")
	var scale_controller := Node.new()
	scale_controller.name = "Player Scale Controller"
	scale_controller.script = load("res://game/PlayerScaleController.gd")
	player.add_child(scale_controller)
	parent.add_child(player)

	var debug_camera := Camera3D.new()
	debug_camera.name = "Preview Camera"
	debug_camera.position = Vector3(-16, 17, 48)
	debug_camera.rotation_degrees = Vector3(-58, -20, 0)
	debug_camera.current = false
	parent.add_child(debug_camera)

# ===== MapLighting.gd =====
# Lighting layer: world environment (day sky, fog), room lights and the
# office blackout sequence.
# Inheritance chain:
#   FirstMuseumMap < MapIntro < MapDecor < MapLighting
#     < MapStructure < MapPrimitives < Node3D
# Every module sees the constants, vars and helpers of the
# modules below it; call sites stay unchanged.

var _office_light: OmniLight3D = null
var _emergency_light: OmniLight3D = null
var _night_entrance_door: MeshInstance3D = null

# Day -> night switch. _add_world_env / _add_room_lights fill these; the
# runtime flips them once via _trigger_blackout() when the player first
# steps into the office.
var _environment: Environment = null
var _sun: DirectionalLight3D = null
var _sun_shaft: SpotLight3D = null
var _powered_lights: Array = []
## Light3D nodes inside the LightProps emergency luminaires. Held invisible from
## the moment they are built and switched on in the same frame the mains die --
## see _add_light_fittings for why they are built lit and hidden rather than
## unlit. Kept separate from _powered_lights, which is the list the blackout
## switches OFF; these are the only fittings that move the other way.
var _emergency_fixtures: Array = []
var _blackout_done := false

# Exact footprint of the security office. Night begins only after the player
# has crossed the office doorway, not merely by walking west in another annex.
const OFFICE_NIGHT_MIN_X := -34.6
const OFFICE_NIGHT_MAX_X := -15.4
const OFFICE_NIGHT_MIN_Z := -6.6
const OFFICE_NIGHT_MAX_Z := 6.6


func _add_world_env(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.3
	_environment = env

	# Liminal depth: a faint fog that swallows the far ends of rooms.
	# Density 0.08 was near-opaque past ~15 m in Godot 4; 0.025 keeps the
	# far walls readable while still eating the corridors.
	# Off for the bright daytime intro; _trigger_blackout() turns it on.
	env.fog_enabled = false
	env.fog_light_color = Color(0.05, 0.05, 0.065)
	env.fog_light_energy = 0.6
	env.fog_density = 0.025

	# Volumetric fog makes the skylight moonbeam and the flashlight cone
	# visible as actual light shafts (Forward+ renderer only; harmlessly
	# ignored in Compatibility).
	env.volumetric_fog_enabled = false
	env.volumetric_fog_density = 0.022
	env.volumetric_fog_albedo = Color(0.62, 0.66, 0.78)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_gi_inject = 0.4

	env.glow_enabled = true
	env.glow_intensity = 0.28
	env.glow_strength = 0.62
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9

	# Grade: slightly desaturated, a touch more contrast -- dead-mall mood.
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.94
	env.adjustment_contrast = 1.08
	env.adjustment_brightness = 1.0

	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 1.5
	env.ssao_power = 1.2
	# Screen-space reflections and indirect light give polished floors and
	# exhibit cases depth without the cost of full realtime GI.
	env.ssr_enabled = true
	env.ssr_max_steps = 32
	env.ssr_fade_in = 0.12
	env.ssr_fade_out = 1.8
	env.ssr_depth_tolerance = 0.18
	env.ssil_enabled = true
	env.ssil_radius = 3.0
	env.ssil_intensity = 0.75
	env.ssil_sharpness = 0.9

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.28, 0.46, 0.80)
	sky_material.sky_horizon_color = Color(0.72, 0.80, 0.90)
	sky_material.ground_bottom_color = Color(0.22, 0.20, 0.16)
	sky_material.ground_horizon_color = Color(0.52, 0.50, 0.44)
	sky_material.sun_angle_max = 35.0
	sky_material.sun_curve = 0.2

	var sky := Sky.new()
	sky.sky_material = sky_material
	env.sky = sky

	var world_env := WorldEnvironment.new()
	world_env.name = "World Environment"
	world_env.environment = env
	parent.add_child(world_env)

	# Bright afternoon sun; _trigger_blackout() dims it to moonlight.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, 25, 0)
	sun.light_energy = 1.4
	sun.light_color = Color(1.0, 0.96, 0.86)
	sun.shadow_enabled = true
	sun.light_angular_distance = 1.0
	parent.add_child(sun)
	_sun = sun

	# Office fluorescent hum.
	var office_light := OmniLight3D.new()
	office_light.name = "Office Fluorescent Hum"
	office_light.position = Vector3(-25, 2.7, 0)
	office_light.light_energy = 1.7
	office_light.omni_range = 12.0
	office_light.light_color = Color(0.85, 0.9, 1.0)
	office_light.shadow_enabled = true
	parent.add_child(office_light)
	_office_light = office_light
	_powered_lights.append(office_light)
	_box(parent, "Office Fluorescent Tube", Vector3(-25, WALL_HEIGHT - 0.08, 0),
		Vector3(2.4, 0.07, 0.45), Color(0.82, 0.88, 0.95), 1.4)

	# Red atrium emergency light.
	var atrium_light := OmniLight3D.new()
	atrium_light.name = "Atrium Emergency Light"
	# Wall-mounted above the north doorway so it does not sit inside the
	# skylight moonbeam.
	atrium_light.position = Vector3(0, 2.95, -14.0)
	atrium_light.light_energy = 1.2
	atrium_light.omni_range = 24.0
	atrium_light.light_color = Color(0.95, 0.18, 0.12)
	atrium_light.shadow_enabled = true
	atrium_light.visible = false  # comes on at the blackout
	parent.add_child(atrium_light)
	_emergency_light = atrium_light
	_box(parent, "Atrium Emergency Lamp", Vector3(0, 3.05, -14.45),
		Vector3(0.45, 0.16, 0.35), Color(0.9, 0.12, 0.08), 2.0)

	# A narrow light shaft through the atrium ceiling: warm sun by day,
	# cold moonlight after the blackout.
	var shaft := SpotLight3D.new()
	shaft.name = "Skylight Beam"
	shaft.position = Vector3(0, WALL_HEIGHT - 0.12, 0)
	# -90 aims the cone down at the floor. The old +90 pointed it up into
	# the sky from above the ceiling, so the beam never lit anything.
	shaft.rotation_degrees = Vector3(-90, 0, 0)
	shaft.light_energy = 3.0
	shaft.spot_range = WALL_HEIGHT + 1.0
	# 24 degrees gave a cone only 1.39 m across at the floor, and the containment
	# core's 0.66 m column now stands inside it: the beam would have landed on the
	# core's own shoulder and thrown a hard radial shadow instead of a pool. 40
	# opens it to ~2.5 m at the floor, so the light falls as a ring around the
	# 2.05 m dais and the column is lit rather than silhouetted by it.
	shaft.spot_angle = 40.0
	shaft.light_color = Color(0.98, 0.93, 0.78)
	shaft.shadow_enabled = true
	parent.add_child(shaft)
	_sun_shaft = shaft

	# Faintly glowing skylight glass so the beam has a visible source.
	_box(parent, "Atrium Skylight Glass", Vector3(0, WALL_HEIGHT - 0.02, 0),
		Vector3(3.4, 0.05, 3.4), Color(0.45, 0.52, 0.72), 1.1)


func _add_room_lights(parent: Node) -> void:
	# Dim practical lights so the wings stay readable now that the
	# moonlight casts real shadows and no longer leaks through ceilings.
	# Each light gets a small emissive tube so the source is visible.
	var fixtures := [
		["Entrance Zone Ceiling Light", Vector3(0, 0, 25), Color(0.72, 0.74, 0.66), 0.75, 13.0, true],
		["Gravity Wing Ceiling Light", Vector3(28, 0, 0), Color(0.55, 0.62, 0.85), 0.7, 13.0, true],
		["Time Wing Ceiling Light", Vector3(0, 0, -24), Color(0.9, 0.68, 0.45), 0.7, 13.0, true],
		["Storage Ceiling Light", Vector3(-25, 0, 12), Color(0.68, 0.68, 0.6), 0.5, 9.0, false],
		["Archive Ceiling Light", Vector3(-25, 0, -12), Color(0.64, 0.68, 0.6), 0.5, 9.0, false],
		["Planetarium Ceiling Light", Vector3(0, 0, -41), Color(0.45, 0.52, 0.9), 0.45, 11.0, false],
		["Restoration Lab Ceiling Light", Vector3(-25, 0, 22), Color(0.78, 0.72, 0.6), 0.55, 9.0, false],
	]
	for f in fixtures:
		var light := OmniLight3D.new()
		light.name = f[0]
		light.position = Vector3(f[1].x, WALL_HEIGHT - 0.35, f[1].z)
		light.light_color = f[2]
		light.light_energy = f[3]
		light.omni_range = f[4]
		light.shadow_enabled = f[5]
		parent.add_child(light)
		_powered_lights.append(light)
		_box(parent, "%s Tube" % f[0],
			Vector3(f[1].x, WALL_HEIGHT - 0.08, f[1].z),
			Vector3(1.8, 0.07, 0.4), f[2], 1.1)


## Names that must never join _powered_lights. The sun and its shaft are dimmed
## by hand, the atrium lamp is the light the blackout brings UP rather than down,
## and the flashlight belongs to the player.
const BLACKOUT_EXEMPT_LIGHTS := ["Sun", "Skylight Beam", "Atrium Emergency Light",
		"Player Flashlight", "Cam Floodlight"]
const EMERGENCY_LAMP_NAME := "Emergency Lamp"


## Adopt the lighting when the layout came out of the saved scene.
##
## build_map() registers every fixture as it creates it, so the blackout has a
## list to switch off. A layout serialized into FirstMuseumMap.tscn skips
## build_map() entirely: the lamps are real nodes in the scene, but every handle
## this script keeps on them is still empty or null. The blackout then fired and
## switched off nothing -- measured: 0 registered lights, five still burning in
## the office, which is exactly what the player saw walking in. This walks the
## saved tree once and takes ownership of what is already there.
func _adopt_serialized_lighting() -> void:
	var generated := get_node_or_null("GeneratedMap")
	if generated == null:
		return
	var env := generated.get_node_or_null("World Environment") as WorldEnvironment
	if env != null:
		_environment = env.environment
	_sun = generated.get_node_or_null("Sun") as DirectionalLight3D
	_sun_shaft = generated.get_node_or_null("Skylight Beam") as SpotLight3D
	_emergency_light = generated.get_node_or_null("Atrium Emergency Light") as OmniLight3D
	_office_light = generated.get_node_or_null("Office Fluorescent Hum") as OmniLight3D
	_night_entrance_door = generated.get_node_or_null(
			"Ночная дверь главного входа") as MeshInstance3D
	_collect_serialized_lights(generated)


## Sort every Light3D in the saved tree into mains or battery-backed. Duplicate
## siblings arrive under engine names like @SpotLight3D@20663, so the sort is by
## exemption rather than by a whitelist of expected names.
func _collect_serialized_lights(node: Node) -> void:
	var light := node as Light3D
	if light != null:
		var light_name := str(light.name)
		if light_name.begins_with(EMERGENCY_LAMP_NAME):
			light.visible = false
			_emergency_fixtures.append(light)
		elif not BLACKOUT_EXEMPT_LIGHTS.has(light_name):
			_powered_lights.append(light)
	for child in node.get_children():
		_collect_serialized_lights(child)


## Take the glow out of the office ceiling tube once the mains are down. The
## material is duplicated first: lamp materials are cached and shared, so
## editing in place would darken fittings in rooms that never lost power.
func _dim_office_tube() -> void:
	var generated := get_node_or_null("GeneratedMap")
	if generated == null:
		return
	var tube := generated.get_node_or_null("Office Fluorescent Tube") as MeshInstance3D
	if tube == null:
		return
	var mat := tube.material_override as StandardMaterial3D
	if mat == null and tube.mesh != null and tube.mesh.get_surface_count() > 0:
		mat = tube.mesh.surface_get_material(0) as StandardMaterial3D
	if mat == null:
		return
	var dark := mat.duplicate() as StandardMaterial3D
	dark.emission_enabled = false
	dark.emission_energy_multiplier = 0.0
	tube.material_override = dark


func _check_blackout() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		# The group is registered in PlayerController._ready(). This fallback
		# covers the first frame if scene initialization order changes.
		player = get_node_or_null("GeneratedMap/Player") as Node3D
	if player == null:
		return
	var p := player.global_position
	# The trigger matches the physical Watcher Office bounds exactly. Entering
	# Storage or Archive no longer causes an accidental daytime-to-night shift.
	if p.x > OFFICE_NIGHT_MIN_X and p.x < OFFICE_NIGHT_MAX_X \
			and p.z > OFFICE_NIGHT_MIN_Z and p.z < OFFICE_NIGHT_MAX_Z:
		_trigger_blackout()


func _trigger_blackout() -> void:
	if _blackout_done:
		return
	_blackout_done = true
	# Sound: power-down thud, then the night ambience takes over.
	var am := get_tree().get_first_node_in_group("audio_manager")
	if am != null:
		if am.has_method("play_sfx"):
			# These two fire together on Master, so positive gain on samples that
			# already sit near full scale drives the sum into clipping. Unity for
			# the blackout hit and -3 dB for the power-down keeps the original
			# 3 dB spread between them with no boost at all.
			am.play_sfx("blackout", 0.0)
			am.play_sfx("power_down", -3.0)
	if is_instance_valid(_night_entrance_door):
		create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).tween_property(_night_entrance_door,"position:y",1.50,1.15)
		if am!=null and am.has_method("play_at"):am.play_at("door_lock",Vector3(0,1.4,34.2),-2.0)
	if am!=null and am.has_method("set_ambience"):
		am.set_ambience("night")
	# Cut mains power everywhere.
	for l in _powered_lights:
		if is_instance_valid(l):
			l.visible = false
	# Switching a Light3D off leaves its housing glowing: the office tube is an
	# emissive mesh in its own right, measured still at emission 1.40 with the
	# lamp already dark. Way-out signage keeps its glow on purpose (see the note
	# above _add_service_fittings); this is only the mains fitting.
	_dim_office_tube()
	# Make the transition unmistakably nighttime: the daylight sun is almost
	# fully extinguished, while a restrained cold moonbeam remains at the atrium.
	if is_instance_valid(_sun):
		_sun.light_energy = 0.10
		_sun.light_color = Color(0.38, 0.46, 0.68)
	if is_instance_valid(_sun_shaft):
		_sun_shaft.light_energy = 0.65
		_sun_shaft.light_color = Color(0.42, 0.50, 0.78)
	# Red emergency light comes up and starts pulsing (see _process).
	if is_instance_valid(_emergency_light):
		_emergency_light.visible = true
	# The battery-backed luminaires come up with it. These do NOT pulse: the
	# single pulsing source in the museum is the atrium lamp above, and six more
	# throbbing red lights would be both worse to look at and worse to read a
	# room by. Their housings have been on the walls, dark, since the map built.
	for unit in _emergency_fixtures:
		if is_instance_valid(unit):
			unit.visible = true
	# Night sky + creeping fog.
	if _environment != null:
		_environment.ambient_light_energy = 0.18
		_environment.fog_enabled = true
		var settings := get_tree().get_first_node_in_group("settings_manager")
		_environment.volumetric_fog_enabled = settings == null or settings.allow_volumetric_fog()
		_environment.adjustment_saturation = 0.72
		_environment.adjustment_brightness = 0.86
		var sky_mat := _environment.sky.sky_material as ProceduralSkyMaterial
		if sky_mat != null:
			sky_mat.sky_top_color = Color(0.02, 0.025, 0.04)
			sky_mat.sky_horizon_color = Color(0.05, 0.05, 0.07)
			sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.015)
			sky_mat.ground_horizon_color = Color(0.04, 0.04, 0.05)

# ===== MapDecor.gd =====
# Decoration layer: exhibits, furnishings, room details, street props
# and the containment dome force-field shader hookup.
# Inheritance chain:
#   FirstMuseumMap < MapIntro < MapDecor < MapLighting
#     < MapStructure < MapPrimitives < Node3D
# Every module sees the constants, vars and helpers of the
# modules below it; call sites stay unchanged.


func _add_atrium_landmarks(parent: Node) -> void:
	# Новая ротонда: свободные оси к четырём крыльям, без мебели в проходах.
	_cylinder(parent,"Кольцо ротонды",Vector3(0,.08,0),5.8,.16,Color(.16,.17,.18))
	_cylinder(parent,"Пол ротонды",Vector3(0,.11,0),4.9,.10,Color(.72,.72,.69))
	for p:Vector3 in [Vector3(-11.5,0,-11.5),Vector3(11.5,0,-11.5),Vector3(-11.5,0,11.5),Vector3(11.5,0,11.5)]:
		_cylinder(parent,"Колонна ротонды %s" % [p],p+Vector3(0,WALL_HEIGHT*.5,0),.42,WALL_HEIGHT,Color(.16,.16,.155))
	# 45, 135, 225, 315 rather than the cardinals. On the axes these four benches
	# sat squarely on the circulation line between every opposing pair of
	# doorways -- Entrance to Time Wing and Office to Gravity Wing both ran
	# straight through one. The room is 30 m wide so they never blocked the bake,
	# but they were furniture parked in the middle of the main routes, and the
	# diagonals put them between the axes where a bench belongs.
	# Each of these was one 2.5 x 0.55 x 0.68 slab with rotation_degrees.y set to
	# -angle. That yaw puts the LONG axis on the radius, so all four pointed at
	# the core end-on: from anywhere in the room they read as blocks of stone
	# aimed at nothing, and they seated two. Yaw -(angle + 90) turns the long
	# axis onto the tangent, and the back goes on the outward side, so the seat
	# faces the core -- which is the one thing in this room worth sitting to look
	# at. Same 3.4 x 0.72 four-seater as the forecourt benches, built from the
	# same parts, with the angle in every node name: two nodes sharing a name
	# under one parent get the second one renamed to @MeshInstance3D@NNN by
	# Godot, and this loop used to produce four "Скамья ротонды" in a row.
	for angle:float in [45.0,135.0,225.0,315.0]:
		var r:=deg_to_rad(angle)
		var radial:=Vector3(cos(r),0,sin(r))
		var tangent:=Vector3(-sin(r),0,cos(r))
		var base:=radial*8.4
		var yaw:=-(angle+90.0)
		var tag:="%d" % int(angle)
		var seat:=_box(parent,"Скамья ротонды %s" % tag,base+Vector3(0,.45,0),Vector3(3.4,.14,.72),Color(.19,.16,.13))
		seat.rotation_degrees.y=yaw
		var back:=_box(parent,"Спинка скамьи ротонды %s" % tag,base+radial*.30+Vector3(0,.84,0),Vector3(3.4,.58,.09),Color(.19,.16,.13))
		back.rotation_degrees.y=yaw
		for side:float in [-1.0,1.0]:
			var end_tag:String = "%s%s" % [tag, "A" if side<0.0 else "B"]
			var e:=base+tangent*(side*1.55)
			var leg:=_box(parent,"Ножка скамьи ротонды %s" % end_tag,e+Vector3(0,.19,0),Vector3(.12,.38,.66),Color(.16,.14,.12))
			leg.rotation_degrees.y=yaw
			var post:=_box(parent,"Стойка скамьи ротонды %s" % end_tag,e+radial*.30+Vector3(0,.82,0),Vector3(.10,.62,.09),Color(.16,.14,.12))
			post.rotation_degrees.y=yaw
	_add_label(parent,tr("EXHIBIT_CONTAINMENT_CORE"),Vector3(0,3.0,4.8),Color(.34,.72,.62))


func _add_atrium_decor(parent: Node) -> void:
	_box(parent,"Ось север-юг",Vector3(0,.015,0),Vector3(.10,.025,27),Color(.38,.31,.16),.2,.5,false)
	_box(parent,"Ось запад-восток",Vector3(0,.016,0),Vector3(27,.025,.10),Color(.38,.31,.16),.2,.5,false)
	for p:Vector3 in [Vector3(-10.8,0,10.8),Vector3(10.8,0,10.8)]:_add_plant(parent,p)
	_add_atrium_power_panel(parent)


## The museum's main distribution board, on the Atrium's south wall in the
## south-east corner. It exists so CAM 08 has a subject: that feed aims at
## Vector3(12.5, 1.2, 14.4) and used to find nothing there but floor. The
## interior face of the south wall is at z = 14.65 (centre 14.825, thickness
## 0.35), so a 0.22-deep cabinet sits flush against it with its door at 14.43 --
## 3 cm behind the aim point, which puts the door in the middle of the frame.
##
## It is also the one prop in the Atrium the night shift has a reason to watch,
## since the game opens by cutting the museum's power the moment the player
## reaches the office.
func _add_atrium_power_panel(parent: Node) -> void:
	var steel := Color(0.30, 0.32, 0.34)
	var dark := Color(0.10, 0.11, 0.12)
	_box(parent, "Atrium Distribution Board", Vector3(12.5, 1.45, 14.54),
		Vector3(0.94, 1.30, 0.22), steel, 0.0, 0.55)
	_box(parent, "Atrium Distribution Board Door", Vector3(12.5, 1.45, 14.41),
		Vector3(0.86, 1.20, 0.05), steel.darkened(0.18), 0.0, 0.6, false)
	_box(parent, "Atrium Distribution Board Handle", Vector3(12.86, 1.45, 14.36),
		Vector3(0.05, 0.24, 0.05), Color(0.55, 0.52, 0.44), 0.0, 0.7, false)
	# Three indicator lamps: the only moving-looking thing in this feed, and the
	# reason the shot reads as a live camera rather than a photograph of a wall.
	var lamps := [Color(0.35, 0.95, 0.45), Color(0.95, 0.72, 0.2), Color(0.9, 0.15, 0.12)]
	for i in range(lamps.size()):
		_box(parent, "Atrium Distribution Lamp %d" % i,
			Vector3(12.16 + float(i) * 0.16, 1.92, 14.37),
			Vector3(0.06, 0.06, 0.03), lamps[i], 2.2, 0.0, false)
	# Conduit up to the ceiling tray, so the board is fed from somewhere.
	_box(parent, "Atrium Distribution Conduit", Vector3(12.5, 2.72, 14.58),
		Vector3(0.12, 1.24, 0.12), dark, 0.0, 0.4, false)
	# Keep-clear hatching on the floor in front of the doors.
	_box(parent, "Atrium Distribution Keep Clear", Vector3(12.5, 0.014, 13.95),
		Vector3(1.3, 0.02, 0.9), Color(0.62, 0.52, 0.16), 0.12, 0.0, false)


func _add_entrance_details(parent: Node) -> void:
	# Последовательность: внешний портал, тамбур, свободное фойе.
	# Портал — два пилона и перемычка: центральный проход всегда свободен днём.
	_box(parent,"Пилон входа — запад",Vector3(-3.7,1.65,34.45),Vector3(2.2,3.3,.34),Color(.20,.21,.22))
	_box(parent,"Пилон входа — восток",Vector3(3.7,1.65,34.45),Vector3(2.2,3.3,.34),Color(.20,.21,.22))
	_box(parent,"Перемычка входа",Vector3(0,3.12,34.45),Vector3(9.6,.42,.34),Color(.20,.21,.22))
	for x:float in [-2.75,2.75]:_glass_case(parent,"Стена тамбура %s" % ("запад" if x < 0.0 else "восток"),Vector3(x,1.45,31.9),Vector3(.10,2.9,4.8))
	_box(parent,"Козырёк тамбура",Vector3(0,3.05,32),Vector3(5.6,.18,5),Color(.12,.13,.14),0,.45)
	_box(parent,"Ковёр тамбура",Vector3(0,.02,32),Vector3(4.6,.03,3.4),Color(.24,.07,.065),0,0,false)
	_box(parent,"Стойка приёма",Vector3(-7.2,.58,25.5),Vector3(5.4,1.16,1.25),Color(.18,.14,.10))
	_box(parent,"Столешница приёма",Vector3(-7.2,1.19,25.5),Vector3(5.7,.08,1.45),Color(.10,.085,.07),0,.3)
	_add_label(parent,tr("EXHIBIT_RECEPTION"),Vector3(-7.2,2.4,25.5),Color(.68,.64,.48))
	_box(parent,"Шкафчики посетителей",Vector3(10.2,1.15,20),Vector3(1,2.3,4.8),Color(.16,.17,.18),0,.5)
	_add_label(parent,tr("EXHIBIT_CLOAKROOM"),Vector3(8.3,2.75,24.8),Color(.54,.70,.72))
	_night_entrance_door=_box(parent,"Ночная дверь главного входа",Vector3(0,4.85,34.2),Vector3(5.6,3.05,.22),Color(.055,.06,.065),0,.75)
	_add_label(parent,tr("EXHIBIT_MAIN_ENTRANCE"),Vector3(0,3.18,34),Color(.42,.64,.54))


func _add_office_details(parent: Node) -> void:
	# Security office rebuilt as a believable fixed CCTV workstation.
	_box(parent, "Office Acoustic Floor", Vector3(-25, 0.015, 0),
		Vector3(16.5, 0.03, 10.8), Color(0.055, 0.065, 0.068), 0.0, 0.0, false)
	_box(parent, "Office Rug", Vector3(-25, 0.035, 0.4),
		Vector3(7.0, 0.025, 4.6), Color(0.08, 0.10, 0.11), 0.0, 0.0, false)

	# The workstation -- monitor bank, desk, chair, key cabinet, roster wall,
	# kettle, mug rings, dead plant and the tablet's charging dock -- is
	# OfficeProps.build_watcher_office(). What stood here before was a 6.2 m desk
	# whose top was at y 1.09 (bar height) carrying six "monitors" 1.92 m wide;
	# those two numbers were why the room read wrong at every scale. The library
	# builds to furniture dimensions: work surface 0.74, monitors 0.52 x 0.40.
	#
	# ORIGIN. (-25, 0, -2.4) is the base of the monitor wall, +Z into the room,
	# which is the frame the builder documents. It puts the bank's top face at
	# 2.02 m -- the height the prologue's seventh shot and GameManager's closing
	# shot both aim at, (-25, 2.05, -2.2) -- and leaves its four colliders'
	# 4.36 x 2.58 m navmesh hole 4.6 m from the Archive door at (-25, -7), 7.7 m
	# from the Storage door at (-25, 7) and 8.7 m from the Atrium door at (-15, 0).
	#
	# The removed "CCTV Control Console" was not a dependency: SecurityCameraTablet
	# gates opening on _player_is_in_office(), a bounding-box test on the room, not
	# on any node. Its "CCTV ACCESS — TAB / Y" plate went with it, and that is a
	# small win on its own -- it was a raw English literal with no catalogue row,
	# so it never spoke Russian. The dock the library builds into the desk is the
	# same affordance stated as an object rather than as a caption.
	#
	# Both label slots are passed "": the two keys they want are not in
	# localization/game.csv and that file belongs to another agent this round.
	# Given "", each builder still builds the physical cabinet and the physical
	# roster board and simply hangs no Label3D on them, which is a complete
	# object either way.
	# THE PAPERWORK NEEDS A WALL TO BE ON.
	#
	# build_key_cabinet() and build_document_wall() both document their local
	# frame as "z = 0 the wall face", and the workstation mounts them at local
	# z 0.02 -- world z -2.38. The nearest real wall is the office's north face at
	# z -6.65, i.e. 4.27 m behind them, so the rails, the roster and fifteen sheets
	# hung in mid-air beside the monitors, which is exactly how they read in game.
	#
	# The fix is the missing object, not a move: a partition behind the desk, its
	# front face at z -2.40, 2 cm behind the paper. It is built as TWO panels with
	# a 1.40 m gap on x -25 rather than one 4.4 m slab, because the Archive door is
	# at (-25, -7) directly behind this line and a solid partition would make every
	# trip to it a detour around the room.
	for panel in [
		{"name": "Office Partition West", "x": -26.35, "w": 1.30},
		{"name": "Office Partition East", "x": -23.45, "w": 1.70},
	]:
		var px: float = panel["x"]
		var pw: float = panel["w"]
		_box(parent, panel["name"], Vector3(px, 1.25, -2.46),
			Vector3(pw, 2.50, 0.12), Color(0.145, 0.155, 0.165), 0.0, 0.15)
		_box(parent, "%s Cap" % panel["name"], Vector3(px, 2.53, -2.46),
			Vector3(pw + 0.08, 0.06, 0.18), Color(0.28, 0.30, 0.32), 0.0, 0.6,
			false)

	# Crouch cover. An audit of every solid box in the office found NOT ONE whose
	# top sits between a crouched head (0.96) and a standing one (1.66): the two
	# partitions above are 2.50 m and hide the player standing, the alarm pedestal
	# is 1.45 m wide and hides a shoulder. So crouching in the room the stealth kit
	# was built for changed nothing. This credenza tops out at 1.15 -- crouch and
	# the Curator's line from its 2.12 m eye breaks, stand and it does not. It stays
	# near the south wall but leaves the doorway's 0.75 m visual-clearance gate.
	_box(parent, "Office Records Credenza", Vector3(-25.0, 0.575, 5.90),
		Vector3(2.60, 1.15, 0.52), Color(0.165, 0.175, 0.185), 0.0, 0.2)
	_box(parent, "Office Records Credenza Lid", Vector3(-25.0, 1.165, 5.90),
		Vector3(2.68, 0.03, 0.56), Color(0.28, 0.30, 0.32), 0.0, 0.5, false)

	OfficeProps.build_watcher_office(parent as Node3D, Vector3(-25, 0, -2.4),
		0.0, "", "")

	# 10.3. The bank the library just built is six housings with dark glass in
	# them; game/MonitorWall.gd is what puts pictures on five of them. It is a
	# separate node rather than more code in OfficeProps because the pictures come
	# from SecurityCameraTablet's feeds -- the SAME textures the handheld shows,
	# borrowed through feed_texture()/release_feed() -- and a static prop builder
	# has no business holding a live rendering budget. It finds the bank by group
	# and the tablet off the scene root, so this line is the whole wiring.
	#
	# The script is INSTANTIATED, not attached to a bare Node3D: set_script() on
	# an existing node leaves the node's per-frame callback flags as they were
	# built, so _ready() ran and _process() never did -- the wall joined its group
	# and then sat there with no bank, no tablet and no pictures. Measured, not
	# assumed: a probe printed _built=false with all three references null.
	var wall_script := load("res://game/MonitorWall.gd") as GDScript
	var monitor_wall := wall_script.new() as Node3D
	monitor_wall.name = "MonitorWall"
	parent.add_child(monitor_wall)

	# Alarm console. It used to stand at (-29, .., 3.1): 3.55 m off the south wall
	# and 6.9 m from the desk, i.e. an island in the middle of a 13 x 13 m room,
	# facing nothing. Measured free floor put it here instead, 3.2 m west of the
	# monitor bank on the same line as the desk, so it reads as the left end of the
	# operator's workstation and is a glance away from the feeds. GameManager's
	# TERMINAL_POS and the head it builds follow these coordinates.
	_box(parent, "Alarm Terminal Pedestal", Vector3(-28.2, 0.55, -2.38),
		Vector3(1.65, 1.1, 0.95), Color(0.075, 0.055, 0.052), 0.0, 0.4)
	_box(parent, "Alarm Terminal", Vector3(-28.2, 1.18, -2.38),
		Vector3(1.45, 0.22, 0.72), Color(0.18, 0.025, 0.02), 0.65, 0.2)
	_box(parent, "Alarm Emergency Button", Vector3(-27.65, 1.34, -2.38),
		Vector3(0.16, 0.10, 0.16), Color(0.95, 0.05, 0.03), 1.5, 0.0, false)

	# Server and power wall.
	for rack_index in range(2):
		var rack_z := -4.8 + float(rack_index) * 2.15
		_box(parent, "Server Rack %d" % rack_index, Vector3(-33.65, 1.25, rack_z),
			Vector3(1.05, 2.5, 1.65), Color(0.035, 0.04, 0.045), 0.0, 0.65)
		for unit in range(7):
			var unit_y := 0.36 + float(unit) * 0.28
			_box(parent, "Server Unit %d-%d" % [rack_index, unit],
				Vector3(-33.10, unit_y, rack_z), Vector3(0.035, 0.19, 1.35),
				Color(0.08, 0.085, 0.09), 0.0, 0.4, false)
			_box(parent, "Server LED %d-%d" % [rack_index, unit],
				Vector3(-33.075, unit_y, rack_z - 0.48), Vector3(0.018, 0.035, 0.035),
				Color(0.12, 0.85 if unit % 3 else 0.25, 0.28), 0.8, 0.0, false)

	# Stabilization locker and equipment shelving.
	_box(parent, "Stabilization Locker", Vector3(-34.05, 1.25, 4.45),
		Vector3(1.35, 2.5, 3.0), Color(0.075, 0.095, 0.09), 0.0, 0.45)
	for shelf_y in [0.55, 1.15, 1.75, 2.35]:
		_box(parent, "Locker Shelf %s" % [shelf_y], Vector3(-33.35, shelf_y, 4.45),
			Vector3(0.045, 0.07, 2.65), Color(0.14, 0.16, 0.15), 0.0, 0.5, false)
	_add_label(parent, "STABILIZATION / AUTHORIZED STAFF", Vector3(-33.2, 2.85, 4.45),
		Color(0.55, 0.88, 0.66))

	# Shift documentation area on the east wall.
	_box(parent, "Incident Board", Vector3(-15.55, 1.75, 3.5),
		Vector3(0.08, 1.85, 4.4), Color(0.12, 0.15, 0.14), 0.0, 0.1, false)
	for paper_index in range(6):
		var paper_y := 1.25 + float(floori(float(paper_index) / 3.0)) * 0.72
		var paper_z := 2.35 + float(paper_index % 3) * 1.05
		_box(parent, "Incident Report %d" % paper_index,
			Vector3(-15.49, paper_y, paper_z), Vector3(0.025, 0.48, 0.72),
			Color(0.72, 0.70, 0.62), 0.0, 0.0, false)

	# The phone, mug, shift log, radio, charger and printer all stood on the
	# 1.09 m slab that no longer exists, and the block-built swivel chair stood at
	# (-25, 0, 1.35) with a 0.62 m seat and no gas column. OfficeProps carries a
	# kettle, three coffee rings and a five-star task chair turned 24 degrees off
	# the desk, all measured off its own 0.74 m surface.
	#
	# The shift printer is the one thing not replaced in kind, and it is not
	# missed: it stood at (-28.35, 1.31, 2.25), on top of a desk return that was
	# 3.35 m from the monitor wall in a room whose operator never leaves the
	# monitors.

	# Cable trays and practical task lighting finish the room.
	_box(parent, "Office Cable Tray", Vector3(-25, 3.05, -2.25),
		Vector3(7.0, 0.10, 0.34), Color(0.055, 0.06, 0.065), 0.0, 0.6, false)
	for light_x in [-27.0, -23.0]:
		var task_light := SpotLight3D.new()
		task_light.name = "Office Task Light %s" % [light_x]
		task_light.position = Vector3(light_x, 2.9, -0.4)
		task_light.rotation_degrees = Vector3(-90, 0, 0)
		task_light.light_color = Color(0.72, 0.84, 0.92)
		task_light.light_energy = 0.85
		task_light.spot_range = 4.0
		task_light.spot_angle = 42.0
		task_light.shadow_enabled = true
		parent.add_child(task_light)
		_powered_lights.append(task_light)

## The fittings that make the building read as a building rather than as a set:
## way-out signage, extinguishers, a hose reel, ceiling hatches and cable trays.
##
## All of it hangs on the ROOM-SIDE WALL FACES computed the way the note in
## _add_model_archive describes. `origin` for a CorridorProps wall prop is where
## the prop meets the wall and local +Z leaves it, so each call is one yaw:
## on a wall the room lies +Z of, yaw 0; -Z, yaw 180; +X, yaw 90; -X, yaw -90.
##
## DOORWAYS. Only the extinguishers and the hose reel carry a collider at all
## (the bottle, 0.15 m square, and the hose coil). CorridorProps' own rule is
## that free-standing props belong at least 1.2 m from a doorway centre; the
## nearest one below is 3.4 m out.
##
## The way-out signs are the reason this function exists. They are lit by
## constant emission and are deliberately NOT registered in _powered_lights:
## battery-backed exit signage that survives the museum losing power is both
## correct and the one navigational aid the player must never lose -- and the
## game's whole first act is the power going out. Their meaning is carried by
## the running-figure pictogram and the arrow, never by the green.
func _add_service_fittings(parent: Node) -> void:
	var root := parent as Node3D
	# Way out, back to the Atrium and then to the street. Each sign hangs at
	# 2.25 m on the face of the wall its doorway is in, offset 2.6 m to one side,
	# with its arrow pointing back at the opening.
	CorridorProps.exit_sign(root, Vector3(-2.6, 2.25, -14.65), 0.0, 1)
	CorridorProps.exit_sign(root, Vector3(2.6, 2.25, 14.65), 180.0, 1)
	CorridorProps.exit_sign(root, Vector3(-14.65, 2.25, 2.6), 90.0, 1)
	CorridorProps.exit_sign(root, Vector3(14.65, 2.25, -2.6), -90.0, 1)
	CorridorProps.exit_sign(root, Vector3(2.6, 2.25, -15.35), 180.0, -1)
	CorridorProps.exit_sign(root, Vector3(15.35, 2.25, 2.6), 90.0, 1)
	CorridorProps.exit_sign(root, Vector3(-15.35, 2.25, -2.6), -90.0, 1)
	CorridorProps.exit_sign(root, Vector3(2.6, 2.25, 34.65), 180.0, -1)

	# Fire points. The bottle is the only collider and it reaches 0.19 m into the
	# room; every one of these is on a blank stretch of wall.
	CorridorProps.fire_extinguisher(root, Vector3(-4.2, 0, -14.65), 0.0)
	CorridorProps.fire_extinguisher(root, Vector3(-15.35, 0, 3.4), -90.0)
	CorridorProps.fire_extinguisher(root, Vector3(15.35, 0, -3.4), 90.0)
	CorridorProps.fire_extinguisher(root, Vector3(-4.2, 0, -15.35), 180.0)
	CorridorProps.fire_extinguisher(root, Vector3(-34.65, 0, 10.0), 90.0)
	# Somebody ran the hose out and never wound it back. Its tail lies 1.01 m to
	# local -X and 0.85 m into the room, so it wants a clear corner: this one is
	# on the Atrium's west wall 5 m north of the office doorway, and the tail
	# runs away from it.
	CorridorProps.fire_hose_reel(root, Vector3(-14.65, 0, -5.0), 90.0, true)

	# Ceiling hatches. No collider on any part, and at 45 degrees the leaf's
	# lowest edge is 2.75 m up -- clear of the player and of the Curator's 2.25 m
	# capsule -- so these are safe directly over circulation.
	CorridorProps.ceiling_hatch(root, Vector3(-8.0, CEILING_SOFFIT_Y, 6.0), 0.9, 38.0)
	CorridorProps.ceiling_hatch(root, Vector3(-25.0, CEILING_SOFFIT_Y, -10.0), 0.9, 0.0)
	CorridorProps.ceiling_hatch(root, Vector3(20.0, CEILING_SOFFIT_Y, 6.0), 0.9, 0.0)

	# Cable trays at 3.0 m, stopped short of every doorway: the doorway is
	# already full of the wall builder's lintel at 2.70-3.40 m. The Atrium run
	# spans x -14..-2 and the office run x -32..-18, both well clear of the
	# openings at x 0 and x -15.
	#
	# THE TRAY IS THE ONE PROP HERE THAT IS NOT ANCHORED ON ITS ORIGIN. Every
	# other CorridorProps wall prop puts its back plane on `origin`, so the
	# room-side face is the whole answer. cable_tray does not: its 0.36 m of
	# bracket depth is LOCAL TO ORIGIN AND CENTRED ON IT (rails at local z
	# +-0.135, brackets -0.18..+0.18), so the origin belongs half a bracket into
	# the room. These three used to sit at face + WALL_THICKNESS -- the depth read
	# as if it grew forward from the origin -- which left every bracket stopping
	# 0.17 m short of the wall it is bolted to, measured, on all three runs. Half
	# the bracket, 0.175 m, puts the back of it exactly on the face.
	CorridorProps.cable_tray(root, Vector3(-8.0, 3.0, -14.475), 12.0, 0.0, 3, 0.0)
	CorridorProps.cable_tray(root, Vector3(-25.0, 3.0, -6.475), 14.0, 0.0, 2, 0.9)
	CorridorProps.cable_tray(root, Vector3(28.0, 3.0, -8.475), 18.0, 0.0, 3, 0.0)

	# Louvred vents: 0.05 m of relief, no collider. The black behind the slats is
	# the point of them.
	CorridorProps.wall_vent(root, Vector3(-6.0, 2.35, -14.65), 0.0)
	CorridorProps.wall_vent(root, Vector3(30.0, 2.35, -8.65), 0.0)
	CorridorProps.wall_vent(root, Vector3(-34.65, 2.35, -13.5), 90.0)

	# Wear at the thresholds. Flat, unlit, deterministic quads with no collider.
	for seam: Vector3 in [Vector3(0, 0, 15), Vector3(-15, 0, 0), Vector3(15, 0, 0),
			Vector3(0, 0, -15), Vector3(-25, 0, 7), Vector3(-25, 0, -7)]:
		CorridorProps.floor_scuffs(root, seam + Vector3(0, 0, 1.25), 2.2, 4)
		CorridorProps.floor_scuffs(root, seam - Vector3(0, 0, 1.25), 2.2, 4)


## Light fittings, and the two lists the blackout drives them from.
##
## THE BLACKOUT IS THE POINT OF THE SPLIT. Everything on the museum's mains goes
## into _powered_lights, which _trigger_blackout() switches off wholesale the
## moment the player reaches the office. The emergency luminaires go into
## _emergency_fixtures instead and come up in the same frame the mains go down.
##
## They are built `lit` so their charge pips and lenses are emissive from the
## start -- which is what a charged emergency luminaire looks like in a lit
## building -- and only their Light3D is hidden until the blackout. Building them
## unlit instead would have left a dark lens casting light afterwards.
##
## MOTION. The three failing tubes are the only animated fittings in the museum
## and their flicker is diegetic: the containment core is losing the building.
## LightProps.attach_flicker (which failing_tube calls for itself) pins the
## fitting at a steady, unmodulated level for as long as
## SettingsManager.reduced_flashes is true, polling the flag continuously so the
## settings panel takes effect in both directions without a rebuild. Nothing else
## here moves at all.
func _add_light_fittings(parent: Node) -> void:
	var root := parent as Node3D
	var soffit := CEILING_SOFFIT_Y

	# Mains ceiling lighting over the circulation the player actually walks.
	for at: Vector3 in [Vector3(0, soffit, 9.0), Vector3(0, soffit, -9.0),
			Vector3(0, soffit, 29.0), Vector3(-19.0, soffit, 0.0),
			Vector3(0, soffit, -19.0)]:
		_powered_lights.append_array(
			LightProps.lights_of(LightProps.troffer(root, at)))

	# Exhibit rigs. Collider-free like everything in the library, so they cannot
	# stand between a camera and the row they light.
	for rig: Array in [[Vector3(28, soffit, -2.0), Vector3(28, 1.4, -4.5), 3],
			[Vector3(0, soffit, -25.0), Vector3(0, 1.4, -27.5), 3],
			[Vector3(24, soffit, -25.0), Vector3(24, 1.4, -27.5), 2]]:
		_powered_lights.append_array(LightProps.lights_of(
			LightProps.spot_rig(root, rig[0], rig[1], rig[2])))

	# Wall wash. Short throw on purpose: it proves the museum has lighting and
	# then declines to help, which is the feeling the wings are meant to carry.
	for at: Array in [[Vector3(-14.65, 2.5, -5.0), 270.0],
			[Vector3(14.65, 2.5, 5.0), 90.0],
			[Vector3(-10.65, 2.5, 28.0), 270.0]]:
		_powered_lights.append_array(LightProps.lights_of(
			LightProps.sconce(root, at[0], at[1])))

	# The three fittings that are already failing before the power goes.
	for at: Array in [[Vector3(-25, soffit, 11.0), 0.0, 14.0],
			[Vector3(-25, soffit, -13.5), 90.0, 0.0],
			[Vector3(24, soffit, -20.0), 0.0, 18.0]]:
		_powered_lights.append_array(LightProps.lights_of(
			LightProps.failing_tube(root, at[0], at[1], at[2])))

	# Battery-backed. Held dark until _trigger_blackout().
	for at: Array in [[Vector3(-3.5, 2.6, -14.65), 180.0],
			[Vector3(3.5, 2.6, 14.65), 0.0],
			[Vector3(-15.35, 2.6, -3.0), 90.0],
			[Vector3(15.35, 2.6, 3.0), 270.0],
			[Vector3(3.5, 2.6, -15.35), 0.0],
			[Vector3(3.5, 2.6, 34.65), 0.0]]:
		var unit := LightProps.emergency(root, at[0], at[1])
		for light in LightProps.lights_of(unit):
			light.visible = false
			_emergency_fixtures.append(light)


## Equipment Storage, dressed from the walls inward.
##
## THE ROOM IS NOT EMPTY WHEN THIS RUNS. GameManager._build_devices() puts four
## 6.8 x 1.25 m equipment benches in here at runtime -- x -34.15..-27.35 and
## -22.65..-15.85, z 8.575..9.825 and 14.375..15.625 -- carrying the twelve
## containment devices the player has to find against the clock. That leaves
## three clear bands: z 7.175..8.575 and z 15.625..16.825 against the end walls,
## and z 9.825..14.375 across the middle. Everything below lives in the middle
## band or is trim thin enough not to matter.
##
## The room is also the timed one, so legibility beats density: two numbered
## shelving bays with their floor markers, one hazard cabinet in the corner the
## benches do not reach, one tool board whose missing tools are painted
## silhouettes, and two hanging aisle signs. Nothing here is a fourth obstacle
## between the player and a device.
func _add_storage_props(parent: Node) -> void:
	var root := parent as Node3D
	# Bays face into the room off the side walls (west face x -34.65, east face
	# x -15.35), centred at z 12.1 so their 2.4 m width lands at z 10.9..13.3 --
	# inside the clear middle band, touching neither pair of benches. facing_deg
	# 90 turns local +Z to world +X, so the west bay looks east across the room.
	StorageProps.shelving_bay(root, Vector3(-34.65, 0, 12.1), 90.0, 1, 1,
		tr("PROP_STORAGE_BAY_SPARES"), PackedInt32Array([1, 2, 5, 9]))
	StorageProps.floor_bay_marker(root, Vector3(-34.65, 0, 12.1), 90.0, 1)
	StorageProps.shelving_bay(root, Vector3(-15.35, 0, 12.1), -90.0, 2, 13,
		tr("PROP_STORAGE_BAY_CONSUMABLES"), PackedInt32Array([13, 16, 17]))
	StorageProps.floor_bay_marker(root, Vector3(-15.35, 0, 12.1), -90.0, 2)
	# North-west corner, in the 1.4 m strip the benches stop short of.
	StorageProps.hazard_cabinet(root, Vector3(-34.0, 0, 7.35), 0.0,
		tr("PROP_STORAGE_HAZARD_PLACARD"), true)
	# Wall trim: 0.10 m deep and explicitly collider-free, so it costs the aisle
	# beside it nothing even though a bench stands 0.8 m in front of it.
	StorageProps.tool_board(root, Vector3(-20.5, 0, 7.35), 0.0,
		tr("PROP_STORAGE_TOOLBOARD_NOTICE"), PackedInt32Array([1, 3, 7]), 0.95)
	# Hung signs clear 2.38 m underneath -- above the player and above the
	# Curator's 2.2 m agent height -- but BELOW the 2.70 m door lintels, so all
	# three hang in the room and none crosses the doorways at (-25, 7) / (-25, 17).
	StorageProps.bay_sign(root, Vector3(-29.5, 0, 11.0), 90.0,
		tr("PROP_STORAGE_SIGN_DEVICES"), 1, 12)
	StorageProps.bay_sign(root, Vector3(-20.5, 0, 11.0), -90.0,
		tr("PROP_STORAGE_SIGN_CHARGING"), 13, 24)
	# Names the hand-tool station over the tool board below it. This is the third
	# of the three bay labels the catalogue carries for this room; without it
	# PROP_STORAGE_BAY_TOOLS sits in game.csv unused, and the station it names is
	# otherwise identified only by the shape of the tools missing from it.
	StorageProps.bay_sign(root, Vector3(-20.5, 0, 8.6), 0.0,
		tr("PROP_STORAGE_BAY_TOOLS"))
	_add_hide_spots(root)


## The two places the player can stop being visible (audit 16.6 п. 5).
##
## Storage: the 4.7 m gap between the two pairs of equipment benches (x
## -27.35..-22.65) is the one strip of this room that is clear from the south
## wall inwards. The locker stands against that wall with its back at z 7.05 and
## its door at z 8.05, and its 1.20 m width lands at x -27.20..-26.00 -- 0.15 m
## clear of the west bench and 0.10 m clear of the Office door gap at x
## -25.90..-24.10.
##
## Office: the west wall, in the one gap it has. Measured occupants of that wall
## are Server Rack 0 (z -5.62..-3.98), Server Rack 1 (z -3.48..-1.83), the
## bookcase in the north-west corner (z about -6.0) and the Stabilization Locker
## (z 2.95..5.95). That leaves z -1.83..2.95, and the locker takes the middle of
## it, turned -90 degrees so its depth runs along X and its width along Z:
## x -34.35..-33.35, z -0.10..1.10, with 1.7 m of clear wall either side.
##
## Two placements were measured and thrown away before this one, both caught by
## the gate rather than by eye:
##   * z -3.60..-2.40 walked into Server Rack 1 -- the sightline into the open
##     locker died on 'Server Rack 1 Collision' at (-33.13 1.57 -3.00);
##   * x -35.00..-34.00 buried the back of the shell in the wall, because the
##     west face here is not the usual x -34.65 but the Causality Wing E sealed
##     door standing proud of it at x -34.42.
## Hence x -33.85 as the origin: the back panel lands at -34.35, 0.07 m clear of
## that door, and the front face at -33.35.
##
## Both numbers are asserted by test_map_verification._verify_hide_spots(), which
## sweeps the player capsule inside each shell and fires a sight ray at it from
## outside: a locker nobody fits in, or one that does not stop the Curator's
## eye, is not a hiding place.
func _add_hide_spots(root: Node3D) -> void:
	HideSpot.build(root, "Storage Hide Locker", Vector3(-26.6, 0.0, 7.55), 180.0,
		tr("PROP_HIDE_LOCKER"))
	HideSpot.build(root, "Office Hide Locker", Vector3(-33.85, 0.0, 0.5), -90.0,
		tr("PROP_HIDE_LOCKER"))


func _add_exhibits(parent: Node) -> void:
	_add_exhibit(parent, "Falling Cube Exhibit", "falling_cube",
		Vector3(21.5, 0, -4.5), Color(0.18, 0.28, 0.48), "box", 0.4)
	_add_exhibit(parent, "Inversion Room Exhibit", "inversion_room",
		Vector3(28, 0, -4.5), Color(0.36, 0.22, 0.46), "box", 0.0)
	_add_exhibit(parent, "Levitating Column Exhibit", "levitating_column",
		Vector3(35.5, 0, -4.5), Color(0.45, 0.45, 0.38), "cylinder", 0.0)
	_add_label(parent, tr("EXHIBIT_WING_A_SIGN"),
		Vector3(28, 2.9, 8.4), Color(0.62, 0.76, 0.98))

	_add_exhibit(parent, "Broken Clock Exhibit", "broken_clock",
		Vector3(-8, 0, -27.5), Color(0.42, 0.28, 0.16), "box", 0.5)
	_add_exhibit(parent, "Frozen Drop Exhibit", "frozen_drop",
		Vector3(0, 0, -27.5), Color(0.22, 0.45, 0.58), "drop", 0.6)
	_add_exhibit(parent, "Time Loop Exhibit", "time_loop",
		Vector3(8, 0, -27.5), Color(0.50, 0.35, 0.25), "torus", 0.5)
	_add_label(parent, tr("EXHIBIT_WING_B_SIGN"),
		Vector3(0, 2.9, -17), Color(0.96, 0.72, 0.48))

	_add_exhibit(parent, "Portal Arch Exhibit", "portal_arch",
		Vector3(24, 0, -20.5), Color(0.18, 0.26, 0.36), "portal", 0.8)
	_add_exhibit(parent, "Star Globe Exhibit", "star_globe",
		Vector3(18.5, 0, -27.5), Color(0.30, 0.40, 0.75), "sphere", 0.7)
	_add_exhibit(parent, "Orrery Exhibit", "orrery",
		Vector3(29.5, 0, -27.5), Color(0.55, 0.50, 0.30), "torus", 0.5)
	_add_label(parent, tr("EXHIBIT_WING_C_SIGN"),
		Vector3(24, 2.9, -17), Color(0.55, 0.65, 0.95))

	_add_exhibit(parent, "Superheavy Sphere Exhibit", "superheavy_sphere",
		Vector3(52, 0, -3), Color(0.33, 0.27, 0.18), "heavy_sphere", 0.0)
	_add_exhibit(parent, "Dense Ingot Exhibit", "dense_ingot",
		Vector3(46.5, 0, 4), Color(0.45, 0.42, 0.38), "box", 0.2)
	_add_exhibit(parent, "Mass Pendulum Exhibit", "mass_pendulum",
		Vector3(58, 0, 4), Color(0.35, 0.30, 0.40), "drop", 0.3)
	# Reinforced containment fixtures make Mass Wing D read as heavy physics,
	# not a loose collection of spheres. The pendulum's own A-frame and crossbar
	# used to be built here, at x 56.8 / 59.2; MassProps.build_mass_pendulum
	# carries columns at 56.7 / 59.3 and would have stood a second frame 0.1 m
	# inside the first, so those three boxes are gone. The containment ring
	# stays: the sphere's 3.27 m footprint reaches z -4.64..-1.37 and the ring
	# sits at z -1.18..1.18, so they clear each other by 0.19 m.
	_torus(parent, "Superheavy Containment Ring", Vector3(52, 1.28, 0),
		1.05, 1.18, Color(0.42, 0.30, 0.12), 0.25, true)
	_add_label(parent, tr("EXHIBIT_WING_D_SIGN"),
		Vector3(52, 2.9, 7.2), Color(0.8, 0.65, 0.42))
	_add_wing_dressing(parent)

	# Per-exhibit accent lights follow the new gallery rows.
	# These six had no name at all, so Godot handed them @OmniLight3D@NNN and the
	# blackout audit could not tell an accent light from any other stray node.
	for pos in [Vector3(21.5, 2.4, -4.5), Vector3(28, 2.4, -4.5), Vector3(35.5, 2.4, -4.5)]:
		var l := OmniLight3D.new()
		l.name = "Gravity Exhibit Accent Light %s" % [pos]
		l.position = pos
		l.light_energy = 0.4
		l.omni_range = 6.0
		l.light_color = Color(0.5, 0.6, 0.9)
		parent.add_child(l)
	for pos in [Vector3(-8, 2.4, -27.5), Vector3(0, 2.4, -27.5), Vector3(8, 2.4, -27.5)]:
		var l := OmniLight3D.new()
		l.name = "Time Exhibit Accent Light %s" % [pos]
		l.position = pos
		l.light_energy = 0.4
		l.omni_range = 6.0
		l.light_color = Color(0.95, 0.7, 0.45)
		parent.add_child(l)
	_add_model_archive(parent)


## Every supplied source model, placed where it stands on a floor, at a size a
## human being would recognise, inside a room that exists.
##
## HOW THE NUMBERS BELOW WERE OBTAINED. Each entry was instantiated through
## MuseumModels.place() and the world AABB of its whole mesh subtree measured in
## a headless run; the position is then derived from that box, not guessed. This
## matters because the .glb origins are wildly inconsistent -- some models sit on
## their origin, some are centred on it, one hangs entirely below it -- and
## because the import scale that makes a model sane is not visible in the file
## name. The measured box of every entry is quoted beside it so the next person
## can check the arithmetic without re-running the probe.
##
## Entries are grouped by the room they belong to, and the four columns are
## (name, position, scale, yaw). `pitch` is passed only where a model is authored
## Z-up and has to be stood on end.
func _add_model_archive(parent: Node) -> void:
	# --- Watcher Office -----------------------------------------------------
	# The workstation is OfficeProps' now and its desk surface is DESK_TOP_Y
	# (0.74) above the office origin at (-25, 0, -2.4), i.e. world y = 0.74 with
	# the top spanning z -2.26..-1.54. Both desktop props below stand on that
	# surface instead of on the 1.09 m bar-height slab that used to be there.
	#
	# basic_pc_monitors at 0.75 measured 1.52 x 0.37 x 0.18 with its base ON its
	# own origin, so at y 1.25 over a 1.09 m desk it floated by exactly the
	# 0.16 m the audit reported. At 0.50 it is 1.01 x 0.25 x 0.12, which fits
	# between the desk edges (x -26.2..-23.8) instead of overhanging them.
	MuseumModels.place(parent, "basic_pc_monitors",
		Vector3(-25.6, 0.74, -1.95), 0.5, 180.0)
	# tactical_flashlight is CENTRED on its origin (measured y -0.03..+0.03 at
	# scale 0.25), so it rests on the desk at 0.74 + 0.027. At the old 0.55 it
	# was a 0.49 m torch; 0.25 makes it 0.22 m, which is a torch.
	MuseumModels.place(parent, "tactical_flashlight",
		Vector3(-24.35, 0.767, -1.78), 0.25, 25.0)
	# The bookcase is an L-shaped Victorian pair -- a tall unit plus a corner
	# unit -- and at 0.8 it stood 1.56 m tall in OPEN FLOOR, 3.5 m from the west
	# wall, which reads as dollhouse furniture parked in a walkway. 1.0 makes
	# the tall unit 1.95 m with 0.25 m book shelves, and the L is tucked into
	# the corner it is shaped for: tall unit's back against the west wall face
	# (x -34.65), corner unit's back against the north wall face (z -6.65).
	# Server Rack 0 spans x -34.17..-33.13, z -5.62..-3.98, so the two clear.
	MuseumModels.place(parent, "wooden_bookcases_with_books",
		Vector3(-34.48, 0.0, -5.16), 1.0, 90.0)
	# The bedside cabinet (0.61 x 0.53 x 0.27) stood in the open at (-21, 1.5),
	# mid-floor in the watch office: domestic furniture in a security post, with
	# nothing on it and nothing beside it. Removed rather than re-sited -- the
	# room already has the locker, two server racks and the bookcase.
	# The vent grille was hanging in mid-air 3.1 m from any wall, at x -18.25 in
	# a room whose east wall face is x -15.35. Its thin axis is X (measured
	# 0.081 deep) so it belongs on a north-south wall; its mesh runs from -0.25
	# to -0.17 of its own origin, so origin -15.10 lands the grille on
	# -15.35..-15.27, flush on the wall face. Non-blocking (MapModels lists it),
	# so it costs the doorway at z = 0 nothing -- and it is 5.5 m from it.
	#
	# ROOM-SIDE WALL FACES, the convention this function and the two dressing
	# functions below all use. _add_room insets each wall by HALF a thickness, so
	# for a room centred on C with size S the wall's centre line is at
	# C +- (S / 2 - WALL_THICKNESS / 2) and the face the room can actually see is
	# a further half-thickness in, at C +- (S / 2 - WALL_THICKNESS). The Watcher
	# Office is 20 x 14 at (-25, 0, 0), so its east face is -25 + 10 - 0.35 =
	# -15.35 and not the -15.175 its wall slab is centred on.
	MuseumModels.place(parent, "vents", Vector3(-15.10, 2.55, -5.5), 0.65, 0.0)

	# --- Entrance Zone ------------------------------------------------------
	# fancy_marble_coffee_table is measured y -0.91..+0.06 at 0.75: its origin is
	# the TOP of the table, so placing it at y 0 buried 94% of it and left the
	# 6 cm sliver the audit found. y = 0.91 stands it on the floor. It also
	# leaves the security office, where a marble coffee table was never furniture
	# the night watch would own, for the public foyer where it is.
	# Footprint x -0.69..+0.69, z -2.12..+0.73 about its origin: at (6.5, 24.0)
	# that is x 5.81..7.19, z 21.88..24.73, clear of the visitor lockers
	# (x 9.7..10.7) and of the central walkway.
	MuseumModels.place(parent, "fancy_marble_coffee_table",
		Vector3(6.5, 0.91, 24.0), 0.75, 0.0)
	# The bust stood at (38, 0, -13): Gravity Wing A is z -9..9, so it was 4 m
	# north of the building with no floor under it. It is also authored Z-up --
	# at pitch 0 it measures 3.09 wide x 1.02 TALL, which is a carving lying on
	# its back. pitch -90 stands it up; 0.55 brings it to 2.00 x 2.00 x 0.66 and
	# y -0.99..+1.01, hence the 0.99 lift. Yawed 90 so its 2 m face runs along
	# the wall, standing 1.05 m in from the west wall FACE at x -10.65 (the
	# -10.825 this used to quote is the slab's centre line, which is 0.175 m
	# inside the wall) and clear of the two exhibition posters at z 21 and z 25.
	# 0.55 also made it 2.00 x 2.00 m -- a square carving the size of a garage
	# door, standing on the bare floor with no plinth under it. That is what
	# read as a monument dumped in the foyer. The model is square head-on, so
	# 0.25 was an over-correction: 0.91 x 0.91 on a 1.05 m plinth reads as a
	# token, not an exhibit, and at pitch -90 the carving stood on its head.
	# pitch +90 turns it the other way up. The model has no head/shoulder taper
	# to measure -- a vertex-band profile is a constant 0.848 m wide over its
	# whole height, i.e. it is a relief panel (two 1 mm plates plus one 0.41 m
	# protrusion in the middle band), so the sign is settled by looking at it,
	# not by measuring it.
	#
	# 0.35 gives a 0.85 x 0.85 m carved face, portrait scale. The MESH AABB is
	# not the carving: it reads y 0.544..1.822 around the origin while the real
	# vertices only run -0.434..+0.420 from it, so sitting the AABB on the plinth
	# left the stone floating 0.21 m in the air. Origin = plinth top + 0.434.
	# Plinth 0.90 high, carving 0.90..1.75, whole piece 1.75 m -- the carved face
	# lands at 1.3 m, eye height for a standing viewer. Plinth is 1.45 m along
	# the wall so the carving does not overhang it, back face at x -10.575, i.e.
	# 0.075 off the west wall face at -10.65, clear of the posters at z 21/25.
	_box(parent, "Foyer Bust Plinth", Vector3(-10.2, 0.45, 18.0),
		Vector3(0.75, 0.90, 1.45), Color(0.22, 0.21, 0.20), 0.0, 0.1)
	MuseumModels.place(parent, "elderly_woman_bust_on_pedestal",
		Vector3(-10.2, 1.334, 18.0), 0.35, 90.0, 90.0)

	# --- Central Atrium / Time Wing B ---------------------------------------
	# Measured 0.51 x 0.65 x 2.32 standing on its own origin: a real 2.3 m bench.
	# Correct as authored, left alone.
	MuseumModels.place(parent, "лавочки", Vector3(8.0, 0.0, -8.0), 0.75, 90.0)
	# The arch that frames the Atrium -> Time Wing B doorway. Deliberately
	# untouched: MapModels.NON_BLOCKING documents the exact collision trade this
	# placement represents, and rescaling it would narrow the opening it frames.
	MuseumModels.place(parent, "арка дверь", Vector3(0.0, 0.0, -15.5), 0.85, 0.0)
	# The clock was 12 cm across, floating at chest height in open floor, and --
	# not being in NON_BLOCKING -- carried a convex collider the player walked
	# into. 2.4 makes it a 0.48 x 0.79 station dial; yaw 90 turns its thin axis
	# (0.12) to face the west wall it now hangs on, whose room-side face is
	# x -12.65. Origin is the dial's BOTTOM centre (measured y 0..0.79), so 1.95
	# puts the dial centre at 2.35 m -- above the player, above the Curator's
	# 2.2 m agent height, and 4.8 m clear of TimeProps' clock bank at z -24.
	MuseumModels.place(parent, "часы", Vector3(-12.59, 1.95, -18.0), 2.4, 90.0)

	# --- Mass Wing D --------------------------------------------------------
	# gallery_bare_concrete_wall is CENTRED on its origin (y -4.19..+4.08 at 0.7),
	# so it was half buried, and at 5.87 m tall it stood 2.5 m through a 3.4 m
	# ceiling while its 6.4 m length ran 3.22 m out through the wing's north wall
	# at z -8. 0.394 brings it to 3.63 x 3.30 x 0.68 -- the tallest slab that
	# clears the 3.39 m soffit -- and y 1.67 stands it on the floor. Its thin
	# axis is Z (measured -0.34..+0.34 about its origin), so it faces into the
	# room off the north wall face at z -7.65, spanning z -7.64..-6.96. The
	# superheavy sphere's plinth reaches z -4.64, so they clear by 2.3 m.
	MuseumModels.place(parent, "gallery_bare_concrete_wall",
		Vector3(52.0, 1.67, -7.30), 0.394, 0.0)
	# 1.33 m was child height for the wing's standing figure; 0.95 makes it
	# 1.80 m, measured base-on-origin. No camera ray reaches x 60.5.
	MuseumModels.place(parent, "наблюдатель", Vector3(61.0, 0.0, 6.0), 0.95, 180.0)

	# --- Forecourt and street -----------------------------------------------
	# A street lamp was standing in the middle of the Central Atrium at
	# (12, 0, -10). It is a street lamp, so it now stands on the street side of
	# the forecourt, east of the east planting bed (which ends at x 17.2) and
	# west of the lot wall at x 31.3. 1.0 makes it 3.23 m, base on origin.
	MuseumModels.place(parent, "уличная лампа", Vector3(19.5, 0.0, 46.0), 1.0, 0.0)
	# The bus shelter rendered 7 cm tall (measured 0.034 x 0.072 x 0.071 at the
	# old 0.6) and stood at (46, -12), 4 m north of Mass Wing D's north wall with
	# nothing under it. 25.0 makes it 1.42 x 3.00 x 2.96; a shelter belongs at
	# the kerb, so it stands on the pavement inside the curb at z 54.55.
	MuseumModels.place(parent, "отсановка", Vector3(20.0, 0.0, 53.0), 25.0, 90.0)
	# The skip was bisected by the Office/Storage wall at z = 7 (measured
	# z -1.31..+1.26 about an origin ON that wall). It is refuse handling, so it
	# joins the delivery bay in the service corner of the forecourt, clear of the
	# pallet at x -28.7..-26.3 and of the tree at x -25.
	MuseumModels.place(parent, "dumpsters_glb", Vector3(-23.0, 0.0, 52.0), 0.65, 0.0)

	# --- Removed -------------------------------------------------------------
	# "modern_grey_stone_tile_texture" is NOT placed. It measured 920.9 x 46.9 x
	# 920.9 m with its top face at y -7.31 -- a tiling-texture swatch nearly a
	# kilometre across, buried seven metres under the museum, visible from
	# nowhere in the game and not a floor by any reading. It is a material
	# sample, not a prop, and the only correct placement for it is none. The
	# file stays in models/; MapModels.NON_BLOCKING still names it, so a future
	# call site gets a collision-free instance if anyone finds a use for it.


## Everything in the four exhibition wings that is not itself an exhibit.
##
## SIGHTLINES ARE THE BINDING CONSTRAINT HERE, not floor space. Each wing's three
## exhibits must stay visible from one nominated camera post
## (test_map_verification raycasts mount -> anomaly anchor), and a hit counts as
## the exhibit only within EXHIBIT_SELF_CLEARANCE = 1.7 m of the anchor. Every
## position below was chosen against the actual rays:
##
##   CAM 05 (16.4, 3.0, -7.8) -> the Wing A row at z -4.5. All three rays run
##   through the wing's NORTH half, descending from y 3.0 to y 1.55, so Wing A's
##   floor dressing lives at z >= 0 and its overhead dressing hangs no lower than
##   y 2.0 where a ray could still be that high.
##   CAM 07 (33.6, 2.9, -30.8) -> Wing C. SpaceProps.dress_wing_c states it
##   traced all three of these clear, so it is taken as-is.
##   CAM 11 (42.2, 2.9, 6.8) -> Wing D. Its three rays sweep the wing's
##   south-west quadrant, so the Wing D dressing is either north of them or has
##   no collider at all.
##
## The second constraint is the Curator. Doorways are 1.8 m and the bake erodes
## 0.45 m per side, so nothing solid goes within 1.6 m of a doorway centre line:
## Wing A's are at (15, 0) and (41, 0), Wing B's at (0, -15), (0, -33) and
## (13, -24), Wing C's at (13, -24), Wing D's at (41, 0).
func _add_wing_dressing(parent: Node) -> void:
	var root := parent as Node3D

	# --- Gravity Wing A: x 15.35..40.65, z -8.65..8.65 -----------------------
	# Those four numbers are the ROOM-SIDE WALL FACES, C +- (S / 2 -
	# WALL_THICKNESS), the convention _add_model_archive spells out. They used to
	# read 15.175..40.825 / -8.825..8.825, which is C +- (S / 2 -
	# WALL_THICKNESS / 2) -- the line each wall slab is CENTRED on, 0.175 m
	# further out than any surface a prop can be stood against. Anything aimed at
	# those numbers lands inside the wall.
	# Anchor plates read as the fixings a wing that manipulates weight would need
	# on every surface: three in the soffit directly over the cases, three in the
	# floor behind them. The ceiling trio sits at y 3.39, above the y 3.0 the
	# camera itself hangs at, so no ray can reach them; the floor trio sits at
	# z -6.6, where the three rays have only travelled to x 18.3 / 20.6 / 23.3
	# and are nowhere near the plates at x 21.5 / 28 / 35.5.
	for x: float in [21.5, 28.0, 35.5]:
		GravityProps.build_anchor_plate(root, Vector3(x, CEILING_SOFFIT_Y, -4.5),
			Vector3.DOWN, true)
		GravityProps.build_anchor_plate(root, Vector3(x, 0, -6.6), Vector3.UP, false)
	# Debris still tethered to its anchor, hanging over the wing's south half.
	# The builder hangs everything BELOW origin and guarantees the lowest piece
	# stays above 1.90 m from an origin at y >= 3.25.
	GravityProps.build_tethered_debris(root, Vector3(38.5, 3.35, 7.0), 5, 1.0, 3)
	GravityProps.build_tethered_debris(root, Vector3(19.0, 3.35, 4.0), 4, 0.9, 7)
	# Dust falling sideways out of a floor crack into the north wall. The whole
	# point of the prop is the wedge piled where the stream stops, so the far end
	# has to MEET a wall; both halves of that used to be wrong.
	#
	#   HEADING. Godot's Y rotation sends local +X to world -Z at yaw +90 and to
	#   +Z at -90 (the mirror of the local-+Z rule CorridorProps states in its
	#   header). At the old -90 the stream ran SOUTH into the middle of the wing
	#   and the wall drift stood in open floor with nothing behind it: measured,
	#   the prop occupied z -6.27..-3.19, its far end 5.5 m from any surface.
	#   ORIGIN. The wedge's flat face lands at length + 0.21 = 2.81 m along local
	#   +X, so the crack belongs 2.81 m out from the face it piles against. The
	#   north face is z -8.65, not the -8.825 the old comment used, which is the
	#   wall slab's centre line -- aiming at it would have buried the drift.
	#
	# -5.84 - 2.81 = -8.65 exactly. 0.97 m tall, so all three CAM 05 rays (y 2.05
	# and above at this x) clear it, and GravityProps builds no colliders at all,
	# so neither the sightline tests nor the navmesh bake can see it.
	GravityProps.build_sideways_dust_column(root, Vector3(24.0, 0, -5.84),
		90.0, 2.6, true, 2)
	# Floor paint on the entrance axis. Chevrons run in from local +Z, which
	# heading 90 sends to world +X, so the approach reads from the Atrium door at
	# x = 15. Paint has no collider and cannot touch the bake.
	GravityProps.build_floor_stencil(root, Vector3(18.0, 0, 0), 90.0, 2.6, 3)

	# --- Time Wing B: room centre (0, -24), 26 x 18 -------------------------
	# dress_time_wing derives its wall mounts from room_size * 0.5, so it is
	# handed the INNER dimensions (26 - 2 * WALL_THICKNESS by 18 - 2 *
	# WALL_THICKNESS). Handed the nominal 26 x 18 it puts the nine-dial clock
	# bank at x -13.0, which is the outer edge of a wall slab spanning
	# -13.0..-12.65 -- the bank would have been built inside the wall.
	TimeProps.dress_time_wing(root, Vector3(0, 0, -24),
		Vector2(26.0 - WALL_THICKNESS * 2.0, 18.0 - WALL_THICKNESS * 2.0))

	# --- Space Wing C -------------------------------------------------------
	# One call. The library placed and measured this set against Wing C's own
	# walls and against CAM 07's rays to all three exhibits.
	SpaceProps.dress_wing_c(root)

	# --- Mass Wing D: x 41.35..62.65, z -7.65..7.65 -------------------------
	# Room-side wall faces again, not the 41.175..62.825 / -7.825..7.825 slab
	# centre lines this header used to quote. All three builders below were
	# measured back off the built tree against the corrected box: chains
	# x 45.24..47.37 z -5.01..-2.79, load frame x 56.17..59.83 z -5.12..-1.17,
	# buckled deck x 49.78..54.22 z 0.41..3.38.
	# Every piece here is deliberately one of MassProps' COLLIDER-FREE builders.
	# The wing already carries three exhibit plinths, the containment ring and
	# the concrete panel, its only door is at x = 41, and CAM 11's three rays
	# cross most of the open floor -- so the dressing buys silhouette without
	# putting one more box in front of the camera or the Curator.
	# Chains: navmesh-neutral by design, over empty floor west of the sphere.
	MassProps.build_tension_chains(root, Vector3(46.5, 0, -4.0), 3.30, 3, 1.15)
	# Load frame: no colliders unless `solid`, which is left false. Its chevron
	# band runs -Z only, so from (58, -3) it occupies z -5.12..-1.17, clear of
	# the pendulum at z 3.57..4.43 and of the sphere at x 50.4..53.6.
	MassProps.build_load_frame(root, Vector3(58, 0, -3.0), 3.4, 3.4, 0.0, false, true)
	# Buckled floor plates: no colliders at all, so this is the one builder in
	# the library that can be walked over and pathed over freely. 3 x 2 plates of
	# 1.4 m give a 4.44 x 2.97 m patch at z 0.12..3.09, north of the sphere and
	# west of the pendulum.
	MassProps.build_buckled_deck(root, Vector3(52, 0, 1.9), 3, 2, 1.4, 0.0, 5)


## The authored exhibit for a slot, built by the wing's own prop library.
##
## These take precedence over `fallback_shape`. Each wing shipped a library of
## measured, purpose-built geometry for its three slots; the primitive shapes
## below them are the older safety net and stay in place for any slot a library
## does not claim.
##
## The gravity, time and space builders all fit inside the 2.25 x 2.10 x 2.25 m
## glass case on top of the 0.7 m pedestal, so those slots keep both. Mass Wing
## D's do not -- MassProps builds its own plinth and the superheavy sphere alone
## is 3.27 m across -- so those three slots are declared PLINTH_FREE_EXHIBITS
## below and get neither pedestal nor case.
##
## Returns true when it built something, false to fall through.
func _add_authored_exhibit(parent: Node, model_name: String,
		at: Vector3) -> bool:
	# GravityProps and TimeProps measure from the FLOOR centre of the slot, which
	# is `at` verbatim. SpaceProps measures from the surface the prop stands on,
	# so those three are lifted onto the 0.70 m pedestal deck.
	var deck := at + Vector3(0, 0.7, 0)
	match model_name:
		"falling_cube":
			GravityProps.build_falling_cube_rig(parent as Node3D, at)
		"inversion_room":
			GravityProps.build_inversion_cell(parent as Node3D, at)
		"levitating_column":
			GravityProps.build_levitating_column(parent as Node3D, at)
		"broken_clock":
			TimeProps.broken_clock(parent as Node3D, at)
		"frozen_drop":
			TimeProps.frozen_drop(parent as Node3D, at)
		"time_loop":
			TimeProps.time_loop(parent as Node3D, at)
		"portal_arch":
			# 0.62 is the largest scale whose 1.46 x 1.62 x 0.58 envelope fits
			# the case; at 1.0 the arch is 2.62 m tall and wears the lid.
			SpaceProps.portal_arch(parent as Node3D, deck, 0.0, 0.62)
		"star_globe":
			SpaceProps.star_globe(parent as Node3D, deck)
		"orrery":
			SpaceProps.orrery(parent as Node3D, deck)
		"superheavy_sphere":
			MassProps.build_superheavy_sphere(parent as Node3D, at)
		"dense_ingot":
			MassProps.build_dense_ingot(parent as Node3D, at, 12.0)
		"mass_pendulum":
			# Yaw 0 puts its two columns at x 56.70 / 59.30, within 5 cm of the
			# 56.8 / 59.2 the hand-built frame that used to stand here occupied,
			# so the wing's silhouette from the doorway is unchanged.
			MassProps.build_mass_pendulum(parent as Node3D, at, 0.0)
		_:
			return false
	return true


## Slots whose authored exhibit brings its own plinth and is too large for the
## standard case. They keep the anomaly anchor and the plaque and lose the
## 2.8 m pedestal and the glass box.
const PLINTH_FREE_EXHIBITS := ["superheavy_sphere", "dense_ingot", "mass_pendulum"]
## One existing case in each open wing doubles as crouch-height cover. The
## footprint was already baked into navigation; only the plinth height changes,
## so this adds a stealth choice without adding another piece of furniture.
const STEALTH_PLINTH_EXHIBITS := ["Inversion Room Exhibit", "Time Loop Exhibit"]
const STEALTH_PLINTH_HEIGHT := 1.15
const STANDARD_PLINTH_HEIGHT := 0.70


func _add_exhibit(parent: Node, exhibit_name: String, model_name: String,
		exhibit_position: Vector3, color: Color, fallback_shape: String,
		emission_energy: float) -> void:
	var anomaly_anchor:=Marker3D.new(); anomaly_anchor.name="Anomaly Anchor - %s"%exhibit_name
	anomaly_anchor.position=exhibit_position+Vector3(0,1.55,0); parent.add_child(anomaly_anchor)
	var cased: bool = model_name not in PLINTH_FREE_EXHIBITS
	if cased:
		var plinth_height := STEALTH_PLINTH_HEIGHT \
			if exhibit_name in STEALTH_PLINTH_EXHIBITS else STANDARD_PLINTH_HEIGHT
		_box(parent, "%s Pedestal" % exhibit_name,
			exhibit_position + Vector3(0, plinth_height * 0.5, 0),
			Vector3(2.8, plinth_height, 2.8), Color(0.16, 0.16, 0.15))

	# Authored geometry first, then a real model, then the primitive fallback.
	if _add_authored_exhibit(parent, model_name, exhibit_position):
		pass
	elif MuseumModels.place(parent, model_name,
			exhibit_position + Vector3(0, 1.55, 0), 1.0, 0.0) == null:
		match fallback_shape:
			"box":
				# Falling cube frozen mid-air: tilted, hovering, with a
				# soft shadow disc on the pedestal.
				var cube := _box(parent, exhibit_name,
					exhibit_position + Vector3(0, 1.6, 0),
					Vector3(0.95, 0.95, 0.95), color, emission_energy)
				cube.rotation_degrees = Vector3(24, 38, 12)
				_cylinder(parent, "%s Shadow" % exhibit_name,
					exhibit_position + Vector3(0, 0.72, 0),
					0.55, 0.03, Color(0.03, 0.03, 0.035))
			"cylinder":
				# Levitating column: broken in two, upper half floating
				# above a glowing seam.
				_cone(parent, "%s Base" % exhibit_name,
					exhibit_position + Vector3(0, 0.98, 0),
					0.38, 0.33, 0.55, color)
				_cylinder(parent, "%s Upper" % exhibit_name,
					exhibit_position + Vector3(0, 1.98, 0),
					0.3, 0.95, color, false, emission_energy)
				_torus(parent, "%s Seam Glow" % exhibit_name,
					exhibit_position + Vector3(0, 1.38, 0),
					0.26, 0.4, Color(0.75, 0.85, 1.0), 1.2, false)
			"sphere":
				_sphere(parent, exhibit_name,
					exhibit_position + Vector3(0, 1.55, 0),
					0.75, color, emission_energy)
			"drop":
				# Frozen falling drop: teardrop body with a tail and a
				# splash ring on the pedestal.
				_sphere(parent, exhibit_name,
					exhibit_position + Vector3(0, 1.45, 0),
					0.42, color, emission_energy)
				_cone(parent, "%s Tail" % exhibit_name,
					exhibit_position + Vector3(0, 2.05, 0),
					0.2, 0.02, 0.55, color, emission_energy * 0.7)
				_torus(parent, "%s Splash Ring" % exhibit_name,
					exhibit_position + Vector3(0, 0.76, 0),
					0.5, 0.64, color, emission_energy * 0.5, false)
			"heavy_sphere":
				# Superheavy sphere sinking into its cracked pedestal.
				_sphere(parent, exhibit_name,
					exhibit_position + Vector3(0, 1.28, 0),
					0.75, color, emission_energy)
				for i in range(4):
					var crack := _box(parent, "%s Crack %d" % [exhibit_name, i],
						exhibit_position + Vector3(0, 0.71, 0),
						Vector3(1.9, 0.02, 0.07), Color(0.02, 0.02, 0.02),
						0.0, 0.0, false)
					crack.rotation_degrees = Vector3(0, 45.0 * float(i) + 10.0, 0)
			"torus":
				# Godot 4 ships a real TorusMesh -- use it instead of the
				# old ring-of-boxes approximation. A small marker sphere
				# sits on the loop like a trapped moment.
				_torus(parent, exhibit_name,
					exhibit_position + Vector3(0, 1.55, 0),
					0.34, 0.62, color, emission_energy)
				_sphere(parent, "%s Marker" % exhibit_name,
					exhibit_position + Vector3(0.34, 1.89, 0),
					0.1, Color(0.95, 0.85, 0.5), 0.9)
			"portal":
				# A prism arch over a transparent portal plane.
				_prism(parent, "%s Arch Top" % exhibit_name,
					exhibit_position + Vector3(0, 2.6, 0),
					Vector3(2.4, 0.6, 0.3), color)
				_box(parent, "%s Arch Left" % exhibit_name,
					exhibit_position + Vector3(-1.0, 1.3, 0),
					Vector3(0.3, 2.6, 0.3), color)
				_box(parent, "%s Arch Right" % exhibit_name,
					exhibit_position + Vector3(1.0, 1.3, 0),
					Vector3(0.3, 2.6, 0.3), color)
				_plane(parent, "%s Portal Surface" % exhibit_name,
					exhibit_position + Vector3(0, 1.3, 0),
					Vector2(2.0, 2.4), Color(0.18, 0.26, 0.36, 0.35),
					false, true)

	# Dedicated glass material: the old call passed `true` into the float
	# emission_energy argument (a type error in Godot 4) and used the
	# rough noise material, which does not read as glass.
	if cased:
		_glass_case(parent, "%s Glass Case" % exhibit_name,
			exhibit_position + Vector3(0, 1.4, 0), Vector3(2.25, 2.1, 2.25))
	_add_label(parent, exhibit_name,
		exhibit_position + Vector3(0, 2.75, 0),
		Color(0.82, 0.82, 0.72))


func _add_planetarium_details(parent: Node) -> void:
	var c := Vector3(0, 0, -41)
	# Pixel-star field glued to the ceiling (deterministic scatter).
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(46):
		var star_pos := Vector3(rng.randf_range(-8.6, 8.6), 3.26,
			rng.randf_range(-48.0, -34.2))
		var tint := 0.7 + rng.randf() * 0.3
		_box(parent, "Star %d" % i, star_pos, Vector3(0.06, 0.06, 0.06),
			Color(tint, tint, 1.0), rng.randf_range(1.2, 2.6), 0.0, false)
	# The room proper: a flat saucer dome, the shrouded projector under it, a
	# raked seating bank and the operator's booth. One call -- the library placed
	# and measured all four against this room's 20 x 16 footprint and its single
	# doorway at (0, -33), and reports the nearest collider to that doorway at
	# 4.9 m.
	#
	# This REPLACES the small brass orrery, its stanchion ring, the four radial
	# benches and the dead console that used to stand here. Every one of them was
	# in the way: the orrery sat at the room centre where the projector stands,
	# the benches at radius 5.2 ran into the seating bank at z -48.1..-42.3, and
	# the console at (6.5, -34.6) was inside the booth's 3.73 x 5.43 m footprint.
	PlanetariumProps.build_all(parent as Node3D, c)
	_add_label(parent, tr("EXHIBIT_PLANETARIUM_SIGN"), c + Vector3(0, 2.9, 6.0),
		Color(0.55, 0.62, 0.95))


func _add_lab_details(parent: Node) -> void:
	var c := Vector3(-25, 0, 22)
	# The Restoration Lab in one call. It replaces the half-restored torso on its
	# bench, the two crate racks and the taped sealed crate that stood here: the
	# library puts a work bench on the same north wall at (-31, 0, 18.1), a fume
	# hood on the east wall, an opened crate at (-20, 0, 24.9) with its foam
	# cut-out in the shape of what left it, and Exhibit 9 under a dust sheet on
	# the room's centre line -- 2.49 m of covered figure, which is taller than a
	# person, standing where the flashlight finds it first.
	#
	# The doorway approach along x = -25 stays clear for 6 m by construction, and
	# the tripod lamp aimed at the sheet casts the only real shadow in the room.
	#
	# Both strings are already translated when they arrive; PROP_EXHIBIT_9_TAG and
	# PROP_CRATE_DO_NOT_OPEN are both in localization/game.csv.
	ArchiveProps.build_restoration_lab(parent as Node3D, c, 0.0,
		tr("PROP_EXHIBIT_9_TAG"), tr("PROP_CRATE_DO_NOT_OPEN"))
	_add_label(parent, tr("EXHIBIT_LAB_SIGN"),
		c + Vector3(0, 2.7, 0), Color(0.9, 0.6, 0.3))


func _add_extra_exhibits(parent: Node) -> void:
	# Gravity Wing A: inverted fountain -- the water falls up.
	var f := Vector3(35.5, 0, 5)
	_cylinder(parent, "Fountain Basin", f + Vector3(0, 0.3, 0), 1.2, 0.6,
		Color(0.13, 0.14, 0.15))
	_cylinder(parent, "Fountain Water", f + Vector3(0, 0.62, 0), 1.05, 0.08,
		Color(0.2, 0.45, 0.55), false, 0.5)
	_cylinder(parent, "Fountain Jet", f + Vector3(0, 1.6, 0), 0.09, 2.0,
		Color(0.35, 0.6, 0.72), false, 0.8)
	_torus(parent, "Fountain Splash", f + Vector3(0, 2.6, 0), 0.3, 0.42,
		Color(0.4, 0.65, 0.78), 0.8, false)
	# Gravity Wing A: broken balance scale, forever tipped.
	var sc := Vector3(20.5, 0, 5)
	_box(parent, "Scale Base", sc + Vector3(0, 0.45, 0), Vector3(0.5, 0.9, 0.5),
		Color(0.15, 0.13, 0.1))
	if MuseumModels.place(parent, "balance_scale", sc + Vector3(0, 0.9, 0), 1.0, 0.0) == null:
		var beam := _box(parent, "Scale Beam", sc + Vector3(0, 1.0, 0),
			Vector3(1.8, 0.07, 0.12), Color(0.35, 0.28, 0.14), 0.0, 0.6, false)
		beam.rotation_degrees = Vector3(0, 0, 14)
		_cylinder(parent, "Scale Pan Left", sc + Vector3(-0.85, 0.72, 0), 0.28, 0.05,
			Color(0.3, 0.25, 0.12))
		_cylinder(parent, "Scale Pan Right", sc + Vector3(0.85, 1.25, 0), 0.28, 0.05,
			Color(0.3, 0.25, 0.12))
	# Time Wing B: great hourglass, sand frozen mid-fall.
	var h := Vector3(0, 0, -20)
	_cylinder(parent, "Hourglass Pedestal", h + Vector3(0, 0.5, 0), 0.7, 1.0,
		Color(0.16, 0.13, 0.11))
	if MuseumModels.place(parent, "great_hourglass", h + Vector3(0, 1.05, 0), 1.0, 0.0) == null:
		_cone(parent, "Hourglass Bottom Bulb", h + Vector3(0, 1.23, 0), 0.42, 0.06,
			0.75, Color(0.7, 0.6, 0.4), 0.3)
		_cone(parent, "Hourglass Top Bulb", h + Vector3(0, 1.98, 0), 0.06, 0.42,
			0.75, Color(0.7, 0.6, 0.4), 0.3)
		_cylinder(parent, "Hourglass Sand Thread", h + Vector3(0, 1.6, 0), 0.02, 0.5,
			Color(0.9, 0.78, 0.45), false, 1.2)
	_glass_case(parent, "Hourglass Case", h + Vector3(0, 1.35, 0),
		Vector3(1.3, 2.7, 1.3))
	# Atrium: brass floor crest under the skylight (no collision -- walkable).
	_box(parent, "Atrium Crest Plate", Vector3(0, 0.012, -8),
		Vector3(2.6, 0.02, 2.6), Color(0.3, 0.25, 0.13), 0.15, 0.5, false)
	var crest_star := _box(parent, "Atrium Crest Star", Vector3(0, 0.03, -8),
		Vector3(1.9, 0.02, 1.9), Color(0.45, 0.36, 0.16), 0.3, 0.6, false)
	crest_star.rotation_degrees = Vector3(0, 45, 0)
	# The Archive's reading desk, ledger, lamp and box files used to be built here
	# around (-25, 0, -11). ArchiveProps.build_archive puts a reading desk at
	# (-28.6, 0, -9.3) and box-file stacks against both side walls, so keeping
	# these would have furnished the room twice.
	#
	# Equipment Storage's four steel racks used to be built here, at
	# (+-32.6 / +-17.4, 0, 10 and 14). Every one of them stood inside a bench:
	# GameManager._build_devices() builds four 6.8 x 1.25 m equipment benches at
	# x -34.15..-27.35 and -22.65..-15.85, z 8.575..9.825 and 14.375..15.625, and
	# the racks at z 8.7..11.3 and 12.7..15.3 overlapped all four. That collision
	# predates this change and is why the room is dressed from the walls now --
	# see _add_storage_props.


func _add_furnishings(parent: Node) -> void:
	# The containment core used to be built here, as a thin dais / pedestal /
	# sphere / dome stack with a ring of stanchions and an untranslated English
	# label reading "Object 01 - do not touch the glass". AtriumProps.build_atrium
	# (called from build_map) now builds the whole assembly, and it rebuilds
	# "Anomalous Core" and "Containment Dome" under those EXACT node names with
	# the same ContainmentDome.gdshader on the dome -- which is what
	# GameManager._tint_core() and GameManager._set_dome_breach() resolve with
	# find_child(). Leaving the old block in would have doubled the geometry on
	# the origin and given both of those lookups two candidates to choose
	# between. The plaque that replaces the label reads tr("EXHIBIT_CONTAINMENT_CORE").

	# Wing banners flanking the atrium doorways.
	_box(parent, "Wing Banner NW", Vector3(-3.2, 2.4, -14.45),
		Vector3(1.1, 1.6, 0.06), Color(0.30, 0.42, 0.72), 0.15, 0.0, false)
	_box(parent, "Wing Banner NE", Vector3(3.2, 2.4, -14.45),
		Vector3(1.1, 1.6, 0.06), Color(0.72, 0.50, 0.30), 0.15, 0.0, false)
	_box(parent, "Wing Banner EN", Vector3(14.45, 2.4, -3.2),
		Vector3(0.06, 1.6, 1.1), Color(0.50, 0.36, 0.66), 0.15, 0.0, false)
	_box(parent, "Wing Banner ES", Vector3(14.45, 2.4, 3.2),
		Vector3(0.06, 1.6, 1.1), Color(0.55, 0.45, 0.28), 0.15, 0.0, false)

	# Entrance hall: brochure stand, posters, floor mat.
	_cylinder(parent, "Brochure Stand Pole", Vector3(5, 0.6, 27), 0.05, 1.2,
		Color(0.2, 0.2, 0.22))
	var brochure_top := _box(parent, "Brochure Stand Top", Vector3(5, 1.25, 27),
		Vector3(0.6, 0.06, 0.45), Color(0.75, 0.72, 0.65))
	brochure_top.rotation_degrees = Vector3(-20, 0, 0)
	_box(parent, "Exhibition Poster A", Vector3(-10.55, 1.7, 21),
		Vector3(0.08, 1.6, 1.1), Color(0.30, 0.42, 0.72), 0.2, 0.0, false)
	_box(parent, "Exhibition Poster B", Vector3(-10.55, 1.7, 25),
		Vector3(0.08, 1.6, 1.1), Color(0.72, 0.50, 0.30), 0.2, 0.0, false)
	_plane(parent, "Entrance Floor Mat", Vector3(0, 0.012, 32), Vector2(3.4, 2.0),
		Color(0.32, 0.14, 0.12), true, false, 0.0, false)

	# Gravity Wing: a cluster of hovering stones.
	_cylinder(parent, "Hover Stones Pedestal", Vector3(28, 0.25, 5), 0.9, 0.5,
		Color(0.55, 0.57, 0.60))
	_sphere(parent, "Hover Stone A", Vector3(27.7, 1.3, 4.8), 0.22,
		Color(0.42, 0.44, 0.48))
	_sphere(parent, "Hover Stone B", Vector3(28.3, 1.7, 5.2), 0.16,
		Color(0.38, 0.40, 0.44))
	_sphere(parent, "Hover Stone C", Vector3(28.0, 2.1, 4.9), 0.11,
		Color(0.46, 0.48, 0.52))
	_add_stanchions(parent, Vector3(28, 0, 5), 1.6, 6)
	_add_label(parent, tr("EXHIBIT_HOVER_STONES"), Vector3(28, 2.6, 5),
		Color(0.30, 0.35, 0.45))

	# The Time Wing's row of four wall clocks used to be built here, on the north
	# wall at z -32.35. TimeProps.dress_time_wing hangs a nine-dial clock bank on
	# the west wall and three single dials including "Gallery Clock North" at
	# (-5, 2.15, -32.65) -- 0.30 m behind where "Wall Clock 1" stood, at the same
	# x, so the two would have intersected. The row is the library's now.

	# The Archive's two wall bays, its shelves and its document boxes were built
	# here; ArchiveProps.build_archive lays out the whole room, its rolling
	# stacks reaching z -16.44, which is where "Archive Rack" stood at -16.2.

	# Equipment Storage's barrels and work cart stood at z 15.3..15.4, inside the
	# footprint of the equipment benches GameManager._build_devices() builds at
	# z 14.375..15.625. StorageProps dresses the room now, from _add_storage_props,
	# which was written against those bench extents.


func _add_more_interior(parent: Node) -> void:
	# Фойе и атриум строятся отдельными функциями.

	# --- Gravity Wing: two more displays ---
	# Placed clear of Falling Cube (22,-4), Inversion Room (30,4),
	# Levitating Column (36,-3), Fountain (35,5) and Scale (20,5).
	_box(parent, "Meteorite Plinth", Vector3(26, 0.5, -7), Vector3(1.1, 1.0, 1.1),
		Color(0.55, 0.57, 0.60))
	if MuseumModels.place(parent, "meteorite", Vector3(26, 1.35, -7), 1.0, 0.0) == null:
		_sphere(parent, "Meteorite", Vector3(26, 1.35, -7), 0.34, Color(0.25, 0.24, 0.26))
	_add_label(parent, tr("EXHIBIT_IRON_METEORITE"), Vector3(26, 2.3, -7), Color(0.30, 0.35, 0.45))
	_box(parent, "Apple Display Pedestal", Vector3(39, 0.45, -7), Vector3(0.8, 0.9, 0.8),
		Color(0.55, 0.57, 0.60))
	if MuseumModels.place(parent, "bronze_apple", Vector3(39, 1.5, -7), 1.0, 0.0) == null:
		_sphere(parent, "Bronze Apple", Vector3(39, 1.5, -7), 0.16, Color(0.72, 0.50, 0.25))
	_add_label(parent, tr("EXHIBIT_FIRST_FALL"), Vector3(39, 2.2, -7), Color(0.30, 0.35, 0.45))

	# --- Time Wing: mini hourglass and sundial ---
	# Moved to the south end of the wing: the exhibit row at z=-26..-30
	# (Broken Clock, Frozen Drop, Time Loop, Great Hourglass) stays clear.
	_box(parent, "Mini Hourglass Pedestal", Vector3(-11, 0.45, -18),
		Vector3(0.9, 0.9, 0.9), Color(0.72, 0.66, 0.55))
	_cone(parent, "Mini Hourglass Bottom", Vector3(-11, 1.12, -18), 0.22, 0.03, 0.24,
		Color(0.85, 0.80, 0.60), 0.2)
	var hourglass_top := _cone(parent, "Mini Hourglass Top", Vector3(-11, 1.36, -18),
		0.22, 0.03, 0.24, Color(0.85, 0.80, 0.60), 0.2)
	hourglass_top.rotation_degrees = Vector3(180, 0, 0)
	_glass_case(parent, "Mini Hourglass Case", Vector3(-11, 1.3, -18),
		Vector3(0.7, 0.8, 0.7))
	_add_label(parent, tr("EXHIBIT_ENDLESS_HOURGLASS"), Vector3(-11, 2.2, -18), Color(0.45, 0.38, 0.25))
	_cylinder(parent, "Солнечные часы Dais", Vector3(11, 0.3, -18), 0.8, 0.6,
		Color(0.72, 0.66, 0.55))
	if MuseumModels.place(parent, "sundial", Vector3(11, 0.6, -18), 1.0, 0.0) == null:
		var gnomon := _box(parent, "Солнечные часы Gnomon", Vector3(11, 0.85, -18),
			Vector3(0.06, 0.5, 0.3), Color(0.35, 0.30, 0.22), 0.0, 0.4, false)
		gnomon.rotation_degrees = Vector3(0, 0, -35)
	_add_label(parent, tr("EXHIBIT_SUNDIAL"), Vector3(11, 1.8, -18), Color(0.45, 0.38, 0.25))

	# The Archive's central catalogue island stood at (-25, 0, -14) with its chair
	# at (-25, 0, -13). ArchiveProps.build_archive opens an aisle through its
	# rolling stacks at x -29.71 and runs a paper trail out of it to z -13.1, and
	# its card catalogue occupies (-23.65, 0, -15.95). The island was in the way
	# of both, so the room's centre line is left clear for them.

	# Storage's ladder, toolbox, mop and bucket stood at x -34.0 / -18.2 / -17.0.
	# The mop and bucket at (-17.0, 8.2) were inside GameManager's east bench
	# (x -22.65..-15.85, z 8.575..9.825) and the toolbox at (-18.2, 15.5) inside
	# its south-east one. Storage is dressed from _add_storage_props now.

	# --- Watcher Office: corkboard and water cooler ---
	_box(parent, "Office Corkboard", Vector3(-34.4, 1.9, 3), Vector3(0.06, 1.0, 1.6),
		Color(0.55, 0.42, 0.28), 0.0, 0.0, false)
	for note in range(4):
		_box(parent, "Corkboard Note %d" % note,
			Vector3(-34.36, 1.75 + 0.18 * float(note % 2), 2.5 + 0.35 * float(note)),
			Vector3(0.02, 0.16, 0.14),
			Color(0.90, 0.90, 0.80) if note % 2 == 0 else Color(0.90, 0.85, 0.50),
			0.05, 0.0, false)
	_cylinder(parent, "Water Cooler Body", Vector3(-16.2, 0.6, 5.6), 0.22, 1.2,
		Color(0.80, 0.82, 0.85))
	_cylinder(parent, "Water Cooler Bottle", Vector3(-16.2, 1.45, 5.6), 0.16, 0.5,
		Color(0.50, 0.70, 0.90))


func _add_outdoor(parent: Node) -> void:
	# Rebuilt forecourt: a formal central arrival axis, balanced lawns and
	# symmetrical seating replace the previous scattered dirt-lot composition.
	_box(parent, "Forecourt Ground", Vector3(0, -0.10, 45), Vector3(64, 0.2, 20),
		Color(0.34, 0.37, 0.31))
	_box(parent, "Museum Walkway", Vector3(0, -0.015, 45), Vector3(6.4, 0.10, 20),
		Color(0.78, 0.77, 0.73))
	_box(parent, "Entrance Plaza", Vector3(0, -0.005, 38.2), Vector3(17, 0.10, 5.6),
		Color(0.70, 0.70, 0.68))
	# These plates used to be a hump, not a stair. Their tops ran 0.100 (z 35.6),
	# 0.160, 0.220 (z 36.4) while the plaza in front of them is 0.045 and the lobby
	# floor behind them is 0.000: walking in meant climbing 0.175 and then
	# immediately dropping 0.220, on ground the fiction calls flat. The lobby floor
	# cannot be raised (the whole building sits on y=0) and any plate standing
	# above the plaza rebuilds the hump, so the plates now sit FLUSH with the plaza
	# at 0.045 and read as a porch by their lighter stone alone, widening outwards.
	# Measured after the change: a ray walk from z 38.6 to the threshold reports
	# 0.045 the whole way, step +0.000, and the body crosses in both directions
	# without a single stuck frame.
	for i in range(3):
		_box(parent, "Entrance Step %d" % i,
			Vector3(0, -0.015, 35.6 + float(i) * 0.4),
			Vector3(5.6 + float(i) * 0.8, 0.12, 0.5),
			Color(0.80 - float(i) * 0.02, 0.79 - float(i) * 0.02, 0.75 - float(i) * 0.02))

	# Long planting beds frame the route without narrowing the playable path.
	for side: float in [-1.0, 1.0]:
		var bed_x: float = side * 10.5
		var bed_tag: String = "West" if side < 0.0 else "East"
		_box(parent, "Formal Lawn %s" % bed_tag, Vector3(bed_x, -0.005, 45), Vector3(13, 0.08, 14),
			Color(0.25, 0.37, 0.23), 0.0, 0.0, false)
		_box(parent, "Lawn Stone Border %s" % bed_tag, Vector3(bed_x, 0.05, 45), Vector3(13.4, 0.12, 14.4),
			Color(0.50, 0.50, 0.47), 0.0, 0.0, false)
		_box(parent, "Lawn Inset %s" % bed_tag, Vector3(bed_x, 0.065, 45), Vector3(12.8, 0.08, 13.8),
			Color(0.25, 0.37, 0.23), 0.0, 0.0, false)
		for z: float in [40.0, 45.0, 50.0]:
			_add_plant(parent, Vector3(side * 6.2, 0, z))

	# Six lights create an even cadence from curb to entrance.
	for z: float in [39.5, 45.0, 50.5]:
		for lx: float in [-4.5, 4.5]:
			_cylinder(parent, "Street Lamp Post %s" % [Vector2(lx, z)], Vector3(lx, 1.6, z), 0.08, 3.2,
				Color(0.12, 0.13, 0.14))
			_box(parent, "Street Lamp Head %s" % [Vector2(lx, z)], Vector3(lx, 3.25, z),
				Vector3(0.42, 0.28, 0.42), Color(0.92, 0.86, 0.68), 0.55)

	# Facing benches form a deliberate pause point halfway to the entrance.
	# The seat and the back used to be two planks hanging in mid-air: the seat
	# floated at y 0.39..0.51 and the back at 0.55..1.05 with nothing under
	# either of them. Legs at both ends and two posts carrying the back make it
	# a bench. Both benches also shared one node name, so Godot renamed the
	# second pair to @MeshInstance3D@NNN; they are told apart by side now.
	for side: float in [-1.0, 1.0]:
		var bx: float = side * 8.0
		var tag: String = "West" if side < 0.0 else "East"
		# Grown from 2.6 x 0.62 (a two-seater plank) to 3.4 x 0.72: a four-seat
		# park bench, which is the scale the 64 m forecourt asks for. Seat top
		# stays at 0.52 (sitting height); the back is taller, 0.55..1.13.
		_box(parent, "Forecourt Bench %s Seat" % tag, Vector3(bx, 0.45, 43.5),
			Vector3(3.4, 0.14, 0.72), Color(0.28, 0.22, 0.16))
		_box(parent, "Forecourt Bench %s Back" % tag, Vector3(bx, 0.84, 43.86),
			Vector3(3.4, 0.58, 0.09), Color(0.25, 0.19, 0.14))
		for end_side: float in [-1.0, 1.0]:
			var ex: float = bx + end_side * 1.55
			var end_tag: String = "L" if end_side < 0.0 else "R"
			_box(parent, "Forecourt Bench %s Leg %s" % [tag, end_tag],
				Vector3(ex, 0.19, 43.5), Vector3(0.12, 0.38, 0.66),
				Color(0.20, 0.16, 0.12))
			_box(parent, "Forecourt Bench %s Post %s" % [tag, end_tag],
				Vector3(ex, 0.82, 43.86), Vector3(0.10, 0.62, 0.09),
				Color(0.20, 0.16, 0.12))

	_box(parent, "Museum Sign", Vector3(0, 3.5, 35.2), Vector3(7.8, 1.0, 0.3),
		Color(0.16, 0.18, 0.22))
	# The facade sign read "NATURAL PHILOSOPHY MUSEUM" -- an untranslated English
	# literal naming a building this game does not contain. The museum is THE
	# FIRST MUSEUM / ПЕРВЫЙ МУЗЕЙ everywhere else: the main menu, the protocol
	# header, the intro caption. It matters more now than it did, because the
	# prologue's first three shots are aimed straight at this sign.
	# z 35.4, not 35.0: the sign box above spans z 35.05..35.35, so the old
	# position put the museum's own name *inside* the board and nobody could
	# read it from the forecourt. 0.05 m clear of the street-facing face.
	_add_label(parent, tr("EXHIBIT_MUSEUM_SIGN"), Vector3(0, 3.5, 35.4),
		Color(0.92, 0.89, 0.78))

	# Low perimeter walls keep the composition bounded while preserving the
	# road-facing entrance and a clear view of the facade.
	# Extents recap: "Forecourt Ground" above covers x -32..32, z 35..55 and
	# "Street Road" in _add_street_extras() continues it over z 55..63. There is
	# no floor anywhere outside that rectangle. The side walls used to be
	# centred at z 45 with depth 22, i.e. they stopped at z 56 and left the
	# whole road frontage open; run them from z 34 to z 63.5 instead, where they
	# meet "Lot Wall South" (z 63.3..63.7).
	_box(parent, "Lot Wall East", Vector3(31.5, 0.6, 48.75), Vector3(0.4, 1.2, 29.5),
		Color(0.26, 0.27, 0.25))
	_box(parent, "Lot Wall West", Vector3(-31.5, 0.6, 48.75), Vector3(0.4, 1.2, 29.5),
		Color(0.26, 0.27, 0.25))

	# North edge. The Entrance Zone facade is only 22 m wide: its south wall
	# spans x -11..11 at z 34.65..35.0 (room centre z 25, depth 20, walls inset
	# by half of WALL_THICKNESS). Past either corner the ground simply ends at
	# z = 35 with nothing underneath -- that is how the player walked into the
	# void. Close both shoulders: x 11..32 and x -32..-11, standing on the
	# ground at z 35.0..35.4 so nothing overhangs the drop, butted flush
	# against the facade so the seam is zero-width (capsule radius is 0.35).
	# 1.2 m matches the lot walls and is unclimbable: jump_velocity 6.0 under
	# gravity 18.0 gives a 1.0 m apex, and _try_step_up() only runs grounded.
	for side: float in [-1.0, 1.0]:
		_box(parent, "Lot Wall North %s" % ("East" if side > 0.0 else "West"),
			Vector3(side * 21.5, 0.6, 35.2), Vector3(21.0, 1.2, 0.4),
			Color(0.26, 0.27, 0.25))


func _add_street_extras(parent: Node) -> void:
	# Proper road edge, pedestrian crossing and drainage line.
	_box(parent, "Street Road", Vector3(0, -0.095, 59), Vector3(64, 0.21, 8),
		Color(0.16, 0.17, 0.19))
	_box(parent, "Street Curb", Vector3(0, 0.05, 54.8), Vector3(64, 0.12, 0.5),
		Color(0.62, 0.62, 0.60))
	for i in range(8):
		_plane(parent, "Road Line %d" % i,
			Vector3(-28.0 + float(i) * 8.0, 0.012, 60.6), Vector2(2.4, 0.18),
			Color(0.88, 0.84, 0.65), true, false, 0.0, false)
	for i in range(6):
		_plane(parent, "Crosswalk Stripe %d" % i,
			Vector3(-2.5 + float(i), 0.016, 57.2), Vector2(0.55, 3.0),
			Color(0.82, 0.82, 0.79), true, false, 0.0, false)

	# Vehicles are parked parallel to the road in distinct visitor/service bays.
	_box(parent, "Visitor Car Body", Vector3(15.5, 0.62, 59.0), Vector3(4.0, 0.8, 1.8),
		Color(0.31, 0.39, 0.48), 0.0, 0.45)
	_box(parent, "Visitor Car Cabin", Vector3(15.1, 1.25, 59.0), Vector3(2.1, 0.55, 1.6),
		Color(0.24, 0.29, 0.34), 0.0, 0.35)
	for off: Vector3 in [Vector3(-1.3, 0, -0.86), Vector3(1.3, 0, -0.86), Vector3(-1.3, 0, 0.86), Vector3(1.3, 0, 0.86)]:
		var wheel := _cylinder(parent, "Visitor Car Wheel %s" % [off], Vector3(15.5, 0.32, 59.0) + off,
			0.32, 0.24, Color(0.06, 0.06, 0.07))
		wheel.rotation_degrees = Vector3(90, 0, 0)
	_box(parent, "Museum Service Van", Vector3(-17.0, 0.95, 59.0), Vector3(4.4, 1.7, 1.9),
		Color(0.70, 0.70, 0.68), 0.0, 0.25)
	_box(parent, "Service Van Stripe", Vector3(-17.0, 1.08, 58.01), Vector3(3.4, 0.32, 0.03),
		Color(0.24, 0.34, 0.42), 0.15, 0.0, false)
	for off: Vector3 in [Vector3(-1.45, 0, -0.9), Vector3(1.45, 0, -0.9), Vector3(-1.45, 0, 0.9), Vector3(1.45, 0, 0.9)]:
		var van_wheel := _cylinder(parent, "Service Van Wheel %s" % [off], Vector3(-17.0, 0.34, 59.0) + off,
			0.34, 0.26, Color(0.06, 0.06, 0.07))
		van_wheel.rotation_degrees = Vector3(90, 0, 0)

	# Symmetrical tree line and flag pair frame the museum facade.
	for tree_pos: Vector3 in [Vector3(-25, 0, 39.5), Vector3(-25, 0, 50.5), Vector3(25, 0, 39.5), Vector3(25, 0, 50.5)]:
		_cylinder(parent, "Street Tree Trunk %s" % [tree_pos], tree_pos + Vector3(0, 1.1, 0), 0.18,
			2.2, Color(0.30, 0.22, 0.14))
		_cone(parent, "Street Tree Crown %s" % [tree_pos], tree_pos + Vector3(0, 3.3, 0), 1.5, 0.15,
			2.4, Color(0.18, 0.31, 0.16))
	for fx: float in [-5.4, 5.4]:
		var flag_tag: String = "West" if fx < 0.0 else "East"
		_cylinder(parent, "Flag Pole %s" % flag_tag, Vector3(fx, 2.5, 36.8), 0.05, 5.0,
			Color(0.60, 0.62, 0.66))
		_box(parent, "Flag %s" % flag_tag, Vector3(fx + 0.5, 4.55, 36.8), Vector3(0.9, 0.5, 0.04),
			Color(0.30, 0.42, 0.72) if fx < 0.0 else Color(0.72, 0.50, 0.30),
			0.15, 0.0, false)

	# Visitor amenities are grouped into clean east/west service zones.
	_cylinder(parent, "Hours Sign Pole", Vector3(4.8, 0.7, 52.0), 0.04, 1.4,
		Color(0.18, 0.19, 0.21))
	_box(parent, "Hours Sign Board", Vector3(4.8, 1.55, 52.0), Vector3(1.5, 0.7, 0.06),
		Color(0.88, 0.86, 0.80), 0.1, 0.0, false)
	_add_label(parent, tr("EXHIBIT_OPEN_HOURS"), Vector3(4.8, 1.55, 51.9),
		Color(0.20, 0.24, 0.20))
	for i in range(4):
		_torus(parent, "Bike Rack Hoop %d" % i,
			Vector3(10.0 + float(i) * 0.8, 0.4, 51.2), 0.32, 0.42,
			Color(0.42, 0.45, 0.48))
	# z 53.2, not 52.0. The planting beds above are 13.4 x 14.4 centred on
	# (+-10.5, 45), so they run to z 52.2 -- both bins used to stand with their
	# bases inside the 12 cm stone border, which measured as a bin sunk 0.11 m
	# into the ground. 53.2 is a metre clear of the beds and 1.35 m short of the
	# kerb at 54.55.
	# r 0.28 x 0.76 was a waste basket, not street furniture. r 0.36 x 1.00 with
	# a rim puts the opening at 1.0 m, i.e. hand height, and still leaves 0.64 m
	# to the beds at z 52.2 and 0.99 m to the kerb at 54.55.
	for bin_pos: Vector3 in [Vector3(-4.8, 0.50, 53.2), Vector3(8.0, 0.50, 53.2)]:
		_cylinder(parent, "Street Bin %s" % [bin_pos], bin_pos, 0.36, 1.00, Color(0.16, 0.25, 0.18))
		_cylinder(parent, "Street Bin Rim %s" % [bin_pos], bin_pos + Vector3(0, 0.52, 0), 0.39,
			0.06, Color(0.12, 0.19, 0.14))
	_cylinder(parent, "Fire Hydrant", Vector3(11.5, 0.3, 54.0), 0.14, 0.6,
		Color(0.62, 0.14, 0.12))
	_sphere(parent, "Fire Hydrant Cap", Vector3(11.5, 0.66, 54.0), 0.15,
		Color(0.62, 0.14, 0.12))

	# Deliveries stay in a dedicated west bay, away from the visitor axis.
	_box(parent, "Delivery Pallet", Vector3(-27.5, 0.06, 52.0), Vector3(2.4, 0.12, 1.6),
		Color(0.38, 0.30, 0.20))
	_box(parent, "Delivery Crate A", Vector3(-28.0, 0.57, 52.0), Vector3(0.9, 0.9, 0.9),
		Color(0.50, 0.40, 0.27))
	_box(parent, "Delivery Crate B", Vector3(-26.9, 0.47, 52.3), Vector3(0.7, 0.7, 0.7),
		Color(0.46, 0.36, 0.24))

	# The billboard closes the long vista without competing with the facade.
	_box(parent, "Lot Wall South", Vector3(0, 0.6, 63.5), Vector3(64, 1.2, 0.4),
		Color(0.26, 0.27, 0.25))
	for bx: float in [-3.2, 3.2]:
		_cylinder(parent, "Billboard Post %s" % ("West" if bx < 0.0 else "East"), Vector3(bx, 0.7, 62.9), 0.08, 1.4,
			Color(0.12, 0.13, 0.14))
	_box(parent, "Street Billboard", Vector3(0, 2.2, 62.9), Vector3(7.2, 2.2, 0.2),
		Color(0.13, 0.15, 0.19))
	_add_label(parent, "SPECIAL EXHIBIT: OBJECT 01", Vector3(0, 2.4, 62.7),
		Color(0.86, 0.90, 0.80))


## NO LONGER CALLED. The containment dome is built by AtriumProps.build_atrium()
## now, and that file applies the shader itself through an identical
## ResourceLoader.exists() guard chain, so this function has no call site left in
## the project.
##
## It is kept rather than deleted because it is cited by name, as the reference
## implementation of that guard chain, from two files that are not mine to edit:
## game/CRTOverlay.gd:93 and game/props/AtriumProps.gd:299. Deleting it would
## leave both comments pointing at nothing. Delete it together with those
## references, or leave it; it costs one unreferenced function.
func _apply_dome_shader(dome: MeshInstance3D) -> void:
	# Force-field glass: screen refraction, chromatic aberration and a
	# damage flicker driven by GameManager. Falls back to plain glass
	# when res://shaders/ContainmentDome.gdshader is absent.
	if dome == null:
		return
	if not ResourceLoader.exists("res://shaders/ContainmentDome.gdshader"):
		return
	var shader: Shader = load("res://shaders/ContainmentDome.gdshader")
	if shader == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("damage", 0.0)
	dome.material_override = mat

# ===== MapIntro.gd =====
# Opening cutscenes: a one-off story prologue and, behind it, the museum intro.
# Neither one owns a camera any more. Both are shot lists handed to Cutscene
# (res://game/Cutscene.gd), which owns the Camera3D, the letterbox, the
# captions, the cross-fades, the skip binding and the restore -- roughly 130
# lines of camera machinery that used to be inlined in this section. What is
# left here is the part that is actually about this map: which shots, where the
# camera stands, and when a player is allowed to see them.
# Inheritance chain:
#   FirstMuseumMap < MapIntro < MapDecor < MapLighting
#     < MapStructure < MapPrimitives < Node3D
# Every module sees the constants, vars and helpers of the
# modules below it; call sites stay unchanged.

# The cutscene currently on screen, or null. Runtime only; freed by itself.
var _cutscene: Cutscene = null

# --- When a cutscene is allowed to play --------------------------------------
# Both files belong to other scripts and are only read here (the two seen flags
# are the exception, see _mark_seen). Paths are
# duplicated rather than imported so the map never has to reach for GameManager:
# this scene is instantiated bare by the headless suites, where that node
# initializes two frames later than _ready() and would not have loaded the night
# yet.
const INTRO_SAVE_PATH := "user://museum_save.cfg"  # GameManager.SAVE_PATH
const INTRO_PROGRESS_PATH := "user://museum_progress.cfg"  # TutorialPrologue.PROGRESS_PATH


## RULE: both cutscenes are first-night, first-time-only. They play only when
## the saved night is 1 *and* the matching seen flag has not been written yet.
## Every other way into this scene -- continuing on night 2 or 3, "Main menu"
## from the pause screen, and the scene reload behind the win screen -- drops
## straight into the game with no cutscene. Two reasons: the intro's second
## caption reads "First night on duty", which is a plain lie on night 3, and
## _ready() runs on every one of those reloads, so an unconditional opening
## charges 91.5 s for each of them.
## Side effect worth knowing, not a contract: MenuManager._reset_progress()
## rewrites museum_progress.cfg wholesale, so "Reset progress" also clears both
## flags and a reset player is shown the whole opening again.
func _intro_should_play() -> bool:
	return _intro_saved_night() <= 1 and not _seen_flag("intro")


## The prologue is gated on its own flag in the same file, so the two can be
## retired independently -- and so that a build that ships the prologue to a
## player who already has intro/seen set still gets to show it once.
func _prologue_should_play() -> bool:
	return _intro_saved_night() <= 1 and not _seen_flag("story", "prologue_seen")


func _intro_saved_night() -> int:
	var config := ConfigFile.new()
	if config.load(INTRO_SAVE_PATH) != OK:
		return 1
	return maxi(1, int(config.get_value("progress", "night", 1)))


func _seen_flag(section: String, key := "seen") -> bool:
	var config := ConfigFile.new()
	if config.load(INTRO_PROGRESS_PATH) != OK:
		return false
	return bool(config.get_value(section, key, false))


## Written when a cutscene ends or is skipped, never when it merely starts, so
## quitting halfway through does not burn it.
## The flags live in the tutorial's progress file and not in museum_save.cfg
## because GameManager._save_night() rewrites that file from a fresh ConfigFile
## on every night change and would drop any key it does not know about. The
## load() below is what keeps tutorial/done, tutorial/skipped and the other
## cutscene's flag intact here.
func _mark_seen(section: String, key := "seen") -> void:
	var config := ConfigFile.new()
	config.load(INTRO_PROGRESS_PATH)
	config.set_value(section, key, true)
	config.save(INTRO_PROGRESS_PATH)


# --- Starting and chaining ---------------------------------------------------


## Entry point, called deferred from _ready(). Plays the prologue if it is owed,
## then the museum intro; on a returning player it plays neither.
func _start_opening() -> void:
	if Engine.is_editor_hint() or is_instance_valid(_cutscene):
		return
	# A cutscene borrows the player's camera and controls, and hands both back
	# when it ends. With no player in the tree there is nothing to borrow, and a
	# camera that took over the frame would never give it back. The map
	# verification suite instantiates this scene bare; that is the case this
	# guards, and it is why the old _start_intro() bailed on a null player too.
	if get_tree().get_first_node_in_group("player") == null:
		return
	if _prologue_should_play():
		_play(_prologue_shots(), _on_prologue_finished)
	elif _intro_should_play():
		_play(_intro_shots(), _on_intro_finished)


func _play(shots: Array, on_finished: Callable) -> void:
	_cutscene = Cutscene.new()
	_cutscene.name = "Opening Cutscene"
	add_child(_cutscene)
	# Connect before start(): a shot list that finishes synchronously (an empty
	# one, or one whose durations sum to zero) would otherwise emit into nothing
	# and leave the chain hanging.
	_cutscene.finished.connect(on_finished)
	_cutscene.start(shots)


func _on_prologue_finished(_skipped: bool) -> void:
	_cutscene = null
	_mark_seen("story", "prologue_seen")
	# Chained rather than concatenated into one shot list, because the two carry
	# separate flags: a player who skips the prologue on a first run and then
	# resets only that flag must still get the prologue back on its own.
	if _intro_should_play():
		_play(_intro_shots(), _on_intro_finished)


func _on_intro_finished(_skipped: bool) -> void:
	_cutscene = null
	_mark_seen("intro")


# --- The prologue ------------------------------------------------------------


## Roughly 78 s, once per save. It says out loud the five things the wall signs
## and terminal readouts only imply, in this order: the museum exhibits physical
## constants rather than objects; a containment core holds them stable; the
## player is the night operator of the Night Containment Service; a rift is both
## an accident and a door; and something already walks the halls.
##
## Shot budget is 8.0 s for a move and 7.0 s for a card. Cutscene's cross-fades
## cost a fixed fraction of each window (FADE_IN 0.12 + FADE_OUT 0.10), so 8.0 s
## leaves ~6.2 s of steady text -- enough for two sentences of prose at a first
## reading. The museum intro's 4.5 s leaves ~3.5 s, which is fine for four words
## and far too tight for these.
##
## Every camera position below stands in geometry this file actually builds:
## the forecourt walkway (x 0, z 35..55) and the facade sign at (0, 3.5, 35.2);
## Gravity Wing A (x 15..41, z -9..9) with its exhibit row at z = -4.5; the
## Atrium (x +-15, z +-15) with the containment dome on the origin and the
## rotunda columns at (+-11.5, +-11.5); the Watcher Office (x -35..-15,
## z +-7) with its monitor wall on the rail at (-25, 2.05, -2.20); and the
## Atrium -> Time Wing B doorway at z = -15. Paths were routed clear of the
## street lamps at x +-4.5, the forecourt benches at x +-8, the rotunda benches
## at radius 8.4, the hover-stone display at (28, 0, 5) and the office chair at
## (-25, 0, 1.35).
##
## STORY_PROLOGUE closes this list. It used to open the museum intro, and it
## moved here because it is a thesis line about night shifts and rifts, not a
## caption about this building -- and because both openings are gated on the
## same first run, so leaving it in place would have replayed the identical card
## eight seconds after the prologue's own last card.
func _prologue_shots() -> Array:
	return [
		# Title card over black, held above the road looking at the facade, so
		# the first fade-up lands on the building rather than on a moving frame.
		{"from": Vector3(0, 6.4, 61.0), "to": Vector3(0, 6.4, 61.0),
			"look": Vector3(0, 3.5, 35.2), "text": "STORY_PROLOGUE_01",
			"time": 7.0, "card": true},
		# Descent down the arrival axis. x = 0 keeps the camera off the two lamp
		# rows at x +-4.5, whose heads sit at y 3.25.
		{"from": Vector3(0, 6.4, 61.0), "to": Vector3(0, 4.4, 51.5),
			"look": Vector3(0, 3.2, 35.2), "text": "STORY_PROLOGUE_02",
			"time": 8.0, "card": false},
		# Across the west lawn towards the entrance portal, west of the lamp row
		# and 1.1 m above the forecourt bench at (-8, 0.45, 43.5). The move stops
		# at z = 43: pushed to z = 41 the sightline to the portal crossed the lamp
		# post at (-4.5, ., 39.5) and put a black pole through the frame centre
		# for the last second of the shot.
		{"from": Vector3(-8.0, 2.3, 48.5), "to": Vector3(-7.0, 2.15, 43.0),
			"look": Vector3(0, 2.6, 35.0), "text": "STORY_PROLOGUE_03",
			"time": 8.0, "card": false},
		# Gravity Wing A, trucking east across the exhibit row towards the
		# Levitating Column and the Bronze Apple. z = 3.0 stays 2 m clear of the
		# hover-stone display at (28, 0, 5); the aim point is deliberately the
		# EAST end of the row and not its middle, because the west end holds the
		# Falling Cube, whose placeholder .glb is a giant rubber duck. Both ends
		# of this move keep it more than 80 deg off the optical axis, well
		# outside the ~50 deg half-frustum a 66 deg vertical fov gives at 16:9.
		{"from": Vector3(26.0, 2.3, 3.0), "to": Vector3(34.0, 2.3, 3.0),
			"look": Vector3(38.0, 1.6, -6.0), "text": "STORY_PROLOGUE_04",
			"time": 8.0, "card": false},
		# Atrium, descending the north-south axis onto the containment dome.
		{"from": Vector3(0, 3.0, 12.5), "to": Vector3(0, 2.2, 6.5),
			"look": Vector3(0, 1.4, 0), "text": "STORY_PROLOGUE_05",
			"time": 8.0, "card": false},
		# Lateral truck past the core at eye height, outside the 2.6 m stanchion
		# ring and above the 0.16 m rotunda kerb.
		{"from": Vector3(4.6, 1.9, 4.6), "to": Vector3(-4.6, 1.9, 4.6),
			"look": Vector3(0, 1.35, 0), "text": "STORY_PROLOGUE_06",
			"time": 8.0, "card": false},
		# Watcher Office: over the chair, over the desk, onto the six monitors.
		{"from": Vector3(-25.0, 1.95, 2.4), "to": Vector3(-25.0, 1.8, 0.35),
			"look": Vector3(-25.0, 2.05, -2.2), "text": "STORY_PROLOGUE_07",
			"time": 8.0, "card": false},
		# Atrium again, walking into the Time Wing B doorway and looking through
		# it. Stops at z = -12.8, short of the arch prop at z = -15.5. The aim
		# point is the Great Hourglass in its case at (0, ., -20), five metres
		# past the door: the doorway becomes a frame around an exhibit instead of
		# around bare floor, which is the whole point of the caption.
		{"from": Vector3(0, 1.8, -7.5), "to": Vector3(0, 1.75, -12.8),
			"look": Vector3(0, 1.7, -20.0), "text": "STORY_PROLOGUE_08",
			"time": 8.0, "card": false},
		# The unease beat: a slow creep out of the north-west quarter of an
		# empty Atrium, aimed diagonally at the far column, the dome in between.
		{"from": Vector3(-9.4, 1.7, 9.4), "to": Vector3(-7.8, 1.7, 7.8),
			"look": Vector3(11.5, 2.0, -11.5), "text": "STORY_PROLOGUE_09",
			"time": 8.0, "card": false},
		# Closing card, on the spot the previous shot ended.
		{"from": Vector3(-7.8, 1.7, 7.8), "to": Vector3(-7.8, 1.7, 7.8),
			"look": Vector3(11.5, 2.0, -11.5), "text": "STORY_PROLOGUE",
			"time": 7.0, "card": true},
	]


# --- The museum intro --------------------------------------------------------


## Three 4.5 s camera shots on the forecourt, 13.5 s in total, unchanged from
## the day they were authored except that the STORY_PROLOGUE title card that
## used to open them now closes the prologue instead (see _prologue_shots).
func _intro_shots() -> Array:
	return [
		{"from": Vector3(26, 13, 63), "to": Vector3(15, 9, 58),
			"look": Vector3(0, 3.0, 35), "text": "HUD_INTRO_MUSEUM",
			"time": 4.5, "card": false},
		{"from": Vector3(-12, 1.5, 53), "to": Vector3(-5, 1.7, 48),
			"look": Vector3(0, 3.4, 35.2), "text": "HUD_INTRO_FIRST_NIGHT",
			"time": 4.5, "card": false},
		{"from": Vector3(0, 2.4, 53), "to": Vector3(0, 1.75, 46.6),
			"look": Vector3(0, 1.8, 35), "text": "HUD_INTRO_CHECK_HALLS",
			"time": 4.5, "card": false},
	]

# ===== FirstMuseumMap.gd =====
# Top-level orchestrator of the procedural museum map (PS1 horror).
# The heavy lifting lives in the inherited modules:
#   MapPrimitives - constants, materials, primitive helpers
#   MapStructure  - rooms, walls, doors, cameras, player spawn
#   MapLighting   - environment, room lights, blackout
#   MapDecor      - exhibits, furnishings, street, dome shader
#   MapIntro      - opening cutscenes (shot lists for game/Cutscene.gd)
# All files must sit in the project together (e.g. res://game/).

var _flicker_time := 0.0

## The museum's wayfinding net -- game/Compass.gd, installed and fed by
## game/NavigationDirector.gd. Null in the editor and if the director could not
## install; see _install_navigation_aid().
var _nav_aid: NavigationDirector = null

@export_category("Editable generated layout")
@export_multiline var layout_help := "GeneratedMap is saved with the scene. Expand it and move, rotate, scale, duplicate or delete any object, then save the scene. Toggle Rebuild Generated Layout only when you want to discard manual placement and regenerate the default museum."
@export var rebuild_generated_layout := false:
	set(value):
		if value and Engine.is_editor_hint() and is_inside_tree():
			_rebuild_generated_map()
		rebuild_generated_layout = false


func _ready() -> void:
	# GameManager finds the map through this group.
	add_to_group("museum_map")
	# Generated geometry is now owned by this scene and therefore remains fully
	# editable in the Godot scene tree. Do not rebuild it automatically: manual
	# transforms must survive editor reloads and scene saves.
	if get_node_or_null("GeneratedMap") == null:
		build_map()
	else:
		# A layout saved into the scene skips build_map(), but the Curator still
		# needs a navigation mesh over whatever geometry that layout contains.
		_ensure_navigation()
		# ...and the blackout still needs to know which lamps are the mains.
		# Editor-side this stays untouched: hiding the battery lamps there would
		# be a scene edit rather than a runtime state.
		if not Engine.is_editor_hint():
			_adopt_serialized_lighting()
	# In game (not in the editor) the map may open with the story prologue and
	# the museum intro. _start_opening() decides for itself whether this entry
	# deserves either -- see _prologue_should_play() / _intro_should_play(); both
	# are first-night, first-time-only pieces, and this _ready() also runs on
	# every return to the menu and after the win screen.
	if not Engine.is_editor_hint():
		call_deferred("_start_opening")
		_install_navigation_aid()


## Install the museum's wayfinding net.
##
## game/Compass.gd and game/NavigationDirector.gd are a finished feature that,
## until this call, only the optional tutorial scene ever instantiated -- so on
## the shipping path the owner's fourth complaint, "непонятно, где я и куда
## идти", was still true of every one of the eleven rooms. This is the line that
## puts it in the museum.
##
## WHAT THE DIRECTOR NEEDS, AND WHERE EACH PIECE COMES FROM. Nothing is passed
## in, and that is the design rather than an omission: every input has exactly
## one owner already, and handing over a second copy would create a number that
## can disagree with the first.
##
##   the player     -- Compass._initialize() takes the "player" group, which
##                     PlayerController._ready() joins. _add_player_spawn()
##                     builds that node, so it exists before this runs.
##   the objective  -- Compass._update_target() reads GameManager's `_state`,
##                     `_carried_id` and the exhibit puzzle controller's
##                     get_incident_origin(), i.e. the same night loop that
##                     writes the objective band. The director only overrides it
##                     when a caller asks for aim_at(); the museum does not, so
##                     the arrow follows the shift: office, then storage, then
##                     the incident.
##   the room table -- SecurityCameraTablet.ROOMS, read out of the script
##                     constant map. The eleven rectangles test_map_verification
##                     already pins to this file's own geometry.
##   disturbance    -- Compass.signal_quality() reads THIS node's
##                     `_blackout_done` and the Curator out of
##                     GameplayEnhancements' `_watcher`; the director adds the
##                     breach clock and per-night wear on top as a floor.
##
## The director is installed under this node, which is the scene root, so the
## Compass node it builds lands beside GameManager and SecurityCameraTablet --
## the sibling relationship both of those files resolve each other through.
## install() is idempotent, which matters because this _ready() runs again on
## every return from the menu and after the win screen.
##
## THE HORROR CONSTRAINT IS NOT WAIVED HERE. All three readouts are on, and all
## three still die with the building: after the blackout the net drops to
## DEGRADED everywhere outside the security office, and inside the Curator's
## 27 m it goes DOWN and the room name becomes a last fix. Turning any of that
## off would need code in Compass, not a flag here -- which is the right shape.
func _install_navigation_aid() -> void:
	_nav_aid = NavigationDirector.install(self)
	if _nav_aid == null:
		push_warning("FirstMuseumMap: navigation aid could not be installed")
		return
	# Room readout, objective bearing, held-open floor plan. Stated rather than
	# left to the director's defaults: this scene is the museum, its room table
	# IS the museum's, so all three are meaningful here -- unlike the tutorial
	# sector, which asks for the bearing alone.
	_nav_aid.set_features(true, true, true)


# The signage fixup that used to live here is gone: SecurityCameraTablet now
# clears CCTV_HIDDEN_MASK itself, in the same breath as it sets each feed's fov.
# The hand-off note asked for that move, and it had become urgent rather than
# tidy -- the feed cameras hang inside SubViewports since stage 10.1, so a
# fixup that walked this node's Camera3D children would have found none and
# said nothing about it.


func _process(delta: float) -> void:
	# First, before any early return below: an owed navmesh rebake outranks
	# lighting. The cutscene check would otherwise stall it for the whole
	# opening, and a night-3 resume can owe one during exactly that.
	_nav_watchdog()
	# Daytime intro keeps steady lighting. Once the player reaches the
	# office the blackout fires and only the red emergency light pulses.
	if Engine.is_editor_hint():
		return
	# The cutscene drives its own camera from its own _process; the map only has
	# to stay out of the way. Holding the blackout check here still matters: it
	# fires on the player's position, and the player is parked at the spawn with
	# controls disabled for the whole opening.
	if is_instance_valid(_cutscene) and _cutscene.is_playing():
		return
	if not _blackout_done:
		_check_blackout()
		return
	_flicker_time += delta
	if is_instance_valid(_emergency_light):
		var settings := get_tree().get_first_node_in_group("settings_manager")
		var pulse_strength := 0.12 if settings != null and settings.reduced_flashes else 0.45
		_emergency_light.light_energy = 0.9 + pulse_strength * (0.5 + 0.5 * sin(_flicker_time * 2.4))


func _rebuild_generated_map() -> void:
	var old_map := get_node_or_null("GeneratedMap")
	if old_map != null:
		old_map.free()
	build_map()


func _make_generated_map_editable(node: Node) -> void:
	# Assigning an owner serializes generated children into FirstMuseumMap.tscn.
	# Every MeshInstance3D/Node3D then behaves like a normal editor object.
	if node != self:
		node.owner = self
	for child in node.get_children():
		_make_generated_map_editable(child)


func build_map() -> void:
	var map_root := Node3D.new()
	map_root.name = "GeneratedMap"
	add_child(map_root)

	_add_world_env(map_root)

	# Rooms are packed wall-to-wall. The `doors` dict says which of the four
	# walls (N=-z, S=+z, E=+x, W=-x) carry a doorway gap onto the shared
	# neighbour; every other wall is solid. Centers are chosen so shared walls
	# coincide: center_A +/- size/2 == center_B -/+ size/2.
	#
	# Layout (top-down, +z = south):
	#
	#          [ Archive ](-25,-12)   [ Time Wing B ](0,-24)
	#                |                        |
	#          [ Watcher Office ](-25,0) -- [ Central Atrium ](0,0) -- [ Gravity Wing A ](28,0) -- [ Mass D ](52,0)
	#                |                        |
	#          [ Storage ](-25,12)     [ Entrance Zone ](0,25)
	#                                                        [ Space Wing C ](24,-24) (locked, east of Time)
	# White-marble museum palette. The entrance also opens south onto the
	# street: the game now starts outside in daylight.
	#
	# The second argument of each call is the NODE name and the third is the
	# catalogue key the room's sign is drawn from. They are index-aligned with
	# SecurityCameraTablet.ROOMS -- same eleven rooms, same eleven keys -- so the
	# name on the wall and the name on the mini-map are one row of game.csv.
	_add_room(map_root, "Entrance Zone", "CAM_ENTRANCE",
		Vector3(0, 0, 25), Vector2(22, 20),
		Color(0.85, 0.84, 0.81), {"N": DOOR_GAP, "S": DOOR_GAP})
	_add_room(map_root, "Central Atrium", "CAM_ROOM_ATRIUM",
		Vector3(0, 0, 0), Vector2(30, 30),
		Color(0.88, 0.87, 0.85),
		{"N": DOOR_GAP, "S": DOOR_GAP, "E": DOOR_GAP, "W": DOOR_GAP})
	_add_room(map_root, "Watcher Office", "CAM_ROOM_OFFICE",
		Vector3(-25, 0, 0), Vector2(20, 14),
		Color(0.55, 0.57, 0.58), {"E": DOOR_GAP, "N": DOOR_GAP, "S": DOOR_GAP})
	_add_room(map_root, "Equipment Storage", "CAM_ROOM_STORAGE",
		Vector3(-25, 0, 12), Vector2(20, 10),
		Color(0.52, 0.52, 0.48), {"N": DOOR_GAP, "S": DOOR_GAP})
	_add_room(map_root, "Archive", "CAM_ROOM_ARCHIVE",
		Vector3(-25, 0, -12), Vector2(20, 10),
		Color(0.60, 0.58, 0.54), {"S": DOOR_GAP})
	_add_room(map_root, "Gravity Wing A", "CAM_ROOM_WING_A",
		Vector3(28, 0, 0), Vector2(26, 18),
		Color(0.78, 0.81, 0.86), {"W": DOOR_GAP, "E": DOOR_GAP})
	_add_room(map_root, "Time Wing B", "CAM_ROOM_WING_B",
		Vector3(0, 0, -24), Vector2(26, 18),
		Color(0.85, 0.79, 0.70), {"S": DOOR_GAP, "N": DOOR_GAP, "E": DOOR_GAP})
	# Wings C and D now have real doorways, sealed by blast doors until
	# nights 2 and 3 (see _add_locked_doors / unlock_wing in MapStructure). Their
	# signs name the wing, not its lock: the blast door in front of the player is
	# already saying the room is shut, and it says so in its own notice.
	_add_room(map_root, "Space Wing C Locked", "CAM_ROOM_WING_C",
		Vector3(24, 0, -24), Vector2(22, 16),
		Color(0.68, 0.70, 0.75), {"W": DOOR_GAP})
	_add_room(map_root, "Mass Wing D Locked", "CAM_ROOM_WING_D",
		Vector3(52, 0, 0), Vector2(22, 16),
		Color(0.76, 0.72, 0.63), {"W": DOOR_GAP})
	# New annexes: a planetarium behind Time Wing and a restoration lab
	# behind Storage.
	_add_room(map_root, "Planetarium", "CAM_PLANETARIUM",
		Vector3(0, 0, -41), Vector2(20, 16),
		Color(0.62, 0.65, 0.78), {"S": DOOR_GAP})
	_add_room(map_root, "Restoration Lab", "CAM_ROOM_LAB",
		Vector3(-25, 0, 22), Vector2(20, 10),
		Color(0.72, 0.68, 0.66), {"N": DOOR_GAP})

	# Door frames dress the seam on the shared wall between two rooms with
	# jambs, threshold and lintel. axis "x" = east-west wall (door faces N/S),
	# axis "z" = north-south wall (door faces E/W).
	_add_door_frame(map_root, Vector3(0, 0, 15), "x")     # Atrium <-> Entrance
	_add_door_frame(map_root, Vector3(-15, 0, 0), "z")    # Atrium <-> Watcher Office
	_add_door_frame(map_root, Vector3(15, 0, 0), "z")     # Atrium <-> Gravity Wing
	_add_door_frame(map_root, Vector3(0, 0, -15), "x")    # Atrium <-> Time Wing
	_add_door_frame(map_root, Vector3(-25, 0, 7), "x", true)    # Office <-> Storage
	_add_door_frame(map_root, Vector3(-25, 0, -7), "x", true)   # Office <-> Archive
	_add_door_frame(map_root, Vector3(0, 0, -33), "x")          # Time Wing <-> Planetarium
	_add_door_frame(map_root, Vector3(-25, 0, 17), "x", true)   # Storage <-> Restoration Lab
	_add_door_frame(map_root, Vector3(0, 0, 35), "x")           # Entrance <-> Street
	_add_door_frame(map_root, Vector3(13, 0, -24), "z")         # Time Wing <-> Space Wing C
	_add_door_frame(map_root, Vector3(41, 0, 0), "z")           # Gravity Wing <-> Mass Wing D

	_add_room_lights(map_root)
	_add_atrium_landmarks(map_root)
	_add_atrium_decor(map_root)
	# The containment core, its signage, the rope barrier, the cable runs, the
	# reception desk and the directory board. This must run AFTER
	# _add_atrium_decor (which is where the old thin core used to be built from
	# _add_furnishings) and BEFORE _add_navigation, so its 45 static bodies are
	# in the tree when the bake walks the map. It rebuilds "Anomalous Core" and
	# "Containment Dome" under those exact names for GameManager's two find_child
	# lookups -- see the note in _add_furnishings.
	AtriumProps.build_atrium(map_root, Vector3.ZERO)
	_add_entrance_details(map_root)
	_add_office_details(map_root)
	_add_storage_props(map_root)
	# Both room builders are pure composition around their own room centre.
	ArchiveProps.build_archive(map_root, Vector3(-25, 0, -12))
	_add_exhibits(map_root)
	_add_planetarium_details(map_root)
	_add_lab_details(map_root)
	_add_extra_exhibits(map_root)
	_add_furnishings(map_root)
	_add_more_interior(map_root)
	_add_service_fittings(map_root)
	_add_light_fittings(map_root)
	_add_outdoor(map_root)
	_add_street_extras(map_root)
	_add_cameras(map_root)
	_add_locked_doors(map_root)
	_add_player_spawn(map_root)
	_add_navigation(map_root)

	if Engine.is_editor_hint():
		_make_generated_map_editable(map_root)
