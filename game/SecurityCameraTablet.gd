extends Node
## FNAF-style security tablet -- the Night Containment Service's CCTV
## workstation, and the reference implementation of the terminal look.
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
##
##
## THE WORKSTATION IS A TerminalFrame WITH A HOLE IN IT
##
## Every full-screen surface in the game is one page of the same device
## (game/TerminalFrame.gd): masthead and status cluster on top, a body region in
## the middle, the key legend along the bottom, all of it behind the tube. This
## screen is that page with the live picture showing through the body region.
##
## The frame paints an opaque SURFACE backdrop over its whole rect, which would
## bury the feed, so the backdrop is switched off and replaced by `_matte`: the
## same opaque SURFACE everywhere EXCEPT the body rect. The result is a bezel
## with a window in it -- which is what a monitor is -- and it buys three things
## that a chrome-over-video layout cannot:
##
##   * TerminalFrame's contrast table holds VERBATIM. Every glyph it draws
##     (masthead, title, status chips, integrity readout, key legend) still sits
##     on an opaque SURFACE, because all of that chrome lies outside the body
##     rect. Nothing in this file re-derives those ratios; they are the ones in
##     that file's header, unchanged.
##   * The picture is cropped, not letterboxed by scaling, so the mini-map's view
##     cone can report what the operator can ACTUALLY see -- see _feed_half_angle.
##   * The mini-map comes off the screen corner, where the tube vignette bites
##     hardest, and lands inside the window instead.
##
## Draw order inside the frame is Backdrop / chrome / Signal Noise / Crt Glass,
## so anything parented into `body` is under both the frame's dropout bands and
## the tube. That is exactly where the feed-change static burst belongs: the
## burst is a thing happening ON the monitor, so it wears scanlines and the
## vignette like everything else, and CRTOverlay composes with it instead of
## being erased by it. The burst is confined to the window, and the burn-in strip
## and the mini-map sit ABOVE it -- an OSD is added after the switcher, so a cut
## does not blank the channel number or the plan.
##
## The tube is the frame's, at the frame's own 0.35 -> 0.50 corruption ramp, not
## a second overlay at the tablet's old 1.0. One monitor, one piece of glass.
##
##
## THE MINI-MAP IS A READ-OUT, NOT DECORATION
##
## Four things have to be answerable at a glance, and each one is carried by
## shape or position BEFORE it is carried by colour:
##
##   which feed am I on   filled chip (ACCENT_FILL, ON_SURFACE digits) + a solid
##                        apex dot at the true mount + the green view cone
##                        leaving it + the same designator burnt into the
##                        picture. A leader line joins the chip to the apex when
##                        the separation pass has pushed them apart.
##   where is it looking  the cone, at the horizontal opening the window really
##                        shows, swung by the pan actually dialled in.
##   which feed does the  amber corner BRACKETS around the chip -- an open
##   objective want       reticle, not a filled ring, so it cannot be confused
##                        with the active chip's fill.
##   where am I           white dot on a dark collar plus a short needle along
##                        the operator's frozen heading, which is the heading
##                        they will be facing the instant the tablet drops.
##
## All of it is drawn, not built out of nodes, so it costs nothing while the
## tablet is down.
##
##
## THE FEED DEGRADES BECAUSE THE CURATOR IS STANDING NEXT TO THE CAMERA
##
## GameManager drives TerminalFrame's corruption from the night loop -- the
## blackout, the night number, the incident clock running out. This screen adds
## the one term only a camera feed can carry, and it is the term that makes the
## tablet frightening: the flat-plane distance from the Curator to the mount of
## the feed CURRENTLY BEING WATCHED.
##
## From FEED_NOISE_RANGE the picture starts rotting -- murk, dropped
## lines, speckle, a falling integrity percentage, the feed's own name coming
## apart in the title -- and inside FEED_DEAD_RANGE it goes out altogether.
##
## The player is hunting the monster THROUGH the thing the monster disturbs. Two
## rules keep that a hunt rather than unfair:
##
##   * It is the ACTIVE feed only. Nothing on the mini-map marks a contaminated
##     camera; the operator has to be looking at that feed to learn anything, and
##     switching away costs them the reading. A chip that lit up would hand over
##     the Curator's position for free and delete the reason to cycle at all.
##   * It needs the Curator to be hunting (CuratorMonster.active), which is false
##     on night 1 and inside a pocket dimension. The mechanic arrives with the
##     threat instead of confusing the tutorial night.
##
## The sustained level sits on top of the floor GameManager already computes for
## every other terminal page (_night_corruption: blackout, night number, the
## incident clock running out), so the workstation cannot claim a healthier
## signal than the fail screen the player sees ten seconds later. The picture,
## though, only ever dies from the Curator term.
##
## Accessibility is TerminalFrame's and CRTOverlay's, unchanged: with
## reduced_flashes on, the murk, the dimmer palette, the broken rules and the
## integrity digits all survive and every time-varying effect is dropped. The two
## time-varying things THIS file owns -- the static burst's per-frame jitter and
## the REC tally's blink -- are switched to a smooth fade and a steady lamp by
## the same flag. The dropout is deliberately NOT gated: it is a monotone fade
## driven by something walking towards a camera, it never oscillates, and it is
## the only cue that says the feed is gone rather than dark. It is paired with
## the TERM_SIGNAL_LOST plate so the reading is a word, not a luminance.
##
##
## CONTRAST -- COMPUTED, NOT EYEBALLED
##
## Everything TerminalFrame draws keeps that file's own table, because the matte
## puts the identical opaque SURFACE behind all of it. What is new here is the
## mini-map, which used to be a SCRIM panel in the screen's corner and is now an
## OPAQUE SURFACE panel inside the picture. SCRIM is SURFACE at 88% and resolves
## to plain SURFACE only when the page is what shows through the other 12%; over
## a live camera feed that 12% was an unbounded backdrop under every room label,
## which is a ratio nobody can compute. Opaque puts it back on the palette.
##
## Method is WCAG 2.1 as in UITheme.gd, with the CRT shader's own falloff
## (`tube = 16*u*v*(1-u)*(1-v)`, raised to CRT_VIGNETTE_POWER) evaluated at the
## panel's MEASURED position -- the window is UV 0.0325..0.9675 x 0.0919..0.9294
## and the panel's far corner lands at UV (0.958, 0.919). `dark` below is the
## light lost to vignette + a full scanline trough + the top of the hum, at
## TerminalFrame's intensity for that corruption level, plus its MURK.
##
##   state                       dark     Wing D label   sealed-wing label
##   clean, c=0, CRT 0.35        0.110       6.57 : 1         6.51 : 1
##   worst, c=1, CRT 0.50        0.157       5.58 : 1         5.53 : 1
##   worst, c=1, 16:9 corner     0.166       5.49 : 1         5.44 : 1
##
## Gate is 4.5; the floor is 5.44 : 1. The old layout spent its whole budget
## (0.27 of the light, 5.13 : 1) because it ran the tube at 1.0 in the screen
## corner; the frame's ramp tops out at 0.50 and the panel is no longer in the
## corner, so there is now real headroom.
##
## Two more ratios, at that same worst pixel: ON_SURFACE digits on the live
## chip's ACCENT_FILL are 8.66 : 1, and the burn-in strip's ON_SURFACE on
## SURFACE is 11.50 : 1. The live chip's digits are ON_SURFACE and not the
## theme's `font_pressed_color`, because a resting Button never resolves the
## pressed colour -- see _switch_to.

const MAP_SCALE := 3.2
const MAP_ORIGIN := Vector2(35.0, 49.0)  # world offset -> map pixels
## The CRT green the game's accent was taken from. Nothing here reads it any
## more -- every Control in this file gets its green from UITheme.ACCENT, which
## is this value -- but it stays: UITheme.gd names `SecurityCameraTablet.GREEN`
## three times as the provenance of ACCENT and of ACCENT_DIM
## (`GREEN.darkened(0.25)`), and a dangling citation is worse than a constant.
const GREEN := Color(0.2, 0.78, 0.42)
const PAN_SPEED := 55.0
const TILT_SPEED := 40.0
## Vertical opening of every feed. Shared with the mini-map view cone so the
## wedge on the map and the picture on screen cannot drift apart.
const CAM_FOV := 75.0

# --- FEED RENDERING ---------------------------------------------------------
#
# A feed is a Camera3D inside its own SubViewport, not a camera that takes the
# player's viewport over. That is what lets ONE picture reach TWO consumers --
# this tablet and, from 10.3, the monitors on the office wall -- and it is what
# stops "watching CCTV" from meaning "the operator is blind".
#
# Cost is the whole design here, not an afterthought: the museum already spends
# ~5000 draw calls a frame, so a feed renders ONLY while somebody asks for it
# (see feed_texture), at FEED_SIZE, and no more than FEED_BUDGET_PER_FRAME of
# them are stepped in any one frame. The rest hold their last drawn frame --
# which on a security monitor reads as a security monitor, not as a compromise.

