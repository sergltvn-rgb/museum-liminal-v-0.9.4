extends Node
## Persistent audio, display, controls and accessibility settings.

signal settings_changed

const PATH := "user://museum_settings.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

var master_volume := 0.82
var mouse_sensitivity := 0.0025
var fullscreen := false
var vsync := true
var quality_preset := 2 # 0 low, 1 medium, 2 high
var resolution_index := 1
var reduced_flashes := false
var large_text := false


func _ready() -> void:
	add_to_group("settings_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_apply_all.call_deferred()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_commit()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.001, 0.006)
	_apply_sensitivity()
	_commit()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_window()
	_commit()


func set_vsync(value: bool) -> void:
	vsync = value
	_apply_window()
	_commit()


func set_quality_preset(value: int) -> void:
	quality_preset = clampi(value, 0, 2)
	_apply_quality()
	_commit()


func set_resolution_index(value: int) -> void:
	resolution_index = clampi(value, 0, RESOLUTIONS.size() - 1)
	_apply_window()
	_commit()


func set_reduced_flashes(value: bool) -> void:
	reduced_flashes = value
	_commit()


func set_large_text(value: bool) -> void:
	large_text = value
	_apply_ui_scale()
	_commit()


func reset_defaults() -> void:
	master_volume = 0.82
	mouse_sensitivity = 0.0025
	fullscreen = false
	vsync = true
	quality_preset = 2
	resolution_index = 1
	reduced_flashes = false
	large_text = false
	_apply_all()
	_commit()


func allow_volumetric_fog() -> bool:
	return quality_preset >= 2


func _commit() -> void:
	_save_settings()
	settings_changed.emit()


func _apply_all() -> void:
	_apply_volume()
	_apply_sensitivity()
	_apply_window()
	_apply_quality()
	_apply_ui_scale()


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, master_volume <= 0.001)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.001)))


func _apply_sensitivity() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.set("mouse_sensitivity", mouse_sensitivity)


func _apply_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen \
		else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync \
		else DisplayServer.VSYNC_DISABLED)
	if not fullscreen:
		DisplayServer.window_set_size(RESOLUTIONS[resolution_index])
		var screen_size := DisplayServer.screen_get_size()
		var target: Vector2i = RESOLUTIONS[resolution_index]
		var centered := Vector2i(roundi(float(screen_size.x - target.x) * 0.5),
			roundi(float(screen_size.y - target.y) * 0.5))
		DisplayServer.window_set_position(centered)


func _apply_quality() -> void:
	var museum := get_tree().get_first_node_in_group("museum_map")
	if museum == null:
		return
	var env: Variant = museum.get("_environment")
	if env is Environment:
		env.ssao_enabled = quality_preset >= 1
		env.ssr_enabled = quality_preset >= 1
		env.ssil_enabled = quality_preset >= 2
		env.glow_enabled = quality_preset >= 1
		var is_night := bool(museum.get("_blackout_done"))
		env.volumetric_fog_enabled = quality_preset >= 2 and is_night


func _apply_ui_scale() -> void:
	get_tree().root.content_scale_factor = 1.12 if large_text else 1.0


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	master_volume = clampf(float(config.get_value("audio", "master_volume", 0.82)), 0.0, 1.0)
	mouse_sensitivity = clampf(float(config.get_value("controls", "mouse_sensitivity", 0.0025)), 0.001, 0.006)
	fullscreen = bool(config.get_value("display", "fullscreen", false))
	vsync = bool(config.get_value("display", "vsync", true))
	quality_preset = clampi(int(config.get_value("display", "quality", 2)), 0, 2)
	resolution_index = clampi(int(config.get_value("display", "resolution", 1)), 0, RESOLUTIONS.size() - 1)
	reduced_flashes = bool(config.get_value("accessibility", "reduced_flashes", false))
	large_text = bool(config.get_value("accessibility", "large_text", false))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	config.set_value("display", "quality", quality_preset)
	config.set_value("display", "resolution", resolution_index)
	config.set_value("accessibility", "reduced_flashes", reduced_flashes)
	config.set_value("accessibility", "large_text", large_text)
	config.save(PATH)
