## DataGrid Widget - RUI2
##
## Sortable grid with virtual row rendering and lazy loading, for datasets far
## larger than the viewport. Columns are addressed by index; rows carry one
## JsonNode per column.
##
## DataGrid is DataTable's simpler sibling: no per-column filters, but it can
## page rows in on demand through `onLoadMore`.
##
## The types are `GridColumn` / `GridRow`, not `Column` / `Row`: `Column` is
## already the name of the vertical-layout container widget, and both are
## exported from rui_widgets.

import rui_core
import rui_drawing
import datatable_helpers   # SortOrder, compareValues, updateSelection, ...
import std/[options, sets, json]

# `from`, not `import`: std/algorithm exports its own SortOrder.
from std/algorithm import sort

import raylib

export SortOrder

type
  GridColumn* = object
    id*: string
    title*: string
    width*: float32
    sortable*: bool
    formatFunc*: Option[proc(value: JsonNode): string]

  GridRow* = object
    id*: string
    values*: seq[JsonNode]   # One value per column, by column index

const
  BufferRows = 10
  LoadAheadRows = 20
  LoadBatchSize = 100

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

proc cellText(row: GridRow, colIdx: int,
              formatFunc: Option[proc(value: JsonNode): string]): string =
  if colIdx < 0 or colIdx >= row.values.len:
    return ""
  let value = row.values[colIdx]
  if formatFunc.isSome:
    formatFunc.get()(value)
  else:
    getStringValue(value)

