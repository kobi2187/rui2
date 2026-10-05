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

type WrapPlan = object
  rects: seq[Rect]      # each child, relative to the Wrap's corner
  own: Size

proc planWrap[W](widget: W, c: Constraints): WrapPlan =
  ## Children at their natural size, broken into runs that fit the width.
  let hasWidth = c.tightWidth and c.minWidth > 0
  var sizes: seq[Size]
  var widths: seq[float32]
  for child in widget.children:
    let s = child.measure(unbounded())
    sizes.add s
    widths.add s.width
  let runs = lineBreaks(widths, (if hasWidth: c.minWidth else: 0.0'f32), widget.spacing)
  result.rects.setLen(widget.children.len)
  var y = 0.0'f32
  var widest = 0.0'f32
  for r, first in runs:
    let last = (if r + 1 < runs.len: runs[r + 1] else: widget.children.len) - 1
    var runWidth, runHeight = 0.0'f32
    for i in first .. last:
      runWidth += widths[i]
      runHeight = max(runHeight, sizes[i].height)
    let count = last - first + 1
    let extent = if hasWidth: c.minWidth
                 else: runWidth + totalSpacing(count, widget.spacing)
    let (gap, start) = calculateDistributedSpacing(widget.alignment, extent,
                                                   runWidth, count, widget.spacing)
    var x = start
    for i in first .. last:
      let dy = case widget.crossAxisAlignment
               of WrapCrossAlignment.start: 0.0'f32
               of WrapCrossAlignment.center: (runHeight - sizes[i].height) / 2
               of WrapCrossAlignment.`end`: runHeight - sizes[i].height
      result.rects[i] = Rect(x: x, y: y + dy, width: sizes[i].width, height: sizes[i].height)
      x += widths[i] + gap
    widest = max(widest, runWidth + totalSpacing(count, widget.spacing))
    y += runHeight + widget.runSpacing
  result.own = Size(
    width: (if hasWidth: c.minWidth else: widest),
    height: (if c.tightHeight and c.minHeight > 0: c.minHeight
             else: max(0.0'f32, y - (if runs.len > 0: widget.runSpacing else: 0.0'f32))))

defineWidget(Wrap):
  props:
    spacing: float32 = 0.0        # between children in a run
    runSpacing: float32 = 0.0     # between runs
    alignment: WrapAlignment = MainAxisAlignment.start
    crossAxisAlignment: WrapCrossAlignment = WrapCrossAlignment.start

  layout:
    let plan = widget.planWrap(constraintsOf(widget.bounds))
    widget.bounds.width = plan.own.width
    widget.bounds.height = plan.own.height
    for i, child in widget.children:
      let r = plan.rects[i]
      child.arrange(Rect(x: widget.bounds.x + r.x, y: widget.bounds.y + r.y,
                         width: r.width, height: r.height))

method computeSize*(widget: Wrap, c: Constraints): Size = widget.planWrap(c).own
