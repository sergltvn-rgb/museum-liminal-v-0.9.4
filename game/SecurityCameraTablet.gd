extends Node
## FNAF-style security tablet.
##
## TAB / Y            -- open / close the camera feed
## "," / "." or LT/RT -- previous / next feed (works without a mouse)
## CAM button         -- jump straight to a feed: click it, or move the focus
##                       ring onto it with the D-pad and press A
## Arrows / right stick -- pan and tilt the active camera
## F / RB             -- toggle the camera's IR floodlight
##
## Setup: add a plain Node to the main scene and attach this script.
## It finds the player through the "player" group and builds its own
## Camera3D nodes and UI at runtime. Positions mirror the CCTV bodies
## placed by FirstMuseumMap.gd (corner mounts).
##
## The mini-map is a read-out, not decoration: it carries the operator's own
## position, the wedge the live feed is actually looking down (mount heading
## plus whatever pan has been dialled in), and a ring on the camera the current
## objective wants confirmed. All three are drawn, not built out of nodes, so
## they cost nothing while the tablet is down.
##
## The whole picture is finished by a CRTOverlay (game/CRTOverlay.gd) added as
## the last child of the UI root -- scanlines, tube vignette and a phosphor
## wash, so the workstation reads as a security monitor rather than as a web
## dashboard. It obeys SettingsManager.reduced_flashes and quality_preset; see
## that file's header and UITheme's CRT section for what it costs the mini-map.

const MAP_SCALE := 3.2
const MAP_ORIGIN := Vector2(35.0, 49.0)  # world offset -> map pixels
## The CRT green the game's accent was taken from. Nothing here reads it any
## more -- every Control in this file gets its green from UITheme.ACCENT, which
## is this value -- but it stays: UITheme.gd names `SecurityCameraTablet.GREEN`
## three times as the provenance of ACCENT and of ACCENT_DIM
## (`GREEN.darkened(0.25)`), and a dangling citation is worse than a constant.
const GREEN := Color(0.2, 0.78, 0.42)
const PAN_SPEED := 55.0
const TILT_SPEED := 40.0
## Vertical opening of every feed. Shared with the mini-map view cone so the
## wedge on the map and the picture on screen cannot drift apart.
const CAM_FOV := 75.0

# --- MINI-MAP GEOMETRY ------------------------------------------------------
## Inset between the map panel's edge and the mapped floor plan.
const MAP_PAD := 14.0
## Nominal chip size. The real one is measured once the chips are in the tree
## (see _build_ui) because a Button's minimum size depends on its theme.
const MAP_CHIP_SIZE := Vector2(34, 22)
## Content margins for the map chips. UITheme.PAD_X/PAD_Y would inflate a chip
## past its slot -- see _map_chip_theme().
const MAP_CHIP_PAD_X := 4
const MAP_CHIP_PAD_Y := 2
## Breathing room the separation pass leaves between two chips.
const MAP_CHIP_GAP := 3.0
## Upper bound on separation passes; the current mounts settle in 6.
const MAP_LAYOUT_PASSES := 8
## Penetrations below this are float noise, not an overlap.
const MAP_LAYOUT_EPSILON := 0.01
## How far the view cone reaches, in world metres.
const CONE_REACH := 11.0
const CONE_SEGMENTS := 12
const PLAYER_MARK_RADIUS := 4.0
# Tilt travel around each camera's mounted pitch. The mounts already aim down:
# the steepest is CAM 08 at -20.6 deg -- it looks at a distribution board 4.5 m
# away -- so anything under 21 leaves that feed permanently staring at the floor
# with the horizon out of reach. (CAM 07 used to sit beside it at -20.8 deg; now
# that the post hangs inside Space Wing C and looks 11.8 m down the wing instead
# of 4.3 m at a door, its mounted pitch is -9.2 deg.) 28 clears the worst mount
# by 7 deg and is applied symmetrically, which still gives every feed at least
# 34 deg of downward travel for detail.
const TILT_LIMIT := 28.0

# --- STATIC BURST -----------------------------------------------------------
## Peak opacity of the near-white burst that covers a feed change, and the
## ceiling that replaces it for a player who has asked for reduced flashing.
## 0.85 of near-white over a night-time museum feed is a full-screen white
## flash; 0.30 still reads as a cut without being one. The burst itself is not
## dropped: it is the only thing that tells the operator the picture changed
## rather than glitched, and CAM_HINT_CONTROLS never mentions the cut.
const STATIC_FLASH_PEAK := 0.85
const STATIC_FLASH_REDUCED := 0.30

