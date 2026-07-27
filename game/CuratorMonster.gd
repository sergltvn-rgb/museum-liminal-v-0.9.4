class_name CuratorMonster
extends CharacterBody3D
## Procedural low-poly museum Curator: porcelain mannequin, uniform and CCTV eye.
##
## The Curator drives itself. It freezes whenever the player can actually see
## it and otherwise paths to the player through the baked museum navigation
## mesh (see FirstMuseumMap._add_navigation).
##
## Movement lives in _physics_process, not _process: move_and_slide() integrates
## against the physics step, so driving it from a render frame made the chase
## speed scale with the player's framerate — the Curator was roughly twice as
## fast at 144 Hz as at 60 Hz.
##
## It is also audible. The Curator carries its own positional players rather
## than borrowing AudioManager's shared 3D pool, so a door or a pickup cannot
## steal a footstep mid-stride, and both players sit on the SFX bus by name.

## Emitted once when the Curator reaches the player. The listener owns the
## consequence (GameplayEnhancements turns it into a run failure); the Curator
## deliberately knows nothing about the night loop.
signal caught_player

## Chase speed, in m/s, against PlayerController's walk_speed 4.5 and
## run_speed 7.5. Every night has to land inside that window: below 4.5 the
## player strolls away and the Curator is scenery, above 7.5 no amount of
## stamina saves them and the chase is a cutscene. The formula gives 4.9 / 5.6
## / 6.3 for nights 1-3, and it only hunts from night 2, so what ships is 5.6
## and 6.3: walking always loses ground and sprinting always gains it — but
## sprinting costs stamina (22/s of 100), which is what makes the gap a
## decision instead of a formality. It was 2.25 / 2.80 / 3.35, half a walk.
const BASE_SPEED := 4.9
const SPEED_PER_NIGHT := 0.7
const CATCH_DISTANCE := 1.25
## Null lantern: slows the Curator while the operator carries it nearby.
## 0.45 of the night-3 speed is 2.84 m/s, still below a walk, so the lantern
## keeps its promise: carry it and you can leave at walking pace.
const NULL_LANTERN_RANGE := 14.0
const NULL_LANTERN_FACTOR := 0.45
const TURN_SPEED := 6.0
## Re-issuing the path target every physics tick is wasted work; the player
## cannot outrun a third of a second of staleness.
const REPATH_INTERVAL := 0.35
const GRAVITY := 18.0

## Sample points for the weeping-angel test, in metres above the Curator's
## feet: shoe, coat torso, camera head (see _build_model for the geometry).
## One point at eye height was not enough — standing three metres away and
## looking up at the face put the head outside the tested point's frustum
## check often enough that the Curator kept walking while the player was
## staring straight at it.
const OBSERVE_HEIGHTS := [0.15, 1.35, 2.12]

## Audio. Everything below plays on the SFX bus (AudioManager owns the layout);
## if that bus is missing the players fall back to Master rather than erroring.
const AUDIO_BUS := "SFX"
## Distance in metres at which the Curator becomes inaudible. Wide enough to
## warn a room ahead, short enough that it reads as direction and range.
const HEAR_DISTANCE := 18.0
## One footstep per this many metres travelled, so the cadence is the movement
## rather than a timer that keeps ticking while the Curator is frozen.
const STEP_DISTANCE := 1.55
const STEP_VOLUME_DB := -6.0
## Footstep samples are a human on a museum floor; two-and-a-bit metres of
## porcelain and coat is not, so they are pitched down into a slow thud.
const STEP_PITCH := 0.58
const STEP_SOUNDS := ["res://audio/footstep1.wav", "res://audio/footstep2.wav",
	"res://audio/footstep3.wav"]
