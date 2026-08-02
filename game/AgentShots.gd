@tool
class_name AgentShots
extends RefCounted
## Saving screenshots in a form the review agent can actually open.
##
## THE PROBLEM THIS SOLVES.
##
## The review tooling reads images through one call, file_read_media(path),
## which takes a path and nothing else -- no quality, no scale, no page. It
## times out on PNGs over roughly half a megabyte, and even a successful read
## of a big file comes back truncated to a fraction of the picture. That limit
## lives in the client, outside this repository, so it cannot be raised from
## here. The only variable under our control is what the file weighs.
##
## So the fix is on the producing side, and it is mostly about the format.
## A 960 x 540 screenshot of a detailed 3D scene is 0.8-1.4 MB as PNG, because
## PNG is lossless and every blade of noise-textured grass is real entropy.
## The same frame as JPEG at quality 0.72 is 50-90 KB -- ten to twenty times
## under the limit -- and for judging architecture, planting and light the
## lossy artefacts are irrelevant.
##
## WHAT GETS WRITTEN, per shot:
##
##   <dir>/<name>.png            full resolution, lossless, for the human
##   <dir>/view/<name>.jpg       whole frame, long edge VIEW_EDGE, agent-readable
##   <dir>/tiles/<name>_r0c1.jpg quadrant crops at full pixel density
##
## The tiles are the part that buys back what JPEG downscaling costs. A crop
## of one quarter of a 1920-wide frame, resized to 760, still carries roughly
## the original pixel density, so a seam, a z-fight or a gap between two roof
## slabs stays visible. Downscaling the whole frame hides exactly those.
##
## Every write reports its byte size, and anything over READ_LIMIT_BYTES is
## flagged in the log: a shot nobody can open is worse than no shot, because
## it looks like proof.

## Long edge, in pixels, of the reviewable copies.
##
## Measured, not guessed. At 760 px / quality 0.72 a forecourt shot weighed
## 47 KB and read back fine, but the reply carries the same base64 twice, once
## as content and once as structuredContent, so the real cost is double the
## file. These values land a whole-frame view near 25 KB, which leaves room for
## several shots in one pass instead of one shot eating the budget.
const VIEW_EDGE := 640
## Long edge of each detail tile.
const TILE_EDGE := 640
## JPEG quality. 0.62 is the knee at this size: below it the thin geometry that
## matters here -- railings, glazing bars, balusters -- mushes into the stone
## behind it, above it the byte count climbs with nothing visible gained.
const JPEG_QUALITY := 0.62
## Soft budget per file. Halved from the observed timeout threshold to cover
## the doubled payload described above.
const READ_LIMIT_BYTES := 240000


## Write one shot in all its forms.
##
## img       -- the captured frame; never modified (callers reuse it)
## out_dir   -- absolute directory, already created by the caller
## base_name -- file stem, no extension
## tiles     -- grid divisor for detail crops; 2 gives four quadrants, 0/1 none
##
## Returns { "png": path, "view": path, "tiles": [paths], "sizes": {path: bytes} }
static func save_set(img: Image, out_dir: String, base_name: String,
		tiles: int = 2) -> Dictionary:
	var view_dir := "%s/view" % out_dir
	var tile_dir := "%s/tiles" % out_dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.make_dir_recursive_absolute(view_dir)
	if tiles > 1:
		DirAccess.make_dir_recursive_absolute(tile_dir)

	var result := {"png": "", "view": "", "tiles": [], "sizes": {}}

	# Full resolution, lossless. This one is for the person, not the agent.
	var png_path := "%s/%s.png" % [out_dir, base_name]
	if img.save_png(png_path) == OK:
		result["png"] = png_path
		result["sizes"][png_path] = _size_of(png_path)
	else:
		push_error("[AGENT SHOTS] png failed: %s" % png_path)

	# Whole frame, small and lossy. duplicate() first -- resizing in place
	# would hand the tile pass an already-shrunken image.
	var view: Image = img.duplicate()
	_fit(view, VIEW_EDGE)
	var view_path := "%s/%s.jpg" % [view_dir, base_name]
	if view.save_jpg(view_path, JPEG_QUALITY) == OK:
		result["view"] = view_path
		result["sizes"][view_path] = _size_of(view_path)
	else:
		push_error("[AGENT SHOTS] view failed: %s" % view_path)

	# Detail crops at native pixel density.
	if tiles > 1:
		var w := img.get_width()
		var h := img.get_height()
		var cw := int(float(w) / float(tiles))
		var ch := int(float(h) / float(tiles))
		for row in range(tiles):
			for col in range(tiles):
				# Last row/column absorbs the rounding remainder, so the crops
				# cover the frame with no missed strip down the right edge.
				var rw: int = (w - cw * col) if col == tiles - 1 else cw
				var rh: int = (h - ch * row) if row == tiles - 1 else ch
				var region := Rect2i(cw * col, ch * row, rw, rh)
				var tile: Image = img.get_region(region)
				_fit(tile, TILE_EDGE)
				var tile_path := "%s/%s_r%dc%d.jpg" % [tile_dir, base_name, row, col]
				if tile.save_jpg(tile_path, JPEG_QUALITY) == OK:
					result["tiles"].append(tile_path)
					result["sizes"][tile_path] = _size_of(tile_path)
				else:
					push_error("[AGENT SHOTS] tile failed: %s" % tile_path)

	return result


## Print one line per written file, flagging anything too heavy to read back.
static func report(result: Dictionary, label: String = "AGENT SHOTS") -> void:
	var sizes: Dictionary = result.get("sizes", {})
	for path: String in sizes.keys():
		var bytes: int = sizes[path]
		var flag := ""
		# The PNG is expected to be over budget; it is not the readable copy.
		if bytes > READ_LIMIT_BYTES and not path.ends_with(".png"):
			flag = "  <-- OVER READ BUDGET"
		print("[%s] %7.1f KB  %s%s"
			% [label, float(bytes) / 1024.0, _tail(path), flag])


## Scale an image so its longest edge is `edge`, keeping aspect. Images already
## smaller than that are left alone: upscaling adds bytes and no information.
static func _fit(img: Image, edge: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var longest: int = maxi(w, h)
	if longest <= edge or longest == 0:
		return
	var scale := float(edge) / float(longest)
	img.resize(maxi(1, int(round(float(w) * scale))),
		maxi(1, int(round(float(h) * scale))), Image.INTERPOLATE_LANCZOS)


static func _size_of(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var n := f.get_length()
	f.close()
	return int(n)


## Last two path components, so the log stays readable on Windows paths.
static func _tail(path: String) -> String:
	var parts := path.replace("\\", "/").split("/")
	if parts.size() < 2:
		return path
	return "%s/%s" % [parts[parts.size() - 2], parts[parts.size() - 1]]
