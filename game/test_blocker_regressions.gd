extends SceneTree
## Regression guard for the two traversal blockers found in the 2026-07 audit.
##
## Both were invisible to every other suite, because the rest of the tests only
## count nodes: a doorway plugged by a collider still has all its meshes, and a
## bottomless map still spawns a player. These two checks look at the physics
## world instead of the scene tree.
##
##   1. The Atrium -> Time Wing B doorway must admit a player-sized capsule.
##      MapModels gave the "арка дверь" model a convex hull, and the hull of an
##      arch fills the arch's own opening (2.18 m across a 1.80 m gap), sealing
##      off the Planetarium, Space Wing C and everything past them.
##   2. A player below GameManager.KILL_PLANE_Y must be put back on solid ground,
##      and the forecourt must be fenced. The map starts outdoors on an open lot
##      whose floor simply ended, so walking off the edge fell forever with no
##      respawn and no way out but killing the process.

## Player capsule, from PlayerController's collision shape.
const PLAYER_RADIUS := 0.35
const PLAYER_HEIGHT := 1.8
## Doorway centre is Vector3(0, 0, -15); sample either side of the arch at -15.5.
const DOORWAY_SAMPLES: Array[float] = [-13.5, -14.5, -15.0, -15.5, -16.5]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/FirstMuseumMap.tscn") as PackedScene
	if packed == null:
		_fail("FirstMuseumMap.tscn did not load")
		_finish()
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	# The engine assigns current_scene when it boots run/main_scene; adding the
	# scene by hand does not, and parts of the game parent nodes under it.
	current_scene = scene
	for i in range(8):
		await process_frame
	await physics_frame

	_verify_doorway()
	await _verify_kill_plane(scene)
	_finish()


## Blocker 0.2 — sweep the player capsule through the doorway.
func _verify_doorway() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = PLAYER_RADIUS
	shape.height = PLAYER_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collide_with_areas = false

	var blocked := 0
	for z in DOORWAY_SAMPLES:
		query.transform = Transform3D(Basis(), Vector3(0.0, PLAYER_HEIGHT * 0.5, z))
		var hits := root.world_3d.direct_space_state.intersect_shape(query, 16)
		if hits.is_empty():
			continue
		blocked += 1
		for hit in hits:
			var node := hit["collider"] as Node
			print("  z=%.1f blocked by %s" % [z, node.get_path() if node != null else "<freed>"])
	if blocked > 0:
		_fail("Atrium -> Time Wing B doorway is obstructed at %d of %d sample points"
			% [blocked, DOORWAY_SAMPLES.size()])
	else:
		_ok("Atrium -> Time Wing B doorway admits the player capsule")


## Blocker 0.4 — the kill plane recovers a fallen player, and the lot is fenced.
func _verify_kill_plane(scene: Node) -> void:
	var player := get_first_node_in_group("player") as Node3D
	var manager := scene.get_node_or_null("GameManager")
	if player == null or manager == null:
		_fail("kill plane: player or GameManager missing")
		return
	var threshold := float(manager.get_script().get_script_constant_map()
		.get("KILL_PLANE_Y", -8.0))

	# MenuManager._ready() opens the main menu, which pauses the tree. The kill
	# plane lives in GameManager._process, so it cannot run until a shift starts.
	paused = false
	for i in range(2):
		await process_frame

	player.global_position = Vector3(0.0, threshold - 12.0, 46.0)
	for i in range(30):
		await process_frame
	if player.global_position.y <= threshold:
		_fail("player left below the kill plane at y=%.2f" % player.global_position.y)
	else:
		_ok("kill plane recovered the player to y=%.2f" % player.global_position.y)

	# North-west forecourt shoulder: floor used to end here with no barrier.
	var ray := PhysicsRayQueryParameters3D.create(
		Vector3(-21.5, 0.6, 30.0), Vector3(-21.5, 0.6, 40.0))
	var hit := root.world_3d.direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		_fail("no barrier across the north-west forecourt shoulder")
	else:
		_ok("forecourt shoulder fenced by %s" % (hit["collider"] as Node).name)


func _ok(text: String) -> void:
	print("[PASS] ", text)


func _fail(text: String) -> void:
	_failures.append(text)
	push_error("[FAIL] %s" % text)
	print("[FAIL] ", text)


func _finish() -> void:
	print("Blocker regressions: %d failure(s)" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
