extends SceneTree
## Съёмка ночного света для глазной оценки яркости.
##
## Запускать ТОЛЬКО с рендером, без --headless (иначе кадры пустые):
##   Godot --path . --script res://game/test_night_capture.gd
##
## Сценарий строит карту, гасит меню и вступительную катсцену, вручную
## зовёт `_trigger_blackout()` — ту же самую функцию, что срабатывает в игре,
## поэтому свет на кадрах ровно такой, какой увидит игрок ночью.
##
## Всё через preload, а не через имена классов: в голом --script-прогоне
## глобальные `class_name` не зарегистрированы (раздел 14 плана).

const Shots := preload("res://game/AgentShots.gd")

const OUT_DIR := "res://shots/night_after"

## Имя, позиция камеры, точка взгляда. Глаз на 1.65 — рост игрока.
const FRAMES := [
	["night_office", Vector3(-20.0, 1.65, 3.0), Vector3(-32.0, 1.40, -2.0)],
	["night_atrium", Vector3(0.0, 1.65, 9.0), Vector3(0.0, 1.50, -6.0)],
	["night_lobby", Vector3(0.0, 1.65, 27.0), Vector3(0.0, 1.50, 13.0)],
	["night_corridor", Vector3(-14.0, 1.65, 0.0), Vector3(-2.0, 1.45, 0.0)],
]


func _init() -> void:
	print("[NIGHT CAPTURE] start")
	call_deferred("_capture_flow")


func _capture_flow() -> void:
	var main_scene: PackedScene = load("res://scenes/FirstMuseumMap.tscn")
	var map_instance: Node = main_scene.instantiate()
	root.add_child(map_instance)
	paused = false

	for c in map_instance.get_children():
		if c.name.begins_with("MenuManager"):
			c.queue_free()
	for m in get_nodes_in_group("menu_manager"):
		m.queue_free()

	for i in range(40):
		await create_timer(0.033).timeout

	# Снять вступительную катсцену, иначе она ведёт камеру сама.
	var map_node := map_instance
	for _hop in range(10):
		var playing: Node = null
		for child in map_instance.get_children():
			if child.has_method("is_playing") and bool(child.call("is_playing")):
				playing = child
				break
		if playing == null:
			break
		if playing.has_method("skip"):
			playing.call("skip")
		await create_timer(0.05).timeout

	# Ночь. Та же функция, что и в игре: гасит сетевой свет, поднимает
	# аварийку, ставит ночной профиль тумана и ночное небо.
	if map_node.has_method("_trigger_blackout"):
		map_node.call("_trigger_blackout")
		print("[NIGHT CAPTURE] blackout triggered")
	else:
		push_error("[NIGHT CAPTURE] _trigger_blackout не найден")

	# Дверь едет 1.15 с, плюс пульсация аварийной лампы и туман.
	for i in range(60):
		await create_timer(0.033).timeout

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var gdignore := FileAccess.open(OUT_DIR + "/.gdignore", FileAccess.WRITE)
	if gdignore != null:
		gdignore.close()

	var vp := root.get_viewport()
	var cam := vp.get_camera_3d()
	if cam == null:
		push_error("[NIGHT CAPTURE] камера не найдена")
		quit()
		return

	for frame: Array in FRAMES:
		var name: String = frame[0]
		cam.look_at_from_position(frame[1], frame[2])
		for i in range(20):
			await create_timer(0.033).timeout
		var img := vp.get_texture().get_image()
		# tiles = 0: сейчас судим об общей яркости кадра, а не о мелкой детали,
		# и четыре кадра должны влезть в бюджет чтения за один проход.
		var res := Shots.save_set(img, OUT_DIR, name, 0)
		Shots.report(res, "NIGHT CAPTURE")
		# Средняя яркость кадра в числах: глаз по JPEG обманывается,
		# а решение «поднять на столько-то» надо на что-то опереть.
		print("[NIGHT CAPTURE] %s luma=%.4f" % [name, _mean_luma(img)])

	print("[NIGHT CAPTURE] done")
	quit()


## Средняя яркость по сетке 32x18 точек. Полный проход по пикселям из GDScript
## стоит секунды; выборки хватает, чтобы сравнить «до» и «после».
func _mean_luma(img: Image) -> float:
	var w := img.get_width()
	var h := img.get_height()
	if w == 0 or h == 0:
		return 0.0
	var total := 0.0
	var count := 0
	for row in range(18):
		for col in range(32):
			var x: int = mini(int(float(col) / 32.0 * float(w)), w - 1)
			var y: int = mini(int(float(row) / 18.0 * float(h)), h - 1)
			var c := img.get_pixel(x, y)
			total += 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			count += 1
	return total / float(count)
