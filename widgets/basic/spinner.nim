## Spinner Widget - RUI2
##
## A numeric spinner with up/down buttons for value adjustment.
## Allows stepping through numeric values within a range.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl_v2
import std/[options, strformat]

when defined(useGraphics):
  import raylib

definePrimitive(Spinner):
  props:
    initialValue: float = 0.0
    minValue: float = 0.0
    maxValue: float = 100.0
    step: float = 1.0
    format: string = "%.2f"
    textLeft: string = ""
    disabled: bool = false

  state:
    value: float
    isFocused: bool
    editing: bool

  actions:
    onChange(value: float)

  events:
    on_mouse_down:
      if not widget.disabled:
        widget.isFocused.set(true)
        return true
      return false

    on_focus_gained:
      widget.isFocused.set(true)
      return false

    on_focus_lost:
      widget.isFocused.set(false)
      widget.editing.set(false)
      return false

  render:
    when defined(useGraphics):
      var value = widget.value.get()
      let isFocused = widget.isFocused.get()

      if GuiSpinner(
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: widget.bounds.width,
          height: widget.bounds.height
        ),
        widget.textLeft.cstring,
        addr value,
        widget.minValue.cint,
        widget.maxValue.cint,
        isFocused
      ):
        # GuiSpinner returns true when value changes
        # Clamp to step increments
        let stepped = round(value / widget.step) * widget.step
        widget.value.set(stepped)

        if widget.onChange.isSome:
          widget.onChange.get()(stepped)
    else:
      # Non-graphics mode: just echo
      let value = widget.value.get()
      echo "Spinner: [▼] ", fmt(widget.format) % value, " [▲]"
