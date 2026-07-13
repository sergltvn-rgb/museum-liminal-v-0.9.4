extends Node
# Night-shift anomaly loop for the First Museum (steps 2-8 of the plan).
#
# Install: add a plain Node to the main scene (next to the map node and
# the SecurityCameraTablet node) and attach this script. Everything else
# is built at runtime.
#
# Flow:
#   1. Day - the player explores the museum.
#   2. Entering the office triggers the blackout (map handles lights).
#   3. A few seconds later - containment breach: the dome shatters and
#      a random anomaly starts. A timer begins.
#   4. The office alarm terminal shows the anomaly readout and protocol.
#   5. The player takes the right device from Equipment Storage and
#      applies it at the dome before the timer runs out.
#
# Controls: E - take device / read terminal / apply at the dome,
#           G - drop the carried device, ENTER - retry after a fail.

const ACCIDENT_DELAY := 4.0
const NIGHT_TIMER := 240.0
const INTERACT_DISTANCE := 2.8
const APPLY_DISTANCE := 3.4

# Night progression: nights 2-3 open the locked wings and stack anomalies.
const MAX_NIGHT := 3
const SAVE_PATH := "user://museum_save.cfg"
const CALM_TIME := 12.0
const NIGHT_CONFIG := {
	1: {"count": 1, "timer": 240.0, "unlock": ""},
	2: {"count": 2, "timer": 200.0, "unlock": "Space Wing C"},
	3: {"count": 3, "timer": 170.0, "unlock": "Mass Wing D"},
}

const DOME_POS := Vector3(0, 1.2, 0)
const TERMINAL_POS := Vector3(-29, 1.4, 3.1)

const STATE_DAY := 0
const STATE_COUNTDOWN := 1
const STATE_ANOMALY := 2
const STATE_RESOLVED := 3
const STATE_FAILED := 4
const STATE_CALM := 5
const STATE_NIGHT_DONE := 6
const STATE_WIN := 7

# Anomaly types (step 2): terminal readout + required equipment id.
const ANOMALIES := {
	"gravity_surge": {
		"title": "ГРАВИТАЦИОННЫЙ СКАЧОК",
		"readout": "ПОТОК МАССЫ +340%\nОБЪЕКТЫ ТЕРЯЮТ ВЕС\nПРОТОКОЛ: ГРАВИТАЦИОННЫЙ ЯКОРЬ",
		"equipment": "gravity_anchor",
		"color": Color(0.62, 0.35, 0.95),
	},
	"temporal_drift": {
		"title": "ВРЕМЕННОЙ СДВИГ",
		"readout": "РАССИНХРОНИЗАЦИЯ 11,3 С/МИН\nЛОКАЛЬНОЕ ВРЕМЯ НЕСТАБИЛЬНО\nПРОТОКОЛ: ХРОНОСТАБИЛИЗАТОР",
		"equipment": "chrono_stabilizer",
		"color": Color(0.95, 0.68, 0.25),
	},
	"radiation_bloom": {
		"title": "РАДИАЦИОННОЕ ЦВЕТЕНИЕ",
		"readout": "РАДИАЦИЯ 12,8 МЗВ/Ч И РАСТЁТ\nЗЕЛЁНОЕ СВЕЧЕНИЕ\nПРОТОКОЛ: СТЕРЖЕНЬ СДЕРЖИВАНИЯ",
		"equipment": "containment_rod",
		"color": Color(0.35, 0.90, 0.35),
	},
	"void_rift": {
		"title": "РАЗРЫВ ПУСТОТЫ",
		"readout": "ПОТОК МАССЫ −270%\nОБНАРУЖЕНО ПОГЛОЩЕНИЕ СВЕТА\nПРОТОКОЛ: ПОЛЕВОЙ ИЗЛУЧАТЕЛЬ",
		"equipment": "field_emitter",
		"color": Color(0.25, 0.45, 0.95),
	},
	"echo_chamber": {
		"title": "РЕЗОНАНСНОЕ ЭХО",
		"readout": "АКУСТИЧЕСКИЙ КОНТУР ЗАМКНУТ\nПОВТОРЯЮЩИЕСЯ ВСПЫШКИ\nПРОТОКОЛ: РЕЗОНАНСНЫЙ НАСТРОЙЩИК",
		"equipment": "resonance_tuner",
		"color": Color(0.95, 0.42, 0.22),
	},
	"glass_bridge": {
		"title": "ФАЗОВЫЙ ПРОВАЛ",
		"readout": "ОПОРНЫЕ ПОВЕРХНОСТИ НЕСТАБИЛЬНЫ\nФАНТОМНАЯ ГЕОМЕТРИЯ\nПРОТОКОЛ: ФАЗОВАЯ ПРИЗМА",
		"equipment": "phase_prism",
		"color": Color(0.78, 0.38, 0.92),
	},
	"mirror_maze": {
		"title": "ЗЕРКАЛЬНЫЙ РАЗЛОМ",
		"readout": "ОТРАЖЕНИЯ РАССИНХРОНИЗИРОВАНЫ\nЛОЖНАЯ ГЕОМЕТРИЯ В ЗЕРКАЛАХ",
		"equipment": "spectral_lens",
		"color": Color(0.55, 0.78, 0.95),
	},
	"yellow_halls": {
		"title": "ЖЁЛТЫЙ ПРЕДЕЛ",
		"readout": "ЛИМИНАЛЬНАЯ ЗОНА КЛАССА 0\nГУЛ ЛЮМИНЕСЦЕНТНЫХ ЛАМП",
		"equipment": "thread_spool",
		"color": Color(0.90, 0.80, 0.30),
	},
	"scrap_run": {
		"title": "ИЗЪЯТИЕ ЦЕННОСТЕЙ",
		"readout": "ЭКСПОНАТЫ СМЕЩЕНЫ В ТЕНЕВОЙ СКЛАД\nТРЕБУЕТСЯ ИЗВЛЕЧЕНИЕ",
		"equipment": "mass_clamp",
		"color": Color(0.55, 0.90, 0.75),
	},
	"ascent": {
		"title": "ВЕРТИКАЛЬНЫЙ РАЗЛОМ",
		"readout": "ВОСХОДЯЩИЙ ТУМАН В ШАХТЕ\nОПОРЫ ФРАГМЕНТИРОВАНЫ",
		"equipment": "thermal_chalk",
		"color": Color(0.95, 0.55, 0.65),
	},
}

