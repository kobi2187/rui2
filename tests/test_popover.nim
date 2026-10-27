## Popover (menus/popover.nim), through the real event router: opens beside
## its anchor (below; above when there is no room), takes no room while closed,
## a click elsewhere or Escape closes it, and the toggling button does not
## close-and-reopen it.

import std/[unittest, options]
import rui
import ui_harness
from raylib import KeyboardKey

proc rig(atBottom = false): tuple[r: Rig, pop: Popover, btn: Button, inner: Button, other: Button] =
  var pop: Popover
  var btn, inner, other: Button
  let root = ui:
    Column(spacing = 8.0, padding = EdgeInsets.all(10.0)):
      other = Button(text = "elsewhere")
      SizedBox(height = (if atBottom: 220.0 else: 0.0))
      btn = Button(text = "?", onClick = proc() = pop.toggle(btn))
      pop = Popover(width = 200.0):
        Column(spacing = 6.0):
          Label(text = "Some help that wraps over a line or two.", wrap = true)
          inner = Button(text = "Got it", onClick = proc() = pop.close())
  let r = newRig(root, 400, 300)
  (r, pop, btn, inner, other)

suite "Popover":
  teardown: clearRepaints()

  test "closed it takes no room; open it sits below its button, its content inside":
    let (r, pop, btn, inner, _) = rig()
    check pop.bounds.width == 0 and not pop.isOpen
    r.click(btn)
    check pop.isOpen
    check Widget(pop) in overlays()            # as every popup: on the overlay layer
    check pop.bounds.y >= btn.bounds.y + btn.bounds.height
    check pop.bounds.width == 200
    check inner.bounds.y > pop.bounds.y and inner.bounds.y + inner.bounds.height <= pop.bounds.y + pop.bounds.height
    disposeTree(r.root)

  test "with no room below it opens above":
    let (r, pop, btn, _, _) = rig(atBottom = true)
    renderView = some(Rect(x: 0, y: 0, width: 400, height: 300))   # set by a real render
    defer: renderView = none(Rect)
    r.click(btn)
    check pop.isOpen
    check pop.bounds.y + pop.bounds.height <= btn.bounds.y
    disposeTree(r.root)

  test "the toggling button closes it (no close-and-reopen); a click elsewhere closes it":
    let (r, pop, btn, _, other) = rig()
    r.click(btn)
    check pop.isOpen
    r.click(btn)
    check not pop.isOpen
    r.click(btn)
    r.click(other)
    check not pop.isOpen
    check Widget(pop) notin overlays()
    disposeTree(r.root)

  test "a button inside it works; Escape from inside closes it":
    let (r, pop, btn, inner, _) = rig()
    r.click(btn)
    r.click(inner)
    check not pop.isOpen
    r.click(btn)
    r.focus(inner)
    r.key(KeyboardKey.Escape)
    check not pop.isOpen
    disposeTree(r.root)
