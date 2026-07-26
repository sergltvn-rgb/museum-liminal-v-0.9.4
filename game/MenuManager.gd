extends Node
## Main menu, pause menu, progress display and Notion Worker feedback panel.
##
## Install: add a plain Node to the main scene and attach this script.
## - The game starts paused on the main menu.
## - ESC toggles the pause menu during play.
## - Progress (current night) is written by GameManager to
##   user://museum_save.cfg; the menu only reads it.

const SAVE_PATH := "user://museum_save.cfg"
const TUTORIAL_PROGRESS_PATH := "user://museum_progress.cfg"
const TUTORIAL_SCENE := "res://scenes/TutorialPrologue.tscn"
const SettingsPanelScript := preload("res://game/SettingsPanel.gd")
const TITLE_TEXT := "MENU_TITLE"
const SUBTITLE_TEXT := "MENU_SUBTITLE_SHIFT"

var _layer: CanvasLayer
var _backdrop: ColorRect
var _main_box: VBoxContainer
var _pause_box: VBoxContainer
var _start_button: Button
var _resume_button: Button
var _settings_panel
var _settings_panel_ready := false
var _return_to_pause := false
var _in_main_menu := true

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
		return
	if _feedback_panel != null and _feedback_panel.visible:
		return
	if not event.is_action_pressed("pause") or _in_main_menu:
		return
	get_viewport().set_input_as_handled()
	if get_tree().paused:
		_resume()
	else:
		_open_pause_menu()


# --- Menu flow --------------------------------------------------------------

func _open_main_menu() -> void:
	_in_main_menu = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _tutorial_done():
		_start_button.text = Loc.fmt("MENU_CONTINUE_NIGHT", [_saved_night()])
	else:
		_start_button.text = tr("MENU_NEW_TUTORIAL")
	if _settings_panel != null:
		_settings_panel.visible = false
	if _feedback_panel != null:
		_feedback_panel.visible = false
	# The page itself, not a dim over the world: opaque SURFACE. The feedback
	# panel's 1.44:1 step is measured against exactly this colour.
	_backdrop.color = UITheme.SURFACE
	_layer.visible = true
	_main_box.visible = true
	_pause_box.visible = false
	_start_button.grab_focus()


func _open_pause_menu() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# A modal dim over the running world, so SCRIM rather than SURFACE.
	_backdrop.color = UITheme.SCRIM
	_layer.visible = true
	_main_box.visible = false
	_pause_box.visible = true
	if _settings_panel != null:
		_settings_panel.visible = false
	if _feedback_panel != null:
		_feedback_panel.visible = false
	if _resume_button != null:
		_resume_button.grab_focus()
	_sfx("menu_select")


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


func _start_game() -> void:
	if not _tutorial_done():
		_open_tutorial()
		return
	_in_main_menu = false
	_resume()


func _open_tutorial() -> void:
	_sfx("menu_select")
	get_tree().paused = false
	get_tree().change_scene_to_file(TUTORIAL_SCENE)


## True when the player may start the shift.
## Deliberately done-OR-skipped: TutorialPrologue._write_progress(false) records a
## skip as tutorial/skipped and leaves tutorial/done false on purpose (so a skipped
## replay cannot downgrade an earlier honest completion). Checking "done" alone
## sends anyone who held ESC out of the tutorial straight back into it on every
## press of Start -- an infinite loop. Do not "simplify" this to a single key.
func _tutorial_done() -> bool:
	var config := ConfigFile.new()
	if config.load(TUTORIAL_PROGRESS_PATH) != OK:
		return false
	if bool(config.get_value("tutorial", "done", false)):
		return true
	return bool(config.get_value("tutorial", "skipped", false))


func _reset_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "night", 1)
	config.save(SAVE_PATH)
	# Both keys are cleared explicitly: _tutorial_done() gates on done-OR-skipped,
	# so leaving a stale skipped=true behind would let Reset Progress skip the
	# tutorial. (Today the fresh ConfigFile also overwrites the file wholesale,
	# but that stops being true the moment someone adds a load() here.)
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
	_main_box.visible = false
	_pause_box.visible = false
	_settings_panel.visible = true
	_sfx("menu_select")


