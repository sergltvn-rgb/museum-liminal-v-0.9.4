extends Node3D

## The six monitors on the office wall, made live.
##
## Stage 10.3. OfficeProps.build_monitor_bank() already builds the installation --
## rail, six housings, six screen panels, timestamp strips, tally lamps, cable
## trough -- and one of those panels is deliberately dead. This node is the thing
## that puts PICTURES on the five that are not, and it does so by borrowing the
## tablet's feeds rather than by building cameras of its own.
##
## ONE TEXTURE, TWO CONSUMERS. SecurityCameraTablet.feed_texture(i) hands back
## the SubViewport texture of feed i and registers a standing request to keep it
## drawn; release_feed(i) gives it back. A panel here and the tablet in the
## player's hands showing the same post therefore show the SAME texture, not two
## renders of one room -- which is both the cheap way and the honest one: the
## wall cannot disagree with the handheld about what CAM 05 is looking at.
##
## COST. Five live feeds at 256x192 and 9 Hz is 45 redraws a second against a
## budget of FEED_BUDGET_PER_FRAME * 60 = 120, so the wall never starves the
## tablet's own feed. It is still not free, so the wall only asks for pictures
## while the operator is IN the office and FACING the bank (see _wants_feeds).
## Walk out and every feed is released; the panels keep their last drawn frame,
## which on a security monitor reads as a security monitor and not as a bug.
##
## NO CAMERA-IN-CAMERA. The feed quads sit on CCTV_HIDDEN_LAYER, so CAM 04 --
## which hangs at (-33.8, 2.9, -5.8) and looks straight at this wall -- sees the
## dark screen panels underneath them instead of a monitor showing a monitor
## showing a monitor. The office feed shows a bank of switched-off screens, which
## is what a camera pointed at a CCTV wall in a dark room should show.

## The screen panels OfficeProps builds sit at local z 0.139; the feed quad goes
## just in front so it covers the panel without z-fighting it.
const FEED_Z_OFFSET := 0.004
## Picture size on the wall. The panel behind it is 0.46 x 0.32, and the feed is
## 4:3, so the quad is inset to keep the aspect ratio the SubViewport renders.
const FEED_SIZE := Vector2(0.4267, 0.32)
## Mirrors FirstMuseumMap.CCTV_HIDDEN_LAYER / SecurityCameraTablet's own copy.
const CCTV_HIDDEN_LAYER := 20

## Name of the tablet constant this file reads its post list out of. Single
## quotes on purpose, exactly as Compass.ROOM_CONSTANT does it: the localization
## sweep treats any DOUBLE-quoted UPPER_SNAKE literal as a translation key, and
## 'CAMS' is a constant name, not a string the player ever reads.
const FEED_TABLE_CONSTANT := 'CAMS'

## Which post each panel carries. Panel indices are row-major from the BOTTOM row
## as build_monitor_bank numbers them, so 0..2 is the lower row left to right and
## 3..5 the upper one. Values are indices into SecurityCameraTablet.CAMS.
##
## The layout is by WING, not by post number, because the operator reads this
## wall as a floor plan and not as a list: the lower row is the way in and the
## room the player crosses twenty times a night (Entrance, Atrium), the upper row
## is the three wings that hold exhibits (A gravity, B time, D mass).
##
## Panel 2 -- the one build_monitor_bank knocks three degrees out of true and
## leaves dark -- carries Space Wing C. That is the point of the dead screen: the
## wing sealed behind a blast door until night two is ALSO the wing the operator
## cannot see, and the label plate under the dark glass says which one it is.
const PANEL_FEEDS := [0, 1, 6, 4, 5, 10]

## How close the operator must be to the wall before the feeds are worth drawing.
## Measured from the bank's own origin, which is the base of the monitor wall.
const WATCH_RADIUS := 7.0
## And how much of a glance counts as facing it: the player's look direction
## against the wall's outward normal. -0.15 is a wide cone (99 deg off axis) --
## the operator turning their head to the desk must not switch the wall off.
const WATCH_FACING_DOT := -0.15
## Hysteresis on the radius so a player pacing the room does not thrash five
## SubViewports on and off every second stride.
const WATCH_RELEASE_MARGIN := 1.5

