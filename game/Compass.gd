extends Node
## Navigation aid for the Observer: where you are, and which way the job is.
##
## Stage 9.3. The museum has eleven rooms, no signage the player can read while
## walking, and its only floor plan lives inside the CCTV tablet -- which is a
## fixed workstation in the security office, so it answers "where am I" only in
## the one room where the question never comes up. The result is the fourth
## complaint on the owner's list: "непонятно, где я и куда идти".
##
## Three parts, each switchable on its own, because they solve three different
## halves of that sentence and a player who wants one may not want the others:
##
##   1. POSITION -- the name of the room the operator is standing in.
##      set_room_readout_enabled().
##   2. OBJECTIVE -- an arrow and a bearing to whatever the night currently
##      wants. Direction and range, never a route: a breadcrumb trail would
##      turn the building into a corridor and kill the tension the wrong way.
##      set_bearing_enabled().
##   3. FLOOR PLAN -- a compact plan of the eleven rooms, held open on a key
##      rather than pinned, so it costs the player their attention for as long
##      as they read it. set_minimap_enabled().
##
## Setup mirrors SecurityCameraTablet: add a plain Node named Compass beside
## GameManager in the main scene and attach this script. It finds the player,
## the map, the tablet and GameManager on its own and builds its own UI; every
## one of those is optional and a missing one costs a feature, not a crash.
##
##
## THE ROOM RECTANGLES ARE NOT COPIED (and must never be)
##
## SecurityCameraTablet.ROOMS already carries all eleven room rectangles, and
## test_map_verification pins them to the geometry FirstMuseumMap actually
## builds. Duplicating that table here would create a second set of numbers with
## no test behind it, which would drift the first time a wall moves and would
## then confidently name the wrong room -- worse than no readout at all. So the
## table is read out of the shipping script at runtime (_load_rooms), and if it
## cannot be read the position readout says so instead of guessing.
##
##
## THIS IS A BUILDING SYSTEM, AND THE BUILDING IS FAILING
##
## A map that always works makes a horror museum safe, and safe is the one thing
## this game cannot afford to be. So the readout is diegetic: it is the First
## Museum's own wayfinding net, it runs on the museum's power, and it is only as
## healthy as the building is.
##
##   * Before the blackout, on mains power, it is perfect.
##   * After the blackout the whole building is on the emergency circuit and the
##     net degrades everywhere: the room name still resolves, the arrow still
##     points, but the range drops off the readout and the bearing wanders
##     inside its own error.
##   * When the Curator is close the net dies outright. Whatever it is, it is
##     louder than the building. The readout keeps the last fix and says that it
##     is a last fix, which is the most frightening thing it can truthfully say.
##   * Inside the security office it is perfect again, whatever else is true --
##     the office is where the net's own hardware lives. Walking back through
##     that door restores a sense the player had lost, which is the point.
##
## set_disturbance(level) lets the rest of the game push the net down for its own
## reasons (an anomaly, a scripted beat). It is a floor, not a replacement: the
## Curator and the blackout are still applied on top, so a caller cannot
## accidentally make the compass MORE reliable than the building is.
##
##
## ACCESSIBILITY
##
## * The arrow never carries the direction on its own. Every state that draws it
##   also prints the sector in words -- AHEAD OF YOU / BEHIND YOU / TO YOUR LEFT
##   / TO YOUR RIGHT, the same four the office motion sensor already uses -- so
##   the readout survives being unable to judge a rotation, and the two channels
##   agree because they are computed from one angle.
## * Signal health is never colour alone: CLEAR prints no status line, DEGRADED
##   and DOWN each print their own sentence, and the room name changes shape
##   (it gains "last fix") when it goes stale.
## * Nothing moves for a player who has asked for reduced flashing. The bearing
##   wander that expresses error on a degraded net is replaced by quantising the
##   arrow to 45-degree sectors, which says the same thing -- this reading is
##   only good to a sector -- without animating.
## * Every surface is opaque UITheme.SURFACE_RAISED rather than a scrim, so the
##   contrast ratios tabulated in UITheme.gd apply exactly as written: ON_SURFACE
##   11.99:1, MUTED 6.30:1, ACCENT 6.09:1, WARNING 6.55:1, DANGER 5.28:1. The
##   floor is 4.5:1 and the worst of those clears it by 17%.
## * Nothing here is focusable and nothing takes the pointer, so the panel cannot
##   swallow a click or a focus ring meant for the tablet underneath.

# --- WHERE THE ROOM TABLE COMES FROM ----------------------------------------

## Owner of the eleven room rectangles. Read, never written.
const ROOM_SOURCE := "res://game/SecurityCameraTablet.gd"
## The constant to pull out of it.
##
## SINGLE QUOTES ARE DELIBERATE. The localization sweep -- KEY_LITERAL_RE in
## tools/check_localization.py, mirrored by KEY_LITERAL_PATTERN in
## game/test_map_verification.gd -- treats every DOUBLE-quoted UPPER_SNAKE
## literal under game/ as a translation key and fails the build when the
## catalogue has no row for it. This is a GDScript identifier, not a key.
## "Fixing" the quotes turns both gates red.
const ROOM_CONSTANT := 'ROOMS'

