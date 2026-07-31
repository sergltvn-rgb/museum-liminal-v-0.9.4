class_name TerminalType
extends RefCounted
## Typographic treatment that sets the game's two faces as instrument output.
##
## Stage 9.5, revised after the fonts landed. The original version of this file
## was written when the project shipped ZERO font files and every screen rendered
## in Open Sans SemiBold, the face compiled into the engine binary -- which is
## why "выглядит как сток Godot" was a literal description. That is no longer the
## situation: fonts/JetBrainsMono.ttf and fonts/Oswald.ttf are in the repository
## under OFL 1.1, UITheme owns loading them, and ui/museum_theme.tres carries the
## mono face as its default_font. THE ASSET REQUEST AT THE BOTTOM OF THIS FILE
## HAS BEEN ANSWERED; what is left of it is the part about weights.
##
## So this file's job changed. It is no longer a workaround for having no font.
## It is the layer that decides WHICH of the two faces a given label speaks in,
## and how it is set once chosen: tracking, case, leading and numeric alignment.
## UITheme's own header hands that decision here in as many words -- "headings
## opt into display_font() explicitly through TerminalType, which owns the
## institutional voice".
##
## It adds no sizes and no colours. Every entry point takes one of UITheme's six
## steps and one of UITheme's tokens, and routes the colour through
## UITheme.apply_text() so the contrast table in that file stays the only
## contrast table. Nothing here animates, so there is nothing for
## SettingsManager.reduced_flashes to switch off.
##
##
## WHAT THE ENGINE ACTUALLY GIVES US -- MEASURED, NOT ASSUMED
##
## All of the following was read out of Godot 4.7.stable on the target machine
## (headless probe, TextServer "ICU / HarfBuzz / Graphite (Built-in)"):
##
##   JetBrains Mono / Regular .... the theme's default_font, and set explicitly
##                                 on Label, RichTextLabel, Button, CheckButton,
##                                 OptionButton, LineEdit and TextEdit. Every
##                                 Control in the game that does not override its
##                                 font resolves to this. MONOSPACED, verified by
##                                 advance and not by name: "i", "W", "M" and "0"
##                                 all measure 11.0 px at BODY 17.
##   Oswald / Regular ............ reached only through UITheme.display_font(),
##                                 which chains it to the mono face for glyphs it
##                                 lacks. Condensed grotesque, proportional: "i"
##                                 4.0, "W" 13.0, "M" 12.0, "0" 9.0 at BODY 17.
##   Open Sans SemiBold .......... ThemeDB.fallback_font, still what anything
##                                 OUTSIDE the theme chain gets -- notably every
##                                 Label3D in the 3D world, which does not read
##                                 Control themes at all. It is missing a great
##                                 deal; see GLYPH COVERAGE.
##
##   METRICS at UITheme's six steps (size -> line box / digit advance):
##       JetBrains Mono   12 -> 17/8   14 -> 20/9   17 -> 24/11
##                        21 -> 29/13  28 -> 38/17  48 -> 64/29
##       Oswald           12 -> 19/7   14 -> 22/8   17 -> 26/9
##                        21 -> 33/11  28 -> 43/14  48 -> 72/25
##   The mono line box is 1.33-1.43x the size; Oswald's is 1.50-1.58x. They are
##   NOT interchangeable, which is why leading_for() takes the resolved font
##   rather than asking the Control -- at TITLE 28 the two differ by 5 px a line.
##
##   FIGURES ARE TABULAR BY CONSTRUCTION on the mono face: "111111" and "098765"
##   both measure 101.0 px at TITLE 28. That is the property a countdown needs
##   and the reason the readout helpers stay on the mono face. Oswald's are not
##   ("111111" 63.0 vs "098765" 80.0 at 28), which is the other half of the same
##   reason: a number is never set in the display face.
##
##   TRACKING WORKS on both. FontVariation.spacing_glyph adds N pixels to every
##   glyph advance: "ПЕРВЫЙ МУЗЕЙ · СЛУЖБА НОЧНОГО СДЕРЖИВАНИЯ" at CAPTION 12
##   measures 296 / 336 / 376 px in the mono face and 240 / 280 / 320 px in
##   Oswald at spacing 0 / 1 / 2. It is an absolute pixel value, not an em
##   fraction, which is why tracking_px() derives it from the size.
##
##   GLYPH COVERAGE IS NO LONGER THE HARD LIMIT -- BUT IT IS STILL A LIMIT.
##   Re-probed with Font.has_char() on 4.7.stable, all three faces:
##
##     characters the bundled faces carry and the engine fallback does NOT
##         ▓ ▒ ░ █ ─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼ ≡ ■ □ ▪ ▫ ● ◆ ◇ ▲ ▼ ◀ ▶ → ← ↑ ↓
##     missing from ALL THREE, do not type these anywhere
##         ▮ ○ ◉ ⌁ ＋ ⊕ ⊙ ☰ ⬛ ⌂ ⚙ ✱ ❖
##     present everywhere, safe in any context including Label3D
##         · • × ÷ ± ° § ¶ † ‡ № ¤ ◊ ¦ ¬ µ ‰ ≈ ≠ ≤ ≥ ∆ √ ∞ ¡ ¿ « » … – — _ | / \
##
##   THE SPLIT IS THE TRAP. The bundled faces reach every Control through
##   ui/museum_theme.tres, and they reach NOTHING ELSE. Label3D does not read a
##   Control theme; unless its `font` is assigned it draws in the engine
##   fallback, so a box-drawing character that looks right on a terminal panel is
##   a tofu box on museum signage two metres away, from the same string constant.
##   Rules and bars are still better drawn as geometry -- UITheme's
##   HSeparator/StyleBoxLine, or a ColorRect -- because geometry has no
##   repertoire to be missing from.
##
##   This is not theoretical. SettingsPanel.TAB_ICONS shipped as
##   ["◉", "◇", "⌁", "＋"]: three of those four are in the missing-everywhere row,
##   so the settings rail drew three empty boxes in the mono face and four in the
##   fallback. has_glyphs() below is the guard, and it costs one has_char() per
##   character -- it asks the face the Control actually resolved rather than a
##   list somebody wrote down, which is the only version of this check that stays
##   true when the theme changes again.
##
##
## THE SYSTEM-FONT OPTION, AND WHY IT IS NOW DEAD
##
## Godot's SystemFont names an OS family with fallbacks, and before the OFL files
## landed it was the only way to reach a monospace at all. It is no longer worth
## considering, and system_mono() / mono_report() survive only as diagnostics.
## The two findings that killed it are worth keeping, because they are the
## argument for why the mono face is a FILE IN THE REPOSITORY and not a family
## name looked up on the player's machine:
##
##   1. SystemFont FAILS SILENTLY. Asked for "DejaVu Sans Mono" -- or for
##      "NotAFontAtAll12345" -- SystemFont.get_font_name() returns
##      "Open Sans SemiBold". No error, no warning, no push_error: the screen
##      simply goes back to looking like stock Godot on that player's machine.
##      A shipped build cannot depend on a resource that can evaporate without
##      saying so. Measured on this Windows 10 box: "Consolas" and "Courier New"
##      resolve; "Cascadia Mono", "DejaVu Sans Mono", "Liberation Mono",
##      "Noto Sans Mono" and "Menlo" do not exist and report success anyway.
##   2. THE METRICS ARE NOT INTERCHANGEABLE. Line box at size 17: Open Sans 24,
##      Courier New 21, Consolas 18, JetBrains Mono 24. Swapping the family
##      reflows every panel measured against one of those -- and it would reflow
##      DIFFERENTLY per machine, which is the one class of layout bug that cannot
##      be reproduced from a bug report.
##
## system_mono() verifies monospacing behaviourally (advance of "i" == "W" ==
## "M" == "0") instead of trusting the family name, and returns null when the OS
## did not deliver, which is the guard SystemFont itself refuses to provide. It
## is the same check that confirms JetBrains Mono really is monospaced.
##
##
## WHAT THE ASSET REQUEST STILL ASKS FOR
##
## Four of the five items the original version of this file asked for arrived
## with fonts/. What did not:
##
##   * WEIGHT CONTRAST. Both files are a single Regular. Every "bold" in the game
##     is still the same weight as its body text, so emphasis is carried by size,
##     colour, case and tracking alone. FontVariation's `variation_embolden`
##     fakes it by outlining the glyph, which thickens stems unevenly and smears
##     at CAPTION 12, so nothing here uses it. ASK: the Bold (or the variable
##     upright) of either family, same OFL licence, dropped in beside the file
##     it belongs to. That is the one remaining thing this file cannot fake.
##
## Delivered, and now relied on: a voice (two, actually -- see WHICH VOICE EACH
## ONE SPEAKS IN below), a real monospace for readouts, the box/block/arrow
## repertoire on the UI faces, and Cyrillic in both.
##
## THE MIGRATION WAS ONE LINE, AS ADVERTISED -- in fact it was zero. base_font()
## resolves through `control.get_theme_font()` before falling back to ThemeDB, so
## when ui/museum_theme.tres started carrying a font every helper here re-derived
## its variations from it with no edit at all. The tracking ratios, the leading
## multiples and the column measurements are all computed from the resolved
## font's own metrics -- none of the numbers above is hardcoded into the logic.
## The one thing that DID need a line is the second face, because "which of two
## voices" is a decision and not a measurement: display_base().
##
##
## WHY tnum IS REQUESTED EVEN THOUGH IT IS A NO-OP
##
## It is a no-op on all three faces in play -- JetBrains Mono is monospaced by
## construction, and "100%" measures 37 px on Open Sans with the feature and
## without it -- and it is insurance on the next one. Plenty of text faces
## default to PROPORTIONAL figures (a "1" narrower than a "0") or to OLD-STYLE
## figures that hop above and below the baseline; Open Sans ships `pnum` and
## `onum` for exactly that. If a future file arrives with either as its default,
## every readout in the game starts twitching, and the cause -- a font default,
## three layers below the code -- is close to unfindable. Asking for
## `tnum`+`lnum` costs nothing today and makes that impossible tomorrow.
##
##
## WHAT ACTUALLY MAKES A TIMER JITTER (the mono face does NOT fix it)
##
## Digit shapes are uniform now that readouts are set in JetBrains Mono, so a
## five-character clock is stable glyph for glyph. What still moves is the
## CHARACTER COUNT: "9" -> "10" is one more glyph, "1:00" -> "59.9" is one more
## again, and a centred or left-of-centre label re-lays-out around it every tick.
## At SECTION 21 one mono glyph is 13 px, so that is a 13 px hop, every second,
## forever -- and if the label sits in an end-aligned row, everything beside it
## hops too.
##
## The fix is geometric, not typographic: reserve the width of the widest string
## the field will ever hold and align the text to the right, so the last digit is
## nailed down and only the leading digits appear. reserve_numeric() does both.
## A monospaced face makes the reservation EXACT rather than unnecessary.
##
## And measure the reservation with the real string -- do NOT multiply a single
## digit's width by the digit count. Advances are fractional and get_string_size
## rounds the result, so on the proportional fallback one "0" at DISPLAY 48
## measures 27.0 while ten of them measure 275.0: per-digit maths is 5 px short
## across a ten-digit field, and at CAPTION 12 it is 1 px long.
## numeric_column_width() measures the string, which is also the only form that
## survives a template with a ":" or a "." in it.
##
## Space padding is not a substitute either. It happens to work in a monospace
## and it silently stops working the moment anything is set in the display face,
## where the space is 4.0 px against a 9.0 px digit at BODY 17.
##
##
## USAGE
##
##     TerminalType.apply_masthead(header, UITheme.CAPTION, UITheme.MUTED)
##     header.text = TerminalType.institutional(tr("HUD_PROTO_HEADER"))
##
##     TerminalType.apply_body(paragraph)                    # no tracking, 1.5 leading
##     TerminalType.reserve_numeric(clock, "88:88", UITheme.TITLE)
##
##     UITheme.apply_button(key, UITheme.LABEL)              # styleboxes + focus
##     TerminalType.apply_label(key, UITheme.LABEL)          # then the tracking
##
## Order between UITheme's helpers and these is free: fonts, font sizes, colours
## and constants are four different theme item families, so neither call erases
## the other's work.
##
##
## WHO CALLS THIS
##
## This file spent a round with ZERO call sites, which is the same as not
## existing: the owner's complaint was that the game looks like stock Godot, and
## a typographic system nothing invokes changes exactly nothing on screen.
##
## game/TerminalFrame.gd now dresses its own chrome with it, in _apply_type(),
## which reaches every full-screen surface in the game -- menu, pause, settings,
## protocol, fail, win, admin, prologue, rift trial, the CCTV workstation --
## because all of them are TerminalFrame pages. What that buys, concretely:
##
##   masthead ......... apply_masthead() + institutional(): the DISPLAY face,
##                      uppercased, tracked. "ПЕРВЫЙ МУЗЕЙ · СЛУЖБА НОЧНОГО
##                      СДЕРЖИВАНИЯ" at CAPTION 12 goes from 296 px of monospace
##                      to 280 px of tracked condensed grotesque -- narrower AND
##                      more widely spaced, which is what stencilled signage looks
##                      like and what a monospace cannot look like.
##   screen title ..... apply_heading(): the display face at TITLE 28, +2 px per
##                      glyph. A heading and the paragraph under it now differ in
##                      FACE and not only in size, which is the one hierarchy this
##                      project can have while it owns a single weight.
##   status chips ..... apply_readout()/reserve_numeric(): the mono face, and the
##                      clock and the integrity percentage pinned to the width of
##                      their widest reading.
##   footer legend .... apply_label() on the descriptions, apply_readout() on the
##                      key caps so a numeric cap sits on the digit grid.
##
## The typography is applied ONCE, at construction, and re-applied only when the
## locale changes. TerminalFrame._render() runs at 12 Hz while the page is
## rotting and touches colours only; letterforms do not change 12 times a second.
##
## THE HONEST BALANCE. Two faces at one weight is a real voice and a real
## hierarchy, and it is where this stops. Neither file carries a Bold, so
## emphasis inside a running paragraph is still not available to any of these
## helpers -- see WHAT THE ASSET REQUEST STILL ASKS FOR.

