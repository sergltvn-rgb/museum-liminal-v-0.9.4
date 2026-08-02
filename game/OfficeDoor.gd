extends Node3D
class_name OfficeDoor

## ГЕРМОСТВОРКА ОФИСА С КНОПКОЙ (механика FNaF).
##
## До этого офис был проходным двором: Куратор входил в проём и ловил игрока,
## сидящего к нему спиной за компьютером, и сделать с этим было нечего.
## Наблюдение за экраном стоило жизни, а не времени. Створка возвращает игроку
## решение: дверь можно закрыть и спокойно читать протокол, но закрытая дверь
## жрёт питание, а питание кончается раньше смены.
##
## Створка едет ВЕРТИКАЛЬНО, гильотиной из короба над проёмом, а не на петлях.
## Причина не стилистическая: распашная створка выметает 0.9 м пола по дуге,
## а проём тут 1.8 м при коридоре, где Куратор проходит впритирку — петля
## гарантированно защемляла бы его капсулу и роняла в застревание.
##
## НАВМЕШ. Коллайдер створки лежит в группе источников навигации, поэтому
## закрытая дверь обязана пересобрать навмеш — иначе Куратор пройдёт сквозь
## неё, как сквозь пустой проём (ровно тот баг, что держал Крыло D запечатанным,
## только наоборот). Пересборку заказывает карта, а не эта нода: у карты уже
## есть очередь на один одновременный bake.
##
## Открытая створка уезжает на 2.72 м вверх — выше дверного перемычки (2.70) и
## внутрь короба, так что её коллайдер оказывается над головой и навмеш снова
## сходится через проём.

## Створка доехала до нового положения. closed — итоговое состояние.
signal state_changed(closed: bool)

## Группа, по которой карта собирает геометрию для навмеша. Значение обязано
## совпадать с FirstMuseumMap.NAV_SOURCE_GROUP; строкой, а не ссылкой на константу,
## чтобы дверь можно было грузить в тестах без карты.
const NAV_SOURCE_GROUP := "museum_nav_source"
## Одна модель индикатора на весь музей. preload, а не class_name: классы по
## имени не регистрируются в голом режиме --script, в котором идут регрессы.
const Lamp := preload("res://game/props/StatusLamp.gd")

## Полный ход створки за 0.55 с. Быстрее — читается как телепорт и убивает
## напряжение «успею ли»; медленнее — игрок жмёт кнопку заранее «на всякий
## случай», и выбор перестаёт быть выбором.
const TRAVEL_TIME := 0.55
const LEAF_THICK := 0.18
const LEAF_HEIGHT := 2.62
const CLOSED_Y := 1.31
const OPEN_LIFT := 2.72
const BUTTON_HEIGHT := 1.35
const BUTTON_CLEARANCE := 0.52
## ТАБЛО НАД ПРОЁМОМ. Кнопка висит на стене сбоку и в тёмном офисе её
## просто не видно, пока не уткнёшься носом: игрок проходил мимо двери
## и не знал, что она вообще есть. Полоса над проёмом горит с ОБЕИХ
## сторон и читается через всю комнату — именно она говорит "здесь дверь".
const MARQUEE_HEIGHT := 2.46
const MARQUEE_THICK := 0.05
const MARQUEE_BAND := 0.13

const COL_LEAF := Color(0.085, 0.095, 0.105)
const COL_RIB := Color(0.140, 0.152, 0.160)
const COL_HOUSING := Color(0.055, 0.062, 0.070)
const COL_PANEL := Color(0.105, 0.115, 0.125)
const COL_KEY := Color(0.560, 0.545, 0.480)
const COL_LAMP_OPEN := Color(0.505, 0.658, 0.541)
const COL_LAMP_SHUT := Color(0.900, 0.560, 0.120)
const COL_LAMP_DEAD := Color(0.220, 0.235, 0.245)

## "z" — проём в стене север-юг, проход вдоль X (Офис <-> Атриум).
## "x" — проём в стене восток-запад, проход вдоль Z (Офис <-> Архив/Склад).
var axis := "z"
## Ширина проёма. Створка перекрывает его с запасом на притворы.
var span := 1.8
## Знак смещения кнопки вдоль стены: с какой стороны проёма её искать.
var button_side := 1.0
## С какой стороны проёма ОФИС. Кнопка всегда висит изнутри: снаружи её
## мог бы нажать тот, от кого дверь закрывают. У восточного проёма офис лежит
## по -X, у северного — по +Z, и одним знаком на все двери тут не обойтись.
var inside_sign := -1.0
## Обесточенная дверь не слушает кнопку и замирает открытой.
var powered := true

var _closed := false
var _travel := 0.0
var _leaf: Node3D = null
var _lamp: Node3D = null
var _lamp_material: StandardMaterial3D = null
## ВСЕ светящиеся указатели двери сразу: лампа кнопки и обе полосы табло.
## Состояние створки обязано меняться везде одновременно, иначе табло будет
## врать про закрытую дверь — а именно по нему игрок судит издалека.
var _signals: Array[StandardMaterial3D] = []
var _button_local := Vector3.ZERO


