extends Node
# Night-shift anomaly loop for the First Museum (steps 2-8 of the plan).
#
# Install: add a plain Node to the main scene (next to the map node and
# the SecurityCameraTablet node) and attach this script. Everything else
# is built at runtime.
#
# Flow:
#   1. Day - the player explores the museum.
#   2. Entering the office triggers the blackout (map handles lights).
#   3. A few seconds later - containment breach: the dome shatters and
#      a random anomaly starts. A timer begins.
#   4. The office alarm terminal shows the anomaly readout and protocol.
#   5. The player takes the right device from Equipment Storage and
#      applies it at the dome before the timer runs out.
#
# Controls: E - take device / read terminal / apply at the dome,
#           G - drop the carried device, ENTER - retry after a fail.

const ACCIDENT_DELAY := 4.0
const NIGHT_TIMER := 240.0
const INTERACT_DISTANCE := 2.8
const APPLY_DISTANCE := 3.4

# --- Kill plane -------------------------------------------------------------
# Every legitimate walkable surface in this game has its top face at y = 0.0:
# room floors are boxes centred at y = -0.08 with height 0.16 (see
# FirstMuseumMap._add_room) and "Forecourt Ground" is centred at y = -0.10
# with height 0.2 (FirstMuseumMap._add_outdoor). The highest outdoor deck is
# the top entrance step at y = 0.22; nothing legitimate is below zero.
# -8.0 is therefore pure void: ~0.94 s of free fall at the player's gravity
# of 18.0 -- fast enough to read as a slip, deep enough never to misfire on
# step-up jitter (PlayerController.step_height is 0.38).
# Pocket-dimension arenas are built around RiftTrialManager.ORIGIN (y = 72)
# and run their own kill plane at ORIGIN.y - 14.0, so they never reach this.
const KILL_PLANE_Y := -8.0
# Marker3D created by FirstMuseumMap._add_player_spawn() at (0, 1.0, 46).
const FALL_SPAWN_NAME := "Player Spawn - Street"
const FALL_SPAWN_FALLBACK := Vector3(0, 1.0, 46)
# Reject a "last safe spot" left over from a pocket dimension (those sit ~72 m
# up) when picking where to drop the player back into the museum.
const FALL_SAFE_MAX_Y := 20.0

# Night progression: nights 2-3 open the locked wings and stack anomalies.
const MAX_NIGHT := 3
const SAVE_PATH := "user://museum_save.cfg"
const CALM_TIME := 12.0
const NIGHT_CONFIG := {
	1: {"count": 1, "timer": 240.0, "unlock": ""},
	2: {"count": 2, "timer": 200.0, "unlock": "Space Wing C"},
	3: {"count": 3, "timer": 170.0, "unlock": "Mass Wing D"},
}

const DOME_POS := Vector3(0, 1.2, 0)
const TERMINAL_POS := Vector3(-29, 1.4, 3.1)

const STATE_DAY := 0
const STATE_COUNTDOWN := 1
const STATE_ANOMALY := 2
const STATE_RESOLVED := 3
const STATE_FAILED := 4
const STATE_CALM := 5
const STATE_NIGHT_DONE := 6
const STATE_WIN := 7

# Anomaly types (step 2): terminal readout + required equipment id.
# title/readout — ключи перевода (const нельзя оборачивать в tr()),
# tr() вызывается там, где строки выводятся на экран.
const ANOMALIES := {
	"gravity_surge": {
		"title": "ANOMALY_GRAVITY_TITLE",
		"readout": "ANOMALY_GRAVITY_READOUT",
		"equipment": "gravity_anchor",
		"color": Color(0.62, 0.35, 0.95),
	},
	"temporal_drift": {
		"title": "ANOMALY_TEMPORAL_TITLE",
		"readout": "ANOMALY_TEMPORAL_READOUT",
		"equipment": "chrono_stabilizer",
		"color": Color(0.95, 0.68, 0.25),
	},
	"radiation_bloom": {
		"title": "ANOMALY_RADIATION_TITLE",
		"readout": "ANOMALY_RADIATION_READOUT",
		"equipment": "containment_rod",
		"color": Color(0.35, 0.90, 0.35),
	},
	"void_rift": {
		"title": "ANOMALY_VOID_TITLE",
		"readout": "ANOMALY_VOID_READOUT",
		"equipment": "field_emitter",
		"color": Color(0.25, 0.45, 0.95),
	},
	"echo_chamber": {
		"title": "ANOMALY_ECHO_TITLE",
		"readout": "ANOMALY_ECHO_READOUT",
		"equipment": "resonance_tuner",
		"color": Color(0.95, 0.42, 0.22),
	},
	"glass_bridge": {
		"title": "ANOMALY_GLASS_TITLE",
		"readout": "ANOMALY_GLASS_READOUT",
		"equipment": "phase_prism",
		"color": Color(0.78, 0.38, 0.92),
	},
	"mirror_maze": {
		"title": "ANOMALY_MIRROR_TITLE",
		"readout": "ANOMALY_MIRROR_READOUT",
		"equipment": "spectral_lens",
		"color": Color(0.55, 0.78, 0.95),
	},
	"yellow_halls": {
		"title": "ANOMALY_YELLOW_TITLE",
		"readout": "ANOMALY_YELLOW_READOUT",
		"equipment": "thread_spool",
		"color": Color(0.90, 0.80, 0.30),
	},
	"scrap_run": {
		"title": "ANOMALY_SCRAP_TITLE",
		"readout": "ANOMALY_SCRAP_READOUT",
		"equipment": "mass_clamp",
		"color": Color(0.55, 0.90, 0.75),
	},
	"ascent": {
		"title": "ANOMALY_ASCENT_TITLE",
		"readout": "ANOMALY_ASCENT_READOUT",
		"equipment": "thermal_chalk",
		"color": Color(0.95, 0.55, 0.65),
	},
}

# Короткое назначение ключевых приборов для экрана протокола (ключи перевода).
const TOOL_HINTS := {
	"gravity_anchor": "TOOL_GRAVITY_ANCHOR_HINT",
	"chrono_stabilizer": "TOOL_CHRONO_STABILIZER_HINT",
	"containment_rod": "TOOL_CONTAINMENT_ROD_HINT",
	"field_emitter": "TOOL_FIELD_EMITTER_HINT",
	"resonance_tuner": "TOOL_RESONANCE_TUNER_HINT",
	"phase_prism": "TOOL_PHASE_PRISM_HINT",
	"spectral_lens": "TOOL_SPECTRAL_LENS_HINT",
	"thread_spool": "TOOL_THREAD_SPOOL_HINT",
	"mass_clamp": "TOOL_MASS_CLAMP_HINT",
	"thermal_chalk": "TOOL_THERMAL_CHALK_HINT",
}

# Equipment (step 3): pedestal row along z=13 in Equipment Storage,
# clear of the ladder (z10), barrels (z15.8), racks (x-16.2) and the
# door corridor at x=-25.
# "name" — ключ перевода; tr() вызывается на месте вывода (метки, подсказки).
const EQUIPMENT := {
	"gravity_anchor":{"name":"TOOL_GRAVITY_ANCHOR_NAME","color":Color(.62,.35,.95),"position":Vector3(-33.4,0,9.2)},
	"chrono_stabilizer":{"name":"TOOL_CHRONO_STABILIZER_NAME","color":Color(.95,.68,.25),"position":Vector3(-30.75,0,9.2)},
	"containment_rod":{"name":"TOOL_CONTAINMENT_ROD_NAME","color":Color(.35,.90,.35),"position":Vector3(-28.1,0,9.2)},
	"field_emitter":{"name":"TOOL_FIELD_EMITTER_NAME","color":Color(.25,.45,.95),"position":Vector3(-21.9,0,9.2)},
	"spectral_lens":{"name":"TOOL_SPECTRAL_LENS_NAME","color":Color(.35,.85,.92),"position":Vector3(-19.25,0,9.2)},
	"phase_prism":{"name":"TOOL_PHASE_PRISM_NAME","color":Color(.78,.38,.92),"position":Vector3(-16.6,0,9.2)},
	"resonance_tuner":{"name":"TOOL_RESONANCE_TUNER_NAME","color":Color(.95,.42,.22),"position":Vector3(-33.4,0,15)},
	"mass_clamp":{"name":"TOOL_MASS_CLAMP_NAME","color":Color(.72,.70,.62),"position":Vector3(-30.75,0,15)},
	"thermal_chalk":{"name":"TOOL_THERMAL_CHALK_NAME","color":Color(.95,.28,.18),"position":Vector3(-28.1,0,15)},
	"memory_reel":{"name":"TOOL_MEMORY_REEL_NAME","color":Color(.32,.72,.95),"position":Vector3(-21.9,0,15)},
	"null_lantern":{"name":"TOOL_NULL_LANTERN_NAME","color":Color(.32,.25,.58),"position":Vector3(-19.25,0,15)},
	"thread_spool":{"name":"TOOL_THREAD_SPOOL_NAME","color":Color(.92,.82,.48),"position":Vector3(-16.6,0,15)},
}

var _map: Node = null
var _map_root: Node = null
var _player: Node3D = null
var _camera: Camera3D = null
var _core: MeshInstance3D = null
var _dome: Node3D = null
var _anomaly_light: OmniLight3D = null

var _state := STATE_DAY
var _accident_in := ACCIDENT_DELAY
var _time_left := NIGHT_TIMER
var _anomaly_id := ""
var _pulse := 0.0
var _night := 1
var _anomalies_left := 0
var _memory_reel_used := false
var _calm_time := 0.0
var _trial_active := false
var _trial_manager: Node
# Cached exhibit puzzle controller: _update_hint() asks for it every frame.
var _puzzle: Node = null

var _devices: Dictionary = {}
var _device_homes: Dictionary = {}
var _carried_id := ""

var _terminal_screen: MeshInstance3D = null
var _terminal_label: Label3D = null

