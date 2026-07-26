extends Control
## Premium settings overlay built entirely from native Godot controls.

signal closed

const BG := Color("11161d")
const SURFACE := Color("171e27")
const SURFACE_HOVER := Color("202a35")
const BORDER := Color("33414f")
const TEXT := Color("edf3f5")
const MUTED := Color("8fa1ad")
const ACCENT := Color("55d6b3")
const ACCENT_SOFT := Color("173a36")

var _settings: Node
var _content: VBoxContainer
var _tabs: Array[Button] = []
var _active_tab := 0
var _value_labels: Dictionary = {}


func setup(settings: Node) -> void:
	_settings = settings
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_show_tab(0)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.035, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	# Subtle museum-green glow behind the panel.
	var glow := ColorRect.new()
	glow.color = Color(0.08, 0.35, 0.29, 0.12)
	glow.anchor_left = 0.16
	glow.anchor_top = 0.12
	glow.anchor_right = 0.84
	glow.anchor_bottom = 0.88
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(glow)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 610)
	panel.add_theme_stylebox_override("panel", _style(BG, BORDER, 2, 14))
	center.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	panel.add_child(outer)

	var header := _header()
	outer.add_child(header)

	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 1)
	outer.add_child(divider)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	outer.add_child(body)

	var sidebar := _sidebar()
	body.add_child(sidebar)

	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 34)
	content_margin.add_theme_constant_override("margin_top", 28)
	content_margin.add_theme_constant_override("margin_right", 34)
	content_margin.add_theme_constant_override("margin_bottom", 24)
	body.add_child(content_margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content_margin.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)


func _header() -> Control:
	var margin := MarginContainer.new()
	margin.custom_minimum_size.y = 104
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	var row := HBoxContainer.new()
	margin.add_child(row)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(titles)
	var eyebrow := Label.new()
	eyebrow.text = tr("SET_EYEBROW")
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", ACCENT)
	titles.add_child(eyebrow)
	var title := Label.new()
	title.text = tr("MENU_SETTINGS")
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", TEXT)
	titles.add_child(title)
	var close := Button.new()
	close.text = tr("SET_BACK")
	close.custom_minimum_size = Vector2(142, 44)
	_style_button(close, false)
	close.pressed.connect(func() -> void: closed.emit())
	row.add_child(close)
	return margin


func _sidebar() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 228
	panel.add_theme_stylebox_override("panel", _style(Color("0d1218"), Color.TRANSPARENT, 0, 0))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 26)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var names := [tr("SET_TAB_AUDIO"), tr("SET_TAB_GRAPHICS"), tr("SET_TAB_CONTROLS"), tr("SET_TAB_ACCESS")]
	var icons := ["◉", "◇", "⌁", "＋"]
	for i in range(names.size()):
		var button := Button.new()
		button.text = "%s    %s" % [icons[i], names[i]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(190, 48)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_show_tab.bind(i))
		button.mouse_entered.connect(_hover_sfx)
		box.add_child(button)
		_tabs.append(button)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var hint := Label.new()
	hint.text = tr("SET_AUTOSAVE_HINT")
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", MUTED)
	box.add_child(hint)
	return panel


func _show_tab(index: int) -> void:
	_active_tab = index
	for i in range(_tabs.size()):
		_style_button(_tabs[i], i == index)
	for child in _content.get_children():
		child.queue_free()
	_value_labels.clear()
	match index:
		0: _build_audio()
		1: _build_graphics()
		2: _build_controls()
		3: _build_accessibility()
	_select_sfx()


func _build_audio() -> void:
	_section_title(tr("SET_TAB_AUDIO"), tr("SET_AUDIO_DESC"))
	_slider_row(tr("SET_MASTER_VOLUME"), tr("SET_MASTER_VOLUME_DESC"), "volume",
		_settings.master_volume * 100.0, 0.0, 100.0, 1.0,
		func(value: float) -> void: _settings.set_master_volume(value / 100.0))
	_info_card(tr("SET_CARD_AUDIO_TITLE"), tr("SET_CARD_AUDIO_BODY"))


