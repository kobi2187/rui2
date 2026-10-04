## ToolBar Widget - RUI2
##
## A horizontal strip of quick-access controls, normally docked under a MenuBar.
## Children keep their own width if they have one, otherwise they are squared off
## to the toolbar's content height. A toolbar with no height of its own grows
## to fit its tallest child.
##
## A toolbar is a **focus group**: one Tab stop however many buttons it holds,
## with Left and Right moving between them once entered. A strip of twelve tool
## buttons that cost twelve Tab presses to get past is the case focus groups
## exist for.

import rui_core
import rui_drawing

template barHeightOf(w: untyped): float32 =
  ## Bar height: the prop, else the theme's.
  themedSize(w.barHeight, currentTheme.barHeight(32.0))

defineWidget(ToolBar):
  props:
    barHeight: float32 = 0.0   # 0: from the theme
    spacing: float32 = 2.0
    padding: float32 = 4.0
    showBorder: bool = true
    intent: ThemeIntent = Default

  init:
    widget.focusGroup = true

  layout:
    if widget.bounds.height <= 0:
      # Tall enough for the tallest child's natural height, and never less
      # than barHeight. Forcing barHeight on captioned ToolButtons pushed
      # their captions up onto their icons.
      var tallest = 0.0'f32
      for child in widget.children:
        child.bounds.height = 0
        child.layout()
        tallest = max(tallest, child.bounds.height)
      widget.bounds.height = max(barHeightOf(widget), tallest + widget.padding * 2)

    let itemHeight = max(0.0'f32, widget.bounds.height - widget.padding * 2)
    var x = widget.bounds.x + widget.padding

    for child in widget.children:
      child.bounds.x = x
      child.bounds.y = widget.bounds.y + widget.padding
      child.bounds.height = itemHeight
      child.layout()

      # A child that still has no width of its own gets a square slot.
      if child.bounds.width <= 0:
        child.bounds.width = itemHeight

      x += child.bounds.width + widget.spacing

    if widget.bounds.width <= 0:
      let contentRight = if widget.children.len > 0: x - widget.spacing
                         else: widget.bounds.x + widget.padding
      widget.bounds.width = (contentRight - widget.bounds.x) + widget.padding

  render:
    # Children are composited by renderPass; only the strip is drawn here.
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    drawThemedBackground(widget.bounds, props)

    if widget.showBorder:
      let borderColor = props.borderColor.get(Color(r: 200, g: 200, b: 200, a: 255))
      drawLine(widget.bounds.x, widget.bounds.y + widget.bounds.height,
               widget.bounds.x + widget.bounds.width,
               widget.bounds.y + widget.bounds.height,
               borderColor)
