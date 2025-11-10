
# Color picker
defineWidget ColorPicker:
  props:
    color: Color
    onChange: proc(newColor: Color)
    showAlpha: bool

  render:
    var col = widget.color
    if GuiColorPicker(
      widget.toRaylibRect(),
      "",
      addr col
    ):
      if col != widget.color:
        widget.color = col
        if widget.onChange != nil:
          widget.onChange(col)

  state:
    fields:
      color: Color
      enabled: bool
