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
## Alarm console, moved out of the middle of the office and onto the operator's
## own workstation line: 3.2 m west of the monitor bank, level with the desk.
## Must match the Alarm Terminal boxes in FirstMuseumMap.gd.
const TERMINAL_POS := Vector3(-28.2, 1.4, -2.38)

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
		# THE VERTICAL SLICE (12.6 p.4). This one anomaly is not diagnosed for the
		# operator: the terminal prints two independent signs and stops, and naming
		# the device is the player's job. A flag rather than a rewrite of all ten,
		# because P2 of the audit checklist says not to scale before one slice has
		# earned it. Read by _begin_anomaly() and _show_protocol().
		"self_diagnosed": true,
		# What the required CCTV post is expected to yield when the operator finally
		# watches it. Its presence is what turns the scan from a progress bar into a
		# reading -- see GameplayEnhancements._update_readouts().
		"evidence": "HUD_EVIDENCE_TEMPORAL",
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
## The id in the operator's HANDS, or "". DERIVED -- _sync_belt() is the only
## writer. Six readers already trust this name and none of them had to change
## when the belt arrived: GameplayEnhancements._carried_tool() (the chalk),
## the orientation's "lantern" step, _update_hint(), _sync_status_slot(),
## _resolve() and _retry(). That is the whole reason the belt is expressed as
## "four slots, one of which is this variable" rather than as a new owner.
var _carried_id := ""

# --- THE BELT ---------------------------------------------------------------
#
# The operator used to carry exactly one device. A pickup with full hands did
# nothing at all -- no refusal, no sound -- and the walk back to Equipment
# Storage (x -35..-15) after guessing wrong cost more of the night than the
# incident did. Four slots, because four is what one hand of number keys covers
# and what the storage row is laid out in.
#
# The rules are deliberately thin, and all four are about the same distinction:
#   * only the ACTIVE slot is in the hands. The other three are on the belt,
#     hidden, and cannot be applied to an incident -- _interact() reads
#     _carried_id, which is the active slot and nothing else;
#   * a pickup fills the active slot when it is empty, otherwise the first free
#     one, and it always becomes the active slot, because a device that landed
#     on a hidden slot reads as a device that vanished;
#   * a pickup with no free slot REFUSES OUT LOUD (HUD_BELT_FULL);
#   * "drop" drops the active slot only -- the one the player can see.
# _resolve() spends the active slot, _retry() empties the whole belt back onto
# the pedestals.
const BELT_SLOTS := 4
var _belt: Array[String] = ["", "", "", ""]
var _belt_slot := 0
var _belt_bar: InventoryBar = null

var _terminal_screen: MeshInstance3D = null
var _terminal_label: Label3D = null
## The line that answers "what do I take?" without being pressed. See
## _build_terminal().
var _terminal_take: Label3D = null

# The whole night HUD: one block, four slots. Replaces the objective band, the
# timer box, the hint line, the flash banner and PlayerController's stamina
# panel -- see _build_hud().
var _task: TaskBlock = null
var _protocol_layer: CanvasLayer = null
var _protocol_frame: TerminalFrame = null
var _proto_item: Label = null
var _proto_purpose: Label = null
var _proto_status: Label = null
var _protocol_time := 0.0

# Тестовая консоль (F9): выбор измерения для проверки. Не влияет на прогресс.
var _admin_layer: CanvasLayer = null
var _test_mode := false
# Состояние ввода на момент открытия консоли — восстанавливается при закрытии.
var _admin_prev_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _admin_prev_controls := true
var _pre_test_state := STATE_DAY
var _pre_test_time_left := 0.0
var _pre_test_calm := 0.0
var _pre_test_anomaly := ""
# Fail and win live on their own CanvasLayer, above every screen a live shift
# can raise -- see the layer table above _build_hud().
var _overlay_layer: CanvasLayer = null
var _fail_frame: TerminalFrame = null
var _fail_reason: Label = null
var _fail_progress: Label = null
var _fail_tip: Label = null
var _fail_retry: Label = null
var _win_frame: TerminalFrame = null
var _win_label: Label = null
var _admin_frame: TerminalFrame = null
## Last corruption level pushed to the terminal frames. Repainting one costs a
## pass over every label it owns, so the level is only pushed when it has
## actually moved -- see _sync_terminals().
var _terminal_corruption := -1.0
## Seconds until the Curator may spike the terminals again. See _sync_terminals().
var _curator_pulse_cooldown := 0.0
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
	# A resumed night 3 must open on the alternate bed, same as a reached one
	# (see _advance_night).
	var am_boot := _audio()
	if am_boot != null and am_boot.has_method("set_bed_variant"):
		am_boot.set_bed_variant(_night)
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
			if _task != null:
				_task.set_timer(_time_left, _timer_urgent(), TaskBlock.OWNER_NIGHT)
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
	_sync_status_slot()
	_sync_terminals(delta)
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
	elif event.is_action_pressed("throw_item"):
		_throw_device()
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("slot_next"):
		_cycle_slot(1)
	elif event.is_action_pressed("slot_prev"):
		_cycle_slot(-1)
	elif event is InputEventKey:
		# The number row, in one loop rather than four branches. Actions are named
		# slot_1..slot_4 in InputBootstrap; a slot with nothing in it is still
		# selectable, because "empty hands" is a state the player chooses.
		#
		# Gated on the event TYPE so the loop is not four is_action_pressed() calls
		# per mouse-motion event -- this handler sees every one of them, because
		# _teach_watch() above needs them.
		for index in range(BELT_SLOTS):
			if event.is_action_pressed("slot_%d" % (index + 1)):
				_select_slot(index)
				break


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
	# The tool, named on the device itself and left standing there. Same wording
	# the protocol panel uses, so the room and the panel cannot disagree.
	if _terminal_take != null:
		_terminal_take.text = "%s\n%s" % [tr("HUD_PROTO_TAKE"),
			tr(str(EQUIPMENT[str(info["equipment"])]["name"]))]
		# A self-diagnosed anomaly withholds the device name on the stand sign as
		# well. Written over the line above rather than branched around it: the
		# name has to disappear from every surface at once, and one override next
		# to the assignment is harder to forget than a second copy of the lookup.
		if bool(info.get("self_diagnosed", false)):
			_terminal_take.text = tr("HUD_PROTO_DIAGNOSE")
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
	# The spent device leaves the belt with it; _sync_belt() re-derives
	# _carried_id from the slot that is active afterwards, which is this one.
	_belt[_belt_slot] = ""
	_sync_belt()
	# Calm the core, restore the dome.
	_tint_core(Color(0.45, 0.95, 0.75), 0.7)
	if is_instance_valid(_anomaly_light):
		_anomaly_light.queue_free()
	_set_dome_breach(false, Color(0.45, 0.95, 0.75))
	if _task != null:
		_task.set_timer(-1.0, false, TaskBlock.OWNER_NIGHT)
	# Emergency power: part of the lights come back, dimmed.
	var lights: Variant = _map.get("_powered_lights")
	if lights is Array:
		for l in lights:
			if is_instance_valid(l) and not l.visible:
				l.visible = true
				l.light_energy = l.light_energy * 0.45
	if _terminal_label != null:
		_terminal_label.text = tr("HUD_TERMINAL_RESTORED")
	if _terminal_take != null:
		# Nothing to fetch any more; the order must not outlive the incident.
		_terminal_take.text = ""
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
		if am.has_method("play_music_stinger"):
			# The musical mark of the catch, over the SFX hit: the night layers
			# duck under it rather than cutting out on the fail page.
			am.play_music_stinger()
	# The block stands down for every screen that takes the game away from the
	# player; the fail page is one, and it carries its own retry prompt.
	if _task != null:
		_task.set_timer(-1.0, false, TaskBlock.OWNER_NIGHT)
		_task.set_suspended(true)
	if _fail_frame != null:
		var anomaly_title := tr("ANOMALY_UNKNOWN")
		if ANOMALIES.has(_anomaly_id): anomaly_title = tr(str(ANOMALIES[_anomaly_id]["title"]))
		var tip := tr("FAIL_TIP_DEFAULT")
		if _trial_manager != null and _trial_manager.has_method("trial_fail_tip"):
			tip = str(_trial_manager.call("trial_fail_tip"))
		_fail_reason.text = Loc.fmt("FAIL_REASON", [anomaly_title])
		_fail_progress.text = Loc.fmt("FAIL_PROGRESS", [_night, _anomalies_left])
		_fail_tip.text = Loc.fmt("FAIL_TIP", [tip])
		# Re-read rather than written once at build: the pause menu can switch
		# language mid-run, and this label is not one the frame re-renders.
		_fail_retry.text = tr("FAIL_RETRY")
		_raise_terminal(_fail_frame)


