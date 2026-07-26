class_name Cutscene
extends Node3D
## Sequenced camera player: a shot list in, a letterboxed cutscene out.
##
## Lifted wholesale out of FirstMuseumMap's inlined "MapIntro" section, which was
## the only sequenced camera machinery in the project — `create_tween()` appears
## once in the whole game (on a door), and AnimationPlayer / Path3D /
## RemoteTransform3D appear nowhere outside addons/. Rather than add a second
## private copy for the prologue, the working one became a node.
##
## Usage — connect first, start second, because a degenerate shot list finishes
## synchronously inside start():
##
##     var cut := Cutscene.new()
##     add_child(cut)
##     cut.finished.connect(_on_cutscene_done)
##     cut.start(shots)
##
## A shot is a Dictionary:
##     "from": Vector3  camera position at t=0
##     "to":   Vector3  camera position at t=1 (equal to "from" for a still)
##     "look": Vector3  world point the camera stays aimed at for the whole shot
##     "text": String   a catalogue KEY, not a sentence — see below
##     "time": float    seconds this shot holds, fades included
##     "card": bool     true = caption over a black title card instead of the world
##
## "text" carries the key and this node calls tr() every frame. The inlined
## version stored the *translated* string, baked once when the shot list was
## built; that is a frame-one snapshot of the language, and it also hid the keys
## from tools/check_localization.py inside a helper the scanner cannot follow.
## Keys survive a language switch mid-cutscene and stay greppable at the call
## site, which is where the catalogue check looks for them.

## Emitted exactly once, however the sequence ends. `skipped` is true when the
## player pressed the skip binding, false when the last shot simply ran out.
## Callers chain on this — the museum plays its prologue, then its intro.
signal finished(skipped: bool)

## Interface hint, not scene dialogue: LABEL / MUTED, bottom right.
const SKIP_HINT_KEY := "HUD_INTRO_SKIP"
const CAMERA_FOV := 66.0
## Letterbox bar height, as a fraction of the viewport.
const BAR_FRACTION := 0.12
## Cross-fade at each cut, as a fraction of the shot's own duration. Black at
## t=0, clear by t=FADE_IN, clear until t=1-FADE_OUT, black again at t=1. These
## are the numbers the museum intro shipped with: on a 4.5 s shot they cost
## ~1.0 s and leave ~3.5 s of steady text, which is why prose shots want 7-9 s.
const FADE_IN := 0.12
const FADE_OUT := 0.10
## Largest single step the sequence will advance by, in seconds.
##
## A shot is 4.5-8.0 s and _process() is handed the real frame delta, so one
## long hitch -- a resource load, a navmesh bake, a headless suite building the
## whole museum between two frames -- can charge a cutscene more than an entire
## shot at once and cut straight to the end. Measured: instantiating
## FirstMuseumMap.tscn headless produces a following delta big enough to consume
## the museum intro's full 13.5 s in a single frame. Clamping trades exact
## wall-clock length (a hitching machine plays the cutscene slightly slower) for
## the guarantee that no caption is skipped without the player skipping it.
const MAX_STEP := 0.25

var _shots: Array = []
var _length := 0.0
var _time := 0.0
var _active := false
var _done := false

var _camera: Camera3D = null
var _overlay: CanvasLayer = null
var _caption: Label = null
var _card: ColorRect = null
var _fade: ColorRect = null

# Restored verbatim on finish, so a cutscene is a loan and not a hand-over.
var _previous_camera: Camera3D = null
var _player: Node = null
var _player_controls_were: bool = true


func _init() -> void:
	# PROCESS_MODE_INHERIT, set explicitly so nobody "fixes" it to ALWAYS.
	#
	# The museum boots into a paused main menu and builds its cutscene during
	# _ready(), long before the player presses Start. ALWAYS would run the whole
	# sequence behind the menu and hand the player a cutscene that is already
	# over. INHERIT gives the behaviour the inlined intro had and the one the
	# scene wants: the node is constructed while paused, its camera is already
	# current and its fade rect is already fully black, and not one frame is
	# consumed until the tree unpauses. Pressing ESC mid-cutscene freezes it
	# under the pause menu and resuming picks it up mid-shot.
	#
	# process_mode governs _input as well as _process, so the skip binding is
	# deaf while paused too — which is correct: ESC belongs to the pause menu
	# there. A caller that genuinely wants a cutscene over a paused tree sets
	# `process_mode = Node.PROCESS_MODE_ALWAYS` after add_child() and gets both.
	process_mode = Node.PROCESS_MODE_INHERIT


