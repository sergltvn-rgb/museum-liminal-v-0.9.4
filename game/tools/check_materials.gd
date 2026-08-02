extends SceneTree

## Проверка библиотеки материалов: все ли карты на месте и собирается ли
## материал целиком.
##
## Смысл в том, что отсутствующая карта НЕ роняет игру: MaterialLib тихо
## отдаёт однотонный материал, и потеря вскроется только глазом на
## скриншоте — через десять шагов работы. Этот скрипт ловит её сразу.
##
## Запуск:
##   godot --headless --path . --script res://game/tools/check_materials.gd

# preload, а не глобальное имя MaterialLib: глобальные class_name регистрирует
# только импорт проекта, а голый --script его не выполняет.
const Lib := preload("res://game/props/MaterialLib.gd")


func _init() -> void:
	var failures := 0
	var checked := 0
	for pack_name in Lib.PACKS:
		var pack: Dictionary = Lib.PACKS[pack_name]
		var found: Array[String] = []
		var lost: Array[String] = []
		for slot in ["col", "nrm", "rough", "ao", "metal"]:
			var file_name := String(pack.get(slot, ""))
			if file_name.is_empty():
				continue
			checked += 1
			var path: String = Lib.TEX_ROOT + String(pack["dir"]) + "/" + file_name
			if ResourceLoader.exists(path):
				found.append(slot)
			else:
				lost.append(slot + " -> " + path)
				failures += 1
		var mat := Lib.get_material(pack_name)
		# Главный признак успеха — альбедо-текстура на месте: без неё
		# библиотека отдаёт запасной однотонный материал.
		var has_albedo: bool = mat.albedo_texture != null
		if not has_albedo:
			failures += 1
		var mark := "OK " if has_albedo and lost.is_empty() else "✗  "
		print("%s%-16s карт: %s | трипланар %s | масштаб %.2f м" % [
			mark,
			pack_name,
			", ".join(found),
			str(mat.uv1_triplanar),
			float(pack["scale"]),
		])
		for entry in lost:
			print("      ПОТЕРЯНО: ", entry)

	print("---")
	print("Проверено карт: %d, наборов: %d, ошибок: %d" % [
		checked, Lib.PACKS.size(), failures
	])
	if failures > 0:
		print("[FAIL] библиотека материалов неполная")
		quit(1)
		return
	print("[OK] все наборы собрались")
	quit(0)
