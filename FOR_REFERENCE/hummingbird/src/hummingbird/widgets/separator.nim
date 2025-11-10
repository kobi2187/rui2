
# Separator (horizontal or vertical line)
defineWidget Separator:
  props:
    vertical*: bool
    color*: Color = GRAY

  render:
    if widget.vertical:
      DrawLineV(
        Vector2(x: widget.rect.x + widget.rect.width/2, y: widget.rect.y),
        Vector2(x: widget.rect.x + widget.rect.width/2, y: widget.rect.y + widget.rect.height),
        widget.color
      )
    else:
      DrawLineH(
        Vector2(x: widget.rect.x, y: widget.rect.y + widget.rect.height/2),
        Vector2(x: widget.rect.x + widget.rect.width, y: widget.rect.y + widget.rect.height/2),
        widget.color
      )