# Короткое назначение ключевых приборов для экрана протокола.
const TOOL_HINTS := {
	"gravity_anchor": "Фиксирует локальную гравитацию у разлома",
	"chrono_stabilizer": "Выравнивает ход времени в зоне аварии",
	"containment_rod": "Гасит радиационное цветение экспоната",
	"field_emitter": "Восстанавливает световой контур в тёмном секторе",
	"resonance_tuner": "Настраивает резонанс эхо-камеры",
	"phase_prism": "Стабилизирует фантомные опоры моста",
	"spectral_lens": "Выявляет дефектные отражения в зале зеркал",
	"thread_spool": "Не даёт потеряться в жёлтых залах",
	"mass_clamp": "Удерживает хрупкие ценности при переноске",
	"thermal_chalk": "Помечает пройденные уступы при восхождении",
}

# Equipment (step 3): pedestal row along z=13 in Equipment Storage,
# clear of the ladder (z10), barrels (z15.8), racks (x-16.2) and the
# door corridor at x=-25.
const EQUIPMENT := {
	"gravity_anchor":{"name":"Гравитационный якорь","color":Color(.62,.35,.95),"position":Vector3(-33.4,0,9.2)},
	"chrono_stabilizer":{"name":"Хроностабилизатор","color":Color(.95,.68,.25),"position":Vector3(-30.75,0,9.2)},
	"containment_rod":{"name":"Стержень сдерживания","color":Color(.35,.90,.35),"position":Vector3(-28.1,0,9.2)},
	"field_emitter":{"name":"Полевой излучатель","color":Color(.25,.45,.95),"position":Vector3(-21.9,0,9.2)},
	"spectral_lens":{"name":"Спектральная линза","color":Color(.35,.85,.92),"position":Vector3(-19.25,0,9.2)},
	"phase_prism":{"name":"Фазовая призма","color":Color(.78,.38,.92),"position":Vector3(-16.6,0,9.2)},
	"resonance_tuner":{"name":"Резонансный настройщик","color":Color(.95,.42,.22),"position":Vector3(-33.4,0,15)},
	"mass_clamp":{"name":"Зажим массы","color":Color(.72,.70,.62),"position":Vector3(-30.75,0,15)},
	"thermal_chalk":{"name":"Термомел","color":Color(.95,.28,.18),"position":Vector3(-28.1,0,15)},
	"memory_reel":{"name":"Катушка памяти","color":Color(.32,.72,.95),"position":Vector3(-21.9,0,15)},
	"null_lantern":{"name":"Нуль-фонарь","color":Color(.32,.25,.58),"position":Vector3(-19.25,0,15)},
	"thread_spool":{"name":"Нить возврата","color":Color(.92,.82,.48),"position":Vector3(-16.6,0,15)},
}

var _map: Node = null
var _map_root: Node = null
var _player: Node3D = null
var _camera: Camera3D = null
var _core: MeshInstance3D = null
var _dome: Node3D = null
var _anomaly_light: OmniLight3D = null

var _state := STATE_DAY
var _accident_in := ACCIDENT_DELAY
var _time_left := NIGHT_TIMER
var _anomaly_id := ""
var _pulse := 0.0
var _night := 1
var _anomalies_left := 0
var _memory_reel_used := false
var _calm_time := 0.0
var _trial_active := false
var _trial_manager: Node

var _devices: Dictionary = {}
var _device_homes: Dictionary = {}
var _carried_id := ""

var _terminal_screen: MeshInstance3D = null
var _terminal_label: Label3D = null

var _hud: CanvasLayer = null
var _objective_label: Label = null
var _timer_label: Label = null
var _hint_label: Label = null
var _message_label: Label = null
var _protocol_layer: CanvasLayer = null
var _protocol_panel: PanelContainer = null
var _proto_title: Label = null
var _proto_item: Label = null
var _proto_purpose: Label = null
var _proto_status: Label = null
var _protocol_time := 0.0

# Тестовая консоль (F9): выбор измерения для проверки. Не влияет на прогресс.
var _admin_layer: CanvasLayer = null
var _admin_panel: PanelContainer = null
var _test_mode := false
var _pre_test_state := STATE_DAY
var _pre_test_time_left := 0.0
var _pre_test_calm := 0.0
var _pre_test_anomaly := ""
var _message_time := 0.0
var _fail_overlay: ColorRect = null
var _win_overlay: ColorRect = null
var _objective_entries: Dictionary = {}
var _objective_priorities: Dictionary = {}


func _ready() -> void:
	call_deferred("_initialize")


func _initialize() -> void:
	# Editor reloads can detach this node before an awaited frame. Initialize
	# only after entering a valid SceneTree and check again after each wait.
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_map = get_tree().get_first_node_in_group("museum_map")
	if _map == null:
		push_warning("GameManager: museum map not found (group 'museum_map')")
		return
	_map_root = _map.get_node_or_null("GeneratedMap")
	if _map_root == null:
		_map_root = _map
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player != null:
		_camera = _player.get_node_or_null("Player Camera") as Camera3D
	_core = _map_root.find_child("Anomalous Core", true, false) as MeshInstance3D
	_dome = _map_root.find_child("Containment Dome", true, false) as Node3D
	_night = _load_night()
	for n in range(2, _night + 1):
		_unlock_for_night(n)
	_build_devices()
	_build_terminal()
	_build_protocol_screen()
	_build_hud()
	_build_test_admin()
	var trial_script := load("res://game/RiftTrialManager.gd")
	_trial_manager = trial_script.new() as Node
	_trial_manager.name = "RiftTrialManager"
	add_child(_trial_manager)
	_trial_manager.call("setup", self)
	_set_objective("Ночь %d. Осмотрите музей. Офис охраны — в западном крыле." % _night)