func _retry() -> void:
	# Retry restarts the night in place (no scene reload), so this is the path
	# that resumes play. Control comes back last, once _start_accident() has left
	# STATE_FAILED: player_controls_allowed() answers from _state, so enabling
	# earlier would contradict the query the tablet and the kill plane now trust.
	_lower_terminal(_fail_frame)
	if _task != null:
		_task.set_suspended(false)
	# Return the WHOLE belt to the pedestals, not just the slot in hand: a retry
	# that left three devices parented to the camera would start the night with
	# them missing from storage and invisible on the operator.
	for index in range(BELT_SLOTS):
		var held := _belt[index]
		if held == "":
			continue
		var body: StaticBody3D = _devices.get(held)
		if body != null and is_instance_valid(body):
			body.get_parent().remove_child(body)
			_map_root.add_child(body)
			body.visible = true
			body.scale = Vector3.ONE
			body.global_transform = _device_homes[held]
			_set_collision(body, true)
		_belt[index] = ""
	_belt_slot = 0
	_sync_belt()
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
	# Night 3 changes key: the alternate bed takes over here (mid-session swap,
	# no scene reload) so the last night does not sound like the first.
	var am := _audio()
	if am != null and am.has_method("set_bed_variant"):
		am.set_bed_variant(_night)
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
	if _task != null:
		_task.set_timer(-1.0, false, TaskBlock.OWNER_NIGHT)
		_task.set_suspended(true)
	_hide_protocol()
	# Whatever is still open on the orientation checklist, three nights closes it.
	_teach_finish(false)
	_refresh_win_label()
	if _win_frame != null:
		# The one terminal page in the game that is not degraded: the museum is
		# contained, so the feed comes back clean -- integrity 100%, no murk, no
		# rot. _night_corruption() answers 0.0 in STATE_WIN, and _raise_terminal()
		# pushes that before the curtain is faded in.
		_raise_terminal(_win_frame)
		_win_frame.modulate.a = 0.0
		create_tween().tween_property(_win_frame, "modulate:a", 1.0, WIN_FADE)
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

## Cutscene parks its own CanvasLayer at 410 (OVERLAY_LAYER), which is right for
## the opening -- that plays over an empty HUD on a paused tree -- and wrong
## here: the ending rolls at the end of a live shift, with the task block and the
## proximity alert still on screen. So this is a promotion within the same band,
## not a jump off the engine default; _play_ending() overwrites .layer in place.
##
## MUST SIT ABOVE the win curtain it replaces (420) and everything that curtain
## already covers: the HUD (110, 199), the raisable screens (200, 210) and the
## alert (320).
## MUST SIT BELOW the pause menu (610) -- ESC during the credits still works --
## and below the catch screen (590), which is unreachable here but must never be
## the loser of that pair anywhere.
## See the full layer table above _build_hud().
const ENDING_LAYER := 430

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
	_lower_terminal(_win_frame)


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


## The task block stands down for anything that takes the game away from the
## player: a cutscene (its letterbox would otherwise have an objective printed
## across it), the fail and win pages, and the F9 console.
##
## set_suspended() rather than `visible`: the block owns its own visibility --
## it hides itself when it has nothing to say and shows itself again on the next
## set_* -- so writing `visible` directly is undone by the very next frame.
##
## STATE_NIGHT_DONE is deliberately NOT in the list. It has no full-screen page
## of its own; the "Night %d complete. ENTER - next night." line in slot 1 IS
## that screen, and suspending here would leave the player frozen in front of
## nothing.
func _sync_hud_visibility() -> void:
	var away := _cutscene_on_screen() or _state == STATE_FAILED \
		or _state == STATE_WIN or (_admin_layer != null and _admin_layer.visible)
	if _task != null:
		_task.set_suspended(away)
	# The belt is part of the same HUD and stands down on the same condition.
	if _belt_bar != null and is_instance_valid(_belt_bar):
		_belt_bar.set_suspended(away)


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
	# Pick up a device. Full hands are no longer a silent refusal: the belt takes
	# four, and only a belt with no free slot says no -- and it says so.
	var target := _raycast_body()
	if target != null and target.is_in_group("equipment"):
		if _free_belt_slot() < 0:
			_flash(tr("HUD_BELT_FULL"), UITheme.WARNING)
		else:
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
	# The block's hand-over, and the ONLY place it happens. Both systems that hold
	# a slot the trial needs give it up HERE, synchronously, before begin() runs --
	# so the trial's claim() lands on a free slot in the same frame instead of
	# racing two _process() orders it does not control. Slot 3 is this node's
	# (_update_hint stands down for as long as _trial_active), slot 4 is the
	# anomaly's. Slots 2 and 5 stay ours: the incident clock keeps running inside a
	# rift, and so do the operator's legs.
	if _task != null:
		_task.release(TaskBlock.Slot.HINT, TaskBlock.OWNER_NIGHT)
	var enhancements := get_tree().get_first_node_in_group("gameplay_enhancements")
	if enhancements != null and enhancements.has_method("release_readouts"):
		enhancements.call("release_readouts")
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
		if _task != null and _state != STATE_ANOMALY:
			_task.set_timer(-1.0, false, TaskBlock.OWNER_NIGHT)
		_flash(tr("ADMIN_TEST_DONE"), UITheme.SUCCESS)
		return
	_resolve()


func _pick_up(id: String) -> void:
	var body: StaticBody3D = _devices.get(id)
	if body == null or _camera == null:
		return
	var slot := _free_belt_slot()
	if slot < 0:
		_flash(tr("HUD_BELT_FULL"), UITheme.WARNING)
		return
	_belt[slot] = id
	# Taking something always puts it in the hands, whichever slot received it.
	_belt_slot = slot
	body.get_parent().remove_child(body)
	_camera.add_child(body)
	body.position = Vector3(0.42, -0.35, -0.75)
	body.rotation = Vector3.ZERO
	body.scale = Vector3(0.8, 0.8, 0.8)
	_set_collision(body, false)
	# Re-derives _carried_id, hides the three belt slots and repaints the row.
	_sync_belt()
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
	# The ACTIVE slot only. Whatever else is on the belt stays on the belt: this
	# is the key the player presses to put down the thing they can see.
	_belt[_belt_slot] = ""
	_sync_belt()
	if body == null:
		return
	body.get_parent().remove_child(body)
	_map_root.add_child(body)
	body.visible = true
	body.scale = Vector3.ONE
	body.rotation = Vector3.ZERO
	var forward := -_player.global_transform.basis.z
	body.global_position = _player.global_position + forward * 1.0 + Vector3(0, 0.35, 0)
	_set_collision(body, true)
	_sfx("drop")
	# Setting a thing down at your feet is quiet on purpose: the loud version of
	# this verb is _throw_device(), and it costs the same slot.


## How far the operator can throw. Past this the item lands short rather than
## sailing across the wing: a decoy the player cannot place is not a decision.
const THROW_RANGE := 12.0

## Cached so a throw does not walk the scene tree looking for the Curator.
var _curator_node: Node = null


## Throw the held item. It costs the same belt slot as dropping it, but the
## noise is reported from WHERE IT LANDS instead of from under the player.
##
## That is the whole point of the verb, and the reason the Curator's hearing had
## to carry a position: footsteps say "someone is there", a thrown object says
## "someone is there" about a place the operator picked. It is the only noise in
## the museum the player aims.
func _throw_device() -> void:
	if _carried_id == "" or _player == null or _camera == null:
		return
	var body: StaticBody3D = _devices.get(_carried_id)
	# The active slot only, exactly as dropping does.
	_belt[_belt_slot] = ""
	_sync_belt()
	if body == null:
		return
	var landing := _throw_landing()
	body.get_parent().remove_child(body)
	_map_root.add_child(body)
	body.visible = true
	body.scale = Vector3.ONE
	body.rotation = Vector3.ZERO
	body.global_position = landing
	_set_collision(body, true)
	_sfx("drop")
	_report_noise(landing, CuratorMonster.NOISE_THROW)
	_flash(tr("HUD_TOOL_THROWN"), UITheme.ON_SURFACE)


## Where a thrown item comes to rest: along the camera until something stops it,
## then down onto the floor. The item is a StaticBody3D and always has been, so
## this resolves the arc geometrically instead of turning it into a rigid body
## whose resting place no test could predict.
func _throw_landing() -> Vector3:
	var space := _camera.get_world_3d().direct_space_state
	var from := _camera.global_position
	var to := from - _camera.global_transform.basis.z * THROW_RANGE
	var blockers: Array[RID] = []
	if _player is PhysicsBody3D:
		blockers.append((_player as PhysicsBody3D).get_rid())
	var forward_query := PhysicsRayQueryParameters3D.create(from, to)
	forward_query.exclude = blockers
	var wall := space.intersect_ray(forward_query)
	var reach: Vector3 = to
	if not wall.is_empty():
		# Stop short of the surface, or the item ends up inside the wall it hit.
		reach = (wall["position"] as Vector3) + (from - to).normalized() * 0.3
	var down_query := PhysicsRayQueryParameters3D.create(
		reach + Vector3(0, 0.2, 0), reach - Vector3(0, 6.0, 0))
	down_query.exclude = blockers
	var ground := space.intersect_ray(down_query)
	if ground.is_empty():
		return reach
	return (ground["position"] as Vector3) + Vector3(0, 0.18, 0)


## Tell the Curator something was heard. Silent no-op when there is no Curator
## in the scene, which is every night before the second one.
func _report_noise(origin: Vector3, loudness: float) -> void:
	if _curator_node == null or not is_instance_valid(_curator_node):
		_curator_node = get_tree().get_root().find_child("The Curator", true, false)
	if _curator_node != null and _curator_node.has_method("hear_noise"):
		_curator_node.call("hear_noise", origin, loudness)


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


# --- The belt ---------------------------------------------------------------
#
# Five short functions, and the only one anything outside this block calls is
# _sync_belt(). See the BELT comment at the top of the file for the rules.