const CAMS: Array = [
	{"id": "CAM 01", "label": "CAM_ENTRANCE",
		"pos": Vector3(-9.6, 3.0, 33.6), "target": Vector3(0, 1.0, 25)},
	{"id": "CAM 02", "label": "CAM_ATRIUM_WEST",
		"pos": Vector3(-13.6, 3.0, 12.6), "target": Vector3(0, 1.0, 0)},
	{"id": "CAM 03", "label": "CAM_ATRIUM_EAST",
		"pos": Vector3(13.6, 3.0, -12.6), "target": Vector3(0, 1.0, 0)},
	{"id": "CAM 04", "label": "CAM_WATCH_POST",
		"pos": Vector3(-33.8, 2.9, -5.8), "target": Vector3(-25, 1.0, 0)},
	{"id": "CAM 05", "label": "CAM_WING_A_GRAVITY",
		"pos": Vector3(16.4, 3.0, -7.8), "target": Vector3(28, 1.0, 0)},
	{"id": "CAM 06", "label": "CAM_WING_B_TIME",
		"pos": Vector3(-11.8, 3.0, -16.4), "target": Vector3(0, 1.0, -24)},
	# Post 07 hangs inside Space Wing C, in its south-east corner, looking back
	# along the wing at the blast door. It used to hang in Time Wing B and frame
	# that door from the far side of the wall at x = 13, which left the wing's
	# three exhibits -- the ones ExhibitPuzzleController requires this feed for --
	# behind solid geometry. Mount and target are the literals _add_cameras builds
	# the housing from; test_map_verification pins the two together.
	{"id": "CAM 07", "label": "CAM_WING_C_DOOR",
		"pos": Vector3(33.6, 2.9, -30.8), "target": Vector3(24, 1.0, -24)},
	# CAM_BASEMENT_LIFT is a stale key id, not a stale label: the museum has no
	# basement, and the catalogue row now reads "Atrium — Power Panel" /
	# "Атриум — электрощит" in both columns. The feed frames the Atrium
	# distribution board, which is the prop this aim point actually meets.
	{"id": "CAM 08", "label": "CAM_BASEMENT_LIFT",
		"pos": Vector3(8.8, 2.9, 11.8), "target": Vector3(12.5, 1.2, 14.4)},
	{"id": "CAM 09", "label": "CAM_PLANETARIUM",
		"pos": Vector3(-9.2, 3.0, -34.4), "target": Vector3(0, 1.2, -41)},
	{"id": "CAM 10", "label": "CAM_RESTORATION",
		"pos": Vector3(-33.8, 2.9, 18.4), "target": Vector3(-25, 1.0, 22)},
	# South-west corner of Mass Wing D. From the north-west one the imported
	# superheavy_sphere mesh stood between the post and the Mass Pendulum.
	{"id": "CAM 11", "label": "CAM_WING_D_MASS",
		"pos": Vector3(42.2, 2.9, 6.8), "target": Vector3(52, 1.0, 0)},
]

# Mini-map rooms: [name, world center (x,z), size (w,d), open from night N].
# The last field replaces a hard-coded "locked" flag: wings C and D are sealed
# behind blast doors that GameManager removes on nights 2 and 3, so a constant
# made the map keep painting them red in rooms the player had already walked
# through. 1 == open from the first shift.
const ROOMS: Array = [
	["CAM_ENTRANCE", Vector2(0, 25), Vector2(22, 20), 1],
	["CAM_ROOM_ATRIUM", Vector2(0, 0), Vector2(30, 30), 1],
	["CAM_ROOM_OFFICE", Vector2(-25, 0), Vector2(20, 14), 1],
	["CAM_ROOM_STORAGE", Vector2(-25, 12), Vector2(20, 10), 1],
	["CAM_ROOM_ARCHIVE", Vector2(-25, -12), Vector2(20, 10), 1],
	["CAM_ROOM_LAB", Vector2(-25, 22), Vector2(20, 10), 1],
	["CAM_ROOM_WING_A", Vector2(28, 0), Vector2(26, 18), 1],
	["CAM_ROOM_WING_B", Vector2(0, -24), Vector2(26, 18), 1],
	["CAM_PLANETARIUM", Vector2(0, -41), Vector2(20, 16), 1],
	["CAM_ROOM_WING_C", Vector2(24, -24), Vector2(22, 16), 2],
	["CAM_ROOM_WING_D", Vector2(52, 0), Vector2(22, 16), 3],
]

