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

defineWidget(Table):
  props:
    columnWidths: seq[TableColumnWidth] = @[]
    defaultColumnWidth: TableColumnWidth = TableColumnWidth(kind: cwFlex, value: 1.0)
    defaultVerticalAlignment: TableCellVerticalAlignment = TableCellVerticalAlignment.middle
    columnSpacing: float32 = 0.0     # beyond Flutter: gaps between columns
    rowSpacing: float32 = 0.0        # and between rows

  layout:
    var n = 0
    for row in widget.children:
      n = max(n, row.children.len)
    var rules = newSeq[TableColumnWidth](n)
    for c in 0 ..< n:
      rules[c] = if c < widget.columnWidths.len: widget.columnWidths[c]
                 else: widget.defaultColumnWidth

    # Intrinsic widths: every cell at its natural size.
    var intrinsic = newSeq[float32](n)
    for row in widget.children:
      for c, cell in row.children:
        cell.bounds.width = 0
        cell.bounds.height = 0
        cell.layout()
        intrinsic[c] = max(intrinsic[c], cell.bounds.width)

    let hasWidth = widget.bounds.width > 0
    let gaps = totalSpacing(n, widget.columnSpacing)
    let widths = resolveColumnWidths(rules, intrinsic,
                                     (if hasWidth: widget.bounds.width - gaps else: 0.0'f32))
    var tableWidth = gaps
    for w in widths: tableWidth += w

    var y = widget.bounds.y
    for row in widget.children:
      var rowHeight = 0.0'f32
      var x = widget.bounds.x
      for c, cell in row.children:
        cell.bounds = Rect(x: x, y: y, width: widths[c])
        cell.layout()
        rowHeight = max(rowHeight, cell.bounds.height)
        x += widths[c] + widget.columnSpacing
      for cell in row.children:
        let dy = case widget.defaultVerticalAlignment
                 of TableCellVerticalAlignment.top: 0.0'f32
                 of TableCellVerticalAlignment.middle: (rowHeight - cell.bounds.height) / 2
                 of TableCellVerticalAlignment.bottom: rowHeight - cell.bounds.height
        if dy != 0:
          cell.bounds.y = y + dy
          cell.layout()
      row.bounds = Rect(x: widget.bounds.x, y: y, width: tableWidth, height: rowHeight)
      y += rowHeight + widget.rowSpacing

    if not hasWidth: widget.bounds.width = tableWidth
    if widget.bounds.height <= 0:
      widget.bounds.height = max(0.0'f32, y - widget.bounds.y -
        (if widget.children.len > 0: widget.rowSpacing else: 0.0'f32))

# A uniform grid of equal cells.
defineWidget(GridView):
  props:
    crossAxisCount: int = 2
    mainAxisSpacing: float32 = 0.0    # between rows
    crossAxisSpacing: float32 = 0.0   # between columns
    childAspectRatio: float32 = 1.0   # cell width / cell height

  layout:
    let n = max(1, widget.crossAxisCount)
    let gaps = totalSpacing(n, widget.crossAxisSpacing)
    if widget.bounds.width <= 0:
      # No width to divide: size the cells to the widest child.
      var widest = 0.0'f32
      for child in widget.children:
        child.bounds = Rect()
        child.layout()
        widest = max(widest, child.bounds.width)
      widget.bounds.width = widest * float32(n) + gaps
    let cellW = (widget.bounds.width - gaps) / float32(n)
    let cellH = cellW / max(0.01'f32, widget.childAspectRatio)
    for i, child in widget.children:
      let col = i mod n
      let row = i div n
      child.bounds = Rect(
        x: widget.bounds.x + float32(col) * (cellW + widget.crossAxisSpacing),
        y: widget.bounds.y + float32(row) * (cellH + widget.mainAxisSpacing),
        width: cellW, height: cellH)
      child.layout()
    let rows = (widget.children.len + n - 1) div n
    if widget.bounds.height <= 0:
      widget.bounds.height = float32(rows) * cellH + totalSpacing(rows, widget.mainAxisSpacing)