# --- TRACKING ---------------------------------------------------------------
#
# Fractions of the font size, converted to whole pixels by tracking_px(). Four
# values, because tracking is a hierarchy signal and a fifth step would not be
# visible: the smallest useful increment is one pixel, and one pixel out of a
# 10 px advance is already 10%.
#
# READABILITY IS THE CEILING, NOT TASTE. Tracking helps short, uppercase,
# isolated strings -- it is how instrument panels have always been lettered --
# and hurts running text, where it breaks the word shapes a reader scans by.
# That is why running text gets TRACK_NONE and only labels get spaced out.

## Running text: sentences, dialogue, anything the player reads as prose.
const TRACK_NONE := 0.0
## Numeric readouts. Uniform per glyph, so a tracked column is still a column.
## Rounds to 0 px below BODY -- honest no-op, kept so the call sites read alike.
const TRACK_READOUT := 0.03
## Field labels and key legends: short, uppercase, one line.
const TRACK_LABEL := 0.06
## The masthead and screen titles. 0.12 em is the letter-spacing value WCAG 2.1
## SC 1.4.12 names as the amount a reader may impose on any text; a header that
## is BUILT at it cannot then break when a reader asks for it.
const TRACK_MASTHEAD := 0.12

# --- LEADING ----------------------------------------------------------------
#
# Multiples of the font size, converted by leading_px() into the extra pixels
# Godot's `line_spacing` (Label) / `line_separation` (RichTextLabel) constants
# want -- those are ADDED to the font's own line box, which is already
# 1.39-1.43x the size, so the helper subtracts before it sets.
#
# One relationship at all six steps is the whole point, and today there is none.
# ui/museum_theme.tres sets no spacing constant, so everything inherits Godot's
# defaults, and those are two different accidents:
#   Label ............ flat +3 px at every size, i.e. 1.67x at CAPTION 12 and
#                      1.46x at DISPLAY 48. The small print is airier than the
#                      title -- the hierarchy runs backwards.
#   RichTextLabel .... +0. Every paragraph the game sets in rich text runs at
#                      the font's bare 1.41x box, under the 1.5x WCAG 2.1
#                      SC 1.4.12 names, and tighter than the plain Labels
#                      beside it. Paragraph separation is +0 too, so
#                      paragraphs do not separate.

