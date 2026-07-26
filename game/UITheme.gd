class_name UITheme
extends RefCounted
## Design tokens for every piece of UI in the game.
##
## Stage 6 foundation. Nothing is shared today: 151 `add_theme_*` calls across
## nine files each invent their own font size and colour, so the same "panel"
## is a different grey in five places and the same "accent" belongs to three
## rival families. This file is the single source those calls migrate onto in
## round 2 -- it defines the values, it does not touch any existing screen.
## Nothing reads it yet, by design: the project-wide switch is a single step at
## the end of the migration, written out above `build_theme()` below.
##
## The shape is deliberately the one game/SettingsPanel.gd already arrived at
## (named colour constants + one StyleBoxFlat factory, `_style()` near line
## 397); this promotes that idea to a shared home rather than replacing it
## with a different one.
##
##
## WHY THE COLOURS ARE THESE COLOURS
##
## The accent family is the CRT green the security tablet already runs on
## (`GREEN := Color(0.2, 0.78, 0.42)` in game/SecurityCameraTablet.gd). It is
## the only accent in the project motivated by the fiction -- the player is
## looking at a night-shift monitor -- so the whole UI adopts it instead of
## SettingsPanel's mint #55d6b3 or the assorted one-off teals. ACCENT is that
## constant unchanged; ACCENT_DIM is literally `GREEN.darkened(0.25)`, the
## value the tablet already draws its row borders with; WARNING is the tablet's
## own flash amber `Color(1.0, 0.62, 0.28)`.
##
##
## CONTRAST -- COMPUTED, NOT EYEBALLED
##
## WCAG 2.1 relative luminance: channels linearised with
## `c/12.92 if c <= 0.04045 else ((c+0.055)/1.055) ** 2.4`, then
## `L = 0.2126*R + 0.7152*G + 0.0722*B`; ratio = `(Lhi+0.05)/(Llo+0.05)`.
##
## The bug being fixed: panels were invisible against the background.
##   SettingsPanel SURFACE #171e27 vs BG #11161d ....... 1.08 : 1
##   SettingsPanel BORDER  #33414f vs #171e27 .......... 1.61 : 1
## A 1.08:1 step is below the threshold of a healthy eye on a good monitor, and
## it is nothing at all on the dim, washed-out panels this game is played on.
##
## Measured luminance of the tokens below:
##   SURFACE         #0a0e12   L = 0.00422
##   SURFACE_RAISED  #25303a   L = 0.02813
##
## The two hard gates:
##   SURFACE_RAISED : SURFACE ..... 1.44 : 1   (gate 1.30, was 1.08)
##   BORDER         : SURFACE ..... 4.58 : 1   (gate 3.00, was 1.61)
## BORDER also clears 3:1 against SURFACE_RAISED (3.18 : 1), so a bordered
## panel reads whether it sits on the page or on another panel -- the gate only
## demanded the first of those, but a border that vanishes on its own fill is
## the same bug one layer up.
##
## Every text token, against BOTH backgrounds (gate 4.5 : 1):
##   token           hex        on SURFACE   on SURFACE_RAISED
##   ON_SURFACE      #edf3f5      17.28            11.99
##   MUTED           #a3b4c0       9.08             6.30
##   ACCENT          #33c76b       8.78             6.09
##   DANGER          #ff7a6b       7.61             5.28
##   SUCCESS         #5fe08d      11.56             8.02
##   WARNING         #ff9e47       9.44             6.55
##
## DANGER is a lightened coral, not the tablet's `Color(0.9, 0.12, 0.1)`
## (#e61f1a, L = 0.1788). That red reaches only 2.93:1 on SURFACE_RAISED as
## text -- 4.22:1 even on SURFACE, the darkest thing in the palette -- and
## cannot be rescued: passing 4.5:1 would need a SURFACE_RAISED of L <= 0.00084,
## while clearing the 1.3x step above SURFACE needs L >= 0.0205. No colour is
## both. It stays valid as a *fill*, which is all the tablet uses it for.
##
## Non-text tokens, for the record:
##   ACCENT_DIM      #269550   5.07 on SURFACE, 3.52 on SURFACE_RAISED
##   BORDER_ACCENT   #33c76b   8.78 on SURFACE, 6.09 on SURFACE_RAISED
## ACCENT_DIM is a fill/border token ONLY. It misses 4.5:1 on SURFACE_RAISED
## and, by the same argument as DANGER above, no legal SURFACE_RAISED would
## let it pass. Do not set it as `font_color`; use ACCENT.
##
##
## KEYBOARD FOCUS (stage 6.6)
##
## Keyboard navigation is impossible today: every button sets
## `focus_mode = FOCUS_NONE` and no focus stylebox exists anywhere, so even
## after re-enabling focus there would be nothing to see. `focus()` supplies
## the missing ring and `apply_button()` re-enables focus by default.
##
## No font resource is shipped, so nothing here names one; the tokens are
## sizes and colours only and ride on Godot's default font.

