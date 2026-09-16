## Hyperlink Widget - RUI2
##
## Underlined text that remembers it has been clicked.
##
## It does not open anything. `onNavigate(url)` hands the url to the
## application and stops there, because what a link should do is the app's
## decision -- open a browser, route in-app, show a confirmation -- and a widget
## that shelled out to a browser on click would be a widget you could not use
## for the other two. `visited` latches on click regardless, so the colour
## changes even for an app that ignores the url.
##
## The underline is drawn rather than asked for: it is a line under the
## measured text, not TextStyle.underline, so its width comes from the same
## Pango metrics the layout used and the two cannot drift.

import rui_core
import rui_drawing
import std/options

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

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      if not widget.disabled:
        widget.visited = true
        if widget.onClick != nil:
          widget.onClick()
        if widget.onNavigate != nil and widget.url.len > 0:
          widget.onNavigate(widget.url)
        return true
      return false

  layout:
    let style = TextStyle(fontFamily: "", fontSize: 14.0, color: BLACK,
                          bold: false, italic: false,
                          underline: widget.underline)
    let m = measureText(widget.text, style)
    if widget.bounds.height <= 0:
      widget.bounds.height = m.height
    if widget.bounds.width <= 0:
      widget.bounds.width = m.width

  render:
    let color = if widget.disabled:
                  Color(r: 160, g: 160, b: 160, a: 255)
                elif widget.visited:
                  widget.colorVisited
                else:
                  widget.colorUnvisited

    let textY = widget.bounds.y + (widget.bounds.height - 14) / 2
    drawText(widget.text, widget.bounds.x + widget.bounds.width / 2, textY, 14.0, color, centered = true)

    if widget.underline:
      # Pango metrics, matching `layout` and matching what drawText actually
      # rendered. This used to call raylib's bitmap-font measureText, which
      # measures a different font from the one on screen, so the rule was the
      # wrong length for anything but plain ASCII at exactly 14px.
      let style = TextStyle(fontFamily: "", fontSize: 14.0, color: color,
                            bold: false, italic: false, underline: false)
      let textWidth = measureText(widget.text, style).width
      shapes.drawLine(
        widget.bounds.x + (widget.bounds.width - textWidth) / 2,
        widget.bounds.y + widget.bounds.height - 3,
        widget.bounds.x + (widget.bounds.width + textWidth) / 2,
        widget.bounds.y + widget.bounds.height - 3,
        color,
        1.0f32
      )