class_name NavigationDirector
extends Node
## Puts the Observer's compass into a scene and owns the one number the compass
## cannot work out for itself.
##
## game/Compass.gd is a complete feature that nothing instantiated. It finds the
## player, the map, the tablet and GameManager on its own, so it needs no wiring
## beyond existing -- but a plain Node with a script attached is not something a
## caller can conjure in one line, and the two scenes that want it are owned by
## other files. This node is that one line:
##
##     NavigationDirector.install(self)
##
## It is idempotent, it may be called from _ready() or from a build step, and it
## returns the director so the caller can configure the readout:
##
##     var nav := NavigationDirector.install(self)
##     nav.set_features(false, true, false)          # bearing only
##     nav.aim_at(Vector3(4.5, 1.0, -10), "TUT_TARGET_CONSOLE")
##
## WHERE THE COMPASS NODE GOES, AND WHY IT IS NOT A CHILD OF THIS ONE
##
## Compass._initialize() resolves GameManager and SecurityCameraTablet with
## `get_parent().get_node_or_null(...)`, exactly the way SecurityCameraTablet
## resolves its own siblings. So the compass has to be a SIBLING of GameManager,
## i.e. a direct child of the scene root -- parenting it under this director
## would silently cost it the game state and the room table both. The director
## therefore adds it to its own parent, not to itself, and every call the
## director makes goes through that node rather than through a second copy of
## the compass's logic.
##
##
## WHAT THIS FILE ADDS TO set_disturbance(), AND WHAT IT DELIBERATELY DOES NOT
##
## Compass.signal_quality() already models two of the three things that break the
## museum's wayfinding net, and it models them from primary sources:
##
##   * the blackout  -- Compass._blackout_done() reads FirstMuseumMap's own
##     `_blackout_done` flag and applies BLACKOUT_NOISE (0.45) everywhere outside
##     the security office;
##   * the Curator   -- Compass._curator_noise() reads GameplayEnhancements'
##     `_watcher`, checks that it is visible and `active`, and ramps 0 -> 1
##     between CURATOR_NOISE_RANGE (27 m) and CURATOR_NOISE_DEAD (9 m).
##
## Both are applied with maxf() on top of whatever set_disturbance() holds, so
## restating either of them here would be either a no-op (same number) or a
## second, disagreeing source of truth for a value the compass already owns. The
## contract in Compass's header is explicit that set_disturbance() is a FLOOR for
## reasons the building itself cannot see -- "an anomaly, a scripted beat" -- so
## that is the only thing this director puts into it:
##
##   BREACH PRESSURE. While the shift is inside a containment breach the net is
##   fighting the same failure the core is. The floor ramps from
##   BREACH_NOISE_MIN at the moment the timer starts to BREACH_NOISE_MAX as it
##   runs out, so the range on the readout is the first thing the player loses
##   when they are running late -- and unlike the blackout term, this one is NOT
##   lifted by standing in the office, because the breach is upstream of the
##   office's own hardware.
##
##   NIGHT WEAR. A small per-night floor: the building is three nights further
##   into failing on night 3 than it was on night 1. Capped well inside the CLEAR
##   band so it never degrades anything on its own.
##
##   A SCRIPTED FLOOR. set_scripted_disturbance() for a cutscene or a beat that
##   wants the net down for a reason no rule here models. Held until it is
##   cleared, and combined with maxf like everything else, so a caller cannot
##   accidentally make the readout MORE reliable than the night is.
##
## The director writes the compass's disturbance every frame, which is why it is
## the single owner of that value: a caller that reached past it and called
## Compass.set_disturbance() directly would be overwritten on the next frame.
## set_scripted_disturbance() is the supported way in.
##
##
## ACCESSIBILITY
##
## Nothing here draws, animates or takes focus; it moves one float. Every visible
## consequence is drawn by Compass, whose own header tabulates its contrast and
## whose degradation already has a static form under
## SettingsManager.reduced_flashes. The one thing this file owes that promise is
## restraint in how fast the floor moves: BREACH pressure tracks the shift clock,
## which is a monotonic ramp over minutes, so it can never read as a flicker and
## it crosses a band boundary at most once per incident.

## The feature this director installs. Loaded, never edited.
const COMPASS_SCRIPT := "res://game/Compass.gd"
## Node names, so install() and _initialize() cannot disagree about them and so a
## second install() finds what the first one built.
const COMPASS_NODE := "Compass"
const DIRECTOR_NODE := "NavigationDirector"

