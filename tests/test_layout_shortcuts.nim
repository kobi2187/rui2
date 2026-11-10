## The layout shortcuts (rui_widgets/layout/shortcuts.nim) build what their
## long Flutter names build, and lay out the same, in `ui:` and in code.

import std/[unittest, math]
import rui

proc place(root: Widget, w, h: float32) =
  discard root.measure(tight(w, h))
  root.arrange(Rect(x: 0, y: 0, width: w, height: h))

proc box(w, h: float32): Widget = newSizedBox(width = w, height = h)

suite "layout shortcuts":
  test "each modifier wraps the widget in its Flutter box":
    check box(1, 1).center of Center
    check box(1, 1).align(Alignment.topRight) of Align
    check box(1, 1).ownSize of UnconstrainedBox
    check box(1, 1).overflow(maxWidth = 9) of OverflowBox
    check box(1, 1).limit(height = 9) of LimitedBox
    check box(1, 1).aspect(2) of AspectRatio
    check box(1, 1).fraction(width = 0.5) of FractionallySizedBox
    check box(1, 1).sameHeight of IntrinsicHeight
    check box(1, 1).sameWidth of IntrinsicWidth
    check box(1, 1).showIf(false) of Visibility
    check box(1, 1).offstage of Offstage
    check box(1, 1).at(left = 1) of Positioned
    check box(1, 1).cover of Positioned
    let b = box(1, 1)
    check b.center.children[0] == b

  test "in ui:, a shortcut's wrapper goes in the tree and a block goes to the widget":
    let root = ui:
      Column(crossAxisAlignment = CrossAxisAlignment.stretch):
        Row(crossAxisAlignment = CrossAxisAlignment.stretch).sameHeight:
          SizedBox(width = 40, height = 30)
          SizedBox(width = 40, height = 60)
        Gap(12)
        SizedBox(width = 80, height = 20).ownSize
    check root.children[0] of IntrinsicHeight
    check root.children[0].children[0].children.len == 2
    check root.children[1] of SizedBox
    check root.children[2] of UnconstrainedBox

  test "the short constructors take a child block":
    let root = ui:
      Stack():
        Ratio(2.0):
          Container()
        At(right = 8, top = 8):
          SizedBox(width = 20, height = 20)
        SameWidth():
          Column(crossAxisAlignment = CrossAxisAlignment.stretch)
        Fraction(width = 0.5):
          Container()
        Limit(height = 10):
          Container()
        ShowIf(false, keepSize = true):
          Container()
        OwnSize():
          Container()
    check root.children[0] of AspectRatio and root.children[0].children.len == 1
    check root.children[1] of Positioned
    check root.children[2] of IntrinsicWidth
    check root.children[3] of FractionallySizedBox
    check root.children[4] of LimitedBox
    check root.children[5] of Visibility
    check root.children[6] of UnconstrainedBox

  test "shortcuts lay out as their long forms":
    let kept = box(80, 20)
    let col = newColumn(crossAxisAlignment = CrossAxisAlignment.stretch)
    col.addChild kept.ownSize
    place(col, 300, 100)
    check kept.bounds.width == 80                      # not stretched

    let badge = box(20, 20)
    let s = newStack()
    s.addChild newContainer().cover
    s.addChild badge.at(right = 8, top = 8)
    place(s, 300, 200)
    check badge.bounds.x == 272 and badge.bounds.y == 8

    let pic = newContainer()
    let c = newColumn()
    c.addChild pic.aspect(2)
    place(c, 300, 400)
    check pic.bounds.width == 300 and pic.bounds.height == 150

    let half = newContainer()
    place(half.fraction(width = 0.5, height = 0.25), 300, 200)
    check half.bounds.width == 150 and half.bounds.height == 50

    let corner = box(40, 30)
    place(corner.align(1, 1), 300, 200)
    check corner.bounds.x == 260 and corner.bounds.y == 170

  test "Gap spaces a Row and a Column":
    let r = newRow()
    r.addChild box(10, 10)
    r.addChild newGap(12)
    let after = box(10, 10)
    r.addChild after
    place(r, 300, 100)
    check after.bounds.x == 22

  test "flexible takes at most its share, flex exactly":
    let small = box(30, 10).flexible
    let grows = newContainer().flex
    let r = newRow()
    r.addChild small
    r.addChild grows
    place(r, 300, 50)
    check small.bounds.width == 30
    check grows.bounds.width == 150
