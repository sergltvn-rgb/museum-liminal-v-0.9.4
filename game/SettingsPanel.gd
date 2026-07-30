extends Control
## The settings screen, rendered as one page of the Night Containment Service
## terminal.
##
## signal closed -- emitted by ESC / pad B / pad START and by the rail's Back
## button. MenuManager owns the visibility; this node never hides itself.
##
#
# STAGE 9.2 -- THE DIALOG BECOMES A SCREEN
#
# Until now this was a 980x610 floating card centred on a scrim: its own header,
# its own glow, its own idea of what a panel is. Every other full-screen surface
# in the game is moving onto game/TerminalFrame.gd, and a settings dialog that
# hovers in front of the terminal instead of being drawn BY it is the last place
# the player can see two different devices at once. So the card is gone. What is
# left of the old `_build()` is the part that was never chrome -- the rail, the
# scrolling page and the rows -- and it now lives in `frame.body`.
#
# What the frame supplies, so this file stopped drawing it:
#   masthead      HUD_PROTO_HEADER, the institution line every screen carries.
#   title         MENU_SETTINGS, in the frame's own TITLE slot.
#   status        the night readout, the shift clock and the signal-integrity
#                 meter. The clock is deliberately blank (the frame prints an em
#                 dash): the shift is paused while this page is up, and a
#                 running clock on a configuration screen would be a lie.
#   legend        ESC / Back, silkscreen along the bottom.
#   scrim + glow  replaced by the frame's opaque SURFACE backdrop and the CRT
#                 glass. There is nothing to dim, because the terminal is not a
#                 window over the world -- it IS the screen.
# The core-state chip stays hidden: it needs the TERM_CORE_* rows, which are not
# in localization/game.csv yet, and TerminalFrame hides the chip on an empty key
# rather than inventing a state.
#
# Corruption is left at 0. The settings page is the one screen the player must be
# able to read when everything else has gone wrong -- a rotting Language row is a
# player who cannot switch back to a language they can read.
#
#
# PLANES AND CONTRAST -- RECOMPUTED, BECAUSE THE PAGE BEHIND THE ROWS CHANGED
#
# The old dialog was SURFACE_RAISED with SURFACE row cards recessed into it. The
# terminal page is SURFACE, so keeping the cards at SURFACE would have left them
# with no fill step at all -- the 1.08:1 bug this project already fixed once,
# re-created by moving the page out from under them. The cards are therefore
# RAISED now, and the rail lost its slab entirely in favour of a hairline rule,
# which is the frame's own vocabulary.
#
# WCAG 2.1, channels linearised with `c/12.92 if c <= 0.04045 else
# ((c+0.055)/1.055) ** 2.4`, `L = 0.2126R + 0.7152G + 0.0722B`, ratio
# `(Lhi+0.05)/(Llo+0.05)`. Measured through the tube: TerminalFrame runs
# CRTOverlay at CRT_INTENSITY_CLEAN here (corruption is 0), whose worst-lit pixel
# leaves k = 0.882 of every channel -- the same k its own contrast table uses,
# and a conservative floor for the body region, which is better lit than the
# corners the table was measured at.
#
#   text                        on            clean    through the tube
#   ON_SURFACE  row title       SURFACE_RAISED 11.99         9.92
#   MUTED       row description SURFACE_RAISED  6.30         5.32
#   ACCENT      row value       SURFACE_RAISED  6.09         5.15
#   MUTED       page subtitle   SURFACE         9.08         7.18
#   ACCENT      rail eyebrow    SURFACE         8.78         6.94
#   ON_SURFACE  info card       ACCENT_FILL/S. 12.13        10.51
#   ACCENT      info card head  ACCENT_FILL/S.  6.29         5.45
# Worst text on this page: 5.15 : 1, against a gate of 4.5.
#
# Non-text, gate 3:1. A row card's BORDER hairline is 3.18:1 against its own
# SURFACE_RAISED fill clean but only 2.79:1 through the tube -- so the hairline is
# NOT what makes a card readable here, and is not asked to be: the fill carries a
# 1.44:1 step over the page and the border is measured against the page it is
# drawn on, SURFACE, where it is 3.76:1. The focus ring is BORDER_ACCENT, 5.15:1
# against the card fill through the tube.
#
#
# MEANING IS NEVER CARRIED BY COLOUR ALONE
#
# The selected tab used to differ from the other three only in hue -- accent fill,
# accent border, accent text. It now also carries a 4 px bar down its left edge,
# which is shape and survives a monochrome display, and it is still the only
# button whose page is on screen, which is position. Every row's state is spoken
# in words (SET_ON / SET_OFF, the percentage beside each slider, the dropdown's
# own text), never by a colour swatch.
#
#
# NOTHING HERE ANIMATES
#
# This file starts no tween, no timer and no _process. The only moving parts on
# the screen belong to TerminalFrame and CRTOverlay, both of which read
# SettingsManager.reduced_flashes themselves and go still when it is on -- which
# is the state a player configuring the game from this very page can reach
# without leaving it, because the frame subscribes to `settings_changed`.
#
#
# KEYBOARD AND GAMEPAD (stage 5.2, unchanged in shape)
#
#   Tab / Shift+Tab ....... the whole page in visual order, wrapping
#   Up / Down ............. within the column you are in (rail, or page)
#   Left / Right .......... cross between the rail and the page
#                           (on a slider, Left/Right is the value -- Godot's
#                            Slider consumes those two and only those two)
#   Enter / Space / pad A .. activate (ui_accept)
#   Escape / pad START ..... close (the "pause" action)
#   Escape / pad B ......... close (ui_cancel, the console-conventional back)
# The Back button moved out of the old header and into the foot of the rail, so
# the rail is now the whole left-hand column of the focus graph: four tabs, then
# Back. See `_wire_focus()` for why every edge is stated rather than inferred.

