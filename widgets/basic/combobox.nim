## ComboBox Widget - RUI2
##
## A dropdown selection widget (combo box).
## Displays a list of items and allows selecting one.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl
import std/[options, strutils]

when defined(useGraphics):
  import raylib

definePrimitive(ComboBox):
  props:
    items: seq[string] = @[]
    initialSelected: int = 0
    placeholder: string = "Select..."
    disabled: bool = false

  state:
    selectedIndex: int
    isOpen: bool

  actions:
    onSelect(index: int)

  events:
    on_mouse_down:
      if not widget.disabled:
        widget.isOpen = not widget.isOpen
        return true
      return false

  render:
    when defined(useGraphics):
      var selectedIdx = widget.selectedIndex

      # Join items with semicolon separator (required by GuiComboBox)
      let itemsStr = if widget.items.len > 0:
                       widget.items.join(";")
                     else:
                       widget.placeholder

      # GuiComboBox signature: (bounds, text, active)
      if GuiComboBox(
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: widget.bounds.width,
          height: widget.bounds.height
        ),
        itemsStr.cstring,
        addr selectedIdx
      ):
        # Selection changed
        widget.selectedIndex = selectedIdx
        if widget.onSelect.isSome:
          widget.onSelect.get()(selectedIdx)
    else:
      # Non-graphics mode: just echo
      let selectedIdx = widget.selectedIndex
      let selectedText = if selectedIdx >= 0 and selectedIdx < widget.items.len:
                           widget.items[selectedIdx]
                         else:
                           widget.placeholder
      echo "ComboBox: [", selectedText, " ▼]"
      if widget.isOpen:
        for i, item in widget.items:
          let marker = if i == selectedIdx: ">" else: " "
          echo "  ", marker, " ", item
