## Viewport culling, against a real GL context (run under Xvfb: tools/run_tests.sh
## does). Widgets wholly outside the window and its scroll areas must not be
## painted, must be painted when they scroll into view, and the scroll area's
## own texture must show them -- read back from the GPU, because the logic that
## can go wrong here is "culled, then never re-composited".

import rui
import raylib
import std/[options, unittest]

initWindow(420, 320, "culling")
setTraceLogLevel(TraceLogLevel.Error)
setCurrentTheme(brandTheme(daylightSpec()))

const Rows = 80

proc build(): tuple[sv: ScrollView, labels: seq[Label]] =
  let sv = newScrollView()
  let col = newVStack(spacing = 0.0)
  var labels: seq[Label]
  for i in 0 ..< Rows:
    let l = newLabel(text = "row number " & $i)
    labels.add l
    col.addChild l
  sv.addChild col
  sv.bounds = Rect(x: 0, y: 0, width: 420, height: 320)
  sv.layout()
  (sv, labels)

proc inkIn(sv: ScrollView, r: Rect): bool =
  ## Whether the scroll view's texture has any painted pixel inside `r`
  ## (in window space). The texture is stored upside down.
  let img = loadImageFromTexture(sv.cachedTexture.get().texture)
  let h = img.height
  for y in max(0, r.y.int) ..< min(h.int, (r.y + r.height).int):
    for x in max(0, r.x.int) ..< min(img.width.int, (r.x + r.width).int):
      if getImageColor(img, x.int32, (h - 1 - y).int32).a > 0:
        return true

suite "viewport culling":

  test "overlapsView":
    let view = Rect(x: 0, y: 0, width: 100, height: 100)
    check overlapsView(Rect(x: 50, y: 50, width: 10, height: 10), view)
    check overlapsView(Rect(x: 90, y: 90, width: 50, height: 50), view)
    check not overlapsView(Rect(x: 100, y: 0, width: 10, height: 10), view)  # only touching
    check not overlapsView(Rect(x: 0, y: -20, width: 10, height: 20), view)

  test "off-screen rows are skipped, then painted when scrolled in":
    let (sv, labels) = build()
    renderView = some(Rect(x: 0, y: 0, width: 420, height: 320))
    defer: renderView = none(Rect)

    sv.renderPass()
    check labels[0].cachedTexture.isSome and not labels[0].culled
    check labels[Rows - 1].culled
    check labels[Rows - 1].cachedTexture.isNone          # never painted
    check not sv.anyChildDirty()                         # and not "dirty" forever
    check inkIn(sv, labels[0].bounds)

    # Scroll to the bottom: layout moves the rows, the scroll view repaints.
    sv.scrollOffsetY = 100000
    sv.layoutDirty = true
    sv.layoutPass()
    sv.isDirty = true
    sv.renderPass()
    check labels[0].culled
    check not labels[Rows - 1].culled
    check labels[Rows - 1].cachedTexture.isSome
    check inkIn(sv, labels[Rows - 1].bounds)             # composited into view

  test "widgets that are visible are painted exactly as without culling":
    let (a, _) = build()
    a.renderPass()                                       # no renderView: all
    let (b, _) = build()
    renderView = some(Rect(x: 0, y: 0, width: 420, height: 320))
    defer: renderView = none(Rect)
    b.renderPass()
    let ia = loadImageFromTexture(a.cachedTexture.get().texture)
    let ib = loadImageFromTexture(b.cachedTexture.get().texture)
    var differing = 0
    for y in 0 ..< 320:
      for x in 0 ..< 420:
        if getImageColor(ia, x.int32, y.int32) != getImageColor(ib, x.int32, y.int32):
          inc differing
    check differing == 0
