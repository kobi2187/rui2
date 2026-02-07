## Slider Widget - RUI2
##
## A slider control for selecting a numeric value within a range.
## Supports optional value display and formatting.
## Ported from Hummingbird (slider2.nim) to RUI2's definePrimitive DSL.

import ../../../core/widget_dsl
import ../../../drawing_primitives/widget_primitives
import std/[options, strformat, strutils]

when defined(useGraphics):
  import raylib

definePrimitive(Slider):
  props:
    initialValue: float32 = 0.0
    minValue: float32 = 0.0
    maxValue: float32 = 100.0
    showValue: bool = true
    textLeft: string = ""
    textRight: string = ""
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    value: float32
    dragging: bool

  actions:
    onChange(value: float32)

  events:
    on_mouse_down:
      if not widget.disabled:
        widget.dragging = true
        return true
      return false

    on_mouse_up:
      if widget.dragging:
        widget.dragging = false
        return true
      return false

  render:
    when defined(useGraphics):
      let state = if widget.disabled: Disabled
                  elif widget.dragging: Pressed
                  elif widget.hovered: Hovered
                  else: Normal
      let props = currentTheme.getThemeProps(widget.intent, state)

      drawSlider(
        widget.bounds,
        widget.value,
        widget.minValue,
        widget.maxValue,
        props,
        widget.dragging
      )

      if widget.showValue:
        let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
        let rightText = fmt"{widget.value:.1f}"
        drawText(rightText, widget.bounds.x + widget.bounds.width + 10, widget.bounds.y + (widget.bounds.height - 14) / 2, 14.0, textColor)
    else:
      let value = widget.value
      let pct = int((value - widget.minValue) / (widget.maxValue - widget.minValue) * 100)
      echo "Slider: [", "=".repeat(pct div 10), " ".repeat(10 - pct div 10), "] ", fmt"{value:.1f}"
