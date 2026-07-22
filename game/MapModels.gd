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
const MODEL_PATHS := {
	"camera": "res://models/camera.fbx",
	"security_camera": "res://models/camera.fbx",
}
const NON_BLOCKING := ["camera", "security_camera", "vents", "tactical_flashlight", "modern_grey_stone_tile_texture"]


static func place(parent: Node, model_name: String, world_position: Vector3,
		scale_factor := 1.0, rotation_y_deg := 0.0) -> Node3D:
	# Every supplied museum asset is eligible. Authored call-site scale and
	# rotation keep inconsistent source units under control; procedural geometry
	# remains the fallback whenever import or instantiation fails.
	var path := str(MODEL_PATHS.get(model_name, "res://models/%s.glb" % model_name))
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
	if model_name not in NON_BLOCKING:
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
	var path := str(MODEL_PATHS.get(model_name, "res://models/%s.glb" % model_name))
	return ResourceLoader.exists(path)