var _player: CharacterBody3D = null
var _cams: Array[Camera3D] = []
var _lights: Array[SpotLight3D] = []
var _base_rot: Array[Vector3] = []
var _buttons: Array[Button] = []
var _room_boxes: Array[StyleBoxFlat] = []
var _layer: CanvasLayer
var _cam_label: Label
var _rec_dot: ColorRect
var _static_rect: ColorRect
var _crt: CRTOverlay
var _map_bounds := Vector2.ZERO
var _chip_active: StyleBoxFlat
var _cone: Control
var _marks: Control
var _enhancements: Node = null
var _open := false
var _active := 0
var _time := 0.0
var _static_alpha := 0.0
var _pan := 0.0
var _tilt := 0.0
var _flash_on := false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_make_cameras()
	_build_ui()


func _make_cameras() -> void:
	for c in CAMS:
		var cam := Camera3D.new()
		cam.name = String(c["id"]).replace(" ", "")
		add_child(cam)
		cam.global_position = c["pos"]
		cam.look_at(c["target"], Vector3.UP)
		# Push the lens just past the physical camera prop, otherwise the
		# prop's own round lens disc sits right in front of the view and
		# fills the screen as an unexplained circle.
		cam.global_position += -cam.global_transform.basis.z * 0.55
		cam.near = 0.15
		cam.fov = CAM_FOV
		cam.current = false
		_cams.append(cam)
		_base_rot.append(cam.rotation_degrees)
		# IR floodlight aligned with the lens, toggled with F.
		var light := SpotLight3D.new()
		light.name = "Cam Floodlight"
		light.light_energy = 3.2
		light.spot_range = 22.0
		light.spot_angle = 42.0
		light.spot_angle_attenuation = 1.4
		light.light_color = Color(0.82, 0.9, 1.0)
		light.shadow_enabled = true
		light.visible = false
		cam.add_child(light)
		_lights.append(light)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	_layer.visible = false
	add_child(_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)

	# Static flash shown for a moment on every camera switch.
	_static_rect = ColorRect.new()
	_static_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_static_rect.color = Color(0.8, 0.85, 0.8, 0.0)
	_static_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_static_rect)

	# Camera name, top-left, with a blinking REC dot. DANGER is a fill token, and
	# a recording tally is exactly that -- UITheme's header calls this dot out as
	# the one legitimate use of the palette's red.
	_rec_dot = ColorRect.new()
	_rec_dot.color = UITheme.DANGER
	_rec_dot.position = Vector2(24, 28)
	_rec_dot.size = Vector2(16, 16)
	root.add_child(_rec_dot)

	_cam_label = Label.new()
	_cam_label.position = Vector2(52, 18)
	UITheme.apply_text(_cam_label, UITheme.TITLE, UITheme.ACCENT)
	root.add_child(_cam_label)

	var hint := Label.new()
	hint.text = tr("CAM_HINT_CONTROLS")
	UITheme.apply_text(hint, UITheme.BODY, UITheme.MUTED)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 24
	hint.offset_top = -44
	root.add_child(hint)

	# Mini-map panel, bottom-right. SCRIM rather than a panel fill: this thing
	# floats over the live picture and the operator has to keep reading the
	# picture through it, which is what SCRIM (SURFACE at 88%) is -- the 0.88 it
	# already carried, now sourced from the palette. The frame stays green
	# because the map is live chrome: BORDER_ACCENT.
	_map_bounds = Vector2((63.0 + MAP_ORIGIN.x) * MAP_SCALE + MAP_PAD * 2.0,
		(35.0 + MAP_ORIGIN.y) * MAP_SCALE + MAP_PAD * 2.0)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UITheme.stylebox(
		UITheme.SCRIM, UITheme.BORDER_ACCENT, UITheme.BORDER_WIDTH, UITheme.RADIUS_LG))
	panel.theme = _map_chip_theme()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -(_map_bounds.x + 16.0)
	panel.offset_top = -(_map_bounds.y + 16.0)
	panel.offset_right = -16.0
	panel.offset_bottom = -16.0
	root.add_child(panel)

	# Room outlines. The lock colour is not baked here: _refresh_map_locks()
	# repaints these style boxes every time the tablet is raised.
	for r in ROOMS:
		var rp := Panel.new()
		var rsb := StyleBoxFlat.new()
		rsb.set_border_width_all(UITheme.BORDER_WIDTH)
		rp.add_theme_stylebox_override("panel", rsb)
		_room_boxes.append(rsb)
		var c: Vector2 = r[1]
		var s: Vector2 = r[2]
		rp.position = _to_panel(c - s * 0.5)
		rp.size = s * MAP_SCALE
		rp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(rp)
		var rl := Label.new()
		rl.text = tr(String(r[0]))
		UITheme.apply_text(rl, UITheme.CAPTION, UITheme.MUTED)
		rl.position = rp.position + Vector2(4, 2)
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(rl)

	# View cone for the live feed, under the chips so it never hides one.
	_cone = Control.new()
	_cone.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cone.draw.connect(_draw_view_cone)
	panel.add_child(_cone)

	# Camera buttons on the map. These must be focusable: a pad has no cursor, so
	# FOCUS_NONE left every feed but CAM 01 unreachable on a controller. TAB is
	# still safe — _input() runs before the viewport hands the event to the GUI,
	# and it marks the toggle as handled, so a focused button never sees it and
	# cannot swallow it for focus navigation.
	for i in range(CAMS.size()):
		var btn := Button.new()
		btn.text = "%02d" % (i + 1)
		btn.focus_mode = Control.FOCUS_ALL
		btn.pressed.connect(_switch_to.bind(i))
		panel.add_child(btn)
		_buttons.append(btn)

	# Size is measured, not assumed. get_combined_minimum_size() only sees the
	# map panel's Theme from inside the tree, and Control.set_size() silently
	# clamps *up* to that minimum -- so a chip that turned out wider than
	# MAP_CHIP_SIZE would quietly break the separation pass below, which is the
	# one thing guaranteeing every chip stays clickable.
	var slot := MAP_CHIP_SIZE
	for btn in _buttons:
		var minimum := btn.get_combined_minimum_size()
		slot = Vector2(maxf(slot.x, minimum.x), maxf(slot.y, minimum.y))
	var spots := _chip_positions(slot)
	for i in range(_buttons.size()):
		_buttons[i].size = slot
		_buttons[i].position = spots[i]

	# Player marker and the objective ring, on top of the chips. Mouse-ignoring,
	# so drawing over a chip costs the chip nothing.
	_marks = Control.new()
	_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_map_marks)
	panel.add_child(_marks)

	# The tube's glass, added last so it covers the whole workstation picture:
	# the live feed, the static burst, the header, the hint and the mini-map.
	# That is the diegetic reading -- all of it is drawn by one monitor, so all
	# of it wears the same scanlines -- and it is also the only order in which
	# the burst and the treatment compose. _static_rect is the first child, so
	# it paints near-white over the feed; with the overlay above, that white-out
	# still carries scanlines and the tube vignette, which is what a real
	# monitor does. Below the burst, the overlay would simply vanish for the
	# quarter-second the burst lasts, i.e. exactly when the operator is looking.
	#
	# The mini-map keeps its legibility on purpose, not by luck: UITheme's CRT
	# section computes the darkening at the worst room label and holds it inside
	# the 4.5:1 contrast budget.
	_crt = CRTOverlay.new()
	_crt.name = "Crt Glass"
	root.add_child(_crt)

	_refresh_map_locks()


