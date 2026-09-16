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
## So `StateLadder` carries the choice rather than a helper silently picking one
## and changing half the library's appearance. Each widget passes the ladder it
## already used, so nothing looks different today -- and if the project owner
## decides the two groups should agree, it is a one-word edit per widget rather
## than a re-derivation of the ladder in each. See issue #21.

import rui_core
import theme_types
import theme_sys_core

type
  StateLadder* = enum
    slPointerFirst
      ## Hovered wins over Focused. Buttons and anything else the pointer acts
      ## on directly.
    slFocusFirst
      ## Focused wins over Hovered. Text fields and anything with a caret.

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

proc themeProps*(widget: Widget, intent: ThemeIntent,
                 ladder = slPointerFirst,
                 disabled = false, pressed = false): ThemeProps =
  ## The themed properties for a widget in its current visual state.
  ##
  ## `hovered` and `focused` come from the base Widget flags, which every widget
  ## shares. `disabled` and `pressed` are passed in, because widgets spell those
  ## differently and meaningfully: a Slider is "pressed" while dragging, a
  ## ComboBox while its list is open, a ToolButton while it is the active tool.
  ## Collapsing those into one base flag would lose the distinction; asking for
  ## them keeps the ladder honest without the widget having to write it out.
  currentTheme.getThemeProps(
    intent, visualState(disabled, pressed, widget.hovered, widget.focused,
                        ladder))
