extends Node
## Main menu, pause menu and the Notion Worker feedback form -- all three
## rendered as PAGES OF THE SAME DEVICE.
##
## Install: add a plain Node to the main scene and attach this script.
## - The game starts paused on the main menu.
## - ESC toggles the pause menu during play.
## - Progress (current night) is written by GameManager to
##   user://museum_save.cfg; the menu only reads it.
##
##
## STAGE 9.1 -- THE MENU IS A SCREEN OF THE TERMINAL
##
## What was here before was a title, a subtitle and a stack of six identical
## buttons floating on a flat rectangle: a web landing page wearing the game's
## palette. It shared nothing with the CCTV tablet, the protocol screen or the
## settings dialog except colours, so the first thing the player ever saw told
## them nothing about what kind of thing they were about to operate.
##
## Everything now sits inside game/TerminalFrame.gd. The masthead
## (HUD_PROTO_HEADER -- "ПЕРВЫЙ МУЗЕЙ · СЛУЖБА НОЧНОГО СДЕРЖИВАНИЯ"), the
## right-hand status cluster, the two hairlines and the footer key legend are the
## frame's; this file supplies a title key, a status, a legend and one body page.
## Pressing Start is logging in for the shift, and the pause menu is the same
## device with the same masthead showing a different page -- which is the
## acceptance test the plan set: two screenshots side by side must read as one
## instrument.
##
## THE PRIMARY ACTION IS STILL ONE KEYPRESS AWAY. The frame is chrome, not
## friction: _open_main_menu() focuses the primary button, so Enter (or pad A)
## starts the shift from a cold boot exactly as it did before, and the footer
## legend says so.
##
##
## ONE PRIMARY ACTION PER SCREEN
##
## Every page has exactly one accent-filled button -- Start / Continue on the
## main page, Resume on the pause page, Send on the feedback form -- and nothing
## else on that page is allowed the accent fill. The subordinate actions are a
## type step smaller (LABEL against SECTION), a third shorter, and MUTED rather
## than ON_SURFACE. Three cues, none of them colour on its own.
##
## Reset progress is the one destructive action in the game's UI and is treated
## as such: DANGER text, and separated from the rest by a rule so it cannot be
## hit on the way to Quit. It is still a single press -- see THE STRINGS THIS
## FILE DOES NOT OWN for the confirmation step that wants two catalogue rows.
##
##
## KEYBOARD, PAD AND ESCAPE
##
## Every button on every page is focusable (UITheme.apply_button, which brings
## the focus ring with it), and each page's focusables are linked into a ring
## that WRAPS at both ends -- Godot's geometric neighbour search stops at the
## last item, so without this the pad player walks into a wall at the bottom of
## the list. Arrival by keyboard or pad plays the same click as arrival by mouse.
##
## Escape is predictable from every panel, which it was not:
##   main menu ...... nothing to escape to; ESC is deliberately inert.
##   pause menu ..... ESC / pad START resumes.
##   settings ....... SettingsPanel answers ESC and pad B itself and emits
##                    `closed`; this file only re-shows the page underneath.
##   feedback ....... ESC and pad B close the form. THIS WAS THE BUG: _input()
##                    returned early whenever the form was visible and the form
##                    had no handler of its own, so the only way out was
##                    clicking Back with the mouse.
## Pad B is accepted inside the form and nowhere else on purpose: outside it,
## ui_cancel shares its button with drop_item, and a pause menu that opened
## every time the player put something down would be worse than no pad support.
##
##
## ACCESSIBILITY
##
## Nothing here animates -- no tween, no _process, no timer -- so
## SettingsManager.reduced_flashes has nothing of this file's to switch off. The
## frame's own degradation honours it (TerminalFrame's header explains how) and
## _raise() calls frame.refresh() on every open, so a toggle flipped in the pause
## menu takes effect on the page behind it without a restart.
##
## Contrast, computed against TerminalFrame's worst-lit body pixel (every channel
## scaled by k = 0.892, which is the c=1 body centre with the tube at full ramp
## -- the menus run at c=0, so this is pessimistic by a wide margin):
##   ON_SURFACE on the primary fill (ACCENT_FILL over SURFACE) ... 10.71 : 1
##   MUTED on SURFACE (every secondary button) .................... 7.33 : 1
##   DANGER on SURFACE (Reset progress) ........................... 6.17 : 1
## Gate is 4.5 : 1. The primary button is legible with the fill removed as well,
## which is what makes the fill a redundant cue rather than the only one.
##
## The comment field is a TextEdit, and UITheme.build_theme() has no TextEdit
## entry, so it was the one focusable control in the game with no focus ring at
## all. _build_feedback_panel() gives it UITheme.focus() explicitly.
##
##
## THE STRINGS THIS FILE DOES NOT OWN
##
## localization/game.csv belongs to another agent this round, so nothing below
## names a row that does not exist yet -- an unknown key would render as a raw
## KEY on the title bar of the first screen the player ever sees. Where a row is
## missing the element is simply not built, and the layout is unchanged.
##
##   key                   en                  ru                  feed in at
##   TERM_TITLE_PAUSED     SHIFT PAUSED        СМЕНА ПРИОСТАНОВЛЕНА  _open_pause_menu -> set_title
##   MENU_RESET_CONFIRM    Press again to wipe Нажмите ещё раз       _reset_progress, first press
##   MENU_RESET_WARNING    This erases all three nights.  Это стирает все три ночи.  under the Reset button
##   TERM_CORE_NOMINAL     CORE: NOMINAL       ЯДРО: НОРМА           _apply_status -> set_core_state
##
## The shift clock reads as an em dash on both pages for the same reason plus one
## more: GameManager keeps `_time_left` (a countdown) and no elapsed-time field,
## and the total it counts down from is a constant this file may not reach for by
## name -- both localization sweeps read every quoted upper-case token in game/
## and would take a script-constant lookup for a catalogue key. Give GameManager
## a `shift_seconds() -> float` and pass it to `_frame.set_shift_time()`.

