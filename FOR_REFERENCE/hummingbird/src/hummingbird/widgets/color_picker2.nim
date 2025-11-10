
# Color picker with palette
defineWidget ColorPicker:
  props:
    color*: Color
    showAlpha*: bool
    showPalette*: bool
    palette*: seq[Color]
    onColorChange*: proc(color: Color)

  render:
    var col = widget.color
    if GuiColorPicker(widget.toRaylibRect(), "", addr col):
      widget.color = col
      if widget.onColorChange != nil:
        widget.onColorChange(col)

    if widget.showPalette:
      let paletteRect = widget.getPaletteRect()
      for i, pColor in widget.palette:
        let swatchRect = Rectangle(
          x: paletteRect.x + (i mod 8).float32 * 20,
          y: paletteRect.y + (i div 8).float32 * 20,
          width: 18,
          height: 18
        )
        if GuiButton(swatchRect, ""):
          widget.color = pColor
          if widget.onColorChange != nil:
            widget.onColorChange(pColor)
