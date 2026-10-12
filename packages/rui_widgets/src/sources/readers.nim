## Readers: the file and database access behind the background sources.
##
## Plain synchronous code that knows how to open a thing, count its rows
## (incrementally, so the UI can show a growing count while a big file is
## still being scanned) and read one page of rows. No threads here: the same
## object runs inline (tests, small data) or inside a worker (paged_source).
##
## Files are memory-mapped (`std/memfiles`): nothing is read until a page asks,
## and the OS keeps the hot parts in its own cache. A sparse index -- the byte
## offset of every 128th row -- is all that is remembered, so a hundred million
## lines cost under a megabyte; a page read seeks to the nearest entry and walks
## forward at most 127 rows.

import std/[memfiles, parsecsv, streams, strutils, os, options]
import db_connector/db_sqlite
import column_page, row_source

type
  SourceKind* = enum skLines, skDelimited, skSqlite

  ReaderSpec* = object
    kind*: SourceKind
    path*: string
    delimiter*: char          ## skDelimited: ',' for CSV, '\t' for TSV
    header*: bool             ## skDelimited: the first record names the columns
    query*: string            ## skSqlite: a table name, or a SELECT
    sortColumn*: string
    sortDir*: SortDir
    filters*: seq[ColumnFilter]

  Reader* = ref object of RootObj

const IndexStride* = 128      ## rows between index entries

proc memchr(s: pointer, c: cint, n: csize_t): pointer {.importc, header: "<string.h>".}

method open*(r: Reader): seq[string] {.base, gcsafe.} = @[]
  ## Open the file or database; return the column names.

method countStep*(r: Reader, budget: int): tuple[count: int, done: bool] {.base, gcsafe.} =
  ## Continue counting, scanning at most `budget` bytes (files) or all at once
  ## (a database). Returns the rows known so far.
  (0, true)

method readPage*(r: Reader, pageNo, pageSize: int): ColumnPage {.base, gcsafe.} =
  newColumnPage(pageNo * pageSize, 1)

method configure*(r: Reader, spec: ReaderSpec): int {.base, gcsafe.} =
  ## Apply a new sort/filter; returns the new row count. (Files cannot.)
  0

method close*(r: Reader) {.base, gcsafe.} = discard

# ---------------------------------------------------------------------------
# Lines

type LinesReader* = ref object of Reader
  path: string
  file: MemFile
  isOpen: bool
  index: seq[int64]          ## byte offset of row k*IndexStride
  scanPos: int64
  rowStart: int64
  rows: int
  done: bool

proc newLinesReader*(path: string): LinesReader = LinesReader(path: path)

method open*(r: LinesReader): seq[string] {.gcsafe.} =
  if getFileSize(r.path) == 0:
    r.done = true
  else:
    r.file = memfiles.open(r.path, mode = fmRead)
    r.isOpen = true
  @["line"]

method countStep*(r: LinesReader, budget: int): tuple[count: int, done: bool] {.gcsafe.} =
  if r.done or not r.isOpen: return (r.rows, true)
  let size = int64(r.file.size)
  let base = cast[ptr UncheckedArray[char]](r.file.mem)
  let limit = min(size, r.scanPos + int64(budget))
  while r.scanPos < limit:
    let left = size - r.scanPos
    let at = memchr(addr base[r.scanPos], cint('\n'), csize_t(min(left, limit - r.scanPos)))
    if at == nil:
      r.scanPos = limit
      break
    let nl = cast[int64](at) - cast[int64](base)
    if r.rows mod IndexStride == 0: r.index.add r.rowStart
    inc r.rows
    r.scanPos = nl + 1
    r.rowStart = r.scanPos
  if r.scanPos >= size:
    r.done = true
    if r.rowStart < size:            # a last line with no newline after it
      if r.rows mod IndexStride == 0: r.index.add r.rowStart
      inc r.rows
  (r.rows, r.done)

method readPage*(r: LinesReader, pageNo, pageSize: int): ColumnPage {.gcsafe.} =
  result = newColumnPage(pageNo * pageSize, 1)
  let firstRow = pageNo * pageSize
  if not r.isOpen or firstRow >= r.rows: return
  let size = int64(r.file.size)
  let base = cast[ptr UncheckedArray[char]](r.file.mem)
  var row = firstRow - firstRow mod IndexStride
  var pos = r.index[row div IndexStride]
  let stop = min(firstRow + pageSize, r.rows)
  while row < stop and pos <= size:
    var lineEnd = size
    let at = if pos < size: memchr(addr base[pos], cint('\n'), csize_t(size - pos)) else: nil
    if at != nil: lineEnd = cast[int64](at) - cast[int64](base)
    if row >= firstRow:
      var len = int(lineEnd - pos)
      if len > 0 and base[pos + len - 1] == '\r': dec len
      var line = newString(len)
      if len > 0: copyMem(addr line[0], addr base[pos], len)
      result.addRow [line]
    pos = lineEnd + 1
    inc row

