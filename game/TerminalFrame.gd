class_name TerminalFrame
extends Control
## The chrome every full-screen surface wears: one screen of the Night
## Containment Service terminal.
##
## Stage 9.1. The previous UI pass was a restyle that moved nothing, and the
## verdict on it was "редизайна не заметил". This is the layout change. Every
## full-screen surface -- menu, settings, protocol, fail, night-done, prologue --
## stops being its own free-floating arrangement of labels and becomes a page
## rendered by the same device: masthead and live status on top, a body region in
## the middle, a key legend along the bottom, the whole thing behind the tube.
##
##     var frame := TerminalFrame.new()
##     layer.add_child(frame)
##     frame.set_title("MENU_TITLE")
##     frame.set_status(2, 3.0 * 3600.0, TERM_CORE_UNSTABLE_KEY, TerminalFrame.CORE_UNSTABLE)
##     frame.set_keys([["E", "TUT_STEP_INTERACT"], ["TAB", "TEACH_HINT_TABLET"]])
##     frame.body_column().add_child(my_content)
##
## Everything player-visible is a KEY. Nothing in this file renders a literal
## sentence; the only two catalogue rows it names itself are HUD_PROTO_HEADER
## (the masthead, which is exactly "ПЕРВЫЙ МУЗЕЙ · СЛУЖБА НОЧНОГО СДЕРЖИВАНИЯ")
## and HUD_NIGHT ("НОЧЬ %d"), both already in localization/game.csv. Every other
## string arrives as a key from the caller, so this file adds no rows to a
## catalogue it does not own -- see THE STRINGS THIS FILE DOES NOT OWN below for
## the four rows the wiring phase should add and where to feed them in.
##
##
## THE INTERFACE IS THE SECURITY SYSTEM, SO IT DEGRADES
##
## The horror hook is not decoration bolted on top: the frame carries a
## corruption level and a signal-lost state, and the game drives them.
##
##     frame.set_corruption(0.45)          # sustained: how bad the night is
##     frame.pulse_corruption(0.5, 1.2)    # transient: the Curator is close
##     frame.set_signal_lost(true, TERM_SIGNAL_LOST_KEY)   # see the table below
##
## `corruption` is 0..1 and composes with `pulse_corruption`, which adds a
## decaying spike on top without disturbing the sustained level -- so a proximity
## system can stab the UI while a night-progress system holds the floor, and
## neither has to know about the other. What the effective level buys:
##
##   MURK           a flat SURFACE wash over the whole page, MURK_MAX at c=1.
##   PALETTE        text drifts dimmer and the accent family DIMS, ACCENT ->
##                  ACCENT_DIM; the rules and borders walk BORDER -> DANGER.
##                  Amber is not on this ramp -- it belongs to the stability
##                  readout alone, and a rotting page is not the same fact as
##                  an unstable core.
##   RULES BREAK    the hairlines above the body and below it lose segments,
##                  RULE_MAX_GAPS of them at c=1. Shape, not colour.
##   INTEGRITY      the status cluster's segmented meter and its percentage fall
##                  with c. Digits, not colour.
##   DROPPED LINES  BAND_MAX horizontal slabs of missing picture, re-rolled at
##                  GLITCH_HZ.
##   SPECKLE        SPECK_MAX one-cell dropouts and phosphor hits, likewise.
##   CHARACTER ROT  registered labels have up to GLITCH_MAX_RATIO of their
##                  characters replaced from GLITCH_ALPHABET, re-rolled at
##                  GLITCH_HZ. The title and the masthead are registered by
##                  default; add_glitch_target() opts a body label in.
##
## Two things never rot, on purpose. The FOOTER LEGEND is exempt from banding and
## from character rot, because it is how the player leaves the screen and a
## terminal's key legend is silkscreen, not signal. The STATUS READOUTS (night,
## clock) are exempt from character rot because they are right-aligned and a
## proportional font would make every re-roll shove the cluster sideways -- the
## numbers stay honest and the words rot around them, which reads better anyway.
##
## `set_signal_lost(true, key)` is the terminal end state: the body is replaced by
## a torn-picture panel carrying the caller's message on an opaque plate, the
## night and clock readouts drop to an em dash, and integrity reads 0%.
##
## WIRED, AND WHERE FROM. game/GameManager.gd drives both terms. The sustained
## floor is _night_corruption(): the blackout, CORRUPT_PER_NIGHT for every night
## survived, and up to CORRUPT_TIMER_SPAN as a containment window closes -- a
## failed run pins it at 1.0 and a finished one at 0.0. The spike is the Curator:
## _sync_terminals() reads the distance every frame and calls pulse_corruption()
## inside CURATOR_PULSE_RANGE, hardest when it is closest, rate-limited by
## CURATOR_PULSE_INTERVAL. Only the page on screen is pushed; a hidden one is
## brought up to date on the way in.
##
## set_signal_lost() is deliberately still unwired. It replaces the body of the
## page with a torn picture carrying one message, which on the fail page would
## bury FAIL_RETRY -- the only line telling the player how to leave -- and on the
## protocol page would bury the device name the page exists to deliver. It wants
## a surface of its own to land on, and there is not one yet.
##
##
## TYPOGRAPHY -- THE CHROME IS SET, NOT JUST COLOURED
##
## Every label this file builds goes through game/TerminalType.gd, in
## _apply_type(). Before that it went through UITheme only, which owns the six
## sizes and the colour tokens and deliberately says nothing about letterforms --
## so the terminal's masthead was set exactly like the body copy of a menu, and
## the whole page read as default Godot at four different sizes.
##
##   masthead ....... TerminalType.apply_masthead() + institutional(). CAPTION 12
##                    at TRACK_MASTHEAD is +1 px on every glyph, +45 px across
##                    the institution line: stencilled, not whispered. 0.12 em is
##                    also the letter-spacing WCAG 2.1 SC 1.4.12 lets a reader
##                    impose, so a header BUILT at it cannot break when they do.
##   title .......... apply_heading(), +2 px per glyph at TITLE 28. Case is left
##                    to the catalogue: uppercase costs +18% width in English
##                    against +9% in Russian, and the title shares its row with
##                    the status cluster, which is not a row to overrun.
##   status chips ... apply_readout() -- tabular, lining figures -- and the two
##                    that change while you watch them are pinned with
##                    reserve_numeric(). See THE CLUSTER USED TO WALK below.
##   core chip ...... apply_label(). It is a status word, not a number.
##   legend ......... apply_label() on the descriptions; apply_readout() on the
##                    key caps, so a numeric cap ("1", "5") sits on the same
##                    digit grid as the readouts above it.
##   signal lost .... apply_heading() + institutional(). The one sentence on a
##                    dead screen is stencilled like the masthead.
##
## THE CLUSTER USED TO WALK. The integrity percentage is re-rendered at
## GLITCH_HZ, and "100%" / "98%" / "9%" are three different widths in a
## proportional font. Its chip therefore resized twelve times a second, and
## because the cluster is an HBoxContainer with ALIGNMENT_END, every resize shoved
## the night and clock chips sideways -- a status bar that jitters whenever the
## night gets worse. Same shape of bug on the clock, which alternates between
## "23:00" and NO_READING. reserve_numeric() pins each field at the width of the
## widest string it can hold ("100%", "88:88") and right-aligns it, so the last
## digit is nailed down and only the leading digits come and go.
##
## APPLIED ONCE, AT CONSTRUCTION. Letterforms do not change twelve times a
## second; _render() still touches colours and text only. The one thing that
## re-runs is _apply_type() on NOTIFICATION_TRANSLATION_CHANGED, because a locale
## may resolve a different font and every measurement here is derived from the
## font the control actually has.
##
## WHAT THIS IS NOT. It is still Open Sans SemiBold, the face compiled into the
## engine binary -- the project ships zero font files. Tracking, case, leading and
## numeric alignment change how the type is SET; they cannot give it a different
## voice, and they cannot give this file a real bold, a slashed zero or a box rule
## (see TerminalType's THE HONEST LIMIT, which is an asset request).
##
##
## ACCESSIBILITY -- THE DEGRADATION HAS A STATIC FORM
##
## SettingsManager.reduced_flashes does not switch the horror off; it changes how
## it is spoken. With the option ON and c > 0 the frame still shows MURK, the
## dimmer PALETTE, the broken RULES and the falling INTEGRITY readout -- and
## drops DROPPED LINES, SPECKLE and CHARACTER ROT outright, which are the three
## time-varying ones. What is left is time-invariant: with reduced_flashes on and
## no pulse running, this node calls set_process(false) and literally cannot
## animate. The band and speckle seeds are never advanced, so even a forced
## redraw paints the same picture.
##
## The same switch is honoured by the CRTOverlay underneath (its own header
## explains how), so the tube stops rolling too.
##
## pulse_corruption() is by definition a flash. With reduced_flashes on it is not
## animated: the level steps up once, holds for the full duration, and steps back
## down once. Two repaints, no ramp. The information survives; the strobe does not.
##
## Meaning is never carried by colour alone. The core-state chip pairs its colour
## with the caller's translated state text and with a heavier border at
## CORE_CRITICAL. Signal integrity is a number of lit segments and a percentage
## before it is a colour. The rules say "broken" by having gaps in them.
##
## Nothing this file builds is focusable -- the legend is silkscreen, not a row
## of buttons -- so there is no focus ring to draw here. Anything focusable the
## caller puts in `body` should come from UITheme.apply_button(), which brings its
## own ring.
##
##
## CONTRAST -- COMPUTED, NOT EYEBALLED
##
## WCAG 2.1: channels linearised with `c/12.92 if c <= 0.04045 else
## ((c+0.055)/1.055) ** 2.4`, `L = 0.2126R + 0.7152G + 0.0722B`, ratio
## `(Lhi+0.05)/(Llo+0.05)`. The backdrop is an opaque UITheme.SURFACE, so every
## ratio below is against L = 0.00422.
##
## A darkening laid over the page multiplies the *sRGB* value of the glyph and of
## its backing alike, and because the ratio carries a +0.05 flare term that still
## costs contrast. Three layers darken: the CRT vignette, the CRT scanline trough
## plus hum, and this file's own MURK. The worst-lit text on the page is the
## masthead and the legend, which sit at roughly UV (0.030, 0.055) and (0.030,
## 0.945) -- symmetric under the vignette, so one number covers both. `k` below is
## what is left of a channel there.
##
##   state                          k        primary  secondary  accent  danger
##   clean, motion   (CRT 0.35)     0.882     13.38     7.18      6.94    6.05
##   clean, reduced  (CRT 0.35)     0.929     14.88     7.91      7.65    6.65
##   c=1,  motion    (CRT 0.50)     0.792      7.86     5.13      6.11    5.01
##   c=1,  reduced   (CRT 0.50)     0.859      9.18     5.91      7.09    5.77
##   c=1,  no CRT    (quality 0)    0.960     11.40     7.22      8.73    7.05
##   c=1,  body centre, motion      0.892      9.88     6.33      7.61    6.18
##
## Worst text ratio anywhere in any state: 5.01 : 1, against a gate of 4.5.
## The chrome ramp (BORDER -> DANGER, gate 3:1 as a non-text token) bottoms out at
## 3.76 : 1 in the clean state and *rises* to 5.01 : 1 at c=1, because DANGER is
## lighter than BORDER -- corruption never makes a rule harder to see.
##
## Where the headroom went, so it can be spent deliberately later:
##   * CRT intensity is ramped 0.35 -> 0.50, not left at the tablet's 1.0. At 1.0
##     the corner darkening is 0.341 and c=1 secondary text lands at 3.9 : 1 --
##     a fail. The tablet can afford 1.0 because its worst text is a mini-map
##     label it can move; a full page of chrome cannot move.
##   * MURK_MAX is 0.04. It is a real wash over everything, so it is spent on
##     every glyph on the page; 0.10 would drag secondary text to 4.4 : 1.
##   * The backdrop is opaque and there is no scrim variant. UITheme.SCRIM over a
##     bright frame resolves to #272b2e, and c=1 secondary text on that is
##     4.16 : 1. A terminal with a translucent screen is also the wrong fiction.
##
## Two effects are deliberately outside the budget, on the same reasoning that
## lets SecurityCameraTablet fire an 0.85 white burst on a feed change:
##   * DROPPED LINES darken a slab by BAND_ALPHA (0.55), far past the budget, but
##     each slab lives for one GLITCH_HZ tick (83 ms), never lands on the footer
##     legend, and is not drawn at all under reduced_flashes.
##   * SPECKLE cells are SPECK_SIZE px. At SPECK_MAX on a 1600x900 page they cover
##     0.14% of it, which is below the resolution of a contrast measurement; they
##     are the reason MURK carries the wash instead.
## Neither is ever the only thing saying "degraded": MURK, the palette, the broken
## rules and the integrity readout all say it too, and all four survive
## reduced_flashes.
##
##
## THE STRINGS THIS FILE DOES NOT OWN
##
## localization/game.csv belongs to another agent this round, so the frame asks
## for these four rows by parameter instead of naming them. Until they exist the
## affected element simply does not render, and the layout is unchanged.
##
##   key                    en                     ru                  fed in via
##   TERM_SIGNAL_LOST       SIGNAL LOST            СИГНАЛ ПОТЕРЯН      set_signal_lost(true, KEY)
##   TERM_CORE_NOMINAL      CORE: NOMINAL          ЯДРО: НОРМА         set_core_state(KEY, CORE_NOMINAL)
##   TERM_CORE_UNSTABLE     CORE: UNSTABLE         ЯДРО: НЕСТАБИЛЬНО   set_core_state(KEY, CORE_UNSTABLE)
##   TERM_CORE_CRITICAL     CORE: CRITICAL         ЯДРО: КРИТИЧНО      set_core_state(KEY, CORE_CRITICAL)

