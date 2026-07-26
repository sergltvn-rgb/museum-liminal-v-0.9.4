extends Control
## Premium settings overlay built entirely from native Godot controls.

signal closed

# The eight colour constants and the `_style()` factory that used to live here
# were promoted wholesale into game/UITheme.gd -- that file is literally this
# file's shape with the padding lifted into arguments. Everything below now
# routes through UITheme, so there is one palette instead of two.
#
#
# KEYBOARD AND GAMEPAD (stage 5.2)
#
# This dialog could not be operated without a mouse. The sidebar tabs were
# FOCUS_NONE, so the four pages were unreachable; the sliders, switches and
# dropdowns were focusable by Godot's defaults but sat inside a ScrollContainer
# with follow_focus off, so tabbing onto a row below the fold moved an invisible
# cursor. Both are fixed below, and the focus graph is now *stated* rather than
# inferred -- see `_wire_focus()` for why inference cannot work here.
#
# What the player can do now, with no mouse at all:
#   Tab / Shift+Tab ....... the whole dialog in visual order, wrapping
#   Up / Down ............. within the column you are in (rail, or page)
#   Left / Right .......... cross between the rail and the page
#                           (on a slider, Left/Right is the value -- Godot's
#                            Slider consumes those two and only those two)
#   Enter / Space / pad A .. activate (ui_accept)
#   Escape / pad START ..... close (the "pause" action, as before)
#   Escape / pad B ......... close (ui_cancel, the console-conventional back)
# The pad's D-pad and left stick drive ui_up/down/left/right out of the box --
# game/InputBootstrap.gd deliberately leaves the D-pad free of game actions for
# exactly this -- so no new binding was needed to make the dialog pad-navigable.

## Row labels for the Controls tab, paired with the actions they describe.
##
## The rows used to be five hand-written [label, keyboard, gamepad] triples, and
## a transcription can only be right on the day it is written: this one had
## already drifted from the map it claimed to document. `_build_controls()` now
## renders the right-hand chips from `InputMap.action_get_events()` -- the same
## table the game polls -- so the page cannot lie again.
##
## Only the five actions that already have a row label in localization/game.csv
## appear. The catalogue is frozen this round, so the rest of the map (jump,
## sprint, flashlight, radar_scan, cam_prev/cam_next, confirm and the look axes)
## has nothing to be called on screen and is reported instead of invented.
const BINDING_ROWS := [
	# Four actions, one row: the player thinks of this as a single control.
	{"label": "SET_BIND_MOVE",
		"actions": ["move_forward", "move_left", "move_back", "move_right"]},
	{"label": "SET_BIND_INTERACT", "actions": ["interact"]},
	{"label": "SET_BIND_TABLET", "actions": ["tablet"]},
	{"label": "SET_BIND_DROP", "actions": ["drop_item"]},
	{"label": "SET_BIND_PAUSE", "actions": ["pause"]},
]

## Printed when an action carries no binding of the kind a column shows.
const NO_BINDING := "—"

var _settings: Node
var _content: VBoxContainer
var _scroll: ScrollContainer
var _tabs: Array[Button] = []
var _close_button: Button
var _active_tab := 0
## Focusable controls on the page currently shown, in visual top-to-bottom
## order. Rebuilt from scratch by every `_show_tab()`, because the page is.
var _page_focusables: Array[Control] = []
## The row card `_row_shell()` most recently produced, so the row builder that
## called it can hand it to `_register_focusable()` without every one of them
## having to thread a second return value through.
var _pending_card: PanelContainer


func _ready() -> void:
	# The panel is built once and then toggled by MenuManager with `visible`,
	# so "opened" is a visibility change, not a _ready. Without this the second
	# and every later opening starts with nothing focused, and the first key the
	# player presses does nothing at all.
	visibility_changed.connect(_on_visibility_changed)


func setup(settings: Node) -> void:
	_settings = settings
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_show_tab(0)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# "pause" is ESC + pad START, ui_cancel is ESC + pad B. Both are accepted:
	# START is how this game opens and closes its menus, B is what every pad
	# player's thumb reaches for to back out. A single ESC satisfies both, and
	# `or` short-circuits, so the signal is still emitted exactly once.
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func _on_visibility_changed() -> void:
	if visible and is_inside_tree():
		_grab_initial_focus()