## РАЗРЕШЕНИЕ ФИДА: ЧИТАЕМОСТЬ ВАЖНЕЕ «ЧЕСТНЫХ ПИКСЕЛЕЙ».
##
## Здесь стояло 256x192 с пояснением «пиксели видны намеренно». На практике это
## означало, что на камере нельзя было разобрать ни зал, ни фигуру в нём: игрок
## смотрел в кашу и не получал информации, ради которой камеры и существуют.
## Ретро-вид держат развёртка, шум и частота кадров, а не нехватка пикселей.
##
## 768x576 -- те же 4:3, втрое больше по стороне. Ценой этого остаётся ленивый
## рендер: фид рисуется только пока его кто-то держит, и не более
## FEED_BUDGET_PER_FRAME за кадр.
const FEED_SIZE := Vector2i(768, 576)
## Redraws per second per wanted feed. Deliberately not 60: a picture that
## updates fifteen times a second reads as a recording, not as a window.
const FEED_REFRESH_HZ := 15.0
## Ceiling on feeds stepped in one frame, whatever the clock says they owe. Two
## viewports of FEED_SIZE is the spike this file is willing to put in a frame.
const FEED_BUDGET_PER_FRAME := 2
## Mirrors FirstMuseumMap.CCTV_HIDDEN_LAYER. Billboarded room names, mount tags
## and door notices live on that layer; a feed that renders them shows a fan of
## text turning to face the lens instead of a museum. Taken over from the map's
## _hide_signage_from_cctv(), which asked for exactly this move in its own
## hand-off note -- the camera is built here, so the cull mask belongs here.
const CCTV_HIDDEN_LAYER := 20

# --- MINI-MAP GEOMETRY ------------------------------------------------------
## Inset between the map panel's edge and the mapped floor plan.
const MAP_PAD := 14.0
## Inset between the picture window's bottom-right corner and the map panel.
const MAP_MARGIN := 16.0
## Nominal chip size. The real one is measured once the chips are in the tree
## (see _build_ui) because a Button's minimum size depends on its theme.
const MAP_CHIP_SIZE := Vector2(34, 22)
## Content margins for the map chips. UITheme.PAD_X/PAD_Y would inflate a chip
## past its slot -- see _map_chip_theme().
const MAP_CHIP_PAD_X := 4
const MAP_CHIP_PAD_Y := 2
## Breathing room the separation pass leaves between two chips.
const MAP_CHIP_GAP := 3.0
## Upper bound on separation passes; the current mounts settle in 6.
const MAP_LAYOUT_PASSES := 8
## Penetrations below this are float noise, not an overlap.
const MAP_LAYOUT_EPSILON := 0.01
## How far the view cone reaches, in world metres.
const CONE_REACH := 11.0
const CONE_SEGMENTS := 12
const PLAYER_MARK_RADIUS := 4.0
## Length of the operator's heading needle, from the centre of the dot.
const PLAYER_NEEDLE := 12.0
## Solid dot on the live feed's true mount, and the leader line that joins it to
## the chip when the separation pass has moved the chip off the mount.
const APEX_RADIUS := 3.5
const LEADER_MIN := 2.5
## Objective reticle: how far the brackets stand off the chip, how long each arm
## is, and how heavy every mark on the map is drawn.
const MARK_GROW := 3.0
const MARK_ARM := 7.0
const MARK_WIDTH := 2.0
# Tilt travel around each camera's mounted pitch. The mounts already aim down:
# the steepest is CAM 08 at -20.6 deg -- it looks at a distribution board 4.5 m
# away -- so anything under 21 leaves that feed permanently staring at the floor
# with the horizon out of reach. (CAM 07 used to sit beside it at -20.8 deg; now
# that the post hangs inside Space Wing C and looks 11.8 m down the wing instead
# of 4.3 m at a door, its mounted pitch is -9.2 deg.) 28 clears the worst mount
# by 7 deg and is applied symmetrically, which still gives every feed at least
# 34 deg of downward travel for detail.
const TILT_LIMIT := 28.0

# --- BURN-IN STRIP ----------------------------------------------------------
## The channel designator and recording tally, burnt into the picture's
## top-left the way a DVR burns them in. Opaque SURFACE plate: it is the one
## piece of text in this file that has a live camera feed behind it, and a feed
## is not a background a contrast ratio can be computed against.
const OSD_MARGIN := 14.0
const OSD_PAD_X := 8
const OSD_PAD_Y := 4
const OSD_GAP := 8
const REC_DOT := 12.0
## Blink period and duty cycle of the recording tally. Held steadily lit for a
## player who has asked for reduced flashing -- the tally means "recording",
## which a lamp says as well as a blink does.
const REC_PERIOD := 1.0
const REC_DUTY := 0.6

# --- STATIC BURST -----------------------------------------------------------
## Peak opacity of the near-white burst that covers a feed change, and the
## ceiling that replaces it for a player who has asked for reduced flashing.
## 0.85 of near-white over a night-time museum feed is a full-screen white
## flash; 0.30 still reads as a cut without being one. The burst itself is not
## dropped: it is the only thing that tells the operator the picture changed
## rather than glitched, and CAM_HINT_CONTROLS never mentions the cut.
const STATIC_FLASH_PEAK := 0.85
const STATIC_FLASH_REDUCED := 0.30

# --- FEED INTERFERENCE ------------------------------------------------------
## Flat-plane distance, in metres, from the Curator to the watched camera's
## mount at which interference starts, and at which the picture is gone. Flat
## because every mount hangs near 3 m and the Curator walks the floor: the true
## 3D distance never drops below about 2.8 m however close it gets, so a 3D
## threshold would make the dead zone unreachable.
const FEED_NOISE_RANGE := 15.0
const FEED_DEAD_RANGE := 3.0
## Where in the 0..1 interference ramp the picture starts going out, and how far
## it goes. Not to 1.0: a ghost of the room left under the dropout is worse to
## look at than a black rectangle, which is the point.
const FEED_DEAD_ONSET := 0.86
const FEED_DEAD_ALPHA := 0.94
## How fast the sustained level chases its target, in units per second, and the
## grid it is quantised onto before being handed to TerminalFrame.set_corruption
## -- that call repaints the whole page, so it must not run once per frame.
const SIGNAL_RATE := 1.1
const SIGNAL_STEP := 0.04
## Interference at which the frame takes a one-shot spike, and the level it has
## to fall back below before another one can fire. Hysteresis, so a Curator
## loitering on the boundary does not stab the page every other frame.
const ALARM_ENTER := 0.25
const ALARM_LEAVE := 0.15
const ALARM_PULSE := 0.5
const ALARM_PULSE_SECONDS := 1.2
const ALARM_VOLUME_DB := -9.0
const ALARM_PITCH := 0.68
## Interference at which the dead picture is labelled in words as well as by
## being black. Below this the operator is watching a rotting feed; above it
## they are watching nothing, and the difference has to be readable.
const LOST_PLATE_AT := 0.5

## Separator between the key cap and its description inside CAM_HINT_CONTROLS,
## and between one hint and the next. The catalogue row is already one legend
## line in both locales ("TAB / Y — exit  |  arrows / right stick — camera ...");
## splitting it is what lets TerminalFrame's footer render proper key caps
## without this file inventing four catalogue rows it does not own. See the
## STRINGS THIS FILE ASKS FOR block at the bottom.
const LEGEND_SEPARATOR := "|"
const LEGEND_SPLIT := " — "

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
	# Post 07 hangs inside Space Wing C, in its south-east corner, looking back
	# along the wing at the blast door. It used to hang in Time Wing B and frame
	# that door from the far side of the wall at x = 13, which left the wing's
	# three exhibits -- the ones ExhibitPuzzleController requires this feed for --
	# behind solid geometry. Mount and target are the literals _add_cameras builds
	# the housing from; test_map_verification pins the two together.
	{"id": "CAM 07", "label": "CAM_WING_C_DOOR",
		"pos": Vector3(33.6, 2.9, -30.8), "target": Vector3(24, 1.0, -24)},
	# CAM_BASEMENT_LIFT is a stale key id, not a stale label: the museum has no
	# basement, and the catalogue row now reads "Atrium — Power Panel" /
	# "Атриум — электрощит" in both columns. The feed frames the Atrium
	# distribution board, which is the prop this aim point actually meets.
	{"id": "CAM 08", "label": "CAM_BASEMENT_LIFT",
		"pos": Vector3(8.8, 2.9, 11.8), "target": Vector3(12.5, 1.2, 14.4)},
	{"id": "CAM 09", "label": "CAM_PLANETARIUM",
		"pos": Vector3(-9.2, 3.0, -34.4), "target": Vector3(0, 1.2, -41)},
	{"id": "CAM 10", "label": "CAM_RESTORATION",
		"pos": Vector3(-33.8, 2.9, 18.4), "target": Vector3(-25, 1.0, 22)},
	# South-west corner of Mass Wing D. From the north-west one the imported
	# superheavy_sphere mesh stood between the post and the Mass Pendulum.
	{"id": "CAM 11", "label": "CAM_WING_D_MASS",
		"pos": Vector3(42.2, 2.9, 6.8), "target": Vector3(52, 1.0, 0)},
]

