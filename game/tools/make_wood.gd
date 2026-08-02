# Generates a seamless oak texture set into textures/WoodProcedural/.
#
# None of the archives in models/ ship a wood set, but the museum is full of
# wood: counters, benches, bookcases, door leaves, handrails. Rather than
# leave all of that flat-shaded, the grain is synthesised here once and saved
# as ordinary image files, so the runtime just loads a normal PBR set and
# knows nothing about how it was made.
#
# Run (headless is fine, no rendering involved):
#   godot --headless --path . --script res://game/tools/make_wood.gd

extends SceneTree

const SIZE := 1024
const OUT_DIR := "res://textures/WoodProcedural/"
const JPEG_QUALITY := 0.92

# Whole number of rings across the tile: anything else breaks the seam.
const RINGS := 7.0

const DARK := Color(0.239, 0.145, 0.078)
const LIGHT := Color(0.541, 0.369, 0.204)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var warp := FastNoiseLite.new()
	warp.noise_type = FastNoiseLite.TYPE_SIMPLEX
	warp.seed = 20260731
	warp.fractal_octaves = 4

	var fibre := FastNoiseLite.new()
	fibre.noise_type = FastNoiseLite.TYPE_SIMPLEX
	fibre.seed = 5507
	fibre.fractal_octaves = 3

	var pore := FastNoiseLite.new()
	pore.noise_type = FastNoiseLite.TYPE_SIMPLEX
	pore.seed = 1213
	pore.fractal_octaves = 2

	var albedo := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var rough := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var height := PackedFloat32Array()
	height.resize(SIZE * SIZE)

	for y in SIZE:
		for x in SIZE:
			# Slow wander of the rings, stretched along the plank direction.
			var wander := _tile(warp, x, y, 0.0042, 0.0011)
			# Ring pattern: a periodic sine so the left and right edges meet.
			var u := float(x) / float(SIZE)
			var rings := sin(TAU * (u * RINGS + wander * 1.35))
			# Sharpen the late wood into thin dark lines.
			var band: float = pow(absf(rings), 0.55)

			# Fine fibre running the length of the plank.
			var grain := _tile(fibre, x, y, 0.115, 0.0065)
			# Open pores: short dark dashes typical of oak.
			var pores := _tile(pore, x, y, 0.28, 0.02)
			var pore_mask: float = smoothstep(0.42, 0.86, pores)

			var tone: float = clampf(band * 0.78 + grain * 0.22 + 0.06, 0.0, 1.0)
			tone = clampf(tone - pore_mask * 0.22, 0.0, 1.0)

			var colour := DARK.lerp(LIGHT, tone)
			albedo.set_pixel(x, y, colour)

			# Late wood and open pores stay matte, early wood takes polish.
			var r: float = clampf(0.74 - tone * 0.26 + pore_mask * 0.12, 0.16, 0.95)
			rough.set_pixel(x, y, Color(r, r, r))

			# Height drives the normal map: pores sink, hard grain stands proud.
			height[y * SIZE + x] = tone * 0.65 - pore_mask * 0.35

	var normal := _normal_map(height)

	var col_path := OUT_DIR + "WoodOak_COL.jpg"
	var rough_path := OUT_DIR + "WoodOak_ROUGH.jpg"
	var nrm_path := OUT_DIR + "WoodOak_NRM.png"

	var failures := 0
	failures += _save_jpg(albedo, col_path)
	failures += _save_jpg(rough, rough_path)
	if normal.save_png(nrm_path) != OK:
		print("[fail] ", nrm_path)
		failures += 1
	else:
		print("[ok] ", nrm_path, " ", normal.get_width(), " x ", normal.get_height())

	print("WOOD: ", SIZE, " x ", SIZE, ", rings: ", RINGS, ", errors: ", failures)
	quit(0 if failures == 0 else 1)


func _save_jpg(image: Image, path: String) -> int:
	if image.save_jpg(path, JPEG_QUALITY) != OK:
		print("[fail] ", path)
		return 1
	print("[ok] ", path, " ", image.get_width(), " x ", image.get_height())
	return 0


# Bilinear wrap blend. Plain noise does not tile, so the field is sampled at
# all four wrapped offsets and cross-faded by position. Opposite edges then
# carry identical values and the texture repeats without a visible seam.
func _tile(noise: FastNoiseLite, x: int, y: int, sx: float, sy: float) -> float:
	var fx := float(x) * sx
	var fy := float(y) * sy
	var wx := float(SIZE) * sx
	var wy := float(SIZE) * sy
	var u := float(x) / float(SIZE)
	var v := float(y) / float(SIZE)

	var a := noise.get_noise_2d(fx, fy)
	var b := noise.get_noise_2d(fx - wx, fy)
	var c := noise.get_noise_2d(fx, fy - wy)
	var d := noise.get_noise_2d(fx - wx, fy - wy)

	var top: float = lerpf(a, b, u)
	var bottom: float = lerpf(c, d, u)
	return lerpf(top, bottom, v)


func _normal_map(height: PackedFloat32Array) -> Image:
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var strength := 2.6
	for y in SIZE:
		for x in SIZE:
			# Wrapped neighbours keep the normal map as seamless as the albedo.
			var left := height[y * SIZE + posmod(x - 1, SIZE)]
			var right := height[y * SIZE + posmod(x + 1, SIZE)]
			var up := height[posmod(y - 1, SIZE) * SIZE + x]
			var down := height[posmod(y + 1, SIZE) * SIZE + x]

			var n := Vector3((left - right) * strength, (up - down) * strength, 1.0).normalized()
			image.set_pixel(x, y, Color(
				n.x * 0.5 + 0.5,
				n.y * 0.5 + 0.5,
				n.z * 0.5 + 0.5))
	return image