## Opening the dialog lands on the tab that is already selected, not on the
## first widget of the page: the rail is what the player has to move through to
## reach the other three pages, and starting there means Down/Up is immediately
## the useful key. One press of Right (or Tab) is on the page.
func _grab_initial_focus() -> void:
	if _active_tab >= 0 and _active_tab < _tabs.size():
		_tabs[_active_tab].grab_focus()


func _build() -> void:
	# A modal dim over whatever is running behind, so SCRIM -- the same call
	# MenuManager._open_pause_menu() makes for the same job.
	var shade := ColorRect.new()
	shade.color = UITheme.SCRIM
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	# Subtle glow behind the panel, retinted from the old one-off mint to the CRT
	# green. Alpha drops 0.12 -> 0.05 because ACCENT is far brighter than that
	# mint: this rect is larger than the dialog, so it IS the dialog's immediate
	# surround, and at 0.12 it lifts the backdrop until SURFACE_RAISED reads only
	# 1.209:1 above it -- under the 1.30 gate, i.e. the bug this stage removes,
	# re-created by decoration. At 0.05 it is 1.356:1, matching the old mint's
	# 1.357:1 exactly: same visual weight, palette hue, plane step intact.
	var glow := ColorRect.new()
	glow.color = Color(UITheme.ACCENT, 0.05)
	glow.anchor_left = 0.16
	glow.anchor_top = 0.12
	glow.anchor_right = 0.84
	glow.anchor_bottom = 0.88
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(glow)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)

	# PLANE 2 of 3 -- the dialog itself. Was BG #11161d, which the sidebar sat
	# 1.04:1 from and the row cards 1.08:1 from: three planes, all the same
	# colour. panel_raised() is SURFACE_RAISED, 1.44:1 above the SCRIM behind
	# it and carrying the BORDER hairline, exactly like MenuManager's feedback
	# dialog. Everything inside is now measured against this.
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 610)
	UITheme.apply_panel(panel)
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

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Off by default in Godot, and the graphics page is taller than the viewport:
	# without this, tabbing past the fold moved the focus onto a row that stayed
	# off screen, which is the same as having no keyboard support at all.
	_scroll.follow_focus = true
	content_margin.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	_scroll.add_child(_content)


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
	UITheme.apply_text(eyebrow, UITheme.CAPTION, UITheme.ACCENT)
	titles.add_child(eyebrow)
	var title := Label.new()
	title.text = tr("MENU_SETTINGS")
	UITheme.apply_text(title, UITheme.TITLE)
	titles.add_child(title)
	_close_button = Button.new()
	_close_button.text = tr("SET_BACK")
	_close_button.custom_minimum_size = Vector2(142, 44)
	_style_button(_close_button, false)
	_close_button.pressed.connect(func() -> void: closed.emit())
	_close_button.focus_entered.connect(_hover_sfx)
	row.add_child(_close_button)
	return margin


func _sidebar() -> Control:
	# PLANE 1 of 3 -- the rail, recessed. Was #0d1218 against BG #11161d: 1.04:1,
	# i.e. nothing. SURFACE is 1.44:1 *below* the SURFACE_RAISED dialog, keeping
	# the original intent (the rail is the darkest thing on screen) while making
	# it an actual step. Hand-rolled rather than apply_panel(panel, false)
	# because the rail is welded to the dialog's left edge: it needs radius 0 and
	# no border, or it becomes a rounded box floating inside the frame.
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 228
	panel.add_theme_stylebox_override("panel",
		UITheme.stylebox(UITheme.SURFACE, Color.TRANSPARENT, 0, 0))
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
		# Was FOCUS_NONE, which is what made the other three pages unreachable
		# without a mouse. _style_button() reads this back, so leaving Godot's
		# default (FOCUS_ALL) is all that is needed to get the ring as well.
		button.pressed.connect(_show_tab.bind(i))
		button.mouse_entered.connect(_hover_sfx)
		# The rail's hover click, now also on arrival by keyboard or pad: the
		# same event from the player's point of view, so the same sound.
		button.focus_entered.connect(_hover_sfx)
		box.add_child(button)
		_tabs.append(button)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var hint := Label.new()
	hint.text = tr("SET_AUTOSAVE_HINT")
	UITheme.apply_text(hint, UITheme.CAPTION, UITheme.MUTED)
	box.add_child(hint)
	return panel