## Theme for the eleven mini-map chips.
##
## UITheme.apply_button() is the right call for a normal screen and the wrong
## one here: its PAD_X/PAD_Y (12/8) put a Button's minimum size at roughly
## 38x31, Control.set_size() clamps up to the minimum, and the separation pass
## then has to shove the fattened chips up to 15 px off their mounts -- 4.7 m of
## museum, on a map whose whole job is saying where things are. Same tokens,
## tighter content margins, and hung on the panel as a Theme so all eleven chips
## share one set of resources instead of carrying five overrides each.
func _map_chip_theme() -> Theme:
	var theme := Theme.new()
	theme.set_font_size("font_size", "Button", UITheme.CAPTION)
	theme.set_color("font_color", "Button", UITheme.MUTED)
	theme.set_color("font_hover_color", "Button", UITheme.ON_SURFACE)
	theme.set_color("font_pressed_color", "Button", UITheme.ACCENT)
	theme.set_color("font_focus_color", "Button", UITheme.ON_SURFACE)
	theme.set_stylebox("normal", "Button", _chip_style(UITheme.SURFACE, UITheme.BORDER))
	theme.set_stylebox("hover", "Button",
		_chip_style(UITheme.SURFACE_RAISED, UITheme.BORDER_ACCENT))
	# The live feed wears the pressed look permanently (see _switch_to), so the
	# two share one resource rather than drifting apart.
	_chip_active = _chip_style(UITheme.ACCENT_FILL, UITheme.ACCENT)
	theme.set_stylebox("pressed", "Button", _chip_active)
	var ring := UITheme.focus()
	ring.set_corner_radius_all(UITheme.RADIUS_SM)
	theme.set_stylebox("focus", "Button", ring)
	return theme


