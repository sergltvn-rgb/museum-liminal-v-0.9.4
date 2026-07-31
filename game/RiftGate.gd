class_name RiftGate
extends Area3D

## РАЗЛОМ КАК ДВЕРЬ В ТОМ ЖЕ ЗАЛЕ (аудит 16.6 п. 6).
##
## До этого карманное измерение начиналось в тот момент, когда прибор касался
## экспоната: GameManager._interact() звал _begin_trial(), а RiftTrialManager.begin()
## через один физический кадр ставил `_player.global_position = _spawn_position()`
## и обнулял поворот. Игрок не входил в разлом — его туда переставляли, и
## измеренная дистанция этой перестановки составляла порядка 260 м по Z и 71 м по
## Y (ORIGIN = (0, 72, -260) против пола музея на y = 0).
##
## RiftGate — это створ, который прибор ОТКРЫВАЕТ на месте аномалии. Он стоит в
## геометрии текущего зала, светится цветом своей аномалии, и пока игрок сам не
## переступит его порог, никакого перехода нет. Створ хранит собственный
## базис, поэтому вход можно продолжить с той же стороны и с тем же курсом, с
## каким игрок в него шагнул, вместо спавна лицом в фиксированный север.

## Проём: створ ровно на человека, а не арка на полстены.
const WIDTH := 1.30
const HEIGHT := 2.30
const DEPTH := 0.55
## Толщина светящейся рамы.
const FRAME := 0.12
## Сколько свободного пола должно быть перед створом, чтобы в него можно было
## войти шагом. Радиус капсулы игрока 0.35, поэтому 1.20 — это шаг разгона плюс
## запас на косой подход.
const CLEARANCE := 1.20
## Курс подбирается перебором с этим шагом, начиная с направления на игрока.
const HEADING_STEP_DEG := 15.0
## ИЗМЕРЕНО: точка аномалии — это сам экспонат, а не свободный пол. Первый прогон
## гейта поставил створ ровно в коллайдеры Clock Drum, Drop Body, Portal Arch Membrane,
## Orrery Column и Superheavy Sphere, а точка подхода уходила на 0.70–0.80 м с
## навмеша — под постаментом меша нет. Поэтому створ отходит от экспоната к тому,
## кто его открыл: разлом раскрывается перед витриной, а не внутри неё.
##
## 2.10 м хватило не всем: на Inversion Room и Time Loop в порог ещё входил
## коллайдер постамента. 2.40 м оставляет дальнюю грань створа в 2.13 м от центра
## экспоната — шире любого постамента на карте и всё ещё в шаге от витрины.
const STANDOFF := 2.40

var kind := ""
var crossed := false

signal crossed_by(body: Node3D)


## Створ, повёрнутый в сторону `toward` настолько, насколько это позволяет зал.
##
## `space` — состояние физики того же мира; курс проверяется лучами, а не
## угадывается, потому что аномалия может стоять вплотную к витрине или к стене.
static func build(parent: Node3D, gate_kind: String, origin: Vector3,
		toward: Vector3, color: Color) -> RiftGate:
	var gate := RiftGate.new()
	gate.name = "Rift Gate"
	gate.kind = gate_kind
	gate.monitoring = true
	gate.monitorable = false
	# Слой 1 — тела игрока и Куратора; сам створ ничего не загораживает.
	gate.collision_layer = 0
	gate.collision_mask = 1
	parent.add_child(gate)
	var preferred := 0.0
	var flat := Vector3(toward.x - origin.x, 0.0, toward.z - origin.z)
	if flat.length() > 0.05:
		preferred = rad_to_deg(atan2(flat.x, flat.z))
		gate.global_position = origin + flat.normalized() * STANDOFF
	else:
		gate.global_position = origin
	gate.rotation_degrees = Vector3(0.0, gate._pick_heading(preferred), 0.0)
	gate._assemble(color)
	gate.body_entered.connect(gate._on_body_entered)
	# Opening the rift: DSGN VORTEX IN, baked at -20.0 dBFS RMS / -1.5 peak.
	var am := parent.get_tree().get_first_node_in_group("audio_manager")
	if am != null and am.has_method("play_at"):
		am.play_at("rift_open", gate.global_position + Vector3(0.0, 1.2, 0.0), -2.0)
	return gate


