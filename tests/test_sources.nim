## Row sources: the column page, the in-memory table, and the poll/listen contract.

import std/[unittest, sets, strutils, os, monotimes]
import db_connector/db_sqlite
import rui
from raylib import KeyboardKey
import ../packages/rui_widgets/src/sources/column_page

suite "ColumnPage":

  test "cells come back as they went in, by row and column":
    var p = newColumnPage(100, 3)
    p.addRow ["a", "bb", ""]
    p.addRow ["", "x", "ccc"]
    p.addRow ["longer text", "é", "☃"]
    check p.rowCount == 3 and p.columnCount == 3 and p.first == 100
    check p.cell(0, 0) == "a" and p.cell(0, 1) == "bb" and p.cell(0, 2) == ""
    check p.cell(1, 2) == "ccc" and p.cell(2, 0) == "longer text"
    check p.cell(2, 1) == "é" and p.cell(2, 2) == "☃"
    check p.cell(3, 0) == "" and p.cell(0, 5) == "" and p.cell(-1, 0) == ""

  test "short rows are padded, long ones cut":
    var p = newColumnPage(0, 2)
    p.addRow ["only"]
    p.addRow ["a", "b", "c"]
    check p.cell(0, 1) == "" and p.cell(1, 1) == "b" and p.columnCount == 2

  test "contains is by global row, and bytes grows with content":
    var p = newColumnPage(10, 1)
    p.addRow ["x"]
    p.addRow ["y"]
    check 10 in p and 11 in p and 12 notin p and 9 notin p
    check p.bytes > 0

  test "a thousand rows hold together":
    var p = newColumnPage(0, 4)
    for i in 0 ..< 1000: p.addRow [$i, "n" & $i, "", $(i * 7)]
    for i in [0, 1, 499, 999]:
      check p.cell(i, 0) == $i and p.cell(i, 1) == "n" & $i and p.cell(i, 3) == $(i * 7)

let srcDir = getTempDir() / "rui_sources_tests"
createDir srcDir

proc fixtureFile(name, content: string): string =
  result = srcDir / name
  writeFile(result, content)

proc makeTestDb(name: string): string =
  result = srcDir / name
  removeFile(result)
  let db = open(result, "", "", "")
  db.exec(sql"CREATE TABLE people (id INTEGER, name TEXT, city TEXT)")
  db.exec(sql"BEGIN")
  for i in 0 ..< 100:
    db.exec(sql"INSERT INTO people VALUES (?, ?, ?)", i, "p" & $i, (if i mod 4 == 0: "Rome" else: "Oslo"))
  db.exec(sql"COMMIT")
  db.close()

proc fruit(): MemorySource =
  newMemorySource(@["name", "qty"], @[@["pear", "10"], @["Apple", "9"],
                                      @["fig", "100"], @["banana", "2"]])

suite "MemorySource":

  test "counts, columns and cells":
    let s = fruit()
    check s.count == 4 and s.columns == @["name", "qty"]
    check s.cell(1, 0) == "Apple" and s.cell(2, 1) == "100"
    check s.text(0) == "pear" and s.row(3) == @["banana", "2"]
    check s.cell(9, 0) == "" and s.columnIndex("qty") == 1 and s.columnIndex("zzz") == -1
    check s.rowState(0) == rsReady

  test "sorting text ignores case; numbers sort as numbers":
    let s = fruit()
    s.sortBy("name", sdAscending)
    check s.row(0)[0] == "Apple" and s.row(3)[0] == "pear"
    s.sortBy("qty", sdAscending)
    check s.row(0)[1] == "2" and s.row(3)[1] == "100"       # not "10" < "100" < "2"
    s.sortBy("qty", sdDescending)
    check s.row(0)[1] == "100"
    s.sortBy("qty", sdNone)
    check s.cell(0, 0) == "pear"                            # stored order again

  test "filters narrow the view and combine":
    let s = fruit()
    s.setFilters @[ColumnFilter(column: "name", op: foContains, text: "AN")]
    check s.count == 1 and s.cell(0, 0) == "banana"
    s.setFilters @[ColumnFilter(column: "qty", op: foGreater, text: "9")]
    check s.count == 2
    s.setFilters @[ColumnFilter(column: "qty", op: foGreater, text: "9"),
                   ColumnFilter(column: "name", op: foEquals, text: "fig")]
    check s.count == 1 and s.cell(0, 0) == "fig"
    s.setFilters @[]
    check s.count == 4
    s.setFilters @[ColumnFilter(column: "nope", op: foContains, text: "x")]
    check s.count == 0                                      # a filter on no column shows nothing

  test "sort and filter together; both announce a reset":
    let s = fruit()
    var changes: seq[SeqChangeKind]
    let id = s.listen(proc(c: SeqChange) = changes.add c.kind)
    s.setFilters @[ColumnFilter(column: "qty", op: foGreaterEq, text: "9")]
    s.sortBy("qty", sdAscending)
    check changes == @[scReset, scReset]
    check s.count == 3 and s.cell(0, 1) == "9" and s.cell(2, 1) == "100"
    s.unlisten id

  test "append is an insert at the end, or a reset when a view is active":
    let s = fruit()
    var log: seq[SeqChange]
    discard s.listen(proc(c: SeqChange) = log.add c)
    s.append ["kiwi", "5"]
    check log[0] == SeqChange(kind: scInsert, index: 4, count: 1)
    s.sortBy("qty", sdAscending)
    s.append ["lime", "1"]
    check log[^1].kind == scReset and s.cell(0, 0) == "lime"

