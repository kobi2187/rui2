## Separator Widget - RUI2
##
## A visual separator line for dividing UI sections.
## Can be horizontal or vertical.

import rui_core
import rui_drawing

definePrimitive(Separator):
  props:
    vertical: bool = false
    thickness: float32 = 1.0
    intent: ThemeIntent = Default

  layout:
    # A separator only has an opinion about its cross axis; the stack that owns
    # it decides how long it is.
    if widget.vertical:
      if widget.bounds.width <= 0:
        widget.bounds.width = max(widget.thickness, 1.0'f32)
    else:
      if widget.bounds.height <= 0:
        widget.bounds.height = max(widget.thickness, 1.0'f32)

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let color = props.borderColor.get(Color(r: 128, g: 128, b: 128, a: 255))

    if widget.vertical:
      let x = widget.bounds.x + widget.bounds.width / 2
      drawLine(x, widget.bounds.y,
               x, widget.bounds.y + widget.bounds.height,
               color, widget.thickness)
    else:
      let y = widget.bounds.y + widget.bounds.height / 2
      drawLine(widget.bounds.x, y,
               widget.bounds.x + widget.bounds.width, y,
               color, widget.thickness)
