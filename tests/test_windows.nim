## rui_windows: movable, resizable, closable windows on the overlay layer --
## geometry to the pixel, z-order and activation, keyboard scope, drag capture,
## and that closing releases everything.

import std/[unittest, options, monotimes]
import rui, rui_windows
from raylib import KeyboardKey

proc press(x, y: float32): GuiEvent =
  GuiEvent(kind: evMouseDown, mousePos: Point(x: x, y: y), timestamp: getMonoTime())

proc move(x, y: float32): GuiEvent =
  GuiEvent(kind: evMouseMove, mousePos: Point(x: x, y: y), timestamp: getMonoTime())

proc release(x, y: float32): GuiEvent =
  GuiEvent(kind: evMouseUp, mousePos: Point(x: x, y: y), timestamp: getMonoTime())

proc layoutOverlays() =
  for o in overlays(): o.layoutPass()

proc reset() =
  resetWindows()
  clearOverlays()
  clearPopups()
  releasePointer()

proc content(name: Link[string], level: Link[float32]): Widget =
  ui:
    Column(spacing = 4.0):
      Label(text = "Hello, " & $name.value)
      TextInput(text = name.value, onChange = name.setter)
      Slider(value = level.value, onChange = level.setter)
      Button(text = "Go")

proc newWin(title: string, name: Link[string], level: Link[float32],
            x, y: float32): Window =
  result = newWindow(title = title, x = x, y = y, width = 300, height = 260)
  result.addChild content(name, level)

suite "window geometry":

  let r = Rect(x: 100, y: 100, width: 200, height: 150)

  test "a BeOS tab keeps its close box at the left end, the zoom box at the right":
    check titleButton(r, 0, leftEnd = true).x == r.x
    check titleButton(r, 0).x == r.x + r.width - titleHeight
    check titleButton(r, 0, leftEnd = true).width == titleHeight

  test "edges under a point":
    check edgesAt(r, Point(x: 150, y: 150)) == {}
    check edgesAt(r, Point(x: 101, y: 150)) == {edgeLeft}
    check edgesAt(r, Point(x: 299, y: 200)) == {edgeRight}
    check edgesAt(r, Point(x: 299, y: 249)) == {edgeRight, edgeBottom}
    check edgesAt(r, Point(x: 101, y: 101)) == {edgeLeft, edgeTop}
    check edgesAt(r, Point(x: 50, y: 50)) == {}

  test "resizing keeps the opposite edge fixed":
    let a = resized(r, {edgeRight, edgeBottom}, 30, 20, 80, 60)
    check (a.x, a.y, a.width, a.height) == (100.0f32, 100.0f32, 230.0f32, 170.0f32)
    let b = resized(r, {edgeLeft, edgeTop}, 30, 20, 80, 60)
    check (b.x, b.y, b.width, b.height) == (130.0f32, 120.0f32, 170.0f32, 130.0f32)
    check b.x + b.width == r.x + r.width and b.y + b.height == r.y + r.height

  test "resizing stops at the minimum and does not push the window":
    let a = resized(r, {edgeLeft}, 500, 0, 80, 60)
    check a.width == 80.0f32
    check a.x + a.width == r.x + r.width
    let b = resized(r, {edgeBottom}, 0, -500, 80, 60)
    check b.height == 60.0f32 and b.y == r.y

  test "a window stays reachable inside the view":
    let view = Rect(x: 0, y: 0, width: 800, height: 600)
    let gone = Rect(x: -900, y: -50, width: 300, height: 200).clampedTo(view)
    check gone.x + gone.width >= minVisibleTitle and gone.y == 0.0f32
    let low = Rect(x: 400, y: 5000, width: 300, height: 200).clampedTo(view)
    check low.y == 600.0f32 - titleHeight
    let huge = Rect(x: 0, y: 0, width: 5000, height: 5000).clampedTo(view)
    check huge.width == 800.0f32 and huge.height == 600.0f32

