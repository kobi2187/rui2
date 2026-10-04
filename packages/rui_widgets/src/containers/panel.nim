## Panel Container Widget - RUI2
##
## A bordered container with optional background and padding.
## Foundation for GroupBox, dialogs and other framed containers.

import rui_core
import rui_drawing

template padOf(w: untyped): float32 =
  ## Inner padding: the prop, else the theme's vertical padding (8 by default).
  (if w.padding >= 0: w.padding
   else: currentTheme.getThemeProps(w.intent).padding.get(EdgeInsets.all(8.0)).top)

template strokeOf(w: untyped): float32 =
  (if w.borderWidth >= 0: w.borderWidth else: currentTheme.getThemeProps(w.intent).strokeWidth)

template radiusOf(w: untyped): float32 =
  (if w.cornerRadius >= 0: w.cornerRadius else: currentTheme.getThemeProps(w.intent).cornerRadius.get(0.0))

defineWidget(Panel):
  props:
    padding: float32 = -1.0       # < 0: the theme's padding
    borderWidth: float32 = -1.0   # < 0: the theme's stroke width
    cornerRadius: float32 = -1.0  # < 0: the theme's corner radius
    showBackground: bool = true
    showBorder: bool = true
    intent: ThemeIntent = Default

  layout:
    # Children fill the panel inside the padding. Give a child a zero width and
    # it measures itself; otherwise it is stretched to the content box.
    let hasWidth = widget.bounds.width > 0
    let hasHeight = widget.bounds.height > 0
    var maxChildWidth = 0.0'f32
    var maxChildBottom = widget.bounds.y + padOf(widget)

    for child in widget.children:
      child.bounds.x = widget.bounds.x + padOf(widget)
      child.bounds.y = widget.bounds.y + padOf(widget)
      if hasWidth:
        child.bounds.width = max(0.0'f32, widget.bounds.width - padOf(widget) * 2)
      if hasHeight:
        child.bounds.height = max(0.0'f32, widget.bounds.height - padOf(widget) * 2)

      child.layout()

      maxChildWidth = max(maxChildWidth, child.bounds.width)
      maxChildBottom = max(maxChildBottom, child.bounds.y + child.bounds.height)

    if not hasWidth:
      widget.bounds.width = maxChildWidth + padOf(widget) * 2
    if not hasHeight:
      widget.bounds.height = (maxChildBottom - widget.bounds.y) + padOf(widget)

  render:
    # Children are composited by renderPass; only the frame is drawn here.
    let props = currentTheme.getThemeProps(widget.intent, Normal)

    let fill = if widget.showBackground:
                 props.backgroundColor.get(Color(r: 245, g: 245, b: 245, a: 255))
               else: Color(r: 0, g: 0, b: 0, a: 0)
    let stroke = if widget.showBorder: strokeOf(widget) else: 0.0'f32
    drawBox(widget.bounds, radiusOf(widget), fill,
            props.borderColor.get(Color(r: 180, g: 180, b: 180, a: 255)), stroke)