func _process(delta: float) -> void:
	if _map == null:
		return
	if _message_time > 0.0:
		_message_time -= delta
		if _message_label != null:
			_message_label.modulate.a = clampf(_message_time / 0.9, 0.0, 1.0)
	match _state:
		STATE_DAY:
			if bool(_map.get("_blackout_done")):
				_state = STATE_COUNTDOWN
				_accident_in = ACCIDENT_DELAY
				_set_objective("Питание пропало. Что-то происходит в атриуме...")
		STATE_COUNTDOWN:
			_accident_in -= delta
			if _accident_in <= 0.0:
				_start_accident()
		STATE_CALM:
			_calm_time -= delta
			if _calm_time <= 0.0:
				_start_accident()
		STATE_ANOMALY:
			_time_left -= delta
			_pulse += delta
			if _protocol_time > 0.0:
				_protocol_time -= delta
				if _protocol_time <= 0.0:
					_hide_protocol()
			if _timer_label != null:
				_timer_label.visible = true
				_timer_label.text = _format_time(_time_left)
			if is_instance_valid(_anomaly_light):
				_anomaly_light.light_energy = 1.5 + 0.7 * sin(_pulse * 3.0)
			if _time_left <= 0.0:
				_fail()
		_:
			pass
	_update_hint()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_F9 or event.keycode == KEY_F9):
		_toggle_test_admin()
		get_viewport().set_input_as_handled()
		return
	if _admin_layer != null and _admin_layer.visible:
		return
	if _trial_active:
		return
	if _protocol_layer != null and _protocol_layer.visible and (event.is_action_pressed("confirm") or event.is_action_pressed("interact")):
		_hide_protocol()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("confirm"):
		if _state == STATE_FAILED:
			_retry()
		elif _state == STATE_NIGHT_DONE:
			_advance_night()
		elif _state == STATE_WIN:
			get_tree().reload_current_scene()
	elif event.is_action_pressed("drop_item"):
		_drop_device()
	elif event.is_action_pressed("interact"):
		_interact()


# --- Night flow -----------------------------------------------------------

func _start_accident() -> void:
	_state = STATE_ANOMALY
	if _anomalies_left <= 0:
		_anomalies_left = int(NIGHT_CONFIG[_night]["count"])
	_time_left = float(NIGHT_CONFIG[_night]["timer"])
	_pulse = 0.0
	_anomaly_id = str(ANOMALIES.keys().pick_random())
	var puzzle := get_tree().get_first_node_in_group("exhibit_puzzle_controller")
	if puzzle != null and puzzle.has_method("prepare_incident"):
		puzzle.prepare_incident(_anomaly_id, _night)
	var info: Dictionary = ANOMALIES[_anomaly_id]
	var color: Color = info["color"]
	# The atrium core remains an alarm beacon; the actual rupture is attached
	# to the randomly selected exhibit and must be treated there.
	_set_dome_breach(false, color)
	_tint_core(color, 2.4)
	if not is_instance_valid(_anomaly_light):
		_anomaly_light = OmniLight3D.new()
		_anomaly_light.name = "Anomaly Light"
		_anomaly_light.position = _incident_position() + Vector3(0, 2.4, 0)
		_anomaly_light.omni_range = 16.0
		_map_root.add_child(_anomaly_light)
	_anomaly_light.light_color = color
	# Tint the night fog toward the anomaly.
	var env: Variant = _map.get("_environment")
	if env is Environment:
		env.fog_light_color = color.darkened(0.65)
		env.volumetric_fog_albedo = color.lightened(0.2)
	# Terminal readout (step 5).
	if _terminal_label != null:
		_terminal_label.text = "!! НАРУШЕНИЕ СДЕРЖИВАНИЯ !!\n%s\n%s" % [info["title"], info["readout"]]
	_set_screen_color(color)
	_set_objective("АВАРИЯ: %s. Найдите источник, завершите протокол и примените стабилизатор у экспоната. Осталось: %d" % [_incident_name(), _anomalies_left])
	_flash("СДЕРЖИВАНИЕ НАРУШЕНО", Color(1.0, 0.35, 0.3))
	_show_protocol(info, color)
	var am := _audio()
	if am != null:
		if am.has_method("set_alarm"):
			am.set_alarm(true)
		if am.has_method("set_anomaly_hum"):
			am.set_anomaly_hum(true, DOME_POS)


func _resolve() -> void:
	_state = STATE_RESOLVED
	# The device is spent in the containment field.
	var body: StaticBody3D = _devices.get(_carried_id)
	if body != null:
		body.queue_free()
	_devices.erase(_carried_id)
	_carried_id = ""
	# Calm the core, restore the dome.
	_tint_core(Color(0.45, 0.95, 0.75), 0.7)
	if is_instance_valid(_anomaly_light):
		_anomaly_light.queue_free()
	_set_dome_breach(false, Color(0.45, 0.95, 0.75))
	if _timer_label != null:
		_timer_label.visible = false
	# Emergency power: part of the lights come back, dimmed.
	var lights: Variant = _map.get("_powered_lights")
	if lights is Array:
		for l in lights:
			if is_instance_valid(l) and not l.visible:
				l.visible = true
				l.light_energy = l.light_energy * 0.45
	if _terminal_label != null:
		_terminal_label.text = "СИСТЕМА: СДЕРЖИВАНИЕ ВОССТАНОВЛЕНО\nДОБРОЙ НОЧИ, НАБЛЮДАТЕЛЬ"
	_set_screen_color(Color(0.2, 0.8, 0.5))
	var am := _audio()
	if am != null:
		if am.has_method("set_alarm"):
			am.set_alarm(false)
		if am.has_method("set_anomaly_hum"):
			am.set_anomaly_hum(false)
		if am.has_method("play_sfx"):
			am.play_sfx("resolve")
	_anomalies_left -= 1
	if _anomalies_left > 0:
		_state = STATE_CALM
		_calm_time = CALM_TIME
		_respawn_devices()
		_set_objective("Аномалия устранена, но ядро нестабильно. Следующий выброс близко...")
		_flash("АНОМАЛИЯ УСТРАНЕНА. ЯДРО ВСЁ ЕЩЁ НЕСТАБИЛЬНО", Color(0.85, 0.95, 0.6))
	elif _night >= MAX_NIGHT:
		_win()
	else:
		_state = STATE_NIGHT_DONE
		_save_night(_night + 1)
		_set_objective("Ночь %d пройдена. ENTER - следующая ночь." % _night)
		_flash("НОЧЬ %d ПРОЙДЕНА" % _night, Color(0.5, 1.0, 0.6))