func _chip_style(bg: Color, border: Color) -> StyleBoxFlat:
	return UITheme.stylebox(bg, border, UITheme.BORDER_WIDTH, UITheme.RADIUS_SM,
		MAP_CHIP_PAD_X, MAP_CHIP_PAD_Y)


## Where the eleven chips sit, in map-panel coordinates.
##
## CAM 03 and CAM 05 are mounted 5.5 m apart across the atrium, which is 17 px
## at MAP_SCALE -- half a chip -- so their 34x22 rects overlapped by 25x7 px.
## Godot hit-tests children front to back and CAM 05 is the later child, so that
## whole band answered for CAM 05 and the bottom-right corner of CAM 03 could
## not be clicked at all.
##
## Chips start on their true mapped position and are then pushed apart until no
## two rects intersect: each pass separates an overlapping pair along its
## shallower axis and moves both halves equally, so the outcome does not depend
## on child order, then clamps them back inside the panel. For the current
## mounts this settles in 6 passes and moves only CAM 03, 05 and 07, by at most
## 6.2 px; the tightest surviving gap is 3.0 px and no pair intersects.
func _chip_positions(size: Vector2) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for c in CAMS:
		var wp: Vector3 = c["pos"]
		spots.append(_clamp_to_map(_to_panel(Vector2(wp.x, wp.z)) - size * 0.5, size))
	var span := size + Vector2(MAP_CHIP_GAP, MAP_CHIP_GAP)
	for _pass in range(MAP_LAYOUT_PASSES):
		var moved := false
		for i in range(spots.size()):
			for j in range(i + 1, spots.size()):
				var delta := spots[j] - spots[i]
				var pen := Vector2(span.x - absf(delta.x), span.y - absf(delta.y))
				if pen.x <= MAP_LAYOUT_EPSILON or pen.y <= MAP_LAYOUT_EPSILON:
					continue
				moved = true
				var push := Vector2.ZERO
				if pen.x < pen.y:
					push.x = pen.x * 0.5 * (1.0 if delta.x >= 0.0 else -1.0)
				else:
					push.y = pen.y * 0.5 * (1.0 if delta.y >= 0.0 else -1.0)
				spots[i] = _clamp_to_map(spots[i] - push, size)
				spots[j] = _clamp_to_map(spots[j] + push, size)
		if not moved:
			break
	return spots


func _clamp_to_map(point: Vector2, size: Vector2) -> Vector2:
	return Vector2(clampf(point.x, 0.0, maxf(0.0, _map_bounds.x - size.x)),
		clampf(point.y, 0.0, maxf(0.0, _map_bounds.y - size.y)))


func _to_map(world: Vector2) -> Vector2:
	return (world + MAP_ORIGIN) * MAP_SCALE


## _to_map() in the map panel's own coordinates, i.e. past its inset.
func _to_panel(world: Vector2) -> Vector2:
	return _to_map(world) + Vector2(MAP_PAD, MAP_PAD)


## Repaint the mini-map's lock state. Called on every open, never baked: wings C
## and D are sealed by blast doors that GameManager tears down on nights 2 and 3,
## so a const flag made the map keep them red in rooms the player had already
## walked through.
func _refresh_map_locks() -> void:
	var night := _current_night()
	for i in range(_room_boxes.size()):
		var box := _room_boxes[i]
		var locked := night < int(ROOMS[i][3])
		# Both fills keep the alpha they had: these are wash tints over the live
		# picture, not surfaces, and at full strength they would bury the feed.
		box.bg_color = Color(UITheme.DANGER, 0.10) if locked \
			else Color(UITheme.ACCENT, 0.08)
		box.border_color = UITheme.DANGER if locked else UITheme.ACCENT_DIM


## The camera the current objective wants confirmed, or -1 when there is none.
##
## GameplayEnhancements owns the number, publishes itself in the
## "gameplay_enhancements" group from its own _ready(), and is optional
## furniture -- the tablet has to keep working in the map scene and in the test
## suites, neither of which builds one -- so every hop is null-guarded and a
## miss costs one group lookup per frame while the tablet is up. Reading a
## private field is the contract already running in the other direction:
## GameplayEnhancements._update_scan() polls this node's `_open` and `_active`.
func _required_camera() -> int:
	if not is_instance_valid(_enhancements):
		_enhancements = get_tree().get_first_node_in_group("gameplay_enhancements")
	if _enhancements == null:
		return -1
	# Confirmed already: stop pointing at a camera the operator is done with.
	var done: Variant = _enhancements.get("_scan_complete")
	if typeof(done) == TYPE_BOOL and bool(done):
		return -1
	var value: Variant = _enhancements.get("_required_camera")
	if typeof(value) != TYPE_INT:
		return -1
	var index := int(value)
	return index if index >= 0 and index < _buttons.size() else -1


