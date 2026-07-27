extends Node
## Audio hub for the museum night shift.
##
## res://audio/*.wav are small procedural files generated offline, CC0, made for
## this game. res://audio/generated/*.mp3 are NOT: they came out of the
## ElevenLabs sound-generation API on a free plan, which forbids commercial use
## and requires attribution. They are in the build as prototype audio, knowingly,
## and they are not cleared for release. Anything that ships has to replace them
## or licence them first.
##
## Install: add a plain Node to the main scene and attach this script.
## Other scripts reach it through the "audio_manager" group:
##   var am = get_tree().get_first_node_in_group("audio_manager")
##   if am != null: am.play_sfx("pickup")
##
## Sounds: ambience_day, ambience_night, anomaly_hum, alarm (loops);
## blackout, footstep1..3, land, pickup, drop, terminal_beep, tablet_click,
## tablet_open, resolve, fail, menu_move, menu_select (one-shots).
## Music: set_music_active(bool) and set_tension(0..1) - see the music block
## below. Do not put a capitalised word in quotes anywhere in res://game unless
## it really is a translation key: test_map_verification's localization sweep
## matches "([A-Z][A-Z0-9_]{3,})" and will demand a game.csv row for it.
##
## Buses (res://default_bus_layout.tres): Master -> Music / Ambience / SFX.
## Nothing here writes to Master any more, which is the whole point: the
## settings screen owns Master, so its one slider still scales the entire mix
## while a future music or SFX slider can move its own bus underneath.
##   Ambience - the continuous beds: day/night room tone and the anomaly hum.
##   SFX      - one-shots, the alarm loop, and the Curator's own players (see
##              CuratorMonster, which routes to SFX by the same name).
##   Music    - two looping layers, see the music block below.
## The Curator does NOT go through the pools below: it owns positional players
## so its footsteps cannot be stolen mid-step by a door or a pickup.

const AUDIO_DIR := "res://audio/"
const LOOPED := ["ambience_day", "ambience_night", "anomaly_hum", "alarm"]
const SFX_POOL_SIZE := 8

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_AMBIENCE := "Ambience"
const BUS_SFX := "SFX"

# ---------------------------------------------------------------- MUSIC ----
# Two layers that always run together and are mixed by one number.
#
#   bed_museum_night  the building itself: flat, wide, no events. Always on
#                     while a night runs.
#   tension_curator   the dread layer. Same 22.00 s length, faded in on top of
#                     the bed as set_tension() rises.
#
# They live in res://audio/generated/ rather than next to the wavs, because they
# were generated on a FREE ElevenLabs plan (no commercial use, attribution
# required) and the folder keeps that visible in the tree. This is prototype
# audio; nothing here has been cleared for release. Moving them was safe only
# because _stream() below builds its paths by pattern (AUDIO_DIR + name +
# ".wav") and no music ever goes through it -- the two paths here are literal
# and complete, so the subfolder cannot silently break an existing sound.
const MUSIC_DIR := "res://audio/generated/"
const MUSIC_BED_PATH := MUSIC_DIR + "music_bed_night.mp3"
const MUSIC_TENSION_PATH := MUSIC_DIR + "music_tension.mp3"

## Levels, measured off the decoded files rather than guessed.
##
## Reference: ambience_night.wav is -13.5 dBFS RMS and plays at -10 dB, so the
## night room tone sits at about -23.5 dBFS RMS. Everything below is placed
## against that.
##
## bed_museum_night decodes at -36.2 dBFS RMS (peak -24.6), which is very quiet
## material, so it needs gain rather than trim: +5 dB puts it at -31.2 dBFS RMS,
## roughly 8 dB under the room tone. That is the point - the bed is the floor
## the night stands on, felt and not heard, and it must never compete with the
## room tone the player uses to read the building. Peak lands at -19.6 dBFS.
const MUSIC_BED_DB := -17.0
## tension_curator decodes at -19.1 dBFS RMS overall, but it is a swell: its
## loudest second is -11.8 dBFS RMS and its tail is -62. -10 dB puts that
## loudest second at -21.8 dBFS RMS at full tension, about 2 dB OVER the room
## tone - at maximum dread this layer is meant to be the loudest continuous
## thing in the mix, since by then the Curator is within a few metres. Peak
## lands at -15.4 dBFS, so it never crowds the catch stinger.
const MUSIC_TENSION_DB := -7.0
## Below this the layer is treated as off. -60 dB is inaudible under any bed but
## still a real number, so no branch has to special-case -INF.
const MUSIC_SILENCE_DB := -60.0

