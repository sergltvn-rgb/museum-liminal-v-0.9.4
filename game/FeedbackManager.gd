extends Node
# Feedback and bug reporting manager for the Notion Worker integration.
# Path: res://game/FeedbackManager.gd

signal request_completed(success: bool, message: String)

var webhook_url: String = ""

func _ready() -> void:
	add_to_group("feedback_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()

func _load_config() -> void:
	var config := ConfigFile.new()
	if config.load("user://notion_config.cfg") == OK:
		webhook_url = config.get_value("notion", "webhook_url", "")

func save_config(url: String) -> void:
	webhook_url = url
	var config := ConfigFile.new()
	config.set_value("notion", "webhook_url", url)
	config.save("user://notion_config.cfg")

func send_feedback(player_name: String, comment: String, version: String = "0.9.4") -> void:
	if webhook_url.is_empty():
		request_completed.emit(false, "URL вебхука не настроен. Укажите его в настройках.")
		return

	var http := HTTPRequest.new()
	add_child(http)
	
	http.request_completed.connect(func(result: int, response_code: int, response_headers: PackedStringArray, body: PackedByteArray):
		_on_request_completed(http, result, response_code, response_headers, body)
	)

	var headers := ["Content-Type: application/json"]
	var data := {
		"playerName": player_name,
		"comment": comment,
		"version": version
	}
	var body_str := JSON.stringify(data)

	var err := http.request(webhook_url, headers, HTTPClient.METHOD_POST, body_str)
	if err != OK:
		request_completed.emit(false, "Ошибка создания HTTP-запроса: " + error_string(err))
		http.queue_free()

func _on_request_completed(http: HTTPRequest, result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS:
		request_completed.emit(false, "Сетевая ошибка при отправке запроса")
		return
	
	# Webhooks in Notion Workers return 202 Accepted (asynchronously processed) or 200 OK
	if response_code == 200 or response_code == 202:
		request_completed.emit(true, "Отзыв успешно отправлен!")
	else:
		var response_text := body.get_string_from_utf8()
		request_completed.emit(false, "Ошибка сервера (код %d): %s" % [response_code, response_text])