func _fail() -> void:
	if _trial_manager != null:
		_trial_manager.call("abort")
	_trial_active = false
	_state = STATE_FAILED
	var am := _audio()
	if am != null:
		if am.has_method("set_alarm"):
			am.set_alarm(false)
		if am.has_method("set_anomaly_hum"):
			am.set_anomaly_hum(false)
		if am.has_method("play_sfx"):
			am.play_sfx("fail")
	if _fail_overlay != null:
		_fail_overlay.visible = true
	if _timer_label != null:
		_timer_label.visible = false


func _retry() -> void:
	if _fail_overlay != null:
		_fail_overlay.visible = false
	# Return the carried device to its pedestal.
	if _carried_id != "":
		var body: StaticBody3D = _devices.get(_carried_id)
		if body != null:
			body.get_parent().remove_child(body)
			_map_root.add_child(body)
			body.scale = Vector3.ONE
			body.global_transform = _device_homes[_carried_id]
			_set_collision(body, true)
		_carried_id = ""
	# Devices spent earlier in the night come back; a fresh anomaly rolls.
	_respawn_devices()
	_anomalies_left = int(NIGHT_CONFIG[_night]["count"])
	_start_accident()


# --- Night progression ------------------------------------------------------

func _advance_night() -> void:
	_night += 1
	_save_night(_night)
	_unlock_for_night(_night)
	_respawn_devices()
	_anomalies_left = int(NIGHT_CONFIG[_night]["count"])
	_state = STATE_COUNTDOWN
	_accident_in = 8.0
	_set_objective("Ночь %d. Ядро снова нестабильно..." % _night)
	var wing := str(NIGHT_CONFIG[_night].get("unlock", ""))
	if wing != "":
		_flash("НОЧЬ %d. Открыто крыло: %s" % [_night, wing], Color(0.7, 0.85, 1.0))
	else:
		_flash("НОЧЬ %d" % _night, Color(0.7, 0.85, 1.0))


func _win() -> void:
	_state = STATE_WIN
	if _timer_label != null:
		_timer_label.visible = false
	if _win_overlay != null:
		_win_overlay.visible = true
	_save_night(1)
	_set_objective("")


func _load_night() -> int:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 1
	return clampi(int(config.get_value("progress", "night", 1)), 1, MAX_NIGHT)


func _save_night(night: int) -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "night", clampi(night, 1, MAX_NIGHT))
	config.save(SAVE_PATH)


func _unlock_for_night(night: int) -> void:
	var wing := str(NIGHT_CONFIG.get(night, {}).get("unlock", ""))
	if wing != "" and _map != null and _map.has_method("unlock_wing"):
		_map.unlock_wing(wing)


func _audio() -> Node:
	return get_tree().get_first_node_in_group("audio_manager")


func _incident_position() -> Vector3:
	var puzzle := get_tree().get_first_node_in_group("exhibit_puzzle_controller")
	if puzzle != null and puzzle.has_method("get_incident_origin"):
		return puzzle.get_incident_origin()
	return DOME_POS


func _incident_name() -> String:
	var puzzle := get_tree().get_first_node_in_group("exhibit_puzzle_controller")
	if puzzle != null and puzzle.has_method("get_incident_name"):
		return puzzle.get_incident_name()
	return "центральное ядро"


func _sfx(sound: String, volume_db := 0.0) -> void:
	var am := _audio()
	if am != null and am.has_method("play_sfx"):
		am.play_sfx(sound, volume_db)


# --- Interaction (step 4) -------------------------------------------------

func _interact() -> void:
	if _state == STATE_FAILED or _player == null or _trial_active:
		return
	# Apply the carried device directly at the possessed exhibit.
	if _carried_id != "" and _state == STATE_ANOMALY and _near(_incident_position(), APPLY_DISTANCE):
		var info: Dictionary = ANOMALIES[_anomaly_id]
		if _carried_id == str(info["equipment"]):
			for gate in get_tree().get_nodes_in_group("resolution_gate"):
				if gate.has_method("can_resolve") and not gate.can_resolve():
					return
			_begin_trial()
		else:
			_flash("Прибор не действует. Проверьте показания терминала.", Color(1.0, 0.45, 0.4))
		return
	# Pick up a device.
	if _carried_id == "":
		var target := _raycast_body()
		if target != null and target.is_in_group("equipment"):
			_pick_up(str(target.get_meta("equipment_id")))
			return
	# Read the terminal.
	if _near(TERMINAL_POS, INTERACT_DISTANCE) and _anomaly_id != "" and _state == STATE_ANOMALY:
		var info: Dictionary = ANOMALIES[_anomaly_id]
		var device_name: String = EQUIPMENT[str(info["equipment"])]["name"]
		_flash("%s -> %s" % [info["title"], device_name], Color(0.7, 0.95, 0.8))
		_sfx("terminal_beep")


func _begin_trial() -> void:
	if _trial_manager == null or _player == null or _trial_active:
		return
	_trial_active = true
	_hide_protocol()
	set_objective("trial", "Пройдите карманное измерение и создайте ключ стабилизации.", 50)
	_flash("ПЕРЕХОД В КАРМАННОЕ ИЗМЕРЕНИЕ", Color(0.55, 0.75, 1.0))
	_trial_manager.call("begin", _anomaly_id, _player)


