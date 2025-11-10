defineWidget Button:
  props:
    text: string
    onClick: proc()
    icon: Option[Icon]

  render:
    # Use raygui
    if GuiButton(widget.toRaylibRect(), widget.text):
      if widget.enabled and widget.onClick != nil:
        widget.onClick()

    # Draw icon if present
    if widget.icon.isSome:
      drawIcon(widget.icon.get, widget.getIconRect())

  input:
    if event.kind == ieMousePress and widget.enabled:
      widget.isPressed = true
      true
    elif event.kind == ieMouseRelease and widget.isPressed:
      widget.isPressed = false
      if widget.containsPoint(event.mousePos):
        widget.onClick()
      true
    else:
      false

  state:
    fields:
      text: string
      enabled: bool
      pressed: bool
      icon: Option[Icon]

# Helper for button creation
proc button*(text: string, onClick: proc()): Button =
  Button(
    text: text,
    onClick: onClick,
    enabled: true,
    visible: true
  )