## Angular tolerance for "the operator is looking AT this panel", used by the
## scan in GameplayEnhancements. 9 degrees at 2 m is a 0.31 m circle on the
## wall, which is inside one 0.52 m housing and cannot claim its neighbour.
const WATCH_PANEL_ANGLE_DEG := 9.0
## Beyond this the panels are scenery, not something being read.
const WATCH_PANEL_RANGE := 4.5

## Tally-lamp breathing period. A SMOOTH fade, never a blink: the REC lamp is
## the one light on this wall that is on for the whole shift, and a hard blink at
## eye height for eleven minutes is exactly what the flash-reduction setting
## exists to stop. Slow enough to read as recording, monotone enough to ignore.
const TALLY_PERIOD := 2.4
const TALLY_ENERGY_MIN := 0.55
const TALLY_ENERGY_MAX := 1.65

var _bank: Node3D = null
var _tablet: Node = null
var _player: CharacterBody3D = null
var _player_camera: Camera3D = null

## Feed quads by panel index, in the order PANEL_FEEDS names them.
var _screens: Array[MeshInstance3D] = []
## Feed index each quad shows, index-aligned with _screens. -1 for the dead panel.
var _screen_feeds: Array[int] = []
## Tally lamp meshes, index-aligned with _screens.
var _tallies: Array[MeshInstance3D] = []
var _tally_materials: Array[StandardMaterial3D] = []

var _holding := false
var _phase := 0.0
var _built := false