## The catch. This used to be land.wav dropped to 0.42 because res://audio/ had
## nothing better; curator_catch is a purpose-made impact stinger, so it plays at
## its natural pitch. It decodes at -21.8 dBFS RMS / -4.6 dBFS peak, about 15 dB
## hotter than the pitched-down landing thud it replaces, so the level has to
## come down even though the sound gets louder: at CATCH_DISTANCE the player's
## 3D gain is capped at max_db (+3), which puts -4 dB at -22.8 dBFS RMS out.
## That is within a decibel of fail.wav (-23.9 dBFS RMS, played at unity by
## GameManager a moment later), so the seize and the sting that follows it land
## at the same weight, with 5.6 dB of peak headroom left between them.
const CATCH_SOUND := "res://audio/generated/curator_catch.mp3"
const CATCH_VOLUME_DB := -4.0
## The breath. A real 5 s recording; the loop flag lives in its .import file.
## It decodes at -24.3 dBFS RMS / -3.3 dBFS peak, 10.2 dB quieter than the
## synthesised loop it replaces (-14.1 dBFS RMS, normalised to the ceiling), so
## -3 dB here lands about 4 dB under where the synth sat: still the clearest
## proximity cue the Curator has, but a recording carries its own detail and does
## not have to shout to be read. At 5 m that is -31.2 dBFS RMS out; at the
## unit_size distance and closer it peaks at -3.3 dBFS, which is the moment the
## player has roughly a second left anyway.
const BREATH_SOUND := "res://audio/generated/curator_breath.mp3"
const BREATH_VOLUME_DB := -3.0

## Music tension, handed to AudioManager.set_tension() every physics tick.
##
## The dread layer is deliberately the FIRST warning: it starts lifting at 26 m,
## outside HEAR_DISTANCE, so the music knows before the footsteps do. It reaches
## full at 3 m, which at chase speed is the last half-second before CATCH_DISTANCE.
## Between the two it is linear in distance, i.e. linear in amplitude, so "closer
## is louder" with no curve to explain. AudioManager owns the smoothing; the
## value handed over here is allowed to be as jumpy as the geometry is.
const TENSION_FAR := 26.0
const TENSION_NEAR := 3.0

## Set by GameplayEnhancements: false while no anomaly is running, during a
## pocket-dimension trial, or before night 2.
var active := false
var night := 1
## True while the operator carries the null lantern.
var slowed := false

var _player: CharacterBody3D = null
var _player_camera: Camera3D = null
var _agent: NavigationAgent3D = null
var _repath_left := 0.0
var _caught := false
var _steps: AudioStreamPlayer3D = null
var _breath: AudioStreamPlayer3D = null
var _step_streams: Array[AudioStream] = []
var _catch_stream: AudioStream = null
var _step_left := STEP_DISTANCE
var _audio_manager: Node = null


func _ready() -> void:
	collision_layer=2; collision_mask=1
	var collision:=CollisionShape3D.new(); var capsule:=CapsuleShape3D.new(); capsule.radius=.38; capsule.height=2.25
	collision.position.y=1.12; collision.shape=capsule; add_child(collision); _build_model()
	_build_agent()
	_build_audio()


func _build_agent() -> void:
	_agent = NavigationAgent3D.new()
	_agent.name = "Curator Navigation Agent"
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 1.0
	_agent.radius = 0.42
	_agent.height = 2.3
	# Avoidance only does something once velocities are fed back through
	# set_velocity()/velocity_computed. There is exactly one agent in the
	# museum, so enabling it would cost a server callback and change nothing.
	_agent.avoidance_enabled = false
	# When the player is somewhere the navmesh cannot reach, fall back to the
	# direct approach rather than freezing against a stale path.
	_agent.path_max_distance = 6.0
	add_child(_agent)


## Teleport the Curator to a fresh starting point and clear the caught latch.
func reset_at(spawn: Vector3) -> void:
	_caught = false
	velocity = Vector3.ZERO
	global_position = spawn
	_repath_left = 0.0
	_step_left = STEP_DISTANCE
	if _steps != null:
		# The catch stinger borrows this player and leaves it loud; a new night
		# must not open with a footstep at stinger level.
		_steps.stop()
		_steps.volume_db = STEP_VOLUME_DB
	_set_breathing(false)
	if _agent != null:
		_agent.target_position = spawn


