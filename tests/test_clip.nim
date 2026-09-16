## Clipping composited children by source rectangle
##
## A container whose viewport is smaller than its own bounds -- ScrollView, with
## padding and scrollbars to keep clear -- needs its children clipped to the
## viewport rather than to the whole widget. The arithmetic is here; the GL side
## is exercised by the Xvfb harness.
##
## Not done with raylib's BeginScissorMode, which computes its rectangle from
## the *screen* height and so clips the wrong region inside beginTextureMode.

import std/unittest
import rui

suite "rectangle intersection":

  test "overlapping rectangles give the overlap":
    let a = Rect(x: 0, y: 0, width: 100, height: 100)
    let b = Rect(x: 50, y: 50, width: 100, height: 100)
    let r = intersect(a, b)
    check r.x == 50.0
    check r.y == 50.0
    check r.width == 50.0
    check r.height == 50.0

  test "a contained rectangle gives itself back":
    let outer = Rect(x: 0, y: 0, width: 100, height: 100)
    let inner = Rect(x: 20, y: 30, width: 10, height: 10)
    check intersect(outer, inner) == inner
    check intersect(inner, outer) == inner

  test "disjoint rectangles give zero size, not a negative one":
    # The caller's test for "nothing to draw" is width <= 0, so this must not
    # come back negative and read as a very wide rectangle somewhere downstream.
    let a = Rect(x: 0, y: 0, width: 10, height: 10)
    let b = Rect(x: 100, y: 100, width: 10, height: 10)
    let r = intersect(a, b)
    check r.width == 0.0
    check r.height == 0.0

  test "touching edges overlap by nothing":
    let a = Rect(x: 0, y: 0, width: 10, height: 10)
    let b = Rect(x: 10, y: 0, width: 10, height: 10)
    check intersect(a, b).width == 0.0

  test "overlapping in one axis only is still empty":
    let a = Rect(x: 0, y: 0, width: 100, height: 10)
    let b = Rect(x: 50, y: 50, width: 100, height: 10)
    let r = intersect(a, b)
    check r.width == 50.0
    check r.height == 0.0

suite "ScrollView sets its viewport as the child clip":

  test "no scrollbars: the clip is the bounds less the padding":
    let sv = newScrollView(padding = 8.0)
    sv.bounds = Rect(x: 10, y: 20, width: 200, height: 100)
    sv.addChild(newLabel(text = "small", fontSize = 14.0))
    sv.layout()

    check sv.childClip.isSome
    let clip = sv.childClip.get()
    # Widget-local coordinates: renderPass zeroes bounds.x/y while compositing.
    check clip.x == 8.0
    check clip.y == 8.0
    check clip.width == 184.0     # 200 - 8*2
    check clip.height == 84.0

  test "a vertical scrollbar narrows the clip":
    let sv = newScrollView(padding = 0.0, scrollbarWidth = 16.0)
    sv.bounds = Rect(x: 0, y: 0, width: 200, height: 50)
    let tall = newVStack(spacing = 0.0)
    for i in 1 .. 20:
      tall.addChild(newLabel(text = "row " & $i, fontSize = 14.0))
    sv.addChild(tall)
    sv.layout()

    let clip = sv.childClip.get()
    check clip.width == 184.0     # 200 - 16, room made for the bar
    check clip.height == 50.0

  test "the clip never covers the scrollbar gutter":
    # The bug this guards: content showing through underneath the scrollbars,
    # because the render texture clips to the full bounds and nothing clipped
    # to the viewport.
    let sv = newScrollView(padding = 4.0, scrollbarWidth = 16.0)
    sv.bounds = Rect(x: 0, y: 0, width: 200, height: 50)
    let tall = newVStack(spacing = 0.0)
    for i in 1 .. 20:
      tall.addChild(newLabel(text = "row " & $i, fontSize = 14.0))
    sv.addChild(tall)
    sv.layout()

    let clip = sv.childClip.get()
    check clip.x + clip.width <= sv.bounds.width - sv.scrollbarWidth