## Re-derive everything the rest of the file reads from the belt array.
##
## Called after every change and NEVER per frame: it walks four slots, toggles
## visibility and repaints the row. It is also the single writer of
## _carried_id, which is what lets six older readers keep working untouched.
##
## Slots holding a freed body (a device spent at an incident, a scene rebuild)
## are cleared here rather than by whoever freed it, so no path can leave a
## dangling id behind.
func _sync_belt() -> void:
	_belt_slot = clampi(_belt_slot, 0, BELT_SLOTS - 1)
	for index in range(BELT_SLOTS):
		var id := _belt[index]
		if id == "":
			continue
		# Read as Variant first. Assigning an ALREADY-FREED instance to a typed
		# StaticBody3D variable throws on the assignment itself, before
		# is_instance_valid() ever runs -- which is precisely the case this block
		# exists to survive (a device spent at the dome, a scene rebuild). The
		# typed form read as correct and was not: the slot kept its dead id.
		# _respawn_devices() reads the same dictionary the same careful way.
		var held: Variant = _devices.get(id)
		if held == null or not is_instance_valid(held):
			_belt[index] = ""
			continue
		var body := held as StaticBody3D
		if body == null:
			_belt[index] = ""
			continue
		# Only the active slot is in the hands; the rest are on the belt, which in
		# a first-person camera means not drawn. The raised CCTV tablet empties the
		# hands too: stage 10 ruled that a device and the tablet cannot be held at
		# once, and hiding the body is that rule WITHOUT taking the device off the
		# belt -- lowering the tablet brings the same device back to the same slot.
		# SecurityCameraTablet._toggle() calls this function on both edges.
		body.visible = index == _belt_slot and not _camera_tablet_open()
	_carried_id = _belt[_belt_slot]
	if _belt_bar != null and is_instance_valid(_belt_bar):
		_belt_bar.set_belt(_belt_names(), _belt_slot)


## Translated device name per slot, empty string for an empty slot. The bar is
## given finished text: it has no business knowing the equipment table.
func _belt_names() -> Array:
	var names: Array = []
	for index in range(BELT_SLOTS):
		var id := _belt[index]
		if id != "" and EQUIPMENT.has(id):
			names.append(tr(str(EQUIPMENT[id]["name"])))
		else:
			names.append("")
	return names


## Where the next pickup goes: the active slot when it is free, otherwise the
## first free one, otherwise -1 for "the belt is full".
func _free_belt_slot() -> int:
	if _belt[_belt_slot] == "":
		return _belt_slot
	for index in range(BELT_SLOTS):
		if _belt[index] == "":
			return index
	return -1


func _select_slot(index: int) -> void:
	if index < 0 or index >= BELT_SLOTS or index == _belt_slot:
		return
	_belt_slot = index
	_sync_belt()
	# The same quiet click the tablet answers a chip with: switching hands is a
	# confirmation, not an event.
	_sfx("tablet_click", -8.0)


func _cycle_slot(step: int) -> void:
	_select_slot(wrapi(_belt_slot + step, 0, BELT_SLOTS))


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
			# Clipped back to the collider it is carried in. The bead used to top
			# out at 0.44 against a box half-height of 0.30, so the rod poked
			# through its own pedestal and, held, through the bottom of frame.
			_mesh_cylinder(body, Vector3(0, -0.04, 0), 0.045, 0.48,
				Color(0.35, 0.37, 0.4))
			_mesh_sphere(body, Vector3(0, 0.22, 0), 0.08, color, 1.4)
			_mesh_box(body, Vector3(0, -0.24, 0), Vector3(0.16, 0.1, 0.16),
				Color(0.14, 0.14, 0.15))
		"field_emitter":
			_mesh_box(body, Vector3(0, -0.18, 0), Vector3(0.3, 0.12, 0.3),
				Color(0.15, 0.17, 0.2))
			_mesh_cone(body, Vector3(0, 0.02, 0), 0.19, 0.05, 0.3,
				Color(0.3, 0.34, 0.4))
			# Dropped from 0.26: the bead reached 0.33 against a collider that
			# stops at 0.30, and at 0.22 it seats into the cone's tip instead of
			# hovering a centimetre above it.
			_mesh_sphere(body, Vector3(0, 0.22, 0), 0.07, color, 1.5)
		"spectral_lens":
			# A hand glass: ring on a stick. Read at a glance from the side, which
			# is how it is read on a workbench.
			_mesh_cylinder(body, Vector3(0, -0.18, 0), 0.035, 0.22,
				Color(0.16, 0.15, 0.13))
			_mesh_torus(body, Vector3(0, 0.08, 0), 0.13, 0.17,
				Color(0.3, 0.32, 0.35))
			var lens_glass := _mesh_cylinder(body, Vector3(0, 0.08, 0), 0.13,
				0.012, color, 1.2)
			lens_glass.rotation_degrees = Vector3(90, 0, 0)
		"phase_prism":
			# Two cones base to base: a cut crystal, the one silhouette here that
			# comes to a point at both ends.
			_mesh_box(body, Vector3(0, -0.24, 0), Vector3(0.24, 0.05, 0.24),
				Color(0.14, 0.13, 0.16))
			_mesh_cone(body, Vector3(0, -0.09, 0), 0.03, 0.17, 0.2, color, 0.9)
			_mesh_cone(body, Vector3(0, 0.12, 0), 0.17, 0.02, 0.22, color, 0.9)
		"resonance_tuner":
			# A tuning fork. Two prongs, and nothing else in the rack has two of
			# anything standing up.
			_mesh_cylinder(body, Vector3(0, -0.21, 0), 0.045, 0.18,
				Color(0.18, 0.16, 0.14))
			_mesh_box(body, Vector3(0, -0.08, 0), Vector3(0.17, 0.08, 0.07),
				Color(0.32, 0.33, 0.36))
			_mesh_box(body, Vector3(-0.06, 0.11, 0), Vector3(0.04, 0.3, 0.05),
				color, 0.6)
			_mesh_box(body, Vector3(0.06, 0.11, 0), Vector3(0.04, 0.3, 0.05),
				color, 0.6)
		"mass_clamp":
			# A C-clamp: the open mouth faces +x, so the tool reads as a jaw
			# rather than as another box with a light on it.
			_mesh_box(body, Vector3(-0.1, 0, 0), Vector3(0.07, 0.34, 0.16),
				Color(0.2, 0.2, 0.22))
			_mesh_box(body, Vector3(0.01, 0.14, 0), Vector3(0.2, 0.07, 0.16),
				color)
			_mesh_box(body, Vector3(0.01, -0.14, 0), Vector3(0.2, 0.07, 0.16),
				color)
			_mesh_cylinder(body, Vector3(0.08, -0.02, 0), 0.028, 0.2,
				Color(0.36, 0.37, 0.4))
			var clamp_bar := _mesh_cylinder(body, Vector3(0.08, -0.12, 0), 0.016,
				0.18, Color(0.36, 0.37, 0.4))
			clamp_bar.rotation_degrees = Vector3(0, 0, 90)
		"thermal_chalk":
			# A stick of chalk in a holder -- the smallest thing on the bench, and
			# deliberately so: it is the one tool that is consumed by being drawn
			# with.
			_mesh_cylinder(body, Vector3(0, -0.13, 0), 0.05, 0.16,
				Color(0.15, 0.14, 0.14))
			_mesh_torus(body, Vector3(0, -0.04, 0), 0.05, 0.07, color, 0.5, false)
			_mesh_cone(body, Vector3(0, 0.11, 0), 0.045, 0.03, 0.3, color, 0.7)
		"memory_reel":
			# A film reel, stood on edge and facing the aisle: the only disc in
			# the room whose face is turned to the player.
			var reel_back := _mesh_cylinder(body, Vector3(0, 0, -0.07), 0.22,
				0.02, Color(0.18, 0.19, 0.22))
			reel_back.rotation_degrees = Vector3(90, 0, 0)
			var reel_front := _mesh_cylinder(body, Vector3(0, 0, 0.07), 0.22,
				0.02, Color(0.18, 0.19, 0.22))
			reel_front.rotation_degrees = Vector3(90, 0, 0)
			var reel_hub := _mesh_cylinder(body, Vector3(0, 0, 0), 0.09, 0.13,
				color, 0.8)
			reel_hub.rotation_degrees = Vector3(90, 0, 0)
		"null_lantern":
			# A caged lamp. The orientation's sixth step sends the player to fetch
			# this one by name, so it is the one device that has to be findable
			# across a dark storage room -- hence the exposed core at 1.6.
			_mesh_cylinder(body, Vector3(0, -0.22, 0), 0.11, 0.05,
				Color(0.15, 0.14, 0.18))
			_mesh_cylinder(body, Vector3(0, 0.2, 0), 0.1, 0.05,
				Color(0.15, 0.14, 0.18))
			for post_x: float in [-0.085, 0.085]:
				for post_z: float in [-0.085, 0.085]:
					_mesh_box(body, Vector3(post_x, -0.01, post_z),
						Vector3(0.02, 0.38, 0.02), Color(0.28, 0.28, 0.33))
			_mesh_sphere(body, Vector3(0, -0.02, 0), 0.085, color, 1.6)
			# The bail tops out at 0.30 -- inside the reach of the 0.6 m collision
			# box, and no taller than the containment rod, which is the tallest
			# thing the pedestals and the held-item pose were ever sized for.
			_mesh_torus(body, Vector3(0, 0.24, 0), 0.03, 0.06,
				Color(0.28, 0.28, 0.33))
		_:
			# Still here on purpose: a device id added to EQUIPMENT without a
			# branch of its own gets a body rather than nothing. thread_spool is
			# the last id that still lands here, and its wound barrel is what this
			# fallback was quietly drawing all along.
			_mesh_cylinder(body, Vector3(0, -0.16, 0), 0.17, 0.03,
				Color(0.13, 0.15, 0.17))
			_mesh_cylinder(body, Vector3(0, 0.16, 0), 0.17, 0.03,
				Color(0.13, 0.15, 0.17))
			_mesh_cylinder(body, Vector3(0, 0, 0), 0.13, 0.3, color, 0.5)
			_mesh_torus(body, Vector3(0, 0.03, 0), 0.13, 0.155, color, 0.8, false)
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


