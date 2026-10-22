## Paths you can walk (outline.nim): a rectangle's, your own points, and the
## edge of an image traced in order -- the outside clockwise from its
## top-left-most point, holes after it, simplified to a few points.

import std/[unittest, math]
import rui

proc near(a, b: float32, eps = 0.6'f32): bool = abs(a - b) <= eps

suite "walking a path":
  test "a rectangle runs clockwise from its top-left; distance wraps round":
    let p = rectPath(Rect(x: 10, y: 20, width: 100, height: 50))
    check p.length == 300
    check p.pointAt(0) == Point(x: 10, y: 20)
    check p.pointAt(50) == Point(x: 60, y: 20)          # along the top
    check p.pointAt(125) == Point(x: 110, y: 45)        # down the right side
    check p.pointAt(350) == p.pointAt(50)               # once round and on
    check p.directionAt(50) == Point(x: 1, y: 0)
    check p.normalAt(50).y < 0                          # out of the shape: up

  test "rounded corners shorten it by what they cut":
    let r = 10.0'f32
    let p = rectPath(Rect(x: 0, y: 0, width: 100, height: 60), radius = r, cornerSteps = 24)
    check near(p.length, 320 - (8 - 2 * PI.float32) * r, 0.5)
    check p.pointAt(0).y == 0                           # starts on the top edge

  test "your own points, as (x, y) pairs":
    let p = newPath([(0'f32, 0'f32), (30'f32, 0'f32), (30'f32, 40'f32)])
    check p.length == 120                               # closed: back to the start
    check newPath([(0'f32, 0'f32), (30'f32, 0'f32)], closed = false).length == 30

  test "inset moves every edge inwards by the same amount":
    let p = rectPath(Rect(x: 0, y: 0, width: 100, height: 60)).inset(5)
    check p.points[0] == Point(x: 5, y: 5)
    check near(p.length, 2 * (90 + 50), 0.01)

suite "tracing an image's edge":
  proc image(w, h: int, inside: proc(x, y: int): bool): proc(x, y: int): float32 =
    result = proc(x, y: int): float32 = (if inside(x, y): 1'f32 else: 0'f32)

  test "a square: one loop, clockwise, from its top-left, a handful of points":
    let alpha = image(40, 40, proc(x, y: int): bool = x in 10 ..< 30 and y in 10 ..< 30)
    let paths = traceOutlines(40, 40, alpha)
    check paths.len == 1
    let p = paths[0]
    check signedArea(p.points) > 0                      # clockwise on screen
    check near(p.length, 80, 2.0)                       # the edge between pixels
    check p.points.len <= 12                            # simplified
    check p.points[0].y <= 10.6 and p.points[0].x <= 11

  test "a ring: the outside first, then the hole running the other way":
    let alpha = image(60, 60, proc(x, y: int): bool =
      let d = sqrt(float((x - 30) ^ 2 + (y - 30) ^ 2))
      d < 25 and d > 12)
    let paths = traceOutlines(60, 60, alpha)
    check paths.len == 2
    check signedArea(paths[0].points) > 0
    check signedArea(paths[1].points) < 0
    check abs(signedArea(paths[0].points)) > abs(signedArea(paths[1].points))

  test "soft edges place the line between pixels by their alpha":
    # a disc with an antialiased rim: the traced edge sits on the radius
    let alpha = proc(x, y: int): float32 =
      let d = sqrt(float32((x.float32 + 0.5 - 50) ^ 2 + (y.float32 + 0.5 - 50) ^ 2))
      clamp(30.5'f32 - d, 0, 1)
    let p = traceOutlines(100, 100, alpha, tolerance = 0.5)[0]
    for i in 0 ..< 16:
      let q = p.pointAt(p.length * i.float32 / 16)
      check near(sqrt((q.x - 50) ^ 2 + (q.y - 50) ^ 2), 30, 0.8)

  test "the same image always gives the same path":
    let alpha = image(30, 30, proc(x, y: int): bool = x + y in 10 .. 40)
    check traceOutlines(30, 30, alpha)[0].points == traceOutlines(30, 30, alpha)[0].points

  test "an empty image has no outline":
    check traceOutlines(10, 10, image(10, 10, proc(x, y: int): bool = false)).len == 0