func _complete_trial() -> void:
	if not _trial_active:
		return
	_trial_active = false
	clear_objective("trial")
	if _test_mode:
		# Тестовый прогон: возвращаем состояние ночи как было до запуска.
		_test_mode = false
		_anomaly_id = _pre_test_anomaly
		_state = _pre_test_state
		_time_left = _pre_test_time_left
		_calm_time = _pre_test_calm
		if _timer_label != null and _state != STATE_ANOMALY:
			_timer_label.visible = false
		_flash("ТЕСТ ЗАВЕРШЁН · F9 — выбрать следующее измерение", Color(0.55, 1.0, 0.7))
		return
	_resolve()


func _pick_up(id: String) -> void:
	var body: StaticBody3D = _devices.get(id)
	if body == null or _camera == null:
		return
	_carried_id = id
	body.get_parent().remove_child(body)
	_camera.add_child(body)
	body.position = Vector3(0.42, -0.35, -0.75)
	body.rotation = Vector3.ZERO
	body.scale = Vector3(0.8, 0.8, 0.8)
	_set_collision(body, false)
	_flash("Взят прибор: %s" % EQUIPMENT[id]["name"], Color(0.85, 0.9, 0.8))
	if id == "memory_reel" and not _memory_reel_used and _state == STATE_ANOMALY:
		# Катушка памяти: одноразовый бонус времени за ночную смену.
		_memory_reel_used = true
		_time_left += 45.0
		_flash("КАТУШКА ПАМЯТИ: +45 СЕКУНД К ТАЙМЕРУ", Color(0.6, 0.85, 1.0))
	_sfx("pickup")


func _drop_device() -> void:
	if _carried_id == "" or _player == null:
		return
	var body: StaticBody3D = _devices.get(_carried_id)
	_carried_id = ""
	if body == null:
		return
	body.get_parent().remove_child(body)
	_map_root.add_child(body)
	body.scale = Vector3.ONE
	body.rotation = Vector3.ZERO
	var forward := -_player.global_transform.basis.z
	body.global_position = _player.global_position + forward * 1.0 + Vector3(0, 0.35, 0)
	_set_collision(body, true)
	_sfx("drop")


func _raycast_body() -> Node:
	if _camera == null:
		return null
	var from := _camera.global_position
	var to := from - _camera.global_transform.basis.z * INTERACT_DISTANCE
	var params := PhysicsRayQueryParameters3D.create(from, to)
	if _player is PhysicsBody3D:
		params.exclude = [(_player as PhysicsBody3D).get_rid()]
	var hit := _camera.get_world_3d().direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return null
	return hit.get("collider") as Node


func _near(point: Vector3, dist: float) -> bool:
	return _player != null and _player.global_position.distance_to(point) <= dist


func _set_collision(body: StaticBody3D, enabled: bool) -> void:
	body.collision_layer = 1 if enabled else 0
	for child in body.get_children():
		if child is CollisionShape3D:
			child.disabled = not enabled


# --- World construction (step 3 + 5) ---------------------------------------

func _build_devices() -> void:
	# Четыре сегмента верстаков у боковых стен; центральный проход x=-25
	# между дверью офиса (z=7) и реставрационной (z=17) остаётся свободным.
	for bench_x: float in [-30.75, -19.25]:
		for bench_z: float in [9.2, 15.0]:
			_static_box("Верстак оборудования",Vector3(bench_x,.55,bench_z),Vector3(6.8,1.1,1.25),Color(.12,.14,.15))
	var slot:=1
	for id in EQUIPMENT.keys():
		var info:Dictionary=EQUIPMENT[id]; var base:Vector3=info["position"]
		_static_box("Гнездо %02d"%slot,Vector3(base.x,1.14,base.z),Vector3(1.05,.08,.85),Color(.22,.25,.27))
		_spawn_device(id); slot+=1


func _respawn_devices() -> void:
	# Devices are spent when applied at the dome; bring the missing ones
	# back between anomalies, retries and nights.
	for id in EQUIPMENT.keys():
		var existing: Variant = _devices.get(id)
		if existing == null or not is_instance_valid(existing):
			_spawn_device(id)


