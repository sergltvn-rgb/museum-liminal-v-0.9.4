extends Node
## Full pocket-world mechanics: rotated gravity, recorded time echoes,
## movable radiation resonators and flashlight-dependent solid geometry.

const ORIGIN := Vector3(0, 72, -260)
const USE_DISTANCE := 2.8
const LOOP_DURATION := 18.0
const TRIAL_SCENES := {
	"gravity_surge": preload("res://scenes/trials/GravityArchiveTrial.tscn"),
	"temporal_drift": preload("res://scenes/trials/MissingMinuteTrial.tscn"),
	"radiation_bloom": preload("res://scenes/trials/CriticalMassTrial.tscn"),
	"void_rift": preload("res://scenes/trials/NegativeSpaceTrial.tscn"),
	"echo_chamber": preload("res://scenes/trials/EchoChamberTrial.tscn"),
	"glass_bridge": preload("res://scenes/trials/GlassBridgeTrial.tscn"),
	"mirror_maze": preload("res://scenes/trials/MirrorMazeTrial.tscn"),
	"yellow_halls": preload("res://scenes/trials/YellowHallsTrial.tscn"),
	"scrap_run": preload("res://scenes/trials/ScrapRunTrial.tscn"),
	"ascent": preload("res://scenes/trials/AscentTrial.tscn"),
}
const TrialRegistry := preload("res://game/trials/RiftTrialRegistry.gd")
var _game: Node
var _player: CharacterBody3D
var _world: Node3D
var _active := false
var _kind := ""
var _saved := Transform3D.IDENTITY
var _layer: CanvasLayer
var _title: Label
var _status: Label
var _active_trial: RiftTrial
var last_fail_reason := ""
var last_fail_detail := ""
var _targets: Array[StaticBody3D] = []
var _step := 0

# Time-loop state.
var _loop_time := 0.0
var _sample_time := 0.0
var _recording: Array[Transform3D] = []
var _echo_recordings: Array = []
var _echoes: Array[Node3D] = []
var _plates: Array[Vector3] = []

# Radiation state.
var _monoliths: Array[StaticBody3D] = []
var _sockets: Array[Vector3] = []
var _socket_occupants := [-1, -1, -1, -1, -1, -1]
var _monolith_socket := [0, 1, 2, 3]
var _frequencies := [0, 0, 0, 0]
var _target_sockets := [4, 1, 5, 2]
var _target_frequencies := [2, 0, 3, 1]
var _carried_monolith := -1
var _carried_from_socket := -1
var _dose := 0.0

# Negative-space state.
var _light_bridges: Array[StaticBody3D] = []
var _bridge_requires_light: Array[bool] = []
var _checkpoints: Array[Vector3] = []
var _checkpoint := 0
var _void_monster:CharacterBody3D
var _void_exit:=Vector3.ZERO
var _void_nodes:Array[Node3D]=[]
var _void_activated:=0
var _lidar_multimesh:MultiMesh
var _lidar_index:=0
const LIDAR_CAPACITY:=4200
const LIDAR_RAYS_PER_SCAN:=240
# Эхо-камера
var _echo_sequence:Array[int]=[]
var _echo_input:=0
var _echo_round:=0
var _echo_show_timer:=0.0
var _echo_show_index:=-1
var _echo_showing:=false
var _echo_pads:Array[StaticBody3D]=[]
const ECHO_COLORS:Array[Color]=[Color(.95,.3,.25),Color(.3,.75,.95),Color(.35,.9,.4),Color(.95,.8,.3)]
# Зыбкий мост
var _bridge_tiles:Array[StaticBody3D]=[]
var _bridge_fake:Array[bool]=[]
var _bridge_done:Array[bool]=[]
# Фаза осмотра и вспышки эхо-камеры
var _echo_look:=0.0
var _echo_glow_on:=false
# Зал отражений
var _mirror_frames:Array[StaticBody3D]=[]
var _mirror_defective:Array[int]=[]
var _mirror_found:=0
var _mirror_time:=0.0
# Жёлтые залы (Backrooms)
var _tapes_found:=0
# Служба извлечения (R.E.P.O. / Lethal Company)
var _scrap_items:Array[StaticBody3D]=[]
var _scrap_home:Array[Vector3]=[]
var _scrap_carrying:=-1
var _scrap_delivered:=0
# Восхождение (PEAK)
var _fog_plane:MeshInstance3D
var _fog_y:=0.0
# Доработка измерений (0.9.4)
var _mirror_errors:=0
var _mirror_ghosts:Array[MeshInstance3D]=[]
var _yellow_tapes:Array[StaticBody3D]=[]
var _yellow_walker:CharacterBody3D=null
var _yellow_points:Array[Vector3]=[]
var _yellow_point:=0
var _yellow_cool:=0.0
var _scrap_drone:Node3D=null
var _drone_angle:=0.0
var _scrap_value:=0
var _carry_visual:MeshInstance3D=null
var _ascent_checkpoint:=Vector3.ZERO
var _ascent_movers:Array[StaticBody3D]=[]
var _ascent_mover_base:Array[Vector3]=[]
var _ascent_cps:Array[Vector3]=[]
var _ascent_time:=0.0

func _ready() -> void:
	add_to_group("rift_trial_manager")
	_build_hud()

func setup(game: Node) -> void: _game = game
func is_active() -> bool: return _active

func begin(kind: String, player: CharacterBody3D) -> void:
	if _active or player == null: return
	_active = true; _kind = kind; _player = player; _saved = player.global_transform; _step = 0
	last_fail_reason = ""; last_fail_detail = ""
	var trial_scene: PackedScene = TRIAL_SCENES.get(kind, TRIAL_SCENES["void_rift"])
	_active_trial = trial_scene.instantiate() as RiftTrial
	add_child(_active_trial)
	_player.controls_enabled = false
	_build_world()
	await get_tree().physics_frame
	if not _active or not is_instance_valid(_player): return
	_player.velocity = Vector3.ZERO
	_player.global_position = _spawn_position()
	_player.rotation_degrees = Vector3.ZERO
	_player.reset_gravity_direction()
	_player.controls_enabled = true
	_layer.visible = true

func abort() -> void:
	if not _active: return
	_return_player(); _cleanup()

func _input(event: InputEvent) -> void:
	if not _active: return
	if event.is_action_pressed("interact"):
		if is_instance_valid(_active_trial): _active_trial.interact(self)
		else: _interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("drop_item") or event.is_action_pressed("radar_scan"):
		var action: StringName = &"drop_item" if event.is_action_pressed("drop_item") else &"radar_scan"
		if _secondary_action_legacy(_kind, action): get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _active or not is_instance_valid(_player):
		return
	if is_instance_valid(_active_trial): _active_trial.process_trial(self, delta)
	else: _process_trial_legacy(_kind, delta)
	if not _active or not is_instance_valid(_player):
		return
	if _player.global_position.y < ORIGIN.y - 14.0:
		_reset_after_fall()

func _process_trial_legacy(kind: String, delta: float) -> void:
	match kind:
		"temporal_drift": _update_time_loop(delta)
		"radiation_bloom": _update_radiation(delta)
		"void_rift": _update_negative_space(delta)
		"echo_chamber": _update_echo(delta)
		"glass_bridge": _update_glass_bridge()
		"mirror_maze": _update_mirrors(delta)
		"yellow_halls": _update_yellow(delta)
		"scrap_run": _update_scrap(delta)
		"ascent": _update_ascent(delta)

func _interact_trial_legacy() -> void:
	_interact()

func _secondary_action_legacy(kind: String, action: StringName) -> bool:
	if kind == "radiation_bloom" and action == &"drop_item":
		_tune_nearest(); return true
	if kind == "void_rift" and action == &"radar_scan":
		_lidar_scan(); return true
	return false

func trial_definition() -> Dictionary:
	return TrialRegistry.find(_kind)

func trial_fail_tip() -> String:
	return TrialRegistry.fail_tip_for(_kind, TranslationServer.get_locale().begins_with("en"))

func _build_world() -> void:
	_world = Node3D.new(); _world.name = "Pocket Dimension — %s" % _kind
	get_tree().current_scene.add_child(_world)
	if is_instance_valid(_active_trial): _active_trial.build(self)
	else: _build_trial_legacy(_kind)
	_add_bounds()
	if _kind in ["void_rift", "scrap_run", "yellow_halls"]:
		return
	for i in range(12):
		var lamp := OmniLight3D.new(); var a := TAU * float(i) / 12.0
		lamp.position = ORIGIN + Vector3(cos(a)*15, 4+i%3, sin(a)*15-5)
		lamp.light_color = Color(.32,.44,.72); lamp.light_energy=.35; lamp.omni_range=9; _world.add_child(lamp)

