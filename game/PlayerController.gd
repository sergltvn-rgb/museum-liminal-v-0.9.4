extends CharacterBody3D

@export var walk_speed := 4.5
@export var run_speed := 7.5
@export var jump_velocity := 6.0
@export var mouse_sensitivity := 0.0025
@export var gravity := 18.0
@export var max_stamina := 100.0
@export var stamina_drain_per_second := 22.0
@export var stamina_recovery_per_second := 16.0
@export_category("Управление движением")
@export var ground_acceleration := 28.0
@export var ground_deceleration := 34.0
@export var air_acceleration := 8.0
@export var air_control := 0.42
@export var step_height := 0.38
## How far ahead the step probe looks for something to climb. One frame of
## walking is 7.5 cm at 60 Hz, which is not enough to see a kerb before the body
## is already jammed into it. This only DETECTS an obstacle; the height is
## measured by a ray, so this value no longer has to clear the capsule shell.
@export var step_probe_distance := 0.30
## Slack above the ledge, so the body lands ON the step and not INSIDE it.
@export var step_clearance := 0.02
## Crouched pace. Slower than a walk on purpose: the crouch is the stealth
## trade -- a smaller silhouette and quieter steps in exchange for speed.
@export var crouch_speed := 2.1
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.14
@export var short_jump_multiplier := 0.48

@onready var camera: Camera3D = $"Player Camera"
@onready var flashlight: SpotLight3D = $"Player Camera/Player Flashlight"

# Off while the CCTV feed is open (so the player cannot walk around blindly),
# while a rift trial is being set up, and while a fail / night-done / win overlay
# is up. GameManager.player_controls_allowed() is the authority on the last case:
# nothing here or elsewhere may assign true on a hunch.
var controls_enabled := true
# Legs off, head on. Hiding inside a locker (HideSpot) must not also take the
# mouse away: the whole point of the mechanic is watching the room through the
# slats while unable to run, and `controls_enabled = false` would blind the
# player at the exact moment they most need to look.
var movement_locked := false

var _pitch := 0.0
var _step_timer := 0.0
var _was_on_floor := true
var _audio_manager: Node = null
var stamina := 100.0
var flashlight_enabled := true
var _recovery_delay := 0.0
var _exhausted := false
var gravity_direction := Vector3.DOWN
var _coyote_left := 0.0
var _jump_buffer_left := 0.0
var _last_safe_transform := Transform3D.IDENTITY
var _safe_position_timer := 0.0
# The body's own capsule, needed to aim the step ray past its shell. Cached as
# the shape (not as a radius) because PlayerScaleController rewrites the radius
# while a size trial is running, and a copied number would go stale.
var _step_capsule: CapsuleShape3D = null
# True while the body is held down, whether the player is still holding the key
# or the ceiling is refusing to let go. Read by _update_footsteps() and by the
# speed pick; the capsule and camera themselves belong to PlayerScaleController.
var crouching := false
var _scale_controller: Node = null


func _ready() -> void:
	add_to_group("player")
	_pull_mouse_sensitivity()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	stamina = max_stamina
	# Going DOWN a step was the other half of the defect. Without a snap length
	# the body leaves the floor at the lip of every step, spends a few frames in
	# the air (so is_on_floor() is false, so the step logic and the footsteps and
	# the coyote timer all switch off) and lands with a thud. Snapping over the
	# same height the player can climb makes a flight of steps walkable in both
	# directions.
	floor_snap_length = maxf(step_height, 0.1)
	var collision := get_node_or_null("Player Collision") as CollisionShape3D
	if collision != null:
		_step_capsule = collision.shape as CapsuleShape3D
	# Sibling under the same body. Looked up by group rather than by node name so
	# both assembly sites (FirstMuseumMap and TutorialPrologue) keep working.
	for child in get_children():
		if child.is_in_group("player_scale_controller"):
			_scale_controller = child
			break


