## DataTable Widget - RUI2
##
## Data table with per-column filtering, sorting and virtual scrolling, sized
## for large datasets: only the rows on screen are ever drawn.
##
## Filtering and sorting run in `layout` and cache their result in
## `filteredIndices`. The pre-split version rebuilt the filtered index list from
## scratch inside `render`, on every single frame, over the whole dataset.
##
## FilterKind / Filter / TableRow / SortOrder come from datatable_helpers, which also owns
## the matching and comparison logic. They used to be declared a second time in
## this file, with a second, subtly different implementation of the matcher:
## the local copy guarded every string test with `value.kind == JString`, so a
## numeric cell silently passed every text filter.

import rui_core
import rui_drawing
import ../virtual_rows
import datatable_helpers

export virtual_rows
import std/[options, sets, json, tables]
# `from`, not `import`: std/algorithm exports its own SortOrder, which would make
# ours ambiguous. The old file only escaped this because it declared SortOrder
# locally, and a local declaration shadows an imported one.
from std/algorithm import sort

import raylib

export datatable_helpers

type
  ColumnDef* = object
    id*: string
    title*: string
    width*: float32
    sortable*: bool
    filterable*: bool
    filterKinds*: set[FilterKind]  # Filter types offered for this column
    formatFunc*: Option[proc(value: JsonNode): string]

const BufferRows = 10

type
  TableMetrics* = object
    ## Where the three bands of the table sit. Every event handler and `render`
    ## needs the same answer, so they all ask this rather than each recomputing
    ## it from showFilter / showHeader.
    originX*, originY*: float32
    filterH*, headerH*: float32
    rows*: RowViewport     ## The scrollable body; owns all the row arithmetic

template metricsOf*(widget: untyped): TableMetrics =
  ## A template, not a proc: the DataTable type does not exist until the macro
  ## below has expanded, and the widget body needs this.
  let fh = if widget.showFilter: widget.filterHeight else: 0.0'f32
  let hh = if widget.showHeader: widget.headerHeight else: 0.0'f32
  TableMetrics(
    originX: widget.bounds.x, originY: widget.bounds.y,
    filterH: fh, headerH: hh,
    rows: rowViewport(top = widget.bounds.y + fh + hh,
                      height = widget.bounds.height - fh - hh,
                      rowHeight = widget.rowHeight,
                      scrollY = widget.scrollY)
  )

proc headerTop*(m: TableMetrics): float32 =
  m.originY + m.filterH

proc rowsTop*(m: TableMetrics): float32 =
  m.rows.top

proc viewHeight*(m: TableMetrics): float32 =
  m.rows.height

proc rowHeight*(m: TableMetrics): float32 =
  m.rows.rowHeight

proc overHeader*(m: TableMetrics, mouseY: float32): bool =
  m.headerH > 0 and mouseY >= m.headerTop and mouseY < m.rowsTop

proc columnAt*(columns: openArray[ColumnDef], originX, mouseX: float32): int =
  ## Index of the column containing `mouseX`, or -1. Columns are laid out left
  ## to right at their own widths, so this walks rather than divides.
  var x = originX
  for i, col in columns:
    if mouseX >= x and mouseX < x + col.width:
      return i
    x += col.width
  -1

proc passesFilters*(row: TableRow, filters: Table[string, Filter]): bool =
  ## Matching itself lives in datatable_helpers; this is just the conjunction.
  for colId, filter in filters:
    if not matchesColumnFilter(row, colId, filter):
      return false
  true

proc nextSortOrder(current: SortOrder): SortOrder =
  ## Header clicks cycle ascending -> descending -> unsorted.
  result = case current
  of soNone: soAscending
  of soAscending: soDescending
  of soDescending: soNone

proc sortIndicatorFor(order: SortOrder): string =
  result = case order
  of soAscending: "  ^"
  of soDescending: "  v"
  of soNone: ""

proc isSortable*(columns: openArray[ColumnDef], idx: int): bool =
  ## Is `idx` a real column that allows sorting?
  idx >= 0 and idx < columns.len and columns[idx].sortable