# --- STATUS ------------------------------------------------------------------
# Core condition. Drives the chip's colour AND its border weight, and is paired
# with the caller's own translated state text, so the reading never rests on hue.
const CORE_NOMINAL := 0
const CORE_UNSTABLE := 1
const CORE_CRITICAL := 2
## The core is not reporting at all. Also what a signal-lost frame shows.
const CORE_OFFLINE := 3

## Stand-in for a readout that has no value: no night set, no clock set, or the
## feed is gone. An em dash, not a blank, so the slot still reads as a slot.
const NO_READING := "—"

# --- LAYOUT ------------------------------------------------------------------
## Outer bezel. Also what keeps the masthead and the legend out of the corner
## where the tube vignette bites hardest -- see the contrast table above.
const BEZEL := 44
const MASTHEAD_GAP := 4
const SECTION_GAP := 16
const RULE_HEIGHT := 3
const CHIP_GAP := 8
const CHIP_PAD_X := 8
const CHIP_PAD_Y := 3
const HINT_GAP := 22
const CAP_GAP := 8
const CAP_MIN_WIDTH := 34
const BODY_PAD := 8

# --- STATUS METER ------------------------------------------------------------
const METER_SEGMENTS := 8
const METER_SEGMENT_WIDTH := 5.0
const METER_SEGMENT_GAP := 2.0
const METER_HEIGHT := 11.0

# --- CRT ---------------------------------------------------------------------
# Intensity handed to CRTOverlay, ramped by corruption. Not the tablet's 1.0:
# this is a page of text rather than a video feed, and 1.0 costs 0.341 of the
# light at the masthead, which fails the gate at c=1. See the contrast table.
const CRT_INTENSITY_CLEAN := 0.35
const CRT_INTENSITY_WORST := 0.50
## Don't churn CRTOverlay.refresh() for sub-perceptual changes during a pulse.
const CRT_INTENSITY_EPSILON := 0.01

# --- DEGRADATION -------------------------------------------------------------
## Flat SURFACE wash at c=1. Inside the contrast budget; see the header.
const MURK_MAX := 0.04
## Re-roll rate for every time-varying effect. 12 Hz reads as a failing signal;
## per-frame is a strobe and is also the one thing a contrast argument cannot
## defend.
const GLITCH_HZ := 12.0
## Ceiling on how much of a string may be replaced at once. A title nobody can
## read is a bug, not a mood.
const GLITCH_MAX_RATIO := 0.25
## Replacement glyphs. Deliberately symbols only: they carry no case and no
## script, so a Cyrillic string rots the same way a Latin one does.
##
## AND THE LIST IS NOT TRUSTED ON ITS WORD. _rot_pool() filters it through
## TerminalType.has_glyphs() against the face that will really draw it, and drops
## anything that face lacks -- because a codepoint a font does not carry is drawn
## as .notdef, and a masthead full of identical empty boxes reads as a broken
## build rather than as a failing signal.
##
## That guard is not hypothetical. "▓▒░" are the densest, most-reached-for end of
## this alphabet; JetBrains Mono and Oswald both carry them, and Open Sans
## SemiBold -- the face compiled into the engine binary, which is what any
## control that does NOT resolve ui/museum_theme.tres falls back to -- carries
## none of the three. Which face a given label ends up with is a property of the
## theme chain, not of this file, so this file checks instead of assuming.
const GLITCH_ALPHABET := "▓▒░#%&@=+*/\\|<>~^:;!?$§"
## Horizontal slabs of missing picture at c=1, and how they are painted.
const BAND_MAX := 7
const BAND_ALPHA := 0.55
const BAND_MIN_HEIGHT := 1.0
const BAND_MAX_HEIGHT := 3.0
## One-cell dropouts and phosphor hits at c=1.
const SPECK_MAX := 220
const SPECK_SIZE := 3.0
const SPECK_DARK_ALPHA := 0.5
const SPECK_LIGHT_ALPHA := 0.35
## Gaps eaten out of the two hairlines at c=1, and how wide each one is.
const RULE_MAX_GAPS := 7
const RULE_GAP_WIDTH := 14.0
## Slabs across the signal-lost panel. Denser than BAND_MAX because that panel is
## the picture being lost, and its message sits on an opaque plate above them.
const LOST_BANDS := 26

