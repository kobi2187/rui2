## DataTable Helpers - Forth Style
##
## Small, composable functions for data table operations
## Each function does ONE thing clearly

import std/[json, strutils, tables, sets]

type
  FilterKind* = enum
    fkNone, fkEquals, fkContains, fkStartsWith, fkEndsWith,
    fkGreater, fkLess, fkBetween, fkIn

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

  TableRow* = object
    id*: string
    values*: Table[string, JsonNode]

# ============================================================================
# Predicates - Filter State
# ============================================================================

proc isNoneFilter*(filter: Filter): bool =
  ## Check if filter is disabled
  filter.kind == fkNone

proc hasColumn*(row: TableRow, colId: string): bool =
  ## Check if row has value for column
  colId in row.values

# ============================================================================
# Queries - JSON Value Extraction
# ============================================================================

proc getStringValue*(value: JsonNode): string =
  ## Get string from JSON value
  if value.kind == JString:
    value.getStr()
  else:
    ""

proc getNumericValue*(value: JsonNode): float =
  ## Get numeric value from JSON
  if value.kind == JInt:
    value.getInt().float
  elif value.kind == JFloat:
    value.getFloat()
  else:
    0.0

proc isStringValue*(value: JsonNode): bool =
  ## Check if JSON value is string
  value.kind == JString

proc isNumericValue*(value: JsonNode): bool =
  ## Check if JSON value is numeric
  value.kind == JInt or value.kind == JFloat

# ============================================================================
# Filter Matching - String Filters
# ============================================================================

proc matchesEquals*(value: JsonNode, target: string): bool =
  ## Check if value equals target string
  isStringValue(value) and getStringValue(value) == target

proc matchesContains*(value: JsonNode, substring: string): bool =
  ## Check if value contains substring
  isStringValue(value) and substring in getStringValue(value)

proc matchesStartsWith*(value: JsonNode, prefix: string): bool =
  ## Check if value starts with prefix
  isStringValue(value) and getStringValue(value).startsWith(prefix)

proc matchesEndsWith*(value: JsonNode, suffix: string): bool =
  ## Check if value ends with suffix
  isStringValue(value) and getStringValue(value).endsWith(suffix)

proc matchesIn*(value: JsonNode, values: seq[string]): bool =
  ## Check if value is in list
  isStringValue(value) and getStringValue(value) in values

# ============================================================================
# Filter Matching - Numeric Filters
# ============================================================================

proc matchesGreater*(value: JsonNode, threshold: float): bool =
  ## Check if value is greater than threshold
  getNumericValue(value) > threshold

proc matchesLess*(value: JsonNode, threshold: float): bool =
  ## Check if value is less than threshold
  getNumericValue(value) < threshold

proc matchesBetween*(value: JsonNode, min, max: float): bool =
  ## Check if value is between min and max
  let num = getNumericValue(value)
  num >= min and num <= max

# ============================================================================
# Filter Matching - Main Logic
# ============================================================================

proc matchesFilter*(value: JsonNode, filter: Filter): bool =
  ## Check if value matches filter criteria
  case filter.kind
  of fkEquals:
    matchesEquals(value, filter.text)
  of fkContains:
    matchesContains(value, filter.text)
  of fkStartsWith:
    matchesStartsWith(value, filter.text)
  of fkEndsWith:
    matchesEndsWith(value, filter.text)
  of fkIn:
    matchesIn(value, filter.values)
  of fkGreater:
    matchesGreater(value, filter.value)
  of fkLess:
    matchesLess(value, filter.value)
  of fkBetween:
    matchesBetween(value, filter.min, filter.max)
  of fkNone:
    true

proc matchesColumnFilter*(row: TableRow, colId: string, filter: Filter): bool =
  ## Check if row value matches filter for column
  if isNoneFilter(filter):
    return true

  if not hasColumn(row, colId):
    return false

  let value = row.values[colId]
  matchesFilter(value, filter)

proc matchesAllFilters*(row: TableRow, filters: Table[string, Filter]): bool =
  ## Check if row matches all active filters
  for colId, filter in filters:
    if not matchesColumnFilter(row, colId, filter):
      return false
  true

# ============================================================================
# Filtering - Build Filtered Index
# ============================================================================

proc buildFilteredIndices*(data: seq[TableRow], filters: Table[string, Filter]): seq[int] =
  ## Build list of row indices that pass filters
  result = @[]
  for i, row in data:
    if matchesAllFilters(row, filters):
      result.add(i)

# ============================================================================
# Virtual Scrolling - Calculations
# ============================================================================

proc calcTotalHeight*(rowCount: int, rowHeight: float): float =
  ## Calculate total height of all rows
  rowCount.float * rowHeight

proc calcMaxScroll*(totalHeight, viewHeight: float): float =
  ## Calculate maximum scroll offset
  max(0.0, totalHeight - viewHeight)

proc calcVisibleStart*(scroll, rowHeight: float, bufferRows: int): int =
  ## Calculate first visible row index with buffer
  max(0, int(scroll / rowHeight) - bufferRows)