## THE TERMINAL THE OPERATOR ACTUALLY READS
##
## What stood here was one BoxMesh 1.3 x 0.8 x 0.08 floating at y 2.15 with a
## Label3D in the same air. Measured against the prop it belongs to: the alarm
## console's own top surface is at y 1.29 (pedestal 0.55 +- 0.55, console box
## 1.18 +- 0.11), so the screen hung 0.86 m ABOVE the thing it reports for, with
## nothing between them. It read as a coloured rectangle parked in the room
## rather than as a device standing on the console -- which is exactly the
## complaint.
##
## It is now a mounted head: two posts off the console top, a bezel, and the lit
## face INSET into that bezel, all under one root at TERMINAL_POS so the thing
## the player presses E at and the thing the player looks at are one object.
##
## And it answers the question without being pressed. The tool to fetch used to
## exist only in a flash message that lasts a few seconds and in the protocol
## panel that times out; miss both and the room never tells you again. Slot 2 of
## the face is now a standing line that names the tool for as long as the
## incident is open.
func _build_terminal() -> void:
	var root := Node3D.new()
	root.name = "Anomaly Terminal"
	root.position = TERMINAL_POS
	# The workstation faces +z: the desk, the chair and the monitor bank's screens
	# are all on that side. The head is built facing local -z, so the whole root is
	# turned to meet the operator instead of the back wall.
	root.rotation_degrees = Vector3(0, 180, 0)
	_map_root.add_child(root)

	# A foot plate on the console top, so the head grows out of the desk furniture
	# rather than balancing on two pins.
	var base := MeshInstance3D.new()
	base.name = "Anomaly Terminal Base"
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.92, 0.04, 0.34)
	base.mesh = base_mesh
	base.position = Vector3(0, -0.115, 0.0)
	base.material_override = _terminal_shell_material()
	root.add_child(base)

	# Two posts bridging console top (y 1.29 world = -0.11 local) to the bezel's
	# bottom edge (y 1.41 world = 0.01 local). Short on purpose: this is a head
	# bolted to a console, not a monitor on a pole.
	for post_index in range(2):
		var post_x := -0.34 + float(post_index) * 0.68
		var post := MeshInstance3D.new()
		# Numbered, or Godot renames the second one to @MeshInstance3D@NNN and the
		# part stops being addressable by name in tests.
		post.name = "Anomaly Terminal Post %d" % post_index
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.06, 0.14, 0.06)
		post.mesh = post_mesh
		post.position = Vector3(post_x, -0.05, 0.0)
		post.material_override = _terminal_shell_material()
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(post)

	var bezel := MeshInstance3D.new()
	bezel.name = "Anomaly Terminal Bezel"
	var bezel_mesh := BoxMesh.new()
	# 1.32 x 0.88 because the text has to FIT. Measured on the old 1.3 x 0.8 slab:
	# the alarm readout ran 0.91 m tall and up to 2.06 m wide, i.e. it spilled off
	# its own screen on every anomaly in the catalogue. The face below is sized
	# from that measurement, and both labels wrap instead of running off the edge.
	bezel_mesh.size = Vector3(1.32, 0.88, 0.09)
	bezel.mesh = bezel_mesh
	bezel.position = Vector3(0, 0.40, 0)
	bezel.material_override = _terminal_shell_material()
	root.add_child(bezel)

	# Casing behind the bezel. Without it the device is a 9 cm slab seen edge-on --
	# the reason it read as a coloured rectangle rather than as a monitor.
	var shell := MeshInstance3D.new()
	shell.name = "Anomaly Terminal Casing"
	var shell_mesh := BoxMesh.new()
	shell_mesh.size = Vector3(1.16, 0.74, 0.20)
	shell.mesh = shell_mesh
	shell.position = Vector3(0, 0.40, 0.14)
	shell.material_override = _terminal_shell_material()
	root.add_child(shell)

	# Hood over the glass: control-room screens get a visor against ceiling glare,
	# and it gives the silhouette a top edge to read against the dark office.
	var hood := MeshInstance3D.new()
	hood.name = "Anomaly Terminal Hood"
	var hood_mesh := BoxMesh.new()
	hood_mesh.size = Vector3(1.36, 0.05, 0.26)
	hood.mesh = hood_mesh
	hood.position = Vector3(0, 0.86, -0.10)
	hood.material_override = _terminal_shell_material()
	root.add_child(hood)

	# Power lamp on the bezel's bottom rail. Small, constant, and the one part of
	# the device that is lit while the screen is idle.
	var lamp := MeshInstance3D.new()
	lamp.name = "Anomaly Terminal Power Lamp"
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.05, 0.02, 0.02)
	lamp.mesh = lamp_mesh
	lamp.position = Vector3(0.58, 0.01, -0.05)
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(0.2, 0.9, 0.55)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(0.25, 1.0, 0.6)
	lamp_mat.emission_energy_multiplier = 2.2
	lamp.material_override = lamp_mat
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lamp)

	# Cable dropping off the casing into the console body.
	var cable := MeshInstance3D.new()
	cable.name = "Anomaly Terminal Cable"
	var cable_mesh := BoxMesh.new()
	cable_mesh.size = Vector3(0.035, 0.16, 0.035)
	cable.mesh = cable_mesh
	cable.position = Vector3(-0.42, -0.06, 0.16)
	var cable_mat := StandardMaterial3D.new()
	cable_mat.albedo_color = Color(0.04, 0.04, 0.045)
	cable_mat.roughness = 0.9
	cable.material_override = cable_mat
	cable.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cable)

	# The lit face, inset 0.05 into the bezel's front (-z, the desk side).
	_terminal_screen = MeshInstance3D.new()
	_terminal_screen.name = "Anomaly Terminal Screen"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.18, 0.74, 0.02)
	_terminal_screen.mesh = mesh
	_terminal_screen.position = Vector3(0, 0.40, -0.05)
	_terminal_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(_terminal_screen)
	_set_screen_color(Color(0.1, 0.3, 0.25))

	# Slot 1: system state. Faces the desk side, flat against the glass.
	_terminal_label = Label3D.new()
	_terminal_label.name = "Anomaly Terminal Readout"
	_terminal_label.text = tr("HUD_TERMINAL_IDLE")
	_terminal_label.position = Vector3(0, 0.52, -0.07)
	_terminal_label.rotation_degrees = Vector3(0, 180, 0)
	_terminal_label.font_size = 40
	# 0.0015 / width 730 px: measured worst case (gravity_surge, 5 alarm lines
	# over 2 order lines) then stacks 0.71 m inside a 0.74 m face.
	_terminal_label.pixel_size = 0.0015
	_terminal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_terminal_label.width = 730.0
	_terminal_label.modulate = Color(0.65, 0.95, 0.8)
	_terminal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_terminal_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	root.add_child(_terminal_label)

	# Slot 2: the answer. Quieter than the alarm line above it and warmer, because
	# it is an instruction rather than a state. Empty until an incident opens.
	_terminal_take = Label3D.new()
	_terminal_take.name = "Anomaly Terminal Order"
	_terminal_take.text = ""
	_terminal_take.position = Vector3(0, 0.18, -0.07)
	_terminal_take.rotation_degrees = Vector3(0, 180, 0)
	_terminal_take.font_size = 34
	_terminal_take.pixel_size = 0.0017
	_terminal_take.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_terminal_take.width = 645.0
	_terminal_take.modulate = Color(0.98, 0.86, 0.52)
	_terminal_take.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_terminal_take.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	root.add_child(_terminal_take)


func _terminal_shell_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.085, 0.095, 0.105)
	mat.metallic = 0.55
	mat.roughness = 0.42
	return mat


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


# The service console is a page of the same terminal as everything else, so it
# wears the same chrome: masthead, live status cluster, the two rules and the
# tube. It is the one screen whose *title* is a catalogue row rather than an
# anomaly name, and the one that shows the night's corruption without being part
# of the night -- which is exactly what a service console is for.
func _build_test_admin() -> void:
	_admin_layer = CanvasLayer.new()
	_admin_layer.name = "Test Admin Console"
	_admin_layer.layer = DEBUG_LAYER
	_admin_layer.visible = false
	add_child(_admin_layer)
	# The frame brings its own opaque backdrop and swallows the clicks that land
	# on its chrome, so the separate SCRIM rect the console used to draw is gone:
	# two full-screen modal surfaces stacked on each other is one too many.
	_admin_frame = _build_terminal_frame("Service Console", _admin_layer)
	_admin_frame.visible = true
	_admin_frame.set_title("ADMIN_TITLE")
	var layout := _admin_frame.body_column()
	layout.add_theme_constant_override("separation", 10)
	# The console's own header label is gone: the frame's masthead and title row
	# say the same thing one type step louder and in the same place on every
	# screen in the game.
	var sub := Label.new()
	sub.text = tr("ADMIN_SUBTITLE")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text(sub, UITheme.LABEL, UITheme.MUTED)
	layout.add_child(sub)
	# Deliberately NOT registered with add_glitch_target(): the console is a tool
	# rather than a scene, and this is its instruction line. Character rot belongs
	# on the pages the player is meant to be unsettled by.
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
	if opening:
		_raise_terminal(_admin_frame)
	else:
		_lower_terminal(_admin_frame)
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
	_lower_terminal(_admin_frame)
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
	_lower_terminal(_fail_frame)
	_lower_terminal(_win_frame)
	if _task != null:
		_task.set_suspended(false)
	_hide_protocol()
	_flash(Loc.fmt("ADMIN_TEST_PREFIX", [tr(str(ANOMALIES[id]["title"]))]), UITheme.ACCENT)
	_begin_trial()


