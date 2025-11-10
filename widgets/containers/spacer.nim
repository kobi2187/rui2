## Spacer Widget - RUI2
##
## A flexible space element for layouts.
## Expands to fill available space in VStack/HStack containers.
## Uses definePrimitive as it's a leaf widget.

import ../../core/widget_dsl_v2
import std/options

when defined(useGraphics):
  import raylib

definePrimitive(Spacer):
  props:
    minWidth: float = 0.0
    minHeight: float = 0.0
    flexGrow: float = 1.0        # How much space to take relative to other spacers
    backgroundColor: Color = Color(r: 0, g: 0, b: 0, a: 0)  # Transparent by default
    showDebug: bool = false      # Show spacer bounds for debugging

  render:
    when defined(useGraphics):
      # Only render if debugging or has background color
      if widget.showDebug or widget.backgroundColor.a > 0:
        if widget.showDebug:
          # Draw debug outline
          DrawRectangleLinesEx(
            widget.bounds,
            1.0,
            Color(r: 255, g: 0, b: 255, a: 128)  # Magenta, semi-transparent
          )
          DrawText(
            "Spacer".cstring,
            widget.bounds.x.cint,
            widget.bounds.y.cint,
            10,
            Color(r: 255, g: 0, b: 255, a: 255)
          )
        elif widget.backgroundColor.a > 0:
          DrawRectangleRec(widget.bounds, widget.backgroundColor)
    else:
      # Non-graphics mode
      if widget.showDebug:
        echo "Spacer: ", widget.bounds.width, "x", widget.bounds.height
