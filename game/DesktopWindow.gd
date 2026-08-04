extends Panel
class_name DesktopWindow

## ОКНО РАБОЧЕГО СТОЛА МНЕМОС (блок 10, референсы 01 и 02).
##
## Раньше данные инцидента показывала ОДНА полноэкранная панель, которая вставала
## перед лицом игрока сама. Референс 02 прямо описывает другое: НАЛОЖЕНИЕ ОКОН.
## Это рабочее место оператора, а не оверлей: несколько программ одновременно,
## каждая в своём окне, окна таскаются за заголовок и перекрывают друг друга.
##
## КАНОН СОХРАНЯЕТСЯ. Нулевые скругления, жёсткая рамка, непрозрачный фон, пиксельный
## шрифт. Окно — это Panel с вариацией темы TerminalPanel, а не новая графика:
## цвета и рамки приходят из ui/museum_theme.tres, а не из этого файла.
##
## Заголовок и три кнопки подписаны ASCII (`_`, `[]`, `X`), потому что в Departure
## Mono нет ни U+2715, ни рамочных глифов — тик или крестик из Unicode выпал бы
## тофу-квадратом в самом видном месте экрана.
##
## Текст заголовка хранится КЛЮЧОМ локализации, а не строкой: окно переживает
## смену языка без пересборки (см. _notification).
##
## ПОЧЕМУ ПЕРЕТАСКИВАНИЕ НЕ ЖИВЁТ В gui_input.
## Первая версия ловила и нажатие, и движение, и отпускание в gui_input полосы
## заголовка. Godot не захватывает мышь за控 контролом: стоило дёрнуть курсор
## быстрее, чем окно успевает переехать, как события уходили другому узлу, а
## отпускание кнопки полоса не получала вовсе — окно навсегда прилипало к
## курсору. Поэтому нажатие берётся в полосе, а движение и отпускание — в
## _input(), который видит ВСЕ события до всякого GUI и не может их пропустить.
##
## ПОЧЕМУ ПОЗИЦИЯ СЧИТАЕТСЯ ОТ КУРСОРА, А НЕ НАКОПЛЕНИЕМ relative.
## Накопление event.relative копит ошибку при упоре окна в край стола: курсор
## уходит дальше, окно стоит, и на обратном ходу окно "отлипает" от курсора.
## Запоминаем захват (курсор минус угол окна) и всегда считаем от него.

## Клик в любое место окна просит оболочку поднять его наверх стопки.
signal focus_requested(window: Control)
## Крестик. Окно НЕ удаляет себя само — это решает DesktopShell, у которого
## есть панель задач и список окон.
signal close_requested(window: Control)
## Сворачивание в панель задач, по той же причине.
signal minimize_requested(window: Control)

## Высота полосы заголовка. Под CAPTION-кегль с запасом на рамку кнопки.
const TITLE_BAR_HEIGHT := 26
## Отступ подписи от левого края окна.
const TITLE_PAD_X := 8
## Размер кнопки заголовка. Одинаковый у всех трёх: референс держит их в
## одной сетке, и разная ширина сразу читалась бы как брак.
const TITLE_BUTTON_SIZE := Vector2(24, 18)
## Зазор между кнопками заголовка.
const TITLE_BUTTON_GAP := 2
## Линейка под заголовком. Та же толщина, что у рамок темы.
const RULE_HEIGHT := 2
## Поля содержимого внутри окна.
const BODY_PAD := 10
## Ниже этого окно не сжимается: заголовок и три кнопки должны влезать
## в любой локали и при large_text.
const MIN_SIZE := Vector2(260, 150)

## Доля стола, которую окно занимает по ширине и высоте. Vector2.ZERO — размер
## абсолютный, как было раньше.
##
## Заведено под шаг 7 блока 10. Раскладка стола была подобрана в пикселях под
## экран 1600x844, но `large_text` поднимает content_scale_factor до 1.12, и
## логический стол ужимается примерно до 1428x748. Абсолютные 1088 + 512 в
## строку туда уже не встают: правая колонка не находит места и уходит
## лесенкой ПОВЕРХ окна протокола — то есть плотная раскладка рассыпается
## именно у того, кто включил крупный текст, чтобы читать было легче.
## Доля переживает любой масштаб, поэтому владелец окна задаёт её, а пиксели
## остаются запасным вариантом на первый кадр, пока стол ещё нулевой.
var desk_fraction := Vector2.ZERO