func _build_trial_legacy(kind: String) -> void:
	match kind:
		"gravity_surge": _build_gravity_archive()
		"temporal_drift": _build_missing_minute()
		"radiation_bloom": _build_critical_mass()
		"echo_chamber": _build_echo_chamber()
		"glass_bridge": _build_glass_bridge()
		"mirror_maze": _build_mirror_maze()
		"yellow_halls": _build_yellow_halls()
		"scrap_run": _build_scrap_run()
		"ascent": _build_ascent()
		_: _build_negative_space()

func _spawn_position() -> Vector3:
	return ORIGIN + Vector3(0, 1.2, 8)

# --- Gravity Archive -------------------------------------------------------
func _build_gravity_archive() -> void:
	_title.text=tr("TRIAL_GRAVITY_TITLE")
	_status.text=tr("TRIAL_GRAVITY_OBJECTIVE")
	_box("Floor", ORIGIN+Vector3(0,0,-3), Vector3(20,.6,24), Color(.12,.08,.2))
	_box("West Wall",ORIGIN+Vector3(-10,6,-3),Vector3(.6,12,24),Color(.1,.07,.18))
	_box("East Wall",ORIGIN+Vector3(10,6,-3),Vector3(.6,12,24),Color(.1,.07,.18))
	_box("Far Wall",ORIGIN+Vector3(0,6,-15),Vector3(20,12,.6),Color(.1,.07,.18))
	_box("Ceiling",ORIGIN+Vector3(0,12,-3),Vector3(20,.6,24),Color(.07,.05,.13))
	for p in [Vector3(-5,1,-1),Vector3(3,1,-6),Vector3(-2,1,-11)]: _box("Archive Shelf",ORIGIN+p,Vector3(2,2,1),Color(.19,.14,.24))
	_anchor(0,ORIGIN+Vector3(0,1,-1),tr("TRIAL_PROP_ANCHOR_FLOOR"))
	_anchor(1,ORIGIN+Vector3(-9.1,4,-6),tr("TRIAL_PROP_ANCHOR_WALL"))
	_anchor(2,ORIGIN+Vector3(0,5,-14.1),tr("TRIAL_PROP_ANCHOR_DEPTH"))

func _anchor(index:int,pos:Vector3,text:String)->void:
	var body:=_target(index,pos,Color(.68,.3,1),text); body.set_meta("type","gravity_anchor")

func _gravity_anchor(index:int)->void:
	if index != _step: _status.text=tr("TRIAL_GRAVITY_ANCHOR_LOCKED"); return
	_mark(_targets[index]); _step+=1
	if _step==1:
		_player.set_gravity_direction(Vector3.LEFT); _status.text=tr("TRIAL_GRAVITY_STEP1")
	elif _step==2:
		_player.set_gravity_direction(Vector3.FORWARD); _status.text=tr("TRIAL_GRAVITY_STEP2")
	else: _complete()

# --- The Missing Minute ----------------------------------------------------
func _build_missing_minute() -> void:
	_title.text=tr("TRIAL_TIME_TITLE"); _status.text=tr("TRIAL_TIME_OBJECTIVE")
	_box("Loop Floor",ORIGIN+Vector3(0,0,-4),Vector3(22,.6,26),Color(.2,.13,.06))
	_plates=[ORIGIN+Vector3(-7,.35,-6),ORIGIN+Vector3(0,.35,-11),ORIGIN+Vector3(7,.35,-6)]
	for i in range(3):
		var plate:=_box("Temporal Plate %d"%(i+1),_plates[i],Vector3(2.4,.25,2.4),Color(.65,.35,.08)); plate.set_meta("plate",i)
	_loop_time=0.; _sample_time=0.; _recording.clear(); _echo_recordings.clear(); _echoes.clear()

func _update_time_loop(delta:float)->void:
	if not is_instance_valid(_player): return
	_loop_time+=delta; _sample_time+=delta
	if _sample_time>=.1:
		_sample_time=0.; _recording.append(_player.global_transform)
	for i in range(_echoes.size()):
		var rec:Array=_echo_recordings[i]
		if not rec.is_empty(): _echoes[i].global_transform=rec[mini(int(_loop_time/.1),rec.size()-1)]
	var occupied := [false,false,false]
	for i in range(3):
		if _player.global_position.distance_to(_plates[i])<1.45: occupied[i]=true
		for echo in _echoes:
			if echo.global_position.distance_to(_plates[i])<1.45: occupied[i]=true
	if occupied[0] and occupied[1] and occupied[2]: _complete(); return
	_status.text=tr("TRIAL_TIME_HUD")%[maxf(0.,LOOP_DURATION-_loop_time),_echoes.size(),str(occupied)]
	if _loop_time>=LOOP_DURATION: _finish_loop()

func _finish_loop()->void:
	if _echo_recordings.size()>=2:
		_echo_recordings.pop_front()
		var old: Node3D = _echoes.pop_front() as Node3D
		if old != null:
			old.queue_free()
	_echo_recordings.append(_recording.duplicate())
	var ghost:=_make_echo(); _echoes.append(ghost)
	_loop_time=0.; _recording.clear(); _player.velocity=Vector3.ZERO; _player.global_position=_spawn_position()

func _make_echo()->Node3D:
	var ghost:=Node3D.new(); ghost.name="Recorded Operator Echo"; _world.add_child(ghost)
	var mesh:=MeshInstance3D.new(); var capsule:=CapsuleMesh.new(); capsule.radius=.34; capsule.height=1.8; mesh.mesh=capsule
	var mat:=StandardMaterial3D.new(); mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; mat.albedo_color=Color(.25,.75,1,.38); mat.emission_enabled=true; mat.emission=Color(.2,.55,1); mesh.material_override=mat; mesh.position.y=.9; ghost.add_child(mesh)
	return ghost

# --- Critical Mass Choir ---------------------------------------------------
func _build_critical_mass() -> void:
	_title.text=tr("TRIAL_RADIATION_TITLE")
	_status.text=tr("TRIAL_RADIATION_OBJECTIVE")
	_box("Choir Floor",ORIGIN+Vector3(0,0,-4),Vector3(22,.6,24),Color(.04,.16,.07))
	_sockets=[ORIGIN+Vector3(-7,.4,1),ORIGIN+Vector3(0,.4,1),ORIGIN+Vector3(7,.4,1),ORIGIN+Vector3(-7,.4,-9),ORIGIN+Vector3(0,.4,-9),ORIGIN+Vector3(7,.4,-9)]
	_socket_occupants=[0,1,2,3,-1,-1]; _monolith_socket=[0,1,2,3]; _frequencies=[0,0,0,0]; _carried_monolith=-1; _carried_from_socket=-1; _dose=0.; _monoliths.clear()
	var symbols := ["▲", "●", "◆", "■"]
	for i in range(6):
		var socket_text := tr("TRIAL_PROP_SOCKET_SPARE")
		for monolith_index in range(4):
			if _target_sockets[monolith_index] == i:
				socket_text = tr("TRIAL_PROP_SOCKET") % symbols[monolith_index]
		var s:=_target(i,_sockets[i],Color(.15,.5,.2),socket_text); s.set_meta("type","socket")
	for i in range(4):
		var text := tr("TRIAL_PROP_MONOLITH_INIT") % [symbols[i], _target_frequencies[i]]
		var m:=_target(i,_sockets[i]+Vector3(0,1,0),Color(.25,1,.35),text); m.set_meta("type","monolith"); _monoliths.append(m)

func _radiation_interact(body:StaticBody3D)->void:
	var type:=str(body.get_meta("type","")); var index:=int(body.get_meta("index",-1))
	if type=="monolith" and _carried_monolith<0:
		_carried_monolith=index; _carried_from_socket=int(_monolith_socket[index]); _socket_occupants[_carried_from_socket]=-1
		body.visible=false; body.collision_layer=0
	elif type=="socket" and _carried_monolith>=0:
		# Placing onto an occupied socket swaps the displaced monolith back to
		# the source socket, so the puzzle never gets stuck behind empty-slot logic.
		var displaced := int(_socket_occupants[index])
		if displaced >= 0:
			_monoliths[displaced].global_position=_sockets[_carried_from_socket]+Vector3(0,1,0)
			_monolith_socket[displaced]=_carried_from_socket
			_socket_occupants[_carried_from_socket]=displaced
		var m:=_monoliths[_carried_monolith]; m.global_position=_sockets[index]+Vector3(0,1,0); m.visible=true; m.collision_layer=1
		_socket_occupants[index]=_carried_monolith; _monolith_socket[_carried_monolith]=index; _carried_monolith=-1; _carried_from_socket=-1; _check_radiation_solution()

