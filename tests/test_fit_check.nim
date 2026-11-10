## fit_check.nim: what does not fit the screen, found in a laid-out tree.

import std/[unittest, strutils]
import rui
import fit_check

proc place(root: Widget, w, h: float32) =
  discard root.measure(tight(w, h))
  root.arrange(Rect(x: 0, y: 0, width: w, height: h))

proc kinds(issues: seq[FitIssue]): seq[FitKind] =
  for i in issues: result.add i.kind

suite "fit check":
  test "a layout that fits reports nothing":
    let root = ui:
      Column(crossAxisAlignment = CrossAxisAlignment.stretch, spacing = 8.0):
        Label(text = "Title")
        Container(color = Color(r: 200, g: 200, b: 200, a: 255)).frame(height = 40)
    place(root, 360, 640)
    check fitIssues(root, Rect(width: 360, height: 640)).len == 0

  test "a Row too wide for the screen overflows, once, where it starts":
    let root = ui:
      Column():
        Row():
          SizedBox(width = 300, height = 20)
          SizedBox(width = 300, height = 20)
    place(root, 360, 640)
    let issues = fitIssues(root, Rect(width: 360, height: 640))
    check issues.kinds == @[fkOffscreen]
    check issues[0].path.endsWith("SizedBox")
    check "right" in issues[0].detail and issues[0].by >= 239

  test "a child sticking out of its parent (inside the screen) is an overflow":
    let inner = newSizedBox(width = 100, height = 20).ownSize
    let slot = newSizedBox(width = 50, height = 20)
    slot.addChild inner
    let root = newCenter()
    root.addChild slot
    place(root, 360, 640)
    let issues = fitIssues(root, Rect(width: 360, height: 640))
    check fkOverflow in issues.kinds

  test "what a scroll view clips is not a problem":
    let col = newColumn()
    for i in 0 ..< 40: col.addChild newSizedBox(width = 100, height = 40)
    let sv = newScrollView(padding = 0)
    sv.addChild col
    place(sv, 360, 640)
    check fitIssues(sv, Rect(width: 360, height: 640)).len == 0

  test "a label without room for its text is cut; a wrapping one with lines is not":
    let cut = newLabel(text = "A rather long caption that will not fit")
    let box = newSizedBox(width = 80)
    box.addChild cut
    let wraps = newLabel(text = "A rather long caption that will wrap", wrap = true)
    let root = newColumn(crossAxisAlignment = CrossAxisAlignment.start)
    root.addChild box
    root.addChild wraps.frame(width = 80)
    place(root, 360, 640)
    let issues = fitIssues(root, Rect(width: 360, height: 640))
    check issues.kinds == @[fkCut]
    check "text needs" in issues[0].detail
    check cut.bounds.width == 80                     # the check left the layout as it was

  test "small tap targets are warnings":
    let root = newColumn()
    root.addChild newButton(text = "OK")
    place(root, 360, 640)
    let issues = fitIssues(root, Rect(width: 360, height: 640), touchTarget = 48)
    check issues.kinds == @[fkSmallTarget]
    check not issues[0].isError
    check fitReport(root, Rect(width: 360, height: 640), 48)["warnings"].getInt == 1

  test "hidden things are not checked":
    let root = newColumn()
    root.addChild newSizedBox(width = 1000, height = 20).showIf(false)
    place(root, 360, 640)
    check fitIssues(root, Rect(width: 360, height: 640)).len == 0

  test "a list wider than its scroll view scrolls sideways; wrapToWidth fits it":
    proc list(wrap: bool): ScrollView =
      let col = newColumn(crossAxisAlignment = CrossAxisAlignment.stretch)
      col.addChild newLabel(text = "A row whose text is wider than a small phone's screen")
      result = newScrollView(padding = 0, wrapToWidth = wrap)
      result.addChild col
    let loose = list(false)
    place(loose, 200, 400)
    check fitIssues(loose, Rect(width: 200, height: 400)).kinds == @[fkSideways]
    let fitted = list(true)
    place(fitted, 200, 400)
    check fitIssues(fitted, Rect(width: 200, height: 400)).kinds == @[fkCut]