## How far outside every mapped rectangle the operator may stand and still be
## told which room they are in. Doorways, the gap between the office and the
## storage annex, and the strip of forecourt in front of the entrance all sit in
## this band; past it the honest answer is that the plan does not cover it.
const ROOM_SLACK := 3.5

# --- SIGNAL HEALTH ----------------------------------------------------------
#
# One number, 0 (dead) .. 1 (perfect), and three bands. The bands are wide on
# purpose: a readout that slides continuously between "trustworthy" and "lying"
# teaches the player nothing, while three named states are learnable in one
# night and are what the status line can put into words.

## Floor of the CLEAR band: full readout, no status line.
const BAND_CLEAR := 0.66
## Floor of the DEGRADED band. Below it the net is DOWN.
const BAND_WEAK := 0.30

## What the emergency circuit costs the net once the blackout has fired. Lands
## inside DEGRADED with room to spare on both sides, so an anomaly pushing
## through set_disturbance() can still take it the rest of the way down.
const BLACKOUT_NOISE := 0.45
## Range at which the Curator starts drowning the net out, and the range at
## which it has finished. The far end is deliberately outside the office motion
## sensor's WATCH_ALERT_RANGE (24 m): losing the compass is the first warning,
## and it arrives before any instrument says why.
const CURATOR_NOISE_RANGE := 27.0
const CURATOR_NOISE_DEAD := 9.0

## Bearing error on a degraded net, in degrees, expressed either as a wander or
## -- for reduced flashing -- as the sector the arrow snaps to.
const WEAK_ERROR_DEGREES := 18.0
const WEAK_SECTOR_DEGREES := 45.0
## Speed of that wander, in radians per second of phase. Slow enough to read as
## an instrument hunting rather than as a flicker.
const WEAK_WANDER_SPEED := 1.9

# --- LAYOUT -----------------------------------------------------------------
#
# Bottom right, and the numbers below are what keeps it there. The night HUD is
# already crowded and every neighbour is fixed: GameManager's objective band
# (x 0.01..0.62, y 0.10..0.19), its timer (y 0.02..0.10) and its interaction
# hint (y 0.90..0.98); GameplayEnhancements' anomaly readout (x 0.72..0.98,
# y 0.02..0.16); PlayerController's stamina panel (bottom LEFT, 260x58).
# BOTTOM_MARGIN clears the hint band and STACK_HEIGHT stops short of the anomaly
# readout, at 1280x720 with the large-text scale applied as well as at 1600x900.

const PANEL_WIDTH := 232
const EDGE_MARGIN := 24
const BOTTOM_MARGIN := 96
const STACK_HEIGHT := 420
const STACK_SEPARATION := 8

## Plan viewport. 196:168 is 7:6, which is the aspect of the museum's own
## footprint -- all eleven rooms span exactly 98 x 84 m -- so _draw_map's fit
## lands at 1.857 px/m and draws 182 x 156 of the 184 x 156 left inside the
## inset. Two spare pixels on one axis, none on the other; change either number
## and the plan starts floating in its panel.
const MAP_VIEW := Vector2(196, 168)
## Inset between the plan viewport and the outermost wall it draws.
const MAP_INSET := 6.0
## Below this width in pixels a room is too small to carry a legend.
const MAP_LABEL_MIN_WIDTH := 30.0
const MAP_PLAYER_RADIUS := 5.0
const MAP_TARGET_RADIUS := 6.0

## Side of the square the objective arrow is drawn in.
const ARROW_BOX := 46

## CanvasLayer index. Above GameManager's night HUD (5) so the panel is never
## buried by the objective band, and well below SecurityCameraTablet (10): the
## tablet is a full-screen workstation with its own, better map, and this thing
## has no business drawing over it. It is hidden outright while the tablet is up
## -- see _should_show() -- and the layer order is the second belt.
const HUD_LAYER := 6

## Hold this to raise the floor plan. Created here rather than in
## game/InputBootstrap.gd because that file belongs to the input map as a whole
## and this action belongs to this feature; the guard means whichever of the two
## runs first wins and the other is a no-op. KEY_M is unclaimed, and BACK/SELECT
## is the one pad button InputBootstrap's own header lists as free -- the D-pad
## is off limits, it is the only way to drive focus navigation.
const MAP_ACTION := "compass_map"

# --- SIGNAL BANDS -----------------------------------------------------------
const SIGNAL_CLEAR := 0
const SIGNAL_WEAK := 1
const SIGNAL_DOWN := 2

# GameManager states, mirrored so the objective can be chosen without reaching
# for that file's constants. Read only; GameManager owns the values.
const STATE_DAY := 0
const STATE_COUNTDOWN := 1
const STATE_ANOMALY := 2
const STATE_RESOLVED := 3
const STATE_CALM := 5

var _player: Node3D = null
var _camera: Camera3D = null
var _map: Node = null
var _game: Node = null
var _tablet: Node = null
var _enhancements: Node = null
var _curator: Node3D = null

## Room table lifted from ROOM_SOURCE. Each entry:
##   key    -- catalogue key for the room's name
##   center -- world (x, z) of its middle
##   half   -- half extents on (x, z)
##   area   -- footprint in square metres, used to break ties
##   night  -- first shift the room is open on
var _rooms: Array[Dictionary] = []
## Bounding box of every room, in world (x, z). Drives the plan's fit.
var _world_bounds := Rect2()

