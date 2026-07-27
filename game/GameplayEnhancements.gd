extends Node
## Distinct anomaly mechanics, camera-confirmation objectives and an active
## "Watcher" threat. Kept separate from GameManager so the core night loop
## remains easy to test and maintain.
##
##
## WHAT THIS FILE DRAWS, AND WHERE IT NOW DRAWS IT
##
## Two of the three surfaces here used to be labels of its own invention, and
## both were on TaskBlock's list of the seven controls that made "what do I do
## now" unanswerable. They are shared components now:
##
##   anomaly effect readout -> TaskBlock slots 3 and 4. It was a right-aligned
##       three-line run drawn straight onto the 3D museum, wearing a 5 px glyph
##       outline because its backdrop was whatever the player happened to be
##       looking at -- an unmeasurable contrast ratio and a third voice on a
##       screen that already had too many. See _update_readouts().
##   the catch sequence -> a TerminalFrame in its signal-lost state. The veil was
##       a bare ColorRect fading to SURFACE; it is the operator's own terminal
##       losing the feed now, which is the same instrument the rest of the game
##       wears and says what happened rather than merely hiding it. See
##       _build_death_screen().
##
## The Curator proximity band below is deliberately NOT moved. It is a
## screen-edge frame sized for peripheral vision while the eye is on a camera
## feed in the middle of the screen, and TaskBlock is a corner panel the tablet
## is allowed to cover; routing one through the other would delete the only
## channel that pays back the perception the tablet takes away.

const STATE_ANOMALY := 2
## GameManager.STATE_FAILED. Read, never written: this node asks whether the run
## has already ended so the catch sequence does not fail it a second time.
const STATE_FAILED := 4
const SCAN_TIME := 2.5
const EFFECT_RADIUS := 15.0

# --- Curator proximity alert (stage 7.8) ------------------------------------
#
# Raising the CCTV tablet parks the operator: PlayerController.controls_enabled
# goes false, the viewport camera moves to a wall mount, and from night 2 the
# incident cannot be resolved until the operator has held a specific feed for
# SCAN_TIME seconds. The Curator kept hunting through all of that, so the
# mandatory scan was performed blind, deaf and immobile and the run could end
# with the office door opening behind a screen the player was legally required
# to be looking at.
#
# The fix is NOT to pause the Curator. The tablet is the one place the operator
# is helpless, and that is the whole reason the tablet is frightening; make it a
# safe room and the scan stops being a decision, the night stops having a cost,
# and there is never a reason to put the tablet down again. What was actually
# missing was information, not mercy: the player had no channel through which to
# learn they were being approached, so a death was noise rather than a lesson.
#
# So the workstation gets a motion readout that only exists while the tablet is
# up -- it pays back exactly the perception the tablet takes away and not one
# metre more, and it vanishes the instant the feed is lowered. It reports range
# AND bearing, because bearing is what makes it actionable: the Curator freezes
# while it is looked at, so "12 m, behind you" tells the operator precisely
# where to turn once they drop the tablet. Holding the scan for two more seconds
# then becomes a bet the player understands and chooses to take.
## Range at which the office motion sensor starts reporting the Curator.
const WATCH_ALERT_RANGE := 24.0
## Range at which the readout escalates: from here it is too late to finish a
## scan, and the frame and the sting say so.
const WATCH_CRITICAL_RANGE := 7.5
## Seconds between pings at WATCH_ALERT_RANGE and at WATCH_CRITICAL_RANGE.
const WATCH_PING_SLOW := 1.35
const WATCH_PING_FAST := 0.22
## Hysteresis on the escalation, so a Curator loitering on the boundary does not
## re-trigger the one-shot sting every other frame.
const WATCH_CRITICAL_RELEASE := 1.4
## Screen-edge alert frame. UITheme has no token for this: BORDER_WIDTH (1) and
## FOCUS_WIDTH (2) size hairlines around a control the player is already looking
## at, and this band has to register in peripheral vision while the eye is on a
## camera feed in the middle of the screen.
const WATCH_FRAME_WIDTH := 6
## Half-angle of the "ahead" and "behind" sectors, as a dot product: cos(45 deg).
const WATCH_SECTOR_DOT := 0.7071
## CanvasLayer for that alert.
##
## 300-399 is the "in-world alarms drawn over the screens the player raises"
## band of the decade scale written out in game/TaskBlock.gd and tabulated in
## full above GameManager._build_hud(). The old 12 collided head-on with
## GameManager's protocol screen, also 12: which of the two drew on top was
## decided by construction order in two unrelated files, i.e. by nobody.
##
## MUST SIT ABOVE:
##   199 TaskBlock ................. the alert is a full-screen border; the block
##                                   is a corner panel and keeps its corner.
##   200 CCTV tablet ............... THE ENTIRE POINT. The alert exists so that
##                                   raising the tablet is a bet the player can
##                                   see the odds on -- it has to be legible
##                                   while the tablet owns the screen.
##   210 protocol screen ........... the Curator does not wait for the briefing.
## MUST SIT BELOW:
##   420 fail / win ................ a run that has ended is not still hunted.
##   590 the catch screen .......... _begin_death() calls _hide_watch_alert()
##                                   anyway; z-order agrees with it rather than
##                                   contradicting it.
##   610 MenuManager ............... a paused game is not being hunted either.
const WATCH_ALERT_LAYER := 320

