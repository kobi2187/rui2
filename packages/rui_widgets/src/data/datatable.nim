## DataTable Widget - RUI2
##
## Data table with per-column filtering, sorting and virtual scrolling, sized
## for large datasets: only the rows on screen are ever drawn.
##
## Filtering and sorting run in `layout` and cache their result in
## `filteredIndices`. The pre-split version rebuilt the filtered index list from
## scratch inside `render`, on every single frame, over the whole dataset.
##
## FilterKind / Filter / DataRow / SortOrder come from datatable_helpers, which also owns
## the matching and comparison logic. They used to be declared a second time in
## this file, with a second, subtly different implementation of the matcher:
## the local copy guarded every string test with `value.kind == JString`, so a
## numeric cell silently passed every text filter.

import rui_core
import ../hover
import rui_drawing
import ../virtual_rows
import ../scroll_drag
import datatable_helpers

export virtual_rows
import std/[options, sets, json, tables]
# `from`, not `import`: std/algorithm exports its own SortOrder, which would make
# ours ambiguous. The old file only escaped this because it declared SortOrder
# locally, and a local declaration shadows an imported one.
from std/algorithm import sort

import raylib

import tabular
import ../seq_follow
import ../sources
import tabular_render
import ../input/textarea
export datatable_helpers, tabular, tabular_render

template filterHeightOf(w: untyped): float32 =
  ## Filter strip height: the prop, else the theme's.
  themedSize(w.filterHeight, currentTheme.barHeight(26.0))

template headerHeightOf(w: untyped): float32 =
  ## Header height: the prop, else the theme's.
  themedSize(w.headerHeight, currentTheme.barHeight(28.0))

template rowHeightOf(w: untyped): float32 =
  ## Row height: the prop, else the theme's.
  themedSize(w.rowHeight, currentTheme.rowHeight(24.0))

type
  DataColumn* = object
    id*: string
    title*: string
    width*: float32
    sortable*: bool
    filterable*: bool
    filterKinds*: set[FilterKind]  # Filter types offered for this column
    formatFunc*: Option[proc(value: JsonNode): string]

const BufferRows = 10

type TableMetrics* = BandMetrics
  ## Alias: the band arithmetic is shared with DataGrid, in tabular.nim.

template viewCount*(widget: untyped): int =
  ## How many rows the table shows: the source's count, or the filtered rows.
  (if widget.source != nil: widget.source.count else: widget.filteredIndices.len)

template dataRowOf*(widget: untyped, viewIdx: int): int =
  ## The row behind shown row `viewIdx`: itself for a source (which does its own
  ## ordering), else its index into `data`.
  (if widget.source != nil: viewIdx else: widget.filteredIndices[viewIdx])

template shownRows*(widget: untyped): RowView =
  (if widget.source != nil: identityView(widget.source.count)
   else: rowView(widget.filteredIndices))

template metricsOf*(widget: untyped): TableMetrics =
  ## A template, not a proc: the DataTable type does not exist until the macro
  ## below has expanded, and the widget body needs this.
  let fh = if widget.showFilter: filterHeightOf(widget) else: 0.0'f32
  let hh = if widget.showHeader: headerHeightOf(widget) else: 0.0'f32
  TableMetrics(
    originX: widget.bounds.x, originY: widget.bounds.y,
    filterH: fh, headerH: hh,
    totalRows: viewCount(widget),
    rows: rowViewport(top = widget.bounds.y + fh + hh,
                      height = widget.bounds.height - fh - hh,
                      rowHeight = rowHeightOf(widget),
                      scrollY = widget.scrollY)
  )

template sortByColumnAt*(widget: untyped, mouseX: float32): bool =
  ## Cycle the sort order of the column under `mouseX`. A header click is always
  ## consumed, whether or not it landed on a sortable column.
  block:
    let idx = columnAt(widget.columns, widget.bounds.x, mouseX)
    if widget.source != nil and not widget.source.canSort:
      discard                         # a file cannot be sorted cheaply: the header does nothing
    elif widget.columns.isSortable(idx):
      let order = nextSortFor(widget.columns[idx].id == widget.sortColumn,
                              widget.sortOrder)
      widget.sortColumn = if order == soNone: "" else: widget.columns[idx].id
      widget.sortOrder = order
      widget.isDirty = true
      widget.layoutDirty = true   # ordering is decided in layout
      if widget.source != nil:
        widget.source.sortBy(widget.columns[idx].id,
          (case order
           of soAscending: sdAscending
           of soDescending: sdDescending
           else: sdNone))
      if widget.onSort != nil:
        widget.onSort(widget.columns[idx].id, order)
    true