## Corrupted end of the text ramp. UITheme.MUTED drifted dimmer but still
## 5.13 : 1 at the worst-lit pixel of the worst state.
const TEXT_DIM := Color("99a6b1")
## How far primary text is allowed to fall towards MUTED at c=1. Not all the way:
## the whole point of a primary token is that it stays the brightest thing.
const PRIMARY_DRIFT := 0.55

var _corruption := 0.0
var _pulse_amount := 0.0
var _pulse_left := 0.0
var _pulse_span := 0.0
var _signal_lost := false
var _reduced := false
var _crt_enabled := true
var _crt_applied := -1.0

var _night := -1
var _shift_seconds := -1.0
var _core_key := ""
var _core_level := CORE_NOMINAL
var _institution_key := "HUD_PROTO_HEADER"
var _title_key := ""
var _lost_key := ""
var _hints: Array = []

## Where a caller's content goes. A MarginContainer, so a single child is
## stretched to the whole region; body_column() is there for the common case.
var body: MarginContainer
var _column: VBoxContainer
var _masthead: Label
var _title: Label
var _status: HBoxContainer
var _night_chip: Label
var _clock_chip: Label
var _core_chip: Label
var _core_chip_frame: PanelContainer
var _core_style: StyleBoxFlat
var _meter: Control
var _meter_value: Label
var _top_rule: Control
var _bottom_rule: Control
var _footer: HBoxContainer
var _noise: Control
var _lost_panel: Control
var _lost_bands: Control
var _lost_label: Label
var _crt: CRTOverlay
var _settings: Node = null
## Labels whose text is allowed to rot: instance id -> the key they render.
##
## Keyed by id and not by the Label itself. A caller may free a body label it
## opted in, and a freed Object is a Variant that cannot be cast (`as Label`
## raises "Trying to cast a freed object" before any is_instance_valid() guard
## gets a look in) and cannot be relied on to still match its own dictionary
## entry. An int always casts, always matches, and instance_from_id() answers
## null for the ones that have gone.
var _glitch_targets: Dictionary[int, String] = {}
## Floor plans handed out by add_floor_plan(), by instance id. Kept so _render()
## can repaint them: they are drawn, not laid out, so neither the corruption ramp
## nor a language change reaches them through the label refresh.
var _plan_ids: Array[int] = []
## Report captions: instance id -> catalogue key. Kept so a locale change can
## re-resolve them from _apply_type(); these labels are built by the caller's
## page rather than by _render(), so nothing else would ever retranslate them.
## Keyed by id for the reason _glitch_targets is -- a caller may free its page.
var _report_captions: Dictionary[int, String] = {}

var _noise_seed := 1
var _since_tick := 0.0
var _rng := RandomNumberGenerator.new()
## GLITCH_ALPHABET with anything the resolved font cannot draw taken out. Built
## on first rot and cleared when the locale (and therefore possibly the font)
## changes; "" means "not built yet", which is why _rot_pool() never caches an
## empty result.
var _glitch_pool := ""


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The terminal is the screen, not a window over the world: it swallows the
	# clicks that land on its chrome. Whatever the caller puts in `body` keeps its
	# own filter and stays interactive.
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_build()


func _ready() -> void:
	refresh()


# --- CONSTRUCTION ------------------------------------------------------------

func _build() -> void:
	var backdrop := Panel.new()
	backdrop.name = "Backdrop"
	backdrop.theme_type_variation = &"TerminalPanel"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var bezel := MarginContainer.new()
	bezel.name = "Bezel"
	bezel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		bezel.add_theme_constant_override(side, BEZEL)
	add_child(bezel)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.add_theme_constant_override("separation", SECTION_GAP)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bezel.add_child(_column)

	_column.add_child(_build_header())

	_top_rule = _build_rule("Top Rule")
	_column.add_child(_top_rule)

	_column.add_child(_build_body_slot())

	_bottom_rule = _build_rule("Bottom Rule")
	_column.add_child(_bottom_rule)

	_footer = HBoxContainer.new()
	_footer.name = "Legend"
	_footer.add_theme_constant_override("separation", HINT_GAP)
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_footer)

	# Above the page and below the tube: the corruption is happening to the
	# picture the terminal is drawing, so it has to cover the page -- but the
	# glass is still in front of all of it.
	_noise = Control.new()
	_noise.name = "Signal Noise"
	_noise.set_anchors_preset(Control.PRESET_FULL_RECT)
	_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_noise.draw.connect(_draw_noise)
	_noise.resized.connect(_noise.queue_redraw)
	add_child(_noise)

	# LAST child, for the reason CRTOverlay's own header gives: everything the
	# screen draws is seen through the glass, including the dropped lines.
	_crt = CRTOverlay.new()
	_crt.name = "Crt Glass"
	add_child(_crt)

	_apply_type()


## Hand every label this file owns to game/TerminalType.gd. See the TYPOGRAPHY
## block at the top for what each treatment is and why.
##
## Called once from _build() and again from NOTIFICATION_TRANSLATION_CHANGED --
## not from _render(), which runs at GLITCH_HZ. Fonts, font sizes, colours and
## constants are four different theme item families, so the colour work _render()
## does on every tick cannot undo any of this, and this cannot undo that.
##
## The footer legend is dressed in _build_hint() instead, because set_keys()
## rebuilds it from scratch.
func _apply_type() -> void:
	TerminalType.apply_masthead(_masthead, UITheme.CAPTION, UITheme.MUTED)
	TerminalType.apply_heading(_title, UITheme.TITLE, UITheme.ON_SURFACE)
	TerminalType.apply_readout(_night_chip, UITheme.LABEL, UITheme.ON_SURFACE)
	TerminalType.apply_label(_core_chip, UITheme.LABEL, UITheme.ON_SURFACE)
	TerminalType.apply_heading(_lost_label, UITheme.SECTION, UITheme.ON_SURFACE)
	_lost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The two fields that change while the player is looking at them. Templates,
	# not current values: "88:88" is every 24 h clock reading, "100%" is the
	# widest integrity the meter can report. Any digit does -- they all have the
	# same advance -- but the separators do not, so the shape is written out.
	TerminalType.reserve_numeric(_clock_chip, "88:88", UITheme.LABEL)
	TerminalType.reserve_numeric(_meter_value, "100%", UITheme.LABEL)
	_refresh_report_captions()
	# A locale change can resolve a different font, and the rot pool is a property
	# of the font, not of the string.
	_glitch_pool = ""


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", MASTHEAD_GAP)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(left)

	_masthead = Label.new()
	_masthead.name = "Institution"
	UITheme.apply_text(_masthead, UITheme.CAPTION, UITheme.MUTED)
	left.add_child(_masthead)

	_title = Label.new()
	_title.name = "Title"
	UITheme.apply_text(_title, UITheme.TITLE, UITheme.ON_SURFACE)
	left.add_child(_title)

	# Both are left-aligned, so replacing characters cannot shove anything else
	# around. The right-hand cluster is not registered -- see the header.
	_glitch_targets[_masthead.get_instance_id()] = ""
	_glitch_targets[_title.get_instance_id()] = ""

	_status = HBoxContainer.new()
	_status.name = "Status"
	_status.alignment = BoxContainer.ALIGNMENT_END
	_status.add_theme_constant_override("separation", CHIP_GAP)
	_status.size_flags_vertical = Control.SIZE_SHRINK_END
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_status)

	_night_chip = _add_chip("Night", _chip_style())
	_clock_chip = _add_chip("Clock", _chip_style())
	_core_style = _chip_style()
	_core_chip = _add_chip("Core", _core_style)
	_core_chip_frame = _core_chip.get_parent() as PanelContainer
	_status.add_child(_build_meter())
	return header


## The chip look: a hairline outline on the terminal's own glass. SURFACE rather
## than SURFACE_RAISED, so every glyph on this page is measured against one
## background and the contrast table at the top of the file stays one table.
func _chip_style() -> StyleBoxFlat:
	return UITheme.stylebox(UITheme.SURFACE, UITheme.BORDER, UITheme.BORDER_WIDTH,
		UITheme.RADIUS_SM, CHIP_PAD_X, CHIP_PAD_Y)


## One bordered readout. Returns the Label inside it; the PanelContainer around
## it is the Label's parent, which is what the core chip needs to restyle.
func _add_chip(chip_name: String, style: StyleBoxFlat) -> Label:
	var frame := PanelContainer.new()
	frame.name = chip_name
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.name = "Value"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text(label, UITheme.LABEL, UITheme.ON_SURFACE)
	frame.add_child(label)
	_status.add_child(frame)
	return label


