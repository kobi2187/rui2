## Table, TableRow and GridView.
##
## `Table` is Flutter's: rows of cells, with a width rule per column --
##
## - `FixedColumnWidth(120)` -- exactly 120 wide
## - `IntrinsicColumnWidth()` -- as wide as the column's widest cell
## - `FlexColumnWidth(2)` -- two shares of the width left over
##
## Each row is as tall as its tallest cell, and cells sit in it by
## `defaultVerticalAlignment`. A column with no rule uses `defaultColumnWidth`.
##
## ```nim
## ui:
##   Table(columnWidths = @[IntrinsicColumnWidth(), FlexColumnWidth()]):
##     TableRow():
##       Label(text = "Name")
##       TextInput()
##     TableRow():
##       Label(text = "Email")
##       TextInput()
## ```
##
## `GridView` is a uniform grid: `crossAxisCount` equal columns, each cell
## `childAspectRatio` wide per unit of height. Unlike Flutter's it does not
## scroll by itself -- put it in a ScrollView.

import rui_core

type
  ColumnWidthKind* = enum
    cwFixed, cwIntrinsic, cwFlex

  TableColumnWidth* = object
    kind*: ColumnWidthKind
    value*: float32              ## pixels for fixed, the factor for flex

  TableCellVerticalAlignment* {.pure.} = enum
    top, middle, bottom

proc FixedColumnWidth*(width: float32): TableColumnWidth =
  TableColumnWidth(kind: cwFixed, value: width)
proc IntrinsicColumnWidth*(): TableColumnWidth =
  TableColumnWidth(kind: cwIntrinsic)