const SAVE_PATH := "user://museum_save.cfg"
const TUTORIAL_PROGRESS_PATH := "user://museum_progress.cfg"
const TUTORIAL_SCENE := "res://scenes/TutorialPrologue.tscn"
const SettingsPanelScript := preload("res://game/SettingsPanel.gd")
const TITLE_TEXT := "MENU_TITLE"
const SUBTITLE_TEXT := "MENU_SUBTITLE_SHIFT"

## Width of a menu page's column. Left-aligned rather than centred: the eye
## already has a reading line down the left edge (masthead, title, body), and a
## centred stack of buttons is the one arrangement that reads as a web page.
const COLUMN_WIDTH := 460
## Measured page heights, against the frame's body region:
##   main page 415, feedback form 411
##   body 476 at 1280x720, 656 at 1600x900, 836 at 1920x1080
##   body 398 at 1280x720 with `large_text` (content_scale_factor 1.12), 559 at
##   1600x900, 720 at 1920x1080
## So every shipped combination fits without a scrollbar except the tightest one,
## the smallest supported window with the large-interface option on, where the
## page scrolls by 17 px. That is the accommodation working, not failing: the
## alternative to a scrollbar there is a Quit button drawn over the key legend.
const PRIMARY_HEIGHT := 58
const SECONDARY_HEIGHT := 40
const COLUMN_GAP := 8
## Gap that separates a group from the one below it.
const GROUP_GAP := 12
const FEEDBACK_WIDTH := 560
const COMMENT_HEIGHT := 96

## CanvasLayer for the main menu and the pause menu -- one layer, two pages.
##
## 600-699 is the "menus and pause" band of the decade scale written out in
## game/TaskBlock.gd and tabulated in full above GameManager._build_hud(). This
## is the SECOND HIGHEST layer the shipping game draws; only the debug console
## (960, debug builds only) is above it.
##
## MUST SIT ABOVE, and each of these is a bug the player can see if it does not:
##   199 TaskBlock ................. the pause menu is opaque; a task readout
##                                   printed over it was the reviewer's blocker.
##   200 CCTV tablet / 210 protocol  screens the player raised are put down by
##                                   pausing, not drawn through it.
##   320 Curator proximity alert ... a paused game is not being hunted.
##   420 fail / win, 430 ending .... ESC over a terminal page still reaches the
##                                   menu. This ordering was inverted while
##                                   GameManager moved to 420 and this file
##                                   stayed at 20.
##   510 trial terminal frame ...... pausing inside a pocket dimension must not
##                                   be read through a failing tube.
##   590 Curator catch screen ...... the catch is the only takeover that covers
##                                   a trial, and pause still covers it.
## MUST SIT BELOW:
##   710 tutorial prologue ......... the replay owns the screen it is teaching
##                                   on; it is not a pausable moment.
##   960 service console ........... F9 is above everything by definition.
const MENU_LAYER := 610

var _layer: CanvasLayer
var _frame: TerminalFrame
var _pages: VBoxContainer
var _main_page: ScrollContainer
var _pause_page: ScrollContainer
var _feedback_page: ScrollContainer
var _start_button: Button
var _resume_button: Button
var _subtitle: Label
var _settings_panel
var _settings_panel_ready := false
var _return_to_pause := false
var _in_main_menu := true