signal closed

## Progress file GameManager writes and MenuManager reads. Duplicated here for
## one readout -- the night on the terminal's status cluster -- rather than
## reaching into a sibling script's privates for it. Nothing in this file writes.
const SAVE_PATH := "user://museum_save.cfg"
## Highest night the game ships, i.e. GameManager.MAX_NIGHT. Only used to reject
## a corrupt save; a wrong number here shows a wrong readout, never a crash.
const MAX_NIGHT := 3

## The four pages, in rail order. Kept as keys rather than as translated strings
## so `_retranslate()` can rebuild the rail when the player changes the language
## from the row two pages down.
const TAB_KEYS := ["SET_TAB_AUDIO", "SET_TAB_GRAPHICS", "SET_TAB_CONTROLS", "SET_TAB_ACCESS"]
## Geometric symbols, not emoji: they carry no colour, no script and no cultural
## reading, and every one of them is paired with the tab's own translated name.
##
## AND EVERY ONE OF THEM IS IN THE FONT THAT DRAWS THEM. This read
## ["◉", "◇", "⌁", "＋"], and the rail is a column of Buttons, which resolve
## ui/museum_theme.tres -> fonts/JetBrainsMono.ttf. Checked in-engine with
## Font.has_char(): that face carries ◇ and does NOT carry ◉, ⌁ or ＋. Three of
## the four tabs were drawing .notdef, which reads as a mojibake bug rather than
## as an icon, and it fails the same way in Open Sans SemiBold (the engine
## fallback, which is missing all four) -- so this was not a stock-Godot problem
## that the new fonts fixed.
##
## The replacements are present in JetBrains Mono, in Oswald and in the engine
## fallback, so the rail cannot box whichever of the three a control ends up
## resolving. The guard for the next edit is TerminalType.has_glyphs(), which
## asks the face the Control really has instead of a list somebody wrote down.
##
##   ≈  audio: a waveform.
##   ¤  graphics: a disc throwing light, which is a screen.
##   ×  controls: a four-way cross, which is a d-pad.
##   ±  access: an adjustment, which is what the page is.
const TAB_ICONS := ["≈", "¤", "×", "±"]

