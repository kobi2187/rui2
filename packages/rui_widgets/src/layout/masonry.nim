## Masonry -- cards of different heights in columns, each placed in whichever
## column is shortest so far: a photo wall, a board of notes.
##
## ```nim
## ui:
##   Masonry(minColumnWidth = 180, spacing = 10):
##     for note in notes:
##       Card(): Label(text = note, wrap = true)
## ```
##
## Every child is as wide as a column and as tall as it wants at that width.
## The number of columns is `columns`, or as many `minColumnWidth`-wide
## columns as fit when `columns` is 0. It needs a width; without one it is a
## single column.

import rui_core

proc columnsFor*(width, minColumnWidth, spacing: float32, columns: int): int =
  ## How many columns: `columns` when set, else as many of `minColumnWidth` as fit.
  if columns > 0: return columns
  if width <= 0 or minColumnWidth <= 0: return 1
  max(1, int((width + spacing) / (minColumnWidth + spacing)))

type MasonryPlan = object
  rects: seq[Rect]      # each child, relative to the Masonry's corner
  own: Size

proc planMasonry[W](widget: W, c: Constraints): MasonryPlan =
  let width = if c.tightWidth and c.minWidth > 0: c.minWidth
              elif c.maxWidth < Inf: c.maxWidth
              else: 0'f32
  let n = columnsFor(width, widget.minColumnWidth, widget.spacing, widget.columns)
  let colW = if width > 0: (width - widget.spacing * float32(n - 1)) / float32(n)
             else: widget.minColumnWidth
  var heights = newSeq[float32](n)
  result.rects.setLen(widget.children.len)
  for i, child in widget.children:
    var col = 0
    for k in 1 ..< n:
      if heights[k] < heights[col]: col = k        # the shortest, leftmost on a tie
    let s = child.measure(Constraints(minWidth: colW, maxWidth: colW, minHeight: 0, maxHeight: Inf))
    let y = heights[col] + (if heights[col] > 0: widget.spacing else: 0'f32)
    result.rects[i] = Rect(x: float32(col) * (colW + widget.spacing), y: y,
                           width: colW, height: s.height)
    heights[col] = y + s.height
  var tallest = 0'f32
  for h in heights: tallest = max(tallest, h)
  result.own = Size(width: (if width > 0: width else: colW),
                    height: (if c.tightHeight and c.minHeight > 0: c.minHeight else: tallest))

defineWidget(Masonry):
  props:
    columns: int = 0                 ## 0: as many as fit at minColumnWidth
    minColumnWidth: float32 = 180.0
    spacing: float32 = 8.0

  layout:
    let plan = widget.planMasonry(constraintsOf(widget.bounds))
    widget.bounds.width = plan.own.width
    widget.bounds.height = plan.own.height
    for i, child in widget.children:
      let r = plan.rects[i]
      child.arrange(Rect(x: widget.bounds.x + r.x, y: widget.bounds.y + r.y,
                         width: r.width, height: r.height))

method computeSize*(widget: Masonry, c: Constraints): Size = widget.planMasonry(c).own
