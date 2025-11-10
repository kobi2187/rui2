# Status bar
defineWidget StatusBar:
  props:
    text*: string
    rightText*: string

  render:
    GuiStatusBar(widget.toRaylibRect(), widget.text)

    if widget.rightText.len > 0:
      let rightRect = widget.rect
      rightRect.x = rightRect.x + rightRect.width -
                    measureText(widget.rightText, 10).x - 10
      GuiLabel(rightRect, widget.rightText)
