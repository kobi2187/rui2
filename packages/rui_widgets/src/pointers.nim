## Several pointers at once, as plain geometry. A pinch is not a gesture to
## recognise: it is two pointers dragging at the same time. One may hold still
## as the anchor while the other moves (a zoom about it), and the anchor may move
## a moment later (so a pan comes with the zoom). Nothing here decides what the
## fingers "mean" -- each move just reports how the pair has changed since the
## last one, and the widget applies it.
##
## ```nim
## # in a widget that sets `multiPointer = true`
## on_mouse_down: widget.pointers.down(event.pointerId, event.mousePos)
## on_mouse_move:
##   let t = widget.pointers.move(event.pointerId, event.mousePos)
##   widget.zoomAbout(widget.zoom * t.scale, t.anchor); widget.panBy(t.pan)
## on_mouse_up:   widget.pointers.up(event.pointerId)
## ```
##
## One pointer gives a pan (`scale` 1). Two give the change of the line between
## them: `scale` is the ratio of their distances, `rotation` the change of its
## angle (radians), `pan` how far its midpoint moved, `anchor` the midpoint now.
## A pointer going down or up changes nothing by itself: the next move is measured
## from where the pointers are, so adding or lifting a finger never jumps.

import std/[math, tables, algorithm]
import rui_core

type
  Pointers* = object
    at: Table[int, Point]

  PointerChange* = object
    pan*: Point          ## movement of the centre (or of the one pointer)
    scale*: float32      ## distance ratio now/before; 1 with one pointer
    rotation*: float32   ## radians; 0 with one pointer
    anchor*: Point       ## the centre now: where to zoom and rotate about
    count*: int          ## pointers down

proc count*(ps: Pointers): int = ps.at.len
proc has*(ps: Pointers, id: int): bool = id in ps.at
proc pos*(ps: Pointers, id: int): Point = ps.at.getOrDefault(id)

proc down*(ps: var Pointers, id: int, p: Point) = ps.at[id] = p
proc up*(ps: var Pointers, id: int) = ps.at.del id
proc clear*(ps: var Pointers) = ps.at.clear()

proc firstTwo(ps: Pointers): seq[int] =
  ## The two lowest ids: the pair a pinch is measured on.
  for id in ps.at.keys: result.add id
  result.sort()
  if result.len > 2: result.setLen 2

proc wrapAngle(a: float32): float32 =
  var r = a
  while r > PI: r -= 2 * PI
  while r < -PI: r += 2 * PI
  r

proc move*(ps: var Pointers, id: int, p: Point): PointerChange =
  ## Pointer `id` is now at `p`; how did the pointers change?
  result = PointerChange(scale: 1, anchor: p, count: ps.at.len)
  if id notin ps.at:
    ps.at[id] = p                  # a move with no down: start tracking, no change
    return
  let pair = ps.firstTwo
  let before = ps.at.getOrDefault(id)
  if pair.len < 2:
    result.pan = Point(x: p.x - before.x, y: p.y - before.y)
    ps.at[id] = p
    return
  if id notin pair:
    ps.at[id] = p                  # a third finger: tracked, not measured
    return
  let a0 = ps.at[pair[0]]
  let b0 = ps.at[pair[1]]
  ps.at[id] = p
  let a1 = ps.at[pair[0]]
  let b1 = ps.at[pair[1]]
  let d0 = hypot(b0.x - a0.x, b0.y - a0.y)
  let d1 = hypot(b1.x - a1.x, b1.y - a1.y)
  let mid0 = Point(x: (a0.x + b0.x) / 2, y: (a0.y + b0.y) / 2)
  let mid1 = Point(x: (a1.x + b1.x) / 2, y: (a1.y + b1.y) / 2)
  result.anchor = mid1
  result.pan = Point(x: mid1.x - mid0.x, y: mid1.y - mid0.y)
  if d0 > 0.0001:
    result.scale = d1 / d0
    result.rotation = wrapAngle(arctan2(b1.y - a1.y, b1.x - a1.x) -
                                arctan2(b0.y - a0.y, b0.x - a0.x))
