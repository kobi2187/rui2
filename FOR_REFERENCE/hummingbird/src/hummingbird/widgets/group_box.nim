# Group box (frame with title)
defineWidget GroupBox:
  props:
    title*: string

  render:
    GuiGroupBox(widget.toRaylibRect(), widget.title)

    # Render children with adjusted rectangle
    let contentRect = Rectangle(
      x: widget.rect.x + 5,
      y: widget.rect.y + 20,
      width: widget.rect.width - 10,
      height: widget.rect.height - 25
    )

    for child in widget.children:
      child.rect = contentRect
      child.draw()
