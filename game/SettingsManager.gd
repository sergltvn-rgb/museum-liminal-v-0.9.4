extends Node
## Persistent audio, display, controls and accessibility settings.

signal settings_changed

const PATH := "user://museum_settings.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
## Масштаб 3D-буфера. Картинка рендерится в долю от окна и растягивается
## обратно — это и есть пиксельный курс (блок 9), вместе с nearest-фильтром
## в MaterialLib. Раньше значение стояло намертво в project.godot
## (rendering/scaling_3d/scale=0.75) и игрок не мог его тронуть: слабой машине
## некуда было опуститься, сильной — некуда подняться.
##
## 1.0 оставлен намеренно: при нём пиксельность даёт только nearest-фильтр
## текстур, и это единственный режим, в котором читаются мелкие надписи на
## табличках экспонатов.
const RENDER_SCALES := [0.5, 0.6, 0.75, 1.0]
## Художественный дефолт шага B: 0.60 сохраняет UI в полном разрешении, но
## уменьшает число 3D-сэмплов на 36% относительно прежних 0.75. Один индекс
## используется и при первом запуске, и в Reset, и как fallback старого cfg.
const DEFAULT_RENDER_SCALE_INDEX := 1
## Contrast the accessibility toggle guarantees when it is ON. Applied as a
## floor over the map's own grade, never as a replacement for it.
const HIGH_CONTRAST_CONTRAST := 1.18

var master_volume := 0.82
var mouse_sensitivity := 0.0025
var fullscreen := false
var vsync := true
var quality_preset := 2 # 0 low, 1 medium, 2 high
var resolution_index := 1
var render_scale_index := DEFAULT_RENDER_SCALE_INDEX
var reduced_flashes := false
var large_text := false
var high_contrast := false
var language := "ru"

# WHY SUBTITLES AND REDUCED-MOTION ARE NOT HERE (stage 5.1)
#
# Both used to live in this file and in the accessibility tab, and both were
# write-only: `subtitles` and `reduced_motion` were stored, persisted, restored
# by reset_defaults() -- and read by nobody, in this file or any other. An
# accessibility toggle that changes nothing is worse than a missing one, because
# a player who needs it flips it, believes they are covered, and plays on.
#
# The other four are honest and stay: reduced_flashes has four readers
# (FirstMuseumMap's alarm pulse, GameplayEnhancements, SecurityCameraTablet's
# static, CRTOverlay), large_text drives content_scale_factor, high_contrast
# drives the colour grade below, language drives TranslationServer.
#
# Restoring either is a small change, and the catalogue rows for both survive in
# localization/game.csv (ACCESS_SUBTITLES / SET_SUBTITLES_DESC,
# ACCESS_REDUCED_MOTION / SET_REDUCED_MOTION_DESC) -- but restore the *reader*
# first and the toggle second, in that order, or this comment gets to be written
# again. `subtitles` needs a caption surface fed by the dialogue and stinger
# sources; `reduced_motion` needs the camera shake and screen transitions to
# consult it. Neither reader is in this file's reach.

# Colour grade authored by FirstMuseumMap (_add_world_env, later modified by
# _trigger_blackout), captured the first time we touch the environment. High
# contrast is an override on top of it, so turning the toggle OFF restores
# these values instead of switching the whole adjustment stage off.
var _grade_cached := false
var _base_adjustment_enabled := true
var _base_adjustment_contrast := 1.0


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


func set_render_scale_index(value: int) -> void:
	render_scale_index = clampi(value, 0, RENDER_SCALES.size() - 1)
	_apply_render_scale()
	_commit()


func set_reduced_flashes(value: bool) -> void:
	reduced_flashes = value
	_commit()


func set_large_text(value: bool) -> void:
	large_text = value
	_apply_ui_scale()
	_commit()


func set_high_contrast(value: bool) -> void:
	high_contrast = value
	_apply_contrast()
	_commit()


func set_language(value: String) -> void:
	language = "en" if value == "en" else "ru"
	TranslationServer.set_locale(language)
	get_tree().root.propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)
	_commit()


