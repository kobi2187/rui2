## SPIKE: do in-app windows behave? Shared state, leaks, hit order, popups,
## focus. Findings are the point; see the test names.

import std/[unittest, options, monotimes]
import rui
from raylib import KeyboardKey

proc press(x, y: float32): GuiEvent =
  GuiEvent(kind: evMouseDown, mousePos: Point(x: x, y: y), timestamp: getMonoTime())

proc layoutOverlays() =
  for o in overlays(): o.layoutPass()

proc content(name: Link[string], level: Link[float32]): Widget =
  ui:
    Column(spacing = 4.0):
      Label(text = -> "Hello, {name}")
      TextInput(text = <-> name)
      Slider(value = <-> level)
      DatePicker(initialValue = "2026-10-11")

proc newWin(title: string, name: Link[string], level: Link[float32],
            x, y: float32): Window =
  result = newWindow(title = title, x = x, y = y, width = 300, height = 260)
  result.addChild content(name, level)

suite "windows spike":

  setup:
    clearOverlays()
    clearPopups()

  test "one Store entry bound in two windows stays in sync":
    let store = newStore()
    let name = store.declare("name", "Ada")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    let a = newWin("A", name, level, 20, 20)
    let b = newWin("B", name, level, 200, 60)
    host.openWindow a
    host.openWindow b
    layoutOverlays()
    let inputA = TextInput(a.children[0].children[1])
    let inputB = TextInput(b.children[0].children[1])
    inputA.onChange("Zed")                       # typed in window A
    check name.value == "Zed"
    inputB.onRefresh()
    check inputB.text == "Zed"
    let labelB = Label(b.children[0].children[0])
    labelB.onRefresh()
    check labelB.text == "Hello, Zed"

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
    check host.children.len == 0
    check name.dependentCount == 0               # every binding released
    check level.dependentCount == 0
    check name.observers.len == 0
    check getOccupiedMem() - memBefore < 2_000_000

  test "CONTROL: without disposeTree the Link keeps every closed window alive":
    let store = newStore()
    let name = store.declare("name", "Ada")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    for i in 0 ..< 50:
      let w = newWin("W", name, level, 0, 0)
      host.openWindow w
      hideOverlay(w)
      host.removeChild w                          # gone from the tree, not disposed
    check name.dependentCount == 100              # 50 windows x (Label + TextInput)

  test "the topmost window takes the click; a press inside a lower one raises it":
    let store = newStore()
    let name = store.declare("name", "Ada")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    let a = newWin("A", name, level, 20, 20)
    let b = newWin("B", name, level, 120, 60)
    host.openWindow a
    host.openWindow b
    layoutOverlays()
    # a point inside both: B is on top
    check windowOf(overlayAt(150, 100)) == Widget(b)
    # a press on a child of A (not in B) raises A
    let inA = a.children[0].children[1]                  # A's TextInput
    check inA.bounds.x < b.bounds.x
    onPointerPress(inA)
    check overlays()[^1] == Widget(a)
    check windowOf(overlayAt(150, 100)) == Widget(a)

  test "a window is opaque: a click on empty window background does not reach the page":
    let host = newVStack()
    let w = newWindow(title = "x", x = 10, y = 10, width = 200, height = 120)
    host.openWindow w
    layoutOverlays()
    check w.handleInput(press(100, 100))

  test "dragging by the title bar moves the window and the content follows":
    let store = newStore()
    let name = store.declare("name", "Ada")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    let w = newWin("A", name, level, 40, 40)
    host.openWindow w
    layoutOverlays()
    let childX = w.children[0].bounds.x
    discard w.handleInput(press(60, 50))                 # on the title bar
    discard w.handleInput(GuiEvent(kind: evMouseMove, mousePos: Point(x: 160, y: 90)))
    layoutOverlays()
    check w.x == 140 and w.y == 80
    check w.children[0].bounds.x == childX + 100

  test "a DatePicker's calendar opens above its own window and every other":
    let store = newStore()
    let name = store.declare("name", "Ada")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    let a = newWin("A", name, level, 20, 20)
    let b = newWin("B", name, level, 120, 60)
    host.openWindow a
    host.openWindow b
    layoutOverlays()
    let picker = DatePicker(a.children[0].children[3])
    onPointerPress(picker)                               # click into A: raised
    discard picker.handleInput(press(picker.bounds.x + 5, picker.bounds.y + 5))
    check picker.isOpen
    check overlays()[^1] == Widget(picker.popup)         # popup above both windows
    check overlays()[^2] == Widget(a)

  test "FINDING: the focus chain spans every window (Tab is not scoped)":
    let store = newStore()
    let name = store.declare("name", "Ada")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    host.addChild newButton(text = "page")
    let a = newWin("A", name, level, 20, 20)
    let b = newWin("B", name, level, 120, 60)
    host.openWindow a
    host.openWindow b
    let fm = newFocusManager()
    fm.buildFocusChain(host)
    check fm.focusChain.len == 1 + 3 + 3                 # button, then 3 in each window
    fm.buildFocusChain(b)                                # the scoping the real design needs
    check fm.focusChain.len == 3

  test "FINDING: closing the window that holds focus leaves the manager pointing at it":
    let store = newStore()
    let name = store.declare("name", "Ada")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    let a = newWin("A", name, level, 20, 20)
    host.openWindow a
    let fm = newFocusManager()
    fm.buildFocusChain(host)
    let input = a.children[0].children[1]
    fm.requestFocus(input)
    closeWindow(a)
    check fm.focusedWidget == input                      # dangling: nothing told the manager
    check input.parent != nil                            # and it still hangs off the dead subtree

suite "windows through the real frame pipeline":

  setup:
    clearOverlays()
    clearPopups()

  test "a click on a child of a lower window raises it, via the router":
    let store = newStore()
    let name = store.declare("name", "Ada")
    let level = store.declare("level", 0.0'f32)
    let host = newVStack()
    let a = newWin("A", name, level, 20, 20)
    let b = newWin("B", name, level, 250, 80)
    host.openWindow a
    host.openWindow b
    let app = newApp(title = "t", width = 700, height = 500)
    let source = newListEventSource()
    app.eventSource = source
    app.setRootWidget(host)
    app.stepHeadless()
    check overlays()[^1] == Widget(b)
    let target = a.children[0].children[1]               # A's TextInput
    let at = Point(x: target.bounds.x + 5, y: target.bounds.y + 5)
    source.push(GuiEvent(kind: evMouseDown, priority: epHigh, timestamp: getMonoTime(),
                         mousePos: at))
    app.stepHeadless()
    check overlays()[^1] == Widget(a)
    check app.focusManager.focusedWidget == target       # and it took the focus too

  test "a hidden popup does not keep the frame dirty":
    let host = newVStack()
    let combo = newComboBox(items = @["a", "b"])
    host.addChild combo
    let picker = newDatePicker()
    host.addChild picker
    let app = newApp(title = "t", width = 400, height = 300)
    app.eventSource = newListEventSource()
    app.setRootWidget(host)
    app.stepHeadless()
    host.isDirty = false
    combo.isDirty = false
    picker.isDirty = false
    check combo.list.isDirty                               # never painted, so never cleaned
    check not host.anyChildDirty()                         # but not the host's business