## Focusables per page, in visual order. Used both to wrap the focus ring and to
## put the keyboard back on the first item when a page reappears.
var _main_focus: Array[Control] = []
var _pause_focus: Array[Control] = []
var _feedback_focus: Array[Control] = []

## Controls whose text is a plain catalogue key, so switching language in the
## settings dialog re-renders the menu underneath it instead of leaving it in the
## language it was built in.
var _localised: Array[Control] = []

# Notion integration UI elements
var _feedback_manager: Node = null
var _feedback_panel: PanelContainer
var _fb_name_input: LineEdit
var _fb_comment_input: TextEdit
var _fb_url_input: LineEdit
var _fb_status_label: Label
var _fb_submit_btn: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Dynamically instantiate the FeedbackManager script
	_feedback_manager = Node.new()
	_feedback_manager.set_script(preload("res://game/FeedbackManager.gd"))
	_feedback_manager.name = "FeedbackManager"
	add_child(_feedback_manager)
	_feedback_manager.request_completed.connect(_on_feedback_completed)

	_build_ui()
	_open_main_menu.call_deferred()


func _input(event: InputEvent) -> void:
	if _settings_panel != null and _settings_panel.visible:
		# SettingsPanel answers ESC and pad B itself and emits `closed`.
		return
	if _feedback_open():
		# The form's own way out. "pause" is ESC + pad START, ui_cancel is ESC +
		# pad B; a single ESC satisfies both and `or` short-circuits, so the form
		# closes exactly once.
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_close_feedback_menu()
		return
	# ui_cancel is NOT accepted here: outside the form it is pad B, which is also
	# drop_item, and pausing the game every time the player puts something down
	# is worse than no pad shortcut at all. Pad START is bound to "pause".
	if not event.is_action_pressed("pause") or _in_main_menu:
		return
	get_viewport().set_input_as_handled()
	if get_tree().paused:
		_resume()
	else:
		_open_pause_menu()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _frame != null:
		_retranslate()


# --- Menu flow --------------------------------------------------------------

func _open_main_menu() -> void:
	_in_main_menu = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_page(_main_page)
	_frame.set_title(TITLE_TEXT)
	# No clock: the shift has not started, so the readout has no value to give
	# and says so with an em dash rather than inventing one.
	_frame.set_status(_saved_night(), -1.0)
	_refresh_start_button()
	_raise()
	_start_button.grab_focus()


func _open_pause_menu() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_page(_pause_page)
	# Same masthead, same title, different page -- see the header. A dedicated
	# title wants TERM_TITLE_PAUSED, which is not in the catalogue yet.
	_frame.set_title(TITLE_TEXT)
	_frame.set_status(_live_night(), -1.0)
	_raise()
	if _resume_button != null:
		_resume_button.grab_focus()
	_sfx("menu_select")


## Raise the terminal and re-read the settings it depends on. refresh() is one
## group lookup and a repaint, so it is cheap enough to do on every open -- and
## it is what makes a reduced_flashes toggle flipped in the pause menu land on
## the page behind it without a restart.
func _raise() -> void:
	_layer.visible = true
	_frame.refresh()
	_apply_keys()


func _resume() -> void:
	# Buttons are focusable since stage 6.2, so the focus has to be handed back
	# explicitly: a still-focused (merely hidden) menu button would swallow the
	# arrow keys during play and fire on Enter. Only our own controls are
	# released -- the CCTV tablet may legitimately hold focus behind the menu.
	var viewport := get_viewport()
	if viewport != null:
		var focused := viewport.gui_get_focus_owner()
		if focused != null and _layer.is_ancestor_of(focused):
			focused.release_focus()
	_layer.visible = false
	get_tree().paused = false
	Input.mouse_mode = _gameplay_mouse_mode()
	_sfx("menu_select")


## The mouse mode the world wants back once the pause menu closes.
## The CCTV tablet is a cursor-driven overlay and owns the mouse while it is
## open (see SecurityCameraTablet._toggle); capturing the cursor here left the
## player inside the camera feed with nothing to click.
func _gameplay_mouse_mode() -> Input.MouseMode:
	var parent := get_parent()
	if parent != null:
		var tablet := parent.get_node_or_null("SecurityCameraTablet")
		if tablet != null and bool(tablet.get("_open")):
			return Input.MOUSE_MODE_VISIBLE
	return Input.MOUSE_MODE_CAPTURED


