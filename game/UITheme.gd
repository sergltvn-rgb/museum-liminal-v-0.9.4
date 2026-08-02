class_name UITheme
extends RefCounted
## Design tokens for every piece of UI in the game.
##
## Stage 6 foundation, now the live source. It began as a reply to 151
## `add_theme_*` calls across nine files, each inventing its own font size and
## colour, so the same "panel" was a different grey in five places and the same
## "accent" belonged to three rival families. Round 2 moved every size and
## colour onto the tokens below; round 3 (block 10) added the spacing scale and
## moved the leftover hand-written gaps onto it. What still calls add_theme_*
## outside this file is styleboxes swapped at runtime, built from these tokens.
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
##   SURFACE         #111518   L = 0.00727
##   SURFACE_RAISED  #2a3339   L = 0.03159
##
## The two hard gates:
##   SURFACE_RAISED : SURFACE ..... 1.42 : 1   (gate 1.30, was 1.08)
##   BORDER         : SURFACE ..... 4.87 : 1   (gate 3.00, was 1.61)
## BORDER also clears 3:1 against SURFACE_RAISED (3.42 : 1), so a bordered
## panel reads whether it sits on the page or on another panel -- the gate only
## demanded the first of those, but a border that vanishes on its own fill is
## the same bug one layer up.
##
## Both surfaces are darker than they were, because the references are: 16% of
## every pixel across the twelve reference screens is #181818 and another 12%
## is nearly black. Panels are opaque, and the darkness comes from the fill
## being dark -- not from transparency over the 3D scene.
##
## Every text token, against BOTH backgrounds (gate 4.5 : 1):
##   token           hex        on SURFACE   on SURFACE_RAISED
##   ON_SURFACE      #c6d3db      12.00             8.42
##   MUTED           #8fa3ae       7.00             4.91
##   BEIGE           #c6b994       9.41             6.60
##   ACCENT          #81a88a       6.89             4.84
##   SUCCESS         #81a88a       6.89             4.84
##   WARNING         #d59a42       7.42             5.21
##   DANGER          #e38175       6.67             4.68
##   RIFT            #c7b7d9       9.79             6.87
##
## The palette is the seven canon colours of the MNEMOS design (block 10),
## not a recolour of the old one. Two of them cannot be text and are split
## into a separate fill token each:
##
##   DANGER_FILL     #b54a42   3.52 on SURFACE, 2.47 on SURFACE_RAISED
##   PANEL_EDGE      #435865   2.43 on SURFACE, 1.70 on SURFACE_RAISED
##
## The canon alarm red #b54a42 fails 4.5:1 as text by the same argument the
## old coral did: clearing the gate would need a SURFACE_RAISED darker than
## the 1.4x step above SURFACE allows. So #b54a42 is the *fill* (the hard
## frame and the hatching on the warning screen) and DANGER, a lightened
## tint of it, carries the words. Alarm is never colour alone -- the frame
## and the diagonal hatch must read in greyscale, per reference 09.
##
## PANEL_EDGE is the canon dim blue-grey. It is decorative chrome only:
## dividers, inactive frames, the CCTV camera grid. Anything a player must
## see and operate uses BORDER (#6b8896, 4.87 / 3.42), which clears the
## 3:1 gate for non-text UI on both backgrounds.
##
## Non-text tokens, for the record:
##   ACCENT_DIM      #55705c   3.15 on SURFACE, 2.21 on SURFACE_RAISED
##   BORDER_ACCENT   #81a88a   6.89 on SURFACE, 4.84 on SURFACE_RAISED
## ACCENT_DIM is a fill/border token ONLY. Do not set it as `font_color`;
## use ACCENT.
##
##
## KEYBOARD FOCUS (stage 6.6)
##
## Keyboard navigation is impossible today: every button sets
## `focus_mode = FOCUS_NONE` and no focus stylebox exists anywhere, so even
## after re-enabling focus there would be nothing to see. `focus()` supplies
## the missing ring and `apply_button()` re-enables focus by default.
##
## One OFL face now carries the whole interface and is named further down, in
## the FONTS section: Departure Mono, a pixel face with full Cyrillic. Before
## it the project had no font file at all, so every screen rendered in Godot's
## stock sans -- which is why "it looks like stock Godot" was a literal
## description of the build rather than an impression. The two faces that
## briefly replaced it, JetBrains Mono and Oswald, were themselves modern and
## are gone; hierarchy is now carried by size and case, not by family.

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
# The seven canon colours of the MNEMOS interface, plus the tints the contrast
# gates force. Ratios for all of these are tabulated in the header comment.
#
# RULE OF ONE ACCENT: the base of any screen is carried by SURFACE,
# SURFACE_RAISED, PANEL_EDGE and ON_SURFACE. At most ONE of the three accents
# (ACCENT green, WARNING amber, DANGER red) may appear on screen at a time.
# Green means one thing only -- the system is operating normally. It is not a
# decoration, not a "confirm" colour on unrelated buttons, and not the default
# border. If green is on screen everywhere, it has stopped saying anything.

