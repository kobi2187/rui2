
# Color gradient editor
defineWidget GradientEditor:
  props:
    stops: seq[GradientStop]
    onStopAdd: proc(stop: GradientStop)
    onStopMove: proc(index: int, position: float32)
    onStopDelete: proc(index: int)
    onColorChange: proc(index: int, color: Color)

  type GradientStop* = object
    position*: float32  # 0.0 to 1.0
    color*: Color

  render:
    # Draw gradient preview
    let gradientRect = Rectangle(
      x: widget.rect.x,
      y: widget.rect.y,
      width: widget.rect.width,
      height: 20
    )
    drawGradient(gradientRect, widget.stops)

    # Draw stop handles
    for i, stop in widget.stops:
      let handleRect = Rectangle(
        x: widget.rect.x + stop.position * widget.rect.width - 5,
        y: widget.rect.y + 25,
        width: 10,
        height: 20
      )

      if GuiButton(handleRect, ""):
        # Show color picker
        var newColor = stop.color
        if colorPicker(addr newColor):
          widget.onColorChange(i, newColor)