

# Dropdown/Combo box
defineWidget ComboBox:
  props:
    items: seq[string]
    selected: int
    onSelect: proc(index: int)
    dropDownHeight: float32

  render:
    var selected = widget.selected
    if GuiComboBox(
      widget.toRaylibRect(),
      widget.items.join(";"),
      addr selected
    ):
      widget.selected = selected
      if widget.onSelect != nil:
        widget.onSelect(selected)
