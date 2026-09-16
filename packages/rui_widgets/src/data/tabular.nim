## The arithmetic every column-and-row widget needs.
##
## DataTable and DataGrid had a copy each: the same band metrics, the same
## column hit-test, the same three-state sort cycle, differing only in the
## names of the types they were written against. Around seventy lines apiece,
## kept in step by hand.
##
## They are here once now, generic over the column type -- `columnAt` and
## `isSortable` need a column to have a `width` and a `sortable`, and nothing
## else -- so TreeView or any other tabular widget gets them by importing
## rather than by copying.

import rui_core
import virtual_rows
import table_sorting  # SortOrder

export SortOrder

type
  BandMetrics* = object
    ## Where the horizontal bands of a tabular widget sit.
    ##
    ## Event handlers and `render` must agree on this to the pixel -- a click
    ## that thinks it is on the header while the paint thinks it is on row 0
    ## sorts when the user meant to select. So they all ask here rather than
    ## each recomputing it from showFilter / showHeader.
    originX*, originY*: float32
    filterH*: float32
      ## 0 for a widget with no filter band, which is how DataGrid uses it.
    headerH*: float32
      ## 0 when the header is hidden, which is what makes `overHeader` false.
    totalRows*: int
      ## The claimed row count. Lazy loading makes this larger than the number
      ## of rows actually held, so the scrollbar can describe the whole set.
    rows*: RowViewport
      ## The scrollable body; owns all the row arithmetic.

proc headerTop*(m: BandMetrics): float32 =
  m.originY + m.filterH

proc rowsTop*(m: BandMetrics): float32 =
  m.rows.top

proc viewHeight*(m: BandMetrics): float32 =
  m.rows.height

proc rowHeight*(m: BandMetrics): float32 =
  m.rows.rowHeight

proc overHeader*(m: BandMetrics, mouseY: float32): bool =
  ## False when the header is hidden, so a hidden header cannot be clicked.
  m.headerH > 0 and mouseY < m.rowsTop

proc columnAt*[C](columns: openArray[C], originX, mouseX: float32): int =
  ## Index of the column containing `mouseX`, or -1. Columns are laid out left
  ## to right at their own widths, so this walks rather than divides.
  var x = originX
  for i, col in columns:
    if mouseX >= x and mouseX < x + col.width:
      return i
    x += col.width
  -1

proc columnLeft*[C](columns: openArray[C], originX: float32, idx: int): float32 =
  ## Left edge of column `idx`, for drawing. The inverse of columnAt, and kept
  ## beside it so the two cannot disagree about where a column starts.
  result = originX
  for i in 0 ..< min(idx, columns.len):
    result += columns[i].width

proc isSortable*[C](columns: openArray[C], idx: int): bool =
  ## Is `idx` a real column that allows sorting?
  idx >= 0 and idx < columns.len and columns[idx].sortable

proc nextSortOrder*(current: SortOrder): SortOrder =
  ## Header clicks cycle ascending -> descending -> unsorted.
  case current
  of soNone: soAscending
  of soAscending: soDescending
  of soDescending: soNone

proc nextSortFor*(sameColumn: bool, currentOrder: SortOrder): SortOrder =
  ## The order a header click produces: clicking the column already sorted
  ## advances its cycle, clicking a different one starts over at ascending.
  ##
  ## `sameColumn` rather than a column identity, because DataTable tracks its
  ## sorted column by id and DataGrid by index. Which of those is right is the
  ## widget's business; the cycle is not.
  if sameColumn: nextSortOrder(currentOrder) else: soAscending

proc sortIndicatorFor*(order: SortOrder): string =
  case order
  of soAscending: "  ^"
  of soDescending: "  v"
  of soNone: ""
