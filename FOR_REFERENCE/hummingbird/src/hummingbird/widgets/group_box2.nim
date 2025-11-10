
# Group box / Panel
defineWidget GroupBox:
  props:
    title: string
    padding: EdgeInsets

  render:
    GuiGroupBox(
      widget.toRaylibRect(),
      widget.title
    )

    # Draw children with padding
    let childRect = widget.getContentRect()
    for child in widget.children:
      child.draw()

  state:
    fields:
      title: string
      padding: EdgeInsets