## Take over the viewport and start playing `shots`.
##
## Safe to call with junk: an empty list, or one whose durations sum to zero,
## finishes immediately rather than dividing by it.
func start(shots: Array) -> void:
	if _active or _done:
		return
	_shots = shots
	_length = 0.0
	for entry in _shots:
		_length += maxf(0.0, float((entry as Dictionary).get("time", 0.0)))
	if _shots.is_empty() or _length <= 0.0:
		_finish(false)
		return

	_borrow_player()
	_build_camera()
	_build_overlay()
	_time = 0.0
	_active = true
	# Pose the first shot now. Waiting for the first _process() would leave the
	# borrowed camera pointing wherever it was constructed for a frame — and on a
	# paused boot that "frame" lasts until the player presses Start.
	_apply(0.0)


## True between start() and finished. Callers use it to suppress their own
## per-frame work while the scene owns the screen.
func is_playing() -> bool:
	return _active


## End the sequence early, as the skip binding does. No-op once finished.
func skip() -> void:
	if _active:
		_finish(true)


func _process(delta: float) -> void:
	if not _active or Engine.is_editor_hint():
		return
	_time += minf(delta, MAX_STEP)
	if _time >= _length or not is_instance_valid(_camera):
		_finish(false)
		return
	_apply(_time)


func _input(event: InputEvent) -> void:
	if not _active or Engine.is_editor_hint():
		return
	# Same three bindings the intro shipped with: SPACE / gamepad A, ENTER,
	# ESC / gamepad START. HUD_INTRO_SKIP is the hint that names them.
	if event.is_action_pressed("jump") or event.is_action_pressed("confirm") \
			or event.is_action_pressed("pause"):
		_finish(true)
		get_viewport().set_input_as_handled()


# --- Playback ---------------------------------------------------------------


## Pose camera, caption, card and fade for `elapsed` seconds into the sequence.
##
## The shots do not share one length — a title card holds longer than a camera
## move — so this walks the cumulative durations instead of dividing the total
## evenly. `into` ends up as the time inside the current shot.
func _apply(elapsed: float) -> void:
	var idx := _shots.size() - 1
	var into := elapsed
	for i in range(_shots.size()):
		var span := maxf(0.0, float((_shots[i] as Dictionary).get("time", 0.0)))
		if into < span:
			idx = i
			break
		into -= span
	var shot: Dictionary = _shots[idx]
	var length: float = maxf(0.001, float(shot.get("time", 0.0)))
	var t := clampf(into / length, 0.0, 1.0)
	# Smoothstep: every move eases out of its start and into its end, so a cut
	# never lands on a camera at full speed.
	var eased := t * t * (3.0 - 2.0 * t)

	if is_instance_valid(_camera):
		var from: Vector3 = shot.get("from", _camera.global_position)
		var to: Vector3 = shot.get("to", from)
		var look: Vector3 = shot.get("look", from + Vector3.FORWARD)
		_camera.global_position = from.lerp(to, eased)
		_aim(look)

	if is_instance_valid(_caption):
		var key := str(shot.get("text", ""))
		_caption.text = tr(key) if not key.is_empty() else ""
	if is_instance_valid(_card):
		_card.color.a = 1.0 if bool(shot.get("card", false)) else 0.0
	if is_instance_valid(_fade):
		_fade.color.a = _fade_alpha(t)


## Black at the cut, clear through the middle, black again before the next cut.
func _fade_alpha(t: float) -> float:
	if t < FADE_IN:
		return 1.0 - t / FADE_IN
	if t > 1.0 - FADE_OUT:
		return (t - (1.0 - FADE_OUT)) / FADE_OUT
	return 0.0


