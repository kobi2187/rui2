## Label Primitive Widget
##
## Pure drawing primitive that renders text
## TODO: Integrate Pango for proper Unicode/RTL support

import ../../../core/widget_dsl
import ../../../drawing_primitives/drawing_primitives
import ../../../drawing_primitives/primitives/text
import raylib

definePrimitive(Label):
  props:
    text: string
    fontSize: float = 14.0
    color: raylib.Color = BLACK

  render:
    let style = TextStyle(
      fontFamily: "",
      fontSize: widget.fontSize,
      color: widget.color,
      bold: false,
      italic: false,
      underline: false
    )
    drawText(widget.text, widget.bounds, style, TextAlign.Left)
