## Drawing samples as a wave, at whatever zoom: shared by the Waveform widget
## and Plot's wave series.
##
## How much detail a pixel column holds decides how it is drawn:
## - many samples to a column: the column spans their smallest to largest
##   (from the summaries, samples.nim), joined to its neighbours so the
##   envelope has no gaps;
## - fewer samples than columns: a line through the samples;
## - a sample every few pixels or more: a dot on each, so single samples can
##   be seen (and, in an editor, picked).

import rui_core
import rui_drawing
import std/math
import raylib
import ../view_range
import ../sources/samples
import plot_scale

proc drawWave*(s: SampleSource, ch: int, view: AxisView, area: Rect,
               yLo, yHi: float, color: Color, line = 1.0'f32) =
  ## Channel `ch` of `s` over `area`, x from `view` (seconds), y from yLo
  ## (bottom) to yHi (top). `view` must already be resolved for `area.width`.
  if s == nil or s.frames == 0 or view.perPixel <= 0 or area.width <= 0: return
  template yOf(v: float32): float32 =
    float32(mapTo(float(v), yLo, yHi, area.y + area.height, area.y))
  let perFrame = view.perPixel * s.rate          # samples to a pixel column
  if perFrame >= 1:
    var prevLo, prevHi = NaN.float32
    for c in 0 ..< int(ceil(area.width)):
      let t0 = view.start + float(c) * view.perPixel
      let f0 = int(floor(t0 * s.rate))
      let f1 = max(f0 + 1, int(floor((t0 + view.perPixel) * s.rate)))
      if f0 >= s.frames: break
      if f1 <= 0: continue
      var mm = s.span(ch, f0, f1)
      if not prevLo.isNaN:                       # meet the column before: no gaps
        if mm.lo > prevHi: mm.lo = prevHi
        if mm.hi < prevLo: mm.hi = prevLo
      prevLo = mm.lo
      prevHi = mm.hi
      let top = yOf(mm.hi)
      let bottom = max(yOf(mm.lo), top + 1)
      drawRect(Rect(x: area.x + float32(c), y: top, width: 1, height: bottom - top), color)
    return
  let first = max(0, int(floor(view.start * s.rate)) - 1)
  let last = min(s.frames - 1, int(ceil(view.stop(area.width) * s.rate)) + 1)
  let dots = 1 / perFrame >= 8                   # a sample every 8 px or more
  var prev: Vector2
  for i in first .. last:
    let x = view.toPixel(float(i) / s.rate, area.x)
    let p = Vector2(x: x, y: yOf(s.sample(ch, i)))
    if i > first: drawLine(prev.x, prev.y, p.x, p.y, color, line)
    if dots: drawCircle(p, max(2.5'f32, line * 1.5), color)
    prev = p
