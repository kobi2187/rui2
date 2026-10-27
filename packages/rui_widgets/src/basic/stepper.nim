## Stepper -- where you are in a series of steps: done ones ticked, the
## current one marked, the rest ahead.
##
## ```nim
## var steps: Stepper
## var pages: IndexedStack
## ui:
##   Column:
##     steps = Stepper(steps = @["Account", "Profile", "Done"],
##                     onStep = proc(i: int) = pages.index = i)
##     pages = IndexedStack(): (one page per step)
##     Row:
##       Button(text = "Back", onClick = proc() = steps.back())
##       Button(text = "Next", onClick = proc() = steps.next())
## ```
##
## That is a whole wizard: a Stepper, the pages, two buttons -- no container
## of its own. A click on a step already done goes back to it (`onStep`); the
## ones ahead are reached with `next`, so a page can check its fields first.
## Focused, Left/Right do the same as back/next.

import rui_core
import rui_drawing
import std/options
import raylib

proc stepCenters*(count: int, area: Rect, inset: float32, insetRight = -1'f32): seq[float32] =
  ## The x of each step's circle, spread evenly across `area`, the first
  ## `inset` from its left and the last `insetRight` (default: the same) from
  ## its right -- half a circle, or half the end label when that is wider.
  if count <= 0: return
  if count == 1: return @[area.x + area.width / 2]
  let right = if insetRight >= 0: insetRight else: inset
  let first = area.x + inset
  let span = area.width - inset - right
  for i in 0 ..< count:
    result.add first + span * float32(i) / float32(count - 1)

proc goTo(widget: Widget, i: int)
proc centers*(widget: Widget): seq[float32]

definePrimitive(Stepper):
  props:
    steps: seq[string] = @[]
    initialCurrent: int = 0
    dotSize: float32 = 26.0
    intent: ThemeIntent = Default

  state:
    current: int
    hover: int

  actions:
    onStep(index: int)

  init:
    widget.focusable = true
    widget.current = clamp(widget.initialCurrent, 0, max(0, widget.steps.high))
    widget.hover = -1

  events:
    on_mouse_down:
      let cs = widget.centers
      for i, x in cs:
        if abs(event.mousePos.x - x) <= max(widget.dotSize, 40) / 2 and i < widget.current:
          widget.goTo(i)                  # back to a step already done
          return true
      return false

    on_mouse_move:
      var over = -1
      let cs = widget.centers
      for i, x in cs:
        if abs(event.mousePos.x - x) <= max(widget.dotSize, 40) / 2 and i < widget.current:
          over = i
      if over != widget.hover:
        widget.hover = over
        widget.isDirty = true
      return false

    on_key_down:
      if not widget.focused: return false
      case event.key
      of KeyboardKey.Left: (if widget.current > 0: widget.goTo(widget.current - 1); return true)
      of KeyboardKey.Right:
        (if widget.current < widget.steps.high: widget.goTo(widget.current + 1); return true)
      else: return false

  layout:
    if widget.bounds.width <= 0: widget.bounds.width = max(200'f32, float32(widget.steps.len) * 110)
    if widget.bounds.height <= 0: widget.bounds.height = widget.dotSize + 26

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let ink = props.foregroundColor.get(BLACK)
    let accent = props.activeColor.get(ink)
    let rail = props.borderColor.get(ink.withAlpha(0.3))
    let d = widget.dotSize
    let cy = widget.bounds.y + d / 2
    let cs = widget.centers
    for i in 1 ..< cs.len:                # the lines between, done ones in the accent
      let c = if i <= widget.current: accent else: rail
      drawLine(cs[i - 1] + d / 2 + 4, cy, cs[i] - d / 2 - 4, cy, c, 2)
    var style = props.captionStyle(ink)
    style.fontSize = max(10'f32, style.fontSize - 2)
    for i, x in cs:
      let box = Rect(x: x - d / 2, y: cy - d / 2, width: d, height: d)
      let done = i < widget.current
      let here = i == widget.current
      let fill = if done or here: accent else: props.backgroundColor.get(WHITE)
      let edge = if done or here: accent else: rail
      discard drawSdfBox(box, d / 2, 2, fill, edge)
      if i == widget.hover:
        discard drawSdfBox(Rect(x: box.x - 3, y: box.y - 3, width: d + 6, height: d + 6),
                           d / 2 + 3, 2, Color(), accent.withAlpha(0.4))
      let onDot = if done or here:
                    (if contrastRatio(accent, BLACK) >= contrastRatio(accent, WHITE): BLACK else: WHITE)
                  else: ink
      if done:                            # a tick
        let k = d * 0.18
        drawLine(x - k * 1.4, cy, x - k * 0.3, cy + k, onDot, 2)
        drawLine(x - k * 0.3, cy + k, x + k * 1.5, cy - k, onDot, 2)
      else:
        var num = style
        num.color = onDot
        num.bold = here
        let t = $(i + 1)
        let sz = measureText(t, num)
        drawStyledText(t, x - sz.width / 2, cy - sz.height / 2, num)
      var cap = style
      cap.bold = here
      cap.color = if done or here: ink else: ink.withAlpha(0.6)
      drawStyledText(widget.steps[i], x, cy + d / 2 + 4, cap, centered = true)
    if widget.focused: drawThemedFocusRing(widget.bounds, props)

proc labelStyle(widget: Stepper): TextStyle =
  result = currentTheme.getThemeProps(widget.intent, Normal).captionStyle(BLACK)
  result.fontSize = max(10'f32, result.fontSize - 2)
  result.bold = true                       # the widest a label is drawn

proc centers*(widget: Widget): seq[float32] =
  ## Where the circles go: the end labels kept inside the bounds.
  let widget = Stepper(widget)
  if widget.steps.len == 0: return
  let style = widget.labelStyle
  let left = max(widget.dotSize, measureText(widget.steps[0], style).width) / 2
  let right = max(widget.dotSize, measureText(widget.steps[^1], style).width) / 2
  stepCenters(widget.steps.len, widget.bounds, left, right)

proc goTo(widget: Widget, i: int) =
  let widget = Stepper(widget)
  let i = clamp(i, 0, max(0, widget.steps.high))
  if i == widget.current: return
  widget.current = i
  widget.hover = -1
  widget.isDirty = true
  if widget.onStep != nil: widget.onStep(i)

proc next*(widget: Stepper) =
  ## On to the next step (a Next button calls this once its page is complete).
  widget.goTo(widget.current + 1)

proc back*(widget: Stepper) =
  ## Back a step.
  widget.goTo(widget.current - 1)
