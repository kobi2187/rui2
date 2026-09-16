## Reading a cell out of a row.
##
## Split out of datatable_helpers.nim, which had grown into a grab-bag:
## filtering, sorting, cell formatting, and two superseded copies of the
## scrolling arithmetic in one 329-line module.
##
## A TableRow's values are JsonNode, so every other module here needs the same
## question answered first -- is this thing text or a number, and what does it
## say? The accessors are deliberately lenient: getStringValue renders a number
## as text rather than failing, because a filter typed into a search box has no
## idea what type the column holds.

import std/[json, strutils, tables]

type
  TableRow* = object
    id*: string
    values*: Table[string, JsonNode]

proc hasColumn*(row: TableRow, colId: string): bool =
  colId in row.values


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