func _spawn_device(id: String) -> void:
	var info: Dictionary = EQUIPMENT[id]
	var base: Vector3 = info["position"]
	var color: Color = info["color"]
	var body := StaticBody3D.new()
	body.name = str(info["name"])
	body.position = Vector3(base.x, 1.48, base.z)
	body.add_to_group("equipment")
	body.add_to_group("interactable")
	body.set_meta("equipment_id", id)
	body.set_meta("device_name", info["name"])
	_map_root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.55, 0.6, 0.55)
	shape.shape = box
	body.add_child(shape)
	match id:
		"gravity_anchor":
			_mesh_box(body, Vector3(0, -0.12, 0), Vector3(0.34, 0.22, 0.34),
				Color(0.16, 0.16, 0.2))
			_mesh_torus(body, Vector3(0, 0.08, 0), 0.14, 0.22,
				Color(0.3, 0.3, 0.36), 0.0, false)
			_mesh_sphere(body, Vector3(0, 0.08, 0), 0.09, color, 1.4)
		"chrono_stabilizer":
			_mesh_box(body, Vector3(0, 0, 0), Vector3(0.34, 0.34, 0.22),
				Color(0.2, 0.18, 0.14))
			var dial := _mesh_cylinder(body, Vector3(0, 0.02, 0.13), 0.12, 0.03,
				color, 1.1)
			dial.rotation_degrees = Vector3(90, 0, 0)
		"containment_rod":
			_mesh_cylinder(body, Vector3(0, 0, 0), 0.045, 0.62,
				Color(0.35, 0.37, 0.4))
			_mesh_sphere(body, Vector3(0, 0.36, 0), 0.08, color, 1.4)
			_mesh_box(body, Vector3(0, -0.24, 0), Vector3(0.16, 0.1, 0.16),
				Color(0.14, 0.14, 0.15))
		"field_emitter":
			_mesh_box(body, Vector3(0, -0.18, 0), Vector3(0.3, 0.12, 0.3),
				Color(0.15, 0.17, 0.2))
			_mesh_cone(body, Vector3(0, 0.02, 0), 0.19, 0.05, 0.3,
				Color(0.3, 0.34, 0.4))
			_mesh_sphere(body, Vector3(0, 0.26, 0), 0.07, color, 1.5)
		_:
			_mesh_box(body,Vector3(0,-.08,0),Vector3(.34,.18,.30),Color(.13,.15,.17))
			_mesh_torus(body,Vector3(0,.10,0),.11,.19,color,.8,false)
			_mesh_sphere(body,Vector3(0,.10,0),.06,color,1.4)
	var label := Label3D.new()
	label.text = str(info["name"])
	label.position = Vector3(0, 0.55, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 34
	label.pixel_size = 0.0035
	label.modulate = color
	body.add_child(label)
	_devices[id] = body
	_device_homes[id] = body.global_transform


func _build_terminal() -> void:
	# Screen above the existing "Alarm Terminal" box in the office.
	_terminal_screen = MeshInstance3D.new()
	_terminal_screen.name = "Anomaly Terminal Screen"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.3, 0.8, 0.08)
	_terminal_screen.mesh = mesh
	_terminal_screen.position = TERMINAL_POS + Vector3(0, 0.75, 0)
	_map_root.add_child(_terminal_screen)
	_set_screen_color(Color(0.1, 0.3, 0.25))
	_terminal_label = Label3D.new()
	_terminal_label.name = "Anomaly Terminal Readout"
	_terminal_label.text = "СИСТЕМА В НОРМЕ\nВСЕ ЭКСПОНАТЫ СТАБИЛЬНЫ"
	# Faces the room centre (the desk side, -z).
	_terminal_label.position = TERMINAL_POS + Vector3(0, 0.75, -0.12)
	_terminal_label.rotation_degrees = Vector3(0, 180, 0)
	_terminal_label.font_size = 40
	_terminal_label.pixel_size = 0.003
	_terminal_label.modulate = Color(0.65, 0.95, 0.8)
	_terminal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_root.add_child(_terminal_label)


# --- Тестовая консоль (F9) --------------------------------------------------

const ADMIN_DESCRIPTIONS := {
	"gravity_surge": "Три якоря поворачивают гравитацию: пол, стена, глубина",
	"temporal_drift": "Запишите три своих временных эха на плитах",
	"radiation_bloom": "Расставьте монолиты по гнёздам и настройте частоты",
	"void_rift": "Полная тьма: рисуйте мир лидаром (ЛКМ), избегайте монстра",
	"echo_chamber": "Запомните и повторите последовательность вспышек колонн",
	"glass_bridge": "Пройдите мост: в каждом ряду одна плита — фантом",
	"mirror_maze": "Найдите 3 дефектных отражения. 3 ошибки — зал перестроится",
	"yellow_halls": "Жёлтые залы: соберите плёнки, не попадитесь Блуждающему",
	"scrap_run": "Вынесите 3 ценности к точке извлечения мимо дрона-сканера",
	"ascent": "Подъём по уступам: контрольные точки, движущиеся плиты, туман",
}


func _admin_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


func _build_test_admin() -> void:
	_admin_layer = CanvasLayer.new()
	_admin_layer.name = "Test Admin Console"
	_admin_layer.layer = 60
	_admin_layer.visible = false
	add_child(_admin_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.03, 0.8)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_admin_layer.add_child(shade)
	_admin_panel = PanelContainer.new()
	_admin_panel.anchor_left = 0.18
	_admin_panel.anchor_top = 0.06
	_admin_panel.anchor_right = 0.82
	_admin_panel.anchor_bottom = 0.94
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.05, 0.075, 0.985)
	panel_style.border_color = Color(0.3, 0.65, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 26.0
	panel_style.content_margin_right = 26.0
	panel_style.content_margin_top = 20.0
	panel_style.content_margin_bottom = 20.0
	_admin_panel.add_theme_stylebox_override("panel", panel_style)
	_admin_layer.add_child(_admin_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	_admin_panel.add_child(layout)
	var header := Label.new()
	header.text = "СЛУЖЕБНАЯ КОНСОЛЬ · ТЕСТ ИЗМЕРЕНИЙ"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color(0.62, 0.85, 1.0))
	layout.add_child(header)
	var sub := Label.new()
	sub.text = "Выберите разлом — вы окажетесь внутри мгновенно. Прогресс ночи и сохранения не изменяются."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.66, 0.74, 0.82))
	layout.add_child(sub)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.2, 0.42, 0.6)
	layout.add_child(divider)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	for id: String in ANOMALIES.keys():
		var info: Dictionary = ANOMALIES[id]
		var accent: Color = info["color"]
		var button := Button.new()
		button.text = "%s\n%s" % [str(info["title"]), str(ADMIN_DESCRIPTIONS.get(id, ""))]
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 62)
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", accent.lightened(0.35))
		button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
		button.add_theme_stylebox_override("normal", _admin_button_style(Color(0.05, 0.075, 0.11, 0.96), accent.darkened(0.25)))
		button.add_theme_stylebox_override("hover", _admin_button_style(accent.darkened(0.72), accent))
		button.add_theme_stylebox_override("pressed", _admin_button_style(accent.darkened(0.55), accent.lightened(0.2)))
		button.pressed.connect(_admin_select_dimension.bind(id))
		grid.add_child(button)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	layout.add_child(footer)
	var close := Button.new()
	close.text = "ЗАКРЫТЬ · F9"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(180, 42)
	close.add_theme_font_size_override("font_size", 15)
	close.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	close.add_theme_stylebox_override("normal", _admin_button_style(Color(0.09, 0.1, 0.12, 0.95), Color(0.45, 0.5, 0.56)))
	close.add_theme_stylebox_override("hover", _admin_button_style(Color(0.16, 0.18, 0.2, 0.95), Color(0.7, 0.75, 0.8)))
	close.add_theme_stylebox_override("pressed", _admin_button_style(Color(0.2, 0.22, 0.25, 0.95), Color(0.85, 0.9, 0.95)))
	close.pressed.connect(_toggle_test_admin)
	footer.add_child(close)
	var note := Label.new()
	note.text = "Режим теста: после прохождения вы вернётесь в музей без последствий."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.55, 0.62, 0.68))
	footer.add_child(note)


