## NumberInput Widget - RUI2
##
## A numeric input field with validation and optional spinner controls.
## Similar to Spinner but with more direct text input capabilities.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl_v3
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
      widget.isFocused = true
      # Convert value to text for editing
      widget.textValue = fmt(widget.format % widget.value)
      return false

    on_focus_lost:
      widget.isFocused = false
      # Parse and validate text input
      try:
        let newValue = parseFloat(widget.textValue)
        let clamped = clamp(newValue, widget.minValue, widget.maxValue)
        widget.value = clamped

        if widget.onChange.isSome:
          widget.onChange.get()(clamped)
      except:
        # Invalid input, revert to current value
        if widget.onValidationError.isSome:
          widget.onValidationError.get()(widget.textValue)
      return false

  render:
    when defined(useGraphics):
      var value = widget.value
      let isFocused = widget.isFocused

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
        widget.value = value
        if widget.onChange.isSome:
          widget.onChange.get()(value)
    else:
      # Non-graphics mode: just echo
      let value = widget.value
      let display = if widget.isFocused:
                      widget.textValue
                    else:
                      fmt(widget.format) % value
      echo "NumberInput: [", display, "]"