func _tune_nearest()->void:
	var body:=_nearest_target("monolith")
	if body==null: _status.text=tr("TRIAL_RADIATION_NEAR_MONOLITH"); return
	var i:=int(body.get_meta("index",-1)); _frequencies[i]=(int(_frequencies[i])+1)%4
	var symbols := ["▲", "●", "◆", "■"]
	var feedback := tr("TRIAL_RADIATION_RESONANCE") if _frequencies[i] == _target_frequencies[i] else tr("TRIAL_RADIATION_NEED") % _target_frequencies[i]
	_find_label(body).text=tr("TRIAL_PROP_MONOLITH")%[symbols[i],_frequencies[i],feedback]; _check_radiation_solution()

func _update_radiation(delta:float)->void:
	if not is_instance_valid(_player): return
	var errors:=0
	for i in range(4):
		if _monolith_socket[i]!=_target_sockets[i]: errors+=1
		if _frequencies[i]!=_target_frequencies[i]: errors+=1
	_dose=clampf(_dose+(float(errors)*.22-.8)*delta,0.,100.)
	var placed := 0; var tuned := 0
	for i in range(4):
		if _monolith_socket[i] == _target_sockets[i]: placed += 1
		if _frequencies[i] == _target_frequencies[i]: tuned += 1
	var action := tr("TRIAL_RADIATION_ACT_PLACE") if _carried_monolith >= 0 else tr("TRIAL_RADIATION_ACT_PICK")
	_status.text=tr("TRIAL_RADIATION_HUD")%[action,placed,tuned,_dose]
	if _dose>=100.: _reset_radiation()

func _check_radiation_solution()->void:
	if _monolith_socket==_target_sockets and _frequencies==_target_frequencies: _complete()

func _reset_radiation()->void:
	_dose=25.; _carried_monolith=-1; _carried_from_socket=-1; _socket_occupants=[0,1,2,3,-1,-1]; _monolith_socket=[0,1,2,3]; _frequencies=[0,0,0,0]
	for i in range(4): _monoliths[i].global_position=_sockets[i]+Vector3(0,1,0); _monoliths[i].visible=true; _monoliths[i].collision_layer=1
	_status.text=tr("TRIAL_RADIATION_RESET")

# --- Negative Space --------------------------------------------------------
func _build_negative_space()->void:
	_title.text=tr("TRIAL_VOID_TITLE");_status.text=tr("TRIAL_VOID_OBJECTIVE")
	_box("Пол сектора",ORIGIN+Vector3(0,0,-8),Vector3(30,.6,36),Color(.008,.012,.018))
	var walls:Array=[ [Vector3(-8,15,1),Vector3(.6,30,12)],[Vector3(7,15,-1),Vector3(.6,30,10)],[Vector3(-2,15,-6),Vector3(12,30,.6)],[Vector3(4,15,-13),Vector3(14,30,.6)],[Vector3(-9,15,-18),Vector3(12,30,.6)],[Vector3(10,15,-20),Vector3(.6,30,12)],[Vector3(-15,24,-8),Vector3(.8,48,36.8)],[Vector3(15,24,-8),Vector3(.8,48,36.8)],[Vector3(0,24,10),Vector3(30.8,48,.8)],[Vector3(0,24,-26),Vector3(30.8,48,.8)] ]
	for i in range(walls.size()):_box("Стена %d"%i,ORIGIN+(walls[i][0] as Vector3),walls[i][1] as Vector3,Color(.025,.035,.05))
	_checkpoints=[_spawn_position()];_checkpoint=0;_void_exit=ORIGIN+Vector3(11,1,-24);_void_nodes.clear();_void_activated=0
	var positions:Array[Vector3]=[Vector3(-10,1,-3),Vector3(10,1,-10),Vector3(-7,1,-22)]
	for i in range(3):
		var node:StaticBody3D=_target(i,ORIGIN+positions[i],Color(.25,.75,1),tr("TRIAL_PROP_POWER_NODE")%(i+1))
		node.set_meta("type","radar_node");_void_nodes.append(node)
	var exit_node:=_target(3,_void_exit,Color(.25,1,.45),tr("TRIAL_PROP_EXIT"));exit_node.set_meta("type","radar_exit")
	_void_monster=CharacterBody3D.new();_void_monster.position=ORIGIN+Vector3(10,0,-4);_world.add_child(_void_monster)
	var cs:=CollisionShape3D.new();var cap:=CapsuleShape3D.new();cap.radius=.42;cap.height=2.1;cs.shape=cap;cs.position.y=1.05;_void_monster.add_child(cs)
	var mi:=MeshInstance3D.new();var cm:=CapsuleMesh.new();cm.radius=.42;cm.height=2.1;mi.mesh=cm;mi.position.y=1.05;var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.08,0,0);mat.emission_enabled=true;mat.emission=Color(1,.02,.01);mi.material_override=mat;mi.visible=false;_void_monster.add_child(mi)
	# Сектор полностью чёрный: маяки почти не светятся, геометрия
	# открывается только точками лидара (ЛКМ).
	for body in _targets:
		if not is_instance_valid(body): continue
		var visual:=body.get_child(1) as MeshInstance3D
		if visual!=null: visual.visible=false
		var lbl:=body.get_node_or_null("Label") as Label3D
		if lbl!=null: lbl.visible=false
		var hint:=OmniLight3D.new(); hint.name="NearHint"; hint.light_color=Color(.5,.7,1); hint.omni_range=2.2; hint.light_energy=.25; hint.position=Vector3(0,1,0); body.add_child(hint)
	_lidar_multimesh=MultiMesh.new(); _lidar_multimesh.transform_format=MultiMesh.TRANSFORM_3D; _lidar_multimesh.use_colors=true
	var dot:=SphereMesh.new(); dot.radius=.035; dot.height=.07; dot.radial_segments=6; dot.rings=3
	var dot_mat:=StandardMaterial3D.new(); dot_mat.vertex_color_use_as_albedo=true; dot_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	dot.material=dot_mat; _lidar_multimesh.mesh=dot; _lidar_multimesh.instance_count=LIDAR_CAPACITY
	var hidden:=Transform3D(Basis.IDENTITY,ORIGIN+Vector3(0,-500,0))
	for i in range(LIDAR_CAPACITY): _lidar_multimesh.set_instance_transform(i,hidden)
	var cloud:=MultiMeshInstance3D.new(); cloud.name="Лидарное облако"; cloud.multimesh=_lidar_multimesh; _world.add_child(cloud)
	_lidar_index=0


func _lidar_scan()->void:
	if _lidar_multimesh==null or not is_instance_valid(_player): return
	var cam:=_player.get_node_or_null("Player Camera") as Camera3D
	if cam==null: return
	var space:=_player.get_world_3d().direct_space_state
	for i in range(LIDAR_RAYS_PER_SCAN):
		var dir:=-cam.global_transform.basis.z
		dir=dir.rotated(cam.global_transform.basis.x,randf_range(-.30,.30))
		dir=dir.rotated(cam.global_transform.basis.y,randf_range(-.40,.40))
		var query:=PhysicsRayQueryParameters3D.create(cam.global_position,cam.global_position+dir*36.0)
		query.exclude=[_player.get_rid()]
		var hit:=space.intersect_ray(query)
		if hit.is_empty(): continue
		var collider:Object=hit.get("collider")
		var color:=Color(.60,.76,1)
		if collider==_void_monster: color=Color(1,.05,.03)
		elif collider is Node and (collider as Node).has_meta("type"):
			match str((collider as Node).get_meta("type")):
				"radar_exit": color=Color(.22,1,.42)
				"radar_node": color=Color(.36,.92,1)
		_lidar_multimesh.set_instance_transform(_lidar_index,Transform3D(Basis.IDENTITY,hit["position"]))
		_lidar_multimesh.set_instance_color(_lidar_index,color)
		_lidar_index=(_lidar_index+1)%LIDAR_CAPACITY
	var am:=get_tree().get_first_node_in_group("audio_manager")
	if am!=null and am.has_method("play_sfx"): am.play_sfx("terminal_beep",-14.0,1.35)


func _bridge(pos:Vector3,size:Vector3,requires_light:bool)->void:
	var body:=_box("Light Bridge" if requires_light else "Shadow Bridge",pos,size,Color(.25,.55,1) if requires_light else Color(.25,.15,.5)); _light_bridges.append(body); _bridge_requires_light.append(requires_light)

