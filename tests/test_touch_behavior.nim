## Fingers on a scrolling row list, the same for every one: with a mouse a press
## selects at once; with fingers a drag scrolls and only a tap selects; two
## fingers scroll by the movement of their midpoint in either mode.

import std/[unittest, sequtils, json, tables, sets]
import rui
import ui_harness

type Scroller = object
  name: string
  make: proc(): Widget
  scrollY: proc(w: Widget): float32
  picked: proc(w: Widget): bool

proc rows(n: int): seq[string] = toSeq(0 ..< n).mapIt("item " & $it)

let scrollers = @[
  Scroller(name: "ListView",
    make: proc(): Widget = newListView(items = rows(100), visibleRows = 8),
    scrollY: proc(w: Widget): float32 = ListView(w).scrollY,
    picked: proc(w: Widget): bool = ListView(w).selection.len > 0),
  Scroller(name: "ListBox",
    make: proc(): Widget = newListBox(items = rows(100), visibleRows = 8),
    scrollY: proc(w: Widget): float32 = ListBox(w).scrollY,
    picked: proc(w: Widget): bool = ListBox(w).selection.len > 0),
  Scroller(name: "TreeView",
    make: proc(): Widget =
      var kids: seq[TreeNode]
      for i in 0 ..< 100: kids.add TreeNode(id: "n" & $i, text: "node " & $i)
      newTreeView(rootNode = TreeNode(id: "root", text: "root", expanded: true,
                                      children: kids), visibleRows = 8),
    scrollY: proc(w: Widget): float32 = TreeView(w).scrollY,
    picked: proc(w: Widget): bool = TreeView(w).selectedId.len > 0),
  Scroller(name: "DataTable",
    make: proc(): Widget =
      var data: seq[DataRow]
      for i in 0 ..< 100:
        var v = initTable[string, JsonNode]()
        v["a"] = %i
        data.add DataRow(id: $i, values: v)
      newDataTable(columns = @[DataColumn(id: "a", title: "A", width: 120.0)],
                   data = data, visibleRows = 8, showFilter = false),
    scrollY: proc(w: Widget): float32 = DataTable(w).scrollY,
    picked: proc(w: Widget): bool = DataTable(w).selected.len > 0),
  Scroller(name: "DataGrid",
    make: proc(): Widget =
      var data: seq[GridRow]
      for i in 0 ..< 100: data.add GridRow(id: $i, values: @[%i])
      newDataGrid(columns = @[GridColumn(id: "a", title: "A", width: 120.0)],
                  data = data, visibleRows = 8),
    scrollY: proc(w: Widget): float32 = DataGrid(w).scrollY,
    picked: proc(w: Widget): bool = DataGrid(w).selected.len > 0),
]

for s in scrollers:
  suite "touch: " & s.name:
    var r: Rig
    var w: Widget
    var x, y: float32

    setup:
      setInputMode(imTouch)
      w = s.make()
      r = newRig(stack(w))
      let c = centre(w)
      x = c.x - 30; y = c.y

    teardown:
      unpinInputMode()
      releaseAllPointers()

    test "a tap selects":
      r.pointerDown(0, x, y); r.pointerUp(0, x, y)
      check s.picked(w)

    test "a drag scrolls and selects nothing":
      r.press(x, y + 40)
      r.pointerMove(0, x, y + 20); r.pointerMove(0, x, y - 20)
      r.release(x, y - 40)
      check s.scrollY(w) > 0
      check not s.picked(w)

    test "dragging the other way brings it back":
      r.press(x, y + 40); r.pointerMove(0, x, y - 40); r.release(x, y - 40)
      let there = s.scrollY(w)
      r.press(x, y - 40); r.pointerMove(0, x, y + 40); r.release(x, y + 40)
      check s.scrollY(w) < there

    test "two fingers moving together scroll":
      r.press(x, y)
      r.pointerDown(1, x + 40, y)
      r.pointerMove(0, x, y - 30); r.pointerMove(1, x + 40, y - 30)
      r.pointerUp(1, x + 40, y - 30); r.release(x, y - 30)
      check s.scrollY(w) > 0

    test "a mouse still selects on the press":
      setInputMode(imDesktop)
      r.press(x, y)
      check s.picked(w)
      r.release(x, y)

    test "a second finger on a mouse desktop is still just a pan":
      setInputMode(imDesktop)
      r.press(x, y)
      r.pointerDown(1, x + 40, y)
      r.pointerMove(0, x, y - 30); r.pointerMove(1, x + 40, y - 30)
      r.pointerUp(1, x + 40, y - 30); r.release(x, y - 30)
      check s.scrollY(w) > 0