## Start the shift. Nothing stands between this button and the museum any more.
##
## It used to open the tutorial scene instead whenever tutorial/done was unset,
## which is what made the first press of Start mean two different things and the
## walk out of the tutorial land back on this menu, where the player pressed
## Start a second time. Since stage 8.6 the orientation is taught inside the
## museum's own daytime segment (GameManager's "Orientation" section), so there
## is nothing here to divert to and the gate is gone rather than weakened.
##
## THE GATE'S REPLACEMENT, since removing it outright is what shipped an infinite
## tutorial loop once before: the done-vs-skipped pair in museum_progress.cfg is
## still written and still respected -- GameManager._teach_recorded() reads it to
## decide whether to run the orientation at all, and _teach_write() sets it. The
## loop cannot come back, because no button's behaviour depends on those flags:
## the worst a corrupt flag can now do is show or hide eight one-line hints.
func _start_game() -> void:
	_in_main_menu = false
	_resume()


## The old orientation sector, kept as an optional replay rather than deleted:
## it is a complete, working scene, it is the only place the jump control is
## taught, and a player who wants the controls without the museum around them
## can still have it. Finishing it writes tutorial/done, which also tells the
## museum's own orientation to stand down -- someone who has just been walked
## through the controls does not need to be walked through them again.
func _open_tutorial() -> void:
	_sfx("menu_select")
	get_tree().paused = false
	get_tree().change_scene_to_file(TUTORIAL_SCENE)


func _reset_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "night", 1)
	config.save(SAVE_PATH)
	# Both keys are cleared explicitly: the orientation stands down on
	# done-OR-skipped, so leaving a stale skipped=true behind would give a reset
	# player a museum that never teaches them anything. (Today the fresh
	# ConfigFile also overwrites the file wholesale, but that stops being true
	# the moment someone adds a load() here.)
	var tutorial_config := ConfigFile.new()
	tutorial_config.set_value("tutorial", "done", false)
	tutorial_config.set_value("tutorial", "skipped", false)
	tutorial_config.save(TUTORIAL_PROGRESS_PATH)
	_sfx("menu_select")
	# Rebuild the whole scene so the GameManager picks up night 1.
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_main_menu() -> void:
	_sfx("menu_select")
	get_tree().paused = false
	get_tree().reload_current_scene()


func _quit() -> void:
	get_tree().quit()


func _settings() -> Node:
	return get_tree().get_first_node_in_group("settings_manager")


func _open_settings() -> void:
	# Late retry: on the first attempt the SettingsManager may not have been in
	# the tree yet. Never show an unpopulated panel -- that used to soft-lock
	# the menu, because MenuManager._input ignores ESC while it is visible.
	if not _prepare_settings_panel():
		_sfx("fail")
		return
	_return_to_pause = not _in_main_menu
	_settings_panel.visible = true
	_sfx("menu_select")


func _close_settings() -> void:
	_settings_panel.visible = false
	_focus_first(_pause_focus if _return_to_pause else _main_focus)
	_sfx("menu_select")


func _open_feedback_menu() -> void:
	_show_page(_feedback_page)
	_apply_keys()
	_set_status("", UITheme.MUTED)
	if _feedback_manager != null:
		_fb_url_input.text = _feedback_manager.webhook_url
	_fb_name_input.grab_focus()
	_sfx("menu_select")


func _close_feedback_menu() -> void:
	_show_page(_pause_page if not _in_main_menu else _main_page)
	_apply_keys()
	_focus_first(_pause_focus if not _in_main_menu else _main_focus)
	_sfx("menu_select")


## True while the feedback form is the page the player is looking at.
##
## `_feedback_panel.visible` is NOT that question: the panel's own flag is always
## true and it is its PAGE that gets hidden, so asking the panel produced a menu
## whose ESC key was permanently routed to a form nobody could see.
func _feedback_open() -> bool:
	return _layer != null and _layer.visible \
		and _feedback_page != null and _feedback_page.visible


## Exactly one body page is visible at a time. The settings dialog is not a page
## -- it is a modal over the whole terminal and lives above the frame.
func _show_page(page: Control) -> void:
	for child in _pages.get_children():
		var control := child as Control
		if control != null:
			control.visible = control == page
	if _settings_panel != null:
		_settings_panel.visible = false


## Puts the keyboard back on the first item of whichever page just reappeared.
## Hiding a Control releases its focus, so after a sub-panel closes nothing is
## focused and the arrow keys have nowhere to start walking from.
func _focus_first(controls: Array[Control]) -> void:
	for control in controls:
		if not is_instance_valid(control):
			continue
		var button := control as BaseButton
		if button != null and button.disabled:
			continue
		control.grab_focus()
		return