func _update_negative_space(_delta:float)->void:
	if not is_instance_valid(_player):return
	if is_instance_valid(_void_monster):
		var d:=_player.global_position-_void_monster.global_position;d.y=0
		var monster_speed:=1.45+float(_void_activated)*.22
		if _game!=null and str(_game.get("_carried_id"))=="thread_spool":monster_speed*=.75
		if d.length()>.1:_void_monster.velocity=d.normalized()*monster_speed;_void_monster.move_and_slide()
		if d.length()<1.15:_reset_after_fall()
	_status.text=tr("TRIAL_VOID_HUD")%_void_activated
	if _void_activated>=3 and _player.global_position.distance_to(_void_exit)<1.8:_complete()


# --- Эхо-камера (Запомни и повтори) --------------------------------------
func _build_echo_chamber()->void:
	_title.text=tr("TRIAL_ECHO_TITLE");_status.text=tr("TRIAL_ECHO_OBJECTIVE")
	_box("Пол камеры",ORIGIN+Vector3(0,0,0),Vector3(20,.6,20),Color(.05,.06,.09))
	_echo_pads.clear();_echo_sequence.clear();_echo_round=0;_echo_input=0;_echo_showing=false;_echo_glow_on=false
	var names:Array[String]=[tr("TRIAL_PROP_COLUMN_RED"),tr("TRIAL_PROP_COLUMN_BLUE"),tr("TRIAL_PROP_COLUMN_GREEN"),tr("TRIAL_PROP_COLUMN_YELLOW")]
	for i in range(4):
		var a: float = TAU * float(i) / 4.0 + TAU / 8.0
		var pad:=_target(i,ORIGIN+Vector3(cos(a)*6.0,1,sin(a)*6.0-2.0),ECHO_COLORS[i],names[i])
		pad.set_meta("type","echo_pad");_echo_pads.append(pad)
		var light:=OmniLight3D.new();light.name="PadLight";light.light_color=ECHO_COLORS[i];light.omni_range=8.0;light.light_energy=0.0;light.position=Vector3(0,1.6,0);pad.add_child(light)
	_echo_look=7.0
	_start_echo_round()

func _start_echo_round()->void:
	_echo_round+=1
	_echo_sequence.clear()
	for i in range(2+_echo_round):_echo_sequence.append(randi()%4)
	_echo_input=0;_echo_showing=false;_echo_glow_on=false;_echo_show_index=-1;_echo_show_timer=1.2
	if _echo_look<=0.0:
		_echo_showing=true
		_status.text=tr("TRIAL_ECHO_ROUND_WATCH")%_echo_round

func _update_echo(delta:float)->void:
	if _echo_look>0.0:
		_echo_look-=delta
		_status.text=tr("TRIAL_ECHO_LOOK_TIMER")%maxi(1,int(ceil(_echo_look)))
		if _echo_look<=0.0:
			_echo_showing=true;_echo_glow_on=false;_echo_show_index=-1;_echo_show_timer=1.0
			_status.text=tr("TRIAL_ECHO_ROUND_WATCH")%_echo_round
		return
	if not _echo_showing:return
	_echo_show_timer-=delta
	if _echo_show_timer>0.0:return
	if _echo_glow_on:
		_set_pad_glow(_echo_pads[_echo_sequence[_echo_show_index]],false)
		_echo_glow_on=false;_echo_show_timer=.34
		return
	_echo_show_index+=1
	if _echo_show_index>=_echo_sequence.size():
		_echo_showing=false;_status.text=tr("TRIAL_ECHO_ROUND_REPEAT")%_echo_round
		return
	_set_pad_glow(_echo_pads[_echo_sequence[_echo_show_index]],true)
	_echo_glow_on=true;_echo_show_timer=.85
	var am:=get_tree().get_first_node_in_group("audio_manager")
	if am!=null and am.has_method("play_sfx"):am.play_sfx("terminal_beep",-10.0,.8+.2*float(_echo_sequence[_echo_show_index]))

func _set_pad_glow(pad:StaticBody3D,glow:bool)->void:
	if not is_instance_valid(pad):return
	var visual:=pad.get_child(1) as MeshInstance3D
	if visual!=null:
		var mat:=visual.material_override as StandardMaterial3D
		if mat!=null:mat.emission_energy_multiplier=9.0 if glow else 1.7
	var light:=pad.get_node_or_null("PadLight") as OmniLight3D
	if light!=null:light.light_energy=5.0 if glow else 0.0

func _dim_all_pads()->void:
	for pad in _echo_pads:_set_pad_glow(pad,false)

func _echo_interact(index:int)->void:
	if _echo_look>0.0:
		_status.text=tr("TRIAL_ECHO_NOT_STARTED")
		return
	if _echo_showing:
		_status.text=tr("TRIAL_ECHO_WAIT")
		return
	if _echo_sequence.is_empty():return
	var am:=get_tree().get_first_node_in_group("audio_manager")
	if index==_echo_sequence[_echo_input]:
		_set_pad_glow(_echo_pads[index],true)
		if am!=null and am.has_method("play_sfx"):am.play_sfx("terminal_beep",-8.0,.8+.2*float(index))
		_echo_input+=1
		if _echo_input>=_echo_sequence.size():
			if _echo_round>=3:
				_complete()
				return
			_status.text=tr("TRIAL_ECHO_ROUND_DONE")%_echo_round
			_dim_all_pads()
			_start_echo_round()
		else:_status.text=tr("TRIAL_ECHO_CORRECT")%[_echo_input,_echo_sequence.size()]
	else:
		var failed_step:=_echo_input+1
		if am!=null and am.has_method("play_sfx"):am.play_sfx("fail",-6.0)
		_dim_all_pads()
		_echo_input=0;_echo_showing=true;_echo_glow_on=false;_echo_show_index=-1;_echo_show_timer=1.8
		_status.text=tr("TRIAL_ECHO_MISTAKE")%failed_step

# --- Зыбкий мост (фантомные плиты) ---------------------------------------
func _build_glass_bridge()->void:
	_title.text=tr("TRIAL_BRIDGE_TITLE");_status.text=tr("TRIAL_BRIDGE_OBJECTIVE")
	_box("Стартовая площадка",ORIGIN+Vector3(0,0,8),Vector3(8,.6,6),Color(.07,.08,.11))
	_box("Финишная площадка",ORIGIN+Vector3(0,0,-19.5),Vector3(8,.6,7),Color(.07,.11,.09))
	_bridge_tiles.clear();_bridge_fake.clear();_bridge_done.clear()
	for row in range(6):
		var safe_column:=randi()%2
		for column in range(2):
			var pos:=ORIGIN+Vector3(-1.6+3.2*float(column),.1,4.0-4.0*float(row))
			var tile:=_box("Плита %d-%d"%[row,column],pos,Vector3(2.4,.22,2.6),Color(.16,.2,.3))
			tile.set_meta("type","bridge_tile");tile.set_meta("tile_index",_bridge_tiles.size())
			_bridge_tiles.append(tile);_bridge_fake.append(column!=safe_column);_bridge_done.append(false)
	var exit_pad:=_target(0,ORIGIN+Vector3(0,1,-19.5),Color(.25,1,.45),tr("TRIAL_PROP_STAB_KEY"))
	exit_pad.set_meta("type","bridge_exit")

func _update_glass_bridge()->void:
	if not is_instance_valid(_player):return
	var p:=_player.global_position
	for i in range(_bridge_tiles.size()):
		if _bridge_done[i]:continue
		var tile:=_bridge_tiles[i]
		if not is_instance_valid(tile):continue
		var d:=p-tile.global_position
		if absf(d.x)<1.3 and absf(d.z)<1.4 and d.y>-.6 and d.y<2.2:
			_bridge_done[i]=true
			var visual:=tile.get_child(1) as MeshInstance3D
			var mat:StandardMaterial3D=null
			if visual!=null:mat=visual.material_override as StandardMaterial3D
			var am:=get_tree().get_first_node_in_group("audio_manager")
			if _bridge_fake[i]:
				if mat!=null:mat.albedo_color=Color(.6,.1,.1);mat.emission=Color(1,.1,.1);mat.emission_energy_multiplier=1.4
				tile.collision_layer=0
				if visual!=null:visual.transparency=.6
				if am!=null and am.has_method("play_sfx"):am.play_sfx("fail",-4.0)
				_player.velocity=Vector3.ZERO
				if _player.has_method("safe_teleport"):_player.call_deferred("safe_teleport",_spawn_position(),Vector3.DOWN)
				else:_player.global_position=_spawn_position()
			else:
				if mat!=null:mat.albedo_color=Color(.1,.4,.2);mat.emission=Color(.3,1,.5);mat.emission_energy_multiplier=1.2
				if am!=null and am.has_method("play_sfx"):am.play_sfx("terminal_beep",-12.0,1.5)