## Page background. Everything else is measured against this. Canon graphite.
const SURFACE := Color("111518")
## Anything that floats above the page: panels, cards, popups, tooltips.
## 1.42:1 above SURFACE -- the whole point of this file.
const SURFACE_RAISED := Color("2a3339")
## Full-screen dim behind a modal. SURFACE at 88% -- alpha, so no ratio applies.
const SCRIM := Color("111518e0")

## Primary text. Cold, slightly blue -- a phosphor white, not a paper white.
const ON_SURFACE := Color("c6d3db")
## Secondary text: captions, disabled-looking-but-readable, units, hints.
const MUTED := Color("8fa3ae")
## Canon museum beige. The institutional voice: exhibit labels, inventory
## numbers, printed report screens -- the parts of the building that predate
## the terminal. Never for live system state.
const BEIGE := Color("c6b994")

## Canon terminal green. NORMAL OPERATION ONLY: system online, scan complete,
## event resolved. See the rule of one accent above.
const ACCENT := Color("81a88a")
## ACCENT darkened for fills and borders.
## FILL AND BORDER ONLY -- see the header; it misses 4.5:1 as text.
const ACCENT_DIM := Color("55705c")
## Accent at 18% for pressed/selected fills.
const ACCENT_FILL := Color("81a88a2e")

## Failure, alarm, destructive actions -- as TEXT. Lightened from DANGER_FILL.
const DANGER := Color("e38175")
## Canon alarm red. FILL AND BORDER ONLY: warning frames, diagonal hatching.
## Never a font_color -- see the header. Alarm must also read in greyscale.
const DANGER_FILL := Color("b54a42")
## Confirmation, objective complete. Deliberately the same green as ACCENT:
## two rival greens would split the one meaning green is allowed to carry.
const SUCCESS := Color("81a88a")
## Canon amber. Caution, timers running out, degraded stability.
const WARNING := Color("d59a42")
## Canon rift colour, pale violet-white. The only thing on screen the museum
## system was never built to display: anomalous readings, ghosted values,
## the closure-count discrepancy. Use it sparingly or it stops being wrong.
const RIFT := Color("c7b7d9")

## Default hairline for anything the player must see and operate.
## 4.87:1 on SURFACE, 3.42:1 on SURFACE_RAISED -- clears the 3:1 non-text gate.
const BORDER := Color("6b8896")
## Canon dim blue-grey. DECORATIVE CHROME ONLY: dividers, inactive frames,
## the CCTV camera grid. Below 3:1 -- never the edge of an active control.
const PANEL_EDGE := Color("435865")
## Hairline for focused / active / selected chrome.
const BORDER_ACCENT := Color("81a88a")

# --- SHAPE ------------------------------------------------------------------
## Block 10: every radius is zero. A rounded corner is the strongest single
## "modern app" signal there is, and MNEMOS has to read as a 1990s
## institutional system. The three names are kept so no caller has to change.
const RADIUS_SM := 0    ## Chips, tags, small buttons.
const RADIUS_MD := 0    ## Buttons, inputs, cards.
const RADIUS_LG := 0    ## Panels, dialogs.
## 2px rather than a 1px hairline: the game renders at scaling_3d 0.75, and a
## single-pixel border thins out to nothing on the in-world CCTV screens.
const BORDER_WIDTH := 2
const FOCUS_WIDTH := 3
const PAD_X := 12
const PAD_Y := 8