func _show_tab(index: int) -> void:
	_active_tab = index
	for i in range(_tabs.size()):
		_style_button(_tabs[i], i == index)
	for child in _content.get_children():
		child.queue_free()
	_page_focusables.clear()
	_pending_card = null
	match index:
		0: _build_audio()
		1: _build_graphics()
		2: _build_controls()
		3: _build_accessibility()
	_wire_focus()
	_restore_focus_after_rebuild()
	_select_sfx()


## The page the focus was standing on has just been freed. Switching tabs is
## safe -- the focus is on a rail button, which survives -- but "Restore
## defaults" rebuilds the page from under its own button, and a dialog with
## nothing focused is a dialog the keyboard has stopped driving.
func _restore_focus_after_rebuild() -> void:
	if not visible or not is_inside_tree():
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var focused := viewport.gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused) and not focused.is_queued_for_deletion():
		return
	_grab_initial_focus()


## The focus graph, written out in VISUAL order.
##
## Godot derives the Tab ring from scene-tree order and the arrow-key neighbours
## from geometry, and neither survives this dialog. Tree order is construction
## order, and construction order here is header -> rail -> page while the page is
## torn down and rebuilt on every tab switch, so any link the engine cached
## points at a freed node. Geometry is no better: the rail is a column of four
## buttons beside a column of rows of differing heights, so "nearest control to
## the right" resolves to a different row for each tab, and to the value label
## rather than the slider whenever a row happens to be tall. So every edge is
## stated, and stated in the order the eye reads them.
##
##   Tab / Shift+Tab  one ring over everything: the Back button (topmost
##                    interactive element, in the header), then the rail top to
##                    bottom, then the page top to bottom. Wraps.
##   Up / Down        stays in its column -- the rail wraps within its four
##                    tabs, the page wraps within Back plus its own controls
##                    (Back sits at the top of the page's column, not the
##                    rail's).
##   Left / Right     crosses the gutter: any tab -> the first control on the
##                    page, any page control -> the tab that is currently lit.
##
## Left/Right is inert while a slider has the focus, by design: Godot's Slider
## consumes ui_left / ui_right to change the value and passes ui_up / ui_down
## through, which is why the vertical ring is the one that has to be complete.
func _wire_focus() -> void:
	var page: Array[Control] = []
	if _close_button != null:
		page.append(_close_button)
	page.append_array(_page_focusables)

	var rail: Array[Control] = []
	for tab in _tabs:
		rail.append(tab)

	var ring: Array[Control] = []
	if _close_button != null:
		ring.append(_close_button)
	ring.append_array(rail)
	ring.append_array(_page_focusables)

	_link_ring(ring, false)
	_link_ring(rail, true)
	_link_ring(page, true)

	# Right off the rail aims at the first *row*, not at Back: Back is already a
	# key press away (Escape), and landing on the top of the page is what the
	# player asked for by pressing towards it.
	var page_entry: Control = _page_focusables[0] if not _page_focusables.is_empty() else _close_button
	for tab in rail:
		if page_entry != null:
			tab.focus_neighbor_right = tab.get_path_to(page_entry)
	var rail_entry: Control = _tabs[_active_tab] if _active_tab < _tabs.size() else null
	for control in page:
		if rail_entry != null:
			control.focus_neighbor_left = control.get_path_to(rail_entry)


## Chain `controls` into a ring that wraps at both ends. `vertical` writes the
## arrow-key neighbours; otherwise the Tab ring. A one-element list links to
## itself, which is what "the only place to go is here" should do.
static func _link_ring(controls: Array[Control], vertical: bool) -> void:
	var count := controls.size()
	if count == 0:
		return
	for i in range(count):
		var control := controls[i]
		var next := controls[(i + 1) % count]
		var previous := controls[(i - 1 + count) % count]
		if vertical:
			control.focus_neighbor_bottom = control.get_path_to(next)
			control.focus_neighbor_top = control.get_path_to(previous)
		else:
			control.focus_next = control.get_path_to(next)
			control.focus_previous = control.get_path_to(previous)