# --- Зал отражений (дефектные зеркала) ---------------------------------
func _build_mirror_maze()->void:
	_title.text=tr("TRIAL_MIRROR_TITLE");_status.text=tr("TRIAL_MIRROR_OBJECTIVE")
	_box("Пол зала",ORIGIN+Vector3(0,0,-4),Vector3(28,.6,28),Color(.09,.1,.12))
	var panels:Array=[ [Vector3(-6,2,-2),Vector3(.35,4,10)],[Vector3(6,2,-10),Vector3(.35,4,10)],[Vector3(0,2,-6),Vector3(10,4,.35)],[Vector3(-9,2,-12),Vector3(6,4,.35)],[Vector3(9,2,-1),Vector3(6,4,.35)],[Vector3(0,2,-14),Vector3(.35,4,6)] ]
	for i in range(panels.size()):
		var wall:=_box("Зеркальная панель %d"%i,ORIGIN+(panels[i][0] as Vector3),panels[i][1] as Vector3,Color(.14,.16,.2))
		var visual:=wall.get_child(1) as MeshInstance3D
		var mat:=visual.material_override as StandardMaterial3D
		if mat!=null:mat.metallic=1.0;mat.roughness=.06;mat.emission_energy_multiplier=.05
	_mirror_frames.clear();_mirror_defective.clear();_mirror_found=0;_mirror_time=0.0
	var spots:Array[Vector3]=[Vector3(-6.6,1,2),Vector3(6.6,1,-10),Vector3(-9,1,-11),Vector3(9,1,-2),Vector3(.8,1,-14),Vector3(-1,1,-5)]
	var pool:Array[int]=[0,1,2,3,4,5];pool.shuffle()
	for k in range(3):_mirror_defective.append(pool[k])
	for i in range(6):
		var frame:=_target(i,ORIGIN+spots[i],Color(.7,.8,.95),tr("TRIAL_PROP_MIRROR")%(i+1))
		frame.set_meta("type","mirror_frame");_mirror_frames.append(frame)
	_mirror_errors=0;_mirror_ghosts.clear()
	for i in range(6):
		var ghost:=MeshInstance3D.new();var ghost_mesh:=CapsuleMesh.new();ghost_mesh.radius=.32;ghost_mesh.height=1.75;ghost.mesh=ghost_mesh
		var ghost_mat:=StandardMaterial3D.new();ghost_mat.albedo_color=Color(.02,.03,.05);ghost_mat.emission_enabled=true;ghost_mat.emission=Color(.06,.09,.14);ghost_mat.emission_energy_multiplier=.6;ghost.material_override=ghost_mat
		ghost.position=Vector3(0,1.05,-.9);_mirror_frames[i].add_child(ghost);_mirror_ghosts.append(ghost)
	var lustre:=OmniLight3D.new();lustre.name="Люстра зала";lustre.position=ORIGIN+Vector3(0,6,-4);lustre.light_color=Color(.75,.85,1);lustre.light_energy=.55;lustre.omni_range=22.0;_world.add_child(lustre)

func _update_mirrors(delta:float)->void:
	_mirror_time+=delta
	for i in range(_mirror_frames.size()):
		var frame:=_mirror_frames[i]
		if not is_instance_valid(frame) or bool(frame.get_meta("solved",false)):continue
		var visual:=frame.get_child(1) as MeshInstance3D
		if visual==null:continue
		var mat:=visual.material_override as StandardMaterial3D
		if mat==null:continue
		if i in _mirror_defective:mat.emission_energy_multiplier=1.2+1.1*sin(_mirror_time*3.4+float(i)*2.1)
		else:mat.emission_energy_multiplier=1.0
		if i>=_mirror_ghosts.size() or not is_instance_valid(_mirror_ghosts[i]):continue
		if i in _mirror_defective:
			_mirror_ghosts[i].position.x=.14*sin(_mirror_time*8.7+float(i)*3.3)
			_mirror_ghosts[i].rotation.y=.3*sin(_mirror_time*5.1+float(i))

func _mirror_interact(body:StaticBody3D,index:int)->void:
	if bool(body.get_meta("solved",false)):return
	var am:=get_tree().get_first_node_in_group("audio_manager")
	if index in _mirror_defective:
		body.set_meta("solved",true);_mark(body);_mirror_found+=1
		if am!=null and am.has_method("play_sfx"):am.play_sfx("terminal_beep",-8.0,1.4)
		if _mirror_found>=3:
			var exit_pad:=_target(9,ORIGIN+Vector3(0,1,4),Color(.25,1,.45),tr("TRIAL_PROP_HALL_EXIT"))
			exit_pad.set_meta("type","mirror_exit")
			_status.text=tr("TRIAL_MIRROR_ALL_FOUND")
		else:_status.text=tr("TRIAL_MIRROR_TAGGED")%_mirror_found
	else:
		if am!=null and am.has_method("play_sfx"):am.play_sfx("fail",-8.0)
		_mirror_errors+=1
		if _mirror_errors>=3:
			_mirror_errors=0
			_reshuffle_mirrors()
			_status.text=tr("TRIAL_MIRROR_RESHUFFLE")
		else:
			_status.text=tr("TRIAL_MIRROR_STABLE")%_mirror_errors

# --- Жёлтые залы (Backrooms Level 0) --------------------------------------
func _build_yellow_halls()->void:
	_title.text=tr("TRIAL_YELLOW_TITLE");_status.text=tr("TRIAL_YELLOW_OBJECTIVE")
	_tapes_found=0;_yellow_tapes.clear()
	var wall_color: Color = Color(.52,.47,.22)
	_box("Пол залов",ORIGIN+Vector3(0,0,-5),Vector3(34,.6,32),Color(.35,.3,.16))
	_box("Потолок залов",ORIGIN+Vector3(0,3.2,-5),Vector3(34,.4,32),Color(.45,.42,.24))
	var walls:Array=[ [Vector3(-8.5,1.6,3),Vector3(.5,3,14)],[Vector3(8.5,1.6,-13),Vector3(.5,3,14)],[Vector3(-3,1.6,-4),Vector3(11,3,.5)],[Vector3(6,1.6,2),Vector3(10,3,.5)],[Vector3(-12,1.6,-12),Vector3(10,3,.5)],[Vector3(2,1.6,-12),Vector3(6,3,.5)],[Vector3(13,1.6,-2),Vector3(8,3,.5)],[Vector3(-14,1.6,4),Vector3(6,3,.5)],[Vector3(0,1.6,-17),Vector3(.5,3,8)],[Vector3(-6,1.6,-8),Vector3(.5,3,8)] ]
	for i in range(walls.size()):_box("Жёлтая стена %d"%i,ORIGIN+(walls[i][0] as Vector3),walls[i][1] as Vector3,wall_color)
	for i in range(6):
		var lx: float = -10.0 + 10.0 * float(i % 3)
		var lz: float = -14.0 + 12.0 * floor(float(i) / 3.0)
		var lamp:=OmniLight3D.new();lamp.name="Люминесцентная лампа %d"%i;lamp.position=ORIGIN+Vector3(lx,2.9,lz);lamp.light_color=Color(1,.94,.72);lamp.light_energy=.9;lamp.omni_range=9.0;_world.add_child(lamp)
	var tape_spots:Array[Vector3]=[Vector3(-12,.6,-15),Vector3(12,.6,6),Vector3(4,.6,-16)]
	for i in range(3):
		var tape:=_target(i,ORIGIN+tape_spots[i],Color(.25,.2,.14),tr("TRIAL_PROP_TAPE")%(i+1))
		tape.set_meta("type","vhs_tape");_yellow_tapes.append(tape)
	var exit_pad:=_target(7,ORIGIN+Vector3(-14,1,-16),Color(.9,.8,.2),tr("TRIAL_PROP_EXIT_STRIPED"))
	exit_pad.set_meta("type","yellow_exit")
	for s in range(6):
		var stripe_color:Color=Color(.9,.8,.15) if s%2==0 else Color(.07,.07,.07)
		_box("Разметка выхода %d"%s,ORIGIN+Vector3(-15.6+.56*float(s),.34,-16),Vector3(.5,.07,1.8),stripe_color)
	for i in range(6):
		var px: float = -10.0 + 10.0 * float(i % 3)
		var pz: float = -14.0 + 12.0 * floor(float(i) / 3.0)
		var panel:=_box("Световая панель %d"%i,ORIGIN+Vector3(px,3.0,pz),Vector3(1.9,.07,1.1),Color(.98,.95,.78))
		var pv:=panel.get_child(1) as MeshInstance3D
		var pm:=pv.material_override as StandardMaterial3D
		if pm!=null:pm.emission_energy_multiplier=1.7
	_yellow_points=[ORIGIN+Vector3(-13,.35,-19),ORIGIN+Vector3(13,.35,-19),ORIGIN+Vector3(13,.35,7),ORIGIN+Vector3(-13,.35,7)]
	_yellow_point=0;_yellow_cool=3.0
	_yellow_walker=CharacterBody3D.new();_yellow_walker.name="Блуждающий"
	var wcol:=CollisionShape3D.new();var wshape:=CapsuleShape3D.new();wshape.radius=.4;wshape.height=1.9;wcol.shape=wshape;wcol.position=Vector3(0,1.0,0);_yellow_walker.add_child(wcol)
	var wmesh:=MeshInstance3D.new();var wcap:=CapsuleMesh.new();wcap.radius=.42;wcap.height=1.95;wmesh.mesh=wcap;wmesh.position=Vector3(0,1.0,0)
	var wmat:=StandardMaterial3D.new();wmat.albedo_color=Color(.14,.12,.05);wmat.emission_enabled=true;wmat.emission=Color(.22,.18,.05);wmat.emission_energy_multiplier=.35;wmesh.material_override=wmat;_yellow_walker.add_child(wmesh)
	for e in range(2):
		var eye:=MeshInstance3D.new();var eye_mesh:=SphereMesh.new();eye_mesh.radius=.05;eye_mesh.height=.1;eye.mesh=eye_mesh
		var eye_mat:=StandardMaterial3D.new();eye_mat.albedo_color=Color(1,1,.9);eye_mat.emission_enabled=true;eye_mat.emission=Color(1,.95,.7);eye_mat.emission_energy_multiplier=3.0;eye.material_override=eye_mat
		eye.position=Vector3(-.12+.24*float(e),1.62,.36);_yellow_walker.add_child(eye)
	_yellow_walker.position=ORIGIN+Vector3(13,.35,-19);_world.add_child(_yellow_walker)