# --- Being caught (stage 4.4) -----------------------------------------------
#
# The catch used to last one frame. _on_watcher_caught() called GameManager's
# _fail() straight away, the scrim landed over whatever the operator's head
# happened to be pointing at, and the very next _process() saw the state leave
# STATE_ANOMALY and ran _end_anomaly(), which hides the Curator. So the thing
# that killed you was gone before the screen finished turning red, the player
# still had the mouse, and the whole event read as a bug rather than an ending.
#
# _update_death() below is the shot instead. It owns the frame for its whole
# length -- _process() short-circuits into it -- which is what guarantees nothing
# tears the Curator down mid-take, including GameManager failing the run itself
# when the night timer happens to expire during it.
#
# HAND-OFF, EXACTLY. At t = 0 this calls GameManager._flash(HUD_CURATOR_CAUGHT),
# whose message lives 3.0 s and so is legible across the turn and the hold. At
# t = 1.55 s, with the veil fully opaque, it calls this node's own _end_anomaly()
# and then GameManager._fail() -- the same two calls the one-frame version made
# and in the same order, 1.55 s later and behind a black screen. GameManager
# still owns the fail overlay, the "fail" sting and the ENTER-to-retry path;
# none of that is touched or duplicated here.
const DEATH_TURN := 0.55     ## Swing the view onto the Curator.
const DEATH_HOLD := 0.45     ## Hold on it. This is the shot.
const DEATH_FADE := 0.55     ## Picture out.
const DEATH_RELEASE := 0.45  ## Veil back off, onto GameManager's fail screen.
## Height of the Curator's lens above its feet: CuratorMonster._build_model()
## mounts "Camera Head" at y = 2.12. The view is aimed there rather than at the
## body centre -- the thing that caught you is a camera on a neck, and framing it
## is the difference between a death and a collision.
const DEATH_FOCUS_Y := 2.12
## CanvasLayer for the catch screen -- the highest layer the shipping game draws
## apart from the pause menu.
##
## 590-599 is the top of the "trial / pocket-dimension" decade on the scale
## written out in game/TaskBlock.gd and tabulated in full above
## GameManager._build_hud(). The catch is a takeover (400-499 by band), but it is
## the ONE takeover that has to cover the trial HUD as well, so it is carved out
## of the rung directly beneath the menus instead. GameManager's own migration
## note used to prescribe 410 for this layer; 410 is wrong and this is why.
##
## MUST SIT ABOVE:
##   199 TaskBlock ................. the veil at 13 did not cover it, so the
##                                   block kept reporting the anomaly over a
##                                   black screen.
##   200 CCTV tablet ............... _begin_death() lowers the tablet anyway, but
##                                   the frame it is lowered on must not show it.
##   320 the proximity alert below . the thing it was warning about has happened.
##   420 GameManager's fail / win .. LOAD-BEARING. _update_death() fades this
##                                   screen back OFF to uncover the fail page:
##                                   at 19, under 420, the fail page popped on
##                                   top instead of being revealed, which is the
##                                   hand-off in this file's header failing
##                                   silently.
##   510 the trial terminal frame .. the catch is the only surface that outranks
##                                   an open pocket dimension.
## MUST SIT BELOW:
##   610 MenuManager ............... ESC during the catch still reaches the pause
##                                   menu; a black veil over a menu is a hang.
const DEATH_LAYER := 590
## Group the single TaskBlock is published under. See _resolve_task_block().
const TASK_BLOCK_GROUP := "task_block"
## Layer a TaskBlock built by THIS file is parked at. GameManager owns the real
## one and puts it at its own HUD_TASK_LAYER; _resolve_task_block() only ever
## constructs a block when no shift HUD exists at all (headless suites, or an
## _initialize() that bailed out). Kept equal to GameManager.HUD_TASK_LAYER so
## the fallback lands on the same rung rather than on TaskBlock's own legacy
## TASK_LAYER = 17, which is below every screen DEATH_LAYER lists.
const HUD_TASK_LAYER := 199

## Perceived-size window each local anomaly drives the operator through, as
## Vector2(min, max). _update_player_scale() only interpolates between these two
## bounds, so this table is the single source of truth for how big the player
## can get; test_incident_catalog.gd reads it to prove every curve still crosses
## the "small" and "large" calibration thresholds. The test used to carry its own
## copy of these numbers and could therefore never notice a change here.
## Anomalies absent from this table do not touch the player's size at all.
const ANOMALY_SCALE_SPAN := {
	"gravity_surge": Vector2(0.72, 1.30),
	"temporal_drift": Vector2(0.78, 1.28),
	"radiation_bloom": Vector2(0.74, 1.30),
	"void_rift": Vector2(0.72, 1.30),
}

var _game: Node
var _map: Node3D
var _player: CharacterBody3D
var _tablet: Node
var _flashlight: SpotLight3D
var _active := false
var _anomaly := ""
var _night := 1
var _phase := 0.0
var _exposure := 0.0
var _scan_progress := 0.0
var _scan_complete := false
var _required_camera := -1
var _base_gravity := 18.0
var _base_walk := 4.5
var _base_run := 7.5
var _base_flash_energy := 2.4
var _block: TaskBlock
## True while THIS node holds TaskBlock slot 4 under TaskBlock.OWNER_ANOMALY, so
## the lease is taken once and given back exactly once. It is the local mirror of
## `_block.slot_owner(Slot.STATUS) == OWNER_ANOMALY`, kept because the block can be
## torn down or replaced under us and the release must not then fire blind.
var _readouts_owned := false
var _watcher: CuratorMonster
var _scale_controller: Node
var _player_camera: Camera3D
var _watch_layer: CanvasLayer
var _watch_frame: Panel
var _watch_label: Label
var _watch_style_near: StyleBoxFlat
var _watch_style_critical: StyleBoxFlat
var _watch_ping := 0.0
var _watch_critical := false
var _watch_pulse := 0.0
var _incident_origin := Vector3.ZERO
var _incident_name := ""
var _rift_visual: Node3D
## Seconds into the catch sequence, or -1.0 while it is not running.
var _death_time := -1.0
var _death_layer: CanvasLayer
var _death_screen: TerminalFrame
var _death_from_yaw := 0.0
var _death_from_pitch := 0.0
var _death_handed_off := false
var _chalk_marks: Array[MeshInstance3D] = []
var _chalk_index := 0
var _last_chalk_position := Vector3.ZERO


func _ready() -> void:
	add_to_group("gameplay_enhancements")
	add_to_group("resolution_gate")
	call_deferred("_initialize")


