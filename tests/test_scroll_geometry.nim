## Scrollbar geometry — which bars appear, and where their thumbs sit
##
## ScrollView's `layout` and `render` each worked this out for themselves from
## the same four numbers, and disagreed: layout clamped the scroll offsets
## against a viewport reduced by both scrollbars, render sized the thumbs
## against one reduced by neither.

import std/unittest
import containers/scroll_geometry
import rui
import std/monotimes

proc extent(cw, ch, vw, vh: float32, sb = 16.0'f32): ScrollExtent =
  ScrollExtent(contentWidth: cw, contentHeight: ch,
               viewportWidth: vw, viewportHeight: vh, scrollbarWidth: sb)

suite "which scrollbars appear":

  test "content that fits needs neither":
    let b = scrollBarsFor(extent(100, 100, 200, 200))
    check not b.vertical
    check not b.horizontal
    check b.innerWidth == 200.0
    check b.innerHeight == 200.0

  test "tall content needs a vertical bar":
    let b = scrollBarsFor(extent(100, 500, 200, 200))
    check b.vertical
    check not b.horizontal
    check b.innerWidth == 184.0      # 200 - 16

  test "wide content needs a horizontal bar":
    let b = scrollBarsFor(extent(500, 100, 200, 200))
    check b.horizontal
    check not b.vertical
    check b.innerHeight == 184.0

  test "content bigger both ways needs both":
    let b = scrollBarsFor(extent(500, 500, 200, 200))
    check b.vertical
    check b.horizontal
    check b.innerWidth == 184.0
    check b.innerHeight == 184.0

  test "a vertical bar can create the need for a horizontal one":
    # 195 wide fits in a 200 viewport -- until the vertical bar takes 16 off it.
    # Decided independently, as the old code did, this content got no
    # horizontal scrollbar and its right-hand edge was unreachable.
    let b = scrollBarsFor(extent(195, 500, 200, 200))
    check b.vertical
    check b.horizontal

  test "a horizontal bar can create the need for a vertical one":
    let b = scrollBarsFor(extent(500, 195, 200, 200))
    check b.horizontal
    check b.vertical

  test "content that fits with room to spare is not caught by the second pass":
    let b = scrollBarsFor(extent(150, 500, 200, 200))
    check b.vertical
    check not b.horizontal

suite "how far it scrolls":

  test "content that fits does not scroll":
    let e = extent(100, 100, 200, 200)
    let b = scrollBarsFor(e)
    check e.maxScrollX(b) == 0.0
    check e.maxScrollY(b) == 0.0

  test "the travel is measured against the viewport the bars left":
    let e = extent(100, 500, 200, 200)
    let b = scrollBarsFor(e)
    check e.maxScrollY(b) == 300.0      # 500 - 200, no horizontal bar
    check b.innerWidth == 184.0

  test "a horizontal bar shortens the vertical travel":
    let e = extent(500, 500, 200, 200)
    let b = scrollBarsFor(e)
    check e.maxScrollY(b) == 316.0      # 500 - (200 - 16)

suite "thumb size":

  test "half the content visible is half the track":
    check thumbLength(200.0, 100.0, 200.0) == 100.0

  test "a long document still has a grabbable thumb":
    check thumbLength(200.0, 10.0, 100_000.0) == MinThumb

  test "all the content visible fills the track":
    check thumbLength(200.0, 200.0, 200.0) == 200.0

  test "more view than content does not overflow the track":
    check thumbLength(200.0, 400.0, 200.0) == 200.0

  test "zero content is a full track, not a division by zero":
    check thumbLength(200.0, 100.0, 0.0) == 200.0

suite "thumb position":

  test "unscrolled is at the start":
    check thumbOffset(200.0, 50.0, 0.0, 300.0) == 0.0

  test "fully scrolled ends flush with the track, not past it":
    # Measured against the free travel (track - thumb), not the whole track.
    # Against the whole track the thumb hangs off the end by its own length.
    check thumbOffset(200.0, 50.0, 300.0, 300.0) == 150.0

  test "half scrolled is half the free travel":
    check thumbOffset(200.0, 50.0, 150.0, 300.0) == 75.0

  test "nothing to scroll parks it at the start":
    check thumbOffset(200.0, 200.0, 0.0, 0.0) == 0.0

  test "an out-of-range offset is clamped, not extrapolated":
    check thumbOffset(200.0, 50.0, 9999.0, 300.0) == 150.0
    check thumbOffset(200.0, 50.0, -50.0, 300.0) == 0.0

suite "scroll view scrollbars":
  proc send(w: Widget, e: GuiEvent): bool =
    var e = e
    e.timestamp = getMonoTime()
    w.handleInput(e)

  proc tall(): tuple[sv: ScrollView, col: Flex] =
    let sv = newScrollView()
    let col = newVStack(spacing = 0)
    for i in 0 ..< 60: col.addChild newRectangle().frame(width = 400, height = 20)
    sv.addChild col
    sv.bounds = Rect(x: 0, y: 0, width: 200, height: 200)
    sv.layoutPass()
    sv.layoutPass()            # the second pass sees the content size
    (sv, col)

  test "the wheel scrolls down, Shift+wheel across, and the end passes it on":
    let (sv, _) = tall()
    check sv.send(GuiEvent(kind: evMouseWheel, wheelDelta: -1))
    check sv.scrollOffsetY == 20
    check sv.send(GuiEvent(kind: evMouseWheel, wheelDelta: -1, mods: {kmShift}))
    check sv.scrollOffsetX == 20
    check sv.send(GuiEvent(kind: evMouseWheel, wheelDelta: 1, mods: {kmShift}))
    check sv.scrollOffsetX == 0
    check not sv.send(GuiEvent(kind: evMouseWheel, wheelDelta: 1, mods: {kmShift}))
    sv.scrollOffsetY = 0
    check not sv.send(GuiEvent(kind: evMouseWheel, wheelDelta: 1))   # already at the top

  test "dragging the vertical thumb to the bottom shows the end":
    let (sv, _) = tall()
    let g = sv.barGeometry(true)
    let x = g.thumb.x + g.thumb.width / 2
    check sv.send(GuiEvent(kind: evMouseDown, mousePos: Point(x: x, y: g.thumb.y + 2)))
    discard sv.send(GuiEvent(kind: evMouseMove, mousePos: Point(x: x, y: 10_000)))
    check sv.scrollOffsetY == g.maxScroll
    discard sv.send(GuiEvent(kind: evMouseUp, mousePos: Point(x: x, y: 10_000)))
    check sv.dragAxis == 0

  test "a press on the track below the thumb moves a page down":
    let (sv, _) = tall()
    let g = sv.barGeometry(true)
    let x = g.thumb.x + g.thumb.width / 2
    check sv.send(GuiEvent(kind: evMouseDown,
                           mousePos: Point(x: x, y: g.track.y + g.track.height - 2)))
    check sv.scrollOffsetY > 100

  test "in a running app a press on the scroll bar reaches the scroll view":
    let (sv, _) = tall()
    let app = newApp(title = "sv", width = 200, height = 200)
    let source = newListEventSource()
    app.eventSource = source
    app.setRootWidget(sv)
    app.stepHeadless()
    app.stepHeadless()
    let g = sv.barGeometry(true)
    let x = g.thumb.x + g.thumb.width / 2
    for kind in [evMouseDown, evMouseUp]:
      source.push GuiEvent(kind: kind, timestamp: getMonoTime(),
                           mousePos: Point(x: x, y: g.track.y + g.track.height - 2))
    app.stepHeadless()
    check sv.scrollOffsetY > 100