## Signal integrity: a segment bar and a percentage. Two non-colour readings of
## the same number, which is what keeps the corruption legible to a player who
## cannot use the hue -- and what carries it at all under reduced_flashes.
func _build_meter() -> Control:
	var frame := PanelContainer.new()
	frame.name = "Integrity"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _chip_style())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CAP_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(row)

	_meter = Control.new()
	_meter.name = "Bar"
	_meter.custom_minimum_size = Vector2(
		METER_SEGMENTS * (METER_SEGMENT_WIDTH + METER_SEGMENT_GAP) - METER_SEGMENT_GAP,
		METER_HEIGHT)
	_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.draw.connect(_draw_meter)
	_meter.resized.connect(_meter.queue_redraw)
	row.add_child(_meter)

	_meter_value = Label.new()
	_meter_value.name = "Percent"
	_meter_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text(_meter_value, UITheme.LABEL, UITheme.ON_SURFACE)
	row.add_child(_meter_value)
	return frame


func _build_body_slot() -> Control:
	var slot := MarginContainer.new()
	slot.name = "Body Slot"
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	body = MarginContainer.new()
	body.name = "Body"
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		body.add_theme_constant_override(side, BODY_PAD)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(body)

	_lost_panel = _build_lost_panel()
	slot.add_child(_lost_panel)
	return slot


## What replaces the body when the feed is gone. The message sits on an opaque
## plate so the torn picture behind it can be as violent as it likes without
## touching the contrast of the one sentence the player has to read.
func _build_lost_panel() -> Control:
	var panel := Control.new()
	panel.name = "Signal Lost"
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_lost_bands = Control.new()
	_lost_bands.name = "Tear"
	_lost_bands.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lost_bands.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lost_bands.draw.connect(_draw_lost_bands)
	_lost_bands.resized.connect(_lost_bands.queue_redraw)
	panel.add_child(_lost_bands)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(centre)

	var plate := PanelContainer.new()
	plate.name = "Plate"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", UITheme.stylebox(
		UITheme.SURFACE, UITheme.DANGER, UITheme.FOCUS_WIDTH,
		UITheme.RADIUS_LG, UITheme.PAD_X + 12, UITheme.PAD_Y + 8))
	centre.add_child(plate)

	_lost_label = Label.new()
	_lost_label.name = "Message"
	_lost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text(_lost_label, UITheme.SECTION, UITheme.ON_SURFACE)
	plate.add_child(_lost_label)
	return panel


func _build_rule(rule_name: String) -> Control:
	var rule := Control.new()
	rule.name = rule_name
	rule.custom_minimum_size = Vector2(0, RULE_HEIGHT)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.draw.connect(_draw_rule.bind(rule))
	rule.resized.connect(rule.queue_redraw)
	return rule


# --- PUBLIC API: CONTENT -----------------------------------------------------

## Convenience for the common case: a column inside `body`, created once.
func body_column() -> VBoxContainer:
	for child in body.get_children():
		if child is VBoxContainer:
			return child
	var column := VBoxContainer.new()
	column.name = "Body Column"
	column.add_theme_constant_override("separation", SECTION_GAP)
	body.add_child(column)
	return column


# --- REPORT BLOCK ------------------------------------------------------------
#
# The body composition reference 01 asks for: a report the museum system printed
# rather than a stack of centred sentences. Three parts, and every page that
# reports on an incident builds itself out of them, so no screen invents its own
# grid again.
#
#   FIELDS      caption on the left at a fixed column, value on the right. The
#               caption width is fixed and the value is a readout, so a value
#               that changes while the player watches cannot shove the column.
#   STABILITY   a segmented bar plus a percentage. Two non-colour readings of
#               one number, for the reason the integrity meter has both.
#   SYMPTOMS    one marker plus one observation per row.
#
# THE MARKERS ARE ASCII ON PURPOSE. Departure Mono carries no U+2713 CHECK MARK
# and no U+2717 BALLOT X (verified with tools/tmp_font_check.py against the
# face's .notdef box), so a tick would render as a tofu box in the one place on
# the page the player has to read carefully.
const MARK_PRESENT := "[+]"
const MARK_ABSENT := "[x]"
const MARK_UNKNOWN := "[?]"
const MARK_PENDING := "[ ]"

## Fixed caption column, in pixels. Sized for the longest field caption in
## either locale at LABEL -- Russian "СТАБИЛЬНОСТЬ" is the worst case, 12
## glyphs on Departure Mono's fixed advance. It is a constant and not a
## measurement because the whole point of the column is that it does not move
## when a value inside the row changes.
const FIELD_CAPTION_WIDTH := 168
const FIELD_GAP := 12
const ROW_GAP := 6
const MARK_WIDTH := 34

const STABILITY_SEGMENTS := 20
const STABILITY_SEGMENT_GAP := 2.0
const STABILITY_HEIGHT := 14.0
## Above this the system is operating normally and the bar may be green. Below
## STABILITY_ALARM it is an alarm. Between them: caution. Green means one thing
## in this UI, so the bar earns it rather than defaulting to it.
const STABILITY_OK := 0.6
const STABILITY_ALARM := 0.3


## One "CAPTION      value" row. Returns the value Label; the caller writes to
## its `text` and nothing else.
func add_report_field(column: VBoxContainer, caption_key: String) -> Label:
	var row := HBoxContainer.new()
	row.name = caption_key
	row.add_theme_constant_override("separation", FIELD_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)

	var caption := Label.new()
	caption.name = "Caption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.custom_minimum_size = Vector2(FIELD_CAPTION_WIDTH, 0)
	TerminalType.apply_label(caption, UITheme.LABEL, UITheme.MUTED)
	caption.text = tr(caption_key)
	_report_captions[caption.get_instance_id()] = caption_key
	row.add_child(caption)

	var value := Label.new()
	value.name = "Value"
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TerminalType.apply_readout(value, UITheme.LABEL, UITheme.ON_SURFACE)
	row.add_child(value)
	return value


## A section caption with a rule under it: "ПРИЗНАКИ", "РЕКОМЕНДУЕМЫЙ ПРОТОКОЛ".
## The rule is the frame's own _build_rule(), so it breaks up with corruption
## exactly like the two rules around the body do.
func add_report_section(column: VBoxContainer, caption_key: String) -> Label:
	var caption := Label.new()
	caption.name = caption_key
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TerminalType.apply_masthead(caption, UITheme.CAPTION, UITheme.MUTED)
	caption.text = tr(caption_key)
	_report_captions[caption.get_instance_id()] = caption_key
	column.add_child(caption)
	column.add_child(_build_rule("%s Rule" % caption_key))
	return caption


## One symptom row: an ASCII marker in a fixed column, then the observation.
## `mark` is one of the MARK_* constants; `text` arrives already translated,
## because the observations belong to the incident catalogue, not to this file.
func add_report_symptom(column: VBoxContainer, mark: String, text: String) -> Label:
	var row := HBoxContainer.new()
	row.name = "Symptom"
	row.add_theme_constant_override("separation", ROW_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)

	var dim := mark == MARK_ABSENT or mark == MARK_PENDING
	var marker := Label.new()
	marker.name = "Mark"
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.custom_minimum_size = Vector2(MARK_WIDTH, 0)
	TerminalType.apply_readout(marker, UITheme.LABEL,
		UITheme.MUTED if dim else UITheme.ON_SURFACE)
	marker.text = mark
	row.add_child(marker)

	var body_label := Label.new()
	body_label.name = "Text"
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	TerminalType.apply_label(body_label, UITheme.LABEL,
		UITheme.MUTED if mark == MARK_ABSENT else UITheme.ON_SURFACE)
	body_label.text = text
	row.add_child(body_label)
	return body_label


## The stability readout: a segmented bar and a percentage on one row, behind the
## same caption column as the fields above it. Returns the bar Control, which is
## what set_stability() takes.
func add_stability_bar(column: VBoxContainer, caption_key: String) -> Control:
	var row := HBoxContainer.new()
	row.name = "Stability"
	row.add_theme_constant_override("separation", FIELD_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)

	var caption := Label.new()
	caption.name = "Caption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.custom_minimum_size = Vector2(FIELD_CAPTION_WIDTH, 0)
	TerminalType.apply_label(caption, UITheme.LABEL, UITheme.MUTED)
	caption.text = tr(caption_key)
	_report_captions[caption.get_instance_id()] = caption_key
	row.add_child(caption)

	var bar := Control.new()
	bar.name = "Bar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, STABILITY_HEIGHT)
	bar.set_meta("value", 1.0)
	bar.draw.connect(_draw_stability.bind(bar))
	bar.resized.connect(bar.queue_redraw)
	row.add_child(bar)

	var percent := Label.new()
	percent.name = "Percent"
	percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TerminalType.apply_readout(percent, UITheme.LABEL, UITheme.ON_SURFACE)
	# Pinned at its widest reading, for the reason the integrity chip is pinned:
	# this number changes while the player is looking at it, and an unpinned
	# field would resize the row every time it did.
	TerminalType.reserve_numeric(percent, "100%", UITheme.LABEL)
	percent.text = "100%"
	row.add_child(percent)
	# The Label is reached by id rather than held as a reference: a caller may
	# free the page this row lives on, and a freed Object cannot be cast.
	bar.set_meta("percent", percent.get_instance_id())
	return bar


