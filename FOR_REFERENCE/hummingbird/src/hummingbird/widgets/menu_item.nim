
# Menu item
defineWidget MenuItem:
  props:
    text*: string
    shortcut*: string
    enabled*: bool = true
    checked*: bool = false
    onClick*: proc()

  render:
    var text = widget.text
    if widget.shortcut.len > 0:
      text &= "\t" & widget.shortcut

    if GuiMenuItem(widget.toRaylibRect(), text):
      if widget.enabled and widget.onClick != nil:
        widget.onClick()

