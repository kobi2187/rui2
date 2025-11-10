
# Number input with validation
defineWidget NumberInput:
  props:
    value: float
    minValue: float
    maxValue: float
    step: float
    format: string = "%.2f"
    onChange: proc(newValue: float)

  render:
    var value = widget.value
    if GuiSpinner(
      widget.toRaylibRect(),
      "",
      addr value,
      widget.minValue,
      widget.maxValue,
      widget.enabled
    ):
      if value != widget.value:
        widget.value = value
        if widget.onChange != nil:
          widget.onChange(value)

  state:
    fields:
      value: float
      enabled: bool
      focused: bool