## Drive a bar built by add_stability_bar(). `value` is 0..1.
func set_stability(bar: Control, value: float) -> void:
	if bar == null or not is_instance_valid(bar):
		return
	var level := clampf(value, 0.0, 1.0)
	bar.set_meta("value", level)
	var percent := instance_from_id(int(bar.get_meta("percent", 0))) as Label
	if percent != null:
		percent.text = "%d%%" % int(round(level * 100.0))
		# Never colour alone: the digits and the count of lit segments both fall
		# with the reading, and the colour only agrees with them.
		percent.add_theme_color_override("font_color", _stability_color(level))
	bar.queue_redraw()


## Green is not the default here -- it is the statement "operating normally".
func _stability_color(level: float) -> Color:
	if level >= STABILITY_OK:
		return UITheme.ACCENT
	if level >= STABILITY_ALARM:
		return UITheme.WARNING
	return UITheme.DANGER


func _draw_stability(bar: Control) -> void:
	var level := float(bar.get_meta("value", 1.0))
	var width := bar.size.x
	if width <= 0.0:
		return
	var step := (width + STABILITY_SEGMENT_GAP) / float(STABILITY_SEGMENTS)
	var seg_width := maxf(1.0, step - STABILITY_SEGMENT_GAP)
	var lit := int(round(level * float(STABILITY_SEGMENTS)))
	var on_color := _stability_color(level)
	for index in STABILITY_SEGMENTS:
		var rect := Rect2(float(index) * step, 0.0, seg_width, bar.size.y)
		if index < lit:
			bar.draw_rect(rect, on_color, true)
		else:
			# An unlit segment is still drawn: the empty cells are what make the
			# reading countable at a glance instead of a bare stripe.
			bar.draw_rect(rect, UITheme.PANEL_EDGE, false, 1.0)


# --- FLOOR PLAN --------------------------------------------------------------
#
# The sixth block of reference 01. The report answers what happened, how bad it
# is and what to carry. The plan answers WHERE, which is the one question the
# page had no way of putting.
#
# THE ROOM TABLE IS NEVER COPIED IN HERE, and this file does not go looking for
# it either. SecurityCameraTablet.ROOMS owns the eleven rectangles and
# game/test_map_verification.gd pins them to the geometry FirstMuseumMap
# actually builds; game/Compass.gd reads that same table out of the shipping
# script at runtime rather than keeping a second copy. This file is chrome: it
# draws whatever rectangles the caller hands it and knows nothing about the
# museum. One table, three renderers -- a plan that has quietly drifted from the
# building is worse than no plan, because the player trusts it.
#
# IT ROTS WITH THE PAGE. The block sits in the body column, under _noise, so
# murk, dropped lines and speckle already cross it; its own ink walks the same
# ramp as everything else -- chrome_color for the walls, secondary_color for the
# sealed wings, primary_color for the names. It never spends an accent: the
# incident is called out with a bracketed name, a lighter cell and a cross, so
# the mark still reads with the accent held elsewhere on the page (RULE OF ONE
# ACCENT) and for a player who cannot separate the greens at all.

## Height of the plan. Fixed, because the body is a VBox and a block that grew
## with its content would shove the sections under it around.
const PLAN_HEIGHT := 132.0
## Margin between the outermost wall and the edge of the block.
const PLAN_INSET := 8.0
## Under this width a room cannot carry its name and goes unlabelled.
const PLAN_LABEL_MIN_WIDTH := 34.0
## Arms of the cross marking the incident, and its stroke.
const PLAN_MARK_ARM := 5.0
const PLAN_MARK_WIDTH := 2.0


## A floor-plan block: section caption, rule, plan. Returns the plan Control,
## which is what set_floor_plan() takes. The caption and rule travel with it --
## with no table to draw the whole block hides itself, rather than leaving a
## heading over an empty rectangle, which reads as a broken readout.
func add_floor_plan(column: VBoxContainer, caption_key: String) -> Control:
	var block := VBoxContainer.new()
	block.name = "Floor Plan Block"
	block.add_theme_constant_override("separation", ROW_GAP)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(block)
	add_report_section(block, caption_key)

	var plan := Control.new()
	plan.name = "Plan"
	plan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan.custom_minimum_size = Vector2(0, PLAN_HEIGHT)
	plan.set_meta("rooms", [])
	plan.set_meta("night", 0)
	plan.set_meta("mark", Vector2.ZERO)
	plan.set_meta("marked", false)
	# The block is reached by id for the reason the percentage label is: a caller
	# may free the page this lives on, and a freed Object cannot be cast.
	plan.set_meta("block", block.get_instance_id())
	plan.draw.connect(_draw_floor_plan.bind(plan))
	plan.resized.connect(plan.queue_redraw)
	block.add_child(plan)
	_plan_ids.append(plan.get_instance_id())
	return plan


## Drive a plan built by add_floor_plan().
##
## `rooms` is SecurityCameraTablet.ROOMS exactly as it stands in that file --
## [key, world centre (x, z), world size (w, d), first night open] -- passed
## through untouched, because the moment this file reshapes the table it has
## started being a second copy of it.
##
## `night` seals every room that opens later than it. Pass 0 for "do not claim to
## know", which draws the whole building open. `mark` is a world (x, z) the page
## wants called out -- the incident -- and is ignored unless `marked`.
func set_floor_plan(plan: Control, rooms: Array, night: int,
		mark := Vector2.ZERO, marked := false) -> void:
	if plan == null or not is_instance_valid(plan):
		return
	plan.set_meta("rooms", rooms)
	plan.set_meta("night", night)
	plan.set_meta("mark", mark)
	plan.set_meta("marked", marked)
	var block := instance_from_id(int(plan.get_meta("block", 0))) as Control
	if block != null:
		block.visible = not rooms.is_empty()
	plan.queue_redraw()


## Bounding box of every rectangle in the table, in world (x, z). Drives the fit,
## so the plan cannot be thrown off by a room being added or moved.
func _plan_bounds(rooms: Array) -> Rect2:
	var box := Rect2()
	var started := false
	for entry: Variant in rooms:
		var row := entry as Array
		if row == null or row.size() < 4:
			continue
		var centre: Vector2 = row[1]
		var half: Vector2 = (row[2] as Vector2) * 0.5
		var rect := Rect2(centre - half, half * 2.0)
		box = rect if not started else box.merge(rect)
		started = true
	return box


## Index of the room containing `point`, or -1. Strict containment: the mark is
## an incident inside the building, not a player who may be standing in a doorway
## -- the slack rule for that case belongs to Compass, which owns the readout it
## is there to steady.
func _plan_room_at(rooms: Array, point: Vector2) -> int:
	for index in range(rooms.size()):
		var row := rooms[index] as Array
		if row == null or row.size() < 4:
			continue
		var centre: Vector2 = row[1]
		var half: Vector2 = (row[2] as Vector2) * 0.5
		if absf(point.x - centre.x) <= half.x and absf(point.y - centre.y) <= half.y:
			return index
	return -1