func _ready() -> void:
	# Found by group, the way every other cross-file consumer in this project
	# finds a node it does not own: GameplayEnhancements' scan asks this wall what
	# the operator is looking at, and the test suite asks it which feeds it holds.
	add_to_group("monitor_wall")
	set_process(true)
	# PROCESS_MODE_ALWAYS is about ASSEMBLY, not animation. The map is generated
	# while the tree is paused -- the menu is up before the first unpaused frame --
	# so an inheriting node here gets can_process() == false and the retry below
	# never runs once: measured, the wall sat in its group forever with no bank, no
	# tablet and no pictures. The pause is honoured explicitly in _process instead,
	# so a paused game still shows a frozen bank rather than a shimmering one.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The live bank hums: a 10 s steady cut of guitar pickup interference, baked
	# at -28.0 dBFS RMS. At -10 dB it is a whisper you hear standing at the
	# screens; mains-powered, so the blackout cuts it with the lights.
	var hum := AudioStreamPlayer3D.new()
	hum.name = "Monitor Hum"
	hum.position = Vector3(0.0, 1.4, 0.15)
	hum.unit_size = 1.8
	hum.max_distance = 4.0
	hum.volume_db = -10.0
	hum.bus = "Ambience"
	hum.stream = load("res://audio/monitor_static.wav")
	if hum.stream is AudioStreamWAV:
		(hum.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		hum.autoplay = true
		hum.add_to_group("lamp_hum")
		add_child(hum)


func _process(delta: float) -> void:
	if not _built:
		# Built in _process and not in _ready for the same reason the docked tablet
		# is: the map creates the player, the bank and this node in one frame, in an
		# order this file does not get to choose, so the first _ready() here can run
		# before any of them exist. Retried once a frame until it takes.
		_try_build()
		return
	if get_tree().paused:
		# Assembly is allowed while paused; motion is not. The feeds themselves are
		# driven by the tablet, which pauses normally, so a paused bank holds the
		# last frame it rendered -- which is what a paused game should look like.
		return
	_phase += delta
	_update_holding()
	_update_tallies()


func _exit_tree() -> void:
	_release_all()


# --- CONSTRUCTION -----------------------------------------------------------

func _try_build() -> void:
	if _bank == null or not is_instance_valid(_bank):
		_bank = get_tree().get_first_node_in_group("monitor_bank") as Node3D
		if _bank == null:
			return
	if _tablet == null or not is_instance_valid(_tablet):
		_tablet = _find_tablet()
		if _tablet == null:
			return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		if _player == null:
			return
	_player_camera = _player.get_node_or_null("Player Camera") as Camera3D
	_build_screens()
	_built = true


## The tablet lives beside GameManager at the root of the scene, while this node
## hangs inside the generated map, so the sideways lookup Compass and
## GameplayEnhancements use (`get_parent().get_node_or_null(...)`) does not reach
## it from here. The scene root does.
func _find_tablet() -> Node:
	var scene := get_tree().current_scene
	if scene != null:
		var found := scene.get_node_or_null("SecurityCameraTablet")
		if found != null:
			return found
	var walk: Node = get_parent()
	while walk != null:
		var sibling := walk.get_node_or_null("SecurityCameraTablet")
		if sibling != null:
			return sibling
		walk = walk.get_parent()
	return null


func _build_screens() -> void:
	var dead_panel := int(_bank.get_meta("dead_panel", -1))
	var panels := int(_bank.get_meta("panels", 0))
	var feed_count := _feed_count()
	for panel in range(mini(panels, PANEL_FEEDS.size())):
		var anchor := _bank.get_node_or_null("Monitor Screen %d" % panel) as MeshInstance3D
		if anchor == null:
			continue
		var feed_index: int = PANEL_FEEDS[panel]
		var live := panel != dead_panel and feed_index >= 0 and feed_index < feed_count
		_label_panel(anchor, panel, feed_index)
		var tally := _bank.get_node_or_null("Monitor Tally %d" % panel) as MeshInstance3D
		if live and tally != null:
			_tallies.append(tally)
			_tally_materials.append(_own_material(tally))
		if not live:
			# The dead panel keeps its dark glass and its three-degree tilt, and it
			# never asks the tablet for a feed. It is still labelled, so the room
			# says WHICH camera the operator has lost.
			continue
		_screens.append(_feed_quad(anchor, panel))
		_screen_feeds.append(feed_index)


## One unshaded quad in front of a screen panel, carrying that feed's texture.
func _feed_quad(anchor: MeshInstance3D, panel: int) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = FEED_SIZE
	var quad := MeshInstance3D.new()
	quad.name = "Monitor Feed %d" % panel
	quad.mesh = mesh
	quad.position = anchor.position + Vector3(0, 0, FEED_Z_OFFSET)
	# Inherit the dead panel's trick in reverse: a live housing is square to the
	# wall, so the quad copies the housing's own rotation and nothing else.
	quad.rotation = anchor.rotation
	quad.layers = 1 << (CCTV_HIDDEN_LAYER - 1)
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	# Unshaded: the picture is a light source in the fiction, and the office is
	# dark. Фильтрация линейная: фид теперь 768x576 (SecurityCameraTablet.FEED_SIZE),
	# и nearest на маленьком настенном экране давал бы только алиасинг, а не
	# крупный честный пиксель.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.albedo_color = Color(0.82, 0.92, 0.88)
	quad.material_override = material
	_bank.add_child(quad)
	return quad


## Post number and room name under the glass, on the CCTV-hidden layer so the
## office feed does not show a wall of floating text. The room name is the
## catalogue row the tablet already prints for that feed -- tr() of CAMS[i].label
## -- so this adds no new string to localization/game.csv.
func _label_panel(anchor: MeshInstance3D, panel: int, feed_index: int) -> void:
	var cams: Array = _cams()
	if feed_index < 0 or feed_index >= cams.size():
		return
	var row: Dictionary = cams[feed_index]
	var label := Label3D.new()
	label.name = "Monitor Caption %d" % panel
	label.text = "%s  %s" % [str(row.get("id", "")), tr(str(row.get("label", "")))]
	label.position = anchor.position + Vector3(0.0, -0.235, 0.002)
	label.rotation = anchor.rotation
	label.modulate = Color(0.62, 0.86, 0.70)
	label.font_size = 34
	label.pixel_size = 0.00085
	# Flat, never billboarded: a swivelling caption is the exact failure
	# CCTV_HIDDEN_LAYER was introduced for, and this one is readable head-on.
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.outline_size = 5
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	label.width = 0.50 / 0.00085
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.layers = 1 << (CCTV_HIDDEN_LAYER - 1)
	label.visibility_range_end = 12.0
	label.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_bank.add_child(label)


## OfficeProps shares one material across every prop it builds, so the tally
## lamps cannot be animated through it without pulsing every LED in the museum.
## This gives one lamp its own copy.
func _own_material(node: MeshInstance3D) -> StandardMaterial3D:
	var source := node.get_active_material(0) as StandardMaterial3D
	var copy: StandardMaterial3D
	if source != null:
		copy = source.duplicate() as StandardMaterial3D
	else:
		copy = StandardMaterial3D.new()
		copy.albedo_color = Color(0.85, 0.10, 0.07)
		copy.emission_enabled = true
		copy.emission = Color(0.85, 0.10, 0.07)
	node.material_override = copy
	return copy


# --- FEED HOLDING -----------------------------------------------------------

## Ask for pictures while the operator can see them, give them back otherwise.
func _update_holding() -> void:
	var want := _wants_feeds()
	if want == _holding:
		if want:
			_refresh_textures()
		return
	_holding = want
	if want:
		_refresh_textures()
	else:
		_release_all()


func _wants_feeds() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var reach := WATCH_RADIUS + (WATCH_RELEASE_MARGIN if _holding else 0.0)
	if _bank.global_position.distance_to(_player.global_position) > reach:
		return false
	if _player_camera == null or not is_instance_valid(_player_camera):
		return true
	# The wall's outward normal is its own +Z, whatever yaw the room was built at.
	var normal := _bank.global_transform.basis.z.normalized()
	var look := -_player_camera.global_transform.basis.z.normalized()
	return look.dot(normal) <= WATCH_FACING_DOT


## Take (or re-take) every feed this wall shows. feed_texture() is idempotent --
## it sets a holder flag and returns the same SubViewport texture -- so calling
## it while already holding costs a dictionary write and keeps the wall correct
## across a tablet that rebuilt its viewports.
func _refresh_textures() -> void:
	if _tablet == null or not is_instance_valid(_tablet):
		return
	for i in range(_screens.size()):
		var quad := _screens[i]
		if not is_instance_valid(quad):
			continue
		var texture: Texture2D = _tablet.call("feed_texture", _screen_feeds[i])
		var material := quad.material_override as StandardMaterial3D
		if material != null and material.albedo_texture != texture:
			material.albedo_texture = texture


func _release_all() -> void:
	if _tablet == null or not is_instance_valid(_tablet):
		return
	for feed_index in _screen_feeds:
		_tablet.call("release_feed", feed_index)


func _update_tallies() -> void:
	var wave := 0.5 + 0.5 * sin(TAU * _phase / TALLY_PERIOD)
	var energy: float = TALLY_ENERGY_MIN + (TALLY_ENERGY_MAX - TALLY_ENERGY_MIN) * wave
	for material in _tally_materials:
		if material != null:
			material.emission_energy_multiplier = energy


# --- PUBLIC CONTRACT --------------------------------------------------------

## The feed the operator is reading off this wall right now, as an index into
## SecurityCameraTablet.CAMS, or -1.
##
## This is what lets the night-two source scan be satisfied from the WALL and not
## only from the raised tablet (GameplayEnhancements._update_scan). Confirming a
## camera by walking to the office and looking at the monitor that shows it is
## the same act as holding the handheld up to it, and the room already asked the
## player to be here.
func watched_feed() -> int:
	if not _built or not _holding:
		return -1
	if _player_camera == null or not is_instance_valid(_player_camera):
		return -1
	var eye := _player_camera.global_position
	var look := -_player_camera.global_transform.basis.z.normalized()
	var best := -1
	var best_angle := WATCH_PANEL_ANGLE_DEG
	for i in range(_screens.size()):
		var quad := _screens[i]
		if not is_instance_valid(quad):
			continue
		var to_panel := quad.global_position - eye
		var range_m := to_panel.length()
		if range_m < 0.05 or range_m > WATCH_PANEL_RANGE:
			continue
		var angle := rad_to_deg(look.angle_to(to_panel / range_m))
		if angle < best_angle:
			best_angle = angle
			best = _screen_feeds[i]
	return best


## Feed indices this wall carries, live panels only. Read by the test suite.
func live_feeds() -> Array[int]:
	return _screen_feeds.duplicate()


func _cams() -> Array:
	if _tablet == null or not is_instance_valid(_tablet):
		return []
	var script := _tablet.get_script() as Script
	if script == null:
		return []
	var cams: Variant = script.get_script_constant_map().get(FEED_TABLE_CONSTANT, null)
	return cams if typeof(cams) == TYPE_ARRAY else []


func _feed_count() -> int:
	return _cams().size()
