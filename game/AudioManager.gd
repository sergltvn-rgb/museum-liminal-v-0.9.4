extends Node
## Audio hub for the museum night shift. All sounds are small procedural
## WAV files in res://audio/ (generated offline, CC0 - made for this game).
##
## Install: add a plain Node to the main scene and attach this script.
## Other scripts reach it through the "audio_manager" group:
##   var am = get_tree().get_first_node_in_group("audio_manager")
##   if am != null: am.play_sfx("pickup")
##
## Sounds: ambience_day, ambience_night, anomaly_hum, alarm (loops);
## blackout, footstep1..3, land, pickup, drop, terminal_beep, tablet_click,
## tablet_open, resolve, fail, menu_move, menu_select (one-shots).

const AUDIO_DIR := "res://audio/"
const LOOPED := ["ambience_day", "ambience_night", "anomaly_hum", "alarm"]
const SFX_POOL_SIZE := 8

var _streams: Dictionary = {}
var _ambience: AudioStreamPlayer
var _alarm: AudioStreamPlayer
var _hum: AudioStreamPlayer3D
var _pool: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_index := 0
var _pool_3d_index := 0
var _ambience_name := ""


func _ready() -> void:
	add_to_group("audio_manager")
	# Keep ambience alive on the pause / main menu screens.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "Ambience"
	_ambience.volume_db = -10.0
	add_child(_ambience)
	_alarm = AudioStreamPlayer.new()
	_alarm.name = "Alarm"
	_alarm.volume_db = -9.0
	add_child(_alarm)
	_hum = AudioStreamPlayer3D.new()
	_hum.name = "Anomaly Hum"
	_hum.unit_size = 7.0
	_hum.max_db = -4.0
	add_child(_hum)
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFX %d" % i
		add_child(p)
		_pool.append(p)
	for i in range(4):
		var p3 := AudioStreamPlayer3D.new()
		p3.name = "SFX3D %d" % i
		p3.unit_size = 6.0
		add_child(p3)
		_pool_3d.append(p3)
	set_ambience("day")


func _stream(sound: String) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound]
	var path := AUDIO_DIR + sound + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: missing %s" % path)
		_streams[sound] = null
		return null
	var stream: AudioStream = load(path)
	var wav := stream as AudioStreamWAV
	if wav != null and sound in LOOPED:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		# 16-bit mono PCM: two bytes per frame.
		wav.loop_end = int(wav.data.size() / 2.0)
	_streams[sound] = stream
	return stream


func play_sfx(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var stream := _stream(sound)
	if stream == null:
		return
	var p := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_at(sound: String, world_position: Vector3, volume_db := 0.0) -> void:
	var stream := _stream(sound)
	if stream == null:
		return
	var p := _pool_3d[_pool_3d_index]
	_pool_3d_index = (_pool_3d_index + 1) % _pool_3d.size()
	p.global_position = world_position
	p.stream = stream
	p.volume_db = volume_db
	p.play()


func footstep(running := false) -> void:
	var volume := -13.0 if running else -16.0
	play_sfx("footstep%d" % (randi() % 3 + 1), volume, randf_range(0.9, 1.1))


func set_ambience(kind: String) -> void:
	# kind: "day", "night" or "" (silence).
	if kind == _ambience_name:
		return
	_ambience_name = kind
	if kind == "":
		_ambience.stop()
		return
	var stream := _stream("ambience_%s" % kind)
	if stream == null:
		_ambience.stop()
		return
	_ambience.stream = stream
	_ambience.play()


func set_alarm(on: bool) -> void:
	if on:
		if _alarm.playing:
			return
		_alarm.stream = _stream("alarm")
		if _alarm.stream != null:
			_alarm.play()
	else:
		_alarm.stop()


func set_anomaly_hum(on: bool, world_position := Vector3.ZERO) -> void:
	if on:
		_hum.global_position = world_position
		_hum.stream = _stream("anomaly_hum")
		if _hum.stream != null and not _hum.playing:
			_hum.play()
	else:
		_hum.stop()
