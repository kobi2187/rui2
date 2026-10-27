## One axis of a zoomable, pannable view (view_range.nim): the mapping, the
## limits, zooming about a point, panning inside the extent, and the gestures
## every widget on a view shares.

import std/[unittest, math]
import rui
from raylib import KeyboardKey

proc near(a, b: float, eps = 1e-6): bool = abs(a - b) <= eps

suite "AxisView":
  test "a whole view fits its extent at any width":
    let v = wholeView(0.0, 100.0)
    let a = v.clampedTo(200)
    check a.perPixel.near(0.5) and a.start == 0
    let b = v.clampedTo(1000)
    check b.perPixel.near(0.1)
    check a.toPixel(50.0, 10).float.near(110) and a.toData(110, 10).near(50)

  test "zooming keeps the data under the pointer there":
    let v = wholeView(0.0, 100.0).clampedTo(200)
    let at = 150'f32
    let before = v.toData(at, 0)
    let z = v.zoomedAt(4, at, 0, 200)
    check z.perPixel.near(v.perPixel / 4)
    check z.toData(at, 0).near(before)
    check not z.fitted

  test "zooming out stops at the whole extent; zooming in at minPerPixel":
    let v = wholeView(0.0, 100.0, minPerPixel = 0.01).clampedTo(200)
    check v.zoomedAt(0.1, 100, 0, 200).perPixel.near(0.5)    # no further out than all of it
    check v.zoomedAt(1000, 100, 0, 200).perPixel.near(0.01)

  test "panning stays inside the extent":
    let v = wholeView(0.0, 100.0).clampedTo(200).zoomedAt(2, 0, 0, 200)  # 50 shown
    check v.pannedBy(-500, 200).start == 0
    check v.pannedBy(10_000, 200).start.near(50)                          # the end at the right
    check v.pannedBy(20, 200).start.near(5)

  test "showing a range zooms to it":
    let v = wholeView(0.0, 100.0).clampedTo(200)
    let s = v.showing(70, 30, 200)
    check s.start.near(30) and s.stop(200).near(70)

  test "a widened window shows more of the data, not the same stretched":
    let v = wholeView(0.0, 100.0).clampedTo(200).zoomedAt(2, 0, 0, 200)
    check v.clampedTo(300).perPixel.near(v.perPixel)
    check v.clampedTo(300).stop(300).near(75)

suite "the gestures on a view (ZoomPan.handle)":
  proc viewer(link: Link[AxisView]): Label =
    result = newLabel(text = "on a view")
    result.bounds = Rect(x: 0, y: 0, width: 200, height: 50)
    result.followView(link)
    result.isDirty = false

  test "Ctrl+wheel zooms about the pointer, a plain wheel pans, both move every follower":
    let link = newLink(wholeView(0.0, 100.0))
    let w = viewer(link)
    var z: ZoomPan
    check z.handle(w, link, GuiEvent(kind: evMouseWheel, wheelDelta: 1, mods: {kmCtrl},
                                       mousePos: Point(x: 50, y: 0)), w.bounds)
    check link.value.clampedTo(200).perPixel.near(0.4)
    check w.isDirty
    let start = link.value.start
    check z.handle(w, link, GuiEvent(kind: evMouseWheel, wheelDelta: -1), w.bounds)
    check link.value.start > start
    check z.handle(w, link, GuiEvent(kind: evMouseWheel, wheelDelta: 100), w.bounds)
    check link.value.start == 0
    check not z.handle(w, link, GuiEvent(kind: evMouseWheel, wheelDelta: 1), w.bounds)

  test "a drag pans: press, move, release":
    let link = newLink(wholeView(0.0, 100.0).clampedTo(200).zoomedAt(4, 0, 0, 200))
    let w = viewer(link)
    var z: ZoomPan
    check z.handle(w, link, GuiEvent(kind: evMouseDown, mousePos: Point(x: 150, y: 10)), w.bounds)
    check z.handle(w, link, GuiEvent(kind: evMouseMove, mousePos: Point(x: 50, y: 10)), w.bounds)
    check link.value.start.near(100 * 0.125)
    check z.handle(w, link, GuiEvent(kind: evMouseUp, mousePos: Point(x: 50, y: 10)), w.bounds)
    check not z.handle(w, link, GuiEvent(kind: evMouseMove, mousePos: Point(x: 0, y: 10)), w.bounds)
    check not z.handle(w, link, GuiEvent(kind: evMouseDown, mousePos: Point(x: 900, y: 10)), w.bounds)

  test "keys, when focused: Right pans, End goes to the end, minus zooms out":
    let link = newLink(wholeView(0.0, 100.0).clampedTo(200).zoomedAt(4, 0, 0, 200))
    let w = viewer(link)
    var z: ZoomPan
    check not z.handle(w, link, GuiEvent(kind: evKeyDown, key: KeyboardKey.Right), w.bounds)
    w.focused = true
    check z.handle(w, link, GuiEvent(kind: evKeyDown, key: KeyboardKey.Right), w.bounds)
    check link.value.start > 0
    check z.handle(w, link, GuiEvent(kind: evKeyDown, key: KeyboardKey.End), w.bounds)
    check link.value.stop(200).near(100)
    check z.handle(w, link, GuiEvent(kind: evKeyDown, key: KeyboardKey.Minus), w.bounds)
    check link.value.perPixel.near(0.125 * 1.25)
    check not z.handle(w, link, GuiEvent(kind: evKeyDown, key: KeyboardKey.A), w.bounds)
