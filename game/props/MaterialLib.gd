@tool
class_name MaterialLib
extends RefCounted

## Библиотека PBR-материалов на фототекстурах из textures/.
##
## До этого файла весь музей был покрашен плоским цветом или процедурным
## шумом (см. GroundsProps._material). Шум даёт грязцу и разнотон, но не даёт
## структуры: у шума нет швов между плитами, нет прожилок камня, нет сколов
## по кромке. Именно эти три вещи глаз читает как "дорогой материал", и именно
## их приносят фотосканы.
##
## ТРИПЛАНАР ПО УМОЛЧАНИЮ. Весь музей собран из BoxMesh разного размера, а у
## BoxMesh развёртка всегда 0..1 на грань. Обычный UV растянул бы одну плитку
## на всю 30-метровую стену и сжал её же в точку на плинтусе. Трипланар
## считает координату от мира, поэтому размер плитки одинаков на любом ящике
## без единой правки геометрии. Цена — три выборки текстуры вместо одной;
## для мелких предметов его можно гасить через triplanar = false.
##
## Масштаб (scale) — СКОЛЬКО МЕТРОВ ЗАНИМАЕТ ОДИН КВАДРАТ ТЕКСТУРЫ.
## Так читать удобнее, чем через uv1_scale: "плита травертина 2.4 м" — это
## физическая величина, которую можно сверить с реальным полом в музее.

const TEX_ROOT := "res://textures/"

