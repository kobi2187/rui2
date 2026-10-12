## The visual-state ladder, written once.
##
## Every themed widget re-derived its own state before asking the theme:
##
## ```nim
## let state = if widget.disabled: Disabled
##             elif widget.isPressed: Pressed
##             elif widget.hovered: Hovered
##             elif widget.focused: Focused
##             else: Normal
## let props = currentTheme.getThemeProps(widget.intent, state)
## ```
##
## Forty-three call sites across twenty-one files, all reading the same flags.
##
## ## The one thing they did not agree on
##
## Two groups order Focused and Hovered differently, and the disagreement looks
## deliberate rather than accidental:
##
##   Focused before Hovered   textinput, textarea, numberinput, spinner,
##                            combobox, checkbox, radiobutton
##   Hovered before Focused   iconbutton, toolbutton, radiogroup
##
## Which reads as a real distinction. For a text field, showing where the caret
## will go matters more than showing the pointer is nearby; for a button it is
## the other way round -- the pointer is about to act on *this* control, and
## saying so is more use than remembering which one has the caret.
##
## The choice belongs to the theme, not to the widget. A widget only says what
## it *is* -- `crText` or `crPointer` -- and `themeProps` asks the current
## theme which ladder that role uses (`Theme.statePreference`, read from the
## in-memory `currentTheme` on every lookup). The defaults keep the split above;
## a theme file can override either role:
##
## ```yaml
## statePreference:
##   text: focus      # or hover
##   pointer: hover
## ```

import std/[tables, options, monotimes, times]
import rui_core
import theme_types
import theme_sys_core


proc firstOf(a, b: bool, aState, bState: ThemeState): ThemeState =
  ## Whichever of two flags is set, in the order given.
  if a: aState
  elif b: bState
  else: ThemeState.Normal

proc attentionState(hovered, focused: bool, ladder: StateLadder): ThemeState =
  ## The half the two groups disagree about, and the only place the
  ## disagreement is written down.
  if ladder == slFocusFirst:
    firstOf(focused, hovered, ThemeState.Focused, ThemeState.Hovered)
  else:
    firstOf(hovered, focused, ThemeState.Hovered, ThemeState.Focused)

proc visualState*(disabled, pressed, hovered, focused: bool,
                  ladder = slPointerFirst): ThemeState =
  ## Which themed state these flags describe.
  ##
  ## Disabled and Pressed are above the disagreement and always come first, in
  ## that order: a disabled control cannot be pressed, and a pressed one is
  ## being acted on right now, which outranks both hover and focus.
  ##
  ## A plain function over four bools, so the ladder is checkable without a
  ## window -- it could previously only be reached by rendering.
  if disabled:
    return ThemeState.Disabled
  if pressed:
    return ThemeState.Pressed
  attentionState(hovered, focused, ladder)

# ---------------------------------------------------------------------------
# State fades
#
# When a control's visual state changes (hover, press, focus), its colours move
# to the new state's over the theme's `transitionSeconds` instead of snapping.
# It lives here, in the one call every themed widget makes, so a widget gets it
# without knowing about it and a theme with `animation.durationFast: 0` turns it
# off everywhere. Only widgets *mid-fade* occupy the table below, and a fade
# asks for repaints only while it runs, so an idle window still costs nothing.
# ---------------------------------------------------------------------------

type Fade = object
  fromState, toState: ThemeState
  start: MonoTime
  seconds: float32

var fades: Table[WidgetId, Fade]

proc mixColors*(a, b: ThemeProps, t: float32): ThemeProps =
  ## `b` with each colour that both have moved `t` of the way from a's. Sizes and
  ## text settings are not mixed: they take b's at once, so layout never sees a
  ## half-way border width.
  result = b
  template mix(field: untyped) =
    if a.field.isSome and b.field.isSome:
      result.field = some(lerp(a.field.get, b.field.get, t))
  mix backgroundColor
  mix foregroundColor
  mix borderColor
  mix pressedColor
  mix hoverColor
  mix activeColor
  mix focusColor
  mix focusRingColor
  mix focusGlowColor
  mix highlightColor
  mix shadowColor
  mix darkShadowColor
  mix gradientStart
  mix gradientEnd
  mix glowColor
  mix dropShadowColor

proc fadeActive*(widget: Widget): bool = widget.id in fades

proc themeProps*(widget: Widget, intent: ThemeIntent,
                 role = crPointer,
                 disabled = false, pressed = false): ThemeProps =
  ## The themed properties for a widget in its current visual state.
  ##
  ## `hovered` and `focused` come from the base Widget flags, which every widget
  ## shares. `disabled` and `pressed` are passed in, because widgets spell those
  ## differently and meaningfully: a Slider is "pressed" while dragging, a
  ## ComboBox while its list is open, a ToolButton while it is the active tool.
  ## Collapsing those into one base flag would lose the distinction; asking for
  ## them keeps the ladder honest without the widget having to write it out.
  ##
  ## A change of state fades (see above); a theme switch lands at once.
  let state = visualState(disabled, pressed, widget.hovered, widget.focused,
                          currentTheme.ladderFor(role))
  let target = currentTheme.getThemeProps(intent, state)
  let seconds = currentTheme.transitionSeconds
  let code = uint8(ord(state)) + 1
  if not animationsEnabled or seconds <= 0 or widget.themeFadeEpoch != settleEpoch or
     widget.lastThemeState == 0:
    if widget.lastThemeState == 0:
      let id = widget.id
      widget.disposers.add proc() = fades.del(id)
    widget.themeFadeEpoch = settleEpoch
    widget.lastThemeState = code
    fades.del(widget.id)
    return target
  if widget.lastThemeState != code:
    fades[widget.id] = Fade(fromState: ThemeState(widget.lastThemeState - 1),
                            toState: state, start: getMonoTime(), seconds: seconds)
    widget.lastThemeState = code
  if widget.id in fades:
    let fade = fades[widget.id]
    let t = float32((getMonoTime() - fade.start).inNanoseconds) / 1e9'f32 / fade.seconds
    if t >= 1:
      fades.del(widget.id)
      return target
    widget.repaintAfter(1.0 / 60.0)
    return mixColors(currentTheme.getThemeProps(intent, fade.fromState), target,
                     ease(easeOut, t))
  target