func _initialize() -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	_game = get_parent().get_node_or_null("GameManager")
	_tablet = get_parent().get_node_or_null("SecurityCameraTablet")
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_scale_controller = get_tree().get_first_node_in_group("player_scale_controller")
	var museum := get_tree().get_first_node_in_group("museum_map")
	if museum != null:
		_map = museum.get_node_or_null("GeneratedMap") as Node3D
	if _player != null:
		_player_camera = _player.get_node_or_null("Player Camera") as Camera3D
		_flashlight = _player.get_node_or_null("Player Camera/Player Flashlight") as SpotLight3D
		_base_gravity = float(_player.get("gravity"))
		_base_walk = float(_player.get("walk_speed"))
		_base_run = float(_player.get("run_speed"))
	if _flashlight != null:
		_base_flash_energy = _flashlight.light_energy
	_build_hud()
	_build_watcher()


func _carried_tool() -> String:
	if _game == null: return ""
	return str(_game.get("_carried_id"))


func _process(delta: float) -> void:
	if _game == null or _player == null:
		return
	if _death_time >= 0.0:
		# The catch owns the frame. Falling through to the state check below would
		# let _end_anomaly() hide the Curator the moment GameManager leaves
		# STATE_ANOMALY, which is the exact bug the sequence exists to fix.
		_update_death(delta)
		return
	if _carried_tool() == "thermal_chalk":
		_update_chalk()
	var state := int(_game.get("_state"))
	var current := str(_game.get("_anomaly_id"))
	if state == STATE_ANOMALY and current != "":
		if not _active or current != _anomaly:
			_begin_anomaly(current)
		_update_anomaly(delta)
	else:
		if _active:
			_end_anomaly()


func _begin_anomaly(id: String) -> void:
	_end_anomaly()
	_active = true
	_anomaly = id
	_night = int(_game.get("_night"))
	_phase = 0.0
	_exposure = 0.0
	_scan_progress = 0.0
	_scan_complete = _night <= 1
	var puzzle := get_tree().get_first_node_in_group("exhibit_puzzle_controller")
	if puzzle != null:
		if puzzle.has_method("get_incident_origin"):
			_incident_origin = puzzle.get_incident_origin()
		if puzzle.has_method("get_incident_name"):
			_incident_name = puzzle.get_incident_name()
		if puzzle.has_method("get_required_camera"):
			_required_camera = puzzle.get_required_camera() if _night >= 2 else -1
	_resolve_task_block()
	_build_rift_visual()
	if _watcher != null:
		_watcher.visible = _night >= 2
		# Night 2 seeds the Curator in Space Wing C, night 3 in Mass Wing D —
		# both are unlocked by the time it spawns there.
		_watcher.reset_at(Vector3(24, 0.0, -27) if _night == 2 else Vector3(53, 0.0, -5))
	if not _scan_complete:
		var cam_name := "CAM %02d" % (_required_camera + 1)
		_game.set_objective("cctv", Loc.fmt("OBJ_CCTV_CONFIRM", [_incident_name, cam_name, SCAN_TIME]), 40)
	_update_readouts()


func _end_anomaly() -> void:
	if _game != null and _game.has_method("clear_objective"): _game.clear_objective("cctv")
	_active = false
	_anomaly = ""
	_scan_progress = 0.0
	_restore_player()
	_update_readouts()
	_hide_watch_alert()
	if _watcher != null:
		_watcher.visible = false
		_watcher.active = false
	if is_instance_valid(_rift_visual):
		_rift_visual.queue_free()
	_rift_visual = null


func _update_anomaly(delta: float) -> void:
	_phase += delta
	_animate_rift(delta)
	_update_scan(delta)
	match _anomaly:
		"gravity_surge":
			_update_gravity()
		"temporal_drift":
			_update_temporal()
		"radiation_bloom":
			_update_radiation(delta)
		"void_rift":
			_update_void()
	_update_player_scale()
	_sync_watcher()
	_update_watch_alert(delta)
	_update_readouts()


func _update_chalk() -> void:
	# Термомел: светящаяся дорожка из 40 меток (кольцевой буфер) за игроком.
	if _map == null: return
	if _chalk_marks.is_empty():
		for i in range(40):
			var mark := MeshInstance3D.new()
			var dot := SphereMesh.new(); dot.radius = .05; dot.height = .1
			var mat := StandardMaterial3D.new(); mat.albedo_color = Color(1,.45,.15)
			mat.emission_enabled = true; mat.emission = Color(1,.4,.1); mat.emission_energy_multiplier = 1.6
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; dot.material = mat
			mark.mesh = dot; mark.position = Vector3(0,-999,0); _map.add_child(mark); _chalk_marks.append(mark)
	if _player.global_position.distance_to(_last_chalk_position) >= 1.3:
		_last_chalk_position = _player.global_position
		var mark := _chalk_marks[_chalk_index]; _chalk_index = (_chalk_index+1) % _chalk_marks.size()
		mark.position = _player.global_position + Vector3(0,.06,0)


func _update_gravity() -> void:
	# Gravity rises and falls in readable waves; jumps and loose vertical
	# movement feel materially different from the normal museum.
	if _carried_tool() == "mass_clamp":
		# Зажим массы стабилизирует личную гравитацию оператора.
		_player.set("gravity", _base_gravity)
		_player.set("jump_velocity", 6.0)
		return
	var strength := _local_strength()
	var wave := 0.55 + 0.45 * sin(_phase * 1.7)
	_player.set("gravity", lerpf(_base_gravity, lerpf(_base_gravity * 0.20, _base_gravity * 1.75, wave), strength))
	_player.set("jump_velocity", lerpf(6.0, lerpf(8.5, 4.2, wave), strength))


func _update_temporal() -> void:
	# Alternating slow and fast time affects locomotion without changing the
	# global Engine.time_scale (menus and the countdown remain reliable).
	var factor := lerpf(1.0, 0.72 + 0.38 * sin(_phase * 1.35), _local_strength())
	_player.set("walk_speed", _base_walk * factor)
	_player.set("run_speed", _base_run * factor)


