## Plot -- a small chart: lines, areas, bars and scatter points on shared axes.
##
## One widget, one job: draw series of (x, y) points with round axis ranges,
## tick labels, a grid and a legend, in the theme's colours. It is not a
## charting library; anything more (interaction, annotations, stacked series)
## is composed from it and the primitives.
##
## ```nim
## ui:
##   Plot(title = "Requests", series = @[
##     lineSeries("2025", @[(0.0, 3.0), (1.0, 5.0), (2.0, 4.0)]),
##     barSeries("2024", @[(0.0, 2.0), (1.0, 4.0), (2.0, 3.0)])]):
## ```
##
## Series take their colours from the theme in turn (accent, info, success,
## warning, danger) unless you give one. `xLabels` names the x positions
## 0, 1, 2, ... for category charts. The line weight is the theme's stroke
## width, so a fat brand draws fat lines.

import rui_core
import rui_drawing
import std/[options, math]
import raylib
import plot_scale
export plot_scale

type
  PlotKind* = enum
    pkLine, pkArea, pkBar, pkScatter

  Series* = object
    name*: string
    kind*: PlotKind
    points*: seq[tuple[x, y: float]]
    color*: Option[Color]      ## from the theme's palette when unset

proc lineSeries*(name: string, points: seq[tuple[x, y: float]],
                 color = none(Color)): Series =
  Series(name: name, kind: pkLine, points: points, color: color)
proc areaSeries*(name: string, points: seq[tuple[x, y: float]],
                 color = none(Color)): Series =
  Series(name: name, kind: pkArea, points: points, color: color)
proc barSeries*(name: string, points: seq[tuple[x, y: float]],
                color = none(Color)): Series =
  Series(name: name, kind: pkBar, points: points, color: color)
proc scatterSeries*(name: string, points: seq[tuple[x, y: float]],
                    color = none(Color)): Series =
  Series(name: name, kind: pkScatter, points: points, color: color)

proc seriesColor*(series: seq[Series], i: int): Color =
  ## The colour series `i` is drawn in: its own, else the theme's palette.
  if series[i].color.isSome:
    return series[i].color.get
  # Four distinct hues (the brand accent, then the status colours -- `info` is
  # usually the accent itself), then the same four drawn toward the ink.
  let intents = [ThemeIntent.Default, Success, Warning, Danger]
  let props = currentTheme.getThemeProps(intents[i mod intents.len])
  let ink = currentTheme.getThemeProps(ThemeIntent.Default).foregroundColor.get(BLACK)
  let base = props.activeColor.get(ink)
  lerp(base, ink, min(0.6'f32, 0.3'f32 * float32(i div intents.len)))

type PlotLayout* = object
  ## Where everything sits, worked out once and shared by painting and tests.
  area*: Rect                       ## the plotting rectangle inside the axes
  xLo*, xHi*, yLo*, yHi*: float
  xStep*, yStep*: float

proc xRangeOf*(series: seq[Series]): tuple[lo, hi: float, any: bool] =
  var xs: seq[float]
  for s in series:
    for p in s.points: xs.add p.x
  span(xs)

proc yRangeOf*(series: seq[Series], includeZero: bool): tuple[lo, hi: float, any: bool] =
  var ys: seq[float]
  for s in series:
    for p in s.points: ys.add p.y
    if includeZero and s.kind in {pkBar, pkArea}:
      ys.add 0.0
  span(ys)

proc layoutPlot*(series: seq[Series], area: Rect, includeZero: bool,
                 yMin = NaN, yMax = NaN): PlotLayout =
  ## Axis ranges and steps for `series`, drawn in `area`.
  let xr = xRangeOf(series)
  let yr = yRangeOf(series, includeZero)
  var ylo = if yMin.isNaN: yr.lo else: yMin
  var yhi = if yMax.isNaN: yr.hi else: yMax
  let ny = niceRange(ylo, yhi, 5)
  # Bars and categories sit at integer x: pad half a unit either side so the
  # outermost bar is not cut by the axis.
  var xlo = xr.lo
  var xhi = xr.hi
  var hasBars = false
  for s in series:
    if s.kind == pkBar: hasBars = true
  if hasBars:
    xlo -= 0.5
    xhi += 0.5
  let nx = niceRange(xlo, xhi, 6)
  PlotLayout(area: area, xLo: (if hasBars: xlo else: nx.lo),
             xHi: (if hasBars: xhi else: nx.hi), yLo: ny.lo, yHi: ny.hi,
             xStep: nx.step, yStep: ny.step)

proc toPixel*(l: PlotLayout, x, y: float): tuple[x, y: float32] =
  (float32(mapTo(x, l.xLo, l.xHi, l.area.x, l.area.x + l.area.width)),
   float32(mapTo(y, l.yLo, l.yHi, l.area.y + l.area.height, l.area.y)))