## The font's natural line box (~1.40x), no extra. Titles and single lines.
const LEADING_TIGHT := 1.35
## Body copy. 1.5x is the line-height value of WCAG 2.1 SC 1.4.12.
const LEADING_NORMAL := 1.50
## Airy: stacked field labels, legends, anything read as a list not a paragraph.
const LEADING_LOOSE := 1.70

# --- SYSTEM MONOSPACE (opt-in, see the header) ------------------------------

## Probed in order; the first family the OS actually has wins. Windows resolves
## "Consolas", then "Courier New"/"monospace"; Linux the DejaVu/Liberation/Noto
## entries; macOS "SF Mono"/"Menlo". If none lands, SystemFont silently returns
## the stock sans and system_mono() turns that into a null.
const DEFAULT_MONO_NAMES: Array[String] = [
	"Consolas", "Cascadia Mono", "SF Mono", "Menlo",
	"DejaVu Sans Mono", "Liberation Mono", "Noto Sans Mono",
	"Courier New", "monospace",
]

## Stamped on every FontVariation this class builds, holding the font it wraps,
## so re-applying a helper to the same Control re-derives from the ORIGINAL face
## instead of tracking an already-tracked font and doubling the spacing.
const _BASE_META := &"terminal_type_base"

## Keyed "<base instance id>|<tracking px>|<tabular>". A FontVariation is a
## shared resource -- every Label at the same step points at one object -- so
## this is a handful of instances for the whole game, not one per control.
static var _variations: Dictionary = {}
## Keyed by the joined family list; holds a Font or null once probed.
static var _mono_probes: Dictionary = {}


