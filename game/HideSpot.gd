extends StaticBody3D
class_name HideSpot

## A place the player can be inside of, and the Curator can open.
##
## Audit 16.6 п. 5. Until now the only answer to being hunted was distance: the
## Curator walks 4.9 m/s at night 1 and the player runs 7.5 m/s, so every
## encounter resolved into a footrace down a corridor. A hide spot is the other
## answer -- stop moving and stop being visible -- and it is only interesting if
## it can be searched, so this node owns both halves:
##
##   * closed, it physically blocks the sight ray (the door gets a collider, not
##     just a mesh, because CuratorMonster._can_see_player() asks the physics
##     server and would happily see straight through a decorative panel);
##   * `check()` is the Curator's hand on the handle -- it opens the door and
##     reports what was inside.
##
## Interior is 1.08 x 2.00 x 0.88 m of clear space. The player capsule is 0.70 m
## across and 1.80 m tall, so it fits standing with 0.18 m of slack around it and
## 0.20 m over its head; test_map_verification measures this rather than trusting
## the numbers in this comment.

## Clear space inside the shell, before the walls are added.
const INTERIOR := Vector3(1.08, 2.0, 0.88)
## Wall thickness. Also the depth of the door.
const WALL := 0.06
## How close the player must be to climb in.
const USE_DISTANCE := 2.0
## How long the door stays open after the Curator has looked inside, so the
## player watching from across the room can see which spot has been searched.
const OPEN_HOLD := 6.0

## True while the player is inside. The Curator never reads the player's position
## to decide this -- it reads the spot.
var occupied := false
## Seconds left of the post-search hold before the door swings shut again.
var _open_left := 0.0

var _door: MeshInstance3D
var _door_body: StaticBody3D
var _label: Label3D


## Build a locker at `origin` (floor level) facing `facing_deg` about Y, and
## return it. The caller owns placement; this node owns everything inside it.
static func build(parent: Node3D, spot_name: String, origin: Vector3,
		facing_deg: float, sign_text: String) -> HideSpot:
	var spot := HideSpot.new()
	spot.name = spot_name
	spot.position = origin
	spot.rotation_degrees = Vector3(0.0, facing_deg, 0.0)
	spot.add_to_group("hide_spot")
	spot.add_to_group("interactable")
	parent.add_child(spot)
	spot._assemble(sign_text)
	return spot


func _assemble(sign_text: String) -> void:
	var half := INTERIOR * 0.5
	var shell := Color(0.085, 0.105, 0.10)
	# Back, two sides, roof and floor pan. The front is the door, built last.
	_panel("Back Panel", Vector3(0.0, half.y, half.z + WALL * 0.5),
		Vector3(INTERIOR.x + WALL * 2.0, INTERIOR.y, WALL), shell)
	_panel("Left Panel", Vector3(-half.x - WALL * 0.5, half.y, 0.0),
		Vector3(WALL, INTERIOR.y, INTERIOR.z + WALL * 2.0), shell)
	_panel("Right Panel", Vector3(half.x + WALL * 0.5, half.y, 0.0),
		Vector3(WALL, INTERIOR.y, INTERIOR.z + WALL * 2.0), shell)
	_panel("Roof Panel", Vector3(0.0, INTERIOR.y + WALL * 0.5, 0.0),
		Vector3(INTERIOR.x + WALL * 2.0, WALL, INTERIOR.z + WALL * 2.0), shell)
	# The door. Collider and mesh move together: an open locker must be lookable
	# into, and a closed one must stop the ray.
	_door_body = StaticBody3D.new()
	_door_body.name = "Door"
	_door_body.position = Vector3(0.0, half.y, -half.z - WALL * 0.5)
	add_child(_door_body)
	var door_shape := CollisionShape3D.new()
	var door_box := BoxShape3D.new()
	door_box.size = Vector3(INTERIOR.x + WALL * 2.0, INTERIOR.y, WALL)
	door_shape.shape = door_box
	_door_body.add_child(door_shape)
	_door = MeshInstance3D.new()
	_door.name = "Door Face"
	var door_mesh := BoxMesh.new()
	door_mesh.size = door_box.size
	_door.mesh = door_mesh
	_door.material_override = _material(Color(0.10, 0.125, 0.12))
	_door_body.add_child(_door)
	# This node's own collider is a handle, not a second front panel. A full face
	# here would block the sightline into an OPEN locker as well as a shut one,
	# which would quietly turn every open door into cover. 0.12 x 0.20 x 0.04 m,
	# off to the latch side at x 0.44, so a ray aimed at the middle of the
	# interior misses it and only the door decides what can be seen.
	var body_shape := CollisionShape3D.new()
	var body_box := BoxShape3D.new()
	body_box.size = Vector3(0.12, 0.20, 0.04)
	body_shape.shape = body_box
	body_shape.position = Vector3(half.x - 0.10, 1.05, -half.z - WALL * 1.5)
	add_child(body_shape)
	_label = Label3D.new()
	_label.name = "Locker Sign"
	_label.text = sign_text
	_label.font_size = 28
	_label.pixel_size = 0.0035
	_label.modulate = Color(0.62, 0.78, 0.72)
	_label.position = Vector3(0.0, INTERIOR.y - 0.18, -half.z - WALL * 2.0)
	_label.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	add_child(_label)
	set_closed(true)


