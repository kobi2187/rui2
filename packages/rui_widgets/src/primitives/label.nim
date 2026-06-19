## Label Primitive Widget
##
## Pure drawing primitive that renders text
## TODO: Integrate Pango for proper Unicode/RTL support

import rui_core
import rui_drawing
import rui_drawing
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
