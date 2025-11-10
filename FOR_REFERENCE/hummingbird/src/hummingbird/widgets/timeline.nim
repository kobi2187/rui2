
# Timeline/scheduling widget
defineWidget Timeline:
  props:
    startTime: DateTime
    endTime: DateTime
    events: seq[TimelineEvent]
    scale: float32  # Pixels per hour
    onEventClick: proc(event: TimelineEvent)
    onEventDrag: proc(event: TimelineEvent, newStart: DateTime)

  type TimelineEvent* = object
    id*: string
    title*: string
    startTime*: DateTime
    duration*: TimeInterval
    color*: Color
    data*: JsonNode

  render:
    # Draw time ruler
    var x = widget.rect.x
    let hourWidth = widget.scale
    var current = widget.startTime

    while current <= widget.endTime:
      GuiDrawText(
        current.format("HH:mm"),
        x.int32,
        widget.rect.y.int32,
        10,
        BLACK
      )
      x += hourWidth
      current = current + 1.hours

    # Draw events
    for event in widget.events:
      let eventRect = Rectangle(
        x: widget.rect.x + timeToPixels(event.startTime - widget.startTime, widget.scale),
        y: widget.rect.y + 20,
        width: timeToPixels(event.duration, widget.scale),
        height: 30
      )

      if GuiButton(eventRect, event.title):
        if widget.onEventClick != nil:
          widget.onEventClick(event)
