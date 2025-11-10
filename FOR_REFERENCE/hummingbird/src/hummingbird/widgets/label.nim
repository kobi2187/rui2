
# Basic text display
defineWidget Label:
  props:
    text: string
    wrap: bool
    alignment: TextAlignment
    fontSize: Option[int]

  render:
    let style = GuiGetStyle(DEFAULT, TEXT_SIZE)
    if widget.fontSize.isSome:
      GuiSetStyle(DEFAULT, TEXT_SIZE, widget.fontSize.get)

    GuiLabel(widget.toRaylibRect(), widget.text)

    if widget.fontSize.isSome:
      GuiSetStyle(DEFAULT, TEXT_SIZE, style)  # Restore style
