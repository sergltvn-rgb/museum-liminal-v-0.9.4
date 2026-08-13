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
##     "bob":  float    optional subtle road/handheld camera motion in metres
##
## "text" carries the key and this node calls tr() every frame. The inlined
## version stored the *translated* string, baked once when the shot list was
## built; that is a frame-one snapshot of the language, and it also hid the keys
## from tools/check_localization.py inside a helper the scanner cannot follow.
## Keys survive a language switch mid-cutscene and stay greppable at the call
## site, which is where the catalogue check looks for them.
##
##
## WHY THERE IS NO TERMINAL FRAME HERE — THE ONE DELIBERATE EXEMPTION
##
## Every other full-screen surface in the game wears game/TerminalFrame.gd: the
## menu, settings, the protocol briefing, fail, night-done, the trial. This one
## does not, and the exemption is the decision, not an oversight — the reviewer
## who noticed the gap was right that it is a gap and wrong about the fix.
##
## TerminalFrame is a PAGE. It is masthead + live status cluster + a bordered
## body column + a key legend, all behind a CRT tube, and it carries a corruption
## model whose whole job is to eat the picture: murk washes, dropped bands,
## speckle, character rot. Three of those four properties are actively wrong for
## a cutscene:
##
##   1. THE BODY COLUMN IS THE PICTURE. A frame's body region is a Control that
##      wants children. This surface's "body" is the 3D viewport itself, drawn by
##      a Camera3D behind the whole CanvasLayer. There is nothing to put in the
##      column, so the frame would be an empty box drawn ON TOP of the shot,
##      inset from the edges the letterbox just established. Two competing
##      apertures, one inside the other.
##   2. THE STATUS CLUSTER WOULD LIE. Night number and shift clock are the
##      frame's two permanent readouts. The opening plays BEFORE night 1 starts,
##      on a paused tree with no shift running; the ending plays after the last
##      one has closed. Both would print a number that means nothing, and the
##      night-done page four minutes later would print the real one.
##   3. THE FRAME DEGRADES ON PURPOSE. Banding and character rot are the horror
##      hook and they are excellent — on a page the player is trying to READ
##      against a threat. A cutscene caption is on screen for ~3.5 seconds behind
##      a cross-fade that is already eating the first and last tenth of it. Rot
##      on top of that does not read as menace, it reads as a text bug.
##
## And the argument the reviewer made for wrapping it — a new player's first
## screen must not look like it came from a different game — is real, and it is
## answered without the box. The thing that made this surface foreign was never
## the absence of chrome; it was that the caption was set in whatever face the
## engine handed it, at stock Label leading, while every other surface had moved
## to the two-face voice in game/TerminalType.gd. So:
##
##   CAPTION ..... TerminalType.apply_heading() — Oswald, the institutional
##                 display face, at UITheme.TITLE. Same helper, same face, same
##                 tracking as TerminalFrame's own page title.
##   SKIP HINT ... apply_masthead() at LABEL/MUTED, institutional() case. The
##                 display face again: a key legend is stencilled, not spoken.
##   MASTHEAD .... HUD_PROTO_HEADER, the exact row TerminalFrame prints across
##                 its top, set with the exact same helper — laid INTO the top
##                 letterbox bar, where it costs the shot nothing.
##   RULES ....... a one-pixel hairline along the inner edge of each bar.
##
## That is the whole borrowing: the institution's letterforms and its name, in
## the black margin, over an untouched picture. The cutscene stays a camera move
## and still announces which building it belongs to.
##
## What is deliberately NOT borrowed, so a later pass does not "finish the job":
## no CRT overlay (the scanlines belong to a monitor the player is looking at,
## not to their own eyes), no scrim, no corruption, no key-legend bar, no border
## around the viewport.

## Emitted exactly once, however the sequence ends. `skipped` is true when the
## player pressed the skip binding, false when the last shot simply ran out.
## Callers chain on this — the museum plays its prologue, then its intro.
signal finished(skipped: bool)

