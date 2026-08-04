extends SceneTree
## Headless integration smoke test. Run with:
## godot --headless --path . --script res://game/test_project_integration.gd

var failures: Array[String] = []

const TEXTURE_IMPORT_CAP := 512
const CAPPED_MODEL_TEXTURE_PREFIXES := [
	"dumpsters_glb",
	"elderly_woman_bust_on_pedestal",
	"fancy_marble_coffee_table",
	"gallery_bare_concrete_wall",
	"tactical_flashlight",
	"vents",
	"wooden_bookcases_with_books",
	"арка дверь",
	"наблюдатель",
	"отсановка",
	"уличная лампа",
	"часы",
]
const FLAT_ALBEDO_TEXTURES := [
	"res://textures/CityStreetAsphaltGenericClean001/CityStreetAsphaltGenericClean001_COL_2K.jpg",
	"res://textures/DirtWindowStains005/DirtWindowStains005_COL_2K.jpg",
	"res://textures/GroundDirtRocky020/GroundDirtRocky020_COL_2K.jpg",
	"res://textures/MetalCorrodedHeavy001/MetalCorrodedHeavy001_COL_2K_METALNESS.jpg",
	"res://textures/Poliigon_ConcreteWorn_8690/Poliigon_ConcreteWorn_8690_BaseColor.jpg",
	"res://textures/Poliigon_MetalPaintedMatte_7037/Poliigon_MetalPaintedMatte_7037_BaseColor.jpg",
	"res://textures/Poliigon_MetalRust_7642/Poliigon_MetalRust_7642_BaseColor.jpg",
	"res://textures/Poliigon_MetalSteelBrushed_7174/Poliigon_MetalSteelBrushed_7174_BaseColor.jpg",
	"res://textures/Poliigon_PlasticMoldDryBlast_7495/Poliigon_PlasticMoldDryBlast_7495_BaseColor.jpg",
	"res://textures/Poliigon_PlasticMoldWorn_7486/Poliigon_PlasticMoldWorn_7486_BaseColor.jpg",
	"res://textures/Poliigon_StoneQuartzite_8060/Poliigon_StoneQuartzite_8060_BaseColor.jpg",
	"res://textures/TilesMosaicYubi003/TilesMosaicYubi003_COL_2K.png",
	"res://textures/TilesTravertine001/TilesTravertine001_COL_2K.jpg",
	"res://textures/WoodProcedural/WoodOak_COL.jpg",
]
const NEAR_FIELD_TEXTURE_PREFIX := "basic_pc_monitors"
const EXPORT_HYGIENE_PATTERNS := [
	"models/broken_clock*",
	"models/camera*",
	"models/falling_cube*",
	"models/frozen_drop*",
	"models/modern_grey_stone_tile_texture*",
	"models/office_chair*",
	"models/portal_arch*",
	"models/superheavy_sphere*",
	"models/тумбочка*",
	"textures/*/*_AO_2K.*",
	"textures/*/*_NRM_2K.*",
	"textures/*/*_ROUGH_2K.*",
	"textures/*/*_GLOSS_2K.*",
	"textures/*/*_REFL_2K.*",
	"textures/*/*_DISP_2K*",
	"textures/*/*_DISP16_2K.*",
	"textures/*/*_BUMP*",
	"textures/*/*_IDMAP_2K.*",
	"textures/*/*_ALPHAMASKED_2K.*",
	"textures/*/*_AmbientOcclusion.*",
	"textures/*/*_Metallic.*",
	"textures/*/*_Normal.*",
	"textures/*/*_Roughness.*",
	"textures/*/*_METALNESS_2K_METALNESS.*",
	"textures/*/*_NRM_2K_METALNESS.*",
	"textures/*/*_ROUGHNESS_2K_METALNESS.*",
	"textures/WoodProcedural/WoodOak_NRM.*",
	"textures/WoodProcedural/WoodOak_ROUGH.*",
]


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
	var settings_script := load("res://game/SettingsManager.gd") as GDScript
	var fresh_settings := settings_script.new() as Node if settings_script != null else null
	_check(fresh_settings != null and int(fresh_settings.get("render_scale_index")) == 1,
		"fresh settings default to 60 percent render scale")
	if fresh_settings != null:
		fresh_settings.free()
	var settings := scene.get_node_or_null("SettingsManager")
	if settings != null:
		var saved_scale_index := int(settings.get("render_scale_index"))
		settings.set("render_scale_index", 1)
		settings.call("_apply_render_scale")
		_check(is_equal_approx(root.scaling_3d_scale, 0.6),
			"render scale setting applies to the root viewport")
		settings.set("render_scale_index", saved_scale_index)
		settings.call("_apply_render_scale")

		var env: Environment = scene.get("_environment") as Environment
		if env != null:
			var saved_quality_preset := int(settings.get("quality_preset"))
			settings.set("quality_preset", 2)
			settings.call("_apply_quality")
			_check(not env.ssao_enabled, "high quality keeps SSAO disabled")
			_check(not env.ssr_enabled and not env.ssil_enabled,
				"high quality keeps SSR and SSIL disabled")
			settings.set("quality_preset", 0)
			settings.call("_apply_quality")
			_check(not env.ssao_enabled, "low quality disables SSAO")
			_check(not env.ssr_enabled and not env.ssil_enabled,
				"low quality keeps SSR and SSIL disabled")
			settings.set("quality_preset", saved_quality_preset)
			settings.call("_apply_quality")
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
	_check_texture_policy()
	_finish()


