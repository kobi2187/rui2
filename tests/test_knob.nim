## Knob (basic/knob.nim): turned by a vertical drag relative to where it was
## taken, Shift for fine, reset by a double click, and the slider keys and
## wheel when focused (value_input.nim, shared with Slider).

import std/[unittest, math]
import rui
import ui_harness
from raylib import KeyboardKey

proc rig(): tuple[r: Rig, k: Knob, seen: ref seq[float32]] =
  let seen = new(seq[float32])
  let k = newKnob(minValue = 0, maxValue = 100, initialValue = 50, step = 1,
                  onChange = proc(v: float32) = seen[].add v)
  let r = newRig(stack(k.frame(width = 64, height = 100)), 200, 200)
  (r, k, seen)

suite "dragging a value":
  test "valueByDrag: relative, the whole range over the given pixels, clamped, on the grid":
    check valueByDrag(50, 20, 0, 100, 1, 200) == 60
    check valueByDrag(50, -400, 0, 100, 1, 200) == 0
    check valueByDrag(50, 3, 0, 100, 5, 200) == 50          # 1.5 -> the grid's 50
    check valueByDrag(50, 1, 0, 100, 0, 200) == 50.5

suite "Knob":
  teardown: clearRepaints()

  test "a drag up raises, down lowers, from where it was taken: no jump on press":
    let (r, k, seen) = rig()
    let c = k.centre
    r.press(c.x + 20, c.y)                 # off-centre: a press alone changes nothing
    check k.value == 50 and seen[].len == 0
    r.moveTo(c.x + 20, c.y - 40)
    check k.value == 70
    r.moveTo(c.x + 20, c.y + 300)          # far past the bottom: pinned at the end
    check k.value == 0
    r.release(c.x + 20, c.y + 300)
    disposeTree(r.root)

  test "Shift turns it ten times finer":
    let (r, k, _) = rig()
    let c = k.centre
    r.press(c.x, c.y)
    discard k.handleInput(GuiEvent(kind: evMouseMove, mousePos: Point(x: c.x, y: c.y - 40),
                                   mods: {kmShift}))
    check k.value == 52
    r.release(c.x, c.y - 40)
    disposeTree(r.root)

  test "a double click puts it back to its initial value":
    let (r, k, _) = rig()
    r.focus(k)
    r.key(KeyboardKey.End)
    check k.value == 100
    r.click(k)
    r.click(k)
    check k.value == 50
    disposeTree(r.root)

  test "focused, it takes the slider keys and the wheel":
    let (r, k, _) = rig()
    r.wheel(k.centre.x, k.centre.y, 1)
    check k.value == 50                    # not focused: the wheel is the page's
    r.focus(k)
    r.key(KeyboardKey.Up)
    check k.value == 51
    r.key(KeyboardKey.PageDown)
    check k.value == 41
    r.wheel(k.centre.x, k.centre.y, 1)
    check k.value == 42
    disposeTree(r.root)
