class_name TreeLib
extends RefCounted

# ===========================================================================
#  Tree library
#
#  Serves the tree meshes baked by tools/bake_trees.gd out of the
#  PlantGenerator addon's L-system. Replaces the old hand-built trees, which
#  were cones and spheres assembled from seven-plus nodes each.
#
#  Two ways to plant:
#
#    build()       one MeshInstance3D. For the handful of trees the player
#                  walks right up to, where an individual yaw and scale is
#                  worth a draw call of its own.
#
#    build_field() a MultiMeshInstance3D per species variant per map chunk.
#                  For belts, avenues and roadside bands -- hundreds of trees
#                  collapse into a few draw calls, and the chunking keeps
#                  frustum culling meaningful instead of drawing a whole
#                  forest because one corner of it is on screen.
#
#  Re-bake with:
#    godot --headless --path . --script res://tools/bake_trees.gd
# ===========================================================================

const MESH_DIR := "res://models/trees"

## Baked variants per species. Must match tools/bake_trees.gd.
const VARIANTS := {
	"oak": 4,
	"pine": 3,
	"birch": 3,
}

## Per-species scale spread. Applied on top of the baked height, so an oak
## still reads as an oak next to a birch.
const SCALE_RANGE := {
	"oak": Vector2(0.82, 1.18),
	"pine": Vector2(0.80, 1.30),
	"birch": Vector2(0.85, 1.15),
}

## Chunk size for build_field batching, in metres. Big enough that a belt is a
## few draw calls, small enough that off-screen chunks actually cull.
const CHUNK := 48.0

static var _cache: Dictionary = {}
static var _warned: Dictionary = {}


## Loads (and caches) one baked variant. Returns null and warns once per
## missing file, so a forgotten bake degrades to empty ground instead of
## spamming the log from inside a placement loop.
static func mesh_for(species: String, variant: int) -> Mesh:
	var key := "%s_%d" % [species, variant]
	if _cache.has(key):
		return _cache[key]
	var path := "%s/%s.tres" % [MESH_DIR, key]
	if not ResourceLoader.exists(path):
		if not _warned.has(key):
			_warned[key] = true
			push_warning("[TreeLib] missing baked mesh %s -- run tools/bake_trees.gd" % path)
		return null
	var mesh := ResourceLoader.load(path)
	_cache[key] = mesh
	return mesh


static func variant_count(species: String) -> int:
	return int(VARIANTS.get(species, 1))


## Which baked copy a given seed gets. Deterministic, so a replanted map is
## identical to the one the capture tests photographed.
static func variant_for(species: String, seed_value: int) -> int:
	return abs(seed_value) % variant_count(species)


static func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Seeded yaw and scale. Shared by both planting paths so a tree looks the
## same whether it ended up as its own node or inside a MultiMesh.
static func _variation(species: String, seed_value: int) -> Array:
	var rng := _rng(seed_value)
	var span: Vector2 = SCALE_RANGE.get(species, Vector2(0.85, 1.15))
	var yaw := rng.randf_range(0.0, TAU)
	var scale_factor := rng.randf_range(span.x, span.y)
	# A slight lean stops a stand of trees reading as a row of flagpoles.
	var lean := rng.randf_range(-0.035, 0.035)
	return [yaw, scale_factor, lean]


static func _transform_for(species: String, origin: Vector3, seed_value: int) -> Transform3D:
	var v := _variation(species, seed_value)
	var basis := Basis()
	basis = basis.rotated(Vector3.UP, v[0])
	basis = basis.rotated(Vector3.RIGHT, v[2])
	basis = basis.scaled(Vector3.ONE * v[1])
	return Transform3D(basis, origin)


## Plants one tree as its own node.
static func build(parent: Node3D, species: String, origin: Vector3,
		seed_value: int, vis := 160.0) -> Node3D:
	var variant := variant_for(species, seed_value)
	var mesh := mesh_for(species, variant)
	if mesh == null:
		return null

	var instance := MeshInstance3D.new()
	var node_name := "%s Tree" % species.capitalize()
	if parent.has_node(NodePath(node_name)):
		node_name = "%s %s" % [node_name, origin]
	instance.name = node_name
	instance.mesh = mesh
	instance.transform = _transform_for(species, origin, seed_value)
	if vis > 0.0:
		instance.visibility_range_end = vis
		instance.visibility_range_fade_mode = \
			GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(instance)
	return instance


## Plants many trees as chunked MultiMesh batches.
##
## `entries` is an array of dictionaries: {species, origin, seed}. Returns the
## container node holding the batches.
static func build_field(parent: Node3D, field_name: String, entries: Array,
		vis := 0.0) -> Node3D:
	var root := Node3D.new()
	var unique_name := field_name
	if parent.has_node(NodePath(unique_name)):
		unique_name = "%s %d" % [field_name, parent.get_child_count()]
	root.name = unique_name
	parent.add_child(root)

	# Bucket by species variant and map chunk.
	var buckets: Dictionary = {}
	for entry in entries:
		var species: String = entry["species"]
		var origin: Vector3 = entry["origin"]
		var seed_value: int = entry["seed"]
		var variant := variant_for(species, seed_value)
		var cell := Vector2i(int(floor(origin.x / CHUNK)), int(floor(origin.z / CHUNK)))
		var key := "%s_%d_%d_%d" % [species, variant, cell.x, cell.y]
		if not buckets.has(key):
			buckets[key] = {"species": species, "variant": variant, "items": []}
		buckets[key]["items"].append(_transform_for(species, origin, seed_value))

	for key in buckets:
		var bucket: Dictionary = buckets[key]
		var mesh := mesh_for(bucket["species"], bucket["variant"])
		if mesh == null:
			continue
		var transforms: Array = bucket["items"]

		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = transforms.size()
		for i in range(transforms.size()):
			multimesh.set_instance_transform(i, transforms[i])

		var instance := MultiMeshInstance3D.new()
		instance.name = "Batch %s" % key
		instance.multimesh = multimesh
		if vis > 0.0:
			instance.visibility_range_end = vis
			instance.visibility_range_fade_mode = \
				GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		root.add_child(instance)

	return root


## Convenience: the species cycle the map has always used, kept in one place so
## the drive set, the grounds and the forecourt stay consistent.
static func species_for_index(index: int) -> String:
	match index % 3:
		0:
			return "oak"
		1:
			return "pine"
		_:
			return "birch"
