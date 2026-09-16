## Spacer Widget - RUI2
##
## A flexible gap in a layout. Stacks give a Spacer whatever room is left over;
## `minWidth` / `minHeight` are the floor it insists on.

import rui_core
import rui_drawing

definePrimitive(Spacer):
  props:
    minWidth: float32 = 0.0
    minHeight: float32 = 0.0
    flexGrow: float32 = 1.0      # Share of leftover space vs other spacers
    showDebug: bool = false      # Outline the spacer so gaps are visible

  layout:
    if widget.bounds.width <= 0:
      widget.bounds.width = widget.minWidth
    if widget.bounds.height <= 0:
      widget.bounds.height = widget.minHeight

  render:
    if widget.showDebug:
      drawRect(widget.bounds, Color(r: 255, g: 0, b: 255, a: 128), filled = false)
      drawText("Spacer", widget.bounds.x, widget.bounds.y, 10.0,
               Color(r: 255, g: 0, b: 255, a: 255))
