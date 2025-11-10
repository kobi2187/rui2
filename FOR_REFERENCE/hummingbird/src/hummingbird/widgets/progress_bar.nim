
# Progress bar
defineWidget ProgressBar:
  props:
    value*: float
    maxValue*: float = 100.0
    showText*: bool = true
    format*: string = "%.0f%%"

  render:
    let percent = (widget.value / widget.maxValue) * 100
    let text = if widget.showText: widget.format % percent else: ""

    GuiProgressBar(
      widget.toRaylibRect(),
      "",
      text,
      0,
      widget.maxValue.float32,
      widget.value.int32
    )

