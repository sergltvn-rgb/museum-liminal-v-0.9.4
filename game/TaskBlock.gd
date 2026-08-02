class_name TaskBlock
extends CanvasLayer
## The one place the game says what to do now.
##
## THE BUG THIS EXISTS TO KILL
##
## The owner's first complaint is "непонятно, что делать сейчас". It is not a
## wording problem, it is a layout problem: the answer was spread over seven
## controls in five corners, each owned by a different file and each on its own
## CanvasLayer.
##
##   objective line ..... GameManager, layer 5, anchors x 0.01..0.62 / y 0.10..0.19
##   timer .............. GameManager, layer 5, x 0.40..0.60 / y 0.02..0.10
##   hint ............... GameManager, layer 5, x 0.10..0.90 / y 0.90..0.98
##   flash message ...... GameManager, layer 5, x 0.10..0.90 / y 0.40..0.52
##   stamina ............ PlayerController, layer 14, bottom-left, fixed 260x58
##   anomaly readout .... GameplayEnhancements, layer 11, x 0.72..0.98 / y 0.02..0.16
##   trial HUD .......... RiftTrialManager, layer 30, its own panel stack
##
## Five of those seven can be on screen at once. None of them is louder than the
## others by more than one type step, so nothing tells the eye where to start,
## and the two that matter most -- the sentence and the clock -- are 0.30 of the
## screen apart with unrelated text between them.
##
## The measured collision: the objective band sat at y 0.01 for most of the
## project's life, i.e. x 16..992 / y 9..90 on a 1600x900 canvas, while
## SecurityCameraTablet prints its feed name at (52, 18) in 30 px on layer 10.
## The one objective that names a camera (OBJ_CCTV_CONFIRM) is the one the
## player reads with the tablet up, so the sentence naming the camera was
## printed underneath the camera's own name, glyph over glyph. GameManager
## worked around it by moving the band down to y 0.10. That fix is correct and
## incomplete: the tablet draws no opaque backing, so the two runs of text still
## share a transparent screen and only luck keeps them apart at other aspect
## ratios.
##
## This block fixes the class of bug rather than the instance. It owns an opaque
## panel, so overlap is resolved by z-order instead of by hoping; it sits above
## every screen a live shift can raise, so it is legible with the tablet up; and
## it is one control tree, so "what to do now" cannot drift away from "how long
## is left" again.
##
##
## THE HIERARCHY, TOP TO BOTTOM
##
##   1. the sentence ... TITLE 28, stepping to SECTION 21 when the sentence is
##                       too long for the column, ON_SURFACE, wrapped in full and
##                       NEVER ellipsised. The loudest text the game draws outside
##                       a full-screen card, and the only thing in the block that
##                       is a sentence rather than a value. See "SLOT 1 IS NEVER
##                       TRUNCATED" below -- it used to be cut off mid-word at
##                       every shipping resolution, which is the one failure this
##                       file cannot have.
##   2. the countdown .. SECTION 21 -> TITLE 28 when urgent, and BODY 17 when
##                       slot 1 has stepped down to SECTION -- the clock stays a
##                       step quieter than the sentence it belongs to. Directly
##                       under the sentence, because it is that sentence's
##                       deadline.
##   3. the hint ....... LABEL 14, MUTED. Half the sentence's size and a
##                       dimmer token: subordinate in size AND in weight, so it
##                       reads as a footnote to the task, never as a rival to it.
##                       WHAT A KEYPRESS DOES RIGHT NOW.
##   4. the status ..... CAPTION 12, MUTED. One line of state: what the world is
##                       currently doing to the operator. No bar, because none of
##                       the rows that stand here is a 0..1 ratio.
##   5. progress ....... CAPTION 12 caption over a 6 px bar. A value about the
##                       OPERATOR, not a message.
##
## Rows 3, 4 and 5 read "act / world / you" top to bottom, which is also their
## order of consequence: only row 3 changes what a key does.
##
## Transient messages do not fly past on their own layer any more; they take
## over slot 1 for FLASH_SECONDS and hand it back. See "ONE PRIMARY LINE" below.
##
##
## ONE PRIMARY LINE -- ENFORCED, NOT REQUESTED
##
## The rule is that at most one loud line exists at any instant. It is enforced
## structurally, in three places, so a caller cannot break it by accident:
##
##   * there is exactly one Label for slot 1 (`_primary`) and `_render_primary()`
##     is its only writer. `set_task()` and `flash()` do not own a Label each;
##     they own two fields that the same renderer resolves, flash first.
##   * `_one_line()` collapses newlines out of every string that reaches slot 1,
##     so "line one\nline two" cannot smuggle a second primary line in.
##   * the Label carries no line cap and no ellipsis. A long sentence is fitted
##     by stepping the TYPE SIZE down, not by cutting words off; "one primary
##     line" is a rule about how many things shout at once, and it was never a
##     licence to throw half the sentence away. See the next section.
##
## A flash therefore displaces the standing task for a moment instead of joining
## it. That is deliberate: an event that just happened IS what the player needs
## to read right now, the standing task is never lost (it is held in
## `_task_text` and restored automatically), and the alternative -- a second
## loud line -- is the exact defect this file was written to remove.
##
##
## SLOT 1 IS NEVER TRUNCATED -- MEASURED, NOT ASSERTED
##
## This file was written to answer "what do I do now" and it was cutting the
## answer off mid-sentence. Slot 1 carried `max_lines_visible = 2` with
## OVERRUN_TRIM_WORD_ELLIPSIS in a 353 px column (ANCHOR_RIGHT was 0.255), and
## TITLE 28 in that column is about 20 characters of Russian a line.
##
## Measured with the shipping font, over the 17 strings that can stand in slot 1
## as an objective (9 OBJ_*, 8 TEACH_OBJ_*), formatted with the longest arguments
## the game can supply -- EXHIBIT_ENDLESS_HOURGLASS, "Бесконечные песочные часы",
## 25 characters -- at the old geometry:
##
##   ru ... 14 of 17 ellipsised.  en ... 15 of 17 ellipsised.
##   worst: OBJ_INCIDENT and OBJ_INCIDENT_EXHIBIT, 121 and 122 characters, wrap
##          to EIGHT lines of TITLE 28. Two were shown. The player was told
##          "АВАРИЯ: Бесконечные песочные часы. Найдите..." and never learned
##          that the sentence goes on to name the protocol, the stabilizer and
##          the exhibit, which is the entire content of the instruction.
##
## THE THREE RESOLUTIONS, AND WHY THEY ALL SHOW THE SAME THING. project.godot
## sets stretch mode "canvas_items" with aspect "expand" over a 1600x900 base, so
## a 16:9 window of ANY size resolves to a 1600x900 canvas and only the
## rasterisation scale changes. Verified by building the block and resizing the
## root window:
##
##   window        canvas       raster scale   panel     slot 1 column
##   1920 x 1080   1600 x 900   1.20           681.6 px  649 px
##   1600 x  900   1600 x 900   1.00           681.6 px  649 px
##   1280 x  720   1600 x 900   0.80           681.6 px  649 px
##
## So "it ellipsises at 1080p and below" was really "it ellipsises, full stop" --
## every 16:9 resolution had the identical layout and the identical defect, and a
## fix that only worked at one of them would have been no fix at all.
##
## WHAT EACH OF THE THREE SHOWS NOW. Identical at all three, by the same
## arithmetic, and truncation is impossible at any of them because the Label
## carries no line cap and OVERRUN_NO_TRIMMING:
##
##   OBJ_INCIDENT ......... 121 ch, TITLE 28 needs 4 lines -> SECTION 21, 3 lines
##   OBJ_INCIDENT_EXHIBIT . 122 ch, TITLE 28 needs 4 lines -> SECTION 21, 3 lines
##   OBJ_CCTV_CONFIRM ..... 97 ch,  TITLE 28, 3 lines
##   TEACH_OBJ_PROTOCOL ... 73 ch,  TITLE 28, 3 lines
##   OBJ_CORE_UNSTABLE .... 67 ch,  TITLE 28, 3 lines
##   OBJ_TRIAL ............ 58 ch,  TITLE 28, 2 lines
##   OBJ_NIGHT_INTRO ...... 56 ch,  TITLE 28, 2 lines
##   OBJ_BLACKOUT ......... 47 ch,  TITLE 28, 2 lines
##   OBJ_NIGHT_RESTART .... 38 ch,  TITLE 28, 1 line
##
##   17 of 17 fully readable, in both locales. Two step down in Russian, one in
##   English; the other 15 keep TITLE 28. Widened to the whole set of 120 strings
##   that can reach slot 1 (objectives, teaching lines and every trial line),
##   still 0 truncated, and the panel's worst height is 144 px of a 900 px canvas.
##
## The room came from three places and the order matters: the column went from
## 353 px to 649 px (ANCHOR_RIGHT 0.255 -> 0.44, and the constraint that set
## 0.255 no longer exists -- see GEOMETRY), the line cap and the ellipsis are
## gone, and only then does a size step exist as a last resort. Trimming was
## never a fit strategy; it is the failure to have one.
##
##
## ONE OWNER PER SLOT -- ENFORCED, WITH A SLOT FOR EVERY SPEAKER
##
## The one-primary-line rule stopped at slot 1 and the lower slots paid for it.
## Measured live on the museum path, before this section was wired:
##
##   slot 3, the hint ..... GameManager._update_hint() writes it every frame
##                          (the interaction prompt: "press E to apply the
##                          stabilizer"). GameplayEnhancements._update_readouts()
##                          ALSO wrote it every frame for the whole of every
##                          anomaly (the CCTV scan percentage, then the carried
##                          tool's distance line).
##   slot 4, the progress . GameManager._sync_status_slot() writes it every frame
##                          (stamina, else the carried device).
##                          GameplayEnhancements._update_readouts() ALSO wrote
##                          it every frame for the whole of every anomaly (the
##                          HUD_EFFECT_* readout).
##
## Two per-frame writers, no arbitration: whichever node's `_process` ran later
## in the frame won, and which that is was decided by node order in a scene tree
## neither file builds. GameplayEnhancements sits after GameManager in
## scenes/FirstMuseumMap.tscn, so it always won, and its fallback branches call
## set_hint("") and set_progress(-1.0) outright. The measured effect was that the
## carry prompt and the stamina gauge were erased for the whole of every anomaly,
## silently, with no error anywhere:
##
##   slot 3  "В руках: Нуль-фонарь (G - бросить)"
##             -> "НУЛЬ-ФОНАРЬ: Куратор замедлен рядом с вами"
##   slot 4  "В руках: Нуль-фонарь"     -> "ГРАВИТАЦИЯ: 100%"
##
## An ownership lock alone does not fix that. Four slots and three systems is a
## shortage, and a lock over a shortage just decides which system loses -- make
## GameManager win instead and the anomaly readout vanishes, which is the same
## bug pointing the other way. So the shortage is removed first and the lock is
## applied second.
##
## THE RULING. Five slots, one owner each, and the owner is a LOCK rather than a
## priority. Nothing is shared and nothing alternates:
##
##   slot 1  &"night_hud"   GameManager. It already multiplexes four sources
##                          (game / incident / cctv / trial) through
##                          set_objective(source, text, priority) and picks a
##                          winner; that registry is the arbitration, and a
##                          second writer of the Label would defeat it. This is
##                          why RiftTrialManager._say() publishes into that
##                          registry instead of writing the block: the trial's
##                          standing line reaches slot 1 THROUGH the one owner.
##   slot 2  &"night_hud"   GameManager owns the incident clock. It keeps running
##                          inside a pocket dimension, so the trial never takes
##                          this one.
##   slot 3  &"night_hud"   THE INTERACTION PROMPT. The only text in the block
##                          whose absence changes what a keypress does, so it is
##                          never displaced by telemetry. Handed to &"trial" for
##                          the duration of a pocket dimension, where the trial's
##                          teaching row is the thing that says how to act.
##   slot 4  &"anomaly"     GameplayEnhancements, while an incident is live: the
##                          effect readout, or the CCTV scan percentage when a
##                          scan is pending -- the anomaly picks between its own
##                          two lines inside its own slot, preferring the one
##                          with a deadline. Handed to &"trial" inside a pocket
##                          dimension, which names the dimension here. Free, and
##                          therefore blank, on a calm night.
##   slot 5  &"night_hud"   GameManager. Stamina while it is being spent, else
##                          the carried device -- during an incident the device's
##                          own HUD_TOOL_* line, which says what the tool is
##                          doing as well as naming it. This slot is about the
##                          OPERATOR, so it survives both an anomaly and a trial.
##
## What that buys, measured (see the probe transcript in the report that landed
## this change): during an anomaly the carry prompt stands in slot 3, the effect
## readout stands in slot 4 and the stamina gauge stands in slot 5, all at once,
## and none of the three is ever blanked by another system.
##
## THE HANDSHAKE. Two boundaries, both explicit, both two-sided:
##
##   incident  GameplayEnhancements claim()s slot 4 in _begin_anomaly() and
##             release()s it in _end_anomaly(). Nothing else ever writes it.
##   trial     GameManager._begin_trial() release()s slot 3 and tells the anomaly
##             to stand down (release_readouts()) BEFORE it calls begin(), so the
##             trial's claim() lands on free slots on the same frame rather than
##             racing the two systems it is replacing. RiftTrialManager gives
##             both back in _release_task_block(), which calls release() -- not
##             set_hint("") -- because an empty string is a thing an owner says.
##
## HOW THE LOCK BEHAVES
##
##   * `owner_id` is REQUIRED on all five setters. There is no default and no
##     anonymous branch: an API that lets a caller opt out of the protection it
##     advertises is the defect, not the migration path. Passing OWNER_NONE is a
##     push_error and the write is dropped.
##   * the first write carrying an owner LEASES that slot. The lease is held
##     until the holder calls `release()`, or until `clear()` drops every lease at
##     a night boundary. It is NOT dropped by writing an empty string: "I own this
##     slot and have nothing to say right now" is a real state, and letting a
##     blank frame open the slot to anyone is how the race gets back in through
##     the window.
##   * a write from anyone else is REFUSED and reported through `push_error()`
##     and the `slot_conflict` signal, once per offending pair so a per-frame
##     caller cannot flood the log. Refused, not obeyed: the block would rather
##     show one system's answer than alternate between two.
##   * `flash()` is exempt and takes no owner. It is not a second writer of
##     slot 1 -- it queues, dwells and hands the line back (see above), which is
##     arbitration rather than a race, and every system is allowed to report an
##     event.
##
##
## URGENCY WITHOUT COLOUR
##
## A red clock is invisible to a deuteranope and to anyone playing on a washed
## out panel, which is most of this game's audience. Urgency is therefore
## carried on five channels at once, only one of which is hue:
##
##   size ....... the countdown steps SECTION 21 -> TITLE 28.
##   glyph ...... a bordered "!" chip appears to its left. A shape, not an icon,
##                and not an emoji.
##   position ... the countdown moves from the right edge of its row to the left,
##                into the reading path directly under the sentence's first
##                character. The row's spacer is what moves; see `_apply_urgency`.
##   rate ....... under URGENT_TENTHS seconds the readout switches to tenths, so
##                the digits visibly start moving ten times faster.
##   border ..... the block's own border goes 1 px BORDER -> 2 px WARNING. Width
##                is a shape channel; the colour rides along on top of it.
##
## Remove hue entirely and four channels still say "hurry".
##
##
## MOTION
##
## The block animates exactly one thing: the urgency chip breathes once per
## second, in step with the countdown. Nothing else moves -- no fades, no
## slides, no attract loop. A flash cuts in and cuts out, because a cross-fade
## on a message that is already only a couple of seconds long communicates
## nothing and costs contrast for the whole fade.
##
## `SettingsManager.reduced_flashes` holds the chip at its bright end, steady.
## The lookup is the project's established one -- group `settings_manager`,
## null-guarded, field read through `.get()`, polled -- matching
## SecurityCameraTablet._reduced_flashes(), GameplayEnhancements._update_watch()
## and FirstMuseumMap._process. It is polled only while the countdown is urgent.
##
## Note that the beat is 1 Hz, an order below the 3 Hz photosensitivity
## threshold, and it modulates a chip's FILL, never text alpha: pulsing the
## alpha of a glyph run is the usual way an "accessible" pulse quietly drops
## text under 4.5:1 for half of every cycle.
##
##
## CONTRAST -- COMPUTED, NOT EYEBALLED
##
## WCAG 2.1, same method as the table in game/UITheme.gd. Everything here sits
## on SURFACE_RAISED (the block's own fill), which is what makes the numbers
## knowable at all -- the labels this replaces were drawn straight onto the 3D
## museum and had to wear black outlines because their background was "whatever
## the player happens to be looking at".
##
##   slot 1, standing task .... ON_SURFACE on SURFACE_RAISED ...... 11.99 : 1
##   slot 1, flash INFO ....... ON_SURFACE ......................... 11.99 : 1
##   slot 1, flash GOOD ....... SUCCESS ............................. 8.02 : 1
##   slot 1, flash WARN ....... WARNING ............................. 6.55 : 1
##   slot 1, flash BAD ........ DANGER .............................. 5.28 : 1
##   countdown, normal ........ ON_SURFACE ......................... 11.99 : 1
##   countdown, urgent ........ WARNING ............................. 6.55 : 1
##   hint ..................... MUTED ............................... 6.30 : 1
##   status line .............. MUTED ............................... 6.30 : 1
##   progress caption ......... MUTED ............................... 6.30 : 1
##
## The chip is the only place where text sits on something that moves. Its fill
## is WARNING at CHIP_FILL_LOW..CHIP_FILL_HIGH alpha over SURFACE_RAISED, so the
## backing travels #3b3b3b -> #55483d across the beat:
##
##   chip glyph, ON_SURFACE ... 10.00 : 1 at the dim end, 7.87 : 1 at the bright
##
## The chip glyph is ON_SURFACE and not WARNING for exactly this reason: WARNING
## on its own wash falls to 4.30 : 1 at the bright end of the beat -- a token
## losing a gate against a tint of itself, which is the failure mode nobody
## checks for.
##
## Non-text: the progress fill is ACCENT on a SURFACE track, 8.78 : 1, far past
## the 3 : 1 a graphical object needs; the urgent border is WARNING on
## SURFACE_RAISED, 6.55 : 1.
##
## Nothing in the block is focusable -- it is a readout, it accepts no input and
## every control in it is MOUSE_FILTER_IGNORE -- so the focus-ring rule has
## nothing to apply to here. If a control is ever added, it goes through
## UITheme.apply_button(), which brings the ring with it.
##
##
## CALLERS PASS KEYS, NEVER TEXT
##
## Every entry point takes a catalogue key plus optional format arguments and
## resolves it through Loc.fmt(), which degrades instead of aborting when a row
## is missing or a translator drops a specifier (see game/Loc.gd). No player
## visible literal exists in this file; the only strings it owns are four
## punctuation marks used as shape markers.
##
##
## HOW A CALLER MIGRATES
##
##     var block := TaskBlock.new()
##     add_child(block)
##     block.set_task("OBJ_TRIAL", [], TaskBlock.OWNER_NIGHT)
##     block.set_timer(_time_left, _time_left < 30.0, TaskBlock.OWNER_NIGHT)
##     block.set_hint("HUD_HINT_APPLY", [tool_name], TaskBlock.OWNER_NIGHT)
##     block.claim(TaskBlock.Slot.STATUS, TaskBlock.OWNER_ANOMALY)
##     block.set_status("HUD_SCAN_ARCHIVE", [], TaskBlock.OWNER_ANOMALY)
##     block.set_progress(stamina, "HUD_STAMINA", [], TaskBlock.OWNER_NIGHT)
##     block.flash("HUD_ANOMALY_CLEARED", [], TaskBlock.Tone.GOOD)
##     block.release(TaskBlock.Slot.STATUS, TaskBlock.OWNER_ANOMALY)
##
## The owner is the last argument of all five `set_*` calls and it is REQUIRED:
## there is no default, so a caller that has not decided who it is does not
## compile. That is deliberate -- the previous revision of this file shipped the
## whole lease with a default of OWNER_NONE, every call site took the default,
## and the protection was dead code that read like a guarantee.
##
## and, at a terminal screen (fail, win, ending, pause), `block.set_suspended(true)`
## rather than reaching into `visible` -- the block manages `visible` itself, see
## `_refresh_visibility()`.


