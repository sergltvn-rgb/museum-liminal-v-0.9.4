extends Control
class_name DesktopShell

## РАБОЧИЙ СТОЛ МНЕМОС — ОБОЛОЧКА СТАНЦИИ НАБЛЮДЕНИЯ (блок 10).
##
## Что было: при прорыве содержания игроку в лицо вставала полноэкранная
## панель протокола, где бы он ни стоял. Это читалось как меню игры, а не как
## музейная система, и лишало смысла само рабочее место в офисе.
##
## Что стало: данные живут НА КОМПЬЮТЕРЕ. Сирена не показывает экран — она
## только открывает окна на столе, а увидит их только тот, кто вернётся в офис и
## сядет за монитор. Цена информации — время, проведённое спиной к двери.
##
## СТРУКТУРА (референсы 01 и 02):
##
##   обои ................ глухой SURFACE с сеткой, никаких картинок
##   верхняя строка ........ имя системы слева, ночь и часы смены справа
##   слой окон ............ DesktopWindow, порядок детей = порядок стопки
##   панель задач ......... по кнопке на окно, включая свёрнутые
##   стекло ............... CRTOverlay поверх всего, как у TerminalFrame
##
## Оболочка НЕ знает, что показывают её окна. Содержимое (отчёт протокола,
## CCTV, датчики) строят вызывающие и кладут в open_window().

## Высота верхней строки состояния.
const STATUS_HEIGHT := 26
## Высота панели задач.
const TASKBAR_HEIGHT := 30
## Горизонтальные поля в обеих полосах.
const BAR_PAD_X := 10
## Зазор между кнопками панели задач.
const TASK_GAP := 4
## Ширина кнопки панели задач. Фиксированная, чтобы длинное русское имя
## программы не растаскивало панель при переключении языка.
const TASK_BUTTON_WIDTH := 168
## Шаг сетки на обоях. Каша из точек на шаге меньше 24 читалась бы как шум.
const WALLPAPER_GRID := 32.0
## Первое окно ставится сюда, каждое следующее — со сдвигом лесенкой.
## ВСЁ КРАТНО ШАГУ СЕТКИ ОБОЕВ. Окна стояли на 48/40 при сетке 32 — рамка
## каждого окна резала клетку пополам, и стол выглядел перекошенным, хотя
## ни одно окно не было наклонено. Ровная стопка получается только тогда,
## когда и позиция, и размер ложатся на ту же миллиметровку, что нарисована
## под ними.
const CASCADE_ORIGIN := Vector2(64, 32)
const CASCADE_STEP := Vector2(32, 32)
## Сколько ступеней лесенки до возврата в начало.
const CASCADE_WRAP := 5
## Пауза между появлением двух окон. Пачка окон, вылетающая в один кадр,
## читается как сбой игры, а не как система, которая просыпается: программы
## станции поднимаются по одной, и у оператора есть время увидеть каждую.
const REVEAL_DELAY := 1.35

var _window_layer: Control
var _taskbar: HBoxContainer
var _system_label: Label
var _clock_label: Label
var _crt: CRTOverlay

## Окно встало на стол. Звук поднятия программы принадлежит тому, у кого есть
## микшер, — оболочка только сообщает момент.
signal window_revealed(window: DesktopWindow)

var _windows: Array[DesktopWindow] = []
var _minimized: Dictionary = {}
## Окна, которые уже созданы, но ещё не показались: очередь постепенного
## появления. Пока окно здесь, его нет ни на столе, ни в панели задач.
var _reveal_queue: Array[DesktopWindow] = []
var _pending: Dictionary = {}
var _reveal_wait := 0.0
var _cascade := 0
var _night := 1
var _shift_seconds := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Очередь появления окон тикает в _process. При унаследованном режиме любая
	# пауза дерева (меню, заставка) останавливала её навсегда: окна уже
	# созданы и размещены, но так и остаются visible=false, и стол выглядит пустым.
	# Компьютер — интерфейс, он обязан жить и на паузе.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Стол забирает мышь целиком: пока игрок за компьютером, клики принадлежат
	# компьютеру, а не миру за его спиной.
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_build()


