## Sparkline -- a tiny line chart with no axes, for a trend in a table cell or a
## card. One series of numbers, drawn to fill its box; the last point is dotted.
##
## ```nim
## Sparkline(values = @[3.0, 5.0, 4.0, 8.0, 6.0, 9.0]).frame(width = 120, height = 28)
## ```
##
## For anything with axes, labels or several series, use Plot.

import rui_core
import rui_drawing
import std/[options, math]
import raylib
import ../modern/plot_scale

proc sparkPoints*(values: openArray[float], area: Rect): seq[tuple[x, y: float32]] =
  ## Where each value lands in `area`: spread evenly left to right, scaled so the
  ## smallest is at the bottom and the largest at the top. A flat series sits in
  ## the middle rather than on an edge.
  let r = span(values)
  for i, v in values:
    if v.isNaN: continue
    let x = if values.len <= 1: area.x + area.width / 2
            else: area.x + float32(i) / float32(values.len - 1) * area.width
    let y = if r.hi == r.lo: area.y + area.height / 2
            else: float32(mapTo(v, r.lo, r.hi, float64(area.y + area.height), float64(area.y)))
    result.add (x, y)

definePrimitive(Sparkline):
  props:
    values: seq[float] = @[]
    filled: bool = true
    intent: ThemeIntent = Default

  layout:
    if widget.bounds.width <= 0: widget.bounds.width = 120.0'f32
    if widget.bounds.height <= 0: widget.bounds.height = 28.0'f32

  render:
    let props = widget.themeProps(widget.intent)
    let color = props.activeColor.get(props.foregroundColor.get(BLACK))
    let line = max(1.5'f32, props.strokeWidth)
    let inset = line + 2
    let area = Rect(x: widget.bounds.x + inset, y: widget.bounds.y + inset,
                    width: widget.bounds.width - inset * 2, height: widget.bounds.height - inset * 2)
    let pts = sparkPoints(widget.values, area)
    if pts.len == 0: return
    let floorY = area.y + area.height
    for i in 1 ..< pts.len:
      if widget.filled:
        let a = Vector2(x: pts[i - 1].x, y: pts[i - 1].y)
        let b = Vector2(x: pts[i].x, y: pts[i].y)
        let fill = color.withAlpha(0.2)
        drawTriangleAnyWinding(a, b, Vector2(x: b.x, y: floorY), fill)
        drawTriangleAnyWinding(a, Vector2(x: b.x, y: floorY), Vector2(x: a.x, y: floorY), fill)
      drawLine(pts[i - 1].x, pts[i - 1].y, pts[i].x, pts[i].y, color, line)
    drawCircle(Vector2(x: pts[^1].x, y: pts[^1].y), line * 1.6, color)