# Mini-map rooms: [name, world center (x,z), size (w,d), open from night N].
# The last field replaces a hard-coded "locked" flag: wings C and D are sealed
# behind blast doors that GameManager removes on nights 2 and 3, so a constant
# made the map keep painting them red in rooms the player had already walked
# through. 1 == open from the first shift.
#
# game/Compass.gd reads this table out of the script constant map without
# instantiating the tablet, so the row shape is a published contract.
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
## One SubViewport per feed, index-aligned with _cams and CAMS.
var _feed_views: Array[SubViewport] = []
## Whether each feed is currently drawn at all. Index-aligned with _feed_views.
var _feed_wanted: Array[bool] = []
## Seconds owed before each feed is stepped again; negative means overdue.
var _feed_due: Array[float] = []
## Consumers holding a feed through feed_texture(): index -> true. Separate from
## the tablet's own active feed, so lowering the tablet cannot switch off a
## monitor on the wall and a monitor cannot keep the tablet's feed alive.
var _feed_holders := {}
## Where the round-robin resumes, so a feed cannot be starved by an earlier one.
var _feed_cursor := 0
## The window's picture. Its texture is whichever feed is on screen.
var _picture: TextureRect
var _lights: Array[SpotLight3D] = []
var _base_rot: Array[Vector3] = []
var _buttons: Array[Button] = []
var _room_boxes: Array[StyleBoxFlat] = []
var _room_labels: Array[Label] = []
var _layer: CanvasLayer
var _frame: TerminalFrame
var _matte: Control
var _feed: Control
var _cam_label: Label
var _rec_dot: ColorRect
var _static_rect: ColorRect
var _dropout: ColorRect
var _lost_plate: Control
var _lost_label: Label
var _game: Node = null
var _map_bounds := Vector2.ZERO
var _chip_active: StyleBoxFlat
var _cone: Control
var _marks: Control
var _enhancements: Node = null
var _open := false
var _active := 0
var _time := 0.0
var _static_alpha := 0.0
var _pan := 0.0
var _tilt := 0.0
var _flash_on := false
## Picture window in canvas coordinates, cached so the matte only repaints when
## the layout actually moves.
var _window := Rect2()
## Sustained corruption: what it is, what TerminalFrame was last told, and
## whether the next update must land in one step (a feed change).
var _signal_level := 0.0
var _signal_applied := -1.0
var _signal_snap := true
var _feed_alarm := false
var _night_cached := 1
var _status_minute := -1
var _status_core := ""
var _status_level := -1

# --- The tablet as an object in the hands (stage 10.2) ---------------------
# Until now the tablet had no body: the feed simply appeared, and the device the
# whole room is built around existed nowhere in the room. The shell below is the
# same object the cradle on the desk holds -- same 0.22 x 0.15 case -- parented
# to the player's camera, and the overlay is no longer allowed on screen until it
# has been raised far enough to read.
#
# The shell's local frame is the camera's: -Z away from the eye, so the screen
# faces the player and the back of the case is what the museum sees.

const SHELL_SIZE := Vector3(0.220, 0.150, 0.014)
const RAISE_SECONDS := 0.30
## Down at the hip, tipped away and out of the sightline; and up in front of the
## face, tipped back the way a hand holds a screen it is reading.
const SHELL_POS_STOWED := Vector3(0.26, -0.46, -0.32)
const SHELL_POS_RAISED := Vector3(0.075, -0.125, -0.315)
const SHELL_ROT_STOWED := Vector3(-74.0, -18.0, 10.0)
const SHELL_ROT_RAISED := Vector3(-12.0, -3.0, 0.0)
## The overlay IS this shell's screen, so it goes on only once the case is most
## of the way up, and off the instant it starts down. A fully readable page on a
## case still swinging at the hip is the artefact this threshold exists to stop.
const SHELL_SCREEN_ON := 0.62

var _shell: Node3D = null
var _shell_glow: StandardMaterial3D = null
## 0.0 stowed, 1.0 raised. Driven every frame, closed as well as open: the half
## that plays while `_open` is already false is the half that puts it away.
var _raise := 0.0
## The cradle's tablet, hidden for as long as the operator is holding this one.
## Two copies of one device on screen at once is the contradiction it resolves.
var _docked: Node3D = null


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_make_cameras()
	_build_ui()
	_build_shell()


## Procedural shell: case, screen, lens and charge lamp, plus grip ridges on the
## back where the room can see them. Boxes with their own materials, like every
## other prop in this museum -- no imported mesh.
##
## Every part sits on the CCTV layer, which each feed camera culls (see
## _make_cameras): a wall camera looking at the operator has to show the
## operator, not a slab floating through their chest.
func _build_shell() -> void:
	var cam := _player_camera()
	if cam == null:
		# No player in the scene -- the standalone map, or a probe. The tablet
		# still works as a screen; it just has no hands to sit in.
		return
	_shell = Node3D.new()
	_shell.name = "Carried Tablet"
	cam.add_child(_shell)
	_shell.position = SHELL_POS_STOWED
	_shell.rotation_degrees = SHELL_ROT_STOWED
	_shell.visible = false

	var front := SHELL_SIZE.z * 0.5 + 0.001
	_shell_mesh("Case", Vector3.ZERO, SHELL_SIZE, Color(0.074, 0.080, 0.088), 0.0)
	var screen := _shell_mesh("Screen", Vector3(0.0, 0.004, front),
		Vector3(SHELL_SIZE.x - 0.024, SHELL_SIZE.y - 0.024, 0.002),
		Color(0.055, 0.085, 0.090), 0.0)
	_shell_glow = screen.material_override as StandardMaterial3D
	_shell_mesh("Lens", Vector3(0.0, SHELL_SIZE.y * 0.5 - 0.008, front),
		Vector3(0.008, 0.008, 0.002), Color(0.020, 0.024, 0.030), 0.0)
	_shell_mesh("Charge Lamp",
		Vector3(SHELL_SIZE.x * 0.5 - 0.020, -SHELL_SIZE.y * 0.5 + 0.010, front),
		Vector3(0.010, 0.004, 0.002), Color(0.900, 0.560, 0.120), 1.4)
	for side in [-1.0, 1.0]:
		_shell_mesh("Grip", Vector3(side * (SHELL_SIZE.x * 0.5 - 0.016), 0.0,
			-SHELL_SIZE.z * 0.5 - 0.003),
			Vector3(0.014, SHELL_SIZE.y - 0.040, 0.006),
			Color(0.035, 0.040, 0.046), 0.0)


