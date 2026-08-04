extends SceneTree
## Съёмка РАБОЧЕГО СТОЛА терминала для глазной приёмки окон.
##
## Запускать ТОЛЬКО с рендером, без --headless (иначе кадры пустые):
##   Godot --path . --script res://game/test_ui_capture.gd
##
## Зачем он есть. Окно протокола рвало свою рамку: содержимое выше слота
## выкладывалось ниже окна, поверх соседних окон и панели задач. Ни один
## текстовый тест этого не ловит, поэтому здесь две проверки сразу: кадр
## глазами и численная — каждый потомок окна обязан лежать внутри его прямо-
## угольника. Число держит регрессию, картинка ловит то, что число не видит.
##
## Всё через preload и has_method, а не через имена классов: в голом
## --script-прогоне глобальные `class_name` не зарегистрированы (раздел 14 плана).

const Shots := preload("res://game/AgentShots.gd")

const OUT_DIR := "res://shots/ui_after"


func _init() -> void:
	print("[UI CAPTURE] start")
	call_deferred("_capture_flow")


func _capture_flow() -> void:
	var main_scene: PackedScene = load("res://scenes/FirstMuseumMap.tscn")
	var map_instance: Node = main_scene.instantiate()
	root.add_child(map_instance)
	paused = false

	for m in get_nodes_in_group("menu_manager"):
		m.queue_free()

	for i in range(40):
		await create_timer(0.033).timeout

	# Снять вступительную катсцену: она держит свой оверлей поверх всего.
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

	var gm := _find_node(map_instance, "_enter_workstation")
	if gm == null:
		push_error("[UI CAPTURE] GameManager не найден")
		quit()
		return

	# Происшествие сначала, стол потом: до первого прорыва окно протокола
	# свёрнуто в панель задач и снимать было бы нечего — а весь спрос именно
	# к тому, как ложится длинный отчёт внутри рамки.
	if gm.has_method("_start_accident"):
		gm.call("_start_accident")
		print("[UI CAPTURE] accident started")
	gm.call("_enter_workstation")

	# Окна встают в очередь появления (REVEAL_DELAY 1.35 на каждое), поэтому
	# ждём с запасом: кадр до конца очереди показал бы полпустой стол.
	for i in range(200):
		await create_timer(0.033).timeout

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var gdignore := FileAccess.open(OUT_DIR + "/.gdignore", FileAccess.WRITE)
	if gdignore != null:
		gdignore.close()

	var vp := root.get_viewport()
	var img := vp.get_texture().get_image()
	var res := Shots.save_set(img, OUT_DIR, "ui_desktop", 0)
	Shots.report(res, "UI CAPTURE")

	_check_windows(map_instance)

	print("[UI CAPTURE] done")
	quit()


## Первый узел в поддереве, у которого есть нужный метод.
func _find_node(from: Node, method: String) -> Node:
	if from.has_method(method):
		return from
	for child in from.get_children():
		var hit := _find_node(child, method)
		if hit != null:
			return hit
	return null


## ГЛАВНАЯ ПРОВЕРКА: ни один потомок окна не выходит за его рамку.
##
## Считается в глобальных координатах, потому что именно так их видит глаз:
## вылезший отчёт на скриншоте был ровно таким прямоугольником, торчащим ниже
## рамки. Допуск 1 пиксель — на округление при масштабировании.
func _check_windows(from: Node) -> void:
	var windows: Array[Control] = []
	_collect_windows(from, windows)
	print("[UI CAPTURE] windows found: %d" % windows.size())
	var bad := 0
	for w in windows:
		# Обходится ВСЁ поддерево, а не прямые дети. Прямых детей у окна два —
		# колонка во всю рамку и уголок, они не вылезали никогда. Вылезал отчёт,
		# лежащий на три уровня глубже, поэтому проверка по первому уровню не
		# поймала бы и исходную поломку.
		# В прокручиваемое поддерево НЕ спускаемся. Там содержимое обязано быть
		# выше окна — иначе прокручивать было бы нечего, а рисование там режет
		# и сама прокрутка, и clip_contents окна. Спрашиваем только с того, что
		# рисуется без обрезки: шапка, кнопки, линейка, низ, уголок и сама
		# полоса прокрутки.
		var frame := Rect2(w.global_position, w.size)
		# Обход начинается С ДЕТЕЙ, а не с самого окна: окно теперь само
		# обрезающее, и обход от него остановился бы на первом же шаге —
		# проверка вышла бы пустой и зелёной по лжи.
		var kids: Array[Control] = []
		for child in w.get_children():
			_collect_controls(child, kids)
		var scrolled := 0
		for c in kids:
			if c is ScrollContainer:
				scrolled += 1
		if scrolled > 0:
			print("[UI CAPTURE] %s: прокруток %d" % [w.name, scrolled])
		for c in kids:
			if c == w:
				continue
			# Невидимое не рисуется и не может вылезти в кадр.
			if not c.is_visible_in_tree():
				continue
			var box := Rect2(c.global_position, c.size)
			var over_x: float = maxf(0.0, box.end.x - frame.end.x) + maxf(0.0, frame.position.x - box.position.x)
			var over_y: float = maxf(0.0, box.end.y - frame.end.y) + maxf(0.0, frame.position.y - box.position.y)
			if over_x > 1.0 or over_y > 1.0:
				bad += 1
				print("[UI CAPTURE] ✗ %s/%s выходит за рамку на %.1f x %.1f px"
					% [w.name, c.name, over_x, over_y])
	if bad == 0:
		print("[UI CAPTURE] [OK] всё содержимое лежит внутри своих окон")
	else:
		print("[UI CAPTURE] FAILED: %d вылезаний" % bad)


## Окно узнаётся по своему же API (toggle_maximized + поле body), а не по
## глобальному имени класса, которого в --script-прогоне нет.
func _collect_controls(from: Node, out: Array[Control]) -> void:
	if from is Control:
		out.append(from as Control)
		# Обрезающий узел — граница обхода: его потомки физически не могут
		# нарисоваться за ним, сколь бы большим ни был их прямоугольник.
		if from is ScrollContainer or (from as Control).clip_contents:
			return
	for child in from.get_children():
		_collect_controls(child, out)


func _collect_windows(from: Node, out: Array[Control]) -> void:
	if from is Control and from.has_method("toggle_maximized"):
		out.append(from as Control)
	for child in from.get_children():
		_collect_windows(child, out)
