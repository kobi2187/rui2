## Paths: an ordered outline you can walk.
##
## A `Path` is a list of points, closed or open, measured: `pointAt(s)` is the
## point `s` pixels along it and `directionAt(s)` the way it runs there, so an
## effect can space lights evenly round any outline, or send one along it.
##
## Where paths come from:
## - `rectPath` -- a widget's (rounded) rectangle;
## - your own points -- `newPath(@[...])`, e.g. a window shape's corners,
##   relative to the window;
## - `traceOutlines` -- the edge of any alpha image (a window skin), traced:
##
##   1. **marching squares**: each 2x2 group of pixels the edge passes
##      between gives a short segment, its ends placed between the pixels by
##      their alpha, so a soft-edged PNG gives a smooth line, not steps;
##   2. **linked**: the segments are joined end to end into closed loops, in
##      order. The loop with the largest area is the outside, the rest are
##      holes; the outside runs clockwise (on screen) and starts at its
##      top-left-most point, so one image always gives the same path;
##   3. **simplified** (Ramer-Douglas-Peucker): only the points needed to stay
##      within `tolerance` pixels of the traced edge are kept -- a few dozen
##      instead of thousands.
##
## Coordinates are whatever space the points were given in (window pixels for
## a traced skin). `inset` moves a closed path inwards, for an effect that
## must stay inside a hard-edged shape.

import std/[math, tables, algorithm]
import types

type Path* = object
  points*: seq[Point]
  closed*: bool
  lengths: seq[float32]     # distance along the path to each point

proc dist(a, b: Point): float32 = sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)

proc newPath*(points: openArray[Point], closed = true): Path =
  ## A path through `points` in order (back to the first, if `closed`).
  result.points = @points
  result.closed = closed
  var total = 0.0'f32
  for i, p in result.points:
    if i > 0: total += dist(result.points[i - 1], p)
    result.lengths.add total

proc newPath*(xy: openArray[(float32, float32)], closed = true): Path =
  ## The same from (x, y) pairs: `newPath([(20'f32, 10'f32), (380, 10), ...])`.
  var pts: seq[Point]
  for (x, y) in xy: pts.add Point(x: x, y: y)
  newPath(pts, closed)

proc length*(p: Path): float32 =
  ## The whole way round (or along, for an open path).
  if p.points.len < 2: return 0
  result = p.lengths[^1]
  if p.closed: result += dist(p.points[^1], p.points[0])

