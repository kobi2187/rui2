## Timeline
##
## A chronological track: instants, durations, a grid with time labels, and a
## "now" marker. Drag the background to pan, scroll to move, click an event.
##
##   nim c -r -d:useGraphics examples/widgets/timeline.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os, times, json]

let app = newApp("RUI2 - Timeline", 720, 420)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 16.0).named("root")
let summary = newLabel(text = "click an event", fontSize = 15.0).named("summary")
root.addChild(summary)

# Anchor the window to the top of the current hour so the "now" marker is
# somewhere sensible whenever the example is run.
let start = now().utc
let dayStart = dateTime(start.year, start.month, start.monthday,
                        start.hour, 0, 0, zone = utc()) - initDuration(hours = 2)

proc event(id, title: string, startHour, durationHours: float,
           color: Color): TimelineEvent =
  let begins = dayStart + initDuration(minutes = int64(startHour * 60))
  TimelineEvent(
    id: id, title: title,
    startTime: begins,
    endTime: begins + initDuration(minutes = int64(durationHours * 60)),
    color: color,
    isDuration: durationHours > 0,
    data: newJObject()
  )

let events = @[
  event("build", "Build", 0.5, 1.5, Color(r: 90, g: 140, b: 220, a: 255)),
  event("test", "Test suite", 2.0, 1.0, Color(r: 110, g: 180, b: 120, a: 255)),
  event("deploy", "Deploy", 3.5, 0.0, Color(r: 220, g: 120, b: 90, a: 255)),
  event("soak", "Soak", 4.0, 3.0, Color(r: 180, g: 150, b: 220, a: 255)),
]

let track = newTimeline(events = events,
                        startTime = dayStart,
                        endTime = dayStart + initDuration(hours = 10),
                        scale = tsHour, pixelsPerUnit = 70.0,
                        eventHeight = 32.0, eventSpacing = 6.0,
                        showGrid = true, showTimeLabels = true,
                        showNowMarker = true).named("track")
track.bounds = Rect(x: 0, y: 0, width: 680, height: 260)
track.onEventClick = some(proc(evt: TimelineEvent) {.closure.} =
  summary.text = evt.title & " (" & evt.startTime.format("HH:mm") & ")"
  summary.isDirty = true
  summary.layoutDirty = true)
root.addChild(track)

root.addChild(newLabel(text = "Drag the background to pan, scroll to move.",
                       fontSize = 13.0).named("hint"))

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
