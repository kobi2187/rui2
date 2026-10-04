## The arithmetic of a plot: nice axis ranges, tick marks, and mapping data to
## pixels. Pure functions, so every rule is decidable from a table of cases
## without a widget or a window.

import std/[math, strutils]

proc niceStep*(span: float, target = 5): float =
  ## A round step (1, 2 or 5 times a power of ten) that divides `span` into
  ## about `target` intervals.
  if span <= 0 or target < 1:
    return 1.0
  let raw = span / float(target)
  let magnitude = pow(10.0, floor(log10(raw)))
  let fraction = raw / magnitude
  let nice = if fraction < 1.5: 1.0
             elif fraction < 3.5: 2.0
             elif fraction < 7.5: 5.0
             else: 10.0
  nice * magnitude

proc niceRange*(lo, hi: float, target = 5): tuple[lo, hi, step: float] =
  ## The axis range that covers [lo, hi] and starts and ends on a step. A
  ## range of no width (one value, or none) is opened out around it, so there
  ## is always something to draw against.
  var a = lo
  var b = hi
  if a > b: swap(a, b)
  if b - a < 1e-12:
    let pad = if abs(a) < 1e-12: 1.0 else: abs(a) * 0.5
    a -= pad
    b += pad
  let step = niceStep(b - a, target)
  (floor(a / step) * step, ceil(b / step) * step, step)

proc ticksFor*(lo, hi, step: float): seq[float] =
  ## Every multiple of `step` in [lo, hi].
  if step <= 0:
    return
  let first = ceil(lo / step - 1e-9)
  let last = floor(hi / step + 1e-9)
  var k = first
  while k <= last:
    result.add k * step
    k += 1

proc formatTick*(v, step: float): string =
  ## A tick label with only the decimals the step needs: 0, 5, 10 -- 0.5, 1.0,
  ## 1.5 -- and large or tiny steps in scientific form.
  let v = if abs(v) < step * 1e-9: 0.0 else: v     # -0 and rounding dust
  if step >= 1e6 or (step < 1e-3 and step > 0):
    return v.formatFloat(ffScientific, 2)
  if step >= 1:
    return $int64(round(v))                    # formatFloat would leave "5."
  v.formatFloat(ffDecimal, clamp(int(ceil(-log10(step))), 0, 6))

proc mapTo*(v, fromLo, fromHi, toA, toB: float): float =
  ## Where `v` in [fromLo, fromHi] lands in [toA, toB] (which may run either
  ## way, as a pixel y axis does).
  if fromHi - fromLo == 0:
    return (toA + toB) / 2
  toA + (v - fromLo) / (fromHi - fromLo) * (toB - toA)

proc span*(values: openArray[float]): tuple[lo, hi: float, any: bool] =
  ## Smallest and largest of `values`, skipping NaN. `any` is false when there
  ## is nothing to measure.
  result.lo = Inf
  result.hi = -Inf
  for v in values:
    if v.isNaN: continue
    result.any = true
    result.lo = min(result.lo, v)
    result.hi = max(result.hi, v)
  if not result.any:
    result.lo = 0
    result.hi = 0
