extends Node
## Distinct anomaly mechanics, camera-confirmation objectives and an active
## "Watcher" threat. Kept separate from GameManager so the core night loop
## remains easy to test and maintain.

const STATE_ANOMALY := 2
const SCAN_TIME := 2.5
const EFFECT_RADIUS := 15.0

var _game: Node
var _map: Node3D
var _player: CharacterBody3D
var _tablet: Node
var _flashlight: SpotLight3D
var _active := false
var _anomaly := ""
var _night := 1
var _phase := 0.0
var _exposure := 0.0
var _scan_progress := 0.0
var _scan_complete := false
var _required_camera := -1
var _base_gravity := 18.0
var _base_walk := 4.5
var _base_run := 7.5
var _base_flash_energy := 2.4
var _effect_label: Label
var _watcher: CuratorMonster
var _scale_controller: Node
var _incident_origin := Vector3.ZERO
var _incident_name := ""
var _rift_visual: Node3D
var _chalk_marks: Array[MeshInstance3D] = []
var _chalk_index := 0
var _last_chalk_position := Vector3.ZERO


func _ready() -> void:
	add_to_group("gameplay_enhancements")
	add_to_group("resolution_gate")
	call_deferred("_initialize")


func _initialize() -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	_game = get_parent().get_node_or_null("GameManager")
	_tablet = get_parent().get_node_or_null("SecurityCameraTablet")
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	_scale_controller = get_tree().get_first_node_in_group("player_scale_controller")
	var museum := get_tree().get_first_node_in_group("museum_map")
	if museum != null:
		_map = museum.get_node_or_null("GeneratedMap") as Node3D
	if _player != null:
		_flashlight = _player.get_node_or_null("Player Camera/Player Flashlight") as SpotLight3D
		_base_gravity = float(_player.get("gravity"))
		_base_walk = float(_player.get("walk_speed"))
		_base_run = float(_player.get("run_speed"))
	if _flashlight != null:
		_base_flash_energy = _flashlight.light_energy
	_build_hud()
	_build_watcher()


func _carried_tool() -> String:
	if _game == null: return ""
	return str(_game.get("_carried_id"))


func _process(delta: float) -> void:
	if _game == null or _player == null:
		return
	if _carried_tool() == "thermal_chalk":
		_update_chalk()
	var state := int(_game.get("_state"))
	var current := str(_game.get("_anomaly_id"))
	if state == STATE_ANOMALY and current != "":
		if not _active or current != _anomaly:
			_begin_anomaly(current)
		_update_anomaly(delta)
	else:
		if _active:
			_end_anomaly()


func _begin_anomaly(id: String) -> void:
	_end_anomaly()
	_active = true
	_anomaly = id
	_night = int(_game.get("_night"))
	_phase = 0.0
	_exposure = 0.0
	_scan_progress = 0.0
	_scan_complete = _night <= 1
	var puzzle := get_tree().get_first_node_in_group("exhibit_puzzle_controller")
	if puzzle != null:
		if puzzle.has_method("get_incident_origin"):
			_incident_origin = puzzle.get_incident_origin()
		if puzzle.has_method("get_incident_name"):
			_incident_name = puzzle.get_incident_name()
		if puzzle.has_method("get_required_camera"):
			_required_camera = puzzle.get_required_camera() if _night >= 2 else -1
	_build_rift_visual()
	if _watcher != null:
		_watcher.visible = _night >= 2
		# Night 2 seeds the Curator in Space Wing C, night 3 in Mass Wing D —
		# both are unlocked by the time it spawns there.
		_watcher.reset_at(Vector3(24, 0.0, -27) if _night == 2 else Vector3(53, 0.0, -5))
	if not _scan_complete:
		var cam_name := "CAM %02d" % (_required_camera + 1)
		_game.set_objective("cctv", tr("OBJ_CCTV_CONFIRM") % [_incident_name, cam_name, SCAN_TIME], 40)
	_update_effect_label()


func _end_anomaly() -> void:
	if _game != null and _game.has_method("clear_objective"): _game.clear_objective("cctv")
	_active = false
	_anomaly = ""
	_scan_progress = 0.0
	_restore_player()
	if _effect_label != null:
		_effect_label.visible = false
	if _watcher != null:
		_watcher.visible = false
		_watcher.active = false
	if is_instance_valid(_rift_visual):
		_rift_visual.queue_free()
	_rift_visual = null


