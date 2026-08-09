extends Node3D
## A pair of hinged door leaves that open when somebody walks up to them.
##
## Node layout, built by FirstMuseumMap._door_leaves():
##
##   Door Swing <centre>        this node, on the seam between two rooms
##     Door Hinge <centre> 0    RigidBody3D standing on the pivot line
##       lp_door_leaf           the leaf model, running along local +X
##       Door Leaf Collider     BoxShape3D wrapping that leaf
##     Door Hinge <centre> 1    the other leaf, mirrored
##     Door Sensor              Area3D covering both approaches
##
## WHY THE HINGES ARE RigidBody3D AND NOT StaticBody3D OR AnimatableBody3D
##
## The Curator's navigation mesh is baked from PARSED_GEOMETRY_STATIC_COLLIDERS
## over the museum_nav_source group, which is the map root and everything under
## it (FirstMuseumMap._add_navigation). AnimatableBody3D extends StaticBody3D,
## so a shut leaf would bake as a wall across its own doorway and strand the
## Curator on one side of it -- and a rebake can happen at any time while the
## game is running (_bake_navigation is called again whenever the map changes).
## A frozen kinematic RigidBody3D still stops the player and still pushes
## bodies out of the way as it swings, but Recast never sees it, so a doorway
## stays walkable in the navmesh no matter which way its leaves are standing.
##
## The leaves are BUILT OPEN, at the same angles the frozen-ajar primitives
## stood at before them, because build_map() bakes navigation immediately and
## every doorway audit measures the map in the state it was built in. They hold
## that pose for SETTLE_HOLD seconds and then swing shut on their own.

## Degrees per second at full speed. A 100 degree swing takes about 0.7 s,
## which is a door being pushed open by someone walking, not a shop shutter.
const SWING_SPEED := 150.0
## The last few degrees are taken slowly: a leaf that runs at full speed into
## its end pose stops dead and reads as a teleport rather than a swing.
const EASE_ARC := 22.0
const EASE_FLOOR := 0.18
## How long the leaves stay open after the last body leaves the sensor.
const OPEN_HOLD := 2.2
## How long they stay open after the map is built: long enough for the first
## navigation bake and for any audit that walks the freshly built map.
const SETTLE_HOLD := 5.0
## Sensor volume. Deliberately square in plan so the same box serves a doorway
## on either axis, and only 2.4 m tall so it cannot catch anything upstairs.
const SENSOR_SIZE := Vector3(3.4, 2.4, 3.4)
## Below this the leaf is treated as parked, which is what stops two dozen
## doors writing a transform every physics frame for the rest of the game.
const SETTLED_DEG := 0.05

var _hinges: Array[Node3D] = []
var _open_yaw: PackedFloat32Array = PackedFloat32Array()
var _shut_yaw: PackedFloat32Array = PackedFloat32Array()
var _inside := 0
var _hold := SETTLE_HOLD
var _open := true


func _ready() -> void:
	# setup() is what wires this node up; until it runs there is nothing to
	# swing. Guarding here keeps the script harmless if it is ever attached to
	# a node by hand.
	set_physics_process(not _hinges.is_empty())


## `hinges` are the pivot bodies, `open_yaw` and `shut_yaw` their Y rotations
## in degrees, in the same order. Both angle lists are absolute, not offsets:
## a leaf's shut pose is its own place in the wall, and the two leaves of one
## doorway do not share a heading.
func setup(hinges: Array, open_yaw: Array, shut_yaw: Array) -> void:
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
	_add_sensor()
	set_physics_process(not _hinges.is_empty())


func _add_sensor() -> void:
	if has_node("Door Sensor"):
		return
	var area := Area3D.new()
	area.name = "Door Sensor"
	# It listens, nothing queries it: an area that is not monitorable is half
	# the physics server work of one that is.
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


# Only walking things open a door. Everything else that can enter the volume
# is scenery, and scenery must not hold a doorway open for the whole game.
func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D:
		_inside += 1


func _on_body_exited(body: Node) -> void:
	if body is CharacterBody3D:
		_inside = maxi(0, _inside - 1)


func _physics_process(delta: float) -> void:
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


## True while any leaf is still moving. Nothing calls this yet; it is here
## because the first thing a sound cue or a scripted scare will need to know
## is whether the door is still on its way.
func is_swinging() -> bool:
	for i in range(_hinges.size()):
		var hinge := _hinges[i]
		if not is_instance_valid(hinge):
			continue
		var target: float = _open_yaw[i] if _open else _shut_yaw[i]
		if absf(target - hinge.rotation_degrees.y) >= SETTLED_DEG:
			return true
	return false
