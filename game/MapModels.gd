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
# Dressing that must never collide: wall-mounted CCTV, ceiling vents, the loose
# flashlight, the huge tiling-texture plane, and the "арка дверь" arch that frames
# the Atrium -> Time Wing B doorway.
#
# The arch entry is a deliberate trade, not a free win. Gained: the doorway keeps
# the whole 1.8 m DOOR_GAP that _add_door_frame's wall segments, jambs and header
# define, so the bake still carries 0.9 m of navmesh through it and the Curator can
# follow the player into Time Wing B. Given up: the arch's own posts overhang that
# opening and nothing stops the player or the Curator walking through stone.
# Measured on the placed instance (scale 0.85 at z = -15.5), the post inner faces
# stand at x = +-0.699 across the standing band and flare to +-0.649 at the base
# plinth, against a 0.90 m half-gap -- roughly 0.20 m of visible intrusion per side,
# 0.25 m at ankle height.
#
# An exact trimesh collider was tried and rejected: it shrinks the opening to its
# true 1.30 m and lays a 0.19-0.22 m threshold slab across it. Navmesh erosion is
# ceil(agent_radius 0.45 / cell_size 0.15) = 3 cells = 0.45 m per side, so 1.30 m
# bakes to ~0.40 m of walkable width instead of 0.90 m; and since agent_max_climb is
# 0.4 m, Recast paths straight over the slab, which CuratorMonster's plain
# move_and_slide() -- no step-up, default 45-degree floor limit -- cannot mount. The
# Curator would grind against a 0.19 m lip and be stranded on one side. A convex
# hull is worse again: 2.18 m across a 1.80 m gap seals the doorway outright, which
# is the regression test_blocker_regressions.gd now guards. Clipping a post is
# cosmetic on one doorway; a Curator that cannot leave the Atrium breaks the chase.
const NON_BLOCKING := ["camera", "security_camera", "vents", "tactical_flashlight",
	"modern_grey_stone_tile_texture", "арка дверь"]
# Large, mostly hollow meshes whose convex hull would be vastly bigger than the
# geometry it wraps. "portal_arch" is an inverted-L roughly 15 x 25 m in source
# units: hulling it yields one solid wedge that swallows a big slice of Space
# Wing C, even though the mesh itself is almost all empty air. An exact concave
# collider follows the real surface instead. Static bodies only:
# ConcavePolygonShape3D is not valid on anything that moves.
const TRIMESH_COLLISION := ["portal_arch"]


## Instantiate `model_name` under `parent` at `world_position`.
##
## `rotation_y_deg` is the yaw (compass heading); `pitch_x_deg` is the tilt of
## the model's own nose, positive = up, negative = DOWN. Both default to the
## behaviour every existing call site relies on, so adding pitch to one
## placement never disturbs the others.
##
## Why an X euler and not a look_at: Godot's default euler order is YXZ, so
## `Vector3(pitch, yaw, 0)` yaws in world space first and then pitches about the
## model's own local right axis. That is what a wall bracket does, and it is
## already the convention the procedural CCTV fallback uses
## (`FirstMuseumMap._camera` builds its pivot with `Vector3(-14, yaw, 0)`), so
## an imported mount and a fallback mount given the same numbers now aim the
## same way. Forward is -Z, so a NEGATIVE pitch points the lens at the floor:
## -14 deg reproduces the fallback exactly, -20 to -30 suits a 3.0 m mount
## covering a room whose ceiling is WALL_HEIGHT 3.4 m.
static func place(parent: Node, model_name: String, world_position: Vector3,
		scale_factor := 1.0, rotation_y_deg := 0.0, pitch_x_deg := 0.0) -> Node3D:
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
	# Read-modify-write rather than a fresh Vector3: roll (Z) stays whatever the
	# imported scene root carried, exactly as when only yaw was assigned here.
	var euler := instance.rotation_degrees
	euler.x = pitch_x_deg
	euler.y = rotation_y_deg
	instance.rotation_degrees = euler
	parent.add_child(instance)
	# Imported museum pieces are static. Generate collision for visible exhibit
	# meshes when the source GLB did not provide one; wall-mounted CCTV stays
	# non-blocking so it cannot snag the player near doorways.
	if model_name not in NON_BLOCKING:
		_ensure_collisions(instance, model_name in TRIMESH_COLLISION)
	return instance


static func _ensure_collisions(root: Node3D, use_trimesh := false) -> void:
	if root.find_child("*Collision*", true, false) != null:
		return
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		if use_trimesh:
			# Exact concave collider: follows the real surface instead of the
			# oversized solid hull a large hollow mesh would otherwise get.
			mesh_instance.create_trimesh_collision()
		else:
			mesh_instance.create_convex_collision(true, true)


static func has_model(model_name: String) -> bool:
	var path := str(MODEL_PATHS.get(model_name, "res://models/%s.glb" % model_name))
	return ResourceLoader.exists(path)
