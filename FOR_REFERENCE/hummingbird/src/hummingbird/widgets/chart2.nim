
# Chart widget
defineWidget Chart:
  props:
    data: seq[ChartPoint]
    xAxis: Axis
    yAxis: Axis
    series: seq[Series]
    legend: bool
    grid: bool

  type
    ChartPoint* = object
      x*, y*: float64
      label*: string

    Axis* = object
      title*: string
      min*, max*: float64
      step*: float64
      format*: proc(value: float64): string

    Series* = object
      name*: string
      color*: Color
      lineWidth*: float32
      pointSize*: float32

  render:
    # Draw axes
    drawAxis(widget.xAxis, widget.yAxis)

    # Draw grid if enabled
    if widget.grid:
      drawGrid(widget.xAxis, widget.yAxis)

    # Draw data series
    for series in widget.series:
      drawSeries(widget.data, series)

    # Draw legend if enabled
    if widget.legend:
      drawLegend(widget.series)