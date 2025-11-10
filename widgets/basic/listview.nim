## ListView Widget - RUI2
##
## A scrollable list view widget with item selection.
## Similar to ListBox but with enhanced features like item height customization.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl_v2
import std/[options, strutils, sets]

when defined(useGraphics):
  import raylib

definePrimitive(ListView):
  props:
    items: seq[string] = @[]
    itemHeight: float = 24.0
    multiSelect: bool = false
    showScrollbar: bool = true
    disabled: bool = false

  state:
    selection: HashSet[int]   # Set of selected indices
    scrollIndex: int           # Current scroll position
    hoverIndex: int            # Currently hovered item

  actions:
    onSelect(selection: HashSet[int])
    onItemClick(index: int)
    onItemDoubleClick(index: int)

  events:
    on_mouse_down:
      if not widget.disabled:
        # Click handling will be done by GuiListView
        return false
      return false

  render:
    when defined(useGraphics):
      var selectedIndex = -1

      # Get first selected item for GuiListView
      for idx in widget.selection.get():
        selectedIndex = idx
        break

      # Join items with semicolon separator
      let itemsStr = if widget.items.len > 0:
                       widget.items.join(";")
                     else:
                       ""

      # GuiListView with scroll support
      var scrollIdx = widget.scrollIndex.get().cint

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
        widget.scrollIndex.set(scrollIdx.int)

        if selectedIndex >= 0:
          var newSelection = widget.selection.get()

          if widget.multiSelect:
            # Toggle selection
            if selectedIndex in newSelection:
              newSelection.excl(selectedIndex)
            else:
              newSelection.incl(selectedIndex)
          else:
            # Single selection - replace
            newSelection = [selectedIndex].toHashSet

          widget.selection.set(newSelection)

          # Trigger callbacks
          if widget.onItemClick.isSome:
            widget.onItemClick.get()(selectedIndex)

          if widget.onSelect.isSome:
            widget.onSelect.get()(newSelection)
    else:
      # Non-graphics mode: just echo
      echo "ListView:"
      let selection = widget.selection.get()
      for i, item in widget.items:
        let marker = if i in selection: "►" else: " "
        echo "  ", marker, " ", item
