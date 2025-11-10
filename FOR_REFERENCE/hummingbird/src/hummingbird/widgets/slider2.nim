

# Slider with optional text
defineWidget Slider:
  props:
    value: float32
    minValue: float32
    maxValue: float32
    showValue: bool
    format: string
    onChange: proc(value: float32)

  render:
    var value = widget.value
    let text = if widget.showValue:
                 widget.format % value
               else: ""
    if GuiSlider(
      widget.toRaylibRect(),
      text,
      $value,
      addr value,
      widget.minValue,
      widget.maxValue
    ):
      widget.value = value
      if widget.onChange != nil:
        widget.onChange(value)