template selectRowAt*(widget: untyped, viewIdx: int): bool =
  ## Select the source row behind filtered-view row `viewIdx`. Selection is kept
  ## against the source index so it survives a change of filter.
  block:
    if viewIdx < 0:
      false
    else:
      assert viewIdx < viewCount(widget),
             "rowAt must not return an index past the filtered view"
      let rowIdx = dataRowOf(widget, viewIdx)
      updateSelection(widget.selected, rowIdx,
                      event.ctrl)
      widget.focusRow = viewIdx
      widget.anchorRow = viewIdx
      widget.isDirty = true
      if widget.onSelect != nil:
        widget.onSelect(widget.selected)
      true

template applyTypedFilter(widget: untyped, colId: string, text: string) =
  ## A filter box changed: set that column's filter (live, as typed). A line
  ## that is not yet a filter (`>` with no number) leaves the old one.
  block:
    let parsed = parseFilter(colId, text)
    if parsed.valid:
      if parsed.filter.kind == fkNone:
        widget.filters.del(colId)
      else:
        widget.filters[colId] = parsed.filter
      widget.layoutDirty = true      # filtering happens in layout
      widget.isDirty = true
      if widget.source != nil and widget.source.canFilter:
        widget.source.setFilters(toColumnFilters(widget.filters))
      if widget.onFilter != nil:
        widget.onFilter(widget.filters)

proc typedFilterHandler[W](table: W, colId: string): proc(t: string) {.closure.} =
  ## What a filter box does on a change. A proc of its own so each box
  ## holds its own column: a closure made inside the loop shared one.
  result = proc(t: string) = table.applyTypedFilter(colId, t)

template ensureEditors(widget: untyped) =
  ## One TextInput per filterable column, children of the table so they take
  ## clicks and keys like any other. Created once, then kept in step with
  ## `filters` (so a filter set from code shows in its box).
  block:
    let table = widget
    for col in table.columns:
      if not col.filterable or col.id in table.editors:
        continue
      let box = newTextInput(placeholder = "Filter", fontSize = 12.0, padding = 3.0)
      box.onChange = typedFilterHandler(table, col.id)
      table.editors[col.id] = box
      table.addChild box
    for colId, box in table.editors:
      let wanted = filterText(table.filters.getOrDefault(colId, Filter(column: colId)))
      if not box.focused and box.text != wanted:
        box.text = wanted
        box.cursorPos = wanted.len
        box.layoutDirty = true

proc toColumnFilters*(filters: Table[string, Filter]): seq[ColumnFilter] =
  ## The table's typed filters as the source's. `in` has no source form and is
  ## left out; `between` is a pair of bounds.
  for column, f in filters:
    case f.kind
    of fkContains: result.add ColumnFilter(column: column, op: foContains, text: f.text)
    of fkStartsWith: result.add ColumnFilter(column: column, op: foStartsWith, text: f.text)
    of fkEndsWith: result.add ColumnFilter(column: column, op: foEndsWith, text: f.text)
    of fkEquals: result.add ColumnFilter(column: column, op: foEquals, text: f.text)
    of fkGreater: result.add ColumnFilter(column: column, op: foGreater, text: $f.value)
    of fkLess: result.add ColumnFilter(column: column, op: foLess, text: $f.value)
    of fkBetween:
      result.add ColumnFilter(column: column, op: foGreaterEq, text: $f.min)
      result.add ColumnFilter(column: column, op: foLessEq, text: $f.max)
    of fkIn, fkNone: discard

