## Circle Primitive Widget
##
## The circle inscribed in its bounds: centred, with the radius taken from the
## shorter side, so a non-square Rectangle gives a circle rather than an
## ellipse. Like primitives/rectangle.nim it has no `layout` and so never sizes
## itself -- it is a part for composites to place, not a standalone widget.
##
## `borderWidth` is a flag, not a width: raylib's drawCircleLines has no
## thickness parameter, so any value above zero draws the same one-pixel
## outline.

import rui_core
import rui_drawing
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