# --- THE CANVAS LAYER SCALE FOR THE WHOLE GAME ------------------------------
#
# Layer collisions are the root cause of the defect this file fixes, so the
# ladder is written down here in full. The decade scale below is no longer a
# proposal: it is what the project assigns today, verified by reading every
# `CanvasLayer.new()` in game/ (there are eleven) and every `.layer =` next to
# them. Where a file still carries a number from the old packed 5..17 ladder it
# is marked STALE with its actual value, so this table never lies by omission.
#
#   000-099  world-anchored diegetic surfaces, and anything that predates the
#            scale
#              6  compass / floor plan ... game/Compass.gd HUD_LAYER
#                 STALE: the ladder's slot for it is 110. Harmless -- 6 and 110
#                 are both under this block and over nothing -- so it is a
#                 rename, not a fix.
#   100-199  the live shift HUD: everything that describes the current task
#            110  (reserved for the compass, see above)
#            199  TASK BLOCK ............. here, TASK_LAYER. GameManager
#                 (HUD_TASK_LAYER), GameplayEnhancements and RiftTrialManager all
#                 name the same 199 for the block they build or adopt.
#   200-299  screens the player raises and can put down
#            200  (reserved for the CCTV tablet)
#             10  CCTV tablet ............ game/SecurityCameraTablet.gd
#                 STALE: belongs at 200. Currently BELOW this block, which is the
#                 intended order anyway -- the block must stay legible with the
#                 feed up -- so it reads correctly today by luck rather than by
#                 arithmetic.
#            210  protocol screen ........ GameManager SCREEN_LAYER
#   300-399  in-world alarms drawn over those screens
#            320  Curator proximity alert  GameplayEnhancements WATCH_ALERT_LAYER
#   400-499  takeovers that end the incident
#            410  cutscene overlay ....... game/Cutscene.gd OVERLAY_LAYER
#                 Under the fail and win pages: the opening has an empty HUD
#                 to play over. _play_ending() promotes the ending's copy to
#                 430, one rung over the win curtain it replaces.
#            420  fail / win pages ....... GameManager OVERLAY_LAYER
#            430  ending cutscene ........ GameManager ENDING_LAYER
#   500-589  the trial / pocket-dimension HUD
#            510  trial terminal frame ... RiftTrialManager TRIAL_FRAME_LAYER
#   590-599  the one takeover that must also cover a trial
#            590  Curator catch veil ..... GameplayEnhancements DEATH_LAYER.
#                 It fades OFF to uncover the fail page, so it has to sit above
#                 the page it hands off to as well as above the trial frame.
#   600-699  menus and pause
#            610  main menu / pause ...... MenuManager MENU_LAYER
#   700-799  the tutorial replay
#            710  (reserved for the prologue)
#             40  tutorial prologue ...... game/TutorialPrologue.gd
#                 STALE: belongs at 710. Beats the night HUD's old 5 but loses to
#                 this block's 199, which is wrong -- the prologue is a takeover
#                 and the shift's task line has nothing to say during it. The
#                 prologue is not on screen while a shift runs, so nothing is
#                 broken today; renumbering it to 710 is the fix.
#   900-999  debug
#            960  F9 service console ..... GameManager DEBUG_LAYER
#
# WHERE THE TASK BLOCK SITS AND WHY. 199 is the TOP of the live-shift band and
# the bottom of nothing: it must beat every other thing the shift itself draws,
# and it must lose to every screen the player raises (tablet, protocol) and to
# every screen that takes the game away (fail, win, ending, trial frame, catch
# veil, pause). The old TASK_LAYER = 17 satisfied none of that -- it was chosen
# by exhaustion, because 5..16 was packed solid and 12 was issued twice -- and
# every construction site in the project had to overwrite it on the next line.
# It is 199 here now, so the value the block parks itself at is the value the
# game wants and the overwrite is belt-and-braces rather than load-bearing.
#
# Decades leave room to insert without renumbering, which is the property the
# old ladder lacked and the reason it collided. The block also does not depend on
# z-order to stay readable: it owns an opaque panel, and it occupies a rectangle
# nothing else claims (the compass is bottom-right, see the anchors below).
const TASK_LAYER := 199