# --- FONT RESOLUTION --------------------------------------------------------

## The face `control` is really drawn in, unwrapped of any variation this class
## put there.
##
## Resolving through the Control rather than through ThemeDB is what made the
## arrival of a real font file a no-op here: ui/museum_theme.tres now carries
## JetBrainsMono.ttf as its default_font and on Label/Button/LineEdit/RichTextLabel
## explicitly, and every ratio below re-derived itself from ITS metrics the moment
## that landed -- no constant in this file names a face. `control` may be null (or
## may be a type with no font item at all, e.g. a bare Control), in which case the
## engine fallback is the answer, and that fallback is still stock Open Sans.
static func base_font(control: Control = null) -> Font:
	var font: Font = null
	if control != null:
		var item := &"normal_font" if control is RichTextLabel else &"font"
		# has_theme_font() first: get_theme_font() on a type that has no such
		# item logs an error rather than returning null.
		if control.has_theme_font(item):
			font = control.get_theme_font(item)
	if font == null:
		font = ThemeDB.fallback_font
	if font is FontVariation and font.has_meta(_BASE_META):
		var base := font.get_meta(_BASE_META) as Font
		if base != null:
			return base
	return font


## The institutional face: fonts/Oswald.ttf, via UITheme.display_font(), which
## also chains it to the mono face for the glyphs Oswald lacks.
##
## Two voices, not one. UITheme's own header hands this file the decision --
## "headings opt into display_font() explicitly through TerminalType, which owns
## the institutional voice" -- so this is where that opt-in lives, and it is
## exactly two helpers: apply_masthead() and apply_heading(). Everything the
## player reads as machine output stays on the monospace, because that is what
## keeps a column a column.
##
## Falls back to whatever `control` resolves if the display face did not load, so
## a missing asset costs the voice and not the screen.
static func display_base(control: Control = null) -> Font:
	var font: Font = UITheme.display_font()
	if font == null:
		return base_font(control)
	return font


