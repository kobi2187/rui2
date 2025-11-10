## ScrollBar Widget - RUI2
##
## A scroll bar control for scrolling through content.
## Can be vertical or horizontal.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl_v2
import std/options

when defined(useGraphics):
  import raylib

definePrimitive(ScrollBar):
  props:
    initialValue: float = 0.0
    minValue: float = 0.0
    maxValue: float = 100.0
    pageSize: float = 10.0       # Size of visible area (for proportional thumb)
    vertical: bool = true
    disabled: bool = false

  state:
    value: float
    dragging: bool
    thumbHovered: bool

  actions:
    onChange(value: float)
    onScroll(delta: float)

  events:
    on_mouse_down:
      if not widget.disabled:
        widget.dragging.set(true)
        return true
      return false

    on_mouse_up:
      if widget.dragging.get():
        widget.dragging.set(false)
        return true
      return false

    on_mouse_wheel:
      # Handle scroll wheel for scrolling
      if not widget.disabled:
        # Scroll wheel delta would come from event
        # For now, placeholder
        return true
      return false

  render:
    when defined(useGraphics):
      var val = widget.value.get()

      # GuiScrollBar signature: (bounds, value, minValue, maxValue)
      if GuiScrollBar(
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: widget.bounds.width,
          height: widget.bounds.height
        ),
        val.cint,
        widget.minValue.cint,
        widget.maxValue.cint
      ):
        # Value changed
        widget.value.set(val)
        if widget.onChange.isSome:
          widget.onChange.get()(val)
    else:
      # Non-graphics mode
      let val = widget.value.get()
      let pct = int((val - widget.minValue) / (widget.maxValue - widget.minValue) * 100)

      if widget.vertical:
        echo "ScrollBar (V): [", pct, "%]"
      else:
        echo "ScrollBar (H): [", "=".repeat(pct div 10), " ".repeat(10 - pct div 10), "]"