var _enabled := true
var _room_enabled := true
var _bearing_enabled := true
var _minimap_enabled := true

## Disturbance pushed in by the rest of the game. A floor under the building's
## own, never a replacement for it -- see the header.
var _disturbance := 0.0
var _band := SIGNAL_CLEAR
var _band_known := false
var _wander := 0.0

var _room_key := ""
## Last room the net was healthy enough to be sure about. What the readout falls
## back to once it is not.
var _last_fix_key := ""

var _has_target := false
var _target := Vector3.ZERO
var _target_room := ""
var _manual_target := false
var _arrow_angle := 0.0
var _arrow_color := UITheme.ACCENT
var _map_held := false

var _layer: CanvasLayer = null
var _stack: VBoxContainer = null
var _map_panel: PanelContainer = null
var _map_title: Label = null
var _map_view: Control = null
var _bearing_panel: PanelContainer = null
var _bearing_caption: Label = null
var _bearing_label: Label = null
var _arrow: Control = null
var _room_panel: PanelContainer = null
var _room_caption: Label = null
var _room_label: Label = null
var _status_label: Label = null
var _map_hint: Label = null


func _ready() -> void:
	add_to_group("compass")
	_ensure_map_action()
	call_deferred("_initialize")


## The map, the player and every manager are generated at runtime, so nothing
## below can run until the scene has settled. Same two-frame wait, and the same
## re-check after each one, that GameManager and GameplayEnhancements use: an
## editor reload can detach this node across an awaited frame.
func _initialize() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var parent := get_parent()
	if parent != null:
		_game = parent.get_node_or_null("GameManager")
		_tablet = parent.get_node_or_null("SecurityCameraTablet")
	_map = get_tree().get_first_node_in_group("museum_map")
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player != null:
		_camera = _player.get_node_or_null("Player Camera") as Camera3D
	_load_rooms()
	_build_ui()
	_refresh_static_text()


# --- PUBLIC API -------------------------------------------------------------

## How badly the rest of the game is jamming the net, 0..1. Applied as a floor
## under the building's own disturbance: the Curator and the blackout still
## count on top, so no caller can make this readout more trustworthy than the
## building it belongs to.
func set_disturbance(level: float) -> void:
	_disturbance = clampf(level, 0.0, 1.0)


func get_disturbance() -> float:
	return _disturbance


## Everything off in one call, for a cutscene or a scripted blackout of the UI
## itself. Independent of the three feature switches: turning this back on
## restores whatever they were.
func set_enabled(value: bool) -> void:
	_enabled = value


func set_room_readout_enabled(value: bool) -> void:
	_room_enabled = value


func set_bearing_enabled(value: bool) -> void:
	_bearing_enabled = value


func set_minimap_enabled(value: bool) -> void:
	_minimap_enabled = value
	if not value:
		_map_held = false


## Point the arrow at an explicit place instead of at what the night loop would
## have chosen. `room_key` is a catalogue key for what to call the destination;
## leave it empty and the destination is named after whichever room contains it.
func set_objective_target(world_position: Vector3, room_key: String = "") -> void:
	_manual_target = true
	_target = world_position
	_target_room = room_key if room_key != "" else _resolve_room(
		Vector2(world_position.x, world_position.z))
	_has_target = true


## Hand targeting back to the night loop.
func clear_objective_target() -> void:
	_manual_target = false


## Catalogue key for the room the operator is in, or "" when the plan does not
## cover where they are standing. Answers from the last known position while the
## net is down, which is the same thing the readout shows.
func current_room_key() -> String:
	return _room_key


## 0 (dead) .. 1 (perfect). What the whole degradation model comes down to.
func signal_quality() -> float:
	var noise := _disturbance
	var in_office := _is_in_office()
	if not in_office and _blackout_done():
		noise = maxf(noise, BLACKOUT_NOISE)
	# The Curator is applied after the office relief on purpose. The office is a
	# shelter from the building's decay, not from the thing walking through it:
	# if it has followed the operator in, the readout dies in there too.
	noise = maxf(noise, _curator_noise())
	return clampf(1.0 - noise, 0.0, 1.0)


# --- FRAME ------------------------------------------------------------------

func _process(delta: float) -> void:
	if _layer == null:
		return
	if not _should_show():
		if _layer.visible:
			_layer.visible = false
			_map_held = false
		return
	_layer.visible = true

	_map_held = _minimap_enabled and InputMap.has_action(MAP_ACTION) \
		and Input.is_action_pressed(MAP_ACTION)

	var quality := signal_quality()
	_set_band(SIGNAL_CLEAR if quality >= BAND_CLEAR \
		else (SIGNAL_WEAK if quality >= BAND_WEAK else SIGNAL_DOWN))
	if _band == SIGNAL_WEAK and not _reduced_flashes():
		_wander += delta * WEAK_WANDER_SPEED
	_update_room()
	_update_target()
	_update_bearing()
	_update_panels()
	if _map_panel != null and _map_panel.visible and _map_view != null:
		_map_view.queue_redraw()