var _hud: CanvasLayer = null
var _objective_label: Label = null
var _timer_label: Label = null
var _hint_label: Label = null
var _message_label: Label = null
var _protocol_layer: CanvasLayer = null
var _protocol_panel: PanelContainer = null
var _proto_title: Label = null
var _proto_item: Label = null
var _proto_purpose: Label = null
var _proto_status: Label = null
var _protocol_time := 0.0

# Тестовая консоль (F9): выбор измерения для проверки. Не влияет на прогресс.
var _admin_layer: CanvasLayer = null
var _admin_panel: PanelContainer = null
var _test_mode := false
# Состояние ввода на момент открытия консоли — восстанавливается при закрытии.
var _admin_prev_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _admin_prev_controls := true
var _pre_test_state := STATE_DAY
var _pre_test_time_left := 0.0
var _pre_test_calm := 0.0
var _pre_test_anomaly := ""
var _message_time := 0.0
# Fail and win live on their own CanvasLayer, above every screen a live shift
# can raise -- see the layer table above _build_hud().
var _overlay_layer: CanvasLayer = null
var _fail_overlay: ColorRect = null
var _fail_label: Label = null
var _win_overlay: ColorRect = null
var _win_label: Label = null
# True when this save has already reached the ending at least once, read from
# progress/completed. Only changes how the first objective of a run is framed.
var _run_completed := false
var _objective_entries: Dictionary = {}
var _objective_priorities: Dictionary = {}


func _ready() -> void:
	call_deferred("_initialize")


func _initialize() -> void:
	# Editor reloads can detach this node before an awaited frame. Initialize
	# only after entering a valid SceneTree and check again after each wait.
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_map = get_tree().get_first_node_in_group("museum_map")
	if _map == null:
		push_warning("GameManager: museum map not found (group 'museum_map')")
		return
	_map_root = _map.get_node_or_null("GeneratedMap")
	if _map_root == null:
		_map_root = _map
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player != null:
		_camera = _player.get_node_or_null("Player Camera") as Camera3D
	_core = _map_root.find_child("Anomalous Core", true, false) as MeshInstance3D
	_dome = _map_root.find_child("Containment Dome", true, false) as Node3D
	_night = _load_night()
	for n in range(2, _night + 1):
		_unlock_for_night(n)
	_build_devices()
	_build_terminal()
	_build_protocol_screen()
	_build_hud()
	# Тестовая консоль (F9) собирается только в отладочных сборках.
	if OS.is_debug_build():
		_build_test_admin()
	var trial_script := load("res://game/RiftTrialManager.gd")
	_trial_manager = trial_script.new() as Node
	_trial_manager.name = "RiftTrialManager"
	add_child(_trial_manager)
	_trial_manager.call("setup", self)
	# A save that has already seen the ending is not on its first night ever, so
	# it is not greeted with the first-night briefing that explains where the
	# security office is. OBJ_NIGHT_RESTART is the same sentence the game uses
	# every other time the core wakes up again, which is exactly what this is.
	if _run_completed:
		_set_objective(Loc.fmt("OBJ_NIGHT_RESTART", [_night]))
	else:
		_set_objective(Loc.fmt("OBJ_NIGHT_INTRO", [_night]))
	# Last, so the orientation can outrank whichever of those two was set.
	_teach_begin()


func _process(delta: float) -> void:
	if _map == null:
		return
	if _message_time > 0.0:
		_message_time -= delta
		if _message_label != null:
			_message_label.modulate.a = clampf(_message_time / 0.9, 0.0, 1.0)
	match _state:
		STATE_DAY:
			if bool(_map.get("_blackout_done")):
				_state = STATE_COUNTDOWN
				_accident_in = ACCIDENT_DELAY
				_set_objective(tr("OBJ_BLACKOUT"))
		STATE_COUNTDOWN:
			_accident_in -= delta
			if _accident_in <= 0.0:
				_start_accident()
		STATE_CALM:
			_calm_time -= delta
			if _calm_time <= 0.0:
				_start_accident()
		STATE_ANOMALY:
			_time_left -= delta
			_pulse += delta
			if _protocol_time > 0.0:
				_protocol_time -= delta
				if _protocol_time <= 0.0:
					_hide_protocol()
			if _timer_label != null:
				_timer_label.visible = true
				_timer_label.text = _format_time(_time_left)
			if is_instance_valid(_anomaly_light):
				_anomaly_light.light_energy = 1.5 + 0.7 * sin(_pulse * 3.0)
			if _time_left <= 0.0:
				_fail()
		_:
			pass
	# After the state machine, not before it: safe_teleport() captures
	# controls_enabled, awaits a physics frame and then puts the captured value
	# back. If the night timer expires on the very frame the falling player
	# crosses the kill plane, running this first would capture "enabled", _fail()
	# would freeze the player a few lines later, and the teleport would thaw them
	# again behind the fail overlay. Running it last means the freeze is already
	# in place when the capture happens.
	_check_kill_plane()
	_update_hint()
	# After _update_hint(), which reads the current orientation step: advancing
	# first would print the next step's hint one frame before its objective.
	_teach_process(delta)
	_sync_hud_visibility()


# The forecourt is an open lot: past its edge there is no floor, so a player
# who walks off falls forever and has to kill the process. This lives here
# because _process() already ticks every frame, already holds _player, already
# holds _map_root (which owns the spawn marker) and already knows whether a
# pocket-dimension trial is running.
func _check_kill_plane() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.global_position.y > KILL_PLANE_Y:
		return
	# Defence in depth, not the working mechanism: RiftTrialManager._process()
	# runs its own kill plane at ORIGIN.y - 14.0 (y < 58), so a trial player who
	# falls out of the arena is caught 66 m above KILL_PLANE_Y and never reaches
	# this line. Kept in case that check ever stops running -- the trial owns the
	# per-trial recovery rules, so delegate rather than respawn on the forecourt.
	if _trial_manager != null and bool(_trial_manager.call("is_active")):
		_trial_manager.call("recover_from_fall")
		return
	var target := _fall_respawn_point()
	if _player.has_method("safe_teleport"):
		# safe_teleport() zeroes velocity, restores DOWN gravity and one physics
		# frame later restores whatever controls_enabled was on entry -- so a
		# player who fell while a terminal overlay was up stays frozen.
		_player.call("safe_teleport", target, Vector3.DOWN)
	else:
		_player.set("velocity", Vector3.ZERO)
		_player.global_position = target
	_flash(tr("HUD_FALL_RESPAWN"), UITheme.WARNING)


# Prefer the last spot the player actually stood on -- PlayerController samples
# it into _last_safe_transform every 0.25 s while is_on_floor() is true -- and
# fall back to the street spawn marker built by _add_player_spawn().
func _fall_respawn_point() -> Vector3:
	var safe: Variant = _player.get("_last_safe_transform")
	if safe is Transform3D:
		var origin: Vector3 = (safe as Transform3D).origin
		if origin != Vector3.ZERO and origin.y > KILL_PLANE_Y \
				and origin.y < FALL_SAFE_MAX_Y:
			return origin + Vector3(0.0, 0.12, 0.0)
	if _map_root != null:
		var marker := _map_root.find_child(FALL_SPAWN_NAME, true, false) as Node3D
		if marker != null:
			return marker.global_position
	return FALL_SPAWN_FALLBACK


func _input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_F9 or event.keycode == KEY_F9):
		_toggle_test_admin()
		get_viewport().set_input_as_handled()
		return
	if _admin_layer != null and _admin_layer.visible:
		return
	# The ending cutscene owns the screen and carries its own skip binding, so
	# nothing belonging to a live shift may fire behind it. Cutscene does mark
	# that skip as handled, but only for the nodes it is reached before; this
	# guard does not depend on propagation order.
	if _ending_playing():
		return
	if _trial_active:
		return
	_teach_watch(event)
	if _protocol_layer != null and _protocol_layer.visible and (event.is_action_pressed("confirm") or event.is_action_pressed("interact")):
		# Dismissing the protocol by hand is the orientation's proof that the
		# player actually read it; letting it time out proves nothing. That is
		# why the flag is set here and not inside _hide_protocol().
		_teach_protocol_read = true
		_hide_protocol()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("confirm"):
		if _state == STATE_FAILED:
			_retry()
		elif _state == STATE_NIGHT_DONE:
			_advance_night()
		elif _state == STATE_WIN:
			# The curtain rolls into the ending by itself once WIN_HOLD is up;
			# this is the impatient player's way past that hold. It is no longer
			# a scene reload -- the reload happens after the ending has played,
			# in _on_ending_finished().
			_play_ending()
	elif event.is_action_pressed("drop_item"):
		_drop_device()
	elif event.is_action_pressed("interact"):
		_interact()


# --- Night flow -----------------------------------------------------------

func _start_accident() -> void:
	_state = STATE_ANOMALY
	if _anomalies_left <= 0:
		_anomalies_left = int(NIGHT_CONFIG[_night]["count"])
	_time_left = float(NIGHT_CONFIG[_night]["timer"])
	_pulse = 0.0
	_anomaly_id = str(ANOMALIES.keys().pick_random())
	var puzzle := get_tree().get_first_node_in_group("exhibit_puzzle_controller")
	if puzzle != null and puzzle.has_method("prepare_incident"):
		puzzle.prepare_incident(_anomaly_id, _night)
	var info: Dictionary = ANOMALIES[_anomaly_id]
	var color: Color = info["color"]
	# The atrium core remains an alarm beacon; the actual rupture is attached
	# to the randomly selected exhibit and must be treated there.
	_set_dome_breach(false, color)
	_tint_core(color, 2.4)
	if not is_instance_valid(_anomaly_light):
		_anomaly_light = OmniLight3D.new()
		_anomaly_light.name = "Anomaly Light"
		_anomaly_light.position = _incident_position() + Vector3(0, 2.4, 0)
		_anomaly_light.omni_range = 16.0
		_map_root.add_child(_anomaly_light)
	_anomaly_light.light_color = color
	# Tint the night fog toward the anomaly.
	var env: Variant = _map.get("_environment")
	if env is Environment:
		env.fog_light_color = color.darkened(0.65)
		env.volumetric_fog_albedo = color.lightened(0.2)
	# Terminal readout (step 5).
	if _terminal_label != null:
		_terminal_label.text = Loc.fmt("HUD_TERMINAL_BREACH", [tr(str(info["title"])), tr(str(info["readout"]))])
	_set_screen_color(color)
	_set_objective(Loc.fmt("OBJ_INCIDENT", [_incident_name(), _anomalies_left]))
	_flash(tr("HUD_CONTAINMENT_BREACHED"), UITheme.DANGER)
	_show_protocol(info, color)
	var am := _audio()
	if am != null:
		if am.has_method("set_alarm"):
			am.set_alarm(true)
		if am.has_method("set_anomaly_hum"):
			am.set_anomaly_hum(true, DOME_POS)


