## Align and Center
##
## Places its content within its own box: left, centred, right or stretched
## across, and the same up and down. Each child keeps its natural size unless
## told to stretch. With no size of its own, an Align wraps its content (plus
## padding), which makes it a padding container as well.
##
## `Center` is an Align centred both ways -- the most common use:
##
## ```nim
## ui:
##   Center().frame(height = 200):
##     Label(text = "Nothing here yet")
## ```

import rui_core

defineWidget(Align):
  props:
    horizontal: CrossAxisAlignment = CrossStart
    vertical: CrossAxisAlignment = CrossStart
    padding: float32 = 0.0

  layout:
    let pad = widget.padding
    let hasWidth = widget.bounds.width > 0
    let hasHeight = widget.bounds.height > 0
    var widest, tallest = 0.0'f32

    for child in widget.children:
      child.bounds.width =
        if hasWidth and widget.horizontal == CrossStretch: widget.bounds.width - pad * 2
        else: 0.0'f32
      child.bounds.height =
        if hasHeight and widget.vertical == CrossStretch: widget.bounds.height - pad * 2
        else: 0.0'f32
      child.bounds.x = widget.bounds.x + pad
      child.bounds.y = widget.bounds.y + pad
      child.layout()
      widest = max(widest, child.bounds.width)
      tallest = max(tallest, child.bounds.height)

    if not hasWidth: widget.bounds.width = widest + pad * 2
    if not hasHeight: widget.bounds.height = tallest + pad * 2

    let innerW = widget.bounds.width - pad * 2
    let innerH = widget.bounds.height - pad * 2
    for child in widget.children:
      let dx = crossOffset(widget.horizontal, innerW, child.bounds.width)
      let dy = crossOffset(widget.vertical, innerH, child.bounds.height)
      if dx != 0 or dy != 0:
        child.bounds.x += dx
        child.bounds.y += dy
        child.layout()

type Center* = Align
  ## An Align centred both ways.

proc newCenter*(padding = 0.0'f32): Center =
  newAlign(horizontal = CrossCenter, vertical = CrossCenter, padding = padding)