# --- HUD (step 8) -----------------------------------------------------------
#
# WHAT THIS NODE STOPPED DRAWING
#
# Four free-flying Labels used to be painted straight onto the 3D museum from
# here -- objective, timer, hint, flash message -- each anchored to a different
# corner, each wearing a 6 px black outline because its background was "whatever
# the player happens to be looking at". Together with PlayerController's stamina
# card, GameplayEnhancements' effect readout and RiftTrialManager's panel stack,
# five of them could be on screen at once with nothing to say which to read
# first. game/TaskBlock.gd's header measures that defect in full.
#
# All four are gone, not hidden. Slot 1 of the block is the objective and the
# flash message (one loud line, enforced structurally by the block); slot 2 is
# the countdown; slot 3 the hint; slot 5 stamina, or the carried device when
# stamina is full. Slot 4 is the anomaly's, and this file never writes it. There
# is no _make_label(), no outline hack and no per-frame alpha fade left here.
#
# Every one of those writes now names this node as the slot's owner
# (TaskBlock.OWNER_NIGHT). See "ONE OWNER PER SLOT" in game/TaskBlock.gd: the
# owner argument has no default, so a call site that has not decided who it is
# does not compile.
#
# Every full-screen surface this node owns -- protocol, fail, win, F9 console --
# is now a page of one terminal (game/TerminalFrame.gd): masthead, live status
# cluster, body, rules, tube. They also degrade: see _night_corruption().
#
#
# CANVAS LAYERS
#
# The ladder is the decade scale game/TaskBlock.gd writes out, adopted here for
# the four layers this file owns. Decades leave room to insert without
# renumbering, which is the property the old packed 5..17 ladder lacked and the
# reason it collided -- the protocol screen and GameplayEnhancements' proximity
# alert were both issued 12, so which of them drew on top was decided by
# construction order in two unrelated files.
#
# THE WHOLE LADDER, EVERY CanvasLayer IN THE PROJECT, LOW TO HIGH. Sixteen
# assignments across ten files, listed at the number the code ACTUALLY writes.
# The left column is the value in the running game; where the decade scale wants a
# different rung, that rung is named on the line under it and marked STALE.
#
# An earlier revision of this table listed the wanted number in the left column
# and the real one in a trailing bracket, and claimed "nothing in the project
# assigns a CanvasLayer.layer that is absent from this list". Three rows made that
# claim false -- the compass runs at 6 and 6 appeared nowhere in the table at all,
# the tablet at 10 and the prologue at 40 were shown as 200 and 710. A table that
# presents itself as the single source of truth and is wrong in three rows is
# worse than no table, so the columns are the other way round now: what the game
# does first, what the scale wants second.
#
#   000-099  world-anchored diegetic surfaces, and anything predating the scale
#            006  compass / floor plan ....... game/Compass.gd:174 HUD_LAYER
#                 STALE, wants 110. Harmless: 6 and 110 are both under the task
#                 block and over nothing, so this is a rename, not a fix.
#            010  CCTV tablet ....... game/SecurityCameraTablet.gd:418
#                 STALE, wants 200. Harmless: it must lose to the task block
#                 either way, and 10 already does.
#            040  tutorial prologue ....... game/TutorialPrologue.gd:209
#                 STALE, wants 710. It beats the night HUD's old 5 and loses to
#                 the task block's 199, which is the wrong way round -- but the
#                 prologue is never on screen while a shift runs, so nothing is
#                 broken today.
#   100-199  the live shift HUD
#            110  (reserved for the compass, which is still at 6)
#            199  TASK BLOCK ....................... here (HUD_TASK_LAYER)
#                 Also named as HUD_TASK_LAYER in game/GameplayEnhancements.gd:170
#                 and game/RiftTrialManager.gd:87, for the fallback block each of
#                 them builds when it finds none to adopt, and as TASK_LAYER in
#                 game/TaskBlock.gd:403, which is where the block parks itself.
#                 Four constants, one number, on purpose.
#   200-299  screens the player raises and can put down
#            200  (reserved for the CCTV tablet, which is still at 10)
#            210  protocol screen .................. here (SCREEN_LAYER)
#   300-399  in-world alarms drawn over those screens
#            320  Curator proximity alert .. game/GameplayEnhancements.gd:101
#   400-499  takeovers that end the incident
#            410  opening cutscene .......... game/Cutscene.gd:143 OVERLAY_LAYER
#                 Under the fail and win pages, which is right for the opening:
#                 it plays over an empty HUD on a paused tree and has nothing to
#                 cover. Confirmed landed: game/Cutscene.gd:143 declares
#                 OVERLAY_LAYER := 410 and :380 assigns it. Before that it sat on
#                 the engine default of 1, where the compass (6) and the task
#                 block (199) drew ON TOP of the museum opening.
#            420  fail / win ....................... here (OVERLAY_LAYER)
#            430  ending cutscene .................. here (ENDING_LAYER)
#                 Not a CanvasLayer of its own: _play_ending() walks the Cutscene
#                 node's children and promotes the 410 above to 430, one rung over
#                 the win curtain it exists to replace rather than hide under.
#   500-589  the trial / pocket-dimension HUD
#            510  trial terminal frame ...... game/RiftTrialManager.gd:80
#   590-599  the one takeover that must also cover a trial
#            590  Curator catch screen ..... game/GameplayEnhancements.gd:161
#   600-699  menus and pause
#            610  main menu / pause menu ......... game/MenuManager.gd:166
#   700-799  the tutorial replay
#            710  (reserved for the prologue, which is still at 40)
#   900-999  debug
#            960  service console (F9) ............... here (DEBUG_LAYER)
#
# NOT IN THIS TABLE, and not a CanvasLayer: FirstMuseumMap.CCTV_HIDDEN_LAYER = 20
# is a VisualInstance3D render-layer bit, which is a different namespace entirely.
#
# THE THREE STALE ROWS ARE NOT FIXED HERE because the fix is one line in each of
# three files this pass does not own -- game/Compass.gd, game/SecurityCameraTablet.gd
# and game/TutorialPrologue.gd. All three are dirty in the working tree, i.e. held
# by another workstream, and renumbering a layer under a file's owner is how two
# correct changes become one broken merge. The relative order is right at 6, 10
# and 40, so nothing renders wrong today; what was wrong was this comment, and
# that is what has been corrected.
#
# WHY THE CATCH SCREEN IS 590 AND NOT 410, which an earlier revision of this
# comment prescribed. _update_death() fades the catch screen back OFF to uncover
# the fail page: the veil has to be ABOVE the page it hands off to, or the page
# pops on top instead of being revealed. 410 put it under 420 and would have
# broken that hand-off silently. It also has to cover the trial frame, which is
# in the band above the takeovers. So it takes the rung directly below the menus
# and the invariant becomes easy to state: the catch is above everything except
# the pause menu.
#
# THREE LAYERS ARE STILL ON THE OLD COMPRESSED LADDER: Compass (6 -> 110),
# SecurityCameraTablet (10 -> 200) and TutorialPrologue (40 -> 710). See the note
# under the table for why they are left alone in this pass. TaskBlock's own
# TASK_LAYER is 199 and agrees with the table, so _build_hud()'s assignment below
# is belt-and-braces rather than load-bearing.
## The task block: the TOP of the live-shift band.
## MUST SIT BELOW every screen that takes the game away -- the tablet (200), the
## protocol page (210), fail / win (420), the proximity alert (320), the trial
## frame (510), the catch screen (590), the pause menu (610).
## MUST SIT ABOVE the compass (6 today, 110 on the scale), which is the only thing
## under it: the block is the loudest thing the live shift draws.
const HUD_TASK_LAYER := 199
## The protocol briefing: a screen the player raises and puts down.
## MUST SIT ABOVE the task block (199) and the CCTV tablet (200), which it
## replaces on screen rather than sharing it with.
## MUST SIT BELOW the proximity alert (320) -- the Curator does not wait for the
## briefing to end -- and below every takeover, the trial frame and the menus.
const SCREEN_LAYER := 210
## The fail and win pages: takeovers that end the incident.
## MUST SIT ABOVE the whole HUD (110, 199), both raisable screens (200, 210) and
## the proximity alert (320): the run is over and none of them has anything left
## to say.
## MUST SIT BELOW the ending (430), the trial frame (510, which _cleanup() hides
## rather than relying on z-order), the catch screen (590 -- it fades off to
## UNCOVER this page, so it has to be on top of it) and the pause menu (610).
const OVERLAY_LAYER := 420
## The F9 service console. Debug builds only.
## MUST SIT ABOVE everything, the pause menu (610) included, because it has to be
## usable from a paused game. Nothing in the project sits above it.
const DEBUG_LAYER := 960
## Seconds the ending curtain takes to close. Long enough to read as a fade.
const WIN_FADE := 1.4