func _update_radiation(delta: float) -> void:
	var distance := _player.global_position.distance_to(_incident_origin)
	var gain := remap(clampf(distance, 2.0, EFFECT_RADIUS), 2.0, EFFECT_RADIUS, 15.0, 1.0)
	if _carried_tool() == "resonance_tuner":
		# Резонансный настройщик гасит набор дозы вдвое.
		gain *= 0.5
	if distance < EFFECT_RADIUS:
		_exposure = minf(100.0, _exposure + gain * delta)
	else:
		_exposure = maxf(0.0, _exposure - 8.0 * delta)
	if _exposure >= 100.0:
		_game.call("_flash", tr("HUD_CRITICAL_DOSE"), Color(1.0, 0.25, 0.15))
		_game.call("_fail")


func _update_void() -> void:
	if _flashlight == null:
		return
	var user_enabled := bool(_player.get("flashlight_enabled"))
	if _local_strength() <= 0.01:
		_flashlight.visible = user_enabled
		_flashlight.light_energy = _base_flash_energy
		return
	var settings := get_tree().get_first_node_in_group("settings_manager")
	if settings != null and settings.reduced_flashes:
		_flashlight.visible = user_enabled
		_flashlight.light_energy = _base_flash_energy * (0.58 + 0.12 * sin(_phase * 3.0))
		return
	var pulse := sin(_phase * 8.0) + sin(_phase * 19.0) * 0.45
	_flashlight.light_energy = _base_flash_energy * (0.12 if pulse < -0.65 else 0.8)
	_flashlight.visible = user_enabled and fmod(_phase, 3.7) > 0.22


func _update_scan(delta: float) -> void:
	if _scan_complete or _required_camera < 0 or _tablet == null:
		return
	var open := bool(_tablet.get("_open"))
	var active_camera := int(_tablet.get("_active"))
	if open and active_camera == _required_camera:
		_scan_progress += delta
		if _scan_progress >= SCAN_TIME:
			_scan_complete = true
			_game.call("_flash", tr("HUD_SOURCE_CONFIRMED"), Color(0.45, 1.0, 0.65))
			_game.clear_objective("cctv")
	else:
		_scan_progress = maxf(0.0, _scan_progress - delta * 0.5)


func can_resolve() -> bool:
	if _scan_complete:
		return true
	var remaining := maxf(0.0, SCAN_TIME - _scan_progress)
	var cam_name := "CAM %02d" % (_required_camera + 1)
	_game.call("_flash", Loc.fmt("HUD_CONFIRM_SOURCE_FIRST", [cam_name, remaining]), Color(1.0, 0.65, 0.3))
	return false


## Push per-frame state onto the Curator. The chase itself runs in the
## Curator's own _physics_process — driving move_and_slide() from here made
## its speed scale with the render framerate.
func _sync_watcher() -> void:
	if not is_instance_valid(_watcher):
		return
	_watcher.night = _night
	_watcher.slowed = _carried_tool() == "null_lantern"
	# The museum is frozen while the operator is inside a pocket dimension.
	#
	# Stage 7.8: deliberately NOT also frozen while the CCTV tablet is open. See
	# the WATCH_* block at the top of this file -- the tablet stays dangerous and
	# _update_watch_alert() pays the player back in information instead. The
	# weeping-angel rule agrees: CuratorMonster._is_observed() is false while the
	# player's camera is not the one rendering, so the tablet never buys a freeze
	# the operator could not have reasoned about.
	_watcher.active = _watcher.visible and not bool(_game.get("_trial_active"))


## Range and bearing to the Curator, or -1.0 when there is nothing to report.
## Everything the alert needs to decide it should stay silent lives here.
func _watch_distance() -> float:
	if _tablet == null or not bool(_tablet.get("_open")):
		# Eyes on the room: the operator can see for themselves, and a readout
		# here would be a wallhack rather than compensation for being blinded.
		return -1.0
	if not is_instance_valid(_watcher) or not _watcher.active or _player == null:
		return -1.0
	var distance := _player.global_position.distance_to(_watcher.global_position)
	return distance if distance <= WATCH_ALERT_RANGE else -1.0


func _update_watch_alert(delta: float) -> void:
	if _watch_layer == null:
		return
	var distance := _watch_distance()
	if distance < 0.0:
		_hide_watch_alert()
		return

	# 0 at the edge of sensor range, 1 once the Curator is inside the office.
	var closeness := 1.0 - clampf(
		(distance - WATCH_CRITICAL_RANGE) / (WATCH_ALERT_RANGE - WATCH_CRITICAL_RANGE), 0.0, 1.0)
	_set_watch_critical(distance)

	if not _watch_layer.visible:
		_watch_layer.visible = true
		# Ping immediately on the first frame of contact: a warning that waits up
		# to 1.35 s to make its first sound is not a warning.
		_watch_ping = 0.0
		_watch_pulse = 0.0

	_watch_ping -= delta
	if _watch_ping <= 0.0:
		_watch_ping = lerpf(WATCH_PING_SLOW, WATCH_PING_FAST, closeness)
		# terminal_beep, not a scream: this is the workstation's own motion
		# channel, and it has to stay separable from the trial and pickup beeps
		# by rate and pitch rather than by being louder than everything else.
		_sfx("terminal_beep", lerpf(-17.0, -4.0, closeness), lerpf(0.62, 1.32, closeness))

	# The band breathes rather than strobes, and holds steady for players who
	# have asked for reduced flashing.
	_watch_pulse += delta * lerpf(2.2, 7.0, closeness)
	var settings := get_tree().get_first_node_in_group("settings_manager")
	var steady: bool = settings != null and bool(settings.get("reduced_flashes"))
	_watch_frame.modulate.a = 1.0 if steady else 0.55 + 0.45 * (0.5 + 0.5 * sin(_watch_pulse))

	var bearing := tr(_watch_bearing_key())
	var text := Loc.fmt("HUD_WATCH_MOTION", [maxi(1, int(round(distance))), bearing])
	if _watch_critical:
		text += "\n" + tr("HUD_WATCH_CRITICAL")
	_watch_label.text = text


