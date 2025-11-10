## StatusBar Widget - RUI2
##
## A status bar typically shown at the bottom of windows.
## Displays text on the left and optional text on the right.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl_v2
import std/options

when defined(useGraphics):
  import raylib

definePrimitive(StatusBar):
  props:
    text: string = ""
    rightText: string = ""
    height: float = 24.0
    backgroundColor: Color = Color(r: 240, g: 240, b: 240, a: 255)  # Light gray
    textColor: Color = Color(r: 60, g: 60, b: 60, a: 255)           # Dark gray
    fontSize: int = 10

  render:
    when defined(useGraphics):
      # Use GuiStatusBar if available, otherwise draw manually
      GuiStatusBar(
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: widget.bounds.width,
          height: widget.height
        ),
        widget.text.cstring
      )

      # Draw right-aligned text if present
      if widget.rightText.len > 0:
        let rightTextWidth = MeasureText(widget.rightText.cstring, widget.fontSize.cint)
        let rightX = widget.bounds.x + widget.bounds.width - float32(rightTextWidth) - 10.0

        DrawText(
          widget.rightText.cstring,
          rightX.cint,
          (widget.bounds.y + (widget.height - float32(widget.fontSize)) / 2).cint,
          widget.fontSize.cint,
          widget.textColor
        )
    else:
      # Non-graphics mode
      if widget.rightText.len > 0:
        let padding = 40 - widget.text.len - widget.rightText.len
        echo widget.text, " ".repeat(max(0, padding)), widget.rightText
      else:
        echo widget.text