# --- URGENCY AND CORRUPTION -------------------------------------------------
#
# The two horror hooks the block and the frame expose, driven from state the
# night loop already keeps. Nothing below is a new fact about the game: it is
# _night, _time_left, _state, the map's blackout flag and the Curator's position
# read back out in the two shapes the UI understands.

## Seconds of incident timer below which the block goes urgent. Every one of the
## block's five urgency channels turns on together, only one of which is hue.
const URGENT_SECONDS := 30.0
## Metres. Inside this the block is urgent whatever the clock says: being about
## to be caught is a deadline too, and it is the one the player cannot see.
## Same number as GameplayEnhancements.WATCH_CRITICAL_RANGE, which is the range
## at which its own readout escalates -- kept in step deliberately, so the two
## channels agree instead of contradicting each other one metre apart.
const CURATOR_URGENT_RANGE := 7.5

## Corruption the terminal carries once the museum is on emergency power. The
## blackout is the moment the building stops being a workplace, and it is the
## floor everything else is added to.
const CORRUPT_BLACKOUT := 0.12
## Added per night past the first. 0.00 / 0.10 / 0.20.
const CORRUPT_PER_NIGHT := 0.10
## How much of the ramp the incident clock owns, from a fresh timer to zero.
## 0.12 + 0.20 + 0.55 = 0.87 at the worst instant of night three, so a live
## shift never reaches the 1.0 the fail page shows -- that number stays reserved
## for a run that has actually ended.
const CORRUPT_TIMER_SPAN := 0.55
## Metres at which the Curator starts spiking the terminals, and the strongest
## spike it lands. Matches GameplayEnhancements.WATCH_ALERT_RANGE.
const CURATOR_PULSE_RANGE := 24.0
const CURATOR_PULSE_MAX := 0.4
## Seconds one spike decays over, and the gap between spikes. The gap exists
## because pulse_corruption() repaints the whole page, so calling it per frame
## would be a full relayout at the framerate for no extra information.
const CURATOR_PULSE_SECONDS := 1.2
const CURATOR_PULSE_INTERVAL := 0.9
## Smallest corruption change worth repainting a page for.
const CORRUPT_EPSILON := 0.02

## Wall time the terminal prints. The shift starts at 23:00 and each night is
## logged an hour later; the only elapsed time this node measures is the
## incident clock, so that is what advances the readout. Between incidents it
## stands still, which is honest -- nothing is being timed then.
const SHIFT_START_SECONDS := 23.0 * 3600.0

## Above this ratio the stamina bar is not drawn at all. A gauge pegged at 100%
## is furniture; this one appears exactly while it has something to say.
const STAMINA_FULL := 0.999


func _build_hud() -> void:
	_task = TaskBlock.new()
	add_child(_task)
	# TaskBlock._ready() already parks itself at TASK_LAYER = 199, the same number
	# this constant carries, so this assignment is belt-and-braces: the block sits
	# at the TOP of the 100-199 live-shift band -- above everything the shift
	# itself draws, below every screen that takes the game away. GameplayEnhancements
	# and RiftTrialManager adopt THIS instance rather than building their own; on
	# the headless paths where they do build one, they park it at the same 199.
	_task.layer = HUD_TASK_LAYER
	# The belt: one rung under the block (150 against 199) and one above the
	# compass, i.e. inside the live-shift band, because it is furniture the shift
	# draws rather than a screen the player raises. This node is its only writer
	# -- see _sync_belt() -- and _sync_hud_visibility() stands it down alongside
	# the block, so the two can never disagree about who owns the screen.
	_belt_bar = InventoryBar.new()
	_belt_bar.name = "Inventory Belt"
	add_child(_belt_bar)
	_sync_belt()
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "Terminal Overlays"
	_overlay_layer.layer = OVERLAY_LAYER
	add_child(_overlay_layer)
	_build_fail_screen()
	_build_win_screen()


## One terminal page, parented and full-rect. Every full-screen surface this
## file owns is built through here, so they cannot drift apart again.
func _build_terminal_frame(frame_name: String, parent: Node) -> TerminalFrame:
	var frame := TerminalFrame.new()
	frame.name = frame_name
	parent.add_child(frame)
	return frame