func _resolve() -> void:
	_state = STATE_RESOLVED
	# The device is spent in the containment field.
	var body: StaticBody3D = _devices.get(_carried_id)
	if body != null:
		body.queue_free()
	_devices.erase(_carried_id)
	_carried_id = ""
	# Calm the core, restore the dome.
	_tint_core(Color(0.45, 0.95, 0.75), 0.7)
	if is_instance_valid(_anomaly_light):
		_anomaly_light.queue_free()
	_set_dome_breach(false, Color(0.45, 0.95, 0.75))
	if _timer_label != null:
		_timer_label.visible = false
	# Emergency power: part of the lights come back, dimmed.
	var lights: Variant = _map.get("_powered_lights")
	if lights is Array:
		for l in lights:
			if is_instance_valid(l) and not l.visible:
				l.visible = true
				l.light_energy = l.light_energy * 0.45
	if _terminal_label != null:
		_terminal_label.text = tr("HUD_TERMINAL_RESTORED")
	_set_screen_color(Color(0.2, 0.8, 0.5))
	var am := _audio()
	if am != null:
		if am.has_method("set_alarm"):
			am.set_alarm(false)
		if am.has_method("set_anomaly_hum"):
			am.set_anomaly_hum(false)
		if am.has_method("play_sfx"):
			am.play_sfx("resolve")
	_anomalies_left -= 1
	if _anomalies_left > 0:
		_state = STATE_CALM
		_calm_time = CALM_TIME
		_respawn_devices()
		_set_objective(tr("OBJ_CORE_UNSTABLE"))
		_flash(tr("HUD_ANOMALY_CLEARED"), UITheme.SUCCESS)
	elif _night >= MAX_NIGHT:
		_win()
	else:
		_state = STATE_NIGHT_DONE
		_set_player_controls(false)
		_save_night(_night + 1)
		# A player who survived a whole night with orientation steps still open
		# has learnt the game by playing it. Closing the sequence here is what
		# stops it from following them into night 2, where its objective line
		# would sit under the incident's and never come back.
		_teach_finish(false)
		_set_objective(Loc.fmt("OBJ_NIGHT_DONE", [_night]))
		_flash(Loc.fmt("HUD_NIGHT_COMPLETE", [_night]), UITheme.SUCCESS)


# The fail / night-done / win screens are read-only panels the player can only
# answer with "confirm", which shares the gamepad A button with "jump". Freezing
# the player keeps the two apart (PlayerController only polls "jump" while
# controls_enabled is true) and stops them walking around behind the overlay.
#
# This query is the single owner of that rule. Nothing outside may decide on its
# own that control is due back: the CCTV tablet asks here when it closes, and
# PlayerController.safe_teleport() restores what it captured instead of forcing
# true. Without one owner a terminal overlay can be up while the player is
# mobile, and a single gamepad A press is polled as "jump" by
# PlayerController._physics_process and as "confirm" by _input() below.
func player_controls_allowed() -> bool:
	return _state != STATE_FAILED and _state != STATE_NIGHT_DONE \
		and _state != STATE_WIN


# Callers must move _state first, so `enabled` always agrees with
# player_controls_allowed(). _admin_prev_controls is kept in sync so closing the
# F9 console cannot restore control that an overlay revoked while the console
# was open.
func _set_player_controls(enabled: bool) -> void:
	_admin_prev_controls = enabled
	if not enabled:
		_close_camera_tablet()
	if _player != null and is_instance_valid(_player):
		_player.set("controls_enabled", enabled)


# The CCTV tablet owns the viewport camera and the free cursor while it is open,
# and hands control back when it closes, so a transition that revokes control
# must not leave it up: the overlay would sit over a frozen wall-mount feed, and
# _retry() / _advance_night() would resume the night with that camera still
# current instead of the player's. Closing it here (one place, on the way down)
# is what keeps those two resume paths clean. Sibling lookup, mirroring the way
# SecurityCameraTablet._toggle() reaches back for this node.
func _close_camera_tablet() -> void:
	var tablet := _camera_tablet()
	if tablet != null and tablet.has_method("close"):
		tablet.call("close")


func _camera_tablet() -> Node:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("SecurityCameraTablet")


## True while the CCTV feed is up. The HUD asks because the tablet is a
## full-screen diegetic screen with no opaque backing of its own: anything the
## night HUD draws lands on top of the feed's own chrome no matter which
## CanvasLayer it sits on. Same sibling lookup and same `_open` flag
## MenuManager._gameplay_mouse_mode() reads.
func _camera_tablet_open() -> bool:
	var tablet := _camera_tablet()
	return tablet != null and bool(tablet.get("_open"))


func _fail() -> void:
	if _trial_manager != null:
		# abort() hands control back to the player; disable it again below.
		_trial_manager.call("abort")
	_trial_active = false
	_state = STATE_FAILED
	_set_player_controls(false)
	var am := _audio()
	if am != null:
		if am.has_method("set_alarm"):
			am.set_alarm(false)
		if am.has_method("set_anomaly_hum"):
			am.set_anomaly_hum(false)
		if am.has_method("play_sfx"):
			am.play_sfx("fail")
	if _fail_overlay != null:
		_fail_overlay.visible = true
	if _fail_label != null:
		var anomaly_title := tr("ANOMALY_UNKNOWN")
		if ANOMALIES.has(_anomaly_id): anomaly_title = tr(str(ANOMALIES[_anomaly_id]["title"]))
		var tip := tr("FAIL_TIP_DEFAULT")
		if _trial_manager != null and _trial_manager.has_method("trial_fail_tip"):
			tip = str(_trial_manager.call("trial_fail_tip"))
		_fail_label.text = "%s\n\n%s\n%s\n\n%s\n\n%s" % [tr("FAIL_TITLE"),
			Loc.fmt("FAIL_REASON", [anomaly_title]),
			Loc.fmt("FAIL_PROGRESS", [_night, _anomalies_left]),
			Loc.fmt("FAIL_TIP", [tip]), tr("FAIL_RETRY")]
	if _timer_label != null:
		_timer_label.visible = false


func _retry() -> void:
	# Retry restarts the night in place (no scene reload), so this is the path
	# that resumes play. Control comes back last, once _start_accident() has left
	# STATE_FAILED: player_controls_allowed() answers from _state, so enabling
	# earlier would contradict the query the tablet and the kill plane now trust.
	if _fail_overlay != null:
		_fail_overlay.visible = false
	# Return the carried device to its pedestal.
	if _carried_id != "":
		var body: StaticBody3D = _devices.get(_carried_id)
		if body != null:
			body.get_parent().remove_child(body)
			_map_root.add_child(body)
			body.scale = Vector3.ONE
			body.global_transform = _device_homes[_carried_id]
			_set_collision(body, true)
		_carried_id = ""
	# Devices spent earlier in the night come back; a fresh anomaly rolls.
	_respawn_devices()
	_anomalies_left = int(NIGHT_CONFIG[_night]["count"])
	_start_accident()
	_set_player_controls(true)


# --- Night progression ------------------------------------------------------

func _advance_night() -> void:
	_night += 1
	_save_night(_night)
	_unlock_for_night(_night)
	_respawn_devices()
	_anomalies_left = int(NIGHT_CONFIG[_night]["count"])
	_state = STATE_COUNTDOWN
	_accident_in = 8.0
	# After the state leaves STATE_NIGHT_DONE, so the assignment agrees with
	# player_controls_allowed() (see _retry()).
	_set_player_controls(true)
	_set_objective(Loc.fmt("OBJ_NIGHT_RESTART", [_night]))
	var wing := str(NIGHT_CONFIG[_night].get("unlock", ""))
	if wing != "":
		_flash(Loc.fmt("HUD_NIGHT_WING_UNLOCKED", [_night, wing]), UITheme.ACCENT)
	else:
		_flash(Loc.fmt("HUD_NIGHT", [_night]), UITheme.ACCENT)


# The end of the third night, in three beats:
#
#   1. the curtain. Opaque and fading in over WIN_FADE, so the museum goes out
#      instead of showing through a green tint that reads as "another
#      notification". It carries HUD_WIN, the scoreboard for the run that just
#      ended -- composed now rather than at scene build, because a label written
#      once when the HUD was assembled has nothing to say about this run.
#   2. the ending cutscene, WIN_HOLD later. See _play_ending().
#   3. the main menu, once the cutscene ends or is skipped.
#
# The save records that this file reached the ending, separately from the night
# the next shift starts on -- see _save_night().
func _win() -> void:
	_state = STATE_WIN
	# The reload behind the ending builds a fresh PlayerController, so control is
	# never handed back here; Cutscene borrows the player it finds frozen and
	# restores exactly that.
	_set_player_controls(false)
	if _timer_label != null:
		_timer_label.visible = false
	_hide_protocol()
	# Whatever is still open on the orientation checklist, three nights closes it.
	_teach_finish(false)
	_refresh_win_label()
	if _win_overlay != null:
		_win_overlay.visible = true
		_win_overlay.modulate.a = 0.0
		create_tween().tween_property(_win_overlay, "modulate:a", 1.0, WIN_FADE)
	_run_completed = true
	_save_night(1, true)
	_set_objective("")
	_roll_ending_after_curtain()


