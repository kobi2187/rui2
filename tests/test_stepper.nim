## Stepper (basic/stepper.nim): steps spread across, next/back, a click goes
## back to a step done but not ahead, Left/Right when focused -- and a whole
## wizard from a Stepper, an IndexedStack and two buttons.

import std/unittest
import rui
import ui_harness
from raylib import KeyboardKey

suite "Stepper":
  teardown: clearRepaints()

  test "the steps are spread evenly, the ends inset by half a circle":
    let xs = stepCenters(3, Rect(x: 0, y: 0, width: 220, height: 40), 10)
    check xs == @[10'f32, 110, 210]
    check stepCenters(3, Rect(x: 0, y: 0, width: 220, height: 40), 20, 0) == @[20'f32, 120, 220]
    check stepCenters(1, Rect(x: 0, y: 0, width: 100, height: 40), 10) == @[50'f32]

  test "a wizard: next and back move the pages; a click goes back but never ahead":
    var steps: Stepper
    var pages: IndexedStack
    let root = ui:
      Column(spacing = 8.0, crossAxisAlignment = CrossAxisAlignment.stretch):
        steps = Stepper(steps = @["Account", "Profile", "Done"],
                        onStep = proc(i: int) = pages.index = i)
        pages = IndexedStack():
          Label(text = "account page")
          Label(text = "profile page")
          Label(text = "done page")
        Row(spacing = 8.0):
          Button(text = "Back", onClick = proc() = steps.back()).named("back")
          Button(text = "Next", onClick = proc() = steps.next()).named("next")
    let r = newRig(root, 400, 200)
    r.click(root.byId("next"))
    r.click(root.byId("next"))
    check steps.current == 2 and pages.index == 2
    r.click(root.byId("next"))                    # past the last: stays
    check steps.current == 2
    let xs = steps.centers
    r.click(xs[0], steps.bounds.y + 10)
    check steps.current == 0 and pages.index == 0
    r.click(xs[2], steps.bounds.y + 10)           # ahead: not by a click
    check steps.current == 0
    r.focus(steps)
    r.key(KeyboardKey.Right)
    check steps.current == 1
    r.click(root.byId("back"))
    check steps.current == 0
    disposeTree(r.root)
