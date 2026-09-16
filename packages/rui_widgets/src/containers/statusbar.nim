## StatusBar Widget - RUI2
##
## A status strip, normally docked at the bottom of a window: left-aligned
## message, optional right-aligned text (counts, position, mode...).

import rui_core
import rui_drawing

definePrimitive(StatusBar):
  props:
    text: string = ""
    rightText: string = ""
    barHeight: float32 = 24.0
    fontSize: float32 = 10.0
    intent: ThemeIntent = Default

  layout:
    # Full width comes from the parent; only the height is ours to decide.
    if widget.bounds.height <= 0:
      widget.bounds.height = widget.barHeight
    if widget.bounds.width <= 0:
      let style = TextStyle(fontFamily: "", fontSize: widget.fontSize, color: BLACK,
                            bold: false, italic: false, underline: false)
      widget.bounds.width = measureText(widget.text, style).width +
                            measureText(widget.rightText, style).width + 40.0

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    drawStatusBar(widget.bounds, widget.text, props)

    if widget.rightText.len > 0:
      let style = TextStyle(fontFamily: "", fontSize: widget.fontSize, color: BLACK,
                            bold: false, italic: false, underline: false)
      let m = measureText(widget.rightText, style)
      let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
      drawText(widget.rightText,
               widget.bounds.x + widget.bounds.width - m.width - 10.0,
               widget.bounds.y + (widget.bounds.height - widget.fontSize) / 2,
               widget.fontSize, textColor)