## Whole pixels of tracking for `size` at `ratio`. spacing_glyph is absolute
## pixels, so this is where the em fraction becomes a device value.
static func tracking_px(size: int, ratio: float) -> int:
	return maxi(0, roundi(float(size) * ratio))


## Extra pixels to hand Godot's line-spacing constant so that a line of `size`
## occupies `leading` * `size`. Clamped at zero: LEADING_TIGHT lands a hair
## under the font's own box at every step, and a negative value would overlap
## the descenders of one line with the ascenders of the next.
static func leading_px(size: int, leading: float, control: Control = null) -> int:
	return leading_for(base_font(control), size, leading)


## leading_px() against a face that is already resolved.
##
## Separate because the two faces have different line boxes -- Oswald is 1.55x
## its size where JetBrains Mono is 1.40x -- so a heading's leading has to be
## computed from Oswald's metrics, not from the mono metrics its Control would
## report if asked. Measuring the wrong face costs 5 px a line at TITLE 28.
static func leading_for(font: Font, size: int, leading: float) -> int:
	return maxi(0, roundi(float(size) * leading) - roundi(font.get_height(size)))


## The face to draw with, given a tracking ratio and whether figures must line
## up. Returns the base font untouched when neither is asked for, so an
## un-tracked body label allocates nothing.
##
## `display` swaps the base for the institutional face; see display_base().
static func font_for(size: int, ratio: float = TRACK_NONE, tabular: bool = false,
		control: Control = null, display: bool = false) -> Font:
	var base := display_base(control) if display else base_font(control)
	var track := tracking_px(size, ratio)
	if track == 0 and not tabular and not display:
		return base
	var key := "%d|%d|%d" % [base.get_instance_id(), track, int(tabular)]
	var cached := _variations.get(key) as FontVariation
	# Instance ids are recycled after free, so the cached entry is only valid if
	# it still wraps the font we just resolved.
	if cached != null and cached.base_font == base:
		return cached
	var variation := FontVariation.new()
	variation.base_font = base
	variation.spacing_glyph = track
	if tabular:
		# tnum: tabular figures. lnum: lining figures, i.e. not the old-style
		# ones that hop off the baseline. No-ops on all three faces in play --
		# measured, "100%" is 37 px with and without them on Open Sans, and
		# JetBrains Mono is monospaced by construction. See the header for why
		# they are asked for anyway.
		variation.opentype_features = {"tnum": 1, "lnum": 1}
	variation.set_meta(_BASE_META, base)
	_variations[key] = variation
	return variation


