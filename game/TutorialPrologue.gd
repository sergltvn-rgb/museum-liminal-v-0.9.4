extends Node3D
## Standalone interactive tutorial. A small, safe "orientation sector" that
## teaches every core control through real actions before the night shift.
##
## Each step is confirmed by the player actually performing the action, then
## fades out. Finishing writes tutorial/done and loads the museum; holding ESC
## bails out early and writes tutorial/skipped instead, so the two are never
## confused on disk. Reachable on first launch and from the main menu.

const PROGRESS_PATH := "user://museum_progress.cfg"
const MAIN_SCENE := "res://scenes/FirstMuseumMap.tscn"
# TUTORIAL_SKIP promises "Удерживайте ESC" / "Hold ESC", so require a real hold.
const SKIP_HOLD_TIME := 1.2
# How long TUTORIAL_COMPLETE stays up before the museum loads. Long enough to
# register as an acknowledgement of the seven steps, short enough that nobody
# reaches for a skip key that is deliberately not offered any more.
const COMPLETE_HOLD_TIME := 1.4

# Step ids drive both the checklist UI and the completion checks.
const STEP_MOVE := 0
const STEP_LOOK := 1
const STEP_SPRINT := 2
const STEP_JUMP := 3
const STEP_FLASHLIGHT := 4
const STEP_INTERACT := 5
const STEP_EXIT := 6

var _player: CharacterBody3D
var _camera: Camera3D
var _step := STEP_MOVE
var _layer: CanvasLayer
var _title: Label
var _checklist: Label
var _hint: Label
# Hold-to-skip state and its progress meter.
var _skip_track: ColorRect
var _skip_fill: ColorRect
var _skip_hold := 0.0
var _leaving := false

# Progress trackers for the current step.
var _move_distance := 0.0
var _last_pos := Vector3.ZERO
var _look_delta := 0.0
var _sprint_time := 0.0
var _did_jump := false
var _console_body: StaticBody3D
var _exit_pad: StaticBody3D
var _console_read := false


func _ready() -> void:
	_build_room()
	_spawn_player()
	_build_ui()
	_refresh_ui()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Room -------------------------------------------------------------------

func _build_room() -> void:
	var env_holder := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.19, 0.24)
	env.ambient_light_energy = 0.6
	env_holder.environment = env
	add_child(env_holder)

	_box("Floor", Vector3(0, -0.3, -4), Vector3(18, 0.6, 30), Color(0.08, 0.09, 0.12))
	_box("Wall North", Vector3(0, 2.5, -19), Vector3(18, 6, 0.6), Color(0.06, 0.07, 0.1))
	_box("Wall South", Vector3(0, 2.5, 11), Vector3(18, 6, 0.6), Color(0.06, 0.07, 0.1))
	_box("Wall West", Vector3(-9, 2.5, -4), Vector3(0.6, 6, 30), Color(0.06, 0.07, 0.1))
	_box("Wall East", Vector3(9, 2.5, -4), Vector3(0.6, 6, 30), Color(0.06, 0.07, 0.1))
	_box("Ceiling", Vector3(0, 5.5, -4), Vector3(18, 0.6, 30), Color(0.04, 0.05, 0.07))

	# A low ledge for the jump step.
	_box("Ledge", Vector3(0, 0.35, -6), Vector3(4, 0.7, 1.4), Color(0.12, 0.14, 0.2))

	# Ceiling lights so the flashlight step is meaningful once toggled off.
	for i in range(3):
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0, 5.0, 2.0 - 8.0 * float(i))
		lamp.light_color = Color(0.5, 0.62, 0.8)
		lamp.light_energy = 0.7
		lamp.omni_range = 12.0
		add_child(lamp)

	# Orientation console (interact target).
	_console_body = _target(Vector3(4.5, 1.0, -10), Color(0.3, 0.8, 1.0),
		"OrientationConsole", tr("TUT_TARGET_CONSOLE"))
	# Exit door pad (final step).
	_exit_pad = _target(Vector3(0, 1.0, -17), Color(0.3, 1.0, 0.45),
		"ExitPad", tr("TUT_TARGET_EXIT"))
	_exit_pad.visible = false


func _spawn_player() -> void:
	_player = CharacterBody3D.new()
	_player.name = "Player"
	_player.position = Vector3(0, 0.2, 6)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	collision.shape = shape
	collision.position = Vector3(0, 0.9, 0)
	_player.add_child(collision)

	_camera = Camera3D.new()
	_camera.name = "Player Camera"
	_camera.position = Vector3(0, 1.65, 0)
	_camera.fov = 72.0
	_camera.current = true
	_player.add_child(_camera)

	var flashlight := SpotLight3D.new()
	flashlight.name = "Player Flashlight"
	flashlight.position = Vector3(0.12, -0.10, -0.08)
	flashlight.light_energy = 2.4
	flashlight.spot_range = 20.0
	flashlight.spot_angle = 36.0
	_camera.add_child(flashlight)

	_player.script = load("res://game/PlayerController.gd")
	add_child(_player)
	_last_pos = _player.global_position


