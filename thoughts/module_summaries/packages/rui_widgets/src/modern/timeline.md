# packages/rui_widgets/src/modern/timeline.nim

## Purpose

Chronological event track: a time axis with grid and labels, blocks for
durations, markers for instants, and a "now" line. Drag to pan, scroll to move,
click an event.

## Public interface

- `TimelineEvent*` — `id`, `title`, `description`, `startTime`, `endTime`,
  `color`, `isDuration`, `data: JsonNode`.
- `TimeScale*` — `tsMinute`, `tsHour`, `tsDay`, `tsWeek`, `tsMonth`, `tsYear`.
- `TimelineAxis*` — the time-to-pixel projection, as a plain value.
- `newTimeline*(events, startTime, endTime, scale = tsHour,
  pixelsPerUnit = 60.0, eventHeight = 40.0, eventSpacing = 8.0, showGrid,
  showTimeLabels, showNowMarker, intent, onEventClick, onScroll)`.
  **`startTime` and `endTime` have no defaults** — a DateTime has no sensible
  zero, so the caller must supply both.
- `axis*(widget: Timeline): TimelineAxis` and the template `axisOf*(widget)`.
- `timeToPixel*(axis, time)`, `pixelToTime*(axis, pixel)`,
  `eventRectFor*(axis, index, evt): Rect`.

## Usage pattern

```nim
let start = dateTime(2026, mJan, 1, 0, 0, 0, zone = utc())
let track = newTimeline(events = events, startTime = start,
                        endTime = start + initDuration(hours = 10),
                        scale = tsHour, pixelsPerUnit = 70.0)
track.onEventClick = some(proc(evt: TimelineEvent) {.closure.} = ...)
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where the event rectangles were computed
inline in `render` and the mouse was polled there too, so selection updated
only on repainting frames.

**The projection is a separate value, not procs over the widget.** A proc
taking `Timeline` cannot be declared before `definePrimitive` has created that
type, and the widget body needs the geometry — so `TimelineAxis` plus an
`axisOf` template. MapWidget's `MapView` exists for exactly the same reason.

Hit-testing and painting both call `eventRectFor`, so a click cannot land
somewhere other than what was drawn. Month and year scales use the usual 30-
and 365-day approximations.
</content>
