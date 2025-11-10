
# Scroll bar
defineWidget ScrollBar:
  props:
    value*: float
    minValue*: float = 0.0
    maxValue*: float = 100.0
    pageSize*: float = 10.0
    vertical*: bool = true
    onChange*: proc(value: float)

  render:
    var val = widget.value
    if GuiScrollBar(
      widget.toRaylibRect(),
      val,
      widget.minValue,
      widget.maxValue
    ):
      widget.value = val
      if widget.onChange != nil:
        widget.onChange(val)
