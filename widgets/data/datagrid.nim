## DataGrid Widget - RUI2
##
## Sortable data grid with virtual row rendering for large datasets.
## Supports column sorting, row selection, and custom formatting.
## Uses virtual scrolling to efficiently handle millions of rows.

import ../../core/widget_dsl
import std/[options, sets, json, algorithm, strutils]

when defined(useGraphics):
  import raylib

type
  Column* = object
    id*: string
    title*: string
    width*: float32
    sortable*: bool
    formatFunc*: Option[proc(value: JsonNode): string]

  Row* = object
    id*: string
    values*: seq[JsonNode]  # One value per column

  SortOrder* = enum
    soNone      # No sorting
    soAscending
    soDescending

defineWidget(DataGrid):
  props:
    columns: seq[Column]
    data: seq[Row]           # Loaded data (can be subset of total)
    totalRowCount: int = -1  # -1 means use data.len, otherwise for lazy loading
    rowHeight: float = 24.0
    headerHeight: float = 28.0
    showHeader: bool = true
    showGrid: bool = true
    alternateRowColor: bool = true
    gridColor: Color = Color(r: 220, g: 220, b: 220, a: 255)
    altRowColor: Color = Color(r: 245, g: 245, b: 245, a: 255)

  state:
    selected: HashSet[int]   # Selected row indices
    sortColumn: int          # -1 means no sort
    sortOrder: SortOrder
    scrollY: float           # Vertical scroll offset
    visibleStart: int        # First visible row index
    visibleEnd: int          # Last visible row index
    hovered: int             # Hovered row index (-1 if none)

  actions:
    onSort(column: int, order: SortOrder)
    onSelect(selected: HashSet[int])
    onDoubleClick(rowIndex: int)
    onLoadMore(startIndex: int, count: int)  # Lazy loading callback
    onScrollNearEnd()                        # Triggered when scrolling near bottom

  layout:
    # No children to layout - draws directly
    discard

  render:
    when defined(useGraphics):
      let headerH = if widget.showHeader: widget.headerHeight else: 0.0
      let rowH = widget.rowHeight
      let scroll = widget.scrollY

      # Calculate total content height
      let totalRows = if widget.totalRowCount >= 0: widget.totalRowCount else: widget.data.len
      let totalHeight = totalRows.float * rowH
      let viewHeight = widget.bounds.height - headerH
      let maxScroll = max(0.0, totalHeight - viewHeight)

      # Virtual scrolling: calculate visible row range
      let bufferRows = 10  # Render extra rows above/below viewport
      let visStart = max(0, int(scroll / rowH) - bufferRows)
      let visEnd = min(totalRows - 1, int((scroll + viewHeight) / rowH) + bufferRows)

      widget.visibleStart = visStart
      widget.visibleEnd = visEnd

      # Check if we need to load more data (lazy loading)
      if widget.onLoadMore.isSome and visEnd >= widget.data.len - 20:
        # We're near the end of loaded data, request more
        let needCount = min(100, totalRows - widget.data.len)
        if needCount > 0:
          widget.onLoadMore.get()(widget.data.len, needCount)

      # Check if near end (trigger lazy loading)
      let scrollRatio = if maxScroll > 0: scroll / maxScroll else: 0.0
      if scrollRatio > 0.8:  # Within 20% of bottom
        if widget.onScrollNearEnd.isSome:
          widget.onScrollNearEnd.get()()

      # Draw background
      DrawRectangleRec(
        widget.bounds,
        Color(r: 255, g: 255, b: 255, a: 255)
      )

      # Begin scissor mode for clipping
      BeginScissorMode(
        widget.bounds.x.cint,
        widget.bounds.y.cint,
        widget.bounds.width.cint,
        widget.bounds.height.cint
      )

      # Get mouse state
      let mousePos = GetMousePosition()
      let mouseInBounds = CheckCollisionPointRec(mousePos, widget.bounds)
      var newHovered = -1

      # Draw header if enabled
      if widget.showHeader:
        var x = widget.bounds.x
        let headerY = widget.bounds.y

        for colIdx, col in widget.columns:
          let headerRect = Rectangle(
            x: x,
            y: headerY,
            width: col.width,
            height: headerH
          )

          # Header background
          let isHovered = mouseInBounds and CheckCollisionPointRec(mousePos, headerRect)
          let bgColor = if isHovered:
                         Color(r: 230, g: 240, b: 250, a: 255)
                       else:
                         Color(r: 240, g: 240, b: 240, a: 255)

          DrawRectangleRec(headerRect, bgColor)

          # Sort indicator
          let sortIndicator = if colIdx == widget.sortColumn:
                               case widget.sortOrder
                               of soAscending: " ▲"
                               of soDescending: " ▼"
                               of soNone: ""
                             else: ""

          let headerText = col.title & sortIndicator

          # Draw header text
          DrawText(
            headerText.cstring,
            (x + 4.0).cint,
            (headerY + 6.0).cint,
            12,
            Color(r: 40, g: 40, b: 40, a: 255)
          )

          # Handle header click for sorting
          if col.sortable and mouseInBounds and IsMouseButtonPressed(MOUSE_LEFT_BUTTON):
            if CheckCollisionPointRec(mousePos, headerRect):
              if colIdx == widget.sortColumn:
                # Toggle sort order
                let newOrder = case widget.sortOrder
                               of soNone: soAscending
                               of soAscending: soDescending
                               of soDescending: soNone
                widget.sortOrder = newOrder
              else:
                widget.sortColumn = colIdx
                widget.sortOrder = soAscending

              if widget.onSort.isSome:
                widget.onSort.get()(widget.sortColumn, widget.sortOrder)

          # Draw header border
          if widget.showGrid:
            DrawRectangleLinesEx(headerRect, 1.0, widget.gridColor)

          x += col.width

      # Draw rows (only visible rows - virtual scrolling)
      let dataAreaY = widget.bounds.y + headerH

      for rowIdx in visStart..visEnd:
        if rowIdx >= totalRows:
          break

        # Check if row is loaded
        let rowLoaded = rowIdx < widget.data.len
        let row = if rowLoaded: widget.data[rowIdx] else: Row(id: "", values: @[])
        let rowY = dataAreaY + (rowIdx.float * rowH) - scroll

        # Skip if completely outside bounds
        if rowY + rowH < dataAreaY or rowY > widget.bounds.y + widget.bounds.height:
          continue

        let rowRect = Rectangle(
          x: widget.bounds.x,
          y: rowY,
          width: widget.bounds.width,
          height: rowH
        )

        # Check hover
        if mouseInBounds and CheckCollisionPointRec(mousePos, rowRect):
          newHovered = rowIdx

        # Draw row background
        let isSelected = rowIdx in widget.selected
        let isHovered = rowIdx == widget.hovered
        let isAltRow = widget.alternateRowColor and (rowIdx mod 2 == 1)

        if isSelected:
          DrawRectangleRec(rowRect, Color(r: 100, g: 150, b: 255, a: 150))
        elif isHovered:
          DrawRectangleRec(rowRect, Color(r: 230, g: 240, b: 255, a: 255))
        elif isAltRow:
          DrawRectangleRec(rowRect, widget.altRowColor)

        # Draw cells
        var x = widget.bounds.x

        for colIdx, col in widget.columns:
          let cellRect = Rectangle(
            x: x,
            y: rowY,
            width: col.width,
            height: rowH
          )

          # Format cell value
          let text = if not rowLoaded:
                      if colIdx == 0: "Loading..." else: ""
                     elif colIdx >= row.values.len:
                      ""
                     else:
                      let value = row.values[colIdx]
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

          # Draw cell text (clipped to cell bounds)
          let textColor = if not rowLoaded:
                            Color(r: 150, g: 150, b: 150, a: 255)
                          else:
                            Color(r: 40, g: 40, b: 40, a: 255)

          DrawText(
            text.cstring,
            (x + 4.0).cint,
            (rowY + 4.0).cint,
            12,
            textColor
          )

          # Draw cell border
          if widget.showGrid:
            DrawRectangleLinesEx(cellRect, 1.0, widget.gridColor)

          x += col.width

        # Handle row click
        if mouseInBounds and IsMouseButtonPressed(MOUSE_LEFT_BUTTON):
          if CheckCollisionPointRec(mousePos, rowRect):
            let ctrlDown = IsKeyDown(KEY_LEFT_CONTROL) or IsKeyDown(KEY_RIGHT_CONTROL)
            let shiftDown = IsKeyDown(KEY_LEFT_SHIFT) or IsKeyDown(KEY_RIGHT_SHIFT)

            var newSelection = widget.selected

            if ctrlDown:
              # Toggle selection
              if rowIdx in newSelection:
                newSelection.excl(rowIdx)
              else:
                newSelection.incl(rowIdx)
            elif shiftDown:
              # Range selection (TODO: implement properly with last selected)
              newSelection.incl(rowIdx)
            else:
              # Single selection
              newSelection = [rowIdx].toHashSet

            widget.selected = newSelection

            if widget.onSelect.isSome:
              widget.onSelect.get()(newSelection)

        # Handle double click
        # (Simple detection - in real impl, track click timing)
        # if mouseInBounds and IsMouseButtonPressed(MOUSE_LEFT_BUTTON):
        #   if CheckCollisionPointRec(mousePos, rowRect):
        #     if widget.onDoubleClick.isSome:
        #       widget.onDoubleClick.get()(rowIdx)

      widget.hovered = newHovered

      EndScissorMode()

      # Draw scrollbar if needed
      if totalHeight > viewHeight:
        let scrollbarW = 12.0
        let scrollbarRect = Rectangle(
          x: widget.bounds.x + widget.bounds.width - scrollbarW,
          y: widget.bounds.y + headerH,
          width: scrollbarW,
          height: viewHeight
        )

        # Scrollbar track
        DrawRectangleRec(scrollbarRect, Color(r: 230, g: 230, b: 230, a: 255))

        # Scrollbar thumb
        let thumbHeight = max(20.0, viewHeight * (viewHeight / totalHeight))
        let thumbY = scrollbarRect.y + (scroll / maxScroll) * (viewHeight - thumbHeight)

        let thumbRect = Rectangle(
          x: scrollbarRect.x + 2.0,
          y: thumbY,
          width: scrollbarW - 4.0,
          height: thumbHeight
        )

        DrawRectangleRec(thumbRect, Color(r: 150, g: 150, b: 150, a: 255))

        # Handle scrollbar dragging
        if mouseInBounds and IsMouseButtonDown(MOUSE_LEFT_BUTTON):
          if CheckCollisionPointRec(mousePos, scrollbarRect):
            let newScroll = ((mousePos.y - scrollbarRect.y) / viewHeight) * maxScroll
            widget.scrollY = clamp(newScroll, 0.0, maxScroll)

      # Handle mouse wheel scrolling
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
      # Non-graphics mode - simple text output
      echo "DataGrid (Virtual + Lazy Loading):"
      let totalRows = if widget.totalRowCount >= 0: widget.totalRowCount else: widget.data.len
      echo "  Columns: ", widget.columns.len
      echo "  Total rows: ", totalRows
      echo "  Loaded rows: ", widget.data.len
      echo "  Visible rows: ", widget.visibleStart, " to ", widget.visibleEnd
      echo "  Selected rows: ", widget.selected.card
      echo "  Sort: column ", widget.sortColumn, ", order: ", widget.sortOrder

      # Print header
      var headerLine = "  "
      for col in widget.columns:
        headerLine.add(col.title.alignLeft(15) & " ")
      echo headerLine

      # Print visible rows only
      let visStart = widget.visibleStart
      let visEnd = min(widget.visibleEnd, totalRows - 1)

      for rowIdx in visStart..visEnd:
        let marker = if rowIdx in widget.selected: "[X]" else: "[ ]"
        var rowLine = "  " & marker & " "

        if rowIdx < widget.data.len:
          # Row is loaded
          let row = widget.data[rowIdx]
          for colIdx, col in widget.columns:
            if colIdx < row.values.len:
              let value = row.values[colIdx]
              let text = if value.kind == JString: value.getStr()
                        elif value.kind == JInt: $value.getInt()
                        elif value.kind == JFloat: value.getFloat().formatFloat(ffDecimal, 2)
                        else: $value
              rowLine.add(text.alignLeft(15) & " ")
        else:
          # Row not loaded yet
          rowLine.add("Loading...".alignLeft(15))

        echo rowLine
