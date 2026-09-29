## Wrap Container Widget
##
## Children left to right at their natural size, starting a new line whenever
## the next one would cross the right edge -- tags, chips, a toolbar that
## reflows when the window narrows. Within a line, `crossAlign` places each
## child vertically against the line's tallest.
##
## It needs a width to wrap against; one that sizes to its content has no edge
## to cross, and lays everything out on a single line.

import rui_core

proc lineBreaks*(widths: openArray[float32], available, spacing: float32): seq[int] =
  ## Index of the first child on each line. A child wider than the whole line
  ## still gets a line of its own rather than an empty line before it.
  if widths.len == 0:
    return
  result.add 0
  if available <= 0:
    return
  var x = 0.0'f32
  for i, w in widths:
    if i > result[^1] and x + w > available:
      result.add i
      x = 0
    x += w + spacing

defineWidget(Wrap):
  props:
    spacing: float32 = 8.0       # between children on a line
    lineSpacing: float32 = 8.0   # between lines
    padding: float32 = 0.0
    crossAlign: CrossAxisAlignment = CrossCenter

  layout:
    let pad = widget.padding
    let hasWidth = widget.bounds.width > 0
    var widths: seq[float32]
    for child in widget.children:
      child.bounds.width = 0
      child.bounds.height = 0
      child.layout()
      widths.add child.bounds.width

    let inner = if hasWidth: widget.bounds.width - pad * 2 else: 0.0'f32
    let starts = lineBreaks(widths, inner, widget.spacing)

    var y = widget.bounds.y + pad
    var widest = 0.0'f32
    for li, first in starts:
      let last = (if li + 1 < starts.len: starts[li + 1] else: widget.children.len) - 1
      var x = widget.bounds.x + pad
      var lineHeight = 0.0'f32
      for i in first .. last:
        lineHeight = max(lineHeight, widget.children[i].bounds.height)
      for i in first .. last:
        let child = widget.children[i]
        child.bounds.x = x
        child.bounds.y = y + crossOffset(widget.crossAlign, lineHeight,
                                         child.bounds.height)
        child.layout()
        x += child.bounds.width + widget.spacing
      widest = max(widest, x - widget.spacing - widget.bounds.x - pad)
      y += lineHeight + widget.lineSpacing

    let contentBottom = if starts.len > 0: y - widget.lineSpacing
                        else: widget.bounds.y + pad
    if not hasWidth:
      widget.bounds.width = widest + pad * 2
    if widget.bounds.height <= 0:
      widget.bounds.height = contentBottom - widget.bounds.y + pad
