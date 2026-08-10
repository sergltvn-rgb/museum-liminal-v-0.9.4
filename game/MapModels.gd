@tool
## Reusable model placement helper.
##
## Tries to load a real 3D model from `res://models/<model_name>.glb`.
## If the file exists it is instantiated and returned; otherwise the call
## returns `null` so the caller can build a procedural fallback instead.
##
## Drop a `.glb` into the `models/` directory (see models/README.md for the
## list of recognised names) and it will automatically replace the fallback
## primitive the next time the map is (re)built. The one exception is
## PLACEHOLDER_MODELS below: names whose file on disk is a stand-in rather than
## the exhibit, for which the fallback is the real artwork and wins.

static var _cache: Dictionary = {}
const MODEL_PATHS := {
	"camera": "res://models/camera.fbx",
	"security_camera": "res://models/camera.fbx",
}
# Dressing that must never collide: wall-mounted CCTV, ceiling vents, the loose
# flashlight and the huge tiling-texture plane.
#
# The "арка дверь" arch was listed here until the atrium pass of 2026-08-06.
# Nothing places it any more (see the Central Atrium / Time Wing B block in
# FirstMuseumMap.gd), so the exemption went with it: an entry for a model that
# is never instantiated reads as if the arch were still standing, and that is
# worse than no note at all. The .glb itself stays in models/, which is the
# owner's folder and is never pruned from here.
#
# The measurements the entry carried are kept, because they are the record of
# what collision costs at a doorway and the next imported arch will need them:
# a convex hull of that mesh is 2.18 m across a 1.80 m gap and seals the
# doorway outright, which is the regression test_blocker_regressions.gd
# guards. An exact trimesh collider was tried and rejected too -- it shrinks
# the opening to its true 1.30 m, which erodes to ~0.40 m of walkable width
# (ceil(agent_radius 0.45 / cell_size 0.15) = 3 cells = 0.45 m per side)
# instead of 0.90 m, and it lays a 0.19-0.22 m threshold slab that Recast
# paths straight over and CuratorMonster's plain move_and_slide() -- no
# step-up, default 45-degree floor limit -- cannot mount.
const NON_BLOCKING := ["camera", "security_camera", "vents", "tactical_flashlight",
	"modern_grey_stone_tile_texture",
	# Wall-mounted at head height with open floor underneath, so a hull here
	# can only ever catch a player brushing along the wall -- it can never stop
	# one walking into something solid. Same reasoning as the CCTV entries.
	"lp_key_cabinet",
	# The eight atrium rope-barrier stanchions. The primitives they replace
	# carried no collision at all and that was deliberate: they stand on a
	# 3.40 m ring inside the rotunda, and eight fresh convex hulls out there
	# would be the first blockers that far from the axis -- the current furthest
	# collider in AtriumProps is the core plaque post at 2.46 m. Recast erodes
	# by ceil(0.45 / 0.15) = 3 cells = 0.45 m per side, so hulling a 0.34 m base
	# costs ~1.24 m of walkable ring at each of eight points on the exact loop
	# the Curator chases the player around. A rope barrier is a visual
	# instruction, not a wall; keeping it non-blocking preserves the navmesh the
	# chase was tuned against.
	"lp_stanchion",
	# The Blender-authored CCTV head and the ceiling plate it hangs from
	# (tools/lowpoly/blender_cameras.py). Same reasoning as the
	# "security_camera" entry at the top of this list: both sit ~3 m up with
	# open floor beneath them, so a hull could never stop a player walking
	# into something solid -- it could only catch one brushing a wall -- and a
	# static body at that height is one more overhead obstacle Recast has to
	# filter back out. Eleven posts, twenty-two hulls, nothing gained.
	"lp_security_camera", "lp_camera_plate",
	# The leaves of the three back-of-house double doors, and the only prop in
	# the museum that MOVES. DoorSwing hangs each leaf on a frozen kinematic
	# RigidBody3D and turns it, and the body that stops the player is a single
	# box built next to the model in FirstMuseumMap._door_leaves. A hull
	# generated here would be a second collider -- a StaticBody3D, bolted to a
	# body that swings -- and a StaticBody3D across a doorway is precisely what
	# the navigation bake must never see.
	"lp_door_leaf",
	# The shell of an archive rolling-stack carriage, placed five times per
	# block. Same shape of argument as "lp_door_leaf" above: the body that stops
	# the player is a single box built next to the model in
	# ArchiveProps._stack_carriage, surveyed at 0.94 x 2.20 x 3.00 and described
	# in that code as one clean box for navigation.
	#
	# A hull generated here would be a SECOND collider wrapping the same volume,
	# and a worse one: the handwheels stand 0.19 m proud of the operating end,
	# so the mesh is 3.14 m deep against the carcass's 3.00 m and the hull would
	# push 70 mm of static body into the working aisle at each end of every
	# carriage -- on the exact rail run the player has to walk down. Five extra
	# static bodies per block, a narrower aisle for Recast to erode, and the
	# StaticBody3D count moves off 547 for nothing gained.
	"lp_stack_carriage"]