func reset_defaults() -> void:
	master_volume = 0.82
	mouse_sensitivity = 0.0025
	fullscreen = false
	vsync = true
	quality_preset = 2
	resolution_index = 1
	render_scale_index = DEFAULT_RENDER_SCALE_INDEX
	reduced_flashes = false
	large_text = false
	high_contrast = false
	language = "ru"
	TranslationServer.set_locale(language)
	_apply_all()
	_commit()


func allow_volumetric_fog() -> bool:
	return quality_preset >= 2


func _commit() -> void:
	_save_settings()
	settings_changed.emit()


func _apply_all() -> void:
	TranslationServer.set_locale(language)
	_apply_volume()
	_apply_sensitivity()
	_apply_window()
	_apply_render_scale()
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


## Масштаб 3D-буфера применяется к корневому окну: 3D рендерится в долю
## разрешения и растягивается обратно, интерфейс остаётся в полном (за это
## отвечает stretch/mode=canvas_items в project.godot, не трогать).
##
## Режим билинейный, а не FSR: FSR на масштабах ниже 0.6 начинает домысливать
## края и съедает ровно ту пиксельную сетку, ради которой всё затевалось.
func _apply_render_scale() -> void:
	if not is_inside_tree():
		return
	var root := get_tree().root
	if root == null:
		return
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = float(RENDER_SCALES[render_scale_index])


func _apply_quality() -> void:
	var museum := get_tree().get_first_node_in_group("museum_map")
	if museum == null:
		return
	var env: Variant = museum.get("_environment")
	if env is Environment:
		# Screen-space effects are art-direction exclusions, not quality upgrades.
		# Re-enabling any of them here would undo FirstMuseumMap._add_world_env()
		# every time settings load, reset, or change.
		env.ssao_enabled = false
		env.ssr_enabled = false
		env.ssil_enabled = false
		env.glow_enabled = quality_preset >= 1
		# Профиль тумана принадлежит карте: у неё их три (день, заезд, ночь)
		# и только она знает, какой из них сейчас верен. Раньше здесь стояло
		# жёсткое "объёмный туман только ночью", и любое применение настроек
		# во время заезда мгновенно гасило его туман.
		if museum.has_method("_apply_fog_profile"):
			museum.call("_apply_fog_profile")
		else:
			var is_night := bool(museum.get("_blackout_done"))
			env.volumetric_fog_enabled = quality_preset >= 2 and is_night


func _apply_ui_scale() -> void:
	get_tree().root.content_scale_factor = 1.12 if large_text else 1.0
	_apply_contrast()


## High contrast is an override on top of the map's colour grade, never a
## replacement for it. OFF restores exactly what FirstMuseumMap authored --
## including the night-time desaturation applied by _trigger_blackout, which
## used to be silently switched off with the whole adjustment stage. ON only
## raises the contrast, leaving saturation and brightness to the art direction.
func _apply_contrast() -> void:
	var museum := get_tree().get_first_node_in_group("museum_map")
	if museum == null:
		return
	var env: Variant = museum.get("_environment")
	if not (env is Environment):
		return
	if not _grade_cached:
		_base_adjustment_enabled = env.adjustment_enabled
		_base_adjustment_contrast = env.adjustment_contrast
		_grade_cached = true
	if high_contrast:
		env.adjustment_enabled = true
		env.adjustment_contrast = maxf(_base_adjustment_contrast, HIGH_CONTRAST_CONTRAST)
	else:
		env.adjustment_enabled = _base_adjustment_enabled
		env.adjustment_contrast = _base_adjustment_contrast


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
	render_scale_index = clampi(int(config.get_value("display", "render_scale", DEFAULT_RENDER_SCALE_INDEX)), 0, RENDER_SCALES.size() - 1)
	reduced_flashes = bool(config.get_value("accessibility", "reduced_flashes", false))
	large_text = bool(config.get_value("accessibility", "large_text", false))
	high_contrast = bool(config.get_value("accessibility", "high_contrast", false))
	language = str(config.get_value("localization", "language", "ru"))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	config.set_value("display", "quality", quality_preset)
	config.set_value("display", "resolution", resolution_index)
	config.set_value("display", "render_scale", render_scale_index)
	config.set_value("accessibility", "reduced_flashes", reduced_flashes)
	config.set_value("accessibility", "large_text", large_text)
	config.set_value("accessibility", "high_contrast", high_contrast)
	config.set_value("localization", "language", language)
	config.save(PATH)
