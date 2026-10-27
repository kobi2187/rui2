## The playhead, selection and markers on a view (Marks, modern/axis_marks.nim)
## and snapping (axis_snap.nim), on a Waveform, driven through the real event
## router.

import std/[unittest, math]
import rui
import ui_harness

suite "snapping":
  test "a target within reach catches; else the grid; Alt leaves it":
    let s = snapTo(step = 1.0, pixels = 6, targets = @[10.3])
    check s.snapped(10.1, 0.1) == 10.3        # 2 px away: caught
    check s.snapped(12.4, 0.1) == 12.0        # nothing near: the grid
    check s.snapped(12.4, 0.1, off = true) == 12.4
    check snapTo().snapped(3.7, 1.0) == 3.7   # no grid, no targets

proc rig(snapStep = 0.0): tuple[r: Rig, m: Waveform, play: Link[float], sel: Link[AxisSpan]] =
  let view = newLink(wholeView(0.0, 100.0))       # 400 px: 0.25 a pixel
  let play = newLink(0.0)
  let sel = newLink(noSpan())
  var quiet: seq[float32]
  for i in 0 ..< 1000: quiet.add 0'f32
  let m = newWaveform(source = newSamples(quiet, 10), view = view,
                      marks = newMarks(playhead = play, selection = sel,
                                       markers = @[marker(80.0, "End")], snapStep = snapStep))
  let r = newRig(stack(m.frame(width = 400, height = 100)), 400, 120)
  (r, m, play, sel)

proc xOf(m: Waveform, at: float): float32 = m.bounds.x + float32(at / 0.25)

suite "Marks on a Waveform":
  teardown: clearRepaints()

  test "a click moves the playhead and clears the selection":
    let (r, m, play, sel) = rig()
    sel.value = span(10, 20)
    var sought = -1.0
    m.onSeek = proc(at: float) = sought = at
    r.click(m.xOf(40), m.bounds.y + 50)
    check abs(play.value - 40) < 0.3 and abs(sought - 40) < 0.3
    check sel.value.isEmpty
    disposeTree(r.root)

  test "a drag selects, snapped to the grid; Alt leaves it unsnapped":
    let (r, m, _, sel) = rig(snapStep = 5.0)
    r.drag(m.xOf(11), m.bounds.y + 50, m.xOf(33), m.bounds.y + 50)
    check sel.value.lo == 10 and sel.value.hi == 35
    r.press(m.xOf(41), m.bounds.y + 50)
    let e = GuiEvent(kind: evMouseMove, mousePos: Point(x: m.xOf(52.3), y: m.bounds.y + 50),
                     mods: {kmAlt})
    discard m.handleInput(e)
    var up = e
    up.kind = evMouseUp
    discard m.handleInput(up)             # Alt still held as it is let go
    check abs(sel.value.hi - 52.3) < 0.3
    disposeTree(r.root)

  test "an edge drags; past the other edge it becomes that one":
    let (r, m, _, sel) = rig()
    sel.value = span(20, 40)
    r.frame(1)
    r.drag(m.xOf(40), m.bounds.y + 50, m.xOf(60), m.bounds.y + 50)
    check sel.value.lo == 20 and abs(sel.value.hi - 60) < 0.3
    r.drag(m.xOf(20), m.bounds.y + 50, m.xOf(70), m.bounds.y + 50)
    check abs(sel.value.lo - 60) < 0.3 and abs(sel.value.hi - 70) < 0.3
    disposeTree(r.root)

  test "Shift+click extends the selection; edges catch on markers nearby":
    let (r, m, _, sel) = rig()
    sel.value = span(20, 40)
    r.frame(1)
    r.clickMod(m.xOf(79.5), m.bounds.y + 50, {kmShift})
    check sel.value.lo == 20 and sel.value.hi == 80    # caught by the marker at 80
    disposeTree(r.root)

  test "a marker's flag drags the marker":
    let (r, m, _, _) = rig()
    var moved: seq[float]
    m.onMarkerMoved = proc(i: int, at: float) = moved.add at
    r.drag(m.xOf(80) + 1, m.bounds.y + 5, m.xOf(50), m.bounds.y + 5)
    check abs(m.marks.markers.value[0].at - 50) < 0.3 and moved.len > 0
    disposeTree(r.root)

  test "without marks a drag pans; the wheel zooms the view either way":
    let view = newLink(wholeView(0.0, 100.0).clampedTo(400).zoomedAt(2, 0, 0, 400))
    let w = newWaveform(source = newSamples(@[0'f32, 0, 0], 10), view = view)
    let r2 = newRig(stack(w.frame(width = 400, height = 100)), 400, 120)
    r2.drag(w.bounds.x + 300, w.bounds.y + 50, w.bounds.x + 100, w.bounds.y + 50)
    check view.value.start > 0
    disposeTree(r2.root)

  test "the wheel zooms the view it is on":
    let (r, m, _, _) = rig()
    r.wheel(m.xOf(50), m.bounds.y + 50, 1)    # a plain notch at the start: nothing to pan
    check m.handleInput(GuiEvent(kind: evMouseWheel, wheelDelta: 1, mods: {kmCtrl},
                                 mousePos: Point(x: m.xOf(50), y: 50)))
    check m.view.value.clampedTo(400).perPixel < 0.25
    disposeTree(r.root)
