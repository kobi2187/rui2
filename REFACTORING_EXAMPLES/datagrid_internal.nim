## DataGrid Internal Implementation
##
## This file contains ALL implementation details:
## - Virtual scrolling calculations
## - Mouse interaction handling
## - Rendering logic
## - Helper functions
##
## Separated from datagrid.nim for:
## - Better testability
## - Cleaner code organization
## - Easier maintenance

import ../../core/widget_dsl_v2
import std/[options, sets, json, algorithm, strutils, math]

when defined(useGraphics):
  import raylib

# =============================================================================
# VIRTUAL SCROLLING CALCULATIONS
# =============================================================================

proc calculateVisibleRange*(widget: DataGridWidget): tuple[start, end: int] =
  ## Calculate which rows are visible in viewport (virtual scrolling)
  ## Returns indices with buffer for smooth scrolling
  let totalRows = widget.data.len
  if totalRows == 0:
    return (0, 0)

  let scroll = widget.scrollY.get()
  let rowH = widget.rowHeight
  let headerH = if widget.showHeader: widget.headerHeight else: 0.0
  let viewHeight = widget.bounds.height - headerH

  # Buffer: render extra rows above/below viewport
  let bufferRows = 10

  let visStart = max(0, int(scroll / rowH) - bufferRows)
  let visEnd = min(totalRows - 1, int((scroll + viewHeight) / rowH) + bufferRows)

  result = (visStart, visEnd)

proc calculateMaxScroll*(widget: DataGridWidget): float =
  ## Calculate maximum scroll offset
  let totalRows = widget.data.len
  let headerH = if widget.showHeader: widget.headerHeight else: 0.0
  let totalHeight = totalRows.float * widget.rowHeight
  let viewHeight = widget.bounds.height - headerH

  result = max(0.0, totalHeight - viewHeight)

# =============================================================================
# MOUSE INTERACTION HANDLING
# =============================================================================

proc handleDataGridMouseDown*(widget: DataGridWidget) =
  ## Handle mouse down events (header click for sort, row click for select)
  when defined(useGraphics):
    let mousePos = GetMousePosition()
    if not CheckCollisionPointRec(mousePos, widget.bounds):
      return

    let headerH = if widget.showHeader: widget.headerHeight else: 0.0
    let headerAreaEnd = widget.bounds.y + headerH

    # Check if click is in header area
    if widget.showHeader and mousePos.y < headerAreaEnd:
      handleHeaderClick(widget, mousePos)
    else:
      handleRowClick(widget, mousePos)

proc handleHeaderClick(widget: DataGridWidget, mousePos: Vector2) =
  ## Handle click on column header (for sorting)
  var x = widget.bounds.x

  for colIdx, col in widget.columns:
    let headerRect = Rectangle(
      x: x,
      y: widget.bounds.y,
      width: col.width,
      height: widget.headerHeight
    )

    if CheckCollisionPointRec(mousePos, headerRect) and col.sortable:
      # Toggle sort order if same column, otherwise start ascending
      if colIdx == widget.sortColumn.get():
        let currentOrder = widget.sortOrder.get()
        let newOrder = case currentOrder
                       of soNone: soAscending
                       of soAscending: soDescending
                       of soDescending: soNone
        widget.sortOrder.set(newOrder)
      else:
        widget.sortColumn.set(colIdx)
        widget.sortOrder.set(soAscending)

      if widget.onSort.isSome:
        widget.onSort.get()(widget.sortColumn.get(), widget.sortOrder.get())

      break

    x += col.width

proc handleRowClick(widget: DataGridWidget, mousePos: Vector2) =
  ## Handle click on data row (for selection)
  let scroll = widget.scrollY.get()
  let rowH = widget.rowHeight
  let headerH = if widget.showHeader: widget.headerHeight else: 0.0
  let dataAreaY = widget.bounds.y + headerH

  # Calculate which row was clicked
  let relY = mousePos.y - dataAreaY + scroll
  let rowIdx = int(relY / rowH)

  if rowIdx >= 0 and rowIdx < widget.data.len:
    # Check if ctrl or shift is pressed for multi-select
    let ctrlDown = IsKeyDown(KEY_LEFT_CONTROL) or IsKeyDown(KEY_RIGHT_CONTROL)
    let shiftDown = IsKeyDown(KEY_LEFT_SHIFT) or IsKeyDown(KEY_RIGHT_SHIFT)

    var newSelection = widget.selected.get()

    if ctrlDown:
      # Toggle selection
      if rowIdx in newSelection:
        newSelection.excl(rowIdx)
      else:
        newSelection.incl(rowIdx)
    elif shiftDown:
      # Range selection (simplified - would need last selected index)
      newSelection.incl(rowIdx)
    else:
      # Single selection
      newSelection = [rowIdx].toHashSet

    widget.selected.set(newSelection)

    if widget.onSelect.isSome:
      widget.onSelect.get()(newSelection)

