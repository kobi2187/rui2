## What the UI keeps globally, in one place.
##
## Widgets have no reference to the App, by design: a widget is a value you can
## build, lay out and test on its own. So the few things every widget may need
## to ask -- what the theme is, where the pointer is, which popups are open --
## live as module-level state, one module per concern. This is the index of all
## of it, and `resetUiState` puts every piece back to how a fresh UI starts
## (an app replacing its whole tree, a test that wants a clean slate).
##
## | State | Lives in | Why widgets need it |
## |---|---|---|
## | the theme, and its text defaults | rui_drawing theme_sys_core (`currentTheme`), primitives/text | every widget paints in it |
## | the pointer: what is under it, who holds it | pointer_state | hover, drags that leave their widget, tooltips |
## | open popups, the pending focus request | popups | a click outside closes them; a menu asks for the keys |
## | the overlay layer | overlays | menus, tooltips and windows float above the tree |
## | repaint timers, and decorative motion resting | repaint_timers | a caret blinks, a fade steps, an idle window sleeps |
## | widget timers (`every`, `after`, `onTick`) | timers | things that change with time |
## | frozen pages behind modals | freeze | a modal's backdrop is a still picture |
## | mouse or touch, keyboard driving | input_mode | a drag scrolls on a finger, selects with a mouse |
## | motion preferences | animation (`motion`, `animationsEnabled`) | reduced or no motion |
## | the user's preferences | preferences (`prefs`) | keys, blink rate, scroll speed |
## | what the window shows | main_loop (`renderView`) | culling |
## | the page glass blurs | rui_drawing backdrop (`glassPage`) | frosted panels |
##
## The drawing half (the theme, glass) is reset by rui_drawing's
## `resetDrawingState`; the App's `resetUi` does both.

import types
import pointer_state, popups, overlays, repaint_timers, timers, freeze, main_loop
import std/options

proc resetUiState*() =
  ## Every piece of rui_core's global UI state back to a fresh start: no
  ## popups, overlays, timers, captures or frozen pages; the user present.
  clearPopups()
  clearOverlays()
  clearRepaints()
  clearTimers()
  resetIdle()
  resetPointerState()
  thawAll()
  renderView = none(Rect)
