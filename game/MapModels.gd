@tool
## Reusable model placement helper.
##
## Tries to load a real 3D model from `res://models/<model_name>.glb`.
## If the file exists it is instantiated and returned; otherwise the call
## returns `null` so the caller can build a procedural fallback instead.
##
## Drop a `.glb` into the `models/` directory (see models/README.md for the
## list of recognised names) and it will automatically replace the fallback
## primitive the next time the map is (re)built.

static var _cache: Dictionary = {}


static func place(parent: Node, model_name: String, world_position: Vector3,
		scale_factor := 1.0, rotation_y_deg := 0.0) -> Node3D:
	# A stale archive may leave the old fox file behind under this misleading
	# name. Never load it: the procedural Newton statue has correct scale and
	# collision. This also protects projects updated by extracting over v0.2.2.
	# The supplied archive contains sample assets under incorrect exhibit names
	# (fox, avocado, lantern, helmet and oversized demo meshes). Only the verified
	# office chair is accepted; every other slot uses its authored fallback.
	if model_name != "office_chair":
		return null
	var path := "res://models/%s.glb" % model_name
	if not ResourceLoader.exists(path):
		return null

	var packed: PackedScene = null
	if _cache.has(path):
		packed = _cache[path]
	else:
		packed = load(path) as PackedScene
		if packed == null:
			return null
		_cache[path] = packed

	var instance: Node3D = packed.instantiate()
	instance.position = world_position
	instance.scale = Vector3.ONE * scale_factor
	instance.rotation_degrees.y = rotation_y_deg
	parent.add_child(instance)
	# Imported museum pieces are static. Generate collision for visible exhibit
	# meshes when the source GLB did not provide one; wall-mounted CCTV stays
	# non-blocking so it cannot snag the player near doorways.
	if model_name != "security_camera":
		_ensure_collisions(instance)
	return instance


static func _ensure_collisions(root: Node3D) -> void:
	if root.find_child("*Collision*", true, false) != null:
		return
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			mesh_instance.create_convex_collision(true, true)


static func has_model(model_name: String) -> bool:
	return ResourceLoader.exists("res://models/%s.glb" % model_name)