func _shell_mesh(part_name: String, part_position: Vector3, size: Vector3,
		color: Color, emission_energy: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	mat.metallic = 0.2
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_energy
	var node := MeshInstance3D.new()
	node.name = part_name
	node.mesh = mesh
	node.material_override = mat
	node.position = part_position
	# Culled by every feed camera; see _make_cameras().
	node.layers = 1 << (CCTV_HIDDEN_LAYER - 1)
	_shell.add_child(node)
	return node


func _player_camera() -> Camera3D:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _player == null:
		return null
	return _player.get_node_or_null("Player Camera") as Camera3D


## The raise and the lower, and the only owner of `_layer.visible`.
##
## Called from _process ahead of its early return, for the same reason the feed
## pacer is: a lowering animation that only ran while the tablet was open would
## never play at all.
func _step_raise(delta: float) -> void:
	# The player is NOT in the tree when this node runs _ready -- the map spawns
	# them -- so the shell built there lands on a null camera and the tablet keeps
	# no body for the whole run. Retried once a frame until the camera exists,
	# which costs one group lookup on a scene that genuinely has no player.
	if _shell == null:
		_build_shell()
	var target := 1.0 if _open else 0.0
	if not is_equal_approx(_raise, target):
		_raise = move_toward(_raise, target, delta / maxf(0.01, RAISE_SECONDS))
	if _shell != null and is_instance_valid(_shell):
		# Smoothstep, not linear: the hand accelerates out of the hip and settles
		# at the top instead of arriving at full speed and stopping dead.
		var t := smoothstep(0.0, 1.0, _raise)
		_shell.visible = _raise > 0.002
		_shell.position = SHELL_POS_STOWED.lerp(SHELL_POS_RAISED, t)
		_shell.rotation_degrees = SHELL_ROT_STOWED.lerp(SHELL_ROT_RAISED, t)
		if _shell_glow != null:
			# The case's own screen brightens with the page, so the glow on the
			# bezel and the picture the player reads agree with each other.
			_shell_glow.emission_enabled = t > 0.05
			_shell_glow.emission_energy_multiplier = t * 0.9
	if _layer != null:
		_layer.visible = _open and _raise >= SHELL_SCREEN_ON
	_sync_docked()


## Empty the cradle for as long as the tablet is out of it. Looked up by group so
## the office props stay a static builder that knows nothing about this node.
func _sync_docked() -> void:
	if _docked == null or not is_instance_valid(_docked):
		_docked = get_tree().get_first_node_in_group("docked_tablet") as Node3D
		if _docked == null:
			return
	_docked.visible = _raise <= 0.002


func _make_cameras() -> void:
	for c in CAMS:
		# One SubViewport per post. `world_3d` is taken from the tablet's own
		# viewport because a SubViewport left alone builds a private, EMPTY
		# World3D -- the feed would come back black and nothing would say why.
		# It has to be assigned after add_child: before that there is no
		# viewport above this node to read the world off.
		var view := SubViewport.new()
		view.name = "Feed %s" % String(c["id"]).replace(" ", "")
		view.size = FEED_SIZE
		view.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
		# Nothing is drawn until somebody asks for it; see _step_feeds().
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		# No antialiasing on a security feed -- it costs, and it would smooth
		# away the one thing the low resolution is here to provide.
		view.msaa_3d = Viewport.MSAA_DISABLED
		add_child(view)
		view.world_3d = get_viewport().world_3d
		_feed_views.append(view)
		_feed_wanted.append(false)
		_feed_due.append(0.0)

		var cam := Camera3D.new()
		cam.name = String(c["id"]).replace(" ", "")
		view.add_child(cam)
		cam.global_position = c["pos"]
		cam.look_at(c["target"], Vector3.UP)
		# Push the lens just past the physical camera prop, otherwise the
		# prop's own round lens disc sits right in front of the view and
		# fills the screen as an unexplained circle.
		cam.global_position += -cam.global_transform.basis.z * 0.55
		cam.near = 0.15
		cam.fov = CAM_FOV
		# Current WITHIN its own SubViewport, which is now the whole of its
		# reach: it can no longer take the player's screen. That is precisely
		# why raising the tablet stopped blinding the operator.
		cam.current = true
		cam.cull_mask &= ~(1 << (CCTV_HIDDEN_LAYER - 1))
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


## The texture a consumer should show, plus a standing request to keep that feed
## drawn. This is how the office monitors get a picture in 10.3 without either
## side knowing the other's node layout. Callers must release() what they take.
func feed_texture(index: int) -> Texture2D:
	if index < 0 or index >= _feed_views.size():
		return null
	_feed_holders[index] = true
	_refresh_feed_wants()
	return _feed_views[index].get_texture()


## Give a feed back. A monitor that goes dark, or a wall that is torn down, must
## stop the cost as well as the picture.
func release_feed(index: int) -> void:
	if _feed_holders.erase(index):
		_refresh_feed_wants()


## Recompute which feeds are drawn: whatever consumers hold, plus the one a
## raised tablet is showing. A feed nobody looks at is switched OFF rather than
## slowed down -- on this map "cheaper" is not the same as "free".
func _refresh_feed_wants() -> void:
	for i in range(_feed_views.size()):
		var wanted: bool = _feed_holders.has(i) or (_open and i == _active)
		if _feed_wanted[i] == wanted:
			continue
		_feed_wanted[i] = wanted
		if wanted:
			# Draw on the very next frame instead of making a cut wait out a
			# ninth of a second on a black window.
			_feed_due[i] = 0.0
			_feed_views[i].render_target_update_mode = SubViewport.UPDATE_ONCE
		else:
			_feed_views[i].render_target_update_mode = SubViewport.UPDATE_DISABLED


## Round-robin pacer. Every wanted feed owes a redraw FEED_REFRESH_HZ times a
## second; at most FEED_BUDGET_PER_FRAME are granted in any frame, and the cursor
## resumes where it left off so the same early feed cannot eat the budget every
## frame while a later one holds a frozen picture forever.
func _step_feeds(delta: float) -> void:
	var count := _feed_views.size()
	if count == 0:
		return
	var period := 1.0 / FEED_REFRESH_HZ
	var granted := 0
	for offset in range(count):
		var i := (_feed_cursor + offset) % count
		if not _feed_wanted[i]:
			continue
		# Debited before the budget check, so a feed that misses its turn is
		# further overdue next frame rather than quietly slipping a beat.
		_feed_due[i] -= delta
		if _feed_due[i] > 0.0:
			continue
		if granted >= FEED_BUDGET_PER_FRAME:
			continue
		granted += 1
		_feed_due[i] = period
		_feed_views[i].render_target_update_mode = SubViewport.UPDATE_ONCE
	if granted > 0:
		_feed_cursor = (_feed_cursor + granted) % count


# --- CONSTRUCTION -----------------------------------------------------------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	_layer.visible = false
	add_child(_layer)

	var root := Control.new()
	root.name = "Workstation"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)

	# The bezel, BEFORE the frame so the frame's chrome paints on top of it.
	_matte = Control.new()
	_matte.name = "Bezel Matte"
	_matte.set_anchors_preset(Control.PRESET_FULL_RECT)
	_matte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_matte.draw.connect(_draw_matte)
	root.add_child(_matte)

	_frame = TerminalFrame.new()
	_frame.name = "Terminal"
	_frame.set_panel_variation(&"CCTVPanel")
	root.add_child(_frame)
	_hide_frame_backdrop()
	_frame.set_keys(_legend_entries())

	_feed = Control.new()
	_feed.name = "Picture"
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.body.add_child(_feed)

	# The picture itself, BEFORE the overlays, so the static burst, the dropout
	# and the burn-in strip all still paint over it. This Control used to be a
	# transparent hole with a hijacked 3D camera behind it; now the feed arrives
	# as a texture and the room behind the tablet keeps rendering.
	_picture = TextureRect.new()
	_picture.name = "Feed Texture"
	_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# KEEP_ASPECT_COVERED, not STRETCH: a 4:3 feed in a wider window would
	# otherwise be letterboxed inside a bezel that is already a matte, and the
	# operator would read the black bars as part of the picture.
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# Линейная фильтрация: при FEED_SIZE увеличение до окна планшета уже не
	# требует «честных пикселей», а nearest на этом разрешении давал рваные
	# края на каждой грани зала. Ретро держат развёртка и шум поверх кадра.
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_feed.add_child(_picture)

	_build_feed_overlays()
	_build_map()
	_refresh_map_locks()


## Switch off TerminalFrame's opaque page backdrop so the live feed reaches the
## body region. `_matte` puts the same SURFACE back everywhere else, so nothing
## the frame draws changes background -- see the header.
##
## Resolved by name first and by type second: the frame is another agent's file,
## and a renamed node must not silently leave a black rectangle over the picture.
func _hide_frame_backdrop() -> void:
	var backdrop := _frame.get_node_or_null("Backdrop") as Control
	if backdrop == null:
		for child in _frame.get_children():
			if child is Panel or child is ColorRect:
				backdrop = child as Control
				break
	if backdrop == null:
		push_warning("SecurityCameraTablet: TerminalFrame has no backdrop to hide; "
			+ "the camera feed will be covered by the page fill.")
		return
	backdrop.visible = false


func _build_feed_overlays() -> void:
	# Static flash shown for a moment on every camera switch. FIRST child of the
	# window, so the burn-in strip and the mini-map survive the cut.
	_static_rect = ColorRect.new()
	_static_rect.name = "Feed Cut"
	_static_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Video white, not a palette colour: this is the switcher's own burst, and it
	# is measured as a flash (see STATIC_FLASH_PEAK), not as a surface.
	_static_rect.color = Color(0.8, 0.85, 0.8, 0.0)
	_static_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.add_child(_static_rect)

	# The picture going out because the Curator is under the camera.
	_dropout = ColorRect.new()
	_dropout.name = "Signal Dropout"
	_dropout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dropout.color = Color(UITheme.SURFACE, 0.0)
	_dropout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.add_child(_dropout)

	var strip := PanelContainer.new()
	strip.name = "Channel Burn In"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", UITheme.stylebox(
		UITheme.SURFACE, UITheme.BORDER, UITheme.BORDER_WIDTH, UITheme.RADIUS_SM,
		OSD_PAD_X, OSD_PAD_Y))
	strip.position = Vector2(OSD_MARGIN, OSD_MARGIN)
	_feed.add_child(strip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", OSD_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(row)

	# DANGER is a fill token, and a recording tally is exactly that -- UITheme's
	# header calls this dot out as the one legitimate use of the palette's red.
	# It is paired with the channel designator beside it, so the reading never
	# rests on the colour.
	_rec_dot = ColorRect.new()
	_rec_dot.name = "Rec"
	_rec_dot.color = UITheme.DANGER
	_rec_dot.custom_minimum_size = Vector2(REC_DOT, REC_DOT)
	_rec_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_rec_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_rec_dot)

	# Deliberately NOT registered with TerminalFrame.add_glitch_target: the
	# channel number is how the operator knows which room they are looking at,
	# and a designator that rots is a designator that lies. The feed's NAME, in
	# the frame's title, rots instead -- same beat, no lost address.
	_cam_label = Label.new()
	_cam_label.name = "Channel"
	_cam_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text(_cam_label, UITheme.LABEL, UITheme.ON_SURFACE)
	row.add_child(_cam_label)

	_build_lost_plate()


