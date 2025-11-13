## Panel Container Widget - RUI2
##
## A bordered container with optional background color and padding.
## Foundation for GroupBox, dialogs, and other framed containers.
## Uses defineWidget for composability.

import ../../core/widget_dsl_v3
import std/options

when defined(useGraphics):
  import raylib

defineWidget(Panel):
  props:
    padding: float = 8.0
    backgroundColor: Color = Color(r: 245, g: 245, b: 245, a: 255)  # Light gray
    borderColor: Color = Color(r: 180, g: 180, b: 180, a: 255)      # Gray
    borderWidth: float = 1.0
    cornerRadius: float = 0.0
    showBackground: bool = true
    showBorder: bool = true

  layout:
    # Children fill the panel with padding
    for child in widget.children:
      child.bounds.x = widget.bounds.x + widget.padding
      child.bounds.y = widget.bounds.y + widget.padding
      child.bounds.width = widget.bounds.width - (widget.padding * 2)
      child.bounds.height = widget.bounds.height - (widget.padding * 2)

      # Layout the child recursively
      child.layout()

  render:
    when defined(useGraphics):
      # Draw background if enabled
      if widget.showBackground:
        if widget.cornerRadius > 0:
          DrawRectangleRounded(
            widget.bounds,
            widget.cornerRadius / min(widget.bounds.width, widget.bounds.height),
            8,  # segments
            widget.backgroundColor
          )
        else:
          DrawRectangleRec(widget.bounds, widget.backgroundColor)

      # Draw border if enabled
      if widget.showBorder:
        if widget.cornerRadius > 0:
          DrawRectangleRoundedLines(
            widget.bounds,
            widget.cornerRadius / min(widget.bounds.width, widget.bounds.height),
            8,  # segments
            widget.borderWidth,
            widget.borderColor
          )
        else:
          DrawRectangleLinesEx(widget.bounds, widget.borderWidth, widget.borderColor)

      # Render children
      for child in widget.children:
        child.render()
    else:
      # Non-graphics mode
      echo "Panel (", widget.bounds.width, "x", widget.bounds.height, "):"
      for child in widget.children:
        echo "  ", child