func _update_yellow(delta:float)->void:
	if not is_instance_valid(_world):return
	var lamp:=_world.get_node_or_null("Люминесцентная лампа 2") as OmniLight3D
	if lamp!=null:lamp.light_energy=.9 if fmod(Time.get_ticks_msec()/1000.0,2.3)>.4 else .15
	_yellow_cool=maxf(0.0,_yellow_cool-delta)
	if not is_instance_valid(_yellow_walker) or not is_instance_valid(_player):return
	var to_player:Vector3=_player.global_position-_yellow_walker.global_position;to_player.y=0.0
	var hunting:=to_player.length()<8.5
	var goal:Vector3=_player.global_position
	if not hunting:
		goal=_yellow_points[_yellow_point]
		var leg:Vector3=goal-_yellow_walker.global_position;leg.y=0.0
		if leg.length()<1.2:_yellow_point=(_yellow_point+1)%_yellow_points.size();goal=_yellow_points[_yellow_point]
	var dir:Vector3=goal-_yellow_walker.global_position;dir.y=0.0
	if dir.length()>.05:
		dir=dir.normalized()
		_yellow_walker.velocity=dir*(2.9 if hunting else 2.1)
		_yellow_walker.move_and_slide()
		_yellow_walker.rotation.y=atan2(dir.x,dir.z)
	if _yellow_cool<=0.0 and to_player.length()<1.5:
		_yellow_cool=4.0
		_player.velocity=Vector3.ZERO;_player.global_position=_spawn_position()
		if _tapes_found>0:
			_tapes_found-=1
			for tape in _yellow_tapes:
				if is_instance_valid(tape) and not tape.visible:
					tape.visible=true;tape.collision_layer=1
					break
			_status.text=tr("TRIAL_YELLOW_TAPE_LOST")%_tapes_found
		else:_status.text=tr("TRIAL_YELLOW_CAUGHT")
		var am:=get_tree().get_first_node_in_group("audio_manager")
		if am!=null and am.has_method("play_sfx"):am.play_sfx("fail",-4.0)

# --- Служба извлечения (R.E.P.O. / Lethal Company) -----------------------
func _build_scrap_run()->void:
	_title.text=tr("TRIAL_SCRAP_TITLE");_status.text=tr("TRIAL_SCRAP_OBJECTIVE")
	_box("Пол склада",ORIGIN+Vector3(-6,0,-6),Vector3(20,.6,32),Color(.03,.035,.05))
	_box("Дальний пол",ORIGIN+Vector3(11,0,-6),Vector3(10,.6,32),Color(.03,.035,.05))
	_box("Мостик между секциями",ORIGIN+Vector3(5,0,-6),Vector3(2.4,.55,2.2),Color(.05,.06,.08))
	var shelves:Array=[ [Vector3(9,1.5,-14),Vector3(1.2,3,8)],[Vector3(13,1.5,2),Vector3(1.2,3,8)],[Vector3(-12,1.5,-16),Vector3(8,3,1.2)],[Vector3(-10,1.5,4),Vector3(6,3,1.2)] ]
	for i in range(shelves.size()):_box("Стеллаж %d"%i,ORIGIN+(shelves[i][0] as Vector3),shelves[i][1] as Vector3,Color(.06,.07,.09))
	_scrap_items.clear();_scrap_home.clear();_scrap_carrying=-1;_scrap_delivered=0
	var names:Array[String]=[tr("TRIAL_PROP_BUST"),tr("TRIAL_PROP_VASE"),tr("TRIAL_PROP_CLOCK")]
	var spots:Array[Vector3]=[Vector3(11,1,-16),Vector3(13,1,7),Vector3(-13,1,-18)]
	for i in range(3):
		var item:=_target(i,ORIGIN+spots[i],Color(.95,.8,.35),names[i])
		item.set_meta("type","valuable");_scrap_items.append(item);_scrap_home.append(item.position)
	var pad:=_target(8,ORIGIN+Vector3(0,1,7),Color(.25,1,.45),tr("TRIAL_PROP_EXTRACT_PAD"))
	pad.set_meta("type","extract_pad")
	var pl:=OmniLight3D.new();pl.name="Свет извлечения";pl.light_color=Color(.3,1,.5);pl.omni_range=7.0;pl.light_energy=1.2;pl.position=Vector3(0,2,0);pad.add_child(pl)
	_scrap_value=0;_drone_angle=0.0
	var values:Array[int]=[40,25,35]
	for i in range(3):_scrap_items[i].set_meta("value",values[i])
	_scrap_drone=Node3D.new();_scrap_drone.name="Дрон-сканер";_world.add_child(_scrap_drone)
	var drone_body:=MeshInstance3D.new();var drone_mesh:=SphereMesh.new();drone_mesh.radius=.45;drone_mesh.height=.9;drone_body.mesh=drone_mesh
	var drone_mat:=StandardMaterial3D.new();drone_mat.albedo_color=Color(.1,.12,.16);drone_mat.emission_enabled=true;drone_mat.emission=Color(1,.25,.2);drone_mat.emission_energy_multiplier=1.4;drone_body.material_override=drone_mat;_scrap_drone.add_child(drone_body)
	var beam:=SpotLight3D.new();beam.name="Луч сканера";beam.rotation_degrees=Vector3(-90,0,0);beam.spot_range=7.0;beam.spot_angle=24.0;beam.light_color=Color(1,.3,.25);beam.light_energy=2.6;_scrap_drone.add_child(beam)
	_scrap_drone.position=ORIGIN+Vector3(10,4.4,-6)

func _update_scrap(delta:float)->void:
	if _scrap_carrying>=0 and is_instance_valid(_scrap_items[_scrap_carrying]):
		_status.text=tr("TRIAL_SCRAP_HUD_CARRY")%[str(_scrap_items[_scrap_carrying].name),_scrap_delivered,_scrap_value]
	if not is_instance_valid(_scrap_drone) or not is_instance_valid(_player):return
	_drone_angle+=delta*.55
	var sweep:Vector3=ORIGIN+Vector3(cos(_drone_angle)*10.0,4.4,-6.0+sin(_drone_angle*2.0)*11.0)
	_scrap_drone.position=_scrap_drone.position.lerp(sweep,minf(1.0,delta*2.2))
	if _scrap_carrying<0:return
	var flat:Vector3=_scrap_drone.global_position-_player.global_position;flat.y=0.0
	if flat.length()<2.3:
		var dropped:=_scrap_items[_scrap_carrying]
		if is_instance_valid(dropped):dropped.visible=true;dropped.collision_layer=1
		_scrap_carrying=-1
		_drop_carry_visual()
		_status.text=tr("TRIAL_SCRAP_DRONE_CAUGHT")
		var am:=get_tree().get_first_node_in_group("audio_manager")
		if am!=null and am.has_method("play_sfx"):am.play_sfx("fail",-4.0)