definePrimitive(DataGrid):
  props:
    columns: seq[GridColumn] = @[]
    data: seq[GridRow] = @[]     # Loaded rows; may be a prefix of the dataset
    totalRowCount: int = -1      # -1 means use data.len, otherwise lazy loading
    rowHeight: float32 = 24.0
    headerHeight: float32 = 28.0
    showHeader: bool = true
    showGrid: bool = true
    alternateRowColor: bool = true
    visibleRows: int = 12
    intent: ThemeIntent = Default

  state:
    selected: HashSet[int]
    sortColumn: int              # -1 means unsorted
    sortOrder: SortOrder
    scrollY: float32
    order: seq[int]              # Display order -> index into `data`
    visibleStart: int
    visibleEnd: int
    hoverRow: int                # Not `hovered`: Widget already has that (a bool)

  actions:
    onSort(column: int, order: SortOrder)
    onSelect(selected: HashSet[int])
    onLoadMore(startIndex: int, count: int)
    onScrollNearEnd()

  events:
    on_mouse_down:
      let headerH = if widget.showHeader: widget.headerHeight else: 0.0'f32
      let rowsTop = widget.bounds.y + headerH

      if widget.showHeader and event.mousePos.y < rowsTop:
        var x = widget.bounds.x
        for colIdx, col in widget.columns:
          if event.mousePos.x >= x and event.mousePos.x < x + col.width:
            if not col.sortable:
              return true
            widget.sortOrder =
              if colIdx == widget.sortColumn: nextSortOrder(widget.sortOrder)
              else: soAscending
            widget.sortColumn = if widget.sortOrder == soNone: -1 else: colIdx
            widget.isDirty = true
            widget.layoutDirty = true   # ordering is decided in layout
            if widget.onSort.isSome:
              widget.onSort.get()(widget.sortColumn, widget.sortOrder)
            return true
          x += col.width
        return true

      let viewIdx = int((event.mousePos.y - rowsTop + widget.scrollY) / widget.rowHeight)
      if viewIdx < 0 or viewIdx >= widget.order.len:
        return false

      let rowIdx = widget.order[viewIdx]
      let ctrlDown = isKeyDown(LeftControl) or isKeyDown(RightControl)
      updateSelection(widget.selected, rowIdx, ctrlDown)
      widget.isDirty = true
      if widget.onSelect.isSome:
        widget.onSelect.get()(widget.selected)
      return true

    on_mouse_move:
      let headerH = if widget.showHeader: widget.headerHeight else: 0.0'f32
      let rowsTop = widget.bounds.y + headerH
      var newHover = -1
      if event.mousePos.y >= rowsTop:
        let viewIdx = int((event.mousePos.y - rowsTop + widget.scrollY) / widget.rowHeight)
        if viewIdx >= 0 and viewIdx < widget.order.len:
          newHover = viewIdx
      if newHover != widget.hoverRow:
        widget.hoverRow = newHover
        widget.isDirty = true
      return false

    on_mouse_wheel:
      let headerH = if widget.showHeader: widget.headerHeight else: 0.0'f32
      let viewHeight = widget.bounds.height - headerH
      let totalRows = if widget.totalRowCount >= 0: widget.totalRowCount
                      else: widget.data.len
      let maxScroll = max(0.0'f32, float32(totalRows) * widget.rowHeight - viewHeight)
      let newScroll = clamp(widget.scrollY - event.wheelDelta * widget.rowHeight * 3.0,
                            0.0'f32, maxScroll)
      if newScroll != widget.scrollY:
        widget.scrollY = newScroll
        widget.isDirty = true

      let scrollRatio = if maxScroll > 0: widget.scrollY / maxScroll else: 0.0'f32
      if scrollRatio > 0.8 and widget.onScrollNearEnd.isSome:
        widget.onScrollNearEnd.get()()
      return true

  layout:
    # Build the display order once here rather than per frame in render.
    widget.order.setLen(widget.data.len)
    for i in 0 ..< widget.data.len:
      widget.order[i] = i

    # Sorting a lazily-loaded grid would order only the rows that happen to be
    # in memory and silently mis-order the rest, so it is left alone.
    let fullyLoaded = widget.totalRowCount < 0 or widget.totalRowCount <= widget.data.len
    if fullyLoaded and widget.sortColumn >= 0 and widget.sortOrder != soNone:
      let colIdx = widget.sortColumn
      let ascending = widget.sortOrder == soAscending
      let rows = widget.data
      widget.order.sort(proc (a, b: int): int =
        let va = if colIdx < rows[a].values.len: rows[a].values[colIdx] else: newJNull()
        let vb = if colIdx < rows[b].values.len: rows[b].values[colIdx] else: newJNull()
        compareValues(va, vb, ascending))

    if widget.bounds.width <= 0:
      var total = 0.0'f32
      for col in widget.columns:
        total += col.width
      widget.bounds.width = total
    if widget.bounds.height <= 0:
      let headerH = if widget.showHeader: widget.headerHeight else: 0.0'f32
      widget.bounds.height = headerH + float32(widget.visibleRows) * widget.rowHeight

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let headerProps = currentTheme.getThemeProps(widget.intent, Selected)
    let headerH = if widget.showHeader: widget.headerHeight else: 0.0'f32
    let rowH = widget.rowHeight
    let rowsTop = widget.bounds.y + headerH
    let viewHeight = widget.bounds.height - headerH

    let totalRows = if widget.totalRowCount >= 0: widget.totalRowCount
                    else: widget.data.len
    let visStart = max(0, int(widget.scrollY / rowH) - BufferRows)
    let visEnd = min(totalRows - 1, int((widget.scrollY + viewHeight) / rowH) + BufferRows)
    widget.visibleStart = visStart
    widget.visibleEnd = visEnd

    if widget.onLoadMore.isSome and visEnd >= widget.data.len - LoadAheadRows:
      let needCount = min(LoadBatchSize, totalRows - widget.data.len)
      if needCount > 0:
        widget.onLoadMore.get()(widget.data.len, needCount)

    drawThemedBackground(widget.bounds, props)
    let gridColor = props.borderColor.get(Color(r: 220, g: 220, b: 220, a: 255))
    let fgColor = props.foregroundColor.get(Color(r: 40, g: 40, b: 40, a: 255))
    let clip = beginClip(widget.bounds)

    if widget.showHeader:
      var x = widget.bounds.x
      for colIdx, col in widget.columns:
        let headerRect = Rect(x: x, y: widget.bounds.y,
                              width: col.width, height: headerH)
        drawThemedBackground(headerRect, headerProps)
        let indicator = if colIdx == widget.sortColumn:
                          sortIndicatorFor(widget.sortOrder)
                        else:
                          ""
        drawThemedPaddedText(col.title & indicator, headerRect, headerProps,
                             selected = true)
        if widget.showGrid:
          drawLine(x + col.width, headerRect.y,
                   x + col.width, headerRect.y + headerH, gridColor)
        x += col.width

    for viewIdx in visStart..visEnd:
      if viewIdx >= totalRows:
        break
      let rowY = rowsTop + float32(viewIdx) * rowH - widget.scrollY
      if rowY + rowH < rowsTop or rowY > rowsTop + viewHeight:
        continue

      let rowRect = Rect(x: widget.bounds.x, y: rowY,
                         width: widget.bounds.width, height: rowH)
      if widget.alternateRowColor and viewIdx mod 2 == 1:
        drawRect(rowRect, Color(r: 245, g: 245, b: 245, a: 255))

      # Rows past the loaded tail are placeholders until onLoadMore delivers.
      if viewIdx >= widget.order.len:
        drawText("Loading...", widget.bounds.x + 4.0, rowY + (rowH - 12.0) / 2,
                 12.0, Color(r: 150, g: 150, b: 150, a: 255))
        continue

      let rowIdx = widget.order[viewIdx]
      drawSelectionBackground(rowRect, props,
                              selected = rowIdx in widget.selected,
                              hovered = viewIdx == widget.hoverRow)

      var x = widget.bounds.x
      for colIdx, col in widget.columns:
        drawText(cellText(widget.data[rowIdx], colIdx, col.formatFunc),
                 x + 4.0, rowY + (rowH - 12.0) / 2, 12.0, fgColor)
        if widget.showGrid:
          drawLine(x + col.width, rowY, x + col.width, rowY + rowH, gridColor)
        x += col.width

      if widget.showGrid:
        drawLine(widget.bounds.x, rowY + rowH,
                 widget.bounds.x + widget.bounds.width, rowY + rowH, gridColor)

    endClip(clip)
    drawThemedBorder(widget.bounds, props, widget.focused)