## The mixer, in the order the audio page shows it. `bus` is the AudioServer bus
## name game/AudioManager.gd routes its players to (Master -> Music / Ambience /
## SFX); the labels are catalogue keys owned by the localization pass this round.
##
## Master is NOT in this table. It already has a row driven by
## SettingsManager.set_master_volume(), which is the one bus level that is
## persisted to user://museum_settings.cfg -- see the note above `_build_audio()`.
const VOLUME_ROWS := [
	{"bus": "Music", "label": "SET_MUSIC_VOLUME", "desc": "SET_MUSIC_VOLUME_DESC"},
	{"bus": "SFX", "label": "SET_SFX_VOLUME", "desc": "SET_SFX_VOLUME_DESC"},
	{"bus": "Ambience", "label": "SET_AMBIENCE_VOLUME", "desc": "SET_AMBIENCE_VOLUME_DESC"},
]

## Row labels for the Controls tab, paired with the actions they describe.
##
## The rows used to be five hand-written [label, keyboard, gamepad] triples, and
## a transcription can only be right on the day it is written: this one had
## already drifted from the map it claimed to document. `_build_controls()` now
## renders the right-hand chips from `InputMap.action_get_events()` -- the same
## table the game polls -- so the page cannot lie again.
##
## Only actions that already have a row label in localization/game.csv appear;
## the rest of the map (jump, sprint, flashlight, radar_scan, cam_prev/cam_next,
## confirm and the look axes) has nothing to be called on screen and is reported
## instead of invented. "crouch" was added to the catalogue with the stealth
## crouch, precisely so it could be shown here: a stealth verb the player is
## never told about is the same as no verb at all.
const BINDING_ROWS := [
	# Four actions, one row: the player thinks of this as a single control.
	{"label": "SET_BIND_MOVE",
		"actions": ["move_forward", "move_left", "move_back", "move_right"]},
	# Held, not toggled, and the pad legend comes out of InputMap, so the R3 that
	# this action took off belt cycling is visible to the player on this page.
	{"label": "SET_BIND_CROUCH", "actions": ["crouch"]},
	{"label": "SET_BIND_INTERACT", "actions": ["interact"]},
	{"label": "SET_BIND_TABLET", "actions": ["tablet"]},
	{"label": "SET_BIND_DROP", "actions": ["drop_item"]},
	# The loud sibling of the row above, and the only aimed noise the operator
	# has. A decoy the player is never told about is not a mechanic.
	{"label": "SET_BIND_THROW", "actions": ["throw_item"]},
	# Two rows for six actions, because that is how the player counts them: the
	# number row is one control, cycling is another. Legends are read out of
	# InputMap, so the wheel and R3 / BACK appear here without being transcribed
	# -- and a player who never notices the belt bar still finds it on this page.
	{"label": "SET_BIND_BELT",
		"actions": ["slot_1", "slot_2", "slot_3", "slot_4"]},
	{"label": "SET_BIND_BELT_CYCLE", "actions": ["slot_next", "slot_prev"]},
	{"label": "SET_BIND_PAUSE", "actions": ["pause"]},
]

## Printed when an action carries no binding of the kind a column shows.
const NO_BINDING := "—"

## Width of the marker down the selected tab's left edge. Shape, not hue.
const TAB_MARKER_WIDTH := 4

var _settings: Node
var _frame: TerminalFrame
var _content: VBoxContainer
var _scroll: ScrollContainer
var _tabs: Array[Button] = []
var _eyebrow: Label
var _autosave_hint: Label
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
		# The frame caches reduced_flashes and the CRT settings; re-reading them
		# as the screen is raised is one group lookup and a repaint.
		if _frame != null:
			_frame.refresh()
			_frame.set_night(_saved_night())