# --- SPACING SCALE ----------------------------------------------------------
# The last thing the migration had no token for. Round 2 collapsed every font
# size and colour onto the tokens above, and the note over build_theme() was
# honest about what it could not finish: the remaining add_theme_* calls were
# "spacing constants (for which there is no token)". This is that token.
#
# Four steps, because the codebase only ever meant four things by a gap: lines
# that belong to one readout, rows inside a block, blocks inside a column, and
# sections that should read as separate. Every literal 2 / 6 / 10 / 14 already
# scattered through the nine UI files is one of those four intents written by
# hand; the values are chosen to match what is on screen today, so migrating a
# call site is a rename and not a redesign.
#
# Insets keep using PAD_X / PAD_Y above -- a margin is a different quantity
# from a gap, and giving them one shared scale is how padding starts drifting
# into spacing.
const GAP_TIGHT := 2     ## Stacked lines that read as one readout.
const GAP_ROW := 6       ## Rows inside a block; label above its value.
const GAP_BLOCK := 10    ## Between blocks in a column. The default.
const GAP_SECTION := 14  ## Between parts that should read as separate.

# --- CRT TREATMENT (stage 6.5) ----------------------------------------------
#
# Strengths for the diegetic scanline layer game/CRTOverlay.gd paints over the
# in-world service screens -- today the CCTV tablet, which is the only screen
# in the game the operator is meant to read as a monitor rather than as UI.
# They live here for the same reason the colours do: one place to tune the look.
#
# THE CEILING IS COMPUTED, NOT TASTE.
#
# A mix-blended darkening multiplies the *sRGB* value, and because the WCAG
# ratio carries a +0.05 flare term, scaling both a glyph and its backing by the
# same factor still costs contrast. So the treatment has a budget, and the
# tablet's mini-map spends it: a CAPTION room label is MUTED text on a SCRIM
# panel pinned to the bottom-right corner, which is where the vignette bites.
#
# Worst label is Wing D's, at roughly UV (0.94, 0.81) on a 1600x900 canvas.
# There `tube` evaluates to 0.557, so it loses 0.443 * CRT_VIGNETTE to the
# vignette, plus a full CRT_SCANLINE in a trough, plus CRT_FLICKER at the top
# of the hum -- 0.27 of its light in total, i.e. every channel scaled by 0.73.
#   MUTED on SCRIM, clean ................ 9.08 : 1
#   MUTED on SCRIM, worst CRT pixel ...... 5.13 : 1   (gate 4.5)
# The budget runs out at about 0.32 of total darkening; these tokens spend
# 0.27. Raising CRT_VIGNETTE past ~0.36, or CRT_SCANLINE past ~0.17, is what
# would break the gate -- so if the look needs to be stronger, take the extra
# out of one of them and put it back into the other, or move the mini-map off
# the corner first.
#
# CRT_GLOW is not in the budget because it adds light rather than removing it.

## Darkening at the bottom of a scanline trough, 0..1.
const CRT_SCANLINE := 0.12
## Scanline pitch in framebuffer pixels. Below 2 the lines alias into a flat
## grey haze on any display that is not showing the canvas 1:1.
const CRT_SCANLINE_PITCH := 3.0
## Pixels per second the scanline phase drifts -- the tube's vertical roll.
const CRT_ROLL_SPEED := 14.0
## Light the simulated tube loses at the very edge of the glass, 0..1.
const CRT_VIGNETTE := 0.30
## Falloff exponent for the vignette. Lower is a wider, softer tube.
const CRT_VIGNETTE_POWER := 0.30
## Phosphor wash laid over the picture, in ACCENT, brightest at the centre.
const CRT_GLOW := 0.05
## Mains hum on the tube's brightness. Deliberately an order below CRT_SCANLINE
## so it reads as breathing rather than as a flash.
const CRT_FLICKER := 0.015


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