func _update_anomaly(delta: float) -> void:
	_phase += delta
	_animate_rift(delta)
	_update_scan(delta)
	match _anomaly:
		"gravity_surge":
			_update_gravity()
		"temporal_drift":
			_update_temporal()
		"radiation_bloom":
			_update_radiation(delta)
		"void_rift":
			_update_void()
	_update_player_scale()
	_sync_watcher()
	_update_effect_label()


func _update_chalk() -> void:
	# Термомел: светящаяся дорожка из 40 меток (кольцевой буфер) за игроком.
	if _map == null: return
	if _chalk_marks.is_empty():
		for i in range(40):
			var mark := MeshInstance3D.new()
			var dot := SphereMesh.new(); dot.radius = .05; dot.height = .1
			var mat := StandardMaterial3D.new(); mat.albedo_color = Color(1,.45,.15)
			mat.emission_enabled = true; mat.emission = Color(1,.4,.1); mat.emission_energy_multiplier = 1.6
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; dot.material = mat
			mark.mesh = dot; mark.position = Vector3(0,-999,0); _map.add_child(mark); _chalk_marks.append(mark)
	if _player.global_position.distance_to(_last_chalk_position) >= 1.3:
		_last_chalk_position = _player.global_position
		var mark := _chalk_marks[_chalk_index]; _chalk_index = (_chalk_index+1) % _chalk_marks.size()
		mark.position = _player.global_position + Vector3(0,.06,0)


func _update_gravity() -> void:
	# Gravity rises and falls in readable waves; jumps and loose vertical
	# movement feel materially different from the normal museum.
	if _carried_tool() == "mass_clamp":
		# Зажим массы стабилизирует личную гравитацию оператора.
		_player.set("gravity", _base_gravity)
		_player.set("jump_velocity", 6.0)
		return
	var strength := _local_strength()
	var wave := 0.55 + 0.45 * sin(_phase * 1.7)
	_player.set("gravity", lerpf(_base_gravity, lerpf(_base_gravity * 0.20, _base_gravity * 1.75, wave), strength))
	_player.set("jump_velocity", lerpf(6.0, lerpf(8.5, 4.2, wave), strength))


func _update_temporal() -> void:
	# Alternating slow and fast time affects locomotion without changing the
	# global Engine.time_scale (menus and the countdown remain reliable).
	var factor := lerpf(1.0, 0.72 + 0.38 * sin(_phase * 1.35), _local_strength())
	_player.set("walk_speed", _base_walk * factor)
	_player.set("run_speed", _base_run * factor)


func _update_radiation(delta: float) -> void:
	var distance := _player.global_position.distance_to(_incident_origin)
	var gain := remap(clampf(distance, 2.0, EFFECT_RADIUS), 2.0, EFFECT_RADIUS, 15.0, 1.0)
	if _carried_tool() == "resonance_tuner":
		# Резонансный настройщик гасит набор дозы вдвое.
		gain *= 0.5
	if distance < EFFECT_RADIUS:
		_exposure = minf(100.0, _exposure + gain * delta)
	else:
		_exposure = maxf(0.0, _exposure - 8.0 * delta)
	if _exposure >= 100.0:
		_game.call("_flash", tr("HUD_CRITICAL_DOSE"), Color(1.0, 0.25, 0.15))
		_game.call("_fail")


func _update_void() -> void:
	if _flashlight == null:
		return
	var user_enabled := bool(_player.get("flashlight_enabled"))
	if _local_strength() <= 0.01:
		_flashlight.visible = user_enabled
		_flashlight.light_energy = _base_flash_energy
		return
	var settings := get_tree().get_first_node_in_group("settings_manager")
	if settings != null and settings.reduced_flashes:
		_flashlight.visible = user_enabled
		_flashlight.light_energy = _base_flash_energy * (0.58 + 0.12 * sin(_phase * 3.0))
		return
	var pulse := sin(_phase * 8.0) + sin(_phase * 19.0) * 0.45
	_flashlight.light_energy = _base_flash_energy * (0.12 if pulse < -0.65 else 0.8)
	_flashlight.visible = user_enabled and fmod(_phase, 3.7) > 0.22


