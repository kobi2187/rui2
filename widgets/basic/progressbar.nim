## ProgressBar Widget - RUI2
##
## A progress bar for displaying completion status.
## Supports optional text display with formatting.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl_v2
import std/[options, strformat]

when defined(useGraphics):
  import raylib

definePrimitive(ProgressBar):
  props:
    initialValue: float = 0.0
    maxValue: float = 100.0
    showText: bool = true
    format: string = "%.0f%%"    # Format string for displaying percentage
    textLeft: string = ""        # Text on left side
    disabled: bool = false

  state:
    value: float

  actions:
    # ProgressBar typically doesn't have actions, but we can add one for completeness
    onComplete()

  render:
    when defined(useGraphics):
      let currentValue = widget.value.get()

      # Calculate percentage for display
      let percent = (currentValue / widget.maxValue) * 100.0

      # Format the text
      let displayText = if widget.showText:
                          try:
                            fmt(widget.format) % percent
                          except:
                            fmt"{percent:.0f}%"
                        else:
                          ""

      # GuiProgressBar signature: (bounds, textLeft, textRight, value, minValue, maxValue)
      GuiProgressBar(
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: widget.bounds.width,
          height: widget.bounds.height
        ),
        widget.textLeft.cstring,
        displayText.cstring,
        addr currentValue,
        0.0'f32,
        widget.maxValue.float32
      )

      # Check if just completed
      if currentValue >= widget.maxValue:
        if widget.onComplete.isSome:
          widget.onComplete.get()()
    else:
      # Non-graphics mode: just echo
      let currentValue = widget.value.get()
      let pct = int((currentValue / widget.maxValue) * 100)
      let filled = pct div 10
      let empty = 10 - filled
      echo "Progress: [", "█".repeat(filled), "░".repeat(empty), "] ", pct, "%"