## Loop crossfade, in seconds. See _advance_layer(): each layer owns two players
## and hands over between them instead of relying on the stream's own loop.
##
## The stream loop flag IS set (audio/generated/*.mp3.import carries loop=true)
## and that is what CuratorMonster's breath uses. It is not enough here.
## Decoding bed_museum_night and butt-splicing its end to its start leaves a
## -44 dBFS transient at the seam - 21 dB above that material's own high
## frequency floor, on a bed whose spectral centroid is 191 Hz. That is exactly
## the tick every 22 seconds that is worse than no music at all. tension_curator
## does not have the problem (it fades to -62 dBFS at both ends, seam artefact
## +4.7 dB, inaudible), but it runs through the same path so there is one code
## path to reason about rather than two.
##
## One second: long enough that the splice is inaudible on a stationary hum,
## short enough that the tension swell keeps its shape. The effective loop
## period becomes 22.0 - 1.0 = 21.0 s for both layers, so they stay locked to
## each other.
const MUSIC_XFADE := 1.0

## Time constants for the first-order lag on the two music controls, in seconds.
## A first-order lag covers 63 % of a step in one time constant and 95 % in
## three, and it can never jump: whatever the frame time, the response is
## continuous. exp(-delta / tau) makes that framerate independent.
##
## Dread rises faster than it falls, which is the whole point. RISE 0.9 s means
## the tension layer is most of the way up 2.7 s after the Curator commits -
## it closes 26 m to 3 m at 5.6-6.3 m/s, so about 3.7 s, and the music must not
## lag the thing it is describing. FALL 3.5 s means it takes about 10 s to
## drain after the player breaks away, so relief is earned rather than granted
## the instant a door shuts.
const MUSIC_TENSION_RISE_TAU := 0.9
const MUSIC_TENSION_FALL_TAU := 3.5
## Whole-music fade for set_music_active(). 1.2 s: a night starts and ends with
## the bed sliding in or out, never with a cut.
const MUSIC_FADE_TAU := 1.2

var _streams: Dictionary = {}
var _ambience: AudioStreamPlayer
var _alarm: AudioStreamPlayer
var _hum: AudioStreamPlayer3D
var _pool: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_index := 0
var _pool_3d_index := 0
var _ambience_name := ""

var _bed_players: Array[AudioStreamPlayer] = []
var _tension_players: Array[AudioStreamPlayer] = []
var _bed_active := 0
var _tension_active := 0
## Shared length of the two layers, 0.0 when music failed to load. Doubles as
## the "is there music at all" flag so _process() can leave immediately.
var _music_length := 0.0
var _music_on := false
var _music_gain := 0.0
var _tension_target := 0.0
var _tension := 0.0


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
	_build_music()
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


## Load the two layers and give each one a pair of players to hand over between.
func _build_music() -> void:
	var bed := _music_stream(MUSIC_BED_PATH)
	var tension := _music_stream(MUSIC_TENSION_PATH)
	if bed == null or tension == null:
		push_warning("AudioManager: music layers missing - the Music bus stays silent")
		return
	var bed_length := bed.get_length()
	var tension_length := tension.get_length()
	if absf(bed_length - tension_length) > 0.05:
		# They are supposed to be the same take length. If they ever diverge the
		# shorter one decides, so both layers keep looping in step instead of
		# drifting apart over a night.
		push_warning("AudioManager: music layers differ in length (%.2f s vs %.2f s)"
			% [bed_length, tension_length])
	var length := minf(bed_length, tension_length)
	if length <= MUSIC_XFADE * 2.0:
		push_warning("AudioManager: music layers are %.2f s, too short to crossfade" % length)
		return
	_music_length = length
	_bed_players = _make_music_players("Music Bed", bed)
	_tension_players = _make_music_players("Music Tension", tension)


## Load one music layer with looping turned OFF on the instance we play.
##
## The imported resource loops (see the .import files) and that is correct for
## anything that just wants a looping stream. This node does not: _advance_layer()
## crossfades between two players to hide the seam, which needs each playback to
## run off the end and stop. duplicate() keeps the mutation off the cached
## resource so a future consumer still gets a looping stream.
func _music_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: missing %s" % path)
		return null
	var source := load(path) as AudioStream
	if source == null:
		return null
	var stream := source.duplicate() as AudioStream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	else:
		push_warning("AudioManager: %s is %s, not AudioStreamMP3" % [path, stream.get_class()])
	return stream


func _make_music_players(base_name: String, stream: AudioStream) -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for i in range(2):
		var p := AudioStreamPlayer.new()
		p.name = "%s %d" % [base_name, i]
		p.bus = BUS_MUSIC
		# Both players share one stream resource on purpose: an AudioStreamPlayer
		# owns its playback position, not the stream, so two of them can be at
		# different points in the same 22 seconds.
		p.stream = stream
		p.volume_db = MUSIC_SILENCE_DB
		add_child(p)
		players.append(p)
	return players


