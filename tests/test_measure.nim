## Measure and arrange: constraints down, sizes up, rects placed once.
##
## A container asks its children how big they want to be (`measure`) without
## laying them out, then gives each its rect (`arrange`). Measurements are
## remembered until something under the widget changes, and a change deep in
## the tree reflows the containers above it.

import std/unittest
import rui

type Counted = ref object of Widget
  ## A leaf of a fixed natural size that counts how often it is measured.
  natural: Size
  calls: int

method computeSize(widget: Counted, c: Constraints): Size =
  inc widget.calls
  c.constrain(widget.natural)

proc counted(w, h: float32): Counted =
  result = Counted(natural: Size(width: w, height: h))
  initWidgetBase(result)

proc box(w, h: float32): Widget =
  newRectangle().frame(width = w, height = h)

suite "constraints":

  test "tight, loose and unbounded":
    let t = tight(100, 40)
    check t.tightWidth and t.tightHeight
    check t.constrain(Size(width: 500, height: 1)) == Size(width: 100, height: 40)
    let l = loose(100, 40)
    check not l.tightWidth
    check l.constrain(Size(width: 30, height: 90)) == Size(width: 30, height: 40)
    let u = unbounded()
    check u.maxWidth == Inf and not u.tightHeight
    check u.constrain(Size(width: 1e6, height: 3)) == Size(width: 1e6, height: 3)

  test "fixing one axis leaves the other alone":
    let c = unbounded().withWidth(80)
    check c.tightWidth and not c.tightHeight

suite "measuring":

  test "a clean widget is measured once, however often it is asked":
    let leaf = counted(30, 10)
    leaf.layoutDirty = false
    check leaf.measure(unbounded()) == Size(width: 30, height: 10)
    check leaf.measure(unbounded()) == Size(width: 30, height: 10)
    check leaf.calls == 1
    discard leaf.measure(unbounded().withWidth(50))   # a different question
    check leaf.calls == 2

  test "a dirty widget is measured again in the next pass":
    let leaf = counted(30, 10)
    inc layoutPassNumber
    discard leaf.measure(unbounded())
    discard leaf.measure(unbounded())        # same pass: remembered
    check leaf.calls == 1
    inc layoutPassNumber
    discard leaf.measure(unbounded())        # still dirty, new pass: asked again
    check leaf.calls == 2

  test "a requested size wins over the constraints, and min/max clamp it":
    let leaf = counted(30, 10)
    discard leaf.frame(width = 70)
    check leaf.measure(unbounded()).width == 70
    let small = counted(30, 10)
    discard small.frame(minWidth = 50, maxHeight = 5)
    check small.measure(unbounded()) == Size(width: 50, height: 5)

suite "Flex measures instead of laying out":

  test "a Row's natural size is the sum of its children, nothing moved":
    let a = box(40, 20)
    let b = box(60, 30)
    let row = newRow(spacing = 10)
    row.addChild a
    row.addChild b
    a.bounds = Rect(x: 999, y: 999, width: 1, height: 1)
    check row.measure(unbounded()) == Size(width: 110, height: 30)
    check a.bounds.x == 999                  # measuring placed nothing

  test "each child is measured once per pass, not once per probe":
    let leaves = @[counted(10, 10), counted(20, 10), counted(30, 10)]
    let col = newColumn()
    let row = newRow()
    for l in leaves: row.addChild l
    col.addChild row
    col.bounds = Rect(x: 0, y: 0, width: 400, height: 300)
    col.layoutPass()
    for l in leaves: check l.calls == 1

  test "a flex child is measured at its share":
    let fixed = box(100, 20)
    let grow = counted(10, 20)
    let row = newRow()
    row.addChild fixed
    row.addChild newExpanded()
    row.children[1].addChild grow
    row.bounds = Rect(x: 0, y: 0, width: 400, height: 50)
    row.layoutPass()
    check row.children[1].bounds.width == 300
    check row.children[1].bounds.x == 100

suite "a change reflows the containers above it":

  test "a label that grows pushes its sibling along":
    let label = newLabel(text = "hi")
    let after = box(20, 20)
    let row = newRow()
    row.addChild label
    row.addChild after
    let col = newColumn()
    col.addChild row
    col.bounds = Rect(x: 0, y: 0, width: 600, height: 200)
    col.layoutPass()
    let before = after.bounds.x
    label.text = "a much, much longer label than before"
    label.layoutDirty = true               # only the label is marked
    col.layoutPass()
    check after.bounds.x > before

  test "nothing dirty, nothing laid out again":
    let leaves = @[counted(10, 10), counted(20, 10)]
    let row = newRow()
    for l in leaves: row.addChild l
    row.bounds = Rect(x: 0, y: 0, width: 300, height: 40)
    row.layoutPass()
    row.layoutPass()
    for l in leaves: check l.calls == 1
