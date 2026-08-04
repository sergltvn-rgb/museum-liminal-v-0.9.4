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
	if not Lib.FLAT_STYLE:
		print("[FAIL] MaterialLib.FLAT_STYLE выключен")
		failures += 1

	# Generic probe: procedural callers rely on the helper itself, not on the
	# setup performed inside get_material().
	var probe := StandardMaterial3D.new()
	var probe_texture := NoiseTexture2D.new()
	probe.metallic = 0.8
	probe.metallic_specular = 0.9
	probe.roughness = 0.2
	probe.normal_enabled = true
	probe.normal_texture = probe_texture
	probe.roughness_texture = probe_texture
	probe.ao_enabled = true
	probe.ao_texture = probe_texture
	probe.metallic_texture = probe_texture
	probe.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var helper_applied := Lib.apply_flat_style(probe)
	var helper_ok := (
		helper_applied
		and is_zero_approx(probe.metallic)
		and is_equal_approx(probe.roughness, float(Lib.FLAT_ROUGHNESS))
		and is_equal_approx(probe.metallic_specular, float(Lib.FLAT_SPECULAR))
		and not probe.normal_enabled
		and probe.normal_texture == null
		and probe.roughness_texture == null
		and not probe.ao_enabled
		and probe.ao_texture == null
		and probe.metallic_texture == null
		and probe.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	)
	if not helper_ok:
		failures += 1
	print("%s procedural helper очищает PBR slots и выставляет nearest" % (
		"[OK]" if helper_ok else "[FAIL]"
	))

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
		var flat_ok := (
			Lib.FLAT_STYLE
			and is_zero_approx(mat.metallic)
			and is_equal_approx(mat.roughness, float(Lib.FLAT_ROUGHNESS))
			and is_equal_approx(mat.metallic_specular, float(Lib.FLAT_SPECULAR))
			and not mat.normal_enabled
			and mat.normal_texture == null
			and mat.roughness_texture == null
			and not mat.ao_enabled
			and mat.ao_texture == null
			and mat.metallic_texture == null
			and mat.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		)
		if not flat_ok:
			failures += 1
		var mark := "OK " if has_albedo and lost.is_empty() and flat_ok else "✗  "
		print("%s%-16s карт: %s | flat %s | трипланар %s | масштаб %.2f м" % [
			mark,
			pack_name,
			", ".join(found),
			str(flat_ok),
			str(mat.uv1_triplanar),
			float(pack["scale"]),
		])
		for entry in lost:
			print("      ПОТЕРЯНО: ", entry)

	print("---")
	print("Плоский режим: %s | roughness %.2f | specular %.2f" % [
		str(Lib.FLAT_STYLE), Lib.FLAT_ROUGHNESS, Lib.FLAT_SPECULAR
	])
	print("Проверено карт: %d, наборов: %d, ошибок: %d" % [
		checked, Lib.PACKS.size(), failures
	])
	if failures > 0:
		print("[FAIL] библиотека материалов неполная")
		quit(1)
		return
	print("[OK] все наборы собрались")
	quit(0)
