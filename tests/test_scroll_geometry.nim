## Scrollbar geometry — which bars appear, and where their thumbs sit
##
## ScrollView's `layout` and `render` each worked this out for themselves from
## the same four numbers, and disagreed: layout clamped the scroll offsets
## against a viewport reduced by both scrollbars, render sized the thumbs
## against one reduced by neither.

import std/unittest
import containers/scroll_geometry

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