## Interface hint, not scene dialogue: LABEL / MUTED, bottom right.
const SKIP_HINT_KEY := "HUD_INTRO_SKIP"
## The institution's own line, stencilled into the top letterbox bar. The same
## catalogue row TerminalFrame prints as its masthead; see WHY THERE IS NO
## TERMINAL FRAME HERE for why that one row is the whole borrowing.
const MASTHEAD_KEY := "HUD_PROTO_HEADER"

## The CanvasLayer this node's overlay is built on.
##
## WHY IT IS NOT 1. It was, by never being assigned at all — 1 is the engine
## default for a fresh CanvasLayer, and "the number you get when you do not
## choose one" is exactly the failure mode the decade ladder documented above
## game/GameManager.gd._build_hud() exists to end. That ladder's own entry for
## this file reads "001 Cutscene overlay (engine default)", which is a note
## saying nobody picked. Worse, 1 is not merely undeliberate, it is WRONG: the
## compass HUD is on 6 and the task block on 199, so both draw over a cutscene
## that is supposed to own the screen. The museum opening is the live case —
## GameManager builds the HUD in _ready() and the map starts the opening
## deferred from the same frame, so the moment the main menu closes the player
## watches the prologue with a compass and a task panel floating on the
## letterbox.
##
## WHY 410. The ladder's 400-499 band is "takeovers that end the incident", and
## a cutscene is a takeover by definition: it steals the Camera3D, freezes the
## player's controls and blacks the frame. 410 is the free rung at the bottom of
## that band.
##
## MUST SIT ABOVE the whole live shift — the compass (110), the task block
## (199), the CCTV tablet (200), the protocol screen (210) — and above the
## Curator proximity alert (320). The alert is the interesting one: it is the
## only thing in the 300s and it is designed to stab through the raisable
## screens, but a cutscene is not a screen the player raised, it is the game
## speaking, and an alert about a Curator who is not in the scene must not be
## the thing on top of it.
##
## MUST SIT BELOW the fail / win curtain (420), because that page is the one the
## player has to act on to leave, and its retry prompt cannot be covered; below
## the Curator catch screen (590), which is the veil that fades off to reveal
## 420 and so must beat everything under it; and below the pause menu (610), so
## ESC during a cutscene still reaches the menu rather than a black rectangle.
##
## The ending is the deliberate exception and it is raised BY ITS CALLER, not
## here: GameManager._play_ending() walks this node's children and moves the
## CanvasLayer to ENDING_LAYER = 430, one rung above the win curtain, because
## the ending's whole job is to replace that curtain rather than hide under it.
## That reassignment still works and is still needed — it is now a two-rung
## promotion inside one band instead of a jump from the engine default.
const OVERLAY_LAYER := 410

const CAMERA_FOV := 66.0
## Letterbox bar height, as a fraction of the viewport.
const BAR_FRACTION := 0.12
## Hairline along the inner edge of each letterbox bar, in pixels, and its alpha
## against UITheme.BORDER. Not a border — an aperture edge. Without it the bars
## are two black rectangles that could have come from any engine's default
## cutscene; with it the picture reads as something being looked AT through the
## service's equipment, which is the only structural claim this file makes.
const RULE_PX := 1.0
const RULE_ALPHA := 0.38
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
# Held, not fire-and-forget, for the same reason the caption is re-translated
# every frame: a language switch mid-cutscene must move all three strings, not
# only the one the shot list carries. _retranslate() is what does it.
var _masthead: Label = null
var _skip_hint: Label = null

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
	# The prologue bed: a one-shot with its own fade-out, started with the first
	# shot rather than the first caption so it is already speaking under the
	# opening black. Stopped in _finish() whether the scene runs out or skips.
	var am := get_tree().get_first_node_in_group("audio_manager")
	if am != null and am.has_method("play_context"):
		am.play_context("prologue")
	# Pose the first shot now. Waiting for the first _process() would leave the
	# borrowed camera pointing wherever it was constructed for a frame — and on a
	# paused boot that "frame" lasts until the player presses Start.
	_apply(0.0)


## True between start() and finished. Callers use it to suppress their own
## per-frame work while the scene owns the screen.
func is_playing() -> bool:
	return _active


