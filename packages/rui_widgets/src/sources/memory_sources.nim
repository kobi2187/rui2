## Sources that live in memory: a column-stored table, and an adapter over LinkSeq.

import std/[algorithm, strutils, parseutils]
import rui_core
import column_page, row_source

# ---------------------------------------------------------------------------
# MemorySource: a whole table in memory, stored by column

type
  MemorySource* = ref object of RowSource
    names: seq[string]
    page: ColumnPage                 ## every row, columns in arenas
    view: seq[int32]                 ## shown row -> stored row, when sorted or filtered
    viewed: bool
    sortColumn: string
    sortDir: SortDir
    filters: seq[ColumnFilter]

proc newMemorySource*(columns: seq[string], rows: seq[seq[string]] = @[]): MemorySource =
  result = MemorySource(names: columns, page: newColumnPage(0, columns.len))
  for r in rows: result.page.addRow r

proc stored(s: MemorySource): int = s.page.rowCount

proc isNumber(text: string): bool =
  var v: float
  text.len > 0 and parseFloat(text.strip, v) == text.strip.len

proc numeric(s: MemorySource, col: int): bool =
  ## A column sorts as numbers when every non-empty cell reads as one.
  for r in 0 ..< s.stored:
    let t = s.page.cell(r, col)
    if t.len > 0 and not t.isNumber: return false
  true

proc passes(s: MemorySource, row: int): bool =
  for f in s.filters:
    let c = s.columnIndex(f.column)
    if c < 0: return false
    let text = s.page.cell(row, c)
    case f.op
    of foContains:
      if f.text.toLowerAscii notin text.toLowerAscii: return false
    of foEquals:
      if text != f.text: return false
    of foGreater, foLess, foGreaterEq, foLessEq:
      var a, b: float
      if parseFloat(text.strip, a) == 0 or parseFloat(f.text.strip, b) == 0: return false
      let ok = case f.op
               of foGreater: a > b
               of foLess: a < b
               of foGreaterEq: a >= b
               else: a <= b
      if not ok: return false
  true

proc rebuildView(s: MemorySource) =
  s.viewed = s.filters.len > 0 or s.sortDir != sdNone
  s.view.setLen(0)
  if not s.viewed: return
  for r in 0 ..< s.stored:
    if s.passes(r): s.view.add int32(r)
  let col = s.columnIndex(s.sortColumn)
  if s.sortDir != sdNone and col >= 0:
    let numbers = s.numeric(col)
    let sign = if s.sortDir == sdAscending: 1 else: -1
    var keyed = s.view
    if numbers:
      var keys = newSeq[float](s.stored)
      for r in keyed:
        discard parseFloat(s.page.cell(int(r), col).strip, keys[r])
      keyed.sort(proc(a, b: int32): int = sign * cmp(keys[a], keys[b]))
    else:
      keyed.sort(proc(a, b: int32): int =
        sign * cmp(s.page.cell(int(a), col).toLowerAscii, s.page.cell(int(b), col).toLowerAscii))
    s.view = keyed

method count*(s: MemorySource): int = (if s.viewed: s.view.len else: s.stored)
method columns*(s: MemorySource): seq[string] = s.names
method cell*(s: MemorySource, row, col: int): string =
  if row < 0 or row >= s.count: return ""
  s.page.cell((if s.viewed: int(s.view[row]) else: row), col)
method canSort*(s: MemorySource): bool = true
method canFilter*(s: MemorySource): bool = true

method sortBy*(s: MemorySource, column: string, dir: SortDir) =
  s.sortColumn = column
  s.sortDir = dir
  s.rebuildView()
  s.notify SeqChange(kind: scReset)

method setFilters*(s: MemorySource, filters: seq[ColumnFilter]) =
  s.filters = filters
  s.rebuildView()
  s.notify SeqChange(kind: scReset)

proc append*(s: MemorySource, row: openArray[string]) =
  ## Add a row at the end. With a sort or filter active it is placed by them.
  s.page.addRow row
  if s.viewed:
    s.rebuildView()
    s.notify SeqChange(kind: scReset)
  else:
    s.notify SeqChange(kind: scInsert, index: s.stored - 1, count: 1)

# ---------------------------------------------------------------------------
# LinkSeqSource: a LinkSeq[string] as one-column rows, nothing copied

type LinkSeqSource* = ref object of RowSource
  source: LinkSeq[string]
  listenerId: ListenerId

proc newLinkSeqSource*(items: LinkSeq[string]): LinkSeqSource =
  result = LinkSeqSource(source: items)
  let me = result
  result.listenerId = items.listen(proc(change: SeqChange) = me.notify change)

method count*(s: LinkSeqSource): int = s.source.len
method cell*(s: LinkSeqSource, row, col: int): string =
  if col == 0 and row >= 0 and row < s.source.len: s.source[row] else: ""
method close*(s: LinkSeqSource) =
  s.source.unlisten s.listenerId
