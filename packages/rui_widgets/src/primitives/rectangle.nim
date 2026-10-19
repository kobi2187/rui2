## Rectangle Primitive Widget
##
## A fill and an optional border, drawn at whatever bounds it is given. It has
## no `layout` section at all, which means it never sizes itself: a Rectangle in
## a VStack contributes zero height unless something assigns its bounds.
##
## That is deliberate -- it is the shape composite widgets draw their background
## with (see basic/button.nim, which sets the rectangle's bounds from its own
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
    bevel: BevelStyle = Flat      # a 3D edge instead of the outline (see drawBeveledRect)
    bevelHighlight: raylib.Color = WHITE
    bevelShadow: raylib.Color = GRAY
    bevelDark: raylib.Color = BLACK
    ringWidth: float = 0.0       # a focus ring drawn inside a bevel (0: none)
    ringColor: raylib.Color = BLACK

  render:
    # Fill and border in one shape, the border inside the bounds.
    let fill = if widget.filled: widget.color else: Color(r: 0, g: 0, b: 0, a: 0)
    if widget.bevel != Flat:
      drawBeveledRect(widget.bounds, widget.bevel, fill, 0.0, widget.bevelHighlight,
                      widget.bevelShadow, widget.bevelDark, max(1.0'f32, widget.borderWidth.float32))
      if widget.ringWidth > 0:
        # Inside the bevel, so the ring sits on the control and not on the edge.
        let inset = max(1.0'f32, widget.borderWidth.float32)
        drawRectangleLines(raylib.Rectangle(x: widget.bounds.x + inset, y: widget.bounds.y + inset,
                                     width: widget.bounds.width - 2 * inset,
                                     height: widget.bounds.height - 2 * inset),
                           widget.ringWidth.float32, widget.ringColor)
      return
    drawBox(widget.bounds, widget.cornerRadius, fill,
            widget.borderColor, widget.borderWidth)
