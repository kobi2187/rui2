## Ordering rows by a column value.
##
## Split out of datatable_helpers.nim.
##
## The comparison is deliberately total and deliberately quiet: two values of
## different shapes compare equal rather than raising. A JSON column is not
## guaranteed to be homogeneous, and a table that throws while sorting is worse
## than one that leaves two odd rows where they were.

import std/[json, tables]
import table_values

export table_values

type
  SortOrder* = enum
    ## Shared by DataTable and DataGrid. It lived in both widgets before, so
    ## exporting the two from one module made `soNone` and friends ambiguous.
    soNone
    soAscending
    soDescending

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

