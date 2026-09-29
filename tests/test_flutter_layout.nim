## The Flutter layout model: vocabulary, arithmetic and every layout widget.
##
## Each case is what a Flutter developer would expect the same tree to do.

import std/[unittest, math]
import rui

proc box(w, h: float32): Widget =
  ## A leaf that insists on its size (a request beats what a parent assigns).
  newRectangle().frame(width = w, height = h)

proc leaf(w, h: float32): Widget =
  ## A leaf with a natural size that a parent may still override: an empty
  ## Padding measures as its insets.
  newPadding(padding = EdgeInsets.symmetric(horizontal = w / 2, vertical = h / 2))

suite "vocabulary":

  test "EdgeInsets constructors, spelled the Flutter way":
    check EdgeInsets.all(8) == EdgeInsets(left: 8, top: 8, right: 8, bottom: 8)
    check EdgeInsets.symmetric(horizontal = 16, vertical = 4) ==
          EdgeInsets(left: 16, right: 16, top: 4, bottom: 4)
    check EdgeInsets.only(left = 3) == EdgeInsets(left: 3)
    check EdgeInsets.fromLTRB(1, 2, 3, 4) == EdgeInsets(left: 1, top: 2, right: 3, bottom: 4)
    check EdgeInsets.all(8).horizontal == 16

  test "Alignment constants":
    check Alignment.topLeft == Alignment(x: -1, y: -1)
    check Alignment.bottomRight == Alignment(x: 1, y: 1)
    check alignmentOffset(Alignment.bottomRight, (100.0'f32, 40.0'f32)) == (100.0'f32, 40.0'f32)
    check alignmentOffset(Alignment.center, (100.0'f32, 40.0'f32)) == (50.0'f32, 20.0'f32)

  test "the enums read as Flutter's":
    check MainAxisAlignment.spaceBetween != MainAxisAlignment.`end`
    check $CrossAxisAlignment.stretch == "stretch"