## Wedge for the live feed: where it is pointed right now, pan included.
func _draw_view_cone() -> void:
	if _active < 0 or _active >= _base_rot.size():
		return
	var wp: Vector3 = CAMS[_active]["pos"]
	var origin := _to_panel(Vector2(wp.x, wp.z))
	# A Godot camera looks down -Z, so a yaw of theta aims it at
	# (-sin theta, -cos theta) in world XZ; _to_map() is a pure scale and offset,
	# so that same vector is the heading on the map with no extra correction.
	# Pan is added rather than read back off the Camera3D because the operator
	# can be panning a feed whose transform this frame is still the old one.
	var yaw := deg_to_rad(_base_rot[_active].y + _pan)
	var facing := Vector2(-sin(yaw), -cos(yaw))
	var half := _feed_half_angle()
	var reach := CONE_REACH * MAP_SCALE
	var fan := PackedVector2Array([origin])
	for i in range(CONE_SEGMENTS + 1):
		var t := float(i) / float(CONE_SEGMENTS)
		fan.append(origin + facing.rotated(lerpf(-half, half, t)) * reach)
	_cone.draw_colored_polygon(fan, Color(UITheme.ACCENT, 0.16))
	_cone.draw_line(origin, origin + facing * reach, Color(UITheme.ACCENT, 0.55), 1.0)


## Half the cone's opening, in radians. CAM_FOV is the *vertical* opening --
## Camera3D defaults to KEEP_HEIGHT -- and a plan view needs the horizontal one,
## which is the vertical widened by the viewport's aspect. 16:9 is the fallback
## for the frame before the viewport exists.
func _feed_half_angle() -> float:
	var aspect := 16.0 / 9.0
	var viewport := get_viewport()
	if viewport != null:
		var size := viewport.get_visible_rect().size
		if size.y > 0.0:
			aspect = size.x / size.y
	return atan(tan(deg_to_rad(CAM_FOV) * 0.5) * aspect)


## The two marks that go over the chips: the objective's camera, and the
## operator's own position.
func _draw_map_marks() -> void:
	var required := _required_camera()
	if required >= 0:
		var chip := _buttons[required]
		_marks.draw_rect(Rect2(chip.position, chip.size).grow(3.0),
			UITheme.WARNING, false, 2.0)
	if _player == null or not is_instance_valid(_player):
		return
	# Clamped, not hidden: the museum fits the map, but a player who somehow
	# leaves it is better reported at the edge than dropped off the panel.
	var here := _clamp_to_map(
		_to_panel(Vector2(_player.global_position.x, _player.global_position.z))
			- Vector2(PLAYER_MARK_RADIUS, PLAYER_MARK_RADIUS),
		Vector2(PLAYER_MARK_RADIUS, PLAYER_MARK_RADIUS) * 2.0
	) + Vector2(PLAYER_MARK_RADIUS, PLAYER_MARK_RADIUS)
	# Dark collar first: the marker has to read on the green wash of an open room
	# and on the red wash of a sealed one.
	_marks.draw_circle(here, PLAYER_MARK_RADIUS + 1.5, UITheme.SURFACE)
	_marks.draw_circle(here, PLAYER_MARK_RADIUS, UITheme.ON_SURFACE)


## Source of truth for the wing locks: GameManager's night counter. It is the
## very number GameManager feeds to _unlock_for_night(), so the mini-map cannot
## disagree with the museum. Reading a private field mirrors what
## GameplayEnhancements and ExhibitPuzzleController already do for the same value.
func _current_night() -> int:
	var game := _game_manager()
	if game != null:
		var value: Variant = game.get("_night")
		if typeof(value) == TYPE_INT and int(value) > 0:
			return int(value)
	return _night_from_blast_doors()


## Fallback for a tablet running without a GameManager (standalone scene, tests).
## FirstMuseumMap leaves a blast door in the scene until the wing opens, so the
## doors that are still standing tell us how far the shift has progressed.
func _night_from_blast_doors() -> int:
	var map := get_tree().get_first_node_in_group("museum_map")
	if map == null:
		return 1
	if map.find_child("Wing C*Blast Door*", true, false) != null:
		return 1
	if map.find_child("Wing D*Blast Door*", true, false) != null:
		return 2
	return 3