## Nothing draws while another screen owns the operator's attention or the
## museum is not where they are.
##
## The tablet is the important one: it is a fixed workstation with a far better
## map of the same eleven rooms, and doubling it with a second, worse plan in the
## corner would be noise. A pocket dimension is the other: the building's net
## does not reach inside one, and an arrow pointing confidently through the wall
## of a trial at a museum that is not there would be a bug that looks like a lie.
func _should_show() -> bool:
	if not _enabled or _player == null or not is_instance_valid(_player):
		return false
	if not (_room_enabled or _bearing_enabled or _minimap_enabled):
		return false
	if _tablet != null and bool(_tablet.get("_open")):
		return false
	if _game != null:
		if bool(_game.get("_trial_active")):
			return false
		# A fail / night-done / win overlay is up: the run is over and the panel
		# would print a bearing across the screen that ends it.
		if _game.has_method("player_controls_allowed") \
				and not bool(_game.call("player_controls_allowed")):
			return false
	return true


func _set_band(band: int) -> void:
	if _band_known and band == _band:
		return
	var was := _band
	var opening := not _band_known
	_band = band
	_band_known = true
	# Colours follow the band and nothing else, so they are written here rather
	# than in _update_panels(): an add_theme_color_override() every frame is an
	# override rebuilt sixty times a second, and each one notifies the whole
	# subtree that its theme changed.
	_apply_band_style()
	if opening:
		return
	# One quiet cue per transition, on the museum's own hardware vocabulary: the
	# net dropping out sounds like something powering down, and coming back
	# sounds like a terminal finding its feet. Neither is a scare -- the scare is
	# whatever made it drop.
	if band == SIGNAL_DOWN:
		_sfx("power_down", -15.0, 1.25)
	elif band == SIGNAL_CLEAR and was != SIGNAL_CLEAR:
		_sfx("terminal_beep", -18.0, 0.92)


func _apply_band_style() -> void:
	if _room_label != null:
		# The name is only trustworthy while the net is. A stale fix reads in
		# MUTED, so the readout looks like a record rather than a reading even
		# before the sentence under it has been read -- shape and wording carry
		# the same fact, so the colour is never the only channel.
		UITheme.apply_text(_room_label, UITheme.SECTION,
			UITheme.MUTED if _band == SIGNAL_DOWN else UITheme.ACCENT)
	if _status_label != null:
		UITheme.apply_text(_status_label, UITheme.CAPTION,
			UITheme.DANGER if _band == SIGNAL_DOWN else UITheme.WARNING)
	_arrow_color = UITheme.ACCENT if _band == SIGNAL_CLEAR else UITheme.WARNING


# --- POSITION ---------------------------------------------------------------

func _update_room() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var here := _resolve_room(_flat(_player.global_position))
	if _band == SIGNAL_DOWN:
		# Hold the last fix. The operator has not stopped moving; the building
		# has stopped being able to say where they moved to.
		return
	_room_key = here
	if here != "":
		_last_fix_key = here


## Catalogue key for the room containing `world` (x, z), or "" when none is
## close enough to claim it.
##
## Nearest rather than strictly-inside, because the operator spends a real
## fraction of the night in doorways and in the gap between two annexes, and a
## readout that blanks every time they cross a threshold is worse than one that
## rounds to the room they just left. Ties -- a point inside two rectangles, both
## at distance zero -- go to the smaller room, which is always the more specific
## answer.
func _resolve_room(world: Vector2) -> String:
	var best := ""
	var best_distance := INF
	var best_area := INF
	for room: Dictionary in _rooms:
		var distance := _rect_distance(world, room["center"], room["half"])
		var area: float = room["area"]
		if distance < best_distance - 0.001 \
				or (absf(distance - best_distance) <= 0.001 and area < best_area):
			best_distance = distance
			best_area = area
			best = String(room["key"])
	return best if best_distance <= ROOM_SLACK else ""


## Distance from `point` to an axis-aligned rectangle, 0 inside it.
func _rect_distance(point: Vector2, center: Vector2, half: Vector2) -> float:
	var outside := (point - center).abs() - half
	return Vector2(maxf(outside.x, 0.0), maxf(outside.y, 0.0)).length()


## World (x, z) of a named room's middle, and whether it was found at all.
func _room_center(key: String) -> Array:
	for room: Dictionary in _rooms:
		if String(room["key"]) == key:
			var center: Vector2 = room["center"]
			return [true, Vector3(center.x, 0.0, center.y)]
	return [false, Vector3.ZERO]


## Standing in the security office, where the net's own hardware lives. Uses the
## office rectangle from the shared table rather than a second copy of its
## bounds, so it cannot disagree with the room the readout is naming.
func _is_in_office() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	for room: Dictionary in _rooms:
		if String(room["key"]) != "CAM_ROOM_OFFICE":
			continue
		return _rect_distance(_flat(_player.global_position),
			room["center"], room["half"]) <= 0.0
	return false


# --- OBJECTIVE --------------------------------------------------------------

