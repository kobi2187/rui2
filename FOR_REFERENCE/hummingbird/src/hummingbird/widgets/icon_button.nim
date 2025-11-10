
# Icon button
defineWidget IconButton:
  props:
    icon*: IconData    # Could be enum for built-in icons or custom image
    tooltip*: string
    onClick*: proc()

  render:
    if GuiImageButton(
      widget.toRaylibRect(),
      widget.icon.texture,
      widget.icon.source
    ):
      if widget.onClick != nil:
        widget.onClick()

    if widget.tooltip.len > 0 and widget.isHovered:
      # Show tooltip...
      discard