## Escalate once and only once per approach, with hysteresis on the way out.
func _set_watch_critical(distance: float) -> void:
	if _watch_critical:
		if distance > WATCH_CRITICAL_RANGE * WATCH_CRITICAL_RELEASE:
			_watch_critical = false
			_watch_frame.add_theme_stylebox_override("panel", _watch_style_near)
			UITheme.apply_text(_watch_label, UITheme.SECTION, UITheme.WARNING)
		return
	if distance > WATCH_CRITICAL_RANGE:
		return
	_watch_critical = true
	_watch_frame.add_theme_stylebox_override("panel", _watch_style_critical)
	UITheme.apply_text(_watch_label, UITheme.SECTION, UITheme.DANGER)
	# One heavy sting at the boundary. The ping tells the operator something is
	# coming; this tells them the decision is now.
	_sfx("blackout", -5.0, 0.85)


func _hide_watch_alert() -> void:
	if _watch_layer == null or not _watch_layer.visible:
		return
	_watch_layer.visible = false
	_watch_ping = 0.0
	if _watch_critical:
		_watch_critical = false
		_watch_frame.add_theme_stylebox_override("panel", _watch_style_near)
		UITheme.apply_text(_watch_label, UITheme.SECTION, UITheme.WARNING)


## Which quarter of the operator's frozen field of view the Curator is in.
##
## The tablet froze the player mid-turn, so this bearing is exactly the one they
## will be facing the moment they lower it -- which is what makes it a usable
## instruction rather than trivia. Sectors instead of degrees: nobody parses
## "137 deg" under a closing beep.
func _watch_bearing_key() -> String:
	var forward := _watch_forward()
	var flat := _watcher.global_position - _player.global_position
	flat.y = 0.0
	if forward == Vector3.ZERO or flat.length_squared() < 0.0001:
		return "HUD_WATCH_BEARING_AHEAD"
	flat = flat.normalized()
	var ahead := forward.dot(flat)
	if ahead >= WATCH_SECTOR_DOT:
		return "HUD_WATCH_BEARING_AHEAD"
	if ahead <= -WATCH_SECTOR_DOT:
		return "HUD_WATCH_BEARING_BEHIND"
	# forward x UP is the operator's right hand: with Godot's -Z forward that
	# cross product lands on +X, so a positive dot means "to your right".
	return "HUD_WATCH_BEARING_RIGHT" if forward.cross(Vector3.UP).dot(flat) > 0.0 \
		else "HUD_WATCH_BEARING_LEFT"


## The operator's flattened facing. Prefer the camera, because it carries the
## yaw the body has plus nothing the body does not; fall back to the body when
## the camera is pitched far enough that flattening its forward is degenerate.
func _watch_forward() -> Vector3:
	if _player == null:
		return Vector3.ZERO
	var forward := Vector3.ZERO
	if is_instance_valid(_player_camera):
		forward = -_player_camera.global_transform.basis.z
		forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = -_player.global_transform.basis.z
		forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.ZERO