## Seconds of sequence time consumed so far — the same clamped clock _apply()
## poses the camera from, NOT wall time (MAX_STEP slows it under hitches).
## Read-only, for callers that animate scenery in step with the shot list: the
## museum's driving cutscene moves the player's car along a track keyed to the
## same shot boundaries, and any other clock would drift away from the camera.
## This node still owns nothing but the camera; what a caller does with the
## number is the caller's scene.
func elapsed() -> float:
	return _time


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
		var camera_pos := from.lerp(to, eased)
		# Optional low-amplitude motion for a camera physically riding in a car
		# or held by an operator. It is keyed to sequence time, not frame delta,
		# so hitches cannot accumulate drift and the shot still ends exactly at
		# its authored endpoints once the next cut takes over.
		var bob := maxf(0.0, float(shot.get("bob", 0.0)))
		if bob > 0.0:
			camera_pos.y += sin(into * 7.4) * bob
			camera_pos.z += sin(into * 3.7 + 0.8) * bob * 0.35
		_camera.global_position = camera_pos
		_aim(look)

	if is_instance_valid(_caption):
		var key := str(shot.get("text", ""))
		_caption.text = tr(key) if not key.is_empty() else ""
	if is_instance_valid(_card):
		_card.color.a = 1.0 if bool(shot.get("card", false)) else 0.0
	if is_instance_valid(_fade):
		_fade.color.a = _fade_alpha(t)


## Re-read the two strings the shot list does not carry.
##
## The caption re-translates itself every frame out of `shot["text"]`, so it was
## already language-switch-proof; the masthead and the skip hint were set once at
## build time and would have been the two frozen English lines on a screen that
## had otherwise moved to Russian. Called once from _build_overlay() and again
## whenever the engine says the locale moved, which costs nothing between
## switches — Label.set_text() early-returns on an unchanged string.
##
## institutional() on both: these are stencilled institutional lines, not
## sentences, which is the case apply_masthead() is documented for. The catalogue
## keeps them in sentence case so a reviewer can tell intent from typo, and the
## uppercasing happens here, at the one place that draws them.
func _retranslate() -> void:
	if is_instance_valid(_masthead):
		_masthead.text = TerminalType.institutional(tr(MASTHEAD_KEY))
	if is_instance_valid(_skip_hint):
		_skip_hint.text = TerminalType.institutional(tr(SKIP_HINT_KEY))


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_retranslate()


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
	# Chosen, not inherited. See OVERLAY_LAYER for the whole above/below case;
	# GameManager._play_ending() overrides this to 430 for the ending only.
	_overlay.layer = OVERLAY_LAYER
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

	# THE CHROME GOES ABOVE THE TITLE CARD, not next to the bars it belongs to.
	# The card is a full-screen opaque black rect, so anything added before it is
	# covered whenever `"card": true` — and a masthead that blinks out for the
	# seven seconds of every title card and back in for the next camera move is
	# worse than no masthead. Above the card and below the fade is the one slot
	# where the frame furniture is constant for the whole sequence and still goes
	# black at the cuts with everything else.
	#
	# The aperture edges: anchored to the bars' inner edges, with their thickness
	# in offsets rather than anchor fractions, so the hairline stays one pixel at
	# every window height instead of growing with the viewport.
	_add_rule("Aperture Rule Top", BAR_FRACTION, 0.0, RULE_PX)
	_add_rule("Aperture Rule Bottom", 1.0 - BAR_FRACTION, -RULE_PX, 0.0)

	# The institution's name, laid into the top bar. This is the ONLY piece of
	# terminal chrome the cutscene wears and it costs the shot nothing: it sits
	# in black margin the letterbox had already taken, left-aligned against the
	# same 0.015 edge inset the skip hint uses on the other side, and it is the
	# same catalogue row and the same helper TerminalFrame draws across its top.
	_masthead = Label.new()
	_masthead.name = "Masthead"
	_masthead.anchor_left = 0.015
	_masthead.anchor_right = 0.7
	_masthead.anchor_bottom = BAR_FRACTION
	_masthead.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_masthead.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_masthead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# CAPTION 12 / MUTED: legible, and quiet enough that the eye reads it once at
	# the top of the sequence and then stops seeing it.
	TerminalType.apply_masthead(_masthead, UITheme.CAPTION, UITheme.MUTED)
	_overlay.add_child(_masthead)

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
	# around, so it takes the institutional voice: apply_heading() is the display
	# face (Oswald) at TITLE 28, the identical treatment TerminalFrame gives a
	# page title, where before this was UITheme.apply_text() alone — the theme's
	# mono at stock Label leading, i.e. the caption was set like body copy.
	#
	# THE SIZE DELIBERATELY DID NOT MOVE, though UITheme.DISPLAY 48 advertises
	# itself for "full-screen moments". The caption band is fixed at 0.66..0.88
	# of the viewport and prologue prose runs to three wrapped lines. Measured on
	# Oswald: a line box is 43 px at 28 and 72 px at 48, so three lines want
	# 129 px or 216 px, against a band of 158 px on a 720p window and 238 px on a
	# 1080p one. DISPLAY 48 clips the third line on exactly the machines least
	# able to spare it; TITLE 28 fits at both. Oswald is condensed, so the same
	# 28 already buys more characters per line than the mono it replaces.
	# (LEADING_TIGHT adds nothing here on purpose: 1.35 * 28 = 38 px is under
	# Oswald's own 43 px box, and leading_for() clamps the difference at zero.)
	TerminalType.apply_heading(_caption, UITheme.TITLE, UITheme.ON_SURFACE)
	_overlay.add_child(_caption)

	_skip_hint = Label.new()
	_skip_hint.name = "Skip Hint"
	_skip_hint.anchor_right = 0.985
	_skip_hint.anchor_top = 0.90
	_skip_hint.anchor_bottom = 0.985
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A hint about the interface, not part of the scene, and the display face
	# rather than the mono for exactly that reason: it is a key legend, and a key
	# legend on this machine is silkscreened onto the bezel, not printed by the
	# program. apply_masthead() is the Oswald + widest-tracking helper;
	# _retranslate() puts the text through institutional() to match.
	# LABEL 14 / MUTED: legible without competing with the caption above it.
	TerminalType.apply_masthead(_skip_hint, UITheme.LABEL, UITheme.MUTED)
	_overlay.add_child(_skip_hint)

	_fade = ColorRect.new()
	_fade.name = "Cut Fade"
	_fade.color = Color(0, 0, 0, 1)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_fade)

	_retranslate()


