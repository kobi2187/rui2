## Icon -- a glyph shown on its own: "★", "⚙", "✔", an emoji.
##
## No chrome, unlike IconButton. Give it `onClick` and it becomes a click
## target that lights up under the pointer. For a picture from a file use
## ImageWidget; this is for glyphs the theme's font can draw.
##
## ```nim
## Icon(glyph = "⚙", size = 20, onClick = openSettings)
## ```

import rui_core
import rui_drawing
import std/options

definePrimitive(Icon):
  props:
    glyph: string = ""
    size: float32 = 18.0
    intent: ThemeIntent = Default

  actions:
    onClick()

  events:
    on_mouse_down:
      if widget.onClick == nil: return false
      widget.onClick()
      return true

  layout:
    let style = TextStyle(fontSize: widget.size, color: BLACK)
    let m = measureText(widget.glyph, style)
    if widget.bounds.width <= 0: widget.bounds.width = max(m.width, widget.size)
    if widget.bounds.height <= 0: widget.bounds.height = max(m.height, widget.size)

  render:
    let props = widget.themeProps(widget.intent, crPointer)
    var color = props.foregroundColor.get(BLACK)
    if widget.onClick != nil and widget.hovered:
      color = props.activeColor.get(color)
    let style = TextStyle(fontSize: widget.size, color: color)
    let m = measureText(widget.glyph, style)
    drawStyledText(widget.glyph, widget.bounds.x + (widget.bounds.width - m.width) / 2,
                   widget.bounds.y + (widget.bounds.height - widget.size) / 2, style)
