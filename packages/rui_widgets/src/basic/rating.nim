## Rating -- a row of stars you click to rate.
##
## `initialValue` seeds `value` (0 for unrated); clicking star n sets n, and
## clicking the star that is already the value clears it. While the pointer is
## over the stars they preview the rating it would give. `readOnly` shows a
## rating without letting it be changed. `onRate(value)` reports changes.
##
## ```nim
## Rating(maxStars = 5, initialValue = 3, onRate = proc(v: int) = ...)
## ```

import rui_core
import rui_drawing
import std/math
import raylib

proc starPoints*(cx, cy, outer: float32, inner = 0.0'f32): array[10, Vector2] =
  ## The ten corners of a five-point star, point-up. `inner` is the radius of
  ## the notches (0.4 of `outer` if left out).
  let r2 = if inner > 0: inner else: outer * 0.4'f32
  for k in 0 ..< 10:
    let angle = -PI / 2 + float(k) * PI / 5
    let r = if k mod 2 == 0: outer else: r2
    result[k] = Vector2(x: cx + float32(cos(angle)) * r, y: cy + float32(sin(angle)) * r)

proc starAt*(x, left, step: float32, count: int): int =
  ## The star (1-based) under a pointer at `x` for stars `step` apart starting at
  ## `left`; 0 when it is off the row.
  if step <= 0 or x < left: return 0
  let n = int((x - left) / step) + 1
  if n > count: 0 else: n

definePrimitive(Rating):
  props:
    maxStars: int = 5
    initialValue: int = 0
    readOnly: bool = false
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    value: int
    preview: int                   # what the pointer would set; 0 when away

  actions:
    onRate(value: int)

  init:
    widget.focusable = true

  events:
    on_mouse_move:
      if widget.readOnly or widget.disabled: return false
      let size = currentTheme.indicatorSize * 1.2'f32
      let n = starAt(event.mousePos.x, widget.bounds.x, size + 4, widget.maxStars)
      if n != widget.preview:
        widget.preview = n
        widget.isDirty = true
      return false

    on_mouse_down:
      if widget.readOnly or widget.disabled: return false
      let size = currentTheme.indicatorSize * 1.2'f32
      let n = starAt(event.mousePos.x, widget.bounds.x, size + 4, widget.maxStars)
      if n == 0: return false
      widget.value = if n == widget.value: 0 else: n
      if widget.onRate != nil: widget.onRate(widget.value)
      return true

    on_key_down:
      if widget.readOnly or widget.disabled or not widget.focused: return false
      let step = if event.key == KeyboardKey.Up or event.key == KeyboardKey.Right: 1
                 elif event.key == KeyboardKey.Down or event.key == KeyboardKey.Left: -1
                 else: 0
      if step == 0: return false
      let next = clamp(widget.value + step, 0, widget.maxStars)
      if next == widget.value: return false
      widget.value = next
      if widget.onRate != nil: widget.onRate(next)
      return true

  layout:
    let size = currentTheme.indicatorSize * 1.2'f32
    if widget.bounds.height <= 0:
      widget.bounds.height = size
    if widget.bounds.width <= 0:
      widget.bounds.width = float32(widget.maxStars) * (size + 4) - 4

  render:
    let props = widget.themeProps(widget.intent, crPointer, disabled = widget.disabled)
    let accent = props.activeColor.get(Color(r: 240, g: 180, b: 20, a: 255))
    # Stars read as gold-ish only if the theme says so; otherwise its accent.
    let warm = currentTheme.getThemeProps(ThemeIntent.Warning).activeColor.get(accent)
    let outline = props.borderColor.get(Color(r: 160, g: 160, b: 160, a: 255))
    let size = currentTheme.indicatorSize * 1.2'f32
    let shown = if widget.preview > 0 and not widget.readOnly: widget.preview else: widget.value
    let line = max(1.5'f32, props.strokeWidth)
    for i in 0 ..< widget.maxStars:
      let cx = widget.bounds.x + float32(i) * (size + 4) + size / 2
      let cy = widget.bounds.y + widget.bounds.height / 2
      let pts = starPoints(cx, cy, size / 2)
      if i < shown:
        for k in 0 ..< 10:       # a fan from the centre
          drawTriangleAnyWinding(Vector2(x: cx, y: cy), pts[k], pts[(k + 1) mod 10], warm)
      for k in 0 ..< 10:
        let a = pts[k]
        let b = pts[(k + 1) mod 10]
        drawLine(a.x, a.y, b.x, b.y, if i < shown: warm else: outline, line)
    if widget.focused:
      drawBox(Rect(x: widget.bounds.x - 3, y: widget.bounds.y - 3, width: widget.bounds.width + 6,
                   height: widget.bounds.height + 6), 6, Color(r: 0, g: 0, b: 0, a: 0),
              props.focusColor.get(accent), props.focusRingWidth.get(2.0'f32))