# --- The ending (stage 8.7) --------------------------------------------------
#
# Before this, "win" was one green overlay and then a scene reload straight back
# to the main menu -- the same reload the pause menu's "Main menu" button does,
# which is to say no ending at all: the run stopped rather than closed.
#
# The close is a 29 s shot list handed to game/Cutscene.gd, the node the museum's
# own prologue and intro already run on. Nothing about the camera, the letterbox,
# the captions, the cross-fades or the skip binding is re-implemented here; what
# lives here is which shots, and when the player is allowed to see them.


## Seconds the curtain holds at full opacity before the ending rolls. WIN_FADE
## closes it, this reads it. Confirm skips the remainder (see _input).
const WIN_HOLD := 2.6

## The ending's overlay layer. Cutscene builds its own CanvasLayer and leaves it
## at the engine default of 1, which is right for the opening -- that plays over
## an empty HUD on a paused tree -- and wrong here: the ending rolls at the end
## of a live shift, with the stamina panel (14) and the anomaly readout (11)
## still on screen. 16 clears every layer in the table above _build_hud() except
## the pause menu (20) and the F9 console (60), both of which must stay on top.
const ENDING_LAYER := 16

## The cutscene currently closing the run, or null. Freed by itself.
var _ending: Cutscene = null
## Set the first time the ending ends, so a stray "confirm" during the reload
## frame cannot start a second one on top of the first.
var _ending_rolled := false


## True while the ending owns the screen.
func _ending_playing() -> bool:
	return _ending != null and is_instance_valid(_ending) and _ending.is_playing()


func _roll_ending_after_curtain() -> void:
	await get_tree().create_timer(WIN_FADE + WIN_HOLD).timeout
	# The tree can be gone under the await (a quit, an editor reload), and the
	# F9 console can have pulled the run back out of STATE_WIN in the meantime.
	if not is_inside_tree() or _state != STATE_WIN:
		return
	_play_ending()


## Take the screen and play the close. Idempotent: the timer above and the
## player's "confirm" both call it, and only the first one does anything.
func _play_ending() -> void:
	if _ending_rolled or _ending != null:
		return
	_ending_rolled = true
	var cut := Cutscene.new()
	cut.name = "Ending Cutscene"
	# Parented to this plain Node rather than to the map: a Node3D under a Node
	# sits at the world origin, which is exactly the frame the shot list below is
	# authored in, and it keeps the ending alive if the map is ever rebuilt.
	add_child(cut)
	_ending = cut
	# Connect before start(), per Cutscene's contract: a degenerate shot list
	# finishes synchronously inside start() and would emit into nothing.
	cut.finished.connect(_on_ending_finished)
	cut.start(_ending_shots())
	if is_instance_valid(cut) and cut.is_playing():
		# The overlay only exists once start() has built it. Looked up by type
		# rather than by name so a rename inside Cutscene cannot silently drop
		# the ending back under the stamina panel.
		for child in cut.get_children():
			var overlay := child as CanvasLayer
			if overlay != null:
				overlay.layer = ENDING_LAYER
	# Lowered only now: start() has already posted the first shot with its fade
	# rect fully black, so the curtain is replaced rather than lifted, and the
	# museum is never briefly visible between the two.
	if _win_overlay != null:
		_win_overlay.visible = false


func _on_ending_finished(_skipped: bool) -> void:
	_ending = null
	if not is_inside_tree():
		return
	# Back to the main menu exactly the way MenuManager._to_main_menu() gets
	# there: the reload rebuilds the scene and MenuManager opens the main menu
	# over it. The museum's own opening does not replay -- it is gated on flags
	# in museum_progress.cfg that this run has already written.
	get_tree().paused = false
	get_tree().reload_current_scene()


## Four shots, 29 s: the atrium the player just saved, the workstation they sat
## at, the building from outside, and the closing card.
##
## Every camera position stands in geometry FirstMuseumMap actually builds, and
## the numbers are the ones its own prologue shot list documents: the Atrium is
## x +-15, z +-15 with the containment dome on the origin, a 2.6 m stanchion ring
## around it and rotunda benches at radius 8.4; the Watcher Office is x -35..-15,
## z +-7 with its monitor wall on the rail at (-25, 2.05, -2.20); the facade sign
## is at (0, 3.5, 35.2) and the forecourt walkway runs x 0, z 35..55 between two
## street-lamp rows at x +-4.5.
##
## Shot budget follows the prologue's: 8.0 s for the opening move and 7.0 s for
## everything after, because Cutscene's cross-fades cost a fixed fraction of each
## window (FADE_IN 0.12 + FADE_OUT 0.10) and prose needs the remainder. The
## museum is on emergency power by now -- _resolve() brings part of the mains
## back at 45% -- so these are dim interiors on purpose.
func _ending_shots() -> Array:
	return [
		# Rising off the core, which _resolve() has just tinted calm green.
		# z 5.6 and 10.5 both clear the stanchion ring, and the climb puts the
		# camera above the bench ring rather than through it.
		{"from": Vector3(0, 1.9, 5.6), "to": Vector3(0, 3.4, 10.5),
			"look": Vector3(0, 1.35, 0), "text": "STORY_END_01",
			"time": 8.0, "card": false},
		# The office, pulling back off the monitor wall: the prologue's arrival
		# shot run in reverse, which is the whole point of it.
		{"from": Vector3(-25.0, 1.8, 0.35), "to": Vector3(-25.0, 1.95, 2.4),
			"look": Vector3(-25.0, 2.05, -2.2), "text": "STORY_END_02",
			"time": 7.0, "card": false},
		# Outside, backing down the arrival axis away from the facade. x = 0
		# keeps the camera off both lamp rows, whose heads sit at y 3.25.
		{"from": Vector3(0, 2.6, 44.0), "to": Vector3(0, 3.6, 52.0),
			"look": Vector3(0, 3.5, 35.2), "text": "STORY_END_03",
			"time": 7.0, "card": false},
		# Closing card, on the spot the previous shot ended. STORY_ENDING is the
		# line this game has always ended on; it used to be printed under the win
		# scoreboard, and it is a closing card, so it is one now.
		{"from": Vector3(0, 3.6, 52.0), "to": Vector3(0, 3.6, 52.0),
			"look": Vector3(0, 3.5, 35.2), "text": "STORY_ENDING",
			"time": 7.0, "card": true},
	]


## True while any cutscene owns the viewport -- the museum's opening as well as
## the ending. The night HUD stands down for both (see _sync_hud_visibility).
func _cutscene_on_screen() -> bool:
	if _ending_playing():
		return true
	if _map == null:
		return false
	var opening: Variant = _map.get("_cutscene")
	return opening is Node and is_instance_valid(opening) \
		and opening.has_method("is_playing") and bool(opening.call("is_playing"))


## The night HUD is on layer 5 and Cutscene's overlay defaults to layer 1, so an
## objective band left standing would print straight across a letterboxed shot.
## Hiding the layer is cheaper and more honest than clearing four labels and
## restoring them afterwards.
func _sync_hud_visibility() -> void:
	if _hud == null:
		return
	var wanted := not _cutscene_on_screen()
	if _hud.visible != wanted:
		_hud.visible = wanted


func _load_night() -> int:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 1
	_run_completed = bool(config.get_value("progress", "completed", false))
	return clampi(int(config.get_value("progress", "night", 1)), 1, MAX_NIGHT)


# `completed` is a separate fact from `night`, and writing only the night is
# what made a finished game indistinguishable from one nobody had played: the
# player who had just watched the ending was reloaded into the first-night
# briefing ("Night 1. Look around the museum. The security office is in the
# west wing."), which frames the museum as somewhere they have never been.
# The existing row is loaded first so nothing else under progress/ is dropped;
# MenuManager._reset_progress() still wipes the file wholesale, which is what
# "reset" is supposed to mean.
func _save_night(night: int, completed := false) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("progress", "night", clampi(night, 1, MAX_NIGHT))
	if completed:
		config.set_value("progress", "completed", true)
		config.set_value("progress", "runs_completed",
			int(config.get_value("progress", "runs_completed", 0)) + 1)
	config.save(SAVE_PATH)


func _unlock_for_night(night: int) -> void:
	var wing := str(NIGHT_CONFIG.get(night, {}).get("unlock", ""))
	if wing != "" and _map != null and _map.has_method("unlock_wing"):
		_map.unlock_wing(wing)


func _audio() -> Node:
	return get_tree().get_first_node_in_group("audio_manager")


func _puzzle_controller() -> Node:
	# _update_hint() calls _incident_position() every frame while a device is
	# carried; re-query the group only when the cached node is gone or freed.
	if not is_instance_valid(_puzzle) or not _puzzle.is_inside_tree():
		_puzzle = get_tree().get_first_node_in_group("exhibit_puzzle_controller")
	return _puzzle


func _incident_position() -> Vector3:
	var puzzle := _puzzle_controller()
	if puzzle != null and puzzle.has_method("get_incident_origin"):
		return puzzle.get_incident_origin()
	return DOME_POS


func _incident_name() -> String:
	var puzzle := _puzzle_controller()
	if puzzle != null and puzzle.has_method("get_incident_name"):
		return puzzle.get_incident_name()
	return tr("EXHIBIT_CENTRAL_CORE")


func _sfx(sound: String, volume_db := 0.0) -> void:
	var am := _audio()
	if am != null and am.has_method("play_sfx"):
		am.play_sfx(sound, volume_db)


# --- Interaction (step 4) -------------------------------------------------

