## Spacer Widget - RUI2
##
## A flexible gap in a layout. A VStack or HStack with a fixed size gives a
## Spacer whatever room its other children leave over, split between spacers
## by `grow`; `minWidth` / `minHeight` are the floor it insists on.
##
## `grow` is the Spacer's name for `Widget.flexGrow`, which any widget can set
## -- a TextArea that should fill a column does not need a Spacer beside it.

import rui_core
import rui_drawing

definePrimitive(Spacer):
  props:
    minWidth: float32 = 0.0
    minHeight: float32 = 0.0
    grow: float32 = 1.0          # Share of leftover space vs other flex children
    showDebug: bool = false      # Outline the spacer so gaps are visible

  layout:
    # Copied here rather than once in init, so setting `grow` later still
    # takes effect: stacks lay a child out before they read its weight.
    widget.flexGrow = widget.grow
    if widget.bounds.width <= 0:
      widget.bounds.width = widget.minWidth
    if widget.bounds.height <= 0:
      widget.bounds.height = widget.minHeight

  render:
    if widget.showDebug:
      drawRect(widget.bounds, Color(r: 255, g: 0, b: 255, a: 128), filled = false)
      drawText("Spacer", widget.bounds.x, widget.bounds.y, 10.0,
               Color(r: 255, g: 0, b: 255, a: 255))
