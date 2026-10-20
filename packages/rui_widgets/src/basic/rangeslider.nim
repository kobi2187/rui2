## RangeSlider -- two thumbs on one track: a `low` and a `high` value.
##
## yui's `range`. Press near a thumb to take it and drag; the thumbs never cross.
## From the keyboard (when focused) the arrows move the active thumb a step,
## Home/End send it to its limit, and Space or Enter hands the keys to the other
## thumb. `onChange(low, high)` fires on real changes only.
##
## ```nim
## RangeSlider(minValue = 0, maxValue = 100, initialLow = 20, initialHigh = 70)
## ```

import rui_core
import rui_drawing
import std/[options, math]
import slider
import ../value_input
import raylib

proc thumbCenter(track: Rect, value, minValue, maxValue: float32): float32 =
  track.x + (if maxValue > minValue: (value - minValue) / (maxValue - minValue) else: 0.0'f32) * track.width

proc nearestThumb*(x, lowX, highX: float32): int =
  ## Which thumb a press at `x` takes: the closer one, and when they sit
  ## together the one that can still move toward the pointer.
  if abs(x - lowX) < abs(x - highX): 0
  elif abs(x - lowX) > abs(x - highX): 1
  elif x < lowX: 0
  else: 1

proc limits(low, high: float32, active: int, minValue, maxValue: float32): tuple[lo, hi: float32] =
  if active == 0: (minValue, high) else: (low, maxValue)

template setThumb(w, which, computed: untyped) =
  block:
    let limit = limits(w.low, w.high, which, w.minValue, w.maxValue)
    let v = clamp(computed, limit.lo, limit.hi)
    let before = (w.low, w.high)
    if which == 0: w.low = v else: w.high = v
    if (w.low, w.high) != before:
      w.isDirty = true
      if w.onChange != nil: w.onChange(w.low, w.high)

definePrimitive(RangeSlider):
  props:
    initialLow: float32 = 0.0
    initialHigh: float32 = 100.0
    minValue: float32 = 0.0
    maxValue: float32 = 100.0
    step: float32 = 0.0
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    low: float32
    high: float32
    active: int          # 0: the low thumb has the keys, 1: the high one
    dragging: bool

  actions:
    onChange(low: float32, high: float32)

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      if widget.disabled: return false
      let t = widget.bounds
      widget.active = nearestThumb(event.mousePos.x,
        thumbCenter(t, widget.low, widget.minValue, widget.maxValue),
        thumbCenter(t, widget.high, widget.minValue, widget.maxValue))
      widget.dragging = true
      capturePointer(widget)
      widget.setThumb(widget.active, valueAtPointer(event.mousePos.x, t.x, t.width,
        widget.minValue, widget.maxValue, widget.step))
      return true

    on_mouse_move:
      if not widget.dragging or widget.disabled: return false
      let t = widget.bounds
      widget.setThumb(widget.active, valueAtPointer(event.mousePos.x, t.x, t.width,
        widget.minValue, widget.maxValue, widget.step))
      return true

    on_mouse_up:
      if not widget.dragging: return false
      widget.dragging = false
      widget.isDirty = true
      return true

    on_key_down:
      if widget.disabled or not widget.focused: return false
      let current = if widget.active == 0: widget.low else: widget.high
      case event.key
      of KeyboardKey.Right, KeyboardKey.Up, KeyboardKey.Left, KeyboardKey.Down,
         KeyboardKey.PageUp, KeyboardKey.PageDown, KeyboardKey.Home, KeyboardKey.End:
        widget.setThumb(widget.active, valueKey(event.key, current, widget.minValue,
                                                widget.maxValue, widget.step))
      of KeyboardKey.Space, KeyboardKey.Enter:
        widget.active = 1 - widget.active
        widget.isDirty = true
      else: return false
      return true

  layout:
    if widget.bounds.height <= 0:
      widget.bounds.height = max(24.0'f32, currentTheme.thumbSize + 4)
    if widget.bounds.width <= 0:
      widget.bounds.width = 200.0'f32

  render:
    let props = widget.themeProps(widget.intent, crPointer, disabled = widget.disabled,
                                  pressed = widget.dragging)
    let t = widget.bounds
    let cy = t.y + t.height / 2
    let lx = thumbCenter(t, widget.low, widget.minValue, widget.maxValue)
    let hx = thumbCenter(t, widget.high, widget.minValue, widget.maxValue)
    if props.bevelStyle.get(Flat) != Flat:
      # A bevelled theme (BeOS): the same groove and knob as a Slider, one per end.
      drawBeGroove(t.x, t.width, cy, props)
      let d = max(currentTheme.thumbSize, 12.0'f32)
      drawBeKnob(lx, cy, d, props)
      drawBeKnob(hx, cy, d, props)
      return
    let thick = max(currentTheme.trackThickness, 4.0'f32)
    let track = Rect(x: t.x, y: cy - thick / 2, width: t.width, height: thick)
    let accent = props.activeColor.get(Color(r: 80, g: 120, b: 255, a: 255))
    let rail = props.borderColor.get(Color(r: 200, g: 200, b: 200, a: 255))
    drawBox(track, thick / 2, rail, rail, 0)
    drawBox(Rect(x: lx, y: track.y, width: max(0.0'f32, hx - lx), height: thick),
            thick / 2, accent, accent, 0)
    let d = max(currentTheme.thumbSize, 12.0'f32)
    for which, x in [lx, hx]:
      let ring = if widget.focused and widget.active == which: props.focusColor.get(accent) else: accent
      drawBox(Rect(x: x - d / 2, y: cy - d / 2, width: d, height: d), d / 2,
              props.backgroundColor.get(WHITE), ring, 2)