proc handleDataGridMouseWheel*(widget: DataGridWidget) =
  ## Handle mouse wheel scrolling
  when defined(useGraphics):
    let mousePos = GetMousePosition()
    if not CheckCollisionPointRec(mousePos, widget.bounds):
      return

    let wheel = GetMouseWheelMove()
    if wheel != 0.0:
      let maxScroll = calculateMaxScroll(widget)
      let newScroll = widget.scrollY.get() - (wheel * widget.rowHeight * 3.0)
      widget.scrollY.set(clamp(newScroll, 0.0, maxScroll))

# =============================================================================
# RENDERING FUNCTIONS
# =============================================================================

proc renderDataGrid*(widget: DataGridWidget) =
  ## Main rendering entry point
  when defined(useGraphics):
    drawBackground(widget)
    drawHeader(widget)
    drawRows(widget)
    drawScrollbar(widget)
    drawBorder(widget)
  else:
    printDebug(widget)

proc drawBackground(widget: DataGridWidget) =
  ## Draw white background
  DrawRectangleRec(widget.bounds, Color(r: 255, g: 255, b: 255, a: 255))

proc drawHeader(widget: DataGridWidget) =
  ## Draw column headers with sort indicators
  if not widget.showHeader:
    return

  var x = widget.bounds.x
  let headerY = widget.bounds.y

  for colIdx, col in widget.columns:
    let headerRect = Rectangle(
      x: x,
      y: headerY,
      width: col.width,
      height: widget.headerHeight
    )

    # Background (highlight on hover)
    let mousePos = GetMousePosition()
    let isHovered = CheckCollisionPointRec(mousePos, headerRect)
    let bgColor = if isHovered:
                   Color(r: 230, g: 240, b: 250, a: 255)
                 else:
                   Color(r: 240, g: 240, b: 240, a: 255)

    DrawRectangleRec(headerRect, bgColor)

    # Sort indicator
    let sortIndicator = if colIdx == widget.sortColumn.get():
                         case widget.sortOrder.get()
                         of soAscending: " ▲"
                         of soDescending: " ▼"
                         of soNone: ""
                       else: ""

    # Text
    let headerText = col.title & sortIndicator
    DrawText(
      headerText.cstring,
      (x + 4.0).cint,
      (headerY + 6.0).cint,
      12,
      Color(r: 40, g: 40, b: 40, a: 255)
    )

    # Border
    if widget.showGrid:
      DrawRectangleLinesEx(headerRect, 1.0, widget.gridColor)

    x += col.width

proc drawRows(widget: DataGridWidget) =
  ## Draw data rows (only visible rows - virtual scrolling)
  let (visStart, visEnd) = calculateVisibleRange(widget)
  widget.visibleStart.set(visStart)
  widget.visibleEnd.set(visEnd)

  let headerH = if widget.showHeader: widget.headerHeight else: 0.0
  let dataAreaY = widget.bounds.y + headerH
  let scroll = widget.scrollY.get()
  let rowH = widget.rowHeight

  # Enable scissor mode for clipping
  BeginScissorMode(
    widget.bounds.x.cint,
    widget.bounds.y.cint,
    widget.bounds.width.cint,
    widget.bounds.height.cint
  )

  let mousePos = GetMousePosition()
  let mouseInBounds = CheckCollisionPointRec(mousePos, widget.bounds)
  var newHovered = -1

  # Draw only visible rows
  for rowIdx in visStart..visEnd:
    if rowIdx >= widget.data.len:
      break

    let row = widget.data[rowIdx]
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

    # Row background
    let isSelected = rowIdx in widget.selected.get()
    let isHovered = rowIdx == widget.hovered.get()
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
      if colIdx >= row.values.len:
        x += col.width
        continue

      let cellRect = Rectangle(
        x: x,
        y: rowY,
        width: col.width,
        height: rowH
      )

      # Format value
      let value = row.values[colIdx]
      let text = formatCellValue(value, col.formatFunc)

      # Draw text
      DrawText(
        text.cstring,
        (x + 4.0).cint,
        (rowY + 4.0).cint,
        12,
        Color(r: 40, g: 40, b: 40, a: 255)
      )

      # Cell border
      if widget.showGrid:
        DrawRectangleLinesEx(cellRect, 1.0, widget.gridColor)

      x += col.width

  widget.hovered.set(newHovered)

  EndScissorMode()