# --- GEOMETRY ---------------------------------------------------------------
#
# Fractional anchors, not fixed pixels: everything the block has to avoid is
# anchored fractionally too, so a pixel rectangle would only be correct at one
# resolution.
#
# ANCHOR_TOP clears the tablet's header row. SecurityCameraTablet puts its REC
# dot at (24, 28) and its feed name at (52, 18) in 30 px type, so that band ends
# at 58 px of 900 = 0.064. 0.085 leaves 24 px of air under it at 900p and scales.
#
# ANCHOR_RIGHT used to be 0.255, "the protocol screen's left edge, which
# GameManager anchors at 0.26". That constraint no longer exists: the protocol
# briefing is a game/TerminalFrame.gd page and sets PRESET_FULL_RECT, so there is
# no 0.26 edge to stop at, and it is 210 on the ladder above -- it covers this
# block outright rather than sitting beside it. The narrowness outlived its own
# reason and cost the block the thing it exists to deliver: 0.241 of a 1600-wide
# canvas is a 385.6 px panel and a 353 px text column, in which 14 of the 17
# objective strings in the catalogue did not fit in the two lines of TITLE 28
# they were capped at (15 of 17 in English). See "SLOT 1 IS NEVER TRUNCATED" in
# the header for the full measurement.
#
# 0.44 gives the sentence 649 px of column on the same canvas. What still
# bounds it:
#   * it stays under half the canvas, so it is a corner panel and not a banner --
#     the block covers the top-left of whatever is behind it and no more;
#   * the compass, the only other thing the live shift draws, is anchored
#     BOTTOM_RIGHT (game/Compass.gd, PRESET_BOTTOM_RIGHT), so the two cannot
#     meet at any aspect ratio;
#   * every screen it can share the frame with is full-rect and above it on the
#     ladder, so width costs nothing there either.
#
# The bottom is deliberately unanchored -- anchor_bottom == anchor_top with a
# zero offset gives a zero-height rect, which Control clamps up to the content's
# combined minimum size. The block is exactly as tall as what it is showing, so
# an empty hint row costs nothing.
const ANCHOR_LEFT := 0.014
const ANCHOR_TOP := 0.085
const ANCHOR_RIGHT := 0.44