## What a dead picture SAYS. The dropout alone is a black rectangle, and "black
## rectangle" is a luminance cue on a night-time feed that is already mostly
## black -- so the state gets a word for it on an opaque plate.
##
## Deliberately not TerminalFrame.set_signal_lost(): that replaces the whole body
## region, which on this screen is where the mini-map and the burn-in strip live.
## The FEED is lost; the workstation is not, and taking the operator's plan away
## at the exact moment something is standing under a camera is the wrong trade.
func _build_lost_plate() -> void:
	_lost_plate = CenterContainer.new()
	_lost_plate.name = "Feed Lost"
	_lost_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lost_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lost_plate.visible = false
	_feed.add_child(_lost_plate)

	var plate := PanelContainer.new()
	plate.name = "Plate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", UITheme.stylebox(
		UITheme.SURFACE, UITheme.DANGER, UITheme.FOCUS_WIDTH, UITheme.RADIUS_LG,
		UITheme.PAD_X + 12, UITheme.PAD_Y + 8))
	_lost_plate.add_child(plate)

	_lost_label = Label.new()
	_lost_label.name = "Message"
	_lost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lost_label.text = tr("TERM_SIGNAL_LOST")
	UITheme.apply_text(_lost_label, UITheme.SECTION, UITheme.ON_SURFACE)
	plate.add_child(_lost_label)


func _build_map() -> void:
	# Mini-map panel, bottom-right of the PICTURE. Opaque SURFACE, not SCRIM:
	# SCRIM is 88% of the page fill and resolves to plain SURFACE only when the
	# page is behind it. Here the thing behind it is a live camera feed, whose
	# brightness nobody can bound, so the 12% that used to show through was 12%
	# of an unknown backdrop under every room label. Opaque puts the label
	# ratios back on the palette's own numbers. The frame stays green because
	# the map is live chrome: BORDER_ACCENT.
	_map_bounds = Vector2((63.0 + MAP_ORIGIN.x) * MAP_SCALE + MAP_PAD * 2.0,
		(35.0 + MAP_ORIGIN.y) * MAP_SCALE + MAP_PAD * 2.0)
	var panel := Panel.new()
	panel.name = "Plan"
	panel.add_theme_stylebox_override("panel", UITheme.stylebox(
		UITheme.SURFACE, UITheme.BORDER_ACCENT, UITheme.BORDER_WIDTH, UITheme.RADIUS_LG))
	panel.theme = _map_chip_theme()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -(_map_bounds.x + MAP_MARGIN)
	panel.offset_top = -(_map_bounds.y + MAP_MARGIN)
	panel.offset_right = -MAP_MARGIN
	panel.offset_bottom = -MAP_MARGIN
	_feed.add_child(panel)

	# Room outlines. The lock colour is not baked here: _refresh_map_locks()
	# repaints these style boxes every time the tablet is raised.
	for r in ROOMS:
		var rp := Panel.new()
		var rsb := StyleBoxFlat.new()
		rsb.set_border_width_all(UITheme.BORDER_WIDTH)
		rp.add_theme_stylebox_override("panel", rsb)
		_room_boxes.append(rsb)
		var c: Vector2 = r[1]
		var s: Vector2 = r[2]
		rp.position = _to_panel(c - s * 0.5)
		rp.size = s * MAP_SCALE
		rp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(rp)
		var rl := Label.new()
		rl.text = tr(String(r[0]))
		UITheme.apply_text(rl, UITheme.CAPTION, UITheme.MUTED)
		rl.position = rp.position + Vector2(4, 2)
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(rl)
		_room_labels.append(rl)

	# View cone for the live feed, under the chips so it never hides one.
	_cone = Control.new()
	_cone.name = "View Cone"
	_cone.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cone.draw.connect(_draw_view_cone)
	panel.add_child(_cone)

	# Camera buttons on the map. These must be focusable: a pad has no cursor, so
	# FOCUS_NONE left every feed but CAM 01 unreachable on a controller. TAB is
	# still safe — _input() runs before the viewport hands the event to the GUI,
	# and it marks the toggle as handled, so a focused button never sees it and
	# cannot swallow it for focus navigation.
	for i in range(CAMS.size()):
		var btn := Button.new()
		btn.text = "%02d" % (i + 1)
		btn.focus_mode = Control.FOCUS_ALL
		btn.pressed.connect(_switch_to.bind(i))
		panel.add_child(btn)
		_buttons.append(btn)

	# Size is measured, not assumed. get_combined_minimum_size() only sees the
	# map panel's Theme from inside the tree, and Control.set_size() silently
	# clamps *up* to that minimum -- so a chip that turned out wider than
	# MAP_CHIP_SIZE would quietly break the separation pass below, which is the
	# one thing guaranteeing every chip stays clickable.
	var slot := MAP_CHIP_SIZE
	for btn in _buttons:
		var minimum := btn.get_combined_minimum_size()
		slot = Vector2(maxf(slot.x, minimum.x), maxf(slot.y, minimum.y))
	var spots := _chip_positions(slot)
	for i in range(_buttons.size()):
		_buttons[i].size = slot
		_buttons[i].position = spots[i]

	# Apex dot, leader, objective reticle and the operator's own mark, on top of
	# the chips. Mouse-ignoring, so drawing over a chip costs the chip nothing.
	_marks = Control.new()
	_marks.name = "Marks"
	_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_map_marks)
	panel.add_child(_marks)


## Theme for the eleven mini-map chips.
##
## UITheme.apply_button() is the right call for a normal screen and the wrong
## one here: its PAD_X/PAD_Y (12/8) put a Button's minimum size at roughly
## 38x31, Control.set_size() clamps up to the minimum, and the separation pass
## then has to shove the fattened chips up to 15 px off their mounts -- 4.7 m of
## museum, on a map whose whole job is saying where things are. Same tokens,
## tighter content margins, and hung on the panel as a Theme so all eleven chips
## share one set of resources instead of carrying five overrides each.
func _map_chip_theme() -> Theme:
	var theme := Theme.new()
	theme.set_font_size("font_size", "Button", UITheme.CAPTION)
	theme.set_color("font_color", "Button", UITheme.MUTED)
	theme.set_color("font_hover_color", "Button", UITheme.ON_SURFACE)
	theme.set_color("font_pressed_color", "Button", UITheme.ACCENT)
	theme.set_color("font_focus_color", "Button", UITheme.ON_SURFACE)
	theme.set_stylebox("normal", "Button", _chip_style(UITheme.SURFACE, UITheme.BORDER))
	theme.set_stylebox("hover", "Button",
		_chip_style(UITheme.SURFACE_RAISED, UITheme.BORDER_ACCENT))
	# The live feed wears the pressed look permanently (see _switch_to), so the
	# two share one resource rather than drifting apart.
	_chip_active = _chip_style(UITheme.ACCENT_FILL, UITheme.ACCENT)
	theme.set_stylebox("pressed", "Button", _chip_active)
	var ring := UITheme.focus()
	ring.set_corner_radius_all(UITheme.RADIUS_SM)
	theme.set_stylebox("focus", "Button", ring)
	return theme


func _chip_style(bg: Color, border: Color) -> StyleBoxFlat:
	return UITheme.stylebox(bg, border, UITheme.BORDER_WIDTH, UITheme.RADIUS_SM,
		MAP_CHIP_PAD_X, MAP_CHIP_PAD_Y)


## Where the eleven chips sit, in map-panel coordinates.
##
## CAM 03 and CAM 05 are mounted 5.5 m apart across the atrium, which is 17 px
## at MAP_SCALE -- half a chip -- so their 34x22 rects overlapped by 25x7 px.
## Godot hit-tests children front to back and CAM 05 is the later child, so that
## whole band answered for CAM 05 and the bottom-right corner of CAM 03 could
## not be clicked at all.
##
## Chips start on their true mapped position and are then pushed apart until no
## two rects intersect: each pass separates an overlapping pair along its
## shallower axis and moves both halves equally, so the outcome does not depend
## on child order, then clamps them back inside the panel. For the current
## mounts this settles in 6 passes and moves only CAM 03, 05 and 07, by at most
## 6.2 px; the tightest surviving gap is 3.0 px and no pair intersects.
##
## A chip that has been moved is a chip that no longer marks its mount, which is
## why _draw_map_marks draws the live feed's apex on the TRUE position and runs a
## leader line back to the chip -- the displacement is shown rather than hidden.
func _chip_positions(size: Vector2) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for c in CAMS:
		var wp: Vector3 = c["pos"]
		spots.append(_clamp_to_map(_to_panel(Vector2(wp.x, wp.z)) - size * 0.5, size))
	var span := size + Vector2(MAP_CHIP_GAP, MAP_CHIP_GAP)
	for _pass in range(MAP_LAYOUT_PASSES):
		var moved := false
		for i in range(spots.size()):
			for j in range(i + 1, spots.size()):
				var delta := spots[j] - spots[i]
				var pen := Vector2(span.x - absf(delta.x), span.y - absf(delta.y))
				if pen.x <= MAP_LAYOUT_EPSILON or pen.y <= MAP_LAYOUT_EPSILON:
					continue
				moved = true
				var push := Vector2.ZERO
				if pen.x < pen.y:
					push.x = pen.x * 0.5 * (1.0 if delta.x >= 0.0 else -1.0)
				else:
					push.y = pen.y * 0.5 * (1.0 if delta.y >= 0.0 else -1.0)
				spots[i] = _clamp_to_map(spots[i] - push, size)
				spots[j] = _clamp_to_map(spots[j] + push, size)
		if not moved:
			break
	return spots


