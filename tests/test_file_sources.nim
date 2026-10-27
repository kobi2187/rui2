## Sources over files and SQLite: lines, CSV/TSV, databases; inline and threaded.

import std/[unittest, os, strutils, random, sets]
import db_connector/db_sqlite
import rui
import ../packages/rui_widgets/src/sources/[readers, column_page]

let dir = getTempDir() / "rui_file_sources"
createDir dir

proc fixture(name, content: string): string =
  result = dir / name
  writeFile(result, content)

proc lines(path: string, mode = smInline): PagedSource =
  newLinesSource(path, mode)

proc settle(s: PagedSource, first, last: int) =
  ## Ask for rows and wait until they are in.
  s.want(first, last)
  for _ in 0 ..< 400:
    discard s.poll()
    if s.rowState(first) == rsReady and s.rowState(last) == rsReady: return
    sleep 5

suite "LinesSource":

  test "counts lines with and without a final newline, CRLF, empty lines and unicode":
    check lines(fixture("a.txt", "one\ntwo\nthree\n")).count == 3
    check lines(fixture("b.txt", "one\ntwo\nthree")).count == 3
    check lines(fixture("c.txt", "")).count == 0
    check lines(fixture("d.txt", "\n")).count == 1
    check lines(fixture("e.txt", "a\n\n\nb\n")).count == 4
    let s = lines(fixture("f.txt", "é\r\n☃ snow\r\n日本語"))
    check s.count == 3
    s.settle(0, 2)
    check s.text(0) == "é" and s.text(1) == "☃ snow" and s.text(2) == "日本語"

  test "every line of a file with a thousand lines reads back, across pages and index strides":
    var text = ""
    for i in 0 ..< 1000: text.add "line number " & $i & "\n"
    let s = lines(fixture("big.txt", text))
    check s.count == 1000
    s.settle(0, 999)
    for i in [0, 1, 127, 128, 129, 255, 256, 257, 511, 512, 999]:
      check s.text(i) == "line number " & $i
    check s.text(1000) == ""                              # past the end

  test "random line lengths agree with a reference split":
    randomize(7)
    var expected: seq[string]
    var text = ""
    for i in 0 ..< 5000:
      let line = repeat(char(ord('a') + i mod 26), rand(0 .. 60))
      expected.add line
      text.add line & "\n"
    let s = lines(fixture("rand.txt", text))
    check s.count == 5000
    s.settle(0, 4999)
    for i in 0 ..< 5000:
      if s.text(i) != expected[i]:
        checkpoint "line " & $i
        fail()
        break

  test "rows not read yet are pending, then ready":
    var text = ""
    for i in 0 ..< 3000: text.add $i & "\n"
    let s = lines(fixture("pend.txt", text))
    check s.rowState(2000) == rsPending
    s.want(2000, 2010)
    check s.rowState(2000) == rsReady and s.text(2005) == "2005"

  test "the cache keeps a bounded number of pages":
    var text = ""
    for i in 0 ..< 20000: text.add $i & "\n"
    let s = newPagedSource(ReaderSpec(kind: skLines, path: fixture("lru.txt", text)),
                           smInline, cachePages = 4)
    for page in 0 ..< 20:
      s.want(page * PageSize, page * PageSize)
    var ready = 0
    for page in 0 ..< 79:
      if s.rowState(page * PageSize) == rsReady: inc ready
    check ready <= 4 + 1                                   # the cache cap, give or take the prefetch
    check s.text(19 * PageSize) == $(19 * PageSize)        # the recent ones are there

  test "a threaded source counts and reads in the background":
    var text = ""
    for i in 0 ..< 3000: text.add "t" & $i & "\n"
    let s = lines(fixture("thr.txt", text), smThread)
    defer: s.close()
    check s.waitIdle()
    check s.count == 3000
    s.settle(1500, 1510)
    check s.text(1505) == "t1505"
    check s.rowState(10) == rsPending or s.text(10) == "t10"

  test "a page asked for before the count reaches it arrives whole, not empty":
    var text = ""
    for i in 0 ..< 200_000: text.add "row " & $i & "\n"
    let s = lines(fixture("early.txt", text), smThread)
    defer: s.close()
    s.want(0, 10)                        # at once: nothing is counted yet
    s.want(150_000, 150_010)             # and far ahead of the count
    s.settle(0, 10)
    s.settle(150_000, 150_010)
    check s.text(0) == "row 0" and s.text(255) == "row 255"
    check s.text(150_005) == "row 150005"

  test "listeners hear the count grow and pages arrive":
    var text = ""
    for i in 0 ..< 600: text.add $i & "\n"
    let s = lines(fixture("notes.txt", text), smThread)
    defer: s.close()
    var kinds: seq[SeqChangeKind]
    discard s.listen(proc(c: SeqChange) = kinds.add c.kind)
    check s.waitIdle()
    check scInsert in kinds
    s.want(0, 5)
    for _ in 0 ..< 200:
      discard s.poll()
      sleep 5
    check scReplace in kinds

  test "a missing file is an error on the source, not a crash":
    let s = newLinesSource(dir / "nope.txt", smThread)
    defer: s.close()
    for _ in 0 ..< 200:
      discard s.poll()
      if s.error.len > 0: break
      sleep 5
    check s.error.len > 0

