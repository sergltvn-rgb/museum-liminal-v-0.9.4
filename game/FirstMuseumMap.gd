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
	_cone(parent, "Plant Pot", plant_position + Vector3(0, 0.26, 0),
		0.3, 0.36, 0.52, Color(0.17, 0.1, 0.07))
	for i in range(6):
		var a: float = TAU * float(i) / 6.0 + plant_position.x * 0.7
		var leaf := _prism(parent, "Plant Leaf %d" % i,
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
		horizontal := false, emission_energy := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = radius
	mesh.top_radius = radius
	var size := Vector3(radius * 2.0, height, radius * 2.0)
	var inst := _primitive(parent, node_name, cylinder_position, mesh, size,
		color, false, emission_energy, 0.0)
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


func _add_label(parent: Node, text: String, label_position: Vector3,
		color: Color) -> void:
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


func _add_room(parent: Node, room_name: String, center: Vector3, size: Vector2,
		floor_color: Color, doors: Dictionary = {}) -> void:
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
	_add_label(room, room_name, Vector3(0, 2.2, size.y * 0.5 - 0.8),
		Color(0.24, 0.27, 0.24))


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
# node name: the mount is either an imported .fbx root or a procedural pivot,
# and its display name is a localizable string.
const SECURITY_CAMERA_GROUP := "security_camera"


func _add_cameras(parent: Node) -> void:
	# Mounted in room corners like real CCTV, each yawed to sweep its room
	# (they used to hang mid-wall staring straight ahead).
	_camera(parent, "Камера 01 - Entrance", Vector3(-9.6, 3.0, 33.6), -48.0)
	_camera(parent, "Камера 02 - Atrium West", Vector3(-13.6, 3.0, 12.6), -47.0)
	_camera(parent, "Камера 03 - Atrium East", Vector3(13.6, 3.0, -12.6), 133.0)
	_camera(parent, "Камера 04 - Watcher Office", Vector3(-33.8, 2.9, -5.8), -123.0)
	_camera(parent, "Камера 05 - Gravity Wing A", Vector3(16.4, 3.0, -7.8), -124.0)
	_camera(parent, "Камера 06 - Time Wing B", Vector3(-11.8, 3.0, -16.4), -57.0)
	_camera(parent, "Камера 07 - Space Wing C Door", Vector3(9.6, 2.9, -20.6), -41.0)
	_camera(parent, "Камера 08 - Basement Elevator", Vector3(8.8, 2.9, 11.8), -125.0)
	_camera(parent, "Камера 09 - Planetarium", Vector3(-9.2, 3.0, -34.4), -54.0)
	_camera(parent, "Камера 10 - Restoration Lab", Vector3(-33.8, 2.9, 18.4), -112.0)
	_camera(parent, "Камера 11 - Mass Wing D", Vector3(42.2, 2.9, -6.8), -118.0)


func _camera(parent: Node, camera_name: String, camera_position: Vector3,
		yaw := 0.0) -> void:
	var model := MuseumModels.place(parent, "security_camera", camera_position, 1.0, yaw)
	if model != null:
		# The .fbx root carries the same name for all eleven placements, so Godot
		# auto-suffixes them (@camera@2, ...). Name each mount after its post.
		model.name = camera_name
		model.add_to_group(SECURITY_CAMERA_GROUP, true)
		_add_label(parent, camera_name, camera_position + Vector3(0, 0.3, 0),
			Color(0.35, 0.95, 0.78))
		return
	# Grouped under a pivot so body, lens and LED tilt down together (the
	# old lens was a vertical cylinder poking out of the housing).
	var cam := Node3D.new()
	cam.name = camera_name
	cam.position = camera_position
	cam.rotation_degrees = Vector3(-14, yaw, 0)
	parent.add_child(cam)
	cam.add_to_group(SECURITY_CAMERA_GROUP, true)
	_box(cam, "%s Mount Arm" % camera_name, Vector3(0, 0.24, 0.12),
		Vector3(0.07, 0.2, 0.07), Color(0.04, 0.04, 0.04), 0.0, 0.0, false)
	_box(cam, "%s Body" % camera_name, Vector3(0, 0, 0),
		Vector3(0.5, 0.28, 0.34), Color(0.03, 0.035, 0.035))
	var lens := _cylinder(cam, "%s Lens" % camera_name, Vector3(0, 0, -0.24),
		0.09, 0.14, Color(0.01, 0.08, 0.07))
	lens.rotation_degrees = Vector3(90, 0, 0)
	_box(cam, "%s LED" % camera_name, Vector3(0.17, 0.08, -0.18),
		Vector3(0.04, 0.04, 0.04), Color(0.9, 0.1, 0.08), 1.8, 0.0, false)


func _add_locked_doors(parent: Node) -> void:
	# Space Wing C blast door: the shared wall x=13 now has a real doorway,
	# sealed by this door until night 2 (see unlock_wing).
	_box(parent, "Wing C Locked Blast Door", Vector3(12.52, 1.25, -24),
		Vector3(0.22, 2.5, 3.5), Color(0.035, 0.04, 0.055), 0.0, 0.5)
	_add_label(parent, "Space Wing C - opens on Night 2", Vector3(12.3, 2.8, -24),
		Color(0.55, 0.65, 0.95))
	# Mass Wing D blast door on the Gravity Wing east wall (x=41), night 3.
	_box(parent, "Wing D Locked Blast Door", Vector3(40.52, 1.25, 0),
		Vector3(0.22, 2.5, 3.5), Color(0.05, 0.04, 0.03), 0.0, 0.5)
	_add_label(parent, "Mass Wing D - opens on Night 3", Vector3(40.3, 2.8, 0),
		Color(0.8, 0.65, 0.42))
	# Causality Wing E sealed door on the Office west wall (x=-35).
	_box(parent, "Causality Wing E Sealed Door", Vector3(-34.53, 1.25, 0),
		Vector3(0.22, 2.5, 3.6), Color(0.055, 0.025, 0.025), 0.0, 0.5)
	_add_label(parent, "Causality Wing E - do not schedule",
		Vector3(-34.3, 2.8, 0), Color(0.95, 0.25, 0.18))


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
	_add_label(root, "%s - OPEN" % wing, label_pos, Color(0.45, 0.95, 0.6))
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
	call_deferred("_bake_navigation")


## Rebuild the navigation mesh. The bake itself runs on a worker thread, so
## this is cheap enough to call again whenever the layout changes.
func _bake_navigation() -> void:
	if not is_instance_valid(_nav_region) or not _nav_region.is_inside_tree():
		return
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
	shaft.spot_angle = 24.0
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
		_cylinder(parent,"Колонна ротонды",p+Vector3(0,WALL_HEIGHT*.5,0),.42,WALL_HEIGHT,Color(.16,.16,.155))
	for angle:float in [0.0,90.0,180.0,270.0]:
		var r:=deg_to_rad(angle); var bench:=_box(parent,"Скамья ротонды",Vector3(cos(r)*8.4,.35,sin(r)*8.4),Vector3(2.5,.55,.68),Color(.19,.16,.13)); bench.rotation_degrees.y=-angle
	_add_label(parent,tr("EXHIBIT_CONTAINMENT_CORE"),Vector3(0,3.0,4.8),Color(.34,.72,.62))


func _add_atrium_decor(parent: Node) -> void:
	_box(parent,"Ось север-юг",Vector3(0,.015,0),Vector3(.10,.025,27),Color(.38,.31,.16),.2,.5,false)
	_box(parent,"Ось запад-восток",Vector3(0,.016,0),Vector3(27,.025,.10),Color(.38,.31,.16),.2,.5,false)
	for p:Vector3 in [Vector3(-10.8,0,10.8),Vector3(10.8,0,10.8)]:_add_plant(parent,p)


func _add_entrance_details(parent: Node) -> void:
	# Последовательность: внешний портал, тамбур, свободное фойе.
	# Портал — два пилона и перемычка: центральный проход всегда свободен днём.
	_box(parent,"Пилон входа — запад",Vector3(-3.7,1.65,34.45),Vector3(2.2,3.3,.34),Color(.20,.21,.22))
	_box(parent,"Пилон входа — восток",Vector3(3.7,1.65,34.45),Vector3(2.2,3.3,.34),Color(.20,.21,.22))
	_box(parent,"Перемычка входа",Vector3(0,3.12,34.45),Vector3(9.6,.42,.34),Color(.20,.21,.22))
	for x:float in [-2.75,2.75]:_glass_case(parent,"Стена тамбура",Vector3(x,1.45,31.9),Vector3(.10,2.9,4.8))
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

	# L-shaped command desk with grounded cabinets and cable management.
	var desk_wood := Color(0.17, 0.12, 0.085)
	var desk_metal := Color(0.055, 0.062, 0.068)
	_box(parent, "Security Desk Main Top", Vector3(-25, 1.02, -1.0),
		Vector3(6.2, 0.14, 1.65), desk_wood, 0.0, 0.15)
	_box(parent, "Security Desk Return Top", Vector3(-28.35, 1.02, 1.15),
		Vector3(1.45, 0.14, 4.4), desk_wood, 0.0, 0.15)
	for leg in [Vector3(-27.8, 0.5, -1.65), Vector3(-22.2, 0.5, -1.65),
			Vector3(-27.8, 0.5, -0.35), Vector3(-22.2, 0.5, -0.35),
			Vector3(-28.8, 0.5, 2.85), Vector3(-27.9, 0.5, 2.85)]:
		_box(parent, "Security Desk Leg", leg, Vector3(0.16, 1.0, 0.16),
			desk_metal, 0.0, 0.7)
	_box(parent, "Desk Cable Modesty Panel", Vector3(-25, 0.62, -1.72),
		Vector3(5.3, 0.72, 0.08), desk_metal, 0.0, 0.35)
	# Drawer pedestal supports the return and prevents floating props.
	_box(parent, "Desk Drawer Pedestal", Vector3(-28.35, 0.5, 2.25),
		Vector3(1.15, 1.0, 1.25), Color(0.09, 0.095, 0.10), 0.0, 0.5)
	for drawer_y in [0.25, 0.53, 0.81]:
		_box(parent, "Desk Drawer Front", Vector3(-27.76, drawer_y, 2.25),
			Vector3(0.025, 0.22, 1.02), Color(0.14, 0.145, 0.15), 0.0, 0.45, false)

	# Six individually framed CCTV displays on a proper wall rail.
	_box(parent, "CCTV Wall Rail", Vector3(-25, 2.05, -2.20),
		Vector3(6.4, 1.62, 0.12), Color(0.025, 0.030, 0.034), 0.0, 0.55)
	for row in range(2):
		for col in range(3):
			var monitor_x := -27.15 + float(col) * 2.15
			var monitor_y := 1.70 + float(row) * 0.67
			_box(parent, "CCTV Monitor Housing %d-%d" % [row, col],
				Vector3(monitor_x, monitor_y, -2.11), Vector3(1.92, 0.59, 0.11),
				Color(0.035, 0.040, 0.045), 0.0, 0.5, false)
			var screen_color := Color(0.025, 0.18 + float(col) * 0.025,
				0.16 + float(row) * 0.03)
			_box(parent, "CCTV Feed %d-%d" % [row, col],
				Vector3(monitor_x, monitor_y, -2.045), Vector3(1.72, 0.43, 0.025),
				screen_color, 0.42 + float((row + col) % 2) * 0.12, 0.0, false)
			_box(parent, "CCTV REC %d-%d" % [row, col],
				Vector3(monitor_x + 0.72, monitor_y + 0.16, -2.02),
				Vector3(0.045, 0.045, 0.018), Color(0.9, 0.04, 0.03), 1.4, 0.0, false)

	# Physical CCTV control console: the tablet UI can only open in this room.
	_box(parent, "CCTV Control Console", Vector3(-25, 1.15, -0.72),
		Vector3(2.25, 0.16, 0.78), Color(0.055, 0.07, 0.075), 0.0, 0.5)
	_box(parent, "CCTV Keyboard", Vector3(-25.35, 1.245, -0.54),
		Vector3(0.92, 0.035, 0.28), Color(0.025, 0.028, 0.03), 0.0, 0.0, false)
	_box(parent, "CCTV Trackball", Vector3(-24.45, 1.255, -0.52),
		Vector3(0.28, 0.045, 0.28), Color(0.08, 0.12, 0.12), 0.25, 0.25, false)
	_add_label(parent, "CCTV ACCESS — TAB / Y", Vector3(-25, 1.48, -0.72),
		Color(0.35, 0.95, 0.78))

	# Alarm terminal remains at the coordinates used by GameManager.
	_box(parent, "Alarm Terminal Pedestal", Vector3(-29, 0.55, 3.1),
		Vector3(1.65, 1.1, 0.95), Color(0.075, 0.055, 0.052), 0.0, 0.4)
	_box(parent, "Alarm Terminal", Vector3(-29, 1.18, 3.1),
		Vector3(1.45, 0.22, 0.72), Color(0.18, 0.025, 0.02), 0.65, 0.2)
	_box(parent, "Alarm Emergency Button", Vector3(-28.45, 1.34, 3.1),
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
		_box(parent, "Locker Shelf", Vector3(-33.35, shelf_y, 4.45),
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

	# Desk props are placed directly on the 1.09 m tabletop.
	_box(parent, "Office Phone", Vector3(-23.1, 1.16, -0.65),
		Vector3(0.62, 0.16, 0.42), Color(0.025, 0.025, 0.023), 0.0, 0.2, false)
	_cylinder(parent, "Coffee Mug", Vector3(-27.15, 1.19, -0.55),
		0.075, 0.20, Color(0.38, 0.08, 0.06))
	_box(parent, "Shift Log", Vector3(-26.45, 1.13, -0.55),
		Vector3(0.62, 0.045, 0.84), Color(0.32, 0.24, 0.13), 0.0, 0.0, false)
	_box(parent, "Radio Charger", Vector3(-28.35, 1.16, 1.05),
		Vector3(0.42, 0.16, 0.36), Color(0.04, 0.045, 0.05), 0.15, 0.3, false)
	_cylinder(parent, "Security Radio", Vector3(-28.35, 1.43, 1.05),
		0.07, 0.48, Color(0.035, 0.04, 0.045))
	_box(parent, "Shift Printer", Vector3(-28.35, 1.31, 2.25),
		Vector3(0.95, 0.42, 0.75), Color(0.42, 0.43, 0.40), 0.0, 0.15)

	# Detailed procedural swivel chair, always correctly scaled.
	_box(parent, "Office Chair Seat", Vector3(-25, 0.54, 1.35),
		Vector3(0.62, 0.12, 0.62), Color(0.045, 0.05, 0.055))
	_box(parent, "Office Chair Back", Vector3(-25, 1.02, 1.62),
		Vector3(0.62, 0.82, 0.10), Color(0.04, 0.045, 0.05))
	_cylinder(parent, "Office Chair Post", Vector3(-25, 0.30, 1.35),
		0.055, 0.42, Color(0.10, 0.11, 0.12))
	for angle in range(0, 360, 72):
		var rad := deg_to_rad(float(angle))
		var foot := Vector3(-25 + cos(rad) * 0.34, 0.09, 1.35 + sin(rad) * 0.34)
		_box(parent, "Office Chair Foot", foot, Vector3(0.34, 0.06, 0.08),
			Color(0.09, 0.10, 0.11), 0.0, 0.55)

	# Cable trays and practical task lighting finish the room.
	_box(parent, "Office Cable Tray", Vector3(-25, 3.05, -2.25),
		Vector3(7.0, 0.10, 0.34), Color(0.055, 0.06, 0.065), 0.0, 0.6, false)
	for light_x in [-27.0, -23.0]:
		var task_light := SpotLight3D.new()
		task_light.name = "Office Task Light"
		task_light.position = Vector3(light_x, 2.9, -0.4)
		task_light.rotation_degrees = Vector3(-90, 0, 0)
		task_light.light_color = Color(0.72, 0.84, 0.92)
		task_light.light_energy = 0.85
		task_light.spot_range = 4.0
		task_light.spot_angle = 42.0
		task_light.shadow_enabled = true
		parent.add_child(task_light)
		_powered_lights.append(task_light)

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
	# not a loose collection of spheres.
	_torus(parent, "Superheavy Containment Ring", Vector3(52, 1.28, 0),
		1.05, 1.18, Color(0.42, 0.30, 0.12), 0.25, true)
	for x in [56.8, 59.2]:
		_box(parent, "Mass Pendulum Frame", Vector3(x, 1.65, 4),
			Vector3(0.16, 2.7, 0.16), Color(0.10, 0.11, 0.12), 0.0, 0.6)
	_box(parent, "Mass Pendulum Crossbar", Vector3(58, 2.95, 4),
		Vector3(2.6, 0.16, 0.16), Color(0.10, 0.11, 0.12), 0.0, 0.6)
	_add_label(parent, tr("EXHIBIT_WING_D_SIGN"),
		Vector3(52, 2.9, 7.2), Color(0.8, 0.65, 0.42))

	# Per-exhibit accent lights follow the new gallery rows.
	for pos in [Vector3(21.5, 2.4, -4.5), Vector3(28, 2.4, -4.5), Vector3(35.5, 2.4, -4.5)]:
		var l := OmniLight3D.new()
		l.position = pos
		l.light_energy = 0.4
		l.omni_range = 6.0
		l.light_color = Color(0.5, 0.6, 0.9)
		parent.add_child(l)
	for pos in [Vector3(-8, 2.4, -27.5), Vector3(0, 2.4, -27.5), Vector3(8, 2.4, -27.5)]:
		var l := OmniLight3D.new()
		l.position = pos
		l.light_energy = 0.4
		l.omni_range = 6.0
		l.light_color = Color(0.95, 0.7, 0.45)
		parent.add_child(l)
	_add_model_archive(parent)


func _add_model_archive(parent: Node) -> void:
	# Collection-storage dressing: every supplied source model is represented,
	# while authored exhibits above retain their procedural safety fallbacks.
	var placements := [
		["basic_pc_monitors", Vector3(-27.0, 1.25, -0.8), 0.75, 180.0],
		["fancy_marble_coffee_table", Vector3(-20.0, 0.0, 5.0), 0.75, 0.0],
		["wooden_bookcases_with_books", Vector3(-31.0, 0.0, -4.2), 0.8, 90.0],
		["elderly_woman_bust_on_pedestal", Vector3(38.0, 0.0, -13.0), 0.85, 180.0],
		["vents", Vector3(-18.0, 2.8, -5.5), 0.65, 0.0],
		["tactical_flashlight", Vector3(-23.0, 1.2, -0.8), 0.55, 25.0],
		["лавочки", Vector3(8.0, 0.0, -8.0), 0.75, 90.0],
		["уличная лампа", Vector3(12.0, 0.0, -10.0), 0.7, 0.0],
		["арка дверь", Vector3(0.0, 0.0, -15.5), 0.85, 0.0],
		["тумбочка", Vector3(-21.0, 0.0, 1.5), 0.7, 0.0],
		["отсановка", Vector3(46.0, 0.0, -12.0), 0.6, 90.0],
		["dumpsters_glb", Vector3(-34.0, 0.0, 7.0), 0.65, 0.0],
		["gallery_bare_concrete_wall", Vector3(60.0, 0.0, -8.0), 0.7, 90.0],
		["modern_grey_stone_tile_texture", Vector3(52.0, 0.02, -8.0), 0.7, 0.0],
		["часы", Vector3(-12.0, 1.5, -18.0), 0.6, 0.0],
		["наблюдатель", Vector3(61.0, 0.0, 6.0), 0.7, 180.0],
	]
	for entry in placements:
		MuseumModels.place(parent, str(entry[0]), entry[1] as Vector3, float(entry[2]), float(entry[3]))


func _add_exhibit(parent: Node, exhibit_name: String, model_name: String,
		exhibit_position: Vector3, color: Color, fallback_shape: String,
		emission_energy: float) -> void:
	var anomaly_anchor:=Marker3D.new(); anomaly_anchor.name="Anomaly Anchor - %s"%exhibit_name
	anomaly_anchor.position=exhibit_position+Vector3(0,1.55,0); parent.add_child(anomaly_anchor)
	_box(parent, "%s Pedestal" % exhibit_name,
		exhibit_position + Vector3(0, 0.35, 0),
		Vector3(2.8, 0.7, 2.8), Color(0.16, 0.16, 0.15))

	# Try a real model first; otherwise build the procedural fallback.
	if MuseumModels.place(parent, model_name,
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
	# Central orrery: emissive sun, three planets on flat brass rings.
	_cylinder(parent, "Orrery Pedestal", c + Vector3(0, 0.3, 0), 0.8, 0.6,
		Color(0.09, 0.09, 0.11))
	_cylinder(parent, "Orrery Stem", c + Vector3(0, 0.95, 0), 0.07, 0.7,
		Color(0.2, 0.17, 0.1))
	_sphere(parent, "Orrery Sun", c + Vector3(0, 1.45, 0), 0.32,
		Color(0.95, 0.66, 0.22), 1.5)
	var orbits := [
		[1.0, 0.10, Color(0.62, 0.56, 0.5), 0.9],
		[1.6, 0.14, Color(0.3, 0.5, 0.75), 3.0],
		[2.2, 0.12, Color(0.75, 0.4, 0.3), 5.1],
	]
	for i in range(orbits.size()):
		var o: Array = orbits[i]
		var ring_radius: float = o[0]
		_torus(parent, "Orrery Ring %d" % i, c + Vector3(0, 1.45, 0),
			ring_radius - 0.03, ring_radius, Color(0.45, 0.38, 0.2), 0.25, false)
		var ang: float = o[3]
		_sphere(parent, "Orrery Planet %d" % i,
			c + Vector3(cos(ang) * ring_radius, 1.45, sin(ang) * ring_radius),
			o[1], o[2], 0.4)
	_add_stanchions(parent, c, 3.1, 8)
	# Ring of low benches facing the orrery.
	for i in range(4):
		var a := PI * 0.25 + i * PI * 0.5
		var bench := Node3D.new()
		bench.name = "Planetarium Bench %d" % i
		bench.position = c + Vector3(cos(a) * 5.2, 0, sin(a) * 5.2)
		bench.rotation.y = -a - PI * 0.5
		parent.add_child(bench)
		_box(bench, "Seat", Vector3(0, 0.42, 0), Vector3(2.4, 0.12, 0.55),
			Color(0.16, 0.14, 0.18))
		_box(bench, "Base", Vector3(0, 0.2, 0), Vector3(2.1, 0.32, 0.4),
			Color(0.10, 0.09, 0.12))
	# Dead projector console by the door.
	_box(parent, "Projector Console", c + Vector3(6.5, 0.55, 6.4),
		Vector3(1.6, 1.1, 0.7), Color(0.07, 0.08, 0.1))
	_box(parent, "Projector Console Screen", c + Vector3(6.5, 1.02, 6.02),
		Vector3(1.1, 0.4, 0.04), Color(0.05, 0.2, 0.16), 0.5, 0.0, false)
	_add_label(parent, tr("EXHIBIT_PLANETARIUM_SIGN"), c + Vector3(0, 2.9, 6.0),
		Color(0.55, 0.62, 0.95))


func _add_lab_details(parent: Node) -> void:
	var c := Vector3(-25, 0, 22)
	# Workbench with a half-restored statue and its detached head.
	_box(parent, "Lab Workbench Top", c + Vector3(-5, 0.92, 2.6),
		Vector3(3.4, 0.1, 1.2), Color(0.17, 0.14, 0.11))
	for off in [Vector3(-6.5, 0.45, 2.15), Vector3(-3.5, 0.45, 2.15),
			Vector3(-6.5, 0.45, 3.05), Vector3(-3.5, 0.45, 3.05)]:
		_box(parent, "Lab Workbench Leg", c + off, Vector3(0.1, 0.9, 0.1),
			Color(0.08, 0.08, 0.08))
	var torso := _cone(parent, "Half-Restored Torso", c + Vector3(-5.5, 1.14, 2.6),
		0.3, 0.16, 0.85, Color(0.44, 0.42, 0.38))
	torso.rotation_degrees = Vector3(0, 0, 90)
	_sphere(parent, "Detached Statue Head", c + Vector3(-4.3, 1.13, 2.85), 0.16,
		Color(0.44, 0.42, 0.38))
	_box(parent, "Chisel", c + Vector3(-4.6, 0.99, 2.3), Vector3(0.3, 0.03, 0.03),
		Color(0.5, 0.5, 0.55), 0.0, 0.7, false)
	_box(parent, "Mallet", c + Vector3(-4.1, 1.0, 2.35), Vector3(0.12, 0.12, 0.28),
		Color(0.25, 0.18, 0.1), 0.0, 0.0, false)
	# Steel racks along the south wall, stacked with crates.
	for rx in [-4.0, 4.0]:
		var rack := Node3D.new()
		rack.name = "Lab Shelf Rack %d" % int(rx)
		rack.position = c + Vector3(rx, 0, 4.1)
		parent.add_child(rack)
		for px in [-1.4, 1.4]:
			for pz in [-0.35, 0.35]:
				_box(rack, "Rack Post", Vector3(px, 1.1, pz),
					Vector3(0.08, 2.2, 0.08), Color(0.1, 0.11, 0.12))
		for level in [0.35, 1.1, 1.85]:
			_box(rack, "Rack Shelf", Vector3(0, level, 0),
				Vector3(2.9, 0.06, 0.8), Color(0.14, 0.15, 0.16))
		for b in range(3):
			_box(rack, "Rack Crate %d" % b, Vector3(-0.9 + b * 0.9, 1.32, 0),
				Vector3(0.55, 0.38, 0.55), Color(0.23, 0.19, 0.13), 0.0, 0.0, false)
	# Sealed crate under warning tape near the east wall.
	_box(parent, "Sealed Crate", c + Vector3(7.6, 0.5, -2.5),
		Vector3(1.4, 1.0, 1.4), Color(0.2, 0.17, 0.12))
	_box(parent, "Sealed Crate Lid", c + Vector3(7.6, 1.2, -2.5),
		Vector3(1.0, 0.4, 1.0), Color(0.22, 0.19, 0.14))
	_plane(parent, "Warning Tape", c + Vector3(7.6, 0.02, -2.5), Vector2(2.6, 2.6),
		Color(0.6, 0.5, 0.1), true, false, 0.25, false)
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
	# Archive: reading desk with a lamp and an opened ledger.
	var a := Vector3(-25, 0, -11)
	_box(parent, "Archive Desk", a + Vector3(0, 0.78, 0), Vector3(1.8, 0.08, 0.9),
		Color(0.18, 0.14, 0.1))
	for off in [Vector3(-0.8, 0.38, -0.35), Vector3(0.8, 0.38, -0.35),
			Vector3(-0.8, 0.38, 0.35), Vector3(0.8, 0.38, 0.35)]:
		_box(parent, "Archive Desk Leg", a + off, Vector3(0.08, 0.76, 0.08),
			Color(0.1, 0.08, 0.06))
	var page_l := _box(parent, "Archive Ledger L", a + Vector3(-0.14, 0.84, 0.05),
		Vector3(0.26, 0.02, 0.38), Color(0.78, 0.74, 0.62), 0.1, 0.0, false)
	page_l.rotation_degrees = Vector3(0, 0, 4)
	var page_r := _box(parent, "Archive Ledger R", a + Vector3(0.14, 0.84, 0.05),
		Vector3(0.26, 0.02, 0.38), Color(0.72, 0.68, 0.56), 0.1, 0.0, false)
	page_r.rotation_degrees = Vector3(0, 0, -4)
	_cylinder(parent, "Archive Desk Lamp Stem", a + Vector3(0.6, 1.0, -0.25),
		0.03, 0.4, Color(0.1, 0.1, 0.1))
	_sphere(parent, "Archive Desk Lamp Shade", a + Vector3(0.6, 1.22, -0.25),
		0.11, Color(0.9, 0.75, 0.5), 1.4)
	for b in range(3):
		_box(parent, "Archive Box %d" % b, a + Vector3(1.6, 0.24 + b * 0.42, 0.1),
			Vector3(0.6, 0.4, 0.5), Color(0.24, 0.2, 0.14))
	# Equipment Storage: paired steel racks on both side walls. The central
	# north-south aisle remains clear from the office to the restoration lab.
	var storage_racks := [
		Vector3(-32.6, 0, 10.0), Vector3(-32.6, 0, 14.0),
		Vector3(-17.4, 0, 10.0), Vector3(-17.4, 0, 14.0),
	]
	for rack_index in range(storage_racks.size()):
		var rack := Node3D.new()
		rack.name = "Storage Rack %d" % (rack_index + 1)
		rack.position = storage_racks[rack_index]
		parent.add_child(rack)
		for pz in [-1.2, 1.2]:
			for px in [-0.3, 0.3]:
				_box(rack, "Post", Vector3(px, 1.1, pz), Vector3(0.08, 2.2, 0.08),
					Color(0.1, 0.11, 0.12))
		for level in [0.4, 1.15, 1.9]:
			_box(rack, "Shelf", Vector3(0, level, 0), Vector3(0.75, 0.06, 2.6),
				Color(0.14, 0.15, 0.16))
		for b in range(2):
			_box(rack, "Stored Box %d" % b, Vector3(0, 1.38, -0.7 + b * 1.4),
				Vector3(0.55, 0.4, 0.55), Color(0.2, 0.18, 0.13), 0.0, 0.0, false)


func _add_furnishings(parent: Node) -> void:
	# Containment dome under the atrium skylight: the museum centerpiece and
	# the object that breaks free during the night-shift accident.
	_cylinder(parent, "Containment Dais", Vector3(0, 0.14, 0), 1.5, 0.28,
		Color(0.82, 0.81, 0.78))
	_cylinder(parent, "Containment Pedestal", Vector3(0, 0.6, 0), 0.55, 0.65,
		Color(0.30, 0.30, 0.32))
	_sphere(parent, "Anomalous Core", Vector3(0, 1.35, 0), 0.32,
		Color(0.45, 0.95, 0.75), 1.6)
	var dome := _glass_case(parent, "Containment Dome",
		Vector3(0, 1.15, 0), Vector3(1.7, 1.8, 1.7))
	_apply_dome_shader(dome)
	_add_stanchions(parent, Vector3(0, 0, 0), 2.6, 10)
	_add_label(parent, "Object 01 - do not touch the glass",
		Vector3(0, 2.6, -0.7), Color(0.2, 0.55, 0.4))

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

	# Time Wing: a row of wall clocks frozen at different hours.
	var clock_xs: Array = [-9.0, -5.0, 5.0, 9.0]
	for i in range(clock_xs.size()):
		var cx: float = clock_xs[i]
		var clock := _cylinder(parent, "Wall Clock %d" % i,
			Vector3(cx, 2.3, -32.35), 0.34, 0.07, Color(0.90, 0.89, 0.84))
		clock.rotation_degrees = Vector3(90, 0, 0)
		var hand := _box(parent, "Wall Clock Hand %d" % i,
			Vector3(cx, 2.32, -32.28), Vector3(0.05, 0.24, 0.02),
			Color(0.1, 0.1, 0.1), 0.0, 0.0, false)
		hand.rotation_degrees = Vector3(0, 0, 25.0 + 47.0 * float(i))

	# Archive: two balanced wall bays keep a quiet central reading axis.
	for rack_x in [-30.0, -20.0]:
		_box(parent, "Archive Rack", Vector3(rack_x, 1.1, -16.2),
			Vector3(4.6, 2.2, 0.6), Color(0.36, 0.30, 0.24))
		for s in range(3):
			_box(parent, "Archive Rack Shelf",
				Vector3(rack_x, 0.55 + float(s) * 0.7, -15.85),
				Vector3(4.4, 0.06, 0.1), Color(0.30, 0.25, 0.20), 0.0, 0.0, false)
	_box(parent, "Document Boxes", Vector3(-32.5, 0.4, -9),
		Vector3(1.2, 0.8, 0.9), Color(0.55, 0.48, 0.36))

	# Storage: hazardous barrels grouped in one marked corner; the work cart is
	# parked beside a rack rather than abandoned in the circulation aisle.
	for i in range(3):
		_cylinder(parent, "Storage Barrel %d" % i,
			Vector3(-32.7 + float(i) * 1.05, 0.45, 15.4), 0.42, 0.9,
			Color(0.35, 0.38, 0.30))
	_box(parent, "Work Cart", Vector3(-20.0, 0.5, 15.3),
		Vector3(1.4, 0.12, 0.8), Color(0.45, 0.45, 0.48))
	_cylinder(parent, "Work Cart Pole", Vector3(-19.5, 0.9, 15.3), 0.03, 0.7,
		Color(0.30, 0.30, 0.32))


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

	# --- Archive: central catalogue island ---
	_box(parent, "Archive Catalogue Table", Vector3(-25, 0.72, -14.0), Vector3(2.4, 0.08, 0.9),
		Color(0.40, 0.33, 0.26))
	for leg_offset in [Vector3(-0.7, 0, -0.3), Vector3(0.7, 0, -0.3),
			Vector3(-0.7, 0, 0.3), Vector3(0.7, 0, 0.3)]:
		_box(parent, "Archive Catalogue Leg", Vector3(-25, 0.36, -14.0) + leg_offset,
			Vector3(0.08, 0.72, 0.08), Color(0.34, 0.28, 0.22), 0.0, 0.0, false)
	_box(parent, "Archive Chair", Vector3(-25, 0.3, -13.0), Vector3(0.5, 0.6, 0.5),
		Color(0.30, 0.26, 0.22))
	_plane(parent, "Archive Papers", Vector3(-25.3, 0.78, -14.0), Vector2(0.5, 0.35),
		Color(0.88, 0.86, 0.78), true, false, 0.0, false)
	_cylinder(parent, "Archive Lamp Stem", Vector3(-24.2, 0.95, -14.2), 0.03, 0.35,
		Color(0.20, 0.20, 0.22))
	_sphere(parent, "Archive Lamp Shade", Vector3(-24.2, 1.16, -14.2), 0.11,
		Color(0.40, 0.70, 0.50), 0.9)

	# --- Storage: janitor clutter ---
	var ladder := _box(parent, "Storage Ladder", Vector3(-34.0, 1.5, 12.0),
		Vector3(0.12, 3.0, 0.5), Color(0.55, 0.50, 0.40))
	ladder.rotation_degrees = Vector3(0, 0, 12)
	_box(parent, "Toolbox", Vector3(-18.2, 0.2, 15.5), Vector3(0.6, 0.35, 0.35),
		Color(0.65, 0.20, 0.15))
	_cylinder(parent, "Mop Bucket", Vector3(-17.0, 0.25, 8.2), 0.24, 0.5,
		Color(0.75, 0.65, 0.20))
	var mop := _cylinder(parent, "Mop Handle", Vector3(-17.0, 1.0, 8.2), 0.025, 1.5,
		Color(0.50, 0.42, 0.30))
	mop.rotation_degrees = Vector3(12, 0, 0)

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
	for i in range(3):
		_box(parent, "Entrance Step %d" % i,
			Vector3(0, 0.04 + float(i) * 0.06, 35.6 + float(i) * 0.4),
			Vector3(7.2 - float(i) * 0.8, 0.12, 0.5), Color(0.80, 0.79, 0.75))

	# Long planting beds frame the route without narrowing the playable path.
	for side: float in [-1.0, 1.0]:
		var bed_x: float = side * 10.5
		_box(parent, "Formal Lawn", Vector3(bed_x, -0.005, 45), Vector3(13, 0.08, 14),
			Color(0.25, 0.37, 0.23), 0.0, 0.0, false)
		_box(parent, "Lawn Stone Border", Vector3(bed_x, 0.05, 45), Vector3(13.4, 0.12, 14.4),
			Color(0.50, 0.50, 0.47), 0.0, 0.0, false)
		_box(parent, "Lawn Inset", Vector3(bed_x, 0.065, 45), Vector3(12.8, 0.08, 13.8),
			Color(0.25, 0.37, 0.23), 0.0, 0.0, false)
		for z: float in [40.0, 45.0, 50.0]:
			_add_plant(parent, Vector3(side * 6.2, 0, z))

	# Six lights create an even cadence from curb to entrance.
	for z: float in [39.5, 45.0, 50.5]:
		for lx: float in [-4.5, 4.5]:
			_cylinder(parent, "Street Lamp Post", Vector3(lx, 1.6, z), 0.08, 3.2,
				Color(0.12, 0.13, 0.14))
			_box(parent, "Street Lamp Head", Vector3(lx, 3.25, z),
				Vector3(0.42, 0.28, 0.42), Color(0.92, 0.86, 0.68), 0.55)

	# Facing benches form a deliberate pause point halfway to the entrance.
	for side: float in [-1.0, 1.0]:
		var bx: float = side * 8.0
		_box(parent, "Forecourt Bench Seat", Vector3(bx, 0.45, 43.5),
			Vector3(2.6, 0.12, 0.62), Color(0.28, 0.22, 0.16))
		_box(parent, "Forecourt Bench Back", Vector3(bx, 0.80, 43.82),
			Vector3(2.6, 0.50, 0.08), Color(0.25, 0.19, 0.14))

	_box(parent, "Museum Sign", Vector3(0, 3.5, 35.2), Vector3(7.8, 1.0, 0.3),
		Color(0.16, 0.18, 0.22))
	_add_label(parent, "NATURAL PHILOSOPHY MUSEUM", Vector3(0, 3.5, 35.0),
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
		var wheel := _cylinder(parent, "Visitor Car Wheel", Vector3(15.5, 0.32, 59.0) + off,
			0.32, 0.24, Color(0.06, 0.06, 0.07))
		wheel.rotation_degrees = Vector3(90, 0, 0)
	_box(parent, "Museum Service Van", Vector3(-17.0, 0.95, 59.0), Vector3(4.4, 1.7, 1.9),
		Color(0.70, 0.70, 0.68), 0.0, 0.25)
	_box(parent, "Service Van Stripe", Vector3(-17.0, 1.08, 58.01), Vector3(3.4, 0.32, 0.03),
		Color(0.24, 0.34, 0.42), 0.15, 0.0, false)
	for off: Vector3 in [Vector3(-1.45, 0, -0.9), Vector3(1.45, 0, -0.9), Vector3(-1.45, 0, 0.9), Vector3(1.45, 0, 0.9)]:
		var van_wheel := _cylinder(parent, "Service Van Wheel", Vector3(-17.0, 0.34, 59.0) + off,
			0.34, 0.26, Color(0.06, 0.06, 0.07))
		van_wheel.rotation_degrees = Vector3(90, 0, 0)

	# Symmetrical tree line and flag pair frame the museum facade.
	for tree_pos: Vector3 in [Vector3(-25, 0, 39.5), Vector3(-25, 0, 50.5), Vector3(25, 0, 39.5), Vector3(25, 0, 50.5)]:
		_cylinder(parent, "Street Tree Trunk", tree_pos + Vector3(0, 1.1, 0), 0.18,
			2.2, Color(0.30, 0.22, 0.14))
		_cone(parent, "Street Tree Crown", tree_pos + Vector3(0, 3.3, 0), 1.5, 0.15,
			2.4, Color(0.18, 0.31, 0.16))
	for fx: float in [-5.4, 5.4]:
		_cylinder(parent, "Flag Pole", Vector3(fx, 2.5, 36.8), 0.05, 5.0,
			Color(0.60, 0.62, 0.66))
		_box(parent, "Flag", Vector3(fx + 0.5, 4.55, 36.8), Vector3(0.9, 0.5, 0.04),
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
	for bin_pos: Vector3 in [Vector3(-4.8, 0.38, 52.0), Vector3(8.0, 0.38, 52.0)]:
		_cylinder(parent, "Street Bin", bin_pos, 0.28, 0.76, Color(0.16, 0.25, 0.18))
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
		_cylinder(parent, "Billboard Post", Vector3(bx, 0.7, 62.9), 0.08, 1.4,
			Color(0.12, 0.13, 0.14))
	_box(parent, "Street Billboard", Vector3(0, 2.2, 62.9), Vector3(7.2, 2.2, 0.2),
		Color(0.13, 0.15, 0.19))
	_add_label(parent, "SPECIAL EXHIBIT: OBJECT 01", Vector3(0, 2.4, 62.7),
		Color(0.86, 0.90, 0.80))


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
# Opening cutscene: a prologue title card plus three camera shots with
# letterbox titles, skippable with SPACE / ENTER / ESC.
# Inheritance chain:
#   FirstMuseumMap < MapIntro < MapDecor < MapLighting
#     < MapStructure < MapPrimitives < Node3D
# Every module sees the constants, vars and helpers of the
# modules below it; call sites stay unchanged.

# Intro cutscene state (runtime only).
# INTRO_LENGTH is the sum of the per-shot durations listed in _intro_shots():
# 6.0 s prologue card + 4.5 + 4.5 + 4.5 for the three camera shots, each of
# which keeps exactly the length it had when the intro was 13.5 s split three
# ways. 6.0 + 13.5 = 19.5.
const INTRO_LENGTH := 19.5
var _intro_active := false
var _intro_time := 0.0
var _intro_camera: Camera3D = null
var _intro_overlay: CanvasLayer = null
var _intro_title: Label = null
var _intro_card: ColorRect = null
var _intro_fade: ColorRect = null

# --- When the intro is allowed to play --------------------------------------
# Both files belong to other scripts and are only read here (the seen flag is
# the one exception, see _mark_intro_seen). Paths are duplicated rather than
# imported so the map never has to reach for GameManager: this scene is
# instantiated bare by the headless suites, where that node initializes two
# frames later than _ready() and would not have loaded the night yet.
const INTRO_SAVE_PATH := "user://museum_save.cfg"  # GameManager.SAVE_PATH
const INTRO_PROGRESS_PATH := "user://museum_progress.cfg"  # TutorialPrologue.PROGRESS_PATH


## RULE: the cutscene is first-night, first-time-only. It plays only when the
## saved night is 1 *and* no intro/seen flag has been written yet. Every other
## way into this scene -- continuing on night 2 or 3, "Main menu" from the pause
## screen, and the scene reload behind the win screen -- drops straight into the
## game with no cutscene. Two reasons: the second caption reads "First night on
## duty", which is a plain lie on night 3, and _ready() runs on every one of
## those reloads, so an unconditional intro charges 19.5 s for each of them.
## Side effect worth knowing, not a contract: MenuManager._reset_progress()
## rewrites museum_progress.cfg wholesale, so "Reset progress" also clears the
## flag and a reset player is shown the intro again.
func _intro_should_play() -> bool:
	return _intro_saved_night() <= 1 and not _intro_seen()


func _intro_saved_night() -> int:
	var config := ConfigFile.new()
	if config.load(INTRO_SAVE_PATH) != OK:
		return 1
	return maxi(1, int(config.get_value("progress", "night", 1)))


func _intro_seen() -> bool:
	var config := ConfigFile.new()
	if config.load(INTRO_PROGRESS_PATH) != OK:
		return false
	return bool(config.get_value("intro", "seen", false))


## Written when the intro ends or is skipped, never when it merely starts, so
## quitting halfway through does not burn it.
## The flag lives in the tutorial's progress file and not in museum_save.cfg
## because GameManager._save_night() rewrites that file from a fresh ConfigFile
## on every night change and would drop any key it does not know about. The
## load() below is what keeps tutorial/done and tutorial/skipped intact here.
func _mark_intro_seen() -> void:
	var config := ConfigFile.new()
	config.load(INTRO_PROGRESS_PATH)
	config.set_value("intro", "seen", true)
	config.save(INTRO_PROGRESS_PATH)


func _start_intro() -> void:
	if Engine.is_editor_hint() or _intro_active:
		return
	if not _intro_should_play():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.set("controls_enabled", false)
	var player_camera := player.get_node_or_null("Player Camera") as Camera3D
	if player_camera != null:
		player_camera.current = false

	_intro_camera = Camera3D.new()
	_intro_camera.name = "Intro Camera"
	_intro_camera.fov = 66.0
	add_child(_intro_camera)
	_intro_camera.global_position = Vector3(26, 13, 63)
	_intro_camera.look_at(Vector3(0, 3.0, 35))
	_intro_camera.current = true

	# Letterbox bars, title text, skip hint and a fade rect.
	_intro_overlay = CanvasLayer.new()
	_intro_overlay.name = "Intro Overlay"
	add_child(_intro_overlay)

	var top_bar := ColorRect.new()
	top_bar.color = Color(0, 0, 0)
	top_bar.anchor_right = 1.0
	top_bar.anchor_bottom = 0.12
	_intro_overlay.add_child(top_bar)

	var bottom_bar := ColorRect.new()
	bottom_bar.color = Color(0, 0, 0)
	bottom_bar.anchor_top = 0.88
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_bottom = 1.0
	_intro_overlay.add_child(bottom_bar)

	# Backdrop for title cards, so the prologue reads over black instead of over
	# a daylit forecourt. Added before the title label so the text draws on top
	# of it, while _intro_fade stays last and still blacks out both at the cuts.
	_intro_card = ColorRect.new()
	_intro_card.color = Color(0, 0, 0, 0)
	_intro_card.anchor_right = 1.0
	_intro_card.anchor_bottom = 1.0
	_intro_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_overlay.add_child(_intro_card)

	_intro_title = Label.new()
	_intro_title.anchor_top = 0.76
	_intro_title.anchor_right = 1.0
	_intro_title.anchor_bottom = 0.88
	_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_title.add_theme_font_size_override("font_size", 24)
	_intro_title.add_theme_color_override("font_color", Color(0.92, 0.90, 0.82))
	_intro_overlay.add_child(_intro_title)

	var skip_hint := Label.new()
	skip_hint.text = tr("HUD_INTRO_SKIP")
	skip_hint.anchor_right = 0.985
	skip_hint.anchor_top = 0.90
	skip_hint.anchor_bottom = 0.985
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	skip_hint.add_theme_font_size_override("font_size", 14)
	skip_hint.add_theme_color_override("font_color", Color(0.60, 0.60, 0.55))
	_intro_overlay.add_child(skip_hint)

	_intro_fade = ColorRect.new()
	_intro_fade.color = Color(0, 0, 0, 1)
	_intro_fade.anchor_right = 1.0
	_intro_fade.anchor_bottom = 1.0
	_intro_overlay.add_child(_intro_fade)

	_intro_time = 0.0
	_intro_active = true


# Each entry: camera start and end position, look target, caption, how long it
# holds and whether it reads over a black card instead of over the world.
#
# The opening entry is a title card, not a move: start and end positions are
# identical, so the camera stands still while STORY_PROLOGUE reads over black.
# It gets 6.0 s rather than the 4.5 s of a camera shot. The fades eat fixed
# fractions of each window (0.12 in, 0.10 out), so a 4.5 s shot leaves ~3.5 s of
# steady text and 6.0 s leaves ~4.7 s -- room for two sentences at a first
# reading, without stalling a player who has seen it and hits SPACE.
func _intro_shots() -> Array:
	return [
		{"from": Vector3(26, 13, 63), "to": Vector3(26, 13, 63),
			"look": Vector3(0, 3.0, 35), "text": tr("STORY_PROLOGUE"),
			"time": 6.0, "card": true},
		{"from": Vector3(26, 13, 63), "to": Vector3(15, 9, 58),
			"look": Vector3(0, 3.0, 35), "text": tr("HUD_INTRO_MUSEUM"),
			"time": 4.5, "card": false},
		{"from": Vector3(-12, 1.5, 53), "to": Vector3(-5, 1.7, 48),
			"look": Vector3(0, 3.4, 35.2), "text": tr("HUD_INTRO_FIRST_NIGHT"),
			"time": 4.5, "card": false},
		{"from": Vector3(0, 2.4, 53), "to": Vector3(0, 1.75, 46.6),
			"look": Vector3(0, 1.8, 35), "text": tr("HUD_INTRO_CHECK_HALLS"),
			"time": 4.5, "card": false},
	]


func _update_intro(delta: float) -> void:
	_intro_time += delta
	if _intro_time >= INTRO_LENGTH or not is_instance_valid(_intro_camera):
		_end_intro()
		return
	var shots := _intro_shots()
	# The shots no longer share one length -- a title card stays up longer than a
	# camera move -- so walk the cumulative durations instead of dividing
	# INTRO_LENGTH evenly. `elapsed` ends up as the time inside the current shot.
	var idx := shots.size() - 1
	var elapsed := _intro_time
	for i in range(shots.size()):
		var length := float(shots[i]["time"])
		if elapsed < length:
			idx = i
			break
		elapsed -= length
	var shot: Dictionary = shots[idx]
	var t := clampf(elapsed / float(shot["time"]), 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	_intro_camera.global_position = (shot["from"] as Vector3).lerp(shot["to"] as Vector3, eased)
	_intro_camera.look_at(shot["look"] as Vector3)
	if is_instance_valid(_intro_title):
		_intro_title.text = str(shot["text"])
	if is_instance_valid(_intro_card):
		_intro_card.color.a = 1.0 if bool(shot["card"]) else 0.0
	# Quick fade from black at each cut, fade to black before the next one.
	var fade := 0.0
	if t < 0.12:
		fade = 1.0 - t / 0.12
	elif t > 0.9:
		fade = (t - 0.9) / 0.1
	if is_instance_valid(_intro_fade):
		_intro_fade.color.a = fade


func _end_intro() -> void:
	if not _intro_active:
		return
	_intro_active = false
	# Both exits land here -- the last shot running out and the skip in _input --
	# and both count as "seen", so neither replays on the next reload.
	_mark_intro_seen()
	if is_instance_valid(_intro_camera):
		_intro_camera.current = false
		_intro_camera.queue_free()
	if is_instance_valid(_intro_overlay):
		_intro_overlay.queue_free()
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		var player_camera := player.get_node_or_null("Player Camera") as Camera3D
		if player_camera != null:
			player_camera.current = true
		player.set("controls_enabled", true)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _intro_active:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("confirm") \
			or event.is_action_pressed("pause"):
		_end_intro()
		get_viewport().set_input_as_handled()

# ===== FirstMuseumMap.gd =====
# Top-level orchestrator of the procedural museum map (PS1 horror).
# The heavy lifting lives in the inherited modules:
#   MapPrimitives - constants, materials, primitive helpers
#   MapStructure  - rooms, walls, doors, cameras, player spawn
#   MapLighting   - environment, room lights, blackout
#   MapDecor      - exhibits, furnishings, street, dome shader
#   MapIntro      - opening cutscene
# All files must sit in the project together (e.g. res://game/).

var _flicker_time := 0.0

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
	# In game (not in the editor) the map may open with the intro cutscene.
	# _start_intro() decides for itself whether this entry deserves one -- see
	# _intro_should_play(); it is a first-night, first-time-only piece and this
	# _ready() also runs on every return to the menu and after the win screen.
	if not Engine.is_editor_hint():
		call_deferred("_start_intro")


func _process(delta: float) -> void:
	# Daytime intro keeps steady lighting. Once the player reaches the
	# office the blackout fires and only the red emergency light pulses.
	if Engine.is_editor_hint():
		return
	if _intro_active:
		_update_intro(delta)
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
	_add_room(map_root, "Entrance Zone", Vector3(0, 0, 25), Vector2(22, 20),
		Color(0.85, 0.84, 0.81), {"N": DOOR_GAP, "S": DOOR_GAP})
	_add_room(map_root, "Central Atrium", Vector3(0, 0, 0), Vector2(30, 30),
		Color(0.88, 0.87, 0.85),
		{"N": DOOR_GAP, "S": DOOR_GAP, "E": DOOR_GAP, "W": DOOR_GAP})
	_add_room(map_root, "Watcher Office", Vector3(-25, 0, 0), Vector2(20, 14),
		Color(0.55, 0.57, 0.58), {"E": DOOR_GAP, "N": DOOR_GAP, "S": DOOR_GAP})
	_add_room(map_root, "Equipment Storage", Vector3(-25, 0, 12), Vector2(20, 10),
		Color(0.52, 0.52, 0.48), {"N": DOOR_GAP, "S": DOOR_GAP})
	_add_room(map_root, "Archive", Vector3(-25, 0, -12), Vector2(20, 10),
		Color(0.60, 0.58, 0.54), {"S": DOOR_GAP})
	_add_room(map_root, "Gravity Wing A", Vector3(28, 0, 0), Vector2(26, 18),
		Color(0.78, 0.81, 0.86), {"W": DOOR_GAP, "E": DOOR_GAP})
	_add_room(map_root, "Time Wing B", Vector3(0, 0, -24), Vector2(26, 18),
		Color(0.85, 0.79, 0.70), {"S": DOOR_GAP, "N": DOOR_GAP, "E": DOOR_GAP})
	# Wings C and D now have real doorways, sealed by blast doors until
	# nights 2 and 3 (see _add_locked_doors / unlock_wing in MapStructure).
	_add_room(map_root, "Space Wing C Locked", Vector3(24, 0, -24), Vector2(22, 16),
		Color(0.68, 0.70, 0.75), {"W": DOOR_GAP})
	_add_room(map_root, "Mass Wing D Locked", Vector3(52, 0, 0), Vector2(22, 16),
		Color(0.76, 0.72, 0.63), {"W": DOOR_GAP})
	# New annexes: a planetarium behind Time Wing and a restoration lab
	# behind Storage.
	_add_room(map_root, "Planetarium", Vector3(0, 0, -41), Vector2(20, 16),
		Color(0.62, 0.65, 0.78), {"S": DOOR_GAP})
	_add_room(map_root, "Restoration Lab", Vector3(-25, 0, 22), Vector2(20, 10),
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
	_add_entrance_details(map_root)
	_add_office_details(map_root)
	_add_exhibits(map_root)
	_add_planetarium_details(map_root)
	_add_lab_details(map_root)
	_add_extra_exhibits(map_root)
	_add_furnishings(map_root)
	_add_more_interior(map_root)
	_add_outdoor(map_root)
	_add_street_extras(map_root)
	_add_cameras(map_root)
	_add_locked_doors(map_root)
	_add_player_spawn(map_root)
	_add_navigation(map_root)

	if Engine.is_editor_hint():
		_make_generated_map_editable(map_root)