func _build_graphics() -> void:
	_section_title(tr("SET_TAB_GRAPHICS"), tr("SET_GRAPHICS_DESC"))
	_option_row(tr("SET_EFFECT_QUALITY"), tr("SET_EFFECT_QUALITY_DESC"),
		[tr("SET_QUALITY_LOW"), tr("SET_QUALITY_MEDIUM"), tr("SET_QUALITY_HIGH")], _settings.quality_preset,
		func(index: int) -> void: _settings.set_quality_preset(index))
	_option_row(tr("SET_RESOLUTION"), tr("SET_RESOLUTION_DESC"),
		["1280 × 720", "1600 × 900", "1920 × 1080"], _settings.resolution_index,
		func(index: int) -> void: _settings.set_resolution_index(index))
	_toggle_row(tr("SET_FULLSCREEN"), tr("SET_FULLSCREEN_DESC"), _settings.fullscreen,
		func(value: bool) -> void: _settings.set_fullscreen(value))
	_toggle_row(tr("SET_VSYNC"), tr("SET_VSYNC_DESC"), _settings.vsync,
		func(value: bool) -> void: _settings.set_vsync(value))
	_info_card(tr("SET_CARD_GRAPHICS_TITLE"), tr("SET_CARD_GRAPHICS_BODY"))


func _build_controls() -> void:
	_section_title(tr("SET_TAB_CONTROLS"), tr("SET_CONTROLS_DESC"))
	_slider_row(tr("SET_MOUSE_SENS"), tr("SET_MOUSE_SENS_DESC"), "sensitivity",
		_settings.mouse_sensitivity * 100000.0, 100.0, 600.0, 5.0,
		func(value: float) -> void: _settings.set_mouse_sensitivity(value / 100000.0))
	var keys := [
		[tr("SET_BIND_MOVE"), "WASD", tr("SET_PAD_LEFT_STICK")], [tr("SET_BIND_INTERACT"), "E", "X"],
		[tr("SET_BIND_TABLET"), "TAB", "Y"], [tr("SET_BIND_DROP"), "G", "B"],
		[tr("SET_BIND_PAUSE"), "ESC", "START"],
	]
	for key in keys:
		_key_row(key[0], key[1], key[2])


func _build_accessibility() -> void:
	_section_title(tr("SET_TAB_ACCESS"), tr("SET_ACCESS_DESC"))
	_option_row(tr("ACCESS_LANGUAGE"), tr("SET_LANGUAGE_DESC"), ["Русский", "English"],
		1 if _settings.language == "en" else 0,
		func(index: int) -> void: _settings.set_language("en" if index == 1 else "ru"))
	_toggle_row(tr("ACCESS_SUBTITLES"), tr("SET_SUBTITLES_DESC"), _settings.subtitles,
		func(value: bool) -> void: _settings.set_subtitles(value))
	_toggle_row(tr("ACCESS_REDUCED_FLASHES"), tr("SET_REDUCED_FLASHES_DESC"), _settings.reduced_flashes,
		func(value: bool) -> void: _settings.set_reduced_flashes(value))
	_toggle_row(tr("ACCESS_REDUCED_MOTION"), tr("SET_REDUCED_MOTION_DESC"), _settings.reduced_motion,
		func(value: bool) -> void: _settings.set_reduced_motion(value))
	_toggle_row(tr("ACCESS_HIGH_CONTRAST"), tr("SET_HIGH_CONTRAST_DESC"), _settings.high_contrast,
		func(value: bool) -> void: _settings.set_high_contrast(value))
	_toggle_row(tr("ACCESS_LARGE_UI"), tr("SET_LARGE_UI_DESC"), _settings.large_text,
		func(value: bool) -> void: _settings.set_large_text(value))
	var reset := Button.new()
	reset.text = tr("SET_RESET_DEFAULTS")
	reset.custom_minimum_size.y = 46
	_style_button(reset, false)
	reset.pressed.connect(_reset_defaults)
	_content.add_child(reset)


