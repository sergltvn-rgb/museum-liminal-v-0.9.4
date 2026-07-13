extends CharacterBody3D
## Procedural low-poly museum Curator: porcelain mannequin, uniform and CCTV eye.


func _ready() -> void:
	collision_layer=2; collision_mask=1
	var collision:=CollisionShape3D.new(); var capsule:=CapsuleShape3D.new(); capsule.radius=.38; capsule.height=2.25
	collision.position.y=1.12; collision.shape=capsule; add_child(collision); _build_model()


func _build_model() -> void:
	var cloth := _material(Color(0.035, 0.05, 0.06), 0.85, 0.0)
	var porcelain := _material(Color(0.62, 0.64, 0.61), 0.72, 0.0)
	var brass := _material(Color(0.32, 0.22, 0.10), 0.3, 0.75)
	var black := _material(Color(0.006, 0.008, 0.01), 0.2, 0.3)
	_part_box("Coat Torso", Vector3(0, 1.35, 0), Vector3(0.62, 0.95, 0.34), cloth)
	_part_box("Coat Tail L", Vector3(-0.18, 0.82, 0.08), Vector3(0.25, 0.62, 0.25), cloth)
	_part_box("Coat Tail R", Vector3(0.18, 0.82, 0.08), Vector3(0.25, 0.62, 0.25), cloth)
	_part_cylinder("Neck", Vector3(0, 1.92, 0), 0.1, 0.22, porcelain)
	_part_box("Camera Head", Vector3(0, 2.12, -0.02), Vector3(0.42, 0.28, 0.34), porcelain)
	var lens := _part_cylinder("Camera Lens", Vector3(0, 2.12, -0.24), 0.105, 0.12, black)
	lens.rotation_degrees.x = 90
	var lens_ring := _part_cylinder("Lens Ring", Vector3(0, 2.12, -0.30), 0.14, 0.035, brass)
	lens_ring.rotation_degrees.x = 90
	# Asymmetric arms: one human, one overlong museum handling tool.
	var left_arm := _part_cylinder("Left Upper Arm", Vector3(-0.42, 1.45, 0), 0.09, 0.72, cloth)
	left_arm.rotation_degrees.z = -8
	var left_forearm := _part_cylinder("Left Forearm", Vector3(-0.48, 0.92, -0.03), 0.075, 0.54, porcelain)
	left_forearm.rotation_degrees.z = -4
	var right_arm := _part_cylinder("Right Long Arm", Vector3(0.43, 1.18, 0), 0.085, 1.22, cloth)
	right_arm.rotation_degrees.z = 7
	_part_box("Handling Claw", Vector3(0.50, 0.52, -0.04), Vector3(0.28, 0.12, 0.24), brass)
	for x in [-0.18, 0.18]:
		_part_cylinder("Leg", Vector3(x, 0.42, 0), 0.105, 0.82, cloth)
		_part_box("Shoe", Vector3(x, 0.08, -0.12), Vector3(0.24, 0.14, 0.42), black)
	for y in [1.55, 1.32, 1.09]:
		var button := _part_cylinder("Coat Button", Vector3(0, y, -0.185), 0.025, 0.025, brass)
		button.rotation_degrees.x = 90
	var eye := OmniLight3D.new()
	eye.name = "Recording Eye"
	eye.position = Vector3(0, 2.12, -0.38)
	eye.light_color = Color(1.0, 0.04, 0.02)
	eye.light_energy = 0.55
	eye.omni_range = 2.5
	add_child(eye)


func _part_box(part_name: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name = part_name; node.position = pos
	var mesh := BoxMesh.new(); mesh.size = size; node.mesh = mesh; node.material_override = mat
	add_child(node); return node


func _part_cylinder(part_name: String, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name = part_name; node.position = pos
	var mesh := CylinderMesh.new(); mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height
	node.mesh = mesh; node.material_override = mat; add_child(node); return node


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = roughness; mat.metallic = metallic
	return mat
