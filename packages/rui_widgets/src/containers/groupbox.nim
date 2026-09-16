## GroupBox Widget - RUI2
##
## A bordered container with a title notched into the top border.
## Groups related controls together visually.

import rui_core
import rui_drawing

defineWidget(GroupBox):
  props:
    title: string = ""
    padding: float32 = 8.0
    titleHeight: float32 = 20.0  # Space reserved for the title row
    intent: ThemeIntent = Default

  layout:
    # Content sits below the title, inside the padding.
    let hasWidth = widget.bounds.width > 0
    let hasHeight = widget.bounds.height > 0
    let contentTop = widget.bounds.y + widget.titleHeight + widget.padding
    var maxChildWidth = 0.0'f32
    var maxChildBottom = contentTop

    for child in widget.children:
      child.bounds.x = widget.bounds.x + widget.padding
      child.bounds.y = contentTop
      if hasWidth:
        child.bounds.width = max(0.0'f32, widget.bounds.width - widget.padding * 2)
      if hasHeight:
        child.bounds.height = max(0.0'f32,
          widget.bounds.height - widget.titleHeight - widget.padding * 2)

      child.layout()

      maxChildWidth = max(maxChildWidth, child.bounds.width)
      maxChildBottom = max(maxChildBottom, child.bounds.y + child.bounds.height)

    if not hasWidth:
      let style = TextStyle(fontFamily: "", fontSize: 14.0, color: BLACK,
                            bold: false, italic: false, underline: false)
      let titleWidth = measureText(widget.title, style).width + widget.padding * 4
      widget.bounds.width = max(maxChildWidth + widget.padding * 2, titleWidth)
    if not hasHeight:
      widget.bounds.height = (maxChildBottom - widget.bounds.y) + widget.padding

  render:
    # Children are composited by renderPass; only the frame is drawn here.
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    drawGroupBox(widget.bounds, widget.title, props)