## look_at() with the two degenerate cases guarded, because a shot list is
## authored by hand and one typo would otherwise spam the log every frame:
## a target on top of the camera has no direction at all, and a target directly
## above or below it is parallel to the UP vector look_at() builds its basis from.
func _aim(target: Vector3) -> void:
	var to_target: Vector3 = target - _camera.global_position
	if Vector2(to_target.x, to_target.z).length() < 0.001:
		return
	_camera.look_at(target)


# --- Construction -----------------------------------------------------------


func _build_camera() -> void:
	# Whatever is on screen now comes back at the end — normally the player's
	# own camera, but asking the viewport rather than the player keeps this
	# honest if some other camera (a CCTV feed, a later cutscene) held the frame.
	_previous_camera = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.name = "Cutscene Camera"
	_camera.fov = CAMERA_FOV
	add_child(_camera)
	# Assigning current steals the frame; the outgoing camera clears itself.
	_camera.current = true


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "Cutscene Overlay"
	add_child(_overlay)

	var top_bar := ColorRect.new()
	top_bar.name = "Letterbox Top"
	top_bar.color = Color(0, 0, 0)
	top_bar.anchor_right = 1.0
	top_bar.anchor_bottom = BAR_FRACTION
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(top_bar)

	var bottom_bar := ColorRect.new()
	bottom_bar.name = "Letterbox Bottom"
	bottom_bar.color = Color(0, 0, 0)
	bottom_bar.anchor_top = 1.0 - BAR_FRACTION
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(bottom_bar)

	# Backdrop for title cards, so a card reads over black instead of over a
	# daylit forecourt. Added before the caption so the text draws on top of it,
	# while the fade rect stays last and still blacks out both at the cuts.
	_card = ColorRect.new()
	_card.name = "Title Card"
	_card.color = Color(0, 0, 0, 0)
	_card.anchor_right = 1.0
	_card.anchor_bottom = 1.0
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_card)

	_caption = Label.new()
	_caption.name = "Caption"
	# Inset from both edges and allowed to wrap. The intro's captions were three
	# or four words and fitted a single unwrapped line; prologue prose does not,
	# and an unwrapped Label clips it at the viewport edge. The band is deeper
	# than the intro's for the same reason: three wrapped lines have to fit
	# between the letterbox bars.
	_caption.anchor_left = 0.08
	_caption.anchor_right = 0.92
	_caption.anchor_top = 0.66
	_caption.anchor_bottom = 1.0 - BAR_FRACTION
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The largest text on screen at this moment and the thing the shot is built
	# around: TITLE, primary text colour.
	UITheme.apply_text(_caption, UITheme.TITLE, UITheme.ON_SURFACE)
	_overlay.add_child(_caption)

	var skip_hint := Label.new()
	skip_hint.name = "Skip Hint"
	skip_hint.text = tr(SKIP_HINT_KEY)
	skip_hint.anchor_right = 0.985
	skip_hint.anchor_top = 0.90
	skip_hint.anchor_bottom = 0.985
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A hint about the interface, not part of the scene: LABEL, and MUTED so it
	# stays legible without competing with the caption.
	UITheme.apply_text(skip_hint, UITheme.LABEL, UITheme.MUTED)
	_overlay.add_child(skip_hint)

	_fade = ColorRect.new()
	_fade.name = "Cut Fade"
	_fade.color = Color(0, 0, 0, 1)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_fade)


# --- Teardown ---------------------------------------------------------------


func _borrow_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	# Read the flag back rather than assuming true: a cutscene may be chained
	# behind another one, or fired while some other system already has the
	# player locked, and restoring a hard-coded true would hand control back to
	# somebody who did not ask for it.
	_player_controls_were = bool(_player.get("controls_enabled"))
	_player.set("controls_enabled", false)


func _finish(skipped: bool) -> void:
	if _done:
		return
	_done = true
	_active = false
	set_process(false)
	set_process_input(false)

	if is_instance_valid(_camera):
		_camera.current = false
		_camera.queue_free()
		_camera = null
	if is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
	if is_instance_valid(_previous_camera):
		_previous_camera.current = true
	if _player != null and is_instance_valid(_player):
		_player.set("controls_enabled", _player_controls_were)

	# Restore before emitting, so a listener that starts the next cutscene from
	# inside this signal borrows a viewport that is already back to normal.
	finished.emit(skipped)
	queue_free()
