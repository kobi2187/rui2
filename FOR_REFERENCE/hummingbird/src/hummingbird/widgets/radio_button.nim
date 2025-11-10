
# Radio button
defineWidget RadioButton:
  props:
    text*: string
    value*: string    # This button's value
    selected*: string # Currently selected value
    onChange*: proc(value: string)

  render:
    if GuiRadioButton(
      widget.toRaylibRect(),
      widget.text,
      widget.selected == widget.value
    ):
      if widget.onChange != nil:
        widget.onChange(widget.value)