func _valuable_interact(body:StaticBody3D,index:int)->void:
	if _scrap_carrying>=0:
		_status.text=tr("TRIAL_SCRAP_HANDS_FULL")
		return
	_scrap_carrying=index;body.visible=false;body.collision_layer=0
	_set_carry_visual(Color(.95,.8,.35))
	_status.text=tr("TRIAL_SCRAP_PICKED")%[str(body.name),int(body.get_meta("value",0))]

func _extract_interact()->void:
	if _scrap_carrying<0:
		_status.text=tr("TRIAL_SCRAP_BRING")%_scrap_delivered
		return
	if is_instance_valid(_scrap_items[_scrap_carrying]):_scrap_value+=int(_scrap_items[_scrap_carrying].get_meta("value",0))
	_scrap_carrying=-1;_scrap_delivered+=1
	_drop_carry_visual()
	if _scrap_delivered>=3:
		_status.text=tr("TRIAL_SCRAP_ALL_DONE")%_scrap_value
		_complete()
		return
	_status.text=tr("TRIAL_SCRAP_PROGRESS")%[_scrap_delivered,_scrap_value]

# --- Восхождение (PEAK: туман поднимается) ------------------------------
func _build_ascent()->void:
	_title.text=tr("TRIAL_ASCENT_TITLE");_status.text=tr("TRIAL_ASCENT_OBJECTIVE")
	_ascent_time=0.0;_ascent_movers.clear();_ascent_mover_base.clear();_ascent_cps.clear();_ascent_checkpoint=_spawn_position()
	_box("Базовая площадка",ORIGIN+Vector3(0,0,6),Vector3(10,.6,8),Color(.07,.08,.1))
	var steps:Array[Vector3]=[Vector3(0.00,1.20,2.60),Vector3(-3.07,2.15,1.68),Vector3(-5.13,3.10,-0.76),Vector3(-5.52,4.05,-3.94),Vector3(-4.10,5.00,-6.81),Vector3(-1.34,5.95,-8.44),Vector3(1.86,6.90,-8.28),Vector3(4.45,7.85,-6.40),Vector3(5.59,8.80,-3.41),Vector3(4.89,9.75,-0.28),Vector3(2.60,10.70,1.96),Vector3(-0.54,11.65,2.57),Vector3(-3.51,12.60,1.37),Vector3(-5.33,13.55,-1.27),Vector3(-5.40,14.50,-4.47),Vector3(-3.71,15.45,-7.19)]
	for i in range(steps.size()):
		var step:=_box("Уступ %d"%i,ORIGIN+steps[i],Vector3(2.8,.5,2.8),Color(.1,.12,.16))
		if i in [5,10,14]:
			_ascent_movers.append(step);_ascent_mover_base.append(step.position)
			var sv:=step.get_child(1) as MeshInstance3D
			var sm:=sv.material_override as StandardMaterial3D
			if sm!=null:sm.albedo_color=Color(.16,.1,.22);sm.emission=Color(.55,.3,.9);sm.emission_energy_multiplier=.9
		if i in [4,9,13]:
			_box("Плита контрольной точки %d"%i,ORIGIN+steps[i]+Vector3(0,.35,0),Vector3(1.3,.14,1.3),Color(.15,.6,.4))
			_ascent_cps.append(ORIGIN+steps[i]+Vector3(0,1.3,0))
	_box("Вершина",ORIGIN+Vector3(-0.81,16.40,-8.54),Vector3(5,.6,5),Color(.09,.14,.11))
	var exit_pad:=_target(0,ORIGIN+Vector3(-0.81,17.40,-8.54),Color(.25,1,.45),tr("TRIAL_PROP_EVAC_PAD"))
	exit_pad.set_meta("type","ascent_exit")
	_fog_plane=MeshInstance3D.new();_fog_plane.name="Поднимающийся туман"
	var fog_mesh:=BoxMesh.new();fog_mesh.size=Vector3(60,.5,60);_fog_plane.mesh=fog_mesh
	var fog_mat:=StandardMaterial3D.new();fog_mat.albedo_color=Color(.75,.8,.9,.45);fog_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;fog_mat.emission_enabled=true;fog_mat.emission=Color(.6,.7,.85);fog_mat.emission_energy_multiplier=.4;_fog_plane.material_override=fog_mat
	_fog_y=-8.0;_fog_plane.position=ORIGIN+Vector3(0,_fog_y,0);_world.add_child(_fog_plane)
	var beacon:=OmniLight3D.new();beacon.name="Маяк вершины";beacon.light_color=Color(.3,1,.5);beacon.omni_range=12.0;beacon.light_energy=1.6;beacon.position=ORIGIN+Vector3(-0.81,18.6,-8.54);_world.add_child(beacon)

func _update_ascent(delta:float)->void:
	_ascent_time+=delta
	for k in range(_ascent_movers.size()):
		if is_instance_valid(_ascent_movers[k]):_ascent_movers[k].position=_ascent_mover_base[k]+Vector3(sin(_ascent_time*1.3+float(k)*2.1)*1.5,0,0)
	_fog_y=minf(_fog_y+delta*.22,15.20)
	if is_instance_valid(_fog_plane):_fog_plane.position=ORIGIN+Vector3(0,_fog_y,0)
	if not is_instance_valid(_player):return
	for cp in _ascent_cps:
		if cp.y>_ascent_checkpoint.y and _player.global_position.distance_to(cp)<1.7:
			_ascent_checkpoint=cp
			_status.text=tr("TRIAL_ASCENT_CHECKPOINT")%int(cp.y-ORIGIN.y)
	if _player.global_position.y<ORIGIN.y+_fog_y-.2:
		_fog_y=minf(_fog_y,_ascent_checkpoint.y-ORIGIN.y-7.0)
		_player.velocity=Vector3.ZERO
		_player.global_position=_ascent_checkpoint
		_status.text=tr("TRIAL_ASCENT_FOG")

# --- Помощники доработанных измерений -------------------------------------
func _reshuffle_mirrors()->void:
	var free_ids:Array[int]=[]
	for i in range(_mirror_frames.size()):
		if is_instance_valid(_mirror_frames[i]) and not bool(_mirror_frames[i].get_meta("solved",false)):free_ids.append(i)
	free_ids.shuffle()
	_mirror_defective.clear()
	for k in range(mini(3-_mirror_found,free_ids.size())):_mirror_defective.append(free_ids[k])
	for i in range(_mirror_ghosts.size()):
		if is_instance_valid(_mirror_ghosts[i]):_mirror_ghosts[i].position.x=0.0;_mirror_ghosts[i].rotation.y=0.0

func _set_carry_visual(color:Color)->void:
	_drop_carry_visual()
	if not is_instance_valid(_player):return
	var cam:Variant=_player.get("camera")
	if cam==null or not (cam is Node3D):return
	_carry_visual=MeshInstance3D.new();_carry_visual.name="Экспонат в руках"
	var mesh:=BoxMesh.new();mesh.size=Vector3(.3,.3,.3);_carry_visual.mesh=mesh
	var mat:=StandardMaterial3D.new();mat.albedo_color=color.darkened(.3);mat.emission_enabled=true;mat.emission=color;mat.emission_energy_multiplier=1.2;_carry_visual.material_override=mat
	_carry_visual.position=Vector3(.42,-.38,-.85);(cam as Node3D).add_child(_carry_visual)

func _drop_carry_visual()->void:
	if is_instance_valid(_carry_visual):_carry_visual.queue_free()
	_carry_visual=null

# --- Невидимые границы измерений ------------------------------------------
func _invisible_wall(pos:Vector3,size:Vector3)->void:
	var body:=StaticBody3D.new();body.name="Граница сектора";body.position=pos;_world.add_child(body)
	var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;collision.shape=shape;body.add_child(collision)

func _add_bounds()->void:
	# Невидимый периметр: выпасть за карту измерения нельзя.
	var center: Vector3 = ORIGIN + Vector3(0,10,-6)
	var half_x: float = 26.0;var half_z: float = 26.0
	match _kind:
		"void_rift":center=ORIGIN+Vector3(0,10,-8);half_x=15.1;half_z=18.4
		"echo_chamber":center=ORIGIN+Vector3(0,10,0);half_x=10.2;half_z=10.2
		"glass_bridge":center=ORIGIN+Vector3(0,10,-6);half_x=8.0;half_z=18.0
		"mirror_maze":center=ORIGIN+Vector3(0,10,-4);half_x=14.2;half_z=14.2
		"yellow_halls":center=ORIGIN+Vector3(0,10,-5);half_x=17.2;half_z=16.2
		"scrap_run":center=ORIGIN+Vector3(0,10,-6);half_x=16.3;half_z=16.3
		"ascent":center=ORIGIN+Vector3(0,12,-3);half_x=12.0;half_z=12.0
	_invisible_wall(center+Vector3(-half_x,0,0),Vector3(.5,26,half_z*2))
	_invisible_wall(center+Vector3(half_x,0,0),Vector3(.5,26,half_z*2))
	_invisible_wall(center+Vector3(0,0,-half_z),Vector3(half_x*2,26,.5))
	_invisible_wall(center+Vector3(0,0,half_z),Vector3(half_x*2,26,.5))