## Enrol a page control in the focus order, newest last -- the row builders are
## called in the order the rows are drawn, so "creation order" and "visual
## order" are the same list here, and the ring above can take it as it stands.
##
## `card` is the row the control belongs to. Godot's focus stylebox reaches
## Buttons, CheckButtons and OptionButtons through the project theme but there
## is no such entry for a Slider, so the focused row is outlined instead: it is
## a bigger, calmer target than a 34px slider handle, and it is the same cue for
## all four widget kinds rather than three different ones.
func _register_focusable(control: Control, card: PanelContainer = null) -> void:
	control.focus_mode = Control.FOCUS_ALL
	control.focus_entered.connect(_on_row_focus_entered.bind(card))
	control.focus_exited.connect(_on_row_focus_exited.bind(card))
	_page_focusables.append(control)


func _on_row_focus_entered(card: PanelContainer) -> void:
	_hover_sfx()
	if card == null or not is_instance_valid(card):
		return
	# UITheme.panel() with the hairline swapped for the focus ring's colour and
	# width. Content margins are set explicitly by the factory, so widening the
	# border cannot move anything inside the card.
	card.add_theme_stylebox_override("panel", UITheme.stylebox(
		UITheme.SURFACE, UITheme.BORDER_ACCENT, UITheme.FOCUS_WIDTH,
		UITheme.RADIUS_LG, UITheme.PAD_X + 4, UITheme.PAD_Y + 4))


func _on_row_focus_exited(card: PanelContainer) -> void:
	if card != null and is_instance_valid(card):
		UITheme.apply_panel(card, false)


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
	for row: Dictionary in BINDING_ROWS:
		var label: String = row["label"]
		var actions: Array = row["actions"]
		_key_row(tr(label), _keyboard_glyphs(actions), _gamepad_glyphs(actions))


## Every distinct keyboard legend bound to `actions`, in the order given.
##
## Four single letters are printed as one word, because "WASD" is how that
## particular cluster is named everywhere including on the keys themselves.
## Anything else is separated, because Tab followed by Escape run together is
## not a key. (Do not quote the concatenation here: the localization sweep reads
## every line, comments included, and an upper-case quoted word is how it spells
## "catalogue key".)
func _keyboard_glyphs(actions: Array) -> String:
	var glyphs := _glyphs(actions, true)
	if glyphs.is_empty():
		return NO_BINDING
	for glyph in glyphs:
		if glyph.length() != 1:
			return " / ".join(glyphs)
	return "".join(glyphs)


func _gamepad_glyphs(actions: Array) -> String:
	var glyphs := _glyphs(actions, false)
	return NO_BINDING if glyphs.is_empty() else " / ".join(glyphs)


## Deduplicated legends for one column of one row. The four movement actions all
## resolve to the same stick, so the pad column of that row must not read
## "Left stick / Left stick / Left stick / Left stick".
func _glyphs(actions: Array, keyboard: bool) -> PackedStringArray:
	var out := PackedStringArray()
	for entry in actions:
		var action := StringName(entry)
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			var glyph := _keyboard_glyph(event) if keyboard else _gamepad_glyph(event)
			if glyph.is_empty() or out.has(glyph):
				continue
			out.append(glyph)
	return out


## InputBootstrap binds physical keycodes, so the legend is asked for by physical
## position and comes back in the engine's own spelling ("Tab", "Escape"),
## upper-cased to match the chip's other half.
func _keyboard_glyph(event: InputEvent) -> String:
	var key_event := event as InputEventKey
	if key_event != null:
		var code: Key = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE \
			else key_event.keycode
		return OS.get_keycode_string(code).to_upper()
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null:
		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
	return ""