func _sfx(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var am := get_tree().get_first_node_in_group("audio_manager")
	if am != null and am.has_method("play_sfx"):
		am.play_sfx(sound, volume_db, pitch)


func _restore_player() -> void:
	if _scale_controller != null:
		_scale_controller.reset()
	if _player != null:
		_player.set("gravity", _base_gravity)
		_player.set("jump_velocity", 6.0)
		_player.set("walk_speed", _base_walk)
		_player.set("run_speed", _base_run)
	if _flashlight != null:
		_flashlight.visible = bool(_player.get("flashlight_enabled")) if _player != null else true
		_flashlight.light_energy = _base_flash_energy


func _build_hud() -> void:
	_build_watch_alert()
	_build_death_screen()


## The single task block, wherever it came from.
##
## TaskBlock's premise is that exactly ONE exists -- two of them at the same
## anchors on the same layer would be the very defect it was written to remove --
## so this adopts the block the shift HUD already owns and only builds one when
## there is none: by group first (cheap), by type second (correct even if the
## owner never joined the group), and either way the result is published under
## TASK_BLOCK_GROUP so every later lookup is O(1).
func _resolve_task_block() -> void:
	if is_instance_valid(_block) or not is_inside_tree():
		return
	var shared: Node = get_tree().get_first_node_in_group(TASK_BLOCK_GROUP)
	if shared == null:
		var found := get_tree().get_root().find_children("*", "TaskBlock", true, false)
		if not found.is_empty():
			shared = found[0]
	if shared == null:
		shared = TaskBlock.new()
		add_child(shared)
		# Only a block WE built is renumbered: an adopted one already carries the
		# layer its owner chose. See HUD_TASK_LAYER for why 17 is not acceptable.
		(shared as CanvasLayer).layer = HUD_TASK_LAYER
	_block = shared as TaskBlock
	if _block != null and not _block.is_in_group(TASK_BLOCK_GROUP):
		_block.add_to_group(TASK_BLOCK_GROUP)


## The catch screen: the operator's own terminal, losing the feed.
##
## What fades in is a TerminalFrame in its signal-lost state -- the torn picture,
## the dead readouts, SIGNAL LOST on an opaque plate -- rather than the bare
## ColorRect this used to be. It is still an opaque SURFACE veil by the time the
## hand-off happens, because the frame's own backdrop is that colour, so the fail
## screen underneath still starts from the value it expects; it just says what
## happened on the way down instead of only hiding it.
##
## THE TUBE IS OFF ON THIS ONE. The fade is `modulate.a` on the frame, and
## CRTOverlay's shader assigns COLOR outright, which discards the modulate the
## engine hands it -- the glass would therefore snap to full strength the instant
## the layer is shown and sit there through a fade that is meant to start from
## nothing. A frame that fades honestly is worth more here than a tube.
func _build_death_screen() -> void:
	_death_layer = CanvasLayer.new()
	_death_layer.name = "Curator Catch Screen"
	_death_layer.layer = DEATH_LAYER
	_death_layer.visible = false
	add_child(_death_layer)
	_death_screen = TerminalFrame.new()
	_death_screen.name = "Signal Lost"
	_death_screen.set_crt_enabled(false)
	_death_screen.modulate.a = 0.0
	_death_layer.add_child(_death_screen)


## Motion readout drawn over the camera feed. Its own CanvasLayer at
## WATCH_ALERT_LAYER, whose header lists what it has to beat and what has to beat
## it -- the whole point is that it is legible while the tablet owns the screen.
func _build_watch_alert() -> void:
	_watch_layer = CanvasLayer.new()
	_watch_layer.name = "Curator Proximity Alert"
	_watch_layer.layer = WATCH_ALERT_LAYER
	_watch_layer.visible = false
	add_child(_watch_layer)

	_watch_style_near = _watch_border(UITheme.WARNING)
	_watch_style_critical = _watch_border(UITheme.DANGER)

	_watch_frame = Panel.new()
	_watch_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_watch_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_watch_frame.add_theme_stylebox_override("panel", _watch_style_near)
	_watch_layer.add_child(_watch_frame)

	var banner := Panel.new()
	banner.anchor_left = 0.22
	banner.anchor_top = 0.055
	banner.anchor_right = 0.78
	banner.anchor_bottom = 0.155
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_panel(banner)
	_watch_layer.add_child(banner)

	_watch_label = Label.new()
	_watch_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Panel is not a container, so the stylebox's content margins do not lay the
	# label out; inset it by hand on the same tokens.
	_watch_label.offset_left = UITheme.PAD_X
	_watch_label.offset_right = -UITheme.PAD_X
	_watch_label.offset_top = UITheme.PAD_Y
	_watch_label.offset_bottom = -UITheme.PAD_Y
	_watch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_watch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_watch_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_watch_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text(_watch_label, UITheme.SECTION, UITheme.WARNING)
	banner.add_child(_watch_label)


## Screen-edge band: border only, so the camera feed underneath stays readable.
func _watch_border(color: Color) -> StyleBoxFlat:
	var style := UITheme.stylebox(Color.TRANSPARENT, color, WATCH_FRAME_WIDTH, 0)
	style.draw_center = false
	return style


## The anomaly readout, on the shared block instead of on a label of its own.
##
## ONE SLOT, AND ONLY ONE. This node used to write slot 3 (the hint) AND slot 4
## (the progress caption) every frame for the whole of every anomaly, while
## GameManager wrote both of them every frame too. It sits after GameManager in
## scenes/FirstMuseumMap.tscn, so it always won, and the measured effect was that
## the interaction prompt and the stamina gauge were silently erased for the
## duration of every incident -- "В руках: Нуль-фонарь (G - бросить)" replaced by
## "НУЛЬ-ФОНАРЬ: Куратор замедлен рядом с вами", and the gauge by "ГРАВИТАЦИЯ:
## 100%". Nobody chose that; node order in a scene neither file builds did.
##
## The block grew a slot so the shortage could be fixed without picking a loser,
## and this node's whole readout now lives in it:
##
##   slot 4, the status line ... what the world is doing to the operator.
##       A state, never a ratio: every HUD_EFFECT_* row carries its own number or
##       none, so a bar would be inventing a scale. While a CCTV scan is pending
##       the scan percentage stands here instead -- inside its own slot the
##       anomaly prefers the line with a deadline, which is arbitration by one
##       owner rather than a race between two.
##
## The carried tool's own line (HUD_TOOL_*) moved to GameManager, which owns
## `_carried_id` and slot 5 and was already saying "Carrying: X" there. Nothing
## was dropped; it is said once, by the node that knows it, in the slot that means
## it.
##
## Keys and arguments, never text: the block resolves through Loc.fmt() and drops
## the write when the resolved string has not changed, which is what makes a
## per-frame caller free.
func _update_readouts() -> void:
	if _block == null:
		return
	# Inside a pocket dimension the trial owns the status line: it is naming the
	# dimension the operator is standing in, and a gravity percentage measured in
	# the museum below is not a fact about anywhere they are. GameManager performs
	# the hand-over in _begin_trial(); this is the guard that keeps us out of the
	# slot until it comes back.
	if not _active or _trial_running():
		release_readouts()
		return
	if not _readouts_owned:
		# claim() before the first write, so the lease is taken at the moment the
		# incident starts rather than at the moment the first readout happens to
		# differ. A refused claim leaves _readouts_owned false and this node silent,
		# which is the right failure: one system's answer, not two alternating.
		if not _block.claim(TaskBlock.Slot.STATUS, TaskBlock.OWNER_ANOMALY):
			return
		_readouts_owned = true
	# The scan is preferred over the effect readout while one is pending: it is the
	# method of the objective GameManager has just set and it is the only one of
	# the two with a deadline.
	if not _scan_complete and _required_camera >= 0:
		_block.set_status("HUD_SCAN_PROGRESS", [100.0 * _scan_progress / SCAN_TIME], TaskBlock.OWNER_ANOMALY)
		return
	# Every key spelled at its own call site with its own arguments, rather than
	# collected into a variable and formatted once below: tools/check_localization.py
	# can only see the arity of a call it can read, and a key whose specifiers no
	# call site is seen to format is a fatal finding there -- correctly, since that
	# is exactly how a raw "%s" reaches the screen.
	match _anomaly:
		"gravity_surge":
			# The argument list stays on the key's own line for the same reason: the
			# checker reads one line at a time.
			var pull := float(_player.get("gravity")) / _base_gravity * 100.0
			_block.set_status("HUD_EFFECT_GRAVITY", [pull], TaskBlock.OWNER_ANOMALY)
		"temporal_drift":
			var pace := float(_player.get("walk_speed")) / _base_walk * 100.0
			_block.set_status("HUD_EFFECT_TEMPORAL", [pace], TaskBlock.OWNER_ANOMALY)
		"radiation_bloom":
			_block.set_status("HUD_EFFECT_DOSE", [_exposure], TaskBlock.OWNER_ANOMALY)
		"void_rift": _block.set_status("HUD_EFFECT_VOID", [], TaskBlock.OWNER_ANOMALY)
		"echo_chamber": _block.set_status("HUD_EFFECT_ECHO", [], TaskBlock.OWNER_ANOMALY)
		"glass_bridge": _block.set_status("HUD_EFFECT_GLASS", [], TaskBlock.OWNER_ANOMALY)
		"mirror_maze": _block.set_status("HUD_EFFECT_MIRROR", [], TaskBlock.OWNER_ANOMALY)
		"yellow_halls": _block.set_status("HUD_EFFECT_YELLOW", [], TaskBlock.OWNER_ANOMALY)
		"scrap_run": _block.set_status("HUD_EFFECT_SCRAP", [], TaskBlock.OWNER_ANOMALY)
		"ascent": _block.set_status("HUD_EFFECT_ASCENT", [], TaskBlock.OWNER_ANOMALY)
		_: _block.set_status("", [], TaskBlock.OWNER_ANOMALY)


## Is a pocket dimension open? Read from GameManager rather than kept here: it is
## the node that opens and closes one, and a second copy of the flag is a second
## thing to forget to clear. Same lookup _update_watch() already uses.
func _trial_running() -> bool:
	return _game != null and bool(_game.get("_trial_active"))


## Give slot 4 back. Called from _end_anomaly(), from the trial guard above, and
## by GameManager._begin_trial() one line before it hands the slot to the trial --
## that last caller is what makes the hand-over synchronous instead of a race
## between two _process() orders.
##
## Released once, not every frame, and only if the slot was ours: the block is
## shared, and clearing a line another owner put there would be a silent,
## one-directional theft. release() refuses it anyway; this keeps the log clean.
func release_readouts() -> void:
	if not _readouts_owned:
		return
	_readouts_owned = false
	if _block == null:
		return
	# Blank the line before dropping the lease: an empty string means "nothing to
	# say", which is a thing an OWNER says, so the clear has to happen while we
	# still hold it.
	_block.set_status("", [], TaskBlock.OWNER_ANOMALY)
	_block.release(TaskBlock.Slot.STATUS, TaskBlock.OWNER_ANOMALY)


func _update_player_scale() -> void:
	if _scale_controller == null:
		return
	var strength := _local_strength()
	if strength <= 0.01:
		_scale_controller.set_target(1.0)
		return
	if not ANOMALY_SCALE_SPAN.has(_anomaly):
		# echo_chamber, glass_bridge, mirror_maze, yellow_halls, scrap_run and
		# ascent have no size curve; the operator keeps the size they already
		# have, exactly as when the match below simply fell through.
		return
	var span: Vector2 = ANOMALY_SCALE_SPAN[_anomaly]
	match _anomaly:
		"gravity_surge":
			_scale_controller.set_target(lerpf(span.x, span.y, 0.5 + 0.5 * sin(_phase * 0.75)))
		"temporal_drift":
			# Square wave rather than a sine: the two extremes only, 12 s per cycle.
			_scale_controller.set_target(span.x if fmod(_phase, 12.0) < 6.0 else span.y)
		"radiation_bloom":
			# Breathing expansion/contraction keeps every calibration size reachable.
			_scale_controller.set_target(lerpf(span.x, span.y, 0.5 + 0.5 * sin(_phase * 0.62)))
		"void_rift":
			_scale_controller.set_target(lerpf(span.x, span.y, 0.5 + 0.5 * sin(_phase * 0.55)))


func _local_strength() -> float:
	if _player == null:
		return 0.0
	var distance := _player.global_position.distance_to(_incident_origin)
	var strength := 1.0 - smoothstep(EFFECT_RADIUS * 0.45, EFFECT_RADIUS, distance)
	if _carried_tool() == "phase_prism":
		# Фазовая призма гасит локальное влияние аномалии.
		strength *= 0.45
	return strength


func _build_rift_visual() -> void:
	if _map == null:
		return
	if is_instance_valid(_rift_visual):
		_rift_visual.queue_free()
	_rift_visual = Node3D.new()
	_rift_visual.name = "Active Exhibit Rupture"
	_rift_visual.position = _incident_origin + Vector3(0, 1.55, 0)
	_map.add_child(_rift_visual)
	var colors := {
		"gravity_surge": Color(0.62, 0.35, 0.95),
		"temporal_drift": Color(0.95, 0.68, 0.25),
		"radiation_bloom": Color(0.35, 0.90, 0.35),
		"void_rift": Color(0.25, 0.45, 0.95),
		"echo_chamber": Color(0.95, 0.42, 0.22),
		"glass_bridge": Color(0.78, 0.38, 0.92),
		"mirror_maze": Color(0.55, 0.78, 0.95),
		"yellow_halls": Color(0.90, 0.80, 0.30),
		"scrap_run": Color(0.55, 0.90, 0.75),
		"ascent": Color(0.95, 0.55, 0.65),
	}
	var color: Color = colors.get(_anomaly, Color(0.7, 0.8, 1.0))
	for i in range(3):
		var ring := MeshInstance3D.new()
		ring.name = "Rupture Ring %d" % i
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.62 + float(i) * 0.2
		mesh.outer_radius = 0.70 + float(i) * 0.2
		ring.mesh = mesh
		ring.rotation_degrees = Vector3(90.0 if i % 2 == 0 else 0.0, float(i) * 37.0, 0.0)
		var material := StandardMaterial3D.new()
		material.albedo_color = color.darkened(0.25)
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
		ring.material_override = material
		_rift_visual.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.2
	light.omni_range = 10.0
	_rift_visual.add_child(light)


func _animate_rift(delta: float) -> void:
	if not is_instance_valid(_rift_visual):
		return
	var lens_active := _carried_tool() == "spectral_lens"
	for i in range(_rift_visual.get_child_count()):
		var child := _rift_visual.get_child(i)
		if child is MeshInstance3D:
			child.rotate_y(delta * (0.65 + 0.22 * float(i)) * (-1.0 if i % 2 else 1.0))
			var ring_mat := (child as MeshInstance3D).material_override as StandardMaterial3D
			if ring_mat != null and ring_mat.no_depth_test != lens_active:
				# Спектральная линза показывает разрыв сквозь стены.
				ring_mat.no_depth_test = lens_active
	var pulse := 1.0 + 0.08 * sin(_phase * 3.2)
	_rift_visual.scale = Vector3.ONE * pulse


func _build_watcher() -> void:
	if _map == null:
		return
	# The Curator owns its own navigation agent and movement; this node only
	# decides *when* it hunts and what a successful catch means.
	_watcher = CuratorMonster.new()
	_watcher.name = "The Curator"
	_watcher.visible = false
	_map.add_child(_watcher)
	_watcher.caught_player.connect(_on_watcher_caught)


func _on_watcher_caught() -> void:
	if _death_time >= 0.0:
		return
	_resolve_task_block()
	if _death_screen == null or _game == null or _player == null:
		# No HUD was ever built (headless suites, or _initialize() bailed out).
		# Fail the run the blunt way rather than not at all.
		if _game != null:
			_announce_caught()
			_game.call("_fail")
		return
	_begin_death()


## Said once, through the block when there is one -- a BAD-toned message takes
## the loud line for its dwell and hands it straight back, which is what the
## block's flash channel is for -- and through GameManager's own banner when this
## node never got a HUD at all.
func _announce_caught() -> void:
	if _block != null:
		_block.flash("HUD_CURATOR_CAUGHT", [], TaskBlock.Tone.BAD)
	elif _game != null:
		_game.call("_flash", tr("HUD_CURATOR_CAUGHT"), UITheme.DANGER)


func _begin_death() -> void:
	_death_time = 0.0
	_death_handed_off = false
	_death_layer.visible = true
	_death_screen.modulate.a = 0.0
	# The night is the last true thing the terminal reports; the shift clock and
	# the core drop to their dead readings by themselves once the signal is gone.
	_death_screen.set_status(_night, -1.0, "TERM_CORE_CRITICAL", TerminalFrame.CORE_CRITICAL)
	_death_screen.set_signal_lost(true, "TERM_SIGNAL_LOST")
	# Re-read reduced_flashes now rather than trusting whatever was true when this
	# was built, which was two frames into the scene and possibly before the
	# settings node existed.
	_death_screen.refresh()
	# Order matters. close() hands control back through
	# GameManager.player_controls_allowed(), which still answers "yes" -- the run
	# has not failed yet -- so the tablet has to be lowered BEFORE control is
	# taken, or it would grant it straight back. Lowering it also returns the
	# viewport to the player's own camera, without which there is nothing to aim.
	if _tablet != null and bool(_tablet.get("_open")) and _tablet.has_method("close"):
		_tablet.call("close")
	_hide_watch_alert()
	# Revoking control, never granting it: GameManager remains the only thing
	# allowed to hand it back, and _fail() re-revokes through _set_player_controls
	# at the end of this sequence.
	_player.set("controls_enabled", false)
	_player.velocity = Vector3.ZERO
	_death_from_yaw = _player.rotation.y
	_death_from_pitch = float(_player.get("_pitch"))
	# Said now, not at the hand-off: the message holds slot 1 for 2.4 s, so it is
	# legible across the turn and the hold and is covered by the screen above only
	# once that screen is opaque -- which is a second later than the fail scrim.
	_announce_caught()
	# One low hit on the seize. GameManager plays its own "fail" sting later.
	_sfx("blackout", -3.0, 0.68)


func _update_death(delta: float) -> void:
	var previous := _death_time
	_death_time += delta
	_aim_at_watcher(clampf(_death_time / DEATH_TURN, 0.0, 1.0))
	var fade_at := DEATH_TURN + DEATH_HOLD
	var handoff_at := fade_at + DEATH_FADE
	if _death_time < handoff_at:
		if previous < fade_at and _death_time >= fade_at:
			_sfx("power_down", -7.0, 0.9)
		_death_screen.modulate.a = clampf((_death_time - fade_at) / DEATH_FADE, 0.0, 1.0)
		return
	if not _death_handed_off:
		_death_handed_off = true
		_death_screen.modulate.a = 1.0
		# Behind an opaque veil, in this order: our own presentation comes down
		# first, so the Curator is never seen to blink out, and then the run is
		# handed to GameManager, which owns the fail overlay and the retry.
		_end_anomaly()
		if int(_game.get("_state")) != STATE_FAILED:
			_game.call("_fail")
		return
	# The night timer can fail the run mid-sequence; _fail() is then already done
	# and the release just uncovers the screen it put up.
	_death_screen.modulate.a = clampf(1.0 - (_death_time - handoff_at) / DEATH_RELEASE, 0.0, 1.0)
	if _death_time - handoff_at >= DEATH_RELEASE:
		_death_time = -1.0
		_death_layer.visible = false
		# A hidden CanvasLayer draws nothing, but a frame left in its signal-lost
		# state keeps re-rolling the tear behind it; this is what stops its clock.
		_death_screen.set_signal_lost(false)


## Ease the operator's own head onto the Curator's lens. `amount` runs 0 -> 1
## across DEATH_TURN; once it reaches 1 this keeps rewriting the finished aim
## every frame, which is what holds the frame steady while the body slides the
## last few centimetres to a stop under its own deceleration.
func _aim_at_watcher(amount: float) -> void:
	if not is_instance_valid(_watcher):
		return
	var eye := _player.global_position + Vector3.UP * 1.65
	if is_instance_valid(_player_camera):
		eye = _player_camera.global_position
	var to := _watcher.global_position + Vector3.UP * DEATH_FOCUS_Y - eye
	var flat := Vector2(to.x, to.z).length()
	var eased := amount * amount * (3.0 - 2.0 * amount)
	if flat > 0.01:
		# Godot forward is -Z: the same yaw convention PlayerController turns the
		# body on and CuratorMonster._face() turns the Curator on.
		_player.rotation.y = lerp_angle(_death_from_yaw, atan2(-to.x, -to.z), eased)
	var pitch := lerpf(_death_from_pitch,
		clampf(atan2(to.y, maxf(flat, 0.01)), deg_to_rad(-85.0), deg_to_rad(85.0)), eased)
	# Write PlayerController's own pitch field as well as the camera node: the
	# controller integrates mouse motion onto `_pitch` and re-applies it, so
	# leaving the two disagreeing would snap the view back to the pre-death angle
	# on the first mouse movement after a retry.
	_player.set("_pitch", pitch)
	if is_instance_valid(_player_camera):
		_player_camera.rotation.x = pitch