# --- Shared interaction and construction ---------------------------------
func _interact()->void:
	var body:=_nearest_target("")
	if body==null: _status.text=tr("TRIAL_MOVE_CLOSER"); return
	var type:=str(body.get_meta("type","")); var index:=int(body.get_meta("index",-1))
	if type=="gravity_anchor": _gravity_anchor(index)
	elif type in ["monolith","socket"]: _radiation_interact(body)
	elif type=="void_node": _checkpoint=maxi(_checkpoint,index); _mark(body)
	elif type=="radar_node" and body.visible:body.visible=false;body.collision_layer=0;_void_activated+=1
	elif type=="radar_exit" and _void_activated>=3:_complete()
	elif type=="echo_pad":_echo_interact(index)
	elif type=="bridge_exit":_complete()
	elif type=="mirror_frame":_mirror_interact(body,index)
	elif type=="mirror_exit":_complete()
	elif type=="vhs_tape":body.visible=false;body.collision_layer=0;_tapes_found+=1;_status.text=tr("TRIAL_YELLOW_TAPE_FOUND")%_tapes_found
	elif type=="yellow_exit" and _tapes_found>=3:_complete()
	elif type=="yellow_exit":_status.text=tr("TRIAL_YELLOW_EXIT_LOCKED")%_tapes_found
	elif type=="valuable":_valuable_interact(body,index)
	elif type=="extract_pad":_extract_interact()
	elif type=="ascent_exit":_complete()

func _nearest_target(type_filter:String)->StaticBody3D:
	if not is_instance_valid(_player): return null
	var found:StaticBody3D; var distance:=USE_DISTANCE
	for body in _targets:
		if not is_instance_valid(body) or not body.visible: continue
		if type_filter!="" and str(body.get_meta("type",""))!=type_filter: continue
		var d:=_player.global_position.distance_to(body.global_position)
		if d<distance: found=body; distance=d
	return found

func _reset_after_fall()->void:
	if not is_instance_valid(_player): return
	_player.velocity=Vector3.ZERO
	if _kind=="scrap_run" and _scrap_carrying>=0:
		var dropped:=_scrap_items[_scrap_carrying]
		if is_instance_valid(dropped):dropped.visible=true;dropped.collision_layer=1
		_scrap_carrying=-1
		_drop_carry_visual()
		_status.text=tr("TRIAL_SCRAP_DROPPED")
	if _kind=="ascent" and _ascent_checkpoint!=Vector3.ZERO:
		_fog_y=minf(_fog_y,_ascent_checkpoint.y-ORIGIN.y-7.0)
		_player.global_position=_ascent_checkpoint
		_status.text=tr("TRIAL_ASCENT_RESPAWN")
		return
	if _kind=="void_rift":
		if _player.has_method("safe_teleport"):_player.call_deferred("safe_teleport",_spawn_position(),Vector3.DOWN)
		else:_player.global_position=_spawn_position()
		if is_instance_valid(_void_monster):_void_monster.global_position=ORIGIN+Vector3(10,0,-4)
	else: _player.global_position=_spawn_position()
	if _kind=="gravity_surge": _player.reset_gravity_direction(); _step=0

func _complete()->void:
	_return_player(); _cleanup()
	if _game!=null: _game.call_deferred("_complete_trial")

func _return_player()->void:
	if _player!=null and is_instance_valid(_player):
		_player.reset_gravity_direction(); _player.controls_enabled=true; _player.velocity=Vector3.ZERO; _player.global_transform=_saved

func _cleanup()->void:
	_active=false; _layer.visible=false
	if is_instance_valid(_active_trial):
		_active_trial.cleanup(self)
		_active_trial.queue_free()
	_active_trial=null
	for echo in _echoes:
		if is_instance_valid(echo): echo.queue_free()
	_echoes.clear(); _echo_recordings.clear(); _targets.clear(); _light_bridges.clear(); _bridge_requires_light.clear(); _monoliths.clear(); _void_nodes.clear(); _echo_pads.clear(); _bridge_tiles.clear(); _bridge_fake.clear(); _bridge_done.clear()
	_void_monster=null;_fog_plane=null;_scrap_carrying=-1;_scrap_delivered=0;_tapes_found=0;_mirror_found=0;_echo_look=0.0;_echo_glow_on=false
	_mirror_frames.clear();_mirror_defective.clear();_scrap_items.clear();_scrap_home.clear()
	_mirror_ghosts.clear();_yellow_tapes.clear();_yellow_points.clear();_ascent_movers.clear();_ascent_mover_base.clear();_ascent_cps.clear()
	_yellow_walker=null;_scrap_drone=null;_mirror_errors=0;_yellow_point=0;_yellow_cool=0.0;_drone_angle=0.0;_scrap_value=0;_ascent_time=0.0;_ascent_checkpoint=Vector3.ZERO
	_drop_carry_visual()
	if is_instance_valid(_world): _world.queue_free()
	_world=null; _player=null

func _target(index:int,pos:Vector3,color:Color,text:String)->StaticBody3D:
	var body:=StaticBody3D.new(); body.name=text; body.position=pos; body.set_meta("index",index); _world.add_child(body)
	var collision:=CollisionShape3D.new(); var shape:=CylinderShape3D.new(); shape.radius=.55; shape.height=1.5; collision.shape=shape; body.add_child(collision)
	var visual:=MeshInstance3D.new(); var mesh:=CylinderMesh.new(); mesh.bottom_radius=.5; mesh.top_radius=.38; mesh.height=1.5; visual.mesh=mesh
	var mat:=StandardMaterial3D.new(); mat.albedo_color=color.darkened(.5); mat.emission_enabled=true; mat.emission=color; mat.emission_energy_multiplier=1.7; visual.material_override=mat; body.add_child(visual)
	var label:=Label3D.new(); label.name="Label"; label.text=text; label.position=Vector3(0,1.25,0); label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.font_size=28; label.pixel_size=.005; label.outline_size=5; body.add_child(label)
	_targets.append(body); return body

func _box(box_name:String,pos:Vector3,size:Vector3,color:Color)->StaticBody3D:
	var body:=StaticBody3D.new(); body.name=box_name; body.position=pos; _world.add_child(body)
	var collision:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=size; collision.shape=shape; body.add_child(collision)
	var visual:=MeshInstance3D.new(); var mesh:=BoxMesh.new(); mesh.size=size; visual.mesh=mesh
	var mat:=StandardMaterial3D.new(); mat.albedo_color=color; mat.emission_enabled=true; mat.emission=color.lightened(.1); mat.emission_energy_multiplier=.2; visual.material_override=mat; body.add_child(visual); return body

func _mark(body:StaticBody3D)->void:
	var visual:=body.get_child(1) as MeshInstance3D; var mat:=visual.material_override as StandardMaterial3D; mat.emission=Color(.4,1,.7); mat.albedo_color=Color(.08,.4,.23)
func _find_label(body:Node)->Label3D: return body.get_node_or_null("Label") as Label3D

func _build_hud()->void:
	_layer=CanvasLayer.new(); _layer.layer=30; _layer.visible=false; add_child(_layer)
	var panel:=ColorRect.new(); panel.color=Color(.01,.02,.035,.94); panel.anchor_left=.14; panel.anchor_top=.025; panel.anchor_right=.86; panel.anchor_bottom=.17; panel.mouse_filter=Control.MOUSE_FILTER_IGNORE; _layer.add_child(panel)
	_title=Label.new(); _title.anchor_right=1.; _title.anchor_bottom=.4; _title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; _title.add_theme_font_size_override("font_size",24); _title.add_theme_color_override("font_color",Color(.65,.82,1)); _title.mouse_filter=Control.MOUSE_FILTER_IGNORE; panel.add_child(_title)
	_status=Label.new(); _status.anchor_top=.4; _status.anchor_right=1.; _status.anchor_bottom=1.; _status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; _status.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; _status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _status.add_theme_font_size_override("font_size",16); _status.mouse_filter=Control.MOUSE_FILTER_IGNORE; panel.add_child(_status)