func _update_scan(delta: float) -> void:
	if _scan_complete or _required_camera < 0 or _tablet == null:
		return
	var open := bool(_tablet.get("_open"))
	var active_camera := int(_tablet.get("_active"))
	if open and active_camera == _required_camera:
		_scan_progress += delta
		if _scan_progress >= SCAN_TIME:
			_scan_complete = true
			_game.call("_flash", tr("HUD_SOURCE_CONFIRMED"), Color(0.45, 1.0, 0.65))
			_game.clear_objective("cctv")
	else:
		_scan_progress = maxf(0.0, _scan_progress - delta * 0.5)


func can_resolve() -> bool:
	if _scan_complete:
		return true
	var remaining := maxf(0.0, SCAN_TIME - _scan_progress)
	var cam_name := "CAM %02d" % (_required_camera + 1)
	_game.call("_flash", tr("HUD_CONFIRM_SOURCE_FIRST") % [cam_name, remaining], Color(1.0, 0.65, 0.3))
	return false


## Push per-frame state onto the Curator. The chase itself runs in the
## Curator's own _physics_process — driving move_and_slide() from here made
## its speed scale with the render framerate.
func _sync_watcher() -> void:
	if not is_instance_valid(_watcher):
		return
	_watcher.night = _night
	_watcher.slowed = _carried_tool() == "null_lantern"
	# The museum is frozen while the operator is inside a pocket dimension.
	_watcher.active = _watcher.visible and not bool(_game.get("_trial_active"))


func _restore_player() -> void:
	if _scale_controller != null:
		_scale_controller.reset()
	if _player != null:
		_player.set("gravity", _base_gravity)
		_player.set("jump_velocity", 6.0)
		_player.set("walk_speed", _base_walk)
		_player.set("run_speed", _base_run)
	if _flashlight != null:
		_flashlight.visible = bool(_player.get("flashlight_enabled")) if _player != null else true
		_flashlight.light_energy = _base_flash_energy


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Anomaly Effects HUD"
	layer.layer = 11
	add_child(layer)
	_effect_label = Label.new()
	_effect_label.anchor_left = 0.72
	_effect_label.anchor_top = 0.02
	_effect_label.anchor_right = 0.98
	_effect_label.anchor_bottom = 0.16
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_effect_label.add_theme_font_size_override("font_size", 17)
	_effect_label.add_theme_color_override("font_color", Color(0.75, 0.95, 0.8))
	_effect_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_effect_label.add_theme_constant_override("outline_size", 5)
	_effect_label.visible = false
	layer.add_child(_effect_label)


func _update_effect_label() -> void:
	if _effect_label == null:
		return
	_effect_label.visible = _active
	var effect := ""
	match _anomaly:
		"gravity_surge": effect = tr("HUD_EFFECT_GRAVITY") % (float(_player.get("gravity")) / _base_gravity * 100.0)
		"temporal_drift": effect = tr("HUD_EFFECT_TEMPORAL") % (float(_player.get("walk_speed")) / _base_walk * 100.0)
		"radiation_bloom": effect = tr("HUD_EFFECT_DOSE") % _exposure
		"void_rift": effect = tr("HUD_EFFECT_VOID")
		"echo_chamber": effect = tr("HUD_EFFECT_ECHO")
		"glass_bridge": effect = tr("HUD_EFFECT_GLASS")
		"mirror_maze": effect = tr("HUD_EFFECT_MIRROR")
		"yellow_halls": effect = tr("HUD_EFFECT_YELLOW")
		"scrap_run": effect = tr("HUD_EFFECT_SCRAP")
		"ascent": effect = tr("HUD_EFFECT_ASCENT")
	match _carried_tool():
		"spectral_lens":
			effect += "\n" + (tr("HUD_TOOL_LENS") % int(_player.global_position.distance_to(_incident_origin)))
		"thread_spool":
			effect += "\n" + (tr("HUD_TOOL_THREAD") % int(_player.global_position.distance_to(_incident_origin)))
		"phase_prism":
			effect += "\n" + tr("HUD_TOOL_PRISM")
		"null_lantern":
			effect += "\n" + tr("HUD_TOOL_LANTERN")
	var scan := ""
	if not _scan_complete and _required_camera >= 0:
		scan = "\n" + (tr("HUD_SCAN_PROGRESS") % (100.0 * _scan_progress / SCAN_TIME))
	_effect_label.text = effect + scan


