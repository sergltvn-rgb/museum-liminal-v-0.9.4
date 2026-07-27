extends Node3D
## Standalone interactive tutorial. A small, safe "orientation sector" that
## teaches every core control through real actions before the night shift.
##
## Each step is confirmed by the player actually performing the action, then
## fades out. Finishing writes tutorial/done and loads the museum; holding ESC
## bails out early and writes tutorial/skipped instead, so the two are never
## confused on disk.
##
## OPTIONAL SINCE STAGE 8.6. The first-run teaching now happens inside the museum
## itself, over the daytime segment that ends at the security office door -- see
## the Orientation section of game/GameManager.gd, which reads and writes the
## same two flags this file does. Nothing sends the player here automatically any
## more; the main menu's Tutorial button is the only way in. It is kept rather
## than deleted because it is complete and working, because it is the only place
## the jump control is taught at all, and because a player who wants the controls
## with no museum around them can still ask for it. Finishing it writes
## tutorial/done, which also tells the museum's orientation to stand down:
## somebody who has just been walked through the controls does not need to be
## walked through them a second time.
##
## Two nodes joined scenes/TutorialPrologue.tscn at the same time, because they
## were what this scene could not do without. InputBootstrap: without it the
## scene only worked when it was entered from the museum, which had already
## registered the actions in the global InputMap; run on its own, every sprint /
## jump / flashlight poll asked about an action that did not exist.
## SettingsManager: without it the saved mouse sensitivity was never applied,
## because PlayerController pulls it from the "settings_manager" group in
## _ready() and this scene had nothing in that group to pull from.
##
##
## IT IS THE SAME TERMINAL AS THE REST OF THE GAME
##
## Stage 9.3. This scene used to be the last screen that looked like it came out
## of a different build: a free-floating translucent card of labels, and a
## success banner that was one centred word on a scrim. Both now render as the
## Night Containment Service's own device.
##
##   * The checklist readout wears the terminal's chrome -- masthead, rule,
##     opaque SURFACE plate with a hairline -- the same shapes TerminalFrame puts
##     on every full-screen page. Opaque, not translucent: it hangs over a 3D
##     room whose brightness this scene does not control, and a see-through plate
##     would make every contrast ratio in it depend on what was behind it.
##   * The completion screen IS a TerminalFrame, so the handover to the shift is
##     rendered by the machine the shift is run on. It carries no night and no
##     clock (both readouts blank rather than invent a number) and no core chip,
##     because the orientation sector contains none of those things.
##
##
## THE COMPASS IS TAUGHT HERE
##
## game/Compass.gd is the museum's wayfinding net, and the two steps that ask the
## player to walk to a specific object are the only place in the game where a
## bearing can be introduced with nothing else happening. NavigationDirector
## installs it and this file feeds it the step's own target, so the arrow appears
## exactly when there is somewhere to go and is gone the rest of the time.
##
## The ROOM READOUT and the FLOOR PLAN are switched OFF here, and that is not a
## simplification. The compass reads its room table out of
## SecurityCameraTablet.ROOMS, which describes the museum -- eleven rooms that
## are nowhere near this corridor. Left on, it would confidently name a room the
## player is not standing in and draw a plan of a building they have not entered
## yet, which is worse than saying nothing. The bearing needs no table: it is
## computed from two positions this scene owns.

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
# Owns the compass node: created here, fed the current step's target, switched
# off for the completion page. Null only if the director could not install.
var _nav: NavigationDirector = null


func _ready() -> void:
	_build_room()
	_spawn_player()
	_build_ui()
	_refresh_ui()
	_install_compass()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Bearing only -- see THE COMPASS IS TAUGHT HERE at the top of the file for why
