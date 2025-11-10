
# List view with selection
defineWidget ListView:
  props:
    items: seq[string]
    selection: HashSet[int]
    multiSelect: bool
    onSelect: proc(selected: HashSet[int])
    scrollOffset: float32

  render:
    var selected = widget.selection
    let itemsStr = widget.items.join(";")

    if GuiListView(
      widget.toRaylibRect(),
      itemsStr,
      addr widget.scrollOffset,
      selected
    ):
      if widget.onSelect != nil:
        widget.onSelect(selected)

  state:
    fields:
      items: seq[string]
      selection: HashSet[int]
      scrollOffset: float32