# _input (not _unhandled_input): GUI must never eat the toggle key.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("tablet"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("flashlight"):
		_flash_on = not _flash_on
		_update_floodlight()
		_sfx("tablet_click")
		get_viewport().set_input_as_handled()
	elif _open and _is_pan_tilt(event):
		# Pan / tilt is polled in _process; swallow the events here so the mini-map
		# buttons -- focusable since the pad fix -- do not also treat the arrow keys
		# as focus navigation and walk the focus ring across the map while the
		# operator is only aiming the lens. The D-pad and the left stick still move
		# focus: neither is bound to a camera axis.
		get_viewport().set_input_as_handled()


## True when the event drives the active camera rather than the UI. Guarded
## because InputBootstrap creates these actions in its own _ready().
func _is_pan_tilt(event: InputEvent) -> bool:
	for action in ["camera_pan_left", "camera_pan_right",
			"camera_tilt_up", "camera_tilt_down"]:
		if InputMap.has_action(action) and event.is_action(action):
			return true
	return false


# GameManager owns PlayerController.controls_enabled. Sibling node in the main
# scene, same lookup _toggle() already used to flash the office-only refusal.
func _game_manager() -> Node:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("GameManager")


# The tablet must not decide on its own that the player may move again: while a
# fail / night-done / win overlay is up GameManager freezes the player, because
# gamepad A drives both "jump" and "confirm" and those overlays answer "confirm".
# Standalone (no GameManager in the scene) the tablet keeps working on its own.
func _controls_allowed() -> bool:
	var game := _game_manager()
	if game != null and game.has_method("player_controls_allowed"):
		return bool(game.call("player_controls_allowed"))
	return true


# Called by GameManager when a transition takes control away: the tablet holds
# the viewport camera while it is open, so it cannot outlive that transition.
func close() -> void:
	if _open:
		_toggle()


func _toggle() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		if _player == null:
			return
	# A terminal overlay is up: opening would steal the viewport camera and free
	# the cursor behind a screen that only answers "confirm". No _flash() here --
	# the fail overlay is drawn over GameManager's message label.
	if not _open and not _controls_allowed():
		_sfx("fail")
		return
	# CCTV is a fixed security workstation, not a portable supernatural tablet.
	if not _open and not _player_is_in_office():
		var game := _game_manager()
		if game != null and game.has_method("_flash"):
			game.call("_flash", tr("CAM_ACCESS_OFFICE_ONLY"), UITheme.WARNING)
		_sfx("fail")
		return
	_open = not _open
	_layer.visible = _open
	_sfx("tablet_open" if _open else "tablet_click")
	if _open:
		_player.controls_enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_map_locks()
		# Accessibility and quality can both have been changed from the pause
		# menu since the tablet was last raised. The overlay also listens to
		# SettingsManager.settings_changed, so this is a second belt for the
		# case where the settings node only joined its group after _ready.
		if _crt != null:
			_crt.refresh()
		# force: the feed being restored is by definition the active one, and
		# raising the tablet has to make its camera current again.
		_switch_to(_active, true)
	else:
		_update_floodlight()
		_player.controls_enabled = _controls_allowed()
		var player_cam := _player.get_node_or_null("Player Camera") as Camera3D
		if player_cam:
			player_cam.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _player_is_in_office() -> bool:
	if _player == null:
		return false
	var position := _player.global_position
	return position.x >= -34.5 and position.x <= -15.5 \
		and position.z >= -6.5 and position.z <= 6.5


## `force` is for the one caller that must relight a feed that is already the
## active one: _toggle(), when the tablet is raised.
func _switch_to(index: int, force: bool = false) -> void:
	# Re-selecting the feed already on screen is a no-op. The mini-map buttons are
	# focusable since the pad fix, so one of them always holds the ring while the
	# tablet is open, and ui_accept (Space / Enter / pad A -- the same A bound to
	# "jump" and "confirm") re-fires "pressed" on it. Without this guard a reflexive
	# press ran the full switch on an unchanged feed: it zeroed the pan and tilt the
	# operator had just dialled in, blasted static over the picture and clicked.
	# Genuine feed changes fall straight through, static flash included.
	if not force and _open and index == _active:
		return
	_sfx("tablet_click")
	# Reset the previous camera to its mounted orientation.
	_cams[_active].rotation_degrees = _base_rot[_active]
	_active = index
	_pan = 0.0
	_tilt = 0.0
	_cams[index].rotation_degrees = _base_rot[index]
	_cams[index].current = true
	_cam_label.text = "%s — %s" % [CAMS[index]["id"], tr(String(CAMS[index]["label"]))]
	_static_alpha = STATIC_FLASH_REDUCED if _reduced_flashes() else STATIC_FLASH_PEAK
	_update_floodlight()
	# The live feed's chip holds the pressed look. This replaces a `modulate` of
	# 1.6 -- a multiply, which on the new near-black chip fill produced a chip
	# that was still near-black.
	for i in range(_buttons.size()):
		if i == index:
			_buttons[i].add_theme_stylebox_override("normal", _chip_active)
		else:
			_buttons[i].remove_theme_stylebox_override("normal")
	# Keep the focus ring on the live feed. Without this a pad player who cycled
	# with the triggers would still have the ring parked on whatever button the
	# D-pad last visited, and pressing A would yank them back to it.
	if _open and index < _buttons.size() and _buttons[index].is_visible_in_tree():
		_buttons[index].grab_focus()


