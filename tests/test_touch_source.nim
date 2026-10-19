## Extra fingers become pointer events: down, moves, up, with ids that are never 0.

import std/[unittest, tables, sequtils]
import rui_core
import ../packages/rui/src/touch_source

proc pt(x, y: float32): Point = Point(x: x, y: y)

suite "touchDiff":
  test "the first finger is the mouse's and produces nothing":
    var known: Table[int, Point]
    check touchDiff(known, @[(id: 0, at: pt(5, 5))]).len == 0
    check known.len == 0

  test "a second finger going down, moving and lifting":
    var known: Table[int, Point]
    let one = @[(id: 0, at: pt(5, 5))]
    let down = touchDiff(known, one & (id: 1, at: pt(50, 50)))
    check down.mapIt(it.kind) == @[evMouseMove, evMouseDown]
    check down.allIt(it.pointerId == 2)          # touch id 1 -> pointer 2
    check touchDiff(known, one & (id: 1, at: pt(50, 50))).len == 0   # still: silent
    let moved = touchDiff(known, one & (id: 1, at: pt(60, 40)))
    check moved.len == 1 and moved[0].kind == evMouseMove
    check moved[0].mousePos == pt(60, 40)
    let up = touchDiff(known, one)
    check up.len == 1 and up[0].kind == evMouseUp and up[0].pointerId == 2
    check up[0].mousePos == pt(60, 40)           # where it was last seen
    check known.len == 0

  test "two extra fingers are told apart":
    var known: Table[int, Point]
    let frame = @[(id: 0, at: pt(0, 0)), (id: 1, at: pt(10, 10)), (id: 2, at: pt(20, 20))]
    let es = touchDiff(known, frame)
    check es.filterIt(it.kind == evMouseDown).mapIt(it.pointerId) == @[2, 3]