proc nextSortFor*(columns: openArray[ColumnDef], idx: int,
                  currentColumn: string, currentOrder: SortOrder): SortOrder =
  ## The order a header click on column `idx` produces. Clicking the column
  ## already sorted advances its cycle; clicking a different one starts over at
  ## ascending. Pure, so the cycle is testable without a table.
  assert columns.isSortable(idx), "caller must check isSortable first"
  if columns[idx].id == currentColumn: nextSortOrder(currentOrder)
  else: soAscending

template sortByColumnAt*(widget: untyped, mouseX: float32): bool =
  ## Cycle the sort order of the column under `mouseX`. A header click is always
  ## consumed, whether or not it landed on a sortable column.
  block:
    let idx = columnAt(widget.columns, widget.bounds.x, mouseX)
    if widget.columns.isSortable(idx):
      let order = nextSortFor(widget.columns, idx,
                              widget.sortColumn, widget.sortOrder)
      widget.sortColumn = if order == soNone: "" else: widget.columns[idx].id
      widget.sortOrder = order
      widget.isDirty = true
      widget.layoutDirty = true   # ordering is decided in layout
      if widget.onSort.isSome:
        widget.onSort.get()(widget.columns[idx].id, order)
    true

template selectRowAt*(widget: untyped, viewIdx: int): bool =
  ## Select the source row behind filtered-view row `viewIdx`. Selection is kept
  ## against the source index so it survives a change of filter.
  block:
    if viewIdx < 0:
      false
    else:
      assert viewIdx < widget.filteredIndices.len,
             "rowAt must not return an index past the filtered view"
      let rowIdx = widget.filteredIndices[viewIdx]
      updateSelection(widget.selected, rowIdx,
                      isKeyDown(LeftControl) or isKeyDown(RightControl))
      widget.isDirty = true
      if widget.onSelect.isSome:
        widget.onSelect.get()(widget.selected)
      true

