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
## The underline is TextStyle.underline, drawn by drawText just under the
## baseline, from the same Pango metrics the layout measured.

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
    widget.cursorShape = csPointer    # the hand every link shows

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

    # One call, which centres the text and puts the underline under the
    # baseline. This used to offset the text by (height - 14) / 2 on top of a
    # full-line-height glyph texture, then draw its own rule at height - 3 --
    # which landed through the lower half of the letters.
    drawText(widget.text, widget.bounds,
             TextStyle(fontFamily: "", fontSize: 14.0, color: color,
                       bold: false, italic: false, underline: widget.underline),
             TextAlign.Center)