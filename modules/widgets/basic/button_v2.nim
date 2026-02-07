## Button Widget (DSL v2)
##
## Composite widget: Rectangle (background) + Label (text)
## Responds to mouse clicks

import ../../../core/widget_dsl
import ../../../drawing_primitives/widget_primitives
import ../primitives/[rectangle, label]
import raylib
import std/[options, json]

defineWidget(Button):
  props:
    text: string
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    isPressed: bool
    isHovered: bool

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

    on_mouse_move:
      # Check if mouse is over widget
      let mouseX = event.mousePos.x
      let mouseY = event.mousePos.y
      let isOver = mouseX >= widget.bounds.x and
                   mouseX <= widget.bounds.x + widget.bounds.width and
                   mouseY >= widget.bounds.y and
                   mouseY <= widget.bounds.y + widget.bounds.height
      widget.isHovered = isOver
      return false

  layout:
    # Clear children before recreating (layout is called on every dirty)
    widget.children.setLen(0)

    # Look up theme colors based on widget state
    let state = if widget.disabled: Disabled
                elif widget.isPressed: Pressed
                elif widget.isHovered: Hovered
                else: Normal
    let props = currentTheme.getThemeProps(widget.intent, state)

    let buttonColor = props.backgroundColor.get(GRAY)
    let textColor = props.foregroundColor.get(WHITE)
    let radius = props.cornerRadius.get(4.0f32)

    # Create background rectangle
    let bg = newRectangle(
      color = buttonColor,
      cornerRadius = radius,
      filled = true
    )
    bg.bounds = widget.bounds
    widget.children.add(bg)

    # Create label (centered)
    let textLabel = newLabel(
      text = widget.text,
      fontSize = props.fontSize.get(14.0f32),
      color = textColor
    )
    # Position label in center of button (rough approximation for now)
    textLabel.bounds = Rect(
      x: widget.bounds.x + 10,
      y: widget.bounds.y + (widget.bounds.height - 14) / 2,
      width: widget.bounds.width - 20,
      height: 14
    )
    widget.children.add(textLabel)

# ============================================================================
# Scripting Support
# ============================================================================

method handleScriptAction*(widget: Button, action: string, params: JsonNode): JsonNode =
  ## Handle scripting actions for Button widget
  ## Scripts can operate the button (click, read) but not modify it
  case action
  of "click":
    if not widget.disabled:
      # Trigger onClick callback
      if widget.onClick.isSome:
        widget.onClick.get()()
      return %*{"success": true, "clicked": true}
    else:
      return %*{"success": false, "error": "Button is disabled"}

  of "getText":
    if not widget.blockReading:
      return %*{"success": true, "text": widget.text}
    else:
      return %*{"success": false, "error": "Reading blocked"}

  else:
    return %*{"success": false, "error": "Unknown action: " & action}

method getScriptableState*(widget: Button): JsonNode =
  ## Get current state of Button as JSON
  result = %*{
    "id": widget.stringId,
    "type": "Button",
    "visible": widget.visible,
    "enabled": not widget.disabled,
    "pressed": widget.isPressed,
    "hovered": widget.isHovered,
    "bounds": {
      "x": widget.bounds.x,
      "y": widget.bounds.y,
      "width": widget.bounds.width,
      "height": widget.bounds.height
    }
  }

  # Add text if reading not blocked
  if not widget.blockReading:
    result["text"] = %widget.text

method getTypeName*(widget: Button): string =
  ## Return the widget type name
  "Button"
