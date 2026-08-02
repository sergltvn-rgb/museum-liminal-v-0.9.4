extends SceneTree

# ===========================================================================
#  Tree baker
#
#  Builds tree meshes with the PlantGenerator addon's L-system engine and
#  saves them as plain ArrayMesh resources in res://models/trees/.
#
#  Why bake instead of using Plant3D nodes directly:
#    * Plant3D draws into an ImmediateMesh inside _draw() and re-runs it from
#      _process() whenever wind is on. With ~180 trees on the map that is a
#      per-frame rebuild of every tree -- unusable in game.
#    * Plant3D's branches are two crossed quads, so they read as flat cards up
#      close. Here every segment becomes a tapered 6-sided tube with real
#      normals, which lights correctly under the museum's sun.
#    * A saved mesh can be fed to MultiMesh, so a whole forest belt costs one
#      draw call instead of one per tree.
#
#  The L-system itself (axiom, rules, widths, branch tapering) is still the
#  addon's -- we only replace the drawing step.
#
#  Run:  godot --headless --script res://tools/bake_trees.gd
# ===========================================================================

const LPlant := preload("res://addons/PlantGenerator/plant.gd")
const LEAF_TEXTURE_PATH := "res://addons/PlantGenerator/Assets/leaf.png"
const OUT_DIR := "res://models/trees"

## Sides per branch tube. Six is the sweet spot: a round-enough silhouette at
## the distances the player ever sees a trunk, at half the cost of eight.
const SIDES := 6

## Branches thinner than this fraction of the base width get no tube of their
## own. Keep this LOW: the fine twig network is most of what makes a silhouette
## read as a tree rather than as a pole with lumps. An earlier 0.12 cut the
## whole twig layer away and the trees looked like posts.
const TWIG_CUTOFF := 0.04

## How fast a segment narrows over its own length. Real branches taper hard;
## 0.82 left them looking like scaffolding tube.
const SEGMENT_TAPER := 0.72

## Leaves drawn per growth tip, spread over three staggered layers so a cluster
## has depth instead of being a flat pinwheel.
const LEAVES_PER_TIP := 9

## How much a branch narrows at each level of the branching hierarchy.
##
## We compute width ourselves from the nesting depth instead of reading the
## addon's `desired_width`. That field barely decays -- on a pine every limb
## came back at nearly full trunk width, which is why the first bakes looked
## like a bundle of poles.
const DEPTH_TAPER := 0.56

## Leaves added along each leafy twig.
const LEAVES_PER_TWIG := 3


class Recipe:
	extends RefCounted
	var id: String
	var axiom: String
	var rules: Dictionary[String, String]
	var steps: int
	var angle: float
	var branch_length: float
	var branch_width: float
	var randomness: float
	var tropism: float
	var leaf_scale: float
	var leafy_depth: int
	var leaf_color: Color
	var bark_color: Color
	var target_height: float
	var variants: int

	func _init(id_: String, axiom_: String, rules_: Dictionary[String, String],
			steps_: int, angle_: float, branch_length_: float,
			branch_width_: float, randomness_: float, tropism_: float,
			leaf_scale_: float, leafy_depth_: int, leaf_color_: Color,
			bark_color_: Color, target_height_: float, variants_: int) -> void:
		id = id_
		axiom = axiom_
		rules = rules_
		steps = steps_
		angle = angle_
		branch_length = branch_length_
		branch_width = branch_width_
		randomness = randomness_
		tropism = tropism_
		leaf_scale = leaf_scale_
		leafy_depth = leafy_depth_
		leaf_color = leaf_color_
		bark_color = bark_color_
		target_height = target_height_
		variants = variants_