# --- SLOT 1 FIT -------------------------------------------------------------
#
# The sentence is fitted by type size, never by ellipsis. Two steps, and the
# large one is what almost every objective in the catalogue gets.
#
# The step-down is one full step of the UITheme scale, not a 10% nudge: 28 -> 21
# is visibly a different size, which is the point -- the block should read as
# "this is a long instruction", not as "the font is subtly wrong today".

## Slot 1's normal size, and the size it steps to when the sentence does not fit
## PRIMARY_COMFORT_LINES lines of it. There is no third step: at SECTION 21 the
## longest string in the catalogue fits, and a step to BODY 17 would put the
## sentence level with the body text of every other screen in the game.
const PRIMARY_SIZE_LARGE := UITheme.TITLE
const PRIMARY_SIZE_SMALL := UITheme.SECTION
## Lines of PRIMARY_SIZE_LARGE the block will grow to before stepping down.
## Three lines of TITLE is a tall panel but still a sentence; four is a
## paragraph, and a paragraph in the corner of the screen is not read.
const PRIMARY_COMFORT_LINES := 3
## Line-breaking flags matching TextServer.AUTOWRAP_WORD_SMART, so the line count
## measured off the font is the line count the Label will actually lay out.
##
## These are the flags Label itself passes for WORD_SMART: mandatory breaks, word
## boundaries, the adaptive fallback for a word longer than the column, and edge
## spaces trimmed. Verified over 480 measurements (every objective, teaching and
## trial row in the catalogue, both locales, both type steps): predicted line
## count equals Label.get_line_count() in every one. BREAK_GRAPHEME_BOUND, the
## obvious-looking third flag, is NOT one of them -- it breaks mid-word and
## disagreed 15 times, always by under-counting, which is the direction that
## would have left the sentence too big for its column.
const WRAP_BREAK_FLAGS := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND \
	| TextServer.BREAK_ADAPTIVE | TextServer.BREAK_TRIM_EDGE_SPACES
## Slots 3 and 4 keep a cap, because a footnote is a footnote and an unbounded
## one is how the block becomes the wall of text it replaced. Measured across
## every row the catalogue can put in either (HUD_HINT_*, HUD_EFFECT_*,
## HUD_TOOL_*, HUD_SCAN_*, TUT_HINT_*,
## TEACH_HINT_* and the trials' tutorial rows, both locales, longest arguments):
## none reaches three lines of LABEL 14 in the 649 px column, so the cap never
## bites and no hint is ellipsised either.
const HINT_MAX_LINES := 3

## Gap between the five slots. Tighter than UITheme.PAD_Y so the block reads as
## one object; the type-size ladder is what separates the slots, not whitespace.
const SLOT_GAP := 6
## Height of the progress bar. Slim enough to read as a gauge rather than as a
## fifth message.
const BAR_HEIGHT := 6

# --- TIMING -----------------------------------------------------------------

## How long one transient message holds slot 1. Shorter than the 3.0 s the old
## free-flying message label used, because this one displaces the standing task
## while it is up and must give it back promptly.
const FLASH_SECONDS := 2.4
## Messages waiting behind the one on screen. Past this the OLDEST pending entry
## is dropped: in a backlog the newest event is the one that still describes the
## player's situation, and a queue that drains for ten seconds after the fact is
## just noise with a delay.
const FLASH_QUEUE_MAX := 3
## Seconds per urgency beat. 1 Hz -- in step with the countdown, and an order of
## magnitude under the 3 Hz photosensitivity threshold.
const BEAT_SECONDS := 1.0
## Below this many seconds the countdown switches to tenths.
const URGENT_TENTHS := 10.0

# --- CHIP FILL --------------------------------------------------------------
# WARNING alpha over SURFACE_RAISED, the two ends of the beat. Both ends are
# contrast-checked against the chip's ON_SURFACE glyph in the header: 10.00 : 1
# and 7.87 : 1. Raising CHIP_FILL_HIGH past roughly 0.45 is what would break the
# gate.
const CHIP_FILL_LOW := 0.10
const CHIP_FILL_HIGH := 0.22

## Marker glyphs. Shapes, so tone survives greyscale; all four are Latin-1, so
## they exist in any font the engine can fall back to, and none is an emoji.
## The STANDING TASK carries no marker at all -- absence of a glyph is itself
## the signal that slot 1 is showing the objective rather than an event.
const MARK_INFO := "·"
const MARK_GOOD := "+"
const MARK_WARN := "!"
const MARK_BAD := "×"

