## Slider, RangeSlider and ScrollBar share their number handling (value_input.nim).

import std/unittest
import rui
import ui_harness
from raylib import KeyboardKey
import ../packages/rui_widgets/src/value_input

suite "valueKey":
  test "arrows step, pages ten, Home/End to the ends, other keys change nothing":
    check valueKey(KeyboardKey.Right, 50, 0, 100, 5) == 55
    check valueKey(KeyboardKey.Down, 50, 0, 100, 5) == 45
    check valueKey(KeyboardKey.PageUp, 50, 0, 100, 5) == 100
    check valueKey(KeyboardKey.PageDown, 50, 0, 100, 5) == 0
    check valueKey(KeyboardKey.Home, 50, 0, 100, 5) == 0
    check valueKey(KeyboardKey.End, 50, 0, 100, 5) == 100
    check valueKey(KeyboardKey.A, 50, 0, 100, 5) == 50
    check not KeyboardKey.A.isValueKey
  test "never leaves the range, stays on the grid":
    check valueKey(KeyboardKey.Right, 100, 0, 100, 5) == 100
    check valueKey(KeyboardKey.Left, 0, 0, 100, 5) == 0
    check valueAtPointer(37, 0, 100, 0, 100, 10) == 40
    check valueAtPointer(-50, 0, 100, 0, 100, 10) == 0
    check valueAtPointer(500, 0, 100, 0, 100, 10) == 100

suite "the three number controls act alike":
  test "click on the track jumps there; drag follows; release stops":
    let s = newSlider(minValue = 0, maxValue = 100, showValue = false)
    let g = newRangeSlider(minValue = 0, maxValue = 100, initialLow = 10, initialHigh = 90)
    let b = newScrollBar(minValue = 0, maxValue = 100, vertical = false)
    let r = newRig(stack(s, g, b))
    for (w, get) in [(Widget(s), proc(): float32 = s.value),
                     (Widget(b), proc(): float32 = b.value)]:
      let y = w.bounds.y + w.bounds.height / 2
      r.press(w.bounds.x + w.bounds.width * 0.25, y)
      check abs(get() - 25) < 12
      r.src.push GuiEvent(kind: evMouseMove, priority: epHigh,
                          mousePos: Point(x: w.bounds.x + w.bounds.width * 0.75, y: y))
      r.frame()
      check abs(get() - 75) < 12
      r.release(w.bounds.x + w.bounds.width * 0.75, y)
      let settled = get()
      r.moveTo(w.bounds.x + 2, y)
      check get() == settled
  test "RangeSlider keys move the active thumb within the range":
    let g = newRangeSlider(minValue = 0, maxValue = 100, initialLow = 20, initialHigh = 80)
    let r = newRig(stack(g))
    r.focus(g)
    r.key(KeyboardKey.Right)
    check g.low > 20
    r.key(KeyboardKey.End)
    check g.low <= g.high