## Opening the dialog lands on the tab that is already selected, not on the
## first widget of the page: the rail is what the player has to move through to
## reach the other three pages, and starting there means Down/Up is immediately
## the useful key. One press of Right (or Tab) is on the page.
func _grab_initial_focus() -> void:
	if _active_tab >= 0 and _active_tab < _tabs.size():
		_tabs[_active_tab].grab_focus()


func _build() -> void:
	_frame = TerminalFrame.new()
	_frame.name = "Terminal"
	add_child(_frame)
	_frame.set_title("MENU_SETTINGS")
	# Night from the save, clock blank. See the header for why the clock is a
	# deliberate em dash rather than a number.
	_frame.set_status(_saved_night(), -1.0)
	# The legend is the frame's silkscreen: it never rots and never dims, which
	# is exactly the guarantee the one key that leaves this screen needs.
	_frame.set_keys([["ESC", "MENU_BACK"]])

	var columns := HBoxContainer.new()
	columns.name = "Settings Body"
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 0)
	_frame.body.add_child(columns)

	columns.add_child(_sidebar())

	# The rail used to be a recessed slab welded to the dialog's left edge. On a
	# page that is already SURFACE a second SURFACE slab is invisible, and a
	# raised one would put the navigation on the same plane as the row cards. A
	# hairline is what the terminal uses everywhere else to divide a region, and
	# UITheme.build_theme() already dresses VSeparator with BORDER.
	columns.add_child(VSeparator.new())

	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 26)
	content_margin.add_theme_constant_override("margin_top", 4)
	content_margin.add_theme_constant_override("margin_right", 6)
	content_margin.add_theme_constant_override("margin_bottom", 4)
	columns.add_child(content_margin)

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