suite "listening":

  test "a poller is registered while something listens, and only then":
    let before = pollerCount()
    let s = fruit()
    check pollerCount() == before
    let a = s.listen(proc(c: SeqChange) = discard)
    let b = s.listen(proc(c: SeqChange) = discard)
    check pollerCount() == before + 1
    s.unlisten a
    check pollerCount() == before + 1
    s.unlisten b
    check pollerCount() == before

  test "a widget attached to a source is released when disposed":
    let s = fruit()
    let list = newListView()
    list.bindSource(s)
    check s.listenerCount == 1 and list.source == RowSource(s)
    disposeTree(list)
    check s.listenerCount == 0

  test "ListView over a source: nothing is copied and rows read from it":
    let s = fruit()
    let list = newListView()
    list.bindSource(s)
    check list.items.len == 0 and list.source.count == 4
    s.append ["kiwi", "5"]
    check list.source.count == 5
    list.selection = toHashSet([4])
    s.sortBy("qty", sdAscending)                            # a reset: the selection is void
    check list.selection.len == 0

  test "the scripting bridge reports a source as a summary, not its data":
    let s = fruit()
    let list = newListView()
    list.bindSource(s)
    let state = list.getScriptableState()
    check state["source"]["rows"].getInt == 4

suite "DataTable over a source":

  proc press(x, y: float32): GuiEvent =
    GuiEvent(kind: evMouseDown, mousePos: Point(x: x, y: y), timestamp: getMonoTime())

  proc key(k: KeyboardKey): GuiEvent =
    GuiEvent(kind: evKeyDown, key: k, timestamp: getMonoTime())

  proc settled(table: DataTable) =
    inc layoutPassNumber
    table.bounds = Rect(x: 0, y: 0, width: 360, height: 200)
    table.layoutDirty = true
    table.layoutPass()

  test "columns are made from the source, and nothing is copied":
    let s = fruit()
    let table = newDataTable()
    table.bindSource(s)
    check table.columns.len == 2 and table.columns[0].id == "name"
    check table.data.len == 0 and table.viewCount == 4
    check table.columns[0].sortable and table.columns[0].filterable   # a MemorySource can

  test "a header click sorts through the source":
    let s = fruit()
    let table = newDataTable(showFilter = false)
    table.bindSource(s)
    table.settled()
    let header = table.bounds.y + 14
    discard table.handleInput(press(table.bounds.x + 20, header))      # the name column
    check s.cell(0, 0) == "Apple"
    discard table.handleInput(press(table.bounds.x + 20, header))
    check s.cell(0, 0) == "pear"                                       # descending

  test "a file source cannot sort: the header does nothing":
    var text = ""
    for i in 0 ..< 50: text.add "row " & $i & "\n"
    let s = newLinesSource(fixtureFile("cantsort.txt", text), smInline)
    let table = newDataTable(showFilter = false)
    table.bindSource(s)
    check not table.columns[0].sortable
    table.settled()
    discard table.handleInput(press(table.bounds.x + 20, table.bounds.y + 14))
    s.want(0, 5)
    check s.cell(0, 0) == "row 0" and table.sortColumn == ""

  test "typing in a filter box filters through the source":
    let s = fruit()
    let table = newDataTable()
    table.bindSource(s)
    table.settled()
    table.editors["name"].onChange("an")
    check s.count == 1 and table.viewCount == 1

  test "a selected row stays on its row across an append; a sort voids it":
    let s = fruit()
    let table = newDataTable()
    table.bindSource(s)
    table.selected = toHashSet([2])
    s.append ["kiwi", "5"]
    check table.selected == toHashSet([2]) and table.viewCount == 5
    s.sortBy("qty", sdAscending)
    check table.selected.len == 0

  test "keyboard moves through the rows and selects by position":
    let s = fruit()
    let table = newDataTable(showFilter = false)
    table.bindSource(s)
    table.settled()
    table.focused = true
    discard table.handleInput(key(KeyboardKey.Down))
    discard table.handleInput(key(KeyboardKey.Down))
    check table.focusRow == 2 and table.selected == toHashSet([2])
    discard table.handleInput(key(KeyboardKey.End))
    check table.focusRow == 3

  test "a SQLite table in a DataTable: sort and filter reach the database":
    let s = newSqliteSource(makeTestDb("dt.db"), "people", smInline)
    let table = newDataTable()
    table.bindSource(s)
    table.settled()
    check table.viewCount == 100
    table.editors["city"].onChange("rome")
    check table.viewCount < 100 and s.canFilter