## Tracked + tabular face for numbers, at UITheme's `size`.
static func figures(size: int, control: Control = null) -> Font:
	return font_for(size, TRACK_READOUT, true, control)


# --- CASE -------------------------------------------------------------------

## Uppercase, for institutional labels: the masthead, wing names, field labels,
## status words. Everything the building itself would have stencilled.
##
## A function and not `.to_upper()` at the call site, for two reasons. It keeps
## the catalogue authoritative -- a translator writes "Служба ночного
## сдерживания" in sentence case and the UI decides how to letter it, instead of
## SHOUTING being frozen into the CSV where a reviewer cannot tell intent from
## typo. And it is the one place to add a locale exception if one ever appears:
## Godot's to_upper() handles Cyrillic correctly (ё -> Ё), but leaves German ß
## alone ("straße" -> "STRAßE") and would need help for Turkish dotless i.
##
## Uppercase costs width, and Latin costs more of it than Cyrillic: measured at
## size 17, "Первый музей" 126 -> "ПЕРВЫЙ МУЗЕЙ" 137 px (+9%), while
## "Night containment" 155 -> "NIGHT CONTAINMENT" 183 px (+18%). Budget the
## English string, not the Russian one.
##
## Do NOT pass a sentence. All-caps running text is measurably slower to read --
## the word shapes a reader scans by all become rectangles -- and it is the
## first thing an accessibility review flags.
static func institutional(text: String) -> String:
	return text.to_upper()


# --- GLYPH COVERAGE ---------------------------------------------------------
#
# A codepoint the font does not carry is not an error and not a fallback: Godot
# draws .notdef, an empty box, and the build ships with a box in it. It is the
# most expensive class of typographic bug in this project, because it looks
# exactly like a mojibake bug, it survives every test that compares strings, and
# it is invisible to the author of the line if their editor font has the glyph.
#
# The MISSING list in the header is a snapshot of one font. These two functions
# are the version that stays true when the font changes: ask the face that will
# actually draw the string, not a list somebody wrote down.

## True when the font `control` really draws with can render every character of
## `text`. An empty string is trivially renderable.
##
## `control` null asks the engine fallback, which is the right question at a
## const declaration or in a test, where there is no Control yet.
static func has_glyphs(text: String, control: Control = null) -> bool:
	var font := base_font(control)
	for i in range(text.length()):
		if not font.has_char(text.unicode_at(i)):
			return false
	return true


## `preferred` when the font can draw all of it, `fallback` otherwise.
##
## For the case where a nicer symbol exists on some faces and a plain one always
## works: safe_glyph("→", "->") is a one-line way to never ship a box. The
## fallback is not itself checked -- pass something from the present list, or
## from ASCII, which every font in existence carries.
static func safe_glyph(preferred: String, fallback: String,
		control: Control = null) -> String:
	return preferred if has_glyphs(preferred, control) else fallback


# --- APPLY HELPERS ----------------------------------------------------------
#
# Each one is UITheme.apply_text() -- which owns the size, the colour and the
# per-class theme-item quirks -- plus the letterform treatment on top. Colour
# defaults are UITheme tokens whose ratios are tabulated in that file; nothing
# here invents a colour, so nothing here can break the contrast gate.
#
# WHICH VOICE EACH ONE SPEAKS IN. The top two take the display face (Oswald,
# condensed grotesque -- signage); the bottom three stay on the theme's own face
# (JetBrains Mono -- machine output). That split IS the hierarchy now: a heading
# and the paragraph under it no longer differ only in size.
#
# ONE VOICE PER CONTROL. These set a font override, and base_font() unwraps to
# whatever was set last, so alternating helpers on one Label -- apply_heading()
# today, apply_body() tomorrow -- leaves it on the display face. Pick the helper
# that matches what the label IS and call only that one; every call site in the
# game does.

