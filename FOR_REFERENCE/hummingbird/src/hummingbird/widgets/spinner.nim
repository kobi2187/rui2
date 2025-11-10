
# Spinner (numeric up/down)
defineWidget Spinner:
  props:
    value*: float
    minValue*: float
    maxValue*: float
    step*: float = 1.0
    format*: string = "%.2f"
    onChange*: proc(value: float)

  render:
    var val = widget.value
    if GuiSpinner(
      widget.toRaylibRect(),
      "",
      addr val,
      widget.minValue,
      widget.maxValue,
      widget.focused
    ):
      widget.value = val
      if widget.onChange != nil:
        widget.onChange(val)

