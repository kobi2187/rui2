
# Spinner (number input with up/down buttons)
defineWidget Spinner:
  props:
    value: int
    minValue: int
    maxValue: int
    onChange: proc(value: int)

  render:
    var value = widget.value
    if GuiSpinner(
      widget.toRaylibRect(),
      "",
      addr value,
      widget.minValue,
      widget.maxValue,
      widget.focused
    ):
      widget.value = value
      if widget.onChange != nil:
        widget.onChange(value)

