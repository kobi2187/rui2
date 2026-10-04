## Animation: values that move toward a target over time.
##
## An `Animated[T]` holds where something is, where it is going and how long
## the trip takes. A widget asks it for this frame's value with `follow`; while
## it is still moving, `follow` asks the loop for another frame (through the
## repaint timers), and when it arrives it stops asking -- so an idle window
## still costs nothing, and only what is moving is repainted.
##
## ```nim
## # in a widget's layout: fade towards whatever colour the theme says now
## bg.color = widget.fade.follow(widget, props.backgroundColor.get(GRAY),
##                               currentTheme.transitionSeconds)
## ```
##
## Easing curves are the usual ones; `lerp` is defined for numbers, colours and
## rectangles. Animate your own type by adding one more
## `lerp` overload (and `==`).

import std/[monotimes, times, math]
import types
import repaint_timers

var animationsEnabled* = true
  ## Off, every `follow` lands on its target at once. Scripted runs and tests
  ## turn it off so what they read is the settled value, not a point on the way.

var settleEpoch* = 0
  ## Bump to make every Animated snap to its next target instead of travelling
  ## there. A theme switch does: its colours change everywhere at once, and a
  ## fade on some widgets but not others (labels have none) would look broken.
  ## Fades are for a control changing state, not for changing theme.

type
  Easing* = enum
    linear
    easeIn          ## starts slow
    easeOut         ## ends slow (the default for UI: responds at once, settles)
    easeInOut
    easeOutBack     ## overshoots a little, then settles
    easeOutBounce

proc ease*(e: Easing, t: float32): float32 =
  ## The curve at progress `t` (0..1, clamped): 0 at the start, 1 at the end.
  let t = clamp(t, 0.0'f32, 1.0'f32)
  case e
  of linear: t
  of easeIn: t * t * t
  of easeOut:
    let u = 1 - t
    1 - u * u * u
  of easeInOut:
    if t < 0.5: 4 * t * t * t
    else:
      let u = -2 * t + 2
      1 - u * u * u / 2
  of easeOutBack:
    const c1 = 1.70158'f32
    const c3 = c1 + 1
    let u = t - 1
    1 + c3 * u * u * u + c1 * u * u
  of easeOutBounce:
    const n1 = 7.5625'f32
    const d1 = 2.75'f32
    if t < 1 / d1: n1 * t * t
    elif t < 2 / d1:
      let u = t - 1.5 / d1
      n1 * u * u + 0.75
    elif t < 2.5 / d1:
      let u = t - 2.25 / d1
      n1 * u * u + 0.9375
    else:
      let u = t - 2.625 / d1
      n1 * u * u + 0.984375

# ---------------------------------------------------------------------------
# Interpolation
# ---------------------------------------------------------------------------

proc lerp*(a, b: float32, t: float32): float32 = a + (b - a) * t

proc lerp*(a, b: Color, t: float32): Color =
  template ch(x, y: uint8): uint8 =
    uint8(clamp(float32(x) + (float32(y) - float32(x)) * t, 0.0, 255.0) + 0.5)
  Color(r: ch(a.r, b.r), g: ch(a.g, b.g), b: ch(a.b, b.b), a: ch(a.a, b.a))

proc lerp*(a, b: Rect, t: float32): Rect =
  Rect(x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t),
       width: lerp(a.width, b.width, t), height: lerp(a.height, b.height, t))

# ---------------------------------------------------------------------------
# Animated[T]
# ---------------------------------------------------------------------------

type
  Animated*[T] = object
    value: T                 ## where it is as of the last `advance`
    origin, target: T
    started: MonoTime
    seconds: float32
    easing: Easing
    running: bool
    seen: bool               ## has it ever been given a target?
    epoch: int               ## `settleEpoch` as of its last `follow`

proc newAnimated*[T](initial: T): Animated[T] =
  Animated[T](value: initial, origin: initial, target: initial, seen: true)

proc isRunning*[T](a: Animated[T]): bool = a.running
proc target*[T](a: Animated[T]): T = a.target

proc advance*[T](a: var Animated[T], now = getMonoTime()): T =
  ## This frame's value.
  if a.running:
    let t = float32((now - a.started).inNanoseconds) / 1e9'f32 / a.seconds
    if t >= 1:
      a.value = a.target
      a.running = false
    else:
      a.value = lerp(a.origin, a.target, ease(a.easing, t))
  a.value

proc jump*[T](a: var Animated[T], v: T) =
  ## Be at `v` immediately, with no trip.
  a.value = v
  a.origin = v
  a.target = v
  a.running = false

proc moveTo*[T](a: var Animated[T], target: T, seconds: float32,
                easing = easeOut, now = getMonoTime()) =
  ## Head for `target` from wherever it is now (a trip already under way turns
  ## round without a jump). Asking for the target it already has changes
  ## nothing, so this is safe to call every frame.
  if not a.seen:
    # A zero-valued Animated (a widget's state field, before its first layout)
    # starts where it is first told to be, rather than fading in from nothing.
    a.jump(target)
    a.seen = true
    return
  if target == a.target:
    return
  discard a.advance(now)
  if seconds <= 0:
    a.jump(target)
    return
  a.origin = a.value
  a.target = target
  a.started = now
  a.seconds = seconds
  a.easing = easing
  a.running = true

proc follow*[T](a: var Animated[T], widget: Widget, target: T,
                seconds: float32, easing = easeOut): T =
  ## The one call a widget needs: this frame's value on the way to `target`.
  ## While it is still moving, the widget is laid out and repainted again next
  ## frame; once it arrives, nothing more is asked of the loop.
  if not animationsEnabled or a.epoch != settleEpoch:
    a.jump(target)                 # also settles a trip already under way
    a.seen = true
    a.epoch = settleEpoch
    return target
  let now = getMonoTime()
  a.moveTo(target, seconds, easing, now)
  result = a.advance(now)
  if a.running:
    widget.repaintAfter(1.0 / 60.0, relayout = true)
