## Timeline Widget - RUI2
##
## Visual timeline for displaying chronological events.
## Supports horizontal time axis, event blocks, and interactive selection.
## Useful for scheduling, project management, history visualization.

import ../../core/widget_dsl_v3
import std/[options, times, json, algorithm, math, strformat]

when defined(useGraphics):
  import raylib

type
  TimelineEvent* = object
    id*: string
    title*: string
    description*: string
    startTime*: DateTime
    endTime*: DateTime         # For duration events
    color*: Color
    isDuration*: bool          # True if has duration, false if instant
    data*: JsonNode           # Custom data

  TimeScale* = enum
    tsMinute = "Minutes"
    tsHour = "Hours"
    tsDay = "Days"
    tsWeek = "Weeks"
    tsMonth = "Months"
    tsYear = "Years"

  TimelineOrientation* = enum
    toHorizontal
    toVertical

defineWidget(Timeline):
  props:
    events: seq[TimelineEvent]
    startTime: DateTime
    endTime: DateTime
    scale: TimeScale = tsHour
    pixelsPerUnit: float = 60.0      # Pixels per hour/day/etc
    orientation: TimelineOrientation = toHorizontal
    eventHeight: float = 40.0
    eventSpacing: float = 8.0
    showGrid: bool = true
    showTimeLabels: bool = true
    showNowMarker: bool = true
    gridColor: Color = Color(r: 230, g: 230, b: 230, a: 255)
    labelColor: Color = Color(r: 100, g: 100, b: 100, a: 255)
    nowMarkerColor: Color = Color(r: 255, g: 100, b: 100, a: 255)
    backgroundColor: Color = Color(r: 255, g: 255, b: 255, a: 255)

  state:
    scrollOffset: float
    selectedEvent: string         # Selected event ID
    hoverEvent: string           # Hovered event ID
    visibleEvents: seq[TimelineEvent]  # Events in viewport
    isDragging: bool
    dragStartX: float
    dragStartY: float

  actions:
    onEventClick(event: TimelineEvent)
    onEventDoubleClick(event: TimelineEvent)
    onEventDrag(event: TimelineEvent, newStart: DateTime, newEnd: DateTime)
    onScroll(offset: float)
    onTimeRangeChanged(start: DateTime, endTime: DateTime)

  layout:
    discard

  render:
    when defined(useGraphics):
      # Draw background
      DrawRectangleRec(widget.bounds, widget.backgroundColor)

      # Calculate time range and scale
      let totalDuration = (widget.endTime - widget.startTime)
      let timeRangeSeconds = totalDuration.inSeconds.float

      # Calculate pixels per second based on scale
      let pixelsPerSecond = case widget.scale
                           of tsMinute: widget.pixelsPerUnit / 60.0
                           of tsHour: widget.pixelsPerUnit / 3600.0
                           of tsDay: widget.pixelsPerUnit / 86400.0
                           of tsWeek: widget.pixelsPerUnit / 604800.0
                           of tsMonth: widget.pixelsPerUnit / 2592000.0  # ~30 days
                           of tsYear: widget.pixelsPerUnit / 31536000.0   # ~365 days

      let totalWidth = timeRangeSeconds * pixelsPerSecond
      let scroll = widget.scrollOffset

      # Begin scissor mode for clipping
      BeginScissorMode(
        widget.bounds.x.cint,
        widget.bounds.y.cint,
        widget.bounds.width.cint,
        widget.bounds.height.cint
      )

      # Time to pixel conversion
      proc timeToPixel(time: DateTime): float =
        let secondsFromStart = (time - widget.startTime).inSeconds.float
        widget.bounds.x + (secondsFromStart * pixelsPerSecond) - scroll

      proc pixelToTime(pixel: float): DateTime =
        let secondsFromStart = (pixel - widget.bounds.x + scroll) / pixelsPerSecond
        widget.startTime + initDuration(seconds = secondsFromStart.int64)

      # Draw time grid and labels
      if widget.showGrid or widget.showTimeLabels:
        let timelineY = widget.bounds.y + 30.0  # Leave space for time labels

        # Determine grid interval based on scale
        let gridInterval = case widget.scale
                          of tsMinute: initDuration(minutes = 5)
                          of tsHour: initDuration(hours = 1)
                          of tsDay: initDuration(days = 1)
                          of tsWeek: initDuration(weeks = 1)
                          of tsMonth: initDuration(days = 30)
                          of tsYear: initDuration(days = 365)

        var currentTime = widget.startTime
        while currentTime <= widget.endTime:
          let x = timeToPixel(currentTime)

          # Only draw if in viewport
          if x >= widget.bounds.x and x <= widget.bounds.x + widget.bounds.width:
            # Draw grid line
            if widget.showGrid:
              DrawLineEx(
                Vector2(x: x, y: timelineY),
                Vector2(x: x, y: widget.bounds.y + widget.bounds.height),
                1.0,
                widget.gridColor
              )

            # Draw time label
            if widget.showTimeLabels:
              let timeLabel = case widget.scale
                             of tsMinute, tsHour: currentTime.format("HH:mm")
                             of tsDay: currentTime.format("MMM dd")
                             of tsWeek, tsMonth: currentTime.format("MMM dd")
                             of tsYear: currentTime.format("yyyy")

              DrawText(
                timeLabel.cstring,
                (x + 4.0).cint,
                (widget.bounds.y + 5.0).cint,
                10,
                widget.labelColor
              )

          currentTime = currentTime + gridInterval

      # Draw "now" marker
      if widget.showNowMarker:
        let now = now()
        if now >= widget.startTime and now <= widget.endTime:
          let nowX = timeToPixel(now)
          if nowX >= widget.bounds.x and nowX <= widget.bounds.x + widget.bounds.width:
            DrawLineEx(
              Vector2(x: nowX, y: widget.bounds.y + 30.0),
              Vector2(x: nowX, y: widget.bounds.y + widget.bounds.height),
              2.0,
              widget.nowMarkerColor
            )

            # Draw "NOW" label
            DrawText(
              "NOW".cstring,
              (nowX - 15.0).cint,
              (widget.bounds.y + 32.0).cint,
              10,
              widget.nowMarkerColor
            )

      # Draw events
      let mousePos = GetMousePosition()
      let mouseInBounds = CheckCollisionPointRec(mousePos, widget.bounds)
      var newHoverEvent = ""

      let eventAreaY = widget.bounds.y + 50.0  # Below time labels

      for eventIdx, event in widget.events:
        let startX = timeToPixel(event.startTime)
        let endX = if event.isDuration:
                    timeToPixel(event.endTime)
                  else:
                    startX + 4.0  # Small marker for instant events

        # Skip if completely outside viewport
        if endX < widget.bounds.x or startX > widget.bounds.x + widget.bounds.width:
          continue

        let eventRect = Rectangle(
          x: max(startX, widget.bounds.x),
          y: eventAreaY + (eventIdx.float * (widget.eventHeight + widget.eventSpacing)),
          width: max(endX - startX, 4.0),
          height: widget.eventHeight
        )

        # Check hover
        if mouseInBounds and CheckCollisionPointRec(mousePos, eventRect):
          newHoverEvent = event.id

        # Draw event block
        let isSelected = event.id == widget.selectedEvent
        let isHovered = event.id == widget.hoverEvent

        var displayColor = event.color
        if isSelected:
          # Brighten selected event
          displayColor = Color(
            r: min(255, event.color.r + 30),
            g: min(255, event.color.g + 30),
            b: min(255, event.color.b + 30),
            a: event.color.a
          )
        elif isHovered:
          # Slightly brighten hovered event
          displayColor = Color(
            r: min(255, event.color.r + 15),
            g: min(255, event.color.g + 15),
            b: min(255, event.color.b + 15),
            a: event.color.a
          )

        DrawRectangleRounded(
          eventRect,
          0.2,
          8,
          displayColor
        )

        # Draw event border
        DrawRectangleRoundedLines(
          eventRect,
          0.2,
          8,
          1.5,
          Color(
            r: max(0, event.color.r - 50),
            g: max(0, event.color.g - 50),
            b: max(0, event.color.b - 50),
            a: 255
          )
        )

        # Draw event title (clipped to event width)
        if eventRect.width > 20.0:
          let textY = eventRect.y + (widget.eventHeight / 2.0) - 7.0
          DrawText(
            event.title.cstring,
            (eventRect.x + 4.0).cint,
            textY.cint,
            12,
            Color(r: 255, g: 255, b: 255, a: 255)
          )

        # Handle click
        if mouseInBounds and IsMouseButtonPressed(MOUSE_LEFT_BUTTON):
          if CheckCollisionPointRec(mousePos, eventRect):
            widget.selectedEvent = event.id

            if widget.onEventClick.isSome:
              widget.onEventClick.get()(event)

        # Handle double-click (simplified)
        # In real impl, track click timing
        # if mouseInBounds and IsMouseButtonPressed(MOUSE_LEFT_BUTTON):
        #   if CheckCollisionPointRec(mousePos, eventRect):
        #     if widget.onEventDoubleClick.isSome:
        #       widget.onEventDoubleClick.get()(event)

      widget.hoverEvent = newHoverEvent

      EndScissorMode()

      # Draw scrollbar if content wider than viewport
      if totalWidth > widget.bounds.width:
        let scrollbarH = 12.0
        let scrollbarRect = Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y + widget.bounds.height - scrollbarH,
          width: widget.bounds.width,
          height: scrollbarH
        )

        # Scrollbar track
        DrawRectangleRec(scrollbarRect, Color(r: 230, g: 230, b: 230, a: 255))

        # Scrollbar thumb
        let thumbWidth = max(30.0, widget.bounds.width * (widget.bounds.width / totalWidth))
        let maxScroll = max(0.0, totalWidth - widget.bounds.width)
        let thumbX = widget.bounds.x + (scroll / maxScroll) * (widget.bounds.width - thumbWidth)

        let thumbRect = Rectangle(
          x: thumbX,
          y: scrollbarRect.y + 2.0,
          width: thumbWidth,
          height: scrollbarH - 4.0
        )

        DrawRectangleRec(thumbRect, Color(r: 150, g: 150, b: 150, a: 255))

        # Handle scrollbar dragging
        if mouseInBounds and IsMouseButtonDown(MOUSE_LEFT_BUTTON):
          if CheckCollisionPointRec(mousePos, scrollbarRect):
            let newScroll = ((mousePos.x - widget.bounds.x) / widget.bounds.width) * maxScroll
            widget.scrollOffset = clamp(newScroll, 0.0, maxScroll)

            if widget.onScroll.isSome:
              widget.onScroll.get()(newScroll)

      # Handle mouse wheel scrolling
      if mouseInBounds:
        let wheel = GetMouseWheelMove()
        if wheel != 0.0:
          let maxScroll = max(0.0, totalWidth - widget.bounds.width)
          let newScroll = widget.scrollOffset - (wheel * widget.pixelsPerUnit)
          widget.scrollOffset = clamp(newScroll, 0.0, maxScroll)

          if widget.onScroll.isSome:
            widget.onScroll.get()(newScroll)

      # Draw border
      DrawRectangleLinesEx(
        widget.bounds,
        1.0,
        Color(r: 180, g: 180, b: 180, a: 255)
      )

    else:
      # Non-graphics mode
      echo "Timeline:"
      echo "  Time range: ", widget.startTime.format("yyyy-MM-dd HH:mm"), " to ", widget.endTime.format("yyyy-MM-dd HH:mm")
      echo "  Scale: ", widget.scale
      echo "  Events: ", widget.events.len
      echo "  Selected: ", widget.selectedEvent
      echo "  Scroll: ", widget.scrollOffset

      for event in widget.events:
        let marker = if event.id == widget.selectedEvent: "[X]" else: "[ ]"
        let timeStr = event.startTime.format("HH:mm")
        let durationStr = if event.isDuration:
                           " -> " & event.endTime.format("HH:mm")
                         else:
                           ""
        echo "  ", marker, " ", timeStr, durationStr, " - ", event.title
