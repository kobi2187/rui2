## Presses and releases are kept in order between frames, so a tap whose
## finger goes down and up before the next frame is still a click. The
## platform hooks (GLFW's button callback on the desktop, the Android touch
## hook in android_glue.c) feed queueButton; the frame drains it.

import std/[unittest, monotimes, times]
import rui
import event_source

suite "button queue":
  test "a down and an up between two frames both arrive, in order, where they happened":
    let t0 = getMonoTime()
    queueButton(true, Point(x: 10, y: 20), t0)
    queueButton(false, Point(x: 11, y: 21), t0 + initDuration(milliseconds = 12))
    var events: seq[GuiEvent]
    drainButtonQueue(events)
    check events.len == 2
    check events[0].kind == evMouseDown and events[0].mousePos == Point(x: 10, y: 20)
    check events[1].kind == evMouseUp and events[1].mousePos == Point(x: 11, y: 21)
    check events[1].timestamp > events[0].timestamp
    check events[0].priority == epHigh            # never coalesced away

  test "draining empties the queue; two quick taps are two clicks":
    for i in 0 ..< 2:
      queueButton(true, Point(x: 5, y: 5))
      queueButton(false, Point(x: 5, y: 5))
    var events: seq[GuiEvent]
    drainButtonQueue(events)
    check events.len == 4
    var again: seq[GuiEvent]
    drainButtonQueue(again)
    check again.len == 0

  test "a tap queued within one frame clicks a button through the real router":
    var clicks = 0
    let b = newButton(text = "Tap", onClick = proc() = inc clicks)
    let root = newColumn()
    root.addChild b
    let app = newApp("tap", 200, 100)
    let src = newListEventSource()
    app.eventSource = src
    app.setRootWidget(root)
    app.stepHeadless()
    let at = Point(x: b.bounds.x + 5, y: b.bounds.y + 5)
    queueButton(true, at)
    queueButton(false, at)
    var events: seq[GuiEvent]
    drainButtonQueue(events)
    src.push GuiEvent(kind: evMouseMove, priority: epHigh, timestamp: getMonoTime(), mousePos: at)
    for e in events: src.push e
    app.stepHeadless()
    check clicks == 1