func _ready() -> void:
	_build_housing()
	_build_leaf()
	_build_button()
	_build_marquee()
	_travel = 0.0
	_apply_travel()
	_refresh_lamp()
	set_process(true)


## Настраивается ДО add_child: _ready() строит геометрию по этим полям.
func configure(door_axis: String, doorway_span := 1.8, side := 1.0,
		inside := -1.0) -> void:
	axis = door_axis
	span = doorway_span
	button_side = 1.0 if side >= 0.0 else -1.0
	inside_sign = 1.0 if inside >= 0.0 else -1.0


func is_closed() -> bool:
	return _closed


func is_moving() -> bool:
	return (_closed and _travel < 1.0) or (not _closed and _travel > 0.0)


## Мировая точка кнопки: по ней GameManager решает, дотянется ли игрок.
func button_position() -> Vector3:
	return to_global(_button_local)


func toggle() -> bool:
	return set_closed(not _closed)


## Возвращает true, если состояние действительно изменилось. Обесточенная
## дверь отказывает механически, а отказ возвращается вызывающему, чтобы тот
## показал причину игроку, а не молчал.
func set_closed(value: bool) -> bool:
	if value == _closed:
		return false
	if value and not powered:
		return false
	_closed = value
	_refresh_lamp()
	return true


## Снятие питания роняет створку в открытое положение: обесточенный офис
## перестаёт быть убежищем — ради этого счётчик питания вообще существует.
func set_powered(value: bool) -> void:
	powered = value
	if not powered and _closed:
		_closed = false
	_refresh_lamp()


func _process(delta: float) -> void:
	var target := 1.0 if _closed else 0.0
	if is_equal_approx(_travel, target):
		return
	var step := delta / TRAVEL_TIME
	_travel = move_toward(_travel, target, step)
	_apply_travel()
	if is_equal_approx(_travel, target):
		state_changed.emit(_closed)


## 0.0 — открыта (створка в коробе), 1.0 — закрыта (створка в проёме).
func _apply_travel() -> void:
	if _leaf == null:
		return
	_leaf.position.y = CLOSED_Y + OPEN_LIFT * (1.0 - _travel)


func _build_housing() -> void:
	# Короб, в который уезжает створка. Без него дверь висит в воздухе и
	# читается как обломок, а не как механизм.
	var housing_size := _oriented(Vector3(LEAF_THICK + 0.14, 0.42, span + 0.44))
	_box(self, "Door Housing", Vector3(0, CLOSED_Y + OPEN_LIFT * 0.5 + 0.86, 0),
		housing_size, COL_HOUSING, false)
	var rail_size := _oriented(Vector3(LEAF_THICK + 0.10, LEAF_HEIGHT + 0.30, 0.10))
	for i in [-1.0, 1.0]:
		var offset := _along(i * (span * 0.5 + 0.11))
		_box(self, "Door Rail %d" % int(i), offset + Vector3(0, CLOSED_Y + 0.22, 0),
			rail_size, COL_RIB, false)


func _build_leaf() -> void:
	_leaf = Node3D.new()
	_leaf.name = "Leaf"
	add_child(_leaf)
	var leaf_size := _oriented(Vector3(LEAF_THICK, LEAF_HEIGHT, span + 0.16))
	_box(_leaf, "Leaf Plate", Vector3.ZERO, leaf_size, COL_LEAF, false)
	# Рёбра жёсткости поперёк створки: на PS1-геометрии это единственное, что
	# отличает бронестворку от чёрного прямоугольника.
	for i in range(4):
		var y := -LEAF_HEIGHT * 0.5 + 0.42 + float(i) * 0.58
		var rib_size := _oriented(Vector3(LEAF_THICK + 0.05, 0.11, span + 0.02))
		_box(_leaf, "Leaf Rib %d" % i, Vector3(0, y, 0), rib_size, COL_RIB, false)
	# Предупредительная кромка понизу — видно, где створка сядет на порог.
	var edge_size := _oriented(Vector3(LEAF_THICK + 0.06, 0.14, span + 0.16))
	_box(_leaf, "Leaf Edge", Vector3(0, -LEAF_HEIGHT * 0.5 + 0.07, 0),
		edge_size, COL_LAMP_SHUT, false, 0.25)
	# Коллайдер едет вместе со створкой: в открытом положении он оказывается
	# над проёмом и навмеш снова сходится сквозь дверь.
	var body := StaticBody3D.new()
	body.name = "Leaf Body"
	_leaf.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = leaf_size
	shape.shape = box
	body.add_child(shape)
	body.add_to_group(NAV_SOURCE_GROUP)


