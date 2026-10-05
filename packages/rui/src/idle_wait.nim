## Blocking while idle: sleep in the OS until something happens, instead of
## waking every frame to find out that nothing did.
##
## A window with nothing to paint needs a wake-up for exactly three reasons --
## input arrives, a repaint timer falls due (caret blink, animation), or the
## idle refresh is owed -- so the loop blocks in GLFW until the earliest of
## them. Another thread that has queued work for the UI calls `wakeMainLoop`.
##
## raylib's own `EnableEventWaiting` blocks with no timeout, which would
## starve the timers; GLFW's `waitEventsTimeout` is what we need.

import std/[monotimes, times, options]

proc glfwWaitEventsTimeout(seconds: cdouble) {.importc: "glfwWaitEventsTimeout", cdecl.}
proc glfwPostEmptyEvent() {.importc: "glfwPostEmptyEvent", cdecl.}

const
  minWait = initDuration(milliseconds = 1)     # never spin tighter than this

proc idleWaitFor*(now: MonoTime, nextTimer: Option[MonoTime], refreshAt: MonoTime,
                  cap = none(Duration)): Duration =
  ## How long an idle loop may block: until the earliest repaint timer or the
  ## idle refresh, and no longer than `cap` (set while scripting, whose command
  ## files are polled once per frame). Never below a millisecond, so a timer
  ## that is already due costs a frame, not a spin.
  var until = refreshAt
  if nextTimer.isSome and nextTimer.get < until:
    until = nextTimer.get
  result = max(until - now, minWait)
  if cap.isSome:
    result = min(result, max(cap.get, minWait))

proc blockForEvents*(timeout: Duration) =
  ## Return when an event arrives, `wakeMainLoop` is called, or `timeout` ends.
  glfwWaitEventsTimeout(cdouble(timeout.inNanoseconds) / 1e9)

proc wakeMainLoop*() =
  ## Interrupt a blocked loop. Safe from any thread -- the way for a worker to
  ## tell the UI there is something to show.
  glfwPostEmptyEvent()