func _submit_feedback() -> void:
	var p_name := _fb_name_input.text.strip_edges()
	var comment := _fb_comment_input.text.strip_edges()
	var url := _fb_url_input.text.strip_edges()

	if comment.is_empty():
		_set_status(tr("MENU_FB_ERR_COMMENT"), UITheme.DANGER)
		_fb_comment_input.grab_focus()
		return

	if url.is_empty():
		_set_status(tr("MENU_FB_ERR_URL"), UITheme.DANGER)
		_fb_url_input.grab_focus()
		return

	_set_status(tr("MENU_FB_SENDING"), UITheme.MUTED)
	_fb_submit_btn.disabled = true

	if _feedback_manager != null:
		_feedback_manager.save_config(url)
		_feedback_manager.send_feedback(p_name, comment)


func _on_feedback_completed(success: bool, message: String) -> void:
	_fb_submit_btn.disabled = false
	_set_status(message, UITheme.SUCCESS if success else UITheme.DANGER)
	if success:
		_fb_comment_input.text = ""


## The one place the status line's text and its semantic colour are set, so the
## four call sites cannot drift onto four different reds again.
##
## The colour is never the whole message: every string fed in here is a full
## sentence from the catalogue, so a player who cannot use the hue reads the
## same outcome from the words.
func _set_status(text: String, color: Color) -> void:
	if _fb_status_label == null:
		return
	_fb_status_label.text = text
	UITheme.apply_text(_fb_status_label, UITheme.LABEL, color)


func _saved_night() -> int:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 1
	return clampi(int(config.get_value("progress", "night", 1)), 1, 3)


## The night the running shift is on, which is not always the saved one -- the
## save is written when a night completes. Falls back to the file whenever the
## manager cannot answer: it may not be in the tree yet, and `get()` on an absent
## field returns null, which int() does not merely coerce but raises on. (Seen
## for real: a sibling script that fails to parse leaves its node scriptless and
## every field lookup on it null.)
func _live_night() -> int:
	var manager := _game_manager()
	if manager == null:
		return _saved_night()
	var night: Variant = manager.get("_night")
	if typeof(night) != TYPE_INT:
		return _saved_night()
	return clampi(int(night), 1, 3)


func _game_manager() -> Node:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("GameManager")


func _sfx(sound: String) -> void:
	var am := get_tree().get_first_node_in_group("audio_manager")
	if am != null and am.has_method("play_sfx"):
		am.play_sfx(sound)


func _move_sfx() -> void:
	_sfx("menu_move")


# --- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "Menu Layer"
	_layer.layer = MENU_LAYER
	_layer.visible = false
	add_child(_layer)

	# The frame owns the backdrop, the masthead, the status cluster, the rules
	# and the footer legend, and it is opaque -- both menus are a screen of the
	# terminal, not a translucent sheet over the world. That is a deliberate
	# change from the old SCRIM pause overlay: TerminalFrame's contrast table is
	# computed against one opaque SURFACE, and a see-through terminal is also the
	# wrong fiction.
	_frame = TerminalFrame.new()
	_frame.name = "Terminal"
	_layer.add_child(_frame)

	_pages = _frame.body_column()
	_pages.name = "Pages"

	_build_main_page()
	_build_pause_page()
	_build_feedback_panel()

	# Settings. Added to the layer ABOVE the frame rather than into the body: it
	# is a modal dialog with its own scrim over the whole terminal, not a page of
	# it, and it must cover the masthead and legend like any other modal.
	_settings_panel = SettingsPanelScript.new()
	_settings_panel.visible = false
	_layer.add_child(_settings_panel)
	# Wire the close handler before setup(): a panel that failed to populate
	# must still answer ESC and its own Back button.
	_settings_panel.closed.connect(_close_settings)
	_prepare_settings_panel()


func _build_main_page() -> void:
	_main_page = _make_page()
	var column := _make_column(_main_page)

	_start_button = _make_primary(column, _start_game)
	_gap(column, GROUP_GAP)
	_main_focus.append(_start_button)

	for entry: Array in [
			["MENU_TUTORIAL", _open_tutorial],
			["MENU_SETTINGS", _open_settings],
			["MENU_FEEDBACK", _open_feedback_menu]]:
		_main_focus.append(_make_secondary(column, String(entry[0]), entry[1]))

	# Below the rule: the two ways out. Reset progress wipes all three nights, so
	# it is separated by shape (its own group under a hairline) and by colour
	# (DANGER), never by colour alone -- and it is nowhere near the primary.
	_gap(column, GROUP_GAP)
	column.add_child(HSeparator.new())
	_gap(column, GROUP_GAP)
	_main_focus.append(_make_secondary(column, "MENU_RESET_PROGRESS",
		_reset_progress, UITheme.DANGER))
	_main_focus.append(_make_secondary(column, "MENU_QUIT", _quit))

	_gap(column, GROUP_GAP)
	_subtitle = Label.new()
	_subtitle.text = Loc.fmt("MENU_SUBTITLE_FMT", [tr(SUBTITLE_TEXT)])
	UITheme.apply_text(_subtitle, UITheme.CAPTION, UITheme.MUTED)
	column.add_child(_subtitle)

	_link_ring(_main_focus)


