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
import timeline_axis
export timeline_axis

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