## Screen-family panels. These are Theme type variations rather than local
## colours, so a screen can declare what kind of instrument it is without
## rebuilding the palette. Their names are part of the UI contract: scenes and
## runtime-built Controls set only `theme_type_variation`; the shared Theme owns
## the actual surface, edge and spacing.
static func terminal_panel() -> StyleBoxFlat:
	return stylebox(SURFACE, PANEL_EDGE, BORDER_WIDTH, RADIUS_LG,
		PAD_X + 4, PAD_Y + 4)


static func cctv_panel() -> StyleBoxFlat:
	return stylebox(SURFACE, PANEL_EDGE, BORDER_WIDTH, RADIUS_LG,
		PAD_X, PAD_Y)


static func warning_panel(border: Color = WARNING) -> StyleBoxFlat:
	return stylebox(SURFACE_RAISED, border, FOCUS_WIDTH, RADIUS_LG,
		PAD_X + 4, PAD_Y + 4)


static func instrument_panel() -> StyleBoxFlat:
	return stylebox(SURFACE_RAISED, BORDER, BORDER_WIDTH, RADIUS_SM,
		PAD_X, PAD_Y)


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


## Set the gap between a container's children from the spacing scale.
##
## The branching is the same kind Godot forces on apply_text(): a BoxContainer
## calls it `separation`, while GridContainer and the flow containers split it
## into `h_separation` and `v_separation`. Call sites should not have to know
## which of those the container they are holding happens to be.
##
## `cross` overrides the vertical step on the two-axis containers only; the
## default keeps both axes on the same token, which is what a grid of equal
## cells wants.
static func apply_gap(container: Container, amount: int = GAP_BLOCK,
		cross: int = -1) -> void:
	if container == null:
		return
	if container is GridContainer or container is FlowContainer:
		container.add_theme_constant_override("h_separation", amount)
		container.add_theme_constant_override("v_separation",
				amount if cross < 0 else cross)
		return
	container.add_theme_constant_override("separation", amount)


## Set all four margins of a MarginContainer from the padding tokens.
##
## Four hand-written add_theme_constant_override lines per inset is how three
## of the four sides end up correct and the fourth ends up 4px off -- the exact
## shape of the bug this collapses.
static func apply_inset(margin: MarginContainer, x: int = PAD_X,
		y: int = PAD_Y) -> void:
	if margin == null:
		return
	margin.add_theme_constant_override("margin_left", x)
	margin.add_theme_constant_override("margin_right", x)
	margin.add_theme_constant_override("margin_top", y)
	margin.add_theme_constant_override("margin_bottom", y)


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

## --- Fonts ---------------------------------------------------------------
##
## The project shipped with NO font file at all, so every screen rendered in
## Godot's stock sans -- which is why "выглядит как сток Godot" was a literal
## description rather than an impression. Two OFL 1.1 faces now sit in fonts/,
## with their licences beside them:
##
##   DepartureMono.otf  every screen in the game. A monospaced pixel face by
##                      Helena Zhang under the SIL OFL. Block 10 requires a
##                      pixel bitmap font, and a monospaced one also keeps a
##                      counting-down timer from jittering.
##
## Both roles point at the same file deliberately. The previous pairing --
## JetBrains Mono for data, Oswald for signage -- was two modern faces, which
## is a large part of why the UI read as stock engine chrome. MNEMOS is one
## machine, so it speaks with one voice; hierarchy now comes from size, case
## and spacing rather than from a second family.
##
## GLYPH COVERAGE, verified by tools/tmp_font_check.py, which renders every
## required character and compares its bitmap against the font's .notdef box:
## Departure Mono has all 33 Cyrillic capitals, all 33 lowercase, Latin,
## digits, dashes and the arrows.
##
## IT DOES NOT HAVE U+2713 CHECK MARK or U+2717 BALLOT X. The terminal's
## symptom rows must therefore NOT be built from those characters -- use ASCII
## markers ([+] [x] [?] [ ]) or draw the mark, otherwise the row renders as
## tofu boxes in the one place the player has to read carefully.
##
## Candidates already rejected, so they are not re-tested: Pixel Operator
## (CC0, but contains no Cyrillic whatsoever), Pixelify Sans (holes in the
## capitals), Pixellari (proportional, no em/en dash).
const MONO_FONT_PATH := "res://fonts/DepartureMono.otf"
const DISPLAY_FONT_PATH := "res://fonts/DepartureMono.otf"

