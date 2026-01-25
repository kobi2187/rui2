## ContextMenu Widget - RUI2
##
## A popup menu that appears at the mouse position (typically on right-click).
## Contains MenuItem children arranged vertically.
## Uses defineWidget to manage MenuItems.

import ../../core/widget_dsl
import std/options

when defined(useGraphics):
  import raylib

defineWidget(ContextMenu):
  props:
    itemHeight: float = 24.0
    minWidth: float = 150.0
    padding: float = 4.0
    backgroundColor: Color = Color(r: 250, g: 250, b: 250, a: 255)
    borderColor: Color = Color(r: 180, g: 180, b: 180, a: 255)

  state:
    isVisible: bool
    posX: float
    posY: float

  actions:
    onOpen(x: float, y: float)
    onClose()

  layout:
    # Position menu at saved coordinates
    widget.bounds.x = widget.posX
    widget.bounds.y = widget.posY

    # Calculate total height
    let totalHeight = float(widget.children.len) * widget.itemHeight + widget.padding * 2
    widget.bounds.height = totalHeight

    # Stack menu items vertically
    var y = widget.bounds.y + widget.padding

    for child in widget.children:
      child.bounds.x = widget.bounds.x + widget.padding
      child.bounds.y = y
      child.bounds.width = widget.minWidth - (widget.padding * 2)
      child.bounds.height = widget.itemHeight

      child.layout()
      y += widget.itemHeight

  events:
    on_mouse_down:
      # Click outside closes the context menu
      if widget.isVisible:
        # Check if click is outside menu bounds
        # For now, just close
        widget.isVisible = false
        if widget.onClose.isSome:
          widget.onClose.get()()
        return true
      return false

  render:
    when defined(useGraphics):
      if widget.isVisible:
        # Draw shadow (simple offset rectangle)
        DrawRectangle(
          (widget.bounds.x + 2).cint,
          (widget.bounds.y + 2).cint,
          widget.bounds.width.cint,
          widget.bounds.height.cint,
          Color(r: 0, g: 0, b: 0, a: 50)
        )

        # Draw menu background
        DrawRectangleRec(widget.bounds, widget.backgroundColor)

        # Draw border
        DrawRectangleLinesEx(widget.bounds, 1.0, widget.borderColor)

        # Render menu items
        for child in widget.children:
          child.render()
    else:
      # Non-graphics mode
      if widget.isVisible:
        echo "┌─ ContextMenu ─┐"
        for child in widget.children:
          echo child
        echo "└", "─".repeat(15), "┘"