## Severity of a transient message. Passed by callers; drives both the colour
## and the marker glyph, never the colour alone.
enum Tone {
	INFO,
	GOOD,
	WARN,
	BAD,
}

# --- SLOT OWNERSHIP ---------------------------------------------------------
#
# See "ONE OWNER PER SLOT" in the header for the ruling and the reasoning. This
# is the mechanism.

## The five slots, as the API names them. `release()`, `claim()`, `slot_owner()`
## and the `slot_conflict` signal all speak in these.
enum Slot {
	PRIMARY,   ## The sentence. Also what a flash() displaces, transiently.
	TIMER,     ## The countdown.
	HINT,      ## How to carry the sentence out. What a keypress does.
	STATUS,    ## One line of state: what the world is doing to the operator.
	PROGRESS,  ## One measured quantity about the operator, with or without a bar.
}

## Not an owner. Kept as the "free slot" marker that `slot_owner()` returns and
## `_slot_owner` misses resolve to; passing it to a setter is a caller bug and is
## reported. It is NOT a default -- see "HOW THE LOCK BEHAVES" in the header.
const OWNER_NONE := &""
## The three systems that write this block, spelled once so the callers cannot
## drift apart on a string literal. GameManager, GameplayEnhancements and
## RiftTrialManager each pass exactly one of these.
const OWNER_NIGHT := &"night_hud"
const OWNER_ANOMALY := &"anomaly"
const OWNER_TRIAL := &"trial"

## Two systems want the same slot. Emitted once per offending pair, alongside the
## push_error, so a test can assert on the defect instead of reading the log.
signal slot_conflict(slot: Slot, holder: StringName, intruder: StringName)

var _panel: PanelContainer = null
## The ONE loud line. See "ONE PRIMARY LINE" in the header before adding another.
var _primary: Label = null
var _timer_row: HBoxContainer = null
var _timer_spacer: Control = null
var _chip: Label = null
var _timer: Label = null
var _divider: ColorRect = null
var _hint: Label = null
var _status: Label = null
var _progress_caption: Label = null
var _progress_bar: ProgressBar = null

var _panel_style: StyleBoxFlat = null
var _panel_style_urgent: StyleBoxFlat = null
var _chip_style: StyleBoxFlat = null
var _bar_fill: StyleBoxFlat = null

## Resolved text, not keys: the catalogue lookup happens once per call rather
## than once per frame, and a locale switch is a fresh set_* from the caller.
var _task_text := ""
var _hint_text := ""
var _status_text := ""
var _flash_text := ""
var _flash_tone := Tone.INFO
var _flash_left := 0.0
var _flash_queue: Array[Dictionary] = []

var _timer_seconds := -1.0
var _urgent := false
var _beat := 0.0

var _progress_ratio := -1.0
var _progress_text := ""

var _suspended := false

## The size slot 1 is currently drawn at: PRIMARY_SIZE_LARGE, or the small step
## when the sentence did not fit. The countdown reads it so it can stay a step
## quieter than the sentence it belongs to.
var _primary_size := PRIMARY_SIZE_LARGE

## Slot -> StringName. A missing key is a free slot. Only `_accept()`, `claim()`,
## `release()` and `clear()` write it.
var _slot_owner := {}
## Conflict signatures already reported. A contended slot is written every frame,
## so without this the first second of an anomaly would be six hundred identical
## errors and the log would be the new place the defect hides.
var _conflicts_reported := {}


func _ready() -> void:
	name = "Task Block"
	layer = TASK_LAYER
	# Pausable, not ALWAYS: a message must not burn its two seconds behind the
	# pause menu, and the urgency beat must not keep breathing over a frozen
	# game. The parent may well be PROCESS_MODE_ALWAYS, so this is set rather
	# than inherited.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build()
	# The fit in _render_primary() is measured against the canvas width, so a
	# window resize (or a change of aspect ratio, which is what actually moves the
	# canvas under "canvas_items" + "expand") has to re-run it. Cheap: one font
	# measurement of one string, only when the viewport actually changes.
	# Guarded: a block that is removed and re-added with request_ready() would
	# otherwise connect twice, which Godot reports as an error.
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_render_primary):
		viewport.size_changed.connect(_render_primary)
	_render_primary()
	_render_timer()
	_render_hint()
	_render_status()
	_render_progress()
	_apply_urgency()
	_refresh_visibility()


# --- PUBLIC API -------------------------------------------------------------
#
# Six calls, all of them taking catalogue KEYS. Passing an already-translated
# string is a bug: it defeats Loc.fmt()'s degradation and it freezes the text at
# the locale that was live when the caller ran.
#
# The five `set_*` calls take a trailing `owner_id` and it has NO DEFAULT. Naming
# yourself leases the slot and makes any other writer a visible error instead of a
# silent winner; see "ONE OWNER PER SLOT" in the header. `flash()` takes none,
# because it queues rather than overwrites.


## Slot 1: the single sentence answering "what do I do now".
##
## Replaces whatever was there. An empty key clears it -- the block then shows
## nothing in slot 1 unless a message is passing through, and hides itself
## entirely if the other slots are empty too. Clearing does NOT drop the lease;
## `release()` does.
func set_task(key: String, args: Array, owner_id: StringName) -> void:
	var text := _one_line(key, args)
	# Ownership is checked before the no-change guard on purpose: a second writer
	# that happens to be writing the same sentence this frame is still a second
	# writer, and it will not be next frame.
	if not _accept(Slot.PRIMARY, owner_id, text):
		return
	if text == _task_text:
		return
	_task_text = text
	_render_primary()
	_refresh_visibility()


## Slot 2: the deadline attached to slot 1.
##
## `seconds` below zero hides the row; callers that used to set
## `_timer_label.visible = false` pass -1.0. `urgent` turns on every channel
## described under "URGENCY WITHOUT COLOUR" -- size, glyph, position, rate and
## border together, so it stays legible without hue.
func set_timer(seconds: float, urgent: bool, owner_id: StringName) -> void:
	if not _accept(Slot.TIMER, owner_id, "%.1f|%s" % [seconds, urgent]):
		return
	var showing := seconds >= 0.0
	var was_urgent := _urgent
	_timer_seconds = seconds
	_urgent = showing and urgent
	if _urgent and not was_urgent:
		# Start the beat at its dim end so the first cycle is a rise, not a
		# half-cycle stub whose length depends on when urgency happened to begin.
		_beat = 0.0
	_render_timer()
	if _urgent != was_urgent:
		_apply_urgency()
	_refresh_visibility()


## Slot 3: how to carry out slot 1. Deliberately the quietest text in the block.
## An empty key hides the row but keeps the lease.
##
## This is the slot the interaction prompt lives in, and the reason the ownership
## lock exists at all -- see "ONE OWNER PER SLOT". It belongs to &"night_hud"
## during a shift and to &"trial" inside a pocket dimension.
func set_hint(key: String, args: Array, owner_id: StringName) -> void:
	var text := _one_line(key, args)
	if not _accept(Slot.HINT, owner_id, text):
		return
	if text == _hint_text:
		return
	_hint_text = text
	_render_hint()
	_refresh_visibility()


## Slot 4: one line of state -- what the world is currently doing to the operator.
##
## The slot that exists because four slots were not enough for three systems. It
## belongs to &"anomaly" for the whole of an incident (the HUD_EFFECT_* readout,
## or the CCTV scan percentage while a scan is pending) and to &"trial" inside a
## pocket dimension, which names the dimension here. Nothing else may write it,
## which is what lets slots 3 and 5 stay the night HUD's through both.
##
## No bar and no ratio, deliberately: every row that stands here carries its own
## number or none at all, and none of them is a 0..1 quantity. A bar would be
## inventing a scale. Slot 5 is where a real measurement goes.
##
## An empty key hides the row but keeps the lease.
func set_status(key: String, args: Array, owner_id: StringName) -> void:
	var text := _one_line(key, args)
	if not _accept(Slot.STATUS, owner_id, text):
		return
	if text == _status_text:
		return
	_status_text = text
	_render_status()
	_refresh_visibility()


