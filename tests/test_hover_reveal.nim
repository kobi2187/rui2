## HoverReveal: controls that show only when the pointer comes for them.
## Hidden, its contents are not drawn and take no clicks; the pointer coming
## near reveals them, and they hide again once it has been away for a while
## -- unless keyboard focus is inside. A press while hidden (a touch tap) only
## reveals.

import std/[unittest, os]
import rui
import ui_harness
from raylib import KeyboardKey

type Reader = object
  r: Rig
  bar: HoverReveal
  next: Button
  page: Label
  turns: int

var current: ref Reader

proc reader(hideDelay = 0.15): ref Reader =
  ## A page with a reveal bar along its bottom, 400 x 300.
  result = new Reader
  current = result
  let rd = result
  rd.page = newLabel(text = "page text")
  rd.next = newButton(text = "Next")
  rd.next.onClick = proc() = inc rd.turns
  rd.bar = newHoverReveal(hideDelay = hideDelay, reach = 20)
  let row = newRow(spacing = 8.0)
  row.addChild(rd.next)
  rd.bar.addChild(row)
  let place = newPositioned(left = 50, right = 50, bottom = 10, height = 56)
  place.addChild(rd.bar)
  let s = newStack(fit = StackFit.expand)
  s.addChild(rd.page)
  s.addChild(place)
  rd.r = newRig(s)
  motion = motionNone                    # land at once: these read states, not fades

proc wait(rd: ref Reader, seconds: float) =
  sleep(int(seconds * 1000) + 20)
  discard fireDueRepaints()
  rd.r.frame(2)

suite "HoverReveal":
  teardown:
    motion = motionFull
    # Gone with its tree, as in an app: a bar left open would otherwise keep
    # watching the pointer (and setting its hide timer) in the tests after.
    if current != nil: disposeTree(current.r.root)
    clearRepaints()

  test "hidden at first: only its outline is there; its controls are not drawn":
    let rd = reader()
    check not rd.bar.shown
    check not rd.bar.children[0].visible
    check rd.bar.bounds.y + rd.bar.bounds.height == 290      # pinned to the bottom

  test "the pointer coming near reveals it, and then its controls work":
    let rd = reader()
    rd.r.moveTo(200, rd.bar.bounds.y - 10)                  # within reach, not on it yet
    check rd.bar.shown and rd.bar.children[0].visible
    rd.r.click(rd.next)
    check rd.turns == 1

  test "hidden, a press only reveals it: the control under it gets nothing":
    let rd = reader()
    let c = centre(rd.next)
    rd.r.press(c.x, c.y)                                     # a tap: no hover came first
    rd.r.release(c.x, c.y)
    check rd.turns == 0
    check rd.bar.shown

  test "away from it, it hides after hideDelay -- not before":
    let rd = reader(hideDelay = 0.15)
    rd.r.moveTo(centre(rd.next))
    check rd.bar.shown
    rd.r.moveTo(200, 40)                                     # back to the page
    check rd.bar.shown                                       # not yet
    rd.wait(0.2)
    check not rd.bar.shown and not rd.bar.children[0].visible

  test "keyboard focus inside keeps it shown when the pointer leaves":
    let rd = reader(hideDelay = 0.05)
    rd.r.moveTo(centre(rd.next))
    rd.r.focus(rd.next)
    rd.r.key(KeyboardKey.LeftShift)                          # the keyboard is driving
    rd.r.moveTo(200, 40)
    rd.wait(0.1)
    check rd.bar.shown

  test "focus a click left behind does not hold it open":
    let rd = reader(hideDelay = 0.05)
    rd.r.moveTo(centre(rd.next))
    rd.r.click(rd.next)                                      # the button now has focus
    rd.r.moveTo(200, 40)
    rd.wait(0.1)
    check rd.turns == 1
    check not rd.bar.shown

  test "it shows at once, whatever the motion preference: no fade":
    let rd = reader()
    motion = motionFull
    rd.r.moveTo(centre(rd.bar))
    check rd.bar.shown and rd.bar.children[0].visible     # the same frame
    check pendingRepaints().len == 0                      # nothing on its way