## Место окна на столе, тоже в долях стола, а не в пикселях. Отрицательное
## значение — место не объявлено, и окно размещается поиском свободной
## клетки, как раньше. Ноль здесь не годится: левый верх — законное место.
##
## Поиск свободной клетки честно находит, куда окно ВЛЕЗЕТ, но не знает, куда
## оно ДОЛЖНО лечь. Результат зависит от порядка открытия, а первый проход идёт
## по столу нулевого размера, где места нет вовсе. Объявленное место убирает
## эту случайность: пост наблюдения каждую ночь выглядит одинаково.
var desk_anchor := Vector2(-1.0, -1.0)

## Значок программы слева от подписи — квадрат с прорезью. Референс держит в
## этом месте иконку, а рисовать растр в PS1-интерфейсе не из чего.
const GLYPH_BOX := Vector2(12, 12)
## Штриховка активного заголовка (Win 3.x / реф. 01): шаг и толщина линии.
const STRIPE_PITCH := 4.0
const STRIPE_WIDTH := 1.0
## Нижняя строка окна: в ней живёт уголок изменения размера.
const FOOTER_HEIGHT := 16
## Квадрат в правом нижнем углу, за который окно тянут за размер.
const GRIP_SIZE := 16.0
## Насечки уголка: столько диагональных штрихов.
const GRIP_TICKS := 3

## Подписи кнопок заголовка — ASCII, см. шапку файла.
const MARK_MINIMIZE := "_"
const MARK_MAXIMIZE := "[]"
const MARK_RESTORE := "><"
const MARK_CLOSE := "X"

## Идентификатор программы ("protocol", "cctv", ...). По нему оболочка ищет
## уже открытое окно вместо того, чтобы плодить второе.
var window_id := ""
## Ключ локализации заголовка.
var title_key := ""

## Слот для содержимого. Кладётся снаружи: окно не знает, что в нём показывают.
var body: MarginContainer

var _bar: Panel
var _bar_art: Control
var _glyph: Control
var _title: Label
var _max_button: Button
var _footer: Panel
var _footer_label: Label
var _grip: Control
var _scroll: ScrollContainer
var _active := false

var _dragging := false
var _resizing := false
## Курсор минус угол окна в момент захвата — см. шапку файла.
var _grab := Vector2.ZERO

## Геометрия до разворачивания, чтобы второе нажатие вернуло окно на место.
var _restore_rect := Rect2()
var _maximized := false


func _init() -> void:
	theme_type_variation = &"TerminalPanel"
	# Окно съедает клики, иначе нажатие провалится на окно под ним и поднимет
	# его — точно обратно тому, что ожидает человек с мышью.
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = MIN_SIZE
	# ОКНО НЕ РИСУЕТ НИЧЕГО ЗА СВОЕЙ РАМКОЙ. Содержимое кладут снаружи, и оно
	# запросто оказывается выше слота: кадр терминала внутри окна протокола
	# требует своей высоты под шапку, отчёт и строку клавиш. VBoxContainer в
	# такой ситуации не сжимает детей, а выкладывает их по минимальной высоте
	# и спокойно вылезает НИЖЕ окна — на скриншоте это выглядело как текст и
	# план музея, висящие поверх соседнего окна и панели задач, и как кнопки
	# заголовка, оторвавшиеся от своей полосы. Отсечение по рамке — это то,
	# что делает окно окном.
	clip_contents = true
	_build()


func _ready() -> void:
	# Стол меняет размер вместе с окном игры и при смене разрешения в
	# настройках. Без этого окно, стоявшее у правого края, оказывалось за
	# краем стола и становилось недостижимым — вернуть его было нечем.
	var parent := get_parent() as Control
	if parent != null:
		parent.resized.connect(_on_desk_resized)