func _build_button() -> void:
	# Пульт на стене со стороны офиса: игрок должен дотянуться до него, не
	# выходя в проём, иначе кнопка требует шагнуть под то, от чего защищает.
	var lateral := span * 0.5 + BUTTON_CLEARANCE
	var depth := LEAF_THICK * 0.5 + 0.09
	_button_local = _along(button_side * lateral) \
		+ _across(inside_sign * depth) + Vector3(0, BUTTON_HEIGHT, 0)
	# Панель сделана ЗАМЕТНО крупнее первой версии (было 0.34 x 0.26 м —
	# размер ладони на чёрной стене в неосвещённом офисе). Промышленный
	# пульт и в жизни размером с лист бумаги: его ищут в темноте рукой.
	var plate_size := _oriented(Vector3(0.07, 0.54, 0.42))
	_box(self, "Door Button Plate", _button_local, plate_size, COL_PANEL, false)
	# Светлая обводка по контуру пульта: отбивает панель от стены, когда
	# обе почти чёрные. Без неё кнопка сливалась с отделкой.
	var bezel_size := _oriented(Vector3(0.06, 0.60, 0.48))
	_box(self, "Door Button Bezel", _button_local + _across(inside_sign * -0.005),
		bezel_size, COL_KEY.darkened(0.45), false, 0.10)
	var key_size := _oriented(Vector3(0.05, 0.26, 0.26))
	_box(self, "Door Button Key",
		_button_local + _across(inside_sign * 0.06) + Vector3(0, -0.07, 0),
		key_size, COL_KEY, false, 0.15)
	# ТА ЖЕ ЛАМПА, ЧТО И НА КОМПЬЮТЕРЕ. Была плоская плашка 0.12 × 0.30 —
	# единственная в своём роде во всём здании. Теперь это штатный индикатор
	# станции, только увеличенный вчетверо: пульт ищут в темноте с двух метров.
	# live = true: эта лампа переключается, значит материал ей нужен свой.
	_lamp = Lamp.build(self, "Door Button Lamp",
		_button_local + _across(inside_sign * 0.055) + Vector3(0, 0.17, 0),
		COL_LAMP_OPEN, Lamp.ENERGY_ALERT, _across(inside_sign), 4.0, true)
	_lamp_material = Lamp.lens_material(_lamp)
	if _lamp_material != null:
		_signals.append(_lamp_material)


## Табло над проёмом — две светящиеся полосы, по одной с каждой стороны стены.
## Обе стороны обязательны: игрок подходит к офису из Атриума и должен видеть,
## что впереди закрытая створка, ЕЩЁ ДО того, как упрётся в неё лицом.
func _build_marquee() -> void:
	var band_size := _oriented(Vector3(MARQUEE_THICK, MARQUEE_BAND, span + 0.30))
	var reach := LEAF_THICK * 0.5 + 0.10
	for i in [-1.0, 1.0]:
		var band := _box(self, "Door Marquee %d" % int(i),
			_across(i * reach) + Vector3(0, MARQUEE_HEIGHT, 0),
			band_size, COL_LAMP_OPEN, false, 1.6)
		var material := band.material_override as StandardMaterial3D
		if material != null:
			_signals.append(material)


## Состояние двери никогда не передаётся ОДНИМ цветом: указатели меняют и цвет,
## и яркость, а рядом с ними стоит физически видимая створка. Дальтоник читает
## дверь по створке, а в темноте — по светимости табло.
func _refresh_lamp() -> void:
	var color := COL_LAMP_OPEN
	var energy := 0.9
	if not powered:
		color = COL_LAMP_DEAD
		energy = 0.0
	elif _closed:
		color = COL_LAMP_SHUT
		energy = 2.1
	for material in _signals:
		if material == null:
			continue
		material.albedo_color = color
		material.emission = color
		material.emission_energy_multiplier = energy
		material.emission_enabled = energy > 0.0


## Разворот размера под ось проёма: в локальных осях створка всегда «тонкая
## по X, широкая по Z», а для стены восток-запад это надо поменять местами.
func _oriented(size: Vector3) -> Vector3:
	if axis == "x":
		return Vector3(size.z, size.y, size.x)
	return size


## Смещение ВДОЛЬ стены (поперёк прохода).
func _along(distance: float) -> Vector3:
	if axis == "x":
		return Vector3(distance, 0, 0)
	return Vector3(0, 0, distance)


## Смещение ПОПЕРЁК стены (вдоль прохода). Отрицательное — в сторону офиса.
func _across(distance: float) -> Vector3:
	if axis == "x":
		return Vector3(0, 0, distance)
	return Vector3(distance, 0, 0)


func _box(parent: Node, node_name: String, box_position: Vector3,
		size: Vector3, color: Color, with_collision := true,
		emission_energy := 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = box_position
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	material.metallic = 0.18
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	instance.material_override = material
	parent.add_child(instance)
	if with_collision:
		var body := StaticBody3D.new()
		body.name = "%s Body" % node_name
		instance.add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		body.add_to_group(NAV_SOURCE_GROUP)
	return instance
