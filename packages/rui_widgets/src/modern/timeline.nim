## Timeline Widget - RUI2
##
## Chronological event track: a time axis with grid and labels, event blocks for
## durations, markers for instants, and a "now" line.
##
## Hit-testing and painting share `eventRectFor`, so a click always lands on the
## block the user actually saw. The pre-split version computed event rectangles
## inline in `render` and polled the mouse there too, which meant selection only
## updated on frames that happened to repaint.

import rui_core
import rui_drawing
import std/[options, times, json]

import raylib

type
  TimelineEvent* = object
    id*: string
    title*: string
    description*: string
    startTime*: DateTime
    endTime*: DateTime         # Only meaningful when isDuration
    color*: Color
    isDuration*: bool
    data*: JsonNode

  TimeScale* = enum
    tsMinute = "Minutes"
    tsHour = "Hours"
    tsDay = "Days"
    tsWeek = "Weeks"
    tsMonth = "Months"
    tsYear = "Years"

const
  AxisHeight = 30.0'f32        ## Time labels live above this line.
  EventAreaTop = 50.0'f32      ## First event row starts here.
  InstantWidth = 4.0'f32

proc secondsPerUnit(scale: TimeScale): float =
  ## Seconds in one unit of `scale`. Month and year are the usual approximations.
  case scale
  of tsMinute: 60.0
  of tsHour: 3600.0
  of tsDay: 86_400.0
  of tsWeek: 604_800.0
  of tsMonth: 2_592_000.0      # 30 days
  of tsYear: 31_536_000.0      # 365 days

proc gridInterval(scale: TimeScale): Duration =
  case scale
  of tsMinute: initDuration(minutes = 5)
  of tsHour: initDuration(hours = 1)
  of tsDay: initDuration(days = 1)
  of tsWeek: initDuration(weeks = 1)
  of tsMonth: initDuration(days = 30)
  of tsYear: initDuration(days = 365)

proc labelFormat(scale: TimeScale): string =
  case scale
  of tsMinute, tsHour: "HH:mm"
  of tsDay, tsWeek, tsMonth: "MMM dd"
  of tsYear: "yyyy"

type
  TimelineAxis* = object
    ## The time-to-pixel projection, pulled out of the widget so the geometry
    ## helpers can be defined before it. A proc taking `Timeline` cannot be:
    ## the type does not exist until definePrimitive has expanded, and the
    ## widget's own body needs these helpers.
    originX*: float32
    areaTop*: float32
    startTime*: DateTime
    pixelsPerSecond*: float32
    scrollOffset*: float32
    eventHeight*: float32
    eventSpacing*: float32

proc timeToPixel*(axis: TimelineAxis, time: DateTime): float32 =
  ## Screen x for an instant, taking the pan offset into account.
  let secondsFromStart = float32((time - axis.startTime).inSeconds)
  axis.originX + secondsFromStart * axis.pixelsPerSecond - axis.scrollOffset

proc pixelToTime*(axis: TimelineAxis, pixel: float32): DateTime =
  ## The instant under a screen x.
  let seconds = if axis.pixelsPerSecond == 0: 0.0
                else: float((pixel - axis.originX + axis.scrollOffset) /
                            axis.pixelsPerSecond)
  axis.startTime + initDuration(seconds = int64(seconds))

proc eventRectFor*(axis: TimelineAxis, index: int, evt: TimelineEvent): Rect =
  ## Where event `index` is drawn. Hit-testing and painting both call this, so a
  ## click can never land somewhere other than what was drawn.
  let startX = axis.timeToPixel(evt.startTime)
  let endX = if evt.isDuration: axis.timeToPixel(evt.endTime)
             else: startX + InstantWidth
  Rect(
    x: startX,
    y: axis.areaTop + float32(index) * (axis.eventHeight + axis.eventSpacing),
    width: max(endX - startX, InstantWidth),
    height: axis.eventHeight
  )

template axisOf*(widget: untyped): TimelineAxis =
  ## The widget's current projection. A template rather than a proc because the
  ## Timeline type does not exist yet at this point in the file, and the widget
  ## body below needs this.
  TimelineAxis(
    originX: widget.bounds.x,
    areaTop: widget.bounds.y + EventAreaTop,
    startTime: widget.startTime,
    pixelsPerSecond: widget.pixelsPerUnit / float32(secondsPerUnit(widget.scale)),
    scrollOffset: widget.scrollOffset,
    eventHeight: widget.eventHeight,
    eventSpacing: widget.eventSpacing
  )