## Everything the director calls on the compass. Checked once, on adoption: a
## scene running a patched or stubbed compass is dropped with a warning instead
## of throwing a different missing-method error on every frame.
const COMPASS_API: Array[String] = [
	"set_disturbance", "set_enabled", "set_room_readout_enabled",
	"set_bearing_enabled", "set_minimap_enabled", "set_objective_target",
	"clear_objective_target",
]

# GameManager states, mirrored the same way Compass mirrors them: read only, and
# only the ones this file branches on. GameManager owns the values.
const STATE_ANOMALY := 2

## Floor at the moment a breach opens, and the floor as its timer expires.
##
## Compass.BAND_CLEAR is 0.66, i.e. the readout leaves the CLEAR band at a
## disturbance of 0.34. MIN therefore changes nothing on its own and MAX drops
## the net to DEGRADED -- the sector survives, the metre count does not -- over
## roughly the last 55% of the shift clock. It stops short of Compass.BAND_WEAK's
## 0.70 on purpose: a breach must never kill the readout outright, because that
## is the Curator's signature and the two must stay distinguishable.
const BREACH_NOISE_MIN := 0.10
const BREACH_NOISE_MAX := 0.55

## Per-night wear, and the ceiling on it. 0.06 a night, so night 3 contributes
## 0.12 -- a third of the way to the DEGRADED boundary, visible only when it is
## stacked under something else, which is the point of a floor.
const NIGHT_NOISE_STEP := 0.06
const NIGHT_NOISE_MAX := 0.18

var _compass: Node = null
var _game: Node = null

# Wishes. Every public setter records here first and pushes to the compass
# second, so a caller may configure the readout in the same frame it installs the
# director -- before the compass node exists -- and get what it asked for.
var _want_enabled := true
var _want_room := true
var _want_bearing := true
var _want_minimap := true
var _aim_active := false
var _aim_point := Vector3.ZERO
var _aim_room := ""
var _scripted := 0.0

## Longest `_time_left` seen inside the current breach, which is the length of
## this incident's clock. Measured rather than read out of GameManager's
## NIGHT_CONFIG: the timer is also shortened by the test console and by a retry,
## and a floor computed against the wrong span would jump.
var _breach_span := 0.0


## Create the director (and, on its first frame, the compass) under `host`.
## Returns the existing director when there already is one, so a caller may call
## this from a _ready() that runs again after an editor reload or a scene reset.
static func install(host: Node) -> NavigationDirector:
	if host == null or not is_instance_valid(host):
		return null
	var existing := host.get_node_or_null(NodePath(DIRECTOR_NODE)) as NavigationDirector
	if existing != null:
		return existing
	var director := NavigationDirector.new()
	director.name = DIRECTOR_NODE
	host.add_child(director)
	return director


func _ready() -> void:
	add_to_group("navigation_director")
	# The map, the player and every manager are generated at runtime, and the
	# compass then waits two more frames for the same reason. Deferred so this
	# node never builds anything during its own parent's _ready().
	call_deferred("_initialize")


func _initialize() -> void:
	if not is_inside_tree():
		return
	var host := get_parent()
	if host == null:
		push_warning("NavigationDirector: no parent to install the compass into")
		return
	_game = host.get_node_or_null("GameManager")
	_adopt(host.get_node_or_null(NodePath(COMPASS_NODE)))
	if _compass == null:
		_adopt(_build_compass(host))
	_apply_wishes()