suite "DelimitedSource":

  test "CSV with quotes, embedded delimiters, escaped quotes and newlines":
    let path = fixture("q.csv", "name,note\nann,\"hi, there\"\nbob,\"two\nlines\"\ncy,\"say \"\"hi\"\"\"\n")
    let s = newDelimitedSource(path, ',', true, smInline)
    check s.columns == @["name", "note"]
    check s.count == 3
    s.settle(0, 2)
    check s.row(0) == @["ann", "hi, there"]
    check s.row(1) == @["bob", "two\nlines"]
    check s.row(2) == @["cy", "say \"hi\""]

  test "TSV, no header, CRLF, a last row without a newline":
    let s = newDelimitedSource(fixture("t.tsv", "1\ta\r\n2\tb\r\n3\tc"), '\t', false, smInline)
    check s.columns == @["1", "2"]
    check s.count == 3
    s.settle(0, 2)
    check s.row(0) == @["1", "a"] and s.row(2) == @["3", "c"]

  test "a header-only file has no rows; an empty one has none either":
    check newDelimitedSource(fixture("h.csv", "a,b\n"), ',', true, smInline).count == 0
    check newDelimitedSource(fixture("z.csv", ""), ',', true, smInline).count == 0

  test "a long CSV reads back row by row across index strides":
    var text = "id,sq\n"
    for i in 0 ..< 1500: text.add $i & "," & $(i * i) & "\n"
    let s = newDelimitedSource(fixture("long.csv", text), ',', true, smInline)
    check s.count == 1500
    s.settle(0, 1499)
    for i in [0, 127, 128, 255, 256, 700, 1499]:
      check s.row(i) == @[$i, $(i * i)]

  test "quoted newlines do not shift the rows after them":
    var text = "a,b\n"
    for i in 0 ..< 400:
      text.add (if i mod 7 == 0: $i & ",\"x\ny\"\n" else: $i & ",plain\n")
    let s = newDelimitedSource(fixture("nl.csv", text), ',', true, smInline)
    check s.count == 400
    s.settle(0, 399)
    for i in [0, 6, 7, 8, 127, 128, 399]:
      check s.cell(i, 0) == $i

proc makeDb(name: string, rows = 1000): string =
  result = dir / name
  removeFile(result)
  let db = open(result, "", "", "")
  db.exec(sql"CREATE TABLE people (id INTEGER, name TEXT, age INTEGER, city TEXT)")
  db.exec(sql"BEGIN")
  for i in 0 ..< rows:
    db.exec(sql"INSERT INTO people VALUES (?, ?, ?, ?)", i, "person " & $i,
            20 + (i * 7) mod 50, (if i mod 3 == 0: "Rome" else: "Oslo"))
  db.exec(sql"COMMIT")
  db.close()

suite "SqliteSource":

  test "count, columns and rows from a table":
    let s = newSqliteSource(makeDb("p.db"), "people", smInline)
    check s.count == 1000
    check s.columns == @["id", "name", "age", "city"]
    s.settle(0, 5)
    check s.row(3) == @["3", "person 3", "41", "Rome"]
    s.settle(990, 999)
    check s.cell(999, 1) == "person 999"

  test "a SELECT works as the source":
    let s = newSqliteSource(makeDb("q.db"), "SELECT id, name FROM people WHERE id < 10", smInline)
    check s.count == 10 and s.columns == @["id", "name"]

  test "sorting is done by the database, text without regard to case":
    let s = newSqliteSource(makeDb("s.db"), "people", smInline)
    s.sortBy("age", sdAscending)
    s.settle(0, 3)
    check s.cell(0, 2) == "20"
    s.sortBy("age", sdDescending)
    s.settle(0, 3)
    check s.cell(0, 2) == "69"
    s.sortBy("name", sdAscending)
    s.settle(0, 3)
    check s.cell(0, 1) == "person 0"
    check s.canSort and s.canFilter

  test "filters become WHERE clauses; a quote or percent in the text is just text":
    let s = newSqliteSource(makeDb("f.db"), "people", smInline)
    s.setFilters @[ColumnFilter(column: "city", op: foEquals, text: "Rome")]
    check s.count == 334
    s.setFilters @[ColumnFilter(column: "city", op: foEquals, text: "Rome"),
                   ColumnFilter(column: "age", op: foGreaterEq, text: "60")]
    check s.count > 0 and s.count < 334
    s.settle(0, 0)
    check s.cell(0, 3) == "Rome" and parseInt(s.cell(0, 2)) >= 60
    s.setFilters @[ColumnFilter(column: "name", op: foContains, text: "50%")]
    check s.count == 0
    s.setFilters @[ColumnFilter(column: "name", op: foContains, text: "'; DROP TABLE people; --")]
    check s.count == 0
    s.setFilters @[]
    check s.count == 1000                                  # the table is intact

  test "a change of sort or filter announces a reset and drops stale rows":
    let s = newSqliteSource(makeDb("r.db"), "people", smInline)
    var resets = 0
    discard s.listen(proc(c: SeqChange) = (if c.kind == scReset: inc resets))
    s.settle(0, 3)
    s.sortBy("age", sdDescending)
    check resets == 1
    check s.rowState(0) == rsPending                       # the old page is gone

  test "threaded: open, count, page and re-sort without blocking":
    let s = newSqliteSource(makeDb("t.db", 5000), "people", smThread)
    defer: s.close()
    check s.waitIdle()
    check s.count == 5000
    s.sortBy("age", sdDescending)
    for _ in 0 ..< 400:
      discard s.poll()
      if s.count == 5000 and not s.busy: break
      sleep 5
    s.settle(0, 2)
    check s.cell(0, 2) == "69"

  test "a missing table is reported as an error":
    let s = newSqliteSource(makeDb("m.db"), "no_such_table", smThread)
    defer: s.close()
    for _ in 0 ..< 400:
      discard s.poll()
      if s.error.len > 0: break
      sleep 5
    check s.error.len > 0
