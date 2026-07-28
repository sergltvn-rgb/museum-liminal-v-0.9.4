class_name InventoryBar
extends CanvasLayer
## The operator's belt: four cells in a row under the crosshair.
##
## GameManager owns the belt itself -- the ids, which slot is in the hands, what
## a pickup and a drop do (see its BELT block). This file owns nothing but the
## picture of it and has exactly two entry points, set_belt() and
## set_suspended(). It never reads the night, the player or the equipment table,
## which is why it can be built headless and why nothing here can contradict the
## state the night loop keeps.
##
##
## WHERE IT SITS ON THE LAYER SCALE
##
## 150 -- inside the 100-199 live-shift band tabulated above
## GameManager._build_hud(): above the compass (110), below the task block
## (199). The belt is furniture the shift draws, not a screen the player raises,
## so everything that takes the game away sits over it: the CCTV tablet (200),
## the protocol page (210), the proximity alert (320), fail / win (420), the
## trial frame (510), the catch (590) and the pause menu (610).
##
##
## THE ACTIVE CELL IS NOT MARKED BY COLOUR
##
## A filled bullet against a hollow one carries the reading in SHAPE; the digit
## turning ACCENT and the border doubling to FOCUS_WIDTH are the second and
## third channel. The same rule TaskBlock follows -- nothing in this game says
## anything with hue alone, because a deuteranope and a washed-out panel are the
## same problem twice.
##
## Cells are opaque SURFACE_RAISED, so UITheme's measured ratios hold verbatim
## rather than landing on whatever 3D happens to be behind them:
##   ON_SURFACE on SURFACE_RAISED .... 11.99 : 1  (device name, filled cell)
##   MUTED      on SURFACE_RAISED ....  6.30 : 1  (slot digit, empty caption)
##   ACCENT     on SURFACE_RAISED ....  6.09 : 1  (active digit)
## Gate is 4.5 : 1.

## Cells drawn. MUST match GameManager.BELT_SLOTS -- set_belt() is told how many
## names there are and pads or trims to this, so a mismatch is a silent cell
## rather than a crash, but it is still a mismatch.
const SLOTS := 4
const BELT_LAYER := 150
const CELL_SIZE := Vector2(138, 50)
const CELL_GAP := 8
## Pixels of clearance under the row. The block's own bottom edge is higher, so
## the two never meet.
const MARGIN_BOTTOM := 26
const ACTIVE_MARK := "\u25cf"
const IDLE_MARK := "\u25cb"

var _row: HBoxContainer = null
var _cells: Array[PanelContainer] = []
var _marks: Array[Label] = []
var _names: Array[Label] = []


func _ready() -> void:
	layer = BELT_LAYER
	add_to_group("inventory_bar")
	_build()


func _build() -> void:
	var root := Control.new()
	root.name = "Belt Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_row = HBoxContainer.new()
	_row.name = "Belt Row"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", CELL_GAP)
	root.add_child(_row)
	var width := CELL_SIZE.x * float(SLOTS) + float(CELL_GAP) * float(SLOTS - 1)
	_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_row.offset_left = -width * 0.5
	_row.offset_right = width * 0.5
	_row.offset_top = -(CELL_SIZE.y + float(MARGIN_BOTTOM))
	_row.offset_bottom = -float(MARGIN_BOTTOM)
	for index in range(SLOTS):
		_build_cell(index)
	set_belt([], 0)


func _build_cell(index: int) -> void:
	var cell := PanelContainer.new()
	cell.name = "Belt Cell %d" % (index + 1)
	cell.custom_minimum_size = CELL_SIZE
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(cell)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	cell.add_child(column)
	# One label, not a bullet plus a digit: the mark and the slot number are read
	# as one token ("the third one, and it is the one in my hands").
	var mark := Label.new()
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(mark)
	var device := Label.new()
	device.mouse_filter = Control.MOUSE_FILTER_IGNORE
	device.clip_text = true
	device.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(device)
	_cells.append(cell)
	_marks.append(mark)
	_names.append(device)


## Paint the belt. `names` holds one already-translated device name per slot,
## empty string for an empty slot; `active` is the slot in the operator's hands.
##
## Called only when something has actually changed (GameManager._sync_belt()),
## not per frame: this repaints every label and rebuilds two styleboxes.
func set_belt(names: Array, active: int) -> void:
	for index in range(_cells.size()):
		var label := ""
		if index < names.size():
			label = str(names[index])
		var filled := label != ""
		var is_active := index == active
		_cells[index].add_theme_stylebox_override("panel", _cell_style(is_active))
		var mark := _marks[index]
		mark.text = "%s %d" % [ACTIVE_MARK if is_active else IDLE_MARK, index + 1]
		UITheme.apply_text(mark, UITheme.CAPTION,
			UITheme.ACCENT if is_active else UITheme.MUTED)
		var device := _names[index]
		# Resolved here rather than cached, so a language switch from the pause
		# menu lands on the next repaint.
		device.text = label if filled else tr("HUD_BELT_EMPTY")
		UITheme.apply_text(device, UITheme.LABEL,
			UITheme.ON_SURFACE if filled else UITheme.MUTED)


## Stand the row down for anything that takes the game away from the player.
## The same call TaskBlock takes, driven from the same place
## (GameManager._sync_hud_visibility) so the two can never disagree.
func set_suspended(value: bool) -> void:
	visible = not value


func _cell_style(active: bool) -> StyleBoxFlat:
	return UITheme.stylebox(UITheme.SURFACE_RAISED,
		UITheme.ACCENT if active else UITheme.BORDER,
		UITheme.FOCUS_WIDTH if active else UITheme.BORDER_WIDTH,
		UITheme.RADIUS_MD, 10, 6)