## Step through the feeds. This is the only feed control a pad has: every
## mini-map button needs a pointer or the focus ring, and from night 2 the
## incident cannot be resolved until a specific camera confirms the source.
func _cycle_camera(step: int) -> void:
	if _cams.is_empty():
		return
	_switch_to(wrapi(_active + step, 0, _cams.size()))


## InputBootstrap builds the actions in its own _ready(); guard the lookup so the
## tablet still runs in a scene that does not carry one.
func _cam_cycle_step() -> int:
	if InputMap.has_action("cam_next") and Input.is_action_just_pressed("cam_next"):
		return 1
	if InputMap.has_action("cam_prev") and Input.is_action_just_pressed("cam_prev"):
		return -1
	return 0


func _update_floodlight() -> void:
	for i in range(_lights.size()):
		_lights[i].visible = _open and _flash_on and i == _active


func _process(delta: float) -> void:
	if not _open:
		return
	_time += delta
	_rec_dot.visible = fmod(_time, 1.0) < 0.6
	# The map overlays track the player, the pan and the objective, all of which
	# move under us; redrawing two mouse-ignoring Controls is cheaper than
	# working out which of the three changed, and neither runs while the tablet
	# is down because this function returns above.
	_cone.queue_redraw()
	_marks.queue_redraw()
	if _static_alpha > 0.0:
		_static_alpha = maxf(0.0, _static_alpha - delta * 4.0)
		# The per-frame random jitter is what makes the burst read as static
		# rather than as a dissolve -- and it is also, precisely, a strobe at
		# frame rate. A player who asked for reduced flashing gets the smooth
		# fade instead, off the lower ceiling set in _switch_to.
		_static_rect.color.a = _static_alpha if _reduced_flashes() \
			else _static_alpha * randf_range(0.6, 1.0)
	else:
		_static_rect.color.a = 0.0
	# Feed cycling is polled, not read from _input(): an analog trigger emits a
	# motion event for every step past the deadzone, so is_action_pressed() on the
	# event would fire several times per pull. Input tracks the edge for us.
	var step := _cam_cycle_step()
	if step != 0:
		_cycle_camera(step)
		# No early return: bailing out here skipped this frame's pan/tilt
		# integration, so holding a trigger while nudging the stick stuttered.
		# The block below re-reads _active, so it aims the feed we just switched to.
	# Pan / tilt the active camera around its mounted orientation. No negation on
	# the tilt: get_axis returns +1 for camera_tilt_up and a larger rotation.x
	# pitches a Godot camera up, so negating it aimed "up" at the floor — the
	# reverse of the player's own mouse look.
	var pan_dir := -Input.get_axis("camera_pan_left", "camera_pan_right")
	var tilt_dir := Input.get_axis("camera_tilt_down", "camera_tilt_up")
	if pan_dir != 0.0 or tilt_dir != 0.0:
		_pan = clampf(_pan + pan_dir * PAN_SPEED * delta, -65.0, 65.0)
		_tilt = clampf(_tilt + tilt_dir * TILT_SPEED * delta, -TILT_LIMIT, TILT_LIMIT)
		var base: Vector3 = _base_rot[_active]
		_cams[_active].rotation_degrees = Vector3(base.x + _tilt, base.y + _pan, 0.0)


## True when the player has asked for reduced flashing.
##
## Same resolution as FirstMuseumMap._process and GameplayEnhancements'
## _update_void / _update_watch: one group lookup, null-guarded, field read via
## `.get()`. Polled rather than cached because those three poll it too, and
## because the only caller runs while the tablet is up -- a lookup a frame for
## the seconds the operator is actually watching a feed.
func _reduced_flashes() -> bool:
	var settings := get_tree().get_first_node_in_group("settings_manager")
	return settings != null and bool(settings.get("reduced_flashes"))


func _sfx(sound: String) -> void:
	var am := get_tree().get_first_node_in_group("audio_manager")
	if am != null and am.has_method("play_sfx"):
		am.play_sfx(sound)