func _sidebar() -> Control:
	var margin := MarginContainer.new()
	margin.name = "Rail"
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 4)

	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 214
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	# What the old dialog printed above its own title. The frame owns the title
	# now, so the eyebrow becomes what it always read as: the heading of the
	# navigation list. Wrapped, because it is a long line in both locales and the
	# rail is 214 px wide.
	_eyebrow = Label.new()
	_eyebrow.text = tr("SET_EYEBROW")
	_eyebrow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text(_eyebrow, UITheme.CAPTION, UITheme.ACCENT)
	box.add_child(_eyebrow)

	var gap := Control.new()
	gap.custom_minimum_size.y = 6
	box.add_child(gap)

	for i in range(TAB_KEYS.size()):
		var button := Button.new()
		button.text = _tab_text(i)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(190, 48)
		# Was FOCUS_NONE, which is what made the other three pages unreachable
		# without a mouse. _style_button() reads this back, so leaving Godot's
		# default (FOCUS_ALL) is all that is needed to get the ring as well.
		button.pressed.connect(_on_tab_pressed.bind(i))
		button.mouse_entered.connect(_hover_sfx)
		# The rail's hover click, now also on arrival by keyboard or pad: the
		# same event from the player's point of view, so the same sound.
		button.focus_entered.connect(_hover_sfx)
		box.add_child(button)
		_tabs.append(button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	# The old header's Back button. It says only "Back": the frame's legend
	# already prints the key that does the same thing, and a button captioned
	# with its own shortcut next to a legend printing that shortcut is the same
	# sentence twice.
	_close_button = Button.new()
	_close_button.text = tr("MENU_BACK")
	_close_button.custom_minimum_size.y = 44
	_style_button(_close_button, false)
	_close_button.pressed.connect(func() -> void: closed.emit())
	_close_button.focus_entered.connect(_hover_sfx)
	box.add_child(_close_button)

	_autosave_hint = Label.new()
	_autosave_hint.text = tr("SET_AUTOSAVE_HINT")
	UITheme.apply_text(_autosave_hint, UITheme.CAPTION, UITheme.MUTED)
	box.add_child(_autosave_hint)
	return margin


func _tab_text(index: int) -> String:
	# Concatenated rather than formatted: the icon is a layout glyph, not part of
	# a translated sentence, so there is no format string here to put in the
	# catalogue and no `%` for a translated argument to be fed to.
	return TAB_ICONS[index] + "    " + tr(TAB_KEYS[index])


func _on_tab_pressed(index: int) -> void:
	if index == _active_tab:
		# Re-pressing the page you are already on should still feel like a press,
		# but there is nothing to rebuild and no reason to throw the focus.
		_select_sfx()
		return
	_show_tab(index)
	_select_sfx()


## Rebuild the page. Silent on purpose: this runs on the very first build and on
## every language change as well as on a real tab press, and a click on startup
## is a sound the player did not ask for. `_on_tab_pressed()` adds the click.
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
## from geometry, and neither survives this page. Tree order is construction
## order, and construction order here is rail -> page while the page is torn down
## and rebuilt on every tab switch, so any link the engine cached points at a
## freed node. Geometry is no better: the rail is a column of five buttons beside
## a column of rows of differing heights, so "nearest control to the right"
## resolves to a different row for each tab, and to the value label rather than
## the slider whenever a row happens to be tall. So every edge is stated, and
## stated in the order the eye reads them.
##
##   Tab / Shift+Tab  one ring over everything: the rail top to bottom (four
##                    tabs, then Back), then the page top to bottom. Wraps.
##   Up / Down        stays in its column -- the rail wraps within its five
##                    buttons, the page wraps within its own controls.
##   Left / Right     crosses the gutter: any rail button -> the first control on
##                    the page, any page control -> the tab that is currently
##                    lit.
##
## Left/Right is inert while a slider has the focus, by design: Godot's Slider
## consumes ui_left / ui_right to change the value and passes ui_up / ui_down
## through, which is why the vertical ring is the one that has to be complete.
func _wire_focus() -> void:
	var rail: Array[Control] = []
	for tab in _tabs:
		rail.append(tab)
	if _close_button != null:
		rail.append(_close_button)

	var page: Array[Control] = []
	page.append_array(_page_focusables)

	var ring: Array[Control] = []
	ring.append_array(rail)
	ring.append_array(page)

	_link_ring(ring, false)
	_link_ring(rail, true)
	_link_ring(page, true)

	# Right off the rail aims at the first *row*: landing on the top of the page
	# is what the player asked for by pressing towards it. With an empty page
	# (which no tab produces today) it falls back to Back, so the key is never a
	# dead press.
	var page_entry: Control = page[0] if not page.is_empty() else _close_button
	for control in rail:
		if page_entry != null:
			control.focus_neighbor_right = control.get_path_to(page_entry)
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
	# UITheme.panel_raised() with the hairline swapped for the focus ring's colour
	# and width. Content margins are set explicitly by the factory, so widening
	# the border cannot move anything inside the card. The FILL is unchanged, so
	# focusing a row does not make it jump a plane.
	card.add_theme_stylebox_override("panel", UITheme.stylebox(
		UITheme.SURFACE_RAISED, UITheme.BORDER_ACCENT, UITheme.FOCUS_WIDTH,
		UITheme.RADIUS_LG, UITheme.PAD_X + 4, UITheme.PAD_Y + 4))


func _on_row_focus_exited(card: PanelContainer) -> void:
	if card != null and is_instance_valid(card):
		UITheme.apply_panel(card)


## Master plus one row per mixer bus.
##
## Master goes through SettingsManager, which is the only path that PERSISTS: it
## writes user://museum_settings.cfg and re-applies on launch. The other three
## call AudioManager.set_bus_volume_linear() directly and are therefore live for
## the session only -- SettingsManager has no field for them and that file is not
## this agent's to change. The handoff names the four lines it needs; until they
## land, a player who turns the ambience down finds it up again next launch.
##
## A bus that is not in the layout gets no row at all. A slider that moves and
## changes nothing is the exact sin the accessibility note below is about, and it
## is no less a lie about audio than it is about flashes.
func _build_audio() -> void:
	_section_title(tr("SET_TAB_AUDIO"), tr("SET_AUDIO_DESC"))
	_slider_row(tr("SET_MASTER_VOLUME"), tr("SET_MASTER_VOLUME_DESC"), true,
		_settings.master_volume * 100.0, 0.0, 100.0, 1.0,
		func(value: float) -> void: _settings.set_master_volume(value / 100.0))
	for row: Dictionary in VOLUME_ROWS:
		var bus: String = row["bus"]
		if AudioServer.get_bus_index(bus) < 0:
			continue
		var label_key: String = row["label"]
		var desc_key: String = row["desc"]
		_slider_row(tr(label_key), tr(desc_key), true,
			_bus_linear(bus) * 100.0, 0.0, 100.0, 1.0,
			func(value: float) -> void: _set_bus_linear(bus, value / 100.0))
	_info_card(tr("SET_CARD_AUDIO_TITLE"), tr("SET_CARD_AUDIO_BODY"))


## Where a bus slider starts. Read back off AudioServer rather than remembered,
## because AudioManager and SettingsManager both write these levels and the
## server is the one place that knows the answer after they have.
func _bus_linear(bus_name: String) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return 1.0
	if AudioServer.is_bus_mute(index):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(index)), 0.0, 1.0)


