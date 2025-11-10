
# Link (clickable text)
defineWidget Link:
  props:
    text*: string
    url*: string
    visited*: bool
    onClick*: proc()

  render:
    let color = if widget.visited: PURPLE else: BLUE
    if GuiLabelButton(widget.toRaylibRect(), widget.text):
      if widget.onClick != nil:
        widget.onClick()
      widget.visited = true