## The masthead: the building's name, a screen title, anything the terminal
## states about itself. The display face, widest tracking, and the caller should
## pass its text through institutional().
static func apply_masthead(control: Control, size: int = UITheme.CAPTION,
		color: Color = UITheme.MUTED) -> void:
	_apply(control, size, color, TRACK_MASTHEAD, LEADING_TIGHT, false, true)


## Panel and section headings. The display face, tracked enough to read as a
## heading rather than as large body text, not so much that it stops being a
## word.
static func apply_heading(control: Control, size: int = UITheme.TITLE,
		color: Color = UITheme.ON_SURFACE) -> void:
	_apply(control, size, color, TRACK_LABEL, LEADING_TIGHT, false, true)


## Field labels, key legends, table headers, status words. Short, uppercase,
## stacked -- hence the loose leading, which is what turns a run of them into a
## legend instead of a paragraph.
static func apply_label(control: Control, size: int = UITheme.LABEL,
		color: Color = UITheme.MUTED) -> void:
	_apply(control, size, color, TRACK_LABEL, LEADING_LOOSE, false)


## Running text: objectives, dialogue, protocol pages, help. No tracking, 1.5
## leading. This is the one helper whose job is to get OUT of the way.
static func apply_body(control: Control, size: int = UITheme.BODY,
		color: Color = UITheme.ON_SURFACE) -> void:
	_apply(control, size, color, TRACK_NONE, LEADING_NORMAL, false)


## A number the player reads as a measurement: a clock, a count, a percentage,
## a core level. Tabular figures and a whisper of tracking.
##
## For anything that CHANGES while it is on screen, call reserve_numeric()
## instead -- this on its own does not stop a growing value from shifting the
## layout under it.
static func apply_readout(control: Control, size: int = UITheme.SECTION,
		color: Color = UITheme.ON_SURFACE) -> void:
	_apply(control, size, color, TRACK_READOUT, LEADING_TIGHT, true)


static func _apply(control: Control, size: int, color: Color, ratio: float,
		leading: float, tabular: bool, display: bool = false) -> void:
	if control == null:
		return
	UITheme.apply_text(control, size, color)
	var font := font_for(size, ratio, tabular, control, display)
	if control is RichTextLabel:
		for item: String in ["normal_font", "bold_font", "italics_font",
				"bold_italics_font", "mono_font"]:
			control.add_theme_font_override(item, font)
	else:
		control.add_theme_font_override("font", font)
	# The font that was just SET, not the one the Control reports: the leading has
	# to be computed against the face the glyphs will be drawn in, and the two
	# faces disagree by 15% of the size on their natural line box.
	_apply_leading(control, font, size, leading)


static func _apply_leading(control: Control, font: Font, size: int,
		leading: float) -> void:
	var extra := leading_for(font, size, leading)
	if control is RichTextLabel:
		control.add_theme_constant_override("line_separation", extra)
		# WCAG 2.1 SC 1.4.12 also names spacing after a paragraph: at least 2x
		# the font size, measured from one baseline block to the next. The
		# constant is the gap ON TOP of a line, so the line's own box comes off.
		var line_box := roundi(font.get_height(size)) + extra
		control.add_theme_constant_override("paragraph_separation",
			maxi(0, size * 2 - line_box))
	elif control is Label:
		control.add_theme_constant_override("line_spacing", extra)
	# Buttons, LineEdits and the rest are single-line by construction and expose
	# no line-spacing constant; there is nothing to set and nothing is wrong.


# --- NUMERIC COLUMNS --------------------------------------------------------

