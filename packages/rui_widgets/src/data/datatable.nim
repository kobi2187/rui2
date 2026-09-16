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
import datatable_helpers
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

  events:
    on_mouse_down:
      let filterH = if widget.showFilter: widget.filterHeight else: 0.0'f32
      let headerH = if widget.showHeader: widget.headerHeight else: 0.0'f32
      let headerTop = widget.bounds.y + filterH
      let rowsTop = headerTop + headerH

      # Header click: cycle this column's sort order.
      if widget.showHeader and event.mousePos.y >= headerTop and
         event.mousePos.y < rowsTop:
        var x = widget.bounds.x
        for col in widget.columns:
          if event.mousePos.x >= x and event.mousePos.x < x + col.width:
            if not col.sortable:
              return true
            widget.sortOrder =
              if col.id == widget.sortColumn: nextSortOrder(widget.sortOrder)
              else: soAscending
            widget.sortColumn = if widget.sortOrder == soNone: "" else: col.id
            widget.isDirty = true
            widget.layoutDirty = true   # ordering is decided in layout
            if widget.onSort.isSome:
              widget.onSort.get()(col.id, widget.sortOrder)
            return true
          x += col.width
        return true

      if event.mousePos.y < rowsTop:
        return false   # inside the filter strip

      let viewIdx = int((event.mousePos.y - rowsTop + widget.scrollY) / widget.rowHeight)
      if viewIdx < 0 or viewIdx >= widget.filteredIndices.len:
        return false

      # Selection is stored against the source row, so it survives re-filtering.
      let rowIdx = widget.filteredIndices[viewIdx]
      let ctrlDown = isKeyDown(LeftControl) or isKeyDown(RightControl)
      updateSelection(widget.selected, rowIdx, ctrlDown)
      widget.isDirty = true
      if widget.onSelect.isSome:
        widget.onSelect.get()(widget.selected)
      return true

    on_mouse_move:
      let filterH = if widget.showFilter: widget.filterHeight else: 0.0'f32
      let headerH = if widget.showHeader: widget.headerHeight else: 0.0'f32
      let rowsTop = widget.bounds.y + filterH + headerH
      var newHover = -1
      if event.mousePos.y >= rowsTop:
        let viewIdx = int((event.mousePos.y - rowsTop + widget.scrollY) / widget.rowHeight)
        if viewIdx >= 0 and viewIdx < widget.filteredIndices.len:
          newHover = viewIdx
      if newHover != widget.hoverRow:
        widget.hoverRow = newHover
        widget.isDirty = true
      return false

    on_mouse_wheel:
      let filterH = if widget.showFilter: widget.filterHeight else: 0.0'f32
      let headerH = if widget.showHeader: widget.headerHeight else: 0.0'f32
      let viewHeight = widget.bounds.height - filterH - headerH
      let maxScroll = max(0.0'f32,
        float32(widget.filteredIndices.len) * widget.rowHeight - viewHeight)
      let newScroll = clamp(widget.scrollY - event.wheelDelta * widget.rowHeight * 3.0,
                            0.0'f32, maxScroll)
      if newScroll != widget.scrollY:
        widget.scrollY = newScroll
        widget.isDirty = true
      return true

  layout:
    # Filter, then sort, then cache. Doing this here rather than in render means
    # it runs when the data or the filters change, not once per frame.
    widget.filteredIndices.setLen(0)
    for i, row in widget.data:
      var keep = true
      for colId, filter in widget.filters:
        if not matchesColumnFilter(row, colId, filter):
          keep = false
          break
      if keep:
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
      let filterH = if widget.showFilter: widget.filterHeight else: 0.0'f32
      let headerH = if widget.showHeader: widget.headerHeight else: 0.0'f32
      widget.bounds.height = filterH + headerH +
                             float32(widget.visibleRows) * widget.rowHeight

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let headerProps = currentTheme.getThemeProps(widget.intent, Selected)
    let filterH = if widget.showFilter: widget.filterHeight else: 0.0'f32
    let headerH = if widget.showHeader: widget.headerHeight else: 0.0'f32
    let rowH = widget.rowHeight
    let rowsTop = widget.bounds.y + filterH + headerH
    let viewHeight = widget.bounds.height - filterH - headerH

    let visStart = max(0, int(widget.scrollY / rowH) - BufferRows)
    let visEnd = min(widget.filteredIndices.len - 1,
                     int((widget.scrollY + viewHeight) / rowH) + BufferRows)
    widget.visibleStart = visStart
    widget.visibleEnd = visEnd

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
        let headerRect = Rect(x: x, y: widget.bounds.y + filterH,
                              width: col.width, height: headerH)
        drawThemedBackground(headerRect, headerProps)
        let indicator = if col.id == widget.sortColumn:
                          sortIndicatorFor(widget.sortOrder)
                        else:
                          ""
        drawThemedPaddedText(col.title & indicator, headerRect, headerProps,
                             selected = true)
        if widget.showGrid:
          drawLine(x + col.width, headerRect.y,
                   x + col.width, headerRect.y + headerH, gridColor)
        x += col.width

    # Body: only the rows that can be on screen.
    for viewIdx in visStart..visEnd:
      if viewIdx < 0 or viewIdx >= widget.filteredIndices.len:
        break
      let rowIdx = widget.filteredIndices[viewIdx]
      let rowY = rowsTop + float32(viewIdx) * rowH - widget.scrollY
      if rowY + rowH < rowsTop or rowY > rowsTop + viewHeight:
        continue

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
