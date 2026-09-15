## Hit-testing and event routing regression tests
##
## Two bugs lived here and between them meant no button in the framework ever
## received a click:
##
## 1. Hit-testing sorted candidates by z-index alone. Everything in an ordinary
##    container has z-index 0, so a click inside a Button also matched the
##    enclosing stack and the root, and the winner was whatever the interval
##    tree happened to yield first — in practice always the root.
## 2. Events were delivered to exactly one widget. Composites are built from
##    primitives (a Button is a Rectangle plus a Label) and hit-testing lands on
##    the innermost, which declares no handlers, so the click was dropped.

import std/unittest
import rui
import std/[options, monotimes]

proc buildTree(): tuple[root: VStack, button: Button, label: Label] =
  let root = newVStack(spacing = 8.0, padding = 10.0)
  root.bounds = Rect(x: 0, y: 0, width: 300, height: 200)
  let label = newLabel(text = "a label", fontSize = 14.0)
  let button = newButton(text = "press me")
  root.addChild(label)
  root.addChild(button)
  root.layoutPass()
  (root, button, label)

proc insertAll(hts: var HitTestSystem, w: Widget) =
  if w.visible:
    hts.insertWidget(w)
    for c in w.children:
      hts.insertAll(c)

proc hitSystem(root: Widget): HitTestSystem =
  # Built with an explicit `var` parameter rather than a closure over `result`:
  # HitTestSystem is a value object and cannot be captured.
  result = newHitTestSystem()
  result.insertAll(root)

proc mouseEvent(kind: EventKind, x, y: float32): GuiEvent =
  GuiEvent(kind: kind, priority: epHigh, timestamp: getMonoTime(),
           mousePos: Point(x: x, y: y))

suite "hit testing":

  test "a point inside a button resolves into the button, not the root":
    let (root, button, _) = buildTree()
    var hts = hitSystem(root)
    let hit = hts.getWidgetAt(button.bounds.x + 5, button.bounds.y + 5)
    check hit != nil
    # Deepest-wins means the hit is the Button or one of the primitives it is
    # built from -- never the enclosing stack, which is the bug this guards.
    var cur = hit
    var reachedButton = false
    while cur != nil:
      if cur == Widget(button):
        reachedButton = true
        break
      cur = cur.parent
    check reachedButton
    check hit.getTypeName() != "VStack"

  test "a point outside every widget resolves to nothing":
    let (root, _, _) = buildTree()
    var hts = hitSystem(root)
    let hit = hts.getWidgetAt(5000, 5000)
    check hit == nil

  test "deeper widgets win ties at equal z-index":
    let (root, button, _) = buildTree()
    var hts = hitSystem(root)
    let all = hts.findWidgetsAt(button.bounds.x + 5, button.bounds.y + 5)
    check all.len > 1          # button, its children and the root all overlap
    check all[0].treeDepth >= all[^1].treeDepth

  test "z-index still beats depth":
    let root = newZStack()
    root.bounds = Rect(x: 0, y: 0, width: 100, height: 100)
    let under = newRectangle(color = BLACK, filled = true)
    under.bounds = Rect(x: 0, y: 0, width: 100, height: 100)
    under.zIndex = 0
    let over = newRectangle(color = WHITE, filled = true)
    over.bounds = Rect(x: 0, y: 0, width: 100, height: 100)
    over.zIndex = 10
    root.addChild(under)
    root.addChild(over)

    var hts = hitSystem(root)
    let hit = hts.getWidgetAt(50, 50)
    check hit.zIndex == 10

  test "degenerate bounds are skipped rather than crashing":
    # Regression: a zero-sized root made padded containers compute negative
    # child widths, and the interval tree raised on the negative extent.
    var hts = newHitTestSystem()
    let zero = newLabel(text = "", fontSize = 14.0)
    zero.bounds = Rect(x: 0, y: 0, width: 0, height: 0)
    let negative = newLabel(text = "", fontSize = 14.0)
    negative.bounds = Rect(x: 10, y: 10, width: -30, height: 20)
    hts.insertWidget(zero)
    hts.insertWidget(negative)
    check hts.len == 0

suite "event routing":

  test "a click on a button fires its handler":
    let (root, button, _) = buildTree()
    var clicked = 0
    button.onClick = some(proc() {.closure.} = inc clicked)

    discard button.handleInput(mouseEvent(evMouseDown, button.bounds.x + 5,
                                          button.bounds.y + 5))
    discard button.handleInput(mouseEvent(evMouseUp, button.bounds.x + 5,
                                          button.bounds.y + 5))
    check clicked == 1

  test "an event bubbles from an inner primitive to the composite":
    # A Button's children are a Rectangle and a Label, neither of which handles
    # input. Without bubbling the click stops there.
    let (root, button, _) = buildTree()
    var clicked = 0
    button.onClick = some(proc() {.closure.} = inc clicked)

    check button.children.len > 0
    let inner = button.children[0]
    check not inner.handleInput(mouseEvent(evMouseDown, 0, 0))

    proc bubble(w: Widget, e: GuiEvent): bool =
      var cur = w
      while cur != nil:
        if cur.handleInput(e): return true
        cur = cur.parent
      false

    check bubble(inner, mouseEvent(evMouseDown, button.bounds.x + 5,
                                   button.bounds.y + 5))
    discard bubble(inner, mouseEvent(evMouseUp, button.bounds.x + 5,
                                     button.bounds.y + 5))
    check clicked == 1

  test "a disabled button ignores clicks":
    let disabled = newButton(text = "no", disabled = true)
    disabled.bounds = Rect(x: 0, y: 0, width: 100, height: 30)
    var clicked = 0
    disabled.onClick = some(proc() {.closure.} = inc clicked)
    discard disabled.handleInput(mouseEvent(evMouseDown, 5, 5))
    discard disabled.handleInput(mouseEvent(evMouseUp, 5, 5))
    check clicked == 0

  test "a checkbox toggles on mouse down and reports the new value":
    let cb = newCheckbox(text = "opt", initialChecked = false)
    cb.bounds = Rect(x: 0, y: 0, width: 150, height: 24)
    var reported: seq[bool] = @[]
    cb.onToggle = some(proc(v: bool) {.closure.} = reported.add v)

    discard cb.handleInput(mouseEvent(evMouseDown, 5, 5))
    check cb.checked
    discard cb.handleInput(mouseEvent(evMouseDown, 5, 5))
    check not cb.checked
    check reported == @[true, false]

  test "mouse move updates hover state":
    let b = newButton(text = "hover me")
    b.bounds = Rect(x: 0, y: 0, width: 100, height: 30)
    discard b.handleInput(mouseEvent(evMouseMove, 50, 15))
    check b.isHovered
    discard b.handleInput(mouseEvent(evMouseMove, 500, 500))
    check not b.isHovered

  test "an unhandled event returns false so it can keep bubbling":
    let l = newLabel(text = "inert", fontSize = 14.0)
    l.bounds = Rect(x: 0, y: 0, width: 50, height: 20)
    check not l.handleInput(mouseEvent(evMouseDown, 5, 5))
