# Tooltip
defineWidget Tooltip:
  props:
    text*: string
    delay*: float = 0.5  # Seconds before showing
    parent*: Widget      # Widget this tooltip belongs to

  render:
    if widget.parent.isHovered:
      if widget.hoverTime >= widget.delay:
        let mousePos = getMousePosition()
        GuiLabel(
          Rectangle(
            x: mousePos.x + 10,
            y: mousePos.y + 10,
            width: measureText(widget.text, 10).x + 10,
            height: 20
          ),
          widget.text
        )
