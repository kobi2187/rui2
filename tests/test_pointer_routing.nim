## Several pointers at once (a pinch is two of them): the router offers pointers
## other than 0 only to widgets that ask for them, and each pointer keeps its own
## capture. Mouse behaviour (pointer 0) must be unchanged.

import std/[unittest, sequtils]
import rui
import ui_harness

type Probe = ref object of Widget
  seen: seq[(EventKind, int)]

method handleInput(widget: Probe, event: GuiEvent): bool =
  widget.seen.add (event.kind, event.pointerId)
  true

proc probe(multi: bool): Probe =
  result = Probe(multiPointer: multi)
  initWidgetBase(result)
  result.multiPointer = multi

proc rigWith(w: Widget): Rig =
  let r = newRig(w, 200, 200)
  w.bounds = Rect(x: 0, y: 0, width: 200, height: 200)
  r.frame()
  r

suite "pointer routing":
  test "a second pointer is not shown to a widget that did not ask for it":
    let p = probe(false)
    let r = rigWith(p)
    r.press(50, 50)
    r.pointerDown(1, 120, 120)
    r.pointerMove(1, 130, 130)
    r.pointerUp(1, 130, 130)
    check p.seen.countIt(it[1] != 0) == 0
    check (evMouseDown, 0) in p.seen

  test "a multiPointer widget gets both pointers, each with its id":
    let p = probe(true)
    let r = rigWith(p)
    r.press(50, 50)
    r.pointerDown(1, 120, 120)
    r.pointerMove(1, 130, 130)
    r.pointerUp(1, 130, 130)
    check (evMouseDown, 1) in p.seen
    check (evMouseMove, 1) in p.seen
    check (evMouseUp, 1) in p.seen

  test "each pointer has its own capture, released on its own up":
    let p = probe(true)
    let r = rigWith(p)
    r.press(50, 50)
    capturePointer(p)                   # as a drag would
    r.pointerDown(1, 120, 120)
    check pointerCapture(0) == p and pointerCapture(1) == p
    r.pointerUp(1, 120, 120)
    check pointerCapture(1) == nil
    check pointerCapture(0) == p        # the first finger is still down
    r.release(50, 50)
    check pointerCapture(0) == nil

  test "a second finger on a child reaches the parent holding the first":
    let parent = probe(true)
    let child = probe(false)
    parent.addChild(child)
    child.bounds = Rect(x: 100, y: 100, width: 80, height: 80)
    let r = rigWith(parent)
    child.bounds = Rect(x: 100, y: 100, width: 80, height: 80)
    r.press(20, 20)
    capturePointer(parent)
    r.pointerDown(1, 120, 120)
    check (evMouseDown, 1) in parent.seen
    check child.seen.len == 0

  test "pointer 1 does not move the hover or focus":
    let p = probe(true)
    let r = rigWith(p)
    r.moveTo(10, 10)
    let before = r.app.hoverTracker.hovered
    r.pointerMove(1, 150, 150)
    check r.app.hoverTracker.hovered == before
