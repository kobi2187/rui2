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

## Long text, a page at a time

A book does not go into a Label. A `TextPager` takes it from a row source, one
paragraph a row (a blank row is a blank line), and lays out pages that fit an
area, only when they are asked for:

```nim
let book = newTextPager(newLinesSource("book.txt"), TextStyle(fontSize: 22))
book.setArea(width, height)          # another size re-lays the pages
book.page(41)                        # some(text), or none while its rows are coming
book.pageAt(pos)                     # the page starting at a TextPos, and where the next starts
book.source.attach(widget, proc(c: SeqChange) = refresh())   # pages as rows arrive
```

- Only the paragraphs a page shows are read (with a stretch ahead), in the
  background; a page whose rows haven't arrived is `none` until they do.
- Pages are found in order and only where each starts is kept; `pageAt` lays out
  one page from any position without the pages before it (to reopen a book at a
  saved place). `atEnd(pos)` tells the end apart from "not read yet".
- Each page is its lines joined by `\n`, each already fitting the width, so a
  wrapped Label of that width shows exactly that page.
- `examples/widgets/wave_reader.nim` reads a 4,000-line book this way.

**`TextView`** is the ready-made scrolling reader on a pager:
`TextView(source = newLinesSource("book.txt"), fontSize = 18)`. It scrolls by
lines (wheel, arrows, PageUp/PageDown, Home/End); its scroll bar counts
paragraphs, since the height of text never laid out isn't known, so dragging it
jumps straight to a paragraph. `top`, `scrollTo(pos)` and `onScroll` give the
place as a text position, to save and reopen. A read-only `TextArea` is still
the choice for short text: it holds and wraps all of it, and it can select
(`examples/widgets/text_view.nim`).
