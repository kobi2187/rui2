## FocusRing -- the highlight drawn round whatever the keyboard has reached.
##
## The App keeps two of these on the overlay layer while the user is navigating
## by keyboard: a firm one round the focused widget and a softer, wider one
## round the container (focus group) it is moving about in. They are overlays
## because a widget cannot paint outside its own bounds, and these have to sit
## just outside the widgets they mark. `bounds` is the marked rectangle already
## grown by the gap; the outline is drawn just inside it.
##
## The colour and thickness are the theme's focus ring (`focusColor`,
## `focusRingWidth`), so a fat brand gets a fat ring.

import rui_core
import rui_drawing
import raylib

definePrimitive(FocusRing):
  props:
    group: bool = false          # the container's ring: softer and rounder
    intent: ThemeIntent = Default

  render:
    let props = currentTheme.getThemeProps(widget.intent, ThemeState.Focused)
    let color = props.focusColor.get(props.activeColor.get(Color(r: 80, g: 120, b: 255, a: 255)))
    let width = max(2.0'f32, props.focusRingWidth.get(2.0'f32))
    let radius = props.cornerRadius.get(4.0'f32)
    const Clear = Color(r: 0, g: 0, b: 0, a: 0)
    if widget.group:
      drawBox(widget.bounds, radius + 6, Clear, color.withAlpha(0.5),
              max(1.5'f32, width * 0.75))
    else:
      drawBox(widget.bounds, radius + 2, Clear, color, width)