# --- TYPE SCALE -------------------------------------------------------------
# Six steps, replacing the 17 ad-hoc sizes currently in the codebase. Ratio is
# roughly 1.2-1.4 per step, wide enough that two adjacent steps never read as
# "the same size, slightly wrong".
const CAPTION := 12   ## Timestamps, hints, footnotes.
const LABEL := 14     ## Control labels, list rows, button text in dense UI.
const BODY := 17      ## Default. Paragraphs, dialogue, primary button text.
const SECTION := 21   ## Group headings inside a panel.
const TITLE := 28     ## Panel / screen titles.
const DISPLAY := 48   ## Full-screen moments: title card, death, chapter break.

# --- SEMANTIC COLOURS -------------------------------------------------------
# Twelve names, replacing 23 unrelated surface colours and 3 rival accent
# families. Ratios for all of these are tabulated in the header comment.

## Page background. Everything else is measured against this.
const SURFACE := Color("0a0e12")
## Anything that floats above the page: panels, cards, popups, tooltips.
## 1.44:1 above SURFACE -- the whole point of this file.
const SURFACE_RAISED := Color("25303a")
## Full-screen dim behind a modal. SURFACE at 88% -- alpha, so no ratio applies.
const SCRIM := Color("0a0e12e0")

## Primary text.
const ON_SURFACE := Color("edf3f5")
## Secondary text: captions, disabled-looking-but-readable, units, hints.
const MUTED := Color("a3b4c0")

## The CCTV CRT green: SecurityCameraTablet.GREEN, `Color(0.2, 0.78, 0.42)`.
## Written as hex like the rest of the palette, so the stored floats differ from
## the tablet's by up to 0.4/255 -- the same pixel once rasterised, but NOT
## `is_equal_approx`-equal to the float triple. Compare via `to_html(false)`.
const ACCENT := Color("33c76b")
## SecurityCameraTablet.GREEN.darkened(0.25), the tablet's own row-border green.
## FILL AND BORDER ONLY -- see the header; it misses 4.5:1 on SURFACE_RAISED.
const ACCENT_DIM := Color("269550")
## Accent at 18% for pressed/selected fills.
const ACCENT_FILL := Color("33c76b2e")

## Destructive actions, failure, alarms.
const DANGER := Color("ff7a6b")
## Confirmation, objective complete.
const SUCCESS := Color("5fe08d")
## Caution, timers running out. The tablet's flash amber, `Color(1.0, 0.62, 0.28)`.
const WARNING := Color("ff9e47")

## Default 1px hairline. 4.58:1 on SURFACE, 3.18:1 on SURFACE_RAISED.
const BORDER := Color("6e7d8b")
## Hairline for focused / active / selected chrome.
const BORDER_ACCENT := Color("33c76b")

# --- SHAPE ------------------------------------------------------------------
const RADIUS_SM := 6    ## Chips, tags, small buttons.
const RADIUS_MD := 10   ## Buttons, inputs, cards.
const RADIUS_LG := 14   ## Panels, dialogs.
const BORDER_WIDTH := 1
const FOCUS_WIDTH := 2
const PAD_X := 12
const PAD_Y := 8


# --- STYLEBOX FACTORY -------------------------------------------------------

## The one StyleBoxFlat builder everything else routes through. Same shape as
## SettingsPanel._style(), with the padding promoted to arguments.
static func stylebox(bg: Color, border: Color, width: int, radius: int,
		pad_x: int = PAD_X, pad_y: int = PAD_Y) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = pad_x
	style.content_margin_right = pad_x
	style.content_margin_top = pad_y
	style.content_margin_bottom = pad_y
	return style


## Page-level container: sits directly on the background.
static func panel() -> StyleBoxFlat:
	return stylebox(SURFACE, BORDER, BORDER_WIDTH, RADIUS_LG, PAD_X + 4, PAD_Y + 4)


## Card / dialog / popup: the surface that must not disappear.
static func panel_raised() -> StyleBoxFlat:
	return stylebox(SURFACE_RAISED, BORDER, BORDER_WIDTH, RADIUS_LG, PAD_X + 4, PAD_Y + 4)