func _close_settings() -> void:
	_settings_panel.visible = false
	if _return_to_pause:
		_pause_box.visible = true
	else:
		_main_box.visible = true
	_focus_first(_pause_box if _return_to_pause else _main_box)
	_sfx("menu_select")


func _open_feedback_menu() -> void:
	_main_box.visible = false
	_pause_box.visible = false
	_feedback_panel.visible = true
	_set_status("", UITheme.MUTED)
	if _feedback_manager != null:
		_fb_url_input.text = _feedback_manager.webhook_url
	_fb_name_input.grab_focus()
	_sfx("menu_select")


func _close_feedback_menu() -> void:
	_feedback_panel.visible = false
	if not _in_main_menu:
		_pause_box.visible = true
	else:
		_main_box.visible = true
	_focus_first(_pause_box if not _in_main_menu else _main_box)
	_sfx("menu_select")


## Puts the keyboard back on the first item of whichever menu just reappeared.
## Hiding a Control releases its focus, so after a sub-panel closes nothing is
## focused and the arrow keys have nowhere to start walking from.
func _focus_first(box: VBoxContainer) -> void:
	if box == null:
		return
	for child in box.get_children():
		var button := child as Button
		if button != null and not button.disabled:
			button.grab_focus()
			return


func _submit_feedback() -> void:
	var p_name := _fb_name_input.text.strip_edges()
	var comment := _fb_comment_input.text.strip_edges()
	var url := _fb_url_input.text.strip_edges()
	
	if comment.is_empty():
		_set_status(tr("MENU_FB_ERR_COMMENT"), UITheme.DANGER)
		return

	if url.is_empty():
		_set_status(tr("MENU_FB_ERR_URL"), UITheme.DANGER)
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


func _sfx(sound: String) -> void:
	var am := get_tree().get_first_node_in_group("audio_manager")
	if am != null and am.has_method("play_sfx"):
		am.play_sfx(sound)