# Паспорта наборов. Имена файлов разные, потому что источники разные
# (ambientCG пишет COL/NRM/AO, Poliigon — BaseColor/Normal/Roughness), поэтому
# каждый набор описан явно, а не угадывается по шаблону.
#   dir      — папка набора в textures/
#   col/nrm/rough/ao/metal — имена карт (пустая строка = карты нет)
#   scale    — метров на квадрат текстуры по умолчанию
#   metallic — множитель металличности, если карты металла нет
const PACKS := {
	"travertine": {
		"dir": "TilesTravertine001",
		"col": "TilesTravertine001_COL_2K.jpg",
		"nrm": "TilesTravertine001_NRM_2K.jpg",
		"rough": "TilesTravertine001_ROUGH_2K.jpg",
		"ao": "TilesTravertine001_AO_2K.jpg",
		"metal": "",
		"scale": 2.4,
		"metallic": 0.0,
	},
	"mosaic": {
		"dir": "TilesMosaicYubi003",
		"col": "TilesMosaicYubi003_COL_2K.png",
		"nrm": "TilesMosaicYubi003_NRM_2K.png",
		"rough": "TilesMosaicYubi003_ROUGH_2K.jpg",
		"ao": "TilesMosaicYubi003_AO_2K.png",
		"metal": "",
		"scale": 1.2,
		"metallic": 0.0,
	},
	"quartzite": {
		"dir": "Poliigon_StoneQuartzite_8060",
		"col": "Poliigon_StoneQuartzite_8060_BaseColor.jpg",
		"nrm": "Poliigon_StoneQuartzite_8060_Normal.png",
		"rough": "Poliigon_StoneQuartzite_8060_Roughness.jpg",
		"ao": "Poliigon_StoneQuartzite_8060_AmbientOcclusion.jpg",
		"metal": "Poliigon_StoneQuartzite_8060_Metallic.jpg",
		"scale": 3.0,
		"metallic": 0.0,
	},
	"concrete": {
		"dir": "Poliigon_ConcreteWorn_8690",
		"col": "Poliigon_ConcreteWorn_8690_BaseColor.jpg",
		"nrm": "Poliigon_ConcreteWorn_8690_Normal.png",
		"rough": "Poliigon_ConcreteWorn_8690_Roughness.jpg",
		"ao": "Poliigon_ConcreteWorn_8690_AmbientOcclusion.jpg",
		"metal": "Poliigon_ConcreteWorn_8690_Metallic.jpg",
		"scale": 4.0,
		"metallic": 0.0,
	},
	"steel": {
		"dir": "Poliigon_MetalSteelBrushed_7174",
		"col": "Poliigon_MetalSteelBrushed_7174_BaseColor.jpg",
		"nrm": "Poliigon_MetalSteelBrushed_7174_Normal.png",
		"rough": "Poliigon_MetalSteelBrushed_7174_Roughness.jpg",
		"ao": "Poliigon_MetalSteelBrushed_7174_AmbientOcclusion.jpg",
		"metal": "Poliigon_MetalSteelBrushed_7174_Metallic.jpg",
		"scale": 1.6,
		"metallic": 1.0,
	},
	"painted_metal": {
		"dir": "Poliigon_MetalPaintedMatte_7037",
		"col": "Poliigon_MetalPaintedMatte_7037_BaseColor.jpg",
		"nrm": "Poliigon_MetalPaintedMatte_7037_Normal.png",
		"rough": "Poliigon_MetalPaintedMatte_7037_Roughness.jpg",
		"ao": "Poliigon_MetalPaintedMatte_7037_AmbientOcclusion.jpg",
		"metal": "Poliigon_MetalPaintedMatte_7037_Metallic.jpg",
		"scale": 2.0,
		"metallic": 0.0,
	},
	"corroded_metal": {
		"dir": "MetalCorrodedHeavy001",
		"col": "MetalCorrodedHeavy001_COL_2K_METALNESS.jpg",
		"nrm": "MetalCorrodedHeavy001_NRM_2K_METALNESS.jpg",
		"rough": "MetalCorrodedHeavy001_ROUGHNESS_2K_METALNESS.jpg",
		"ao": "",
		"metal": "MetalCorrodedHeavy001_METALNESS_2K_METALNESS.jpg",
		"scale": 2.2,
		"metallic": 1.0,
	},
	"window_grime": {
		"dir": "DirtWindowStains005",
		"col": "DirtWindowStains005_COL_2K.jpg",
		"nrm": "DirtWindowStains005_NRM_2K.jpg",
		"rough": "DirtWindowStains005_ROUGH_2K.jpg",
		"ao": "",
		"metal": "",
		"scale": 3.2,
		"metallic": 0.0,
	},
	"rust": {
		"dir": "Poliigon_MetalRust_7642",
		"col": "Poliigon_MetalRust_7642_BaseColor.jpg",
		"nrm": "Poliigon_MetalRust_7642_Normal.png",
		"rough": "Poliigon_MetalRust_7642_Roughness.jpg",
		"ao": "Poliigon_MetalRust_7642_AmbientOcclusion.jpg",
		"metal": "Poliigon_MetalRust_7642_Metallic.jpg",
		"scale": 1.8,
		"metallic": 1.0,
	},
	"plastic_dry": {
		"dir": "Poliigon_PlasticMoldDryBlast_7495",
		"col": "Poliigon_PlasticMoldDryBlast_7495_BaseColor.jpg",
		"nrm": "Poliigon_PlasticMoldDryBlast_7495_Normal.png",
		"rough": "Poliigon_PlasticMoldDryBlast_7495_Roughness.jpg",
		"ao": "Poliigon_PlasticMoldDryBlast_7495_AmbientOcclusion.jpg",
		"metal": "",
		"scale": 0.9,
		"metallic": 0.0,
	},
	"plastic_worn": {
		"dir": "Poliigon_PlasticMoldWorn_7486",
		"col": "Poliigon_PlasticMoldWorn_7486_BaseColor.jpg",
		"nrm": "Poliigon_PlasticMoldWorn_7486_Normal.png",
		"rough": "Poliigon_PlasticMoldWorn_7486_Roughness.jpg",
		"ao": "Poliigon_PlasticMoldWorn_7486_AmbientOcclusion.jpg",
		"metal": "",
		"scale": 1.1,
		"metallic": 0.0,
	},
	"dirt": {
		"dir": "GroundDirtRocky020",
		"col": "GroundDirtRocky020_COL_2K.jpg",
		"nrm": "GroundDirtRocky020_NRM_2K.jpg",
		"rough": "GroundDirtRocky020_ROUGH_2K.jpg",
		"ao": "GroundDirtRocky020_AO_2K.jpg",
		"metal": "",
		"scale": 2.6,
		"metallic": 0.0,
	},
	"asphalt": {
		"dir": "CityStreetAsphaltGenericClean001",
		"col": "CityStreetAsphaltGenericClean001_COL_2K.jpg",
		"nrm": "CityStreetAsphaltGenericClean001_NRM_2K.jpg",
		"rough": "CityStreetAsphaltGenericClean001_ROUGH_2K.jpg",
		"ao": "CityStreetAsphaltGenericClean001_AO_2K.jpg",
		"metal": "",
		"scale": 4.0,
		"metallic": 0.0,
	},
	"wood": {
		"dir": "WoodProcedural",
		"col": "WoodOak_COL.jpg",
		"nrm": "WoodOak_NRM.png",
		"rough": "WoodOak_ROUGH.jpg",
		"ao": "",
		"metal": "",
		"scale": 1.2,
		"metallic": 0.0,
	},
}

