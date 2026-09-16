## Row filters: what they are, what they match, and how they read.
##
## Split out of datatable_helpers.nim. Every predicate takes a value and a
## filter and returns a bool, so the whole filter language is decidable from a
## table of cases without a widget.
##
## A filter naming a column the row does not have refuses the row rather than
## passing it. That is the conservative reading: a filter the user typed should
## narrow the result, and silently ignoring it on rows with a missing column
## would show more than they asked for, not less.

import std/[json, strutils, tables]
import table_values

export table_values

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

proc isNoneFilter*(filter: Filter): bool =
  ## Check if filter is disabled
  filter.kind == fkNone

proc hasColumn*(row: TableRow, colId: string): bool =
  ## Check if row has value for column
  colId in row.values


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