func _build() -> void:
	var wallpaper := Panel.new()
	wallpaper.name = "Wallpaper"
	wallpaper.theme_type_variation = &"TerminalPanel"
	wallpaper.set_anchors_preset(Control.PRESET_FULL_RECT)
	wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wallpaper)

	var grid := Control.new()
	grid.name = "Wallpaper Grid"
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.draw.connect(_draw_wallpaper.bind(grid))
	grid.resized.connect(grid.queue_redraw)
	add_child(grid)

	_build_status_bar()

	_window_layer = Control.new()
	_window_layer.name = "Windows"
	_window_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_window_layer.offset_top = STATUS_HEIGHT
	_window_layer.offset_bottom = -TASKBAR_HEIGHT
	# Сам слой прозрачен для мыши: клик мимо окон — это клик по столу, а не
	# по невидимой пластине поверх него.
	_window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Слой получает настоящий размер только после первой раскладки и
	# меняется вместе с разрешением. Окна, расставленные до этого,
	# считали границы по нулю — и вылазили за край стола.
	_window_layer.resized.connect(_fit_all_windows)
	add_child(_window_layer)

	_build_taskbar()

	# ПОСЛЕДНИМ РЕБЁНКОМ — та же причина, что у TerminalFrame: всё, что рисует
	# монитор, видно через стекло — и окна, и панель задач.
	_crt = CRTOverlay.new()
	_crt.name = "Crt Glass"
	add_child(_crt)

	_apply_type()
	_refresh_taskbar()


func _build_status_bar() -> void:
	var bar := Panel.new()
	bar.name = "Status Bar"
	bar.theme_type_variation = &"InstrumentPanel"
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, STATUS_HEIGHT)
	bar.offset_bottom = STATUS_HEIGHT
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = BAR_PAD_X
	row.offset_right = -BAR_PAD_X
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)

	_system_label = Label.new()
	_system_label.name = "System"
	_system_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_system_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_system_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_system_label)

	_clock_label = Label.new()
	_clock_label.name = "Clock"
	_clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_clock_label)


func _build_taskbar() -> void:
	var bar := Panel.new()
	bar.name = "Taskbar"
	bar.theme_type_variation = &"InstrumentPanel"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.custom_minimum_size = Vector2(0, TASKBAR_HEIGHT)
	bar.offset_top = -TASKBAR_HEIGHT
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)

	_taskbar = HBoxContainer.new()
	_taskbar.name = "Tasks"
	_taskbar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_taskbar.offset_left = BAR_PAD_X
	_taskbar.offset_right = -BAR_PAD_X
	_taskbar.offset_top = TASK_GAP
	_taskbar.offset_bottom = -TASK_GAP
	_taskbar.add_theme_constant_override("separation", TASK_GAP)
	_taskbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_taskbar)


