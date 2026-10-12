## ColumnPage: a block of rows stored column by column (struct of arrays).
##
## A list of 256 rows of 6 text cells as `seq[seq[string]]` is 1,500 small heap
## objects, each with its own header and allocator slack. Here each *column*
## is one arena string holding all its cells back to back, and an offsets array
## says where each cell starts: 12 allocations for the page instead of 1,500,
## cells that sit together in memory, and a whole-column pass (a sort key, a
## filter) that reads one contiguous buffer. Rows are never materialised: ask for
## `cell(row, col)`, which is a slice of the arena.

type
  ColumnPage* = object
    first*: int                  ## index of the page's first row in its source
    columnCount: int
    rows: int
    arena: seq[string]           ## per column, every cell's bytes in a row
    ends: seq[seq[int32]]        ## per column, where each cell ends in its arena

proc newColumnPage*(first, columns: int): ColumnPage =
  ColumnPage(first: first, columnCount: columns,
             arena: newSeq[string](columns), ends: newSeq[seq[int32]](columns))

proc rowCount*(page: ColumnPage): int = page.rows
proc columnCount*(page: ColumnPage): int = page.columnCount

proc addRow*(page: var ColumnPage, cells: openArray[string]) =
  ## Append a row. A short row is padded with empty cells, a long one cut.
  for c in 0 ..< page.columnCount:
    if c < cells.len: page.arena[c].add cells[c]
    page.ends[c].add int32(page.arena[c].len)
  inc page.rows

proc cell*(page: ColumnPage, row, col: int): string =
  ## The text of one cell; `row` is local to the page (0 ..< rowCount).
  if row < 0 or row >= page.rows or col < 0 or col >= page.columnCount: return ""
  let stop = int(page.ends[col][row])
  let start = if row == 0: 0 else: int(page.ends[col][row - 1])
  result = page.arena[col][start ..< stop]

proc contains*(page: ColumnPage, globalRow: int): bool =
  globalRow >= page.first and globalRow < page.first + page.rows

proc bytes*(page: ColumnPage): int =
  ## Memory held by the cells (for a cache budget).
  for a in page.arena: result += a.len
  for e in page.ends: result += e.len * 4