static var _mono_font: FontFile = null
static var _display_font: FontFile = null


## Monospaced face for anything the operator reads as an instrument.
static func mono_font() -> FontFile:
	if _mono_font == null:
		_mono_font = _load_font(MONO_FONT_PATH)
	return _mono_font


## Condensed face for mastheads and signage. Falls back to the mono face for
## glyphs it lacks, so a missing character degrades to a readable one instead of
## a tofu box.
static func display_font() -> FontFile:
	if _display_font == null:
		_display_font = _load_font(DISPLAY_FONT_PATH)
		if _display_font != null:
			var chain: Array[Font] = []
			var mono := mono_font()
			# ОБЕ РОЛИ СЕЙЧАС УКАЗЫВАЮТ НА ОДИН ФАЙЛ, а load() отдаёт для
			# одного пути ОДИН И ТОТ ЖЕ ресурс. Значит display и mono — это
			# буквально один объект, и запись его себе в fallbacks замыкает
			# цепочку на себя: Godot ловит это при первой же отрисовке текста
			# и печатает "ERROR: Cyclic font fallback". Запасное начертание
			# имеет смысл только когда лица РАЗНЫЕ; сравниваем по объекту, а
			# не по путям, потому что пути могут разойтись, а ресурс совпасть.
			if mono != null and mono != _display_font:
				chain.append(mono)
			_display_font.fallbacks = chain
	return _display_font


## load(), never load_dynamic_font(). The latter builds a FontFile with no
## resource_path, so ResourceSaver has nowhere to point and embeds the entire
## typeface inside whatever references it -- measured: it took
## ui/museum_theme.tres from 10 KB to 437 KB and duplicated both faces into the
## repository. Going through the import pipeline yields a resource with a path,
## which serialises as a one-line ExtResource and is what an export build ships.
static func _load_font(path: String) -> FontFile:
	if not ResourceLoader.exists(path):
		push_warning("UITheme: font missing at %s, falling back to the engine default" % path)
		return null
	var font := load(path) as FontFile
	if font == null:
		push_warning("UITheme: %s did not import as a FontFile" % path)
		return null
	return font


## Build the shared Theme so new controls inherit tokens without any code.
##
## Assigned once at the root of a UI tree (`root.theme = UITheme.build_theme()`)
## or saved to disk and wired to the `gui/theme/custom` project setting -- see
## `save_theme()` and the switch-over recipe above.
static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = BODY

	# Body copy defaults to the mono face: nearly everything the player reads in
	# this game is output from a machine. Headings opt into display_font()
	# explicitly through TerminalType, which owns the institutional voice.
	var body_font := mono_font()
	if body_font != null:
		theme.default_font = body_font
		for type_name in ["Label", "RichTextLabel", "Button", "CheckButton",
				"OptionButton", "LineEdit", "TextEdit"]:
			theme.set_font("font", type_name, body_font)
		theme.set_font("normal_font", "RichTextLabel", body_font)

	theme.set_font_size("font_size", "Label", BODY)
	theme.set_color("font_color", "Label", ON_SURFACE)

	theme.set_font_size("normal_font_size", "RichTextLabel", BODY)
	theme.set_color("default_color", "RichTextLabel", ON_SURFACE)

	theme.set_stylebox("panel", "Panel", panel())
	theme.set_stylebox("panel", "PanelContainer", panel_raised())
	theme.set_stylebox("panel", "PopupPanel", panel_raised())

	# Four semantic families over the common theme. Godot type variations need a
	# base type explicitly; without it an unset item falls through to Control
	# instead of inheriting the built-in Panel/PanelContainer contract.
	for variation: String in ["TerminalPanel", "CCTVPanel", "WarningPanel",
			"InstrumentPanel"]:
		theme.set_type_variation(variation, "Panel")
	theme.set_stylebox("panel", "TerminalPanel", terminal_panel())
	theme.set_stylebox("panel", "CCTVPanel", cctv_panel())
	theme.set_stylebox("panel", "WarningPanel", warning_panel())
	theme.set_stylebox("panel", "InstrumentPanel", instrument_panel())

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
