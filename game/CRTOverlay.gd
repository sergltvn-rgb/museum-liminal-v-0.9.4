class_name CRTOverlay
extends ColorRect
## Diegetic CRT treatment for the museum's in-world service screens.
##
## Add one as the LAST child of whatever is supposed to be a monitor:
##
##     var crt := CRTOverlay.new()
##     root.add_child(crt)
##
## It anchors to its parent's full rect, ignores the mouse, and paints
## scanlines, a tube vignette and a faint phosphor wash through
## res://shaders/CRTOverlay.gdshader.
##
## LAST child on purpose. The treatment is the glass of the tube, so everything
## the screen draws is seen through it -- including the CCTV tablet's white
## static burst on a feed change, which is a thing happening *on* the monitor
## and therefore carries scanlines like everything else. Put this node lower in
## the draw order and the first bright thing painted above it erases the effect;
## put it above and the two compose instead of fighting.
##
## Cheap by construction: one full-screen quad, no screen-texture read, no
## texture lookups, no branching, and no per-frame script work whatsoever. That
## matters because on the tablet this sits over a live 3D feed. It costs nothing
## at all while the screen is down, because a hidden CanvasLayer draws none of
## its children.
##
## The curvature is implied, not real. Barrel distortion needs a screen-texture
## sample per pixel and would bend the mini-map's room outlines, which are a
## read-out; a vignette that collapses towards the corners says "tube" for free.
##
##
## ACCESSIBILITY -- the reason this is a class and not four lines of setup.
##
## refresh() re-reads SettingsManager and rebuilds the uniform set:
##
##   reduced_flashes ON  -- a static vignette and nothing else. Scanlines, roll
##                          and hum are all multiplied by zero, which leaves the
##                          shader time-invariant: nothing it draws can move.
##   quality_preset 0    -- hidden outright, so the quad is never submitted and
##                          a weak GPU pays literally nothing.
##   quality_preset 1    -- vignette only, same picture as reduced_flashes.
##   quality_preset 2    -- the full treatment.
##
## The >= 1 / >= 2 split is the one SettingsManager._apply_quality() already
## uses (SSAO, SSR and glow at >= 1; SSIL and volumetric fog at >= 2), so the
## quality slider means the same thing here as it does everywhere else.
##
## The settings node is resolved exactly the way the three existing readers of
## `reduced_flashes` resolve it -- FirstMuseumMap._process,
## GameplayEnhancements._update_void and GameplayEnhancements._update_watch --
## one `get_first_node_in_group("settings_manager")`, null-guarded, field read
## through `.get()`. Those three poll every frame because they are already in
## _process; this node has no _process, so it reads on demand instead: once at
## _ready, again on every `settings_changed`, and whenever its owner raises the
## screen. Same resolution, no fourth pattern, no per-frame cost.

const SHADER_PATH := "res://shaders/CRTOverlay.gdshader"

## Quality preset at or below which nothing is drawn at all.
const OFF_QUALITY := 0
## Quality preset from which the animated half of the treatment is allowed.
const FULL_QUALITY := 2

## Multiplier over every UITheme strength. 1.0 is the tuned look; 0.0 hides the
## overlay. Owners of a smaller or busier screen can dial it back without
## touching the tokens, which stay the reference for the tablet.
var _intensity := 1.0
## False when res://shaders/CRTOverlay.gdshader could not be loaded. The overlay
## then stays hidden for good rather than falling back to a flat ColorRect,
## which is the one failure mode that would be worse than having no effect.
var _shader_ok := false


func _init() -> void:
	# Anchors here rather than in _ready() so a caller that wants the treatment
	# over a sub-rect can override them straight after new().
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	# Hidden until refresh() has confirmed a shader to paint with. ColorRect's
	# own `color` is left at its default and never read -- the shader assigns
	# COLOR outright -- and starting invisible is what guarantees the stock
	# white rect can never reach a frame.
	visible = false


func _ready() -> void:
	_shader_ok = _load_shader()
	refresh()


func _load_shader() -> bool:
	# Same guard chain FirstMuseumMap._apply_dome_shader() uses for the
	# containment dome: a project exported without the shaders/ folder must
	# degrade, not crash.
	if not ResourceLoader.exists(SHADER_PATH):
		return false
	var shader: Shader = load(SHADER_PATH)
	if shader == null:
		return false
	var mat := ShaderMaterial.new()
	mat.shader = shader
	material = mat
	return true


## Re-read the accessibility and quality settings and repaint accordingly.
##
## Cheap enough to call whenever the owning screen is raised: one group lookup,
## eight uniform writes, no allocation. Safe before the settings node exists --
## a museum scene without a SettingsManager (the standalone map, the headless
## suites) simply gets the full treatment, which is what those contexts had
## before this overlay existed.
func refresh() -> void:
	if not _shader_ok or _intensity <= 0.0:
		visible = false
		return
	var settings: Node = null
	if is_inside_tree():
		settings = get_tree().get_first_node_in_group("settings_manager")
	var quality := FULL_QUALITY
	var reduced := false
	if settings != null:
		var preset: Variant = settings.get("quality_preset")
		if typeof(preset) == TYPE_INT:
			quality = int(preset)
		reduced = bool(settings.get("reduced_flashes"))
		_watch(settings)
	if quality <= OFF_QUALITY:
		visible = false
		return
	visible = true
	# One boolean gates every time-dependent term in the shader. Anything added
	# to that shader later must be gated by it too, or the accessibility promise
	# in the header stops being true.
	var animate := not reduced and quality >= FULL_QUALITY
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("phosphor", UITheme.ACCENT)
	mat.set_shader_parameter("vignette_strength", UITheme.CRT_VIGNETTE * _intensity)
	mat.set_shader_parameter("vignette_power", UITheme.CRT_VIGNETTE_POWER)
	mat.set_shader_parameter("scanline_pitch", UITheme.CRT_SCANLINE_PITCH)
	mat.set_shader_parameter("scanline_strength",
		UITheme.CRT_SCANLINE * _intensity if animate else 0.0)
	mat.set_shader_parameter("roll_speed", UITheme.CRT_ROLL_SPEED if animate else 0.0)
	mat.set_shader_parameter("glow_strength",
		UITheme.CRT_GLOW * _intensity if animate else 0.0)
	mat.set_shader_parameter("flicker_strength",
		UITheme.CRT_FLICKER * _intensity if animate else 0.0)


## Connect once to SettingsManager.settings_changed so a toggle flipped in the
## pause menu lands immediately instead of waiting for the owner's next
## refresh(). Re-checked on every call rather than latched behind a flag, so a
## settings node that is replaced (scene reload) is picked up again.
func _watch(settings: Node) -> void:
	if not settings.has_signal("settings_changed"):
		return
	if not settings.is_connected("settings_changed", refresh):
		settings.connect("settings_changed", refresh)


## Scale the whole treatment. 1.0 is the UITheme look; 0.0 takes it off.
##
## The tablet does not use this -- it is full-screen, which is what the tokens
## are tuned against. It exists for the smaller readouts that come next: the
## vignette is UV-relative, so on a 600 px panel a full-strength corner falloff
## lands on the text instead of on empty glass, and the strength has to come
## down with the rect.
func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, 1.0)
	refresh()