proc locate(p: Path, s: float32): (int, float32) =
  ## The segment `s` falls on, and how far along it (0..1). A closed path
  ## wraps; an open one clamps.
  let total = p.length
  var d = s
  if p.closed:
    d = d mod total
    if d < 0: d += total
  else:
    d = clamp(d, 0, total)
  let last = if p.closed: p.points.len - 1 else: p.points.len - 2
  # binary search the segment whose start is at or before d
  var lo = 0
  var hi = last
  while lo < hi:
    let mid = (lo + hi + 1) div 2
    if p.lengths[mid] <= d: lo = mid else: hi = mid - 1
  let a = p.points[lo]
  let b = p.points[(lo + 1) mod p.points.len]
  let segLen = dist(a, b)
  (lo, (if segLen > 0: (d - p.lengths[lo]) / segLen else: 0'f32))

proc pointAt*(p: Path, s: float32): Point =
  ## The point `s` pixels along the path.
  if p.points.len == 0: return Point()
  if p.points.len == 1: return p.points[0]
  let (i, t) = p.locate(s)
  let a = p.points[i]
  let b = p.points[(i + 1) mod p.points.len]
  Point(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)

proc directionAt*(p: Path, s: float32): Point =
  ## The unit direction the path runs in at `s`.
  if p.points.len < 2: return Point(x: 1, y: 0)
  let (i, _) = p.locate(s)
  let a = p.points[i]
  let b = p.points[(i + 1) mod p.points.len]
  let d = dist(a, b)
  if d == 0: Point(x: 1, y: 0) else: Point(x: (b.x - a.x) / d, y: (b.y - a.y) / d)

proc normalAt*(p: Path, s: float32): Point =
  ## Out of the shape, for a clockwise (on screen) closed path.
  let d = p.directionAt(s)
  Point(x: d.y, y: -d.x)

proc signedArea*(points: openArray[Point]): float32 =
  ## Positive for a loop that runs clockwise on screen (y grows downwards).
  for i in 0 ..< points.len:
    let a = points[i]
    let b = points[(i + 1) mod points.len]
    result += a.x * b.y - b.x * a.y
  result /= 2

proc rectPath*(r: Rect, radius = 0.0'f32, cornerSteps = 6): Path =
  ## A rectangle's outline, clockwise from its top-left, its corners rounded
  ## by `radius` (each in `cornerSteps` straight pieces).
  let rr = clamp(radius, 0, min(r.width, r.height) / 2)
  if rr <= 0:
    return newPath([Point(x: r.x, y: r.y), Point(x: r.x + r.width, y: r.y),
                    Point(x: r.x + r.width, y: r.y + r.height), Point(x: r.x, y: r.y + r.height)])
  var pts: seq[Point]
  let centres = [(r.x + r.width - rr, r.y + rr, -PI / 2),          # top-right
                 (r.x + r.width - rr, r.y + r.height - rr, 0.0),    # bottom-right
                 (r.x + rr, r.y + r.height - rr, PI / 2),           # bottom-left
                 (r.x + rr, r.y + rr, PI)]                          # top-left
  for (cx, cy, start) in centres:
    for k in 0 .. cornerSteps:
      let a = start + (PI / 2) * k.float / cornerSteps.float
      pts.add Point(x: cx + rr * cos(a).float32, y: cy + rr * sin(a).float32)
  # start at the top-left corner's end, so the path begins on the top edge
  let first = pts.len - 1
  newPath(pts[first .. ^1] & pts[0 ..< first])

proc inset*(p: Path, by: float32): Path =
  ## The closed path moved `by` pixels inwards (outwards if negative), each
  ## point along the average of its two edges' normals. Good for the gentle
  ## outlines of windows and widgets; a deep inset of a sharp spike folds.
  if p.points.len < 3: return p
  let sign = if signedArea(p.points) >= 0: 1.0'f32 else: -1.0'f32
  var pts: seq[Point]
  let n = p.points.len
  for i in 0 ..< n:
    let prev = p.points[(i + n - 1) mod n]
    let cur = p.points[i]
    let next = p.points[(i + 1) mod n]
    proc outward(a, b: Point): Point =
      let d = dist(a, b)
      if d == 0: Point() else: Point(x: (b.y - a.y) / d * sign, y: -(b.x - a.x) / d * sign)
    let n1 = outward(prev, cur)
    let n2 = outward(cur, next)
    var nx = n1.x + n2.x
    var ny = n1.y + n2.y
    let len = sqrt(nx * nx + ny * ny)
    if len > 0: nx /= len; ny /= len
    # keep the edges `by` away, not just the corner point
    let cosHalf = max(0.3'f32, nx * n1.x + ny * n1.y)
    pts.add Point(x: cur.x - nx * by / cosHalf, y: cur.y - ny * by / cosHalf)
  newPath(pts, p.closed)

proc offsetBy*(p: Path, dx, dy: float32): Path =
  ## The same path moved by (dx, dy).
  var pts = p.points
  for q in pts.mitems:
    q.x += dx
    q.y += dy
  newPath(pts, p.closed)

# ----------------------------------------------------------------------------
# Simplifying
# ----------------------------------------------------------------------------

proc lineDistance(p, a, b: Point): float32 =
  let d = dist(a, b)
  if d == 0: return dist(p, a)
  abs((b.x - a.x) * (a.y - p.y) - (a.x - p.x) * (b.y - a.y)) / d

proc rdp(pts: openArray[Point], first, last: int, tolerance: float32, keep: var seq[bool]) =
  var worst = 0.0'f32
  var at = -1
  for i in first + 1 ..< last:
    let d = lineDistance(pts[i], pts[first], pts[last])
    if d > worst: worst = d; at = i
  if at >= 0 and worst > tolerance:
    keep[at] = true
    rdp(pts, first, at, tolerance, keep)
    rdp(pts, at, last, tolerance, keep)

proc simplify*(points: openArray[Point], tolerance = 1.0'f32, closed = true): seq[Point] =
  ## The fewest of `points` (in order) that stay within `tolerance` pixels of
  ## the line through all of them.
  if points.len < 4: return @points
  var keep = newSeq[bool](points.len)
  keep[0] = true
  if closed:
    # A loop has no ends: split it at the point farthest from the first.
    var far = 0
    for i in 1 ..< points.len:
      if dist(points[i], points[0]) > dist(points[far], points[0]): far = i
    keep[far] = true
    rdp(points, 0, far, tolerance, keep)
    var tail = @points[far .. ^1] & @[points[0]]
    var keepTail = newSeq[bool](tail.len)
    rdp(tail, 0, tail.len - 1, tolerance, keepTail)
    for i in 1 ..< tail.len - 1:
      if keepTail[i]: keep[far + i] = true
  else:
    keep[^1] = true
    rdp(points, 0, points.len - 1, tolerance, keep)
  for i, p in points:
    if keep[i]: result.add p

# ----------------------------------------------------------------------------
# Tracing an image's edge
# ----------------------------------------------------------------------------

proc traceOutlines*(width, height: int, alphaAt: proc(x, y: int): float32,
                    threshold = 0.5'f32, tolerance = 1.0'f32): seq[Path] =
  ## The edges of whatever `alphaAt` (0..1 per pixel) has at or above
  ## `threshold`, as closed paths in pixel coordinates: the outside first
  ## (clockwise, starting at its top-left-most point), then any holes (each
  ## running the other way). See the module comment for how.
  # Samples at pixel centres, with a ring of empty pixels round the image so
  # every edge closes.
  proc sample(x, y: int): float32 =
    if x < 0 or y < 0 or x >= width or y >= height: 0'f32 else: alphaAt(x, y)
  let cols = width + 2                       # corner columns, -1 .. width
  proc edgeId(x, y: int, vertical: bool): int =
    (((y + 1) * (cols + 1) + (x + 1)) * 2) + (if vertical: 1 else: 0)
  var points = initTable[int, Point]()
  var links = initTable[int, seq[int]]()
  proc crossing(ax, ay, bx, by: int, vertical: bool): int =
    ## The edge between corners a and b: where along it the threshold falls.
    let id = edgeId(ax, ay, vertical)
    if id notin points:
      let va = sample(ax, ay)
      let vb = sample(bx, by)
      let t = if vb != va: clamp((threshold - va) / (vb - va), 0'f32, 1'f32) else: 0.5'f32
      points[id] = Point(x: ax.float32 + 0.5 + (bx - ax).float32 * t,
                         y: ay.float32 + 0.5 + (by - ay).float32 * t)
    id
  proc link(a, b: int) =
    links.mgetOrPut(a, @[]).add b
    links.mgetOrPut(b, @[]).add a
  for y in -1 ..< height:
    for x in -1 ..< width:
      let tl = sample(x, y) >= threshold
      let tr = sample(x + 1, y) >= threshold
      let br = sample(x + 1, y + 1) >= threshold
      let bl = sample(x, y + 1) >= threshold
      if tl == tr and tr == br and br == bl: continue
      var top, right, bottom, left = -1
      if tl != tr: top = crossing(x, y, x + 1, y, false)
      if tr != br: right = crossing(x + 1, y, x + 1, y + 1, true)
      if bl != br: bottom = crossing(x, y + 1, x + 1, y + 1, false)
      if tl != bl: left = crossing(x, y, x, y + 1, true)
      let crossed = [top, right, bottom, left]
      var ends: seq[int]
      for e in crossed:
        if e >= 0: ends.add e
      if ends.len == 2:
        link(ends[0], ends[1])
      else:
        # A saddle: two corners in, diagonally. The centre decides which pair
        # of corners the edges cut off.
        let centre = (sample(x, y) + sample(x + 1, y) + sample(x + 1, y + 1) +
                      sample(x, y + 1)) / 4 >= threshold
        let cutTlBr = (tl == centre) == false     # the corners unlike the centre are cut off
        if cutTlBr:
          link(top, left); link(right, bottom)
        else:
          link(top, right); link(bottom, left)
  # Walk the links into loops.
  var seen = initTable[int, bool]()
  var loops: seq[seq[Point]]
  for start in links.keys:
    if seen.getOrDefault(start): continue
    var loop: seq[Point]
    var prev = -1
    var cur = start
    while true:
      seen[cur] = true
      loop.add points[cur]
      let next = (if links[cur][0] != prev: links[cur][0] else: links[cur][1])
      prev = cur
      cur = next
      if cur == start: break
    if loop.len >= 3: loops.add loop
  # Outside first; outside clockwise, holes the other way; a fixed start.
  var outer = 0
  for i, l in loops:
    if abs(signedArea(l)) > abs(signedArea(loops[outer])): outer = i
  for i, l in loops.mpairs:
    let clockwise = signedArea(l) > 0
    if clockwise != (i == outer): l.reverse()
    var first = 0
    for j, p in l:
      if p.y < l[first].y or (p.y == l[first].y and p.x < l[first].x): first = j
    l = l[first .. ^1] & l[0 ..< first]
  if loops.len == 0: return
  result.add newPath(simplify(loops[outer], tolerance))
  for i, l in loops:
    if i != outer: result.add newPath(simplify(l, tolerance))
