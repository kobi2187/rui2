## Pointers: pan, zoom and rotate fall out of two pointers moving, with no
## gesture to recognise -- the anchor may hold still, or move later.

import std/[unittest, math]
import rui

proc pt(x, y: float32): Point = Point(x: x, y: y)

suite "Pointers":
  test "one pointer pans by its movement":
    var ps: Pointers
    ps.down(0, pt(10, 10))
    let c = ps.move(0, pt(25, 4))
    check c.pan == pt(15, -6)
    check c.scale == 1 and c.rotation == 0 and c.count == 1

  test "two pointers moving apart zoom about their midpoint":
    var ps: Pointers
    ps.down(0, pt(90, 100)); ps.down(1, pt(110, 100))      # 20 apart
    let c = ps.move(1, pt(130, 100))                       # 40 apart
    check abs(c.scale - 2.0'f32) < 1e-4'f32
    check c.rotation == 0
    check c.anchor == pt(110, 100)
    check c.pan == pt(10, 0)             # the midpoint moved as the one finger did

  test "one pointer is an anchor that holds still, and may move later":
    var ps: Pointers
    ps.down(0, pt(100, 100)); ps.down(1, pt(140, 100))
    let zoom = ps.move(1, pt(180, 100))                    # 40 -> 80
    check abs(zoom.scale - 2.0'f32) < 1e-4'f32
    let drift = ps.move(0, pt(110, 100))                   # the anchor moves later
    check drift.scale < 1                                  # they are closer again
    check drift.pan.x > 0                                  # and the pair shifted right

  test "both moving together is a pure pan":
    var ps: Pointers
    ps.down(0, pt(50, 50)); ps.down(1, pt(150, 50))
    let a = ps.move(0, pt(60, 70))        # one event at a time, so each is partial...
    let b = ps.move(1, pt(160, 70))
    check abs(a.scale * b.scale - 1.0'f32) < 1e-4'f32   # ...but the net zoom is none
    check abs(a.pan.y + b.pan.y - 20) < 1e-4'f32        # and the pan adds up to the move

  test "rotation is the change of the angle between them":
    var ps: Pointers
    ps.down(0, pt(100, 100)); ps.down(1, pt(200, 100))
    let c = ps.move(1, pt(100, 200))                       # a quarter turn
    check abs(c.rotation - PI.float32 / 2) < 1e-4'f32
    check abs(c.scale - 1.0'f32) < 1e-4'f32

  test "lifting or adding a finger never jumps":
    var ps: Pointers
    ps.down(0, pt(0, 0)); ps.down(1, pt(100, 0))
    ps.up(1)
    let c = ps.move(0, pt(5, 5))
    check c.pan == pt(5, 5) and c.scale == 1 and c.count == 1
    ps.down(1, pt(300, 300))                               # lands far away
    let d = ps.move(1, pt(300, 300))                       # no movement
    check d.scale == 1 and d.pan == pt(0, 0)

  test "a third pointer is tracked but not measured":
    var ps: Pointers
    ps.down(0, pt(0, 0)); ps.down(1, pt(10, 0)); ps.down(2, pt(500, 500))
    let c = ps.move(2, pt(600, 600))
    check c.scale == 1 and c.pan == pt(0, 0)
    check ps.count == 3

  test "a move without a down starts tracking, changing nothing":
    var ps: Pointers
    let c = ps.move(3, pt(7, 7))
    check c.pan == pt(0, 0) and c.scale == 1
    check ps.has(3)
