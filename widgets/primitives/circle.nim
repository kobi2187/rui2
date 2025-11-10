## Circle Primitive Widget
##
## Pure drawing primitive that renders circles using drawing_primitives

import ../../core/widget_dsl_v2
import ../../drawing_primitives/drawing_primitives
import raylib

definePrimitive(Circle):
  props:
    color: raylib.Color = GRAY
    filled: bool = true
    borderColor: raylib.Color = BLACK
    borderWidth: float = 0.0

  render:
    # Calculate center and radius from bounds
    let centerX = widget.bounds.x + widget.bounds.width / 2
    let centerY = widget.bounds.y + widget.bounds.height / 2
    let radius = min(widget.bounds.width, widget.bounds.height) / 2

    # Draw filled circle
    if widget.filled:
      drawCircle(int32(centerX), int32(centerY), radius, widget.color)

    # Draw border if specified
    if widget.borderWidth > 0:
      drawCircleLines(int32(centerX), int32(centerY), radius, widget.borderColor)