func _recipes() -> Array:
	var oak_rules: Dictionary[String, String] = {
		"X": "f[&+X][&-X][^/X]fX",
	}
	var pine_rules: Dictionary[String, String] = {
		"X": "f[&&Y][//&&Y][////&&Y][//////&&Y]fX",
		# A whorl limb is recursive, so it grows out in several needle-bearing
		# segments. The earlier "F[+L][-L]L" stopped after one segment and left
		# the pine with a bare skeleton.
		"Y": "F[+L][-L][&L][^L]FY",
	}
	var birch_rules: Dictionary[String, String] = {
		"X": "f[+X][-X]fX",
	}
	return [
		# Broadleaf oak: wide, heavy, strongly branching, leaves out to the tips.
		# Trunk and first boughs stay bare; foliage starts two levels in.
		Recipe.new("oak", "X", oak_rules, 4, 28.0, 1.5, 0.34, 0.35, 0.22,
			1.30, 2, Color(0.20, 0.34, 0.14), Color(0.24, 0.19, 0.15), 10.5, 4),
		# Conifer pine: straight leader, whorls of short down-swept branches.
		# Needles ride every limb except the trunk itself: leafy from level 1.
		Recipe.new("pine", "X", pine_rules, 6, 52.0, 1.15, 0.30, 0.25, 0.55,
			0.85, 1, Color(0.13, 0.26, 0.16), Color(0.28, 0.19, 0.13), 12.0, 3),
		# Birch: slim, upright, airy crown, pale bark. Carries foliage well down
		# its thin branches, so it turns leafy one level earlier than the oak.
		Recipe.new("birch", "X", birch_rules, 4, 20.0, 1.35, 0.20, 0.40, 0.42,
			1.00, 1, Color(0.34, 0.46, 0.20), Color(0.74, 0.73, 0.69), 9.5, 3),
	]


# ---------------------------------------------------------------------------
#  Geometry buffers
# ---------------------------------------------------------------------------

var _bark_v: PackedVector3Array
var _bark_n: PackedVector3Array
var _bark_uv: PackedVector2Array
var _leaf_v: PackedVector3Array
var _leaf_n: PackedVector3Array
var _leaf_uv: PackedVector2Array


func _reset_buffers() -> void:
	_bark_v = PackedVector3Array()
	_bark_n = PackedVector3Array()
	_bark_uv = PackedVector2Array()
	_leaf_v = PackedVector3Array()
	_leaf_n = PackedVector3Array()
	_leaf_uv = PackedVector2Array()


## One tapered tube from `a` to `b`. `right`/`up` are the branch's own axes, so
## consecutive segments of the same branch line up instead of twisting.
func _add_branch(a: Vector3, b: Vector3, right: Vector3, up: Vector3,
		r_bottom: float, r_top: float, v0: float, v1: float) -> void:
	for i in range(SIDES):
		var a0 := TAU * float(i) / float(SIDES)
		var a1 := TAU * float(i + 1) / float(SIDES)
		var n0 := (right * cos(a0) + up * sin(a0)).normalized()
		var n1 := (right * cos(a1) + up * sin(a1)).normalized()
		var b0 := a + n0 * r_bottom
		var b1 := a + n1 * r_bottom
		var t0 := b + n0 * r_top
		var t1 := b + n1 * r_top
		var u0 := float(i) / float(SIDES)
		var u1 := float(i + 1) / float(SIDES)

		_bark_v.append(b0); _bark_n.append(n0); _bark_uv.append(Vector2(u0, v0))
		_bark_v.append(t0); _bark_n.append(n0); _bark_uv.append(Vector2(u0, v1))
		_bark_v.append(t1); _bark_n.append(n1); _bark_uv.append(Vector2(u1, v1))

		_bark_v.append(b0); _bark_n.append(n0); _bark_uv.append(Vector2(u0, v0))
		_bark_v.append(t1); _bark_n.append(n1); _bark_uv.append(Vector2(u1, v1))
		_bark_v.append(b1); _bark_n.append(n1); _bark_uv.append(Vector2(u1, v0))


## A single leaf quad. Rendered two-sided, so winding does not matter here.
func _add_leaf(at: Vector3, right: Vector3, up: Vector3, size: float) -> void:
	var r := right * size * 0.5
	var u := up * size
	var p0 := at - r
	var p1 := at + r
	var p2 := at + r + u
	var p3 := at - r + u
	var nrm := right.cross(up).normalized()

	_leaf_v.append(p0); _leaf_n.append(nrm); _leaf_uv.append(Vector2(0, 1))
	_leaf_v.append(p1); _leaf_n.append(nrm); _leaf_uv.append(Vector2(1, 1))
	_leaf_v.append(p2); _leaf_n.append(nrm); _leaf_uv.append(Vector2(1, 0))

	_leaf_v.append(p0); _leaf_n.append(nrm); _leaf_uv.append(Vector2(0, 1))
	_leaf_v.append(p2); _leaf_n.append(nrm); _leaf_uv.append(Vector2(1, 0))
	_leaf_v.append(p3); _leaf_n.append(nrm); _leaf_uv.append(Vector2(0, 0))