func _update_player_scale() -> void:
	if _scale_controller == null:
		return
	var strength := _local_strength()
	if strength <= 0.01:
		_scale_controller.set_target(1.0)
		return
	match _anomaly:
		"gravity_surge":
			_scale_controller.set_target(0.72 + 0.58 * (0.5 + 0.5 * sin(_phase * 0.75)))
		"temporal_drift":
			_scale_controller.set_target(0.78 if fmod(_phase, 12.0) < 6.0 else 1.28)
		"radiation_bloom":
			# Breathing expansion/contraction keeps every calibration size reachable.
			_scale_controller.set_target(1.02 + 0.28 * sin(_phase * 0.62))
		"void_rift":
			_scale_controller.set_target(1.01 + 0.29 * sin(_phase * 0.55))


func _local_strength() -> float:
	if _player == null:
		return 0.0
	var distance := _player.global_position.distance_to(_incident_origin)
	var strength := 1.0 - smoothstep(EFFECT_RADIUS * 0.45, EFFECT_RADIUS, distance)
	if _carried_tool() == "phase_prism":
		# Фазовая призма гасит локальное влияние аномалии.
		strength *= 0.45
	return strength


func _build_rift_visual() -> void:
	if _map == null:
		return
	if is_instance_valid(_rift_visual):
		_rift_visual.queue_free()
	_rift_visual = Node3D.new()
	_rift_visual.name = "Active Exhibit Rupture"
	_rift_visual.position = _incident_origin + Vector3(0, 1.55, 0)
	_map.add_child(_rift_visual)
	var colors := {
		"gravity_surge": Color(0.62, 0.35, 0.95),
		"temporal_drift": Color(0.95, 0.68, 0.25),
		"radiation_bloom": Color(0.35, 0.90, 0.35),
		"void_rift": Color(0.25, 0.45, 0.95),
		"echo_chamber": Color(0.95, 0.42, 0.22),
		"glass_bridge": Color(0.78, 0.38, 0.92),
		"mirror_maze": Color(0.55, 0.78, 0.95),
		"yellow_halls": Color(0.90, 0.80, 0.30),
		"scrap_run": Color(0.55, 0.90, 0.75),
		"ascent": Color(0.95, 0.55, 0.65),
	}
	var color: Color = colors.get(_anomaly, Color(0.7, 0.8, 1.0))
	for i in range(3):
		var ring := MeshInstance3D.new()
		ring.name = "Rupture Ring %d" % i
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.62 + float(i) * 0.2
		mesh.outer_radius = 0.70 + float(i) * 0.2
		ring.mesh = mesh
		ring.rotation_degrees = Vector3(90.0 if i % 2 == 0 else 0.0, float(i) * 37.0, 0.0)
		var material := StandardMaterial3D.new()
		material.albedo_color = color.darkened(0.25)
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
		ring.material_override = material
		_rift_visual.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.2
	light.omni_range = 10.0
	_rift_visual.add_child(light)


func _animate_rift(delta: float) -> void:
	if not is_instance_valid(_rift_visual):
		return
	var lens_active := _carried_tool() == "spectral_lens"
	for i in range(_rift_visual.get_child_count()):
		var child := _rift_visual.get_child(i)
		if child is MeshInstance3D:
			child.rotate_y(delta * (0.65 + 0.22 * float(i)) * (-1.0 if i % 2 else 1.0))
			var ring_mat := (child as MeshInstance3D).material_override as StandardMaterial3D
			if ring_mat != null and ring_mat.no_depth_test != lens_active:
				# Спектральная линза показывает разрыв сквозь стены.
				ring_mat.no_depth_test = lens_active
	var pulse := 1.0 + 0.08 * sin(_phase * 3.2)
	_rift_visual.scale = Vector3.ONE * pulse


func _build_watcher() -> void:
	if _map == null:
		return
	# The Curator owns its own navigation agent and movement; this node only
	# decides *when* it hunts and what a successful catch means.
	_watcher = CuratorMonster.new()
	_watcher.name = "The Curator"
	_watcher.visible = false
	_map.add_child(_watcher)
	_watcher.caught_player.connect(_on_watcher_caught)


func _on_watcher_caught() -> void:
	_game.call("_flash", tr("HUD_CURATOR_CAUGHT"), Color(1, .2, .15))
	_game.call("_fail")