func _clamp_to_map(point: Vector2, size: Vector2) -> Vector2:
	return Vector2(clampf(point.x, 0.0, maxf(0.0, _map_bounds.x - size.x)),
		clampf(point.y, 0.0, maxf(0.0, _map_bounds.y - size.y)))


func _to_map(world: Vector2) -> Vector2:
	return (world + MAP_ORIGIN) * MAP_SCALE


## _to_map() in the map panel's own coordinates, i.e. past its inset.
func _to_panel(world: Vector2) -> Vector2:
	return _to_map(world) + Vector2(MAP_PAD, MAP_PAD)


## Repaint the mini-map's lock state. Called on every open, never baked: wings C
## and D are sealed by blast doors that GameManager tears down on nights 2 and 3,
## so a const flag made the map keep them red in rooms the player had already
## walked through.
func _refresh_map_locks() -> void:
	var night := _night_cached
	for i in range(_room_boxes.size()):
		var box := _room_boxes[i]
		var locked := night < int(ROOMS[i][3])
		# Both fills keep the alpha they had: these are wash tints the plan is
		# read through, not surfaces, and at full strength they would bury the
		# room outlines and the chips standing on them.
		box.bg_color = Color(UITheme.DANGER, 0.10) if locked \
			else Color(UITheme.ACCENT, 0.08)
		box.border_color = UITheme.DANGER if locked else UITheme.ACCENT_DIM


# --- THE BEZEL --------------------------------------------------------------

## Everything outside the picture window, in opaque SURFACE. See the header for
## why this exists rather than TerminalFrame's own backdrop.
func _draw_matte() -> void:
	var page := _matte.size
	if page.x <= 0.0 or page.y <= 0.0:
		return
	var hole := Rect2(_window.position - _matte.global_position, _window.size)
	hole = hole.intersection(Rect2(Vector2.ZERO, page))
	if hole.size.x <= 0.0 or hole.size.y <= 0.0:
		# No window yet (first frame after the layer is shown, before the frame
		# has been laid out). Painting the full page here would black the feed
		# out for that frame, so paint nothing at all instead.
		return
	var fill := UITheme.SURFACE
	_matte.draw_rect(Rect2(0.0, 0.0, page.x, hole.position.y), fill)
	_matte.draw_rect(Rect2(0.0, hole.end.y, page.x, maxf(0.0, page.y - hole.end.y)), fill)
	_matte.draw_rect(Rect2(0.0, hole.position.y, hole.position.x, hole.size.y), fill)
	_matte.draw_rect(Rect2(hole.end.x, hole.position.y,
		maxf(0.0, page.x - hole.end.x), hole.size.y), fill)
	# A hairline on the aperture, so the picture reads as a window in a bezel
	# rather than as the page having failed to paint.
	_matte.draw_rect(hole.grow(1.0), UITheme.BORDER, false, 1.0)


## Track the picture window. Compared rather than driven off `resized`, because
## the window also moves when the frame's own chrome changes height (a longer
## title, a status chip appearing) and one Rect2 compare a frame is cheaper than
## keeping three signals honest.
func _sync_window() -> void:
	if _feed == null or _matte == null:
		return
	var rect := _feed.get_global_rect()
	if rect == _window:
		return
	_window = rect
	_matte.queue_redraw()


# --- MINI-MAP DRAWING -------------------------------------------------------

## The camera the current objective wants confirmed, or -1 when there is none.
##
## GameplayEnhancements owns the number, publishes itself in the
## "gameplay_enhancements" group from its own _ready(), and is optional
## furniture -- the tablet has to keep working in the map scene and in the test
## suites, neither of which builds one -- so every hop is null-guarded and a
## miss costs one group lookup per frame while the tablet is up. Reading a
## private field is the contract already running in the other direction:
## GameplayEnhancements._update_scan() polls this node's `_open` and `_active`.
func _required_camera() -> int:
	var source := _enhancement_node()
	if source == null:
		return -1
	# Confirmed already: stop pointing at a camera the operator is done with.
	var done: Variant = source.get("_scan_complete")
	if typeof(done) == TYPE_BOOL and bool(done):
		return -1
	var value: Variant = source.get("_required_camera")
	if typeof(value) != TYPE_INT:
		return -1
	var index := int(value)
	return index if index >= 0 and index < _buttons.size() else -1


func _enhancement_node() -> Node:
	if not is_instance_valid(_enhancements):
		_enhancements = get_tree().get_first_node_in_group("gameplay_enhancements")
	return _enhancements


## Wedge for the live feed: where it is pointed right now, pan included.
func _draw_view_cone() -> void:
	if _active < 0 or _active >= _base_rot.size():
		return
	var origin := _mount_on_map(_active)
	# A Godot camera looks down -Z, so a yaw of theta aims it at
	# (-sin theta, -cos theta) in world XZ; _to_map() is a pure scale and offset,
	# so that same vector is the heading on the map with no extra correction.
	# Pan is added rather than read back off the Camera3D because the operator
	# can be panning a feed whose transform this frame is still the old one.
	var yaw := deg_to_rad(_base_rot[_active].y + _pan)
	var facing := Vector2(-sin(yaw), -cos(yaw))
	var half := _feed_half_angle()
	var reach := CONE_REACH * MAP_SCALE
	var fan := PackedVector2Array([origin])
	for i in range(CONE_SEGMENTS + 1):
		var t := float(i) / float(CONE_SEGMENTS)
		fan.append(origin + facing.rotated(lerpf(-half, half, t)) * reach)
	_cone.draw_colored_polygon(fan, Color(UITheme.ACCENT, 0.16))
	_cone.draw_line(origin, origin + facing * reach, Color(UITheme.ACCENT, 0.55), 1.0)


func _mount_on_map(index: int) -> Vector2:
	var wp: Vector3 = CAMS[index]["pos"]
	return _to_panel(Vector2(wp.x, wp.z))


## Half the cone's opening, in radians, as the OPERATOR sees it.
##
## CAM_FOV is the *vertical* opening -- Camera3D defaults to KEEP_HEIGHT -- and a
## plan view needs the horizontal one, which is the vertical widened by the
## viewport's aspect. The picture window is then a horizontally centred crop of
## that viewport (the bezel is symmetric left and right), so the half-angle the
## operator can actually see is narrowed by the same fraction. Without that
## second step the wedge would promise coverage the bezel is hiding.
##
## 16:9 and "no crop" are the fallbacks for the frame before the viewport and the
## window exist.
func _feed_half_angle() -> float:
	var width := 0.0
	var aspect := 16.0 / 9.0
	var viewport := get_viewport()
	if viewport != null:
		var size := viewport.get_visible_rect().size
		if size.y > 0.0:
			aspect = size.x / size.y
		width = size.x
	var half := atan(tan(deg_to_rad(CAM_FOV) * 0.5) * aspect)
	if width > 0.0 and _window.size.x > 0.0 and _window.size.x < width:
		half = atan(tan(half) * _window.size.x / width)
	return half


## Everything that goes over the chips, in the order it has to stack: the live
## feed's own apex under the objective reticle under the operator.
func _draw_map_marks() -> void:
	_draw_active_mark()
	_draw_required_mark()
	_draw_player_mark()


## The live feed, said twice more: a solid dot on the TRUE mount, and a leader
## back to the chip whenever the separation pass has moved the chip off it. The
## chip's own fill is the third statement and the burn-in strip is the fourth,
## so "which camera am I watching" never rests on one cue -- or on colour.
func _draw_active_mark() -> void:
	if _active < 0 or _active >= _buttons.size():
		return
	var apex := _mount_on_map(_active)
	var chip := _buttons[_active]
	var centre := chip.position + chip.size * 0.5
	if centre.distance_to(apex) > LEADER_MIN:
		_marks.draw_line(apex, centre, Color(UITheme.ACCENT, 0.7), 1.0)
	_marks.draw_circle(apex, APEX_RADIUS + 1.5, UITheme.SURFACE)
	_marks.draw_circle(apex, APEX_RADIUS, UITheme.ACCENT)


