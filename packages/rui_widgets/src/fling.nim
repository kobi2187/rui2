## Kinetic scrolling: a finger lifted while still moving carries the content on,
## slowing to a stop. Plain values, so it is tested with a clock you hand it.
##
## ```nim
## fling.track(y)                 # on each move of a drag
## if fling.release(): widget.repaintAfter(FlingFrame, relayout = true)
## # in layout:
## let d = fling.step()           # pixels the content moves this frame, 0 when done
## if fling.active: widget.repaintAfter(FlingFrame, relayout = true)
## ```
##
## Positions are the finger's; a widget scrolls by `-d`.

import std/[monotimes, times, math]
from rui_core import easingAllowed

const
  FlingFrame* = 0.016          ## seconds between frames of a fling
  MinFlingSpeed = 250.0'f32    ## px/s a release must beat to fling at all
  StopSpeed = 30.0'f32         ## px/s under which a fling ends
  Friction = 3.0'f32           ## per second: speed falls by e^-3 each second
  StaleAfter = 0.08            ## s: a finger that rested this long before lifting does not fling

type Fling* = object
  velocity: float32            ## px/s, smoothed
  lastPos: float32
  lastAt: MonoTime
  tracking: bool
  active*: bool                ## a fling is running (step it each frame)
  stepAt: MonoTime

proc stop*(f: var Fling) =
  f.active = false
  f.tracking = false
  f.velocity = 0

proc begin*(f: var Fling, pos: float32, now = getMonoTime()) =
  ## A drag starts at `pos`; any fling in progress ends.
  f.stop()
  f.tracking = true
  f.lastPos = pos
  f.lastAt = now

proc track*(f: var Fling, pos: float32, now = getMonoTime()) =
  if not f.tracking:
    f.begin(pos, now)
    return
  let dt = float32((now - f.lastAt).inNanoseconds) / 1e9'f32
  if dt > 0.001:
    let instant = (pos - f.lastPos) / dt
    f.velocity = if f.velocity == 0: instant else: 0.6'f32 * f.velocity + 0.4'f32 * instant
    f.lastPos = pos
    f.lastAt = now

proc release*(f: var Fling, now = getMonoTime()): bool =
  ## The finger lifts. True when it was moving fast enough for the content to
  ## run on -- a coast is easing, so never when the user's motion preference
  ## is reduced or none: the content stops where the finger did.
  let rested = float((now - f.lastAt).inNanoseconds) / 1e9
  f.tracking = false
  if abs(f.velocity) >= MinFlingSpeed and rested < StaleAfter and easingAllowed():
    f.active = true
    f.stepAt = now
    return true
  f.velocity = 0
  false

proc step*(f: var Fling, now = getMonoTime()): float32 =
  ## Movement since the last step; speed decays with friction.
  if not f.active: return 0
  let dt = min(float32((now - f.stepAt).inNanoseconds) / 1e9'f32, 0.1'f32)
  f.stepAt = now
  result = f.velocity * dt
  f.velocity *= exp(-Friction * dt)
  if abs(f.velocity) < StopSpeed:
    f.active = false
    f.velocity = 0
