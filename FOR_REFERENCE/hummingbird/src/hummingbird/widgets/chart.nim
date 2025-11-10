# Chart/Graph widget
defineWidget Chart:
  props:
    kind*: ChartKind
    data*: seq[ChartPoint]
    xAxis*: Axis
    yAxis*: Axis
    showGrid*: bool
    showLegend*: bool

  type
    ChartKind* = enum
      ckLine, ckBar, ckPie, ckScatter

    ChartPoint* = object
      x*, y*: float
      label*: string
      color*: Color

    Axis* = object
      title*: string
      min*, max*: float
      step*: float
      format*: proc(value: float): string

  render:
    # Draw axes
    if widget.showGrid:
      # Draw grid lines
      let xRange = widget.xAxis.max - widget.xAxis.min
      let yRange = widget.yAxis.max - widget.yAxis.min

      for x in countup(widget.xAxis.min, widget.xAxis.max, widget.xAxis.step):
        let screenX = widget.dataToScreenX(x)
        DrawLine(
          screenX.int32, widget.rect.y.int32,
          screenX.int32, (widget.rect.y + widget.rect.height).int32,
          fade(GRAY, 0.2)
        )

      for y in countup(widget.yAxis.min, widget.yAxis.max, widget.yAxis.step):
        let screenY = widget.dataToScreenY(y)
        DrawLine(
          widget.rect.x.int32, screenY.int32,
          (widget.rect.x + widget.rect.width).int32, screenY.int32,
          fade(GRAY, 0.2)
        )

    # Draw data
    case widget.kind
    of ckLine:
      var lastPoint: Option[ChartPoint]
      for point in widget.data:
        let screenX = widget.dataToScreenX(point.x)
        let screenY = widget.dataToScreenY(point.y)

        if lastPoint.isSome:
          DrawLine(
            widget.dataToScreenX(lastPoint.get.x).int32,
            widget.dataToScreenY(lastPoint.get.y).int32,
            screenX.int32,
            screenY.int32,
            point.color
          )

        DrawCircle(screenX.int32, screenY.int32, 3, point.color)
        lastPoint = some(point)

    of ckBar:
      let barWidth = widget.rect.width / widget.data.len.float32
      for i, point in widget.data:
        let screenX = widget.rect.x + i.float32 * barWidth
        let screenY = widget.dataToScreenY(point.y)
        DrawRectangle(
          screenX.int32,
          screenY.int32,
          barWidth.int32,
          (widget.rect.y + widget.rect.height - screenY).int32,
          point.color
        )

    of ckPie:
      var startAngle = 0.0
      let total = sum(widget.data.mapIt(it.y))
      let center = Point(
        x: widget.rect.x + widget.rect.width/2,
        y: widget.rect.y + widget.rect.height/2
      )
      let radius = min(widget.rect.width, widget.rect.height)/2

      for point in widget.data:
        let slice = point.y / total * 360.0
        DrawCircleSector(
          Vector2(x: center.x, y: center.y),
          radius,
          startAngle,
          startAngle + slice,
          36,
          point.color
        )
        startAngle += slice

    of ckScatter:
      for point in widget.data:
        let screenX = widget.dataToScreenX(point.x)
        let screenY = widget.dataToScreenY(point.y)
        DrawCircle(screenX.int32, screenY.int32, 3, point.color)