## SettingsManager pushes the saved sensitivity onto whatever is in the "player"
## group at the moment the value changes -- see its `_apply_sensitivity()`, which
## is also all `_apply_all()` does on startup. A player that enters the tree
## *after* that push was never pushed to, and every one of them does: the
## museum scene is reloaded on retry, on "Restore progress" and on the walk out
## of the tutorial, and each reload builds a fresh PlayerController carrying the
## exported default. The setting was saved, restored and then silently ignored.
## Pulling once on entry closes the other half of the handshake.
func _pull_mouse_sensitivity() -> void:
	var settings := get_tree().get_first_node_in_group("settings_manager")
	if settings == null:
		return
	var saved: Variant = settings.get("mouse_sensitivity")
	if saved is float:
		# Same clamp SettingsManager.set_mouse_sensitivity() applies, so a config
		# file edited by hand cannot make the mouse unusable in either direction.
		mouse_sensitivity = clampf(saved, 0.001, 0.006)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity,
			deg_to_rad(-85), deg_to_rad(85))
		camera.rotation.x = _pitch

	if event.is_action_pressed("flashlight"):
		flashlight_enabled = not flashlight_enabled
		flashlight.visible = flashlight_enabled
		var am := _audio()
		if am != null and am.has_method("play_sfx"):
			am.play_sfx("tablet_click", -8.0, 0.82 if flashlight_enabled else 0.68)

	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var local_up := -gravity_direction.normalized(); up_direction = local_up
	var grounded := is_on_floor()
	_coyote_left = coyote_time if grounded else maxf(0.0, _coyote_left-delta)
	if not grounded: velocity += gravity_direction.normalized()*gravity*delta
	if not controls_enabled:
		# Do not poll "jump" while control is off: the A button also drives
		# "confirm" on the terminal overlays, and a buffered press would fire
		# as a jump the instant control comes back. Clear rather than decay so
		# nothing survives a disabled period however short it was.
		_jump_buffer_left = 0.0
		velocity = velocity.project(local_up)+velocity.slide(local_up).move_toward(Vector3.ZERO,ground_deceleration*delta)
		move_and_slide(); return
	if movement_locked:
		_jump_buffer_left = 0.0
		velocity = Vector3.ZERO
		move_and_slide()
		return
	_jump_buffer_left = jump_buffer_time if Input.is_action_just_pressed("jump") else maxf(0.0,_jump_buffer_left-delta)
	var input_dir := Input.get_vector("move_left","move_right","move_forward","move_back")
	_update_crouch()
	# Sprinting out of a crouch is not a thing: standing up first is the cost.
	var wants_run := Input.is_action_pressed("sprint") and input_dir.length()>0.08 and not _exhausted and not crouching
	if wants_run:
		stamina=maxf(0.0,stamina-stamina_drain_per_second*delta); _recovery_delay=.7
		if stamina<=0.0:
			_exhausted=true; wants_run=false
			_set_panting(true)
	else:
		_recovery_delay=maxf(0.0,_recovery_delay-delta)
		if _recovery_delay<=0.0: stamina=minf(max_stamina,stamina+stamina_recovery_per_second*delta)
		if _exhausted and stamina>=max_stamina*.25:
			_exhausted=false
			_set_panting(false)
	var speed := run_speed if wants_run else (crouch_speed if crouching else walk_speed)
	var forward := (-camera.global_transform.basis.z).slide(local_up).normalized()
	var right := camera.global_transform.basis.x.slide(local_up).normalized()
	var direction := (right*input_dir.x+forward*-input_dir.y).normalized()
	var planar := velocity.slide(local_up)
	var target := direction*speed*(1.0 if grounded else air_control)
	var accel := (ground_acceleration if not direction.is_zero_approx() else ground_deceleration) if grounded else air_acceleration
	planar=planar.move_toward(target,accel*delta); velocity=velocity.project(local_up)+planar
	if _jump_buffer_left>0.0 and _coyote_left>0.0:
		velocity=planar+local_up*jump_velocity; _jump_buffer_left=0.0; _coyote_left=0.0
	elif Input.is_action_just_released("jump") and velocity.dot(local_up)>0.0:
		velocity-=local_up*velocity.dot(local_up)*(1.0-short_jump_multiplier)
	elif grounded: velocity+=gravity_direction.normalized()*.1
	if grounded: _try_step_up(direction,speed,delta)
	var was_falling := velocity.dot(gravity_direction.normalized())>3.0
	move_and_slide(); _update_safe_transform(delta); _update_footsteps(delta,wants_run,was_falling)

