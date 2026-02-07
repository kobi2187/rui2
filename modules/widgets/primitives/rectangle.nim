## Rectangle Primitive Widget
##
## Pure drawing primitive that renders rectangles using drawing_primitives

import ../../../core/widget_dsl
import ../../../drawing_primitives/drawing_primitives
import raylib

definePrimitive(Rectangle):
  props:
    color: raylib.Color = GRAY
    cornerRadius: float = 0.0
    filled: bool = true
    borderColor: raylib.Color = BLACK
    borderWidth: float = 0.0

  render:
    # Draw filled rectangle
    if widget.filled:
      if widget.cornerRadius > 0:
        drawRoundedRect(widget.bounds, widget.cornerRadius, widget.color, filled = true)
      else:
        drawRect(widget.bounds, widget.color, filled = true)

    # Draw border if specified
    if widget.borderWidth > 0:
      if widget.cornerRadius > 0:
        drawRoundedRect(widget.bounds, widget.cornerRadius, widget.borderColor, filled = false)
      else:
        drawRect(widget.bounds, widget.borderColor, filled = false)