# --- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 40
	add_child(_layer)

	var panel := ColorRect.new()
	panel.color = Color(0.02, 0.03, 0.05, 0.9)
	panel.anchor_left = 0.62
	panel.anchor_top = 0.08
	panel.anchor_right = 0.98
	panel.anchor_bottom = 0.62
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	_title = Label.new()
	_title.text = tr("TUTORIAL_TITLE")
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.65, 0.82, 1.0))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)

	_checklist = Label.new()
	_checklist.add_theme_font_size_override("font_size", 16)
	_checklist.add_theme_color_override("font_color", Color(0.85, 0.9, 0.92))
	_checklist.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_checklist)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_hint)

	# Skip hint (bottom-center), so returning players are never trapped.
	var skip := Label.new()
	skip.text = tr("TUTORIAL_SKIP")
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip.anchor_left = 0.0
	skip.anchor_right = 1.0
	skip.anchor_top = 0.93
	skip.anchor_bottom = 0.98
	skip.add_theme_font_size_override("font_size", 14)
	skip.add_theme_color_override("font_color", Color(0.55, 0.6, 0.66))
	skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(skip)

	# Hold-progress meter under the caption. Purely graphical, so it adds no
	# localization key while the catalogue is still being rebuilt.
	# Anchors are set before add_child so the offsets stay at zero.
	_skip_track = ColorRect.new()
	_skip_track.color = Color(0.10, 0.12, 0.15, 0.85)
	_skip_track.anchor_left = 0.40
	_skip_track.anchor_right = 0.60
	_skip_track.anchor_top = 0.962
	_skip_track.anchor_bottom = 0.970
	_skip_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_track.visible = false
	_layer.add_child(_skip_track)

	_skip_fill = ColorRect.new()
	_skip_fill.color = Color(0.95, 0.82, 0.35, 0.95)
	_skip_fill.anchor_left = 0.0
	_skip_fill.anchor_top = 0.0
	_skip_fill.anchor_right = 0.0
	_skip_fill.anchor_bottom = 1.0
	_skip_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_track.add_child(_skip_fill)


func _step_rows() -> Array:
	return [
		{"id": STEP_MOVE, "key": "TUT_STEP_MOVE"},
		{"id": STEP_LOOK, "key": "TUT_STEP_LOOK"},
		{"id": STEP_SPRINT, "key": "TUT_STEP_SPRINT"},
		{"id": STEP_JUMP, "key": "TUT_STEP_JUMP"},
		{"id": STEP_FLASHLIGHT, "key": "TUT_STEP_FLASHLIGHT"},
		{"id": STEP_INTERACT, "key": "TUT_STEP_INTERACT"},
		{"id": STEP_EXIT, "key": "TUT_STEP_EXIT"},
	]


func _refresh_ui() -> void:
	var lines := PackedStringArray()
	for row in _step_rows():
		var id: int = int(row["id"])
		var mark := "[x]" if id < _step else ("[>]" if id == _step else "[ ]")
		lines.append("%s %s" % [mark, tr(String(row["key"]))])
	_checklist.text = "\n".join(lines)
	_hint.text = _current_hint()


func _current_hint() -> String:
	match _step:
		STEP_MOVE:
			return tr("TUT_HINT_MOVE")
		STEP_LOOK:
			return tr("TUT_HINT_LOOK")
		STEP_SPRINT:
			return tr("TUT_HINT_SPRINT")
		STEP_JUMP:
			return tr("TUT_HINT_JUMP")
		STEP_FLASHLIGHT:
			return tr("TUT_HINT_FLASHLIGHT")
		STEP_INTERACT:
			return tr("TUT_HINT_INTERACT")
		STEP_EXIT:
			return tr("TUT_HINT_EXIT")
	return ""


# --- Loop -------------------------------------------------------------------

func _process(delta: float) -> void:
	# Skip polling comes first: it must work even if the player node is gone,
	# and it must stop once the scene change is already requested.
	_update_skip(delta)
	if _leaving:
		return
	if _player == null or not is_instance_valid(_player):
		return
	match _step:
		STEP_MOVE:
			var moved := _player.global_position.distance_to(_last_pos)
			_last_pos = _player.global_position
			_move_distance += moved
			if _move_distance > 3.0:
				_advance()
		STEP_SPRINT:
			var horizontal := Vector2(_player.velocity.x, _player.velocity.z).length()
			if Input.is_action_pressed("sprint") and horizontal > 5.0:
				_sprint_time += delta
				if _sprint_time > 0.6:
					_advance()
		STEP_JUMP:
			if _did_jump:
				_advance()
		STEP_INTERACT:
			pass
		STEP_EXIT:
			pass


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _step == STEP_LOOK:
		_look_delta += (event as InputEventMouseMotion).relative.length()
		if _look_delta > 260.0:
			_advance()
	if event.is_action_pressed("jump") and _step == STEP_JUMP:
		_did_jump = true
	if event.is_action_pressed("flashlight") and _step == STEP_FLASHLIGHT:
		_advance()
	if event.is_action_pressed("interact"):
		_handle_interact()


