

# Progress bar
defineWidget ProgressBar:
  props:
    value: float32
    maxValue: float32
    showPercentage: bool

  render:
    let text = if widget.showPercentage:
                 $int((widget.value / widget.maxValue) * 100) & "%"
               else: ""
    GuiProgressBar(
      widget.toRaylibRect(),
      text,
      $widget.value,
      0,
      widget.maxValue
    )