## Resting button. Filled with SURFACE so it stays legible whether it is
## dropped on the page or on a raised panel.
static func button_normal() -> StyleBoxFlat:
	return stylebox(SURFACE, BORDER, BORDER_WIDTH, RADIUS_MD)


static func button_hover() -> StyleBoxFlat:
	return stylebox(SURFACE_RAISED, BORDER_ACCENT, BORDER_WIDTH, RADIUS_MD)


static func button_pressed() -> StyleBoxFlat:
	return stylebox(ACCENT_FILL, ACCENT, BORDER_WIDTH, RADIUS_MD)


## Disabled: same geometry, drained. Pair with MUTED text at 40% via
## `apply_text`, which sets font_disabled_color for you.
static func button_disabled() -> StyleBoxFlat:
	return stylebox(Color(SURFACE, 0.6), Color(BORDER, 0.35), BORDER_WIDTH, RADIUS_MD)


## Keyboard focus ring (stage 6.6). Draws only the border and expands outward,
## so the ring frames the control instead of covering its own border. Godot
## paints the `focus` stylebox on top of the state stylebox, which is why
## draw_center must be off -- otherwise focusing a button repaints its fill.
static func focus() -> StyleBoxFlat:
	var style := stylebox(Color.TRANSPARENT, ACCENT, FOCUS_WIDTH, RADIUS_MD)
	style.draw_center = false
	style.set_expand_margin_all(FOCUS_WIDTH)
	return style


# --- APPLY HELPERS ----------------------------------------------------------

## Set a type-scale step and a colour on any Control in one call.
##
## This is the helper round 2 leans on: each of the 151 scattered
## `add_theme_font_size_override` / `add_theme_color_override` pairs collapses
## into one line. The branching exists because Godot does not agree with itself
## on theme item names -- RichTextLabel wants `normal_font_size` and
## `default_color`, LineEdit wants a placeholder colour, BaseButton wants five
## colours for its five states, everything else wants `font_size`/`font_color`.
static func apply_text(control: Control, size: int = BODY, color: Color = ON_SURFACE) -> void:
	if control == null:
		return
	if control is RichTextLabel:
		for item: String in ["normal_font_size", "bold_font_size", "italics_font_size",
				"bold_italics_font_size", "mono_font_size"]:
			control.add_theme_font_size_override(item, size)
		control.add_theme_color_override("default_color", color)
		return
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", color)
	if control is LineEdit:
		control.add_theme_color_override("font_placeholder_color", MUTED)
		control.add_theme_color_override("caret_color", ACCENT)
	elif control is BaseButton:
		control.add_theme_color_override("font_hover_color", ON_SURFACE)
		control.add_theme_color_override("font_pressed_color", ACCENT)
		control.add_theme_color_override("font_focus_color", ON_SURFACE)
		control.add_theme_color_override("font_disabled_color", Color(MUTED, 0.4))


## Full button dressing: text, all four state styleboxes, and the focus ring.
## `focusable` defaults to true -- passing false is how you keep a button out
## of the tab order deliberately, rather than by forgetting, which is how all
## of them ended up FOCUS_NONE in the first place.
static func apply_button(button: Button, size: int = BODY,
		color: Color = ON_SURFACE, focusable: bool = true) -> void:
	if button == null:
		return
	apply_text(button, size, color)
	button.add_theme_stylebox_override("normal", button_normal())
	button.add_theme_stylebox_override("hover", button_hover())
	button.add_theme_stylebox_override("pressed", button_pressed())
	button.add_theme_stylebox_override("disabled", button_disabled())
	button.add_theme_stylebox_override("focus", focus())
	button.focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE


## Dress a Panel or PanelContainer. `raised` picks the surface that separates.
static func apply_panel(control: Control, raised: bool = true) -> void:
	if control == null:
		return
	control.add_theme_stylebox_override("panel", panel_raised() if raised else panel())