func _panel(panel_name: String, at: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = panel_name
	body.position = at
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.name = "%s Face" % panel_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = _material(color)
	body.add_child(mesh)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	mat.metallic = 0.35
	return mat


## Where the player stands while hidden: the middle of the interior, on the floor.
func hide_point() -> Vector3:
	return to_global(Vector3.ZERO)


## Where someone opening this locker stands: one metre out in front of the door.
func approach_point() -> Vector3:
	return to_global(Vector3(0.0, 0.0, -(INTERIOR.z * 0.5 + 1.0)))


func set_closed(closed: bool) -> void:
	if _door_body == null:
		return
	var changed := is_closed() != closed
	_door_body.visible = closed
	_door_body.process_mode = Node.PROCESS_MODE_INHERIT
	# collision_layer 0 is how a StaticBody3D stops existing for rays without
	# being removed from the tree and rebuilt every time a door swings.
	_door_body.collision_layer = 1 if closed else 0
	if not changed:
		return
	# The hinge creaks: a recorded piece of hinge_creaks (1.4 s, -26.0 dBFS RMS
	# / -11.9 peak). Full level when the Curator swings the door, so it reads
	# across the room; quieter and pitched down when the player pulls it shut.
	var am := get_tree().get_first_node_in_group("audio_manager")
	if am != null and am.has_method("play_at"):
		var at := global_position + Vector3(0.0, 1.2, 0.0)
		if closed:
			am.play_at("locker_creak", at, -8.0, 0.8)
		else:
			am.play_at("locker_creak", at, -2.0, 1.0)


## The locker for a body the interaction ray hit, or null. The ray lands on the
## door or a panel far more often than on the handle, and every one of those is
## a child of the locker itself.
static func owner_of(body: Node) -> HideSpot:
	var node := body
	while node != null:
		if node is HideSpot:
			return node as HideSpot
		node = node.get_parent()
	return null


func is_closed() -> bool:
	return _door_body != null and _door_body.collision_layer != 0


## The Curator's hand on the handle. Opens the door, holds it open long enough to
## be seen from across the room, and reports whether anyone was in there.
func check() -> bool:
	_open_left = OPEN_HOLD
	set_closed(false)
	return occupied


## The player climbs in, or climbs back out. Returns the point they should be
## standing at.
##
## Reported live: after one round trip the locker stayed wide open for good. The
## old body was `set_closed(hidden)`, which is right on the way in and wrong on
## the way out -- a door the player pulled shut behind them has no reason to hang
## open once they leave. Leaving now shuts it, with one exception: while
## `_open_left > 0` the Curator's `check()` is holding the door, and that hold is
## the only way a player across the room can read which locker was searched.
func take(hidden: bool) -> Vector3:
	occupied = hidden
	if hidden:
		_open_left = 0.0
		set_closed(true)
	elif _open_left <= 0.0:
		set_closed(true)
	return hide_point()


func _process(delta: float) -> void:
	if _open_left <= 0.0:
		return
	_open_left -= delta
	if _open_left <= 0.0 and not occupied:
		set_closed(true)
