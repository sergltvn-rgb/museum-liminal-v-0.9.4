extends Node

## Безопасная оболочка для агентского помощника MCP.
##
## Зачем она есть. Раньше автозагрузка `_mcp_game_helper` указывала прямо на
## `res://addons/godot_ai/runtime/game_helper.gd`. Этот каталог вырезан из экспорта
## (`exclude_filter="addons/godot_ai/*, ..."` в export_presets.cfg), поэтому в собранной
## игре автозагрузка ссылалась на несуществующий ресурс — билд падал бы на старте,
## ещё до первого кадра, и ни одна проверка в редакторе этого не ловит.
##
## Что делает. Автозагрузка теперь указывает на этот файл, который всегда едет в
## сборке. Он подгружает настоящий помощник ТОЛЬКО если тот физически лежит рядом
## (то есть в редакторе и в агентских прогонах), а в экспортной сборке молча ничего
## не делает. Один и тот же `project.godot` годится и для работы, и для выпуска.
##
## Не удалять и не заменять обратно прямой ссылкой на addons/.

const HELPER_PATH := "res://addons/godot_ai/runtime/game_helper.gd"

## Имя узла-ребёнка с настоящим помощником. Полезно в отладке дерева сцены.
const HELPER_NODE_NAME := "GodotAiGameHelper"


func _ready() -> void:
	if not ResourceLoader.exists(HELPER_PATH):
		# Обычный случай для собранной игры: помощника в сборке нет, и это норма.
		return
	var helper_script: Script = load(HELPER_PATH) as Script
	if helper_script == null:
		push_warning("[MCP] помощник найден, но не загрузился как скрипт")
		return
	var helper: Node = Node.new()
	helper.name = HELPER_NODE_NAME
	helper.set_script(helper_script)
	add_child(helper)