## A body line on a terminal page. Centred, wrapped, no outline: the frame draws
## an opaque backdrop, which is the whole reason these ratios are knowable.
func _terminal_line(column: VBoxContainer, size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text(label, size, color)
	column.add_child(label)
	return label


## Push the current night onto a page and show it. Every raise goes through
## here: a frame that was hidden did not receive the per-frame corruption and
## status updates (_sync_terminals only pays for visible pages), so it would
## otherwise come up showing the state of whenever it was last on screen.
func _raise_terminal(frame: TerminalFrame) -> void:
	if frame == null:
		return
	_push_terminal_state(frame)
	frame.modulate.a = 1.0
	frame.visible = true


## Put a page down.
##
## Corruption is zeroed on the way out rather than left standing. A hidden
## TerminalFrame whose level is above zero keeps repainting at its GLITCH_HZ for
## a picture nobody is looking at -- Godot keeps running _process on the children
## of an invisible CanvasLayer -- and there are four of these frames in the
## scene. Zero is also the level a page should come back up at if anything ever
## shows one without going through _raise_terminal().
func _lower_terminal(frame: TerminalFrame) -> void:
	if frame == null:
		return
	frame.visible = false
	frame.set_corruption(0.0)


# THE FAIL PAGE. A full terminal page now rather than an 88% scrim with one
# centred Label on it: the shift is over, so the screen is the terminal's, and
# the corruption reads 100% -- containment was lost, and the readout says so in
# digits and in lit segments before it says it in colour.
func _build_fail_screen() -> void:
	_fail_frame = _build_terminal_frame("Shift Interrupted", _overlay_layer)
	_fail_frame.visible = false
	_fail_frame.set_title("FAIL_TITLE")
	var column := _fail_frame.body_column()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_fail_reason = _terminal_line(column, UITheme.SECTION, UITheme.DANGER)
	_fail_progress = _terminal_line(column, UITheme.BODY, UITheme.MUTED)
	_fail_tip = _terminal_line(column, UITheme.BODY, UITheme.ON_SURFACE)
	# The way out, and deliberately NOT an add_glitch_target(). This page runs at
	# corruption 1.0, where character rot replaces a quarter of a string twelve
	# times a second: five of the nineteen glyphs of "ENTER - retry night", every
	# 83 ms, forever, on the only line telling the player how to leave. That is
	# the same reasoning TerminalFrame gives for exempting its footer legend --
	# a key legend is silkscreen, not signal.
	_fail_retry = _terminal_line(column, UITheme.SECTION, UITheme.ACCENT)


# THE WIN CURTAIN. Opaque, and the only page in the game that is not degraded:
# _night_corruption() answers 0.0 in STATE_WIN, so integrity reads 100%, the
# rules are whole and nothing rots. That contrast is the point -- every other
# terminal the player has read this run was falling apart.
func _build_win_screen() -> void:
	_win_frame = _build_terminal_frame("Shift Over", _overlay_layer)
	_win_frame.visible = false
	var column := _win_frame.body_column()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_win_label = _terminal_line(column, UITheme.TITLE, UITheme.SUCCESS)
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


# THE PROTOCOL SCREEN. Formerly a 48%-wide panel over a 72% dim, so that the
# player could keep walking behind it; it is a page of the terminal now, which
# means an opaque screen.
#
# That is a real trade and it was made deliberately. What was bought: the panel
# no longer competes for the same rectangle as the task block (which is why the
# block's ANCHOR_RIGHT stops at 0.255 -- the old panel started at 0.26 and the
# clearance was one hundredth of a screen), the anomaly's fiction colour stops
# being asked to carry a border on a translucent fill over an arbitrary 3D
# background, and the readout that names the device now looks like every other
# readout in the building. What was paid: ten seconds of not seeing the room.
# The screen is dismissed by E or ENTER at any moment (see _input), which is the
# same key the player is about to press anyway, and it costs those ten seconds
# only to a player who chooses to read all of it.
#
# The anomaly's own colour is not lost: it is still the fog, the anomaly light
# and the terminal screen in the office. It simply stopped being UI chrome.
func _build_protocol_screen() -> void:
	_protocol_layer = CanvasLayer.new()
	_protocol_layer.name = "Protocol Screen"
	_protocol_layer.layer = SCREEN_LAYER
	_protocol_layer.visible = false
	add_child(_protocol_layer)
	_protocol_frame = _build_terminal_frame("Containment Protocol", _protocol_layer)
	# The masthead is TerminalFrame's own default (HUD_PROTO_HEADER), which is the
	# very row this screen used to print by hand as its first label. The title is
	# set per incident by _show_protocol() to the anomaly's name.
	var column := _protocol_frame.body_column()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var need := _terminal_line(column, UITheme.LABEL, UITheme.MUTED)
	_protocol_frame.add_glitch_target(need, "HUD_PROTO_TAKE")
	# The one thing the player has to leave the screen remembering. Not a glitch
	# target: a device name with a quarter of its characters replaced is the exact
	# information this page exists to deliver.
	_proto_item = _terminal_line(column, UITheme.TITLE, UITheme.ACCENT)
	_proto_purpose = _terminal_line(column, UITheme.BODY, UITheme.ON_SURFACE)
	_proto_status = _terminal_line(column, UITheme.BODY, UITheme.MUTED)
	_proto_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Not a glitch target either, and for the fail page's reason: this is the line
	# that says which key puts the screen down.
	var footer := _terminal_line(column, UITheme.LABEL, UITheme.MUTED)
	footer.text = tr("HUD_PROTO_FOOTER")


func _show_protocol(info: Dictionary, _accent: Color) -> void:
	if _protocol_layer == null:
		return
	var equip_id := str(info["equipment"])
	var equip_name := equip_id
	if EQUIPMENT.has(equip_id):
		equip_name = tr(str(EQUIPMENT[equip_id]["name"]))
	# The page's subject, as a key: the frame resolves it, recolours it on the
	# corruption ramp and lets it rot, which no formatted string could do.
	_protocol_frame.set_title(str(info["title"]))
	# On a self-diagnosed anomaly the page keeps everything except its answer:
	# masthead, incident zone, shift status, the signs the terminal is showing in
	# the office. The one line the player used to leave remembering is now theirs.
	var self_diagnosed := bool(info.get("self_diagnosed", false))
	_proto_item.text = tr("HUD_PROTO_DIAGNOSE") if self_diagnosed else equip_name.to_upper()
	var hint_key := str(TOOL_HINTS.get(equip_id, ""))
	if self_diagnosed:
		# Not the tool hint: that names the device by describing exactly what it
		# does, which is the same answer one sentence later.
		_proto_purpose.text = tr("HUD_PROTO_SIGNS_HINT")
	else:
		_proto_purpose.text = tr(hint_key) if hint_key != "" else ""
	_proto_status.text = Loc.fmt("HUD_PROTO_STATUS", [_night, _incident_name()])
	_raise_terminal(_protocol_frame)
	_protocol_layer.visible = true
	_protocol_time = 10.0
	var am := _audio()
	if am != null and am.has_method("play_sfx"):
		am.play_sfx("terminal_beep", -6.0, 0.9)


## The evidence line the running incident's CCTV post is expected to yield, or ""
## for the nine incidents that still confirm by scan. A method rather than a
## second table in the watcher: GameplayEnhancements owns the watching, this node
## owns which anomaly is running and what that anomaly promises.
func incident_evidence_key() -> String:
	if not ANOMALIES.has(_anomaly_id):
		return ""
	return str((ANOMALIES[_anomaly_id] as Dictionary).get("evidence", ""))


func _hide_protocol() -> void:
	_protocol_time = 0.0
	if _protocol_layer != null:
		_protocol_layer.visible = false
	_lower_terminal(_protocol_frame)


func _update_hint() -> void:
	if _task == null or _player == null:
		return
	# Slot 3 belongs to the trial for the duration of a pocket dimension: in there
	# the teaching row is what says how to act, and "press E to apply the
	# stabilizer" names a museum the operator is not standing in. Standing down is
	# a RETURN, not a set_hint("") -- the lease was handed over in _begin_trial()
	# and writing the slot at all would now be refused and reported.
	if _trial_active:
		return
	var hint := ""
	# The hint stands down while the CCTV feed is up. The player cannot act on an
	# interaction prompt with the tablet raised anyway -- controls are off -- and
	# the objective line above it does the opposite, staying put, because reading
	# which camera to watch is the whole reason the tablet is up. That is a
	# decision the block can now make per slot instead of per corner.
	if _camera_tablet_open():
		_task.set_hint("", [], TaskBlock.OWNER_NIGHT)
		return
	if _state != STATE_FAILED and _state != STATE_WIN and _state != STATE_NIGHT_DONE:
		# The ray is cast whatever is in the hands now, because with a belt a
		# device the operator is LOOKING AT is an action that is available -- it
		# was not before, so the prompt used to be suppressed while carrying.
		# One ray per frame, the same one _interact() would cast on the next press.
		var target := _raycast_body()
		if target != null and target.is_in_group("equipment") and _free_belt_slot() >= 0:
			hint = Loc.fmt("HUD_HINT_TAKE", [tr(str(target.get_meta("device_name")))])
		elif _carried_id != "":
			var carried_name := tr(str(EQUIPMENT[_carried_id]["name"]))
			if _state == STATE_ANOMALY and _near(_incident_position(), APPLY_DISTANCE):
				hint = Loc.fmt("HUD_HINT_APPLY", [carried_name])
			else:
				hint = Loc.fmt("HUD_HINT_CARRYING", [carried_name])
		elif _state == STATE_ANOMALY and _near(TERMINAL_POS, INTERACT_DISTANCE):
			hint = tr("HUD_HINT_TERMINAL")
	# The orientation's key legend falls in behind the interaction prompts rather
	# than fighting them: a real "press E to take the null lantern" is always
	# more useful than the line telling the player what E is for.
	if hint == "":
		hint = _teach_hint()
	_task.set_hint(hint, [], TaskBlock.OWNER_NIGHT)


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


## The winning objective goes to slot 1 of the block.
##
## The registry stores RESOLVED text rather than keys, because three other files
## put entries in it and all of them translate at the call site
## (GameplayEnhancements' camera confirmation and ExhibitPuzzleController's
## incident line both need format arguments). TaskBlock takes keys and resolves
## through Loc.fmt(); an unknown key with no arguments comes back unchanged, so
## a sentence passes through untouched. Every catalogue key in this project is
## UPPER_SNAKE, so a translated sentence can never collide with one.
func _refresh_objective() -> void:
	if _task == null:
		return
	var text := ""
	var best := -999
	for source in _objective_entries:
		var priority := int(_objective_priorities.get(source, 0))
		if priority > best:
			best = priority
			text = str(_objective_entries[source])
	_task.set_task(text, [], TaskBlock.OWNER_NIGHT)


## A transient message.
##
## It used to be a Label of its own flying across the middle of the screen on
## the night HUD layer, fading out over 3.0 s while the objective, the timer and
## the hint all stayed up around it. It takes over slot 1 of the task block for
## TaskBlock.FLASH_SECONDS instead, then hands the standing objective back: at
## most one loud line exists at any instant, and that is a property of the
## block's construction rather than a rule this file has to remember.
##
## The signature is unchanged because three other files call it -- see
## GameplayEnhancements (the Curator catch, the radiation dose, the source
## confirmation) and SecurityCameraTablet (CCTV refused outside the office).
## They pass a translated string and a Color; both survive the move. `text` is
## fed to the block as a key, and Loc.fmt() returns an unknown key unchanged
## with no arguments to apply, so an already-translated sentence round-trips
## untouched. `color` becomes a tone, which is a marker glyph AND a colour --
## the block never says anything with hue alone.
func _flash(text: String, color: Color) -> void:
	if _task == null:
		return
	_task.flash(text, [], _tone_for(color))


## Nearest tone to a caller's colour, in RGB.
##
## Five of the eight call sites already pass a UITheme role and match exactly.
## The other three pass a hand-mixed approximation from before the palette
## existed -- Color(1.0, 0.25, 0.15), Color(0.45, 1.0, 0.65), Color(1.0, 0.65,
## 0.3) -- and land on DANGER, SUCCESS and WARNING respectively, which is what
## each of them meant. UITheme.ACCENT (a milestone: a wing unlocked, a pocket
## dimension entered) resolves to GOOD, the nearest of the four.
func _tone_for(color: Color) -> TaskBlock.Tone:
	var tokens := [UITheme.ON_SURFACE, UITheme.SUCCESS, UITheme.WARNING, UITheme.DANGER]
	var best := 0
	var best_distance := INF
	for i in range(tokens.size()):
		var token: Color = tokens[i]
		var gap := Vector3(color.r - token.r, color.g - token.g,
			color.b - token.b).length_squared()
		if gap < best_distance:
			best_distance = gap
			best = i
	match best:
		1:
			return TaskBlock.Tone.GOOD
		2:
			return TaskBlock.Tone.WARN
		3:
			return TaskBlock.Tone.BAD
	return TaskBlock.Tone.INFO


# --- THE BLOCK'S STATUS SLOT -------------------------------------------------

## Which carried devices have a line of their own for slot 5. The keys are spelled
## out again at the call site in _sync_status_slot() rather than read out of here,
## because tools/check_localization.py reads the arguments at the call site and a
## key it cannot see formatted is a fatal finding there -- correctly, since that is
## exactly how a raw "%d" reaches the screen.
##
## These rows used to be written by GameplayEnhancements straight into slot 3,
## every frame, for the whole of every anomaly -- which is what erased the
## interaction prompt. They belong here: this node owns `_carried_id`, it owns
## the incident's position, and slot 5 is already the "what is in your hands"
## line. One owner, one slot, and nothing is lost.
const TOOL_LINES := ["spectral_lens", "thread_spool", "phase_prism", "null_lantern"]


## Slot 5: one measured quantity ABOUT THE OPERATOR. Stamina outranks the carried
## device, because stamina is only shown while it is NOT full -- that is, exactly
## while the player is spending it -- and a device in your hands is a fact you can
## also see in your hands.
##
## This is where PlayerController's bottom-left card went. The bar is the same
## reading; the difference is that it now sits under the sentence it affects
## instead of in the one corner of the screen nothing else uses.
##
## &"night_hud" holds this slot at ALL times, an anomaly and a pocket dimension
## included: neither of those suspends the operator's legs or empties their
## hands. That is the whole reason the block grew a fifth slot -- the anomaly's
## effect readout now has slot 4 to speak in and no longer has to take this one.
func _sync_status_slot() -> void:
	if _task == null:
		return
	if _player != null and is_instance_valid(_player) \
			and _player.has_method("stamina_ratio"):
		var ratio := float(_player.call("stamina_ratio"))
		if ratio < STAMINA_FULL:
			var spent := bool(_player.call("is_exhausted"))
			# Exhaustion is a different caption row, not a different fill colour:
			# "EXHAUSTED - CATCH YOUR BREATH" reads in greyscale and the old red
			# bar did not.
			_task.set_progress(ratio,
				"HUD_STAMINA_EXHAUSTED" if spent else "HUD_STAMINA", [],
				TaskBlock.OWNER_NIGHT)
			return
	if _carried_id != "" and EQUIPMENT.has(_carried_id):
		# A state, not a measurement: no ratio, so no bar. A bar pinned at 100%
		# would claim to be measuring something. The key and its argument list stay
		# on one line: tools/check_localization.py anchors its arity check on the
		# text immediately after the key literal, and a wrapped call reads to it as
		# a key nobody formats -- which is a fatal finding, and a fair one.
		#
		# During an incident in the museum the device says what it is DOING, which
		# is strictly more than its name; outside one, and inside a pocket
		# dimension (where the incident's position is a hundred metres below the
		# floor and the distance would be a lie), it just names itself.
		if _state == STATE_ANOMALY and not _trial_active and TOOL_LINES.has(_carried_id):
			var metres := 0
			if _player != null and is_instance_valid(_player):
				metres = int(_player.global_position.distance_to(_incident_position()))
			match _carried_id:
				"spectral_lens":
					_task.set_progress(-1.0, "HUD_TOOL_LENS", [metres], TaskBlock.OWNER_NIGHT)
				"thread_spool":
					_task.set_progress(-1.0, "HUD_TOOL_THREAD", [metres], TaskBlock.OWNER_NIGHT)
				"phase_prism":
					_task.set_progress(-1.0, "HUD_TOOL_PRISM", [], TaskBlock.OWNER_NIGHT)
				_:
					_task.set_progress(-1.0, "HUD_TOOL_LANTERN", [], TaskBlock.OWNER_NIGHT)
			return
		var device := tr(str(EQUIPMENT[_carried_id]["name"]))
		_task.set_progress(-1.0, "HUD_TASK_CARRYING", [device], TaskBlock.OWNER_NIGHT)
		return
	_task.set_progress(-1.0, "", [], TaskBlock.OWNER_NIGHT)


## Slot 2's urgency. Two deadlines, either of which turns on all five channels:
## the incident clock, and the Curator being close enough that the clock has
## stopped being the thing that will end the run.
func _timer_urgent() -> bool:
	if _time_left <= URGENT_SECONDS:
		return true
	var distance := _curator_distance()
	return distance >= 0.0 and distance <= CURATOR_URGENT_RANGE


# --- THE TERMINAL'S CORRUPTION -----------------------------------------------
#
# game/TerminalFrame.gd carries a corruption level and says, in its own header,
# that wiring it is the next phase's job and that the intended sources are "night
# number and remaining anomalies for the sustained floor, Curator distance for
# the pulse, and a blackout ... for signal loss". This is that wiring, minus the
# signal-loss case -- see _night_corruption() for why that one is left alone.


## Sustained corruption, 0..1, from state the night loop already keeps.
##
##   blackout ... CORRUPT_BLACKOUT once the museum is on emergency power. Before
##                that the building is a workplace and the terminal is clean.
##   night ...... CORRUPT_PER_NIGHT per night past the first.
##   clock ...... up to CORRUPT_TIMER_SPAN as an incident timer runs out. This is
##                the one that moves while the player watches, and it is the
##                largest term, because a containment window closing IS the
##                thing the interface is degrading in sympathy with.
##
## The two ends are absolute rather than additive: a failed run reads 1.0 (the
## containment is gone, and the integrity meter should say so in digits), and a
## finished one reads 0.0.
##
## NOT WIRED: TerminalFrame.set_signal_lost(). It replaces the body of the page
## with a torn picture carrying one message, which on the fail page would hide
## FAIL_RETRY -- the only line telling the player how to leave -- and on the
## protocol page would hide the device name the page exists to deliver. It wants
## a screen of its own to land on, which this file does not have one of yet.
func _night_corruption() -> float:
	if _state == STATE_FAILED:
		return 1.0
	if _state == STATE_WIN or _state == STATE_NIGHT_DONE:
		return 0.0
	var level := 0.0
	if _map != null and bool(_map.get("_blackout_done")):
		level += CORRUPT_BLACKOUT
	level += CORRUPT_PER_NIGHT * float(_night - 1)
	if _state == STATE_ANOMALY:
		var total: float = maxf(float(NIGHT_CONFIG[_night]["timer"]), 1.0)
		level += CORRUPT_TIMER_SPAN * clampf(1.0 - _time_left / total, 0.0, 1.0)
	return clampf(level, 0.0, 1.0)


## The core chip: a translated state row AND a level, so the reading never rests
## on the chip's colour. CORE_CRITICAL also doubles the chip's border width.
func _core_state() -> Array:
	match _state:
		STATE_FAILED:
			return ["TERM_CORE_CRITICAL", TerminalFrame.CORE_CRITICAL]
		STATE_ANOMALY:
			if _timer_urgent():
				return ["TERM_CORE_CRITICAL", TerminalFrame.CORE_CRITICAL]
			return ["TERM_CORE_UNSTABLE", TerminalFrame.CORE_UNSTABLE]
		STATE_COUNTDOWN, STATE_CALM:
			return ["TERM_CORE_UNSTABLE", TerminalFrame.CORE_UNSTABLE]
	return ["TERM_CORE_NOMINAL", TerminalFrame.CORE_NOMINAL]


## Metres to the Curator, or -1.0 when there is nothing to report.
##
## Read, never written, and read out of the node that already owns it rather
## than duplicated here: GameplayEnhancements builds the Curator, decides when it
## hunts and holds it in `_watcher`. The hop through the group is the same one
## every other cross-node lookup in this file makes.
##
## Note this is NOT GameplayEnhancements._watch_distance(), which is gated on the
## CCTV tablet being open on purpose -- that readout is compensation for being
## blinded by the tablet, and giving it away with the tablet down would be a
## wallhack. Nothing here is shown to the player as a range: it moves a
## corruption level and an urgency flag, both of which the player could already
## infer from the Curator's own footsteps.
func _curator_distance() -> float:
	if _player == null or not is_instance_valid(_player):
		return -1.0
	var enhancements := get_tree().get_first_node_in_group("gameplay_enhancements")
	if enhancements == null:
		return -1.0
	var held: Variant = enhancements.get("_watcher")
	if held == null or not is_instance_valid(held):
		return -1.0
	var curator := held as Node3D
	# `active` is false before night two, during a pocket-dimension trial and
	# whenever no anomaly is running -- i.e. exactly when it is not a threat.
	if curator == null or not curator.is_inside_tree() \
			or not bool(curator.get("active")):
		return -1.0
	return _player.global_position.distance_to(curator.global_position)


## Wall time for the status cluster. See SHIFT_START_SECONDS.
func _shift_clock_seconds() -> float:
	var elapsed := 0.0
	if _state == STATE_ANOMALY:
		elapsed = maxf(float(NIGHT_CONFIG[_night]["timer"]) - _time_left, 0.0)
	return SHIFT_START_SECONDS + float(_night - 1) * 3600.0 + elapsed


## Everything a terminal page shows about the night, in one call.
func _push_terminal_state(frame: TerminalFrame) -> void:
	if frame == null:
		return
	var core := _core_state()
	frame.set_status(_night, _shift_clock_seconds(), str(core[0]), int(core[1]))
	frame.set_corruption(_night_corruption())


## Per frame: keep whatever page is on screen in step with the night, and let the
## Curator stab it.
##
## Only visible pages are touched. TerminalFrame._render() walks every label it
## owns, and there is never more than one page up at a time; a hidden one is
## brought up to date by _raise_terminal() on the way in, which is also the only
## way any of them is ever shown.
func _sync_terminals(delta: float) -> void:
	_curator_pulse_cooldown = maxf(0.0, _curator_pulse_cooldown - delta)
	var frame := _visible_terminal()
	if frame == null:
		# Nothing on screen: forget the last pushed level so the next page to come
		# up is repainted rather than skipped by the epsilon test below.
		_terminal_corruption = -1.0
		return
	var level := _night_corruption()
	if absf(level - _terminal_corruption) >= CORRUPT_EPSILON:
		_terminal_corruption = level
		_push_terminal_state(frame)
	if _curator_pulse_cooldown > 0.0:
		return
	var distance := _curator_distance()
	if distance < 0.0 or distance > CURATOR_PULSE_RANGE:
		return
	# Closest = strongest. The frame keeps this as a decaying spike on top of the
	# sustained floor, so the two systems compose without either knowing about the
	# other -- and under reduced_flashes it steps up once and back down once
	# instead of ramping, which is the frame's own contract.
	var closeness := 1.0 - clampf(distance / CURATOR_PULSE_RANGE, 0.0, 1.0)
	frame.pulse_corruption(CURATOR_PULSE_MAX * closeness, CURATOR_PULSE_SECONDS)
	_curator_pulse_cooldown = CURATOR_PULSE_INTERVAL


## The one terminal page currently on screen, or null. They are mutually
## exclusive by construction: fail and win are states, the protocol screen is
## hidden by both, and the F9 console refuses to open during a trial.
func _visible_terminal() -> TerminalFrame:
	if _admin_layer != null and _admin_layer.visible:
		return _admin_frame
	if _fail_frame != null and _fail_frame.visible:
		return _fail_frame
	if _win_frame != null and _win_frame.visible:
		return _win_frame
	if _protocol_layer != null and _protocol_layer.visible:
		return _protocol_frame
	return null


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