func _check_texture_policy() -> void:
	var capped_paths: Array[String] = []
	var near_field_paths: Array[String] = []
	for file_name: String in DirAccess.get_files_at("res://models"):
		if not _is_texture_source(file_name):
			continue
		if file_name.begins_with("%s_" % NEAR_FIELD_TEXTURE_PREFIX):
			near_field_paths.append("res://models/%s" % file_name)
		for prefix: String in CAPPED_MODEL_TEXTURE_PREFIXES:
			if file_name.begins_with("%s_" % prefix):
				capped_paths.append("res://models/%s" % file_name)
				break
	for path: String in FLAT_ALBEDO_TEXTURES:
		capped_paths.append(path)
	capped_paths.sort()
	near_field_paths.sort()
	_check(capped_paths.size() == 71,
		"texture policy enumerates 71 capped production images")
	_check(near_field_paths.size() == 7,
		"texture policy retains seven near-field monitor exceptions")

	var cap_mismatches: Array[String] = []
	for path: String in capped_paths:
		var size_limit := _texture_size_limit(path)
		if size_limit != TEXTURE_IMPORT_CAP:
			cap_mismatches.append("%s=%d" % [path, size_limit])
	if not cap_mismatches.is_empty():
		print("[TEXTURE POLICY] cap mismatches: ", cap_mismatches)
	_check(cap_mismatches.is_empty(),
		"used model and flat albedo textures are capped at 512")

	var runtime_dimension_mismatches: Array[String] = []
	for path: String in capped_paths:
		var texture := load(path) as Texture2D
		if texture == null:
			runtime_dimension_mismatches.append("%s=unloaded" % path)
			continue
		var imported_size := Vector2i(texture.get_width(), texture.get_height())
		if maxi(imported_size.x, imported_size.y) > TEXTURE_IMPORT_CAP:
			runtime_dimension_mismatches.append("%s=%dx%d" % [
				path, imported_size.x, imported_size.y])
	if not runtime_dimension_mismatches.is_empty():
		print("[TEXTURE POLICY] runtime dimension mismatches: ",
			runtime_dimension_mismatches)
	_check(runtime_dimension_mismatches.is_empty(),
		"capped production textures load at no more than 512 pixels")

	var near_field_mismatches: Array[String] = []
	for path: String in near_field_paths:
		var size_limit := _texture_size_limit(path)
		if size_limit != 0:
			near_field_mismatches.append("%s=%d" % [path, size_limit])
	_check(near_field_mismatches.is_empty(),
		"near-field monitor textures remain uncapped pending their own A/B")

	var export_config := ConfigFile.new()
	var export_error := export_config.load("res://export_presets.cfg")
	_check(export_error == OK, "export presets load for texture-policy checks")
	if export_error == OK:
		for section: String in ["preset.0", "preset.1", "preset.2"]:
			var raw_patterns := String(export_config.get_value(section, "exclude_filter", ""))
			var present_patterns: Dictionary = {}
			for pattern: String in raw_patterns.split(",", false):
				present_patterns[pattern.strip_edges()] = true
			var missing_patterns: Array[String] = []
			for pattern: String in EXPORT_HYGIENE_PATTERNS:
				if not present_patterns.has(pattern):
					missing_patterns.append(pattern)
			if not missing_patterns.is_empty():
				print("[TEXTURE POLICY] %s missing export excludes: " % section,
					missing_patterns)
			_check(missing_patterns.is_empty(),
				"%s carries texture export hygiene" % section)
			_check(not present_patterns.has("addons/godot_ai/*"),
				"%s keeps the required godot_ai runtime autoload exportable" % section)


func _texture_size_limit(texture_path: String) -> int:
	var import_config := ConfigFile.new()
	if import_config.load("%s.import" % texture_path) != OK:
		return -1
	return int(import_config.get_value("params", "process/size_limit", -1))


func _is_texture_source(file_name: String) -> bool:
	return file_name.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] ", label)
	else:
		failures.append(label)
		push_error("[FAIL] %s" % label)


func _finish() -> void:
	print("Integration smoke test: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