suite "the restored arithmetic":

  test "calculateDistributedSpacing: every mode, with and without spacing":
    check calculateDistributedSpacing(MainAxisAlignment.start, 100, 40, 2, 0) == (0.0'f32, 0.0'f32)
    check calculateDistributedSpacing(MainAxisAlignment.center, 100, 40, 2, 0) == (0.0'f32, 30.0'f32)
    check calculateDistributedSpacing(MainAxisAlignment.`end`, 100, 40, 2, 0) == (0.0'f32, 60.0'f32)
    check calculateDistributedSpacing(MainAxisAlignment.spaceBetween, 100, 40, 2, 0) == (60.0'f32, 0.0'f32)
    check calculateDistributedSpacing(MainAxisAlignment.spaceAround, 100, 40, 2, 0) == (30.0'f32, 15.0'f32)
    check calculateDistributedSpacing(MainAxisAlignment.spaceEvenly, 100, 40, 2, 0) == (20.0'f32, 20.0'f32)
    # spacing is a floor the space-* modes add to, and center packs with it
    check calculateDistributedSpacing(MainAxisAlignment.center, 100, 40, 2, 10) == (10.0'f32, 25.0'f32)
    check calculateDistributedSpacing(MainAxisAlignment.spaceBetween, 100, 40, 2, 10) == (60.0'f32, 0.0'f32)

  test "calculateAlignmentOffset":
    check calculateAlignmentOffset(CrossAxisAlignment.center, 40, 10) == 15.0
    check calculateAlignmentOffset(CrossAxisAlignment.`end`, 40, 10) == 30.0
    check calculateAlignmentOffset(CrossAxisAlignment.stretch, 40, 10) == 0.0

  test "applyPadding / removePadding are inverses":
    let r = Rect(x: 10, y: 10, width: 100, height: 50)
    check removePadding(applyPadding(r, EdgeInsets.all(5)), EdgeInsets.all(5)) == r

  test "flexSizes: Expanded takes exactly its share, Flexible at most":
    check flexSizes([0.0'f32, 1, 2], [false, false, false], [30.0'f32, 999, 1], 90) ==
          @[30.0'f32, 30, 60]
    check flexSizes([1.0'f32, 1], [true, true], [10.0'f32, 80], 100) == @[10.0'f32, 50]
    check flexSizes([1.0'f32], [false], [40.0'f32], -1) == @[40.0'f32]   # unbounded

suite "Row and Column":

  test "a Row centres its children vertically by default":
    let r = newRow()
    r.bounds = Rect(x: 0, y: 0, width: 200, height: 40)
    let a = box(20, 10)
    r.addChild(a)
    r.layout()
    check a.bounds.y == 15.0

  test "mainAxisAlignment and spacing":
    let r = newRow(mainAxisAlignment = MainAxisAlignment.spaceBetween)
    r.bounds = Rect(x: 0, y: 0, width: 200, height: 20)
    let a = box(20, 10)
    let b = box(20, 10)
    r.addChild(a); r.addChild(b)
    r.layout()
    check a.bounds.x == 0.0
    check b.bounds.x + b.bounds.width == 200.0

    let e = newRow(mainAxisAlignment = MainAxisAlignment.`end`, spacing = 4)
    e.bounds = Rect(x: 0, y: 0, width: 100, height: 20)
    let c = box(10, 10)
    let d = box(10, 10)
    e.addChild(c); e.addChild(d)
    e.layout()
    check d.bounds.x == 90.0 and c.bounds.x == 76.0

  test "MainAxisSize.min shrinks to the children even when given room":
    let c = newColumn(mainAxisSize = MainAxisSize.min)
    c.bounds = Rect(x: 0, y: 0, width: 100, height: 400)
    c.addChild(box(10, 30))
    c.layout()
    check c.bounds.height == 30.0

  test "CrossAxisAlignment.stretch fills the cross axis":
    let c = newColumn(crossAxisAlignment = CrossAxisAlignment.stretch)
    c.bounds = Rect(x: 0, y: 0, width: 150, height: 100)
    let l = newLabel(text = "x", fontSize = 14.0)
    c.addChild(l)
    c.layout()
    check l.bounds.width == 150.0

  test "the reported type is the name it was built with":
    check newRow().getTypeName() == "Row"
    check newColumn().getTypeName() == "Column"
    check newVStack().getTypeName() == "VStack"

suite "Expanded, Flexible, Spacer":

  test "Expanded splits the spare room by flex, whatever its content":
    let r = newRow()
    r.bounds = Rect(x: 0, y: 0, width: 300, height: 20)
    let fixed = box(60, 10)
    let one = newExpanded(flex = 1)
    one.addChild(newLabel(text = "a much longer label than its share", fontSize = 14.0))
    let two = newExpanded(flex = 2)
    two.addChild(box(5, 10))
    for w in [fixed, Widget(one), two]: r.addChild(w)
    r.layout()
    check one.bounds.width == 80.0 and two.bounds.width == 160.0
    check two.bounds.x + two.bounds.width == 300.0
    check one.children[0].bounds.width == 80.0         # the child fills it

  test "Flexible takes no more than its child needs":
    let r = newRow()
    r.bounds = Rect(x: 0, y: 0, width: 300, height: 20)
    let f = newFlexible()
    f.addChild(box(40, 10))
    r.addChild(f)
    r.layout()
    check f.bounds.width == 40.0

  test "Spacer pushes its neighbours apart":
    let r = newRow()
    r.bounds = Rect(x: 0, y: 0, width: 200, height: 20)
    let a = box(20, 10)
    let b = box(20, 10)
    r.addChild(a); r.addChild(newSpacer()); r.addChild(b)
    r.layout()
    check b.bounds.x == 180.0

suite "boxes":

  test "Padding":
    let p = newPadding(padding = EdgeInsets.all(10))
    let c = box(30, 20)
    p.addChild(c)
    p.layout()
    check p.bounds.width == 50.0 and p.bounds.height == 40.0
    check c.bounds.x == 10.0

  test "SizedBox as a gap, and as a fixed size":
    let gap = newSizedBox(height = 12)
    gap.layout()
    check gap.bounds.height == 12.0
    let s = newSizedBox(width = 80, height = 30)
    let l = newLabel(text = "hi", fontSize = 14.0)
    s.addChild(l)
    let col = newColumn(crossAxisAlignment = CrossAxisAlignment.stretch)
    col.bounds = Rect(x: 0, y: 0, width: 300, height: 100)
    col.addChild(s)
    col.layout()
    check s.bounds.width == 80.0                 # beats stretch
    check l.bounds.width == 80.0 and l.bounds.height == 30.0

  test "ConstrainedBox":
    let c = newConstrainedBox(constraints = BoxConstraints(minWidth: 100, maxHeight: 10))
    c.addChild(box(20, 40))
    c.layout()
    check c.bounds.width == 100.0 and c.bounds.height == 10.0

  test "Align and Center":
    let a = newAlign(alignment = Alignment.bottomRight).frame(width = 100, height = 50)
    let c = box(10, 10)
    a.addChild(c)
    a.layout()
    check c.bounds.x == 90.0 and c.bounds.y == 40.0
    let ce = newCenter().frame(width = 100, height = 50)
    let d = box(10, 10)
    ce.addChild(d)
    ce.layout()
    check d.bounds.x == 45.0 and d.bounds.y == 20.0

  test "Container: size, padding, margin, alignment":
    let k = newContainer(width = 100, height = 60, padding = EdgeInsets.all(5),
                         margin = EdgeInsets.all(10), alignment = some(Alignment.center))
    let c = box(20, 10)
    k.addChild(c)
    k.layout()
    check k.bounds.width == 120.0 and k.bounds.height == 80.0
    check c.bounds.x == 50.0 and c.bounds.y == 35.0

suite "Stack and Positioned":

  test "a Stack is as big as its largest plain child":
    let s = newStack()
    s.addChild(box(80, 30))
    s.addChild(box(40, 50))
    s.layout()
    check s.bounds.width == 80.0 and s.bounds.height == 50.0

  test "Positioned pins by its edges, and stretches between two":
    let s = newStack().frame(width = 200, height = 100)
    let p1 = newPositioned(right = 10, bottom = 10)
    p1.addChild(box(20, 20))
    let p2 = newPositioned(left = 10, right = 10, top = 0)
    p2.addChild(box(5, 5))
    s.addChild(p1); s.addChild(p2)
    s.layout()
    check p1.bounds.x == 170.0 and p1.bounds.y == 70.0
    check p2.bounds.width == 180.0

  test "ZStack layers fill it":
    let z = newZStack().frame(width = 100, height = 40)
    let c = leaf(10, 10)
    z.addChild(c)
    z.layout()
    check c.bounds.width == 100.0 and c.bounds.height == 40.0

suite "Wrap, Table, GridView, Dock":

  test "lineBreaks":
    check lineBreaks([40.0'f32, 40, 40, 40], 100.0, 10.0) == @[0, 2]
    check lineBreaks([150.0'f32, 20], 100.0, 10.0) == @[0, 1]

  test "Wrap runs, centred":
    let w = newWrap(spacing = 4, runSpacing = 4, alignment = MainAxisAlignment.center)
    w.bounds = Rect(x: 0, y: 0, width: 100, height: 0)
    var kids: seq[Widget]
    for i in 0 ..< 3:
      kids.add box(40, 20)
      w.addChild(kids[^1])
    w.layout()
    check kids[2].bounds.y == 24.0
    check kids[2].bounds.x == 30.0            # alone on its run, centred
    check w.bounds.height == 44.0

  test "Table: intrinsic and flex columns, rows centred":
    let t = newTable(columnWidths = @[IntrinsicColumnWidth(), FlexColumnWidth()])
    t.bounds = Rect(x: 0, y: 0, width: 300, height: 0)
    let r1 = newTableRow()
    let lbl = leaf(40, 10)
    let field = leaf(10, 30)
    r1.addChild(lbl); r1.addChild(field)
    t.addChild(r1)
    t.layout()
    check field.bounds.x == 40.0 and field.bounds.width == 260.0
    check lbl.bounds.y == 10.0                 # middle of a 30-high row
    check t.bounds.height == 30.0

  test "GridView.count":
    let g = newGridView(crossAxisCount = 3, crossAxisSpacing = 10, mainAxisSpacing = 10,
                        childAspectRatio = 2.0)
    g.bounds = Rect(x: 0, y: 0, width: 320, height: 0)
    var kids: seq[Widget]
    for i in 0 ..< 4:
      kids.add leaf(1, 1)
      g.addChild(kids[^1])
    g.layout()
    check kids[0].bounds.width == 100.0 and kids[0].bounds.height == 50.0
    check kids[3].bounds.x == 0.0 and kids[3].bounds.y == 60.0
    check g.bounds.height == 110.0

  test "Dock: top, bottom, left, and the rest filled":
    let d = newDock().frame(width = 400, height = 300)
    let top = newDocked(side = DockSide.top)
    top.addChild(box(1, 30))
    let bottom = newDocked(side = DockSide.bottom)
    bottom.addChild(box(1, 20))
    let left = newDocked(side = DockSide.left)
    left.addChild(box(100, 1))
    let body = box(1, 1)
    body.sizeRequest = Size()                  # let the dock size it
    for w in [Widget(top), bottom, left, body]: d.addChild(w)
    d.layout()
    check top.bounds.width == 400.0 and top.bounds.y == 0.0
    check bottom.bounds.y == 280.0
    check left.bounds.height == 250.0
    check body.bounds.x == 100.0 and body.bounds.width == 300.0 and body.bounds.height == 250.0

suite "in a ui: tree":

  test "Flutter code, nearly verbatim":
    var name: TextArea
    let root = ui:
      Column(crossAxisAlignment = CrossAxisAlignment.stretch, spacing = 8.0):
        Row(mainAxisAlignment = MainAxisAlignment.spaceBetween):
          Label(text = "Title", fontSize = 14.0)
          Label(text = "x", fontSize = 14.0)
        Padding(padding = EdgeInsets.symmetric(horizontal = 16)):
          name = TextInput()
        Expanded():
          TextArea()
    root.bounds = Rect(x: 0, y: 0, width: 300, height: 400)
    root.layout()
    check root.getTypeName() == "Column"
    check name.bounds.x == 16.0 and name.bounds.width == 268.0
    let area = root.children[2]
    check area.bounds.y + area.bounds.height == 400.0   # Expanded to the bottom
