## GroupBox Widget - RUI2
##
## A bordered container with a title label.
## Groups related controls together visually.
## Ported from Hummingbird to RUI2's defineWidget DSL.

import ../../../core/widget_dsl
import std/options

when defined(useGraphics):
  import raylib

defineWidget(GroupBox):
  props:
    title: string = ""
    padding: float = 8.0
    titleHeight: float = 20.0    # Space reserved for title
    borderColor: Color = Color(r: 180, g: 180, b: 180, a: 255)
    titleColor: Color = Color(r: 60, g: 60, b: 60, a: 255)
    backgroundColor: Color = Color(r: 250, g: 250, b: 250, a: 255)

  layout:
    # Children are positioned inside the group box with padding
    # Title takes up top space
    for child in widget.children:
      child.bounds.x = widget.bounds.x + widget.padding
      child.bounds.y = widget.bounds.y + widget.titleHeight + widget.padding
      child.bounds.width = widget.bounds.width - (widget.padding * 2)
      child.bounds.height = widget.bounds.height - widget.titleHeight - (widget.padding * 2)

      # Layout the child recursively
      child.layout()

  render:
    when defined(useGraphics):
      # Use GuiGroupBox from raygui
      GuiGroupBox(
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: widget.bounds.width,
          height: widget.bounds.height
        ),
        widget.title.cstring
      )

      # Render children (they're already positioned by layout)
      for child in widget.children:
        child.render()
    else:
      # Non-graphics mode
      echo "┌─ ", widget.title, " ", "─".repeat(max(0, 30 - widget.title.len)), "┐"
      for child in widget.children:
        echo "│ ", child
      echo "└", "─".repeat(32), "┘"