func _draw_floor_plan(plan: Control) -> void:
	var rooms: Array = plan.get_meta("rooms", [])
	var view := plan.size
	if rooms.is_empty() or view.x <= 0.0 or view.y <= 0.0:
		return
	var bounds := _plan_bounds(rooms)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return

	var level := get_effective_corruption()
	var walls := chrome_color(level)
	var struck := secondary_color(level)
	var ink := primary_color(level)
	# One scale for both axes and the result centred: the museum keeps its
	# proportions instead of being stretched to whatever shape the block is.
	var fit := minf((view.x - PLAN_INSET * 2.0) / bounds.size.x,
		(view.y - PLAN_INSET * 2.0) / bounds.size.y)
	var origin := (view - bounds.size * fit) * 0.5 - bounds.position * fit
	var night := int(plan.get_meta("night", 0))
	var marked := bool(plan.get_meta("marked", false))
	var mark: Vector2 = plan.get_meta("mark", Vector2.ZERO)
	var here := _plan_room_at(rooms, mark) if marked else -1
	var font := plan.get_theme_default_font()

	for index in range(rooms.size()):
		var row := rooms[index] as Array
		if row == null or row.size() < 4:
			continue
		var centre: Vector2 = row[1]
		var half: Vector2 = (row[2] as Vector2) * 0.5
		var rect := Rect2(origin + (centre - half) * fit, half * 2.0 * fit)
		# night 0 means the caller does not know, and an unknown building is drawn
		# open rather than sealed -- guessing shut is the guess that strands people.
		var sealed_off := night > 0 and night < int(row[3])
		if index == here:
			# A lighter cell, not a coloured one. The accent may be spoken for
			# elsewhere on the page and this mark still has to read.
			plan.draw_rect(rect, UITheme.SURFACE_RAISED, true)
		plan.draw_rect(rect, struck if sealed_off else walls, false, 1.0)
		if sealed_off:
			# Struck through, not merely greyed: the cross is what a player who
			# cannot tell one grey from the other actually reads.
			plan.draw_line(rect.position, rect.position + rect.size, struck, 1.0)
			plan.draw_line(rect.position + Vector2(rect.size.x, 0.0),
				rect.position + Vector2(0.0, rect.size.y), struck, 1.0)
			continue
		if font == null or rect.size.x < PLAN_LABEL_MIN_WIDTH:
			continue
		# Brackets, not colour, say which room the report is about.
		var caption := tr(String(row[0]))
		if index == here:
			caption = "[%s]" % caption
		plan.draw_string(font,
			rect.position + Vector2(3.0, float(UITheme.CAPTION) + 2.0),
			caption, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 6.0,
			UITheme.CAPTION, ink)

	if not marked:
		return
	var spot := origin + mark * fit
	plan.draw_line(spot - Vector2(PLAN_MARK_ARM, PLAN_MARK_ARM),
		spot + Vector2(PLAN_MARK_ARM, PLAN_MARK_ARM), ink, PLAN_MARK_WIDTH)
	plan.draw_line(spot + Vector2(PLAN_MARK_ARM, -PLAN_MARK_ARM),
		spot + Vector2(-PLAN_MARK_ARM, PLAN_MARK_ARM), ink, PLAN_MARK_WIDTH)


## Re-resolve every caption this file handed out. Called from _apply_type(), so
## it runs at construction and again on NOTIFICATION_TRANSLATION_CHANGED.
func _refresh_report_captions() -> void:
	for id: int in _report_captions.keys():
		var label := instance_from_id(id) as Label
		if label == null:
			_report_captions.erase(id)
			continue
		label.text = tr(_report_captions[id])


## The screen's own title, by catalogue key. "" clears it.
func set_title(key: String) -> void:
	_title_key = key
	_render()


## The masthead. Defaults to HUD_PROTO_HEADER, which is already the institution
## line the protocol screen prints; there is no second wording of it.
func set_institution(key: String) -> void:
	_institution_key = key
	_render()


## Select the shared panel family without copying palette values into callers.
## The fallback keeps typoed or empty values on the normal terminal contract.
func set_panel_variation(variation: StringName) -> void:
	var backdrop := get_node_or_null("Backdrop") as Panel
	if backdrop == null:
		return
	var allowed: Array[StringName] = [
		&"TerminalPanel", &"CCTVPanel", &"WarningPanel", &"InstrumentPanel"]
	backdrop.theme_type_variation = variation if variation in allowed else &"TerminalPanel"


## The whole status cluster in one call.
##
## `night` < 1 and `shift_seconds` < 0 blank their readouts rather than printing
## a wrong one. `core_key` "" hides the core chip; it stays hidden while the
## catalogue has no row for the state, which is why nothing here defaults it.
func set_status(night: int, shift_seconds: float, core_key: String = "",
		core_level: int = CORE_NOMINAL) -> void:
	_night = night
	_shift_seconds = shift_seconds
	_core_key = core_key
	_core_level = clampi(core_level, CORE_NOMINAL, CORE_OFFLINE)
	_render()


func set_night(night: int) -> void:
	_night = night
	_render()


## Shift clock, in seconds of in-fiction time. Rendered HH:MM on a 24 h dial, so
## a caller may pass either "seconds since midnight" or "23:00 plus elapsed" --
## whichever its own fiction keeps. Negative blanks the readout.
func set_shift_time(seconds: float) -> void:
	_shift_seconds = seconds
	_render()


func set_core_state(key: String, level: int = CORE_NOMINAL) -> void:
	_core_key = key
	_core_level = clampi(level, CORE_NOMINAL, CORE_OFFLINE)
	_render()


## The footer legend. Each entry is either ["E", "TUT_STEP_INTERACT"] or
## {"cap": "E", "label": "TUT_STEP_INTERACT"}.
##
## `cap` is the glyph on the key, printed as given -- but it is passed through
## tr() first, so a caller with a cap that has to be translated ("LMB" / "ЛКМ")
## can hand over a key there too. `label` is always a key.
func set_keys(hints: Array) -> void:
	_hints = hints.duplicate()
	_rebuild_footer()
	_render()


# --- PUBLIC API: DEGRADATION -------------------------------------------------

## Sustained corruption, 0..1. Survives pulses; a pulse rides on top of it.
func set_corruption(value: float) -> void:
	_corruption = clampf(value, 0.0, 1.0)
	_render()
	_sync_process()


## The sustained level, without any pulse currently riding on it.
func get_corruption() -> float:
	return _corruption


## Effective corruption right now: sustained plus whatever the pulse still has.
func get_effective_corruption() -> float:
	if _signal_lost:
		return 1.0
	return clampf(_corruption + _pulse_amount, 0.0, 1.0)


## A transient spike -- the Curator is close, a surge just hit. `amount` is added
## on top of set_corruption()'s floor and decays linearly over `seconds`.
##
## Under reduced_flashes it does not decay: it holds at full value for the whole
## duration and then drops in one step. Same information, two repaints, no ramp.
func pulse_corruption(amount: float, seconds: float) -> void:
	var value := clampf(amount, 0.0, 1.0)
	var span := maxf(seconds, 0.0)
	if value <= 0.0 or span <= 0.0:
		return
	# A stronger spike replaces a weaker one instead of stacking; two overlapping
	# proximity events must not sum into a whiteout.
	if value >= _pulse_amount:
		_pulse_amount = value
		_pulse_span = span
		_pulse_left = span
	else:
		_pulse_left = maxf(_pulse_left, span)
	_render()
	_sync_process()


## The terminal end state. `message_key` "" leaves the plate empty rather than
## printing a placeholder; the torn picture still reads as a dead feed.
func set_signal_lost(lost: bool, message_key: String = "") -> void:
	_signal_lost = lost
	if message_key != "":
		_lost_key = message_key
	body.visible = not lost
	_lost_panel.visible = lost
	_render()
	_sync_process()


func is_signal_lost() -> bool:
	return _signal_lost


## Take the tube off, for a caller that wants the layout without the glass.
func set_crt_enabled(enabled: bool) -> void:
	_crt_enabled = enabled
	_crt_applied = -1.0
	_apply_crt()


## Let a label in `body` rot with the rest of the page. The key is kept so the
## clean text can be restored on a language change or when corruption drops.
func add_glitch_target(label: Label, key: String) -> void:
	if not is_instance_valid(label):
		return
	_glitch_targets[label.get_instance_id()] = key
	_render()


func remove_glitch_target(label: Label) -> void:
	if not is_instance_valid(label):
		return
	_glitch_targets.erase(label.get_instance_id())
	_render()


## Re-read SettingsManager and repaint. Cheap enough to call whenever the owning
## screen is raised: one group lookup and a repaint, no allocation.
func refresh() -> void:
	_read_settings()
	_crt_applied = -1.0
	_render()
	_sync_process()
	if _crt != null:
		_crt.refresh()


# --- SETTINGS ----------------------------------------------------------------

## Same resolution the other four readers of `reduced_flashes` use -- one
## `get_first_node_in_group`, null-guarded, field read through `.get()` -- and the
## same one-shot subscription CRTOverlay._watch() uses, so a toggle flipped in the
## pause menu lands here without the owner having to forward it.
func _read_settings() -> void:
	if not is_inside_tree():
		return
	_settings = get_tree().get_first_node_in_group("settings_manager")
	if _settings == null:
		_reduced = false
		return
	_reduced = bool(_settings.get("reduced_flashes"))
	if _settings.has_signal("settings_changed") \
			and not _settings.is_connected("settings_changed", refresh):
		_settings.connect("settings_changed", refresh)


## True when the frame is allowed to animate at all.
func _motion_allowed() -> bool:
	return not _reduced


# --- RENDER ------------------------------------------------------------------