# Large, mostly hollow meshes whose convex hull would be vastly bigger than the
# geometry it wraps. "portal_arch" is an inverted-L roughly 15 x 25 m in source
# units: hulling it yields one solid wedge that swallows a big slice of Space
# Wing C, even though the mesh itself is almost all empty air. An exact concave
# collider follows the real surface instead. Static bodies only:
# ConcavePolygonShape3D is not valid on anything that moves.
#
# The "portal_arch" entry is dormant while that name is in PLACEHOLDER_MODELS
# (the file behind it is the Khronos Lantern and never instantiates). It is kept
# because it describes the collider a genuine arch mesh would need, and because
# working around the sample's hull was the reason it was written -- deleting it
# would erase the record of why concave collision exists here at all.
const TRIMESH_COLLISION := ["portal_arch"]
# Names that have a file in models/ but whose file is NOT the thing the name
# says. Every one of them is a stock Khronos glTF sample dropped in as a
# stand-in, and every one of them sits in an _add_exhibit slot whose procedural
# fallback is the exhibit the map author actually wrote, sized to fit the
# 2.25 x 2.10 x 2.25 m glass case and the 3.4 m ceiling. Without this list
# place() resolves the file, the fallback branch never runs, and the case holds
# a rubber duck.
#
# READ THIS BEFORE DELETING AN ENTRY. The file still exists on disk (models/ is
# the owner's and nothing there may be removed), so dropping a name from this
# list does not "restore a model" -- it puts the sample asset back in the museum
# and silently deletes the authored exhibit again. Remove a name only when the
# file behind it has genuinely been replaced with the exhibit it claims to be;
# verify by opening the .glb and reading asset.generator / the node names.
#
# Identified by parsing each .glb's JSON chunk (generator, copyright, node,
# mesh and material names) and computing a transform-aware scene bbox.
const PLACEHOLDER_MODELS := [
	# Khronos sample "Duck" (COLLADA2GLTF, mesh LOD3spShape, material blinn3-fx).
	# Floats 0.95 m over its plinth with its head 0.74 m out through the case lid.
	# Fallback "box": a 0.95 m cube tilted (24,38,12) over a shadow disc -- the
	# Falling Cube Exhibit frozen mid-fall, which is what Wing A's sign promises.
	"falling_cube",
	# Khronos sample "DamagedHelmet" (Blender glTF exporter, node
	# node_damagedHelmet_-6514). A sci-fi flight helmet filling the case wall to
	# wall, nothing to do with a clock. Fallback "box": the same tilted emissive
	# cube + shadow disc, which is what models/README.md lists for this slot.
	"broken_clock",
	# Khronos sample "Avocado" (glTF Tools for Unity, node/mesh "Avocado").
	# 6.3 cm of fruit hanging in mid-air inside a 2.25 m case. Fallback "drop":
	# a 0.84 m teardrop with a cone tail and a splash torus -- a waterdrop frozen
	# mid-fall, i.e. the Frozen Drop Exhibit.
	"frozen_drop",
	# Khronos sample "Lantern" (glTF Tools for Unity; children LanternPole_Body /
	# _Chain / _Lantern). A 25.7 m lamp post: 24 m of it stands above Space Wing
	# C's roof, it punches through the east wall, and its lantern head lands 9.6 m
	# from its own pedestal. Fallback "portal": a 2.4 x 2.9 x 0.3 m prism arch over
	# a translucent portal plane -- the spatial-curvature portal Wing C advertises.
	"portal_arch",
	# Khronos sample "MetalRoughSpheres" (AGI / Ed Mackey, CC-BY 4.0) -- a PBR
	# material test grid of 501,776 triangles, 9.6 m wide, 2.54 m through the
	# ceiling and 3.39 m below the floor, swallowing its own case, pedestal and
	# the containment ring. Fallback "heavy_sphere": a 1.5 m sphere sunk into a
	# cracked plinth, i.e. one impossibly dense mass, which is the exhibit.
	"superheavy_sphere",
]


## Where a name's file actually lives, or "" when there is none.
##
## Two directories are searched, in this order:
##   res://models/<name>.glb           assets the owner bought or downloaded
##   res://models/lowpoly/<name>.glb   assets generated by tools/lowpoly/
##
## Keeping them in separate folders is deliberate. models/ belongs to the owner
## and nothing in it may be removed; models/lowpoly/ is BUILD OUTPUT, rewritten
## wholesale every time `python tools/lowpoly/build_props.py` runs, so anything
## hand-edited in there is lost on the next build and no purchased asset may
## ever be stored in it.
##
## The owner's folder is checked first, so replacing a generated stand-in with
## a real model is just a matter of dropping the file into models/ under the
## same name -- no code change, and the generator keeps working untouched.
static func _resolve_path(model_name: String) -> String:
	if MODEL_PATHS.has(model_name):
		var mapped := str(MODEL_PATHS[model_name])
		return mapped if ResourceLoader.exists(mapped) else ""
	var owned := "res://models/%s.glb" % model_name
	if ResourceLoader.exists(owned):
		return owned
	var generated := "res://models/lowpoly/%s.glb" % model_name
	if ResourceLoader.exists(generated):
		return generated
	return ""


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
	# Every supplied museum asset is eligible EXCEPT the known stand-ins, which
	# are refused before the file is even looked up so the caller's procedural
	# fallback -- the authored exhibit -- runs instead. Authored call-site scale
	# and rotation keep inconsistent source units under control; procedural
	# geometry remains the fallback whenever import or instantiation fails.
	if model_name in PLACEHOLDER_MODELS:
		return null
	var path := _resolve_path(model_name)
	if path.is_empty():
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
	# The instantiated root carries the GLB's own name ("Sketchfab_model", "FAB
	# converted model") or none at all, so several placements collide and Godot
	# renames them to @Node3D@NNN -- unaddressable from tests and from code that
	# looks a placed exhibit up by name. Name the holder after the asset, tagged
	# with its position when the same asset is placed more than once.
	var holder_name := model_name
	if parent.has_node(NodePath(holder_name)):
		holder_name = "%s %s" % [model_name, world_position]
	instance.name = holder_name
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


