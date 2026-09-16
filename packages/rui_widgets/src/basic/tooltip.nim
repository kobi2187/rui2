## Tooltip Widget - RUI2
##
## A popup tooltip that appears after the pointer has rested on it for `delay`
## seconds. Typically placed as a sibling overlay of the widget it describes.
##
## Note: the DSL has no on_mouse_enter / on_mouse_leave events. Hover entry is
## detected from the repeated on_mouse_hover events, and hover exit from the
## base `hovered` flag the event manager maintains.

import rui_core
import rui_drawing

import raylib

definePrimitive(Tooltip):
  props:
    text: string = ""
    delay: float = 0.5           # Seconds of hover before showing
    offsetX: float32 = 10.0      # Offset from the pointer
    offsetY: float32 = 10.0
    fontSize: float32 = 10.0
    padding: float32 = 6.0

  state:
    showing: bool
    hoverStartTime: float        # getTime() when the current hover began
    mouseX: float32
    mouseY: float32

  events:
    on_mouse_hover:
      if widget.hoverStartTime <= 0:
        widget.hoverStartTime = getTime()
      elif not widget.showing and getTime() - widget.hoverStartTime >= widget.delay:
        widget.showing = true
        widget.isDirty = true
        widget.layoutDirty = true
      return false

    on_mouse_move:
      widget.mouseX = event.mousePos.x
      widget.mouseY = event.mousePos.y
      if widget.showing:
        # The tip travels with the pointer, and its bounds ARE its render
        # texture, so moving it is a layout change and not just a repaint.
        widget.isDirty = true
        widget.layoutDirty = true
      return false

  layout:
    # Size to the text and sit at the pointer. Nothing drawn outside these
    # bounds would survive renderPass' per-widget render texture.
    let style = TextStyle(fontFamily: "", fontSize: widget.fontSize, color: BLACK,
                          bold: false, italic: false, underline: false)
    let m = measureText(widget.text, style)
    widget.bounds = Rect(
      x: widget.mouseX + widget.offsetX,
      y: widget.mouseY + widget.offsetY,
      width: m.width + widget.padding * 2,
      height: m.height + widget.padding * 2
    )

  render:
    # Hover exit: no leave event exists, so the flag is the signal.
    if not widget.hovered:
      if widget.showing or widget.hoverStartTime > 0:
        widget.showing = false
        widget.hoverStartTime = 0
      return

    if not widget.showing or widget.text.len == 0:
      return

    let style = TextStyle(fontFamily: "", fontSize: widget.fontSize, color: BLACK,
                          bold: false, italic: false, underline: false)
    drawTooltip(widget.text, widget.bounds,
                Color(r: 255, g: 255, b: 200, a: 255),
                Color(r: 0, g: 0, b: 0, a: 255),
                style)
