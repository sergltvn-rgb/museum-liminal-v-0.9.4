@tool
extends Node3D
## A pair of hinged door leaves. Back-of-house doors remain proximity driven;
## the ceremonial street entrance is manual and only changes state when the
## player presses the project's `interact` action (E / gamepad X).
##
## Node layout, built by FirstMuseumMap._door_leaves():
##
##   Door Swing <centre>        this node, on the seam between two rooms
##     Door Hinge <centre> 0    frozen kinematic RigidBody3D pivot
##       lp_*_door_leaf         visual leaf, running along local +X
##       Door Leaf Collider     one deliberate BoxShape3D for the moving leaf
##     Door Hinge <centre> 1    the other leaf, mirrored by its shut yaw
##     Door Sensor              legacy automatic mode only; absent on map doors
##
## WHY RIGIDBODY3D. Navigation is baked from static colliders. A StaticBody3D or
## AnimatableBody3D leaf would bake a wall across its own doorway. A frozen
## kinematic RigidBody3D still stops and gently shoves the player while moving,
## but Recast ignores it and the doorway remains connected in every pose.

const SWING_SPEED := 150.0
const EASE_ARC := 22.0
const EASE_FLOOR := 0.18
const OPEN_HOLD := 2.2
const SETTLE_HOLD := 5.0
const SENSOR_SIZE := Vector3(3.4, 2.4, 3.4)
const SETTLED_DEG := 0.05
## GameManager uses this group for every unpowered museum swing pair. Office
## blast doors keep their own `office_door` group and power economy untouched.
const INTERACTION_GROUP := "museum_swing_door"
const INTERACTION_HEIGHT := 1.60

var _hinges: Array[Node3D] = []
var _open_yaw: PackedFloat32Array = PackedFloat32Array()
var _shut_yaw: PackedFloat32Array = PackedFloat32Array()
var _inside := 0
var _hold := SETTLE_HOLD
var _open := true
var _interaction_required := false


func _ready() -> void:
	set_physics_process(not _hinges.is_empty())


## Both angle lists are absolute Y rotations in degrees. Map doors pass
## `interaction_required = true`: they start shut, have no proximity sensor,
## join INTERACTION_GROUP and hold state until another E press. The automatic
## branch remains only as a safe reusable fallback for non-map callers.
func setup(hinges: Array, open_yaw: Array, shut_yaw: Array,
		interaction_required := false) -> void:
	_hinges.clear()
	_open_yaw = PackedFloat32Array()
	_shut_yaw = PackedFloat32Array()
	for i in range(hinges.size()):
		var hinge := hinges[i] as Node3D
		if hinge == null:
			continue
		_hinges.append(hinge)
		_open_yaw.append(float(open_yaw[i]))
		_shut_yaw.append(float(shut_yaw[i]))
	_interaction_required = bool(interaction_required)
	if _interaction_required:
		_open = false
		_hold = 0.0
		add_to_group(INTERACTION_GROUP)
	else:
		_open = true
		_hold = SETTLE_HOLD
		_add_sensor()
	set_physics_process(not _hinges.is_empty())


func _add_sensor() -> void:
	if has_node("Door Sensor"):
		return
	var area := Area3D.new()
	area.name = "Door Sensor"
	area.monitorable = false
	var shape := CollisionShape3D.new()
	shape.name = "Door Sensor Shape"
	var box := BoxShape3D.new()
	box.size = SENSOR_SIZE
	shape.shape = box
	shape.position = Vector3(0.0, SENSOR_SIZE.y * 0.5, 0.0)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if not _interaction_required and body is CharacterBody3D:
		_inside += 1


func _on_body_exited(body: Node) -> void:
	if not _interaction_required and body is CharacterBody3D:
		_inside = maxi(0, _inside - 1)


func _physics_process(delta: float) -> void:
	if not _interaction_required:
		if _inside > 0:
			_hold = OPEN_HOLD
			_open = true
		elif _hold > 0.0:
			_hold -= delta
		else:
			_open = false

	var step := SWING_SPEED * delta
	for i in range(_hinges.size()):
		var hinge := _hinges[i]
		if not is_instance_valid(hinge):
			continue
		var target: float = _open_yaw[i] if _open else _shut_yaw[i]
		var euler := hinge.rotation_degrees
		var diff: float = target - euler.y
		if absf(diff) < SETTLED_DEG:
			continue
		var slow: float = clampf(absf(diff) / EASE_ARC, EASE_FLOOR, 1.0)
		euler.y += clampf(diff, -step * slow, step * slow)
		hinge.rotation_degrees = euler


## Public interaction contract consumed by GameManager and the entrance probe.
func is_interaction_required() -> bool:
	return _interaction_required


func interaction_position() -> Vector3:
	return global_position + Vector3(0.0, INTERACTION_HEIGHT, 0.0)


func is_closed() -> bool:
	return not _open


func set_open(opened: bool) -> bool:
	if not _interaction_required:
		return false
	_open = opened
	_hold = 0.0
	return true


func toggle_interaction() -> bool:
	return set_open(not _open)


func is_swinging() -> bool:
	for i in range(_hinges.size()):
		var hinge := _hinges[i]
		if not is_instance_valid(hinge):
			continue
		var target: float = _open_yaw[i] if _open else _shut_yaw[i]
		if absf(target - hinge.rotation_degrees.y) >= SETTLED_DEG:
			return true
	return false
