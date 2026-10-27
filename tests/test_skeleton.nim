## Skeleton (basic/skeleton.nim): the bars of a text placeholder, a pulse that
## goes and comes back, and stillness when motion is off.

import std/unittest
import rui

suite "Skeleton":
  teardown:
    motion = motionFull
    animationsEnabled = false            # as the test rig keeps it
    clearRepaints()

  test "text: full-width bars, the last shorter; its height is its lines":
    let bars = textLines(Rect(x: 0, y: 0, width: 200, height: 0), 3, 12, 8)
    check bars.len == 3
    check bars[0].width == 200 and bars[2].width == 120
    check bars[2].y == 40
    let s = newSkeleton(shape = skText, lines = 3)
    s.layout()
    check s.bounds.height == 52'f32

  test "the pulse goes to its lightest and back over its period":
    check pulseAt(0) == 0
    check abs(pulseAt(0.8) - 1) < 1e-4
    check pulseAt(1.6) < 1e-4

  test "it asks for frames while it pulses; with motion none it stays still":
    proc mine(w: Widget): int =
      for p in pendingRepaints():
        if p.widget == w: inc result
    let s = newSkeleton(shape = skBlock)
    s.bounds = Rect(x: 0, y: 0, width: 100, height: 40)
    animationsEnabled = true             # the rig and scripted runs keep effects off
    s.render()                           # headless: the drawing is skipped, not the rest
    check mine(s) >= 1
    clearRepaints()
    motion = motionNone
    s.render()
    check mine(s) == 0
