## IconButton Widget - RUI2
##
## A button that displays an icon (can be text icon or texture).
## Supports tooltip on hover.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl_v3
import std/options

when defined(useGraphics):
  import raylib

definePrimitive(IconButton):
  props:
    # Icon can be either text (emoji, Unicode symbol) or texture path
    iconText: string = ""         # Text icon (e.g., "🔍", "⚙", "✕")
    iconTexturePath: string = ""  # Path to icon texture file
    tooltip: string = ""
    size: float = 24.0
    disabled: bool = false

  state:
    isPressed: bool
    texture: Texture2D  # Loaded texture (if using iconTexturePath)

  actions:
    onClick()

  events:
    on_mouse_down:
      if not widget.disabled:
        widget.isPressed = true
        return true
      return false

    on_mouse_up:
      if widget.isPressed and not widget.disabled:
        widget.isPressed = false
        if widget.onClick.isSome:
          widget.onClick.get()()
        return true
      return false

  render:
    when defined(useGraphics):
      let isPressed = widget.isPressed
      let isHovered = widget.isHovered

      # If using texture and not loaded yet, try to load it
      if widget.iconTexturePath.len > 0:
        # In a real implementation, we'd check if texture is valid first
        # For now, we'll use GuiButton as fallback
        if GuiButton(
          Rectangle(
            x: widget.bounds.x,
            y: widget.bounds.y,
            width: widget.size,
            height: widget.size
          ),
          widget.iconText.cstring  # Fallback to text if texture not loaded
        ):
          if widget.onClick.isSome and not widget.disabled:
            widget.onClick.get()()
      else:
        # Use text icon
        if GuiButton(
          Rectangle(
            x: widget.bounds.x,
            y: widget.bounds.y,
            width: widget.size,
            height: widget.size
          ),
          widget.iconText.cstring
        ):
          if widget.onClick.isSome and not widget.disabled:
            widget.onClick.get()()

      # Show tooltip on hover (simplified - just draw text below)
      if isHovered and widget.tooltip.len > 0:
        let tooltipY = widget.bounds.y + widget.size + 4
        DrawText(
          widget.tooltip.cstring,
          widget.bounds.x.cint,
          tooltipY.cint,
          10,
          Color(r: 0, g: 0, b: 0, a: 200)
        )
    else:
      # Non-graphics mode: just echo
      let icon = if widget.iconText.len > 0: widget.iconText else: "[?]"
      echo "IconButton: [", icon, "]"
      if widget.tooltip.len > 0:
        echo "  Tooltip: ", widget.tooltip
