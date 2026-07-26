extends SceneTree
## Headless scenario test for tutorial -> shift -> every rift -> fail/retry -> win.

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var tutorial := load("res://scenes/TutorialPrologue.tscn") as PackedScene
	_check(tutorial != null, "tutorial scene loads")
	var main := load("res://scenes/FirstMuseumMap.tscn") as PackedScene
	_check(main != null, "museum scene loads")
	if main == null:
		_finish(); return
	var scene := main.instantiate()
	root.add_child(scene)
	# The engine assigns current_scene when it boots run/main_scene; adding the
	# scene by hand does not. RiftTrialManager._build_world() parents each pocket
	# dimension under current_scene, so without this every trial builder aborted
	# on a null and the "<kind> starts" checks were passing against a world that
	# had never been built.
	current_scene = scene
	for i in range(5): await process_frame
	var game := scene.get_node_or_null("GameManager")
	var player := get_first_node_in_group("player")
	_check(game != null, "game manager ready")
	_check(player != null, "player ready")
	if game == null or player == null:
		_finish(); return
	var manager_script := load("res://game/RiftTrialManager.gd") as Script
	var registry_script := load("res://game/trials/RiftTrialRegistry.gd") as Script
	_check(manager_script != null, "trial dispatcher parses")
	_check(registry_script != null, "trial registry parses")
	if manager_script != null:
		var manager: Node = manager_script.new()
		scene.add_child(manager)
		manager.call("setup", game)
		for kind in ["gravity_surge", "temporal_drift", "radiation_bloom", "void_rift", "echo_chamber", "glass_bridge", "mirror_maze", "yellow_halls", "scrap_run", "ascent"]:
			manager.call("begin", kind, player)
			# begin() deliberately waits for the portal fade before teleporting.
			await create_timer(1.0).timeout
			_check(bool(manager.call("is_active")), "%s starts" % kind)
			manager.call("abort")
			await process_frame
			_check(not bool(manager.call("is_active")), "%s abort restores cycle" % kind)
		manager.queue_free()
	_check(game.has_method("_fail"), "failure path exists")
	_check(game.has_method("_retry"), "retry path exists")
	_check(game.has_method("_win"), "win path exists")
	_finish()

func _check(condition: bool, label: String) -> void:
	if condition: print("[PASS] ", label)
	else:
		failures.append(label)
		push_error("[FAIL] %s" % label)

func _finish() -> void:
	print("Full game cycle: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