method close*(r: LinesReader) {.gcsafe.} =
  if r.isOpen:
    r.file.close()
    r.isOpen = false

# ---------------------------------------------------------------------------
# Delimited text: CSV and TSV

type DelimitedReader* = ref object of Reader
  path: string
  delimiter: char
  header: bool
  file: MemFile
  isOpen: bool
  names: seq[string]
  index: seq[int64]          ## byte offset of data record k*IndexStride
  ends: seq[int64]           ## end offset of every IndexStride-th record's block (for page cuts)
  scanPos: int64
  recStart: int64
  inQuote: bool
  records: int               ## data records found (the header is not one)
  sawHeader: bool
  done: bool

proc newDelimitedReader*(path: string, delimiter = ',', header = true): DelimitedReader =
  DelimitedReader(path: path, delimiter: delimiter, header: header)

proc parseRecord(text: string, delimiter: char): seq[string] =
  var p: CsvParser
  p.open(newStringStream(text), "record", separator = delimiter, quote = '"')
  defer: p.close()
  if p.readRow(): result = p.row

method open*(r: DelimitedReader): seq[string] {.gcsafe.} =
  if getFileSize(r.path) == 0:
    r.done = true
    return @[]
  r.file = memfiles.open(r.path, mode = fmRead)
  r.isOpen = true
  r.names = @[]
  # The first record: the header, or just how many columns there are.
  let base = cast[ptr UncheckedArray[char]](r.file.mem)
  var q = false
  var e = 0
  while e < r.file.size:
    let c = base[e]
    if c == '"': q = not q
    elif c == '\n' and not q: break
    inc e
  var first = newString(e)
  if e > 0: copyMem(addr first[0], addr base[0], e)
  first = first.strip(leading = false, chars = {'\r'})
  let fields = parseRecord(first, r.delimiter)
  if r.header:
    r.names = fields
    r.recStart = int64(min(e + 1, r.file.size))
    r.scanPos = r.recStart
    r.sawHeader = true
  else:
    for i in 1 .. max(1, fields.len): r.names.add $i
  r.names

method countStep*(r: DelimitedReader, budget: int): tuple[count: int, done: bool] {.gcsafe.} =
  if r.done or not r.isOpen: return (r.records, true)
  let size = int64(r.file.size)
  let base = cast[ptr UncheckedArray[char]](r.file.mem)
  let limit = min(size, r.scanPos + int64(budget))
  while r.scanPos < limit:
    let c = base[r.scanPos]
    if c == '"': r.inQuote = not r.inQuote
    elif c == '\n' and not r.inQuote:
      if r.records mod IndexStride == 0: r.index.add r.recStart
      inc r.records
      r.recStart = r.scanPos + 1
    inc r.scanPos
  if r.scanPos >= size:
    r.done = true
    if r.recStart < size:
      if r.records mod IndexStride == 0: r.index.add r.recStart
      inc r.records
  (r.records, r.done)

method readPage*(r: DelimitedReader, pageNo, pageSize: int): ColumnPage {.gcsafe.} =
  result = newColumnPage(pageNo * pageSize, r.names.len)
  let firstRow = pageNo * pageSize
  if not r.isOpen or firstRow >= r.records: return
  let size = int64(r.file.size)
  let base = cast[ptr UncheckedArray[char]](r.file.mem)
  var row = firstRow - firstRow mod IndexStride
  var pos = r.index[row div IndexStride]
  let stop = min(firstRow + pageSize, r.records)
  var blockStart = pos
  var blockEnd = pos
  var q = false
  var recStart = pos
  while row < stop and pos < size:
    let c = base[pos]
    if c == '"': q = not q
    if (c == '\n' and not q) or pos == size - 1:
      var recEnd = pos
      if c == '\n': recEnd = pos            # the newline itself is excluded below
      if row >= firstRow:
        if row == firstRow: blockStart = recStart
        blockEnd = if c == '\n': pos else: pos + 1
      inc row
      recStart = pos + 1
    inc pos
  if blockEnd > blockStart:
    var text = newString(int(blockEnd - blockStart))
    copyMem(addr text[0], addr base[blockStart], text.len)
    var p: CsvParser
    p.open(newStringStream(text), "page", separator = r.delimiter, quote = '"')
    while p.readRow():
      result.addRow p.row
    p.close()