## Walking over a kerb, measured rather than assumed.
##
## The old version probed exactly one frame of motion (speed * delta -- 7.5 cm
## at walking pace and 60 Hz, less on a fast machine), and on any hit at all it
## teleported the body up by the WHOLE step_height and left it there. A 4 cm
## floor seam threw the camera up 38 cm and gravity dropped it back the same
## frame, which is the hop the player kept hitting. It also never checked that
## anything was underneath the raised body, so it would climb the face of a
## wall whenever there was clearance above it and then fall back down.
##
## This version measures the ledge:
##   1. probe at least `step_probe_distance` ahead, so a kerb is seen before the
##      body is already pressed into it;
##   2. drop rays along the path, from just past the capsule shell out to the
##      full probe length, and take the REAL rise from the highest standable
##      face they land on;
##   3. give up if nothing standable was found (the body's own floor_max_angle
##      decides that, not a second opinion about what a floor is) or if the face
##      is higher than step_height;
##   4. give up if there is no headroom for THAT rise;
##   5. give up if the obstacle is still in the way once lifted -- that is a
##      wall, not a step.
##
## The lift is applied to the position directly, as before: velocity is left
## alone so the step costs no speed and adds no upward momentum.
##
## The height is measured by a RAY, not by dropping the capsule back down. The
## capsule version was measured on the live map and it lied on every ledge,
## because a capsule sweep stops when the shell touches the ledge, and the shell
## is a radius away from the body's axis: the rounded side of the capsule caught
## the lip of the step, so the collision reported the ledge's SIDE and not its
## top. The kerb around the rotunda (a true 0.160) measured 0.095, the street
## kerb (0.099) measured 0.034, and with a shorter probe the cylindrical kerb was
## not even noticed. Everything was still climbable only because
## floor_snap_length papered over the shortfall. A ray dropped from beyond the
## shell hits the top face itself, so `rise` is the real height and the lift can
## be exact.
func _try_step_up(direction: Vector3, speed: float, delta: float) -> void:
	if direction.length_squared() < 0.01 or step_height <= 0.0:
		return
	# Every axis here is the body's own up, so the step works in the rift zones
	# where gravity points sideways or backwards. Vector3.UP used to be hardcoded,
	# and the whole routine was skipped unless gravity pointed straight down,
	# which turned every ledge into a wall the moment gravity was rotated.
	var up: Vector3 = -gravity_direction.normalized()
	var heading: Vector3 = direction.normalized()
	var probe: Vector3 = heading * maxf(speed * delta, step_probe_distance)
	if not test_move(global_transform, probe):
		return
	var ceiling: float = step_height + step_clearance
	var radius: float = _step_capsule.radius if _step_capsule != null else 0.35
	# The rays have to cover the whole path the body is about to travel, not just
	# the far end of it. Measured: standing 0.15 m off a kerb puts the body's axis
	# 0.50 m from the edge, so a single ray at radius + 0.06 still landed on the
	# road behind the kerb and reported a rise of 0.000 -- the street kerb and both
	# sides of the rotunda kerb were simply not climbed. Sampling from just past
	# the shell out to the full probe length and taking the HIGHEST standable face
	# also handles a narrow step, where a single far ray would overshoot the tread
	# and measure whatever lies beyond it.
	var space := get_world_3d().direct_space_state
	var reach: float = probe.length()
	var rise := 0.0
	for i in 4:
		var ahead: float = radius + lerpf(0.06, reach, float(i) / 3.0)
		var from: Vector3 = global_position + up * ceiling + heading * ahead
		var query := PhysicsRayQueryParameters3D.create(from, from - up * (ceiling + 0.05))
		query.exclude = [get_rid()]
		query.collision_mask = collision_mask
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			continue
		if (hit["normal"] as Vector3).dot(up) < cos(floor_max_angle):
			continue
		rise = maxf(rise, ((hit["position"] as Vector3) - global_position).dot(up))
	if rise <= 0.001 or rise > step_height:
		return
	# Headroom is asked for the lift we are actually about to make. Asking for the
	# full step_height (0.40 with the clearance) even to cross a 4 cm floor seam
	# meant the player stopped taking the floor under a low shelf or in a 2.0 m
	# doorway.
	var lift: Vector3 = up * (rise + step_clearance)
	if test_move(global_transform, lift):
		return
	if test_move(global_transform.translated(lift), probe):
		return
	global_position += lift

## Crouch, held rather than toggled, and refused release under a low ceiling.
##
## The capsule, the collision offset and the camera height are NOT touched here.
## PlayerScaleController owns all three and rewrites them every frame a size
## change is in flight, so editing them from this file would have produced a
## fight for the shape on any frame an anomaly was resizing the player. This
## function only decides the intent and reads back the geometry it needs.
##
## Standing up is blocked while there is no headroom for the full height: without
## that check, releasing the key under a shelf grows the capsule into the shelf
## and move_and_slide() ejects the body sideways or through the floor. The test
## asks for the height that is actually missing, at the current anomaly scale,
## rather than a hardcoded 1.8.
func _update_crouch() -> void:
	if _scale_controller == null:
		crouching = false
		return
	var wants := Input.is_action_pressed("crouch")
	if not wants and crouching and not _has_standing_headroom():
		wants = true
	crouching = wants
	_scale_controller.call("set_crouch", wants)


func _has_standing_headroom() -> bool:
	if _step_capsule == null or _scale_controller == null:
		return true
	var standing: float = float(_scale_controller.call("standing_height"))
	# The capsule's foot stays put and its crown rises, so the missing height is
	# exactly how far up the body has to be able to move.
	var missing: float = standing - _step_capsule.height
	if missing <= 0.001:
		return true
	return not test_move(global_transform, -gravity_direction.normalized() * missing)


