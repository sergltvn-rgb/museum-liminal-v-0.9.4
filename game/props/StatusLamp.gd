extends RefCounted
class_name StatusLamp

## СИГНАЛЬНАЯ ЛАМПА СТАНЦИИ — ОДНА МОДЕЛЬ НА ВЕСЬ МУЗЕЙ.
##
## Что было: каждый билдер рисовал индикатор сам и по-своему. Лампа на пульте
## двери была плоским бруском 0.04×0.12×0.30 с яркостью 2.2, диод башни — бруском
## 0.016×0.008×0.006 с яркостью 2.4, лампа зарядки планшета — третьим бруском с яркостью
## 1.2, чайник — четвёртым. В кадре это читалось как четыре разные вещи из четырёх
## разных игр, а не как оборудование одного здания одного года выпуска.
##
## Что стало: одна геометрия везде — утопленная в корпус обойма и выпуклая
## линза над ней. Меняется ТОЛЬКО цвет, яркость и общий масштаб: лампа на
## дверном пульте — та же самая лампа, что и на башне компьютера, просто крупнее.
##
## ЦВЕТ НИКОГДА НЕ ЕДИНСТВЕННЫЙ ПРИЗНАК. Вместе с цветом всегда меняется
## яркость (ENERGY_*), а рядом стоит то, что видно без цвета вообще: створка,
## текст, табло.
##
## Локальный кадр: начало — точка на поверхности корпуса, куда лампа врезана;
## `facing` — куда она смотрит. Линза выступает вдоль facing, обойма утоплена.

## Геометрия базового (scale = 1) индикатора — приборный диод около 2 см.
const BEZEL_RADIUS := 0.014
const BEZEL_DEPTH := 0.008
const LENS_RADIUS := 0.0092
const LENS_SQUASH := 0.62

## Три яркости на всю игру. Своя цифра у каждого билдера означала, что два
## одинаково важных диода горели по-разному без всякой причины.
const ENERGY_ALERT := 2.2
const ENERGY_ON := 1.4
const ENERGY_IDLE := 0.8
const ENERGY_DEAD := 0.0

## Канонные цвета индикации. Те же семь тонов, что у UITheme, но в 3D:
## зелёный — норма, янтарный — внимание, красный — тревога, серый — мёртвая.
# Только через preload: глобальное имя класса в голом --script-прогоне не
# регистрируется и вся цепочка падает (раздел 14 плана).
const Pal := preload("res://game/props/Palette.gd")

# Лампа состояния — ровно тот случай, ради которого в палитре есть сигнальные
# цвета: три состояния берутся один в один, без своих литералов.
static var COL_BEZEL := Pal.tone(Pal.SHELL, -0.13)
const COL_OK := Pal.MOSS
const COL_WARN := Pal.LED_AMBER
const COL_ALERT := Pal.RUST
static var COL_DEAD := Pal.tone(Pal.STEEL_DARK, 0.07)

## Материалы кэшируются по цвету и яркости, но ТОЛЬКО для ламп, которые не
## меняются: общий материал у управляемой лампы перекрасил бы все остальные
## вместе с ней — все диоды музея стали бы красными от одной закрытой створки.
static var _shared: Dictionary = {}
static var _bezel_material: StandardMaterial3D = null


## Поставить лампу. Возвращает корень — его можно двигать и гасить целиком.
##
## `live` — лампа, которую кто-то будет переключать через set_state(): ей выдаётся
## собственный материал вместо общего.
static func build(parent: Node3D, node_name: String, lamp_position: Vector3,
		color: Color, energy := ENERGY_ON, facing := Vector3(0, 0, 1),
		lamp_scale := 1.0, live := false) -> Node3D:
	var root := Node3D.new()
	if parent.has_node(NodePath(node_name)):
		node_name = "%s %s" % [node_name, lamp_position]
	root.name = node_name
	root.transform = Transform3D(_aim(facing), lamp_position)
	root.scale = Vector3.ONE * maxf(0.05, lamp_scale)
	parent.add_child(root)

	var bezel_mesh := CylinderMesh.new()
	bezel_mesh.height = BEZEL_DEPTH
	bezel_mesh.top_radius = BEZEL_RADIUS
	bezel_mesh.bottom_radius = BEZEL_RADIUS
	bezel_mesh.radial_segments = 10
	bezel_mesh.rings = 1
	var bezel := MeshInstance3D.new()
	bezel.name = "Bezel"
	bezel.mesh = bezel_mesh
	bezel.position = Vector3(0, BEZEL_DEPTH * 0.5, 0)
	bezel.material_override = _bezel()
	bezel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bezel)

	var lens_mesh := SphereMesh.new()
	lens_mesh.radius = LENS_RADIUS
	lens_mesh.height = LENS_RADIUS * 2.0
	lens_mesh.radial_segments = 10
	lens_mesh.rings = 5
	var lens := MeshInstance3D.new()
	lens.name = "Lens"
	lens.mesh = lens_mesh
	# Линза сплющена вдоль оси лампы: шарик на панели читается как бусина,
	# а не как вклеенный в корпус индикатор.
	lens.scale = Vector3(1.0, LENS_SQUASH, 1.0)
	lens.position = Vector3(0, BEZEL_DEPTH + LENS_RADIUS * LENS_SQUASH * 0.55, 0)
	lens.material_override = _lens_material(color, energy, live)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lens)
	return root


## Материал линзы готовой лампы. Тот, кто держит свой список индикаторов
## (например OfficeDoor), берёт материал отсюда, а не лезет в узлы руками.
static func lens_material(lamp: Node) -> StandardMaterial3D:
	if lamp == null or not is_instance_valid(lamp):
		return null
	var lens := lamp.get_node_or_null("Lens") as MeshInstance3D
	if lens == null:
		return null
	return lens.material_override as StandardMaterial3D


## Переключить лампу. Работает только для ламп, собранных с live = true.
static func set_state(lamp: Node, color: Color, energy: float) -> void:
	apply(lens_material(lamp), color, energy)


## Та же операция над готовым материалом: одно место, где решается, как
## выглядит погасший индикатор во всём здании.
static func apply(material: StandardMaterial3D, color: Color,
		energy: float) -> void:
	if material == null:
		return
	material.albedo_color = color if energy > 0.0 else color.darkened(0.35)
	material.emission = color
	material.emission_energy_multiplier = energy
	material.emission_enabled = energy > 0.0


static func _lens_material(color: Color, energy: float,
		live: bool) -> StandardMaterial3D:
	var key := "%s:%s" % [color.to_html(true), energy]
	if not live and _shared.has(key):
		return _shared[key]
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.24
	mat.metallic = 0.0
	apply(mat, color, energy)
	if not live:
		_shared[key] = mat
	return mat


static func _bezel() -> StandardMaterial3D:
	if _bezel_material != null:
		return _bezel_material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COL_BEZEL
	mat.roughness = 0.78
	mat.metallic = 0.22
	_bezel_material = mat
	return mat


## Ориентация: локальная ось +Y смотрит вдоль facing. Цилиндр и сфера в
## Godot строятся вдоль Y, поэтому разворачивается КОРЕНЬ, а не каждый меш.
static func _aim(direction: Vector3) -> Basis:
	var up := direction
	if up.length_squared() < 0.000001:
		up = Vector3(0, 0, 1)
	up = up.normalized()
	var reference := Vector3.UP
	if absf(up.dot(Vector3.UP)) > 0.95:
		reference = Vector3.RIGHT
	var side := reference.cross(up).normalized()
	var forward := up.cross(side).normalized()
	return Basis(side, up, forward)
