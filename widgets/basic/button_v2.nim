## Button Widget (DSL v2)
##
## Composite widget: Rectangle (background) + Label (text)
## Responds to mouse clicks

import ../../core/widget_dsl_v3
import ../primitives/[rectangle, label]
import raylib
import std/[options, json]

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

    # Calculate button color based on state
    var buttonColor = widget.bgColor
    if widget.disabled:
      buttonColor = LIGHTGRAY
    elif widget.isPressed:
      buttonColor = DARKGRAY
    elif widget.isHovered:
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

# ============================================================================
# Scripting Support
# ============================================================================

method handleScriptAction*(widget: Button, action: string, params: JsonNode): JsonNode =
  ## Handle scripting actions for Button widget
  case action
  of "click":
    if not widget.disabled and widget.scriptable:
      # Trigger onClick callback
      if widget.onClick.isSome:
        widget.onClick.get()()
      return %*{"success": true, "clicked": true}
    else:
      return %*{"success": false, "error": "Button is disabled or not scriptable"}

  of "getText":
    if not widget.blockReading:
      return %*{"success": true, "text": widget.text}
    else:
      return %*{"success": false, "error": "Reading blocked"}

  of "setText":
    if widget.scriptable and params.hasKey("text"):
      widget.text = params["text"].getStr()
      widget.isDirty = true
      return %*{"success": true}
    else:
      return %*{"success": false, "error": "Missing 'text' parameter or not scriptable"}

  of "enable":
    widget.disabled = false
    widget.isDirty = true
    return %*{"success": true}

  of "disable":
    widget.disabled = true
    widget.isDirty = true
    return %*{"success": true}

  else:
    return %*{"success": false, "error": "Unknown action: " & action}

method getScriptableState*(widget: Button): JsonNode =
  ## Get current state of Button as JSON
  result = %*{
    "id": widget.stringId,
    "type": "Button",
    "visible": widget.visible,
    "enabled": not widget.disabled,
    "scriptable": widget.scriptable,
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