func _interact() -> void:
	if _state == STATE_FAILED or _player == null or _trial_active:
		return
	# Apply the carried device directly at the possessed exhibit.
	if _carried_id != "" and _state == STATE_ANOMALY and _near(_incident_position(), APPLY_DISTANCE):
		var info: Dictionary = ANOMALIES[_anomaly_id]
		if _carried_id == str(info["equipment"]):
			for gate in get_tree().get_nodes_in_group("resolution_gate"):
				if gate.has_method("can_resolve") and not gate.can_resolve():
					return
			_begin_trial()
		else:
			_flash(tr("HUD_WRONG_TOOL"), UITheme.DANGER)
		return
	# Pick up a device.
	if _carried_id == "":
		var target := _raycast_body()
		if target != null and target.is_in_group("equipment"):
			_pick_up(str(target.get_meta("equipment_id")))
			return
	# Read the terminal.
	if _near(TERMINAL_POS, INTERACT_DISTANCE) and _anomaly_id != "" and _state == STATE_ANOMALY:
		var info: Dictionary = ANOMALIES[_anomaly_id]
		var device_name := tr(str(EQUIPMENT[str(info["equipment"])]["name"]))
		_flash("%s -> %s" % [tr(str(info["title"])), device_name], UITheme.SUCCESS)
		_sfx("terminal_beep")
		# The alarm terminal prints the same anomaly-to-tool line the protocol
		# screen does, so reading it satisfies the protocol step as well. Without
		# this the step would be unclearable for anyone who let the panel time
		# out, and the orientation would never record a result.
		_teach_protocol_read = true


func _begin_trial() -> void:
	if _trial_manager == null or _player == null or _trial_active:
		return
	_trial_active = true
	_hide_protocol()
	set_objective("trial", tr("OBJ_TRIAL"), 50)
	_flash(tr("HUD_ENTER_POCKET"), UITheme.ACCENT)
	_trial_manager.call("begin", _anomaly_id, _player)


func _complete_trial() -> void:
	if not _trial_active:
		return
	_trial_active = false
	clear_objective("trial")
	if _test_mode:
		# Тестовый прогон: возвращаем состояние ночи как было до запуска.
		_test_mode = false
		_anomaly_id = _pre_test_anomaly
		_state = _pre_test_state
		_time_left = _pre_test_time_left
		_calm_time = _pre_test_calm
		if _timer_label != null and _state != STATE_ANOMALY:
			_timer_label.visible = false
		_flash(tr("ADMIN_TEST_DONE"), UITheme.SUCCESS)
		return
	_resolve()


func _pick_up(id: String) -> void:
	var body: StaticBody3D = _devices.get(id)
	if body == null or _camera == null:
		return
	_carried_id = id
	body.get_parent().remove_child(body)
	_camera.add_child(body)
	body.position = Vector3(0.42, -0.35, -0.75)
	body.rotation = Vector3.ZERO
	body.scale = Vector3(0.8, 0.8, 0.8)
	_set_collision(body, false)
	_flash(Loc.fmt("HUD_TOOL_TAKEN", [tr(str(EQUIPMENT[id]["name"]))]), UITheme.ON_SURFACE)
	if id == "memory_reel" and not _memory_reel_used and _state == STATE_ANOMALY:
		# Катушка памяти: одноразовый бонус времени за ночную смену.
		_memory_reel_used = true
		_time_left += 45.0
		_flash(tr("HUD_MEMORY_REEL_BONUS"), UITheme.ACCENT)
	_sfx("pickup")


func _drop_device() -> void:
	if _carried_id == "" or _player == null:
		return
	var body: StaticBody3D = _devices.get(_carried_id)
	_carried_id = ""
	if body == null:
		return
	body.get_parent().remove_child(body)
	_map_root.add_child(body)
	body.scale = Vector3.ONE
	body.rotation = Vector3.ZERO
	var forward := -_player.global_transform.basis.z
	body.global_position = _player.global_position + forward * 1.0 + Vector3(0, 0.35, 0)
	_set_collision(body, true)
	_sfx("drop")


func _raycast_body() -> Node:
	if _camera == null:
		return null
	var from := _camera.global_position
	var to := from - _camera.global_transform.basis.z * INTERACT_DISTANCE
	var params := PhysicsRayQueryParameters3D.create(from, to)
	if _player is PhysicsBody3D:
		params.exclude = [(_player as PhysicsBody3D).get_rid()]
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return null
	return hit.get("collider") as Node


func _near(point: Vector3, dist: float) -> bool:
	return _player != null and _player.global_position.distance_to(point) <= dist


func _set_collision(body: StaticBody3D, enabled: bool) -> void:
	body.collision_layer = 1 if enabled else 0
	for child in body.get_children():
		if child is CollisionShape3D:
			child.disabled = not enabled


# --- World construction (step 3 + 5) ---------------------------------------

func _build_devices() -> void:
	# Четыре сегмента верстаков у боковых стен; центральный проход x=-25
	# между дверью офиса (z=7) и реставрационной (z=17) остаётся свободным.
	for bench_x: float in [-30.75, -19.25]:
		for bench_z: float in [9.2, 15.0]:
			_static_box("Верстак оборудования",Vector3(bench_x,.55,bench_z),Vector3(6.8,1.1,1.25),Color(.12,.14,.15))
	var slot:=1
	for id in EQUIPMENT.keys():
		var info:Dictionary=EQUIPMENT[id]; var base:Vector3=info["position"]
		_static_box("Гнездо %02d"%slot,Vector3(base.x,1.14,base.z),Vector3(1.05,.08,.85),Color(.22,.25,.27))
		_spawn_device(id); slot+=1


func _respawn_devices() -> void:
	# Devices are spent when applied at the dome; bring the missing ones
	# back between anomalies, retries and nights.
	for id in EQUIPMENT.keys():
		var existing: Variant = _devices.get(id)
		if existing == null or not is_instance_valid(existing):
			_spawn_device(id)


func _spawn_device(id: String) -> void:
	var info: Dictionary = EQUIPMENT[id]
	var base: Vector3 = info["position"]
	var color: Color = info["color"]
	var body := StaticBody3D.new()
	body.name = str(info["name"])
	body.position = Vector3(base.x, 1.48, base.z)
	body.add_to_group("equipment")
	body.add_to_group("interactable")
	body.set_meta("equipment_id", id)
	body.set_meta("device_name", info["name"])
	_map_root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.55, 0.6, 0.55)
	shape.shape = box
	body.add_child(shape)
	match id:
		"gravity_anchor":
			_mesh_box(body, Vector3(0, -0.12, 0), Vector3(0.34, 0.22, 0.34),
				Color(0.16, 0.16, 0.2))
			_mesh_torus(body, Vector3(0, 0.08, 0), 0.14, 0.22,
				Color(0.3, 0.3, 0.36), 0.0, false)
			_mesh_sphere(body, Vector3(0, 0.08, 0), 0.09, color, 1.4)
		"chrono_stabilizer":
			_mesh_box(body, Vector3(0, 0, 0), Vector3(0.34, 0.34, 0.22),
				Color(0.2, 0.18, 0.14))
			var dial := _mesh_cylinder(body, Vector3(0, 0.02, 0.13), 0.12, 0.03,
				color, 1.1)
			dial.rotation_degrees = Vector3(90, 0, 0)
		"containment_rod":
			_mesh_cylinder(body, Vector3(0, 0, 0), 0.045, 0.62,
				Color(0.35, 0.37, 0.4))
			_mesh_sphere(body, Vector3(0, 0.36, 0), 0.08, color, 1.4)
			_mesh_box(body, Vector3(0, -0.24, 0), Vector3(0.16, 0.1, 0.16),
				Color(0.14, 0.14, 0.15))
		"field_emitter":
			_mesh_box(body, Vector3(0, -0.18, 0), Vector3(0.3, 0.12, 0.3),
				Color(0.15, 0.17, 0.2))
			_mesh_cone(body, Vector3(0, 0.02, 0), 0.19, 0.05, 0.3,
				Color(0.3, 0.34, 0.4))
			_mesh_sphere(body, Vector3(0, 0.26, 0), 0.07, color, 1.5)
		_:
			_mesh_box(body,Vector3(0,-.08,0),Vector3(.34,.18,.30),Color(.13,.15,.17))
			_mesh_torus(body,Vector3(0,.10,0),.11,.19,color,.8,false)
			_mesh_sphere(body,Vector3(0,.10,0),.06,color,1.4)
	var label := Label3D.new()
	label.text = tr(str(info["name"]))
	label.position = Vector3(0, 0.55, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34
	label.pixel_size = 0.0035
	label.modulate = color
	body.add_child(label)
	_devices[id] = body
	_device_homes[id] = body.global_transform


func _build_terminal() -> void:
	# Screen above the existing "Alarm Terminal" box in the office.
	_terminal_screen = MeshInstance3D.new()
	_terminal_screen.name = "Anomaly Terminal Screen"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.3, 0.8, 0.08)
	_terminal_screen.mesh = mesh
	_terminal_screen.position = TERMINAL_POS + Vector3(0, 0.75, 0)
	_map_root.add_child(_terminal_screen)
	_set_screen_color(Color(0.1, 0.3, 0.25))
	_terminal_label = Label3D.new()
	_terminal_label.name = "Anomaly Terminal Readout"
	_terminal_label.text = tr("HUD_TERMINAL_IDLE")
	# Faces the room centre (the desk side, -z).
	_terminal_label.position = TERMINAL_POS + Vector3(0, 0.75, -0.12)
	_terminal_label.rotation_degrees = Vector3(0, 180, 0)
	_terminal_label.font_size = 40
	_terminal_label.pixel_size = 0.003
	_terminal_label.modulate = Color(0.65, 0.95, 0.8)
	_terminal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_root.add_child(_terminal_label)


# --- Тестовая консоль (F9) --------------------------------------------------

# Значения — ключи перевода, tr() вызывается при построении кнопок.
const ADMIN_DESCRIPTIONS := {
	"gravity_surge": "ADMIN_DESC_GRAVITY",
	"temporal_drift": "ADMIN_DESC_TEMPORAL",
	"radiation_bloom": "ADMIN_DESC_RADIATION",
	"void_rift": "ADMIN_DESC_VOID",
	"echo_chamber": "ADMIN_DESC_ECHO",
	"glass_bridge": "ADMIN_DESC_GLASS",
	"mirror_maze": "ADMIN_DESC_MIRROR",
	"yellow_halls": "ADMIN_DESC_YELLOW",
	"scrap_run": "ADMIN_DESC_SCRAP",
	"ascent": "ADMIN_DESC_ASCENT",
}


