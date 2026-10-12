## Window geometry: pure rectangle arithmetic, no widgets, no drawing.
##
## Where on a window's border a press lands, what a resize or a drag does to
## the rectangle, and how a rectangle is kept on screen. Separate from the
## widget so it can be tested to the pixel.

import rui_core

type
  Edge* = enum edgeLeft, edgeRight, edgeTop, edgeBottom
  Edges* = set[Edge]

const
  titleHeight* = 28.0'f32
  contentPad* = 8.0'f32
  gripWidth* = 6.0'f32
  minVisibleTitle* = 72.0'f32
    ## How much of a dragged window's title bar must stay on screen, so there is
    ## always something to grab.

func edgesAt*(r: Rect, p: Point, grip = gripWidth): Edges =
  ## Which borders a point on (or just inside) the window's outline is over.
  ## Empty for a point inside the body or outside the window.
  if p.x < r.x or p.x > r.x + r.width or p.y < r.y or p.y > r.y + r.height:
    return {}
  if p.x < r.x + grip: result.incl edgeLeft
  if p.x > r.x + r.width - grip: result.incl edgeRight
  if p.y < r.y + grip: result.incl edgeTop
  if p.y > r.y + r.height - grip: result.incl edgeBottom

func resized*(start: Rect, edges: Edges, dx, dy: float32,
              minWidth, minHeight: float32): Rect =
  ## `start` with the dragged `edges` moved by (dx, dy). The opposite edge stays
  ## put, and the size never goes below the minimum -- when it would, the moving
  ## edge stops at the minimum rather than pushing the window along.
  result = start
  if edgeRight in edges:
    result.width = max(minWidth, start.width + dx)
  if edgeLeft in edges:
    result.width = max(minWidth, start.width - dx)
    result.x = start.x + start.width - result.width
  if edgeBottom in edges:
    result.height = max(minHeight, start.height + dy)
  if edgeTop in edges:
    result.height = max(minHeight, start.height - dy)
    result.y = start.y + start.height - result.height

func clampedTo*(r: Rect, view: Rect): Rect =
  ## Keep a window reachable inside `view`: the whole thing when it fits, else at
  ## least `minVisibleTitle` of the title bar horizontally and the title bar
  ## itself vertically. A window larger than the view is shrunk to it.
  result = r
  result.width = min(result.width, view.width)
  result.height = min(result.height, view.height)
  let keep = min(minVisibleTitle, result.width)
  result.x = clamp(result.x, view.x + keep - result.width, view.x + view.width - keep)
  result.y = clamp(result.y, view.y, view.y + view.height - titleHeight)

func contentRect*(r: Rect): Rect =
  Rect(x: r.x + contentPad, y: r.y + titleHeight + contentPad,
       width: max(0.0'f32, r.width - contentPad * 2),
       height: max(0.0'f32, r.height - titleHeight - contentPad * 2))

func titleButton*(r: Rect, slot: int): Rect =
  ## The square buttons at the right end of the title bar; slot 0 is the
  ## rightmost (close).
  Rect(x: r.x + r.width - titleHeight * float32(slot + 1), y: r.y,
       width: titleHeight, height: titleHeight)
