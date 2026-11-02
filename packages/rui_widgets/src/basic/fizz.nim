## Fizz -- bubbles rising through a control, once: the carbonation a soda
## theme puts in its primary buttons when one is pressed.
##
## A primitive you can see. `burst()` starts it; it rises for `seconds`, then
## is gone. Button keeps one between its body and its caption and bursts it on
## a click of a primary (Info) button, when the theme has `fizz`. It respects
## motion: with effects off (motion none) a burst does nothing.
##
## `fizzBubbles` is the whole animation as a value -- where every bubble is at
## a moment -- so it is tested without a window.
##
## It is hidden except while it rises: every widget owns a texture, and one
## Fizz per button, idle, cost a quarter more render time in a big form.
## Hidden, it has none and is never painted.

import rui_core
import rui_drawing
import std/[monotimes, times, math]
import raylib except getTime

const FizzCount* = 11

type Bubble* = tuple[center: Point, radius, alpha: float32]

proc fract(x: float): float = x - floor(x)

proc fizzBubbles*(t: float, area: Rect, seconds = 0.9): seq[Bubble] =
  ## The bubbles `t` seconds into a burst over `area`: each starts at the
  ## bottom at its own moment, rises with a wobble, and fades near the top.
  ## Empty before the start and once the last has risen out.
  if t < 0 or t > seconds or area.width <= 0 or area.height <= 0: return
  for i in 0 ..< FizzCount:
    # A fixed pattern from the index (the same burst every time).
    let k = float(i)
    let x0 = 0.08 + 0.84 * fract(k * 0.6180339)            # spread across
    let delay = 0.28 * fract(k * 0.4142135)
    let speed = 0.9 + 0.6 * fract(k * 0.7320508)           # heights per run
    let r = 1.4 + 2.2 * fract(k * 0.2360679)
    let life = (t - delay) / (seconds - delay)
    if life <= 0 or life >= 1: continue
    let rise = life * speed
    if rise >= 1: continue
    let y = area.y + area.height - r - rise * (area.height - 2 * r)
    let x = area.x + x0 * area.width + sin(life * 9 + k) * 2.2
    let fade = float32(min(1.0, (1 - rise) * 3) * min(1.0, life * 6))
    result.add (Point(x: x.float32, y: y.float32), r.float32, fade)

definePrimitive(Fizz):
  props:
    seconds: float32 = 0.9
    color: Color = Color(r: 255, g: 255, b: 255, a: 200)

  state:
    started: MonoTime
    running: bool

  init:
    widget.visible = false
  render:
    if not widget.running: return
    let t = float((getMonoTime() - widget.started).inMicroseconds) / 1e6
    let bubbles = fizzBubbles(t, widget.bounds, widget.seconds)
    if bubbles.len == 0 and t > widget.seconds:
      widget.running = false
      widget.visible = false          # out of the way again: no texture, no paint
      if widget.parent != nil: widget.parent.markDirtyToRoot()
      return
    for b in bubbles:
      let c = widget.color.withAlpha(float32(widget.color.a) / 255 * b.alpha)
      let r = Rect(x: b.center.x - b.radius, y: b.center.y - b.radius,
                   width: 2 * b.radius, height: 2 * b.radius)
      # A ring with a lighter middle: a bubble, not a dot.
      drawBox(r, b.radius, c.withAlpha(float32(c.a) / 255 * 0.25), c, max(1'f32, b.radius * 0.45))
    widget.repaintAfter(1.0 / 60.0)

proc burst*(widget: Fizz) =
  ## Start the bubbles rising (again, if they already are). Nothing when
  ## effects are off.
  if not effectsAllowed(): return
  widget.started = getMonoTime()
  widget.running = true
  widget.visible = true
  widget.markDirtyToRoot()
