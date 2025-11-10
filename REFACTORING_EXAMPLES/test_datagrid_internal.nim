## Unit Tests for DataGrid Internal Functions
##
## Shows how separating internal implementation enables unit testing
## of complex logic without needing full widget rendering

import datagrid_internal
import datagrid_refactored
import unittest
import std/[json, options, sets]

suite "DataGrid Internal - Virtual Scrolling":
  test "calculateVisibleRange with no scroll":
    var widget = newDataGrid(
      columns: @[],
      data: @[]
    )

    # Setup: 100 rows, 24px each, viewport height 240px
    for i in 0..<100:
      widget.data.add(Row(id: $i, values: @[]))

    widget.bounds = Rectangle(x: 0.0, y: 0.0, width: 400.0, height: 240.0)
    widget.rowHeight = 24.0
    widget.headerHeight = 28.0
    widget.scrollY.set(0.0)

    let (start, endIdx) = calculateVisibleRange(widget)

    # Should show first ~10 visible rows + buffer
    check start == 0
    check endIdx >= 10
    check endIdx <= 30  # With buffer

  test "calculateVisibleRange with scroll":
    var widget = newDataGrid(
      columns: @[],
      data: @[]
    )

    for i in 0..<100:
      widget.data.add(Row(id: $i, values: @[]))

    widget.bounds = Rectangle(x: 0.0, y: 0.0, width: 400.0, height: 240.0)
    widget.rowHeight = 24.0
    widget.scrollY.set(240.0)  # Scrolled down 10 rows

    let (start, endIdx) = calculateVisibleRange(widget)

    # Should show rows starting around index 10
    check start >= 0   # Buffer included
    check start <= 10
    check endIdx >= 20
    check endIdx <= 40

  test "calculateVisibleRange with empty data":
    var widget = newDataGrid(
      columns: @[],
      data: @[]
    )

    widget.bounds = Rectangle(x: 0.0, y: 0.0, width: 400.0, height: 240.0)

    let (start, endIdx) = calculateVisibleRange(widget)

    check start == 0
    check endIdx == 0

  test "calculateMaxScroll returns correct value":
    var widget = newDataGrid(
      columns: @[],
      data: @[]
    )

    # 100 rows * 24px = 2400px total
    # Viewport = 240px - 28px header = 212px
    # Max scroll = 2400 - 212 = 2188px
    for i in 0..<100:
      widget.data.add(Row(id: $i, values: @[]))

    widget.bounds = Rectangle(x: 0.0, y: 0.0, width: 400.0, height: 240.0)
    widget.rowHeight = 24.0
    widget.headerHeight = 28.0
    widget.showHeader = true

    let maxScroll = calculateMaxScroll(widget)

    check maxScroll == (100.0 * 24.0) - (240.0 - 28.0)
    check maxScroll == 2188.0

suite "DataGrid Internal - Cell Formatting":
  test "formatCellValue for string":
    let value = %"Hello"
    let text = formatCellValue(value, none(proc(v: JsonNode): string))
    check text == "Hello"

  test "formatCellValue for integer":
    let value = %42
    let text = formatCellValue(value, none(proc(v: JsonNode): string))
    check text == "42"

  test "formatCellValue for float":
    let value = %3.14159
    let text = formatCellValue(value, none(proc(v: JsonNode): string))
    check text == "3.14"  # Formatted to 2 decimal places

  test "formatCellValue for boolean":
    let valueTrue = %true
    let valueFalse = %false

    let textTrue = formatCellValue(valueTrue, none(proc(v: JsonNode): string))
    let textFalse = formatCellValue(valueFalse, none(proc(v: JsonNode): string))

    check textTrue == "true"
    check textFalse == "false"

  test "formatCellValue with custom formatter":
    let value = %99.99

    let formatter = some(proc(v: JsonNode): string =
      "$" & v.getFloat().formatFloat(ffDecimal, 2)
    )

    let text = formatCellValue(value, formatter)
    check text == "$99.99"

suite "DataGrid Internal - Selection Logic":
  # These tests would require mocking the widget and simulating clicks
  # Shown here as placeholders for the pattern

  test "handleRowClick with single click":
    # Would test that single click replaces selection
    skip()

  test "handleRowClick with Ctrl+click":
    # Would test that Ctrl+click toggles selection
    skip()

  test "handleHeaderClick sorts ascending first time":
    # Would test that clicking unsorted column starts ascending
    skip()

  test "handleHeaderClick toggles sort order":
    # Would test that clicking sorted column toggles order
    skip()

## Benefits of this testing approach:
##
## 1. Fast: No graphics rendering required
## 2. Focused: Test one function at a time
## 3. Comprehensive: Can test edge cases easily
## 4. Reliable: No UI interaction flakiness
## 5. Debuggable: Easy to step through with debugger
##
## Without the internal separation, we'd have to:
## - Render the full widget
## - Simulate mouse events
## - Inspect visual output
## - Much slower and more fragile
