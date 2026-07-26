extends Node
## FNAF-style security tablet.
##
## TAB        -- open / close the camera feed
## CAM button -- switch camera (click on the mini-map)
## A/D or arrows -- pan the active camera, W/S or up/down -- tilt
## F          -- toggle the camera's IR floodlight
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

# Mini-map rooms: [name, world center (x,z), size (w,d), locked].
const ROOMS: Array = [
	["CAM_ENTRANCE", Vector2(0, 25), Vector2(22, 20), false],
	["CAM_ROOM_ATRIUM", Vector2(0, 0), Vector2(30, 30), false],
	["CAM_ROOM_OFFICE", Vector2(-25, 0), Vector2(20, 14), false],
	["CAM_ROOM_STORAGE", Vector2(-25, 12), Vector2(20, 10), false],
	["CAM_ROOM_ARCHIVE", Vector2(-25, -12), Vector2(20, 10), false],
	["CAM_ROOM_LAB", Vector2(-25, 22), Vector2(20, 10), false],
	["CAM_ROOM_WING_A", Vector2(28, 0), Vector2(26, 18), false],
	["CAM_ROOM_WING_B", Vector2(0, -24), Vector2(26, 18), false],
	["CAM_PLANETARIUM", Vector2(0, -41), Vector2(20, 16), false],
	["CAM_ROOM_WING_C", Vector2(24, -24), Vector2(22, 16), true],
	["CAM_ROOM_WING_D", Vector2(52, 0), Vector2(22, 16), true],
]

var _player: CharacterBody3D = null
var _cams: Array[Camera3D] = []
var _lights: Array[SpotLight3D] = []
var _base_rot: Array[Vector3] = []
var _buttons: Array[Button] = []
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

	# Room outlines.
	for r in ROOMS:
		var rp := Panel.new()
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color(0.9, 0.2, 0.15, 0.10) if r[3] \
			else Color(GREEN.r, GREEN.g, GREEN.b, 0.08)
		rsb.border_color = Color(0.7, 0.25, 0.2) if r[3] else GREEN.darkened(0.25)
		rsb.set_border_width_all(1)
		rp.add_theme_stylebox_override("panel", rsb)
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

	# Camera buttons on the map. FOCUS_NONE is critical: focused buttons
	# swallow TAB for focus navigation and the tablet could not be closed.
	for i in range(CAMS.size()):
		var btn := Button.new()
		btn.text = "%02d" % (i + 1)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 12)
		btn.size = Vector2(34, 22)
		var wp: Vector3 = CAMS[i]["pos"]
		btn.position = _to_map(Vector2(wp.x, wp.z)) + Vector2(pad, pad) - btn.size * 0.5
		btn.pressed.connect(_switch_to.bind(i))
		panel.add_child(btn)
		_buttons.append(btn)


func _to_map(world: Vector2) -> Vector2:
	return (world + MAP_ORIGIN) * MAP_SCALE


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
		_switch_to(_active)
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


func _switch_to(index: int) -> void:
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
	# Pan / tilt the active camera around its mounted orientation.
	var pan_dir := -Input.get_axis("camera_pan_left", "camera_pan_right")
	var tilt_dir := -Input.get_axis("camera_tilt_down", "camera_tilt_up")
	if pan_dir != 0.0 or tilt_dir != 0.0:
		_pan = clampf(_pan + pan_dir * PAN_SPEED * delta, -65.0, 65.0)
		_tilt = clampf(_tilt + tilt_dir * TILT_SPEED * delta, -18.0, 16.0)
		var base: Vector3 = _base_rot[_active]
		_cams[_active].rotation_degrees = Vector3(base.x + _tilt, base.y + _pan, 0.0)


func _sfx(sound: String) -> void:
	var am := get_tree().get_first_node_in_group("audio_manager")
	if am != null and am.has_method("play_sfx"):
		am.play_sfx(sound)