func _update_safe_transform(delta:float)->void:
	_safe_position_timer+=delta
	if is_on_floor() and _safe_position_timer>=.25:
		_last_safe_transform=global_transform; _safe_position_timer=0.0

# Restores the control state that was in force on entry instead of forcing true:
# gravity is applied above the "not controls_enabled" early-out in
# _physics_process, so a player frozen behind a fail overlay keeps falling and
# still trips GameManager's kill plane. Both RiftTrialManager callers teleport
# mid-trial with control on, so they get it back exactly as before.
func safe_teleport(target_position:Vector3,new_gravity:=Vector3.DOWN)->void:
	var was_enabled := controls_enabled
	controls_enabled=false; velocity=Vector3.ZERO; set_gravity_direction(new_gravity); global_position=target_position
	_coyote_left=0.0; _jump_buffer_left=0.0
	await get_tree().physics_frame
	velocity=Vector3.ZERO; controls_enabled=was_enabled

func return_to_last_safe_position()->void:
	if _last_safe_transform!=Transform3D.IDENTITY: await safe_teleport(_last_safe_transform.origin+Vector3.UP*.12)


# --- STAMINA READOUT --------------------------------------------------------
#
# The panel this file used to build is gone. It was a 260x58 card pinned to the
# bottom-left corner on its own CanvasLayer (14), which made it the fifth of the
# seven controls that between them answered "what am I doing now" -- each in a
# different corner, each owned by a different file, none of them louder than the
# others. game/TaskBlock.gd's header lists all seven and the layout defect they
# add up to; the fix is one block, so stamina moved into its status slot with
# the objective, the countdown and the hint.
#
# What is left here is the two facts the block needs. This node no longer draws
# anything, holds no Control references and no longer runs a per-physics-frame
# UI update: GameManager polls these while it is composing the block, which is
# once per render frame rather than once per physics step.
#
# Both are read-only and allocation-free, and both stay correct when the block
# does not exist at all (a headless suite, or a scene without a GameManager).


## Stamina as 0..1. The block hides the bar entirely at full, so a player who is
## not sprinting never sees a gauge pegged at 100% -- a bar that never moves is
## furniture, and this one now appears exactly when it has something to say.
## The pant loop answers the exhausted flag the moment it flips, not the HUD.
func _set_panting(on: bool) -> void:
	var am := get_tree().get_first_node_in_group("audio_manager")
	if am != null and am.has_method("set_panting"):
		am.set_panting(on)


func stamina_ratio() -> float:
	return clampf(stamina / maxf(max_stamina, 1.0), 0.0, 1.0)


## True while sprinting is locked out. The block pairs this with a different
## caption row (HUD_STAMINA_EXHAUSTED), not with a colour change alone: the old
## panel signalled exhaustion by turning its fill red, which says nothing to a
## deuteranope and nothing at all on a washed-out panel.
func is_exhausted() -> bool:
	return _exhausted


func _update_footsteps(delta: float, running: bool, was_falling: bool) -> void:
	var am := _audio()
	if am == null:
		_was_on_floor = is_on_floor()
		return
	# Landing thud after a real fall.
	if is_on_floor() and not _was_on_floor and was_falling:
		if am.has_method("play_sfx"):
			am.play_sfx("land", -10.0)
	_was_on_floor = is_on_floor()
	# Footsteps while moving on the floor.
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horizontal > 1.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			# Crouched steps are spaced out, not just quieter: this is the interval
			# the coming noise system will read as the player's audible footprint.
			_step_timer = 0.31 if running else (0.68 if crouching else 0.45)
			if am.has_method("footstep"):
				am.footstep(running)
	else:
		_step_timer = 0.12


func _audio() -> Node:
	if _audio_manager == null or not is_instance_valid(_audio_manager):
		_audio_manager = get_tree().get_first_node_in_group("audio_manager")
	return _audio_manager


func set_gravity_direction(direction: Vector3) -> void:
	if direction.length() < 0.1:
		return
	gravity_direction = direction.normalized()
	var new_up := -gravity_direction
	up_direction = new_up
	var forward := -global_transform.basis.z
	forward = forward.slide(new_up).normalized()
	if forward.length() < 0.1:
		forward = Vector3.FORWARD.slide(new_up).normalized()
	var origin := global_position
	global_transform = Transform3D(Basis.looking_at(forward, new_up), origin)
	velocity = Vector3.ZERO


func reset_gravity_direction() -> void:
	set_gravity_direction(Vector3.DOWN)
