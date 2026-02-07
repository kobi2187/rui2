## Separator Widget - RUI2
##
## A visual separator line for dividing UI sections.
## Can be horizontal or vertical.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../../core/widget_dsl
import std/options

when defined(useGraphics):
  import raylib

definePrimitive(Separator):
  props:
    vertical: bool = false
    thickness: float = 1.0
    color: Color = Color(r: 128, g: 128, b: 128, a: 255)  # Gray

  render:
    when defined(useGraphics):
      if widget.vertical:
        # Draw vertical line in the center of the bounds
        let x = widget.bounds.x + widget.bounds.width / 2
        DrawLineEx(
          Vector2(x: x, y: widget.bounds.y),
          Vector2(x: x, y: widget.bounds.y + widget.bounds.height),
          widget.thickness,
          widget.color
        )
      else:
        # Draw horizontal line in the center of the bounds
        let y = widget.bounds.y + widget.bounds.height / 2
        DrawLineEx(
          Vector2(x: widget.bounds.x, y: y),
          Vector2(x: widget.bounds.x + widget.bounds.width, y: y),
          widget.thickness,
          widget.color
        )
    else:
      # Non-graphics mode: just echo
      if widget.vertical:
        echo "Separator: |"
      else:
        echo "Separator: ─────────────────"