func _build() -> void:
	var column := VBoxContainer.new()
	column.name = "Column"
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Flush: the title bar, the rule and the body are one slab, not three
	# stacked cards.
	UITheme.apply_gap(column, 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_bar = Panel.new()
	_bar.name = "Title Bar"
	_bar.custom_minimum_size = Vector2(0, TITLE_BAR_HEIGHT)
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar.gui_input.connect(_on_bar_input)
	column.add_child(_bar)

	# Штриховка рисуется ПОД строкой заголовка (канвас родителя выводится
	# раньше детей), а подпись лежит на собственной непрозрачной плашке —
	# ровно так полоса и устроена на референсе 01.
	_bar_art = Control.new()
	_bar_art.name = "Title Stripes"
	_bar_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_art.draw.connect(_draw_stripes)
	_bar_art.resized.connect(_bar_art.queue_redraw)
	_bar.add_child(_bar_art)

	var row := HBoxContainer.new()
	row.name = "Title Row"
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = TITLE_PAD_X
	row.offset_right = -float(TITLE_BUTTON_GAP)
	row.add_theme_constant_override("separation", TITLE_BUTTON_GAP)
	# Строка прозрачна для мыши, иначе она съела бы протаскивание за заголовок;
	# кнопки внутри ставят свой фильтр сами.
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(row)

	_glyph = Control.new()
	_glyph.name = "Glyph"
	_glyph.custom_minimum_size = GLYPH_BOX
	_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.draw.connect(_draw_glyph)
	row.add_child(_glyph)

	_title = Label.new()
	_title.name = "Title"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_title)

	row.add_child(_title_button(MARK_MINIMIZE, "Minimize", func() -> void:
		minimize_requested.emit(self)))
	_max_button = _title_button(MARK_MAXIMIZE, "Maximize", func() -> void:
		toggle_maximized())
	row.add_child(_max_button)
	row.add_child(_title_button(MARK_CLOSE, "Close", func() -> void:
		close_requested.emit(self)))

	var rule := ColorRect.new()
	rule.name = "Title Rule"
	rule.color = UITheme.PANEL_EDGE
	rule.custom_minimum_size = Vector2(0, RULE_HEIGHT)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)

	# Одного отсечения мало: обрезанный отчёт — это молча потерянные строки.
	# Содержимое едет в прокрутку, поэтому то, что не поместилось по высоте,
	# остаётся доступным, а по ширине окно не разъезжается вовсе.
	_scroll = ScrollContainer.new()
	_scroll.name = "Body Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	column.add_child(_scroll)

	body = MarginContainer.new()
	body.name = "Body"
	# Обе оси EXPAND_FILL: ScrollContainer тянет ребёнка до своего размера
	# только с этими флагами, иначе кадр терминала схлопнулся бы к минимуму и
	# отчёт прижался бы к верхней кромке узкой полоской.
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		body.add_theme_constant_override(side, BODY_PAD)
	_scroll.add_child(body)

	_build_footer(column)
	_apply_type()
	set_active(false)


## Нижняя строка нужна не для красоты: она даёт уголку изменения размера
## собственное место. Уголок, лежащий поверх содержимого, воровал бы клики у
## того, что показывает программа.
func _build_footer(column: VBoxContainer) -> void:
	_footer = Panel.new()
	_footer.name = "Footer"
	_footer.custom_minimum_size = Vector2(0, FOOTER_HEIGHT)
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.SURFACE
	style.set_corner_radius_all(UITheme.RADIUS_SM)
	style.set_border_width_all(0)
	style.border_width_top = RULE_HEIGHT
	style.border_color = UITheme.PANEL_EDGE
	_footer.add_theme_stylebox_override("panel", style)
	column.add_child(_footer)

	_footer_label = Label.new()
	_footer_label.name = "Footer Text"
	_footer_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_footer_label.offset_left = TITLE_PAD_X
	_footer_label.offset_right = -GRIP_SIZE
	_footer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_footer_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_footer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_footer.add_child(_footer_label)

	_grip = Control.new()
	_grip.name = "Resize Grip"
	_grip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_grip.offset_left = -GRIP_SIZE
	_grip.offset_top = -GRIP_SIZE
	_grip.offset_right = 0
	_grip.offset_bottom = 0
	_grip.mouse_filter = Control.MOUSE_FILTER_STOP
	_grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_grip.draw.connect(_draw_grip)
	_grip.gui_input.connect(_on_grip_input)
	add_child(_grip)


