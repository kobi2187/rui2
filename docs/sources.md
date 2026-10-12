# Row sources

Lists and tables do not hold their data; they ask a **row source** for the rows
they are about to draw (`rui_widgets/src/sources/`).

```nim
let lines = newLinesSource("server.log")            # every line of a file
let people = newDelimitedSource("people.csv")        # CSV; '\t' for TSV; header = false
let db = newSqliteSource("app.db", "people")         # a table, or any SELECT
let todos = newMemorySource(@["task", "done"], rows) # in memory, stored by column

ui:
  ListView(items = -> lines)                         # or list.bindSource(lines)
  DataTable(rows = -> db)
```

- **Only the visible rows are read**, plus a page either side, in the background
  (one worker thread per source; files are memory-mapped; SQLite uses
  `db_connector`). A hundred-million-line file costs about a megabyte of index.
- **Frames never wait.** A row that has not arrived is `rsPending` and draws as
  `...` in the theme's *disabled* colours; when its page lands the list repaints.
  The row count of a big file grows while it is being scanned.
- **Sorting and filtering belong to the source.** SQLite and MemorySource do both
  (`DataTable` headers and filter boxes call them); files cannot, and the header
  then does nothing.
- **Edits are positions** (`SeqChange`, as for `LinkSeq`): selection, focus and
  scroll stay on the rows they were on. `ListView.bindItems(linkSeq)` is a source
  over a `LinkSeq[string]`, nothing copied.
- Pages are stored by column (one arena string per column, offsets alongside),
  256 rows each, 96 pages cached.
- `close()` a source you made when you are done with it (it stops the worker).
- Write your own: subclass `RowSource`, override `count`, `columns`, `cell`, and
  `rowState`/`want`/`poll` if you fetch asynchronously (see `paged_source.nim`).