func _set_bus_linear(bus_name: String, linear: float) -> void:
	var audio := _audio()
	if audio != null and audio.has_method("set_bus_volume_linear"):
		audio.set_bus_volume_linear(bus_name, linear)


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
	_slider_row(tr("SET_MOUSE_SENS"), tr("SET_MOUSE_SENS_DESC"), false,
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
## Re-audited this round, reader by reader, because a switch that promises an
## accommodation and delivers none is worse for the player who needs it than an
## option that is honestly absent:
##   language        SettingsManager.set_language -> TranslationServer.set_locale
##                   plus a NOTIFICATION_TRANSLATION_CHANGED sweep, which this
##                   file now answers as well (see `_notification`).
##   reduced_flashes read by FirstMuseumMap's alarm pulse, GameplayEnhancements
##                   (void + watch), SecurityCameraTablet's static, Compass,
##                   TaskBlock, LightProps, CRTOverlay and TerminalFrame.
##   high_contrast   SettingsManager._apply_contrast, a floor over the map's own
##                   colour grade.
##   large_text      SettingsManager._apply_ui_scale -> content_scale_factor.
## All four are real. Nothing on this page is write-only.
##
## "Субтитры" and "Уменьшить движение" used to sit in this list. Both wrote to
## the config file and were read by nothing, anywhere. They are gone from here
## and from game/SettingsManager.gd; the reasoning and the route back are
## recorded at the top of that file.
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


## SECTION, not TITLE: the frame's own header already carries a TITLE-sized
## "Настройки" two rules above this, and two 28 px headings stacked on one page
## is a hierarchy that says nothing. The page heading is now the step below it.
func _section_title(title_text: String, subtitle: String) -> void:
	var title := Label.new()
	title.text = title_text
	UITheme.apply_text(title, UITheme.SECTION)
	_content.add_child(title)
	var sub := Label.new()
	sub.text = subtitle
	UITheme.apply_text(sub, UITheme.LABEL, UITheme.MUTED)
	_content.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	_content.add_child(gap)


## One slider row. `as_percent` picks the readout beside it: a 0..100 bus level
## prints "72%", and the mouse sensitivity -- which is a 100..600 stand-in for
## 0.001..0.006 radians per pixel -- prints "2.50". Two formats, one flag,
## no key strings threaded through the row builder to mean "which one".
func _slider_row(title_text: String, description: String, as_percent: bool,
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
		value_label.text = _slider_text(v, as_percent)
		callback.call(v))
	row.add_child(slider)
	value_label.text = _slider_text(value, as_percent)
	# Left / Right adjust the value, Up / Down leave the slider -- Godot's Slider
	# consumes only the axis it is drawn on, so a horizontal one hands the
	# vertical pair straight back to focus navigation.
	_register_focusable(slider, card)


func _slider_text(value: float, as_percent: bool) -> String:
	return "%d%%" % int(value) if as_percent else "%.2f" % (value / 100.0)


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
	# The row cards, RAISED. They used to be the recessed plane inside a raised
	# dialog; the dialog is gone and the page behind them is the terminal's own
	# SURFACE, so recessed would mean "the same colour as the page" -- the 1.08:1
	# bug this project already fixed once. panel_raised() puts them 1.44:1 above
	# the page, with the BORDER hairline reading 3.76:1 against that page.
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = height
	UITheme.apply_panel(panel)
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
	# out of the tab order stays out of it. Nothing on this page is any more:
	# the rail's FOCUS_NONE was the whole of bug 5.2, and it is gone. Every
	# button here therefore arrives with Godot's FOCUS_ALL and keeps it, focus
	# ring included -- _show_tab() re-styles the four tabs on every switch, and
	# this is what stops that from quietly revoking their focusability.
	UITheme.apply_button(button, UITheme.LABEL,
		UITheme.ACCENT if active else UITheme.ON_SURFACE,
		button.focus_mode != Control.FOCUS_NONE)
	if not active:
		return
	# UITheme has no "selected" state, but it has the pair the palette uses for
	# one: ACCENT_FILL over an ACCENT border, i.e. button_pressed(). The heavy
	# left edge is added on top so the selection is also a SHAPE -- on a
	# monochrome display, or for a player who cannot separate the accent from the
	# page, the lit tab is still the one with the bar down its side.
	var style := UITheme.button_pressed()
	style.border_width_left = TAB_MARKER_WIDTH
	button.add_theme_stylebox_override("normal", style)


func _reset_defaults() -> void:
	_settings.reset_defaults()
	# Full retranslate, not just a page rebuild: reset_defaults() puts the locale
	# back to Russian by calling TranslationServer directly, WITHOUT the
	# propagate_notification() that set_language() sends -- so nothing else is
	# going to repaint the rail, and an English player would be left with English
	# tabs over a Russian page.
	_retranslate()
	_select_sfx()


## Re-read every string this file owns. Godot delivers
## NOTIFICATION_TRANSLATION_CHANGED to the whole tree when
## SettingsManager.set_language() propagates it, and until now this panel ignored
## it: switching to English left the rail, the rows and the hint in Russian until
## the player closed the screen and opened it again -- from the very row that had
## just promised to change the language.
##
## TerminalFrame answers the same notification for its own masthead, title and
## legend, so nothing here touches those.
##
## Deferred by one idle frame because the notification arrives from inside
## `_settings.set_language()`, which this page reaches through an OptionButton's
## own `item_selected` -- rebuilding the page synchronously would free that
## button, and its popup, while both are still unwinding.
func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or _content == null:
		return
	_retranslate.call_deferred()


func _retranslate() -> void:
	# Reachable one idle frame late, so re-check what `_notification` checked.
	if _content == null or not is_inside_tree():
		return
	for i in range(_tabs.size()):
		_tabs[i].text = _tab_text(i)
	if _eyebrow != null:
		_eyebrow.text = tr("SET_EYEBROW")
	if _autosave_hint != null:
		_autosave_hint.text = tr("SET_AUTOSAVE_HINT")
	if _close_button != null:
		_close_button.text = tr("MENU_BACK")
	_show_tab(_active_tab)


## The night the terminal reports, read from the progress file GameManager
## writes. A missing or unreadable file is night 1, which is what the main menu
## shows for the same state.
func _saved_night() -> int:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 1
	return clampi(int(config.get_value("progress", "night", 1)), 1, MAX_NIGHT)


func _audio() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("audio_manager")


func _hover_sfx() -> void:
	var audio := _audio()
	if audio != null and audio.has_method("play_sfx"):
		audio.play_sfx("menu_move", -8.0)


func _select_sfx() -> void:
	var audio := _audio()
	if audio != null and audio.has_method("play_sfx"):
		audio.play_sfx("menu_select", -7.0)
