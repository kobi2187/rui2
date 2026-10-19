## Fingers on a scrolling row list, the same for every one: with a mouse a press
## selects at once; with fingers a drag scrolls and only a tap selects; two
## fingers scroll by the movement of their midpoint in either mode.

import std/[unittest, sequtils, json, tables, sets, os]
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

suite "pinch":
  setup: releaseAllPointers()
  teardown: releaseAllPointers()

  proc spread(r: Rig, c: Point, from0, to0: float32, steps = 4) =
    ## Two fingers either side of `c`, moving apart (or together) symmetrically.
    r.press(c.x - from0, c.y)
    r.pointerDown(1, c.x + from0, c.y)
    for i in 1 .. steps:
      let d = from0 + (to0 - from0) * i.float32 / steps.float32
      r.pointerMove(0, c.x - d, c.y)
      r.pointerMove(1, c.x + d, c.y)
    r.pointerUp(1, c.x + to0, c.y)
    r.release(c.x - to0, c.y)

  test "MapWidget zooms in when the fingers spread and out when they close":
    let m = newMapWidget(); m.sizeRequest = Size(width: 300, height: 200)
    let r = newRig(stack(m))
    let before = m.zoom
    r.spread(centre(m), 20, 60)
    check m.zoom > before + 0.5
    let zoomed = m.zoom
    r.spread(centre(m), 60, 20)
    check m.zoom < zoomed - 0.5

  test "MapWidget keeps the place between the fingers under them":
    let m = newMapWidget(); m.sizeRequest = Size(width: 300, height: 200)
    let r = newRig(stack(m))
    let c = centre(m)
    let view = MapView(center: m.center, zoom: m.zoom, projection: m.projection,
                       originX: m.bounds.x, originY: m.bounds.y,
                       width: m.bounds.width, height: m.bounds.height)
    let place = view.screenToWorld(c.x, c.y)
    r.spread(c, 20, 60)
    let after = MapView(center: m.center, zoom: m.zoom, projection: m.projection,
                        originX: m.bounds.x, originY: m.bounds.y,
                        width: m.bounds.width, height: m.bounds.height)
    let at = after.worldToScreen(place)
    check abs(at.x - c.x) < 2 and abs(at.y - c.y) < 2

  test "MapWidget: a pinch does not start a one-finger pan":
    let m = newMapWidget(); m.sizeRequest = Size(width: 300, height: 200)
    let r = newRig(stack(m))
    let c = centre(m)
    r.press(c.x, c.y)
    check m.isPanning
    r.pointerDown(1, c.x + 40, c.y)
    check not m.isPanning
    r.pointerUp(1, c.x + 40, c.y); r.release(c.x, c.y)

  test "Timeline zooms with a pinch":
    let t = Timeline(newWidgetByName("Timeline").get)
    t.sizeRequest = Size(width: 300, height: 120)
    let r = newRig(stack(t))
    let before = t.pixelsPerUnit
    r.spread(Point(x: t.bounds.x + 150, y: t.bounds.y + 100), 20, 60)
    check t.pixelsPerUnit > before * 1.5
    let zoomed = t.pixelsPerUnit
    r.spread(Point(x: t.bounds.x + 150, y: t.bounds.y + 100), 60, 20)
    check t.pixelsPerUnit < zoomed

  test "ScrollView: a second finger carries the content":
    let sv = newScrollView(padding = 0.0)
    sv.sizeRequest = Size(width: 200, height: 100)
    let tall = newLabel(text = "tall", fontSize = 14.0)
    tall.sizeRequest = Size(width: 150, height: 600)
    sv.addChild(tall)
    let r = newRig(stack(sv))
    let c = centre(sv)
    r.pointerDown(1, c.x, c.y + 30)
    r.pointerMove(1, c.x, c.y)
    r.pointerMove(1, c.x, c.y - 30)
    r.pointerUp(1, c.x, c.y - 30)
    check sv.scrollOffsetY > 40