func _build_pause_page() -> void:
	_pause_page = _make_page()
	var column := _make_column(_pause_page)

	_resume_button = _make_primary(column, _resume)
	_resume_button.text = tr("MENU_RESUME")
	_register_text(_resume_button, "MENU_RESUME")
	_gap(column, GROUP_GAP)
	_pause_focus.append(_resume_button)

	for entry: Array in [
			["MENU_SETTINGS", _open_settings],
			["MENU_FEEDBACK", _open_feedback_menu],
			["MENU_MAIN_MENU", _to_main_menu]]:
		_pause_focus.append(_make_secondary(column, String(entry[0]), entry[1]))

	_gap(column, GROUP_GAP)
	column.add_child(HSeparator.new())
	_gap(column, GROUP_GAP)
	_pause_focus.append(_make_secondary(column, "MENU_QUIT", _quit))

	_link_ring(_pause_focus)


## Populates the settings panel. Split out of _build_ui() so that a missing
## SettingsManager can no longer abort the rest of the menu construction (the
## feedback panel used to be lost with it, leaving _feedback_panel null), and
## so the lookup can be retried the next time the player opens Settings.
func _prepare_settings_panel() -> bool:
	if _settings_panel_ready:
		return true
	if _settings_panel == null:
		return false
	var settings := _settings()
	if settings == null:
		push_error("MenuManager: SettingsManager is missing")
		return false
	_settings_panel.setup(settings)
	_settings_panel_ready = true
	return true