## Slot 5: a measured quantity ABOUT THE OPERATOR, as a slim bar with a caption.
##
## `ratio` is clamped to 0..1; below zero the BAR is hidden. `key`'s row must NOT
## carry a percentage of its own -- the block appends "  42%" itself, so one row
## serves both the bar case and the no-bar case. `args` is for rows that name a
## thing (a tool, an exhibit) rather than a quantity.
##
## The two shapes that matter:
##   set_progress(scanned / total, key)  -- a scan: caption, percentage and bar.
##   set_progress(-1.0, key, [tool])     -- a state, e.g. what is being carried:
##                                          caption only, no bar and no number,
##                                          because a binary state has no ratio
##                                          and a bar pinned at 100% would lie
##                                          about being a measurement.
## An empty key with a negative ratio clears the slot, but keeps the lease --
## `release()` is what drops one. This slot is &"night_hud"'s at all times,
## including inside a pocket dimension: stamina and what is in your hands are
## facts about the operator, and neither an anomaly nor a trial suspends them.
func set_progress(ratio: float, key: String, args: Array,
		owner_id: StringName) -> void:
	var text := _one_line(key, args)
	if not _accept(Slot.PROGRESS, owner_id, "%.4f|%s" % [ratio, text]):
		return
	_progress_ratio = -1.0 if ratio < 0.0 else clampf(ratio, 0.0, 1.0)
	_progress_text = text
	_render_progress()
	_refresh_visibility()


## Push a transient message through slot 1.
##
## It takes the loud line over for FLASH_SECONDS, then hands it back to the
## standing task -- messages do not fly past on their own layer any more, and
## two of them cannot be on screen at once by construction.
##
## Repeats of the message currently showing refresh its dwell instead of
## queueing, so a per-frame caller cannot build a backlog out of one event.
func flash(key: String, args: Array = [], tone: Tone = Tone.INFO) -> void:
	var text := _one_line(key, args)
	if text == "":
		return
	if _flash_left > 0.0 and text == _flash_text:
		_flash_left = FLASH_SECONDS
		_flash_tone = tone
		_render_primary()
		return
	if not _flash_queue.is_empty() and str(_flash_queue.back()["text"]) == text:
		return
	if _flash_left > 0.0:
		while _flash_queue.size() >= FLASH_QUEUE_MAX:
			_flash_queue.remove_at(0)
		_flash_queue.append({"text": text, "tone": tone})
		return
	_begin_flash({"text": text, "tone": tone})


## Hide the block whatever it is holding, for the screens that take the game
## away from the player: fail, win, the ending, the pause menu. The block owns
## its own `visible`, so this flag is the supported way to override it; setting
## `visible` directly is undone on the next set_*.
func set_suspended(on: bool) -> void:
	if _suspended == on:
		return
	_suspended = on
	_refresh_visibility()


## Take a slot without writing to it yet, e.g. at the start of an incident.
##
## Returns true if `owner_id` holds the slot afterwards. A slot already held by
## somebody else is NOT taken: the attempt is reported and false comes back, so a
## caller that genuinely needs the slot fails loudly at the moment it is written
## rather than a frame later, in a corner of the screen, in a build nobody is
## watching. Re-claiming a slot you already hold is a no-op and succeeds.
func claim(slot: Slot, owner_id: StringName) -> bool:
	if owner_id == OWNER_NONE:
		push_error("TaskBlock.claim(): OWNER_NONE cannot hold a slot. Pass the "
			+ "system's own owner id -- see ONE OWNER PER SLOT in game/TaskBlock.gd.")
		return false
	var holder: StringName = _slot_owner.get(slot, OWNER_NONE)
	if holder != OWNER_NONE and holder != owner_id:
		_report_conflict(slot, holder, owner_id, "<claim>")
		return false
	_slot_owner[slot] = owner_id
	return true


## Hand a slot back. The other half of the handshake, and the ONLY thing that
## drops a lease short of clear(): writing an empty string means "nothing to say
## right now", which is a thing an owner does constantly and must not be read as
## "help yourself".
##
## Releasing a slot you do not hold is a conflict and is reported: it is the
## silent theft the ownership rule exists to stop, just in the other direction.
## Releasing a free slot is a no-op.
func release(slot: Slot, owner_id: StringName) -> void:
	var holder: StringName = _slot_owner.get(slot, OWNER_NONE)
	if holder == OWNER_NONE:
		return
	if holder != owner_id:
		_report_conflict(slot, holder, owner_id, "<release>")
		return
	_slot_owner.erase(slot)


## Who holds `slot` right now, or OWNER_NONE. For tests and for a caller that
## wants to check before it writes rather than be told after.
func slot_owner(slot: Slot) -> StringName:
	return _slot_owner.get(slot, OWNER_NONE)


## Drop everything and go dark. For a night boundary or a scene change, where
## leaving a stale sentence up is worse than showing nothing.
##
## Every lease goes with it. A scene change is precisely the moment when the
## systems that held the slots are being torn down, and a lease surviving its
## owner would lock the slot out for the rest of the process.
func clear() -> void:
	_slot_owner.clear()
	_task_text = ""
	_hint_text = ""
	_status_text = ""
	_flash_text = ""
	_flash_left = 0.0
	_flash_queue.clear()
	_timer_seconds = -1.0
	_progress_ratio = -1.0
	_progress_text = ""
	var was_urgent := _urgent
	_urgent = false
	_render_primary()
	_render_timer()
	_render_hint()
	_render_status()
	_render_progress()
	if was_urgent:
		_apply_urgency()
	_refresh_visibility()


# --- FRAME ------------------------------------------------------------------

func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_advance_flash()
	if _urgent:
		_beat = fmod(_beat + delta, BEAT_SECONDS)
		_apply_beat()


func _begin_flash(entry: Dictionary) -> void:
	_flash_text = str(entry["text"])
	_flash_tone = entry["tone"]
	_flash_left = FLASH_SECONDS
	_render_primary()
	_refresh_visibility()


## Hard cut to the next queued message, or back to the standing task. No fade:
## a cross-fade on a two-second line says nothing and spends the whole fade
## under the contrast gate.
func _advance_flash() -> void:
	_flash_left = 0.0
	_flash_text = ""
	if not _flash_queue.is_empty():
		_begin_flash(_flash_queue.pop_front())
		return
	_render_primary()
	_refresh_visibility()


## The urgency chip breathes once per second. Fill only -- never the alpha of a
## glyph run, which is how a "gentle" pulse usually drops text under 4.5:1.
## reduced_flashes holds it at the bright end, so the chip still reads as the
## loud state; it simply stops moving.
func _apply_beat() -> void:
	if _chip_style == null:
		return
	var alpha := CHIP_FILL_HIGH
	if not _reduced_flashes():
		var phase := 0.5 - 0.5 * cos(TAU * _beat / BEAT_SECONDS)
		alpha = lerpf(CHIP_FILL_LOW, CHIP_FILL_HIGH, phase)
	_chip_style.bg_color = Color(UITheme.WARNING, alpha)


## The project's established settings lookup: one group lookup, null-guarded,
## field read through `.get()` so a missing property cannot abort the caller.
## Polled rather than cached, matching SecurityCameraTablet._reduced_flashes()
## and GameplayEnhancements._update_watch(), and only while the beat is running.
func _reduced_flashes() -> bool:
	if not is_inside_tree():
		return false
	var settings := get_tree().get_first_node_in_group("settings_manager")
	return settings != null and bool(settings.get("reduced_flashes"))


# --- SLOT OWNERSHIP ---------------------------------------------------------