## Where the night currently wants the operator.
##
## Every branch is a place, never a path. The arrow says "that way, 24 m" and
## stops there; working out that the way through is the atrium and not the
## sealed blast door is the player's job, and it is most of the job.
func _update_target() -> void:
	if _manual_target:
		_has_target = true
		return
	_has_target = false
	_target_room = ""
	if _game == null or not is_instance_valid(_game):
		return
	var state := int(_game.get("_state"))
	match state:
		STATE_DAY:
			# The shift has not started: the office is the only instruction the
			# game has given, and OBJ_NIGHT_INTRO has just given it in words.
			_aim_at_room("CAM_ROOM_OFFICE")
		STATE_ANOMALY:
			if _scan_pending():
				# The source has to be confirmed on a camera before the protocol
				# unlocks, and the cameras only answer at the workstation.
				_aim_at_room("CAM_ROOM_OFFICE")
			elif String(_game.get("_carried_id")) == "":
				# Empty handed: the containment gear is racked in storage. Which
				# device to pick is on the protocol screen, not on this arrow.
				_aim_at_room("CAM_ROOM_STORAGE")
			else:
				_aim_at_incident()
		STATE_COUNTDOWN, STATE_CALM, STATE_RESOLVED:
			_aim_at_room("CAM_ROOM_OFFICE")
		_:
			pass


func _aim_at_room(key: String) -> void:
	var found := _room_center(key)
	if not bool(found[0]):
		return
	_target = found[1]
	_target_room = key
	_has_target = true


func _aim_at_incident() -> void:
	var puzzle := get_tree().get_first_node_in_group("exhibit_puzzle_controller")
	if puzzle == null or not puzzle.has_method("get_incident_origin"):
		return
	var origin: Vector3 = puzzle.call("get_incident_origin")
	_target = origin
	_target_room = _resolve_room(_flat(origin))
	_has_target = true


## True while the night is waiting on the CCTV confirmation. Reads
## GameplayEnhancements the same way SecurityCameraTablet already does -- that
## node owns the scan, publishes itself in a group from its own _ready(), and is
## optional furniture, so every hop is guarded and a miss simply means no scan.
func _scan_pending() -> bool:
	if not is_instance_valid(_enhancements):
		_enhancements = get_tree().get_first_node_in_group("gameplay_enhancements")
	if _enhancements == null:
		return false
	if not bool(_enhancements.get("_active")):
		return false
	var done: Variant = _enhancements.get("_scan_complete")
	return typeof(done) == TYPE_BOOL and not bool(done)


## Bearing to the target, as an angle and as a sentence. Both come out of the
## same number, so the arrow and the words can never disagree.
func _update_bearing() -> void:
	if not _has_target or _player == null or not is_instance_valid(_player):
		return
	var delta := _flat(_target) - _flat(_player.global_position)
	var forward := _player_forward()
	var angle := 0.0
	if forward != Vector2.ZERO and delta.length_squared() > 0.0001:
		var direction := delta.normalized()
		# forward rotated a quarter turn is the operator's right hand: world
		# forward (fx, 0, fz) crossed with UP lands on (-fz, 0, fx).
		var right := Vector2(-forward.y, forward.x)
		angle = atan2(right.dot(direction), forward.dot(direction))
	_arrow_angle = _degrade_angle(angle)


## What the arrow is allowed to claim at the current signal band.
##
## CLEAR is the true angle. DEGRADED is the true angle plus an error the player
## can see: a slow wander for anyone who can take motion, and -- for a player
## who has asked for reduced flashing -- the same statement made without moving,
## by snapping the needle to 45-degree sectors. Both say "good to a sector, not
## to a degree"; neither is decoration.
func _degrade_angle(angle: float) -> float:
	if _band != SIGNAL_WEAK:
		return angle
	if _reduced_flashes():
		var sector := deg_to_rad(WEAK_SECTOR_DEGREES)
		return roundf(angle / sector) * sector
	return angle + deg_to_rad(WEAK_ERROR_DEGREES) * sin(_wander) * 0.5 \
		+ deg_to_rad(WEAK_ERROR_DEGREES) * sin(_wander * 2.7) * 0.5


## Which quarter of the operator's view the target sits in. The same four
## sentences the office motion sensor uses for the Curator, because the operator
## has already learnt them there and a second vocabulary for the same fact would
## be a second thing to learn.
func _bearing_key() -> String:
	var away := absf(_arrow_angle)
	if away <= PI * 0.25:
		return "HUD_WATCH_BEARING_AHEAD"
	if away >= PI * 0.75:
		return "HUD_WATCH_BEARING_BEHIND"
	return "HUD_WATCH_BEARING_RIGHT" if _arrow_angle > 0.0 \
		else "HUD_WATCH_BEARING_LEFT"


## The operator's flattened facing, in world (x, z). Prefer the camera: it
## carries the yaw the body has and nothing the body does not. Fall back to the
## body when the camera is pitched far enough for that projection to collapse.
func _player_forward() -> Vector2:
	if _player == null or not is_instance_valid(_player):
		return Vector2.ZERO
	var flat := Vector2.ZERO
	if is_instance_valid(_camera):
		var eye := -_camera.global_transform.basis.z
		flat = Vector2(eye.x, eye.z)
	if flat.length_squared() < 0.0001:
		var body := -_player.global_transform.basis.z
		flat = Vector2(body.x, body.z)
	return flat.normalized() if flat.length_squared() > 0.0001 else Vector2.ZERO


# --- WHAT THE BUILDING IS DOING TO THE SIGNAL -------------------------------

func _blackout_done() -> bool:
	if _map == null or not is_instance_valid(_map):
		return false
	return bool(_map.get("_blackout_done"))