func _physics_process(delta: float) -> void:
	if not active or _caught or not _resolve_player():
		velocity = Vector3.ZERO
		_set_breathing(false)
		# Not hunting is zero dread. This has to be pushed every tick and not
		# only on the transition: AudioManager eases towards whatever it was last
		# told, so a target that stops arriving would freeze the music wherever
		# the Curator happened to leave it.
		_report_tension(0.0)
		return

	var target := _player.global_position
	# Breathing runs for as long as it is hunting, frozen or not: while it
	# stands still under observation the breath is the only thing left telling
	# the player it is still there, and it keeps working behind them.
	_set_breathing(true)
	# Distance, not path length: the dread layer is about how close the thing is
	# to the player in the room, which is what the player can feel. It keeps
	# rising while the weeping-angel rule has the Curator frozen a metre away,
	# because standing still and being stared at is the tense part.
	_report_tension(clampf(inverse_lerp(TENSION_FAR, TENSION_NEAR,
		global_position.distance_to(target)), 0.0, 1.0))

	# Weeping-angel rule: the Curator only advances while unobserved. A frustum
	# test alone is not enough — a wall between the two still counts as unseen.
	if _is_observed():
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_repath_left -= delta
	if _repath_left <= 0.0:
		_repath_left = REPATH_INTERVAL
		_agent.target_position = target

	# is_navigation_finished() also covers "no navmesh baked yet", so the
	# Curator degrades to a straight-line stalker instead of standing still.
	var waypoint := target if _agent.is_navigation_finished() else _agent.get_next_path_position()
	var step := waypoint - global_position
	step.y = 0.0

	if step.length() > 0.05:
		var speed := BASE_SPEED + SPEED_PER_NIGHT * float(night - 1)
		if slowed and global_position.distance_to(target) < NULL_LANTERN_RANGE:
			speed *= NULL_LANTERN_FACTOR
		var desired := step.normalized() * speed
		velocity.x = desired.x
		velocity.z = desired.z
		_face(step, delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	# After move_and_slide, so the cadence follows the distance actually
	# covered: it slows with the null lantern and stops dead against a wall.
	_advance_footsteps(delta)

	if global_position.distance_to(_player.global_position) < CATCH_DISTANCE:
		_caught = true
		active = false
		velocity = Vector3.ZERO
		_set_breathing(false)
		_play_catch()
		caught_player.emit()


## Ease the yaw instead of snapping with look_at(): the Curator now rounds
## corners on a path, and an instant facing flip at every waypoint read as a
## glitch rather than as movement.
func _face(direction: Vector3, delta: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		return
	# Godot forward is -Z, so this is the yaw that points -Z along `flat`.
	var target_yaw := atan2(-flat.x, -flat.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))


## True while the player can actually see any part of the Curator.
##
## Three points instead of one. A single sample at eye height answered for a
## 2.3 m tall figure as if it were a dot: three metres away with the camera
## tilted up at the lens, the torso point fell out of the frustum, the check
## said "unobserved" and the Curator walked at a player who was looking right
## at it. Any of feet / torso / head being visible now counts.
##
## Frustum and occlusion have to agree per point — a head poking through the
## frustum while a wall covers it is not seen — so the ray is only cast for
## points that passed the cheap test, and a point that fails either one simply
## moves on to the next.
func _is_observed() -> bool:
	if _player_camera == null:
		return false
	# Only the camera actually rendering can observe anything. A parked camera
	# keeps its last transform, so is_position_in_frustum() below would happily
	# answer for a viewpoint nobody is looking through — the CCTV tablet takes
	# the viewport this way, and so does the intro cinematic. Camera3D.current
	# resolves to `get_viewport().get_camera_3d() == self` at runtime, which
	# lets the Curator stay ignorant of whatever stole the view.
	if not _player_camera.current:
		return false
	var space := get_world_3d().direct_space_state
	var eye := _player_camera.global_position
	var blockers: Array[RID] = [_player.get_rid(), get_rid()]
	for height: float in OBSERVE_HEIGHTS:
		var point := global_position + Vector3.UP * height
		if not _player_camera.is_position_in_frustum(point):
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, point)
		query.exclude = blockers
		if space.intersect_ray(query).is_empty():
			return true
	return false


func _resolve_player() -> bool:
	if is_instance_valid(_player) and is_instance_valid(_player_camera):
		return true
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _player == null:
		return false
	_player_camera = _player.get_node_or_null("Player Camera") as Camera3D
	return _player_camera != null