## the other two readouts are off in this scene. Safe to call before the compass
## node itself exists: NavigationDirector records the request and applies it when
## it builds the node a frame later.
func _install_compass() -> void:
	_nav = NavigationDirector.install(self)
	if _nav == null:
		return
	_nav.set_features(false, true, false)
	_sync_compass()


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

	# The terminal's own plate: opaque SURFACE with a hairline, the same stylebox
	# shape TerminalFrame gives every chip on the shift terminal. It replaces a
	# translucent SURFACE_RAISED ColorRect, which had no border and whose contrast
	# depended on the lit 3D room behind it. Against opaque SURFACE the ratios are
	# fixed and computed: ON_SURFACE 17.28:1, MUTED 9.08:1, ACCENT 8.78:1,
	# WARNING 9.44:1, and the BORDER hairline 4.58:1 as a non-text token.
	var panel := PanelContainer.new()
	panel.name = "Orientation Readout"
	panel.add_theme_stylebox_override("panel", UITheme.stylebox(
		UITheme.SURFACE, UITheme.BORDER, UITheme.BORDER_WIDTH,
		UITheme.RADIUS_SM, UITheme.PAD_X + 6, UITheme.PAD_Y + 6))
	panel.anchor_left = 0.62
	panel.anchor_top = 0.08
	panel.anchor_right = 0.98
	panel.anchor_bottom = 0.62
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	# Masthead, exactly the row TerminalFrame prints at the top of every page and
	# in the same tokens, so the orientation readout is recognisably the same
	# device rather than a lookalike.
	var masthead := Label.new()
	masthead.name = "Institution"
	masthead.text = tr("HUD_PROTO_HEADER")
	masthead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	masthead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text(masthead, UITheme.CAPTION, UITheme.MUTED)
	box.add_child(masthead)

	_title = Label.new()
	_title.text = tr("TUTORIAL_TITLE")
	UITheme.apply_text(_title, UITheme.SECTION, UITheme.ACCENT)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_title)

	# The rule under the masthead. A ColorRect and not a draw callback because
	# this one never breaks: nothing in the orientation sector is corrupted, and
	# a static hairline is a shape that costs no frame time and cannot animate.
	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.color = UITheme.BORDER
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)

	_checklist = Label.new()
	UITheme.apply_text(_checklist, UITheme.BODY, UITheme.ON_SURFACE)
	_checklist.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_checklist)

	_hint = Label.new()
	UITheme.apply_text(_hint, UITheme.LABEL, UITheme.WARNING)
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
	UITheme.apply_text(skip, UITheme.LABEL, UITheme.MUTED)
	skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(skip)

	# Hold-progress meter under the caption. Purely graphical, so it adds no
	# localization key while the catalogue is still being rebuilt.
	# Anchors are set before add_child so the offsets stay at zero.
	_skip_track = ColorRect.new()
	# Opaque, for the same reason the readout plate above is: the fill inside it
	# is a progress reading, and a reading whose contrast depends on the wall
	# behind it is not a reading. WARNING on SURFACE is 9.44:1.
	_skip_track.color = UITheme.SURFACE
	_skip_track.anchor_left = 0.40
	_skip_track.anchor_right = 0.60
	_skip_track.anchor_top = 0.962
	_skip_track.anchor_bottom = 0.970
	_skip_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_track.visible = false
	_layer.add_child(_skip_track)

	_skip_fill = ColorRect.new()
	# Same amber as the hint text above: this bar is the "you are about to leave"
	# caution, and the two must not drift apart.
	_skip_fill.color = UITheme.WARNING
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
	_checklist.text = _checklist_text()
	_hint.text = _current_hint()


## The seven steps with their marks. `force_done` ticks every row, which is what
## the completion page shows -- the same list the player has been reading all
## along, finished, rather than a second wording of "you are finished".
##
## The mark is a shape, never a colour: [x] / [>] / [ ] survives a monochrome
## display and every colour-vision profile, and it is the only thing carrying
## progress in this list.
func _checklist_text(force_done := false) -> String:
	var lines := PackedStringArray()
	for row in _step_rows():
		var id: int = int(row["id"])
		var mark := "[x]" if force_done or id < _step else ("[>]" if id == _step else "[ ]")
		lines.append("%s %s" % [mark, tr(String(row["key"]))])
	return "\n".join(lines)


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
	_sync_compass()


## Feed the compass the objective this step actually has.
##
## Only the two steps that ask the player to reach a specific object get a
## bearing. Walking, looking, sprinting, jumping and the flashlight are performed
## on the spot, and an arrow pointing at nothing in particular during them would
## teach the player that the arrow means nothing in particular.
func _sync_compass() -> void:
	if _nav == null or not is_instance_valid(_nav):
		return
	match _step:
		STEP_INTERACT:
			_aim_compass(_console_body, "TUT_TARGET_CONSOLE")
		STEP_EXIT:
			_aim_compass(_exit_pad, "TUT_TARGET_EXIT")
		_:
			_nav.release_aim()


func _aim_compass(body: Node3D, room_key: String) -> void:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		_nav.release_aim()
		return
	_nav.aim_at(body.global_position, room_key)


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


## The handover to the shift, rendered by the device the shift is run on.
##
## A TerminalFrame rather than a scrim and a centred word: this is a full-screen
## surface, and every other full-screen surface in the game is one page of the
## same terminal. It covers the checklist plate and the skip hint outright --
## both are stale the moment the seventh step lands -- and it is opaque, so the
## contrast table in TerminalFrame.gd applies to it as written.
##
## No corruption is set. The orientation sector is on mains power with nothing
## loose in it, and a clean frame calls set_process(false) on itself, so this
## page cannot animate at all -- which is also exactly what it would do under
## reduced_flashes.
func _show_completion_banner() -> void:
	if _layer == null or not is_instance_valid(_layer):
		return
	# The bearing belongs to the room behind the page. Leaving it drawing under an
	# opaque full-screen frame is invisible but not free, and it would reappear
	# for a frame if anything ever dismissed the page instead of changing scene.
	if _nav != null and is_instance_valid(_nav):
		_nav.set_enabled(false)

	var frame := TerminalFrame.new()
	frame.name = "Orientation Handover"
	_layer.add_child(frame)
	frame.set_title("TUTORIAL_COMPLETE")
	# No shift is assigned in the orientation sector and there is no core in it,
	# so the night and clock readouts blank rather than print a number this scene
	# would have to invent, and "" hides the core chip instead of claiming a state
	# for a core that is not here.
	frame.set_status(-1, -1.0, "")

	var centre := CenterContainer.new()
	centre.name = "Summary"
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.body_column().add_child(centre)

	var done := Label.new()
	done.name = "Checklist"
	done.text = _checklist_text(true)
	done.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# SUCCESS on the frame's opaque SURFACE is 11.56:1 before the tube, and the
	# tube costs at most 11% of a channel at the centre of the page. The colour is
	# not carrying the meaning either way -- every row is ticked with [x].
	UITheme.apply_text(done, UITheme.BODY, UITheme.SUCCESS)
	centre.add_child(done)
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
