## ToolButton Widget - RUI2
##
## A button for use in toolbars, typically with an icon and optional text.
## Similar to IconButton but optimized for toolbar layout.
## Uses definePrimitive.

import ../../core/widget_dsl
import std/options

when defined(useGraphics):
  import raylib

definePrimitive(ToolButton):
  props:
    iconText: string = ""        # Text icon (emoji/Unicode)
    text: string = ""            # Optional label below icon
    tooltip: string = ""
    size: float = 24.0           # Button size
    showText: bool = false       # Show text label below icon
    toggleable: bool = false     # Can be toggled on/off
    disabled: bool = false

  state:
    isPressed: bool
    toggled: bool                # For toggleable buttons

  actions:
    onClick()
    onToggle(state: bool)

  events:
    on_mouse_down:
      if not widget.disabled:
        widget.isPressed = true
        return true
      return false

    on_mouse_up:
      if widget.isPressed and not widget.disabled:
        widget.isPressed = false

        if widget.toggleable:
          widget.toggled = not widget.toggled
          if widget.onToggle.isSome:
            widget.onToggle.get()(widget.toggled)

        if widget.onClick.isSome:
          widget.onClick.get()()

        return true
      return false

  render:
    when defined(useGraphics):
      let isPressed = widget.isPressed or widget.toggled
      let isHovered = widget.isHovered

      # Draw button background on hover or pressed
      if isHovered or isPressed:
        let bgColor = if isPressed:
                        Color(r: 200, g: 200, b: 200, a: 255)
                      else:
                        Color(r: 230, g: 230, b: 230, a: 255)

        DrawRectangleRec(widget.bounds, bgColor)
        DrawRectangleLinesEx(widget.bounds, 1.0, Color(r: 180, g: 180, b: 180, a: 255))

      # Draw icon
      if widget.iconText.len > 0:
        let iconX = widget.bounds.x + (widget.bounds.width - 16) / 2
        let iconY = widget.bounds.y + 4

        DrawText(
          widget.iconText.cstring,
          iconX.cint,
          iconY.cint,
          16,
          Color(r: 60, g: 60, b: 60, a: 255)
        )

      # Draw text label if enabled
      if widget.showText and widget.text.len > 0:
        let textWidth = MeasureText(widget.text.cstring, 8)
        let textX = widget.bounds.x + (widget.bounds.width - float32(textWidth)) / 2
        let textY = widget.bounds.y + widget.bounds.height - 12

        DrawText(
          widget.text.cstring,
          textX.cint,
          textY.cint,
          8,
          Color(r: 80, g: 80, b: 80, a: 255)
        )

      # Show tooltip on hover
      if isHovered and widget.tooltip.len > 0:
        let tooltipY = widget.bounds.y + widget.bounds.height + 4
        DrawText(
          widget.tooltip.cstring,
          widget.bounds.x.cint,
          tooltipY.cint,
          10,
          Color(r: 0, g: 0, b: 0, a: 200)
        )
    else:
      # Non-graphics mode
      let icon = if widget.iconText.len > 0: widget.iconText else: "[?]"
      let state = if widget.toggled: "[ON]" else: ""
      echo "ToolButton: [", icon, "] ", widget.text, " ", state
