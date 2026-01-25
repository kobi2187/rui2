## DataTable Widget - RUI2
##
## Advanced data table with filtering, sorting, and virtual scrolling.
## Supports multiple filter types per column and efficient rendering
## of large datasets (millions of rows).

import ../../core/widget_dsl
import std/[options, sets, json, algorithm, strutils, tables]

when defined(useGraphics):
  import raylib

type
  FilterKind* = enum
    fkNone           # No filter
    fkEquals         # Exact match
    fkContains       # Contains substring
    fkStartsWith     # Starts with prefix
    fkEndsWith       # Ends with suffix
    fkGreater        # Numeric > value
    fkLess           # Numeric < value
    fkBetween        # Numeric between min and max
    fkIn             # One of multiple values

  Filter* = object
    column*: string
    case kind*: FilterKind
    of fkEquals, fkContains, fkStartsWith, fkEndsWith:
      text*: string
    of fkGreater, fkLess:
      value*: float
    of fkBetween:
      min*, max*: float
    of fkIn:
      values*: seq[string]
    of fkNone:
      discard

  ColumnDef* = object
    id*: string
    title*: string
    width*: float32
    sortable*: bool
    filterable*: bool
    filterKinds*: set[FilterKind]  # Allowed filter types for this column
    formatFunc*: Option[proc(value: JsonNode): string]

  TableRow* = object
    id*: string
    values*: Table[string, JsonNode]  # Column ID -> value

  SortOrder* = enum
    soNone
    soAscending
    soDescending