definePrimitive(DataTable):
  props:
    columns: seq[DataColumn] = @[]
    data: seq[DataRow] = @[]    # The whole dataset; can be large
    rowHeight: float32 = 0.0   # 0: from the theme
    headerHeight: float32 = 0.0   # 0: from the theme
    filterHeight: float32 = 0.0   # 0: from the theme
    showHeader: bool = true
    showFilter: bool = true
    showGrid: bool = true
    alternateRowColor: bool = true
    visibleRows: int = 12
    intent: ThemeIntent = Default

  state:
    focusRow: int                # the keyboard's row, in the rows as shown
    anchorRow: int               # where a Shift range starts
    selected: HashSet[int]       # Indices into `data`, not into the filtered view
    source: RowSource            # where the rows come from, instead of `data`
    columnMap: seq[int]          # each column's index in the source, -1 for none
    filters: Table[string, Filter]
    sortColumn: string           # Empty means unsorted
    sortOrder: SortOrder
    scrollY: float32
    touch: RowsTouch             # a finger's tap or drag (scroll_drag.nim)
    vbar: VBar                   # the scroll bar's drag and hover
    filteredIndices: seq[int]
    visibleStart: int
    visibleEnd: int
    hoverRow: int                # Not `hovered`: Widget already has that (a bool)
    editors: Table[string, TextInput]  # the filter box above each filterable column

  actions:
    onSort(column: string, order: SortOrder)
    onFilter(filters: Table[string, Filter])
    onSelect(selected: HashSet[int])
    onActivate(row: int)         # Enter on the focus row (a source row index)

  init:
    widget.focusable = true
    widget.multiPointer = true
    widget.resetOnLeave:
      widget.hoverRow = -1
      widget.vbar.hover = false
    widget.hoverRow = -1       # nothing is under the pointer yet

  events:
    on_mouse_up:
      let m = metricsOf(widget)
      if widget.rowsTouch(widget.touch, event, widget.scrollY, m.rows,
                          viewCount(widget), barTrackOf(widget, m)): return true
      return widget.rowsUp(widget.vbar)

    on_mouse_down:
      let m = metricsOf(widget)
      if widget.rowsTouch(widget.touch, event, widget.scrollY, m.rows,
                          viewCount(widget), barTrackOf(widget, m)): return true
      if widget.rowsDown(widget.vbar, widget.scrollY, barTrackOf(widget, m), m.rows,
                         viewCount(widget), event.mousePos):
        return true
      if m.overHeader(event.mousePos.y):
        return widget.sortByColumnAt(event.mousePos.x)
      return widget.selectRowAt(m.rows.rowAt(event.mousePos.y, viewCount(widget)))

    on_mouse_move:
      let m = metricsOf(widget)
      if widget.rowsTouch(widget.touch, event, widget.scrollY, m.rows,
                          viewCount(widget), barTrackOf(widget, m)): return true
      let at = widget.rowsMove(widget.vbar, widget.scrollY, barTrackOf(widget, m),
                               m.rows, viewCount(widget), event.mousePos)
      if at.taken: return true
      if at.row != widget.hoverRow:
        widget.hoverRow = at.row
        widget.isDirty = true
      return false

    on_mouse_wheel:
      let m = metricsOf(widget)
      discard widget.rowsWheel(m.rows, viewCount(widget), event.wheelDelta, widget.scrollY)
      return true

    on_key_down:
      let m = metricsOf(widget)
      return widget.tableKeyDown(shownRows(widget), m.rows, event)

  layout:
    widget.ensureEditors()
    # Filter, then sort, then cache. Doing this here rather than in render means
    # it runs when the data or the filters change, not once per frame.
    widget.filteredIndices.setLen(0)
    if widget.source == nil:
      for i, row in widget.data:
        if row.matchesAllFilters(widget.filters):
          widget.filteredIndices.add(i)

    if widget.source == nil and widget.sortColumn.len > 0 and widget.sortOrder != soNone:
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
                             float32(widget.visibleRows) * rowHeightOf(widget)

    # The filter boxes sit in the strip above their columns.
    let stripH = if widget.showFilter: filterHeightOf(widget) else: 0.0'f32
    var cellX = widget.bounds.x
    for col in widget.columns:
      if col.id in widget.editors:
        let box = widget.editors[col.id]
        box.visible = widget.showFilter and col.filterable
        if box.visible:
          box.arrange(Rect(x: cellX + 2, y: widget.bounds.y + 2,
                           width: max(0.0'f32, col.width - 4),
                           height: max(0.0'f32, stripH - 4)))
      cellX += col.width

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let headerProps = currentTheme.getThemeProps(widget.intent, Selected)
    let m = metricsOf(widget)
    let filterH = m.filterH
    let rowH = m.rowHeight
    let rowsTop = m.rowsTop
    let viewHeight = m.viewHeight

    let visible = m.rows.visibleRange(viewCount(widget), buffer = BufferRows)
    widget.visibleStart = visible.a
    widget.visibleEnd = visible.b

    drawThemedBackground(widget.bounds, props)
    let gridColor = props.borderColor.get(DefaultGridColor)
    let fgColor = props.foregroundColor.get(DefaultInkColor)
    let clip = beginClip(widget.bounds)

    # The filter strip is the filter boxes (children, composited over this).

    # Header row with sort indicators. DataTable tracks its sorted column by
    # id, so it resolves that to an index here; the shared drawing takes the
    # index, because DataGrid keeps one.
    if widget.showHeader:
      var sortedIndex = -1
      for i, col in widget.columns:
        if col.id == widget.sortColumn:
          sortedIndex = i
          break
      drawColumnHeaders(widget.columns, widget.bounds.x, m.headerTop, m.headerH,
                        sortedIndex, widget.sortOrder, headerProps,
                        widget.showGrid, gridColor)

    # Body: only the rows that can be on screen.
    let pendingFg = currentTheme.getThemeProps(widget.intent, Disabled).foregroundColor.get(
                      fgColor.withAlpha(0.45'f32))
    if widget.source != nil and visible.b >= visible.a:
      widget.source.want(visible.a, visible.b)
    for viewIdx in visible:
      let rowIdx = dataRowOf(widget, viewIdx)
      let rowY = m.rows.rowTop(viewIdx)
      let rowRect = Rect(x: widget.bounds.x, y: rowY,
                         width: widget.bounds.width, height: rowH)
      drawRowBackground(rowRect, props, viewIdx, widget.alternateRowColor,
                        selected = rowIdx in widget.selected,
                        hovered = viewIdx == widget.hoverRow)
      if widget.focused and viewIdx == widget.focusRow:
        drawFocusRing(rowRect, props.borderColor.get(GRAY))   # the keyboard's row

      var texts: seq[string] = @[]
      var ink = fgColor
      if widget.source != nil:
        if widget.source.rowState(viewIdx) == rsPending:
          # Known to exist, not here yet: placeholders in the theme's disabled ink.
          ink = pendingFg
          for col in widget.columns: texts.add "..."
        else:
          for ci, col in widget.columns:
            let sc = if ci < widget.columnMap.len: widget.columnMap[ci] else: -1
            texts.add(if sc >= 0: widget.source.cell(viewIdx, sc) else: "")
      else:
        for col in widget.columns:
          texts.add(getCellText(widget.data[rowIdx], col.id,
                                if col.formatFunc.isSome: col.formatFunc.get()
                                else: nil))
      drawCells(widget.columns, widget.bounds.x, rowY, rowH, texts, ink,
                widget.showGrid, gridColor, props.cellFontSize)

      if widget.showGrid:
        drawRowGridLine(rowRect, gridColor)

    endClip(clip)
    widget.vbar.drawBar(barTrackOf(widget, m), m.rows.contentHeight(viewCount(widget)), m.viewHeight,
                        widget.scrollY, props)
    drawThemedBorder(widget.bounds, props, widget.focused)

proc bindRows*(table: DataTable, source: LinkSeq[DataRow]) =
  ## Show `source` as the table's data and follow its edits one by one.
  ## Selection is kept against source rows, so it stays on the rows it was on
  ## through inserts, removals and moves; filtering and sorting are redone on
  ## the next layout as they always are.
  table.data = source.toSeq
  table.layoutDirty = true
  source.attach(table, proc(change: SeqChange) =
    change.apply(table.data, source)
    var place = RowPlace(selection: table.selected, focus: 0, hover: table.hoverRow,
                         anchor: 0, scrollY: table.scrollY)
    # focus and anchor are positions in the filtered view, which the next
    # layout rebuilds; only the selection is carried by source index.
    let lost = place.followEdit(change, table.data.len, rowHeightOf(table),
                                table.bounds.height)
    table.selected = place.selection
    table.hoverRow = -1
    table.scrollY = place.scrollY
    table.layoutDirty = true
    table.isDirty = true
    if lost and table.onSelect != nil: table.onSelect(table.selected))


proc bindSource*(table: DataTable, source: RowSource) =
  ## Show the rows of `source`, asking it only for the ones on screen. With no
  ## `columns` given, one is made per source column. A source that can sort or
  ## filter (SQLite, MemorySource) does it when the header or a filter box is
  ## used; a file source cannot, and the header then does nothing. Rows still
  ## being fetched draw as placeholders in the theme's disabled ink.
  table.source = source
  table.data = @[]
  table.selected.clear()
  let auto = table.columns.len == 0
  proc buildColumns() =
    # One column per source column, unless the caller gave their own. A file
    # source learns its columns once it has opened (a moment after binding).
    if auto:
      table.columns.setLen(0)
      if source.columns != @["value"] or source.count > 0:
        for name in source.columns:
          table.columns.add DataColumn(id: name, title: name, width: 120,
                                       sortable: source.canSort, filterable: source.canFilter,
                                       filterKinds: {fkContains})
  proc mapColumns() =
    table.columnMap.setLen(0)
    for i, col in table.columns:
      let byName = source.columnIndex(col.id)
      table.columnMap.add(if byName >= 0: byName elif i < source.columns.len: i else: -1)
  buildColumns()
  mapColumns()
  table.layoutDirty = true
  source.attach(table, proc(change: SeqChange) =
    if change.kind == scReset or table.columnMap.len == 0:
      buildColumns()
      mapColumns()
    var place = RowPlace(selection: table.selected, focus: table.focusRow,
                         hover: table.hoverRow, anchor: table.anchorRow,
                         scrollY: table.scrollY)
    let lost = place.followEdit(change, source.count, rowHeightOf(table),
                                table.bounds.height)
    table.selected = place.selection
    table.focusRow = place.focus
    table.anchorRow = place.anchor
    table.hoverRow = -1
    table.scrollY = place.scrollY
    table.layoutDirty = true
    table.isDirty = true
    if lost and table.onSelect != nil: table.onSelect(table.selected))

proc bindRows*(table: DataTable, source: RowSource) = table.bindSource(source)
  ## `ui:` spelling: `DataTable(rows = -> source)`.