# --- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "Menu Layer"
	_layer.layer = 20
	_layer.visible = false
	add_child(_layer)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_backdrop)

	var title := Label.new()
	title.text = tr(TITLE_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_text(title, UITheme.DISPLAY, UITheme.ON_SURFACE)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.16
	title.anchor_bottom = 0.26
	_backdrop.add_child(title)

	var subtitle := Label.new()
	subtitle.text = Loc.fmt("MENU_SUBTITLE_FMT", [tr(SUBTITLE_TEXT)])
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_text(subtitle, UITheme.SECTION, UITheme.MUTED)
	subtitle.anchor_left = 0.0
	subtitle.anchor_right = 1.0
	subtitle.anchor_top = 0.26
	subtitle.anchor_bottom = 0.32
	_backdrop.add_child(subtitle)

	_main_box = _make_box()
	_start_button = _add_button(_main_box, tr("MENU_START"), _start_game)
	_add_button(_main_box, tr("MENU_TUTORIAL"), _open_tutorial)
	_add_button(_main_box, tr("MENU_SETTINGS"), _open_settings)
	_add_button(_main_box, tr("MENU_FEEDBACK"), _open_feedback_menu)
	_add_button(_main_box, tr("MENU_RESET_PROGRESS"), _reset_progress)
	_add_button(_main_box, tr("MENU_QUIT"), _quit)

	_pause_box = _make_box()
	_resume_button = _add_button(_pause_box, tr("MENU_RESUME"), _resume)
	_add_button(_pause_box, tr("MENU_SETTINGS"), _open_settings)
	_add_button(_pause_box, tr("MENU_FEEDBACK"), _open_feedback_menu)
	_add_button(_pause_box, tr("MENU_MAIN_MENU"), _to_main_menu)
	_add_button(_pause_box, tr("MENU_QUIT"), _quit)

	# Settings
	_settings_panel = SettingsPanelScript.new()
	_settings_panel.visible = false
	_backdrop.add_child(_settings_panel)
	# Wire the close handler before setup(): a panel that failed to populate
	# must still answer ESC and its own Back button.
	_settings_panel.closed.connect(_close_settings)
	_prepare_settings_panel()

	# Feedback panel
	_build_feedback_panel()


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
	_feedback_panel = PanelContainer.new()
	_feedback_panel.visible = false
	_feedback_panel.anchor_left = 0.5
	_feedback_panel.anchor_right = 0.5
	_feedback_panel.anchor_top = 0.5
	_feedback_panel.anchor_bottom = 0.5
	_feedback_panel.offset_left = -220.0
	_feedback_panel.offset_right = 220.0
	_feedback_panel.offset_top = -240.0
	_feedback_panel.offset_bottom = 240.0
	_backdrop.add_child(_feedback_panel)

	# Was #14141a at 95% on a near-black backdrop -- 1.10:1, and no border at all,
	# so the form read as text floating in the void. panel_raised() is 1.44:1
	# above SURFACE and carries the BORDER hairline every other panel has.
	UITheme.apply_panel(_feedback_panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	_feedback_panel.add_child(layout)

	var fb_title := Label.new()
	fb_title.text = tr("MENU_FEEDBACK")
	fb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_text(fb_title, UITheme.SECTION)
	layout.add_child(fb_title)

	# Name
	var name_label := Label.new()
	name_label.text = tr("MENU_FB_NAME")
	UITheme.apply_text(name_label, UITheme.LABEL)
	layout.add_child(name_label)

	_fb_name_input = LineEdit.new()
	_fb_name_input.placeholder_text = tr("MENU_FB_NAME_HINT")
	_fb_name_input.focus_mode = Control.FOCUS_ALL
	UITheme.apply_text(_fb_name_input)
	layout.add_child(_fb_name_input)

	# Comment
	var comment_label := Label.new()
	comment_label.text = tr("MENU_FB_COMMENT")
	UITheme.apply_text(comment_label, UITheme.LABEL)
	layout.add_child(comment_label)

	_fb_comment_input = TextEdit.new()
	_fb_comment_input.placeholder_text = tr("MENU_FB_COMMENT_HINT")
	_fb_comment_input.custom_minimum_size = Vector2(0, 120)
	_fb_comment_input.focus_mode = Control.FOCUS_ALL
	UITheme.apply_text(_fb_comment_input)
	layout.add_child(_fb_comment_input)

	# Webhook URL Input
	var url_label := Label.new()
	url_label.text = tr("MENU_FB_URL")
	UITheme.apply_text(url_label, UITheme.CAPTION, UITheme.MUTED)
	layout.add_child(url_label)

	_fb_url_input = LineEdit.new()
	_fb_url_input.placeholder_text = "https://www.notion.so/webhooks/worker/..."
	_fb_url_input.focus_mode = Control.FOCUS_ALL
	UITheme.apply_text(_fb_url_input)
	layout.add_child(_fb_url_input)

	# Status Label
	_fb_status_label = Label.new()
	_fb_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fb_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_text(_fb_status_label, UITheme.LABEL, UITheme.MUTED)
	layout.add_child(_fb_status_label)

	# Buttons
	var btn_layout := HBoxContainer.new()
	btn_layout.add_theme_constant_override("separation", 10)
	layout.add_child(btn_layout)

	_fb_submit_btn = Button.new()
	_fb_submit_btn.text = tr("MENU_FB_SUBMIT")
	UITheme.apply_button(_fb_submit_btn)
	_fb_submit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fb_submit_btn.pressed.connect(_submit_feedback)
	btn_layout.add_child(_fb_submit_btn)

	var back_btn := Button.new()
	back_btn.text = tr("MENU_BACK")
	UITheme.apply_button(back_btn)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(_close_feedback_menu)
	btn_layout.add_child(back_btn)


func _make_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.42
	box.anchor_bottom = 0.42
	box.offset_left = -160.0
	box.offset_right = 160.0
	box.add_theme_constant_override("separation", 14)
	box.visible = false
	_backdrop.add_child(box)
	return box


func _add_button(box: VBoxContainer, text: String,
		handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(320, 44)
	# focusable: the whole menu was FOCUS_NONE, so a keyboard or a gamepad could
	# not reach it at all. apply_button() flips focus back on and installs the
	# ring that makes the current item visible.
	UITheme.apply_button(btn, UITheme.SECTION)
	btn.pressed.connect(handler)
	btn.mouse_entered.connect(func() -> void: _sfx("menu_move"))
	box.add_child(btn)
	return btn
