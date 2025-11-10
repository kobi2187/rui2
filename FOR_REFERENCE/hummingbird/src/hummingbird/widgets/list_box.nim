# List box (single or multi-select)
defineWidget ListBox:
  props:
    items*: seq[string]
    selection*: HashSet[int]
    multiSelect*: bool
    onSelect*: proc(selection: HashSet[int])

  render:
    var selected = -1
    if GuiListView(
      widget.toRaylibRect(),
      widget.items.join(";"),
      addr selected
    ):
      if selected >= 0:
        if widget.multiSelect:
          if selected in widget.selection:
            widget.selection.excl(selected)
          else:
            widget.selection.incl(selected)
        else:
          widget.selection = [selected].toHashSet

        if widget.onSelect != nil:
          widget.onSelect(widget.selection)