func _title_button(text: String, node_name: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = TITLE_BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UITheme.apply_button(button, UITheme.CAPTION)
	button.pressed.connect(action)
	# Нажатие на любую кнопку тоже делает окно активным: человек считает
	# прикосновение к окну обращением к нему, независимо от того, куда попал.
	button.button_down.connect(func() -> void: focus_requested.emit(self))
	return button


## Типографика заголовка — через TerminalType, как и весь остальной блок 10, чтобы
## окно не заводило собственный шрифтовой вкус.
func _apply_type() -> void:
	TerminalType.apply_label(_title, UITheme.LABEL, UITheme.ON_SURFACE)
	TerminalType.apply_label(_footer_label, UITheme.CAPTION, UITheme.MUTED)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_refresh_title()


# --- ОТРИСОВКА ---------------------------------------------------------------

## Косая штриховка активного заголовка. Она не декоративная: это второй,
## нецветовой признак активного окна — его видно и в оттенках серого.
func _draw_stripes() -> void:
	if not _active or _bar_art == null:
		return
	var rect := _bar_art.get_rect()
	var line := UITheme.PANEL_EDGE
	line.a = 0.55
	var x := 0.0
	while x < rect.size.x + rect.size.y:
		_bar_art.draw_line(Vector2(x, 0.0),
			Vector2(x - rect.size.y, rect.size.y), line, STRIPE_WIDTH)
		x += STRIPE_PITCH


## Значок программы: рамка с заполненной сердцевиной. Активное окно светит
## бежевым, спящее — приглушённым.
func _draw_glyph() -> void:
	if _glyph == null:
		return
	var rect := Rect2(Vector2.ZERO, _glyph.size)
	var tone := UITheme.BEIGE if _active else UITheme.MUTED
	_glyph.draw_rect(rect, UITheme.SURFACE, true)
	_glyph.draw_rect(rect, tone, false, 1.0)
	_glyph.draw_rect(rect.grow(-3.0), tone, true)


## Уголок изменения размера — насечки, а не картинка: три диагонали читаются
## как "тяни" на любом разрешении и не зависят от шрифта.
func _draw_grip() -> void:
	if _grip == null:
		return
	var tone := UITheme.BEIGE if _active else UITheme.MUTED
	var box := _grip.size
	for i in range(GRIP_TICKS):
		var inset := 3.0 + float(i) * 4.0
		_grip.draw_line(Vector2(box.x - inset, box.y - 2.0),
			Vector2(box.x - 2.0, box.y - inset), tone, 1.0)


# --- ПУБЛИЧНЫЙ API ---------------------------------------------------------

func setup(id: String, key: String) -> void:
	window_id = id
	name = "Window %s" % id.capitalize()
	title_key = key
	_refresh_title()


func _refresh_title() -> void:
	if _title == null:
		return
	_title.text = tr(title_key).to_upper() if title_key != "" else ""


## Подпись в нижней строке окна. Пусто по умолчанию: программа сама решает,
## есть ли ей что сказать про своё состояние.
func set_footer_text(text: String) -> void:
	if _footer_label != null:
		_footer_label.text = text


## Активное окно отличается НЕ ТОЛЬКО ЦВЕТОМ: у его заголовка залитая полоса,
## косая штриховка и светлая подпись, у неактивного — фон корпуса, без
## штриховки и приглушённая подпись. Разница читается в градациях серого,
## как требует правило о тревоге и цвете.
func set_active(active: bool) -> void:
	_active = active
	if _bar == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = UITheme.SURFACE_RAISED if active else UITheme.SURFACE
	style.set_corner_radius_all(UITheme.RADIUS_SM)
	style.set_border_width_all(0)
	style.border_width_bottom = 0
	_bar.add_theme_stylebox_override("panel", style)
	if _title != null:
		_title.add_theme_color_override("font_color",
			UITheme.BEIGE if active else UITheme.MUTED)
		# Подпись сидит на непрозрачной плашке, иначе штриховка прошла бы
		# прямо по буквам и съела читаемость заголовка.
		var plate := StyleBoxFlat.new()
		plate.bg_color = UITheme.SURFACE_RAISED if active else UITheme.SURFACE
		plate.set_corner_radius_all(UITheme.RADIUS_SM)
		plate.set_border_width_all(0)
		plate.content_margin_left = 6
		plate.content_margin_right = 6
		_title.add_theme_stylebox_override("normal", plate)
	if _bar_art != null:
		_bar_art.queue_redraw()
	if _glyph != null:
		_glyph.queue_redraw()
	if _grip != null:
		_grip.queue_redraw()


func is_active() -> bool:
	return _active


func toggle_maximized() -> void:
	var area := get_parent_area_size()
	if area == Vector2.ZERO:
		return
	if _maximized:
		position = _restore_rect.position
		size = _restore_rect.size
		_maximized = false
		_max_button.text = MARK_MAXIMIZE
		clamp_into_parent()
	else:
		_restore_rect = Rect2(position, size)
		position = Vector2.ZERO
		size = area
		_maximized = true
		_max_button.text = MARK_RESTORE
	_refresh_grip_state()
	focus_requested.emit(self)


## Развёрнутое окно не тянется за угол: тянуть нечего, оно уже во весь стол.
func _refresh_grip_state() -> void:
	if _grip != null:
		_grip.visible = not _maximized


# --- ПЕРЕТАСКИВАНИЕ И РАЗМЕР --------------------------------------------------

func _on_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		focus_requested.emit(self)
		# Развёрнутое окно не таскается: оно занимает весь стол, и сдвиг
		# только обнажил бы полосу пустоты у края.
		if not _maximized:
			_dragging = true
			_grab = _desk_mouse() - position


func _on_grip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		focus_requested.emit(self)
		if not _maximized:
			_resizing = true
			_grab = _desk_mouse() - size


## Движение и отпускание ловятся здесь, а не в gui_input — см. шапку файла.
func _input(event: InputEvent) -> void:
	if not (_dragging or _resizing):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_dragging = false
		_resizing = false
		return
	if event is not InputEventMouseMotion:
		return
	if _dragging:
		position = _desk_mouse() - _grab
		clamp_into_parent()
	elif _resizing:
		_resize_to(_desk_mouse() - _grab)


## Курсор в координатах стола. Считать в своих координатах нельзя: они едут
## вместе с окном, и перетаскивание пошло бы вразнос.
func _desk_mouse() -> Vector2:
	var parent := get_parent() as Control
	if parent == null:
		return get_global_mouse_position()
	return parent.get_local_mouse_position()


## Размер ограничен снизу MIN_SIZE, сверху — краем стола: окно не должно
## вырастать за пределы, где его уже не ухватить за заголовок.
func _resize_to(target: Vector2) -> void:
	var area := get_parent_area_size()
	var limit := target
	limit.x = maxf(limit.x, MIN_SIZE.x)
	limit.y = maxf(limit.y, MIN_SIZE.y)
	if area != Vector2.ZERO:
		limit.x = minf(limit.x, area.x - position.x)
		limit.y = minf(limit.y, area.y - position.y)
	size = limit


func _on_desk_resized() -> void:
	if _maximized:
		var area := get_parent_area_size()
		if area != Vector2.ZERO:
			position = Vector2.ZERO
			size = area
		return
	# Стол мог стать меньше окна: сначала ужимаем, потом возвращаем в поле.
	var room := get_parent_area_size()
	if room != Vector2.ZERO:
		size.x = clampf(size.x, MIN_SIZE.x, maxf(MIN_SIZE.x, room.x))
		size.y = clampf(size.y, MIN_SIZE.y, maxf(MIN_SIZE.y, room.y))
	clamp_into_parent()


## Окно не уезжает за край стола. Потерять единственное окно с данными в ночь,
## когда по коридору ходит Куратор, — не сложность, а поломка.
func clamp_into_parent() -> void:
	var area := get_parent_area_size()
	if area == Vector2.ZERO:
		return
	position.x = clampf(position.x, 0.0, maxf(0.0, area.x - size.x))
	position.y = clampf(position.y, 0.0, maxf(0.0, area.y - size.y))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		focus_requested.emit(self)