## Repaint everything from the current state.
##
## Runs on every setter, and at GLITCH_HZ while the page is rotting -- never
## per-frame, and never at all on a clean, still page, because _sync_process()
## turns _process off there. It is deliberately not incremental: the alternative
## is caching which of corruption / core level / signal state last moved and
## invalidating that cache from six setters, which is two stale-colour bugs
## waiting to happen for the sake of a few dozen theme overrides a second.
func _render() -> void:
	var level := get_effective_corruption()
	var primary := primary_color(level)
	var secondary := secondary_color(level)

	_glitch_targets[_masthead.get_instance_id()] = _institution_key
	_glitch_targets[_title.get_instance_id()] = _title_key

	UITheme.apply_text(_masthead, UITheme.CAPTION, secondary)
	UITheme.apply_text(_title, UITheme.TITLE, primary)
	# A caller may have freed a body label it opted in with add_glitch_target();
	# collect those here rather than erasing mid-iteration.
	var stale: Array[int] = []
	var masthead_id := _masthead.get_instance_id()
	for id: int in _glitch_targets:
		var label := instance_from_id(id) as Label
		if label == null:
			stale.append(id)
			continue
		var key := _glitch_targets[id]
		var text := tr(key) if key != "" else ""
		# Case is decided here and not in localization/game.csv, so a translator
		# writes the institution's name and the terminal decides how to letter it.
		# HUD_PROTO_HEADER is already stencilled in both locales, so this is a
		# no-op today and the guarantee for whatever set_institution() is handed.
		if id == masthead_id:
			text = TerminalType.institutional(text)
		label.text = _glitch(text)
		label.visible = label.text != ""
	for id: int in stale:
		_glitch_targets.erase(id)

	_render_status(level, primary, secondary)
	_render_footer(secondary)

	_lost_label.text = TerminalType.institutional(tr(_lost_key)) if _lost_key != "" else ""
	UITheme.apply_text(_lost_label, UITheme.SECTION, primary)

	_top_rule.queue_redraw()
	_bottom_rule.queue_redraw()
	_meter.queue_redraw()
	_noise.queue_redraw()
	_lost_bands.queue_redraw()
	# The plans are painted, not laid out, so nothing above this reaches them:
	# their ink walks the corruption ramp and their room names come from tr().
	for index in range(_plan_ids.size() - 1, -1, -1):
		var plan := instance_from_id(_plan_ids[index]) as Control
		if plan == null:
			_plan_ids.remove_at(index)
			continue
		plan.queue_redraw()
	_apply_crt()


func _render_status(level: float, primary: Color, secondary: Color) -> void:
	var lost := _signal_lost
	_night_chip.text = NO_READING if lost or _night < 1 \
		else Loc.fmt("HUD_NIGHT", [_night])
	_clock_chip.text = NO_READING if lost or _shift_seconds < 0.0 \
		else _clock_text(_shift_seconds)
	UITheme.apply_text(_night_chip, UITheme.LABEL, primary)
	UITheme.apply_text(_clock_chip, UITheme.LABEL, primary)

	var effective_level := CORE_OFFLINE if lost else _core_level
	_core_chip_frame.visible = _core_key != ""
	if _core_chip_frame.visible:
		var colour := _core_color(effective_level, level)
		_core_chip.text = tr(_core_key)
		UITheme.apply_text(_core_chip, UITheme.LABEL, colour)
		# Weight, not only hue: a critical core is the one chip with a double
		# border, which survives both a monochrome display and colour blindness.
		# The stylebox is mutated rather than rebuilt -- _render() runs at
		# GLITCH_HZ while the page is rotting, and a fresh resource per tick is
		# garbage the frame does not need to make.
		_core_style.border_color = colour
		_core_style.set_border_width_all(UITheme.FOCUS_WIDTH \
			if effective_level == CORE_CRITICAL else UITheme.BORDER_WIDTH)

	_meter_value.text = "%d%%" % _integrity_percent()
	UITheme.apply_text(_meter_value, UITheme.LABEL, primary if level < 1.0 else secondary)


func _render_footer(secondary: Color) -> void:
	# The legend never rots and never dims below the readable ramp: it is how the
	# player leaves the screen. Only the description tracks the palette.
	for hint in _footer.get_children():
		var description := hint.get_node_or_null("Text") as Label
		if description != null:
			UITheme.apply_text(description, UITheme.LABEL, secondary)


func _rebuild_footer() -> void:
	for child in _footer.get_children():
		_footer.remove_child(child)
		child.queue_free()
	for entry: Variant in _hints:
		var cap := ""
		var label_key := ""
		if entry is Dictionary:
			cap = String(entry.get("cap", ""))
			label_key = String(entry.get("label", ""))
		elif entry is Array and entry.size() >= 2:
			cap = String(entry[0])
			label_key = String(entry[1])
		if cap == "" and label_key == "":
			continue
		_footer.add_child(_build_hint(cap, label_key))


func _build_hint(cap: String, label_key: String) -> Control:
	var hint := HBoxContainer.new()
	hint.add_theme_constant_override("separation", CAP_GAP)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var plate := PanelContainer.new()
	plate.name = "Cap"
	plate.custom_minimum_size = Vector2(CAP_MIN_WIDTH, 0)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", _chip_style())
	hint.add_child(plate)

	var glyph := Label.new()
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# tr() so a cap that needs translating can arrive as a key; a plain glyph is
	# returned unchanged, which is what every ASCII cap does.
	glyph.text = tr(cap) if cap != "" else ""
	# A readout rather than a label: caps are as often "1" / "5" / "F3" as they
	# are "E", and the readout treatment puts those digits on the same tabular
	# grid the status cluster uses. Its tracking rounds to 0 px at LABEL, which is
	# what a single centred glyph wants anyway -- spacing_glyph pads after the
	# last glyph too, and on a one-character cap that reads as an off-centre cap.
	TerminalType.apply_readout(glyph, UITheme.LABEL, UITheme.ON_SURFACE)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(glyph)

	var description := Label.new()
	description.name = "Text"
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	description.text = tr(label_key) if label_key != "" else ""
	TerminalType.apply_label(description, UITheme.LABEL, UITheme.MUTED)
	hint.add_child(description)
	return hint


func _clock_text(seconds: float) -> String:
	var total := int(seconds) % 86400
	return "%02d:%02d" % [int(total / 3600.0), int((total % 3600) / 60.0)]


func _integrity_percent() -> int:
	return int(round((1.0 - get_effective_corruption()) * 100.0))


# --- PALETTE -----------------------------------------------------------------
#
# Static so a caller filling `body` can dress its own content on the same ramp
# instead of inventing a second one. Every return value is tabulated in the
# contrast block at the top of this file.

## Primary text. Falls only PRIMARY_DRIFT of the way to MUTED at c=1.
static func primary_color(level: float) -> Color:
	return UITheme.ON_SURFACE.lerp(UITheme.MUTED, clampf(level, 0.0, 1.0) * PRIMARY_DRIFT)


## Secondary text. MUTED drifting to TEXT_DIM; 5.13 : 1 at the worst pixel.
static func secondary_color(level: float) -> Color:
	return UITheme.MUTED.lerp(TEXT_DIM, clampf(level, 0.0, 1.0))


## Live accent: the CRT green LOSING POWER, not changing meaning.
##
## It used to walk ACCENT -> WARNING, and that leaked amber into places that
## have nothing to say about stability: the hot edge of every dropped line, a
## third of the speckle, the lit segments of the integrity meter and the chip
## of a perfectly nominal core. The reference README keeps amber for exactly
## one reading -- the stability bar in add_stability_bar() -- and green for
## "штатная работа". A page can be rotting and still be nominal; those are
## two different facts and they are not allowed to share a colour.
##
## So corruption now DRAINS the accent instead of repainting it. Where a real
## warning is due, the caller says so outright -- see _draw_meter(), which
## steps to WARNING at 0.4 and DANGER at 0.75 on its own.
##
## FILL AND STROKE ONLY. UITheme measures ACCENT_DIM at 3.15 : 1 on SURFACE,
## under the 4.5 gate for text, and says so itself: "ACCENT_DIM is a
## fill/border token ONLY. Do not set it as font_color; use ACCENT." Anything
## on this ramp that ends up as a font_color must take flat ACCENT instead.
static func accent_color(level: float) -> Color:
	return UITheme.ACCENT.lerp(UITheme.ACCENT_DIM, clampf(level, 0.0, 1.0))


## Hairlines and borders. BORDER -> DANGER, which is *lighter*, so a corrupted
## rule is easier to see than a clean one -- 3.76 : 1 rising to 5.01 : 1.
static func chrome_color(level: float) -> Color:
	return UITheme.BORDER.lerp(UITheme.DANGER, clampf(level, 0.0, 1.0))


func _core_color(core_level: int, level: float) -> Color:
	match core_level:
		CORE_UNSTABLE:
			return UITheme.WARNING
		CORE_CRITICAL:
			return UITheme.DANGER
		CORE_OFFLINE:
			return secondary_color(level)
		_:
			# Штатное ядро — ровный зелёный, без дрейфа. Это ЦВЕТ ТЕКСТА
			# чипа, а accent_color() теперь уходит в ACCENT_DIM, который
			# как надпись не проходит по контрасту.
			return UITheme.ACCENT


# --- DRAWING -----------------------------------------------------------------