## May `owner_id` write `value` into `slot`? The gate every set_* call passes.
##
## Three outcomes, and only one of them is silent:
##   * the slot is free, or the caller already holds it -> the write goes ahead
##     and the caller now holds the slot;
##   * somebody else holds it -> refused and reported;
##   * the caller did not name itself -> refused and reported. There is no
##     anonymous branch. A slot that can be written without a lease is a slot
##     with no protection, which is what this whole section shipped as once.
func _accept(slot: Slot, owner_id: StringName, value: String) -> bool:
	if owner_id == OWNER_NONE:
		_report_conflict(slot, OWNER_NONE, OWNER_NONE, value)
		return false
	var holder: StringName = _slot_owner.get(slot, OWNER_NONE)
	if holder != OWNER_NONE and holder != owner_id:
		_report_conflict(slot, holder, owner_id, value)
		return false
	_slot_owner[slot] = owner_id
	return true


## One error per offending pair, ever. A contended slot is written sixty times a
## second, so an unthrottled report would bury the defect in its own evidence.
func _report_conflict(slot: Slot, holder: StringName, intruder: StringName,
		value: String) -> void:
	var signature := "%d|%s|%s" % [slot, holder, intruder]
	if _conflicts_reported.has(signature):
		return
	_conflicts_reported[signature] = true
	if holder == OWNER_NONE and intruder == OWNER_NONE:
		push_error(("TaskBlock: slot %s was written with no owner (%s). Every "
			+ "set_* call must name the system making it -- see ONE OWNER PER SLOT "
			+ "in game/TaskBlock.gd.") % [_slot_name(slot), value])
	else:
		push_error(("TaskBlock: slot %s is held by \"%s\"; \"%s\" tried to write "
			+ "%s and was refused. One of the two is in the wrong slot -- see ONE "
			+ "OWNER PER SLOT in game/TaskBlock.gd.")
			% [_slot_name(slot), holder, intruder, value])
	slot_conflict.emit(slot, holder, intruder)


func _slot_name(slot: Slot) -> String:
	match slot:
		Slot.PRIMARY:
			return "1 (the sentence)"
		Slot.TIMER:
			return "2 (the countdown)"
		Slot.HINT:
			return "3 (the hint)"
		Slot.STATUS:
			return "4 (the status line)"
		_:
			return "5 (progress)"


# --- RENDERING --------------------------------------------------------------

## The ONLY writer of `_primary.text`. A flash outranks the standing task; when
## no flash is live the task comes back. There is no third source and no second
## Label, which is what makes "at most one primary line" a property of the code
## rather than a promise in a comment.
func _render_primary() -> void:
	if _primary == null:
		return
	var showing_flash := _flash_left > 0.0 and _flash_text != ""
	var text := _task_text
	var color := UITheme.ON_SURFACE
	if showing_flash:
		text = "%s %s" % [_tone_marker(_flash_tone), _flash_text]
		color = _tone_color(_flash_tone)
	_primary.text = text
	var was := _primary_size
	UITheme.apply_text(_primary, _fit_primary(text), color)
	_primary.visible = text != ""
	if was != _primary_size:
		_apply_timer_type()


## The size slot 1 gets: the large step, unless the sentence needs more than
## PRIMARY_COMFORT_LINES lines of it in the column it actually has.
##
## THIS IS THE FIX FOR THE TRUNCATION BUG. What used to happen here was
## `max_lines_visible = 2` plus OVERRUN_TRIM_WORD_ELLIPSIS, i.e. the answer to
## "what do I do now" was cut off mid-sentence and replaced with three dots on
## every resolution the game ships at. The block now measures the string against
## the font it is about to be drawn with and picks a size that fits; if even the
## small step does not fit, the text still WRAPS in full rather than being
## trimmed, because a task the player cannot read is worse than a tall panel.
func _fit_primary(text: String) -> int:
	_primary_size = PRIMARY_SIZE_LARGE
	if text == "":
		return _primary_size
	var column := _primary_column()
	if column <= 0.0:
		return _primary_size
	if _wrapped_lines(text, PRIMARY_SIZE_LARGE, column) > PRIMARY_COMFORT_LINES:
		_primary_size = PRIMARY_SIZE_SMALL
	return _primary_size


## Width of the text column inside the panel, in canvas units.
##
## Computed from the anchors and the panel's own content margins rather than read
## off `_primary.size`, because the fit has to be right on the FIRST frame a
## sentence is shown -- `size` is still zero until the container has laid out,
## which is one frame after the caller asked a question the player wants
## answered now.
func _primary_column() -> float:
	if not is_inside_tree():
		return 0.0
	var viewport := get_viewport()
	if viewport == null:
		return 0.0
	var pads := 0.0
	if _panel_style != null:
		pads = _panel_style.content_margin_left + _panel_style.content_margin_right
	# Floored: Control rounds its rect down to whole pixels, so the Label gets
	# 649 px where the anchors say 649.6. Measuring against the wider figure would
	# let a line that only just fits round into a line that does not.
	return maxf(0.0,
		floorf((ANCHOR_RIGHT - ANCHOR_LEFT) * viewport.get_visible_rect().size.x - pads))


## How many lines `text` wraps to at `size` in a `width` column, per the font the
## Label will use. WRAP_BREAK_FLAGS matches AUTOWRAP_WORD_SMART, so this is the
## same break decision the Label makes rather than an estimate of it.
func _wrapped_lines(text: String, size: int, width: float) -> int:
	var font := _primary.get_theme_font("font")
	if font == null:
		return 1
	var line_height := font.get_height(size)
	if line_height <= 0.0:
		return 1
	var box := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
		width, size, -1, WRAP_BREAK_FLAGS)
	return maxi(1, roundi(box.y / line_height))


## The countdown's type step. It is always one step quieter than the sentence it
## belongs to, except when urgency deliberately promotes it: a clock the same
## size as the task reads as a second headline, which is the defect this file
## exists to remove, one slot down.
func _apply_timer_type() -> void:
	if _timer == null:
		return
	if _urgent:
		UITheme.apply_text(_timer, UITheme.TITLE, UITheme.WARNING)
		return
	var size := UITheme.SECTION if _primary_size > PRIMARY_SIZE_SMALL else UITheme.BODY
	UITheme.apply_text(_timer, size, UITheme.ON_SURFACE)


func _render_timer() -> void:
	if _timer == null:
		return
	var showing := _timer_seconds >= 0.0
	_timer_row.visible = showing
	if showing:
		_timer.text = _format_time(_timer_seconds)


## m:ss, and tenths inside the last URGENT_TENTHS seconds of an urgent stretch.
## The switch is an urgency channel in its own right: the digits start moving ten
## times faster, which reads at a glance and reads in greyscale.
func _format_time(seconds: float) -> String:
	var left := maxf(seconds, 0.0)
	if _urgent and left < URGENT_TENTHS:
		return "%.1f" % left
	# floori() on a float division rather than int/int: same answer, and it does
	# not trip GDScript's integer_division warning on a line where the discarded
	# decimal part is the whole point.
	return "%d:%02d" % [floori(left / 60.0), int(left) % 60]


func _render_hint() -> void:
	if _hint == null:
		return
	_hint.text = _hint_text
	_hint.visible = _hint_text != ""
	_render_divider()


func _render_status() -> void:
	if _status == null:
		return
	_status.text = _status_text
	_status.visible = _status_text != ""
	_render_divider()


func _render_progress() -> void:
	if _progress_bar == null:
		return
	var has_bar := _progress_ratio >= 0.0
	_progress_bar.visible = has_bar
	if has_bar:
		_progress_bar.value = _progress_ratio * 100.0
		# Completion is announced by the number reaching 100, not by the fill
		# changing hue; the colour follows so it is not the only signal.
		_bar_fill.bg_color = UITheme.SUCCESS if _progress_ratio >= 1.0 else UITheme.ACCENT
	if _progress_text == "":
		_progress_caption.visible = false
	else:
		_progress_caption.visible = true
		# The percentage is appended here rather than expected inside the row,
		# so one plain catalogue label serves both the bar and the no-bar case.
		_progress_caption.text = _progress_text if not has_bar \
			else "%s  %d%%" % [_progress_text, roundi(_progress_ratio * 100.0)]
	_render_divider()


