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
##
## Buses (res://default_bus_layout.tres): Master -> Music / Ambience / SFX.
## Nothing here writes to Master any more, which is the whole point: the
## settings screen owns Master, so its one slider still scales the entire mix
## while a future music or SFX slider can move its own bus underneath.
##   Ambience - the continuous beds: day/night room tone and the anomaly hum.
##   SFX      - one-shots, the alarm loop, and the Curator's own players (see
##              CuratorMonster, which routes to SFX by the same name).
##   Music    - reserved; no music stream ships yet.
## The Curator does NOT go through the pools below: it owns positional players
## so its footsteps cannot be stolen mid-step by a door or a pickup.

const AUDIO_DIR := "res://audio/"
const LOOPED := ["ambience_day", "ambience_night", "anomaly_hum", "alarm"]
const SFX_POOL_SIZE := 8

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_AMBIENCE := "Ambience"
const BUS_SFX := "SFX"

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
	_ensure_buses()
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "Ambience"
	_ambience.volume_db = -10.0
	_ambience.bus = BUS_AMBIENCE
	add_child(_ambience)
	_alarm = AudioStreamPlayer.new()
	_alarm.name = "Alarm"
	_alarm.volume_db = -9.0
	# The alarm loops like a bed but behaves like an event: it is the game
	# shouting at the operator, so it belongs with the SFX it competes against
	# rather than with the room tone a later duck is meant to pull down.
	_alarm.bus = BUS_SFX
	add_child(_alarm)
	_hum = AudioStreamPlayer3D.new()
	_hum.name = "Anomaly Hum"
	_hum.unit_size = 7.0
	_hum.max_db = -4.0
	_hum.bus = BUS_AMBIENCE
	add_child(_hum)
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFX %d" % i
		p.bus = BUS_SFX
		add_child(p)
		_pool.append(p)
	for i in range(4):
		var p3 := AudioStreamPlayer3D.new()
		p3.name = "SFX3D %d" % i
		p3.unit_size = 6.0
		p3.bus = BUS_SFX
		add_child(p3)
		_pool_3d.append(p3)
	set_ambience("day")


## Guarantee the three child buses exist before anything is routed to them.
##
## They normally arrive with res://default_bus_layout.tres, which the engine
## loads at startup from the default "audio/buses/default_bus_layout" setting.
## An export that dropped the resource, or a project.godot pointed elsewhere,
## would otherwise silently collapse every player back onto Master with an
## error per node, so rebuild the layout in code and say so once.
func _ensure_buses() -> void:
	for bus_name: String in [BUS_MUSIC, BUS_AMBIENCE, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, BUS_MASTER)
		push_warning("AudioManager: bus '%s' was missing from the layout - created at runtime" % bus_name)


## Set one bus's level from a 0..1 slider value, the way the settings screen
## already drives Master. Nothing calls this yet: per-bus sliders need new
## HUD strings, and localization/game.csv is frozen this round.
func set_bus_volume_linear(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_warning("AudioManager: no such bus '%s'" % bus_name)
		return
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))


func _stream(sound: String) -> AudioStream:
	if _streams.has(sound):
		return _streams[sound]
	var path := AUDIO_DIR + sound + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: missing %s" % path)
		_streams[sound] = null
		return null
	var stream: AudioStream = load(path)
	if sound in LOOPED:
		var wav := stream as AudioStreamWAV
		if wav != null:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			# loop_end counts audio FRAMES, not bytes. These wavs import with
			# compress/mode=2 (QOA), so data.size() is the size of the compressed
			# payload - about a fifth of the PCM size. Deriving frames from it
			# cut every loop short at ~20% of the sound. get_length() decodes the
			# real duration whatever the format, so go through that instead.
			wav.loop_end = roundi(wav.get_length() * wav.mix_rate)
		elif stream != null:
			# Only AudioStreamWAV exposes loop_begin / loop_end. Anything else
			# would play once and stop, so say so instead of failing quietly.
			push_warning("AudioManager: %s is %s, not AudioStreamWAV - not looped" % [path, stream.get_class()])
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
