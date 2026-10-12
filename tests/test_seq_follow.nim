## A list's place (selection, focus, scroll) across edits to its rows, and the
## real widgets following a LinkSeq.

import std/[unittest, sets, json, tables]
import rui
import ../packages/rui_widgets/src/seq_follow

proc place(sel: openArray[int], focus = 0, scroll = 0.0'f32): RowPlace =
  RowPlace(selection: toHashSet(sel), focus: focus, hover: -1, anchor: focus,
           scrollY: scroll)

suite "followEdit":

  test "an insert above the selection shifts it; below leaves it":
    var p = place([3], focus = 3)
    discard p.followEdit(SeqChange(kind: scInsert, index: 1, count: 2), 8, 20, 100)
    check p.selection == toHashSet([5]) and p.focus == 5
    p = place([1], focus = 1)
    discard p.followEdit(SeqChange(kind: scInsert, index: 4, count: 1), 6, 20, 100)
    check p.selection == toHashSet([1]) and p.focus == 1

  test "removing the selected row drops it and reports it; focus stays beside":
    var p = place([2, 4], focus = 2)
    let lost = p.followEdit(SeqChange(kind: scRemove, index: 2, count: 1), 5, 20, 100)
    check lost
    check p.selection == toHashSet([3])
    check p.focus == 2                           # the row that slid into its place

  test "removing the last row keeps focus in range":
    var p = place([], focus = 4)
    discard p.followEdit(SeqChange(kind: scRemove, index: 4, count: 1), 4, 20, 100)
    check p.focus == 3

  test "an emptied list has focus 0":
    var p = place([0], focus = 0)
    discard p.followEdit(SeqChange(kind: scRemove, index: 0, count: 1), 0, 20, 100)
    check p.focus == 0 and p.selection.len == 0

  test "a move carries the selection with its row":
    var p = place([1], focus = 1)
    discard p.followEdit(SeqChange(kind: scMove, index: 1, to: 4, count: 1), 6, 20, 100)
    check p.selection == toHashSet([4]) and p.focus == 4

  test "reset clears the place":
    var p = place([1, 2], focus = 2, scroll = 80)
    check p.followEdit(SeqChange(kind: scReset), 3, 20, 100)
    check p.selection.len == 0 and p.focus == 0 and p.scrollY == 0

  test "replace changes nothing":
    var p = place([1], focus = 1, scroll = 40)
    check not p.followEdit(SeqChange(kind: scReplace, index: 1, count: 1), 6, 20, 100)
    check p.selection == toHashSet([1]) and p.scrollY == 40

  test "rows added above the viewport hold the view still":
    var p = place([], scroll = 100)               # row 5 is the first visible
    discard p.followEdit(SeqChange(kind: scInsert, index: 2, count: 3), 30, 20, 100)
    check p.scrollY == 160                        # still looking at the same row
    p = place([], scroll = 100)
    discard p.followEdit(SeqChange(kind: scInsert, index: 7, count: 3), 30, 20, 100)
    check p.scrollY == 100                        # inside or below the view: unchanged

  test "rows removed above the viewport hold the view still, and scroll is clamped":
    var p = place([], scroll = 100)
    discard p.followEdit(SeqChange(kind: scRemove, index: 0, count: 2), 28, 20, 100)
    check p.scrollY == 60
    p = place([], scroll = 100)
    discard p.followEdit(SeqChange(kind: scRemove, index: 0, count: 5), 8, 20, 100)
    check p.scrollY == 0                          # the rows in view moved up with it
    p = place([], scroll = 100)
    discard p.followEdit(SeqChange(kind: scRemove, index: 7, count: 3), 8, 20, 100)
    check p.scrollY == 60                         # 8 rows * 20 - 100: the new maximum

suite "widgets following a LinkSeq":

  test "ListView: edits land where they happen and the selection stays on its row":
    let todos = newLinkSeq(@["a", "b", "c", "d"])
    let list = newListView()
    list.bindItems(todos)
    check list.source.count == 4 and list.source.text(3) == "d"
    list.selection = toHashSet([2])
    list.focusIndex = 2
    todos.insert(0, "new")
    check list.source.count == 5 and list.source.text(0) == "new"
    check list.selection == toHashSet([3]) and list.focusIndex == 3
    todos.delete(3)                                   # the selected row ("c")
    check list.selection.len == 0
    check list.source.count == todos.len

  test "ListView: onSelect hears that a selected row vanished":
    let todos = newLinkSeq(@["a", "b", "c"])
    var heard = -1
    let list = newListView(onSelect = proc(s: HashSet[int]) = heard = s.len)
    list.bindItems(todos)
    list.selection = toHashSet([1])
    todos.delete(1)
    check heard == 0

  test "ListView: an edit marks it dirty and releases on dispose":
    let todos = newLinkSeq(@["a"])
    let list = newListView()
    list.bindItems(todos)
    list.isDirty = false
    todos.add "b"
    check list.isDirty and list.layoutDirty
    disposeTree(list)
    check todos.listenerCount == 0
    todos.add "c"                                     # nobody follows any more
    check list.layoutDirty == false or list.source.count == 3

  test "ListBox follows too":
    let todos = newLinkSeq(@["a", "b"])
    let box = newListBox()
    box.bindItems(todos)
    box.selection = toHashSet([1])
    todos.insert(0, "z")
    check box.selection == toHashSet([2])

  test "DataTable: rows follow, selection stays on its source row":
    proc row(name: string): DataRow =
      DataRow(id: name, values: {"name": %name}.toTable)
    let rows = newLinkSeq(@[row("a"), row("b"), row("c")])
    let table = newDataTable(columns = @[DataColumn(id: "name", title: "Name", width: 100)])
    table.bindRows(rows)
    check table.data.len == 3
    table.selected = toHashSet([2])
    rows.insert(0, row("z"))
    check table.data.len == 4
    check table.selected == toHashSet([3])
    check table.data[3].values["name"].getStr == "c"

  test "ui: items = -> seq binds a LinkSeq":
    let todos = newLinkSeq(@["x", "y"])
    let root = ui:
      Column():
        ListView(items = -> todos)
    let list = ListView(root.children[0])
    check list.source.count == 2
    todos.add "z"
    check list.source.count == 3 and list.source.text(2) == "z"