proc nearestPoint*(series: openArray[Series], l: PlotLayout,
                   x, y: float32): tuple[series, index: int] =
  ## The data point closest to (x, y) on screen, going by x first -- a
  ## pointer over a line chart means "the value here" -- then by distance.
  ## (-1, -1) when there is no data.
  result = (-1, -1)
  var best = Inf.float32
  for i, s in series:
    for j, p in s.points:
      let px = l.toPixel(p.x, p.y)
      let d = abs(px.x - x) * 4 + abs(px.y - y)
      if d < best:
        best = d
        result = (i, j)

template plotFrame*(widget: untyped): tuple[area: Rect, l: PlotLayout, tickStyle: TextStyle,
                                         titleStyle: TextStyle, lineH, legendH: float32] =
  ## The plot area inside the margins (tick labels, title, legend), and the
  ## scales over it. Painting and hover both use this, so a hover lands on
  ## what was drawn.
  block:
    let props = widget.themeProps(widget.intent)
    let ink = props.foregroundColor.get(BLACK)
    var tickStyle = props.captionStyle(ink)
    tickStyle.fontSize = max(10.0'f32, tickStyle.fontSize - 2)   # a little under the text size
    let titleStyle = props.captionStyle(ink, props.fontSize.get(14.0), action = true)
    let probe = layoutPlot(widget.series, widget.bounds, widget.includeZero,
                           widget.yMin, widget.yMax)
    var widest = 0.0'f32
    for t in ticksFor(probe.yLo, probe.yHi, probe.yStep):
      widest = max(widest, measureText(formatTick(t, probe.yStep), tickStyle).width)
    let lineH = measureText("Ag", tickStyle).height
    let titleH = if widget.title.len > 0: measureText(widget.title, titleStyle).height + 6 else: 0.0'f32
    let legendH = if widget.showLegend and widget.series.len > 1: lineH + 8 else: 0.0'f32
    let area = Rect(x: widget.bounds.x + widest + 12,
                    y: widget.bounds.y + titleH + 8,
                    width: max(1.0'f32, widget.bounds.width - widest - 24),
                    height: max(1.0'f32, widget.bounds.height - titleH - lineH - legendH - 20))
    (area, layoutPlot(widget.series, area, widget.includeZero, widget.yMin, widget.yMax),
     tickStyle, titleStyle, lineH, legendH)

definePrimitive(Plot):
  props:
    series: seq[Series] = @[]
    title: string = ""
    xLabels: seq[string] = @[]        # names for x = 0, 1, 2, ... (category charts)
    showGrid: bool = true
    showLegend: bool = true
    includeZero: bool = true          # bars and areas start at zero
    yMin: float = NaN                 # NaN: from the data
    yMax: float = NaN
    showReadout: bool = true          # the value under the pointer
    intent: ThemeIntent = Default

  state:
    hoverSeries: int                  # the point under the pointer; -1: none
    hoverIndex: int

  init:
    widget.hoverSeries = -1

  events:
    on_mouse_move:
      if not widget.showReadout:
        return false
      let f = widget.plotFrame
      let inside = f.area.contains(event.mousePos.x, event.mousePos.y)
      let hit = if inside: nearestPoint(widget.series, f.l, event.mousePos.x, event.mousePos.y)
                else: (-1, -1)
      if hit.series != widget.hoverSeries or hit.index != widget.hoverIndex:
        widget.hoverSeries = hit.series
        widget.hoverIndex = hit.index
        widget.isDirty = true
      return false

  layout:
    if widget.bounds.width <= 0:
      widget.bounds.width = 360.0f32
    if widget.bounds.height <= 0:
      widget.bounds.height = 220.0f32

  render:
    let props = widget.themeProps(widget.intent)
    let ink = props.foregroundColor.get(BLACK)
    let faint = ink.withAlpha(0.18)
    let frame = widget.plotFrame
    let tickStyle = frame.tickStyle
    let titleStyle = frame.titleStyle
    let line = max(2.0'f32, props.strokeWidth)

    # Margins: room for the y tick labels, the x ones, a title and a legend.
    let area = frame.area
    let l = frame.l
    let lineH = frame.lineH
    let legendH = frame.legendH

    if widget.title.len > 0:
      drawStyledText(widget.title, widget.bounds.x + 8, widget.bounds.y + 4, titleStyle)

    # Grid and tick labels.
    for t in ticksFor(l.yLo, l.yHi, l.yStep):
      let y = l.toPixel(l.xLo, t).y
      if widget.showGrid:
        drawLine(area.x, y, area.x + area.width, y, faint)
      let label = formatTick(t, l.yStep)
      drawStyledText(label, area.x - 6 - measureText(label, tickStyle).width,
                     y - tickStyle.fontSize / 2, tickStyle)
    if widget.xLabels.len > 0:
      for i, name in widget.xLabels:
        let x = l.toPixel(float(i), l.yLo).x
        drawStyledText(name, x, area.y + area.height + 4, tickStyle, centered = true)
    else:
      for t in ticksFor(l.xLo, l.xHi, l.xStep):
        let x = l.toPixel(t, l.yLo).x
        if widget.showGrid:
          drawLine(x, area.y, x, area.y + area.height, faint)
        drawStyledText(formatTick(t, l.xStep), x, area.y + area.height + 4,
                       tickStyle, centered = true)
    # Axes.
    drawLine(area.x, area.y + area.height, area.x + area.width, area.y + area.height, ink.withAlpha(0.6))
    drawLine(area.x, area.y, area.x, area.y + area.height, ink.withAlpha(0.6))

    # Bars share the width of one x unit between the bar series.
    var barCount = 0
    for s in widget.series:
      if s.kind == pkBar: inc barCount
    var barIndex = 0
    let unit = abs(l.toPixel(1.0, l.yLo).x - l.toPixel(0.0, l.yLo).x)
    let zeroY = l.toPixel(l.xLo, clamp(0.0, l.yLo, l.yHi)).y

    for i, s in widget.series:
      let color = seriesColor(widget.series, i)
      case s.kind
      of pkLine, pkArea:
        var prev: tuple[x, y: float32]
        for j, p in s.points:
          let px = l.toPixel(p.x, p.y)
          if s.kind == pkArea and j > 0:
            let a = Vector2(x: prev.x, y: prev.y)
            let b = Vector2(x: px.x, y: px.y)
            let c = Vector2(x: px.x, y: zeroY)
            let d = Vector2(x: prev.x, y: zeroY)
            let fill = color.withAlpha(0.25)
            drawTriangleAnyWinding(a, b, c, fill)
            drawTriangleAnyWinding(a, c, d, fill)
          if j > 0:
            drawLine(prev.x, prev.y, px.x, px.y, color, line)
          prev = px
        for p in s.points:       # dots over the joins, so a fat line stays round
          let px = l.toPixel(p.x, p.y)
          drawCircle(Vector2(x: px.x, y: px.y), line * 0.75, color)
      of pkScatter:
        for p in s.points:
          let px = l.toPixel(p.x, p.y)
          drawCircle(Vector2(x: px.x, y: px.y), max(4.5'f32, line * 2), color)
      of pkBar:
        let slot = unit * 0.8 / float32(max(1, barCount))
        for p in s.points:
          let px = l.toPixel(p.x, p.y)
          let left = px.x - unit * 0.4 + float32(barIndex) * slot
          let top = min(px.y, zeroY)
          let h = abs(zeroY - px.y)
          drawBox(Rect(x: left, y: top, width: max(1.0'f32, slot - 1), height: max(1.0'f32, h)),
                  min(props.cornerRadius.get(2.0), slot / 2), color, ink, 0)
        inc barIndex

    # Legend.
    if legendH > 0:
      var x = area.x
      let y = widget.bounds.y + widget.bounds.height - lineH - 4
      for i, s in widget.series:
        drawBox(Rect(x: x, y: y + 2, width: lineH - 4, height: lineH - 4), 2,
                seriesColor(widget.series, i), ink, 0)
        x += lineH
        drawStyledText(s.name, x, y, tickStyle)
        x += measureText(s.name, tickStyle).width + 14

    # The value under the pointer: a crosshair at the point, a dot on it,
    # and a label with the series and both values, kept inside the plot.
    if widget.showReadout and widget.hovered and widget.hoverSeries >= 0 and
       widget.hoverSeries < widget.series.len and
       widget.hoverIndex < widget.series[widget.hoverSeries].points.len:
      let s = widget.series[widget.hoverSeries]
      let p = s.points[widget.hoverIndex]
      let px = l.toPixel(p.x, p.y)
      let color = seriesColor(widget.series, widget.hoverSeries)
      drawLine(px.x, area.y, px.x, area.y + area.height, ink.withAlpha(0.35))
      drawCircle(Vector2(x: px.x, y: px.y), max(4.5'f32, line * 2) + 1.5, color)
      let xText = if widget.xLabels.len > 0 and p.x >= 0 and int(p.x) < widget.xLabels.len and
                     float(int(p.x)) == p.x: widget.xLabels[int(p.x)]
                  elif p.x == round(p.x): formatTick(p.x, 1.0)     # whole numbers stay whole
                  else: formatTick(p.x, l.xStep / 10)
      let label = (if s.name.len > 0: s.name & ": " else: "") & xText & ", " &
                  formatTick(p.y, l.yStep / 10)
      let size = measureText(label, tickStyle)
      var bx = px.x + 10
      var by = px.y - size.height - 12
      if bx + size.width + 12 > area.x + area.width: bx = px.x - size.width - 22
      if by < area.y: by = px.y + 10
      let box = Rect(x: bx, y: by, width: size.width + 12, height: size.height + 6)
      drawBox(box, 4, props.backgroundColor.get(WHITE), color, max(1.0'f32, props.strokeWidth))
      drawStyledText(label, box.x + 6, box.y + 3, tickStyle)
