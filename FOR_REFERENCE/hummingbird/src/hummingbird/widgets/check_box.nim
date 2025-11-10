
# Checkbox with label
defineWidget Checkbox:
  props:
    text: string
    checked: bool
    onToggle: proc(checked: bool)

  render:
    var checked = widget.checked
    if GuiCheckBox(
      widget.toRaylibRect(),
      widget.text,
      addr checked
    ):
      widget.checked = checked
      if widget.onToggle != nil:
        widget.onToggle(checked)