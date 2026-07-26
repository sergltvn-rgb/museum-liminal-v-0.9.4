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

const MAP_SCALE := 3.2
const MAP_ORIGIN := Vector2(35.0, 49.0)  # world offset -> map pixels
const GREEN := Color(0.2, 0.78, 0.42)
const PAN_SPEED := 55.0
const TILT_SPEED := 40.0
# Tilt travel around each camera's mounted pitch. The mounts already aim down:
# the steepest are CAM 07 (-20.8 deg) and CAM 08 (-20.6 deg), so anything under
# 21 leaves those two feeds permanently staring at the floor with the horizon
# out of reach. 28 clears the worst mount by 7 deg and is applied symmetrically,
# which still gives every feed at least 34 deg of downward travel for detail.
const TILT_LIMIT := 28.0

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
	{"id": "CAM 07", "label": "CAM_WING_C_DOOR",
		"pos": Vector3(9.6, 2.9, -20.6), "target": Vector3(12.5, 1.2, -24)},
	{"id": "CAM 08", "label": "CAM_BASEMENT_LIFT",
		"pos": Vector3(8.8, 2.9, 11.8), "target": Vector3(12.5, 1.2, 14.4)},
	{"id": "CAM 09", "label": "CAM_PLANETARIUM",
		"pos": Vector3(-9.2, 3.0, -34.4), "target": Vector3(0, 1.2, -41)},
	{"id": "CAM 10", "label": "CAM_RESTORATION",
		"pos": Vector3(-33.8, 2.9, 18.4), "target": Vector3(-25, 1.0, 22)},
	{"id": "CAM 11", "label": "CAM_WING_D_MASS",
		"pos": Vector3(42.2, 2.9, -6.8), "target": Vector3(52, 1.0, 0)},
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
		cam.fov = 75.0
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

	# Camera name, top-left, with a blinking REC dot.
	_rec_dot = ColorRect.new()
	_rec_dot.color = Color(0.9, 0.12, 0.1)
	_rec_dot.position = Vector2(24, 28)
	_rec_dot.size = Vector2(16, 16)
	root.add_child(_rec_dot)

	_cam_label = Label.new()
	_cam_label.position = Vector2(52, 18)
	_cam_label.add_theme_font_size_override("font_size", 30)
	_cam_label.add_theme_color_override("font_color", GREEN)
	root.add_child(_cam_label)

	var hint := Label.new()
	hint.text = tr("CAM_HINT_CONTROLS")
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 24
	hint.offset_top = -44
	root.add_child(hint)

	# Mini-map panel, bottom-right.
	var inner := Vector2((63.0 + MAP_ORIGIN.x) * MAP_SCALE,
		(35.0 + MAP_ORIGIN.y) * MAP_SCALE)
	var pad := 14.0
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.05, 0.03, 0.88)
	sb.border_color = GREEN
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -(inner.x + pad * 2.0 + 16.0)
	panel.offset_top = -(inner.y + pad * 2.0 + 16.0)
	panel.offset_right = -16.0
	panel.offset_bottom = -16.0
	root.add_child(panel)

	# Room outlines. The lock colour is not baked here: _refresh_map_locks()
	# repaints these style boxes every time the tablet is raised.
	for r in ROOMS:
		var rp := Panel.new()
		var rsb := StyleBoxFlat.new()
		rsb.set_border_width_all(1)
		rp.add_theme_stylebox_override("panel", rsb)
		_room_boxes.append(rsb)
		var c: Vector2 = r[1]
		var s: Vector2 = r[2]
		rp.position = _to_map(c - s * 0.5) + Vector2(pad, pad)
		rp.size = s * MAP_SCALE
		rp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(rp)
		var rl := Label.new()
		rl.text = tr(String(r[0]))
		rl.add_theme_font_size_override("font_size", 10)
		rl.add_theme_color_override("font_color", Color(0.55, 0.7, 0.6, 0.8))
		rl.position = rp.position + Vector2(4, 2)
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(rl)

	# Camera buttons on the map. These must be focusable: a pad has no cursor, so
	# FOCUS_NONE left every feed but CAM 01 unreachable on a controller. TAB is
	# still safe — _input() runs before the viewport hands the event to the GUI,
	# and it marks the toggle as handled, so a focused button never sees it and
	# cannot swallow it for focus navigation.
	for i in range(CAMS.size()):
		var btn := Button.new()
		btn.text = "%02d" % (i + 1)
		btn.focus_mode = Control.FOCUS_ALL
		btn.add_theme_font_size_override("font_size", 12)
		btn.size = Vector2(34, 22)
		var wp: Vector3 = CAMS[i]["pos"]
		btn.position = _to_map(Vector2(wp.x, wp.z)) + Vector2(pad, pad) - btn.size * 0.5
		btn.pressed.connect(_switch_to.bind(i))
		panel.add_child(btn)
		_buttons.append(btn)

	_refresh_map_locks()


func _to_map(world: Vector2) -> Vector2:
	return (world + MAP_ORIGIN) * MAP_SCALE


## Repaint the mini-map's lock state. Called on every open, never baked: wings C
## and D are sealed by blast doors that GameManager tears down on nights 2 and 3,
## so a const flag made the map keep them red in rooms the player had already
## walked through.
func _refresh_map_locks() -> void:
	var night := _current_night()
	for i in range(_room_boxes.size()):
		var box := _room_boxes[i]
		var locked := night < int(ROOMS[i][3])
		box.bg_color = Color(0.9, 0.2, 0.15, 0.10) if locked \
			else Color(GREEN.r, GREEN.g, GREEN.b, 0.08)
		box.border_color = Color(0.7, 0.25, 0.2) if locked else GREEN.darkened(0.25)


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
			game.call("_flash", tr("CAM_ACCESS_OFFICE_ONLY"), Color(1.0, 0.62, 0.28))
		_sfx("fail")
		return
	_open = not _open
	_layer.visible = _open
	_sfx("tablet_open" if _open else "tablet_click")
	if _open:
		_player.controls_enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_map_locks()
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
	_static_alpha = 0.85
	_update_floodlight()
	for i in range(_buttons.size()):
		_buttons[i].modulate = Color(1.6, 1.6, 1.2) if i == index else Color(1, 1, 1)
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
	if _static_alpha > 0.0:
		_static_alpha = maxf(0.0, _static_alpha - delta * 4.0)
		_static_rect.color.a = _static_alpha * randf_range(0.6, 1.0)
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


func _sfx(sound: String) -> void:
	var am := get_tree().get_first_node_in_group("audio_manager")
	if am != null and am.has_method("play_sfx"):
		am.play_sfx(sound)