## Pad legends are printed, not translated: A / B / X / Y / LB / RT / START are
## the letters moulded into the plastic and read the same in both shipped
## locales -- which is why the old hardcoded list only ever translated one of
## these chips. The exception is the stick, which is a noun, and the right stick
## is deliberately blank: it is the look axis, no row in BINDING_ROWS shows it,
## and game.csv has no label for it this round (reported, not invented).
func _gamepad_glyph(event: InputEvent) -> String:
	var button_event := event as InputEventJoypadButton
	if button_event != null:
		match button_event.button_index:
			JOY_BUTTON_A: return "A"
			JOY_BUTTON_B: return "B"
			JOY_BUTTON_X: return "X"
			JOY_BUTTON_Y: return "Y"
			JOY_BUTTON_LEFT_SHOULDER: return "LB"
			JOY_BUTTON_RIGHT_SHOULDER: return "RB"
			JOY_BUTTON_LEFT_STICK: return "L3"
			JOY_BUTTON_RIGHT_STICK: return "R3"
			JOY_BUTTON_START: return "START"
			JOY_BUTTON_BACK: return "SEL"
			JOY_BUTTON_DPAD_UP: return "▲"
			JOY_BUTTON_DPAD_DOWN: return "▼"
			JOY_BUTTON_DPAD_LEFT: return "◀"
			JOY_BUTTON_DPAD_RIGHT: return "▶"
		return "#%d" % int(button_event.button_index)
	var motion_event := event as InputEventJoypadMotion
	if motion_event != null:
		match motion_event.axis:
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y: return tr("SET_PAD_LEFT_STICK")
			JOY_AXIS_TRIGGER_LEFT: return "LT"
			JOY_AXIS_TRIGGER_RIGHT: return "RT"
	return ""


## One dropdown and three toggles, every one of which does something (5.1).
##
## "Субтитры" and "Уменьшить движение" used to sit in this list. Both wrote to
## the config file and were read by nothing, anywhere -- a switch that promises
## an accommodation and delivers none, which for the player who needs it is
## worse than an option that is honestly absent. They are gone from here and
## from game/SettingsManager.gd; the reasoning and the route back are recorded
## at the top of that file.
func _build_accessibility() -> void:
	_section_title(tr("SET_TAB_ACCESS"), tr("SET_ACCESS_DESC"))
	_option_row(tr("ACCESS_LANGUAGE"), tr("SET_LANGUAGE_DESC"), ["Русский", "English"],
		1 if _settings.language == "en" else 0,
		func(index: int) -> void: _settings.set_language("en" if index == 1 else "ru"))
	_toggle_row(tr("ACCESS_REDUCED_FLASHES"), tr("SET_REDUCED_FLASHES_DESC"), _settings.reduced_flashes,
		func(value: bool) -> void: _settings.set_reduced_flashes(value))
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
	# No row card of its own, so no card to outline -- the button carries the
	# focus ring apply_button() already gave it.
	_register_focusable(reset)


func _section_title(title_text: String, subtitle: String) -> void:
	var title := Label.new()
	title.text = title_text
	UITheme.apply_text(title, UITheme.TITLE)
	_content.add_child(title)
	var sub := Label.new()
	sub.text = subtitle
	UITheme.apply_text(sub, UITheme.LABEL, UITheme.MUTED)
	_content.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	_content.add_child(gap)


func _slider_row(title_text: String, description: String, key: String,
		value: float, min_value: float, max_value: float, step: float,
		callback: Callable) -> void:
	var row := _row_shell()
	var card := _pending_card
	var text_box := _row_text(row, title_text, description)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 58
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.apply_text(value_label, UITheme.BODY, UITheme.ACCENT)
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
	# Left / Right adjust the value, Up / Down leave the slider -- Godot's Slider
	# consumes only the axis it is drawn on, so a horizontal one hands the
	# vertical pair straight back to focus navigation.
	_register_focusable(slider, card)


func _toggle_row(title_text: String, description: String, value: bool,
		callback: Callable) -> void:
	var row := _row_shell()
	var card := _pending_card
	var text_box := _row_text(row, title_text, description)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var toggle := CheckButton.new()
	toggle.text = tr("SET_ON") if value else tr("SET_OFF")
	toggle.button_pressed = value
	toggle.custom_minimum_size = Vector2(92, 42)
	# apply_text, not apply_button: a CheckButton draws its own switch graphic
	# and the row card already supplies the surface, so it wants no stylebox.
	UITheme.apply_text(toggle, UITheme.BODY, UITheme.ACCENT)
	toggle.toggled.connect(func(on: bool) -> void:
		toggle.text = tr("SET_ON") if on else tr("SET_OFF")
		callback.call(on))
	row.add_child(toggle)
	_register_focusable(toggle, card)