## How badly the Curator is drowning the net out, 0..1.
##
## Only while it is actually hunting: `active` is false before night 2, between
## incidents and inside a trial, and a compass that died because a hidden,
## inactive mannequin happened to be parked nearby would be a bug the player
## would read as the mechanic working.
func _curator_noise() -> float:
	if not is_instance_valid(_curator):
		_curator = null
		if not is_instance_valid(_enhancements):
			_enhancements = get_tree().get_first_node_in_group("gameplay_enhancements")
		if _enhancements != null:
			_curator = _enhancements.get("_watcher") as Node3D
	if not is_instance_valid(_curator) or _player == null or not is_instance_valid(_player):
		return 0.0
	if not _curator.visible or not bool(_curator.get("active")):
		return 0.0
	var distance := _player.global_position.distance_to(_curator.global_position)
	if distance >= CURATOR_NOISE_RANGE:
		return 0.0
	if distance <= CURATOR_NOISE_DEAD:
		return 1.0
	return clampf(inverse_lerp(CURATOR_NOISE_RANGE, CURATOR_NOISE_DEAD, distance), 0.0, 1.0)


func _reduced_flashes() -> bool:
	var settings := get_tree().get_first_node_in_group("settings_manager")
	return settings != null and bool(settings.get("reduced_flashes"))


func _sfx(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var am := get_tree().get_first_node_in_group("audio_manager")
	if am != null and am.has_method("play_sfx"):
		am.call("play_sfx", sound, volume_db, pitch)


## The shift number, or 0 when nothing in the scene can say. 0 means "do not
## claim to know", and the plan then draws every room as open rather than
## inventing a lock state -- a wing wrongly crossed out is a player who does not
## go through a door that was standing wide open.
func _current_night() -> int:
	if _game == null or not is_instance_valid(_game):
		return 0
	var value: Variant = _game.get("_night")
	return int(value) if typeof(value) == TYPE_INT and int(value) > 0 else 0


func _flat(world: Vector3) -> Vector2:
	return Vector2(world.x, world.z)


# --- ROOM TABLE -------------------------------------------------------------

## Pull the eleven rectangles out of SecurityCameraTablet without instantiating
## or editing it. Prefer the script already loaded on the tablet node in this
## scene, so a scene running a patched tablet is measured against the table that
## tablet is actually using; fall back to the path for a scene with no tablet.
func _load_rooms() -> void:
	_rooms.clear()
	var source: GDScript = null
	if _tablet != null and is_instance_valid(_tablet):
		source = _tablet.get_script() as GDScript
	if source == null and ResourceLoader.exists(ROOM_SOURCE):
		source = load(ROOM_SOURCE) as GDScript
	if source == null:
		push_warning("Compass: room table unavailable (%s did not load)" % ROOM_SOURCE)
		return
	var table: Variant = source.get_script_constant_map().get(ROOM_CONSTANT, null)
	if not (table is Array):
		push_warning("Compass: %s has no usable room table" % ROOM_SOURCE)
		return
	var bounds := Rect2()
	var first := true
	for entry: Variant in table:
		if not (entry is Array):
			continue
		var row: Array = entry
		if row.size() < 3 or not (row[1] is Vector2) or not (row[2] is Vector2):
			continue
		var center: Vector2 = row[1]
		var size: Vector2 = row[2]
		_rooms.append({
			"key": String(row[0]),
			"center": center,
			"half": size * 0.5,
			"area": size.x * size.y,
			"night": int(row[3]) if row.size() > 3 else 1,
		})
		var rect := Rect2(center - size * 0.5, size)
		bounds = rect if first else bounds.merge(rect)
		first = false
	_world_bounds = bounds
	if _rooms.is_empty():
		push_warning("Compass: %s room table was empty" % ROOM_SOURCE)


# --- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "Navigation Aid"
	_layer.layer = HUD_LAYER
	_layer.visible = false
	add_child(_layer)

	# One fixed rect anchored to the bottom-right corner, with the children
	# stacked against its bottom edge. The plan therefore grows upward out of the
	# readouts when it is raised, instead of shoving them off their corner.
	_stack = VBoxContainer.new()
	_stack.name = "Navigation Stack"
	_stack.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_stack.offset_left = -float(PANEL_WIDTH + EDGE_MARGIN)
	_stack.offset_right = -float(EDGE_MARGIN)
	_stack.offset_top = -float(STACK_HEIGHT + BOTTOM_MARGIN)
	_stack.offset_bottom = -float(BOTTOM_MARGIN)
	_stack.alignment = BoxContainer.ALIGNMENT_END
	_stack.add_theme_constant_override("separation", STACK_SEPARATION)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_stack)

	_build_map_panel()
	_build_bearing_panel()
	_build_room_panel()


## HUD-sized surface. UITheme.apply_panel() is deliberately not used: it hands
## back panel_raised(), whose PAD+4 content margins would inflate these fixed
## widths. Same tokens, tighter, exactly as PlayerController's stamina panel
## already does for the same reason.
func _surface() -> StyleBoxFlat:
	return UITheme.stylebox(UITheme.SURFACE_RAISED, UITheme.BORDER,
		UITheme.BORDER_WIDTH, UITheme.RADIUS_SM)


func _panel_container(node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _surface())
	return panel