method close*(r: DelimitedReader) {.gcsafe.} =
  if r.isOpen:
    r.file.close()
    r.isOpen = false

# ---------------------------------------------------------------------------
# SQLite

type SqliteReader* = ref object of Reader
  spec: ReaderSpec
  db: DbConn
  isOpen: bool
  names: seq[string]
  rows: int

proc newSqliteReader*(spec: ReaderSpec): SqliteReader = SqliteReader(spec: spec)

proc quoteIdent(name: string): string = "\"" & name.replace("\"", "\"\"") & "\""

proc baseQuery(spec: ReaderSpec): string =
  ## The table or SELECT as a subquery.
  let q = spec.query.strip
  if q.toLowerAscii.startsWith("select") or q.toLowerAscii.startsWith("with"): "(" & q & ")"
  else: quoteIdent(q)

proc whereClause(r: SqliteReader, args: var seq[string]): string =
  var parts: seq[string]
  for f in r.spec.filters:
    if f.column notin r.names:
      parts.add "0"                       # a filter on no column shows nothing
      continue
    let col = quoteIdent(f.column)
    case f.op
    of foContains:
      parts.add col & " LIKE ? ESCAPE '\\'"
      args.add "%" & f.text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") & "%"
    of foStartsWith, foEndsWith:
      parts.add col & " LIKE ? ESCAPE '\\'"
      let esc = f.text.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
      args.add (if f.op == foStartsWith: esc & "%" else: "%" & esc)
    of foEquals:
      parts.add col & " = ?"
      args.add f.text
    of foGreater, foLess, foGreaterEq, foLessEq:
      let op = case f.op
               of foGreater: ">"
               of foLess: "<"
               of foGreaterEq: ">="
               else: "<="
      parts.add "CAST(" & col & " AS REAL) " & op & " CAST(? AS REAL)"
      args.add f.text
  if parts.len == 0: "" else: " WHERE " & parts.join(" AND ")

proc orderClause(r: SqliteReader): string =
  if r.spec.sortDir == sdNone or r.spec.sortColumn notin r.names: return ""
  " ORDER BY " & quoteIdent(r.spec.sortColumn) & " COLLATE NOCASE" &
    (if r.spec.sortDir == sdDescending: " DESC" else: " ASC")

proc recount(r: SqliteReader): int =
  var args: seq[string]
  let where = r.whereClause(args)
  var statement = "SELECT COUNT(*) FROM " & baseQuery(r.spec) & where
  parseInt(r.db.getValue(sql(statement), args))

method open*(r: SqliteReader): seq[string] {.gcsafe.} =
  r.db = db_sqlite.open(r.spec.path, "", "", "")
  r.isOpen = true
  var cols: DbColumns
  for _ in r.db.instantRows(cols, sql("SELECT * FROM " & baseQuery(r.spec) & " LIMIT 1")):
    discard
  for c in cols: r.names.add c.name
  r.rows = r.recount()
  r.names

method countStep*(r: SqliteReader, budget: int): tuple[count: int, done: bool] {.gcsafe.} =
  (r.rows, true)

method configure*(r: SqliteReader, spec: ReaderSpec): int {.gcsafe.} =
  r.spec.sortColumn = spec.sortColumn
  r.spec.sortDir = spec.sortDir
  r.spec.filters = spec.filters
  r.rows = r.recount()
  r.rows

method readPage*(r: SqliteReader, pageNo, pageSize: int): ColumnPage {.gcsafe.} =
  result = newColumnPage(pageNo * pageSize, r.names.len)
  if not r.isOpen: return
  var args: seq[string]
  let statement = "SELECT * FROM " & baseQuery(r.spec) & r.whereClause(args) &
                  r.orderClause() & " LIMIT " & $pageSize & " OFFSET " & $(pageNo * pageSize)
  for row in r.db.getAllRows(sql(statement), args):
    result.addRow row

method close*(r: SqliteReader) {.gcsafe.} =
  if r.isOpen:
    r.db.close()
    r.isOpen = false

proc newReader*(spec: ReaderSpec): Reader =
  case spec.kind
  of skLines: newLinesReader(spec.path)
  of skDelimited: newDelimitedReader(spec.path, spec.delimiter, spec.header)
  of skSqlite: newSqliteReader(spec)
