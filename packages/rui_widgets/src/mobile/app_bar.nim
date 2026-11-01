## AppBar -- the bar across the top of a phone-style screen: a menu or back
## button, the screen's title, and its actions on the right.
##
## ```nim
## ui:
##   AppBar(title = "Inbox", leading = "☰", onLeading = proc() = drawer.toggle()):
##     IconButton(icon = "⌕")
##     IconButton(icon = "⋮")
## ```
##
## Its children are its actions, in a row at the right end, at their own size
## (as a ToolBar's children are its buttons). `leading` is a glyph drawn as a
## button at the left ("☰", "←"; empty for none); pressing it calls
## `onLeading`, with the press behaviour of every button (press.nim).

import rui_core
import rui_drawing
import ../press
import std/options
import raylib

const LeadingSize = 48'f32

proc leadingRect(widget: Widget): Rect

defineWidget(AppBar):
  props:
    title: string = ""
    subtitle: string = ""
    leading: string = ""            ## a glyph: "☰", "←"; empty for none
    barHeight: float32 = 56.0
    spacing: float32 = 4.0
    intent: ThemeIntent = Default

  actions:
    onLeading()

  init:
    widget.makePressable(keyboard = false)

  events:
    on_mouse_down:
      return widget.pressDown(event, widget.leading.len > 0, region = widget.leadingRect)
    on_mouse_up:
      return widget.pressUp(event):
        if widget.leadingRect.contains(event.mousePos.x, event.mousePos.y) and
           widget.onLeading != nil:
          widget.onLeading()

  layout:
    if widget.bounds.height <= 0: widget.bounds.height = widget.barHeight
    if widget.bounds.width <= 0: widget.bounds.width = 360
    var x = widget.bounds.x + widget.bounds.width - 8
    for i in countdown(widget.children.high, 0):     # right to left from the end
      let c = widget.children[i]
      let s = c.measure(unbounded())
      x -= s.width
      c.arrange(Rect(x: x, y: widget.bounds.y + (widget.bounds.height - s.height) / 2,
                     width: s.width, height: s.height))
      x -= widget.spacing

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let b = widget.bounds
    let ink = props.foregroundColor.get(BLACK)
    drawRect(b, props.backgroundColor.get(WHITE))
    drawLine(b.x, b.y + b.height - 0.5, b.x + b.width, b.y + b.height - 0.5, ink.withAlpha(0.12))
    var x = b.x + 16
    if widget.leading.len > 0:
      let r = widget.leadingRect
      if widget.pressed:
        discard drawSdfBox(r, r.width / 2, 0, ink.withAlpha(0.12), ink.withAlpha(0.12))
      var g = props.captionStyle(ink)
      g.fontSize = 22
      let s = measureText(widget.leading, g)
      drawStyledText(widget.leading, r.x + (r.width - s.width) / 2, r.y + (r.height - s.height) / 2, g)
      x = r.x + r.width + 8
    var t = props.captionStyle(ink)
    t.fontSize = props.fontSize.get(14) * 1.4
    t.bold = true
    if widget.subtitle.len > 0:
      var st = props.captionStyle(ink.withAlpha(0.65))
      st.fontSize = max(10'f32, st.fontSize - 2)
      let th = measureText(widget.title, t).height
      let sh = measureText(widget.subtitle, st).height
      let top = b.y + (b.height - th - sh) / 2
      drawStyledText(widget.title, x, top, t)
      drawStyledText(widget.subtitle, x, top + th, st)
    else:
      drawStyledText(widget.title, x, b.y + (b.height - measureText(widget.title, t).height) / 2, t)

proc leadingRect(widget: Widget): Rect =
  ## The leading button: a circle at the left, centred in the bar.
  let b = widget.bounds
  let s = min(LeadingSize, b.height)
  Rect(x: b.x + 4, y: b.y + (b.height - s) / 2, width: s, height: s)