func _section_title(title_text: String, subtitle: String) -> void:
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", TEXT)
	_content.add_child(title)
	var sub := Label.new()
	sub.text = subtitle
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", MUTED)
	_content.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	_content.add_child(gap)


func _slider_row(title_text: String, description: String, key: String,
		value: float, min_value: float, max_value: float, step: float,
		callback: Callable) -> void:
	var row := _row_shell()
	var text_box := _row_text(row, title_text, description)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 58
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", ACCENT)
	row.add_child(value_label)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(210, 34)
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = "%d%%" % int(v) if key == "volume" else "%.2f" % (v / 100.0)
		callback.call(v))
	row.add_child(slider)
	value_label.text = "%d%%" % int(value) if key == "volume" else "%.2f" % (value / 100.0)


func _toggle_row(title_text: String, description: String, value: bool,
		callback: Callable) -> void:
	var row := _row_shell()
	var text_box := _row_text(row, title_text, description)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var toggle := CheckButton.new()
	toggle.text = tr("SET_ON") if value else tr("SET_OFF")
	toggle.button_pressed = value
	toggle.custom_minimum_size = Vector2(92, 42)
	toggle.add_theme_color_override("font_color", ACCENT)
	toggle.toggled.connect(func(on: bool) -> void:
		toggle.text = tr("SET_ON") if on else tr("SET_OFF")
		callback.call(on))
	row.add_child(toggle)


func _option_row(title_text: String, description: String, options: Array,
		selected: int, callback: Callable) -> void:
	var row := _row_shell()
	var text_box := _row_text(row, title_text, description)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(180, 42)
	for item in options:
		option.add_item(str(item))
	option.select(selected)
	option.item_selected.connect(func(index: int) -> void: callback.call(index))
	row.add_child(option)


func _key_row(action: String, keyboard: String, gamepad: String) -> void:
	var row := _row_shell(56)
	var label := Label.new()
	label.text = action
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", TEXT)
	row.add_child(label)
	for value in [keyboard, gamepad]:
		var chip := Label.new()
		chip.text = value
		chip.custom_minimum_size = Vector2(92, 32)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_theme_color_override("font_color", ACCENT)
		chip.add_theme_stylebox_override("normal", _style(ACCENT_SOFT, Color(0.25, 0.65, 0.55, 0.45), 1, 6))
		row.add_child(chip)


func _row_shell(height := 74) -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = height
	panel.add_theme_stylebox_override("panel", _style(SURFACE, BORDER, 1, 9))
	_content.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)
	return row


func _row_text(row: HBoxContainer, title_text: String, description: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", TEXT)
	box.add_child(title)
	var sub := Label.new()
	sub.text = description
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", MUTED)
	box.add_child(sub)
	row.add_child(box)
	return box


func _info_card(title_text: String, body: String) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(ACCENT_SOFT, Color(0.2, 0.55, 0.47, 0.45), 1, 9))
	_content.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)
	var label := Label.new()
	label.text = body
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", TEXT)
	box.add_child(label)


func _style_button(button: Button, active: bool) -> void:
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", ACCENT if active else TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_stylebox_override("normal", _style(ACCENT_SOFT if active else Color.TRANSPARENT,
		Color(0.25, 0.7, 0.58, 0.35) if active else Color.TRANSPARENT, 1 if active else 0, 8))
	button.add_theme_stylebox_override("hover", _style(SURFACE_HOVER, BORDER, 1, 8))
	button.add_theme_stylebox_override("pressed", _style(ACCENT_SOFT, ACCENT, 1, 8))


func _style(color: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _reset_defaults() -> void:
	_settings.reset_defaults()
	_show_tab(_active_tab)
	_select_sfx()


func _hover_sfx() -> void:
	if not is_inside_tree():
		return
	var audio := get_tree().get_first_node_in_group("audio_manager")
	if audio != null and audio.has_method("play_sfx"):
		audio.play_sfx("menu_move", -8.0)


func _select_sfx() -> void:
	if not is_inside_tree():
		return
	var audio := get_tree().get_first_node_in_group("audio_manager")
	if audio != null and audio.has_method("play_sfx"):
		audio.play_sfx("menu_select", -7.0)
