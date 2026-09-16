## The drawing DataTable and DataGrid share: headers, row backgrounds, grid.
##
## The companion to tabular.nim, which holds the arithmetic. Both widgets had a
## copy of each of these loops, differing only in how they identify the sorted
## column -- DataTable by id, DataGrid by index -- which is settled here by
## taking the index and leaving the lookup to the caller.
##
## Generic over the column type for the same reason tabular.nim is: a column
## needs a `title` and a `width`, and nothing else.

import rui_core
import rui_drawing
import tabular

const
  AlternateRowColor* = Color(r: 245, g: 245, b: 245, a: 255)
  DefaultGridColor* = Color(r: 220, g: 220, b: 220, a: 255)
  DefaultInkColor* = Color(r: 40, g: 40, b: 40, a: 255)
  PlaceholderColor* = Color(r: 150, g: 150, b: 150, a: 255)
  CellFontSize* = 12.0'f32
  CellPadX* = 4.0'f32

proc cellBaseline*(rowY, rowHeight: float32): float32 =
  ## Vertically centres CellFontSize text in a row of this height.
  rowY + (rowHeight - CellFontSize) / 2

proc drawColumnHeaders*[C](columns: openArray[C], originX, top, height: float32,
                           sortedIndex: int, order: SortOrder,
                           props: ThemeProps, showGrid: bool,
                           gridColor: Color) =
  ## One header cell per column, with the sort arrow on the sorted one.
  ##
  ## `sortedIndex` of -1 means nothing is sorted. DataTable tracks its sorted
  ## column by id, so it resolves the id to an index before calling; which
  ## identity a widget keeps is its business, and the arrow does not care.
  var x = originX
  for i, col in columns:
    let cell = Rect(x: x, y: top, width: col.width, height: height)
    drawThemedBackground(cell, props)
    let indicator = if i == sortedIndex: sortIndicatorFor(order) else: ""
    drawThemedPaddedText(col.title & indicator, cell, props, selected = true)
    if showGrid:
      drawLine(x + col.width, cell.y, x + col.width, cell.y + height, gridColor)
    x += col.width

proc drawRowBackground*(rowRect: Rect, props: ThemeProps, viewIdx: int,
                        alternate, selected, hovered: bool) =
  ## Banding first, then selection over it -- a selected odd row must read as
  ## selected, not as a slightly different shade of stripe.
  if alternate and viewIdx mod 2 == 1:
    drawRect(rowRect, AlternateRowColor)
  drawSelectionBackground(rowRect, props, selected = selected, hovered = hovered)

proc drawRowGridLine*(rowRect: Rect, gridColor: Color) =
  ## The line under a row. Drawn per row rather than as a full grid afterwards,
  ## so it is clipped with the row it belongs to.
  drawLine(rowRect.x, rowRect.y + rowRect.height,
           rowRect.x + rowRect.width, rowRect.y + rowRect.height, gridColor)

proc drawCells*[C](columns: openArray[C], originX, rowY, rowHeight: float32,
                   texts: openArray[string], ink: Color,
                   showGrid: bool, gridColor: Color) =
  ## One row of cells. `texts` is parallel to `columns`; a short seq leaves the
  ## remaining cells blank rather than raising, because a row is not guaranteed
  ## to carry a value for every column.
  var x = originX
  for i, col in columns:
    if i < texts.len:
      drawText(texts[i], x + CellPadX, cellBaseline(rowY, rowHeight),
               CellFontSize, ink)
    if showGrid:
      drawLine(x + col.width, rowY, x + col.width, rowY + rowHeight, gridColor)
    x += col.width
