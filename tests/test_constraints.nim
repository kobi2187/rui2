## Flutter's constraint rules: the parent always wins, constraints can be
## loose ("up to"), and what wants to fill fills the room it is allowed. The
## same cases, and many more, are checked against Flutter itself by
## mobile/layout_conformance/; these keep the rules from drifting in CI.

import std/[unittest, math]
import rui

proc box(w, h: float32): Widget = newSizedBox(width = w, height = h)

proc place(root: Widget, w, h: float32) =
  ## Lay `root` out as the root of a w x h window: tight, as Flutter's root.
  discard root.measure(tight(w, h))
  root.arrange(Rect(x: 0, y: 0, width: w, height: h))

suite "constraints":
  test "enforce: the parent's range wins over the child's wishes":
    let own = Constraints(minWidth: 50, maxWidth: 50, minHeight: 0, maxHeight: Inf)
    let parent = Constraints(minWidth: 0, maxWidth: 30, minHeight: 10, maxHeight: 20)
    let e = own.enforce(parent)
    check e.minWidth == 30 and e.maxWidth == 30
    check e.minHeight == 10 and e.maxHeight == 20

  test "loosen keeps the maxima and drops the minima":
    let l = tight(100, 40).loosen()
    check l.minWidth == 0 and l.maxWidth == 100 and l.minHeight == 0 and l.maxHeight == 40

  test "deflate shrinks min and max by the padding, never below 0":
    let d = Constraints(minWidth: 10, maxWidth: 100, maxHeight: Inf).deflate(EdgeInsets.all(8))
    check d.minWidth == 0 and d.maxWidth == 84 and d.maxHeight == Inf

suite "a requested size is a wish within the parent's constraints":
  test "frame and SizedBox are cut to a tight parent":
    check newLabel(text = "x").frame(width = 500).measure(tight(100, 20)).width == 100
    check box(500, 500).measure(loose(100, 60)) == Size(width: 100, height: 60)

  test "SizedBox: NaN is unset, 0 is zero, Inf is as big as allowed":
    check box(0, 0).measure(loose(100, 60)) == Size()
    check newSizedBox(width = Inf, height = Inf).measure(loose(100, 60)) ==
          Size(width: 100, height: 60)
    let s = newSizedBox(width = 40)
    s.addChild newSizedBox(width = 10, height = 25)
    check s.measure(loose(100, 60)) == Size(width: 40, height: 25)
    check newSizedBox(width = Inf).measure(unbounded()).width == 0   # nothing to expand into

  test "ConstrainedBox limits apply within the parent's":
    let c = newConstrainedBox(constraints = Constraints(minWidth: 100, minHeight: 60))
    c.addChild box(20, 20)
    check c.measure(loose(300, 200)) == Size(width: 100, height: 60)
    check c.measure(tight(50, 50)) == Size(width: 50, height: 50)

suite "loose constraints: what wants to fill, fills":
  test "a max-size Row in a Center is as wide as the Center allows":
    let r = newRow()
    r.addChild box(40, 30)
    let c = newCenter()
    c.addChild r
    place(c, 300, 200)
    check r.bounds.width == 300 and r.bounds.height == 30

  test "an empty Container fills a Center; with a child it is the child":
    let empty = newContainer()
    let c = newCenter()
    c.addChild empty
    place(c, 300, 200)
    check empty.bounds.width == 300 and empty.bounds.height == 200
    let wrapped = newContainer(padding = EdgeInsets.all(5))
    wrapped.addChild box(40, 30)
    check wrapped.measure(loose(300, 200)) == Size(width: 50, height: 40)

  test "Align fills a bounded parent, and shrinks by its factors":
    let a = newAlign(alignment = Alignment.bottomRight)
    let b = box(40, 30)
    a.addChild b
    place(a, 300, 200)
    check b.bounds.x == 260 and b.bounds.y == 170
    let f = newAlign(widthFactor = 2, heightFactor = 1.5)
    f.addChild box(40, 30)
    check f.measure(loose(300, 200)) == Size(width: 80, height: 45)

  test "text wraps at the width a Column allows it":
    let label = newLabel(text = "Layout wraps text at the width its parent allows, not the screen's",
                         wrap = true)
    let col = newColumn(crossAxisAlignment = CrossAxisAlignment.start)
    col.addChild label
    place(col, 200, 300)
    check label.bounds.width <= 200
    check label.bounds.height > label.measure(unbounded()).height   # more than one line

  test "an Expanded's filler fills the Row's height":
    let fill = newContainer()
    let e = newExpanded()
    e.addChild fill
    let r = newRow()
    r.addChild e
    place(r, 300, 200)
    check fill.bounds.width == 300 and fill.bounds.height == 200

  test "a Positioned pinned at both edges sizes its child":
    let b = box(40, 30)
    let p = newPositioned(left = 10, right = 10, top = 5)
    p.addChild b
    let s = newStack()
    s.addChild newContainer()
    s.addChild p
    place(s, 300, 200)
    check b.bounds.x == 10 and b.bounds.width == 280 and b.bounds.height == 30