## Первый курс, перед которым есть CLEARANCE свободного пола по всей ширине
## проёма. Проверяются три луча (центр и обе щеки), начиная с желаемого курса и
## расходясь в обе стороны; если зал не даёт ничего чистого, возвращается
## желаемый курс — створ всё равно будет виден и его створка не блокирует проход.
func _pick_heading(preferred_deg: float) -> float:
	var world := get_world_3d()
	if world == null:
		return preferred_deg
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var steps := int(round(360.0 / HEADING_STEP_DEG))
	for i in range(steps):
		# 0, +15, -15, +30, -30 ... — ближайший к желаемому курс выигрывает.
		# Делитель вещественный нарочно: целочисленное деление даёт ту же
		# последовательность 0,1,1,2,2..., но роняет предупреждение компилятора.
		var step := float(int((i + 1) / 2.0))
		var offset := step * HEADING_STEP_DEG * (1.0 if i % 2 == 0 else -1.0)
		var heading := preferred_deg + offset
		if _heading_is_clear(space, heading):
			return heading
	return preferred_deg


func _heading_is_clear(space: PhysicsDirectSpaceState3D, heading_deg: float) -> bool:
	var yaw := deg_to_rad(heading_deg)
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var side := Vector3(cos(yaw), 0.0, -sin(yaw))
	for lateral in [-WIDTH * 0.5 + 0.1, 0.0, WIDTH * 0.5 - 0.1]:
		for height in [0.45, 1.60]:
			var from: Vector3 = global_position + side * lateral + Vector3(0.0, height, 0.0)
			var to: Vector3 = from + forward * CLEARANCE
			var query := PhysicsRayQueryParameters3D.create(from, to)
			query.collision_mask = 1
			if not space.intersect_ray(query).is_empty():
				return false
	return true


func _assemble(color: Color) -> void:
	var shape := CollisionShape3D.new()
	shape.name = "Threshold"
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, HEIGHT, DEPTH)
	shape.shape = box
	shape.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	add_child(shape)
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.55)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.8
	# Стойки и перемычка: рама стоит по краям проёма, сам проём пуст.
	var half := WIDTH * 0.5
	_bar("Gate Post Left", Vector3(-half - FRAME * 0.5, HEIGHT * 0.5, 0.0),
		Vector3(FRAME, HEIGHT, FRAME), material)
	_bar("Gate Post Right", Vector3(half + FRAME * 0.5, HEIGHT * 0.5, 0.0),
		Vector3(FRAME, HEIGHT, FRAME), material)
	_bar("Gate Lintel", Vector3(0.0, HEIGHT + FRAME * 0.5, 0.0),
		Vector3(WIDTH + FRAME * 2.0, FRAME, FRAME), material)
	# Плёнка в проёме: видно, что там не зал, но пройти можно насквозь.
	var sheet := MeshInstance3D.new()
	sheet.name = "Gate Sheet"
	var plane := PlaneMesh.new()
	plane.size = Vector2(WIDTH, HEIGHT)
	plane.orientation = PlaneMesh.FACE_Z
	sheet.mesh = plane
	sheet.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	var film := StandardMaterial3D.new()
	film.albedo_color = Color(color.r, color.g, color.b, 0.42)
	film.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	film.emission_enabled = true
	film.emission = color
	film.emission_energy_multiplier = 1.2
	film.cull_mode = BaseMaterial3D.CULL_DISABLED
	sheet.material_override = film
	add_child(sheet)
	var glow := OmniLight3D.new()
	glow.name = "Gate Glow"
	glow.light_color = color
	glow.light_energy = 1.6
	glow.omni_range = 7.0
	glow.position = Vector3(0.0, HEIGHT * 0.6, 0.0)
	add_child(glow)


func _bar(bar_name: String, offset: Vector3, size: Vector3,
		material: StandardMaterial3D) -> void:
	var bar := MeshInstance3D.new()
	bar.name = bar_name
	var mesh := BoxMesh.new()
	mesh.size = size
	bar.mesh = mesh
	bar.position = offset
	bar.material_override = material
	add_child(bar)


## Точка, с которой в створ входят: CLEARANCE перед плёнкой, на полу.
func approach_point() -> Vector3:
	return global_position + global_transform.basis.z * CLEARANCE


## Курс створа в градусах — то, чем должен стать курс игрока по ту сторону, чтобы
## шаг сквозь плёнку не разворачивал камеру.
func heading_degrees() -> float:
	return rotation_degrees.y


## Смещение тела вбок от оси створа в момент перехода. Карманное измерение
## ставит игрока на свой порог с тем же смещением, поэтому вход "по краю"
## остаётся входом по краю.
func lateral_offset(from: Vector3) -> float:
	var delta := from - global_position
	return global_transform.basis.x.dot(delta)


func _on_body_entered(body: Node3D) -> void:
	if crossed or body == null:
		return
	if not body.is_in_group("player"):
		return
	crossed = true
	# Stepping through: WHOOSH PASS SF LOW, baked at -17.4 dBFS RMS.
	var am := get_tree().get_first_node_in_group("audio_manager")
	if am != null and am.has_method("play_sfx"):
		am.play_sfx("rift_cross", -2.0)
	crossed_by.emit(body)
