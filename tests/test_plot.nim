## Plot: the scale arithmetic and the layout of axes, with no window.

import std/[unittest, math, options]
import rui

suite "nice steps and ranges":

  test "steps are 1, 2 or 5 times a power of ten":
    check niceStep(10, 5) == 2.0
    check niceStep(100, 5) == 20.0
    check niceStep(7, 5) == 1.0       # raw 1.4 -> 1
    check niceStep(0.9, 5) == 0.2
    check niceStep(1000, 4) == 200.0 or niceStep(1000, 4) == 250.0 or niceStep(1000, 4) == 500.0
    check niceStep(0, 5) == 1.0       # nothing to divide

  test "a range starts and ends on a step":
    let r = niceRange(3.2, 97.5)
    check r.lo == 0.0 and r.hi == 100.0 and r.step == 20.0
    let r2 = niceRange(-4, 4)
    check r2.lo <= -4 and r2.hi >= 4
    check r2.lo mod r2.step == 0 and r2.hi mod r2.step == 0

  test "a range with no width is opened out; reversed ends are fine":
    let one = niceRange(5, 5)
    check one.lo < 5 and one.hi > 5
    let zero = niceRange(0, 0)
    check zero.lo < 0 and zero.hi > 0
    check niceRange(10, 0) == niceRange(0, 10)

  test "ticks are the multiples of the step inside the range":
    check ticksFor(0, 100, 25) == @[0.0, 25.0, 50.0, 75.0, 100.0]
    check ticksFor(-1, 1, 0.5) == @[-1.0, -0.5, 0.0, 0.5, 1.0]
    check ticksFor(3, 7, 2) == @[4.0, 6.0]
    check ticksFor(0, 10, 0).len == 0

  test "labels carry only the decimals the step needs":
    check formatTick(5, 5) == "5"
    check formatTick(1.5, 0.5) == "1.5"
    check formatTick(0.25, 0.05) == "0.25"
    check formatTick(-0.0, 1) == "0"           # no negative zero
    check formatTick(2_000_000, 1_000_000) == "2.00e+06"

  test "mapping data to pixels, either way up":
    check mapTo(5, 0, 10, 0, 100) == 50.0
    check mapTo(0, 0, 10, 200, 0) == 200.0     # a pixel y axis runs down
    check mapTo(10, 0, 10, 200, 0) == 0.0
    check mapTo(3, 4, 4, 0, 10) == 5.0         # no span: the middle

  test "span skips NaN, and an empty list is not an error":
    check span([3.0, NaN, -1.0, 7.0]) == (lo: -1.0, hi: 7.0, any: true)
    check not span(newSeq[float]()).any

suite "plot layout":

  let area = Rect(x: 50, y: 10, width: 300, height: 200)

  test "bars start at zero; lines need not":
    let bars = layoutPlot(@[barSeries("a", @[(0.0, 5.0), (1.0, 9.0)])], area, true)
    check bars.yLo == 0.0
    let line = layoutPlot(@[lineSeries("a", @[(0.0, 50.0), (1.0, 90.0)])], area, true)
    check line.yLo > 0.0
    let forced = layoutPlot(@[lineSeries("a", @[(0.0, 50.0), (1.0, 90.0)])], area, true, yMin = 0)
    check forced.yLo == 0.0

  test "bars are padded half a unit so the outer ones are not cut":
    let l = layoutPlot(@[barSeries("a", @[(0.0, 1.0), (3.0, 2.0)])], area, true)
    check l.xLo == -0.5 and l.xHi == 3.5

  test "data lands inside the plotting area, high values high":
    let l = layoutPlot(@[lineSeries("a", @[(0.0, 0.0), (10.0, 100.0)])], area, true)
    let low = l.toPixel(l.xLo, l.yLo)
    let high = l.toPixel(l.xHi, l.yHi)
    check low.x == area.x and low.y == area.y + area.height
    check high.x == area.x + area.width and high.y == area.y
    let mid = l.toPixel(5, 50)
    check mid.y < low.y and mid.y > high.y

  test "no data still lays out":
    let l = layoutPlot(@[], area, true)
    check l.yHi > l.yLo and l.xHi > l.xLo

  test "series without a colour take the theme's palette in turn":
    setCurrentTheme(brandTheme(daylightSpec()))
    let s = @[lineSeries("a", @[]), lineSeries("b", @[]),
              lineSeries("c", @[], some(Color(r: 1, g: 2, b: 3, a: 255)))]
    check seriesColor(s, 0) != seriesColor(s, 1)
    check seriesColor(s, 2) == Color(r: 1, g: 2, b: 3, a: 255)

suite "plot hover readout":
  proc chart(): Plot =
    result = newPlot(series = @[
      lineSeries("sales", @[(0.0, 10.0), (1.0, 30.0), (2.0, 20.0), (3.0, 40.0)]),
      lineSeries("costs", @[(0.0, 5.0), (1.0, 8.0), (2.0, 12.0), (3.0, 9.0)])])
    result.bounds = Rect(x: 0, y: 0, width: 400, height: 240)
    result.layout()

  test "the nearest point goes by x first, then by distance":
    let p = chart()
    let f = p.plotFrame
    let at1 = f.l.toPixel(1.0, 30.0)
    check nearestPoint(p.series, f.l, at1.x + 3, at1.y + 2) == (0, 1)
    let low = f.l.toPixel(2.0, 12.0)
    check nearestPoint(p.series, f.l, low.x - 2, low.y + 4) == (1, 2)

  test "moving over the plot area picks the point; outside it, none":
    let p = chart()
    let f = p.plotFrame
    let at = f.l.toPixel(3.0, 40.0)
    discard p.handleInput(GuiEvent(kind: evMouseMove, mousePos: Point(x: at.x, y: at.y)))
    check (p.hoverSeries, p.hoverIndex) == (0, 3)
    discard p.handleInput(GuiEvent(kind: evMouseMove, mousePos: Point(x: 1, y: 1)))
    check p.hoverSeries == -1