func _build_map_panel() -> void:
	_map_panel = _panel_container("Floor Plan")
	_map_panel.visible = false
	_stack.add_child(_map_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_panel.add_child(box)

	_map_title = Label.new()
	UITheme.apply_text(_map_title, UITheme.CAPTION, UITheme.MUTED)
	_map_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_map_title)

	_map_view = Control.new()
	_map_view.name = "Plan View"
	_map_view.custom_minimum_size = MAP_VIEW
	_map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_view.draw.connect(_draw_map)
	box.add_child(_map_view)


func _build_bearing_panel() -> void:
	_bearing_panel = _panel_container("Bearing")
	_stack.add_child(_bearing_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bearing_panel.add_child(row)

	_arrow = Control.new()
	_arrow.name = "Heading Arrow"
	_arrow.custom_minimum_size = Vector2(ARROW_BOX, ARROW_BOX)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.draw.connect(_draw_arrow)
	row.add_child(_arrow)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)

	_bearing_caption = Label.new()
	UITheme.apply_text(_bearing_caption, UITheme.CAPTION, UITheme.MUTED)
	_bearing_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_bearing_caption)

	_bearing_label = Label.new()
	_bearing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text(_bearing_label, UITheme.LABEL, UITheme.ON_SURFACE)
	_bearing_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_bearing_label)


func _build_room_panel() -> void:
	_room_panel = _panel_container("Room Readout")
	_stack.add_child(_room_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room_panel.add_child(box)

	_room_caption = Label.new()
	UITheme.apply_text(_room_caption, UITheme.CAPTION, UITheme.MUTED)
	_room_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_room_caption)

	_room_label = Label.new()
	_room_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text(_room_label, UITheme.SECTION, UITheme.ACCENT)
	_room_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_room_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.visible = false
	UITheme.apply_text(_status_label, UITheme.CAPTION, UITheme.WARNING)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_status_label)

	_map_hint = Label.new()
	UITheme.apply_text(_map_hint, UITheme.CAPTION, UITheme.MUTED)
	_map_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_map_hint)


## Text that does not depend on the frame. Re-run on a language change, because
## SettingsManager swaps the locale live and a caption written once at scene
## build would keep the language the player just left.
func _refresh_static_text() -> void:
	if _map_title != null:
		_map_title.text = tr("COMPASS_MAP_TITLE")
	if _bearing_caption != null:
		_bearing_caption.text = tr("COMPASS_CAPTION_HEADING")
	if _room_caption != null:
		_room_caption.text = tr("COMPASS_CAPTION_POSITION")
	if _map_hint != null:
		_map_hint.text = tr("COMPASS_MAP_HINT")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_static_text()


# --- PER-FRAME TEXT ---------------------------------------------------------

func _update_panels() -> void:
	_room_panel.visible = _room_enabled
	_map_panel.visible = _minimap_enabled and _map_held
	_bearing_panel.visible = _bearing_enabled and _has_target and _band != SIGNAL_DOWN

	if _room_enabled:
		_room_label.text = _room_text()
		_status_label.visible = _band != SIGNAL_CLEAR
		if _band == SIGNAL_WEAK:
			_status_label.text = tr("COMPASS_SIGNAL_WEAK")
		elif _band == SIGNAL_DOWN:
			_status_label.text = tr("COMPASS_SIGNAL_LOST")
		_map_hint.visible = _minimap_enabled and not _map_held

	if _bearing_panel.visible:
		_bearing_label.text = _bearing_text()
		_arrow.queue_redraw()


func _room_text() -> String:
	if _rooms.is_empty():
		return tr("COMPASS_ROOM_UNKNOWN")
	if _band == SIGNAL_DOWN:
		if _last_fix_key == "":
			return tr("COMPASS_ROOM_UNKNOWN")
		return Loc.fmt("COMPASS_ROOM_STALE", [tr(_last_fix_key)])
	if _room_key == "":
		return tr("COMPASS_ROOM_UNKNOWN")
	return tr(_room_key)


## Destination, sector and range on one line -- and the range is the first thing
## the building stops being able to tell you. On a degraded net the sector
## survives (it is one of four answers and the error is smaller than a quarter
## turn) while the metre count does not, so it is simply absent rather than
## printed wrong.
func _bearing_text() -> String:
	var sector := tr(_bearing_key())
	var line := sector
	if _band == SIGNAL_CLEAR and _player != null and is_instance_valid(_player):
		var metres := maxi(1, int(round(
			_flat(_target).distance_to(_flat(_player.global_position)))))
		line = Loc.fmt("COMPASS_BEARING", [sector, metres])
	if _target_room != "":
		return "%s\n%s" % [tr(_target_room), line]
	return line


# --- DRAWING ----------------------------------------------------------------

## Needle. Rotation carries the precise angle for anyone who can read it; the
## label beside it carries the same angle as one of four sentences for anyone
## who cannot. Neither is the only channel.
func _draw_arrow() -> void:
	if _arrow == null:
		return
	var middle := _arrow.size * 0.5
	var reach := minf(middle.x, middle.y) - 2.0
	if reach <= 0.0:
		return
	var shape: Array[Vector2] = [
		Vector2(0.0, -reach),
		Vector2(reach * 0.66, reach * 0.62),
		Vector2(0.0, reach * 0.22),
		Vector2(-reach * 0.66, reach * 0.62),
	]
	var points := PackedVector2Array()
	for point: Vector2 in shape:
		points.append(middle + point.rotated(_arrow_angle))
	_arrow.draw_colored_polygon(points, _arrow_color)
	# Outline in the page surface, the same trick GameplayEnhancements uses on
	# its panel-less readout: it keeps the silhouette of the needle legible where
	# it crosses its own fill colour.
	var closed := points.duplicate()
	closed.append(points[0])
	_arrow.draw_polyline(closed, UITheme.SURFACE, 1.0, true)