defineWidget(DataTable):
  props:
    columns: seq[ColumnDef]
    data: seq[TableRow]      # All data (can be millions)
    rowHeight: float = 24.0
    headerHeight: float = 28.0
    filterHeight: float = 26.0
    showHeader: bool = true
    showFilter: bool = true
    showGrid: bool = true
    alternateRowColor: bool = true
    gridColor: Color = Color(r: 220, g: 220, b: 220, a: 255)
    altRowColor: Color = Color(r: 245, g: 245, b: 245, a: 255)

  state:
    selected: HashSet[int]   # Selected row indices
    filters: Table[string, Filter]  # Column ID -> active filter
    sortColumn: string       # Empty means no sort
    sortOrder: SortOrder
    scrollY: float
    filteredIndices: seq[int]  # Indices of rows that pass filters
    visibleStart: int
    visibleEnd: int
    hovered: int
    editingFilter: string    # Column ID of filter being edited

  actions:
    onSort(column: string, order: SortOrder)
    onFilter(filters: Table[string, Filter])
    onSelect(selected: HashSet[int])
    onDoubleClick(rowIndex: int)

  layout:
    discard

  render:
    when defined(useGraphics):
      # Calculate layout dimensions
      let filterH = if widget.showFilter: widget.filterHeight else: 0.0
      let headerH = if widget.showHeader: widget.headerHeight else: 0.0
      let topOffset = filterH + headerH
      let rowH = widget.rowHeight
      let scroll = widget.scrollY

      # Apply filters to get filtered row indices
      proc matchesFilters(row: TableRow): bool =
        let filters = widget.filters
        for colId, filter in filters:
          if filter.kind == fkNone:
            continue

          if not row.values.hasKey(colId):
            return false

          let value = row.values[colId]

          case filter.kind
          of fkEquals:
            if value.kind == JString and value.getStr() != filter.text:
              return false
          of fkContains:
            if value.kind == JString and filter.text notin value.getStr():
              return false
          of fkStartsWith:
            if value.kind == JString and not value.getStr().startsWith(filter.text):
              return false
          of fkEndsWith:
            if value.kind == JString and not value.getStr().endsWith(filter.text):
              return false
          of fkGreater:
            let numVal = if value.kind == JInt: value.getInt().float
                        elif value.kind == JFloat: value.getFloat()
                        else: 0.0
            if numVal <= filter.value:
              return false
          of fkLess:
            let numVal = if value.kind == JInt: value.getInt().float
                        elif value.kind == JFloat: value.getFloat()
                        else: 0.0
            if numVal >= filter.value:
              return false
          of fkBetween:
            let numVal = if value.kind == JInt: value.getInt().float
                        elif value.kind == JFloat: value.getFloat()
                        else: 0.0
            if numVal < filter.min or numVal > filter.max:
              return false
          of fkIn:
            if value.kind == JString and value.getStr() notin filter.values:
              return false
          of fkNone:
            discard

        return true

      # Build filtered indices (cache this for performance)
      var filtered: seq[int] = @[]
      for i, row in widget.data:
        if matchesFilters(row):
          filtered.add(i)

      widget.filteredIndices = filtered

      # Virtual scrolling on filtered data
      let totalRows = filtered.len
      let totalHeight = totalRows.float * rowH
      let viewHeight = widget.bounds.height - topOffset
      let maxScroll = max(0.0, totalHeight - viewHeight)

      let bufferRows = 10
      let visStart = max(0, int(scroll / rowH) - bufferRows)
      let visEnd = min(totalRows - 1, int((scroll + viewHeight) / rowH) + bufferRows)

      widget.visibleStart = visStart
      widget.visibleEnd = visEnd

      # Draw background
      DrawRectangleRec(
        widget.bounds,
        Color(r: 255, g: 255, b: 255, a: 255)
      )

      BeginScissorMode(
        widget.bounds.x.cint,
        widget.bounds.y.cint,
        widget.bounds.width.cint,
        widget.bounds.height.cint
      )

      let mousePos = GetMousePosition()
      let mouseInBounds = CheckCollisionPointRec(mousePos, widget.bounds)
      var newHovered = -1

      var currentY = widget.bounds.y

      # Draw filter bar
      if widget.showFilter:
        var x = widget.bounds.x

        for col in widget.columns:
          if not col.filterable:
            x += col.width
            continue

          let filterRect = Rectangle(
            x: x,
            y: currentY,
            width: col.width,
            height: filterH
          )

          # Get current filter for this column
          let currentFilter = widget.filters.getOrDefault(
            col.id,
            Filter(column: col.id, kind: fkNone)
          )

          # Draw filter type dropdown (simplified)
          let dropdownW = 60.0
          let dropdownRect = Rectangle(
            x: x + 2.0,
            y: currentY + 2.0,
            width: dropdownW,
            height: filterH - 4.0
          )

          DrawRectangleRec(dropdownRect, Color(r: 250, g: 250, b: 250, a: 255))
          DrawRectangleLinesEx(dropdownRect, 1.0, widget.gridColor)

          let filterLabel = case currentFilter.kind
                           of fkNone: "All"
                           of fkEquals: "="
                           of fkContains: "~"
                           of fkStartsWith: "^"
                           of fkEndsWith: "$"
                           of fkGreater: ">"
                           of fkLess: "<"
                           of fkBetween: "[]"
                           of fkIn: "in"

          DrawText(
            filterLabel.cstring,
            (x + 6.0).cint,
            (currentY + 6.0).cint,
            10,
            Color(r: 60, g: 60, b: 60, a: 255)
          )

          # TODO: Implement dropdown on click to change filter type

          # Draw filter value input (simplified - just display current value)
          let inputRect = Rectangle(
            x: x + dropdownW + 4.0,
            y: currentY + 2.0,
            width: col.width - dropdownW - 6.0,
            height: filterH - 4.0
          )

          DrawRectangleRec(inputRect, Color(r: 255, g: 255, b: 255, a: 255))
          DrawRectangleLinesEx(inputRect, 1.0, widget.gridColor)

          let filterValue = case currentFilter.kind
                           of fkEquals, fkContains, fkStartsWith, fkEndsWith:
                             currentFilter.text
                           of fkGreater, fkLess:
                             $currentFilter.value
                           of fkBetween:
                             $currentFilter.min & "-" & $currentFilter.max
                           of fkIn:
                             currentFilter.values.join(",")
                           of fkNone:
                             ""

          if filterValue.len > 0:
            DrawText(
              filterValue.cstring,
              (x + dropdownW + 8.0).cint,
              (currentY + 6.0).cint,
              10,
              Color(r: 40, g: 40, b: 40, a: 255)
            )

          # TODO: Implement text input for filter value

          x += col.width

        currentY += filterH

      # Draw header
      if widget.showHeader:
        var x = widget.bounds.x

        for col in widget.columns:
          let headerRect = Rectangle(
            x: x,
            y: currentY,
            width: col.width,
            height: headerH
          )

          let isHovered = mouseInBounds and CheckCollisionPointRec(mousePos, headerRect)
          let bgColor = if isHovered:
                         Color(r: 230, g: 240, b: 250, a: 255)
                       else:
                         Color(r: 240, g: 240, b: 240, a: 255)

          DrawRectangleRec(headerRect, bgColor)

          # Sort indicator
          let sortIndicator = if col.id == widget.sortColumn:
                               case widget.sortOrder
                               of soAscending: " ▲"
                               of soDescending: " ▼"
                               of soNone: ""
                             else: ""

          let headerText = col.title & sortIndicator

          DrawText(
            headerText.cstring,
            (x + 4.0).cint,
            (currentY + 6.0).cint,
            12,
            Color(r: 40, g: 40, b: 40, a: 255)
          )

          # Handle header click for sorting
          if col.sortable and mouseInBounds and IsMouseButtonPressed(MOUSE_LEFT_BUTTON):
            if CheckCollisionPointRec(mousePos, headerRect):
              if col.id == widget.sortColumn:
                let newOrder = case widget.sortOrder
                               of soNone: soAscending
                               of soAscending: soDescending
                               of soDescending: soNone
                widget.sortOrder = newOrder
              else:
                widget.sortColumn = col.id
                widget.sortOrder = soAscending

              if widget.onSort.isSome:
                widget.onSort.get()(widget.sortColumn, widget.sortOrder)

          if widget.showGrid:
            DrawRectangleLinesEx(headerRect, 1.0, widget.gridColor)

          x += col.width

        currentY += headerH

      # Draw rows (only visible filtered rows)
      let dataAreaY = currentY

      for visIdx in visStart..visEnd:
        if visIdx >= totalRows:
          break

        let rowIdx = filtered[visIdx]  # Map to original data index
        let row = widget.data[rowIdx]
        let rowY = dataAreaY + (visIdx.float * rowH) - scroll

        if rowY + rowH < dataAreaY or rowY > widget.bounds.y + widget.bounds.height:
          continue

        let rowRect = Rectangle(
          x: widget.bounds.x,
          y: rowY,
          width: widget.bounds.width,
          height: rowH
        )

        if mouseInBounds and CheckCollisionPointRec(mousePos, rowRect):
          newHovered = rowIdx

        # Draw row background
        let isSelected = rowIdx in widget.selected
        let isHovered = rowIdx == widget.hovered
        let isAltRow = widget.alternateRowColor and (visIdx mod 2 == 1)

        if isSelected:
          DrawRectangleRec(rowRect, Color(r: 100, g: 150, b: 255, a: 150))
        elif isHovered:
          DrawRectangleRec(rowRect, Color(r: 230, g: 240, b: 255, a: 255))
        elif isAltRow:
          DrawRectangleRec(rowRect, widget.altRowColor)

        # Draw cells
        var x = widget.bounds.x

        for col in widget.columns:
          let cellRect = Rectangle(
            x: x,
            y: rowY,
            width: col.width,
            height: rowH
          )

          # Get and format cell value
          let text = if row.values.hasKey(col.id):
                      let value = row.values[col.id]
                      if col.formatFunc.isSome:
                        col.formatFunc.get()(value)
                      elif value.kind == JString:
                        value.getStr()
                      elif value.kind == JInt:
                        $value.getInt()
                      elif value.kind == JFloat:
                        value.getFloat().formatFloat(ffDecimal, 2)
                      elif value.kind == JBool:
                        $value.getBool()
                      else:
                        $value
                    else:
                      ""

          DrawText(
            text.cstring,
            (x + 4.0).cint,
            (rowY + 4.0).cint,
            12,
            Color(r: 40, g: 40, b: 40, a: 255)
          )

          if widget.showGrid:
            DrawRectangleLinesEx(cellRect, 1.0, widget.gridColor)

          x += col.width

        # Handle row click
        if mouseInBounds and IsMouseButtonPressed(MOUSE_LEFT_BUTTON):
          if CheckCollisionPointRec(mousePos, rowRect):
            let ctrlDown = IsKeyDown(KEY_LEFT_CONTROL) or IsKeyDown(KEY_RIGHT_CONTROL)

            var newSelection = widget.selected

            if ctrlDown:
              if rowIdx in newSelection:
                newSelection.excl(rowIdx)
              else:
                newSelection.incl(rowIdx)
            else:
              newSelection = [rowIdx].toHashSet

            widget.selected = newSelection

            if widget.onSelect.isSome:
              widget.onSelect.get()(newSelection)

      widget.hovered = newHovered

      EndScissorMode()

      # Draw scrollbar
      if totalHeight > viewHeight:
        let scrollbarW = 12.0
        let scrollbarRect = Rectangle(
          x: widget.bounds.x + widget.bounds.width - scrollbarW,
          y: widget.bounds.y + topOffset,
          width: scrollbarW,
          height: viewHeight
        )

        DrawRectangleRec(scrollbarRect, Color(r: 230, g: 230, b: 230, a: 255))

        let thumbHeight = max(20.0, viewHeight * (viewHeight / totalHeight))
        let thumbY = scrollbarRect.y + (scroll / maxScroll) * (viewHeight - thumbHeight)

        let thumbRect = Rectangle(
          x: scrollbarRect.x + 2.0,
          y: thumbY,
          width: scrollbarW - 4.0,
          height: thumbHeight
        )

        DrawRectangleRec(thumbRect, Color(r: 150, g: 150, b: 150, a: 255))

        if mouseInBounds and IsMouseButtonDown(MOUSE_LEFT_BUTTON):
          if CheckCollisionPointRec(mousePos, scrollbarRect):
            let newScroll = ((mousePos.y - scrollbarRect.y) / viewHeight) * maxScroll
            widget.scrollY = clamp(newScroll, 0.0, maxScroll)

      # Mouse wheel
      if mouseInBounds:
        let wheel = GetMouseWheelMove()
        if wheel != 0.0:
          let newScroll = widget.scrollY - (wheel * rowH * 3.0)
          widget.scrollY = clamp(newScroll, 0.0, maxScroll)

      # Draw border
      DrawRectangleLinesEx(
        widget.bounds,
        1.0,
        Color(r: 180, g: 180, b: 180, a: 255)
      )

    else:
      # Non-graphics mode
      echo "DataTable:"
      echo "  Columns: ", widget.columns.len
      echo "  Total rows: ", widget.data.len
      echo "  Filtered rows: ", widget.filteredIndices.len
      echo "  Visible rows: ", widget.visibleStart, " to ", widget.visibleEnd
      echo "  Active filters: ", widget.filters.len
      echo "  Sort: ", widget.sortColumn, ", ", widget.sortOrder
