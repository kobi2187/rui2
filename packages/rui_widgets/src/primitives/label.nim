## Label Primitive Widget
##
## Renders text through Pango, so full Unicode, BiDi (Hebrew/Arabic) and complex
## script shaping come for free, along with real font metrics.
##
## A Label sizes itself: its `layout` measures the text and sets its own height
## (and width, when the parent has not imposed one), which is what lets vertical
## and horizontal stacks arrange labels without every caller assigning bounds by
## hand.

import rui_core
import rui_drawing
import raylib

definePrimitive(Label):
  props:
    text: string
    fontSize: float = 14.0
    color: raylib.Color = BLACK
    fontFamily: string = ""     ## "" resolves to the system Sans alias
    bold: bool = false
    italic: bool = false
    underline: bool = false
    align: TextAlign = TextAlign.Left
    wrap: bool = false          ## wrap to the width the parent assigned

  layout:
    let style = TextStyle(
      fontFamily: widget.fontFamily,
      fontSize: widget.fontSize,
      color: widget.color,
      bold: widget.bold,
      italic: widget.italic,
      underline: widget.underline
    )

    # Measure against the assigned width when wrapping, otherwise on one line.
    let metrics =
      if widget.wrap and widget.bounds.width > 0:
        measureTextWrapped(widget.text, style, widget.bounds.width)
      else:
        measureText(widget.text, style)

    # A parent that has already assigned a width keeps it; an unparented or
    # free-sized label takes its natural width.
    if widget.bounds.width <= 0:
      widget.bounds.width = metrics.width
    widget.bounds.height = metrics.height

  render:
    let style = TextStyle(
      fontFamily: widget.fontFamily,
      fontSize: widget.fontSize,
      color: widget.color,
      bold: widget.bold,
      italic: widget.italic,
      underline: widget.underline
    )

    if widget.wrap:
      drawTextLayout(TextLayout(
        text: widget.text,
        rect: widget.bounds,
        style: style,
        align: widget.align,
        wrap: true
      ))
    else:
      drawText(widget.text, widget.bounds, style, widget.align)