func _build_test_admin() -> void:
	_admin_layer = CanvasLayer.new()
	_admin_layer.name = "Test Admin Console"
	_admin_layer.layer = 60
	_admin_layer.visible = false
	add_child(_admin_layer)
	var shade := ColorRect.new()
	# Modal: the console eats the mouse and freezes the player, so the standard
	# full-screen dim applies.
	shade.color = UITheme.SCRIM
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_admin_layer.add_child(shade)
	_admin_panel = PanelContainer.new()
	_admin_panel.anchor_left = 0.18
	_admin_panel.anchor_top = 0.06
	_admin_panel.anchor_right = 0.82
	_admin_panel.anchor_bottom = 0.94
	UITheme.apply_panel(_admin_panel)
	_admin_layer.add_child(_admin_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	_admin_panel.add_child(layout)
	var header := Label.new()
	header.text = tr("ADMIN_TITLE")
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_text(header, UITheme.TITLE, UITheme.ACCENT)
	layout.add_child(header)
	var sub := Label.new()
	sub.text = tr("ADMIN_SUBTITLE")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text(sub, UITheme.LABEL, UITheme.MUTED)
	layout.add_child(sub)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = UITheme.BORDER
	layout.add_child(divider)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for id: String in ANOMALIES.keys():
		var info: Dictionary = ANOMALIES[id]
		var accent: Color = info["color"]
		var button := Button.new()
		var desc_key := str(ADMIN_DESCRIPTIONS.get(id, ""))
		var desc := ""
		if desc_key != "":
			desc = tr(desc_key)
		button.text = "%s\n%s" % [tr(str(info["title"])), desc]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 62)
		# The console is mouse-driven with a free cursor, so it stays out of the
		# tab order deliberately (the `false` argument), not by accident.
		UITheme.apply_button(button, UITheme.LABEL, UITheme.ON_SURFACE, false)
		# `accent` is the anomaly's fiction colour -- the same Color that lights
		# the OmniLight3D and tints the fog, not a UI role -- so it survives the
		# migration as the resting border only: identity without inventing a
		# thirteenth text colour.
		button.add_theme_stylebox_override("normal", UITheme.stylebox(
			UITheme.SURFACE, accent, UITheme.BORDER_WIDTH, UITheme.RADIUS_MD))
		button.pressed.connect(_admin_select_dimension.bind(id))
		grid.add_child(button)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	layout.add_child(footer)
	var close := Button.new()
	close.text = tr("ADMIN_CLOSE")
	close.custom_minimum_size = Vector2(180, 42)
	UITheme.apply_button(close, UITheme.LABEL, UITheme.ON_SURFACE, false)
	close.pressed.connect(_toggle_test_admin)
	footer.add_child(close)
	var note := Label.new()
	note.text = tr("ADMIN_NOTE")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_text(note, UITheme.CAPTION, UITheme.MUTED)
	footer.add_child(note)


