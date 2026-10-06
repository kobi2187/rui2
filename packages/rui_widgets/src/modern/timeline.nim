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

template maxScrollOf(widget: untyped): float32 =
  ## How far the view can pan: the whole range less what fits.
  block:
    let seconds = float32((widget.endTime - widget.startTime).inSeconds)
    let width = seconds * widget.pixelsPerUnit / float32(secondsPerUnit(widget.scale))
    max(0.0'f32, width - widget.bounds.width)

template panTo(widget: untyped, offset: float32) =
  ## Pan within the range, telling whoever listens.
  block:
    let limit = widget.maxScrollOf
    let o = clamp(float32(offset), 0.0'f32, limit)
    if o != widget.scrollOffset:
      widget.scrollOffset = o
      widget.isDirty = true
      if widget.onScroll != nil:
        widget.onScroll(o)

template zoomAt(widget: untyped, factor: float32, atX: float32) =
  ## Scale the time axis by `factor`, keeping the instant under `atX` where
  ## it is on screen.
  block:
    let anchor = atX - widget.bounds.x + widget.scrollOffset   # content x
    let next = clamp(widget.pixelsPerUnit * factor, 4.0'f32, 4000.0'f32)
    let real = next / widget.pixelsPerUnit
    widget.pixelsPerUnit = next
    widget.panTo(anchor * real - (atX - widget.bounds.x))
    widget.isDirty = true

template showEvent(widget: untyped, index: int) =
  ## Select event `index` and pan so it is in view.
  block:
    let evt = widget.events[index]
    widget.selectedEvent = evt.id
    let r = axisOf(widget).eventRectFor(index, evt)
    if r.x < widget.bounds.x:
      widget.panTo(widget.scrollOffset - (widget.bounds.x - r.x) - 16)
    elif r.x + min(r.width, widget.bounds.width / 2) > widget.bounds.x + widget.bounds.width:
      widget.panTo(widget.scrollOffset + (r.x + min(r.width, widget.bounds.width / 2)) -
                   (widget.bounds.x + widget.bounds.width) + 16)
    widget.isDirty = true

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
          if widget.onEventClick != nil:
            widget.onEventClick(evt)
          return true
      # Empty space starts a pan.
      widget.isDragging = true
      widget.dragStartX = event.mousePos.x + widget.scrollOffset
      return true

    on_mouse_move:
      if widget.isDragging:
        widget.panTo(widget.dragStartX - event.mousePos.x)
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
      # The wheel pans; with Ctrl it zooms about the pointer. At the ends of
      # the range a plain wheel is left to an enclosing scroll view.
      if event.ctrl:
        widget.zoomAt(if event.wheelDelta > 0: 1.25'f32 else: 0.8'f32, event.mousePos.x)
        return true
      let before = widget.scrollOffset
      widget.panTo(widget.scrollOffset - event.wheelDelta * 40.0)
      return widget.scrollOffset != before

    on_key_down:
      # Left/Right pan, Home/End to the ends of the range, +/- zoom about
      # the middle; Up/Down select the previous/next event and bring it into
      # view; Enter opens the selected one.
      if not widget.focused:
        return false
      let middle = widget.bounds.x + widget.bounds.width / 2
      var at = -1
      for i, evt in widget.events:
        if evt.id == widget.selectedEvent: at = i
      case event.key
      of KeyboardKey.Left: widget.panTo(widget.scrollOffset - widget.pixelsPerUnit)
      of KeyboardKey.Right: widget.panTo(widget.scrollOffset + widget.pixelsPerUnit)
      of KeyboardKey.Home: widget.panTo(0.0'f32)
      of KeyboardKey.End: widget.panTo(widget.maxScrollOf)
      of KeyboardKey.Equal, KeyboardKey.KpAdd: widget.zoomAt(1.25, middle)
      of KeyboardKey.Minus, KeyboardKey.KpSubtract: widget.zoomAt(0.8, middle)
      of KeyboardKey.Down, KeyboardKey.Up:
        if widget.events.len == 0: return false
        let next = if at < 0: 0
                   elif event.key == KeyboardKey.Down: min(widget.events.high, at + 1)
                   else: max(0, at - 1)
        widget.showEvent(next)
      of KeyboardKey.Enter, KeyboardKey.KpEnter:
        if at >= 0 and widget.onEventClick != nil:
          widget.onEventClick(widget.events[at])
      else:
        return false
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
