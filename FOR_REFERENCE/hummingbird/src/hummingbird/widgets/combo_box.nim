

# Dropdown/Combo box
defineWidget ComboBox:
  props:
    items: seq[string]
    selectedIndex: int
    onSelect: proc(index: int)
    dropDownHeight: float32

  render:
    let itemsStr = widget.items.join(";")
    var selected = widget.selectedIndex

    if GuiComboBox(
      widget.toRaylibRect(),
      itemsStr,
      addr selected
    ):
      if selected != widget.selectedIndex:
        widget.selectedIndex = selected
        if widget.onSelect != nil:
          widget.onSelect(selected)

  state:
    fields:
      items: seq[string]
      selectedIndex: int
      enabled: bool
