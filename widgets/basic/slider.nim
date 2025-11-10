## Slider Widget - RUI2
##
## A slider control for selecting a numeric value within a range.
## Supports optional value display and formatting.
## Ported from Hummingbird (slider2.nim) to RUI2's definePrimitive DSL.

import ../../core/widget_dsl_v2
import std/[options, strformat]

when defined(useGraphics):
  import raylib

definePrimitive(Slider):
  props:
    initialValue: float32 = 0.0
    minValue: float32 = 0.0
    maxValue: float32 = 100.0
    showValue: bool = true
    textLeft: string = ""        # Text on left side
    textRight: string = ""       # Text on right (value display)
    disabled: bool = false

  state:
    value: float32
    dragging: bool
    hovered: bool

  actions:
    onChange(value: float32)

  events:
    on_mouse_down:
      if not widget.disabled:
        widget.dragging.set(true)
        return true
      return false

    on_mouse_up:
      if widget.dragging.get():
        widget.dragging.set(false)
        return true
      return false

    on_mouse_enter:
      widget.hovered.set(true)
      return false

    on_mouse_leave:
      widget.hovered.set(false)
      return false

  render:
    when defined(useGraphics):
      var value = widget.value.get()

      # Format the right text (value display)
      let rightText = if widget.showValue:
                        fmt"{value:.1f}"
                      else:
                        widget.textRight

      if GuiSlider(
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: widget.bounds.width,
          height: widget.bounds.height
        ),
        widget.textLeft.cstring,
        rightText.cstring,
        addr value,
        widget.minValue,
        widget.maxValue
      ):
        # GuiSlider returns true when value changes
        widget.value.set(value)
        if widget.onChange.isSome:
          widget.onChange.get()(value)
    else:
      # Non-graphics mode: just echo
      let value = widget.value.get()
      let pct = int((value - widget.minValue) / (widget.maxValue - widget.minValue) * 100)
      echo "Slider: [", "=".repeat(pct div 10), " ".repeat(10 - pct div 10), "] ", fmt"{value:.1f}"