## One aperture hairline. `edge` is the viewport fraction the bar's inner edge
## sits at; `top_off` / `bottom_off` push the one-pixel band to the black side of
## it, so the rule is drawn ON the bar and never eats a row of the picture.
func _add_rule(rule_name: String, edge: float, top_off: float, bottom_off: float) -> void:
	var rule := ColorRect.new()
	rule.name = rule_name
	# UITheme.BORDER at RULE_ALPHA. The token, not a literal grey, so the rule
	# moves with the palette the rest of the game is drawn from.
	rule.color = Color(UITheme.BORDER, RULE_ALPHA)
	rule.anchor_right = 1.0
	rule.anchor_top = edge
	rule.anchor_bottom = edge
	rule.offset_top = top_off
	rule.offset_bottom = bottom_off
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(rule)


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
		# Dropped with the layer that owns them, so a late
		# NOTIFICATION_TRANSLATION_CHANGED between queue_free() and the frame
		# that actually deletes them cannot write into a dying Label.
		_masthead = null
		_skip_hint = null
		_caption = null
		_card = null
		_fade = null
	if is_instance_valid(_previous_camera):
		_previous_camera.current = true
	if _player != null and is_instance_valid(_player):
		_player.set("controls_enabled", _player_controls_were)

	# Hand the music back with the same timing as the visuals: out by the last
	# frame, not fading over whatever the caller opens next. If that caller is
	# another cutscene its own play_context() crossfades with this one anyway.
	var am := get_tree().get_first_node_in_group("audio_manager")
	if am != null and am.has_method("stop_context"):
		am.stop_context()

	# Restore before emitting, so a listener that starts the next cutscene from
	# inside this signal borrows a viewport that is already back to normal.
	finished.emit(skipped)
	queue_free()
