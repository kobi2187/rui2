## Panel Container Widget - RUI2
##
## A bordered container with optional background and padding.
## Foundation for GroupBox, dialogs and other framed containers.

import rui_core
import rui_drawing

defineWidget(Panel):
  props:
    padding: float32 = 8.0
    borderWidth: float32 = 1.0
    cornerRadius: float32 = 0.0
    showBackground: bool = true
    showBorder: bool = true
    intent: ThemeIntent = Default

  layout:
    # Children fill the panel inside the padding. Give a child a zero width and
    # it measures itself; otherwise it is stretched to the content box.
    let hasWidth = widget.bounds.width > 0
    let hasHeight = widget.bounds.height > 0
    var maxChildWidth = 0.0'f32
    var maxChildBottom = widget.bounds.y + widget.padding

    for child in widget.children:
      child.bounds.x = widget.bounds.x + widget.padding
      child.bounds.y = widget.bounds.y + widget.padding
      if hasWidth:
        child.bounds.width = max(0.0'f32, widget.bounds.width - widget.padding * 2)
      if hasHeight:
        child.bounds.height = max(0.0'f32, widget.bounds.height - widget.padding * 2)

      child.layout()

      maxChildWidth = max(maxChildWidth, child.bounds.width)
      maxChildBottom = max(maxChildBottom, child.bounds.y + child.bounds.height)

    if not hasWidth:
      widget.bounds.width = maxChildWidth + widget.padding * 2
    if not hasHeight:
      widget.bounds.height = (maxChildBottom - widget.bounds.y) + widget.padding

  render:
    # Children are composited by renderPass; only the frame is drawn here.
    let props = currentTheme.getThemeProps(widget.intent, Normal)

    if widget.showBackground:
      if widget.cornerRadius > 0:
        drawRoundedRect(widget.bounds, widget.cornerRadius,
                        props.backgroundColor.get(Color(r: 245, g: 245, b: 245, a: 255)),
                        true)
      else:
        drawThemedBackground(widget.bounds, props)

    if widget.showBorder:
      if widget.cornerRadius > 0:
        drawRoundedRectLines(widget.bounds, widget.cornerRadius, widget.borderWidth,
                             props.borderColor.get(Color(r: 180, g: 180, b: 180, a: 255)))
      else:
        drawThemedBorder(widget.bounds, props)