# --- THEME RESOURCE ---------------------------------------------------------
#
# THE SWITCH-OVER IS DONE. All three steps have landed:
#
#   1. The nine UI files are on apply_text/apply_button/apply_panel. Every
#      `add_theme_font_size_override` outside this file is gone; the
#      `add_theme_*` calls that remain are spacing constants (for which there
#      is no token) and runtime-swapped styleboxes built from these tokens.
#   2. `save_theme()` has been run and res://ui/museum_theme.tres is committed.
#   3. project.godot carries:
#          [gui]
#          theme/custom="res://ui/museum_theme.tres"
#          theme/default_font_size=17
#
# Why the order mattered, kept for whoever regenerates this: `theme/custom`
# takes a path, so pointing it at a .tres that does not exist logs a load
# failure on every launch; and `theme/default_font_size` on its own would have
# lifted only the Controls with no override, leaving the un-migrated screens on
# their old sizes -- half a restyle.
#
# The project theme cannot fight the migrated screens: Godot resolves a theme
# item from the control's own overrides first, then any Theme on an ancestor,
# and only then the project default. Every Control built in game/ either goes
# through the apply_* helpers or carries an explicit override, so this resource
# is what NEW controls -- and Godot's own built-in sub-controls, e.g. a
# ScrollContainer's bar or a LineEdit inside a popup -- inherit.
#
# REGENERATE after changing any token above: run `UITheme.save_theme()` once
# (headless `--script` on a SceneTree, or the remote console) and re-import.
# Nothing reads the tokens at runtime for a themed control, so a stale .tres
# silently keeps the old palette on anything that has no override.
#
# This recipe lives here and not in project.godot because Godot rewrites that
# file whenever any setting changes and discards every ";" comment when it does.

## Build the shared Theme so new controls inherit tokens without any code.
##
## Assigned once at the root of a UI tree (`root.theme = UITheme.build_theme()`)
## or saved to disk and wired to the `gui/theme/custom` project setting -- see
## `save_theme()` and the switch-over recipe above.
static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = BODY

	theme.set_font_size("font_size", "Label", BODY)
	theme.set_color("font_color", "Label", ON_SURFACE)

	theme.set_font_size("normal_font_size", "RichTextLabel", BODY)
	theme.set_color("default_color", "RichTextLabel", ON_SURFACE)

	theme.set_stylebox("panel", "Panel", panel())
	theme.set_stylebox("panel", "PanelContainer", panel_raised())
	theme.set_stylebox("panel", "PopupPanel", panel_raised())

	# Separators are the one hairline nothing overrides: SettingsPanel's dialog
	# divider (its `separation` constant sets the gap, not the line) was drawing
	# in Godot's stock separator grey while BORDER sat unused two pixels away --
	# two greys doing the same job, which is the bug this file exists to kill.
	for separator: String in ["HSeparator", "VSeparator"]:
		var line := StyleBoxLine.new()
		line.color = BORDER
		line.thickness = BORDER_WIDTH
		line.vertical = separator == "VSeparator"
		theme.set_stylebox("separator", separator, line)

	theme.set_font_size("font_size", "LineEdit", BODY)
	theme.set_color("font_color", "LineEdit", ON_SURFACE)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_color("caret_color", "LineEdit", ACCENT)
	theme.set_stylebox("normal", "LineEdit", button_normal())
	theme.set_stylebox("focus", "LineEdit", focus())

	# Godot resolves theme items by exact type name -- CheckBox does NOT inherit
	# Button's entries -- so every BaseButton subclass in use is listed.
	#
	# The five styleboxes are built ONCE and shared across all five type names.
	# Calling the factories inside the loop produced 25 byte-identical
	# StyleBoxFlat sub-resources in the saved .tres (and 25 objects at runtime)
	# for five distinct looks. Sharing is safe because nothing mutates a
	# stylebox it got from the theme -- the two callers that need a variant
	# (SecurityCameraTablet's chip focus ring, SettingsPanel's rail) call the
	# factories directly and get their own instance.
	var btn_normal := button_normal()
	var btn_hover := button_hover()
	var btn_pressed := button_pressed()
	var btn_disabled := button_disabled()
	var btn_focus := focus()
	for type_name: String in ["Button", "CheckBox", "CheckButton", "OptionButton", "MenuButton"]:
		theme.set_font_size("font_size", type_name, BODY)
		theme.set_color("font_color", type_name, ON_SURFACE)
		theme.set_color("font_hover_color", type_name, ON_SURFACE)
		theme.set_color("font_pressed_color", type_name, ACCENT)
		theme.set_color("font_focus_color", type_name, ON_SURFACE)
		theme.set_color("font_disabled_color", type_name, Color(MUTED, 0.4))
		theme.set_stylebox("normal", type_name, btn_normal)
		theme.set_stylebox("hover", type_name, btn_hover)
		theme.set_stylebox("pressed", type_name, btn_pressed)
		theme.set_stylebox("disabled", type_name, btn_disabled)
		theme.set_stylebox("focus", type_name, btn_focus)

	return theme


## Write the theme to disk so `gui/theme/custom` can point at it. Run once from
## a tool script or the remote console; the result is a plain .tres and does not
## need regenerating unless the tokens above change.
static func save_theme(path: String = "res://ui/museum_theme.tres") -> Error:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var made := DirAccess.make_dir_recursive_absolute(dir)
		if made != OK:
			return made
	return ResourceSaver.save(build_theme(), path)
