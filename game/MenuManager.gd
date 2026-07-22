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
const TITLE_TEXT := "ПЕРВЫЙ МУЗЕЙ"
const SUBTITLE_TEXT := "ночная смена"

var _layer: CanvasLayer
var _backdrop: ColorRect
var _main_box: VBoxContainer
var _pause_box: VBoxContainer
var _start_button: Button
var _settings_panel
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
	_start_button.text = "Начать смену — Ночь %d" % _saved_night()
	if _settings_panel != null:
		_settings_panel.visible = false
	if _feedback_panel != null:
		_feedback_panel.visible = false
	_backdrop.color = Color(0.02, 0.02, 0.03, 1.0)
	_layer.visible = true
	_main_box.visible = true
	_pause_box.visible = false


func _open_pause_menu() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_backdrop.color = Color(0.01, 0.01, 0.02, 0.72)
	_layer.visible = true
	_main_box.visible = false
	_pause_box.visible = true
	if _settings_panel != null:
		_settings_panel.visible = false
	if _feedback_panel != null:
		_feedback_panel.visible = false
	_sfx("menu_select")


func _resume() -> void:
	_layer.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_sfx("menu_select")


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


func _tutorial_done() -> bool:
	var config := ConfigFile.new()
	if config.load(TUTORIAL_PROGRESS_PATH) != OK:
		return false
	return bool(config.get_value("tutorial", "done", false))


func _reset_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "night", 1)
	config.save(SAVE_PATH)
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
	_sfx("menu_select")


func _open_feedback_menu() -> void:
	_main_box.visible = false
	_pause_box.visible = false
	_feedback_panel.visible = true
	_fb_status_label.text = ""
	if _feedback_manager != null:
		_fb_url_input.text = _feedback_manager.webhook_url
	_sfx("menu_select")


func _close_feedback_menu() -> void:
	_feedback_panel.visible = false
	if not _in_main_menu:
		_pause_box.visible = true
	else:
		_main_box.visible = true
	_sfx("menu_select")


func _submit_feedback() -> void:
	var p_name := _fb_name_input.text.strip_edges()
	var comment := _fb_comment_input.text.strip_edges()
	var url := _fb_url_input.text.strip_edges()
	
	if comment.is_empty():
		_fb_status_label.text = "Введите текст отзыва!"
		_fb_status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		return
		
	if url.is_empty():
		_fb_status_label.text = "Пожалуйста, введите URL вебхука!"
		_fb_status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		return
		
	_fb_status_label.text = "Отправка..."
	_fb_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_fb_submit_btn.disabled = true
	
	if _feedback_manager != null:
		_feedback_manager.save_config(url)
		_feedback_manager.send_feedback(p_name, comment)


func _on_feedback_completed(success: bool, message: String) -> void:
	_fb_submit_btn.disabled = false
	_fb_status_label.text = message
	if success:
		_fb_status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		_fb_comment_input.text = ""
	else:
		_fb_status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


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
	title.text = TITLE_TEXT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.anchor_top = 0.16
	title.anchor_bottom = 0.26
	_backdrop.add_child(title)

	var subtitle := Label.new()
	subtitle.text = SUBTITLE_TEXT
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	subtitle.anchor_left = 0.0
	subtitle.anchor_right = 1.0
	subtitle.anchor_top = 0.26
	subtitle.anchor_bottom = 0.32
	_backdrop.add_child(subtitle)

	_main_box = _make_box()
	_start_button = _add_button(_main_box, "Начать смену", _start_game)
	_add_button(_main_box, "Обучение", _open_tutorial)
	_add_button(_main_box, "Настройки", _open_settings)
	_add_button(_main_box, "Обратная связь (Notion)", _open_feedback_menu)
	_add_button(_main_box, "Сбросить прогресс", _reset_progress)
	_add_button(_main_box, "Выход", _quit)

	_pause_box = _make_box()
	_add_button(_pause_box, "Продолжить", _resume)
	_add_button(_pause_box, "Настройки", _open_settings)
	_add_button(_pause_box, "Обратная связь (Notion)", _open_feedback_menu)
	_add_button(_pause_box, "Главное меню", _to_main_menu)
	_add_button(_pause_box, "Выход", _quit)

	# Settings
	_settings_panel = SettingsPanelScript.new()
	_settings_panel.visible = false
	_backdrop.add_child(_settings_panel)
	var settings := _settings()
	if settings == null:
		push_error("MenuManager: SettingsManager is missing")
		return
	_settings_panel.setup(settings)
	_settings_panel.closed.connect(_close_settings)

	# Feedback panel
	_build_feedback_panel()


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

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.set_content_margin_all(20)
	_feedback_panel.add_theme_stylebox_override("panel", style)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	_feedback_panel.add_child(layout)

	var fb_title := Label.new()
	fb_title.text = "Обратная связь (Notion)"
	fb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fb_title.add_theme_font_size_override("font_size", 22)
	layout.add_child(fb_title)

	# Name
	var name_label := Label.new()
	name_label.text = "Ваше имя:"
	name_label.add_theme_font_size_override("font_size", 14)
	layout.add_child(name_label)

	_fb_name_input = LineEdit.new()
	_fb_name_input.placeholder_text = "Игрок"
	_fb_name_input.focus_mode = Control.FOCUS_ALL
	layout.add_child(_fb_name_input)

	# Comment
	var comment_label := Label.new()
	comment_label.text = "Отзыв / Описание бага:"
	comment_label.add_theme_font_size_override("font_size", 14)
	layout.add_child(comment_label)

	_fb_comment_input = TextEdit.new()
	_fb_comment_input.placeholder_text = "Опишите ваши впечатления или найденную ошибку..."
	_fb_comment_input.custom_minimum_size = Vector2(0, 120)
	_fb_comment_input.focus_mode = Control.FOCUS_ALL
	layout.add_child(_fb_comment_input)

	# Webhook URL Input
	var url_label := Label.new()
	url_label.text = "URL вебхука Notion Worker:"
	url_label.add_theme_font_size_override("font_size", 12)
	url_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	layout.add_child(url_label)

	_fb_url_input = LineEdit.new()
	_fb_url_input.placeholder_text = "https://www.notion.so/webhooks/worker/..."
	_fb_url_input.focus_mode = Control.FOCUS_ALL
	layout.add_child(_fb_url_input)

	# Status Label
	_fb_status_label = Label.new()
	_fb_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fb_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fb_status_label.add_theme_font_size_override("font_size", 14)
	layout.add_child(_fb_status_label)

	# Buttons
	var btn_layout := HBoxContainer.new()
	btn_layout.add_theme_constant_override("separation", 10)
	layout.add_child(btn_layout)

	_fb_submit_btn = Button.new()
	_fb_submit_btn.text = "Отправить"
	_fb_submit_btn.focus_mode = Control.FOCUS_NONE
	_fb_submit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fb_submit_btn.pressed.connect(_submit_feedback)
	btn_layout.add_child(_fb_submit_btn)

	var back_btn := Button.new()
	back_btn.text = "Назад"
	back_btn.focus_mode = Control.FOCUS_NONE
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
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(320, 44)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(handler)
	btn.mouse_entered.connect(func() -> void: _sfx("menu_move"))
	box.add_child(btn)
	return btn