suite "windows":

  setup:
    reset()

  test "one store entry bound in two windows stays in sync":
    let store = newStore()
    let name = store.declare("name", "Ada")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    let a = newWin("A", name, level, 20, 20)
    let b = newWin("B", name, level, 200, 60)
    host.openWindow a
    host.openWindow b
    layoutOverlays()
    TextInput(a.children[0].children[1]).onChange("Zed")
    check name.value == "Zed"
    let inputB = TextInput(b.children[0].children[1])
    inputB.onRefresh()
    check inputB.text == "Zed"

  test "the last opened window is on top and active":
    let store = newStore()
    let name = store.declare("name", "")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    let a = newWin("A", name, level, 20, 20)
    let b = newWin("B", name, level, 120, 60)
    host.openWindow a
    host.openWindow b
    check activeWindow() == Widget(b)
    check overlays()[^1] == Widget(b)
    check openWindows() == @[Widget(a), Widget(b)]

  test "a press inside a lower window raises it; a press on the page deactivates":
    let store = newStore()
    let name = store.declare("name", "")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    let page = newButton(text = "page")
    host.addChild page
    let a = newWin("A", name, level, 20, 20)
    let b = newWin("B", name, level, 120, 60)
    host.openWindow a
    host.openWindow b
    layoutOverlays()
    let inA = a.children[0].children[1]
    onPointerPress(inA)
    check activeWindow() == Widget(a) and overlays()[^1] == Widget(a)
    check windowOf(overlayAt(150, 100)) == Widget(a)
    onPointerPress(page)
    check activeWindow() == nil
    check focusScope == nil
    onPointerPress(nil)                       # empty space: still fine
    check activeWindow() == nil

  test "Tab stays inside the active window":
    let store = newStore()
    let name = store.declare("name", "")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    host.addChild newButton(text = "page")
    let a = newWin("A", name, level, 20, 20)
    let b = newWin("B", name, level, 120, 60)
    host.openWindow a
    host.openWindow b
    let fm = newFocusManager()
    fm.nextFocus(host)
    check fm.focusedWidget.isWithin(b)
    for i in 0 ..< 7:                          # more than a lap
      fm.nextFocus(host)
      check fm.focusedWidget.isWithin(b)
    for i in 0 ..< 7:
      fm.prevFocus(host)
      check fm.focusedWidget.isWithin(b)
    onPointerPress(a.children[0].children[1])  # switch to A
    fm.nextFocus(host)
    check fm.focusedWidget.isWithin(a)
    deactivate()
    fm.clearFocus()
    var seen = 0
    for i in 0 ..< 8:
      fm.nextFocus(host)
      if not fm.focusedWidget.isWithin(a) and not fm.focusedWidget.isWithin(b): inc seen
    check seen > 0                             # with no active window the page is reachable

  test "a window is opaque and a title press starts a drag":
    let host = newVStack()
    let w = newWindow(title = "x", x = 10, y = 10, width = 200, height = 120)
    host.openWindow w
    layoutOverlays()
    check w.handleInput(press(100, 100))

  test "dragging moves the window, and keeps going when the pointer outruns it":
    let store = newStore()
    let name = store.declare("name", "")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    let w = newWin("A", name, level, 40, 40)
    host.openWindow w
    layoutOverlays()
    let childX = w.children[0].bounds.x
    check w.handleInput(press(60, 50))                   # on the title bar
    check pointerCapture() == Widget(w)
    check w.handleInput(move(160, 90))
    layoutOverlays()
    check w.x == 140 and w.y == 80
    check w.children[0].bounds.x == childX + 100
    check w.handleInput(release(160, 90))
    check not w.dragging

  test "the title bar cannot be dragged off screen":
    let host = newVStack()
    let w = newWindow(title = "x", x = 40, y = 40, width = 200, height = 120)
    host.openWindow w
    discard renderView
    renderView = some(Rect(x: 0, y: 0, width: 800, height: 600))
    layoutOverlays()
    discard w.handleInput(press(60, 50))
    discard w.handleInput(move(-5000, -5000))
    layoutOverlays()
    check w.y == 0.0f32
    check w.bounds.x + w.bounds.width >= minVisibleTitle
    discard w.handleInput(move(9000, 9000))
    layoutOverlays()
    check w.y == 600.0f32 - titleHeight
    renderView = none(Rect)

  test "dragging the border resizes; the minimum holds":
    let host = newVStack()
    let w = newWindow(title = "x", x = 40, y = 40, width = 200, height = 150,
                      minWidth = 120, minHeight = 90)
    host.openWindow w
    layoutOverlays()
    let corner = Point(x: w.bounds.x + w.bounds.width - 2, y: w.bounds.y + w.bounds.height - 2)
    check w.handleInput(press(corner.x, corner.y))
    discard w.handleInput(move(corner.x + 50, corner.y + 30))
    check w.width == 250.0f32 and w.height == 180.0f32
    discard w.handleInput(move(corner.x - 900, corner.y - 900))
    check w.width == 120.0f32 and w.height == 90.0f32
    check w.x == 40.0f32 and w.y == 40.0f32
    discard w.handleInput(release(0, 0))
    check w.resizeEdges == {}

  test "a window that is not resizable ignores the border":
    let host = newVStack()
    let w = newWindow(title = "x", x = 40, y = 40, width = 200, height = 150,
                      resizable = false)
    host.openWindow w
    layoutOverlays()
    discard w.handleInput(press(w.bounds.x + w.bounds.width - 2, w.bounds.y + w.bounds.height - 2))
    check w.resizeEdges == {}

  test "maximise fills the view and restores":
    let host = newVStack()
    let w = newWindow(title = "x", x = 40, y = 40, width = 200, height = 150)
    host.openWindow w
    renderView = some(Rect(x: 0, y: 0, width: 800, height: 600))
    layoutOverlays()
    toggleMaximized(w)
    layoutOverlays()
    check w.bounds.width == 800.0f32 and w.bounds.height == 600.0f32
    toggleMaximized(w)
    layoutOverlays()
    check (w.bounds.x, w.bounds.y, w.bounds.width) == (40.0f32, 40.0f32, 200.0f32)
    renderView = none(Rect)

  test "the close button closes; onClose fires once; closing twice is harmless":
    let host = newVStack()
    var closed = 0
    let w = newWindow(title = "x", x = 40, y = 40, width = 200, height = 150,
                      onClose = proc() = inc closed)
    host.openWindow w
    layoutOverlays()
    let c = titleButton(w.bounds, 0)
    check w.handleInput(press(c.x + 5, c.y + 5))
    check closed == 1 and host.children.len == 0 and overlays().len == 0
    check openWindows().len == 0
    closeWindow(w)
    check closed == 1

  test "Escape closes a window that asks for it":
    let host = newVStack()
    let w = newWindow(title = "x", closeOnEscape = true)
    let keep = newWindow(title = "y")
    host.openWindow w
    host.openWindow keep
    check not keep.handleInput(GuiEvent(kind: evKeyDown, key: KeyboardKey.Escape))
    check w.handleInput(GuiEvent(kind: evKeyDown, key: KeyboardKey.Escape))
    check openWindows() == @[Widget(keep)]

  test "closing the active window activates the next one and frees the scope":
    let store = newStore()
    let name = store.declare("name", "")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    let a = newWin("A", name, level, 20, 20)
    let b = newWin("B", name, level, 120, 60)
    host.openWindow a
    host.openWindow b
    closeWindow(b)
    check activeWindow() == Widget(a) and focusScope == Widget(a)
    closeWindow(a)
    check activeWindow() == nil and focusScope == nil

  test "a window opened with a focusable child asks for focus on it":
    let store = newStore()
    let name = store.declare("name", "")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    let a = newWin("A", name, level, 20, 20)
    host.openWindow a
    check takeFocusRequest() == a.children[0].children[1]

  test "opening and closing a thousand windows leaves nothing behind":
    let store = newStore()
    let name = store.declare("name", "Ada")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    GC_fullCollect()
    let memBefore = getOccupiedMem()
    for i in 0 ..< 1000:
      let w = newWin("W" & $i, name, level, float32(i mod 50), float32(i mod 30))
      host.openWindow w
      layoutOverlays()
      closeWindow(w)
    GC_fullCollect()
    check overlays().len == 0
    check openWindows().len == 0
    check host.children.len == 0
    check name.dependentCount == 0
    check level.dependentCount == 0
    check getOccupiedMem() - memBefore < 2_000_000

