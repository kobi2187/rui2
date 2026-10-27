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
import ../value_input
import ../pointers
import ../view_range
import rui_drawing
import std/[options, times, json]

import raylib
import timeline_axis
export timeline_axis

template secondsPerUnitOf(widget: untyped): float =
  secondsPerUnit(widget.scale)

template viewOf(widget: untyped): AxisView =
  ## The time axis as drawn: seconds from `startTime`, resolved at this width.
  widget.view.resolved(widget.bounds.width)

template axisOf*(widget: untyped): TimelineAxis =
  ## The widget's current projection. A template rather than a proc because the
  ## Timeline type does not exist yet at this point in the file, and the widget
  ## body below needs this.
  block:
    let v = viewOf(widget)
    TimelineAxis(
      originX: widget.bounds.x,
      areaTop: widget.bounds.y + EventAreaTop,
      startTime: widget.startTime,
      pixelsPerSecond: float32(1 / v.perPixel),
      scrollOffset: float32((v.start - v.lo) / v.perPixel),
      eventHeight: widget.eventHeight,
      eventSpacing: widget.eventSpacing)

template settle(widget: untyped, before: AxisView) =
  ## After the view may have moved: the zoom readable as `pixelsPerUnit`
  ## again, and `onScroll` told of a pan.
  block:
    let v = viewOf(widget)
    widget.pixelsPerUnit = float32(widget.secondsPerUnitOf / v.perPixel)
    widget.shownZoom = widget.pixelsPerUnit
    if v.start != before.start:
      widget.isDirty = true
      if widget.onScroll != nil:
        widget.onScroll(float32((v.start - v.lo) / v.perPixel))

template showEvent(widget: untyped, index: int) =
  ## Select event `index` and pan so it is in view.
  block:
    let evt = widget.events[index]
    widget.selectedEvent = evt.id
    let r = axisOf(widget).eventRectFor(index, evt)
    let w = widget.bounds.width
    if r.x < widget.bounds.x:
      widget.view.value = viewOf(widget).pannedBy(-((widget.bounds.x - r.x) + 16), w)
    elif r.x + min(r.width, w / 2) > widget.bounds.x + w:
      widget.view.value = viewOf(widget).pannedBy(
        (r.x + min(r.width, w / 2)) - (widget.bounds.x + w) + 16, w)
    widget.isDirty = true

definePrimitive(Timeline):
  props:
    events: seq[TimelineEvent] = @[]
    startTime: DateTime
    endTime: DateTime
    scale: TimeScale = tsHour
    pixelsPerUnit: float32 = 60.0    # Pixels per hour / day / ...: the zoom
    eventHeight: float32 = 40.0
    eventSpacing: float32 = 8.0
    showGrid: bool = true
    showTimeLabels: bool = true
    showNowMarker: bool = true
    view: Link[AxisView] = nil       # seconds from startTime; share it to move with other widgets
    intent: ThemeIntent = Default

  state:
    selectedEvent: string        # Event ID
    hoverEvent: string           # Event ID
    input: ViewInput             # drag, pinch (view_range.nim)
    shownZoom: float32           # pixelsPerUnit as last applied to the view

  actions:
    onEventClick(event: TimelineEvent)
    onScroll(offset: float32)

  init:
    widget.focusable = true
    widget.multiPointer = true
    # An unset range (year 0) would crash every time calculation: use one day.
    if widget.startTime.isUnset: widget.startTime = dateTime(2000, mJan, 1, zone = utc())
    if widget.endTime.isUnset: widget.endTime = dateTime(2000, mJan, 2, zone = utc())
    if widget.view == nil:
      let spu = widget.secondsPerUnitOf
      widget.view = newLink(fixedView(
        0.0, float((widget.endTime - widget.startTime).inSeconds), 0.0,
        spu / widget.pixelsPerUnit, minPerPixel = spu / 4000, maxPerPixel = spu / 4))
    widget.shownZoom = widget.pixelsPerUnit
    widget.followView(widget.view)

  events:
    on_mouse_down:
      if event.pointerId == 0 and widget.input.fingers.count == 0:
        let axis = axisOf(widget)
        for i, evt in widget.events:
          if axis.eventRectFor(i, evt).contains(event.mousePos.x, event.mousePos.y):
            widget.selectedEvent = evt.id
            widget.isDirty = true
            if widget.onEventClick != nil:
              widget.onEventClick(evt)
            return true
      # Empty space starts a pan; a second finger a pinch.
      return widget.input.viewDown(widget, event)

    on_mouse_move:
      let before = viewOf(widget)
      if widget.input.viewMove(widget.view, event, widget.bounds.x, widget.bounds.width):
        widget.settle(before)
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
      return widget.input.viewUp(event)

    on_mouse_wheel:
      # The wheel pans; with Ctrl it zooms about the pointer. At the ends of
      # the range a plain wheel is left to an enclosing scroll view.
      let before = viewOf(widget)
      let used = viewWheel(widget.view, event, widget.bounds.x, widget.bounds.width)
      widget.settle(before)
      return used

    on_key_down:
      # Left/Right pan a unit, Home/End to the ends of the range, +/- zoom
      # about the middle (view_range); Up/Down select the previous/next event
      # and bring it into view; Enter opens the selected one.
      if not widget.focused:
        return false
      let before = viewOf(widget)
      var at = -1
      for i, evt in widget.events:
        if evt.id == widget.selectedEvent: at = i
      case event.key
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
        if not viewKey(widget.view, event, widget.bounds.x, widget.bounds.width,
                       step = widget.pixelsPerUnit):
          return false
      widget.settle(before)
      return true

  layout:
    if widget.pixelsPerUnit != widget.shownZoom and widget.pixelsPerUnit > 0:
      # The zoom was set from outside: the view takes it, keeping its start.
      var v = viewOf(widget)
      v.fitted = false
      v.perPixel = widget.secondsPerUnitOf / widget.pixelsPerUnit
      widget.view.value = v
      widget.shownZoom = widget.pixelsPerUnit
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
      if evt.spans:
        drawThemedPaddedText(evt.title, r, evtProps, selected = state == Selected)

    endClip(clip)
    drawThemedBorder(widget.bounds, props, widget.focused)

proc scrollOffset*(widget: Timeline): float32 =
  ## How far the view is panned from `startTime`, in pixels.
  let v = viewOf(widget)
  float32((v.start - v.lo) / v.perPixel)

proc isDragging*(widget: Timeline): bool =
  ## A drag is panning the view.
  widget.input.panning

proc axis*(widget: Timeline): TimelineAxis =
  ## The widget's current projection, for callers outside this module.
  axisOf(widget)