func _toggle_test_admin() -> void:
	if _admin_layer == null:
		return
	if _trial_active:
		_flash("Сначала завершите текущее измерение.", Color(1.0, 0.65, 0.35))
		return
	var opening := not _admin_layer.visible
	_admin_layer.visible = opening
	# Пока консоль открыта, игрок не вращает камеру и не перехватывает мышь.
	if _player != null:
		_player.set("controls_enabled", not opening)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if opening else Input.MOUSE_MODE_CAPTURED
	_sfx("tablet_click", -8.0)


func _admin_select_dimension(id: String) -> void:
	if _trial_active or not ANOMALIES.has(id):
		return
	_admin_layer.visible = false
	if _player != null:
		_player.set("controls_enabled", true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_pre_test_state = _state
	_pre_test_time_left = _time_left
	_pre_test_calm = _calm_time
	_pre_test_anomaly = _anomaly_id
	_test_mode = true
	_anomaly_id = id
	_anomalies_left = maxi(_anomalies_left, 1)
	_time_left = 999999.0
	_pulse = 0.0
	_state = STATE_ANOMALY
	if _fail_overlay != null:
		_fail_overlay.visible = false
	if _win_overlay != null:
		_win_overlay.visible = false
	_hide_protocol()
	_flash("ТЕСТ: %s" % str(ANOMALIES[id]["title"]), ANOMALIES[id]["color"] as Color)
	_begin_trial()


# --- HUD (step 8) -----------------------------------------------------------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "Night HUD"
	add_child(_hud)
	_objective_label = _make_label(Vector4(0.01, 0.01, 0.62, 0.10), 15,
		Color(0.85, 0.88, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
	_timer_label = _make_label(Vector4(0.40, 0.02, 0.60, 0.10), 30,
		Color(1.0, 0.35, 0.3), HORIZONTAL_ALIGNMENT_CENTER)
	_timer_label.visible = false
	_hint_label = _make_label(Vector4(0.10, 0.90, 0.90, 0.98), 17,
		Color(0.9, 0.92, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	_message_label = _make_label(Vector4(0.10, 0.40, 0.90, 0.52), 26,
		Color(1.0, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_message_label.modulate.a = 0.0
	_fail_overlay = ColorRect.new()
	_fail_overlay.color = Color(0.08, 0.0, 0.0, 0.82)
	_fail_overlay.anchor_right = 1.0
	_fail_overlay.anchor_bottom = 1.0
	_fail_overlay.visible = false
	_hud.add_child(_fail_overlay)
	var fail_label := Label.new()
	fail_label.text = "АНОМАЛИЯ ПОГЛОТИЛА МУЗЕЙ\n\nENTER - начать ночь заново"
	fail_label.anchor_right = 1.0
	fail_label.anchor_bottom = 1.0
	fail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fail_label.add_theme_font_size_override("font_size", 26)
	fail_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_fail_overlay.add_child(fail_label)
	_win_overlay = ColorRect.new()
	_win_overlay.color = Color(0.0, 0.05, 0.03, 0.85)
	_win_overlay.anchor_right = 1.0
	_win_overlay.anchor_bottom = 1.0
	_win_overlay.visible = false
	_hud.add_child(_win_overlay)
	var win_label := Label.new()
	win_label.text = "СМЕНА ОКОНЧЕНА\nВсе три ночи пройдены. Музей снова спит.\n\nENTER - начать заново"
	win_label.anchor_right = 1.0
	win_label.anchor_bottom = 1.0
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	win_label.add_theme_font_size_override("font_size", 26)
	win_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.7))
	_win_overlay.add_child(win_label)


func _protocol_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.045, 0.06, 0.97)
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 30.0
	style.content_margin_right = 30.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	return style


func _proto_label(size: int, color: Color, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_protocol_screen() -> void:
	_protocol_layer = CanvasLayer.new()
	_protocol_layer.name = "Protocol Screen"
	_protocol_layer.layer = 12
	_protocol_layer.visible = false
	add_child(_protocol_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.008, 0.012, 0.028, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_protocol_layer.add_child(dim)
	_protocol_panel = PanelContainer.new()
	_protocol_panel.anchor_left = 0.26
	_protocol_panel.anchor_top = 0.14
	_protocol_panel.anchor_right = 0.74
	_protocol_panel.anchor_bottom = 0.8
	_protocol_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_protocol_panel.add_theme_stylebox_override("panel", _protocol_style(Color(0.4, 0.7, 0.9)))
	_protocol_layer.add_child(_protocol_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_protocol_panel.add_child(box)
	var header := _proto_label(15, Color(0.55, 0.68, 0.78), HORIZONTAL_ALIGNMENT_CENTER)
	header.text = "ПЕРВЫЙ МУЗЕЙ · СЛУЖБА НОЧНОГО СДЕРЖИВАНИЯ"
	box.add_child(header)
	_proto_title = _proto_label(25, Color(0.95, 0.55, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_proto_title)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.25, 0.35, 0.42)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)
	var need := _proto_label(15, Color(0.6, 0.72, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	need.text = "ВОЗЬМИТЕ СО СКЛАДА ОБОРУДОВАНИЯ:"
	box.add_child(need)
	_proto_item = _proto_label(33, Color(0.95, 0.9, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_proto_item)
	_proto_purpose = _proto_label(17, Color(0.75, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_proto_purpose)
	_proto_status = _proto_label(16, Color(0.62, 0.74, 0.7), HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(_proto_status)
	var footer := _proto_label(14, Color(0.5, 0.58, 0.64), HORIZONTAL_ALIGNMENT_CENTER)
	footer.text = "E / ENTER — закрыть · Экран закроется сам"
	box.add_child(footer)


func _show_protocol(info: Dictionary, accent: Color) -> void:
	if _protocol_layer == null:
		return
	var equip_id := str(info["equipment"])
	var equip_name := equip_id
	if EQUIPMENT.has(equip_id):
		equip_name = str(EQUIPMENT[equip_id]["name"])
	_proto_title.text = "ПРОТОКОЛ ЛОКАЛИЗАЦИИ: %s" % str(info["title"])
	_proto_item.text = equip_name.to_upper()
	_proto_item.add_theme_color_override("font_color", accent.lightened(0.4))
	_proto_purpose.text = str(TOOL_HINTS.get(equip_id, ""))
	_proto_status.text = "НОЧЬ: %d\nЗОНА АВАРИИ: %s\nМЕСТО ВЫДАЧИ: Склад оборудования\nСТАТУС: ожидает выдачи" % [_night, _incident_name()]
	_protocol_panel.add_theme_stylebox_override("panel", _protocol_style(accent))
	_protocol_layer.visible = true
	_protocol_time = 10.0
	var am := _audio()
	if am != null and am.has_method("play_sfx"):
		am.play_sfx("terminal_beep", -6.0, 0.9)


func _hide_protocol() -> void:
	_protocol_time = 0.0
	if _protocol_layer != null:
		_protocol_layer.visible = false



func _make_label(anchors: Vector4, size: int, color: Color,
		align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.anchor_left = anchors.x
	label.anchor_top = anchors.y
	label.anchor_right = anchors.z
	label.anchor_bottom = anchors.w
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	_hud.add_child(label)
	return label


func _update_hint() -> void:
	if _hint_label == null or _player == null:
		return
	var hint := ""
	if _state != STATE_FAILED and _state != STATE_WIN and _state != STATE_NIGHT_DONE:
		if _carried_id != "":
			var carried_name: String = EQUIPMENT[_carried_id]["name"]
			if _state == STATE_ANOMALY and _near(_incident_position(), APPLY_DISTANCE):
				hint = "E - применить %s к аномалии" % carried_name
			else:
				hint = "В руках: %s (G - бросить)" % carried_name
		else:
			var target := _raycast_body()
			if target != null and target.is_in_group("equipment"):
				hint = "E - взять: %s" % str(target.get_meta("device_name"))
			elif _state == STATE_ANOMALY and _near(TERMINAL_POS, INTERACT_DISTANCE):
				hint = "E - показания терминала"
	_hint_label.text = hint


func _set_objective(text: String) -> void:
	set_objective("game", text, 10)


func set_objective(source: String, text: String, priority := 10) -> void:
	if text == "":
		_objective_entries.erase(source)
		_objective_priorities.erase(source)
	else:
		_objective_entries[source] = text
		_objective_priorities[source] = priority
	_refresh_objective()


func clear_objective(source: String) -> void:
	_objective_entries.erase(source)
	_objective_priorities.erase(source)
	_refresh_objective()


func _refresh_objective() -> void:
	if _objective_label == null:
		return
	var text := ""
	var best := -999
	for source in _objective_entries:
		var priority := int(_objective_priorities.get(source, 0))
		if priority > best:
			best = priority
			text = str(_objective_entries[source])
	_objective_label.text = text


func _flash(text: String, color: Color) -> void:
	if _message_label == null:
		return
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)
	_message_label.modulate.a = 1.0
	_message_time = 3.0


func _format_time(t: float) -> String:
	var s := maxi(int(ceil(t)), 0)
	return "%d:%02d" % [int(s / 60.0), s % 60]


# --- Visual helpers ---------------------------------------------------------

func _tint_core(color: Color, emission: float) -> void:
	if _core == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = emission
	_core.material_override = mat


func _set_dome_breach(breached: bool, color: Color) -> void:
	# With the force-field shader the dome cracks and strobes instead of
	# disappearing; without the shader, fall back to hiding the mesh.
	if _dome == null:
		return
	var mesh := _dome as MeshInstance3D
	var mat: ShaderMaterial = null
	if mesh != null:
		mat = mesh.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("damage", 1.0 if breached else 0.0)
		mat.set_shader_parameter("anomaly_color", color)
		_dome.visible = true
	else:
		_dome.visible = not breached


func _set_screen_color(color: Color) -> void:
	if _terminal_screen == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.55)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.9
	_terminal_screen.material_override = mat


func _static_box(box_name: String, pos: Vector3, size: Vector3,
		color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = pos
	_map_root.add_child(body)
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh_instance(body, mesh, Vector3.ZERO, color, 0.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)


func _mesh_instance(parent: Node, mesh: Mesh, pos: Vector3, color: Color,
		emission := 0.0) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	inst.material_override = mat
	parent.add_child(inst)
	return inst


func _mesh_box(parent: Node, pos: Vector3, size: Vector3, color: Color,
		emission := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh_instance(parent, mesh, pos, color, emission)


func _mesh_cylinder(parent: Node, pos: Vector3, radius: float, height: float,
		color: Color, emission := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius
	mesh.height = height
	return _mesh_instance(parent, mesh, pos, color, emission)


func _mesh_sphere(parent: Node, pos: Vector3, radius: float, color: Color,
		emission := 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _mesh_instance(parent, mesh, pos, color, emission)


func _mesh_cone(parent: Node, pos: Vector3, bottom_radius: float,
		top_radius: float, height: float, color: Color,
		emission := 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	return _mesh_instance(parent, mesh, pos, color, emission)


func _mesh_torus(parent: Node, pos: Vector3, inner: float, outer: float,
		color: Color, emission := 0.0, upright := true) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	var inst := _mesh_instance(parent, mesh, pos, color, emission)
	if upright:
		inst.rotate_x(deg_to_rad(90))
	return inst
