## Fizz: a soda theme's bubbles, rising through a primary button once it is
## clicked (rui_widgets basic/fizz.nim).

import std/unittest
import rui
import ui_harness

suite "fizz":
  let area = Rect(x: 10, y: 20, width: 100, height: 32)

  test "bubbles rise from the bottom, stay inside, and are gone by the end":
    check fizzBubbles(-0.1, area).len == 0
    let early = fizzBubbles(0.05, area)
    let mid = fizzBubbles(0.4, area)
    check mid.len > 0
    for b in mid:
      check b.center.x >= area.x - 3 and b.center.x <= area.x + area.width + 3
      check b.center.y >= area.y and b.center.y <= area.y + area.height
      check b.alpha > 0 and b.alpha <= 1
    if early.len > 0:
      var lowest = 0'f32
      for b in early: lowest = max(lowest, b.center.y)
      check lowest > area.y + area.height / 2          # they start low
    check fizzBubbles(0.95, area).len == 0
    check fizzBubbles(0.4, Rect()).len == 0

  test "a click on a primary button fizzes in a soda theme, not elsewhere":
    let r = newRig(stack(newButton(text = "Go", intent = ThemeIntent.Info)))
    r.app.setTheme("soda")
    let b = Button(r.app.tree.root.children[0])
    r.click(b)
    check Fizz(b.children[2]).running
    let plain = newButton(text = "No", intent = ThemeIntent.Default)
    let r2 = newRig(stack(plain))
    r2.app.setTheme("soda")
    r2.click(plain)
    check not Fizz(plain.children[2]).running        # only the primary action
    let r3 = newRig(stack(newButton(text = "Go", intent = ThemeIntent.Info)))
    r3.app.setTheme("daylight")
    let b3 = Button(r3.app.tree.root.children[0])
    r3.click(b3)
    check not Fizz(b3.children[2]).running            # not in a theme without fizz

  test "with motion none, nothing fizzes":
    let r = newRig(stack(newButton(text = "Go", intent = ThemeIntent.Info)))
    r.app.setTheme("soda")
    motion = motionNone
    defer: motion = motionFull
    let b = Button(r.app.tree.root.children[0])
    r.click(b)
    check not Fizz(b.children[2]).running