func _build_audio() -> void:
	for path: String in STEP_SOUNDS:
		if ResourceLoader.exists(path):
			_step_streams.append(load(path) as AudioStream)
		else:
			push_warning("CuratorMonster: missing %s" % path)
	if ResourceLoader.exists(CATCH_SOUND):
		_catch_stream = load(CATCH_SOUND) as AudioStream
	else:
		push_warning("CuratorMonster: missing %s" % CATCH_SOUND)
	_steps = AudioStreamPlayer3D.new()
	_steps.name = "Curator Footsteps"
	# At the shoes and at the lens: two heights a metre and a half apart is the
	# difference between "something is in the room" and "it is behind you".
	_steps.position = Vector3(0.0, 0.12, 0.0)
	_steps.volume_db = STEP_VOLUME_DB
	_steps.max_distance = HEAR_DISTANCE
	_steps.unit_size = 4.5
	_steps.panning_strength = 1.35
	_steps.bus = _audio_bus()
	add_child(_steps)
	_breath = AudioStreamPlayer3D.new()
	_breath.name = "Curator Breath"
	_breath.position = Vector3(0.0, 2.05, 0.0)
	_breath.volume_db = BREATH_VOLUME_DB
	_breath.max_distance = HEAR_DISTANCE
	_breath.unit_size = 3.2
	_breath.panning_strength = 1.1
	_breath.bus = _audio_bus()
	_breath.stream = _breath_stream()
	add_child(_breath)


## The breathing loop.
##
## This used to be synthesised here - noise through a one-pole low-pass under an
## inhale/exhale envelope - purely because res://audio/ held twenty wavs and not
## one of them was a breath. curator_breath.mp3 is a real 5 s recording, so the
## synthesiser is gone rather than kept as a fallback: a fallback that only fires
## when a shipped asset is missing is a branch nobody ever runs, and _set_breathing()
## already treats a null stream as "no breath" instead of erroring.
##
## Looping is the .import file's job (loop=true on the mp3). Checked here rather
## than assumed: a reimport that dropped the flag would give the Curator one
## five-second breath per night and silence after it, which looks like a bug in
## the chase logic and is not one.
func _breath_stream() -> AudioStream:
	if not ResourceLoader.exists(BREATH_SOUND):
		push_warning("CuratorMonster: missing %s - the Curator will not breathe" % BREATH_SOUND)
		return null
	var stream := load(BREATH_SOUND) as AudioStream
	var mp3 := stream as AudioStreamMP3
	if mp3 != null and not mp3.loop:
		push_warning("CuratorMonster: %s imported without loop - breathing once only" % BREATH_SOUND)
	return stream


## Hand the current dread level to AudioManager, if there is one. Cached rather
## than looked up per tick: this runs at the physics rate for the whole night.
func _report_tension(level: float) -> void:
	if not is_instance_valid(_audio_manager):
		_audio_manager = get_tree().get_first_node_in_group("audio_manager")
		if _audio_manager == null:
			return
	if _audio_manager.has_method("set_tension"):
		_audio_manager.set_tension(level)


## SFX if AudioManager's layout is loaded, Master otherwise. An AudioStreamPlayer3D
## silently reports Master for an unknown bus anyway, but saying so here keeps a
## stripped export explainable instead of "the Curator ignores the SFX slider".
func _audio_bus() -> StringName:
	if AudioServer.get_bus_index(AUDIO_BUS) >= 0:
		return StringName(AUDIO_BUS)
	push_warning("CuratorMonster: no '%s' bus - routing to Master" % AUDIO_BUS)
	return &"Master"


## One footstep per STEP_DISTANCE metres of ground actually covered. Driving
## this from distance rather than a timer means the freeze is audible: the
## instant the weeping-angel rule stops the Curator the steps stop too, and
## they resume from the same point in the stride when the player looks away.
func _advance_footsteps(delta: float) -> void:
	var travelled := Vector2(velocity.x, velocity.z).length() * delta
	if travelled <= 0.0001:
		return
	_step_left -= travelled
	if _step_left > 0.0:
		return
	_step_left += STEP_DISTANCE
	if _step_streams.is_empty() or _steps == null:
		return
	_steps.stream = _step_streams[randi() % _step_streams.size()]
	# Pitched down and jittered: the three samples are 80-100 ms, so at 0.58
	# they land as ~160 ms thuds and never overlap at any of the three speeds.
	_steps.pitch_scale = STEP_PITCH * randf_range(0.94, 1.06)
	_steps.play()