## A bushy cluster of leaves at a growth tip.
##
## Leaves are staggered back down the axis and jittered sideways, so the tip
## reads as a handful of foliage from any angle rather than as a flat pinwheel.
func _add_tip_cluster(at: Vector3, basis: Basis, size: float) -> void:
	var axis := -basis.z.normalized()
	for i in range(LEAVES_PER_TIP):
		var turn := TAU * float(i) * 0.618034
		var spun := basis.rotated(axis, turn)
		# Walk back along the twig as we go, so the cluster has length.
		var back := -axis * size * 0.42 * (float(i) / float(LEAVES_PER_TIP))
		var out := spun.x.normalized() * size * randf_range(0.05, 0.30)
		var droop := (axis + spun.y * randf_range(0.35, 1.10)).normalized()
		_add_leaf(at + back + out, spun.x.normalized(), droop,
			size * randf_range(0.75, 1.15))


## Leaves sprouting from the middle of a thin twig. Tip clusters alone leave the
## inner crown bare and the tree looks half-stripped.
func _add_twig_leaves(a: Vector3, b: Vector3, basis: Basis, size: float) -> void:
	var axis := -basis.z.normalized()
	for i in range(LEAVES_PER_TWIG):
		var t := (float(i) + 0.5) / float(LEAVES_PER_TWIG)
		var at := a.lerp(b, t)
		var spun := basis.rotated(axis, TAU * float(i) * 0.618034 + t * 2.4)
		var droop := (spun.y * -0.55 + spun.x * randf_range(-0.8, 0.8)
			+ axis * 0.35).normalized()
		_add_leaf(at, spun.x.normalized(), droop, size * randf_range(0.6, 0.95))


## Bend a growth basis towards world up. This is the addon's tropism idea, kept
## so pines stay poker-straight and oaks reach for the light.
func _apply_tropism(basis: Basis, strength: float) -> Basis:
	if strength == 0.0:
		return basis
	var growth := -basis.z
	var axis := growth.cross(Vector3.UP)
	if axis.length() < 0.001:
		return basis
	return basis.rotated(axis.normalized(), growth.angle_to(Vector3.UP) * strength)


func _walk(recipe: Recipe, sentence) -> void:
	var stack: Array = []
	var pos := Vector3.ZERO
	var basis := Basis().rotated(Vector3.LEFT, deg_to_rad(-90.0))
	var v_coord := 0.0
	var ang := deg_to_rad(recipe.angle)
	var base_width: float = recipe.branch_width
	# Branching depth: 0 on the trunk, +1 inside every bracketed sub-branch.
	var depth := 0

	for symbol in sentence.symbols:
		match symbol.character:
			"[":
				stack.push_front([pos, basis, v_coord, depth])
				depth += 1
			"]":
				if stack.is_empty():
					continue
				var state: Array = stack.pop_front()
				pos = state[0]
				basis = state[1]
				v_coord = state[2]
				depth = state[3]
			"F", "f":
				basis = _apply_tropism(basis, recipe.tropism)
				var dir := -basis.z.normalized()
				var seg: float = recipe.branch_length * symbol.attributes.length_factor
				var next := pos + dir * seg
				var w: float = base_width * pow(DEPTH_TAPER, float(depth))
				if w >= base_width * TWIG_CUTOFF:
					_add_branch(pos, next, basis.x.normalized(),
						basis.y.normalized(), w * 0.5, w * 0.5 * SEGMENT_TAPER,
						v_coord, v_coord + seg)
				if depth >= recipe.leafy_depth:
					_add_twig_leaves(pos, next, basis, recipe.leaf_scale)
				pos = next
				v_coord += seg
			"+":
				basis = basis.rotated(basis.y.normalized(), -ang)
			"-":
				basis = basis.rotated(basis.y.normalized(), ang)
			"&":
				basis = basis.rotated(basis.x.normalized(), -ang)
			"^":
				basis = basis.rotated(basis.x.normalized(), ang)
			"/":
				basis = basis.rotated(-basis.z.normalized(), ang)
			"\\":
				basis = basis.rotated(-basis.z.normalized(), -ang)
			"L", "l":
				_add_leaf(pos, basis.x.normalized(), -basis.z.normalized(),
					recipe.leaf_scale)
			"X", "Y":
				# An unexpanded tip: growth ran out of steps here, which is
				# exactly where foliage belongs. Fan a few quads around the axis
				# so the cluster reads as a leafy end from any angle.
				_add_tip_cluster(pos, basis, recipe.leaf_scale)


