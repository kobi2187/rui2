## ToolBar Widget - RUI2
##
## A horizontal toolbar containing buttons and other controls.
## Typically shown below the MenuBar with quick-access buttons.
## Uses defineWidget to manage ToolButton children.

import ../../core/widget_dsl_v3
import std/options

when defined(useGraphics):
  import raylib

defineWidget(ToolBar):
  props:
    height: float = 32.0
    spacing: float = 2.0
    padding: float = 4.0
    backgroundColor: Color = Color(r: 245, g: 245, b: 245, a: 255)
    borderColor: Color = Color(r: 200, g: 200, b: 200, a: 255)
    showBorder: bool = true

  layout:
    # Arrange toolbar items horizontally
    var x = widget.bounds.x + widget.padding

    for child in widget.children:
      child.bounds.x = x
      child.bounds.y = widget.bounds.y + widget.padding
      child.bounds.height = widget.height - (widget.padding * 2)

      # Width depends on child (button, separator, etc.)
      # For now, let child keep its width or use default
      if child.bounds.width == 0:
        child.bounds.width = widget.height - (widget.padding * 2)  # Square buttons

      child.layout()
      x += child.bounds.width + widget.spacing

  render:
    when defined(useGraphics):
      # Draw toolbar background
      DrawRectangleRec(
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: widget.bounds.width,
          height: widget.height
        ),
        widget.backgroundColor
      )

      # Draw bottom border if enabled
      if widget.showBorder:
        DrawLineEx(
          Vector2(x: widget.bounds.x, y: widget.bounds.y + widget.height),
          Vector2(x: widget.bounds.x + widget.bounds.width, y: widget.bounds.y + widget.height),
          1.0,
          widget.borderColor
        )

      # Render toolbar items
      for child in widget.children:
        child.render()
    else:
      # Non-graphics mode
      echo "ToolBar:"
      for child in widget.children:
        echo "  ", child
