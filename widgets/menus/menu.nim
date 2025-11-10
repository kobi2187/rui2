## Menu Widget - RUI2
##
## A dropdown menu container that holds MenuItem children.
## Can be used in MenuBar or as a standalone ContextMenu.
## Uses defineWidget to manage MenuItems.

import ../../core/widget_dsl_v2
import std/options

when defined(useGraphics):
  import raylib

defineWidget(Menu):
  props:
    title: string = ""           # Menu title (for MenuBar)
    itemHeight: float = 24.0     # Height of each menu item
    minWidth: float = 150.0      # Minimum menu width
    padding: float = 4.0

  state:
    isOpen: bool
    selectedIndex: int

  actions:
    onOpen()
    onClose()

  layout:
    # Stack menu items vertically
    var y = widget.bounds.y + widget.padding

    for child in widget.children:
      child.bounds.x = widget.bounds.x + widget.padding
      child.bounds.y = y
      child.bounds.width = widget.bounds.width - (widget.padding * 2)
      child.bounds.height = widget.itemHeight

      child.layout()
      y += widget.itemHeight

  render:
    when defined(useGraphics):
      if widget.isOpen.get():
        # Draw menu background
        DrawRectangleRec(
          widget.bounds,
          Color(r: 250, g: 250, b: 250, a: 255)
        )

        # Draw border
        DrawRectangleLinesEx(
          widget.bounds,
          1.0,
          Color(r: 180, g: 180, b: 180, a: 255)
        )

        # Render menu items
        for child in widget.children:
          child.render()
    else:
      # Non-graphics mode
      if widget.isOpen.get():
        echo "┌─ ", widget.title, " ", "─".repeat(max(0, 20 - widget.title.len)), "┐"
        for child in widget.children:
          echo child
        echo "└", "─".repeat(22), "┘"
