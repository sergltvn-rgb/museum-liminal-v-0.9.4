extends SceneTree
## Headless integration smoke test. Run with:
## godot --headless --path . --script res://game/test_project_integration.gd

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/FirstMuseumMap.tscn") as PackedScene
	_check(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	_check(scene.name == "FirstMuseumMap", "FirstMuseumMap root is connected")
	for node_name in ["InputBootstrap", "AudioManager",
			"SecurityCameraTablet", "GameManager", "GameplayEnhancements",
			"ExhibitPuzzleController", "SettingsManager", "MenuManager"]:
		_check(scene.get_node_or_null(node_name) != null, "%s is connected" % node_name)
	_check(get_first_node_in_group("player") != null, "player generated")
	_check(get_first_node_in_group("audio_manager") != null, "audio manager ready")
	_check(get_first_node_in_group("gameplay_enhancements") != null, "enhancements ready")
	_check(get_first_node_in_group("exhibit_puzzle_controller") != null, "puzzle controller ready")
	_check(get_first_node_in_group("player_scale_controller") != null, "player scale controller ready")
	_check(InputMap.has_action("interact"), "input actions registered")
	_check(InputMap.has_action("flashlight"), "flashlight input registered")
	var player: Node = get_first_node_in_group("player")
	if player != null:
		_check(player.get("max_stamina") != null, "player stamina available")
	var theme := load("res://ui/museum_theme.tres") as Theme
	_check(theme != null, "shared museum theme loads")
	if theme != null:
		for variation: StringName in [&"TerminalPanel", &"CCTVPanel", &"WarningPanel",
				&"InstrumentPanel"]:
			_check(theme.get_type_variation_base(variation) == &"Panel",
				"%s inherits Panel" % variation)
			_check(theme.has_stylebox(&"panel", variation),
				"%s supplies its panel style" % variation)
	var tablet: Node = scene.get_node_or_null("SecurityCameraTablet")
	if tablet != null:
		var cameras: Array = tablet.get("_cams")
		_check(cameras.size() == 11, "eleven CCTV feeds available")
		var frame: Node = tablet.get("_frame")
		var backdrop := frame.get_node_or_null("Backdrop") as Control if frame != null else null
		_check(backdrop != null and backdrop.theme_type_variation == &"CCTVPanel",
			"CCTV workstation selects CCTVPanel")
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] ", label)
	else:
		failures.append(label)
		push_error("[FAIL] %s" % label)


func _finish() -> void:
	print("Integration smoke test: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
