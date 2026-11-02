## FloatingActionButton -- the one round button for a screen's main action,
## floating over the content: "+", a pen, a call. With `label` it is the
## extended, pill-shaped kind.
##
## ```nim
## ui:
##   Stack(fit = StackFit.expand):
##     theList()
##     Positioned(right = 16, bottom = 16):
##       FloatingActionButton(icon = "+", onClick = proc() = compose())
## ```
##
## It presses as every button does (press.nim): Space and Enter when focused.

import rui_core
import rui_drawing
import ../press
import std/options
import raylib

defineWidget(FloatingActionButton):
  props:
    icon: string = "+"
    label: string = ""              ## set: the extended kind, icon and label
    size: float32 = 56.0
    disabled: bool = false
    intent: ThemeIntent = Default

  actions:
    onClick()

  init:
    widget.makePressable()

  events:
    on_mouse_down: return widget.pressDown(event, not widget.disabled)
    on_key_down: return widget.pressKey(event, not widget.disabled)
    on_mouse_up:
      return widget.pressUp(event):
        if widget.onClick != nil: widget.onClick()

  layout:
    if widget.bounds.height <= 0: widget.bounds.height = widget.size + 8   # room for its shadow
    if widget.bounds.width <= 0:
      var w = widget.size
      if widget.label.len > 0:
        let props = currentTheme.getThemeProps(widget.intent, Normal)
        w = widget.size * 0.4 + 24 + 8 + measureText(widget.label, props.captionStyle(BLACK)).width + 20
      widget.bounds.width = w + 8

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let ink = props.foregroundColor.get(BLACK)
    let accent = props.activeColor.get(ink)
    let onAccent = if contrastRatio(accent, BLACK) >= contrastRatio(accent, WHITE): BLACK else: WHITE
    let b = widget.bounds
    let body = Rect(x: b.x + 4, y: b.y + (if widget.pressed: 3'f32 else: 2), width: b.width - 8,
                    height: widget.size)
    let r = min(body.height / 2, props.cornerRadius.get(16) * 2)
    discard drawSdfShadow(body, r, 0, (if widget.pressed: 1'f32 else: 3), 6, 0,
                          BLACK.withAlpha(0.28))
    let fill = if widget.disabled: ink.withAlpha(0.2)
               elif widget.pressed: lerp(accent, BLACK, 0.12)
               else: accent
    discard drawSdfBox(body, r, 0, fill, fill)
    var ic = props.captionStyle(onAccent)
    ic.fontSize = widget.size * 0.42
    let isz = measureText(widget.icon, ic)
    if widget.label.len == 0:
      drawStyledText(widget.icon, body.x + (body.width - isz.width) / 2,
                     body.y + (body.height - isz.height) / 2, ic)
    else:
      drawStyledText(widget.icon, body.x + 20, body.y + (body.height - isz.height) / 2, ic)
      var lab = props.captionStyle(onAccent, action = true)
      let ls = measureText(widget.label, lab)
      drawStyledText(widget.label, body.x + 20 + isz.width + 8,
                     body.y + (body.height - ls.height) / 2, lab)
    if widget.focused: drawThemedFocusRing(body, props)
