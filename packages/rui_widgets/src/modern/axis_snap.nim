## Snapping a position on an axis: to things nearby (a marker, the playhead,
## the edge of a selection or a clip), else to a grid (a frame, a beat).
## Shared by AxisMarks and Lanes, so a selection edge and a clip edge snap
## the same way.

import std/math

type Snap* = object
  step*: float          ## the grid, in data units (0: none)
  pixels*: float32      ## how near, on screen, a thing must be to catch it
  targets*: seq[float]  ## the things to catch: markers, playhead, edges

proc snapTo*(step = 0.0, pixels = 6'f32, targets: seq[float] = @[]): Snap =
  Snap(step: step, pixels: pixels, targets: targets)

proc snapped*(s: Snap, x, perPixel: float, off = false): float =
  ## `x`, caught by the nearest target within `pixels`, else on the grid.
  ## `off` (a modifier held) leaves it where it is.
  if off: return x
  let reach = float(s.pixels) * perPixel
  var best = reach
  result = x
  for t in s.targets:
    if abs(t - x) <= best:
      best = abs(t - x)
      result = t
  if best < reach: return
  if s.step > 0: result = round(x / s.step) * s.step
