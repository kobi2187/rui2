## ProgressBar Widget - RUI2
##
## A progress bar for displaying completion status.
## Supports optional text display with formatting.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl
import ../../drawing_primitives/widget_primitives
import std/[options, strutils]

when defined(useGraphics):
  import raylib

definePrimitive(ProgressBar):
  props:
    initialValue: float = 0.0
    maxValue: float = 100.0
    showText: bool = true
    format: string = "%.0f%%"
    textLeft: string = ""
    disabled: bool = false
    # TODO: these should be fetched from the current theme
    themeProps: ThemeProps = ThemeProps(
      backgroundColor: some(Color(r: 220, g: 220, b: 220, a: 255)),
      activeColor: some(Color(r: 100, g: 150, b: 255, a: 255))
    )

  state:
    value: float

  actions:
    onComplete()

  render:
    when defined(useGraphics):
      let progress = (widget.value / widget.maxValue).float32
      drawProgressBar(widget.bounds, progress, widget.themeProps)

      if widget.showText:
        let percent = int((widget.value / widget.maxValue) * 100)
        let displayText = $percent & "%"
        drawText(displayText, widget.bounds.x + widget.bounds.width / 2, widget.bounds.y + (widget.bounds.height - 14) / 2, 14.0, Color(r: 60, g: 60, b: 60, a: 255), centered = true)

      if widget.value >= widget.maxValue:
        if widget.onComplete.isSome:
          widget.onComplete.get()()
    else:
      let currentValue = widget.value
      let pct = int((currentValue / widget.maxValue) * 100)
      let filled = pct div 10
      let empty = 10 - filled
      echo "Progress: [", "█".repeat(filled), "░".repeat(empty), "] ", pct, "%"
