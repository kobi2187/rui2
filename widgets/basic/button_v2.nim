## Button Widget (DSL v2)
##
## Composite widget: Rectangle (background) + Label (text)
## Responds to mouse clicks

import ../../core/widget_dsl_v2
import ../primitives/[rectangle, label]
import raylib
import std/options

defineWidget(Button):
  props:
    text: string
    bgColor: raylib.Color = GRAY
    textColor: raylib.Color = WHITE
    disabled: bool = false

  state:
    isPressed: bool
    isHovered: bool

  actions:
    onClick()

  events:
    on_mouse_down:
      if not widget.disabled:
        widget.isPressed.set(true)
        return true
      return false

    on_mouse_up:
      if widget.isPressed.get() and not widget.disabled:
        widget.isPressed.set(false)
        if widget.onClick.isSome:
          widget.onClick.get()()
        return true
      return false

    on_mouse_move:
      # Check if mouse is over widget
      let mouseX = event.mousePos.x
      let mouseY = event.mousePos.y
      let isOver = mouseX >= widget.bounds.x and
                   mouseX <= widget.bounds.x + widget.bounds.width and
                   mouseY >= widget.bounds.y and
                   mouseY <= widget.bounds.y + widget.bounds.height
      widget.isHovered.set(isOver)
      return false

  layout:
    # Clear children before recreating (layout is called on every dirty)
    widget.children.setLen(0)

    # Calculate button color based on state
    var buttonColor = widget.bgColor
    if widget.disabled:
      buttonColor = LIGHTGRAY
    elif widget.isPressed.get():
      buttonColor = DARKGRAY
    elif widget.isHovered.get():
      # Lighten color slightly
      buttonColor = raylib.Color(
        r: uint8(min(255, int(widget.bgColor.r) + 20)),
        g: uint8(min(255, int(widget.bgColor.g) + 20)),
        b: uint8(min(255, int(widget.bgColor.b) + 20)),
        a: widget.bgColor.a
      )

    # Create background rectangle
    let bg = newRectangle(
      color = buttonColor,
      cornerRadius = 4.0,
      filled = true
    )
    bg.bounds = widget.bounds
    widget.children.add(bg)

    # Create label (centered)
    # TODO: Properly measure text and center it
    let textLabel = newLabel(
      text = widget.text,
      fontSize = 14.0,
      color = if widget.disabled: GRAY else: widget.textColor
    )
    # Position label in center of button (rough approximation for now)
    textLabel.bounds = Rect(
      x: widget.bounds.x + 10,
      y: widget.bounds.y + (widget.bounds.height - 14) / 2,
      width: widget.bounds.width - 20,
      height: 14
    )
    widget.children.add(textLabel)