func _build_feedback_panel() -> void:
	_feedback_page = _make_page()

	_feedback_panel = PanelContainer.new()
	_feedback_panel.name = "Feedback"
	_feedback_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_feedback_panel.custom_minimum_size.x = FEEDBACK_WIDTH
	(_feedback_page.get_child(0) as VBoxContainer).add_child(_feedback_panel)

	# Was #14141a at 95% on a near-black backdrop -- 1.10:1, and no border at all,
	# so the form read as text floating in the void. panel_raised() is 1.44:1
	# above SURFACE and carries the BORDER hairline every other panel has.
	UITheme.apply_panel(_feedback_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", COLUMN_GAP)
	_feedback_panel.add_child(layout)

	var fb_title := Label.new()
	fb_title.text = tr("MENU_FEEDBACK")
	UITheme.apply_text(fb_title, UITheme.SECTION)
	_register_text(fb_title, "MENU_FEEDBACK")
	layout.add_child(fb_title)

	_fb_name_input = _field(layout, "MENU_FB_NAME", UITheme.LABEL, UITheme.ON_SURFACE)
	_fb_name_input.placeholder_text = tr("MENU_FB_NAME_HINT")

	# Comment
	var comment_label := Label.new()
	comment_label.text = tr("MENU_FB_COMMENT")
	UITheme.apply_text(comment_label, UITheme.LABEL)
	_register_text(comment_label, "MENU_FB_COMMENT")
	layout.add_child(comment_label)

	_fb_comment_input = TextEdit.new()
	_fb_comment_input.placeholder_text = tr("MENU_FB_COMMENT_HINT")
	_fb_comment_input.custom_minimum_size = Vector2(0, COMMENT_HEIGHT)
	_fb_comment_input.focus_mode = Control.FOCUS_ALL
	UITheme.apply_text(_fb_comment_input)
	# UITheme.build_theme() has no TextEdit entry, so this control had no focus
	# ring anywhere in the game -- the keyboard could reach it and nothing said
	# so. The ring is the same one every button wears.
	_fb_comment_input.add_theme_stylebox_override("normal", UITheme.button_normal())
	_fb_comment_input.add_theme_stylebox_override("focus", UITheme.focus())
	layout.add_child(_fb_comment_input)

	_fb_url_input = _field(layout, "MENU_FB_URL", UITheme.CAPTION, UITheme.MUTED)
	_fb_url_input.placeholder_text = "https://www.notion.so/webhooks/worker/..."

	# Status Label
	_fb_status_label = Label.new()
	_fb_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text(_fb_status_label, UITheme.LABEL, UITheme.MUTED)
	layout.add_child(_fb_status_label)

	# Buttons. Send is this page's single primary; Back is subordinate and
	# narrower, so the two never read as a pair of equals.
	var btn_layout := HBoxContainer.new()
	btn_layout.add_theme_constant_override("separation", COLUMN_GAP)
	layout.add_child(btn_layout)

	_fb_submit_btn = Button.new()
	_fb_submit_btn.text = tr("MENU_FB_SUBMIT")
	_register_text(_fb_submit_btn, "MENU_FB_SUBMIT")
	_fb_submit_btn.custom_minimum_size.y = SECONDARY_HEIGHT
	_fb_submit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_primary(_fb_submit_btn, UITheme.BODY)
	_fb_submit_btn.pressed.connect(_submit_feedback)
	btn_layout.add_child(_fb_submit_btn)

	var back_btn := Button.new()
	back_btn.text = tr("MENU_BACK")
	_register_text(back_btn, "MENU_BACK")
	back_btn.custom_minimum_size = Vector2(150, SECONDARY_HEIGHT)
	UITheme.apply_button(back_btn, UITheme.LABEL, UITheme.MUTED)
	_wire_button_sfx(back_btn)
	back_btn.pressed.connect(_close_feedback_menu)
	btn_layout.add_child(back_btn)

	for control: Control in [_fb_name_input, _fb_comment_input, _fb_url_input,
			_fb_submit_btn, back_btn]:
		_feedback_focus.append(control)
	_link_ring(_feedback_focus)


## One labelled text field. Returns the LineEdit so the caller can set its
## placeholder; the label above it is registered for retranslation.
func _field(layout: VBoxContainer, key: String, size: int, color: Color) -> LineEdit:
	var label := Label.new()
	label.text = tr(key)
	UITheme.apply_text(label, size, color)
	_register_text(label, key)
	layout.add_child(label)

	var input := LineEdit.new()
	input.focus_mode = Control.FOCUS_ALL
	UITheme.apply_text(input)
	input.add_theme_stylebox_override("normal", UITheme.button_normal())
	input.add_theme_stylebox_override("focus", UITheme.focus())
	layout.add_child(input)
	return input


# --- Page construction ------------------------------------------------------

## A body page: the full height of the frame's body region, contents centred
## vertically, hidden until _show_page() picks it.
##
## The page is a ScrollContainer because the body region is not a fixed size. It
## is 656 logical pixels at 1600x900 and 398 at 1280x720 with `large_text` on
## (SettingsManager sets content_scale_factor 1.12), and a page that overflowed
## would not shrink -- it would draw straight over the bottom rule and the key
## legend, hiding the very row that tells the player how to get out. See the
## height table above the layout constants for which combinations scroll.
## follow_focus is on for the reason SettingsPanel turns it on: tabbing onto a
## control below the fold has to bring it into view.
##
## The inner VBox does the centring, so a page that fits sits exactly where it
## did before the scroller was added.
func _make_page() -> ScrollContainer:
	var page := ScrollContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	page.follow_focus = true
	page.visible = false
	_pages.add_child(page)

	var centre := VBoxContainer.new()
	centre.name = "Centre"
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(centre)
	return page


func _make_column(page: ScrollContainer) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.custom_minimum_size.x = COLUMN_WIDTH
	column.add_theme_constant_override("separation", COLUMN_GAP)
	(page.get_child(0) as VBoxContainer).add_child(column)
	return column


func _gap(column: VBoxContainer, height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)


## The one primary action of a page. Its text is set by the caller, because both
## primaries say something the catalogue cannot say on its own (the start button
## carries a night number, and Resume is a plain key).
func _make_primary(column: VBoxContainer, handler: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(COLUMN_WIDTH, PRIMARY_HEIGHT)
	_style_primary(button, UITheme.SECTION)
	button.pressed.connect(handler)
	_wire_button_sfx(button)
	column.add_child(button)
	return button


## Accent fill + accent hairline: the pair UITheme already spends on "this is the
## live one" (button_pressed(), and SettingsPanel's selected rail tab). Hover and
## focus thicken the hairline instead of changing the fill, so the button never
## flashes and the ring is still the widest border on the page.
##
## Content margins are passed explicitly to every stylebox, so a border that
## grows from BORDER_WIDTH to FOCUS_WIDTH cannot shove the label sideways.
func _style_primary(button: Button, size: int) -> void:
	UITheme.apply_button(button, size)
	button.add_theme_stylebox_override("normal", UITheme.stylebox(
		UITheme.ACCENT_FILL, UITheme.ACCENT, UITheme.BORDER_WIDTH,
		UITheme.RADIUS_MD, UITheme.PAD_X, UITheme.PAD_Y))
	button.add_theme_stylebox_override("hover", UITheme.stylebox(
		UITheme.ACCENT_FILL, UITheme.ACCENT, UITheme.FOCUS_WIDTH,
		UITheme.RADIUS_MD, UITheme.PAD_X, UITheme.PAD_Y))


## Everything that is not the primary: a type step down, a third shorter, MUTED
## instead of ON_SURFACE, and no fill. `color` exists for the one destructive
## action, which is DANGER *in addition to* sitting alone below a rule.
func _make_secondary(column: VBoxContainer, key: String, handler: Callable,
		color: Color = UITheme.MUTED) -> Button:
	var button := Button.new()
	button.text = tr(key)
	_register_text(button, key)
	button.custom_minimum_size = Vector2(COLUMN_WIDTH, SECONDARY_HEIGHT)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UITheme.apply_button(button, UITheme.LABEL, color)
	button.pressed.connect(handler)
	_wire_button_sfx(button)
	column.add_child(button)
	return button


## Arriving by pad or keyboard is the same event as arriving by mouse, so it
## makes the same sound. Without focus_entered the pad player navigates in
## silence while the mouse player gets feedback on every row.
func _wire_button_sfx(button: Button) -> void:
	button.mouse_entered.connect(_move_sfx)
	button.focus_entered.connect(_move_sfx)


## Chain a page's focusables into a ring that WRAPS at both ends.
##
## Godot derives arrow-key neighbours from geometry, which gets the middle of a
## single column right and the two ends wrong: at the bottom of the list Down
## finds nothing and the focus stops dead, which on a pad reads as the menu
## having frozen. Tab is wired too, so the ring is the same in both directions.
## A one-element list links to itself, which is what "the only place to go is
## here" should do.
static func _link_ring(controls: Array[Control]) -> void:
	var count := controls.size()
	if count == 0:
		return
	for i in range(count):
		var control := controls[i]
		var next := controls[(i + 1) % count]
		var previous := controls[(i - 1 + count) % count]
		control.focus_neighbor_bottom = control.get_path_to(next)
		control.focus_neighbor_top = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)
		control.focus_previous = control.get_path_to(previous)


# --- Text -------------------------------------------------------------------

## Remember that `control`'s text is exactly tr(key), so a language switch in the
## settings dialog re-renders the menu underneath it. Controls whose text is
## composed (the start button, the subtitle) are rebuilt by _retranslate()
## instead and are deliberately not registered here.
func _register_text(control: Control, key: String) -> void:
	control.set_meta(&"loc_key", key)
	_localised.append(control)


func _retranslate() -> void:
	for control in _localised:
		if not is_instance_valid(control):
			continue
		control.set("text", tr(String(control.get_meta(&"loc_key", ""))))
	if _subtitle != null:
		_subtitle.text = Loc.fmt("MENU_SUBTITLE_FMT", [tr(SUBTITLE_TEXT)])
	_refresh_start_button()
	_apply_keys()


## The button says what pressing it does, and pressing it now always does the
## same thing: enter the museum. A save past the first night is offered as a
## continuation; everything else, first launch included, is a plain start.
func _refresh_start_button() -> void:
	if _start_button == null:
		return
	var night := _saved_night()
	if night > 1:
		_start_button.text = Loc.fmt("MENU_CONTINUE_NIGHT", [night])
	else:
		_start_button.text = tr("MENU_START")


# --- Footer legend ----------------------------------------------------------

## The frame's key legend, one entry per key that actually does something on the
## page in front of the player.
##
## Nothing here is a lie by construction: the caps are read back out of InputMap
## rather than transcribed, so rebinding "pause" or "confirm" rewrites the
## legend, and the labels are the same catalogue rows the buttons carry.
func _apply_keys() -> void:
	var hints: Array = []
	if _feedback_page != null and _feedback_page.visible:
		_append_key(hints, &"pause", "MENU_BACK")
	elif _in_main_menu:
		# Resume, not Start, once there is a night to come back to -- the same
		# distinction the primary button makes, in a row that cannot carry a
		# number because the frame translates a legend label with a plain tr().
		_append_key(hints, &"confirm",
			"MENU_START" if _saved_night() <= 1 else "MENU_RESUME")
	else:
		_append_key(hints, &"pause", "MENU_RESUME")
	_frame.set_keys(hints)


func _append_key(hints: Array, action: StringName, label_key: String) -> void:
	var cap := _cap(action)
	if cap == "":
		return
	hints.append([cap, label_key])


## The keyboard legend for `action`, straight out of InputMap -- the trick
## SettingsPanel._keyboard_glyph() uses so the Controls page cannot drift from
## the map it documents. Returns "" when the action carries no key at all, and
## _append_key() then omits the row rather than printing an empty cap plate.
func _cap(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event := event as InputEventKey
		if key_event == null:
			continue
		var code: Key = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE \
			else key_event.keycode
		return OS.get_keycode_string(code).to_upper()
	return ""