proc FlexColumnWidth*(flex = 1.0'f32): TableColumnWidth =
  TableColumnWidth(kind: cwFlex, value: flex)

proc resolveColumnWidths*(rules: openArray[TableColumnWidth],
                          intrinsic: openArray[float32],
                          available: float32): seq[float32] =
  ## The width of each column. `intrinsic` is the widest cell per column;
  ## `available` the width for the columns themselves, or <= 0 when the table
  ## sizes to its content -- then flex columns size like intrinsic ones.
  result = newSeq[float32](rules.len)
  var used, flexTotal = 0.0'f32
  for i, r in rules:
    case r.kind
    of cwFixed: result[i] = r.value
    of cwIntrinsic: result[i] = intrinsic[i]
    of cwFlex:
      flexTotal += max(r.value, 0.0)
      continue
    used += result[i]
  for i, r in rules:
    if r.kind == cwFlex:
      result[i] = if available > 0 and flexTotal > 0:
                    max(0.0'f32, available - used) * max(r.value, 0.0) / flexTotal
                  else: intrinsic[i]

# One row of a Table; its children are the cells. The Table lays it out.
defineWidget(TableRow):
  layout:
    discard

type TablePlan = object
  widths: seq[float32]             # per column
  heights: seq[float32]            # per row
  cells: seq[seq[Size]]            # each cell, measured at its column's width
  own: Size

proc planTable[W](widget: W, c: Constraints): TablePlan =
  ## Column widths from the rules and the cells' natural widths, then each
  ## cell measured at its column's width to find the row heights.
  var n = 0
  for row in widget.children:
    n = max(n, row.children.len)
  var rules = newSeq[TableColumnWidth](n)
  for i in 0 ..< n:
    rules[i] = if i < widget.columnWidths.len: widget.columnWidths[i]
               else: widget.defaultColumnWidth
  var intrinsic = newSeq[float32](n)
  for row in widget.children:
    for i, cell in row.children:
      intrinsic[i] = max(intrinsic[i], cell.measure(unbounded()).width)
  let hasWidth = c.tightWidth and c.minWidth > 0
  let gaps = totalSpacing(n, widget.columnSpacing)
  result.widths = resolveColumnWidths(rules, intrinsic,
                                      (if hasWidth: c.minWidth - gaps else: 0.0'f32))
  var tableWidth = gaps
  for w in result.widths: tableWidth += w
  var total = 0.0'f32
  for row in widget.children:
    var sizes: seq[Size]
    var rowHeight = 0.0'f32
    for i, cell in row.children:
      let s = cell.measure(unbounded().withWidth(result.widths[i]))
      sizes.add s
      rowHeight = max(rowHeight, s.height)
    result.cells.add sizes
    result.heights.add rowHeight
    total += rowHeight
  total += totalSpacing(widget.children.len, widget.rowSpacing)
  result.own = Size(width: (if hasWidth: c.minWidth else: tableWidth),
                    height: (if c.tightHeight and c.minHeight > 0: c.minHeight else: total))

defineWidget(Table):
  props:
    columnWidths: seq[TableColumnWidth] = @[]
    defaultColumnWidth: TableColumnWidth = TableColumnWidth(kind: cwFlex, value: 1.0)
    defaultVerticalAlignment: TableCellVerticalAlignment = TableCellVerticalAlignment.middle
    columnSpacing: float32 = 0.0     # beyond Flutter: gaps between columns
    rowSpacing: float32 = 0.0        # and between rows

  layout:
    let plan = widget.planTable(constraintsOf(widget.bounds))
    widget.bounds.width = plan.own.width
    widget.bounds.height = plan.own.height
    var tableWidth = totalSpacing(plan.widths.len, widget.columnSpacing)
    for w in plan.widths: tableWidth += w
    var y = widget.bounds.y
    for r, row in widget.children:
      let rowHeight = plan.heights[r]
      var x = widget.bounds.x
      for i, cell in row.children:
        let s = plan.cells[r][i]
        let dy = case widget.defaultVerticalAlignment
                 of TableCellVerticalAlignment.top: 0.0'f32
                 of TableCellVerticalAlignment.middle: (rowHeight - s.height) / 2
                 of TableCellVerticalAlignment.bottom: rowHeight - s.height
        cell.arrange(Rect(x: x, y: y + dy, width: s.width, height: s.height))
        x += plan.widths[i] + widget.columnSpacing
      row.bounds = Rect(x: widget.bounds.x, y: y, width: tableWidth, height: rowHeight)
      y += rowHeight + widget.rowSpacing

method computeSize*(widget: Table, c: Constraints): Size = widget.planTable(c).own

# A uniform grid of equal cells.
proc gridSize[W](widget: W, c: Constraints): Size =
  ## Equal cells: the width divided by the column count -- or, with no width,
  ## the widest child per column -- and rows at the aspect ratio.
  let n = max(1, widget.crossAxisCount)
  let gaps = totalSpacing(n, widget.crossAxisSpacing)
  var width = c.minWidth
  if not (c.tightWidth and c.minWidth > 0):
    var widest = 0.0'f32
    for child in widget.children:
      widest = max(widest, child.measure(unbounded()).width)
    width = widest * float32(n) + gaps
  let cellH = (width - gaps) / float32(n) / max(0.01'f32, widget.childAspectRatio)
  let rows = (widget.children.len + n - 1) div n
  Size(width: width,
       height: (if c.tightHeight and c.minHeight > 0: c.minHeight
                else: float32(rows) * cellH + totalSpacing(rows, widget.mainAxisSpacing)))

defineWidget(GridView):
  props:
    crossAxisCount: int = 2
    mainAxisSpacing: float32 = 0.0    # between rows
    crossAxisSpacing: float32 = 0.0   # between columns
    childAspectRatio: float32 = 1.0   # cell width / cell height

  layout:
    let own = widget.gridSize(constraintsOf(widget.bounds))
    widget.bounds.width = own.width
    widget.bounds.height = own.height
    let n = max(1, widget.crossAxisCount)
    let cellW = (own.width - totalSpacing(n, widget.crossAxisSpacing)) / float32(n)
    let cellH = cellW / max(0.01'f32, widget.childAspectRatio)
    for i, child in widget.children:
      child.arrange(Rect(
        x: widget.bounds.x + float32(i mod n) * (cellW + widget.crossAxisSpacing),
        y: widget.bounds.y + float32(i div n) * (cellH + widget.mainAxisSpacing),
        width: cellW, height: cellH))

method computeSize*(widget: GridView, c: Constraints): Size = widget.gridSize(c)