## The objective's camera: four corner brackets, i.e. an open reticle. Brackets
## rather than a closed ring because the live chip is a FILLED rounded rect and
## the two marks have to stay apart for a player who cannot use the amber.
func _draw_required_mark() -> void:
	var required := _required_camera()
	if required < 0:
		return
	var chip := _buttons[required]
	var box := Rect2(chip.position, chip.size).grow(MARK_GROW)
	var arm := minf(MARK_ARM, minf(box.size.x, box.size.y) * 0.5)
	var colour := UITheme.WARNING
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var at := box.position + box.size * corner
		# +1 on the near edge, -1 on the far one: each arm runs back along the box.
		var reach := Vector2(1.0 - 2.0 * corner.x, 1.0 - 2.0 * corner.y) * arm
		_marks.draw_line(at, at + Vector2(reach.x, 0.0), colour, MARK_WIDTH)
		_marks.draw_line(at, at + Vector2(0.0, reach.y), colour, MARK_WIDTH)


## The operator: a dot, and a needle along the heading they are frozen on.
##
## The needle is the same reading GameplayEnhancements' motion sensor speaks in
## words ("12 m, behind you") -- the tablet parks the player mid-turn, so this is
## exactly the direction they will be facing the moment the feed drops. Drawn in
## ON_SURFACE and only ~12 px long, so it cannot be read as a second view cone.
func _draw_player_mark() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	# Clamped, not hidden: the museum fits the map, but a player who somehow
	# leaves it is better reported at the edge than dropped off the panel.
	var here := _clamp_to_map(
		_to_panel(Vector2(_player.global_position.x, _player.global_position.z))
			- Vector2(PLAYER_MARK_RADIUS, PLAYER_MARK_RADIUS),
		Vector2(PLAYER_MARK_RADIUS, PLAYER_MARK_RADIUS) * 2.0
	) + Vector2(PLAYER_MARK_RADIUS, PLAYER_MARK_RADIUS)
	var forward := -_player.global_transform.basis.z
	var heading := Vector2(forward.x, forward.z)
	if heading.length_squared() > 0.0001:
		heading = heading.normalized()
		_marks.draw_line(here, here + heading * PLAYER_NEEDLE, UITheme.SURFACE, 4.0)
		_marks.draw_line(here, here + heading * PLAYER_NEEDLE, UITheme.ON_SURFACE, 2.0)
	# Dark collar first: the marker has to read on the green wash of an open room,
	# on the red wash of a sealed one, and on a chip it happens to sit over.
	_marks.draw_circle(here, PLAYER_MARK_RADIUS + 1.5, UITheme.SURFACE)
	_marks.draw_circle(here, PLAYER_MARK_RADIUS, UITheme.ON_SURFACE)


# --- STATE READERS ----------------------------------------------------------

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


## The Curator, or null when there is nothing hunting.
##
## Same private-field hop as _required_camera(), and guarded the same way, with
## one extra step: `_watcher` may hold a freed object, and a freed Object cannot
## be cast (`as CuratorMonster` raises before any guard gets a look in). So the
## Variant is checked for validity BEFORE it is narrowed.
func _curator() -> Node3D:
	var source := _enhancement_node()
	if source == null:
		return null
	var value: Variant = source.get("_watcher")
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	var node := value as Node3D
	if node == null or not node.is_inside_tree():
		return null
	# `active` is false on night 1, inside a pocket dimension, and whenever the
	# Curator is not in play. No hunt, no interference.
	return node if bool(node.get("active")) else null


## 0 when the watched feed is clean, 1 when the Curator is on top of its mount.
## Flat-plane distance -- see FEED_DEAD_RANGE.
func _feed_interference() -> float:
	var curator := _curator()
	if curator == null or _active < 0 or _active >= CAMS.size():
		return 0.0
	var mount: Vector3 = CAMS[_active]["pos"]
	var here := curator.global_position
	var distance := Vector2(here.x, here.z).distance_to(Vector2(mount.x, mount.z))
	return 1.0 - clampf((distance - FEED_DEAD_RANGE)
		/ maxf(0.001, FEED_NOISE_RANGE - FEED_DEAD_RANGE), 0.0, 1.0)


## The sustained floor every terminal page in the game already sits on: the
## blackout, the night number and the incident clock running out.
##
## Read out of GameManager rather than recomputed, for the reason its own header
## gives for keeping it in one place -- three of those terms are night-loop state
## this node has no business modelling, and a second copy would let the CCTV
## workstation report a healthier signal than the protocol screen. Guarded
## because the tablet has to keep working in the standalone map scene and in the
## headless suites, neither of which builds a GameManager.
func _terminal_floor() -> float:
	var game := _game_manager()
	if game == null or not game.has_method("_night_corruption"):
		return 0.0
	return clampf(float(game.call("_night_corruption")), 0.0, 1.0)


# --- SIGNAL HEALTH ----------------------------------------------------------

## Chase the corruption target and push it at the frame. The whole horror beat
## lives here; the frame turns the number into murk, dropped lines, speckle,
## broken rules, a rotting title and a falling integrity percentage, and drops
## every time-varying one of those under reduced_flashes on its own.
func _update_signal(delta: float) -> void:
	var near := _feed_interference()
	var target := maxf(near, _terminal_floor())
	if _signal_snap:
		_signal_snap = false
		_signal_level = target
	else:
		_signal_level = move_toward(_signal_level, target, SIGNAL_RATE * delta)
	_push_corruption()

	# One spike on arrival, then silence until the feed has cleared. The spike is
	# the frame's own transient channel, so it composes with the sustained level
	# instead of overwriting it.
	if not _feed_alarm and near >= ALARM_ENTER:
		_feed_alarm = true
		_frame.pulse_corruption(ALARM_PULSE, ALARM_PULSE_SECONDS)
		_sfx("terminal_beep", ALARM_VOLUME_DB, ALARM_PITCH)
	elif _feed_alarm and near < ALARM_LEAVE:
		_feed_alarm = false

	# The picture itself. Driven by the Curator term ALONE: the night floor may
	# rot a feed, but it must never take one off the air.
	var dead := clampf((near - FEED_DEAD_ONSET) / maxf(0.001, 1.0 - FEED_DEAD_ONSET),
		0.0, 1.0)
	_dropout.color.a = dead * FEED_DEAD_ALPHA
	_lost_plate.visible = dead >= LOST_PLATE_AT


## Hand the level to TerminalFrame, quantised onto SIGNAL_STEP.
##
## set_corruption() repaints the whole page -- every chrome label, both rules,
## the meter, the noise field -- so calling it per frame during a ramp would run
## a full render 60 times a second for a change nobody can see. On the step grid
## a full 0 -> 1 ramp costs 25 renders, and 0.0 and 1.0 both land exactly on it.
func _push_corruption(force: bool = false) -> void:
	if _frame == null:
		return
	var level := clampf(snappedf(_signal_level, SIGNAL_STEP), 0.0, 1.0)
	if not force and is_equal_approx(level, _signal_applied):
		return
	_signal_applied = level
	_frame.set_corruption(level)


# --- INPUT ------------------------------------------------------------------

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


# GameManager owns PlayerController.controls_enabled, the night counter, the
# shift clock, the core state and the terminal corruption floor. Sibling node in
# the main scene, same lookup _toggle() already used to flash the office-only
# refusal -- cached now, because three of those five are read every frame the
# tablet is up and a by-name child lookup a frame is not free.
func _game_manager() -> Node:
	if is_instance_valid(_game):
		return _game
	var parent := get_parent()
	if parent == null:
		return null
	_game = parent.get_node_or_null("GameManager")
	return _game


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
			game.call("_flash", tr("CAM_ACCESS_OFFICE_ONLY"), UITheme.WARNING)
		_sfx("fail")
		return
	_open = not _open
	# `_layer.visible` is _step_raise's to set: the page appears when the shell is
	# most of the way up, not on the frame the key was pressed.
	_sfx("tablet_open" if _open else "tablet_click")
	# Stage 10 ruled that a device and the tablet cannot be held at once. Rather
	# than refuse the tablet -- which would lock CCTV away for as long as the
	# operator carries a tool -- the belt re-derives what is in the hands: the
	# carried body hides while the tablet is up and comes back when it goes down.
	# It never leaves its slot, so nothing is dropped and nothing is lost.
	var hands := _game_manager()
	if hands != null and hands.has_method("_sync_belt"):
		hands.call("_sync_belt")
	if _open:
		_player.controls_enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_sync_night()
		_refresh_map_locks()
		_push_status(true)
		# Accessibility and quality can both have been changed from the pause
		# menu since the tablet was last raised. TerminalFrame also listens to
		# SettingsManager.settings_changed, so this is a second belt for the
		# case where the settings node only joined its group after _ready.
		_frame.refresh()
		# Layout has not run yet for a layer that was hidden; force one matte
		# repaint from whatever the frame reports once it has.
		_window = Rect2()
		# force: the feed being restored is by definition the active one, and
		# raising the tablet has to put its picture back on the window and
		# start paying for its redraws again.
		_switch_to(_active, true)
	else:
		_update_floodlight()
		# A hidden CanvasLayer draws nothing, but TerminalFrame would happily keep
		# re-rendering a corrupted page at GLITCH_HZ behind it. Zeroing the level
		# is what puts its _process back to sleep.
		_signal_level = 0.0
		_signal_snap = true
		_feed_alarm = false
		_push_corruption(true)
		# _update_signal owns these and does not run while the tablet is down, so
		# a feed that died on the way out would still be dead for the first frame
		# of the next raise -- on whatever camera that raise lands on.
		_dropout.color.a = 0.0
		_lost_plate.visible = false
		_player.controls_enabled = _controls_allowed()
		# There is no camera to give back any more: the feeds render into their
		# own SubViewports, so the player's camera was never taken away. All
		# lowering the tablet has to do is stop paying for the feed it showed.
		_refresh_feed_wants()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _player_is_in_office() -> bool:
	if _player == null:
		return false
	var position := _player.global_position
	return position.x >= -34.5 and position.x <= -15.5 \
		and position.z >= -6.5 and position.z <= 6.5