suite "stretch: Flutter's for Row/Column, CSS's for VStack/HStack":
  test "Column stretches a sized child; VStack keeps its size and max":
    let inCol = box(80, 20)
    let col = newColumn(crossAxisAlignment = CrossAxisAlignment.stretch)
    col.addChild inCol
    place(col, 300, 100)
    check inCol.bounds.width == 300
    let inV = box(80, 20)
    let capped = newLabel(text = "x").frame(maxWidth = 150)
    let v = newVStack()
    v.addChild inV
    v.addChild capped
    place(v, 300, 100)
    check inV.bounds.width == 80
    check capped.bounds.width == 150

suite "the constraint boxes":
  test "UnconstrainedBox: the child keeps its size inside a stretch":
    let b = box(40, 20)
    let u = newUnconstrainedBox()
    u.addChild b
    let r = newRow(crossAxisAlignment = CrossAxisAlignment.stretch)
    r.addChild u
    place(r, 300, 100)
    check b.bounds.width == 40 and b.bounds.height == 20
    check u.bounds.height == 100

  test "OverflowBox: the child under its own limits; the box as big as allowed":
    let b = newContainer()
    let o = newOverflowBox(maxWidth = 200, maxHeight = 200)
    o.addChild b
    let s = newSizedBox(width = 50, height = 50)
    s.addChild o
    let c = newCenter()
    c.addChild s
    place(c, 300, 300)
    check o.bounds.width == 50 and b.bounds.width == 200 and b.bounds.x == 50

  test "LimitedBox only limits where the parent has no limit":
    let l = newLimitedBox(maxHeight = 80)
    l.addChild newContainer()
    check l.measure(Constraints(maxWidth: 300, maxHeight: Inf)).height == 80
    check l.measure(loose(300, 50)).height == 50

  test "AspectRatio: as big as allowed at the ratio":
    let a = newAspectRatio(aspectRatio = 2)
    check a.measure(loose(300, 200)) == Size(width: 300, height: 150)
    check a.measure(loose(300, 100)) == Size(width: 200, height: 100)

  test "FractionallySizedBox: a share of the parent's room":
    let f = newFractionallySizedBox(widthFactor = 0.5, heightFactor = 0.25)
    f.addChild newContainer()
    check f.measure(tight(300, 200)) == Size(width: 300, height: 200)
    place(f, 300, 200)
    check f.children[0].bounds.width == 150 and f.children[0].bounds.height == 50

  test "IntrinsicHeight makes a stretched sibling as tall as the tallest":
    let rule = newContainer(width = 4)
    let r = newRow(crossAxisAlignment = CrossAxisAlignment.stretch)
    r.addChild box(40, 30)
    r.addChild rule
    r.addChild box(40, 60)
    let ih = newIntrinsicHeight()
    ih.addChild r
    let c = newCenter()
    c.addChild ih
    place(c, 300, 200)
    check rule.bounds.height == 60

  test "Offstage takes no room; Visibility can keep it":
    check newOffstage().measure(loose(100, 100)) == Size()
    let gone = newVisibility(shown = false)
    gone.addChild box(40, 30)
    check gone.measure(loose(100, 100)) == Size()
    let kept = newVisibility(shown = false, maintainSize = true)
    kept.addChild box(40, 30)
    check kept.measure(loose(100, 100)) == Size(width: 40, height: 30)