definePrimitive(DataTable):
  props:
    columns: seq[ColumnDef] = @[]
    data: seq[TableRow] = @[]    # The whole dataset; can be large
    rowHeight: float32 = 24.0
    headerHeight: float32 = 28.0
    filterHeight: float32 = 26.0
    showHeader: bool = true
    showFilter: bool = true
    showGrid: bool = true
    alternateRowColor: bool = true
    visibleRows: int = 12
    intent: ThemeIntent = Default

  state:
    selected: HashSet[int]       # Indices into `data`, not into the filtered view
    filters: Table[string, Filter]
    sortColumn: string           # Empty means unsorted
    sortOrder: SortOrder
    scrollY: float32
    filteredIndices: seq[int]
    visibleStart: int
    visibleEnd: int
    hoverRow: int                # Not `hovered`: Widget already has that (a bool)

  actions:
    onSort(column: string, order: SortOrder)
    onFilter(filters: Table[string, Filter])
    onSelect(selected: HashSet[int])

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      let m = metricsOf(widget)
      if m.overHeader(event.mousePos.y):
        return widget.sortByColumnAt(event.mousePos.x)
      return widget.selectRowAt(
        m.rows.rowAt(event.mousePos.y, widget.filteredIndices.len))

    on_mouse_move:
      let m = metricsOf(widget)
      let newHover = m.rows.rowAt(event.mousePos.y, widget.filteredIndices.len)
      if newHover != widget.hoverRow:
        widget.hoverRow = newHover
        widget.isDirty = true
      return false

    on_mouse_wheel:
      let m = metricsOf(widget)
      let newScroll = m.rows.scrolledBy(event.wheelDelta,
                                        widget.filteredIndices.len)
      if newScroll != widget.scrollY:
        widget.scrollY = newScroll
        widget.isDirty = true
      return true

  layout:
    # Filter, then sort, then cache. Doing this here rather than in render means
    # it runs when the data or the filters change, not once per frame.
    widget.filteredIndices.setLen(0)
    for i, row in widget.data:
      if row.passesFilters(widget.filters):
        widget.filteredIndices.add(i)

    if widget.sortColumn.len > 0 and widget.sortOrder != soNone:
      let colId = widget.sortColumn
      let ascending = widget.sortOrder == soAscending
      let rows = widget.data
      widget.filteredIndices.sort(proc (a, b: int): int =
        compareRows(rows[a], rows[b], colId, ascending))

    if widget.bounds.width <= 0:
      var total = 0.0'f32
      for col in widget.columns:
        total += col.width
      widget.bounds.width = total
    if widget.bounds.height <= 0:
      let m = metricsOf(widget)
      widget.bounds.height = m.filterH + m.headerH +
                             float32(widget.visibleRows) * widget.rowHeight

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let headerProps = currentTheme.getThemeProps(widget.intent, Selected)
    let m = metricsOf(widget)
    let filterH = m.filterH
    let rowH = m.rowHeight
    let rowsTop = m.rowsTop
    let viewHeight = m.viewHeight

    let visible = m.rows.visibleRange(widget.filteredIndices.len,
                                      buffer = BufferRows)
    widget.visibleStart = visible.a
    widget.visibleEnd = visible.b

    drawThemedBackground(widget.bounds, props)
    let gridColor = props.borderColor.get(Color(r: 220, g: 220, b: 220, a: 255))
    let fgColor = props.foregroundColor.get(Color(r: 40, g: 40, b: 40, a: 255))
    let clip = beginClip(widget.bounds)

    # Filter strip: shows the active filter per column. Editing a filter from
    # the UI is not wired up -- set `filters` from code.
    if widget.showFilter:
      var x = widget.bounds.x
      for col in widget.columns:
        let cellRect = Rect(x: x, y: widget.bounds.y,
                            width: col.width, height: filterH)
        if col.filterable:
          let filter = widget.filters.getOrDefault(
            col.id, Filter(column: col.id, kind: fkNone))
          drawInteractiveBox(cellRect, props)
          let label = getFilterKindLabel(filter.kind) & " " & getFilterValueText(filter)
          drawText(label, x + 6.0, widget.bounds.y + 6.0, 10.0, fgColor)
        x += col.width

    # Header row with sort indicators.
    if widget.showHeader:
      var x = widget.bounds.x
      for col in widget.columns:
        let headerRect = Rect(x: x, y: m.headerTop,
                              width: col.width, height: m.headerH)
        drawThemedBackground(headerRect, headerProps)
        let indicator = if col.id == widget.sortColumn:
                          sortIndicatorFor(widget.sortOrder)
                        else:
                          ""
        drawThemedPaddedText(col.title & indicator, headerRect, headerProps,
                             selected = true)
        if widget.showGrid:
          drawLine(x + col.width, headerRect.y,
                   x + col.width, headerRect.y + m.headerH, gridColor)
        x += col.width

    # Body: only the rows that can be on screen.
    for viewIdx in visible:
      let rowIdx = widget.filteredIndices[viewIdx]
      let rowY = m.rows.rowTop(viewIdx)
      let rowRect = Rect(x: widget.bounds.x, y: rowY,
                         width: widget.bounds.width, height: rowH)
      if widget.alternateRowColor and viewIdx mod 2 == 1:
        drawRect(rowRect, Color(r: 245, g: 245, b: 245, a: 255))
      drawSelectionBackground(rowRect, props,
                              selected = rowIdx in widget.selected,
                              hovered = viewIdx == widget.hoverRow)

      var x = widget.bounds.x
      for col in widget.columns:
        let text = getCellText(widget.data[rowIdx], col.id,
                               if col.formatFunc.isSome: col.formatFunc.get()
                               else: nil)
        drawText(text, x + 4.0, rowY + (rowH - 12.0) / 2, 12.0, fgColor)
        if widget.showGrid:
          drawLine(x + col.width, rowY, x + col.width, rowY + rowH, gridColor)
        x += col.width

      if widget.showGrid:
        drawLine(widget.bounds.x, rowY + rowH,
                 widget.bounds.x + widget.bounds.width, rowY + rowH, gridColor)

    endClip(clip)
    drawThemedBorder(widget.bounds, props, widget.focused)
