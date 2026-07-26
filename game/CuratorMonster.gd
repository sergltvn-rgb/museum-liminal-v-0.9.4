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

## Emitted once when the Curator reaches the player. The listener owns the
## consequence (GameplayEnhancements turns it into a run failure); the Curator
## deliberately knows nothing about the night loop.
signal caught_player

const BASE_SPEED := 2.25
const SPEED_PER_NIGHT := 0.55
const CATCH_DISTANCE := 1.25
## Null lantern: slows the Curator while the operator carries it nearby.
const NULL_LANTERN_RANGE := 14.0
const NULL_LANTERN_FACTOR := 0.45
const TURN_SPEED := 6.0
## Re-issuing the path target every physics tick is wasted work; the player
## cannot outrun a third of a second of staleness.
const REPATH_INTERVAL := 0.35
const GRAVITY := 18.0
const EYE_HEIGHT := 1.5

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


func _ready() -> void:
	collision_layer=2; collision_mask=1
	var collision:=CollisionShape3D.new(); var capsule:=CapsuleShape3D.new(); capsule.radius=.38; capsule.height=2.25
	collision.position.y=1.12; collision.shape=capsule; add_child(collision); _build_model()
	_build_agent()


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
	if _agent != null:
		_agent.target_position = spawn


func _physics_process(delta: float) -> void:
	if not active or _caught or not _resolve_player():
		velocity = Vector3.ZERO
		return

	var target := _player.global_position

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

	if global_position.distance_to(_player.global_position) < CATCH_DISTANCE:
		_caught = true
		active = false
		velocity = Vector3.ZERO
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
	var head := global_position + Vector3.UP * EYE_HEIGHT
	if not _player_camera.is_position_in_frustum(head):
		return false
	var query := PhysicsRayQueryParameters3D.create(_player_camera.global_position, head)
	query.exclude = [_player.get_rid(), get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _resolve_player() -> bool:
	if is_instance_valid(_player) and is_instance_valid(_player_camera):
		return true
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _player == null:
		return false
	_player_camera = _player.get_node_or_null("Player Camera") as Camera3D
	return _player_camera != null


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