func _handle_interact() -> void:
	if _step == STEP_INTERACT and _near(_console_body):
		_console_read = true
		_mark(_console_body)
		_sfx("terminal_beep")
		_advance()
	elif _step == STEP_EXIT and _near(_exit_pad):
		_finish()


func _near(body: Node3D) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	return _player.global_position.distance_to(body.global_position) < 2.8


func _advance() -> void:
	_step += 1
	_move_distance = 0.0
	_look_delta = 0.0
	_sprint_time = 0.0
	_did_jump = false
	_sfx("resolve")
	if _step == STEP_EXIT and _exit_pad != null:
		_exit_pad.visible = true
	_refresh_ui()


func _update_skip(delta: float) -> void:
	if _leaving:
		return
	if Input.is_action_pressed("pause"):
		_skip_hold += delta
		_update_skip_bar()
		if _skip_hold >= SKIP_HOLD_TIME:
			_skip()
		return
	if _skip_hold > 0.0:
		_skip_hold = 0.0
		_update_skip_bar()
		# PlayerController frees the cursor on "pause"; an aborted hold must not
		# leave the tutorial running with an uncaptured mouse.
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _update_skip_bar() -> void:
	if _skip_track == null or not is_instance_valid(_skip_track):
		return
	var ratio := clampf(_skip_hold / SKIP_HOLD_TIME, 0.0, 1.0)
	_skip_track.visible = ratio > 0.0
	# keep_offset must be false, otherwise the anchor change preserves the
	# current rect and the bar never grows.
	_skip_fill.set_anchor(SIDE_RIGHT, ratio, false)


func _finish() -> void:
	if _leaving:
		return
	_leaving = true
	_write_progress(true)
	# Acknowledge the seven steps instead of hard-cutting to the museum on the
	# same frame. _leaving is already true above, and both _process() and
	# _update_skip() return on it, so for the whole banner the step logic is
	# inert and a player still holding ESC cannot fall into _skip() and turn a
	# completed tutorial into a recorded skip.
	_show_completion_banner()
	await get_tree().create_timer(COMPLETE_HOLD_TIME).timeout
	# The tree can be gone under the await (quit, or an editor reload).
	if not is_inside_tree():
		return
	_leave()


func _show_completion_banner() -> void:
	if _layer == null or not is_instance_valid(_layer):
		return
	# Covers the checklist and the skip hint: with the tutorial over, both are
	# stale, and the last thing on screen should be the one line that matters.
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.03, 0.05, 0.88)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(veil)

	var done := Label.new()
	done.text = tr("TUTORIAL_COMPLETE")
	done.set_anchors_preset(Control.PRESET_FULL_RECT)
	done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	done.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	done.add_theme_font_size_override("font_size", 34)
	done.add_theme_color_override("font_color", Color(0.55, 1.0, 0.72))
	done.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(done)
	_sfx("resolve")


func _skip() -> void:
	if _leaving:
		return
	_leaving = true
	_write_progress(false)
	_leave()


func _leave() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_file(MAIN_SCENE)


func _write_progress(completed: bool) -> void:
	var config := ConfigFile.new()
	config.load(PROGRESS_PATH)
	if completed:
		config.set_value("tutorial", "done", true)
		config.set_value("tutorial", "skipped", false)
	else:
		# A skip is not a completion. "done" is deliberately left untouched: a
		# first-time skip leaves it false, and a replay that is skipped does not
		# downgrade an earlier honest completion.
		# CONTRACT: the menu gate must accept done-or-skipped as "may start the
		# shift" (MenuManager._tutorial_done), otherwise a skipping player is
		# sent back into the tutorial every time they press Start.
		config.set_value("tutorial", "skipped", true)
	config.save(PROGRESS_PATH)


func _sfx(sound: String) -> void:
	var am := get_tree().get_first_node_in_group("audio_manager")
	if am != null and am.has_method("play_sfx"):
		am.play_sfx(sound)


# --- Builders ---------------------------------------------------------------

func _box(box_name: String, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = pos
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	visual.material_override = mat
	body.add_child(visual)
	return body


func _target(pos: Vector3, color: Color, body_name: String, text: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = pos
	add_child(body)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.55
	shape.height = 1.5
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = 0.5
	mesh.top_radius = 0.38
	mesh.height = 1.5
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.5)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.7
	visual.material_override = mat
	body.add_child(visual)
	var label := Label3D.new()
	label.text = text
	label.position = Vector3(0, 1.25, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.pixel_size = 0.005
	label.outline_size = 5
	body.add_child(label)
	return body


func _mark(body: StaticBody3D) -> void:
	var visual := body.get_child(1) as MeshInstance3D
	if visual == null:
		return
	var mat := visual.material_override as StandardMaterial3D
	if mat != null:
		mat.emission = Color(0.4, 1.0, 0.7)
		mat.albedo_color = Color(0.08, 0.4, 0.23)
