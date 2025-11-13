## Tooltip Widget - RUI2
##
## A popup tooltip that appears on hover after a delay.
## Typically attached to another widget.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl_v3
import std/[options, times]

when defined(useGraphics):
  import raylib

definePrimitive(Tooltip):
  props:
    text: string
    delay: float = 0.5           # Seconds before showing tooltip
    offsetX: float = 10.0        # Offset from mouse position
    offsetY: float = 10.0
    backgroundColor: Color = Color(r: 255, g: 255, b: 200, a: 255)  # Light yellow
    textColor: Color = Color(r: 0, g: 0, b: 0, a: 255)              # Black
    borderColor: Color = Color(r: 100, g: 100, b: 100, a: 255)      # Dark gray
    padding: float = 6.0

  state:
    visible: bool
    hoverStartTime: float   # Time when hover started
    mouseX: float
    mouseY: float

  actions:
    # Tooltips don't typically have actions

  events:
    on_mouse_enter:
      # Start hover timer
      widget.hoverStartTime = GetTime()
      widget.visible = false
      return false

    on_mouse_leave:
      widget.visible = false
      return false

    on_mouse_move:
      # Update mouse position for tooltip placement
      when defined(useGraphics):
        let mousePos = GetMousePosition()
        widget.mouseX = mousePos.x
        widget.mouseY = mousePos.y

        # Check if delay has elapsed
        let elapsed = GetTime() - widget.hoverStartTime
        if elapsed >= widget.delay:
          widget.visible = true
      return false

  render:
    when defined(useGraphics):
      if widget.visible:
        # Measure text size
        let textWidth = MeasureText(widget.text.cstring, 10)
        let textHeight = 10

        # Calculate tooltip rectangle
        let tooltipWidth = float32(textWidth) + widget.padding * 2
        let tooltipHeight = float32(textHeight) + widget.padding * 2

        let tooltipX = widget.mouseX + widget.offsetX
        let tooltipY = widget.mouseY + widget.offsetY

        let tooltipRect = Rectangle(
          x: tooltipX,
          y: tooltipY,
          width: tooltipWidth,
          height: tooltipHeight
        )

        # Draw background
        DrawRectangleRec(tooltipRect, widget.backgroundColor)

        # Draw border
        DrawRectangleLinesEx(tooltipRect, 1.0, widget.borderColor)

        # Draw text
        DrawText(
          widget.text.cstring,
          (tooltipX + widget.padding).cint,
          (tooltipY + widget.padding).cint,
          10,
          widget.textColor
        )
    else:
      # Non-graphics mode: just echo when visible
      if widget.visible:
        echo "Tooltip: ", widget.text