## Width in pixels of `widest` -- the longest string this field will ever show
## -- drawn as a readout at `size`.
##
## MEASURE THE STRING. Do not reconstruct this as digit_width * count: advances
## are fractional and get_string_size() rounds, so at DISPLAY 48 a single "0"
## reports 27.0 while "0000000000" reports 275.0 (27.5 each), and at CAPTION 12
## it reports 7.0 against 69.0 (6.9 each). Per-digit arithmetic is wrong in both
## directions, and tracking widens the gap further, because spacing_glyph falls
## between glyphs: a ten-digit field at DISPLAY 48 measures 284 px against a
## naive 270.
##
## Digits are interchangeable in the template because every one of them has the
## same advance -- "88:88" and "23:59" measure identically -- but separators do
## not: ":" and "." are half a digit wide. Write the real shape.
static func numeric_column_width(widest: String, size: int = UITheme.SECTION,
		control: Control = null) -> float:
	return figures(size, control).get_string_size(
		widest, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Dress `label` as a readout AND pin its geometry so a changing value cannot
## move anything: reserve the width of `widest`, then align right so the last
## digit stays put and only the leading digits come and go.
##
## `widest` is the longest string the field will ever hold -- "88:88" for a
## clock, "100%" for a percentage, "-999" if it can go negative. Any digit will
## do; they are all the same width.
##
## Under-declare it and the field simply grows past the reservation -- measured:
## reserving "88:88" at TITLE pins 76 px for every value up to five characters
## and expands to 93 px for "123:59". That is the right failure: a template that
## is one digit short degrades to today's jitter for that one value, rather than
## clipping a digit off a number the player is being asked to read.
##
## Returns the reserved width so a caller laying out a table can align a whole
## column to the widest of several fields.
##
## This owns `custom_minimum_size.x` on the label it is given; it sets the value
## outright rather than growing it, so re-reserving with a shorter template
## shrinks the field as expected.
##
## Right alignment is the default because it is the only alignment that pins a
## digit rather than a box edge. HORIZONTAL_ALIGNMENT_CENTER is still stable at
## the LAYOUT level once the width is reserved -- the field stops resizing --
## but the digits themselves slide by half a glyph inside it each time the count
## changes, which is visible on a clock and not on a score.
static func reserve_numeric(label: Label, widest: String,
		size: int = UITheme.SECTION, color: Color = UITheme.ON_SURFACE,
		alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT) -> float:
	if label == null:
		return 0.0
	apply_readout(label, size, color)
	label.horizontal_alignment = alignment
	var width := numeric_column_width(widest, size, label)
	label.custom_minimum_size.x = ceilf(width)
	return width


# --- SYSTEM MONOSPACE -------------------------------------------------------
#
# Opt-in and unused. Read the header before wiring it into anything.

## An OS monospace, or null if this machine does not have one of `names`.
##
## SystemFont does not report failure -- ask it for a family that is not
## installed and it hands back the stock sans with the name of the stock sans
## and no error -- so resolution is verified by BEHAVIOUR: a font whose "i",
## "W", "M" and "0" all advance the same distance is monospaced, whatever it
## calls itself. Open Sans measures 5 / 17 / 16 / 10 at size 17 and fails;
## Consolas measures 10 / 10 / 10 / 10 and passes.
##
## The result is cached per family list: the probe costs four string
## measurements and a font load.
static func system_mono(names: Array[String] = DEFAULT_MONO_NAMES) -> Font:
	var families := PackedStringArray(names)
	var key := "|".join(families)
	if _mono_probes.has(key):
		return _mono_probes[key] as Font
	var font := SystemFont.new()
	font.font_names = families
	var resolved: Font = font if _is_monospaced(font) else null
	_mono_probes[key] = resolved
	return resolved


## What this machine would actually give a caller of system_mono(), next to what
## it is using now. For a diagnostic print or a report; it decides nothing.
##
## `line_height` vs `stock_line_height` is the number that matters: they differ
## (24 stock, 18 Consolas, 21 Courier New at BODY), so any layout measured
## against one reflows under the other -- differently on different machines.
static func mono_report(names: Array[String] = DEFAULT_MONO_NAMES) -> Dictionary:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(names)
	var stock := ThemeDB.fallback_font
	return {
		"requested": names,
		"resolved": _is_monospaced(font),
		"family": font.get_font_name(),
		"digit_advance": font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.BODY).x,
		"line_height": font.get_height(UITheme.BODY),
		"stock_family": stock.get_font_name(),
		"stock_digit_advance": stock.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.BODY).x,
		"stock_line_height": stock.get_height(UITheme.BODY),
	}


static func _is_monospaced(font: Font, size: int = UITheme.BODY) -> bool:
	if font == null:
		return false
	var digit_width := font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if digit_width <= 0.0:
		return false
	for glyph: String in ["i", "W", "M", "l", "."]:
		if not is_equal_approx(font.get_string_size(
				glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, digit_width):
			return false
	return true