## Eleven rectangles, the operator, and the destination. No route is drawn and
## none is computed: this is the plan on the wall, not a satnav.
func _draw_map() -> void:
	if _map_view == null or _rooms.is_empty():
		return
	var view := _map_view.size
	if view.x <= 0.0 or view.y <= 0.0 \
			or _world_bounds.size.x <= 0.0 or _world_bounds.size.y <= 0.0:
		return
	# Pixels per metre, and the offset that centres the plan in the viewport.
	var fit := minf((view.x - MAP_INSET * 2.0) / _world_bounds.size.x,
		(view.y - MAP_INSET * 2.0) / _world_bounds.size.y)
	if fit <= 0.0:
		return
	var origin := (view - _world_bounds.size * fit) * 0.5 - _world_bounds.position * fit
	var font := _map_view.get_theme_default_font()
	var night := _current_night()

	for room: Dictionary in _rooms:
		var center: Vector2 = room["center"]
		var half: Vector2 = room["half"]
		var rect := Rect2(origin + (center - half) * fit, half * 2.0 * fit)
		var is_here := _band != SIGNAL_DOWN and String(room["key"]) == _room_key
		var sealed_off := night > 0 and night < int(room["night"])
		if is_here:
			_map_view.draw_rect(rect, UITheme.ACCENT_FILL, true)
		_map_view.draw_rect(rect,
			UITheme.DANGER if sealed_off else (UITheme.ACCENT if is_here else UITheme.BORDER),
			false, 1.0)
		if sealed_off:
			# A cross, not a colour. A player who cannot separate the red border
			# from the grey one still sees that the room is struck out.
			_map_view.draw_line(rect.position, rect.position + rect.size,
				UITheme.DANGER, 1.0, true)
			_map_view.draw_line(rect.position + Vector2(rect.size.x, 0.0),
				rect.position + Vector2(0.0, rect.size.y), UITheme.DANGER, 1.0, true)

	if _band == SIGNAL_DOWN:
		# The plan is a printed thing and survives the outage; the two live
		# marks on it do not. Knowing the shape of the building without knowing
		# your place in it is exactly the state the net going down leaves you in.
		return

	if _has_target:
		var spot := origin + _flat(_target) * fit
		_map_view.draw_arc(spot, MAP_TARGET_RADIUS, 0.0, TAU, 16, UITheme.WARNING, 2.0, true)
		_map_label(font, spot + Vector2(MAP_TARGET_RADIUS + 3.0, 4.0),
			tr("COMPASS_CAPTION_HEADING"), UITheme.WARNING, view)

	if _player != null and is_instance_valid(_player):
		var here := origin + _flat(_player.global_position) * fit
		var forward := _player_forward()
		# The map is drawn north-up, matching the tablet's: world +X to the
		# right, world +Z downward. A facing of (fx, fz) therefore lands on
		# screen as (fx, fz) with no further conversion.
		var heading := forward if forward != Vector2.ZERO else Vector2(0.0, -1.0)
		var side := Vector2(-heading.y, heading.x)
		var nose := here + heading * (MAP_PLAYER_RADIUS + 2.0)
		_map_view.draw_colored_polygon(PackedVector2Array([
			nose,
			here + side * MAP_PLAYER_RADIUS * 0.8 - heading * MAP_PLAYER_RADIUS * 0.6,
			here - side * MAP_PLAYER_RADIUS * 0.8 - heading * MAP_PLAYER_RADIUS * 0.6,
		]), UITheme.ACCENT)
		_map_label(font, here + Vector2(MAP_PLAYER_RADIUS + 3.0, 4.0),
			tr("COMPASS_LEGEND_YOU"), UITheme.ON_SURFACE, view)


## Caption for a marker, nudged back inside the viewport when the marker is near
## an edge so the word is never half-drawn off the panel.
func _map_label(font: Font, at: Vector2, text: String, color: Color, view: Vector2) -> void:
	if font == null or text == "":
		return
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		UITheme.CAPTION).x
	if width < MAP_LABEL_MIN_WIDTH:
		width = MAP_LABEL_MIN_WIDTH
	var spot := Vector2(minf(at.x, view.x - width - 2.0), clampf(at.y, 12.0, view.y - 2.0))
	_map_view.draw_string(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		UITheme.CAPTION, color)


# --- INPUT ------------------------------------------------------------------

## Register the hold-to-open binding if nothing has yet. Shaped exactly like
## InputBootstrap._add_action so the two cannot fight: whichever runs first
## creates the action, the other adds nothing, and a player-rebound key is left
## alone because the events are only appended when they are absent.
func _ensure_map_action() -> void:
	if not InputMap.has_action(MAP_ACTION):
		InputMap.add_action(MAP_ACTION, 0.22)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_M
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_BACK
	for event: InputEvent in [key, pad]:
		if not InputMap.action_has_event(MAP_ACTION, event):
			InputMap.action_add_event(MAP_ACTION, event)