# Готовые материалы и текстуры живут в статических кэшах. Без них каждая
# из тысяч плит вестибюля завела бы свою копию материала и свою пачку 2K-карт
# в видеопамяти, а рендер потерял бы всякий шанс на группировку вызовов.
static var _materials := {}
static var _textures := {}
static var _missing := {}


## Материал по имени набора.
##
## tint — подкраска альбедо (белый = оставить как есть). Один скан травертина
## так работает и тёплым полом вестибюля, и холодной стеной архива —
## без второго набора карт в памяти, потому что текстуры общие.
## scale — метров на квадрат текстуры; 0.0 берёт штатный для набора.
static func get_material(
	pack_name: String,
	tint: Color = Color.WHITE,
	scale: float = 0.0,
	triplanar: bool = true
) -> StandardMaterial3D:
	if not PACKS.has(pack_name):
		push_warning("MaterialLib: нет набора '%s'" % pack_name)
		return _fallback(tint)
	var pack: Dictionary = PACKS[pack_name]
	var metres: float = scale if scale > 0.0 else float(pack["scale"])
	var key := "%s|%s|%.3f|%s" % [pack_name, tint.to_html(false), metres, triplanar]
	if _materials.has(key):
		return _materials[key]

	var mat := StandardMaterial3D.new()
	mat.resource_name = "%s %s" % [pack_name, tint.to_html(false)]
	mat.albedo_color = tint
	mat.metallic = float(pack["metallic"])

	var albedo := _texture(pack, "col")
	if albedo == null:
		# Набор не распакован — лучше ровный цвет, чем розовый квадрат
		# "текстура не найдена" на полкомнаты.
		var plain := _fallback(tint)
		_materials[key] = plain
		return plain
	mat.albedo_texture = albedo

	var normal := _texture(pack, "nrm")
	if normal != null:
		mat.normal_enabled = true
		mat.normal_texture = normal
		mat.normal_scale = 1.0

	var rough := _texture(pack, "rough")
	if rough != null:
		mat.roughness_texture = rough
		mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE

	var ao := _texture(pack, "ao")
	if ao != null:
		mat.ao_enabled = true
		mat.ao_texture = ao
		mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
		# AO по каналу света, а не поверх альбедо: иначе швы чернеют даже
		# под прямым фонарём и пол читается грязным, а не рельефным.
		mat.ao_light_affect = 0.7

	var metal := _texture(pack, "metal")
	if metal != null:
		mat.metallic = 1.0
		mat.metallic_texture = metal
		mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE

	if triplanar:
		mat.uv1_triplanar = true
		var factor := 1.0 / maxf(metres, 0.05)
		mat.uv1_scale = Vector3(factor, factor, factor)
	else:
		mat.uv1_scale = Vector3.ONE

	# Анизотропия обязательна именно на полах: пол всегда виден под острым
	# углом, и обычный мипмаппинг смазывает его в кашу в двух метрах от игрока.
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	_materials[key] = mat
	return mat


## Навесить материал на готовый MeshInstance3D.
static func apply(
	mesh: MeshInstance3D,
	pack_name: String,
	tint: Color = Color.WHITE,
	scale: float = 0.0,
	triplanar: bool = true
) -> void:
	if mesh == null:
		return
	# Переопределение на уровне узла, а не меша: меши у нас переиспользуются
	# между десятками экземпляров, и запись в mesh.surface_set_material
	# перекрасила бы все сразу.
	mesh.material_override = get_material(pack_name, tint, scale, triplanar)


static func _texture(pack: Dictionary, slot: String) -> Texture2D:
	var file_name := String(pack.get(slot, ""))
	if file_name.is_empty():
		return null
	var path: String = TEX_ROOT + String(pack["dir"]) + "/" + file_name
	if _textures.has(path):
		return _textures[path]
	if not ResourceLoader.exists(path):
		# О каждой потеряшке ругаемся ровно один раз: при сборке карты этот
		# путь спрашивают сотни раз, и без фильтра лог становится нечитаем.
		if not _missing.has(path):
			_missing[path] = true
			push_warning("MaterialLib: нет текстуры %s" % path)
		_textures[path] = null
		return null
	var tex := load(path) as Texture2D
	_textures[path] = tex
	return tex


static func _fallback(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.9
	return mat


## Список недостающих карт — для проверочного скрипта.
static func missing_paths() -> Array:
	return _missing.keys()