suite "one finger in a ScrollView":
  var sv: ScrollView
  var button: Button
  var clicks = 0
  var r: Rig

  setup:
    setInputMode(imTouch)
    clicks = 0
    sv = newScrollView(padding = 0.0)
    sv.sizeRequest = Size(width: 200, height: 100)
    let content = newVStack(spacing = 4.0)
    button = newButton(text = "go", onClick = proc() = inc clicks)
    content.addChild(button)
    let tall = newLabel(text = "tall", fontSize = 14.0)
    tall.sizeRequest = Size(width: 150, height: 600)
    content.addChild(tall)
    sv.addChild(content)
    r = newRig(stack(sv))

  teardown:
    unpinInputMode()
    releaseAllPointers()

  test "dragging on empty content scrolls it":
    let c = centre(sv)
    r.press(c.x, c.y + 30)
    r.pointerMove(0, c.x, c.y)
    r.pointerMove(0, c.x, c.y - 30)
    r.release(c.x, c.y - 30)
    check sv.scrollOffsetY > 40

  test "a tap on a button still clicks it":
    r.click(button)
    check clicks == 1

  test "a drag that starts on a button scrolls and does not click":
    let c = centre(button)
    r.press(c.x, c.y)
    r.pointerMove(0, c.x, c.y - 10)
    r.pointerMove(0, c.x, c.y - 40)
    r.release(c.x, c.y - 40)
    check sv.scrollOffsetY > 20
    check clicks == 0
    check not button.pressed

  test "with a mouse the same drag clicks nothing and scrolls nothing":
    setInputMode(imDesktop)
    let c = centre(button)
    r.press(c.x, c.y)
    r.pointerMove(0, c.x, c.y - 40)
    r.release(c.x, c.y - 40)
    check sv.scrollOffsetY == 0

  test "a quick flick runs on after the finger lifts":
    let c = centre(sv)
    r.press(c.x, c.y + 40)
    for i in 1 .. 4:
      sleep(16)
      r.pointerMove(0, c.x, c.y + 40 - i.float32 * 15)
    r.release(c.x, c.y - 20)
    let atRelease = sv.scrollOffsetY
    for _ in 1 .. 30:
      sleep(20); discard fireDueRepaints(); r.frame(1)
    check sv.scrollOffsetY > atRelease + 10

  test "touching again stops it":
    let c = centre(sv)
    r.press(c.x, c.y + 40)
    for i in 1 .. 4:
      sleep(16)
      r.pointerMove(0, c.x, c.y + 40 - i.float32 * 15)
    r.release(c.x, c.y - 20)
    sleep(40); discard fireDueRepaints(); r.frame(1)
    r.press(c.x, c.y)
    let held = sv.scrollOffsetY
    for _ in 1 .. 5:
      sleep(20); discard fireDueRepaints(); r.frame(1)
    check sv.scrollOffsetY == held
    r.release(c.x, c.y)

suite "a flick on a row list":
  setup: setInputMode(imTouch)
  teardown:
    unpinInputMode()
    releaseAllPointers()

  test "ListView runs on after a quick drag":
    let l = newListView(items = rows(300), visibleRows = 8)
    let r = newRig(stack(l))
    let c = centre(l)
    r.press(c.x - 30, c.y + 40)
    for i in 1 .. 4:
      sleep(16)
      r.pointerMove(0, c.x - 30, c.y + 40 - i.float32 * 15)
    r.release(c.x - 30, c.y - 20)
    let atRelease = l.scrollY
    for _ in 1 .. 30:
      sleep(20); discard fireDueRepaints(); r.frame(1)
    check l.scrollY > atRelease + 10

suite "a pinch that ends with one finger":
  setup: releaseAllPointers()
  teardown: releaseAllPointers()

  test "MapWidget carries on panning with the finger that stayed":
    let m = newMapWidget(); m.sizeRequest = Size(width: 300, height: 200)
    let r = newRig(stack(m))
    let c = centre(m)
    r.press(c.x, c.y)
    r.pointerDown(1, c.x + 40, c.y)
    r.pointerUp(1, c.x + 40, c.y)
    check m.isPanning
    let before = m.center
    r.pointerMove(0, c.x + 50, c.y)
    check m.center != before

suite "scroll bars on a touch screen jump to where they are touched":
  setup: setInputMode(imTouch)
  teardown:
    unpinInputMode()
    releaseAllPointers()

  for s in scrollers:
    let sc = s
    test sc.name & ": a tap low on the bar jumps there, a drag from it carries on":
      let w = sc.make()
      let r = newRig(stack(w))
      let x = w.bounds.x + w.bounds.width - 6      # inside the (widened) bar
      let y = w.bounds.y + w.bounds.height - 12
      r.press(x, y)
      let jumped = sc.scrollY(w)
      check jumped > 100                           # not a page: a jump near the end
      r.pointerMove(0, x, w.bounds.y + 30)
      check sc.scrollY(w) < jumped                 # the thumb follows the finger
      r.release(x, w.bounds.y + 30)
      check not sc.picked(w)

  test "ScrollView: the same":
    let sv = newScrollView(padding = 0.0)
    sv.sizeRequest = Size(width: 200, height: 100)
    let tall = newLabel(text = "tall", fontSize = 14.0)
    tall.sizeRequest = Size(width: 150, height: 1000)
    sv.addChild(tall)
    let r = newRig(stack(sv))
    let x = sv.bounds.x + sv.bounds.width - 6
    r.press(x, sv.bounds.y + sv.bounds.height - 10)
    check sv.scrollOffsetY > 500
    r.release(x, sv.bounds.y + sv.bounds.height - 10)

  test "with a mouse a click on the track still moves one page":
    setInputMode(imDesktop)
    let l = newListView(items = rows(300), visibleRows = 8)
    let r = newRig(stack(l))
    r.click(l.bounds.x + l.bounds.width - 5, l.bounds.y + l.bounds.height - 8)
    check l.scrollY > 0 and l.scrollY < 200