proc calcVisibleEnd*(scroll, viewHeight, rowHeight: float, totalRows, bufferRows: int): int =
  ## Calculate last visible row index with buffer
  min(totalRows - 1, int((scroll + viewHeight) / rowHeight) + bufferRows)

proc calcVisibleRange*(scroll, viewHeight, rowHeight: float,
                      totalRows, bufferRows: int): tuple[start, stop: int] =
  ## Calculate visible row range for virtual scrolling
  let start = calcVisibleStart(scroll, rowHeight, bufferRows)
  let stop = calcVisibleEnd(scroll, viewHeight, rowHeight, totalRows, bufferRows)
  (start, stop)

# ============================================================================
# Row Position Calculations
# ============================================================================

proc calcRowY*(visIdx: int, rowHeight, dataAreaY, scroll: float): float =
  ## Calculate Y position for row
  dataAreaY + (visIdx.float * rowHeight) - scroll

proc isRowVisible*(rowY, rowHeight, areaY, areaBottom: float): bool =
  ## Check if row is visible in viewport
  let rowBottom = rowY + rowHeight
  rowBottom >= areaY and rowY <= areaBottom

# ============================================================================
# Cell Value Formatting
# ============================================================================

proc formatCellValue*(value: JsonNode, formatFunc: proc(v: JsonNode): string = nil): string =
  ## Format JSON value for display
  if formatFunc != nil:
    return formatFunc(value)

  case value.kind
  of JString:
    value.getStr()
  of JInt:
    $value.getInt()
  of JFloat:
    value.getFloat().formatFloat(ffDecimal, 2)
  of JBool:
    $value.getBool()
  else:
    $value

proc getCellText*(row: TableRow, colId: string, formatFunc: proc(v: JsonNode): string = nil): string =
  ## Get formatted text for cell
  if not hasColumn(row, colId):
    return ""

  formatCellValue(row.values[colId], formatFunc)

# ============================================================================
# Sorting - Comparison
# ============================================================================

proc compareStrings*(a, b: string, ascending: bool): int =
  ## Compare two strings with sort order
  let cmp = cmp(a, b)
  if ascending: cmp else: -cmp

proc compareNumbers*(a, b: float, ascending: bool): int =
  ## Compare two numbers with sort order
  let cmp = cmp(a, b)
  if ascending: cmp else: -cmp

proc compareValues*(a, b: JsonNode, ascending: bool): int =
  ## Compare two JSON values with sort order
  if isStringValue(a) and isStringValue(b):
    compareStrings(getStringValue(a), getStringValue(b), ascending)
  elif isNumericValue(a) and isNumericValue(b):
    compareNumbers(getNumericValue(a), getNumericValue(b), ascending)
  else:
    0

proc compareRows*(a, b: TableRow, colId: string, ascending: bool): int =
  ## Compare two rows by column value
  if not hasColumn(a, colId) or not hasColumn(b, colId):
    return 0

  compareValues(a.values[colId], b.values[colId], ascending)

# ============================================================================
# Filter Labels
# ============================================================================

proc getFilterKindLabel*(kind: FilterKind): string =
  ## Get short label for filter kind
  case kind
  of fkNone: "All"
  of fkEquals: "="
  of fkContains: "~"
  of fkStartsWith: "^"
  of fkEndsWith: "$"
  of fkGreater: ">"
  of fkLess: "<"
  of fkBetween: "[]"
  of fkIn: "in"

proc getFilterValueText*(filter: Filter): string =
  ## Get display text for filter value
  case filter.kind
  of fkEquals, fkContains, fkStartsWith, fkEndsWith:
    filter.text
  of fkGreater, fkLess:
    $filter.value
  of fkBetween:
    $filter.min & "-" & $filter.max
  of fkIn:
    filter.values.join(",")
  of fkNone:
    ""

# ============================================================================
# Selection Management
# ============================================================================

proc toggleSelection*(selected: var HashSet[int], idx: int) =
  ## Toggle selection state for row
  if idx in selected:
    selected.excl(idx)
  else:
    selected.incl(idx)

proc setSingleSelection*(selected: var HashSet[int], idx: int) =
  ## Set selection to single row
  selected = [idx].toHashSet

proc updateSelection*(selected: var HashSet[int], idx: int, ctrlDown: bool) =
  ## Update selection based on ctrl key state
  if ctrlDown:
    toggleSelection(selected, idx)
  else:
    setSingleSelection(selected, idx)

# ============================================================================
# Scrollbar Calculations
# ============================================================================

proc calcScrollbarThumbHeight*(viewHeight, totalHeight: float, minHeight = 20.0): float =
  ## Calculate scrollbar thumb height
  max(minHeight, viewHeight * (viewHeight / totalHeight))

proc calcScrollbarThumbY*(scroll, maxScroll, viewHeight, thumbHeight, barY: float): float =
  ## Calculate scrollbar thumb Y position
  barY + (scroll / maxScroll) * (viewHeight - thumbHeight)

proc calcScrollFromMouseY*(mouseY, barY, barHeight, maxScroll: float): float =
  ## Calculate scroll position from mouse Y
  let ratio = (mouseY - barY) / barHeight
  clamp(ratio * maxScroll, 0.0, maxScroll)