## Start or stop the music as a whole. Both layers fade together over
## MUSIC_FADE_TAU; nothing here ever cuts.
func set_music_active(active: bool) -> void:
	if _music_on == active:
		return
	_music_on = active
	if not active:
		# A night that has ended has no tension. Leaving the target high would
		# mean the next night opened part-way up the dread curve.
		_tension_target = 0.0


## 0.0 calm .. 1.0 the Curator is on you. Smoothed in _process(), never applied
## directly: a step in music level reads as a bug, not as a scare.
##
## At 0 the layer is held at MUSIC_SILENCE_DB rather than stopped. Stopping it
## would cost nothing to start again, but it would restart from the top of the
## take and the swell would no longer line up with the bed underneath it - so it
## keeps running silently and the two layers stay locked together all night.
func set_tension(level: float) -> void:
	_tension_target = clampf(level, 0.0, 1.0)


## Current smoothed tension, for anything that wants to follow the music.
func get_tension() -> float:
	return _tension


func _process(delta: float) -> void:
	if _music_length <= 0.0:
		return
	_music_gain = _approach(_music_gain, 1.0 if _music_on else 0.0, MUSIC_FADE_TAU, delta)
	var tau := MUSIC_TENSION_RISE_TAU if _tension_target > _tension else MUSIC_TENSION_FALL_TAU
	_tension = _approach(_tension, _tension_target, tau, delta)
	if not _music_on and _music_gain <= 0.001:
		_music_gain = 0.0
		for p in _bed_players:
			p.stop()
		for p in _tension_players:
			p.stop()
		return
	_bed_active = _advance_layer(_bed_players, _bed_active, MUSIC_BED_DB, _music_gain)
	_tension_active = _advance_layer(_tension_players, _tension_active, MUSIC_TENSION_DB,
		_music_gain * _tension)


## Framerate-independent first-order lag. Reaches 63 % of a step in `tau`
## seconds and 95 % in three, and cannot overshoot or jump whatever `delta` is -
## which a naive lerp(current, target, rate * delta) does the moment a frame
## runs long enough for rate * delta to pass 1.0.
func _approach(current: float, target: float, tau: float, delta: float) -> float:
	if tau <= 0.0:
		return target
	return target + (current - target) * exp(-delta / tau)


## Run one layer for a frame: hand over to its other player near the end of the
## take, then set both players' levels. Returns the new active index.
func _advance_layer(players: Array[AudioStreamPlayer], active: int, base_db: float,
		linear: float) -> int:
	if players.size() < 2:
		return active
	var current := players[active]
	if not current.playing:
		# Either the music has just been switched on, or a frame ran longer than
		# MUSIC_XFADE and the take ran off its end before the handover fired.
		# Restarting is better than a layer that stays silent for the rest of the
		# night; it restarts from zero, so the fade-in below still applies and it
		# does not click back in.
		current.play()
	var position := current.get_playback_position()
	if position >= _music_length - MUSIC_XFADE:
		var other := players[1 - active]
		if not other.playing:
			# Start it at however far past the handover point this frame landed,
			# not at zero. A frame boundary never falls exactly on the splice, so
			# play() from the top leaves the two players non-complementary by up
			# to one frame - measured, that is a 0.5 dB sag in the summed power
			# at a 46 ms overshoot. Starting from the overshoot makes the pair
			# exactly complementary whatever the frame time: measured across the
			# splice, the summed power then holds to within 0.04 dB.
			other.play(position - (_music_length - MUSIC_XFADE))
			active = 1 - active
	for p in players:
		if not p.playing:
			continue
		p.volume_db = _music_db(base_db, linear * _crossfade_gain(p.get_playback_position()))
	return active


## Equal-power window over one take: up over the first MUSIC_XFADE seconds, down
## over the last. Two players offset by exactly the take length minus the
## crossfade give sin(x)^2 + cos(x)^2 = 1, so the summed power is flat across
## the splice and a stationary hum shows no seam at all.
func _crossfade_gain(position: float) -> float:
	var t := clampf(minf(position, _music_length - position) / MUSIC_XFADE, 0.0, 1.0)
	return sin(t * PI * 0.5)


func _music_db(base_db: float, linear: float) -> float:
	if linear <= 0.001:
		return MUSIC_SILENCE_DB
	return maxf(base_db + linear_to_db(minf(linear, 1.0)), MUSIC_SILENCE_DB)


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
	#
	# The music rides on this rather than on a call of its own. "night" is set in
	# exactly one place - FirstMuseumMap._trigger_blackout() - and that blackout
	# IS the start of the shift, so the bed comes up with the darkness and goes
	# away with it. set_music_active() stays public for anything that wants to
	# override that; this is only the default wiring, and it costs the rest of
	# the codebase nothing to learn.
	set_music_active(kind == "night")
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
