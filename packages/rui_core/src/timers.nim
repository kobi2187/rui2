## Timers that belong to a widget: `every`, `after`, `onTick`.
##
## Something that changes with time -- a reader's line gliding down the page,
## a clock, a slideshow -- needs to be told when, and to stop when it is no
## longer seen. These do both:
##
## ```nim
## page.every(5.0, proc() = nextSlide())       # every 5 s
## toast.after(3.0, proc() = toast.hide())     # once, in 3 s
## rule.onTick(proc(dt: float) =               # every frame, dt seconds after the last
##   y += speed * dt)
## ```
##
## A timer runs while its widget is on the page: visible, its ancestors
## visible, not behind a modal (overlays.nim `onPage`). Hidden, it waits --
## and an `onTick` resumes with the time since it resumed, not the time it was
## away, so nothing jumps. It goes with its widget (disposed) or `stopTimers`.
## Unlike animations these ignore the user's motion preference: what they
## drive is the app's content (a reading pace, a clock), not decoration.

import std/[monotimes, times]
import types
import pollers
import repaint_timers
import overlays

type
  TimerKind = enum tkEvery, tkAfter, tkTick
  WidgetTimer = object
    widget: Widget
    kind: TimerKind
    period: float                 # seconds (every / after)
    due: MonoTime                 # next firing (every / after)
    last: MonoTime                # last tick (tick)
    running: bool                 # was on the page last frame (tick)
    action: proc() {.closure.}
    tick: proc(dt: float) {.closure.}

var
  timers: seq[WidgetTimer]
  polling = false

const FrameSeconds = 1.0 / 60.0

proc seconds(d: Duration): float = d.inNanoseconds.float / 1e9

proc runTimers(): bool =
  ## Each frame: fire what is due, tick what ticks, and ask for the frame the
  ## next one needs (an idle loop is otherwise asleep).
  let now = getMonoTime()
  var i = 0
  while i < timers.len:
    let w = timers[i].widget
    if not w.onPage:
      timers[i].running = false     # waits; a tick resumes without a jump
      inc i
      continue
    case timers[i].kind
    of tkTick:
      let dt = if timers[i].running: (now - timers[i].last).seconds else: 0.0
      timers[i].last = now
      timers[i].running = true
      let call = timers[i].tick
      call(dt)
      w.repaintAfter(FrameSeconds)
      result = true
    of tkEvery, tkAfter:
      if now >= timers[i].due:
        let call = timers[i].action
        if timers[i].kind == tkAfter:
          timers.delete(i)
          call()
          result = true
          continue
        timers[i].due = timers[i].due + initDuration(nanoseconds = int64(timers[i].period * 1e9))
        if timers[i].due < now:     # fell behind (it was hidden): no catching up in a burst
          timers[i].due = now + initDuration(nanoseconds = int64(timers[i].period * 1e9))
        call()
        result = true
      if i < timers.len and timers[i].widget == w:
        w.repaintAfter((timers[i].due - now).seconds)
    inc i

proc add(t: WidgetTimer) =
  if not polling:
    polling = true
    discard addPoller(runTimers)
  let w = t.widget
  # Gone with its widget; added once per widget, however many timers it has.
  var first = true
  for other in timers:
    if other.widget == w: first = false
  timers.add t
  if first:
    w.disposers.add proc() =
      for i in countdown(timers.high, 0):
        if timers[i].widget == w: timers.delete(i)
  w.repaintAfter(0.0)                # wake the loop so the first frame comes

proc every*[T: Widget](widget: T, seconds: float, action: proc()): T {.discardable.} =
  ## Call `action` every `seconds` while the widget is on the page.
  add WidgetTimer(widget: widget, kind: tkEvery, period: seconds, action: action,
                  due: getMonoTime() + initDuration(nanoseconds = int64(seconds * 1e9)))
  widget

proc after*[T: Widget](widget: T, seconds: float, action: proc()): T {.discardable.} =
  ## Call `action` once, `seconds` from now (later, if the widget is hidden
  ## then: when it is back).
  add WidgetTimer(widget: widget, kind: tkAfter, period: seconds, action: action,
                  due: getMonoTime() + initDuration(nanoseconds = int64(seconds * 1e9)))
  widget

proc onTick*[T: Widget](widget: T, tick: proc(dt: float)): T {.discardable.} =
  ## Call `tick` every frame while the widget is on the page, with the seconds
  ## since the last call: for movement at a speed (`y += speed * dt`).
  add WidgetTimer(widget: widget, kind: tkTick, tick: tick, last: getMonoTime())
  widget

proc stopTimers*(widget: Widget) =
  ## Stop every timer of `widget`.
  for i in countdown(timers.high, 0):
    if timers[i].widget == widget: timers.delete(i)

proc timerCount*(widget: Widget): int =
  for t in timers:
    if t.widget == widget: inc result