func _play_catch() -> void:
	if _catch_stream == null or _steps == null:
		return
	# Reuses the footstep player on purpose: the catch is the last sound this
	# Curator makes before the run ends, so there is nothing left to interrupt.
	# Same player, same call site, same moment in _physics_process as before, so
	# it still lands ahead of the "fail" sting GameManager plays once the death
	# sequence has run - only the sample and its level change.
	_steps.stream = _catch_stream
	# The previous sample was pitched down an octave and a half to fake an
	# impact. This one is an impact, so leave it alone; reset explicitly because
	# _advance_footsteps() leaves STEP_PITCH on this player.
	_steps.pitch_scale = 1.0
	_steps.volume_db = CATCH_VOLUME_DB
	_steps.play()


func _set_breathing(on: bool) -> void:
	if _breath == null or _breath.stream == null:
		return
	if on:
		if not _breath.playing:
			_breath.play()
	elif _breath.playing:
		_breath.stop()


func _build_model() -> void:
	var cloth := _material(Color(0.035, 0.05, 0.06), 0.85, 0.0)
	var porcelain := _material(Color(0.62, 0.64, 0.61), 0.72, 0.0)
	var brass := _material(Color(0.32, 0.22, 0.10), 0.3, 0.75)
	var black := _material(Color(0.006, 0.008, 0.01), 0.2, 0.3)
	_part_box("Coat Torso", Vector3(0, 1.35, 0), Vector3(0.62, 0.95, 0.34), cloth)
	_part_box("Coat Tail L", Vector3(-0.18, 0.82, 0.08), Vector3(0.25, 0.62, 0.25), cloth)
	_part_box("Coat Tail R", Vector3(0.18, 0.82, 0.08), Vector3(0.25, 0.62, 0.25), cloth)
	_part_cylinder("Neck", Vector3(0, 1.92, 0), 0.1, 0.22, porcelain)
	_part_box("Camera Head", Vector3(0, 2.12, -0.02), Vector3(0.42, 0.28, 0.34), porcelain)
	var lens := _part_cylinder("Camera Lens", Vector3(0, 2.12, -0.24), 0.105, 0.12, black)
	lens.rotation_degrees.x = 90
	var lens_ring := _part_cylinder("Lens Ring", Vector3(0, 2.12, -0.30), 0.14, 0.035, brass)
	lens_ring.rotation_degrees.x = 90
	# Asymmetric arms: one human, one overlong museum handling tool.
	var left_arm := _part_cylinder("Left Upper Arm", Vector3(-0.42, 1.45, 0), 0.09, 0.72, cloth)
	left_arm.rotation_degrees.z = -8
	var left_forearm := _part_cylinder("Left Forearm", Vector3(-0.48, 0.92, -0.03), 0.075, 0.54, porcelain)
	left_forearm.rotation_degrees.z = -4
	var right_arm := _part_cylinder("Right Long Arm", Vector3(0.43, 1.18, 0), 0.085, 1.22, cloth)
	right_arm.rotation_degrees.z = 7
	_part_box("Handling Claw", Vector3(0.50, 0.52, -0.04), Vector3(0.28, 0.12, 0.24), brass)
	for x in [-0.18, 0.18]:
		_part_cylinder("Leg", Vector3(x, 0.42, 0), 0.105, 0.82, cloth)
		_part_box("Shoe", Vector3(x, 0.08, -0.12), Vector3(0.24, 0.14, 0.42), black)
	for y in [1.55, 1.32, 1.09]:
		var button := _part_cylinder("Coat Button", Vector3(0, y, -0.185), 0.025, 0.025, brass)
		button.rotation_degrees.x = 90
	var eye := OmniLight3D.new()
	eye.name = "Recording Eye"
	eye.position = Vector3(0, 2.12, -0.38)
	eye.light_color = Color(1.0, 0.04, 0.02)
	eye.light_energy = 0.55
	eye.omni_range = 2.5
	add_child(eye)


func _part_box(part_name: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name = part_name; node.position = pos
	var mesh := BoxMesh.new(); mesh.size = size; node.mesh = mesh; node.material_override = mat
	add_child(node); return node


func _part_cylinder(part_name: String, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name = part_name; node.position = pos
	var mesh := CylinderMesh.new(); mesh.top_radius = radius; mesh.bottom_radius = radius; mesh.height = height
	node.mesh = mesh; node.material_override = mat; add_child(node); return node


func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.roughness = roughness; mat.metallic = metallic
	return mat
