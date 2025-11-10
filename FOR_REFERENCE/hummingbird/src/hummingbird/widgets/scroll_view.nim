
# Scrollable container
defineWidget ScrollView:
  props:
    contentSize: Size  # Size of content
    scrollX: bool     # Allow horizontal scroll
    scrollY: bool     # Allow vertical scroll
    scrollOffset: Point

  render:
    let viewRect = widget.rect
    let contentRect = Rectangle(
      x: 0,
      y: 0,
      width: widget.contentSize.width,
      height: widget.contentSize.height
    )

    # Handle scrollbars
    if widget.scrollY:
      let scrollY = GuiScrollBar(
        Rectangle(
          x: viewRect.x + viewRect.width - 12,
          y: viewRect.y,
          width: 12,
          height: viewRect.height
        ),
        widget.scrollOffset.y,
        0,
        max(0, contentRect.height - viewRect.height)
      )
      widget.scrollOffset.y = scrollY

    if widget.scrollX:
      let scrollX = GuiScrollBar(
        Rectangle(
          x: viewRect.x,
          y: viewRect.y + viewRect.height - 12,
          width: viewRect.width - 12,
          height: 12
        ),
        widget.scrollOffset.x,
        0,
        max(0, contentRect.width - viewRect.width)
      )
      widget.scrollOffset.x = scrollX

    # Draw content with scissor
    BeginScissorMode(
      viewRect.x.int32,
      viewRect.y.int32,
      viewRect.width.int32,
      viewRect.height.int32
    )

    for child in widget.children:
      child.rect.x -= widget.scrollOffset.x
      child.rect.y -= widget.scrollOffset.y
      child.draw()
      child.rect.x += widget.scrollOffset.x
      child.rect.y += widget.scrollOffset.y

    EndScissorMode()

  input:
    if event.kind == ieMouseWheel and widget.scrollY:
      widget.scrollOffset.y = clamp(
        widget.scrollOffset.y - event.wheelDelta * 20,
        0,
        max(0, widget.contentSize.height - widget.rect.height)
      )
      true
    else:
      false