## Re-read the night. Called on every open, which is the only moment the number
## can have changed under us: a night advances behind GameManager's night-done
## overlay, and that overlay closes the tablet on its way up.
func _sync_night() -> void:
	_night_cached = _current_night()


## Push the status cluster: night, shift clock, core state.
##
## All three come from GameManager, which computes them for the fail, win and
## protocol pages already -- one number, one wording, whichever screen the player
## is looking at. Without a GameManager the clock blanks to TerminalFrame's em
## dash and the core chip hides itself, which is the honest reading for a tablet
## running in the standalone map scene.
##
## `force` on open; otherwise only when something the cluster prints has actually
## changed, because set_status() repaints the entire page.
func _push_status(force: bool) -> void:
	if _frame == null:
		return
	var game := _game_manager()
	var seconds := -1.0
	var core_key := ""
	var core_level := TerminalFrame.CORE_NOMINAL
	if game != null:
		if game.has_method("_shift_clock_seconds"):
			seconds = float(game.call("_shift_clock_seconds"))
		if game.has_method("_core_state"):
			var state: Variant = game.call("_core_state")
			if state is Array and (state as Array).size() >= 2:
				core_key = String((state as Array)[0])
				core_level = int((state as Array)[1])
	var minute := int(seconds / 60.0) if seconds >= 0.0 else -1
	if not force and minute == _status_minute and core_key == _status_core \
			and core_level == _status_level:
		return
	_status_minute = minute
	_status_core = core_key
	_status_level = core_level
	_frame.set_status(_night_cached, seconds, core_key, core_level)


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
	# Hand the window the new feed's texture, then re-price the feeds: the one
	# being left stops being paid for in the same breath, or a shift spent
	# cycling would end with eleven viewports all drawing.
	if _picture != null:
		_picture.texture = _feed_views[index].get_texture()
	_refresh_feed_wants()
	_cam_label.text = String(CAMS[index]["id"])
	# The room name is the frame's title, so it rots with the rest of the page
	# when the feed is being interfered with.
	_frame.set_title(String(CAMS[index]["label"]))
	_static_alpha = STATIC_FLASH_REDUCED if _reduced_flashes() else STATIC_FLASH_PEAK
	# A cut to a contaminated feed has to land as a cut. Chasing the new level
	# over a second would turn the one moment the picture tells the truth into a
	# slow dissolve the operator reads as a rendering artefact.
	_signal_snap = true
	_feed_alarm = false
	_update_floodlight()
	# The live feed's chip holds the pressed look. Colour AND text weight: the
	# theme's `font_pressed_color` never applies to a resting button, so a chip
	# wearing the pressed stylebox alone kept MUTED digits on an accent fill.
	for i in range(_buttons.size()):
		if i == index:
			_buttons[i].add_theme_stylebox_override("normal", _chip_active)
			_buttons[i].add_theme_color_override("font_color", UITheme.ON_SURFACE)
		else:
			_buttons[i].remove_theme_stylebox_override("normal")
			_buttons[i].remove_theme_color_override("font_color")
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
	# Ahead of the early return: from 10.3 the office monitors hold feeds while
	# the tablet is DOWN, and a pacer that only ran on a raised tablet would
	# leave a wall of six screens frozen on whatever they last drew.
	_step_feeds(delta)
	# Same placement, same reason: the second half of the raise animation plays
	# with `_open` already false, and it is the half that stows the tablet.
	_step_raise(delta)
	if not _open:
		return
	_time += delta
	var reduced := _reduced_flashes()
	# A recording tally is a pulsing element, so it holds steady for a player who
	# has asked for that; the channel designator beside it still says the feed is
	# live, and the lamp is still lit.
	_rec_dot.visible = true if reduced else fmod(_time, REC_PERIOD) < REC_DUTY
	_sync_window()
	_push_status(false)
	_update_signal(delta)
	# The map overlays track the player, the pan and the objective, all of which
	# move under us; redrawing two mouse-ignoring Controls is cheaper than
	# working out which of the three changed, and neither runs while the tablet
	# is down because this function returns above.
	_cone.queue_redraw()
	_marks.queue_redraw()
	if _static_alpha > 0.0:
		_static_alpha = maxf(0.0, _static_alpha - delta * 4.0)
		# The per-frame random jitter is what makes the burst read as static
		# rather than as a dissolve -- and it is also, precisely, a strobe at
		# frame rate. A player who asked for reduced flashing gets the smooth
		# fade instead, off the lower ceiling set in _switch_to.
		_static_rect.color.a = _static_alpha if reduced \
			else _static_alpha * randf_range(0.6, 1.0)
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


# --- LEGEND -----------------------------------------------------------------

## TerminalFrame's footer legend, built out of the catalogue row that already
## carries this screen's controls.
##
## CAM_HINT_CONTROLS is one line of "cap — description" hints separated by "|",
## in both shipped locales. Split it and the footer renders real key caps; keep
## it whole and it is a sentence pretending to be a legend. Both halves go back
## through tr() inside the frame, which returns an unknown string unchanged, so
## already-translated fragments pass through untouched.
##
## The fallback is the whole row as one entry, which is exactly what the screen
## showed before -- a catalogue edit can therefore make this uglier, never
## broken. See the block at the bottom for the four rows that would retire it.
func _legend_entries() -> Array:
	var entries: Array = []
	var line := tr("CAM_HINT_CONTROLS")
	for chunk in line.split(LEGEND_SEPARATOR, false):
		var piece := chunk.strip_edges()
		if piece == "":
			continue
		var cut := piece.find(LEGEND_SPLIT)
		if cut < 0:
			entries.append(["", piece])
		else:
			entries.append([piece.substr(0, cut).strip_edges(),
				piece.substr(cut + LEGEND_SPLIT.length()).strip_edges()])
	if entries.is_empty():
		entries.append(["", line])
	return entries


## Two things on this screen do not re-translate themselves.
##
## The legend is built from translated FRAGMENTS rather than from keys -- see
## _legend_entries -- and TerminalFrame rebuilds its footer on this notification
## from the strings it was last handed, which would be the previous language's.
## The mini-map's eleven room labels are plain Labels whose text was resolved
## once at build time; nothing else was ever going to refresh them.
func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED:
		return
	for i in range(_room_labels.size()):
		_room_labels[i].text = tr(String(ROOMS[i][0]))
	if _lost_label != null:
		_lost_label.text = tr("TERM_SIGNAL_LOST")
	if _frame != null:
		_frame.set_keys(_legend_entries())


## True when the player has asked for reduced flashing.
##
## Same resolution as FirstMuseumMap._process and GameplayEnhancements'
## _update_void / _update_watch: one group lookup, null-guarded, field read via
## `.get()`. Polled rather than cached because those three poll it too, and
## because the only caller runs while the tablet is up -- a lookup a frame for
## the seconds the operator is actually watching a feed.
func _reduced_flashes() -> bool:
	var settings := get_tree().get_first_node_in_group("settings_manager")
	return settings != null and bool(settings.get("reduced_flashes"))


func _sfx(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var am := get_tree().get_first_node_in_group("audio_manager")
	if am != null and am.has_method("play_sfx"):
		am.play_sfx(sound, volume_db, pitch)


# --- STRINGS ----------------------------------------------------------------
#
# Every player-visible string on this screen is a catalogue key: the eleven feed
# names and eleven room names (CAM_*), the controls line (CAM_HINT_CONTROLS), the
# dead-feed plate (TERM_SIGNAL_LOST), the masthead and night readout the frame
# owns (HUD_PROTO_HEADER, HUD_NIGHT) and the core chip GameManager hands over
# (TERM_CORE_*). The one literal is the channel designator, "CAM 05", which is
# an equipment address and identical in both locales.
#
# One row would still be worth adding, and only one: a "cap / description" pair
# per control, to retire _legend_entries()' split of CAM_HINT_CONTROLS. It is
# cosmetic -- the split already produces the same four key caps out of the row
# that exists -- and it would say the same four hints twice in the catalogue, so
# it is filed as a preference rather than a request.