suite "windows through the real frame pipeline":

  setup:
    reset()

  test "a click inside a lower window raises it, focuses the field, and Tab then stays in it":
    let store = newStore()
    let name = store.declare("name", "Ada")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    host.addChild newButton(text = "page")
    let a = newWin("A", name, level, 20, 20)
    let b = newWin("B", name, level, 350, 80)
    host.openWindow a
    host.openWindow b
    let app = newApp(title = "t", width = 700, height = 500)
    let source = newListEventSource()
    app.eventSource = source
    app.setRootWidget(host)
    app.stepHeadless()
    check overlays()[^1] == Widget(b)
    let target = a.children[0].children[1]
    let at = Point(x: target.bounds.x + 5, y: target.bounds.y + 5)
    source.push(GuiEvent(kind: evMouseDown, priority: epHigh, timestamp: getMonoTime(),
                         mousePos: at))
    app.stepHeadless()
    check overlays()[^1] == Widget(a)
    check activeWindow() == Widget(a)
    check app.focusManager.focusedWidget == target
    source.push(GuiEvent(kind: evKeyDown, priority: epHigh, timestamp: getMonoTime(),
                         key: KeyboardKey.Tab))
    app.stepHeadless()
    check app.focusManager.focusedWidget.isWithin(a)

  test "closing the window that holds focus releases focus and the pointer":
    let store = newStore()
    let name = store.declare("name", "Ada")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    let a = newWin("A", name, level, 20, 20)
    host.openWindow a
    let app = newApp(title = "t", width = 700, height = 500)
    app.eventSource = newListEventSource()
    app.setRootWidget(host)
    app.stepHeadless()
    let input = a.children[0].children[1]
    app.focusManager.requestFocus(input)
    capturePointer(a)
    closeWindow(a)
    check app.focusManager.focusedWidget == nil
    check pointerCapture() == nil