proc drawScrollbar(widget: DataGridWidget) =
  ## Draw vertical scrollbar if needed
  let maxScroll = calculateMaxScroll(widget)
  if maxScroll <= 0.0:
    return

  let headerH = if widget.showHeader: widget.headerHeight else: 0.0
  let viewHeight = widget.bounds.height - headerH
  let scrollbarW = 12.0

  let scrollbarRect = Rectangle(
    x: widget.bounds.x + widget.bounds.width - scrollbarW,
    y: widget.bounds.y + headerH,
    width: scrollbarW,
    height: viewHeight
  )

  # Track
  DrawRectangleRec(scrollbarRect, Color(r: 230, g: 230, b: 230, a: 255))

  # Thumb
  let scroll = widget.scrollY.get()
  let thumbHeight = max(20.0, viewHeight * (viewHeight / (viewHeight + maxScroll)))
  let thumbY = scrollbarRect.y + (scroll / maxScroll) * (viewHeight - thumbHeight)

  let thumbRect = Rectangle(
    x: scrollbarRect.x + 2.0,
    y: thumbY,
    width: scrollbarW - 4.0,
    height: thumbHeight
  )

  DrawRectangleRec(thumbRect, Color(r: 150, g: 150, b: 150, a: 255))

  # Handle drag
  let mousePos = GetMousePosition()
  if IsMouseButtonDown(MOUSE_LEFT_BUTTON):
    if CheckCollisionPointRec(mousePos, scrollbarRect):
      let newScroll = ((mousePos.y - scrollbarRect.y) / viewHeight) * maxScroll
      widget.scrollY.set(clamp(newScroll, 0.0, maxScroll))

proc drawBorder(widget: DataGridWidget) =
  ## Draw outer border
  DrawRectangleLinesEx(
    widget.bounds,
    1.0,
    Color(r: 180, g: 180, b: 180, a: 255)
  )

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

proc formatCellValue(value: JsonNode, formatFunc: Option[proc(value: JsonNode): string]): string =
  ## Format cell value for display
  if formatFunc.isSome:
    return formatFunc.get()(value)

  case value.kind
  of JString:
    return value.getStr()
  of JInt:
    return $value.getInt()
  of JFloat:
    return value.getFloat().formatFloat(ffDecimal, 2)
  of JBool:
    return $value.getBool()
  else:
    return $value

proc printDebug(widget: DataGridWidget) =
  ## Non-graphics mode debug output
  echo "DataGrid:"
  echo "  Columns: ", widget.columns.len
  echo "  Total rows: ", widget.data.len
  echo "  Visible rows: ", widget.visibleStart.get(), " to ", widget.visibleEnd.get()
  echo "  Selected rows: ", widget.selected.get().card
  echo "  Sort: column ", widget.sortColumn.get(), ", order: ", widget.sortOrder.get()

  if widget.data.len > 0:
    echo "  First 5 rows:"
    for i in 0..<min(5, widget.data.len):
      let row = widget.data[i]
      let marker = if i in widget.selected.get(): "[X]" else: "[ ]"
      var rowLine = "    " & marker & " "

      for colIdx, col in widget.columns:
        if colIdx < row.values.len:
          let val = row.values[colIdx]
          let text = formatCellValue(val, col.formatFunc)
          rowLine.add(text.alignLeft(15) & " ")

      echo rowLine

# =============================================================================
# TESTING EXPORTS
# =============================================================================

# Export internal functions for unit testing
export calculateVisibleRange
export calculateMaxScroll
export formatCellValue
