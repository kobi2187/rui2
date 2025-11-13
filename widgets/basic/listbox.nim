## ListBox Widget - RUI2
##
## A list box widget for single or multi-select from a list of items.
## Displays a scrollable list with selectable items.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl_v3
import std/[options, strutils, sets]

when defined(useGraphics):
  import raylib

definePrimitive(ListBox):
  props:
    items: seq[string] = @[]
    multiSelect: bool = false
    disabled: bool = false

  state:
    selection: HashSet[int]   # Set of selected indices
    scrollIndex: int           # Current scroll position
    focusIndex: int            # Currently focused item

  actions:
    onSelect(selection: HashSet[int])
    onItemActivate(index: int)  # Double-click or Enter

  events:
    on_mouse_down:
      if not widget.disabled:
        # Will be handled by GuiListView
        return false
      return false

  render:
    when defined(useGraphics):
      var selectedIndex = -1

      # Get first selected item for GuiListView (which only supports single selection)
      for idx in widget.selection:
        selectedIndex = idx
        break

      # Join items with semicolon separator
      let itemsStr = if widget.items.len > 0:
                       widget.items.join(";")
                     else:
                       ""

      # GuiListView signature: (bounds, text, scrollIndex, active)
      var scrollIdx = widget.scrollIndex.cint
      if GuiListView(
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: widget.bounds.width,
          height: widget.bounds.height
        ),
        itemsStr.cstring,
        addr scrollIdx,
        addr selectedIndex
      ):
        # Selection changed
        widget.scrollIndex = scrollIdx.int

        if selectedIndex >= 0:
          var newSelection = widget.selection

          if widget.multiSelect:
            # Toggle selection
            if selectedIndex in newSelection:
              newSelection.excl(selectedIndex)
            else:
              newSelection.incl(selectedIndex)
          else:
            # Single selection - replace
            newSelection = [selectedIndex].toHashSet

          widget.selection = newSelection

          if widget.onSelect.isSome:
            widget.onSelect.get()(newSelection)
    else:
      # Non-graphics mode: just echo
      echo "ListBox:"
      let selection = widget.selection
      for i, item in widget.items:
        let marker = if i in selection: "[X]" else: "[ ]"
        echo "  ", marker, " ", item