func _option_row(title_text: String, description: String, options: Array,
		selected: int, callback: Callable) -> void:
	var row := _row_shell()
	var card := _pending_card
	var text_box := _row_text(row, title_text, description)
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(180, 42)
	for item in options:
		option.add_item(str(item))
	option.select(selected)
	option.item_selected.connect(func(index: int) -> void: callback.call(index))
	row.add_child(option)
	# Enter / Space / pad A open the list; the popup then owns Up / Down and
	# Escape itself, and hands the focus back to this button when it closes.
	_register_focusable(option, card)


func _key_row(action: String, keyboard: String, gamepad: String) -> void:
	var row := _row_shell(56)
	var label := Label.new()
	label.text = action
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_text(label, UITheme.BODY)
	row.add_child(label)
	for value in [keyboard, gamepad]:
		var chip := Label.new()
		chip.text = value
		chip.custom_minimum_size = Vector2(92, 32)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITheme.apply_text(chip, UITheme.BODY, UITheme.ACCENT)
		# Accent-tinted tag: no apply_* helper covers it, since apply_panel only
		# offers the two neutral surfaces. RADIUS_SM is the chip radius by name.
		chip.add_theme_stylebox_override("normal", UITheme.stylebox(
			UITheme.ACCENT_FILL, UITheme.ACCENT_DIM, UITheme.BORDER_WIDTH, UITheme.RADIUS_SM))
		row.add_child(chip)


func _row_shell(height := 74) -> HBoxContainer:
	# PLANE 3 of 3 -- the row cards. Was SURFACE #171e27 on BG #11161d: 1.08:1,
	# with a BORDER only 1.61:1 from its own fill, so the cards were invisible
	# twice over. panel() is SURFACE, 1.44:1 *below* the SURFACE_RAISED dialog,
	# plus the BORDER hairline at 3.18:1 against the dialog and 4.58:1 against
	# the card's own fill. Recessed rather than raised because the page they sit
	# on is already the raised plane.
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = height
	UITheme.apply_panel(panel, false)
	_content.add_child(panel)
	# Handed to the caller through a field rather than a second return value:
	# only the three interactive row builders want it, and every one of them
	# reads it on the line after this call returns.
	_pending_card = panel
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
	UITheme.apply_text(title, UITheme.BODY)
	box.add_child(title)
	var sub := Label.new()
	sub.text = description
	UITheme.apply_text(sub, UITheme.CAPTION, UITheme.MUTED)
	box.add_child(sub)
	row.add_child(box)
	return box


func _info_card(title_text: String, body: String) -> void:
	# Accent-tinted callout, so neither apply_panel surface fits. RADIUS_LG to
	# match the row cards it is stacked with -- 9 was never on the shape scale.
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.stylebox(
		UITheme.ACCENT_FILL, UITheme.ACCENT_DIM, UITheme.BORDER_WIDTH, UITheme.RADIUS_LG))
	_content.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var title := Label.new()
	title.text = title_text
	UITheme.apply_text(title, UITheme.CAPTION, UITheme.ACCENT)
	box.add_child(title)
	var label := Label.new()
	label.text = body
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text(label, UITheme.CAPTION)
	box.add_child(label)


func _style_button(button: Button, active: bool) -> void:
	# apply_button re-enables focus by default; pass through whatever the caller
	# already decided rather than forcing it, so a button that is deliberately
	# out of the tab order stays out of it. Nothing in this dialog is any more:
	# the rail's FOCUS_NONE was the whole of bug 5.2, and it is gone. Every
	# button here therefore arrives with Godot's FOCUS_ALL and keeps it, focus
	# ring included -- _show_tab() re-styles the four tabs on every switch, and
	# this is what stops that from quietly revoking their focusability.
	UITheme.apply_button(button, UITheme.LABEL,
		UITheme.ACCENT if active else UITheme.ON_SURFACE,
		button.focus_mode != Control.FOCUS_NONE)
	if active:
		# UITheme has no "selected" state, but it has the pair the palette uses
		# for one: ACCENT_FILL over an ACCENT border, i.e. button_pressed().
		button.add_theme_stylebox_override("normal", UITheme.button_pressed())


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
