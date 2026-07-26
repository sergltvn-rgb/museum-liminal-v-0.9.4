extends Node
## Central input map with keyboard and gamepad bindings. Actions are created
## at runtime so the project no longer depends on hard-coded key polling.
##
## Gamepad layout — one action per control, with A as the single deliberate
## double: it is the platform-conventional accept button, so it carries both
## jump (during play) and confirm (on the terminal overlays). The two can never
## fire together — GameManager switches the player's controls_enabled off while
## a fail / night-done / win screen is up.
##   Left stick  move_*        Right stick  camera_pan_* / camera_tilt_*
##   A  jump + confirm         B  drop_item
##   X  interact               Y  tablet
##   LB radar_scan             RB flashlight
##   LT cam_prev               RT cam_next
##   L3 sprint                 START pause
##   Free: BACK/SELECT, R3, D-pad.
## The engine keeps its own ui_* actions on A (ui_accept), B (ui_cancel),
## Y (ui_select), the D-pad and the left stick; those are UI-only and are left
## alone on purpose. The D-pad is deliberately left free of game actions: it is
## the only way to drive focus navigation, which the CCTV mini-map now needs.
##
## THAT PARAGRAPH IS AN ACCESSIBILITY CONTRACT, NOT A NOTE (stage 5.2). The
## settings dialog, the main menu and the pause menu are driven entirely by the
## builtin set — ui_up / ui_down / ui_left / ui_right to move the focus,
## ui_accept to activate, ui_cancel to back out, plus "pause" for START. Nothing
## below may claim the D-pad, and nothing below may take A or B away from the
## engine, or the menus stop being operable on a pad. Note there is no builtin
## pad binding for ui_focus_next / ui_focus_prev (Tab is keyboard-only), so a
## screen that expects a pad has to make its own up/down/left/right graph
## complete; game/SettingsPanel.gd `_wire_focus()` is the worked example.
##
## The Controls page of the settings dialog is now GENERATED from this map
## rather than transcribed from it (SettingsPanel.BINDING_ROWS names the actions,
## InputMap.action_get_events supplies the legends), so rebinding anything here
## updates what the player is told. Renaming an action, however, silently empties
## its row — grep BINDING_ROWS before you do.


func _ready() -> void:
	_add_action("move_left", [_key(KEY_A), _joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_add_action("move_right", [_key(KEY_D), _joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_add_action("move_forward", [_key(KEY_W), _joy_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add_action("move_back", [_key(KEY_S), _joy_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add_action("jump", [_key(KEY_SPACE), _joy_button(JOY_BUTTON_A)])
	_add_action("sprint", [_key(KEY_SHIFT), _joy_button(JOY_BUTTON_LEFT_STICK)])
	_add_action("interact", [_key(KEY_E), _joy_button(JOY_BUTTON_X)])
	_add_action("drop_item", [_key(KEY_G), _joy_button(JOY_BUTTON_B)])
	_add_action("tablet", [_key(KEY_TAB), _joy_button(JOY_BUTTON_Y)])
	_add_action("flashlight", [_key(KEY_F), _joy_button(JOY_BUTTON_RIGHT_SHOULDER)])
	# "radar" has no reader anywhere in game/ (only "radar_scan" is queried), so
	# it must not occupy the last free shoulder button.
	_add_action("radar", [_key(KEY_R)])
	# Lidar scan moves off RB: it collided with the flashlight, which made the
	# flashlight untoggleable during void_rift and the scan unreachable on a pad.
	_add_action("radar_scan", [_mouse(MOUSE_BUTTON_LEFT), _joy_button(JOY_BUTTON_LEFT_SHOULDER)])
	_add_action("pause", [_key(KEY_ESCAPE), _joy_button(JOY_BUTTON_START)])
	# Stays on A: Back/Select is a cancel button and no player would look for
	# "accept" there. Sharing A is safe because PlayerController only polls
	# "jump" while controls_enabled is true, and GameManager clears that flag
	# for STATE_FAILED / STATE_NIGHT_DONE / STATE_WIN — the only states where
	# "confirm" does anything besides dismissing the protocol overlay.
	_add_action("confirm", [_key(KEY_ENTER), _joy_button(JOY_BUTTON_A)])
	_add_action("camera_pan_left", [_key(KEY_LEFT), _joy_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_add_action("camera_pan_right", [_key(KEY_RIGHT), _joy_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_add_action("camera_tilt_up", [_key(KEY_UP), _joy_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_add_action("camera_tilt_down", [_key(KEY_DOWN), _joy_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	# CCTV feed cycling. Clicking a mini-map button used to be the only way to
	# change feed, which made the game unfinishable on a pad: from night 2 the
	# incident cannot be resolved until the source is confirmed on a specific
	# camera. Both shoulder buttons are taken (LB radar_scan, RB flashlight), so
	# the feeds sit on the triggers — the only free pair left in that cluster,
	# and the one every player already reaches for to cycle something.
	# Keyboard uses the physical "<" / ">" keys, which nothing else claims.
	_add_action("cam_prev", [_key(KEY_COMMA), _joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_add_action("cam_next", [_key(KEY_PERIOD), _joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])


func _add_action(action: StringName, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.22)
	for event in events:
		if event != null and not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event
