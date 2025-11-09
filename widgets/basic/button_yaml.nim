## Button Widget - YAML-UI style
##
## Demonstrates the new on_click: section matching YAML-UI syntax

import ../../core/[types, widget_dsl]
import ../../drawing_primitives/drawing_primitives

when defined(useGraphics):
  import raylib

export types

type ButtonCallback* = proc()

defineWidget(ButtonYAML):
  props:
    text: string
    onClick: ButtonCallback
    backgroundColor: Color
    hoverColor: Color
    pressedColor: Color
    textColor: Color
    borderRadius: float32

  init:
    widget.text = "Button"
    when defined(useGraphics):
      widget.backgroundColor = Color(r: 70, g: 130, b: 180, a: 255)  # Steel blue
      widget.hoverColor = Color(r: 90, g: 150, b: 200, a: 255)       # Lighter blue
      widget.pressedColor = Color(r: 50, g: 110, b: 160, a: 255)     # Darker blue
      widget.textColor = Color(r: 255, g: 255, b: 255, a: 255)       # White
    widget.borderRadius = 4.0
    widget.onClick = nil
    widget.bounds.width = 120
    widget.bounds.height = 40

  render:
    when defined(useGraphics):
      # Choose color based on state
      var bgColor = widget.backgroundColor
      if widget.pressed:
        bgColor = widget.pressedColor
      elif widget.hovered:
        bgColor = widget.hoverColor

      # Draw button background
      drawRoundedRect(widget.bounds, widget.borderRadius, bgColor, true)

      # Draw border when focused
      if widget.focused:
        let borderColor = Color(r: 255, g: 255, b: 255, a: 180)
        drawRoundedRect(widget.bounds, widget.borderRadius, borderColor, false)

      # Draw text centered
      if widget.text.len > 0:
        let textStyle = TextStyle(
          fontFamily: "",
          fontSize: 16.0,
          color: widget.textColor,
          bold: false,
          italic: false,
          underline: false
        )
        drawText(widget.text, widget.bounds, textStyle, TextAlign.Center)

  on_click:
    # YAML-UI style event handler!
    echo "Button clicked: ", widget.text
    if widget.onClick != nil:
      widget.onClick()