## The hairline. Whole at c=0; at c>0 it loses spans, which is the one
## degradation cue that is pure shape and therefore survives every display, every
## colour-vision profile and reduced_flashes.
func _draw_rule(rule: Control) -> void:
	var level := get_effective_corruption()
	var width := rule.size.x
	if width <= 0.0:
		return
	var colour := chrome_color(level)
	var y := float(RULE_HEIGHT) * 0.5
	var gaps := int(round(level * float(RULE_MAX_GAPS)))
	if gaps <= 0:
		rule.draw_line(Vector2(0.0, y), Vector2(width, y), colour, 1.0)
		return
	# Seeded off the rule's own name so the two rules break differently, and off
	# nothing else, so the pattern is fixed for a given corruption level and does
	# not shimmer between repaints -- including under reduced_flashes.
	_rng.seed = hash(rule.name) + gaps
	var cuts: Array[float] = []
	for i in range(gaps):
		cuts.append(_rng.randf_range(0.0, maxf(0.0, width - RULE_GAP_WIDTH)))
	cuts.sort()
	var cursor := 0.0
	for cut in cuts:
		if cut > cursor:
			rule.draw_line(Vector2(cursor, y), Vector2(cut, y), colour, 1.0)
		cursor = maxf(cursor, cut + RULE_GAP_WIDTH)
	if cursor < width:
		rule.draw_line(Vector2(cursor, y), Vector2(width, y), colour, 1.0)


func _draw_meter() -> void:
	var level := get_effective_corruption()
	var lit := int(round((1.0 - level) * float(METER_SEGMENTS)))
	var live := accent_color(level)
	if level >= 0.75:
		live = UITheme.DANGER
	elif level >= 0.4:
		live = UITheme.WARNING
	var dim := chrome_color(level)
	for i in range(METER_SEGMENTS):
		var box := Rect2(
			float(i) * (METER_SEGMENT_WIDTH + METER_SEGMENT_GAP), 0.0,
			METER_SEGMENT_WIDTH, METER_HEIGHT)
		if i < lit:
			_meter.draw_rect(box, live)
		else:
			# Empty segments stay outlined so the scale is still countable when
			# the meter is nearly dead -- an unlit run must read as "eight slots,
			# one filled", not as "one lonely mark".
			_meter.draw_rect(box, dim, false, 1.0)


## Murk, dropped lines and speckle. Everything past the murk is time-varying and
## is skipped outright when motion is not allowed.
func _draw_noise() -> void:
	var level := get_effective_corruption()
	if level <= 0.0:
		return
	var page := _noise.size
	if page.x <= 0.0 or page.y <= 0.0:
		return
	_noise.draw_rect(Rect2(Vector2.ZERO, page), Color(UITheme.SURFACE, MURK_MAX * level))
	if not _motion_allowed():
		return

	# The legend is silkscreen: nothing is allowed to tear across it.
	var limit := page.y
	if _footer != null and _footer.is_inside_tree():
		limit = clampf(_footer.global_position.y - _noise.global_position.y,
			0.0, page.y)

	_rng.seed = _noise_seed
	var bands := int(round(level * float(BAND_MAX)))
	for i in range(bands):
		var height := _rng.randf_range(BAND_MIN_HEIGHT, BAND_MAX_HEIGHT)
		var y := _rng.randf_range(0.0, maxf(0.0, limit - height))
		_noise.draw_rect(Rect2(0.0, y, page.x, height),
			Color(UITheme.SURFACE, BAND_ALPHA))
		# One bright edge per slab: a dropout on a phosphor tube leaves a hot line
		# where the beam restarts, and without it the slabs read as black tape.
		_noise.draw_rect(Rect2(0.0, y, page.x, 1.0),
			Color(accent_color(level), SPECK_LIGHT_ALPHA))

	var specks := int(round(level * float(SPECK_MAX)))
	for i in range(specks):
		var at := Vector2(
			_rng.randf_range(0.0, maxf(0.0, page.x - SPECK_SIZE)),
			_rng.randf_range(0.0, maxf(0.0, limit - SPECK_SIZE)))
		var hot := _rng.randf() < 0.35
		_noise.draw_rect(Rect2(at, Vector2(SPECK_SIZE, SPECK_SIZE)),
			Color(accent_color(level), SPECK_LIGHT_ALPHA) if hot
			else Color(UITheme.SURFACE, SPECK_DARK_ALPHA))


## The torn picture behind the signal-lost plate. Free to be violent: the message
## sits on an opaque plate above it, so none of this touches the text contrast.
func _draw_lost_bands() -> void:
	var page := _lost_bands.size
	if page.x <= 0.0 or page.y <= 0.0:
		return
	# Fixed seed when motion is off, so the tear is a still photograph rather than
	# a pattern that changes every time something forces a repaint.
	_rng.seed = _noise_seed if _motion_allowed() else 1
	for i in range(LOST_BANDS):
		var height := _rng.randf_range(1.0, 6.0)
		var y := _rng.randf_range(0.0, maxf(0.0, page.y - height))
		var width := _rng.randf_range(page.x * 0.25, page.x)
		var x := _rng.randf_range(0.0, maxf(0.0, page.x - width))
		_lost_bands.draw_rect(Rect2(x, y, width, height),
			Color(UITheme.MUTED, _rng.randf_range(0.05, 0.16)))


# --- CHARACTER ROT -----------------------------------------------------------

## Replace up to GLITCH_MAX_RATIO of `text` with GLITCH_ALPHABET. Length is
## preserved, spaces are left alone -- word boundaries are what let a player read
## a half-rotten line at all -- and nothing happens when motion is not allowed.
func _glitch(text: String) -> String:
	var level := get_effective_corruption()
	if text == "" or level <= 0.0 or not _motion_allowed():
		return text
	var count := int(round(float(text.length()) * GLITCH_MAX_RATIO * level))
	if count <= 0:
		return text
	# Seeded off the string as well as the tick, so two labels showing different
	# text rot differently but each one is stable within a tick.
	_rng.seed = _noise_seed * 31 + hash(text)
	var pool := _rot_pool()
	var out := text
	for i in range(count):
		var at := _rng.randi_range(0, out.length() - 1)
		if out[at] == " ":
			continue
		var glyph := pool[_rng.randi_range(0, pool.length() - 1)]
		out = out.substr(0, at) + glyph + out.substr(at + 1)
	return out


## GLITCH_ALPHABET minus anything the resolved font cannot draw.
##
## Measured against the masthead -- the label the rot is most visible on, and the
## one wearing the display face rather than the mono one -- and cached until
## _apply_type() clears it on a locale change. ASCII "#" is the floor: no font in
## existence is missing it, so the pool can never come back empty and _glitch()
## can never index an empty string.
##
## Cost is one has_char() per character of the alphabet, once.
func _rot_pool() -> String:
	if _glitch_pool != "":
		return _glitch_pool
	var pool := ""
	for i in range(GLITCH_ALPHABET.length()):
		var glyph := GLITCH_ALPHABET[i]
		if TerminalType.has_glyphs(glyph, _masthead):
			pool += glyph
	_glitch_pool = pool if pool != "" else "#"
	return _glitch_pool


# --- CRT ---------------------------------------------------------------------

## Ramp the tube with the corruption, inside the budget the contrast table above
## was computed against. CRTOverlay does its own reduced_flashes and
## quality_preset handling, so nothing here duplicates it.
func _apply_crt() -> void:
	if _crt == null:
		return
	var target := 0.0
	if _crt_enabled:
		target = lerpf(CRT_INTENSITY_CLEAN, CRT_INTENSITY_WORST,
			get_effective_corruption())
	if absf(target - _crt_applied) < CRT_INTENSITY_EPSILON:
		return
	_crt_applied = target
	_crt.set_intensity(target)


# --- TICK --------------------------------------------------------------------

## _process runs only while something is genuinely changing: a pulse counting
## down, or a corrupted page that is allowed to animate. A clean, still frame
## costs nothing.
func _sync_process() -> void:
	var animating := _motion_allowed() \
		and (get_effective_corruption() > 0.0 or _signal_lost)
	set_process(animating or _pulse_left > 0.0)


func _process(delta: float) -> void:
	var expired := false
	if _pulse_left > 0.0:
		_pulse_left = maxf(0.0, _pulse_left - delta)
		if _motion_allowed() and _pulse_span > 0.0:
			# Linear decay back onto the sustained floor.
			_pulse_amount = _pulse_amount * (_pulse_left / maxf(_pulse_span, 0.0001))
			_pulse_span = _pulse_left
		if _pulse_left <= 0.0:
			_pulse_amount = 0.0
			_pulse_span = 0.0
			expired = true

	if not _motion_allowed():
		# Reduced flashes: the only thing that may change is the pulse ending, and
		# that is a single step, not a ramp.
		if expired:
			_render()
			_sync_process()
		return

	_since_tick += delta
	if _since_tick < 1.0 / GLITCH_HZ and not expired:
		return
	_since_tick = 0.0
	_noise_seed += 1
	_render()
	if expired:
		_sync_process()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _title != null:
		# Type first: a locale can resolve a different font, and both the numeric
		# reservations and the rot pool are measured from the font, so they have to
		# be re-derived before anything is laid out against them.
		_apply_type()
		_rebuild_footer()
		_render()
