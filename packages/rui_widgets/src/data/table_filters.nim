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

proc hasColumn*(row: DataRow, colId: string): bool =
  ## Check if row has value for column
  colId in row.values


# The text filters work on a value as it reads -- a number by its digits --
# because a filter typed into a search box has no idea what the column holds.
# Containing is case-blind (what typing "ann" to find "Ann" means); the rest
# are exact.

proc matchesEquals*(value: JsonNode, target: string): bool =
  ## Check if value equals target string
  getStringValue(value) == target

proc matchesContains*(value: JsonNode, substring: string): bool =
  ## Check if value contains substring, ignoring case
  substring.toLowerAscii in getStringValue(value).toLowerAscii

proc matchesStartsWith*(value: JsonNode, prefix: string): bool =
  ## Check if value starts with prefix
  getStringValue(value).startsWith(prefix)

proc matchesEndsWith*(value: JsonNode, suffix: string): bool =
  ## Check if value ends with suffix
  getStringValue(value).endsWith(suffix)

proc matchesIn*(value: JsonNode, values: seq[string]): bool =
  ## Check if value is in list
  getStringValue(value) in values

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

proc matchesColumnFilter*(row: DataRow, colId: string, filter: Filter): bool =
  ## Check if row value matches filter for column
  if isNoneFilter(filter):
    return true

  if not hasColumn(row, colId):
    return false

  let value = row.values[colId]
  matchesFilter(value, filter)

proc matchesAllFilters*(row: DataRow, filters: Table[string, Filter]): bool =
  ## Check if row matches all active filters
  for colId, filter in filters:
    if not matchesColumnFilter(row, colId, filter):
      return false
  true

# ============================================================================
# Filtering - Build Filtered Index
# ============================================================================

proc buildFilteredIndices*(data: seq[DataRow], filters: Table[string, Filter]): seq[int] =
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

# ============================================================================
# Typing a filter
#
# One short line per column, the way a search box wants it:
#
#   (nothing)   no filter          5..10   between 5 and 10, ends included
#   ann         contains "ann"     a|b|c   one of "a", "b", "c"
#   =ann        is exactly "ann"   >5      greater than 5
#   ^ann        starts with "ann"  <5      less than 5
#   $ann        ends with "ann"
#
# `filterText` writes a filter the same way, so a filter set from code reads
# back in the box, and what is typed round-trips.
# ============================================================================

proc parseFilter*(column, text: string): tuple[filter: Filter, valid: bool] =
  ## The filter a typed line means. `valid` is false for a number the line
  ## promises but does not have (`>abc`, `3..`); the caller keeps the filter
  ## it had rather than applying half a thought.
  let t = text.strip()
  let none = Filter(column: column, kind: fkNone)
  if t.len == 0:
    return (none, true)
  template number(src: string, v: var float): bool =
    try:
      v = parseFloat(src.strip())
      true
    except ValueError:
      false
  case t[0]
  of '=': return (Filter(column: column, kind: fkEquals, text: t[1 .. ^1]), true)
  of '^': return (Filter(column: column, kind: fkStartsWith, text: t[1 .. ^1]), true)
  of '$': return (Filter(column: column, kind: fkEndsWith, text: t[1 .. ^1]), true)
  of '>', '<':
    var v: float
    if not number(t[1 .. ^1], v):
      return (none, false)
    let f = if t[0] == '>': Filter(column: column, kind: fkGreater, value: v)
            else: Filter(column: column, kind: fkLess, value: v)
    return (f, true)
  else:
    discard
  let dots = t.find("..")
  if dots > 0:
    var lo, hi: float
    if not (number(t[0 ..< dots], lo) and number(t[dots + 2 .. ^1], hi)):
      return (none, false)
    return (Filter(column: column, kind: fkBetween, min: min(lo, hi), max: max(lo, hi)), true)
  if '|' in t:
    var values: seq[string]
    for part in t.split('|'):
      values.add part.strip()
    return (Filter(column: column, kind: fkIn, values: values), true)
  (Filter(column: column, kind: fkContains, text: t), true)

proc filterText*(filter: Filter): string =
  ## The line that means `filter` (see `parseFilter`).
  proc num(v: float): string =
    if v == float(int(v)): $int(v) else: $v
  case filter.kind
  of fkNone: ""
  of fkEquals: "=" & filter.text
  of fkContains: filter.text
  of fkStartsWith: "^" & filter.text
  of fkEndsWith: "$" & filter.text
  of fkGreater: ">" & num(filter.value)
  of fkLess: "<" & num(filter.value)
  of fkBetween: num(filter.min) & ".." & num(filter.max)
  of fkIn: filter.values.join("|")
