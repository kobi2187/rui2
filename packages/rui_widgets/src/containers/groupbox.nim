## GroupBox Widget - RUI2
##
## A bordered container with a title notched into the top border.
## Groups related controls together visually.

import rui_core
import rui_drawing

template padOf(w: untyped): float32 =
  ## Inner padding: the prop, else the theme's vertical padding (8 by default).
  (if w.padding >= 0: w.padding
   else: currentTheme.getThemeProps(w.intent).padding.get(EdgeInsets.all(8.0)).top)

template titleOf(w: untyped): float32 =
  ## The row the title sits in: the prop, else its caption line (20 at the
  ## default 14px text).
  (if w.titleHeight > 0: w.titleHeight
   else: max(20.0'f32, currentTheme.getThemeProps(w.intent).fontSize.get(14.0) + 6))

defineWidget(GroupBox):
  props:
    title: string = ""
    padding: float32 = -1.0      # < 0: the theme's padding
    titleHeight: float32 = 0.0   # Space for the title row; 0: the theme's caption line
    intent: ThemeIntent = Default

  layout:
    # Content sits below the title, inside the padding.
    let hasWidth = widget.bounds.width > 0
    let hasHeight = widget.bounds.height > 0
    let contentTop = widget.bounds.y + titleOf(widget) + padOf(widget)
    var maxChildWidth = 0.0'f32
    var maxChildBottom = contentTop

    for child in widget.children:
      child.bounds.x = widget.bounds.x + padOf(widget)
      child.bounds.y = contentTop
      if hasWidth:
        child.bounds.width = max(0.0'f32, widget.bounds.width - padOf(widget) * 2)
      if hasHeight:
        child.bounds.height = max(0.0'f32,
          widget.bounds.height - titleOf(widget) - padOf(widget) * 2)

      child.layout()

      maxChildWidth = max(maxChildWidth, child.bounds.width)
      maxChildBottom = max(maxChildBottom, child.bounds.y + child.bounds.height)

    if not hasWidth:
      let style = currentTheme.getThemeProps(widget.intent).captionStyle(BLACK, action = true)
      let titleWidth = measureText(widget.title, style).width + padOf(widget) * 4
      widget.bounds.width = max(maxChildWidth + padOf(widget) * 2, titleWidth)
    if not hasHeight:
      widget.bounds.height = (maxChildBottom - widget.bounds.y) + padOf(widget)

  render:
    # Children are composited by renderPass; only the frame is drawn here.
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    drawGroupBox(widget.bounds, widget.title, props)