## Rescale so the tree stands on y = 0 with the requested height, and recentre
## it on its trunk. Callers can then place a tree by world position alone.
func _normalise(target_height: float) -> void:
	var all := _bark_v + _leaf_v
	if all.is_empty():
		return
	var mn := all[0]
	var mx := all[0]
	for p in all:
		mn = Vector3(minf(mn.x, p.x), minf(mn.y, p.y), minf(mn.z, p.z))
		mx = Vector3(maxf(mx.x, p.x), maxf(mx.y, p.y), maxf(mx.z, p.z))
	var height: float = maxf(mx.y - mn.y, 0.001)
	var k: float = target_height / height
	for i in range(_bark_v.size()):
		_bark_v[i] = Vector3(_bark_v[i].x * k, (_bark_v[i].y - mn.y) * k, _bark_v[i].z * k)
	for i in range(_leaf_v.size()):
		_leaf_v[i] = Vector3(_leaf_v[i].x * k, (_leaf_v[i].y - mn.y) * k, _leaf_v[i].z * k)


func _bark_material(recipe: Recipe) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = recipe.bark_color
	mat.roughness = 0.95
	mat.metallic = 0.0
	mat.resource_name = "%s_bark" % recipe.id
	return mat


func _leaf_material(recipe: Recipe) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = recipe.leaf_color
	mat.roughness = 0.9
	mat.metallic = 0.0
	# Leaves are single quads, so both faces must render.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Scissor, not blend: no sorting cost and no halo through the fog.
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	var tex := load(LEAF_TEXTURE_PATH)
	if tex is Texture2D:
		mat.albedo_texture = tex
	mat.resource_name = "%s_leaf" % recipe.id
	return mat


func _commit(recipe: Recipe) -> ArrayMesh:
	var mesh := ArrayMesh.new()

	if not _bark_v.is_empty():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(_bark_material(recipe))
		for i in range(_bark_v.size()):
			st.set_normal(_bark_n[i])
			st.set_uv(_bark_uv[i])
			st.add_vertex(_bark_v[i])
		st.generate_tangents()
		st.commit(mesh)

	if not _leaf_v.is_empty():
		var stl := SurfaceTool.new()
		stl.begin(Mesh.PRIMITIVE_TRIANGLES)
		stl.set_material(_leaf_material(recipe))
		for i in range(_leaf_v.size()):
			stl.set_normal(_leaf_n[i])
			stl.set_uv(_leaf_uv[i])
			stl.add_vertex(_leaf_v[i])
		stl.generate_tangents()
		stl.commit(mesh)

	return mesh


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var total_tris := 0

	for recipe in _recipes():
		for variant in range(recipe.variants):
			# Seeding the global RNG is what varies the copies: the addon's
			# branch-length randomiser calls randf() internally.
			seed(hash(recipe.id) + variant * 7919)

			var gen = LPlant.new(recipe.axiom, recipe.rules, recipe.steps,
				recipe.steps, recipe.randomness, recipe.branch_width)
			gen._ready()
			if gen.sentence == null:
				push_error("[BAKE] %s variant %d produced no sentence" % [recipe.id, variant])
				continue

			_reset_buffers()
			_walk(recipe, gen.sentence)
			_normalise(recipe.target_height)
			var mesh := _commit(recipe)

			var tris := (_bark_v.size() + _leaf_v.size()) / 3
			total_tris += tris
			var path := "%s/%s_%d.tres" % [OUT_DIR, recipe.id, variant]
			var err := ResourceSaver.save(mesh, path)
			if err != OK:
				push_error("[BAKE] failed to save %s (error %d)" % [path, err])
			else:
				print("[BAKE] %s  %d tris  (%d bark, %d leaf quads)" % [
					path, tris, _bark_v.size() / 6, _leaf_v.size() / 6])

	print("[BAKE] done, %d triangles total" % total_tris)
	quit()