definePrimitive(Timeline):
  props:
    events: seq[TimelineEvent] = @[]
    startTime: DateTime
    endTime: DateTime
    scale: TimeScale = tsHour
    pixelsPerUnit: float32 = 60.0    # Pixels per hour / day / ...
    eventHeight: float32 = 40.0
    eventSpacing: float32 = 8.0
    showGrid: bool = true
    showTimeLabels: bool = true
    showNowMarker: bool = true
    intent: ThemeIntent = Default

  state:
    scrollOffset: float32
    selectedEvent: string        # Event ID
    hoverEvent: string           # Event ID
    isDragging: bool
    dragStartX: float32

  actions:
    onEventClick(event: TimelineEvent)
    onScroll(offset: float32)

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      let axis = axisOf(widget)
      for i, evt in widget.events:
        if axis.eventRectFor(i, evt).contains(event.mousePos.x, event.mousePos.y):
          widget.selectedEvent = evt.id
          widget.isDirty = true
          if widget.onEventClick.isSome:
            widget.onEventClick.get()(evt)
          return true
      # Empty space starts a pan.
      widget.isDragging = true
      widget.dragStartX = event.mousePos.x + widget.scrollOffset
      return true

    on_mouse_move:
      if widget.isDragging:
        let newOffset = max(0.0'f32, widget.dragStartX - event.mousePos.x)
        if newOffset != widget.scrollOffset:
          widget.scrollOffset = newOffset
          widget.isDirty = true
          if widget.onScroll.isSome:
            widget.onScroll.get()(newOffset)
        return true

      let axis = axisOf(widget)
      var newHover = ""
      for i, evt in widget.events:
        if axis.eventRectFor(i, evt).contains(event.mousePos.x, event.mousePos.y):
          newHover = evt.id
          break
      if newHover != widget.hoverEvent:
        widget.hoverEvent = newHover
        widget.isDirty = true
      return false

    on_mouse_up:
      if widget.isDragging:
        widget.isDragging = false
        return true
      return false

    on_mouse_wheel:
      let newOffset = max(0.0'f32, widget.scrollOffset - event.wheelDelta * 40.0)
      if newOffset != widget.scrollOffset:
        widget.scrollOffset = newOffset
        widget.isDirty = true
        if widget.onScroll.isSome:
          widget.onScroll.get()(newOffset)
      return true

  layout:
    if widget.bounds.width <= 0:
      widget.bounds.width = 600.0'f32
    if widget.bounds.height <= 0:
      widget.bounds.height = EventAreaTop +
        float32(widget.events.len) * (widget.eventHeight + widget.eventSpacing)

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    drawThemedBackground(widget.bounds, props)

    let axis = axisOf(widget)

    let gridColor = props.borderColor.get(Color(r: 230, g: 230, b: 230, a: 255))
    let labelColor = props.foregroundColor.get(Color(r: 100, g: 100, b: 100, a: 255))
    let axisY = widget.bounds.y + AxisHeight
    let bottom = widget.bounds.y + widget.bounds.height
    let clip = beginClip(widget.bounds)

    if widget.showGrid or widget.showTimeLabels:
      let interval = gridInterval(widget.scale)
      let fmt = labelFormat(widget.scale)
      var current = widget.startTime
      while current <= widget.endTime:
        let x = axis.timeToPixel(current)
        if x >= widget.bounds.x and x <= widget.bounds.x + widget.bounds.width:
          if widget.showGrid:
            drawLine(x, axisY, x, bottom, gridColor)
          if widget.showTimeLabels:
            drawText(current.format(fmt), x + 4.0, widget.bounds.y + 5.0,
                     10.0, labelColor)
        current = current + interval

    if widget.showNowMarker:
      let rightNow = now()
      if rightNow >= widget.startTime and rightNow <= widget.endTime:
        let nowX = axis.timeToPixel(rightNow)
        if nowX >= widget.bounds.x and nowX <= widget.bounds.x + widget.bounds.width:
          let markerColor = Color(r: 255, g: 100, b: 100, a: 255)
          drawLine(nowX, axisY, nowX, bottom, markerColor, 2.0)
          drawText("NOW", nowX - 15.0, axisY + 2.0, 10.0, markerColor)

    for i, evt in widget.events:
      let r = axis.eventRectFor(i, evt)
      if r.x + r.width < widget.bounds.x or r.x > widget.bounds.x + widget.bounds.width:
        continue

      let state = if evt.id == widget.selectedEvent: Selected
                  elif evt.id == widget.hoverEvent: Hovered
                  else: Normal
      let evtProps = currentTheme.getThemeProps(widget.intent, state)

      drawRect(r, evt.color)
      if state != Normal:
        drawThemedBorder(r, evtProps, focused = state == Selected)
      if evt.isDuration:
        drawThemedPaddedText(evt.title, r, evtProps, selected = state == Selected)

    endClip(clip)
    drawThemedBorder(widget.bounds, props, widget.focused)

proc axis*(widget: Timeline): TimelineAxis =
  ## The widget's current projection, for callers outside this module.
  axisOf(widget)
