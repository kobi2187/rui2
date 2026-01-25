## MenuBar Widget - RUI2
##
## A horizontal menu bar typically shown at the top of windows.
## Contains Menu widgets as children (File, Edit, View, etc.).
## Uses defineWidget to manage multiple Menu children.

import ../../core/widget_dsl
import std/options

when defined(useGraphics):
  import raylib

defineWidget(MenuBar):
  props:
    height: float = 28.0
    backgroundColor: Color = Color(r: 240, g: 240, b: 240, a: 255)
    textColor: Color = Color(r: 60, g: 60, b: 60, a: 255)
    hoverColor: Color = Color(r: 220, g: 220, b: 220, a: 255)

  state:
    activeMenuIndex: int  # Which menu is currently open (-1 = none)
    hoverIndex: int

  actions:
    onMenuOpen(index: int)
    onMenuClose()

  init:
    # Enable z-index sorting for dropdown menus to render on top
    widget.hasOverlay = true

  layout:
    # Arrange menu titles horizontally
    var x = widget.bounds.x

    for i, child in widget.children:
      child.bounds.x = x
      child.bounds.y = widget.bounds.y
      child.bounds.height = widget.height

      # Calculate width based on title
      # For now, use fixed width per menu
      child.bounds.width = 80.0  # TODO: measure text width

      child.layout()
      x += child.bounds.width

  render:
    when defined(useGraphics):
      # Draw menu bar background
      DrawRectangleRec(
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: widget.bounds.width,
          height: widget.height
        ),
        widget.backgroundColor
      )

      # Draw bottom border
      DrawLineEx(
        Vector2(x: widget.bounds.x, y: widget.bounds.y + widget.height),
        Vector2(x: widget.bounds.x + widget.bounds.width, y: widget.bounds.y + widget.height),
        1.0,
        Color(r: 180, g: 180, b: 180, a: 255)
      )

      # Render menu titles and active menu
      var x = widget.bounds.x
      let activeIdx = widget.activeMenuIndex

      for i, child in widget.children:
        # Get menu title (would be a property of Menu widget)
        let menuWidth = 80.0  # Fixed for now

        # Draw hover/active background
        if i == activeIdx or i == widget.hoverIndex:
          DrawRectangle(
            x.cint,
            widget.bounds.y.cint,
            menuWidth.cint,
            widget.height.cint,
            widget.hoverColor
          )

        # Draw menu title
        # TODO: Get actual title from Menu child
        DrawText(
          "Menu".cstring,
          (x + 8).cint,
          (widget.bounds.y + 6).cint,
          14,
          widget.textColor
        )

        # Render dropdown if this menu is active
        if i == activeIdx:
          child.render()

        x += menuWidth
    else:
      # Non-graphics mode
      echo "┌─ MenuBar ", "─".repeat(50), "┐"
      for child in widget.children:
        echo child
      echo "└", "─".repeat(60), "┘"
