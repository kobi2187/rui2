## Hyperlink Widget - RUI2
##
## A clickable hyperlink with visited state tracking.
## Displays as underlined text that changes color when clicked.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../../core/widget_dsl
import ../../../drawing_primitives/widget_primitives
import ../../../drawing_primitives/primitives/shapes
import std/options

when defined(useGraphics):
  import raylib

definePrimitive(Hyperlink):
  props:
    text: string
    url: string = ""
    colorUnvisited: Color = Color(r: 0, g: 102, b: 204, a: 255)
    colorVisited: Color = Color(r: 128, g: 0, b: 128, a: 255)
    underline: bool = true
    disabled: bool = false

  state:
    visited: bool

  actions:
    onClick()
    onNavigate(url: string)

  events:
    on_mouse_down:
      if not widget.disabled:
        widget.visited = true
        if widget.onClick.isSome:
          widget.onClick.get()()
        if widget.onNavigate.isSome and widget.url.len > 0:
          widget.onNavigate.get()(widget.url)
        return true
      return false

  render:
    when defined(useGraphics):
      let color = if widget.disabled:
                    Color(r: 160, g: 160, b: 160, a: 255)
                  elif widget.visited:
                    widget.colorVisited
                  else:
                    widget.colorUnvisited

      let textY = widget.bounds.y + (widget.bounds.height - 14) / 2
      drawText(widget.text, widget.bounds.x + widget.bounds.width / 2, textY, 14.0, color, centered = true)

      if widget.underline:
        let textWidth = measureText(widget.text, 14'i32)
        shapes.drawLine(
          widget.bounds.x + (widget.bounds.width - textWidth.float32) / 2,
          widget.bounds.y + widget.bounds.height - 3,
          widget.bounds.x + (widget.bounds.width + textWidth.float32) / 2,
          widget.bounds.y + widget.bounds.height - 3,
          color,
          1.0f32
        )
    else:
      let marker = if widget.visited: "[visited]" else: ""
      echo "Hyperlink: ", widget.text, " (", widget.url, ") ", marker