## The rule under the sentence and the clock only earns its pixel when there is
## something beneath it to separate.
func _render_divider() -> void:
	if _divider == null:
		return
	_divider.visible = _hint.visible or _status.visible or _progress_caption.visible \
		or _progress_bar.visible


## Every urgency channel except the beat, applied on transition only so nothing
## re-lays-out per frame.
func _apply_urgency() -> void:
	if _panel == null:
		return
	_panel.add_theme_stylebox_override("panel",
		_panel_style_urgent if _urgent else _panel_style)
	_chip.visible = _urgent
	_apply_timer_type()
	# The position channel. The spacer is the only expanding child of the row, so
	# moving it across the countdown moves the countdown: index 0 parks the
	# digits on the right, where a calm readout belongs; index 2 (past the chip
	# and the digits) pulls them left, under the first character of the sentence
	# and into the reading path.
	_timer_row.move_child(_timer_spacer, 2 if _urgent else 0)
	_apply_beat()


## The block shows itself when it has something to say and hides when it does
## not -- an empty bordered panel is a claim on attention with nothing behind it.
## `set_suspended()` overrides both ways.
func _refresh_visibility() -> void:
	if _panel == null:
		return
	var has_content := _task_text != "" or _flash_left > 0.0 or _hint_text != "" \
		or _status_text != "" or _timer_seconds >= 0.0 or _progress_ratio >= 0.0 \
		or _progress_text != ""
	visible = has_content and not _suspended


# --- TEXT -------------------------------------------------------------------

## Key -> one line of translated text.
##
## Loc.fmt() rather than `tr(key) % args`: a missing row or a translator-dropped
## specifier degrades to readable output instead of printing a bare KEY or
## aborting the caller mid-function (game/Loc.gd). Newlines are collapsed on the
## way through, which is the third of the three structural guards that keep slot
## 1 to a single line.
func _one_line(key: String, args: Array) -> String:
	if key == "":
		return ""
	return Loc.fmt(key, args).replace("\n", " ").strip_edges()


func _tone_color(tone: Tone) -> Color:
	match tone:
		Tone.GOOD:
			return UITheme.SUCCESS
		Tone.WARN:
			return UITheme.WARNING
		Tone.BAD:
			return UITheme.DANGER
		_:
			return UITheme.ON_SURFACE


func _tone_marker(tone: Tone) -> String:
	match tone:
		Tone.GOOD:
			return MARK_GOOD
		Tone.WARN:
			return MARK_WARN
		Tone.BAD:
			return MARK_BAD
		_:
			return MARK_INFO


# --- CONSTRUCTION -----------------------------------------------------------

func _build() -> void:
	_panel_style = UITheme.panel_raised()
	# Urgent: same surface, twice the border width. Width is the shape channel;
	# WARNING rides on top of it rather than carrying the signal alone.
	_panel_style_urgent = UITheme.stylebox(UITheme.SURFACE_RAISED, UITheme.WARNING,
		UITheme.FOCUS_WIDTH, UITheme.RADIUS_LG, UITheme.PAD_X + 4, UITheme.PAD_Y + 4)

	_panel = PanelContainer.new()
	_panel.anchor_left = ANCHOR_LEFT
	_panel.anchor_right = ANCHOR_RIGHT
	# anchor_bottom == anchor_top with zero offsets: the rect is zero-height and
	# Control clamps it up to the content's combined minimum, so the block is
	# exactly as tall as what it is showing.
	_panel.anchor_top = ANCHOR_TOP
	_panel.anchor_bottom = ANCHOR_TOP
	_panel.offset_left = 0.0
	_panel.offset_top = 0.0
	_panel.offset_right = 0.0
	_panel.offset_bottom = 0.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _panel_style)
	add_child(_panel)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", SLOT_GAP)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(body)

	# Slot 1. NO line cap and NO overrun behaviour, deliberately: this label used
	# to carry `max_lines_visible = 2` with word ellipsis, which is what cut the
	# objective off mid-sentence at every shipping resolution. Length is handled
	# by _fit_primary() stepping the type size instead, and anything that still
	# does not fit wraps in full. Autowrap also pins the Label's minimum width at
	# 1 px, which is what stops a long word from pushing the panel past
	# ANCHOR_RIGHT.
	_primary = Label.new()
	_primary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_primary.max_lines_visible = -1
	_primary.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_primary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text(_primary, PRIMARY_SIZE_LARGE, UITheme.ON_SURFACE)
	body.add_child(_primary)

	# Slot 2.
	_timer_row = HBoxContainer.new()
	_timer_row.add_theme_constant_override("separation", SLOT_GAP)
	_timer_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_timer_row)

	_timer_spacer = Control.new()
	_timer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timer_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_row.add_child(_timer_spacer)

	# The chip is a Label wearing a stylebox rather than a Panel wrapping a
	# Label: one control, and `_chip_style` is then the single object the beat
	# mutates. Its glyph is ON_SURFACE, NOT WARNING -- see the header; WARNING
	# on its own wash falls to 4.30 : 1 at the bright end of the beat.
	_chip_style = UITheme.stylebox(Color(UITheme.WARNING, CHIP_FILL_HIGH),
		UITheme.WARNING, UITheme.BORDER_WIDTH, UITheme.RADIUS_SM, 8, 2)
	_chip = Label.new()
	_chip.text = MARK_WARN
	_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chip.visible = false
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.add_theme_stylebox_override("normal", _chip_style)
	UITheme.apply_text(_chip, UITheme.SECTION, UITheme.ON_SURFACE)
	_timer_row.add_child(_chip)

	_timer = Label.new()
	_timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text(_timer, UITheme.SECTION, UITheme.ON_SURFACE)
	_timer_row.add_child(_timer)

	_divider = ColorRect.new()
	_divider.color = UITheme.BORDER
	_divider.custom_minimum_size = Vector2(0, UITheme.BORDER_WIDTH)
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_divider)

	# Slot 3. Half slot 1's size and a dimmer token: subordinate twice over.
	# It keeps a cap, unlike slot 1: a hint is a footnote, the block must not be
	# able to grow one into a page, and HINT_MAX_LINES is set above the longest
	# hint the catalogue can produce so the cap never actually bites.
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.max_lines_visible = HINT_MAX_LINES
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text(_hint, UITheme.LABEL, UITheme.MUTED)
	body.add_child(_hint)

	# Slot 4. Below the hint and above the gauge: "act / world / you". A step
	# quieter than the hint (CAPTION 12 against LABEL 14) on the same MUTED token,
	# because the world's telemetry never outranks what a keypress does. Capped
	# like the hint for the same reason -- every HUD_EFFECT_* row is one short
	# clause, so the cap does not bite.
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.max_lines_visible = HINT_MAX_LINES
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text(_status, UITheme.CAPTION, UITheme.MUTED)
	body.add_child(_status)

	# Slot 5.
	_progress_caption = Label.new()
	_progress_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_text(_progress_caption, UITheme.CAPTION, UITheme.MUTED)
	body.add_child(_progress_caption)

	# Track and fill carry zero border and zero padding, the same reasoning as
	# PlayerController's stamina bar: Godot draws the fill over the bar's full
	# height from its left edge, so a border on the track is swallowed as the bar
	# fills and any content margin shifts where 0% and 100% land.
	var bar_track := UITheme.stylebox(UITheme.SURFACE, UITheme.SURFACE, 0,
		UITheme.RADIUS_SM, 0, 0)
	_bar_fill = UITheme.stylebox(UITheme.ACCENT, UITheme.ACCENT, 0,
		UITheme.RADIUS_SM, 0, 0)
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bar.add_theme_stylebox_override("background", bar_track)
	_progress_bar.add_theme_stylebox_override("fill", _bar_fill)
	body.add_child(_progress_bar)
