## What every "drag or key a number" control does with its input: Slider,
## RangeSlider, ScrollBar, Knob. Pure functions on numbers, so each widget keeps only
## its own geometry and which thumb moves.

import std/math
import raylib

proc valueAtX*(x, boundsX, boundsWidth, minValue, maxValue: float32): float32 =
  ## Where a pointer at `x` falls on a slider spanning boundsX..+boundsWidth.
  ## Clamped, so dragging past either end pins to that end rather than running
  ## the value off the scale.
  if boundsWidth <= 0:
    return minValue
  let t = clamp((x - boundsX) / boundsWidth, 0.0'f32, 1.0'f32)
  minValue + t * (maxValue - minValue)

proc stepValue*(value, minValue, maxValue, step: float32, steps: float32): float32 =
  ## `value` moved by `steps` steps (negative: down), kept on the range and,
  ## when `step` > 0, on its grid. A step of 0 is a hundredth of the range.
  let s = if step > 0: step else: (maxValue - minValue) / 100
  result = clamp(value + s * steps, min(minValue, maxValue), max(minValue, maxValue))
  if step > 0:
    result = clamp(minValue + round((result - minValue) / step) * step,
                   min(minValue, maxValue), max(minValue, maxValue))

proc snapped*(value, minValue, step: float32): float32 =
  ## A dragged value on the step grid; unchanged when there is no step.
  if step > 0: minValue + round((value - minValue) / step) * step
  else: value


proc valueKey*(key: KeyboardKey, current, minValue, maxValue, step: float32): float32 =
  ## The value after `key`, or `current` unchanged when it is not a value key:
  ## arrows move a step (up/right raise), PageUp/PageDown ten, Home/End go to the ends.
  case key
  of KeyboardKey.Right, KeyboardKey.Up: stepValue(current, minValue, maxValue, step, 1)
  of KeyboardKey.Left, KeyboardKey.Down: stepValue(current, minValue, maxValue, step, -1)
  of KeyboardKey.PageUp: stepValue(current, minValue, maxValue, step, 10)
  of KeyboardKey.PageDown: stepValue(current, minValue, maxValue, step, -10)
  of KeyboardKey.Home: minValue
  of KeyboardKey.End: maxValue
  else: current

proc isValueKey*(key: KeyboardKey): bool =
  key in {KeyboardKey.Right, KeyboardKey.Up, KeyboardKey.Left, KeyboardKey.Down,
          KeyboardKey.PageUp, KeyboardKey.PageDown, KeyboardKey.Home, KeyboardKey.End}

proc valueAtPointer*(pos, trackStart, trackLength, minValue, maxValue, step: float32): float32 =
  ## A pointer at `pos` along a track, as a value on the grid.
  snapped(valueAtX(pos, trackStart, trackLength, minValue, maxValue), minValue, step)

proc valueByDrag*(startValue, pixels, minValue, maxValue, step: float32,
                  pixelsForRange = 200'f32): float32 =
  ## The value a drag of `pixels` (positive raises: up, or right) has moved
  ## `startValue` to, the whole range taking `pixelsForRange`: how a knob turns,
  ## relative to where it was taken, so it never jumps. Clamped, on the grid.
  let span = maxValue - minValue
  let v = startValue + pixels / max(1'f32, pixelsForRange) * span
  snapped(clamp(v, min(minValue, maxValue), max(minValue, maxValue)), minValue, step)

proc zoomDirection*(key: KeyboardKey): int =
  ## +1 for + / =, -1 for -, 0 for any other key: what a pannable view's zoom keys mean.
  case key
  of KeyboardKey.Equal, KeyboardKey.KpAdd: 1
  of KeyboardKey.Minus, KeyboardKey.KpSubtract: -1
  else: 0
