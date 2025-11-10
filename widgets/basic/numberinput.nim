## NumberInput Widget - RUI2
##
## A numeric input field with validation and optional spinner controls.
## Similar to Spinner but with more direct text input capabilities.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl_v2
import std/[options, strformat, strutils]

when defined(useGraphics):
  import raylib

definePrimitive(NumberInput):
  props:
    initialValue: float = 0.0
    minValue: float = 0.0
    maxValue: float = 100.0
    step: float = 1.0
    format: string = "%.2f"
    placeholder: string = "0.0"
    disabled: bool = false

  state:
    value: float
    isFocused: bool
    textValue: string    # String representation while editing

  actions:
    onChange(value: float)
    onValidationError(input: string)

  events:
    on_focus_gained:
      widget.isFocused.set(true)
      # Convert value to text for editing
      widget.textValue.set(fmt(widget.format) % widget.value.get())
      return false

    on_focus_lost:
      widget.isFocused.set(false)
      # Parse and validate text input
      try:
        let newValue = parseFloat(widget.textValue.get())
        let clamped = clamp(newValue, widget.minValue, widget.maxValue)
        widget.value.set(clamped)

        if widget.onChange.isSome:
          widget.onChange.get()(clamped)
      except:
        # Invalid input, revert to current value
        if widget.onValidationError.isSome:
          widget.onValidationError.get()(widget.textValue.get())
      return false

  render:
    when defined(useGraphics):
      var value = widget.value.get()
      let isFocused = widget.isFocused.get()

      # Use GuiSpinner for number input with spinners
      if GuiSpinner(
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: widget.bounds.width,
          height: widget.bounds.height
        ),
        "",
        addr value,
        widget.minValue.cint,
        widget.maxValue.cint,
        isFocused
      ):
        widget.value.set(value)
        if widget.onChange.isSome:
          widget.onChange.get()(value)
    else:
      # Non-graphics mode: just echo
      let value = widget.value.get()
      let display = if widget.isFocused.get():
                      widget.textValue.get()
                    else:
                      fmt(widget.format) % value
      echo "NumberInput: [", display, "]"
