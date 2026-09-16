## Rectangle Primitive Widget
##
## A fill and an optional border, drawn at whatever bounds it is given. It has
## no `layout` section at all, which means it never sizes itself: a Rectangle in
## a VStack contributes zero height unless something assigns its bounds.
##
## That is deliberate -- it is the shape composite widgets draw their background
## with (see basic/button_v2.nim, which sets the rectangle's bounds from its own
## measured text), not something you place on its own and expect to appear.
##
## The colours are plain raylib Colors rather than theme intents, for the same
## reason: a themed widget resolves its own ThemeProps and hands the result
## down. A Rectangle that read the theme itself could not be used as a part.

import rui_core
import rui_drawing
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
