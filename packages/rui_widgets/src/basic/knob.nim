## Knob -- a value on a dial: gain, pan, a filter's cutoff, a tempo.
##
## ```nim
## ui:
##   Knob(label = "Gain", minValue = -24, maxValue = 12, initialValue = 0, step = 0.5,
##        onChange = proc(v: float32) = gain = v)
## ```
##
## It turns the way audio knobs do: a drag up raises the value, down lowers
## it, relative to where it was taken (so it never jumps), the whole range over
## 200 pixels -- Shift for fine, a tenth as fast. A double click puts it back to
## `initialValue`. Focused, it takes the slider keys (arrows a step,
## PageUp/PageDown ten, Home/End the ends) and the wheel. The value maths is
## the sliders' (value_input.nim).

import rui_core
import rui_drawing
import ../value_input
import ../clicks
export value_input
import std/[options, strformat]
import raylib

const KnobDrag = 200'f32               ## pixels for the whole range

template setValue(w, computed: untyped) =
  ## Turn the knob, and tell onChange of a real change only.
  block:
    let v = computed
    if w.value != v:
      w.value = v
      w.isDirty = true
      if w.onChange != nil: w.onChange(v)

definePrimitive(Knob):
  props:
    initialValue: float32 = 0.0
    minValue: float32 = 0.0
    maxValue: float32 = 100.0
    step: float32 = 0.0           ## the grid and the key step; 0: 1% of the range
    label: string = ""
    showValue: bool = true
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    value: float32
    dragging: bool
    grabY: float32
    grabValue: float32
    clicks: ClickRun              ## a double click resets (clicks.nim)

  actions:
    onChange(value: float32)

  init:
    widget.focusable = true
    widget.value = clamp(widget.initialValue, min(widget.minValue, widget.maxValue),
                         max(widget.minValue, widget.maxValue))

  events:
    on_mouse_down:
      if widget.disabled: return false
      if widget.clicks.countClick(event.timestamp, most = 2) == 2:
        widget.setValue(widget.initialValue)
        return true
      widget.dragging = true
      widget.grabY = event.mousePos.y
      widget.grabValue = widget.value
      capturePointer(widget)
      widget.isDirty = true
      return true

    on_mouse_move:
      if not widget.dragging: return false
      let fine = if event.shift: 10'f32 else: 1'f32
      widget.setValue(valueByDrag(widget.grabValue, widget.grabY - event.mousePos.y,
                                  widget.minValue, widget.maxValue, widget.step,
                                  KnobDrag * fine))
      return true

    on_mouse_up:
      if not widget.dragging: return false
      widget.dragging = false
      widget.isDirty = true
      return true

    on_key_down:
      if widget.disabled or not widget.focused or not event.key.isValueKey: return false
      widget.setValue(valueKey(event.key, widget.value, widget.minValue,
                               widget.maxValue, widget.step))
      return true

    on_mouse_wheel:
      # Only while focused, as a slider: passing under the pointer must not
      # steal the page's scroll.
      if widget.disabled or not widget.focused or event.wheelDelta == 0: return false
      widget.setValue(stepValue(widget.value, widget.minValue, widget.maxValue,
                                widget.step, (if event.wheelDelta > 0: 1'f32 else: -1'f32)))
      return true

  layout:
    if widget.bounds.width <= 0: widget.bounds.width = 64
    if widget.bounds.height <= 0:
      widget.bounds.height = widget.bounds.width + (if widget.label.len > 0: 20 else: 0) +
                             (if widget.showValue: 18 else: 0)

  render:
    let props = widget.themeProps(widget.intent, crPointer, disabled = widget.disabled,
                                  pressed = widget.dragging)
    let b = widget.bounds
    let below = (if widget.label.len > 0: 20'f32 else: 0) + (if widget.showValue: 18'f32 else: 0)
    let d = max(8'f32, min(b.width, b.height - below))
    let center = Vector2(x: b.x + b.width / 2, y: b.y + d / 2)
    drawKnob(center, d / 2 - 2, widget.value, widget.minValue, widget.maxValue,
             props, widget.dragging)
    if widget.focused: drawThemedFocusRing(Rect(x: center.x - d / 2, y: b.y, width: d, height: d), props)
    var style = props.captionStyle(props.foregroundColor.get(BLACK))
    style.fontSize = max(10'f32, style.fontSize - 2)
    var y = b.y + d + 2
    if widget.showValue:
      let text = if widget.step >= 1 or widget.step == 0 and abs(widget.maxValue - widget.minValue) >= 100:
                   fmt"{widget.value:.0f}"
                 else: fmt"{widget.value:.1f}"
      drawStyledText(text, center.x, y, style, centered = true)
      y += 18
    if widget.label.len > 0:
      drawStyledText(widget.label, center.x, y, style, centered = true)
