extends SceneTree
## Deterministic regression for the public museum entrance.
## Run: Godot --path . --headless --script res://game/tools/check_museum_entrance.gd

const SCENE_PATH := "res://scenes/FirstMuseumMap.tscn"
const GROUP := "museum_swing_door"
const STEP := 1.0 / 60.0
const MAX_STEPS := 240


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error("[MUSEUM ENTRANCE] %s" % message)
	quit(1)


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("cannot load scene")
		return
	var map := packed.instantiate()
	root.add_child(map)
	await process_frame
	await process_frame

	var doors := get_nodes_in_group(GROUP)
	if doors.size() != 5:
		_fail("expected five manual museum swings, found %d" % doors.size())
		return
	var entrance_doors: Array[Node] = []
	for candidate in doors:
		if _has_model(candidate, "lp_museum_door_leaf"):
			entrance_doors.append(candidate)
	if entrance_doors.size() != 1:
		_fail("expected one ceremonial entrance in the swing group, found %d"
			% entrance_doors.size())
		return
	var door: Node = entrance_doors[0]
	if not bool(door.call("is_interaction_required")):
		_fail("entrance is not in manual mode")
		return
	if not bool(door.call("is_closed")):
		_fail("entrance did not start closed")
		return
	if door.get_node_or_null("Door Sensor") != null:
		_fail("manual entrance has a proximity sensor")
		return

	var has_e := false
	for event in InputMap.action_get_events("interact"):
		var key := event as InputEventKey
		if key != null and (key.keycode == KEY_E or key.physical_keycode == KEY_E):
			has_e = true
	if not has_e:
		_fail("interact action is not bound to E")
		return

	var hinges: Array[Node3D] = []
	for child in door.get_children():
		if child is Node3D and String(child.name).begins_with("Door Hinge"):
			hinges.append(child as Node3D)
	if hinges.size() != 2:
		_fail("expected two hinge bodies, found %d" % hinges.size())
		return
	for hinge in hinges:
		if not _has_model(hinge, "lp_museum_door_leaf"):
			_fail("hinge %s does not carry lp_museum_door_leaf" % hinge.name)
			return
		if hinge.position.y < 0.359 or hinge.position.y > 0.361:
			_fail("hinge %s is not seated on the 0.36 m stylobate" % hinge.name)
			return
	if absf(hinges[0].position.x + 1.20) > 0.001 			or absf(hinges[1].position.x - 1.20) > 0.001:
		_fail("hinges do not span the 2.40 m portal")
		return

	if not bool(door.call("toggle_interaction")):
		_fail("manual toggle refused open request")
		return
	var open_steps := _drive(door)
	if bool(door.call("is_closed")) or bool(door.call("is_swinging")):
		_fail("entrance failed to reach open pose")
		return
	if absf(hinges[0].rotation_degrees.y - 96.0) > 0.1 			or absf(hinges[1].rotation_degrees.y - 84.0) > 0.1:
		_fail("open yaw is not the inward 96-degree pair")
		return

	if not bool(door.call("toggle_interaction")):
		_fail("manual toggle refused close request")
		return
	var close_steps := _drive(door)
	if not bool(door.call("is_closed")) or bool(door.call("is_swinging")):
		_fail("entrance failed to return to shut pose")
		return
	if absf(hinges[0].rotation_degrees.y) > 0.1 			or absf(hinges[1].rotation_degrees.y - 180.0) > 0.1:
		_fail("shut yaw does not seal the pair")
		return

	# Integration gate: GameManager initializes after two awaited frames of its
	# own, so let that real bootstrap finish rather than injecting its _player.
	for _i in range(4):
		await process_frame
	# It must then require both reach and gaze, and stay usable during a power
	# cut because this entrance is hand-operated.
	var manager := _find_method(map, &"_museum_entrance_at_hand")
	var player := get_first_node_in_group("player") as CharacterBody3D
	var camera := player.get_node_or_null("Player Camera") as Camera3D if player != null else null
	if manager == null or player == null or camera == null:
		_fail("could not find initialized GameManager, player and player camera")
		return
	if manager.get("_player") != player:
		_fail("GameManager did not bind the runtime player")
		return
	camera.current = true
	player.set_process(false)
	player.set_physics_process(false)
	player.global_position = Vector3(0.0, 0.40, 37.20)
	camera.global_position = Vector3(0.0, 1.70, 37.20)
	camera.look_at(Vector3(0.0, 1.60, 35.0), Vector3.UP)
	if manager.call("_museum_entrance_at_hand") != door:
		_fail("near, forward-facing player cannot reach entrance")
		return
	camera.look_at(Vector3(0.0, 1.60, 40.0), Vector3.UP)
	if manager.call("_museum_entrance_at_hand") != null:
		_fail("entrance can be operated while camera faces away")
		return
	player.global_position = Vector3(0.0, 0.40, 38.10)
	camera.global_position = Vector3(0.0, 1.70, 38.10)
	camera.look_at(Vector3(0.0, 1.60, 35.0), Vector3.UP)
	if manager.call("_museum_entrance_at_hand") != null:
		_fail("entrance reach exceeds the 2.75 m interaction gate")
		return

	player.global_position = Vector3(0.0, 0.40, 37.20)
	camera.global_position = Vector3(0.0, 1.70, 37.20)
	camera.look_at(Vector3(0.0, 1.60, 35.0), Vector3.UP)
	manager.set("_power_out", true)
	if not bool(manager.call("_toggle_museum_entrance")) or bool(door.call("is_closed")):
		_fail("GameManager did not open manual entrance during power cut")
		return
	# A second E press while the leaves are moving must reverse them immediately.
	door.call("_physics_process", 0.10)
	if not bool(manager.call("_toggle_museum_entrance")) or not bool(door.call("is_closed")):
		_fail("mid-swing E press did not reverse entrance")
		return
	_drive(door)
	if bool(door.call("is_swinging")):
		_fail("reversed entrance did not settle shut")
		return

	print("[MUSEUM ENTRANCE] OK | E bound | gap 2.40 | open %.2f s | close %.2f s | gaze/reach/power gates" % [
		open_steps * STEP, close_steps * STEP])
	quit(0)


func _drive(door: Node) -> int:
	var steps := 0
	while steps < MAX_STEPS and bool(door.call("is_swinging")):
		door.call("_physics_process", STEP)
		steps += 1
	return steps


func _has_model(node: Node, wanted: String) -> bool:
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if String(current.name).begins_with(wanted):
			return true
		for child in current.get_children():
			stack.append(child)
	return false


func _find_method(node: Node, method: StringName) -> Node:
	if node.has_method(method):
		return node
	for child in node.get_children():
		var match := _find_method(child, method)
		if match != null:
			return match
	return null