func _toggle_test_admin() -> void:
	if _admin_layer == null:
		return
	if _trial_active:
		_flash(tr("HUD_FINISH_TRIAL_FIRST"), UITheme.WARNING)
		return
	var opening := not _admin_layer.visible
	_admin_layer.visible = opening
	# Пока консоль открыта, игрок не вращает камеру и не перехватывает мышь.
	# При закрытии возвращаем ровно то состояние ввода, что было при открытии:
	# консоль могли вызвать поверх пульта видеонаблюдения, где курсор виден,
	# а управление игроком отключено (см. SecurityCameraTablet._toggle).
	if opening:
		_admin_prev_mouse_mode = Input.mouse_mode
		_admin_prev_controls = true
		if _player != null:
			var prev: Variant = _player.get("controls_enabled")
			if prev != null:
				_admin_prev_controls = bool(prev)
			_player.set("controls_enabled", false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if _player != null:
			_player.set("controls_enabled", _admin_prev_controls)
		Input.mouse_mode = _admin_prev_mouse_mode
	_sfx("tablet_click", -8.0)


func _admin_select_dimension(id: String) -> void:
	if _trial_active or not ANOMALIES.has(id):
		return
	_admin_layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_pre_test_state = _state
	_pre_test_time_left = _time_left
	_pre_test_calm = _calm_time
	_pre_test_anomaly = _anomaly_id
	_test_mode = true
	_anomaly_id = id
	_anomalies_left = maxi(_anomalies_left, 1)
	_time_left = 999999.0
	_pulse = 0.0
	_state = STATE_ANOMALY
	# Через того же владельца и уже после смены состояния: консоль F9 могли
	# открыть поверх экрана провала, где управление отключено намеренно.
	_set_player_controls(true)
	if _fail_overlay != null:
		_fail_overlay.visible = false
	if _win_overlay != null:
		_win_overlay.visible = false
	_hide_protocol()
	_flash(Loc.fmt("ADMIN_TEST_PREFIX", [tr(str(ANOMALIES[id]["title"]))]), UITheme.ACCENT)
	_begin_trial()


# --- HUD (step 8) -----------------------------------------------------------
#
# CANVAS LAYERS -- the whole project's stack, low to high, so that "what draws
# on top" is a decision instead of an accident of construction order:
#
#    5  Night HUD ................ here (objective, timer, hint, flash)
#   10  SecurityCameraTablet ..... the CCTV feed the player raises
#   11  GameplayEnhancements ..... anomaly effect readout
#   12  Protocol Screen .......... here
#   14  PlayerController ......... stamina panel
#   15  Terminal Overlays ........ here (fail / win)
#   16  Ending Cutscene .......... game/Cutscene.gd's own overlay, moved up to
#                                 this number by _play_ending()
#   20  MenuManager .............. main and pause menus
#   40  TutorialPrologue ......... the optional orientation replay scene
#   60  Test admin console ....... here, debug builds only
#
# HUD_LAYER is the floor: the night HUD is painted on the world and everything
# the player raises is held in front of it. It was never set before, so it fell
# back to 1 -- below the tablet by luck rather than by choice.
#
# OVERLAY_LAYER sits above every in-world screen (tablet, effects, protocol,
# stamina) because fail and win take the game away from the player: nothing
# belonging to a live shift may draw over them. It stays below the pause menu,
# which has to stay reachable, and below the F9 console.
const HUD_LAYER := 5
const OVERLAY_LAYER := 15
## Seconds the ending curtain takes to close. Long enough to read as a fade.
const WIN_FADE := 1.4


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "Night HUD"
	_hud.layer = HUD_LAYER
	add_child(_hud)
	# The objective band used to start at y = 0.01, which ran it straight through
	# the CCTV tablet's 30 px feed name at (52, 18) -- and the one objective that
	# names the camera to watch (OBJ_CCTV_CONFIRM, set by GameplayEnhancements) is
	# read with the tablet up. The tablet draws no opaque backing, so no z-order
	# separates the two glyph runs; the band moves instead. y = 0.10 clears both
	# the tablet's header row (which ends at 58 px of 900) and the timer box
	# above it, which ends at exactly 0.10.
	_objective_label = _make_label(Vector4(0.01, 0.10, 0.62, 0.19), UITheme.LABEL,
		UITheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_LEFT)
	_timer_label = _make_label(Vector4(0.40, 0.02, 0.60, 0.10), UITheme.TITLE,
		UITheme.DANGER, HORIZONTAL_ALIGNMENT_CENTER)
	_timer_label.visible = false
	_hint_label = _make_label(Vector4(0.10, 0.90, 0.90, 0.98), UITheme.BODY,
		UITheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_CENTER)
	_message_label = _make_label(Vector4(0.10, 0.40, 0.90, 0.52), UITheme.TITLE,
		UITheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_CENTER)
	_message_label.modulate.a = 0.0
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "Terminal Overlays"
	_overlay_layer.layer = OVERLAY_LAYER
	add_child(_overlay_layer)
	_fail_overlay = ColorRect.new()
	# A scrim, not a curtain: the night is still behind it and ENTER drops the
	# player straight back into it.
	_fail_overlay.color = UITheme.SCRIM
	_fail_overlay.anchor_right = 1.0
	_fail_overlay.anchor_bottom = 1.0
	_fail_overlay.visible = false
	_overlay_layer.add_child(_fail_overlay)
	_fail_label = Label.new()
	_fail_label.text = "%s\n\n%s" % [tr("FAIL_TITLE"), tr("FAIL_RETRY")]
	_fail_label.anchor_left = 0.12
	_fail_label.anchor_top = 0.18
	_fail_label.anchor_right = 0.88
	_fail_label.anchor_bottom = 0.82
	_fail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text(_fail_label, UITheme.TITLE, UITheme.DANGER)
	_fail_overlay.add_child(_fail_label)
	_win_overlay = ColorRect.new()
	# Opaque, unlike the fail scrim: at the end of the third night the museum
	# goes out instead of showing through a green tint. _win() fades it in.
	_win_overlay.color = UITheme.SURFACE
	_win_overlay.anchor_right = 1.0
	_win_overlay.anchor_bottom = 1.0
	_win_overlay.visible = false
	_overlay_layer.add_child(_win_overlay)
	_win_label = Label.new()
	_win_label.anchor_right = 1.0
	_win_label.anchor_bottom = 1.0
	_win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_win_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text(_win_label, UITheme.TITLE, UITheme.SUCCESS)
	_win_overlay.add_child(_win_label)
	_refresh_win_label()


## Compose the end card. Called from _win() and not only from _build_hud(): the
## curtain is the one screen that has to speak about the run that just finished,
## and a label written once at scene build has nothing to say.
##
## HUD_WIN alone now. It is the scoreboard -- "three nights done" -- and it no
## longer carries an ENTER prompt, because the curtain is a beat rather than a
## menu: it holds for WIN_HOLD and then rolls the ending on its own. STORY_ENDING
## used to be printed underneath it and is now the ending's closing card, where a
## closing line belongs.
func _refresh_win_label() -> void:
	if _win_label == null:
		return
	_win_label.text = tr("HUD_WIN")


## The protocol panel keeps the anomaly's own colour as its border: `accent` is
## the fiction colour that also drives the anomaly light and the fog, and the
## border is the one place UITheme allows a non-token colour to survive. The
## fill and the geometry come from the shared factory; only the generous 30/20
## content margins are kept, because they are this panel's layout.
func _protocol_style(accent: Color) -> StyleBoxFlat:
	return UITheme.stylebox(UITheme.SURFACE_RAISED, accent, UITheme.BORDER_WIDTH,
		UITheme.RADIUS_MD, 30, 20)


func _proto_label(size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text(label, size, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_protocol_screen() -> void:
	_protocol_layer = CanvasLayer.new()
	_protocol_layer.name = "Protocol Screen"
	_protocol_layer.layer = 12
	_protocol_layer.visible = false
	add_child(_protocol_layer)
	var dim := ColorRect.new()
	# SURFACE at the panel's own 72%, not UITheme.SCRIM (88%): the protocol screen
	# is a timed readout the player keeps walking behind, so it must not black the
	# museum out the way a modal does.
	dim.color = Color(UITheme.SURFACE, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_protocol_layer.add_child(dim)
	_protocol_panel = PanelContainer.new()
	_protocol_panel.anchor_left = 0.26
	_protocol_panel.anchor_top = 0.14
	_protocol_panel.anchor_right = 0.74
	_protocol_panel.anchor_bottom = 0.8
	_protocol_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Placeholder border until the first anomaly rolls; _show_protocol() repaints
	# it with that anomaly's colour.
	_protocol_panel.add_theme_stylebox_override("panel", _protocol_style(UITheme.BORDER_ACCENT))
	_protocol_layer.add_child(_protocol_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_protocol_panel.add_child(box)
	var header := _proto_label(UITheme.LABEL, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	header.text = tr("HUD_PROTO_HEADER")
	box.add_child(header)
	_proto_title = _proto_label(UITheme.TITLE, UITheme.DANGER, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_proto_title)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = UITheme.BORDER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)
	var need := _proto_label(UITheme.LABEL, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	need.text = tr("HUD_PROTO_TAKE")
	box.add_child(need)
	# The one thing the player has to leave the screen remembering, so it carries
	# the accent instead of each anomaly's own tint (which the border already
	# shows, and which no longer has to clear a text contrast ratio).
	_proto_item = _proto_label(UITheme.TITLE, UITheme.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_proto_item)
	_proto_purpose = _proto_label(UITheme.BODY, UITheme.ON_SURFACE, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_proto_purpose)
	_proto_status = _proto_label(UITheme.BODY, UITheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(_proto_status)
	var footer := _proto_label(UITheme.LABEL, UITheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	footer.text = tr("HUD_PROTO_FOOTER")
	box.add_child(footer)


func _show_protocol(info: Dictionary, accent: Color) -> void:
	if _protocol_layer == null:
		return
	var equip_id := str(info["equipment"])
	var equip_name := equip_id
	if EQUIPMENT.has(equip_id):
		equip_name = tr(str(EQUIPMENT[equip_id]["name"]))
	_proto_title.text = Loc.fmt("HUD_PROTO_TITLE", [tr(str(info["title"]))])
	_proto_item.text = equip_name.to_upper()
	var hint_key := str(TOOL_HINTS.get(equip_id, ""))
	_proto_purpose.text = tr(hint_key) if hint_key != "" else ""
	_proto_status.text = Loc.fmt("HUD_PROTO_STATUS", [_night, _incident_name()])
	_protocol_panel.add_theme_stylebox_override("panel", _protocol_style(accent))
	_protocol_layer.visible = true
	_protocol_time = 10.0
	var am := _audio()
	if am != null and am.has_method("play_sfx"):
		am.play_sfx("terminal_beep", -6.0, 0.9)


func _hide_protocol() -> void:
	_protocol_time = 0.0
	if _protocol_layer != null:
		_protocol_layer.visible = false



func _make_label(anchors: Vector4, size: int, color: Color,
		align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.anchor_left = anchors.x
	label.anchor_top = anchors.y
	label.anchor_right = anchors.z
	label.anchor_bottom = anchors.w
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text(label, size, color)
	# The outline stays a literal. It is not a palette colour: these four labels
	# are drawn straight onto the 3D museum, where the background is whatever the
	# player happens to be looking at, and a black halo is a legibility measure
	# rather than a surface. UITheme has no token for it by design.
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	_hud.add_child(label)
	return label


func _update_hint() -> void:
	if _hint_label == null or _player == null:
		return
	var hint := ""
	# The hint sits at y 0.90..0.98, which is where the tablet prints its own
	# control legend (bottom-left, 44 px up). The player cannot act on an
	# interaction prompt while holding the tablet up anyway -- controls are off --
	# so the prompt stands down for as long as the feed is on screen. The
	# objective line above does the opposite: it is moved, not hidden, because
	# reading which camera to watch is the whole reason the tablet is up.
	if _camera_tablet_open():
		_hint_label.text = ""
		return
	if _state != STATE_FAILED and _state != STATE_WIN and _state != STATE_NIGHT_DONE:
		if _carried_id != "":
			var carried_name := tr(str(EQUIPMENT[_carried_id]["name"]))
			if _state == STATE_ANOMALY and _near(_incident_position(), APPLY_DISTANCE):
				hint = Loc.fmt("HUD_HINT_APPLY", [carried_name])
			else:
				hint = Loc.fmt("HUD_HINT_CARRYING", [carried_name])
		else:
			var target := _raycast_body()
			if target != null and target.is_in_group("equipment"):
				hint = Loc.fmt("HUD_HINT_TAKE", [tr(str(target.get_meta("device_name")))])
			elif _state == STATE_ANOMALY and _near(TERMINAL_POS, INTERACT_DISTANCE):
				hint = tr("HUD_HINT_TERMINAL")
	# The orientation's key legend falls in behind the interaction prompts rather
	# than fighting them: a real "press E to take the null lantern" is always
	# more useful than the line telling the player what E is for.
	if hint == "":
		hint = _teach_hint()
	_hint_label.text = hint


func _set_objective(text: String) -> void:
	set_objective("game", text, 10)


func set_objective(source: String, text: String, priority := 10) -> void:
	if text == "":
		_objective_entries.erase(source)
		_objective_priorities.erase(source)
	else:
		_objective_entries[source] = text
		_objective_priorities[source] = priority
	_refresh_objective()


func clear_objective(source: String) -> void:
	_objective_entries.erase(source)
	_objective_priorities.erase(source)
	_refresh_objective()


func _refresh_objective() -> void:
	if _objective_label == null:
		return
	var text := ""
	var best := -999
	for source in _objective_entries:
		var priority := int(_objective_priorities.get(source, 0))
		if priority > best:
			best = priority
			text = str(_objective_entries[source])
	_objective_label.text = text


## Transient banner across the middle of the screen. `color` is the one thing
## every caller has to decide, and every caller now passes a UITheme role
## (DANGER for a breach, SUCCESS for a containment, WARNING for a recoverable
## slip, ACCENT for a milestone) rather than its own approximation of one --
## which is why the override below is the last raw colour call in the file.
func _flash(text: String, color: Color) -> void:
	if _message_label == null:
		return
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)
	_message_label.modulate.a = 1.0
	_message_time = 3.0


func _format_time(t: float) -> String:
	var s := maxi(int(ceil(t)), 0)
	return "%d:%02d" % [int(s / 60.0), s % 60]


# --- Orientation (stage 8.6) ------------------------------------------------
#
# The tutorial used to be a separate scene: a 17.4 x 29.4 x 5.2 m windowless
# charcoal box with twelve objects, its own Player and its own AudioManager, and
# neither a SettingsManager nor an InputBootstrap -- so the mouse sensitivity the
# player had saved did not apply inside it. Finishing it returned them to the
# MAIN MENU to press Start a second time, in a different context.
#
# The museum already owns everything that room was faking. It has a daytime
# segment (STATE_DAY, from the street spawn to the moment the player crosses the
# office threshold and FirstMuseumMap fires the blackout), a player, an audio
# manager, the saved settings, the real input map and the real controls. The
# orientation lives there now: one line in the objective band, one line in the
# hint label, and every step confirmed by the player doing the thing rather than
# acknowledging a prompt. The blackout is the payoff at the end of it.
#
# WHY THE LIST RUNS PAST THE BLACKOUT. Three of the steps -- the null lantern,
# the CCTV tablet, the protocol screen -- are the ones the old tutorial never
# taught at all, and none of the three can be taught in daylight: Equipment
# Storage is reachable only through the Watcher Office, the tablet refuses to
# come up anywhere but that office, and the protocol screen exists only while an
# anomaly does. Crossing into the office IS the blackout trigger
# (FirstMuseumMap.OFFICE_NIGHT_MIN_X..MAX_Z), so those three necessarily land in
# the first minutes of night one, which is also the first minute they are usable.
#
# WHY THERE IS NO HOLD-TO-SKIP METER. The old scene had one on ESC and it was
# right for that scene. In the museum ESC belongs to the pause menu -- MenuManager
# opens it on the first press and pauses the tree, which stops this node's
# _process and the meter with it -- and putting the hold on some other binding
# would be a control nobody could discover. The skip is instead the thing a
# player who does not want the orientation does anyway: walk to the office and
# work the shift. Finishing a night with steps outstanding records `skipped`
# (see _resolve and _win), which is the same on-disk answer the meter gave.
#
# THE CONTRACT ON DISK is unchanged and is now read here instead of by the menu:
#   tutorial/done    = every step was confirmed by a real action;
#   tutorial/skipped = the player got through without confirming them all.
# A skip deliberately does not clear `done`, so a later skipped replay of the
# optional TutorialPrologue scene cannot downgrade an honest completion.
# MenuManager no longer gates the Start button on either flag -- it cannot, with
# nothing to send the player to -- so the infinite "skip sends you back to the
# tutorial" loop that shipped once is now structurally impossible.

## Same file TutorialPrologue and FirstMuseumMap's cutscene flags use.
const TEACH_PROGRESS_PATH := "user://museum_progress.cfg"
## Metres of real walking that count as "you know how to move".
const TEACH_MOVE_DISTANCE := 6.0
## Pixels of accumulated mouse motion for the look step, from the old tutorial.
const TEACH_LOOK_DELTA := 260.0
## Seconds of sprinting, and the horizontal speed that counts as sprinting.
const TEACH_SPRINT_TIME := 0.6
const TEACH_SPRINT_SPEED := 5.0
## Above the game's own objective (10) so it owns the band through the day,
## below the incident (30) and the CCTV confirmation (40) so it can never mask a
## line the player must act on to finish the night.
const TEACH_PRIORITY := 20
## Largest distance a single frame may contribute to the move step. A teleport --
## the kill plane, a rift trial, safe_teleport() -- must not pass it for free.
const TEACH_MOVE_STEP_CAP := 1.0

## The remaining steps, front to back; empty when the orientation is not running.
var _teach_steps: Array = []
## Index into _teach_steps, or -1 when nothing is running.
var _teach_index := -1
var _teach_move := 0.0
var _teach_last_pos := Vector3.ZERO
var _teach_look := 0.0
var _teach_sprint := 0.0
var _teach_flashlight := false
var _teach_protocol_read := false


## The step list. Each row is an objective line (what to do, in the band) and a
## hint line (which key does it, at the bottom) -- the same split the old
## tutorial's checklist and caption had, mapped onto the two labels the night HUD
## already owns. Three of the old scene's hint keys are reused verbatim; its
## look hint is not, because it names the orientation sector, which no longer
## exists on the path to the office.
func _teach_rows() -> Array:
	return [
		{"id": "move", "obj": "TEACH_OBJ_MOVE", "hint": "TUT_HINT_MOVE"},
		{"id": "look", "obj": "TEACH_OBJ_LOOK", "hint": "TEACH_HINT_LOOK"},
		{"id": "sprint", "obj": "TEACH_OBJ_SPRINT", "hint": "TUT_HINT_SPRINT"},
		{"id": "flashlight", "obj": "TEACH_OBJ_FLASHLIGHT", "hint": "TUT_HINT_FLASHLIGHT"},
		{"id": "office", "obj": "TEACH_OBJ_OFFICE", "hint": "TEACH_HINT_OFFICE"},
		{"id": "lantern", "obj": "TEACH_OBJ_LANTERN", "hint": "TEACH_HINT_LANTERN"},
		{"id": "tablet", "obj": "TEACH_OBJ_TABLET", "hint": "TEACH_HINT_TABLET"},
		{"id": "protocol", "obj": "TEACH_OBJ_PROTOCOL", "hint": "TEACH_HINT_PROTOCOL"},
	]


func _teach_begin() -> void:
	if _teach_recorded():
		return
	if _night > 1:
		# This save has already worked a whole night. Teaching it to walk would
		# be an insult, and the steps would spend the rest of the run sitting
		# under the incident line where nobody would ever clear them. Record the
		# skip so the question is settled once instead of every reload.
		_teach_write(false)
		return
	_teach_steps = _teach_rows()
	_teach_index = 0
	if _player != null and is_instance_valid(_player):
		_teach_last_pos = _player.global_position
	_teach_show()


## Has this save already answered the orientation, either way?
func _teach_recorded() -> bool:
	var config := ConfigFile.new()
	if config.load(TEACH_PROGRESS_PATH) != OK:
		return false
	if bool(config.get_value("tutorial", "done", false)):
		return true
	return bool(config.get_value("tutorial", "skipped", false))


## Byte-for-byte the same write TutorialPrologue._write_progress() performs, and
## for the same reason: `done` is only ever set by a real completion, while a
## skip sets `skipped` alone and leaves an earlier completion standing. The
## existing file is loaded first because it also carries the two cutscene flags
## FirstMuseumMap writes, and a fresh ConfigFile would drop them.
func _teach_write(completed: bool) -> void:
	var config := ConfigFile.new()
	config.load(TEACH_PROGRESS_PATH)
	if completed:
		config.set_value("tutorial", "done", true)
		config.set_value("tutorial", "skipped", false)
	else:
		config.set_value("tutorial", "skipped", true)
	config.save(TEACH_PROGRESS_PATH)


func _teach_process(delta: float) -> void:
	if _teach_index < 0:
		return
	if _player == null or not is_instance_valid(_player) or _cutscene_on_screen():
		return
	# Distance and sprint time are sampled on every frame whatever step is
	# current, so a player who has already sprinted across the forecourt is not
	# asked to do it again when the sprint step comes round.
	var moved := _player.global_position.distance_to(_teach_last_pos)
	_teach_last_pos = _player.global_position
	_teach_move += minf(moved, TEACH_MOVE_STEP_CAP)
	var horizontal := Vector2(_player.velocity.x, _player.velocity.z).length()
	if Input.is_action_pressed("sprint") and horizontal > TEACH_SPRINT_SPEED:
		_teach_sprint += delta
	# A loop, not a single test: the steps are ordered by where the player meets
	# them, not by when they satisfy them, and several can already be true by the
	# time the one in front of them clears.
	var advanced := false
	while _teach_index < _teach_steps.size() \
			and _teach_done(str((_teach_steps[_teach_index] as Dictionary)["id"])):
		_teach_index += 1
		advanced = true
	if not advanced:
		return
	if _teach_index >= _teach_steps.size():
		_teach_finish(true)
		return
	_sfx("resolve", -8.0)
	_teach_show()


## Every one of these is a fact about the world, not a button the player pressed
## to say they understood.
func _teach_done(id: String) -> bool:
	match id:
		"move":
			return _teach_move > TEACH_MOVE_DISTANCE
		"look":
			return _teach_look > TEACH_LOOK_DELTA
		"sprint":
			return _teach_sprint > TEACH_SPRINT_TIME
		"flashlight":
			return _teach_flashlight
		"office":
			# The blackout is the confirmation: it fires from the map the instant
			# the player crosses into the Watcher Office, and STATE_DAY is the
			# only state that precedes it.
			return _state != STATE_DAY
		"lantern":
			return _carried_id == "null_lantern"
		"tablet":
			return _camera_tablet_open()
		"protocol":
			return _teach_protocol_read
	return true


## Passive observers for the two steps with nothing to poll: a mouse that moved
## and a flashlight that was toggled. Both stand down while a cutscene owns the
## screen -- the player is frozen there, and dragging the mouse across the
## opening prologue is not looking around the museum.
func _teach_watch(event: InputEvent) -> void:
	if _teach_index < 0 or _cutscene_on_screen():
		return
	if event is InputEventMouseMotion:
		_teach_look += (event as InputEventMouseMotion).relative.length()
	elif event.is_action_pressed("flashlight"):
		_teach_flashlight = true


func _teach_show() -> void:
	if _teach_index < 0 or _teach_index >= _teach_steps.size():
		return
	var step: Dictionary = _teach_steps[_teach_index]
	set_objective("teach", tr(str(step["obj"])), TEACH_PRIORITY)


## The current step's key legend, for the hint label. Read live rather than
## cached so a language switch mid-orientation lands on the next frame.
func _teach_hint() -> String:
	if _teach_index < 0 or _teach_index >= _teach_steps.size():
		return ""
	return tr(str((_teach_steps[_teach_index] as Dictionary)["hint"]))


## End the orientation and write the result. Safe to call when nothing is
## running, which is what lets _resolve() and _win() call it unconditionally.
func _teach_finish(completed: bool) -> void:
	if _teach_index < 0:
		return
	_teach_index = -1
	_teach_steps = []
	clear_objective("teach")
	_teach_write(completed)
	if completed:
		# The banner the old orientation sector signed off with, kept: it is the
		# same event, and the catalogue already answers for it in both locales.
		_flash(tr("TUTORIAL_COMPLETE"), UITheme.SUCCESS)
		_sfx("resolve")


# --- Visual helpers ---------------------------------------------------------

func _tint_core(color: Color, emission: float) -> void:
	if _core == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emission
	_core.material_override = mat


func _set_dome_breach(breached: bool, color: Color) -> void:
	# With the force-field shader the dome cracks and strobes instead of
	# disappearing; without the shader, fall back to hiding the mesh.
	if _dome == null:
		return
	var mesh := _dome as MeshInstance3D
	var mat: ShaderMaterial = null
	if mesh != null:
		mat = mesh.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("damage", 1.0 if breached else 0.0)
		mat.set_shader_parameter("anomaly_color", color)
		_dome.visible = true
	else:
		_dome.visible = not breached


func _set_screen_color(color: Color) -> void:
	if _terminal_screen == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.55)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.9
	_terminal_screen.material_override = mat


func _static_box(box_name: String, pos: Vector3, size: Vector3,
		color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = pos
	_map_root.add_child(body)
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh_instance(body, mesh, Vector3.ZERO, color, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)


func _mesh_instance(parent: Node, mesh: Mesh, pos: Vector3, color: Color,
		emission := 0.0) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	inst.material_override = mat
	parent.add_child(inst)
	return inst


func _mesh_box(parent: Node, pos: Vector3, size: Vector3, color: Color,
		emission := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh_instance(parent, mesh, pos, color, emission)


func _mesh_cylinder(parent: Node, pos: Vector3, radius: float, height: float,
		color: Color, emission := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius
	mesh.height = height
	return _mesh_instance(parent, mesh, pos, color, emission)


func _mesh_sphere(parent: Node, pos: Vector3, radius: float, color: Color,
		emission := 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _mesh_instance(parent, mesh, pos, color, emission)


func _mesh_cone(parent: Node, pos: Vector3, bottom_radius: float,
		top_radius: float, height: float, color: Color,
		emission := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	return _mesh_instance(parent, mesh, pos, color, emission)


func _mesh_torus(parent: Node, pos: Vector3, inner: float, outer: float,
		color: Color, emission := 0.0, upright := true) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	var inst := _mesh_instance(parent, mesh, pos, color, emission)
	if upright:
		inst.rotate_x(deg_to_rad(90))
	return inst