func _apply_type() -> void:
	TerminalType.apply_masthead(_system_label, UITheme.CAPTION, UITheme.MUTED)
	# Часы — readout: ширина забронирована под "88:88", иначе строка состояния
	# дёргалась бы каждую минуту смены.
	TerminalType.apply_readout(_clock_label, UITheme.CAPTION, UITheme.ON_SURFACE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_status()
		_refresh_taskbar()


func _draw_wallpaper(canvas: Control) -> void:
	# Сетка одним тоном над фоном: референс держит стол пустым, чтобы вес
	# был у окон. Линии — это миллиметровка служебного экрана, не украшение.
	var rect := canvas.get_rect()
	var line := UITheme.PANEL_EDGE
	line.a = 0.35
	var x := WALLPAPER_GRID
	while x < rect.size.x:
		canvas.draw_line(Vector2(x, 0.0), Vector2(x, rect.size.y), line, 1.0)
		x += WALLPAPER_GRID
	var y := WALLPAPER_GRID
	while y < rect.size.y:
		canvas.draw_line(Vector2(0.0, y), Vector2(rect.size.x, y), line, 1.0)
		y += WALLPAPER_GRID


# --- ОКНА -------------------------------------------------------------------

## Открыть программу. Если окно с таким id уже есть, оно просто поднимается:
## вторая копия одного и того же отчёта ничего не добавляет, а перекрывает первую.
func open_window(id: String, key: String, content: Control,
		window_size := Vector2(560, 380),
		desk_fraction := Vector2.ZERO,
		desk_anchor := Vector2(-1.0, -1.0)) -> DesktopWindow:
	var existing := get_window_by_id(id)
	if existing != null:
		restore_window(existing)
		return existing

	var window := DesktopWindow.new()
	window.setup(id, key)
	# Доля стола запоминается ДО размещения: с ней окно пересчитает себя под
	# любой масштаб интерфейса, а window_size остаётся запасным вариантом на
	# первый кадр, пока слой ещё нулевого размера. См. DesktopWindow.desk_fraction.
	window.desk_fraction = desk_fraction
	# Место — там же и по той же причине: оно должно быть известно ДО
	# первого размещения, иначе окно успеет уйти в лесенку.
	window.desk_anchor = desk_anchor
	# Размер тоже ложится на сетку, а не только позиция: иначе ровно
	# поставленное окно всё равно заканчивается посреди клетки обоев.
	_place(window, window_size)
	window.focus_requested.connect(focus_window)
	window.close_requested.connect(close_window)
	window.minimize_requested.connect(minimize_window)
	_window_layer.add_child(window)
	if content != null:
		window.body.add_child(content)
	_windows.append(window)
	# Окно возвращается вызывающему СРАЗУ (ему есть что в него положить), но на
	# столе оно появится в свою очередь — см. REVEAL_DELAY.
	_enqueue_reveal(window)
	return window


## Поставить окно в очередь появления. Вызывается и снаружи: отчёт протокола
## не должен выпрыгивать в лицо в тот же кадр, когда сработала сирена.
func reveal_window(window: DesktopWindow) -> void:
	if window == null or not is_instance_valid(window):
		return
	if _reveal_queue.has(window):
		return
	_enqueue_reveal(window)


func _enqueue_reveal(window: DesktopWindow) -> void:
	window.visible = false
	window.set_active(false)
	_pending[window.window_id] = true
	_minimized.erase(window.window_id)
	_reveal_queue.append(window)
	if _reveal_wait <= 0.0:
		_reveal_wait = REVEAL_DELAY
	_refresh_taskbar()


## Очередь двигается по одному окну за REVEAL_DELAY. Ничего не открывается,
## пока предыдущее окно не встало на стол.
func _process(delta: float) -> void:
	if _reveal_queue.is_empty():
		_reveal_wait = 0.0
		return
	_reveal_wait -= delta
	if _reveal_wait > 0.0:
		return
	_reveal_wait = REVEAL_DELAY
	var next: DesktopWindow = null
	while not _reveal_queue.is_empty():
		var candidate: DesktopWindow = _reveal_queue.pop_front()
		if is_instance_valid(candidate):
			next = candidate
			break
	if next == null:
		return
	_pending.erase(next.window_id)
	# К моменту показа размер стола уже настоящий: только здесь можно
	# честно проверить, что окно целиком влезает в свои границы.
	_fit_window(next)
	focus_window(next)
	window_revealed.emit(next)


func get_window_by_id(id: String) -> DesktopWindow:
	for window in _windows:
		if is_instance_valid(window) and window.window_id == id:
			return window
	return null


func has_window(id: String) -> bool:
	return get_window_by_id(id) != null


## Порядок детей слоя и есть z-порядок: последний рисуется поверх остальных.
func focus_window(window: Control) -> void:
	var target := window as DesktopWindow
	if target == null or not is_instance_valid(target):
		return
	if target.get_parent() == _window_layer:
		_window_layer.move_child(target, _window_layer.get_child_count() - 1)
	target.visible = true
	_reveal_queue.erase(target)
	_pending.erase(target.window_id)
	_minimized.erase(target.window_id)
	for other in _windows:
		if is_instance_valid(other):
			other.set_active(other == target)
	_refresh_taskbar()


func restore_window(window: DesktopWindow) -> void:
	focus_window(window)


func minimize_window(window: Control) -> void:
	var target := window as DesktopWindow
	if target == null or not is_instance_valid(target):
		return
	target.visible = false
	target.set_active(false)
	_reveal_queue.erase(target)
	_pending.erase(target.window_id)
	_minimized[target.window_id] = true
	_refresh_taskbar()


func close_window(window: Control) -> void:
	var target := window as DesktopWindow
	if target == null or not is_instance_valid(target):
		return
	_windows.erase(target)
	_reveal_queue.erase(target)
	_pending.erase(target.window_id)
	_minimized.erase(target.window_id)
	# Лесенка отматывается назад: без этого пятое подряд открытое окно уезжало
	# в угол стола, даже если на столе к тому моменту было пусто.
	_cascade = maxi(0, _cascade - 1)
	target.queue_free()
	_refresh_taskbar()


func close_window_by_id(id: String) -> void:
	var window := get_window_by_id(id)
	if window != null:
		close_window(window)


func close_all() -> void:
	for window in _windows.duplicate():
		if is_instance_valid(window):
			window.queue_free()
	_windows.clear()
	_minimized.clear()
	_reveal_queue.clear()
	_pending.clear()
	_reveal_wait = 0.0
	_cascade = 0
	_refresh_taskbar()


## Поставить окно на стол: СНАЧАЛА размер, ПОТОМ позиция. Порядок важен.
## Раньше лесенка клампилась по ЗАПРОШЕННОМУ размеру (760), а окно получало
## снапнутый (768): восьми пикселей хватало, чтобы правый край с уголком
## изменения размера ушёл за край стола.
func _place(window: DesktopWindow, desired: Vector2) -> void:
	window.size = _fit_size(desired, window.desk_fraction)
	# СНАЧАЛА свободное место, и только если его нет — лесенка. Референс 01
	# держит кадр плотным: клетчатая подложка, просвечивающая между окнами,
	# читается как недогруженная система, а не как пост наблюдателя. Пока на
	# столе есть куда положить окно целиком, оно кладётся рядом, а не поверх.
	# Объявленное место бьёт поиск: если владелец окна сказал, где оно
	# должно стоять, столу нечего решать за него.
	var anchored: Variant = _anchor_spot(window)
	if anchored != null:
		window.position = anchored as Vector2
		return
	var spot: Variant = _free_spot(window.size)
	if spot == null:
		window.position = _next_cascade(window.size)
	else:
		window.position = _snap(spot as Vector2)


## Место, объявленное владельцем окна, в пикселях этого стола. null — место
## не объявлено или стол ещё нулевой; тогда работает обычный поиск клетки.
## Кламп по размеру окна обязателен: доля считалась от угла, а окно после
## округления к сетке может оказаться на клетку шире остатка.
##
## Округление ВНИЗ, точно так же, как считаются РАЗМЕРЫ из долей. Два
## разных округления в одной колонке расходятся на клетку: при крупном тексте
## протокол кончался на 480, а CCTV начинался с 512, и между ними светилась
## полоса обоев. Место и размер обязаны ложиться на сетку одинаково.
func _anchor_spot(window: DesktopWindow) -> Variant:
	if window.desk_anchor.x < 0.0 or window.desk_anchor.y < 0.0:
		return null
	var area := _window_layer.size
	if area == Vector2.ZERO:
		return null
	var spot := _snap_down(Vector2(area.x * window.desk_anchor.x,
			area.y * window.desk_anchor.y))
	spot.x = clampf(spot.x, 0.0, maxf(0.0, area.x - window.size.x))
	spot.y = clampf(spot.y, 0.0, maxf(0.0, area.y - window.size.y))
	return spot


## Размер, который гарантированно влезает в стол. Окно не бывает больше
## своего слоя: иначе его нижний край уходит под панель задач вместе с
## уголком изменения размера, и уменьшить окно уже нечем.
func _fit_size(desired: Vector2, fraction := Vector2.ZERO) -> Vector2:
	var area := _window_layer.size
	var box := _snap(desired)
	# Доля бьёт пиксели, но только когда есть от чего её считать. Округление
	# ВНИЗ: две доли, каждая округлённая вверх, вместе перерастают стол, и
	# соседняя колонка теряет своё место из-за одной клетки обоев.
	if area != Vector2.ZERO and fraction.x > 0.0 and fraction.y > 0.0:
		box = _snap_down(Vector2(area.x * fraction.x, area.y * fraction.y))
	box.x = maxf(box.x, DesktopWindow.MIN_SIZE.x)
	box.y = maxf(box.y, DesktopWindow.MIN_SIZE.y)
	if area != Vector2.ZERO:
		box.x = minf(box.x, area.x)
		box.y = minf(box.y, area.y)
	return box


## Вернуть окно в границы стола. В момент open_window слой ещё может быть
## нулевого размера (первый кадр после входа за компьютер) — тогда
## клампить не по чему, и проверка откладывается до показа окна.
func _fit_window(window: DesktopWindow) -> void:
	if window == null or not is_instance_valid(window):
		return
	if _window_layer == null or _window_layer.size == Vector2.ZERO:
		return
	window.size = _fit_size(window.size, window.desk_fraction)
	# Окно с объявленным местом возвращается НА НЕГО, а не туда, где
	# случилось свободно. Именно здесь раскладка и рассыпалась: первый
	# проход шёл по столу нулевого размера, все окна уходили в лесенку, а
	# потом чинились по очереди открытия — и последнему доставался остаток.
	var anchored: Variant = _anchor_spot(window)
	if anchored != null:
		window.position = anchored as Vector2
		window.clamp_into_parent()
		return
	# Место ищется заново ТОЛЬКО если нынешнее испортилось: окно вылезло за
	# край или налезло на соседа после смены масштаба. Пока раскладка цела,
	# окно не двигается — оператор должен знать, где журнал, не глядя.
	if _rect_conflicts(window):
		var spot: Variant = _free_spot(window.size, window)
		if spot == null:
			window.position = _next_cascade(window.size)
		else:
			window.position = _snap(spot as Vector2)
	window.clamp_into_parent()


## Стоит ли окно неправильно: вне стола или поверх другого открытого окна.
func _rect_conflicts(window: DesktopWindow) -> bool:
	var area := _window_layer.size
	var box := Rect2(window.position, window.size)
	if box.position.x < 0.0 or box.position.y < 0.0:
		return true
	if box.end.x > area.x or box.end.y > area.y:
		return true
	for other in _windows:
		if other == window or not is_instance_valid(other):
			continue
		if _minimized.has(other.window_id):
			continue
		if box.intersects(Rect2(other.position, other.size)):
			return true
	return false


## Стол пересобрался — проверяем ВСЕ окна, включая свёрнутые и те, что
## ещё ждут своей очереди: свёрнутое окно тоже когда-то вернётся на стол.
func _fit_all_windows() -> void:
	for window in _windows:
		_fit_window(window)


## Лесенка, как у любого оконного менеджера: окна не ложатся строго друг на
## друга, иначе второе окно выглядит как подмена первого.
func _next_cascade(window_size: Vector2) -> Vector2:
	var area := _window_layer.size
	var spot := CASCADE_ORIGIN + CASCADE_STEP * float(_cascade % CASCADE_WRAP)
	_cascade += 1
	if area == Vector2.ZERO:
		return _snap(spot)
	spot.x = clampf(spot.x, 0.0, maxf(0.0, area.x - window_size.x))
	spot.y = clampf(spot.y, 0.0, maxf(0.0, area.y - window_size.y))
	return _snap(spot)


## Свободное место под окно такого размера. Стол обходится по сетке обоев
## слева направо, сверху вниз; первая клетка, где окно целиком влезает в стол
## и не задевает уже стоящие окна, и есть ответ. Места нет — возвращается
## null, и окно уходит в лесенку поверх остальных, как раньше.
##
## Обход по сетке, а не поиск идеальной упаковки: раскладка обязана быть
## ПРЕДСКАЗУЕМОЙ. Одни и те же программы, открытые в одном и том же порядке,
## должны каждую ночь ложиться одинаково, иначе оператор заново ищет глазами
## журнал событий вместо того, чтобы знать, где он.
func _free_spot(window_size: Vector2, ignore: DesktopWindow = null) -> Variant:
	var area := _window_layer.size
	if area == Vector2.ZERO:
		return null
	if window_size.x > area.x or window_size.y > area.y:
		return null
	var taken := _occupied_rects(ignore)
	var y := 0.0
	while y + window_size.y <= area.y:
		var x := 0.0
		while x + window_size.x <= area.x:
			var box := Rect2(Vector2(x, y), window_size)
			var clear := true
			for rect in taken:
				# Rect2.intersects() без include_borders: окна, стоящие
				# впритык, не считаются пересекающимися, и их рамки
				# складываются в одну общую линию — как на референсе.
				if box.intersects(rect):
					clear = false
					break
			if clear:
				return Vector2(x, y)
			x += WALLPAPER_GRID
		y += WALLPAPER_GRID
	return null


## Прямоугольники окон, которые держат место на столе. Свёрнутое окно места
## НЕ держит: пока его нет на экране, закрывать им живую клетку незачем — оно
## вернётся туда же, откуда ушло, и разберётся с соседями по z-порядку.
## `ignore` — окно, которое само себе место ищет: без этого оно нашло бы
## занятым собственный прямоугольник и всегда уходило бы в лесенку.
func _occupied_rects(ignore: DesktopWindow = null) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for other in _windows:
		if not is_instance_valid(other) or other == ignore:
			continue
		if _minimized.has(other.window_id):
			continue
		rects.append(Rect2(other.position, other.size))
	return rects


## Округление к сетке обоев. Одна функция и для позиции, и для размера, иначе
## ровно поставленное окно всё равно кончалось бы посреди клетки.
func _snap(value: Vector2) -> Vector2:
	return (value / WALLPAPER_GRID).round() * WALLPAPER_GRID


## То же округление, но ВНИЗ, для размеров, посчитанных из долей стола.
## Половина клетки прибавляется до пола, чтобы 287.9999, посчитанное в
## плавающей точке вместо ровных 288, не проваливалось на клетку вниз.
func _snap_down(value: Vector2) -> Vector2:
	return ((value + Vector2.ONE * 0.5) / WALLPAPER_GRID).floor() * WALLPAPER_GRID


# --- ПАНЕЛЬ ЗАДАЧ -------------------------------------------------------------

func _refresh_taskbar() -> void:
	if _taskbar == null:
		return
	for child in _taskbar.get_children():
		child.queue_free()
	for window in _windows:
		if not is_instance_valid(window):
			continue
		# Программа, которая ещё поднимается, не занимает место в панели задач:
		# кнопка без окна за ней — обещание, которое интерфейс не выполняет.
		if _pending.has(window.window_id):
			continue
		var button := Button.new()
		button.name = "Task %s" % window.window_id
		# Свёрнутое окно помечено ФОРМОЙ, а не цветом: в квадратных скобках.
		var caption := tr(window.title_key).to_upper()
		button.text = "[%s]" % caption if _minimized.has(window.window_id) else caption
		button.custom_minimum_size = Vector2(TASK_BUTTON_WIDTH, 0)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.clip_text = true
		UITheme.apply_button(button, UITheme.CAPTION)
		button.pressed.connect(_on_task_pressed.bind(window))
		_taskbar.add_child(button)


func _on_task_pressed(window: DesktopWindow) -> void:
	if not is_instance_valid(window):
		return
	# Нажатие на кнопку активного окна его сворачивает — как везде.
	if window.visible and window.is_active():
		minimize_window(window)
	else:
		focus_window(window)


# --- СТРОКА СОСТОЯНИЯ ---------------------------------------------------------

func set_status(night: int, shift_seconds: float) -> void:
	_night = night
	_shift_seconds = shift_seconds
	_refresh_status()


func _refresh_status() -> void:
	if _system_label == null or _clock_label == null:
		return
	_system_label.text = Loc.fmt("DESK_SYSTEM_LINE", [_night])
	_clock_label.text = _clock_text(_shift_seconds)


func _clock_text(seconds: float) -> String:
	var total := int(maxf(0.0, seconds))
	return "%02d:%02d" % [total / 60, total % 60]


func set_crt_enabled(enabled: bool) -> void:
	if _crt != null:
		_crt.visible = enabled