## Take ownership of a compass node, after checking it can do the job.
func _adopt(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	for method: String in COMPASS_API:
		if not node.has_method(method):
			push_warning("NavigationDirector: %s has no %s(); leaving it alone"
				% [node.name, method])
			return
	_compass = node


func _build_compass(host: Node) -> Node:
	if not ResourceLoader.exists(COMPASS_SCRIPT):
		push_warning("NavigationDirector: %s is missing" % COMPASS_SCRIPT)
		return null
	var script := load(COMPASS_SCRIPT) as GDScript
	if script == null:
		push_warning("NavigationDirector: %s did not load" % COMPASS_SCRIPT)
		return null
	var node := Node.new()
	node.name = COMPASS_NODE
	# Script first: add_child() runs _ready(), and a Node that reaches its own
	# _ready() without the script has no _ready() to run and never initialises.
	node.set_script(script)
	host.add_child(node)
	return node


# --- PUBLIC API ---------------------------------------------------------------

## The compass node, or null while it is still being built or could not be. Read
## it for state; write through this director, not through it.
func compass() -> Node:
	return _compass if is_instance_valid(_compass) else null


## Everything off in one call, for a cutscene or a full-screen page that has no
## business having a bearing drawn across it. Independent of set_features().
func set_enabled(value: bool) -> void:
	_want_enabled = value
	_apply_wishes()


## The three readouts, in the order Compass's header lists them: the room name,
## the objective arrow, the held-open floor plan. A scene whose room table is not
## the museum's -- the orientation sector, a pocket dimension -- should pass
## `room` and `minimap` false: the plan the compass reads belongs to the museum,
## and naming a museum room while the player stands somewhere else is worse than
## printing nothing.
func set_features(room: bool, bearing: bool, minimap: bool) -> void:
	_want_room = room
	_want_bearing = bearing
	_want_minimap = minimap
	_apply_wishes()


## Point the arrow at an explicit place instead of at whatever the night loop
## would have chosen. `room_key` is a catalogue key naming the destination; leave
## it empty and the compass names it after whichever mapped room contains it.
func aim_at(world_position: Vector3, room_key: String = "") -> void:
	_aim_active = true
	_aim_point = world_position
	_aim_room = room_key
	_apply_wishes()


## Hand targeting back to the night loop.
func release_aim() -> void:
	if not _aim_active:
		return
	_aim_active = false
	_aim_room = ""
	_apply_wishes()


## A held floor under the net, 0..1, for a beat no rule in this file models.
## Combined with maxf like every other term, so it can only ever make the readout
## worse. Survives until clear_scripted_disturbance().
func set_scripted_disturbance(level: float) -> void:
	_scripted = clampf(level, 0.0, 1.0)


func clear_scripted_disturbance() -> void:
	_scripted = 0.0


# --- FRAME --------------------------------------------------------------------

func _process(_delta: float) -> void:
	_track_breach()
	if not is_instance_valid(_compass):
		return
	_compass.call("set_disturbance", building_noise())


## Remember how long this incident's clock was when it started. Kept out of
## building_noise() so that stays a pure read: a caller asking what the floor is
## must not be able to change it by asking.
func _track_breach() -> void:
	if not is_instance_valid(_game) or int(_game.get("_state")) != STATE_ANOMALY:
		_breach_span = 0.0
		return
	_breach_span = maxf(_breach_span, maxf(float(_game.get("_time_left")), 0.0))


## How badly the building itself is jamming its own wayfinding net, 0..1.
## Public so a test or a debug readout can ask without duplicating the rules.
func building_noise() -> float:
	var noise := _scripted
	if not is_instance_valid(_game):
		# No night loop in this scene -- the orientation sector, a standalone
		# probe. Nothing here claims the building is failing.
		return clampf(noise, 0.0, 1.0)
	noise = maxf(noise, _night_wear())
	if int(_game.get("_state")) == STATE_ANOMALY:
		noise = maxf(noise, _breach_pressure())
	return clampf(noise, 0.0, 1.0)


func _night_wear() -> float:
	var night := int(_game.get("_night"))
	if night <= 1:
		return 0.0
	return minf(float(night - 1) * NIGHT_NOISE_STEP, NIGHT_NOISE_MAX)


## Ramps with the shift clock rather than with wall time, so a shorter night
## degrades over the same fraction of itself and the test console's shortened
## timers do not read as a stuck floor.
func _breach_pressure() -> float:
	if _breach_span <= 0.0:
		return BREACH_NOISE_MIN
	var left := maxf(float(_game.get("_time_left")), 0.0)
	var spent := clampf(1.0 - left / _breach_span, 0.0, 1.0)
	return lerpf(BREACH_NOISE_MIN, BREACH_NOISE_MAX, spent)


# --- WISHES -------------------------------------------------------------------

func _apply_wishes() -> void:
	if not is_instance_valid(_compass):
		return
	_compass.call("set_enabled", _want_enabled)
	_compass.call("set_room_readout_enabled", _want_room)
	_compass.call("set_bearing_enabled", _want_bearing)
	_compass.call("set_minimap_enabled", _want_minimap)
	if _aim_active:
		_compass.call("set_objective_target", _aim_point, _aim_room)
	else:
		_compass.call("clear_objective_target")