## Hulls, cached per Mesh. Deriving them was essentially the entire synchronous
## cost of building the museum: measured headless with _cache already warm, the
## sixteen archive models spent ~2.6 s of a ~2.7 s build inside
## create_convex_collision(), while the four names in NON_BLOCKING -- the branch
## that skips collision altogether -- cost 0.0-0.1 ms each. Instantiating meshes
## is NOT the cost: dressing the museum with the game/props/ libraries took the
## mesh count from 1173 to 3127 and moved the total by under 60 ms.
##
## The waste was re-derivation. _cache already shares one PackedScene per path,
## and instantiate() hands every instance the SAME Mesh resource, yet each
## placement re-hulled it -- and the hull for a given mesh never varies. Shape3D
## is shareable between bodies, so one hull per Mesh now serves every placement.
##
## Keyed by the Mesh object rather than by model path: one GLB carries several
## meshes, and nothing stops two GLBs sharing one.
static var _convex_shapes: Dictionary = {}
static var _trimesh_shapes: Dictionary = {}


static func _shape_for(mesh: Mesh, use_trimesh: bool) -> Shape3D:
	var cache: Dictionary = _trimesh_shapes if use_trimesh else _convex_shapes
	if cache.has(mesh):
		return cache[mesh]
	# Exact concave collider for the hollow architecture in TRIMESH_COLLISION;
	# a cleaned hull for everything else.
	#
	# simplify is deliberately FALSE, and it is where the build time went. It
	# runs a convex DECOMPOSITION to reduce the hull's plane count, which is
	# both expensive and pointless when the goal is a single hull. Measured per
	# model, clean+simplify vs clean alone:
	#   wooden_bookcases_with_books   10,284 verts   511.0 ms  ->   4.1 ms
	#   наблюдатель                  524,772 verts   780.9 ms  -> 183.0 ms
	#   dumpsters_glb                 23,914 verts   231.0 ms  ->   9.0 ms
	#   уличная лампа                119,929 verts   321.9 ms  ->  40.5 ms
	#   gallery_bare_concrete_wall    80,485 verts   280.6 ms  ->  45.7 ms
	# Note the cost barely tracks vertex count: a 10 k mesh paid 511 ms, 125x
	# what the same mesh costs without the flag.
	#
	# The resulting hull has more planes, so a contact test against it is a
	# little dearer -- but it is also the EXACT convex hull rather than an
	# approximation of one, so it is tighter, never looser. That matters here:
	# test_blocker_regressions asserts the Atrium -> Time Wing B doorway still
	# admits the player capsule, and a looser hull is what would break it.
	var shape: Shape3D
	if use_trimesh:
		shape = mesh.create_trimesh_shape()
	else:
		shape = mesh.create_convex_shape(true, false)
	cache[mesh] = shape
	return shape


## Reproduces exactly what create_convex_collision()/create_trimesh_collision()
## build -- a StaticBody3D named "<mesh>_col" parented to the MeshInstance3D,
## carrying one CollisionShape3D -- so node counts, node paths and the
## "*Collision*" re-entrancy guard above all behave as before.
static func _attach_collision(mesh_instance: MeshInstance3D, shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	body.name = "%s_col" % mesh_instance.name
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	mesh_instance.add_child(body)


static func _ensure_collisions(root: Node3D, use_trimesh := false) -> void:
	if root.find_child("*Collision*", true, false) != null:
		return
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var shape := _shape_for(mesh_instance.mesh, use_trimesh)
		if shape == null:
			# QuickHull cannot build a polyhedron from coplanar points, so flat
			# decal planes and needle meshes yield nothing. The engine helpers
			# produced an empty collider for these; skipping is the same thing
			# without the dead node.
			continue
		_attach_collision(mesh_instance, shape)


## True when place() would return a model for this name. Placeholders answer
## false even though their file exists, so a caller that asks first and a caller
## that just tries place() cannot disagree about what is on the pedestal.
static func has_model(model_name: String) -> bool:
	if model_name in PLACEHOLDER_MODELS:
		return false
	return not _resolve_path(model_name).is_empty()
