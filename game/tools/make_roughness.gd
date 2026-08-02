extends SceneTree

## Разовый конвертер: GLOSS -> ROUGH.
##
## Наборы ambientCG отдают карту блеска (GLOSS): белое = зеркало.
## StandardMaterial3D в Godot ждёт ровно обратное — карту шероховатости
## (ROUGHNESS), где белое = матовое. Скормить одну вместо другой нельзя:
## в материале нет галочки "инвертировать", и мрамор в вестибюле вышел бы
## отполированным до состояния зеркала, а поцарапанные места — единственным,
## что не блестит. Поэтому карты переворачиваются один раз здесь, а не
## каждый кадр в шейдере.
##
## Запуск (после распаковки архивов в textures/):
##   godot --headless --path . --script res://game/tools/make_roughness.gd
##
## Скрипт идемпотентен: готовый *_ROUGH_2K.jpg не переписывается, так что
## повторный прогон стоит ноль и его можно звать после любой новой распаковки.

const SOURCES := [
	"res://textures/TilesTravertine001/TilesTravertine001_GLOSS_2K.jpg",
	"res://textures/TilesMosaicYubi003/TilesMosaicYubi003_GLOSS_2K.png",
	"res://textures/DirtWindowStains005/DirtWindowStains005_GLOSS_2K.jpg",
	"res://textures/GroundDirtRocky020/GroundDirtRocky020_GLOSS_2K.jpg",
	"res://textures/CityStreetAsphaltGenericClean001/CityStreetAsphaltGenericClean001_GLOSS_2K.jpg",
]

# Качество JPEG для результата. Карта шероховатости — это плавные пятна без
# мелкой геометрии, артефакты сжатия на ней не читаются, поэтому 0.85 хватает
# с запасом и экономит десятки мегабайт против PNG.
const JPEG_QUALITY := 0.85


func _init() -> void:
	var made := 0
	var skipped := 0
	for source in SOURCES:
		var target: String = String(source).replace("_GLOSS_2K", "_ROUGH_2K")
		# Результат всегда JPEG, даже если исходник был PNG: разница на глаз
		# нулевая, а вес меньше на порядок.
		target = target.replace(".png", ".jpg")
		if FileAccess.file_exists(target):
			print("[skip] уже готово: ", target.get_file())
			skipped += 1
			continue
		if not FileAccess.file_exists(source):
			push_warning("нет исходника: %s" % source)
			continue
		var img := Image.load_from_file(source)
		if img == null:
			push_warning("не читается: %s" % source)
			continue
		# Приведение к RGB8 обязательно: буфер разворачивается побайтово, и
		# любой формат с 16 битами на канал дал бы мусор.
		if img.get_format() != Image.FORMAT_RGB8:
			img.convert(Image.FORMAT_RGB8)
		# Побайтовый разворот вместо get_pixel/set_pixel: карта 2K — это
		# 4.2 млн пикселей, поэлементный цикл на GDScript тянется минутами.
		var data := img.get_data()
		for i in data.size():
			data[i] = 255 - data[i]
		var flipped := Image.create_from_data(
			img.get_width(), img.get_height(), false, Image.FORMAT_RGB8, data
		)
		var err := flipped.save_jpg(target, JPEG_QUALITY)
		if err != OK:
			push_warning("не сохранилось (%d): %s" % [err, target])
			continue
		print("[ok] %s  %d x %d" % [target.get_file(), img.get_width(), img.get_height()])
		made += 1
	print("ROUGHNESS: собрано %d, пропущено %d" % [made, skipped])
	quit(0)
