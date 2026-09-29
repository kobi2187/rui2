## Wrap -- children in runs that break at the edge.
##
## Flutter's Wrap, horizontal: children left to right at their natural size,
## starting a new run whenever the next one would cross the right edge. Each
## run is spread by `alignment` and its children placed vertically within it
## by `crossAxisAlignment`. It needs a width to wrap against; without one
## everything is a single run.
##
## ```nim
## ui:
##   Wrap(spacing = 8.0, runSpacing = 8.0):
##     for tag in tags:
##       Button(text = tag)
## ```

import rui_core

type
  WrapAlignment* = MainAxisAlignment
    ## How each run spends its spare width (start, center, end, space*).

  WrapCrossAlignment* {.pure.} = enum
    ## Where a child sits within its run's height.
    start, center, `end`

proc lineBreaks*(widths: openArray[float32], available, spacing: float32): seq[int] =
  ## Index of the first child of each run. A child wider than the whole run
  ## still gets a run of its own rather than an empty run before it.
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
    spacing: float32 = 0.0        # between children in a run
    runSpacing: float32 = 0.0     # between runs
    alignment: WrapAlignment = MainAxisAlignment.start
    crossAxisAlignment: WrapCrossAlignment = WrapCrossAlignment.start

  layout:
    let hasWidth = widget.bounds.width > 0
    var widths: seq[float32]
    for child in widget.children:
      child.bounds.width = 0
      child.bounds.height = 0
      child.layout()
      widths.add child.bounds.width

    let runs = lineBreaks(widths, (if hasWidth: widget.bounds.width else: 0.0'f32),
                          widget.spacing)
    var y = 0.0'f32
    var widest = 0.0'f32
    for r, first in runs:
      let last = (if r + 1 < runs.len: runs[r + 1] else: widget.children.len) - 1
      var runWidth, runHeight = 0.0'f32
      for i in first .. last:
        runWidth += widths[i]
        runHeight = max(runHeight, widget.children[i].bounds.height)
      let count = last - first + 1
      let extent = if hasWidth: widget.bounds.width
                   else: runWidth + totalSpacing(count, widget.spacing)
      let (gap, start) = calculateDistributedSpacing(widget.alignment, extent,
                                                     runWidth, count, widget.spacing)
      var x = start
      for i in first .. last:
        let child = widget.children[i]
        let dy = case widget.crossAxisAlignment
                 of WrapCrossAlignment.start: 0.0'f32
                 of WrapCrossAlignment.center: (runHeight - child.bounds.height) / 2
                 of WrapCrossAlignment.`end`: runHeight - child.bounds.height
        child.bounds.x = widget.bounds.x + x
        child.bounds.y = widget.bounds.y + y + dy
        child.layout()
        x += widths[i] + gap
      widest = max(widest, runWidth + totalSpacing(count, widget.spacing))
      y += runHeight + widget.runSpacing

    if not hasWidth:
      widget.bounds.width = widest
    if widget.bounds.height <= 0:
      widget.bounds.height = max(0.0'f32, y - (if runs.len > 0: widget.runSpacing else: 0.0'f32))
